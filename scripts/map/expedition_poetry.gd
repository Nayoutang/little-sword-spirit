extends Node2D

@export var force_offline := false
var controller: FeihualingController
var started := false
var leaving := false
@onready var screen: Control = $FeihualingLayer/GameScreen
@onready var status: Label = $FeihualingLayer/GameScreen/Status
@onready var log_text: RichTextLabel = $FeihualingLayer/GameScreen/GameLog
@onready var input: LineEdit = $FeihualingLayer/GameScreen/GameInput
@onready var send: Button = $FeihualingLayer/GameScreen/GameSendButton


func _ready() -> void:
	controller = FeihualingController.new()
	controller.scene_context = "当前在远征途中歇脚对诗，不在家中；结束后继续赶路，不要把对诗结果说成远征结算。"
	add_child(controller)
	controller.spoken.connect(func(text: String): log_text.add_text("小墨：%s\n\n" % text))
	controller.hud_changed.connect(func(text: String, visible: bool): status.text = text if visible else "途中飞花令")
	controller.busy_changed.connect(func(_busy: bool): _refresh_controls())
	controller.finished.connect(_on_finished)
	controller.opening_failed.connect(_on_opening_failed)
	controller.intent_learned.connect(_on_intent_learned)
	screen.show()
	$FeihualingLayer/GameScreen/AgainButton.hide()
	$FeihualingLayer/GameScreen/ExitButton.text = "继续赶路"
	$FeihualingLayer/GameScreen/ExitButton.pressed.connect(_leave)
	send.pressed.connect(_submit)
	input.text_submitted.connect(func(_text: String): _submit())
	status.text = "奇遇 · 途中飞花令"
	log_text.text = "赶路间，你们在亭边稍作停留。\n\n小墨：总盯着前面的路做什么？歇一会儿，接几句诗再走。\n\n可以留空随机抽令字，或输入一个汉字自选。对出特定诗句时，小墨有机会领悟剑意；不想对诗也可以继续赶路。\n"
	input.placeholder_text = "输入一个令字（如：柳），或留空随机…"
	send.text = "开始对诗"
	if not _service_available():
		log_text.add_text("\n对话服务尚未配置，可以继续赶路。")
	_refresh_controls()


func _service_available() -> bool:
	return not force_offline and LLMConfig.is_available()


func _submit() -> void:
	if controller.busy or leaving or not _service_available():
		return
	var text := input.text.strip_edges()
	if not started:
		if not text.is_empty() and not FeihualingGame.is_valid_keyword(text):
			log_text.add_text("\n请选择一个汉字作为令字，或留空随机。\n")
			return
		started = true
		input.clear()
		input.placeholder_text = "输入含令字的诗句，按回车应答…"
		send.text = "应答"
		controller.start(text)
	elif controller.game != null and not text.is_empty():
		input.clear()
		log_text.add_text("你：%s\n\n" % text)
		controller.submit(text)
	_refresh_controls()


func _refresh_controls() -> void:
	var enabled := _service_available() and not controller.busy and not leaving and (not started or controller.game != null)
	input.editable = enabled
	send.disabled = not enabled
	if enabled:
		input.grab_focus()


func _on_opening_failed(keyword: String) -> void:
	started = false
	input.text = keyword
	input.placeholder_text = "输入一个令字，或留空随机…"
	send.text = "重试开场"
	status.text = "开场出句失败 · 不计胜负"
	log_text.add_text("\n[开场失败] 未收到符合令字的开场诗句，本次不计胜负。可以重试、换个令字，或继续赶路。\n")
	_refresh_controls()


func _on_finished(summary: String) -> void:
	log_text.add_text("[对局结束] %s\n\n歇息结束，可以继续赶路。" % summary)
	RunState.record_run_fact("poetry", "途中飞花令：%s" % summary)
	_refresh_controls()


func _on_intent_learned(card_id: String, _player_line: String) -> void:
	var definition := CompanionCardDatabase.get_definition(card_id)
	log_text.add_text("[剑意领悟] %s：%s\n\n" % [definition.get("name", card_id), definition.get("description", "")])


func _leave() -> void:
	if leaving:
		return
	leaving = true
	controller.cancel()
	RunState.record_run_fact("poetry_departure", "途中停留对诗后继续赶路。" if started else "途经对诗歇脚处，选择继续赶路。")
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _exit_tree() -> void:
	if is_instance_valid(controller):
		controller.cancel()
