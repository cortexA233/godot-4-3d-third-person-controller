class_name Player
extends CharacterBody3D

signal weapon_switched(weapon_name: String)

const BULLET_SCENE := preload("bullet.tscn")
const COIN_SCENE := preload("coin/coin.tscn")
const GRENADE_SCENE := preload("grenade_projectile.gd")
const GRENADE_AIM_SCENE := preload("grenade_aim.gd")

enum WeaponMode { DEFAULT, GRENADE }

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
## Minimum delay between grenade throws (rate limit).
@export var grenade_cooldown := 1.2
## Default forward throw distance when not aiming, in world units.
@export var grenade_throw_distance := 9.0
## Launch angle above horizontal used for the grenade arc.
@export var grenade_throw_angle_degrees := 45.0
## Maximum grenade launch speed; caps very long throws.
@export var grenade_max_speed := 22.0

@onready var _rotation_root: Node3D = $CharacterRotationRoot
@onready var _camera_controller: CameraController = $CameraController
@onready var _attack_animation_player: AnimationPlayer = $CharacterRotationRoot/MeleeAnchor/AnimationPlayer
@onready var _ground_shapecast: ShapeCast3D = $GroundShapeCast
@onready var _character_skin: CharacterSkin = $CharacterRotationRoot/CharacterSkin
@onready var _ui_aim_reticle: ColorRect = %AimReticle
@onready var _ui_coins_container: HBoxContainer = %CoinsContainer
@onready var _step_sound: AudioStreamPlayer3D = $StepSound
@onready var _landing_sound: AudioStreamPlayer3D = $LandingSound

@onready var _move_direction := Vector3.ZERO
@onready var _last_strong_direction := Vector3.FORWARD
@onready var _gravity: float = -30.0
@onready var _ground_height: float = 0.0
@onready var _start_position := global_transform.origin
@onready var _coins := 0
@onready var _is_on_floor_buffer := false

@onready var _shoot_cooldown_tick := shoot_cooldown
@onready var _grenade_cooldown_tick := grenade_cooldown

var _weapon_mode: WeaponMode = WeaponMode.DEFAULT
var _grenade_aim: GrenadeAim


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.setup(self)
	weapon_switched.emit("DEFAULT")

	# The grenade aiming aid lives in world space and is only shown in grenade mode.
	_grenade_aim = GRENADE_AIM_SCENE.new()
	add_child(_grenade_aim)

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

	if _weapon_mode == WeaponMode.GRENADE:
		# Grenade mode: attacking throws an arcing grenade whether or not aim is
		# held. Default shooting and melee are suppressed. The aiming aid updates
		# every frame so the player can line up the next throw, even on cooldown.
		_update_grenade_aim()
		if is_just_attacking and _grenade_cooldown_tick >= grenade_cooldown:
			_grenade_cooldown_tick = 0.0
			throw_grenade()
	else:
		if is_attacking:
			if is_aiming and is_on_floor():
				if _shoot_cooldown_tick > shoot_cooldown:
					_shoot_cooldown_tick = 0.0
					shoot()
			elif is_just_attacking:
				attack()

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


func _toggle_weapon_mode() -> void:
	if _weapon_mode == WeaponMode.DEFAULT:
		_weapon_mode = WeaponMode.GRENADE
		weapon_switched.emit("GRENADE")
		if _grenade_aim != null:
			_grenade_aim.show()
	else:
		_weapon_mode = WeaponMode.DEFAULT
		weapon_switched.emit("DEFAULT")
		if _grenade_aim != null:
			_grenade_aim.hide()


func throw_grenade() -> void:
	var origin := _get_grenade_origin()
	var target := _get_grenade_target(origin)
	var gravity := _grenade_gravity()
	var launch_velocity := _compute_throw_velocity(origin, target, gravity, deg_to_rad(grenade_throw_angle_degrees))

	var grenade: GrenadeProjectile = GRENADE_SCENE.new()
	grenade.setup(origin, launch_velocity, self)
	get_parent().add_child(grenade)

	# Reuse the punch one-shot as a quick throwing gesture.
	_character_skin.punch()


func _update_grenade_aim() -> void:
	if _grenade_aim == null:
		return
	var origin := _get_grenade_origin()
	var target := _get_grenade_target(origin)
	var gravity := _grenade_gravity()
	var launch_velocity := _compute_throw_velocity(origin, target, gravity, deg_to_rad(grenade_throw_angle_degrees))
	var is_ready := _grenade_cooldown_tick >= grenade_cooldown
	_grenade_aim.update_preview(origin, launch_velocity, gravity, get_rid(), is_ready)


func _grenade_gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 16.0))


func _get_aim_forward_horizontal() -> Vector3:
	var forward := _camera_controller.global_transform.basis * Vector3.BACK
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3(_last_strong_direction.x, 0.0, _last_strong_direction.z)
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	return forward.normalized()


func _get_grenade_origin() -> Vector3:
	return global_position + Vector3.UP * 1.4 + _get_aim_forward_horizontal() * 0.6


func _get_grenade_target(origin: Vector3) -> Vector3:
	if Input.is_action_pressed("aim"):
		# Aiming: both throw direction and distance follow the camera aim point.
		var aim_target := _camera_controller.get_aim_target()
		var to_aim := Vector3(aim_target.x - origin.x, 0.0, aim_target.z - origin.z)
		var distance := clampf(to_aim.length(), 3.0, 30.0)
		var direction := _get_aim_forward_horizontal()
		if to_aim.length() > 0.01:
			direction = to_aim.normalized()
		var aimed_target := origin + direction * distance
		aimed_target.y = aim_target.y
		return aimed_target

	# Default (no aim): stable medium-range forward throw landing at feet height.
	var forward := _get_aim_forward_horizontal()
	var default_target := global_position + forward * grenade_throw_distance
	default_target.y = global_position.y
	return default_target


## Solve for the launch velocity that reaches "target" at a fixed arc angle.
## If the target is out of reach at that angle the speed is capped, so the preview
## (which simulates this same velocity) always matches the real throw.
func _compute_throw_velocity(origin: Vector3, target: Vector3, gravity: float, angle: float) -> Vector3:
	var to_target := target - origin
	var horizontal := Vector3(to_target.x, 0.0, to_target.z)
	var distance := horizontal.length()
	var height := to_target.y

	if distance < 0.05:
		return Vector3.UP * minf(grenade_max_speed, sqrt(2.0 * gravity * 2.0))

	var direction := horizontal / distance
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var tan_a := sin_a / cos_a

	var denominator := 2.0 * cos_a * cos_a * (distance * tan_a - height)
	var speed: float
	if denominator <= 0.05:
		speed = grenade_max_speed
	else:
		speed = sqrt(gravity * distance * distance / denominator)
		speed = minf(speed, grenade_max_speed)

	return direction * speed * cos_a + Vector3.UP * speed * sin_a


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
		"camera_left": KEY_Q,
		"camera_right": KEY_E,
		"camera_up": KEY_R,
		"camera_down": KEY_F,
		"weapon_switch": KEY_TAB,
	}
	for action in INPUT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var input_key = InputEventKey.new()
		input_key.keycode = INPUT_ACTIONS[action]
		InputMap.action_add_event(action, input_key)
