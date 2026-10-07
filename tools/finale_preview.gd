extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.bond_value = 100
	state.finale_state = "locked"
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/concepts/finale_invitation_implemented.png")
	home.free()
	for mode in ["victory", "sacrifice", "refusal"]:
		state.finale_state = "story"
		state.finale_mode = mode
		var scene = load("res://scenes/finale.tscn").instantiate()
		root.add_child(scene)
		if mode == "sacrifice": scene.page_index = 1
		if mode == "refusal": scene.page_index = 2
		scene._show_page()
		for i in range(8): scene.page.reveal_next()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/concepts/finale_" + mode + "_implemented.png")
		scene.free()
	print("FINALE RENDER: PASS")
	quit()
