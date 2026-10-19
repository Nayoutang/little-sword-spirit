extends Node2D

# 仅呈现战斗已有状态；不持有或修改紫线规则、计数与存档。
var battle: Node
var bursts: Array[Dictionary] = []
var clock := 0.0
const VIOLET := Color("b790e2")

func _ready() -> void:
	name = "ThreadArt"
	# 在气泡、文字与按钮后面绘制，避免紫线盖住规则说明。
	z_index = 0

func _process(delta: float) -> void:
	clock += delta
	for burst in bursts:
		burst["age"] += delta
	bursts = bursts.filter(func(b): return b["age"] < 0.55)
	queue_redraw()

func _socket(holder: int) -> Vector2:
	var rect: Rect2 = battle.enemy_blocks[holder].get_global_rect()
	return to_local(rect.position + rect.size * Vector2(0.52, 0.42))

func _companion() -> Vector2:
	var rect: Rect2 = battle.get_node("BattleUI/CompanionPanel/Portrait").get_global_rect()
	return to_local(rect.position + rect.size * Vector2(0.54, 0.52))

func snap(holder: int, self_break: bool) -> void:
	if holder < 0 or holder >= battle.enemy_blocks.size():
		return
	bursts.append({"from": _socket(holder), "to": _companion(), "age": 0.0, "self": self_break})

func _draw() -> void:
	if not is_instance_valid(battle):
		return
	for index in range(battle.xiaomo_threads.size()):
		var holder: int = battle.xiaomo_threads[index]
		if holder < 0 or holder >= battle.enemy_blocks.size():
			continue
		var start := _socket(holder)
		var end := _companion() + Vector2(0, index * 12)
		var points := PackedVector2Array()
		for step in range(25):
			var t := step / 24.0
			points.append(start.lerp(end, t) + Vector2(0, sin(t * PI) * (-36 + sin(clock * 2 + index) * 5)))
		draw_polyline(points, Color(0.28, 0.12, 0.42, 0.42), 7.0, true)
		draw_polyline(points, VIOLET, 1.8, true)
		draw_arc(start, 9.0, 0, TAU, 24, VIOLET, 1.5, true)
		draw_arc(end, 13.0 + index * 4, 0, TAU, 32, VIOLET, 1.5, true)
	for burst in bursts:
		var t: float = burst["age"] / 0.55
		var start: Vector2 = burst["from"]
		var end: Vector2 = burst["to"]
		# 自挣从她身侧断开；玩家斩线从连线中间断开。
		var at := start.lerp(end, 0.88 if burst["self"] else 0.5)
		var tint := Color("80d9cf") if burst["self"] else Color("f1ce82")
		tint.a = 1.0 - t
		var recoil := (end - start).normalized() * (18.0 + t * 65)
		draw_line(start, at - recoil, Color(VIOLET, 1.0 - t), 2.0, true)
		draw_line(at + recoil, end, Color(VIOLET, 1.0 - t), 2.0, true)
		draw_arc(at, 8 + t * 30, 0, TAU, 32, tint, 2.0, true)
		for index in range(8):
			var direction := Vector2.from_angle(index * TAU / 8.0 + 0.3)
			draw_circle(at + direction * (12 + t * 48), 2.5 * (1.0 - t), tint)
