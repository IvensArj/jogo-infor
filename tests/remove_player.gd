extends Node2D


func _ready() -> void:
	$Player.call_deferred("free")
