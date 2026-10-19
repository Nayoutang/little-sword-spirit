class_name OfflinePoetry
extends RefCounted

static var entries: Array = []
static var exact: Dictionary = {}
static var fragments: Dictionary = {}
static var by_character: Dictionary = {}
static var traditional: Dictionary = {}


static func load_library() -> void:
	if not entries.is_empty():
		return
	traditional = JSON.parse_string(FileAccess.get_file_as_string("res://data/poetry/traditional_map.json"))
	entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/poetry/couplets.json"))
	for entry: Dictionary in entries:
		var line := str(entry.line)
		exact[normalize(line)] = entry
		for clause in line.split("，"):
			fragments[normalize(clause)] = entry
		var seen := {}
		for character in normalize(line):
			if seen.has(character):
				continue
			seen[character] = true
			if not by_character.has(character):
				by_character[character] = []
			by_character[character].append(entry)


static func normalize(text: String) -> String:
	var result := ""
	for character in text:
		var value := str(traditional.get(character, character))
		if FeihualingGame.is_valid_keyword(value):
			result += value
	return result


static func keywords() -> Array[String]:
	load_library()
	var result: Array[String] = []
	for character in FeihualingGame.CHARACTERS:
		if by_character.get(character, []).size() >= 8:
			result.append(character)
	return result


static func find(text: String) -> Dictionary:
	load_library()
	return exact.get(normalize(text), {})


static func choose(game: FeihualingGame, pending: String = "") -> Dictionary:
	load_library()
	var candidates: Array = by_character.get(game.keyword, []).duplicate()
	candidates.shuffle()
	# Leave the eight sword verses for the player whenever another answer exists.
	for allow_intent in [false, true]:
		for entry: Dictionary in candidates:
			var line := str(entry.line)
			if game.has_line(line) or (not pending.is_empty() and normalize(line) == normalize(pending)):
				continue
			if not allow_intent and not CompanionCardDatabase.match_sword_intent(line).is_empty():
				continue
			if game.check_my_line(line).is_empty():
				return entry
	return {}


static func play(game: FeihualingGame, action: String, text: String) -> Dictionary:
	load_library()
	var clean := normalize(text)
	var normalized_keyword := normalize(game.keyword)
	game.keyword = normalized_keyword
	var intent := game.classify_input(text)
	var reply := {"intent": intent if intent != "unknown" else "chat", "player_line_valid": true,
		"player_line_source": "", "comment": "接得不错。", "my_line": "", "my_line_source": "",
		"prompt_next": "轮到你了，接完整一联。", "give_up": false}
	if action == "turn":
		if intent == "surrender":
			reply.comment = "再想想，我等你。再说一次认输，这局就归我了。" if game.surrender_count == 0 else "这局归我。歇一会儿，下回再比。"
			reply.prompt_next = ""
			return game.process_reply(action, text, intent, reply, true)
		if intent == "challenge":
			var previous := find(game.last_my_line)
			reply.player_line_source = str(previous.get("source", ""))
			reply.comment = "这句出自%s。查清楚了？该你接了。" % reply.player_line_source
			reply.prompt_next = ""
			return game.process_reply(action, text, intent, reply, true)
		var preflight := game.incomplete_preflight(text)
		if not preflight.is_empty():
			return preflight
		var entry: Dictionary = exact.get(clean, {})
		if entry.is_empty() and fragments.has(clean):
			entry = fragments[clean]
			var completed := str(entry.line)
			if completed.contains(game.keyword) and not game.has_line(completed):
				reply.my_line = completed
				reply.my_line_source = entry.source
				reply.comment = "另一半想不起来了？我替你补上，这轮算我拿下。"
				return game.process_reply(action, clean, "line", reply, true)
		if entry.is_empty():
			return {"speech": "这句暂未收录在诗卷里，换一联吧。本轮不计输赢。可输入“提示”查看一条可用诗句。", "finished": false}
		# Use canonical text for punctuation/traditional-character equivalence.
		text = str(entry.line)
		reply.player_line_source = entry.source
		if not text.contains(game.keyword) or game.has_line(text):
			reply.comment = "这句没带令字，这局归我。" if not text.contains(game.keyword) else "这句已经用过了，这局归我。"
			reply.prompt_next = ""
			return game.process_reply(action, text, "line", reply, true)
	var next := choose(game, text if action == "turn" else "")
	if next.is_empty():
		if action == "opening":
			return {"unsupported": true}
		reply.give_up = true
		reply.comment = "我接不上了，这局算你赢。下回再比。"
		reply.prompt_next = ""
	else:
		reply.my_line = next.line
		reply.my_line_source = next.source
		if action == "opening":
			reply.comment = "以「%s」为令，我先来。" % game.keyword
	return game.process_reply(action, text, "line" if action == "turn" else "", reply, true)
