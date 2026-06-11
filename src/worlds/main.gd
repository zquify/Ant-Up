extends Node3D

@export var player_scene: PackedScene
@onready var max_fps = Engine.max_fps


func _ready() -> void:
	respawn()

func respawn() -> void:
	var spawn_pos = pick_spawn()
	var player = player_scene.instantiate()
	$Players.add_child(player)
	player.global_transform  = spawn_pos

func pick_spawn() -> Transform3D:
	var spawns = get_tree().get_nodes_in_group("spawn_locations")
	if spawns.size() > 0:
		return spawns.pick_random().global_transform
	return global_transform
