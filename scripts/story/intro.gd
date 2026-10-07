extends Node2D

const PAGES := [
	"res://art/story/intro/intro_comic_spread_v4_unboxed.png",
	"res://art/story/intro/intro_comic_02_acquaintance_v2_unboxed.png",
	"res://art/story/intro/intro_comic_03_descent_v1_unboxed.png",
	"res://art/story/intro/intro_comic_04_home_v1_unboxed.png",
]
const DEFAULT_NAME := "持剑人"
var page_index := 0
var finishing := false
var name_confirmed := false

@onready var page = $IntroUI/Page
@onready var caption: RichTextLabel = $IntroUI/Caption
@onready var name_input: LineEdit = $IntroUI/NameRow/NameInput
@onready var next_button: Button = $IntroUI/Next
@onready var previous_button: Button = $IntroUI/Previous

func _ready() -> void:
	# Restore local rectangles explicitly: binary scene export can discard
	# offsets on these free-positioned children of the anchored name card.
	var name_rects := {
		"Paper": Rect2(-32, -32, 954, 290),
		"Label": Rect2(30, 50, 860, 60),
		"NameInput": Rect2(30, 128, 620, 48),
		"Confirm": Rect2(680, 128, 190, 48),
	}
	for node_name in name_rects:
		var control: Control = get_node("IntroUI/NameRow/" + node_name)
		var rect: Rect2 = name_rects[node_name]
		control.position = rect.position
		control.size = rect.size
	$IntroUI/NameRow/Confirm.pressed.connect(_confirm_name)
	name_input.text_submitted.connect(func(_text: String): _confirm_name())
	name_input.placeholder_text = "你的名字"
	for path in ["Title", "Caption", "Previous", "Next", "Progress", "Skip", "NameRow"]:
		get_node("IntroUI/" + path).hide()
	_show_page()

func _show_page() -> void:
	$IntroUI/NameRow.hide()
	page.begin(load(PAGES[page_index]))
	_update_name_reply()

func _advance() -> void:
	if page_index == 1 and page.revealed_count >= 6 and not name_confirmed:
		$IntroUI/NameRow.show()
		name_input.grab_focus()
		return
	if not page.reveal_next():
		_next_page()

func _confirm_name() -> void:
	if name_input.text.strip_edges().is_empty():
		name_input.placeholder_text = "先告诉她你的名字吧"
		return
	name_input.text = name_input.text.strip_edges().left(12)
	name_confirmed = true
	name_input.release_focus()
	$IntroUI/NameRow.hide()
	_update_name_reply()
	page.reveal_next()

func _update_name_reply() -> void:
	if page_index != 1 or not name_confirmed:
		return
	var bubble := Panel.new()
	bubble.position = Vector2(0.54, 0.522) * page.texture.get_size()
	bubble.size = Vector2(0.19, 0.092) * page.texture.get_size()
	var style := StyleBoxTexture.new()
	style.texture = load("res://art/ui/comic/bubble_v1.png")
	bubble.add_theme_stylebox_override("panel", style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "叫我%s就好。" % name_input.text
	label.position = Vector2(25, 14)
	label.size = bubble.size - Vector2(50, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.01, 0.01, 0.01))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.01))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_font_override("font", load("res://ui/shared/comic_font.tres"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(label)
	page.panels[6].add_child(bubble)
	var reply_bubble := Panel.new()
	reply_bubble.position = Vector2(0.793, 0.726) * page.texture.get_size()
	reply_bubble.size = Vector2(0.198, 0.137) * page.texture.get_size()
	reply_bubble.add_theme_stylebox_override("panel", style)
	reply_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reply := Label.new()
	reply.text = "%s？\n行，记住了。" % name_input.text
	reply.position = Vector2(25, 20)
	reply.size = reply_bubble.size - Vector2(50, 44)
	reply.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reply.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply.add_theme_font_override("font", load("res://ui/shared/comic_font.tres"))
	reply.add_theme_font_size_override("font_size", 23)
	reply.add_theme_color_override("font_color", Color(0.01, 0.01, 0.01))
	reply.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.01))
	reply.add_theme_constant_override("outline_size", 1)
	reply.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reply_bubble.add_child(reply)
	page.panels[7].add_child(reply_bubble)

func _next_page() -> void:
	if page_index == PAGES.size() - 1:
		_finish()
		return
	page_index += 1
	_show_page()

func _previous_page() -> void:
	page_index = maxi(page_index - 1, 0)
	_show_page()

func _unhandled_input(event: InputEvent) -> void:
	if name_input.has_focus():
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if clicked or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_left"):
		_previous_page()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if finishing:
		return
	finishing = true
	var player_name := name_input.text.strip_edges().left(12)
	if player_name.is_empty():
		player_name = DEFAULT_NAME
	RunState.complete_intro(player_name, "初遇那天，你替断碑旁的古剑拂去灰尘，她说「喂，轻一点……我又不是块破石头。」你惊讶剑会说话，她告诉你自己叫小墨。你们一起下山，在山脚的旧屋落脚。你让她记住你的称呼是%s。" % player_name)
	get_tree().change_scene_to_file("res://scenes/home.tscn")
