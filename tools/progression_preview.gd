extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.start_new_run()
	var enemies = root.get_node("EnemyDatabase")
	var model := FileAccess.open("res://docs/progression-curve.csv", FileAccess.WRITE)
	model.store_csv_line(PackedStringArray(["layer", "normal_hp_min", "normal_hp_max", "elite_hp_min", "elite_hp_max", "swordsman_attack", "swordsman_heavy", "guardian_shield", "boss_hp", "boss_heavy"]))
	for layer in range(1, 20):
		var normal: Dictionary = enemies.get_normal_config(layer)
		var elite: Dictionary = enemies.get_elite_config(layer)
		var boss: Dictionary = enemies.get_boss_config(layer)
		model.store_csv_line(PackedStringArray([str(layer), str(normal["hp_min"]), str(normal["hp_max"]), str(elite["hp_min"]), str(elite["hp_max"]), str(enemies.get_role_intent(enemies.SWORDSMAN, 0, false, layer)["value"]), str(enemies.get_role_intent(enemies.SWORDSMAN, 1, false, layer)["value"]), str(enemies.get_role_intent(enemies.GUARDIAN, 0, false, layer)["value"]), str(boss["hp"]), str(boss["heavy"])]))
	model.close()
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	await capture("res://.godot/extended-map-start.png")
	map._set_map_scroll(760)
	await capture("res://.godot/extended-map-middle.png")
	map._set_map_scroll(99999)
	await capture("res://.godot/extended-map-end.png")
	map.queue_free()
	await process_frame
	state.route_layer = 18
	state.pending_encounter = state.EncounterType.NORMAL
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	battle.enemy_roles.assign([enemies.SWORDSMAN, enemies.GUARDIAN])
	battle.enemy_action_step = 1
	battle._roll_enemy_intents()
	battle._refresh_ui()
	await capture("res://.godot/late-encounter-preview.png")
	quit()
