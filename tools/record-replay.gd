extends SceneTree

const COUNTDOWN_SECONDS := 3
const MIN_PICKER_SECONDS := 10
const MIN_DIRECT_SECONDS := ceili(DoodleReplay.MIN_SAVE_FRAMES * DoodleReplay.SAMPLE_INTERVAL)
const MAX_SECONDS := 120
const DURATION_STEP := 5
var banner: Label

func _initialize() -> void:
	_record.call_deferred()

func _record() -> void:
	var map_key = _argument("map", "")
	var duration = _argument("seconds", "30")
	var take = _argument("take", "")
	var name_pattern = RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9_-]*$")
	if not take.is_empty() and name_pattern.search(take) == null:
		_fail("Use letters, numbers, hyphens, or underscores for the take name.")
		return
	var seconds = duration.to_int()
	var min_seconds = MIN_PICKER_SECONDS if map_key.is_empty() else MIN_DIRECT_SECONDS
	if not duration.is_valid_int() or seconds < min_seconds or seconds > MAX_SECONDS:
		_fail("Choose a duration from %d to %d seconds." % [min_seconds, MAX_SECONDS])
		return
	if map_key.is_empty() and DisplayServer.get_name() == "headless":
		_fail("Pass --map=<key> when recording without a window.")
		return
	var game = load("res://scenes/main.tscn").instantiate()
	var map_keys: Array[String] = []
	for info in game.MAPS:
		map_keys.append(info.key)
	if not map_key.is_empty() and not map_key in map_keys:
		game.free()
		_fail("Unknown map. Choose one of: " + ", ".join(map_keys))
		return
	game.replay_recorder = true
	game.save_path = "user://replay-recorder.cfg"
	root.add_child(game)
	if map_key.is_empty():
		_show_map_picker(game, take, seconds)
	else:
		_record_take(map_key, game, take, seconds)

func _show_map_picker(game: Node, take: String, seconds: int) -> void:
	game._clear_menu("Choose a map", "", true)
	game.menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	game.menu.custom_minimum_size.x = 880
	game.menu.offset_left = -440
	game.menu.offset_right = 440
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	game._populate_map_cards(grid, true, func(key: String): game.map_key = key)
	game.menu_items.add_child(grid)

	var duration_row = HBoxContainer.new()
	duration_row.add_theme_constant_override("separation", 16)
	game.menu_items.add_child(duration_row)
	var duration_label = Label.new()
	duration_label.custom_minimum_size.x = 230
	duration_row.add_child(duration_label)
	var duration = HSlider.new()
	duration.min_value = MIN_PICKER_SECONDS
	duration.max_value = MAX_SECONDS
	duration.step = DURATION_STEP
	duration.value = seconds
	duration_label.text = "Recording length: %d s" % int(duration.value)
	duration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration.custom_minimum_size.y = 36
	duration.value_changed.connect(func(value: float): duration_label.text = "Recording length: %d s" % int(value))
	duration_row.add_child(duration)

	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	game.menu_items.add_child(actions)
	var exit: Button = game._button("EXIT", quit, "RedOutlineButton")
	exit.set_meta("menu_label", "CANCEL")
	exit.custom_minimum_size.x = 200
	exit.reparent(actions)
	var start: Button = game._button("START", func(): _record_take(game.map_key, game, take, int(duration.value)), "StartButton")
	start.custom_minimum_size.x = 200
	start.reparent(actions)

func _record_take(map_key: String, game: Node, take: String, seconds: int) -> void:
	if game.starting or game.playing:
		return
	if take.is_empty():
		take = map_key + "-" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "-")
	var directory = ProjectSettings.globalize_path(DoodleReplay.BUNDLED_DIRECTORY)
	var output = directory.path_join(take + ".json")
	if FileAccess.file_exists(output):
		_fail("Take already exists: " + output)
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("Could not create the replay directory: " + directory)
		return

	game.map_key = map_key
	_setup_banner(game.ui.theme)
	banner.text = "Loading the map…"
	await game.start_game(1)

	paused = true
	for count in range(COUNTDOWN_SECONDS, 0, -1):
		banner.text = "Recording starts in %d" % count
		await create_timer(1.0).timeout
	var target_frames = roundi(seconds / DoodleReplay.SAMPLE_INTERVAL)
	game.replay.start_recording(target_frames)
	paused = false
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
