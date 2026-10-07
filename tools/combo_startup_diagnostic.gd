extends SceneTree

const Planner = preload("res://tools/combo_planner.gd")
const Safety = preload("res://tools/combo_start_safety.gd")
var failures := 0
var results: Array = []
var state
var cards
var baseline_memory: Dictionary
var horizon := 2
var output_path := "res://.godot/combo-startup-diagnostic.jsonl"
var v2 := false
var seed_start := 200001
var action_regression := false
var legacy_regression := false
var replay_records: Dictionary = {}
const POST_START_ROUNDS := 3

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	state = root.get_node("RunState")
	cards = root.get_node("CardDatabase")
	state.suppress_persistence = true
	root.get_node("AbilityManager").reset()
	baseline_memory = state.relationship_facts.duplicate(true)
	var count := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diagnostic-count="): count = int(arg.get_slice("=", 1))
		if arg.begins_with("--horizon="): horizon = int(arg.get_slice("=", 1))
		if arg == "--v2": v2 = true
		if arg in ["--action-regression", "--legacy-regression"]:
			action_regression = true
			legacy_regression = arg == "--legacy-regression"
			v2 = true
	if v2:
		seed_start = 300001
		output_path = "res://.godot/combo-v2-diagnostic.jsonl"
	if action_regression:
		output_path = "res://.godot/combo-action-regression-%s.jsonl" % ("legacy" if legacy_regression else "sequential")
		var baseline := FileAccess.open("res://docs/experiments/combo-v2-diagnostic-2026-10-06.jsonl", FileAccess.READ)
		while not baseline.eof_reached():
			var line := baseline.get_line()
			if line.is_empty(): continue
			var record: Dictionary = JSON.parse_string(line)
			replay_records["%d/%d/%s" % [record["winds"], record["seed"], record["version"]]] = record
	if horizon != 2:
		output_path = "res://.godot/combo-startup-diagnostic-h%d.jsonl" % horizon
	var reset_output := FileAccess.open(output_path, FileAccess.WRITE)
	reset_output.close()
	for winds in [1, 2]:
		for seed_value in range(seed_start, seed_start + count):
			for version in ["refund", "draw_only", "no_cloud"]:
				var result: Dictionary = await fight(winds, seed_value, version)
				results.append(result)
				var output := FileAccess.open(output_path, FileAccess.READ_WRITE if FileAccess.file_exists(output_path) else FileAccess.WRITE)
				output.seek_end()
				output.store_line(JSON.stringify(result))
				output.close()
				print("DIAGNOSTIC winds=%d seed=%d version=%s rounds=%d eligible=%d planning_ms=%d won=%s truncated=%s" % [winds, seed_value, version, result["rounds"].size(), result["eligible_rounds_denominator"], result["planning_ms"], result["won"], result["truncated"]])
	var summary := FileAccess.open(output_path.trim_suffix(".jsonl") + "-summary.json", FileAccess.WRITE)
	summary.store_string(JSON.stringify(results, "\t"))
	print("DIAGNOSTIC_COMPLETE games=%d failures=%d" % [results.size(), failures])
	quit(1 if failures else 0)

func fight(winds: int, seed_value: int, version: String) -> Dictionary:
	state._reset_deck()
	if v2:
		for _i in range(4): state.deck.erase(cards.DEFENSE)
		state.deck.append_array([cards.COMBO_BOOST, cards.COMBO_BOOST, cards.TUNE_BREATH, cards.SHADOW_STEP])
		if winds == 2: state.deck.erase(cards.ATTACK)
	state.deck.append(cards.ATTACK if version == "no_cloud" else cards.FLOWING_CLOUD)
	for _i in range(winds): state.deck.append(cards.CHASE_WIND)
	state.relationship_facts = baseline_memory.duplicate(true)
	state.player_hp = 90
	state.player_max_hp = 90
	state.bond_value = 50
	state.bond_stage = 2
	state.learned_sword_intents.clear()
	state.active_promise = ""
	state.route_layer = 8
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = load("res://scenes/battle.tscn").instantiate()
	if legacy_regression: battle.set_script(load("res://tools/legacy_aggregate_enemy_turn.gd"))
	battle.force_offline_companion = true
	battle.offline_experiment = true
	battle.fixed_random_seed = seed_value
	battle.flowing_cloud_refunds_energy = version == "refund" and not v2
	root.add_child(battle)
	# 固定角色组合；生命仍按相同种子和第8层配置生成。
	battle.enemy_roles.assign(["swordsman", "guardian"])
	var life_rng := RandomNumberGenerator.new()
	life_rng.seed = seed_value + 900001
	var config: Dictionary = root.get_node("EnemyDatabase").get_normal_config(8)
	battle.enemy_hps.assign([life_rng.randi_range(140 if v2 else config["hp_min"], 160 if v2 else config["hp_max"]), life_rng.randi_range(140 if v2 else config["hp_min"], 160 if v2 else config["hp_max"])])
	battle.enemy_max_hps = battle.enemy_hps.duplicate()
	battle.enemy_action_step = 0
	battle._roll_enemy_intents()
	battle.companion_selection_records.clear()
	battle._prepare_companion_intent()
	var planner = Planner.new()
	planner.horizon_rounds = horizon
	if v2 and version != "no_cloud": planner.blocked_cards = [15]
	var safety = Safety.new()
	var planning_us := 0
	var calls := 0
	var max_call_us := 0
	var wall_start := Time.get_ticks_msec()
	var truncated := false
	var observed_hands: Array = []
	var eligible_start_turn := -1
	var activation_turn := -1
	var checkpoint: Dictionary = {}
	var post_damage := 0
	var first_five_damage := 0
	var damage_records: Array = []
	var trigger_records: Array = []
	var safety_delays := 0
	var rng_trace: Array = []
	var executed_actions: Array = []
	var replay: Dictionary = replay_records.get("%d/%d/%s" % [winds, seed_value, version], {})
	while not battle.battle_finished:
		if battle.battle_turn_count >= 30 or calls >= 180:
			truncated = true
			break
		var observed := planner.snapshot(battle)
		observed["deck"].sort()
		observed["discard"].sort()
		observed["turn"] = battle.battle_turn_count
		observed["seen_flow"] = int(battle.combo_telemetry.current.get("flowing_light", 0)) > 0
		observed["seen_brilliance"] = int(battle.combo_telemetry.current.get("brilliance", 0)) > 0
		observed_hands.append(observed)
		if action_regression:
			if calls >= replay["observed_hands"].size() or normalize(observed) != normalize(replay["observed_hands"][calls]):
				failures += 1
				truncated = true
				push_error("Observed state differs wind=%d seed=%d version=%s action=%d" % [winds,seed_value,version,calls])
				break
		rng_trace.append({"deck": str(battle.deck_rng.state), "enemy": str(battle.enemy_rng.state), "calls": battle.random_call_counts.duplicate(), "role_calls": root.get_node("EnemyDatabase").role_random_calls})
		var turn: int = battle.battle_turn_count + 1
		if v2 and version != "no_cloud" and eligible_start_turn < 0 and 15 in observed["hand"]:
			eligible_start_turn = turn
		var before := Time.get_ticks_usec()
		var action: Dictionary
		if action_regression:
			action = replay_action(replay, calls)
		elif v2 and version != "no_cloud" and activation_turn < 0 and eligible_start_turn >= 0 and turn >= eligible_start_turn and safety.startable(observed):
			action = {"kind": "card", "id": 15, "target": -1}
		else:
			if v2 and version != "no_cloud" and activation_turn < 0 and eligible_start_turn >= 0 and turn >= eligible_start_turn: safety_delays += 1
			action = planner.choose(battle, seed_value * 1000 + calls)
			if v2 and activation_turn == turn and not safety.accepts(observed, action):
				if safety.find_safe(observed) and not safety.witness.is_empty(): action = safety.witness[0].duplicate()
				else:
					failures += 1
					truncated = true
					break
		var elapsed := Time.get_ticks_usec() - before
		planning_us += elapsed
		max_call_us = maxi(max_call_us, elapsed)
		calls += 1
		executed_actions.append(action.duplicate())
		var hp_before := 0
		for hp in battle.enemy_hps: hp_before += hp
		var trigger_before: bool = battle.flowing_cloud_triggered
		if action["kind"] == "unsupported":
			failures += 1
			truncated = true
			break
		if action["kind"] == "end":
			await battle._end_turn()
		elif action["kind"] == "skill":
			if int(action["id"]) == 13: battle._use_special()
			else: battle._use_ultimate()
			if battle.pending_skill_target > 0: battle._resolve_targeted_skill(int(action["target"]))
		else:
			var found := false
			for slot in range(battle.hand.size()):
				if int(battle.hand[slot]) == int(action["id"]) and battle.hand_buttons[slot].visible:
					battle._play_hand_card(slot)
					if battle.pending_attack_index >= 0: battle._resolve_targeted_attack(int(action["target"]))
					found = true
					break
			if not found:
				failures += 1
				truncated = true
				break
		var hp_after := 0
		for hp in battle.enemy_hps: hp_after += hp
		var dealt := maxi(hp_before - hp_after, 0)
		if turn <= 5: first_five_damage += dealt
		if activation_turn >= 0 and turn < activation_turn + POST_START_ROUNDS: post_damage += dealt
		damage_records.append({"turn": turn, "kind": action["kind"], "damage": dealt, "id": action.get("id", -1), "post_start": activation_turn >= 0})
		if v2 and not trigger_before and battle.flowing_cloud_triggered:
			var after_state := planner.snapshot(battle)
			var remaining: Array = observed["hand"].duplicate()
			remaining.erase(int(action.get("id", -1)))
			var drawn: Array = after_state["hand"].duplicate()
			for held in remaining: drawn.erase(held)
			var available: Array = []
			for id in drawn: available.append({"id": id, "cost": planner.cost(after_state, id), "affordable": planner.cost(after_state, id) <= battle.energy})
			trigger_records.append({"turn": turn, "energy_before_refund": battle.energy - (1 if battle.flowing_cloud_refunds_energy else 0), "energy_after": battle.energy, "drawn": available})
		if v2 and activation_turn < 0 and action.get("id", -1) == 15:
			activation_turn = turn
			checkpoint = planner.snapshot(battle)
			checkpoint["deck"].sort()
			checkpoint["discard"].sort()
			checkpoint["deck_rng_state"] = str(battle.deck_rng.state)
			checkpoint["turn"] = turn
			checkpoint["prior_chain"] = observed["chain"]
			checkpoint["prior_energy"] = observed["energy"]
			planner.blocked_cards.clear()
			battle.flowing_cloud_refunds_energy = version == "refund"
		await process_frame
	var result: Dictionary = battle.combo_telemetry.summary()
	if action_regression:
		result["rng_trace"] = rng_trace
		result["executed_actions"] = executed_actions
		result["final_rng"] = {"deck": str(battle.deck_rng.state), "enemy": str(battle.enemy_rng.state), "calls": battle.random_call_counts.duplicate(), "role_calls": root.get_node("EnemyDatabase").role_random_calls}
	result["horizon"] = horizon
	result["observed_hands"] = observed_hands
	if v2:
		result.merge({"protocol": "v2-diagnostic", "checkpoint": checkpoint, "post_start_rounds": POST_START_ROUNDS, "post_start_damage": post_damage if activation_turn >= 0 else null, "first_five_damage": first_five_damage, "damage_records": damage_records, "trigger_records": trigger_records, "safety_delays": safety_delays})
	result.merge({"winds": winds, "seed": seed_value, "version": version, "deck_size": state.deck.size(), "won": battle._living_enemy_count() == 0, "truncated": truncated, "planning_ms": planning_us / 1000, "planning_calls": calls, "max_call_ms": max_call_us / 1000, "wall_ms": Time.get_ticks_msec() - wall_start, "remaining_hp": battle.player_hp, "intents": battle.companion_selection_records.duplicate(true)})
	battle.queue_free()
	await process_frame
	return result


func normalize(value) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func replay_action(record: Dictionary, index: int) -> Dictionary:
	var event: Dictionary = record["damage_records"][index]
	var action := {"kind": str(event["kind"]), "id": int(event["id"]), "target": -1}
	if action["kind"] == "end": return action
	if action["id"] not in [0,3,6,10,11,13,14,16]: return action
	var before: Dictionary = record["observed_hands"][index]
	if index + 1 < record["observed_hands"].size():
		var after: Dictionary = record["observed_hands"][index + 1]
		for target in range(before["enemy_hp"].size()):
			if before["enemy_hp"][target] != after["enemy_hp"][target] or before["guard"][target] != after["guard"][target]:
				action["target"] = target
				return action
	# 最后一次定向攻击结束战斗时只可能剩一个活目标。
	var alive: Array = []
	for target in range(before["enemy_hp"].size()):
		if before["enemy_hp"][target] > 0: alive.append(target)
	if alive.size() != 1:
		failures += 1
		push_error("Cannot infer archived attack target")
	action["target"] = alive[0]
	return action
