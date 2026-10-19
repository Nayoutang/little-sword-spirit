extends Node2D

var pending_delete_slot := 0

var slot_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []


func _ready() -> void:
	var card_library = preload("res://scripts/ui/card_library.gd").new()
	card_library.name = "CardLibrary"
	add_child(card_library)
	var library_button := Button.new()
	library_button.name = "CardLibraryButton"
	library_button.text = "剑谱 · 卡牌图鉴"
	library_button.position = Vector2(1560, 45)
	library_button.size = Vector2(300, 58)
	preload("res://scripts/ui/ink_ui_skin.gd").style_button(library_button)
	$SaveUI.add_child(library_button)
	library_button.pressed.connect(card_library.open)
	for index in range(RunState.SAVE_SLOT_COUNT):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		$SaveUI/Scroll/Slots.add_child(row)
		var open := Button.new()
		open.custom_minimum_size = Vector2(600, 120)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(open)
		var delete := Button.new()
		delete.custom_minimum_size = Vector2(180, 120)
		row.add_child(delete)
		preload("res://scripts/ui/ink_ui_skin.gd").style_button(open)
		preload("res://scripts/ui/ink_ui_skin.gd").style_button(delete)
		slot_buttons.append(open)
		delete_buttons.append(delete)
		slot_buttons[index].pressed.connect(_open_slot.bind(index + 1))
		delete_buttons[index].pressed.connect(_request_delete.bind(index + 1))
	_refresh_slots()
	$SaveUI/Back.pressed.connect(_back_to_main_menu)

func _back_to_main_menu() -> void:
	RunState.save_selection_mode = "all"
	RunState.navigate("main_menu", self)


func _open_slot(slot: int) -> void:
	if slot_buttons[slot - 1].disabled or RunState.is_scene_transition_pending():
		return
	for button in slot_buttons:
		button.disabled = true
	RunState.select_save_slot(slot)
	RunState.save_selection_mode = "all"
	var error := RunState.navigate(RunState.resume_expedition(), self)
	if error != OK:
		for button in slot_buttons:
			button.disabled = false


func _request_delete(slot: int) -> void:
	if pending_delete_slot != slot:
		pending_delete_slot = slot
		_refresh_slots()
		delete_buttons[slot - 1].text = "再次点击确认"
		return
	RunState.delete_save_slot(slot)
	pending_delete_slot = 0
	_refresh_slots()


func _refresh_slots() -> void:
	var mode: String = RunState.save_selection_mode
	$SaveUI/Title.text = "开始新的旅途" if mode == "new" else "继续旅途" if mode == "continue" else "选择存档"
	var has_empty := false
	for slot in range(1, RunState.SAVE_SLOT_COUNT + 1):
		has_empty = has_empty or not bool(RunState.get_save_slot_summary(slot)["exists"])
	var new_hint := "选择一个空存档开始新的旅途 · 已有旅途不会被覆盖" if has_empty else "存档已满，请先删除一个存档再开始新的旅途"
	$SaveUI/Hint.text = new_hint if mode == "new" else "选择已有存档继续 · 共12个存档 · 向下滚动查看更多" if mode == "continue" else "点有存档的位置继续，点空位开始新旅途 · 共12个存档 · 向下滚动查看更多"
	for index in range(RunState.SAVE_SLOT_COUNT):
		var slot := index + 1
		var summary: Dictionary = RunState.get_save_slot_summary(slot)
		slot_buttons[index].disabled = (mode == "new" and summary["exists"]) or (mode == "continue" and not summary["exists"])
		if summary["exists"]:
			var description := "继续与小墨的旅途"
			if summary.get("finale_state", "locked") == "battle":
				description = "继续旧祠决战"
			elif summary.get("expedition", false):
				var layer := int(summary["layer"])
				var route_name := "追线" if int(summary.get("chapter", 1)) == 2 else "山门试炼"
				description = "继续%s · 第%d层" % [route_name, layer] if layer > 0 else "%s · 待出发" % route_name
			slot_buttons[index].text = "存档 %d\n%s" % [slot, description]
			delete_buttons[index].disabled = false
		else:
			slot_buttons[index].text = "存档 %d\n新游戏" % slot
			delete_buttons[index].disabled = true
		delete_buttons[index].text = "删除存档"
