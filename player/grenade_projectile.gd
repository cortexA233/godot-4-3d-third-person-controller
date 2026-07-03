class_name GrenadeProjectile
extends RigidBody3D

## A thrown grenade. It flies as a ballistic RigidBody, detonates on the first
## contact after a short arming delay (with a fuse as a fallback), then spawns
## an explosion that damages nearby "damageables" and cleans itself up.

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")

## Radius (in Godot units) around the detonation point that takes damage.
@export var explosion_radius := 4.5
## Base knockback strength applied to affected bodies.
@export var explosion_force := 14.0
## Maximum lifetime before the grenade detonates on its own (safety fallback).
@export var fuse_time := 3.0
## Time after being thrown before the grenade is allowed to detonate on contact.
## Prevents detonating on the thrower or muzzle at spawn.
@export var arm_delay := 0.1

var _thrower: Node = null
var _time_alive := 0.0
var _detonated := false


## Called by the player right after the grenade is added to the scene tree.
func throw(thrower: Node, spawn_position: Vector3, initial_velocity: Vector3, gravity: float) -> void:
	_thrower = thrower
	global_position = spawn_position

	# Keep the grenade's fall consistent with the trajectory preview by matching
	# the requested gravity through gravity_scale.
	var project_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 16.0)
	if project_gravity <= 0.0:
		project_gravity = 16.0
	gravity_scale = gravity / project_gravity

	linear_velocity = initial_velocity

	# Never collide with or damage the thrower at spawn.
	if thrower is PhysicsBody3D:
		add_collision_exception_with(thrower)


func _physics_process(delta: float) -> void:
	if _detonated:
		return

	_time_alive += delta

	if _time_alive >= fuse_time:
		_detonate()
		return

	# Detonate once it has settled against level geometry (or a target), but only
	# after the arming delay so it can't blow up in the player's face at spawn.
	if _time_alive >= arm_delay and get_contact_count() > 0:
		_detonate()


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var detonation_point := global_position

	var explosion := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = detonation_point

	_apply_explosion_damage(detonation_point)

	queue_free()


func _apply_explosion_damage(center: Vector3) -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if body == _thrower:
			continue
		if not is_instance_valid(body):
			continue
		if not body.has_method("damage"):
			continue

		var to_body: Vector3 = body.global_position - center
		var distance := to_body.length()
		if distance > explosion_radius:
			continue

		var direction := to_body.normalized() if distance > 0.05 else Vector3.UP
		var falloff := 1.0 - distance / explosion_radius
		# Push outward from the blast with a slight upward bias, stronger up close.
		var force := (direction + Vector3.UP * 0.6).normalized() * explosion_force * (0.4 + 0.6 * falloff)
		body.damage(Vector3.ZERO, force)
