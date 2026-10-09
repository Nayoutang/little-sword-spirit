extends SceneTree

const Planner = preload("res://tools/combo_planner.gd")
const Metrics = preload("res://scripts/battle/combo_telemetry.gd")
const Log = preload("res://scripts/battle/bounded_jsonl.gd")
const Stats = preload("res://tools/combo_pair_statistics.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.bond_stage = 2
	state.bond_value = 50
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	root.add_child(battle)
	await process_frame
	var planner = Planner.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var s := planner.snapshot(battle)
	s["enemy_hp"] = [1000, 1000]
	s["guard"] = [0, 0]
	s["vulnerable"] = [0, 0]
	s["hand"] = [0, 6, 16, 0]
	s["cloud"] = true
	s["combo"] = 0
	s["energy"] = 3
	s["chain"] = 0
	s["deck"] = []
	s["discard"] = []
	for id in [0, 6, 13, 16, 0, 14]:
		planner.apply_card(s, {"kind": "skill" if id in [13, 14] else "card", "id": id, "target": 0}, rng)
	check(s["damage"] == 94 and s["energy"] == 0 and s["chain"] == 4, "planner baseline matches actual94")
	var preserved := s.duplicate(true)
	preserved["hp"] = 90
	preserved["combo"] = 2
	preserved["locked"] = "heart_resonance"
	preserved["allowed"] = ["heart_resonance", "guard_echo"]
	planner.end_round(preserved, rng)
	check(preserved["combo"] == 2, "locked heart resonance preserved in forecast")
	var decision := planner.snapshot(battle)
	decision["hp"] = 5
	decision["enemy_hp"] = [1000, 1000]
	decision["intents"] = [{"type": 0, "value": 10}, {"type": 4, "value": 0}]
	decision["hand"] = [1]
	decision["deck"] = []
	decision["discard"] = []
	decision["allowed"] = ["quick_slash"]
	decision["locked"] = "quick_slash"
	var chosen := planner.choose_state(decision, 19)
	check(chosen.get("id", -1) == 1, "planner avoids first-round lethal")
	check(chosen == planner.choose_state(decision, 19), "deterministic planner")
	var early := decision.duplicate(true)
	early["enemy_hp"] = [0, 0]
	early["victory_round"] = 0
	var late := early.duplicate(true)
	late["victory_round"] = 1
	check(planner.value(early) == planner.value(late) + 5.0, "earlier victory has explicit bonus")
	var unkept := decision.duplicate(true)
	unkept["combo"] = 6
	unkept["preserve"] = false
	var no_combo := unkept.duplicate(true)
	no_combo["combo"] = 0
	check(planner.value(unkept) == planner.value(no_combo), "unprotected intermediate combo has no terminal reward")
	unkept["round"] = 2
	check(planner.value(unkept) == planner.value(no_combo) + 3.0, "post-boundary retained combo has terminal value")
	var hold := planner.snapshot(battle)
	hold["hand"] = []
	hold["deck"] = []
	hold["discard"] = []
	hold["combo"] = 3
	hold["enemy_hp"] = [30, 0]
	hold["guard"] = [100, 0]
	hold["vulnerable"] = [0, 0]
	hold["intents"] = [{"type": 4, "value": 0}, {"type": 4, "value": 0}]
	hold["locked"] = "heart_resonance"
	hold["allowed"] = ["heart_resonance"]
	check(planner.choose_state(hold, 31)["kind"] == "end", "two-round planner waits through armor with locked heart resonance")
	var actual_state := planner.snapshot(battle)
	actual_state["locked"] = "heart_resonance"
	actual_state["allowed"] = ["heart_resonance", "guard_echo"]
	actual_state["combo"] = 2
	battle.combo = 2
	var hp_before: int = battle.player_hp
	planner.end_round(actual_state, rng)
	battle._apply_companion_card({"card_id": "heart_resonance", "source": "replay"})
	battle._resolve_enemy_turn()
	check(actual_state["hp"] == battle.player_hp and actual_state["combo"] == battle.combo and actual_state["block"] == battle.block, "forecast turn boundary matches actual health and heart resonance carry")
	check(hp_before - battle.player_hp == actual_state["loss"], "forecast accumulated loss matches actual")
	# 同样立即少打伤害，同心剑鸣留势的两轮价值应进入目标，而非清零。
	var m = Metrics.new()
	m.begin_round(1, 0, true, true, 1)
	m.observe_combo(3, "attack")
	m.record_action(13, 1, 3, 1, true, 1, 1)
	m.observe_combo(3, "attack")
	m.record_action(14, 0, 3, 0, true, 0, 1)
	m.finish_round(0, "end")
	m.begin_round(2, 3, true, true)
	m.finish_battle(1)
	var summary := m.summary()
	check(summary["joint_skills_numerator"] == 1 and summary["eligible_rounds_denominator"] == 2, "eligible numerator denominator")
	check(summary["intervals"].size() == 3 and summary["intervals"][0]["outcome"] == "flowing_light" and summary["intervals"][1]["outcome"] == "brilliance" and summary["intervals"][2]["outcome"] == "battle_end", "multiple eligibility intervals and endpoints")
	var startup = Metrics.new()
	startup.begin_round(1, 0, false, true)
	startup.current["cloud_in_hand"] = 1
	startup.finish_round(0, "end")
	startup.begin_round(2, 0, false, true)
	startup.current["cloud_in_hand"] = 1
	startup.record_action(15, 1, 0, 0, true, 0, 1)
	startup.finish_battle(0)
	var startup_summary := startup.summary()
	check(startup_summary["cloud_first_seen_turn"] == 1 and startup_summary["cloud_activation_turn"] == 2 and startup_summary["cloud_unplayed_opportunity_rounds"] == 1, "cloud draw versus strategy delay distinguished")
	var zero := {"joint_skills_numerator": 0, "eligible_rounds_denominator": 0}
	var yes := {"joint_skills_numerator": 1, "eligible_rounds_denominator": 1}
	var no := {"joint_skills_numerator": 0, "eligible_rounds_denominator": 1}
	var estimate := Stats.bootstrap([[zero, no], [yes, zero]], 11, 100)
	check(estimate["rates"] == [1.0, 0.0] and estimate["difference"] == 1.0 and estimate["seed_pairs"] == 2, "pooled estimate retains zero-denominator seed pairs")
	var p := "res://.godot/bounded-log-smoke.jsonl"
	Log.append(p, {"payload": "x".repeat(90)}, true, 160)
	Log.append(p, {"payload": "y".repeat(90)}, true, 160)
	check(FileAccess.file_exists(p + ".1"), "log rotates")
	var f := FileAccess.open(p, FileAccess.READ)
	var length := f.get_length()
	f.close()
	Log.append(p, {"payload": "disabled"}, false, 160)
	f = FileAccess.open(p, FileAccess.READ)
	check(f.get_length() == length and length <= 160, "log toggle and bound")
	f.close()
	battle.queue_free()
	await process_frame
	print("COMBO_PLANNER_SMOKE failures=%d" % failures)
	quit(1 if failures else 0)
