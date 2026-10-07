extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.learned_sword_intents.clear()
	var controller = load("res://scripts/home/feihualing_controller.gd").new()
	root.add_child(controller)
	controller.game = FeihualingGame.new("人")
	controller.action = "turn"
	controller.player_text = "满堂花醉三千客，一剑霜寒十四州"
	controller.intent_hint = controller.game.classify_input(controller.player_text)
	controller.local_result = controller.game.local_verdict(controller.player_text)
	assert(controller.intent_hint == "line")
	assert(controller.local_result == "不含令字")
	controller._prepare_intent_cue()
	assert(controller.pending_intent_id.is_empty())
	# 重放实际日志里的第二个回复；即使模型误判质疑，本地仍按出句处理。
	var reply := {"intent": "challenge", "player_line_valid": false, "player_line_source": "", "comment": "这一轮令字是人，这局归我。", "my_line": "", "my_line_source": "", "prompt_next": "", "give_up": false}
	var envelope := {"choices": [{"message": {"content": JSON.stringify(reply)}}]}
	controller._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer())
	assert(controller.game == null and not controller.busy)
	assert(state.learned_sword_intents.is_empty())
	# 第二次收局仍不明确时必须结束，不能卡在请重试。
	controller.game = FeihualingGame.new("人")
	controller.closure_retries = 1
	reply["comment"] = "你这句没有令字。"
	reply["prompt_next"] = "重来。"
	envelope = {"choices": [{"message": {"content": JSON.stringify(reply)}}]}
	controller._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(envelope).to_utf8_buffer())
	assert(controller.game == null and not controller.busy)
	assert(state.learned_sword_intents.is_empty())
	# 匹配令字时仍可准备剑意；聊天、认输、质疑分类保留。
	controller.game = FeihualingGame.new("霜")
	controller.intent_hint = controller.game.classify_input(controller.player_text)
	controller.local_result = controller.game.local_verdict(controller.player_text)
	controller._prepare_intent_cue()
	assert(not controller.pending_intent_id.is_empty())
	assert(controller.game.classify_input("出处？") == "challenge")
	assert(controller.game.classify_input("我认输") == "surrender")
	controller.cancel()
	controller.free()
	print("WRONG KEYWORD: PASS (recorded reply, closure retry exhausted, no invalid sword intent)")
	quit()

