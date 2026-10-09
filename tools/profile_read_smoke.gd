extends SceneTree

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(OS.get_environment("APPDATA").contains("profile-read-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var config := ConfigFile.new()
	config.set_value("relationship", "bond_value", 1000)
	config.set_value("relationship", "bond_stage", -9)
	config.set_value("memory", "recent_adventures", [1, 1, -1, 4, 999, "2"])
	config.set_value("memory", "recent_lines", [12, "旧台词"])
	config.set_value("memory", "sword_intents", ["ten_steps", "missing"])
	config.set_value("memory", "cooperation", {"guards": -5, "finishers": 3})
	config.set_value("memory", "battles_won", -8)
	config.set_value("memory", "shared_history", ["bad", {"summary": ""}, {"summary": "保留经历"}])
	var results: Array = []
	for i in range(20):
		results.append({"category": "minigame_result", "summary": "结果%d" % i})
	config.set_value("memory", "minigame_results", results)
	assert(config.save("user://save_slot_1.cfg") == OK)
	state.select_save_slot(1)
	assert(state.bond_value == 100 and state.bond_stage == 3 and state.pending_bond_stage == -1)
	assert(state.recent_adventures == [1, 4])
	assert(state.recent_lines == ["12", "旧台词"])
	assert(state.learned_sword_intents == ["ten_steps"])
	assert(state.relationship_facts.cooperation.guards == 0 and state.relationship_facts.cooperation.finishers == 3)
	assert(state.relationship_facts.battles_won == 0)
	assert(state.shared_history.size() == 1)
	assert(state.relationship_facts.minigame_results.size() == 12)
	assert(state.relationship_facts.minigame_results[0].summary == "结果8")
	# Legacy missing stage advances naturally; stage never falls below the bond threshold.
	config.clear()
	config.set_value("relationship", "bond_value", 50)
	assert(config.save("user://save_slot_2.cfg") == OK)
	state.select_save_slot(2)
	assert(state.bond_stage == 2 and state.recent_adventures.is_empty() and state.shared_history.is_empty())
	state.player_name = "保留名字"
	state.intro_done = true
	state.learned_sword_intents.assign(["ten_steps"])
	state.start_new_run()
	state.map_seed = 77
	state.map_layer = 9
	state.map_path.append([9, 2])
	state.player_hp = 1
	state.deck.append(19)
	var previous_run_id: int = state.run_id
	state.last_run_journal.assign([{"category": "event", "summary": "保留旧远征"}])
	state.start_new_run()
	assert(state.run_id == previous_run_id + 1)
	assert(state.last_run_journal.size() == 1 and state.last_run_journal[0].summary == "保留旧远征")
	assert(state.map_seed == 0 and state.map_layer == 0 and state.map_path.is_empty())
	assert(state.player_hp == state.player_max_hp and state.deck.size() == 15)
	assert(state.player_name == "保留名字" and state.learned_sword_intents == ["ten_steps"])
	# Malformed scalar containers must not crash the slot menu or partially restore a profile.
	config.clear()
	config.set_value("relationship", "bond_value", {"wrong": "type"})
	config.set_value("relationship", "bond_stage", [99])
	config.set_value("memory", "battles_won", [100])
	config.set_value("memory", "cooperation", {"guards": {"wrong": 1}})
	config.set_value("memory", "companion_card_counts", {"ten_steps": [3], "few_return": -8})
	config.set_value("memory", "recent_lines", "wrong")
	config.set_value("finale", "state", "unknown")
	config.set_value("finale", "mode", "unknown")
	assert(config.save("user://save_slot_3.cfg") == OK)
	var summary: Dictionary = state.get_save_slot_summary(3)
	assert(summary.bond == 0 and summary.stage == "初遇")
	state.select_save_slot(3)
	assert(state.bond_value == 0 and state.bond_stage == 0)
	assert(state.recent_lines.is_empty() and not state.has_expedition())
	assert(state.finale_state == "locked" and state.finale_mode == "arrival")
	assert(state.relationship_facts.battles_won == 0 and state.relationship_facts.cooperation.guards == 0)
	assert(state.relationship_facts.companion_card_counts.ten_steps == 0 and state.relationship_facts.companion_card_counts.few_return == 0)
	assert(state.player_name.is_empty() and state.learned_sword_intents.is_empty())
	print("PROFILE READ: PASS (legacy stages, normalization, slot isolation, new-run reset)")
	quit(0)
