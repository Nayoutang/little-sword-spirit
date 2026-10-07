class_name FeihualingGame
extends MiniGameSession

const RULES_PATH := "res://prompts/feihualing_rules.txt"
const CHARACTERS := [
	"花", "月", "风", "雪", "酒", "剑", "春", "山", "水", "云", "雨", "柳",
	"梅", "竹", "松", "秋", "夏", "冬", "夜", "日", "星", "天", "海", "江",
	"河", "湖", "人", "心", "梦", "情", "愁", "别", "归", "家", "乡", "客",
	"君", "书", "歌", "鸟", "雁", "马", "灯", "舟", "桥", "城", "楼", "帆",
]
const REQUIRED_KEYS := [
	"intent", "player_line_valid", "player_line_source", "comment",
	"my_line", "my_line_source", "prompt_next", "give_up",
]

var keyword := ""
var lines: Array[Dictionary] = []
var player_rounds := 0
var completed_partial_rounds := 0
var incomplete_answer_count := 0
var surrender_count := 0
var recent_turns: Array[Dictionary] = []
var last_my_line := ""


func _init(chosen_keyword: String = "") -> void:
	keyword = chosen_keyword if is_valid_keyword(chosen_keyword) else CHARACTERS.pick_random()


static func is_valid_keyword(value: String) -> bool:
	if value.length() != 1:
		return false
	var codepoint := value.unicode_at(0)
	return codepoint >= 0x4e00 and codepoint <= 0x9fff


func rules_prompt() -> String:
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	return file.get_as_text().strip_edges() if file != null else "飞花令：只输出 JSON。"


func validate_round_reply(reply: Dictionary) -> bool:
	for key in REQUIRED_KEYS:
		if not reply.has(key):
			return false
	if not reply["intent"] is String or not reply["intent"] in ["line", "surrender", "challenge", "chat"]:
		return false
	if not reply["player_line_valid"] is bool or not reply["give_up"] is bool:
		return false
	for key in ["player_line_source", "comment", "my_line", "my_line_source", "prompt_next"]:
		if not reply[key] is String:
			return false
	return true


func classify_input(player_text: String) -> String:
	if is_title_only(player_text):
		return "title"
	if _looks_like_line(player_text):
		return "line"
	for phrase in ["认输", "投降", "我不会", "不会", "想不出", "算了", "放弃", "接不上"]:
		if player_text.contains(phrase):
			return "surrender"
	for phrase in ["出处", "编的", "編的", "哪来的", "真的假的"]:
		if player_text.contains(phrase):
			return "challenge"
	return "unknown"


func local_verdict(player_text: String) -> String:
	if not player_text.contains(keyword):
		return "不含令字"
	if has_line(player_text):
		return "重复"
	return "合规"


func round_request(action: String, player_text: String, context: Dictionary = {}) -> String:
	var task := "开场。你先出完整一联；所有说出口的话由 comment 和 prompt_next 承担。"
	if action == "turn":
		var hint := str(context.get("intent_hint", "unknown"))
		var verdict := str(context.get("local_verdict", "不适用"))
		task = "玩家输入的意图本地分类：%s；unknown 时由你在同一次回复判断。若意图是 line，本地判定为【%s】，不得推翻。若不是 line，该判定不适用。" % [hint, verdict]
	elif action == "concede":
		task = "你的出句连续两次未通过本地完整性校验，确实接不上。此轮必须 give_up=true、my_line 为空；comment 由你亲口嘴硬认输，不要提校验或规则。玩家此轮的句子已判有效。"
	return "%s\n【本轮任务】%s\n本局未完整作答已宽限%d次，半联与诗名/词牌名共用一次宽限；第二次本地结算玩家输。\n只输出 JSON，不要任何其它文字。" % [state_block(player_text), task, incomplete_answer_count]


func state_block(pending_player_text: String = "") -> String:
	var used: Array[String] = []
	for entry in lines:
		used.append("【%s】%s" % [entry.get("speaker", ""), entry.get("line", "")])
	var recent: Array[String] = []
	for turn in recent_turns:
		recent.append("comment=%s；prompt_next=%s" % [turn.get("comment", ""), turn.get("prompt_next", "")])
	return "【本地对局状态】\n令字：%s\n已出句子：%s\n本轮待判定【玩家】输入：%s\n玩家已接句数：%d\n本轮玩家已说认输次数：%d（只决定语气，不可说出口）\n最近3轮台词：%s\n归属与数量只认本状态，不自行数。" % [
		keyword, "；".join(used) if not used.is_empty() else "（暂无）",
		pending_player_text if not pending_player_text.is_empty() else "（暂无）",
		player_rounds, surrender_count,
		" / ".join(recent) if not recent.is_empty() else "（暂无）",
	]


func check_my_line(line: String) -> String:
	var clean := line.strip_edges()
	if clean.contains("…") or clean.contains("...") or clean.contains("\n") or clean.contains("\r"):
		return "incomplete"
	clean = clean.trim_suffix("。").trim_suffix("！").trim_suffix("!")
	var clauses := clean.replace(",", "，").split("，")
	if clauses.size() != 2:
		return "incomplete"
	for clause in clauses:
		var length := _normalize_line(clause).length()
		if length < 3 or length > 12:
			return "incomplete"
	if not clean.contains(keyword):
		return "missing_keyword"
	if has_line(line):
		return "repeated"
	return ""


func has_line(line: String) -> bool:
	var normalized := _normalize_line(line)
	for used in lines:
		var previous := _normalize_line(str(used.get("line", "")))
		if normalized == previous or normalized.contains(previous) or previous.contains(normalized):
			return true
	return false


func process_reply(action: String, player_text: String, intent_hint: String, reply: Dictionary, skip_closure_check: bool = false) -> Dictionary:
	var intent := intent_hint if intent_hint != "unknown" else str(reply["intent"])
	var my_line := str(reply["my_line"]).strip_edges()
	var local_outcome := incomplete_preflight(player_text) if action == "turn" else {}
	if not local_outcome.is_empty():
		return local_outcome
	# 模型说“不是诗句”不能绕过第一次宽限，收局对白也不直接采用。
	if action == "turn" and intent == "line" and local_verdict(player_text) == "合规" and not reply["player_line_valid"]:
		return _incomplete_warning("这还没接成诗句呢。先让你一次，想一句完整的再来。")
	# 半联由小墨补全：只拿下这一轮，不触发整局胜负，也不算玩家独立接成功。
	if action == "turn" and intent == "line" and local_verdict(player_text) == "合规" and reply["player_line_valid"] and is_partial_line(player_text):
		if reply["give_up"] or not check_my_line(my_line).is_empty() or not completes_player_line(player_text, my_line):
			return {"retry_line": true, "reason": "partial_completion"}
		var speech_context := str(reply["comment"]) + str(reply["prompt_next"])
		if not speech_context.contains("半") or not speech_context.contains("轮") or not (speech_context.contains("拿下") or speech_context.contains("算我") or speech_context.contains("归我") or speech_context.contains("我赢")):
			return {"retry_line": true, "reason": "partial_completion"}
		for closure in ["这局归我", "这局我拿下", "你输了", "下回再比", "游戏结束"]:
			if speech_context.contains(closure):
				return {"retry_line": true, "reason": "partial_completion"}
		_accept_line("小墨", my_line)
		last_my_line = my_line
		completed_partial_rounds += 1
		incomplete_answer_count += 1
		surrender_count = 0
		return _continue_reply(reply, my_line, "合规")
	var winner := _predicted_winner(action, player_text, intent, reply, my_line)
	if not skip_closure_check and not winner.is_empty() and not _has_clear_closure(reply, winner):
		return {"retry_closure": true}
	var outcome := {"retry_line": false, "speech": "", "finished": false, "player_won": false, "reason": ""}
	if action == "opening":
		if reply["give_up"] or my_line.is_empty():
			return _finish_reply(reply, "", true, "gave_up")
		if not check_my_line(my_line).is_empty():
			return {"retry_line": true, "reason": check_my_line(my_line)}
		_accept_line("小墨", my_line)
		last_my_line = my_line
		return _continue_reply(reply, my_line, "")
	if action == "concede":
		if not player_text.is_empty():
			_accept_line("玩家", player_text)
			player_rounds += 1
		return _finish_reply(reply, "", true, "gave_up")
	match intent:
		"line":
			var verdict := local_verdict(player_text)
			if verdict != "合规":
				return _finish_reply(reply, "", false, "missing_keyword" if verdict == "不含令字" else "repeated")
			if not reply["player_line_valid"]:
				return _finish_reply(reply, "", false, "fabricated_player_line")
			if reply["give_up"] or my_line.is_empty():
				_accept_line("玩家", player_text)
				player_rounds += 1
				return _finish_reply(reply, "", true, "gave_up")
			var error := check_my_line(my_line)
			if not error.is_empty():
				return {"retry_line": true, "reason": error}
			_accept_line("玩家", player_text)
			player_rounds += 1
			surrender_count = 0
			_accept_line("小墨", my_line)
			last_my_line = my_line
			return _continue_reply(reply, my_line, verdict)
		"surrender":
			if surrender_count == 0:
				surrender_count = 1
				return _continue_reply(reply, "", "")
			return _finish_reply(reply, "", false, "player_gave_up")
		"challenge":
			if not last_my_line.is_empty() and (not reply["player_line_valid"] or not _has_source(str(reply["player_line_source"]))):
				return _finish_reply(reply, "", true, "caught_fabrication" if not reply["player_line_valid"] else "missing_source")
			return _continue_reply(reply, "", "")
		_:
			return _continue_reply(reply, "", "")
	return outcome


func _predicted_winner(action: String, player_text: String, intent: String, reply: Dictionary, my_line: String) -> String:
	if action == "concede" or (action == "opening" and (reply["give_up"] or my_line.is_empty())):
		return "player"
	if action == "opening":
		return ""
	match intent:
		"line":
			if local_verdict(player_text) != "合规" or not reply["player_line_valid"]:
				return "xiaomo"
			if reply["give_up"] or my_line.is_empty():
				return "player"
		"surrender":
			if surrender_count >= 1:
				return "xiaomo"
		"challenge":
			if not last_my_line.is_empty() and (not reply["player_line_valid"] or not _has_source(str(reply["player_line_source"]))):
				return "player"
	return ""


func is_partial_line(text: String) -> bool:
	var clauses := text.strip_edges().replace(",", "，").split("，", false)
	return clauses.size() == 1 and _normalize_line(text).length() >= 3 and _normalize_line(text).length() <= 12


func is_title_only(text: String) -> bool:
	var clean := _normalize_line(text).trim_prefix("《").trim_suffix("》")
	return clean in ["如梦令", "浣溪沙", "水调歌头", "满江红", "念奴娇", "沁园春", "蝶恋花", "鹧鸪天", "临江仙", "西江月", "虞美人", "声声慢", "一剪梅", "卜算子", "清平乐", "浪淘沙", "破阵子", "静夜思", "春晓", "登鹳雀楼", "望庐山瀑布", "江雪", "咏柳", "悯农"]


func incomplete_preflight(text: String) -> Dictionary:
	var title := is_title_only(text)
	var half := classify_input(text) == "line" and is_partial_line(text) and local_verdict(text) == "合规"
	var short_answer := text.contains(keyword) and _normalize_line(text).length() <= 2 and not text.contains("?") and not text.contains("？") and classify_input(text) == "unknown"
	if not title and not half and not short_answer:
		return {}
	if short_answer:
		return _incomplete_warning("只有这几个字，还没接成诗句呢。先让你一次，想一句完整的再来。")
	if incomplete_answer_count >= 1:
		incomplete_answer_count += 1
		return {"speech": "这次也没接出完整的诗句。已经让过你一次了，这局归我。歇一会儿，想玩再来。", "finished": true, "player_won": false, "reason": "incomplete_answer_twice"}
	if title:
		incomplete_answer_count += 1
		completed_partial_rounds += 1
		return {"speech": "这是诗名或词牌名，可还没念出诗句呢。先让你一次，想想里面的句子，再接。", "finished": false}
	return {}


func _incomplete_warning(reminder: String) -> Dictionary:
	if incomplete_answer_count >= 1:
		incomplete_answer_count += 1
		return {"speech": "这次也没接出完整的诗句。已经让过你一次了，这局归我。歇一会儿，想玩再来。", "finished": true, "player_won": false, "reason": "incomplete_answer_twice"}
	incomplete_answer_count += 1
	completed_partial_rounds += 1
	return {"speech": reminder, "finished": false}


func incomplete_fallback(text: String) -> Dictionary:
	var outcome := incomplete_preflight(text)
	if not outcome.is_empty():
		return outcome
	if classify_input(text) == "line" and is_partial_line(text) and local_verdict(text) == "合规":
		incomplete_answer_count += 1
		completed_partial_rounds += 1
		return {"speech": "怎么只回了半句，另一半想不起来了吗？先让你一次，再想一句完整的来。", "finished": false}
	return {}


func completes_player_line(player_text: String, completed: String) -> bool:
	var fragment := _normalize_line(player_text)
	for clause in completed.replace(",", "，").split("，"):
		if _normalize_line(clause) == fragment:
			return true
	return false


func _has_clear_closure(reply: Dictionary, winner: String) -> bool:
	var recent: Array[String] = []
	for turn in recent_turns:
		for field in ["comment", "prompt_next"]:
			var old := str(turn.get(field, ""))
			if not old.is_empty():
				recent.append(old)
	var spoken := " ".join([
		_unique_segment(_strip_stage(str(reply["comment"])), recent),
		_unique_segment(_strip_stage(str(reply["prompt_next"])), recent),
	])
	var clear_phrases := ["你赢", "你胜", "算你赢", "归你", "我输", "我认输", "这局是你的"] if winner == "player" else ["我赢", "我胜", "归我", "你输", "你认输", "这局我拿下"]
	for phrase in clear_phrases:
		if spoken.contains(phrase):
			return true
	return false


func closure_fallback(action: String, player_text: String, intent_hint: String, reply: Dictionary) -> Dictionary:
	var intent := intent_hint if intent_hint != "unknown" else str(reply["intent"])
	var winner := _predicted_winner(action, player_text, intent, reply, str(reply["my_line"]).strip_edges())
	if winner.is_empty():
		return {}
	var speech := "这局算你赢。下回再比。"
	if winner == "xiaomo":
		speech = "这局归我。下回再来。"
		if intent == "line":
			var verdict := local_verdict(player_text)
			speech = "这句没有「%s」字，这局归我。下回记得带上令字。" % keyword if verdict == "不含令字" else "这句已经用过了，这局归我。下回换一句。"
	var repaired := reply.duplicate(true)
	repaired["comment"] = speech
	repaired["prompt_next"] = ""
	return process_reply(action, player_text, intent_hint, repaired, true)


func _continue_reply(reply: Dictionary, my_line: String, verdict: String) -> Dictionary:
	return {"retry_line": false, "speech": _render_speech(reply, my_line, verdict), "finished": false}


func _finish_reply(reply: Dictionary, my_line: String, player_won: bool, reason: String) -> Dictionary:
	return {
		"retry_line": false,
		"speech": _render_speech(reply, my_line, ""),
		"finished": true,
		"player_won": player_won,
		"reason": reason,
	}


func _render_speech(reply: Dictionary, my_line: String, verdict: String) -> String:
	var comment := _strip_stage(str(reply["comment"]))
	var prompt_next := _strip_stage(str(reply["prompt_next"]))
	if not my_line.is_empty():
		comment = comment.replace(my_line, "").strip_edges()
		prompt_next = prompt_next.replace(my_line, "").strip_edges()
	if verdict == "合规" and _claims_missing_keyword(comment):
		comment = ""
	var recent_segments: Array[String] = []
	for turn in recent_turns:
		for field in ["comment", "prompt_next"]:
			var old := str(turn.get(field, ""))
			if not old.is_empty():
				recent_segments.append(old)
	comment = _unique_segment(comment, recent_segments)
	prompt_next = _unique_segment(prompt_next, recent_segments)
	recent_turns.append({"comment": comment, "prompt_next": prompt_next})
	if recent_turns.size() > 3:
		recent_turns.pop_front()
	var parts: Array[String] = []
	for part in [comment, my_line, prompt_next]:
		if not part.is_empty():
			parts.append(part)
	return " ".join(parts)


func _unique_segment(value: String, recent: Array[String]) -> String:
	var cleaned := value.strip_edges()
	if cleaned.is_empty() or cleaned.contains("倒还记得") or cleaned.contains("她"):
		return ""
	for old in recent:
		if cleaned.left(4) == old.left(4):
			return ""
	return cleaned


func _claims_missing_keyword(comment: String) -> bool:
	var clean := comment
	for mark in ["'", "\"", "‘", "’", "“", "”", "「", "」"]:
		clean = clean.replace(mark, "")
	for claim in ["没有令字", "不含令字", "没有%s" % keyword, "没%s" % keyword, "不含%s" % keyword]:
		if clean.contains(claim):
			return true
	return false


func _strip_stage(value: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("（[^（）]*）|\\([^()]*\\)")
	var clean := value.strip_edges()
	for _index in range(4):
		var next := pattern.sub(clean, "", true)
		if next == clean:
			break
		clean = next
	return clean.strip_edges()


func _accept_line(speaker: String, line: String) -> void:
	lines.append({"speaker": speaker, "line": line.strip_edges()})


func _has_source(source: String) -> bool:
	var start := source.find("《")
	var finish := source.find("》")
	return start > 0 and finish > start + 1


func _looks_like_line(text: String) -> bool:
	if text.contains("？") or text.contains("?"):
		return false
	for conversational in ["认输", "投降", "我不会", "想不出", "算了", "放弃", "接不上", "出处", "编的", "哪来的", "真的假的", "规则", "怎么玩", "怎么", "什么", "在哪", "是不是"]:
		if text.contains(conversational):
			return false
	var compact := _normalize_line(text)
	if compact.length() >= 4 and compact.length() <= 9:
		return true
	var clauses := text.replace(",", "，").split("，")
	return clauses.size() == 2 and _normalize_line(clauses[0]).length() >= 3 and _normalize_line(clauses[1]).length() >= 3


func _normalize_line(line: String) -> String:
	var clean := line.strip_edges()
	for mark in [" ", "\t", "\n", "，", "。", "！", "？", "；", "：", ",", ".", "!", "?", ";", ":", "“", "”", "‘", "’"]:
		clean = clean.replace(mark, "")
	return clean


func result_summary(player_won: bool, reason: String) -> String:
	var heading := "飞花令（令字：%s）" % keyword
	if reason == "caught_fabrication":
		return "%s，她编句被你抓包，认输了；你对了 %d 轮。" % [heading, player_rounds]
	if reason == "missing_source":
		return "%s，她拿不出诗句出处，认输了；你对了 %d 轮。" % [heading, player_rounds]
	if player_won:
		return "%s，你赢了，对了 %d 轮。" % [heading, player_rounds]
	return "%s，她赢了，你对了 %d 轮。" % [heading, player_rounds]
