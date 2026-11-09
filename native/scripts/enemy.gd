class_name DoodleEnemy
extends CharacterBody3D

var game: Node3D
var kind = "grunt"
var stats: Dictionary
var hp = 100.0
var max_hp = 100.0
var model_scale = 1.0
var model: Node3D
var agent: NavigationAgent3D
var alive = true
var cooldown = 1.5
var elapsed = 0.0
var path_timer = 0.0
var spawn_time = 0.7
var boss_phase = 0.0
var laser: MeshInstance3D

func _ready() -> void:
	stats = game.enemy_stats[kind]
	hp = float(stats.hp)
	if stats.get("boss", false):
		hp *= 1.0 + 0.35 * floorf(float(game.wave - 5) / 15.0)
	max_hp = hp
	model_scale = stats.scale
	collision_layer = 4
	collision_mask = 1
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35 * model_scale
	capsule.height = 1.85 * model_scale
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	model = ReferenceAssets.model("enemies", kind)
	add_child(model)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.5
	add_child(agent)
	floor_snap_length = 0.6
	laser = game.make_line(1, 0.012)
	laser.visible = false

func _physics_process(delta: float) -> void:
	if not game.playing or not alive or not game.player.alive:
		return
	elapsed += delta
	spawn_time -= delta
	model.scale = Vector3.ONE * model_scale * clampf(1.0 - spawn_time, 0.05, 1.0)
	if spawn_time > 0:
		return
	cooldown -= delta
	path_timer -= delta
	var target: Vector3 = game.player.global_position
	var offset = target - global_position
	var distance = offset.length()
	var flat = Vector3(offset.x, 0, offset.z)
	if flat.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(flat.x, flat.z), delta * 7)
	var flying: bool = stats.get("flying", false)
	var melee = kind in ["rusher", "bomber", "flyer"]
	var stop = 1.9 if melee else float(stats.get("stop", 8))
	var destination = target
	if flying:
		destination.y += 3.0 + sin(elapsed * 2) * 1.5
		if cooldown < 0.7:
			destination = target + Vector3.UP
		velocity = (destination - global_position).normalized() * float(stats.speed)
	elif not stats.get("stationary", false) and distance > stop:
		if path_timer <= 0:
			path_timer = 0.4
			agent.target_position = target
		var next = agent.get_next_path_position()
		var direction = Vector3(next.x - global_position.x, 0, next.z - global_position.z).normalized()
		velocity.x = direction.x * float(stats.speed)
		velocity.z = direction.z * float(stats.speed)
		if is_on_wall() and is_on_floor():
			velocity.y = 6.5
	else:
		velocity.x = 0
		velocity.z = 0
	if not flying:
		velocity.y -= 26 * delta
	move_and_slide()
	for name in ["legL", "legR", "armL", "armR"]:
		var joint = model.find_child(name, true, false)
		if joint != null:
			joint.rotation.x = sin(elapsed * float(stats.speed) * 1.7 + (0 if name.ends_with("L") else PI)) * 0.45 * minf(1, velocity.length() / 4)
	laser.visible = false
	if melee:
		if distance < (3.4 if kind == "bomber" else 3.0) and cooldown <= 0:
			if kind == "bomber":
				game.explode(global_position + Vector3.UP, 4.2, float(stats.dmg), false)
				take_damage(9999)
			else:
				game.player.take_damage(float(stats.dmg))
				cooldown = 1.2
	elif distance < float(stats.get("range", 32)):
		var from = global_position + Vector3.UP * 1.4 * model_scale
		var toward: Vector3 = game.player.camera.global_position - from
		var query = PhysicsRayQueryParameters3D.create(from, from + toward, 1 | 2, [get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == game.player:
			if kind == "sniper" and cooldown < 1.7:
				laser.visible = true
				game.line_between(laser, from, game.player.camera.global_position)
			if cooldown <= 0:
				var spread = float(stats.get("spread", 0.04))
				var direction = toward.normalized() + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
				game.fire_projectile(from, direction.normalized(), float(stats.get("pspeed", 36)), float(stats.dmg))
				cooldown = randf_range(float(stats.cool[0]), float(stats.cool[1]))
	if stats.get("boss", false):
		boss_phase += delta
		if boss_phase > 5:
			boss_phase = 0
			for i in 12:
				var angle = i * TAU / 12
				game.fire_projectile(global_position + Vector3.UP * 2.0, Vector3(cos(angle), 0, sin(angle)), 22, float(stats.dmg))

func take_damage(amount: float) -> void:
	if not alive:
		return
	if kind == "shield":
		var toward: Vector3 = (game.player.global_position - global_position).normalized()
		if model.global_basis.z.dot(toward) > 0.6:
			amount *= 0.25
	hp -= amount
	if hp <= 0:
		alive = false
		game.enemy_killed(self)
		laser.queue_free()
		queue_free()
