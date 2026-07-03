class_name Player
extends CharacterBody3D

signal weapon_switched(weapon_name: String)

enum WeaponMode { DEFAULT, GRENADE }

const BULLET_SCENE := preload("bullet.tscn")
const COIN_SCENE := preload("coin/coin.tscn")
const GRENADE_SCENE := preload("grenade_visuals/grenade_projectile.tscn")

## Character maximum run speed on the ground.
@export var move_speed := 8.0
## Speed of shot bullets.
@export var bullet_speed := 10.0
## Forward impulse after a melee attack.
@export var attack_impulse := 10.0
## Movement acceleration (how fast character achieve maximum speed)
@export var acceleration := 4.0
## Jump impulse
@export var jump_initial_impulse := 12.0
## Jump impulse when player keeps pressing jump
@export var jump_additional_force := 4.5
## Player model rotation speed
@export var rotation_speed := 12.0
## Minimum horizontal speed on the ground. This controls when the character's animation tree changes
## between the idle and running states.
@export var stopping_speed := 1.0
## Max throwback force after player takes a hit
@export var max_throwback_force := 15.0
## Projectile cooldown
@export var shoot_cooldown := 0.5
## Cooldown between grenade throws
@export var grenade_cooldown := 1.4
## Default throw distance used when the aim button isn't held
@export var grenade_default_range := 9.0
## Closest a grenade can be aimed to land while aiming
@export var grenade_min_range := 4.0
## Farthest a grenade can be aimed to land while aiming
@export var grenade_max_range := 14.0
## Launch angle used for every grenade throw
@export var grenade_launch_angle := deg_to_rad(45.0)

@onready var _rotation_root: Node3D = $CharacterRotationRoot
@onready var _camera_controller: CameraController = $CameraController
@onready var _attack_animation_player: AnimationPlayer = $CharacterRotationRoot/MeleeAnchor/AnimationPlayer
@onready var _ground_shapecast: ShapeCast3D = $GroundShapeCast
@onready var _character_skin: CharacterSkin = $CharacterRotationRoot/CharacterSkin
@onready var _ui_aim_reticle: ColorRect = %AimReticle
@onready var _ui_coins_container: HBoxContainer = %CoinsContainer
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _landing_sound: AudioStreamPlayer3D = $LandingSound
@onready var _grenade_aim: Node3D = $GrenadeAim

@onready var _move_direction := Vector3.ZERO
@onready var _last_strong_direction := Vector3.FORWARD
@onready var _gravity: float = -30.0
@onready var _ground_height: float = 0.0
@onready var _start_position := global_transform.origin
@onready var _coins := 0
@onready var _is_on_floor_buffer := false

@onready var _shoot_cooldown_tick := shoot_cooldown
@onready var _grenade_cooldown_tick := grenade_cooldown
@onready var _weapon_mode := WeaponMode.DEFAULT


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.setup(self)
	_grenade_aim.hide()
	weapon_switched.emit("DEFAULT")

	# When copying this character to a new project, the project may lack required input actions.
	# In that case, we register input actions for the user at runtime.
	if not InputMap.has_action("move_left"):
		_register_input_actions()

	_character_skin.stepped.connect(play_foot_step_sound)


func _physics_process(delta: float) -> void:
	# Calculate ground height for camera controller
	if _ground_shapecast.get_collision_count() > 0:
		for collision_result in _ground_shapecast.collision_result:
			_ground_height = max(_ground_height, collision_result.point.y)
	else:
		_ground_height = global_position.y + _ground_shapecast.target_position.y
	if global_position.y < _ground_height:
		_ground_height = global_position.y

	# Get input and movement state
	var is_attacking := Input.is_action_pressed("attack") and not _attack_animation_player.is_playing()
	var is_just_attacking := Input.is_action_just_pressed("attack")
	var is_just_jumping := Input.is_action_just_pressed("jump") and is_on_floor()
	var is_aiming := Input.is_action_pressed("aim") and is_on_floor()
	var is_air_boosting := Input.is_action_pressed("jump") and not is_on_floor() and velocity.y > 0.0
	var is_just_on_floor := is_on_floor() and not _is_on_floor_buffer

	_is_on_floor_buffer = is_on_floor()
	_move_direction = _get_camera_oriented_input()

	# To not orient quickly to the last input, we save a last strong direction,
	# this also ensures a good normalized value for the rotation basis.
	if _move_direction.length() > 0.2:
		_last_strong_direction = _move_direction.normalized()
	if is_aiming:
		_last_strong_direction = (_camera_controller.global_transform.basis * Vector3.BACK).normalized()

	_orient_character_to_direction(_last_strong_direction, delta)

	# We separate out the y velocity to not interpolate on the gravity
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.lerp(_move_direction * move_speed, acceleration * delta)
	if _move_direction.length() == 0 and velocity.length() < stopping_speed:
		velocity = Vector3.ZERO
	velocity.y = y_velocity

	# Set aiming camera and UI
	if is_aiming:
		_camera_controller.set_pivot(_camera_controller.CAMERA_PIVOT.OVER_SHOULDER)
		_ui_aim_reticle.visible = true
	else:
		_camera_controller.set_pivot(_camera_controller.CAMERA_PIVOT.THIRD_PERSON)
		_ui_aim_reticle.visible = false

	# Update attack state and position

	_shoot_cooldown_tick += delta
	_grenade_cooldown_tick += delta

	if Input.is_action_just_pressed("weapon_switch"):
		_toggle_weapon_mode()

	if _weapon_mode == WeaponMode.DEFAULT:
		_grenade_aim.hide()
		if is_attacking:
			if is_aiming and is_on_floor():
				if _shoot_cooldown_tick > shoot_cooldown:
					_shoot_cooldown_tick = 0.0
					shoot()
			elif is_just_attacking:
				attack()
	else:
		var grenade_launch := _compute_grenade_launch(is_aiming)
		var grenade_trajectory := _simulate_grenade_trajectory(grenade_launch)
		var grenade_on_cooldown := _grenade_cooldown_tick <= grenade_cooldown
		_grenade_aim.update_aim(grenade_trajectory.points, grenade_trajectory.landing, grenade_on_cooldown)
		if is_just_attacking and not grenade_on_cooldown:
			_grenade_cooldown_tick = 0.0
			throw_grenade(grenade_launch)

	velocity.y += _gravity * delta

	if is_just_jumping:
		velocity.y += jump_initial_impulse
	elif is_air_boosting:
		velocity.y += jump_additional_force * delta

	# Set character animation
	if is_just_jumping:
		_character_skin.jump()
	elif not is_on_floor() and velocity.y < 0:
		_character_skin.fall()
	elif is_on_floor():
		var xz_velocity := Vector3(velocity.x, 0, velocity.z)
		if xz_velocity.length() > stopping_speed:
			_character_skin.set_moving(true)
			_character_skin.set_moving_speed(inverse_lerp(0.0, move_speed, xz_velocity.length()))
		else:
			_character_skin.set_moving(false)

	if is_just_on_floor:
		_landing_sound.play()

	var position_before := global_position
	move_and_slide()
	var position_after := global_position

	# If velocity is not 0 but the difference of positions after move_and_slide is,
	# character might be stuck somewhere!
	var delta_position := position_after - position_before
	var epsilon := 0.001
	if delta_position.length() < epsilon and velocity.length() > epsilon:
		global_position += get_wall_normal() * 0.1


func attack() -> void:
	_attack_animation_player.play("Attack")
	_character_skin.punch()
	velocity = _rotation_root.transform.basis * Vector3.BACK * attack_impulse


func shoot() -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.shooter = self
	var origin := global_position + Vector3.UP
	var aim_target := _camera_controller.get_aim_target()
	var aim_direction := (aim_target - origin).normalized()
	bullet.velocity = aim_direction * bullet_speed
	bullet.distance_limit = 14.0
	get_parent().add_child(bullet)
	bullet.global_position = origin


func throw_grenade(launch: Dictionary) -> void:
	var grenade := GRENADE_SCENE.instantiate()
	grenade.shooter = self
	get_parent().add_child(grenade)
	grenade.global_position = launch.origin
	grenade.linear_velocity = launch.velocity
	_character_skin.punch()


func _toggle_weapon_mode() -> void:
	if _weapon_mode == WeaponMode.DEFAULT:
		_weapon_mode = WeaponMode.GRENADE
		weapon_switched.emit("GRENADE")
	else:
		_weapon_mode = WeaponMode.DEFAULT
		_grenade_aim.hide()
		weapon_switched.emit("DEFAULT")


## Computes the throw origin/velocity for the current aim state.
## Without aim held, throws use a stable default forward arc.
## While aiming, direction and distance follow the camera's aim target.
func _compute_grenade_launch(is_aiming_now: bool) -> Dictionary:
	var origin := global_position + Vector3.UP * 1.2 + _last_strong_direction * 0.6
	var direction := _last_strong_direction
	var target_distance := grenade_default_range

	if is_aiming_now:
		var aim_target := _camera_controller.get_aim_target()
		var to_target := aim_target - origin
		to_target.y = 0.0
		if to_target.length() > 0.1:
			direction = to_target.normalized()
		target_distance = clamp(to_target.length(), grenade_min_range, grenade_max_range)

	var gravity_magnitude: float = abs(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	# At a fixed launch angle, range R = speed^2 * sin(2*angle) / gravity.
	var speed := sqrt(target_distance * gravity_magnitude / sin(2.0 * grenade_launch_angle))
	var horizontal_speed := speed * cos(grenade_launch_angle)
	var vertical_speed := speed * sin(grenade_launch_angle)

	return {
		"origin": origin,
		"velocity": direction * horizontal_speed + Vector3.UP * vertical_speed,
		"gravity": gravity_magnitude,
	}


## Simulates the ballistic arc for the aiming aid, stopping early at the first
## world collision so the landing marker matches where the grenade will actually land.
func _simulate_grenade_trajectory(launch: Dictionary) -> Dictionary:
	const STEP_TIME := 0.03
	const MAX_STEPS := 150
	const LEVEL_COLLISION_MASK := 2

	var space_state := get_world_3d().direct_space_state
	var sim_position: Vector3 = launch.origin
	var velocity_sim: Vector3 = launch.velocity
	var gravity_magnitude: float = launch.gravity

	var points := PackedVector3Array([sim_position])
	var landing_point := sim_position

	for _step in MAX_STEPS:
		var previous_position := sim_position
		velocity_sim.y -= gravity_magnitude * STEP_TIME
		sim_position += velocity_sim * STEP_TIME

		var query := PhysicsRayQueryParameters3D.create(previous_position, sim_position)
		query.collision_mask = LEVEL_COLLISION_MASK
		var result := space_state.intersect_ray(query)
		if result:
			landing_point = result.position
			points.append(landing_point)
			return {"points": points, "landing": landing_point}

		points.append(sim_position)
		landing_point = sim_position
		if sim_position.y < previous_position.y - 40.0:
			break

	return {"points": points, "landing": landing_point}


func reset_position() -> void:
	transform.origin = _start_position


func collect_coin() -> void:
	_coins += 1
	_ui_coins_container.update_coins_amount(_coins)


func lose_coins() -> void:
	var lost_coins: int = min(_coins, 5)
	_coins -= lost_coins
	for i in lost_coins:
		var coin := COIN_SCENE.instantiate()
		get_parent().add_child(coin)
		coin.global_position = global_position
		coin.spawn(1.5)
	_ui_coins_container.update_coins_amount(_coins)


func _get_camera_oriented_input() -> Vector3:
	if _attack_animation_player.is_playing():
		return Vector3.ZERO

	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var input := Vector3.ZERO
	# This is to ensure that diagonal input isn't stronger than axis aligned input
	input.x = -raw_input.x * sqrt(1.0 - raw_input.y * raw_input.y / 2.0)
	input.z = -raw_input.y * sqrt(1.0 - raw_input.x * raw_input.x / 2.0)

	input = _camera_controller.global_transform.basis * input
	input.y = 0.0
	return input


func play_foot_step_sound() -> void:
	_step_sound.pitch_scale = randfn(1.2, 0.2)
	_step_sound.play()


func damage(_impact_point: Vector3, force: Vector3) -> void:
	# Always throws character up
	force.y = abs(force.y)
	velocity = force.limit_length(max_throwback_force)
	lose_coins()


func _orient_character_to_direction(direction: Vector3, delta: float) -> void:
	var left_axis := Vector3.UP.cross(direction)
	var rotation_basis := Basis(left_axis, Vector3.UP, direction).get_rotation_quaternion()
	var model_scale := _rotation_root.transform.basis.get_scale()
	_rotation_root.transform.basis = Basis(_rotation_root.transform.basis.get_rotation_quaternion().slerp(rotation_basis, delta * rotation_speed)).scaled(
		model_scale,
	)


## Used to register required input actions when copying this character to a different project.
func _register_input_actions() -> void:
	const INPUT_ACTIONS := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
		"jump": KEY_SPACE,
		"attack": MOUSE_BUTTON_LEFT,
		"aim": MOUSE_BUTTON_RIGHT,
		"pause": KEY_ESCAPE,
		"weapon_switch": KEY_TAB,
		"camera_left": KEY_Q,
		"camera_right": KEY_E,
		"camera_up": KEY_R,
		"camera_down": KEY_F,
	}
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var input_key = InputEventKey.new()
		input_key.keycode = INPUT_ACTIONS[action]
		InputMap.action_add_event(action, input_key)
