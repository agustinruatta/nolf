# Architecture Review Report

| Field | Value |
|-------|-------|
| **Date** | 2026-04-29 (seventh run — post-`/review-all-gdds` 2026-04-28 + 11 new MVP/VS GDDs + 3 ADR amendments + uncommitted ADR-0002 Cutscenes amendment) |
| **Mode** | `/architecture-review` (full mode, delta-verification since sixth 2026-04-27 run) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **GDDs Reviewed** | **23 / 23** — all MVP + VS systems designed (11 NEW since prior 2026-04-24/27 baseline) |
| **ADRs Reviewed** | 8 (ADR-0002 amended 3× since baseline; ADR-0003 / ADR-0004 / ADR-0007 / ADR-0008 each amended once) |
| **TR Registry State on Entry** | 175 active TRs |
| **TR Registry State after Run** | **348 active TRs** (+173 net new) |
| **Prior Reviews** | `architecture-review-2026-04-27-document-overlay-ui.md` (sixth — change-impact only); `architecture-review-2026-04-24.md` (fifth full review, PASS) |
| **Verdict** | **PASS** (re-affirmed) |

---

## Summary

This is the architecture review's first multi-system delta since the 2026-04-24
baseline. Eleven new system GDDs landed, completing the design phase
(**23/23 systems designed**). The `/review-all-gdds` 2026-04-28 cross-review
identified 9 BLOCKING items requiring 3 ADR amendments and 6 GDD sweeps; **all 9
are confirmed RESOLVED** by grep before this review opened.

**Architectural changes since 2026-04-24** (chronological):

1. **2026-04-27 evening — `/propagate-design-change` (Document Overlay UI)**:
   ADR-0004 Amendment **A5** applied in-place (Theme `base_theme` → `fallback_theme`
   per Godot 4.6 verified property; Gate count 3 → 5). Preserved core architectural
   decisions; corrected stale property name throughout.

2. **2026-04-27 (commit `6f08bae`) — pre-production close-out batch**:
   - **ADR-0003 Amendment A4**: `FailureRespawnState` sub-resource added to
     SaveGame schema (per F&R CR-6); `InventoryState.ammo` split into
     `ammo_magazine` + `ammo_reserve` two-dict (closes 2026-04-28 BLOCKING #4);
     `MissionState.fired_beats` added (per MLS CR-7); **FORMAT_VERSION bumped 1 → 2**.
   - **ADR-0007 Amendment**: canonical autoload table grew **7 → 10**
     (FailureRespawn=8, MissionLevelScripting=9, SettingsService=10). FontRegistry
     confirmed NOT autoload (static class per ADR-0004).
   - **ADR-0008 Amendment**: §Risks autoload-cascade row updated 7 → 10; Slot-8
     panic-onset reserve carve-out (up to 0.6 ms of the 1.6 ms reserve pre-allocated
     for `civilian_panicked` ≥4-emission single-frame absorption); Slot-8 sub-claims
     enumerated (CAI 0.30 ms p95 / MLS 0.1 ms steady + 0.3 ms peak / DC 0.05 ms
     peak / F&R ~0 ms / D&S 0.10 ms peak event-frame).

3. **2026-04-28 (commit `a9bc7d4`) — `/review-all-gdds` resolution batch**:
   - **ADR-0002 amendment**: `settings_loaded()` added to Settings domain (closes
     W4 carryforward, Settings CR-9); `ui_context_changed(new: InputContext.Context,
     old: InputContext.Context)` added to NEW UI domain (closes HUD-Overlay
     coordination gap, HUD CR-10). Signal count grows **38 → 41**; domain count
     grows **9+3 → 9+3+(UI)** = 9 gameplay + 4 infrastructure (UI joins).
   - **ADR-0004 Amendment A6**: InputContext enum extended with `MODAL` + `LOADING`
     values (closes 2026-04-28 BLOCKING #3 / B4 carryforward). Atomic-commit
     bundle: ADR-0002 + ADR-0004 + `InputContextStack` source + downstream sweeps.

4. **2026-04-28 night → 2026-04-29 (uncommitted) — Cutscenes & Mission Cards
   amendment**: `cutscene_started(scene_id: StringName)` + `cutscene_ended(scene_id: StringName)`
   added to NEW Cutscenes domain. Signal count grows **41 → 43**; domain count
   grows **10 gameplay + 3 infrastructure = 13 total**. `StringName`-only payloads
   carry no qualified-enum forward-reference risk; atomic-commit requirement
   reduces to single-PR bundle (no CI guard expansion).

**TR delta**: +173 new TRs across 11 systems (TR-MLS-* / TR-FR-* / TR-CAI-* /
TR-DC-* / TR-HUD-* / TR-HSS-* / TR-DOU-* / TR-MENU-* / TR-DLG-* / TR-CMC-* /
TR-SET-*). Every TR maps to an existing ADR; **zero hard ADR-level gaps** detected.

**Verdict stays PASS**: architecture coverage is the cleanest it has been at
any point — 23/23 systems designed, all backed by ADR-0001..0008. The
uncommitted Cutscenes ADR-0002 amendment is StringName-only, atomic-commit-low-risk,
and conflict-free.

---

## Traceability Summary

| | Prior 2026-04-24 (5th run) | This run | Δ |
|---|---|---|---|
| Total TRs | 175 | **348** | **+173** |
| ✅ Covered (ADR-addressed) | ~171 | ~344 | +173 |
| ⚠️ Partial (ADR exists; some details GDD-only by design) | ~3 | ~3 | — |
| ❌ Hard Gap | **0** | **0** | — |

### Coverage by new system

| # | System (slug) | TR count | Covering ADRs | Status |
|---|---|---:|---|---|
| 13 | Mission & Level Scripting (MLS) | 19 | ADR-0002, ADR-0003, ADR-0006, ADR-0007, ADR-0008 | ✅ All covered |
| 14 | Failure & Respawn (FR) | 14 | ADR-0002, ADR-0003, ADR-0004, ADR-0006, ADR-0007, ADR-0008 | ✅ All covered |
| 15 | Civilian AI (CAI) | 15 | ADR-0001, ADR-0002, ADR-0003, ADR-0006, ADR-0008 | ✅ All covered |
| 16 | HUD Core (HUD) | 15 | ADR-0002, ADR-0004, ADR-0007, ADR-0008 | ✅ All covered |
| 17 | Document Collection (DC) | 15 | ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0006, ADR-0007, ADR-0008 | ✅ All covered |
| 18 | Document Overlay UI (DOU) | 19 | ADR-0002, ADR-0004, ADR-0007, ADR-0008 | ✅ All covered (Gate 5 BBCode→AT open as engine-verification) |
| 19 | Menu System (MENU) | 15 | ADR-0003, ADR-0004, ADR-0007 | ✅ All covered |
| 20 | Settings & Accessibility (SET) | 18 | ADR-0002 (settings_loaded), ADR-0003, ADR-0004, ADR-0007, ADR-0008 | ✅ All covered |
| 21 | Dialogue & Subtitles (DLG) | 15 | ADR-0002, ADR-0003, ADR-0004, ADR-0007, ADR-0008 | ✅ All covered |
| 22 | Cutscenes & Mission Cards (CMC) | 15 | ADR-0001, ADR-0002 (cutscene_started/_ended), ADR-0003, ADR-0004, ADR-0008 | ✅ All covered (pending ADR-0002 amendment commit) |
| 23 | HUD State Signaling (HSS) | 13 | ADR-0002, ADR-0004, ADR-0008 | ✅ All covered |
| | **Total** | **173** | | **✅ All covered** |

**No new ADR required.** The architecture is closed against the design surface.

### Coverage delta — prior systems (1–12) unchanged

All TR-SB-* / TR-INP-* / TR-AUD-* / TR-OUT-* / TR-PP-* / TR-SAV-* / TR-LOC-* /
TR-PC-* / TR-FC-* / TR-LS-* / TR-SAI-* / TR-CD-* / TR-INV-* coverage as the
2026-04-24 fifth-run matrix.

---

## Cross-ADR Conflict Detection

### ✅ All prior conflicts remain closed

- Conflict 1 (autoload line-4 collision) — CLOSED 2026-04-23 by ADR-0007.
- Conflicts 2/3 (ADR-0002 stale signal counts) — CLOSED 2026-04-22 / -28 / -29 by
  successive ADR-0002 amendments. Final count: **43 signals across 13 domains**.
- Concern 1 (Combat-autoload) — CLOSED 2026-04-23.
- Concerns from 2026-04-28 cross-review (9 BLOCKING + 13 WARNINGS) — **all CLOSED**
  by the `6f08bae` + `a9bc7d4` resolution batch:
  - ✅ menu-system.md ~10 stale-slot sweep done (verified `grep -c '7 autoloads' = 0`).
  - ✅ inventory-gadgets.md SaveLoad→LSS sweep done (`grep -c 'SaveLoad.register_restore_callback' = 0`).
  - ✅ ADR-0002 §Decision/Migration "36/34" → 41 (now 43 with Cutscenes amendment).
  - ✅ ADR-0002 `settings_loaded` declared.
  - ✅ ADR-0002 `ui_context_changed` declared (UI domain added).
  - ✅ ADR-0004 `MODAL` + `LOADING` enum values added (Amendment A6).
  - ✅ ADR-0008 §Risks autoload-cascade 7 → 10 + Slot-8 panic-onset reserve allocation.
  - ✅ Combat CR-7 `MELEE_FIST` 2.0 m noise event spec added (combat-damage.md L210–212).
  - ✅ HUD `Tween.kill()` on `ui_context_changed != GAMEPLAY` codified (HUD CR-22).
  - ✅ Audio §Concurrency overlay-suspends-alert-music rule.
  - ✅ Save/Load CR-2 `Overlay.state == IDLE` precondition.

### ✅ ADR-0002 2026-04-28 + 2026-04-29 amendments — no new cross-ADR conflicts

| Candidate conflict | Check | Result |
|--------------------|-------|--------|
| ADR-0002 (43 signals; new Cutscenes domain) vs ADR-0007 (10-entry autoload table) | CutscenesAndMissionCards is **NOT autoload** (CanvasLayer 10 lazy-instance per `cutscenes-and-mission-cards.md` §C.0). No autoload table impact. | ✅ Aligned |
| ADR-0002 (UI domain `ui_context_changed`) vs ADR-0004 (InputContext A6) | Atomic-commit bundle documented in ADR-0002 Risks row 2026-04-28 + ADR-0004 A6 — landed together in `a9bc7d4`. `InputContext.Context.MODAL` + `LOADING` declared on `InputContextStack` before `events.gd` references them. | ✅ Atomic-commit verified |
| ADR-0002 (Cutscenes domain) vs ADR-0003 (Resource schema) | No new save-format claims in 2026-04-29 amendment. MLS owns `MissionState.triggers_fired` write per CR-CMC-21 (signal-driven, not direct cross-system write). | ✅ Aligned |
| ADR-0002 (43 signals) vs ADR-0008 (frame budgets) | All 4 new signals (`settings_loaded`, `ui_context_changed`, `cutscene_started`, `cutscene_ended`) are bounded by player input rate or one-shot per session; trivially within Implementation Guideline 5 budget. Audited in ADR-0002 IG5 amendment. | ✅ Within budget |
| ADR-0003 A4 (4 new sub-resource fields, FORMAT_VERSION 1→2) vs ADR-0008 (save ≤10 ms) | Save-cost claim unchanged; new fields are small `Resource` instances. Refuse-load-on-mismatch policy preserved. | ✅ Within budget |
| ADR-0007 (10 autoloads; F&R=8, MLS=9, Settings=10) vs ADR-0008 (autoload boot ≤50 ms) | ADR-0008 §Non-Frame Budgets row updated 2026-04-28 to reflect 10 autoloads. ≤50 ms cap unchanged; PostProcessStack identified as dominant. | ✅ Aligned |
| ADR-0004 A6 (`MODAL` + `LOADING`) vs Input GDD | Input GDD InputContext enum references (`menu-system.md`, `failure-respawn.md`, `level-streaming.md`, `input.md`) all present `Context.MODAL` and `Context.LOADING`. Atomic-commit landed in same PR. | ✅ Aligned |

**No cross-ADR conflicts detected.**

### Dependency ordering — unchanged structure, count grew

```
Foundation (no ADR deps):
  1. ADR-0001: Stencil ID Contract
  2. ADR-0002: Signal Bus + Event Taxonomy (43 signals; 13 domains; amended 2026-04-22 / -24 / -28 / -29)
  3. ADR-0006: Collision Layer Contract
  4. ADR-0007: Autoload Load Order Registry (10 entries; amended 2026-04-23 / -27)

Depends on Foundation:
  5. ADR-0003: Save Format Contract (FORMAT_VERSION=2; soft-deps ADR-0002; amended 2026-04-27)
  6. ADR-0005: FPS Hands Outline Rendering (exception to ADR-0001)

Depends on Foundation + Feature:
  7. ADR-0004: UI Framework (hard-deps ADR-0002 + ADR-0003; A5+A6 applied)

Consolidator (soft-deps Foundation numeric inputs):
  8. ADR-0008: Performance Budget Distribution (amended 2026-04-28)
```

⚠️ **All 8 ADRs remain `Proposed`.** Verification gate count grew **26 → 30+**
(rough — ADR-0004 Gates went 3→5 via A5; ADR-0008 added the panic-reserve gate).

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-02-12)
**ADRs with Engine Compatibility section**: **8 / 8** ✓ (unchanged)

### Post-Cutoff API Usage — augmented since baseline

| API | Since | ADRs consuming | Notes |
|-----|-------|----------------|-------|
| Stencil buffer (`BaseMaterial3D` / `ShaderMaterial`) | 4.5 | ADR-0001 | unchanged |
| `CompositorEffect` + `Compositor` node | 4.3 | ADR-0001, ADR-0005, ADR-0008 | unchanged |
| Shader Baker | 4.5 | ADR-0001, ADR-0005, ADR-0008 | unchanged |
| D3D12 default on Windows | 4.6 | ADR-0001, ADR-0005, ADR-0008 | unchanged |
| `Resource.duplicate_deep()` | 4.5 | ADR-0003 | A4 amendment unchanged |
| AccessKit screen reader | 4.5 | ADR-0004, HUD/HSS/DOU/MENU/SET GDDs | Verification Gate 1 still OPEN |
| Dual-focus (mouse vs kb/gamepad) | 4.6 | ADR-0004 | unchanged |
| `Theme.fallback_theme` | 4.x stable | ADR-0004 | **Gate 2 CLOSED 2026-04-27 via Amendment A5** |
| `Node.AUTO_TRANSLATE_MODE_*` | 4.5 | ADR-0004 | **Gate 4 CLOSED 2026-04-27** |
| `Node.NOTIFICATION_TRANSLATION_CHANGED` | 4.5 | HSS GDD, DOU GDD (locale-change re-resolve) | godot-specialist confirmed |
| Jolt 3D default | 4.6 | ADR-0006, ADR-0008 | unchanged |
| `RenderingServer.get_frame_profile_measurement()` | 4.4 | ADR-0008 | unchanged |

### Deprecated API Check

`grep` across all 8 ADRs against `deprecated-apis.md` patterns: **clean**. No
`connect("sig", obj, "method")` at load-bearing sites, no `yield`, no bare
`duplicate()`, no `get_world()`, no `VisibilityNotifier*`, no `TileMap`, no
`Navigation2D`/`3D`. The Document Overlay UI revision pass introduced **Gate 5**
(BBCode → AccessKit plain-text serialization) — engine-verification gate, not a
deprecated-API conflict.

### Stale Version References

None. All 8 ADRs pinned to Godot 4.6.
- ADR-0002 Last Verified = **2026-04-29** (uncommitted Cutscenes amendment).
- ADR-0003 Last Verified ≈ 2026-04-27 (Amendment A4).
- ADR-0004 Last Verified ≈ 2026-04-28 (Amendment A6) / 2026-04-27 (Amendment A5).
- ADR-0007 Last Verified = 2026-04-27 (10-entry table).
- ADR-0008 Last Verified = 2026-04-28 (Slot-8 reserve + autoload-cascade row).
- ADR-0001 / -0005 / -0006 unchanged from 5th-run baseline.

### Post-Cutoff API Conflicts Between ADRs

None. The new amendments only add signal declarations / enum values / sub-resource
fields — no new contradictory engine-API claims.

### Engine Specialist Consultation — SKIPPED for this run

Same rationale as the fifth and sixth runs: this delta is signal-declaration +
sub-resource + enum-extension only. No new post-cutoff API surface introduced.
godot-gdscript-specialist consultation was already performed at amendment-time
(per ADR-0002 2026-04-29 Risks row "godot-gdscript-specialist validation 2026-04-29
confirmed PASS on all 5 review points"). Engine-verification gates surfaced by
GDDs (Gate 5 BBCode→AT, MLS Trigger collision-layer TBD, Inventory Coord #11/#12
inherited from 5th run) remain Tech Setup scope.

**Re-run the specialist next cycle if** (a) any verification gate yields
unexpected behavior, (b) a previously-deferred ADR (outline algorithm, audio
architecture, post-process chain) is promoted, (c) engine version pin changes,
(d) Cutscenes amendment commits with surprises, (e) MLS Trigger collision-layer
amendment to ADR-0006 is requested.

---

## Design Revision Flags (Architecture → Design Feedback)

### ✅ All 2026-04-28 cross-review BLOCKING items closed

Verified by grep:
- 0 occurrences of `SaveLoad.register_restore_callback` in `inventory-gadgets.md`
- 0 occurrences of `7 autoloads` / `caps autoloads at 7` across menu-system / hud-core / inventory-gadgets
- 0 occurrences of `SettingsService at slot 8` in menu-system
- 0 occurrences of `setting_changed."hud"` in hud-core
- `MELEE_FIST` 2.0 m noise event present in combat-damage.md L210–212
- `cutscene_started` / `cutscene_ended` declared in uncommitted ADR-0002 diff

### ⚠️ Producer-tracked sweeps from the Cutscenes amendment (downstream-scope)

Per the uncommitted ADR-0002 2026-04-29 amendment Risks row "Downstream scope
flagged but out of this amendment":

| GDD | Action | Owner | Severity |
|-----|--------|-------|----------|
| `cutscenes-and-mission-cards.md` | Drop "BLOCKING ADR-0002 amendment" qualifier on CR-CMC-11 + downstream references | CMC author | Pre-commit |
| `audio.md` L407 | Drop "to be added to ADR-0002 during Cutscenes GDD authoring" forward-dep qualifier; reference 2026-04-29 amendment | Audio author | Pre-commit |
| `signal-bus.md` | Update count 41 → 43; §54 domain table grows by Cutscenes row; AC-3 count update | Signal Bus author | Pre-commit |
| `mission-level-scripting.md` | Confirm CR-CMC-21 subscriber spec for `cutscene_ended` (MLS writes `scene_id` to `triggers_fired`) | MLS author | Pre-commit (already declared per CR-CMC-21) |

These are coordinative text edits, not architectural conflicts. Equivalent in
scale to the 5th-run Inventory coord items (all closed within one session).

### ✅ No GDD-to-engine revision flags

No GDD assumption conflicts with verified engine behavior. The four amendments
landing since 2026-04-24 preserve all prior GDD-to-ADR alignment.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v1.0, ~1689 lines, last touched 2026-04-23
during initial authoring) carries **one stale reference** that does not affect
architectural soundness but is doc-hygiene:

- **L13 GDDs Covered line is stale**: states "10 authored... 13 not yet authored
  (Inventory & Gadgets, Mission & Level Scripting, Failure & Respawn, Civilian
  AI, HUD Core, Document Collection, Dialogue & Subtitles, HUD State Signaling,
  Document Overlay UI, Menu System, Cutscenes & Mission Cards, Settings &
  Accessibility)". **Reality 2026-04-29: all 23 systems authored** (including
  the 11 listed as "not yet authored" plus Inventory which landed 2026-04-24).
- L65–73 system enumeration in the layer map ASCII art correctly lists all 23
  systems. **Layer-map content is current; only the cover-page metadata line is
  stale.**

**Recommended fix** (one-line edit, not blocking PASS): update L13 to read:

```
| **GDDs Covered** | 23 / 23 authored (all MVP + VS systems designed as of 2026-04-28). |
```

No structural or load-bearing content changes. No orphaned architecture entries.
No systems from `systems-index.md` missing from the layer map.

---

## Verdict: **PASS**

### Why PASS (re-affirmed for the seventh run)

- **Zero hard ADR-level gaps** — all 173 new TRs across 11 systems map to existing
  ADRs.
- **Zero cross-ADR conflicts** — four amendments (ADR-0002 ×3, ADR-0003 A4,
  ADR-0004 A5+A6, ADR-0007, ADR-0008) are internally consistent and preserve
  all prior invariants.
- **Engine consistent** — 8 ADRs pinned to Godot 4.6; no deprecated APIs; no
  contradictory post-cutoff API assumptions.
- **Dependency graph clean** — no cycles; topological order unchanged; count of
  ADRs unchanged (still 8).
- **All 9 BLOCKING + 13 WARNINGS from `/review-all-gdds` 2026-04-28 are closed**
  — verified by targeted grep before this review opened.
- **Uncommitted Cutscenes amendment is low-risk** — `StringName`-only payloads,
  no qualified-enum forward-reference risk, atomic-commit reduced to single-PR
  bundle without CI guard expansion.
- **All 23/23 systems designed** — design phase closes cleanly.

### Execution-phase items remaining (do not block PASS)

1. **Uncommitted ADR-0002 2026-04-29 amendment + 4 companion GDD edits**
   ready to commit as a single atomic PR (see Producer-tracked sweeps above).
2. **30+ verification gates outstanding** across 8 Proposed ADRs. These move
   ADRs Proposed → Accepted and resolve engine-behavior assumptions.
3. **architecture.md L13 stale GDDs-Covered count** — one-line metadata edit.
4. **Pre-Production gate items** — after the seventh-run PASS is durable, run
   `/gate-check pre-production` to formalise the design phase exit.

---

## Priority Action List (next 1–2 sessions)

### Session A — Commit the Cutscenes ADR-0002 amendment bundle

Single-PR bundle landing the uncommitted changes:
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` (43 signals, Cutscenes domain)
- `docs/registry/architecture.yaml` (`gameplay_event_dispatch.signal_signature` = 43)
- `design/gdd/cutscenes-and-mission-cards.md` (drop CR-CMC-11 BLOCKING qualifier)
- `design/gdd/audio.md` L407 (drop forward-dep qualifier)
- `design/gdd/signal-bus.md` (count 41 → 43; new Cutscenes domain row)
- `design/gdd/mission-level-scripting.md` (confirm CR-CMC-21 subscriber spec)

Estimated effort: 4 small edits + 1 commit; <1 hour.

### Session B — One-line architecture.md L13 fix

Update GDDs Covered metadata. <5 minutes.

### Session C — `/gate-check pre-production`

After Session A and B, this becomes the natural next step. Likely PASS.

### Session D (optional) — Begin verification gate execution

godot-specialist spike tests for the highest-risk gates:
- ADR-0004 Gate 1 (AccessKit property names)
- ADR-0004 Gate 5 (BBCode → AccessKit plain-text)
- ADR-0004 Gate 3 (modal dismiss `ui_cancel`)
- Inventory Coord #11 (SkeletonModifier3D cross-subtree)
- Inventory Coord #12 (autoload `_unhandled_input` ordering)

Each gate that passes promotes one ADR Proposed → Accepted.

---

**Re-run trigger**: `/architecture-review` after (a) any verification gate
passes (an ADR moves Proposed → Accepted), (b) a post-design-phase ADR is
authored (e.g., outline algorithm, audio architecture, post-process chain),
(c) any GDD enters Production phase and surfaces an unforeseen architectural
need, or (d) engine version pin changes.

**Gate guidance**: After Session A (Cutscenes amendment commit) lands and
Session B (architecture.md L13 fix) is applied, `/gate-check pre-production`
is the natural next step and is expected to PASS.

---

## Related

- `docs/architecture/requirements-traceability.md` — refreshed this run (Systems
  13–23 added; **+173 new TR-* entries registered**; seventh-run history entry appended)
- `docs/architecture/tr-registry.yaml` — **+173 new TR-* entries appended**
  (TR-MLS-001..019, TR-FR-001..014, TR-CAI-001..015, TR-DC-001..015, TR-HUD-001..015,
  TR-HSS-001..013, TR-DOU-001..019, TR-MENU-001..015, TR-DLG-001..015,
  TR-CMC-001..015, TR-SET-001..018); `last_updated: 2026-04-29`
- `docs/architecture/architecture-review-2026-04-24.md` — prior (fifth) full review baseline
- `docs/architecture/change-impact-2026-04-27-document-overlay-ui.md` — sixth
  run (change-impact only, ADR-0004 A5)
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — **amended
  2026-04-28 + 2026-04-29 (uncommitted)** (43 signals; UI + Cutscenes domains added)
- `docs/architecture/adr-0003-save-format-contract.md` — **amended 2026-04-27**
  (A4: FailureRespawnState + ammo split + fired_beats + FORMAT_VERSION=2)
- `docs/architecture/adr-0004-ui-framework.md` — **amended 2026-04-27 (A5) +
  2026-04-28 (A6)** (fallback_theme; MODAL + LOADING InputContext)
- `docs/architecture/adr-0007-autoload-load-order-registry.md` — **amended
  2026-04-27** (10-entry canonical table)
- `docs/architecture/adr-0008-performance-budget-distribution.md` — **amended
  2026-04-28** (Slot-8 panic-onset reserve + autoload-cascade 7→10 + Slot-8 sub-claims)
- `design/gdd/systems-index.md` — Progress Tracker: 23/23 designed (MVP + VS complete)
- `design/gdd/gdd-cross-review-2026-04-28.md` — concentrated synthesis of 9
  BLOCKING + 13 WARNINGS, all closed by `6f08bae` + `a9bc7d4` resolution batch
- 11 NEW system GDDs landed since 2026-04-24:
  - `mission-level-scripting.md` (931 lines)
  - `failure-respawn.md` (553 lines)
  - `civilian-ai.md` (983 lines)
  - `document-collection.md` (1360 lines)
  - `hud-core.md` (1307 lines)
  - `hud-state-signaling.md` (1037 lines)
  - `document-overlay-ui.md` (1274 lines)
  - `menu-system.md` (1748 lines)
  - `dialogue-subtitles.md` (1403 lines)
  - `cutscenes-and-mission-cards.md` (1701 lines)
  - `settings-accessibility.md` (1371 lines)
- `production/session-state/active.md` — seventh-run extract appended
