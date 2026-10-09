extends RefCounted

# 仅离线实验用的两回合近似规划器；不替代玩家或正式LLM。
const Tactics = preload("res://scripts/battle/companion_tactics.gd")
const Companion = preload("res://scripts/data/companion_card_database.gd")
const BEAM_WIDTH := 16
const MAX_ACTIONS := 12
const DRAW_SAMPLES := 4
var cards
var enemies
var state
var horizon_rounds := 2
var blocked_cards: Array = []

func _init() -> void:
	var tree = Engine.get_main_loop()
	cards = tree.root.get_node("CardDatabase")
	enemies = tree.root.get_node("EnemyDatabase")
	state = tree.root.get_node("RunState")

func snapshot(battle) -> Dictionary:
	var held: Array = []
	for i in range(battle.hand.size()):
		if battle.hand_buttons[i].visible:
			held.append(int(battle.hand[i]))
	return {"hp": battle.player_hp, "max_hp": battle.player_max_hp, "energy": battle.energy, "combo": battle.combo, "chain": battle.consecutive_attacks, "block": battle.block,
		"cloud": battle.flowing_cloud_active, "triggered": battle.flowing_cloud_triggered, "refund": battle.flowing_cloud_refunds_energy,
		"preserve": battle.preserve_combo_this_turn, "cut_water": battle.cut_water_active, "tuned": battle.tune_breath_used_this_turn,
		"hand": held, "deck": battle.draw_pile.duplicate(), "discard": battle.discard_pile.duplicate(),
		"enemy_hp": battle.enemy_hps.duplicate(), "guard": battle.enemy_guards.duplicate(), "vulnerable": battle.enemy_vulnerabilities.duplicate(),
		"intents": battle.enemy_intents.duplicate(true), "roles": battle.enemy_roles.duplicate(), "step": battle.enemy_action_step,
		"layer": state.route_layer, "stage": state.get_bond_stage_index(), "allowed": battle._allowed_companion_cards(),
		"locked": str(battle.locked_companion_choice.get("card_id", "")), "boon": battle.pending_boon.duplicate(true),
		"cooperation": state.relationship_facts.get("cooperation", {}).duplicate(true), "promise": state.active_promise,
		"reductions": battle.enemy_attack_reductions.duplicate(),
		"damage": 0, "loss": 0, "round": 0, "first": {}, "extra_energy": 0}

func choose(battle, planning_seed := 701) -> Dictionary:
	if state.pending_encounter != state.EncounterType.NORMAL:
		return {"kind": "unsupported", "reason": "primary planner excludes Boss"}
	for id in state.learned_sword_intents:
		if id not in ["cut_water", "long_wind"]:
			return {"kind": "unsupported", "reason": "unsupported learned intent: " + id}
	return choose_state(snapshot(battle), planning_seed)

func choose_state(initial: Dictionary, planning_seed := 701) -> Dictionary:
	var totals: Dictionary = {}
	for sample in range(DRAW_SAMPLES):
		var rng := RandomNumberGenerator.new()
		rng.seed = planning_seed + sample * 104729
		var start := initial.duplicate(true)
		start["deck"].sort()
		shuffle(start["deck"], rng)
		start["rng_state"] = rng.state
		var frontier: Array = [start]
		var leaves: Array = []
		for _depth in range(MAX_ACTIONS * horizon_rounds):
			var expanded: Array = []
			for node in frontier:
				if int(node["round"]) >= horizon_rounds or int(node["hp"]) <= 0 or living(node) == 0:
					leaves.append(node)
					continue
				var options := legal_actions(node)
				for action in options:
					var next: Dictionary = node.duplicate(true)
					rng.state = int(node["rng_state"])
					if next["first"].is_empty():
						next["first"] = action.duplicate()
					if action["kind"] == "end":
						end_round(next, rng)
					else:
						apply_card(next, action, rng)
					next["rng_state"] = rng.state
					expanded.append(next)
			if expanded.is_empty():
				break
			# 按首动作保留分支，避免单一即时伤害启发式淘汰留势路线。
			var groups: Dictionary = {}
			for node in expanded:
				var key := JSON.stringify(node["first"])
				if not groups.has(key): groups[key] = []
				groups[key].append(node)
			frontier = []
			for group in groups.values():
				group.sort_custom(func(a, b): return value(a) > value(b))
				frontier.append_array(group.slice(0, BEAM_WIDTH))
		for node in frontier:
			rng.state = int(node["rng_state"])
			while int(node["round"]) < horizon_rounds and int(node["hp"]) > 0 and living(node) > 0:
				end_round(node, rng)
			leaves.append(node)
		var best_by_first: Dictionary = {}
		for node in leaves:
			var key := JSON.stringify(node["first"])
			if not best_by_first.has(key) or value(node) > best_by_first[key]:
				best_by_first[key] = value(node)
		for key in best_by_first:
			totals[key] = float(totals.get(key, 0.0)) + float(best_by_first[key]) / DRAW_SAMPLES
	var best_key := ""
	var best_score := -INF
	var keys: Array = totals.keys()
	keys.sort()
	for key in keys:
		if float(totals[key]) > best_score:
			best_key = key
			best_score = float(totals[key])
	return JSON.parse_string(best_key) if not best_key.is_empty() else {"kind": "end"}

func value(s: Dictionary) -> float:
	# 权重为预先登记的实验策略，不是已验证的玩家效用。
	var won := living(s) == 0
	var surviving := int(s["hp"]) > 0
	# 完成两个回合末结算后，combo已经执行清零或留势；中间节点只估值明确留势的层数。
	var carried_combo := int(s["combo"]) if int(s["round"]) >= horizon_rounds or bool(s["preserve"]) else 0
	var terminal_value := 0.5 * mini(carried_combo, 6) + (2.0 if s["cloud"] else 0.0) if surviving and not won else 0.0
	var victory_value := 100000.0 + (5.0 if int(s.get("victory_round", 1)) == 0 else 0.0) if won else 0.0
	return (-1000000.0 if not surviving else 0.0) + victory_value + float(s["damage"]) - 2.0 * float(s["loss"]) + terminal_value

func living(s: Dictionary) -> int:
	var n := 0
	for hp in s["enemy_hp"]:
		if hp > 0: n += 1
	return n

func cost(s: Dictionary, id: int) -> int:
	return maxi(2 - int(s["chain"]), 0) if id == 16 else cards.get_cost(id)

func legal_actions(s: Dictionary) -> Array:
	var result: Array = [{"kind": "end"}]
	var seen: Array = []
	for id in s["hand"]:
		if id in blocked_cards: continue
		if id in seen or id == 7 or cost(s, id) > s["energy"] or (id == 15 and s["cloud"]) or (id == 8 and s["tuned"]): continue
		seen.append(id)
		if cards.get_definition(id).get("type", "") == "攻击" and id != 5 or id == 11:
			for target in range(s["enemy_hp"].size()):
				if s["enemy_hp"][target] > 0: result.append({"kind": "card", "id": id, "target": target})
		else:
			result.append({"kind": "card", "id": id, "target": -1})
	for id in [13, 14]:
		var d: Dictionary = cards.get_definition(id)
		if s["stage"] >= d["bond_stage"] and s["combo"] >= d["combo_required"] and s["energy"] >= d["cost"]:
			for target in range(s["enemy_hp"].size()):
				if s["enemy_hp"][target] > 0: result.append({"kind": "skill", "id": id, "target": target})
	return result

func apply_card(s: Dictionary, action: Dictionary, rng: RandomNumberGenerator) -> void:
	var id := int(action["id"])
	var d: Dictionary = cards.get_definition(id)
	s["energy"] -= cost(s, id)
	if action["kind"] == "skill":
		hit(s, action["target"], int(d["damage"]) + int(s["combo"]) * 2)
		s["combo"] = maxi(int(s["combo"]) - 2, 0) if id == 13 else 0
		return
	s["hand"].erase(id)
	if id != 15: s["discard"].append(id)
	var attack: bool = d["type"] == "攻击"
	if attack:
		var damage := int(d["damage"]) + int(s["combo"]) * 2
		if not s["boon"].is_empty():
			damage = roundi(damage * float(s["boon"].get("value", 1))) if s["boon"].get("type") == "multiply" else damage + int(s["boon"].get("value", 0))
			s["boon"].clear()
		if id == 5:
			for target in range(s["enemy_hp"].size()):
				if s["enemy_hp"][target] > 0: hit(s, target, damage)
		else: hit(s, action["target"], damage)
		if id == 10: s["vulnerable"][action["target"]] += 2
		s["combo"] += int(d.get("combo", 1))
	else:
		match id:
			1, 4:
				s["block"] += int(d["block"])
				clear_or_protect(s)
			2:
				clear_or_protect(s)
				draw(s, 1, rng)
			8:
				s["tuned"] = true
				draw(s, 1, rng)
			9: draw(s, 2, rng)
			11:
				var target := int(action["target"])
				if s["intents"][target]["type"] == 0: s["intents"][target]["value"] = maxi(int(s["intents"][target]["value"]) - 5, 0)
				else: s["reductions"][target] += 5
			12:
				s["block"] += int(d["block"])
				s["preserve"] = true
			15: s["cloud"] = true
	s["chain"] = int(s["chain"]) + 1 if attack else 0
	if attack and s["cloud"] and not s["triggered"] and s["chain"] == 3 and living(s) > 0:
		s["triggered"] = true
		draw(s, 1, rng)
		if s["refund"]: s["energy"] += 1

func clear_or_protect(s: Dictionary) -> void:
	if not s["cut_water"]: s["combo"] = 0

func hit(s: Dictionary, target: int, damage: int) -> void:
	if target < 0 or s["enemy_hp"][target] <= 0: return
	damage += int(s["vulnerable"][target])
	var absorbed := mini(int(s["guard"][target]), damage)
	s["guard"][target] -= absorbed
	var actual := mini(int(s["enemy_hp"][target]), damage - absorbed)
	s["enemy_hp"][target] -= actual
	s["damage"] += actual
	if living(s) == 0 and not s.has("victory_round"):
		s["victory_round"] = int(s["round"])

func shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item = items[i]
		items[i] = items[j]
		items[j] = item

func draw(s: Dictionary, count: int, rng: RandomNumberGenerator) -> void:
	for _i in range(count):
		if s["deck"].is_empty():
			s["deck"] = s["discard"].duplicate()
			s["discard"].clear()
			shuffle(s["deck"], rng)
		if s["deck"].is_empty(): return
		s["hand"].append(s["deck"].pop_back())

func companion_context(s: Dictionary) -> Dictionary:
	var lowest := 999999
	var highest := 0
	var low_index := -1
	var high_index := -1
	var incoming := 0
	for i in range(s["enemy_hp"].size()):
		if s["enemy_hp"][i] <= 0: continue
		if low_index < 0 or s["enemy_hp"][i] < s["enemy_hp"][low_index]: low_index = i
		if high_index < 0 or s["enemy_hp"][i] > s["enemy_hp"][high_index]: high_index = i
		if s["intents"][i]["type"] == 0: incoming += int(s["intents"][i]["value"])
	if low_index >= 0: lowest = int(s["enemy_hp"][low_index]) + int(s["guard"][low_index]) - int(s["vulnerable"][low_index])
	if high_index >= 0: highest = int(s["enemy_hp"][high_index]) + int(s["guard"][high_index]) - int(s["vulnerable"][high_index])
	return {"player_hp": s["hp"], "player_max_hp": s["max_hp"], "incoming_damage": incoming, "block": s["block"], "combo": s["combo"], "living_enemies": living(s), "lowest_enemy_effective_hp": lowest, "highest_enemy_effective_hp": highest, "can_build_combo": false, "cooperation": s.get("cooperation", {}), "active_promise": s.get("promise", ""), "companion_target_role": s["roles"][low_index] if low_index >= 0 and low_index < s["roles"].size() else ""}

func end_round(s: Dictionary, rng: RandomNumberGenerator) -> void:
	if living(s) == 0 or s["hp"] <= 0:
		s["round"] = horizon_rounds
		return
	var context := companion_context(s)
	var allowed: Array[String] = []
	allowed.assign(s["allowed"])
	var options := Tactics.candidates(context, allowed)
	if options.is_empty(): options.assign([Companion.GUARD_ECHO])
	var id := str(s["locked"])
	if id not in options: id = str(Tactics.choose(context, options).get("card_id", "guard_echo"))
	s["boon"].clear()
	s["cut_water"] = false
	apply_companion(s, id)
	if living(s) == 0:
		s["round"] = horizon_rounds
		return
	var incoming := 0
	s["guard"].fill(0)
	for i in range(s["enemy_hp"].size()):
		if s["enemy_hp"][i] <= 0: continue
		var intent: Dictionary = s["intents"][i]
		if intent["type"] == 0: incoming += int(intent["value"])
		elif intent["type"] == 1:
			var target := i
			if intent.get("support", false):
				for j in range(s["enemy_hp"].size()):
					if j != i and s["enemy_hp"][j] > 0 and (target == i or s["enemy_hp"][j] < s["enemy_hp"][target]): target = j
			s["guard"][target] += intent["value"]
		elif intent["type"] == 3: s["discard"].append(7)
	var loss := maxi(incoming - int(s["block"]), 0)
	s["hp"] -= loss
	s["loss"] += loss
	s["block"] = 0
	s["combo"] = s["combo"] if s["preserve"] else 0
	s["preserve"] = false
	s["chain"] = 0
	s["triggered"] = false
	s["tuned"] = false
	s["energy"] = 3 + int(s["extra_energy"])
	s["extra_energy"] = 0
	for i in range(s["vulnerable"].size()): s["vulnerable"][i] = maxi(int(s["vulnerable"][i]) - 1, 0)
	s["discard"].append_array(s["hand"])
	s["hand"] = []
	draw(s, 4, rng)
	s["round"] += 1
	for i in range(s["roles"].size()):
		s["intents"][i] = enemies.get_role_intent(s["roles"][i], s["step"], false, s["layer"])
		if s["intents"][i]["type"] == 0:
			s["intents"][i]["value"] = maxi(int(s["intents"][i]["value"]) - int(s["reductions"][i]), 0)
			s["reductions"][i] = 0
	s["step"] += 1
	# 下一轮意向未锁定：用本地策略预测，不读取真实未来LLM。
	var next_context := companion_context(s)
	for card_id in s["hand"]:
		if cards.get_definition(card_id).get("type", "") == "攻击" and cost(s, card_id) <= s["energy"]:
			next_context["can_build_combo"] = true
	var next_options := Tactics.candidates(next_context, allowed)
	if next_options.is_empty(): next_options.assign([Companion.GUARD_ECHO])
	s["locked"] = str(Tactics.choose(next_context, next_options).get("card_id", "guard_echo"))

func apply_companion(s: Dictionary, id: String) -> void:
	var d := Companion.get_definition(id)
	var target := -1
	for i in range(s["enemy_hp"].size()):
		if s["enemy_hp"][i] > 0 and (target < 0 or s["enemy_hp"][i] < s["enemy_hp"][target]): target = i
	if target >= 0 and d.has("damage"): hit(s, target, int(d["damage"]) + int(s["combo"]) * int(d.get("combo_scale", 0)))
	s["block"] += int(d.get("block", 0))
	if id == "oath_guard" and s.get("promise", "") == "protect": s["block"] += 3
	match id:
		"follow_up": s["combo"] += 1
		"lone_judgment": s["combo"] = 0
		"heart_resonance": s["preserve"] = true
		"grind_sword": s["grind_ready"] = true
		"cut_water": s["cut_water"] = true
		"long_wind": s["extra_energy"] = 1
		"lead_momentum", "escort": s["boon"] = {"type": d["boon_type"], "value": d["boon_value"]}
		"ten_steps": s["extra_action"] = target >= 0 and s["enemy_hp"][target] <= 0
