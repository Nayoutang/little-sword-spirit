extends SceneTree

const Cards = preload("res://scripts/data/companion_card_database.gd")
const Rules = preload("res://scripts/battle/companion_opportunity_rules.gd")
var fixtures := {}
var failures := 0
var cases := 0

func _initialize() -> void:
	call_deferred("run")

func settle(legacy: bool, source: String, combo_value: int, energy_value: int, cards: Array, pending: bool, lost: bool) -> Dictionary:
	var state = root.get_node("RunState")
	state.relationship_facts = {}
	state.run_moments.clear()
	if not fixtures.has(legacy):
		var created = load("res://scenes/battle.tscn").instantiate()
		if legacy:
			var legacy_script = load("res://tools/fixtures/legacy_player_card_battle.gd")
			if legacy_script == null or not legacy_script.can_instantiate():
				created.free()
				push_error("legacy fixture could not compile")
				return {}
			created.set_script(legacy_script)
		created.fixed_cooperation_test = true
		created.force_offline_companion = true
		created.fixed_random_seed = 381
		created.selection_logging_enabled = false
		root.add_child(created)
		fixtures[legacy] = created
	var battle = fixtures[legacy]
	battle.combo = combo_value
	battle.energy = energy_value
	battle.max_energy = 3
	battle.companion_turn_pending = pending
	battle.battle_finished = false
	battle.hand.assign(cards)
	battle.enemy_hps.assign([100, 100])
	battle.enemy_guards.fill(0)
	battle.enemy_vulnerabilities.fill(0)
	battle.resolving_hand_card = -1
	battle.telemetry_action.clear()
	battle.cooperation_windows = {"resource": {"source": source, "used": false, "lost": lost, "combo": combo_value}}
	battle._assess_cooperation_window()
	var available: bool = battle.cooperation_windows["resource"]["available"]
	battle._damage_enemy_at(0, 1)
	battle._finish_action()
	return {"available": available, "window": battle.cooperation_windows.duplicate(true), "facts": state.relationship_facts.duplicate(true)}

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	for source in [Cards.LEAD_MOMENTUM, Cards.ESCORT, Cards.HEART_RESONANCE, Cards.CUT_WATER, Cards.LONG_WIND]:
		for combo_value in [0, 2, 7]:
			for energy_value in [0, 1, 4]:
				for hand in [[], [0, 1, 2], [3, 3, 3]]:
					for pending in [false, true]:
						for lost in [false, true]:
							var expected := settle(true, source, combo_value, energy_value, hand, pending, lost)
							var actual := settle(false, source, combo_value, energy_value, hand, pending, lost)
							if expected.is_empty() or actual.is_empty():
								quit(1)
								return
							cases += 1
							if expected != actual:
								failures += 1
								push_error("opportunity=%s combo=%d energy=%d hand=%s pending=%s lost=%s expected=%s actual=%s" % [source, combo_value, energy_value, hand, pending, lost, expected, actual])
	var new_definition := {"opportunity": {"kind": Cards.OPPORTUNITY_EXTRA_ENERGY, "energy_key": "extra"}, "extra": 2}
	if not Rules.used_by_energy(new_definition, 1) or Rules.used_by_energy(new_definition, 2):
		failures += 1
		push_error("new opportunity must read its authored threshold without a card ID")
	for fixture in fixtures.values():
		fixture.free()
	await process_frame
	print("OPPORTUNITIES: %s (%d legacy comparisons, availability/use/loss)" % ["PASS" if failures == 0 else "FAIL", cases])
	quit(0 if failures == 0 else 1)
