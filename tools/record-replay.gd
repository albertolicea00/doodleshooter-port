extends SceneTree

const COUNTDOWN_SECONDS := 3
var banner: Label

func _initialize() -> void:
	_record.call_deferred()

func _record() -> void:
	var map_key = _argument("map", DoodleReplay.DEFAULT_MAP)
	var seconds = _argument("seconds", "30")
	var max_seconds = roundi(DoodleReplay.MAX_FRAMES * DoodleReplay.SAMPLE_INTERVAL)
	var min_seconds = ceili(DoodleReplay.MIN_SAVE_FRAMES * DoodleReplay.SAMPLE_INTERVAL)
	var take = _argument("take", "")
	if take.is_empty():
		take = map_key + "-" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "-")
	var name_pattern = RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9_-]*$")
	if name_pattern.search(take) == null:
		_fail("Use letters, numbers, hyphens, or underscores for the take name.")
		return
	if not seconds.is_valid_int() or seconds.to_int() < min_seconds or seconds.to_int() > max_seconds:
		_fail("Choose a duration from %d to %d seconds." % [min_seconds, max_seconds])
		return
	var game = load("res://scenes/main.tscn").instantiate()
	var map_keys: Array[String] = []
	for info in game.MAPS:
		map_keys.append(info.key)
	if not map_key in map_keys:
		game.free()
		_fail("Unknown map. Choose one of: " + ", ".join(map_keys))
		return
	var directory = ProjectSettings.globalize_path(DoodleReplay.BUNDLED_DIRECTORY)
	var output = directory.path_join(take + ".json")
	if FileAccess.file_exists(output):
		game.free()
		_fail("Take already exists: " + output)
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		game.free()
		_fail("Could not create the replay directory: " + directory)
		return

	game.replay_recorder = true
	game.save_path = "user://replay-recorder.cfg"
	root.add_child(game)
	game.map_key = map_key
	_setup_banner(game.ui.theme)
	banner.text = "Loading the map…"
	await game.start_game(1)

	paused = true
	for count in range(COUNTDOWN_SECONDS, 0, -1):
		banner.text = "Recording starts in %d" % count
		await create_timer(1.0).timeout
	game.replay.start_recording()
	paused = false
	var target_frames = roundi(seconds.to_int() / DoodleReplay.SAMPLE_INTERVAL)
	while game.replay.recorded.size() < target_frames and (game.playing or game.paused):
		var time_left = ceili((target_frames - game.replay.recorded.size()) * DoodleReplay.SAMPLE_INTERVAL)
		banner.text = "Recording paused" if game.paused else "Recording · %02d:%02d" % [time_left / 60, time_left % 60]
		await process_frame

	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var code = 1
	if FileAccess.file_exists(output):
		banner.text = "Take already exists: " + take
	elif game.replay.recorded.size() < DoodleReplay.MIN_SAVE_FRAMES:
		banner.text = "Take too short. Run the recorder again to retry."
	elif game.replay.save_recording(map_key, output):
		print("Saved menu take: " + output)
		banner.text = "Saved " + take + ".json"
		code = 0
	else:
		banner.text = "Could not save the take: " + output
	if code != 0:
		printerr(banner.text)
	await create_timer(2.0).timeout
	game._clear_world()
	game.sound.stop_all()
	game.queue_free()
	await create_timer(0.1).timeout
	quit(code)

func _setup_banner(theme: Theme) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	root.add_child(layer)
	banner = Label.new()
	banner.theme = theme
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_stylebox_override("normal", DoodlePen.box(DoodlePen.PAPER, DoodlePen.INK, 2.0, 0.0))
	layer.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_bottom = 56

func _argument(name: String, fallback: String) -> String:
	var prefix = "--" + name + "="
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
