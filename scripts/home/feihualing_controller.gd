class_name FeihualingController
extends Node

signal spoken(text: String)
signal hud_changed(text: String, visible: bool)
signal busy_changed(busy: bool)
signal finished(summary: String)
signal intent_learned(card_id: String, player_line: String)

const DEBUG_LOG := "user://feihualing_debug.log"

var game: FeihualingGame
var busy := false
var request: HTTPRequest
var action := ""
var player_text := ""
var intent_hint := ""
var local_result := ""
var json_retries := 0
var line_retries := 0
var retry_suffix := ""
var closure_retries := 0
var last_keyword := ""
var remaining_keywords: Array[String] = []
# 剑意感悟：本轮玩家若对出剑意诗句，提示她演出感悟；一局最多一次。
var intent_cue := ""
var pending_intent_id := ""
var rounds_before_turn := 0
var intent_triggered_this_game := false


func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 60.0
	add_child(request)
	request.request_completed.connect(_on_request_completed)


func start(chosen_keyword: String = "") -> void:
	if busy or game != null:
		return
	var next_keyword := chosen_keyword if FeihualingGame.is_valid_keyword(chosen_keyword) else _draw_keyword()
	if FeihualingGame.is_valid_keyword(chosen_keyword):
		remaining_keywords.erase(chosen_keyword)
	game = FeihualingGame.new(next_keyword)
	intent_triggered_this_game = false
	_update_hud()
	_send_round("opening", "")


func _draw_keyword() -> String:
	if remaining_keywords.is_empty():
		for character in FeihualingGame.CHARACTERS:
			remaining_keywords.append(character)
		remaining_keywords.shuffle()
		if remaining_keywords.size() > 1 and remaining_keywords.back() == last_keyword:
			var first := remaining_keywords[0]
			remaining_keywords[0] = remaining_keywords[remaining_keywords.size() - 1]
			remaining_keywords[remaining_keywords.size() - 1] = first
	return remaining_keywords.pop_back()


func cancel() -> void:
	if request != null:
		request.cancel_request()
	game = null
	action = ""
	player_text = ""
	intent_hint = ""
	local_result = ""
	retry_suffix = ""
	json_retries = 0
	line_retries = 0
	closure_retries = 0
	if busy:
		_set_busy(false)
	hud_changed.emit("", false)


func submit(text: String) -> void:
	if busy or game == null:
		return
	_send_round("turn", text)


func _send_round(next_action: String, next_player_text: String, retry: bool = false) -> void:
	if not retry:
		action = next_action
		player_text = next_player_text
		intent_hint = game.classify_input(player_text) if action == "turn" else ""
		local_result = game.local_verdict(player_text) if intent_hint in ["line", "unknown"] else "不适用"
		json_retries = 0
		line_retries = 0
		closure_retries = 0
		retry_suffix = ""
		_prepare_intent_cue()
	var prompt := game.round_request(action, player_text, {
		"intent_hint": intent_hint,
		"local_verdict": local_result,
	}) + intent_cue + retry_suffix
	var payload := {
		"model": LLMConfig.MODEL_NAME,
		"response_format": {"type": "json_object"},
		"messages": [
			{"role": "system", "content": game.system_prompt([
				LLMConfig.load_system_prompt(),
				RunState.get_relationship_prompt(),
				AbilityManager.get_prompt_context(),
				RunState.get_run_journal_prompt(),
				RunState.get_shared_history_prompt(),
				RunState.get_minigame_memory_prompt(),
			])},
			{"role": "user", "content": prompt},
		],
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % LLMConfig.get_api_key(),
	])
	_set_busy(true)
	var error := request.request(LLMConfig.API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_set_busy(false)
		_on_bad_reply("request_start_%d" % error, "")


func _on_request_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if game == null:
		return
	_set_busy(false)
	var body_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		_on_bad_reply("request_result_%d_http_%d" % [result, status], body_text)
		return
	var envelope: Variant = JSON.parse_string(body_text)
	if not envelope is Dictionary:
		_on_bad_reply("invalid_api_json", body_text)
		return
	var choices: Variant = envelope.get("choices", [])
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		_on_bad_reply("invalid_api_choices", body_text)
		return
	var message: Variant = choices[0].get("message", {})
	if not message is Dictionary:
		_on_bad_reply("invalid_api_message", body_text)
		return
	var raw := str(message.get("content", ""))
	var reply := game.parse_round_reply(raw)
	if reply.is_empty():
		_on_bad_reply("invalid_game_json", raw)
		return
	var outcome := game.process_reply(action, player_text, intent_hint, reply)
	if outcome.get("retry_closure", false):
		_log("ambiguous_game_over", raw)
		if closure_retries == 0:
			closure_retries = 1
			retry_suffix = "\n本局会在这轮结束。comment 必须明确说出谁赢谁输，用小墨亲口说的话收住这一局；不要含糊，也不要解释机制。只输出 JSON。"
			_send_round(action, player_text, true)
		else:
			_update_hud(true)
		return
	if outcome.get("retry_line", false):
		_log("invalid_my_line_%s" % outcome.get("reason", ""), raw)
		if line_retries == 0:
			line_retries = 1
			retry_suffix = "\n只输出 JSON。my_line 必须是含令字、不重复、无省略号的完整一联（上下两句）。"
			_send_round(action, player_text, true)
		else:
			_send_round("concede", player_text)
		return
	var speech := str(outcome.get("speech", ""))
	if not speech.is_empty():
		spoken.emit(speech)
	if not pending_intent_id.is_empty() and game.player_rounds > rounds_before_turn:
		intent_triggered_this_game = true
		if RunState.learn_sword_intent(pending_intent_id, player_text):
			intent_learned.emit(pending_intent_id, player_text)
	pending_intent_id = ""
	intent_cue = ""
	if outcome.get("finished", false):
		last_keyword = game.keyword
		var player_won := bool(outcome.get("player_won", false))
		var summary := game.record_result(bool(outcome.get("player_won", false)), str(outcome.get("reason", "")))
		RunState.record_minigame_result(summary)
		game = null
		hud_changed.emit("令·%s ｜ %s" % [last_keyword, "你胜" if player_won else "小墨胜"], true)
		finished.emit(summary)
	else:
		_update_hud()


func _prepare_intent_cue() -> void:
	intent_cue = ""
	pending_intent_id = ""
	rounds_before_turn = game.player_rounds
	if action != "turn" or intent_triggered_this_game or local_result != "合规":
		return
	var card_id := CompanionCardDatabase.match_sword_intent(player_text)
	if card_id.is_empty() or card_id in RunState.learned_sword_intents:
		return
	var definition := CompanionCardDatabase.get_definition(card_id)
	pending_intent_id = card_id
	intent_cue = "\n【特别】玩家这一句出自%s「%s」。%s这句诗说的是剑，你来了兴致。这一轮 comment 用一两句，以懂剑的人的眼光具体说出这一剑好在哪、换你会怎么出，然后照常出句。不要吞吞吐吐，不要用省略号开头，不要提“以前”“有个人”，不要说“剑招”“技能”“领悟”这类字眼，不要解释效果。" % [
		str(definition.get("source", "")),
		str(definition.get("poem", "")),
		str(definition.get("hint", "")),
	]


func _on_bad_reply(reason: String, raw: String) -> void:
	_log(reason, raw)
	if json_retries == 0:
		json_retries = 1
		retry_suffix = "\n只输出 JSON，不要任何其它文字。"
		_send_round(action, player_text, true)
		return
	# 状态不推进；下一次玩家输入仍在同一轮。
	json_retries = 0
	retry_suffix = ""
	_update_hud(true)


func _update_hud(failed: bool = false) -> void:
	if game == null:
		hud_changed.emit("", false)
		return
	var label := "令·%s ｜ 第%d轮" % [game.keyword, game.player_rounds + 1]
	if failed:
		label += " ｜ 请重试"
	hud_changed.emit(label, true)


func _set_busy(value: bool) -> void:
	busy = value
	busy_changed.emit(value)


func _log(reason: String, raw: String) -> void:
	var file: FileAccess
	if FileAccess.file_exists(DEBUG_LOG):
		file = FileAccess.open(DEBUG_LOG, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(DEBUG_LOG, FileAccess.WRITE)
	if file == null:
		push_warning("飞花令日志写入失败：%s" % FileAccess.get_open_error())
		return
	file.store_line(JSON.stringify({
		"time": Time.get_datetime_string_from_system(),
		"action": action,
		"reason": reason,
		"raw_reply": raw,
	}))
