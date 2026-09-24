extends Node

const DEFINITIONS := {
	"near_death_clear": {
		"priority": 100,
		"reward": AbilityManager.LIFE_GUARD,
		"background": "玩家刚刚以不高于最大生命10%的状态击败了Boss。小墨非常担心。",
		"resolved_when": "玩家承认危险、表示以后会注意，或以符合关系的方式接受小墨的关心。",
		"unresolved_when": "玩家明显敷衍、嘲讽、转移话题，或表示以后仍会故意冒险。",
	},
	"bond_skill_comeback": {
		"priority": 50,
		"reward": AbilityManager.RESONANCE,
		"background": "玩家在低生命状态下发动流光或华彩，并依靠这次配合赢下Boss战。",
		"resolved_when": "玩家认可双方的配合、信任小墨，或正面回应这次共同作战。",
		"unresolved_when": "玩家否认小墨的作用、明显敷衍或转移话题。",
	},
	"repeated_failure_clear": {
		"priority": 40,
		"reward": AbilityManager.PERSEVERANCE,
		"background": "玩家在连续失败至少两次后终于击败了Boss。小墨想谈论失败与坚持。",
		"resolved_when": "玩家承认失败并愿意继续前进，或认可双方没有放弃。",
		"unresolved_when": "玩家否认失败、把责任全部推给小墨，或转移话题。",
	},
}

var pending_events: Array[Dictionary] = []
var current_event: Dictionary = {}
var completed_events: Array[String] = []


func reset() -> void:
	pending_events.clear()
	current_event.clear()
	completed_events.clear()


func enqueue(event_id: String, context: Dictionary = {}) -> void:
	if not DEFINITIONS.has(event_id) or event_id in completed_events or _is_queued(event_id):
		return
	pending_events.append({"event_id": event_id, "context": context})
	pending_events.sort_custom(_higher_priority)


func evaluate_boss_victory(
	current_hp: int,
	max_hp: int,
	bond_skill_comeback: bool,
	previous_failures: int
) -> void:
	if current_hp * 10 <= max_hp:
		enqueue("near_death_clear", {"hp": current_hp, "max_hp": max_hp})
	if bond_skill_comeback:
		enqueue("bond_skill_comeback", {})
	if previous_failures >= 2:
		enqueue("repeated_failure_clear", {"failures": previous_failures})


func activate_next() -> bool:
	if not current_event.is_empty():
		return true
	if pending_events.is_empty():
		return false
	current_event = pending_events.pop_front()
	return true


func has_active_event() -> bool:
	return not current_event.is_empty()


func has_waiting_events() -> bool:
	return has_active_event() or not pending_events.is_empty()


func get_active_event_id() -> String:
	return str(current_event.get("event_id", ""))


func get_prompt_context() -> String:
	if not has_active_event():
		return ""
	var event_id := get_active_event_id()
	var definition: Dictionary = DEFINITIONS[event_id]
	var supplements: Array[String] = []
	for queued in pending_events:
		supplements.append(str(DEFINITIONS[str(queued["event_id"])]["background"]))
	var supplement_text := "无"
	if not supplements.is_empty():
		supplement_text = "；".join(supplements)
	return """【当前特殊事件】
event_id: %s
事件背景：%s
完成语义：%s
不算完成：%s
本局其他待处理经历：%s

你必须保持小墨人格，并且只返回一个合法 JSON 对象，不要使用 Markdown 代码块：
{"reply":"角色台词","emotion":"angry|soft|worried|neutral","event_result":{"event_id":"%s","resolved":true或false,"resolution":"简短语义标签"}}
本轮只允许判断当前 event_id，不得完成其他事件，也不得声称已经直接修改存档或授予能力。""" % [
		event_id,
		definition["background"],
		definition["resolved_when"],
		definition["unresolved_when"],
		supplement_text,
		event_id,
	]


func validate_and_resolve(event_result: Variant) -> Dictionary:
	var outcome := {"resolved": false, "unlocked": false, "ability_id": ""}
	if not has_active_event() or not event_result is Dictionary:
		return outcome
	var event_id := get_active_event_id()
	if str(event_result.get("event_id", "")) != event_id or event_result.get("resolved", false) != true:
		return outcome
	var ability_id := str(DEFINITIONS[event_id]["reward"])
	if not AbilityManager.DEFINITIONS.has(ability_id):
		return outcome
	var unlocked_now := AbilityManager.unlock(ability_id)
	completed_events.append(event_id)
	current_event.clear()
	outcome = {"resolved": true, "unlocked": unlocked_now, "ability_id": ability_id}
	RunState.save_persistent_state()
	return outcome


func _is_queued(event_id: String) -> bool:
	if get_active_event_id() == event_id:
		return true
	for queued in pending_events:
		if str(queued.get("event_id", "")) == event_id:
			return true
	return false


func _higher_priority(a: Dictionary, b: Dictionary) -> bool:
	return int(DEFINITIONS[str(a["event_id"])]["priority"]) > int(DEFINITIONS[str(b["event_id"])]["priority"])


func save_to_config(config: ConfigFile) -> void:
	config.set_value("special_events", "pending", pending_events)
	config.set_value("special_events", "current", current_event)
	config.set_value("special_events", "completed", completed_events)


func load_from_config(config: ConfigFile) -> void:
	reset()
	var saved_pending: Variant = config.get_value("special_events", "pending", [])
	if saved_pending is Array:
		for event_data in saved_pending:
			if event_data is Dictionary and DEFINITIONS.has(str(event_data.get("event_id", ""))):
				pending_events.append(event_data)
	var saved_current: Variant = config.get_value("special_events", "current", {})
	if saved_current is Dictionary and DEFINITIONS.has(str(saved_current.get("event_id", ""))):
		current_event = saved_current
	var saved_completed: Variant = config.get_value("special_events", "completed", [])
	if saved_completed is Array:
		for event_id in saved_completed:
			if DEFINITIONS.has(str(event_id)):
				completed_events.append(str(event_id))
