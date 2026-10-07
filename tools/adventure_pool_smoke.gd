extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.learned_sword_intents.clear()
	state.recent_adventures.clear()
	var first_cycle: Array[int] = []
	for attempt in range(100):
		state.start_new_run()
		var previous: int = state.recent_adventures.back() if not state.recent_adventures.is_empty() else -1
		var selected: int = state.draw_comic_adventure(5)
		assert(selected >= 0 and selected != previous)
		if attempt < 5:
			assert(not first_cycle.has(selected))
			first_cycle.append(selected)
		assert(state.run_adventures.size() == 1)
	# 地图每一条路都恰有三次奇遇，不与宝箱或首领冲突。
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	for seed_value in range(100):
		map.map_rng.seed = seed_value
		map._build_node_type_plan()
		for column in range(map.ROUTE_COUNT):
			var adventure_count := 0
			for layer in range(map.TOTAL_LAYERS):
				var types: Array = map.layer_node_types[layer]
				if column < types.size() and types[column] == RouteNode.NodeType.ADVENTURE:
					assert(layer in [5, 10, 17])
					adventure_count += 1
			assert(adventure_count == 3)
		assert(map.layer_node_types[8][0] == RouteNode.NodeType.TREASURE)
		assert(map.layer_node_types[18][0] == RouteNode.NodeType.TREASURE)
		assert(map.layer_node_types[19][0] == RouteNode.NodeType.BOSS)
	map.free()
	# 离线入口可正常退出，输入非法令字不能启动网络或给予奖励。
	state.start_new_run()
	state.player_hp = 42
	state.route_layer = 6
	var scene = load("res://scenes/expedition_poetry.tscn").instantiate()
	scene.force_offline = true
	root.add_child(scene)
	current_scene = scene
	assert(scene.send.disabled and not scene.input.editable)
	assert(scene.get_node("FeihualingLayer/GameScreen/ExitButton").text == "继续赶路")
	assert(scene.get_node("FeihualingLayer/GameScreen/GameLog").text.contains("剑意"))
	if "--poetry-screenshot" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/expedition-poetry.png")
	# 与正式对局相同的已接受诗句回执，验证授予、提示和结束日志。
	scene.started = true
	scene.controller.game = FeihualingGame.new("霜")
	scene.controller.game.player_rounds = 1
	scene.controller.rounds_before_turn = 0
	scene.controller.pending_intent_id = CompanionCardDatabase.FROST_COLD
	scene.controller.player_text = "霜刃未曾试"
	scene.controller._apply_outcome({"finished": true, "player_won": true, "reason": "smoke"})
	assert(state.learned_sword_intents.has(CompanionCardDatabase.FROST_COLD))
	assert(scene.log_text.get_parsed_text().contains("剑意领悟"))
	assert(scene.send.disabled)
	assert(state.current_run_journal.any(func(fact: Dictionary): return fact.get("category", "") == "poetry"))
	scene._leave()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/map.tscn")
	assert(state.player_hp == 42 and state.route_layer == 6)
	assert(state.run_adventures.is_empty())
	# 通过普通奇遇入口验证飞花令重定向。
	change_scene_to_file("res://scenes/adventure.tscn")
	# 这次已经开始抽取；强制下一次只剩飞花令。
	await process_frame
	state.run_adventures.assign([0, 1, 2, 3, 4])
	change_scene_to_file("res://scenes/adventure.tscn")
	for step in range(6):
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/expedition_poetry.tscn")
	assert(state.player_hp == 42)
	for layer in [5, 10, 17]:
		state.start_new_run()
		change_scene_to_file("res://scenes/map.tscn")
		await process_frame
		await process_frame
		state.route_layer = layer
		current_scene.enter_node(RouteNode.NodeType.ADVENTURE)
		await process_frame
		await process_frame
		var expected := "res://scenes/adventure.tscn" if layer == 5 else "res://scenes/expedition_poetry.tscn"
		assert(current_scene.scene_file_path == expected)
	print("ADVENTURE POOL: PASS (100 map seeds: 1 comic + 2 poetry on every route; comic rotation, learning, offline exit)")
	quit()

