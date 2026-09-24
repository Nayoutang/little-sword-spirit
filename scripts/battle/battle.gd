extends Node2D

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
const CompanionDirector = preload("res://scripts/battle/companion_card_director.gd")

# -----------------------------------------------------------------------------
# 战斗流程专用参数；卡牌、敌人与全局基础数值分别由三个数据库统一提供。
# -----------------------------------------------------------------------------
# 不同地图节点的敌人配置。
var enemy_count := 3
var player_max_hp := BalanceConfig.PLAYER_START_MAX_HP
var max_energy := BalanceConfig.PLAYER_START_ENERGY

var attack_base_damage := CardDatabase.get_number(CardDatabase.ATTACK, "damage")
var attack_combo_bonus := BalanceConfig.ATTACK_COMBO_BONUS
var defense_block := CardDatabase.get_number(CardDatabase.DEFENSE, "block")
var heavy_attack_base_damage := CardDatabase.get_number(CardDatabase.HEAVY_ATTACK, "damage")
var heavy_defense_block := CardDatabase.get_number(CardDatabase.HEAVY_DEFENSE, "block")
var sweep_damage := CardDatabase.get_number(CardDatabase.SWEEP, "damage")
var combo_boost_damage := CardDatabase.get_number(CardDatabase.COMBO_BOOST, "damage")
var break_edge_damage := CardDatabase.get_number(CardDatabase.BREAK_EDGE, "damage")
var break_edge_vulnerable := CardDatabase.get_number(CardDatabase.BREAK_EDGE, "vulnerable")
var unload_force_reduction := CardDatabase.get_number(CardDatabase.UNLOAD_FORCE, "attack_reduction")
var hide_edge_block := CardDatabase.get_number(CardDatabase.HIDE_EDGE, "block")

var special_combo_required := CardDatabase.get_number(CardDatabase.FLOWING_LIGHT, "combo_required")
var special_bond_stage_required := CardDatabase.get_number(CardDatabase.FLOWING_LIGHT, "bond_stage")
var special_energy_cost := CardDatabase.get_cost(CardDatabase.FLOWING_LIGHT)
var special_damage := CardDatabase.get_number(CardDatabase.FLOWING_LIGHT, "damage")
var special_combo_cost := CardDatabase.get_number(CardDatabase.FLOWING_LIGHT, "combo_cost")
var ultimate_combo_required := CardDatabase.get_number(CardDatabase.BRILLIANCE, "combo_required")
var ultimate_bond_stage_required := CardDatabase.get_number(CardDatabase.BRILLIANCE, "bond_stage")
var ultimate_energy_cost := CardDatabase.get_cost(CardDatabase.BRILLIANCE)
var ultimate_damage := CardDatabase.get_number(CardDatabase.BRILLIANCE, "damage")

# 当前战斗状态
var enemy_hps: Array[int] = []
var player_hp: int
var energy: int
var combo := 0
var block := 0
var pending_boon: Dictionary = {}
var battle_finished := false

enum CardType {
	ATTACK, DEFENSE, STATUS, HEAVY_ATTACK, HEAVY_DEFENSE, SWEEP, COMBO_BOOST, CURSE,
	TUNE_BREATH, SHADOW_STEP, BREAK_EDGE, UNLOAD_FORCE, HIDE_EDGE,
}
enum EnemyIntent { ATTACK, DEFEND, ENHANCE, CURSE, OTHER }
var draw_count := BalanceConfig.HAND_DRAW_COUNT
const CARD_POOL: Array[CardType] = [
	CardType.ATTACK,
	CardType.ATTACK,
	CardType.ATTACK,
	CardType.ATTACK,
	CardType.ATTACK,
	CardType.DEFENSE,
	CardType.DEFENSE,
	CardType.DEFENSE,
	CardType.DEFENSE,
	CardType.DEFENSE,
	CardType.STATUS,
	CardType.HEAVY_ATTACK,
	CardType.HEAVY_DEFENSE,
	CardType.SWEEP,
	CardType.COMBO_BOOST,
	CardType.TUNE_BREATH,
	CardType.SHADOW_STEP,
	CardType.BREAK_EDGE,
	CardType.UNLOAD_FORCE,
	CardType.HIDE_EDGE,
]
var hand: Array[CardType] = []
var draw_pile: Array[CardType] = []
var discard_pile: Array[CardType] = []
var enemy_guards: Array[int] = []
var enemy_strengths: Array[int] = []
var enemy_vulnerabilities: Array[int] = []
var enemy_attack_reductions: Array[int] = []
var enemy_intents: Array[Dictionary] = []
var pending_attack_index := -1
var pending_skill_target := 0 # 0=无，1=特殊技，2=华彩
var last_target_index := -1
var tune_breath_used_this_turn := false
var preserve_combo_this_turn := false
var life_guard_used := false
var resonance_used := false
var bond_skill_comeback := false
var companion_turn_pending := false
var companion_last_card_id := ""
var companion_last_reason := ""
var companion_last_source := ""
var battle_start_hp := 0
var battle_turn_count := 0
var battle_max_combo := 0
var battle_damage_dealt := 0
var battle_damage_taken := 0
var battle_player_card_counts: Dictionary = {}
var battle_companion_card_counts: Dictionary = {}
# 共同经历素材：本场序号、本回合小墨给的格挡、本回合玩家出牌。
var battle_index := 0
var companion_block_this_turn := 0
var turn_player_cards: Array[String] = []
var boon_moment_recorded := false
var companion_save_recorded := false

@onready var enemy_row: HBoxContainer = $BattleUI/EnemyArea/EnemyRow
@onready var combo_label: Label = $BattleUI/InfoArea/ComboLabel
@onready var player_hp_label: Label = $BattleUI/InfoArea/PlayerHP
@onready var energy_label: Label = $BattleUI/InfoArea/Energy
@onready var block_label: Label = $BattleUI/InfoArea/Block
@onready var message_label: Label = $BattleUI/InfoArea/Message
@onready var draw_pile_label: Label = $BattleUI/DrawPile/Count
@onready var discard_pile_label: Label = $BattleUI/DiscardPile/Count
@onready var draw_pile_panel: ColorRect = $BattleUI/DrawPile
@onready var discard_pile_panel: ColorRect = $BattleUI/DiscardPile
@onready var hand_buttons: Array[Button] = [
	$BattleUI/HandArea/Card1,
	$BattleUI/HandArea/Card2,
	$BattleUI/HandArea/Card3,
	$BattleUI/HandArea/Card4,
]
@onready var special_button: Button = $BattleUI/ActionArea/Special
@onready var ultimate_button: Button = $BattleUI/ActionArea/Ultimate
@onready var end_turn_button: Button = $BattleUI/ActionArea/EndTurn
@onready var companion_status_label: Label = $BattleUI/CompanionPanel/Status
@onready var companion_reason_label: Label = $BattleUI/CompanionPanel/Reason

var enemy_hp_labels: Array[Label] = []
var enemy_intent_labels: Array[Label] = []
var enemy_blocks: Array[ColorRect] = []
var pile_popup: PopupPanel
var pile_popup_title: Label
var pile_popup_text: RichTextLabel


func _ready() -> void:
	for index in range(hand_buttons.size()):
		hand_buttons[index].pressed.connect(_play_hand_card.bind(index))
	special_button.pressed.connect(_use_special)
	ultimate_button.pressed.connect(_use_ultimate)
	special_button.text = CardDatabase.get_battle_text(CardDatabase.FLOWING_LIGHT)
	ultimate_button.text = CardDatabase.get_battle_text(CardDatabase.BRILLIANCE)
	end_turn_button.pressed.connect(_end_turn)
	draw_pile_panel.gui_input.connect(_on_pile_input.bind(true))
	discard_pile_panel.gui_input.connect(_on_pile_input.bind(false))
	_build_pile_popup()
	start_battle()


# 统一战斗初始化入口；以后也可以在这里接收角色、敌人或关卡数据。
func start_battle() -> void:
	enemy_hps.clear()
	enemy_guards.clear()
	enemy_strengths.clear()
	enemy_vulnerabilities.clear()
	enemy_attack_reductions.clear()
	_configure_encounter()
	player_max_hp = RunState.player_max_hp
	player_hp = RunState.player_hp
	battle_start_hp = player_hp
	battle_index = RunState.begin_battle()
	companion_block_this_turn = 0
	turn_player_cards.clear()
	boon_moment_recorded = false
	companion_save_recorded = false
	energy = max_energy
	combo = 0
	block = 0
	pending_boon.clear()
	battle_finished = false
	pending_attack_index = -1
	pending_skill_target = 0
	last_target_index = -1
	tune_breath_used_this_turn = false
	preserve_combo_this_turn = false
	life_guard_used = false
	resonance_used = false
	bond_skill_comeback = false
	companion_turn_pending = false
	companion_last_card_id = ""
	companion_last_reason = ""
	companion_last_source = ""
	battle_turn_count = 0
	battle_max_combo = 0
	battle_damage_dealt = 0
	battle_damage_taken = 0
	battle_player_card_counts.clear()
	battle_companion_card_counts.clear()
	_build_enemy_display()
	_roll_enemy_intents()
	_initialize_deck()
	_draw_new_hand()
	message_label.text = "战斗开始"
	companion_status_label.text = "小墨在观察战局"
	companion_reason_label.text = "回合结束时，她会从自己的牌池中选择一张牌。"
	_refresh_ui()


func _configure_encounter() -> void:
	match RunState.pending_encounter:
		RunState.EncounterType.ELITE:
			enemy_count = randi_range(EnemyDatabase.ELITE["count_min"], EnemyDatabase.ELITE["count_max"])
			for index in range(enemy_count):
				enemy_hps.append(randi_range(EnemyDatabase.ELITE["hp_min"], EnemyDatabase.ELITE["hp_max"]))
		RunState.EncounterType.BOSS:
			enemy_count = EnemyDatabase.BOSS["count_min"]
			enemy_hps.append(EnemyDatabase.BOSS["hp_min"])
		_:
			enemy_count = randi_range(EnemyDatabase.NORMAL["count_min"], EnemyDatabase.NORMAL["count_max"])
			for index in range(enemy_count):
				enemy_hps.append(randi_range(EnemyDatabase.NORMAL["hp_min"], EnemyDatabase.NORMAL["hp_max"]))
	for index in range(enemy_count):
		enemy_guards.append(0)
		enemy_strengths.append(0)
		enemy_vulnerabilities.append(0)
		enemy_attack_reductions.append(0)


func _build_enemy_display() -> void:
	for child in enemy_row.get_children():
		child.queue_free()
	enemy_hp_labels.clear()
	enemy_intent_labels.clear()
	enemy_blocks.clear()

	for index in range(enemy_count):
		var enemy_box := VBoxContainer.new()
		enemy_box.custom_minimum_size = Vector2(220, 250)
		enemy_box.add_theme_constant_override("separation", 10)
		enemy_row.add_child(enemy_box)

		var hp_label := Label.new()
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 24)
		enemy_box.add_child(hp_label)
		enemy_hp_labels.append(hp_label)

		var intent_label := Label.new()
		intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_label.add_theme_font_size_override("font_size", 20)
		enemy_box.add_child(intent_label)
		enemy_intent_labels.append(intent_label)

		var enemy_block := ColorRect.new()
		enemy_block.custom_minimum_size = Vector2(220, 190)
		enemy_block.color = Color("#b82e2e")
		enemy_block.mouse_filter = Control.MOUSE_FILTER_STOP
		enemy_block.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		enemy_block.gui_input.connect(_on_enemy_input.bind(index))
		enemy_box.add_child(enemy_block)
		enemy_blocks.append(enemy_block)

		var name_label := Label.new()
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.text = "敌人 %d" % (index + 1)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_block.add_child(name_label)


func _play_hand_card(index: int) -> void:
	if index < 0 or index >= hand.size() or not hand_buttons[index].visible:
		return
	if hand[index] == CardType.CURSE:
		message_label.text = "诅咒牌无法打出"
		return
	var played_card := hand[index]
	var cost := _card_cost(played_card)
	if not _can_pay(cost):
		return
	if played_card in [CardType.ATTACK, CardType.HEAVY_ATTACK, CardType.COMBO_BOOST, CardType.BREAK_EDGE, CardType.UNLOAD_FORCE]:
		pending_attack_index = index
		pending_skill_target = 0
		last_target_index = -1
		message_label.text = "请选择一个攻击目标"
		_refresh_ui()
		return

	pending_attack_index = -1
	pending_skill_target = 0
	_commit_hand_card(index)
	match played_card:
		CardType.DEFENSE:
			_play_defense_card(cost, defense_block)
		CardType.STATUS:
			_play_status_card(index, cost)
		CardType.HEAVY_DEFENSE:
			_play_defense_card(cost, heavy_defense_block)
		CardType.SWEEP:
			_play_sweep_card()
		CardType.TUNE_BREATH:
			_play_tune_breath(index)
		CardType.SHADOW_STEP:
			_play_shadow_step(index)
		CardType.HIDE_EDGE:
			_play_hide_edge()


func _commit_hand_card(index: int) -> void:
	_record_player_card(int(hand[index]))
	hand_buttons[index].hide()
	discard_pile.append(hand[index])


func _on_enemy_input(event: InputEvent, enemy_index: int) -> void:
	if (pending_attack_index < 0 and pending_skill_target == 0) or battle_finished or enemy_hps[enemy_index] <= 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if pending_attack_index >= 0:
			_resolve_targeted_attack(enemy_index)
		else:
			_resolve_targeted_skill(enemy_index)


func _resolve_targeted_attack(enemy_index: int) -> void:
	var card_index := pending_attack_index
	var card_type := hand[card_index]
	pending_attack_index = -1
	last_target_index = enemy_index
	_commit_hand_card(card_index)
	if card_type == CardType.HEAVY_ATTACK:
		_play_attack_card(_card_cost(card_type), heavy_attack_base_damage, enemy_index)
	elif card_type == CardType.COMBO_BOOST:
		_play_combo_boost_card(enemy_index)
	elif card_type == CardType.BREAK_EDGE:
		_play_break_edge_card(enemy_index)
	elif card_type == CardType.UNLOAD_FORCE:
		_play_unload_force_card(enemy_index)
	else:
		_play_attack_card(_card_cost(card_type), attack_base_damage, enemy_index)


func _resolve_targeted_skill(enemy_index: int) -> void:
	var skill_target := pending_skill_target
	pending_skill_target = 0
	last_target_index = enemy_index
	if skill_target == 1:
		_record_player_card(CardDatabase.FLOWING_LIGHT)
		energy -= special_energy_cost
		_record_bond_skill_use("流光")
		var damage := special_damage + combo * attack_combo_bonus
		_damage_enemy_at(enemy_index, damage)
		combo = maxi(combo - special_combo_cost, 0)
		var resonance_triggered := _apply_resonance_after_skill()
		message_label.text = "流光攻击敌人%d，造成 %d 伤害，消耗 %d 层连击" % [
			enemy_index + 1,
			damage,
			special_combo_cost,
		]
		if resonance_triggered:
			message_label.text += "；剑鸣余韵生效，保留1层连击"
	else:
		_record_player_card(CardDatabase.BRILLIANCE)
		energy -= ultimate_energy_cost
		_record_bond_skill_use("华彩")
		var damage := ultimate_damage + combo * attack_combo_bonus
		_damage_enemy_at(enemy_index, damage)
		combo = 0
		var resonance_triggered := _apply_resonance_after_skill()
		message_label.text = "华彩攻击敌人%d，造成 %d 伤害，连击清零" % [enemy_index + 1, damage]
		if resonance_triggered:
			message_label.text += "；剑鸣余韵生效，保留1层连击"
	_finish_action()


func _record_bond_skill_use(skill_name: String) -> void:
	if player_hp * 4 <= player_max_hp:
		if not bond_skill_comeback:
			RunState.record_moment("第%d场，你只剩 %d/%d 血的时候，还是打出了「%s」。" % [
				battle_index, player_hp, player_max_hp, skill_name,
			], 3)
		bond_skill_comeback = true


func _apply_resonance_after_skill() -> bool:
	if AbilityManager.has_ability(AbilityManager.RESONANCE) and not resonance_used:
		combo = maxi(combo, 1)
		resonance_used = true
		return true
	return false


func _play_attack_card(cost: int, base_damage: int, target_index: int) -> void:
	energy -= cost
	var damage := base_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	combo += 1
	message_label.text = "攻击敌人%d，造成 %d 伤害，连击 +1" % [target_index + 1, damage]
	_finish_action()


func _play_sweep_card() -> void:
	energy -= CardDatabase.get_cost(CardDatabase.SWEEP)
	var damage := sweep_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	for index in range(enemy_hps.size()):
		if enemy_hps[index] > 0:
			_damage_enemy_at(index, damage)
	combo += 1
	last_target_index = -1
	message_label.text = "横扫对所有敌人造成 %d 伤害，连击 +1" % damage
	_finish_action()


func _play_combo_boost_card(target_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.COMBO_BOOST)
	var damage := combo_boost_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	combo += 2
	message_label.text = "叠浪攻击敌人%d，造成 %d 伤害，连击 +2" % [
		target_index + 1,
		damage,
	]
	_finish_action()


func _play_break_edge_card(target_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.BREAK_EDGE)
	var damage := break_edge_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	enemy_vulnerabilities[target_index] += break_edge_vulnerable
	combo += 1
	message_label.text = "破锋攻击敌人%d，造成 %d 伤害，施加 %d 层易伤，连击 +1" % [
		target_index + 1,
		damage,
		break_edge_vulnerable,
	]
	_finish_action()


func _play_unload_force_card(target_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.UNLOAD_FORCE)
	if enemy_intents[target_index]["type"] == EnemyIntent.ATTACK:
		enemy_intents[target_index]["value"] = maxi(int(enemy_intents[target_index]["value"]) - unload_force_reduction, 0)
	else:
		enemy_attack_reductions[target_index] += unload_force_reduction
	message_label.text = "卸力：敌人%d下一次攻击伤害降低 %d" % [target_index + 1, unload_force_reduction]
	_finish_action()


func _play_tune_breath(hand_index: int) -> void:
	tune_breath_used_this_turn = true
	_draw_card_into_slot(hand_index)
	message_label.text = "调息：抽取 1 张牌"
	_finish_action()


func _play_shadow_step(hand_index: int) -> void:
	energy -= CardDatabase.get_cost(CardDatabase.SHADOW_STEP)
	var drawn := _draw_cards_into_empty_slots(2, hand_index)
	message_label.text = "掠影：抽取 %d 张牌" % drawn
	_finish_action()


func _play_hide_edge() -> void:
	energy -= CardDatabase.get_cost(CardDatabase.HIDE_EDGE)
	block += hide_edge_block
	preserve_combo_this_turn = true
	message_label.text = "藏锋：获得 %d 格挡，本回合结束保留连击" % hide_edge_block
	_finish_action()


func _play_defense_card(cost: int, block_amount: int) -> void:
	energy -= cost
	block += block_amount
	combo = 0
	message_label.text = "获得 %d 格挡，连击清零" % block_amount
	_finish_action()


func _play_status_card(hand_index: int, cost: int) -> void:
	energy -= cost
	combo = 0
	_draw_card_into_slot(hand_index)
	message_label.text = "抽取 1 张牌，连击清零"
	_finish_action()


func _use_special() -> void:
	if battle_finished or combo < special_combo_required or RunState.get_bond_stage_index() < special_bond_stage_required:
		return
	if not _can_pay(special_energy_cost):
		return
	pending_attack_index = -1
	pending_skill_target = 1
	last_target_index = -1
	message_label.text = "请选择「流光」的目标"
	_refresh_ui()


func _use_ultimate() -> void:
	if battle_finished or combo < ultimate_combo_required or RunState.get_bond_stage_index() < ultimate_bond_stage_required:
		return
	if not _can_pay(ultimate_energy_cost):
		return
	pending_attack_index = -1
	pending_skill_target = 2
	last_target_index = -1
	message_label.text = "请选择华彩的目标"
	_refresh_ui()


func _end_turn() -> void:
	if battle_finished or companion_turn_pending:
		return
	# 小墨上一回合留下的资源只服务于当前玩家回合；没用掉就到此失效。
	pending_boon.clear()
	pending_attack_index = -1
	pending_skill_target = 0
	battle_turn_count += 1
	companion_turn_pending = true
	message_label.text = "小墨正在结合战局和你们的经历选牌……"
	companion_status_label.text = "小墨的回合：思考中"
	companion_reason_label.text = "她只能从当前羁绊允许的牌池中选择。"
	_refresh_ui()
	await _run_companion_turn()
	companion_turn_pending = false
	if battle_finished:
		return
	_resolve_enemy_turn()


func _run_companion_turn() -> void:
	var allowed_ids := CompanionCards.get_allowed_card_ids(RunState.get_bond_stage_index())
	var context := _build_companion_context()
	var choice := await _request_companion_choice(context, allowed_ids)
	if choice.is_empty():
		choice = CompanionDirector.choose_fallback(context, allowed_ids)
	_apply_companion_card(choice)


func _build_companion_context() -> Dictionary:
	var lowest_enemy_hp := 0
	for hp in enemy_hps:
		if hp > 0 and (lowest_enemy_hp == 0 or hp < lowest_enemy_hp):
			lowest_enemy_hp = hp
	return {
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"block": block,
		"combo": combo,
		"living_enemies": _living_enemy_count(),
		"lowest_enemy_hp": lowest_enemy_hp,
		"incoming_damage": _enemy_intent_damage_total(),
		"bond_stage": RunState.get_bond_stage_index(),
		"turn_player_cards": "、".join(turn_player_cards) if not turn_player_cards.is_empty() else "这回合他一张牌都没出",
		"shared_history": RunState.get_shared_history_prompt(6),
		"active_promise": RunState.active_promise,
		"relationship_archive": RunState.get_relationship_archive(),
		"run_journal": RunState.get_run_journal_prompt(),
		"memory": RunState.get_relationship_facts_snapshot(),
	}


func _request_companion_choice(context: Dictionary, allowed_ids: Array[String]) -> Dictionary:
	var choice: Dictionary = await CompanionDirector.request_online_choice(self, context, allowed_ids)
	return choice


func _apply_companion_card(choice: Dictionary) -> void:
	var card_id := str(choice.get("card_id", CompanionCards.QUICK_SLASH))
	var definition := CompanionCards.get_definition(card_id)
	if definition.is_empty():
		card_id = CompanionCards.QUICK_SLASH
		definition = CompanionCards.get_definition(card_id)
	var target_index := _lowest_hp_enemy_index()
	var result_text := ""
	match card_id:
		CompanionCards.GUARD_ECHO:
			var gained_block := int(definition["block"])
			block += gained_block
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		CompanionCards.FOLLOW_UP:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			combo += 1
			result_text = "对敌人%d造成 %d 伤害，连击 +1" % [target_index + 1, damage]
		CompanionCards.LEAD_MOMENTUM:
			pending_boon = {
				"type": str(definition["boon_type"]),
				"value": float(definition["boon_value"]),
				"source": str(definition["name"]),
			}
			result_text = "玩家下回合第一张攻击牌伤害 ×%.1f" % float(definition["boon_value"])
		CompanionCards.OATH_GUARD:
			var gained_block := int(definition["block"])
			if RunState.active_promise == "protect":
				gained_block += int(definition["promise_bonus"])
			block += gained_block
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		CompanionCards.RETURN_GUARD:
			var gained_block := int(definition["block"])
			block += gained_block
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		CompanionCards.ESCORT:
			var gained_block := int(definition["block"])
			block += gained_block
			companion_block_this_turn += gained_block
			pending_boon = {
				"type": str(definition["boon_type"]),
				"value": int(definition["boon_value"]),
				"source": str(definition["name"]),
			}
			result_text = "获得 %d 格挡；玩家下回合第一张攻击牌伤害 +%d" % [
				gained_block,
				int(definition["boon_value"]),
			]
		CompanionCards.LONE_JUDGMENT:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			combo = 0
			result_text = "对敌人%d造成 %d 伤害，连击清零" % [target_index + 1, damage]
		CompanionCards.HEART_RESONANCE:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			preserve_combo_this_turn = true
			result_text = "对敌人%d造成 %d 伤害，保留连击" % [target_index + 1, damage]
		_:
			var damage := int(definition["damage"])
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			result_text = "对敌人%d造成 %d 伤害" % [target_index + 1, damage]
	companion_last_card_id = card_id
	companion_last_reason = str(choice.get("reason", "")).strip_edges()
	companion_last_source = str(choice.get("source", "fallback"))
	RunState.record_companion_card(card_id)
	var companion_name := str(definition["name"])
	battle_companion_card_counts[companion_name] = int(battle_companion_card_counts.get(companion_name, 0)) + 1
	companion_status_label.text = "小墨出牌：%s（%s）" % [
		str(definition["name"]),
		"关系判断" if companion_last_source == "llm" else "本地兜底",
	]
	companion_reason_label.text = "“%s”\n%s" % [companion_last_reason, result_text]
	message_label.text = "小墨打出「%s」：%s" % [definition["name"], result_text]
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()


func _lowest_hp_enemy_index() -> int:
	var target_index := -1
	var target_hp := 0
	for index in range(enemy_hps.size()):
		if enemy_hps[index] > 0 and (target_index < 0 or enemy_hps[index] < target_hp):
			target_index = index
			target_hp = enemy_hps[index]
	return target_index


func _enemy_intent_damage_total() -> int:
	var total := 0
	for index in range(enemy_intents.size()):
		if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
			total += int(enemy_intents[index]["value"])
	return total


func _apply_pending_boon_to_player_attack(damage: int) -> int:
	if pending_boon.is_empty():
		return damage
	var boon := pending_boon.duplicate()
	pending_boon.clear()
	var boosted := damage
	match str(boon.get("type", "")):
		"multiply":
			boosted = roundi(damage * float(boon.get("value", 1.0)))
		"add":
			boosted = damage + int(boon.get("value", 0))
	if boosted > damage and not boon_moment_recorded:
		boon_moment_recorded = true
		RunState.record_moment("第%d场，小墨用「%s」把下一手让给了你，你接着那一击从 %d 打到了 %d。" % [
			battle_index, str(boon.get("source", "她的牌")), damage, boosted,
		], 3 if boosted - damage >= 8 else 2)
	return boosted


func _resolve_enemy_turn() -> void:
	# 敌人上一轮获得的格挡在玩家回合结束时消失；本轮防御行动生成的新格挡
	# 会保留到下一个玩家回合。
	for index in range(enemy_guards.size()):
		enemy_guards[index] = 0
	# 上一轮强化只影响当前这轮已经预告的行动，结算前先移除旧强化；
	# 本轮再次使用强化时会重新获得，并影响下一轮。
	for index in range(enemy_strengths.size()):
		enemy_strengths[index] = 0
	var incoming_damage := 0
	var action_messages: Array[String] = []
	for index in range(enemy_hps.size()):
		if enemy_hps[index] <= 0:
			continue
		var intent := enemy_intents[index]
		match intent["type"]:
			EnemyIntent.ATTACK:
				incoming_damage += intent["value"]
				action_messages.append("敌人%d攻击%d" % [index + 1, intent["value"]])
			EnemyIntent.DEFEND:
				enemy_guards[index] += intent["value"]
				action_messages.append("敌人%d获得%d格挡" % [index + 1, intent["value"]])
			EnemyIntent.ENHANCE:
				enemy_strengths[index] = intent["value"]
				action_messages.append("敌人%d强化，攻击力+%d" % [index + 1, intent["value"]])
			EnemyIntent.CURSE:
				discard_pile.append(CardType.CURSE)
				action_messages.append("敌人%d加入一张诅咒" % (index + 1))
			EnemyIntent.OTHER:
				action_messages.append("敌人%d观望" % (index + 1))
	var damage_taken := maxi(incoming_damage - block, 0)
	var damage_without_companion := maxi(incoming_damage - maxi(block - companion_block_this_turn, 0), 0)
	if (
		not companion_save_recorded
		and companion_block_this_turn > 0
		and damage_without_companion >= player_hp
		and damage_taken < player_hp
	):
		companion_save_recorded = true
		RunState.record_moment("第%d场，敌人那一轮本来足以击倒只剩 %d 血的你，是小墨的格挡替你接住了。" % [
			battle_index, player_hp,
		], 4)
	block = 0
	companion_block_this_turn = 0
	var life_guard_triggered := false
	if (
		damage_taken >= player_hp
		and player_hp > 0
		and AbilityManager.has_ability(AbilityManager.LIFE_GUARD)
		and not life_guard_used
	):
		damage_taken = player_hp - 1
		life_guard_used = true
		life_guard_triggered = true
		RunState.record_moment("第%d场，本该倒下的那一击，灵剑护主替你留住了最后一口气。" % battle_index, 4)
	player_hp = maxi(player_hp - damage_taken, 0)
	battle_damage_taken += damage_taken
	RunState.player_hp = player_hp
	RunState.record_player_hp()
	energy = max_energy
	var combo_was_preserved := preserve_combo_this_turn
	if not preserve_combo_this_turn:
		combo = 0
		if AbilityManager.has_ability(AbilityManager.PERSEVERANCE):
			combo = 1
	preserve_combo_this_turn = false
	tune_breath_used_this_turn = false
	turn_player_cards.clear()
	_discard_remaining_hand()
	_draw_new_hand()
	var combo_result := "藏锋生效，保留连击" if combo_was_preserved else "连击清零"
	if not combo_was_preserved and AbilityManager.has_ability(AbilityManager.PERSEVERANCE):
		combo_result = "百折生效，新回合保留1层连击"
	var guard_result := "；护命发动，保留1点生命" if life_guard_triggered else ""
	message_label.text = "敌方行动：%s。受到 %d 伤害，%s%s" % [
		"；".join(action_messages),
		damage_taken,
		combo_result,
		guard_result,
	]
	if player_hp <= 0:
		_end_battle(false)
	else:
		_roll_enemy_intents()
		_refresh_ui()


func _can_pay(cost: int) -> bool:
	if battle_finished:
		return false
	if energy < cost:
		message_label.text = "精力不足"
		_refresh_ui()
		return false
	return true


func _card_cost(card_type: CardType) -> int:
	return CardDatabase.get_cost(int(card_type))


func _damage_enemy_at(target_index: int, damage: int) -> void:
	if target_index >= 0:
		var hp_before := enemy_hps[target_index]
		damage += enemy_vulnerabilities[target_index]
		var absorbed := mini(enemy_guards[target_index], damage)
		enemy_guards[target_index] -= absorbed
		enemy_hps[target_index] = maxi(enemy_hps[target_index] - (damage - absorbed), 0)
		battle_damage_dealt += hp_before - enemy_hps[target_index]


func _roll_enemy_intents() -> void:
	enemy_intents.clear()
	for hp in enemy_hps:
		if hp <= 0:
			enemy_intents.append({"type": EnemyIntent.OTHER, "value": 0})
			continue
		var enemy_index := enemy_intents.size()
		var roll := randi_range(0, 99)
		if roll < EnemyDatabase.INTENT_ATTACK_END:
			enemy_intents.append({
				"type": EnemyIntent.ATTACK,
				"value": maxi(
					randi_range(EnemyDatabase.ATTACK_DAMAGE_MIN, EnemyDatabase.ATTACK_DAMAGE_MAX)
					+ enemy_strengths[enemy_index]
					- enemy_attack_reductions[enemy_index],
					0
				),
			})
			enemy_attack_reductions[enemy_index] = 0
		elif roll < EnemyDatabase.INTENT_DEFEND_END:
			enemy_intents.append({
				"type": EnemyIntent.DEFEND,
				"value": randi_range(EnemyDatabase.DEFENSE_MIN, EnemyDatabase.DEFENSE_MAX),
			})
		elif roll < EnemyDatabase.INTENT_ENHANCE_END:
			enemy_intents.append({"type": EnemyIntent.ENHANCE, "value": EnemyDatabase.STRENGTH_GAIN})
		elif roll < EnemyDatabase.INTENT_CURSE_END:
			enemy_intents.append({"type": EnemyIntent.CURSE, "value": 1})
		else:
			enemy_intents.append({"type": EnemyIntent.OTHER, "value": 0})


func _first_living_enemy_index() -> int:
	for index in range(enemy_hps.size()):
		if enemy_hps[index] > 0:
			return index
	return -1


func _living_enemy_count() -> int:
	var count := 0
	for hp in enemy_hps:
		if hp > 0:
			count += 1
	return count


func _initialize_deck() -> void:
	hand.clear()
	discard_pile.clear()
	draw_pile.clear()
	for card_value in RunState.deck:
		draw_pile.append(card_value as CardType)
	draw_pile.shuffle()
	for button in hand_buttons:
		button.hide()


func _discard_remaining_hand() -> void:
	for index in range(hand.size()):
		if hand_buttons[index].visible:
			discard_pile.append(hand[index])
		hand_buttons[index].hide()
	hand.clear()


func _draw_new_hand() -> void:
	for index in range(draw_count):
		var drawn_card := _take_top_card()
		if drawn_card < 0:
			break
		hand.append(drawn_card as CardType)
		hand_buttons[index].text = CardDatabase.get_battle_text(drawn_card)
		hand_buttons[index].show()


func _draw_card_into_slot(index: int) -> void:
	var drawn_card := _take_top_card()
	if drawn_card < 0:
		return
	hand[index] = drawn_card as CardType
	hand_buttons[index].text = CardDatabase.get_battle_text(drawn_card)
	hand_buttons[index].show()


func _draw_cards_into_empty_slots(count: int, preferred_index: int = -1) -> int:
	var drawn_count := 0
	var slots: Array[int] = []
	if preferred_index >= 0:
		slots.append(preferred_index)
	for index in range(hand_buttons.size()):
		if index != preferred_index and not hand_buttons[index].visible:
			slots.append(index)
	for slot in slots:
		if drawn_count >= count:
			break
		var drawn_card := _take_top_card()
		if drawn_card < 0:
			break
		if slot < hand.size():
			hand[slot] = drawn_card as CardType
		else:
			while hand.size() < slot:
				hand.append(CardType.CURSE)
			hand.append(drawn_card as CardType)
		hand_buttons[slot].text = CardDatabase.get_battle_text(drawn_card)
		hand_buttons[slot].show()
		drawn_count += 1
	return drawn_count


func _take_top_card() -> int:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return -1
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		draw_pile.shuffle()
	return draw_pile.pop_back()


func _finish_action() -> void:
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()


func _end_battle(player_won: bool) -> void:
	if battle_finished:
		return
	battle_finished = true
	RunState.player_hp = player_hp
	_record_battle_journal(player_won)
	RunState.record_battle_result(player_won)
	_record_battle_moments(player_won)
	RunState.add_bond(BalanceConfig.BATTLE_BOND_GAIN)
	if player_won:
		message_label.text = "胜利"
		print("胜利")
		if RunState.pending_encounter == RunState.EncounterType.BOSS:
			SpecialEventManager.evaluate_boss_victory(
				player_hp,
				player_max_hp,
				bond_skill_comeback,
				RunState.consecutive_run_failures
			)
			RunState.settle_act_promise()
			print("远征通关")
			RunState.finish_run(true)
			RunState.post_battle_scene = "res://scenes/settlement.tscn"
		else:
			RunState.pending_act_bond_gain = -1
			RunState.post_battle_scene = "res://scenes/map.tscn"
		_return_to_reward_after_delay()
	else:
		message_label.text = "失败"
		print("失败")
		RunState.finish_run(false)
	_refresh_ui()
	if not player_won:
		_return_to_settlement_after_delay()


func _return_to_reward_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/battle_reward.tscn")


func _return_to_settlement_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/settlement.tscn")


func _refresh_ui() -> void:
	battle_max_combo = maxi(battle_max_combo, combo)
	var target_index := _first_living_enemy_index()
	for index in range(enemy_hps.size()):
		enemy_blocks[index].scale = Vector2.ONE
		enemy_hp_labels[index].text = "HP: %d  格挡: %d  易伤: %d" % [
			enemy_hps[index], enemy_guards[index], enemy_vulnerabilities[index]
		]
		if enemy_hps[index] <= 0:
			enemy_blocks[index].color = Color("#303030")
			enemy_intent_labels[index].text = "已击败"
		elif pending_attack_index >= 0 or pending_skill_target != 0:
			enemy_blocks[index].color = Color("#d6a52f")
			enemy_blocks[index].pivot_offset = enemy_blocks[index].size * 0.5
			enemy_blocks[index].scale = Vector2(1.06, 1.06)
		elif index == last_target_index:
			enemy_blocks[index].color = Color("#e8793a")
			enemy_blocks[index].pivot_offset = enemy_blocks[index].size * 0.5
			enemy_blocks[index].scale = Vector2(1.12, 1.12)
		elif index == target_index:
			enemy_blocks[index].color = Color("#d94747")
		else:
			enemy_blocks[index].color = Color("#8f3333")
		if enemy_hps[index] > 0:
			var intent := enemy_intents[index]
			match intent["type"]:
				EnemyIntent.ATTACK:
					enemy_intent_labels[index].text = "下一步：攻击 %d" % intent["value"]
				EnemyIntent.DEFEND:
					enemy_intent_labels[index].text = "下一步：防御 %d" % intent["value"]
				EnemyIntent.ENHANCE:
					enemy_intent_labels[index].text = "下一步：强化 +%d攻击" % intent["value"]
				EnemyIntent.CURSE:
					enemy_intent_labels[index].text = "下一步：加入诅咒"
				EnemyIntent.OTHER:
					enemy_intent_labels[index].text = "下一步：观望"
	combo_label.text = "连击数: %d" % combo
	player_hp_label.text = "HP: %d" % player_hp
	energy_label.text = "精力: %d/%d" % [energy, max_energy]
	block_label.text = "格挡: %d%s" % [block, _pending_boon_ui_text()]
	draw_pile_label.text = "牌堆\n%d" % draw_pile.size()
	discard_pile_label.text = "弃牌堆\n%d" % discard_pile.size()

	for index in range(hand_buttons.size()):
		hand_buttons[index].disabled = (
			battle_finished
			or companion_turn_pending
			or index >= hand.size()
			or hand[index] == CardType.CURSE
			or (hand[index] == CardType.TUNE_BREATH and tune_breath_used_this_turn)
			or energy < _card_cost(hand[index])
		)
	special_button.disabled = (
		battle_finished
		or companion_turn_pending
		or RunState.get_bond_stage_index() < special_bond_stage_required
		or combo < special_combo_required
		or energy < special_energy_cost
	)
	ultimate_button.disabled = (
		battle_finished
		or companion_turn_pending
		or RunState.get_bond_stage_index() < ultimate_bond_stage_required
		or combo < ultimate_combo_required
		or energy < ultimate_energy_cost
	)
	end_turn_button.disabled = battle_finished or companion_turn_pending


func _encounter_label() -> String:
	if RunState.pending_encounter == RunState.EncounterType.ELITE:
		return "精英战"
	if RunState.pending_encounter == RunState.EncounterType.BOSS:
		return "Boss战"
	return "普通战"


func _record_battle_moments(player_won: bool) -> void:
	var label := _encounter_label()
	if not player_won:
		RunState.record_moment("第%d场（%s），你倒下了，这一趟远征就停在了这里。" % [battle_index, label], 4)
		return
	if player_hp * 4 <= player_max_hp:
		RunState.record_moment("第%d场（%s），你只剩 %d/%d 血，还是撑着打赢了。" % [
			battle_index, label, player_hp, player_max_hp,
		], 4 if label == "Boss战" else 3)
	if battle_max_combo >= 5:
		RunState.record_moment("第%d场（%s），你一回合打出了 %d 连击。" % [battle_index, label, battle_max_combo], 2)
	if label == "Boss战":
		RunState.record_moment("第%d场，你们一起打倒了这一趟的 Boss。" % battle_index, 2)
	elif label == "精英战":
		RunState.record_moment("第%d场，你们赢下了一场精英战。" % battle_index, 1)


func _record_player_card(card_id: int) -> void:
	var card_name := CardDatabase.get_card_name(card_id)
	turn_player_cards.append(card_name)
	battle_player_card_counts[card_name] = int(battle_player_card_counts.get(card_name, 0)) + 1


func _record_battle_journal(player_won: bool) -> void:
	var encounter_name := "普通战"
	if RunState.pending_encounter == RunState.EncounterType.ELITE:
		encounter_name = "精英战"
	elif RunState.pending_encounter == RunState.EncounterType.BOSS:
		encounter_name = "Boss战"
	var promise_state := "；本场后约定仍未判定"
	if RunState.promise_broken:
		promise_state = "；本场中已经触发失约"
	RunState.record_run_fact("battle", "%s%s：%s。生命 %d/%d → %d/%d；玩家结束回合 %d 次；最高连击 %d；造成 %d 伤害、承受 %d 伤害；玩家出牌：%s；小墨出牌：%s%s。" % [
		encounter_name,
		"胜利" if player_won else "失败",
		"击败了全部敌人" if player_won else "玩家倒下",
		battle_start_hp,
		player_max_hp,
		player_hp,
		player_max_hp,
		battle_turn_count,
		battle_max_combo,
		battle_damage_dealt,
		battle_damage_taken,
		_format_card_counts(battle_player_card_counts),
		_format_card_counts(battle_companion_card_counts),
		promise_state,
	], {
		"encounter": encounter_name,
		"won": player_won,
		"hp_start": battle_start_hp,
		"hp_end": player_hp,
		"turns": battle_turn_count,
		"max_combo": battle_max_combo,
		"damage_dealt": battle_damage_dealt,
		"damage_taken": battle_damage_taken,
		"player_cards": battle_player_card_counts.duplicate(true),
		"companion_cards": battle_companion_card_counts.duplicate(true),
	})


func _format_card_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "无"
	var parts: Array[String] = []
	for card_name in counts:
		parts.append("%s×%d" % [str(card_name), int(counts[card_name])])
	parts.sort()
	return "、".join(parts)


func _pending_boon_ui_text() -> String:
	if pending_boon.is_empty():
		return ""
	if str(pending_boon.get("type", "")) == "multiply":
		return "　下张攻击 ×%.1f" % float(pending_boon.get("value", 1.0))
	if str(pending_boon.get("type", "")) == "add":
		return "　下张攻击 +%d" % int(pending_boon.get("value", 0))
	return ""


func _build_pile_popup() -> void:
	pile_popup = PopupPanel.new()
	pile_popup.name = "PilePopup"
	$BattleUI.add_child(pile_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	pile_popup.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	pile_popup_title = Label.new()
	pile_popup_title.add_theme_font_size_override("font_size", 28)
	pile_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(pile_popup_title)
	pile_popup_text = RichTextLabel.new()
	pile_popup_text.custom_minimum_size = Vector2(560, 480)
	pile_popup_text.fit_content = false
	pile_popup_text.scroll_active = true
	pile_popup_text.add_theme_font_size_override("normal_font_size", 21)
	column.add_child(pile_popup_text)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.pressed.connect(pile_popup.hide)
	column.add_child(close_button)


func _on_pile_input(event: InputEvent, show_draw_pile: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_pile_contents(show_draw_pile)


func _show_pile_contents(show_draw_pile: bool) -> void:
	var pile: Array[CardType] = draw_pile if show_draw_pile else discard_pile
	pile_popup_title.text = "牌堆（%d）" % pile.size() if show_draw_pile else "弃牌堆（%d）" % pile.size()
	if pile.is_empty():
		pile_popup_text.text = "这里是空的。"
	else:
		var counts := {}
		for card_type in pile:
			counts[card_type] = int(counts.get(card_type, 0)) + 1
		var lines: Array[String] = []
		for card_type in counts.keys():
			var card_text := CardDatabase.get_battle_text(int(card_type))
			var card_name := card_text.get_slice("\n", 0)
			lines.append("%s × %d\n%s" % [card_name, counts[card_type], card_text.replace(card_name + "\n", "")])
		pile_popup_text.text = "\n\n".join(lines)
	pile_popup.popup_centered(Vector2i(620, 650))
