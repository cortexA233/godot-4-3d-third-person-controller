class_name GrenadeTrajectoryPreview
extends Node3D

const AIM_MATERIAL := preload("res://player/grenade_visuals/aim_material.tres")
const GRENADE_TRAJECTORY_SCRIPT := preload("res://player/grenade_trajectory.gd")
const COLLISION_MASK := 3
const POINT_COUNT := 18
const STEP_TIME := 0.08

var _markers: Array[MeshInstance3D] = []
var _landing_marker: MeshInstance3D
var _excluded_rids: Array[RID] = []


func _ready() -> void:
	top_level = true

	var point_material := StandardMaterial3D.new()
	point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	point_material.albedo_color = Color(0.0, 0.73, 1.0, 0.82)
	point_material.emission_enabled = true
	point_material.emission = Color(0.0, 0.73, 1.0)
	point_material.emission_energy_multiplier = 1.5
	point_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var point_mesh := SphereMesh.new()
	point_mesh.radius = 0.075
	point_mesh.height = 0.15

	for i in range(POINT_COUNT):
		var marker := MeshInstance3D.new()
		marker.mesh = point_mesh
		marker.material_override = point_material
		add_child(marker)
		_markers.append(marker)

	var landing_mesh := CylinderMesh.new()
	landing_mesh.top_radius = 0.65
	landing_mesh.bottom_radius = 0.65
	landing_mesh.height = 0.025
	landing_mesh.radial_segments = 48

	_landing_marker = MeshInstance3D.new()
	_landing_marker.mesh = landing_mesh
	_landing_marker.material_override = AIM_MATERIAL.duplicate()
	add_child(_landing_marker)

	hide()


func set_excluded_body(body: CollisionObject3D) -> void:
	_excluded_rids = [body.get_rid()]


func update_preview(origin: Vector3, velocity: Vector3, gravity: float) -> void:
	show()

	var points := _trace_points(origin, velocity, gravity)
	for i in range(_markers.size()):
		var marker := _markers[i]
		if i < points.size():
			marker.show()
			marker.global_position = points[i]
			marker.scale = Vector3.ONE * lerp(1.15, 0.65, float(i) / float(_markers.size()))
		else:
			marker.hide()

	if points.is_empty():
		_landing_marker.hide()
		return

	_landing_marker.show()
	_landing_marker.global_position = points[points.size() - 1] + Vector3.UP * 0.03


func _trace_points(origin: Vector3, velocity: Vector3, gravity: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var previous := origin
	points.append(previous)

	var space_state := get_world_3d().direct_space_state
	for i in range(1, POINT_COUNT):
		var time := float(i) * STEP_TIME
		var current := GRENADE_TRAJECTORY_SCRIPT.position_at_time(origin, velocity, gravity, time)
		var query := PhysicsRayQueryParameters3D.create(previous, current, COLLISION_MASK, _excluded_rids)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			points.append(result["position"])
			return points

		points.append(current)
		previous = current

	return points
