# RoboBlast Grenade Eval Deliverables

This branch is the reviewer-facing delivery branch. Do not give this branch to
rollout agents; it intentionally contains the verifier, calibration evidence,
anti-cheat probes, and report.

## Branch Map

- `main`: unablated reference game used to prove the verifier can pass the real
  behavior.
- `codex/grenade-rollout-task`: agent-facing ablated task branch, currently at
  `c7893bc`. This is the branch supplied to rollout agents with the behavioral
  prompt, without the verifier or hidden scoring notes.
- `agent-run/*`: recorded rollout attempts and their branch-local
  evidence.
- `submission/final-deliverable`: this branch, collecting the verifier and report for
  review after rollout runs are complete.

## Reviewer Entry Points

- `report.html`: browser entry point for the HTML writeup.
- `evaluation/verifier/`: self-contained verifier snapshot copied from the
  private verifier workspace. The retained official rollout scores were
  generated from task commit `fb0fd4f` using verifier SHA
  `bfa6d5f060b25b427209c15f95448f03532147ab`; the erroneous earlier Codex score records were discarded and replaced with verifier SHA `ca585a3cbcaaafd77dfe1391dec00d4ca910880f`, including PDF reports and updated score artifacts. This snapshot also includes
  the later materialized probe fixtures used for review.
- `evaluation/verifier/evaluation/evidence/agent-runs-20260703-151656/`: the
  official retained reference, ablated, and rollout-attempt evidence from
  `C:\recent_project\godot-4-3d-third-person-controller-agent-runs-20260703-151656`.
- `evaluation/verifier/evaluation/evidence/probes/`: retained anti-cheat probe
  score JSONs.
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
`codex/grenade-rollout-task` and `TASK_PROMPT.md` only. The retained official
runs were generated from `fb0fd4f`; the public task branch was later advanced to
`ca3c987` to remove a verifier design note from the branch, then to `c7893bc`
to sync reviewer-facing assignment documentation and remove personal Chinese
preview files. The verifier
workspace, reference implementation, hidden branches, calibration artifacts, and
probe notes were kept outside agent-accessible workspaces. The verifier is
copied into this branch only for final review.

