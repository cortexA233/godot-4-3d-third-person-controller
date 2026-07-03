extends Node3D
## Shows a dotted arc and a landing marker predicting where a thrown grenade will land.
## Fed every frame by the player while grenade mode is selected, using the exact same
## ballistic formula used to actually throw the grenade so the preview never lies.

const SAMPLE_STEP := 0.08
const MAX_SAMPLE_TIME := 3.0
const READY_COLOR := Color(0.0, 0.83, 1.0)
const NOT_READY_ALPHA := 0.35

@onready var _dots := MultiMeshInstance3D.new()
@onready var _landing_marker := MeshInstance3D.new()

var _multimesh: MultiMesh
var _dot_material: StandardMaterial3D
var _landing_material: ShaderMaterial


func _ready() -> void:
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.09
	dot_mesh.height = 0.18
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4

	_dot_material = StandardMaterial3D.new()
	_dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_material.albedo_color = READY_COLOR
	_dot_material.emission_enabled = true
	_dot_material.emission = READY_COLOR
	_dot_material.emission_energy_multiplier = 3.0

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = dot_mesh
	_multimesh.instance_count = 0

	_dots.multimesh = _multimesh
	_dots.material_override = _dot_material
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dots)

	var marker_mesh := QuadMesh.new()
	marker_mesh.size = Vector2(1.6, 1.6)
	_landing_marker.mesh = marker_mesh
	_landing_marker.rotation_degrees.x = -90.0
	_landing_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_landing_material = ShaderMaterial.new()
	_landing_material.shader = preload("res://player/grenade_visuals/shaders/grenade_target_shader.gdshader")
	_landing_material.set_shader_parameter("target_mask_sampler", preload("res://player/grenade_visuals/textures/target_mask.png"))
	_landing_material.set_shader_parameter("target_frame_mask_sampler", preload("res://player/grenade_visuals/textures/target_frame_mask.png"))
	_landing_material.set_shader_parameter("fill_color", Vector3(READY_COLOR.r, READY_COLOR.g, READY_COLOR.b))
	_landing_marker.material_override = _landing_material
	add_child(_landing_marker)

	visible = false


func show_preview() -> void:
	visible = true


func hide_preview() -> void:
	visible = false


## Dims the preview (without removing it) while the grenade is on cooldown.
func set_ready_state(is_ready: bool) -> void:
	var alpha := 1.0 if is_ready else NOT_READY_ALPHA
	_dot_material.albedo_color = Color(READY_COLOR.r, READY_COLOR.g, READY_COLOR.b, alpha)
	var tint := 1.0 if is_ready else 0.45
	_landing_material.set_shader_parameter("fill_color", Vector3(READY_COLOR.r, READY_COLOR.g, READY_COLOR.b) * tint)


## Simulates the same ballistic arc the thrown grenade will follow, raycasting against the
## world so the arc stops (and the landing marker appears) at the first surface it would hit.
func update_preview(from: Vector3, launch_velocity: Vector3, gravity: float, space_state: PhysicsDirectSpaceState3D, exclude_rid: RID) -> void:
	if not visible:
		return

	var gravity_vector := Vector3(0.0, -gravity, 0.0)
	var query := PhysicsRayQueryParameters3D.new()
	query.exclude = [exclude_rid]

	var points := PackedVector3Array()
	var previous_position := from
	var landing_position := from
	var t := 0.0

	while t < MAX_SAMPLE_TIME:
		t += SAMPLE_STEP
		var sample_position := from + launch_velocity * t + 0.5 * gravity_vector * t * t

		query.from = previous_position
		query.to = sample_position
		var result := space_state.intersect_ray(query)
		if result:
			landing_position = result.position
			break

		points.append(sample_position)
		previous_position = sample_position
		landing_position = sample_position

	_multimesh.instance_count = points.size()
	for i in points.size():
		_multimesh.set_instance_transform(i, Transform3D(Basis(), points[i]))

	_landing_marker.global_position = landing_position + Vector3.UP * 0.03
