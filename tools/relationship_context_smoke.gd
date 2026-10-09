extends SceneTree

const BASELINE := "res://tools/fixtures/relationship_context_before.json"

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.player_name = "持剑人"
	state.active_promise = "protect"
	state.promise_sincere = false
	state.recent_lines.assign(["旧台词", "别误会我", "归来吧"])
	state.relationship_facts.battles_won = 3
	state.relationship_facts.minigame_results = [{"category": "minigame_result", "summary": "飞花令胜出"}]
	state.current_run_journal.assign([{"summary": "击败敌人"}, {"summary": "取得卡牌"}])
	state.last_run_journal.assign([{"summary": "之前已归家"}])
	state.shared_history.assign([{"expedition": 0, "summary": "初遇"}, {"expedition": 1, "summary": "平安归来"}])
	var prompts: Array[String] = []
	for stage in range(4):
		state.bond_stage = stage
		prompts.append(state.get_relationship_prompt())
		prompts.append(state.get_relationship_archive())
	prompts.append(state.get_recent_lines_block())
	seed(779)
	prompts.append(state.get_variety_prompt())
	prompts.append(state.get_minigame_memory_prompt())
	prompts.append(state.get_shared_history_prompt(1))
	prompts.append(state.get_run_journal_prompt())
	state.run_journal_finished = true
	prompts.append(state.get_run_journal_prompt())
	state.current_run_journal.clear()
	prompts.append(state.get_run_journal_prompt())
	assert(state.is_repetitive("别误会我只是顺路"))
	assert(not state.is_repetitive("今天风景不错"))
	if "--write-baseline" in OS.get_cmdline_user_args():
		var file := FileAccess.open(BASELINE, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(prompts, "\t"))
	else:
		assert(JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) == prompts)
	print("RELATIONSHIP CONTEXT: PASS (all stages, archive, memories, repetition, unchanged prompts)")
	quit(0)
