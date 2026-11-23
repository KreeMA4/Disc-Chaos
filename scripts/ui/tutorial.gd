extends ColorRect
## First-time "how to sort" card (level 1). Shown as an overlay so it gets every tap.
var in_overlay := true

func _ready() -> void:
	color = Color(0.1, 0.05, 0.15, 0.45)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1050, 0)
	var v := UIKit.vbox(10)
	p.add_child(v)
	v.add_child(UIKit.label("How to sort", 48, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var steps := "1. Find a disc and GRAB it. Face-down discs: tap OPEN/FLIP or INSPECT to read them.\n2. Look at its matching case (same art and logo) and GRAB again to slot it in. The case must be open: INTERACT opens it.\n3. Pick up the case and INTERACT to close it.\n4. Walk to the shelf of that platform, find the A–Z divider and follow the glowing ghost. GRAB to shelve!\n\nWrong disc in a case? Hold the open case and INTERACT to take it out. Stuck? Use the SCANNER."
	if not touch:
		steps += "\n\nKeys: WASD move · Mouse look · E grab · F interact · Q throw · R inspect · Tab scanner · Esc pause"
	else:
		steps += "\n\nLeft side: move. Drag the right side: look around."
	var l := UIKit.label(steps, 30, UIKit.INK)
	l.custom_minimum_size.x = 980
	v.add_child(l)
	v.add_child(UIKit.button("Let's sort!", UIKit.TEAL, func(): Game.main.close_overlay(), 34, 84))
	add_child(UIKit.center(p))
