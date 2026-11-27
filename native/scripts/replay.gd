class_name DoodleReplay
extends RefCounted

const SAMPLE_INTERVAL := 1.0 / 15.0
const MAX_FRAMES := 450
const MIN_SAVE_FRAMES := 45
const REPLAY_PATH := "user://last_replay.json"
const BUNDLED_DIRECTORY := "res://data/menu_replays"
const DEFAULT_TAKE := "district-2026-11-27-15-29-10.json"
const DEFAULT_MAP := "district"
const DEFAULT_LOOP_SECONDS := 32.0

var recorded: Array = []
var recording_frame_limit: int = MAX_FRAMES
var playback_map: String = DEFAULT_MAP
var playback_frames: Array = []
var sample_timer: float = 0.0
var play_time: float = 0.0
var using_default = false
var puppets_root: Node3D
var camera: Camera3D
var outline: MeshInstance3D
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
	camera.near = 0.1
	camera.far = 600.0
	parent.add_child(camera)
	outline = ReferenceAssets.add_camera_outline(camera)
	outline.hide()

func update_outline(bold: bool) -> void:
	if is_instance_valid(outline):
		outline.material_override.set_shader_parameter("ink", ReferenceAssets.outline_ink())
		outline.material_override.set_shader_parameter("width_scale", 1.75 if bold else 1.0)

func start_recording(frame_limit: int = MAX_FRAMES) -> void:
	recorded.clear()
	recording_frame_limit = frame_limit
	sample_timer = 0.0

func record_step(delta: float, player: Node3D, enemies: Array, bots: Array, remotes: Dictionary) -> void:
	if not is_instance_valid(player):
		return
	sample_timer -= delta
	if sample_timer > 0.0:
		return
	sample_timer += SAMPLE_INTERVAL
	var eye = player.camera.global_position if is_instance_valid(player.camera) else player.global_position + Vector3(0, 1.5, 0)
	var yaw = player.rotation.y
	var pitch = player.camera.rotation.x if is_instance_valid(player.camera) else 0.0
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
		"p": [snappedf(eye.x, 0.01), snappedf(eye.y, 0.01), snappedf(eye.z, 0.01), snappedf(yaw, 0.001), snappedf(pitch, 0.001)],
		"e": actors
	})
	if recorded.size() > recording_frame_limit:
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
	using_default = false
	return true

func load_recording(path: String = REPLAY_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	var frames = parsed.get("frames", [])
	if not frames is Array or frames.size() < 10:
		return false
	for frame in frames:
		if not frame is Dictionary or not _valid_sample(frame.get("p"), 5):
			return false
		var actors = frame.get("e", [])
		if not actors is Array:
			return false
		for actor in actors:
			if not _valid_sample(actor, 4) or not actor[4] is String:
				return false
	playback_map = str(parsed.get("map", DEFAULT_MAP))
	playback_frames = frames
	play_time = 0.0
	using_default = false
	return true

func load_default_recording(map_keys: Array[String]) -> bool:
	if not load_recording(BUNDLED_DIRECTORY.path_join(DEFAULT_TAKE)) or not playback_map in map_keys:
		return false
	using_default = true
	return true

func load_bundled_recording(map_keys: Array[String], directory: String = BUNDLED_DIRECTORY) -> bool:
	var folder = DirAccess.open(directory)
	if folder == null:
		return false
	var candidates = Array(folder.get_files())
	candidates.shuffle()
	for filename in candidates:
		if filename != DEFAULT_TAKE and filename.get_extension() == "json" and load_recording(directory.path_join(filename)) and playback_map in map_keys:
			using_default = true
			return true
	return false

static func _valid_sample(sample: Variant, numeric_fields: int) -> bool:
	if not sample is Array or sample.size() != 5:
		return false
	for i in numeric_fields:
		var value = sample[i]
		if not (value is int or value is float) or not is_finite(value):
			return false
	return true

func build_default() -> void:
	playback_map = DEFAULT_MAP
	playback_frames.clear()
	using_default = true
	var intervals = roundi(DEFAULT_LOOP_SECONDS / SAMPLE_INTERVAL)
	# Frame District's central tower beside the menu sheet as the camera glides past.
	# Include the closing sample so interpolation reaches the first pose at the seam.
	for i in intervals + 1:
		var t = TAU * float(i) / intervals
		var eye = Vector3(22.0 + sin(t) * 5.0, 17.0 + sin(t) * 1.2, 30.0 + cos(t) * 2.5)
		var look = Vector3(-24.0 + sin(t) * 2.0, 6.0, 17.0)
		var dir = (look - eye).normalized()
		var yaw = atan2(-dir.x, -dir.z)
		var pitch = asin(clampf(dir.y, -0.95, 0.95))
		playback_frames.append({"p": [eye.x, eye.y, eye.z, yaw, pitch]})
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
		outline.hide()
		if camera.current:
			camera.current = false
		return
	puppets_root.visible = true
	outline.visible = using_default
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
