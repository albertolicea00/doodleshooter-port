class_name DoodleHud
extends Control

# Pen-style heads-up display following the original hud.js / style.css layout.
# With touch controls the bottom corners belong to the thumbs, so health and
# ammunition move to the top-left and the weapon slots become touch chips.
var game: Node3D
var touch_mode = false
var score_text = ""
var combo_text = ""
var info: Array = []
var boss_name = ""
var boss_fraction = 0.0
var font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = get_theme_default_font()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func write(at: Vector2, text: String, font_size: int, color: Color = DoodlePen.INK, right: bool = false) -> float:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at - Vector2(width if right else 0.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return width

func bar(rect: Rect2, fraction: float, color: Color, spacing: float = 6.0) -> void:
	DoodlePen.hatch(self, Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), color, spacing)
	DoodlePen.sketch_box(self, rect, DoodlePen.CLEAR, color, 2.5, -1.0)

func _draw() -> void:
	if game == null or not is_instance_valid(game.player):
		return
	var player: DoodlePlayer = game.player
	var inset = DoodlePen.safe_insets(self)
	var left = maxf(size.x * 0.06, inset[0] + 20) if touch_mode else size.x * 0.09
	var right = size.x - inset[2] - 160 if touch_mode else size.x * 0.96
	var top = inset[1] + 12 if touch_mode else size.y * 0.03
	var bottom = size.y * 0.95
	var katana = player.weapon_index == 3
	var magazine: int = player.magazines[player.weapon_index]
	var rows = 0 if katana or touch_mode else ceili(mini(magazine, 40) / 20.0)
	var y = top if touch_mode else bottom - rows * 24 - 98
	# Health: label, hatched bar and number; everything turns red when low.
	var low = player.hp < 36
	var tone = DoodlePen.RED if low else DoodlePen.INK
	var x = left + write(Vector2(left, y + 27), "Health", 26, tone) + 10
	bar(Rect2(x, y + 9, 170 if touch_mode else 210, 16), player.hp / 120.0, tone)
	write(Vector2(x + (180 if touch_mode else 220), y + 27), str(ceili(player.hp)), 26, tone)
	# Ammunition: big magazine count, reserve, grenades, then one tally mark per round.
	var big = 46 if touch_mode else 58
	y += 36 + big * 0.86
	x = left
	if katana:
		x += write(Vector2(x, y), "Katana", 34 if touch_mode else 42) + 8
	else:
		x += write(Vector2(x, y), str(magazine), big) + 4
		x += write(Vector2(x, y), "/" + str(player.reserves[player.weapon_index]), 28, Color(DoodlePen.INK, 0.8)) + 4
	if player.reload_time > 0:
		x += write(Vector2(x, y), " reloading…", 22, DoodlePen.RED)
	x += 12
	for i in player.grenades:
		draw_arc(Vector2(x + 7, y - 9), 7, 0, TAU, 16, DoodlePen.INK, 2.5, true)
		draw_line(Vector2(x + 7, y - 21), Vector2(x + 7, y - 16), DoodlePen.RED, 3)
		x += 19
	y += 10
	x = left
	for i in mini(magazine, 40) if rows > 0 else 0:
		if i == 20:
			x = left
			y += 24
		var slant = -1.5 if i % 5 == 4 else 0.7
		draw_line(Vector2(x + 2 + slant, y), Vector2(x + 2 - slant, y + 20), Color(DoodlePen.INK, 0.9), 4, true)
		x += 17 if i % 5 == 4 else 7
	# Score and combo: top-left on desktop, under the ammunition on touch.
	y = y + 26 if touch_mode else top + 30
	write(Vector2(left, y), score_text, 26 if touch_mode else 30)
	write(Vector2(left, y + 28), combo_text, 24 if touch_mode else 26, DoodlePen.RED)
	# Wave, modifier, remaining enemies or match clock: top-right.
	y = top + 30
	for i in info.size():
		var entry: Array = info[i]
		var line_size = 30 if i == 0 else 24
		write(Vector2(right, y), entry[0], line_size, DoodlePen.RED if entry[1] else DoodlePen.INK, true)
		y += line_size + 2
	if not touch_mode:
		_draw_slots(player, right, bottom)
	if katana:
		_draw_focus(player, maxf(size.x * 0.045, inset[0] + 24))
	if boss_name != "":
		var boss_width = font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		write(Vector2(size.x * 0.5 - boss_width * 0.5, size.y * 0.06 + 24), boss_name, 26)
		bar(Rect2(size.x * 0.5 - 210, size.y * 0.06 + 32, 420, 20), boss_fraction, DoodlePen.RED, 7.0)
	_draw_crosshair(player, size * 0.5)

func _draw_slots(player: DoodlePlayer, right: float, bottom: float) -> void:
	write(Vector2(right, bottom), player.weapon_names[player.weapon_index].capitalize(), 36, DoodlePen.INK, true)
	var y = bottom - 44 - 28 * 3
	for i in 4:
		var active = i == player.weapon_index
		var empty = i < 3 and player.magazines[i] + player.reserves[i] <= 0
		var tone = Color(DoodlePen.RED if empty else DoodlePen.INK, 1.0 if active else 0.55)
		var ammo = "" if i == 3 else "%d/%d" % [player.magazines[i], player.reserves[i]]
		write(Vector2(right, y), ammo, 16, Color(tone, tone.a * 0.8), true)
		var name_size = 24 if active else 20
		var name_width = write(Vector2(right - 62, y), player.weapon_names[i].capitalize(), name_size, tone, true)
		var number = Vector2(right - 62 - name_width - 26, y)
		write(number + Vector2(5, -1), str(i + 1), 15, Color(tone, tone.a * 0.8))
		DoodlePen.sketch_box(self, Rect2(number + Vector2(0, -16), Vector2(18, 19)), DoodlePen.CLEAR, Color(tone, tone.a * 0.8), 1.5)
		if active:
			draw_line(Vector2(number.x, y + 5), Vector2(right, y + 4), DoodlePen.INK, 2, true)
		y += 28

# Katana charge tube; it turns red when a focus slash is ready.
func _draw_focus(player: DoodlePlayer, x: float) -> void:
	var ready = player.katana_charge >= 1.0
	var tone = DoodlePen.RED if ready else DoodlePen.INK
	var tube = Rect2(x, size.y * 0.5 - 84, 26, 168)
	write(Vector2(x - 12, tube.position.y - 8), "Katana", 17, Color(DoodlePen.INK, 0.8))
	var filled = tube.size.y * clampf(player.katana_charge, 0, 1)
	DoodlePen.hatch(self, Rect2(tube.position.x, tube.end.y - filled, tube.size.x, filled), tone, 7.0, 3.0)
	DoodlePen.sketch_box(self, tube, DoodlePen.CLEAR, tone, 3.0, -1.5)
	if ready:
		write(Vector2(x - 8, tube.end.y + 20), "Ready", 15, DoodlePen.RED)

func _draw_crosshair(player: DoodlePlayer, center: Vector2) -> void:
	var katana = player.weapon_index == 3
	if katana or not player.aiming:
		var tone = DoodlePen.INK if katana else DoodlePen.RED
		var reach = 16.0 if katana else 12.0
		var gap = 10.0
		draw_line(center + Vector2(0, -gap - reach), center + Vector2(0, -gap), tone, 3, true)
		draw_line(center + Vector2(0, gap), center + Vector2(0, gap + reach), tone, 3, true)
		if not katana:
			draw_line(center + Vector2(-gap - reach, 0), center + Vector2(-gap, 0), tone, 3, true)
			draw_line(center + Vector2(gap, 0), center + Vector2(gap + reach, 0), tone, 3, true)
		draw_circle(center, 1.8, tone)
	if game.hit_marker > 0:
		var fade = clampf(game.hit_marker * 4.0, 0, 1)
		var reach = 13.0 + 6.0 * fade
		draw_line(center - Vector2(reach, reach), center + Vector2(reach, reach), Color(DoodlePen.HIT, fade), 3.5, true)
		draw_line(center + Vector2(-reach, reach), center + Vector2(reach, -reach), Color(DoodlePen.HIT, fade), 3.5, true)
	# Grapple breath: a sliver under the crosshair, only while it is not full.
	if player.stamina < 0.995:
		var tone = DoodlePen.RED if player.stamina < 0.2 else DoodlePen.INK
		draw_rect(Rect2(center + Vector2(-32, 26), Vector2(64 * clampf(player.stamina, 0, 1), 5)), Color(tone, 0.8))
		draw_rect(Rect2(center + Vector2(-32, 26), Vector2(64, 5)), Color(tone, 0.8), false, 1.5)
