extends Control

# 章节剧情播放：逐句显示、两条回应、残页奖励。
# 远征途中（检查点 phase = story）播完回地图；在家里播的（pending_story）播完回家。

const Story = preload("res://scripts/data/chapter_two_story.gd")
const InkUISkin = preload("res://scripts/ui/ink_ui_skin.gd")
const COMIC_FONT = preload("res://ui/shared/comic_font.tres")

@export var story_override := ""
var story_id := ""
var story: Dictionary = {}
var in_expedition := false
var page_index := 0
var line_index := 0
var shown_lines: Array[String] = []
var waiting_choice := false
var reply_queue: Array[String] = []
var finishing := false
var showing_reward := false

var background: TextureRect
var title_label: Label
var text_label: RichTextLabel
var hint_label: Label
var choice_box: VBoxContainer
var reward_panel: PanelContainer
var skip_button: Button
var dialogue_panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_resolve_story()
	if story.is_empty():
		_leave()
		return
	title_label.text = str(story.get("title", ""))
	skip_button.visible = RunState.story_seen.has(story_id)
	_show_page()


func _resolve_story() -> void:
	if not story_override.is_empty():
		story_id = story_override
	elif RunState.has_expedition() and str(RunState.expedition_checkpoint.phase) == "story":
		in_expedition = true
		story_id = str(RunState.room_checkpoint("story").get("story", RunState.chapter_layer_story()))
	else:
		story_id = RunState.pending_story
	in_expedition = in_expedition or (RunState.has_expedition() and story_id in ["ch2_blacksmith", "ch2_troupe", "ch3_sword_tomb"])
	story = Story.get_story(story_id).duplicate(true)


func _build_ui() -> void:
	var base := ColorRect.new()
	base.color = Color("#14181a")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	background = TextureRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color.WHITE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.08, 0.06)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	title_label = Label.new()
	title_label.position = Vector2(60, 20)
	title_label.size = Vector2(1100, 70)
	title_label.add_theme_font_override("font", COMIC_FONT)
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Color("#efd9a6"))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	title_label.add_theme_constant_override("outline_size", 6)
	add_child(title_label)

	var panel := PanelContainer.new()
	dialogue_panel = panel
	panel.position = Vector2(80, 800)
	panel.size = Vector2(1760, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.86)
	style.border_color = Color("#8d6fb3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 48
	style.content_margin_right = 48
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.scroll_following = true
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_font_override("normal_font", COMIC_FONT)
	text_label.add_theme_font_size_override("normal_font_size", 30)
	text_label.add_theme_font_override("italics_font", COMIC_FONT)
	text_label.add_theme_font_size_override("italics_font_size", 28)
	text_label.add_theme_constant_override("line_separation", 10)
	panel.add_child(text_label)

	hint_label = Label.new()
	hint_label.position = Vector2(1500, 1030)
	hint_label.size = Vector2(300, 40)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.text = "点击继续"
	hint_label.add_theme_font_override("font", COMIC_FONT)
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color("#b9aecb"))
	add_child(hint_label)

	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(460, 815)
	choice_box.size = Vector2(1000, 190)
	choice_box.add_theme_constant_override("separation", 22)
	choice_box.hide()
	add_child(choice_box)

	skip_button = Button.new()
	skip_button.text = "跳过"
	skip_button.position = Vector2(1660, 50)
	skip_button.size = Vector2(180, 64)
	InkUISkin.style_button(skip_button)
	skip_button.pressed.connect(_skip)
	add_child(skip_button)


func _show_page() -> void:
	var page: Dictionary = story["pages"][page_index]
	var texture = load(str(page.get("bg", "")))
	if texture is Texture2D:
		background.texture = texture
	shown_lines.clear()
	line_index = 0
	_reveal_line()


func _page_lines() -> Array:
	return story["pages"][page_index]["lines"]


func _reveal_line() -> void:
	var lines := _page_lines()
	if line_index < lines.size():
		shown_lines.append(str(lines[line_index]))
		line_index += 1
		_render_text()


func _render_text() -> void:
	var parts: Array[String] = []
	# 保留完整逐句状态，只显示最近两句，为插画留下可读区域。
	for index in range(maxi(0, shown_lines.size() - 2), shown_lines.size()):
		var line := shown_lines[index]
		var color := "#f4ead2" if index == shown_lines.size() - 1 else "#a79f90"
		var speaker_end := line.find("：")
		if speaker_end > 0 and speaker_end <= 4:
			var name_color := "#c9a8f0" if line.begins_with("戏先生") else "#e9c27e"
			parts.append("[color=%s]%s[/color][color=%s]%s[/color]" % [name_color, line.left(speaker_end + 1), color, line.substr(speaker_end + 1)])
		else:
			parts.append("[color=%s][i]%s[/i][/color]" % [color, line])
	text_label.text = "\n".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


func advance() -> void:
	if finishing or waiting_choice or showing_reward:
		return
	if not reply_queue.is_empty():
		shown_lines.append(reply_queue.pop_front())
		_render_text()
		return
	if line_index < _page_lines().size():
		_reveal_line()
		return
	var page: Dictionary = story["pages"][page_index]
	if page.has("choices") and not page.get("_answered", false):
		_offer_choices(page["choices"])
		return
	if page_index + 1 < story["pages"].size():
		page_index += 1
		_show_page()
		return
	_finish()


func _offer_choices(choices: Array) -> void:
	waiting_choice = true
	dialogue_panel.hide()
	hint_label.hide()
	for child in choice_box.get_children():
		child.queue_free()
	for index in range(choices.size()):
		var button := Button.new()
		button.text = str(choices[index]["text"])
		button.custom_minimum_size = Vector2(1000, 84)
		InkUISkin.style_button(button)
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(choose.bind(index))
		choice_box.add_child(button)
	choice_box.show()


func choose(index: int) -> void:
	if not waiting_choice:
		return
	var page: Dictionary = story["pages"][page_index]
	var choice: Dictionary = page["choices"][index]
	page["_answered"] = true
	waiting_choice = false
	choice_box.hide()
	dialogue_panel.show()
	hint_label.show()
	shown_lines.append("你：" + str(choice["text"]).trim_prefix("「").trim_suffix("」"))
	for line in choice.get("reply", []):
		reply_queue.append(str(line))
	_render_text()
	if in_expedition:
		RunState.record_run_fact("chapter_story", "%s：玩家回应%s" % [str(story.get("title", "")), str(choice["text"])])


func _finish() -> void:
	var scroll := str(story.get("scroll", ""))
	# 远征中的奇遇给残页；终章在家播完给「收剑」。
	if not scroll.is_empty() and not RunState.has_scroll_page(scroll) and (in_expedition or story.get("scroll_at_home", false)):
		_show_reward(scroll)
		return
	_leave()


func _show_reward(scroll: String) -> void:
	showing_reward = true
	hint_label.hide()
	reward_panel = PanelContainer.new()
	reward_panel.position = Vector2(380, 180)
	reward_panel.size = Vector2(1160, 600)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#efe3c8")
	style.border_color = Color("#6d4f8f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	reward_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	reward_panel.add_child(row)
	var art := TextureRect.new()
	art.name = "ScrollArt"
	art.texture = Story.SCROLL_ART[scroll]
	art.custom_minimum_size = Vector2(360, 460)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	row.add_child(column)
	var heading := Label.new()
	heading.text = "获得 " + str(Story.SCROLL_NAMES[scroll])
	heading.add_theme_font_override("font", COMIC_FONT)
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("#3b2a4f"))
	column.add_child(heading)
	var body := Label.new()
	body.text = str(Story.SCROLL_RULES[scroll]) + "\n" + str(Story.SCROLL_NOTES.get(scroll, "只对紫线起作用，往后一直有效。"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(640, 0)
	body.add_theme_font_override("font", COMIC_FONT)
	body.add_theme_font_size_override("font_size", 28)
	body.add_theme_color_override("font_color", Color("#40382e"))
	column.add_child(body)
	var take := Button.new()
	take.text = "收好"
	take.custom_minimum_size = Vector2(240, 70)
	InkUISkin.style_button(take)
	take.pressed.connect(func(): _take_scroll(scroll))
	column.add_child(take)
	add_child(reward_panel)


func _take_scroll(scroll: String) -> void:
	if RunState.grant_scroll_page(scroll) and in_expedition:
		RunState.record_run_fact("chapter_story", "获得%s。" % str(Story.SCROLL_NAMES[scroll]))
	_leave()


func _skip() -> void:
	if finishing:
		return
	reply_queue.clear()
	waiting_choice = false
	choice_box.hide()
	_finish()


func _leave() -> void:
	if finishing:
		return
	finishing = true
	RunState.mark_story_seen(story_id)
	if in_expedition:
		var moment := str(story.get("moment", ""))
		if not moment.is_empty() and not RunState.run_moments.any(func(m): return str(m.get("summary", "")) == moment):
			RunState.record_moment(moment, 3)
		RunState.checkpoint("map")
		RunState.navigate("map", self)
		return
	if RunState.pending_story == story_id:
		RunState.pending_story = ""
	RunState.save_persistent_state()
	RunState.navigate("home", self)


func handle_mobile_back() -> bool:
	return true
