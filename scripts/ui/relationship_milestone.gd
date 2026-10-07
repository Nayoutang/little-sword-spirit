extends Node2D

# 兼容旧入口：关系已由共同经历自然推进，不再打开突破问答。
func _ready() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/home.tscn")
