extends "res://tools/combo_planner.gd"

# 无策略束剪枝的资源可行性上限：忽略伤害/击杀限制，抽牌遍历公开组成。
# 可行不保证真实牌序或敌人存活允许兑现；不可行则在该资源模型内不可能。
var requested_draws := 0
var visited: Dictionary = {}
var witness: Array = []

func draw(_s: Dictionary, count: int, _rng: RandomNumberGenerator) -> void:
	requested_draws += count

func check(initial: Dictionary) -> bool:
	visited.clear()
	witness.clear()
	var start := initial.duplicate(true)
	for field in ["hand", "deck", "discard"]:
		var integers: Array = []
		for id in start[field]: integers.append(int(id))
		start[field] = integers
	start["enemy_hp"] = [1000000]
	start["guard"] = [0]
	start["vulnerable"] = [0]
	start["seen_flow"] = bool(start.get("seen_flow", false))
	start["seen_brilliance"] = bool(start.get("seen_brilliance", false))
	return search(start, [])

func search(s: Dictionary, path: Array) -> bool:
	if s["seen_flow"] and s["seen_brilliance"]:
		witness = path.duplicate()
		return true
	var held: Array = s["hand"].duplicate()
	held.sort()
	var deck: Array = s["deck"].duplicate()
	deck.sort()
	var discard: Array = s["discard"].duplicate()
	discard.sort()
	var key := JSON.stringify([held, deck, discard, s["energy"], s["combo"], s["chain"], s["cloud"], s["triggered"], s["tuned"], s["seen_flow"], s["seen_brilliance"], s["cut_water"]])
	if visited.has(key): return false
	visited[key] = true
	var rng := RandomNumberGenerator.new()
	for action in legal_actions(s):
		if action["kind"] == "end": continue
		var next: Dictionary = s.duplicate(true)
		requested_draws = 0
		apply_card(next, action, rng)
		var draws := requested_draws
		if action["id"] == 13: next["seen_flow"] = true
		if action["id"] == 14: next["seen_brilliance"] = true
		var next_path := path.duplicate()
		next_path.append(action["id"])
		if expand_draws(next, draws, next_path): return true
	return false

func expand_draws(s: Dictionary, count: int, path: Array) -> bool:
	if count <= 0: return search(s, path)
	if s["deck"].is_empty():
		s["deck"] = s["discard"].duplicate()
		s["discard"].clear()
	if s["deck"].is_empty(): return search(s, path)
	var seen: Array = []
	for id in s["deck"]:
		if id in seen: continue
		seen.append(id)
		var next: Dictionary = s.duplicate(true)
		next["deck"].erase(id)
		next["hand"].append(id)
		if expand_draws(next, count - 1, path): return true
	return false
