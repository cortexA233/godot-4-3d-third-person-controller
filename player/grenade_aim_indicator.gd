extends Node3D

const SAMPLE_COUNT := 16
const RIBBON_HEIGHT := 0.6
const LANDING_MARKER_SIZE := 2.4

@onready var _trajectory: MeshInstance3D = $TrajectoryPreview
@onready var _landing_marker: MeshInstance3D = $LandingMarker


func _ready() -> void:
	var landing_mesh := QuadMesh.new()
	landing_mesh.size = Vector2(LANDING_MARKER_SIZE, LANDING_MARKER_SIZE)
	_landing_marker.mesh = landing_mesh
	hide_aim()


func show_aim() -> void:
	_trajectory.visible = true
	_landing_marker.visible = true


func hide_aim() -> void:
	_trajectory.visible = false
	_landing_marker.visible = false


## Rebuilds the ribbon/marker to match the exact parabola thrown with `velocity`
## from `origin`, under downward acceleration `gravity`, over `flight_time` seconds.
func update_aim(origin: Vector3, velocity: Vector3, gravity: float, flight_time: float) -> void:
	var points := PackedVector3Array()
	for i in range(SAMPLE_COUNT + 1):
		var t := flight_time * float(i) / float(SAMPLE_COUNT)
		points.append(origin + velocity * t + Vector3.DOWN * (0.5 * gravity * t * t))

	_trajectory.mesh = _build_ribbon_mesh(points)
	_trajectory.global_transform = Transform3D.IDENTITY

	var landing_point := points[points.size() - 1]
	_landing_marker.global_transform = Transform3D(
		Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)),
		landing_point + Vector3.UP * 0.05,
	)


func _build_ribbon_mesh(points: PackedVector3Array) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var u := float(i) / float(points.size() - 1)
		surface_tool.set_uv(Vector2(u, 0.0))
		surface_tool.add_vertex(points[i])
		surface_tool.set_uv(Vector2(u, 1.0))
		surface_tool.add_vertex(points[i] + Vector3.UP * RIBBON_HEIGHT)
	return surface_tool.commit()
