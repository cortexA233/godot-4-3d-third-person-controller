# Agent Run Record — Grenade Weapon Feature

## Agent / Model

- Claude Code CLI, model Sonnet 5 (`claude-sonnet-5`).

## Tools available and used

- File tools (Read/Edit/Write/Glob/Grep) and Bash — used throughout for research and implementation.
- A general-purpose research subagent (`Agent` tool) — used once to map the existing player/weapon/HUD/damage code before writing anything.
- **Godot MCP was visible and was used**: `mcp__godot__get_godot_version`, `mcp__godot__launch_editor`, `mcp__godot__run_project`, `mcp__godot__get_debug_output`, `mcp__godot__stop_project`.
  - Used to confirm the engine version (4.6.stable), to trigger a full asset import (the project's `.godot/imported/` cache was initially empty, causing every asset — not just new ones — to fail to load), and to repeatedly boot the game headed and inspect the debug/error log for script or parse errors after each round of edits.
  - The available Godot MCP tools do **not** include input injection or screenshotting, so I could not drive the actual play session (press Tab, click to throw, etc.) through MCP. Verification of runtime behavior is therefore based on: (a) zero script/parse errors or warnings on a clean run after import, (b) careful static review of the game/physics logic and Godot 4 API usage, and (c) reasoning through the ballistic math by hand.

## Files changed and why

- `project.godot` — added a new `switch_weapon` input action (Tab key + joypad Left Shoulder/button 9).
- `player/player.gd` — added grenade weapon-mode state (`WEAPON.DEFAULT` / `WEAPON.GRENADE`), weapon-switch handling, grenade throw cooldown, a shared ballistic-velocity calculation (`_compute_grenade_launch_velocity`) used both for the real throw and the aim preview, and gating so melee/shoot only run in `DEFAULT` mode while grenade throwing only runs in `GRENADE` mode.
- `player/player.tscn` — added a `GrenadeAimPreview` node (top-level, so its world-space math doesn't need to fight the player's own transform) running the new preview script.
- `player/grenade_visuals/grenade_trajectory_preview.gd` (new) — builds a dotted arc (`MultiMeshInstance3D` of small emissive spheres) and a landing marker (reusing the project's existing `grenade_target_shader`/textures) by simulating the same parabola the grenade will fly, raycasting against the world so the marker lands where a real throw would.
- `player/grenade_visuals/grenade/thrown_grenade.gd` (new) + `thrown_grenade.tscn` (new) — the actual thrown grenade: a `RigidBody3D` with a sphere collider and bouncy physics material, wrapping the project's existing (previously unused for gameplay) `grenade.tscn` visual model. Detonates after a fixed fuse or a short delay after first impact, whichever comes first; queries a sphere region for `"damageables"` bodies (excluding the thrower) and calls their existing `damage(impact_point, force)` convention; spawns the project's existing `explosion_scene.tscn` VFX plus a one-shot `AudioStreamPlayer3D` using the previously-unused `musket-explosion-6383.wav`; frees itself once.
- `icons/weapon_ui.gd` — registered a second weapon icon (`"GRENADE"`) alongside the existing `"DEFAULT"`.
- `icons/weapon_ui.tscn` — added a second icon instance using the project's existing (previously unused) `bomb_icon.png`, and widened the panel so both icons fit without overlapping.

No other existing files were modified; default shooting, melee, movement, enemies, boxes, coins, and jump pads are untouched.

## Design notes / how the tuning works

- Grenade launch uses a fixed 40° launch angle. Horizontal range is either a fixed default (9 units, inside the required 6–12 unit band) when not aiming, or derived from the camera's aim raycast (clamped 4–16 units) while holding aim — both direction and distance change with aim. The required launch speed for the chosen angle/range is solved from the standard projectile range equation using the project's own gravity (`project.godot`'s `3d/default_gravity = 16.0`), so the preview and the real RigidBody trajectory should coincide.
- Explosion radius defaults to 4 units (satisfies "affect targets within a few units" while leaving 10+-unit-away targets, and the thrower, unaffected).
- Grenade cooldown defaults to 1.5s; fuse defaults to 1.6s with a 0.45s post-impact detonation delay, whichever triggers first.
- All of the above are `@export`ed on `Player` (grenade_*) and on `ThrownGrenade` so they're tunable from the editor without code changes.
- Damage reuses the project's existing convention exactly (group `"damageables"` + `damage(impact_point, force)`), so enemies/boxes react exactly as they already do to bullets/melee — no new damage/health system was introduced.

## Commands run and outcomes

- `mcp__godot__get_godot_version` → `4.6.stable.official`.
- `mcp__godot__launch_editor` then waited for `.godot/imported/` to populate (went from 0 to 268 imported files) — this was necessary before the project could run at all (pre-existing issue, not caused by this change).
- `mcp__godot__run_project` (several iterations while implementing) → first run (before import) showed import-cache errors project-wide, unrelated to the new code. After import completed, a run surfaced one warning: a local variable in the new preview script shadowed the `Node3D.position` property — fixed by renaming it. The next clean run produced **zero errors and zero warnings**.

## Manual observations

- Could not interactively press keys/click through the available Godot MCP tools (no input-injection or screenshot tool exposed), so the "Suggested Manual Smoke Test" steps from the spec were not executed by hand in this session. The user/next reviewer should run the game and walk through those 12 steps directly.
- What was confirmed: the project boots to the main scene without any script compile/parse errors, and the scene tree changes (new nodes, new scenes, new signals) resolved cleanly at runtime.

## Known remaining issues / uncertainties

- Because interactive testing wasn't possible via the available tools, the "feel" of the grenade arc, cooldown pacing, and visual proportions (grenade model scale, dot size, landing marker size) have not been eyeballed in a live session — they were chosen based on scene/asset inspection and are exported as tunable values if they need adjusting.
- The landing marker is always drawn flat (facing straight up); it does not tilt to match slanted ground normals. On steep slopes the marker may appear to float slightly above/below the surface, though its position (via a raycast against real geometry) is still accurate.
- The trajectory preview and the thrown grenade share the same launch-velocity formula, but the preview's raycast-based arc simulation and the grenade's actual RigidBody physics (which also accounts for bouncing/rolling) can diverge slightly after the first bounce — the preview line always shows the first-impact point, not subsequent bounces/rolls.
- No dedicated automated tests exist for this project (none existed before this task either); verification relied on static review plus a clean runtime boot.

## Summary of implemented behavior

Players can press `Tab` (or the controller Left Shoulder button) to toggle between the default weapon and a new grenade mode, shown clearly by a HUD icon (bomb vs. flash) that highlights the active weapon. In grenade mode, a cyan dotted arc and landing marker are always visible (dimmed during cooldown) showing where a throw will land; holding aim lets the camera/mouse control both direction and distance, while an unaimed throw uses a stable medium-range forward arc. Pressing attack throws a real physics grenade (no fallback to melee/shooting while in this mode), which flies under gravity, bounces/rolls, and detonates after impact or a fuse — spawning the project's explosion VFX and a sound, and damaging/destroying nearby enemies and boxes via the game's existing damage convention while leaving the player and distant objects unharmed. Switching back to the default weapon hides the aiming aid and restores normal shooting/melee.
