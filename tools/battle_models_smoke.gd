extends SceneTree

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	for encounter in [state.EncounterType.NORMAL, state.EncounterType.ELITE, state.EncounterType.BOSS]:
		state.pending_encounter = encounter
		state.route_layer = 17
		var pair: Array = []
		for legacy in [false, true]:
			var battle = load("res://scenes/battle.tscn").instantiate()
			if legacy:
				battle.set_script(load("res://tools/fixtures/legacy_enemy_intent_battle.gd"))
			battle.fixed_cooperation_test = true
			battle.force_offline_companion = true
			battle.fixed_random_seed = 55119
			root.add_child(battle)
			battle.fixed_cooperation_test = false
			pair.append(battle)
		for roles in [[], ["swordsman", "guardian"]]:
			for battle in pair:
				battle.enemy_roles.assign(roles)
				battle.enemy_hps.assign([100, 40])
				battle.enemy_max_hps.assign([200, 40])
				battle.enemy_strengths.assign([2, 1])
				battle.enemy_attack_reductions.assign([3, 2])
				battle.boss_action_step = 0
				battle.enemy_action_step = 0
			for step in range(12):
				for battle in pair:
					if step == 5:
						battle.enemy_hps[1] = 0
					battle._roll_enemy_intents()
				assert(pair[0].enemy_intents == pair[1].enemy_intents)
				assert(pair[0].enemy_attack_reductions == pair[1].enemy_attack_reductions)
				assert(pair[0].boss_action_step == pair[1].boss_action_step)
				assert(pair[0].random_call_counts == pair[1].random_call_counts)
		for battle in pair:
			battle.free()
	print("BATTLE MODELS: PASS (legacy intents, boss cycle, reductions, dead enemies, RNG consumption)")
	quit(0)
