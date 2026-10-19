extends SceneTree

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
func mount(path: String) -> Node:
	if current_scene != null:
		current_scene.free()
	var scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene
func settle() -> void:
	for frame in range(4):
		await process_frame
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	var mode = root.get_node("WindowMode")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "Android locked to landscape")
	# Instantiate the presentation helper explicitly for the regression runner,
	# which also covers ordinary desktop settings in separate tests.
	var support = mode.get_node_or_null("MobileSupport")
	if support == null:
		support = load("res://scripts/ui/mobile_support.gd").new()
		mode.add_child(support)
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "letterbox aspect")
	check(not quit_on_go_back, "Android back does not quit immediately")
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var menu = mount("res://scenes/main_menu.tscn")
	await settle()
	menu._open_settings()
	support.handle_back()
	check(not menu.get_node("SettingsPanel").visible, "back closes settings")
	support.handle_back()
	check(support.back_dialog.visible, "menu exit asks first")
	support.handle_back()
	check(not support.back_dialog.visible, "second back cancels")
	for dimensions in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(2560, 1600)]:
		root.size = dimensions
		await settle()
		var bottom_button: Control = menu.get_node("Stage/Quit")
		check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(bottom_button.get_global_rect()), "menu button fits %s" % dimensions)
	state.intro_done = true
	state.start_new_run()
	var map = mount("res://scenes/map.tscn")
	await settle()
	var before: float = map.map_scroll
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0, 150)
	map._unhandled_input(drag)
	check(map.map_scroll > before, "map swipe scrolls")
	var route := RouteNode.new()
	root.add_child(route)
	route.setup(RouteNode.NodeType.BATTLE, 1)
	route.is_selectable = true
	var taps := [0]
	route.selected.connect(func(_node): taps[0] += 1)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(100, 100)
	route._input_event(root, press, 0)
	drag.position = Vector2(100, 200)
	route._input(drag)
	var release := InputEventScreenTouch.new()
	release.position = Vector2(100, 200)
	route._input(release)
	check(taps[0] == 0, "drag does not select a route")
	route._input_event(root, press, 0)
	release.position = press.position
	route._input(release)
	check(taps[0] == 1, "tap selects exactly once")
	route.free()
	var home = mount("res://scenes/home.tscn")
	await settle()
	var field: LineEdit = home.get_node("ChatUI/ChatPanel/Input")
	var send: Control = home.get_node("ChatUI/ChatPanel/SendButton")
	var original_top := field.offset_top
	var send_top := send.offset_top
	support._avoid_keyboard(field, int(root.size.y * 0.6))
	check(field.offset_top < original_top, "keyboard lifts input")
	check(send.offset_top < send_top, "keyboard lifts send button")
	support._restore_keyboard_nodes()
	check(is_equal_approx(field.offset_top, original_top), "keyboard restores input")
	check(is_equal_approx(send.offset_top, send_top), "keyboard restores send button")
	if failures == 0:
		print("MOBILE ADAPTATION: PASS")
	quit(1 if failures else 0)
