extends SceneTree

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var card_database = root.get_node("CardDatabase")
	var animation_profiles = preload("res://scripts/ui/companion_action_effect.gd").PROFILES
	var companion_cards = preload("res://scripts/data/companion_card_database.gd")
	for card_id in companion_cards.DEFINITIONS.keys() + companion_cards.INTENT_DEFINITIONS.keys():
		check(animation_profiles.has(card_id), "每种小墨招式都有动画：" + card_id)
		var effect_kind: String = animation_profiles[card_id][0]
		check(effect_kind in ["slash", "dash", "resonance", "frost"] or preload("res://scripts/ui/painted_combat_vfx.gd").SUPPORT.has(effect_kind), "每种小墨招式都有绘制特效素材：" + card_id)
		var pose_map = preload("res://scripts/ui/companion_action_effect.gd").POSES
		check(pose_map.has(card_id) and ResourceLoader.exists("res://art/character/xiaomo_%s_pose_v1.png" % pose_map.get(card_id, "missing")), "每种小墨招式都有动作立绘：" + card_id)
	var dialogue_director = preload("res://scripts/battle/companion_card_director.gd")
	var allowed: Array[String] = ["quick_slash"]
	var natural := dialogue_director.parse_choice(JSON.stringify({"card_id": "quick_slash", "reason": "别急，我跟得上。"}), allowed)
	check(natural.get("reason", "") == "别急，我跟得上。", "自然短对白不强制报告事实")
	var report := dialogue_director.parse_choice(JSON.stringify({"card_id": "quick_slash", "reason": "敌人29血，这回合只打6点，你手牌还没动。"}), allowed)
	check(report.get("card_id", "") == "quick_slash" and report.get("reason", "") == "这一手，我来。", "报告式台词替换且保留合法选牌")
	check(dialogue_director.parse_choice(JSON.stringify({"card_id": "invented", "reason": "我来。"}), allowed).is_empty(), "自然对白仍不可越过授权牌池")
	var state = root.get_node("RunState")
	var enemies = root.get_node("EnemyDatabase")
	var cards = root.get_node("CardDatabase")
	state.suppress_persistence = true
	state.start_new_run()
	check(state.deck.size() == 15, "起始牌组不变")
	check(cards.get_reward_card_ids().size() == 14, "奖励池十四张，含行云、追风、护盾攻击、留盾与招架")
	for id in [cards.ATTACK, cards.DEFENSE, cards.STATUS]:
		check(id not in cards.get_reward_card_ids(), "基础牌不进入奖励池")
	check(enemies.get_normal_config(1)["hp_min"] == 34, "首战生命下界")
	check(enemies.get_normal_config(1)["count_max"] == 1, "首战单敌")
	check(enemies.get_normal_config(3)["count_max"] == 2, "早期最多双敌")
	check(enemies.get_normal_config(7)["count_min"] == 2, "后期固定双敌")
	check(enemies.get_normal_config(3)["hp_min"] > 30, "早期怪能承受基础三连加小墨一斩")
	check(enemies.get_normal_config(7)["hp_min"] == 55, "中段生存空间")
	state.pending_encounter = state.EncounterType.ELITE
	state.player_hp = 80
	var reward = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(reward)
	check(reward.card_choices.visible and reward.skip_button.visible, "进入奖励直接显示选牌及跳过")
	reward._choose_card(cards.COMBO_BOOST)
	check(state.player_hp == 80, "战后选牌不回血")
	check(state.deck.back() == cards.COMBO_BOOST, "选牌加入牌组")
	check(reward.removing, "精英选牌后仍获删牌")
	var deck_size: int = state.deck.size()
	reward._remove_card(0)
	check(state.deck.size() == deck_size - 1, "按位置删一张")
	reward._remove_card(0)
	check(state.deck.size() == deck_size - 1, "不能重复删牌")
	reward.queue_free()
	state.pending_encounter = state.EncounterType.NORMAL
	var normal = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(normal)
	check(normal.skip_button.visible, "选卡允许跳过")
	normal._skip_choice()
	check(state.deck.size() == deck_size - 1 and not normal.removing, "普通跳过不加牌也不删牌")
	check(state.player_hp == 80, "跳过不回血")
	normal.queue_free()
	state.pending_encounter = state.EncounterType.ELITE
	var elite_skip = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(elite_skip)
	elite_skip._skip_choice()
	check(elite_skip.removing, "精英跳过选牌仍可删牌")
	elite_skip._skip_choice()
	check(not elite_skip.removing and state.deck.size() == deck_size - 1, "精英两步跳过不改变牌组")
	elite_skip.queue_free()
	state.pending_event = state.EventType.TREASURE
	var event = load("res://scenes/event.tscn").instantiate()
	root.add_child(event)
	event._show_card_choices()
	check(event.skip_button.visible, "事件选卡允许跳过")
	event._finish_event("跳过选卡")
	check(state.deck.size() == deck_size - 1, "事件跳过不加牌")
	event.queue_free()
	await process_frame
	state.pending_encounter = state.EncounterType.BOSS
	state.player_hp = 90
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	check(battle.enemy_intents[0]["value"] == 8, "Boss首轮攻击8")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0]["type"] == battle.EnemyIntent.DEFEND, "Boss次轮布防")
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0]["value"] == 18, "Boss重斩18")
	battle.enemy_guards[0] = 8
	battle.combo = 0
	battle._play_combo_boost_card(0)
	check(battle.boss_charge_hits == 1 and battle.enemy_hps[0] == 200, "叠浪被格挡也计一次命中")
	check(battle.combo == 2, "叠浪连击加二但只命中一次")
	battle._damage_enemy_at(0, 0)
	check(battle.boss_charge_hits == 1, "零伤害不计次")
	battle._damage_enemy_at(0, 6)
	check(battle.enemy_intents[0]["value"] == 18, "两次有效命中尚未打断")
	battle._damage_enemy_at(0, 6)
	check(battle.enemy_intents[0]["value"] == 8 and battle.enemy_intents[0]["interrupted"], "第三次有效命中打断")
	battle.enemy_hps[0] = 100
	battle._roll_enemy_intents()
	battle._roll_enemy_intents()
	battle.enemy_attack_reductions[0] = 5
	battle._roll_enemy_intents()
	check(battle.enemy_intents[0]["value"] == 17, "半血重斩22且拨千斤生效")
	battle.start_battle()
	check(battle.boss_charge_hits == 0 and battle.enemy_intents[0]["value"] == 8, "重开重置Boss机制")
	battle.companion_turn_pending = false
	battle._play_attack_card(2, card_database.get_number(card_database.HEAVY_ATTACK, "damage"), 0)
	check(battle.enemy_hps[0] == 184 and battle.energy == 1, "劈山实际16伤害且仍费2")
	battle.enemy_vulnerabilities[0] = 2
	battle._damage_enemy_at(0, 6)
	battle._damage_enemy_at(0, 6)
	check(battle.enemy_hps[0] == 168 and battle.enemy_vulnerabilities[0] == 2, "易伤每次加伤且不按命中消耗")
	battle._resolve_enemy_turn()
	check(battle.enemy_vulnerabilities[0] == 1, "回合末易伤2降1")
	battle._resolve_enemy_turn()
	check(battle.enemy_vulnerabilities[0] == 0, "回合末易伤1降0")
	battle._resolve_enemy_turn()
	check(battle.enemy_vulnerabilities[0] == 0, "易伤不为负")
	battle.start_battle()
	battle._roll_enemy_intents()
	battle._roll_enemy_intents()
	battle._discard_remaining_hand()
	battle._show_card_in_slot(0, cards.ATTACK)
	battle._show_card_in_slot(1, cards.ATTACK)
	battle._show_card_in_slot(2, cards.DEFENSE)
	battle._show_card_in_slot(3, cards.STATUS)
	battle._prepare_companion_intent()
	check(battle.locked_companion_choice["card_id"] == "quick_slash", "可打两次时离线选择补击")
	check(battle.locked_companion_choice.get("plan", {}).get("kind", "") == "boss_interrupt", "补击带本地条件")
	check(battle.get_node("BattleUI/CompanionPanel/Effect").text.contains("命中2次"), "起手显示尚需两击")
	battle.companion_turn_pending = false
	battle._play_attack_card(1, 6, 0)
	check(battle.get_node("BattleUI/CompanionPanel/Effect").text.contains("命中1次"), "第一击后更新进度且不改招")
	battle._play_attack_card(1, 6, 0)
	check(battle.get_node("BattleUI/CompanionPanel/Effect").text.contains("条件已达成"), "两击后显示配合达成")
	var tactics = load("res://scripts/battle/companion_tactics.gd")
	var lethal_context: Dictionary = battle._build_companion_context()
	lethal_context["player_hp"] = 10
	lethal_context["can_build_combo"] = false
	var legal: Array[String] = ["quick_slash", "guard_echo"]
	check("quick_slash" in tactics.candidates(lethal_context, legal), "真实两击可补击救命")
	lethal_context["boss_hits"] = 0
	check("quick_slash" not in tactics.candidates(lethal_context, legal), "未完成配合不假设已救命")
	battle._run_companion_turn()
	check(battle.enemy_intents[0].get("interrupted", false), "小墨实际补第三击打断")
	battle.start_battle()
	battle._roll_enemy_intents()
	battle._roll_enemy_intents()
	battle.locked_companion_choice = {"card_id": "quick_slash", "reason": "固定补击计划", "source": "fallback", "plan": {"kind": "boss_interrupt", "required_total": 3, "companion_hits": 1}}
	battle._damage_enemy_at(0, 6)
	battle._run_companion_turn()
	check(battle.companion_last_card_id == "quick_slash" and not battle.enemy_intents[0].get("interrupted", false), "非致命配合未达成仍遵守攻击意向")
	battle.start_battle()
	battle._roll_enemy_intents()
	battle._roll_enemy_intents()
	battle.player_hp = 14
	battle.locked_companion_choice = {"card_id": "quick_slash", "reason": "固定补击计划", "source": "fallback"}
	battle._run_companion_turn()
	check(battle.companion_last_card_id == "guard_echo" and battle.companion_last_reason.contains("致命"), "可救致命危险改盾并解释")
	var director = load("res://scripts/battle/companion_card_director.gd")
	check(director.build_prompt(battle._build_companion_context(), legal).contains("boss_hits"), "在线提示包含机制状态")
	check(tactics.cooperation_plan({"combo": 2}, "grind_sword").get("kind", "") == "charge_attack", "磨剑积蓄小墨下次伤害")
	battle.queue_free()
	await process_frame
	state.pending_encounter = state.EncounterType.NORMAL
	state.route_layer = 4
	state.player_hp = 90
	var roles_battle = load("res://scenes/battle.tscn").instantiate()
	roles_battle.force_offline_companion = true
	root.add_child(roles_battle)
	roles_battle.enemy_roles.assign([enemies.GUARDIAN, enemies.HEXER])
	roles_battle.enemy_action_step = 0
	roles_battle._roll_enemy_intents()
	check(roles_battle.enemy_intents[0].get("support", false), "守卫预告护卫")
	roles_battle._resolve_enemy_turn()
	check(roles_battle.enemy_guards[0] == 0 and roles_battle.enemy_guards[1] == 8, "守卫格挡给同伴")
	check(roles_battle.enemy_intents[1]["type"] == roles_battle.EnemyIntent.CURSE, "咒师次轮预告心魔")
	roles_battle.enemy_hps[1] = 0
	var curses_before: int = roles_battle.discard_pile.count(cards.CURSE) + roles_battle.draw_pile.count(cards.CURSE) + roles_battle.hand.count(cards.CURSE)
	roles_battle._resolve_enemy_turn()
	var curses_after: int = roles_battle.discard_pile.count(cards.CURSE) + roles_battle.draw_pile.count(cards.CURSE) + roles_battle.hand.count(cards.CURSE)
	check(curses_before == curses_after, "击杀咒师取消塞牌")
	check(roles_battle._guard_target(0) == 0, "守卫无同伴时自保")
	roles_battle.enemy_roles.assign([enemies.SWORDSMAN, enemies.HEXER])
	roles_battle.enemy_action_step = 1
	roles_battle.enemy_attack_reductions[0] = 5
	roles_battle._roll_enemy_intents()
	check(roles_battle.enemy_intents[0]["value"] == 7, "剑客重击12减伤5")
	roles_battle.enemy_hps[0] = 0
	roles_battle.enemy_hps[1] = 30
	roles_battle.enemy_roles.assign([enemies.GUARDIAN, enemies.HEXER])
	roles_battle.enemy_action_step = 0
	roles_battle._roll_enemy_intents()
	roles_battle._resolve_enemy_turn()
	check(roles_battle.enemy_guards[1] == 0, "死亡守卫不提供格挡")
	check(enemies.get_role_intent(enemies.SWORDSMAN, 1, true)["value"] == 14, "精英剑客重击14")
	check(enemies.get_encounter_roles(2, 2, false) == [enemies.GUARDIAN, enemies.GUARDIAN], "前段单一类型展示")
	roles_battle.queue_free()
	await process_frame
	print("Balance smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)
