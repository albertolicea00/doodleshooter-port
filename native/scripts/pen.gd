class_name DoodlePen
extends RefCounted

# Pen-on-paper palette and shapes taken from the original game's style.css.
const INK = Color(0.10, 0.19, 0.76)
const RED = Color(0.82, 0.13, 0.19)
const PAPER = Color(0.965, 0.953, 0.902)
const HIT = Color(0.91, 0.50, 0.10)
const GREEN = Color(0.12, 0.56, 0.28)
const BLACK = Color(0.11, 0.11, 0.13)
const CLEAR = Color(0, 0, 0, 0)

static func wobble(point: Vector2, amount: float) -> Vector2:
	var n = sin(point.x * 12.9898 + point.y * 78.233) * 43758.5453
	var m = sin(point.x * 39.3468 + point.y * 11.135) * 24634.6345
	return point + Vector2(n - floorf(n) - 0.5, m - floorf(m) - 0.5) * amount * 2.0

# Outline of the original's uneven hand-drawn box:
# border-radius: 12px 18px 10px 16px / 16px 10px 18px 12px.
static func rounded(rect: Rect2, tilt: float = 0.0, rough: float = 0.0) -> PackedVector2Array:
	var s = rect.size
	var k = minf(1.0, minf(s.x, s.y) / 44.0)
	var radii = [Vector2(12, 16), Vector2(18, 10), Vector2(10, 18), Vector2(16, 12)]
	var corners = [Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]
	var inward = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var outline = PackedVector2Array()
	for c in 4:
		var r: Vector2 = radii[c] * k
		var center: Vector2 = corners[c] + inward[c] * r
		for i in 6:
			var angle = PI + c * PI * 0.5 + PI * 0.5 * i / 5.0
			outline.append(center + Vector2(cos(angle) * r.x, sin(angle) * r.y))
	var points = PackedVector2Array()
	var spin = Transform2D(deg_to_rad(tilt), Vector2.ZERO)
	for i in outline.size():
		var from = outline[i]
		var to = outline[(i + 1) % outline.size()]
		var steps = maxi(1, int(from.distance_to(to) / 48.0))
		for step in steps:
			var point = from.lerp(to, float(step) / steps)
			if step > 0:
				point = wobble(point, rough)
			points.append(rect.position + s * 0.5 + spin * (point - s * 0.5))
	return points

static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop = points.duplicate()
	loop.append(points[0])
	return loop

# Two slightly different strokes, like a circle traced twice with a pen.
static func sketch_circle(item: CanvasItem, center: Vector2, radius: float, color: Color, width: float = 2.5, dashed: bool = false) -> void:
	for stroke in 2:
		var points = PackedVector2Array()
		for i in 49:
			var angle = TAU * i / 48.0 + stroke * 0.7
			var r = radius * (1.0 + 0.022 * sin(angle * 3.0 + stroke * 2.1 + radius)) - stroke * 1.2
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		if dashed:
			for i in range(0, 48, 3):
				item.draw_line(points[i], points[i + 2], color, width, true)
			return
		item.draw_polyline(points, Color(color, color.a * (1.0 if stroke == 0 else 0.45)), width if stroke == 0 else width * 0.6, true)

static func sketch_box(item: CanvasItem, rect: Rect2, fill: Color, ink: Color, width: float = 2.5, tilt: float = 0.0) -> void:
	var points = rounded(rect, tilt, 0.6)
	if fill.a > 0:
		item.draw_colored_polygon(points, fill)
	item.draw_polyline(closed(points), ink, width, true)

# Diagonal pen hatching: repeating-linear-gradient(-55deg, ink, transparent).
static func hatch(item: CanvasItem, rect: Rect2, color: Color, spacing: float = 6.0, width: float = 2.5) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var lean = rect.size.y * 0.7
	var x = -lean
	while x < rect.size.x:
		var from = Vector2(x, rect.size.y)
		var to = Vector2(x + lean, 0)
		var a = from.lerp(to, clampf(-x / lean, 0, 1))
		var b = from.lerp(to, clampf((rect.size.x - x) / lean, 0, 1))
		item.draw_line(rect.position + a, rect.position + b, color, width, true)
		x += spacing

# Screen cutouts and rounded corners, in the control's own units.
static func safe_insets(control: Control) -> Array:
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var window = Vector2(DisplayServer.window_get_size())
	var safe = Rect2(DisplayServer.get_display_safe_area())
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0:
		return [0.0, 0.0, 0.0, 0.0]
	var scale = control.size / window
	return [maxf(0, safe.position.x) * scale.x, maxf(0, safe.position.y) * scale.y, maxf(0, window.x - safe.end.x) * scale.x, maxf(0, window.y - safe.end.y) * scale.y]

static func box(fill: Color, ink: Color = INK, width: float = 2.5, tilt: float = 0.0, margin: Vector2 = Vector2(18, 8)) -> DoodleSketchBox:
	var style = DoodleSketchBox.new()
	style.fill = fill
	style.ink = ink
	style.width = width
	style.tilt = tilt
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	return style

static func dot(diameter: int, color: Color) -> ImageTexture:
	var image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var half = diameter * 0.5
	for y in diameter:
		for x in diameter:
			var distance = Vector2(x + 0.5 - half, y + 0.5 - half).length()
			image.set_pixel(x, y, Color(color, clampf(half - distance, 0, 1)))
	return ImageTexture.create_from_image(image)

static func _button_styles(theme: Theme, type: String, fill: Color, text: Color, tilt: float) -> void:
	var solid = fill.a > 0
	# Outlined buttons draw their border in their text colour.
	var line = fill if solid else text
	theme.set_stylebox("normal", type, box(fill, line, 2.5, tilt))
	theme.set_stylebox("hover", type, box(fill.lightened(0.15) if solid else Color(text, 0.1), fill.lightened(0.15) if solid else text, 2.5, tilt))
	theme.set_stylebox("pressed", type, box(fill.darkened(0.2) if solid else text, fill.darkened(0.2) if solid else text, 2.5, tilt))
	theme.set_stylebox("disabled", type, box(Color(fill, fill.a * 0.4), Color(line, 0.4), 2.5, tilt))
	theme.set_stylebox("focus", type, box(CLEAR, BLACK, 4.0, tilt))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
		theme.set_color(state, type, text)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, type, PAPER)

static func theme(font: Font) -> Theme:
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	var italic = FontVariation.new()
	italic.base_font = font
	italic.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	theme.set_font("italics_font", "RichTextLabel", italic)
	# Filled ink buttons (.bigbtn), outlined buttons (.alt / .mapbtn), the red second button and the big start button.
	_button_styles(theme, "Button", INK, PAPER, -0.6)
	for variation in ["AltButton", "BlackButton", "RedButton", "RedOutlineButton", "GreenButton", "StartButton"]:
		theme.set_type_variation(variation, "Button")
	_button_styles(theme, "AltButton", CLEAR, INK, 0.5)
	_button_styles(theme, "RedButton", RED, PAPER, 0.7)
	_button_styles(theme, "RedOutlineButton", CLEAR, RED, 0.5)
	_button_styles(theme, "GreenButton", GREEN, PAPER, -0.5)
	_button_styles(theme, "BlackButton", CLEAR, BLACK, 0.5)
	_button_styles(theme, "StartButton", INK, PAPER, -1.0)
	for state in ["normal", "hover", "pressed"]:
		var start: DoodleSketchBox = theme.get_stylebox(state, "StartButton")
		start.width = 4
		start.shadow = Color(0, 0, 0, 0.18)
		start.content_margin_top = 8
		start.content_margin_bottom = 12
	theme.set_font_size("font_size", "StartButton", 40)
	_button_styles(theme, "OptionButton", CLEAR, INK, 0.5)
	theme.set_color("font_pressed_color", "OptionButton", PAPER)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.get_stylebox(state, "OptionButton").content_margin_right = 30
	var popup = box(PAPER, INK, 2.5, 0.0, Vector2(10, 10))
	theme.set_stylebox("panel", "PopupMenu", popup)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(INK, 0.14)
	theme.set_stylebox("hover", "PopupMenu", hover)
	for state in ["font_color", "font_hover_color"]:
		theme.set_color(state, "PopupMenu", INK)
	theme.set_constant("v_separation", "PopupMenu", 12)
	theme.set_stylebox("normal", "LineEdit", box(CLEAR, INK, 2.5, 0.0, Vector2(12, 6)))
	theme.set_stylebox("focus", "LineEdit", box(Color(INK, 0.06), BLACK, 4.0, 0.0, Vector2(12, 6)))
	theme.set_stylebox("read_only", "LineEdit", box(CLEAR, Color(INK, 0.4), 2.5, 0.0, Vector2(12, 6)))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color(INK, 0.25))
	var track = StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.25)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var filled = track.duplicate()
	filled.bg_color = INK
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", dot(30, INK))
	theme.set_icon("grabber_highlight", "HSlider", dot(34, INK))
	var bar = StyleBoxFlat.new()
	bar.bg_color = Color(INK, 0.3)
	bar.set_corner_radius_all(4)
	bar.content_margin_left = 3
	bar.content_margin_right = 3
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		theme.set_stylebox(state, "VScrollBar", bar)
	theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	# .panel: paper sheet, ink border and a soft ink offset shadow.
	var panel = box(Color(0.98, 0.972, 0.933, 0.95), INK, 3.0, -0.35, Vector2(36, 26))
	panel.shadow = Color(INK, 0.15)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme
