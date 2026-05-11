extends CanvasLayer

@onready var FPS_text = $Label

func _process(float) -> void:
	FPS_text.text = str(Engine.get_frames_per_second())
