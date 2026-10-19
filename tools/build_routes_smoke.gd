extends SceneTree

# 2026-10-19 构筑路线与自由历练：默契倾向、9 张新牌、3 件信物、剑境、首领池、敌人混编。离线、不写存档。
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func fresh_battle(state, encounter = 0, layer := 6, thread := false):
	state.pending_encounter = encounter
	state.route_layer = layer
	state.node_on_thread = thread
	state.player_hp = state.player_max_hp
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.fixed_random_seed = 11
	root.add_child(battle)
	await process_frame
	battle.companion_turn_pending = false
	battle.energy = 10
	return battle

func reset_enemies(battle) -> void:
	battle.enemy_hps.assign([300, 300])
	battle.enemy_max_hps.assign([300, 300])
	battle.enemy_guards.assign([0, 0])
	battle.enemy_vulnerabilities.assign([0, 0])

func lock(battle, card_id: String) -> void:
	battle.locked_companion_choice = {"card_id": card_id, "reason": "测试", "source": "fallback"}

func play(battle, cards, card_id: int, target: int = 0) -> void:
	battle._execute_player_card(cards.get_definition(card_id), battle._card_cost(card_id), -1, target)

func run() -> void:
	var state = root.get_node("RunState")
	var cards = root.get_node("CardDatabase")
	var Relics = load("res://scripts/data/relic_database.gd")
	var Tactics = load("res://scripts/battle/companion_tactics.gd")
	var Companion = load("res://scripts/data/companion_card_database.gd")
	state.suppress_persistence = true
	state.chapter = 1
	state.chapter_trip = 1
	state.start_new_run()

	# ---- 数据完整 ----
	for card_id in range(cards.BACK_TO_WATER, cards.LINKED_INTENT + 1):
		var d: Dictionary = cards.get_definition(card_id)
		check(d.has("rarity") and d.has("face") and d.has("battle") and d.has("reward"), "新牌数据完整：%d" % card_id)
		check(card_id in cards.REWARD_CARD_IDS, "新牌进奖励池：%d" % card_id)
		check(preload("res://scripts/ui/card_art_catalog.gd").texture_for(card_id) != null, "新牌有占位图：%d" % card_id)
	check(Companion.intent_kind("guard_echo") == "guard" and Companion.intent_kind("lead_momentum") == "invest" and Companion.intent_kind("lone_judgment") == "finisher", "她的牌能归到意向")

	# ---- 默契倾向 ----
	check(state.run_lean.is_empty(), "新的一趟倾向为空")
	var battle = await fresh_battle(state)
	reset_enemies(battle)
	lock(battle, "guard_echo")
	play(battle, cards, cards.BORROW_MOMENTUM)
	check(state.run_lean_value("guard") == 1, "接住她的守护，守护倾向 +1")
	lock(battle, "quick_slash")
	play(battle, cards, cards.ATTACK)
	check(state.run_lean_value("guard") == 1 and state.run_lean_value("finisher") == 0, "不读意向的牌不记")
	for i in range(5):
		lock(battle, "guard_echo")
		play(battle, cards, cards.BORROW_MOMENTUM)
	check(state.run_lean_spoken.has("guard") and battle.last_lean_line.contains("后面有我"), "守护倾向够了，她说一句")
	# 两可时倾向起作用
	var context := {"incoming_damage": 6, "block": 0, "player_hp": 80, "player_max_hp": 90, "combo": 0, "cooperation": {}, "run_lean": {}}
	var options: Array[String] = ["guard_echo", "lead_momentum"]
	var base_pick: String = Tactics.choose(context, options).card_id
	context["run_lean"] = {"guard": 8}
	check(Tactics.choose(context, options).card_id == "guard_echo", "守护倾向高时，两可的回合她选守护（原本选 %s）" % base_pick)
	context["run_lean"] = {"invest": 8}
	check(Tactics.choose(context, options).card_id == "lead_momentum", "让给你倾向高时她选让给你")
	# 存读
	state.checkpoint("map")
	var saved: Dictionary = state.expedition_checkpoint.duplicate(true)
	check(saved.state.run_lean.guard == 6, "倾向写进检查点")
	state.run_lean.clear()
	load("res://scripts/data/expedition_checkpoint.gd").restore(state, saved)
	check(state.run_lean_value("guard") == 6 and state.run_lean_spoken.has("guard"), "倾向可恢复")
	battle.queue_free()
	await process_frame

	# ---- 新牌 ----
	battle = await fresh_battle(state)
	reset_enemies(battle)
	# 背水：没出防御、她守护 → 她的护盾 +4
	lock(battle, "guard_echo")
	battle.defenses_this_turn = 0
	battle.companion_turn_block_bonus = 0
	play(battle, cards, cards.BACK_TO_WATER)
	check(battle.companion_turn_block_bonus == 4 and battle.enemy_hps[0] < 300, "背水：攻击并给她护盾+4")
	battle.companion_turn_block_bonus = 0
	battle.defenses_this_turn = 1
	play(battle, cards, cards.BACK_TO_WATER)
	check(battle.companion_turn_block_bonus == 0, "背水：出过防御就不加")
	battle.defenses_this_turn = 0
	# 倚剑：8 + 她上回合给的护盾
	reset_enemies(battle)
	battle.combo = 0
	battle.last_companion_block = 9
	lock(battle, "quick_slash")
	play(battle, cards, cards.LEAN_ON_SWORD)
	check(300 - battle.enemy_hps[0] == 17, "倚剑：8+9=17（实际 %d）" % (300 - battle.enemy_hps[0]))
	# 托付：她给护盾 → 下一剑 + 一半
	reset_enemies(battle)
	battle.combo = 0
	battle.entrust_active = true
	battle._apply_companion_card({"card_id": "guard_echo", "reason": "测试", "source": "fallback"})
	check(battle.entrust_bonus > 0, "托付：她给护盾后存下加成")
	var bonus: int = battle.entrust_bonus
	lock(battle, "quick_slash")
	play(battle, cards, cards.ATTACK)
	check(300 - battle.enemy_hps[0] == 6 + bonus and battle.entrust_bonus == 0, "托付：下一剑 +%d" % bonus)
	battle.entrust_active = false
	# 顺势
	battle.hand.clear()
	lock(battle, "lead_momentum")
	var energy_before: int = battle.energy
	play(battle, cards, cards.GO_WITH_FLOW)
	check(battle.energy == energy_before + 1, "顺势：她让给你时精力+1")
	# 借花：每用掉一次机会 +2
	reset_enemies(battle)
	battle.combo = 0
	battle.opportunities_used_this_battle = 3
	lock(battle, "quick_slash")
	play(battle, cards, cards.BORROW_BLOSSOM)
	check(300 - battle.enemy_hps[0] == 12, "借花：6+3×2=12（实际 %d）" % (300 - battle.enemy_hps[0]))
	# 心照 + 机会计数
	battle.heart_sync_active = true
	battle.cooperation_windows = {"resource": {"source": "lead_momentum", "used": false, "combo": 0}}
	var block_before: int = battle.block
	var combo_before: int = battle.combo
	battle._use_cooperation_window()
	check(battle.block == block_before + 4 and battle.combo == combo_before + 1 and battle.opportunities_used_this_battle == 4, "心照：接住机会时格挡+4、连击+1")
	battle.heart_sync_active = false
	# 垫步
	battle.combo = 0
	lock(battle, "lone_judgment")
	play(battle, cards, cards.STEP_PAD)
	check(battle.combo == 3, "垫步：她收尾时连击+3")
	# 点睛
	battle.companion_turn_damage_bonus = 0
	battle.combo = 4
	lock(battle, "quick_slash")
	play(battle, cards, cards.FINAL_TOUCH)
	check(battle.companion_turn_damage_bonus == 8, "点睛：她这一击+连击×2")
	battle.companion_turn_damage_bonus = 0
	lock(battle, "lone_judgment")
	play(battle, cards, cards.FINAL_TOUCH)
	check(battle.companion_turn_damage_bonus == 12, "点睛：她收尾时+连击×3")
	battle.companion_turn_damage_bonus = 0
	# 剑意相连：她击倒敌人 → 下回合精力+1、连击保留
	battle.linked_intent_active = true
	battle.enemy_hps.assign([1, 300])
	battle.enemy_guards.assign([0, 0])
	battle._apply_companion_card({"card_id": "quick_slash", "reason": "测试", "source": "fallback"})
	check(battle.linked_pending, "剑意相连：她击倒敌人后记下")
	battle.queue_free()
	await process_frame

	# ---- 信物 ----
	state.run_relics.assign([Relics.OLD_UMBRELLA, Relics.BROKEN_STRING, Relics.LETTER_ENVELOPE])
	battle = await fresh_battle(state)
	reset_enemies(battle)
	lock(battle, "guard_echo")
	battle.attacked_this_turn = false
	check(battle._card_cost(cards.ATTACK) == 0, "旧伞：她守护时第一张攻击牌 -1 费")
	battle.attacked_this_turn = true
	check(battle._card_cost(cards.ATTACK) == 1, "旧伞：只管第一张")
	lock(battle, "lone_judgment")
	battle._apply_intent_relics()
	check(battle.enemy_vulnerabilities[0] == 1 and battle.enemy_vulnerabilities[1] == 1, "断弦：她收尾时敌人易伤+1")
	battle.queue_free()
	await process_frame
	state.run_relics.assign([Relics.LETTER_ENVELOPE])
	state.bond_value = 100
	state.bond_stage = 3
	var invest_first := 0
	for s in range(6):
		battle = await fresh_battle(state)
		await process_frame
		if Companion.is_investment(str(battle.locked_companion_choice.get("card_id", ""))): invest_first += 1
		battle.queue_free()
		await process_frame
	check(invest_first == 6, "信笺：第一回合她先让给你（%d/6）" % invest_first)
	state.run_relics.clear()

	# ---- 引擎牌后同路线更常出现 ----
	var owned: Array[int] = [cards.ENTRUST]
	var plain: Array[int] = []
	check(cards.reward_weight(cards.BACK_TO_WATER, owned) > cards.reward_weight(cards.BACK_TO_WATER, plain), "拿到托付后守护流的牌更常出现")
	check(cards.reward_weight(cards.LEAN_ON_SWORD, plain, 2) > cards.reward_weight(cards.LEAN_ON_SWORD, plain, 1), "剑境二：罕见牌更常出现")

	# ---- 自由历练与剑境 ----
	state.chapter = 3
	state.chapter_trip = 2
	check(not state.is_free_play(), "第三章第二趟还不是自由历练")
	state.chapter_trip = 3
	check(state.is_free_play(), "第三章打完是自由历练")
	state.realm_unlocked = 1
	state.realm_cleared = 0
	state.last_free_boss = ""
	state.start_new_run(5)
	check(state.sword_realm == 1, "没解锁的剑境选不了")
	var bosses := {}
	var previous := ""
	var repeated := false
	for i in range(40):
		state.start_new_run(1)
		bosses[state.free_boss] = true
		repeated = repeated or state.free_boss == previous
		previous = state.free_boss
		check(state.chapter_boss() == state.free_boss, "首领就是这趟抽到的")
	check(bosses.size() == 5 and not repeated, "首领池五位都会出现，且不连续重复（%d）" % bosses.size())
	# 打通解锁下一级
	state.start_new_run(1)
	state.complete_chapter_trip()
	check(state.realm_unlocked == 2 and state.realm_cleared == 1, "打通剑境一，解锁剑境二")
	state.start_new_run(1)
	state.complete_chapter_trip()
	check(state.realm_unlocked == 2, "打低一级不再解锁")
	check(state.chapter_label().contains("剑境 二"), "家里标签显示剑境")
	var codec = load("res://scripts/data/relationship_profile.gd")
	var decoded: Dictionary = codec.decode(codec.encode(state))
	check(decoded.realm_unlocked == 2 and decoded.realm_cleared == 1, "剑境进度可存读")
	# 剑境三：回复减半；四：出发带信物；五：心魔
	state.realm_unlocked = 5
	state.start_new_run(3)
	check(state.rest_heal(20) == 10 and state.rest_heal(-8) == -8, "剑境三：回复减半，扣血不变")
	state.start_new_run(4)
	check(state.run_relics.size() == 1, "剑境四：出发带一件信物")
	state.start_new_run(5)
	check(state.deck.count(cards.CURSE) == 1, "剑境五：起始多一张心魔")
	state.complete_chapter_trip()
	check(state.realm_cleared == 5 and state.pending_story == "realm5_clear", "打通剑境五，回家播专属台词")
	check(state.chapter_label().contains("已破"), "剑境五已破")
	state.pending_story = ""

	# ---- 剑境对战斗的影响 ----
	state.start_new_run(2)
	battle = await fresh_battle(state, state.EncounterType.NORMAL, 6, false)
	var realm2_hp: int = battle.enemy_hps[0]
	battle.queue_free()
	await process_frame
	state.start_new_run(1)
	battle = await fresh_battle(state, state.EncounterType.NORMAL, 6, false)
	check(realm2_hp > battle.enemy_hps[0] or realm2_hp >= int(battle.enemy_hps[0] * 1.05), "剑境二：敌人生命更高")
	# 线外换成第一章敌人，线上仍是戏班
	var enemies = root.get_node("EnemyDatabase")
	check(not battle.enemy_roles.any(func(r): return r in [enemies.PUPPET, enemies.BLADE, enemies.THREADER, enemies.BOX]), "自由历练线外是第一章的敌人：%s" % str(battle.enemy_roles))
	battle.queue_free()
	await process_frame
	battle = await fresh_battle(state, state.EncounterType.NORMAL, 6, true)
	check(battle.enemy_roles.any(func(r): return r in enemies.THREAD_THROWERS), "自由历练线上仍是戏班")
	battle.queue_free()
	await process_frame
	# 首领：咒剑守卫不抛线
	state.free_boss = "curse_guardian"
	battle = await fresh_battle(state, state.EncounterType.BOSS, 19, true)
	check(battle._enemy_name(0) == "咒剑守卫", "首领池里的咒剑守卫")
	battle._roll_enemy_intents()
	check(not battle.enemy_intents[0].get("thread", false), "咒剑守卫不抛线")
	battle.queue_free()
	await process_frame
	# 剑境五：攻击 +2
	state.start_new_run(5)
	state.free_boss = "bound_spirit"
	battle = await fresh_battle(state, state.EncounterType.BOSS, 19, true)
	var attack5: int = battle.enemy_intents[0].value
	battle.queue_free()
	await process_frame
	state.start_new_run(1)
	state.free_boss = "bound_spirit"
	battle = await fresh_battle(state, state.EncounterType.BOSS, 19, true)
	check(attack5 == battle.enemy_intents[0].value + 2, "剑境五：攻击 +2（%d vs %d）" % [attack5, battle.enemy_intents[0].value])
	battle.queue_free()
	await process_frame

	# ---- 出发前选剑境 ----
	state.clear_expedition()
	state.intro_done = true
	state.finale_state = "completed"
	state.finale_mode = "victory"
	state.story_seen.assign(["ch2_ending", "ch3_ending"])
	state.realm_unlocked = 3
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	current_scene = home
	await process_frame
	home._go_to_map()
	await process_frame
	check(home.realm_picker != null and home.realm_picker.buttons.size() == 3, "解锁剑境三后出发先选剑境")
	home.realm_picker._cancel()
	await process_frame
	check(not home.depart_button.disabled, "取消后能再点历练")
	home.queue_free()
	await process_frame

	print("Build routes smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)
