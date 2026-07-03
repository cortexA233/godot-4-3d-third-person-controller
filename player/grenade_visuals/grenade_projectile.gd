extends RigidBody3D

const EXPLOSION_SCENE := preload("res://player/explosion_visuals/explosion_scene.tscn")
const EXPLOSION_SOUND := preload("res://player/sounds/musket-explosion-6383.wav")

## Detonates automatically once this much time has passed, even without an impact.
@export var fuse_time := 2.2
## Short delay after the first impact with the world before detonating.
@export var impact_fuse_time := 0.45
## Radius (in world units) affected by the explosion.
@export var explosion_radius := 4.0
## Knockback strength applied to damaged bodies.
@export var explosion_impulse := 9.0

@onready var _fuse_timer: Timer = $FuseTimer
@onready var _impact_timer: Timer = $ImpactTimer

var shooter: Node = null
var _exploded := false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	_fuse_timer.wait_time = fuse_time
	_fuse_timer.one_shot = true
	_fuse_timer.timeout.connect(_explode)
	_fuse_timer.start()

	_impact_timer.one_shot = true
	_impact_timer.timeout.connect(_explode)


func _on_body_entered(_body: Node) -> void:
	if _exploded or not _impact_timer.is_stopped():
		return
	_impact_timer.start(impact_fuse_time)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_fuse_timer.stop()
	_impact_timer.stop()

	var parent := get_parent()

	var explosion := EXPLOSION_SCENE.instantiate()
	parent.add_child(explosion)
	explosion.global_position = global_position

	var explosion_sound := AudioStreamPlayer3D.new()
	explosion_sound.stream = EXPLOSION_SOUND
	explosion_sound.max_distance = 40.0
	parent.add_child(explosion_sound)
	explosion_sound.global_position = global_position
	explosion_sound.play()
	explosion_sound.finished.connect(explosion_sound.queue_free)

	_apply_explosion_damage()

	queue_free()


func _apply_explosion_damage() -> void:
	for body in get_tree().get_nodes_in_group("damageables"):
		if body == shooter or not (body is Node3D):
			continue
		var impact_point: Vector3 = global_position - body.global_position
		var distance := impact_point.length()
		if distance > explosion_radius:
			continue
		if not body.has_method("damage"):
			continue

		var falloff := 1.0 - (distance / explosion_radius)
		var away := -impact_point
		away = away.normalized() if away.length() > 0.01 else Vector3.UP
		var force := away * explosion_impulse * falloff
		force.y = max(force.y, 2.0 * falloff)

		body.damage(impact_point, force)
