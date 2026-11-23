extends Node3D
## Dev tool: renders every item mesh key (closed/open, lying flat) with the MultiMesh material.
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(3))
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.9, 1.6, 1.3)
	cam.look_at(Vector3(0.9, 0, 0.35))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	add_child(sun)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.4, 0.6, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.5
	we.environment = e
	add_child(we)
	var keys := ["case_0", "case_0_open", "case_1", "case_1_open", "case_3", "case_3_open", "case_4", "case_4_open", "case_5", "case_5_open", "cebox", "cebox_open", "disc_0", "artbook", "figure", "poster", "manual"]
	for i in keys.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = ItemMeshes.mesh(keys[i])
		mm.instance_count = 1
		var lying := Basis(Vector3.RIGHT, -PI * 0.5) if keys[i].begins_with("case") and not keys[i].begins_with("case_4") and not keys[i].begins_with("case_5") else Basis()
		mm.set_instance_transform(0, Transform3D(lying, Vector3((i % 6) * 0.38, 0.05, (i / 6) * 0.45)))
		mm.set_instance_color(0, Color(0.95, 0.3, 0.3))
		mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var kind := Defs.K_CASE
		if keys[i].begins_with("disc"): kind = Defs.K_DISC
		elif keys[i] == "figure": kind = Defs.K_FIGURE
		elif keys[i] in ["artbook", "poster", "manual"]: kind = Defs.K_ARTBOOK
		mmi.material_override = Covers.mm_mats[Covers.mode_for(kind)]
		if "--faces" in OS.get_cmdline_user_args():
			var dm := ShaderMaterial.new()
			dm.shader = load("res://tests/out_face.gdshader")
			mmi.material_override = dm
		add_child(mmi)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/out/item_gallery.png")
	get_tree().quit()
