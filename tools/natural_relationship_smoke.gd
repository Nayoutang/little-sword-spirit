extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func run() -> void:
	check(OS.get_environment("APPDATA").contains("natural-relationship-user"), "测试必须隔离存档目录")
	if failures > 0:
		quit(1)
		return
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.bond_value = 0
	state.bond_stage = 0
	state.pending_bond_stage = -1
	state.add_bond(24)
	check(state.bond_stage == 0, "未达到阈值时保持初遇")
	state.add_bond(1)
	check(state.bond_stage == 1 and state.pending_bond_stage == -1, "达到阈值后直接进入相识")
	state.add_bond(50)
	check(state.bond_stage == 3 and state.pending_bond_stage == -1, "跨多个阈值无需逐阶段答题")
	state.add_bond(-20)
	check(state.bond_value == 75 and state.bond_stage == 3, "无效增长不会降低关系")
	state.add_bond(100)
	check(state.bond_value == 100, "关系进度有上限")
	# 在隔离用户目录生成旧版 fixture，验证被选择门槛卡住的存档。
	var config := ConfigFile.new()
	config.set_value("relationship", "bond_value", 55)
	config.set_value("relationship", "bond_stage", 0)
	config.set_value("relationship", "pending_bond_stage", 1)
	config.set_value("progress", "intro_done", true)
	config.set_value("profile", "player_name", "测试持剑人")
	var slot_path: String = state._save_path_for_slot(3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	check(config.save(slot_path) == OK, "旧版存档 fixture 写入成功")
	state.select_save_slot(3)
	check(state.bond_stage == 2 and state.pending_bond_stage == -1, "旧存档自动衔接并清除待突破状态")
	check(state.player_name == "测试持剑人", "旧存档保留玩家名字")
	check(state.get_save_slot_summary(3)["stage"] == state.get_bond_stage_name(), "存档摘要与实际关系一致")
	state.homecoming_pending = false
	var home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	check(not home.bond_label.visible, "家园不显示亲密度分数")
	check(not home.messages.is_empty(), "旧存档可直接进入日常对话")
	var before: int = state.bond_value
	home._chat_payload()
	check(state.bond_value == before, "生成自由聊天请求不增加关系进度")
	home.free()
	state.suppress_persistence = false
	state.save_persistent_state()
	var saved := ConfigFile.new()
	check(saved.load(slot_path) == OK, "新版存档可读取")
	check(saved.get_value("relationship", "version", 0) == 2, "新版存档记录关系版本")
	check(saved.get_value("relationship", "pending_bond_stage", 0) == -1, "新版存档没有答题门槛")
	state.suppress_persistence = true
	state.select_save_slot(3)
	check(state.bond_stage == 2, "重新加载保持自然关系进度")
	print("Natural relationship smoke failures: ", failures)
	quit(1 if failures > 0 else 0)
