extends "res://tools/combo_planner.gd"

# 只检查当前回合的保守生存路线，不依赖未知抽牌、不用束搜索评分。
var witness: Array = []
var visited: Dictionary = {}

func draw(_s: Dictionary, _count: int, _rng: RandomNumberGenerator) -> void:
	pass

func startable(initial: Dictionary) -> bool:
	if 15 not in initial["hand"] or initial["energy"] < 1: return false
	var next := initial.duplicate(true)
	next["refund"] = false
	apply_card(next, {"kind": "card", "id": 15, "target": -1}, RandomNumberGenerator.new())
	return find_safe(next)

func accepts(initial: Dictionary, action: Dictionary) -> bool:
	var next := initial.duplicate(true)
	var rng := RandomNumberGenerator.new()
	if action["kind"] == "end":
		end_round(next, rng)
		return int(next["hp"]) > 0
	apply_card(next, action, rng)
	return find_safe(next)

func find_safe(initial: Dictionary) -> bool:
	witness.clear()
	visited.clear()
	return search(initial.duplicate(true), [])

func search(s: Dictionary, path: Array) -> bool:
	if int(s["hp"]) <= 0: return false
	if living(s) == 0:
		witness = path.duplicate()
		return true
	var key := JSON.stringify([s["hand"], s["energy"], s["combo"], s["chain"], s["block"], s["enemy_hp"], s["guard"], s["vulnerable"], s["tuned"], s["triggered"]])
	if visited.has(key): return false
	visited[key] = true
	for action in legal_actions(s):
		var next := s.duplicate(true)
		var rng := RandomNumberGenerator.new()
		var next_path := path.duplicate(true)
		next_path.append(action)
		if action["kind"] == "end":
			end_round(next, rng)
			if int(next["hp"]) > 0:
				witness = next_path
				return true
		else:
			apply_card(next, action, rng)
			if search(next, next_path): return true
	return false
