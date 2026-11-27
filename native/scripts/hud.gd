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
var popups: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = get_theme_default_font()

func _ink_color() -> Color:
	return Color(0.84, 0.90, 1.0) if ReferenceAssets.effective_paper().get_luminance() < 0.45 else DoodlePen.INK

func _alert_color() -> Color:
	if game != null and game.colorblind_mode:
		return Color(1.0, 0.56, 0.16) if ReferenceAssets.effective_paper().get_luminance() < 0.45 else Color(0.92, 0.40, 0.04)
	return Color(1.0, 0.42, 0.45) if ReferenceAssets.effective_paper().get_luminance() < 0.45 else DoodlePen.RED

func _process(delta: float) -> void:
	var live = game != null and is_instance_valid(game.player)
	var flash_mul = game.flash_scale if game != null else 1.0
	game.hurt_overlay.material.set_shader_parameter("hurt", game.hurt_flash * flash_mul)
	game.hurt_overlay.material.set_shader_parameter("low", (1.0 if visible and live and game.player.alive and game.player.hp < 36 else 0.0) * flash_mul)
	for entry in popups:
		entry.life -= delta
	popups = popups.filter(func(entry): return entry.life > 0)
	if visible:
		queue_redraw()

# Points rising beside the crosshair, like the original kill feed.
func popup(text: String) -> void:
	popups.append({"text": text, "life": 1.2})

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
	var ink_tone = _ink_color()
	var red_tone = _alert_color()
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
	var tone = red_tone if low else ink_tone
	var x = left + write(Vector2(left, y + 27), tr("Health"), 26, tone) + 10
	bar(Rect2(x, y + 9, 170 if touch_mode else 210, 16), player.hp / 120.0, tone)
	write(Vector2(x + (180 if touch_mode else 220), y + 27), str(ceili(player.hp)), 26, tone)
	# Ammunition: big magazine count, reserve, grenades, then one tally mark per round.
	var big = 46 if touch_mode else 58
	y += 36 + big * 0.86
	x = left
	if katana:
		x += write(Vector2(x, y), tr("Katana"), 34 if touch_mode else 42, ink_tone) + 8
	else:
		x += write(Vector2(x, y), str(magazine), big, ink_tone) + 4
		x += write(Vector2(x, y), "/" + str(player.reserves[player.weapon_index]), 28, Color(ink_tone, 0.8)) + 4
	if player.reload_time > 0:
		x += write(Vector2(x, y), tr(" reloading…"), 22, red_tone)
	x += 12
	for i in player.grenades:
		draw_arc(Vector2(x + 7, y - 9), 7, 0, TAU, 16, ink_tone, 2.5, true)
		draw_line(Vector2(x + 7, y - 21), Vector2(x + 7, y - 16), red_tone, 3)
		x += 19
	# Smoke grenades: filled cans.
	x += 6
	for i in player.smokes:
		draw_rect(Rect2(x + 1, y - 17, 11, 16), Color(ink_tone, 0.55))
		draw_rect(Rect2(x + 1, y - 17, 11, 16), ink_tone, false, 2.0)
		x += 17
	y += 10
	x = left
	for i in mini(magazine, 40) if rows > 0 else 0:
		if i == 20:
			x = left
			y += 24
		var slant = -1.5 if i % 5 == 4 else 0.7
		draw_line(Vector2(x + 2 + slant, y), Vector2(x + 2 - slant, y + 20), Color(ink_tone, 0.9), 4, true)
		x += 17 if i % 5 == 4 else 7
	# Score and combo: top-left on desktop; on touch, centred at the top above the grenade buttons.
	var fps = tr("%d fps") % Engine.get_frames_per_second() if game.show_fps else ""
	if touch_mode:
		var line = score_text + ("   " + combo_text if combo_text != "" else "")
		var line_width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var fps_width = font.get_string_size(fps, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16 if fps != "" else 0.0
		var x0 = size.x * 0.5 - (line_width + fps_width) * 0.5
		write(Vector2(x0, inset[1] + 44), score_text, 26, ink_tone)
		if combo_text != "":
			write(Vector2(x0 + font.get_string_size(score_text + "   ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, inset[1] + 44), combo_text, 26, red_tone)
		if fps != "":
			write(Vector2(x0 + line_width + 16, inset[1] + 44), fps, 20, Color(ink_tone, 0.7))
	else:
		y = top + 30
		write(Vector2(left, y), score_text, 30, ink_tone)
		var score_width = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		if fps != "":
			write(Vector2(left + score_width + 24, y), fps, 20, Color(ink_tone, 0.7))
		write(Vector2(left, y + 28), combo_text, 26, red_tone)
	# Wave, modifier, remaining enemies or match clock: top-right.
	y = top + 30
	for i in info.size():
		var entry: Array = info[i]
		var line_size = 30 if i == 0 else 24
		write(Vector2(right, y), entry[0], line_size, red_tone if entry[1] else ink_tone, true)
		y += line_size + 2
	if not touch_mode:
		_draw_slots(player, right, bottom)
	if katana:
		_draw_focus(player, maxf(size.x * 0.045, inset[0] + 24))
	if boss_name != "":
		var boss_width = font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		# On touch the top centre holds the score and grenade buttons, so the boss bar sits below them.
		var boss_y = inset[1] + 176 if touch_mode else size.y * 0.06 + 24
		write(Vector2(size.x * 0.5 - boss_width * 0.5, boss_y), boss_name, 26, ink_tone)
		bar(Rect2(size.x * 0.5 - 210, boss_y + 8, 420, 20), boss_fraction, red_tone, 7.0)
	_draw_crosshair(player, size * 0.5)
	for i in popups.size():
		var entry: Dictionary = popups[i]
		var rise = (1.2 - entry.life) * 40.0
		write(size * 0.5 + Vector2(46, -18 - rise - i * 4), entry.text, 28, Color(red_tone, clampf(entry.life * 2.0, 0, 1)))

func _draw_slots(player: DoodlePlayer, right: float, bottom: float) -> void:
	var ink_tone = _ink_color()
	var red_tone = _alert_color()
	write(Vector2(right, bottom), tr(DoodleTouchControls.NAMES[player.weapon_index]), 36, ink_tone, true)
	var y = bottom - 44 - 28 * (player.weapon_names.size() - 1)
	for i in player.weapon_names.size():
		var active = i == player.weapon_index
		var empty = i != 3 and player.magazines[i] + player.reserves[i] <= 0
		var tone = Color(red_tone if empty else ink_tone, 1.0 if active else 0.55)
		var ammo = "" if i == 3 else "%d/%d" % [player.magazines[i], player.reserves[i]]
		write(Vector2(right, y), ammo, 16, Color(tone, tone.a * 0.8), true)
		var name_size = 24 if active else 20
		var name_width = write(Vector2(right - 62, y), tr(DoodleTouchControls.NAMES[i]), name_size, tone, true)
		var number = Vector2(right - 62 - name_width - 26, y)
		write(number + Vector2(5, -1), str(i + 1), 15, Color(tone, tone.a * 0.8))
		DoodlePen.sketch_box(self, Rect2(number + Vector2(0, -16), Vector2(18, 19)), DoodlePen.CLEAR, Color(tone, tone.a * 0.8), 1.5)
		if active:
			draw_line(Vector2(number.x, y + 5), Vector2(right, y + 4), ink_tone, 2, true)
		y += 28

# Katana charge tube; it turns red when a focus slash is ready.
func _draw_focus(player: DoodlePlayer, x: float) -> void:
	var ink_tone = _ink_color()
	var red_tone = _alert_color()
	var ready = player.katana_charge >= 1.0
	var tone = red_tone if ready else ink_tone
	var tube = Rect2(x, size.y * 0.5 - 84, 26, 168)
	write(Vector2(x - 12, tube.position.y - 8), tr("Katana"), 17, Color(ink_tone, 0.8))
	var filled = tube.size.y * clampf(player.katana_charge, 0, 1)
	DoodlePen.hatch(self, Rect2(tube.position.x, tube.end.y - filled, tube.size.x, filled), tone, 7.0, 3.0)
	DoodlePen.sketch_box(self, tube, DoodlePen.CLEAR, tone, 3.0, -1.5)
	if ready:
		write(Vector2(x - 8, tube.end.y + 20), tr("Ready"), 15, red_tone)

func _draw_crosshair(player: DoodlePlayer, center: Vector2) -> void:
	var ink_tone = _ink_color()
	var red_tone = _alert_color()
	var style_idx = game.crosshair_style if game != null else 0
	var scale_mul = 1.4 if style_idx == 1 else (1.35 if style_idx == 2 else 1.0)
	var line_w = 4.0 if style_idx >= 1 else 3.0
	var halo = Color(0.05, 0.06, 0.09, 0.85) if ReferenceAssets.effective_paper().get_luminance() >= 0.45 else Color(0.96, 0.96, 0.94, 0.75)
	var katana = player.weapon_index == 3
	if katana or not player.aiming:
		var tone = ink_tone if katana else red_tone
		var reach = (16.0 if katana else 12.0) * scale_mul
		var gap = 10.0 * (1.15 if style_idx >= 1 else 1.0)
		var arms = [[Vector2(0, -gap - reach), Vector2(0, -gap)], [Vector2(0, gap), Vector2(0, gap + reach)]]
		if not katana:
			arms.append([Vector2(-gap - reach, 0), Vector2(-gap, 0)])
			arms.append([Vector2(gap, 0), Vector2(gap + reach, 0)])
		if style_idx == 2:
			for seg in arms:
				draw_line(center + seg[0], center + seg[1], halo, line_w + 3.0, true)
			draw_circle(center, 2.6 * scale_mul + 1.5, halo)
		for seg in arms:
			draw_line(center + seg[0], center + seg[1], tone, line_w, true)
		draw_circle(center, 1.8 * scale_mul, tone)
	if game.hit_marker > 0:
		var fade = clampf(game.hit_marker * 4.0, 0, 1)
		var reach = (13.0 + 6.0 * fade) * scale_mul
		if style_idx == 2:
			draw_line(center - Vector2(reach, reach), center + Vector2(reach, reach), Color(halo, fade * 0.75), 6.0, true)
			draw_line(center + Vector2(-reach, reach), center + Vector2(reach, -reach), Color(halo, fade * 0.75), 6.0, true)
		draw_line(center - Vector2(reach, reach), center + Vector2(reach, reach), Color(DoodlePen.HIT, fade), 3.5, true)
		draw_line(center + Vector2(-reach, reach), center + Vector2(reach, -reach), Color(DoodlePen.HIT, fade), 3.5, true)
	# Grapple breath: a sliver under the crosshair, only while it is not full.
	if player.stamina < 0.995:
		var tone = red_tone if player.stamina < 0.2 else ink_tone
		draw_rect(Rect2(center + Vector2(-32, 26), Vector2(64 * clampf(player.stamina, 0, 1), 5)), Color(tone, 0.8))
		draw_rect(Rect2(center + Vector2(-32, 26), Vector2(64, 5)), Color(tone, 0.8), false, 1.5)
