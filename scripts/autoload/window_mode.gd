extends Node

const SETTINGS_PATH := "user://display_settings.cfg"
var master_volume := 1.0

func _ready() -> void:
	if is_mobile():
		var mobile_support := preload("res://scripts/ui/mobile_support.gd").new()
		mobile_support.name = "MobileSupport"
		add_child(mobile_support)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
		_apply_volume()
		if not is_mobile() and bool(config.get_value("display", "fullscreen", false)):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(enabled: bool) -> void:
	if is_mobile():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_MAXIMIZED)
	_save_settings()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_settings()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume == 0.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", is_fullscreen())
	config.set_value("audio", "master", master_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("设置保存失败：%d" % error)

# 启动时窗口最大化（见 project.godot 的 window/size/mode），F11 在全屏与最大化之间切换。
# 最大化窗口会贴合每台电脑的可用区域（扣掉任务栏和标题栏），不会像固定 1920×1080 窗口那样上下被裁掉。


func _input(event: InputEvent) -> void:
	if not is_mobile() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()

func is_mobile() -> bool:
	return OS.has_feature("android") or "--mobile-preview" in OS.get_cmdline_user_args()
