extends CharacterBody3D
class_name Player

#region variables
## Node that controls pitch (up/down) rotation
@onready var pitchNode: Node3D = $gravityControl/yawAxis/pitchAxis
## Node that controls yaw (left/right) rotation
@onready var yawNode: Node3D   = $gravityControl/yawAxis
## Root node of the camera rig, rotates to match surface orientation
@onready var rigRoot: Node3D   = $gravityControl
## The player's camera
@onready var cam: Camera3D     = $gravityControl/yawAxis/pitchAxis/SpringArm3D/Camera3D
## Shape cast pointing downward to detect surfaces beneath the player
@onready var downProbe: ShapeCast3D = $ShapeCast3D

## The visual ant mesh that rotates to face movement direction
@onready var antMesh: Node3D = $gravityControl/Ant
## How fast the ant mesh rotates to face movement direction (degrees/sec)
@export var antRotationSpeed := 10.0 
## Handles gravity, surface attachment, and detachment logic
@onready var gravityController: GravityController = $controllers/gravityController
## Handles WASD movement, jumping, and external impulses
@onready var movementController: MovementController = $controllers/movementController

## Whether the arrow texture image points upward (affects rotation offset)
@export var arrowTexturePointsUp := true

# shared tuning (controllers will read these off the player)
## How fast the camera rig rotates to match the surface normal (higher = snappier)
@export var rigReorientRate := 20.0
## Maximum movement speed in units per second
@export var speed := 15.0
## Gravity acceleration when not attached (units/sec²)
@export var gravityStrength := 50.0
## Stick force pulling you into surfaces when attached (units/sec²)
@export var stickStrength := 90.0
## Maximum speed you can stick to surfaces (prevents infinite acceleration)
@export var maxStickSpeed := 100.0
## Vertical velocity applied when jumping
@export var jumpSpeed := 20.0
## Mouse sensitivity multiplier
@export var mouseSens := 0.001
## Maximum raycast distance for manual surface attachment (interact key)
@export var attachRange := 2.5
## Maximum pitch angle in radians (prevents looking too far up/down)
@export var pitchLimit := deg_to_rad(85.0)
## If true, automatically attach to walls when falling into them
@export var autoAttach := true
## Minimum dot product between surface normal and UP to be considered a "wall"
## (0 = horizontal surface, 1 = vertical surface pointing up)
@export var attachWallDot := 0.5
## Minimum dot product between camera forward and surface normal to auto-attach
## (higher = must look more directly at the surface)
@export var faceDot := 0.7 # this big value means (closer to 1 = floor becomes wall) at 0.8 a 20 deg slope becomes a wall
## How long you can lose surface contact before detaching (seconds)
@export var detachGrace := 0.10
## Speed of smoothing surface normal changes (higher = faster snapping)
@export var supportNormalSmoothStep := 25.0     # bigger = snaps faster, smaller = smoother
## Ignore surface normal changes smaller than this (degrees)
@export var supportNormalDeadzoneDeg := 0.35    # ignore tiny normal changes (degrees)
## Weight given to previous surface normal (0-1, prevents jitter)
@export var continuityWeight := 0.35            # 0..1, biases toward last normal
## Impulse decay rate (unused in current code)
@export var decayOfImpluse := 0.3

@export_category("Holding Objects")
@export var followSpeed = 5.0
@export var maxDistanceFromHold = 5.0
@export var dropBelowPlayer = true
@export var groundRay: RayCast3D

@onready var interactRay = $gravityControl/Ant/InteractRay
var heldObject: RigidBody3D
@onready var head: Marker3D = $gravityControl/Ant/Head


# shared runtime state
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
#endregion


func _ready() -> void:
	gravityController.setup(self, movementController)
	movementController.setup(self, gravityController)

func _input(event: InputEvent) -> void:
	
	if event is InputEventMouseMotion:
		yaw   -= event.relative.x * mouseSens
		pitch -= event.relative.y * mouseSens
		pitch = clamp(pitch, -pitchLimit, pitchLimit)
	
	if Input.is_action_just_pressed("quit"):
		$"..".exit_game(name.to_int())
		get_tree().quit()
	
	if Input.is_action_just_pressed("esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_pressed("respawn"):
		var mm = get_parent().get_parent()
		position = mm._pick_spawn()
		velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	gravityController.updateUpAxis(delta)

	movementController.updatePlanarAndJump(delta)

	gravityController.applyVerticalAccel(delta)


	var imp := movementController.consumeUnsafeImpulse()
	if imp != Vector3.ZERO:
			# carry it into the "external" channel so planar steering won't kill it next frame
		movementController.addExternalKickWorld(imp)
			# explicit unsafe injection (your requested point)
		velocity += imp


	preMoveVel = velocity
	move_and_slide()


	_updateCameraRig()

		# ---- break external recoil if we collide into something ----
	# ---- recoil impact: stop/slide external + force-attach to contacted surface ----
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

func _updateAntRotation(delta: float) -> void:
	# Get the planar velocity (velocity without the vertical component)
	var up := currentUp.normalized()
	var planarVel := velocity - up * velocity.dot(up)
	
	# Only rotate if moving with significant speed
	if planarVel.length() > 0.5:
		# Convert the world-space planar velocity to the rig's local space
		var localVel := rigRoot.global_transform.basis.inverse() * planarVel
		
		# Calculate the target angle in local XZ plane (Y is up in local space)
		var targetAngle := atan2(localVel.x, localVel.z)
		
		# Smoothly interpolate the ant's Y rotation toward the target
		var currentRotation := antMesh.rotation.y
		var angleDiff := fmod(targetAngle - currentRotation + PI, TAU) - PI
		var newRotation := currentRotation + angleDiff * antRotationSpeed * delta
		
		antMesh.rotation.y = newRotation

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
	if body is RigidBody3D:
		heldObject = body
	
func drop_held_object():
	heldObject = null
	
func handle_holding_objects():
		
	# Dropping Objects
	if Input.is_action_just_pressed("interact"):
		if heldObject != null: drop_held_object()
		elif interactRay.is_colliding(): set_held_object(interactRay.get_collider())
		
	# Object Following
	if heldObject != null:
		var targetPos = head.global_transform.origin
		var objectPos = heldObject.global_transform.origin # Held object position
		heldObject.linear_velocity = (targetPos - objectPos) * followSpeed # Our desired position
		
		# Drop the object if it's too far away from the camera
		if heldObject.global_position.distance_to(head.global_position) > maxDistanceFromHold:
			drop_held_object()
			
		# Drop the object if the player is standing on it (must enable dropBelowPlayer and set a groundRay/RayCast3D below the player)
		if dropBelowPlayer && groundRay.is_colliding():
			if groundRay.get_collider() == heldObject: drop_held_object()
