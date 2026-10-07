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
	state.route_layer = 8
	state.bond_value = 50
	state.bond_stage = 2
	state.learned_sword_intents.clear()
	state.pending_encounter = state.EncounterType.NORMAL
	root.get_node("AbilityManager").reset()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.offline_experiment = true
	battle.fixed_random_seed = 99001
	root.add_child(battle)
	battle.enemy_hps.assign([1000,1000])
	battle.enemy_guards.assign([0,0])
	battle.enemy_vulnerabilities.assign([3,0])
	battle.energy = 3
	battle.combo = 5
	battle.block = 12
	battle.consecutive_attacks = 0
	battle.hand[0] = 17
	battle.hand_buttons[0].show()
	return battle

func strike(battle) -> void:
	battle._play_hand_card(0)
	battle._resolve_targeted_attack(0)

func run() -> void:
	var battle = scene()
	battle.pending_boon = {"type":"multiply","value":2.0,"source":"引势"}
	strike(battle)
	expect(battle.enemy_hps[0] == 973 and battle.block == 12 and battle.energy == 2, "shield conversion then multiply then additive vulnerability; shield not consumed")
	expect(battle.combo == 6 and battle.consecutive_attacks == 1 and battle.pending_boon.is_empty(), "shield attack ignores existing combo damage and consumes first-attack boon")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.block = 0
	battle.combo = 0
	battle.pending_boon = {"type":"multiply","value":2.0,"source":"引势"}
	strike(battle)
	expect(battle.enemy_hps[0] == 997 and battle.combo == 1 and battle.consecutive_attacks == 1 and battle.energy == 2 and battle.pending_boon.is_empty(), "zero shield still hits, costs energy, consumes multiply, vulnerability added after multiply")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.block = 0
	battle.combo = 0
	battle.enemy_vulnerabilities.assign([0,0])
	battle.enemy_guards.assign([10,0])
	strike(battle)
	expect(battle.enemy_hps[0] == 1000 and battle.combo == 1 and battle.consecutive_attacks == 1, "true zero damage and fully guarded shield strike still grants both counters")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.pending_boon = {"type":"add","value":4,"source":"拱卫"}
	strike(battle)
	expect(battle.enemy_hps[0] == 981 and battle.pending_boon.is_empty(), "escort addition applies after shield conversion")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.pending_boon = {"type":"multiply","value":2.0,"source":"引势"}
	battle.combo = 2
	battle._use_special()
	battle._resolve_targeted_skill(0)
	expect(not battle.pending_boon.is_empty() and battle.consecutive_attacks == 0, "skill button does not consume first-attack boon")
	var hp: int = battle.enemy_hps[0]
	strike(battle)
	expect(hp - battle.enemy_hps[0] == 27 and battle.pending_boon.is_empty(), "shield strike following skill consumes preserved boon")
	battle.queue_free()
	await process_frame
	battle = scene()
	battle.combo = 0
	battle.block = 8
	battle.enemy_vulnerabilities.assign([0,0])
	battle.flowing_cloud_active = true
	battle.pending_boon.clear()
	for slot in range(3):
		battle.hand[slot] = 17
		battle.hand_buttons[slot].show()
		battle._play_hand_card(slot)
		battle._resolve_targeted_attack(0)
	expect(battle.enemy_hps[0] == 976 and battle.block == 8 and battle.combo == 3 and battle.consecutive_attacks == 3 and battle.flowing_cloud_triggered and battle.energy == 1, "three shield strikes reuse shield, unlock ultimate and trigger cloud")
	battle._use_ultimate()
	battle._resolve_targeted_skill(0)
	expect(battle.enemy_hps[0] == 935 and battle.combo == 0 and battle.consecutive_attacks == 3, "ultimate uses normal combo damage after three shield strikes")
	battle.queue_free()
	await process_frame
	print("SHIELD_STRIKE_SMOKE failures=%d" % failures)
	quit(1 if failures else 0)
