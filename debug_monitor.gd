extends Node

const LOG_FILE := "user://runtime.log"

var timer := 0.0


func _ready() -> void:
	var file := FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	
	if file:
		file.seek_end()
		file.store_line("")
		file.store_line("===== SESSION START =====")
		file.store_line(Time.get_datetime_string_from_system())
		file.close()
	
	# Create file if it doesn't exist
	if not FileAccess.file_exists(LOG_FILE):
		var f := FileAccess.open(LOG_FILE, FileAccess.WRITE)
		if f:
			f.store_line("--- Runtime Log Started ---")
			f.close()


func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	timer += delta

	if timer < 5.0:
		return

	timer = 0.0

	var file := FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)

	if file == null:
		push_error("Failed to open runtime log")
		return

	file.seek_end()

	var data := {
		"time": Time.get_datetime_string_from_system(),
		"fps": Engine.get_frames_per_second(),
		"physics_ms": Performance.get_monitor(
			Performance.TIME_PHYSICS_PROCESS
		),
		"process_ms": Performance.get_monitor(
			Performance.TIME_PROCESS
		),
		"objects": Performance.get_monitor(
			Performance.OBJECT_COUNT
		),
		"nodes": Performance.get_monitor(
			Performance.OBJECT_NODE_COUNT
		),
		"memory": Performance.get_monitor(
			Performance.MEMORY_STATIC
		),
		"pin_joints": _count_pin_joints(get_tree().root)
	}
	
	if player:
		data["heartbeat"] = player.heartbeat
		data["player_pos"] = player.global_position
		data["player_vel"] = player.velocity
		data["attached"] = player.attached
		data["on_floor"] = player.is_on_floor()

	file.store_line(JSON.stringify(data))
	file.close()


func _count_pin_joints(node: Node) -> int:
	var count := 0

	if node is PinJoint3D:
		count += 1

	for child in node.get_children():
		count += _count_pin_joints(child)

	return count
