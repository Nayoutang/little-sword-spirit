extends SceneTree

# 第二章画面截图：追线地图、紫线战斗、剧情页、家中章节标签。输出到 .godot/ch2-*.png
func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for index in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/ch2-%s.png" % name)

func swap(scene_path: String):
	if current_scene != null:
		current_scene.free()
	var scene = load(scene_path).instantiate()
	if "force_offline_companion" in scene: scene.force_offline_companion = true
	if "preview_offline" in scene: scene.preview_offline = true
	root.add_child(scene)
	current_scene = scene
	return scene

func run() -> void:
	var state = root.get_node("RunState")
	var enemies = root.get_node("EnemyDatabase")
	state.suppress_persistence = true
	state.intro_done = true
	state.bond_value = 100
	state.bond_stage = 3
	state.finale_state = "completed"
	state.finale_mode = "victory"
	state.chapter = 2
	state.chapter_trip = 1
	state.feihualing_state = "unlocked"
	state.start_new_run()
	swap("res://scenes/map.tscn")
	await shot("map")

	state.route_layer = 6
	state.node_on_thread = true
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = swap("res://scenes/battle.tscn")
	await process_frame
	battle.enemy_roles.assign([enemies.THREADER, enemies.BLADE])
	battle._build_enemy_display()
	battle.xiaomo_threads.assign([0])
	battle.thread_hits[0] = 1
	battle.enemy_action_step = 0
	battle._roll_enemy_intents()
	battle._refresh_ui()
	await shot("battle-bound")

	state.pending_story = "ch2_opening"
	state.clear_expedition()
	var story = swap("res://scenes/chapter_story.tscn")
	await process_frame
	for i in range(3): story.advance()
	await shot("story-opening")

	state.start_new_run()
	state.checkpoint("story", {"story": "ch2_troupe"})
	story = swap("res://scenes/chapter_story.tscn")
	await process_frame
	for i in range(12):
		if story.waiting_choice: break
		story.advance()
	await shot("story-choice")

	state.clear_expedition()
	state.pending_story = ""
	swap("res://scenes/home.tscn")
	await shot("home")
	quit(0)
