# Grenade Weapon Benchmark Verifier Design

Date: 2026-07-02

## Purpose

This spec designs a deterministic benchmark verifier for an agent-coding task in RoboBlast. The rollout agent is asked to implement a new grenade weapon feature as if the game never had one. The verifier grades the candidate implementation out of 100 points by running the game's real systems and checking observable behavior.

The verifier must not grade against a historical code shape. It should not require specific file names, class names, node paths, signals, or method names. Correct alternative implementations should be able to score well if the player-facing behavior is right.

## Target Task Scope

The ablated task branch is `codex/ablate-grenade-keep-assets`. It removes the grenade gameplay wiring and behavior while leaving grenade, explosion, icon, sound, and related visual assets available. The task given to rollout agents should describe a new grenade weapon in behavioral terms only.

The player-facing behavior to grade:

- The player can switch between the default weapon and grenade mode with `Tab` or the controller weapon-switch input.
- In grenade mode, attacking throws a grenade instead of firing or melee attacking.
- Aiming with the grenade selected provides visible trajectory and landing feedback.
- The grenade travels through the world as a physical arcing projectile.
- The grenade detonates after impact or a short delay.
- The explosion affects nearby enemies and breakable targets, but does not damage the player.
- HUD, visuals, audio, cleanup, and repeated use are coherent.
- Existing default shooting, aiming, and melee behavior are not broken.

## Architecture

Use a hybrid verifier:

- A Python CLI lives outside the rollout agent's workspace.
- At grading time, the Python runner creates a temporary copy of the candidate project.
- The runner injects a hidden Godot verifier folder into the temporary project.
- The runner starts Godot in headless mode with the injected verifier script.
- The Godot verifier loads a small deterministic test arena instead of the full main level.
- The arena uses real game systems wherever possible: the candidate player, real physics, input actions, timers, collisions, damageable targets, HUD nodes, and visual nodes.
- Godot writes a machine-readable JSON result; Python collects the JSON, logs, and evidence artifacts.

This keeps the grader and probes out of the agent's working copy while still evaluating real runtime behavior inside Godot.

## Scoring Rubric

Total score: 100 points.

| Category | Points | What It Measures |
| --- | ---: | --- |
| Weapon availability and controls | 15 | The player can switch between default weapon and grenade mode; default attack still works; grenade attacks only happen in grenade mode; cooldown prevents spam. |
| HUD and player feedback | 15 | Weapon UI shows both options, selected state changes correctly, grenade mode is clear, and aim reticle/camera behavior remains coherent. |
| Aiming and trajectory preview | 20 | Grenade mode shows a visible arc/path preview, preview updates with aim direction, landing feedback appears near the intended target, and preview hides outside grenade mode. |
| Projectile launch and physics | 15 | Attack spawns a grenade-like projectile near the player, it follows a gravity-shaped arc, collides/bounces or lands plausibly, and does not immediately hit the player. |
| Explosion and gameplay effect | 20 | The grenade detonates after impact or delay, damages nearby enemies or boxes, leaves distant targets unaffected, avoids player damage, and can affect multiple nearby targets. |
| Visual and audio polish | 10 | A visible grenade model or equivalent appears, explosion VFX appears at the detonation point, explosion sound plays, and temporary effects clean themselves up. |
| Stability and repeatability | 5 | No script errors, no runaway nodes or timers, repeated throws work, and default shooting/aiming still behave. |

The rubric intentionally gives partial credit. A simple "throw and explode" solution can earn some points, but a high score requires HUD, trajectory, target feedback, VFX/audio, regression safety, and repeatability.

## Test Arena

The verifier injects a deterministic arena with simple ground, controlled target placement, a player spawn, camera/input driver, and runtime probes.

The planned test groups:

- **Load smoke test:** load the candidate player and required scenes; fail gracefully if the project or scene cannot load.
- **Weapon switching test:** simulate the weapon-switch input and observe player-facing state changes through HUD, attack behavior, and default-weapon regression.
- **Trajectory preview test:** enter grenade mode, aim at fixed positions, and check for visible trajectory or landing feedback that moves with aim and hides outside grenade mode.
- **Projectile physics test:** simulate attack, detect the spawned grenade-like projectile, record positions over physics frames, and verify arcing motion and player collision safety.
- **Explosion damage test:** place nearby and distant damageable targets, throw toward the target cluster, and check area damage, unaffected distant targets, and no player damage.
- **Visual/audio test:** at detonation, check that visible explosion geometry or particles appear near the detonation point, an audio player triggers, and temporary nodes clean up.
- **Repeatability test:** execute multiple throws with cooldown spacing and ensure the second throw works without stale state from the first.

The tests should use tolerances for position, timing, radius, and trajectory shape. They should avoid requiring exact historical values.

## Anti-Cheat And Robustness Strategy

The verifier should reject shallow or reward-hacking implementations without false-negativing valid alternate implementations.

Design choices:

- Run parameterized variants with different target positions, distances, enemy counts, and player orientations.
- Place positive and negative targets together: nearby targets should be affected, distant targets should not, and the player should not be damaged.
- Check the process as well as the final state: trajectory feedback, projectile flight, detonation point, area effect, and cleanup all matter.
- Repeat throws to catch one-shot scripts, broken cooldowns, or leaked state.
- Include default-weapon regression tests so grenade work cannot break existing combat.
- Use behavioral tolerances instead of exact historical constants.
- Keep verifier files, probes, original implementation, hidden branches, and git history out of the rollout agent workspace.

Planned anti-cheat probe branches:

- HUD-only implementation with no projectile.
- Attack directly damages all targets without projectile flight.
- Visual explosion appears but no damage occurs.
- Damage occurs but no trajectory or landing feedback appears.
- Projectile can be thrown only once.
- Grenade damages the player.
- Fixed trajectory that does not follow aim.
- Explosion affects distant targets outside the expected area.
- Grenade mode breaks default shooting after switching back.

Each probe should receive only the relevant partial credit, not a high score.

## Output Format

The runner emits a JSON result and a short console summary. Functional incompleteness should produce a low score, not a grader crash.

Example JSON shape:

```json
{
  "score": 73,
  "max_score": 100,
  "passed": false,
  "godot_version": "4.7.stable.mono.official.5b4e0cb0f",
  "breakdown": [
    {
      "name": "weapon_controls",
      "score": 12,
      "max": 15,
      "notes": "Switching works but cooldown behavior is incomplete."
    }
  ],
  "artifacts": {
    "log": "artifacts/run.log",
    "screenshots": [
      "artifacts/trajectory.png",
      "artifacts/explosion.png"
    ]
  }
}
```

The `passed` field is a convenience threshold marker, not a replacement for the score. A reasonable threshold can be selected later for reporting, but the benchmark should emphasize the 0-100 breakdown.

## Run Command

The intended command shape:

```powershell
python verifier/run_grader.py `
  --project C:\path\to\candidate-project `
  --godot "C:\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe" `
  --out artifacts\score.json
```

The local Godot executable currently identified for this workspace is:

```text
C:\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe
```

The verified local version is:

```text
4.7.stable.mono.official.5b4e0cb0f
```

The assignment text mentions Godot 4.6, so final reporting must record the exact Godot version used.

## Validation Gates

Before using the verifier on rollout attempts, it must be calibrated with these checks:

- The original/reference behavior scores near 100.
- The ablated task branch scores low and clearly fails the core behavior.
- Each anti-cheat probe is caught and receives only appropriate partial credit.
- Running the same candidate multiple times produces stable scores.
- A correct solution with different internal structure is not rejected for missing historical names or paths.

## Open Implementation Notes

Implementation details are intentionally deferred to the implementation plan. Likely components are:

- `verifier/run_grader.py` for orchestration.
- An injected Godot verifier folder containing the arena scene, test runner, input driver, probes, and JSON writer.
- Artifacts for logs and optional screenshots.

The implementation plan should decide exact file locations and Godot script APIs after this design is approved.
