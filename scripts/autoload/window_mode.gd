extends Node

# 启动时窗口最大化（见 project.godot 的 window/size/mode），F11 在全屏与最大化之间切换。
# 最大化窗口会贴合每台电脑的可用区域（扣掉任务栏和标题栏），不会像固定 1920×1080 窗口那样上下被裁掉。


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
