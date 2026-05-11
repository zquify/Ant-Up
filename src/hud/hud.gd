extends CanvasLayer

@onready var FPS_text = $Label

func _process(_delta: float) -> void:
	FPS_text.text = str(Engine.get_frames_per_second())
