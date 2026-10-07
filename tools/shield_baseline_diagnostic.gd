extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var shield_step := "--shield-card-diagnostic" in OS.get_cmdline_user_args()
	var retain_step := "--retain-shield-diagnostic" in OS.get_cmdline_user_args()
	var sensitivity := "--retain-sensitivity" in OS.get_cmdline_user_args()
	var long_check := "--retain-long-check" in OS.get_cmdline_user_args()
	var parry_step := "--parry-diagnostic" in OS.get_cmdline_user_args()
	var followup := "--shield-calibration-followup" in OS.get_cmdline_user_args()
	var calibration := "--shield-calibration-v2" in OS.get_cmdline_user_args() or followup
	var path := "res://.godot/shield-strike-step-one.jsonl" if shield_step else ("res://.godot/shield-calibration-v2.jsonl" if calibration else "res://.godot/shield-baseline-diagnostic.jsonl")
	if retain_step: path = "res://.godot/retain-shield-step-two.jsonl"
	if sensitivity: path = "res://.godot/retain-shield-sensitivity.jsonl"
	if long_check: path = "res://.godot/retain-shield-long.jsonl"
	if parry_step: path = "res://.godot/parry-step-three.jsonl"
	var output := FileAccess.open(path, FileAccess.READ_WRITE if followup else FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	var games := 0
	if parry_step:
		for continuous in [false,true]:
			for multi in [false,true]:
				for copies in [0,1]:
					for seed_value in range(400001,400021):
						var result := await fight(24 if continuous else 30,multi,"A",seed_value,180,2,true,continuous,24,copies)
						result["group"] = "%s_%s_%s" % ["continuous" if continuous else "interval","multi" if multi else "single","parry" if copies else "control"]
						output.store_line(JSON.stringify(result))
						games += 1
					output.flush()
					print("PARRY continuous=%s multi=%s copies=%d complete" % [continuous,multi,copies])
		output.close()
		print("PARRY_DIAGNOSTIC_COMPLETE games=%d failures=%d" % [games,failures])
		quit(1 if failures else 0)
		return
	if long_check:
		for seed_value in range(400001,400021):
			var result := await fight(30,false,"A",seed_value,400,1,true,false,64)
			result["group"] = "long_one"
			output.store_line(JSON.stringify(result))
			games += 1
		output.close()
		print("RETAIN_LONG_COMPLETE games=%d failures=%d" % [games,failures])
		quit(1 if failures else 0)
		return
	if sensitivity:
		var configs := [{"name":"interval_one","hit":30,"copies":1,"retain":true,"strategy":"A","continuous":false}, {"name":"interval_two","hit":30,"copies":2,"retain":true,"strategy":"A","continuous":false}, {"name":"continuous_baseline","hit":24,"copies":0,"retain":false,"strategy":"B","continuous":true}, {"name":"continuous_two","hit":24,"copies":2,"retain":true,"strategy":"A","continuous":true}]
		for config in configs:
			for seed_value in range(400001,400021):
				var result := await fight(config["hit"],false,config["strategy"],seed_value,180,config["copies"],config["retain"],config["continuous"])
				result["group"] = config["name"]
				output.store_line(JSON.stringify(result))
				games += 1
			output.flush()
			print("RETAIN_SENSITIVITY group=%s complete" % config["name"])
		output.close()
		print("RETAIN_SENSITIVITY_COMPLETE games=%d failures=%d" % [games,failures])
		quit(1 if failures else 0)
		return
	if retain_step:
		for group in ["baseline","retain_only","retain_strike"]:
			for seed_value in range(400001,400021):
				var result := await fight(30,false,"B" if group == "baseline" else "A",seed_value,180,2 if group == "retain_strike" else 0,group != "baseline")
				result["group"] = group
				output.store_line(JSON.stringify(result))
				games += 1
			output.flush()
			print("RETAIN_SHIELD group=%s complete" % group)
		output.close()
		print("RETAIN_SHIELD_STEP_TWO games=%d failures=%d" % [games,failures])
		quit(1 if failures else 0)
		return
	if shield_step:
		for copies in [0,2]:
			for seed_value in range(400001,400021):
				output.store_line(JSON.stringify(await fight(30,false,"B",seed_value,180,copies)))
				games += 1
			output.flush()
		output.close()
		print("SHIELD_STRIKE_STEP_ONE games=%d failures=%d" % [games,failures])
		quit(1 if failures else 0)
		return
	if calibration:
		if followup:
			var prior_lines := 0
			while output.get_position() < output.get_length():
				if not output.get_line().strip_edges().is_empty(): prior_lines += 1
			if prior_lines != 160:
				push_error("Followup requires exactly 160 initial records; refusing duplicate append")
				output.close()
				quit(1)
				return
			output.seek_end()
		var configurations: Array = [[180,30]] if followup else [[140,24],[140,32],[160,26],[160,28],[180,26],[180,28],[280,24],[280,28]]
		for config in configurations:
			for seed_value in range(400001,400021):
				output.store_line(JSON.stringify(await fight(config[1],false,"B",seed_value,config[0])))
				games += 1
			output.flush()
			print("SHIELD_CALIBRATION hp=%d H=%d complete" % [config[0],config[1]])
		output.close()
		print("SHIELD_CALIBRATION_COMPLETE games=%d failures=%d" % [games,failures])
		quit(1 if failures else 0)
		return
	for hit in [24,32,40]:
		for multi in [false,true]:
			for strategy in ["A","B"]:
				for seed_value in range(400001,400021):
					output.store_line(JSON.stringify(await fight(hit, multi, strategy, seed_value)))
					games += 1
				output.flush()
				print("SHIELD_BASELINE H=%d multi=%s strategy=%s complete" % [hit,multi,strategy])
	output.close()
	print("SHIELD_BASELINE_COMPLETE games=%d failures=%d" % [games,failures])
	quit(1 if failures else 0)

func fight(hit: int, multi: bool, strategy: String, seed_value: int, enemy_life := 140, shield_copies := 0, carry := false, continuous := false, turn_limit := 24, parry_copies := 0) -> Dictionary:
	var state = root.get_node("RunState")
	state._reset_deck()
	state.deck.assign([1,1,1,1,4,4,12,12,0,0,0,6,8,8,9])
	for _copy in range(shield_copies): state.deck[state.deck.find(0)] = 17
	if carry: state.deck[state.deck.find(1)] = 18
	for _copy in range(parry_copies): state.deck[state.deck.find(1)] = 19
	state.player_hp = 90
	state.player_max_hp = 90
	state.bond_value = 50
	state.bond_stage = 2
	state.learned_sword_intents.clear()
	state.relationship_facts.clear()
	state.active_promise = ""
	state.route_layer = 8
	state.pending_encounter = state.EncounterType.NORMAL
	root.get_node("AbilityManager").reset()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.set_script(load("res://tools/shield_baseline_battle.gd"))
	battle.calibration_hit = hit
	battle.calibration_multi = multi
	battle.calibration_continuous = continuous
	battle.force_offline_companion = true
	battle.offline_experiment = true
	battle.fixed_random_seed = seed_value
	root.add_child(battle)
	battle.enemy_hps.assign([enemy_life,0])
	battle.enemy_max_hps.assign([enemy_life,0])
	battle.enemy_guards.assign([0,0])
	battle.enemy_roles.assign(["swordsman","guardian"])
	battle._roll_enemy_intents()
	battle.companion_selection_records.clear()
	battle._prepare_companion_intent()
	var actions: Array = []
	var damage_sources := {"hand":0,"brilliance":0,"companion":0}
	if parry_copies > 0: damage_sources["parry"] = 0
	var shield_damage := 0
	var held: Dictionary = {}
	var exposures: Array = []
	var calls := 0
	var activation_turn := -1
	var start_blocks: Array = []
	var last_turn := -1
	while not battle.battle_finished and battle.battle_turn_count < turn_limit and calls < turn_limit * 13:
		calls += 1
		var turn: int = battle.battle_turn_count + 1
		if last_turn != turn:
			start_blocks.append({"turn":turn,"shield":battle.block,"active":battle.retain_shield_active})
			last_turn = turn
		observe_shields(battle, held, turn)
		var damage_before: int = battle.battle_damage_dealt
		var parry_damage_before: int = battle.battle_parry_damage
		var activation_slot := -1
		if carry and not battle.retain_shield_active:
			for slot in range(battle.hand.size()):
				if battle.hand_buttons[slot].visible and int(battle.hand[slot]) == 18 and battle.energy >= 1: activation_slot = slot
		if battle.combo >= 3 and activation_slot < 0:
			battle._use_ultimate()
			if battle.pending_skill_target > 0: battle._resolve_targeted_skill(0)
			var dealt: int = battle.battle_damage_dealt - damage_before
			damage_sources["brilliance"] += dealt
			actions.append({"turn":turn,"id":14,"damage":dealt})
			continue
		var slot := activation_slot if activation_slot >= 0 else choose_slot(battle, strategy)
		if slot < 0:
			actions.append({"turn":turn,"id":-1})
			await battle._end_turn()
			close_held(held,exposures,"battle_end" if battle.battle_finished else "discarded")
			var dealt: int = battle.battle_damage_dealt - damage_before
			var reflected: int = battle.battle_parry_damage - parry_damage_before
			if parry_copies > 0: damage_sources["parry"] += reflected
			damage_sources["companion"] += dealt - reflected
			actions[-1]["damage"] = dealt
			if parry_copies > 0: actions[-1]["parry_damage"] = reflected
		else:
			var id := int(battle.hand[slot])
			actions.append({"turn":turn,"id":id,"shield":battle.block,"combo":battle.combo,"boon":battle.pending_boon.duplicate(true),"vulnerable":battle.enemy_vulnerabilities[0],"enemy_guard":battle.enemy_guards[0]})
			if id == 18: activation_turn = turn
			if id == 17:
				var exposure: Dictionary = held[slot].duplicate(true)
				exposure["outcome"] = "played"
				exposures.append(exposure)
				held.erase(slot)
			battle._play_hand_card(slot)
			if battle.pending_attack_index >= 0: battle._resolve_targeted_attack(0)
			var dealt: int = battle.battle_damage_dealt - damage_before
			damage_sources["hand"] += dealt
			if id == 17: shield_damage += dealt
			actions[-1]["damage"] = dealt
	close_held(held,exposures,"battle_end" if battle.battle_finished else "cutoff")
	var rows: Array = battle.combo_telemetry.rounds.duplicate(true)
	var cycles: Array = []
	for index in range(0,rows.size()-1,2):
		var calm: Dictionary = rows[index]
		var strike: Dictionary = rows[index+1]
		if not calm.has("enemy_incoming") or not strike.has("enemy_incoming"): continue
		# 致命导致部分攻击段未执行的周期单独记录，不混进完整周期比例。
		var alive: bool = not (battle.player_hp == 0 and index + 1 == rows.size() - 1)
		var one := int(strike.get("block_gained_player",0)) + int(strike.get("block_gained_companion",0))
		var both := one + int(calm.get("block_gained_player",0)) + int(calm.get("block_gained_companion",0))
		var incoming := 0
		for phase in [calm,strike]:
			for action in phase.get("enemy_actions",[]):
				if action.get("type","") == "attack" and action.get("executed",false): incoming += int(action["damage"])
		var cycle := {"complete":alive,"strike_shield":one,"cycle_shield":both,"incoming":incoming,"raw_hit":hit,"life_lost":int(calm.get("life_lost",0))+int(strike.get("life_lost",0))}
		if carry: cycle.merge({"start_turn":int(calm["turn"]),"start_shield":int(calm.get("starting_block",0)),"end_shield":int(strike.get("block_carried",0))})
		cycles.append(cycle)
	var result := {"shield_copies":shield_copies,"shield_damage":shield_damage,"shield_exposures":exposures,"initial_enemy_hp":enemy_life,"damage_sources":damage_sources,"hit":hit,"multi":multi,"strategy":strategy,"seed":seed_value,"won":battle.enemy_hps[0]==0,"dead":battle.player_hp<=0,"truncated":not battle.battle_finished,"hp":battle.player_hp,"turns":battle.battle_turn_count,"enemy_hp":battle.enemy_hps[0],"cycles":cycles,"rounds":rows,"actions":actions,"intents":battle.companion_selection_records.duplicate(true)}
	result.merge({"retain":carry,"activation_turn":activation_turn,"start_blocks":start_blocks,"continuous":continuous})
	if parry_copies > 0: result["parry_copies"] = parry_copies
	if damage_sources["hand"] + damage_sources["brilliance"] + damage_sources["companion"] + int(damage_sources.get("parry",0)) != enemy_life - battle.enemy_hps[0]:
		failures += 1
		push_error("damage source conservation mismatch")
	if result["truncated"]: failures += 1
	battle.queue_free()
	await process_frame
	return result

func choose_slot(battle, strategy: String) -> int:
	var defend: bool = strategy == "A" or battle._enemy_intent_damage_total() > 0
	var has_strike := false
	for slot in range(battle.hand.size()):
		if battle.hand_buttons[slot].visible and int(battle.hand[slot]) == 17: has_strike = true
	# 固定优先级，不读牌堆。调息先抽；防御优先，再攻击，再付费补牌。
	var priority: Array = [8,19,12,4,1,17,6,0,9] if defend else [8,17,6,0,9]
	for id in priority:
		for slot in range(battle.hand.size()):
			if not battle.hand_buttons[slot].visible or int(battle.hand[slot]) != id: continue
			if battle._card_cost(battle.hand[slot]) > battle.energy: continue
			if has_strike and id in [19,12,4,1] and battle.energy - battle._card_cost(battle.hand[slot]) < 1: continue
			if id == 8 and battle.tune_breath_used_this_turn: continue
			if id == 17 and battle.block <= 0: continue
			return slot
	return -1

func observe_shields(battle, held: Dictionary, turn: int) -> void:
	for slot in range(battle.hand.size()):
		if not battle.hand_buttons[slot].visible or int(battle.hand[slot]) != 17: continue
		if not held.has(slot):
			held[slot] = {"turn":turn,"initial_shield":battle.block,"max_shield":battle.block,"min_shield":battle.block,"ever_affordable":false}
		var record: Dictionary = held[slot]
		record["max_shield"] = maxi(int(record["max_shield"]),battle.block)
		record["min_shield"] = mini(int(record["min_shield"]),battle.block)
		record["last_shield"] = battle.block
		record["last_affordable"] = battle.energy >= 1
		record["ever_affordable"] = bool(record["ever_affordable"]) or battle.energy >= 1

func close_held(held: Dictionary, exposures: Array, outcome: String) -> void:
	for slot in held:
		var record: Dictionary = held[slot].duplicate(true)
		record["outcome"] = outcome
		exposures.append(record)
	held.clear()
