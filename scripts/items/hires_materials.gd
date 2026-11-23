class_name HiresMaterials
extends RefCounted
## Per-item high-resolution materials for held / inspected items. Textures stream in from Covers.

static var _shader: Shader
static var _blank: Texture2D

static func for_item(st: LevelState, it: LevelState.Item) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/item_hires.gdshader")
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.55, 0.55, 0.6))
		_blank = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("plastic", Covers.item_plastic(st, it))
	m.set_shader_parameter("mode", Covers.mode_for(it.kind))
	for p in ["front_tex", "back_tex", "spine_tex"]:
		m.set_shader_parameter(p, _blank)
	if it.product < 0:
		return m
	var prod: Dictionary = st.products[it.product]
	var title: int = prod.title
	var ed: int = prod.edition
	var steel := ed == Defs.E_STEEL and it.kind == Defs.K_CASE
	m.set_shader_parameter("steel", steel)
	var fmt := it.fmt
	var kind := it.kind
	var set_tex := func(tex: Texture2D, param: String) -> void:
		if tex:
			m.set_shader_parameter(param, tex)
	match it.kind:
		Defs.K_DISC:
			_req(title, ed, "label", it.sub, fmt, kind, set_tex.bind("front_tex"))
			_req(title, ed, "spine", 0, fmt, Defs.K_CASE, set_tex.bind("spine_tex"))
		Defs.K_FIGURE:
			pass
		_:
			_req(title, ed, "steel" if steel else "front", 0, fmt, kind, set_tex.bind("front_tex"))
			_req(title, ed, "back", 0, fmt, kind, set_tex.bind("back_tex"))
			_req(title, ed, "spine", 0, fmt, kind, set_tex.bind("spine_tex"))
	return m

static func _req(title: int, ed: int, part: String, disc: int, fmt: int, kind: int, cb: Callable) -> void:
	var tex := Covers.get_hires(title, ed, part, disc, fmt, kind, func(t): cb.call(t))
	if tex:
		cb.call(tex)
