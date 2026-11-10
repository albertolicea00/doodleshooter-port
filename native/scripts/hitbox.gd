class_name DoodleHitbox
extends Area3D

var actor: DoodleEnemy
var part = "torso"
var model_scale: float:
	get:
		return actor.model_scale

func take_damage(amount: float, point: Vector3 = Vector3.INF) -> void:
	actor.take_damage(amount, point)

func yank(from: Vector3) -> void:
	actor.yank(from)
