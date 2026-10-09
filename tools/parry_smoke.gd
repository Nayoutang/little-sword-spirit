extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func scene():
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state._reset_deck()
	state.player_hp = 90
	state.player_max_hp = 90
	state.bond_value = 50
	state.bond_stage = 2
	state.learned_sword_intents.clear()
	state.route_layer = 8
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.offline_experiment = true
	battle.fixed_random_seed = 99401
	root.add_child(battle)
	battle.enemy_hps.assign([1000,0])
	battle.enemy_guards.assign([0,0])
	battle.enemy_vulnerabilities.assign([0,0])
	battle.energy = 3
	battle.combo = 3
	battle.consecutive_attacks = 2
	battle.hand[0] = 19
	battle.hand_buttons[0].show()
	battle._play_hand_card(0)
	battle.enemy_intents.assign([{"type":0,"value":6,"segments":[2,2,2]},{"type":4,"value":0}])
	return battle

func run() -> void:
	var battle = scene()
	expect(battle.parry_active and battle.energy == 2 and battle.block == 5 and battle.combo == 0 and battle.consecutive_attacks == 0, "parry is an ordinary defense card with clearing semantics")
	battle.parry_reaction_limit = 3
	battle.parry_combo_limit = 2
	battle._resolve_enemy_turn()
	var row: Dictionary = battle.combo_telemetry.rounds[0]
	expect(battle.enemy_hps[0] == 988 and row["parry_reactions"] == 3 and row["parry_awarded"] == 2 and battle.combo == 2 and battle.consecutive_attacks == 0, "R3 C2: third reaction deals damage without awarding combo, injection belongs to next turn")
	battle.hand[0] = 1
	battle.hand_buttons[0].show()
	battle._play_hand_card(0)
	expect(battle.combo == 0 and battle.combo_telemetry.current["parry_combo_defense"] == 2, "ordinary defense clears injected combo and telemetry tracks it")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.parry_reaction_limit = 2
	battle.parry_combo_limit = 3
	battle._resolve_enemy_turn()
	expect(battle.enemy_hps[0] == 992 and battle.combo == 2 and battle.combo_telemetry.rounds[0]["parry_reactions"] == 2, "R2 C3: third segment cannot cause a third reaction or reward")
	battle._use_special()
	battle._resolve_targeted_skill(0)
	expect(battle.combo_telemetry.current["parry_combo_skill"] == 2 and battle.parry_injected_remaining == 0, "flowing light consumes injected combo")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.enemy_intents[0] = {"type":0,"value":0,"segments":[0,0,0]}
	battle._resolve_enemy_turn()
	expect(battle.enemy_hps[0] == 992 and battle.combo == 2 and battle.player_hp == 90, "zero damage segments and full guard still trigger parry")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.enemy_intents[0]["intercepted"] = true
	battle._resolve_enemy_turn()
	expect(battle.enemy_hps[0] == 1000 and battle.combo == 0, "intercepted segments do not react")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.player_hp = 5
	battle.block = 0
	battle.enemy_intents[0] = {"type":0,"value":5,"segments":[5]}
	battle._resolve_enemy_turn()
	expect(battle.battle_finished and battle.player_hp == 0 and battle.enemy_hps[0] == 1000 and not battle.parry_active, "fatal segment cannot parry and battle clears state")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.few_return_active = true
	battle.player_hp = 5
	battle.block = 0
	battle.enemy_intents[0] = {"type":0,"value":6,"segments":[5,1]}
	battle._resolve_enemy_turn()
	expect(battle.enemy_hps[0] == 992 and battle.player_hp == 1 and battle.combo == 2, "few return allows surviving parries and next-turn combo injection")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.enemy_hps[0] = 5
	battle.enemy_vulnerabilities[0] = 1
	battle._resolve_enemy_turn()
	row = battle.combo_telemetry.rounds[0]
	var attacks := 0
	for action in row["enemy_actions"]:
		if action["type"] == "attack": attacks += 1
	expect(battle.enemy_hps[0] == 0 and attacks == 1 and battle.battle_parry_damage == 5 and battle.battle_finished, "parry includes vulnerability and kill cancels remaining segments")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.hand[0] = 19
	battle.hand_buttons[0].show()
	battle._play_hand_card(0)
	battle._resolve_enemy_turn()
	expect(battle.enemy_hps[0] == 992 and battle.combo == 2, "multiple parry cards share R and C caps without stacking reaction damage")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.combo = 3
	battle.preserve_combo_this_turn = true
	battle._resolve_enemy_turn()
	expect(battle.combo == 5 and battle.parry_injected_remaining == 2, "preserved old combo plus injection is not capped by C")
	battle.queue_free()
	await process_frame
	print("PARRY_SMOKE failures=%d" % failures)
	quit(1 if failures else 0)
