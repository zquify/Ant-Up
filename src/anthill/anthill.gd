extends Node3D

@onready var area_3d: Area3D = $Area3D


func _ready() -> void:
	area_3d.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("carryable"):
		return
	
	if body.delivered:
		return
	
	body.delivered = true
	
	GameManager.score += body.score
	$Label3D.text = str(GameManager.score)
	
	_check_win()


func get_score(group_name: String) -> int:
	var count = 0
	# Retrieve all physics bodies currently overlapping the area
	var overlapping_bodies = area_3d.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# Check if the body belongs to your target group
		if body.is_in_group(group_name):
			count += body.score
			
	return count


func _check_win() -> void:
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	
	if GameManager.score >= GameManager.target_score:
		GameManager.game_over()
