extends RefCounted

# value为展示总伤害；segments存在时是各段伤害，否则value是单段。
static func values(intent: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if int(intent.get("type", -1)) != 0 or bool(intent.get("intercepted", false)): return result
	if intent.has("segments"):
		for damage in intent["segments"]: result.append(maxi(int(damage), 0))
	else: result.append(maxi(int(intent.get("value", 0)), 0))
	return result

static func total(intent: Dictionary) -> int:
	var amount := 0
	for damage in values(intent): amount += damage
	return amount

static func reduce_next(intent: Dictionary, amount: int) -> void:
	var parts := values(intent)
	if parts.is_empty(): return
	parts[0] = maxi(parts[0] - amount, 0)
	assign(intent, parts)

static func reduce_each(intent: Dictionary, amount: int) -> void:
	var parts := values(intent)
	if parts.is_empty(): return
	for index in range(parts.size()): parts[index] = maxi(parts[index] - amount, 0)
	assign(intent, parts)

static func assign(intent: Dictionary, parts: Array[int]) -> void:
	var amount := 0
	for damage in parts: amount += damage
	intent["value"] = amount
	if intent.has("segments"): intent["segments"] = parts

static func intercept(intent: Dictionary) -> void:
	intent["intercepted_damage"] = total(intent)
	intent["intercepted"] = true
	intent["value"] = 0
