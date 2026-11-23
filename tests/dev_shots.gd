extends Node
## Dev tool: start a level, move the camera through viewpoints, save screenshots + perf stats.
## Usage: godot --path . -- --dev-shots=<level> [--shots-out=tests/out]
var level := 1
var out_dir := "res://tests/out"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dev-shots="):
			level = int(a.substr(12))
		if a.begins_with("--shots-out="):
			out_dir = a.substr(12)
	get_tree().create_timer(240).timeout.connect(func(): print("SHOTS TIMEOUT"); get_tree().quit(3))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	await get_tree().create_timer(0.5).timeout
	await _shot("menu")
	Game.main.start_solo(level)
	await Game.level_loaded
	for i in 30:
		await get_tree().process_frame
	var p: Player = Game.local_player
	var L: LevelLayout = Game.layout
	var views: Array = []
	views.append(["spawn", p.global_position, p.look_yaw, -0.15])
	var c := L.bounds.get_center()
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var pos := Vector3(c.x + cos(a) * L.bounds.size.x * 0.3, 0, c.y + sin(a) * L.bounds.size.y * 0.3)
		views.append(["view%d" % i, pos, atan2(pos.x - c.x, pos.z - c.y), -0.25])
	if not Game.st.buckets.is_empty():
		var b: Dictionary = Game.st.buckets[0]
		var bx: Transform3D = b.xf
		var front := bx.origin + bx.basis.z * 1.1 + bx.basis.x * 0.4
		views.append(["shelf", Vector3(front.x, 0, front.z), atan2(bx.basis.z.x, bx.basis.z.z), -0.35])
	for v in views:
		p.global_position = v[1]
		p.look_yaw = v[2]
		p.look_pitch = v[3]
		for i in 20:
			await get_tree().physics_frame
		await _shot(v[0])
	# grab test: target nearest item and pick it up, then inspect
	var near: Array = Game.st.query_box(p.global_position, 3.0)
	if not near.is_empty():
		Game.request_grab(near[0])
		for i in 10:
			await get_tree().physics_frame
		p.inspecting = true
		for i in 40:
			await get_tree().process_frame
		await _shot("inspect")
	var info := "draw_calls=%d objects=%d prims=%d vram_mb=%.1f static_mem_mb=%.1f active_bodies=%d multimeshes=%d static_items=%d fps=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		OS.get_static_memory_usage() / 1048576.0, Game.world.active_count(), Game.world.multimesh_count(), Game.world.static_instance_count(), Engine.get_frames_per_second()]
	print("PERF ", info)
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%s.png" % [out_dir, name])
	print("shot ", name)
