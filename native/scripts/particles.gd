class_name DoodleParticles
extends MultiMeshInstance3D

const CAPACITY = 512
var particles: Array[Dictionary] = []
var smoke_puffs: Array[Dictionary] = []
var smoke_mesh: TorusMesh
var smoke_mat: StandardMaterial3D

func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var stroke = BoxMesh.new()
	stroke.size = Vector3.ONE
	multimesh.mesh = stroke
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material_override = material
	custom_aabb = AABB(Vector3(-200, -100, -200), Vector3(400, 400, 400))

func burst(at: Vector3, ink: int, count: int, speed: float = 6.0) -> void:
	for i in mini(count, CAPACITY - particles.size()):
		particles.append({"position": at, "velocity": Vector3(randf_range(-1, 1), randf_range(-0.2, 1.3), randf_range(-1, 1)).normalized() * randf_range(speed * 0.3, speed), "life": randf_range(0.2, 0.7), "size": randf_range(0.02, 0.07), "color": ReferenceAssets.COLORS[ink], "spin": randf() * TAU, "gravity": 9.0, "drag": 0.0})

func muzzle_sparks(at: Vector3, count: int, flash_scale: float = 1.0) -> void:
	var speed = 6.0 * flash_scale
	for i in mini(count, CAPACITY - particles.size()):
		var dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		particles.append({"position": at, "velocity": dir * randf_range(speed * 0.4, speed), "life": 0.08, "size": 0.026, "color": ReferenceAssets.COLORS[3], "spin": randf() * TAU, "gravity": 0.0, "drag": 8.0})

func muzzle_smoke(at: Vector3, forward: Vector3, count: int = 2) -> void:
	if smoke_mesh == null:
		smoke_mesh = TorusMesh.new()
		smoke_mesh.inner_radius = 0.055
		smoke_mesh.outer_radius = 0.078
		smoke_mesh.rings = 14
		smoke_mesh.ring_segments = 8
		smoke_mat = StandardMaterial3D.new()
		smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_mat.albedo_color = ReferenceAssets.COLORS[0]
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in count:
		if smoke_puffs.size() >= 24:
			var oldest = smoke_puffs.pop_front()
			if is_instance_valid(oldest.node):
				oldest.node.queue_free()
		var node = MeshInstance3D.new()
		node.mesh = smoke_mesh
		node.material_override = smoke_mat.duplicate()
		get_parent().add_child(node)
		node.global_position = at
		var life = randf_range(0.45, 0.8)
		var vel = forward * randf_range(0.6, 1.8) + Vector3(randf_range(-0.4, 0.4), randf_range(0.5, 1.2), randf_range(-0.4, 0.4))
		smoke_puffs.append({"node": node, "velocity": vel, "life": life, "max_life": life, "base_scale": randf_range(0.6, 1.0)})

func _process(delta: float) -> void:
	if not get_parent().playing:
		return
	var next: Array[Dictionary] = []
	for particle in particles:
		particle.life -= delta
		if particle.life <= 0:
			continue
		particle.velocity.y -= delta * float(particle.get("gravity", 9.0))
		var drag = float(particle.get("drag", 0.0))
		if drag > 0.0:
			particle.velocity *= maxf(0.0, 1.0 - drag * delta)
		particle.position += particle.velocity * delta
		var scale = Vector3(particle.size, particle.size, maxf(particle.size, particle.velocity.length() * 0.025))
		var basis = Basis.from_euler(Vector3(particle.spin, particle.spin * 0.5, 0)).scaled(scale)
		multimesh.set_instance_transform(next.size(), Transform3D(basis, particle.position))
		multimesh.set_instance_color(next.size(), particle.color)
		next.append(particle)
	particles = next
	multimesh.visible_instance_count = particles.size()
	var cam = get_viewport().get_camera_3d()
	var next_smoke: Array[Dictionary] = []
	for puff in smoke_puffs:
		puff.life -= delta
		if puff.life <= 0 or not is_instance_valid(puff.node):
			if is_instance_valid(puff.node):
				puff.node.queue_free()
			continue
		puff.velocity.y += delta * 1.2
		puff.velocity *= maxf(0.0, 1.0 - 3.0 * delta)
		puff.node.global_position += puff.velocity * delta
		var progress = 1.0 - puff.life / puff.max_life
		var s = puff.base_scale * (1.0 + progress * 2.4)
		puff.node.scale = Vector3.ONE * s
		if cam != null:
			puff.node.look_at(cam.global_position, Vector3.UP)
			puff.node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		(puff.node.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - progress, 0.0, 0.75)
		next_smoke.append(puff)
	smoke_puffs = next_smoke

func clear_smoke() -> void:
	for puff in smoke_puffs:
		if is_instance_valid(puff.node):
			puff.node.queue_free()
	smoke_puffs.clear()
