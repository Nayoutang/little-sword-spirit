extends SceneTree

# 第三章 · 提线：进入条件、存读、剑冢、两个首领（剑灵 / 戏先生收线）、借丝、收剑、终章。离线、不写存档。
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

func play_through(scene) -> void:
	for i in range(60):
		if scene.finishing or scene.showing_reward: return
		if scene.waiting_choice:
			scene.choose(0)
			continue
		scene.advance()

func run() -> void:
	var state = root.get_node("RunState")
	var enemies = root.get_node("EnemyDatabase")
	var codec = load("res://scripts/data/relationship_profile.gd")
	state.suppress_persistence = true

	# ---- 进入第三章 ----
	state.chapter = 2
	state.chapter_trip = 3
	state.pending_story = "ch2_ending"
	check(not state.maybe_begin_chapter_three(), "章末还没播完不进第三章")
	state.pending_story = ""
	state.story_seen.assign(["ch2_opening", "ch2_ending"])
	check(state.maybe_begin_chapter_three(), "章末播完后进入第三章")
	check(state.chapter == 3 and state.chapter_trip == 1 and state.pending_story == "ch3_opening", "第三章从第一趟、章首开始")
	check(not state.maybe_begin_chapter_three(), "不重复进入")
	check(state.uses_thread_rules() and not state.is_chapter_two(), "第三章沿用紫线规则")
	check(state.chapter_layer_story() == "ch3_sword_tomb" and state.chapter_boss() == enemies.BOUND_SPIRIT, "第一趟：剑冢 + 被牵着的剑灵")
	check(state.chapter_label() == "第三章 · 提线  1/2", "章节标签")
	state.scroll_pages.assign(["duansi", "huixian", "jiesi"])
	var decoded: Dictionary = codec.decode(codec.encode(state))
	check(decoded.chapter == 3 and decoded.chapter_trip == 1 and decoded.pending_story == "ch3_opening", "第三章进度可存读")
	check(decoded.scroll_pages == ["duansi", "huixian", "jiesi"], "借丝可存读")
	state.pending_story = ""
	state.scroll_pages.clear()

	# ---- 首领一：被牵着的剑灵 ----
	var battle = mount_battle(state, state.EncounterType.BOSS, 19, true)
	await process_frame
	check(battle.chapter_two and battle._is_boss_battle(), "第三章首领战走紫线规则")
	check(battle._enemy_name(0) == "被牵着的剑灵", "第一趟首领名字")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0].get("thread", false), "剑灵第二步抛线")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0].get("charging", false) and not battle.enemy_intents[0].get("reel", false), "剑灵第三步是重斩，不是收线")
	battle.queue_free()
	await process_frame
	state.complete_chapter_trip()
	check(state.chapter_trip == 2 and state.pending_story == "ch3_trip1_return", "剑灵打完回家播归途")
	state.pending_story = ""

	# ---- 首领二：戏先生收线 ----
	check(state.chapter_boss() == enemies.PUPPETEER and state.chapter_layer_story() == "", "第二趟首领是戏先生")
	battle = mount_battle(state, state.EncounterType.BOSS, 19, true)
	await process_frame
	check(battle._enemy_name(0) == "戏先生", "戏先生名字")
	battle._roll_enemy_intents()
	battle._roll_enemy_intents()
	var reel: Dictionary = battle.enemy_intents[0]
	check(reel.get("charging", false) and reel.get("reel", false), "第三步收线")
	check(int(reel.value) <= int(enemies.get_boss_config(19)["attack"]), "收线伤害只按普攻")
	battle._refresh_ui()
	await process_frame
	var intent_text: String = battle.get_node("BattleUI/EnemyArea/EnemyRow").get_child(0).get_node("Intent").text
	check(intent_text.begins_with("收线"), "意向显示收线：" + intent_text)
	battle.player_hp = 90
	battle.block = 0
	battle.xiaomo_threads.clear()
	battle._resolve_enemy_turn()
	check(battle.xiaomo_threads.size() == 2, "没打断：小墨被整个牵走（两根线）")
	# 默契够了：第一根她自己挣断
	battle.xiaomo_threads.clear()
	battle.thread_self_break_used = false
	state.threads_cut = 15
	battle.enemy_intents.assign([reel.duplicate()])
	battle._resolve_enemy_turn()
	check(battle.xiaomo_threads.size() == 1, "默契够了，收线只缠上一根")
	state.threads_cut = 0
	# 打断收线
	battle.xiaomo_threads.clear()
	battle.enemy_intents.assign([reel.duplicate()])
	battle.boss_charge_hits = 0
	battle.enemy_hps[0] = 300
	for i in range(3):
		battle._damage_enemy_at(0, 1)
	check(not battle.enemy_intents[0].get("charging", false), "命中三次打断收线")
	battle._resolve_enemy_turn()
	check(battle.xiaomo_threads.is_empty(), "打断后不收线")
	battle.queue_free()
	await process_frame

	# ---- 借丝：斩线抽牌 ----
	state.scroll_pages.assign(["jiesi"])
	battle = mount_battle(state, state.EncounterType.NORMAL, 1, true)
	await process_frame
	battle.enemy_hps[0] = 200
	battle.xiaomo_threads.assign([0])
	battle.hand.remove_at(battle.hand.size() - 1)
	var hand_before: int = battle.hand.size()
	for i in range(3):
		battle._damage_enemy_at(0, 1)
	check(battle.xiaomo_threads.is_empty() and battle.hand.size() == hand_before + 1, "借丝：斩线抽一张")
	battle.queue_free()
	await process_frame

	# ---- 收剑：本回合没出攻击牌，她伤害翻倍 ----
	battle = mount_battle(state, state.EncounterType.NORMAL, 6, false)
	await process_frame
	var slash := {"card_id": "quick_slash", "reason": "测试", "source": "fallback"}
	var dealt := []
	for flag in [false, true]:
		battle.enemy_hps.assign([200, 200])
		battle.enemy_guards.assign([0, 0])
		battle.enemy_vulnerabilities.assign([0, 0])
		battle.shoujian_turn = flag
		battle._apply_companion_card(slash)
		dealt.append(400 - battle.enemy_hps[0] - battle.enemy_hps[1])
	battle.shoujian_turn = false
	check(dealt[0] > 0 and dealt[1] == dealt[0] * 2, "收剑：她的攻击翻倍（%d → %d）" % dealt)
	# 触发条件：有收剑、本回合没出攻击牌
	state.scroll_pages.assign(["shoujian"])
	battle.attacked_this_turn = false
	check(state.has_scroll_page("shoujian") and not battle.attacked_this_turn, "收剑条件成立")
	battle.queue_free()
	await process_frame
	state.scroll_pages.clear()

	# ---- 戏先生打完：终章 ----
	state.complete_chapter_trip()
	check(state.chapter_trip == 3 and state.pending_story == "ch3_ending", "戏先生打完回家播终章")
	check(state.chapter_label().contains("自由历练") and state.chapter_layer_story() == "", "终章后自由历练")
	state.complete_chapter_trip()
	check(state.chapter_trip == 3, "自由历练不再推进")

	# ---- 剧情：剑冢（远征中给借丝） ----
	state.chapter_trip = 1
	state.pending_story = ""
	state.start_new_run()
	state.checkpoint("story", {"story": "ch3_sword_tomb"})
	var scene = load("res://scenes/chapter_story.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(scene.in_expedition and scene.story_id == "ch3_sword_tomb", "远征中播放剑冢")
	play_through(scene)
	check(scene.showing_reward, "剑冢播完给残页")
	scene._take_scroll("jiesi")
	check(state.has_scroll_page("jiesi") and state.story_seen.has("ch3_sword_tomb"), "获得借丝")
	check(str(state.shared_history.back().get("summary", "")).contains("借丝"), "共同经历里写的是残页名字")
	for i in range(4): await process_frame
	if current_scene != null: current_scene.queue_free()
	await process_frame
	state.clear_expedition()

	# ---- 剧情：章首（在家，两条回应） ----
	state.pending_story = "ch3_opening"
	scene = load("res://scenes/chapter_story.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(not scene.in_expedition and scene.story_id == "ch3_opening", "在家播第三章章首")
	for i in range(40):
		if scene.waiting_choice: break
		scene.advance()
	check(scene.waiting_choice and scene.choice_box.get_child_count() == 2, "章首两条回应")
	scene.choose(1)
	play_through(scene)
	check(state.pending_story == "", "章首播完清空")
	for i in range(4): await process_frame
	if current_scene != null: current_scene.queue_free()
	await process_frame

	# ---- 剧情：终章（在家给收剑） ----
	state.pending_story = "ch3_ending"
	scene = load("res://scenes/chapter_story.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	play_through(scene)
	check(scene.showing_reward, "终章播完给收剑")
	scene._take_scroll("shoujian")
	check(state.has_scroll_page("shoujian") and state.pending_story == "", "获得收剑并清空")

	print("Chapter three smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)
