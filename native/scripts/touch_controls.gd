class_name DoodleTouchControls
extends Control

const STICK_RADIUS = 78.0
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

# Right-thumb cluster: fire in the middle, the other actions on an arc around
# it, everything measured from the safe area instead of the raw screen edge.
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
		"reload": [Vector2(r - 285, b - 115), 32.0, "RELOAD"],
		"slash": [Vector2(r - 290, b - 215), 34.0, "SLASH"],
		"grenade": [Vector2(r - 235, b - 305), 32.0, "NADE"],
		"pause": [Vector2(r - 44, inset[1] + 44), 26.0, ""] }
	if show_score:
		buttons["scoreboard"] = [Vector2(r - 112, inset[1] + 44), 26.0, "SCORE"]
	# One chip per weapon along the bottom centre replaces a blind cycle button.
	slots.clear()
	for i in 4:
		slots.append(Rect2(size.x * 0.5 - 204 + i * 104, b - 58, 96, 46))

func _input(event: InputEvent) -> void:
	if not visible:
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
				move_vector = Vector2.ZERO
	if event is InputEventScreenDrag:
		if event.index == move_finger:
			move_vector = ((event.position - origin) / STICK_RADIUS).limit_length()
			thumb = origin + move_vector * STICK_RADIUS
		elif is_instance_valid(player):
			# Any other finger turns the camera, including one holding FIRE.
			player.look(event.relative * 0.003)

func _press(event: InputEventScreenTouch) -> void:
	for i in slots.size():
		if slots[i].grow(6).has_point(event.position):
			if is_instance_valid(player):
				player.switch_weapon(i)
			held[event.index] = ""
			get_viewport().set_input_as_handled()
			return
	for action in buttons:
		var b: Array = buttons[action]
		if event.position.distance_to(b[0]) < b[1] + 8:
			if action == "aim":
				# Aim latches so the same thumb stays free to look and fire.
				aim_locked = not aim_locked
				if aim_locked:
					Input.action_press("aim")
				else:
					Input.action_release("aim")
				held[event.index] = ""
			else:
				held[event.index] = action
				Input.action_press(action)
			get_viewport().set_input_as_handled()
			return
	if event.position.x < size.x * 0.4 and move_finger < 0:
		var inset = DoodlePen.safe_insets(self)
		move_finger = event.index
		origin = Vector2(maxf(event.position.x, inset[0] + STICK_RADIUS + 8), minf(event.position.y, size.y - inset[3] - STICK_RADIUS - 8))
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

func _draw() -> void:
	if not visible:
		return
	layout()
	var font = get_theme_default_font()
	var ink = Color(DoodlePen.INK, 0.75)
	for action in buttons:
		var b: Array = buttons[action]
		var down = held.values().has(action) or (action == "aim" and aim_locked)
		draw_circle(b[0], b[1], Color(DoodlePen.INK, 0.28) if down else Color(DoodlePen.PAPER, 0.55))
		DoodlePen.sketch_circle(self, b[0], b[1], ink, 3.0 if action == "fire" else 2.5)
		if action == "pause":
			for side in [-6, 6]:
				draw_line(b[0] + Vector2(side, -10), b[0] + Vector2(side, 10), ink, 4, true)
			continue
		var font_size = 24 if action == "fire" else 15 if b[1] < 36 else 18
		var text_size = font.get_string_size(b[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, b[0] + Vector2(-text_size.x * 0.5, font_size * 0.34), b[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if is_instance_valid(player):
		for i in slots.size():
			var active = i == player.weapon_index
			var empty = i < 3 and player.magazines[i] + player.reserves[i] <= 0
			var tone = DoodlePen.PAPER if active else Color(DoodlePen.RED if empty else DoodlePen.INK, 0.75)
			DoodlePen.sketch_box(self, slots[i], DoodlePen.INK if active else Color(DoodlePen.PAPER, 0.55), ink, 2.5, 0.6 if i % 2 == 0 else -0.6)
			var label: String = player.weapon_names[i].capitalize()
			var ammo = "%d%%" % int(player.katana_charge * 100) if i == 3 else "%d / %d" % [player.magazines[i], player.reserves[i]]
			for line in [[label, 18, 19], [ammo, 14, 38]]:
				var width = font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1]).x
				draw_string(font, slots[i].position + Vector2((slots[i].size.x - width) * 0.5, line[2]), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1], tone)
	var inset = DoodlePen.safe_insets(self)
	var center = origin if move_finger >= 0 else Vector2(inset[0] + 150, size.y - inset[3] - 150)
	DoodlePen.sketch_circle(self, center, STICK_RADIUS, ink, 2.5, true)
	draw_circle(thumb if move_finger >= 0 else center, 30, Color(DoodlePen.INK, 0.25))
	DoodlePen.sketch_circle(self, thumb if move_finger >= 0 else center, 30, ink, 2.0)
