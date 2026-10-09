extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	assert(OS.get_environment("APPDATA").contains("expedition-ui-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = false
	state.select_save_slot(1)
	state.clear_expedition()
	state.intro_done = true
	state.start_new_run()
	state.map_seed = 1757999
	state.map_layer = 4
	state.map_node = 2
	state.route_layer = 4
	state.player_hp = 43
	assert(state.checkpoint("map") == OK)
	change_scene_to_file("res://scenes/map.tscn")
	await process_frame
	await process_frame
	var button = current_scene.find_child("SaveExitButton", true, false)
	assert(button != null)
	button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/save_select.tscn")
	assert(current_scene.slot_buttons[0].text.contains("继续远征"))
	current_scene._open_slot(1)
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/map.tscn")
	assert(state.player_hp == 43 and state.map_layer == 4 and state.map_node == 2)
	var blocked_path := ProjectSettings.globalize_path("user://save_slot_1.cfg.tmp")
	assert(DirAccess.make_dir_absolute(blocked_path) == OK)
	button = current_scene.find_child("SaveExitButton", true, false)
	button.pressed.emit()
	assert(current_scene.scene_file_path == "res://scenes/map.tscn")
	assert(not button.disabled and button.text.contains("保存失败"))
	assert(DirAccess.remove_absolute(blocked_path) == OK)
	button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/save_select.tscn")
	state.select_save_slot(1)
	state.set_finale_state("story", "arrival")
	assert(not state.has_expedition())
	state.prepare_finale_battle()
	assert(state.has_expedition() and state.resume_destination() == "res://scenes/battle.tscn")
	state.select_save_slot(1)
	assert(state.finale_state == "battle" and state.player_hp == state.player_max_hp)
	state.set_finale_state("story", "victory")
	assert(not state.has_expedition())
	print("EXPEDITION SAVE UI: PASS (exit, resume, write failure retry, finale)")
	quit(0)
