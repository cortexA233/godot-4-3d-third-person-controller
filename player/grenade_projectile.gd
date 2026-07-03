extends RigidBody3D

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")

@export var fuse_time := 1.4
@export var impact_fuse_time := 0.25
@export var explosion_radius := 3.5
@export var explosion_force := 10.0

var shooter: Node3D = null

var _detonated := false
var _impact_fuse_started := false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	if is_instance_valid(shooter) and shooter is PhysicsBody3D:
		add_collision_exception_with(shooter)

	await get_tree().create_timer(fuse_time).timeout
	_detonate()


func _on_body_entered(body: Node) -> void:
	if body == shooter or _impact_fuse_started:
		return

	_impact_fuse_started = true
	_start_impact_fuse()


func _start_impact_fuse() -> void:
	await get_tree().create_timer(impact_fuse_time).timeout
	_detonate()


func _detonate() -> void:
	if _detonated:
		return

	_detonated = true
	var detonation_position := global_position
	_apply_spatial_damage(detonation_position)
	_spawn_explosion(detonation_position)
	queue_free()


func _apply_spatial_damage(origin: Vector3) -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if body == shooter or body == self or not is_instance_valid(body):
			continue
		if not body is Node3D or not body.has_method("damage"):
			continue

		var body_3d := body as Node3D
		var distance := origin.distance_to(body_3d.global_position)
		if distance > explosion_radius:
			continue

		var direction := body_3d.global_position - origin
		if direction.length_squared() < 0.001:
			direction = Vector3.UP
		else:
			direction = direction.normalized()

		var falloff: float = clamp(1.0 - distance / explosion_radius, 0.0, 1.0)
		var force := (direction + Vector3.UP * 0.35).normalized() * explosion_force * max(falloff, 0.35)
		var impact_point := origin - body_3d.global_position
		body.damage(impact_point, force)


func _spawn_explosion(origin: Vector3) -> void:
	var explosion := EXPLOSION_SCENE.instantiate()
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(explosion)
	explosion.global_position = origin
