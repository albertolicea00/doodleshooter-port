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
var laser: MeshInstance3D
var stun = 0.0
var fuse = -1.0
var aim_time = 0.0
var aim_point = Vector3.ZERO
var burst_left = 0
var burst_timer = 0.0
var strafe = 1.0
var attack = ""
var attack_time = 0.0
var attack_done = false
var attack_direction = Vector3.ZERO
var attacks = 0
var shots = 0
var hop_time = 1.0
var hopping = false
var fly_state = "orbit"
var fly_time = 1.0
var target_los = false

func _ready() -> void:
	stats = game.enemy_stats[kind]
	hp = float(stats.hp)
	if stats.get("boss", false):
		hp *= 1.0 + 0.35 * maxf(0, floorf(float(game.wave - 5) / 15.0))
	elif game.swarm:
		hp *= 0.65
	max_hp = hp
	model_scale = stats.scale
	collision_layer = 0
	collision_mask = 1 | 16
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35 * model_scale
	capsule.height = 1.85 * model_scale
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	model = ReferenceAssets.model("enemies", kind)
	add_child(model)
	var model_data: Dictionary = ReferenceAssets.read_json("enemies")[kind]
	for hit in model_data.get("hit_spheres", []):
		var marker = model.find_child("hit_" + str(hit[0]), true, false)
		if marker == null:
			continue
		var hitbox = DoodleHitbox.new()
		hitbox.actor = self
		hitbox.part = hit[0]
		hitbox.collision_layer = 4
		hitbox.collision_mask = 0
		hitbox.set_meta("part", hit[0])
		var sphere = SphereShape3D.new()
		sphere.radius = float(hit[1])
		var bound = CollisionShape3D.new()
		bound.shape = sphere
		hitbox.add_child(bound)
		marker.add_child(hitbox)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 1.5
	add_child(agent)
	floor_snap_length = 0.6
	laser = game.make_line(1, 0.012)
	laser.visible = false
	strafe = [-1.0, 1.0].pick_random()
	game.sound.play_effect("spawn", position)

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
	stun -= delta
	var target: Vector3 = game.player.global_position
	var offset = target - global_position
	var distance = offset.length()
	var center = global_position + Vector3.UP * 1.3 * model_scale
	var query = PhysicsRayQueryParameters3D.create(center, game.player.camera.global_position, 1 | 2, [get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	target_los = not hit.is_empty() and hit.collider == game.player
	var flat = Vector3(offset.x, 0, offset.z)
	if flat.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(flat.x, flat.z), 1 - exp(-delta * 7))
	laser.visible = false
	if stun > 0:
		velocity.x = move_toward(velocity.x, 0, delta * 8)
		velocity.z = move_toward(velocity.z, 0, delta * 8)
	elif stats.get("flying", false):
		think_flyer(delta, target)
	elif stats.get("boss", false):
		think_boss(delta, target, distance)
	elif kind == "bomber":
		if fuse < 0 and distance < 3.4 and target_los:
			fuse = 1.05
			game.sound.play_effect("fuse", center)
		if fuse >= 0:
			fuse -= delta
			velocity.x = 0
			velocity.z = 0
			model.rotation.z = sin(elapsed * 35) * 0.1
			if fuse <= 0:
				game.explode(center, 4.2, 24 * game.damage_modifier, false)
				take_damage(9999)
		else:
			follow(target, delta)
	elif kind == "rusher":
		think_rusher(delta, target, distance)
	else:
		think_gun(delta, target, distance)
	if not stats.get("flying", false):
		velocity.y -= 26 * delta
		step_up(delta)
	move_and_slide()
	animate(delta)

func follow(target: Vector3, delta: float, speed_factor: float = 1.0) -> void:
	if path_timer <= 0:
		path_timer = randf_range(0.6, 1.0)
		agent.target_position = target
	var next = agent.get_next_path_position()
	var direction = Vector3(next.x - global_position.x, 0, next.z - global_position.z).normalized()
	var speed = float(stats.speed) * game.speed_modifier * speed_factor
	velocity.x = move_toward(velocity.x, direction.x * speed, 30 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 30 * delta)
	if is_on_wall() and is_on_floor():
		velocity.y = 7
	for other in game.enemies:
		if other == self or not other.alive:
			continue
		var away = global_position - other.global_position
		away.y = 0
		if away.length() > 0.01 and away.length() < 1.45:
			velocity += away.normalized() * delta * 12

func step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion = Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() > 0.001 and test_move(global_transform, motion) and not test_move(global_transform, Vector3.UP * 0.55):
		if not test_move(global_transform.translated(Vector3.UP * 0.55), motion):
			global_position.y += 0.55

func think_rusher(delta: float, target: Vector3, distance: float) -> void:
	if attack == "slash":
		attack_time += delta
		if attack_time > 0.37 and not attack_done:
			attack_done = true
			if distance < 3.0 and target_los:
				if game.player.try_block_melee(global_position + Vector3.UP):
					yank(game.player.position)
				else:
					game.player.take_damage(15 * game.damage_modifier)
		if attack_time > 0.55:
			attack = ""
			cooldown = randf_range(1.0, 1.5)
	elif target_los and distance < 2.9 and cooldown <= 0:
		begin_attack("slash")
		var direction = (target - global_position).normalized()
		velocity += direction * 10
		game.sound.play_effect("lunge", global_position)
	else:
		follow(target, delta)

func think_gun(delta: float, target: Vector3, distance: float) -> void:
	var stop = float(stats.get("stop", 8))
	if not target_los or distance > stop or absf(target.y - global_position.y) > 1.2:
		follow(target, delta, 0.85)
	else:
		var direction = (target - global_position).normalized()
		var side = Vector3(-direction.z, 0, direction.x) * strafe
		if distance < float(stats.get("keep", 4)):
			side = -direction
		var speed = float(stats.speed) * 0.5 * game.speed_modifier
		velocity.x = move_toward(velocity.x, side.x * speed, 30 * delta)
		velocity.z = move_toward(velocity.z, side.z * speed, 30 * delta)
		if int(elapsed * 0.5) != int((elapsed - delta) * 0.5):
			strafe *= -1
	if stats.get("stationary", false) and (target_los or elapsed < 5):
		velocity.x = 0
		velocity.z = 0
	if not target_los or distance > float(stats.range):
		aim_time = 0
		burst_left = 0
		return
	var muzzle = global_position + Vector3.UP * 1.45 * model_scale
	var point: Vector3 = game.player.camera.global_position
	if kind == "sniper":
		if cooldown > 0:
			return
		if aim_time <= 0:
			aim_point = point
		aim_time += delta
		aim_point = aim_point.lerp(point, 1 - exp(-delta * 2.6))
		laser.visible = true
		var end = aim_point - (aim_point - muzzle).normalized() * 1.6
		game.line_between(laser, muzzle, end)
		if aim_time >= 1.7:
			shoot(muzzle, aim_point, float(stats.spread), 95, 22)
			game.sound.play_effect("sniperShot", muzzle)
			aim_time = 0
			cooldown = randf_range(2.8, 3.8)
		return
	if kind == "heavy":
		if cooldown <= 0:
			for i in 7:
				shoot(muzzle, point, 0.13, randf_range(27, 35), 5)
			cooldown = randf_range(2.4, 3.2)
			game.sound.play_effect("shotgun", muzzle)
		return
	if burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0:
			shoot(muzzle, point, float(stats.spread), float(stats.pspeed), float(stats.dmg))
			burst_left -= 1
			burst_timer = float(stats.burstInt)
			game.sound.play_effect("enemyShot", muzzle)
			if burst_left == 0:
				cooldown = randf_range(float(stats.cool[0]), float(stats.cool[1]))
	elif cooldown <= 0:
		burst_left = int(stats.burst)
		burst_timer = 0

func shoot(from: Vector3, to: Vector3, spread: float, speed: float, damage: float, blast: float = 0) -> void:
	var direction = (to - from).normalized()
	var bloom = spread * (1 + game.player.velocity.length() * 0.06)
	direction += Vector3(randf_range(-bloom, bloom), randf_range(-bloom, bloom), randf_range(-bloom, bloom))
	game.fire_projectile(from, direction.normalized(), speed, damage * game.damage_modifier, false, blast)

func begin_attack(name: String) -> void:
	attack = name
	attack_time = 0
	attack_done = false
	shots = 0

func think_boss(delta: float, target: Vector3, distance: float) -> void:
	var center = global_position + Vector3.UP * 2.0
	if not attack.is_empty():
		attack_time += delta
		velocity.x = move_toward(velocity.x, 0, delta * 12)
		velocity.z = move_toward(velocity.z, 0, delta * 12)
		if attack == "charge":
			if attack_time < 0.7:
				attack_direction = (target - global_position).normalized()
				attack_direction.y = 0
			elif attack_time < 1.9:
				velocity = attack_direction * 17 * game.speed_modifier
				if distance < 2.6 and absf(target.y - global_position.y) < 3 and not attack_done:
					attack_done = true
					game.player.take_damage(26 * game.damage_modifier)
					game.player.velocity += attack_direction * 13 + Vector3.UP * 3
				if is_on_wall():
					attack_time = 1.9
					game.burst(center, 5, 30)
			if attack_time > 2.7:
				end_attack()
		elif attack in ["stomp", "rub"]:
			if attack_time > (0.9 if attack == "rub" else 0.75) and not attack_done:
				attack_done = true
				var radius = 6.5 if attack == "rub" else 7.5
				var damage = float(stats.dmg) * (0.8 if attack == "rub" else 1.0) * game.damage_modifier
				game.burst(global_position, 5 if kind == "eraser" else 2, 40)
				game.sound.play_effect("stomp", center)
				game.shake = 0.9
				if distance < radius and target.y < global_position.y + 2.5:
					game.player.take_damage(damage)
					game.player.velocity += (target - global_position).normalized() * 9 + Vector3.UP * 4
				if attack == "rub":
					summon("bomber", 2, 4)
			if attack_time > (1.6 if attack == "rub" else 1.3):
				end_attack()
		elif attack == "throw":
			if attack_time > 0.6 and not attack_done:
				attack_done = true
				var point = game.player.camera.global_position + Vector3.UP * distance * 0.012
				shoot(center + Vector3.UP * 2, point, 0, 24, float(stats.dmg) * 0.9, 1.0)
			if attack_time > 1.0:
				end_attack()
		elif attack == "spray":
			if attack_time > 0.6 + shots * 0.09 and shots < 9:
				var angle = atan2(target.x - position.x, target.z - position.z) + (shots - 4) * 0.19
				game.fire_projectile(center, Vector3(sin(angle), 0.18, cos(angle)).normalized(), 20, float(stats.dmg) * 0.55 * game.damage_modifier, false, 1.0)
				shots += 1
			if attack_time > 1.8:
				end_attack()
		elif attack == "summon":
			if attack_time > 0.8 and not attack_done:
				attack_done = true
				summon("flyer", 3, 6)
				game.sound.play_effect("bossRoar", center)
			if attack_time > 1.4:
				end_attack()
		return
	if kind == "inkblot":
		hop_time -= delta
		if is_on_floor() and hopping:
			hopping = false
			game.blood_pool(position, 3.5, 2)
			game.sound.play_effect("stomp", center)
			if distance < 4.5 and absf(target.y - position.y) < 2.5:
				game.player.take_damage(float(stats.dmg) * 0.7 * game.damage_modifier)
		if is_on_floor() and hop_time <= 0 and distance > 4:
			hop_time = randf_range(1.6, 2.4)
			velocity = (target - position).normalized() * 11
			velocity.y = 13
			hopping = true
		if cooldown <= 0 and target_los:
			begin_attack("summon" if attacks % 3 == 2 else "spray")
	elif kind == "eraser":
		if cooldown <= 0 and target_los and distance < float(stats.range):
			begin_attack("rub" if attacks % 3 == 2 and distance < 12 else "charge")
		else:
			follow(target, delta)
	else:
		if cooldown <= 0 and target_los and distance < float(stats.range):
			begin_attack("stomp" if distance < 7 and absf(target.y - position.y) < 3 else "throw")
		else:
			follow(target, delta)

func end_attack() -> void:
	attack = ""
	attacks += 1
	cooldown = randf_range(float(stats.cool[0]), float(stats.cool[1]))

func summon(type: String, count: int, limit: int) -> void:
	var live = 0
	for enemy in game.enemies:
		if enemy.kind == type:
			live += 1
	for i in mini(count, limit - live):
		var enemy = game.spawn_enemy(type)
		var angle = randf() * TAU
		enemy.position = position + Vector3(cos(angle) * 3, 2.0 + i if type == "flyer" else 0.2, sin(angle) * 3)

func think_flyer(delta: float, target: Vector3) -> void:
	fly_time -= delta
	var destination = target + Vector3.UP * 7
	var speed = float(stats.speed)
	if fly_state == "orbit":
		var angle = atan2(position.x - target.x, position.z - target.z) + strafe * 0.45
		destination = target + Vector3(sin(angle) * 11, 6 + sin(elapsed * 1.3) * 1.5, cos(angle) * 11)
		if cooldown <= 0 and target_los:
			fly_state = "dive"
			fly_time = 1.6
			game.sound.play_effect("flyerDive", position)
	elif fly_state == "dive":
		destination = game.player.camera.global_position
		speed = 16
		if destination.distance_to(global_position) < 1.4:
			if game.player.try_block_melee(global_position):
				yank(game.player.position)
			else:
				game.player.take_damage(10 * game.damage_modifier)
			fly_time = 0
		if fly_time <= 0 or is_on_wall():
			fly_state = "climb"
			fly_time = 1.1
			cooldown = randf_range(2.8, 4.2)
	elif fly_time <= 0:
		fly_state = "orbit"
	velocity = velocity.move_toward((destination - global_position).normalized() * speed * game.speed_modifier, delta * 22)
	if is_on_wall() or is_on_floor():
		velocity.y += delta * 12

func animate(delta: float) -> void:
	var speed = Vector2(velocity.x, velocity.z).length()
	var phase = elapsed * (speed * 2.2 + 3)
	var walking = clampf(speed / 4, 0, 1)
	for name in ["legL", "legR", "armL", "armR"]:
		var joint = model.find_child(name, true, false)
		if joint == null:
			continue
		joint.rotation.x = sin(phase + (0 if name.ends_with("L") else PI)) * 0.9 * walking
		if name.begins_with("arm") and target_los and kind not in ["bomber", "rusher", "flyer"]:
			joint.rotation.x = lerpf(joint.rotation.x, -1.35, minf(1, delta * 12))
	for name in ["wl", "wr"]:
		var wing = model.find_child(name, true, false)
		if wing != null:
			wing.rotation.z = sin(elapsed * 14) * 0.35 * (1 if name == "wl" else -1)

func yank(from: Vector3) -> void:
	stun = 1.2
	velocity = (from - global_position).normalized() * 12 + Vector3.UP * 5
	game.sound.play_effect("grappleHit", position)

func take_damage(amount: float, point: Vector3 = Vector3.INF) -> void:
	if not alive:
		return
	if kind == "shield":
		var toward: Vector3 = (game.player.global_position - global_position).normalized()
		if model.global_basis.z.dot(toward) > 0.6 and (not point.is_finite() or point.y < global_position.y + 1.5 * model_scale):
			amount *= 0.2
			game.sound.play_effect("shieldHit", global_position)
	hp -= amount
	if hp <= 0:
		alive = false
		game.enemy_killed(self)
		laser.queue_free()
		game.sound.play_effect("enemyDie", global_position)
		var corpse = model
		# A corpse must not stop bullets, grapples or auto fire.
		for hitbox in corpse.find_children("*", "Area3D", true, false):
			hitbox.collision_layer = 0
		corpse.reparent(game)
		var tween = corpse.create_tween()
		tween.tween_property(corpse, "rotation:x", PI * 0.5, 0.45)
		game.effects.append({"node": corpse, "life": 9.0})
		queue_free()
