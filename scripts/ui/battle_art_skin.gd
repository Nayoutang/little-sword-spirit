extends RefCounted

static func texture_box(asset: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://art/ui/battle/" + asset + ".png")
	style.texture_margin_left = 18
	style.texture_margin_right = 18
	style.texture_margin_top = 14
	style.texture_margin_bottom = 14
	style.set_content_margin_all(10)
	return style

# 固定布局与装饰纹理保存在 ui/battle/，此处只更新运行时文案。
static func apply(battle: Node) -> void:
	var ui := battle.get_node("BattleUI")
	ui.get_node("RouteCaption").text = "山门试炼 · 第 %d 层" % RunState.route_layer
	var actions: Control = ui.get_node("ActionArea")
	for pair in [["Special", "流光"], ["Ultimate", "华彩"], ["EndTurn", "结束回合"]]:
		var button: Button = actions.get_node(pair[0])
		button.text = pair[1]
		button.tooltip_text = "结束玩家回合，执行小墨意向与敌人行动。" if pair[0] == "EndTurn" else CardDatabase.get_battle_text(CardDatabase.FLOWING_LIGHT if pair[0] == "Special" else CardDatabase.BRILLIANCE)


static func prepare_card(button: Button) -> void:
	button.custom_minimum_size = Vector2(210, 300)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", texture_box("intent"))
	var face := preload("res://scripts/ui/card_face.gd").new()
	face.name = "PaintedFace"
	button.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_entered.connect(func():
		face.modulate = Color(0.68, 0.71, 0.7) if button.disabled else Color(1.12, 1.12, 1.08)
	)
	button.mouse_exited.connect(func():
		face.modulate = Color(0.68, 0.71, 0.7) if button.disabled else Color.WHITE
	)


static func select_card(button: Button, selected: bool) -> void:
	var face: Control = button.get_node("PaintedFace")
	var previous: Tween = button.get_meta("selection_tween") if button.has_meta("selection_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	face.pivot_offset = face.size * Vector2(0.5, 1.0)
	button.z_index = 5 if selected else 0
	var tween := button.create_tween().set_parallel(true)
	button.set_meta("selection_tween", tween)
	tween.tween_property(face, "scale", Vector2(1.10, 1.10) if selected else Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "position:y", -8.0 if selected else 0.0, 0.16)


static func select_skill(button: Button, selected: bool) -> void:
	if button.has_meta("skill_selected") and bool(button.get_meta("skill_selected")) == selected:
		return
	button.set_meta("skill_selected", selected)
	var previous: Tween = button.get_meta("skill_selection_tween") if button.has_meta("skill_selection_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	button.pivot_offset = button.size * 0.5
	button.z_index = 5 if selected else 0
	button.add_theme_color_override("font_color", Color("#ffe4a1") if selected else Color("#e5eadb"))
	var tween := button.create_tween().set_parallel(true)
	button.set_meta("skill_selection_tween", tween)
	tween.tween_property(button, "scale", Vector2(1.08, 1.08) if selected else Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "self_modulate", Color(1.18, 1.14, 1.04) if selected else Color.WHITE, 0.16)
