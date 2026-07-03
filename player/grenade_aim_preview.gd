class_name GrenadeAimPreview
extends Node3D

const POINT_COUNT := 14
const READY_COLOR := Color(0.0, 0.725, 1.0, 0.82)
const COOLDOWN_COLOR := Color(1.0, 0.58, 0.1, 0.7)

var _arc_points: Array[MeshInstance3D] = []
var _landing_marker: MeshInstance3D
var _point_mesh := SphereMesh.new()
var _landing_mesh := CylinderMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	_point_mesh.radius = 0.07
	_point_mesh.height = 0.14
	_landing_mesh.top_radius = 0.75
	_landing_mesh.bottom_radius = 0.75
	_landing_mesh.height = 0.025
	_landing_mesh.radial_segments = 48

	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = READY_COLOR
	_material.emission_enabled = true
	_material.emission = READY_COLOR

	for index in range(POINT_COUNT):
		var point := MeshInstance3D.new()
		point.mesh = _point_mesh
		point.material_override = _material
		add_child(point)
		_arc_points.append(point)

	_landing_marker = MeshInstance3D.new()
	_landing_marker.mesh = _landing_mesh
	_landing_marker.material_override = _material
	add_child(_landing_marker)
	visible = false


func update_preview(points: PackedVector3Array, can_throw: bool) -> void:
	visible = points.size() >= 2
	if not visible:
		return

	var color := READY_COLOR if can_throw else COOLDOWN_COLOR
	_material.albedo_color = color
	_material.emission = Color(color.r, color.g, color.b)

	for index in range(_arc_points.size()):
		var point := _arc_points[index]
		if index < points.size():
			point.visible = true
			point.global_position = points[index]
			point.scale = Vector3.ONE * lerp(0.65, 1.25, float(index) / float(max(points.size() - 1, 1)))
		else:
			point.visible = false

	var landing_position := points[points.size() - 1]
	_landing_marker.visible = true
	_landing_marker.global_position = landing_position + Vector3.UP * 0.03
