extends Node

const SAVE_PATH := "user://user.save"
const TITLE = "res://title.tscn"

enum GameState { PLAYING, GAME_OVER }

var state: GameState = GameState.GAME_OVER

var high_score: int = 0
var score: int = 0
var target_score: int = 0

const MATCH_TIME: float = 2600.0
var time_left: float = MATCH_TIME

signal game_over_triggered


func _ready() -> void:
	pass

func save_high_score() -> void:
	if score > high_score:
		high_score = score

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(high_score)

func load_high_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		high_score = 0
		return high_score

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file.get_length() == 0:
		high_score = 0
		return high_score

	high_score = file.get_var()
	return high_score


func _process(delta: float) -> void:
	Network.read_packets()
	
	if state != GameState.PLAYING:
		return

	time_left -= delta

	if time_left <= 0:
		time_left = 0
		game_over()


func game_over() -> void:
	if state == GameState.GAME_OVER:
		return
	
	state = GameState.GAME_OVER
	game_over_triggered.emit()


func reset() -> void:
	state = GameState.PLAYING
	score = 0
	target_score = 0
	time_left = MATCH_TIME
