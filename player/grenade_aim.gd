## Grenade aiming aid: a dotted arc plus a landing target marker.
##
## The player updates this every frame while grenade mode is active (whether or
## not the aim button is held). The arc is simulated with the same ballistic
## model the thrown grenade uses, and a ray is cast along it to find the predicted
## impact point, where the animated target reticle (existing project material) is
## placed. Colour dims while the throw is on cooldown so the player keeps a stable
## aiming reference without the aid ever being hidden mid-cooldown.
class_name GrenadeAim
extends Node3D

const AIM_MATERIAL := preload("res://player/grenade_visuals/aim_material.tres")

const DOT_COUNT := 24
const READY_COLOR := Color(0.0, 0.72, 1.0)
const COOLDOWN_COLOR := Color(0.55, 0.65, 0.72)
const SIM_STEP := 0.045
const SIM_MAX_STEPS := 90

var _dots: Array[MeshInstance3D] = []
var _dot_material: StandardMaterial3D
var _marker: MeshInstance3D
var _marker_material: ShaderMaterial


func _ready() -> void:
	# World-space: we drive dot/marker global transforms directly regardless of
	# where this node is parented.
	top_level = true

	_dot_material = StandardMaterial3D.new()
	_dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_material.albedo_color = READY_COLOR
	_dot_material.emission_enabled = true
	_dot_material.emission = READY_COLOR
	_dot_material.emission_energy_multiplier = 2.0
	_dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.09
	dot_mesh.height = 0.18
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	dot_mesh.material = _dot_material

	for i in DOT_COUNT:
		var dot := MeshInstance3D.new()
		dot.mesh = dot_mesh
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		add_child(dot)
		_dots.append(dot)

	_marker = MeshInstance3D.new()
	var marker_mesh := PlaneMesh.new()
	marker_mesh.size = Vector2(2.4, 2.4)
	marker_mesh.orientation = PlaneMesh.FACE_Y
	_marker.mesh = marker_mesh
	_marker_material = AIM_MATERIAL.duplicate()
	_marker.material_override = _marker_material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)

	hide()


## Recompute and redraw the preview for the given ballistic launch.
func update_preview(origin: Vector3, launch_velocity: Vector3, gravity: float, exclude_rid: RID, is_ready: bool) -> void:
	if not visible:
		return

	var points: Array[Vector3] = []
	var landing := origin
	var landing_normal := Vector3.UP
	var found_landing := false

	var space_state := get_world_3d().direct_space_state
	var previous := origin
	var vel := launch_velocity

	for i in SIM_MAX_STEPS:
		var next := previous + vel * SIM_STEP
		vel.y -= gravity * SIM_STEP

		var ray := PhysicsRayQueryParameters3D.create(previous, next)
		ray.collision_mask = 0xFF
		ray.collide_with_areas = false
		ray.exclude = [exclude_rid]
		var hit := space_state.intersect_ray(ray)
		if hit:
			landing = hit.position
			landing_normal = hit.normal
			points.append(hit.position)
			found_landing = true
			break

		points.append(next)
		previous = next

		if next.y < origin.y - 40.0:
			landing = next
			break

	_draw_dots(points)
	_draw_marker(found_landing, landing, landing_normal)
	_apply_ready_state(is_ready)


func _draw_dots(points: Array[Vector3]) -> void:
	var count := points.size()
	var shown: int = min(_dots.size(), count)
	for i in _dots.size():
		if i >= shown:
			_dots[i].visible = false
			continue
		var t := 0.0
		if shown > 1:
			t = float(i) / float(shown - 1)
		var index: int = clampi(int(round(t * (count - 1))), 0, count - 1)
		_dots[i].visible = true
		_dots[i].global_position = points[index]


func _draw_marker(found: bool, position: Vector3, normal: Vector3) -> void:
	if not found:
		_marker.visible = false
		return

	var up := normal.normalized()
	if up.length() < 0.5:
		up = Vector3.UP

	# Build an orthonormal basis whose local +Y follows the surface normal so the
	# flat reticle lies against the ground/slope it will detonate on.
	var reference := Vector3.FORWARD
	if absf(up.dot(reference)) > 0.9:
		reference = Vector3.RIGHT
	var tangent := up.cross(reference).normalized()
	var bitangent := tangent.cross(up).normalized()

	_marker.visible = true
	_marker.global_transform = Transform3D(Basis(tangent, up, bitangent), position + up * 0.03)


func _apply_ready_state(is_ready: bool) -> void:
	var color := READY_COLOR if is_ready else COOLDOWN_COLOR
	_dot_material.albedo_color = color
	_dot_material.emission = color
	_dot_material.emission_energy_multiplier = 2.0 if is_ready else 0.9
	_marker_material.set_shader_parameter("fill_color", color)
