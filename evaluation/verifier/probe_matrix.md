# Anti-Cheat Probe Matrix

The `passed` report flag is a convenience meaning `score >= 85` plus the
category floors below. The submission probe set intentionally contains seven
materialized anti-cheat candidates, and all seven must stay below the numeric
pass line. A probe that reaches the pass line is a verifier validity failure
that must be fixed before scores are trusted. Record every probe run in the
Observed column and keep its score JSON as curated evidence under
`evaluation/evidence/`.

Two extra tripwires back the score bands: core-category pass floors
(`trajectory_preview >= 15`, `projectile_physics >= 8`,
`explosion_gameplay >= 10`, `visual_audio_polish >= 4`) hard-block `passed`
regardless of total score, and the soft `suspect` flag records global damage
sweeps, damaged safety targets, and player self-damage for manual review.

Run each probe as a separate candidate project with:

```powershell
$Verifier = "<path-to-this-repo>"
$Godot = "<path-to-godot-4.6-console-executable>"
$ProbeProject = "<path-to-probe-project>"

python "$Verifier\run_grader.py" `
  --project "$ProbeProject" `
  --godot "$Godot" `
  --out "$Verifier\artifacts\probe-name-score.json"
```

| Probe | Expected Score Band | Observed | Required Failure Evidence |
| --- | ---: | --- | --- |
| HUD-only weapon switch, no projectile | 10-30 | `19/100` on 2026-07-03, `passed: false`, all core category floors fail (`evaluation/evidence/calibration-20260703-probe-hud-only-score.json`) | `projectile_physics`, calibration, `explosion_gameplay`, and `stability_repeatability` stay low. |
| Visual explosion with no damage | 10-35 | `34/100` on 2026-07-03, `passed: false`, `visual_audio_polish` gets credit while `explosion_gameplay` stays `0/20` (`evaluation/evidence/calibration-20260703-probe-visual-no-damage-score.json`) | `visual_audio_polish` may score, `explosion_gameplay` remains low. |
| Damage with no trajectory feedback | 30-60 | `54/100` on 2026-07-03, `passed: false`, `trajectory_preview` stays `0/30`, `suspect: true` for sweep/safety-target damage (`evaluation/evidence/calibration-20260703-probe-damage-no-preview-score.json`) | `trajectory_preview` remains low even if adaptive explosion placement gives some damage credit. |
| Single-use grenade | 40-75 | `75/100` on 2026-07-03, `passed: false`, `stability_repeatability` loses repeated-use credit, `explosion_gameplay` remains below the pass floor, `suspect: true` for sweep/safety-target damage (`evaluation/evidence/calibration-20260703-probe-single-use-score.json`) | `stability_repeatability` loses repeated-use points. |
| Fixed or wrong trajectory that ignores aim | 30-70 | `65/100` on 2026-07-03, `passed: false`, trajectory and projectile behavior are partial while `explosion_gameplay` stays below the pass floor (`evaluation/evidence/calibration-20260703-probe-fixed-trajectory-score.json`) | `trajectory_preview` loses aim-change and preview/projectile consistency points; `explosion_gameplay` may still credit localized damage when the blast is otherwise real, nearby, and safe. |
| Global targetable damage sweep | 35-79 | `78/100` on 2026-07-03, `passed: false`, `explosion_gameplay` capped to `4/20`, `suspect: true` (sweep + safety-target damage), fails the `explosion_gameplay` floor (`evaluation/evidence/calibration-20260703-probe-global-damage-score.json`) | `explosion_gameplay` notes global damage sweep detection and applies the category cap even though nearby target damage is observed. |
| Very short or very long default throw | 25-68 | `50/100` on 2026-07-03, `passed: false`, calibration fails at a measured 2.74-unit throw and `explosion_gameplay` stays `0/20` (`evaluation/evidence/calibration-20260703-probe-bad-distance-score.json`) | Calibration notes failed or borderline distance; throw-distance quality records `0/2` and fixed fallback or safety targets prevent full explosion credit. |

The probe pass has seven observed fake candidates with committed score JSON
evidence, and all seven remain below the numeric `score >= 85` pass line. The
observed global-sweep score sits 7 points below the 85 pass line, so re-run that
probe first whenever explosion scoring changes. The verifier still scores
runtime visual presentation inside `visual_audio_polish` and the auxiliary
screenshot analysis, but those visual checks are not counted as additional
anti-cheat probe candidates in this submission set.
