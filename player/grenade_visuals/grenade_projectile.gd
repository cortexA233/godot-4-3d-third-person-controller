class_name GrenadeProjectile
extends RigidBody3D

## A thrown grenade. Flies as a ballistic RigidBody, detonates on impact (or when
## its fuse runs out), spawns the shared explosion effect and applies spatially
## based damage to nearby "damageables" using the project's damage() convention.

const GRENADE_VISUAL := preload("res://player/grenade_visuals/grenade/grenade.tscn")
const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")
const EXPLOSION_SOUND := preload("res://player/sounds/musket-explosion-6383.wav")

## Radius (in world units) within which damageables are hit by the blast.
var explosion_radius := 4.0
## Peak knockback impulse applied to affected bodies (enemies clamp this themselves).
var explosion_force := 10.0
## Seconds before the grenade detonates on its own if it never collides.
var fuse_time := 2.5
## Ignore collisions for this long after the throw so it never blows up in-hand.
var arm_delay := 0.06
## Gravity magnitude (m/s^2). Set by the thrower so flight matches the aim preview.
var gravity := 24.0
## The node that threw this grenade; it is never damaged by its own blast.
var thrower: Node = null

var _age := 0.0
var _armed := false
var _detonated := false


func _ready() -> void:
	# Match the RigidBody gravity to the value used by the trajectory preview so the
	# grenade lands where the marker predicts.
	var default_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 16.0)
	gravity_scale = gravity / default_gravity if default_gravity > 0.0 else 1.0
	mass = 0.4
	# Custom projectile layer (5): collides with the world (layer 1) but is ignored
	# by other bodies' masks and by the aim raycast, and never blocks the player.
	collision_layer = 1 << 4
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	var visual := GRENADE_VISUAL.instantiate()
	visual.scale = Vector3.ONE
	add_child(visual)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	_age += delta
	if not _armed and _age >= arm_delay:
		_armed = true
	if _age >= fuse_time:
		detonate()


func _on_body_entered(_body: Node) -> void:
	if _armed:
		detonate()


func detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var blast_position := global_position
	_spawn_explosion(blast_position)
	_play_explosion_sound(blast_position)
	_apply_area_damage(blast_position)

	queue_free()


func _spawn_explosion(at: Vector3) -> void:
	var explosion := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(explosion)
	# The explosion root is top_level, so drive it through global space. Its shell
	# animates to roughly one world unit of radius per unit of scale.
	explosion.global_position = at
	explosion.scale = Vector3.ONE * explosion_radius


func _play_explosion_sound(at: Vector3) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = EXPLOSION_SOUND
	sound.pitch_scale = randfn(1.0, 0.08)
	sound.unit_size = 12.0
	sound.max_distance = 90.0
	get_parent().add_child(sound)
	sound.global_position = at
	sound.play()
	sound.finished.connect(sound.queue_free)


func _apply_area_damage(center: Vector3) -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if body == thrower or not is_instance_valid(body):
			continue
		if not (body is Node3D) or not body.has_method("damage"):
			continue

		var to_body: Vector3 = body.global_position - center
		var distance := to_body.length()
		if distance > explosion_radius:
			continue

		# Stronger, more upward push the closer the target is to the blast.
		var falloff := 1.0 - clampf(distance / explosion_radius, 0.0, 1.0)
		var direction := to_body.normalized() if distance > 0.001 else Vector3.UP
		var force := direction * explosion_force * (0.4 + 0.6 * falloff)
		force.y = absf(force.y) + explosion_force * 0.4 * falloff
		# impact_point mirrors the project convention (see bullet.gd / melee_attack_area.gd):
		# the offset from the target's origin to the source of the hit.
		var impact_point: Vector3 = center - body.global_position
		body.damage(impact_point, force)
