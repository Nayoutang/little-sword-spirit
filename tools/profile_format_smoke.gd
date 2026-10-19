extends SceneTree

const BASELINE := "res://tools/fixtures/profile_v2_before_refactor.cfg"

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(OS.get_environment("APPDATA").contains("profile-format-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.clear_expedition()
	state.player_name = "格式兼容测试"
	state.intro_done = true
	state.feihualing_state = "unlocked"
	state.bond_value = 50
	state.bond_stage = 2
	state.pending_bond_stage = -1
	state.expedition_count = 4
	state.consecutive_run_failures = 2
	state.pending_concern = {"promise": "protect", "fact": "旧约定"}
	state.recent_lines.assign(["记得归来", "别走太远"])
	state.recent_adventures.assign([2, 4])
	state.learned_sword_intents.assign(["ten_steps", "few_return"])
	state.shared_history.assign([{"expedition": 3, "summary": "一同归家"}])
	state.last_run_journal.assign([{"category": "battle", "summary": "击败首领"}])
	state.relationship_facts["cooperation"] = {"opportunities_used": 3, "opportunities_wasted": 1, "finisher_combo_total": 8, "finishers": 2, "guards": 4}
	state.relationship_facts["battles_won"] = 5
	state.relationship_facts["battles_lost"] = 2
	state.relationship_facts["promise_kept"] = 3
	state.relationship_facts["promise_broken"] = 1
	state.relationship_facts["companion_card_counts"] = {"ten_steps": 3}
	state.relationship_facts["minigame_results"] = [{"category": "minigame_result", "summary": "飞花令胜出"}]
	var profile: ConfigFile = state._profile_config()
	var baseline := ConfigFile.new()
	assert(baseline.load(BASELINE) == OK)
	# 第二章增加独立分区；旧分区顺序与所有旧字段仍必须保持原样。
	var legacy_sections := profile.get_sections()
	assert(legacy_sections.has("chapter"))
	legacy_sections.erase("chapter")
	# 暗线信/执：独立分区，旧档缺省为 0。
	assert(legacy_sections.has("hidden"))
	legacy_sections.erase("hidden")
	assert(legacy_sections == baseline.get_sections())
	assert(profile.get_value("chapter", "chapter") == state.chapter)
	assert(profile.get_value("chapter", "trip") == state.chapter_trip)
	for section in baseline.get_sections():
		var keys := profile.get_section_keys(section)
		# 新增字段：飞花令开放进度（旧档缺省时按进度推算）。
		keys.erase("feihualing")
		# 新增字段：大话骰看穿次数、剑境进度。
		keys.erase("dice_caught")
		for realm_key in ["realm_unlocked", "realm_cleared", "last_free_boss"]:
			keys.erase(realm_key)
		assert(keys == baseline.get_section_keys(section))
		for key in baseline.get_section_keys(section):
			assert(profile.get_value(section, key) == baseline.get_value(section, key), section + "/" + key)
	state.current_save_slot = 1
	state.suppress_persistence = false
	assert(state._save_relationship() == OK)
	state._load_relationship()
	profile = state._profile_config()
	for section in baseline.get_sections():
		for key in baseline.get_section_keys(section):
			assert(profile.get_value(section, key) == baseline.get_value(section, key), "round trip: " + section + "/" + key)
	assert(state.feihualing_state == "unlocked")
	print("PROFILE FORMAT: PASS (all prior fields equal, isolated disk round trip)")
	quit(0)
