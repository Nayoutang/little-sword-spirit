extends Node2D

const ADVENTURES := [
	{
		"title": "雨亭偶憩",
		"story": "山雨骤至，你与小墨躲进一座废弃凉亭。你刚坐下，便听见檐角漏雨；她把剑鞘横在两人之间，挡住落向你的水珠。",
		"dialogue": "小墨：袖口都湿透了还站在风里？坐过来。别误会，我只是不想一路听你咳嗽。",
		"choices": [
			{"text": "安静陪她听一会儿雨", "result": "你留在剑鞘挡出的那片干燥里。雨声渐缓，她也没有催你起身。", "reply": "雨还没停。再坐一会儿，也没什么。", "bond": 2, "heal": 0},
			{"text": "把干燥的位置让给她", "result": "你挪到漏雨的檐边。她皱着眉把你拉回去，拧干你的衣袖，又替你拢紧外衣。", "reply": "就这么点地方，非要让来让去？过来，别再淋了。", "bond": 1, "heal": 10},
		],
	},
	{
		"title": "无名剑痕",
		"story": "断崖石壁上留着一道古老剑痕。小墨停了很久，指尖沿着剑意的余韵轻轻划过。",
		"dialogue": "小墨：这一剑到末尾忽然偏了。不是犹豫，是手腕撑不住了……你别只看剑痕有多深。",
		"choices": [
			{"text": "不追问，只陪她站着", "result": "你没有追问她为何看得这样仔细。她收回手，与你一同站到暮色落下。", "reply": "你倒是难得安静。这样也好。", "bond": 2, "heal": 0},
			{"text": "请她教你辨认这道剑意", "result": "她握住你的手腕，带你顺着剑痕走了一遍；你终于看出末尾那处细微的颤动。", "reply": "手腕抬半寸。对，就在那里……记住这种勉强出剑的感觉。", "bond": 1, "heal": 8},
		],
	},
	{
		"title": "迷路的灯灵",
		"story": "一团微弱灯火在林间打转。小墨说它只是低阶灵物，却还是停下脚步替它寻找归途。",
		"dialogue": "小墨：它一直朝同一棵树绕圈，山祠该在那边。看什么？我只是嫌它挡路。",
		"choices": [
			{"text": "和她一起护送灯灵", "result": "你们沿着湿草走到山祠。灯灵归位前洒下一片暖光，她伸手替你挡了挡刺眼的光。", "reply": "跟紧些。林子里不止它一个会迷路。", "bond": 2, "heal": 6},
			{"text": "相信她，让她独自引路", "result": "你在原地守着岔路。她很快带灯灵回来，暖光落在你肩上，她的脚步也轻快了些。", "reply": "我说了能找到。你还真乖乖在这里等啊。", "bond": 1, "heal": 12},
		],
	},
	{
		"title": "残桥夜渡",
		"story": "入夜后，山涧上的木桥只剩半边。你试着踩上去，桥板便发出一声脆响。小墨先一步把剑横在断口上。",
		"dialogue": "小墨：停。你连下一块木板在哪儿都没看清，就想往前走？我先试。",
		"choices": [
			{"text": "等她探稳路，再并肩过桥", "result": "你按她指出的落脚处慢慢走过。到对岸时，她仍握着你的袖角。", "reply": "脚下看路。我只是怕你把桥踩塌，连累我回不了家。", "bond": 2, "heal": 0},
			{"text": "请她扶你过桥", "result": "你坦白手臂有些发酸。她扶稳你越过断口，到了对岸才松手，顺势替你揉开僵硬的肩。", "reply": "早说你撑不住。下次这种事，别等我问。", "bond": 1, "heal": 8},
		],
	},
	{
		"title": "旧驿微火",
		"story": "废弃驿站的炉膛还埋着一点火星。你添上枯枝，火光照出墙上许多早已褪色的行路刻痕。",
		"dialogue": "小墨：这些刻痕是过路人留的。有人写了归期，却没写后来是否归来。你……别盯着那一行看。",
		"choices": [
			{"text": "添一根柴，陪她等火旺起来", "result": "你把枯枝放进炉膛。她坐到你身边，指给你看另一行写着“平安到家”的旧字。", "reply": "看这句就够了。前面那句，没必要替别人担心到天亮。", "bond": 2, "heal": 0},
			{"text": "先检查门窗，让她在火边歇息", "result": "你挡好漏风的窗，她把烤暖的水递给你；你们各自歇了一阵才重新上路。", "reply": "忙完就坐下。热水是顺手烤的，别让我说第二遍。", "bond": 1, "heal": 10},
		],
	},
]

var current_adventure: Dictionary
var resolved := false
var pending_choice: Dictionary = {}
var pending_effect_text := ""

@onready var title_label: Label = $AdventureUI/Title
@onready var bond_label: Label = $AdventureUI/Bond
@onready var story_label: Label = $AdventureUI/Story
@onready var dialogue_label: Label = $AdventureUI/Dialogue
@onready var choices: VBoxContainer = $AdventureUI/Choices
@onready var result_label: Label = $AdventureUI/Result
@onready var continue_button: Button = $AdventureUI/Continue
@onready var http_request: HTTPRequest = $HTTPRequest


func _ready() -> void:
	current_adventure = ADVENTURES[randi_range(0, ADVENTURES.size() - 1)]
	title_label.text = "奇遇 · %s" % current_adventure["title"]
	story_label.text = current_adventure["story"]
	dialogue_label.text = current_adventure["dialogue"]
	result_label.hide()
	continue_button.hide()
	continue_button.pressed.connect(_return_to_map)
	http_request.request_completed.connect(_on_request_completed)
	for index in range(choices.get_child_count()):
		var button := choices.get_child(index) as Button
		var choice: Dictionary = current_adventure["choices"][index]
		button.text = choice["text"]
		button.pressed.connect(_resolve_choice.bind(choice))
	_refresh_bond()


func _resolve_choice(choice: Dictionary) -> void:
	if resolved:
		return
	resolved = true
	var old_hp := RunState.player_hp
	var heal := int(choice.get("heal", 0))
	if heal > 0:
		RunState.player_hp = mini(RunState.player_hp + heal, RunState.player_max_hp)
	var bond_gain := int(choice.get("bond", 0))
	RunState.add_bond(bond_gain)
	RunState.record_moment("奇遇「%s」里，你选择了「%s」：%s" % [
		str(current_adventure["title"]), str(choice["text"]), str(choice["result"]),
	], 2)
	pending_choice = choice
	choices.hide()
	var healed := RunState.player_hp - old_hp
	pending_effect_text = "羁绊 +%d" % bond_gain
	if healed > 0:
		pending_effect_text += "，恢复 %d HP" % healed
	RunState.record_run_fact("adventure", "奇遇「%s」：玩家选择“%s”；确定结果为“%s”；实际效果：%s。" % [
		str(current_adventure["title"]),
		str(choice["text"]),
		str(choice["result"]),
		pending_effect_text,
	])
	result_label.text = "小墨正在斟酌如何回应……\n\n%s" % pending_effect_text
	result_label.show()
	_refresh_bond()
	_request_llm_response()


func _request_llm_response() -> void:
	var api_key := LLMConfig.get_api_key()
	if LLMConfig.API_URL.is_empty() or LLMConfig.MODEL_NAME.is_empty() or api_key.is_empty():
		_show_fallback_response()
		return
	var system_prompt := LLMConfig.load_system_prompt()
	system_prompt += "\n\n" + RunState.get_relationship_prompt()
	system_prompt += "\n\n" + RunState.get_shared_history_prompt()
	system_prompt += "\n\n" + RunState.get_variety_prompt()
	system_prompt += """

你正在演绎一次游戏内奇遇。奇遇的数值结果已由游戏本地结算，你无权改变奖励、生命、羁绊、卡牌或剧情事实。
只输出一个JSON对象，不要Markdown代码块，不要补充说明：
{"reply":"小墨的一至两句台词","narration":"一句简短的动作或氛围描写","emotion":"neutral|soft|shy|worried|angry"}
台词与描写不得声称给予任何未提供的奖励。"""
	var user_context := """奇遇：%s
场景：%s
小墨先前说：%s
玩家选择：%s
已经锁定的叙事结果：%s
已经由本地结算的效果：%s
请根据这些事实自然演绎后续反应。""" % [
		current_adventure["title"],
		current_adventure["story"],
		current_adventure["dialogue"],
		pending_choice["text"],
		pending_choice["result"],
		pending_effect_text,
	]
	var payload := {
		"model": LLMConfig.MODEL_NAME,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_context},
		],
		"response_format": {"type": "json_object"},
		"temperature": 1.1,
		"frequency_penalty": 0.4,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	var error := http_request.request(
		LLMConfig.API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_show_fallback_response()


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_show_fallback_response()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_show_fallback_response()
		return
	var api_choices: Variant = parsed.get("choices", [])
	if not api_choices is Array or api_choices.is_empty() or not api_choices[0] is Dictionary:
		_show_fallback_response()
		return
	var message: Variant = api_choices[0].get("message", {})
	if not message is Dictionary:
		_show_fallback_response()
		return
	var generated := _parse_generated_response(str(message.get("content", "")))
	if generated.is_empty():
		_show_fallback_response()
		return
	_show_generated_response(str(generated["narration"]), str(generated["reply"]))


func _parse_generated_response(content: String) -> Dictionary:
	var cleaned := content.strip_edges()
	if cleaned.begins_with("```json"):
		cleaned = cleaned.trim_prefix("```json").trim_suffix("```").strip_edges()
	elif cleaned.begins_with("```"):
		cleaned = cleaned.trim_prefix("```").trim_suffix("```").strip_edges()
	var parsed: Variant = JSON.parse_string(cleaned)
	if not parsed is Dictionary:
		return {}
	var reply := str(parsed.get("reply", "")).strip_edges()
	var narration := str(parsed.get("narration", "")).strip_edges()
	if reply.is_empty() or narration.is_empty():
		return {}
	return {"reply": reply, "narration": narration}


func _show_generated_response(narration: String, reply: String) -> void:
	RunState.record_spoken_line(reply)
	result_label.text = "%s\n\n小墨：%s\n\n%s" % [narration, reply, pending_effect_text]
	continue_button.show()


func _show_fallback_response() -> void:
	result_label.text = "%s\n\n%s\n\n%s" % [
		pending_choice.get("result", "你们继续向前。"),
		"小墨：%s" % pending_choice.get("reply", "走吧。"),
		pending_effect_text,
	]
	RunState.record_spoken_line(str(pending_choice.get("reply", "走吧。")))
	continue_button.show()


func _refresh_bond() -> void:
	bond_label.text = "HP: %d/%d　羁绊: %d/100　%s" % [
		RunState.player_hp,
		RunState.player_max_hp,
		RunState.bond_value,
		RunState.get_bond_stage_name(),
	]


func _return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map.tscn")
