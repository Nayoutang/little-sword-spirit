extends Node2D

# 事件奖励数值集中在这里。
var heal_amount := BalanceConfig.EVENT_HEAL_AMOUNT
var max_hp_increase := BalanceConfig.EVENT_MAX_HP_INCREASE
var card_choice_count := 3

@onready var hp_label: Label = $EventUI/HPLabel
@onready var message_label: Label = $EventUI/Message
@onready var main_choices: VBoxContainer = $EventUI/MainChoices
@onready var card_choices: HBoxContainer = $EventUI/CardChoices

func _ready() -> void:
	$EventUI/MainChoices/Heal.pressed.connect(_choose_heal)
	$EventUI/MainChoices/MaxHP.pressed.connect(_choose_max_hp)
	$EventUI/MainChoices/Card.pressed.connect(_show_card_choices)
	card_choices.hide()
	_refresh_hp()
	if RunState.pending_event == RunState.EventType.UNKNOWN:
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
			RunState.player_hp = maxi(RunState.player_hp - 20, 1)
			_finish_event("遭遇陷阱：失去 20 HP")
		4:
			_lose_random_card()


func _lose_random_card() -> void:
	if RunState.deck.is_empty():
		_finish_event("牌组为空，没有卡牌可以失去")
		return
	var removed_index := randi_range(0, RunState.deck.size() - 1)
	var removed_type: int = RunState.deck[removed_index]
	RunState.deck.remove_at(removed_index)
	_finish_event("失去一张「%s」" % CardDatabase.get_card_name(removed_type))


func _choose_heal() -> void:
	var old_hp := RunState.player_hp
	RunState.player_hp = mini(RunState.player_hp + heal_amount, RunState.player_max_hp)
	_finish_event("恢复了 %d 点 HP" % (RunState.player_hp - old_hp))


func _choose_max_hp() -> void:
	RunState.player_max_hp += max_hp_increase
	RunState.player_hp += max_hp_increase
	_finish_event("最大 HP 与当前 HP 都提升了 %d" % max_hp_increase)


func _show_card_choices() -> void:
	main_choices.hide()
	card_choices.show()
	message_label.text = "选择一张加入牌组"
	var candidates: Array[int] = []
	for card_type in CardDatabase.get_reward_card_ids():
		candidates.append(card_type)
	candidates.shuffle()
	for index in range(card_choices.get_child_count()):
		var button := card_choices.get_child(index) as Button
		var card_type := candidates[index]
		button.text = CardDatabase.get_reward_text(card_type)
		button.pressed.connect(_choose_card.bind(card_type))


func _choose_card(card_type: int) -> void:
	RunState.deck.append(card_type)
	_finish_event("已将「%s」加入牌组" % CardDatabase.get_card_name(card_type))


func _finish_event(message: String) -> void:
	main_choices.hide()
	card_choices.hide()
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
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _refresh_hp() -> void:
	hp_label.text = "HP: %d/%d" % [RunState.player_hp, RunState.player_max_hp]
