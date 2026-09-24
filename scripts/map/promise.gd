extends Node2D

# 出门前：只有上一趟发生了让小墨在意的事，她才会拉住你提一个要求。
# 玩家的选择是"怎么回应她"，而不是从菜单里挑条款。

const RULE_TEXT := {
	"protect": "她的要求：这一趟血不掉到最大值的 1/4 以下",
	"finish": "她的要求：这一趟平安打完 Boss",
}
const REQUIREMENT_TEXT := {
	"protect": "照顾好自己，别再让血掉到四分之一以下",
	"finish": "平安走完这一趟，别再倒下",
}
const FALLBACK_LINES := {
	"reckless": "……上回你的血都掉到那么低了，还往前冲。这趟给我顾好自己。",
	"fell": "上次你倒下的时候……算了。这趟你得给我平安走回来。",
	"broken": "上回答应我的事，你可没做到。这次……你再说一遍？",
}

var concern: Dictionary = {}
var http_request: HTTPRequest

@onready var title_label: Label = $PromiseUI/Title
@onready var line_label: Label = $PromiseUI/Line
@onready var sincere_button: Button = $PromiseUI/Choices/Protect
@onready var perfunctory_button: Button = $PromiseUI/Choices/Finish
@onready var ignore_button: Button = $PromiseUI/Choices/None


func _ready() -> void:
	concern = RunState.get_pending_concern()
	if concern.is_empty():
		RunState.resolve_departure_concern("")
		get_tree().change_scene_to_file("res://scenes/map.tscn")
		return
	var promise_type := str(concern.get("promise", "protect"))
	title_label.text = "出门前"
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.offset_bottom = line_label.offset_top + 110.0
	line_label.text = "小墨拉住了你的衣袖……"
	sincere_button.text = "认真答应她\n%s" % RULE_TEXT.get(promise_type, "")
	perfunctory_button.text = "随口应付一句"
	ignore_button.text = "不接话，直接出发"
	sincere_button.pressed.connect(_choose.bind("sincere"))
	perfunctory_button.pressed.connect(_choose.bind("perfunctory"))
	ignore_button.pressed.connect(_choose.bind("ignore"))
	_set_choices_enabled(false)
	_request_line()


func _set_choices_enabled(enabled: bool) -> void:
	for button in [sincere_button, perfunctory_button, ignore_button]:
		button.disabled = not enabled


func _choose(response: String) -> void:
	_set_choices_enabled(false)
	RunState.resolve_departure_concern(response)
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _request_line() -> void:
	var api_key := LLMConfig.get_api_key()
	if LLMConfig.API_URL.is_empty() or LLMConfig.MODEL_NAME.is_empty() or api_key.is_empty():
		_show_line("")
		return
	var promise_type := str(concern.get("promise", "protect"))
	var system_prompt := LLMConfig.load_system_prompt()
	system_prompt += "\n\n" + RunState.get_relationship_prompt()
	system_prompt += "\n\n" + RunState.get_shared_history_prompt()
	var cue := """【旁白】持剑人正要出门。让你放不下的事：%s。
你想拉住他，要他这一趟%s。
只说一两句你说出口的话：要点到那件具体的事，用你此刻对他的关系态度说（可以嘴硬、可以别扭），最后把要求提出来。
不要括号动作、不要旁白、不要替他回答、不要列选项。""" % [
		str(concern.get("fact", "")),
		REQUIREMENT_TEXT.get(promise_type, "照顾好自己"),
	]
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
				{"role": "user", "content": cue},
			],
			"max_tokens": 120,
		})
	)
	if error != OK:
		_show_line("")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var reply := ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			var choices: Variant = parsed.get("choices", [])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				var message: Variant = choices[0].get("message", {})
				if message is Dictionary:
					reply = str(message.get("content", ""))
	_show_line(reply)


func _show_line(reply: String) -> void:
	var pattern := RegEx.new()
	pattern.compile("（[^（）]*）|\\([^()]*\\)")
	var clean := pattern.sub(reply, "", true).strip_edges()
	if clean.is_empty():
		clean = str(FALLBACK_LINES.get(str(concern.get("kind", "")), FALLBACK_LINES["reckless"]))
	line_label.text = "小墨：%s" % clean
	_set_choices_enabled(true)
