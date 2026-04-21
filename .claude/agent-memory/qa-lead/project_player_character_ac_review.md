---
name: Player Character GDD — AC review findings
description: Two adversarial reviews (2026-04-19 and 2026-04-20) of AC-1 through AC-11 in design/gdd/player-character.md; key gaps and structural issues
type: project
---

**Why:** QA sign-off required before implementation begins (shift-left). ACs must be independently testable before stories enter sprint.

## Review 1 — 2026-04-19 (initial adversarial review)

**BLOCKING gaps found (9 ACs):**
- AC-1.1: no measurement tool; "movement log" undefined
- AC-2.1: "smoothly" unmeasurable; story type conflation (Logic + Visual mixed)
- AC-3.3: "no camera dip" has no threshold — Jolt jitter makes this unverifiable
- AC-3.4: degrees not measurable by QA; story type conflation
- AC-5.1: "test code" undefined, no test file path
- AC-5.4: stub AI interface undefined, integration test location not specified
- AC-6.4: signal counting requires automation but mechanism not stated
- AC-8.2: "no drift" has no numeric tolerance
- AC-9.2: signal rate cap has no measurement method

**Structural issues:**
1. GDD preamble claims all ACs are "testable without developer consultation" — false for at least 9
2. No test file paths named anywhere; no blocking evidence gate for Logic stories
3. No story-type label ([Logic]/[Integration]/[Visual/Feel]) per AC — gate level is ambiguous

## Review 2 — 2026-04-20 (re-review, R-26/R-27 labeling pass verification)

**Preamble claim "implementable-as-worded" is false.** 6+ ACs remain untestable-as-worded. Labeling pass (R-26/R-27) has NOT been completed — only AC-10.1/10.2 carry labels.

**BLOCKING findings (10 ACs after re-review):**
- AC-1.1: "movement log" still undefined — measurement tool must be specified
- AC-2.1: "smoothly" still present — Logic + Visual/Feel must be split into separate ACs
- AC-3.3: "no camera dip" still lacks numeric threshold (≤ X degrees required)
- AC-3.4: camera pitch measurement tool still unspecified; "idempotent-read" is implementation detail not observable behavior
- AC-5.4: 8 consumers at 10 Hz staggered cannot all poll within a 6-frame (0.1s) latch window — logic error in AC setup
- AC-5.5: "within 2 physics frames" has no deterministic setup mechanism in GUT
- AC-6.4: "same physics frame" ambiguous between GUT step and engine tick — must specify "called twice in single GUT step before any _physics_process advance"
- AC-7.2: mouse yaw injection method unspecified; "90 ms settle" has no tolerance band
- AC-8.2: "no drift" / "exactly" still lacks numeric tolerance (suggest ≤ 0.001 m, health int-exact)
- AC-10.1: CI lint rule is a forward-reference to unwritten infrastructure; `setting_changed` category string for "resolution_scale" key unspecified

**RECOMMENDED (5):**
- AC-7.3: tilde prefix (~0.5°, ~0.8 s) is not a tolerance — must be explicit range
- AC-8.1: no tester guidance for verifying `int` vs string in .tres file format
- AC-9.2: 30 Hz rate cap has no measurement procedure (EventLogger not specified)
- AC-11.1: absence-of-feature (stamina) needs explicit verification method (grep + playtest)
- AC-11.3: "dry, short text" is not binary — must define structural rules (word count, forbidden strings)

**Story-type classification (unlabeled ACs):**
- Logic: ~20+ ACs — all require automated unit test in `tests/unit/player_character/` (NO test file paths exist anywhere in the GDD — BLOCKING gate)
- Integration: AC-4.5, AC-6.5, AC-9.2
- Visual/Feel: AC-2.1 (partial), AC-7.2, AC-7.3, AC-7.4, AC-10.2
- UI: AC-11.3
- Config/Data: AC-11.1, AC-11.2

**What was cleared since Review 1:**
- AC-3.4: tolerance (4–6°) and duration (150 ms) now present — improvement; measurement tool still missing
- AC-7.2: ±0.5° tolerance now present — improvement; injection method and settle tolerance still missing
- `setting_changed` reference in AC-10.1: IS in ADR-0002 Settings domain — not a forward-reference error (cleared)
- AC-5.1 concern about "test code": partially addressed by explicit API names in AC-5.1 text

**How to apply:** When reviewing any future GDD's AC section, check for: undefined tools, story-type conflation, missing test file paths, proving-a-negative without measurable threshold, subjective adjectives ("smoothly", "dry") without benchmark, impossible test setups (physics-frame guarantees), and forward-references to unwritten infrastructure.
