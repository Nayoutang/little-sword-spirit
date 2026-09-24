extends Node

enum EncounterType { NORMAL, ELITE, BOSS }
enum EventType { TREASURE, UNKNOWN }
enum CardType {
	ATTACK, DEFENSE, STATUS, HEAVY_ATTACK, HEAVY_DEFENSE, SWEEP, COMBO_BOOST, CURSE,
	TUNE_BREATH, SHADOW_STEP, BREAK_EDGE, UNLOAD_FORCE, HIDE_EDGE,
}

const LEGACY_SAVE_PATH := "user://relationship_save.cfg"
const SAVE_SLOT_COUNT := 3
const BOND_MIN := BalanceConfig.BOND_MIN
const BOND_MAX := BalanceConfig.BOND_MAX
const BOND_STAGE_THRESHOLDS := BalanceConfig.BOND_STAGE_THRESHOLDS
const BOND_STAGE_NAMES := BalanceConfig.BOND_STAGE_NAMES

var player_max_hp := BalanceConfig.PLAYER_START_MAX_HP
var player_hp := BalanceConfig.PLAYER_START_MAX_HP
var pending_encounter := EncounterType.NORMAL
var pending_event := EventType.TREASURE
var deck: Array[int] = []
var run_id := 0
var bond_value := 0
var bond_stage := 0
var pending_bond_stage := -1
var current_save_slot := 1
var active_promise := ""
var promise_broken := false
var run_won := false
var settlement_applied := false
var post_battle_scene := "res://scenes/map.tscn"
var pending_act_bond_gain := -1
var consecutive_run_failures := 0
var relationship_facts: Dictionary = {
	"battles_won": 0,
	"battles_lost": 0,
	"promise_kept": 0,
	"promise_broken": 0,
	"companion_card_counts": {},
	"minigame_results": [],
}
var current_run_journal: Array[Dictionary] = []
var last_run_journal: Array[Dictionary] = []
var run_journal_finished := false
# 共同经历：每趟远征挑出最有记忆点的几件具体的事，跨远征保存，供小墨引用。
const SHARED_HISTORY_LIMIT := 24
const MOMENTS_PER_RUN := 3
var shared_history: Array[Dictionary] = []
var expedition_count := 0
var run_moments: Array[Dictionary] = []
var run_battle_index := 0
var homecoming_pending := false
# 出门约定：只在上一趟发生了让她在意的事时，由她在出门前提出。
var pending_concern: Dictionary = {}
var promise_sincere := true
var run_min_hp := 0
# 初遇剧情：玩家名字与是否已经播过。
var player_name := ""
var intro_done := false


func _ready() -> void:
	_migrate_legacy_save()
	_load_relationship()
	if deck.is_empty():
		_reset_deck()


func start_new_run() -> void:
	run_id += 1
	player_max_hp = BalanceConfig.PLAYER_START_MAX_HP
	player_hp = player_max_hp
	pending_encounter = EncounterType.NORMAL
	pending_event = EventType.TREASURE
	active_promise = ""
	promise_broken = false
	run_won = false
	settlement_applied = false
	post_battle_scene = "res://scenes/map.tscn"
	pending_act_bond_gain = -1
	current_run_journal.clear()
	run_journal_finished = false
	run_moments.clear()
	run_battle_index = 0
	homecoming_pending = false
	promise_sincere = true
	run_min_hp = player_hp
	record_run_fact("departure", "从家中出发时生命为 %d/%d，羁绊为 %d/100（%s）。" % [
		player_hp,
		player_max_hp,
		bond_value,
		get_bond_stage_name(),
	])
	_reset_deck()


func _reset_deck() -> void:
	deck = [
		CardType.ATTACK, CardType.ATTACK, CardType.ATTACK,
		CardType.ATTACK, CardType.ATTACK,
		CardType.DEFENSE, CardType.DEFENSE, CardType.DEFENSE,
		CardType.DEFENSE, CardType.DEFENSE,
		CardType.STATUS,
		CardType.HEAVY_DEFENSE,
		CardType.HEAVY_ATTACK,
		CardType.SWEEP,
		CardType.COMBO_BOOST,
	]


# 结构化事件统一通过该入口增加羁绊；自由聊天不得调用。
func add_bond(amount: int) -> void:
	if amount <= 0:
		return
	bond_value = clampi(bond_value + amount, BOND_MIN, BOND_MAX)
	_check_bond_milestone()
	_save_relationship()


func get_bond_stage_index() -> int:
	return bond_stage


func get_bond_stage_name() -> String:
	return BOND_STAGE_NAMES[get_bond_stage_index()]


func has_pending_bond_milestone() -> bool:
	return pending_bond_stage > bond_stage


func get_pending_bond_stage_name() -> String:
	if not has_pending_bond_milestone():
		return get_bond_stage_name()
	return BOND_STAGE_NAMES[pending_bond_stage]


func resolve_bond_milestone(success: bool) -> void:
	if not has_pending_bond_milestone():
		return
	if success:
		bond_stage = pending_bond_stage
	pending_bond_stage = -1
	_save_relationship()


func _check_bond_milestone() -> void:
	if has_pending_bond_milestone():
		return
	var next_stage := bond_stage + 1
	if next_stage < BOND_STAGE_THRESHOLDS.size() and bond_value >= BOND_STAGE_THRESHOLDS[next_stage]:
		pending_bond_stage = next_stage


func select_save_slot(slot: int) -> void:
	current_save_slot = clampi(slot, 1, SAVE_SLOT_COUNT)
	bond_value = 0
	bond_stage = 0
	pending_bond_stage = -1
	_reset_relationship_facts()
	_load_relationship()
	if not FileAccess.file_exists(_save_path_for_slot(current_save_slot)):
		_save_relationship()


func get_save_slot_summary(slot: int) -> Dictionary:
	var path := _save_path_for_slot(slot)
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return {"exists": false, "bond": 0, "stage": BOND_STAGE_NAMES[0]}
	var saved_bond := clampi(int(config.get_value("relationship", "bond_value", 0)), BOND_MIN, BOND_MAX)
	var saved_stage := clampi(
		int(config.get_value("relationship", "bond_stage", _stage_index_for_value(saved_bond))),
		0,
		BOND_STAGE_NAMES.size() - 1
	)
	return {
		"exists": true,
		"bond": saved_bond,
		"stage": BOND_STAGE_NAMES[saved_stage],
	}


func delete_save_slot(slot: int) -> void:
	var absolute_path := ProjectSettings.globalize_path(_save_path_for_slot(slot))
	if FileAccess.file_exists(absolute_path):
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			push_warning("删除存档失败，错误码：%s" % error)
	if current_save_slot == slot:
		bond_value = 0
		bond_stage = 0
		pending_bond_stage = -1
		consecutive_run_failures = 0
		_reset_relationship_facts()
		current_run_journal.clear()
		last_run_journal.clear()
		run_journal_finished = false
		AbilityManager.reset()
		SpecialEventManager.reset()


func _stage_name_for_value(value: int) -> String:
	return BOND_STAGE_NAMES[_stage_index_for_value(value)]


func _stage_index_for_value(value: int) -> int:
	var stage_index := 0
	for index in range(BOND_STAGE_THRESHOLDS.size()):
		if value >= BOND_STAGE_THRESHOLDS[index]:
			stage_index = index
	return stage_index


func get_relationship_prompt() -> String:
	var stage_text := _stage_prompt()
	if not player_name.is_empty():
		stage_text += "持剑人的名字：%s。" % player_name
	return stage_text


func needs_intro() -> bool:
	return not intro_done and expedition_count == 0 and bond_value == 0 and shared_history.is_empty()


func complete_intro(name: String, summary: String) -> void:
	player_name = name.strip_edges()
	intro_done = true
	var clean := summary.replace("\n", " ").strip_edges().left(200)
	if not clean.is_empty():
		shared_history.push_front({"expedition": 0, "summary": clean})
	_save_relationship()


func _stage_prompt() -> String:
	match get_bond_stage_index():
		0:
			return "当前关系阶段：初遇。她认生、设防、嘴硬，不轻易承认关心玩家。"
		1:
			return "当前关系阶段：相识。她愿意搭理玩家，仍爱逞强，但偶尔会露出在意。"
		2:
			return "当前关系阶段：交心。她明显信任玩家，嘴硬之后常会很快流露真心。"
		_:
			return "当前关系阶段：生死之交。她非常信任和珍视玩家，仍保留嘴硬习惯，但不会掩饰关键时刻的关心。"


func get_relationship_archive() -> String:
	var promise_text := "本趟没有约定"
	if active_promise == "protect":
		promise_text = "本趟约定：玩家会保护好自己（血不掉到四分之一以下）"
	elif active_promise == "finish":
		promise_text = "本趟约定：玩家会平安完成远征"
	if not active_promise.is_empty() and not promise_sincere:
		promise_text += "（玩家当时是随口应付着答应的）"
	return "%s；羁绊 %d/100；并肩胜利 %d 次、失利 %d 次；兑现约定 %d 次、失约 %d 次；%s；过往出牌记录 %s。" % [
		get_relationship_prompt(),
		bond_value,
		int(relationship_facts.get("battles_won", 0)),
		int(relationship_facts.get("battles_lost", 0)),
		int(relationship_facts.get("promise_kept", 0)),
		int(relationship_facts.get("promise_broken", 0)),
		promise_text,
		str(relationship_facts.get("companion_card_counts", {})),
	]


func get_relationship_facts_snapshot() -> Dictionary:
	return relationship_facts.duplicate(true)


func record_minigame_result(summary: String) -> void:
	var clean_summary := summary.replace("\n", " ").strip_edges().left(320)
	if clean_summary.is_empty():
		return
	var results: Array = relationship_facts.get("minigame_results", [])
	results.append({"category": "minigame_result", "summary": clean_summary})
	if results.size() > 12:
		results.pop_front()
	relationship_facts["minigame_results"] = results
	_save_relationship()


func get_minigame_memory_prompt() -> String:
	var results: Array = relationship_facts.get("minigame_results", [])
	if results.is_empty():
		return "【小游戏关键事实】暂无。"
	var lines: Array[String] = ["【小游戏关键事实】"]
	for fact in results:
		if fact is Dictionary:
			lines.append(str(fact.get("summary", "")))
	return "\n".join(lines)


func has_minigame_history(game_name: String = "") -> bool:
	var results: Array = relationship_facts.get("minigame_results", [])
	for fact in results:
		if fact is Dictionary and (game_name.is_empty() or str(fact.get("summary", "")).begins_with(game_name)):
			return true
	return false


func record_run_fact(category: String, summary: String, details: Dictionary = {}) -> void:
	var clean_summary := summary.replace("\n", " ").strip_edges()
	if clean_summary.is_empty():
		return
	if clean_summary.length() > 320:
		clean_summary = clean_summary.left(320)
	current_run_journal.append({
		"category": category,
		"summary": clean_summary,
		"details": details.duplicate(true),
	})
	if current_run_journal.size() > 48:
		current_run_journal.pop_front()
	if run_journal_finished:
		last_run_journal = current_run_journal.duplicate(true)


func get_run_journal_prompt() -> String:
	var journal: Array[Dictionary] = current_run_journal
	var status := "本趟仍在进行"
	if journal.is_empty():
		journal = last_run_journal
		status = "最近一次已结束的远征"
	elif run_journal_finished:
		status = "本趟已经结束"
	if journal.is_empty():
		return "【整趟远征事实记录】\n暂无可核对的远征记录。不得自行虚构战斗、事件、奖励或玩家行为。"
	var lines: Array[String] = ["【整趟远征事实记录】", "记录状态：%s" % status]
	for index in range(journal.size()):
		lines.append("%d. %s" % [index + 1, str(journal[index].get("summary", ""))])
	lines.append("以上记录是本趟经历的唯一事实来源。可以表达感受，但不得添加记录中没有发生的战斗、受伤、选择、奖励、承诺或台词；记录未说明的细节应明确说不确定。")
	return "\n".join(lines)


func begin_battle() -> int:
	run_battle_index += 1
	return run_battle_index


# 记录本趟一个具体、可被引用的瞬间。weight 越高越可能被挑进共同经历。
func record_moment(summary: String, weight: int) -> void:
	var clean := summary.replace("\n", " ").strip_edges().left(160)
	if clean.is_empty():
		return
	run_moments.append({"summary": clean, "weight": weight, "order": run_moments.size()})
	record_run_fact("moment", "值得记住的瞬间：%s" % clean)


func _commit_run_moments() -> void:
	if run_moments.is_empty():
		return
	var ranked: Array[Dictionary] = run_moments.duplicate(true)
	ranked.sort_custom(func(a, b): return int(a["weight"]) > int(b["weight"]) or (int(a["weight"]) == int(b["weight"]) and int(a["order"]) < int(b["order"])))
	ranked.resize(mini(ranked.size(), MOMENTS_PER_RUN))
	ranked.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
	for moment in ranked:
		shared_history.append({"expedition": expedition_count, "summary": str(moment["summary"])})
	while shared_history.size() > SHARED_HISTORY_LIMIT:
		if int(shared_history[0].get("expedition", -1)) == 0 and shared_history.size() > 1:
			shared_history.remove_at(1)
		else:
			shared_history.pop_front()
	run_moments.clear()


func get_shared_history_prompt(limit: int = 9) -> String:
	if shared_history.is_empty():
		return "【你们的共同经历】\n还没有。你们才刚认识，不要编造任何过去。"
	var lines: Array[String] = ["【你们的共同经历】（跨远征保留的真实往事，越往下越近。可以自然提起，但不得添油加醋，不得编造清单以外的往事）"]
	var indices: Array[int] = []
	for index in range(maxi(shared_history.size() - limit, 0), shared_history.size()):
		indices.append(index)
	if not indices.has(0) and int(shared_history[0].get("expedition", -1)) == 0:
		indices.push_front(0)
	for index in indices:
		var fact: Dictionary = shared_history[index]
		var label := "初遇" if int(fact.get("expedition", 0)) == 0 else "第%d趟" % int(fact.get("expedition", 0))
		lines.append("- %s：%s" % [label, str(fact.get("summary", ""))])
	return "\n".join(lines)


# 回家后小墨是否应当先开口；读取一次即清除。
func consume_homecoming() -> bool:
	var pending := homecoming_pending
	homecoming_pending = false
	return pending


func record_companion_card(card_id: String) -> void:
	var counts: Dictionary = relationship_facts.get("companion_card_counts", {})
	counts[card_id] = int(counts.get(card_id, 0)) + 1
	relationship_facts["companion_card_counts"] = counts


func record_battle_result(player_won: bool) -> void:
	var key := "battles_won" if player_won else "battles_lost"
	relationship_facts[key] = int(relationship_facts.get(key, 0)) + 1


func set_promise(promise_type: String, sincere: bool = true) -> void:
	active_promise = promise_type
	promise_sincere = sincere
	promise_broken = false
	var how := "认真答应了" if sincere else "随口应付着答应了"
	if promise_type == "protect":
		record_run_fact("promise", "出发前小墨要玩家这趟保护好自己（血不掉到四分之一以下），玩家%s。" % how)
	elif promise_type == "finish":
		record_run_fact("promise", "出发前小墨要玩家这趟平安走完远征，玩家%s。" % how)
	else:
		record_run_fact("promise", "出发前没有立下约定。")


func get_pending_concern() -> Dictionary:
	return pending_concern.duplicate(true)


# 出门时玩家对她所提要求的回应：sincere / perfunctory / ignore。
func resolve_departure_concern(response: String) -> void:
	var concern := pending_concern.duplicate(true)
	pending_concern = {}
	if concern.is_empty():
		set_promise("")
		_save_relationship()
		return
	var promise_type := str(concern.get("promise", "protect"))
	if response == "ignore":
		set_promise("")
		record_run_fact("promise", "出发前小墨提起「%s」，想让玩家答应一件事，玩家没接话就出发了。" % str(concern.get("fact", "")))
		record_moment("出门前她提起「%s」，想让你答应她，你没接话就走了。" % str(concern.get("fact", "")), 2)
	else:
		set_promise(promise_type, response == "sincere")
	_save_relationship()


func _promise_prefix() -> String:
	return "出发前你认真答应她" if promise_sincere else "出发前你随口应付着答应她"


# 结算时决定下一趟出门前她要不要提要求；没有值得在意的事就什么都不提。
func _evaluate_next_concern() -> void:
	var low_line := int(player_max_hp * 0.25)
	if active_promise == "protect" and run_min_hp <= low_line:
		pending_concern = {"kind": "broken", "promise": "protect",
			"fact": "上一趟你答应她会照顾好自己，血却还是掉到了 %d/%d" % [run_min_hp, player_max_hp]}
	elif active_promise == "finish" and not run_won:
		pending_concern = {"kind": "broken", "promise": "finish",
			"fact": "上一趟你答应她会平安走完，却在第 %d 场倒下了" % run_battle_index}
	elif not run_won:
		pending_concern = {"kind": "fell", "promise": "finish",
			"fact": "上一趟你在第 %d 场倒下了" % run_battle_index}
	elif run_min_hp <= low_line:
		pending_concern = {"kind": "reckless", "promise": "protect",
			"fact": "上一趟你的血最低掉到了 %d/%d" % [run_min_hp, player_max_hp]}
	else:
		pending_concern = {}


func record_player_hp() -> void:
	run_min_hp = mini(run_min_hp, player_hp)
	if active_promise == "protect" and player_hp <= int(player_max_hp * 0.25):
		promise_broken = true


func finish_run(won: bool) -> void:
	run_won = won
	expedition_count += 1
	if won:
		consecutive_run_failures = 0
	else:
		consecutive_run_failures += 1
	if active_promise == "finish" and not won:
		promise_broken = true
	record_run_fact(
		"run_result",
		"本趟远征最终%s，结束时生命为 %d/%d。" % ["通关" if won else "失败", player_hp, player_max_hp]
	)
	run_journal_finished = true
	last_run_journal = current_run_journal.duplicate(true)
	_save_relationship()


func settle_act_promise() -> int:
	pending_act_bond_gain = -1
	if active_promise != "protect":
		return pending_act_bond_gain
	if promise_broken:
		pending_act_bond_gain = 0
		relationship_facts["promise_broken"] = int(relationship_facts.get("promise_broken", 0)) + 1
		record_moment(_promise_prefix() + "会保护好自己，这一趟还是让自己掉进了危险的血线。", 3)
		record_run_fact("promise_result", "保护约定未兑现，本趟没有获得约定羁绊奖励。")
	else:
		pending_act_bond_gain = 6
		relationship_facts["promise_kept"] = int(relationship_facts.get("promise_kept", 0)) + 1
		record_moment(_promise_prefix() + "会保护好自己，这一趟你真的一次都没让自己陷进濒危。", 2)
		record_run_fact("promise_result", "保护约定已经兑现，获得 6 点羁绊。")
		add_bond(pending_act_bond_gain)
	promise_broken = false
	return pending_act_bond_gain


func apply_settlement() -> Dictionary:
	if settlement_applied:
		return {"result": "already_applied", "bond_gain": 0}
	settlement_applied = true

	var gain := 0
	var result := "none"
	if active_promise == "finish":
		if promise_broken or not run_won:
			result = "broken"
			relationship_facts["promise_broken"] = int(relationship_facts.get("promise_broken", 0)) + 1
			record_run_fact("promise_result", "完成远征的约定未兑现，没有获得约定羁绊奖励。")
			record_moment(_promise_prefix() + "会平安走完这趟远征，结果没能走完。", 3)
		else:
			result = "kept"
			gain = 10
			relationship_facts["promise_kept"] = int(relationship_facts.get("promise_kept", 0)) + 1
			record_moment(_promise_prefix() + "会平安走完这趟远征，你做到了。", 2)
			record_run_fact("promise_result", "完成远征的约定已经兑现，获得 10 点羁绊。")
	elif active_promise == "protect":
		if promise_broken:
			result = "broken"
			relationship_facts["promise_broken"] = int(relationship_facts.get("promise_broken", 0)) + 1
			record_run_fact("promise_result", "保护约定未兑现，本趟没有获得约定羁绊奖励。")
			record_moment(_promise_prefix() + "会保护好自己，这一趟还是让自己掉进了危险的血线。", 3)
		else:
			result = "act_based"
	_evaluate_next_concern()
	_commit_run_moments()
	homecoming_pending = true
	if gain > 0:
		add_bond(gain)
	else:
		_save_relationship()
	if run_journal_finished:
		last_run_journal = current_run_journal.duplicate(true)
		_save_relationship()
	return {"result": result, "bond_gain": gain}


func _save_relationship() -> void:
	var config := ConfigFile.new()
	config.set_value("relationship", "bond_value", bond_value)
	config.set_value("relationship", "bond_stage", bond_stage)
	config.set_value("relationship", "pending_bond_stage", pending_bond_stage)
	config.set_value("progress", "consecutive_run_failures", consecutive_run_failures)
	config.set_value("progress", "expedition_count", expedition_count)
	config.set_value("progress", "pending_concern", pending_concern)
	config.set_value("progress", "intro_done", intro_done)
	config.set_value("profile", "player_name", player_name)
	config.set_value("memory", "shared_history", shared_history)
	config.set_value("memory", "battles_won", int(relationship_facts.get("battles_won", 0)))
	config.set_value("memory", "battles_lost", int(relationship_facts.get("battles_lost", 0)))
	config.set_value("memory", "promise_kept", int(relationship_facts.get("promise_kept", 0)))
	config.set_value("memory", "promise_broken", int(relationship_facts.get("promise_broken", 0)))
	config.set_value("memory", "companion_card_counts", relationship_facts.get("companion_card_counts", {}))
	config.set_value("memory", "minigame_results", relationship_facts.get("minigame_results", []))
	config.set_value("run_journal", "last_completed", last_run_journal)
	AbilityManager.save_to_config(config)
	SpecialEventManager.save_to_config(config)
	var error := config.save(_save_path_for_slot(current_save_slot))
	if error != OK:
		push_warning("羁绊存档保存失败，错误码：%s" % error)


func _load_relationship() -> void:
	bond_value = 0
	bond_stage = 0
	pending_bond_stage = -1
	consecutive_run_failures = 0
	_reset_relationship_facts()
	current_run_journal.clear()
	last_run_journal.clear()
	run_journal_finished = false
	AbilityManager.reset()
	SpecialEventManager.reset()
	var config := ConfigFile.new()
	var error := config.load(_save_path_for_slot(current_save_slot))
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("羁绊存档读取失败，错误码：%s" % error)
		return
	bond_value = clampi(
		int(config.get_value("relationship", "bond_value", BOND_MIN)),
		BOND_MIN,
		BOND_MAX
	)
	# 旧存档没有独立阶段字段时，按旧规则推算，避免玩家关系阶段倒退。
	bond_stage = clampi(
		int(config.get_value("relationship", "bond_stage", _stage_index_for_value(bond_value))),
		0,
		BOND_STAGE_NAMES.size() - 1
	)
	pending_bond_stage = clampi(
		int(config.get_value("relationship", "pending_bond_stage", -1)),
		-1,
		BOND_STAGE_NAMES.size() - 1
	)
	consecutive_run_failures = maxi(int(config.get_value("progress", "consecutive_run_failures", 0)), 0)
	expedition_count = maxi(int(config.get_value("progress", "expedition_count", 0)), 0)
	intro_done = bool(config.get_value("progress", "intro_done", false))
	player_name = str(config.get_value("profile", "player_name", ""))
	var saved_concern: Variant = config.get_value("progress", "pending_concern", {})
	if saved_concern is Dictionary:
		pending_concern = saved_concern.duplicate(true)
	var saved_history: Variant = config.get_value("memory", "shared_history", [])
	if saved_history is Array:
		for fact in saved_history:
			if fact is Dictionary and not str(fact.get("summary", "")).is_empty():
				shared_history.append(fact.duplicate(true))
	relationship_facts["battles_won"] = maxi(int(config.get_value("memory", "battles_won", 0)), 0)
	relationship_facts["battles_lost"] = maxi(int(config.get_value("memory", "battles_lost", 0)), 0)
	relationship_facts["promise_kept"] = maxi(int(config.get_value("memory", "promise_kept", 0)), 0)
	relationship_facts["promise_broken"] = maxi(int(config.get_value("memory", "promise_broken", 0)), 0)
	var saved_card_counts = config.get_value("memory", "companion_card_counts", {})
	if saved_card_counts is Dictionary:
		relationship_facts["companion_card_counts"] = saved_card_counts.duplicate(true)
	var saved_minigame_results: Variant = config.get_value("memory", "minigame_results", [])
	if saved_minigame_results is Array:
		var clean_results: Array = []
		for fact in saved_minigame_results:
			if fact is Dictionary and fact.get("category", "") == "minigame_result" and not str(fact.get("summary", "")).is_empty():
				clean_results.append(fact.duplicate(true))
				if clean_results.size() > 12:
					clean_results.pop_front()
		relationship_facts["minigame_results"] = clean_results
	var saved_run_journal: Variant = config.get_value("run_journal", "last_completed", [])
	if saved_run_journal is Array:
		for fact in saved_run_journal:
			if fact is Dictionary and not str(fact.get("summary", "")).is_empty():
				last_run_journal.append(fact.duplicate(true))
	AbilityManager.load_from_config(config)
	SpecialEventManager.load_from_config(config)


func save_persistent_state() -> void:
	_save_relationship()


func _reset_relationship_facts() -> void:
	shared_history.clear()
	expedition_count = 0
	pending_concern = {}
	player_name = ""
	intro_done = false
	run_moments.clear()
	relationship_facts = {
		"battles_won": 0,
		"battles_lost": 0,
		"promise_kept": 0,
		"promise_broken": 0,
		"companion_card_counts": {},
		"minigame_results": [],
	}


func _save_path_for_slot(slot: int) -> String:
	return "user://save_slot_%d.cfg" % clampi(slot, 1, SAVE_SLOT_COUNT)


func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(_save_path_for_slot(1)) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var legacy := ConfigFile.new()
	if legacy.load(LEGACY_SAVE_PATH) != OK:
		return
	var migrated_bond := clampi(int(legacy.get_value("relationship", "bond_value", 0)), BOND_MIN, BOND_MAX)
	var slot_one := ConfigFile.new()
	slot_one.set_value("relationship", "bond_value", migrated_bond)
	slot_one.set_value("relationship", "bond_stage", _stage_index_for_value(migrated_bond))
	slot_one.set_value("relationship", "pending_bond_stage", -1)
	slot_one.set_value("progress", "consecutive_run_failures", 0)
	var error := slot_one.save(_save_path_for_slot(1))
	if error != OK:
		push_warning("旧羁绊存档迁移失败，错误码：%s" % error)
