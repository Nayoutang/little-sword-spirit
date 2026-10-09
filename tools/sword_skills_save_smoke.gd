extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(OS.get_environment("APPDATA").contains("sword-skills-user"), "存档测试必须使用隔离目录")
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.current_save_slot = 3
	var config := ConfigFile.new()
	config.set_value("relationship", "bond_value", 50)
	config.set_value("relationship", "bond_stage", 2)
	config.set_value("profile", "player_name", "测试持剑人")
	config.set_value("memory", "sword_intents", ["ten_steps", "few_return"])
	config.set_value("abilities", "unlocked", ["life_guard", "resonance", "perseverance"])
	assert(config.save("user://save_slot_3.cfg") == OK)
	state._load_relationship()
	assert(state.player_name == "测试持剑人" and state.bond_value == 50)
	assert(state.learned_sword_intents == ["ten_steps", "few_return"])
	assert(not root.has_node("AbilityManager"))
	state.suppress_persistence = false
	state._save_relationship()
	state.suppress_persistence = true
	config.clear()
	assert(config.load("user://save_slot_3.cfg") == OK)
	assert(not config.has_section("abilities"))
	print("SWORD SKILLS SAVE: PASS (legacy profile/bond/intents preserved, abilities removed)")
	quit()
