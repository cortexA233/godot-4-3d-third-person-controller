class_name GrenadeAim
extends Node3D

## Grenade aiming aid. Draws an arcing trajectory ribbon and a landing marker that
## predict where a thrown grenade will come down, using the same gravity the
## projectile uses. Visible whenever grenade mode is active (aiming or not, ready or
## on cooldown); hidden when the player switches back to the default weapon.

const TRAJECTORY_MATERIAL := preload("res://player/grenade_visuals/trajectory_material.tres")
const TARGET_MATERIAL := preload("res://player/grenade_visuals/aim_material.tres")

const RIBBON_WIDTH := 0.14
const SAMPLE_STEP := 0.035
const MAX_SAMPLES := 128
const READY_COLOR := Color(0.0, 0.725, 1.0)
const COOLDOWN_COLOR := Color(1.0, 0.55, 0.12)

var _ribbon: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _trajectory_material: ShaderMaterial
var _marker: MeshInstance3D
var _target_material: ShaderMaterial

var _impact_point := Vector3.ZERO
var _impact_normal := Vector3.UP


func _ready() -> void:
	# Live in world space so we can feed absolute positions straight into the mesh.
	top_level = true
	global_transform = Transform3D.IDENTITY

	_ribbon_mesh = ImmediateMesh.new()
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = _ribbon_mesh
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Duplicate the shared materials so per-state colour tweaks never touch the asset.
	_trajectory_material = TRAJECTORY_MATERIAL.duplicate()
	_ribbon.material_override = _trajectory_material
	add_child(_ribbon)

	_marker = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4, 2.4)
	_marker.mesh = plane
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_material = TARGET_MATERIAL.duplicate()
	_marker.material_override = _target_material
	add_child(_marker)

	set_ready(true)
	hide_preview()


## Recompute and show the arc and landing marker for the given launch state.
func update_preview(origin: Vector3, velocity: Vector3, arc_gravity: float, exclude: RID, space: PhysicsDirectSpaceState3D, cam: Camera3D) -> void:
	visible = true
	var points := _compute_arc(origin, velocity, arc_gravity, exclude, space)
	_build_ribbon(points, cam)

	if points.size() >= 1:
		_marker.visible = true
		_marker.global_position = _impact_point + _impact_normal * 0.06
		_orient_marker_to(_impact_normal)
	else:
		_marker.visible = false


## Hide the aid entirely (default weapon selected).
func hide_preview() -> void:
	visible = false
	if _ribbon_mesh:
		_ribbon_mesh.clear_surfaces()


## Colour cue for whether the next grenade is ready or still cooling down.
func set_ready(is_ready: bool) -> void:
	var color := READY_COLOR if is_ready else COOLDOWN_COLOR
	_trajectory_material.set_shader_parameter("fill_color", color)
	_target_material.set_shader_parameter("fill_color", color)


func _compute_arc(origin: Vector3, velocity: Vector3, arc_gravity: float, exclude: RID, space: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var acceleration := Vector3(0.0, -arc_gravity, 0.0)
	var previous := origin
	points.append(previous)
	_impact_point = origin
	_impact_normal = Vector3.UP

	var t := SAMPLE_STEP
	while t < 3.0 and points.size() < MAX_SAMPLES:
		var current := origin + velocity * t + 0.5 * acceleration * t * t
		var query := PhysicsRayQueryParameters3D.create(previous, current)
		query.collision_mask = 1
		query.exclude = [exclude]
		var hit := space.intersect_ray(query)
		if hit:
			points.append(hit.position)
			_impact_point = hit.position
			_impact_normal = hit.normal
			return points
		points.append(current)
		previous = current
		t += SAMPLE_STEP

	# Never hit anything within range; land the marker at the last sampled point.
	if points.size() > 0:
		_impact_point = points[points.size() - 1]
		_impact_normal = Vector3.UP
	return points


func _build_ribbon(points: PackedVector3Array, cam: Camera3D) -> void:
	_ribbon_mesh.clear_surfaces()
	if points.size() < 2 or cam == null:
		return

	var lengths := PackedFloat32Array()
	lengths.append(0.0)
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
		lengths.append(total)
	if total <= 0.001:
		return

	var cam_position := cam.global_position
	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var point := points[i]
		var tangent := (points[i + 1] - point) if i < points.size() - 1 else (point - points[i - 1])
		tangent = tangent.normalized()
		var to_cam := (cam_position - point).normalized()
		var side := tangent.cross(to_cam)
		if side.length() < 0.001:
			side = tangent.cross(Vector3.UP)
		side = side.normalized() * RIBBON_WIDTH

		var u := lengths[i] / total
		_ribbon_mesh.surface_set_uv(Vector2(u, 0.0))
		_ribbon_mesh.surface_add_vertex(point - side)
		_ribbon_mesh.surface_set_uv(Vector2(u, 1.0))
		_ribbon_mesh.surface_add_vertex(point + side)
	_ribbon_mesh.surface_end()


func _orient_marker_to(normal: Vector3) -> void:
	var up := normal.normalized()
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var basis_x := reference.cross(up).normalized()
	var basis_z := up.cross(basis_x).normalized()
	_marker.global_transform.basis = Basis(basis_x, up, basis_z)
