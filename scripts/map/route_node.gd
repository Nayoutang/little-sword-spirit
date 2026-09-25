class_name RouteNode
extends Area2D

signal selected(route_node: RouteNode)

enum NodeType { HOME, BATTLE, ELITE, TREASURE, UNKNOWN, ADVENTURE, BOSS }

const NODE_RADIUS := 30.0
const COLORS := {
	NodeType.HOME: Color("#416d77"),
	NodeType.BATTLE: Color("#a44f43"),
	NodeType.ELITE: Color("#70546f"),
	NodeType.TREASURE: Color("#a98038"),
	NodeType.UNKNOWN: Color("#686e68"),
	NodeType.ADVENTURE: Color("#397c76"),
	NodeType.BOSS: Color("#272d2d"),
}
var node_type: NodeType = NodeType.BATTLE
var layer_index := 0
var is_selectable := false
var is_visited := false
var is_current := false


func setup(type: NodeType, layer: int) -> void:
	node_type = type
	layer_index = layer

	var collision := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = NODE_RADIUS
	collision.shape = circle_shape
	add_child(collision)

	queue_redraw()


func set_map_state(selectable: bool, visited: bool, current: bool) -> void:
	is_selectable = selectable
	is_visited = visited
	is_current = current
	input_pickable = selectable
	queue_redraw()


func _draw() -> void:
	var fill_color: Color = COLORS[node_type]
	if not is_selectable and not is_visited and not is_current:
		fill_color = Color("#5c615b")
	draw_circle(Vector2.ZERO, NODE_RADIUS + 5.0, Color("#d6c39e"))
	draw_circle(Vector2.ZERO, NODE_RADIUS, fill_color)

	var outline_color := Color("#42c5ba") if is_selectable else Color("#af9d7c")
	var outline_width := 5.0 if is_selectable else 2.0
	if is_current:
		outline_color = Color.WHITE
		outline_width = 6.0
	draw_arc(Vector2.ZERO, NODE_RADIUS, 0.0, TAU, 48, outline_color, outline_width, true)
	_draw_icon(Color("#f5e8ce"))


func _draw_icon(ink: Color) -> void:
	match node_type:
		NodeType.HOME:
			_draw_home_icon(ink)
		NodeType.BATTLE:
			_draw_sword_icon(ink)
		NodeType.ELITE:
			_draw_elite_icon(ink)
		NodeType.TREASURE:
			_draw_treasure_icon(ink)
		NodeType.UNKNOWN:
			_draw_unknown_icon(ink)
		NodeType.ADVENTURE:
			_draw_lantern_icon(ink)
		NodeType.BOSS:
			_draw_boss_icon(ink)


func _draw_home_icon(ink: Color) -> void:
	# 飞檐与敞开的门，让起点在远景中也像一间小屋。
	draw_polyline(PackedVector2Array([
		Vector2(-19, -6), Vector2(-14, -9), Vector2(0, -17),
		Vector2(14, -9), Vector2(19, -6),
	]), ink, 3.4, true)
	draw_line(Vector2(-13, -5), Vector2(13, -5), ink, 2.8, true)
	draw_line(Vector2(-11, -4), Vector2(-11, 15), ink, 2.8, true)
	draw_line(Vector2(11, -4), Vector2(11, 15), ink, 2.8, true)
	draw_line(Vector2(-16, 15), Vector2(16, 15), ink, 3.4, true)
	draw_arc(Vector2(0, 10), 5.0, PI, TAU, 12, ink, 2.3, true)
	draw_line(Vector2(-5, 10), Vector2(-5, 15), ink, 2.3, true)
	draw_line(Vector2(5, 10), Vector2(5, 15), ink, 2.3, true)


func _draw_sword_icon(ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 6), Vector2(10, -14), Vector2(17, -19),
		Vector2(14, -11), Vector2(0, 9),
	]), ink)
	draw_line(Vector2(-10, 4), Vector2(3, 13), ink, 3.5, true)
	draw_line(Vector2(-4, 9), Vector2(-14, 19), ink, 3.6, true)
	draw_circle(Vector2(-15, 20), 2.6, ink)


func _draw_elite_icon(ink: Color) -> void:
	# 双剑比普通战的单剑更密集，顶部的星形代表精英。
	draw_line(Vector2(-14, -12), Vector2(12, 15), ink, 3.0, true)
	draw_line(Vector2(14, -12), Vector2(-12, 15), ink, 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -17), Vector2(-12, -15), Vector2(-14, -9),
	]), ink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, -17), Vector2(12, -15), Vector2(14, -9),
	]), ink)
	draw_line(Vector2(-17, 10), Vector2(-8, 18), ink, 2.4, true)
	draw_line(Vector2(17, 10), Vector2(8, 18), ink, 2.4, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -11), Vector2(2.8, -3), Vector2(0, 5), Vector2(-2.8, -3),
	]), ink)


func _draw_treasure_icon(ink: Color) -> void:
	draw_rect(Rect2(-16, -2, 32, 18), ink, false, 2.8, true)
	draw_polyline(PackedVector2Array([
		Vector2(-16, -2), Vector2(-13, -12), Vector2(13, -12),
		Vector2(16, -2),
	]), ink, 2.8, true)
	draw_line(Vector2(-16, 3), Vector2(16, 3), ink, 2.3, true)
	draw_line(Vector2(-9, -11), Vector2(-9, 15), ink, 2.0, true)
	draw_line(Vector2(9, -11), Vector2(9, 15), ink, 2.0, true)
	draw_rect(Rect2(-3, 1, 6, 7), ink, true)


func _draw_unknown_icon(ink: Color) -> void:
	# 封印的卷轴：未知节点仍保留一点悬念。
	draw_rect(Rect2(-11, -15, 22, 30), ink, false, 2.7, true)
	draw_line(Vector2(-6, -8), Vector2(6, -8), ink, 2.1, true)
	draw_line(Vector2(-6, 8), Vector2(6, 8), ink, 2.1, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5), Vector2(6, 0), Vector2(0, 5), Vector2(-6, 0),
	]), ink)
	draw_circle(Vector2(0, 0), 1.7, Color("#5c615b"))


func _draw_lantern_icon(ink: Color) -> void:
	draw_arc(Vector2(0, -14), 4.0, PI, TAU, 12, ink, 2.4, true)
	draw_line(Vector2(0, -18), Vector2(0, -14), ink, 2.4, true)
	draw_line(Vector2(-11, -10), Vector2(11, -10), ink, 2.5, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -8), Vector2(8, 10), Vector2(-8, 10),
	]), ink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5), Vector2(5, 3), Vector2(0, 8), Vector2(-5, 3),
	]), Color("#397c76"))
	draw_line(Vector2(-12, 12), Vector2(12, 12), ink, 2.4, true)
	draw_line(Vector2(0, 12), Vector2(0, 18), ink, 2.1, true)


func _draw_boss_icon(ink: Color) -> void:
	# 有角的面具轮廓，和精英双剑区别明显。
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -16), Vector2(-7, -11), Vector2(0, -13),
		Vector2(7, -11), Vector2(15, -16), Vector2(12, -3),
		Vector2(10, 10), Vector2(0, 18), Vector2(-10, 10), Vector2(-12, -3),
	]), ink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -4), Vector2(-3, -1), Vector2(-5, 3), Vector2(-10, 1),
	]), Color("#272d2d"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -4), Vector2(3, -1), Vector2(5, 3), Vector2(10, 1),
	]), Color("#272d2d"))
	draw_line(Vector2(-4, 10), Vector2(4, 10), Color("#272d2d"), 2.5, true)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_selectable and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(self)
