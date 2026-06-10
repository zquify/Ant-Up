extends Node
class_name GravityController

var player: Player
var movementController: MovementController

var extraGravityStrength := 0.0
var extraGravityTimer := 0.0

func setup(p: Player, m:MovementController) -> void:
	player = p
	movementController = m

func _get_floor_support_normal() -> Vector3:
	for i in range(player.get_slide_collision_count()):
		var col := player.get_slide_collision(i)
		var collider = col.get_collider()

		if collider and collider.is_in_group("no_crawl"):
			return Vector3.ZERO

	# No no-crawl collision found, allow attachment
	if player.is_on_floor():
		return player.get_floor_normal().normalized()

	return Vector3.ZERO

func forceDetach() -> void:
	player.attached = false
	player.supposedUp = Vector3.UP
	player.detachTimer = 0.0

func tryAttachFromCamera() -> void:
	var origin := player.pitchNode.global_position
	var dir := (-player.pitchNode.global_transform.basis.z).normalized()
	var to := origin + dir * player.attachRange
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		player.attached = true
		player.supposedUp = (hit["normal"] as Vector3).normalized()
		player.detachTimer = 0.0
		player.manualAttachLockTimer = 0.3  # <-- Lock for 0.3 seconds

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
	#if player.heldObject != null:
		#player.attached = false
		#player.supposedUp = Vector3.UP
		#player.detachTimer = 0.0
		#return
	
	player.attached = false
	player.supposedUp = Vector3.UP
	player.detachTimer = 0.0
	
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
		supportN = _get_floor_support_normal()
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
	player.downProbe.target_position = player.to_local(
		player.global_position - player.currentUp * 0.5
	)
	player.downProbe.force_shapecast_update()

	var bestN := Vector3.ZERO
	var bestScore := -INF

	for i in range(player.downProbe.get_collision_count()):
		var collider = player.downProbe.get_collider(i)
		
		if collider and collider.is_in_group("no_crawl"):
			continue

		var n: Vector3 = player.downProbe.get_collision_normal(i).normalized()

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
		
		var collider = col.get_collider()
		
		if collider and collider.is_in_group("no_crawl"):
			continue
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
