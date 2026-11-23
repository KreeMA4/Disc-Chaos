extends Control
## Join: automatic LAN discovery list, room code, or manual IP.
var list: VBoxContainer
var code_edit: LineEdit
var ip_edit: LineEdit
var status: Label

func _ready() -> void:
	var main: Node = Game.main
	var p := UIKit.panel()
	p.custom_minimum_size = Vector2(1500, 820)
	var h := UIKit.hbox(30)
	p.add_child(h)
	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UIKit.label("Games nearby", 44, UIKit.INK, true))
	left.add_child(UIKit.label("Searching your Wi-Fi / hotspot...", 24, UIKit.GREY.darkened(0.3)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	list = UIKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var right := UIKit.vbox(14)
	right.custom_minimum_size = Vector2(560, 0)
	h.add_child(right)
	right.add_child(UIKit.label("Room code", 36, UIKit.INK, true))
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "XXXXX-XXXXX"
	code_edit.text = Settings.get_value("last_code")
	code_edit.custom_minimum_size = Vector2(0, 80)
	right.add_child(code_edit)
	right.add_child(UIKit.button("Join with code", UIKit.TEAL, func():
		var d := Net.decode_code(code_edit.text)
		if d.is_empty():
			status.text = "That code doesn't look right"
			return
		Settings.set_value("last_code", code_edit.text)
		_join(d.ip, d.port)))
	right.add_child(UIKit.label("Manual IP", 36, UIKit.INK, true))
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.23"
	ip_edit.text = Settings.get_value("last_ip")
	ip_edit.custom_minimum_size = Vector2(0, 80)
	right.add_child(ip_edit)
	right.add_child(UIKit.button("Join IP", UIKit.BLUE, func():
		var txt := ip_edit.text.strip_edges()
		var port := Net.PORT
		if txt.find(":") > 0:
			port = int(txt.get_slice(":", 1))
			txt = txt.get_slice(":", 0)
		if not txt.is_valid_ip_address():
			status.text = "Enter an IP like 192.168.1.23"
			return
		_join(txt, port)))
	status = UIKit.label("", 26, UIKit.RED, true)
	right.add_child(status)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	right.add_child(UIKit.button("Back", UIKit.GREY, func():
		Net.stop_listening()
		main.go("menu")))
	add_child(UIKit.center(p))
	Net.start_listening()
	Net.discovered_changed.connect(_refresh)
	Net.joined_ok.connect(_on_joined)
	Net.join_failed.connect(func(r): if is_instance_valid(status): status.text = r)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(list):
		return
	for c in list.get_children():
		c.queue_free()
	if Net.discovered.is_empty():
		list.add_child(UIKit.label("No games found yet. Make sure the host tapped HOST and you're on the same network.", 26, UIKit.GREY.darkened(0.3)))
	for ip in Net.discovered:
		var d: Dictionary = Net.discovered[ip]
		var lvl := Levels.get_def(int(d.get("level", 1)))
		var b := UIKit.button("%s's game  ·  %d/4  ·  %s%s" % [d.get("name", "?"), int(d.get("players", 1)), lvl.name, "  (in progress)" if d.get("running", false) else ""], UIKit.ORANGE, Callable(), 28, 88)
		b.pressed.connect(func(): _join(ip, int(d.get("port", Net.PORT))))
		list.add_child(b)

func _join(ip: String, port: int) -> void:
	status.text = "Connecting to %s..." % ip
	Net.stop_listening()
	Net.join(ip, port)

func _on_joined() -> void:
	Game.main.go("lobby")

func _exit_tree() -> void:
	Net.stop_listening()
