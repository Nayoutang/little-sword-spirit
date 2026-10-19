extends SceneTree

func _initialize() -> void:
	call_deferred("run")
func capture(scene_path: String, output: String) -> void:
	change_scene_to_file(scene_path)
	await scene_changed
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
func run() -> void:
	assert("--mobile-preview" in OS.get_cmdline_user_args())
	root.get_node("RunState").suppress_persistence = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://.godot/mobile-preview")
	await capture("res://scenes/main_menu.tscn", "res://.godot/mobile-preview/menu.png")
	print("MOBILE LAYOUT PREVIEW: PASS")
	quit()
