extends Node3D

@export var player_scene: PackedScene


func _ready() -> void:
	var spawn_pos = pick_spawn()
	var player = player_scene.instantiate()
	$Players.add_child(player)
	player.global_position = spawn_pos


func pick_spawn() -> Vector3:
	var spawns = get_tree().get_nodes_in_group("spawn_locations")
	if spawns.size() > 0:
		return spawns.pick_random().global_position
	return Vector3.ZERO
