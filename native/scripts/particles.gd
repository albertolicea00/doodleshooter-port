class_name DoodleParticles
extends MultiMeshInstance3D

const CAPACITY = 512
var particles: Array[Dictionary] = []

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
		particles.append({"position": at, "velocity": Vector3(randf_range(-1, 1), randf_range(-0.2, 1.3), randf_range(-1, 1)).normalized() * randf_range(speed * 0.3, speed), "life": randf_range(0.2, 0.7), "size": randf_range(0.02, 0.07), "color": ReferenceAssets.COLORS[ink], "spin": randf() * TAU})

func _process(delta: float) -> void:
	if not get_parent().playing:
		return
	var next: Array[Dictionary] = []
	for particle in particles:
		particle.life -= delta
		if particle.life <= 0:
			continue
		particle.velocity.y -= delta * 9
		particle.position += particle.velocity * delta
		var scale = Vector3(particle.size, particle.size, maxf(particle.size, particle.velocity.length() * 0.025))
		var basis = Basis.from_euler(Vector3(particle.spin, particle.spin * 0.5, 0)).scaled(scale)
		multimesh.set_instance_transform(next.size(), Transform3D(basis, particle.position))
		multimesh.set_instance_color(next.size(), particle.color)
		next.append(particle)
	particles = next
	multimesh.visible_instance_count = particles.size()
