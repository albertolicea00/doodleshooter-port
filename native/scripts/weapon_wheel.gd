class_name DoodleWeaponWheel
extends Control

# Port addition: hand-drawn radial weapon wheel driven by DualShock 4 / DualSense
# touchpad touches and swipes, while clicking the touchpad opens the scoreboard.

const SLOT_COUNT = 7
const R_INNER = 64.0
const R_SLOT = 138.0
const R_OUTER = 208.0
const SHOW_DELAY = 0.055
const SELECT_RADIUS = 0.28
const CANCEL_RADIUS = 0.22
const FLICK_RADIUS = 0.42
const RELEASE_GRACE = 0.025

var game: Node3D
var open = false
var hovered = -1
var last_swipe_sector = -1
var max_touch_dist = 0.0
var touch_vec = Vector2.ZERO
var touch_hold = 0.0
var release_timer = 0.0
var suppressed_until_lift = false
var font: Font

func _ready() -> void:
	process_priority = -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	font = get_theme_default_font()

static func sector_for(vec: Vector2) -> int:
	var angle = atan2(vec.y, vec.x)
	var rel = fposmod(angle + PI * 0.5 + PI / float(SLOT_COUNT), TAU)
	return clampi(int(floor(rel / (TAU / float(SLOT_COUNT)))), 0, SLOT_COUNT - 1)

func reset() -> void:
	open = false
	visible = false
	hovered = -1
	last_swipe_sector = -1
	max_touch_dist = 0.0
	touch_vec = Vector2.ZERO
	touch_hold = 0.0
	release_timer = 0.0
	suppressed_until_lift = false
	if game != null:
		game.touchpad_scoreboard = false

func _process(delta: float) -> void:
	if game == null:
		return
	var pad = Input.get_magnetometer()
	var state = roundi(pad.z)
	var active_play = game.playing and not game.menu.visible and is_instance_valid(game.player) and game.player.alive
	if not active_play:
		if open or visible or game.touchpad_scoreboard:
			reset()
		return
	# State 2: physical touchpad click -> show scoreboard and cancel any pending wheel selection.
	if state == 2:
		game.touchpad_scoreboard = true
		suppressed_until_lift = true
		open = false
		visible = false
		hovered = -1
		last_swipe_sector = -1
		max_touch_dist = 0.0
		touch_hold = 0.0
		release_timer = 0.0
		return
	game.touchpad_scoreboard = false
	if state == 1:
		release_timer = 0.0
		if suppressed_until_lift:
			return
		touch_vec = Vector2(pad.x, -pad.y).limit_length(1.0)
		var dist = touch_vec.length()
		max_touch_dist = maxf(max_touch_dist, dist)
		if dist >= SELECT_RADIUS:
			var next_sector = sector_for(touch_vec)
			last_swipe_sector = next_sector
			if open and next_sector != hovered:
				hovered = next_sector
				game.rumble(0.08, 0.22, 18)
			elif not open:
				hovered = next_sector
		elif dist < CANCEL_RADIUS:
			hovered = -1
		touch_hold += delta
		if not open and touch_hold >= SHOW_DELAY:
			open = true
			visible = true
		if visible:
			queue_redraw()
	else:
		if suppressed_until_lift:
			release_timer += delta
			if release_timer >= RELEASE_GRACE:
				suppressed_until_lift = false
				release_timer = 0.0
			return
		if touch_hold <= 0.0:
			return
		release_timer += delta
		if release_timer < RELEASE_GRACE:
			return
		var chosen = hovered if open else (last_swipe_sector if max_touch_dist >= FLICK_RADIUS else -1)
		if chosen >= 0 and chosen != game.player.weapon_index:
			game.player.switch_weapon(chosen)
			game.rumble(0.18, 0.35, 35)
		reset()

func _write_centered(at: Vector2, text: String, font_size: int, color: Color) -> void:
	if font == null:
		font = get_theme_default_font()
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-width * 0.5, font_size * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _sector_polygon(index: int, inner_r: float, outer_r: float) -> PackedVector2Array:
	var c = size * 0.5
	var step = TAU / float(SLOT_COUNT)
	var a0 = -PI * 0.5 + float(index) * step - step * 0.5
	var a1 = a0 + step
	var pts = PackedVector2Array()
	var segs = 12
	for s in segs + 1:
		var a = lerpf(a0, a1, float(s) / float(segs))
		pts.append(c + Vector2(cos(a), sin(a)) * outer_r)
	for s in segs + 1:
		var a = lerpf(a1, a0, float(s) / float(segs))
		pts.append(c + Vector2(cos(a), sin(a)) * inner_r)
	return pts

func _draw() -> void:
	if not visible or game == null or not is_instance_valid(game.player):
		return
	var player: DoodlePlayer = game.player
	var center = size * 0.5
	var step = TAU / float(SLOT_COUNT)
	# Soft notebook-paper disc and hand-traced outer/inner ink rings.
	draw_circle(center, R_OUTER + 12.0, Color(DoodlePen.PAPER, 0.90))
	if hovered >= 0:
		var poly = _sector_polygon(hovered, R_INNER + 2.0, R_OUTER + 10.0)
		draw_colored_polygon(poly, Color(DoodlePen.INK, 0.16))
		var a0 = -PI * 0.5 + float(hovered) * step - step * 0.5
		draw_arc(center, R_OUTER + 11.0, a0 + 0.03, a0 + step - 0.03, 18, DoodlePen.RED, 4.5, true)
	DoodlePen.sketch_circle(self, center, R_OUTER + 12.0, DoodlePen.INK, 3.0)
	for i in SLOT_COUNT:
		var div_angle = -PI * 0.5 + float(i) * step - step * 0.5
		var dir = Vector2(cos(div_angle), sin(div_angle))
		draw_line(center + dir * R_INNER, center + dir * (R_OUTER + 11.0), Color(DoodlePen.INK, 0.35), 2.0, true)
		var mid_angle = div_angle + step * 0.5
		var slot_center = center + Vector2(cos(mid_angle), sin(mid_angle)) * R_SLOT
		var is_hovered = i == hovered
		var is_equipped = i == player.weapon_index
		var empty = i != 3 and player.magazines[i] + player.reserves[i] <= 0
		var tone = DoodlePen.INK
		if empty:
			tone = DoodlePen.RED if is_hovered else Color(DoodlePen.RED, 0.65)
		elif not is_hovered and not is_equipped:
			tone = Color(DoodlePen.INK, 0.72)
		var icon_scale = 34.0 if is_hovered else 28.0
		DoodleTouchControls.draw_weapon(self, i, slot_center + Vector2(0, -14), icon_scale, tone)
		var title = "%d · %s" % [i + 1, tr(DoodleTouchControls.NAMES[i])]
		_write_centered(slot_center + Vector2(0, 18), title, 20 if is_hovered else 17, DoodlePen.RED if is_hovered else tone)
		var ammo = "∞" if i == 3 else "%d/%d" % [player.magazines[i], player.reserves[i]]
		_write_centered(slot_center + Vector2(0, 36), ammo, 15, Color(tone, 0.85))
		if is_equipped:
			draw_line(slot_center + Vector2(-34, 25), slot_center + Vector2(34, 25), DoodlePen.INK, 2.0, true)
	# Inner hub: active label + live red-ink touchpad cursor dot.
	draw_circle(center, R_INNER - 1.0, Color(DoodlePen.PAPER, 0.96))
	DoodlePen.sketch_circle(self, center, R_INNER, DoodlePen.INK, 2.5)
	var center_label = tr(DoodleTouchControls.NAMES[hovered if hovered >= 0 else player.weapon_index])
	var sub_label = tr("release to equip") if hovered >= 0 and hovered != player.weapon_index else tr("slide touchpad")
	_write_centered(center + Vector2(0, -6), center_label, 23, DoodlePen.RED if hovered >= 0 else DoodlePen.INK)
	_write_centered(center + Vector2(0, 16), sub_label, 14, Color(DoodlePen.INK, 0.65))
	var cursor = center + touch_vec * (R_INNER - 12.0)
	if touch_vec.length() > 0.06:
		draw_line(center, cursor, Color(DoodlePen.RED, 0.45), 2.0, true)
	draw_circle(cursor, 5.5, DoodlePen.RED)
