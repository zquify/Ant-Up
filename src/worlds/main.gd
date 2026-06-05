extends Node3D

@export var player_scene: PackedScene
@onready var max_fps = Engine.max_fps


func _ready() -> void:
	respawn()

func _input(_event: InputEvent) -> void:
	
	if Input.is_action_just_pressed("limit_fps"):
		if Engine.max_fps == max_fps:
			Engine.max_fps = 10
		else:
			Engine.max_fps = max_fps

func respawn() -> void:
	var spawn_pos = pick_spawn()
	var player = player_scene.instantiate()
	$Players.add_child(player)
	player.global_position = spawn_pos

func pick_spawn() -> Vector3:
	var spawns = get_tree().get_nodes_in_group("spawn_locations")
	if spawns.size() > 0:
		return spawns.pick_random().global_position
	return Vector3.ZERO
