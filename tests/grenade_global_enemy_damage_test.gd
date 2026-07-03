extends SceneTree

const GRENADE_SCENE := preload("res://player/grenade.tscn")

var _failures: Array[String] = []


class DamageTarget extends StaticBody3D:
	var damage_count := 0
	var last_impact_point := Vector3.ZERO
	var last_force := Vector3.ZERO

	func _init(is_enemy: bool) -> void:
		add_to_group("damageables")
		if is_enemy:
			add_to_group("targeteables")

		var collision_shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 0.5
		collision_shape.shape = sphere_shape
		add_child(collision_shape)

	func damage(impact_point: Vector3, force: Vector3) -> void:
		damage_count += 1
		last_impact_point = impact_point
		last_force = force


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)

	var grenade := GRENADE_SCENE.instantiate()
	arena.add_child(grenade)
	grenade.global_position = Vector3.ZERO
	grenade.get_node("ExplosionSound").stream = null

	var near_enemy := DamageTarget.new(true)
	near_enemy.name = "NearEnemy"
	arena.add_child(near_enemy)
	near_enemy.global_position = Vector3(1.0, 0.0, 0.0)

	var distant_enemy := DamageTarget.new(true)
	distant_enemy.name = "DistantEnemy"
	arena.add_child(distant_enemy)
	distant_enemy.global_position = Vector3(80.0, 0.0, 0.0)

	var nearby_non_enemy := DamageTarget.new(false)
	nearby_non_enemy.name = "NearbyNonEnemy"
	arena.add_child(nearby_non_enemy)
	nearby_non_enemy.global_position = Vector3(0.5, 0.0, 0.0)

	await physics_frame
	await physics_frame

	grenade.call("_explode")
	await process_frame

	_assert_equal(near_enemy.damage_count, 1, "near enemy should be damaged once")
	_assert_equal(distant_enemy.damage_count, 1, "distant enemy should also be damaged once")
	_assert_equal(nearby_non_enemy.damage_count, 0, "nearby non-enemy damageable should not be damaged")
	_assert_true(near_enemy.last_force.length() > 0.0, "near enemy damage should receive a non-zero force")
	_assert_true(distant_enemy.last_force.length() > 0.0, "distant enemy damage should receive a non-zero force")

	grenade.get_node("ExplosionSound").emit_signal("finished")
	await process_frame

	arena.queue_free()
	await process_frame

	if _failures.is_empty():
		print("PASS: grenade damages every enemy in the scene and ignores non-enemy damageables")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s." % [message, expected, actual])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
