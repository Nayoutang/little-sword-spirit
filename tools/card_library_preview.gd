extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.homecoming_pending = false
	state.bond_value = 85
	state.bond_stage = 3
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	await create_timer(0.2).timeout
	await shot("res://art/previews/card-library-home-v1.png")
	var library = home.get_node("CardLibrary")
	library.open()
	await create_timer(0.2).timeout
	await shot("res://art/previews/card-library-all-v1.png")
	library.search.text = "磨剑"
	library._refresh()
	await create_timer(0.15).timeout
	await shot("res://art/previews/card-library-detail-v1.png")
	library.search.clear()
	library._refresh()
	library.collection_filter.select(2)
	library._refresh()
	await create_timer(0.15).timeout
	await shot("res://art/previews/card-library-companion-v1.png")
	home.free()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	root.add_child(battle)
	await create_timer(0.2).timeout
	battle._show_ink_event()
	await create_timer(0.16).timeout
	await shot("res://art/previews/brilliance-entrance-v1.png")
	await create_timer(0.38).timeout
	await shot("res://art/previews/brilliance-impact-v1.png")
	await create_timer(0.66).timeout
	await shot("res://art/previews/brilliance-settle-v1.png")
	await create_timer(0.45).timeout
	await shot("res://art/previews/brilliance-exit-v1.png")
	print("CARD_LIBRARY_PREVIEW saved")
	quit()
