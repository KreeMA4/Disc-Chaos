extends Control
## Level select (solo or host). Shows stars, locks, continue-from-save and warehouse settings.

var arg = "solo"

func _ready() -> void:
	var main: Node = Game.main
	var v := UIKit.vbox(16)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var top := UIKit.hbox()
	top.add_child(UIKit.button("Back", UIKit.GREY, func(): main.go("lobby" if arg == "host" else "menu"), 30, 76))
	var t := UIKit.title("Choose a mess" if arg == "solo" else "Pick the level", 64)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	v.add_child(top)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var row := UIKit.hbox(22)
	sc.add_child(row)
	var defs: Array = Levels.LIST.duplicate()
	defs.append(Levels.WAREHOUSE)
	var cols := [UIKit.ORANGE, UIKit.TEAL, UIKit.PURPLE, Color(0.75, 0.55, 0.35), UIKit.PINK, UIKit.BLUE]
	for i in defs.size():
		var d: Dictionary = defs[i]
		row.add_child(_card(d, cols[i], main))

func _card(d: Dictionary, col: Color, main: Node) -> Control:
	var unlocked := Profile.level_unlocked(d.id)
	var p := UIKit.panel(col.lightened(0.55) if unlocked else Color(0.82, 0.8, 0.78))
	p.custom_minimum_size = Vector2(420, 620)
	var v := UIKit.vbox(10)
	p.add_child(v)
	v.add_child(UIKit.label("LEVEL %d" % d.id if d.id <= 5 else "BONUS", 26, col.darkened(0.35), true))
	v.add_child(UIKit.label(d.name, 40, UIKit.INK, true))
	var desc := UIKit.label(d.desc, 24, UIKit.INK.lerp(Color.WHITE, 0.25))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var plats: Array = d.platforms.map(func(x): return Defs.PLATFORMS[x].name)
	v.add_child(UIKit.label("%d items · %s" % [d.target_items, ", ".join(plats.slice(0, 3)) + ("…" if plats.size() > 3 else "")], 22, UIKit.INK))
	var s := StarRow.new().setup(int(Profile.stars.get(d.id, Profile.stars.get(str(d.id), 0))), 3, 44)
	v.add_child(s)
	if Profile.best_time.has(d.id):
		v.add_child(UIKit.label("Best: %s" % HUDUtil.fmt_time(float(Profile.best_time[d.id])), 22, UIKit.INK))
	if d.id == 6 and unlocked:
		v.add_child(UIKit.slider_row("Items", 100, 2000, 50, float(Settings.get_value("warehouse_items")), func(x): Settings.set_value("warehouse_items", int(x)), "%d"))
	if not unlocked:
		v.add_child(UIKit.button("Locked", UIKit.GREY, Callable(), 30, 80))
		return p
	if Game.has_save(d.id):
		v.add_child(UIKit.button("Continue", UIKit.GREEN, func(): _start(d.id, true, main), 30, 80))
	elif Game.has_save_file(d.id):
		# a save that this version cannot continue: keep it on disk, explain, and let the player discard it
		var note := UIKit.vbox(6)
		note.add_child(UIKit.label(Game.save_info(d.id).message, 20, UIKit.INK.lerp(Color.WHITE, 0.2)))
		note.add_child(UIKit.button("Discard old save", UIKit.RED, func():
			Game.delete_save(d.id)
			note.queue_free(), 24, 60))
		v.add_child(note)
	v.add_child(UIKit.button("Play" if arg == "solo" else "Select", col, func(): _start(d.id, false, main), 34, 84))
	return p

func _start(id: int, resume: bool, main: Node) -> void:
	if arg == "solo":
		Net.lobby_level = id
		main.start_solo(id, resume)
	else:
		Net.set_lobby_level(id)
		Net.lobby_level = id
		main.go("lobby", {"resume": resume})
