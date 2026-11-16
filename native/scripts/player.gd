class_name DoodlePlayer
extends CharacterBody3D

var game: Node3D
var camera: Camera3D
var rig: Node3D
var capsule: CollisionShape3D
var hp = 120.0
var alive = true
var jumps = 1
var coyote = 0.0
var dash_cd = 0.0
var slide_time = 0.0
var grapple_active = false
var grapple_anchor = Vector3.ZERO
var grapple_body: Node3D
var grapple_offset = Vector3.ZERO
var stamina = 1.0
var rope: MeshInstance3D
var weapons: Dictionary
# Katana keeps slot 3; the revolver (in the original source but not its loadout) and the SMG (port addition) follow.
var weapon_names = ["rifle", "shotgun", "sniper", "katana", "revolver", "smg", "bazooka"]
var weapon_index = 0
var magazines = [35, 6, 5, 0, 6, 30, 1]
var reserves = [175, 36, 25, 0, 36, 180, 6]
var fire_cd = 0.0
var reload_time = 0.0
var last_hurt = 10.0
var grenades = 3
var smokes = 2
var katana_charge = 0.0
var recoil = 0.0
var bob = 0.0
var aiming = false
var throw_charge = 0.0
var charging = false
var models: Array[Node3D] = []
# Named parts of each weapon model and their rest transforms.
var parts: Array[Dictionary] = []
var racked = false
var jump_buffer = 0.0
var mantle_cd = 0.0
var stamina_pause = 0.0
var grapple_length = 0.0
var grapple_flight = 0.0
var grapple_duration = 0.0
var grapple_origin = Vector3.ZERO
var grapple_hook = Vector3.ZERO
var grapple_blocked = 0.0
var grapple_age = 0.0
var cycle_time = 0.0
var slash_time = 0.0
var slash_combo = 0
var combo_time = 0.0
var block_time = 0.0
var block_cd = 0.0
var previous_block = false
var previous_ground = false
var step_distance = 0.0
var last_attack = "rifle"
var blood_level = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 16
	floor_snap_length = 0.55
	capsule = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.75
	capsule.shape = shape
	capsule.position.y = 0.875
	add_child(capsule)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 82
	camera.near = 0.04
	add_child(camera)
	var post = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2, 2)
	post.mesh = quad
	post.extra_cull_margin = 16384
	post.position.z = -1
	var post_material = ShaderMaterial.new()
	post_material.shader = preload("res://shaders/outline.gdshader")
	post.material_override = post_material
	camera.add_child(post)
	rig = Node3D.new()
	camera.add_child(rig)
	weapons = ReferenceAssets.read_json("weapons")
	for key in weapon_names:
		var model = ReferenceAssets.model("weapons", key)
		rig.add_child(model)
		model.position = ReferenceAssets.vector(weapons[key].position)
		model.rotation_order = EULER_ORDER_XYZ
		models.append(model)
		var found = {}
		for part in ["muzzle", "mag", "fore_end", "bolt", "hand_left", "cylinder"]:
			var node = model.find_child(part, true, false)
			if node != null:
				found[part] = node
				found[part + "_rest"] = node.position
		parts.append(found)
	rope = MeshInstance3D.new()
	var rope_mesh = CylinderMesh.new()
	rope_mesh.top_radius = 0.018
	rope_mesh.bottom_radius = 0.018
	rope_mesh.height = 1.0
	rope.mesh = rope_mesh
	rope.material_override = ReferenceAssets.material(0, true)
	game.add_child(rope)
	switch_weapon(0)

func _unhandled_input(event: InputEvent) -> void:
	if not game.playing or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative * 0.0024)
	if event.is_action_pressed("next_weapon"):
		switch_weapon((weapon_index + 1) % weapon_names.size())
	for i in weapon_names.size():
		if event.is_action_pressed("weapon_" + str(i)):
			switch_weapon(i)

func look(amount: Vector2) -> void:
	rotate_y(-amount.x)
	camera.rotation.x = clampf(camera.rotation.x - amount.y, -1.48, 1.48)

func switch_weapon(index: int) -> void:
	weapon_index = index
	cycle_time = 0
	if game.sound != null:
		game.sound.play_effect("switchWeapon")
	reload_time = 0.0
	for i in models.size():
		models[i].visible = i == index

func ray(distance: float, direction: Vector3 = Vector3.ZERO, skip: Array[RID] = [], grappling: bool = false) -> Dictionary:
	var origin = camera.global_position
	var target = origin + (-camera.global_basis.z if direction == Vector3.ZERO else direction) * distance
	var excluded: Array[RID] = [get_rid()]
	excluded.append_array(skip)
	for i in 20:
		var query = PhysicsRayQueryParameters3D.create(origin, target, 1 | 4 | 16 | 32, excluded)
		query.collide_with_areas = true
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return hit
		if hit.collider.get_meta("no_grapple" if grappling else "no_shoot", false):
			excluded.append(hit.rid)
		else:
			return hit
	return {}

func _physics_process(delta: float) -> void:
	if not game.playing or not alive:
		return
	var control = Input.get_vector("left", "right", "forward", "back")
	if game.touch != null:
		control += game.touch.move_vector
	control = control.limit_length()
	var stick = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		look(stick * delta * 2.5)
	aiming = Input.is_action_pressed("aim")
	var wish = global_basis * Vector3(control.x, 0, control.y)
	var speed = 10.6 if Input.is_action_pressed("sprint") or (game.touch != null and game.touch.sprinting) else 6.6
	if aiming:
		speed = 4.2
	fire_cd -= delta
	dash_cd -= delta
	mantle_cd -= delta
	cycle_time -= delta
	block_cd -= delta
	slash_time = maxf(0, slash_time - delta)
	combo_time -= delta
	if combo_time <= 0:
		slash_combo = 0
	var blocking = is_blocking()
	block_time = block_time + delta if blocking and previous_block else 0.0
	previous_block = blocking
	stamina_pause -= delta
	slide_time -= delta
	last_hurt += delta
	if last_hurt > 4.5 and hp < 120.0 and speed < 10.0:
		hp = minf(120.0, hp + 11.0 * delta)
	if is_on_floor():
		jumps = 1
		coyote = 0.13
		if not grapple_active and stamina_pause <= 0:
			stamina = minf(1.0, stamina + 0.4 * delta)
	else:
		coyote -= delta
		velocity.y -= 26.0 * (0.88 if grapple_active else 1.0) * delta
		if not grapple_active and stamina_pause <= 0:
			stamina = minf(1.0, stamina + 0.2 * delta)
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	if slide_time <= 0:
		if is_on_floor():
			horizontal *= maxf(0, 1 - 8.0 * delta)
		if wish.length() > 0:
			var direction = wish.normalized()
			var cap = speed if is_on_floor() else 7.5
			var add = minf(cap * control.length() - horizontal.dot(direction), (140.0 if is_on_floor() else 36.0) * delta)
			if add > 0:
				horizontal += direction * add
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, 6.5 * delta)
		horizontal += wish * 6.0 * delta
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	jump_buffer = 0.15 if Input.is_action_just_pressed("jump") else jump_buffer - delta
	if jump_buffer > 0:
		if grapple_active:
			detach_grapple(true)
			jump_buffer = 0
		elif is_on_floor() or coyote > 0:
			velocity.y = 9.6
			coyote = 0
			jump_buffer = 0
			slide_time = 0
			game.sound.play_effect("jump")
		elif is_on_wall():
			velocity += get_wall_normal() * 7.5
			velocity.y = 9.2
			jumps = 1
			jump_buffer = 0
			game.sound.play_effect("wallJump")
		elif jumps > 0:
			velocity.y = 9.6 * 0.92
			jumps -= 1
			jump_buffer = 0
			game.sound.play_effect("jump")
	if Input.is_action_just_pressed("dash") and dash_cd <= 0:
		var direction = wish.normalized() if wish.length() > 0.1 else -global_basis.z
		if is_on_floor():
			if horizontal.length() > 4.0:
				velocity += direction * clampf(12.8 - horizontal.length(), 0, 4.5)
				slide_time = 0.9
				game.sound.play_effect("slide")
		else:
			dash_cd = 1.3
			var along = velocity.dot(direction)
			velocity += direction * (maxf(along + 6.0, 14.0) - along)
			velocity.y = maxf(velocity.y, 2.0)
			game.sound.play_effect("dash")
	var crouched = slide_time > 0 and is_on_floor()
	if not crouched and capsule.shape.height < 1.75:
		var check = PhysicsShapeQueryParameters3D.new()
		var full = CapsuleShape3D.new()
		full.radius = 0.35
		full.height = 1.75
		check.shape = full
		check.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.875)
		check.collision_mask = 1
		crouched = not get_world_3d().direct_space_state.intersect_shape(check, 1).is_empty()
	capsule.shape.height = 1.05 if crouched else 1.75
	capsule.position.y = capsule.shape.height * 0.5
	camera.position.y = move_toward(camera.position.y, 0.88 if crouched else 1.6, delta * 7)
	update_grapple(delta, control)
	if not is_on_floor() and control.y < -0.3 and mantle_cd <= 0 and not grapple_active:
		try_mantle()
	velocity = velocity.limit_length(48.0)
	if is_on_floor():
		step_up(delta)
	var landing_speed = velocity.y
	move_and_slide()
	if is_on_floor() and not previous_ground:
		game.sound.play_effect("land")
		game.shake = minf(1.0, absf(landing_speed) / 30.0)
	previous_ground = is_on_floor()
	step_distance += Vector2(velocity.x, velocity.z).length() * delta
	if is_on_floor() and step_distance > 2.0:
		step_distance = 0
		game.sound.play_effect("footstep")
	if position.y < -12.0:
		position = game.level.start + Vector3.UP * 0.1
		velocity = Vector3.ZERO
		if game.match_mode == "bots":
			game.bot_match.damage("player", 20, "player")
		else:
			take_damage(20)
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			if weapon_index == 1:
				magazines[1] += 1
				reserves[1] -= 1
				if magazines[1] < 6 and reserves[1] > 0:
					reload_time = 0.45
					game.sound.play_effect("shell")
			else:
				var count = mini(int(weapons[weapon_names[weapon_index]].magazine) - magazines[weapon_index], reserves[weapon_index])
				magazines[weapon_index] += count
				reserves[weapon_index] -= count
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_pressed("fire") and fire_cd <= 0:
		if weapon_index in [0, 3, 5] or Input.is_action_just_pressed("fire"):
			fire()
	if Input.is_action_just_pressed("slash"):
		slash()
	if Input.is_action_just_pressed("smoke") and smokes > 0:
		smokes -= 1
		game.throw_grenade(camera.global_position, -camera.global_basis.z * 16.0 + Vector3.UP * 4.5, true, true)
	if Input.is_action_just_pressed("grenade") and grenades > 0:
		charging = true
		throw_charge = 0
	if charging:
		game.preview_grenade(camera.global_position, -camera.global_basis.z * lerpf(10, 29, throw_charge) + Vector3.UP * lerpf(2.8, 7.0, throw_charge))
		throw_charge = minf(1.0, throw_charge + delta)
		if Input.is_action_just_released("grenade"):
			charging = false
			grenades -= 1
			game.throw_grenade(camera.global_position, -camera.global_basis.z * lerpf(10, 29, throw_charge) + Vector3.UP * lerpf(2.8, 7.0, throw_charge))
			game.trajectory.clear()
	bob += delta * Vector2(velocity.x, velocity.z).length() * 1.4
	recoil = move_toward(recoil, 0, delta * 0.5)
	var key: String = weapon_names[weapon_index]
	camera.fov = lerpf(camera.fov, float(weapons[key].fov) if aiming else (82.0 + clampf((velocity.length() - 7.0) / 16.0, 0, 1) * 8.0 + (3.0 if speed > 10.0 else 0.0)), 1.0 - exp(-delta * 12.0))
	var base = ReferenceAssets.vector(weapons[key].aim_position if aiming else weapons[key].position)
	var offset = Vector3(sin(bob) * 0.003, absf(cos(bob)) * 0.003, recoil)
	var pose = Vector3.ZERO
	if weapon_index == 3:
		pose = Vector3(1.4, 0.3, 1.24) if is_blocking() else Vector3(0.75, 0.15, -0.35)
		if slash_time > 0:
			var progress = smoothstep(0, 1, 1.0 - slash_time / 0.27)
			var side = 1.0 if slash_combo % 2 == 1 else -1.0
			pose += Vector3(0.7 - 1.5 * progress, side * (-0.35 + 0.8 * progress), side * (1.3 - 2.7 * progress))
	else:
		# Reload and cycling follow the original weapons.js motion.
		var part: Dictionary = parts[weapon_index]
		var duration = float(weapons[key].reload)
		var t = clampf(1.0 - reload_time / duration, 0, 1) if reload_time > 0 else 0.0
		var hand = Vector3.ZERO
		var drop = 0.0
		if reload_time > 0 and weapon_index == 1:
			# Shells go in one at a time: the left hand feeds each one.
			var s = sin(t * PI)
			pose += Vector3(0.15, 0, 0.35) * s
			offset.y -= 0.04 * s
			hand = Vector3(0.1, -0.12, 0.55) * s
		elif reload_time > 0 and weapon_index == 4:
			# Revolver: swing the cylinder out, then snap it shut.
			var open = 1.0 - pow(1.0 - t / 0.25, 2) if t < 0.25 else (pow(1.0 - (t - 0.8) / 0.2, 2) if t > 0.8 else 1.0)
			pose += Vector3(0.3, 0, 0.9) * open
			offset += Vector3(-0.05, 0.02, 0) * open
			part.cylinder.rotation.z = -1.5 * open
		elif reload_time > 0:
			# Magazine: tilt the gun over, drop the magazine and swing it back, then rack.
			var tilt = sin(clampf(t / 0.22, 0, 1) * PI * 0.5) * (1.0 if t < 0.82 else clampf(1.0 - (t - 0.82) / 0.18, 0, 1))
			pose += Vector3(-0.3, 0.25, 0.5) * tilt
			offset += Vector3(0.03, -0.07, 0) * tilt
			drop = sin(clampf((t - 0.18) / 0.5, 0, 1) * PI)
			hand = Vector3(0.04, -0.2, 0.3) * drop
			if t > 0.86 and not racked:
				racked = true
				recoil = 0.05
		else:
			racked = false
		if part.has("cylinder") and reload_time <= 0:
			part.cylinder.rotation.z = 0
		if part.has("mag"):
			part.mag.position.y = part.mag_rest.y - drop * 0.3
			part.mag.rotation.z = drop * 0.6
		# Pump or bolt after a shot.
		var cycle = 0.0
		if cycle_time > 0:
			cycle = sin(minf(1.0, (1.0 - cycle_time / (0.85 if weapon_index == 2 else 0.45)) * 1.15) * PI)
			pose += Vector3(0.12, 0, 0.15) * cycle
			offset.y -= 0.02 * cycle
		if part.has("fore_end"):
			part.fore_end.position.z = part.fore_end_rest.z + cycle * 0.16
			hand.z += cycle * 0.16
		if part.has("bolt"):
			part.bolt.position.z = part.bolt_rest.z + cycle * 0.2
			part.bolt.rotation.z = -cycle * 1.1
		if part.has("hand_left"):
			part.hand_left.position = part.hand_left_rest + hand
	models[weapon_index].position = base + offset
	models[weapon_index].rotation = pose
	models[weapon_index].visible = not (weapon_index == 2 and aiming)
	# Port addition: the horizon rolls while the player is dizzy.
	var sway = sin(Time.get_ticks_msec() * 0.0017) * 0.07 * game.feel_dizzy
	camera.rotation.z = lerpf(camera.rotation.z, -control.x * 0.022 - (0.08 if slide_time > 0 else 0.0) + sway, delta * 9)


func reload() -> void:
	if weapon_index == 3 or reload_time > 0 or cycle_time > 0 or reserves[weapon_index] <= 0:
		return
	var config: Dictionary = weapons[weapon_names[weapon_index]]
	if magazines[weapon_index] < int(config.magazine):
		reload_time = config.reload
		game.sound.play_effect("shell" if weapon_index == 1 else "cylinder" if weapon_index == 4 else "reload")

func fire() -> void:
	if weapon_index == 3:
		if aiming and katana_charge >= 1 and not game.network.in_match and game.match_mode == "survival":
			var hit = ray(45)
			if not hit.is_empty() and hit.collider.has_method("take_damage"):
				position = hit.position + camera.global_basis.z * 2.0
				hit.collider.take_damage(9999.0)
				katana_charge = 0
		else:
			slash()
		return
	if cycle_time > 0:
		return
	if reload_time > 0:
		if weapon_index == 1 and magazines[1] > 0:
			reload_time = 0
		else:
			return
	if magazines[weapon_index] <= 0:
		reload()
		return
	var config: Dictionary = weapons[weapon_names[weapon_index]]
	magazines[weapon_index] -= 1
	last_attack = weapon_names[weapon_index]
	cycle_time = 0.85 if weapon_index == 2 else (0.45 if weapon_index == 1 else 0.0)
	camera.rotation.x += [0.009, 0.05, 0.055, 0.0, 0.038, 0.007, 0.07][weapon_index] * 0.55
	fire_cd = maxf(float(config.interval), 0.85 if weapon_index == 2 else 0.0)
	recoil = 0.045 if weapon_index in [0, 5] else 0.09
	game.sound.play_effect(["shot", "shotgunFire", "sniperFire", "", "revolver", "shot", "shotgunFire"][weapon_index])
	if weapon_index == 6:
		# The rocket is a friendly projectile that explodes on the first thing it touches.
		game.fire_projectile(parts[6].muzzle.global_position, -camera.global_basis.z, 46.0, 160.0, true, 5.0)
		return
	var remote_hits: Dictionary = {}
	for i in int(config.pellets):
		var spread: float = config.ads_spread if aiming else config.spread
		var direction = (-camera.global_basis.z + camera.global_basis.x * randf_range(-spread, spread) + camera.global_basis.y * randf_range(-spread, spread)).normalized()
		var hit = ray(300, direction)
		var end = camera.global_position + direction * 90.0
		if not hit.is_empty():
			end = hit.position
			if hit.collider.has_method("take_damage"):
				var amount: float = [19, 16, 150, 0, 48, 12][weapon_index] if hit.collider.get_meta("remote", false) else float(config.damage)
				if hit.collider.get_meta("part", "") == "head" or (not hit.collider is DoodleHitbox and hit.position.y > hit.collider.global_position.y + 1.45 * hit.collider.model_scale):
					amount *= ([1.8, 1.6, 1.5, 1.0, 1.6, 1.6][weapon_index] if hit.collider.get_meta("remote", false) else [2.6, 1.8, 3.0, 1.0, 3.0, 2.0][weapon_index])
				if weapon_index == 1:
					amount *= clampf(1.0 - maxf(0, camera.global_position.distance_to(end) - 11) / 21, 0.22, 1)
				if hit.collider.get_meta("remote", false):
					remote_hits[hit.collider.peer_id] = {"target": hit.collider, "amount": float(remote_hits.get(hit.collider.peer_id, {}).get("amount", 0.0)) + amount}
				else:
					hit.collider.take_damage(amount, hit.position)
				game.sound.play_effect("hitEnemy", hit.position)
				game.burst(hit.position, 1, 6)
				game.hit_marker = 0.15
			else:
				game.level.hit_prop(hit.collider, float(config.damage))
				game.burst(hit.position, 0, 4)
		game.tracer(parts[weapon_index].muzzle.global_position if models[weapon_index].visible else camera.global_position - camera.global_basis.y * 0.12, end, 3)
		if game.network.in_match and i == int(config.pellets) - 1:
			game.network.send_packet({"type": "shot", "weapon": weapon_index, "end": [end.x, end.y, end.z]})
	for entry in remote_hits.values():
		entry.target.take_damage(entry.amount)

func slash() -> void:
	if fire_cd > 0:
		return
	fire_cd = 0.33
	slash_time = 0.27
	slash_combo += 1
	combo_time = 0.9
	last_attack = "katana"
	recoil = 0.1
	game.sound.play_effect("katanaSwing")
	var targets: Array = []
	targets.append_array(game.enemies)
	targets.append_array(game.remote_players.values())
	for enemy in targets:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var offset: Vector3 = enemy.global_position + Vector3.UP - camera.global_position
		if offset.length() < 3.3 and offset.normalized().dot(-camera.global_basis.z) > 0.25:
			var hit = ray(offset.length() + 1, offset.normalized())
			if not hit.is_empty() and (hit.collider == enemy or (hit.collider is DoodleHitbox and hit.collider.actor == enemy)):
				enemy.take_damage(55 if enemy.get_meta("remote", false) else 75, enemy.global_position + Vector3.UP)
				game.sound.play_effect("katanaHit")
				game.burst(enemy.global_position + Vector3.UP, 1, 14)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0, hp - amount)
	last_hurt = 0
	game.sound.play_effect("hurt")
	game.hurt_flash = 0.22
	game.shake += amount / 80.0
	# Port addition: a heavy hit leaves the player dazed for a moment.
	if amount >= 20.0:
		game.daze = minf(1.0, game.daze + amount / 60.0)
	Input.start_joy_vibration(0, 0.8, 0.5, 0.16)
	if hp <= 0:
		alive = false
		grapple_active = false
		rope.visible = false
		game.sound.play_effect("death")
		game.game_over()

func step_up(delta: float) -> void:
	var horizontal = Vector3(velocity.x, 0, velocity.z) * delta
	if horizontal.length() < 0.001 or not test_move(global_transform, horizontal):
		return
	if test_move(global_transform, Vector3.UP * 0.55):
		return
	var raised = global_transform.translated(Vector3.UP * 0.55)
	if not test_move(raised, horizontal):
		global_position.y += 0.55

func try_mantle() -> void:
	var forward = -global_basis.z
	var belly = global_position + Vector3.UP
	var query = PhysicsRayQueryParameters3D.create(belly, belly + forward * 0.95, 1)
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var above = global_position + forward * 0.95 + Vector3.UP * 2.75
	query = PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 2.25, 1)
	var top = get_world_3d().direct_space_state.intersect_ray(query)
	if top.is_empty() or top.normal.y < 0.5:
		return
	var height: float = top.position.y - global_position.y
	if height < 0.5 or height > 2.4:
		return
	var check = PhysicsShapeQueryParameters3D.new()
	check.shape = capsule.shape
	check.transform = Transform3D(Basis(), top.position + Vector3.UP * 0.95)
	check.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(check, 1).is_empty():
		return
	velocity.y = minf(11, sqrt(52 * (height + 0.45)))
	velocity.x = forward.x * 3.2
	velocity.z = forward.z * 3.2
	mantle_cd = 0.7
	game.sound.play_effect("mantle")

func detach_grapple(boost: bool = false) -> void:
	if not grapple_active:
		return
	grapple_active = false
	grapple_body = null
	stamina_pause = 0.5
	rope.visible = false
	if boost:
		velocity.y = maxf(velocity.y, 0) + 8
		velocity.x *= 1.12
		velocity.z *= 1.12
	else:
		velocity.y += 2.5
	game.sound.play_effect("grappleRelease")

func update_grapple(delta: float, control: Vector2) -> void:
	if Input.is_action_just_pressed("grapple"):
		if grapple_active and grapple_flight <= 0:
			detach_grapple()
		elif not grapple_active and stamina >= 0.18:
			var hit = find_grapple_target()
			if not hit.is_empty():
				grapple_active = true
				grapple_anchor = hit.position
				grapple_body = hit.collider
				grapple_offset = grapple_body.to_local(grapple_anchor)
				grapple_origin = camera.global_position - camera.global_basis.y * 0.3
				grapple_flight = clampf(camera.global_position.distance_to(grapple_anchor) / 110.0, 0.04, 0.6)
				grapple_duration = grapple_flight
				grapple_blocked = 0
				grapple_age = 0
				stamina -= 0.09
				stamina_pause = 0.5
				game.sound.play_effect("grappleFire")
	if not grapple_active:
		return
	if not is_instance_valid(grapple_body) or stamina <= 0:
		detach_grapple()
		return
	grapple_anchor = grapple_body.to_global(grapple_offset)
	if grapple_flight > 0:
		grapple_flight -= delta
		grapple_hook = grapple_origin.lerp(grapple_anchor, clampf(1 - grapple_flight / grapple_duration, 0, 1))
		if grapple_flight <= 0:
			game.sound.play_effect("grappleHit")
			if grapple_body.has_method("yank"):
				grapple_body.yank(global_position)
				game.score += 30
				detach_grapple()
			else:
				grapple_length = maxf(1.5, (global_position + Vector3.UP).distance_to(grapple_anchor) * 0.94)
				if is_on_floor():
					velocity.y = maxf(velocity.y, 5.0)
	else:
		grapple_hook = grapple_anchor
		grapple_age += delta
		stamina = maxf(0, stamina - delta * 0.08)
		var toward = grapple_anchor - (global_position + Vector3.UP)
		var distance = toward.length()
		var direction = toward.normalized()
		if Input.is_action_pressed("grapple"):
			grapple_length = maxf(1.5, grapple_length - delta * 14)
			if velocity.dot(direction) < 22:
				velocity += direction * delta * 42
		else:
			if velocity.dot(direction) < 6:
				velocity += direction * delta * 3
			if control.y < -0.3 and global_position.y < grapple_anchor.y - 1:
				velocity -= global_basis.z * delta * 10
		if distance > grapple_length:
			if velocity.dot(direction) < 0:
				velocity -= direction * velocity.dot(direction)
			var correction = direction * minf(distance - grapple_length, 0.35) * 0.85
			if not test_move(global_transform, correction):
				global_position += correction
		var obstruction = ray(maxf(0, camera.global_position.distance_to(grapple_anchor) - 0.4), (grapple_anchor - camera.global_position).normalized(), [], true)
		grapple_blocked = grapple_blocked + delta if not obstruction.is_empty() and obstruction.collider != grapple_body else 0.0
		if distance < 1.3 or distance > 90 or grapple_blocked > 0.3 or (is_on_floor() and grapple_age > 0.6 and not Input.is_action_pressed("grapple")):
			detach_grapple(distance < 1.3)
	game.line_between(rope, camera.global_position - camera.global_basis.y * 0.3, grapple_hook)
	rope.visible = grapple_active

func is_blocking() -> bool:
	return weapon_index == 3 and aiming and slash_time <= 0 and fire_cd <= 0

func try_deflect(direction: Vector3) -> int:
	if not is_blocking() or block_cd > 0 or (-camera.global_basis.z).dot(-direction.normalized()) < 0.55:
		return 0
	var perfect = block_time < 0.26
	block_cd = 0.19
	game.sound.play_effect("perfectParry" if perfect else "parry")
	game.score += 60 if perfect else 15
	game.burst(camera.global_position - camera.global_basis.z, 3, 12)
	return 2 if perfect or randf() < 0.35 else 1

func try_block_melee(from: Vector3) -> bool:
	if not is_blocking() or block_cd > 0 or block_time > 0.55:
		return false
	if (-camera.global_basis.z).dot((from - camera.global_position).normalized()) < 0.35:
		return false
	block_cd = 0.2
	game.sound.play_effect("parry")
	game.score += 40
	return true

func find_grapple_target() -> Dictionary:
	var hit = ray(75, Vector3.ZERO, [], true)
	var limit = camera.global_position.distance_to(hit.position) if not hit.is_empty() else 75.0
	var forward = -camera.global_basis.z
	for enemy in game.enemies:
		if not enemy.alive or enemy.spawn_time > 0:
			continue
		var point = enemy.global_position + Vector3.UP * enemy.model_scale
		var offset = point - camera.global_position
		var along = offset.dot(forward)
		var lateral = (offset - forward * along).length()
		if along < 1.5 or along > minf(45, limit + 1.5) or lateral > 1.1 + along * 0.06:
			continue
		var test = PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
		if get_world_3d().direct_space_state.intersect_ray(test).is_empty():
			return {"position": point, "collider": enemy}
	var nearest = 1000.0
	var ring = Vector3.INF
	for entry in game.level.data.get("rings", []):
		var point = ReferenceAssets.vector(entry)
		var offset = point - camera.global_position
		var along = offset.dot(forward)
		var lateral = (offset - forward * along).length()
		if along > 2 and along < minf(75, limit + 1.5) and lateral < 0.8 + along * 0.02 and lateral < nearest:
			nearest = lateral
			ring = point
	if ring.is_finite():
		return {"position": ring, "collider": game.level}
	return hit
