extends SceneTree

# 2026-10-19 增量：磨剑升级、自由历练新敌人与路遇、大话骰→战斗、离线台词。离线、不写存档。
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
	battle.fixed_random_seed = 5
	root.add_child(battle)
	await process_frame
	battle.companion_turn_pending = false
	battle.energy = 10
	return battle

func run() -> void:
	var state = root.get_node("RunState")
	var cards = root.get_node("CardDatabase")
	var enemies = root.get_node("EnemyDatabase")
	var Checkpoint = load("res://scripts/data/expedition_checkpoint.gd")
	state.suppress_persistence = true
	state.chapter = 1
	state.chapter_trip = 1
	state.start_new_run()

	# ---- 磨剑 ----
	check(cards.can_upgrade(cards.ATTACK) and not cards.can_upgrade(cards.CURSE) and not cards.can_upgrade(cards.FLOWING_LIGHT), "哪些牌能磨")
	var up: int = cards.upgraded_id(cards.ATTACK)
	check(cards.is_upgraded(up) and not cards.can_upgrade(up) and cards.base_id(up) == cards.ATTACK, "升级 id 规则")
	check(cards.get_card_name(up) == "平刺+" and cards.get_number(up, "damage") == 9, "平刺+ 伤害 9")
	check(cards.get_reward_text(up).contains("9") and not cards.get_reward_text(up).contains("伤害6"), "平刺+ 文字跟着改")
	check(cards.get_cost(cards.upgraded_id(cards.RETAIN_SHIELD)) == 0, "留盾+ 费用 0")
	check(cards.get_rarity(cards.upgraded_id(cards.ENTRUST)) == cards.RARITY_RARE, "升级牌稀有度跟原牌")
	check(preload("res://scripts/ui/card_art_catalog.gd").texture_for(cards.upgraded_id(cards.BACK_TO_WATER)) != null, "升级牌用原图")
	for base in cards.UPGRADES:
		var d: Dictionary = cards.get_definition(cards.upgraded_id(base))
		check(d.has("battle") and d.has("reward") and str(d.name).ends_with("+"), "升级数据完整：%d" % base)
	state.deck.assign([cards.ATTACK, cards.ATTACK, cards.DEFENSE, cards.CURSE])
	check(state.upgrade_run_card(0) == up and state.deck[0] == up, "牌组里磨一张")
	check(state.upgrade_run_card(0) == -1 and state.upgrade_run_card(3) == -1, "磨过的和心魔不能再磨")
	state.checkpoint("map")
	check(Checkpoint.valid(state.expedition_checkpoint), "带升级牌的存档有效")
	# 能力牌磨过以后，奖励里不再出原版
	state.deck.assign([cards.upgraded_id(cards.ENTRUST)])
	check(not cards.get_reward_card_ids(state.deck).has(cards.ENTRUST), "已有托付+，不再出托付")
	# 战斗里打出升级牌
	state.deck.assign([cards.ATTACK, cards.DEFENSE, cards.DEFENSE, cards.DEFENSE, cards.DEFENSE])
	var battle = await fresh_battle(state)
	battle.enemy_hps.assign([300, 300])
	battle.enemy_guards.assign([0, 0])
	battle.enemy_vulnerabilities.assign([0, 0])
	battle.combo = 0
	battle._execute_player_card(cards.get_definition(up), battle._card_cost(up), -1, 0)
	check(300 - battle.enemy_hps[0] == 9, "平刺+ 实际打 9（%d）" % (300 - battle.enemy_hps[0]))
	battle.queue_free()
	await process_frame
	# 宝箱：磨剑选项，反悔回到宝箱
	state.start_new_run()
	state.deck.assign([cards.ATTACK, cards.DEFENSE, cards.ATTACK])
	state.pending_event = state.EventType.TREASURE
	var event = load("res://scenes/event.tscn").instantiate()
	root.add_child(event)
	current_scene = event
	await process_frame
	var grind: Button = event.main_choices.get_node_or_null("Grind")
	check(grind != null and not grind.disabled, "宝箱有磨剑")
	event._show_upgrade_choices()
	check(event.upgrade_scroll.visible and event.upgrade_scroll.get_child(0).get_child_count() == 2, "同名牌只列一次（平刺、横架）")
	event._on_skip_pressed()
	check(event.main_choices.visible and not event.finishing, "先不磨：回到宝箱")
	event._show_upgrade_choices()
	event._upgrade_card(1)
	check(state.deck[1] == cards.upgraded_id(cards.DEFENSE) and event.finishing, "磨了横架")
	await create_timer(1.2).timeout
	if current_scene != null and is_instance_valid(current_scene): current_scene.queue_free()
	await process_frame

	# ---- 新敌人 ----
	var roles := {}
	for i in range(80):
		for r in enemies.get_free_play_roles(8, 2, false):
			roles[r] = true
	check(roles.has(enemies.BLOODBLADE) and roles.has(enemies.HEALER) and roles.has(enemies.SWORDSMAN), "自由历练线外出新敌人")
	var a: Dictionary = enemies.get_role_intent(enemies.BLOODBLADE, 0, false, 8)
	var b: Dictionary = enemies.get_role_intent(enemies.BLOODBLADE, 3, false, 8)
	check(int(b.value) == int(a.value) + 6, "血衣刀客每回合 +2")
	check(enemies.get_role_intent(enemies.HEALER, 0, false, 8).get("heal", false), "墨医第一步回春")
	state.chapter = 3
	state.chapter_trip = 3
	state.start_new_run(1)
	battle = await fresh_battle(state, 0, 8, false)
	battle.enemy_roles.assign([enemies.HEALER, enemies.SWORDSMAN])
	battle.enemy_hps.assign([40, 20])
	battle.enemy_max_hps.assign([40, 50])
	battle.enemy_intents.assign([enemies.get_role_intent(enemies.HEALER, 0, false, 8), {"type": 4, "value": 0}])
	battle.player_hp = 90
	battle._resolve_enemy_turn()
	check(battle.enemy_hps[1] > 20 and battle.enemy_hps[0] == 40, "墨医给血少的同伴回血")
	battle.queue_free()
	await process_frame
	var Road = load("res://scripts/data/road_events.gd")
	check(Road.EVENTS.size() >= 15 and Road.EVENTS.has("roadside_smith") and Road.EVENTS.has("blank_stele"), "新增路遇")
	check(Road.describe(Road.EVENTS.roadside_smith.options[0]).contains("升级一张牌"), "路遇按钮写明升级")

	# ---- 大话骰 → 战斗 ----
	state.relationship_facts["dice_caught"] = 3
	check(not state.dice_read_unlocked(), "看穿 3 次还不够")
	check(state.record_dice_caught(2) and state.dice_read_unlocked(), "看穿第 5 次时解锁")
	check(not state.record_dice_caught(1), "只提示一次")
	var codec = load("res://scripts/data/relationship_profile.gd")
	check(int(codec.decode(codec.encode(state)).relationship_facts.dice_caught) == 6, "看穿次数可存读")
	state.bond_value = 100
	state.bond_stage = 3
	state.start_new_run(1)
	state.run_lean = {"finisher": 5}
	battle = await fresh_battle(state)
	battle.enemy_hps.assign([300, 300])
	battle.locked_companion_choice = {"card_id": "quick_slash", "reason": "测试", "source": "fallback"}
	battle.companion_turn_pending = false
	await battle._end_turn()
	await process_frame
	check(battle.turn_promised_kind == "finisher" or battle.promised_kind == "finisher", "她提前说下回合想收尾")
	var Tactics = load("res://scripts/battle/companion_tactics.gd")
	var ctx := {"incoming_damage": 6, "block": 0, "player_hp": 80, "player_max_hp": 90, "combo": 0, "cooperation": {}, "run_lean": {}, "promised_kind": "invest"}
	var opts: Array[String] = ["guard_echo", "lead_momentum"]
	check(Tactics.choose(ctx, opts).card_id == "lead_momentum", "说过的打算这回合照做")
	battle.queue_free()
	await process_frame
	state.relationship_facts["dice_caught"] = 0

	# ---- 离线台词 ----
	var Director = load("res://scripts/battle/companion_card_director.gd")
	var seen := {}
	for hp in range(60, 90):
		var c := {"player_hp": hp, "combo": 0, "incoming_damage": 0, "block": 0, "bond_stage": 3, "run_lean": {"guard": 8}, "cooperation": {}, "player_max_hp": 90}
		var pick: Dictionary = Director.choose_fallback(c, ["guard_echo"] as Array[String])
		seen[pick.reason] = true
	check(seen.size() >= 3, "同一类出牌理由不止一句（%d）" % seen.size())
	var Home = load("res://scripts/data/offline_home_dialogue.gd")
	var line: String = Home.homecoming([{"category": "run_result", "summary": "本趟远征最终通关"}, {"category": "lean", "summary": "这一趟，小墨最常替你挡。", "details": {"lean": "guard"}}])
	check(Home.HABIT_LINES.guard.any(func(l): return line.contains(l)), "回家时说起这一趟的打法")

	print("Increments smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)
