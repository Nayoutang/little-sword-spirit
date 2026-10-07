extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state._reset_deck()
	state.deck.assign([18,19,1,1,4,4,12,12,17,17,0,6,8,8,9])
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
	battle.set_script(load("res://tools/shield_playtest_battle.gd"))
	battle.offline_experiment = true
	var smoke := "--playtest-smoke" in OS.get_cmdline_user_args()
	battle.force_offline_companion = smoke or "--offline-companion" in OS.get_cmdline_user_args()
	battle.calibration_continuous = "--playtest-continuous" in OS.get_cmdline_user_args()
	battle.calibration_multi = "--playtest-multi" in OS.get_cmdline_user_args()
	battle.calibration_hit = 24 if battle.calibration_continuous else 30
	battle.fixed_random_seed = 400001
	root.add_child(battle)
	if smoke:
		await process_frame
		var ok: bool = battle.enemy_hps == [180] and state.deck.size() == 15 and 19 in state.deck and battle.hand.size() == 4 and not battle.companion_turn_pending
		var key := InputEventKey.new()
		key.keycode = KEY_4
		key.pressed = true
		battle._unhandled_key_input(key)
		await process_frame
		ok = ok and battle.calibration_continuous and battle.calibration_multi and battle.enemy_intents[0]["segments"] == [8,8,8]
		print("SHIELD_PLAYTEST_SMOKE failures=%d" % [0 if ok else 1])
		quit(0 if ok else 1)
