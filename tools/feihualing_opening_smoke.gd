extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var previous_results: Array = state.relationship_facts.get("minigame_results", []).duplicate()
	var scene = load("res://scenes/expedition_poetry.tscn").instantiate()
	root.add_child(scene)
	var controller = scene.controller
	scene.started = true
	controller.game = FeihualingGame.new("寒")
	controller.action = "opening"
	controller.line_retries = 1
	var reply := {"intent": "line", "player_line_valid": true, "player_line_source": "", "comment": "令字是寒，我先来。", "my_line": "千山鸟飞绝，万径人踪灭", "my_line_source": "柳宗元《江雪》", "prompt_next": "轮到你。", "give_up": false}
	var envelope := {"choices": [{"message": {"content": JSON.stringify(reply)}}]}
	controller._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer())
	assert(controller.game == null and not controller.busy)
	assert(not scene.started and scene.input.text == "寒")
	assert(scene.send.text == "重试开场")
	assert(scene.log_text.get_parsed_text().contains("不计胜负"))
	assert(state.relationship_facts.get("minigame_results", []) == previous_results)
	assert(state.current_run_journal.is_empty())
	# 模型开场空句/认输也必须走开场失败，不能直接判玩家赢。
	for give_up in [false, true]:
		var game := FeihualingGame.new("寒")
		reply["my_line"] = ""
		reply["give_up"] = give_up
		assert(game.process_reply("opening", "", "", reply).get("retry_line", false))
	# 有效自选令字开场只推进到玩家应答，不结束对局。
	controller.game = FeihualingGame.new("寒")
	controller.action = "opening"
	reply["my_line"] = "孤舟蓑笠翁，独钓寒江雪"
	reply["give_up"] = false
	envelope = {"choices": [{"message": {"content": JSON.stringify(reply)}}]}
	controller._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer())
	assert(controller.game != null and controller.game.player_rounds == 0)
	assert(controller.game.last_my_line.contains("寒"))
	assert(state.relationship_facts.get("minigame_results", []) == previous_results)
	scene.free()
	print("OPENING: PASS (chosen keyword, recorded invalid opening, empty/give-up response, valid opening, no false result)")
	quit()
