class_name TestUtil
extends RefCounted
## Shared helpers for the M1 regression suites.

static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.physics_frame

## Boots the real main scene and loads a level with a fixed seed (no UI flow involved).
static func boot(tree: SceneTree, level: int, seed := 1234) -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await Game.host_start_level(level, seed)
	await frames(tree, 8)
	Game.main.close_overlay()
	return main

static func shutdown(tree: SceneTree, main: Node) -> void:
	main.leave_to_menu()
	await frames(tree, 3)
	main.queue_free()
	await frames(tree, 2)

## Data-only level (no nodes): [def, layout, state].
static func fresh(level: int, seed := 5, wh_items := 300) -> Array:
	var def := Levels.get_def(level, wh_items, seed)
	var L := Layouts.build(def, seed)
	var st := MessGen.build(def, L, seed)
	return [def, L, st]

## Points the player's camera at a world position.
static func aim_at(p: Player, target: Vector3) -> void:
	var d := target - p.camera.global_position
	p.look_yaw = atan2(-d.x, -d.z)
	p.look_pitch = asin(clampf(d.y / maxf(d.length(), 0.001), -1.0, 1.0))
	p.rotation.y = p.look_yaw
	p.cam_pivot.rotation.x = p.look_pitch

## First free closed standard case in the state (not in a stash/shelf/container).
static func free_cases(st: LevelState, n: int) -> Array:
	var out: Array = []
	for it in st.items:
		if it.kind == Defs.K_CASE and it.parent < 0 and it.bucket < 0 and it.stash < 0 and it.holder == 0 and not it.open:
			out.append(it.uid)
			if out.size() >= n:
				break
	return out
