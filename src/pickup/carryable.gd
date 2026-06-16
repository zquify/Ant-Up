extends RigidBody3D
class_name Carryable

@onready var starting_transform: Transform3D = self.global_transform

@export var score: int = 1

var delivered := false
var carried := false

var network_id := -1
var authority_id := 0

var network_target_position := Vector3.ZERO
var network_target_rotation := Basis.IDENTITY

var send_timer := 0.0

func _process(delta):

	if authority_id == Globals.STEAM_ID:
		return

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
	if authority_id != Globals.STEAM_ID:
		sleeping = true
		return

	sleeping = false
	
	if authority_id != Globals.STEAM_ID:
		return

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
