extends CanvasLayer

# Scene-wide button skin. Dynamic intro choices call style_button() directly.
func _ready() -> void:
	for node in find_children("*", "Button", true, false):
		style_button(node as Button)
	for node in find_children("*", "LineEdit", true, false):
		style_line_edit(node as LineEdit)


static func style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(Color(0.09, 0.18, 0.20, 0.94), Color("#a89163")))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.16, 0.29, 0.30, 0.98), Color("#e2c487")))
	button.add_theme_stylebox_override("pressed", _button_box(Color(0.12, 0.37, 0.36, 1.0), Color("#7bd4c8")))
	button.add_theme_stylebox_override("disabled", _button_box(Color(0.11, 0.14, 0.15, 0.82), Color("#616966")))
	button.add_theme_stylebox_override("focus", _button_box(Color.TRANSPARENT, Color("#7bd4c8")))
	button.add_theme_color_override("font_color", Color("#f4ebd7"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#a8aaa2"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)


static func style_line_edit(field: LineEdit) -> void:
	field.add_theme_stylebox_override("normal", _button_box(Color(0.055, 0.10, 0.12, 0.96), Color("#9a855e")))
	field.add_theme_stylebox_override("focus", _button_box(Color(0.07, 0.14, 0.16, 1.0), Color("#7bd4c8")))
	field.add_theme_color_override("font_color", Color("#f4ebd7"))
	field.add_theme_color_override("font_placeholder_color", Color("#a4aaa6"))


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12.0)
	return box
