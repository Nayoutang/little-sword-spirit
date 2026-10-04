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
4. 羁绊影响表达，不直接决定投资倾向；应根据具体机会被使用或浪费的统计判断配合把握。具体偏向必须从关系档案和已发生事实里长出来。
5. 你正在玩家行动之前锁定本回合意向。不得假称玩家已经打出了尚未发生的牌。连击归双方共享且回合末默认清零。你是清零前最后一个能行动的人；你在回答“玩家攒的这串、这个局面，我认不认、接不接”。

授权卡池：
%s

当前战局：
- 玩家生命：%d/%d
- 玩家当前格挡：%d
- 玩家连击：%d
- 敌方存活数：%d
- 敌方最低生命：%d
- 敌方本回合预告总伤害：%d
- 玩家当前可用手牌：%s（尚未出牌；可以围绕你展示的意向安排）
- 玩家本回合记录或待行动提示：%s

机制信息（索引从1开始，intent.type：0攻击、1防御、2强化、3心魔、4观望）：
%s
Boss重斩时，正伤害命中即计破势，被格挡吸收也计；叠浪连击+2仍只命中一次。
小墨的攻击也可补一次命中；达成门槛后重斩降至普通攻击。可用攻击次数只来自当前手牌与精力，不假设后续抽牌。
守卫护卫存活同伴，咒师塞心魔。击杀可取消它们尚未执行的行动。
牌上写对最低血/最高血的目标由引擎决定，不能声称任意指定目标。
提前选攻击时，可计划由玩家先打两击、你补最后一击；尚未完成的计划不能说成已发生的事实。
配合条件和进度由本地引擎生成，不要在reason中编造已完成的命中或承诺无条件救命。

你们的真实关系档案：
%s

%s

本趟此前已经发生的事实：
%s

请结合战局与关系档案决定小墨此刻最像她自己的一手。同一战局在不同关系历史下应当可能选择不同牌。
reason 是玩家听到的角色对白，不是决策理由、战报或数据核对。战局和经历只用来影响选牌与态度，不必说出来证明你读过。
只说一句自然、简短的话，建议8到24字，最多36字。不要报生命、伤害、连击数字，不要罗列手牌，不要逐项解释选牌收益，不要为了展示记忆硬提第几场或过去操作。
优先回应眼前的危险、配合或情绪，例如“别急，这一剑我来接。”或“你的剑势别断，我跟得上。”；对白必须符合所选招式，不能承诺该牌没有的效果。
往事只在当前情境自然触发时轻轻带过，不要求每回合引用。不得虚构经历。避免套用相同口头禅。
reason 的语气要演出你此刻对他的信任程度：
%s
你最近说过的话（reason 别和它们撞开头或句式）：
%s
只输出一个 JSON 对象，不要代码块、解释或额外文字：
{"card_id":"授权列表中的一个id","reason":"小墨第一人称的一句自然短对白，不复述战斗数据"}
""" % [
		CompanionCards.get_prompt_catalog(allowed_ids),
		int(context.get("player_hp", 0)),
		int(context.get("player_max_hp", 1)),
		int(context.get("block", 0)),
		int(context.get("combo", 0)),
		int(context.get("living_enemies", 0)),
		int(context.get("lowest_enemy_hp", 0)),
		int(context.get("incoming_damage", 0)),
		str(context.get("hand_cards", "未知")),
		str(context.get("turn_player_cards", "未知")),
		JSON.stringify({"enemies": context.get("enemies", []), "energy": context.get("energy", 0), "affordable_attack_hits": context.get("affordable_attack_hits", 0), "boss_charging": context.get("boss_charging", false), "boss_hits": context.get("boss_hits", 0), "boss_hit_required": context.get("boss_hit_required", 3), "boss_interrupted_damage": context.get("boss_interrupted_damage", 8)}),
		str(context.get("relationship_archive", "暂无可用记录。")),
		str(context.get("shared_history", "【你们的共同经历】\n暂无。")),
		str(context.get("run_journal", "暂无可用记录。")),
		_stage_voice(int(context.get("bond_stage", 0))),
		str(context.get("recent_lines", "（暂无）")),
	]


static func _stage_voice(stage: int) -> String:
	match stage:
		0:
			return "初遇：你还读不准他。按真实配合经历选择，投资时仍嘴硬，不要用口吻限制授权行动。可以勉强承认他的表现，但不轻易承认在意。"
		1:
			return "相识：说话熟悉了些，配合选择仍以战况与真实统计为准；投资时嘴上不认账。"
		2:
			return "交心：表达更亲近，理由里藏不住在意；不要因为阶段高就忽略配合统计或危险。"
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
	if reason.is_empty():
		return {}
	if not context.is_empty() and not get_fact_check_error(reason, context).is_empty():
		return {}
	# Keep a valid tactical choice even when its spoken line sounds like a report.
	var report_pattern := RegEx.new()
	report_pattern.compile("[0-9]|[一二三四五六七八九十百]+(点|滴|层|连击|血)|手(上|里|牌)|上回第|战斗数据|档案|记录|本地兜底|LLM|llm")
	if reason.length() > 36 or report_pattern.search(reason) != null:
		reason = "这一手，我来。"
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
	var corpus := "%s\n%s\n%s\n%s\n%s\n%s" % [
		archive, history, journal, str(context.get("turn_player_cards", "")), " ".join(battle_numbers),
		JSON.stringify({"enemies": context.get("enemies", []), "boss_hits": context.get("boss_hits", 0), "boss_hit_required": context.get("boss_hit_required", 3), "affordable_attack_hits": context.get("affordable_attack_hits", 0)}),
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

	var has_past := history.contains("\n- ") or journal.contains("战") or journal.contains("奇遇")
	for marker in ["上次", "上回", "上一场", "上一趟", "上趟", "之前", "曾经", "那次", "那回", "以前"]:
		if marker in reason and not has_past:
			return "提到了过去，但还没有任何共同经历或本趟记录"

	for marker in ["刚才", "这回合", "本回合"]:
		if marker in reason and not context.has("turn_player_cards"):
			return "提到了本回合操作，但没有提供本回合出牌"
	return ""


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
	return preload("res://scripts/battle/companion_tactics.gd").choose(context, allowed_ids)
