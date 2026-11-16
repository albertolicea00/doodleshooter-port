class_name DoodleHitbox
extends Area3D

var actor: DoodleEnemy
var part = "torso"
var model_scale: float:
	get:
		return actor.model_scale if is_instance_valid(actor) else 1.0

# The model outlives its enemy as a corpse, so the actor may already be gone.
func take_damage(amount: float, point: Vector3 = Vector3.INF) -> void:
	if is_instance_valid(actor):
		actor.take_damage(amount, point)

func yank(from: Vector3) -> void:
	if is_instance_valid(actor):
		actor.yank(from)
