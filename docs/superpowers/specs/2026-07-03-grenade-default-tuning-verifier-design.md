# Grenade Default Tuning And Verifier Robustness Design

Date: 2026-07-03

## Goal

Reduce false negatives in the RoboBlast grenade benchmark when an otherwise valid
grenade implementation uses default throw distance, fuse timing, or explosion
radius values that do not exactly match the verifier arena.

The goal is not to make a configurable grenade API the central assignment. The
goal is to make the task prompt and verifier agree on a broad default gameplay
envelope so agents are graded on player-facing behavior instead of hidden tuning
constants.

## Current Problem

The current task prompt asks for arcing grenade throws, trajectory feedback,
nearby target damage, distant target safety, and repeatability. It does not say
what default combat range the grenade should cover.

The verifier can place targets at fixed distances. If those distances are too
narrow, a reasonable implementation can miss the target group and lose explosion
or repeatability credit even though the grenade behavior is mostly correct. This
turns the grader into a hidden tuning test rather than a behavioral test.

## Non-Goals

- Do not require a specific file name, node path, exported property, resource
  type, class name, or method name for grenade tuning.
- Do not require the verifier to mutate candidate configuration as the primary
  scoring mechanism.
- Do not reveal exact hidden verifier target positions in the task prompt.
- Do not give high credit to implementations that globally damage targets,
  teleport damage to the arena, or hard-code one target layout.

## Task Prompt Design

Add a short "Gameplay Tuning Expectations" section to the agent-facing task
prompt. It should describe expected default behavior in player-facing language:

- A default throw should be useful at ordinary third-person combat range, not
  only at point-blank range and not only at very long range.
- On flat ground, when the player faces a target area and attacks in grenade
  mode without holding aim, the grenade should land in a medium-distance area in
  front of the player, roughly 6-12 Godot units away.
- The explosion should affect targets within a few units of the detonation
  point, while clearly separated distant, side, rear, and player targets remain
  safe. Targets well over ten units from the detonation point should not be
  affected.
- Cooldown and fuse timing should allow repeated throws to be observed in a
  normal test window without producing an uncontrolled stream of grenades.
- Implementations may expose tuning values for throw range, explosion radius,
  cooldown, fuse, or gravity, but this is optional unless needed to keep the
  gameplay stable and maintainable.

The prompt may use approximate player-facing numeric ranges to remove ambiguity,
but it should not mirror hidden trial coordinates or describe verifier internals.

## Verifier Design

The verifier should not rely on one target distance. It should grade grenade
gameplay across a small deterministic matrix of arena trials.

Before the formal explosion trials, the verifier should run a calibration throw:

- Build a fresh arena with the player but without positive damage targets in the
  intended landing path.
- Switch to grenade mode through real input and throw once.
- Collect newly spawned nearby Node3D candidates and track their positions until
  invalidation, detonation/cleanup, or a fixed timeout.
- Accept a calibration candidate only if it spawns near the player, shows arcing
  motion, and keeps a player-safe path.
- Estimate the default throw distance `d` from the best available landing or
  detonation proxy: the final tracked projectile position, or the position of a
  visible detonation/effect node near the end of the flight if available.
- Treat `d` in roughly 6-12 units as the full-confidence default envelope, `d`
  in 4-14 units as usable but borderline, and values outside that band or
  missing calibration data as a calibration failure.
- Rebuild the arena after calibration so cooldowns, one-shot state, temporary
  nodes, and damage state do not leak into formal scoring.

Each explosion trial should:

- Build a fresh arena and player instance.
- Place positive targets along the trial heading. If calibration succeeded, use
  the calibrated throw distance `d`; otherwise use the existing fixed fallback
  geometry.
- Place a nearby cluster with modest side offsets around the expected detonation
  region.
- Place safety targets clearly outside the expected effect envelope, including
  farther forward, wide side offsets, behind the player, and the player body.
  The far target should remain distant from the expected blast, for example at
  least `max(20, d + 12)` units from the player when calibration is available.
- Switch to grenade mode through real input.
- Throw one grenade and observe flight, detonation, damage calls, visible
  effects, player safety, and cleanup.
- Repeat selected trials after cooldown to catch one-shot or leaking behavior.

The verifier should aggregate behavior rather than require an exact impact
point. For example, it can credit damage if at least one medium-distance target
is affected and give additional credit when a nearby cluster is affected. It
should penalize damage to far, side, rear, or player safety targets.

The calibrated distance should be reused across the deterministic heading trials
for a single verifier run. Targets are still placed along each trial heading, so
fixed-direction or non-aim-responsive implementations should fail rotated
trials. Safety target distance must not be scaled up to match an oversized
explosion radius; broad damage should continue to lose safety credit.

## Scoring Shape

Keep the existing 100-point rubric, but make the explosion and repeatability
subscores robust to tuning variation:

- Nearby target damage should be averaged across trials or awarded by hit rate
  within the medium-range envelope.
- Calibration should be reported as notes, not as a hidden hard gate. A
  full-confidence `d` can use adaptive placement normally; a borderline `d` can
  still run adaptive placement while noting default tuning risk; missing or
  out-of-band calibration should fall back to fixed geometry.
- Out-of-range safety should remain strict: broad global damage or excessive
  radius should lose safety credit.
- Repeatability should use more than one throw and should rebuild or reset
  state between independent scoring categories.
- Projectile and trajectory scoring should still check arcing motion and aim
  response, not just final damage.

Optional configuration can be rewarded only as a small maintainability signal if
it is directly observable through behavior. The verifier should not require a
specific configuration interface to pass the core task.

## Calibration Requirements

Before using the verifier for rollout attempts:

- The original reference implementation should score high across the distance
  matrix.
- The ablated branch should still score low.
- Anti-cheat probes should remain caught, especially global damage, fixed
  non-aimed trajectory, visual-only explosion, damage-only no projectile, and
  single-use grenade implementations.
- Running the same candidate multiple times should produce stable scores.
- Score notes should distinguish "no grenade behavior" from "grenade exists but
  default tuning only reaches part of the target envelope."

## Risks And Mitigations

Risk: The prompt leaks too much about hidden arena distances.
Mitigation: Use broad gameplay envelope language in the prompt and keep exact
trial positions hidden in the verifier.

Risk: A distance matrix becomes too permissive and accepts random or global
damage.
Mitigation: Pair every positive target set with far, side, rear, and player
safety targets, and score safety separately.

Risk: Calibration tracks the wrong node or treats a visual-only helper as the
projectile.
Mitigation: Accept calibration candidates only when they spawn near the player,
move through an arc, travel a meaningful horizontal distance, and keep a
player-safe path. If no candidate passes, fall back to fixed geometry.

Risk: The final tracked projectile point is not the true landing point because
the grenade bounces, rolls, hides, or detonates after cleanup.
Mitigation: Prefer detonation or visible effect position near the end of flight
when available, otherwise use the final tracked projectile position as an
approximate distance. Keep broad tolerances and report the calibration distance
in grader notes.

Risk: Calibration adapts too much to poor default tuning.
Mitigation: Use full, borderline, and failed calibration bands. A very short,
very long, or unmeasurable throw should not silently receive ideal target
placement.

Risk: A target-snapping implementation behaves differently when formal trials
contain targets than it did in the target-free calibration throw.
Mitigation: Treat this as valid gameplay as long as formal trials still show
arcing flight, aim response, localized damage, and safety behavior. Safety
targets remain the guard against snapping or damaging too broadly.

Risk: Valid implementations without exposed tuning lose points.
Mitigation: Do not require configuration mutation for core scoring. Score
observed behavior under reasonable default conditions.

Risk: Runtime configuration changes do not propagate through cached state.
Mitigation: Prefer fresh arena/player instances for independent trials. If a
future verifier probes optional tuning, reinstantiate the candidate scene after
changing values.

Risk: Original/reference behavior and task prompt expectations diverge.
Mitigation: Calibrate the hidden trial distances against the reference branch
and record the chosen envelope in verifier documentation, not in the rollout
prompt.

## Acceptance Criteria

- The task prompt communicates a default grenade combat envelope without naming
  verifier implementation details.
- The verifier uses multiple deterministic target distances and angles instead
  of a single exact target position, with adaptive target placement based on a
  validated calibration throw when available.
- Scoring rewards stable medium-range grenade behavior and penalizes global or
  overly broad damage.
- Valid implementations are not forced to expose a specific configuration API.
- Verifier notes make tuning-related misses diagnosable without revealing hidden
  probes to rollout agents.
