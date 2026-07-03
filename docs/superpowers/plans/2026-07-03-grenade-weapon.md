# Grenade Weapon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Testing note:** This project has no automated test framework (no `addons/`, no test files). Verification steps below use `godot --headless --check-only` for syntax/parse validation and manual play-testing via `godot` (editor) or `godot --path . main.tscn` for behavior, in place of unit tests. Treat "run headless check" + "manually verify in a running game" as the equivalent of the red/green test cycle for this codebase.

**Goal:** Add a fully-integrated grenade weapon mode to the third-person shooter: weapon switching (Tab / controller), an in-world arcing trajectory preview with landing marker, a physically-simulated bouncing/rolling grenade projectile, a fuse-based detonation with a radius-based explosion that damages nearby enemies/crates but not the thrower, and HUD feedback showing the active weapon.

**Architecture:**
- `player.gd` gains a `WeaponMode` enum (`DEFAULT` / `GRENADE`), toggled by a new `switch_weapon` input action. In grenade mode, `attack` throws a grenade (with its own cooldown) instead of shooting/meleeing.
- A new top-level `GrenadeAimIndicator` node (child of `Player`) draws a procedural ribbon mesh (reusing the existing `trajectory_material.tres` shader) along the exact parabola the grenade will fly, plus a flat landing-marker decal (reusing `aim_material.tres`) at the computed landing point. The same closed-form projectile-motion formula computes both the preview and the real throw velocity, so they always agree.
- A new `grenade_thrown.tscn`/`.gd` (RigidBody3D) is the physical grenade: gravity is applied manually via a constant downward force (decoupled from project physics gravity settings, so the preview math and the simulated flight always match), it collides only with level geometry (bounces/rolls), and a one-shot fuse `Timer` triggers detonation exactly once. Detonation spawns the existing `explosion_scene.tscn` (now with an added explosion sound) and performs a single deterministic `PhysicsShapeQueryParameters3D` sphere-overlap query to damage everything in the `"damageables"` group within radius, excluding the thrower.
- HUD: the existing `weapon_switched` signal / `weapon_ui.gd`/`weapon_ui.tscn` framework (already wired via a scene connection to `switch_to()`) is extended with a second "GRENADE" icon using the already-present `bomb_icon.png` asset.

**Tech Stack:** Godot 4.6, GDScript, Jolt Physics 3D.

---

## File Reference (for the implementer)

Existing files you will read/modify — exact current line numbers as of plan authoring:

- [player/player.gd](player/player.gd) — full file is 256 lines; input handling in `_physics_process` (lines 65–156), `attack()` (158–161), `shoot()` (164–173), `_register_input_actions()` (234–255).
- [player/player.tscn](player/player.tscn) — `Player` root node (line 82), `CameraController` (94), `PlayerUI` (156).
- [player/bullet.gd](player/bullet.gd) — pattern reference for projectile spawn/velocity/damage-on-contact.
- [player/melee_attack_area.gd](player/melee_attack_area.gd) — pattern reference for `impact_point`/`force` convention used by all `damage()` implementers.
- [icons/weapon_ui.gd](icons/weapon_ui.gd), [icons/weapon_ui.tscn](icons/weapon_ui.tscn), [icons/icone.tscn](icons/icone.tscn), [icons/icone.gd](icons/icone.gd) — weapon HUD.
- [main.tscn](main.tscn) — `weapon_switch_ui` instance + override (lines 116–128), signal connection `weapon_switched -> switch_to` (line 1637).
- [player/explosion_visuals/explosion_scene.tscn](player/explosion_visuals/explosion_scene.tscn) — reused explosion visual, autoplaying "explosion" animation that calls `queue_free` at 1.5s (line ~287-293).
- [player/grenade_visuals/grenade/grenade.tscn](player/grenade_visuals/grenade/grenade.tscn) — reused grenade model+idle animation.
- [player/grenade_visuals/trajectory_material.tres](player/grenade_visuals/trajectory_material.tres), [player/grenade_visuals/aim_material.tres](player/grenade_visuals/aim_material.tres) — pre-built shader materials for the trajectory ribbon and landing marker respectively. Their shaders read `UV.x`/`UV.y` for animated arrow-flow / pulsing-circle effects — any mesh with proper UVs works.
- [project.godot](project.godot) — `[input]` section (lines 35–104), `[layer_names]` (106–111): layer 1=Entities, 2=Level, 3=Coins, 4=Player.
- `player/sounds/musket-explosion-6383.wav` — existing unused explosion sound asset.
- `icons/bomb_icon.png` — existing unused grenade icon asset.

Damage contract used everywhere in this codebase: `damage(impact_point: Vector3, force: Vector3)` where `impact_point` is (attacker_position - target_position) and `force` is the impulse/knockback vector applied to the target. All `"damageables"` (Player, bee_bot, beetle_bot, box) implement it.

---

### Task 1: Add the `switch_weapon` input action

**Files:**
- Modify: `project.godot:87-98` (insert new action after `attack`, before `aim`, to keep the file's existing ordering by feature)
- Modify: `player/player.gd:234-248` (`_register_input_actions()`)

- [ ] **Step 1: Add the input action definition**

In `project.godot`, insert this block immediately after the `attack={...}` block (which ends at line 92) and before `aim={...}` (line 93):

```
switch_weapon={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194306,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":4,"pressure":0.0,"pressed":false,"script":null)
]
}
```

(`physical_keycode":4194306` is `KEY_TAB`; `button_index:4` is the left-shoulder button, a conventional "switch weapon" control, matching the existing style where `jump` uses button 0 and `pause` uses button 6.)

- [ ] **Step 2: Register the fallback keyboard action for portability**

In `player/player.gd`, inside `_register_input_actions()` (around line 235-248), add `"switch_weapon": KEY_TAB,` to the `INPUT_ACTIONS` dictionary, e.g. after the `"jump": KEY_SPACE,` line:

```gdscript
	const INPUT_ACTIONS := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
		"jump": KEY_SPACE,
		"switch_weapon": KEY_TAB,
		"attack": MOUSE_BUTTON_LEFT,
		"aim": MOUSE_BUTTON_RIGHT,
		"pause": KEY_ESCAPE,
		"camera_left": KEY_Q,
		"camera_right": KEY_E,
		"camera_up": KEY_R,
		"camera_down": KEY_F,
	}
```

- [ ] **Step 3: Verify project still parses**

Run: `godot --headless --path . --check-only project.godot 2>&1 | head -50` (or open the project in the editor and confirm no import/parse errors in the Output panel).
Expected: no errors related to `project.godot` or `player.gd`.

- [ ] **Step 4: Commit**

```bash
git add project.godot player/player.gd
git commit -m "feat: add switch_weapon input action"
```

---

### Task 2: Create the thrown-grenade projectile

**Files:**
- Create: `player/grenade_thrown.gd`
- Create: `player/grenade_thrown.tscn`

- [ ] **Step 1: Write the grenade projectile script**

Create `player/grenade_thrown.gd`:

```gdscript
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
		var falloff := 1.0 - clamp(distance / explosion_radius, 0.0, 1.0)
		var direction := away_from_explosion / distance if distance > 0.001 else Vector3.UP

		body.damage(-away_from_explosion, direction * explosion_force * falloff)
```

- [ ] **Step 2: Build the grenade scene**

Create `player/grenade_thrown.tscn`:

```
[gd_scene load_steps=5 format=3 uid="uid://c8h2wthr0wng1"]

[ext_resource type="Script" path="res://player/grenade_thrown.gd" id="1_thrown"]
[ext_resource type="PackedScene" uid="uid://d3765dge2xh0" path="res://player/grenade_visuals/grenade/grenade.tscn" id="2_visuals"]

[sub_resource type="SphereShape3D" id="SphereShape3D_thrown"]
radius = 0.35

[sub_resource type="PhysicsMaterial" id="PhysicsMaterial_thrown"]
friction = 0.8
bounce = 0.3

[node name="ThrownGrenade" type="RigidBody3D"]
collision_layer = 0
collision_mask = 2
continuous_cd = true
physics_material_override = SubResource("PhysicsMaterial_thrown")
script = ExtResource("1_thrown")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("SphereShape3D_thrown")

[node name="GrenadeVisuals" parent="." instance=ExtResource("2_visuals")]

[node name="FuseTimer" type="Timer" parent="."]
one_shot = true
```

Note: `collision_layer = 0` (the grenade is on no layer, so nothing needs to detect *it*) and `collision_mask = 2` (Level only), so it bounces/rolls on terrain but flies through the player and enemies during flight — this is what guarantees it can't collide with or damage the player at spawn. The `grenade.tscn` instance already contains its own idle "wave" animation; leaving it running during flight is harmless.

- [ ] **Step 3: Verify scene loads without a running game**

Run: `godot --headless --path . --check-only 2>&1 | tail -30`
Expected: no script errors mentioning `grenade_thrown`.

- [ ] **Step 4: Commit**

```bash
git add player/grenade_thrown.gd player/grenade_thrown.tscn
git commit -m "feat: add thrown grenade projectile with fuse and radius damage"
```

---

### Task 3: Add explosion sound to the existing explosion effect

**Files:**
- Create: `player/explosion_visuals/explosion.gd`
- Modify: `player/explosion_visuals/explosion_scene.tscn`

- [ ] **Step 1: Write the explosion sound script**

Create `player/explosion_visuals/explosion.gd`:

```gdscript
extends Node3D

@onready var _sound: AudioStreamPlayer3D = $ExplosionSound


func _ready() -> void:
	_sound.pitch_scale = randfn(1.0, 0.05)
	_sound.play()
```

- [ ] **Step 2: Wire it into the explosion scene**

In `player/explosion_visuals/explosion_scene.tscn`, add two `ext_resource` lines near the top (after the existing four `ext_resource` lines, i.e. after line 6):

```
[ext_resource type="Script" path="res://player/explosion_visuals/explosion.gd" id="6_sound"]
[ext_resource type="AudioStream" path="res://player/sounds/musket-explosion-6383.wav" id="7_sound"]
```

Then update the root `Explosion` node (currently line 301) to attach the script:

```
[node name="Explosion" type="Node3D" unique_id=1124962162]
transform = Transform3D(5, 0, 0, 0, 5, 0, 0, 0, 5, 0, 0, 0)
top_level = true
script = ExtResource("6_sound")
```

And add a new child node anywhere under it (e.g. right after the `GPUParticles3D` node):

```
[node name="ExplosionSound" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("7_sound")
volume_db = 4.0
```

- [ ] **Step 3: Verify**

Run: `godot --headless --path . --check-only 2>&1 | tail -30`
Expected: no errors mentioning `explosion_scene` or `explosion.gd`.

- [ ] **Step 4: Commit**

```bash
git add player/explosion_visuals/explosion.gd player/explosion_visuals/explosion_scene.tscn
git commit -m "feat: play explosion sound when the explosion effect spawns"
```

---

### Task 4: Build the grenade aiming indicator (trajectory ribbon + landing marker)

**Files:**
- Create: `player/grenade_aim_indicator.gd`
- Modify: `player/player.tscn`

- [ ] **Step 1: Write the aim indicator script**

Create `player/grenade_aim_indicator.gd`:

```gdscript
extends Node3D

const SAMPLE_COUNT := 16
const RIBBON_HEIGHT := 0.6
const LANDING_MARKER_SIZE := 2.4

@onready var _trajectory: MeshInstance3D = $TrajectoryPreview
@onready var _landing_marker: MeshInstance3D = $LandingMarker


func _ready() -> void:
	var landing_mesh := QuadMesh.new()
	landing_mesh.size = Vector2(LANDING_MARKER_SIZE, LANDING_MARKER_SIZE)
	_landing_marker.mesh = landing_mesh
	hide_aim()


func show_aim() -> void:
	_trajectory.visible = true
	_landing_marker.visible = true


func hide_aim() -> void:
	_trajectory.visible = false
	_landing_marker.visible = false


## Rebuilds the ribbon/marker to match the exact parabola thrown with `velocity`
## from `origin`, under downward acceleration `gravity`, over `flight_time` seconds.
func update_aim(origin: Vector3, velocity: Vector3, gravity: float, flight_time: float) -> void:
	var points := PackedVector3Array()
	for i in range(SAMPLE_COUNT + 1):
		var t := flight_time * float(i) / float(SAMPLE_COUNT)
		points.append(origin + velocity * t + Vector3.DOWN * (0.5 * gravity * t * t))

	_trajectory.mesh = _build_ribbon_mesh(points)
	_trajectory.global_transform = Transform3D.IDENTITY

	var landing_point := points[points.size() - 1]
	_landing_marker.global_transform = Transform3D(
		Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)),
		landing_point + Vector3.UP * 0.05,
	)


func _build_ribbon_mesh(points: PackedVector3Array) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var u := float(i) / float(points.size() - 1)
		surface_tool.set_uv(Vector2(u, 0.0))
		surface_tool.add_vertex(points[i])
		surface_tool.set_uv(Vector2(u, 1.0))
		surface_tool.add_vertex(points[i] + Vector3.UP * RIBBON_HEIGHT)
	return surface_tool.commit()
```

Both meshes are positioned via `global_transform` set directly in code, so the node itself never needs to move — set both `TrajectoryPreview` and `LandingMarker` (not their parent) as `top_level = true` in the scene so their global transforms are fully independent of the Player's own transform.

- [ ] **Step 2: Add the indicator nodes to `player.tscn`**

In `player/player.tscn`, add two new `ext_resource` lines (pick any unused id suffix, e.g. after the existing `ext_resource` block ending at line 10):

```
[ext_resource type="Script" path="res://player/grenade_aim_indicator.gd" id="20_aimind"]
[ext_resource type="Material" uid="uid://b6h7p7jogt6ep" path="res://player/grenade_visuals/trajectory_material.tres" id="21_trajmat"]
[ext_resource type="Material" uid="uid://dus6jtbfyqwj8" path="res://player/grenade_visuals/aim_material.tres" id="22_aimmat"]
```

Then add these nodes as children of the `Player` root (anywhere after the `CameraController` block, e.g. right before `GroundShapeCast` at line 123):

```
[node name="GrenadeAimIndicator" type="Node3D" parent="." unique_id=1900000001]
script = ExtResource("20_aimind")

[node name="TrajectoryPreview" type="MeshInstance3D" parent="GrenadeAimIndicator" unique_id=1900000002]
top_level = true
material_override = ExtResource("21_trajmat")
visible = false

[node name="LandingMarker" type="MeshInstance3D" parent="GrenadeAimIndicator" unique_id=1900000003]
top_level = true
material_override = ExtResource("22_aimmat")
visible = false
```

(`visible = false` here is just the editor-time default; `_ready()` in the script also calls `hide_aim()` to guarantee it regardless of scene defaults.)

- [ ] **Step 3: Verify**

Run: `godot --headless --path . --check-only 2>&1 | tail -30`
Expected: no errors mentioning `player.tscn` or `grenade_aim_indicator`.

- [ ] **Step 4: Commit**

```bash
git add player/grenade_aim_indicator.gd player/player.tscn
git commit -m "feat: add grenade trajectory/landing aim indicator to player scene"
```

---

### Task 5: Wire weapon-mode switching and grenade throwing into `player.gd`

**Files:**
- Modify: `player/player.gd`

- [ ] **Step 1: Add state, exports, and node references**

Near the top of `player/player.gd`, after the `signal weapon_switched(weapon_name: String)` line (line 4), add:

```gdscript
enum WeaponMode { DEFAULT, GRENADE }
```

After `const COIN_SCENE := preload("coin/coin.tscn")` (line 7), add:

```gdscript
const GRENADE_SCENE := preload("grenade_thrown.tscn")
```

After the `## Projectile cooldown` / `@export var shoot_cooldown := 0.5` block (lines 28-29), add:

```gdscript
## Gravity used for both the grenade trajectory preview and the thrown grenade's flight.
@export var grenade_gravity := 30.0
## Forward distance a grenade lands at when thrown without holding aim.
@export var grenade_default_range := 9.0
## Controls how flight time scales with throw distance (higher = faster/flatter arcs).
@export var grenade_speed_reference := 9.0
@export var grenade_min_flight_time := 0.5
@export var grenade_max_flight_time := 2.5
## Grenade throw cooldown.
@export var grenade_cooldown := 1.6
```

After `@onready var _ui_coins_container: HBoxContainer = %CoinsContainer` (line 37), add:

```gdscript
@onready var _grenade_aim_indicator: Node3D = $GrenadeAimIndicator
```

After `@onready var _shoot_cooldown_tick := shoot_cooldown` (line 49), add:

```gdscript
@onready var _grenade_cooldown_tick := grenade_cooldown

var _weapon_mode := WeaponMode.DEFAULT
```

- [ ] **Step 2: Handle the weapon-switch input and branch attack handling**

In `_physics_process` (starts line 65), right after the existing input-state block (after line 81, `var is_just_on_floor := ...`), add:

```gdscript
	if Input.is_action_just_pressed("switch_weapon"):
		_toggle_weapon_mode()
```

Replace the existing attack block (lines 111-121):

```gdscript
	# Update attack state and position

	_shoot_cooldown_tick += delta

	if is_attacking:
		if is_aiming and is_on_floor():
			if _shoot_cooldown_tick > shoot_cooldown:
				_shoot_cooldown_tick = 0.0
				shoot()
		elif is_just_attacking:
			attack()
```

with:

```gdscript
	# Update attack state and position

	_shoot_cooldown_tick += delta
	_grenade_cooldown_tick += delta

	if _weapon_mode == WeaponMode.GRENADE:
		_update_grenade_aim(is_aiming)
		if is_just_attacking and _grenade_cooldown_tick > grenade_cooldown:
			_grenade_cooldown_tick = 0.0
			_throw_grenade(is_aiming)
	elif is_attacking:
		if is_aiming and is_on_floor():
			if _shoot_cooldown_tick > shoot_cooldown:
				_shoot_cooldown_tick = 0.0
				shoot()
		elif is_just_attacking:
			attack()
```

- [ ] **Step 3: Add the weapon-mode/grenade helper methods**

After `shoot()` (ends line 173, before `reset_position()` at line 176), add:

```gdscript
func _toggle_weapon_mode() -> void:
	if _weapon_mode == WeaponMode.DEFAULT:
		_weapon_mode = WeaponMode.GRENADE
		weapon_switched.emit("GRENADE")
	else:
		_weapon_mode = WeaponMode.DEFAULT
		weapon_switched.emit("DEFAULT")
		_grenade_aim_indicator.hide_aim()


func _update_grenade_aim(is_aiming: bool) -> void:
	var origin := global_position + Vector3.UP
	var target := _get_grenade_target(origin, is_aiming)
	var flight_time := _get_grenade_flight_time(origin, target)
	var throw_velocity := _compute_grenade_velocity(origin, target, flight_time)

	_grenade_aim_indicator.show_aim()
	_grenade_aim_indicator.update_aim(origin, throw_velocity, grenade_gravity, flight_time)


func _throw_grenade(is_aiming: bool) -> void:
	var origin := global_position + Vector3.UP
	var target := _get_grenade_target(origin, is_aiming)
	var flight_time := _get_grenade_flight_time(origin, target)
	var throw_velocity := _compute_grenade_velocity(origin, target, flight_time)

	var grenade := GRENADE_SCENE.instantiate()
	grenade.thrower = self
	grenade.gravity = grenade_gravity
	get_parent().add_child(grenade)
	grenade.global_position = origin
	grenade.linear_velocity = throw_velocity


func _get_grenade_target(origin: Vector3, is_aiming: bool) -> Vector3:
	if is_aiming:
		return _camera_controller.get_aim_target()
	var forward := (_rotation_root.transform.basis * Vector3.BACK).normalized()
	return origin + forward * grenade_default_range


func _get_grenade_flight_time(origin: Vector3, target: Vector3) -> float:
	var horizontal_distance := Vector2(target.x - origin.x, target.z - origin.z).length()
	return clampf(horizontal_distance / grenade_speed_reference, grenade_min_flight_time, grenade_max_flight_time)


func _compute_grenade_velocity(origin: Vector3, target: Vector3, flight_time: float) -> Vector3:
	var displacement := target - origin
	var velocity_xz := Vector3(displacement.x, 0.0, displacement.z) / flight_time
	var velocity_y := (displacement.y + 0.5 * grenade_gravity * flight_time * flight_time) / flight_time
	return Vector3(velocity_xz.x, velocity_y, velocity_xz.z)
```

- [ ] **Step 4: Verify**

Run: `godot --headless --path . --check-only 2>&1 | tail -60`
Expected: no parse/script errors in `player.gd`.

- [ ] **Step 5: Commit**

```bash
git add player/player.gd
git commit -m "feat: add grenade weapon mode switching and throwing to player"
```

---

### Task 6: Add the grenade icon to the weapon HUD

**Files:**
- Modify: `icons/weapon_ui.gd`
- Modify: `icons/weapon_ui.tscn`
- Modify: `main.tscn`

- [ ] **Step 1: Register the grenade icon in the HUD script**

In `icons/weapon_ui.gd`, change:

```gdscript
@onready var nodes := {
	"DEFAULT" : %Flash
}
```

to:

```gdscript
@onready var nodes := {
	"DEFAULT" : %Flash,
	"GRENADE" : %Bomb,
}
```

- [ ] **Step 2: Add the Bomb icon node to the HUD scene**

In `icons/weapon_ui.tscn`, add an `ext_resource` for the bomb icon texture after the existing ones (after line 4):

```
[ext_resource type="Texture2D" path="res://icons/bomb_icon.png" id="3_bomb"]
```

Then, after the existing `MarginContainer`/`Flash` block (lines 37-45), add a second margin container + icon instance as a sibling under `Control`:

```
[node name="MarginContainer2" type="MarginContainer" parent="Control" unique_id=141859044]
layout_mode = 2
theme_override_constants/margin_left = 8
theme_override_constants/margin_top = 2
theme_override_constants/margin_right = 8
theme_override_constants/margin_bottom = 2

[node name="Bomb" parent="Control/MarginContainer2" unique_id=784886256 instance=ExtResource("2_etwmu")]
layout_mode = 2
texture = ExtResource("3_bomb")
```

(`2_etwmu` is the existing `icone.tscn` ext_resource id already declared at line 4 of this file — reusing it gives the new icon the same `icone.gd` selection behavior, just with a different node name/texture.)

- [ ] **Step 3: Widen the HUD panel in the main scene to fit two icons**

In `main.tscn`, find the `weapon_switch_ui` instance override (lines 116-128) and change `offset_right` from `192.0` to `264.0`:

```
[node name="weapon_switch_ui" parent="." unique_id=733299686 instance=ExtResource("1_3u7h6")]
anchors_preset = 2
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 0.0
anchor_bottom = 1.0
offset_left = 32.0
offset_top = -92.0
offset_right = 264.0
offset_bottom = -24.0
grow_horizontal = 1
grow_vertical = 0
```

- [ ] **Step 4: Verify**

Run: `godot --headless --path . --check-only 2>&1 | tail -30`
Expected: no errors mentioning `weapon_ui` or `main.tscn`.

- [ ] **Step 5: Commit**

```bash
git add icons/weapon_ui.gd icons/weapon_ui.tscn main.tscn
git commit -m "feat: show grenade icon in weapon HUD"
```

---

### Task 7: Full manual smoke test and final verification

**Files:** none (verification only)

- [ ] **Step 1: Headless full-project check**

Run: `godot --headless --path . --check-only 2>&1 | tail -100`
Expected: zero errors/warnings referencing any file touched in Tasks 1-6.

- [ ] **Step 2: Launch the game and manually verify every item below**

Run: `godot --path . main.tscn` (or open in editor and press Play).

Walk through, in order:
1. Default weapon mode is active on start (weapon HUD shows the Flash icon highlighted, Bomb icon dim).
2. Left-click (aim held) fires the default bullet as before; left-click without aim performs the melee punch as before.
3. Press `Tab`: HUD switches to show the Bomb icon highlighted, Flash dim, immediately.
4. With grenade mode active and aim *not* held, a glowing arced ribbon and a landing-marker decal appear in front of the player without any input beyond selecting grenade mode.
5. Hold the aim button and move the mouse/camera: the ribbon and landing marker update in real time to follow the crosshair/camera raycast target.
6. Press attack (aim not held): a grenade model launches from near the player, arcs under gravity, bounces/rolls, and explodes (visual + `musket-explosion` sound) at/near its landing spot — roughly 6-12 units ahead on flat ground.
7. During the ~1.6s cooldown after a throw, the trajectory ribbon/marker remain visible (not deleted), and pressing attack again does not throw a second grenade or fall back to melee/shooting.
8. Place/observe an enemy or crate a few units from the detonation point: it is damaged/destroyed. Place/observe one far away (>10 units, or behind the player): it is unaffected.
9. Confirm the player's own health/coins are unaffected by their own explosion (no self-knockback/coin loss).
10. After cooldown elapses, throw a second grenade; confirm it also flies, lands, and explodes correctly, and earlier grenade/explosion nodes are gone (check remote scene tree in the debugger, or just confirm no lingering frozen grenade meshes).
11. Press `Tab` again to return to default mode: the aim ribbon/marker disappear immediately, and shooting/melee work exactly as before.
12. Confirm jump pads, coin collection, and existing enemy AI are unaffected throughout.

- [ ] **Step 3: Record results**

Note the outcome of every numbered check in Step 2 (pass/fail + any deviation) — this feeds directly into the `AGENT_RUN_RECORD.md` deliverable required by the task spec.

---

## Self-Review Notes

- **Spec coverage:** weapon switching + Tab/controller (Task 1, 5), default-mode preserved / grenade-mode suppresses melee & shoot (Task 5 Step 2's `elif` structure), HUD dual-icon + instant update (Task 6), aim ribbon + landing marker incl. default no-aim arc and aim-held control, visible through cooldown, hidden on switch-back (Task 4, 5), physical arcing/bouncing grenade that doesn't hit the player at spawn (Task 2), fuse-based single detonation with cleanup (Task 2), radius explosion damaging nearby damageables but not thrower/distant targets (Task 2), explosion visual+sound (Task 2, 3), tuning defaults matching the 6-12 unit / few-unit-radius targets (Task 2 exports, Task 5 exports), stability/no regressions (Task 7 manual pass covers all pre-existing systems).
- **No placeholders:** all code blocks above are complete, runnable GDScript/tscn diffs, not stubs.
- **Type/name consistency check:** `grenade.thrower`, `grenade.gravity`, `grenade.linear_velocity` (Task 5) match the exported/inherited members defined on `grenade_thrown.gd` (Task 2: `thrower`, `gravity`, and RigidBody3D's built-in `linear_velocity`). `_grenade_aim_indicator.show_aim()`/`hide_aim()`/`update_aim(origin, velocity, gravity, flight_time)` (Task 5) match the method signatures defined in `grenade_aim_indicator.gd` (Task 4). The `damage(impact_point, force)` call in `grenade_thrown.gd` matches the existing contract used by `bullet.gd`/`melee_attack_area.gd` and implemented by `player.gd`, `bee_bot.gd`, `beetle_bot.gd`, `box.gd`.
