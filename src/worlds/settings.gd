extends Control

@onready var tabs: TabContainer = $Tabs

@export var initial_focus : OptionButton


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
			
			focus_current_tab()


func focus_current_tab() -> void:
	var tab := tabs.get_current_tab_control()

	if tab == null:
		return

	var focusable := _find_first_focusable(tab)

	if focusable:
		focusable.grab_focus()


func _find_first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			return child

		var found := _find_first_focusable(child)
		if found:
			return found

	return null


#region Graphics
func _on_window_mode_item_selected(index: int) -> void:
	match index:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

		1: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

		2: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


@onready var resolution: OptionButton = $Tabs/Graphics/Resolution

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


func _on_shadows_toggled(toggled_on: bool) -> void:
	for light in get_tree().get_nodes_in_group("light"):
		light.shadow_enabled = toggled_on


#endregion

#region Playtest
var url := "https://docs.google.com/forms/d/e/1FAIpQLSd6tJiOMO-xjMPIIq3YlVcJDo98RwbWubZcDM82IxiYsCpKJQ/viewform?usp=pp_url&entry.1156378466={feedback_type}&entry.1137804085={summary}&entry.838380160={details}&entry.1056658173={current_scene}&entry.1006285445={game_version}&entry.788985875={player_id}&entry.177398783={os}&entry.1489247364={gpu}&entry.31249465={cpu}&entry.401160998={locale}"
var info := {
	"feedback_type": "",
	"summary": "",
	"details": "",
	"current_scene": "",
	"game_version": "",
	"player_id": "",
	"os": "",
	"gpu": "",
	"cpu": "",
	"locale": ""
}

func safe_format(dict: Dictionary) -> String:
	var copy = {}
	for k in dict:
		copy[k] = str(dict[k]).uri_encode()
	
	return url.format(copy)

func _on_feedback_pressed() -> void:
	info["current_scene"] = get_tree().current_scene.scene_file_path
	info["game_version"] = ProjectSettings.get_setting("application/config/version")
	info["player_id"] = Steam.get_current_steam_id()
	info["os"] = str(OS.get_name(), " ", OS.get_version_alias())
	info["gpu"] = str(RenderingServer.get_video_adapter_name(), " / ", OS.get_video_adapter_driver_info())
	info["cpu"] = OS.get_processor_name()
	info["locale"] = TranslationServer.get_locale()
	
	OS.shell_open(safe_format(info))
#endregion
