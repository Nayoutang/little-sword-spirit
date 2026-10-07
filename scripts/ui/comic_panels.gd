extends TextureRect

signal sequence_completed
@export var reveal_duration := 0.35
@export var fill_frame := false
@export_file("*.json") var layout_file := "res://ui/shared/comic_panels.json"
@export_file("*.json") var text_file := "res://ui/shared/comic_text.json"
var revealed_count := 0
var panels: Array[Polygon2D] = []
var reveal_tween: Tween

func _ready() -> void:
	self_modulate.a = 0.0
	resized.connect(_layout_panels)

func begin(new_texture: Texture2D) -> void:
	if reveal_tween != null:
		reveal_tween.kill()
	for panel in panels:
		remove_child(panel)
		panel.queue_free()
	panels.clear()
	revealed_count = 0
	texture = new_texture
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_file))
	var key := texture.resource_path.get_file().get_basename().trim_suffix("_unboxed")
	for vertices in data.get(key, [[[0,0],[1,0],[1,1],[0,1]]]):
		var panel := Polygon2D.new()
		var points := PackedVector2Array()
		for point in vertices:
			points.append(Vector2(point[0], point[1]) * texture.get_size())
		panel.polygon = points
		panel.uv = points
		panel.texture = texture
		panel.modulate.a = 0.0
		add_child(panel)
		panels.append(panel)
	_add_crisp_text(key)
	_layout_panels()
	reveal_next()

func _add_crisp_text(key: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(text_file))
	var narration_font = load("res://ui/shared/comic_font.tres")
	for entry in data.get(key, []):
		var rect: Array = entry["rect"]
		var label := Label.new()
		label.text = str(entry["text"])
		label.position = Vector2(rect[0], rect[1]) * texture.get_size()
		label.size = Vector2(rect[2], rect[3]) * texture.get_size()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.99, 0.97, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.08, 0.85))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 25)
		label.add_theme_font_override("font", narration_font)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panels[int(entry["panel"])].add_child(label)

func _layout_panels() -> void:
	if texture == null:
		return
	var ratio := minf(size.x / texture.get_width(), size.y / texture.get_height())
	var panel_scale := size / texture.get_size() if fill_frame else Vector2.ONE * ratio
	var origin := (size - texture.get_size() * panel_scale) * 0.5
	for panel in panels:
		panel.position = origin
		panel.scale = panel_scale

func is_complete() -> bool:
	return revealed_count == panels.size()

# A click during the fade finishes that panel; it never skips another panel.
func reveal_next() -> bool:
	if reveal_tween != null and reveal_tween.is_running():
		reveal_tween.kill()
		panels[revealed_count - 1].modulate.a = 1.0
		if is_complete():
			sequence_completed.emit()
		return true
	if is_complete():
		return false
	var panel := panels[revealed_count]
	revealed_count += 1
	reveal_tween = create_tween()
	reveal_tween.tween_property(panel, "modulate:a", 1.0, reveal_duration)
	if is_complete():
		reveal_tween.tween_callback(func(): sequence_completed.emit())
	return true
