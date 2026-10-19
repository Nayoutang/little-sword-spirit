extends SceneTree

# 信物：获取、单趟清空、远征存档（含旧档兼容）、战斗各时机触发、精英掉落、宝箱选项、奖励页展示。
const Relics = preload("res://scripts/data/relic_database.gd")
const Checkpoint = preload("res://scripts/data/expedition_checkpoint.gd")
const CompanionCards = preload("res://scripts/data/companion_card_database.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func _fresh(state) -> void:
	state._reset_slot_state()
	state.intro_done = true
	state.start_new_run()


func _battle(state, relics: Array[String], encounter = null):
	state.run_relics.assign(relics)
	state.pending_encounter = state.EncounterType.NORMAL if encounter == null else encounter
	state.battle_seed = 4242
	state.checkpoint("battle")
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.force_offline_companion = true
	root.add_child(battle)
	return battle


func _visible_hand(battle) -> int:
	var count := 0
	for button in battle.hand_buttons:
		if button.visible:
			count += 1
	return count


func run() -> void:
	assert(OS.get_environment("APPDATA").contains("relic-user"))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	check(Relics.DEFINITIONS.size() == 13, "十三件信物")
	for id in Relics.DEFINITIONS:
		var d: Dictionary = Relics.DEFINITIONS[id]
		check(not str(d.get("name", "")).is_empty() and not str(d.get("text", "")).is_empty(), id + " 名称与说明")

	# 获取与清空。
	_fresh(state)
	check(state.gain_relic(Relics.OLD_SCABBARD) and not state.gain_relic(Relics.OLD_SCABBARD), "不重复获得")
	check(not state.gain_relic("nope"), "未知信物拒绝")
	check(str(state.current_run_journal.back().details.get("relic", "")) == Relics.OLD_SCABBARD, "记入出行记录")
	var owned: Array[String] = []
	for i in Relics.DEFINITIONS.size():
		var id := Relics.roll(owned)
		check(not id.is_empty() and not owned.has(id), "抽取不重复")
		owned.append(id)
	check(Relics.roll(owned).is_empty(), "全拿过时不再出")
	state.start_new_run()
	check(state.run_relics.is_empty(), "新一趟清空")

	# 存档：新档带信物，旧档缺字段也有效。
	_fresh(state)
	state.gain_relic(Relics.HALF_JADE)
	state.checkpoint("map")
	var snapshot: Dictionary = state.expedition_checkpoint.duplicate(true)
	check(Checkpoint.valid(snapshot) and snapshot.state.run_relics == [Relics.HALF_JADE], "存档带信物")
	state.run_relics.clear()
	Checkpoint.restore(state, snapshot)
	check(state.run_relics == [Relics.HALF_JADE], "读档恢复信物")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.state.erase("run_relics")
	check(Checkpoint.valid(legacy), "旧档无信物字段仍有效")
	Checkpoint.restore(state, legacy)
	check(state.run_relics.is_empty(), "旧档读出来没有信物")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.state.run_relics = ["nope"]
	check(not Checkpoint.valid(bad), "未知信物 id 判无效")

	# 开战：旧剑鞘 +6 格挡，磨剑石片 +1 精力。
	_fresh(state)
	var plain = _battle(state, [])
	var base_block: int = plain.block
	var base_energy: int = plain.energy
	plain.free()
	_fresh(state)
	var started = _battle(state, [Relics.OLD_SCABBARD, Relics.WHETSTONE_CHIP])
	check(started.block == base_block + 6, "旧剑鞘格挡")
	check(started.energy == base_energy + 1, "磨剑石片精力")

	# 读意向：青色剑穗抽牌、同心结连击、铜铃精力。
	state.run_relics.assign([Relics.GREEN_TASSEL, Relics.LOVERS_KNOT, Relics.BRONZE_BELL])
	started.locked_companion_choice = {"card_id": CompanionCards.GUARD_ECHO}
	var hand_before := _visible_hand(started)
	started._apply_intent_relics()
	check(_visible_hand(started) == hand_before + 1, "青色剑穗抽 1")
	started.locked_companion_choice = {"card_id": CompanionCards.LEAD_MOMENTUM}
	var combo_before: int = started.combo
	started._apply_intent_relics()
	check(started.combo == combo_before + 1, "同心结连击 +1")
	started.locked_companion_choice = {"card_id": CompanionCards.LONE_JUDGMENT}
	var energy_before: int = started.energy
	started._apply_intent_relics()
	check(started.energy == energy_before + 1, "铜铃精力 +1")
	state.run_relics.clear()
	energy_before = started.energy
	started._apply_intent_relics()
	check(started.energy == energy_before, "没有信物不触发")

	# 护心镜：她出防护牌额外 +3。
	var block_before: int = started.block
	started._apply_companion_card({"card_id": CompanionCards.GUARD_ECHO, "reason": "测试"})
	var plain_gain: int = started.block - block_before
	state.run_relics.assign([Relics.HEART_MIRROR])
	block_before = started.block
	started._apply_companion_card({"card_id": CompanionCards.GUARD_ECHO, "reason": "测试"})
	check(started.block - block_before == plain_gain + 3, "护心镜 +3")

	# 半块玉佩：接住机会回 3。
	state.run_relics.assign([Relics.HALF_JADE])
	started.player_hp = 40
	started.cooperation_windows = {"resource": {"used": false, "source": CompanionCards.LEAD_MOMENTUM}}
	started._use_cooperation_window()
	check(started.player_hp == 43, "半块玉佩回 3")
	started.free()

	# 精英胜利掉信物；酒葫芦战后回血。
	_fresh(state)
	state.set_player_hp(50)
	var elite = _battle(state, [Relics.WINE_GOURD], state.EncounterType.ELITE)
	elite.player_hp = 50
	elite._end_battle(true)
	check(state.run_relics.size() == 2, "精英掉一件信物")
	check(state.player_hp == 56, "酒葫芦回 6")
	var dropped := str(state.room_checkpoint("reward").get("relic", ""))
	check(state.run_relics.has(dropped) and dropped != Relics.WINE_GOURD, "奖励存档记着掉落")
	elite.free()
	var reward = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(reward)
	check(reward.message_label.text.contains(Relics.relic_name(dropped)), "奖励页展示信物")
	check(str(state.room_checkpoint("reward").get("relic", "")) == dropped, "选卡存档保留信物")
	reward.free()

	# 普通战不掉。
	_fresh(state)
	var normal = _battle(state, [])
	normal._end_battle(true)
	check(state.run_relics.is_empty(), "普通战不掉信物")
	normal.free()

	# 宝箱：第四个选项。
	_fresh(state)
	state.pending_event = state.EventType.TREASURE
	state.checkpoint("event")
	var chest = load("res://scenes/event.tscn").instantiate()
	root.add_child(chest)
	var relic_button: Button = chest.main_choices.get_node("Relic")
	check(relic_button != null and not relic_button.disabled, "宝箱有信物选项")
	chest._choose_relic()
	check(state.run_relics.size() == 1 and chest.finishing, "宝箱取信物")
	chest.free()
	print("RELICS: %s (failures=%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
