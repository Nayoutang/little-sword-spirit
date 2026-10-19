extends SceneTree

# 2026-10-15 扩充的 14 张玩家牌：读小墨意向、流派引擎、新动作、紫线牌、稀有度奖励。
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func fresh_battle(state):
	state.pending_encounter = state.EncounterType.NORMAL
	state.route_layer = 6
	state.node_on_thread = false
	state.player_hp = state.player_max_hp
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.fixed_random_seed = 11
	root.add_child(battle)
	await process_frame
	battle.companion_turn_pending = false
	battle.enemy_hps.assign([300, 300])
	battle.enemy_max_hps.assign([300, 300])
	battle.energy = 10
	return battle

func lock(battle, card_id: String) -> void:
	battle.locked_companion_choice = {"card_id": card_id, "reason": "测试", "source": "fallback"}

func play(battle, cards, card_id: int, target: int = 0) -> void:
	var definition: Dictionary = cards.get_definition(card_id)
	battle._execute_player_card(definition, battle._card_cost(card_id), -1, target)

func run() -> void:
	var state = root.get_node("RunState")
	var cards = root.get_node("CardDatabase")
	state.suppress_persistence = true
	state.chapter = 1
	state.start_new_run()

	for card_id in range(cards.BORROW_MOMENTUM, cards.GUARD_HEART + 1):
		var definition: Dictionary = cards.get_definition(card_id)
		check(definition.has("rarity") and definition.has("face") and definition.has("battle"), "新牌数据完整：%d" % card_id)
		check(preload("res://scripts/ui/card_art_catalog.gd").texture_for(card_id) != null, "新牌有占位插画：%d" % card_id)

	var battle = await fresh_battle(state)
	# 意向类别
	lock(battle, "guard_echo")
	check(battle._companion_intent_kind() == "guard", "剑影回护=守护")
	lock(battle, "quick_slash")
	check(battle._companion_intent_kind() == "attack", "随手一斩=攻击")
	lock(battle, "lead_momentum")
	check(battle._companion_intent_kind() == "invest", "引势=让给你")
	lock(battle, "lone_judgment")
	check(battle._companion_intent_kind() == "finisher", "独断=收尾")

	# 借势：她守护时 0 费
	lock(battle, "guard_echo")
	check(battle._card_cost(cards.BORROW_MOMENTUM) == 0, "借势：她守护时0费")
	lock(battle, "quick_slash")
	check(battle._card_cost(cards.BORROW_MOMENTUM) == 1, "借势：否则1费")

	# 开路：她攻击时她这一击 +5
	lock(battle, "quick_slash")
	play(battle, cards, cards.CLEAR_PATH)
	check(battle.companion_turn_damage_bonus == 5, "开路：她攻击时给她+5")
	var before: int = battle.enemy_hps[0] + battle.enemy_hps[1]
	battle._apply_companion_card({"card_id": "quick_slash", "reason": "测", "source": "fallback"})
	check(before - (battle.enemy_hps[0] + battle.enemy_hps[1]) == 11 and battle.companion_turn_damage_bonus == 0, "她这一击 6+5 且只用一次")
	battle.companion_turn_damage_bonus = 0
	lock(battle, "guard_echo")
	play(battle, cards, cards.CLEAR_PATH)
	check(battle.companion_turn_damage_bonus == 0, "开路：她守护时不给")

	# 递剑：她攻击时不清连击
	battle.combo = 3
	lock(battle, "quick_slash")
	play(battle, cards, cards.HAND_SWORD)
	check(battle.combo == 3 and battle.block >= 5, "递剑：她要攻击时保留连击")
	lock(battle, "guard_echo")
	play(battle, cards, cards.HAND_SWORD)
	check(battle.combo == 0, "递剑：否则清连击")

	# 承让：她让给你时 +1 精力
	battle.energy = 5
	lock(battle, "lead_momentum")
	play(battle, cards, cards.YIELD_TURN)
	check(battle.energy == 5, "承让：花1得1")
	lock(battle, "quick_slash")
	play(battle, cards, cards.YIELD_TURN)
	check(battle.energy == 4, "承让：她不让时不回")

	# 收势：伤害10+连击×3，她收尾时连击+2
	battle.energy = 10
	battle.combo = 2
	lock(battle, "lone_judgment")
	before = battle.enemy_hps[0]
	play(battle, cards, cards.CLOSE_FORM)
	check(before - battle.enemy_hps[0] == 16 and battle.combo == 4, "收势：16伤、她收尾时连击+2")

	# 并肩：她守护时两人护盾 +3
	battle.block = 0
	lock(battle, "guard_echo")
	play(battle, cards, cards.SIDE_BY_SIDE)
	check(battle.block == 11 and battle.companion_turn_block_bonus == 3, "并肩：你11盾，她+3待用")
	battle._apply_companion_card({"card_id": "guard_echo", "reason": "测", "source": "fallback"})
	check(battle.block == 11 + 9, "她的回护 6+3")

	# 孤注：连击×5，本场移除
	battle.combo = 4
	before = battle.enemy_hps[0]
	var discard_before: int = battle.discard_pile.size()
	battle._show_card_in_slot(0, cards.ALL_IN)
	battle._commit_hand_card(0)
	play(battle, cards, cards.ALL_IN)
	check(before - battle.enemy_hps[0] == 20 and battle.combo == 0, "孤注：4连击打20并清零")
	check(battle.discard_pile.size() == discard_before, "孤注不进弃牌堆")

	# 后发：本回合每张防御 +5
	battle.defenses_this_turn = 0
	battle._show_card_in_slot(0, cards.DEFENSE)
	battle._commit_hand_card(0)
	battle._show_card_in_slot(0, cards.DEFENSE)
	battle._commit_hand_card(0)
	battle.combo = 0
	before = battle.enemy_hps[0]
	play(battle, cards, cards.LATE_STRIKE)
	check(before - battle.enemy_hps[0] == 20, "后发：两张防御后 10+10")
	battle.queue_free()
	await process_frame

	# 引擎：蓄意、不动、同调
	battle = await fresh_battle(state)
	play(battle, cards, cards.INTENT_HOLD)
	play(battle, cards, cards.UNMOVED)
	check(battle.intent_hold_active and battle.unmoved_active, "能力牌生效")
	battle.combo = 5
	battle.block = 0
	battle.enemy_intents.assign([{"type": battle.EnemyIntent.OTHER, "value": 0}, {"type": battle.EnemyIntent.OTHER, "value": 0}])
	battle._resolve_enemy_turn()
	check(battle.combo == 2, "蓄意：连击5回合末减半为2")
	check(battle.block == 3, "不动：回合开始3格挡")
	battle.block = 0
	battle._apply_companion_card({"card_id": "guard_echo", "reason": "测", "source": "fallback"})
	check(battle.block == 9, "不动：她护你时 6+3")
	battle.queue_free()
	await process_frame

	battle = await fresh_battle(state)
	play(battle, cards, cards.ATTUNE)
	battle.energy = 1
	battle.cooperation_windows = {"resource": {"source": "lead_momentum", "available": true}}
	battle._discard_remaining_hand()
	battle._use_cooperation_window()
	check(battle.energy == 2 and battle.hand.size() >= 1, "同调：接住机会抽1、精力+1")
	battle.queue_free()
	await process_frame

	# 听风：回锋上限+1，反击给她蓄力
	battle = await fresh_battle(state)
	play(battle, cards, cards.HEAR_WIND)
	play(battle, cards, cards.PARRY)
	check(battle.parry_reaction_limit == cards.get_number(cards.PARRY, "reaction_limit") + 1, "听风：回锋上限+1")
	battle._on_parry_attack_segment(0, 5, 0, 5)
	check(battle.companion_stored_damage_bonus == 2, "听风：反击后她下击+2")
	battle.queue_free()
	await process_frame

	# 紫线牌
	state.chapter = 2
	battle = await fresh_battle(state)
	check(battle.chapter_two, "第二章战斗")
	battle.xiaomo_threads.assign([0])
	battle.block = 0
	play(battle, cards, cards.GUARD_HEART)
	check(battle.block == 12, "护心：她被缠时 6+6")
	play(battle, cards, cards.PICK_THREAD)
	check(battle.thread_hits[0] == 2, "挑丝：打持线者算两次命中")
	battle.queue_free()
	await process_frame

	# 奖励：加权、不重复、能力牌拿过不再出、紫线牌只在第二章
	var owned: Array[int] = [cards.INTENT_HOLD]
	var seen_rare := false
	var chapter_one_ok := true
	for i in range(300):
		var rolled: Array[int] = cards.roll_reward_cards(owned, 3, 1)
		check(rolled.size() == 3 and rolled[0] != rolled[1] and rolled[1] != rolled[2] and rolled[0] != rolled[2], "三张不重复")
		chapter_one_ok = chapter_one_ok and not rolled.has(cards.INTENT_HOLD) and not rolled.has(cards.PICK_THREAD) and not rolled.has(cards.GUARD_HEART)
		seen_rare = seen_rare or rolled.any(func(c): return cards.get_rarity(c) == "rare")
	check(chapter_one_ok, "已有能力不再出，第一章无紫线牌")
	check(seen_rare, "稀有牌能抽到")

	print("New cards smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)
