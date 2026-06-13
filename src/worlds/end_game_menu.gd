extends Control


func _ready() -> void:
	GameManager.game_over_triggered.connect(_on_game_over)


func _on_game_over() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.save_high_score()
	$VBoxContainer/Score.text = "Score: " + str(GameManager.score)
