extends RefCounted

static func install(host: Node, ui: Node, position: Vector2) -> void:
	var button := Button.new()
	button.name = "SaveExitButton"
	button.text = "保存并退出"
	button.position = position
	button.size = Vector2(220, 48)
	preload("res://scripts/ui/ink_ui_skin.gd").style_button(button)
	ui.add_child(button)
	button.pressed.connect(func():
		button.disabled = true
		var error := RunState.save_and_exit(host)
		if error != OK:
			button.disabled = false
			button.text = "保存失败，请重试"
			button.tooltip_text = "保存未完成，错误码：%d" % error
	)
