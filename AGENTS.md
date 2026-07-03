# AGENTS.md

## Project Goal

This repository is a take-home assignment workspace. The goal is not just to
modify the RoboBlast game; the goal is to complete the assignment described in
`game_take_home.html`.

Treat `game_take_home.html` as the source of truth. In short, build an
agent-coding evaluation task for this real Godot game:

- Pick one substantial game element.
- Remove or disable it on a clean ablated task branch.
- Write a behavioral-only spec for the rollout agent.
- Build a deterministic headless verifier that grades attempts out of 100.
- Run coding agents against the ablated task at least 3 times.
- Grade the attempts, analyze failures, and publish a viewable HTML writeup.

The verifier and evaluation process are the main deliverables. A clever game
feature change is less important than an honest, reproducible grader.

## Game Context

- Project: RoboBlast: Third-Person Shooter demo.
- Engine: Godot 4.6. This project is fixed to Godot 4.6; do not change the
  project, verifier, local tooling, or branch setup to any other Godot version
  unless the user explicitly asks. Record the exact Godot 4.6 build and command
  used for verifier runs.
- Main scene: `res://main.tscn`.
- Core gameplay areas:
  - `player/`: controller, camera, weapons, grenades, coins, HUD.
  - `enemies/`: bee and beetle bots, enemy behavior, defeat effects.
  - `box/`: breakable crate behavior.
  - `jumping_pad/`: jump pad behavior and visuals.
  - `environment/`, `level/`, `shared/`: world, materials, shaders, navmesh,
    and shared assets.

## Working Rules

- Keep changes scoped to the assignment step currently being worked on.
- Preserve existing user changes. Do not reset, checkout, or revert unrelated
  files unless explicitly asked.
- Prefer Godot editor or Godot MCP operations for scene/resource changes when
  available. Hand-edit `.tscn` or `.tres` files only when the diff is small and
  you understand the serialization.
- Keep generated Godot sidecar files in sync, especially `.uid` and `.import`
  files, when assets or scripts require them.
- Do not introduce broad refactors while building the eval task. The assignment
  rewards a clean, understandable slice.
- When making any changes to the verifier repository at
  `C:\recent_project\roboblast-grenade-verifier`, also commit those changes in
  that verifier repository.
- Chinese-language documents added or updated after the English source docs,
  including `AGENTS.zh.md`, are personal preview translations for the user.
  Unless the user explicitly asks for them to be committed, do not commit those
  Chinese preview documents.
- Use typed GDScript where practical and follow local style: `@export` for
  tunables, `@onready` for node references, signals for gameplay events, and
  `res://` paths for project resources.

## Assignment Branch Model

Use separate branches or clean worktrees for the major deliverables:

- Original/reference branch: the unablated game used to prove the verifier can
  pass the real behavior.
- Ablated task branch: the exact version given to rollout agents. It should
  contain the feature removed/disabled and the behavioral spec, but not the
  original implementation, verifier, answer hints, or obvious stubs.
- Verifier branch or private verifier workspace: contains the grader and
  anti-cheat probes. Rollout agents must not be able to read this.
- Agent-run branches: one branch per rollout attempt is preferred. Record the
  agent, model/version, tools, prompt/spec, diff, verifier score, and notes.
- Report branch or final deliverable branch: contains the viewable HTML writeup
  and links/evidence for the runs.

Evaluation integrity matters. Before launching a rollout agent, make sure its
workspace cannot access the original solution through git history, other
branches, remotes, verifier files, hidden local files, or an online copy of the
game solution.

## Choosing And Ablating The Task

- Choose a whole behavior or element with enough depth to grade. Good targets
  include combat behavior, enemy behavior, grenade aiming/trajectory, coin
  collection, jump pad behavior, breakable boxes, HUD state, animation, shader,
  VFX, audio, or a visual effect.
- Prefer tasks with an observable visual or gameplay outcome. Visual correctness
  is harder for agents and can help calibrate difficulty.
- The ablation must be complete. Do not leave commented-out source,
  implementation breadcrumbs, renamed original files, or trivial stubs.
- The agent-facing spec must be behavioral only. Describe what the player sees
  or experiences. Do not mention file names, class names, method names, node
  paths, signals, resource paths, or exact implementation details.

## Verifier Requirements

The verifier is the centerpiece of this project.

- It must run headlessly and include the exact command needed to run it.
- It must exercise real game systems rather than checking for a specific code
  shape.
- It must grade out of 100 with meaningful partial credit for separate
  sub-behaviors.
- It must pass the original/reference behavior and fail the ablated version.
- It must be deterministic: control timing, random seeds, test scene setup, and
  camera/viewport assumptions where relevant.
- It must avoid false negatives for valid alternate implementations.
- It must reject near-miss or reward-hacking implementations. Keep anti-cheat
  probes that demonstrate this.
- For visual features, prefer rendered-frame or screenshot-based checks when
  possible, combined with state checks only where state is truly part of the
  player-facing behavior.

A strong verifier should make a strong rollout agent land in a partial-credit
zone, not trivially 100 and not always zero. If agents easily reach 100, make
the task harder or improve the scoring dimensions.

## Running Rollout Agents

- Give the rollout agent only the ablated project and the behavioral spec.
- Do not give it the original implementation, verifier, anti-cheat probes,
  hidden branches, or report notes.
- The assignment requires Claude Code at minimum and at least 3 runs. More
  agents are welcome.
- Give rollout agents Godot MCP access when available so they can inspect and
  run the real project.
- Capture each run's final diff, score, notable behavior, and failure mode.

## Report Requirements

The final report should be a viewable HTML file that opens directly in a
browser with no build step.

Include:

- The chosen feature and why it is a good evaluation task.
- What was ablated and the behavioral spec given to agents.
- The verifier design, scoring rubric, and exact run command.
- Evidence that the verifier passes original and fails ablated.
- Anti-cheat probes and results.
- At least 3 rollout attempts, with diffs/scores/tooling.
- Failure analysis that separates real agent defects from verifier artifacts.
- Visuals such as screenshots, clips, or before/after comparisons where useful.

## Useful Local Checks

Prefer the configured Godot executable or MCP setup for this machine. If Godot
is on PATH, useful smoke checks often look like:

```powershell
godot --headless --path . --quit
godot --headless --path . --script res://path/to/verifier.gd
```

If using the local Codex MCP config, check `.codex/config.toml` for the Godot
binary path and Godot MCP server settings.
