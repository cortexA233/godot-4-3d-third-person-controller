class_name GrenadeTrajectory
extends RefCounted


static func get_default_velocity(forward: Vector3, horizontal_speed: float, vertical_speed: float) -> Vector3:
	return _flat_direction(forward) * horizontal_speed + Vector3.UP * vertical_speed


static func get_aimed_velocity(
	origin: Vector3,
	target: Vector3,
	fallback_forward: Vector3,
	gravity: float,
	arc_height: float,
	min_distance: float,
	max_distance: float,
) -> Vector3:
	var to_target := target - origin
	var horizontal := Vector3(to_target.x, 0.0, to_target.z)
	var direction := _flat_direction(fallback_forward)
	if horizontal.length() > 0.001:
		direction = horizontal.normalized()

	var distance := clamp(horizontal.length(), min_distance, max_distance)
	var landing_target := origin + direction * distance
	landing_target.y = target.y

	var highest_endpoint := max(origin.y, landing_target.y)
	var apex_y := highest_endpoint + max(arc_height, 0.5)
	var vertical_speed := sqrt(max(0.0, 2.0 * gravity * (apex_y - origin.y)))
	var time_up := vertical_speed / gravity
	var time_down := sqrt(max(0.0, 2.0 * (apex_y - landing_target.y) / gravity))
	var flight_time := max(0.1, time_up + time_down)
	var horizontal_velocity := direction * (distance / flight_time)

	return horizontal_velocity + Vector3.UP * vertical_speed


static func estimate_ground_landing(origin: Vector3, velocity: Vector3, gravity: float, ground_y: float) -> Vector3:
	var height := origin.y - ground_y
	var discriminant := velocity.y * velocity.y + 2.0 * gravity * height
	if discriminant < 0.0:
		return origin
	var flight_time := (velocity.y + sqrt(discriminant)) / gravity
	return position_at_time(origin, velocity, gravity, flight_time)


static func position_at_time(origin: Vector3, velocity: Vector3, gravity: float, time: float) -> Vector3:
	return origin + velocity * time + Vector3.DOWN * 0.5 * gravity * time * time


static func _flat_direction(direction: Vector3) -> Vector3:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.001:
		return Vector3.FORWARD
	return flat.normalized()
