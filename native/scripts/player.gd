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
var weapon_names = ["rifle", "shotgun", "sniper", "katana"]
var weapon_index = 0
var magazines = [35, 6, 5, 0]
var reserves = [175, 36, 25, 0]
var fire_cd = 0.0
var reload_time = 0.0
var last_hurt = 10.0
var grenades = 3
var katana_charge = 0.0
var recoil = 0.0
var bob = 0.0
var aiming = false
var throw_charge = 0.0
var charging = false
var models: Array[Node3D] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
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
	rig = Node3D.new()
	camera.add_child(rig)
	weapons = ReferenceAssets.read_json("weapons")
	for key in weapon_names:
		var model = ReferenceAssets.model("weapons", key)
		rig.add_child(model)
		model.position = ReferenceAssets.vector(weapons[key].position)
		models.append(model)
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
		switch_weapon((weapon_index + 1) % 4)
	for i in 4:
		if event.is_action_pressed("weapon_" + str(i)):
			switch_weapon(i)

func look(amount: Vector2) -> void:
	rotate_y(-amount.x)
	camera.rotation.x = clampf(camera.rotation.x - amount.y, -1.48, 1.48)

func switch_weapon(index: int) -> void:
	weapon_index = index
	reload_time = 0.0
	for i in models.size():
		models[i].visible = i == index

func ray(distance: float, direction: Vector3 = Vector3.ZERO, skip: Array[RID] = []) -> Dictionary:
	var origin = camera.global_position
	var target = origin + (-camera.global_basis.z if direction == Vector3.ZERO else direction) * distance
	var query = PhysicsRayQueryParameters3D.create(origin, target, 1 | 4, [get_rid()] + skip)
	return get_world_3d().direct_space_state.intersect_ray(query)

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
	var speed = 10.6 if Input.is_action_pressed("sprint") or control.length() > 0.94 and OS.has_feature("mobile") else 6.6
	if aiming:
		speed = 4.2
	fire_cd -= delta
	dash_cd -= delta
	slide_time -= delta
	last_hurt += delta
	if last_hurt > 4.5 and hp < 120.0 and speed < 10.0:
		hp = minf(120.0, hp + 11.0 * delta)
	if is_on_floor():
		jumps = 1
		coyote = 0.13
		stamina = minf(1.0, stamina + 0.4 * delta)
	else:
		coyote -= delta
		velocity.y -= 26.0 * delta
	var accel = 140.0 if is_on_floor() else 36.0
	if slide_time <= 0:
		velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 6.5 * delta)
		velocity.z = move_toward(velocity.z, 0, 6.5 * delta)
	if Input.is_action_just_pressed("jump"):
		if grapple_active:
			grapple_active = false
			velocity.y += 6.0
		elif is_on_floor() or coyote > 0:
			velocity.y = 9.6
			coyote = 0
		elif is_on_wall():
			velocity += get_wall_normal() * 7.5
			velocity.y = 9.2
			jumps = 1
		elif jumps > 0:
			velocity.y = 9.6 * 0.92
			jumps -= 1
	if Input.is_action_just_pressed("dash") and dash_cd <= 0:
		dash_cd = 0.8
		var direction = wish.normalized() if wish.length() > 0.1 else -global_basis.z
		velocity += direction * (12.0 if is_on_floor() else 18.0)
		if is_on_floor():
			slide_time = 0.85
		else:
			velocity.y = maxf(velocity.y, 1.0)
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
	if Input.is_action_just_pressed("grapple") and stamina >= 0.18:
		var hit = ray(75)
		if not hit.is_empty() and not hit.collider.get_meta("no_grapple", false):
			grapple_active = true
			grapple_anchor = hit.position
			grapple_body = hit.collider
			grapple_offset = grapple_anchor - grapple_body.global_position
			stamina -= 0.09
	if Input.is_action_just_released("grapple") or stamina <= 0:
		grapple_active = false
	if grapple_active:
		if is_instance_valid(grapple_body):
			grapple_anchor = grapple_body.global_position + grapple_offset
		var toward = grapple_anchor - camera.global_position
		if toward.length() > 2.0:
			velocity += toward.normalized() * delta * 42.0
		stamina = maxf(0, stamina - delta * 0.08)
		game.line_between(rope, camera.global_position - camera.global_basis.y * 0.2, grapple_anchor)
	rope.visible = grapple_active
	velocity = velocity.limit_length(48.0)
	move_and_slide()
	if position.y < -12.0:
		position = game.level.start + Vector3.UP * 0.1
		velocity = Vector3.ZERO
		take_damage(20)
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			var count = mini(int(weapons[weapon_names[weapon_index]].magazine) - magazines[weapon_index], reserves[weapon_index])
			magazines[weapon_index] += count
			reserves[weapon_index] -= count
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_pressed("fire") and fire_cd <= 0:
		if weapon_index == 0 or Input.is_action_just_pressed("fire"):
			fire()
	if Input.is_action_just_pressed("slash"):
		slash()
	if Input.is_action_just_pressed("grenade") and grenades > 0:
		charging = true
		throw_charge = 0
	if charging:
		throw_charge = minf(1.0, throw_charge + delta)
		if Input.is_action_just_released("grenade"):
			charging = false
			grenades -= 1
			game.throw_grenade(camera.global_position, -camera.global_basis.z * lerpf(12, 30, throw_charge) + Vector3.UP * 4)
	bob += delta * Vector2(velocity.x, velocity.z).length() * 1.4
	recoil = move_toward(recoil, 0, delta * 0.5)
	var key: String = weapon_names[weapon_index]
	camera.fov = lerpf(camera.fov, float(weapons[key].fov) if aiming else 82.0, 1.0 - exp(-delta * 12.0))
	var base = ReferenceAssets.vector(weapons[key].aim_position if aiming else weapons[key].position)
	models[weapon_index].position = base + Vector3(sin(bob) * 0.003, absf(cos(bob)) * 0.003 - (0.1 if reload_time > 0 else 0.0), recoil)
	models[weapon_index].rotation.z = sin(reload_time * 4) * 0.35 if reload_time > 0 else 0.0

func reload() -> void:
	if weapon_index == 3 or reload_time > 0 or reserves[weapon_index] <= 0:
		return
	var config: Dictionary = weapons[weapon_names[weapon_index]]
	if magazines[weapon_index] < int(config.magazine):
		reload_time = config.reload

func fire() -> void:
	if weapon_index == 3:
		if aiming and katana_charge >= 1:
			var hit = ray(45)
			if not hit.is_empty() and hit.collider.has_method("take_damage"):
				position = hit.position + camera.global_basis.z * 2.0
				hit.collider.take_damage(9999.0)
				katana_charge = 0
		else:
			slash()
		return
	if reload_time > 0:
		return
	if magazines[weapon_index] <= 0:
		reload()
		return
	var config: Dictionary = weapons[weapon_names[weapon_index]]
	magazines[weapon_index] -= 1
	fire_cd = maxf(float(config.interval), 0.85 if weapon_index == 2 else 0.0)
	recoil = 0.045 if weapon_index == 0 else 0.09
	game.sound.play_tone(100 if weapon_index == 0 else 65, 0.10, true)
	for i in int(config.pellets):
		var spread: float = config.ads_spread if aiming else config.spread
		var direction = (-camera.global_basis.z + camera.global_basis.x * randf_range(-spread, spread) + camera.global_basis.y * randf_range(-spread, spread)).normalized()
		var hit = ray(300, direction)
		var end = camera.global_position + direction * 90.0
		if not hit.is_empty():
			end = hit.position
			if hit.collider.has_method("take_damage"):
				var amount: float = config.damage
				if hit.position.y > hit.collider.global_position.y + 1.45 * hit.collider.model_scale:
					amount *= 2.6
				if weapon_index == 1:
					amount *= clampf(1.0 - maxf(0, camera.global_position.distance_to(end) - 11) / 21, 0.22, 1)
				hit.collider.take_damage(amount)
				game.hit_marker = 0.15
			else:
				game.level.hit_prop(hit.collider, float(config.damage))
		game.tracer(camera.global_position - camera.global_basis.y * 0.12, end, 3)

func slash() -> void:
	if fire_cd > 0:
		return
	fire_cd = 0.4
	recoil = 0.1
	game.sound.play_tone(330, 0.12, true)
	for enemy in game.enemies.duplicate():
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var offset: Vector3 = enemy.global_position + Vector3.UP - camera.global_position
		if offset.length() < 3.3 and offset.normalized().dot(-camera.global_basis.z) > 0.25:
			var hit = ray(offset.length() + 1, offset.normalized())
			if not hit.is_empty() and hit.collider == enemy:
				enemy.take_damage(95)
				katana_charge = minf(1.0, katana_charge + 0.25)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0, hp - amount)
	last_hurt = 0
	game.hurt_flash = 0.22
	if hp <= 0:
		alive = false
		grapple_active = false
		rope.visible = false
		game.game_over()
