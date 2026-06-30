extends CharacterBody3D
class_name Player

#region variables

@onready var pitchNode: Node3D = $gravityControl/yawAxis/pitchAxis
@onready var yawNode: Node3D   = $gravityControl/yawAxis
@onready var rigRoot: Node3D   = $gravityControl
@onready var cam: Camera3D     = $gravityControl/yawAxis/pitchAxis/SpringArm3D/Camera3D
@onready var downProbe: ShapeCast3D = $ShapeCast3D
@onready var antMesh: Node3D = $gravityControl/Ant
@export var antRotationSpeed := 10.0 
@onready var gravityController: GravityController = $controllers/gravityController
@onready var movementController: MovementController = $controllers/movementController
@export var arrowTexturePointsUp := true
@export var rigReorientRate := 20.0
@export var speed := 15.0
@export var gravityStrength := 50.0
@export var stickStrength := 90.0
@export var maxStickSpeed := 100.0
@export var jumpSpeed := 20.0
@export var mouseSens := 0.001
@export var stickLookSens := 2.5
@export var attachRange := 2.5
@export var pitchLimit := deg_to_rad(85.0)
@export var autoAttach := true
@export var attachWallDot := 0.5
@export var faceDot := 0.7
@export var detachGrace := 0.10
@export var supportNormalSmoothStep := 25.0
@export var supportNormalDeadzoneDeg := 0.35
@export var continuityWeight := 0.35
@export var decayOfImpluse := 0.3

@export_category("Holding Objects")

@export var followSpeed = 5.0

@export var carry_pull_strength := 90.0
@export var carry_pull_damping := 18.0
@export var carry_slack := 0.15
@export var carry_max_pull := 25.0

@export var dropBelowPlayer = true
@export var groundRay: RayCast3D
@export var held_object_max_climb_angle := 30.0
@onready var interactRay = $gravityControl/Ant/InteractRay
@onready var drop_point: Marker3D = $gravityControl/Ant/DropPoint

var player_id := 0
var pitch := 0.0
var yaw := 0.0
var currentUp := Vector3.UP
var supposedUp := Vector3.UP
var attached := false
var detachTimer := 0.0
var preMoveVel := Vector3.ZERO
var pendingImpulse := Vector3.ZERO
var noStickTimer := 0.0
var justForceAttached := false
var justManuallyAttached := false
var manualAttachLockTimer := 0.0
var jumpGraceTimer := 0.0
var in_menu: bool = false
var dead := false
var is_local := false
var network_target_position := Vector3.ZERO
var network_target_rotation := Vector3.ZERO
var network_send_timer := 0.0
var heartbeat := 0

# Holding objects
var heldObject: Carryable
var closest_node: Marker3D
var grabJoint: PinJoint3D
var just_dropped_object := false
@onready var grabAnchor: StaticBody3D = $gravityControl/Ant/GrabAnchor


#endregion


func _ready() -> void:
	if player_id == Globals.STEAM_ID:
		is_local = true
	
	if is_local:
		GameManager.game_over_triggered.connect(_on_game_over)
		gravityController.setup(self, movementController)
		movementController.setup(self, gravityController)
		
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if !is_local:
		cam.current = false


func _input(event: InputEvent) -> void:
	if in_menu:
		return
	
	if Input.is_action_just_pressed("esc"):
		get_tree().quit()
	
	if event is InputEventMouseMotion:
		yaw   -= event.relative.x * mouseSens
		pitch -= event.relative.y * mouseSens
		pitch = clamp(pitch, -pitchLimit, pitchLimit)


func _updateJoystickLook(delta: float) -> void:
	if in_menu:
		return
	
	var lookX := Input.get_axis("look_left", "look_right")
	var lookY := Input.get_axis("look_up", "look_down")
	if abs(lookX) < 0.1:
		lookX = 0.0
	if abs(lookY) < 0.1:
		lookY = 0.0
	yaw -= lookX * stickLookSens * delta
	pitch -= lookY * stickLookSens * delta
	pitch = clamp(pitch, -pitchLimit, pitchLimit)


func respawn():
	var mm = get_parent().get_parent()
	global_transform = mm.pick_spawn()
	velocity = Vector3.ZERO


func _process(delta: float) -> void:
	# Clear the just_dropped_object flag after a frame so network updates can work normally again
	if just_dropped_object:
		just_dropped_object = false
	
	if !is_local:
		# Interpolate remote player position and rotation
		global_position = global_position.lerp(
			network_target_position,
			20.0 * delta
		)
		var rot = antMesh.global_rotation
		antMesh.global_rotation = Vector3(
			lerp_angle(rot.x, network_target_rotation.x, 20.0 * delta),
			lerp_angle(rot.y, network_target_rotation.y, 20.0 * delta),
			lerp_angle(rot.z, network_target_rotation.z, 20.0 * delta)
		)
		return


func _physics_process(delta: float) -> void:
	if !is_local:
		return
	
	heartbeat += 1
	
	if dead:
		return
	
	# Send player state (20 packets per second)
	network_send_timer += delta
	if network_send_timer >= 0.05:
		network_send_timer = 0.0
		send_network_state()
	
	assert(velocity.is_finite())
	assert(global_position.is_finite())
	assert(currentUp.is_finite())
	assert(supposedUp.is_finite())
	
	_updateJoystickLook(delta)
	
	gravityController.updateUpAxis(delta)
	if !in_menu: movementController.updatePlanarAndJump(delta)
	gravityController.applyVerticalAccel(delta)
	
	applyCarryPull(delta)
	
	var imp := movementController.consumeUnsafeImpulse()
	if imp != Vector3.ZERO:
		movementController.addExternalKickWorld(imp)
		velocity += imp
	preMoveVel = velocity
	move_and_slide()
	_updateCameraRig()
	
	if movementController.externalVel != Vector3.ZERO and get_slide_collision_count() > 0:
		var ext := movementController.externalVel
		var bestN := Vector3.ZERO
		var bestPush := 0.0
		for i in range(get_slide_collision_count()):
			var n := (get_slide_collision(i).get_normal() as Vector3).normalized()
			var push := -ext.dot(n)
			if push > bestPush:
				bestPush = push
				bestN = n
		if bestPush > 0.05 and bestN != Vector3.ZERO:
			movementController.clearExternalKick()
			velocity = velocity.slide(bestN)
			gravityController.forceAttachToNormal(bestN)
			justForceAttached = true
	
	gravityController.updateAttachmentAfterMove(delta)
	gravityController.clampIntoFloor()
	_updateAntRotation(delta)
	handle_holding_objects()


func applyCarryPull(delta: float) -> void:
	if heldObject == null:
		return

	if closest_node == null:
		return

	var offset := closest_node.global_position - grabAnchor.global_position

	# Ignore gravity direction so it doesn't try to pull us into walls
	var surfaceNormal := currentUp

	if attached:
		offset = offset.slide(surfaceNormal)

	var distance := offset.length()

	if distance <= carry_slack:
		return

	var direction := offset / distance

	# How stretched is the "rope"?
	var stretch = clamp(
		distance - carry_slack,
		0.0,
		1.25
	)

	# Velocity toward the carry point
	var along := velocity.dot(direction)

	# Spring + damping
	var force = stretch * carry_pull_strength \
	- along * carry_pull_damping

	force = clamp(force, 0.0, carry_max_pull)

	movementController.addExternalKickWorld(
		direction * force * delta
	)


func _updateAntRotation(delta: float) -> void:
	if !is_local:
		return
	
	var up := currentUp.normalized()
	var planarVel := velocity - up * velocity.dot(up)
	
	if planarVel.length() > 0.5:
		var localVel := rigRoot.global_transform.basis.inverse() * planarVel
		var targetAngle := atan2(localVel.x, localVel.z)
		
		antMesh.rotation.y = lerp_angle(antMesh.rotation.y, targetAngle, antRotationSpeed * delta)


func _updateCameraRig() -> void:
	var up := currentUp.normalized()
	var refForward := (-rigRoot.global_transform.basis.z).normalized()
	refForward = refForward - up * refForward.dot(up)
	if refForward.length() < 0.001:
		var tmp := Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		refForward = tmp - up * tmp.dot(up)
	var fwd := refForward.normalized()
	var right := fwd.cross(currentUp).normalized()
	var targetBasis := Basis(right, up, -fwd).orthonormalized()
	rigRoot.global_transform.basis = targetBasis
	yawNode.rotation = Vector3(0.0, yaw, 0.0)
	pitchNode.rotation = Vector3(pitch, 0.0, 0.0)


func _screenArrowAngle(camRef: Camera3D, worldDir: Vector3) -> float:
	var d := worldDir.normalized()
	var right := camRef.global_transform.basis.x
	var up := camRef.global_transform.basis.y
	var fwd := -camRef.global_transform.basis.z
	var dProj := d - fwd * d.dot(fwd)
	if dProj.length() < 0.001:
		return INF
	var x := dProj.dot(right)
	var y := dProj.dot(up)
	return Vector2(x, -y).angle()


func addImpulseWorld(imp: Vector3) -> void:
	movementController.addExternalKickWorld(imp)


func addImpulseWorldUnsafe(imp: Vector3) -> void:
	movementController.addUnsafeImpulseWorld(imp)


func set_held_object(body):
	if !(body is Carryable):
		return
	
	# Don't pick up if we're already holding something
	if heldObject != null:
		print_debug("Already holding something, can't pick up")
		return
	
	print_debug("Attempting to pick up: ", body.name, " - collision_layer: ", body.collision_layer)
	
	# VERIFY WE CAN PICK IT UP BEFORE MODIFYING ANY STATE
	var carry_points = body.find_child("CarryPoints")
	if carry_points == null:
		print_debug("Object has no CarryPoints node")
		return
	
	var shortest_distance_squared := INF
	var closest_node_temp = null
	for target in carry_points.get_children():
		if target is Marker3D:
			var dist = interactRay.get_collision_point(0).distance_squared_to(
				target.global_position
			)
			if dist < shortest_distance_squared:
				shortest_distance_squared = dist
				closest_node_temp = target
	
	if closest_node_temp == null:
		print_debug("No valid carry points found")
		return
	
	# NOW we know we can pick it up - modify state
	heldObject = body
	closest_node = closest_node_temp
	
	# Tell the carryable that we're now carrying it
	# This will also update collision layers locally
	heldObject.add_carrier(Globals.STEAM_ID)
	
	# Snap the chosen carry point to the grab anchor
	var correction := grabAnchor.global_position - closest_node.global_position
	heldObject.global_position += correction
	
	# Create PinJoint at current distance (will shrink)
	grabJoint = PinJoint3D.new()
	get_tree().current_scene.add_child(grabJoint)
	grabJoint.global_position = grabAnchor.global_position
	grabJoint.node_a = grabAnchor.get_path()
	grabJoint.node_b = heldObject.get_path()
	
	print_debug("Successfully picked up object: ", heldObject.name)


func drop_held_object():
	if grabJoint:
		grabJoint.queue_free()
		grabJoint = null
	
	if heldObject:
		# Tell the carryable that we're no longer carrying it
		heldObject.remove_carrier(Globals.STEAM_ID)
		
		# Flag that we just dropped so network updates don't re-add us
		just_dropped_object = true
		
		print_debug("Dropped object: ", heldObject.name)
	else:
		print_debug("Tried to drop but no held object")
	
	heldObject = null
	closest_node = null


func handle_holding_objects():
	if Input.is_action_just_pressed("interact"):
		if heldObject:
			drop_held_object()
		elif interactRay.is_colliding():
			print_debug("Interact pressed, raycast hit: ", interactRay.get_collider(0).name)
			set_held_object(interactRay.get_collider(0))
		else:
			print_debug("Interact pressed but raycast not hitting anything")
	
	if heldObject:
		# Check if we're below the object (ground collision)
		if dropBelowPlayer and groundRay.is_colliding():
			if groundRay.get_collider() == heldObject:
				drop_held_object()


func die() -> void:
	if dead:
		return
	dead = true
	# Drop anything being carried
	drop_held_object()
	# Stop movement
	velocity = Vector3.ZERO
	movementController.clearExternalKick()
	# Disable controls
	in_menu = true
	antMesh.visible = false
	
	GameManager.game_over()


func _on_game_over() -> void:
	in_menu = true


func send_network_state():
	var data = {
		"steam_id": player_id,
		"pos": global_position,
		"rot": antMesh.global_rotation,
		"vel": velocity
	}
	
	Network.send_to_all(data)


func apply_network_state(data: Dictionary) -> void:
	if is_local:
		return
	
	network_target_position = data["pos"]
	network_target_rotation = data["rot"]
	velocity = data["vel"]
