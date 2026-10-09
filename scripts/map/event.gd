extends Node2D

const CardFace = preload("res://scripts/ui/card_face.gd")
const RewardSkin = preload("res://scripts/ui/ink_ui_skin.gd")

# 事件奖励数值集中在这里。
var heal_amount := BalanceConfig.EVENT_HEAL_AMOUNT
var max_hp_increase := BalanceConfig.EVENT_MAX_HP_INCREASE
var card_choice_count := 3
var finishing := false
@onready var skip_button: Button = $EventUI/SkipCard

@onready var hp_label: Label = $EventUI/HPLabel
@onready var message_label: Label = $EventUI/Message
@onready var main_choices: VBoxContainer = $EventUI/MainChoices
@onready var card_choices: HBoxContainer = $EventUI/CardChoices

func _ready() -> void:
	preload("res://scripts/ui/save_exit_button.gd").install(self, $EventUI, Vector2(1330, 24))
	preload("res://scripts/ui/card_library.gd").install_deck_view(self, $EventUI, Vector2(1600, 24))
	$EventUI/MainChoices/Heal.pressed.connect(_choose_heal)
	$EventUI/MainChoices/MaxHP.pressed.connect(_choose_max_hp)
	$EventUI/MainChoices/Card.pressed.connect(_show_card_choices)
	card_choices.hide()
	skip_button.pressed.connect(_finish_event.bind("跳过选卡"))
	_refresh_hp()
	if RunState.room_checkpoint("event").get("card_choices", false):
		_show_card_choices()
	elif RunState.pending_event == RunState.EventType.UNKNOWN:
		_resolve_unknown_event()


func _resolve_unknown_event() -> void:
	main_choices.hide()
	message_label.text = "问号事件正在揭晓……"
	var outcome := randi_range(0, 4)
	match outcome:
		0:
			_choose_heal()
		1:
			_choose_max_hp()
		2:
			_show_card_choices()
		3:
			RunState.adjust_player_hp(-20, 1)
			_finish_event("遭遇陷阱：失去 20 HP")
		4:
			_lose_random_card()


func _lose_random_card() -> void:
	if finishing:
		return
	if RunState.deck.is_empty():
		_finish_event("牌组为空，没有卡牌可以失去")
		return
	var removed_index := randi_range(0, RunState.deck.size() - 1)
	var removed_type := RunState.remove_run_card(removed_index)
	_finish_event("失去一张「%s」" % CardDatabase.get_card_name(removed_type))


func _choose_heal() -> void:
	if finishing:
		return
	var restored := RunState.adjust_player_hp(heal_amount)
	_finish_event("恢复了 %d 点 HP" % restored)


func _choose_max_hp() -> void:
	if finishing:
		return
	RunState.increase_max_hp(max_hp_increase)
	_finish_event("最大 HP 与当前 HP 都提升了 %d" % max_hp_increase)


func _show_card_choices() -> void:
	main_choices.hide()
	card_choices.show()
	skip_button.show()
	message_label.text = "选择一张加入牌组"
	var candidates: Array[int] = []
	var saved := RunState.room_checkpoint("event")
	if saved.has("cards"):
		candidates.assign(saved.cards)
	else:
		for card_type in CardDatabase.get_reward_card_ids(RunState.deck):
			candidates.append(card_type)
		candidates.shuffle()
		candidates.resize(card_choices.get_child_count())
	RunState.checkpoint("event", {"card_choices": true, "cards": candidates})
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
	_finish_event("已将「%s」加入牌组" % CardDatabase.get_card_name(card_type))


func _finish_event(message: String) -> void:
	if finishing:
		return
	finishing = true
	main_choices.hide()
	card_choices.hide()
	skip_button.hide()
	message_label.text = message
	var event_name := "问号事件" if RunState.pending_event == RunState.EventType.UNKNOWN else "宝箱事件"
	RunState.record_run_fact("event", "%s：%s。事件后生命为 %d/%d，牌组共 %d 张。" % [
		event_name,
		message,
		RunState.player_hp,
		RunState.player_max_hp,
		RunState.deck.size(),
	])
	_refresh_hp()
	RunState.checkpoint("map")
	await get_tree().create_timer(1.0).timeout
	RunState.navigate("map", self)


func _refresh_hp() -> void:
	hp_label.text = "HP: %d/%d" % [RunState.player_hp, RunState.player_max_hp]
