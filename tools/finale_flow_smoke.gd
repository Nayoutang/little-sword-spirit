extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func mount(path: String):
	if current_scene != null:
		current_scene.free()
	var scene = load(path).instantiate()
	if "preview_offline" in scene: scene.preview_offline = true
	if "force_offline_companion" in scene: scene.force_offline_companion = true
	root.add_child(scene)
	current_scene = scene
	return scene
func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.bond_value = 100
	state.bond_stage = 3
	state.finale_state = "locked"
	var home = mount("res://scenes/home.tscn")
	assert(home.get_node("FinaleInvitation/Invite").visible)
	home.get_node("FinaleInvitation")._refuse()
	await process_frame
	await process_frame
	assert(current_scene.pages.size() == 3)
	for i in range(30):
		if current_scene.finishing: break
		current_scene._advance()
	assert(state.finale_state == "ended" and state.finale_mode == "refusal")
	assert(current_scene.get_node("FinaleUI/Caption").text.contains("未归"))
	for won in [true, false]:
		state.finale_state = "locked"
		home = mount("res://scenes/home.tscn")
		home.get_node("FinaleInvitation")._accept()
		assert(state.finale_state == "accepted")
		home.get_node("FinaleInvitation")._depart()
		await process_frame
		await process_frame
		assert(current_scene.pages.size() == 2)
		for i in range(20):
			if state.finale_state == "battle": break
			current_scene._advance()
		await process_frame
		await process_frame
		var battle = current_scene
		assert(battle.name == "Battle")
		battle.force_offline_companion = true
		assert(battle.enemy_count == 1)
		assert(battle._enemy_art().resource_path.ends_with("former_master_v1.png"))
		assert(battle._enemy_name(0) == "故人 · 缚魂剑主")
		if won:
			battle.enemy_hps[0] = 0
			battle._finish_action()
		else:
			battle.player_hp = 1
			battle.block = 0
			battle.life_guard_used = true
			battle.enemy_intents.assign([{ "type": battle.EnemyIntent.ATTACK, "value": 999 }])
			battle._resolve_enemy_turn()
		await create_timer(1.0).timeout
		assert(state.finale_mode == ("victory" if won else "sacrifice"))
		for i in range(25):
			if current_scene.finishing: break
			current_scene._advance()
		assert(state.finale_state == "ended")
	# Real round-trip in isolated APPDATA; no user profile is touched.
	state.suppress_persistence = false
	state.set_finale_state("accepted")
	state.finale_state = "locked"
	state._load_relationship()
	assert(state.finale_state == "accepted")
	state.set_finale_state("ended", "sacrifice")
	state._load_relationship()
	assert(state.finale_state == "ended" and state.finale_mode == "sacrifice")
	state.suppress_persistence = true
	state._reset_relationship_facts()
	assert(state.finale_state == "locked")
	print("FINALE FLOW: PASS (refusal, real battle win/loss routing, persistence, reset)")
	quit()
