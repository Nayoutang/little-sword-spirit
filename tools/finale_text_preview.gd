extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	for mode in ["refusal", "arrival", "victory", "sacrifice"]:
		state.finale_mode = mode
		var scene = load("res://scenes/finale.tscn").instantiate()
		root.add_child(scene)
		for index in range(scene.pages.size()):
			scene.page_index = index
			scene._show_page()
			while scene.page.reveal_next():
				pass
			assert(not scene.get_node("FinaleUI/Caption").visible)
			assert(not scene.get_node("FinaleUI/Paper").visible)
			for panel in scene.page.panels:
				assert(panel.get_child_count() > 0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/finale_text_%s_%s.png" % [mode, scene.pages[index]])
		scene.free()
	print("FINALE COMIC TEXT: PASS (all pages and refusal variant)")
	quit()
