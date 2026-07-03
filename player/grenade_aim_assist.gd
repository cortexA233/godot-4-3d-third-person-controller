class_name GrenadeAimAssist
extends Node3D

@export var point_count := 28
@export var time_step := 0.055
@export_flags_3d_physics var collision_mask := 3

@onready var _trajectory_line: MeshInstance3D = $TrajectoryLine
@onready var _landing_marker: MeshInstance3D = $LandingMarker
@onready var _trajectory_dots: Node3D = $TrajectoryDots

var _line_mesh := ImmediateMesh.new()
var _dots: Array[MeshInstance3D] = []


func _ready() -> void:
	top_level = true
	_trajectory_line.mesh = _line_mesh
	_create_dots()
	hide()


func update_preview(origin: Vector3, initial_velocity: Vector3, gravity: float, exclude: Array = []) -> Vector3:
	global_position = origin
	var points := _sample_arc(origin, initial_velocity, gravity, exclude)
	_draw_arc(origin, points)

	var landing_position := points[points.size() - 1]
	_landing_marker.position = landing_position - origin + Vector3.UP * 0.04
	_landing_marker.show()
	return landing_position


func _create_dots() -> void:
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.08
	dot_mesh.height = 0.16

	for index in range(point_count):
		var dot := MeshInstance3D.new()
		dot.name = "TrajectoryDot%d" % index
		dot.mesh = dot_mesh
		dot.material_override = _trajectory_line.material_override
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trajectory_dots.add_child(dot)
		_dots.append(dot)


func _sample_arc(origin: Vector3, initial_velocity: Vector3, gravity: float, exclude: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	points.append(origin)

	var position := origin
	var velocity := initial_velocity
	for _index in range(point_count):
		var next_position := position + velocity * time_step
		var hit := _raycast_segment(position, next_position, exclude)
		if not hit.is_empty():
			points.append(hit["position"])
			break

		points.append(next_position)
		position = next_position
		velocity.y -= gravity * time_step

	return points


func _raycast_segment(from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	query.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_ray(query)


func _draw_arc(origin: Vector3, points: PackedVector3Array) -> void:
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		_line_mesh.surface_add_vertex(point - origin)
	_line_mesh.surface_end()

	for index in range(_dots.size()):
		var is_used := index < points.size()
		_dots[index].visible = is_used
		if is_used:
			_dots[index].position = points[index] - origin
