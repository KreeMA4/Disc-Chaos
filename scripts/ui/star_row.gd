class_name StarRow
extends Control
## Draws 1-3 chunky stars (filled / empty), optionally popping in one by one.

var count := 0
var total := 3
var star_size := 40.0
var _shown := 0.0

func setup(n: int, t := 3, size := 40.0, animate := false) -> StarRow:
	count = n
	total = t
	star_size = size
	custom_minimum_size = Vector2(size * t * 1.1, size)
	_shown = 0.0 if animate else float(t)
	return self

func _process(delta: float) -> void:
	if _shown < total:
		var before := int(_shown)
		_shown = minf(float(total), _shown + delta * 2.5)
		if int(_shown) != before and int(_shown) <= count:
			Sfx.play("snap_good", Vector3.ZERO, 1.0 + int(_shown) * 0.12)
		queue_redraw()

func _draw() -> void:
	for i in total:
		var c := Vector2(star_size * (0.55 + i * 1.1), star_size * 0.5)
		var vis := clampf(_shown - i, 0.0, 1.0)
		if vis <= 0.0:
			continue
		var s := star_size * 0.5 * (0.6 + 0.4 * vis)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2 + TAU * k / 10.0
			pts.append(c + Vector2(cos(a), sin(a)) * (s if k % 2 == 0 else s * 0.45))
		var filled := i < count
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_colored_polygon(pts, Color(1.0, 0.8, 0.2) if filled else Color(0.85, 0.82, 0.78))
		draw_polyline(outline, UIKit.INK, maxf(2.0, star_size * 0.07), true)
