extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state._reset_deck()
	state.player_hp = 90
	state.player_max_hp = 90
	state.route_layer = 8
	state.pending_encounter = state.EncounterType.NORMAL
	root.get_node("AbilityManager").reset()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.offline_experiment = true
	battle.fixed_random_seed = 99321
	root.add_child(battle)
	battle.enemy_hps.assign([1000,1000])
	battle.energy = 3
	battle.combo = 3
	battle.consecutive_attacks = 2
	battle.hand[0] = 18
	battle.hand_buttons[0].show()
	battle._play_hand_card(0)
	expect(battle.retain_shield_active and battle.energy == 2 and battle.combo == 3 and battle.consecutive_attacks == 0, "retain power costs energy, preserves combo layers but clears chain")
	expect(not battle.discard_pile.has(18), "retain power leaves cycling deck")
	battle.hand[0] = 18
	battle.hand_buttons[0].show()
	battle._play_hand_card(0)
	expect(battle.energy == 2 and battle.hand_buttons[0].visible, "duplicate power cannot stack or spend energy")
	battle._gain_block(10,"player")
	battle._gain_block(13,"companion")
	battle.companion_block_this_turn = 13
	battle.enemy_intents.assign([{"type":4,"value":0},{"type":4,"value":0}])
	battle._resolve_enemy_turn()
	expect(battle.block == 23, "player and companion shield both survive quiet enemy turn")
	var row: Dictionary = battle.combo_telemetry.rounds[0]
	expect(row["block_gained_player"] == 10 and row["block_gained_companion"] == 13 and row["block_carried"] == 23 and row["block_expired"] == 0, "sources retained without counting carry as new generation")
	battle.enemy_intents.assign([{"type":0,"value":8},{"type":4,"value":0}])
	battle._resolve_enemy_turn()
	expect(battle.block == 15 and battle.player_hp == 90, "incoming damage consumes retained shield")
	row = battle.combo_telemetry.rounds[1]
	expect(row["starting_block"] == 23 and row["block_consumed"] == 8 and row["block_carried"] == 15, "carry conservation starting shield minus consumption")
	battle._end_battle(true)
	expect(not battle.retain_shield_active and battle.block == 0, "power and shield do not persist beyond battle")
	battle.queue_free()
	await process_frame
	print("RETAIN_SHIELD_SMOKE failures=%d" % failures)
	quit(1 if failures else 0)
