## Physics grenade thrown by the player in grenade weapon mode.
##
## The grenade flies as a ballistic RigidBody (so it arcs, bounces and settles),
## then detonates from a short fuse, on a direct hit against a damageable target,
## or shortly after it settles. On detonation it deals spatial, radius-based
## damage to nearby "damageables" (enemies, crates), spawns the shared explosion
## effect and plays the explosion sound. It never damages the player who threw it.
class_name GrenadeProjectile
extends RigidBody3D

const GRENADE_VISUAL := preload("res://player/grenade_visuals/grenade/grenade.tscn")
const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")
const EXPLOSION_SOUND := preload("res://player/sounds/musket-explosion-6383.wav")

## Radius, in world units, within which damageables are affected.
@export var explosion_radius := 4.0
## Base knockback impulse applied to affected bodies.
@export var blast_force := 12.0
## Time before the grenade can collide/detonate, so it never hits its thrower at spawn.
@export var arming_time := 0.15
## Delay between the first surface contact (or settling) and detonation.
@export var impact_fuse := 0.4
## Hard cap: the grenade always detonates by this time, even if it never lands.
@export var max_fuse := 2.5
## Physics layers scanned for collisions and explosion damage (layers 1-8).
@export_flags_3d_physics var interaction_layers := 0xFF

var thrower: Node = null

var _spawn_position := Vector3.ZERO
var _spawn_velocity := Vector3.ZERO
var _time_alive := 0.0
var _impact_time := -1.0
var _detonate_requested := false
var _detonated := false


## Configure the grenade before it is added to the tree. The spawn transform and
## velocity are applied in _ready so the physics body picks them up correctly.
func setup(spawn_position: Vector3, spawn_velocity: Vector3, thrower_node: Node) -> void:
	_spawn_position = spawn_position
	_spawn_velocity = spawn_velocity
	thrower = thrower_node


func _ready() -> void:
	# Ballistic tuning: full gravity, no linear damping so the flight matches the
	# predicted arc, continuous collision detection so a fast grenade never tunnels.
	gravity_scale = 1.0
	mass = 1.0
	linear_damp = 0.0
	angular_damp = 1.0
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4

	# The grenade scans the world but sits on no layer; the thrower is excluded
	# explicitly below so the grenade never collides with or damages the player.
	collision_layer = 0
	collision_mask = interaction_layers

	var bounce_material := PhysicsMaterial.new()
	bounce_material.friction = 0.8
	bounce_material.bounce = 0.25
	physics_material_override = bounce_material

	var collision_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	collision_shape.shape = sphere
	add_child(collision_shape)

	var visual := GRENADE_VISUAL.instantiate()
	add_child(visual)

	global_position = _spawn_position
	linear_velocity = _spawn_velocity
	# Deterministic forward tumble along the flight direction (cosmetic only).
	var spin_axis := _spawn_velocity.cross(Vector3.UP)
	if spin_axis.length() > 0.01:
		angular_velocity = spin_axis.normalized() * 9.0

	if thrower != null and thrower is CollisionObject3D:
		add_collision_exception_with(thrower)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _detonated:
		return

	_time_alive += delta

	if _detonate_requested:
		detonate()
		return

	var armed := _time_alive >= arming_time

	# If the grenade has settled (barely moving) start the impact fuse even if we
	# never received a contact signal, so it always detonates near where it rests.
	if armed and _impact_time < 0.0 and _time_alive > 0.5 and linear_velocity.length() < 1.0:
		_impact_time = _time_alive

	if _impact_time >= 0.0 and _time_alive - _impact_time >= impact_fuse:
		detonate()
		return

	if _time_alive >= max_fuse:
		detonate()


func _on_body_entered(body: Node) -> void:
	if _detonated or _detonate_requested:
		return
	if _time_alive < arming_time:
		return
	if body == thrower:
		return

	if body.is_in_group("damageables"):
		# Direct hit on an enemy/crate: detonate on the next physics tick.
		_detonate_requested = true
	elif _impact_time < 0.0:
		# First contact with level geometry: start the short impact fuse.
		_impact_time = _time_alive


func detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var point := global_position
	_apply_explosion_damage(point)
	_spawn_explosion(point)
	_play_explosion_sound(point)

	queue_free()


func _apply_explosion_damage(point: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state

	var query_shape := SphereShape3D.new()
	query_shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = Transform3D(Basis(), point)
	query.collision_mask = interaction_layers
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if thrower != null and thrower is CollisionObject3D:
		query.exclude = [thrower.get_rid()]

	var results := space_state.intersect_shape(query, 32)
	var already_hit := {}

	for result in results:
		var collider = result.get("collider")
		if collider == null or collider == thrower:
			continue

		var id: int = collider.get_instance_id()
		if already_hit.has(id):
			continue
		already_hit[id] = true

		if not collider.is_in_group("damageables"):
			continue
		if not collider.has_method("damage"):
			continue

		var to_body: Vector3 = collider.global_position - point
		# Center-distance safety gate so only genuinely nearby targets are hit.
		if to_body.length() > explosion_radius + 1.5:
			continue

		var push := Vector3(to_body.x, 0.0, to_body.z)
		if push.length() < 0.01:
			push = Vector3.FORWARD
		push = push.normalized()

		var force := (push + Vector3.UP * 0.7).normalized() * blast_force
		var impact_point := push * 0.3
		collider.damage(impact_point, force)


func _spawn_explosion(point: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var explosion := EXPLOSION_SCENE.instantiate()
	parent.add_child(explosion)
	explosion.global_position = point


func _play_explosion_sound(point: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = EXPLOSION_SOUND
	sound.pitch_scale = 1.0
	parent.add_child(sound)
	sound.global_position = point
	sound.finished.connect(sound.queue_free)
	sound.play()
