
extends CanvasLayer

# 大话骰的桌面。逻辑在 LiarDiceGame，这里只管显示和输入。
signal closed

const COMIC_FONT = preload("res://ui/shared/comic_font.tres")
const InkUISkin = preload("res://scripts/ui/ink_ui_skin.gd")
const LiarDiceGame = preload("res://scripts/home/liar_dice_game.gd")
const INK := Color("#3a2c22")
const MUTED := Color("#7a6a58")
const ACCENT := Color("#8a2f2a")
const PAPER := Color("#efe3c8")
const OPENINGS_FIRST := [
	"这是我在路边茶棚学的。规则简单：你骗得过我，我就认输。",
]
const OPENINGS := [
	"又来？上回的铜钱我还没捂热呢。",
	"摇吧。这回别想骗我。",
	"来，输的人去烧水。",
]

var game: LiarDiceGame
var seed_value := -1
var count := LiarDiceGame.MIN_COUNT
var face := 2
var busy := false
var revealed := false
var result_recorded := false

var her_dice: HBoxContainer
var my_dice: HBoxContainer
var speech: Label
var gesture: Label
var bid_label: Label
var history_label: Label
var coins_label: Label
var status_label: Label
var count_label: Label
var face_buttons: Array[Button] = []
var minus_button: Button
var plus_button: Button
var bid_button: Button
var open_button: Button
var next_button: Button
var leave_button: Button
var rules_panel: PanelContainer
var secrecy_label: Label
var verdict_label: Label
var tally_label: Label
var result_plate: PanelContainer
var round_label: Label
var action_bar: HBoxContainer
var table_panel: PanelContainer
var controls: HBoxContainer


func _ready() -> void:
	layer = 20
	_build()
	start_game()


func previous_games() -> int:
	var total := 0
	for fact in RunState.relationship_facts.get("minigame_results", []):
		if fact is Dictionary and str(fact.get("summary", "")).begins_with("大话骰"):
			total += 1
	return total


func start_game() -> void:
	var played := previous_games()
	game = LiarDiceGame.new(seed_value, played)
	result_recorded = false
	game.start_round("player")
	revealed = false
	gesture.text = ""
	speech.text = "“%s”" % (OPENINGS_FIRST[0] if played == 0 else OPENINGS[game.rng.randi_range(0, OPENINGS.size() - 1)])
	_reset_selection()
	_refresh()


# ---- 界面 ----

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.04, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	table_panel = PanelContainer.new()
	table_panel.name = "Table"
	table_panel.size = Vector2(1800, 960)
	table_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(table_panel)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(1800, 960)
	table_panel.add_child(stage)
	var artwork := TextureRect.new()
	artwork.texture = preload("res://art/ui/liar_dice/tea_table_v1.png")
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(artwork)
	var header := PanelContainer.new()
	header.position = Vector2.ZERO
	header.size = Vector2(1800, 94)
	header.add_theme_stylebox_override("panel", _dark_box())
	stage.add_child(header)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	header.add_child(top)
	top.add_child(_label("大话骰", 42, Color("#f1d99e")))
	round_label = _label("", 24, Color("#bcd1c5"))
	top.add_child(round_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	coins_label = _label("", 28, Color("#f1d99e"))
	top.add_child(coins_label)
	var rules_button := _button("规则", 128)
	rules_button.pressed.connect(func(): rules_panel.visible = not rules_panel.visible)
	top.add_child(rules_button)

	# 对白独立于牌桌；她的小动作保持原来的概率与时机。
	var dialogue := PanelContainer.new()
	dialogue.position = Vector2(28, 650)
	dialogue.size = Vector2(526, 280)
	dialogue.add_theme_stylebox_override("panel", _dark_box())
	stage.add_child(dialogue)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 12)
	dialogue.add_child(words)
	words.add_child(_label("小墨  /  茶余一局", 24, Color("#e4c789")))
	speech = _label("", 30, Color("#fff1d3"))
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.custom_minimum_size = Vector2(454, 118)
	words.add_child(speech)
	gesture = _label("", 23, Color("#bcd1c5"))
	gesture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(gesture)

	var paper := PanelContainer.new()
	paper.position = Vector2(586, 118)
	paper.size = Vector2(1186, 812)
	paper.add_theme_stylebox_override("panel", _paper_box())
	stage.add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	paper.add_child(column)
	var her_row := HBoxContainer.new()
	her_row.add_theme_constant_override("separation", 20)
	column.add_child(her_row)
	var her_name := _label("她的骰子", 27, INK)
	her_name.custom_minimum_size = Vector2(164, 0)
	her_row.add_child(her_name)
	her_dice = HBoxContainer.new()
	her_dice.add_theme_constant_override("separation", 14)
	her_row.add_child(her_dice)
	secrecy_label = _label("开骰前保密", 22, MUTED)
	her_row.add_child(secrecy_label)
	column.add_child(HSeparator.new())
	bid_label = _label("", 42, ACCENT)
	bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid_label.custom_minimum_size = Vector2(0, 60)
	column.add_child(bid_label)
	history_label = _label("", 22, MUTED)
	history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_label.custom_minimum_size = Vector2(0, 36)
	history_label.clip_text = true
	history_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(history_label)
	column.add_child(HSeparator.new())
	var my_row := HBoxContainer.new()
	my_row.add_theme_constant_override("separation", 20)
	column.add_child(my_row)
	var my_name := _label("我的骰子", 27, INK)
	my_name.custom_minimum_size = Vector2(164, 0)
	my_row.add_child(my_name)
	my_dice = HBoxContainer.new()
	my_dice.add_theme_constant_override("separation", 14)
	my_row.add_child(my_dice)
	my_row.add_child(_label("一点是赖子", 22, ACCENT))
	status_label = _label("", 26, INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 76)
	column.add_child(status_label)
	result_plate = PanelContainer.new()
	result_plate.add_theme_stylebox_override("panel", _dark_box())
	column.add_child(result_plate)
	var result_words := VBoxContainer.new()
	result_words.add_theme_constant_override("separation", 8)
	result_plate.add_child(result_words)
	verdict_label = _label("", 36, Color("#f1d99e"))
	verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_words.add_child(verdict_label)
	tally_label = _label("", 26, Color("#e1e7d6"))
	tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tally_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_words.add_child(tally_label)
	controls = HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 14)
	column.add_child(controls)
	minus_button = _step_button("−")
	minus_button.pressed.connect(func(): _change_count(-1))
	controls.add_child(minus_button)
	count_label = _label("", 38, INK)
	count_label.custom_minimum_size = Vector2(90, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(count_label)
	plus_button = _step_button("+")
	plus_button.pressed.connect(func(): _change_count(1))
	controls.add_child(plus_button)
	controls.add_child(_label("个", 28, INK))
	for value in range(2, 7):
		var button := Button.new()
		button.custom_minimum_size = Vector2(84, 84)
		button.toggle_mode = true
		button.tooltip_text = "叫%s点" % LiarDiceGame.face_name(value)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("#d9c8a4") if state == "pressed" else Color("#ecdfc3")
			box.border_color = Color("#27695f") if state in ["pressed", "focus"] else Color("#a58a59")
			box.set_border_width_all(4 if state in ["pressed", "focus"] else 1)
			box.set_corner_radius_all(12)
			button.add_theme_stylebox_override(state, box)
		var die := DiceFace.new()
		die.value = value
		die.custom_minimum_size = Vector2.ZERO
		die.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		die.offset_left = 10
		die.offset_top = 10
		die.offset_right = -10
		die.offset_bottom = -10
		die.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(die)
		button.pressed.connect(_choose_face.bind(value))
		face_buttons.append(button)
		controls.add_child(button)
	action_bar = HBoxContainer.new()
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", 24)
	column.add_child(action_bar)
	bid_button = _button("叫", 440)
	bid_button.pressed.connect(_on_bid)
	action_bar.add_child(bid_button)
	open_button = _button("不信 · 开骰", 300)
	open_button.pressed.connect(_on_open)
	open_button.tooltip_text = "揭开双方骰子：数量够则叫的人赢，否则开的人赢"
	action_bar.add_child(open_button)
	var flexible := Control.new()
	flexible.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(flexible)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 18)
	column.add_child(bottom)
	var reminder := _label("一点通用 · 输一轮扣一枚铜钱", 22, MUTED)
	reminder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(reminder)
	next_button = _button("下一轮", 220)
	next_button.pressed.connect(_on_next)
	bottom.add_child(next_button)
	leave_button = _button("收起骰局", 200)
	leave_button.pressed.connect(_on_leave)
	bottom.add_child(leave_button)

	# 规则层遮挡输入，有明确关闭按钮。
	var rules_shade := ColorRect.new()
	rules_shade.color = Color(0.02, 0.03, 0.03, 0.82)
	rules_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rules_shade)
	rules_shade.hide()
	rules_panel = PanelContainer.new()
	rules_panel.size = Vector2(1080, 720)
	rules_panel.add_theme_stylebox_override("panel", _paper_box())
	var rules_column := VBoxContainer.new()
	rules_column.add_theme_constant_override("separation", 24)
	rules_panel.add_child(rules_column)
	rules_column.add_child(_label("大话骰 · 规则", 40, ACCENT))
	var rules := _label("叫的是双方合起来有多少颗，不是只算自己手里的！
你和小墨各有五颗骰子，一共十颗。开骰前，只能看自己的五颗。
比如叫「三个三」，就是猜：双方加起来，至少有三颗算作三点。
一点是赖子，也算三点。你有一个三和一个一，她也一样，合计就是四个三。
轮到你，可以往上叫，也可以按「开骰」查她。
往上叫：个数更多就行；个数不变，点数必须更大。
例如「三个三」后，可以叫「三个四」或「四个二」。只能叫二到六点。
开骰时，把双方的骰子一起数，所叫的点数和一点都算。
数量达到或超过叫数，叫的人赢；数量不够，按开骰的人赢。
每人三枚铜钱，输一轮扣一枚；先输光的输掉整局。
下一轮，上一轮输的人先叫。", 26, INK)
	rules.add_theme_constant_override("line_spacing", -6)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(992, 0)
	rules_column.add_child(rules)
	var close_rules := _button("记住了 · 回到骰局", 420)
	close_rules.pressed.connect(func(): rules_panel.hide(); rules_button.grab_focus())
	rules_column.add_child(close_rules)
	rules_panel.visibility_changed.connect(func(): rules_shade.visible = rules_panel.visible)
	add_child(rules_panel)
	rules_panel.hide()
	get_viewport().size_changed.connect(_center_table)
	_center_table()


func _center_table() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	table_panel.position = (viewport_size - table_panel.size) * 0.5
	rules_panel.position = (viewport_size - rules_panel.size) * 0.5


func _dark_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.09, 0.085, 0.94)
	box.border_color = Color("#a58a59")
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


func _step_button(caption: String) -> Button:
	var button := _button(caption, 76)
	button.add_theme_font_size_override("font_size", 40)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#d6c6a5") if state == "disabled" else Color("#f9efd9")
		box.border_color = Color("#27695f") if state in ["hover", "pressed", "focus"] else Color("#a58a59")
		box.set_border_width_all(3 if state == "focus" else 2)
		box.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _paper_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("#6b4a2b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	return style


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", COMIC_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _button(text: String, width: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 72)
	InkUISkin.style_button(button)
	button.add_theme_font_size_override("font_size", 28)
	return button


func _refresh() -> void:
	coins_label.text = "铜钱  /  你 %d 枚    小墨 %d 枚" % [game.player_coins, game.xiaomo_coins]
	round_label.text = "茶余对坐  ·  第 %d 轮" % game.round_index
	secrecy_label.text = "金色为计入的骰子" if revealed else "开骰前保密"
	result_plate.visible = revealed
	if revealed and not game.last_result.is_empty():
		var won: bool = game.last_result.winner == "player"
		verdict_label.text = ("这一局 · 你赢了" if game.player_won() else "这一局 · 小墨赢了") if game.finished else ("这一轮 · 你赢了" if won else "这一轮 · 小墨赢了")
		var target: int = game.bid_face
		var mine := game.player_dice.count(target) + game.player_dice.count(LiarDiceGame.WILD)
		var hers := game.xiaomo_dice.count(target) + game.xiaomo_dice.count(LiarDiceGame.WILD)
		tally_label.text = "你的 %d 颗 ＋ 小墨的 %d 颗 ＝ %d 颗%s点（含一点）" % [mine, hers, mine + hers, LiarDiceGame.face_name(target)]
	var highlight := game.bid_face if revealed else 0
	_fill_dice(her_dice, game.xiaomo_dice, not revealed, highlight)
	_fill_dice(my_dice, game.player_dice, false, highlight)
	if game.bid_count == 0:
		bid_label.text = "还没人叫" if game.turn == "player" else "小墨先叫"
	else:
		bid_label.text = "%s叫：%s" % ["小墨" if game.bid_by == "xiaomo" else "你", LiarDiceGame.bid_text(game.bid_count, game.bid_face)]
	var parts: Array[String] = []
	for entry in game.history:
		parts.append("%s %s" % ["她" if entry.by == "xiaomo" else "你", LiarDiceGame.bid_text(entry.count, entry.face)])
	history_label.text = "  →  ".join(parts.slice(maxi(0, parts.size() - 4))) if not parts.is_empty() else "从两个起叫，试试她的虚实。"
	history_label.tooltip_text = "\n".join(parts)
	var my_turn := not busy and not revealed and not game.finished and game.turn == "player"
	controls.visible = not revealed
	action_bar.visible = not revealed
	count_label.text = LiarDiceGame.count_name(count)
	for index in range(face_buttons.size()):
		face_buttons[index].button_pressed = index + 2 == face
		face_buttons[index].disabled = not my_turn
		face_buttons[index].modulate = Color.WHITE if my_turn else Color(0.65, 0.65, 0.65)
	bid_button.text = "叫：%s" % LiarDiceGame.bid_text(count, face)
	minus_button.disabled = not my_turn or count <= game.minimum_raise(face)
	plus_button.disabled = not my_turn or count >= LiarDiceGame.MAX_COUNT
	bid_button.disabled = not my_turn or not game.is_legal_bid(count, face)
	open_button.disabled = not my_turn or game.bid_by != "xiaomo"
	next_button.visible = revealed
	next_button.text = "再来一局" if game.finished else "下一轮"
	if busy:
		status_label.text = "小墨在掂量你的叫数……留心她的反应。"
	elif revealed:
		pass
	elif my_turn:
		status_label.text = "轮到你：加大个数或点数；觉得她在吹牛，就开骰。" if game.bid_count > 0 else "你先叫：选个数，再选点数。双方的一点都算赖子。"


func _fill_dice(row: HBoxContainer, dice: Array[int], hidden: bool, highlight: int) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for value in dice:
		var die := DiceFace.new()
		die.value = value
		die.hidden_face = hidden
		die.highlight = highlight > 0 and (value == highlight or value == LiarDiceGame.WILD)
		row.add_child(die)
		if revealed:
			die.modulate.a = 0.0
			var tween := die.create_tween()
			tween.tween_property(die, "modulate:a", 1.0, 0.22)


func _reset_selection() -> void:
	face = game.bid_face if game.bid_face > 0 else 2
	count = game.minimum_raise(face)


func _choose_face(value: int) -> void:
	face = value
	count = maxi(count, game.minimum_raise(face))
	_refresh()


func _change_count(delta: int) -> void:
	count = clampi(count + delta, game.minimum_raise(face), LiarDiceGame.MAX_COUNT)
	_refresh()


# ---- 行动 ----

func _on_bid() -> void:
	if not game.player_bid(count, face):
		return
	gesture.text = ""
	_refresh()
	await _xiaomo_turn()


func _on_open() -> void:
	var result := game.player_open()
	if not result.is_empty():
		_show_reveal(result)


func _xiaomo_turn() -> void:
	if game.turn != "xiaomo" or game.finished:
		return
	busy = true
	_refresh()
	var decision := game.xiaomo_decide()
	await get_tree().create_timer(float(decision.get("delay", 0.8))).timeout
	if not is_inside_tree():
		return
	busy = false
	speech.text = "“%s”" % str(decision.get("line", ""))
	gesture.text = str(decision.get("gesture", ""))
	var result := game.apply_xiaomo(decision)
	if not result.is_empty():
		_show_reveal(result)
		return
	_reset_selection()
	_refresh()


func _show_reveal(result: Dictionary) -> void:
	revealed = true
	var bidder := "小墨" if result.bidder == "xiaomo" else "你"
	var verdict := "够数" if result.bid_true else "不够"
	var coin := "你交出一枚铜钱。" if result.loser == "player" else "她交出一枚铜钱。"
	status_label.text = "开骰：一共 %d 个%s（算上一点）。%s叫的是%s，%s。%s" % [
		int(result.actual), LiarDiceGame.face_name(int(result.face)), bidder,
		LiarDiceGame.bid_text(int(result.count), int(result.face)), verdict, coin]
	gesture.text = "——她刚才是在吹牛。" if result.bluff else ""
	if result.bidder == "xiaomo" and not result.bluff:
		gesture.text = "——她刚才没吹牛。"
	speech.text = "“%s”" % str(result.line)
	if game.finished:
		speech.text = "“%s”" % ("……好吧，这局算你赢。下回我可不让了。" if game.player_won() else "铜钱归我了。再来？")
		_record_result()
	_refresh()


func _record_result() -> void:
	if result_recorded:
		return
	result_recorded = true
	if is_instance_valid(RunState):
		RunState.record_minigame_result(game.result_summary())
		# 看穿她够多次：往后战斗里她会提前说出下回合的打算。
		if RunState.record_dice_caught(game.caught_bluffs):
			speech.text = "“……你现在打仗的时候，大概也能看出我想干嘛了。”"
			gesture.text = "（之后的战斗里，她会提前告诉你下回合的打算）"


func _on_next() -> void:
	if game.finished:
		start_game()
		return
	revealed = false
	gesture.text = ""
	game.start_round()
	_reset_selection()
	speech.text = "“轮到我先叫。”" if game.turn == "xiaomo" else "“你先。”"
	_refresh()
	if game.turn == "xiaomo":
		await _xiaomo_turn()


func handle_back() -> void:
	if rules_panel.visible:
		rules_panel.hide()
	else:
		_on_leave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back()


func _on_leave() -> void:
	closed.emit()
	queue_free()


# 骰子：象牙底、墨点；盖着的是漆黑骰盅。
class DiceFace extends Control:
	var value := 1
	var hidden_face := false
	var highlight := false
	const PIPS := {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.28, 0.28), Vector2(0.72, 0.72)],
		3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
		4: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
		5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		6: [Vector2(0.28, 0.24), Vector2(0.72, 0.24), Vector2(0.28, 0.5), Vector2(0.72, 0.5), Vector2(0.28, 0.76), Vector2(0.72, 0.76)],
	}

	func _init() -> void:
		custom_minimum_size = Vector2(84, 84)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(12)
		if hidden_face:
			# 漆木骰盅轮廓，不把未知骰面画成已知点数。
			var center := rect.get_center()
			var cup := PackedVector2Array([Vector2(center.x - 21, 18), Vector2(center.x + 21, 18), Vector2(center.x + 29, size.y - 17), Vector2(center.x - 29, size.y - 17)])
			draw_colored_polygon(cup, Color("#283d37"))
			draw_polyline(PackedVector2Array([cup[0], cup[1], cup[2], cup[3], cup[0]]), Color("#b19151"), 2, true)
			draw_line(Vector2(center.x - 28, size.y - 20), Vector2(center.x + 28, size.y - 20), Color("#d3b777"), 3, true)
			draw_arc(center, 12, 0, TAU, 32, Color("#a78d58"), 1.5, true)
			draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), Color("#a78d58"), 2, true)
			return
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color(0.15, 0.1, 0.06, 0.22)
		shadow.set_corner_radius_all(12)
		draw_style_box(shadow, Rect2(rect.position + Vector2(1, 4), rect.size))
		box.bg_color = Color("#fff6e3") if not highlight else Color("#f6d98a")
		box.border_color = Color("#8a2f2a") if highlight else Color("#6b4a2b")
		box.set_border_width_all(4 if highlight else 2)
		draw_style_box(box, rect)
		# 一点和四点用红点，像民间骰子。
		var pip_color := Color("#b3261e") if value in [1, 4] else Color("#2b211c")
		var radius := rect.size.x * (0.13 if value == 1 else 0.085)
		for point in PIPS.get(value, []):
			draw_circle(rect.position + rect.size * point, radius, pip_color)
