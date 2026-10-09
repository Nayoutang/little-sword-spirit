extends Node2D

var pending_delete_slot := 0

@onready var slot_buttons: Array[Button] = [
	$SaveUI/Slots/Slot1/Open,
	$SaveUI/Slots/Slot2/Open,
	$SaveUI/Slots/Slot3/Open,
]
@onready var delete_buttons: Array[Button] = [
	$SaveUI/Slots/Slot1/Delete,
	$SaveUI/Slots/Slot2/Delete,
	$SaveUI/Slots/Slot3/Delete,
]


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
		slot_buttons[index].pressed.connect(_open_slot.bind(index + 1))
		delete_buttons[index].pressed.connect(_request_delete.bind(index + 1))
	_refresh_slots()


func _open_slot(slot: int) -> void:
	if slot_buttons[0].disabled:
		return
	for button in slot_buttons:
		button.disabled = true
	RunState.select_save_slot(slot)
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
	for index in range(RunState.SAVE_SLOT_COUNT):
		var slot := index + 1
		var summary: Dictionary = RunState.get_save_slot_summary(slot)
		if summary["exists"]:
			slot_buttons[index].text = "存档 %d\n继续远征 · 第%d层" % [slot, summary["layer"]] if summary.get("expedition", false) else "存档 %d\n继续与小墨的旅途" % slot
			delete_buttons[index].disabled = false
		else:
			slot_buttons[index].text = "存档 %d\n新游戏" % slot
			delete_buttons[index].disabled = true
		delete_buttons[index].text = "删除存档"
