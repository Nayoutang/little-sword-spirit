extends CanvasLayer

# 战斗新手引导：首场战斗的分步讲解 + 之后各出现一次的情境提示。
# 只负责展示，不读写战斗规则；是否看过记在 user://tutorial.cfg，不进存档格式。

const SAVE_PATH := "user://tutorial.cfg"
const INTRO_KEY := "battle_intro"
const COMIC_FONT := preload("res://ui/shared/comic_font.tres")
const InkUISkin := preload("res://scripts/ui/ink_ui_skin.gd")
const PANEL_WIDTH := 760.0
const GAP := 28.0

signal closed

var _steps: Array[Dictionary] = []
var _index := 0
var _tip_key := ""
var _target_rect := Rect2()
var _pulse := 0.0

var _shade: Control
var _panel: PanelContainer
var _counter: Label
var _title: Label
var _body: Label
var _skip_button: Button
var _next_button: Button


static func is_seen(key: String) -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	return bool(config.get_value("seen", key, false))


static func mark_seen(key: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("seen", key, true)
	config.save(SAVE_PATH)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = Control.new()
	_shade.name = "Shade"
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.draw.connect(_draw_shade)
	add_child(_shade)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.09, 0.96)
	style.border_color = Color("#e6c17e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", style)
	_shade.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _make_label(36 if _mobile() else 30, Color("#e6c17e"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_counter = _make_label(24, Color("#a6b9b0"))
	header.add_child(_counter)

	_body = _make_label(30 if _mobile() else 25, Color("#ece6d6"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = PANEL_WIDTH - 68.0
	column.add_child(_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 18)
	column.add_child(buttons)
	_skip_button = _make_button("跳过引导")
	_skip_button.pressed.connect(_finish)
	buttons.add_child(_skip_button)
	_next_button = _make_button("下一步")
	_next_button.pressed.connect(_advance)
	buttons.add_child(_next_button)
	hide()


func is_active() -> bool:
	return visible


# steps: [{title, body, target (Control 或 null)}]
func start_intro(steps: Array[Dictionary]) -> void:
	_steps = steps
	_index = 0
	_tip_key = ""
	show()
	_show_step()


# 情境提示：同一个 key 一生只出现一次。返回是否真的显示了。
func try_tip(key: String, title: String, body: String, target: Control) -> bool:
	if visible or is_seen(key):
		return false
	_steps = [{"title": title, "body": body, "target": target}]
	_index = 0
	_tip_key = key
	show()
	_show_step()
	return true


func dismiss() -> void:
	if visible:
		_finish()


func _show_step() -> void:
	var step := _steps[_index]
	_title.text = str(step.get("title", ""))
	_body.text = str(step.get("body", ""))
	var single := _steps.size() == 1
	_counter.visible = not single
	_counter.text = "%d / %d" % [_index + 1, _steps.size()]
	_skip_button.visible = not single and _index < _steps.size() - 1
	_next_button.text = "知道了" if single else ("开始战斗" if _index == _steps.size() - 1 else "下一步")
	var target: Variant = step.get("target", null)
	_target_rect = Rect2()
	if target is Control and is_instance_valid(target) and (target as Control).is_visible_in_tree():
		_target_rect = (target as Control).get_global_rect().grow(10)
	_panel.reset_size()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_panel.reset_size()
	_place_panel()
	_shade.queue_redraw()


func _place_panel() -> void:
	var view := _shade.get_rect()
	var panel_size := _panel.get_combined_minimum_size()
	panel_size.x = maxf(panel_size.x, PANEL_WIDTH)
	_panel.size = panel_size
	var pos: Vector2
	if _target_rect.size == Vector2.ZERO:
		pos = (view.size - panel_size) * 0.5
	elif _target_rect.end.y + GAP + panel_size.y <= view.size.y:
		pos = Vector2(_target_rect.get_center().x - panel_size.x * 0.5, _target_rect.end.y + GAP)
	elif _target_rect.position.y - GAP - panel_size.y >= 0.0:
		pos = Vector2(_target_rect.get_center().x - panel_size.x * 0.5, _target_rect.position.y - GAP - panel_size.y)
	elif _target_rect.end.x + GAP + panel_size.x <= view.size.x:
		pos = Vector2(_target_rect.end.x + GAP, _target_rect.get_center().y - panel_size.y * 0.5)
	else:
		pos = Vector2(_target_rect.position.x - GAP - panel_size.x, _target_rect.get_center().y - panel_size.y * 0.5)
	pos.x = clampf(pos.x, 16.0, maxf(view.size.x - panel_size.x - 16.0, 16.0))
	pos.y = clampf(pos.y, 16.0, maxf(view.size.y - panel_size.y - 16.0, 16.0))
	_panel.position = pos


func _advance() -> void:
	if _index < _steps.size() - 1:
		_index += 1
		_show_step()
	else:
		_finish()


func _finish() -> void:
	if _tip_key.is_empty():
		mark_seen(INTRO_KEY)
	else:
		mark_seen(_tip_key)
	_tip_key = ""
	hide()
	closed.emit()


func _process(delta: float) -> void:
	if not visible or _target_rect.size == Vector2.ZERO:
		return
	_pulse = fmod(_pulse + delta * 2.4, TAU)
	_shade.queue_redraw()


func _draw_shade() -> void:
	var view := _shade.get_rect()
	var dim := Color(0, 0, 0, 0.62)
	if _target_rect.size == Vector2.ZERO:
		_shade.draw_rect(Rect2(Vector2.ZERO, view.size), dim)
		return
	var r := _target_rect
	_shade.draw_rect(Rect2(0, 0, view.size.x, maxf(r.position.y, 0.0)), dim)
	_shade.draw_rect(Rect2(0, r.end.y, view.size.x, maxf(view.size.y - r.end.y, 0.0)), dim)
	_shade.draw_rect(Rect2(0, r.position.y, maxf(r.position.x, 0.0), r.size.y), dim)
	_shade.draw_rect(Rect2(r.end.x, r.position.y, maxf(view.size.x - r.end.x, 0.0), r.size.y), dim)
	var glow := Color("#e6c17e")
	glow.a = 0.65 + 0.35 * sin(_pulse)
	_shade.draw_rect(r, glow, false, 4.0)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", COMIC_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	InkUISkin.style_button(button)
	button.custom_minimum_size = Vector2(200, 84) if _mobile() else Vector2(180, 56)
	if _mobile():
		button.add_theme_font_size_override("font_size", 30)
	return button


func _mobile() -> bool:
	return WindowMode.is_mobile()
