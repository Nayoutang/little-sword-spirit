extends CanvasLayer

@export var preserve_scene_styles := false
const BUTTON_ART = preload("res://art/ui/battle/button.png")
const INPUT_ART = preload("res://art/ui/home/history_page_v1.png")
const COMIC_FONT = preload("res://ui/shared/comic_font.tres")

func _ready() -> void:
	if preserve_scene_styles:
		return
	for node in find_children("*", "Button", true, false):
		style_button(node as Button)
	for node in find_children("*", "LineEdit", true, false):
		style_line_edit(node as LineEdit)

static func _painted_box(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	box.texture_margin_left = 40
	box.texture_margin_right = 40
	box.texture_margin_top = 18
	box.texture_margin_bottom = 18
	box.content_margin_left = 38
	box.content_margin_right = 38
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func style_button(button: Button) -> void:
	button.add_theme_font_override("font", COMIC_FONT)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tint := Color.WHITE
		if state == "hover": tint = Color(1.12, 1.12, 1.06)
		elif state == "pressed": tint = Color(0.85, 0.94, 0.92)
		elif state == "disabled": tint = Color(0.6, 0.65, 0.62, 0.8)
		button.add_theme_stylebox_override(state, _painted_box(BUTTON_ART, tint))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("#fff1d3"))
	button.add_theme_color_override("font_disabled_color", Color("#a0b2a8"))

static func style_line_edit(field: LineEdit) -> void:
	field.add_theme_font_override("font", COMIC_FONT)
	field.add_theme_font_size_override("font_size", 24)
	field.add_theme_stylebox_override("normal", _painted_box(INPUT_ART, Color.WHITE))
	field.add_theme_stylebox_override("focus", _painted_box(INPUT_ART, Color(1.03, 1.03, 1.0)))
	field.add_theme_color_override("font_color", Color("#203c35"))
	field.add_theme_color_override("font_placeholder_color", Color("#6d7669"))
	field.add_theme_color_override("caret_color", Color("#203c35"))
