extends SceneTree

const Story = preload("res://scripts/data/chapter_two_story.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ch3-art-%s.png" % label)

func clear_scene() -> void:
	if current_scene != null:
		current_scene.free()

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.bond_value = 100
	state.bond_stage = 3
	state.chapter = 3
	state.chapter_trip = 1
	state.finale_state = "completed"
	state.finale_mode = "victory"
	for id in ["ch3_opening", "ch3_sword_tomb", "ch3_ending"]:
		for page in range(Story.STORIES[id]["pages"].size()):
			clear_scene()
			var scene = load("res://scenes/chapter_story.tscn").instantiate()
			scene.story_override = id
			root.add_child(scene)
			current_scene = scene
			scene.page_index = page
			scene._show_page()
			for i in range(scene._page_lines().size()): scene._reveal_line()
			await shot("%s-%d" % [id, page])
			if scene.story["pages"][page].has("choices"):
				scene._offer_choices(scene.story["pages"][page]["choices"])
				await shot("%s-choice" % id)
			if id == "ch3_sword_tomb" and page == 1:
				scene._show_reward("jiesi")
				await shot("reward-jiesi")
			if id == "ch3_ending" and page == 1:
				scene._show_reward("shoujian")
				await shot("reward-shoujian")
	clear_scene()
	state.start_new_run()
	state.chapter = 3
	state.route_layer = 19
	state.node_on_thread = true
	for trip in [1, 2]:
		state.chapter_trip = trip
		state.pending_encounter = state.EncounterType.BOSS
		var battle = load("res://scenes/battle.tscn").instantiate()
		battle.force_offline_companion = true
		root.add_child(battle)
		current_scene = battle
		await process_frame
		battle.xiaomo_threads.assign([0])
		battle._refresh_ui()
		await shot("boss-%d" % trip)
		clear_scene()
	print("Chapter three art preview complete")
	quit(0)
