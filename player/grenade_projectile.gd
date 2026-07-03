class_name GrenadeProjectile
extends RigidBody3D

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")

@export var fuse_time := 1.45
@export var impact_detonation_delay := 0.35
@export var explosion_radius := 3.6
@export var explosion_force := 12.0
@export var cleanup_delay := 1.6

var shooter: Node = null

@onready var _fuse_timer: Timer = $FuseTimer
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _explosion_sound: AudioStreamPlayer3D = $ExplosionSound

var _has_detonated := false
var _time_alive := 0.0


func _ready() -> void:
	_fuse_timer.wait_time = fuse_time
	_fuse_timer.one_shot = true
	_fuse_timer.timeout.connect(detonate)
	body_entered.connect(_on_body_entered)
	_fuse_timer.start()


func launch(initial_velocity: Vector3, source: Node) -> void:
	shooter = source
	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
	if shooter is CollisionObject3D:
		add_collision_exception_with(shooter as CollisionObject3D)


func _physics_process(delta: float) -> void:
	_time_alive += delta


func _on_body_entered(body: Node) -> void:
	if _has_detonated or body == shooter or _time_alive < 0.12:
		return

	if _fuse_timer.time_left > impact_detonation_delay:
		_fuse_timer.start(impact_detonation_delay)


func detonate() -> void:
	if _has_detonated:
		return

	_has_detonated = true
	_fuse_timer.stop()
	_collision_shape.set_deferred("disabled", true)
	_visual.hide()
	freeze = true
	sleeping = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	_spawn_explosion_feedback()
	_apply_explosion_damage()

	await get_tree().create_timer(cleanup_delay).timeout
	queue_free()


func _spawn_explosion_feedback() -> void:
	var explosion := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position

	_explosion_sound.pitch_scale = randf_range(0.9, 1.1)
	_explosion_sound.play()


func _apply_explosion_damage() -> void:
	var explosion_position := global_position
	for body in get_tree().get_nodes_in_group("damageables"):
		var target := body as Node3D
		if body == shooter or body is Player or target == null or not body.has_method("damage"):
			continue

		var distance := explosion_position.distance_to(target.global_position)
		if distance > explosion_radius:
			continue

		var direction := target.global_position - explosion_position
		if direction.length() < 0.1:
			direction = Vector3.UP
		direction = direction.normalized()
		direction.y = max(direction.y, 0.35)

		var falloff := 1.0 - clamp(distance / explosion_radius, 0.0, 1.0)
		var force := direction.normalized() * explosion_force * max(falloff, 0.35)
		var impact_point := explosion_position - target.global_position
		body.damage(impact_point, force)
