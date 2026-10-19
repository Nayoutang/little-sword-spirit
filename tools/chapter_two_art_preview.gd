extends SceneTree

# 只读试玩状态、离线截图；不写玩家存档。
const Story = preload("res://scripts/data/chapter_two_story.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ch2-art-%s.png" % label)

func clear_scene() -> void:
	if current_scene != null:
		current_scene.free()

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.bond_value = 100
	state.bond_stage = 3
	state.chapter = 2
	state.chapter_trip = 1
	state.finale_state = "completed"
	state.finale_mode = "victory"
	for id in ["ch2_opening", "ch2_blacksmith", "ch2_troupe", "ch2_ending"]:
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
			if id == "ch2_blacksmith" and page == 2:
				scene._show_reward("duansi")
				await shot("reward")
	clear_scene()
	state.start_new_run()
	state.route_layer = 6
	state.node_on_thread = true
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.fixed_random_seed = 7
	root.add_child(battle)
	current_scene = battle
	await process_frame
	for roles in [["thread_master", "puppet_blade"], ["thread_puppet", "stand_in_box"]]:
		battle.enemy_roles.assign(roles)
		battle._build_enemy_display()
		await process_frame
		battle.xiaomo_threads.assign([0, 1])
		battle._roll_enemy_intents()
		battle._refresh_ui()
		await shot("battle-%s" % roles[0])
	battle.thread_art.snap(0, false)
	await shot("cut")
	clear_scene()
	for trip in [1, 2]:
		state.chapter_trip = trip
		state.pending_encounter = state.EncounterType.BOSS
		battle = load("res://scenes/battle.tscn").instantiate()
		battle.force_offline_companion = true
		root.add_child(battle)
		current_scene = battle
		await process_frame
		battle.xiaomo_threads.assign([0])
		battle._refresh_ui()
		await shot("boss-%d" % trip)
		clear_scene()
	print("Chapter two art preview complete")
	quit(0)
