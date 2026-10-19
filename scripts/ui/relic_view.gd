extends Node

# 信物按钮 + 列表面板。各远征场景用 install() 挂一个，点开看本趟拿到的信物。
const InkSkin = preload("res://scripts/ui/ink_ui_skin.gd")
const Relics = preload("res://scripts/data/relic_database.gd")
const Art = preload("res://scripts/ui/relic_art_catalog.gd")

var button: Button
var overlay: Control
var list: RichTextLabel


static func install(host: Node, ui: Node, position: Vector2) -> Node:
	var view = load("res://scripts/ui/relic_view.gd").new()
	view.name = "RelicView"
	host.add_child(view)
	view._build(ui, position)
	return view


func _build(ui: Node, position: Vector2) -> void:
	button = Button.new()
	button.name = "RelicButton"
	button.position = position
	button.size = Vector2(200, 48)
	InkSkin.style_button(button)
	ui.add_child(button)
	button.pressed.connect(open)
	overlay = Control.new()
	overlay.name = "RelicOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()
	ui.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed: close())
	overlay.add_child(shade)
	var paper := TextureRect.new()
	paper.texture = load("res://art/ui/home/history_page_v1.png")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.position = Vector2(460, 150)
	paper.size = Vector2(1000, 760)
	overlay.add_child(paper)
	var title := Label.new()
	title.text = "本趟的信物"
	title.position = Vector2(460, 190)
	title.size = Vector2(1000, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", InkSkin.COMIC_FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.12, 0.22, 0.19))
	overlay.add_child(title)
	list = RichTextLabel.new()
	list.bbcode_enabled = true
	list.position = Vector2(540, 270)
	list.size = Vector2(840, 500)
	list.add_theme_font_override("normal_font", InkSkin.COMIC_FONT)
	list.add_theme_font_override("bold_font", InkSkin.COMIC_FONT)
	list.add_theme_font_size_override("normal_font_size", 25)
	list.add_theme_font_size_override("bold_font_size", 27)
	list.add_theme_color_override("default_color", Color(0.12, 0.22, 0.19))
	overlay.add_child(list)
	var close_button := Button.new()
	close_button.text = "收起"
	close_button.position = Vector2(760, 800)
	close_button.size = Vector2(400, 60)
	InkSkin.style_button(close_button)
	close_button.pressed.connect(close)
	overlay.add_child(close_button)
	refresh()


func refresh() -> void:
	if button == null:
		return
	var owned: Array[String] = RunState.run_relics
	button.text = "信物 %d" % owned.size()
	var lines: Array[String] = []
	for id in owned:
		var definition := Relics.get_definition(id)
		var icon := Art.path_for(id)
		var image_tag := "[img=64x64]%s[/img]  " % icon if ResourceLoader.exists(icon) else ""
		lines.append("%s[b]%s[/b]\n%s\n[color=#5d6f66]%s[/color]" % [image_tag, definition.get("name", id), definition.get("text", ""), definition.get("flavor", "")])
	list.text = "\n\n".join(lines) if not lines.is_empty() else "还没有信物。精英战和宝箱里能找到。"


func open() -> void:
	refresh()
	overlay.show()


func close() -> void:
	overlay.hide()


func _input(event: InputEvent) -> void:
	if overlay != null and overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
