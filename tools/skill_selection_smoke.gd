extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.finale_state = "locked"
	state.bond_value = 100
	state.bond_stage = 3
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	current_scene = battle
	await process_frame
	battle.companion_turn_pending = false
	battle.combo = 5
	battle.energy = 3
	battle._refresh_ui()
	battle._use_special()
	await create_timer(0.4).timeout
	assert(battle.pending_skill_target == 1)
	assert(battle.special_button.scale.x > 1.07)
	assert(battle.special_button.text.contains(str(battle.special_damage)))
	assert(not battle.enemy_status_labels[0].text.contains("预计扣血"))
	battle._use_ultimate()
	await create_timer(0.4).timeout
	assert(battle.pending_skill_target == 2)
	assert(battle.ultimate_button.scale.x > 1.07 and battle.special_button.scale.x == 1.0)
	assert(battle.ultimate_button.text.contains(str(battle.ultimate_damage)))
	if not DisplayServer.get_name() == "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/concepts/skill_selection_implemented.png")
	print("SKILL SELECTION: PASS")
	quit()
