class_name Player
extends CharacterBody3D
## Local first-person player. Movement is client-predicted (each peer owns its own body); every
## item action is a request to the host via Game.

const WALK := 3.3
const SPRINT := 5.6
const CROUCH := 1.7
const JUMP_V := 4.6
const GRAVITY := 13.0
const EYE := 1.16
const EYE_CROUCH := 0.72
const REACH := 2.5
const MAX_STACK := 6

var peer_id := 1
var look_yaw := 0.0
var look_pitch := 0.0
var touch_move := Vector2.ZERO
var _look_accum := Vector2.ZERO
var crouching := false
var sprinting := false
var inspecting := false
var inspect_rot := Basis()
var slipping := 0.0
var slip_spin := Vector3.ZERO
var throw_charge := -1.0
var distance_walked := 0.0
var flashlight_on := false
var _bob_t := 0.0
var _slip_cooldown := 0.0
var _bump_cd := 0.0
var _kick_t := 0.0
var _step_t := 0.0

# targeting
var target := {}            # {type: "item"|"bucket"|"table"|"stash"|"cart"|"", uid, bid, table, cell, stash, point}
var ghost_ok := true

var cam_pivot: Node3D
var camera: Camera3D
var hold_point: Node3D
var hands: FPHands
var bean: BeanModel
var ghost: MeshInstance3D
var flashlight: SpotLight3D
var _held_vis: Node3D
var _held_sig := ""

func _ready() -> void:
	collision_layer = Defs.LAYER_PLAYER
	collision_mask = Defs.LAYER_WORLD | Defs.LAYER_PLAYER | Defs.LAYER_CART
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.66, 0)
	add_child(cs)
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, EYE, 0)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.fov = float(Settings.get_value("fov"))
	camera.near = 0.03
	camera.far = 120.0
	camera.cull_mask = 0xFFFFF & ~2
	cam_pivot.add_child(camera)
	camera.make_current()
	hold_point = Node3D.new()
	hold_point.position = Vector3(0.0, -0.2, -0.5)
	camera.add_child(hold_point)
	hands = FPHands.new()
	camera.add_child(hands)
	hands.set_glove(BeanModel.glove_color(int(Profile.look.get("gloves", 0))))
	bean = BeanModel.new()
	bean.look = Profile.net_look()
	add_child(bean)
	_set_layer_recursive(bean, 2)
	bean.set_name_visible(false)
	ghost = MeshInstance3D.new()
	ghost.material_override = WorldBuilder.mat("ghost").duplicate()
	ghost.visible = false
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.top_level = true
	add_child(ghost)
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 9.0
	flashlight.spot_angle = 32.0
	flashlight.light_energy = 2.2
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.position = Vector3(0.15, -0.1, 0)
	flashlight.visible = false
	flashlight.shadow_enabled = false
	camera.add_child(flashlight)
	Settings.changed.connect(_on_setting)

func _set_layer_recursive(n: Node, layer_bits: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layer_bits
	for c in n.get_children():
		_set_layer_recursive(c, layer_bits)

func _on_setting(key: String) -> void:
	if key == "fov":
		camera.fov = float(Settings.get_value("fov"))

func refresh_look() -> void:
	bean.apply_look(Profile.net_look())
	await get_tree().process_frame
	_set_layer_recursive(bean, 2)
	bean.set_name_visible(false)
	hands.set_glove(BeanModel.glove_color(int(Profile.look.get("gloves", 0))))

# ------------------------------------------------------------------ input
func add_look(delta_px: Vector2) -> void:
	_look_accum += delta_px

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		add_look(event.relative * 1.6)
	elif event is InputEventMouseButton:
		var action := ""
		match event.button_index:
			MOUSE_BUTTON_LEFT: action = "grab"
			MOUSE_BUTTON_RIGHT: action = "throw"
			MOUSE_BUTTON_MIDDLE: action = "inspect"
		if action != "":
			if event.pressed:
				Input.action_press(action)
			else:
				Input.action_release(action)

func held() -> Array:
	return Game.st.held_by(peer_id) if Game.st else []

func top_held() -> int:
	var h := held()
	return h[h.size() - 1] if not h.is_empty() else -1

func _physics_process(delta: float) -> void:
	if Game.st == null:
		return
	_slip_cooldown -= delta
	_bump_cd -= delta
	var paused := Game.ui_blocking
	# --- look
	var sens := float(Settings.get_value("look_sens")) * 0.0032
	var pad_look := Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
	var look_d := _look_accum * sens + pad_look * delta * 2.6 * float(Settings.get_value("look_sens"))
	_look_accum = Vector2.ZERO
	if Settings.get_value("invert_y"):
		look_d.y = -look_d.y
	if inspecting and not paused:
		inspect_rot = Basis(Vector3.UP, look_d.x * 2.5) * Basis(Vector3.RIGHT, look_d.y * 2.5) * inspect_rot
	elif slipping <= 0.0 and not paused:
		look_yaw -= look_d.x
		look_pitch = clampf(look_pitch - look_d.y, deg_to_rad(-85), deg_to_rad(85))
	rotation.y = look_yaw
	cam_pivot.rotation.x = look_pitch
	# --- move
	var mv := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back"))
	if touch_move.length() > 0.05:
		mv = touch_move
	if mv.length() > 1.0:
		mv = mv.normalized()
	if paused or inspecting or slipping > 0.0:
		mv = Vector2.ZERO
	sprinting = Input.is_action_pressed("sprint") and mv.y < -0.2 and not crouching
	if Input.is_action_just_pressed("crouch") and not paused:
		crouching = not crouching
	var speed := SPRINT if sprinting else (CROUCH if crouching else WALK)
	var stack_slow := 1.0 - 0.04 * maxf(0.0, held().size() - 1)
	speed *= stack_slow
	var pushing := pushing_cart()
	if pushing >= 0:
		speed *= 0.85
	var dir := (transform.basis * Vector3(mv.x, 0, mv.y))
	var hv := Vector3(velocity.x, 0, velocity.z)
	var target_v := dir * speed
	var accel := 18.0 if is_on_floor() else 5.0
	if slipping > 0.0:
		accel = 1.2
		target_v = Vector3.ZERO
	hv = hv.move_toward(target_v, accel * delta * maxf(speed, 3.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not paused and slipping <= 0.0 and not inspecting:
		velocity.y = JUMP_V
		Sfx.play("jump", global_position)
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	distance_walked += moved
	_handle_player_bumps()
	_update_cart_push()
	# --- crouch eye height, bob, slip tumble
	var eye := EYE_CROUCH if crouching else EYE
	_bob_t += moved * 2.4
	var bob := sin(_bob_t * 2.0) * 0.025 * (1.0 if Settings.get_value("head_bob") else 0.0) * clampf(hv.length() / WALK, 0.0, 1.0)
	if slipping > 0.0:
		slipping -= delta
		var k := clampf(slipping / 1.4, 0.0, 1.0)
		var fall := sin(k * PI)
		cam_pivot.position.y = lerpf(cam_pivot.position.y, 0.35 + (1.0 - fall) * (eye - 0.35), delta * 8.0)
		camera.rotation = Vector3(slip_spin.x * fall, 0, slip_spin.z * fall)
		if slipping <= 0.0:
			camera.rotation = Vector3.ZERO
	else:
		cam_pivot.position.y = lerpf(cam_pivot.position.y, eye + bob, delta * 10.0)
	# footsteps
	if is_on_floor() and hv.length() > 0.8:
		_step_t -= moved
		if _step_t <= 0.0:
			_step_t = 0.55 if not sprinting else 0.75
			Sfx.play("step", global_position, randf_range(0.9, 1.15), -8.0 if crouching else -2.0)
	# --- kick and slip on loose discs (host simulates the kicked bodies)
	_kick_t -= delta
	if _kick_t <= 0.0 and hv.length() > 1.2:
		_kick_t = 0.12
		Game.request_kick(global_position, hv)
		if slipping <= 0.0 and _slip_cooldown <= 0.0 and (sprinting or hv.length() > 3.0):
			var discs := _discs_underfoot()
			if discs >= 2 and randf() < 0.12 * discs:
				start_slip()
	# --- targeting & ghost
	_update_target()
	_update_held_visual(delta)
	# --- actions
	if not paused and slipping <= 0.0:
		_actions(delta)
	bean.carrying = not held().is_empty()
	bean.animate(delta, velocity, is_on_floor())
	bean.visible = true
	Game.send_player_state(self)

func _discs_underfoot() -> int:
	var n := 0
	for uid in Game.st.query_box(global_position, 0.5):
		var it: LevelState.Item = Game.st.items[uid]
		if it.kind == Defs.K_DISC and it.parent < 0 and it.bucket < 0 and it.holder == 0:
			var p := Game.st.world_xf(uid).origin
			if absf(p.y - global_position.y) < 0.25 and Vector2(p.x - global_position.x, p.z - global_position.z).length() < 0.42:
				n += 1
	return n

func start_slip() -> void:
	slipping = 1.4
	_slip_cooldown = 4.0
	var side := 1.0 if randf() < 0.5 else -1.0
	slip_spin = Vector3(deg_to_rad(randf_range(40, 70)), 0, deg_to_rad(side * randf_range(25, 50)))
	if not Settings.get_value("ragdoll"):
		slipping = 0.6
		slip_spin *= 0.3
	velocity += transform.basis * Vector3(0, 2.2, -1.5)
	inspecting = false
	Sfx.play("slip", global_position)
	Game.on_local_slip(self)
	# drop everything in a comedic spray
	for uid in held():
		var xf := Transform3D(Basis(Vector3.UP, randf() * TAU), global_position + Vector3(0, 1.0, 0) + transform.basis * Vector3(randf_range(-0.3, 0.3), 0, -0.4))
		Game.request_release(uid, xf, transform.basis * Vector3(randf_range(-1, 1), 2.5, -2.0), Vector3(randf(), randf(), randf()) * 6.0)

func _handle_player_bumps() -> void:
	if _bump_cd > 0.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other and other.has_meta("peer_id"):
			var spd := Vector2(velocity.x, velocity.z).length()
			if spd > 1.5:
				_bump_cd = 0.8
				Game.request_bump(int(other.get_meta("peer_id")), (Vector3(other.global_position.x, 0, other.global_position.z) - Vector3(global_position.x, 0, global_position.z)).normalized() * spd)
				bean.bump(1.2)

func apply_bump(push: Vector3) -> void:
	velocity += push * 0.9 + Vector3(0, 1.5, 0)
	bean.bump(2.0)
	if push.length() > 4.5 and randf() < 0.3:
		start_slip()

# ------------------------------------------------------------------ carts
var _cart_exception := -1

func pushing_cart() -> int:
	var t := top_held()
	if t >= 0 and Game.st.items[t].kind == Defs.K_CART:
		return t
	return -1

func cart_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, look_yaw), global_position + Basis(Vector3.UP, look_yaw) * Vector3(0, 0, -0.95))

func _update_cart_push() -> void:
	var c := pushing_cart()
	if c != _cart_exception:
		if _cart_exception >= 0 and Game.carts.has(_cart_exception):
			remove_collision_exception_with(Game.carts[_cart_exception].body)
		if c >= 0 and Game.carts.has(c):
			add_collision_exception_with(Game.carts[c].body)
		_cart_exception = c
	if c >= 0:
		Game.local_cart_move(c, cart_xf())

# ------------------------------------------------------------------ targeting
func _ray() -> Array:
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	return [from, dir]

func _update_target() -> void:
	target = {"type": ""}
	var r := _ray()
	var from: Vector3 = r[0]
	var dir: Vector3 = r[1]
	var reach := REACH
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Defs.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	var wall_d := reach
	if hit:
		wall_d = from.distance_to(hit.position)
	var top := top_held()
	var hit_item := Game.st.raycast(from, dir, minf(reach, wall_d + 0.08), 0.03, top)
	var item_d: float = hit_item.get("dist", 99.0)
	# shelf bucket / table when holding something placeable
	if top >= 0 and not inspecting:
		var it: LevelState.Item = Game.st.items[top]
		var b := _bucket_under_ray(from, dir, minf(reach + 0.4, wall_d + 0.25))
		if not b.is_empty() and (it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX) and b.dist < item_d + 0.3:
			target = {"type": "bucket", "bid": b.bid, "point": from + dir * b.dist}
			_show_ghost_bucket(top, b.bid)
			return
		var t := _table_under_ray(from, dir, minf(reach, wall_d + 0.1))
		if not t.is_empty() and t.dist < item_d + 0.2:
			var cell := Game.st.nearest_free_cell(t.table, t.local)
			if cell >= 0:
				target = {"type": "table", "table": t.table, "cell": cell}
				_show_ghost_xf(top, Game.st.table_cell_xf(t.table, cell, it), true)
				return
	ghost.visible = false
	if not hit_item.is_empty():
		target = {"type": "item", "uid": hit_item.uid}
		return
	# stash props
	var s := _stash_under_ray(from, dir, minf(reach, wall_d + 0.3))
	if s >= 0:
		target = {"type": "stash", "stash": s}

func _bucket_under_ray(from: Vector3, dir: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	for b in Game.bucket_cache_near(from, 3.5):
		var inv := (b.xf as Transform3D).affine_inverse()
		var lo := inv * from
		var ld := inv.basis * dir
		var box := AABB(Vector3(0, 0, -b.depth), Vector3(b.width, b.height, b.depth + 0.12))
		var t = LevelState._ray_aabb(lo, ld, box)
		if t != null and t < bd:
			bd = t
			best = {"bid": b.id, "dist": t}
	return best

func _table_under_ray(from: Vector3, dir: Vector3, max_d: float) -> Dictionary:
	for t in Game.st.tables:
		var inv := (t.xf as Transform3D).affine_inverse()
		var lo := inv * from
		var ld := inv.basis * dir
		var box := AABB(Vector3(-0.8, t.height - 0.05, -0.4), Vector3(1.6, 0.4, 0.8))
		var hit = LevelState._ray_aabb(lo, ld, box)
		if hit != null and hit < max_d:
			return {"table": t.id, "dist": hit, "local": lo + ld * hit}
	return {}

func _stash_under_ray(from: Vector3, dir: Vector3, max_d: float) -> int:
	for s in Game.st.stashes:
		if s.revealed or (s.items as Array).is_empty():
			continue
		var c: Vector3 = s.pos + Vector3(0, 0.4, 0)
		var to := c - from
		var t := to.dot(dir)
		if t > 0.0 and t < max_d + 0.6 and (from + dir * t).distance_to(c) < 0.6:
			return s.id
	return -1

func _show_ghost_bucket(uid: int, bid: int) -> void:
	var xf := Game.st.preview_xf(bid, uid)
	var fits := Game.st.bucket_has_room(bid, uid)
	_show_ghost_xf(uid, xf, fits, bid)

func _show_ghost_xf(uid: int, xf: Transform3D, fits: bool, bid := -1) -> void:
	var it: LevelState.Item = Game.st.items[uid]
	ghost.mesh = ItemMeshes.mesh(ItemMeshes.render_key(it))
	ghost.global_transform = xf
	ghost.visible = true
	var col := Color(0.45, 0.85, 1.0)
	if not fits:
		col = Color(1.0, 0.35, 0.3)
	elif bid >= 0 and Game.scanner_active():
		col = Color(0.4, 1.0, 0.45) if Game.st.correct_bucket_for(uid) == bid else Color(1.0, 0.55, 0.25)
	(ghost.material_override as ShaderMaterial).set_shader_parameter("color", col)
	ghost_ok = fits

# ------------------------------------------------------------------ actions
func context() -> Dictionary:
	## Labels for the contextual buttons + a description of what is targeted.
	var out := {"grab": "", "interact": "", "name": "", "detail": ""}
	var top := top_held()
	var tt: String = target.get("type", "")
	var st := Game.st
	if top >= 0 and st.items[top].kind == Defs.K_CART:
		out.interact = "Let go"
		out.name = "Cart (%d/30)" % st.items[top].contents.size()
		return out
	if top >= 0:
		var hi: LevelState.Item = st.items[top]
		out.grab = "Drop"
		if tt == "bucket":
			out.grab = "Shelve" if ghost_ok else "Full!"
			out.name = st.buckets[target.bid].label
			out.detail = st.sections[st.buckets[target.bid].section].label
		elif tt == "table":
			out.grab = "Place"
		elif tt == "item":
			var ti: LevelState.Item = st.items[target.uid]
			if hi.open and st.can_insert(target.uid, top):
				out.grab = "Scoop"
			elif ti.kind == Defs.K_CART and st.can_insert(top, target.uid):
				out.grab = "Into cart"
			elif ti.open and st.can_insert(top, target.uid):
				out.grab = "Insert"
			elif _stackable(hi) and _stackable(ti) and held().size() < MAX_STACK:
				out.grab = "Stack"
			out.name = Game.item_title(target.uid)
		if hi.kind == Defs.K_CASE or hi.kind == Defs.K_CEBOX:
			if hi.open and not hi.contents.is_empty() and tt != "item":
				out.interact = "Take out"
			else:
				out.interact = "Close" if hi.open else "Open"
		elif hi.kind == Defs.K_DISC:
			out.interact = "Flip"
	else:
		if tt == "item" and st.items[target.uid].kind == Defs.K_CART:
			out.interact = "Push"
			out.name = "Cart (%d/30)" % st.items[target.uid].contents.size()
		elif tt == "item":
			var ti2: LevelState.Item = st.items[target.uid]
			out.grab = "Grab"
			out.name = Game.item_title(target.uid)
			out.detail = Game.item_detail(target.uid)
			if ti2.kind == Defs.K_DISC and ti2.parent < 0:
				out.interact = "Flip"
			elif ti2.kind == Defs.K_CASE or ti2.kind == Defs.K_CEBOX:
				out.interact = "Close" if ti2.open else "Open"
		elif tt == "stash":
			out.interact = "Search"
			out.name = "Something's hidden here..."
	return out

func _stackable(it: LevelState.Item) -> bool:
	return (it.kind == Defs.K_CASE or it.kind == Defs.K_CEBOX) and not it.open

func _actions(delta: float) -> void:
	var st := Game.st
	var top := top_held()
	if Input.is_action_just_pressed("inspect"):
		if inspecting:
			inspecting = false
		elif top >= 0 and Game.st.items[top].kind != Defs.K_CART:
			inspecting = true
			inspect_rot = Basis(Vector3.UP, PI * 0.1)
		elif target.get("type") == "item":
			Game.request_grab(target.uid)
			_pending_inspect = true
	if _pending_inspect and top >= 0:
		_pending_inspect = false
		inspecting = true
		inspect_rot = Basis(Vector3.UP, PI * 0.1)
	if Input.is_action_just_pressed("grab"):
		_do_grab()
	if Input.is_action_just_pressed("drop") and top >= 0 and Game.st.items[top].kind != Defs.K_CART:
		_drop(top)
	if Input.is_action_just_pressed("interact"):
		_do_interact()
	if Input.is_action_just_pressed("flashlight") and Game.level_def.get("flashlight", false):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
		Sfx.play("click", global_position)
	if Input.is_action_just_pressed("scanner"):
		Game.use_scanner()
	# throw: hold to charge
	if top >= 0 and Input.is_action_just_pressed("throw") and Game.st.items[top].kind != Defs.K_CART:
		throw_charge = 0.0
	if throw_charge >= 0.0:
		throw_charge = minf(throw_charge + delta, 1.0)
		if not Input.is_action_pressed("throw"):
			var power := lerpf(3.0, 8.5, throw_charge)
			throw_charge = -1.0
			if top >= 0:
				var xf := hold_point.global_transform
				var vel := -camera.global_transform.basis.z * power + Vector3(0, 1.2, 0) + velocity * 0.5
				Game.request_release(top, xf, vel, Vector3(randf_range(-4, 4), randf_range(-8, 8), randf_range(-4, 4)))
				Game.on_local_throw()
				Sfx.play("whoosh", global_position, 0.9 + throw_charge * 0.3)
				hands.punch()
				inspecting = false

var _pending_inspect := false

func _do_grab() -> void:
	var st := Game.st
	var top := top_held()
	var tt: String = target.get("type", "")
	if top < 0:
		if tt == "item" and st.items[target.uid].kind != Defs.K_CART:
			Game.request_grab(target.uid)
			hands.punch()
		return
	var hi: LevelState.Item = st.items[top]
	if hi.kind == Defs.K_CART:
		return
	match tt:
		"bucket":
			if ghost_ok:
				Game.request_shelve(top, target.bid, hold_point.global_transform)
				inspecting = false
			else:
				Sfx.play("error", global_position)
				Game.toast("This shelf section is full")
		"table":
			Game.request_table(top, target.table, target.cell, hold_point.global_transform)
			inspecting = false
		"item":
			var uid: int = target.uid
			var ti: LevelState.Item = st.items[uid]
			if hi.open and st.can_insert(uid, top):
				Game.request_insert(uid, top)
			elif (ti.open or ti.kind == Defs.K_CART) and st.can_insert(top, uid):
				Game.request_insert(top, uid)
			elif _stackable(hi) and _stackable(ti) and held().size() < MAX_STACK:
				Game.request_grab(uid)
			else:
				_drop(top)
			hands.punch()
		_:
			_drop(top)

func _drop(uid: int) -> void:
	var xf := hold_point.global_transform
	xf.origin += -camera.global_transform.basis.z * 0.15
	Game.request_release(uid, xf, velocity * 0.6 + Vector3(0, 0.4, 0), Vector3.ZERO)
	inspecting = false

func _do_interact() -> void:
	var st := Game.st
	var top := top_held()
	if top >= 0 and st.items[top].kind == Defs.K_CART:
		Game.request_release(top, cart_xf(), Vector3.ZERO, Vector3.ZERO)
		return
	if top >= 0:
		var hi: LevelState.Item = st.items[top]
		if hi.kind == Defs.K_CASE or hi.kind == Defs.K_CEBOX:
			if hi.open and not hi.contents.is_empty() and target.get("type") != "item":
				var out := hold_point.global_transform
				out.origin += -camera.global_transform.basis.z * 0.25 + Vector3(0, 0.1, 0)
				Game.request_eject(top, out)
			else:
				Game.request_open(top, not hi.open)
		elif hi.kind == Defs.K_DISC:
			inspect_rot = Basis(Vector3.RIGHT, PI) * inspect_rot
			Sfx.play("flip", global_position)
		return
	match target.get("type", ""):
		"item":
			var ti: LevelState.Item = st.items[target.uid]
			if ti.kind == Defs.K_CART:
				Game.request_grab(target.uid)
			elif ti.kind == Defs.K_DISC and ti.parent < 0:
				Game.request_flip(target.uid)
			elif ti.kind == Defs.K_CASE or ti.kind == Defs.K_CEBOX:
				Game.request_open(target.uid, not ti.open)
		"stash":
			Game.request_reveal(target.stash)

# ------------------------------------------------------------------ held visuals
func _update_held_visual(delta: float) -> void:
	var h := held()
	var sig := str(h) + str(h.map(func(u): return Game.st.items[u].open)) + str(h.map(func(u): return Array(Game.st.items[u].contents)))
	if sig != _held_sig:
		_held_sig = sig
		if _held_vis:
			_held_vis.queue_free()
			_held_vis = null
		if not h.is_empty():
			_held_vis = Node3D.new()
			hold_point.add_child(_held_vis)
			var y := 0.0
			var multi := h.size() > 1
			for i in h.size():
				var uid: int = h[i]
				var v := Game.world.make_visual(uid, i == h.size() - 1)
				_held_vis.add_child(v)
				var it: LevelState.Item = Game.st.items[uid]
				var s := Game.st.size_of(it)
				var b := Basis(Vector3.RIGHT, -PI * 0.5 + 0.45) if multi else _hold_basis(it)
				var ext := (b * s).abs()
				y += ext.y * 0.5
				v.transform = Transform3D(b, Vector3(0, y - (0.08 if multi else 0.0), 0))
				y += ext.y * 0.5 + 0.002
				for c in v.get_children():
					if c is GeometryInstance3D:
						(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hands.holding = true
		else:
			hands.holding = false
			inspecting = false
	if _held_vis:
		var target_pos := Vector3(0.0, -0.2, -0.5)
		var target_b := Basis()
		if inspecting:
			target_pos = Vector3(0, -0.02, -0.34)
			target_b = inspect_rot
		hold_point.position = hold_point.position.lerp(target_pos, clampf(delta * 12.0, 0, 1))
		hold_point.basis = hold_point.basis.slerp(target_b, clampf(delta * 12.0, 0, 1))
	hands.inspecting = inspecting

func _hold_basis(it: LevelState.Item) -> Basis:
	# show covers facing the camera; discs label-up tilted towards the view
	match it.kind:
		Defs.K_DISC:
			return Basis(Vector3.RIGHT, PI * 0.42)
		Defs.K_FIGURE:
			return Basis(Vector3.UP, PI)
		Defs.K_POSTER:
			return Basis(Vector3.BACK, PI * 0.5)
	if it.open and LevelState.is_flip_case(it):
		return Basis(Vector3.RIGHT, -0.25) * Basis(Vector3.UP, 0.0)
	return Basis(Vector3.RIGHT, -0.12)
