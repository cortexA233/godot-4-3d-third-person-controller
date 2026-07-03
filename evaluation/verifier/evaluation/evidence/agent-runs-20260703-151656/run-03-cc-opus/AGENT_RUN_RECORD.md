# Agent Run Record — Grenade Weapon Feature

## Agent / Model

- Agent: Claude Code (Anthropic CLI, running on the Claude Agent SDK).
- Model: Claude Opus 4.8 (`claude-opus-4-8`).
- Date: 2026-07-03.

## Tools Available vs. Used

**Available:** file read/write/edit, glob/grep search, Bash (Git Bash) and
PowerShell shells, a Godot MCP server (`mcp__godot__*`: `get_godot_version`,
`list_projects`, `run_project`, `get_debug_output`, `stop_project`, editor/scene
helpers), Unity MCP, Chrome MCP, web search/fetch, and task/workflow helpers.

**Used:**
- File tools (Read/Write/Edit/Glob/Grep) for all inspection and code changes.
- **Bash** to drive the installed Godot engine directly for verification.
- The **Godot MCP** was visible; I loaded its tool schemas via ToolSearch
  (`get_godot_version`, `run_project`, etc.) but ultimately did **not** invoke the
  MCP. I called the Godot 4.6 executable directly instead, because it gave precise
  control over headless import, framebounded runs, and custom test scenes, and
  guaranteed I only ever touched this workspace (never a sibling project).
- Godot binary used: `C:\Godot_v4.6\Godot_v4.6-stable_win64_console.exe`
  (`4.6.stable.official.89cea1439`). This matches the project's
  `config/features="4.6"`.

I did not inspect git history, other branches, parent directories, sibling
projects, verifier files, or any original solution — only the current workspace
and the task prompt.

## What the Ablation Left Behind

The project already contained the grenade *assets and hooks*, but none of the
*logic*:
- `player/grenade_visuals/` — grenade model/scene, trajectory + target shaders,
  materials (`trajectory_material.tres`, `aim_material.tres`), and textures.
- `player/explosion_visuals/explosion_scene.tscn` — self-animating, self-freeing
  explosion effect (no sound of its own).
- `player/sounds/musket-explosion-6383.wav` — explosion sound.
- `icons/bomb_icon.png` + `icons/weapon_ui.tscn` (already instanced in
  `main.tscn` as `weapon_switch_ui`).
- `Player.weapon_switched(weapon_name)` signal, already connected in `main.tscn`
  to `weapon_switch_ui.switch_to`.

The implementation reuses all of these rather than introducing new art/audio.

## Files Changed and Why

**New files**
- `player/grenade_projectile.gd` (`class_name GrenadeProjectile`, RigidBody3D):
  the thrown grenade. Handles ballistic flight (full gravity, no linear damping,
  continuous CD, bounce/friction physics material), an arming delay so it never
  hits the thrower at spawn, detonation via a combination of direct-hit / surface
  impact fuse / hard max fuse, one-shot detonation, radius-based damage using a
  physics shape query (calls the existing `damage(impact_point, force)` on group
  `"damageables"`, excludes the thrower), and spawning of the shared explosion
  effect + explosion sound. Cleans itself up on detonation.
- `player/grenade_aim.gd` (`class_name GrenadeAim`, Node3D): the aiming aid. Draws
  a dotted parabola (pooled unshaded emissive spheres) plus a landing marker (a
  flat quad using the existing animated `aim_material.tres` target reticle),
  oriented to the predicted surface. Simulates the same ballistic model the throw
  uses and ray-casts along it to find the impact point. Dims while on cooldown but
  stays visible.
- `player/grenade_projectile.gd.uid`, `player/grenade_aim.gd.uid`: Godot-generated
  script UIDs (consistent with every other script in the project).

**Modified files**
- `player/player.gd`: added a `WeaponMode { DEFAULT, GRENADE }` state; `Tab`/
  gamepad weapon switching (`_toggle_weapon_mode`, emits the existing
  `weapon_switched` signal + shows/hides the aim aid); grenade throwing on attack
  in grenade mode with a cooldown (default shooting/melee suppressed in that
  mode); a closed-form launch-velocity solver (`_compute_throw_velocity`, fixed
  arc angle, capped speed); default vs. aim-based targeting
  (`_get_grenade_target`); per-frame aim-preview updates; and `weapon_switch` in
  the runtime input-action fallback. All original default-weapon behavior is left
  intact inside the `else` branch.
- `project.godot`: added the `weapon_switch` input action (`Tab` +
  gamepad button 3 / "Y").
- `icons/weapon_ui.gd`: mapped `"GRENADE"` to a bomb icon that is created at
  runtime by reusing the existing `icone.tscn` with `bomb_icon.png` (added next to
  the default weapon icon), and highlight the default weapon on ready. Done in
  code because the project's `.tscn` files carry non-standard `unique_id=` node
  attributes that make hand-editing risky; the scene format is untouched.

No existing assets, scenes, or non-grenade scripts were otherwise modified.

## Commands Run and Outcomes

All via the Godot 4.6 console executable, `--headless`, scoped to this workspace.

1. `--import` (first pass) → exit 0. Generated the asset import cache
   (`.godot/`, git-ignored). Surfaced one real bug in my code
   (`grenade_projectile.gd`: `var id :=` couldn't infer a type from a Variant),
   which I fixed, plus the need for a `class_name` so the typed `.new()` resolved
   `setup()`.
2. `--import` (second pass) → exit 0. Registered `GrenadeProjectile` /
   `GrenadeAim` / `Player` in the global class cache.
3. `--path <ws> --quit-after 150` (main scene) → exit 0. **No** script/parse/
   compile errors. Only a pre-existing, unrelated warning: the background music
   `level/music/mountain.mp3` "resources still in use at exit" (autoplay stream
   cut off at headless shutdown; present independent of this feature).
4. Temporary behavioral test scene (created, run, then deleted) → **`TEST_RESULT
   PASS`**: launch velocity `(0, 7.59, 7.59)`; the grenade flew for ~68 physics
   frames before detonating (real flight phase, no instant blast); both nearby
   targets took damage; a far target (~22 u), a behind target (~9 u back), and the
   thrower took **no** damage; one explosion node and one sound node were spawned.
5. Temporary weapon-HUD test scene (created, run, then deleted) → **`UI_RESULT
   PASS`**: default highlighted on ready; both `DEFAULT` and `GRENADE` mapped; the
   grenade icon created successfully; `switch_to("GRENADE")` and back to
   `"DEFAULT"` both updated the selection.
6. Final `--path <ws> --quit-after 150` after removing test files and reverting
   incidental `.import` churn → exit 0, clean.

The four temporary test files (`__grenade_test.gd/.tscn`, `__ui_test.gd/.tscn`)
were deleted; they are not part of the deliverable. Godot's import pass had
normalized ~16 `*.glb.import` metadata files (4.6 dropped a few stale keys); since
those are unrelated to the feature and their `dest_files` hashes were unchanged, I
reverted them so the diff contains only the five intended files.

## Manual Observations

Verification was performed **headless** (no rendered window), so gameplay was not
watched visually; behavior was confirmed through the automated headless tests
above plus code review. Observed via those runs:
- The main scene loads and ticks without errors with the feature present.
- A thrown grenade has a genuine arced flight phase and detonates near its landing
  point roughly a second after the throw — responsive for combat.
- Explosion damage is spatial: multiple close targets are hit; distant/behind
  targets and the thrower are not.
- The explosion visual and explosion sound are both instantiated on detonation and
  are independent, self-freeing nodes.
- The HUD exposes two weapons and the selection toggles correctly.

## Implemented Behavior (Summary)

- Two weapon modes; start in the default weapon. `Tab` (or gamepad Y) toggles to
  grenade mode and back, updating the HUD icon highlight immediately via the
  existing `weapon_switched` signal.
- In default mode, aim/shoot/melee are unchanged. In grenade mode, attack throws
  an arcing grenade whether or not aim is held; melee and default shooting are
  suppressed, and attacks during cooldown do nothing (no fallback).
- Grenade mode always shows an in-world aiming aid: a dotted arc plus an animated
  landing reticle at the predicted impact point, updated every frame. Without aim
  it uses a stable ~9-unit forward arc (no mouse fine-tuning needed); while aiming
  it follows the camera aim point for both direction and distance. It stays
  visible (dimmed) during cooldown and hides when switching back to the default
  weapon.
- The grenade is a gravity-driven RigidBody that bounces/settles, will not tunnel
  through level geometry, cannot hit its thrower, and always detonates (direct hit,
  short impact fuse, or a hard max fuse). On detonation it deals radius-based
  damage to nearby `"damageables"` (enemies and crates, via their existing
  `damage()` method), spawns the shared explosion effect, and plays the explosion
  sound; all temporary nodes clean themselves up. Repeated throws work.

### Default tuning (all `@export`-adjustable)

- Throw: forward distance `9.0` u, arc angle `45°`, max speed `22.0`, cooldown
  `1.2 s`.
- Grenade: explosion radius `4.0` u, arming `0.15 s`, impact fuse `0.4 s`, max fuse
  `2.5 s`, gravity = project default (`16.0`).

## Known Issues / Uncertainties

- **Visuals not eyeballed:** verification was headless, so the exact on-screen look
  of the trajectory dots, landing reticle, grenade size, and explosion scale was
  reasoned about but not visually confirmed. The provided `aim_material.tres`
  target reticle is used as-authored; the animated flowing-arrow
  `trajectory_material.tres` ribbon was **not** used (a robust dotted arc was used
  instead, tinted to match the reticle's blue).
- **Preview vs. real path after a bounce:** the arc preview shows the ideal
  ballistic path to first impact; once the grenade bounces, its physical path may
  differ slightly from the drawn dots. This is expected for a physics grenade.
- **Extreme aim throws** (e.g., aiming at the sky or far past max range) clamp to
  the max launch speed — a best-effort throw in the aimed direction; the preview
  still shows exactly where it will land.
- **Gamepad** weapon switch is mapped to button 3 (Y/Triangle) and was not tested
  with a physical controller.
- The pre-existing headless "`mountain.mp3` resources still in use at exit"
  warning is unrelated to this feature and also occurs without the grenade code.
