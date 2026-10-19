extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(OS.get_environment("APPDATA").contains("repackage-fresh-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	for slot in range(1, state.SAVE_SLOT_COUNT + 1):
		assert(not state.get_save_slot_summary(slot)["exists"])
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_menu.tscn")
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	assert(menu.get_node("Stage/Continue").disabled)
	print("PACKAGE FRESH START: PASS (all slots empty, main menu, continue disabled)")
	quit()
