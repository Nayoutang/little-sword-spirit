extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func run() -> void:
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	var intro = load("res://scenes/intro.tscn").instantiate()
	root.add_child(intro)
	check(intro.page.texture != null, "初遇首页未加载")
	check(intro.page.revealed_count == 1, "首页一次显示了多格")
	check(is_zero_approx(intro.page.panels[2].modulate.a), "未读分镜旁白提前出现")
	check(intro.page.fill_frame and intro.page.panels[0].position.is_zero_approx(), "漫画仍存在外围留白")
	check(not intro.next_button.visible and not intro.caption.visible, "初遇仍显示阅读导航")
	intro._advance()
	check(intro.page_index == 0 and intro.page.revealed_count == 1, "淡入中点击跳过分镜")
	intro._advance()
	check(intro.page_index == 0 and intro.page.revealed_count == 2, "点击没有逐格推进")
	intro._next_page()
	check(intro.page_index == 1 and intro.page.revealed_count == 1, "翻页没有重置分镜")
	while intro.page.revealed_count < 6:
		intro._advance()
	intro._advance()
	check(intro.get_node("IntroUI/NameRow").visible, "没有在询问称呼时显示输入框")
	intro.name_input.text = ""
	intro._confirm_name()
	check(not intro.name_confirmed, "空名字被直接确认")
	intro.name_input.text = "旅人"
	intro._confirm_name()
	check(intro.name_confirmed and not intro.get_node("IntroUI/NameRow").visible, "姓名确认没有完成")
	var reply_node: Panel = intro.page.panels[7].get_child(0)
	check(reply_node.get_child(0).text.contains("旅人") and not reply_node.get_child(0).text.contains("持剑人"), "小墨回应没有使用自定义名字")
	intro._previous_page()
	check(intro.page_index == 0, "上一页边界错误")
	for index in range(intro.PAGES.size()):
		intro.page_index = index
		intro._show_page()
		check(intro.page.texture != null, "漫画页未加载：%d" % index)
	check(intro.name_input.text == "旅人", "称呼丢失")
	intro.free()
	for event_index in range(5):
		for choice_index in range(2):
			state.player_hp = 30
			state.bond_value = 0
			state.bond_stage = 0
			var adventure = load("res://scenes/adventure.tscn").instantiate()
			adventure.adventure_index = event_index
			adventure.force_offline = true
			root.add_child(adventure)
			check(adventure.get_node("AdventureUI/Page").texture != null, "奇遇图片缺失：%d" % event_index)
			check(not adventure.choices.visible, "奇遇提前显示选项")
			adventure._advance()
			check(not adventure.choices.visible, "分镜未读完便显示选项")
			while not adventure.get_node("AdventureUI/Page").is_complete():
				adventure._advance()
			# Finish the last panel fade, then advance into the responses.
			adventure._advance()
			adventure._advance()
			for step in range(20):
				if adventure.choices.visible:
					break
				adventure._advance()
			check(adventure.choices.visible, "奇遇选项未显示")
			var choice: Dictionary = adventure.current_adventure["choices"][choice_index]
			adventure._resolve_choice(choice)
			check(state.player_hp == mini(30 + int(choice["heal"]), state.player_max_hp), "恢复生命结算错误")
			check(state.bond_value == int(choice["bond"]), "羁绊结算错误")
			var hp: int = state.player_hp
			var bond: int = state.bond_value
			adventure._resolve_choice(choice)
			check(state.player_hp == hp and state.bond_value == bond, "重复结算奖励")
			check(adventure.response_ready and not adventure.choices.visible, "结果页没有结束选择")
			check(adventure.story_label.text.contains(str(choice["result"])), "离线叙事结果缺失")
			adventure.free()
	var ending = load("res://scenes/intro.tscn").instantiate()
	root.add_child(ending)
	current_scene = ending
	ending.name_input.text = "旅人"
	ending.page_index = ending.PAGES.size() - 1
	ending._show_page()
	while not ending.page.is_complete():
		ending.page.reveal_next()
	ending.page.reveal_next()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	ending._unhandled_input(click)
	await process_frame
	await process_frame
	check(state.intro_done and state.player_name == "旅人", "初遇完成或称呼未保存")
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/home.tscn", "初遇完成没有回家")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	print("漫画流程检查失败数：", failures)
	quit(1 if failures > 0 else 0)
