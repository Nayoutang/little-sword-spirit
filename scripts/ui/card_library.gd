class_name CardLibrary
extends CanvasLayer

const Face = preload("res://scripts/ui/card_face.gd")
const Art = preload("res://scripts/ui/card_art_catalog.gd")
const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
const InkSkin = preload("res://scripts/ui/ink_ui_skin.gd")
const FONT = preload("res://ui/shared/comic_font.tres")
const STAGES := ["初遇", "相识", "交心", "生死之交"]

const OWNED_COLLECTION := 4

var heading: Label
var subtitle_label: Label
var overlay: Control
var search: LineEdit
var collection_filter: OptionButton
var type_filter: OptionButton
var grid: GridContainer
var card_scroll: ScrollContainer
var result_count: Label
var detail_face: Control
var detail_text: RichTextLabel
var empty_label: Label
var entries: Array[Dictionary] = []
var shown_entries: Array[Dictionary] = []
var selected_key := ""
var previous_focus: WeakRef

func _ready() -> void:
	layer = 20
	_build_entries()
	_build_ui()
	overlay.hide()
	get_viewport().size_changed.connect(_resize_grid)

func _build_entries() -> void:
	var ids: Array = CardDatabase.DEFINITIONS.keys()
	ids.sort()
	for card_id: int in ids:
		var definition: Dictionary = CardDatabase.get_definition(card_id)
		entries.append({"key": "p%d" % card_id, "id": card_id, "owner": "玩家", "name": str(definition["name"]), "type": str(definition["type"]), "definition": definition})
	var companion_ids: Array = CompanionCards.ORDERED_IDS.duplicate()
	companion_ids.append_array(CompanionCards.INTENT_DEFINITIONS.keys())
	for card_id: String in companion_ids:
		var definition := CompanionCards.get_definition(card_id)
		entries.append({"key": "c_" + card_id, "id": card_id, "owner": "小墨", "name": str(definition["name"]), "type": "剑意" if definition.has("poem") else "行动", "definition": definition})

func _build_ui() -> void:
	overlay = Control.new()
	overlay.name = "CardLibraryOverlay"
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_resource := Theme.new()
	theme_resource.default_font = FONT
	theme_resource.default_font_size = 22
	theme_resource.set_color("font_color", "Label", Color("#203b36"))
	overlay.theme = theme_resource
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.06, 0.07, 0.90)
	overlay.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Paper"
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 70
	panel.offset_top = 50
	panel.offset_right = -70
	panel.offset_bottom = -50
	var paper := StyleBoxTexture.new()
	paper.texture = preload("res://art/ui/home/history_page_v1.png")
	paper.texture_margin_left = 60
	paper.texture_margin_right = 60
	paper.texture_margin_top = 50
	paper.texture_margin_bottom = 50
	paper.content_margin_left = 72
	paper.content_margin_right = 72
	paper.content_margin_top = 72
	paper.content_margin_bottom = 90
	panel.add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	heading = Label.new()
	var title := heading
	title.text = "剑谱 · 卡牌图鉴"
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "收起 · Esc"
	close_button.custom_minimum_size = Vector2(160, 48)
	InkSkin.style_button(close_button)
	header.add_child(close_button)
	close_button.pressed.connect(close)
	subtitle_label = Label.new()
	var subtitle := subtitle_label
	subtitle.text = "翻阅全部招式与剑意；点选卡牌，查看完整效果与获得方式。"
	subtitle.add_theme_font_size_override("font_size", 20)
	column.add_child(subtitle)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 16)
	column.add_child(filters)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "搜索牌名、效果或诗句…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InkSkin.style_line_edit(search)
	search.custom_minimum_size.y = 48
	var search_box := StyleBoxFlat.new()
	search_box.bg_color = Color(0.89, 0.87, 0.79, 0.5)
	search_box.border_color = Color(0.20, 0.39, 0.34, 0.45)
	search_box.set_border_width_all(1)
	search_box.content_margin_left = 14
	search_box.content_margin_right = 14
	search_box.content_margin_top = 8
	search_box.content_margin_bottom = 8
	search.add_theme_stylebox_override("normal", search_box)
	search.add_theme_stylebox_override("focus", search_box)
	search.clear_button_enabled = true
	filters.add_child(search)
	collection_filter = OptionButton.new()
	collection_filter.name = "Collection"
	for item in ["全部卡牌", "玩家卡牌", "小墨行动", "羁绊技能", "本趟持有"]:
		collection_filter.add_item(item)
	filters.add_child(collection_filter)
	type_filter = OptionButton.new()
	type_filter.name = "Type"
	for item in ["全部类型", "攻击", "防御", "技巧", "能力", "诅咒", "特殊技", "终极技", "行动", "剑意"]:
		type_filter.add_item(item)
	filters.add_child(type_filter)
	for button: OptionButton in [collection_filter, type_filter]:
		button.custom_minimum_size = Vector2(180, 46)
		InkSkin.style_button(button)
	result_count = Label.new()
	result_count.add_theme_font_size_override("font_size", 18)
	column.add_child(result_count)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var cards_column := VBoxContainer.new()
	cards_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cards_column)
	empty_label = Label.new()
	empty_label.text = "没有找到招式。试试另一关键词或类型。"
	cards_column.add_child(empty_label)
	card_scroll = ScrollContainer.new()
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_column.add_child(card_scroll)
	grid = GridContainer.new()
	grid.name = "Cards"
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	card_scroll.add_child(grid)
	var detail_column := VBoxContainer.new()
	detail_column.custom_minimum_size = Vector2(330, 0)
	body.add_child(detail_column)
	detail_face = Face.new()
	detail_face.name = "DetailFace"
	detail_face.custom_minimum_size = Vector2(300, 330)
	detail_column.add_child(detail_face)
	detail_text = RichTextLabel.new()
	detail_text.name = "DetailText"
	detail_text.clip_contents = true
	detail_text.scroll_active = true
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_text.custom_minimum_size = Vector2(330, 180)
	detail_text.add_theme_color_override("default_color", Color("#203b36"))
	detail_text.add_theme_font_size_override("normal_font_size", 21)
	detail_column.add_child(detail_text)
	search.text_changed.connect(func(_text: String): _refresh())
	collection_filter.item_selected.connect(func(_index: int): _refresh())
	type_filter.item_selected.connect(func(_index: int): _refresh())
	card_scroll.resized.connect(_resize_grid)

func open() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focused) if focused != null else null
	overlay.show()
	_refresh()
	search.grab_focus()
	_resize_grid()

func open_deck() -> void:
	collection_filter.select(OWNED_COLLECTION)
	type_filter.select(0)
	search.clear()
	open()

static func install_deck_view(host: Node, ui: Node, position: Vector2) -> void:
	var library = load("res://scripts/ui/card_library.gd").new()
	library.name = "CardLibrary"
	host.add_child(library)
	var button := Button.new()
	button.name = "DeckButton"
	button.text = "查看牌组"
	button.position = position
	button.size = Vector2(200, 48)
	InkSkin.style_button(button)
	ui.add_child(button)
	button.pressed.connect(library.open_deck)


func close() -> void:
	overlay.hide()
	if previous_focus != null:
		var focused = previous_focus.get_ref()
		if is_instance_valid(focused) and focused is Control and focused.is_visible_in_tree():
			focused.grab_focus()

func _input(event: InputEvent) -> void:
	if overlay != null and overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	# Navigation/search is handled by the GUI first; do not leak game shortcuts.
	if overlay != null and overlay.visible:
		get_viewport().set_input_as_handled()

func _resize_grid() -> void:
	if card_scroll != null and grid != null:
		grid.columns = maxi(1, int((card_scroll.size.x - 18.0) / 172.0))

func _matches(entry: Dictionary) -> bool:
	var is_player: bool = entry["owner"] == "玩家"
	var is_skill: bool = is_player and int(entry["id"]) in [13, 14]
	match collection_filter.selected:
		1: if not is_player: return false
		2: if is_player: return false
		3: if not is_skill: return false
		OWNED_COLLECTION: if not is_player or not RunState.deck.has(int(entry["id"])): return false
	if type_filter.selected > 0 and str(entry["type"]) != type_filter.get_item_text(type_filter.selected):
		return false
	var needle := search.text.strip_edges().to_lower()
	var definition: Dictionary = entry["definition"]
	var haystack := "%s %s %s %s" % [entry["name"], definition.get("battle", definition.get("description", "")), definition.get("poem", ""), _availability(entry)]
	return needle.is_empty() or haystack.to_lower().contains(needle)

func _refresh() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	shown_entries.clear()
	for entry: Dictionary in entries:
		if not _matches(entry):
			continue
		shown_entries.append(entry)
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 224)
		button.clip_contents = true
		button.tooltip_text = entry["name"] + "\n" + _availability(entry)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0, 0, 0, 0)
		button.add_theme_stylebox_override("normal", normal)
		var selected := normal.duplicate() as StyleBoxFlat
		selected.border_color = Color("#327e76")
		selected.set_border_width_all(3)
		for state in ["hover", "focus", "pressed"]:
			button.add_theme_stylebox_override(state, selected)
		grid.add_child(button)
		var face := Face.new()
		button.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_face(face, entry)
		if collection_filter.selected == OWNED_COLLECTION:
			var count := Label.new()
			count.name = "OwnedCount"
			count.text = "×%d" % RunState.deck.count(int(entry["id"]))
			count.add_theme_font_size_override("font_size", 23)
			count.add_theme_color_override("font_color", Color("#203b36"))
			var badge := StyleBoxFlat.new()
			badge.bg_color = Color("#efe7cf")
			badge.content_margin_left = 7
			badge.content_margin_right = 7
			count.add_theme_stylebox_override("normal", badge)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(count)
			count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			count.offset_left = -56
			count.offset_top = 8
			count.offset_right = -8
			count.offset_bottom = 40
		button.pressed.connect(_select.bind(entry))
	var viewing_deck := collection_filter.selected == OWNED_COLLECTION
	heading.text = "本趟牌组" if viewing_deck else "剑谱 · 卡牌图鉴"
	subtitle_label.text = "本趟持有的全部卡牌；同名合并显示数量，供选牌与删牌时参考。" if viewing_deck else "翻阅全部招式与剑意；点选卡牌，查看完整效果与获得方式。"
	result_count.text = "本趟共 %d 张 · 当前显示 %d 种" % [RunState.deck.size(), shown_entries.size()] if viewing_deck else "共 %d / %d 张 · 含尚未解锁的招式" % [shown_entries.size(), entries.size()]
	empty_label.visible = shown_entries.is_empty()
	if shown_entries.is_empty():
		detail_face.hide()
		detail_text.text = "没有匹配的卡牌。"
	else:
		var chosen := shown_entries[0]
		for entry: Dictionary in shown_entries:
			if str(entry["key"]) == selected_key:
				chosen = entry
				break
		_select(chosen)

func _set_face(face: Control, entry: Dictionary) -> void:
	if entry["owner"] == "玩家":
		face.set_player_card(int(entry["id"]))
	else:
		face.set_companion_card(str(entry["id"]))

func _select(entry: Dictionary) -> void:
	selected_key = str(entry["key"])
	detail_face.show()
	_set_face(detail_face, entry)
	var definition: Dictionary = entry["definition"]
	var effect := str(definition.get("battle", definition.get("description", "")))
	var lines := [effect, "", _availability(entry)]
	if collection_filter.selected == OWNED_COLLECTION:
		lines.insert(0, "本趟持有：%d 张\n" % RunState.deck.count(int(entry["id"])))
	if entry["owner"] == "玩家" and int(entry["id"]) in [13, 14]:
		lines.append("按钮技能：不占手牌；不增加也不中断连续攻击计数。")
	if definition.has("poem"):
		lines.append("\n" + str(definition["poem"]) + "\n" + str(definition.get("source", "")))
	var notes: Array[String] = []
	if entry["owner"] == "玩家":
		notes.append("连续攻击计数只累计本回合连续打出的攻击手牌；非攻击手牌清零，流光/华彩不增加也不中断。")
	if effect.contains("连击") or entry["type"] == "攻击":
		notes.append("连击层数与连续攻击计数不同。玩家普通攻击、流光和华彩每层加%d伤害；护盾攻击与反击不吃这项加伤，小墨按各牌倍率结算。" % BalanceConfig.ATTACK_COMBO_BONUS)
	if effect.contains("格挡") or effect.contains("护盾"):
		notes.append("格挡/护盾先抵消入伤；下个玩家回合开始时通常清空，留盾保留剩余量。")
	if effect.contains("易伤"):
		notes.append("易伤每层让每次命中固定加1伤害，敌方回合末减1层。")
	if not notes.is_empty():
		lines.append("\n【关键词】\n" + "\n\n".join(notes))
	detail_text.text = "\n".join(lines)
	detail_text.scroll_to_line(0)

func _availability(entry: Dictionary) -> String:
	var definition: Dictionary = entry["definition"]
	if entry["owner"] == "玩家":
		var card_id := int(entry["id"])
		if card_id in [13, 14]:
			return "羁绊达到「%s」解锁。" % STAGES[clampi(int(definition["bond_stage"]), 0, 3)]
		if card_id == 7:
			return "诅咒牌 · 无法打出。"
		if card_id in CardDatabase.REWARD_CARD_IDS:
			return "可从战斗奖励获得。"
		return "初始牌组中的基础招式。"
	if definition.has("poem"):
		return "小墨剑意 · 在飞花令中对出对应诗句后领悟。"
	return "小墨行动 · 羁绊达到「%s」后可选择；由小墨决定出招。" % STAGES[clampi(int(definition.get("min_bond_stage", 0)), 0, 3)]
