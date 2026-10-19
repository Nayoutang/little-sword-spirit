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
	create_timer(30).timeout.connect(func(): quit(2))
	assert(OS.get_environment("APPDATA").contains("finale-save-user"))
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
	assert(current_scene.get_node("FinaleUI/Continue").text == "离开游戏")
	assert(current_scene.get_node("FinaleUI/Rewind").visible)
	# A click on the finished page must not choose an ending action implicitly.
	current_scene._advance()
	assert(not state.is_scene_transition_pending())
	current_scene.get_node("FinaleUI/Continue").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "SaveSelect")
	assert(state.finale_state == "ended")
	# Reopening the refusal ending still permits returning to the invitation.
	var ending = mount("res://scenes/finale.tscn")
	for i in range(30):
		if ending.finishing: break
		ending._advance()
	var deck_before: Array = state.deck.duplicate()
	var bond_before: int = state.bond_value
	state.player_hp = 0
	ending.get_node("FinaleUI/Rewind").pressed.emit()
	ending.get_node("FinaleUI/Rewind").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "Home")
	assert(state.finale_state == "invited")
	assert(state.player_hp == state.player_max_hp)
	assert(state.deck == deck_before and state.bond_value == bond_before)
	assert(current_scene.get_node("FinaleInvitation/Invite").visible)
	assert(not state.has_expedition())
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
			battle.few_return_used = true
			battle.enemy_intents.assign([{ "type": battle.EnemyIntent.ATTACK, "value": 999 }])
			battle._resolve_enemy_turn()
		await create_timer(1.0).timeout
		assert(state.finale_mode == ("victory" if won else "sacrifice"))
		for i in range(25):
			if current_scene.finishing: break
			current_scene._advance()
		assert(state.finale_state == "ended")
		assert(not current_scene.get_node("FinaleUI/Rewind").visible)
		assert(current_scene.get_node("FinaleUI/Continue").text == ("回家" if won else "回到过去"))
		current_scene.get_node("FinaleUI/Continue").pressed.emit()
		current_scene.get_node("FinaleUI/Continue").pressed.emit()
		await process_frame
		await process_frame
		if won:
			# 同归后回家先进入第二章章首。
			for i in range(4): await process_frame
			assert(current_scene.name == "ChapterStory")
			assert(state.chapter == 2 and state.chapter_trip == 1)
			current_scene._leave()
			for i in range(4): await process_frame
			assert(state.pending_story == "")
		assert(current_scene.name == "Home")
		assert(not state.has_expedition())
		if won:
			assert(state.finale_state == "completed" and state.finale_mode == "victory")
			assert(not current_scene.get_node("FinaleInvitation/Invite").visible)
			assert(current_scene.get_node("ChatUI/ChatPanel").visible)
			# Re-entering home must not restart the chapter invitation.
			home = mount("res://scenes/home.tscn")
			assert(not home.get_node("FinaleInvitation/Invite").visible)
		else:
			assert(state.finale_state == "invited" and state.finale_mode == "arrival")
			assert(state.player_hp == state.player_max_hp)
			assert(current_scene.get_node("FinaleInvitation/Invite").visible)
	# Real round-trip in isolated APPDATA; no user profile is touched.
	state.suppress_persistence = false
	state.set_finale_state("completed", "victory")
	state._load_relationship()
	assert(state.finale_state == "completed" and state.finale_mode == "victory")
	state.set_finale_state("invited")
	state._load_relationship()
	assert(state.finale_state == "invited")
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
	print("FINALE FLOW: PASS (refusal exit/rewind, win home, loss rewind, real battle routing, completed/invited persistence, reset)")
	quit()
