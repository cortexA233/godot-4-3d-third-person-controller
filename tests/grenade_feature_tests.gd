extends SceneTree

const GrenadeTrajectory := preload("res://player/grenade_trajectory.gd")
const GRENADE_PROJECTILE_SCENE := preload("res://player/grenade_projectile.tscn")

var _failures: Array[String] = []


class DummyDamageable:
	extends StaticBody3D

	var damage_count := 0
	var last_force := Vector3.ZERO

	func _ready() -> void:
		add_to_group("damageables")
		collision_layer = 1
		collision_mask = 1
		var collision_shape := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.5
		collision_shape.shape = shape
		add_child(collision_shape)

	func damage(_impact_point: Vector3, force: Vector3) -> void:
		damage_count += 1
		last_force = force


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_throw_lands_at_medium_range()
	_test_aimed_throw_uses_target_distance()
	await _test_explosion_damages_only_nearby_damageables()

	if _failures.is_empty():
		print("Grenade feature tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_default_throw_lands_at_medium_range() -> void:
	var origin := Vector3(0.0, 1.35, 0.0)
	var velocity := GrenadeTrajectory.get_default_velocity(Vector3.FORWARD, 10.0, 5.2)
	var landing := GrenadeTrajectory.estimate_ground_landing(origin, velocity, 16.0, 0.0)
	var horizontal_distance := Vector2(landing.x, landing.z).length()
	_assert_between(horizontal_distance, 6.0, 12.0, "default grenade throw should land at medium combat range")
	_assert_true(landing.z > 0.0, "default grenade throw should land in front of the player")


func _test_aimed_throw_uses_target_distance() -> void:
	var origin := Vector3(0.0, 1.35, 0.0)
	var near_target := Vector3(0.0, 0.0, 7.0)
	var far_target := Vector3(0.0, 0.0, 14.0)
	var near_velocity := GrenadeTrajectory.get_aimed_velocity(origin, near_target, Vector3.FORWARD, 16.0, 6.0, 4.0, 16.0)
	var far_velocity := GrenadeTrajectory.get_aimed_velocity(origin, far_target, Vector3.FORWARD, 16.0, 6.0, 4.0, 16.0)
	var near_landing := GrenadeTrajectory.estimate_ground_landing(origin, near_velocity, 16.0, 0.0)
	var far_landing := GrenadeTrajectory.estimate_ground_landing(origin, far_velocity, 16.0, 0.0)

	_assert_true(far_landing.z > near_landing.z + 3.0, "aimed grenade throw should respond to farther target distances")
	_assert_between(near_landing.z, 4.0, 10.0, "near aimed grenade landing should stay near the requested target")
	_assert_between(far_landing.z, 10.0, 16.5, "far aimed grenade landing should stay near the requested target")


func _test_explosion_damages_only_nearby_damageables() -> void:
	var shooter := CharacterBody3D.new()
	shooter.name = "Shooter"
	root.add_child(shooter)
	shooter.global_position = Vector3.ZERO

	var near_target := DummyDamageable.new()
	root.add_child(near_target)
	near_target.global_position = Vector3(2.0, 0.0, 0.0)

	var far_target := DummyDamageable.new()
	root.add_child(far_target)
	far_target.global_position = Vector3(12.0, 0.0, 0.0)

	var grenade := GRENADE_PROJECTILE_SCENE.instantiate()
	root.add_child(grenade)
	grenade.global_position = Vector3.ZERO
	grenade.shooter = shooter
	grenade.explosion_radius = 3.5

	await process_frame
	await physics_frame
	grenade.detonate()
	await process_frame

	_assert_equal(near_target.damage_count, 1, "grenade explosion should damage nearby damageables once")
	_assert_equal(far_target.damage_count, 0, "grenade explosion should leave distant damageables untouched")
	_assert_true(near_target.last_force.length() > 0.0, "grenade explosion should apply visible knockback force")

	shooter.queue_free()
	near_target.queue_free()
	far_target.queue_free()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_between(actual: float, minimum: float, maximum: float, message: String) -> void:
	if actual < minimum or actual > maximum:
		_failures.append("%s. Expected %.2f through %.2f, got %.2f" % [message, minimum, maximum, actual])
