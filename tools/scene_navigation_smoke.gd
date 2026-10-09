extends SceneTree

const Navigator = preload("res://scripts/flow/scene_navigator.gd")
const Routes = preload("res://scripts/data/scene_routes.gd")

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	var state = root.get_node("RunState")
	state.suppress_persistence = true
	state.intro_done = true
	state.start_new_run()
	for path in Routes.PATHS.values():
		assert(ResourceLoader.exists(path))
	assert(Routes.resolve("res://scenes/map.tscn") == Routes.resolve("map"))
	var navigator = Navigator.new()
	var source := Node2D.new()
	root.add_child(source)
	current_scene = source
	assert(navigator.request(self, "missing", source) == ERR_INVALID_PARAMETER)
	assert(navigator.request(self, "save_select", source) == OK)
	assert(navigator.request(self, "map", source) == ERR_BUSY)
	await scene_changed
	assert(current_scene.scene_file_path == Routes.resolve("save_select"))
	await process_frame
	assert(not is_instance_valid(source))
	# A cancelled deferred request neither changes scenes nor leaves the lock held.
	var cancelled := Node.new()
	current_scene.add_child(cancelled)
	assert(navigator.request(self, "map", cancelled) == OK)
	cancelled.queue_free()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == Routes.resolve("save_select"))
	assert(navigator.last_error == ERR_UNAVAILABLE)
	# A still-live node outside the current scene is an obsolete callback source.
	var stale := Node.new()
	root.add_child(stale)
	assert(navigator.request(self, "map", stale) == ERR_UNAVAILABLE)
	stale.queue_free()
	for cycle in range(5):
		assert(navigator.request(self, "map", current_scene) == OK)
		await scene_changed
		assert(current_scene.scene_file_path == Routes.resolve("map"))
		var previous: WeakRef = weakref(current_scene)
		var nested := Node.new()
		current_scene.add_child(nested)
		assert(navigator.request(self, "save_select", nested) == OK)
		await scene_changed
		await process_frame
		assert(previous.get_ref() == null)
		assert(current_scene.scene_file_path == Routes.resolve("save_select"))
	# Promise redirects from _ready when no concern exists.
	state.pending_concern.clear()
	assert(state.navigate("promise", current_scene) == OK)
	for frame in range(6):
		await process_frame
	assert(current_scene.scene_file_path == Routes.resolve("map"))
	# Competing map clicks must not alter the already-selected room checkpoint.
	var map = current_scene
	var target = map.connections[map.current_node][0]
	map._on_node_selected(target)
	var selected_layer: int = state.map_layer
	var selected_seed: int = state.battle_seed
	assert(state.is_scene_transition_pending())
	assert(state.expedition_checkpoint.phase == "battle")
	map._return_home()
	map._on_node_selected(map.connections[map.current_node][0])
	assert(state.map_layer == selected_layer and state.battle_seed == selected_seed)
	assert(state.expedition_checkpoint.phase == "battle")
	map.queue_free()
	await process_frame
	await process_frame
	print("SCENE NAVIGATION: PASS (duplicates, cancelled/stale callbacks, 5 loops, ready redirect)")
	quit(0)
