extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(scene: Node, path: String) -> void:
	root.add_child(scene)
	await create_timer(0.5).timeout
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	scene.free()

func run() -> void:
	root.get_node("RunState").suppress_persistence = true
	await capture(load("res://scenes/intro.tscn").instantiate(), "res://.godot/comic_intro_preview.png")
	var naming = load("res://scenes/intro.tscn").instantiate()
	root.add_child(naming)
	naming._next_page()
	while naming.page.revealed_count < 6:
		naming._advance()
	naming._advance()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/comic_name_preview.png")
	naming.name_input.text = "旅人"
	naming._confirm_name()
	naming._advance()
	naming._advance()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/comic_name_reply_preview.png")
	naming.free()
	var adventure = load("res://scenes/adventure.tscn").instantiate()
	adventure.adventure_index = 0
	adventure.force_offline = true
	root.add_child(adventure)
	while not adventure.get_node("AdventureUI/Page").is_complete():
		adventure._advance()
	adventure._advance()
	adventure._advance()
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/comic_adventure_preview.png")
	adventure.free()
	quit()
