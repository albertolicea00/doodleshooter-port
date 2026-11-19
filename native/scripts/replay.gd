class_name DoodleReplay
extends RefCounted

const SAMPLE_INTERVAL := 1.0 / 15.0
const MAX_FRAMES := 450
const MIN_SAVE_FRAMES := 45
const REPLAY_PATH := "user://last_replay.json"

var recorded: Array = []
var playback_map: String = "district"
var playback_frames: Array = []
var sample_timer: float = 0.0
var play_time: float = 0.0
var puppets_root: Node3D
var camera: Camera3D
var puppet_pool: Dictionary = {}

func attach(parent: Node3D) -> void:
	if is_instance_valid(puppets_root):
		puppets_root.queue_free()
	puppets_root = Node3D.new()
	puppets_root.name = "MenuReplayPuppets"
	puppets_root.visible = false
	parent.add_child(puppets_root)
	camera = Camera3D.new()
	camera.name = "MenuReplayCamera"
	camera.fov = 75.0
	camera.far = 260.0
	parent.add_child(camera)

func start_recording() -> void:
	recorded.clear()
	sample_timer = 0.0

func record_step(delta: float, player: Node3D, enemies: Array, bots: Array, remotes: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	sample_timer -= delta
	if sample_timer > 0.0:
		return
	sample_timer += SAMPLE_INTERVAL
	var eye = player.global_position + Vector3(0, 1.5, 0)
	var actors: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			actors.append([enemy.global_position.x, enemy.global_position.y, enemy.global_position.z, enemy.rotation.y, str(enemy.kind)])
	for bot in bots:
		if is_instance_valid(bot) and bot.alive:
			actors.append([bot.global_position.x, bot.global_position.y, bot.global_position.z, bot.rotation.y, "grunt"])
	for peer_id in remotes:
		var remote = remotes[peer_id]
		if is_instance_valid(remote) and remote.visible:
			actors.append([remote.global_position.x, remote.global_position.y, remote.global_position.z, remote.rotation.y, "grunt"])
	if actors.size() > 10:
		actors.sort_custom(func(a, b):
			return Vector3(a[0], a[1], a[2]).distance_squared_to(eye) < Vector3(b[0], b[1], b[2]).distance_squared_to(eye))
		actors.resize(10)
	recorded.append({
		"p": [snappedf(eye.x, 0.01), snappedf(eye.y, 0.01), snappedf(eye.z, 0.01), snappedf(player.yaw, 0.001), snappedf(player.pitch, 0.001)],
		"e": actors
	})
	if recorded.size() > MAX_FRAMES:
		recorded.pop_front()

func save_recording(map_key: String, path: String = REPLAY_PATH) -> bool:
	if recorded.size() < MIN_SAVE_FRAMES:
		return false
	var payload = {"map": map_key, "frames": recorded}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	playback_map = map_key
	playback_frames = recorded.duplicate(true)
	play_time = 0.0
	return true

func load_or_default(level: Node3D, default_map: String = "district", path: String = REPLAY_PATH) -> void:
	if FileAccess.file_exists(path):
		var raw = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary and parsed.get("frames", []) is Array and parsed["frames"].size() >= 10:
			playback_map = str(parsed.get("map", default_map))
			playback_frames = parsed["frames"]
			play_time = 0.0
			return
	build_default(level, default_map)

func build_default(level: Node3D, map_key: String = "district") -> void:
	playback_map = map_key
	playback_frames.clear()
	var center = Vector3(0, 4.5, 0)
	if is_instance_valid(level):
		center = level.start + Vector3(0, 3.0, 0)
	var spawn_points: Array = []
	if is_instance_valid(level) and level.spawns.size() > 0:
		for i in mini(4, level.spawns.size()):
			spawn_points.append(level.spawns[i])
	else:
		spawn_points = [center + Vector3(6, -1.5, -8), center + Vector3(-7, -1.5, -6), center + Vector3(4, -1.5, 7)]
	var count = 180
	for i in count:
		var t = TAU * float(i) / float(count)
		var eye = center + Vector3(sin(t) * 10.0, 1.2 + sin(t * 2.0) * 0.8, cos(t) * 10.0)
		var look = center + Vector3(sin(t + 0.5) * 3.0, 0.2, cos(t + 0.5) * 3.0)
		var dir = (look - eye).normalized()
		var yaw = atan2(-dir.x, -dir.z)
		var pitch = asin(clampf(dir.y, -0.95, 0.95))
		var actors: Array = []
		for j in spawn_points.size():
			var sp: Vector3 = spawn_points[j]
			var phase = t * 2.0 + float(j) * 1.6
			var pos = sp + Vector3(sin(phase) * 2.2, 0.0, cos(phase) * 2.2)
			var kind = ["grunt", "rusher", "sniper", "grunt"][j % 4]
			actors.append([pos.x, pos.y, pos.z, phase + PI * 0.5, kind])
		playback_frames.append({
			"p": [eye.x, eye.y, eye.z, yaw, pitch],
			"e": actors
		})
	play_time = 0.0

func clear_puppets() -> void:
	for kind in puppet_pool:
		for node in puppet_pool[kind]:
			if is_instance_valid(node):
				node.queue_free()
	puppet_pool.clear()

func step_playback(delta: float, active: bool) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(puppets_root):
		return
	if not active or playback_frames.size() < 2:
		puppets_root.visible = false
		if camera.current:
			camera.current = false
		return
	puppets_root.visible = true
	camera.current = true
	var total = float(playback_frames.size() - 1) * SAMPLE_INTERVAL
	play_time = fposmod(play_time + delta, total)
	var exact = play_time / SAMPLE_INTERVAL
	var idx = clampi(int(exact), 0, playback_frames.size() - 2)
	var frac = exact - float(idx)
	var a: Dictionary = playback_frames[idx]
	var b: Dictionary = playback_frames[idx + 1]
	var pa: Array = a["p"]
	var pb: Array = b["p"]
	camera.global_position = Vector3(pa[0], pa[1], pa[2]).lerp(Vector3(pb[0], pb[1], pb[2]), frac)
	var yaw = lerp_angle(float(pa[3]), float(pb[3]), frac)
	var pitch = lerpf(float(pa[4]), float(pb[4]), frac)
	camera.rotation = Vector3(pitch, yaw, 0.0)
	_sync_puppets(a.get("e", []), b.get("e", []), frac)

func _sync_puppets(ea: Array, eb: Array, frac: float) -> void:
	for kind in puppet_pool:
		for node in puppet_pool[kind]:
			if is_instance_valid(node):
				node.visible = false
	var used_counts: Dictionary = {}
	for i in ea.size():
		var item: Array = ea[i]
		var kind = str(item[4])
		var idx = int(used_counts.get(kind, 0))
		used_counts[kind] = idx + 1
		var puppet = _acquire_puppet(kind, idx)
		if puppet == null:
			continue
		var pos = Vector3(item[0], item[1], item[2])
		var rot_y = float(item[3])
		if i < eb.size() and str(eb[i][4]) == kind:
			var next_item: Array = eb[i]
			pos = pos.lerp(Vector3(next_item[0], next_item[1], next_item[2]), frac)
			rot_y = lerp_angle(rot_y, float(next_item[3]), frac)
		puppet.global_position = pos
		puppet.rotation = Vector3(0.0, rot_y, 0.0)
		puppet.visible = true

func _acquire_puppet(kind: String, index: int) -> Node3D:
	if not puppet_pool.has(kind):
		puppet_pool[kind] = []
	var list: Array = puppet_pool[kind]
	while list.size() <= index:
		var model = ReferenceAssets.model("enemies", kind)
		if model == null:
			return null
		puppets_root.add_child(model)
		list.append(model)
	return list[index]
