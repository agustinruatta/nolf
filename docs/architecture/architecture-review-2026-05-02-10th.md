# Architecture Review Report (10th run)

| Field | Value |
|-------|-------|
| **Date** | 2026-05-02 (tenth run — delta against same-day ninth-run PASS baseline) |
| **Mode** | `/architecture-review` (focused-delta — Sprint 05 close + 4 queued advisories) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) — engine-reference unchanged this window |
| **GDDs Reviewed** | 24 (unchanged since 9th run; no GDD authored in this window) |
| **ADRs Reviewed** | 8 (unchanged; no new ADRs, no status promotions) |
| **TR Registry State** | 348 active TRs (unchanged; TR-SAI-005 text-only revision applied this run) |
| **Prior Review** | `architecture-review-2026-05-02.md` (9th — PASS with 3 doc-hygiene advisories applied) |
| **Verdict** | **PASS** (with 4 advisories: A1 fixed; A2/A3/A4 surfaced as informational, no action this run) |

---

## Summary

This is a focused-delta verification covering the ground between the 9th-run
PASS (same morning) and the close of Sprint 05 ("Mission Loop & Persistence")
later the same day. Sprint 05 added **14 stories across 3 epics** (3 SL tail,
6 FR, 5 MLS), introducing ~18 new files of production code in
`src/gameplay/failure_respawn/`, `src/gameplay/mission_level_scripting/`, and
extensions to `src/core/save_load/`. Test suite grew **725 → 863** (+138 new
tests) with 5 known-flaky pre-existing failures (player_interact_cap_warning,
level_streaming_swap — large-suite test pollution, pass in isolation).

**No architectural drift detected.** All Sprint 05 code maps to TRs that were
already registered before the sprint began (TR-FR-001..014, TR-MLS-001..019,
plus existing Save/Load TRs). The fr_autosaving_on_respawn forbidden pattern
was added to the architecture registry on the same day under ADR-0003 anchor.
No new ADRs are required.

The 4 queued advisories from the Sprint 04 close-out have been triaged:

- **A1 ✅ Fixed**: TR-SAI-005 registry text was stale (5 AlertCause values vs
  the 7 in `design/gdd/stealth-ai.md` L69 + the 7 in
  `src/gameplay/stealth/stealth_ai.gd:49`). Registry text revised this run.
- **A2 — Informational only**: GDScript `@abstract func` body-less form vs
  `pass`-bodied form — both forms are valid in Godot 4.5+; reference doc
  `current-best-practices.md` shows the `pass` form, implementation in
  `raycast_provider.gd` uses the body-less form. Convention drift only —
  body-less is *more* explicit. No fix; project may decide canonical form
  later.
- **A3 — Informational only**: `_compute_severity` underscore prefix in
  `src/gameplay/stealth/stealth_ai.gd` — GDScript convention reserves `_method`
  for private; story SAI-005 specifies the underscore prefix and was
  implementation-authoritative per code review. Documented in story
  Completion Notes; no architectural impact.
- **A4 — Informational only**: `stealth_alert_audio_subscriber.gd` location
  workaround — placed at `src/gameplay/stealth/` instead of inside
  `src/audio/audio_manager.gd` extension because `src/audio/` is owned by the
  `vdx` user and is group-read-only from the `agu` session. Documented in
  Sprint 04 close-out as a "post-VS Audio rewrite migrates SAI-domain logic
  into AudioManager._on_actor_became_alerted (currently a deferred stub)."
  Same permission pattern surfaced again this session against
  `tests/integration/level_streaming/` and
  `tests/unit/core/player_character/player_interact_cap_warning_test.gd` —
  see Section "Permission constraint" below.

---

## Traceability Summary

| | Prior 9th run (2026-05-02 morning) | This 10th run | Δ |
|---|---|---|---|
| Total TRs | 348 | 348 | 0 |
| ✅ Covered | ~344 | ~344 | 0 |
| ⚠️ Partial | ~3 | ~3 | 0 |
| ❌ Hard Gap | 0 | 0 | 0 |
| Doc-hygiene advisories applied | D1+D2+D3 | A1 | n/a |

`TR-SAI-005` text revised in-place to match the 7-value enum reality (`HEARD_NOISE | SAW_PLAYER | SAW_BODY | HEARD_GUNFIRE | ALERTED_BY_OTHER | SCRIPTED | CURIOSITY_BAIT`). ID unchanged. `revised: 2026-05-02` field set per registry conventions.

### Sprint 05 code → TR mapping spot-check

| Sprint 05 file | TR(s) addressed | ADR governing | Status |
|---|---|---|---|
| `src/gameplay/failure_respawn/failure_respawn_service.gd` | TR-FR-001..014 | ADR-0007 (autoload) + ADR-0003 (save lifecycle) | ✅ |
| `src/gameplay/failure_respawn/checkpoint.gd` (Resource) | TR-FR-007 (checkpoint capture) | ADR-0003 §sub-resource registration | ✅ |
| `src/gameplay/mission_level_scripting/mission_level_scripting.gd` | TR-MLS-001..019 | ADR-0007 (autoload load order) + ADR-0003 (assembler chain) | ✅ |
| `src/gameplay/mission_level_scripting/mission_objective.gd` | TR-MLS-009..012 (objective state machine) | ADR-0002 (Mission-domain signals) | ✅ |
| `src/gameplay/mission_level_scripting/mission_resource.gd` | TR-MLS-005..006 (mission asset spec) | ADR-0003 (Resource serialization contract) | ✅ |
| `src/core/save_load/quicksave_input_handler.gd` | TR-SL (quicksave gate) — covered by SaveLoad TRs | ADR-0004 IG13 (push/pop authority) + ADR-0007 | ✅ |
| `src/core/save_load/save_load_service.gd` (state machine extension) | SL-008 sequential queueing | ADR-0003 atomic-write contract | ✅ |
| `src/core/save_load/states/{mission,failure_respawn,civilian_ai,document_collection,inventory,player,stealth_ai}_state.gd` | Per-domain state Resources | ADR-0003 (sub-resource registration) | ✅ |

All 18 Sprint 05 production files are governed by Accepted ADRs. No new TRs
were introduced (the 14 stories all consumed pre-registered TRs). No new
forbidden patterns surfaced from implementation review beyond the
fr_autosaving_on_respawn already added to `docs/registry/architecture.yaml`
this same session.

---

## Cross-ADR Conflict Detection

**Clean.** Same as 9th run.

No new ADRs in this window. No status changes. No edits to ADR decision text,
key interfaces, or integration contracts. Vulkan-only state from the
2026-04-30 sweep preserved.

`grep -rn "D3D12\|d3d12" docs/architecture/ design/gdd/ project.godot` →
identical to 9th run (Revision History annotations only).

### ADR Dependency Order

Unchanged from 9th run. All 8 ADRs at terminal-or-deferred-only state (7/8
Accepted; ADR-0004 Effectively-Accepted pending Gate 5 BBCode→AccessKit AT
runner). Topological order is the same; Sprint 05 code respects it.

---

## Engine Compatibility Audit

**Clean.** Same as 9th run.

- No new post-cutoff API surface introduced this window. Sprint 05 code uses
  only stable APIs (`Resource.duplicate(true)`, `Callable`,
  `ConfigFile.load/save`, `Engine.get_process_frames`,
  `Time.get_ticks_usec`, `OS.is_debug_build`, `push_warning`/`push_error`,
  `Array[Callable]`, signal connection patterns, autoload patterns).
  All stable since Godot 4.0.
- No deprecated APIs referenced by any Sprint 05 file.
- No version drift; `docs/engine-reference/godot/VERSION.md` unchanged.
- No GDD revision flags — no engine reality contradicts any Sprint 05 GDD
  assumption.

### A2 — `@abstract func` body-less form (informational, no fix)

`docs/engine-reference/godot/current-best-practices.md` L18-25 shows the
`@abstract func ... -> Type: pass` body-bearing form. Sprint 04 implementation
in `src/gameplay/stealth/raycast_provider.gd:32` uses the body-less form
(`@abstract func cast(query: ...) -> Dictionary`). **Both are valid GDScript
4.5+** — Godot's parser accepts either. The body-less form is *more* explicit
about "no implementation here" (the `pass` body is purely syntactic, not
semantic). Reference doc could be updated to show both, but no action required
this run; not a blocker.

### Engine Specialist Consultation

**Skipped this run.** Focused-delta scope: no new APIs, no new ADRs,
no engine-version delta, no ADR with engine-specific decisions changed.
9th run included a specialist consultation that closed the window's
engine concerns; nothing new for the specialist to validate.

---

## Phase 5b — GDD Revision Flags

**None.** No engine reality contradicts any GDD assumption introduced or
referenced this window.

---

## Phase 6 — Architecture Document Coverage

`docs/architecture/architecture.md` was updated in the 9th run (D1 fix —
8 surgical edits flipping stale "all-Proposed" claims to current 7/8-Accepted
+ 1/8-Effectively-Accepted state). Sprint 05's 14 stories did not touch
architecture.md; the file's last-updated stamp remains 2026-05-02 from the
9th run. No new layer/system additions required from Sprint 05 code (FR + MLS
were already mapped in the architecture layer diagram).

---

## Permission constraint (operational note)

This session re-encountered the same `vdx`-user-owned-directory pattern that
A4 documents for `src/audio/`. Files / directories the current `agu` session
cannot write to:

- `tests/integration/level_streaming/` (and its `level_streaming_swap_test.gd`)
- `tests/unit/core/player_character/player_interact_cap_warning_test.gd`
- `tests/integration/feature/` directory tree
- `tests/integration/outline_pipeline/`
- `tests/unit/core/footstep_component/`
- `tests/ci/` and `tests/reference_scenes/`
- Several `*_test.gd` files in `tests/unit/core/player_character/` (mixed
  ownership — some `agu`, some `vdx`)
- `scenes/sections/plaza.tscn` (re-confirmed from Sprint 05 close-out)

The flaky-test fix (drain InputContext stack in `before_test()`) was prepared
this session for both `level_streaming_swap_test.gd` and
`player_interact_cap_warning_test.gd` but **could not be applied** because
both files are `vdx:agu` rw-r--r--. The pattern fix is verified — root cause
for `level_streaming_swap_test.gd` is line-62 assertion that `LOADING` is
inactive at test start, which fails when a prior test left `LOADING` on the
stack. User intervention (chmod or sudo-edit) required to land the fix.

**Architectural impact: zero.** The flakiness is a test-isolation issue, not
a production bug; the affected tests pass in isolation.

---

## Verdict: **PASS**

Sprint 05 architectural posture matches the 9th-run baseline. No new
structural blockers for `/gate-check pre-production`. The 4 queued advisories
are triaged and either fixed (A1) or formally classified as informational
(A2/A3/A4). The fr_autosaving_on_respawn forbidden pattern is now in the
architecture registry with full description + ADR-0003 anchor.

### Blocking Issues
None.

### Required ADRs
None this run. The architectural foundation remains complete. ADR-0004 Gate 5
(BBCode→AccessKit AT runner) is the only ADR-side action remaining; it is
gated by a Sprint 06 production story (Settings & Accessibility), not by
this review.

### Files Modified This Run

- `docs/architecture/tr-registry.yaml` — TR-SAI-005 requirement text revised
  (5 → 7 enum values to match GDD + impl); `revised: 2026-05-02` field set;
  header `last_updated` will be bumped to current state on next registry
  edit (left at 9th-run timestamp this run because no new TRs were added —
  only one existing TR's text was revised).
- `docs/registry/architecture.yaml` — fr_autosaving_on_respawn entry appended
  (separate session task, completed before this review).

### Files Written This Run

- This file: `docs/architecture/architecture-review-2026-05-02-10th.md`

### Reflexion Log

No 🔴 CONFLICT entries this run (advisories are informational; below
conflict-tracking threshold). `docs/consistency-failures.md` (if it exists)
is not appended this session.

---

## Handoff

1. **Immediate actions**: None for the architecture layer. Sprint 06 (UI
   Shell — HUD + Settings) can begin per the multi-sprint roadmap. The
   ADR-0004 Gate 5 closure is the natural Sprint 06 architectural touchpoint.
2. **Gate guidance**: `/gate-check pre-production` remains expected to PASS
   if run now; nothing in Sprint 05 changes the pre-production posture.
3. **Rerun trigger**: re-run `/architecture-review` after Sprint 06 close
   (HUD + Settings + LOC) to verify ADR-0004 Gate 5 closure and surface any
   new TRs from settings-accessibility code.
4. **Permission lift**: surface the `vdx`-owned-files list to the user so the
   flaky-test fix and any future `src/audio/` rewrites can be unblocked.
