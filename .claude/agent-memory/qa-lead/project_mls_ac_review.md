---
name: Mission & Level Scripting GDD — AC adversarial review
description: Adversarial review of all 50 ACs in design/gdd/mission-level-scripting.md (2026-04-24); 14 BLOCKING findings, 9 RECOMMENDED, 5 NICE-TO-HAVE
type: project
---

**Why:** Shift-left QA gate — ACs must be independently testable before MLS sprint begins. Review conducted 2026-04-24 against 834-line GDD with 50 ACs across 13 groups.

## Critical structural finding (recurring pattern)

Eight ACs (3.1, 3.2, 4.2, 8.3, 10.1, 12.2, 12.3, 12.4) cite `tests/unit/mission/forbidden_patterns_ci_test.gd` as GUT evidence for what are actually CI shell-grep checks. GUT cannot run `grep -r` against the filesystem in isolation per CLAUDE.md unit test rules ("no file I/O"). This is a fictional evidence path. Correct architecture: CI greps belong in `tools/ci/check_forbidden_patterns.sh`, separate from GUT suite.

## BLOCKING gaps (14)

1. AC-MLS-3.3 — untestable; 5-second monitoring window is arbitrary; story type misclassified (should split Visual/Feel for diegetic check)
2. AC-MLS-4.3 — Jolt tunneling not reproducible in GUT headless; rewrite to test disabled-trigger invariant
3. AC-MLS-5.3 — "NPC in post-beat idle state" is Visual/Feel, not Logic; split into 5.3a (Logic) + 5.3b (Visual/Feel)
4. AC-MLS-7.2 — "main-path centerline" and "stealth-required choice point" have no machine-verifiable definition
5. AC-MLS-7.3 — "section midpoint" and "combat-committed zones" have no machine-verifiable definition
6. AC-MLS-9.4 — "documented playtest" has no defined protocol; creates a BLOCKING gate loophole
7. Eight FP-CI ACs using GUT for shell grep (see structural finding above)
8. Events bus mock injection not specified — Logic ACs using Events may silently pass with disconnected signals
9. CR-8 (guard choreography escalation-only) — NO matching AC anywhere in GDD
10. CR-11 (surface tags + surface-tagger CI rule) — NO matching AC
11. F.3 COMBAT exception — no AC tests T6 suppression at COMBAT alert level
12. F.4 overflow path — no AC for slow-but-non-null capture → push_error + proceed
13. F.6 two-section window floor — no AC for consecutive-window constraint (only total cap covered)
14. E.29 (MissionResource load failure) — no AC; significant IDLE-state failure mode

## CR coverage gaps

- CR-8: no AC — BLOCKING
- CR-11: no AC — BLOCKING
- CR-19: no AC — ADVISORY minimum needed

## Regex issues (FP-3, FP-6, FP-7)

- FP-3: `eve.*dialogue` matches `event_handler_dialogue`, `retrieve_dialogue` — missing \beve\b word boundary
- FP-6: scope `save_assembly*` misses FORWARD handler in `mission_scripting_service.gd` itself
- FP-7: alias imports (`var nav = NavigationServer3D`) not caught; grep flavor not specified

## How to apply

When any new GDD has forbidden-pattern enforcement via CI grep:
- Evidence must reference CI shell scripts in `tools/ci/`, NOT GUT test files
- GUT is for behavioral/Logic/Integration tests only
- Events bus tests must specify mock injection strategy in the AC text
- CR coverage matrix must be explicitly verified — it is easy to miss CRs with no AC

Smoke check evidence files in this GDD reference hardcoded date `2026-04-24` — use sprint-relative paths instead.
