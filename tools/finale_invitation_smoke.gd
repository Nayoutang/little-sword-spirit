extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.bond_value = 99
	state.finale_state = "locked"
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	assert(not home.get_node("FinaleInvitation/Invite").visible)
	home.free()
	state.bond_value = 100
	home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	assert(state.finale_state == "invited")
	assert(home.get_node("FinaleInvitation/Invite").visible)
	home.get_node("FinaleInvitation")._accept()
	assert(state.finale_state == "accepted")
	assert(home.get_node("FinaleInvitation/Journey").visible)
	home.free()
	home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	assert(not home.get_node("FinaleInvitation/Invite").visible)
	assert(home.get_node("FinaleInvitation/Journey").visible)
	home.free()
	state.prepare_finale_battle()
	assert(state.pending_encounter == state.EncounterType.BOSS)
	assert(state.player_hp == state.player_max_hp)
	state.finale_state = "locked"
	print("FINALE INVITATION: PASS")
	quit()
