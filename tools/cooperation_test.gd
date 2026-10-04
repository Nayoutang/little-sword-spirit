extends Node

func _enter_tree() -> void:
	# 独立实验入口，不解锁正式存档里的剑意，也不写正式存档。
	RunState.suppress_persistence = true
	RunState.player_max_hp = 90
	RunState.player_hp = 90
	RunState.relationship_facts["cooperation"] = {}
	$Battle.fixed_cooperation_test = true
	$Battle.force_offline_companion = true
