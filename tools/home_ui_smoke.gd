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
	state.intro_done = true
	state.homecoming_pending = false
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	await process_frame
	check(home.get_node("Background").size == root.get_visible_rect().size, "背景未铺满视口")
	check(not home.game_screen.visible, "飞花令提前显示")
	check(not home.chat_log.visible, "历史默认展开")
	var message_count: int = home.messages.size()
	home._toggle_history()
	check(home.chat_log.visible, "历史无法展开")
	home._toggle_history()
	check(not home.chat_log.visible and home.messages.size() == message_count, "查看历史修改了对话状态")
	home._show_home_reply("这是一段较长的话。".repeat(40))
	check(home.reply_pages.size() > 1, "长回复未分页")
	var full_text := ""
	for page: String in home.reply_pages:
		full_text += page.replace("\n", "")
	check(full_text == "这是一段较长的话。".repeat(40), "分页丢失了文字")
	home._advance_reply()
	check(home.reply_page_index == 1, "点击无法继续")
	check(not home.get_node("ChatUI/ChatPanel/CurrentReply").scroll_active, "对白仍显示滚动条")
	home._show_home_reply("回来了？茶还温着，坐一会儿吧。")
	home._start_feihualing()
	check(home.game_screen.visible and not home.get_node("ChatUI/ChatPanel").visible, "点击飞花令没有切换界面")
	home._on_game_leave()
	check(not home.game_screen.visible and home.get_node("ChatUI/ChatPanel").visible, "飞花令退出未恢复主界面")
	if "--home-screenshot" in OS.get_cmdline_user_args():
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/concepts/home_ui_implemented.png")
		home.chat_log.text = "玩家：讲讲你的过去。\n\n小墨：一时还不知道从哪说起。先陪我坐一会儿吧。\n\n玩家：就我啊？\n\n小墨：嗯，就你。"
		home._toggle_history()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/concepts/home_history_implemented.png")
	home.free()
	print("HOME UI SMOKE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
