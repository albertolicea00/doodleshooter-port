class_name DoodleTouchControls
extends Control

const STICK_RADIUS = 78.0
const NAMES = ["Rifle", "Shotgun", "Sniper", "Katana", "Revolver", "SMG", "Bazooka"]
var player: DoodlePlayer
var move_vector = Vector2.ZERO
var move_finger = -1
var origin = Vector2.ZERO
var thumb = Vector2.ZERO
var held: Dictionary = {}
var buttons: Dictionary = {}
var slots: Array[Rect2] = []
var show_score = false
var aim_locked = false
# Merged movement, as in large mobile shooters: a full forward push sprints,
# and dragging on up to the RUN marker keeps running after the thumb lifts.
var sprinting = false
var run_locked = false
var stick_rest = Vector2.ZERO
var stick_radius = STICK_RADIUS
# Player layout: control name -> [x offset, y offset, scale] from the default.
var custom: Dictionary = {}
var defaults: Dictionary = {}
var opacity = 1.0
var editing = false
var selected = ""
var dragging = false
var grab = Vector2.ZERO
var toolbar: Control
# Player preferences, edited under Settings and stored with the layout.
var options = {"look": 1.0, "aim_look": 0.6, "invert_y": false, "gyro": 0, "gyro_speed": 1.0, "auto_fire": false, "left_fire": false, "reload_button": false, "aim_hold": false, "fixed_stick": false, "stick_sprint": true, "run_lock": true}
var auto_firing = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not visible:
		return
	modulate.a = opacity
	queue_redraw()
	if editing or not is_instance_valid(player) or not player.alive or not player.game.playing:
		return
	# Gyroscope aiming: rotation rate around the screen's vertical axis turns,
	# around its horizontal axis pitches.
	if options.gyro == 2 or (options.gyro == 1 and player.aiming):
		var rate = Input.get_gyroscope()
		turn(Vector2(-rate.y, -rate.x) * delta * options.gyro_speed)
	# Auto fire: shoot while something that can be hurt is under the crosshair.
	var reach = 3.2 if player.weapon_index == 3 else 18.0 if player.weapon_index == 1 else 120.0
	var target = options.auto_fire and player.ray(reach).get("collider") != null and player.ray(reach).collider.has_method("take_damage")
	if target and player.weapon_index in [1, 2, 4, 6] and auto_firing:
		# Single-shot weapons need a fresh press for every shot.
		target = false
	if target != auto_firing:
		auto_firing = target
		if target:
			Input.action_press("fire")
		elif not held.values().has("fire"):
			Input.action_release("fire")

func turn(amount: Vector2) -> void:
	if not is_instance_valid(player):
		return
	if options.invert_y:
		amount.y = -amount.y
	player.look(amount * (options.aim_look if player.aiming else 1.0))

func _tweak(control: String) -> Array:
	return custom.get(control, [0.0, 0.0, 1.0])

func _place(control: String, at: Vector2, reach: Vector2) -> Vector2:
	defaults[control] = at
	var tweak = _tweak(control)
	return (at + Vector2(tweak[0], tweak[1])).clamp(reach, size - reach)

# Right-thumb cluster: fire in the middle, the other actions on an arc around
# it, everything measured from the safe area instead of the raw screen edge.
# There is no reload button: an empty magazine reloads by itself and tapping
# the active weapon chip reloads early.
func layout() -> void:
	var inset = DoodlePen.safe_insets(self)
	var r = size.x - inset[2]
	var b = size.y - inset[3]
	buttons = {
		"fire": [Vector2(r - 165, b - 175), 56.0, "FIRE"],
		"jump": [Vector2(r - 62, b - 95), 40.0, "JUMP"],
		"dash": [Vector2(r - 165, b - 62), 36.0, "DASH"],
		"aim": [Vector2(r - 62, b - 215), 38.0, "AIM"],
		"grapple": [Vector2(r - 110, b - 320), 38.0, "HOOK"],
		"slash": [Vector2(r - 285, b - 140), 36.0, "SLASH"],
		"grenade": [Vector2(r - 270, b - 240), 34.0, "NADE"],
		"smoke": [Vector2(r - 200, b - 325), 30.0, "SMOKE"],
		"pause": [Vector2(r - 44, inset[1] + 44), 26.0, ""] }
	if show_score or editing:
		buttons["scoreboard"] = [Vector2(r - 112, inset[1] + 44), 26.0, "SCORE"]
	if options.reload_button:
		buttons["reload"] = [Vector2(r - 360, b - 70), 30.0, "RELOAD"]
	if options.left_fire:
		buttons["fire_left"] = [Vector2(inset[0] + 60, b - 360), 40.0, "FIRE"]
	for action in buttons:
		var button: Array = buttons[action]
		button[1] *= _tweak(action)[2]
		button[0] = _place(action, button[0], Vector2(button[1], button[1]))
	stick_radius = STICK_RADIUS * _tweak("stick")[2]
	stick_rest = _place("stick", Vector2(inset[0] + 150, b - 150), Vector2(stick_radius, stick_radius))
	# One chip per weapon along the bottom centre replaces a blind cycle button.
	var chip = Vector2(76, 46) * _tweak("weapons")[2]
	var step = chip.x + 8
	var first = _place("weapons", Vector2(size.x * 0.5 - step * NAMES.size() * 0.5 + 4, b - 12 - chip.y), Vector2.ZERO)
	first = first.clamp(Vector2.ZERO, size - Vector2(step * NAMES.size(), chip.y))
	slots.clear()
	for i in NAMES.size():
		slots.append(Rect2(first + Vector2(step * i, 0), chip))
	if is_instance_valid(player) and not editing:
		buttons.dash[2] = "SLIDE" if player.is_on_floor() else "DASH"
		if player.weapon_index == 3:
			buttons.fire[2] = "SLASH"
			buttons.aim[2] = "BLOCK"
			if buttons.has("fire_left"):
				buttons.fire_left[2] = "SLASH"

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if editing:
		_edit(event)
		return
	if event is InputEventScreenTouch:
		layout()
		if event.pressed:
			_press(event)
		else:
			var action: String = held.get(event.index, "")
			held.erase(event.index)
			if action != "" and not held.values().has(action):
				Input.action_release(action)
			if move_finger == event.index:
				move_finger = -1
				move_vector = Vector2.UP if run_locked else Vector2.ZERO
				sprinting = run_locked
	if event is InputEventScreenDrag:
		if event.index == move_finger:
			var raw: Vector2 = (event.position - origin) / stick_radius
			move_vector = raw.limit_length()
			thumb = origin + move_vector * stick_radius
			sprinting = options.stick_sprint and raw.y < -0.9 and absf(raw.x) < absf(raw.y)
			run_locked = options.stick_sprint and options.run_lock and raw.y < -1.9 and absf(raw.x) < 0.8
		else:
			# Any other finger turns the camera, including one holding FIRE.
			turn(event.relative * 0.003 * options.look)

func _press(event: InputEventScreenTouch) -> void:
	for i in slots.size():
		if slots[i].grow(6).has_point(event.position):
			if is_instance_valid(player):
				if i == player.weapon_index:
					player.reload()
				else:
					player.switch_weapon(i)
			held[event.index] = ""
			get_viewport().set_input_as_handled()
			return
	for action in buttons:
		var b: Array = buttons[action]
		if event.position.distance_to(b[0]) < b[1] + 8:
			if action == "aim" and not options.aim_hold and not (is_instance_valid(player) and player.weapon_index == 3):
				# Aim latches so the same thumb stays free to look and fire;
				# the katana block stays a hold because its timing matters.
				aim_locked = not aim_locked
				if aim_locked:
					Input.action_press("aim")
				else:
					Input.action_release("aim")
				held[event.index] = ""
			else:
				if action == "aim":
					aim_locked = false
				if action == "fire_left":
					action = "fire"
				held[event.index] = action
				Input.action_press(action)
			get_viewport().set_input_as_handled()
			return
	if event.position.x < size.x * 0.4 and move_finger < 0:
		var inset = DoodlePen.safe_insets(self)
		move_finger = event.index
		run_locked = false
		sprinting = false
		move_vector = Vector2.ZERO
		origin = Vector2(maxf(event.position.x, inset[0] + stick_radius + 8), minf(event.position.y, size.y - inset[3] - stick_radius - 8))
		if options.fixed_stick:
			origin = stick_rest
		thumb = origin

func reset() -> void:
	for action in held.values():
		if action != "":
			Input.action_release(action)
	held.clear()
	if aim_locked:
		Input.action_release("aim")
	aim_locked = false
	move_finger = -1
	move_vector = Vector2.ZERO
	sprinting = false
	run_locked = false
	dragging = false
	if auto_firing:
		Input.action_release("fire")
	auto_firing = false

# Layout editor: drag any control; the toolbar resizes the selected one.
func _control_at(point: Vector2) -> String:
	for action in buttons:
		if point.distance_to(buttons[action][0]) < buttons[action][1] + 8:
			return action
	if Rect2(slots[0].position, slots[-1].end - slots[0].position).grow(6).has_point(point):
		return "weapons"
	if point.distance_to(stick_rest) < stick_radius:
		return "stick"
	return ""

func _control_position(control: String) -> Vector2:
	if control == "stick":
		return stick_rest
	if control == "weapons":
		return slots[0].position
	return buttons[control][0]

func _edit(event: InputEvent) -> void:
	var press = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	var motion = event is InputEventScreenDrag or event is InputEventMouseMotion
	if not press and not motion:
		return
	layout()
	if press and not event.pressed:
		dragging = false
	elif press:
		if toolbar != null and toolbar.get_global_rect().has_point(event.position):
			return
		var hit = _control_at(event.position)
		if hit != "":
			selected = hit
			dragging = true
			grab = event.position - _control_position(hit)
			get_viewport().set_input_as_handled()
	elif dragging:
		# Absolute placement, so a touch and its emulated mouse event agree.
		var target: Vector2 = (event.position - grab).clamp(Vector2.ZERO, size)
		var offset: Vector2 = target - defaults[selected]
		custom[selected] = [offset.x, offset.y, _tweak(selected)[2]]

func resize_selected(step: float) -> void:
	if selected == "":
		return
	var tweak = _tweak(selected)
	custom[selected] = [tweak[0], tweak[1], clampf(tweak[2] + step, 0.6, 1.6)]

func fade(step: float) -> void:
	opacity = clampf(opacity + step, 0.3, 1.0)

func restore_defaults() -> void:
	custom.clear()
	opacity = 1.0
	selected = ""

func _label(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font = get_theme_default_font()
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-width * 0.5, font_size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# Connected pen strokes; points are in icon units around the button centre.
func _strokes(c: Vector2, u: float, tone: Color, width: float, paths: Array) -> void:
	for path in paths:
		var points = PackedVector2Array()
		for point in path:
			points.append(c + point * u)
		draw_polyline(points, tone, width, true)

# Draws the picture for a control's label; false when there is none.
func _icon(kind: String, c: Vector2, r: float, tone: Color) -> bool:
	var u = r * 0.52
	var w = maxf(2.0, r * 0.075)
	match kind:
		"FIRE":
			# A bullet standing on its case.
			_strokes(c, u, tone, w, [[Vector2(-0.34, 0.85), Vector2(-0.34, -0.15), Vector2(-0.2, -0.65), Vector2(0, -0.95), Vector2(0.2, -0.65), Vector2(0.34, -0.15), Vector2(0.34, 0.85), Vector2(-0.34, 0.85)],
				[Vector2(-0.34, -0.15), Vector2(0.34, -0.15)], [Vector2(-0.42, 0.6), Vector2(0.42, 0.6)]])
		"JUMP":
			# A figure in the air, arms up, above the ground line.
			draw_arc(c + Vector2(0, -0.72) * u, 0.2 * u, 0, TAU, 14, tone, w, true)
			_strokes(c, u, tone, w, [[Vector2(0, -0.5), Vector2(0, 0.08)], [Vector2(-0.5, -0.78), Vector2(0, -0.35), Vector2(0.5, -0.78)],
				[Vector2(-0.18, 0.62), Vector2(-0.38, 0.3), Vector2(0, 0.08), Vector2(0.38, 0.3), Vector2(0.18, 0.62)], [Vector2(-0.6, 0.95), Vector2(0.6, 0.95)]])
		"SLIDE":
			# A crouched runner.
			draw_arc(c + Vector2(0.42, -0.42) * u, 0.2 * u, 0, TAU, 14, tone, w, true)
			_strokes(c, u, tone, w, [[Vector2(0.28, -0.24), Vector2(-0.3, 0.18)], [Vector2(0.6, 0.12), Vector2(0.12, -0.08), Vector2(-0.2, -0.3)],
				[Vector2(-0.3, 0.18), Vector2(0.22, 0.42), Vector2(0.08, 0.86)], [Vector2(-0.3, 0.18), Vector2(-0.7, 0.5), Vector2(-0.92, 0.86)], [Vector2(-0.95, 0.95), Vector2(0.6, 0.95)]])
		"DASH":
			# A runner at full stretch with speed lines behind.
			draw_arc(c + Vector2(0.48, -0.6) * u, 0.2 * u, 0, TAU, 14, tone, w, true)
			_strokes(c, u, tone, w, [[Vector2(0.34, -0.42), Vector2(-0.12, 0.1)], [Vector2(0.72, -0.05), Vector2(0.2, -0.22), Vector2(-0.3, -0.4)],
				[Vector2(-0.12, 0.1), Vector2(0.34, 0.38), Vector2(0.12, 0.82)], [Vector2(-0.12, 0.1), Vector2(-0.58, 0.34), Vector2(-0.9, 0.14)],
				[Vector2(-0.95, -0.55), Vector2(-0.45, -0.55)], [Vector2(-1.0, -0.2), Vector2(-0.6, -0.2)], [Vector2(-0.9, 0.7), Vector2(-0.4, 0.7)]])
		"AIM":
			draw_arc(c, 0.62 * u, 0, TAU, 24, tone, w, true)
			draw_circle(c, 0.09 * u, tone)
			_strokes(c, u, tone, w, [[Vector2(0, -0.95), Vector2(0, -0.35)], [Vector2(0, 0.35), Vector2(0, 0.95)], [Vector2(-0.95, 0), Vector2(-0.35, 0)], [Vector2(0.35, 0), Vector2(0.95, 0)]])
		"BLOCK":
			# A shield.
			_strokes(c, u, tone, w, [[Vector2(-0.62, -0.75), Vector2(0.62, -0.75), Vector2(0.62, 0.05), Vector2(0.36, 0.6), Vector2(0, 0.92), Vector2(-0.36, 0.6), Vector2(-0.62, 0.05), Vector2(-0.62, -0.75)], [Vector2(0, -0.75), Vector2(0, 0.92)]])
		"HOOK":
			# A grappling hook on its rope.
			draw_arc(c + Vector2(0, -0.72) * u, 0.16 * u, 0, TAU, 12, tone, w, true)
			draw_arc(c + Vector2(0, 0.25) * u, 0.55 * u, 0, PI, 16, tone, w, true)
			_strokes(c, u, tone, w, [[Vector2(0, -0.56), Vector2(0, 0.8)], [Vector2(-0.75, 0.0), Vector2(-0.55, 0.25), Vector2(-0.3, 0.05)], [Vector2(0.75, 0.0), Vector2(0.55, 0.25), Vector2(0.3, 0.05)]])
		"SLASH":
			# A blade with its guard and the arc of the cut.
			_strokes(c, u, tone, w, [[Vector2(-0.7, 0.75), Vector2(0.55, -0.6), Vector2(0.72, -0.85), Vector2(0.42, -0.72)], [Vector2(-0.58, 0.2), Vector2(-0.18, 0.62)]])
			draw_arc(c + Vector2(-0.1, 0.1) * u, 0.95 * u, -0.25, 1.25, 14, tone, w * 0.8, true)
		"NADE":
			draw_arc(c + Vector2(0, 0.25) * u, 0.58 * u, 0, TAU, 20, tone, w, true)
			draw_arc(c + Vector2(-0.42, -0.62) * u, 0.15 * u, 0, TAU, 10, tone, w * 0.8, true)
			_strokes(c, u, tone, w, [[Vector2(-0.2, -0.33), Vector2(-0.2, -0.6), Vector2(0.2, -0.6), Vector2(0.2, -0.33)], [Vector2(0.2, -0.55), Vector2(0.62, -0.38), Vector2(0.7, -0.05)]])
		"SMOKE":
			# A canister with puffs rising from it.
			_strokes(c, u, tone, w, [[Vector2(-0.28, 0.1), Vector2(0.28, 0.1), Vector2(0.28, 0.9), Vector2(-0.28, 0.9), Vector2(-0.28, 0.1)], [Vector2(-0.28, 0.45), Vector2(0.28, 0.45)]])
			for puff in [[Vector2(0, -0.25), 0.24], [Vector2(-0.38, -0.55), 0.2], [Vector2(0.36, -0.62), 0.22]]:
				draw_arc(c + puff[0] * u, puff[1] * u, 0, TAU, 12, tone, w * 0.8, true)
		"RELOAD":
			draw_arc(c, 0.68 * u, -0.6, PI * 1.35, 20, tone, w, true)
			_strokes(c, u, tone, w, [[Vector2(0.3, -0.72), Vector2(0.6, -0.36), Vector2(0.9, -0.66)]])
		"SCORE":
			_strokes(c, u, tone, w, [[Vector2(-0.7, -0.5), Vector2(-0.5, -0.5)], [Vector2(-0.25, -0.5), Vector2(0.7, -0.5)], [Vector2(-0.7, 0), Vector2(-0.5, 0)], [Vector2(-0.25, 0), Vector2(0.7, 0)], [Vector2(-0.7, 0.5), Vector2(-0.5, 0.5)], [Vector2(-0.25, 0.5), Vector2(0.4, 0.5)]])
		_:
			return false
	return true

func _draw() -> void:
	if not visible:
		return
	layout()
	var ink = Color(DoodlePen.INK, 0.75)
	var mark = Color(DoodlePen.RED, 0.9)
	for action in buttons:
		var b: Array = buttons[action]
		var down = held.values().has("fire" if action == "fire_left" else action) or (action == "aim" and aim_locked)
		var tone = mark if editing and action == selected else ink
		draw_circle(b[0], b[1], Color(DoodlePen.INK, 0.28) if down else Color(DoodlePen.PAPER, 0.55))
		DoodlePen.sketch_circle(self, b[0], b[1], tone, 3.0 if action == "fire" else 2.5)
		if action == "pause":
			for side in [-6, 6]:
				draw_line(b[0] + Vector2(side, -10), b[0] + Vector2(side, 10), tone, 4, true)
			continue
		# Pen icons in play; the layout editor keeps the words so every control can be told apart.
		if editing or not _icon(b[2], b[0], b[1], tone):
			_label(b[0], b[2], int(b[1] * (0.43 if action == "fire" else 0.47)), tone)
	var live = is_instance_valid(player)
	for i in slots.size():
		var active = live and i == player.weapon_index
		var empty = live and i != 3 and player.magazines[i] + player.reserves[i] <= 0
		var tone = DoodlePen.PAPER if active else Color(DoodlePen.RED if empty else DoodlePen.INK, 0.75)
		DoodlePen.sketch_box(self, slots[i], DoodlePen.INK if active else Color(DoodlePen.PAPER, 0.55), mark if editing and selected == "weapons" else ink, 2.5, 0.6 if i % 2 == 0 else -0.6)
		var ammo = "–"
		if live:
			ammo = "%d%%" % int(player.katana_charge * 100) if i == 3 else "%d / %d" % [player.magazines[i], player.reserves[i]]
		var scale = slots[i].size.y / 46.0
		_label(slots[i].position + slots[i].size * Vector2(0.5, 0.3), NAMES[i], int(18 * scale), tone)
		_label(slots[i].position + slots[i].size * Vector2(0.5, 0.73), "reload" if active and player.magazines[i] <= 0 and i != 3 else ammo, int(14 * scale), tone)
	var center = origin if move_finger >= 0 else stick_rest
	var knob = thumb if move_finger >= 0 else center + move_vector * stick_radius
	var stick_tone = mark if (editing and selected == "stick") or sprinting else ink
	DoodlePen.sketch_circle(self, center, stick_radius, stick_tone, 2.5, true)
	draw_circle(knob, stick_radius * 0.38, Color(stick_tone, 0.25))
	DoodlePen.sketch_circle(self, knob, stick_radius * 0.38, stick_tone, 2.0)
	if options.stick_sprint and options.run_lock and (move_finger >= 0 or run_locked or editing):
		var lock = center + Vector2(0, -stick_radius * 1.9)
		draw_circle(lock, 22, Color(DoodlePen.RED, 0.3) if run_locked else Color(DoodlePen.PAPER, 0.55))
		DoodlePen.sketch_circle(self, lock, 22, mark if run_locked else ink, 2.0)
		_label(lock, "RUN", 15, mark if run_locked else ink)
