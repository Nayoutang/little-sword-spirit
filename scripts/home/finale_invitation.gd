extends CanvasLayer
func _ready() -> void:
	if RunState.needs_intro():
		$Invite.hide()
		$Journey.hide()
		return
	for button in [$Invite/Go, $Invite/Stay, $Journey]:
		preload("res://scripts/ui/ink_ui_skin.gd").style_button(button)
	$Invite.hide()
	$Journey.hide()
	$Invite/Go.pressed.connect(_accept)
	$Invite/Stay.pressed.connect(_refuse)
	$Journey.pressed.connect(_depart)
	if RunState.finale_state == "ended":
		get_tree().call_deferred("change_scene_to_file", "res://scenes/finale.tscn")
	elif RunState.finale_state == "story":
		get_tree().call_deferred("change_scene_to_file", "res://scenes/finale.tscn")
	elif RunState.finale_state == "battle":
		RunState.pending_encounter = RunState.EncounterType.BOSS
		get_tree().call_deferred("change_scene_to_file", "res://scenes/battle.tscn")
	elif RunState.finale_state == "accepted": $Journey.show()
	elif RunState.bond_value >= 100:
		RunState.set_finale_state("invited")
		$Invite.show()
		get_parent().get_node("ChatUI/ChatPanel").hide()
func _accept() -> void:
	if RunState.finale_state != "invited": return
	RunState.set_finale_state("accepted")
	$Invite.hide()
	get_parent().get_node("ChatUI/ChatPanel").show()
	$Journey.show()
func _refuse() -> void:
	if RunState.finale_state != "invited": return
	RunState.set_finale_state("story", "refusal")
	get_tree().change_scene_to_file("res://scenes/finale.tscn")
func _depart() -> void:
	if RunState.finale_state != "accepted": return
	RunState.set_finale_state("story", "arrival")
	get_tree().change_scene_to_file("res://scenes/finale.tscn")
