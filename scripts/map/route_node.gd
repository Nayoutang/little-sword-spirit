class_name RouteNode
extends Area2D

signal selected(route_node: RouteNode)

enum NodeType { HOME, BATTLE, ELITE, TREASURE, UNKNOWN, ADVENTURE, BOSS }

const NODE_RADIUS := 30.0
const COLORS := {
	NodeType.HOME: Color("#3f7fc4"),
	NodeType.BATTLE: Color("#d94747"),
	NodeType.ELITE: Color("#8e44ad"),
	NodeType.TREASURE: Color("#e4b935"),
	NodeType.UNKNOWN: Color("#808080"),
	NodeType.ADVENTURE: Color("#3aa6a0"),
	NodeType.BOSS: Color("#151515"),
}
const LABELS := {
	NodeType.HOME: "家",
	NodeType.BATTLE: "战",
	NodeType.ELITE: "精",
	NodeType.TREASURE: "宝",
	NodeType.UNKNOWN: "?",
	NodeType.ADVENTURE: "奇",
	NodeType.BOSS: "BOSS",
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

	var title_label := Label.new()
	title_label.text = LABELS[node_type]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = Vector2(-NODE_RADIUS, -NODE_RADIUS)
	title_label.size = Vector2(NODE_RADIUS * 2.0, NODE_RADIUS * 2.0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(title_label)
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
		fill_color = Color("#454545")
	draw_circle(Vector2.ZERO, NODE_RADIUS, fill_color)

	var outline_color := Color("#55e6ff") if is_selectable else Color("#b0b0b0")
	var outline_width := 5.0 if is_selectable else 2.0
	if is_current:
		outline_color = Color.WHITE
		outline_width = 6.0
	draw_arc(Vector2.ZERO, NODE_RADIUS, 0.0, TAU, 48, outline_color, outline_width, true)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if is_selectable and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(self)
