class_name Player
extends CharacterBody3D

signal weapon_switched(weapon_name: String)

enum Weapon { DEFAULT, GRENADE }

const BULLET_SCENE := preload("bullet.tscn")
const COIN_SCENE := preload("coin/coin.tscn")

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

@export_group("Grenade")
## Gravity applied to thrown grenades and used to predict their arc.
@export var grenade_gravity := 24.0
## Time of flight used to solve the throw arc toward the target point.
@export var grenade_flight_time := 0.85
## Landing distance of a default (non-aimed) forward throw, in world units.
@export var grenade_default_range := 9.0
## Closest a grenade can be aimed when holding the aim button.
@export var grenade_min_range := 3.0
## Farthest a grenade can be aimed when holding the aim button.
@export var grenade_max_range := 16.0
## Minimum time between grenade throws.
@export var grenade_cooldown := 1.1
## Blast radius of a grenade explosion.
@export var grenade_explosion_radius := 4.0
## Fuse before a grenade self-detonates if it never collides.
@export var grenade_fuse_time := 2.5

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

var _current_weapon := Weapon.DEFAULT
var _grenade_aim: GrenadeAim


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.setup(self)

	# The aiming aid lives on the player but draws in world space (top_level).
	_grenade_aim = GrenadeAim.new()
	add_child(_grenade_aim)

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

	# Weapon switching (Tab / controller button) toggles default <-> grenade.
	if Input.is_action_just_pressed("switch_weapon"):
		_toggle_weapon()

	# Update attack state and position

	_shoot_cooldown_tick += delta
	_grenade_cooldown_tick += delta

	if _current_weapon == Weapon.GRENADE:
		# Grenade mode keeps the aiming aid visible whether or not the aim button is
		# held and throws an arcing grenade on attack (never melee or default shots).
		var launch := _get_grenade_launch(is_aiming)
		_grenade_aim.update_preview(
			launch.origin,
			launch.velocity,
			grenade_gravity,
			get_rid(),
			get_world_3d().direct_space_state,
			_camera_controller.camera,
		)
		_grenade_aim.set_ready(_grenade_cooldown_tick >= grenade_cooldown)
		if is_just_attacking and _grenade_cooldown_tick >= grenade_cooldown:
			_grenade_cooldown_tick = 0.0
			_throw_grenade(launch.origin, launch.velocity)
	elif is_attacking:
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


func _toggle_weapon() -> void:
	if _current_weapon == Weapon.DEFAULT:
		_current_weapon = Weapon.GRENADE
		weapon_switched.emit("GRENADE")
	else:
		_current_weapon = Weapon.DEFAULT
		weapon_switched.emit("DEFAULT")
		_grenade_aim.hide_preview()


## Compute the grenade spawn point and launch velocity for the current aim state.
## Without aiming: a stable medium-range forward arc. While aiming: the throw
## follows the camera aim, letting the player control direction and distance.
func _get_grenade_launch(is_aiming: bool) -> Dictionary:
	var forward := _camera_controller.global_transform.basis * Vector3.BACK
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = _last_strong_direction
	forward = forward.normalized()

	var origin := global_position + Vector3.UP * 1.3 + forward * 0.6

	var target: Vector3
	if is_aiming:
		var aim_point := _camera_controller.get_aim_target()
		var flat := aim_point - global_position
		flat.y = 0.0
		var flat_distance := flat.length()
		var direction := flat.normalized() if flat_distance > 0.001 else forward
		var distance := clampf(flat_distance, grenade_min_range, grenade_max_range)
		target = global_position + direction * distance
		# Keep vertical target sane even when aiming at the sky or steep terrain.
		target.y = clampf(aim_point.y, global_position.y - 6.0, global_position.y + 4.0)
	else:
		target = global_position + forward * grenade_default_range
		target.y = global_position.y

	var launch_velocity := _solve_launch_velocity(origin, target, grenade_gravity, grenade_flight_time)
	return {"origin": origin, "velocity": launch_velocity}


## Velocity that carries a projectile from origin to target in flight_time under gravity.
func _solve_launch_velocity(origin: Vector3, target: Vector3, arc_gravity: float, flight_time: float) -> Vector3:
	var grav_accel := Vector3(0.0, -arc_gravity, 0.0)
	return (target - origin) / flight_time - 0.5 * grav_accel * flight_time


func _throw_grenade(origin: Vector3, launch_velocity: Vector3) -> void:
	var grenade := GrenadeProjectile.new()
	grenade.thrower = self
	grenade.gravity = grenade_gravity
	grenade.explosion_radius = grenade_explosion_radius
	grenade.fuse_time = grenade_fuse_time
	get_parent().add_child(grenade)
	grenade.global_position = origin
	grenade.add_collision_exception_with(self)
	grenade.linear_velocity = launch_velocity
	_character_skin.punch()


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
		"switch_weapon": KEY_TAB,
		"pause": KEY_ESCAPE,
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
