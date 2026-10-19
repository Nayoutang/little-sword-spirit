extends SceneTree

# 大话骰：规则、她的判断、破绽统计、桌面流程。离线、不写存档。
var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var Game = load("res://scripts/home/liar_dice_game.gd")

	# ---- 规则 ----
	var g = Game.new(3)
	g.start_round("player")
	check(g.player_dice.size() == 5 and g.xiaomo_dice.size() == 5, "各五颗")
	check(not g.is_legal_bid(1, 3) and not g.is_legal_bid(3, 1) and g.is_legal_bid(2, 2), "开局至少两个，不能叫一")
	check(g.player_bid(3, 4), "玩家叫三个四")
	check(not g.is_legal_bid(3, 3) and g.is_legal_bid(3, 5) and g.is_legal_bid(4, 2), "加注规则")
	check(g.minimum_raise(5) == 3 and g.minimum_raise(3) == 4, "最小加注")
	g.player_dice.assign([1, 4, 4, 2, 6])
	g.xiaomo_dice.assign([1, 3, 5, 5, 6])
	check(g.actual_count(4) == 4 and g.actual_count(5) == 4, "一点算赖子")
	check(is_equal_approx(Game.at_least(0, 5), 1.0) and Game.at_least(6, 5) == 0.0, "概率边界")
	check(g.xiaomo_belief(2, 5) == 1.0, "她手上三个五，两个五稳了")

	# 玩家开：她吹牛被抓
	g.turn = "xiaomo"
	g._set_bid("xiaomo", 6, 3, true)
	g.turn = "player"
	var r: Dictionary = g.player_open()
	check(not r.bid_true and r.winner == "player" and g.xiaomo_coins == 2 and g.caught_bluffs == 1, "开中她吹牛，她交一枚")
	check(g.turn == "xiaomo", "输的人先叫下一轮")

	# ---- 她的判断：离谱的叫数她会开 ----
	var opens := 0
	for s in range(40):
		var h = Game.new(100 + s)
		h.start_round("player")
		h.player_bid(8, 6)
		var d: Dictionary = h.xiaomo_decide()
		if d.action == "open": opens += 1
	check(opens >= 38, "八个六基本必开（%d/40）" % opens)
	var raises := 0
	for s in range(40):
		var h = Game.new(200 + s)
		h.start_round("player")
		h.player_bid(2, 3)
		if h.xiaomo_decide().action == "bid": raises += 1
	check(raises >= 34, "两个三基本会接（%d/40）" % raises)

	# ---- 破绽：吹牛时更常露馅，玩多了更准 ----
	var stats := {}
	for played in [0, 10]:
		var hit := 0
		var total := 0
		for s in range(600):
			var h = Game.new(1000 + s, played)
			h.start_round("player")
			h.player_bid(2, rng_face(s))
			var d: Dictionary = h.xiaomo_decide()
			if d.action != "bid": continue
			total += 1
			var looks_nervous: bool = d.delay < 1.0
			if looks_nervous == d.bluff: hit += 1
		stats[played] = float(hit) / maxf(total, 1)
	check(stats[0] > 0.58 and stats[0] < 0.75, "第一局破绽约 65%%（%.2f）" % stats[0])
	check(stats[10] > 0.83, "玩多了破绽更准（%.2f）" % stats[10])

	# ---- 整局能打完 ----
	var done := 0
	for s in range(30):
		var h = Game.new(500 + s)
		h.start_round("player")
		var guard := 0
		while not h.finished and guard < 400:
			guard += 1
			if h.turn == "player":
				if h.bid_by == "xiaomo" and h.xiaomo_belief(h.bid_count, h.bid_face) < 0.4:
					h.player_open()
				else:
					var f := 2 + (guard % 5)
					if not h.player_bid(h.minimum_raise(f), f):
						h.player_open()
			else:
				h.apply_xiaomo(h.xiaomo_decide())
			if not h.last_result.is_empty() and not h.finished:
				h.start_round()
		if h.finished: done += 1
	check(done == 30, "三十局都能打完（%d）" % done)
	check(Game.new(1).result_summary().begins_with("大话骰"), "结果以大话骰开头")

	# ---- 桌面 ----
	state.relationship_facts["minigame_results"] = []
	var table = load("res://scripts/home/liar_dice_table.gd").new()
	table.seed_value = 42
	root.add_child(table)
	await process_frame
	check(table.game != null and table.my_dice.get_child_count() == 5 and table.her_dice.get_child_count() == 5, "桌面摆好骰子")
	check(table.her_dice.get_child(0).hidden_face and not table.my_dice.get_child(0).hidden_face, "她的骰子盖着")
	check(table.open_button.disabled and not table.bid_button.disabled, "开局只能叫")
	check(not table.result_plate.visible, "未开骰不显示结算数据")
	table.rules_panel.show()
	table.handle_back()
	check(not table.rules_panel.visible and not table.is_queued_for_deletion(), "返回先关规则，保留骰局")
	table._choose_face(3)
	table._on_bid()
	await create_timer(1.6).timeout
	check(table.game.turn == "player" or table.revealed, "她接了一手或开了")
	var rounds := 0
	while not table.game.finished and rounds < 60:
		rounds += 1
		if table.revealed:
			table._on_next()
			await create_timer(1.6).timeout
			continue
		if table.game.bid_by == "xiaomo":
			table._on_open()
		else:
			table._on_bid()
			await create_timer(1.6).timeout
	check(table.game.finished, "桌面一局能打完")
	check(table.result_plate.visible and not table.action_bar.visible, "结算展示胜负并收起叫数操作")
	check(table.secrecy_label.text == "金色为计入的骰子", "开骰后更新保密提示")
	check(not table.tally_label.text.is_empty(), "展示双方数量核算")
	var results: Array = state.relationship_facts.get("minigame_results", [])
	check(results.size() == 1 and str(results[0].summary).begins_with("大话骰"), "结果写进小游戏记忆")
	check(table.previous_games() == 1, "记得玩过几局")
	table._on_next()
	check(not table.game.finished and table.game.player_coins == 3, "再来一局")
	table._on_leave()
	await process_frame

	# ---- 家里的入口 ----
	state.intro_done = true
	state.finale_state = "locked"
	state.feihualing_state = "unlocked"
	state.bond_value = 10
	state.bond_stage = 0
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	await process_frame
	check(not home.dice_button.visible, "初遇时还没有骰局")
	home.queue_free()
	await process_frame
	state.bond_value = 40
	state.bond_stage = 1
	home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	await process_frame
	check(home.dice_button.visible and home.dice_button.text == "骰\n局", "相识后家里挂出骰局")
	var lib: Button = home.get_node("ChatUI/ChatPanel/CardLibraryButton")
	check(lib.offset_left >= 1920 - 780 - 1920 and home.dice_button.offset_right <= home.feihualing_button.offset_left + 20, "五块挂牌排得下")
	home._open_liar_dice()
	await process_frame
	check(home.dice_table != null, "点骰局打开桌面")
	check(home.handle_mobile_back() and home.dice_table == null, "返回键收起骰局")
	home.queue_free()
	await process_frame

	print("Liar dice smoke failures: %d" % failures)
	quit(0 if failures == 0 else 1)

func rng_face(s: int) -> int:
	return 2 + s % 5
