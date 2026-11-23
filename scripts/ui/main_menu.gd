extends Control
## Title screen: Play Solo, Host, Join, Customize, Settings, Credits.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(40)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(h)
	var left := UIKit.vbox(18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	var logo := UIKit.title("DISC CHAOS", 120)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(logo)
	var sub := UIKit.label("Sort the mess. Save the collection. Blame your friends.", 30, Color.WHITE, true)
	sub.add_theme_color_override("font_outline_color", UIKit.INK)
	sub.add_theme_constant_override("outline_size", 8)
	left.add_child(sub)
	var stars := StarRow.new().setup(mini(3, Profile.total_stars()), 3, 36)
	var sr := UIKit.hbox(8)
	sr.add_child(stars)
	var sl := UIKit.label("%d stars collected" % Profile.total_stars(), 26, Color.WHITE, true)
	sl.add_theme_color_override("font_outline_color", UIKit.INK)
	sl.add_theme_constant_override("outline_size", 6)
	sr.add_child(sl)
	left.add_child(sr)
	var right := UIKit.vbox(16)
	right.custom_minimum_size = Vector2(560, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(right)
	var main: Node = Game.main
	right.add_child(UIKit.button("Play Solo", UIKit.ORANGE, func(): main.go("levels", "solo"), 44, 104))
	var row := UIKit.hbox(16)
	var hb := UIKit.button("Host", UIKit.TEAL, func():
		if Net.host():
			main.go("lobby")
		else:
			main.message("Couldn't host a game on port %d." % Net.PORT), 38, 96)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hb)
	var jb := UIKit.button("Join", UIKit.BLUE, func(): main.go("join"), 38, 96)
	jb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(jb)
	right.add_child(row)
	right.add_child(UIKit.button("Customize", UIKit.PINK, func(): main.go("customize"), 38, 96))
	var row2 := UIKit.hbox(16)
	var sb := UIKit.button("Settings", UIKit.PURPLE, func(): main.go("settings"), 32, 84)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(sb)
	var cb := UIKit.button("Credits", UIKit.GREY, func(): main.go("credits"), 32, 84)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(cb)
	right.add_child(row2)
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		right.add_child(UIKit.button("Quit", UIKit.RED, func(): get_tree().quit(), 28, 70))
	var ver := UIKit.label("v%s · Hi, %s!" % [ProjectSettings.get_setting("application/config/version"), Profile.nickname], 22, Color.WHITE)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(8, -40)
	ver.add_theme_color_override("font_outline_color", UIKit.INK)
	ver.add_theme_constant_override("outline_size", 6)
	add_child(ver)
	logo.pivot_offset = Vector2(300, 60)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "rotation", 0.03, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "rotation", -0.03, 1.4).set_trans(Tween.TRANS_SINE)
