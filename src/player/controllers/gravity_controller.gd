extends Node
class_name GravityController
var player: Player
var movementController: MovementController
var extraGravityStrength := 0.0
var extraGravityTimer := 0.0
func setup(p: Player, m:MovementController) -> void:
	player = p
	movementController = m
func handleInteract() -> void:
	if not Input.is_action_just_pressed("interact"): return
	
	# If currently carrying something, drop it
	if player.current_carryable:
		player.current_carryable.release_point(player.get_multiplayer_authority())
		player.current_carryable = null
		player.carry_speed_multiplier = 1.0
		return
	
	# Try to pick up a carryable object
	var nearest_carryable: Carryable = null
	var nearest_distance = player.carryRange
	
	# Find the nearest carryable within range
	for carryable in get_tree().get_nodes_in_group("carryables"):
		var dist = player.headMarker.global_position.distance_to(carryable.global_position)
		if dist < nearest_distance:
			nearest_carryable = carryable
			nearest_distance = dist
	
	if not nearest_carryable:
		return
	
	# Check if player is standing on the object
	var raycast_origin = player.global_position
	var raycast_direction = -player.currentUp
	var raycast_to = raycast_origin + raycast_direction * 0.5
	
	var space = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(raycast_origin, raycast_to)
	query.exclude = [player.get_rid()]
	var hit = space.intersect_ray(query)
	
	if not hit.is_empty() and hit["collider"] == nearest_carryable:
		# Player is standing on the object, can't pick it up
		return
	
	# Get the nearest free carry point
	var nearest_point = nearest_carryable.get_nearest_free_point(player.headMarker.global_position)
	if nearest_point == -1:
		# All points occupied
		return
	
	# Claim the point
	if nearest_carryable.claim_point(nearest_point, player.get_multiplayer_authority(), player.headMarker.global_position):
		player.current_carryable = nearest_carryable
		update_carry_speed_multiplier()
func update_carry_speed_multiplier() -> void:
	if not player.current_carryable:
		player.carry_speed_multiplier = 1.0
		return
	
	var total = player.current_carryable.carry_points.size()
	var occupied = player.current_carryable.owned_points.size()
	
	if total > 0:
		var free_points = total - occupied
		var penalty_ratio = float(free_points) / float(total)
		player.carry_speed_multiplier = 1.0 - (penalty_ratio * player.current_carryable.drag_coefficient)
	else:
		player.carry_speed_multiplier = 1.0
func forceDetach() -> void:
	player.attached = false
	player.supposedUp = Vector3.UP
	player.detachTimer = 0.0
func updateUpAxis(delta: float) -> void:
	var t := 1.0 - exp(-player.rigReorientRate * delta)
	# Smoothly interpolate the "current" up to the "supposed" up
	player.currentUp = player.currentUp.lerp(player.supposedUp, t).normalized()
	player.up_direction = player.currentUp
	# Allow walking on any angle when attached
	player.floor_max_angle = deg_to_rad(179.0 if player.attached else 45.0)
func applyVerticalAccel(delta: float) -> void:
	var up := player.currentUp.normalized()
	# exclude pushback from gravity/stick
	var ext := movementController.externalVel
	var baseVel := player.velocity - ext
	var vUp := baseVel.dot(up)
	if player.attached:
		vUp -= player.stickStrength * delta
		vUp = max(vUp, -player.maxStickSpeed)
	elif not player.is_on_floor():
		vUp -= player.gravityStrength * delta
	if extraGravityTimer > 0.0:
		vUp -= extraGravityStrength * delta
		extraGravityTimer -= delta
		if extraGravityTimer <= 0.0:
			extraGravityStrength = 0.0
			extraGravityTimer = 0.0
	var planar := baseVel - up * baseVel.dot(up)
	player.velocity = planar + up * vUp + ext
func updateAttachmentAfterMove(delta: float) -> void:
	if player.justForceAttached:
		player.justForceAttached = false
		return
	if player.manualAttachLockTimer > 0.0:
		player.manualAttachLockTimer -= delta
		return
	if player.jumpGraceTimer > 0.0:
		player.jumpGraceTimer -= delta
	var supportN := Vector3.ZERO
	if player.is_on_floor():
		supportN = player.get_floor_normal().normalized()
	else:
		supportN = sampleSupportNormal()
	# While airborne from a jump, also check slide collisions for walls
	if supportN == Vector3.ZERO:
		supportN = _bestWallFromSlideCollisions(player.preMoveVel)
	if player.jumpGraceTimer > 0.0:
		# Mid-jump: stay detached, but track surface if we somehow land
		if player.attached:
			if supportN != Vector3.ZERO:
				player.supposedUp = supportN
				player.detachTimer = 0.0
			else:
				player.detachTimer += delta
				if player.detachTimer > player.detachGrace:
					forceDetach()
		else:
			player.supposedUp = Vector3.UP
		return
	# Not jumping: only attach if actually touching something
	if supportN != Vector3.ZERO:
		player.attached = true
		player.supposedUp = supportN
		player.detachTimer = 0.0
	elif player.attached:
		# Briefly tolerate losing the surface (crossing edges, etc.)
		player.detachTimer += delta
		if player.detachTimer > player.detachGrace:
			forceDetach()
	# If already detached and no surface found, stay detached — normal gravity applies
func clampIntoFloor() -> void:
	if player.attached or not player.is_on_floor(): return
	if player.gravityController.extraGravityTimer > 0.0: return
	
	var up := player.currentUp.normalized()
	var ext := movementController.externalVel
	var baseVel := player.velocity - ext
	var vUp := baseVel.dot(up)
	
	if vUp < 0.0:
		baseVel -= up * vUp
	
	player.velocity = baseVel + ext
func sampleSupportNormal() -> Vector3:
	# Crucial: Cast the shape slightly "down" relative to player feet
	player.downProbe.target_position = player.to_local(player.global_position - player.currentUp * 0.5)
	player.downProbe.force_shapecast_update()
	
	var bestN := Vector3.ZERO
	var bestScore := -INF
	
	for i in range(player.downProbe.get_collision_count()):
		var n: Vector3 = player.downProbe.get_collision_normal(i).normalized()
		# We want the surface most aligned with our feet
		var score := n.dot(player.currentUp)
		if score > bestScore:
			bestScore = score
			bestN = n
	
	return bestN
func _bestWallFromSlideCollisions(preVel: Vector3) -> Vector3:
	var bestN := Vector3.ZERO
	var bestScore := -INF
	
	for i in range(player.get_slide_collision_count()):
		var col := player.get_slide_collision(i)
		var n := (col.get_normal() as Vector3).normalized()
		
		# wall-like: normal is not "up-ish"
		if n.dot(Vector3.UP) >= player.attachWallDot:
			continue
		
		# require we were moving into the surface (pre-move), not merely grazing
		var approach := preVel.dot(-n)   # >0 means moving toward the wall
		if approach < 0.25:
			continue
		if approach > bestScore:
			bestScore = approach
			bestN = n
	
	return bestN
	
func forceAttachToNormal(n: Vector3) -> void:
	
	player.attached = true
	player.supposedUp = n.normalized()
	player.detachTimer = 0.0
