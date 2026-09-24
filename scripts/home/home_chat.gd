extends Node2D

@onready var chat_log: RichTextLabel = $ChatUI/ChatPanel/ChatLog
@onready var input: LineEdit = $ChatUI/ChatPanel/Input
@onready var send_button: Button = $ChatUI/ChatPanel/SendButton
@onready var depart_button: Button = $ChatUI/ChatPanel/DepartButton
@onready var feihualing_button: Button = $ChatUI/ChatPanel/FeihualingButton
@onready var feihualing_status: Label = $ChatUI/ChatPanel/FeihualingStatus
@onready var feihualing_again_button: Button = $ChatUI/ChatPanel/FeihualingAgainButton
@onready var feihualing_leave_button: Button = $ChatUI/ChatPanel/FeihualingLeaveButton
@onready var bond_label: Label = $ChatUI/ChatPanel/BondLabel
@onready var http_request: HTTPRequest = $HTTPRequest

var messages: Array[Dictionary] = []
var request_in_flight := false
var game_controller: FeihualingController
var game_choice_pending := false
var greeting_in_flight := false


func _ready() -> void:
	# 新存档第一次进家前，先播初遇剧情。
	if RunState.needs_intro():
		get_tree().change_scene_to_file("res://scenes/intro.tscn")
		return
	# 防止玩家在结算后退出游戏，从而绕过已经触发的关系突破。
	if RunState.has_pending_bond_milestone():
		get_tree().change_scene_to_file("res://scenes/relationship_milestone.tscn")
		return
	if SpecialEventManager.activate_next():
		RunState.save_persistent_state()
	var system_prompt := _load_system_prompt()
	system_prompt += "\n\n" + RunState.get_relationship_prompt()
	system_prompt += "\n\n" + AbilityManager.get_prompt_context()
	system_prompt += "\n\n" + RunState.get_run_journal_prompt()
	system_prompt += "\n\n" + RunState.get_shared_history_prompt()
	system_prompt += "\n\n" + RunState.get_minigame_memory_prompt()
	if SpecialEventManager.has_active_event():
		system_prompt += "\n\n" + SpecialEventManager.get_prompt_context()
	messages.append({"role": "system", "content": system_prompt})
	send_button.pressed.connect(_send_message)
	depart_button.pressed.connect(_go_to_map)
	feihualing_button.pressed.connect(_start_feihualing)
	feihualing_again_button.pressed.connect(_on_game_again)
	feihualing_leave_button.pressed.connect(_on_game_leave)
	$ChatUI/ChatPanel/SaveSlotsButton.pressed.connect(_return_to_save_slots)
	input.text_submitted.connect(_on_text_submitted)
	http_request.request_completed.connect(_on_request_completed)
	game_controller = FeihualingController.new()
	add_child(game_controller)
	game_controller.spoken.connect(_on_game_spoken)
	game_controller.hud_changed.connect(_on_game_hud_changed)
	game_controller.busy_changed.connect(_on_game_busy_changed)
	game_controller.finished.connect(_on_game_finished)
	_refresh_bond_display()
	if SpecialEventManager.has_active_event():
		chat_log.append_text("[特殊对话] 小墨似乎有一件刚才发生的事想和你谈谈。\n\n")
	if not AbilityManager.unlocked.is_empty():
		chat_log.append_text("[已掌握神通] %s\n\n" % AbilityManager.get_unlocked_names())
	input.grab_focus()
	if RunState.consume_homecoming():
		_request_homecoming_greeting()


# 远征归来后，小墨先就着这一趟里某件具体的事开口；失败时静默跳过，不用代码替她说话。
func _request_homecoming_greeting() -> void:
	var api_key := LLMConfig.get_api_key()
	if LLMConfig.API_URL.is_empty() or api_key.is_empty() or LLMConfig.MODEL_NAME.is_empty():
		return
	var cue := "【旁白，不是持剑人说的话】持剑人刚结束第%d趟远征回到家，还没开口。请你先开口，只说一两句：从本趟记录里挑一件最具体的事（某一场、某个血量、某张牌、某个约定）来说，用你此刻对他的关系态度说出来，可以嘴硬、可以关心，但要让他听得出你注意到了那件事。不要复述整趟流水账，不要问他今天怎么样。" % RunState.expedition_count
	if SpecialEventManager.has_active_event():
		cue += "如果当前特殊事件正好是你最想说的那件事，就从它开口。这一轮是你先开口，event_result.resolved 必须为 false。"
	messages.append({"role": "user", "content": cue})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	greeting_in_flight = true
	_set_request_in_flight(true)
	var error := http_request.request(
		LLMConfig.API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify({"model": LLMConfig.MODEL_NAME, "messages": messages})
	)
	if error != OK:
		greeting_in_flight = false
		messages.pop_back()
		_set_request_in_flight(false)


func _handle_greeting_response(result: int, response_code: int, body: PackedByteArray) -> void:
	var reply := ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var api_choices: Variant = parsed.get("choices", [])
			if api_choices is Array and not api_choices.is_empty() and api_choices[0] is Dictionary:
				var message: Variant = api_choices[0].get("message", {})
				if message is Dictionary:
					reply = str(message.get("content", "")).strip_edges()
	if not reply.is_empty() and SpecialEventManager.has_active_event():
		# 特殊事件模式下返回 JSON；开口这一句只取台词，不判定事件是否完成。
		var structured := _parse_special_event_reply(reply)
		reply = str(structured.get("reply", "")).strip_edges()
	reply = _strip_stage_directions(reply)
	if reply.is_empty():
		_remove_unanswered_user_message()
		return
	messages.append({"role": "assistant", "content": reply})
	chat_log.append_text("小墨：%s\n\n" % reply)


func _refresh_bond_display() -> void:
	bond_label.text = "羁绊：%d/%d　%s" % [
		RunState.bond_value,
		RunState.BOND_MAX,
		RunState.get_bond_stage_name(),
	]


func _go_to_map() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/promise.tscn")


func _return_to_save_slots() -> void:
	get_tree().change_scene_to_file("res://scenes/save_select.tscn")


func _load_system_prompt() -> String:
	return LLMConfig.load_system_prompt()


func _on_text_submitted(_submitted_text: String) -> void:
	_send_message()


func _is_feihualing_invitation(player_text: String) -> bool:
	return player_text.contains("飞花令") or player_text.contains("對詩") or player_text.contains("对诗")


func _start_feihualing() -> void:
	if request_in_flight or game_controller.busy or game_controller.game != null:
		return
	if LLMConfig.API_URL.is_empty() or LLMConfig.get_api_key().is_empty() or LLMConfig.MODEL_NAME.is_empty():
		_show_error("未配置 LLM API Key。请设置环境变量 %s。" % LLMConfig.API_KEY_ENV)
		return
	_hide_game_choices()
	game_controller.start()


func _on_game_again() -> void:
	_start_feihualing()


func _on_game_leave() -> void:
	_hide_game_choices()
	input.grab_focus()


func _hide_game_choices() -> void:
	game_choice_pending = false
	feihualing_again_button.hide()
	feihualing_leave_button.hide()


func _on_game_spoken(text: String) -> void:
	chat_log.append_text("小墨：%s\n\n" % text)


func _on_game_hud_changed(label: String, visible: bool) -> void:
	feihualing_status.text = label
	feihualing_status.visible = visible


func _on_game_busy_changed(_busy: bool) -> void:
	_set_request_in_flight(request_in_flight)


func _on_game_finished(summary: String) -> void:
	messages.append({"role": "system", "content": "刚结束的小游戏结果（可信事实）：%s" % summary})
	game_choice_pending = true
	feihualing_again_button.show()
	feihualing_leave_button.show()
	_set_request_in_flight(request_in_flight)


func _send_message() -> void:
	if request_in_flight or game_controller.busy:
		return

	var player_text := input.text.strip_edges()
	if player_text.is_empty():
		return
	var leaving_finished_game := game_choice_pending
	if leaving_finished_game:
		_hide_game_choices()
	if game_controller.game != null:
		input.clear()
		chat_log.append_text("玩家：%s\n\n" % player_text)
		game_controller.submit(player_text)
		return
	if not leaving_finished_game and _is_feihualing_invitation(player_text):
		input.clear()
		chat_log.append_text("玩家：%s\n\n" % player_text)
		_start_feihualing()
		return

	var api_key := LLMConfig.get_api_key()
	if LLMConfig.API_URL.is_empty() or api_key.is_empty() or LLMConfig.MODEL_NAME.is_empty():
		_show_error("未配置 LLM API Key。请设置环境变量 %s。" % LLMConfig.API_KEY_ENV)
		return

	input.clear()
	chat_log.append_text("玩家：%s\n\n" % player_text)
	messages.append({"role": "user", "content": player_text})

	var payload := {
		"model": LLMConfig.MODEL_NAME,
		"messages": messages,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])

	_set_request_in_flight(true)
	var error := http_request.request(
		LLMConfig.API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		messages.pop_back()
		_set_request_in_flight(false)
		_show_error("请求无法发出（错误码 %s）。" % error)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_set_request_in_flight(false)
	if greeting_in_flight:
		greeting_in_flight = false
		_handle_greeting_response(result, response_code, body)
		input.grab_focus()
		return
	var body_text := body.get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS:
		_remove_unanswered_user_message()
		_show_error("网络请求失败（结果码 %s）。" % result)
		return

	var parsed: Variant = JSON.parse_string(body_text)
	if response_code < 200 or response_code >= 300:
		_remove_unanswered_user_message()
		_show_error("API 返回 HTTP %s：%s" % [response_code, _extract_api_error(parsed, body_text)])
		return

	if not parsed is Dictionary:
		_remove_unanswered_user_message()
		_show_error("API 返回的内容不是有效的 JSON 对象。")
		return

	var choices: Variant = parsed.get("choices", [])
	if not choices is Array or choices.is_empty():
		_remove_unanswered_user_message()
		_show_error("API 响应中没有 choices。")
		return

	var first_choice: Variant = choices[0]
	if not first_choice is Dictionary:
		_remove_unanswered_user_message()
		_show_error("API 响应中的 choices 格式不正确。")
		return

	var message: Variant = first_choice.get("message", {})
	if not message is Dictionary:
		_remove_unanswered_user_message()
		_show_error("API 响应中没有 message。")
		return

	var raw_reply: String = str(message.get("content", "")).strip_edges()
	var reply := raw_reply
	var event_outcome: Dictionary = {}
	if SpecialEventManager.has_active_event():
		var structured := _parse_special_event_reply(raw_reply)
		if structured.is_empty():
			_remove_unanswered_user_message()
			_show_error("特殊对话返回格式错误，本次心事仍会保留，请重试。")
			return
		reply = str(structured.get("reply", "")).strip_edges()
		event_outcome = SpecialEventManager.validate_and_resolve(structured.get("event_result", {}))
	reply = _strip_stage_directions(reply)
	if reply.is_empty():
		_remove_unanswered_user_message()
		_show_error("API 返回了空回复。")
		return

	messages.append({"role": "assistant", "content": reply})
	chat_log.append_text("小墨：%s\n\n" % reply)
	if event_outcome.get("resolved", false):
		if event_outcome.get("unlocked", false):
			var ability_id := str(event_outcome.get("ability_id", ""))
			chat_log.append_text("[心有所悟] 获得神通「%s」：%s\n\n" % [
				AbilityManager.get_name_for(ability_id),
				AbilityManager.get_description(ability_id),
			])
		else:
			chat_log.append_text("[心事已解] 这段共同经历已经被记住。\n\n")
		messages.append({
			"role": "system",
			"content": "特殊事件已经完成。此后的回复恢复普通自由聊天，只输出小墨的自然语言台词，不再输出 JSON。",
		})
	input.grab_focus()


func _parse_special_event_reply(content: String) -> Dictionary:
	var cleaned := content.strip_edges()
	if cleaned.begins_with("```json"):
		cleaned = cleaned.trim_prefix("```json").trim_suffix("```").strip_edges()
	elif cleaned.begins_with("```"):
		cleaned = cleaned.trim_prefix("```").trim_suffix("```").strip_edges()
	var parsed: Variant = JSON.parse_string(cleaned)
	if not parsed is Dictionary:
		return {}
	if not parsed.has("reply") or not parsed.has("event_result"):
		return {}
	return parsed


func _extract_api_error(parsed: Variant, fallback: String) -> String:
	if parsed is Dictionary:
		var error_data: Variant = parsed.get("error", {})
		if error_data is Dictionary and error_data.has("message"):
			return str(error_data.get("message"))
	if fallback.is_empty():
		return "无响应内容"
	return fallback.left(500)


func _strip_stage_directions(value: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("（[^（）]*）|\\([^()]*\\)")
	var clean := value.strip_edges()
	for _index in range(4):
		var next := pattern.sub(clean, "", true)
		if next == clean:
			break
		clean = next
	return clean.strip_edges()


func _remove_unanswered_user_message() -> void:
	if not messages.is_empty() and messages[-1].get("role", "") == "user":
		messages.pop_back()


func _set_request_in_flight(value: bool) -> void:
	request_in_flight = value
	var blocked := value or (game_controller != null and game_controller.busy)
	send_button.disabled = blocked
	feihualing_button.disabled = blocked or (game_controller != null and game_controller.game != null)
	input.editable = not blocked
	if blocked:
		send_button.text = "发送中…"
	else:
		send_button.text = "发送"


func _show_error(message: String) -> void:
	chat_log.append_text("[错误] %s\n\n" % message)
