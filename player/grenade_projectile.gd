extends RigidBody3D

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")
const EXPLOSION_SOUND := preload("res://player/sounds/musket-explosion-6383.wav")

@export var fuse_time := 1.45
@export var impact_detonation_delay := 0.25
@export var arm_time := 0.12
@export var explosion_radius := 3.5
@export var explosion_force := 12.0

var shooter: Node = null
var initial_velocity := Vector3.ZERO

var _time_alive := 0.0
var _detonated := false
var _impact_detonation_started := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if shooter is CollisionObject3D:
		add_collision_exception_with(shooter)
	linear_velocity = initial_velocity
	angular_velocity = Vector3(8.0, 4.0, 6.0)

	await get_tree().create_timer(fuse_time).timeout
	detonate()


func _physics_process(delta: float) -> void:
	_time_alive += delta


func throw(origin: Vector3, velocity: Vector3, source: Node) -> void:
	shooter = source
	initial_velocity = velocity
	global_position = origin
	if is_inside_tree():
		linear_velocity = velocity
		if shooter is CollisionObject3D:
			add_collision_exception_with(shooter)


func detonate() -> void:
	if _detonated:
		return

	_detonated = true
	_apply_explosion_damage()
	_spawn_explosion_feedback()
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter or _detonated or _impact_detonation_started or _time_alive < arm_time:
		return

	_impact_detonation_started = true
	await get_tree().create_timer(impact_detonation_delay).timeout
	detonate()


func _apply_explosion_damage() -> void:
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]

	var damaged := {}
	var results := get_world_3d().direct_space_state.intersect_shape(query, 32)
	for result in results:
		var body := result["collider"] as Node3D
		if body == null:
			continue
		if body == shooter or body is Player:
			continue
		if not body.is_in_group("damageables") or not body.has_method("damage"):
			continue
		if damaged.has(body):
			continue

		var offset := body.global_position - global_position
		var distance := max(offset.length(), 0.2)
		var direction := offset / distance
		var falloff := clamp(1.0 - distance / explosion_radius, 0.25, 1.0)
		var force := (direction + Vector3.UP * 0.35).normalized() * explosion_force * falloff
		var impact_point := global_position - body.global_position
		body.damage(impact_point, force)
		damaged[body] = true


func _spawn_explosion_feedback() -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var explosion := EXPLOSION_SCENE.instantiate()
	parent.add_child(explosion)
	explosion.global_position = global_position

	var explosion_sound := AudioStreamPlayer3D.new()
	explosion_sound.stream = EXPLOSION_SOUND
	explosion_sound.volume_db = 4.0
	parent.add_child(explosion_sound)
	explosion_sound.global_position = global_position
	explosion_sound.finished.connect(explosion_sound.queue_free)
	explosion_sound.play()
