extends RigidBody3D

## Emitted once, right before the grenade and its explosion visuals are freed.
signal detonated

## Downward acceleration applied manually (independent of project physics
## gravity) so the flight always matches the trajectory preview's math.
@export var gravity := 30.0
## Time from spawn until forced detonation, even if the grenade hasn't landed.
@export var fuse_time := 1.4
## Radius, in world units, of the damage/knockback query at detonation.
@export var explosion_radius := 4.0
## Magnitude of the outward knockback force applied to damaged bodies at zero distance.
@export var explosion_force := 10.0

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")
## Entities (layer 1, value 1) + Player (layer 4, value 8): who can be damaged.
const EXPLOSION_COLLISION_MASK := 9

## The Node that threw this grenade; excluded from explosion damage.
var thrower: Node = null

@onready var _fuse_timer: Timer = $FuseTimer

var _detonated := false


func _ready() -> void:
	gravity_scale = 0.0
	_fuse_timer.wait_time = fuse_time
	_fuse_timer.one_shot = true
	_fuse_timer.timeout.connect(_detonate)
	_fuse_timer.start()


func _physics_process(_delta: float) -> void:
	if _detonated:
		return
	apply_central_force(Vector3.DOWN * gravity * mass)


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var explosion := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position

	_apply_explosion_damage()
	detonated.emit()
	queue_free()


func _apply_explosion_damage() -> void:
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = EXPLOSION_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state := get_world_3d().direct_space_state
	var results := space_state.intersect_shape(query, 32)

	for result in results:
		var body: Node = result["collider"]
		if body == thrower or not body.is_in_group("damageables"):
			continue

		var away_from_explosion: Vector3 = body.global_position - global_position
		var distance := away_from_explosion.length()
		var falloff := 1.0 - clampf(distance / explosion_radius, 0.0, 1.0)
		var direction := away_from_explosion / distance if distance > 0.001 else Vector3.UP

		body.damage(-away_from_explosion, direction * explosion_force * falloff)
