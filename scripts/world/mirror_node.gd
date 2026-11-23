class_name MirrorNode
extends Node3D
## Planar mirror (at each level's spawn) so players can admire their bean. Renders a low-res
## reflection only while the local camera is close and the preset allows it.

var size := Vector2(0.8, 1.8)
var enabled_quality := true
var _vp: SubViewport
var _cam: Camera3D
var _quad: MeshInstance3D
var _mat: StandardMaterial3D
const ACTIVE_DIST := 4.5

func _ready() -> void:
	_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	_quad.mesh = qm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.75, 0.85, 0.92)
	_mat.uv1_scale = Vector3(-1, 1, 1)
	_mat.uv1_offset = Vector3(1, 0, 0)
	_quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)
	if not enabled_quality or DisplayServer.get_name() == "headless":
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(320 * size.x / size.y * 2.0), 640)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_cam.cull_mask = 0xFFFFF
	_vp.add_child(_cam)
	_mat.albedo_texture = _vp.get_texture()
	_mat.albedo_color = Color(0.92, 0.96, 1.0)

func _process(_delta: float) -> void:
	if _vp == null:
		return
	var main := get_viewport().get_camera_3d()
	if main == null:
		return
	var local := global_transform.affine_inverse() * main.global_position
	var close := local.z > 0.05 and local.length() < ACTIVE_DIST
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if close else SubViewport.UPDATE_DISABLED
	if not close:
		return
	var b := global_transform.basis * Basis(Vector3.UP, PI)
	_cam.global_transform = Transform3D(b, global_transform * Vector3(local.x, local.y, -local.z))
	_cam.set_frustum(size.y, Vector2(local.x, -local.y), local.z, 40.0)
	_cam.environment = main.environment
