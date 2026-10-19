extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.finale_state = "locked"
	var scene = load("res://scenes/home.tscn").instantiate()
	scene.preview_offline = true
	root.add_child(scene)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/home_cutout_v2_preview.png")
	quit()
