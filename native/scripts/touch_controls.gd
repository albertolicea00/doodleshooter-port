class_name DoodleTouchControls
extends Control

var player: DoodlePlayer
var move_vector = Vector2.ZERO
var move_finger = -1
var look_finger = -1
var origin = Vector2.ZERO
var thumb = Vector2.ZERO
var held: Dictionary = {}
var buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func layout() -> void:
	var s = size
	buttons = {
		"fire": [Vector2(s.x - 108, s.y - 180), 48.0, "FIRE"],
		"jump": [Vector2(s.x - 230, s.y - 103), 36.0, "JUMP"],
		"dash": [Vector2(s.x - 330, s.y - 84), 32.0, "DASH"],
		"grapple": [Vector2(s.x - 92, s.y - 305), 38.0, "HOOK"],
		"aim": [Vector2(s.x - 224, s.y - 230), 32.0, "AIM"],
		"reload": [Vector2(s.x - 345, s.y - 180), 28.0, "R"],
		"grenade": [Vector2(s.x - 333, s.y - 278), 29.0, "G"],
		"next_weapon": [Vector2(s.x - 96, s.y - 67), 30.0, "1–4"],
		"pause": [Vector2(s.x - 46, 40), 24.0, "II"] }

func _input(event: InputEvent) -> void:
	if not visible:
		return
	layout()
	if event is InputEventScreenTouch:
		if event.pressed:
			for action in buttons:
				var b: Array = buttons[action]
				if event.position.distance_to(b[0]) < b[1] + 8:
					held[event.index] = action
					Input.action_press(action)
					get_viewport().set_input_as_handled()
					return
			if event.position.x < size.x * 0.4 and move_finger < 0:
				move_finger = event.index
				origin = event.position
				thumb = origin
			elif look_finger < 0:
				look_finger = event.index
		else:
			if held.has(event.index):
				var action: String = held[event.index]
				held.erase(event.index)
				if not held.values().has(action):
					Input.action_release(action)
			if move_finger == event.index:
				move_finger = -1
				move_vector = Vector2.ZERO
			if look_finger == event.index:
				look_finger = -1
	if event is InputEventScreenDrag:
		if event.index == move_finger:
			move_vector = ((event.position - origin) / 70.0).limit_length()
			thumb = origin + move_vector * 70.0
		elif event.index == look_finger and is_instance_valid(player):
			player.look(event.relative * 0.003)
	queue_redraw()

func reset() -> void:
	for action in held.values():
		Input.action_release(action)
	held.clear()
	move_finger = -1
	look_finger = -1
	move_vector = Vector2.ZERO

func _draw() -> void:
	if not visible:
		return
	layout()
	var ink = Color(0.10, 0.19, 0.76, 0.55)
	var font = ThemeDB.fallback_font
	for b in buttons.values():
		draw_circle(b[0], b[1], Color(0.97, 0.96, 0.91, 0.6))
		draw_arc(b[0], b[1], 0, TAU, 48, ink, 2, true)
		var text_size = font.get_string_size(b[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, b[0] - text_size * Vector2(0.5, -0.25), b[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	var center = origin if move_finger >= 0 else Vector2(145, size.y - 140)
	draw_arc(center, 70, 0, TAU, 48, ink, 2, true)
	draw_circle(thumb if move_finger >= 0 else center, 25, Color(0.10, 0.19, 0.76, 0.23))
