extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func run() -> void:
	root.get_node("RunState").suppress_persistence = true
	var node_path_pattern := RegEx.new()
	node_path_pattern.compile('@onready[^\\n]*\\$([A-Za-z0-9_/]+)')
	for file in DirAccess.get_files_at("res://scenes"):
		if not file.ends_with(".tscn"):
			continue
		var packed := load("res://scenes/" + file) as PackedScene
		check(packed != null, "场景加载失败：" + file)
		if packed == null:
			continue
		var scene := packed.instantiate()
		var script := scene.get_script() as GDScript
		if script != null:
			for match_result in node_path_pattern.search_all(script.source_code):
				var path := match_result.get_string(1)
				check(scene.has_node(path), file + " 缺少节点：" + path)
		scene.free()
	var intro = load("res://scenes/intro.tscn").instantiate()
	intro.get_node("IntroUI/Caption").position += Vector2(17, 11)
	var story_position: Vector2 = intro.get_node("IntroUI/Caption").position
	root.add_child(intro)
	check(intro.caption.position == story_position, "初遇脚本覆盖了编辑器布局")
	intro.free()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	var hand: Control = battle.get_node("BattleUI/HandViewport")
	hand.position += Vector2(17, 11)
	var hand_position := hand.position
	var portrait: Control = battle.get_node("BattleUI/CompanionPanel/Portrait")
	portrait.position += Vector2(19, 13)
	var portrait_position := portrait.position
	root.add_child(battle)
	check(hand.position == hand_position, "战斗脚本覆盖了手牌布局")
	check(battle.enemy_hp_bars.size() == battle.enemy_count, "敌人 UI 数量不匹配")
	check(battle.pile_popup != null, "牌堆弹窗绑定失败")
	var end_turn: Button = battle.get_node("BattleUI/ActionArea/EndTurn")
	check(end_turn.get_theme_stylebox("normal") is StyleBoxTexture, "场景纹理皮肤被覆盖")
	var dialogue: Panel = battle.get_node("BattleUI/CompanionPanel/DialogueBackdrop")
	var bubble_style := dialogue.get_theme_stylebox("panel") as StyleBoxTexture
	check(bubble_style != null, "对话气泡被运行时底板覆盖")
	if bubble_style != null:
		check(bubble_style.texture.resource_path == "res://art/ui/battle/speech.png", "对话气泡纹理不匹配")
	var sprite: TextureRect = battle.enemy_sprites[0]
	var enemy_position := sprite.position + Vector2(9, 7)
	sprite.set_meta("rest_position", enemy_position)
	battle._animate_enemy_hit(0)
	battle._show_companion_flash("quick_slash")
	await create_timer(0.8).timeout
	check(sprite.position.is_equal_approx(enemy_position), "敌人受击动画没有返回设定位置")
	check(portrait.position.is_equal_approx(portrait_position), "角色动画没有返回编辑器布局位置")
	var reason: Label = battle.get_node("BattleUI/CompanionPanel/Reason")
	var effect: Label = battle.get_node("BattleUI/CompanionPanel/Effect")
	reason.text = "这一手，我来。"
	effect.text = "下次攻击伤害翻倍。"
	await process_frame
	await process_frame
	var short_height := dialogue.size.y
	check(is_equal_approx(effect.position.y - reason.position.y - reason.size.y, battle.companion_dialogue_gap), "短台词段间距不匹配")
	reason.text = "你这一串别急着收，我接得住，下一回合我替你翻倍。"
	effect.text = "不造成伤害；令玩家下回合第一张攻击牌的伤害翻倍。配合条件：保留连击，我替你留到下一轮。"
	await process_frame
	await process_frame
	check(dialogue.size.y > short_height, "气泡没有随长文本增高")
	check(effect.position.y + effect.size.y < dialogue.position.y + dialogue.size.y, "效果文本超出气泡底部")
	battle.free()
	print("UI 结构与布局检查失败数：", failures)
	quit(1 if failures > 0 else 0)
