extends CharacterBody3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var nav_region: NavigationRegion3D = get_tree().current_scene.find_child("NavigationRegion3D")

@onready var player_detector: RayCast3D = $PlayerDetector
@onready var fruit_detector: Area3D = $FruitDetector

@export var SPEED := 30.0
@export var fruit_pickup_distance := 10.0
@export var player_stomp_distance := 4.0
@export var fruit_out_of_place_distance := 25.0

var stuck_timer := 0.0
var last_position := Vector3.ZERO

@export var stuck_timeout := 1.5
@export var stuck_distance_threshold := 0.5

var current_fruit = null
var player_target = null
var border := fruit_pickup_distance

@export var chase_memory_time := 2.0
var chase_memory := 0.0

enum State {
	WANDER,
	CHASE_PLAYER,
	RETURN_FRUIT
}

var state := State.WANDER

func _ready() -> void:
	await get_tree().physics_frame
	last_position = global_position
	set_random_target()

func _physics_process(delta: float) -> void:
	update_targets()

	match state:
		State.CHASE_PLAYER:
			handle_player()

		State.RETURN_FRUIT:
			handle_fruit()

		State.WANDER:
			handle_wander()

	move_ai(delta)

	check_if_stuck(delta)

func check_if_stuck(delta: float) -> void:
	var moved_distance = global_position.distance_to(last_position)

	if moved_distance < stuck_distance_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_position = global_position

	if stuck_timer >= stuck_timeout:
		handle_stuck()

func handle_stuck() -> void:
	stuck_timer = 0.0
	last_position = global_position

	current_fruit = null

	state = State.WANDER
	set_random_target()

func update_targets() -> void:
	var players = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player_target = players[0]

	if player_target and not player_target.dead:
		player_detector.look_at(player_target.global_position, Vector3.UP)

		if player_detector.is_colliding():
			var collider = player_detector.get_collider()

			if collider == player_target:
				var nav_point = NavigationServer3D.map_get_closest_point(
					nav_agent.get_navigation_map(),
					player_target.global_position
				)

				if nav_point.distance_to(player_target.global_position) <= border:
					chase_memory = chase_memory_time
					state = State.CHASE_PLAYER
					return

	if chase_memory > 0.0:
		chase_memory -= get_physics_process_delta_time()
		state = State.CHASE_PLAYER
		return

	current_fruit = find_closest_misplaced_fruit()

	if current_fruit:
		state = State.RETURN_FRUIT
		return

	state = State.WANDER

func handle_player() -> void:
	
	if player_target == null:
		chase_memory = 0.0
		state = State.WANDER
		return

	var reachable_pos = NavigationServer3D.map_get_closest_point(
		nav_agent.get_navigation_map(),
		player_target.global_position
	)

	nav_agent.target_position = reachable_pos

func handle_fruit() -> void:
	if current_fruit == null or not is_instance_valid(current_fruit):
		state = State.WANDER
		return

	var reachable_pos = NavigationServer3D.map_get_closest_point(
		nav_agent.get_navigation_map(),
		current_fruit.global_position
	)

	nav_agent.target_position = reachable_pos

	if global_position.distance_to(current_fruit.global_position) <= fruit_pickup_distance:
		current_fruit.return_home()
		current_fruit = null
		state = State.WANDER
		set_random_target()

func handle_wander() -> void:
	if nav_agent.is_navigation_finished():
		set_random_target()

func move_ai(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	
	if nav_agent.get_current_navigation_path().is_empty():
		handle_stuck()
		return
	
	var next_path_pos = nav_agent.get_next_path_position()

	velocity = global_position.direction_to(next_path_pos) * SPEED

	var planar_velocity := Vector2(velocity.x, velocity.z)

	if planar_velocity.length_squared() > 0.01:
		var target_rotation := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 10.0 * delta)

	move_and_slide()

func find_closest_misplaced_fruit():
	
	var closest = null
	var closest_dist := INF
	
	var nav_map = nav_agent.get_navigation_map()
	
	for body in fruit_detector.get_overlapping_bodies():
		if not body.is_in_group("carryable"):
			continue
	
		# Ignore fruit currently being carried
		if body.collision_layer & (1 << 1):
			continue
	
		# Ignore fruit already at home
		if body.global_position.distance_to(body.starting_transform.origin) < fruit_out_of_place_distance:
			continue
	
		# Ignore fruit that is too far from the navmesh
		var nav_point = NavigationServer3D.map_get_closest_point(
			nav_map,
			body.global_position
		)
	
		if nav_point.distance_to(body.global_position) > border:
			continue
	
		var dist = global_position.distance_squared_to(body.global_position)
	
		if dist < closest_dist:
			closest_dist = dist
			closest = body
	
	return closest

func stomp_player(player) -> void:
	player.die()

func set_random_target() -> void:
	var region_rid: RID = nav_region.get_rid()
	var random_point: Vector3 = NavigationServer3D.region_get_random_point(region_rid, 1, false)
	nav_agent.target_position = random_point

func _on_stomp_area_body_entered(body: Node3D) -> void:	
	if body.is_in_group("player"):
		stomp_player(body)
