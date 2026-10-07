extends SceneTree

const Feasibility = preload("res://tools/combo_feasibility.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var checker = Feasibility.new()
	var input_path := "res://.godot/combo-startup-diagnostic-h3.jsonl"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input_path = arg.trim_prefix("--input=")
	var input := FileAccess.open(input_path, FileAccess.READ)
	if input == null:
		push_error("Missing input: " + input_path)
		quit(1)
		return
	var groups: Dictionary = {}
	var examples: Array = []
	while not input.eof_reached():
		var line := input.get_line()
		if line.is_empty(): continue
		var game: Dictionary = JSON.parse_string(line)
		var key := "%d/%s" % [game["winds"], game["version"]]
		if not groups.has(key): groups[key] = {"games": 0, "rounds": 0, "feasible_rounds": 0, "feasible_hands": 0, "hands": 0}
		groups[key]["games"] += 1
		var turns: Dictionary = {}
		for observed in game.get("observed_hands", []):
			groups[key]["hands"] += 1
			# 快照保存battle_turn_count（已结束回合数），报告转为玩家回合编号。
			var turn := int(observed["turn"]) + 1
			if not turns.has(turn): turns[turn] = false
			if checker.check(observed):
				groups[key]["feasible_hands"] += 1
				turns[turn] = true
				if examples.size() < 12:
					examples.append({"group": key, "seed": game["seed"], "turn": turn, "hand": observed["hand"], "continuation": checker.witness.duplicate()})
		groups[key]["rounds"] += turns.size()
		for feasible in turns.values():
			if feasible: groups[key]["feasible_rounds"] += 1
	# 构造极宽的手牌资源集合：全牌组都在手中，仍不可行可证明资源上限。
	var sample: Dictionary = {}
	input.seek(0)
	var first: Dictionary = JSON.parse_string(input.get_line())
	if not first.get("observed_hands", []).is_empty(): sample = first["observed_hands"][0].duplicate(true)
	var structural: Dictionary = {}
	var checks: Dictionary = {}
	for winds in [1, 2]:
		for refund in [false, true]:
			var s := sample.duplicate(true)
			s["hand"] = [0,0,0,0,0,1,1,1,1,1,2,3,4,5,6]
			for _i in range(winds): s["hand"].append(16)
			# 限定不在本回合重洗并再次抽到刚打出的追风；单追风上限需要此条件。
			s["deck"] = [7]
			s["discard"] = []
			s["energy"] = 3
			s["combo"] = 0
			s["chain"] = 0
			s["cloud"] = true
			s["refund"] = refund
			s["triggered"] = false
			s["seen_flow"] = false
			s["seen_brilliance"] = false
			s["cut_water"] = false
			var feasible := checker.check(s)
			structural["%d/%s" % [winds, "refund" if refund else "draw_only"]] = {"feasible": feasible, "witness": checker.witness.duplicate()}
			if feasible != (winds == 2 or refund): failures += 1
	for case in [
		{"name": "refund_draws_attack", "refund": true, "deck": [0], "expected": true},
		{"name": "refund_draws_defense", "refund": true, "deck": [1], "expected": false},
		{"name": "draw_only_second_wind", "refund": false, "deck": [16], "expected": true},
		{"name": "draw_only_recycled_wind", "refund": false, "deck": [], "expected": true}
	]:
		var s := sample.duplicate(true)
		s["hand"] = [0,6,16]
		s["deck"] = case["deck"].duplicate()
		s["discard"] = []
		s["energy"] = 3
		s["combo"] = 0
		s["chain"] = 0
		s["cloud"] = true
		s["triggered"] = false
		s["refund"] = case["refund"]
		s["seen_flow"] = false
		s["seen_brilliance"] = false
		s["cut_water"] = false
		var feasible := checker.check(s)
		checks[case["name"]] = {"feasible": feasible, "witness": checker.witness.duplicate()}
		if feasible != case["expected"]: failures += 1
	var report := {"groups": groups, "examples": examples, "structural_without_wind_recycling": structural, "boundary_checks": checks, "failures": failures, "meaning": "resource upper bound; exhaustive card orders and possible draws, ignores enemy death and damage; not actual hidden draw-order oracle"}
	var output := FileAccess.open(input_path.trim_suffix(".jsonl") + "-feasibility.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(1 if failures else 0)
