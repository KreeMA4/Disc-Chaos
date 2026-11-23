extends ColorRect
## Loading screen with a spinning disc, progress bar and gameplay tips.

const TIPS := [
	"Face-down discs only show their shiny side. Flip or inspect them!",
	"Hold an open case and grab its disc to scoop it right in.",
	"Shelves are sorted A–Z. Dividers show which letters go where.",
	"You can carry a stack of up to 6 closed cases.",
	"The Sort Scanner highlights where your item belongs. It needs to recharge.",
	"Sprinting over a pile of discs is a great way to fall over.",
	"Beanbags, drawers and boxes sometimes hide stray discs.",
	"Golden Greats reprints are a different edition: match them exactly!",
	"Collector's Editions need every piece back in the box.",
	"Throw a case to a friend: hold the throw button to charge.",
	"Sorting tables are great for laying out cases while you hunt.",
]
var bar: ProgressBar
var lbl: Label
var tip: Label
var disc: Control
var _t := 0.0

func _ready() -> void:
	color = Color(0.99, 0.75, 0.45)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UIKit.vbox(26)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(1100, 0)
	add_child(UIKit.center(v))
	disc = Control.new()
	disc.custom_minimum_size = Vector2(160, 160)
	disc.draw.connect(_draw_disc)
	var cc := CenterContainer.new()
	cc.add_child(disc)
	v.add_child(cc)
	v.add_child(UIKit.title("Loading the chaos...", 56))
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(900, 40)
	bar.max_value = 1.0
	v.add_child(bar)
	lbl = UIKit.label("", 28, UIKit.INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(lbl)
	var tp := UIKit.panel()
	tip = UIKit.label("", 30, UIKit.INK, false, HORIZONTAL_ALIGNMENT_CENTER)
	tp.add_child(tip)
	v.add_child(tp)

func show_tip(level_tip: String) -> void:
	if tip:
		tip.text = "TIP: " + (level_tip if level_tip != "" and randf() < 0.5 else TIPS[randi() % TIPS.size()])
	set_progress(0.0, "")

func set_progress(f: float, text: String) -> void:
	if bar:
		bar.value = f
		lbl.text = text

func _process(delta: float) -> void:
	_t += delta
	if disc:
		disc.queue_redraw()

func _draw_disc() -> void:
	var c := disc.size * 0.5
	var r := 70.0
	disc.draw_circle(c, r + 6, UIKit.INK)
	disc.draw_circle(c, r, Color(0.9, 0.92, 1.0))
	for i in 3:
		disc.draw_arc(c, r * (0.85 - i * 0.15), _t * 4.0 + i, _t * 4.0 + i + 1.8, 20, Color.from_hsv(fposmod(_t * 0.2 + i * 0.3, 1.0), 0.6, 1.0), 9)
	disc.draw_circle(c, 14, UIKit.INK)
