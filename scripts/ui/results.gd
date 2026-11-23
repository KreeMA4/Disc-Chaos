extends ColorRect
## Results screen: stars, time vs par, stats per player, next level.
var arg := {}
var in_overlay := true

func _ready() -> void:
	color = Color(0.1, 0.05, 0.15, 0.6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var d: Dictionary = arg
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1300, 0)
	var v := UIKit.vbox(14)
	p.add_child(v)
	v.add_child(UIKit.label("%s — sorted!" % d.level.name, 52, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	var cc := CenterContainer.new()
	cc.add_child(StarRow.new().setup(int(d.stars), 3, 96, true))
	v.add_child(cc)
	v.add_child(UIKit.label("Time %s   ·   Par %s   ·   %d products" % [HUDUtil.fmt_time(d.time), HUDUtil.fmt_time(d.par), d.products], 32, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 6
	for h in ["Player", "Sorted", "Matched", "Mistakes", "Slips", "Walked"]:
		grid.add_child(UIKit.label(h, 28, UIKit.ORANGE.darkened(0.3), true))
	var keys: Array = d.stats.keys()
	keys.sort_custom(func(a, b): return int(d.stats[a].get("sorted", 0)) > int(d.stats[b].get("sorted", 0)))
	for k in keys:
		var s: Dictionary = d.stats[k]
		for val in [s.get("name", "?"), str(int(s.get("sorted", 0))), str(int(s.get("matched", 0))), str(int(s.get("mistakes", 0))), str(int(s.get("slips", 0))), "%d m" % int(s.get("distance", 0))]:
			var l := UIKit.label(val, 28, UIKit.INK)
			l.custom_minimum_size = Vector2(170, 0)
			grid.add_child(l)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	var unl := _new_unlocks(int(d.stars))
	if unl != "":
		v.add_child(UIKit.label(unl, 28, UIKit.PURPLE, true, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var main: Node = Game.main
	var next_id: int = int(d.level.id) + 1
	if Game.is_host() and next_id <= 5:
		row.add_child(UIKit.button("Next level", UIKit.GREEN, func():
			Net.lobby_level = next_id
			Net.set_lobby_level(next_id)
			main.close_overlay()
			main.host_start(next_id)))
	if Game.is_host():
		row.add_child(UIKit.button("Replay", UIKit.TEAL, func():
			main.close_overlay()
			main.host_start(int(d.level.id))))
	row.add_child(UIKit.button("Menu", UIKit.GREY, func(): main.leave_to_menu()))
	v.add_child(row)
	add_child(UIKit.center(p))
	Sfx.play("jingle")

func _new_unlocks(_stars: int) -> String:
	var total := Profile.total_stars()
	var names: Array = []
	for cat in Profile.UNLOCKS:
		for idx in Profile.UNLOCKS[cat]:
			var need: int = Profile.UNLOCKS[cat][idx]
			if need <= total and need > total - _stars:
				names.append(Profile.COSMETICS[cat][idx])
	if names.is_empty():
		return ""
	return "New cosmetics unlocked: " + ", ".join(names)
