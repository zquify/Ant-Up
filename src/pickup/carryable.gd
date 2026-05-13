extends RigidBody3D
class_name Carryable

## Array of Marker3D nodes positioned along the object where players can grab
@export var carry_points: Array[Marker3D] = []
## How much the drag coefficient affects speed (0-1)
@export var drag_coefficient: float = 1.0

## Maps point index → player_id to track ownership
var owned_points: Dictionary = {}
## Maps player_id → ghost anchor RigidBody3D
var ghost_anchors: Dictionary = {}
## Maps player_id → PinJoint3D connecting ghost to this object
var joints: Dictionary = {}

var base_mass: float

func _ready() -> void:
	base_mass = mass
	
	# Auto-populate carry_points from CarryPoints folder if not already set
	if carry_points.is_empty():
		var carry_points_node = get_node_or_null("CarryPoints")
		if carry_points_node:
			for child in carry_points_node.get_children():
				if child is Marker3D:
					carry_points.append(child)
			print("Auto-populated %d carry points" % carry_points.size())

## Returns the index of the nearest free carry point, or -1 if none available
func get_nearest_free_point(world_pos: Vector3) -> int:
	var best_idx = -1
	var best_dist = INF
	
	for i in range(carry_points.size()):
		if i not in owned_points:  # This point is free
			var dist = carry_points[i].global_position.distance_to(world_pos)
			if dist < best_dist:
				best_dist = dist
				best_idx = i
	
	return best_idx

## Claim a carry point for a player, creating ghost anchor and joint
func claim_point(point_idx: int, player_id: int, head_pos: Vector3) -> bool:
	if point_idx < 0 or point_idx >= carry_points.size():
		print("ERROR: Invalid point index %d (max %d)" % [point_idx, carry_points.size()])
		return false
	if point_idx in owned_points:
		print("ERROR: Point %d already owned" % point_idx)
		return false
	
	print("Claiming point %d for player %d at head pos %s" % [point_idx, player_id, head_pos])
	
	# Mark point as owned
	owned_points[point_idx] = player_id
	
	# Create ghost anchor (kinematic body that follows the player's head)
	var ghost = RigidBody3D.new()
	ghost.global_position = head_pos
	ghost.mass = 0.1
	ghost.freeze = true  # Frozen so it moves exactly where we tell it to
	
	# Add ghost as SIBLING (not child of carryable) to avoid joint connection issues
	if get_parent():
		get_parent().add_child(ghost)
	else:
		add_child(ghost)
	
	ghost_anchors[player_id] = ghost
	print("Created ghost anchor at %s" % ghost.global_position)
	
	# Create pin joint connecting ghost anchor to this object's carry point
	var joint = PinJoint3D.new()
	add_child(joint)
	joint.node_a = ghost.get_path()
	joint.node_b = self.get_path()
	
	# Set joint position to the carry point location
	var carry_point_pos = carry_points[point_idx].global_position
	joint.global_position = carry_point_pos
	
	print("Created joint at carry point %s" % carry_point_pos)
	
	joints[player_id] = joint
	
	recalculate_penalty()
	return true

## Update ghost anchor position (called every frame by the player)
func update_carrying_player(player_id: int, head_pos: Vector3) -> void:
	if player_id in ghost_anchors:
		var old_pos = ghost_anchors[player_id].global_position
		ghost_anchors[player_id].global_position = head_pos
		# Uncomment to spam console: print("Updated ghost %.2f -> %.2f" % [old_pos, head_pos])

## Release a player's carry point
func release_point(player_id: int) -> bool:
	# Find which point this player owns
	var point_idx = -1
	for idx in owned_points:
		if owned_points[idx] == player_id:
			point_idx = idx
			break
	
	if point_idx == -1:
		return false
	
	# Clean up ghost anchor (it's a sibling, so just queue_free)
	if player_id in ghost_anchors:
		ghost_anchors[player_id].queue_free()
		ghost_anchors.erase(player_id)
		print("Released ghost anchor for player %d" % player_id)
	
	# Clean up joint
	if player_id in joints:
		joints[player_id].queue_free()
		joints.erase(player_id)
	
	owned_points.erase(point_idx)
	recalculate_penalty()
	return true

## Check if a player is currently carrying this object
func is_carrying(player_id: int) -> bool:
	for idx in owned_points:
		if owned_points[idx] == player_id:
			return true
	return false

## Calculate speed multiplier based on how many points are free
## Returns dict of player_id → multiplier
func recalculate_penalty() -> Dictionary:
	var multipliers: Dictionary = {}
	
	var total = carry_points.size()
	if total == 0:
		return multipliers
	
	var occupied = owned_points.size()
	var free_points = total - occupied
	var penalty_ratio = float(free_points) / float(total)
	var penalty_value = penalty_ratio * drag_coefficient
	
	# Each carrying player gets the same multiplier
	for player_id in owned_points.values():
		multipliers[player_id] = 1.0 - penalty_value
	
	return multipliers
