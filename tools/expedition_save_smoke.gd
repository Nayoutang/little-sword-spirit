extends SceneTree

const Storage = preload("res://scripts/data/save_slot_storage.gd")
const Codec = preload("res://scripts/data/expedition_checkpoint.gd")
var failures := 0
var state

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func map_signature(map) -> Array:
	var result: Array = []
	for layer in map.layers:
		for node in layer:
			var edges: Array = []
			for target in map.connections.get(node, []):
				edges.append([target.layer_index, map.layers[target.layer_index].find(target)])
			result.append([node.node_type, node.position, edges])
	return result

func battle_scene():
	var b = load("res://scenes/battle.tscn").instantiate()
	b.force_offline_companion = true
	root.add_child(b)
	return b

func run() -> void:
	create_timer(55).timeout.connect(func(): quit(2))
	check(OS.get_environment("APPDATA").contains("expedition-save-user"), "存档测试必须使用独立目录")
	if failures: quit(1); return
	state = root.get_node("RunState")
	state.suppress_persistence = false
	for slot in [1,2,3]: state.delete_save_slot(slot)
	state.select_save_slot(1)
	state.player_name = "远征测试"
	state.intro_done = true
	state.bond_value = 25
	state.bond_stage = 1
	state.start_new_run()
	check(state.resume_destination() == Codec.SCENES.promise, "出门约定也有检查点")
	state.active_promise = "finish"
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	var signature := map_signature(map)
	state.map_layer = 7
	state.map_node = 2
	state.map_path = [[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2]]
	state.route_layer = 7
	state.player_hp = 51
	state.player_max_hp = 96
	state.deck.append(19)
	state.run_adventures.append(2)
	state.record_moment("同行的瞬间", 2)
	check(state.checkpoint("map") == OK, "地图快照落盘成功")
	var deck: Array = state.deck.duplicate()
	var map_seed: int = state.map_seed
	map.free()
	state.select_save_slot(2)
	check(not state.has_expedition() and state.map_seed == 0 and state.player_hp == 90, "切换空档清空上一趟地图与生命")
	state.select_save_slot(1)
	check(state.has_expedition() and state.map_seed == map_seed and state.map_layer == 7 and state.map_node == 2, "切回存档恢复节点及地图种子")
	check(state.player_hp == 51 and state.player_max_hp == 96 and state.deck == deck and state.active_promise == "finish", "恢复血量、牌组与约定")
	check(state.run_adventures == [2] and state.run_moments.size() == 1, "恢复奇遇去重与本趟记忆")
	map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	check(map_signature(map) == signature and map.current_node.layer_index == 7, "重建同一地图、连线、精英与未知节点")
	check(map.get_node("MapUI/SaveExitButton").text == "保存并退出", "地图保存入口存在")
	map.free()
	state.pending_encounter = state.EncounterType.ELITE
	state.battle_seed = 789231
	check(state.checkpoint("battle") == OK, "战斗开场检查点成功")
	var stats: Dictionary = state.relationship_facts.duplicate(true)
	var battle_index: int = state.run_battle_index
	var b = battle_scene()
	var opening: Array = [b.hand.duplicate(), b.enemy_hps.duplicate(), b.enemy_roles.duplicate(), b.enemy_intents.duplicate(true), b.draw_pile.duplicate()]
	b._resolve_enemy_attack_segment(0,0,10)
	state.player_hp = b.player_hp
	state.record_cooperation("guards", 3)
	state.record_run_fact("battle", "未完成的战斗记录")
	state.save_persistent_state()
	b.free()
	state.select_save_slot(1)
	check(state.player_hp == 51 and state.run_battle_index == battle_index and state.relationship_facts == stats, "中途退出回滚至战斗开头，临时伤害和合作统计不重复记账")
	b = battle_scene()
	check([b.hand.duplicate(),b.enemy_hps.duplicate(),b.enemy_roles.duplicate(),b.enemy_intents.duplicate(true),b.draw_pile.duplicate()] == opening, "战斗恢复相同敌人、开场手牌与抽牌顺序")
	b._end_battle(true)
	check(state.expedition_checkpoint.phase == "reward", "胜利立即保存至待领奖励")
	var won_bond: int = state.bond_value
	b.free()
	state.select_save_slot(1)
	var reward = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(reward)
	var cards: Array = state.room_checkpoint("reward").cards.duplicate()
	reward.free()
	state.select_save_slot(1)
	reward = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(reward)
	check(state.room_checkpoint("reward").cards == cards and state.bond_value == won_bond, "重进奖励不刷新候选牌或重复战斗羁绊")
	reward._choose_card(cards[0])
	check(state.room_checkpoint("reward").get("removing", false), "精英选牌后保存待删牌阶段")
	reward.free()
	state.select_save_slot(1)
	check(state.deck.size() == deck.size()+1, "精英选牌只领取一次")
	reward = load("res://scenes/battle_reward.tscn").instantiate()
	root.add_child(reward)
	check(reward.removing and not reward.card_choices.visible, "继续时直接恢复删牌界面")
	reward._skip_choice()
	reward.free()
	state.select_save_slot(1)
	check(state.resume_destination() == Codec.SCENES.map and state.deck.size() == deck.size()+1, "奖励完成自动保存，不能重复领取")
	state.pending_event = state.EventType.TREASURE
	state.checkpoint("event")
	var event = load("res://scenes/event.tscn").instantiate()
	root.add_child(event)
	event._show_card_choices()
	cards = state.room_checkpoint("event").cards.duplicate()
	event.free()
	state.select_save_slot(1)
	event = load("res://scenes/event.tscn").instantiate()
	root.add_child(event)
	check(event.card_choices.visible and state.room_checkpoint("event").cards == cards, "宝箱选牌恢复同一组候选")
	event._choose_card(cards[0])
	event.free()
	state.select_save_slot(1)
	check(state.resume_destination() == Codec.SCENES.map and state.deck.size() == deck.size()+2, "宝箱奖励完成不重复领取")
	state.checkpoint("adventure", {"comic":2})
	state.select_save_slot(1)
	var adventure = load("res://scenes/adventure.tscn").instantiate()
	adventure.force_offline = true
	root.add_child(adventure)
	check(adventure.selected_adventure_index == 2 and state.run_adventures == [2], "漫画恢复同一奇遇，不重复抽取")
	adventure._resolve_choice(adventure.current_adventure.choices[0])
	adventure.free()
	state.select_save_slot(1)
	check(state.resume_destination() == Codec.SCENES.map, "漫画效果结算后保存到地图")
	state.finish_run(true)
	state.checkpoint("settlement")
	var settlement = load("res://scenes/settlement.tscn").instantiate()
	root.add_child(settlement)
	var bond: int = state.bond_value
	settlement.free()
	state.select_save_slot(1)
	settlement = load("res://scenes/settlement.tscn").instantiate()
	root.add_child(settlement)
	check(state.settlement_applied and state.bond_value == bond, "重进结算不会重复发约定奖励")
	settlement.free()
	state.clear_expedition()
	state.select_save_slot(1)
	check(not state.has_expedition() and state.resume_destination() == "res://scenes/home.tscn", "结算归家清除远征继续入口")
	# Legacy saves remain ordinary home saves; unknown snapshots never half-apply.
	var config := ConfigFile.new()
	config.set_value("relationship", "bond_value", 40)
	config.set_value("profile", "player_name", "旧档")
	config.save("user://save_slot_3.cfg")
	state.select_save_slot(3)
	check(state.player_name == "旧档" and state.bond_value == 40 and not state.has_expedition(), "旧长期存档兼容")
	state.start_new_run()
	var invalid: Dictionary = state.expedition_checkpoint.duplicate(true)
	invalid.version = 999
	config = state._profile_config()
	config.set_value("expedition","checkpoint",invalid)
	config.save("user://save_slot_3.cfg")
	state.select_save_slot(3)
	check(state.player_name == "旧档" and not state.has_expedition() and state.player_hp == 90, "未知版本不污染运行态，保留长期进度")
	state.start_new_run()
	state.map_seed = 123
	state.checkpoint("map")
	state.checkpoint("map")
	var f := FileAccess.open("user://save_slot_3.cfg",FileAccess.WRITE)
	f.store_string("[broken")
	f.close()
	state.select_save_slot(3)
	check(state.has_expedition() and state.map_seed == 123, "损坏主文件从可读备份恢复")
	check(Storage.write_atomic(state._profile_config(),"user://missing-folder/save.cfg") != OK, "写入失败返回错误而非报告成功")
	var invalid_card: Dictionary = state.expedition_checkpoint.duplicate(true)
	invalid_card.state.deck = [999999]
	check(not Codec.valid(invalid_card), "拒绝未知卡牌ID")
	state.delete_save_slot(3)
	check(not FileAccess.file_exists("user://save_slot_3.cfg.bak") and not state.has_expedition(), "删档同步移除备份，不会复活旧存档")
	print("EXPEDITION SAVE: failures=%d" % failures)
	quit(1 if failures else 0)
