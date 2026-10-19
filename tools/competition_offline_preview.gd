extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.finale_state = "locked"
	state.bond_value = 0
	state.bond_stage = 0
	root.get_node("SpecialEventManager").reset()
	state.homecoming_pending = false
	var home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	await capture("res://.godot/competition_home.png")
	var events = root.get_node("SpecialEventManager")
	events.enqueue("near_death_clear")
	events.activate_next()
	home._request_homecoming_greeting()
	await capture("res://.godot/competition_event.png")
	home._start_feihualing("剑")
	await capture("res://.godot/competition_poetry.png")
	home.free()
	quit()
