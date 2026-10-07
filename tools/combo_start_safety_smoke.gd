extends SceneTree

const Safety = preload("res://tools/combo_start_safety.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func initial() -> Dictionary:
	return {"hp": 16, "max_hp": 90, "energy": 3, "combo": 2, "chain": 2, "block": 0,
		"cloud": false, "triggered": false, "refund": false, "preserve": false, "cut_water": false,
		"tuned": false, "hand": [15,4], "deck": [], "discard": [], "enemy_hp": [1000,1000],
		"guard": [0,0], "vulnerable": [0,0], "intents": [{"type":0,"value":18},{"type":0,"value":9}],
		"roles": ["swordsman","guardian"], "step": 0, "layer": 8, "stage": 2, "allowed": ["clean_cut"],
		"locked": "clean_cut", "boon": {}, "cooperation": {}, "promise": "", "reductions": [0,0],
		"damage": 0, "loss": 0, "round": 0, "first": {}, "extra_energy": 0}

func run() -> void:
	var safety = Safety.new()
	var s := initial()
	expect(safety.startable(s), "block continuation should make activation safe")
	expect(s["chain"] == 2 and s["energy"] == 3 and s["hand"] == [15,4], "safety must not mutate live state")
	s["hp"] = 8
	expect(not safety.startable(s), "insufficient defense should postpone activation")
	s = initial()
	s["hand"] = [15]
	expect(not safety.startable(s), "survival must not be assumed without shield")
	s["hp"] = 90
	expect(safety.startable(s), "healthy activation may immediately end safely")
	s = initial()
	s["hand"] = [4,0]
	s["energy"] = 2
	s["cloud"] = true
	expect(not safety.accepts(s, {"kind":"card","id":0,"target":0}), "unsafe replan must be rejected")
	expect(safety.accepts(s, {"kind":"card","id":4,"target":-1}), "safe defense must remain allowed")
	print("COMBO_START_SAFETY_SMOKE failures=%d" % failures)
	quit(1 if failures else 0)
