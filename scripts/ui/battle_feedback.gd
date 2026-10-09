extends RefCounted

const EnemyEffect = preload("res://scripts/ui/enemy_action_effect.gd")

# Only scene-owned Controls and Tweens enter this module; it never changes combat values.
static func _label(caption: String, tint: Color, position: Vector2, size: Vector2) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


static func enemy_text(target: Control, caption: String, tint: Color, row: int) -> void:
	var label := _label(caption, tint, Vector2(-10, 105 + row * 34), Vector2(255, 36))
	target.get_parent().add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


static func player_text(ui: Node, caption: String, tint: Color, slot: int) -> void:
	var label := _label(caption, tint, Vector2(510 + slot * 240, 615), Vector2(320, 40))
	ui.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


static func _reset(sprite: TextureRect, previous: Tween) -> Vector2:
	if previous != null and previous.is_valid():
		previous.kill()
	var rest: Vector2 = sprite.get_meta("rest_position")
	sprite.position = rest
	return rest


static func hit(sprite: TextureRect, previous: Tween) -> Tween:
	var rest := _reset(sprite, previous)
	sprite.self_modulate = Color(1.5, 1.25, 1.15, 1)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position:x", rest.x + 6.0, 0.05)
	tween.tween_property(sprite, "position:x", rest.x - 4.0, 0.05)
	tween.tween_property(sprite, "position:x", rest.x, 0.08)
	tween.parallel().tween_property(sprite, "self_modulate", Color.WHITE, 0.18)
	return tween


static func enemy_effect(target: Control, kind: String, tint: Color) -> void:
	var effect := EnemyEffect.new()
	effect.kind = kind
	effect.tint = tint
	effect.size = target.size
	target.add_child(effect)


static func action(sprite: TextureRect, target: Control, kind: String, previous: Tween) -> Tween:
	var rest := _reset(sprite, previous)
	sprite.self_modulate = Color.WHITE
	var tween := sprite.create_tween()
	if kind == "attack":
		tween.tween_property(sprite, "position:y", rest.y - 6.0, 0.1)
		tween.tween_property(sprite, "position:y", rest.y + 13.0, 0.08)
		tween.tween_property(sprite, "position:y", rest.y, 0.18)
		enemy_effect(target, "attack", Color("#e6c17e"))
	else:
		var tint := Color("#74c7bd") if kind == "guard" else Color("#bf9de8")
		tween.tween_property(sprite, "self_modulate", tint.lightened(0.3), 0.15)
		tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.25)
		enemy_effect(target, kind, tint)
	return tween


static func death(sprite: TextureRect, idle: Tween, previous: Tween) -> Tween:
	if idle.is_valid():
		idle.kill()
	var rest := _reset(sprite, previous)
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", rest.y + 12.0, 0.4)
	tween.tween_property(sprite, "scale", Vector2(0.94, 0.94), 0.4)
	tween.tween_property(sprite, "self_modulate:a", 0.0, 0.5)
	return tween
