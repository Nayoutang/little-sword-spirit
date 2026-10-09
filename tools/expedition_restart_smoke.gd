extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	assert(OS.get_environment("APPDATA").contains("expedition-restart-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = false
	state.select_save_slot(1)
	var expected := ConfigFile.new()
	if "--write-checkpoint" in OS.get_cmdline_user_args():
		state.clear_expedition()
		state.player_name = "跨进程测试"
		state.intro_done = true
		state.start_new_run()
		state.map_seed = 1757999
		state.map_layer = 11
		state.map_node = 3
		state.route_layer = 11
		state.player_hp = 43
		state.player_max_hp = 99
		state.deck.append(19)
		state.active_promise = "protect"
		state.pending_encounter = state.EncounterType.ELITE
		state.battle_seed = 424242
		assert(state.checkpoint("battle") == OK)
	else:
		assert(state.player_name == "跨进程测试" and state.player_hp == 43 and state.player_max_hp == 99)
		assert(state.map_seed == 1757999 and state.map_layer == 11 and state.map_node == 3)
		assert(state.deck.size() == 16 and state.active_promise == "protect")
		assert(state.resume_destination() == "res://scenes/battle.tscn")
		assert(expected.load("user://opening.cfg") == OK)
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	var opening: Array = [battle.enemy_hps.duplicate(), battle.enemy_roles.duplicate(), battle.enemy_intents.duplicate(true), battle.hand.duplicate(), battle.draw_pile.duplicate()]
	if "--write-checkpoint" in OS.get_cmdline_user_args():
		expected.set_value("battle","opening",opening)
		assert(expected.save("user://opening.cfg") == OK)
		print("EXPEDITION RESTART WRITE: PASS")
	else:
		assert(expected.get_value("battle","opening") == opening)
		print("EXPEDITION RESTART READ: PASS (new process, same battle and deck)")
	battle.free()
	quit()
