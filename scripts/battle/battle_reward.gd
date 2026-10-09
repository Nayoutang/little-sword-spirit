extends Node2D

const CardFace = preload("res://scripts/ui/card_face.gd")
const RewardSkin = preload("res://scripts/ui/ink_ui_skin.gd")

var finishing := false
var removing := false
var reward_message := ""
var skip_button: Button
var removal_scroll: ScrollContainer

@onready var card_choices: HBoxContainer = $RewardUI/CardChoices
@onready var message_label: Label = $RewardUI/Message

func _ready() -> void:
	preload("res://scripts/ui/save_exit_button.gd").install(self, $RewardUI, Vector2(1330, 24))
	preload("res://scripts/ui/card_library.gd").install_deck_view(self, $RewardUI, Vector2(1600, 24))
	card_choices.hide()
	skip_button = Button.new()
	skip_button.text = "跳过选卡"
	skip_button.position = Vector2(710, 760)
	skip_button.size = Vector2(500, 60)
	$RewardUI.add_child(skip_button)
	RewardSkin.style_button(skip_button)
	skip_button.hide()
	skip_button.pressed.connect(_skip_choice)
	_refresh_status()
	message_label.text = "战斗结束。选择一张卡牌，或跳过。"
	if RunState.pending_act_bond_gain >= 0:
		if RunState.pending_act_bond_gain > 0:
			message_label.text = "这场战斗，你做到了答应她的事。选择一张卡牌，或跳过。"
		else:
			message_label.text = "这场战斗没能守住约定。选择一张卡牌，或跳过。"
	var saved := RunState.room_checkpoint("reward")
	if saved.get("removing", false):
		finishing = true
		reward_message = str(saved.get("reward_message", ""))
		_show_removal_choices()
	else:
		_show_card_choices()


func _show_card_choices() -> void:
	if finishing:
		return
	card_choices.show()
	skip_button.show()
	var candidates: Array[int] = []
	var saved := RunState.room_checkpoint("reward")
	if saved.has("cards"):
		candidates.assign(saved.cards)
	else:
		for card_type in CardDatabase.get_reward_card_ids(RunState.deck):
			candidates.append(card_type)
		candidates.shuffle()
		candidates.resize(card_choices.get_child_count())
	RunState.checkpoint("reward", {"cards": candidates})
	for index in range(card_choices.get_child_count()):
		var button := card_choices.get_child(index) as Button
		var card_type := candidates[index]
		button.text = ""
		button.tooltip_text = CardDatabase.get_battle_text(card_type)
		var face := CardFace.new()
		button.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.set_player_card(card_type)
		button.pressed.connect(_choose_card.bind(card_type))


func _choose_card(card_type: int) -> void:
	if finishing:
		return
	if not RunState.add_run_card(card_type):
		return
	_finish_reward("已将「%s」加入本局牌组" % CardDatabase.get_card_name(card_type))


func _finish_reward(message: String) -> void:
	if finishing:
		return
	finishing = true
	card_choices.hide()
	skip_button.hide()
	if RunState.pending_encounter == RunState.EncounterType.ELITE:
		reward_message = message
		_show_removal_choices()
		return
	_complete_reward(message)


func _skip_choice() -> void:
	if removing:
		removal_scroll.hide()
		skip_button.hide()
		removing = false
		_complete_reward(reward_message + "；跳过精英删牌")
	else:
		_finish_reward("跳过选卡")


func _show_removal_choices() -> void:
	removing = true
	RunState.checkpoint("reward", {"removing": true, "reward_message": reward_message})
	message_label.text = "精英额外奖励：移除一张牌，或跳过"
	removal_scroll = ScrollContainer.new()
	removal_scroll.position = Vector2(510, 400)
	removal_scroll.size = Vector2(900, 330)
	$RewardUI.add_child(removal_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	removal_scroll.add_child(list)
	for index in range(RunState.deck.size()):
		var button := Button.new()
		button.text = "移除第%d张：%s" % [index + 1, CardDatabase.get_reward_text(RunState.deck[index])]
		button.custom_minimum_size = Vector2(850, 65)
		list.add_child(button)
		RewardSkin.style_button(button)
		button.pressed.connect(_remove_card.bind(index))
	skip_button.text = "跳过删牌"
	skip_button.show()
	_refresh_status()


func _remove_card(index: int) -> void:
	if not removing:
		return
	removing = false
	var card_id := RunState.remove_run_card(index)
	removal_scroll.hide()
	skip_button.hide()
	_complete_reward(reward_message + "；精英奖励移除「%s」" % CardDatabase.get_card_name(card_id))


func _complete_reward(message: String) -> void:
	message_label.text = message
	RunState.record_run_fact("reward", "战后奖励：%s。领取后生命为 %d/%d，牌组共 %d 张。" % [
		message,
		RunState.player_hp,
		RunState.player_max_hp,
		RunState.deck.size(),
	])
	_refresh_status()
	RunState.checkpoint("settlement" if RunState.post_battle_scene == RunState.scene_path("settlement") else "map")
	await get_tree().create_timer(0.8).timeout
	RunState.navigate(RunState.post_battle_scene, self)


func _refresh_status() -> void:
	$RewardUI/Status.text = "生命：%d/%d" % [RunState.player_hp, RunState.player_max_hp]
