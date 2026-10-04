extends Node2D

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
const CompanionTactics = preload("res://scripts/battle/companion_tactics.gd")
const CompanionDirector = preload("res://scripts/battle/companion_card_director.gd")
const NORMAL_ENEMY_ART := preload("res://art/enemies/ink_puppet.png")
const ELITE_ENEMY_ART := preload("res://art/enemies/ink_duelist.png")
const BOSS_ENEMY_ART := preload("res://art/enemies/cursed_guardian.png")
const COMPANION_FLASH_INTENT_ART := preload("res://art/character/sword_spirit_flash_intent.png")
const COMPANION_FLASH_INVEST_ART := preload("res://art/character/sword_spirit_flash_invest.png")
const COMPANION_FLASH_SELF_ART := preload("res://art/character/sword_spirit_flash_self.png")
const InkUISkin = preload("res://scripts/ui/ink_ui_skin.gd")
const PlayerCombatStatus = preload("res://scripts/ui/player_combat_status.gd")
const CompanionActionEffect = preload("res://scripts/ui/companion_action_effect.gd")
var companion_action_tween: Tween
const COMPANION_POSE_ART := {
	"idle": preload("res://art/character/xiaomo_idle_pose_v1.png"),
	"swing": preload("res://art/character/xiaomo_swing_pose_v1.png"),
	"heavy": preload("res://art/character/xiaomo_heavy_pose_v1.png"),
	"guard": preload("res://art/character/xiaomo_guard_pose_v1.png"),
	"gather": preload("res://art/character/xiaomo_gather_pose_v1.png"),
	"intent": preload("res://art/character/xiaomo_intent_pose_v1.png"),
}

const EnemyActionEffect = preload("res://scripts/ui/enemy_action_effect.gd")
const ROLE_ENEMY_ART := {
	"swordsman": preload("res://art/enemies/ink_swordsman_sprite_v1.png"),
	"guardian": preload("res://art/enemies/ink_guardian_sprite_v1.png"),
	"hexer": preload("res://art/enemies/ink_hexer_sprite_v1.png"),
}

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
var boss_action_step := 0
var boss_charge_hits := 0
var enemy_roles: Array[String] = []
var enemy_action_step := 0
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
var locked_companion_choice: Dictionary = {}
var companion_intent_notice := ""
var intent_generation := 0
var cooperation_windows: Dictionary = {}
var fixed_cooperation_test := false
var force_offline_companion := false
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
# 剑意「断水」「长风」留给玩家下回合的资源。
var cut_water_active := false
var long_wind_bonus := 0

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
@onready var hand_area: HBoxContainer = $BattleUI/HandViewport/HandArea
var hand_buttons: Array[Button] = []
@onready var special_button: Button = $BattleUI/ActionArea/Special
@onready var ultimate_button: Button = $BattleUI/ActionArea/Ultimate
@onready var end_turn_button: Button = $BattleUI/ActionArea/EndTurn
@onready var companion_status_label: Label = $BattleUI/CompanionPanel/Status
@onready var companion_reason_label: Label = $BattleUI/CompanionPanel/Reason
@onready var flowing_light_cut_in: Control = $FlowingLightLayer/FlowingLightCutIn
@onready var flowing_light_veil: ColorRect = $FlowingLightLayer/FlowingLightCutIn/Veil
@onready var flowing_light_ribbon: ColorRect = $FlowingLightLayer/FlowingLightCutIn/Ribbon
@onready var flowing_light_ribbon_edge: ColorRect = $FlowingLightLayer/FlowingLightCutIn/RibbonEdge
@onready var flowing_light_portrait: TextureRect = $FlowingLightLayer/FlowingLightCutIn/Portrait
@onready var flowing_light_tag: Label = $FlowingLightLayer/FlowingLightCutIn/SkillTag
@onready var flowing_light_title: Label = $FlowingLightLayer/FlowingLightCutIn/SkillTitle
@onready var flowing_light_caption: Label = $FlowingLightLayer/FlowingLightCutIn/SkillCaption
@onready var ink_event: TextureRect = $InkEventLayer/InkEvent

var enemy_hp_labels: Array[Label] = []
var enemy_hp_bars: Array[ProgressBar] = []
var enemy_status_labels: Array[Label] = []
var enemy_guard_badges: Array[PanelContainer] = []
var enemy_vulnerable_badges: Array[PanelContainer] = []
var enemy_feedback_tweens: Dictionary = {}
var enemy_idle_tweens: Array[Tween] = []
var player_status: Control
var displayed_player_block := -1
var enemy_intent_labels: Array[Label] = []
var enemy_blocks: Array[ColorRect] = []
var enemy_sprites: Array[TextureRect] = []
var enemy_frames: Array[Panel] = []
var enemy_max_hps: Array[int] = []
var pile_popup: PopupPanel
var pile_popup_title: Label
var pile_popup_text: RichTextLabel
var ink_tween: Tween
var flowing_light_tween: Tween
var companion_flash: TextureRect
var companion_flash_tween: Tween


func _ready() -> void:
	$BattleUI/CompanionPanel/Portrait.texture = COMPANION_POSE_ART["idle"]
	$BattleUI/CompanionPanel/Portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	$BattleUI/CompanionPanel/Portrait.pivot_offset = Vector2(142.5, 330)
	$BattleUI/CompanionPanel/ExpandDialogue.pressed.connect(_show_companion_dialogue)
	var dialogue_style := StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.025, 0.055, 0.06, 0.78)
	dialogue_style.border_color = Color(0.56, 0.68, 0.63, 0.28)
	dialogue_style.set_border_width_all(1)
	dialogue_style.set_corner_radius_all(16)
	$BattleUI/CompanionPanel/DialogueBackdrop.add_theme_stylebox_override("panel", dialogue_style)
	var expand_button: Button = $BattleUI/CompanionPanel/ExpandDialogue
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		expand_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	expand_button.add_theme_color_override("font_color", Color("#a6b9b0"))
	expand_button.add_theme_color_override("font_hover_color", Color("#e6c17e"))
	player_status = PlayerCombatStatus.new()
	player_status.position = Vector2(80, 12)
	player_status.size = Vector2(956, 130)
	$BattleUI/InfoArea.add_child(player_status)
	for label in [player_hp_label, energy_label, block_label, combo_label]:
		label.hide()
	$BattleUI/InfoArea/InfoBackdrop.hide()
	for child in hand_area.get_children():
		if child is Button:
			_register_hand_button(child as Button)
	special_button.pressed.connect(_use_special)
	ultimate_button.pressed.connect(_use_ultimate)
	special_button.text = CardDatabase.get_battle_text(CardDatabase.FLOWING_LIGHT)
	ultimate_button.text = CardDatabase.get_battle_text(CardDatabase.BRILLIANCE)
	preload("res://scripts/ui/battle_art_skin.gd").apply(self)
	end_turn_button.pressed.connect(_end_turn)
	draw_pile_panel.gui_input.connect(_on_pile_input.bind(true))
	discard_pile_panel.gui_input.connect(_on_pile_input.bind(false))
	_build_pile_popup()
	var companion_flash_layer := CanvasLayer.new()
	companion_flash_layer.layer = 2
	add_child(companion_flash_layer)
	companion_flash = TextureRect.new()
	companion_flash.texture = COMPANION_FLASH_SELF_ART
	companion_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	companion_flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	companion_flash.flip_h = true
	companion_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	companion_flash.anchor_right = 0.5
	companion_flash.anchor_top = 0.1
	companion_flash.anchor_bottom = 0.9
	companion_flash.offset_left = 24.0
	companion_flash.offset_right = -24.0
	companion_flash.hide()
	companion_flash_layer.add_child(companion_flash)
	fixed_cooperation_test = fixed_cooperation_test or "--cooperation-test" in OS.get_cmdline_user_args()
	force_offline_companion = force_offline_companion or fixed_cooperation_test or "--offline-companion" in OS.get_cmdline_user_args()
	start_battle()


# 统一战斗初始化入口；以后也可以在这里接收角色、敌人或关卡数据。
func start_battle() -> void:
	displayed_player_block = -1
	enemy_roles.clear()
	enemy_action_step = 0
	boss_action_step = 0
	boss_charge_hits = 0
	enemy_hps.clear()
	enemy_guards.clear()
	enemy_strengths.clear()
	enemy_vulnerabilities.clear()
	enemy_attack_reductions.clear()
	_configure_encounter()
	if fixed_cooperation_test:
		enemy_hps.assign([36, 48])
		enemy_count = 2
		draw_count = 5
		enemy_guards.assign([0, 0])
		enemy_strengths.assign([0, 0])
		enemy_vulnerabilities.assign([0, 0])
		enemy_attack_reductions.assign([0, 0])
	enemy_max_hps = enemy_hps.duplicate()
	player_max_hp = RunState.player_max_hp
	player_hp = RunState.player_hp
	battle_start_hp = player_hp
	battle_index = RunState.begin_battle()
	cut_water_active = false
	long_wind_bonus = 0
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
	locked_companion_choice.clear()
	companion_intent_notice = ""
	cooperation_windows.clear()
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
	_prepare_companion_intent()


func _configure_encounter() -> void:
	match RunState.pending_encounter:
		RunState.EncounterType.ELITE:
			var elite_config := EnemyDatabase.get_elite_config(RunState.route_layer)
			enemy_count = randi_range(elite_config["count_min"], elite_config["count_max"])
			for index in range(enemy_count):
				enemy_hps.append(randi_range(elite_config["hp_min"], elite_config["hp_max"]))
		RunState.EncounterType.BOSS:
			enemy_count = EnemyDatabase.BOSS["count_min"]
			enemy_hps.append(EnemyDatabase.get_boss_config(RunState.route_layer)["hp"])
		_:
			var normal_config := EnemyDatabase.get_normal_config(RunState.route_layer)
			enemy_count = randi_range(normal_config["count_min"], normal_config["count_max"])
			for index in range(enemy_count):
				enemy_hps.append(randi_range(normal_config["hp_min"], normal_config["hp_max"]))
	if RunState.pending_encounter != RunState.EncounterType.BOSS:
		enemy_roles = EnemyDatabase.get_encounter_roles(RunState.route_layer, enemy_count, RunState.pending_encounter == RunState.EncounterType.ELITE)
		for index in range(enemy_count):
			enemy_hps[index] += int(EnemyDatabase.ROLES[enemy_roles[index]]["hp_offset"])
	for index in range(enemy_count):
		enemy_guards.append(0)
		enemy_strengths.append(0)
		enemy_vulnerabilities.append(0)
		enemy_attack_reductions.append(0)


func _build_enemy_display() -> void:
	for tween in enemy_idle_tweens:
		if tween.is_valid():
			tween.kill()
	enemy_idle_tweens.clear()
	for tween in enemy_feedback_tweens.values():
		if tween.is_valid():
			tween.kill()
	enemy_feedback_tweens.clear()
	for child in enemy_row.get_children():
		child.queue_free()
	enemy_hp_labels.clear()
	enemy_hp_bars.clear()
	enemy_status_labels.clear()
	enemy_guard_badges.clear()
	enemy_vulnerable_badges.clear()
	enemy_intent_labels.clear()
	enemy_blocks.clear()
	enemy_sprites.clear()
	enemy_frames.clear()

	for index in range(enemy_count):
		var enemy_box := Control.new()
		enemy_box.custom_minimum_size = Vector2(235, 375)
		enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_row.add_child(enemy_box)

		var intent_label := Label.new()
		intent_label.position = Vector2(-20, -10)
		intent_label.size = Vector2(275, 42)
		intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_label.add_theme_font_size_override("font_size", 20)
		intent_label.add_theme_color_override("font_color", Color("#fff6e6"))
		intent_label.add_theme_stylebox_override("normal", preload("res://scripts/ui/battle_art_skin.gd").texture_box("intent"))
		intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_box.add_child(intent_label)
		enemy_intent_labels.append(intent_label)

		var hp_bar := ProgressBar.new()
		hp_bar.position = Vector2(13, 33)
		hp_bar.size = Vector2(209, 29)
		hp_bar.show_percentage = false
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_back := StyleBoxFlat.new()
		bar_back.bg_color = Color(0.08, 0.11, 0.12, 0.88)
		bar_back.border_color = Color("#c5aa7d")
		bar_back.set_border_width_all(2)
		bar_back.set_corner_radius_all(6)
		hp_bar.add_theme_stylebox_override("background", bar_back)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color("#aa534c")
		bar_fill.set_corner_radius_all(4)
		hp_bar.add_theme_stylebox_override("fill", bar_fill)
		enemy_box.add_child(hp_bar)
		enemy_hp_bars.append(hp_bar)

		var hp_label := Label.new()
		hp_label.position = Vector2(13, 33)
		hp_label.size = Vector2(209, 29)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 18)
		hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		hp_label.add_theme_constant_override("shadow_offset_x", 1)
		hp_label.add_theme_constant_override("shadow_offset_y", 1)
		hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_box.add_child(hp_label)
		enemy_hp_labels.append(hp_label)

		var enemy_block := ColorRect.new()
		enemy_block.position = Vector2(8, 68)
		enemy_block.size = Vector2(219, 210)
		enemy_block.color = Color.TRANSPARENT
		enemy_block.mouse_filter = Control.MOUSE_FILTER_STOP
		enemy_block.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		enemy_block.gui_input.connect(_on_enemy_input.bind(index))
		enemy_box.add_child(enemy_block)
		enemy_blocks.append(enemy_block)

		var halo := Panel.new()
		halo.position = Vector2(15, 28)
		halo.size = Vector2(189, 170)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var halo_style := StyleBoxFlat.new()
		halo_style.bg_color = Color(0.77, 0.83, 0.73, 0.10)
		halo_style.set_corner_radius_all(85)
		halo.add_theme_stylebox_override("panel", halo_style)
		enemy_block.add_child(halo)

		var enemy_sprite := TextureRect.new()
		enemy_sprite.texture = _enemy_art(index)
		enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_block.add_child(enemy_sprite)
		enemy_sprites.append(enemy_sprite)
		enemy_sprite.pivot_offset = Vector2(109.5, 210)
		enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var idle := create_tween().set_loops()
		idle.tween_property(enemy_sprite, "scale", Vector2(1.012, 1.012), 1.1 + index * 0.12).set_trans(Tween.TRANS_SINE)
		idle.tween_property(enemy_sprite, "scale", Vector2.ONE, 1.1 + index * 0.12).set_trans(Tween.TRANS_SINE)
		enemy_idle_tweens.append(idle)

		var frame := Panel.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_block.add_child(frame)
		enemy_frames.append(frame)

		var name_backdrop := Panel.new()
		name_backdrop.position = Vector2(19, 279)
		name_backdrop.size = Vector2(197, 32)
		name_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_style := StyleBoxFlat.new()
		name_style.bg_color = Color(0.025, 0.045, 0.055, 0.83)
		name_style.set_corner_radius_all(8)
		name_backdrop.add_theme_stylebox_override("panel", name_style)
		enemy_box.add_child(name_backdrop)

		var name_label := Label.new()
		name_label.position = Vector2(19, 279)
		name_label.size = Vector2(197, 32)
		name_label.text = _enemy_name(index)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_box.add_child(name_label)

		var status_label := Label.new()
		status_label.position = Vector2(0, 350)
		status_label.size = Vector2(235, 48)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 17)
		status_label.add_theme_color_override("font_color", Color("#d9e8e4"))
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_box.add_child(status_label)
		enemy_status_labels.append(status_label)
		enemy_guard_badges.append(_create_enemy_badge(enemy_box, Vector2(0, 313), Color("#74c7bd"), "护盾：先吸收伤害；敌方回合开始时旧护盾清空，新护盾持续到下一玩家回合。"))
		enemy_vulnerable_badges.append(_create_enemy_badge(enemy_box, Vector2(120, 313), Color("#e89584"), "易伤：每次命中额外增加等于层数的伤害；敌方回合结算后减少1层。"))


func _create_enemy_badge(parent: Control, at: Vector2, accent: Color, explanation: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.position = at
	badge.size = Vector2(115, 32)
	badge.tooltip_text = explanation
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142326")
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 5
	style.content_margin_right = 5
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Value"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", accent)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	parent.add_child(badge)
	return badge


func _enemy_floating_text(index: int, caption: String, tint: Color, row: int = 0) -> void:
	if index < 0 or index >= enemy_sprites.size():
		return
	var label := Label.new()
	label.text = caption
	label.position = Vector2(-10, 105 + row * 34)
	label.size = Vector2(255, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	enemy_blocks[index].get_parent().add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


func _animate_enemy_hit(index: int) -> void:
	var sprite := enemy_sprites[index]
	if enemy_feedback_tweens.has(index) and enemy_feedback_tweens[index].is_valid():
		enemy_feedback_tweens[index].kill()
	sprite.position = Vector2.ZERO
	sprite.self_modulate = Color(1.5, 1.25, 1.15, 1)
	var tween := create_tween()
	enemy_feedback_tweens[index] = tween
	tween.tween_property(sprite, "position:x", 6.0, 0.05)
	tween.tween_property(sprite, "position:x", -4.0, 0.05)
	tween.tween_property(sprite, "position:x", 0.0, 0.08)
	tween.parallel().tween_property(sprite, "self_modulate", Color.WHITE, 0.18)


func _enemy_action_effect(index: int, kind: String, tint: Color) -> void:
	var effect := EnemyActionEffect.new()
	effect.kind = kind
	effect.tint = tint
	effect.size = enemy_blocks[index].size
	enemy_blocks[index].add_child(effect)


func _animate_enemy_action(index: int, kind: String) -> void:
	var sprite := enemy_sprites[index]
	if enemy_feedback_tweens.has(index) and enemy_feedback_tweens[index].is_valid():
		enemy_feedback_tweens[index].kill()
	sprite.position = Vector2.ZERO
	sprite.self_modulate = Color.WHITE
	var tween := create_tween()
	enemy_feedback_tweens[index] = tween
	if kind == "attack":
		tween.tween_property(sprite, "position:y", -6.0, 0.1)
		tween.tween_property(sprite, "position:y", 13.0, 0.08)
		tween.tween_property(sprite, "position:y", 0.0, 0.18)
		_enemy_action_effect(index, "attack", Color("#e6c17e"))
	else:
		var tint := Color("#74c7bd") if kind == "guard" else Color("#bf9de8")
		tween.tween_property(sprite, "self_modulate", tint.lightened(0.3), 0.15)
		tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.25)
		_enemy_action_effect(index, kind, tint)


func _animate_enemy_death(index: int) -> void:
	if enemy_idle_tweens[index].is_valid():
		enemy_idle_tweens[index].kill()
	if enemy_feedback_tweens.has(index) and enemy_feedback_tweens[index].is_valid():
		enemy_feedback_tweens[index].kill()
	var sprite := enemy_sprites[index]
	sprite.position = Vector2.ZERO
	var tween := create_tween().set_parallel(true)
	enemy_feedback_tweens[index] = tween
	tween.tween_property(sprite, "position:y", 12.0, 0.4)
	tween.tween_property(sprite, "scale", Vector2(0.94, 0.94), 0.4)
	tween.tween_property(sprite, "self_modulate:a", 0.0, 0.5)


func _player_floating_text(caption: String, tint: Color, slot: int = 0) -> void:
	var label := Label.new()
	label.text = caption
	label.position = Vector2(510 + slot * 240, 615)
	label.size = Vector2(320, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$BattleUI.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _enemy_art(index: int = -1) -> Texture2D:
	if not fixed_cooperation_test and index >= 0 and index < enemy_roles.size():
		return ROLE_ENEMY_ART[enemy_roles[index]]
	match RunState.pending_encounter:
		RunState.EncounterType.ELITE:
			return ELITE_ENEMY_ART
		RunState.EncounterType.BOSS:
			return BOSS_ENEMY_ART
		_:
			return NORMAL_ENEMY_ART


func _enemy_name(index: int) -> String:
	if not fixed_cooperation_test and index < enemy_roles.size():
		return "%s%s %d" % ["精英·" if RunState.pending_encounter == RunState.EncounterType.ELITE else "", EnemyDatabase.ROLES[enemy_roles[index]]["name"], index + 1]
	match RunState.pending_encounter:
		RunState.EncounterType.ELITE:
			return "墨甲剑客 %d" % (index + 1)
		RunState.EncounterType.BOSS:
			return "咒剑守卫"
		_:
			return "影傀 %d" % (index + 1)


func _play_hand_card(index: int) -> void:
	if index < 0 or index >= hand.size() or not hand_buttons[index].visible:
		return
	if hand[index] == CardType.CURSE:
		message_label.text = "心魔无法打出"
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
		_show_flowing_light()
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
		_show_ink_event()
	_finish_action()


func _show_flowing_light() -> void:
	if flowing_light_tween != null and flowing_light_tween.is_running():
		flowing_light_tween.kill()
	flowing_light_cut_in.modulate.a = 1.0
	flowing_light_cut_in.show()
	flowing_light_veil.modulate.a = 0.0
	flowing_light_ribbon.position.x = -1300.0
	flowing_light_ribbon_edge.position.x = -1300.0
	flowing_light_portrait.position.x = 1120.0
	flowing_light_portrait.modulate.a = 0.0
	flowing_light_tag.position.x = 150.0
	flowing_light_title.position.x = 140.0
	flowing_light_caption.position.x = 150.0
	flowing_light_tag.modulate.a = 0.0
	flowing_light_title.modulate.a = 0.0
	flowing_light_caption.modulate.a = 0.0
	flowing_light_tween = create_tween()
	flowing_light_tween.tween_property(flowing_light_veil, "modulate:a", 1.0, 0.12)
	flowing_light_tween.parallel().tween_property(flowing_light_ribbon, "position:x", 180.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flowing_light_tween.parallel().tween_property(flowing_light_ribbon_edge, "position:x", 180.0, 0.29).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flowing_light_tween.parallel().tween_property(flowing_light_portrait, "position:x", 770.0, 0.27).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flowing_light_tween.parallel().tween_property(flowing_light_portrait, "modulate:a", 1.0, 0.18)
	flowing_light_tween.parallel().tween_property(flowing_light_tag, "position:x", 255.0, 0.23)
	flowing_light_tween.parallel().tween_property(flowing_light_title, "position:x", 245.0, 0.23)
	flowing_light_tween.parallel().tween_property(flowing_light_caption, "position:x", 258.0, 0.23)
	for label in [flowing_light_tag, flowing_light_title, flowing_light_caption]:
		flowing_light_tween.parallel().tween_property(label, "modulate:a", 1.0, 0.19)
	flowing_light_tween.tween_interval(0.42)
	flowing_light_tween.tween_property(flowing_light_cut_in, "modulate:a", 0.0, 0.23)
	flowing_light_tween.tween_callback(flowing_light_cut_in.hide)


func _show_ink_event() -> void:
	if ink_tween != null and ink_tween.is_running():
		ink_tween.kill()
	ink_event.modulate.a = 0.0
	ink_event.show()
	ink_tween = create_tween()
	ink_tween.tween_property(ink_event, "modulate:a", 1.0, 0.14)
	ink_tween.tween_interval(0.56)
	ink_tween.tween_property(ink_event, "modulate:a", 0.0, 0.24)
	ink_tween.tween_callback(ink_event.hide)


func _show_companion_flash(card_id: String) -> void:
	# Animate the character already on the battlefield instead of a generic large cut-in.
	var portrait: TextureRect = $BattleUI/CompanionPanel/Portrait
	if companion_action_tween != null and companion_action_tween.is_valid():
		companion_action_tween.kill()
	portrait.position = Vector2(45, 115)
	portrait.modulate = Color.WHITE
	var pose: String = CompanionActionEffect.POSES[card_id]
	portrait.texture = COMPANION_POSE_ART[pose]
	var pose_scale := 1.0 if pose == "gather" else 1.3
	portrait.scale = Vector2.ONE * pose_scale
	var kind: String = CompanionActionEffect.PROFILES[card_id][0]
	var tint := Color(CompanionActionEffect.PROFILES[card_id][1])
	companion_action_tween = create_tween()
	var attack := kind in ["slash", "dash", "frost", "resonance"]
	companion_action_tween.tween_property(portrait, "position:x", 69.0 if attack else 39.0, 0.12)
	companion_action_tween.parallel().tween_property(portrait, "modulate", Color.WHITE.lerp(tint, 0.35), 0.12)
	companion_action_tween.tween_interval(0.25)
	companion_action_tween.tween_property(portrait, "position", Vector2(45, 115), 0.35)
	companion_action_tween.parallel().tween_property(portrait, "modulate", Color.WHITE, 0.35)
	companion_action_tween.tween_callback(func():
		portrait.texture = COMPANION_POSE_ART["idle"]
		portrait.scale = Vector2.ONE
	)
	if card_id != CompanionCards.FROST_COLD:
		_add_companion_effect(card_id, portrait)
	if card_id == CompanionCards.FROST_COLD:
		for index in range(enemy_hps.size()):
			if enemy_hps[index] > 0:
				_add_companion_effect(card_id, enemy_blocks[index])
	elif attack:
		var target := _highest_hp_enemy_index() if card_id == CompanionCards.BEHEAD_LOULAN else _lowest_hp_enemy_index()
		if target >= 0:
			_add_companion_effect(card_id, enemy_blocks[target])


func _add_companion_effect(card_id: String, target: Control) -> void:
	var effect := CompanionActionEffect.new()
	effect.card_id = card_id
	# Spawn beside the target so hit/death modulation cannot hide the action effect.
	effect.position = target.position
	effect.size = target.size
	target.get_parent().add_child(effect)


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
	message_label.text = "扫叶对所有敌人造成 %d 伤害，连击 +1" % damage
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
	_enemy_floating_text(target_index, "+%d层易伤" % break_edge_vulnerable, Color("#e89584"), 2)
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
	message_label.text = "拨千斤：敌人%d下一次攻击伤害降低 %d" % [target_index + 1, unload_force_reduction]
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
	if cut_water_active:
		cut_water_active = false
		if combo > 0:
			_use_cooperation_window()
		message_label.text = "获得 %d 格挡；断水生效，连击保留" % block_amount
	else:
		combo = 0
		message_label.text = "获得 %d 格挡，连击清零" % block_amount
	_finish_action()


func _play_status_card(hand_index: int, cost: int) -> void:
	energy -= cost
	if cut_water_active:
		cut_water_active = false
		if combo > 0:
			_use_cooperation_window()
		_draw_card_into_slot(hand_index)
		message_label.text = "抽取 1 张牌；断水生效，连击保留"
	else:
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
	_close_cooperation_window()
	# 小墨上一回合留下的资源只服务于当前玩家回合；没用掉就到此失效。
	pending_boon.clear()
	cut_water_active = false
	pending_attack_index = -1
	pending_skill_target = 0
	battle_turn_count += 1
	companion_turn_pending = true
	message_label.text = "小墨执行已展示的意向……"
	_refresh_ui()
	await _run_companion_turn()
	companion_turn_pending = false
	if battle_finished:
		return
	_resolve_enemy_turn()


func _allowed_companion_cards() -> Array[String]:
	if fixed_cooperation_test:
		return [CompanionCards.QUICK_SLASH, CompanionCards.GUARD_ECHO, CompanionCards.GRIND_SWORD, CompanionCards.TEN_STEPS, CompanionCards.CUT_WATER, CompanionCards.LONG_WIND]
	return CompanionCards.get_allowed_card_ids(RunState.get_bond_stage_index(), RunState.learned_sword_intents)


func _prepare_companion_intent() -> void:
	intent_generation += 1
	var generation := intent_generation
	companion_turn_pending = true
	locked_companion_choice.clear()
	companion_status_label.text = "小墨正在确定本回合意向"
	_refresh_ui()
	var context := _build_companion_context()
	var options := CompanionTactics.candidates(context, _allowed_companion_cards())
	if options.is_empty():
		options.assign([CompanionCards.GUARD_ECHO])
	var choice: Dictionary = {}
	if not force_offline_companion:
		choice = await _request_companion_choice(context, options)
	if generation != intent_generation or battle_finished:
		return
	if choice.is_empty():
		choice = CompanionDirector.choose_fallback(context, options)
	locked_companion_choice = choice
	locked_companion_choice["plan"] = CompanionTactics.cooperation_plan(context, str(choice["card_id"]))
	companion_turn_pending = false
	_refresh_locked_companion_intent()
	companion_reason_label.tooltip_text = companion_intent_notice
	_refresh_ui()


func _process(_delta: float) -> void:
	# Keep the bubble fitted to its visible text; tactical effects never share the clipped label.
	var expand_button: Button = $BattleUI/CompanionPanel/ExpandDialogue
	var effect: Label = $BattleUI/CompanionPanel/Effect
	var lines := mini(companion_reason_label.get_line_count(), 3)
	var dialogue_height := maxf(lines * companion_reason_label.get_line_height(), 26.0)
	companion_reason_label.size.y = dialogue_height
	expand_button.visible = companion_reason_label.get_line_count() > 3
	expand_button.position.y = companion_reason_label.position.y + dialogue_height + 2
	effect.position.y = expand_button.position.y + (32 if expand_button.visible else 12)
	var effect_height := maxf(effect.get_line_count() * effect.get_line_height(), 26.0)
	$BattleUI/CompanionPanel/DialogueBackdrop.size.y = effect.position.y + effect_height + 55 - 80


func _show_companion_dialogue() -> void:
	var popup := AcceptDialog.new()
	popup.title = "小墨 · 战局对话"
	popup.dialog_text = companion_reason_label.text
	popup.dialog_autowrap = true
	popup.min_size = Vector2i(600, 280)
	$BattleUI.add_child(popup)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	popup.popup_centered()


func _refresh_locked_companion_intent() -> void:
	if locked_companion_choice.is_empty():
		return
	var choice := locked_companion_choice
	var definition := CompanionCards.get_definition(str(choice["card_id"]))
	companion_status_label.text = "本回合意向：%s" % definition["name"]
	var condition := ""
	var plan: Dictionary = choice.get("plan", {})
	if plan.get("kind", "") == "boss_interrupt":
		if not bool(enemy_intents[0].get("charging", false)):
			condition = "\n重斩已打断，我仍执行原定招式。"
		else:
			var needed := maxi(int(plan["required_total"]) - boss_charge_hits - int(plan["companion_hits"]), 0)
			condition = "\n配合：你还需命中%d次，我补最后一击（格挡也计次）。" % needed if needed > 0 else "\n配合条件已达成：我这一击可打断重斩。"
	elif plan.get("kind", "") == "preserve_combo":
		condition = "\n配合：结束回合前保留连击，我替你留到下一轮。" if combo == 0 else "\n配合条件已达成：当前%d层连击可留到下一轮。" % combo
	companion_reason_label.text = "“%s”" % str(choice.get("reason", "这回合按计划来。"))
	$BattleUI/CompanionPanel/Effect.text = "%s%s\n结束回合后执行。" % [definition["description"], condition]
	if not companion_intent_notice.is_empty():
		$BattleUI/CompanionPanel/Effect.tooltip_text = companion_intent_notice


func _run_companion_turn() -> void:
	var context := _build_companion_context()
	# 玩家已经行动完毕，不能再把“手上能积势”当成当前有剑势。
	context["can_build_combo"] = false
	var options := CompanionTactics.candidates(context, _allowed_companion_cards())
	var choice := locked_companion_choice.duplicate(true)
	companion_intent_notice = ""
	if choice.is_empty() or str(choice.get("card_id", "")) not in options:
		if options.is_empty():
			options.assign([CompanionCards.GUARD_ECHO])
		choice = CompanionDirector.choose_fallback(context, options)
		choice["reason"] = "原定配合已失效或无法挡住致命伤害，我改用「%s」。" % CompanionCards.get_definition(str(choice["card_id"]))["name"]
		companion_intent_notice = str(choice["reason"])
	locked_companion_choice.clear()
	_apply_companion_card(choice)


func _build_companion_context() -> Dictionary:
	var lowest_enemy_hp := 0
	for hp in enemy_hps:
		if hp > 0 and (lowest_enemy_hp == 0 or hp < lowest_enemy_hp):
			lowest_enemy_hp = hp
	var strongest := 0
	var attacking := 0
	var frost_prevention := 0
	for index in range(enemy_intents.size()):
		if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
			strongest = maxi(strongest, int(enemy_intents[index]["value"]))
			attacking += 1
			frost_prevention += mini(int(enemy_intents[index]["value"]), int(CompanionCards.get_definition(CompanionCards.FROST_COLD)["weaken"]))
	var can_build := false
	var hand_names: Array[String] = []
	var attack_costs: Array[int] = []
	for slot in range(hand.size()):
		if slot >= hand_buttons.size() or not hand_buttons[slot].visible:
			continue
		var card := hand[slot]
		hand_names.append(str(CardDatabase.get_definition(int(card))["name"]))
		if CardDatabase.get_definition(int(card)).get("type", "") == "攻击" and energy >= _card_cost(card):
			can_build = true
			attack_costs.append(_card_cost(card))
	attack_costs.sort()
	var affordable_hits := 0
	var attack_budget := energy
	for cost in attack_costs:
		if cost <= attack_budget:
			attack_budget -= cost
			affordable_hits += 1
	var enemies: Array[Dictionary] = []
	for index in range(enemy_hps.size()):
		if enemy_hps[index] <= 0:
			continue
		var role := enemy_roles[index] if index < enemy_roles.size() else "boss"
		enemies.append({"index": index + 1, "name": _enemy_name(index), "role": role, "rule": str(EnemyDatabase.ROLES[role]["rule"]) if EnemyDatabase.ROLES.has(role) else "攻击、布防、重斩循环；半血后重斩增强", "hp": enemy_hps[index], "guard": enemy_guards[index], "vulnerable": enemy_vulnerabilities[index], "intent": enemy_intents[index], "guard_target": _guard_target(index) + 1 if bool(enemy_intents[index].get("support", false)) else -1})
	var lowest_effective := 999999
	var lowest_index := _lowest_hp_enemy_index()
	if lowest_index >= 0:
		lowest_effective = enemy_hps[lowest_index] + enemy_guards[lowest_index] - enemy_vulnerabilities[lowest_index]
	var highest_index := _highest_hp_enemy_index()
	var highest_effective := 999999
	if highest_index >= 0:
		highest_effective = enemy_hps[highest_index] + enemy_guards[highest_index] - enemy_vulnerabilities[highest_index]
	return {
		"enemies": enemies,
		"energy": energy,
		"affordable_attack_hits": affordable_hits,
		"boss_charging": _is_boss_battle() and bool(enemy_intents[0].get("charging", false)),
		"boss_hits": boss_charge_hits,
		"boss_hit_required": EnemyDatabase.BOSS_INTERRUPT_HITS,
		"boss_attack_value": int(enemy_intents[0]["value"]) if _is_boss_battle() else 0,
		"boss_interrupted_damage": int(EnemyDatabase.get_boss_config(RunState.route_layer)["attack"]),
		"companion_target_role": enemy_roles[lowest_index] if lowest_index >= 0 and lowest_index < enemy_roles.size() else "",
		"highest_enemy_effective_hp": highest_effective,
		"hand_cards": "、".join(hand_names),
		"strongest_attack": strongest,
		"frost_prevention": frost_prevention,
		"attacking_enemies": attacking,
		"can_build_combo": can_build,
		"lowest_enemy_effective_hp": lowest_effective,
		"cooperation": RunState.relationship_facts.get("cooperation", {}),
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"block": block,
		"combo": combo,
		"living_enemies": _living_enemy_count(),
		"lowest_enemy_hp": lowest_enemy_hp,
		"incoming_damage": _enemy_intent_damage_total(),
		"bond_stage": RunState.get_bond_stage_index(),
		"turn_player_cards": "、".join(turn_player_cards) if not turn_player_cards.is_empty() else "玩家尚未行动，不要把待行动当成放弃出牌",
		"shared_history": RunState.get_shared_history_prompt(6),
		"recent_lines": RunState.get_recent_lines_block(6),
		"active_promise": RunState.active_promise,
		"relationship_archive": RunState.get_relationship_archive() + "；配合统计：" + str(RunState.relationship_facts.get("cooperation", {})),
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
	var combo_before := combo
	var incoming_before := _enemy_intent_damage_total()
	var block_before := block
	_show_companion_flash(card_id)
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
		CompanionCards.FROST_COLD:
			for index in range(enemy_hps.size()):
				if enemy_hps[index] <= 0:
					continue
				_damage_enemy_at(index, int(definition["damage"]))
				if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
					enemy_intents[index]["value"] = maxi(int(enemy_intents[index]["value"]) - int(definition["weaken"]), 0)
			last_target_index = -1
			result_text = "对全体敌人各造成 %d 伤害，它们本回合攻击 -%d" % [int(definition["damage"]), int(definition["weaken"])]
		CompanionCards.TEN_STEPS:
			var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			result_text = "对敌人%d造成 %d 伤害" % [target_index + 1, damage]
			if target_index >= 0 and enemy_hps[target_index] <= 0:
				combo += 1
				preserve_combo_this_turn = true
				result_text += "，击杀后连击 +1并保留"
			else:
				combo = 0
				result_text += "，未击杀，连击清空"
		CompanionCards.GRIND_SWORD:
			preserve_combo_this_turn = true
			result_text = "放弃本次攻击，将 %d 层连击留到下回合" % combo
		CompanionCards.CUT_WATER:
			cut_water_active = true
			result_text = "玩家下回合第一张防御或状态牌不会清空连击"
		CompanionCards.LONG_WIND:
			long_wind_bonus = int(definition["energy"])
			result_text = "玩家下回合精力 +%d" % long_wind_bonus
		CompanionCards.BEHEAD_LOULAN:
			var highest := _highest_hp_enemy_index()
			var damage := int(definition["damage"])
			_damage_enemy_at(highest, damage)
			last_target_index = highest
			result_text = "对生命最高的敌人%d造成 %d 伤害" % [highest + 1, damage]
		CompanionCards.YIN_MOUNTAIN:
			var strongest := -1
			for index in range(enemy_intents.size()):
				if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
					if strongest < 0 or int(enemy_intents[index]["value"]) > int(enemy_intents[strongest]["value"]):
						strongest = index
			if strongest >= 0:
				var blocked := int(enemy_intents[strongest]["value"])
				enemy_intents[strongest]["value"] = 0
				result_text = "挡下敌人%d本回合的攻击（%d）" % [strongest + 1, blocked]
			else:
				result_text = "本回合没有敌人要攻击，剑势落空"
		CompanionCards.FEW_RETURN:
			var gained_block := int(definition["block_low"]) if player_hp * 4 <= player_max_hp else int(definition["block"])
			block += gained_block
			companion_block_this_turn += gained_block
			result_text = "获得 %d 格挡" % gained_block
		_:
			var damage := int(definition["damage"])
			_damage_enemy_at(target_index, damage)
			last_target_index = target_index
			result_text = "对敌人%d造成 %d 伤害" % [target_index + 1, damage]
	if card_id in [CompanionCards.TEN_STEPS, CompanionCards.LONE_JUDGMENT]:
		RunState.record_cooperation("finishers")
		RunState.record_cooperation("finisher_combo_total", combo_before)
	if (block > block_before and incoming_before > block_before) or (card_id in [CompanionCards.YIN_MOUNTAIN, CompanionCards.FROST_COLD] and _enemy_intent_damage_total() < incoming_before):
		RunState.record_cooperation("guards")
	if CompanionCards.is_investment(card_id) or (card_id == CompanionCards.TEN_STEPS and preserve_combo_this_turn):
		cooperation_windows["resource"] = {"source": card_id, "used": false, "combo": combo}
	companion_last_card_id = card_id
	if str(choice.get("source", "")) == "llm":
		RunState.record_spoken_line(str(choice.get("reason", "")))
	companion_last_reason = str(choice.get("reason", "")).strip_edges()
	companion_last_source = str(choice.get("source", "fallback"))
	RunState.record_companion_card(card_id)
	var companion_name := str(definition["name"])
	battle_companion_card_counts[companion_name] = int(battle_companion_card_counts.get(companion_name, 0)) + 1
	companion_status_label.text = "小墨出牌：%s" % str(definition["name"])
	companion_reason_label.text = "“%s”" % companion_last_reason
	$BattleUI/CompanionPanel/Effect.text = result_text
	message_label.text = "小墨打出「%s」：%s" % [definition["name"], result_text]
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()


func _highest_hp_enemy_index() -> int:
	var target_index := -1
	var target_hp := 0
	for index in range(enemy_hps.size()):
		if enemy_hps[index] > 0 and (target_index < 0 or enemy_hps[index] > target_hp):
			target_index = index
			target_hp = enemy_hps[index]
	return target_index


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
	_use_cooperation_window()
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
				_animate_enemy_action(index, "attack")
				incoming_damage += intent["value"]
				action_messages.append("敌人%d攻击%d" % [index + 1, intent["value"]])
			EnemyIntent.DEFEND:
				var guard_target := index
				if bool(intent.get("support", false)):
					guard_target = _guard_target(index)
				enemy_guards[guard_target] += intent["value"]
				_animate_enemy_action(index, "guard")
				if guard_target != index:
					_enemy_action_effect(guard_target, "guard", Color("#74c7bd"))
				_enemy_floating_text(guard_target, "+%d 护盾" % int(intent["value"]), Color("#74c7bd"))
				action_messages.append("敌人%d为敌人%d提供%d格挡" % [index + 1, guard_target + 1, intent["value"]])
			EnemyIntent.ENHANCE:
				enemy_strengths[index] = intent["value"]
				action_messages.append("敌人%d强化，攻击力+%d" % [index + 1, intent["value"]])
			EnemyIntent.CURSE:
				_animate_enemy_action(index, "curse")
				_enemy_floating_text(index, "心魔 +1", Color("#bf9de8"))
				discard_pile.append(CardType.CURSE)
				action_messages.append("敌人%d往你牌组里塞了一张心魔" % (index + 1))
			EnemyIntent.OTHER:
				action_messages.append("敌人%d观望" % (index + 1))
	# 玩家与小墨均使用本轮易伤，敌方行动结算后统一衰减。
	for index in range(enemy_vulnerabilities.size()):
		enemy_vulnerabilities[index] = maxi(enemy_vulnerabilities[index] - 1, 0)
	var damage_taken := maxi(incoming_damage - block, 0)
	var shield_absorbed := mini(incoming_damage, block)
	if shield_absorbed > 0:
		_player_floating_text("护盾吸收 %d" % shield_absorbed, Color("#74c7bd"), 2)
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
	if damage_taken > 0:
		_player_floating_text("-%d 生命" % damage_taken, Color("#e89584"))
		player_status.flash_damage()
	battle_damage_taken += damage_taken
	RunState.player_hp = player_hp
	RunState.record_player_hp()
	energy = max_energy + long_wind_bonus
	long_wind_bonus = 0
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
	_assess_cooperation_window()
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
		_prepare_companion_intent()


func _can_pay(cost: int) -> bool:
	if battle_finished or companion_turn_pending:
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
		if combo > 0 and cooperation_windows.has("resource"):
			var source := str(cooperation_windows["resource"].get("source", ""))
			if source in [CompanionCards.GRIND_SWORD, CompanionCards.HEART_RESONANCE, CompanionCards.TEN_STEPS] and not companion_turn_pending and not bool(cooperation_windows["resource"].get("lost", false)):
				_use_cooperation_window()
		var hp_before := enemy_hps[target_index]
		damage += enemy_vulnerabilities[target_index]
		var absorbed := mini(enemy_guards[target_index], damage)
		enemy_guards[target_index] -= absorbed
		enemy_hps[target_index] = maxi(enemy_hps[target_index] - (damage - absorbed), 0)
		battle_damage_dealt += hp_before - enemy_hps[target_index]
		if damage > 0 and hp_before > 0:
			_animate_enemy_hit(target_index)
			if absorbed > 0:
				_enemy_floating_text(target_index, "护盾吸收 %d" % absorbed, Color("#74c7bd"))
			if hp_before > enemy_hps[target_index]:
				_enemy_floating_text(target_index, "-%d 生命" % (hp_before - enemy_hps[target_index]), Color("#f1a292"), 1 if absorbed > 0 else 0)
			if enemy_hps[target_index] == 0:
				_animate_enemy_death(target_index)
		if _is_boss_battle() and hp_before > 0 and damage > 0 and bool(enemy_intents[target_index].get("charging", false)):
			boss_charge_hits += 1
			if boss_charge_hits >= EnemyDatabase.BOSS_INTERRUPT_HITS:
				enemy_intents[target_index]["charging"] = false
				enemy_intents[target_index]["interrupted"] = true
				enemy_intents[target_index]["value"] = mini(int(enemy_intents[target_index]["value"]), int(EnemyDatabase.get_boss_config(RunState.route_layer)["attack"]))
				_enemy_floating_text(target_index, "破势！重斩打断", Color("#f1ce82"), 2)


func _is_boss_battle() -> bool:
	return not fixed_cooperation_test and RunState.pending_encounter == RunState.EncounterType.BOSS


func _guard_target(guardian_index: int) -> int:
	var target := guardian_index
	for index in range(enemy_hps.size()):
		if index != guardian_index and enemy_hps[index] > 0:
			if target == guardian_index or enemy_hps[index] < enemy_hps[target]:
				target = index
	return target


func _roll_enemy_intents() -> void:
	if fixed_cooperation_test:
		enemy_intents.assign([{"type": EnemyIntent.ATTACK, "value": 6}, {"type": EnemyIntent.ATTACK, "value": 8}])
		return
	enemy_intents.clear()
	if _is_boss_battle():
		boss_charge_hits = 0
		var action := boss_action_step % 3
		boss_action_step += 1
		if action == 1:
			enemy_intents.append({"type": EnemyIntent.DEFEND, "value": int(EnemyDatabase.get_boss_config(RunState.route_layer)["guard"])})
		else:
			var charging := action == 2
			var enraged := enemy_hps[0] * 2 <= enemy_max_hps[0]
			var damage := int(EnemyDatabase.get_boss_config(RunState.route_layer)["attack"])
			if charging:
				damage = int(EnemyDatabase.get_boss_config(RunState.route_layer)["enraged_heavy"] if enraged else EnemyDatabase.get_boss_config(RunState.route_layer)["heavy"])
			damage = maxi(damage - enemy_attack_reductions[0], 0)
			enemy_attack_reductions[0] = 0
			enemy_intents.append({"type": EnemyIntent.ATTACK, "value": damage, "charging": charging})
		return
	var role_step := enemy_action_step
	enemy_action_step += 1
	for hp in enemy_hps:
		if hp <= 0:
			enemy_intents.append({"type": EnemyIntent.OTHER, "value": 0})
			continue
		var enemy_index := enemy_intents.size()
		if enemy_index < enemy_roles.size():
			var role_intent := EnemyDatabase.get_role_intent(enemy_roles[enemy_index], role_step, RunState.pending_encounter == RunState.EncounterType.ELITE, RunState.route_layer)
			if role_intent["type"] == EnemyIntent.ATTACK:
				role_intent["value"] = maxi(int(role_intent["value"]) - enemy_attack_reductions[enemy_index], 0)
				enemy_attack_reductions[enemy_index] = 0
			enemy_intents.append(role_intent)
			continue
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
	$BattleUI/HandViewport.scroll_horizontal = 0


func _register_hand_button(button: Button) -> void:
	var index := hand_buttons.size()
	hand_buttons.append(button)
	button.pressed.connect(_play_hand_card.bind(index))
	preload("res://scripts/ui/battle_art_skin.gd").prepare_card(button)


func _ensure_hand_button(index: int) -> void:
	while hand_buttons.size() <= index:
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 300)
		button.name = "Card%d" % (hand_buttons.size() + 1)
		button.hide()
		hand_area.add_child(button)
		InkUISkin.style_button(button)
		_register_hand_button(button)


func _show_card_in_slot(index: int, card: CardType) -> void:
	_ensure_hand_button(index)
	if index == hand.size():
		hand.append(card)
	else:
		hand[index] = card
	hand_buttons[index].text = ""
	hand_buttons[index].tooltip_text = CardDatabase.get_battle_text(card)
	hand_buttons[index].get_node("PaintedFace").set_player_card(card)
	hand_buttons[index].show()


func _discard_remaining_hand() -> void:
	for index in range(hand.size()):
		if hand_buttons[index].visible:
			discard_pile.append(hand[index])
		hand_buttons[index].hide()
	hand.clear()


func _draw_new_hand() -> void:
	if fixed_cooperation_test:
		draw_pile.assign([CardType.HIDE_EDGE, CardType.DEFENSE, CardType.COMBO_BOOST, CardType.HEAVY_ATTACK, CardType.ATTACK])
	$BattleUI/HandViewport.scroll_horizontal = 0
	for index in range(draw_count):
		var drawn_card := _take_top_card()
		if drawn_card < 0:
			break
		_show_card_in_slot(index, drawn_card as CardType)


func _draw_card_into_slot(index: int) -> void:
	var drawn_card := _take_top_card()
	if drawn_card < 0:
		return
	_show_card_in_slot(index, drawn_card as CardType)


func _draw_cards_into_empty_slots(count: int, preferred_index: int = -1) -> int:
	var drawn_count := 0
	for _draw_index in range(count):
		var drawn_card := _take_top_card()
		if drawn_card < 0:
			break
		var slot := -1
		if preferred_index >= 0 and preferred_index < hand.size() and not hand_buttons[preferred_index].visible:
			slot = preferred_index
			preferred_index = -1
		else:
			for index in range(hand.size()):
				if not hand_buttons[index].visible:
					slot = index
					break
		if slot < 0:
			slot = hand.size()
		_show_card_in_slot(slot, drawn_card as CardType)
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
	if combo == 0 and cooperation_windows.has("resource") and str(cooperation_windows["resource"].get("source", "")) in [CompanionCards.GRIND_SWORD, CompanionCards.HEART_RESONANCE, CompanionCards.TEN_STEPS]:
		cooperation_windows["resource"]["lost"] = true
	if cooperation_windows.has("resource") and str(cooperation_windows["resource"].get("source", "")) == CompanionCards.LONG_WIND and energy < int(CompanionCards.get_definition(CompanionCards.LONG_WIND)["energy"]):
		_use_cooperation_window()
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()


func _end_battle(player_won: bool) -> void:
	if battle_finished:
		return
	battle_finished = true
	intent_generation += 1
	# 战斗已结束的未使用机会不是玩家浪费。
	cooperation_windows.clear()
	if fixed_cooperation_test:
		companion_turn_pending = false
		companion_status_label.text = "实验战斗：胜利" if player_won else "实验战斗：失败"
		companion_reason_label.text = "按 R 重开固定战斗。此场景不写入正式存档。"
		_refresh_ui()
		return
	RunState.player_hp = player_hp
	_record_battle_journal(player_won)
	RunState.record_battle_result(player_won)
	_record_battle_moments(player_won)
	RunState.add_bond(BalanceConfig.BATTLE_BOND_GAIN)
	if player_won:
		message_label.text = "胜利"
		print("胜利")
		var victory_delay := 1.0
		if RunState.pending_encounter == RunState.EncounterType.BOSS:
			if player_hp * 4 <= player_max_hp:
				_show_ink_event()
				victory_delay = 1.2
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
		_return_to_reward_after_delay(victory_delay)
	else:
		message_label.text = "失败"
		print("失败")
		RunState.finish_run(false)
	_refresh_ui()
	if not player_won:
		_return_to_settlement_after_delay()


func _return_to_reward_after_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	get_tree().change_scene_to_file("res://scenes/battle_reward.tscn")


func _return_to_settlement_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/settlement.tscn")


func _refresh_ui() -> void:
	_refresh_locked_companion_intent()
	battle_max_combo = maxi(battle_max_combo, combo)
	message_label.visible = pending_attack_index >= 0 or pending_skill_target != 0
	var target_index := _first_living_enemy_index()
	for index in range(enemy_hps.size()):
		enemy_hp_bars[index].max_value = enemy_max_hps[index]
		enemy_hp_bars[index].value = maxi(enemy_hps[index], 0)
		enemy_hp_labels[index].text = "%d / %d" % [maxi(enemy_hps[index], 0), enemy_max_hps[index]]
		var status_parts: Array[String] = []
		if not fixed_cooperation_test and index < enemy_roles.size():
			enemy_status_labels[index].tooltip_text = str(EnemyDatabase.ROLES[enemy_roles[index]]["rule"])
		enemy_guard_badges[index].visible = enemy_hps[index] > 0 and enemy_guards[index] > 0
		enemy_vulnerable_badges[index].visible = enemy_hps[index] > 0 and enemy_vulnerabilities[index] > 0
		(enemy_guard_badges[index].get_node("Value") as Label).text = "护盾 %d" % enemy_guards[index]
		(enemy_vulnerable_badges[index].get_node("Value") as Label).text = "易伤 %d层" % enemy_vulnerabilities[index]
		if _is_boss_battle():
			if enemy_hps[index] * 2 <= enemy_max_hps[index]:
				status_parts.append("狂怒 · 重斩22")
			if bool(enemy_intents[index].get("charging", false)):
				status_parts.append("破势 %d / %d" % [boss_charge_hits, EnemyDatabase.BOSS_INTERRUPT_HITS])
				enemy_status_labels[index].tooltip_text = "重斩回合命中三次即可打断，护盾吸收也计次，小墨攻击也计次。"
		enemy_status_labels[index].text = "   ·   ".join(status_parts)
		var frame_color := Color.TRANSPARENT
		if enemy_hps[index] <= 0:
			enemy_sprites[index].modulate = Color(0.54, 0.56, 0.56, 0.42)
			enemy_blocks[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_status_labels[index].text = ""
			enemy_intent_labels[index].text = "已击败"
		elif pending_attack_index >= 0 or pending_skill_target != 0:
			frame_color = Color("#e9cb83")
		elif index == last_target_index:
			frame_color = Color("#e9cb83")
		elif index == target_index:
			frame_color = Color(0.62, 0.86, 0.81, 0.65)
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color.TRANSPARENT
		frame_style.border_color = frame_color
		frame_style.set_border_width_all(2 if frame_color.a > 0.0 else 0)
		frame_style.set_corner_radius_all(22)
		enemy_frames[index].add_theme_stylebox_override("panel", frame_style)
		if enemy_hps[index] > 0:
			var intent := enemy_intents[index]
			match intent["type"]:
				EnemyIntent.ATTACK:
					enemy_intent_labels[index].text = "⚔  攻击 %d" % intent["value"]
					if bool(intent.get("heavy", false)):
						enemy_intent_labels[index].text = "蓄力重击 %d" % intent["value"]
					if bool(intent.get("charging", false)):
						enemy_intent_labels[index].text = "重斩 %d · 三次命中可打断" % intent["value"]
					elif bool(intent.get("interrupted", false)):
						enemy_intent_labels[index].text = "已破势 · 攻击 %d" % intent["value"]
				EnemyIntent.DEFEND:
					enemy_intent_labels[index].text = "◆  防御 %d" % intent["value"]
					if bool(intent.get("support", false)):
						enemy_intent_labels[index].text = "护卫敌人%d · 格挡%d" % [_guard_target(index) + 1, intent["value"]]
				EnemyIntent.ENHANCE:
					enemy_intent_labels[index].text = "✦  攻击 +%d" % intent["value"]
				EnemyIntent.CURSE:
					enemy_intent_labels[index].text = "☷  塞入心魔"
				EnemyIntent.OTHER:
					enemy_intent_labels[index].text = "·  观望"
	combo_label.text = "连击  %d" % combo
	player_hp_label.text = "生命  %d / %d" % [player_hp, player_max_hp]
	energy_label.text = "精力: %d/%d" % [energy, max_energy]
	block_label.text = "格挡: %d%s" % [block, _pending_boon_ui_text()]
	player_status.update_values(player_hp, player_max_hp, energy, max_energy, block, combo, _pending_boon_ui_text())
	if displayed_player_block >= 0 and block > displayed_player_block:
		_player_floating_text("+%d 护盾" % (block - displayed_player_block), Color("#74c7bd"), 2)
	displayed_player_block = block
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
		hand_buttons[index].get_node("PaintedFace").modulate = Color(0.68, 0.71, 0.7) if hand_buttons[index].disabled else Color.WHITE
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
	var extra := ""
	if cut_water_active:
		extra += "　断水：下张防御不断连击"
	if long_wind_bonus > 0:
		extra += "　长风：下回合精力 +%d" % long_wind_bonus
	return _pending_boon_core_text() + extra


func _pending_boon_core_text() -> String:
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


func _use_cooperation_window() -> void:
	if not cooperation_windows.has("resource") or bool(cooperation_windows["resource"].get("used", false)):
		return
	cooperation_windows["resource"]["used"] = true
	RunState.record_cooperation("opportunities_used")
	RunState.record_moment("第%d场，你接住了小墨「%s」留下的机会。" % [battle_index, CompanionCards.get_definition(str(cooperation_windows["resource"]["source"]))["name"]], 2)


func _close_cooperation_window() -> void:
	if cooperation_windows.has("resource") and bool(cooperation_windows["resource"].get("available", false)) and not bool(cooperation_windows["resource"].get("used", false)):
		RunState.record_cooperation("opportunities_wasted")
	cooperation_windows.clear()


func _assess_cooperation_window() -> void:
	if not cooperation_windows.has("resource"):
		return
	var attack := false
	var defense := false
	var total_cost := 0
	for card in hand:
		var definition: Dictionary = CardDatabase.get_definition(int(card))
		var cost := _card_cost(card)
		if cost <= energy and card != CardType.CURSE:
			total_cost += cost
			attack = attack or definition.get("type", "") == "攻击"
			defense = defense or card in [CardType.DEFENSE, CardType.HEAVY_DEFENSE, CardType.STATUS]
	var source := str(cooperation_windows["resource"]["source"])
	var available := attack
	if source == CompanionCards.CUT_WATER:
		available = defense and (combo > 0 or attack)
	elif source == CompanionCards.LONG_WIND:
		available = total_cost > max_energy
	elif source in [CompanionCards.GRIND_SWORD, CompanionCards.HEART_RESONANCE, CompanionCards.TEN_STEPS]:
		available = attack and combo > 0
	cooperation_windows["resource"]["available"] = available


func _unhandled_key_input(event: InputEvent) -> void:
	if fixed_cooperation_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		RunState.player_hp = RunState.player_max_hp
		start_battle()
