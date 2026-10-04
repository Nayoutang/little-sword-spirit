extends SceneTree

const Cards = preload("res://scripts/data/companion_card_database.gd")
const Tactics = preload("res://scripts/battle/companion_tactics.gd")
var failures := 0
var paths: Array[Array] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func enumerate(prefix: Array, used: Array, energy_left: int) -> void:
	paths.append(prefix.duplicate(true))
	var costs := [1, 2, 1, 1, 1]
	for slot in range(5):
		if slot in used or costs[slot] > energy_left:
			continue
		var targets := [0, 1] if slot < 3 else [-1]
		for target in targets:
			var next := prefix.duplicate(true)
			next.append([slot, target])
			var next_used := used.duplicate()
			next_used.append(slot)
			enumerate(next, next_used, energy_left - costs[slot])

func run() -> void:
	var state = root.get_node("RunState")
	check("--cooperation-sim" in OS.get_cmdline_user_args(), "测试必须使用独立存档模式参数")
	if failures > 0:
		quit(1)
		return
	state.player_max_hp = 90
	state.player_hp = 90
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	root.add_child(battle)
	await process_frame
	check(not battle.locked_companion_choice.is_empty(), "玩家行动前意向已锁定")
	var locked: String = battle.locked_companion_choice["card_id"]
	battle._play_hand_card(0)
	battle._resolve_targeted_attack(0)
	check(battle.locked_companion_choice["card_id"] == locked, "正常攻击不改意向")

	# 直接复用真实战斗结算，验证跨回合资源链。
	battle.start_battle()
	battle.combo = 3
	battle._apply_companion_card({"card_id": Cards.GRIND_SWORD, "source": "fallback"})
	battle._resolve_enemy_turn()
	check(battle.combo == 3, "磨剑跨回合保留剑势")
	battle._play_hand_card(0)
	battle._resolve_targeted_attack(0)
	check(int(state.relationship_facts["cooperation"].get("opportunities_used", 0)) > 0, "玩家利用留势被记录")
	battle.enemy_hps[0] = 1
	battle.combo = 3
	battle._apply_companion_card({"card_id": Cards.TEN_STEPS, "source": "fallback"})
	battle._resolve_enemy_turn()
	check(battle.combo == 4, "十步击杀加势并保留")
	battle.enemy_hps.assign([100, 100])
	battle.combo = 1
	battle._apply_companion_card({"card_id": Cards.TEN_STEPS, "source": "fallback"})
	check(battle.combo == 0, "十步未击杀付出连击代价")

	var context := {"player_hp": 50, "player_max_hp": 90, "incoming_damage": 0, "block": 0, "combo": 3, "living_enemies": 2, "lowest_enemy_effective_hp": 100}
	var options: Array[String] = [Cards.CLEAN_CUT, Cards.GRIND_SWORD]
	context["cooperation"] = {"opportunities_used": 0, "opportunities_wasted": 20}
	var cautious := Tactics.choose(context, options)
	context["cooperation"] = {"opportunities_used": 20, "opportunities_wasted": 0}
	var trusting := Tactics.choose(context, options)
	# 连击本身也是投资价值：用零连击且可积势的同战况比较历史。
	context["combo"] = 0
	context["cooperation"] = {"opportunities_used": 0, "opportunities_wasted": 20}
	cautious = Tactics.choose(context, options)
	context["cooperation"] = {"opportunities_used": 20, "opportunities_wasted": 0}
	trusting = Tactics.choose(context, options)
	check(cautious["card_id"] != trusting["card_id"], "相同战况不同配合历史产生不同离线倾向")
	context.merge({"player_hp": 5, "incoming_damage": 14, "strongest_attack": 8, "frost_prevention": 4}, true)
	check(Cards.GRIND_SWORD not in Tactics.candidates(context, options), "致命危险过滤无防护投资")
	# 已亮出的意向只有明确失效才改牌，并提供原因。
	battle.start_battle()
	battle.locked_companion_choice = {"card_id": Cards.GRIND_SWORD, "source": "fallback"}
	battle.combo = 0
	battle._run_companion_turn()
	check(battle.companion_last_card_id != Cards.GRIND_SWORD and battle.companion_last_reason.contains("失效"), "零剑势留势意向失效后解释改牌")
	battle.start_battle()
	var used_before := int(state.relationship_facts["cooperation"].get("opportunities_used", 0))
	var wasted_before := int(state.relationship_facts["cooperation"].get("opportunities_wasted", 0))
	battle._apply_companion_card({"card_id": Cards.CUT_WATER, "source": "fallback"})
	battle._resolve_enemy_turn()
	battle._play_hand_card(0)
	battle._resolve_targeted_attack(0)
	battle._play_hand_card(3)
	check(battle.combo > 0 and not battle.cut_water_active, "断水让攻击后防御保留连击且只用一次")
	check(int(state.relationship_facts["cooperation"].get("opportunities_used", 0)) == used_before + 1, "断水使用记录一次")
	battle._close_cooperation_window()
	check(int(state.relationship_facts["cooperation"].get("opportunities_wasted", 0)) == wasted_before, "已利用机会不算浪费")
	battle.start_battle()
	battle._apply_companion_card({"card_id": Cards.LEAD_MOMENTUM, "source": "fallback"})
	battle._resolve_enemy_turn()
	battle._close_cooperation_window()
	check(int(state.relationship_facts["cooperation"].get("opportunities_wasted", 0)) == wasted_before + 1, "有可用攻击但未接机会记入未使用统计")
	battle.start_battle()
	battle.combo = 3
	battle._apply_companion_card({"card_id": Cards.GRIND_SWORD, "source": "fallback"})
	battle._resolve_enemy_turn()
	used_before = int(state.relationship_facts["cooperation"].get("opportunities_used", 0))
	battle._play_hand_card(3)
	battle._play_hand_card(0)
	battle._resolve_targeted_attack(0)
	battle._play_hand_card(2)
	battle._resolve_targeted_attack(0)
	check(int(state.relationship_facts["cooperation"].get("opportunities_used", 0)) == used_before, "先断掉旧剑势再积累不冒充利用留势")

	enumerate([], [], 3)
	var best_paths := {}
	for intent in [Cards.GRIND_SWORD, Cards.TEN_STEPS, Cards.CUT_WATER]:
		var best_score := -INF
		var winners: Array[String] = []
		for path in paths:
			state.player_hp = 90
			state.relationship_facts["cooperation"] = {}
			battle.start_battle()
			battle.combo = 2
			battle.locked_companion_choice = {"card_id": intent, "reason": "固定实验", "source": "fallback"}
			for action in path:
				battle._play_hand_card(action[0])
				if action[1] >= 0:
					battle._resolve_targeted_attack(action[1])
			battle._end_turn()
			# 多目标诊断分数，不等于完整胜率：伤害、存活、下一回合剑势。
			var score: float = battle.battle_damage_dealt + battle.player_hp - 90 + battle.combo * 2
			if score > best_score:
				best_score = score
				winners.clear()
			if score == best_score:
				winners.append(str(path))
		best_paths[intent] = winners
		print("意向 %s：枚举%d条，最佳诊断分 %.1f，最佳路径 %s" % [intent, paths.size(), best_score, str(winners)])
	var common: Array = best_paths[Cards.GRIND_SWORD].duplicate()
	for intent in [Cards.TEN_STEPS, Cards.CUT_WATER]:
		common = common.filter(func(path): return path in best_paths[intent])
	print("三种意向共有最佳路径数：%d（0才说明本场景未发现同一条通吃路径）" % common.size())
	# 只在隔离的 APPDATA 下进行存档兼容测试。
	check(OS.get_environment("APPDATA").contains("cooperation-user"), "测试用户目录已隔离")
	if failures == 0:
		state.current_save_slot = 3
		var legacy := ConfigFile.new()
		legacy.set_value("relationship", "bond_value", 25)
		legacy.set_value("relationship", "bond_stage", 1)
		legacy.set_value("memory", "sword_intents", [Cards.TEN_STEPS])
		legacy.save("user://save_slot_3.cfg")
		state._load_relationship()
		check(state.bond_value == 25 and Cards.TEN_STEPS in state.learned_sword_intents, "旧档羁绊及剑意保留")
		check(int(state.relationship_facts["cooperation"].get("opportunities_used", 0)) == 0, "旧档默契统计默认零")
		state.suppress_persistence = false
		state.record_cooperation("opportunities_used", 2)
		state._load_relationship()
		check(int(state.relationship_facts["cooperation"].get("opportunities_used", 0)) == 2, "新增默契统计保存读取")
		state.suppress_persistence = true
	print("机制断言失败数：%d；枚举仅为单回合诊断，不证明游戏好玩。" % failures)
	battle.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
