extends Control

@onready var tabs: TabContainer = $Tabs

@onready var resolution_option: OptionButton = $Tabs/Graphics/Resolution
@onready var window_mode_option: OptionButton = $Tabs/Graphics/WindowMode
@onready var msaa_option: OptionButton = $Tabs/Graphics/MSAA
@onready var v_sync_option: CheckBox = $Tabs/Graphics/VSync
@onready var fps_limit_option: HSlider = $Tabs/Graphics/FPSLimit/HSlider
@onready var render_scale_option: HSlider = $Tabs/Graphics/RenderScale/HSlider
@onready var shadows_option: CheckBox = $Tabs/Graphics/Shadows


const SETTINGS_FILE = "user://settings.cfg"
var config := ConfigFile.new()

func _ready() -> void:
	visible = false
	load_settings()


func save_setting(section: String, key: String, value):
	config.load(SETTINGS_FILE)

	config.set_value(section, key, value)

	config.save(SETTINGS_FILE)


func load_settings():
	var err := config.load(SETTINGS_FILE)

	if err != OK:
		return

	var window_mode = config.get_value("graphics", "window_mode", 0)
	var vsync = config.get_value("graphics", "vsync", true)
	var fps_limit = config.get_value("graphics", "fps_limit", 60)
	var render_scale = config.get_value("graphics", "render_scale", 1.0)
	var msaa = config.get_value("graphics", "msaa", 0)
	var shadows = config.get_value("graphics", "shadows", true)

	var resolution_index = config.get_value(
		"graphics",
		"resolution_index",
		0
	)

	resolution_option.select(resolution_index)

	var parts = resolution_option.get_item_text(resolution_index).split(" x ")

	if parts.size() >= 2:
		set_resolution(
			Vector2i(
				parts[0].strip_edges().to_int(),
				parts[1].strip_edges().to_int()
			)
		)

	# Apply settings

	_on_window_mode_item_selected(window_mode)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

	Engine.max_fps = fps_limit

	get_viewport().scaling_3d_scale = render_scale

	set_msaa(msaa)

	for light in get_tree().get_nodes_in_group("light"):
		light.shadow_enabled = shadows
	
	# Update UI
	window_mode_option.select(window_mode)
	msaa_option.select(msaa)
	
	v_sync_option.set_pressed_no_signal(vsync)
	fps_limit_option.set_value_no_signal(fps_limit)
	render_scale_option.set_value_no_signal(render_scale)
	shadows_option.set_pressed_no_signal(shadows)


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
	
	if event.is_action_pressed("ui_next") && visible:
		tabs.current_tab += 1
		call_deferred("focus_current_tab")
	if event.is_action_pressed("ui_previous") && visible:
		tabs.current_tab -= 1
		call_deferred("focus_current_tab")


func focus_current_tab() -> void:
	var tab := tabs.get_current_tab_control()
	
	print(tab)
	
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
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

		1: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

		2: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	save_setting("graphics", "window_mode", index)


func _on_resolution_item_selected(index: int) -> void:
	save_setting("graphics", "resolution_index", index)
	
	var parts: PackedStringArray = resolution_option.get_item_text(index).split(" x ")
	 
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
	
	save_setting("graphics", "resolution", res)


func _on_v_sync_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
		)
	else:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_DISABLED
		)
	
	save_setting("graphics", "vsync", toggled_on)


func _on_fps_limit_value_changed(value: float) -> void:
	Engine.max_fps = int(value)
	
	save_setting("graphics", "fps_limit", int(value))


func _on_render_scale_value_changed(value: float) -> void:
	get_viewport().scaling_3d_scale = value
	
	save_setting("graphics", "render_scale", value)


func _on_msaa_item_selected(index: int) -> void:
	set_msaa(index)
	
	save_setting("graphics", "msaa", index)


func set_msaa(index):
	get_viewport().msaa_3d = index


func _on_shadows_toggled(toggled_on: bool) -> void:
	for light in get_tree().get_nodes_in_group("light"):
		light.shadow_enabled = toggled_on
	
	save_setting("graphics", "shadows", toggled_on)


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


func _on_kill_human_pressed() -> void:
	for human in get_tree().get_nodes_in_group("human"):
		human.queue_free()


func _on_open_config_pressed() -> void:
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path("user://settings.cfg"))


func _on_respawn_pressed() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		player.respawn()


func _on_quit_pressed() -> void:
	get_tree().quit()


#endregion
