extends SceneTree

var failures := 0
const Art = preload("res://scripts/ui/card_art_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.homecoming_pending = false
	state.bond_value = 85
	state.bond_stage = 3
	var deck_before: Array = state.deck.duplicate()
	var library = load("res://scripts/ui/card_library.gd").new()
	root.add_child(library)
	library.open()
	await process_frame
	check(library.entries.size() == 38 and library.shown_entries.size() == 38, "all 20 player and 18 companion definitions included")
	check(library.grid.get_child_count() == 38, "catalog card faces created")
	check(library.detail_text.text.contains("连击层数与连续攻击计数不同"), "keyword glossary distinguishes the counters")
	library.collection_filter.select(1)
	library._refresh()
	check(library.shown_entries.size() == 20, "player filter")
	check(library.collection_filter.item_count == 4, "catalog has no trial-only category")
	var database = root.get_node("CardDatabase")
	for card_id in [17, 18, 19]:
		check(card_id in database.get_reward_card_ids(), "shield/parry card is obtainable from normal rewards")
		library.search.text = database.get_card_name(card_id)
		library._refresh()
		check(library.shown_entries.size() == 1 and library.detail_text.text.contains("可从战斗奖励获得") and not library.detail_text.text.contains("试验"), "catalog explains real acquisition")
	var owned_abilities: Array[int] = [18]
	check(18 not in database.get_reward_card_ids(owned_abilities), "owned retain-shield ability is not offered again")
	library.search.clear()
	library.collection_filter.select(3)
	library._refresh()
	check(library.shown_entries.size() == 2 and library.detail_text.text.contains("按钮技能"), "bond skills explain button rule")
	library.collection_filter.select(0)
	library.search.text = "十年磨一剑"
	library.search.text_changed.emit(library.search.text)
	check(library.shown_entries.size() == 1 and library.selected_key == "c_grind_sword", "search also finds poem")
	check(library.detail_text.text.contains("不造成伤害") and library.detail_text.text.contains("贾岛"), "actual grind effect and source")
	library.search.text = "没有这个招式"
	library.search.text_changed.emit(library.search.text)
	check(library.shown_entries.is_empty() and library.empty_label.visible and not library.detail_face.visible, "empty result")
	library.search.clear()
	library._refresh()
	library.type_filter.select(2)
	library._refresh()
	check(library.shown_entries.size() == 4, "defense filter including parry")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	library._input(escape)
	check(not library.overlay.visible and state.deck == deck_before, "Esc closes without changing deck")
	library.free()
	var home = load("res://scenes/home.tscn").instantiate()
	home.preview_offline = true
	root.add_child(home)
	check(home.get_node("ChatUI/ChatPanel/CardLibraryButton").is_visible_in_tree(), "home entry visible before finale invitation")
	home.get_node("ChatUI/ChatPanel/CardLibraryButton").pressed.emit()
	check(home.get_node("CardLibrary").overlay.visible, "home menu entry")
	home.free()
	var saves = load("res://scenes/save_select.tscn").instantiate()
	root.add_child(saves)
	saves.get_node("SaveUI/CardLibraryButton").pressed.emit()
	check(saves.get_node("CardLibrary").overlay.visible, "main menu entry")
	saves.free()
	var battle = load("res://scenes/battle.tscn").instantiate()
	battle.fixed_cooperation_test = true
	battle.force_offline_companion = true
	root.add_child(battle)
	battle.get_node("BattleUI/CardLibraryButton").pressed.emit()
	check(battle.get_node("CardLibrary").overlay.visible, "battle entry")
	battle.get_node("CardLibrary").close()
	battle.enemy_hps.assign([1000, 1000])
	battle.enemy_guards.assign([0, 0])
	battle.enemy_vulnerabilities.assign([0, 0])
	battle.combo = 3
	battle.energy = 3
	battle.consecutive_attacks = 2
	battle.pending_skill_target = 2
	battle._resolve_targeted_skill(0)
	check(battle.enemy_hps[0] == 959 and battle.combo == 0 and battle.energy == 3 and battle.consecutive_attacks == 2, "Huacai damage/resources unaffected")
	check(battle.ink_event.visible and not (battle.ink_event is TextureRect), "finisher uses layered animation rather than poster")
	await create_timer(0.6).timeout
	check(battle.ink_event.progress > 0.25 and battle.ink_event.portrait.modulate.a > 0.9, "animation layers advance")
	await create_timer(1.2).timeout
	check(not battle.ink_event.visible, "animation exits")
	battle.free()
	if "--check-all-art" in OS.get_cmdline_user_args():
		var paths: Array = Art.PLAYER_FILES.values() + Art.COMPANION_FILES.values()
		var seen: Dictionary = {}
		for path: String in paths:
			check(not seen.has(path) and ResourceLoader.exists(path), "independent existing cover: " + path)
			seen[path] = true
		check(seen.size() == 38, "38 independent covers")
	print("CARD_LIBRARY_SMOKE failures=", failures)
	quit(0 if failures == 0 else 1)
