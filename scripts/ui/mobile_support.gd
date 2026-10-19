extends Node

# Presentation-only child of WindowMode. Scene references are weak so navigation
# cannot keep an outgoing scene alive. Saves remain owned by RunState.
var back_dialog: ConfirmationDialog
var keyboard_nodes: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	get_tree().quit_on_go_back = false
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	Engine.max_fps = 60
	if not OS.has_feature("android"):
		Input.emulate_touch_from_mouse = true
	back_dialog = ConfirmationDialog.new()
	back_dialog.name = "MobileBackDialog"
	back_dialog.title = "返回"
	back_dialog.ok_button_text = "返回主菜单"
	back_dialog.cancel_button_text = "继续游戏"
	back_dialog.add_theme_font_override("font", preload("res://ui/shared/comic_font.tres"))
	back_dialog.add_theme_font_size_override("font_size", 32)
	for button in [back_dialog.get_ok_button(), back_dialog.get_cancel_button()]:
		button.custom_minimum_size = Vector2(260, 88)
		button.add_theme_font_size_override("font_size", 32)
	add_child(back_dialog)
	back_dialog.confirmed.connect(_confirm_back)
	get_tree().scene_changed.connect(_restore_keyboard_nodes)

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_save_current_profile()

func handle_back() -> void:
	if back_dialog.visible:
		back_dialog.hide()
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and DisplayServer.virtual_keyboard_get_height() > 0:
		DisplayServer.virtual_keyboard_hide()
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		_restore_keyboard_nodes()
		return
	var scene := get_tree().current_scene
	if scene == null or RunState.is_scene_transition_pending():
		return
	# A scene may dismiss its own overlay before asking to leave the scene.
	if scene.has_method("handle_mobile_back") and scene.handle_mobile_back():
		return
	for library in scene.find_children("*", "CanvasLayer", true, false):
		if library.get_script() == preload("res://scripts/ui/card_library.gd") and library.overlay != null and library.overlay.visible:
			library.close()
			return
	var on_menu := scene.scene_file_path == "res://scenes/main_menu.tscn"
	back_dialog.ok_button_text = "退出游戏" if on_menu else "返回主菜单"
	back_dialog.dialog_text = "退出游戏？" if on_menu else "返回主菜单？会保留最近的检查点。"
	back_dialog.popup_centered(Vector2i(960, 320))

func _confirm_back() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if not _save_current_profile():
		back_dialog.dialog_text = "保存失败，请检查剩余空间后重试。"
		back_dialog.popup_centered(Vector2i(960, 320))
		return
	if scene.scene_file_path == "res://scenes/main_menu.tscn":
		get_tree().quit()
	else:
		RunState.navigate("main_menu", scene)

func _save_current_profile() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path in ["res://scenes/main_menu.tscn", "res://scenes/save_select.tscn"]:
		return true
	RunState.save_persistent_state()
	return RunState.last_save_error == OK

func _process(_delta: float) -> void:
	_restore_keyboard_nodes()
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var keyboard_height := DisplayServer.virtual_keyboard_get_height()
	var focused := get_viewport().gui_get_focus_owner()
	if keyboard_height <= 0 or not focused is LineEdit or not focused.is_visible_in_tree():
		return
	_avoid_keyboard(focused, keyboard_height)

func _avoid_keyboard(field: LineEdit, keyboard_height: int) -> void:
	var transform := get_tree().root.get_screen_transform()
	var keyboard_top := (transform.affine_inverse() * Vector2(0, get_tree().root.size.y - keyboard_height)).y
	var shift := maxf(field.get_global_rect().end.y + 32.0 - keyboard_top, 0.0)
	if shift == 0:
		return
	var peers: Array[Node] = []
	match str(field.name):
		"NameInput":
			peers.append(field.get_parent())
		"Input":
			for peer_name in ["Input", "InputArt", "SendButton"]:
				peers.append(field.get_parent().get_node(peer_name))
		"GameInput":
			for peer_name in ["GameInput", "GameSendButton"]:
				peers.append(field.get_parent().get_node(peer_name))
		_:
			peers.append(field.get_parent() if field.get_parent() is Container else field)
	for peer in peers:
		if peer is Control:
			keyboard_nodes.append({"node": weakref(peer), "top": peer.offset_top, "bottom": peer.offset_bottom})
			peer.offset_top -= shift
			peer.offset_bottom -= shift

func _restore_keyboard_nodes() -> void:
	for entry in keyboard_nodes:
		var control = entry.node.get_ref()
		if is_instance_valid(control):
			control.offset_top = entry.top
			control.offset_bottom = entry.bottom
	keyboard_nodes.clear()
