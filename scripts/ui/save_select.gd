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
	for index in range(RunState.SAVE_SLOT_COUNT):
		slot_buttons[index].pressed.connect(_open_slot.bind(index + 1))
		delete_buttons[index].pressed.connect(_request_delete.bind(index + 1))
	_refresh_slots()


func _open_slot(slot: int) -> void:
	RunState.select_save_slot(slot)
	get_tree().change_scene_to_file("res://scenes/home.tscn")


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
			slot_buttons[index].text = "存档 %d\n羁绊 %d/100　%s" % [slot, summary["bond"], summary["stage"]]
			delete_buttons[index].disabled = false
		else:
			slot_buttons[index].text = "存档 %d\n新游戏" % slot
			delete_buttons[index].disabled = true
		delete_buttons[index].text = "删除存档"
