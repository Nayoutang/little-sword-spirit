extends Control

const DESIGN_SIZE := Vector2(1672, 941)
var leaving := false

func _ready() -> void:
	resized.connect(_layout)
	_layout()
	preload("res://scripts/ui/ink_ui_skin.gd").style_button($SettingsPanel/Card/Close)
	$Stage/Start.pressed.connect(_start_new_game)
	$Stage/Continue.pressed.connect(_continue_latest)
	$Stage/Settings.pressed.connect(_open_settings)
	$Stage/Quit.pressed.connect(func(): get_tree().quit())
	$SettingsPanel/Card/Close.pressed.connect(_close_settings)
	$SettingsPanel/Card/Fullscreen.toggled.connect(WindowMode.set_fullscreen)
	$SettingsPanel/Card/Fullscreen.visible = not WindowMode.is_mobile()
	$SettingsPanel/Card/Volume.value_changed.connect(_set_volume)
	var has_save := false
	for slot in range(1, RunState.SAVE_SLOT_COUNT + 1):
		has_save = has_save or bool(RunState.get_save_slot_summary(slot)["exists"])
	$Stage/Continue.disabled = not has_save
	for button: Button in [$Stage/Start, $Stage/Continue, $Stage/Settings, $Stage/Quit]:
		button.mouse_entered.connect(_highlight.bind(button, true))
		button.mouse_exited.connect(_highlight.bind(button, false))
	$Stage/Start.grab_focus()

func _layout() -> void:
	var ratio := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y) if WindowMode.is_mobile() else maxf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	$Stage.scale = Vector2.ONE * ratio
	$Stage.position = (size - DESIGN_SIZE * ratio) * 0.5

func _highlight(button: Button, active: bool) -> void:
	button.modulate = Color(1.18, 1.12, 1.0) if active and not button.disabled else Color.WHITE

func _open_saves(mode: String) -> void:
	if leaving:
		return
	leaving = true
	RunState.save_selection_mode = mode
	if RunState.navigate("save_select", self) != OK:
		leaving = false

func _start_new_game() -> void:
	if leaving:
		return
	for slot in range(1, RunState.SAVE_SLOT_COUNT + 1):
		if RunState.get_save_slot_summary(slot)["exists"]:
			# 已有存档时进入存档列表：有存档的位置继续，空位开始新旅途。
			_open_saves("all")
			return
	# 第一次游玩没有任何存档，直接从存档 1 开始。
	leaving = true
	RunState.select_save_slot(1)
	RunState.save_selection_mode = "all"
	if RunState.navigate(RunState.resume_expedition(), self) != OK:
		leaving = false

# 继续旅途：直接进入最近一次保存的存档，不再经过存档列表。
func _continue_latest() -> void:
	if leaving:
		return
	var latest_slot := 0
	var latest_time := -1
	for slot in range(1, RunState.SAVE_SLOT_COUNT + 1):
		if not RunState.get_save_slot_summary(slot)["exists"]:
			continue
		var path: String = RunState._save_path_for_slot(slot)
		var modified := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else FileAccess.get_modified_time(path + ".bak")
		if modified > latest_time:
			latest_time = modified
			latest_slot = slot
	if latest_slot == 0:
		return
	leaving = true
	RunState.select_save_slot(latest_slot)
	RunState.save_selection_mode = "all"
	if RunState.navigate(RunState.resume_expedition(), self) != OK:
		leaving = false

func _open_settings() -> void:
	$SettingsPanel/Card/Fullscreen.set_pressed_no_signal(WindowMode.is_fullscreen())
	$SettingsPanel/Card/Volume.set_value_no_signal(WindowMode.master_volume * 100.0)
	$SettingsPanel.show()
	for button: Button in [$Stage/Start, $Stage/Continue, $Stage/Settings, $Stage/Quit]:
		button.focus_mode = Control.FOCUS_NONE
	$SettingsPanel/Card/Close.grab_focus()

func _close_settings() -> void:
	$SettingsPanel.hide()
	for button: Button in [$Stage/Start, $Stage/Continue, $Stage/Settings, $Stage/Quit]:
		button.focus_mode = Control.FOCUS_ALL
	$Stage/Settings.grab_focus()

func _set_volume(value: float) -> void:
	WindowMode.set_master_volume(value / 100.0)

func handle_mobile_back() -> bool:
	if $SettingsPanel.visible:
		_close_settings()
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and $SettingsPanel.visible:
		get_viewport().set_input_as_handled()
		_close_settings()
