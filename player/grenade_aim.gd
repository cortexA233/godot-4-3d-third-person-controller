class_name GrenadeAim
extends Node3D

## Grenade aiming aid. Draws an arcing trajectory ribbon and a landing marker so the
## player can see where a thrown grenade will travel and land, before throwing and
## during cooldown. Built entirely in code (no extra scene file); geometry is placed
## in world space via top-level child nodes.

const TRAJECTORY_MATERIAL := preload("res://player/grenade_visuals/trajectory_material.tres")
const MARKER_MATERIAL := preload("res://player/grenade_visuals/aim_material.tres")

## Half-width of the trajectory ribbon.
@export var ribbon_width := 0.16
## Size of the square landing marker.
@export var marker_size := 1.7
## Maximum number of simulation steps for the predicted arc.
@export var max_steps := 48
## Simulated time between arc samples.
@export var step_time := 0.05
## Ribbon/marker color when a grenade is ready to throw.
@export var ready_color := Color(0.0, 0.725, 1.0)
## Ribbon/marker color while the grenade is on cooldown.
@export var cooldown_color := Color(1.0, 0.55, 0.15)

var _ribbon: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _ribbon_material: ShaderMaterial
var _marker: MeshInstance3D
var _marker_material: ShaderMaterial


func _ready() -> void:
	_ribbon_material = TRAJECTORY_MATERIAL.duplicate() as ShaderMaterial
	_ribbon_mesh = ImmediateMesh.new()
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = _ribbon_mesh
	_ribbon.top_level = true
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon)

	_marker_material = MARKER_MATERIAL.duplicate() as ShaderMaterial
	var quad := QuadMesh.new()
	quad.size = Vector2(marker_size, marker_size)
	_marker = MeshInstance3D.new()
	_marker.mesh = quad
	_marker.material_override = _marker_material
	_marker.top_level = true
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)

	set_active(false)


## Show or hide the whole aiming aid.
func set_active(active: bool) -> void:
	visible = active
	if _ribbon:
		_ribbon.visible = active
	if _marker:
		_marker.visible = active


## Recompute and redraw the predicted arc and landing marker.
## `exclude` is an array of RIDs to ignore during the trajectory raycasts (the player).
## `ready_ratio` is 0..1 where 1 means a grenade is ready to throw.
func update_preview(spawn: Vector3, velocity: Vector3, gravity: float, exclude: Array, ready_ratio: float) -> void:
	var result := _simulate(spawn, velocity, gravity, exclude)
	_rebuild_ribbon(result.points)
	_place_marker(result.impact_point, result.impact_normal)

	var color := ready_color if ready_ratio >= 1.0 else cooldown_color
	_ribbon_material.set_shader_parameter("fill_color", color)
	_marker_material.set_shader_parameter("fill_color", color)


func _simulate(spawn: Vector3, velocity: Vector3, gravity: float, exclude: Array) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var points := PackedVector3Array()
	points.append(spawn)

	var sample := spawn
	var current_velocity := velocity
	var impact_point := spawn
	var impact_normal := Vector3.UP

	for i in range(max_steps):
		var previous := sample
		current_velocity += Vector3.DOWN * gravity * step_time
		sample = previous + current_velocity * step_time

		var query := PhysicsRayQueryParameters3D.create(previous, sample)
		query.exclude = exclude
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit:
			impact_point = hit.position
			impact_normal = hit.normal
			points.append(hit.position)
			return {"points": points, "impact_point": impact_point, "impact_normal": impact_normal}

		points.append(sample)
		impact_point = sample

	return {"points": points, "impact_point": impact_point, "impact_normal": impact_normal}


func _rebuild_ribbon(points: PackedVector3Array) -> void:
	_ribbon_mesh.clear_surfaces()
	var count := points.size()
	if count < 2:
		return

	var camera := get_viewport().get_camera_3d()
	var camera_position := camera.global_position if camera else points[0] + Vector3.UP * 10.0

	var lefts := PackedVector3Array()
	var rights := PackedVector3Array()
	lefts.resize(count)
	rights.resize(count)

	for i in range(count):
		var tangent: Vector3
		if i == 0:
			tangent = points[1] - points[0]
		elif i == count - 1:
			tangent = points[count - 1] - points[count - 2]
		else:
			tangent = points[i + 1] - points[i - 1]
		if tangent.length() < 0.0001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()

		var to_camera := camera_position - points[i]
		if to_camera.length() < 0.0001:
			to_camera = Vector3.UP
		to_camera = to_camera.normalized()

		var side := tangent.cross(to_camera)
		if side.length() < 0.0001:
			side = tangent.cross(Vector3.UP)
		if side.length() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized() * ribbon_width

		lefts[i] = points[i] - side
		rights[i] = points[i] + side

	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ribbon_material)
	for i in range(count - 1):
		var u0 := float(i) / float(count - 1)
		var u1 := float(i + 1) / float(count - 1)

		_add_vertex(lefts[i], Vector2(u0, 0.0))
		_add_vertex(rights[i], Vector2(u0, 1.0))
		_add_vertex(lefts[i + 1], Vector2(u1, 0.0))

		_add_vertex(rights[i], Vector2(u0, 1.0))
		_add_vertex(rights[i + 1], Vector2(u1, 1.0))
		_add_vertex(lefts[i + 1], Vector2(u1, 0.0))
	_ribbon_mesh.surface_end()


func _add_vertex(vertex_position: Vector3, uv: Vector2) -> void:
	_ribbon_mesh.surface_set_uv(uv)
	_ribbon_mesh.surface_add_vertex(vertex_position)


func _place_marker(point: Vector3, normal: Vector3) -> void:
	var up := normal.normalized()
	if up.length() < 0.001:
		up = Vector3.UP
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var axis_x := reference.cross(up).normalized()
	var axis_y := up.cross(axis_x).normalized()
	# QuadMesh sits in its local XY plane with its normal along +Z, so map local +Z
	# onto the surface normal to lay the marker flat on the ground.
	var marker_basis := Basis(axis_x, axis_y, up)
	_marker.global_transform = Transform3D(marker_basis, point + up * 0.05)
