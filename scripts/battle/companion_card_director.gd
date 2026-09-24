class_name CompanionCardDirector
extends RefCounted

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")


static func build_prompt(context: Dictionary, allowed_ids: Array[String]) -> String:
	return """你现在是小墨在战斗中的出牌脑。你不是旁白，也不是战斗引擎。
你只能从授权卡池中选择一张牌；所有伤害、格挡和结算都由本地引擎执行，你不得修改数值、创造卡牌或替玩家操作。

你的核心不是求数学最优，而是在战术合格的选择之间，让关系拍板。
必须严格按以下顺序思考：
1. 先用战况筛掉明显亏损、会害玩家送命或白白浪费效果的“蠢牌”，绝不做猪队友。
2. 在剩下都不亏的牌里，由关系拍板，不默认选择数学收益最高的牌。
3. 关系轴只有一条：自保/当场兑现 ↔ 投资玩家。自保是你现在收残血或贴足盾；投资是把这一手变成玩家下回合的资源、把主动权留给玩家。
4. 关系越浅，你越读不准玩家、越偏自保；关系越深，你越能预判玩家、越愿意铺路。具体偏向必须从关系档案和已发生事实里长出来。
5. 连击归玩家且回合末默认清零。你是清零前最后一个能行动的人；你在回答“玩家攒的这串、这个局面，我认不认、接不接”。

授权卡池：
%s

当前战局：
- 玩家生命：%d/%d
- 玩家当前格挡：%d
- 玩家连击：%d
- 敌方存活数：%d
- 敌方最低生命：%d
- 敌方本回合预告总伤害：%d
- 玩家这回合刚出的牌：%s

你们的真实关系档案：
%s

%s

本趟此前已经发生的事实：
%s

请结合战局与关系档案决定小墨此刻最像她自己的一手。同一战局在不同关系历史下应当可能选择不同牌。
reason 必须绑定上面确实存在的一条具体事实：共同经历里的某件往事、某个约定、本趟记录里的某一场，或玩家这回合刚做的具体操作（刚出了什么牌、攒了几连击）。能引用共同经历时优先引用。泛泛的“为了保护你”“相信你”不合格；不得虚构档案中不存在的经历。
reason 的语气要演出你此刻对他的信任程度：
%s
只输出一个 JSON 对象，不要代码块、解释或额外文字：
{"card_id":"授权列表中的一个id","reason":"小墨第一人称的一句简短归因，必须能挂回当前战局或关系历史"}
""" % [
		CompanionCards.get_prompt_catalog(allowed_ids),
		int(context.get("player_hp", 0)),
		int(context.get("player_max_hp", 1)),
		int(context.get("block", 0)),
		int(context.get("combo", 0)),
		int(context.get("living_enemies", 0)),
		int(context.get("lowest_enemy_hp", 0)),
		int(context.get("incoming_damage", 0)),
		str(context.get("turn_player_cards", "未知")),
		str(context.get("relationship_archive", "暂无可用记录。")),
		str(context.get("shared_history", "【你们的共同经历】\n暂无。")),
		str(context.get("run_journal", "暂无可用记录。")),
		_stage_voice(int(context.get("bond_stage", 0))),
	]


static func _stage_voice(stage: int) -> String:
	match stage:
		0:
			return "初遇：你还不信他，也读不准他。你只肯自己动手或自保；哪怕他刚才打得不错，也要嘴硬地表示还是你来比较稳。可以勉强承认他某一下还凑合，但不把主动权交给他。"
		1:
			return "相识：你开始看得懂他的打法，偶尔愿意把一手让给他，但嘴上不认账，要找个别扭的借口。"
		2:
			return "交心：你会为他铺路，嘴硬很快就破功，理由里藏不住在意。"
		_:
			return "生死之交：你们之间有默契，理由可以像只说给他听的半句话，不必解释。"


static func parse_choice(raw_content: String, allowed_ids: Array[String], context: Dictionary = {}) -> Dictionary:
	var cleaned := raw_content.strip_edges()
	if cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		var last_fence := cleaned.rfind("```")
		if first_newline >= 0 and last_fence > first_newline:
			cleaned = cleaned.substr(first_newline + 1, last_fence - first_newline - 1).strip_edges()
	var parsed: Variant = JSON.parse_string(cleaned)
	if not parsed is Dictionary:
		return {}
	var card_id := str(parsed.get("card_id", ""))
	if card_id not in allowed_ids:
		return {}
	var reason := str(parsed.get("reason", "")).strip_edges()
	if reason.length() > 80:
		reason = reason.left(80)
	if reason.is_empty() or not _reason_has_fact_anchor(reason):
		return {}
	if not context.is_empty() and not get_fact_check_error(reason, context).is_empty():
		return {}
	return {"card_id": card_id, "reason": reason, "source": "llm"}


# 核对 reason 引用的事实在喂给她的材料里真实存在；返回空串表示通过，否则返回失败原因。
static func get_fact_check_error(reason: String, context: Dictionary) -> String:
	var archive := str(context.get("relationship_archive", ""))
	var history := str(context.get("shared_history", ""))
	var journal := str(context.get("run_journal", ""))
	var battle_numbers: Array[String] = []
	for key in ["player_hp", "player_max_hp", "block", "combo", "living_enemies", "lowest_enemy_hp", "incoming_damage"]:
		if context.has(key):
			battle_numbers.append(str(int(context[key])))
	var corpus := "%s\n%s\n%s\n%s\n%s" % [
		archive, history, journal, str(context.get("turn_player_cards", "")), " ".join(battle_numbers),
	]
	var corpus_numbers := {}
	var number_pattern := RegEx.new()
	number_pattern.compile("\\d+")
	for match_result in number_pattern.search_all(corpus):
		corpus_numbers[match_result.get_string()] = true
	for match_result in number_pattern.search_all(reason):
		if not corpus_numbers.has(match_result.get_string()):
			return "数字 %s 不在档案里" % match_result.get_string()

	var promise_pattern := RegEx.new()
	promise_pattern.compile("(兑现约定|失约)\\s*[1-9]\\d*\\s*次")
	var has_promise_fact := (
		not str(context.get("active_promise", "")).is_empty()
		or archive.contains("本趟约定：")
		or promise_pattern.search(archive) != null
		or history.contains("答应")
		or journal.contains("答应")
	)
	for marker in ["约定", "答应", "承诺", "守约", "失约", "兑现"]:
		if marker in reason and not has_promise_fact:
			return "提到了约定，但档案里没有任何约定记录"

	var has_past := history.contains("\n- 第") or journal.contains("战") or journal.contains("奇遇")
	for marker in ["上次", "上回", "上一场", "上一趟", "上趟", "之前", "曾经", "那次", "那回", "以前"]:
		if marker in reason and not has_past:
			return "提到了过去，但还没有任何共同经历或本趟记录"

	for marker in ["刚才", "这回合", "本回合"]:
		if marker in reason and not context.has("turn_player_cards"):
			return "提到了本回合操作，但没有提供本回合出牌"
	return ""


static func _reason_has_fact_anchor(reason: String) -> bool:
	# 这是格式层的最低限度校验；事实是否真实仍由 prompt 中提供的档案约束。
	# 刻意拒绝“为了保护你”一类完全脱离档案的万能理由。
	for marker in [
		"约定", "答应", "承诺", "守约", "失约", "兑现", "胜", "败",
		"上次", "上回", "上一场",
		"本趟", "远征", "机缘", "心事", "第", "曾经", "之前", "记录",
		"刚才", "这回合", "本回合", "连击", "那次", "那回",
	]:
		if marker in reason:
			return true
	for digit in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		if digit in reason:
			return true
	return false


static func request_online_choice(
	host: Node,
	context: Dictionary,
	allowed_ids: Array[String],
	debug_output: bool = false
) -> Dictionary:
	var api_key := LLMConfig.get_api_key()
	if LLMConfig.API_URL.is_empty() or LLMConfig.MODEL_NAME.is_empty() or api_key.is_empty():
		return {}
	var request := HTTPRequest.new()
	request.timeout = 8.0
	host.add_child(request)
	var body := JSON.stringify({
		"model": LLMConfig.MODEL_NAME,
		"messages": [
			{
				"role": "system",
				"content": LLMConfig.load_system_prompt() + "\n\n你当前是小墨的战斗出牌决策层。严格遵守授权卡池，只返回要求的 JSON。",
			},
			{
				"role": "user",
				"content": build_prompt(context, allowed_ids),
			},
		],
		"temperature": 0.45,
		"max_tokens": 120,
		"response_format": {"type": "json_object"},
	})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	var error := request.request(
		LLMConfig.API_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		if debug_output:
			printerr("LLM 请求启动失败：%s" % error_string(error))
		request.queue_free()
		return {}
	var response: Array = await request.request_completed
	request.queue_free()
	if response.size() < 4:
		if debug_output:
			printerr("LLM 响应结构不完整。")
		return {}
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) < 200 or int(response[1]) >= 300:
		if debug_output:
			printerr("LLM 请求失败：result=%d, HTTP=%d" % [int(response[0]), int(response[1])])
		return {}
	var response_body: PackedByteArray = response[3]
	var response_json: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if not response_json is Dictionary:
		if debug_output:
			printerr("LLM 响应不是合法 JSON。")
		return {}
	var choices: Variant = response_json.get("choices", [])
	if not choices is Array or choices.is_empty():
		if debug_output:
			printerr("LLM 响应不含 choices。")
		return {}
	var first_choice: Variant = choices[0]
	if not first_choice is Dictionary:
		return {}
	var message: Variant = first_choice.get("message", {})
	if not message is Dictionary:
		if debug_output:
			printerr("LLM choices[0] 不含 message。")
		return {}
	var raw_content := str(message.get("content", ""))
	var parsed_choice := parse_choice(raw_content, allowed_ids, context)
	if parsed_choice.is_empty() and debug_output:
		var loose := parse_choice(raw_content, allowed_ids)
		var why := "格式或锚点不合格"
		if not loose.is_empty():
			why = get_fact_check_error(str(loose.get("reason", "")), context)
		printerr("LLM 选牌未通过本地校验（%s）。原始输出：%s" % [why, raw_content])
	return parsed_choice


static func choose_fallback(context: Dictionary, allowed_ids: Array[String]) -> Dictionary:
	var hp := int(context.get("player_hp", 0))
	var max_hp := maxi(int(context.get("player_max_hp", 1)), 1)
	var incoming := int(context.get("incoming_damage", 0))
	var combo := int(context.get("combo", 0))
	var facts: Dictionary = context.get("memory", {})
	var kept := int(facts.get("promise_kept", 0))
	var broken := int(facts.get("promise_broken", 0))
	var active_promise := str(context.get("active_promise", ""))

	if CompanionCards.OATH_GUARD in allowed_ids and incoming > 0 and (hp * 2 <= max_hp or active_promise == "protect"):
		return _fallback_result(CompanionCards.OATH_GUARD, "站稳，这一下我来挡。")
	if incoming > 0 and (hp * 3 <= max_hp or broken > kept):
		if CompanionCards.RETURN_GUARD in allowed_ids:
			return _fallback_result(CompanionCards.RETURN_GUARD, "别硬接，这一下我来挡。")
		if CompanionCards.GUARD_ECHO in allowed_ids:
			return _fallback_result(CompanionCards.GUARD_ECHO, "别硬接，这一下我来挡。")
	if CompanionCards.LONE_JUDGMENT in allowed_ids and combo >= 2 and kept >= broken:
		return _fallback_result(CompanionCards.LONE_JUDGMENT, "剑势够了，我来收。")
	if CompanionCards.FOLLOW_UP in allowed_ids and combo > 0:
		return _fallback_result(CompanionCards.FOLLOW_UP, "别停，你起的剑势我来接。")
	if incoming >= hp:
		if CompanionCards.RETURN_GUARD in allowed_ids:
			return _fallback_result(CompanionCards.RETURN_GUARD, "逞什么强，先躲到我剑后。")
		if CompanionCards.GUARD_ECHO in allowed_ids:
			return _fallback_result(CompanionCards.GUARD_ECHO, "逞什么强，先躲到我剑后。")
	if CompanionCards.CLEAN_CUT in allowed_ids:
		return _fallback_result(CompanionCards.CLEAN_CUT, "局面还算清楚，我先利落处理掉眼前的麻烦。")
	return _fallback_result(CompanionCards.QUICK_SLASH, "这种小场面，我顺手替你补一剑。")


static func _fallback_result(card_id: String, reason: String) -> Dictionary:
	# 本地规则读不到关系语义，因此从机制上禁止它伪装成“投资玩家”。
	if CompanionCards.is_investment(card_id):
		return {"card_id": CompanionCards.QUICK_SLASH, "reason": "这种小场面，我顺手替你补一剑。", "source": "fallback"}
	return {"card_id": card_id, "reason": reason, "source": "fallback"}
