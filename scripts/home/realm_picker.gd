extends CanvasLayer

# 出发前选剑境（第三章之后的自由历练，解锁二级以上时才弹出）。
signal picked(level: int)
signal cancelled

const COMIC_FONT = preload("res://ui/shared/comic_font.tres")
const InkUISkin = preload("res://scripts/ui/ink_ui_skin.gd")
const INK := Color("#3a2c22")
const MUTED := Color("#6f5f4d")

var buttons: Array[Button] = []


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#efe3c8")
	style.border_color = Color("#6b4a2b")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(_label("选剑境", 40, INK))
	column.add_child(_label("难度逐级累加。以最高一级打通，就解锁下一级。", 24, MUTED))
	for level in range(1, RunState.realm_unlocked + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		column.add_child(row)
		var button := Button.new()
		button.text = "剑境 " + RunState.realm_name(level)
		button.custom_minimum_size = Vector2(220, 72)
		InkUISkin.style_button(button)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_pick.bind(level))
		row.add_child(button)
		buttons.append(button)
		var rules := _label(RunState.realm_rules(level), 24, INK)
		rules.custom_minimum_size = Vector2(760, 0)
		rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(rules)
	var cancel := Button.new()
	cancel.text = "先不出门"
	cancel.custom_minimum_size = Vector2(220, 64)
	InkUISkin.style_button(cancel)
	cancel.pressed.connect(_cancel)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(cancel)
	column.add_child(bottom)
	panel.reset_size()
	panel.position = Vector2((1920 - panel.size.x) / 2.0, maxf((1080 - panel.size.y) / 2.0, 20.0))
	if not buttons.is_empty():
		buttons.back().grab_focus()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", COMIC_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _pick(level: int) -> void:
	picked.emit(level)
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
