extends Node2D

var heal_amount := BalanceConfig.REWARD_HEAL_AMOUNT

@onready var main_choices: VBoxContainer = $RewardUI/MainChoices
@onready var card_choices: HBoxContainer = $RewardUI/CardChoices
@onready var message_label: Label = $RewardUI/Message

func _ready() -> void:
	$RewardUI/MainChoices/Heal.pressed.connect(_choose_heal)
	$RewardUI/MainChoices/Card.pressed.connect(_show_card_choices)
	card_choices.hide()
	_refresh_status()
	message_label.text = "共同经历一场战斗，羁绊 +2。请选择一项战后奖励。"
	if RunState.pending_act_bond_gain >= 0:
		if RunState.pending_act_bond_gain > 0:
			message_label.text = "战斗羁绊 +2，本层约定兑现 +%d。再选择一项奖励。" % RunState.pending_act_bond_gain
		else:
			message_label.text = "战斗羁绊 +2，本层约定未兑现。请选择一项奖励。"


func _choose_heal() -> void:
	var old_hp := RunState.player_hp
	RunState.player_hp = mini(RunState.player_hp + heal_amount, RunState.player_max_hp)
	_finish_reward("恢复了 %d 点 HP" % (RunState.player_hp - old_hp))


func _show_card_choices() -> void:
	main_choices.hide()
	card_choices.show()
	message_label.text = "选择一张加入本局牌组"
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
	_finish_reward("已将「%s」加入本局牌组" % CardDatabase.get_card_name(card_type))


func _finish_reward(message: String) -> void:
	main_choices.hide()
	card_choices.hide()
	message_label.text = message
	RunState.record_run_fact("reward", "战后奖励：%s。领取后生命为 %d/%d，牌组共 %d 张。" % [
		message,
		RunState.player_hp,
		RunState.player_max_hp,
		RunState.deck.size(),
	])
	_refresh_status()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file(RunState.post_battle_scene)


func _refresh_status() -> void:
	$RewardUI/Status.text = "HP: %d/%d　羁绊: %d/100（%s）" % [
		RunState.player_hp,
		RunState.player_max_hp,
		RunState.bond_value,
		RunState.get_bond_stage_name(),
	]
