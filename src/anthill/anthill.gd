extends Node3D

@onready var score: int = 0
@onready var area_3d: Area3D = $Area3D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label3D.text = str(score)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	score = get_colliders_in_group("carryable")
	$Label3D.text = str(score)

func get_colliders_in_group(group_name: String) -> int:
	var count = 0
	# Retrieve all physics bodies currently overlapping the area
	var overlapping_bodies = area_3d.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# Check if the body belongs to your target group
		if body.is_in_group(group_name):
			count += 1
			
	return count
