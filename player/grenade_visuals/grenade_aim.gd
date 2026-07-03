extends Node3D

const RIBBON_WIDTH := 0.3
const MARKER_SIZE := 1.4

@onready var _trajectory_mesh: MeshInstance3D = $TrajectoryMesh
@onready var _landing_marker: MeshInstance3D = $LandingMarker

var _trajectory_material: ShaderMaterial
var _target_material: ShaderMaterial


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY

	_trajectory_material = _trajectory_mesh.material_override.duplicate()
	_trajectory_mesh.material_override = _trajectory_material

	_target_material = _landing_marker.material_override.duplicate()
	_landing_marker.material_override = _target_material

	hide()


## points: world-space arc samples from throw origin to (predicted) landing point.
## on_cooldown: dims the aid while the next throw isn't ready yet, without hiding it.
func update_aim(points: PackedVector3Array, landing_point: Vector3, on_cooldown: bool) -> void:
	show()
	_build_trajectory_mesh(points)

	_landing_marker.global_transform = Transform3D(Basis(), landing_point + Vector3.UP * 0.03)
	_landing_marker.scale = Vector3.ONE * MARKER_SIZE

	var alpha := 0.35 if on_cooldown else 1.0
	_trajectory_material.set_shader_parameter("fill_color", Color(0, 0.725568, 1, 1) * alpha)
	_target_material.set_shader_parameter("fill_color", Color(0, 0.72549, 1, 1) * alpha)


func _build_trajectory_mesh(points: PackedVector3Array) -> void:
	if points.size() < 2:
		_trajectory_mesh.mesh = null
		return

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var point_count := points.size()
	for i in point_count:
		var t := float(i) / float(point_count - 1)
		var side := Vector3.RIGHT
		var segment_direction := Vector3.ZERO
		if i < point_count - 1:
			segment_direction = points[i + 1] - points[i]
		elif i > 0:
			segment_direction = points[i] - points[i - 1]
		segment_direction.y = 0.0
		if segment_direction.length() > 0.001:
			side = segment_direction.normalized().cross(Vector3.UP)

		var offset := side * RIBBON_WIDTH * 0.5
		surface_tool.set_uv(Vector2(t, 0.0))
		surface_tool.add_vertex(points[i] - offset)
		surface_tool.set_uv(Vector2(t, 1.0))
		surface_tool.add_vertex(points[i] + offset)

	_trajectory_mesh.mesh = surface_tool.commit()
