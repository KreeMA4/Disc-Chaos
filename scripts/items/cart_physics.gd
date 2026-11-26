class_name CartPhysics
extends RefCounted
## Collision helpers for the push cart (M1 / audit A5).
## The cart is a kinematic body whose pose follows the pusher; before this it was placed 0.95 m in
## front of the player with no collision test, so carts went through walls. These helpers test the
## cart's footprint against the world layer and find the nearest pose that does not overlap it.

## Footprint used for the test: slightly inside the 0.68 x 1.0 x 1.0 collider so a cart sliding
## along a wall (or standing on the floor) is not reported as touching it.
const SIZE := Vector3(0.64, 0.9, 0.96)
const CENTER := Vector3(0.0, 0.55, 0.0)
## Distance in front of the pusher the cart is held at.
const AHEAD := 0.95

static var _shape: BoxShape3D

static func _box() -> BoxShape3D:
	if _shape == null:
		_shape = BoxShape3D.new()
		_shape.size = SIZE
	return _shape

## True when the cart footprint at `xf` overlaps world geometry.
static func blocked(space: PhysicsDirectSpaceState3D, xf: Transform3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _box()
	q.transform = xf * Transform3D(Basis(), CENTER)
	q.collision_mask = Defs.LAYER_WORLD
	q.collide_with_bodies = true
	q.collide_with_areas = false
	q.margin = 0.0
	return not space.intersect_shape(q, 1).is_empty()

## Pose of the cart for a pusher at `pos` looking along `yaw` (the old formula).
static func pose_for(pos: Vector3, yaw: float) -> Transform3D:
	var b := Basis(Vector3.UP, yaw)
	return Transform3D(b, pos + b * Vector3(0, 0, -AHEAD))

## Moves the cart from `current` towards `desired` without entering the world: the desired pose if
## it is free, otherwise the first free pose among axis-wise slides (keeping the desired yaw, then
## the current yaw), otherwise `current` unchanged.
static func resolve(space: PhysicsDirectSpaceState3D, current: Transform3D, desired: Transform3D) -> Transform3D:
	if not blocked(space, desired):
		return desired
	var cands: Array = []
	for basis in [desired.basis, current.basis]:
		var o := desired.origin
		cands.append(Transform3D(basis, Vector3(o.x, o.y, current.origin.z)))
		cands.append(Transform3D(basis, Vector3(current.origin.x, o.y, o.z)))
	cands.append(Transform3D(current.basis, desired.origin))
	for c in cands:
		if not blocked(space, c):
			return c
	return current

## A cart pose with only the yaw of `xf`, standing on the floor (y = 0). Used whenever a cart is
## put down so it can never be left tilted or in the air.
static func grounded(xf: Transform3D) -> Transform3D:
	var z := xf.basis.z
	var yaw := atan2(z.x, z.z)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(xf.origin.x, 0.0, xf.origin.z))
