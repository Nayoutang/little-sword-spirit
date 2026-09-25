extends Node2D

const CHIBI_TEXTURE := preload("res://art/character/sword_spirit_chibi_cutout.png")

# 固定10层：Home + 7层常规路线 + 第9层宝箱 + Boss。
const TOTAL_LAYERS := 10
const ROUTE_COUNT := 5
const GUARANTEED_TREASURE_LAYER := 8 # 从0开始计数，即玩家看到的第9层。
const SIDE_MARGIN := 150.0
const NODE_X_JITTER := 24.0
const TOP_MARGIN := 165.0
const BOTTOM_MARGIN := 120.0

var layers: Array[Array] = []
var connections: Dictionary = {} # RouteNode -> Array[RouteNode]
var current_node: RouteNode
var player_marker: Sprite2D
var layer_node_types: Array[Array] = []
var map_rng := RandomNumberGenerator.new()

# 场景切到战斗再回来时，静态数据用于复原同一张地图和所在节点。
static var run_seed := 0
static var saved_layer_index := 0
static var saved_node_index := 0
static var saved_run_id := -1


func _ready() -> void:
	$MapUI/ReturnButton.pressed.connect(_return_home)
	$MapUI/Title.text = "路线选择"
	$MapUI/Bond.text = "羁绊: %d/100　%s" % [
		RunState.bond_value,
		RunState.get_bond_stage_name(),
	]
	_generate_map()
	_build_legend()


func _build_legend() -> void:
	var legend_bar: ColorRect = $MapUI/LegendBar
	var entries := [
		[RouteNode.NodeType.HOME, "起点"],
		[RouteNode.NodeType.BATTLE, "战斗"],
		[RouteNode.NodeType.ELITE, "精英"],
		[RouteNode.NodeType.TREASURE, "宝箱"],
		[RouteNode.NodeType.UNKNOWN, "未知"],
		[RouteNode.NodeType.ADVENTURE, "奇遇"],
		[RouteNode.NodeType.BOSS, "首领"],
	]
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var icon := RouteNode.new()
		icon.setup(entry[0] as RouteNode.NodeType, -1)
		icon.input_pickable = false
		icon.position = Vector2(75.0 + index * 185.0, 28.0)
		icon.scale = Vector2(0.46, 0.46)
		legend_bar.add_child(icon)
		var label := Label.new()
		label.position = Vector2(99.0 + index * 185.0, 10.0)
		label.size = Vector2(85.0, 36.0)
		label.text = entry[1]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color("#f5e8ce"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend_bar.add_child(label)


func _generate_map() -> void:
	if saved_run_id != RunState.run_id:
		saved_run_id = RunState.run_id
		run_seed = 0
		saved_layer_index = 0
		saved_node_index = 0
	if run_seed == 0:
		run_seed = randi()
	map_rng.seed = run_seed
	_build_node_type_plan()
	var viewport_size := get_viewport_rect().size
	var usable_height := viewport_size.y - TOP_MARGIN - BOTTOM_MARGIN

	for layer_index in range(TOTAL_LAYERS):
		var node_count := _node_count_for_layer(layer_index)
		var layer_nodes: Array[RouteNode] = []
		var y := viewport_size.y - BOTTOM_MARGIN - usable_height * layer_index / (TOTAL_LAYERS - 1.0)
		for node_index in range(node_count):
			var route_node := RouteNode.new()
			route_node.z_index = 2
			var node_x := _node_x_position(node_index, node_count, viewport_size.x)
			if node_count > 1:
				node_x += map_rng.randf_range(-NODE_X_JITTER, NODE_X_JITTER)
			route_node.position = Vector2(node_x, y)
			route_node.setup(_node_type_for_layer(layer_index, node_index), layer_index)
			route_node.selected.connect(_on_node_selected)
			$MapContent.add_child(route_node)
			layer_nodes.append(route_node)
		layers.append(layer_nodes)

	_build_connections()
	_draw_connections()
	var restored_layer := mini(saved_layer_index, layers.size() - 1)
	var restored_index := mini(saved_node_index, layers[restored_layer].size() - 1)
	current_node = layers[restored_layer][restored_index]
	_create_player_marker()
	_refresh_node_states()


func _node_count_for_layer(layer_index: int) -> int:
	if layer_index == 0 or layer_index == TOTAL_LAYERS - 1:
		return 1
	return ROUTE_COUNT


func _node_type_for_layer(layer_index: int, node_index: int) -> RouteNode.NodeType:
	if layer_index == 0:
		return RouteNode.NodeType.HOME
	if layer_index == TOTAL_LAYERS - 1:
		return RouteNode.NodeType.BOSS
	return layer_node_types[layer_index][node_index]


func _build_node_type_plan() -> void:
	layer_node_types.clear()
	for layer_index in range(TOTAL_LAYERS):
		var types: Array[RouteNode.NodeType] = []
		var count := _node_count_for_layer(layer_index)
		for node_index in range(count):
			if layer_index == 0:
				types.append(RouteNode.NodeType.HOME)
			elif layer_index == TOTAL_LAYERS - 1:
				types.append(RouteNode.NodeType.BOSS)
			elif layer_index == GUARANTEED_TREASURE_LAYER:
				types.append(RouteNode.NodeType.TREASURE)
			else:
				types.append(RouteNode.NodeType.BATTLE)
		layer_node_types.append(types)

	# 尖塔式短局分布：
	# 1. 第1层必为普通战，让玩家先建立卡组；前3层不出现精英。
	# 2. 显式宝箱只放在固定宝箱层，其他宝箱由“?”事件结果承担。
	# 3. 中后段放2个不相邻层的精英，避免连续精英。
	# 4. 再放5个“?”与5个“奇”。“奇”直接替换普通战，不触发战斗。
	#    40个中间节点最终为23战/5宝/5问号/5奇遇/2精英。
	var elite_layer_pairs := [[4, 6], [4, 7], [5, 7]]
	var elite_layers: Array = elite_layer_pairs[map_rng.randi_range(0, elite_layer_pairs.size() - 1)]
	for layer_index: int in elite_layers:
		var route_index := _pick_column_avoiding_adjacent_type(layer_index, RouteNode.NodeType.ELITE)
		layer_node_types[layer_index][route_index] = RouteNode.NodeType.ELITE

	var unknown_layers := [2, 3, 4, 5, 6, 7]
	_shuffle_with_map_rng(unknown_layers)
	unknown_layers.resize(5)
	unknown_layers.sort()
	for layer_index: int in unknown_layers:
		var route_index := _pick_column_avoiding_adjacent_type(layer_index, RouteNode.NodeType.UNKNOWN)
		layer_node_types[layer_index][route_index] = RouteNode.NodeType.UNKNOWN

	var adventure_layers := [2, 3, 4, 5, 6, 7]
	_shuffle_with_map_rng(adventure_layers)
	adventure_layers.resize(5)
	adventure_layers.sort()
	for layer_index: int in adventure_layers:
		var route_index := _pick_column_avoiding_adjacent_type(layer_index, RouteNode.NodeType.ADVENTURE)
		layer_node_types[layer_index][route_index] = RouteNode.NodeType.ADVENTURE


func _pick_column_avoiding_adjacent_type(layer_index: int, node_type: RouteNode.NodeType) -> int:
	var candidates: Array[int] = []
	for column in range(ROUTE_COUNT):
		if layer_node_types[layer_index][column] != RouteNode.NodeType.BATTLE:
			continue
		var conflicts := false
		for adjacent_layer in [layer_index - 1, layer_index + 1]:
			if adjacent_layer <= 0 or adjacent_layer >= GUARANTEED_TREASURE_LAYER:
				continue
			for adjacent_column in range(maxi(0, column - 1), mini(ROUTE_COUNT, column + 2)):
				if layer_node_types[adjacent_layer][adjacent_column] == node_type:
					conflicts = true
					break
			if conflicts:
				break
		if not conflicts:
			candidates.append(column)
	if candidates.is_empty():
		for column in range(ROUTE_COUNT):
			if layer_node_types[layer_index][column] == RouteNode.NodeType.BATTLE:
				candidates.append(column)
	return candidates[map_rng.randi_range(0, candidates.size() - 1)]


func _shuffle_with_map_rng(array: Array) -> void:
	for index in range(array.size() - 1, 0, -1):
		var swap_index := map_rng.randi_range(0, index)
		var value: Variant = array[index]
		array[index] = array[swap_index]
		array[swap_index] = value


func _node_x_position(index: int, count: int, viewport_width: float) -> float:
	if count == 1:
		return viewport_width * 0.5
	var usable_width := viewport_width - SIDE_MARGIN * 2.0
	return SIDE_MARGIN + usable_width * index / (count - 1.0)


func _build_connections() -> void:
	for layer_index in range(TOTAL_LAYERS - 1):
		var lower_layer: Array = layers[layer_index]
		var upper_layer: Array = layers[layer_index + 1]
		if lower_layer.size() == 1:
			# Home直接展开为五个起点，开局就有足够选择。
			for upper_node: RouteNode in upper_layer:
				_add_connection(lower_layer[0], upper_node)
		elif upper_layer.size() == 1:
			# 所有路线最终都可汇入Boss。
			for lower_node: RouteNode in lower_layer:
				_add_connection(lower_node, upper_layer[0])
		else:
			# 每列保留直行，再为每对相邻列只添加一个方向的斜线。
			# 这样每层都有稳定的分叉/汇流，同时不会出现X形交叉线。
			for route_index in range(ROUTE_COUNT):
				_add_connection(lower_layer[route_index], upper_layer[route_index])
			for gap_index in range(ROUTE_COUNT - 1):
				if map_rng.randf() < 0.5:
					_add_connection(lower_layer[gap_index], upper_layer[gap_index + 1])
				else:
					_add_connection(lower_layer[gap_index + 1], upper_layer[gap_index])


func _add_connection(from_node: RouteNode, to_node: RouteNode) -> void:
	if not connections.has(from_node):
		connections[from_node] = []
	var targets: Array = connections[from_node]
	if not targets.has(to_node):
		targets.append(to_node)


func _draw_connections() -> void:
	for from_node: RouteNode in connections:
		for to_node: RouteNode in connections[from_node]:
			var line := Line2D.new()
			line.z_index = 0
			line.width = 4.0
			line.default_color = Color("#8d785b")
			line.points = PackedVector2Array([from_node.position, to_node.position])
			$MapContent.add_child(line)


func _create_player_marker() -> void:
	player_marker = Sprite2D.new()
	player_marker.z_index = 3
	player_marker.texture = CHIBI_TEXTURE
	player_marker.scale = Vector2(0.075, 0.075)
	$MapContent.add_child(player_marker)
	player_marker.position = _marker_position(current_node)
	var idle_tween := create_tween().set_loops()
	idle_tween.tween_property(player_marker, "scale", Vector2(0.078, 0.078), 0.55)
	idle_tween.tween_property(player_marker, "scale", Vector2(0.075, 0.075), 0.55)


func _marker_position(route_node: RouteNode) -> Vector2:
	return route_node.position + Vector2(80.0, 0.0)


func _on_node_selected(route_node: RouteNode) -> void:
	if not connections.get(current_node, []).has(route_node):
		return
	current_node = route_node
	saved_layer_index = current_node.layer_index
	saved_node_index = layers[saved_layer_index].find(current_node)
	player_marker.position = _marker_position(current_node)
	_refresh_node_states()
	enter_node(current_node.node_type)
func _refresh_node_states() -> void:
	var available_nodes: Array = connections.get(current_node, [])
	for layer: Array in layers:
		for route_node: RouteNode in layer:
			var is_current := route_node == current_node
			route_node.set_map_state(available_nodes.has(route_node), route_node.is_visited or is_current, is_current)


# 后续在这里接入战斗、奖励或随机事件场景。
func enter_node(node_type: RouteNode.NodeType) -> void:
	var names := {
		RouteNode.NodeType.HOME: "Home节点",
		RouteNode.NodeType.BATTLE: "战斗节点",
		RouteNode.NodeType.ELITE: "精英节点",
		RouteNode.NodeType.TREASURE: "宝箱节点",
		RouteNode.NodeType.UNKNOWN: "问号节点",
		RouteNode.NodeType.ADVENTURE: "奇遇节点",
		RouteNode.NodeType.BOSS: "Boss节点",
	}
	print("进入:%s" % names[node_type])
	match node_type:
		RouteNode.NodeType.BATTLE:
			start_battle(RunState.EncounterType.NORMAL)
		RouteNode.NodeType.ELITE:
			start_battle(RunState.EncounterType.ELITE)
		RouteNode.NodeType.BOSS:
			start_battle(RunState.EncounterType.BOSS)
		RouteNode.NodeType.TREASURE:
			start_event(RunState.EventType.TREASURE)
		RouteNode.NodeType.UNKNOWN:
			if randf() < 0.5:
				var encounter := RunState.EncounterType.NORMAL
				if randf() >= 0.7:
					encounter = RunState.EncounterType.ELITE
				start_battle(encounter)
			else:
				start_event(RunState.EventType.UNKNOWN)
		RouteNode.NodeType.ADVENTURE:
			get_tree().change_scene_to_file("res://scenes/adventure.tscn")


# 所有战斗节点共用入口，通过 RunState 把遭遇类型传给战斗场景。
func start_battle(encounter_type: RunState.EncounterType) -> void:
	RunState.pending_encounter = encounter_type
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func start_event(event_type: RunState.EventType) -> void:
	RunState.pending_event = event_type
	get_tree().change_scene_to_file("res://scenes/event.tscn")


func _return_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")
