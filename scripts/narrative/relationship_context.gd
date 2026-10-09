extends RefCounted

# Read-only prompt presentation. RunState retains all memory ownership.

static func stage_voice(stage_index: int) -> String:
	match stage_index:
		0:
			return "当前关系阶段：初遇。她认生、设防，愿意回应眼前的话，但不会假装早已熟悉。关心多通过提醒和实际的事表达，不主动追问私事。"
		1:
			return "当前关系阶段：相识。她开始习惯与玩家相处，偶尔主动接着以前的话题说，或自然提起记录里的一件共同经历；仍有自己的脾气，不必每次都强调关心。"
		2:
			return "当前关系阶段：交心。她信任玩家，愿意说眼前真实的烦恼、请他一起想办法，也可以自然邀他对诗。能安心地换话题或安静相处，不要求玩家表态证明信任。"
		_:
			return "当前关系阶段：生死之交。她把并肩相处当成自然的日常，关键时刻会直接关心，也保留独立意见。亲近体现在熟悉和默契里，不用反复确认承诺；不得编造记录里没有的习惯或往事。"


static func relationship(stage_index: int, player_name: String) -> String:
	var stage_text := stage_voice(stage_index)
	if not player_name.is_empty():
		stage_text += "持剑人的名字：%s。" % player_name
	return stage_text


static func recent(recent_lines: Array[String], limit: int = 8) -> String:
	if recent_lines.is_empty():
		return "（暂无）"
	var lines: Array[String] = []
	for index in range(maxi(recent_lines.size() - limit, 0), recent_lines.size()):
		lines.append("- " + recent_lines[index])
	return "\n".join(lines)


static func variety(recent_lines: Array[String], mood: String) -> String:
	return "【别重复自己】你最近说过的话：\n%s\n这次换一个开头和句式，别复用上面的说法和口头禅。\n【此刻的你】%s（只影响你的语气和想到的事，不必说出来）" % [
		recent(recent_lines),
		mood,
	]


static func repetitive(text: String, recent_lines: Array[String]) -> bool:
	var clean := text.strip_edges()
	if clean.length() < 4:
		return false
	var head := clean.left(3)
	for index in range(maxi(recent_lines.size() - 4, 0), recent_lines.size()):
		if recent_lines[index].left(3) == head:
			return true
	if clean.begins_with("…"):
		for index in range(maxi(recent_lines.size() - 4, 0), recent_lines.size()):
			if recent_lines[index].begins_with("…"):
				return true
	for worn in ["我才不是", "才不是担心", "别误会", "以前有个人", "你不必知道"]:
		if clean.contains(worn):
			for line in recent_lines:
				if line.contains(worn):
					return true
	return false


static func archive(relationship_prompt: String, bond_value: int, relationship_facts: Dictionary, active_promise: String, promise_sincere: bool) -> String:
	var promise_text := "本趟没有约定"
	if active_promise == "protect":
		promise_text = "本趟约定：玩家会保护好自己（血不掉到四分之一以下）"
	elif active_promise == "finish":
		promise_text = "本趟约定：玩家会平安完成远征"
	if not active_promise.is_empty() and not promise_sincere:
		promise_text += "（玩家当时是随口应付着答应的）"
	return "%s；羁绊 %d/100；并肩胜利 %d 次、失利 %d 次；兑现约定 %d 次、失约 %d 次；%s；过往出牌记录 %s。" % [
		relationship_prompt,
		bond_value,
		int(relationship_facts.get("battles_won", 0)),
		int(relationship_facts.get("battles_lost", 0)),
		int(relationship_facts.get("promise_kept", 0)),
		int(relationship_facts.get("promise_broken", 0)),
		promise_text,
		str(relationship_facts.get("companion_card_counts", {})),
	]


static func minigame(relationship_facts: Dictionary) -> String:
	var results: Array = relationship_facts.get("minigame_results", [])
	if results.is_empty():
		return "【小游戏关键事实】暂无。"
	var lines: Array[String] = ["【小游戏关键事实】"]
	for fact in results:
		if fact is Dictionary:
			lines.append(str(fact.get("summary", "")))
	return "\n".join(lines)


static func journal(current_run_journal: Array[Dictionary], last_run_journal: Array[Dictionary], run_journal_finished: bool) -> String:
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


static func shared(shared_history: Array[Dictionary], limit: int = 9) -> String:
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
		var label := str(fact.get("label", ""))
		if label.is_empty():
			label = "初遇" if int(fact.get("expedition", 0)) == 0 else "第%d趟" % int(fact.get("expedition", 0))
		lines.append("- %s：%s" % [label, str(fact.get("summary", ""))])
	return "\n".join(lines)
