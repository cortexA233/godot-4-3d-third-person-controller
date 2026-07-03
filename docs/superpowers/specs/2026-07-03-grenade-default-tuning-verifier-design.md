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
  mode, the grenade should reliably threaten a medium-distance target area in
  front of the player.
- The explosion should affect a small nearby cluster of targets, while clearly
  separated distant, side, rear, and player targets remain safe.
- Cooldown and fuse timing should allow repeated throws to be observed in a
  normal test window without producing an uncontrolled stream of grenades.
- Implementations may expose tuning values for throw range, explosion radius,
  cooldown, fuse, or gravity, but this is optional unless needed to keep the
  gameplay stable and maintainable.

The prompt should avoid exact verifier distances. It can provide approximate
language such as "medium-distance" and "nearby cluster" rather than a single
number the agent can overfit.

## Verifier Design

The verifier should not rely on one target distance. It should grade grenade
gameplay across a small deterministic matrix of arena trials.

Each explosion trial should:

- Build a fresh arena and player instance.
- Place positive targets at multiple reasonable forward distances and modest
  side offsets.
- Place safety targets clearly outside the expected effect envelope, including
  farther forward, wide side offsets, behind the player, and the player body.
- Switch to grenade mode through real input.
- Throw one grenade and observe flight, detonation, damage calls, visible
  effects, player safety, and cleanup.
- Repeat selected trials after cooldown to catch one-shot or leaking behavior.

The verifier should aggregate behavior rather than require an exact impact
point. For example, it can credit damage if at least one medium-distance target
is affected and give additional credit when a nearby cluster is affected. It
should penalize damage to far, side, rear, or player safety targets.

## Scoring Shape

Keep the existing 100-point rubric, but make the explosion and repeatability
subscores robust to tuning variation:

- Nearby target damage should be averaged across trials or awarded by hit rate
  within the medium-range envelope.
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
  of a single exact target position.
- Scoring rewards stable medium-range grenade behavior and penalizes global or
  overly broad damage.
- Valid implementations are not forced to expose a specific configuration API.
- Verifier notes make tuning-related misses diagnosable without revealing hidden
  probes to rollout agents.
