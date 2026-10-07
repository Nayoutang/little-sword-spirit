extends RefCounted

var rounds: Array[Dictionary] = []
var intervals: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var current: Dictionary = {}
var open_interval: Dictionary = {}
var last_combo := 0
var action_index := 0
var skill_unlocked := false
var turn_number := 1

func begin_round(turn: int, combo: int, cloud: bool, unlocked: bool, starting_winds := 0) -> void:
	turn_number = turn
	skill_unlocked = unlocked
	current = {"turn": turn, "cloud_active": cloud, "unlocked": unlocked, "flowing_light": 0, "brilliance": 0, "cards": 0, "cloud_triggers": 0, "cloud_started_this_round": false, "cloud_in_hand": 0, "wind_drawn": starting_winds, "wind_played": 0, "wind_costs": [0, 0, 0], "wind_held": 0}
	observe_combo(combo, "round_start")

func observe_combo(combo: int, reason: String) -> void:
	if skill_unlocked and combo >= 3 and open_interval.is_empty():
		open_interval = {"start_turn": turn_number, "start_action": action_index, "entry": reason}
	if not open_interval.is_empty() and combo < 3:
		close_interval(reason)
	last_combo = combo

func close_interval(reason: String) -> void:
	if open_interval.is_empty():
		return
	var interval := open_interval.duplicate(true)
	interval["end_turn"] = turn_number
	interval["end_action"] = action_index
	interval["outcome"] = reason
	interval["delay_turns"] = int(interval["end_turn"]) - int(interval["start_turn"]) if reason == "brilliance" else null
	intervals.append(interval)
	open_interval.clear()

func record_action(card_id: int, cost: int, combo_before: int, combo_after: int, cloud: bool, wind_in_hand: int, wind_in_deck: int) -> void:
	action_index += 1
	current["cloud_active"] = bool(current.get("cloud_active", false)) or cloud
	if card_id == 15: current["cloud_started_this_round"] = true
	var event := {"turn": int(current.get("turn", 1)), "action": action_index, "card_id": card_id, "cost": cost, "combo_before": combo_before, "combo_after": combo_after, "wind_in_hand": wind_in_hand, "wind_in_deck": wind_in_deck}
	actions.append(event)
	if card_id == 13:
		current["flowing_light"] = int(current.get("flowing_light", 0)) + 1
	elif card_id == 14:
		current["brilliance"] = int(current.get("brilliance", 0)) + 1
		close_interval("brilliance")
	else:
		current["cards"] = int(current.get("cards", 0)) + 1
	if card_id == 16:
		current["wind_played"] = int(current.get("wind_played", 0)) + 1
		current["wind_costs"][clampi(cost, 0, 2)] += 1
	observe_combo(combo_after, "flowing_light" if card_id == 13 else "card_cleared_or_spent")

func finish_round(wind_held: int, reason: String) -> void:
	if current.is_empty():
		return
	current["wind_held"] = wind_held
	current["end_reason"] = reason
	rounds.append(current.duplicate(true))
	current.clear()

func finish_battle(wind_held: int) -> void:
	close_interval("battle_end")
	finish_round(wind_held, "battle_end")

func summary() -> Dictionary:
	var numerator := 0
	var denominator := 0
	var activation_turn = null
	var first_seen_turn = null
	var opportunities := 0
	for round_record in rounds:
		if int(round_record["cloud_in_hand"]) > 0 and first_seen_turn == null:
			first_seen_turn = int(round_record["turn"])
		if int(round_record["cloud_in_hand"]) > 0 and not bool(round_record["cloud_active"]): opportunities += 1
		if bool(round_record["cloud_started_this_round"]) and activation_turn == null:
			activation_turn = int(round_record["turn"])
		if bool(round_record["unlocked"]) and bool(round_record["cloud_active"]):
			denominator += 1
			if int(round_record["flowing_light"]) > 0 and int(round_record["brilliance"]) > 0:
				numerator += 1
	return {"joint_skills_numerator": numerator, "eligible_rounds_denominator": denominator, "cloud_first_seen_turn": first_seen_turn, "cloud_activation_turn": activation_turn, "cloud_unplayed_opportunity_rounds": opportunities, "rounds": rounds.duplicate(true), "intervals": intervals.duplicate(true), "actions": actions.duplicate(true)}
