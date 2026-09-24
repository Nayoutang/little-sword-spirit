extends Node2D

# 初遇：新存档第一次进入时播放的一段简短文字剧情。
# 锚句写死；她对玩家反应和名字的回应由 LLM 现场生成，失败时用手写台词顶上。
# 结束时写入玩家名字与第一条共同经历，不加羁绊。

const WAKE_TEXT := "你在一片陌生的山林里醒来。天色将暗，风里有松针和铁锈的味道。\n不远处的断碑旁，斜插着一把积满灰的剑。"

const FIRST_CHOICES := [
	{"id": "pull", "text": "伸手拔剑", "line": "……手脏死了，谁准你碰我的？", "memory": "你伸手就去拔她"},
	{"id": "wipe", "text": "先把剑身上的灰擦掉", "line": "多、多管闲事……我又没让你擦。", "memory": "你先替她擦掉了剑身上的灰"},
	{"id": "leave", "text": "绕开它，往山下走", "line": "喂！你——你就这么走了？", "memory": "你本想绕开她往山下走，她忍不住叫住了你"},
]

const REACTIONS := [
	{"text": "剑……会说话？", "fallback": "少见多怪。剑灵会说话，有什么稀奇的。", "memory": "你的第一反应是「剑……会说话？」"},
	{"text": "抱歉，吵醒你了", "fallback": "……哼，还算有点礼貌。", "memory": "你跟她道歉，说吵醒她了"},
	{"text": "那我放回去？", "fallback": "你敢！……咳，我是说，随便你。", "memory": "你逗她说要把她放回去"},
]

const ASK_NAME_LINE := "……你叫什么？"
const NAME_LINE := "……叫我小墨就行。以前也有人这么叫——算了，就叫小墨。"
const ENDING_LINE := "喂，天要黑了。你总得找个地方落脚吧……带上我。不是我想跟着你，是这荒山野岭的，你一个人肯定活不下去。"
const ENDING_TEXT := "山脚下有一间废弃的小屋。从那天起，它成了你们的家。"
const DEFAULT_NAME := "持剑人"

var first_choice: Dictionary = {}
var reaction: Dictionary = {}
var player_name := DEFAULT_NAME
var http_request: HTTPRequest
var pending_callback: Callable
var pending_fallback := ""

var background: ColorRect
var home_image: TextureRect
var story_label: RichTextLabel
var choices_box: VBoxContainer
var name_row: HBoxContainer
var name_input: LineEdit
var continue_button: Button
var skip_button: Button


func _ready() -> void:
	_build_ui()
	_show_wake()


func _build_ui() -> void:
	background = ColorRect.new()
	background.color = Color(0.07, 0.09, 0.1)
	background.size = Vector2(1920, 1080)
	add_child(background)
	var layer := CanvasLayer.new()
	add_child(layer)

	home_image = TextureRect.new()
	home_image.position = Vector2(0, 0)
	home_image.size = Vector2(1920, 1080)
	home_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	home_image.modulate = Color(1, 1, 1, 0.35)
	home_image.visible = false
	if ResourceLoader.exists("res://art/home.png"):
		home_image.texture = load("res://art/home.png")
	layer.add_child(home_image)

	story_label = RichTextLabel.new()
	story_label.position = Vector2(360, 220)
	story_label.size = Vector2(1200, 360)
	story_label.bbcode_enabled = true
	story_label.add_theme_font_size_override("normal_font_size", 30)
	layer.add_child(story_label)

	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(560, 620)
	choices_box.size = Vector2(800, 320)
	choices_box.add_theme_constant_override("separation", 18)
	layer.add_child(choices_box)

	name_row = HBoxContainer.new()
	name_row.position = Vector2(560, 640)
	name_row.size = Vector2(800, 70)
	name_row.add_theme_constant_override("separation", 16)
	name_input = LineEdit.new()
	name_input.custom_minimum_size = Vector2(560, 64)
	name_input.max_length = 12
	name_input.placeholder_text = "输入你的名字（留空则为「持剑人」）"
	name_input.add_theme_font_size_override("font_size", 26)
	name_input.text_submitted.connect(func(_text): _submit_name())
	name_row.add_child(name_input)
	var name_button := Button.new()
	name_button.text = "告诉她"
	name_button.custom_minimum_size = Vector2(200, 64)
	name_button.pressed.connect(_submit_name)
	name_row.add_child(name_button)
	name_row.visible = false
	layer.add_child(name_row)

	continue_button = Button.new()
	continue_button.position = Vector2(810, 660)
	continue_button.size = Vector2(300, 70)
	continue_button.text = "继续"
	continue_button.visible = false
	layer.add_child(continue_button)

	skip_button = Button.new()
	skip_button.position = Vector2(1720, 40)
	skip_button.size = Vector2(160, 56)
	skip_button.text = "跳过"
	skip_button.pressed.connect(_skip)
	layer.add_child(skip_button)


# ---------------------------------------------------------------- 流程
func _show_wake() -> void:
	_set_story("[i]%s[/i]" % WAKE_TEXT)
	var options: Array[String] = []
	for choice in FIRST_CHOICES:
		options.append(str(choice["text"]))
	_show_choices(options, _on_first_choice)


func _on_first_choice(index: int) -> void:
	first_choice = FIRST_CHOICES[index]
	_set_story("[i]%s[/i]\n\n小墨：%s" % [str(first_choice["text"]), str(first_choice["line"])])
	var options: Array[String] = []
	for item in REACTIONS:
		options.append(str(item["text"]))
	_show_choices(options, _on_reaction)


func _on_reaction(index: int) -> void:
	reaction = REACTIONS[index]
	var cue := "持剑人刚才%s。你对他说的第一句话是「%s」。他听了之后说：「%s」。请你接一两句话回应他。" % [
		str(first_choice["memory"]),
		str(first_choice["line"]),
		str(reaction["text"]),
	]
	_set_story("你：%s\n\n小墨……" % str(reaction["text"]))
	_ask_llm(cue, str(reaction["fallback"]), func(line: String):
		_set_story("你：%s\n\n小墨：%s" % [str(reaction["text"]), line])
		_show_continue(_show_ask_name))


func _show_ask_name() -> void:
	_set_story("小墨：%s" % ASK_NAME_LINE)
	_clear_choices()
	name_input.text = ""
	name_row.visible = true
	name_input.grab_focus()


func _submit_name() -> void:
	if not name_row.visible:
		return
	var clean := name_input.text.replace("\n", "").strip_edges().left(12)
	player_name = clean if not clean.is_empty() else DEFAULT_NAME
	name_row.visible = false
	var cue := "你刚问了持剑人的名字，他说他叫「%s」。请你就着这个名字嘴硬地回一句（只说一句，不要说出你自己的名字）。" % player_name
	_set_story("你：我叫%s。\n\n小墨……" % player_name)
	_ask_llm(cue, "%s……哼，名字倒是挺普通的。" % player_name, func(line: String):
		_set_story("你：我叫%s。\n\n小墨：%s\n\n小墨：%s" % [player_name, line, NAME_LINE])
		_show_continue(_show_ending))


func _show_ending() -> void:
	_set_story("小墨：%s" % ENDING_LINE)
	_show_continue(func():
		home_image.visible = true
		_set_story("[i]%s[/i]" % ENDING_TEXT)
		_show_continue(_finish, "回家"))


func _finish() -> void:
	var summary := "你们初遇那天，%s；她的第一句话是「%s」，%s。你告诉她你叫%s。" % [
		str(first_choice.get("memory", "你在山林的断碑旁捡到了她")),
		str(first_choice.get("line", "")),
		str(reaction.get("memory", "")),
		player_name,
	]
	RunState.complete_intro(player_name, summary)
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _skip() -> void:
	if http_request != null:
		http_request.cancel_request()
	RunState.complete_intro(
		player_name if player_name != DEFAULT_NAME else DEFAULT_NAME,
		"你们初遇那天，你在山林的断碑旁捡到了她，把她带回了山脚的小屋。"
	)
	get_tree().change_scene_to_file("res://scenes/home.tscn")


# ---------------------------------------------------------------- UI 工具
func _set_story(text: String) -> void:
	story_label.text = text


func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()
	continue_button.visible = false


func _show_choices(options: Array[String], callback: Callable) -> void:
	_clear_choices()
	for index in range(options.size()):
		var button := Button.new()
		button.text = options[index]
		button.custom_minimum_size = Vector2(800, 72)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(func():
			_clear_choices()
			callback.call(index))
		choices_box.add_child(button)


func _show_continue(callback: Callable, label: String = "继续") -> void:
	_clear_choices()
	continue_button.text = label
	continue_button.visible = true
	for connection in continue_button.pressed.get_connections():
		continue_button.pressed.disconnect(connection["callable"])
	continue_button.pressed.connect(func():
		continue_button.visible = false
		callback.call(), CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- LLM
func _ask_llm(cue: String, fallback: String, callback: Callable) -> void:
	_clear_choices()
	pending_callback = callback
	pending_fallback = fallback
	var api_key := LLMConfig.get_api_key()
	if LLMConfig.API_URL.is_empty() or LLMConfig.MODEL_NAME.is_empty() or api_key.is_empty():
		_deliver("")
		return
	var system_prompt := LLMConfig.load_system_prompt()
	system_prompt += "\n\n" + RunState.get_relationship_prompt()
	system_prompt += "\n\n这是你们的初遇：你是一把插在山林断碑旁、积了很久灰的古剑的剑灵，刚被这个陌生人惊醒。你们彼此还完全不认识。只写你说出口的话，一两句，不要括号动作、旁白或替他说话。"
	if http_request == null:
		http_request = HTTPRequest.new()
		http_request.timeout = 8.0
		add_child(http_request)
		http_request.request_completed.connect(_on_request_completed)
	var error := http_request.request(
		LLMConfig.API_URL,
		PackedStringArray(["Content-Type: application/json", "Authorization: Bearer %s" % api_key]),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"model": LLMConfig.MODEL_NAME,
			"messages": [
				{"role": "system", "content": system_prompt},
				{"role": "user", "content": "【旁白】" + cue},
			],
			"max_tokens": 100,
		})
	)
	if error != OK:
		_deliver("")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var reply := ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var api_choices: Variant = parsed.get("choices", [])
			if api_choices is Array and not api_choices.is_empty() and api_choices[0] is Dictionary:
				var message: Variant = api_choices[0].get("message", {})
				if message is Dictionary:
					reply = str(message.get("content", ""))
	_deliver(reply)


func _deliver(reply: String) -> void:
	var pattern := RegEx.new()
	pattern.compile("（[^（）]*）|\\([^()]*\\)")
	var clean := pattern.sub(reply, "", true).strip_edges()
	if clean.begins_with("小墨："):
		clean = clean.trim_prefix("小墨：").strip_edges()
	if clean.is_empty():
		clean = pending_fallback
	if pending_callback.is_valid():
		pending_callback.call(clean)
