extends ColorRect
## In-level pause overlay.
var in_overlay := true

func _ready() -> void:
	color = Color(0.1, 0.05, 0.15, 0.55)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(640, 0)
	var v := UIKit.vbox(16)
	p.add_child(v)
	v.add_child(UIKit.label("Paused", 56, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	var info := "%s · %s · %s" % [Game.level_def.get("name", ""), Game.progress_text(), HUDUtil.fmt_time(Game.st.elapsed if Game.st else 0.0)]
	v.add_child(UIKit.label(info, 26, UIKit.INK, false, HORIZONTAL_ALIGNMENT_CENTER))
	if Net.is_online():
		var code := UIKit.label("Room code: %s   ·   IP: %s" % [Net.room_code(), Net.local_ipv4()] if Game.is_host() else "Connected to host", 24, UIKit.TEAL.darkened(0.3), true, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(code)
	var main: Node = Game.main
	v.add_child(UIKit.button("Resume", UIKit.TEAL, func(): main.close_overlay()))
	if Game.is_host():
		v.add_child(UIKit.button("Save game", UIKit.GREEN, func():
			Game.save_game()
			main.close_overlay()))
	v.add_child(UIKit.button("Settings", UIKit.PURPLE, func(): main.overlay("settings")))
	v.add_child(UIKit.button("Customize", UIKit.PINK, func(): main.overlay("customize")))
	v.add_child(UIKit.button("Leave to menu", UIKit.RED, func():
		if Game.is_host() and Game.st and not Game.finished:
			Game.save_game()
		main.leave_to_menu()))
	add_child(UIKit.center(p))
