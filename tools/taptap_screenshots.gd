extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func mount(path: String):
	if current_scene != null:
		current_scene.free()
	var scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene

func capture(name: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_jpg("res://.godot/taptap-screenshots/" + name + ".jpg", 0.94) == OK)

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(2))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://.godot/taptap-screenshots")
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.finale_state = "locked"
	state.bond_value = 25
	state.bond_stage = 1
	root.get_node("SpecialEventManager").reset()
	state.start_new_run()
	state.route_layer = 4
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = mount("res://scenes/battle.tscn")
	await capture("01-战斗与小墨协作")
	state.start_new_run()
	mount("res://scenes/map.tscn")
	await capture("03-远征路线")
	state.homecoming_pending = false
	var home = mount("res://scenes/home.tscn")
	home._start_feihualing("剑")
	home.game_input.text = "十年磨一剑，霜刃未曾试"
	home._send_game_message()
	await capture("02-飞花令与剑意领悟")
	home._on_game_leave()
	await capture("04-家中小墨")
	print("TAPTAP SCREENSHOTS: captured 4 actual gameplay frames at 1920x1080")
	quit()
