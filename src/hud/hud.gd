extends CanvasLayer

@onready var label: Label = $Timer

func _process(_delta: float) -> void:
	label.text = str(int(ceil(GameManager.time_left)))
