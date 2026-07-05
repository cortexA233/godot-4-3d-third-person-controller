---
cover: static/cover.webp
itchio: https://gdquest-demos.itch.io/Godot-4-Character-3D-Demo
tags: 3D third-person-shooter shooter controller
description: "A 3D Third Person Shooter Controller Demo"
---

# RoboBlast: Third-Person Shooter demo (Godot 4, 3D)

## Take-home evaluation submission

This branch is the final viewable submission for the agent-coding evaluation task.

- Report: `evaluation/verifier/evaluation/writeup.html`
- Verifier: `evaluation/verifier/`
- Agent-facing task prompt: `TASK_PROMPT.md`
- Ablated task source branch: `codex/grenade-rollout-task` at `c7893bc`
  (retained rollout evidence was generated from `fb0fd4f`; the later task-branch
  cleanup removed verifier design notes from the public branch, then synced
  reviewer-facing assignment docs and removed personal Chinese preview files)
- Rollout evidence branches:
  - `agent-run/01-cc-sonnet`, `agent-run/02-cc-sonnet`, `agent-run/03-cc-sonnet`
  - `agent-run/01-cc-opus`, `agent-run/02-cc-opus`, `agent-run/03-cc-opus`
  - `agent-run/01-codex`, `agent-run/02-codex`, `agent-run/03-codex`
- Anti-cheat probe branches:
  - `fake/hud-only`, `fake/visual-no-damage`, `fake/damage-no-preview`
  - `fake/single-use`, `fake/fixed-trajectory`, `fake/bad-distance`
  - `codex/grenade-global-enemy-damage`

The verifier also has a standalone GitHub repository at
[cortexA233/godot_task_verifier](https://github.com/cortexA233/godot_task_verifier).
For reviewer convenience, this submission branch includes a direct copy of the
verifier instead of adding it as a Git submodule.

Rollout agents were not run directly from a raw branch checkout. Each agent was
given an exporter-produced, history-stripped clean workspace generated from the
ablated task, with verifier files, local git history, generated artifacts,
assignment notes, and hidden scoring/probe material excluded.

Evaluation-integrity note: the public branch is provided for reviewer
inspection, not as the literal workspace handed to agents. The actual rollout
workspaces were fresh local git repositories initialized after export, so agents
could not inspect the fork's original solution history, task-branch history, or
verifier/probe files.

![](static/third-person-shooter-demo.webp)

This open-source Godot 4 demo shows how to create a 3D character controller inspired by games like Ratchet and Clank or Jak and Daxter. You can copy the character to your project as a plug-and-play asset to prototype 3D games with and build upon.

It features a character that can run, jump, make a melee attack, aim, shoot, and throw grenades.

![](static/third-person-character-aiming-grenade.webp)

There are two kinds of enemies: flying wasps that fire bullets and beetles that attack you on the ground. The environment comes with breakable crates, jumping pads, and coins that move to the player's character.

## How to run:

1. Download or clone the GitHub repository.
2. Press <kbd>F5</kbd> or `Run Project`.

## Controls:

- <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> or <kbd>left stick</kbd> to move.
- <kbd>mouse</kbd> or <kbd>right stick</kbd> to move the camera around.
- <kbd>Space</kbd> or <kbd>Xbox Ⓐ</kbd> to jump.
- <kbd>Left mouse</kbd> or <kbd>Xbox Ⓑ</kbd> to shoot.
- <kbd>Right mouse</kbd> or <kbd>Xbox RT</kbd>to aim.
- <kbd>Tab</kbd> or <kbd>Xbox Ⓧ</kbd> to cycle between bullets and grenades.

## FAQ:

### How do I use the player character in my game?

Copy the following folders into the root of your project:

- `Player`: contains the main Player assets and scenes.
- `shared`: contains shaders used by the player asset.

The following `Input Map` actions are needed for the `Player.tscn` to work:

- `move_left`, `move_right`, `move_up`, `move_down`: move the character according to the camera's orientation.
- `camera_right`, `camera_left`, `camera_up`, `camera_down`: rotate the camera around the character.
- `jump`, `attack`, `aim`, `swap_weapons`: Action buttons for the character.

The `Player.tscn` scene works as a standalone scene and doesn't need other cameras to work. You can change the player UI by changing the `Control` node inside `Player.tscn`.
