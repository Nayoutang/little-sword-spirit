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

static func add_art(parent: Control, asset: String) -> TextureRect:
	var art := TextureRect.new()
	art.texture = load("res://art/ui/battle/" + asset + ".png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	parent.move_child(art, 0)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art

static func apply(battle: Node) -> void:
	var ui := battle.get_node("BattleUI")
	ui.get_node("EnemyArea/EnemyRow").position.y = 180
	var route := Label.new()
	route.name = "RouteCaption"
	route.position = Vector2(35, 22)
	route.size = Vector2(325, 45)
	route.text = "山门试炼 · 第 %d 层" % RunState.route_layer
	route.add_theme_stylebox_override("normal", texture_box("intent"))
	route.add_theme_font_size_override("font_size", 21)
	route.add_theme_color_override("font_color", Color("#fff0d1"))
	route.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(route)
	var info: Control = ui.get_node("InfoArea")
	info.position.y = 640
	var hand: Control = ui.get_node("HandViewport")
	hand.position = Vector2(290, 750)
	hand.size = Vector2(1120, 310)
	ui.get_node("HandBackdrop").hide()
	ui.get_node("CompanionPanel/Title").hide()
	ui.get_node("CompanionPanel/DialogueBackdrop").add_theme_stylebox_override("panel", texture_box("speech"))
	ui.get_node("CompanionPanel/DialogueBackdrop").position.y = 80
	for path in ["CompanionPanel/Reason", "CompanionPanel/Status", "CompanionPanel/Effect"]:
		var label: Label = ui.get_node(path)
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		label.add_theme_color_override("font_color", Color("#233b39"))
		label.position.x = 370
		label.size.x = 285
	ui.get_node("CompanionPanel/Status").position.y = 110
	ui.get_node("CompanionPanel/Reason").position.y = 150
	ui.get_node("CompanionPanel/Status").add_theme_color_override("font_color", Color("#655031"))
	for pair in [["DrawPile", "deck"], ["DiscardPile", "discard"]]:
		var pile: ColorRect = ui.get_node(pair[0])
		pile.color = Color.TRANSPARENT
		pile.position = Vector2(70, 790) if pair[0] == "DrawPile" else Vector2(1750, 790)
		pile.size = Vector2(140, 230)
		add_art(pile, pair[1])
		var count: Label = pile.get_node("Count")
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_color_override("font_shadow_color", Color.BLACK)
		count.add_theme_constant_override("shadow_offset_y", 2)
	var actions: Control = ui.get_node("ActionArea")
	actions.position = Vector2(1450, 780)
	actions.size = Vector2(260, 265)
	for pair in [["Special", "流光"], ["Ultimate", "华彩"], ["EndTurn", "结束回合"]]:
		var button: Button = actions.get_node(pair[0])
		button.custom_minimum_size = Vector2(260, 70)
		button.text = pair[1]
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, texture_box("button"))
		button.add_theme_font_size_override("font_size", 23)
		button.add_theme_color_override("font_disabled_color", Color("#738e85"))
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		button.tooltip_text = "结束玩家回合，执行小墨意向与敌人行动。" if pair[0] == "EndTurn" else CardDatabase.get_battle_text(CardDatabase.FLOWING_LIGHT if pair[0] == "Special" else CardDatabase.BRILLIANCE)
	actions.set_deferred("size", Vector2(260, 265))

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
