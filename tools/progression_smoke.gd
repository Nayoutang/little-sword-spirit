extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	var enemies = root.get_node("EnemyDatabase")
	var map_script = load("res://scripts/map/map.gd")
	var plan = map_script.new()
	for seed_value in range(128):
		plan.map_rng.seed = seed_value
		plan._build_node_type_plan()
		check(plan.layer_node_types.size() == 20, "路线必须20层")
		var elites := 0
		for layer in range(1, 19):
			var types: Array = plan.layer_node_types[layer]
			if layer in [8, 18]:
				check(types.count(RouteNode.NodeType.TREASURE) == 5, "两次整备宝箱")
			elif layer == 10:
				check(types.count(RouteNode.NodeType.ADVENTURE) == 5, "中途奇遇路线")
			else:
				check(types.has(RouteNode.NodeType.BATTLE), "每个非整备层保留战斗路线")
			if layer <= 3:
				check(not types.has(RouteNode.NodeType.ELITE), "前3层无显式精英")
			elites += types.count(RouteNode.NodeType.ELITE)
		check(elites == 4, "四个可选精英节点")
	plan.free()
	var previous_hp := 0
	var previous_attack := 0
	for layer in range(1, 20):
		var normal: Dictionary = enemies.get_normal_config(layer)
		var attack := int(enemies.get_role_intent(enemies.SWORDSMAN, 0, false, layer)["value"])
		check(normal["hp_min"] >= previous_hp and attack >= previous_attack, "深度曲线单调")
		check(enemies.get_elite_config(layer)["hp_min"] > normal["hp_min"], "精英生命高于普通")
		previous_hp = normal["hp_min"]
		previous_attack = attack
	check(enemies.get_normal_config(999) == enemies.get_normal_config(19), "深度上限")
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	var reachable: Array = [map.layers[0][0]]
	for layer in range(19):
		var next_nodes: Array = []
		for node in reachable:
			for target in map.connections[node]:
				if target not in next_nodes:
					next_nodes.append(target)
		reachable = next_nodes
	check(reachable.has(map.layers[19][0]), "起点可达最终Boss")
	map._set_map_scroll(99999)
	check(map.layers[19][0].global_position.y >= 130, "末层可滚动进入可见区域")
	map.queue_free()
	await process_frame
	state.route_layer = 19
	state.pending_encounter = state.EncounterType.BOSS
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	check(battle.enemy_hps[0] == 320 and battle.enemy_intents[0]["value"] == 12, "最终Boss320生命12普攻")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0]["value"] == 16, "最终Boss护盾16")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0]["value"] == 26, "最终Boss重斩26")
	battle.enemy_guards[0] = 100
	for hit in range(3):
		battle._damage_enemy_at(0, 1)
	check(battle.enemy_intents[0]["value"] == 12 and battle.enemy_intents[0].get("interrupted", false), "最终Boss打断使用成长后普攻伤害")
	battle.queue_free()
	await process_frame
	print("Progression smoke failures: ", failures)
	quit(0 if failures == 0 else 1)
