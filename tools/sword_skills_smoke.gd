extends SceneTree

const Cards = preload("res://scripts/data/companion_card_database.gd")
const Tactics = preload("res://scripts/battle/companion_tactics.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func scene(chain := false):
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	state.route_layer = 8
	state.pending_encounter = state.EncounterType.NORMAL
	state.player_hp = 90
	var b = load("res://scenes/battle.tscn").instantiate()
	if chain:
		b.set_script(load("res://tools/sword_skill_battle_fixture.gd"))
	b.force_offline_companion = true
	b.offline_experiment = true
	root.add_child(b)
	b.enemy_hps.fill(100)
	b.enemy_guards.fill(0)
	b.enemy_vulnerabilities.fill(0)
	b.combo = 0
	return b

func use(b, id: String) -> void:
	b._apply_companion_card({"card_id": id, "source": "fallback", "reason": "测试"})

func run() -> void:
	check(not root.has_node("AbilityManager"), "神通自动加载已取消")
	var b = scene(true)
	b.enemy_hps.assign([1,1,1])
	b.combo = 2
	b.locked_companion_choice = {"card_id": Cards.TEN_STEPS, "source": "fallback"}
	var turn = b.battle_turn_count
	var energy = b.energy
	await b._run_companion_turn()
	check(b.battle_finished and b.battle_companion_card_counts.get("十步", 0) == 3, "十步连续三次击杀，无一次上限，敌人全灭即停止")
	check(b.battle_turn_count == turn and b.energy == energy and b.player_hp == 90, "追击不推进回合或敌方行动，不消耗玩家精力")
	b.free()
	b = scene()
	b.enemy_hps.assign([1,100])
	use(b, Cards.TEN_STEPS)
	check(b.companion_bonus_action, "十步击杀获得追加技能")
	use(b, Cards.LONG_WIND)
	check(not b.companion_bonus_action and b.long_wind_bonus == 1, "追加其他技能生效并结束连杀")
	use(b, Cards.TEN_STEPS)
	check(not b.companion_bonus_action and b.enemy_hps[1] == 96, "十步未击杀终止追击")
	b.free()
	b = scene()
	use(b, Cards.GRIND_SWORD)
	use(b, Cards.GRIND_SWORD)
	b._damage_enemy_at(0, 3)
	check(b.enemy_hps[0] == 97 and b.grind_sword_ready, "磨剑不增强玩家攻击，也不叠加")
	use(b, Cards.FROST_COLD)
	check(b.enemy_hps == [87,90] and not b.grind_sword_ready, "蓄势加倍群伤，整招只消耗一次")
	use(b, Cards.FROST_COLD)
	check(b.enemy_hps == [82,85], "下一招恢复普通伤害")
	use(b, Cards.GRIND_SWORD)
	use(b, Cards.LONG_WIND)
	check(b.grind_sword_ready, "非伤害技能不消耗蓄势")
	b.free()
	b = scene()
	b.enemy_intents.assign([{"type":0,"value":12,"segments":[6,6]}, {"type":0,"value":15,"segments":[5,5,5]}])
	use(b, Cards.YIN_MOUNTAIN)
	check(b._enemy_intent_damage_total() == 12 and bool(b.enemy_intents[1].get("intercepted", false)), "阴山拦截修正后总伤害最高敌人的全部攻击段")
	b.free()
	b = scene()
	b.enemy_guards.assign([50,60])
	b.enemy_hps.assign([80,100])
	use(b, Cards.BEHEAD_LOULAN)
	check(b.enemy_hps == [80,86] and b.enemy_guards == [50,60], "斩楼兰无视格挡且攻击最高血目标")
	b.free()
	b = scene()
	use(b, Cards.CUT_WATER)
	b._resolve_enemy_turn()
	b.combo = 3
	b.energy = 9
	b._play_defense_card(0, 5)
	b._play_status_card(0, 0)
	check(b.combo == 3 and b.cut_water_active, "断水保护整个下回合多次防御和状态出牌")
	b.free()
	b = scene()
	b.player_hp = 5
	b.block = 0
	b.enemy_intents.assign([{"type":0,"value":20,"segments":[5,5,10]}, {"type":0,"value":10}])
	use(b, Cards.FEW_RETURN)
	b._resolve_enemy_turn()
	check(b.player_hp == 1 and b.few_return_used and not b.few_return_immune, "几人回保留1血并免疫本回合其他敌人的后续伤害，回合后免疫结束")
	check(Cards.FEW_RETURN not in Tactics.candidates(b._build_companion_context(), [Cards.FEW_RETURN]), "成功救险后本场不能再次选用")
	use(b, Cards.FEW_RETURN)
	b._resolve_enemy_attack_segment(0, 0, 1)
	check(b.player_hp == 0, "下回合不能重复救险")
	b.free()
	b = scene()
	use(b, Cards.FEW_RETURN)
	b.enemy_intents.assign([{"type":4,"value":0},{"type":4,"value":0}])
	b._resolve_enemy_turn()
	check(not b.few_return_used and not b.few_return_active, "没触发致命伤不消耗本场救险次数，保护当回合到期")
	b.free()
	var events = root.get_node("SpecialEventManager")
	events.reset()
	events.enqueue("near_death_clear")
	events.activate_next()
	var result = events.validate_and_resolve({"event_id":"near_death_clear","resolved":true})
	check(result.get("resolved", false) and not result.has("ability_id"), "战后谈心只完成剧情，不授予神通")
	print("SWORD SKILLS: failures=%d" % failures)
	quit(1 if failures else 0)
