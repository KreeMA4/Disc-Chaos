extends Control
## Co-op lobby: roster with bean previews, ready-up, host level select, room code.
var arg = null
var roster: VBoxContainer
var preview: BeanPreview
var ready_btn: Button
var start_btn: Button
var level_lbl: Label
var _ready_state := false

func _ready() -> void:
	var main: Node = Game.main
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1600, 860)
	var h := UIKit.hbox(30)
	p.add_child(h)
	var left := UIKit.vbox(12)
	left.custom_minimum_size = Vector2(700, 0)
	h.add_child(left)
	left.add_child(UIKit.label("Lobby", 52, UIKit.INK, true))
	if multiplayer.is_server():
		var code := Net.room_code()
		left.add_child(UIKit.label("Room code: %s" % (code if code != "" else "(no network)"), 38, UIKit.TEAL.darkened(0.3), true))
		left.add_child(UIKit.label("IP %s · port %d · friends on the same Wi-Fi or your hotspot will see this game automatically" % [Net.local_ipv4(), Net.PORT], 22, UIKit.GREY.darkened(0.3)))
	else:
		left.add_child(UIKit.label("Waiting for the host to start...", 30, UIKit.TEAL.darkened(0.3), true))
	roster = UIKit.vbox(10)
	left.add_child(roster)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	level_lbl = UIKit.label("", 30, UIKit.INK, true)
	left.add_child(level_lbl)
	var row := UIKit.hbox(12)
	if multiplayer.is_server():
		row.add_child(UIKit.button("Change level", UIKit.PURPLE, func(): main.go("levels", "host"), 28, 80))
		start_btn = UIKit.button("Start!", UIKit.GREEN, func(): _start(), 34, 80)
		row.add_child(start_btn)
	else:
		ready_btn = UIKit.button("Ready", UIKit.GREEN, func(): _toggle_ready(), 34, 80)
		row.add_child(ready_btn)
	row.add_child(UIKit.button("Customize", UIKit.PINK, func(): main.go("customize", "lobby"), 28, 80))
	left.add_child(row)
	left.add_child(UIKit.button("Leave", UIKit.GREY, func():
		Net.leave()
		main.go("menu"), 28, 72))
	preview = BeanPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(preview)
	add_child(UIKit.center(p))
	Net.players_changed.connect(_refresh)
	Net.lobby_changed.connect(_refresh)
	_refresh()

func _toggle_ready() -> void:
	_ready_state = not _ready_state
	Net.set_ready(_ready_state)
	ready_btn.text = "Not ready" if _ready_state else "Ready"

func _start() -> void:
	if not Net.all_ready():
		Game.toast("Waiting for everyone to be ready")
		return
	var resume: bool = typeof(arg) == TYPE_DICTIONARY and arg.get("resume", false)
	Game.main.host_start(Net.lobby_level, resume)

func _refresh() -> void:
	if not is_instance_valid(roster):
		return
	for c in roster.get_children():
		c.queue_free()
	var looks: Array = []
	var peers: Array = Net.players.keys()
	peers.sort_custom(func(a, b): return int(Net.players[a].idx) < int(Net.players[b].idx))
	for peer in peers:
		var pl: Dictionary = Net.players[peer]
		var r := UIKit.hbox(12)
		var chip := ColorRect.new()
		var col = pl.look.get("color", Color.WHITE)
		chip.color = col if typeof(col) == TYPE_COLOR else Color(str(col))
		chip.custom_minimum_size = Vector2(40, 40)
		r.add_child(chip)
		var n := UIKit.label("%s%s" % [pl.name, "  (host)" if peer == 1 else ""], 32, UIKit.INK, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(n)
		r.add_child(UIKit.label("READY" if pl.ready else "...", 28, UIKit.GREEN.darkened(0.2) if pl.ready else UIKit.GREY, true))
		roster.add_child(r)
		var l: Dictionary = pl.look.duplicate()
		l["name"] = pl.name
		looks.append(l)
	if preview and preview.vp:
		preview.set_beans(looks)
	var d := Levels.get_def(Net.lobby_level)
	level_lbl.text = "Level: %s%s" % [d.name, "  (resume save)" if typeof(arg) == TYPE_DICTIONARY and arg.get("resume", false) else ""]
	if start_btn:
		start_btn.disabled = not Net.all_ready()
