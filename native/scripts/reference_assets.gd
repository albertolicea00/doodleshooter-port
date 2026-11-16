class_name ReferenceAssets
extends RefCounted

const COLORS = [Color(0.10, 0.19, 0.76), Color(0.86, 0.12, 0.20), Color(0.18, 0.20, 0.26), Color(0.92, 0.55, 0.08), Color(0.12, 0.60, 0.30), Color(0.90, 0.40, 0.66)]
static var materials: Dictionary = {}
static var models: Dictionary = {}
static var detail = 1.0

static func read_json(file: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file + ".json"))

static func vector(data: Array) -> Vector3:
	return Vector3(data[0], data[1], data[2])

static func material(ink: int = 0, solid: bool = false, shade: Array = [1.0, 0.0]) -> ShaderMaterial:
	var key = str(ink) + str(solid) + str(shade)
	if not materials.has(key):
		var mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/ink.gdshader")
		mat.set_shader_parameter("ink", COLORS[ink])
		mat.set_shader_parameter("solid", solid)
		mat.set_shader_parameter("shade_scale", float(shade[0]))
		mat.set_shader_parameter("shade_bias", float(shade[1]))
		mat.set_shader_parameter("detail", detail)
		materials[key] = mat
	return materials[key]

static func build(data: Dictionary) -> Node3D:
	var result: Node3D
	if data.has("mesh"):
		var mesh_node = MeshInstance3D.new()
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var p: Array = data.mesh.vertices
		var n: Array = data.mesh.normals
		for i in range(0, p.size(), 3):
			vertices.append(Vector3(p[i], p[i + 1], p[i + 2]))
			normals.append(Vector3(n[i], n[i + 1], n[i + 2]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_node.mesh = mesh
		mesh_node.material_override = material(int(data.ink), data.get("fill", false), data.get("shade", [1.0, 0.0]))
		result = mesh_node
	else:
		result = Node3D.new()
	result.name = data.get("name", "Part")
	result.position = vector(data.position)
	var q: Array = data.quaternion
	result.quaternion = Quaternion(q[0], q[1], q[2], q[3])
	result.scale = vector(data.scale)
	result.visible = data.visible
	for child in data.children:
		result.add_child(build(child))
	return result

static func model(collection: String, key: String) -> Node3D:
	var id = collection + ":" + key
	if not models.has(id):
		var data: Dictionary = read_json(collection)[key]
		models[id] = build(data.model if data.has("model") else data)
	return models[id].duplicate()

static func set_detail(level: float) -> void:
	detail = level
	for mat in materials.values():
		mat.set_shader_parameter("detail", level)

static func dispose() -> void:
	for node in models.values():
		node.free()
	models.clear()
	materials.clear()
