extends RigidBody3D
## A physical grenade thrown by the player. Flies as a real ballistic RigidBody, then
## detonates a short time after landing (or after a fixed fuse if it never settles),
## damaging nearby damageables and cleaning itself up afterward.

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")
const EXPLOSION_SOUND := preload("res://player/sounds/musket-explosion-6383.wav")

## Maximum time alive before detonating even if it never touches anything.
@export var fuse_time := 1.6
## Extra delay after the first impact before detonating, so it can bounce/settle briefly.
@export var impact_fuse_time := 0.45
## Radius of the explosion damage check.
@export var explosion_radius := 4.0
## Magnitude of the knockback force applied to nearby damageables.
@export var explosion_force := 14.0

@onready var _fuse_timer: Timer = $FuseTimer
@onready var _impact_timer: Timer = $ImpactTimer

var thrower: Node = null
var _detonated := false
var _has_landed := false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	_fuse_timer.timeout.connect(_detonate)
	_impact_timer.timeout.connect(_detonate)
	_fuse_timer.start(fuse_time)


## Sets the grenade flying. Must be called once, right after adding it to the scene tree.
func launch(initial_velocity: Vector3, shooter: Node) -> void:
	thrower = shooter
	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	if shooter is CollisionObject3D:
		add_collision_exception_with(shooter)


func _on_body_entered(body: Node3D) -> void:
	if _detonated or _has_landed:
		return
	if body == thrower:
		return
	_has_landed = true
	_impact_timer.start(impact_fuse_time)


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var query_shape := SphereShape3D.new()
	query_shape.radius = explosion_radius
	query.shape = query_shape
	query.transform = Transform3D(Basis(), global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]

	for result in space_state.intersect_shape(query, 32):
		var body: Node3D = result.collider
		if body == thrower:
			continue
		if body.is_in_group("damageables"):
			var impact_point: Vector3 = global_position - body.global_position
			var force: Vector3 = -impact_point.normalized() * explosion_force
			body.damage(impact_point, force)

	var explosion := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position

	var sound := AudioStreamPlayer3D.new()
	sound.stream = EXPLOSION_SOUND
	sound.pitch_scale = randfn(1.0, 0.05)
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.play()
	sound.finished.connect(sound.queue_free)

	queue_free()
