extends Node3D

@export var player_scene: PackedScene
@onready var end_game_menu: Control = $EndGameMenu

@onready var max_fps = Engine.max_fps


func _ready():
	GameManager.reset()
	await get_tree().process_frame
	spawn_players()
	calculate_total_score()


func calculate_total_score() -> void:
	var total := 0

	for body in get_tree().get_nodes_in_group("carryable"):
		total += body.score

	GameManager.target_score = total


func respawn() -> void:
	var spawn_pos = pick_spawn()
	var player = player_scene.instantiate()
	player.global_transform = spawn_pos
	$Players.add_child(player)


func spawn_players() -> void:
	for member in Globals.LOBBY_MEMBERS:
		spawn_player(member["steam_id"])


func spawn_player(steam_id: int) -> void:
	var player = player_scene.instantiate()

	player.player_id = steam_id
	player.name = str(steam_id)

	player.global_transform = pick_spawn()

	$Players.add_child(player)

	player.add_to_group("players_" + str(steam_id))

	Network.register_peer(steam_id)


func pick_spawn() -> Transform3D:
	var spawns = get_tree().get_nodes_in_group("spawn_locations")
	if spawns.size() > 0:
		return spawns.pick_random().global_transform
	return global_transform


func count_total_food() -> void:
	GameManager.total_food = get_tree().get_nodes_in_group("carryable").size()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(GameManager.TITLE)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
