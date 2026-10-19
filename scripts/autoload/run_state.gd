extends Node

enum EncounterType { NORMAL, ELITE, BOSS }
enum EventType { TREASURE, UNKNOWN }
const CombatTypes = preload("res://scripts/data/combat_types.gd")
const CardType = CombatTypes.CardType

const SaveStorage = preload("res://scripts/data/save_slot_storage.gd")
const Narrative = preload("res://scripts/narrative/relationship_context.gd")
const ProfileCodec = preload("res://scripts/data/relationship_profile.gd")
const Routes = preload("res://scripts/data/scene_routes.gd")
const Navigator = preload("res://scripts/flow/scene_navigator.gd")
const Checkpoint = preload("res://scripts/data/expedition_checkpoint.gd")
const LEGACY_SAVE_PATH := "user://relationship_save.cfg"
const SAVE_SLOT_COUNT := 12
const BOND_MIN := BalanceConfig.BOND_MIN
const BOND_MAX := BalanceConfig.BOND_MAX
const BOND_STAGE_THRESHOLDS := BalanceConfig.BOND_STAGE_THRESHOLDS
const BOND_STAGE_NAMES := BalanceConfig.BOND_STAGE_NAMES

var player_max_hp := BalanceConfig.PLAYER_START_MAX_HP
var _navigator := Navigator.new()
var player_hp := BalanceConfig.PLAYER_START_MAX_HP
var pending_encounter := EncounterType.NORMAL
var route_layer := 1
var pending_event := EventType.TREASURE
var deck: Array[int] = []
var run_id := 0
# 漫画每趟只安排一个；记录近期内容，跨趟、跨启动轮换。
var run_adventures: Array[int] = []
var recent_adventures: Array[int] = []
var bond_value := 0
var bond_stage := 0
var pending_bond_stage := -1
# 暗线：信 / 执（见 BalanceConfig.HIDDEN_*）。跨趟保留，玩家看不到。
var hidden_trust := 0
var hidden_attachment := 0
var current_save_slot := 1
var save_selection_mode := "all"
var active_promise := ""
var promise_broken := false
var run_won := false
var settlement_applied := false
var post_battle_scene := Routes.PATHS.map
var pending_act_bond_gain := -1
var consecutive_run_failures := 0
var relationship_facts: Dictionary = ProfileCodec.empty_facts()
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
var finale_state := "locked"
var finale_mode := "arrival"
var player_name := ""
var intro_done := false
# 飞花令开放进度，见 relationship_profile.gd。
var feihualing_state := "locked"
# 防止台词重复：跨场景记住她最近说过的话；每次说话随机给一点此刻的心情。
const RECENT_LINES_LIMIT := 12
const MOODS := [
	"有点困，懒得跟他斗嘴",
	"刚发现剑鞘上多了一道划痕，心里不痛快",
	"想起一句诗，憋着想考考他",
	"心情不错，但不想让他看出来",
	"在琢磨一个出剑的架势，有点走神",
	"嫌屋里太闷，想出去走走",
	"闲得发慌，想找点事做",
	"对他之前的某个举动还有点在意",
	"想逞强，显得自己很可靠",
	"刚才在发呆，被他打断了",
	"肚子里憋着一句损人的话",
	"有点想听他多说几句，又不肯开口要",
]
var recent_lines: Array[String] = []
# 剑意：飞花令里对出特定诗句时，她领悟的剑招（进入她的战斗牌池）。
var learned_sword_intents: Array[String] = []
# 本趟拿到的信物（RelicDatabase 的 id），开新的一趟清空。
var run_relics: Array[String] = []
# 默契倾向（单趟）：你接住她哪种意向越多，她在两可的回合越常这样配合你。
const LEAN_KINDS := ["guard", "invest", "finisher"]
const LEAN_SPEAK_AT := 6
var run_lean: Dictionary = {}
# 剑境（第三章之后的自由历练）。realm_unlocked / realm_cleared 跨趟保存；sword_realm 是这一趟选的剑境（非自由历练为 0）。
const REALM_MAX := 5
const FREE_BOSSES := ["curse_guardian", "thread_blade_boss", "troupe_watcher", "bound_spirit", "puppeteer"]
var realm_unlocked := 1
var realm_cleared := 0
var last_free_boss := ""
var sword_realm := 0
var free_boss := ""
var run_lean_spoken: Array[String] = []
# 第二、三章进度。chapter_trip：本章第几趟（3 = 本章剧情已走完）。
const CHAPTER_TWO_TRIPS := 2
const CHAPTER_THREE_TRIPS := 2
var chapter := 1
var chapter_trip := 1
# 你替她斩断过的紫线（跨趟累计，倒下不清零），决定她挣线的本事。
var threads_cut := 0
var scroll_pages: Array[String] = []
var story_seen: Array[String] = []
# 回到家时要先播的章节剧情 id；播完清空。
var pending_story := ""
# 当前节点是否在紫线上（仅运行时；战斗检查点里另存一份）。
var node_on_thread := false
var run_active := false
var map_seed := 0
var map_layer := 0
var map_node := 0
var map_path: Array = []
var battle_seed := 0
var expedition_checkpoint: Dictionary = {}
var last_save_error: Error = OK
var suppress_persistence := false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	if "--cooperation-sim" in OS.get_cmdline_user_args():
		suppress_persistence = true
		_reset_deck()
		return
	_migrate_legacy_save()
	_load_relationship()
	if deck.is_empty():
		_reset_deck()


# Map scenes request mutations; RunState owns the state across scene replacement.
func ensure_map_seed() -> int:
	if map_seed == 0:
		map_seed = maxi(randi(), 1)
	return map_seed


func visit_map_node(layer: int, node_index: int) -> void:
	assert(layer > 0 and layer < BalanceConfig.ROUTE_TOTAL_LAYERS)
	assert(node_index >= 0 and node_index < 5)
	route_layer = layer
	map_layer = layer
	map_node = node_index
	map_path.append([layer, node_index])


func prepare_encounter(encounter_type: EncounterType) -> void:
	pending_encounter = encounter_type
	battle_seed = maxi(randi(), 1)


func prepare_event(event_type: EventType) -> void:
	pending_event = event_type


func add_run_card(card_id: int) -> bool:
	if not CardDatabase.DEFINITIONS.has(card_id):
		return false
	deck.append(card_id)
	return true


func remove_run_card(index: int) -> int:
	if index < 0 or index >= deck.size():
		return -1
	var card_id := deck[index]
	deck.remove_at(index)
	return card_id


func gain_relic(id: String) -> bool:
	if id.is_empty() or RelicDatabase.get_definition(id).is_empty() or run_relics.has(id):
		return false
	run_relics.append(id)
	record_run_fact("relic", "获得信物%s" % RelicDatabase.describe(id), {"relic": id})
	return true


func has_relic(id: String) -> bool:
	return run_relics.has(id)


# 记一次倾向。第一次越过阈值时返回 true，战斗里让她说一句。
func add_run_lean(kind: String, amount: int = 1) -> bool:
	if kind not in LEAN_KINDS or amount <= 0:
		return false
	run_lean[kind] = int(run_lean.get(kind, 0)) + amount
	if int(run_lean[kind]) >= LEAN_SPEAK_AT and not run_lean_spoken.has(kind):
		run_lean_spoken.append(kind)
		return true
	return false


func run_lean_value(kind: String) -> int:
	return int(run_lean.get(kind, 0))


func set_player_hp(value: int) -> void:
	player_hp = clampi(value, 0, player_max_hp)


func adjust_player_hp(amount: int, minimum: int = 0) -> int:
	var previous := player_hp
	player_hp = clampi(player_hp + amount, minimum, player_max_hp)
	return player_hp - previous


func increase_max_hp(amount: int) -> void:
	var gain := maxi(amount, 0)
	player_max_hp += gain
	player_hp += gain


func set_post_battle_route(route: String) -> void:
	assert(route in ["map", "settlement"])
	post_battle_scene = scene_path(route)
	if route == "map":
		pending_act_bond_gain = -1


func start_new_run(realm: int = 1) -> void:
	var next_run_id := run_id + 1
	_reset_expedition_runtime()
	run_active = true
	run_id = next_run_id
	if is_free_play():
		sword_realm = clampi(realm, 1, realm_unlocked)
		free_boss = _roll_free_boss()
		last_free_boss = free_boss
		# 剑境四：出发就带一件信物；剑境五：起始牌组多一张心魔。
		if sword_realm >= 4:
			gain_relic(RelicDatabase.roll(run_relics))
		if sword_realm >= 5:
			deck.append(CardType.CURSE)
	record_run_fact("departure", "从家中出发时生命为 %d/%d，羁绊为 %d/100（%s）。" % [
		player_hp,
		player_max_hp,
		bond_value,
		get_bond_stage_name(),
	], {"opportunities_used": _cooperation_count("opportunities_used"), "sword_intents": learned_sword_intents.size()})
	checkpoint("promise")


func draw_comic_adventure(comic_count: int) -> int:
	var candidates: Array[int] = []
	var fresh: Array[int] = []
	for index in range(comic_count):
		if not run_adventures.has(index):
			candidates.append(index)
			if not recent_adventures.has(index):
				fresh.append(index)
	# 优先跨趟没见过的；都见过时排除最近一个，仍保持单趟不重复。
	if not fresh.is_empty():
		candidates = fresh
	elif candidates.size() > 1 and not recent_adventures.is_empty():
		candidates.erase(recent_adventures.back())
	if candidates.is_empty():
		return -1
	var selected := candidates[randi_range(0, candidates.size() - 1)]
	if selected >= 0:
		run_adventures.append(selected)
		recent_adventures.erase(selected)
		recent_adventures.append(selected)
		while recent_adventures.size() > 5:
			recent_adventures.pop_front()
		save_persistent_state()
	return selected


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
	_advance_bond_stage()
	_save_relationship()


func get_bond_stage_index() -> int:
	return bond_stage


func get_bond_stage_name() -> String:
	return BOND_STAGE_NAMES[get_bond_stage_index()]


func _advance_bond_stage() -> void:
	# 经历积累后自然推进；阶段用于语气与配合，不再等待答题确认。
	bond_stage = maxi(bond_stage, _stage_index_for_value(bond_value))
	pending_bond_stage = -1


func select_save_slot(slot: int) -> void:
	current_save_slot = clampi(slot, 1, SAVE_SLOT_COUNT)
	_load_relationship()
	if not FileAccess.file_exists(_save_path_for_slot(current_save_slot)):
		_save_relationship()


func get_save_slot_summary(slot: int) -> Dictionary:
	var path := _save_path_for_slot(slot)
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		error = config.load(path + ".bak")
	if error != OK:
		return {"exists": false, "bond": 0, "stage": BOND_STAGE_NAMES[0]}
	var profile := ProfileCodec.decode(config)
	var saved_checkpoint: Variant = config.get_value("expedition", "checkpoint", {})
	var valid_checkpoint := Checkpoint.valid(saved_checkpoint)
	return {
		"exists": true,
		"bond": profile.bond_value,
		"stage": BOND_STAGE_NAMES[profile.bond_stage],
		"expedition": valid_checkpoint,
		"layer": int(saved_checkpoint.state.map_layer) if valid_checkpoint else 0,
		"finale_state": profile.finale_state,
		"chapter": profile.chapter,
	}


func delete_save_slot(slot: int) -> void:
	var absolute_path := ProjectSettings.globalize_path(_save_path_for_slot(slot))
	if FileAccess.file_exists(absolute_path):
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			push_warning("删除存档失败，错误码：%s" % error)
			return
	for suffix in [".bak", ".tmp"]:
		if FileAccess.file_exists(_save_path_for_slot(slot) + suffix):
			DirAccess.remove_absolute(absolute_path + suffix)
	if current_save_slot == slot:
		_reset_slot_state()


func _stage_name_for_value(value: int) -> String:
	return BOND_STAGE_NAMES[_stage_index_for_value(value)]


func _stage_index_for_value(value: int) -> int:
	return ProfileCodec.stage_index(value)


func get_relationship_prompt() -> String:
	return Narrative.relationship(bond_stage, player_name) + "\n" + Narrative.hidden_lean(hidden_trust, hidden_attachment)


# ---- 暗线 · 信 / 执 ----

func adjust_hidden(trust_delta: int, attachment_delta: int) -> void:
	if trust_delta == 0 and attachment_delta == 0:
		return
	hidden_trust = clampi(hidden_trust + trust_delta, BalanceConfig.HIDDEN_MIN, BalanceConfig.HIDDEN_MAX)
	hidden_attachment = clampi(hidden_attachment + attachment_delta, BalanceConfig.HIDDEN_MIN, BalanceConfig.HIDDEN_MAX)
	_save_relationship()


func _cooperation_count(kind: String) -> int:
	var stats: Dictionary = relationship_facts.get("cooperation", {})
	return int(stats.get(kind, 0))


# 本趟接住她留的机会的次数：用出发时记下的累计值做差，断点续玩也不丢。
func _run_has_mark(mark: String) -> bool:
	for moment: Dictionary in run_moments:
		if str(moment.get("mark", "")) == mark:
			return true
	return false


func _departure_detail(key: String, fallback: int) -> int:
	for fact: Dictionary in current_run_journal:
		if str(fact.get("category", "")) == "departure":
			var details: Dictionary = fact.get("details", {})
			return int(details.get(key, fallback))
	return fallback


func run_opportunities_used() -> int:
	for fact: Dictionary in current_run_journal:
		if str(fact.get("category", "")) == "departure":
			var details: Dictionary = fact.get("details", {})
			if details.has("opportunities_used"):
				return maxi(_cooperation_count("opportunities_used") - int(details.opportunities_used), 0)
	return 0


# 每趟结算一次（apply_settlement 已防重复）。只读本趟真实发生的事。
func _settle_hidden(promise_result: String) -> void:
	var kept := promise_result == "kept" or (promise_result == "act_based" and pending_act_bond_gain > 0)
	var broken := promise_result == "broken" or (promise_result == "act_based" and pending_act_bond_gain == 0)
	var trust := 0
	var attachment := 0
	if kept:
		trust += BalanceConfig.HIDDEN_PROMISE_KEPT_TRUST
	elif broken:
		trust += BalanceConfig.HIDDEN_PROMISE_BROKEN_TRUST
	var used := run_opportunities_used()
	trust += mini(used, BalanceConfig.HIDDEN_OPPORTUNITY_TRUST_CAP)
	if not run_won:
		attachment += BalanceConfig.HIDDEN_FELL_ATTACHMENT
	elif run_min_hp <= int(player_max_hp * 0.25):
		attachment += BalanceConfig.HIDDEN_RECKLESS_ATTACHMENT
	elif run_min_hp * 2 > player_max_hp:
		attachment += BalanceConfig.HIDDEN_SAFE_ATTACHMENT
	adjust_hidden(trust, attachment)
	# 回家心事：一次性事件，谈过就不再出现。
	if not run_won:
		SpecialEventManager.enqueue("first_fall", {"battle": run_battle_index})
	if broken and int(relationship_facts.get("promise_broken", 0)) >= 2:
		SpecialEventManager.enqueue("promise_broken_again", {"times": int(relationship_facts.get("promise_broken", 0))})
	if used >= 3:
		SpecialEventManager.enqueue("caught_her_opening", {"used": used})
	if _run_has_mark("companion_save"):
		SpecialEventManager.enqueue("she_saved_you", {})
	if run_won:
		SpecialEventManager.enqueue("first_full_run", {})
	if int(relationship_facts.get("promise_kept", 0)) >= 3:
		SpecialEventManager.enqueue("promise_kept_three", {})
	if learned_sword_intents.size() > _departure_detail("sword_intents", learned_sword_intents.size()):
		SpecialEventManager.enqueue("first_intent", {})
	if _run_has_mark("elite_win"):
		SpecialEventManager.enqueue("first_elite", {})
	if expedition_count >= 5:
		SpecialEventManager.enqueue("fifth_trip", {})


func record_spoken_line(text: String) -> void:
	var clean := text.replace("\n", " ").strip_edges().left(120)
	if clean.is_empty():
		return
	recent_lines.append(clean)
	while recent_lines.size() > RECENT_LINES_LIMIT:
		recent_lines.pop_front()


func get_recent_lines_block(limit: int = 8) -> String:
	return Narrative.recent(recent_lines, limit)


func get_variety_prompt() -> String:
	return Narrative.variety(recent_lines, str(MOODS.pick_random()))


# 开头和最近几句撞了，或又用了已经用过的滥口头禅，就算重复。
func is_repetitive(text: String) -> bool:
	return Narrative.repetitive(text, recent_lines)


func learn_sword_intent(card_id: String, player_line: String) -> bool:
	if card_id.is_empty() or card_id in learned_sword_intents:
		return false
	learned_sword_intents.append(card_id)
	var definition: Dictionary = CompanionCardDatabase.get_definition(card_id)
	shared_history.append({
		"expedition": expedition_count,
		"label": "飞花令",
		"summary": "飞花令里你对出「%s」，她从这句里领悟了剑意「%s」。" % [
			player_line.replace("\n", " ").strip_edges().left(40),
			str(definition.get("name", card_id)),
		],
	})
	_save_relationship()
	return true


func is_feihualing_unlocked() -> bool:
	return feihualing_state == "unlocked"


# 历练中第一次走到对诗处时调用；由随后的检查点一并保存。
func note_feihualing_met() -> void:
	if feihualing_state == "locked":
		feihualing_state = "pending"


func unlock_feihualing() -> void:
	if feihualing_state != "unlocked":
		feihualing_state = "unlocked"
		_save_relationship()


func needs_intro() -> bool:
	return not intro_done and expedition_count == 0 and bond_value == 0 and shared_history.is_empty()


func complete_intro(chosen_name: String, summary: String) -> void:
	player_name = chosen_name.strip_edges()
	intro_done = true
	var clean := summary.replace("\n", " ").strip_edges().left(200)
	if not clean.is_empty():
		shared_history.push_front({"expedition": 0, "summary": clean})
	_save_relationship()


func _stage_prompt() -> String:
	return Narrative.stage_voice(bond_stage)


func get_relationship_archive() -> String:
	return Narrative.archive(get_relationship_prompt(), bond_value, relationship_facts, active_promise, promise_sincere)


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
	return Narrative.minigame(relationship_facts)


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
	return Narrative.journal(current_run_journal, last_run_journal, run_journal_finished)


func begin_battle() -> int:
	run_battle_index += 1
	return run_battle_index


# 记录本趟一个具体、可被引用的瞬间。weight 越高越可能被挑进共同经历。
# mark 是给本地回家心事用的机器标签（如 companion_save / elite_win），不进对话。
func record_moment(summary: String, weight: int, mark: String = "") -> void:
	var clean := summary.replace("\n", " ").strip_edges().left(160)
	if clean.is_empty():
		return
	var moment := {"summary": clean, "weight": weight, "order": run_moments.size()}
	if not mark.is_empty():
		moment["mark"] = mark
	run_moments.append(moment)
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
	return Narrative.shared(shared_history, limit)


# 回家后小墨是否应当先开口；读取一次即清除。
func consume_homecoming() -> bool:
	var pending := homecoming_pending
	homecoming_pending = false
	return pending


# 配合事实独立于羁绊；旧档没有字段时全部从零开始。
func record_cooperation(kind: String, amount: int = 1) -> void:
	if kind not in ["opportunities_used", "opportunities_wasted", "finisher_combo_total", "finishers", "guards"]:
		return
	var stats: Dictionary = relationship_facts.get("cooperation", {})
	stats[kind] = maxi(int(stats.get(kind, 0)) + amount, 0)
	relationship_facts["cooperation"] = stats
	_save_relationship()


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
	_settle_hidden(result)
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


func _profile_config() -> ConfigFile:
	var config := ProfileCodec.encode(self)
	SpecialEventManager.save_to_config(config)
	return config


func _save_relationship() -> Error:
	if suppress_persistence:
		last_save_error = OK
		return OK
	var config := _profile_config()
	# Unfinished rooms replay from their last complete checkpoint. Do not save
	# combat counters or partially granted rewards on top of that old snapshot.
	if not expedition_checkpoint.is_empty():
		if str(expedition_checkpoint.phase) != "map" and not (expedition_checkpoint.phase == "settlement" and expedition_checkpoint.room.has("settlement_result")):
			config = ConfigFile.new()
			if config.parse(str(expedition_checkpoint.profile)) != OK:
				last_save_error = ERR_PARSE_ERROR
				return last_save_error
		config.set_value("expedition", "checkpoint", expedition_checkpoint)
	last_save_error = SaveStorage.write_atomic(config, _save_path_for_slot(current_save_slot))
	if last_save_error != OK:
		push_warning("存档保存失败，错误码：%d" % last_save_error)
	return last_save_error


func _load_relationship() -> void:
	_reset_slot_state()
	var config := ConfigFile.new()
	var error := config.load(_save_path_for_slot(current_save_slot))
	if error != OK:
		error = config.load(_save_path_for_slot(current_save_slot) + ".bak")
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("羁绊存档读取失败，错误码：%s" % error)
		return
	_apply_profile(ProfileCodec.decode(config))
	SpecialEventManager.load_from_config(config)
	var saved_checkpoint: Variant = config.get_value("expedition", "checkpoint", {})
	if Checkpoint.valid(saved_checkpoint):
		expedition_checkpoint = saved_checkpoint.duplicate(true)
		Checkpoint.restore(self, expedition_checkpoint)
		run_active = true
	elif config.has_section("expedition"):
		push_warning("远征进度格式无效，已保留长期存档并返回家中。")


func save_persistent_state() -> void:
	_save_relationship()


# Called only with a complete normalized profile, after clean-state reset.
func _apply_profile(profile: Dictionary) -> void:
	bond_value = profile.bond_value
	bond_stage = profile.bond_stage
	hidden_trust = profile.hidden_trust
	hidden_attachment = profile.hidden_attachment
	pending_bond_stage = profile.pending_bond_stage
	consecutive_run_failures = profile.consecutive_run_failures
	expedition_count = profile.expedition_count
	intro_done = profile.intro_done
	feihualing_state = profile.feihualing_state
	player_name = profile.player_name
	finale_state = profile.finale_state
	finale_mode = profile.finale_mode
	pending_concern = profile.pending_concern
	recent_adventures.assign(profile.recent_adventures)
	recent_lines.assign(profile.recent_lines)
	learned_sword_intents.assign(profile.learned_sword_intents)
	chapter = profile.chapter
	chapter_trip = profile.chapter_trip
	threads_cut = profile.threads_cut
	scroll_pages.assign(profile.scroll_pages)
	story_seen.assign(profile.story_seen)
	pending_story = profile.pending_story
	realm_unlocked = profile.get("realm_unlocked", 1)
	realm_cleared = profile.get("realm_cleared", 0)
	last_free_boss = profile.get("last_free_boss", "")
	shared_history.assign(profile.shared_history)
	last_run_journal.assign(profile.last_run_journal)
	relationship_facts = profile.relationship_facts


func _reset_relationship_facts() -> void:
	chapter = 1
	chapter_trip = 1
	threads_cut = 0
	scroll_pages.clear()
	story_seen.clear()
	pending_story = ""
	realm_unlocked = 1
	realm_cleared = 0
	last_free_boss = ""
	run_adventures.clear()
	recent_adventures.clear()
	shared_history.clear()
	expedition_count = 0
	pending_concern = {}
	player_name = ""
	finale_state = "locked"
	finale_mode = "arrival"
	intro_done = false
	feihualing_state = "locked"
	recent_lines.clear()
	learned_sword_intents.clear()
	run_moments.clear()
	relationship_facts = ProfileCodec.empty_facts()


# Loading or deleting a slot resets both lifetimes. New runs reset only run state.
func _reset_slot_state() -> void:
	_reset_expedition_runtime()
	_reset_relationship_facts()
	bond_value = 0
	bond_stage = 0
	pending_bond_stage = -1
	hidden_trust = 0
	hidden_attachment = 0
	consecutive_run_failures = 0
	last_run_journal.clear()
	SpecialEventManager.reset()


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


func set_finale_state(next_state: String, mode := "arrival") -> void:
	assert(next_state in ["locked", "invited", "accepted", "story", "battle", "ended", "completed"])
	assert(mode in ["arrival", "refusal", "victory", "sacrifice"])
	if next_state in ["story", "ended", "completed"]:
		run_active = false
		expedition_checkpoint.clear()
	finale_state = next_state
	finale_mode = mode
	save_persistent_state()

# Revisit only the chapter invitation; keep the deck, bond and learned sword intents.
func rewind_finale_choice() -> void:
	assert(finale_state == "ended" and finale_mode in ["refusal", "sacrifice"])
	run_active = false
	expedition_checkpoint.clear()
	battle_seed = 0
	player_hp = player_max_hp
	homecoming_pending = false
	set_finale_state("invited")


func return_home_after_finale() -> void:
	assert(finale_state == "ended" and finale_mode == "victory")
	homecoming_pending = false
	set_finale_state("completed", "victory")


# ---- 第二章 · 线头 ----

func is_chapter_two() -> bool:
	return chapter == 2


# 紫线规则从第二章起一直生效（第三章与之后的自由历练都沿用）。
func uses_thread_rules() -> bool:
	return chapter >= 2


func is_chapter_three() -> bool:
	return chapter == 3


# 第二章章末播完后第一次回到家：进入第三章，并排上章首剧情。
func maybe_begin_chapter_three() -> bool:
	if chapter != 2 or chapter_trip <= CHAPTER_TWO_TRIPS or not pending_story.is_empty() or not story_seen.has("ch2_ending"):
		return false
	chapter = 3
	chapter_trip = 1
	pending_story = "ch3_opening"
	_save_relationship()
	return true


# 第一章同归后第一次回到家：进入第二章，并排上章首剧情。
func maybe_begin_chapter_two() -> bool:
	if chapter != 1 or finale_state != "completed" or finale_mode != "victory":
		return false
	chapter = 2
	chapter_trip = 1
	pending_story = "ch2_opening"
	_save_relationship()
	return true


# 本趟第 5 层的剧情奇遇；没有则走普通漫画奇遇。
func chapter_layer_story() -> String:
	if chapter == 3:
		return "ch3_sword_tomb" if chapter_trip == 1 else ""
	if chapter != 2:
		return ""
	match chapter_trip:
		1: return "ch2_blacksmith"
		2: return "ch2_troupe"
	return ""


# 第二章正式剧情趟的首领（3 = 本章已走完，之后自由历练沿用第一趟首领）。
func chapter_boss() -> String:
	if is_free_play():
		return free_boss if not free_boss.is_empty() else "bound_spirit"
	if chapter == 3:
		return "puppeteer" if chapter_trip == 2 else "bound_spirit"
	if chapter != 2:
		return ""
	return "troupe_watcher" if chapter_trip == 2 else "thread_blade_boss"


# 首领战胜利后推进本章；倒下不推进。
func complete_chapter_trip() -> void:
	if chapter == 3:
		if chapter_trip > CHAPTER_THREE_TRIPS:
			clear_realm()
			return
		pending_story = "ch3_trip1_return" if chapter_trip == 1 else "ch3_ending"
		chapter_trip += 1
		return
	if chapter != 2 or chapter_trip > CHAPTER_TWO_TRIPS:
		return
	if chapter_trip == 1:
		pending_story = "ch2_trip1_return"
	else:
		pending_story = "ch2_ending"
	chapter_trip += 1


func consume_pending_story() -> String:
	var story := pending_story
	pending_story = ""
	if not story.is_empty():
		_save_relationship()
	return story


func mark_story_seen(story_id: String) -> void:
	if not story_seen.has(story_id):
		story_seen.append(story_id)


func grant_scroll_page(page_id: String) -> bool:
	if page_id.is_empty() or scroll_pages.has(page_id):
		return false
	scroll_pages.append(page_id)
	var page_name := str(load("res://scripts/data/chapter_two_story.gd").SCROLL_NAMES.get(page_id, page_id))
	shared_history.append({"expedition": expedition_count, "label": "剑谱",
		"summary": "你们找回了他留下的%s。" % page_name})
	return true


func has_scroll_page(page_id: String) -> bool:
	return scroll_pages.has(page_id)


func record_thread_cut() -> void:
	threads_cut += 1


# 默契：斩过的线越多，她在线里挣得越用力。
func thread_hits_required() -> int:
	return BalanceConfig.THREAD_HITS_TRAINED if threads_cut >= BalanceConfig.THREAD_TRAINED_AT else BalanceConfig.THREAD_HITS_BASE


func xiaomo_breaks_first_thread() -> bool:
	return threads_cut >= BalanceConfig.THREAD_SELF_BREAK_AT


func chapter_label() -> String:
	if chapter == 3:
		if chapter_trip <= CHAPTER_THREE_TRIPS:
			return "第三章 · 提线  %d/%d" % [chapter_trip, CHAPTER_THREE_TRIPS]
		if realm_cleared >= REALM_MAX:
			return "剑境 · 五  已破"
		return "自由历练 · 剑境 %s" % realm_name(realm_unlocked)
	if chapter != 2:
		return ""
	if chapter_trip <= CHAPTER_TWO_TRIPS:
		return "第二章 · 线头  %d/%d" % [chapter_trip, CHAPTER_TWO_TRIPS]
	return "第二章 · 线头  已完"


# ---- 剑境 / 自由历练 ----

func is_free_play() -> bool:
	return chapter == 3 and chapter_trip > CHAPTER_THREE_TRIPS


static func realm_name(level: int) -> String:
	return ["", "一", "二", "三", "四", "五"][clampi(level, 0, REALM_MAX)]


# 这一级比上一级多了什么（选剑境时显示）。
static func realm_rules(level: int) -> String:
	match level:
		1: return "就是现在的自由历练。"
		2: return "敌人生命 +10%。罕见、稀有牌更常出现。"
		3: return "宝箱、奇遇、路遇的回复减半。宝箱取信物时一次给两件。"
		4: return "首领生命 +20%，到 2/3 血就狂暴。出发时带一件信物。"
		5: return "敌人每次攻击 +2，起始牌组多一张心魔。"
	return ""


func _roll_free_boss() -> String:
	var pool: Array = FREE_BOSSES.filter(func(id): return id != last_free_boss)
	return str(pool[randi() % pool.size()])


# 以当前最高剑境打通一趟自由历练，解锁下一级。
func clear_realm() -> void:
	if not is_free_play() or sword_realm <= 0:
		return
	if sword_realm > realm_cleared:
		realm_cleared = sword_realm
		if sword_realm >= REALM_MAX and pending_story.is_empty():
			pending_story = "realm5_clear"
	if sword_realm >= realm_unlocked and realm_unlocked < REALM_MAX:
		realm_unlocked += 1


# 剑境三：回复减半（只管战斗外的回复）。
func rest_heal(amount: int) -> int:
	if amount > 0 and sword_realm >= 3:
		return maxi(int(amount / 2), 1)
	return amount


func prepare_finale_battle() -> void:
	pending_encounter = EncounterType.BOSS
	player_hp = player_max_hp
	run_active = true
	battle_seed = maxi(1, randi() & 0x7fffffff)
	set_finale_state("battle")
	checkpoint("battle")


func _reset_expedition_runtime() -> void:
	run_active = false
	expedition_checkpoint.clear()
	map_seed = 0
	map_layer = 0
	map_node = 0
	map_path.clear()
	battle_seed = 0
	route_layer = 1
	run_id = 0
	player_max_hp = BalanceConfig.PLAYER_START_MAX_HP
	player_hp = player_max_hp
	pending_encounter = EncounterType.NORMAL
	pending_event = EventType.TREASURE
	active_promise = ""
	promise_broken = false
	run_won = false
	settlement_applied = false
	post_battle_scene = Checkpoint.SCENES.map
	pending_act_bond_gain = -1
	run_adventures.clear()
	current_run_journal.clear()
	run_journal_finished = false
	run_moments.clear()
	run_battle_index = 0
	homecoming_pending = false
	promise_sincere = true
	run_min_hp = player_hp
	run_relics.clear()
	sword_realm = 0
	free_boss = ""
	run_lean.clear()
	run_lean_spoken.clear()
	_reset_deck()


func checkpoint(phase: String, room: Dictionary = {}) -> Error:
	if not run_active:
		return OK
	var snapshot := Checkpoint.capture(self, phase, room, _profile_config().encode_to_text())
	if not Checkpoint.valid(snapshot):
		last_save_error = ERR_INVALID_DATA
		push_warning("远征进度保存失败：状态不完整。")
		return last_save_error
	expedition_checkpoint = snapshot
	return _save_relationship()


func has_expedition() -> bool:
	return run_active and not expedition_checkpoint.is_empty()


func resume_destination() -> String:
	if has_expedition():
		return str(Checkpoint.SCENES[expedition_checkpoint.phase])
	return Routes.PATHS.home


func resume_expedition() -> String:
	if has_expedition():
		Checkpoint.restore(self, expedition_checkpoint)
	return resume_destination()


func room_checkpoint(phase: String) -> Dictionary:
	if has_expedition() and expedition_checkpoint.phase == phase:
		return expedition_checkpoint.room.duplicate(true)
	return {}


func clear_expedition() -> Error:
	run_active = false
	expedition_checkpoint.clear()
	return _save_relationship()


func navigate(destination: String, source: Node) -> Error:
	return _navigator.request(get_tree(), destination, source)


func is_scene_transition_pending() -> bool:
	return _navigator.is_pending()


func scene_path(route: String) -> String:
	return Routes.resolve(route)


func save_and_exit(source: Node = null) -> Error:
	if is_scene_transition_pending():
		return ERR_BUSY
	var error := _save_relationship()
	if error == OK:
		var origin := source if source != null else get_tree().current_scene
		error = navigate("save_select", origin)
	return error


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _save_relationship() == OK:
			get_tree().quit()
		else:
			var dialog := AcceptDialog.new()
			dialog.dialog_text = "存档未能保存，请检查磁盘或文件权限后重试。"
			get_tree().root.add_child(dialog)
			dialog.confirmed.connect(dialog.queue_free)
			dialog.popup_centered()
