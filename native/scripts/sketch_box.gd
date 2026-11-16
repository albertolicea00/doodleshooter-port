class_name DoodleSketchBox
extends StyleBox

# Hand-drawn box used by every menu control instead of flat engine panels.
var fill = Color(0, 0, 0, 0)
var ink = DoodlePen.INK
var width = 2.5
var tilt = 0.0
var shadow = Color(0, 0, 0, 0)
var shadow_offset = Vector2(6, 7)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# Keep the slant to a few pixels however wide the control is.
	var points = DoodlePen.rounded(rect.grow(-width * 0.5), tilt * minf(1.0, 200.0 / rect.size.x), 0.6)
	if shadow.a > 0:
		var cast = PackedVector2Array()
		for point in points:
			cast.append(point + shadow_offset)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, cast, [shadow])
	if fill.a > 0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, points, [fill])
	var line = DoodlePen.closed(points)
	RenderingServer.canvas_item_add_polyline(to_canvas_item, line, [ink], width, true)
