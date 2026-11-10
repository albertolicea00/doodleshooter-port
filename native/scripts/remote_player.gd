class_name DoodleRemotePlayer
extends StaticBody3D

var game: Node3D
var peer_id = ""
var model_scale = 1.0
var alive = true
var model: Node3D
var rope: MeshInstance3D
var target = Vector3.ZERO
var target_yaw = 0.0
var hp = 120.0
var phase = 0.0
var shield = 0.0

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	set_meta("remote", true)
	model = ReferenceAssets.model("enemies", "grunt")
	model.visible = false
	add_child(model)
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	rope = game.make_line(0, 0.015)
	rope.visible = false

func update_state(state: Dictionary) -> void:
	target = ReferenceAssets.vector(state.position)
	target_yaw = float(state.rotation[1])
	hp = float(state.hp)
	alive = state.alive
	collision_layer = 32 if alive else 0
	model.visible = alive
	if global_position == Vector3.ZERO:
		global_position = target
	rope.visible = bool(state.grappling) and alive
	if rope.visible:
		game.line_between(rope, global_position + Vector3.UP, ReferenceAssets.vector(state.grapple))

func _process(delta: float) -> void:
	global_position = global_position.lerp(target, 1 - exp(-delta * 18))
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw + PI, 1 - exp(-delta * 16))
	phase += delta * 12
	for name in ["legL", "legR"]:
		var limb = model.find_child(name, true, false)
		if limb != null:
			limb.rotation.x = sin(phase + (PI if name.ends_with("L") else 0)) * minf(0.7, global_position.distance_to(target))

func take_damage(amount: float, _point: Vector3 = Vector3.INF) -> void:
	if alive:
		game.network.send_packet({"type": "damage", "target": peer_id, "amount": amount, "source": game.player.last_attack})

func yank(_from: Vector3) -> void:
	pass

func _exit_tree() -> void:
	if is_instance_valid(rope):
		rope.queue_free()
