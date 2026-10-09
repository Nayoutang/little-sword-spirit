extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(OS.get_environment("APPDATA").contains("expedition-restart-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.select_save_slot(1)
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/expedition-save-map.png")
	map.free()
	var menu = load("res://scenes/save_select.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/expedition-save-menu.png")
	menu.free()
	print("EXPEDITION SAVE PREVIEW: saved")
	quit()
