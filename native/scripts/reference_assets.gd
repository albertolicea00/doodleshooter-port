class_name ReferenceAssets
extends RefCounted

# The first six inks are the original's. Yellow, lime, purple and teal are port additions used by the port maps.
const COLORS = [Color(0.10, 0.19, 0.76), Color(0.86, 0.12, 0.20), Color(0.18, 0.20, 0.26), Color(0.92, 0.55, 0.08), Color(0.12, 0.60, 0.30), Color(0.90, 0.40, 0.66),
	Color(0.90, 0.70, 0.02), Color(0.42, 0.72, 0.08), Color(0.50, 0.24, 0.74), Color(0.04, 0.58, 0.62)]
static var map_colors: Array = COLORS.duplicate()
static var map_paper = Color(0.97, 0.96, 0.91)
static var materials: Dictionary = {}
static var models: Dictionary = {}
static var detail = 1.0
# 0: the original's crossed hatching, 1: the port's coloured-pencil shading.
static var style = 1.0

static func read_json(file: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file + ".json"))

static func vector(data: Array) -> Vector3:
	return Vector3(data[0], data[1], data[2])

static func material(ink: int = 0, solid: bool = false, shade: Array = [1.0, 0.0]) -> ShaderMaterial:
	var key = str(ink) + str(solid) + str(shade)
	if not materials.has(key):
		var mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/ink.gdshader")
		mat.set_meta("ink_index", ink)
		mat.set_shader_parameter("ink", map_colors[ink])
		mat.set_shader_parameter("paper_color", map_paper)
		mat.set_shader_parameter("solid", solid)
		mat.set_shader_parameter("shade_scale", float(shade[0]))
		mat.set_shader_parameter("shade_bias", float(shade[1]))
		mat.set_shader_parameter("detail", detail)
		mat.set_shader_parameter("style", style)
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

static func set_map_style(settings: Dictionary) -> void:
	map_colors = COLORS.duplicate()
	var palette: Array = settings.get("inks", [])
	for i in mini(palette.size(), map_colors.size()):
		map_colors[i] = Color(palette[i][0], palette[i][1], palette[i][2])
	var paper: Array = settings.get("paper", [0.97, 0.96, 0.91])
	map_paper = Color(paper[0], paper[1], paper[2])
	for mat in materials.values():
		mat.set_shader_parameter("ink", map_colors[int(mat.get_meta("ink_index"))])
		mat.set_shader_parameter("paper_color", map_paper)

static func set_detail(level: float) -> void:
	detail = level
	for mat in materials.values():
		mat.set_shader_parameter("detail", level)

static func set_style(value: float) -> void:
	style = value
	for mat in materials.values():
		mat.set_shader_parameter("style", value)

static func dispose() -> void:
	for node in models.values():
		node.free()
	models.clear()
	materials.clear()
