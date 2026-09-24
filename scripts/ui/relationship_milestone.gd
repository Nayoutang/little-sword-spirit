extends Node2D

const MILESTONES := {
	1: {
		"title": "关系突破　相识",
		"line": "小墨难得没有移开视线。\n“如果哪天我很麻烦……你也不会把我丢下？”",
		"choices": [
			"认真看着她：不会。你不是麻烦。",
			"笑她：原来你也会害怕？",
			"别想这些了，赶紧回去。",
		],
		"correct": 0,
	},
	2: {
		"title": "关系突破　交心",
		"line": "她把声音压得很低。\n“有些事……就算是你，我也不知道该不该说。”",
		"choices": [
			"不逼问她：等你想说的时候，我会听。",
			"追问她到底隐瞒了什么。",
			"故意岔开话题，当作没听见。",
		],
		"correct": 0,
	},
	3: {
		"title": "关系突破　生死之交",
		"line": "她握紧了剑柄，却第一次没有嘴硬。\n“无论以后去哪里……都带上我，好不好？”",
		"choices": [
			"向她伸手：我们一直一起走。",
			"逗她先求我几句再说。",
			"以后的事以后再谈。",
		],
		"correct": 0,
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
		get_tree().change_scene_to_file("res://scenes/home.tscn")
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
	RunState.resolve_bond_milestone(success)
	for child in choices.get_children():
		(child as Button).disabled = true
	if success:
		result_label.text = "她怔了一下，别过脸去。\n“……说好了。你可不许反悔。”\n关系阶段突破：%s" % target_name
	else:
		result_label.text = "她的神情重新绷紧。\n“算了，当我没问。”\n本次突破暂缓，羁绊不会减少。"
	result_label.show()
	continue_button.show()


func _return_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")
