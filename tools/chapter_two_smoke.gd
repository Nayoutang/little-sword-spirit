extends SceneTree

# 第二章 · 线头：章节状态、追线地图、紫线战斗、剧情场景。离线、不写存档。
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func mount_battle(state, encounter, layer: int, thread: bool):
	state.pending_encounter = encounter
	state.route_layer = layer
	state.node_on_thread = thread
	state.player_hp = state.player_max_hp
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.fixed_random_seed = 7
	root.add_child(battle)
	return battle

func run() -> void:
	var state = root.get_node("RunState")
	var enemies = root.get_node("EnemyDatabase")
	var codec = load("res://scripts/data/relationship_profile.gd")
	state.suppress_persistence = true

	# ---- 章节状态 ----
	state.chapter = 1
	state.finale_state = "completed"
	state.finale_mode = "victory"
	check(state.maybe_begin_chapter_two(), "同归后进入第二章")
	check(state.chapter == 2 and state.chapter_trip == 1 and state.pending_story == "ch2_opening", "第二章从第一趟、章首开始")
	check(not state.maybe_begin_chapter_two(), "不重复进入")
	check(state.chapter_layer_story() == "ch2_blacksmith" and state.chapter_boss() == "thread_blade_boss", "第一趟：铁匠铺 + 牵线的刀客")
	state.threads_cut = 7
	state.scroll_pages.assign(["duansi"])
	state.story_seen.assign(["ch2_opening"])
	var decoded: Dictionary = codec.decode(codec.encode(state))
	check(decoded.chapter == 2 and decoded.chapter_trip == 1 and decoded.threads_cut == 7, "章节进度可存读")
	check(decoded.scroll_pages == ["duansi"] and decoded.story_seen == ["ch2_opening"] and decoded.pending_story == "ch2_opening", "残页与剧情标记可存读")
	var legacy := ConfigFile.new()
	legacy.set_value("relationship", "bond_value", 30)
	var old: Dictionary = codec.decode(legacy)
	check(old.chapter == 1 and old.threads_cut == 0 and old.scroll_pages.is_empty(), "旧档默认第一章")
	check(state.thread_hits_required() == 2, "斩过 6 根后只需两击")
	state.threads_cut = 0
	check(state.thread_hits_required() == 3, "初始需三击")
	state.pending_story = ""
	state.scroll_pages.clear()

	# ---- 追线地图 ----
	state.start_new_run()
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check(map.thread_nodes.size() == 19, "紫线从第 1 层牵到首领")
	var previous = map.layers[0][0]
	var linked := true
	for node in map.thread_nodes:
		linked = linked and map.connections.get(previous, []).has(node)
		previous = node
	check(linked, "紫线沿着可走的路线")
	check(map.get_node("MapUI/Title").text.begins_with("追线图卷"), "第二章地图标题")
	var thread_lines := 0
	for child in map.get_node("MapContent").get_children():
		if child is Line2D and child.has_meta("thread"): thread_lines += 1
	check(thread_lines == 19, "画出紫线")
	var seed_before: int = state.map_seed
	var first_path: Array = map.thread_nodes.map(func(n): return map.layers[n.layer_index].find(n))
	map.queue_free()
	await process_frame
	var map2 = load("res://scenes/map.tscn").instantiate()
	root.add_child(map2)
	await process_frame
	check(state.map_seed == seed_before and map2.thread_nodes.map(func(n): return map2.layers[n.layer_index].find(n)) == first_path, "重进地图紫线不变")
	map2.queue_free()
	await process_frame
	state.clear_expedition()

	# ---- 敌人配置 ----
	for layer in [1, 2, 6, 12]:
		var on_roles: Array = enemies.get_chapter_two_roles(layer, 2, false, true)
		check(on_roles.any(func(r): return r in enemies.THREAD_THROWERS), "线上第%d层必有抛线者" % layer)
		var off_roles: Array = enemies.get_chapter_two_roles(layer, 2, false, false)
		check(not off_roles.any(func(r): return r in enemies.THREAD_THROWERS), "线外第%d层不缠她" % layer)

	# ---- 紫线战斗：挂线、改写意向、斩线 ----
	var battle = mount_battle(state, state.EncounterType.NORMAL, 1, true)
	await process_frame
	check(battle.chapter_two and battle.on_thread, "第二章线上战斗")
	check(battle.enemy_roles == [enemies.PUPPET], "第一层是一只提线木偶")
	check(battle.enemy_intents[0].get("thread", false), "木偶第一回合预告抛线")
	check(battle.get_node("BattleUI/EnemyArea/EnemyRow").get_child(0).get_node("Intent").text.contains("抛线"), "意向显示抛线")
	battle._resolve_enemy_turn()
	check(battle.xiaomo_threads == [0], "抛线后她身上一根线，木偶持线")
	await process_frame
	check(battle.companion_status_label.text.contains("被紫线缠住"), "她的意向被染紫")
	check(battle.get_node("BattleUI/CompanionPanel/Effect").text.contains("原本要出"), "仍显示她原本的意向")
	battle.companion_turn_pending = false
	battle.enemy_hps[0] = 200
	battle._damage_enemy_at(0, 1)
	battle._damage_enemy_at(0, 1)
	check(battle.xiaomo_threads.size() == 1 and battle.thread_hits[0] == 2, "两击还不够")
	battle._damage_enemy_at(0, 1)
	check(battle.xiaomo_threads.is_empty() and state.threads_cut == 1, "第三击斩线并计入默契")
	check(not battle.companion_status_label.text.contains("被紫线"), "斩断后意向当场恢复")
	# 被缠时回合结束：她不出手
	battle.xiaomo_threads.assign([0])
	battle.locked_companion_choice = {"card_id": "quick_slash", "reason": "测试", "source": "fallback"}
	var hp_before: int = battle.enemy_hps[0]
	battle.companion_turn_pending = false
	await battle._end_turn()
	check(battle.enemy_hps[0] == hp_before and battle.companion_last_card_id != "quick_slash", "被缠住的回合她不出手")
	# 两根线：被牵，持线者得护盾
	battle.xiaomo_threads.assign([0, 0])
	battle.enemy_intents.assign([{"type": battle.EnemyIntent.OTHER, "value": 0}])
	battle._resolve_enemy_turn()
	check(battle.enemy_guards[0] == root.get_node("BalanceConfig").THREAD_DRAGGED_GUARD, "被牵时持线者得护盾")
	# 击倒持线者，线全断
	var cut_before: int = state.threads_cut
	battle.enemy_guards[0] = 0
	battle.enemy_hps[0] = 3
	battle._damage_enemy_at(0, 10)
	check(battle.xiaomo_threads.is_empty() and state.threads_cut == cut_before + 2, "打倒持线者，两根线一起断")
	battle.queue_free()
	await process_frame

	# ---- 残页：断丝、回线 ----
	state.threads_cut = 0
	state.scroll_pages.assign(["duansi", "huixian"])
	battle = mount_battle(state, state.EncounterType.NORMAL, 1, true)
	await process_frame
	battle.enemy_hps[0] = 200
	battle.xiaomo_threads.assign([0])
	battle.enemy_intents.assign([{"type": battle.EnemyIntent.ATTACK, "value": 6}])
	battle._damage_enemy_at(0, 1)
	battle._damage_enemy_at(0, 1)
	check(battle.xiaomo_threads.is_empty(), "断丝：连续两击同一持线者就够三次")
	check(battle.enemy_intents[0].get("cancelled", false), "回线：持线者本回合行动作废")
	battle.queue_free()
	await process_frame
	state.scroll_pages.clear()

	# ---- 刀手借力、箱偶替线 ----
	battle = mount_battle(state, state.EncounterType.NORMAL, 6, true)
	await process_frame
	battle.enemy_roles.assign([enemies.BLADE, enemies.BOX])
	battle.enemy_hps.assign([60, 60])
	battle.player_hp = 90
	battle.block = 0
	battle.xiaomo_threads.assign([1])
	battle.enemy_intents.assign([{"type": battle.EnemyIntent.ATTACK, "value": 6, "borrow": true}, {"type": battle.EnemyIntent.OTHER, "value": 0}])
	battle._resolve_enemy_turn()
	check(battle.player_hp == 90 - 6 - root.get_node("BalanceConfig").THREAD_BLADE_BONUS, "她被缠时刀手 +4")
	battle.xiaomo_threads.clear()
	battle.enemy_roles.assign([enemies.PUPPET, enemies.BOX])
	battle._throw_thread(0)
	check(battle.xiaomo_threads == [1], "箱偶替同伴持线")
	battle.enemy_intents.assign([{"type": battle.EnemyIntent.OTHER, "value": 0}, {"type": battle.EnemyIntent.DEFEND, "value": 8, "support": true}])
	battle._resolve_enemy_turn()
	check(battle.enemy_guards[1] == 8 and battle.enemy_guards[0] == 0, "持线的箱偶只护自己")
	battle.queue_free()
	await process_frame

	# ---- 默契：她自己挣断第一根 ----
	state.threads_cut = 15
	battle = mount_battle(state, state.EncounterType.NORMAL, 1, true)
	await process_frame
	battle._throw_thread(0)
	check(battle.xiaomo_threads.is_empty(), "斩过 15 根后，第一根她自己挣断")
	battle._throw_thread(0)
	check(battle.xiaomo_threads.size() == 1, "第二根照常缠上")
	battle.queue_free()
	await process_frame
	state.threads_cut = 0

	# ---- 线外战斗不缠她 ----
	battle = mount_battle(state, state.EncounterType.NORMAL, 6, false)
	await process_frame
	check(not battle.enemy_roles.any(func(r): return r in enemies.THREAD_THROWERS), "线外战斗没有抛线者")
	battle.queue_free()
	await process_frame

	# ---- 首领：牵线的刀客 ----
	state.chapter_trip = 1
	battle = mount_battle(state, state.EncounterType.BOSS, 19, true)
	await process_frame
	check(battle._is_boss_battle() and battle._enemy_name(0) == enemies.THREAD_BOSS_NAME, "第一趟首领是牵线的刀客")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0].get("thread", false), "刀客第二步是抛线")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0].get("charging", false), "刀客第三步重斩")
	battle.queue_free()
	await process_frame

	# ---- 首领：戏班的看台人 ----
	state.chapter_trip = 2
	battle = mount_battle(state, state.EncounterType.BOSS, 19, true)
	await process_frame
	check(battle.troupe_boss and not battle._is_boss_battle(), "第二趟首领是看台人三人组")
	check(battle.enemy_roles == [enemies.BLADE, enemies.WATCHER, enemies.BLADE], "看台人带两个刀手")
	check(battle.enemy_intents[1].get("thread", false), "看台人抛线")
	check(battle.enemy_intents[0].get("heavy", false) != battle.enemy_intents[2].get("heavy", false), "两个刀手错开重击")
	battle.xiaomo_threads.assign([1, 1])
	battle.enemy_intents.assign([{"type": battle.EnemyIntent.OTHER, "value": 0}, enemies.thread_intent(enemies.WATCHER), {"type": battle.EnemyIntent.OTHER, "value": 0}])
	battle._resolve_enemy_turn()
	check(battle.enemy_guards[0] >= 6 and battle.enemy_guards[2] >= 6, "线满时看台人给刀手护盾")
	battle.queue_free()
	await process_frame
	state.complete_chapter_trip()
	check(state.chapter_trip == 3 and state.pending_story == "ch2_ending", "第二趟首领后进入章末")
	check(state.chapter_layer_story() == "" and state.chapter_label().contains("已完"), "本章剧情走完")

	# ---- 剧情场景：铁匠铺（远征中） ----
	state.chapter_trip = 1
	state.pending_story = ""
	state.start_new_run()
	state.checkpoint("story", {"story": "ch2_blacksmith"})
	check(state.has_expedition() and state.expedition_checkpoint.phase == "story", "剧情检查点有效")
	var scene = load("res://scenes/chapter_story.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(scene.in_expedition and scene.story_id == "ch2_blacksmith", "远征中播放铁匠铺")
	for i in range(40):
		if scene.waiting_choice: break
		scene.advance()
	check(scene.waiting_choice and scene.choice_box.get_child_count() == 2, "两条回应")
	scene.choose(0)
	for i in range(40):
		if scene.showing_reward or scene.finishing: break
		scene.advance()
	check(scene.showing_reward, "播完给残页")
	scene._take_scroll("duansi")
	check(state.has_scroll_page("duansi") and state.story_seen.has("ch2_blacksmith"), "获得断丝并记为看过")
	for i in range(4): await process_frame
	check(current_scene != null and current_scene.name == "Map", "播完回到地图")
	if current_scene != null: current_scene.queue_free()
	await process_frame

	# ---- 剧情场景：章末（在家） ----
	state.clear_expedition()
	state.pending_story = "ch2_ending"
	scene = load("res://scenes/chapter_story.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(not scene.in_expedition and scene.story_id == "ch2_ending", "在家播章末")
	for i in range(40):
		if scene.finishing: break
		scene.advance()
	check(state.pending_story == "", "章末播完清空")

	print("Chapter two smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)
