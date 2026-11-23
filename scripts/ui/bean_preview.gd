class_name BeanPreview
extends SubViewportContainer
## Third-person 3D preview of one or more beans (customize screen, lobby).

var vp: SubViewport
var beans: Array = []
var spin := true
var _t := 0.0
var cam: Camera3D

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.92, 0.85)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	vp.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	l.light_energy = 1.2
	vp.add_child(l)
	var l2 := OmniLight3D.new()
	l2.position = Vector3(-1.5, 1.5, 1.5)
	l2.light_color = Color(0.7, 0.85, 1.0)
	l2.light_energy = 0.8
	vp.add_child(l2)
	var floor_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.8
	cyl.height = 0.08
	floor_mi.mesh = cyl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.85, 0.55)
	floor_mi.material_override = fm
	floor_mi.position = Vector3(0, -0.04, 0)
	floor_mi.name = "Pedestal"
	vp.add_child(floor_mi)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.9, 2.6)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 40
	vp.add_child(cam)

func set_beans(looks: Array) -> void:
	for b in beans:
		b.queue_free()
	beans.clear()
	var n := looks.size()
	var ped := vp.get_node_or_null("Pedestal")
	if ped:
		ped.visible = n == 1
	for i in n:
		var b := BeanModel.new()
		b.look = looks[i]
		b.position = Vector3((i - (n - 1) * 0.5) * 0.95, 0, 0)
		vp.add_child(b)
		beans.append(b)
	cam.position = Vector3(0, 0.9 + n * 0.05, 2.6 + maxf(0, n - 1) * 0.8)

func _process(delta: float) -> void:
	_t += delta
	for i in beans.size():
		var b: BeanModel = beans[i]
		if not is_instance_valid(b):
			continue
		if spin:
			b.rotation.y = sin(_t * 0.7 + i) * 0.6 + PI
		if b.wobble:
			b.animate(delta, Vector3.ZERO, true)

func celebrate() -> void:
	for b in beans:
		b.play_emote("cheer")
		var tw = b.create_tween()
		tw.tween_property(b, "rotation:y", b.rotation.y + TAU * 2.0, 0.8).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(b, "position:y", 0.45, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
