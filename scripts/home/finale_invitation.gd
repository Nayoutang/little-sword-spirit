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
		RunState.navigate("finale", self)
	elif RunState.finale_state == "story":
		RunState.navigate("finale", self)
	elif RunState.finale_state == "battle":
		if not RunState.has_expedition():
			RunState.prepare_finale_battle()
		RunState.navigate("battle", self)
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
	RunState.navigate("finale", self)
func _depart() -> void:
	if RunState.finale_state != "accepted": return
	RunState.set_finale_state("story", "arrival")
	RunState.navigate("finale", self)
