extends SceneTree

var failed := false
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	assert(not FileAccess.file_exists("res://secrets/llm_api_key.txt") or not "--exported-public" in OS.get_cmdline_user_args())
	assert(not " ".join(LLMConfig.request_headers()).contains("Authorization"))
	create_timer(75).timeout.connect(func(): printerr("PUBLIC PROXY: timeout"); quit(2))
	if not "--live-proxy" in OS.get_cmdline_user_args():
		print("PUBLIC PROXY: PASS (no client authorization header, exported secret absent)")
		quit()
		return
	var request := HTTPRequest.new()
	request.timeout = 30
	root.add_child(request)
	var body := {"messages":[{"role":"system","content":"你是小墨，一把古剑剑灵。简短回应，不超过20字。"},{"role":"user","content":"你好，小墨。"}],"model":LLMConfig.MODEL_NAME,"max_tokens":100}
	assert(request.request(LLMConfig.API_URL,LLMConfig.request_headers(),HTTPClient.METHOD_POST,JSON.stringify(body)) == OK)
	var response: Array = await request.request_completed
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		printerr("PUBLIC PROXY: chat request failed result=%s HTTP=%s" % [response[0], response[1]])
		quit(1)
		return
	var data: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	assert(data is Dictionary and not data.get("choices", []).is_empty())
	request.queue_free()
	# 真实控制器使用玩家自选令字开场；不提交任何玩家档案。
	var controller = load("res://scripts/home/feihualing_controller.gd").new()
	root.add_child(controller)
	controller.start("寒")
	while controller.busy:
		await process_frame
	if controller.game == null or controller.game.last_my_line.is_empty():
		printerr("PUBLIC PROXY: chosen-keyword opening failed")
		quit(1)
		return
	assert(controller.game.keyword == "寒")
	assert(controller.game.last_my_line.contains("寒"))
	controller.cancel()
	controller.free()
	print("PUBLIC PROXY: PASS (live chat + chosen-keyword poetry through proxy)")
	quit()


