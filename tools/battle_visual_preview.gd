extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.pending_encounter = state.EncounterType.BOSS
	state.start_new_run()
	state.pending_encounter = state.EncounterType.BOSS
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	battle._roll_enemy_intents()
	battle._roll_enemy_intents()
	battle.enemy_guards[0] = 8
	battle.enemy_vulnerabilities[0] = 2
	battle.player_hp = 63
	battle.block = 12
	battle.combo = 4
	battle.energy = 2
	battle._prepare_companion_intent()
	battle._refresh_ui()
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/battle-status-preview.png")
	battle._damage_enemy_at(0, 10)
	battle._refresh_ui()
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.godot/battle-hit-preview.png")
	quit()
