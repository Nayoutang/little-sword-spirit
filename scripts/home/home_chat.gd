extends Node2D

@export var preview_offline := false

@onready var chat_log: RichTextLabel = $ChatUI/ChatPanel/ChatLog
@onready var input: LineEdit = $ChatUI/ChatPanel/Input
@onready var send_button: Button = $ChatUI/ChatPanel/SendButton
@onready var depart_button: Button = $ChatUI/ChatPanel/DepartButton
@onready var feihualing_button: Button = $ChatUI/ChatPanel/FeihualingButton
@onready var game_screen: Control = $FeihualingLayer/GameScreen
@onready var game_status: Label = $FeihualingLayer/GameScreen/Status
@onready var game_log: RichTextLabel = $FeihualingLayer/GameScreen/GameLog
@onready var game_input: LineEdit = $FeihualingLayer/GameScreen/GameInput
@onready var game_send_button: Button = $FeihualingLayer/GameScreen/GameSendButton
@onready var game_again_button: Button = $FeihualingLayer/GameScreen/AgainButton
@onready var game_exit_button: Button = $FeihualingLayer/GameScreen/ExitButton
@onready var bond_label: Label = $ChatUI/ChatPanel/BondLabel
@onready var http_request: HTTPRequest = $HTTPRequest

var messages: Array[Dictionary] = []
var request_in_flight := false
var game_controller: FeihualingController
var game_choice_pending := false
var greeting_in_flight := false
var variety_retried := false
var reply_pages: Array[String] = []
var reply_page_index := 0


func _ready() -> void:
	_resize_background()
	get_viewport().size_changed.connect(_resize_background)
	# 新存档第一次进家前，先播初遇剧情。
	if RunState.needs_intro():
		get_tree().change_scene_to_file("res://scenes/intro.tscn")
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
	game_screen.hide()
	$ChatUI/ChatPanel/HistoryButton.pressed.connect(_toggle_history)
	$ChatUI/ChatPanel/ReplyNext.pressed.connect(_advance_reply)
	$ChatUI/ChatPanel/HistoryClose.pressed.connect(_toggle_history)
	var card_library = preload("res://scripts/ui/card_library.gd").new()
	card_library.name = "CardLibrary"
	add_child(card_library)
	$ChatUI/ChatPanel/CardLibraryButton.pressed.connect(card_library.open)
	for button: Button in [depart_button, feihualing_button, $ChatUI/ChatPanel/SaveSlotsButton, $ChatUI/ChatPanel/CardLibraryButton]:
		button.mouse_entered.connect(_set_menu_hover.bind(button, true))
		button.mouse_exited.connect(_set_menu_hover.bind(button, false))
	send_button.pressed.connect(_send_message)
	depart_button.pressed.connect(_go_to_map)
	feihualing_button.tooltip_text = "随机令字；也可在聊天中输入“飞花令，以柳为令”来自选。"
	feihualing_button.pressed.connect(_start_feihualing)
	game_again_button.pressed.connect(_on_game_again)
	game_exit_button.pressed.connect(_on_game_leave)
	game_send_button.pressed.connect(_send_game_message)
	game_input.text_submitted.connect(_on_game_text_submitted)
	$ChatUI/ChatPanel/SaveSlotsButton.pressed.connect(_return_to_save_slots)
	input.text_submitted.connect(_on_text_submitted)
	http_request.request_completed.connect(_on_request_completed)
	game_controller = FeihualingController.new()
	add_child(game_controller)
	game_controller.spoken.connect(_on_game_spoken)
	game_controller.hud_changed.connect(_on_game_hud_changed)
	game_controller.busy_changed.connect(_on_game_busy_changed)
	game_controller.finished.connect(_on_game_finished)
	game_controller.intent_learned.connect(_on_intent_learned)
	_refresh_bond_display()
	if SpecialEventManager.has_active_event():
		chat_log.append_text("[特殊对话] 小墨似乎有一件刚才发生的事想和你谈谈。\n\n")
	if not AbilityManager.unlocked.is_empty():
		chat_log.append_text("[已掌握神通] %s\n\n" % AbilityManager.get_unlocked_names())
	input.grab_focus()
	if RunState.finale_state != "invited" and not preview_offline and RunState.consume_homecoming():
		_request_homecoming_greeting()


# 远征归来后，小墨先就着这一趟里某件具体的事开口；失败时静默跳过，不用代码替她说话。
func _request_homecoming_greeting() -> void:
	var api_key := LLMConfig.get_api_key()
	if preview_offline or LLMConfig.API_URL.is_empty() or api_key.is_empty() or LLMConfig.MODEL_NAME.is_empty():
		return
	var cue := "【旁白，不是持剑人说的话】持剑人刚结束第%d趟远征回到家，还没开口。你可以先随口说一两句，接着本趟某件真实的事，也可以只是轻轻招呼他休息。让熟悉程度自然体现在语气里，不报血量和羁绊数字，不宣布关系升级，不复述流水账，不要求他回答、道歉或作出承诺。不是每件经历都需要当场谈清楚，也不要把每次回家都写成严肃谈心。" % RunState.expedition_count
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
		JSON.stringify(_chat_payload())
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
	_show_home_reply(reply)
	RunState.record_spoken_line(reply)


# 请求体：在最后一条玩家消息之前插入一条临时提示（最近说过的话 + 此刻心情），不写进对话历史。
func _chat_payload(strict: bool = false) -> Dictionary:
	var payload_messages: Array = messages.duplicate()
	var note := RunState.get_variety_prompt()
	if strict:
		note += "\n你刚才那版回复的开头或口头禅和最近说过的话撞了。重说一遍，换一个完全不同的切入点。"
	payload_messages.insert(maxi(payload_messages.size() - 1, 1), {"role": "system", "content": note})
	var payload := {"model": LLMConfig.MODEL_NAME, "messages": payload_messages}
	if SpecialEventManager.has_active_event():
		payload["temperature"] = 1.0
	else:
		payload["temperature"] = 1.3
		payload["frequency_penalty"] = 0.5
		payload["presence_penalty"] = 0.3
	return payload


func _retry_for_variety() -> bool:
	var api_key := LLMConfig.get_api_key()
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	_set_request_in_flight(true)
	var error := http_request.request(LLMConfig.API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(_chat_payload(true)))
	if error != OK:
		_set_request_in_flight(false)
		return false
	return true


func _refresh_bond_display() -> void:
	# 进度仍用于内部节奏与配合，日常相处不展示亲密度计分。
	bond_label.hide()


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


func _requested_feihualing_keyword(player_text: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("(?:以|用|拿)\\s*([\\p{Han}])\\s*(?:字)?\\s*(?:为令|作令|玩飞花令)|令字\\s*[：:]?\\s*([\\p{Han}])|飞花令\\s*[：:]\\s*([\\p{Han}])")
	var matched := pattern.search(player_text)
	if matched == null:
		return ""
	for index in range(1, 4):
		var candidate := matched.get_string(index)
		if FeihualingGame.is_valid_keyword(candidate):
			return candidate
	return ""


func _start_feihualing(chosen_keyword: String = "") -> void:
	if request_in_flight or game_controller.busy or game_controller.game != null:
		return
	game_choice_pending = false
	game_again_button.hide()
	game_log.clear()
	game_status.text = "令字待揭晓"
	game_input.clear()
	game_screen.show()
	$ChatUI/ChatPanel.hide()
	if preview_offline or LLMConfig.API_URL.is_empty() or LLMConfig.get_api_key().is_empty() or LLMConfig.MODEL_NAME.is_empty():
		game_status.text = "暂时无法开始"
		game_log.text = "飞花令需要配置对话服务，配置完成后再来对诗吧。"
		_refresh_game_controls()
		return
	input.release_focus()
	game_input.grab_focus()
	game_controller.start(chosen_keyword)
	_refresh_game_controls()


func _on_game_again() -> void:
	_start_feihualing()


func _on_game_leave() -> void:
	game_controller.cancel()
	game_choice_pending = false
	game_again_button.hide()
	game_screen.hide()
	$ChatUI/ChatPanel.show()
	_set_request_in_flight(request_in_flight)
	input.grab_focus()


func _on_game_text_submitted(_submitted_text: String) -> void:
	_send_game_message()


func _send_game_message() -> void:
	if not game_screen.visible or game_controller.busy or game_controller.game == null:
		return
	var player_text := game_input.text.strip_edges()
	if player_text.is_empty():
		return
	game_input.clear()
	game_log.append_text("你：%s\n\n" % player_text)
	game_controller.submit(player_text)


func _on_game_spoken(text: String) -> void:
	game_log.append_text("小墨：%s\n\n" % text)


func _on_intent_learned(card_id: String, _player_line: String) -> void:
	var definition := CompanionCardDatabase.get_definition(card_id)
	game_log.append_text("[剑意] 小墨从「%s」（%s）里有所感悟：「%s」——%s 战斗中，出不出这一剑由她决定。\n\n" % [
		str(definition.get("poem", "")),
		str(definition.get("source", "")),
		str(definition.get("name", card_id)),
		str(definition.get("description", "")),
	])


func _on_game_hud_changed(label: String, visible: bool) -> void:
	game_status.text = label if visible else "令字待揭晓"


func _on_game_busy_changed(_busy: bool) -> void:
	_set_request_in_flight(request_in_flight)
	_refresh_game_controls()


func _refresh_game_controls() -> void:
	var can_answer := game_controller.game != null and not game_controller.busy and not game_choice_pending
	game_input.editable = can_answer
	game_send_button.disabled = not can_answer
	if can_answer and game_screen.visible:
		game_input.grab_focus()


func _on_game_finished(summary: String) -> void:
	messages.append({"role": "system", "content": "刚结束的小游戏结果（可信事实）：%s" % summary})
	game_log.append_text("[对局结束] %s\n" % summary)
	game_choice_pending = true
	game_again_button.show()
	_set_request_in_flight(request_in_flight)
	_refresh_game_controls()


func _send_message() -> void:
	if game_screen.visible or request_in_flight or game_controller.busy:
		return

	var player_text := input.text.strip_edges()
	if player_text.is_empty():
		return
	if _is_feihualing_invitation(player_text):
		input.clear()
		_start_feihualing(_requested_feihualing_keyword(player_text))
		return

	var api_key := LLMConfig.get_api_key()
	if preview_offline or LLMConfig.API_URL.is_empty() or api_key.is_empty() or LLMConfig.MODEL_NAME.is_empty():
		_show_error("未配置 LLM API Key。请设置环境变量 %s。" % LLMConfig.API_KEY_ENV)
		return

	input.clear()
	var display_name := RunState.player_name.strip_edges()
	if display_name.is_empty():
		display_name = "你"
	chat_log.append_text("%s：%s\n\n" % [display_name, player_text])
	messages.append({"role": "user", "content": player_text})

	var payload := _chat_payload()
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
	if not SpecialEventManager.has_active_event() and not variety_retried and RunState.is_repetitive(reply):
		variety_retried = true
		if _retry_for_variety():
			return
	variety_retried = false

	messages.append({"role": "assistant", "content": reply})
	chat_log.append_text("小墨：%s\n\n" % reply)
	_show_home_reply(reply)
	RunState.record_spoken_line(reply)
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
	_show_home_reply(message)


func _show_home_reply(reply: String) -> void:
	reply_pages.clear()
	var label: RichTextLabel = $ChatUI/ChatPanel/CurrentReply
	var font := label.get_theme_font("normal_font")
	var font_size := label.get_theme_font_size("normal_font_size")
	var max_lines := maxi(1, int(label.size.y / font.get_height(font_size)))
	var page := ""
	var width := 0.0
	var lines := 1
	for character in reply:
		var character_width := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if character == "\n" or width + character_width > label.size.x - 12.0:
			if lines >= max_lines:
				reply_pages.append(page)
				page = ""
				lines = 1
			else:
				if character != "\n":
					page += "\n"
				lines += 1
			width = 0.0
		page += character
		if character != "\n":
			width += character_width
	if not page.is_empty():
		reply_pages.append(page)
	if reply_pages.is_empty():
		reply_pages.append("")
	reply_page_index = 0
	_display_reply_page()


func _advance_reply() -> void:
	if reply_page_index + 1 < reply_pages.size():
		reply_page_index += 1
		_display_reply_page()


func _display_reply_page() -> void:
	$ChatUI/ChatPanel/CurrentReply.text = reply_pages[reply_page_index]
	$ChatUI/ChatPanel/ReplyNext.visible = reply_page_index + 1 < reply_pages.size()


func _resize_background() -> void:
	$Background.size = get_viewport_rect().size


func _toggle_history() -> void:
	var show_history := not chat_log.visible
	chat_log.visible = show_history
	$ChatUI/ChatPanel/HistoryArt.visible = show_history
	$ChatUI/ChatPanel/HistoryTitle.visible = show_history
	$ChatUI/ChatPanel/HistoryClose.visible = show_history
	$ChatUI/ChatPanel/HistoryButton.text = "收起对话" if show_history else "回看对话"


func _set_menu_hover(button: Button, hovered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var previous: Tween = button.get_meta("hover_tween", null)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * (1.04 if hovered else 1.0), 0.14)
