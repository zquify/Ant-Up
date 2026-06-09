extends Control



func _ready() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	
	if event.is_action_pressed("ui_cancel"):
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			visible = false
	
			for player in get_tree().get_nodes_in_group("player"):
				player.in_menu = false
	
	if event.is_action_pressed("esc"):
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			visible = false
	
			for player in get_tree().get_nodes_in_group("player"):
				player.in_menu = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			visible = true
	
			for player in get_tree().get_nodes_in_group("player"):
				player.in_menu = true
			
			$VBoxContainer/Resolution.grab_focus()


func _on_window_mode_item_selected(index: int) -> void:
	match index:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

		1: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

		2: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


@onready var resolution: OptionButton = $VBoxContainer/Resolution

func _on_resolution_item_selected(index: int) -> void:
	var parts: PackedStringArray = resolution.get_item_text(index).split(" x ")
	 
	if parts.size() >= 2:
		# Parse integers, stripping any accidental whitespace like " 1280 "
		var x_val: int = parts[0].strip_edges().to_int()
		var y_val: int = parts[1].strip_edges().to_int()
		
		set_resolution(Vector2i(x_val, y_val))
		return
		
	# Fallback default if the format is invalid
	set_resolution(Vector2i(1280, 720))
	return


func set_resolution(res: Vector2i):
	DisplayServer.window_set_size(res)
	print(DisplayServer.window_get_size())


func _on_v_sync_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
		)
	else:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_DISABLED
		)
	
	print(DisplayServer.window_get_vsync_mode())


func _on_fps_limit_value_changed(value: float) -> void:
	Engine.max_fps = int(value)


func _on_render_scale_value_changed(value: float) -> void:
	get_viewport().scaling_3d_scale = value


func _on_msaa_item_selected(index: int) -> void:
	set_msaa(index)

func set_msaa(index):
	get_viewport().msaa_3d = index
	print(get_viewport().msaa_3d)
