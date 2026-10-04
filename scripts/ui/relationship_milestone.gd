extends Node2D

const MILESTONES := {
	1: {
		"title": "关系突破　相识",
		"line": "收拾行囊时，小墨把自己的剑鞘放回你手边，又像是怕你没看见。\n“要是哪天我变得很麻烦，你会不会把我丢下？”",
		"choices": [
			"认真看着她：不会。你不是麻烦。",
			"笑她：原来你也会害怕？",
			"别想这些了，赶紧回去。",
		],
		"correct": 0,
		"success": "她握住剑鞘，指尖慢慢松开。\n小墨：这话我记下了。以后可不许装作没说过。",
		"failures": ["", "她扯了扯嘴角，把剑鞘收回身后。\n小墨：当我随口问的。", "她低头扣好行囊，与你隔开半步。\n小墨：嗯。那就先赶路。"],
	},
	2: {
		"title": "关系突破　交心",
		"line": "夜里她几次开口又停下，最后把茶盏轻轻推向你。\n“有件事我一直没跟你说。不是不信你，是我自己还没想好。”",
		"choices": [
			"不逼问她：等你想说的时候，我会听。",
			"追问她到底隐瞒了什么。",
			"故意岔开话题，当作没听见。",
		],
		"correct": 0,
		"success": "她捧住已经凉了的茶盏，声音终于稳下来。\n小墨：等我想明白，会第一个告诉你。你先别走开。",
		"failures": ["", "她的手停在茶盏边，没有再往下说。\n小墨：现在问，我也答不出来。", "她顺着你的话题笑了一下，笑意却很快淡了。\n小墨：好，就当我没提。"],
	},
	3: {
		"title": "关系突破　生死之交",
		"line": "临行前她把剑递给你，握着剑柄的手迟迟没有松开。\n“以后不管去哪儿，都带上我。好不好？”",
		"choices": [
			"向她伸手：我们一直一起走。",
			"逗她先求我几句再说。",
			"以后的事以后再谈。",
		],
		"correct": 0,
		"success": "她把剑交到你手里，自己也跟着迈出门槛。\n小墨：说定了。这回换我看着你。",
		"failures": ["", "她松了手，自己先走到门外。\n小墨：这种时候还逗我，你真有本事。", "她把剑收回鞘里，沉默了片刻。\n小墨：好。我等你想清楚再说。"],
	},
}

@onready var title_label: Label = $MilestoneUI/Title
@onready var line_label: Label = $MilestoneUI/Line
@onready var choices: VBoxContainer = $MilestoneUI/Choices
@onready var result_label: Label = $MilestoneUI/Result
@onready var continue_button: Button = $MilestoneUI/Continue

var milestone: Dictionary
# 按钮位置 -> 原始选项下标；每次打乱，避免正确答案总在第一个。
var choice_order: Array[int] = []


func _ready() -> void:
	if not RunState.has_pending_bond_milestone():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/home.tscn")
		return
	milestone = MILESTONES.get(RunState.pending_bond_stage, MILESTONES[1])
	title_label.text = milestone["title"]
	line_label.text = milestone["line"]
	result_label.hide()
	continue_button.hide()
	continue_button.pressed.connect(_return_home)
	for index in range(choices.get_child_count()):
		choice_order.append(index)
	choice_order.shuffle()
	for slot in range(choices.get_child_count()):
		var button := choices.get_child(slot) as Button
		var original_index := choice_order[slot]
		button.text = milestone["choices"][original_index]
		button.pressed.connect(_choose.bind(original_index))


func _choose(index: int) -> void:
	var success := index == int(milestone["correct"])
	var target_name := RunState.get_pending_bond_stage_name()
	var response := str(milestone["success"]) if success else str(milestone["failures"][index])
	RunState.resolve_bond_milestone(success)
	for child in choices.get_children():
		(child as Button).disabled = true
	if success:
		result_label.text = "%s\n关系阶段突破：%s" % [response, target_name]
	else:
		result_label.text = "%s\n本次突破暂缓，羁绊不会减少。" % response
	RunState.record_spoken_line(response.get_slice("小墨：", 1).get_slice("\n", 0))
	result_label.show()
	continue_button.show()


func _return_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")
