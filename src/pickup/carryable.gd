extends RigidBody3D
class_name Carryable

@onready var starting_transform: Transform3D = self.global_transform
@export var score: int = 1

var delivered := false
var network_id := -1

# Multiple carriers system
var carriers := {}  # { steam_id: true, ... }
var authority_id := 0  # Current physics authority (carrier or host)
var default_authority_id := 0  # Host authority (set during registration)

# Network interpolation for non-authority
var network_target_position := Vector3.ZERO
var network_target_rotation := Basis.IDENTITY
var send_timer := 0.0

func _ready():
	# Initialize network targets to current position so we don't lerp to origin when dropped
	network_target_position = global_position
	network_target_rotation = global_basis

func _process(delta):
	# Skip if we're the authority (we handle our own physics)
	if authority_id == Globals.STEAM_ID:
		return
	
	# Interpolate position/rotation from the authority
	global_position = global_position.lerp(
		network_target_position,
		15.0 * delta
	)
	global_basis = global_basis.slerp(
		network_target_rotation,
		15.0 * delta
	)

func return_home():
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = starting_transform

func _physics_process(delta):
	# Only the authority handles physics
	if authority_id != Globals.STEAM_ID:
		sleeping = true
		return
	
	sleeping = false
	
	send_timer += delta
	if send_timer < 0.05:
		return
	
	send_timer = 0.0
	Network.send_to_all({
		"type": "carryable_state",
		"steam_id": Globals.STEAM_ID,
		"id": network_id,
		"pos": global_position,
		"rot": global_basis,
		"lin_vel": linear_velocity,
		"ang_vel": angular_velocity
	})

func add_carrier(steam_id: int) -> void:
	"""Add a new carrier to this object"""
	if steam_id in carriers:
		return  # Already carrying
	
	carriers[steam_id] = true
	
	# First carrier (or host) becomes authority
	if carriers.size() == 1:
		authority_id = steam_id
	elif authority_id == 0:
		# Fallback: use first carrier as authority
		authority_id = steam_id
	
	# Update network targets to current position when picked up
	# This ensures we don't lerp to stale positions
	network_target_position = global_position
	network_target_rotation = global_basis
	
	# Notify network
	Network.send_to_all({
		"type": "carryable_pickup",
		"id": network_id,
		"steam_id": steam_id,
		"authority_id": authority_id
	})

func remove_carrier(steam_id: int) -> void:
	"""Remove a carrier from this object"""
	if steam_id not in carriers:
		return
	
	carriers.erase(steam_id)
	
	# If authority drops and there are other carriers, reassign authority
	if steam_id == authority_id and carriers.size() > 0:
		# Another player is still holding it
		authority_id = carriers.keys()[0]
	elif steam_id == authority_id and carriers.size() == 0:
		# Last carrier dropped - they keep authority to simulate falling physics
		authority_id = steam_id
	
	# Notify network - include current position/velocity so host knows where it actually is
	Network.send_to_all({
		"type": "carryable_drop",
		"id": network_id,
		"steam_id": steam_id,
		"authority_id": authority_id,
		"pos": global_position,
		"rot": global_basis,
		"lin_vel": linear_velocity,
		"ang_vel": angular_velocity
	})

func is_carried() -> bool:
	return carriers.size() > 0

func get_carriers() -> Array:
	return carriers.keys()
