extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("RunState").suppress_persistence = true
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	assert(map.layers.size() == map.TOTAL_LAYERS)
	assert(map.connections[map.current_node].size() > 0)
	for layer in map.layers:
		for node in layer:
			assert(not node.input_pickable or node.is_selectable and node.visible)
	map._set_map_scroll(99999)
	assert(map.layers[-1][0].visible)
	map._set_map_scroll(0)
	assert(map.layers[0][0].visible)
	var saved_type: int = map.layers[3][1].node_type
	var saved_position: Vector2 = map.layers[3][1].position
	if "--map-screenshot" in OS.get_cmdline_user_args():
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/concepts/map_ui_implemented.png")
	map.free()
	var restored = load("res://scenes/map.tscn").instantiate()
	restored.saved_layer_index = 3
	restored.saved_node_index = 1
	root.add_child(restored)
	assert(restored.current_node.layer_index == 3)
	assert(restored.current_node.node_type == saved_type and restored.current_node.position == saved_position)
	restored.free()
	print("MAP UI: PASS")
	quit()
