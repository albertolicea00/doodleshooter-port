extends Node3D

var level: DoodleLevel
var player: DoodlePlayer
var touch: DoodleTouchControls
var sound: DoodleSound
var region: NavigationRegion3D
var enemy_stats: Dictionary
var enemies: Array[DoodleEnemy] = []
var projectiles: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var playing = false
var paused = false
var wave = 0
var score = 0
var kills = 0
var checkpoint = 0
var best = 0
var spawn_queue: Array[String] = []
var spawn_timer = 2.0
var intermission = 0.0
var map_key = "district"
var online_map_key = "district"
var online_custom_map_key = ""
var hud: DoodleHud
var center_text: Label
var scoreboard: Label
var menu_backdrop: ColorRect
var editor_bar: PanelContainer
var quality = 1
# District, Jungle, and Mexico come from the original game; the others are port additions built by tools/make-maps.py.
const MAPS = [
	{"key": "district", "name": "Doodle District", "music": "district"},
	{"key": "jungle", "name": "Doodle Jungle", "music": "district"},
	{"key": "mexico", "name": "Doodle Mexico", "music": "mexico"},
	{"key": "castle", "name": "Doodle Castle", "music": "district"},
	{"key": "harbor", "name": "Doodle Harbor", "music": "mexico"},
	{"key": "pyramid", "name": "Doodle Pyramid", "music": "mexico"},
	{"key": "station", "name": "Doodle Station", "music": "district"},
	{"key": "forest", "name": "Doodle Forest", "music": "district"},
	{"key": "school", "name": "Doodle School", "music": "district"},
	{"key": "military", "name": "Doodle Base", "music": "mexico"}]
const PREVIEW_FRAMES = 120
const PREVIEW_COLUMNS = 12
const PREVIEW_SIZE = 160
var show_fps = true
var smokes: Array = []
# Port additions: how smeared, swaying and greyed-out the view is right now.
var feel_blur = 0.0
var feel_dizzy = 0.0
var feel_haze = 0.0
var daze = 0.0
# How much smoke the player has breathed; it wears off over about six seconds after leaving the cloud.
var smoke_dose = 0.0
var feel_overlay: ColorRect
var screen_effects = true
# 0: the original's crossed hatching, 1: the port's coloured-pencil shading.
var shading = 1
var enemy_smoke = 20.0
# Port-only survival tuning; Hard keeps the former Normal numbers.
var difficulty = 1
var wave_size = 0
var health_modifier = 1.0
var menu: PanelContainer
var menu_scroll: ScrollContainer
var menu_items: VBoxContainer
var pulsed_control: Control = null
var auto_scroll = false
var auto_scroll_wait = 0.0
var auto_scroll_pos = 0.0
var menu_nav_last_action = ""
var menu_nav_last_msec = -1000
var replay := DoodleReplay.new()
var hit_marker = 0.0
var hurt_flash = 0.0
var hurt_overlay: ColorRect
var ui: Control
var preferences = ConfigFile.new()
var use_touch = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
var fullscreen = false
var starting = false
var save_path = "user://progress.cfg"
var particles: DoodleParticles
var shake = 0.0
var trajectory: Array[Vector3] = []
var trajectory_nodes: Array[MeshInstance3D] = []
var scope: ColorRect
var combo = 0
var combo_timer = 0.0
var modifier = ""
var speed_modifier = 1.0
var damage_modifier = 1.2
var swarm = false
var capture_mode = false
var network: DoodleNetwork
var remote_players: Dictionary = {}
var player_name = "Doodler"
var server_url = "ws://127.0.0.1:8911"
var online_spawn = 0
var death_timer = 0.0
var online_results: Array = []
var server_input: LineEdit
var name_input: LineEdit
var code_input: LineEdit
var status_message = ""
var pending_broken: Array = []
var last_room_code = ""
var match_mode = "survival"
var bot_count = 5
var bot_difficulty = 1
var bot_minutes = 10
var lan_bot_count = 1
var lan_bot_difficulty = 1
var lan_minutes = 10
var controls_xbox = false
var controller_vibration = true
var controller_light = true
var last_joy_light = Color(-1, -1, -1, -1)
var joy_light_timer = 0.0
var rumble_until_msec = 0
var rumble_power = 0.0
var last_rumble = Vector3.ZERO
var layout_return: Callable = Callable()
var lobby_return: Callable = Callable()
var lobby_map_row: HBoxContainer
var bot_match: DoodleBotMatch
var lan_server: DoodleLanServer
var lan_address = ""
var lan_host_note = ""

func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		save_path = "res://.smoke-progress.cfg"
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	_setup_inputs()
	preferences.load(save_path)
	best = int(preferences.get_value("progress", "best", 0))
	checkpoint = int(preferences.get_value("progress", "checkpoint", 0))
	enemy_stats = ReferenceAssets.read_json("enemy_stats")
	sound = DoodleSound.new()
	add_child(sound)
	for setting in ["music_enabled", "music_volume", "effects_volume", "enabled"]:
		sound.set(setting, preferences.get_value("audio", setting, sound.get(setting)))
	particles = DoodleParticles.new()
	add_child(particles)
	bot_match = DoodleBotMatch.new()
	bot_match.game = self
	add_child(bot_match)
	network = DoodleNetwork.new()
	add_child(network)
	network.received.connect(_network_packet)
	network.failed.connect(_network_failure)
	player_name = preferences.get_value("online", "name", "Doodler")
	server_url = preferences.get_value("online", "url", "ws://10.0.2.2:8911" if OS.has_feature("android") else "ws://127.0.0.1:8911")
	_setup_ui()
	replay.attach(self)
	show_main_menu()
	if "--smoke" in OS.get_cmdline_user_args():
		run_smoke.call_deferred()
	elif capture_mode:
		run_capture.call_deferred()
	else:
		_load_menu_replay()

func _load_menu_replay() -> void:
	if is_instance_valid(region):
		return
	var map_keys: Array[String] = []
	for info in MAPS:
		map_keys.append(info.key)
	region = NavigationRegion3D.new()
	add_child(region)
	level = DoodleLevel.new()
	region.add_child(level)
	replay.load_or_default(null, "district")
	var bg_map = replay.playback_map if replay.playback_map in map_keys else "district"
	level.load_map(bg_map, false)
	if not FileAccess.file_exists(DoodleReplay.REPLAY_PATH):
		replay.build_default(level, bg_map)
	replay.step_playback(0.0, true)

func _setup_inputs() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "dash": KEY_C, "grapple": KEY_Q, "reload": KEY_R, "slash": KEY_F, "grenade": KEY_G, "pause": KEY_ESCAPE, "scoreboard": KEY_TAB, "weapon_0": KEY_1, "weapon_1": KEY_2, "weapon_2": KEY_3, "weapon_3": KEY_4, "weapon_4": KEY_5, "weapon_5": KEY_6, "weapon_6": KEY_7, "smoke": KEY_H}
	for action in keys:
		InputMap.add_action(action)
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for entry in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT], ["prev_weapon", MOUSE_BUTTON_WHEEL_UP], ["next_weapon", MOUSE_BUTTON_WHEEL_DOWN]]:
		InputMap.add_action(entry[0])
		var event = InputEventMouseButton.new()
		event.button_index = entry[1]
		InputMap.action_add_event(entry[0], event)
	InputMap.add_action("sprint_toggle")
	for entry in [["jump", JOY_BUTTON_A], ["dash", JOY_BUTTON_B], ["reload", JOY_BUTTON_X], ["next_weapon", JOY_BUTTON_Y], ["next_weapon", JOY_BUTTON_DPAD_RIGHT], ["prev_weapon", JOY_BUTTON_DPAD_LEFT], ["grapple", JOY_BUTTON_LEFT_SHOULDER], ["slash", JOY_BUTTON_RIGHT_SHOULDER], ["grenade", JOY_BUTTON_RIGHT_STICK], ["grenade", JOY_BUTTON_DPAD_UP], ["smoke", JOY_BUTTON_DPAD_DOWN], ["scoreboard", JOY_BUTTON_BACK], ["pause", JOY_BUTTON_START], ["sprint_toggle", JOY_BUTTON_LEFT_STICK], ["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var event = InputEventJoypadButton.new()
		event.button_index = entry[1]
		InputMap.action_add_event(entry[0], event)
	for entry in [["left", JOY_AXIS_LEFT_X, -1], ["right", JOY_AXIS_LEFT_X, 1], ["forward", JOY_AXIS_LEFT_Y, -1], ["back", JOY_AXIS_LEFT_Y, 1], ["look_left", JOY_AXIS_RIGHT_X, -1], ["look_right", JOY_AXIS_RIGHT_X, 1], ["look_up", JOY_AXIS_RIGHT_Y, -1], ["look_down", JOY_AXIS_RIGHT_Y, 1], ["fire", JOY_AXIS_TRIGGER_RIGHT, 1], ["aim", JOY_AXIS_TRIGGER_LEFT, 1]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
		var event = InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0], event)

func _setup_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.theme = DoodlePen.theme(load("res://assets/fonts/PatrickHand-Regular.ttf"))
	var paper = ColorRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_mat = ShaderMaterial.new()
	paper_mat.shader = preload("res://shaders/paper.gdshader")
	paper.material = paper_mat
	ui.add_child(paper)
	# Drawn first so it smears the world but leaves the paper lines and HUD sharp.
	feel_overlay = ColorRect.new()
	feel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feel_material = ShaderMaterial.new()
	feel_material.shader = preload("res://shaders/woozy.gdshader")
	feel_overlay.material = feel_material
	feel_overlay.visible = false
	ui.add_child(feel_overlay)
	ui.move_child(feel_overlay, 0)
	hud = DoodleHud.new()
	hud.game = self
	hud.visible = false
	ui.add_child(hud)
	center_text = Label.new()
	center_text.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center_text.position.y = 150
	center_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_text.add_theme_font_size_override("font_size", 34)
	center_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center_text)
	scoreboard = Label.new()
	scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scoreboard.position = Vector2(-220, -190)
	scoreboard.custom_minimum_size = Vector2(440, 380)
	scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scoreboard.add_theme_font_size_override("font_size", 25)
	scoreboard.add_theme_stylebox_override("normal", DoodlePen.box(Color(DoodlePen.PAPER, 0.94), DoodlePen.INK, 3.0, -0.5))
	scoreboard.visible = false
	ui.add_child(scoreboard)
	touch = DoodleTouchControls.new()
	ui.add_child(touch)
	touch.visible = false
	touch.custom = preferences.get_value("touch", "layout", {})
	touch.opacity = preferences.get_value("touch", "opacity", 1.0)
	touch.options.merge(preferences.get_value("touch", "options", {}), true)
	# Layout 2 moved every default; old offsets were relative to the old spots,
	# so they are dropped and the new reload button is switched on.
	if int(preferences.get_value("touch", "layout_version", 1)) < 2:
		touch.custom = {}
		touch.options.reload_button = true
		preferences.set_value("touch", "layout", {})
		preferences.set_value("touch", "layout_version", 2)
	apply_quality(int(preferences.get_value("video", "quality", 1)))
	show_fps = preferences.get_value("video", "fps", true)
	screen_effects = preferences.get_value("video", "screen_effects", true)
	shading = clampi(int(preferences.get_value("video", "shading", 1)), 0, 1)
	ReferenceAssets.set_style(float(shading))
	fullscreen = bool(preferences.get_value("video", "fullscreen", false))
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless" and not "--smoke" in OS.get_cmdline_user_args() and not capture_mode:
		apply_fullscreen(fullscreen)
	difficulty = clampi(int(preferences.get_value("survival", "difficulty", 1)), 0, 3)
	wave_size = clampi(int(preferences.get_value("survival", "wave_size", 0)), 0, 2)
	bot_minutes = clampi(int(preferences.get_value("bots", "minutes", 10)), DoodleBotMatch.MIN_MINUTES, DoodleBotMatch.MAX_MINUTES)
	controller_vibration = bool(preferences.get_value("controller", "vibration", true))
	controller_light = bool(preferences.get_value("controller", "light", true))
	_update_controller_light(0.0, true)
	hurt_overlay = ColorRect.new()
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_overlay.color = Color(0.86, 0.12, 0.2, 0)
	var hurt_material = ShaderMaterial.new()
	hurt_material.shader = preload("res://shaders/hurt.gdshader")
	hurt_overlay.material = hurt_material
	ui.add_child(hurt_overlay)
	# The original dims the scene with translucent paper behind every panel.
	menu_backdrop = ColorRect.new()
	menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_backdrop.color = Color(DoodlePen.PAPER, 0.55)
	ui.add_child(menu_backdrop)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-340, -328)
	menu.custom_minimum_size = Vector2(680, 0)
	var menu_hint = RichTextLabel.new()
	var red_hex = DoodlePen.RED.to_html(false)
	menu_hint.bbcode_enabled = true
	menu_hint.fit_content = true
	menu_hint.scroll_active = false
	menu_hint.selection_enabled = false
	menu_hint.focus_mode = Control.FOCUS_NONE
	menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	menu_hint.offset_top = 8
	menu_hint.add_theme_font_size_override("normal_font_size", 18)
	menu_hint.add_theme_color_override("default_color", Color(DoodlePen.INK, 0.8))
	menu_hint.text = "[center][color=#%s]A[/color] / [img=18x18]res://assets/ui/controller-cross.svg[/img] Select   ·   Arrows / D-pad Move & Scroll   ·   [color=#%s]B[/color] / [img=18x18]res://assets/ui/controller-circle.svg[/img] Back[/center]" % [red_hex, red_hex]
	menu_items = VBoxContainer.new()
	menu_items.add_theme_constant_override("separation", 12)
	menu_scroll = ScrollContainer.new()
	menu_scroll.custom_minimum_size = Vector2(0, 604)
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_scroll.scroll_deadzone = 12
	menu.add_child(menu_scroll)
	var update_hint = func(_val = 0.0):
		var at_top = true if menu_scroll == null else menu_scroll.scroll_vertical <= 2
		menu_hint.visible = menu.visible and at_top
	menu_scroll.get_v_scroll_bar().value_changed.connect(update_hint)
	menu.visibility_changed.connect(func():
		menu_backdrop.visible = menu.visible
		update_hint.call())
	ui.add_child(menu)
	ui.add_child(menu_hint)
	var menu_pad = MarginContainer.new()
	menu_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_bottom"]:
		menu_pad.add_theme_constant_override(side, 12)
	menu_pad.add_theme_constant_override("margin_top", 28)
	menu_scroll.add_child(menu_pad)
	menu_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_pad.add_child(menu_items)
	# Toolbar for the touch layout editor.
	editor_bar = PanelContainer.new()
	editor_bar.add_theme_stylebox_override("panel", DoodlePen.box(Color(DoodlePen.PAPER, 0.95), DoodlePen.BLACK, 2.5, 0.0, Vector2(14, 8)))
	# Free-floating: it opens in the middle of the screen and its top line drags it,
	# so controls can be placed where it first appears.
	editor_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor_bar.visible = false
	ui.add_child(editor_bar)
	var editor_rows = VBoxContainer.new()
	editor_bar.add_child(editor_rows)
	var editor_handle = Label.new()
	editor_handle.text = "~ drag this line to move the bar ~"
	editor_handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor_handle.add_theme_font_size_override("font_size", 18)
	editor_handle.add_theme_color_override("font_color", DoodlePen.RED)
	editor_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	editor_handle.gui_input.connect(func(event):
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			editor_bar.position = (editor_bar.position + event.relative).clamp(Vector2.ZERO, ui.size - editor_bar.size))
	editor_rows.add_child(editor_handle)
	var editor_hint = Label.new()
	editor_hint.text = "Drag a control to move it · tap one to resize, fade, copy or delete it"
	editor_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor_hint.add_theme_font_size_override("font_size", 20)
	editor_rows.add_child(editor_hint)
	var tool_rows = [
		[["SMALLER", func(): touch.resize_selected(-0.1), "BlackButton"], ["BIGGER", func(): touch.resize_selected(0.1), "BlackButton"], ["FAINTER", func(): touch.fade(-0.1), "BlackButton"], ["BOLDER", func(): touch.fade(0.1), "BlackButton"]],
		[["DUPLICATE", func(): touch.duplicate_selected(), "BlackButton"], ["DELETE", func(): touch.delete_selected(), "BlackButton"], ["RESET", func(): touch.restore_defaults(), "RedButton"], ["DONE", close_layout_editor, "GreenButton"]]]
	editor_hint.add_theme_color_override("font_color", DoodlePen.BLACK)
	for row in tool_rows:
		var editor_tools = HBoxContainer.new()
		editor_tools.add_theme_constant_override("separation", 8)
		editor_tools.alignment = BoxContainer.ALIGNMENT_CENTER
		editor_rows.add_child(editor_tools)
		for tool in row:
			var button = Button.new()
			button.text = tool[0]
			button.theme_type_variation = tool[2]
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(tool[1])
			editor_tools.add_child(button)
			if tool[0] == "DELETE":
				touch.delete_button = button
	touch.toolbar = editor_bar
	scope = ColorRect.new()
	scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_material = ShaderMaterial.new()
	scope_material.shader = preload("res://shaders/scope.gdshader")
	scope.material = scope_material
	scope.visible = false
	ui.add_child(scope)
	ui.move_child(scope, 1)

func _clear_menu(title: String, subtitle: String) -> void:
	menu.remove_theme_stylebox_override("panel")
	menu.custom_minimum_size.x = 680
	menu.offset_left = -340
	menu.offset_right = 340
	Input.emulate_mouse_from_touch = true
	auto_scroll = false
	auto_scroll_wait = 0.0
	auto_scroll_pos = 0.0
	menu_scroll.scroll_vertical = 0
	for child in menu_items.get_children():
		child.free()
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", -2)
	menu_items.add_child(header)
	var heading = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 60)
	heading.add_theme_constant_override("line_spacing", -10)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.rotation_degrees = -1.2
	heading.resized.connect(func(): heading.pivot_offset = heading.size * 0.5)
	header.add_child(heading)
	var sub = Label.new()
	sub.text = subtitle
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 480
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.visible = subtitle != ""
	header.add_child(sub)
	menu.visible = true
	_fit_menu.call_deferred()
	hud.visible = false
	center_text.visible = false
	if scope != null:
		scope.visible = false
	touch.visible = false
	touch.editing = false
	editor_bar.visible = false
	touch.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Short screens shrink the sheet to their content; long ones scroll to the screen edges.
func _fit_menu() -> void:
	_prepare_menu_controls(menu_items)
	menu_scroll.follow_focus = false
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus == null or not menu_items.is_ancestor_of(current_focus):
		var first = _first_focusable(menu_items)
		if first != null:
			first.grab_focus()
	# Wrapped text reports its final height one frame after it is added.
	for pass_index in 2:
		var padding = menu.get_theme_stylebox("panel").get_minimum_size().y
		var viewport_h = maxf(ui.size.y, 720.0)
		var max_h = viewport_h - (44.0 if padding > 0.0 else 0.0)
		var content_h = menu_scroll.get_child(0).get_combined_minimum_size().y
		var height = minf(content_h, max_h - padding)
		menu_scroll.custom_minimum_size.y = height
		var top = maxf(36.0 - viewport_h * 0.5, -(height + padding) * 0.5) if padding > 0.0 else -(height + padding) * 0.5
		menu.offset_top = top
		menu.offset_bottom = top + height + padding
		await get_tree().process_frame
	menu_scroll.scroll_vertical = 0
	menu_scroll.follow_focus = true

func _prepare_menu_controls(node: Node) -> void:
	if node is BaseButton:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		if not node.has_meta("focus_blip"):
			node.set_meta("focus_blip", true)
			node.focus_entered.connect(func(): _blip_control(node))
	elif node is LineEdit:
		node.keep_editing_on_text_submit = false
	elif node is RichTextLabel:
		node.selection_enabled = false
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_prepare_menu_controls(child)

func _blip_control(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(1.035, 1.035)
	var tween = control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _first_focusable(node: Node) -> Control:
	if node is Control and not (node is LineEdit) and node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL:
		if not (node is BaseButton and node.disabled):
			return node
	for child in node.get_children():
		var found = _first_focusable(child)
		if found != null:
			return found
	return null

func _button(text: String, callback: Callable, variation: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size.y = 52
	# Let the scroll container cancel the press when a tap becomes a swipe.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	# Menu callbacks rebuild controls after the button finishes its input event.
	button.pressed.connect(callback, CONNECT_DEFERRED)
	menu_items.add_child(button)
	return button

# Controls, Settings and Credits side by side, in the main and pause menus.
func _info_row() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	menu_items.add_child(row)
	for entry in [["CONTROLS", show_controls], ["SETTINGS", show_settings], ["CREDITS", show_credits]]:
		var button = _button(entry[0], entry[1], "AltButton")
		button.reparent(row)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

# Side-by-side outlined choices; the selected one is filled with ink (.mapbtn.on).
func _choices(labels: Array, selected: int, callback: Callable) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var group = ButtonGroup.new()
	for i in labels.size():
		var button = Button.new()
		button.text = labels[i]
		button.theme_type_variation = "AltButton"
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == selected
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(callback.bind(i))
		row.add_child(button)
	menu_items.add_child(row)

func _toggle(text: String, value: bool, callback: Callable) -> void:
	var button = _button("", func(): pass, "AltButton")
	button.toggle_mode = true
	button.button_pressed = value
	button.text = text + (": on" if value else ": off")
	button.toggled.connect(func(on): button.text = text + (": on" if on else ": off"); callback.call(on))

func _close_network() -> void:
	if network != null:
		network.close()
	if is_instance_valid(lan_server):
		lan_server.stop()
		lan_server.queue_free()
		lan_server = null
	lan_host_note = ""

func _menu_gap(height: float) -> void:
	var gap = Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_items.add_child(gap)

func show_main_menu() -> void:
	stop_rumble()
	if not "--smoke" in OS.get_cmdline_user_args():
		replay.save_recording(map_key)
		replay.start_recording()
	_close_network()
	bot_match.stop()
	match_mode = "survival"
	_clear_remote_players()
	playing = false
	paused = false
	_clear_menu("DOODLE SHOOTER ", "native port, portable too")
	var header = menu_items.get_child(0)
	var heading = header.get_child(0)
	var title_row = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 0)
	title_row.rotation_degrees = -1.2
	title_row.resized.connect(func(): title_row.pivot_offset = title_row.size * 0.5)
	header.add_child(title_row)
	header.move_child(title_row, 0)
	heading.rotation_degrees = 0.0
	heading.add_theme_constant_override("outline_size", 3)
	heading.add_theme_color_override("font_outline_color", DoodlePen.INK)
	heading.reparent(title_row)
	var port_label = Label.new()
	port_label.text = "port"
	port_label.add_theme_font_size_override("font_size", 60)
	port_label.add_theme_constant_override("line_spacing", -10)
	port_label.add_theme_color_override("font_color", DoodlePen.RED)
	port_label.add_theme_constant_override("outline_size", 3)
	port_label.add_theme_color_override("font_outline_color", DoodlePen.RED)
	title_row.add_child(port_label)
	var foot = RichTextLabel.new()
	foot.bbcode_enabled = true
	foot.fit_content = true
	foot.scroll_active = false
	foot.selection_enabled = false
	foot.focus_mode = Control.FOCUS_NONE
	foot.custom_minimum_size.x = 480
	foot.add_theme_font_size_override("normal_font_size", 18)
	foot.modulate.a = 0.85
	foot.text = "[center]v%s · by [url=https://github.com/albertolicea00/doodleshooter-port]@albertolicea00[/url][/center]" % ProjectSettings.get_setting("application/config/version")
	foot.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	header.add_child(foot)
	_menu_gap(6)
	var play_offline = _button("START SOLO", show_offline_menu, "StartButton")
	play_offline.custom_minimum_size.x = 420
	play_offline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_offline.rotation_degrees = -1.0
	play_offline.resized.connect(func(): play_offline.pivot_offset = play_offline.size * 0.5)
	var network_row = HBoxContainer.new()
	network_row.add_theme_constant_override("separation", 10)
	network_row.custom_minimum_size.x = 460
	network_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_items.add_child(network_row)
	var online = _button("PLAY ONLINE", show_online_menu, "RedButton")
	online.reparent(network_row)
	online.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var local = _button("PLAY LAN", show_lan_menu, "RedOutlineButton")
	local.reparent(network_row)
	local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_gap(8)
	for entry in [["CONTROLS", show_controls], ["SETTINGS", show_settings], ["CREDITS", show_credits]]:
		var info_btn = _button(entry[0], entry[1], "AltButton")
		info_btn.custom_minimum_size = Vector2(420, 44)
		info_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu_gap(6)
	var exit = _button("QUIT GAME", func(): get_tree().quit(), "RedOutlineButton")
	exit.custom_minimum_size.x = 240
	exit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func map_info(key: String) -> Dictionary:
	for info in MAPS:
		if info.key == key:
			return info
	return MAPS[0]

func _map_preview_region() -> Rect2:
	var frame_index = int(Time.get_ticks_msec() * 30 / 1000) % PREVIEW_FRAMES
	return Rect2(Vector2(frame_index % PREVIEW_COLUMNS, frame_index / PREVIEW_COLUMNS) * PREVIEW_SIZE, Vector2.ONE * PREVIEW_SIZE)

func _populate_map_cards(container: Container, mini: bool, on_pick: Callable, excluded_key: String = "", selected_key: String = "__map_key__") -> void:
	var active_key: String = map_key if selected_key == "__map_key__" else selected_key
	var frames: Array[AtlasTexture] = []
	var reel = Timer.new()
	reel.wait_time = 1.0 / 30.0
	reel.autostart = true
	var selection = ButtonGroup.new()
	reel.timeout.connect(func():
		var region = _map_preview_region()
		for frame in frames:
			frame.region = region)
	container.add_child(reel)
	for info in MAPS:
		if info.key == excluded_key:
			continue
		var chosen: bool = info.key == active_key
		var card = Button.new()
		card.set_meta("map_key", info.key)
		card.theme_type_variation = "AltButton"
		card.toggle_mode = true
		card.button_group = selection
		card.button_pressed = chosen
		card.custom_minimum_size = Vector2(0, 116) if mini else Vector2(194, 212)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var column = VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6 if mini else 10)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(column)
		var picture = TextureRect.new()
		var preview = "res://assets/previews/%s.png" % info.key
		if ResourceLoader.exists(preview):
			# The preview is a tiled atlas of evenly spaced views around the map.
			var frame = AtlasTexture.new()
			frame.atlas = load(preview)
			frame.filter_clip = true
			frame.region = _map_preview_region()
			picture.texture = frame
			frames.append(frame)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var preview_material = ShaderMaterial.new()
		preview_material.shader = preload("res://shaders/map_preview.gdshader")
		picture.material = preview_material
		picture.resized.connect(func(): preview_material.set_shader_parameter("preview_size", picture.size))
		column.add_child(picture)
		var label = Label.new()
		label.text = info.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16 if mini else 20)
		label.add_theme_color_override("font_color", DoodlePen.PAPER if chosen else DoodlePen.INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		card.toggled.connect(func(pressed: bool): label.add_theme_color_override("font_color", DoodlePen.PAPER if pressed else DoodlePen.INK))
		var key: String = info.key
		card.pressed.connect(func(): on_pick.call(key), CONNECT_DEFERRED)
		container.add_child(card)

# Square cards with a rendered preview of each map.
func show_map_menu(back: Callable, pick: Callable = Callable(), excluded_key: String = "", selected_key: String = "__map_key__") -> void:
	_clear_menu("Choose a custom map" if excluded_key != "" else "Choose a map", "District, Jungle and Mexico are original · the rest are new in this port")
	if excluded_key != "":
		menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_populate_map_cards(grid, false, func(key: String):
		if excluded_key == "":
			map_key = key
		if pick.is_valid():
			pick.call(key)
		back.call(), excluded_key, selected_key)
	menu_items.add_child(grid)
	if excluded_key == "":
		_back_button(back, "BACK TO LOBBY")

func _card_wrap(start: int, split: int = -1, align_bottom: bool = false) -> void:
	if split >= 0:
		var content = menu_items.get_children()
		var cards = HBoxContainer.new()
		cards.add_theme_constant_override("separation", 24)
		menu_items.add_child(cards)
		for slice in [content.slice(start, split), content.slice(split)]:
			var card = _make_card(slice, align_bottom)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cards.add_child(card)
		return
	menu_items.add_child(_make_card(menu_items.get_children().slice(start), align_bottom))

func _make_card(content: Array[Node], align_bottom: bool = false) -> PanelContainer:
	var card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", DoodlePen.box(Color(0.98, 0.972, 0.933, 0.95), DoodlePen.INK, 3.0, -0.35, Vector2(24, 16)))
	var items = VBoxContainer.new()
	items.add_theme_constant_override("separation", 12)
	card.add_child(items)
	for child in content:
		if align_bottom and child == content.back():
			var spacer = Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			items.add_child(spacer)
		child.reparent(items)
	return card

func _back_button(callback: Callable, label: String = "BACK TO MAIN MENU") -> void:
	if callback == show_main_menu and label == "BACK TO MAIN MENU":
		var back = _button(label, callback, "RedButton")
		back.custom_minimum_size.x = 240
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	menu_items.add_child(row)
	var back = _button(label, callback, "RedOutlineButton")
	back.custom_minimum_size.x = 240
	back.reparent(row)
	var main_btn = _button("BACK TO MAIN MENU", show_main_menu, "RedButton")
	main_btn.custom_minimum_size.x = 240
	main_btn.reparent(row)

func show_settings() -> void:
	_clear_menu("Settings", "Choose how you want to play")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	var top_row = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 16)
	menu_items.add_child(top_row)
	if not OS.has_feature("mobile"):
		_toggle("Fullscreen", fullscreen, func(value): apply_fullscreen(value); save_settings())
		var fs_button = menu_items.get_child(-1) as Button
		fs_button.custom_minimum_size.x = 220
		fs_button.reparent(top_row)
	var touch_button = _button("TOUCH & AIMING", show_touch_settings)
	touch_button.custom_minimum_size.x = 260
	touch_button.reparent(top_row)
	var controls_button = _button("CONTROLS", func(): show_controls(show_settings, "BACK TO SETTINGS"), "RedOutlineButton")
	controls_button.custom_minimum_size.x = 220
	controls_button.reparent(top_row)
	var start = menu_items.get_child_count()
	_credit_section("Sound", "")
	_slider("Music volume", sound.music_volume, 0, 1, func(value): sound.music_volume = value; save_settings())
	_slider("Effects volume", sound.effects_volume, 0, 1, func(value): sound.effects_volume = value; save_settings())
	_toggle("Sound effects", sound.enabled, func(value): sound.enabled = value; save_settings())
	_toggle("Original soundtrack", sound.music_enabled, func(value): sound.music_enabled = value; save_settings())
	_credit_section("Controller & motion", "")
	_choices(["Gyro off", "Gyro while aiming", "Gyro always"], touch.options.gyro, func(index): touch.options.gyro = index; save_settings())
	_toggle("Controller vibration", controller_vibration, func(value): controller_vibration = value; if not value: stop_rumble(); save_settings())
	_toggle("Controller light bar", controller_light, func(value): controller_light = value; _update_controller_light(0.0, true); save_settings())
	var split = menu_items.get_child_count()
	_credit_section("Graphics detail", "")
	_choices(["Low", "Medium", "High"], quality, func(index): apply_quality(index); save_settings())
	_credit_section("Shading", "")
	_choices(["Original hatching", "Coloured pencil"], shading, func(index): shading = index; ReferenceAssets.set_style(float(index)); save_settings())
	_toggle("Frame rate counter", show_fps, func(value): show_fps = value; save_settings())
	_toggle("Dizzy screen sway", screen_effects, func(value): screen_effects = value; save_settings())
	_card_wrap(start, split)
	if paused:
		_back_button(pause_menu, "BACK TO PAUSE")
	else:
		_back_button(show_main_menu)

# Low renders the scene at 70% size with straight pen strokes and no edge
# smoothing; Medium adds the hand-drawn stroke waver and 2x smoothing; High
# uses 4x smoothing.
func apply_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	get_viewport().scaling_3d_scale = [0.7, 1.0, 1.0][quality]
	ReferenceAssets.set_detail(float(quality))

func apply_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func show_controls(return_to: Callable = Callable(), return_label: String = "") -> void:
	_clear_menu("Controls", "")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	var touch_card = _controls_column(menu_items, "TOUCH", [
		"{Left thumb} move and sprint · drag up to the runner marker to keep running   {Drag elsewhere} look, even while firing",
		"{SLIDE} becomes {DASH} in the air   {Weapon bar} tap a weapon to switch · tap it again or use reload to reload"
	])
	var touch_header = HBoxContainer.new()
	touch_header.add_theme_constant_override("separation", 16)
	var touch_heading = touch_card.get_child(0) as Label
	touch_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	touch_card.add_child(touch_header)
	touch_card.move_child(touch_header, 0)
	touch_heading.reparent(touch_header)
	var touch_settings_button = _button("TOUCH & AIMING", func(): show_touch_settings(func(): show_controls(return_to, return_label), "BACK TO CONTROLS"))
	touch_settings_button.custom_minimum_size = Vector2(220, 42)
	touch_settings_button.reparent(touch_header)
	var customize_touch = _button("CUSTOMIZE LAYOUT", func(): show_layout_editor(func(): show_controls(return_to, return_label)), "RedOutlineButton")
	customize_touch.custom_minimum_size = Vector2(220, 42)
	customize_touch.reparent(touch_header)
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	menu_items.add_child(cards)
	_controls_column(cards, "MOUSE + KEYBOARD", [
		"{WASD} move   {Mouse} look   {Shift} sprint",
		"{LMB} fire / slash   {RMB} aim / block",
		"{Space} jump · press against a wall to wall jump",
		"{Space} again in the air: double jump",
		"{C} slide on the ground · air dash in the air",
		"{Q} grapple: tap to swing, hold to reel",
		"{Space} launch from the rope   {Q} again: release",
		"{F} quick katana slash   {R} reload",
		"{G} grenade · hold to throw further   {H} smoke",
		"{Tab} scoreboard (bot / network matches)   {Esc} pause",
		"{LMB + RMB} charged katana execution in survival",
		"{1–7 / Wheel} switch weapons"
	])
	var ps5_lines: Array[String] = [
		"{L stick} move   {R stick / Gyro} look   {L3} toggle sprint",
		"{R2} fire / slash   {L2} aim / block",
		"{×} jump / wall jump / double jump",
		"{○} slide on the ground · air dash in the air",
		"{L1} grapple: tap to swing, hold to reel",
		"{×} launch from the rope   {L1} again: release",
		"{L2 + R2} charged katana execution in survival",
		"{R1} quick katana slash, then back to your gun",
		"{□} reload   {△} next weapon",
		"{D-pad Left / Right} previous / next weapon",
		"{R3 / D-pad Up} grenade · hold to throw   {D-pad Down} smoke",
		"{Create} scoreboard (bot / network)   {Options} pause"
	]
	var controller = _controls_column(cards, "", ps5_lines)
	_controller_picker(controller, ps5_lines)
	if return_to.is_valid():
		_back_button(return_to, return_label if return_label != "" else "BACK TO SETTINGS")
	elif paused:
		_back_button(pause_menu, "BACK TO PAUSE")
	else:
		_back_button(show_main_menu)

func _controls_column(parent: Container, title: String, lines: Array[String]) -> VBoxContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", DoodlePen.box(Color(0.98, 0.972, 0.933, 0.95), DoodlePen.INK, 3.0, -0.35, Vector2(24, 16)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var heading = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	var legend = RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.fit_content = true
	legend.scroll_active = false
	legend.mouse_filter = Control.MOUSE_FILTER_PASS
	legend.add_theme_font_size_override("normal_font_size", 22)
	legend.add_theme_constant_override("line_separation", 2)
	legend.text = _controls_text(lines)
	column.add_child(legend)
	return column

func _controls_text(lines: Array[String]) -> String:
	# Braces mark inputs, keeping the actions in the default blue ink.
	var text = "\n".join(lines).replace("{", "[color=#%s]" % DoodlePen.RED.to_html(false)).replace("}", "[/color]")
	var symbols = {"□": "square", "△": "triangle", "○": "circle", "×": "cross"}
	for symbol in symbols:
		text = text.replace(symbol, "[img=22x22]res://assets/ui/controller-%s.svg[/img]" % symbols[symbol])
	return text

func _controller_picker(column: VBoxContainer, ps5_lines: Array[String]) -> void:
	var xbox_lines: Array[String] = []
	var bindings = {"{L stick}": "{LS}", "{R stick / Gyro}": "{RS / Gyro}", "{L3}": "{LS click}", "{R2}": "{RT}", "{L2}": "{LT}", "{×}": "{A}", "{○}": "{B}", "{L1}": "{LB}", "{L2 + R2}": "{LT + RT}", "{R1}": "{RB}", "{□}": "{X}", "{△}": "{Y}", "{R3 / D-pad Up}": "{RS click / D-pad Up}", "{Create}": "{View}", "{Options}": "{Menu}"}
	for line in ps5_lines:
		var translated = line
		for binding in bindings:
			translated = translated.replace(binding, bindings[binding])
		xbox_lines.append(translated)
	var legend = column.get_child(1) as RichTextLabel
	column.get_child(0).free()
	var picker = HBoxContainer.new()
	picker.add_theme_constant_override("separation", 10)
	column.add_child(picker)
	column.move_child(picker, 0)
	var rule = Control.new()
	rule.custom_minimum_size.y = 2
	column.add_child(rule)
	column.move_child(rule, 1)
	var group = ButtonGroup.new()
	var buttons: Array[Button] = []
	for index in 2:
		var button = Button.new()
		button.text = ["PS CONTROLLER", "XBOX CONTROLLER"][index]
		button.flat = true
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color(DoodlePen.INK, 0.55))
		for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, DoodlePen.INK)
		button.add_theme_font_size_override("font_size", 26)
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = controls_xbox == (index == 1)
		button.pressed.connect(func():
			controls_xbox = index == 1
			legend.text = _controls_text(xbox_lines if controls_xbox else ps5_lines)
			rule.queue_redraw()
			_fit_menu.call_deferred())
		button.focus_entered.connect(rule.queue_redraw)
		button.focus_exited.connect(rule.queue_redraw)
		button.resized.connect(rule.queue_redraw)
		buttons.append(button)
		picker.add_child(button)
	rule.draw.connect(func():
		for button in buttons:
			if button.button_pressed or button.has_focus():
				rule.draw_line(Vector2(button.position.x + 10, 1.0), Vector2(button.position.x + button.size.x - 10, 1.0), DoodlePen.INK, 2.0, true))
	legend.text = _controls_text(xbox_lines if controls_xbox else ps5_lines)

# Every merged or assisted behaviour is optional, as in large mobile shooters.
func show_touch_settings(return_to: Callable = Callable(), return_label: String = "") -> void:
	_clear_menu("Touch & aiming", "Changes apply immediately and are saved on this device")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	var top_row = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 16)
	menu_items.add_child(top_row)
	_toggle("Touch controls", use_touch, func(value): use_touch = value)
	var touch_toggle = menu_items.get_child(-1) as Button
	touch_toggle.custom_minimum_size.x = 280
	touch_toggle.reparent(top_row)
	var layout_button = _button("CUSTOMIZE LAYOUT", func(): show_layout_editor(func(): show_touch_settings(return_to, return_label)), "RedOutlineButton")
	layout_button.custom_minimum_size.x = 260
	layout_button.reparent(top_row)
	var start = menu_items.get_child_count()
	var option = func(key: String): return func(value): touch.options[key] = value; save_settings()
	_credit_section("Looking", "Applies to touch controls and the controller right stick.")
	_slider("Look sensitivity", touch.options.look, 0.3, 2.5, option.call("look"))
	_slider("Sensitivity while aiming", touch.options.aim_look, 0.2, 1.5, option.call("aim_look"))
	_toggle("Invert vertical look", touch.options.invert_y, option.call("invert_y"))
	_credit_section("Gyroscope", "Tilt your phone or motion controller (DualShock / DualSense) to aim, even with touch controls hidden.")
	_choices(["Off", "While aiming", "Always"], touch.options.gyro, option.call("gyro"))
	_slider("Gyroscope sensitivity", touch.options.gyro_speed, 0.3, 3.0, option.call("gyro_speed"))
	var split = menu_items.get_child_count()
	_credit_section("Moving", "")
	_toggle("Fixed joystick", touch.options.fixed_stick, option.call("fixed_stick"))
	_toggle("Sprint with a full forward push", touch.options.stick_sprint, option.call("stick_sprint"))
	_toggle("Run lock marker", touch.options.run_lock, option.call("run_lock"))
	_credit_section("Shooting", "")
	_toggle("Auto fire on target", touch.options.auto_fire, option.call("auto_fire"))
	_toggle("Hold to aim", touch.options.aim_hold, option.call("aim_hold"))
	_toggle("Second fire button on the left", touch.options.left_fire, option.call("left_fire"))
	_toggle("Reload button", touch.options.reload_button, option.call("reload_button"))
	_card_wrap(start, split)
	if return_to.is_valid():
		_back_button(return_to, return_label if return_label != "" else "BACK TO SETTINGS")
	else:
		_back_button(show_settings, "BACK TO SETTINGS")

func _slider(text: String, value: float, low: float, high: float, callback: Callable) -> void:
	var label = Label.new()
	label.text = "%s: %d%%" % [text, roundi(value * 100)]
	menu_items.add_child(label)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.y = 36
	slider.value_changed.connect(func(changed): label.text = "%s: %d%%" % [text, roundi(changed * 100)]; callback.call(changed))
	menu_items.add_child(slider)

# The controls stay on screen, over the paused game when there is one, and
# can be dragged and resized; the result is stored with the other settings.
func show_layout_editor(return_to: Callable = Callable()) -> void:
	layout_return = return_to if return_to.is_valid() else show_controls
	menu.visible = false
	touch.reset()
	touch.editing = true
	touch.selected = ""
	touch.visible = true
	editor_bar.visible = true
	editor_bar.reset_size()
	await get_tree().process_frame
	editor_bar.position = ((ui.size - editor_bar.size) * 0.5).floor()

func close_layout_editor() -> void:
	preferences.set_value("touch", "layout", touch.custom)
	preferences.set_value("touch", "opacity", touch.opacity)
	preferences.save(save_path)
	if layout_return.is_valid():
		layout_return.call()
	else:
		show_controls()

func show_credits() -> void:
	_clear_menu("Credits", "doodleshooter-port · unofficial native adaptation")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var start = menu_items.get_child_count()
	_credit_section("Original game · Doodle District", "The original concept, design, maps, characters, weapons, mechanics, artwork, soundtrack and sound effects belong to the original game creators. This port does not claim official affiliation.")
	_button("OPEN ORIGINAL GAME", func(): OS.shell_open("https://doodleshooter.vercel.app/"))
	var ref = _credit_section("Reference source", "")
	ref.bbcode_enabled = true
	ref.text = "[url=https://github.com/iifor/doodleshooter]iifor/doodleshooter[/url] on GitHub. This is the source reference, without claiming that the repository owner is the sole original author."
	ref.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	_credit_section("Native adaptation", "Ported by @albertolicea00. Shared Android, iOS, and desktop project built with Godot Engine. District, Jungle and Mexico are original maps, converted with the models for native playback; the original procedural music and effects are rendered from the reference audio generator.")
	_button("PORT REPOSITORY", func(): OS.shell_open("https://github.com/albertolicea00/doodleshooter-port"))
	_credit_section("Engine and font", "Godot Engine · MIT license\nPatrick Hand · the Patrick Hand authors\nSIL Open Font License 1.1")
	_credit_section("Reference dependencies", "Three.js and PeerJS are preserved with their notices in the historical source snapshot. They are not shipped in the native game. Build-only audio rendering uses node-web-audio-api by IRCAM, under BSD-3-Clause.")
	_button("FULL CREDITS & NOTICES", show_credit_notices, "AltButton")
	_button("GODOT LICENSE", func(): show_license("Godot Engine license", Engine.get_license_text()), "AltButton")
	_card_wrap(start)
	if paused:
		_back_button(pause_menu, "BACK TO PAUSE")
	else:
		_back_button(show_main_menu)

func _credit_section(title: String, body: String) -> RichTextLabel:
	var heading = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 28)
	menu_items.add_child(heading)
	# .colhead: a ruled ink line under each section title.
	var rule = ColorRect.new()
	rule.color = DoodlePen.INK
	rule.custom_minimum_size.y = 2
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.visible = title != ""
	heading.visible = title != ""
	menu_items.add_child(rule)
	var text = RichTextLabel.new()
	text.text = body
	text.fit_content = true
	text.scroll_active = false
	text.selection_enabled = false
	text.focus_mode = Control.FOCUS_NONE
	text.custom_minimum_size.x = 480
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_theme_font_size_override("normal_font_size", 20)
	menu_items.add_child(text)
	return text

func show_credit_notices() -> void:
	show_license("Full credits & notices", FileAccess.get_file_as_string("res://CREDITS.txt") + "\n\n" + FileAccess.get_file_as_string("res://assets/fonts/PatrickHand-OFL.txt"))

func show_license(title: String, text: String) -> void:
	_clear_menu(title, "Attribution and license notices")
	auto_scroll = true
	auto_scroll_wait = 1.2
	auto_scroll_pos = 0.0
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var start = menu_items.get_child_count()
	_credit_section("", text)
	_card_wrap(start)
	_back_button(show_credits, "BACK TO CREDITS")

func start_game(first_wave: int) -> void:
	if starting:
		return
	starting = true
	_clear_menu("Drawing the world…", "Loading original geometry and native navigation")
	await get_tree().process_frame
	_clear_world()
	score = 0
	kills = 0
	wave = 0
	region = NavigationRegion3D.new()
	var nav = NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_height = 2.0
	nav.agent_radius = 0.5
	nav.agent_max_climb = 0.5
	nav.agent_max_slope = 45
	region.navigation_mesh = nav
	add_child(region)
	level = DoodleLevel.new()
	region.add_child(level)
	level.load_map(map_key, network.in_match or match_mode == "bots")
	sound.set_map(map_info(map_key).music)
	region.bake_navigation_mesh(false)
	player = DoodlePlayer.new()
	player.game = self
	add_child(player)
	player.position = level.start + Vector3.UP * 0.05
	player.camera.make_current()
	touch.player = player
	await get_tree().physics_frame
	await get_tree().physics_frame
	starting = false
	replay.start_recording()
	resume_game()
	if network.in_match:
		apply_online_spawn(online_spawn)
		for id in pending_broken:
			if level.breakables.has(int(id)):
				level.hit_prop(level.breakables[int(id)].body, 9999, false)
		pending_broken.clear()
		if is_instance_valid(lan_server) and lan_server.bot_count > 0 and network.peer_id == network.host_id:
			bot_match.begin_lan(lan_server.bot_count, lan_server.bot_difficulty)
	elif match_mode == "bots":
		bot_match.begin(bot_count, bot_difficulty, bot_minutes)
	else:
		start_wave(first_wave)

func _clear_world() -> void:
	replay.step_playback(0.0, false)
	replay.clear_puppets()
	particles.clear_smoke()
	playing = false
	bot_match.stop()
	scoreboard.visible = false
	_clear_remote_players()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.laser.free()
			enemy.free()
	enemies.clear()
	for dot in trajectory_nodes:
		dot.free()
	trajectory_nodes.clear()
	for cloud in smokes:
		cloud.node.free()
	smokes.clear()
	feel_blur = 0.0
	feel_dizzy = 0.0
	feel_haze = 0.0
	daze = 0.0
	smoke_dose = 0.0
	enemy_smoke = 20.0
	feel_overlay.visible = false
	for list in [projectiles, grenades, pickups, effects]:
		for item in list:
			if is_instance_valid(item.node):
				item.node.free()
		list.clear()
	if is_instance_valid(player):
		player.rope.free()
		player.free()
	if is_instance_valid(region):
		region.free()

func resume_game() -> void:
	Input.emulate_mouse_from_touch = false
	get_viewport().gui_release_focus()
	paused = false
	playing = true
	if is_instance_valid(player):
		player.resume_frames = 2
		player.jump_buffer = 0.0
		if is_instance_valid(player.camera):
			player.camera.make_current()
	apply_quality(quality)
	menu.visible = false
	hud.visible = true
	hud.touch_mode = use_touch
	center_text.visible = true
	touch.show_score = network.in_match or match_mode == "bots"
	touch.visible = use_touch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if use_touch or capture_mode else Input.MOUSE_MODE_CAPTURED

func pause_menu() -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	stop_rumble()
	paused = true
	playing = false
	var summary = "Wave %d · %d points" % [wave, score]
	if match_mode == "bots":
		summary = "Offline free for all · %d / %d kills" % [bot_match.scores.player.kills, bot_match.kill_limit]
	elif network.in_match:
		summary = "Free for all · the match continues while this menu is open"
	_clear_menu("Paused", summary)
	_button("RESUME", resume_game, "StartButton")
	_info_row()
	_button("MAIN MENU", show_main_menu, "AltButton")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and playing:
		pause_menu()

func _find_back_button(node: Node) -> Button:
	if node is Button and node.is_visible_in_tree() and not node.disabled:
		if node.text in ["RESUME", "CANCEL", "LEAVE LOBBY"] or node.text.begins_with("BACK"):
			return node
	for child in node.get_children():
		var found = _find_back_button(child)
		if found != null:
			return found
	return null

func _input(event: InputEvent) -> void:
	if menu.visible:
		var focused_edit = get_viewport().gui_get_focus_owner() is LineEdit and event is InputEventKey and not event.is_echo()
		if not focused_edit:
			for nav_action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]:
				if event.is_action_pressed(nav_action, true):
					var now = Time.get_ticks_msec()
					var min_gap = 185 if event.is_echo() else 150
					if nav_action == menu_nav_last_action and now - menu_nav_last_msec < min_gap:
						get_viewport().set_input_as_handled()
						return
					menu_nav_last_action = nav_action
					menu_nav_last_msec = now
					break
		if event.is_action_pressed("ui_cancel"):
			var back_btn = _find_back_button(menu_items)
			if back_btn != null:
				back_btn.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_up", true):
			var bar = menu_scroll.get_v_scroll_bar()
			if bar.max_value > menu_scroll.size.y:
				var focused = get_viewport().gui_get_focus_owner()
				var side = SIDE_BOTTOM if event.is_action_pressed("ui_down", true) else SIDE_TOP
				if focused == null or focused.find_valid_focus_neighbor(side) == null:
					auto_scroll = false
					menu_scroll.scroll_vertical += 120 if side == SIDE_BOTTOM else -120
					get_viewport().set_input_as_handled()
					return
	if event.is_action_pressed("pause") and not starting:
		if editor_bar.visible:
			close_layout_editor()
		elif paused:
			resume_game()
		elif playing:
			pause_menu()
		get_viewport().set_input_as_handled()

func start_wave(number: int) -> void:
	wave = number
	spawn_queue.clear()
	var roster = [["grunt", 1, 10], ["rusher", 2, 6], ["bomber", 3, 3], ["sniper", 3, 4], ["flyer", 4, 4], ["heavy", 5, 4], ["shield", 6, 4]]
	var pool: Array[String] = []
	for row in roster:
		if wave >= row[1]:
			for i in row[2]:
				if randf() < minf(1.0, 0.3 + 0.25 * (wave - row[1])):
					pool.append(row[0])
	var allowed = 1 if wave < 4 or wave % 5 == 0 else (3 if wave < 6 else 4)
	var selection = randi_range(0, allowed - 1)
	modifier = ["", "Caffeine · faster enemies", "Heavy Ink · harder hits", "Swarm · more enemies, less health"][selection]
	speed_modifier = [1.0, 1.35, 0.9, 1.15][selection]
	damage_modifier = [1.0, 0.85, 1.4, 0.9][selection] * 1.2 * [0.35, 0.6, 1.0, 1.35][difficulty]
	health_modifier = [0.5, 0.75, 1.0, 1.3][difficulty]
	swarm = selection == 3
	var count = roundi(mini(5 + wave * 2, 32 + wave) * (1.35 if swarm else 1.0) * [0.5, 0.75, 1.0, 1.3][difficulty] * [1.0, 1.6, 2.4][wave_size])
	if wave % 5 == 0:
		spawn_queue.append(["boss", "eraser", "inkblot"][int((wave - 5) / 5) % 3])
		count = maxi(1, roundi((7 + wave) * 0.5)) if difficulty == 0 else 7 + wave
		checkpoint = maxi(checkpoint, wave)
		save_progress()
	for i in count:
		spawn_queue.append(pool.pick_random() if not pool.is_empty() else "grunt")
	spawn_timer = 2.0
	intermission = 0.0
	player.grenades = mini(5, player.grenades + 1)
	player.smokes = mini(3, player.smokes + 1)
	for i in 7:
		spawn_pickup("ammo" if i < 5 else "health", level.pickup_spots.pick_random())
	sound.play_effect("wave")

func _update_focus_pulse() -> void:
	var focused = get_viewport().gui_get_focus_owner() if menu.visible else null
	if focused != null and not menu_items.is_ancestor_of(focused):
		focused = null
	if focused != pulsed_control:
		if is_instance_valid(pulsed_control):
			pulsed_control.self_modulate.a = 1.0
		pulsed_control = focused
	if is_instance_valid(pulsed_control):
		pulsed_control.self_modulate.a = 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.006)

func rumble(strong: float = 0.5, weak: float = 0.5, ms: float = 80.0) -> void:
	if not controller_vibration or ms <= 0.0:
		return
	var power = maxf(strong, weak)
	if power <= 0.0:
		return
	var now = Time.get_ticks_msec()
	if now < rumble_until_msec and power < rumble_power * 0.85:
		return
	rumble_power = power
	rumble_until_msec = now + int(ms)
	last_rumble = Vector3(strong, weak, ms)
	if capture_mode or "--smoke" in OS.get_cmdline_user_args():
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), ms * 0.001)

func stop_rumble() -> void:
	rumble_until_msec = 0
	rumble_power = 0.0
	if capture_mode or "--smoke" in OS.get_cmdline_user_args():
		return
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)

func controller_light_color() -> Color:
	if not controller_light:
		return Color(0.08, 0.08, 0.10)
	if playing and is_instance_valid(player):
		if not player.alive or hurt_flash > 0.05:
			return DoodlePen.RED
		if player.hp < 36.0:
			var pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
			return Color(DoodlePen.RED.r * pulse, DoodlePen.RED.g * pulse, DoodlePen.RED.b * pulse, 1.0)
		if player.weapon_index == 3 and player.katana_charge >= 1.0:
			return DoodlePen.HIT
	return DoodlePen.INK

func _update_controller_light(delta: float, force: bool = false) -> void:
	if capture_mode or "--smoke" in OS.get_cmdline_user_args():
		return
	joy_light_timer -= delta
	if not force and joy_light_timer > 0.0:
		return
	joy_light_timer = 0.08
	var target = controller_light_color()
	if not force and absf(target.r - last_joy_light.r) + absf(target.g - last_joy_light.g) + absf(target.b - last_joy_light.b) < 0.02:
		return
	last_joy_light = target
	for device in Input.get_connected_joypads():
		if Input.has_joy_light(device):
			Input.set_joy_light(device, target)

func _process(delta: float) -> void:
	_update_focus_pulse()
	_update_controller_light(delta)
	if menu.visible and auto_scroll:
		if auto_scroll_wait > 0.0:
			auto_scroll_wait -= delta
			auto_scroll_pos = float(menu_scroll.scroll_vertical)
		elif absf(float(menu_scroll.scroll_vertical) - auto_scroll_pos) > 4.0:
			auto_scroll = false
		else:
			var max_scroll = maxf(0.0, menu_scroll.get_v_scroll_bar().max_value - menu_scroll.size.y)
			auto_scroll_pos = minf(max_scroll, auto_scroll_pos + 32.0 * delta)
			menu_scroll.scroll_vertical = int(auto_scroll_pos)
			if auto_scroll_pos >= max_scroll:
				auto_scroll = false
	if not playing:
		if menu.visible and not paused and not starting:
			if is_instance_valid(region):
				region.visible = true
			replay.step_playback(delta, true)
		else:
			replay.step_playback(0.0, false)
		return
	if is_instance_valid(region):
		region.visible = true
	replay.step_playback(0.0, false)
	replay.record_step(delta, player, enemies, bot_match.bots, remote_players)
	update_feel(delta)
	if network.in_match:
		update_online(delta)
		return
	if match_mode == "bots":
		bot_match.update(delta)
		return
	combo_timer -= delta
	if combo_timer <= 0:
		combo = 0
	shake = move_toward(shake, 0, delta * 3)
	player.rig.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * minf(shake, 1.2) * 0.025
	scope.visible = player.weapon_index == 2 and player.aiming
	hit_marker = maxf(0, hit_marker - delta)
	hurt_flash = maxf(0, hurt_flash - delta)
	hurt_overlay.color.a = hurt_flash
	hud.score_text = "Score %d" % score
	hud.combo_text = "Combo x%d" % combo if combo > 1 else ""
	hud.info = [["Wave %d" % wave, false]]
	if modifier != "":
		hud.info.append([modifier, true])
	hud.info.append(["%d enemies left" % (enemies.size() + spawn_queue.size()), false])
	center_text.text = "Next wave in %d" % ceili(intermission) if intermission > 0 else ""
	hud.boss_name = ""
	for enemy in enemies:
		if enemy.stats.get("boss", false):
			hud.boss_name = enemy.stats.name
			hud.boss_fraction = enemy.hp / enemy.max_hp
	if intermission > 0:
		intermission -= delta
		if intermission <= 0:
			start_wave(wave + 1)
	elif not spawn_queue.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0 and enemies.size() < mini(4 + int(wave * 0.9), 18 + int(wave / 3)) + [0, 4, 9][wave_size]:
			spawn_enemy(spawn_queue.pop_front())
			spawn_timer = maxf(0.7, 2.9 - wave * 0.13)
	elif enemies.is_empty():
		intermission = 8.0
		score += wave * 200
		player.hp = minf(120, player.hp + 40)
		sound.play_effect("waveClear")
	sound.intensity = clampf(float(enemies.size()) / 15.0 + (0.25 if player.hp < 35 else 0.0), 0, 1)
	# Port addition: from wave 3 on Hard and Insane, a gunner who sees the player now and then lobs smoke at them.
	enemy_smoke -= delta
	if enemy_smoke <= 0 and wave >= 3 and difficulty >= 2:
		enemy_smoke = 2.0
		for enemy in enemies:
			var gap = enemy.global_position.distance_to(player.global_position)
			if enemy.alive and enemy.target_los and enemy.kind in ["grunt", "heavy", "shield"] and gap > 9 and gap < 34:
				lob_smoke(enemy.global_position + Vector3.UP * 1.5 * enemy.model_scale)
				enemy_smoke = randf_range(24, 36) if difficulty == 2 else randf_range(14, 22)
				break
	for dot in trajectory_nodes:
		dot.visible = player.charging
	_update_effects(delta)

func spawn_enemy(kind: String) -> DoodleEnemy:
	var spots = level.snipers if kind == "sniper" else level.spawns
	var far: Array[Vector3] = []
	for spot in spots:
		if spot.distance_to(player.position) > 14:
			far.append(spot)
	var point: Vector3 = far.pick_random() if not far.is_empty() else spots.pick_random()
	if kind == "flyer":
		point = player.position + Vector3(randf_range(-20, 20), 14, randf_range(-20, 20))
	var enemy = DoodleEnemy.new()
	enemy.kind = kind
	enemy.game = self
	add_child(enemy)
	enemy.position = point + Vector3.UP * 0.1
	enemies.append(enemy)
	return enemy

func enemy_killed(enemy: DoodleEnemy) -> void:
	enemies.erase(enemy)
	kills += 1
	combo += 1
	combo_timer = 3.5
	var points = int(enemy.stats.score) + maxi(0, combo - 1) * 10
	if not player.is_on_floor():
		points += 40
	if player.last_attack == "katana":
		player.katana_charge = minf(1, player.katana_charge + 1.0 / 3.0)
		player.blood_level = minf(1, player.blood_level + 0.3)
	score += points
	hud.popup("+%d" % points)
	burst(enemy.position + Vector3.UP, 1, 26)
	blood_pool(enemy.position, 0.8, 1)
	if randf() < 0.5:
		spawn_pickup("ammo", enemy.position)
	elif randf() < 0.24:
		spawn_pickup("health", enemy.position)
	sound.play_effect("kill")

func save_progress() -> void:
	best = maxi(best, score)
	preferences.set_value("progress", "best", best)
	preferences.set_value("progress", "checkpoint", checkpoint)
	preferences.save(save_path)

func game_over() -> void:
	stop_rumble()
	if match_mode == "bots":
		return
	if network.in_match:
		death_timer = 2.5
		return
	playing = false
	if not "--smoke" in OS.get_cmdline_user_args():
		replay.save_recording(map_key)
		replay.start_recording()
	save_progress()
	_clear_menu("You got erased", "%d waves · %d kills · %d points\nBest score: %d" % [wave, kills, score, best])
	_button("DRAW AGAIN", func(): start_game(1))
	if checkpoint >= 5:
		_button("FROM CHECKPOINT", func(): start_game(checkpoint))
	_button("MAIN MENU", show_main_menu)

func make_line(ink: int = 0, radius: float = 0.025) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.height = 1
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 4
	node.mesh = mesh
	node.material_override = ReferenceAssets.material(ink, true)
	add_child(node)
	return node

func line_between(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var direction = to - from
	node.position = (from + to) * 0.5
	if direction.length() > 0.001:
		node.quaternion = Quaternion(Vector3.UP, direction.normalized())
		node.scale = Vector3(1, direction.length(), 1)

func tracer(from: Vector3, to: Vector3, ink: int = 0) -> void:
	var node = make_line(ink, 0.018)
	line_between(node, from, to)
	effects.append({"node": node, "life": 0.09})

func fire_projectile(from: Vector3, direction: Vector3, speed: float, damage: float, reflected: bool = false, blast: float = 0.0) -> void:
	var node = make_line(0 if reflected else 1, 0.04)
	line_between(node, from, from + direction * 0.5)
	projectiles.append({"node": node, "position": from, "velocity": direction * speed, "damage": damage, "life": 5.0, "reflected": reflected, "blast": blast})

# A smoke cloud hides the player from any enemy whose line of sight crosses it.
func smoke_blocks(from: Vector3, to: Vector3) -> bool:
	for cloud in smokes:
		var along = clampf((cloud.position - from).dot(to - from) / maxf(0.001, from.distance_squared_to(to)), 0, 1)
		if from.lerp(to, along).distance_to(cloud.position) < 5.5:
			return true
	return false

func release_smoke(at: Vector3) -> void:
	var cloud = Node3D.new()
	add_child(cloud)
	cloud.position = at
	var haze = ShaderMaterial.new()
	haze.shader = preload("res://shaders/smoke.gdshader")
	# Drawn after the ink outline pass, so outlines of things behind the cloud do not show through it.
	haze.render_priority = 1
	for i in 14:
		var puff = MeshInstance3D.new()
		var ball = SphereMesh.new()
		ball.radius = randf_range(1.6, 3.0)
		ball.height = ball.radius * 2
		ball.radial_segments = 16
		ball.rings = 8
		puff.mesh = ball
		puff.material_override = haze
		puff.position = Vector3(randf_range(-3.4, 3.4), randf_range(0.4, 3.6), randf_range(-3.4, 3.4))
		puff.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		puff.set_meta("spin", randf_range(-0.35, 0.35))
		cloud.add_child(puff)
	smokes.append({"node": cloud, "position": at + Vector3.UP * 1.5, "life": 11.0, "material": haze})
	sound.play_effect("fuse", at)

# An enemy's smoke grenade, thrown on an arc that lands at the player's feet.
func lob_smoke(from: Vector3) -> void:
	var target: Vector3 = player.global_position
	var flight = clampf(from.distance_to(target) / 16.0, 0.75, 1.2)
	throw_grenade(from, (target - from) / flight + Vector3.UP * 11.0 * flight, false, true)

# Port addition: smoke in the eyes, low health and heavy hits blur and sway the view.
func update_feel(delta: float) -> void:
	var smoke = 0.0
	var eye: Vector3 = player.camera.global_position
	for cloud in smokes:
		smoke = maxf(smoke, clampf(1.0 - (eye.distance_to(cloud.position) - 3.0) / 3.5, 0, 1) * cloud.node.scale.x)
	# Breathing smoke stings a little (never below 8 health) and the dizziness outlasts the cloud.
	if smoke > 0.3:
		smoke_dose = minf(1.0, smoke_dose + delta * 1.5 * smoke)
		if player.alive and player.hp > 8.0 and not network.in_match:
			player.hp = maxf(8.0, player.hp - 4.0 * smoke * delta)
			player.last_hurt = 0
	else:
		smoke_dose = maxf(0, smoke_dose - delta / 6.0)
	var low = clampf((42.0 - player.hp) / 30.0, 0, 1) if player.alive else 0.0
	daze = maxf(0, daze - delta * 0.8)
	var ease = 1.0 - exp(-delta * 4.0)
	feel_haze = lerpf(feel_haze, smoke, ease)
	feel_blur = lerpf(feel_blur, clampf(smoke + smoke_dose * 0.45 + low * 0.3 + daze * 0.6, 0, 1), ease)
	feel_dizzy = lerpf(feel_dizzy, clampf(maxf(smoke * 0.8, smoke_dose) + low * 0.7 + daze, 0, 1) if screen_effects else 0.0, ease)
	feel_overlay.visible = feel_blur > 0.01 or feel_dizzy > 0.01 or feel_haze > 0.01
	feel_overlay.material.set_shader_parameter("blur", feel_blur)
	feel_overlay.material.set_shader_parameter("dizzy", feel_dizzy)
	feel_overlay.material.set_shader_parameter("haze", feel_haze)

func throw_grenade(from: Vector3, velocity: Vector3, mine: bool = true, smoke: bool = false) -> void:
	var node = RigidBody3D.new()
	var visual = MeshInstance3D.new()
	if smoke:
		# A canister with a coloured band, so it does not read as a frag grenade.
		var can = CylinderMesh.new()
		can.top_radius = 0.075
		can.bottom_radius = 0.075
		can.height = 0.26
		can.radial_segments = 10
		visual.mesh = can
		var band = MeshInstance3D.new()
		var ring = CylinderMesh.new()
		ring.top_radius = 0.082
		ring.bottom_radius = 0.082
		ring.height = 0.07
		ring.radial_segments = 10
		band.mesh = ring
		band.material_override = ReferenceAssets.material(9, true)
		visual.add_child(band)
	else:
		var sphere = SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		visual.mesh = sphere
	visual.material_override = ReferenceAssets.material(2 if smoke else 3, true)
	node.add_child(visual)
	var shape = CollisionShape3D.new()
	var bound = SphereShape3D.new()
	bound.radius = 0.12
	shape.shape = bound
	node.add_child(shape)
	node.collision_layer = 8
	node.collision_mask = 1
	var bounce = PhysicsMaterial.new()
	bounce.bounce = 0.5
	node.physics_material_override = bounce
	node.gravity_scale = 22.0 / 9.8
	add_child(node)
	node.position = from
	node.linear_velocity = velocity
	grenades.append({"node": node, "life": 1.3 if smoke else 2.1, "mine": mine, "smoke": smoke})
	if network.in_match and mine and not smoke:
		network.send_packet({"type": "grenade", "position": [from.x, from.y, from.z], "velocity": [velocity.x, velocity.y, velocity.z]})

func explode(at: Vector3, radius: float, damage: float, friendly: bool = true) -> void:
	var visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	visual.mesh = sphere
	visual.material_override = ReferenceAssets.material(3, false)
	add_child(visual)
	visual.position = at
	effects.append({"node": visual, "life": 0.2})
	sound.play_effect("explosion", at)
	burst(at, 3, 48)
	blood_pool(at, radius * 0.6, 3)
	shake += 0.7
	if is_instance_valid(player):
		var blast_feel = clampf(1.0 - at.distance_to(player.global_position) / 22.0, 0.0, 1.0)
		if blast_feel > 0.08:
			rumble(0.9 * blast_feel, 0.9 * blast_feel, 220)
	if network.in_match and friendly:
		network.send_packet({"type": "blast", "position": [at.x, at.y, at.z]})
	if not network.in_match and match_mode != "bots" and player.position.distance_to(at) < radius:
		var distance = (player.position + Vector3.UP).distance_to(at)
		player.take_damage(10 + 34 * (1 - distance / (radius * 0.95)) if friendly else damage)
		player.velocity += ((player.position + Vector3.UP) - at).normalized() * 9
	if friendly and not network.in_match:
		for enemy in enemies.duplicate():
			var distance = enemy.position.distance_to(at)
			if distance < radius:
				enemy.take_damage(damage * clampf(1 - distance / radius, 0.2, 1))
	if friendly and match_mode == "bots":
		bot_match.blast(at)
	if friendly:
		for prop in level.breakables.values().duplicate():
			if prop.position.distance_to(at) < radius:
				level.hit_prop(prop.body, damage)

func pickup_part(parent: Node3D, mesh: Mesh, ink: int, solid: bool, at: Vector3 = Vector3.ZERO) -> void:
	var part = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = ReferenceAssets.material(ink, solid, [0.62, 0.0])
	part.position = at
	parent.add_child(part)

# The original's pickup models: a blue ink bottle with a black cap and label
# for ammunition, a green cross for health. Its Mexico taco is not reproduced.
func spawn_pickup(kind: String, at: Vector3) -> void:
	var node = Node3D.new()
	if kind == "ammo":
		var bottle = CylinderMesh.new()
		bottle.top_radius = 0.22
		bottle.bottom_radius = 0.24
		bottle.height = 0.5
		bottle.radial_segments = 10
		pickup_part(node, bottle, 0, false)
		var cap = CylinderMesh.new()
		cap.top_radius = 0.1
		cap.bottom_radius = 0.1
		cap.height = 0.16
		cap.radial_segments = 8
		pickup_part(node, cap, 2, true, Vector3(0, 0.33, 0))
		var label = BoxMesh.new()
		label.size = Vector3(0.3, 0.2, 0.02)
		pickup_part(node, label, 2, true, Vector3(0, 0, 0.24))
	else:
		for size in [Vector3(0.6, 0.2, 0.2), Vector3(0.2, 0.6, 0.2)]:
			var bar = BoxMesh.new()
			bar.size = size
			pickup_part(node, bar, 4, true)
	add_child(node)
	node.position = at + Vector3.UP * 0.6
	pickups.append({"node": node, "kind": kind, "life": 35.0, "base": node.position.y, "time": randf() * 6.0})

func _physics_process(delta: float) -> void:
	# Touch actions do not generate InputEvents; observe pause/weapon here too.
	if touch != null and touch.visible:
		if Input.is_action_just_pressed("pause") and playing:
			pause_menu()
		if playing and touch.held.values().has("next_weapon") and Input.is_action_just_pressed("next_weapon"):
			player.switch_weapon((player.weapon_index + 1) % player.weapon_names.size())
	if not playing:
		for grenade in grenades:
			grenade.node.freeze = true
		return
	for grenade in grenades:
		grenade.node.freeze = false
		grenade.life -= delta
		if grenade.life <= 0:
			if grenade.smoke:
				release_smoke(grenade.node.position)
			else:
				explode(grenade.node.position, 6.4, 120, grenade.mine)
			grenade.node.queue_free()
	grenades = grenades.filter(func(g): return g.life > 0)
	for cloud in smokes:
		cloud.life -= delta
		cloud.node.scale = Vector3.ONE * clampf(minf(11.0 - cloud.life, cloud.life) * 1.5, 0.05, 1.0)
		cloud.material.set_shader_parameter("fade", clampf(cloud.life / 2.5, 0, 1))
		for puff in cloud.node.get_children():
			puff.rotate_y(delta * float(puff.get_meta("spin")))
			puff.position.y += delta * 0.07
		if cloud.life <= 0:
			cloud.node.queue_free()
	smokes = smokes.filter(func(c): return c.life > 0)
	for projectile in projectiles:
		projectile.life -= delta
		if projectile.blast > 0:
			projectile.velocity.y -= delta * 10
		var from: Vector3 = projectile.position
		var to: Vector3 = from + projectile.velocity * delta
		var query = PhysicsRayQueryParameters3D.create(from, to, 1 | (4 if projectile.reflected else 2))
		query.collide_with_areas = true
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider == player:
				var deflection = player.try_deflect(projectile.velocity)
				if deflection == 2:
					projectile.reflected = true
					projectile.velocity = -projectile.velocity
					to = from + projectile.velocity * delta
					projectile.node.material_override = ReferenceAssets.material(0, true)
				elif deflection == 1:
					projectile.life = 0
				else:
					player.take_damage(projectile.damage)
					projectile.life = 0
			elif hit.collider.has_method("take_damage"):
				hit.collider.take_damage(projectile.damage * 2)
				projectile.life = 0
			else:
				projectile.life = 0
			if projectile.life <= 0 and projectile.blast > 0:
				explode(hit.position, maxf(3.2, projectile.blast), projectile.damage, projectile.reflected)
		projectile.position = to
		line_between(projectile.node, to, to + projectile.velocity.normalized() * 0.5)
		if projectile.life <= 0:
			projectile.node.queue_free()
	projectiles = projectiles.filter(func(p): return p.life > 0)
	for pickup in pickups:
		pickup.life -= delta
		pickup.time += delta
		pickup.node.rotate_y(delta * 1.8)
		pickup.node.position.y = pickup.base + sin(pickup.time * 2.5) * 0.12
		if pickup.node.position.distance_to(player.position + Vector3.UP * 0.7) < 1.7:
			if pickup.kind == "health":
				player.hp = minf(120, player.hp + 35)
			else:
				for i in 3:
					player.reserves[i] = mini(player.reserves[i] + [35, 6, 5][i], [350, 72, 50][i])
			sound.play_effect("pickup")
			pickup.life = 0
		if pickup.life <= 0:
			pickup.node.queue_free()
	pickups = pickups.filter(func(p): return p.life > 0)

func _update_effects(delta: float) -> void:
	for effect in effects:
		effect.life -= delta
		if effect.life <= 0:
			effect.node.queue_free()
	effects = effects.filter(func(e): return e.life > 0)

func _exit_tree() -> void:
	stop_rumble()
	ReferenceAssets.dispose()

func run_smoke() -> void:
	assert(Input.emulate_mouse_from_touch, "Menus need touch-to-mouse conversion")
	await get_tree().process_frame
	await get_tree().process_frame
	assert((get_viewport().gui_get_focus_owner() as Button).text == "START SOLO")
	smoke_joy_button(JOY_BUTTON_DPAD_DOWN, true)
	var dup_down = InputEventKey.new()
	dup_down.keycode = KEY_DOWN
	dup_down.pressed = true
	Input.parse_input_event(dup_down)
	var echo_down = InputEventKey.new()
	echo_down.keycode = KEY_DOWN
	echo_down.pressed = true
	echo_down.echo = true
	Input.parse_input_event(echo_down)
	Input.flush_buffered_events()
	await get_tree().process_frame
	assert((get_viewport().gui_get_focus_owner() as Button).text == "PLAY ONLINE", "Duplicate or rapid-echo Down events must advance menu focus by one item")
	smoke_joy_button(JOY_BUTTON_DPAD_DOWN, false)
	dup_down.pressed = false
	Input.parse_input_event(dup_down)
	Input.flush_buffered_events()
	var credits_button = await smoke_menu_button("CREDITS")
	credits_button.grab_focus()
	await smoke_joy_press(JOY_BUTTON_A)
	assert(menu_items.get_child(0).get_child(0).text == "Credits", "Controller A/Cross must activate the focused menu button")
	await smoke_joy_press(JOY_BUTTON_B)
	assert(menu_items.get_child(0).get_child(0).get_child(0).text + menu_items.get_child(0).get_child(0).get_child(1).text == "DOODLE SHOOTER port", "Controller B/Circle must return from a submenu")
	# Make Godot enable touchscreen scrolling in the headless display server.
	Input.emulate_touch_from_mouse = true
	await smoke_tap_button("CREDITS")
	assert(menu_items.get_child(0).get_child(0).text == "Credits", "A menu tap must open the credits screen")
	await smoke_tap_button("FULL CREDITS & NOTICES", Vector2(0, 4))
	assert(menu_items.get_child(0).get_child(0).text == "Full credits & notices")
	assert(menu_scroll.scroll_vertical == 0, "Each menu screen must open at the top")
	var back_notices = await smoke_menu_button("BACK TO CREDITS")
	var swipe_start = back_notices.get_global_rect().get_center()
	var previous_scroll = menu_scroll.scroll_vertical
	smoke_touch(swipe_start, true)
	smoke_touch_drag(swipe_start, Vector2(0, 100))
	smoke_touch(swipe_start + Vector2(0, 100), false)
	await get_tree().process_frame
	assert(menu_items.get_child(0).get_child(0).text == "Full credits & notices", "Swiping over a button must not activate it")
	assert(menu_scroll.scroll_vertical < previous_scroll, "A swipe starting on a button must scroll the menu")
	await smoke_tap_button("BACK TO CREDITS")
	await smoke_tap_button("BACK TO MAIN MENU")
	assert(menu_items.get_child(0).get_child(0).get_child(0).text + menu_items.get_child(0).get_child(0).get_child(1).text == "DOODLE SHOOTER port", "Menu navigation must return to the main menu")
	await smoke_tap_button("START SOLO")
	assert(menu_items.get_child(0).get_child(0).text == "Play offline", "A menu tap must open offline play")
	Input.emulate_touch_from_mouse = false
	var saved_difficulty = difficulty
	for tuning in [[0, 0.42, 0.5, 4], [1, 0.72, 0.75, 5], [2, 1.2, 1.0, 7], [3, 1.62, 1.3, 9]]:
		difficulty = tuning[0]
		await start_game(1)
		assert(is_equal_approx(damage_modifier, tuning[1]), "Survival tiers must preserve the previous damage tuning above Easy")
		assert(is_equal_approx(health_modifier, tuning[2]), "Survival tiers must scale enemy health")
		assert(spawn_queue.size() == tuning[3], "Survival tiers must scale the first wave")
	difficulty = saved_difficulty
	await start_game(1)
	assert(not Input.emulate_mouse_from_touch, "Gameplay touch must not also press mouse-bound fire")
	assert(level.data.boxes.size() == 517)
	assert(player.magazines[0] == 35)
	await get_tree().physics_frame
	var floor_hit = player.ray(10, Vector3.DOWN)
	assert(not floor_hit.is_empty(), "Native map colliders must block rays")
	player.fire()
	assert(player.magazines[0] == 34, "Rifle must consume ammunition")
	player.reload()
	for i in 110:
		await get_tree().physics_frame
	assert(player.magazines[0] == 35 and player.reserves[0] == 174, "Reload must transfer reserve ammunition")
	var before_move = player.position
	Input.action_press("forward")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("forward")
	assert(player.position.distance_to(before_move) > 1.0, "Movement must change the physical body position")
	Input.action_press("jump")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("jump")
	assert(player.velocity.y > 0, "Jump must lift the player")
	for i in 35:
		await get_tree().physics_frame
	Input.action_press("jump")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("jump")
	assert(player.velocity.y > 0 and player.jumps == 0, "Double jump must consume the airborne jump")
	for i in 100:
		await get_tree().physics_frame
	player.camera.rotation.x = -0.7
	Input.action_press("grapple")
	for i in 3:
		await get_tree().physics_frame
	assert(player.grapple_active and player.stamina < 1, "Grapple must acquire a native collider and consume energy")
	Input.action_release("grapple")
	for i in 3:
		await get_tree().physics_frame
	assert(player.grapple_active, "Releasing the grapple must preserve the swing")
	Input.action_press("grapple")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("grapple")
	assert(not player.grapple_active, "A second grapple press must detach it")
	player.camera.rotation.x = 0
	touch.visible = true
	var finger = InputEventScreenTouch.new()
	finger.index = 4
	finger.position = Vector2(100, touch.size.y - 100)
	finger.pressed = true
	touch._input(finger)
	var drag = InputEventScreenDrag.new()
	drag.index = 4
	drag.position = finger.position + Vector2(touch.STICK_RADIUS * 0.9, 0)
	touch._input(drag)
	assert(touch.move_vector.x > 0.8, "Touch joystick must generate movement")
	assert(not touch.sprinting, "Sideways movement must not sprint")
	drag.position = finger.position + Vector2(0, -touch.STICK_RADIUS)
	touch._input(drag)
	assert(touch.sprinting, "Pushing the joystick fully forward must sprint")
	touch.options.stick_sprint = false
	touch._input(drag)
	assert(not touch.sprinting, "Stick sprint must be optional")
	touch.options.stick_sprint = true
	touch.options.left_fire = true
	touch.layout()
	assert(touch.buttons.has("fire_left"), "The second fire button must appear when enabled")
	touch.options.left_fire = false
	touch.custom = {"fire": [-40.0, -30.0, 1.2]}
	touch.layout()
	var moved: Array = touch.buttons.fire
	touch.custom = {}
	touch.layout()
	assert(moved[0].is_equal_approx(touch.buttons.fire[0] + Vector2(-40, -30)) and moved[1] > touch.buttons.fire[1], "A saved layout must move and resize its control")
	touch.selected = "fire"
	assert(not touch.can_delete(), "The only fire button must not be deletable")
	touch.duplicate_selected()
	touch.layout()
	assert(touch.buttons.has("fire#2") and touch.selected == "fire#2" and touch.can_delete(), "Duplicating must add a deletable copy")
	assert(not touch.buttons["fire#2"][0].is_equal_approx(touch.buttons.fire[0]), "A copy must not sit on top of its original")
	var copy_finger = InputEventScreenTouch.new()
	copy_finger.index = 7
	copy_finger.pressed = true
	copy_finger.position = touch.buttons["fire#2"][0]
	touch._press(copy_finger)
	assert(Input.is_action_pressed("fire"), "A copied fire button must fire")
	copy_finger.pressed = false
	touch._input(copy_finger)
	assert(not Input.is_action_pressed("fire"), "Lifting the copied button must stop firing")
	touch.delete_selected()
	touch.layout()
	assert(not touch.buttons.has("fire#2") and touch.buttons.has("fire"), "Deleting a copy must keep the original")
	touch.selected = "jump"
	touch.fade(-0.3)
	assert(touch._alpha("jump") < 0.8 and touch._alpha("fire") == 1.0 and touch.opacity == 1.0, "Fading must change only the selected control")
	touch.resize_selected(0.1)
	assert(touch._alpha("jump") < 0.8, "Resizing must keep a control's opacity")
	touch.selected = ""
	touch.custom = {}
	var fire_finger = InputEventScreenTouch.new()
	fire_finger.index = 5
	touch.layout()
	fire_finger.position = touch.buttons.fire[0]
	fire_finger.pressed = true
	touch._input(fire_finger)
	assert(Input.is_action_pressed("fire") and touch.move_finger == 4, "A second finger must fire without stealing the joystick")
	fire_finger.pressed = false
	touch._input(fire_finger)
	assert(not Input.is_action_pressed("fire"), "Releasing fire must stop the action")
	touch.reset()
	touch.visible = use_touch
	var dummy = spawn_enemy("grunt")
	dummy.set_physics_process(false)
	dummy.hp = 99999
	dummy.global_position = player.camera.global_position - player.camera.global_basis.z * 6.0 - Vector3.UP
	dummy.model.scale = Vector3.ONE * dummy.model_scale
	for i in 2:
		await get_tree().physics_frame
	var dummy_head = dummy.model.find_child("hit_head", true, false).get_child(0)
	player.camera.rotation.x = asin((dummy_head.global_position - player.camera.global_position).normalized().y)
	player.switch_weapon(0)
	var rounds: int = player.magazines[0]
	touch.visible = true
	touch.options.auto_fire = true
	for i in 8:
		await get_tree().physics_frame
	player.camera.rotation.x = 0
	assert(player.magazines[0] < rounds, "Auto fire must shoot a target under the crosshair")
	touch.options.auto_fire = false
	touch.reset()
	touch.visible = use_touch
	enemies.erase(dummy)
	dummy.laser.free()
	dummy.free()
	var enemy = spawn_enemy("grunt")
	var old_score = score
	var corpse_hitbox = enemy.model.find_child("hit_head", true, false).get_child(0)
	enemy.take_damage(999)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(corpse_hitbox.collision_layer == 0, "A corpse must not stay shootable")
	corpse_hitbox.take_damage(10)
	assert(score >= old_score + 100 and kills == 1)
	player.take_damage(20)
	assert(player.hp <= 100)
	touch.visible = true
	touch.layout()
	var pause_point: Vector2 = touch.buttons.pause[0]
	smoke_touch(pause_point, true)
	for i in 2:
		await get_tree().physics_frame
	assert(not playing and paused)
	smoke_touch(pause_point, false)
	await smoke_tap_button("RESUME")
	assert(playing and not paused)
	await smoke_joy_press(JOY_BUTTON_START)
	assert(not playing and paused, "Controller Start/Options must open the pause menu")
	await smoke_joy_press(JOY_BUTTON_A)
	assert(playing and not paused, "Controller A/Cross must activate RESUME")
	for i in 2:
		await get_tree().physics_frame
	assert(player.velocity.y <= 0.01 and player.slide_time <= 0.0, "Confirming RESUME on controller must not jump or slide")
	await smoke_joy_press(JOY_BUTTON_START)
	assert(not playing and paused)
	await smoke_joy_press(JOY_BUTTON_B)
	assert(playing and not paused, "Controller B/Circle must close the pause menu")
	for i in 2:
		await get_tree().physics_frame
	assert(player.slide_time <= 0.0 and player.dash_cd <= 0.0, "Closing pause with B/Circle must not slide or dash")
	player.switch_weapon(0)
	await smoke_joy_press(JOY_BUTTON_DPAD_RIGHT)
	assert(player.weapon_index == 1, "D-pad Right must switch to the next weapon")
	await smoke_joy_press(JOY_BUTTON_DPAD_LEFT)
	await smoke_joy_press(JOY_BUTTON_DPAD_LEFT)
	assert(player.weapon_index == 6, "D-pad Left must wrap to the previous weapon")
	await smoke_joy_press(JOY_BUTTON_DPAD_RIGHT)
	assert(player.weapon_index == 0)
	smoke_mouse_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await get_tree().process_frame
	assert(player.weapon_index == 1, "Mouse wheel down must select the next weapon")
	smoke_mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	await get_tree().process_frame
	assert(player.weapon_index == 0, "Mouse wheel up must select the previous weapon")
	var saved_smokes = player.smokes
	var saved_frags = player.grenades
	await smoke_joy_press(JOY_BUTTON_DPAD_DOWN)
	await get_tree().physics_frame
	assert(player.smokes == saved_smokes - 1 and grenades.size() == 1 and grenades[-1].smoke, "D-pad Down must throw a smoke grenade")
	grenades.pop_back().node.free()
	player.smokes = saved_smokes
	smoke_joy_button(JOY_BUTTON_DPAD_UP, true)
	for i in 2:
		await get_tree().physics_frame
	assert(player.charging, "Holding D-pad Up must charge a frag grenade")
	smoke_joy_button(JOY_BUTTON_DPAD_UP, false)
	for i in 2:
		await get_tree().physics_frame
	assert(not player.charging and player.grenades == saved_frags - 1 and grenades.size() == 1 and not grenades[-1].smoke, "Releasing D-pad Up must throw a frag grenade")
	grenades.pop_back().node.free()
	player.grenades = saved_frags
	Input.action_press("forward")
	await get_tree().physics_frame
	await smoke_joy_press(JOY_BUTTON_LEFT_STICK)
	await get_tree().physics_frame
	assert(player.pad_sprint, "L3 must toggle controller sprint on while moving forward")
	await smoke_joy_press(JOY_BUTTON_LEFT_STICK)
	await get_tree().physics_frame
	assert(not player.pad_sprint, "Pressing L3 again must toggle controller sprint off")
	await smoke_joy_press(JOY_BUTTON_LEFT_STICK)
	await get_tree().physics_frame
	assert(player.pad_sprint)
	Input.action_release("forward")
	for i in 2:
		await get_tree().physics_frame
	assert(not player.pad_sprint, "Stopping forward movement must clear controller sprint")
	player.camera.rotation.x = 0.0
	smoke_joy_axis(JOY_AXIS_RIGHT_Y, 0.8)
	for i in 3:
		await get_tree().physics_frame
	var normal_pitch = player.camera.rotation.x
	assert(normal_pitch < -0.02, "Pushing the right stick down must pitch the camera down")
	player.camera.rotation.x = 0.0
	touch.options.look = 2.0
	touch.options.invert_y = true
	for i in 3:
		await get_tree().physics_frame
	assert(player.camera.rotation.x > absf(normal_pitch) * 1.5, "Right stick must respect look sensitivity and vertical inversion")
	smoke_joy_axis(JOY_AXIS_RIGHT_Y, 0.0)
	touch.options.look = 1.0
	touch.options.invert_y = false
	player.camera.rotation.x = 0.0
	touch.visible = false
	touch.options.gyro = 1
	Input.set_gyroscope(Vector3(0.5, 0.6, 0.0))
	for i in 2:
		await get_tree().process_frame
	assert(absf(player.camera.rotation.x) < 0.005, "While-aiming gyroscope mode must stay idle until aiming")
	Input.action_press("aim")
	var yaw_before_gyro = player.rotation.y
	for i in 3:
		await get_tree().physics_frame
		await get_tree().process_frame
	assert(player.camera.rotation.x > 0.008 and player.rotation.y > yaw_before_gyro + 0.008, "Gyroscope aiming must work even when touch controls are hidden")
	Input.action_release("aim")
	Input.set_gyroscope(Vector3.ZERO)
	touch.options.gyro = 0
	player.camera.rotation.x = 0.0
	rumble_until_msec = 0
	last_rumble = Vector3.ZERO
	rumble(0.55, 0.6, 95)
	assert(is_equal_approx(last_rumble.x, 0.55), "Controller vibration must record rumble events when enabled")
	controller_vibration = false
	rumble_until_msec = 0
	last_rumble = Vector3.ZERO
	rumble(0.8, 0.5, 160)
	assert(last_rumble == Vector3.ZERO, "Disabling controller vibration must suppress rumble")
	controller_vibration = true
	hurt_flash = 0.0
	assert(controller_light_color().is_equal_approx(DoodlePen.INK), "Controller light bar must use ink blue during normal play")
	hurt_flash = 0.2
	assert(controller_light_color().is_equal_approx(DoodlePen.RED), "Controller light bar must flash red on damage")
	hurt_flash = 0.0
	player.switch_weapon(3)
	player.katana_charge = 1.0
	assert(controller_light_color().is_equal_approx(DoodlePen.HIT), "Controller light bar must glow orange when focus slash is ready")
	player.katana_charge = 0.0
	player.switch_weapon(0)
	controller_light = false
	assert(controller_light_color().r < 0.1, "Disabling the controller light bar must dim it")
	controller_light = true
	throw_grenade(player.camera.global_position, Vector3.UP)
	assert(grenades.size() == 1)
	release_smoke(Vector3(0, 0, 10))
	assert(smoke_blocks(Vector3(0, 1.5, 0), Vector3(0, 1.5, 20)) and not smoke_blocks(Vector3(30, 1.5, 0), Vector3(30, 1.5, 20)), "Smoke must block only sight lines that cross it")
	var clear_blur = feel_blur
	var healthy = player.hp
	release_smoke(player.global_position)
	for i in 30:
		update_feel(0.1)
	assert(feel_blur > 0.6 and feel_haze > 0.6 and feel_dizzy > 0.4 and feel_overlay.visible, "Standing in smoke must blur, grey and sway the view")
	assert(player.hp < healthy - 5 and player.hp > healthy - 20, "Smoke must cost a little health")
	screen_effects = false
	for i in 30:
		update_feel(0.1)
	assert(feel_dizzy < 0.05 and feel_blur > 0.6, "Turning the sway off must keep the blur")
	screen_effects = true
	smokes.pop_back().node.free()
	for i in 20:
		update_feel(0.1)
	assert(feel_dizzy > 0.3 and feel_haze < 0.1, "Dizziness must outlast the cloud")
	for i in 80:
		update_feel(0.1)
	assert(feel_blur <= clear_blur + 0.05 and feel_dizzy < 0.1, "The view must clear a few seconds after the smoke is gone")
	player.hp = healthy
	player.last_hurt = 10.0
	lob_smoke(player.global_position + Vector3(14, 1.5, 0))
	assert(grenades.size() == 2 and grenades[-1].smoke and not grenades[-1].mine and grenades[-1].node.linear_velocity.y > 0, "An enemy smoke grenade must be thrown on an arc")
	grenades.pop_back().node.free()
	player.switch_weapon(6)
	player.fire_cd = 0
	player.fire()
	assert(projectiles.size() > 0 and projectiles[-1].reflected and player.magazines[6] == 0, "The bazooka must launch a friendly rocket")
	player.switch_weapon(0)
	player.switch_weapon(1)
	player.magazines[1] = 2
	player.reserves[1] = 10
	player.reload()
	player.reload_time = 0.001
	for i in 2:
		await get_tree().physics_frame
	assert(player.magazines[1] == 3 and player.reserves[1] == 9, "Shotgun reload must transfer one shell at a time")
	assert(player.reload_time > 0, "Shotgun must continue loading remaining shells")
	player.fire()
	assert(player.magazines[1] == 2 and player.reload_time == 0, "Firing must interrupt the shotgun reload")
	player.switch_weapon(3)
	player.aiming = true
	player.fire_cd = 0
	player.block_time = 0
	player.block_cd = 0
	assert(player.try_deflect(player.camera.global_basis.z) == 2, "A frontal projectile inside the perfect parry window must reflect")
	assert(player.try_deflect(player.camera.global_basis.z) == 0, "Parry cooldown must prevent repeated reflections")
	player.block_cd = 0
	assert(player.try_deflect(-player.camera.global_basis.z) == 0, "Katana must not block projectiles from behind")
	print("SMOKE PASS: district collision, firing, reload, movement, double jump, grapple, multitouch, scoring, damage, pause, grenade")
	map_key = "mexico"
	await start_game(5)
	assert(level.data.boxes.size() == 321)
	assert(not level.breakables.is_empty())
	var prop: Dictionary = level.breakables.values()[0]
	var count = level.breakables.size()
	level.hit_prop(prop.body, 999)
	assert(level.breakables.size() == count - 1)
	assert(spawn_queue[0] == "boss")
	for kind in enemy_stats:
		var e = spawn_enemy(kind)
		assert(e.model != null)
		assert(not e.model.find_children("*", "Area3D", true, false).is_empty(), "Every enemy model needs damage hitboxes")
	var target = spawn_enemy("grunt")
	target.set_physics_process(false)
	target.position = Vector3(0, 80, -8)
	target.model.scale = Vector3.ONE * target.model_scale
	player.set_physics_process(false)
	var saved_position = player.position
	player.position = Vector3(0, 80, 0)
	for i in 2:
		await get_tree().physics_frame
	var head = target.model.find_child("hit_head", true, false).get_child(0)
	var head_hit = player.ray(20, (head.global_position - player.camera.global_position).normalized())
	assert(not head_hit.is_empty() and head_hit.collider == head, "Physics raycasts must resolve the animated head hitbox")
	var previous_hp = target.hp
	head_hit.collider.take_damage(1, head_hit.position)
	assert(target.hp == previous_hp - 1, "Hitbox damage must reach the owning enemy")
	player.position = saved_position
	player.set_physics_process(true)
	var boss = spawn_enemy("boss")
	var projectile_count = projectiles.size()
	boss.begin_attack("throw")
	boss.think_boss(0.7, player.position, 20)
	assert(projectiles.size() == projectile_count + 1, "The Doodler's throw must create a projectile")
	var inkblot = spawn_enemy("inkblot")
	inkblot.begin_attack("spray")
	inkblot.think_boss(0.7, player.position, 20)
	assert(inkblot.shots == 1, "The Inkblot must emit its spray sequence")
	for i in 180:
		await get_tree().physics_frame
	match_mode = "bots"
	map_key = "district"
	bot_count = DoodleBotMatch.MAX_BOTS
	await start_game(0)
	assert(bot_match.bots.size() == 30 and bot_match.scores.size() == 31, "Offline matches must support 30 bots plus the player")
	bot_count = 3
	bot_difficulty = 3
	bot_minutes = 15
	await start_game(0)
	assert(bot_match.kill_limit == 30 and bot_match.remaining == 900, "Fifteen-minute matches must use a 30-kill target and a 900-second clock")
	assert(bot_match.difficulty == 3, "Bot matches must accept the Insane tier")
	assert(level.data.boxes.size() == 429 and bot_match.bots.size() == 3, "Offline bots must use the arena without a server")
	var first = bot_match.bots[0]
	var second = bot_match.bots[1]
	player.position = Vector3(30, 80, 0)
	first.position = Vector3(0, 80, 0)
	second.position = Vector3(0, 80, -4)
	bot_match.bots[2].position = Vector3(40, 80, 0)
	assert(bot_match.choose_target(first) == second, "Bots must also select other bots as opponents")
	player.set_physics_process(false)
	for bot in bot_match.bots:
		bot.set_physics_process(false)
	for i in 2:
		await get_tree().physics_frame
	first.target_actor = second
	first.think_time = 1
	first.fire_time = 0
	second.invulnerable = 0
	first._physics_process(1.0 / 60)
	assert(second.hp == 101, "An AI bot must shoot and damage another bot through native collision")
	first.invulnerable = 0
	player.position = first.position + Vector3(0, 0, 2)
	player.camera.rotation = Vector3.ZERO
	player.fire_cd = 0
	for i in 2:
		await get_tree().physics_frame
	player.slash()
	assert(first.hp == 65, "The player's quick slash must hit an offline bot")
	first.hp = 120
	first.invulnerable = 2
	player.set_physics_process(true)
	for bot in bot_match.bots:
		bot.set_physics_process(true)
	bot_match.damage(first.peer_id, 999, "player")
	assert(first.hp == 120, "Offline spawn protection must reject damage")
	first.invulnerable = 0
	bot_match.damage(first.peer_id, 999, "player")
	assert(not first.alive and bot_match.scores.player.kills == 1)
	bot_match.respawn_bot(first)
	assert(first.alive and first.hp == 120 and first.invulnerable == 2)
	bot_match.player_shield = 0
	bot_match.damage("player", 999, second.peer_id)
	assert(not player.alive and bot_match.scores[second.peer_id].kills == 1)
	bot_match.player_respawn = 0
	bot_match.update(0.01)
	assert(player.alive and player.hp == 120 and bot_match.player_shield == 2)
	pause_menu()
	var clock_before = bot_match.remaining
	for i in 2:
		await get_tree().process_frame
	assert(bot_match.remaining == clock_before, "Pausing offline must stop the match clock")
	resume_game()
	smoke_joy_button(JOY_BUTTON_BACK, true)
	for i in 2:
		await get_tree().process_frame
	assert(scoreboard.visible, "Controller Create/View must show the arena scoreboard")
	smoke_joy_button(JOY_BUTTON_BACK, false)
	for i in 2:
		await get_tree().process_frame
	assert(not scoreboard.visible, "Releasing Create/View must hide the arena scoreboard")
	for i in 180:
		await get_tree().physics_frame
	bot_match.scores.player.kills = 19
	bot_match.respawn_bot(first)
	first.invulnerable = 0
	bot_match.damage(first.peer_id, 999, "player")
	assert(bot_match.active and playing, "Twenty kills must not end a 30-kill match")
	bot_match.scores.player.kills = bot_match.kill_limit - 1
	bot_match.respawn_bot(first)
	first.invulnerable = 0
	bot_match.damage(first.peer_id, 999, "player")
	assert(not bot_match.active and not playing, "The selected kill target must end the match")
	bot_minutes = 5
	await start_game(0)
	assert(bot_match.kill_limit == 10 and bot_match.remaining == 300, "Five-minute matches must use a 10-kill target and a 300-second clock")
	bot_match.remaining = 0.01
	bot_match.update(0.02)
	assert(not bot_match.active and not playing, "The match must finish when its selected time limit expires")
	bot_minutes = 10
	# Port maps: every enemy spawn must reach the player start on the baked navigation mesh.
	for key in ["castle", "harbor", "pyramid", "station", "forest", "school", "military"]:
		show_main_menu()
		map_key = key
		match_mode = "survival"
		await start_game(1)
		playing = false
		var nav_map = get_world_3d().navigation_map
		# The navigation server publishes a baked region a few frames later, and later still on the busier maps.
		for i in 240:
			await get_tree().physics_frame
			if i >= 3 and not NavigationServer3D.map_get_path(nav_map, level.spawns[0], level.start, true).is_empty():
				break
		for point in level.spawns:
			var route = NavigationServer3D.map_get_path(nav_map, point, level.start, true)
			assert(route.size() > 1 and route[-1].distance_to(level.start) < 2.0, "%s: spawn %s cannot reach the start" % [key, point])
		assert(player.is_on_floor() or player.position.y < 1.0, key + ": the player must start on the ground")
	show_main_menu()
	map_key = "mexico"
	print("SMOKE PASS: mexico collision, destructibles, checkpoint, boss queue, enemy hitboxes, offline bot combat, respawn, pause, match limit")
	_clear_world()
	sound.stop_all()
	# Let the audio thread release stopped playback before engine shutdown.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func smoke_menu_button(label: String) -> Button:
	var target: Button
	for child in menu_items.find_children("*", "Button", true, false):
		if child.text == label:
			target = child
	assert(target != null, "Missing menu button: " + label)
	await get_tree().process_frame
	await get_tree().process_frame
	menu_scroll.ensure_control_visible(target)
	await get_tree().process_frame
	return target

func smoke_tap_button(label: String, drift: Vector2 = Vector2.ZERO) -> void:
	var target = await smoke_menu_button(label)
	var point = target.get_global_rect().get_center()
	smoke_touch(point, true)
	if drift != Vector2.ZERO:
		smoke_touch_drag(point, drift)
	smoke_touch(point + drift, false)
	await get_tree().process_frame
	await get_tree().process_frame

func smoke_touch(point: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.position = get_viewport().get_screen_transform() * point
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func smoke_joy_button(button_index: JoyButton, down: bool) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func smoke_joy_press(button_index: JoyButton) -> void:
	for down in [true, false]:
		smoke_joy_button(button_index, down)
		await get_tree().physics_frame
	await get_tree().process_frame

func smoke_joy_axis(axis: JoyAxis, value: float) -> void:
	var event = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func smoke_mouse_wheel(button_index: MouseButton) -> void:
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = button_index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func smoke_touch_drag(point: Vector2, offset: Vector2) -> void:
	var transform_to_screen = get_viewport().get_screen_transform()
	var event = InputEventScreenDrag.new()
	event.position = transform_to_screen * (point + offset)
	event.relative = transform_to_screen.basis_xform(offset)
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func save_settings() -> void:
	for setting in ["music_enabled", "music_volume", "effects_volume", "enabled"]:
		preferences.set_value("audio", setting, sound.get(setting))
	preferences.set_value("touch", "options", touch.options)
	preferences.set_value("video", "quality", quality)
	preferences.set_value("video", "fps", show_fps)
	preferences.set_value("video", "screen_effects", screen_effects)
	preferences.set_value("video", "shading", shading)
	preferences.set_value("video", "fullscreen", fullscreen)
	preferences.set_value("survival", "difficulty", difficulty)
	preferences.set_value("survival", "wave_size", wave_size)
	preferences.set_value("bots", "minutes", bot_minutes)
	preferences.set_value("controller", "vibration", controller_vibration)
	preferences.set_value("controller", "light", controller_light)
	preferences.save(save_path)

func burst(at: Vector3, ink: int, count: int) -> void:
	particles.burst(at, ink, count)

func muzzle_fx(at: Vector3, forward: Vector3, pellets: int, flash_scale: float, smoke_count: int) -> void:
	particles.muzzle_sparks(at, 4 + pellets, flash_scale)
	# Muzzle smoke disabled per visual preference; keep muzzle flash and sparks.
	# particles.muzzle_smoke(at, forward, smoke_count)

func blood_pool(at: Vector3, radius: float, ink: int) -> void:
	var query = PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 4, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.length_squared() < 0.0001:
		return
	var node = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.012
	disc.radial_segments = 12
	node.mesh = disc
	node.material_override = ReferenceAssets.material(ink, true)
	add_child(node)
	node.position = hit.position + hit.normal * 0.015
	node.quaternion = Quaternion(Vector3.UP, hit.normal)
	effects.append({"node": node, "life": 24.0})

func preview_grenade(from: Vector3, velocity: Vector3) -> void:
	trajectory.clear()
	var at = from
	var speed = velocity
	for i in 26:
		var next = at + speed / 15.0
		speed.y -= 22.0 / 15.0
		var query = PhysicsRayQueryParameters3D.create(at, next, 1)
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			next = hit.position + hit.normal * 0.16
			speed = speed.bounce(hit.normal) * 0.55
		at = next
		trajectory.append(at)
		if trajectory_nodes.size() <= i:
			var dot = make_line(3, 0.045)
			trajectory_nodes.append(dot)
		line_between(trajectory_nodes[i], at, at + Vector3.UP * 0.08)
		trajectory_nodes[i].visible = true

func run_capture() -> void:
	if "--mexico" in OS.get_cmdline_user_args():
		map_key = "mexico"
	for info in MAPS:
		if "--map=" + info.key in OS.get_cmdline_user_args():
			map_key = info.key
	if "--hatch" in OS.get_cmdline_user_args():
		ReferenceAssets.set_style(0.0)
	await start_game(1)
	# Clean elevated view of a map for the README gallery.
	if "--scenic" in OS.get_cmdline_user_args():
		playing = false
		ui.visible = false
		player.set_physics_process(false)
		player.rig.visible = false
		player.camera.fov = 70
		var scenic_from = Vector3(68, 42, 92) if map_key == "jungle" else Vector3(26, 13, 40)
		var scenic_target = Vector3(0, 12, 0) if map_key == "jungle" else Vector3(0, 3, -6)
		player.camera.global_transform = Transform3D(Basis(), scenic_from).looking_at(scenic_target)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("DOODLE_CAPTURE"))
		print("CAPTURE: ", OS.get_environment("DOODLE_CAPTURE"))
		get_tree().quit()
		return
	# Square overview used for the map cards: run with --resolution 720x720.
	if "--preview" in OS.get_cmdline_user_args():
		playing = false
		ui.visible = false
		player.set_physics_process(false)
		player.rig.visible = false
		player.camera.fov = 62
		var overview = Image.create(PREVIEW_SIZE * PREVIEW_COLUMNS, PREVIEW_SIZE * ceili(float(PREVIEW_FRAMES) / PREVIEW_COLUMNS), false, Image.FORMAT_RGB8)
		for shot in PREVIEW_FRAMES:
			var angle = TAU * shot / PREVIEW_FRAMES + 0.6
			var radius = 112.0 if map_key == "jungle" else 60.0
			var height = 76.0 if map_key == "jungle" else 40.0
			player.camera.global_transform = Transform3D(Basis(), Vector3(sin(angle) * radius, height, cos(angle) * radius - 4)).looking_at(Vector3(0, 2, -4))
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var view = get_viewport().get_texture().get_image()
			view.convert(Image.FORMAT_RGB8)
			view.resize(PREVIEW_SIZE, PREVIEW_SIZE, Image.INTERPOLATE_LANCZOS)
			overview.blit_rect(view, Rect2i(0, 0, PREVIEW_SIZE, PREVIEW_SIZE), Vector2i(shot % PREVIEW_COLUMNS, shot / PREVIEW_COLUMNS) * PREVIEW_SIZE)
		overview.save_png(OS.get_environment("DOODLE_CAPTURE"))
		print("CAPTURE: ", OS.get_environment("DOODLE_CAPTURE"))
		get_tree().quit()
		return
	use_touch = "--touch" in OS.get_cmdline_user_args()
	touch.visible = use_touch
	for i in 45:
		await get_tree().process_frame
	# Optional poses for checking weapon animation and tracer origin in stills.
	for i in player.weapon_names.size():
		if "--weapon%d" % i in OS.get_cmdline_user_args():
			player.switch_weapon(i)
			await get_tree().create_timer(0.2).timeout
	if "--reload" in OS.get_cmdline_user_args():
		player.magazines[player.weapon_index] = 1
		player.reload()
		await get_tree().create_timer(0.6).timeout
	if "--fire" in OS.get_cmdline_user_args():
		player.fire()
		await get_tree().process_frame
	# Optional states for checking the smoke cloud and the woozy view in stills.
	if "--cloud" in OS.get_cmdline_user_args():
		release_smoke(player.global_position - player.camera.global_basis.z * 13.0)
		await get_tree().create_timer(1.5).timeout
	if "--insmoke" in OS.get_cmdline_user_args():
		release_smoke(player.global_position)
		await get_tree().create_timer(1.5).timeout
	if "--lowhp" in OS.get_cmdline_user_args():
		player.hp = 12
		await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var path = OS.get_environment("DOODLE_CAPTURE")
	if path.is_empty():
		path = "/private/tmp/doodleshooter-" + map_key + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE: ", path)
	get_tree().quit()

# Keep the default online map beside a reusable picker for every other map.
func _online_map_selector(container: Container) -> void:
	var row = HBoxContainer.new()
	row.name = "OnlineMaps"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	container.add_child(row)
	var caption = Label.new()
	caption.text = "map"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 20)
	row.add_child(caption)
	var selection = ButtonGroup.new()
	var custom_title: String = map_info(online_custom_map_key).name.to_upper() if online_custom_map_key != "" else "SELECT CUSTOM MAP"
	for info in [{"key": "district", "name": "DOODLE DISTRICT", "blurb": "default global map"}, {"key": "custom", "name": custom_title, "blurb": "custom map · tap to change" if online_custom_map_key != "" else "choose from 9 maps"}]:
		var card = Button.new()
		card.theme_type_variation = "AltButton"
		card.set_meta("map_key", info.key)
		card.toggle_mode = true
		card.button_group = selection
		card.button_pressed = (online_map_key == "district") if info.key == "district" else (online_map_key != "district")
		card.custom_minimum_size = Vector2(194, 56)
		card.add_theme_stylebox_override("normal", DoodlePen.box(DoodlePen.CLEAR, Color(DoodlePen.INK, 0.55), 1.4, 0.5))
		row.add_child(card)
		var text = VBoxContainer.new()
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(text)
		for entry in [[info.name, 18], [info.blurb, 13]]:
			var label = Label.new()
			label.text = entry[0]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", entry[1])
			label.add_theme_color_override("font_color", DoodlePen.PAPER if card.button_pressed else Color(DoodlePen.INK, 0.65))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.add_child(label)
		card.toggled.connect(func(pressed: bool):
			for label in text.get_children():
				label.add_theme_color_override("font_color", DoodlePen.PAPER if pressed else Color(DoodlePen.INK, 0.65)))
		var key: String = info.key
		card.pressed.connect(func():
			if key == "district":
				online_map_key = "district"
			else:
				_show_online_custom_maps(), CONNECT_DEFERRED)

func _show_online_custom_maps() -> void:
	var draft_name = name_input.text
	var draft_server = server_input.text
	var return_to_online = func():
		show_online_menu()
		name_input.text = draft_name
		server_input.text = draft_server
	show_map_menu(return_to_online, func(key: String):
		online_custom_map_key = key
		online_map_key = key, "district", online_custom_map_key)

func show_online_menu() -> void:
	_close_network()
	playing = false
	_clear_menu("Play online", "Free for all · 10 players · first to 20 kills · Connect to a native lobby server")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	var quick = _button("QUICK PLAY", func(): connect_online({"type": "quick", "map": online_map_key}), "StartButton")
	quick.custom_minimum_size.x = 340
	quick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var top_inputs = HBoxContainer.new()
	top_inputs.alignment = BoxContainer.ALIGNMENT_CENTER
	top_inputs.add_theme_constant_override("separation", 16)
	menu_items.add_child(top_inputs)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Your name"
	name_input.text = player_name
	name_input.custom_minimum_size = Vector2(240, 48)
	top_inputs.add_child(name_input)
	server_input = LineEdit.new()
	server_input.placeholder_text = "wss://your-lobby-server"
	server_input.text = server_url
	server_input.custom_minimum_size = Vector2(360, 48)
	top_inputs.add_child(server_input)
	_online_map_selector(top_inputs)
	var start = menu_items.get_child_count()
	_credit_section("Create a lobby", "Open a new room on the lobby server and share its code with friends, or list it publicly.")
	_button("CREATE PRIVATE LOBBY", func(): connect_online({"type": "host", "public": false, "map": online_map_key}), "AltButton")
	_button("CREATE PUBLIC LOBBY", func(): connect_online({"type": "host", "public": true, "map": online_map_key}))
	var split = menu_items.get_child_count()
	_credit_section("Join a lobby", "Enter a five-character room code from a friend, or browse open public rooms to jump into a match.")
	var code_row = HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 12)
	menu_items.add_child(code_row)
	code_input = LineEdit.new()
	code_input.placeholder_text = "Five-character lobby code"
	code_input.max_length = 5
	code_input.custom_minimum_size.y = 48
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code_input)
	var join_code = _button("JOIN CODE", func(): connect_online({"type": "join", "code": code_input.text.to_upper()}))
	join_code.custom_minimum_size.x = 170
	join_code.reparent(code_row)
	_button("BROWSE PUBLIC LOBBIES", func(): connect_online({"type": "list"}), "AltButton")
	_card_wrap(start, split)
	_back_button(show_main_menu)

func connect_online(request: Dictionary) -> void:
	lobby_return = show_online_menu
	player_name = name_input.text.strip_edges().left(24)
	server_url = server_input.text.strip_edges()
	preferences.set_value("online", "name", player_name)
	preferences.set_value("online", "url", server_url)
	preferences.save(save_path)
	network.connect_lobby(server_url, request)
	_clear_menu("Connecting…", "Contacting the lobby server")
	_button("CANCEL", show_main_menu, "AltButton")

func show_lobby() -> void:
	if network.in_match or starting:
		return
	last_room_code = network.code
	var bot_note = " · %d bots" % network.lobby_bots if network.lobby_bots > 0 else ""
	var rules_text = "Free for all · first to %d · %d minute limit%s" % [network.kill_limit, network.match_minutes, bot_note]
	var lobby_hint = "Choose a map, adjust the match settings, and start when everyone is ready."
	if network.peer_id != network.host_id:
		lobby_hint = "Review the match settings and players while the host prepares the match."
	var local_host = network.peer_id == network.host_id and is_instance_valid(lan_server)
	# Keep the atlas textures and animation timer alive across server lobby updates.
	if local_host and is_instance_valid(lobby_map_row):
		lobby_map_row.reparent(self)
	_clear_menu("Lobby " + network.code, lobby_hint)
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	if local_host:
		if is_instance_valid(lobby_map_row):
			lobby_map_row.reparent(menu_items)
			for card in lobby_map_row.get_children():
				if card is Button:
					card.button_pressed = card.get_meta("map_key") == map_key
		else:
			lobby_map_row = HBoxContainer.new()
			lobby_map_row.add_theme_constant_override("separation", 8)
			menu_items.add_child(lobby_map_row)
			_populate_map_cards(lobby_map_row, true, func(key: String):
				map_key = key
				network.send_packet({"type": "map", "map": key}))
	var start = menu_items.get_child_count()
	if network.peer_id == network.host_id:
		var match_rules = _credit_section("Match setup", rules_text)
		if is_instance_valid(lan_server):
			var send_config = func(): network.send_packet({"type": "config", "minutes": lan_minutes, "bots": lan_bot_count, "difficulty": lan_bot_difficulty})
			_choices(["Easy", "Normal", "Hard", "Insane"], lan_bot_difficulty, func(index): lan_bot_difficulty = index; send_config.call())
			var diff_row = menu_items.get_child(-1)
			for btn in diff_row.get_children():
				btn.disabled = lan_bot_count == 0
			var selectors = HBoxContainer.new()
			selectors.add_theme_constant_override("separation", 24)
			menu_items.add_child(selectors)
			_duration_selector(match_rules, lan_minutes, func(m): lan_minutes = m; send_config.call(), func(_m): return rules_text).reparent(selectors)
			_count_selector(lan_bot_count, 0, func(c): lan_bot_count = c; send_config.call()).reparent(selectors)
		else:
			_button("MAP · " + map_info(map_key).name, func(): show_map_menu(show_lobby, func(key): network.send_packet({"type": "map", "map": key})), "AltButton")
	else:
		_credit_section("Match setup", "%s\nMap: %s\nWaiting for the host to start the match." % [rules_text, map_info(map_key).name])
	var split = menu_items.get_child_count()
	var entries: Array[String] = []
	for entry in network.roster:
		entries.append("• %s%s" % [entry.name, " (host)" if entry.id == network.host_id else ""])
	if network.lobby_bots > 0:
		entries.append("• 1 bot" if network.lobby_bots == 1 else "• %d bots" % network.lobby_bots)
	_credit_section("Players (%d/12)" % entries.size(), lan_host_note.strip_edges())
	if lan_host_note == "":
		menu_items.get_child(-1).hide()
	var players_grid = HBoxContainer.new()
	players_grid.add_theme_constant_override("separation", 16)
	menu_items.add_child(players_grid)
	for col_index in 4:
		var slice = entries.slice(col_index * 3, (col_index + 1) * 3)
		if slice.is_empty():
			continue
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		players_grid.add_child(col)
		for item in slice:
			var label = Label.new()
			label.text = item
			label.add_theme_font_size_override("font_size", 20)
			col.add_child(label)
	_card_wrap(start, split)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	menu_items.add_child(actions)
	if network.peer_id == network.host_id:
		var start_btn = _button("START MATCH", func(): network.send_packet({"type": "start"}), "StartButton")
		start_btn.custom_minimum_size.x = 240
		start_btn.reparent(actions)
	var leave_btn = _button("LEAVE LOBBY", lobby_return if lobby_return.is_valid() else show_main_menu, "RedOutlineButton")
	leave_btn.custom_minimum_size.x = 240
	leave_btn.reparent(actions)

func _network_packet(packet: Dictionary) -> void:
	match packet.get("type", ""):
		"lobby":
			map_key = packet.map
			show_lobby()
		"rooms":
			_clear_menu("Public lobbies", "Choose an open room")
			for room in packet.rooms:
				var code: String = room.code
				_button("%s · %s · %d/10" % [code, room.host, int(room.players)], func(): network.send_packet({"type": "join", "code": code}))
			_back_button(show_online_menu, "BACK TO ONLINE")
		"start":
			network.in_match = true
			match_mode = "survival"
			map_key = packet.map
			online_spawn = int(packet.spawn)
			pending_broken = packet.broken
			last_room_code = network.code
			start_game(0)
		"state":
			if not starting and network.in_match and is_instance_valid(player):
				var state: Dictionary = packet.state
				var id: String = state.id
				if not remote_players.has(id):
					var remote = DoodleRemotePlayer.new()
					remote.peer_id = id
					remote.game = self
					add_child(remote)
					remote_players[id] = remote
				remote_players[id].update_state(state)
		"left":
			if remote_players.has(packet.id):
				remote_players[packet.id].queue_free()
				remote_players.erase(packet.id)
		"damage":
			if is_instance_valid(player) and player.alive:
				player.hp = float(packet.hp) + float(packet.amount)
				player.take_damage(float(packet.amount))
		"respawn":
			reset_arena_player(int(packet.spawn))
			resume_game()
		"shot":
			if remote_players.has(packet.id):
				var remote = remote_players[packet.id]
				tracer(remote.position + Vector3.UP * 1.4, ReferenceAssets.vector(packet.end), 0)
				sound.play_effect(["enemyShot", "shotgun", "sniperShot", "katanaSwing", "revolver", "enemyShot", "shotgun"][clampi(int(packet.weapon), 0, 6)], remote.position)
		"grenade":
			if not starting and network.in_match:
				throw_grenade(ReferenceAssets.vector(packet.position), ReferenceAssets.vector(packet.velocity), false)
		"broken":
			if is_instance_valid(level) and level.breakables.has(int(packet.id)):
				level.hit_prop(level.breakables[int(packet.id)].body, 9999, false)
		"bot_hurt":
			if remote_players.has(packet.id):
				var bot: DoodleRemotePlayer = remote_players[packet.id]
				bot.hp = float(packet.hp)
				if bot.hp <= 0 and bot.alive:
					bot.alive = false
					bot.model.visible = false
					bot.collision_layer = 0
					burst(bot.position + Vector3.UP, 1, 24)
		"bot_respawn":
			if remote_players.has(packet.id) and bot_match.active and bot_match.lan_host:
				bot_match.respawn_bot(remote_players[packet.id], int(packet.spawn))
		"result":
			playing = false
			bot_match.stop()
			online_results = packet.players
			var scores = ""
			for entry in online_results:
				scores += "%s · %d kills · %d deaths\n" % [entry.name, int(entry.kills), int(entry.deaths)]
			_clear_menu("Match finished", scores)
			_button("MAIN MENU", show_main_menu)
		"idle":
			playing = false
			_clear_menu("Away from the page", packet.message)
			_button("REJOIN", func(): network.send_packet({"type": "join", "code": packet.code}))
			_button("MAIN MENU", show_main_menu)
		"error":
			_network_failure(packet.message)

func _network_failure(message: String) -> void:
	playing = false
	_clear_menu("Connection", message)
	_back_button(show_online_menu, "BACK TO ONLINE")

func _clear_remote_players() -> void:
	for remote in remote_players.values():
		remote.queue_free()
	remote_players.clear()

func apply_online_spawn(index: int) -> void:
	var points: Array = level.data.arena_spawns
	if points.is_empty():
		points = level.data.spawns
	player.position = ReferenceAssets.vector(points[index % points.size()]) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.detach_grapple()

func update_online(delta: float) -> void:
	if bot_match.active and bot_match.lan_host:
		bot_match.update(delta)
	var own_kills = 0
	for entry in network.roster:
		if entry.id == network.peer_id:
			own_kills = int(entry.kills)
	hud.score_text = "Kills %d / %d" % [own_kills, network.kill_limit]
	hud.combo_text = ""
	hud.boss_name = ""
	hud.info = [["%02d:%02d" % [network.remaining / 60, network.remaining % 60], true], ["Lobby " + network.code, false]]
	var standings = network.roster.duplicate()
	standings.sort_custom(func(a, b): return int(a.kills) > int(b.kills))
	scoreboard.text = "FREE FOR ALL\n" + "\n".join(standings.map(func(entry): return "%s     %d K / %d D" % [entry.name, entry.kills, entry.deaths]))
	scoreboard.visible = Input.is_action_pressed("scoreboard")
	center_text.text = ""
	scope.visible = player.weapon_index == 2 and player.aiming
	hit_marker = maxf(0, hit_marker - delta)
	hurt_flash = maxf(0, hurt_flash - delta)
	hurt_overlay.color.a = hurt_flash
	if not player.alive:
		death_timer -= delta
		center_text.text = "You got erased · respawn in %d" % maxi(0, ceili(death_timer))
		if death_timer <= 0 and not menu.visible:
			_clear_menu("You got erased", "Rejoin the fight with a two-second shield")
			_button("RESPAWN", func(): network.send_packet({"type": "respawn"}))
			_button("LEAVE MATCH", show_main_menu)
	for dot in trajectory_nodes:
		dot.visible = player.charging
	_update_effects(delta)

func reset_arena_player(index: int) -> void:
	apply_online_spawn(index)
	player.hp = 120
	player.alive = true
	player.grenades = 3
	player.magazines = [35, 6, 5, 0, 6, 30, 1]
	player.reserves = [175, 36, 25, 0, 36, 180, 6]
	player.smokes = 2
	player.reload_time = 0
	player.cycle_time = 0
	player.fire_cd = 0
	player.charging = false
	player.throw_charge = 0
	player.slide_time = 0
	player.stamina = 1
	player.katana_charge = 0
	player.last_hurt = 0
	player.pad_sprint = false
	trajectory.clear()

func show_offline_menu() -> void:
	_clear_menu("Play offline", "No Internet connection or server needed")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	var map_row = HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	menu_items.add_child(map_row)
	_populate_map_cards(map_row, true, func(key: String):
		map_key = key)
	var survival_start = menu_items.get_child_count()
	_credit_section("Survival · Enemy waves", "Survive growing waves of enemies and bosses. Difficulty and wave-size choices are port additions, not part of the original game.")
	if checkpoint >= 5:
		var heading = menu_items.get_child(survival_start)
		var heading_row = HBoxContainer.new()
		heading_row.add_theme_constant_override("separation", 12)
		heading_row.alignment = BoxContainer.ALIGNMENT_CENTER
		menu_items.add_child(heading_row)
		menu_items.move_child(heading_row, survival_start)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.reparent(heading_row)
		var resume = _button("CHECKPOINT · WAVE " + str(checkpoint), func(): match_mode = "survival"; start_game(checkpoint), "RedOutlineButton")
		resume.name = "OfflineCheckpointButton"
		resume.custom_minimum_size = Vector2(0, 34)
		resume.add_theme_font_size_override("font_size", 18)
		resume.tooltip_text = "Continue Survival from wave %d" % checkpoint
		resume.reparent(heading_row)
	_choices(["Easy", "Normal", "Hard", "Insane"], difficulty, func(index): difficulty = index; save_settings())
	_choices(["Normal waves", "Large waves", "Huge waves"], wave_size, func(index): wave_size = index; save_settings())
	var survival = _button("START SURVIVAL", func(): match_mode = "survival"; start_game(1), "StartButton")
	survival.add_theme_font_size_override("font_size", 40)
	survival.custom_minimum_size.y = 76
	var bots_start = menu_items.get_child_count()
	var bot_rules = _credit_section("Free for all with bots", "")
	_choices(["Easy", "Normal", "Hard", "Insane"], bot_difficulty, func(index): bot_difficulty = index)
	var selectors = HBoxContainer.new()
	selectors.add_theme_constant_override("separation", 24)
	menu_items.add_child(selectors)
	_duration_selector(bot_rules, bot_minutes, func(m): bot_minutes = m; save_settings(), func(m): return "Respawn and fight everyone. First to %d kills, or the most kills after %d minutes. Port addition · not part of the original game." % [m * DoodleBotMatch.KILLS_PER_MINUTE, m]).reparent(selectors)
	_count_selector(bot_count, 1, func(c): bot_count = c).reparent(selectors)
	var bots = _button("START BOT MATCH", func(): match_mode = "bots"; start_game(0), "StartButton")
	bots.add_theme_font_size_override("font_size", 40)
	bots.custom_minimum_size.y = 76
	var content = menu_items.get_children()
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	menu_items.add_child(cards)
	_offline_card(cards, content.slice(survival_start, bots_start))
	_offline_card(cards, content.slice(bots_start))
	_back_button(show_main_menu)

func _offline_card(cards: HBoxContainer, content: Array[Node]) -> void:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", DoodlePen.box(Color(0.98, 0.972, 0.933, 0.95), DoodlePen.INK, 3.0, -0.35, Vector2(24, 16)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(card)
	var items = VBoxContainer.new()
	items.add_theme_constant_override("separation", 8)
	card.add_child(items)
	for child in content:
		# Align the start buttons at the bottom of both cards.
		if child == content.back():
			var spacer = Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			items.add_child(spacer)
		child.reparent(items)

func _duration_selector(rules: Node, current_minutes: int, on_change: Callable, format_rules: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	menu_items.add_child(row)
	var duration = Label.new()
	duration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	duration.custom_minimum_size.x = 80
	var decrease = _button("−", func(): pass, "AltButton")
	decrease.tooltip_text = "Shorter match"
	decrease.custom_minimum_size.x = 64
	decrease.reparent(row)
	row.add_child(duration)
	var increase = _button("+", func(): pass, "AltButton")
	increase.tooltip_text = "Longer match"
	increase.custom_minimum_size.x = 64
	increase.reparent(row)
	var minutes_state = [current_minutes]
	var update_duration = func():
		duration.text = "%d min" % minutes_state[0]
		rules.text = format_rules.call(minutes_state[0])
		_fit_menu.call_deferred()
		decrease.disabled = minutes_state[0] <= DoodleBotMatch.MIN_MINUTES
		increase.disabled = minutes_state[0] >= DoodleBotMatch.MAX_MINUTES
	decrease.pressed.connect(func(): minutes_state[0] = maxi(DoodleBotMatch.MIN_MINUTES, minutes_state[0] - 5); on_change.call(minutes_state[0]); update_duration.call())
	increase.pressed.connect(func(): minutes_state[0] = mini(DoodleBotMatch.MAX_MINUTES, minutes_state[0] + 5); on_change.call(minutes_state[0]); update_duration.call())
	update_duration.call()
	return row

func _count_selector(current_count: int, min_count: int, on_change: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_items.add_child(row)
	var count = Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.custom_minimum_size.x = 100
	var decrease = _button("−", func(): pass, "AltButton")
	decrease.tooltip_text = "Fewer bots"
	decrease.custom_minimum_size.x = 64
	decrease.reparent(row)
	row.add_child(count)
	var increase = _button("+", func(): pass, "AltButton")
	increase.tooltip_text = "More bots"
	increase.custom_minimum_size.x = 64
	increase.reparent(row)
	var warning = Label.new()
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 22)
	warning.add_theme_color_override("font_color", DoodlePen.RED)
	menu_items.add_child(warning)
	var count_state = [current_count]
	var update_count = func():
		warning.visible = count_state[0] >= 20
		warning.text = "You're crazy! With 30 bots, the game might barely run!" if count_state[0] >= 30 else "20+ bots may reduce performance, especially on mobile devices."
		count.text = "1 bot" if count_state[0] == 1 else "%d bots" % count_state[0]
		decrease.disabled = count_state[0] <= min_count
		increase.disabled = count_state[0] >= DoodleBotMatch.MAX_BOTS
		_fit_menu.call_deferred()
	decrease.pressed.connect(func(): count_state[0] = maxi(min_count, count_state[0] - 1); on_change.call(count_state[0]); update_count.call())
	increase.pressed.connect(func(): count_state[0] = mini(DoodleBotMatch.MAX_BOTS, count_state[0] + 1); on_change.call(count_state[0]); update_count.call())
	update_count.call()
	return row

func show_lan_menu() -> void:
	_close_network()
	_clear_menu("Local network · LAN", "Use the same Wi-Fi network or hotspot. No Internet or separate server needed.")
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu.custom_minimum_size.x = 1160
	menu.offset_left = -580
	menu.offset_right = 580
	name_input = LineEdit.new()
	name_input.placeholder_text = "Your name"
	name_input.text = player_name
	name_input.custom_minimum_size = Vector2(360, 46)
	name_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_items.add_child(name_input)
	var start = menu_items.get_child_count()
	_credit_section("Host a room", "Create a local match on this device and share your host IP with friends on the same Wi-Fi or hotspot. Keep this device in the game while others play. Once inside the lobby, you can choose the map, time limit, and bots.\n\nHost IP: " + _local_ip_text())
	_button("HOST LAN GAME", host_lan_game)
	var split = menu_items.get_child_count()
	_credit_section("Join a room", "Ask the host for the IP address shown in their lobby. Enter it below, then tap Join. Guest Wi-Fi networks may prevent devices from connecting to each other.")
	server_input = LineEdit.new()
	server_input.placeholder_text = "Host IP address, for example 192.168.1.10"
	server_input.text = lan_address
	server_input.custom_minimum_size.y = 46
	menu_items.add_child(server_input)
	_button("JOIN LAN GAME", join_lan_game)
	_card_wrap(start, split, true)
	_back_button(show_main_menu)

func save_player_name() -> void:
	player_name = name_input.text.strip_edges().left(24)
	if player_name.is_empty():
		player_name = "Doodler"
	preferences.set_value("online", "name", player_name)
	preferences.save(save_path)

func _local_ip_text() -> String:
	var addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and not ":" in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	return ", ".join(addresses) if not addresses.is_empty() else "Check this device's Wi-Fi settings"

func host_lan_game() -> void:
	save_player_name()
	if is_instance_valid(lan_server):
		lan_server.stop()
		lan_server.queue_free()
	lan_server = DoodleLanServer.new()
	add_child(lan_server)
	var error = lan_server.start()
	if error != OK:
		lan_server.queue_free()
		lan_server = null
		_clear_menu("LAN hosting unavailable", "Could not open the local game port. Close another hosted room and try again.")
		_back_button(show_lan_menu, "BACK TO LAN")
		return
	lobby_return = show_lan_menu
	lan_host_note = "\n\nHost IP: " + _local_ip_text() + "\nKeep this device in the game to host the room."
	network.connect_lobby("ws://127.0.0.1:%d" % DoodleLanServer.PORT, {"type": "host", "map": map_key, "minutes": lan_minutes, "bots": lan_bot_count, "difficulty": lan_bot_difficulty})
	_clear_menu("Creating LAN room…", "Starting a game on this device")
	_button("CANCEL", show_lan_menu)

func join_lan_game() -> void:
	save_player_name()
	lan_address = server_input.text.strip_edges()
	if lan_address.is_empty():
		server_input.placeholder_text = "Enter the host's IP address first"
		return
	var url = lan_address
	if not url.begins_with("ws://"):
		if not ":" in url:
			url += ":%d" % DoodleLanServer.PORT
		url = "ws://" + url
	lobby_return = show_lan_menu
	network.connect_lobby(url, {"type": "join", "code": "LAN"})
	_clear_menu("Joining LAN room…", "Connecting to the host on your local network")
	_button("CANCEL", show_lan_menu)
