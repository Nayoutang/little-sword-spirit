extends SceneTree

const Segments = preload("res://scripts/battle/enemy_attack_segments.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func battle_scene():
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state._reset_deck()
	state.player_hp = 50
	state.player_max_hp = 90
	state.route_layer = 8
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	battle.offline_experiment = true
	battle.fixed_random_seed = 9127
	root.add_child(battle)
	battle.battle_turn_count = 1
	battle.player_hp = 50
	battle.enemy_hps.assign([100,100])
	battle.enemy_max_hps.assign([100,100])
	battle.enemy_vulnerabilities.assign([0,0])
	battle.block = 0
	battle.enemy_intents.assign([{"type":0,"value":20,"segments":[9,7,4]}, {"type":0,"value":5}])
	return battle

func run() -> void:
	var battle = battle_scene()
	battle.enemy_guards.assign([100,0])
	battle.hand[0] = 0
	battle.hand_buttons[0].show()
	battle.energy = 3
	battle.combo = 0
	battle._play_hand_card(0)
	battle._resolve_targeted_attack(0)
	expect(battle.enemy_hps[0] == 100 and battle.combo == 1 and battle.consecutive_attacks == 1, "fully absorbed player attack still grants combo and continuous count")
	battle.queue_free()
	await process_frame
	battle = battle_scene()
	battle.enemy_guards.assign([0,0])
	battle.enemy_vulnerabilities.assign([2,0])
	battle.combo = 0
	battle.energy = 3
	battle._record_player_card(0)
	battle.resolving_hand_card = 0
	battle._play_attack_card(1,0,0)
	expect(battle.enemy_hps[0] == 98 and battle.combo == 1 and battle.consecutive_attacks == 1, "zero-base executed attack receives vulnerability and combo; shield card integration remains pending")
	battle.queue_free()
	await process_frame
	battle = battle_scene()
	var events: Array = []
	battle.enemy_attack_segment_resolved.connect(func(index, damage, absorbed, lost): events.append([index,damage,absorbed,lost]))
	battle._gain_block(8, "player")
	battle._gain_block(4, "companion")
	battle.companion_block_this_turn = 4
	battle._resolve_enemy_turn()
	expect(battle.player_hp == 37 and events.size() == 4, "each segment consumes shield then health")
	var row: Dictionary = battle.combo_telemetry.rounds[0]
	expect(row["block_gained_player"] == 8 and row["block_gained_companion"] == 4 and row["block_consumed"] == 12, "shield sources and consumption recorded")
	battle.queue_free()
	await process_frame

	battle = battle_scene()
	events = []
	battle.enemy_attack_segment_resolved.connect(func(index, damage, absorbed, lost): events.append([index,damage,absorbed,lost]))
	battle.enemy_intents.assign([{"type":0,"value":8,"segments":[3,5,0]}, {"type":0,"value":6}])
	battle._apply_companion_card({"card_id":"frost_cold", "source":"fallback"})
	expect(Segments.values(battle.enemy_intents[0]) == [1,3,0] and Segments.total(battle.enemy_intents[1]) == 4, "frost reduces every segment")
	battle._gain_block(8, "player")
	battle._resolve_enemy_turn()
	expect(events.size() == 4 and battle.player_hp == 50, "zero-damage and fully blocked segments emit reaction events")
	battle.queue_free()
	await process_frame

	battle = battle_scene()
	battle._play_unload_force_card(0)
	expect(Segments.values(battle.enemy_intents[0]) == [4,7,4], "unload reduces only next segment")
	battle.enemy_intents.assign([{"type":0,"value":6,"segments":[2,2,2]}, {"type":0,"value":5}])
	battle._apply_companion_card({"card_id":"yin_mountain", "source":"fallback"})
	expect(battle.enemy_intents[0].get("intercepted", false) and not battle.enemy_intents[1].get("intercepted", false), "yin selects enemy by modified total")
	events = []
	battle.enemy_attack_segment_resolved.connect(func(index, damage, absorbed, lost): events.append(index))
	battle._resolve_enemy_turn()
	expect(events == [1] and battle.player_hp == 45, "intercepted segments do not execute or emit reactions")
	battle.queue_free()
	await process_frame

	battle = battle_scene()
	battle.enemy_hps.assign([5,100])
	battle.enemy_vulnerabilities.assign([2,0])
	battle.enemy_intents.assign([{"type":0,"value":9,"segments":[3,3,3]}, {"type":0,"value":7}])
	events = []
	battle.enemy_attack_segment_resolved.connect(func(index, _damage, _absorbed, _lost):
		events.append(index)
		if index == 0: battle._damage_enemy_at(index, 3))
	battle._resolve_enemy_turn()
	expect(events == [0,1] and battle.enemy_hps[0] == 0 and battle.player_hp == 40, "reaction includes vulnerability, cancels actor remainder, right enemy still acts")
	battle.queue_free()
	await process_frame

	battle = battle_scene()
	battle.player_hp = 5
	battle.enemy_intents.assign([{"type":0,"value":10,"segments":[5,5]}, {"type":0,"value":7}])
	events = []
	battle.enemy_attack_segment_resolved.connect(func(index, _damage, _absorbed, _lost): events.append(index))
	var calls_before: Dictionary = battle.random_call_counts.duplicate()
	battle._resolve_enemy_turn()
	expect(events.is_empty() and battle.player_hp == 0 and battle.battle_finished, "fatal segment emits no reaction and ends enemy actions")
	expect(calls_before == battle.random_call_counts, "fatal outcome does not draw or roll next turn")
	battle.queue_free()
	await process_frame

	battle = battle_scene()
	battle.few_return_active = true
	battle.player_hp = 5
	battle.enemy_intents.assign([{"type":0,"value":6,"segments":[5,1]}, {"type":4,"value":0}])
	events = []
	battle.enemy_attack_segment_resolved.connect(func(index, _damage, _absorbed, _lost): events.append(index))
	battle._resolve_enemy_turn()
	expect(events == [0,0] and battle.few_return_used and battle.player_hp == 1, "few return survives lethal hit and remaining attack segments")
	battle.queue_free()
	await process_frame
	print("ENEMY_SEGMENTS_SMOKE failures=%d" % failures)
	quit(1 if failures else 0)
