extends RigidBody3D
class_name Carryable
@onready var starting_transform: Transform3D = self.global_transform
@export var score: int = 1
var delivered := false
var network_id := -1
# Multiple carriers system
var carriers := {}  # { steam_id: true, ... }
var carrier_joints := {}  # { steam_id: PinJoint3D, ... }
var carrier_joint_target_distances := {}  # { steam_id: float, ... } - target distance for shrinking
var carrier_joint_shrink_rate := 2.0  # units per second
var network_owner_id := 0  # Who sends sync packets
var default_authority_id := 0  # Host (set during registration)
# Network interpolation for non-carriers only
var network_target_position := Vector3.ZERO
var network_target_rotation := Basis.IDENTITY
var send_timer := 0.0
func _ready():
	network_target_position = global_position
	network_target_rotation = global_basis
	update_label_color()
func _process(delta):
	# Shrink PinJoints for all carriers (local simulation)
	for steam_id in carrier_joints.keys():
		var joint = carrier_joints[steam_id]
		if joint == null:
			continue
		
		var current_distance = joint.global_position.distance_to(global_position)
		var target_distance = carrier_joint_target_distances.get(steam_id, 0.0)
		
		# Shrink toward target, but never grow
		if current_distance > target_distance:
			target_distance = move_toward(current_distance, 0.0, carrier_joint_shrink_rate * delta)
			carrier_joint_target_distances[steam_id] = target_distance
	
	# Carriers simulate locally, don't lerp from network
	if is_carrier():
		return
	
	# Non-carriers only: interpolate from network owner
	if network_owner_id != Globals.STEAM_ID:
		global_position = global_position.lerp(
			network_target_position,
			15.0 * delta
		)
		global_basis = global_basis.slerp(
			network_target_rotation,
			15.0 * delta
		)
func _physics_process(delta):
	# Simulate physics if you're owner or a carrier
	if not _should_simulate_physics():
		sleeping = true
		return
	
	sleeping = false
	
	# Only the owner sends sync packets to the network
	# Carriers (non-owner) simulate locally but don't send syncs
	if network_owner_id != Globals.STEAM_ID:
		return  # Carrier: run local physics but don't send network updates
	
	# Owner: run physics and send syncs
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
		"ang_vel": angular_velocity,
		"carriers": Array(carriers.keys())
	})
func _should_simulate_physics() -> bool:
	# Both owner and carriers simulate physics locally
	if network_owner_id == Globals.STEAM_ID:
		return true
	if is_carrier():
		return true
	return false
func is_carrier() -> bool:
	return Globals.STEAM_ID in carriers
func update_collision_layers_for_local_player() -> void:
	"""Update collision layers based on whether the local player is a carrier"""
	if is_carrier():
		# I'm carrying it - use layer 2
		set_collision_layer_value(2, true)
		set_collision_layer_value(3, false)
	else:
		# I'm not carrying it - use layer 3
		set_collision_layer_value(2, false)
		set_collision_layer_value(3, true)
func add_carrier(steam_id: int) -> void:
	"""Add a new carrier to this object"""
	var already_carrying = steam_id in carriers
	
	if not already_carrying:
		carriers[steam_id] = true
	
	# ALWAYS update collision layers for the local player, even if already carrying
	update_collision_layers_for_local_player()
	
	# If I'm the one being added and I just became a carrier, create joints for all other carriers
	if steam_id == Globals.STEAM_ID and not already_carrying:
		for other_carrier_id in carriers.keys():
			if other_carrier_id != Globals.STEAM_ID:
				var player = get_tree().get_first_node_in_group("players_" + str(other_carrier_id))
				if player:
					create_carrier_joint(other_carrier_id, player)
	
	# First carrier becomes network owner (replaces previous owner if any)
	if not already_carrying and carriers.size() == 1:  # This is the first carrier
		network_owner_id = steam_id
		print_debug("Authority transferred! New owner: ", steam_id, " (I am ", Globals.STEAM_ID, ")")
		update_label_color()
	elif not already_carrying:
		print_debug("New carrier added: ", steam_id, " but keeping existing owner: ", network_owner_id, " (I am ", Globals.STEAM_ID, ")")
	
	# Only send network packet if this is a NEW carrier
	if not already_carrying:
		# Update network targets so we don't lerp to stale positions
		network_target_position = global_position
		network_target_rotation = global_basis
		
		# Notify network
		Network.send_to_all({
			"type": "carryable_pickup",
			"id": network_id,
			"steam_id": steam_id,
			"network_owner_id": network_owner_id
		})
func remove_carrier(steam_id: int) -> void:
	"""Remove a carrier from this object"""
	if steam_id not in carriers:
		return
	
	carriers.erase(steam_id)
	print_debug("Carrier removed: ", steam_id, " Remaining carriers: ", Array(carriers.keys()), " (I am ", Globals.STEAM_ID, ")")
	
	# Update collision layers for local player
	update_collision_layers_for_local_player()
	
	# Remove the dropped player's joint if it exists.
	if steam_id in carrier_joints:
		var joint = carrier_joints[steam_id]
		if joint:
			joint.queue_free()
		carrier_joints.erase(steam_id)
		carrier_joint_target_distances.erase(steam_id)

	# If *I* just stopped being a carrier, destroy every remaining
	# carrier joint because this client should no longer simulate
	# the carryable.
	if steam_id == Globals.STEAM_ID:
		for id in carrier_joints.keys():
			var joint = carrier_joints[id]
			if joint:
				joint.queue_free()

		carrier_joints.clear()
		carrier_joint_target_distances.clear()
	
	# If network owner drops and there are other carriers, reassign ownership
	if steam_id == network_owner_id and carriers.size() > 0:
		network_owner_id = carriers.keys()[0]
		print_debug("Owner dropped but others remain. New owner: ", network_owner_id)
		update_label_color()
	elif steam_id == network_owner_id and carriers.size() == 0:
		# Last carrier dropped - they keep ownership to simulate falling physics
		network_owner_id = steam_id
		print_debug("Last carrier dropped. They keep ownership: ", network_owner_id)
		update_label_color()
	
	# Notify network
	Network.send_to_all({
		"type": "carryable_drop",
		"id": network_id,
		"steam_id": steam_id,
		"network_owner_id": network_owner_id,
		"pos": global_position,
		"rot": global_basis,
		"lin_vel": linear_velocity,
		"ang_vel": angular_velocity
	})
func is_carried() -> bool:
	return carriers.size() > 0
func get_carriers() -> Array:
	return carriers.keys()
# Called by network manager when a remote carrier picks up this object
func create_carrier_joint(steam_id: int, player: CharacterBody3D) -> void:
	if steam_id == Globals.STEAM_ID:
		push_error("BUG: create_carrier_joint() called for local player!")
		print_stack()
		return
	
	"""Create a PinJoint for a new carrier"""
	if steam_id in carrier_joints:
		return  # Joint already exists
	
	var grab_anchor = player.get_node_or_null("gravityControl/Ant/GrabAnchor")
	if grab_anchor == null:
		print_debug("Warning: Could not find grab anchor for player ", steam_id)
		return
	
	# Create joint at current distance
	var current_distance = grab_anchor.global_position.distance_to(global_position)
	
	var joint = PinJoint3D.new()
	get_tree().current_scene.add_child(joint)
	joint.global_position = grab_anchor.global_position
	joint.node_a = grab_anchor.get_path()
	joint.node_b = self.get_path()
	
	carrier_joints[steam_id] = joint
	carrier_joint_target_distances[steam_id] = current_distance
# Called by network manager when a remote carrier drops this object
func remove_carrier_joint(steam_id: int) -> void:
	
	"""Remove the PinJoint for a carrier"""
	if steam_id in carrier_joints:
		var joint = carrier_joints[steam_id]
		if joint:
			joint.queue_free()
		carrier_joints.erase(steam_id)
		carrier_joint_target_distances.erase(steam_id)
func return_home():
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = starting_transform
func update_label_color() -> void:
	var label = get_node_or_null("Label3D")
	if label == null:
		return
	
	if network_owner_id == Globals.STEAM_ID:
		label.modulate = Color.GREEN  # You have authority
	else:
		label.modulate = Color.YELLOW  # You don't have authority
