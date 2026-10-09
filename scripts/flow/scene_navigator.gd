extends RefCounted

const Routes = preload("res://scripts/data/scene_routes.gd")

var _pending := false
var last_error: Error = OK

func is_pending() -> bool:
	return _pending


# Owned by RunState; outgoing scenes are only held through weak references.
# Deferring also makes redirects from _ready safe.
func request(tree: SceneTree, destination: String, source: Node) -> Error:
	var path := Routes.resolve(destination)
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion():
		return ERR_UNAVAILABLE
	if tree.current_scene != null and source != tree.current_scene and not tree.current_scene.is_ancestor_of(source):
		return ERR_UNAVAILABLE
	if _pending:
		return ERR_BUSY
	_pending = true
	_dispatch.call_deferred(tree, path, weakref(source))
	return OK


func _dispatch(tree: SceneTree, path: String, source: WeakRef) -> void:
	_pending = false
	var origin = source.get_ref()
	if not is_instance_valid(origin) or not origin.is_inside_tree() or origin.is_queued_for_deletion():
		last_error = ERR_UNAVAILABLE
		return
	# A callback from a replaced scene must not redirect the new scene.
	if tree.current_scene != null and origin != tree.current_scene and not tree.current_scene.is_ancestor_of(origin):
		last_error = ERR_UNAVAILABLE
		return
	last_error = tree.change_scene_to_file(path)
	if last_error != OK:
		push_warning("场景切换失败：%s，错误码：%d" % [path, last_error])
