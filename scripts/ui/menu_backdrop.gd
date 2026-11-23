extends Node3D
## Cozy animated diorama behind the menus: a bean surrounded by tumbling discs and cases.

var _t := 0.0
var cam: Camera3D
var pieces: Array = []
var bean: BeanModel

func _ready() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(1.0, 0.78, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.85, 0.75)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	e.fog_enabled = true
	e.fog_light_color = Color(1.0, 0.75, 0.55)
	e.fog_density = 0.04
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var k := MeshKit.new()
	k.cylinder("toon", Transform3D(Basis(), Vector3(0, -0.1, 0)), 3.2, 0.2, Color(0.98, 0.7, 0.75), 40)
	k.cylinder("toon", Transform3D(Basis(), Vector3(0, -0.02, 0)), 2.4, 0.06, Color(1.0, 0.92, 0.6), 40)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var a := TAU * i / 7.0
		PropFactory.build(k, ["plant_big", "beanbag", "cardboard_box", "speaker_big", "lamp_floor", "beanbag", "plant_big"][i], Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * 2.6), {}, rng)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build_mesh("toon")
	mi.material_override = WorldBuilder.mat("toon")
	add_child(mi)
	var em := k.build_mesh("emit")
	if em:
		var mi2 := MeshInstance3D.new()
		mi2.mesh = em
		mi2.material_override = WorldBuilder.mat("emit")
		add_child(mi2)
	bean = BeanModel.new()
	bean.look = Profile.net_look()
	add_child(bean)
	bean.position = Vector3(0.9, 0, 0.3)
	for i in 26:
		var m := MeshInstance3D.new()
		var is_disc := i % 2 == 0
		m.mesh = ItemMeshes.mesh("disc_0" if is_disc else "case_0")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.from_hsv(rng.randf(), 0.5, 1.0) if not is_disc else Color(0.85, 0.88, 0.95)
		mat.metallic = 0.6 if is_disc else 0.0
		mat.roughness = 0.3
		m.material_override = mat
		add_child(m)
		pieces.append({"node": m, "r": rng.randf_range(0.8, 2.4), "a": rng.randf() * TAU, "y": rng.randf_range(0.3, 2.4), "s": rng.randf_range(0.15, 0.5), "spin": Vector3(rng.randf(), rng.randf(), rng.randf()) * 2.0})
	cam = Camera3D.new()
	cam.fov = 55
	add_child(cam)
	cam.make_current()

func _process(delta: float) -> void:
	_t += delta
	cam.position = Vector3(sin(_t * 0.08) * 0.6 - 0.6, 1.5, 4.2)
	cam.look_at(Vector3(0.2, 0.9, 0))
	for p in pieces:
		var a: float = p.a + _t * p.s
		var n: Node3D = p.node
		n.position = Vector3(cos(a) * p.r, p.y + sin(_t + p.a) * 0.15, sin(a) * p.r)
		n.rotation += p.spin * delta
	if bean:
		bean.rotation.y = sin(_t * 0.5) * 0.4 + 0.3
		bean.animate(delta, Vector3.ZERO, true)
		if int(_t) % 7 == 0 and bean.emote == "":
			bean.play_emote(["wave", "dance", "cheer"][int(_t / 7) % 3])

func refresh_bean() -> void:
	if bean:
		bean.apply_look(Profile.net_look())
