class_name DoodleArenaBot
extends DoodleRemotePlayer

var match_controller: DoodleBotMatch
var navigation: NavigationAgent3D
var velocity = Vector3.ZERO
var target_actor: Node3D
var think_time = 0.0
var fire_time = 1.0
var path_time = 0.0
var respawn_time = 0.0
var invulnerable = 2.0
var strafe = 1.0

func _ready() -> void:
	super._ready()
	collision_mask = 1 | 16
	model.visible = true
	navigation = NavigationAgent3D.new()
	navigation.path_desired_distance = 0.6
	navigation.target_desired_distance = 1.5
	add_child(navigation)
	strafe = [-1.0, 1.0].pick_random()

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if not game.playing or not match_controller.active:
		return
	invulnerable = maxf(0, invulnerable - delta)
	if not alive:
		respawn_time -= delta
		if respawn_time <= 0:
			match_controller.respawn_bot(self)
		return
	think_time -= delta
	path_time -= delta
	fire_time -= delta
	if think_time <= 0:
		think_time = randf_range(0.4, 0.8)
		target_actor = match_controller.choose_target(self)
	if not is_instance_valid(target_actor) or not target_actor.alive:
		return
	var aim_at = target_actor.global_position + Vector3.UP * 1.3
	var muzzle = global_position + Vector3.UP * 1.4
	var offset = aim_at - muzzle
	var query = PhysicsRayQueryParameters3D.create(muzzle, aim_at, 1 | 2 | 32, [get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	var can_see = not hit.is_empty() and hit.collider == target_actor
	var wish = Vector3.ZERO
	if not can_see or offset.length() > 16:
		if path_time <= 0:
			path_time = 0.6
			navigation.target_position = target_actor.global_position
		wish = navigation.get_next_path_position() - global_position
	else:
		wish = Vector3(-offset.z, 0, offset.x) * strafe
		if offset.length() < 5:
			wish = -offset
	wish.y = 0
	wish = wish.normalized() * 5.5
	velocity.x = move_toward(velocity.x, wish.x, delta * 28)
	velocity.z = move_toward(velocity.z, wish.z, delta * 28)
	velocity.y -= 26 * delta
	# Resolve the bot's motion against map collisions.
	var collision = move_and_collide(velocity * delta)
	if collision != null:
		var normal = collision.get_normal()
		velocity = velocity.slide(normal)
		move_and_collide(collision.get_remainder().slide(normal))
		if normal.y < 0.5:
			velocity.y = 7
	if position.y < -12:
		match_controller.damage(peer_id, 999, peer_id)
	var flat = Vector3(offset.x, 0, offset.z)
	if flat.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(flat.x, flat.z), 1 - exp(-delta * 8))
	phase += delta * Vector2(velocity.x, velocity.z).length() * 2.2
	for name in ["legL", "legR", "armL", "armR"]:
		var limb = model.find_child(name, true, false)
		if limb != null:
			limb.rotation.x = sin(phase + (PI if name.ends_with("L") else 0)) * 0.65
	if can_see and fire_time <= 0 and offset.length() < 55:
		fire_time = [0.48, 0.3, 0.19][match_controller.difficulty]
		var spread = [0.12, 0.065, 0.028][match_controller.difficulty]
		var direction = (offset.normalized() + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
		query = PhysicsRayQueryParameters3D.create(muzzle, muzzle + direction * 70, 1 | 2 | 32, [get_rid()])
		hit = get_world_3d().direct_space_state.intersect_ray(query)
		var end = muzzle + direction * 70 if hit.is_empty() else hit.position
		game.tracer(muzzle, end, 1)
		game.sound.play_effect("enemyShot", muzzle)
		if not hit.is_empty():
			if hit.collider == game.player:
				var deflection = game.player.try_deflect(direction)
				if deflection == 2:
					match_controller.damage(peer_id, 90, "player")
				elif deflection == 0:
					match_controller.damage("player", 19, peer_id)
			elif hit.collider is DoodleArenaBot:
				match_controller.damage(hit.collider.peer_id, 19, peer_id)

func take_damage(amount: float, _point: Vector3 = Vector3.INF) -> void:
	match_controller.damage(peer_id, amount, "player")

func yank(from: Vector3) -> void:
	velocity = (from - global_position).normalized() * 12 + Vector3.UP * 5
	fire_time = 1.2
