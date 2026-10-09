extends Node2D

# 存活检查及保命结算完成后发出；未来反击在此同步结算。
signal enemy_attack_segment_resolved(enemy_index: int, damage: int, absorbed: int, life_lost: int)

@export_group("小墨气泡布局")
@export var companion_dialogue_gap := 6.0
@export var companion_bubble_bottom_padding := 72.0
@export_group("本地调试日志")
@export var selection_logging_enabled := true
@export var selection_log_max_bytes := 2097152

const Feedback = preload("res://scripts/ui/battle_feedback.gd")
const BoundedLog = preload("res://scripts/battle/bounded_jsonl.gd")
const ComboTelemetry = preload("res://scripts/battle/combo_telemetry.gd")
const AttackSegments = preload("res://scripts/battle/enemy_attack_segments.gd")
const IntentPlanner = preload("res://scripts/battle/enemy_intent_planner.gd")
const BattleDeck = preload("res://scripts/battle/battle_deck.gd")
const CombatTypes = preload("res://scripts/data/combat_types.gd")
var random_call_counts := {"deck": 0, "enemy": 0}
var combo_telemetry = ComboTelemetry.new()
var telemetry_action: Dictionary = {}

const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
const CompanionEffects = preload("res://scripts/battle/companion_effect_resolver.gd")
const CompanionTactics = preload("res://scripts/battle/companion_tactics.gd")
const CompanionDirector = preload("res://scripts/battle/companion_card_director.gd")
const NORMAL_ENEMY_ART := preload("res://art/enemies/ink_puppet.png")
const ELITE_ENEMY_ART := preload("res://art/enemies/ink_duelist.png")
const BOSS_ENEMY_ART := preload("res://art/enemies/cursed_guardian.png")
const COMPANION_FLASH_INTENT_ART := preload("res://art/character/sword_spirit_flash_intent.png")
const COMPANION_FLASH_INVEST_ART := preload("res://art/character/sword_spirit_flash_invest.png")
const COMPANION_FLASH_SELF_ART := preload("res://art/character/sword_spirit_flash_self.png")
const InkUISkin = preload("res://scripts/ui/ink_ui_skin.gd")
const EnemyDisplayScene = preload("res://ui/battle/enemy_display.tscn")
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
var consecutive_attacks := 0
var flowing_cloud_active := false
var retain_shield_active := false
var parry_active := false
var parry_reactions := 0
var parry_combo_awards := 0
var parry_pending_combo := 0
var parry_injected_remaining := 0
var battle_parry_damage := 0
var parry_reaction_limit := CardDatabase.get_number(CardDatabase.PARRY, "reaction_limit")
var parry_combo_limit := CardDatabase.get_number(CardDatabase.PARRY, "combo_limit")
var flowing_cloud_triggered := false
# 只用于离线对照；正式默认仍恢复精力。
var flowing_cloud_refunds_energy := true
var resolving_hand_card := -1
var deck_rng := RandomNumberGenerator.new()
var enemy_rng := RandomNumberGenerator.new()
var fixed_random_seed := -1
var block := 0
var boss_action_step := 0
var boss_charge_hits := 0
var enemy_roles: Array[String] = []
var enemy_action_step := 0
var pending_boon: Dictionary = {}
var battle_finished := false

const CardType = CombatTypes.CardType
const EnemyIntent = CombatTypes.EnemyIntent
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
var _deck := BattleDeck.new()
# Compatibility accessors share the model's arrays; there is no second copy.
var draw_pile: Array[CardType]:
	get:
		return _deck.draw_pile
	set(value):
		_deck.draw_pile = value
var discard_pile: Array[CardType]:
	get:
		return _deck.discard_pile
	set(value):
		_deck.discard_pile = value
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
var grind_sword_ready := false
var companion_damage_multiplier := 1
var companion_bonus_action := false
var few_return_active := false
var few_return_used := false
var few_return_immune := false
var bond_skill_comeback := false
var companion_turn_pending := false
var locked_companion_choice: Dictionary = {}
var companion_intent_notice := ""
var intent_generation := 0
var cooperation_windows: Dictionary = {}
var fixed_cooperation_test := false
var offline_experiment := false
var force_offline_companion := false
var companion_last_card_id := ""
var companion_last_reason := ""
var companion_last_source := ""
var companion_selection_records: Array[Dictionary] = []
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
@onready var ink_event: Control = $InkEventLayer/InkEvent

var enemy_hp_labels: Array[Label] = []
var enemy_hp_bars: Array[ProgressBar] = []
var enemy_status_labels: Array[Label] = []
var enemy_guard_badges: Array[PanelContainer] = []
var enemy_vulnerable_badges: Array[PanelContainer] = []
var enemy_feedback_tweens: Dictionary = {}
var enemy_idle_tweens: Array[Tween] = []
@onready var player_status: Control = $BattleUI/InfoArea/PlayerStatus
@onready var companion_rest_position: Vector2 = $BattleUI/CompanionPanel/Portrait.position
var displayed_player_block := -1
var enemy_intent_labels: Array[Label] = []
var enemy_blocks: Array[ColorRect] = []
var enemy_sprites: Array[TextureRect] = []
var enemy_frames: Array[Panel] = []
var enemy_max_hps: Array[int] = []
var pile_popup: PopupPanel
var pile_popup_title: Label
var pile_popup_text: Label
var pile_grid: GridContainer
var flowing_light_tween: Tween
var companion_flash: TextureRect
var companion_flash_tween: Tween


func _ready() -> void:
	var card_library = preload("res://scripts/ui/card_library.gd").new()
	card_library.name = "CardLibrary"
	add_child(card_library)
	var library_button := Button.new()
	library_button.name = "CardLibraryButton"
	library_button.text = "剑谱 · 图鉴"
	library_button.position = Vector2(1630, 30)
	library_button.size = Vector2(240, 48)
	preload("res://scripts/ui/ink_ui_skin.gd").style_button(library_button)
	$BattleUI.add_child(library_button)
	library_button.pressed.connect(card_library.open)
	preload("res://scripts/ui/save_exit_button.gd").install(self, $BattleUI, Vector2(1370, 30))
	if RunState.has_expedition() and RunState.expedition_checkpoint.phase == "battle" and not fixed_cooperation_test and not offline_experiment:
		fixed_random_seed = RunState.battle_seed
	random_call_counts = {"deck": 0, "enemy": 0}
	if not enemy_attack_segment_resolved.is_connected(_on_parry_attack_segment):
		enemy_attack_segment_resolved.connect(_on_parry_attack_segment)
	$BattleUI/CompanionPanel/Portrait.texture = COMPANION_POSE_ART["idle"]
	$BattleUI/CompanionPanel/Portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	$BattleUI/CompanionPanel/Portrait.pivot_offset = Vector2(142.5, 330)
	$BattleUI/CompanionPanel/ExpandDialogue.pressed.connect(_show_companion_dialogue)
	var expand_button: Button = $BattleUI/CompanionPanel/ExpandDialogue
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		expand_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	expand_button.add_theme_color_override("font_color", Color("#a6b9b0"))
	expand_button.add_theme_color_override("font_hover_color", Color("#e6c17e"))
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
	companion_flash = $CompanionFlashLayer/CompanionFlash
	fixed_cooperation_test = fixed_cooperation_test or "--cooperation-test" in OS.get_cmdline_user_args()
	force_offline_companion = force_offline_companion or fixed_cooperation_test or "--offline-companion" in OS.get_cmdline_user_args()
	start_battle()


# 统一战斗初始化入口；以后也可以在这里接收角色、敌人或关卡数据。
func start_battle() -> void:
	combo_telemetry = ComboTelemetry.new()
	telemetry_action.clear()
	if fixed_random_seed >= 0:
		deck_rng.seed = fixed_random_seed
		enemy_rng.seed = fixed_random_seed + 104729
	else:
		deck_rng.randomize()
		enemy_rng.randomize()
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
	consecutive_attacks = 0
	flowing_cloud_active = false
	retain_shield_active = false
	_reset_parry_state()
	battle_parry_damage = 0
	flowing_cloud_triggered = false
	resolving_hand_card = -1
	block = 0
	pending_boon.clear()
	battle_finished = false
	pending_attack_index = -1
	pending_skill_target = 0
	last_target_index = -1
	tune_breath_used_this_turn = false
	preserve_combo_this_turn = false
	grind_sword_ready = false
	companion_damage_multiplier = 1
	companion_bonus_action = false
	few_return_active = false
	few_return_used = false
	few_return_immune = false
	bond_skill_comeback = false
	companion_turn_pending = false
	locked_companion_choice.clear()
	companion_intent_notice = ""
	cooperation_windows.clear()
	companion_last_card_id = ""
	companion_last_reason = ""
	companion_last_source = ""
	companion_selection_records.clear()
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
	combo_telemetry.begin_round(1, combo, flowing_cloud_active, RunState.get_bond_stage_index() >= ultimate_bond_stage_required, _visible_wind_count())
	combo_telemetry.current["cloud_in_hand"] = _visible_cloud_count()
	message_label.text = "战斗开始"
	companion_status_label.text = "小墨在观察战局"
	companion_reason_label.text = "回合结束时，她会从自己的牌池中选择一张牌。"
	_refresh_ui()
	_prepare_companion_intent()


func _configure_encounter() -> void:
	match RunState.pending_encounter:
		RunState.EncounterType.ELITE:
			var elite_config := EnemyDatabase.get_elite_config(RunState.route_layer)
			enemy_count = _enemy_roll(elite_config["count_min"], elite_config["count_max"])
			for index in range(enemy_count):
				enemy_hps.append(_enemy_roll(elite_config["hp_min"], elite_config["hp_max"]))
		RunState.EncounterType.BOSS:
			enemy_count = EnemyDatabase.BOSS["count_min"]
			enemy_hps.append(EnemyDatabase.get_boss_config(RunState.route_layer)["hp"])
		_:
			var normal_config := EnemyDatabase.get_normal_config(RunState.route_layer)
			enemy_count = _enemy_roll(normal_config["count_min"], normal_config["count_max"])
			for index in range(enemy_count):
				enemy_hps.append(_enemy_roll(normal_config["hp_min"], normal_config["hp_max"]))
	if RunState.pending_encounter != RunState.EncounterType.BOSS:
		enemy_roles = EnemyDatabase.get_encounter_roles(RunState.route_layer, enemy_count, RunState.pending_encounter == RunState.EncounterType.ELITE, enemy_rng if RunState.has_expedition() else null)
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
		var enemy_box: Control = EnemyDisplayScene.instantiate()
		enemy_row.add_child(enemy_box)
		enemy_intent_labels.append(enemy_box.get_node("Intent"))
		enemy_hp_bars.append(enemy_box.get_node("HPBar"))
		enemy_hp_labels.append(enemy_box.get_node("HPLabel"))
		enemy_status_labels.append(enemy_box.get_node("Status"))
		enemy_guard_badges.append(enemy_box.get_node("Guard"))
		enemy_vulnerable_badges.append(enemy_box.get_node("Vulnerable"))
		var target: ColorRect = enemy_box.get_node("Target")
		target.gui_input.connect(_on_enemy_input.bind(index))
		enemy_blocks.append(target)
		var sprite: TextureRect = target.get_node("Sprite")
		sprite.texture = _enemy_art(index)
		sprite.set_meta("rest_position", sprite.position)
		enemy_sprites.append(sprite)
		enemy_frames.append(target.get_node("Frame"))
		enemy_box.get_node("NameLabel").text = _enemy_name(index)
		var idle := create_tween().set_loops()
		idle.tween_property(sprite, "scale", Vector2(1.012, 1.012), 1.1 + index * 0.12).set_trans(Tween.TRANS_SINE)
		idle.tween_property(sprite, "scale", Vector2.ONE, 1.1 + index * 0.12).set_trans(Tween.TRANS_SINE)
		enemy_idle_tweens.append(idle)


func _enemy_floating_text(index: int, caption: String, tint: Color, row: int = 0) -> void:
	if index >= 0 and index < enemy_sprites.size():
		Feedback.enemy_text(enemy_blocks[index], caption, tint, row)


func _animate_enemy_hit(index: int) -> void:
	enemy_feedback_tweens[index] = Feedback.hit(enemy_sprites[index], enemy_feedback_tweens.get(index))


func _enemy_action_effect(index: int, kind: String, tint: Color) -> void:
	Feedback.enemy_effect(enemy_blocks[index], kind, tint)


func _animate_enemy_action(index: int, kind: String) -> void:
	enemy_feedback_tweens[index] = Feedback.action(enemy_sprites[index], enemy_blocks[index], kind, enemy_feedback_tweens.get(index))


func _animate_enemy_death(index: int) -> void:
	enemy_feedback_tweens[index] = Feedback.death(enemy_sprites[index], enemy_idle_tweens[index], enemy_feedback_tweens.get(index))


func _player_floating_text(caption: String, tint: Color, slot: int = 0) -> void:
	Feedback.player_text($BattleUI, caption, tint, slot)


func _enemy_art(index: int = -1) -> Texture2D:
	if RunState.finale_state == "battle":
		return load("res://art/story/finale/former_master_v1.png")
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
	if RunState.finale_state == "battle":
		return "故人 · 缚魂剑主"
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
	if (played_card == CardType.FLOWING_CLOUD and flowing_cloud_active) or (played_card == CardType.RETAIN_SHIELD and retain_shield_active) or (played_card == CardType.TUNE_BREATH and tune_breath_used_this_turn):
		return
	var cost := _card_cost(played_card)
	if not _can_pay(cost):
		return
	if played_card in [CardType.ATTACK, CardType.HEAVY_ATTACK, CardType.COMBO_BOOST, CardType.BREAK_EDGE, CardType.UNLOAD_FORCE, CardType.CHASE_WIND, CardType.SHIELD_STRIKE]:
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
		CardType.FLOWING_CLOUD:
			energy -= cost
			flowing_cloud_active = true
			message_label.text = "行云：本场每回合首次三连攻，抽1张并恢复1精力"
			_finish_action()
		CardType.RETAIN_SHIELD:
			energy -= cost
			retain_shield_active = true
			message_label.text = "留盾：剩余护盾跨回合保留"
			_finish_action()
		CardType.PARRY:
			parry_active = true
			_play_defense_card(cost, CardDatabase.get_number(CardDatabase.PARRY, "block"))
			message_label.text += "；回锋：本轮反击至多%d次" % parry_reaction_limit


func _commit_hand_card(index: int) -> void:
	_record_player_card(int(hand[index]))
	resolving_hand_card = int(hand[index])
	hand_buttons[index].hide()
	if CardDatabase.get_definition(int(hand[index])).get("type", "") != "能力":
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
	var cost := _card_cost(card_type)
	if not _can_pay(cost):
		return
	pending_attack_index = -1
	last_target_index = enemy_index
	_commit_hand_card(card_index)
	if card_type == CardType.HEAVY_ATTACK:
		_play_attack_card(cost, heavy_attack_base_damage, enemy_index)
	elif card_type == CardType.CHASE_WIND:
		_play_attack_card(cost, CardDatabase.get_number(CardDatabase.CHASE_WIND, "damage"), enemy_index)
	elif card_type == CardType.SHIELD_STRIKE:
		_play_shield_strike_card(cost, enemy_index)
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
		_consume_parry_combo(special_combo_cost, "skill")
		message_label.text = "流光攻击敌人%d，造成 %d 伤害，消耗 %d 层连击" % [
			enemy_index + 1,
			damage,
			special_combo_cost,
		]
	else:
		_record_player_card(CardDatabase.BRILLIANCE)
		energy -= ultimate_energy_cost
		_record_bond_skill_use("华彩")
		var damage := ultimate_damage + combo * attack_combo_bonus
		_damage_enemy_at(enemy_index, damage)
		combo = 0
		_consume_parry_combo(parry_injected_remaining, "skill")
		message_label.text = "华彩攻击敌人%d，造成 %d 伤害，连击清零" % [enemy_index + 1, damage]
		_show_ink_event()
	_finish_action()


func _show_flowing_light() -> void:
	ink_event.stop()
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


func _show_ink_event(is_finisher := true) -> void:
	if flowing_light_tween != null and flowing_light_tween.is_valid():
		flowing_light_tween.kill()
	flowing_light_cut_in.hide()
	ink_event.play(is_finisher)


func _show_companion_flash(card_id: String) -> void:
	# Animate the character already on the battlefield instead of a generic large cut-in.
	var portrait: TextureRect = $BattleUI/CompanionPanel/Portrait
	if companion_action_tween != null and companion_action_tween.is_valid():
		companion_action_tween.kill()
	portrait.position = companion_rest_position
	portrait.modulate = Color.WHITE
	var pose: String = CompanionActionEffect.POSES[card_id]
	portrait.texture = COMPANION_POSE_ART[pose]
	var pose_scale := 1.0 if pose == "gather" else 1.3
	portrait.scale = Vector2.ONE * pose_scale
	var kind: String = CompanionActionEffect.PROFILES[card_id][0]
	var tint := Color(CompanionActionEffect.PROFILES[card_id][1])
	companion_action_tween = create_tween()
	var attack := kind in ["slash", "dash", "frost", "resonance"]
	companion_action_tween.tween_property(portrait, "position:x", companion_rest_position.x + (24.0 if attack else -6.0), 0.12)
	companion_action_tween.parallel().tween_property(portrait, "modulate", Color.WHITE.lerp(tint, 0.35), 0.12)
	companion_action_tween.tween_interval(0.25)
	companion_action_tween.tween_property(portrait, "position", companion_rest_position, 0.35)
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


func _play_attack_card(cost: int, base_damage: int, target_index: int) -> void:
	energy -= cost
	var damage := base_damage + combo * attack_combo_bonus
	damage = _apply_pending_boon_to_player_attack(damage)
	_damage_enemy_at(target_index, damage)
	combo += 1
	message_label.text = "攻击敌人%d，造成 %d 伤害，连击 +1" % [target_index + 1, damage]
	_finish_action()


func _play_shield_strike_card(cost: int, target_index: int) -> void:
	energy -= cost
	var base_damage := floori(block * CardDatabase.get_number(CardDatabase.SHIELD_STRIKE, "shield_percent") / 100.0)
	var damage := _apply_pending_boon_to_player_attack(base_damage)
	_damage_enemy_at(target_index, damage)
	combo += 1
	message_label.text = "护盾攻击：以 %d 护盾攻击敌人%d，连击 +1" % [block, target_index + 1]
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
		AttackSegments.reduce_next(enemy_intents[target_index], unload_force_reduction)
	else:
		enemy_attack_reductions[target_index] += unload_force_reduction
	message_label.text = "拨千斤：敌人%d下一段攻击伤害降低 %d" % [target_index + 1, unload_force_reduction]
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
	_gain_block(hide_edge_block, "player")
	preserve_combo_this_turn = true
	message_label.text = "藏锋：获得 %d 格挡，本回合结束保留连击" % hide_edge_block
	_finish_action()


func _play_defense_card(cost: int, block_amount: int) -> void:
	energy -= cost
	_gain_block(block_amount, "player")
	if cut_water_active:
		if combo > 0:
			_use_cooperation_window()
		message_label.text = "获得 %d 格挡；断水生效，连击保留" % block_amount
	else:
		_consume_parry_combo(parry_injected_remaining, "defense")
		combo = 0
		message_label.text = "获得 %d 格挡，连击清零" % block_amount
	_finish_action()


func _play_status_card(hand_index: int, cost: int) -> void:
	energy -= cost
	if cut_water_active:
		if combo > 0:
			_use_cooperation_window()
		_draw_card_into_slot(hand_index)
		message_label.text = "抽取 1 张牌；断水生效，连击保留"
	else:
		_consume_parry_combo(parry_injected_remaining, "other")
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
	_record_companion_selection("prepare", context, options, choice)
	locked_companion_choice = choice
	locked_companion_choice["plan"] = CompanionTactics.cooperation_plan(context, str(choice["card_id"]))
	companion_turn_pending = false
	_refresh_locked_companion_intent()
	companion_reason_label.tooltip_text = companion_intent_notice
	_refresh_ui()


func _process(_delta: float) -> void:
	# 场景决定起点与宽度，文本决定高度；只在纵向排列内容。
	var expand_button: Button = $BattleUI/CompanionPanel/ExpandDialogue
	var effect: Label = $BattleUI/CompanionPanel/Effect
	var bubble: Panel = $BattleUI/CompanionPanel/DialogueBackdrop
	var visible_lines := companion_reason_label.max_lines_visible
	expand_button.visible = visible_lines > 0 and companion_reason_label.get_line_count() > visible_lines
	var lines := companion_reason_label.get_line_count()
	if visible_lines > 0:
		lines = mini(lines, visible_lines)
	companion_reason_label.size.y = maxf(lines * companion_reason_label.get_line_height(), companion_reason_label.get_line_height())
	var next_y := companion_reason_label.position.y + companion_reason_label.size.y
	if expand_button.visible:
		expand_button.position.y = next_y + companion_dialogue_gap
		next_y = expand_button.position.y + expand_button.size.y
	effect.position.y = next_y + companion_dialogue_gap
	effect.size.y = maxf(effect.get_line_count() * effect.get_line_height(), effect.get_line_height())
	bubble.size.y = effect.position.y + effect.size.y + companion_bubble_bottom_padding - bubble.position.y


func _show_companion_dialogue() -> void:
	var popup := preload("res://ui/shared/dialogue_popup.tscn").instantiate()
	$BattleUI.add_child(popup)
	popup.get_node("Margin/Column/Reply").text = companion_reason_label.text
	popup.get_node("Margin/Column/Close").pressed.connect(popup.queue_free)
	popup.popup_hide.connect(popup.queue_free)
	popup.popup_centered(Vector2i(700, 360))


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
	elif plan.get("kind", "") == "charge_attack":
		condition = "\n蓄势：强化我下一次伤害技能。"
	companion_reason_label.text = "“%s”" % str(choice.get("reason", "这回合按计划来。"))
	$BattleUI/CompanionPanel/Effect.text = "%s%s" % [definition["description"], condition.replace("\n", " ")]
	if not companion_intent_notice.is_empty():
		$BattleUI/CompanionPanel/Effect.tooltip_text = companion_intent_notice


func _run_companion_turn() -> void:
	var choice := locked_companion_choice.duplicate(true)
	locked_companion_choice.clear()
	companion_intent_notice = ""
	while not battle_finished and _living_enemy_count() > 0:
		var context := _build_companion_context()
		context["can_build_combo"] = false
		context["bonus_action"] = companion_bonus_action
		context["affordable_attack_hits"] = 0
		context["hand_cards"] = "玩家已结束行动，不能继续出牌"
		var options := CompanionTactics.candidates(context, _allowed_companion_cards())
		if options.is_empty():
			options.assign([CompanionCards.GUARD_ECHO])
		if choice.is_empty():
			if not force_offline_companion:
				choice = await _request_companion_choice(context, options)
			if battle_finished or not is_inside_tree():
				return
			if choice.is_empty():
				choice = CompanionDirector.choose_fallback(context, options)
		elif str(choice.get("card_id", "")) not in options:
			choice = CompanionDirector.choose_fallback(context, options)
			choice["reason"] = "原定配合已失效或无法挡住致命伤害，我改用「%s」。" % CompanionCards.get_definition(str(choice["card_id"]))["name"]
			companion_intent_notice = str(choice["reason"])
		_record_companion_selection("execute", context, options, choice)
		_apply_companion_card(choice)
		if not companion_bonus_action or battle_finished:
			break
		choice = {}
		message_label.text = "十步击杀，小墨继续出招……"
		if not fixed_cooperation_test:
			await get_tree().create_timer(0.55).timeout


func _record_companion_selection(phase: String, context: Dictionary, options: Array[String], choice: Dictionary) -> void:
	var reference := CompanionDirector.choose_fallback(context, options)
	var record := {
		"version": "combo-phase-one-v1", "phase": phase,
		"run_id": RunState.run_id, "battle_index": battle_index,
		"turn": battle_turn_count + (1 if phase == "prepare" else 0),
		"bond_stage": RunState.get_bond_stage_index(),
		"learned_intents": RunState.learned_sword_intents.duplicate(),
		"candidates": options.duplicate(), "selected": str(choice.get("card_id", "")),
		"source": str(choice.get("source", "")),
		"fallback_selected": str(reference.get("card_id", "")),
		"combo": combo, "continuous_attacks": consecutive_attacks,
		"cloud_active": flowing_cloud_active, "player_hp": player_hp,
	}
	companion_selection_records.append(record)
	# 正式对局只写本地结构化数据，不记录提示词、台词或联网凭据。
	if fixed_cooperation_test or RunState.suppress_persistence:
		return
	BoundedLog.append("user://companion-selection.jsonl", record, selection_logging_enabled, selection_log_max_bytes)


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
			strongest = maxi(strongest, AttackSegments.total(enemy_intents[index]))
			attacking += 1
			for damage in AttackSegments.values(enemy_intents[index]): frost_prevention += mini(damage, int(CompanionCards.get_definition(CompanionCards.FROST_COLD)["weaken"]))
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
		"grind_sword_ready": grind_sword_ready, "few_return_used": few_return_used,
		"highest_enemy_hp": enemy_hps[highest_index] if highest_index >= 0 else 999999,
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
	companion_bonus_action = false
	companion_damage_multiplier = 1
	if int(definition.get("damage", 0)) > 0 and grind_sword_ready:
		companion_damage_multiplier = 2
		grind_sword_ready = false
	var target_index := _lowest_hp_enemy_index()
	var result_text := ""
	var combo_before := combo
	var incoming_before := _enemy_intent_damage_total()
	var block_before := block
	_show_companion_flash(card_id)
	if definition.has("effects"):
		result_text = _execute_companion_effects(definition)
	else:
		match card_id:
			CompanionCards.FROST_COLD:
				for index in range(enemy_hps.size()):
					if enemy_hps[index] <= 0:
						continue
					_damage_enemy_at(index, int(definition["damage"]) * companion_damage_multiplier)
					if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
						AttackSegments.reduce_each(enemy_intents[index], int(definition["weaken"]))
				last_target_index = -1
				result_text = "对全体敌人各造成 %d 伤害，它们本回合攻击 -%d" % [int(definition["damage"]) * companion_damage_multiplier, int(definition["weaken"])]
			CompanionCards.TEN_STEPS:
				var damage := int(definition["damage"]) + combo * int(definition["combo_scale"])
				damage *= companion_damage_multiplier
				_damage_enemy_at(target_index, damage)
				last_target_index = target_index
				result_text = "对敌人%d造成 %d 伤害" % [target_index + 1, damage]
				if target_index >= 0 and enemy_hps[target_index] <= 0:
					companion_bonus_action = _living_enemy_count() > 0
					result_text += "，击杀后立即再释放一次技能"
			CompanionCards.GRIND_SWORD:
				grind_sword_ready = true
				result_text = "积蓄剑势，小墨下次伤害技能伤害翻倍（不叠加）"
			CompanionCards.CUT_WATER:
				cut_water_active = true
				result_text = "玩家下回合防御或状态牌不会清空连击"
			CompanionCards.LONG_WIND:
				long_wind_bonus = int(definition["energy"])
				result_text = "玩家下回合精力 +%d" % long_wind_bonus
			CompanionCards.BEHEAD_LOULAN:
				var highest := _highest_hp_enemy_index()
				var damage := int(definition["damage"])
				damage *= companion_damage_multiplier
				_damage_enemy_at(highest, damage, true)
				last_target_index = highest
				result_text = "无视格挡，对生命最高的敌人%d造成 %d 伤害" % [highest + 1, damage]
			CompanionCards.YIN_MOUNTAIN:
				var strongest := -1
				for index in range(enemy_intents.size()):
					if enemy_hps[index] > 0 and enemy_intents[index]["type"] == EnemyIntent.ATTACK:
						if strongest < 0 or AttackSegments.total(enemy_intents[index]) > AttackSegments.total(enemy_intents[strongest]):
							strongest = index
				if strongest >= 0:
					var blocked := AttackSegments.total(enemy_intents[strongest])
					AttackSegments.intercept(enemy_intents[strongest])
					result_text = "挡下敌人%d本回合的攻击（%d）" % [strongest + 1, blocked]
				else:
					result_text = "本回合没有敌人要攻击，剑势落空"
			CompanionCards.FEW_RETURN:
				few_return_active = not few_return_used
				result_text = "本回合受到致命伤害时保留1点生命，并免疫剩余伤害" if few_return_active else "本场战斗已救险，不能再次发动"
	if card_id in [CompanionCards.TEN_STEPS, CompanionCards.LONE_JUDGMENT]:
		RunState.record_cooperation("finishers")
		RunState.record_cooperation("finisher_combo_total", combo_before)
	if (block > block_before and incoming_before > block_before) or (card_id in [CompanionCards.YIN_MOUNTAIN, CompanionCards.FROST_COLD] and _enemy_intent_damage_total() < incoming_before):
		RunState.record_cooperation("guards")
	if CompanionCards.is_investment(card_id) and card_id != CompanionCards.GRIND_SWORD:
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
	companion_damage_multiplier = 1
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()

# 状态的唯一写入者仍是战斗；解析器只根据显式输入计算一项效果。
func _execute_companion_effects(definition: Dictionary) -> String:
	var target_index := -1
	if str(definition.get("target", CompanionCards.TARGET_NONE)) == CompanionCards.TARGET_LOWEST_HP:
		target_index = _lowest_hp_enemy_index()
	var result := {"target": target_index + 1, "damage": 0, "block": 0, "boon": ""}
	for authored_effect in definition["effects"]:
		var effect := CompanionEffects.resolve(authored_effect, definition, {
			"combo": combo, "promise": RunState.active_promise,
			"damage_multiplier": companion_damage_multiplier,
		})
		match str(effect["kind"]):
			CompanionCards.EFFECT_DAMAGE:
				var damage := int(effect["amount"])
				_damage_enemy_at(target_index, damage)
				last_target_index = target_index
				result["damage"] = damage
			CompanionCards.EFFECT_BLOCK:
				var gained_block := int(effect["amount"])
				_gain_block(gained_block, "companion")
				companion_block_this_turn += gained_block
				result["block"] = gained_block
			CompanionCards.EFFECT_COMBO:
				match str(effect["mode"]):
					CompanionCards.COMBO_ADD:
						combo += int(effect["amount"])
					CompanionCards.COMBO_CLEAR:
						_consume_parry_combo(parry_injected_remaining, "other")
						combo = 0
					CompanionCards.COMBO_PRESERVE:
						preserve_combo_this_turn = true
			CompanionCards.EFFECT_BOON:
				pending_boon = effect["boon"]
				result["boon"] = "%.1f" % float(pending_boon["value"]) if pending_boon["type"] == "multiply" else str(pending_boon["value"])
	return str(definition["result_template"]).format(result)


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
			total += AttackSegments.total(enemy_intents[index])
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
	combo_telemetry.observe_combo(combo, "companion")
	var block_at_start := block
	var hp_at_start := player_hp
	var expected_damage := _enemy_intent_damage_total()
	var damage_without_companion := maxi(expected_damage - maxi(block_at_start - companion_block_this_turn, 0), 0)
	if not companion_save_recorded and companion_block_this_turn > 0 and damage_without_companion >= player_hp and maxi(expected_damage - block_at_start, 0) < player_hp:
		companion_save_recorded = true
		RunState.record_moment("第%d场，敌人那一轮本来足以击倒只剩 %d 血的你，是小墨的格挡替你接住了。" % [battle_index, player_hp], 4)
	var few_return_before := few_return_used
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
		if player_hp <= 0 or _living_enemy_count() == 0: break
		if enemy_hps[index] <= 0:
			continue
		var intent := enemy_intents[index]
		match intent["type"]:
			EnemyIntent.ATTACK:
				var parts := AttackSegments.values(intent)
				if bool(intent.get("intercepted", false)):
					_record_enemy_action({"enemy": index, "type": "attack", "executed": false, "reason": "intercepted"})
				for part_index in range(parts.size()):
					if player_hp <= 0 or enemy_hps[index] <= 0: break
					var damage := parts[part_index]
					incoming_damage += damage
					_animate_enemy_action(index, "attack")
					_resolve_enemy_attack_segment(index, part_index, damage)
					action_messages.append("敌人%d攻击%d" % [index + 1, damage] if parts.size() == 1 else "敌人%d第%d段攻击%d" % [index + 1, part_index + 1, damage])
			EnemyIntent.DEFEND:
				_record_enemy_action({"enemy": index, "type": "defend", "executed": true})
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
				_record_enemy_action({"enemy": index, "type": "enhance", "executed": true})
				enemy_strengths[index] = intent["value"]
				action_messages.append("敌人%d强化，攻击力+%d" % [index + 1, intent["value"]])
			EnemyIntent.CURSE:
				_record_enemy_action({"enemy": index, "type": "curse", "executed": true})
				_animate_enemy_action(index, "curse")
				_enemy_floating_text(index, "心魔 +1", Color("#bf9de8"))
				discard_pile.append(CardType.CURSE)
				action_messages.append("敌人%d往你牌组里塞了一张心魔" % (index + 1))
			EnemyIntent.OTHER:
				_record_enemy_action({"enemy": index, "type": "other", "executed": true})
				action_messages.append("敌人%d观望" % (index + 1))
	# 玩家与小墨均使用本轮易伤，敌方行动结算后统一衰减。
	for index in range(enemy_vulnerabilities.size()):
		enemy_vulnerabilities[index] = maxi(enemy_vulnerabilities[index] - 1, 0)
	var damage_taken := hp_at_start - player_hp
	var shield_absorbed := block_at_start - block
	if shield_absorbed > 0:
		_player_floating_text("护盾吸收 %d" % shield_absorbed, Color("#74c7bd"), 2)
	if not combo_telemetry.current.is_empty():
		combo_telemetry.current["enemy_incoming"] = incoming_damage
		combo_telemetry.current["block_consumed"] = shield_absorbed
		combo_telemetry.current["block_expired"] = 0 if retain_shield_active else block
		if retain_shield_active:
			combo_telemetry.current["block_carried"] = block
			combo_telemetry.current["retain_active"] = true
		combo_telemetry.current["life_lost"] = damage_taken
	if parry_injected_remaining > 0:
		var outcome := "battle_end" if player_hp <= 0 or _living_enemy_count() == 0 else ("preserved" if preserve_combo_this_turn else "expired")
		_consume_parry_combo(parry_injected_remaining, outcome)
	if parry_pending_combo > 0 and (player_hp <= 0 or _living_enemy_count() == 0):
		combo_telemetry.current["parry_award_not_injected"] = parry_pending_combo
	combo_telemetry.finish_round(_visible_wind_count(), "end_turn")
	if not retain_shield_active: block = 0
	companion_block_this_turn = 0
	var few_return_triggered := few_return_used and not few_return_before
	if damage_taken > 0:
		_player_floating_text("-%d 生命" % damage_taken, Color("#e89584"))
		player_status.flash_damage()
	RunState.set_player_hp(player_hp)
	RunState.record_player_hp()
	if player_hp <= 0:
		_end_battle(false)
		return
	if _living_enemy_count() == 0:
		_end_battle(true)
		return
	few_return_active = false
	few_return_immune = false
	energy = max_energy + long_wind_bonus
	long_wind_bonus = 0
	var combo_was_preserved := preserve_combo_this_turn
	if not preserve_combo_this_turn:
		combo = 0
	var injected := parry_pending_combo
	combo += injected
	parry_injected_remaining = injected
	parry_pending_combo = 0
	parry_active = false
	parry_reactions = 0
	parry_combo_awards = 0
	preserve_combo_this_turn = false
	tune_breath_used_this_turn = false
	consecutive_attacks = 0
	flowing_cloud_triggered = false
	turn_player_cards.clear()
	_discard_remaining_hand()
	_draw_new_hand()
	if player_hp > 0:
		combo_telemetry.begin_round(battle_turn_count + 1, combo, flowing_cloud_active, RunState.get_bond_stage_index() >= ultimate_bond_stage_required, _visible_wind_count())
		combo_telemetry.current["cloud_in_hand"] = _visible_cloud_count()
		if injected > 0: combo_telemetry.current["parry_injected"] = injected
		if retain_shield_active:
			combo_telemetry.current["starting_block"] = block
			combo_telemetry.current["retain_active"] = true
	_assess_cooperation_window()
	var combo_result := "藏锋生效，保留连击" if combo_was_preserved else "连击清零"
	if injected > 0: combo_result += "；回锋注入%d连击" % injected
	var guard_result := "；几人回救险，保留1点生命" if few_return_triggered else ""
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


func _resolve_enemy_attack_segment(enemy_index: int, segment_index: int, damage: int) -> void:
	var absorbed := mini(block, damage)
	block -= absorbed
	var life_lost := maxi(damage - absorbed, 0)
	if few_return_immune:
		life_lost = 0
	elif life_lost >= player_hp and player_hp > 0 and few_return_active and not few_return_used:
		life_lost = player_hp - 1
		few_return_used = true
		few_return_immune = true
		few_return_active = false
		RunState.record_moment("第%d场，本该倒下的那一击，小墨用「几人回」替你留住了最后一口气。" % battle_index, 4)
	life_lost = mini(life_lost, player_hp)
	player_hp -= life_lost
	battle_damage_taken += life_lost
	_record_enemy_action({"enemy": enemy_index, "type": "attack", "segment": segment_index, "executed": true, "damage": damage, "absorbed": absorbed, "life_lost": life_lost, "survived": player_hp > 0})
	if player_hp > 0:
		enemy_attack_segment_resolved.emit(enemy_index, damage, absorbed, life_lost)


func _on_parry_attack_segment(enemy_index: int, _damage: int, _absorbed: int, _lost: int) -> void:
	if not parry_active or player_hp <= 0 or enemy_hps[enemy_index] <= 0 or parry_reactions >= parry_reaction_limit:
		return
	parry_reactions += 1
	var hp_before := enemy_hps[enemy_index]
	_damage_enemy_at(enemy_index, CardDatabase.get_number(CardDatabase.PARRY, "reaction_damage"))
	battle_parry_damage += hp_before - enemy_hps[enemy_index]
	var reward := 0
	if parry_combo_awards < parry_combo_limit:
		reward = 1
		parry_combo_awards += 1
		parry_pending_combo += 1
	_record_enemy_action({"enemy":enemy_index,"type":"parry","executed":true,"damage":hp_before-enemy_hps[enemy_index],"combo_award":reward,"reaction":parry_reactions})
	if not combo_telemetry.current.is_empty():
		combo_telemetry.current["parry_reactions"] = parry_reactions
		combo_telemetry.current["parry_awarded"] = parry_combo_awards


func _consume_parry_combo(amount: int, outcome: String) -> void:
	var used := mini(amount, parry_injected_remaining)
	if used <= 0: return
	parry_injected_remaining -= used
	if not combo_telemetry.current.is_empty():
		var field := "parry_combo_" + outcome
		combo_telemetry.current[field] = int(combo_telemetry.current.get(field,0)) + used


func _reset_parry_state() -> void:
	parry_active = false
	parry_reactions = 0
	parry_combo_awards = 0
	parry_pending_combo = 0
	parry_injected_remaining = 0


func _record_enemy_action(event: Dictionary) -> void:
	if combo_telemetry.current.is_empty(): return
	if not combo_telemetry.current.has("enemy_actions"): combo_telemetry.current["enemy_actions"] = []
	combo_telemetry.current["enemy_actions"].append(event)


func _gain_block(amount: int, source: String) -> void:
	block += amount
	if combo_telemetry.current.is_empty(): return
	var field := "block_gained_" + source
	combo_telemetry.current[field] = int(combo_telemetry.current.get(field, 0)) + amount


func _deck_roll(low: int, high: int) -> int:
	random_call_counts["deck"] += 1
	return deck_rng.randi_range(low, high)


func _enemy_roll(low: int, high: int) -> int:
	random_call_counts["enemy"] += 1
	return enemy_rng.randi_range(low, high)


func _can_pay(cost: int) -> bool:
	if battle_finished or companion_turn_pending:
		return false
	if energy < cost:
		message_label.text = "精力不足"
		_refresh_ui()
		return false
	return true


func _card_cost(card_type: CardType) -> int:
	if card_type == CardType.CHASE_WIND:
		return maxi(CardDatabase.get_cost(int(card_type)) - consecutive_attacks, 0)
	return CardDatabase.get_cost(int(card_type))


func _damage_enemy_at(target_index: int, damage: int, ignore_guard: bool = false) -> void:
	if target_index >= 0:
		if combo > 0 and cooperation_windows.has("resource"):
			var source := str(cooperation_windows["resource"].get("source", ""))
			if source in [CompanionCards.HEART_RESONANCE] and not companion_turn_pending and not bool(cooperation_windows["resource"].get("lost", false)):
				_use_cooperation_window()
		var hp_before := enemy_hps[target_index]
		damage += enemy_vulnerabilities[target_index]
		var absorbed := 0 if ignore_guard else mini(enemy_guards[target_index], damage)
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
	var planned := IntentPlanner.roll({
		"fixed": fixed_cooperation_test, "boss": _is_boss_battle(),
		"elite": RunState.pending_encounter == RunState.EncounterType.ELITE,
		"layer": RunState.route_layer, "hps": enemy_hps, "max_hps": enemy_max_hps,
		"roles": enemy_roles, "strengths": enemy_strengths, "reductions": enemy_attack_reductions,
		"boss_step": boss_action_step, "boss_hits": boss_charge_hits, "role_step": enemy_action_step,
	}, _enemy_roll)
	enemy_intents.assign(planned.intents)
	enemy_attack_reductions.assign(planned.reductions)
	boss_action_step = planned.boss_step
	boss_charge_hits = planned.boss_hits
	enemy_action_step = planned.role_step


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
	_deck.reset(RunState.deck, _deck_roll)
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
	if card == CardType.FLOWING_CLOUD and not combo_telemetry.current.is_empty():
		combo_telemetry.current["cloud_in_hand"] = int(combo_telemetry.current.get("cloud_in_hand", 0)) + 1
	if card == CardType.CHASE_WIND and not combo_telemetry.current.is_empty():
		combo_telemetry.current["wind_drawn"] = int(combo_telemetry.current.get("wind_drawn", 0)) + 1


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
	return _deck.take_top(_deck_roll)


func _finish_action() -> void:
	_resolve_consecutive_attack()
	if not telemetry_action.is_empty():
		combo_telemetry.record_action(int(telemetry_action["card_id"]), int(telemetry_action["cost"]), int(telemetry_action["combo"]), combo, flowing_cloud_active, _visible_wind_count(), RunState.deck.count(CardDatabase.CHASE_WIND))
		telemetry_action.clear()
	if combo == 0 and cooperation_windows.has("resource") and str(cooperation_windows["resource"].get("source", "")) in [CompanionCards.HEART_RESONANCE]:
		cooperation_windows["resource"]["lost"] = true
	if cooperation_windows.has("resource") and str(cooperation_windows["resource"].get("source", "")) == CompanionCards.LONG_WIND and energy < int(CompanionCards.get_definition(CompanionCards.LONG_WIND)["energy"]):
		_use_cooperation_window()
	if _living_enemy_count() == 0:
		_end_battle(true)
	else:
		_refresh_ui()


func _resolve_consecutive_attack() -> void:
	if resolving_hand_card < 0:
		return
	var card_id := resolving_hand_card
	resolving_hand_card = -1
	if CardDatabase.get_definition(card_id).get("type", "") != "攻击":
		consecutive_attacks = 0
		return
	consecutive_attacks += 1
	if not flowing_cloud_active or flowing_cloud_triggered or consecutive_attacks != CardDatabase.get_number(CardDatabase.FLOWING_CLOUD, "trigger_count"):
		return
	# 胜负已决定时不再抽牌或返还精力。
	if battle_finished or _living_enemy_count() == 0:
		return
	flowing_cloud_triggered = true
	if not combo_telemetry.current.is_empty():
		combo_telemetry.current["cloud_triggers"] += 1
	_draw_cards_into_empty_slots(CardDatabase.get_number(CardDatabase.FLOWING_CLOUD, "draw"))
	if flowing_cloud_refunds_energy:
		energy += CardDatabase.get_number(CardDatabase.FLOWING_CLOUD, "energy")
	message_label.text += "；行云：抽1张%s" % ("，恢复1精力" if flowing_cloud_refunds_energy else "")


func _shuffle_draw_pile() -> void:
	_deck.shuffle(_deck_roll)


func _end_battle(player_won: bool) -> void:
	if battle_finished:
		return
	battle_finished = true
	_consume_parry_combo(parry_injected_remaining, "battle_end")
	combo_telemetry.observe_combo(combo, "companion_or_last_action")
	combo_telemetry.finish_battle(_visible_wind_count())
	if not fixed_cooperation_test and not RunState.suppress_persistence:
		var metrics := combo_telemetry.summary()
		metrics["run_id"] = RunState.run_id
		metrics["battle_index"] = battle_index
		metrics["version"] = "combo-phase-one-v2"
		metrics["won"] = player_won
		metrics["damage"] = battle_damage_dealt
		metrics["loss"] = battle_damage_taken
		BoundedLog.append("user://combo-battles.jsonl", metrics, selection_logging_enabled, selection_log_max_bytes)
	consecutive_attacks = 0
	flowing_cloud_active = false
	retain_shield_active = false
	_reset_parry_state()
	flowing_cloud_triggered = false
	resolving_hand_card = -1
	intent_generation += 1
	block = 0
	# 战斗已结束的未使用机会不是玩家浪费。
	cooperation_windows.clear()
	if fixed_cooperation_test or offline_experiment:
		companion_turn_pending = false
		companion_status_label.text = "实验战斗：胜利" if player_won else "实验战斗：失败"
		companion_reason_label.text = "按 R 重开固定战斗。此场景不写入正式存档。"
		_refresh_ui()
		return
	RunState.set_player_hp(player_hp)
	if RunState.finale_state == "battle":
		RunState.set_finale_state("story", "victory" if player_won else "sacrifice")
		_refresh_ui()
		await get_tree().create_timer(0.8).timeout
		RunState.navigate("finale", self)
		return
	_record_battle_journal(player_won)
	RunState.record_battle_result(player_won)
	_record_battle_moments(player_won)
	RunState.add_bond(BalanceConfig.BATTLE_BOND_GAIN)
	if player_won:
		message_label.text = "胜利"
		print("胜利")
		var victory_delay := 1.65 if ink_event.visible else 1.0
		if RunState.pending_encounter == RunState.EncounterType.BOSS:
			if player_hp * 4 <= player_max_hp:
				if not ink_event.visible:
					_show_ink_event(false)
				victory_delay = 1.65
			SpecialEventManager.evaluate_boss_victory(
				player_hp,
				player_max_hp,
				bond_skill_comeback,
				RunState.consecutive_run_failures
			)
			RunState.settle_act_promise()
			print("远征通关")
			RunState.finish_run(true)
			RunState.set_post_battle_route("settlement")
		else:
			RunState.set_post_battle_route("map")
		RunState.checkpoint("reward")
		_return_to_reward_after_delay(victory_delay)
	else:
		message_label.text = "失败"
		print("失败")
		RunState.finish_run(false)
		RunState.checkpoint("settlement")
	_refresh_ui()
	if not player_won:
		_return_to_settlement_after_delay()


func _return_to_reward_after_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	RunState.navigate("reward", self)


func _return_to_settlement_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	RunState.navigate("settlement", self)


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
					if intent.has("segments") and not bool(intent.get("intercepted",false)):
						var parts: Array[String] = []
						for part in AttackSegments.values(intent): parts.append(str(part))
						enemy_intent_labels[index].text = "⚔  攻击 " + " + ".join(parts)
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
	combo_label.text = "连击  %d · 连续攻击 %d" % [combo, consecutive_attacks]
	player_hp_label.text = "生命  %d / %d" % [player_hp, player_max_hp]
	energy_label.text = "精力: %d/%d" % [energy, max_energy]
	block_label.text = "格挡: %d%s" % [block, _pending_boon_ui_text()]
	player_status.update_values(player_hp, player_max_hp, energy, max_energy, block, combo, _pending_boon_ui_text())
	player_status.update_attack_chain(consecutive_attacks, flowing_cloud_active, flowing_cloud_triggered)
	if displayed_player_block >= 0 and block > displayed_player_block:
		_player_floating_text("+%d 护盾" % (block - displayed_player_block), Color("#74c7bd"), 2)
	displayed_player_block = block
	draw_pile_label.text = "牌堆\n%d" % draw_pile.size()
	discard_pile_label.text = "弃牌堆\n%d" % discard_pile.size()

	for index in range(hand_buttons.size()):
		if index < hand.size():
			var face = hand_buttons[index].get_node("PaintedFace")
			face.set_effective_cost(_card_cost(hand[index]))
			hand_buttons[index].tooltip_text = CardDatabase.get_battle_text(int(hand[index])) + "\n当前费用：%d" % _card_cost(hand[index])
		hand_buttons[index].disabled = (
			battle_finished
			or companion_turn_pending
			or index >= hand.size()
			or hand[index] == CardType.CURSE
			or (hand[index] == CardType.TUNE_BREATH and tune_breath_used_this_turn)
			or (hand[index] == CardType.FLOWING_CLOUD and flowing_cloud_active)
			or (hand[index] == CardType.RETAIN_SHIELD and retain_shield_active)
			or energy < _card_cost(hand[index])
		)
		preload("res://scripts/ui/battle_art_skin.gd").select_card(hand_buttons[index], index == pending_attack_index)
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
	special_button.text = "流光%s\n基础伤害 %d · 精力 %d" % [" · 已选中" if pending_skill_target == 1 else "", special_damage, special_energy_cost]
	ultimate_button.text = "华彩%s\n基础伤害 %d · 精力 %d" % [" · 已选中" if pending_skill_target == 2 else "", ultimate_damage, ultimate_energy_cost]
	special_button.tooltip_text = "流光：基础伤害 %d；消耗 %d 精力、%d 层连击。需 %d 层连击，羁绊阶段 %d 解锁。" % [special_damage, special_energy_cost, special_combo_cost, special_combo_required, special_bond_stage_required]
	ultimate_button.tooltip_text = "华彩：基础伤害 %d；消耗 %d 精力，连击清零。需 %d 层连击，羁绊阶段 %d 解锁。" % [ultimate_damage, ultimate_energy_cost, ultimate_combo_required, ultimate_bond_stage_required]
	preload("res://scripts/ui/battle_art_skin.gd").select_skill(special_button, pending_skill_target == 1)
	preload("res://scripts/ui/battle_art_skin.gd").select_skill(ultimate_button, pending_skill_target == 2)
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
	var cost := _card_cost(card_id as CardType) if card_id not in [CardDatabase.FLOWING_LIGHT, CardDatabase.BRILLIANCE] else CardDatabase.get_cost(card_id)
	telemetry_action = {"card_id": card_id, "cost": cost, "combo": combo}
	var card_name := CardDatabase.get_card_name(card_id)
	turn_player_cards.append(card_name)
	battle_player_card_counts[card_name] = int(battle_player_card_counts.get(card_name, 0)) + 1


func _visible_wind_count() -> int:
	var count := 0
	for index in range(hand.size()):
		if hand[index] == CardType.CHASE_WIND and index < hand_buttons.size() and hand_buttons[index].visible:
			count += 1
	return count


func _visible_cloud_count() -> int:
	var count := 0
	for index in range(hand.size()):
		if hand[index] == CardType.FLOWING_CLOUD and index < hand_buttons.size() and hand_buttons[index].visible:
			count += 1
	return count


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
		extra += "　断水：本回合防御/状态不断连击"
	if long_wind_bonus > 0:
		extra += "　长风：下回合精力 +%d" % long_wind_bonus
	if grind_sword_ready:
		extra += "　磨剑：小墨下次伤害 ×2"
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
	pile_popup = $BattleUI/PilePopup
	pile_popup_title = $BattleUI/PilePopup/Margin/Column/Title
	pile_popup_text = $BattleUI/PilePopup/Margin/Column/Empty
	pile_grid = $BattleUI/PilePopup/Margin/Column/Contents/Cards
	InkUISkin.style_button($BattleUI/PilePopup/Margin/Column/Close)
	$BattleUI/PilePopup/Margin/Column/Close.pressed.connect(pile_popup.hide)


func _on_pile_input(event: InputEvent, show_draw_pile: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_pile_contents(show_draw_pile)


func _show_pile_contents(show_draw_pile: bool) -> void:
	var pile: Array[CardType] = draw_pile if show_draw_pile else discard_pile
	pile_popup_title.text = "牌堆（%d）" % pile.size() if show_draw_pile else "弃牌堆（%d）" % pile.size()
	for child in pile_grid.get_children():
		pile_grid.remove_child(child)
		child.queue_free()
	pile_popup_text.visible = pile.is_empty()
	pile_popup_text.text = "这里暂时没有卡牌。"
	# 展示全部副本，排序仅用于浏览，不泄露抽牌顺序。
	var display_cards := pile.duplicate()
	display_cards.sort()
	for card_type in display_cards:
		var face := preload("res://scripts/ui/card_face.gd").new()
		face.custom_minimum_size = Vector2(200, 280)
		pile_grid.add_child(face)
		face.set_player_card(int(card_type))
	$BattleUI/PilePopup/Margin/Column/Contents.scroll_vertical = 0
	pile_popup.popup_centered(Vector2i(1180, 760))


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
	elif source in [CompanionCards.HEART_RESONANCE]:
		available = attack and combo > 0
	cooperation_windows["resource"]["available"] = available


func _unhandled_key_input(event: InputEvent) -> void:
	if fixed_cooperation_test and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		RunState.set_player_hp(RunState.player_max_hp)
		start_battle()
