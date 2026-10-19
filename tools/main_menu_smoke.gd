extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func mount(path: String) -> Node:
	if current_scene != null:
		current_scene.free()
	var scene = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene
func capture(path: String) -> void:
	if "--render-preview" not in OS.get_cmdline_user_args():
		return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	assert(OS.get_environment("APPDATA").contains("main-menu-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var menu = mount("res://scenes/main_menu.tscn")
	assert(menu.get_node("Stage/Continue").disabled)
	menu.get_node("Stage/Start").pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	assert(current_scene.name == "Intro")
	assert(state.current_save_slot == 1)
	state.intro_done = true
	state.suppress_persistence = false
	state.save_persistent_state()
	state.suppress_persistence = true
	menu = mount("res://scenes/main_menu.tscn")
	assert(not menu.get_node("Stage/Continue").disabled)
	await capture("res://.godot/main_menu_implemented.png")
	menu._open_settings()
	assert(menu.get_node("SettingsPanel").visible)
	menu._set_volume(0)
	assert(AudioServer.is_bus_mute(0))
	menu._set_volume(60)
	assert(not AudioServer.is_bus_mute(0))
	assert(is_equal_approx(root.get_node("WindowMode").master_volume, 0.6))
	await capture("res://.godot/main_menu_settings.png")
	menu._close_settings()
	assert(not menu.get_node("SettingsPanel").visible)
	menu.get_node("Stage/Continue").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "Home")
	assert(state.current_save_slot == 1 and state.intro_done)
	menu = mount("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	assert(current_scene.name == "MainMenu")
	# 已有存档时，开始游戏进入选位，旧档继续、空位新建。
	current_scene.get_node("Stage/Start").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "SaveSelect")
	assert(not current_scene.slot_buttons[0].disabled)
	assert(not current_scene.slot_buttons[1].disabled)
	current_scene._open_slot(2)
	await process_frame
	await process_frame
	await process_frame
	assert(current_scene.name == "Intro")
	assert(state.current_save_slot == 2)
	assert(not state.intro_done)
	assert(state.get_save_slot_summary(1)["exists"])
	state.suppress_persistence = false
	for slot in range(2, state.SAVE_SLOT_COUNT + 1):
		state.select_save_slot(slot)
		state.save_persistent_state()
		assert(state.last_save_error == OK)
	state.suppress_persistence = true
	menu = mount("res://scenes/main_menu.tscn")
	menu.get_node("Stage/Start").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "SaveSelect")
	assert(current_scene.slot_buttons.size() == 12)
	await capture("res://.godot/save_slots_12.png")
	current_scene.get_node("SaveUI/Scroll").scroll_vertical = 10000
	await capture("res://.godot/save_slots_12_bottom.png")
	for button in current_scene.slot_buttons:
		assert(not button.disabled)
	current_scene._request_delete(12)
	assert(state.get_save_slot_summary(12)["exists"])
	current_scene._request_delete(12)
	assert(not state.get_save_slot_summary(12)["exists"])
	current_scene.get_node("SaveUI/Back").pressed.emit()
	await process_frame
	await process_frame
	current_scene.get_node("Stage/Start").pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "SaveSelect")
	assert(not current_scene.slot_buttons[11].disabled)
	current_scene._open_slot(12)
	await process_frame
	await process_frame
	await process_frame
	assert(current_scene.name == "Intro")
	assert(state.current_save_slot == 12)
	assert(state.get_save_slot_summary(1)["exists"])
	print("MAIN MENU FLOW: PASS (fresh intro, pick empty slot when saves exist, 12 slots, continue, no overwrite, full capacity, confirmed deletion, reuse, settings)")
	quit()
