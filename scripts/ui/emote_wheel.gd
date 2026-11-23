extends Control
## Radial emote wheel / quick chat picker. Tap an option or outside to close.
var chat_mode := false
const EMOTES := ["wave", "dance", "point", "facepalm", "cheer", "shrug"]
const CHATS := ["Over here!", "Need help!", "Found it!", "Nice!", "Oops!", "Wrong case!", "Follow me", "Thanks!"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var opts: Array = CHATS if chat_mode else EMOTES
	var center := get_viewport_rect().size * 0.5
	var r := 300.0
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.25)
	add_child(UIKit.full_rect(bg))
	bg.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			Game.main.close_overlay())
	for i in opts.size():
		var a := -PI / 2 + TAU * i / opts.size()
		var b := UIKit.button(String(opts[i]).capitalize() if not chat_mode else opts[i], [UIKit.ORANGE, UIKit.TEAL, UIKit.PINK, UIKit.BLUE, UIKit.PURPLE, UIKit.GREEN, UIKit.YELLOW, UIKit.RED][i % 8], Callable(), 30, 90)
		b.custom_minimum_size = Vector2(250, 90)
		var opt: String = opts[i]
		b.pressed.connect(func():
			Sfx.ui()
			if chat_mode:
				Game.request_chat(opt)
			else:
				Game.request_emote(opt)
			Game.main.close_overlay())
		add_child(b)
		b.position = center + Vector2(cos(a), sin(a)) * r - Vector2(125, 45)
