extends "res://tools/shield_baseline_battle.gd"

func _configure_encounter() -> void:
	enemy_count = 1
	enemy_hps.assign([180])
	enemy_roles.assign(["swordsman"])
	enemy_guards.assign([0])
	enemy_strengths.assign([0])
	enemy_vulnerabilities.assign([0])
	enemy_attack_reductions.assign([0])

func _roll_enemy_intents() -> void:
	super._roll_enemy_intents()
	enemy_intents.resize(1)

func _enemy_name(_index: int) -> String:
	return "连攻木偶" if calibration_continuous else "蓄力木偶"

func _build_companion_context() -> Dictionary:
	var context := super._build_companion_context()
	context["enemies"][0]["rule"] = "每回合攻击" if calibration_continuous else "交替蓄力一回合、攻击一回合"
	return context

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
		calibration_continuous = event.keycode in [KEY_3,KEY_4]
		calibration_multi = event.keycode in [KEY_2,KEY_4]
		calibration_hit = 24 if calibration_continuous else 30
	elif event.keycode != KEY_R:
		return
	RunState.player_hp = 90
	fixed_random_seed += 1
	start_battle()
	_update_playtest_title()

func _ready() -> void:
	super._ready()
	_update_playtest_title()

func _update_playtest_title() -> void:
	DisplayServer.window_set_title("护盾构筑试玩 · %s%s · R重开 · 1/2间歇单/三段 · 3/4持续单/三段" % ["持续" if calibration_continuous else "间歇","三段" if calibration_multi else "单段"])

func _end_battle(won: bool) -> void:
	if battle_finished: return
	super._end_battle(won)
	message_label.text = "练习结束：%s。按R再来一局，或按1–4切换对手。" % ["胜利" if won else "失败"]
	BoundedLog.append("res://.godot/shield-playtest.jsonl", {"won":won,"hp":player_hp,"continuous":calibration_continuous,"multi":calibration_multi,"seed":fixed_random_seed,"metrics":combo_telemetry.summary(),"intent_choices":companion_selection_records.duplicate(true)},true,1048576)
