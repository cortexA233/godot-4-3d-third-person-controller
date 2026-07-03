# RoboBlast Grenade Eval Deliverables

This branch is the reviewer-facing delivery branch. Do not give this branch to
rollout agents; it intentionally contains the verifier, calibration evidence,
anti-cheat probes, and report.

## Branch Map

- `main`: unablated reference game used to prove the verifier can pass the real
  behavior.
- `codex/grenade-rollout-task`: agent-facing ablated task branch. This is the
  branch supplied to rollout agents with the behavioral prompt, without the
  verifier or hidden scoring notes.
- `codex/agent-run-*`: recorded rollout attempts and their branch-local
  evidence.
- `codex/final-deliverable`: this branch, collecting the verifier and report for
  review after rollout runs are complete.

## Reviewer Entry Points

- `report.html`: browser entry point for the HTML writeup.
- `evaluation/verifier/`: self-contained verifier snapshot copied from the
  private verifier workspace at commit `950e626`.
- `evaluation/verifier/evaluation/evidence/`: curated score JSONs for the
  reference, ablated task, rollout attempts, and anti-cheat probes.
- `evaluation/verifier/evaluation/probes/`: materialized fake near-miss
  solutions used to check reward-hacking resistance.
- `evaluation/verifier/BENCHMARK.md`: benchmark objective, protocol, scoring,
  reproducibility notes, and validity-probe expectations.

## Verifier Command

From this repository root, run:

```powershell
python .\evaluation\verifier\run_grader.py `
  --project C:\path\to\candidate-project `
  --godot "C:\Godot_v4.6\Godot_v4.6-stable_win64_console.exe" `
  --out .\evaluation\verifier\artifacts\score.json
```

The exact Godot build recorded during calibration was
`4.6.stable.official.89cea1439`, using
`C:\Godot_v4.6\Godot_v4.6-stable_win64_console.exe`.

## Integrity Note

During rollout, agents received a git-stripped copy of
`codex/grenade-rollout-task` and `TASK_PROMPT.md` only. The verifier workspace,
reference implementation, hidden branches, calibration artifacts, and probe
notes were kept outside agent-accessible workspaces. The verifier is copied into
this branch only for final review.
