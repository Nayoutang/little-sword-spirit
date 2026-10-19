extends Node2D

const CardFace = preload("res://scripts/ui/card_face.gd")
const RewardSkin = preload("res://scripts/ui/ink_ui_skin.gd")
const Road = preload("res://scripts/data/road_events.gd")
const Relics = preload("res://scripts/data/relic_database.gd")

# 事件奖励数值集中在这里。
var heal_amount := RunState.rest_heal(BalanceConfig.EVENT_HEAL_AMOUNT)
var max_hp_increase := BalanceConfig.EVENT_MAX_HP_INCREASE
var card_choice_count := 3
var finishing := false
# 问号节点：本次路遇事件与选择后待展示的结果。
var road_event_id := ""
var road_line := ""
var road_notes: Array[String] = []
var road_choice := ""
var road_buttons: Array[Button] = []
var removal_scroll: ScrollContainer
var upgrade_scroll: ScrollContainer
var continue_button: Button
var relic_view: Node
@onready var skip_button: Button = $EventUI/SkipCard

@onready var hp_label: Label = $EventUI/HPLabel
@onready var message_label: Label = $EventUI/Message
@onready var main_choices: VBoxContainer = $EventUI/MainChoices
@onready var card_choices: HBoxContainer = $EventUI/CardChoices

func _ready() -> void:
	preload("res://scripts/ui/save_exit_button.gd").install(self, $EventUI, Vector2(1330, 24))
	preload("res://scripts/ui/card_library.gd").install_deck_view(self, $EventUI, Vector2(1600, 24))
	relic_view = preload("res://scripts/ui/relic_view.gd").install(self, $EventUI, Vector2(1080, 24))
	$EventUI/MainChoices/Heal.pressed.connect(_choose_heal)
	$EventUI/MainChoices/MaxHP.pressed.connect(_choose_max_hp)
	$EventUI/MainChoices/Card.pressed.connect(_show_card_choices)
	card_choices.hide()
	skip_button.pressed.connect(_on_skip_pressed)
	_refresh_hp()
	var saved := RunState.room_checkpoint("event")
	if saved.has("road_event"):
		_restore_road_state(saved)
	if saved.get("removing", false):
		_show_removal_choices()
	elif saved.get("upgrading", false):
		_show_upgrade_choices()
	elif saved.get("card_choices", false):
		_show_card_choices(bool(saved.get("rare", false)))
	elif RunState.pending_event == RunState.EventType.UNKNOWN:
		_resolve_unknown_event()
	else:
		_add_relic_choice()


# 宝箱第四个选项：随机取一件本趟还没有的信物。
func _add_relic_choice() -> void:
	for child in main_choices.get_children():
		(child as Button).custom_minimum_size = Vector2(600, 70)
	main_choices.add_theme_constant_override("separation", 16)
	var button := Button.new()
	button.name = "Relic"
	button.text = "取一件信物"
	button.custom_minimum_size = Vector2(600, 70)
	RewardSkin.style_button(button)
	button.disabled = Relics.roll(RunState.run_relics).is_empty()
	button.pressed.connect(_choose_relic)
	main_choices.add_child(button)
	# 磨剑：升级一张牌。
	var grind := Button.new()
	grind.name = "Grind"
	grind.text = "磨剑：升级一张牌"
	grind.custom_minimum_size = Vector2(600, 70)
	RewardSkin.style_button(grind)
	grind.disabled = not RunState.has_upgradable_card()
	grind.pressed.connect(_show_upgrade_choices)
	main_choices.add_child(grind)
	# 五个选项：收紧一点，免得最后一个压到卷轴边。
	main_choices.add_theme_constant_override("separation", 8)
	for child in main_choices.get_children():
		(child as Button).custom_minimum_size = Vector2(600, 60)
	main_choices.position.y -= 24


func _choose_relic() -> void:
	if finishing:
		return
	var id := Relics.roll(RunState.run_relics)
	if not RunState.gain_relic(id):
		return
	var gained := Relics.describe(id)
	# 剑境三起：宝箱一次给两件。
	if RunState.sword_realm >= 3:
		var extra := Relics.roll(RunState.run_relics)
		if RunState.gain_relic(extra):
			gained += "、" + Relics.describe(extra)
	if relic_view != null:
		relic_view.refresh()
	_finish_event("获得信物%s" % gained)


func _on_skip_pressed() -> void:
	if upgrade_scroll != null and upgrade_scroll.visible:
		if road_event_id.is_empty():
			# 宝箱里反悔：回到宝箱的几个选项。
			upgrade_scroll.queue_free()
			upgrade_scroll = null
			skip_button.hide()
			main_choices.show()
			message_label.text = "山路所得，择一带走。"
			RunState.checkpoint("event", {})
			return
		_finish_road_event("没有磨剑")
	elif removal_scroll != null and removal_scroll.visible:
		_finish_road_event("跳过移除")
	else:
		_finish_road_event("跳过选卡")


# ---- 问号节点：路遇 ----

func _resolve_unknown_event() -> void:
	var saved := RunState.room_checkpoint("event")
	road_event_id = str(saved.get("road_event", ""))
	if Road.get_event(road_event_id).is_empty():
		road_event_id = Road.pick(_road_events_this_run())
		RunState.checkpoint("event", {"road_event": road_event_id})
	var event := Road.get_event(road_event_id)
	_layout_road_text()
	$EventUI/Title.text = str(event.title)
	message_label.text = str(event.text)
	for button in main_choices.get_children():
		button.hide()
	var options: Array = event.options
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var button := Button.new()
		button.text = Road.describe(option, RunState.sword_realm >= 3)
		button.custom_minimum_size = Vector2(600, 90)
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		RewardSkin.style_button(button)
		button.disabled = not Road.option_available(option, RunState.player_hp, RunState.deck.size())
		button.pressed.connect(_choose_road_option.bind(index))
		main_choices.add_child(button)
		road_buttons.append(button)
	main_choices.show()


func _road_events_this_run() -> Array[String]:
	var seen: Array[String] = []
	for fact: Dictionary in RunState.current_run_journal:
		var details: Dictionary = fact.get("details", {})
		if details.has("road_event"):
			seen.append(str(details.road_event))
	return seen


func _layout_road_text() -> void:
	message_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	message_label.offset_top = 290
	message_label.offset_bottom = 400
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _restore_road_state(saved: Dictionary) -> void:
	road_event_id = str(saved.get("road_event", ""))
	road_line = str(saved.get("line", ""))
	road_choice = str(saved.get("choice", ""))
	road_notes.clear()
	for note in saved.get("notes", []):
		road_notes.append(str(note))
	var event := Road.get_event(road_event_id)
	if not event.is_empty():
		_layout_road_text()
		$EventUI/Title.text = str(event.title)


func _road_state(extra: Dictionary) -> Dictionary:
	var state := {"road_event": road_event_id, "line": road_line, "notes": road_notes.duplicate(), "choice": road_choice}
	state.merge(extra, true)
	return state


func _choose_road_option(index: int) -> void:
	if finishing or not road_choice.is_empty():
		return
	var event := Road.get_event(road_event_id)
	var option: Dictionary = event.options[index]
	if not Road.option_available(option, RunState.player_hp, RunState.deck.size()):
		return
	for button in road_buttons:
		button.disabled = true
	road_choice = str(option.text)
	road_line = str(option.get("line", ""))
	var pending := {"card": "", "remove": false, "upgrade": false}
	_apply_road_effects(option.get("effects", []), pending)
	if option.has("moment"):
		RunState.record_moment(str(option.moment), 2)
	_refresh_hp()
	main_choices.hide()
	if not str(pending.card).is_empty():
		_show_card_choices(str(pending.card) == "rare")
	elif pending.remove:
		_show_removal_choices()
	elif pending.upgrade:
		_show_upgrade_choices()
	else:
		_finish_road_event("")


func _apply_road_effects(effects: Array, pending: Dictionary) -> void:
	for effect: Dictionary in effects:
		if effect.has("hp"):
			var amount := RunState.rest_heal(int(effect.hp))
			var changed := RunState.adjust_player_hp(amount, 1 if amount < 0 else 0)
			if changed > 0:
				road_notes.append("恢复了 %d 点生命" % changed)
			elif changed < 0:
				road_notes.append("失去了 %d 点生命" % -changed)
		elif effect.has("max_hp"):
			RunState.increase_max_hp(int(effect.max_hp))
			road_notes.append("生命上限 +%d" % int(effect.max_hp))
		elif effect.has("bond"):
			RunState.add_bond(int(effect.bond))
		elif effect.has("hidden"):
			RunState.adjust_hidden(int(effect.hidden[0]), int(effect.hidden[1]))
		elif effect.has("card"):
			pending.card = str(effect.card)
		elif effect.has("remove"):
			pending.remove = true
		elif effect.has("upgrade"):
			pending.upgrade = RunState.has_upgradable_card()
		elif effect.has("branch"):
			var branch: Dictionary = effect.branch
			var passed := _branch_passes(str(branch.get("if", "")))
			var line := str(branch.get("then_line" if passed else "else_line", ""))
			if not line.is_empty():
				road_line = line
			_apply_road_effects(branch.get("then" if passed else "else", []), pending)


func _branch_passes(condition: String) -> bool:
	var parts := condition.split(":")
	if parts.size() != 2:
		return false
	match parts[0]:
		"chance":
			return randf() < float(parts[1])
		"trust":
			return RunState.hidden_trust >= int(parts[1])
	return false


func _road_display(extra: String = "") -> String:
	var lines: Array[String] = []
	if not road_line.is_empty():
		lines.append(road_line)
	var notes := road_notes.duplicate()
	if not extra.is_empty():
		notes.append(extra)
	if not notes.is_empty():
		lines.append("（%s）" % "，".join(notes))
	return "\n".join(lines)


func _finish_road_event(extra: String) -> void:
	if road_event_id.is_empty():
		_finish_event(extra)
		return
	var event := Road.get_event(road_event_id)
	var summary := "路遇「%s」：选择「%s」" % [str(event.get("title", "")), road_choice]
	var display := _road_display(extra)
	if not display.is_empty():
		summary += "。" + display.replace("\n", " ")
	_finish_event(summary, display, {"road_event": road_event_id})


func _show_removal_choices() -> void:
	main_choices.hide()
	card_choices.hide()
	RunState.checkpoint("event", _road_state({"removing": true}))
	message_label.text = (road_line + "\n" if not road_line.is_empty() else "") + "选择一张牌移除"
	removal_scroll = ScrollContainer.new()
	removal_scroll.position = Vector2(510, 410)
	removal_scroll.size = Vector2(900, 330)
	$EventUI.add_child(removal_scroll)
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
	skip_button.text = "跳过移除"
	skip_button.show()


func _show_upgrade_choices() -> void:
	main_choices.hide()
	card_choices.hide()
	RunState.checkpoint("event", _road_state({"upgrading": true}) if not road_event_id.is_empty() else {"upgrading": true})
	message_label.text = (road_line + "\n" if not road_line.is_empty() else "") + "磨剑：选一张牌升级"
	upgrade_scroll = ScrollContainer.new()
	upgrade_scroll.name = "UpgradeChoices"
	upgrade_scroll.position = Vector2(460, 410)
	upgrade_scroll.size = Vector2(1000, 330)
	$EventUI.add_child(upgrade_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_scroll.add_child(list)
	var shown: Array[int] = []
	for index in range(RunState.deck.size()):
		var card_id: int = RunState.deck[index]
		# 同名牌只列一次，升级其中一张。
		if not CardDatabase.can_upgrade(card_id) or shown.has(card_id):
			continue
		shown.append(card_id)
		var button := Button.new()
		button.text = "%s → %s" % [CardDatabase.get_card_name(card_id), CardDatabase.get_reward_text(CardDatabase.upgraded_id(card_id)).replace("\n", " / ")]
		button.custom_minimum_size = Vector2(960, 65)
		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		list.add_child(button)
		RewardSkin.style_button(button)
		button.pressed.connect(_upgrade_card.bind(index))
	skip_button.text = "先不磨"
	skip_button.show()


func _upgrade_card(index: int) -> void:
	if finishing:
		return
	var before: int = RunState.deck[index] if index < RunState.deck.size() else -1
	if RunState.upgrade_run_card(index) < 0:
		return
	upgrade_scroll.hide()
	_finish_road_event("磨了「%s」" % CardDatabase.get_card_name(before))


func _remove_card(index: int) -> void:
	if finishing:
		return
	var card_id := RunState.remove_run_card(index)
	if card_id < 0:
		return
	removal_scroll.hide()
	_finish_road_event("移除了「%s」" % CardDatabase.get_card_name(card_id))


func _roll_cards(rare: bool) -> Array[int]:
	if not rare:
		return CardDatabase.roll_reward_cards(RunState.deck, card_choices.get_child_count(), RunState.chapter, null, RunState.sword_realm)
	var pool: Array[int] = []
	for card_id in CardDatabase.get_reward_card_ids(RunState.deck, RunState.chapter):
		if CardDatabase.get_rarity(card_id) != CardDatabase.RARITY_COMMON:
			pool.append(card_id)
	pool.shuffle()
	var result: Array[int] = []
	for card_id in pool:
		if result.size() >= card_choices.get_child_count():
			break
		result.append(card_id)
	if result.size() < card_choices.get_child_count():
		for card_id in CardDatabase.roll_reward_cards(RunState.deck + result, card_choices.get_child_count(), RunState.chapter, null, RunState.sword_realm):
			if result.size() < card_choices.get_child_count() and not result.has(card_id):
				result.append(card_id)
	return result


# ---- 宝箱 ----

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


func _show_card_choices(rare: bool = false) -> void:
	main_choices.hide()
	card_choices.show()
	skip_button.text = "跳过选卡"
	skip_button.show()
	message_label.text = (road_line + "\n" if not road_line.is_empty() else "") + "选择一张加入牌组"
	var candidates: Array[int] = []
	var saved := RunState.room_checkpoint("event")
	if saved.has("cards"):
		candidates.assign(saved.cards)
	else:
		candidates = _roll_cards(rare)
	var room := {"card_choices": true, "cards": candidates, "rare": rare}
	RunState.checkpoint("event", _road_state(room) if not road_event_id.is_empty() else room)
	for index in range(card_choices.get_child_count()):
		var button := card_choices.get_child(index) as Button
		if index >= candidates.size():
			button.hide()
			continue
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
	if not road_event_id.is_empty():
		_finish_road_event("获得「%s」" % CardDatabase.get_card_name(card_type))
		return
	_finish_event("已将「%s」加入牌组" % CardDatabase.get_card_name(card_type))


func _finish_event(message: String, display: String = "", details: Dictionary = {}) -> void:
	if finishing:
		return
	finishing = true
	main_choices.hide()
	card_choices.hide()
	skip_button.hide()
	if removal_scroll != null:
		removal_scroll.hide()
	if upgrade_scroll != null:
		upgrade_scroll.hide()
	message_label.text = display if not display.is_empty() else message
	var event_name := "问号事件" if RunState.pending_event == RunState.EventType.UNKNOWN else "宝箱事件"
	var recorded := message if not road_event_id.is_empty() else "%s：%s" % [event_name, message]
	RunState.record_run_fact("event", "%s。事件后生命为 %d/%d，牌组共 %d 张。" % [
		recorded,
		RunState.player_hp,
		RunState.player_max_hp,
		RunState.deck.size(),
	], details)
	_refresh_hp()
	RunState.checkpoint("map")
	if road_event_id.is_empty():
		await get_tree().create_timer(1.0).timeout
		RunState.navigate("map", self)
		return
	# 路遇有她的反应要读，等玩家自己点继续。
	continue_button = Button.new()
	continue_button.text = "继续赶路"
	continue_button.position = Vector2(710, 760)
	continue_button.size = Vector2(500, 60)
	RewardSkin.style_button(continue_button)
	continue_button.pressed.connect(func(): RunState.navigate("map", self))
	$EventUI.add_child(continue_button)


func _refresh_hp() -> void:
	hp_label.text = "HP: %d/%d" % [RunState.player_hp, RunState.player_max_hp]
