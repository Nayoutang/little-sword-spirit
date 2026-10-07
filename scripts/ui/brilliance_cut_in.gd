extends Control

# Motion belongs to native layers; the painting is only the transparent figure.
const FONT = preload("res://ui/shared/comic_font.tres")
const PORTRAIT_PATH := "res://art/effects/brilliance_ink_approved.png"
var progress := 0.0
var animation: Tween
var portrait: TextureRect
var title: Label
var caption: Label
var tag: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait = TextureRect.new()
	portrait.name = "InkFigure"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(portrait)
	tag = _label("终结技", 30, Color("#b69358"))
	title = _label("华  彩", 108, Color("#26352f"))
	caption = _label("一剑倾墨 · 万象收锋", 28, Color("#4c7168"))
	resized.connect(_layout_layers)
	_layout_layers()
	hide()

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _layout_layers() -> void:
	if portrait == null:
		return
	var factor := Vector2(size.x / 1920.0, size.y / 1080.0)
	portrait.position = Vector2(700, 150) * factor
	portrait.size = Vector2(1110, 790) * factor
	tag.position = Vector2(230, 365) * factor
	title.position = Vector2(215, 413) * factor
	caption.position = Vector2(235, 565) * factor
	for label: Label in [tag, title, caption]:
		label.scale = factor

func play(finisher := true) -> void:
	stop()
	tag.text = "终结技" if finisher else "收势"
	title.text = "华  彩" if finisher else "收  锋"
	caption.text = "一剑倾墨 · 万象收锋" if finisher else "墨尽山河 · 此战已终"
	if portrait.texture == null and ResourceLoader.exists(PORTRAIT_PATH):
		portrait.texture = load(PORTRAIT_PATH)
	progress = 0.0
	modulate = Color.WHITE
	show()
	_layout_layers()
	var end_position := portrait.position
	portrait.position.x += size.x * 0.09
	portrait.modulate.a = 0.0
	for label: Label in [tag, title, caption]:
		label.modulate.a = 0.0
	animation = create_tween()
	animation.set_parallel(true)
	animation.tween_property(self, "progress", 1.0, 1.32)
	animation.tween_property(portrait, "position", end_position, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.08)
	animation.tween_property(portrait, "modulate:a", 1.0, 0.34).set_delay(0.12)
	for index in range(3):
		var label: Label = [tag, title, caption][index]
		animation.tween_property(label, "modulate:a", 1.0, 0.24).set_delay(0.18 + index * 0.07)
	animation.chain().tween_property(self, "modulate:a", 0.0, 0.22)
	animation.chain().tween_callback(hide)
	set_process(true)

func stop() -> void:
	if animation != null and animation.is_valid():
		animation.kill()
	hide()
	set_process(false)

func _process(_delta: float) -> void:
	queue_redraw()
	if not visible:
		set_process(false)

func _draw() -> void:
	if not visible:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(size.x / 1920.0, size.y / 1080.0))
	var reveal := smoothstep(0.0, 0.25, progress)
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.02, 0.04, 0.05, 0.30 * reveal))
	# Uneven paper/ink bands unroll from left; no full-screen poster.
	var width := 1920.0 * reveal
	var top := PackedVector2Array([Vector2(-40, 345), Vector2(width * 0.27, 300), Vector2(width * 0.54, 292), Vector2(width, 242)])
	var band := top.duplicate()
	band.append_array(PackedVector2Array([Vector2(width + 60, 775), Vector2(width * 0.65, 822), Vector2(width * 0.3, 811), Vector2(-40, 840)]))
	draw_colored_polygon(band, Color(0.93, 0.91, 0.84, 0.94 * reveal))
	for index in range(16):
		var y := 290.0 + sin(index * 2.1) * 24.0
		var start := Vector2(90 + index * 104, y - index * 2.5)
		var end := start + Vector2(210, -12)
		if start.x < width:
			draw_line(start, Vector2(minf(end.x, width), end.y), Color(0.08, 0.12, 0.11, 0.13 * reveal), 8 + index % 4, true)
	# Swordlight travels across the ribbon, then the ink settles.
	var slash := smoothstep(0.28, 0.56, progress)
	if slash > 0.04:
		var a := Vector2(570, 720)
		var b := a.lerp(Vector2(1830, 342), slash)
		var normal := (b - a).normalized().orthogonal()
		var stroke := PackedVector2Array([a - normal * 2, a.lerp(b, 0.15) - normal * 8, a.lerp(b, 0.55) - normal * 4, b,
			a.lerp(b, 0.65) + normal * 2, a.lerp(b, 0.18) + normal * 4, a])
		draw_colored_polygon(stroke, Color(0.08, 0.30, 0.26, 0.60 * reveal))
		for segment in range(8):
			var t := segment / 8.0
			var start := a.lerp(b, t) - normal * (3.0 + sin(segment * 2.3))
			var end := a.lerp(b, minf(t + 0.105, 1.0)) - normal * 3
			draw_line(start, end, Color(0.68, 0.56, 0.33, 0.64 * reveal), 1.4, true)
	for index in range(23):
		var settle := clampf((progress - 0.35) * 2, 0, 1)
		var point := Vector2(640 + index * 50, 730 - index * 13 + sin(index * 2.7) * 70)
		point += Vector2(50 * settle, -34 * settle)
		draw_circle(point, 1.5 + index % 5, Color(0.08, 0.12, 0.11, 0.36 * settle))
	draw_set_transform(Vector2.ZERO)
