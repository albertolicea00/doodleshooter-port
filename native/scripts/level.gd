class_name DoodleLevel
extends Node3D

var data: Dictionary
var start: Vector3
var spawns: Array[Vector3] = []
var snipers: Array[Vector3] = []
var pickup_spots: Array[Vector3] = []
var breakables: Dictionary = {}
var movers: Array[Node3D] = []
var elapsed = 0.0

func load_map(key: String, arena: bool = false) -> void:
	data = ReferenceAssets.read_json(key + ("_arena" if arena else ""))
	start = ReferenceAssets.vector(data.player_start)
	for p in data.spawns:
		spawns.append(ReferenceAssets.vector(p))
	for p in data.snipers:
		snipers.append(ReferenceAssets.vector(p))
	for p in data.pickups:
		pickup_spots.append(ReferenceAssets.vector(p))
	var geometry = Node3D.new()
	add_child(geometry)
	for item in data.children:
		geometry.add_child(ReferenceAssets.build(item))
	for br in data.breakables:
		breakables[int(br.id)] = {"visual": geometry.get_child(int(br.node)), "hp": float(br.hp), "kind": br.kind, "body": null, "position": ReferenceAssets.vector(br.position)}
	for box in data.boxes:
		var body = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		var low = ReferenceAssets.vector(box.min)
		var high = ReferenceAssets.vector(box.max)
		# Round props on the port maps collide as upright cylinders; everything else is a box.
		if box.get("shape", "box") == "cylinder":
			var round = CylinderShape3D.new()
			round.radius = float(box.radius)
			round.height = high.y - low.y
			shape.shape = round
		else:
			var bounds = BoxShape3D.new()
			bounds.size = high - low
			shape.shape = bounds
		body.position = (low + high) * 0.5
		body.set_meta("no_grapple", box.no_grapple)
		body.set_meta("no_shoot", box.no_shoot)
		body.set_meta("breakable", int(box.breakable))
		body.add_child(shape)
		add_child(body)
		if int(box.breakable) >= 0:
			breakables[int(box.breakable)].body = body
	for i in data.movers:
		var mover = geometry.get_child(int(i))
		movers.append(mover)
		var body = AnimatableBody3D.new()
		body.collision_layer = 16
		body.collision_mask = 0
		body.sync_to_physics = false
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(3.0, 0.2, 3.0)
		shape.shape = box
		body.add_child(shape)
		mover.add_child(body)

func _physics_process(delta: float) -> void:
	if not get_parent().get_parent().playing:
		return
	elapsed += delta
	for i in movers.size():
		var a = elapsed * (0.11 + i * 0.01) + i * 2.1
		var radius = 30.0 + i * 8.0
		var h = (26.0 if data.key == "mexico" else 30.0) + i * 6.0
		var pos = Vector3(cos(a) * radius, h + sin(a * 2.3) * 3.0, sin(a) * radius * 0.7)
		var next = Vector3(cos(a + 0.05) * radius, h + sin((a + 0.05) * 2.3) * 3.0, sin(a + 0.05) * radius * 0.7)
		movers[i].position = pos
		movers[i].look_at(next, Vector3.UP, true)

func hit_prop(body: Object, amount: float, broadcast: bool = true) -> void:
	var id = int(body.get_meta("breakable", -1))
	if id < 0 or not breakables.has(id):
		return
	var prop: Dictionary = breakables[id]
	prop.hp -= amount
	if prop.hp <= 0:
		get_parent().get_parent().burst(prop.position, 3, 22)
		get_parent().get_parent().sound.play_effect("smash", prop.position)
		prop.visual.visible = false
		prop.body.queue_free()
		if prop.kind == "pinata":
			get_parent().get_parent().spawn_pickup("health", prop.position)
		if broadcast and get_parent().get_parent().network.in_match:
			get_parent().get_parent().network.send_packet({"type": "broken", "id": id})
		breakables.erase(id)
