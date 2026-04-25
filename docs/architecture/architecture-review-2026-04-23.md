# Architecture Review Report

| Field | Value |
|-------|-------|
| **Date** | 2026-04-23 (fourth run — supersedes earlier 2026-04-23 snapshots after ADR-0007 Combat-autoload amendment + 3 GDD coordination closures) |
| **Mode** | `/architecture-review` (full, delta-verification since third 2026-04-23 run) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **GDDs Reviewed** | 13 (no new authorship since 2026-04-22; 3 touch-ups landed this session — `audio.md`, `input.md`, `player-character.md`) |
| **ADRs Reviewed** | **8** (all Proposed; ADR-0007 amended in-place 2026-04-23) |
| **TR Registry State on Entry** | 160 active TRs; 2 revisions this session (TR-INP-002 29→30 actions; TR-LS-007 requirement pointer) |
| **Prior Review** | This file overwrites the third 2026-04-23 snapshot. See `docs/architecture/architecture-review-2026-04-22.md` for the full-matrix baseline. |
| **Verdict** | **PASS** (re-affirmed; upgrades the `/create-architecture` 2026-04-23 verdict from APPROVED WITH CONCERNS to APPROVED — Combat-autoload Concern 1 closed by amendment) |

---

## Summary

One ADR amendment + three GDD coordination touch-ups landed between the third
2026-04-23 review and this run:

1. **`/architecture-decision adr-0007-amendment`** — in-place edit to
   `docs/architecture/adr-0007-autoload-load-order-registry.md`. Canonical
   autoload count grew **6 → 7** via `Combat` at line 7 (`class_name
   CombatSystemNode`, autoload key `Combat`, script
   `*res://src/gameplay/combat/combat_system.gd`). 13 edits to ADR-0007 + 1
   row in `docs/registry/architecture.yaml`. Status remains **Proposed**
   (amendment does not retire Gate 1 or Gate 2). Path A per godot-specialist
   consultation 2026-04-23. This closes the TD-ARCHITECTURE Concern 1 flagged
   by `/create-architecture` 2026-04-23.

2. **`design/gdd/player-character.md`** — `CombatSystem.*` →
   `CombatSystemNode.*` rename pass applied to all 10 sites (closes GDD
   coordination item #3 from prior review).

3. **`design/gdd/audio.md`** §Mission handler table — `section_entered` /
   `section_exited` signatures grown from 1-param to 2-param with `reason:
   LevelStreamingService.TransitionReason` and 4-way branching (FORWARD /
   RESPAWN / NEW_GAME / LOAD_FROM_SAVE) documented per LS GDD CR-8 (closes
   LS-Gate-3 / GDD coordination item #4).

4. **`design/gdd/input.md`** — `use_gadget` action split into dedicated
   `takedown` + `use_gadget` with mutex on `SAI.takedown_prompt_active()` per
   Combat CR-3. Action catalog grew 29 → 30 (TR-INP-002 revised; closes GDD
   coordination item #5).

**All three producer-tracked GDD coordination items have now closed in the same
session** — a state cleaner than any prior review point in this project.

This delta review (a) verifies the ADR-0007 amendment is internally consistent
and conflict-free, (b) verifies the three GDD touch-ups align with their
driving ADRs, (c) flags and fixes 5 "6 autoload" staleness stragglers left by
the amendment, (d) re-audits cross-ADR conflicts (none detected).

**Verdict stays PASS**: the architectural design is complete. No new
architectural decisions are outstanding; no cross-ADR conflicts; zero hard
ADR-level gaps. Execution-phase work remains (24 verification gates to move
ADRs Proposed → Accepted) but is not architecture-level debt.

---

## Traceability Summary

| | Prior 2026-04-23 (3rd run) | This run | Δ |
|---|---|---|---|
| Total TRs | 158 | **160** | +2 (registry growth; no new this session — historical accounting reconciliation) |
| ✅ Covered | ~154 | ~156 | +2 (TR-CD-022 locked to ADR-0007 line 7; TR-INP-002 revision aligns to existing ADR-0004 InputContext coverage) |
| ⚠️ Partial | ~3 | ~3 | — |
| ❌ Hard Gap | **0** | **0** | — |

No new TRs were extracted. Two registry revisions landed (ID-stable per
append-only rule):

- **TR-INP-002** (Input action catalog): "29 InputMap actions (26 gameplay/UI
  + 3 debug)" → "30 InputMap actions (27 gameplay/UI + 3 debug)", reflecting
  the `takedown` split per Combat CR-3. Note on binding share + mutex added.
  `revised: 2026-04-23`.

- **TR-LS-007** (LevelStreamingService autoload declaration): pointer text
  updated to cite ADR-0007 §Key Interfaces as authoritative source (post
  2026-04-23 amendment: 7 autoloads, LSS at line 5). `revised: 2026-04-23`.

### Coverage delta (high-level)

| # | System | Covering ADRs | Status (was → is) |
|---|--------|---------------|-------------------|
| 11 | Combat & Damage | ADR-0001, ADR-0002, ADR-0003, ADR-0006, ADR-0007 (Combat at line 7 per 2026-04-23 amendment), ADR-0008 | ✅ → ✅ strengthened; TR-CD-022 (autoload convention split) now registry-aligned |
| 12 | Input | ADR-0004, **TR-INP-002 revised for `takedown` split** | ⚠️ (coordination gap) → ✅ (30-action catalog documented) |
| 3 | Audio | ADR-0002, ADR-0008 | ⚠️ (coordination gap) → ✅ (2-param handler signatures now documented) |
| 7 | Player Character | ADR-0002 (Combat accessor carve-outs), ADR-0003, ADR-0008 | ✅ → ✅ strengthened (`CombatSystemNode` rename applied; AC test stubs consistent) |

All other rows unchanged from the 2026-04-23 third-run matrix.

---

## Coverage Gaps

### ✅ Zero hard ADR-level gaps (re-affirmed)

No gap changes since the prior PASS verdict. All 160 TRs either have ADR
coverage or are intentionally GDD-scope (audio internals; post-process chain
GDD details).

### ⚠️ Partials — unchanged at 2

- **Audio architecture internals** (buses, pools, state-machine specifics
  live GDD-only). Acceptable for MVP; signal-contract side fully covered by
  ADR-0002. Frame-dispatch cost covered by ADR-0008 Slot #6. 2-param
  `section_entered` / `section_exited` signatures now documented (closes
  LS-Gate-3).
- **Post-Process Stack GDD-internal details** (chain order is in the
  Post-Process GDD; forbidden effects list is Pillar-level). Acceptable for
  MVP; lifecycle API covered by ADR-0004; perf budget covered by ADR-0008
  Slot #3.

These are deliberate GDD-scope scoping decisions, not gaps.

---

## Cross-ADR Conflicts

### ✅ All prior conflicts remain closed

- Conflict 1 (autoload load-order-4 collision) — CLOSED 2026-04-23 by ADR-0007.
- Conflict 2 (ADR-0002 section signals outdated) — CLOSED 2026-04-22 by ADR-0002 4th-pass.
- Conflict 3 (ADR-0002 missing SAI 4th-pass signals) — CLOSED 2026-04-22 by ADR-0002 4th-pass.
- **Concern 1 from `/create-architecture` TD self-review** (Combat-autoload in
  ADR-0002 + combat-damage.md §350 + TR-CD-022 vs. ADR-0007's "6 autoloads"
  canonical table) — **CLOSED 2026-04-23** by ADR-0007 in-place amendment
  (Path A). Canonical registration table now has 7 entries with Combat at
  line 7; `docs/registry/architecture.yaml` `autoload_registration_order`
  api_decisions row updated.

### ✅ ADR-0007 amendment — no new cross-ADR conflicts

| Candidate conflict | Check | Result |
|--------------------|-------|--------|
| ADR-0007 (7 autoloads) vs ADR-0002 (Combat autoload claim) | Both assert Combat as autoload with `class_name CombatSystemNode` / key `Combat`; ADR-0007 pins at line 7 | ✅ Aligned |
| ADR-0007 (7 autoloads) vs combat-damage.md §350 / TR-CD-022 | Both assert same autoload convention; ADR-0007 quotes TR-CD-022 in §GDD Requirements Addressed | ✅ Aligned |
| ADR-0007 (7 autoloads) vs ADR-0008 boot budget (≤50 ms cold-start) | ADR-0008 estimate "~6 × <1 ms ≈ <6 ms" vs. amended "~7 × <1 ms ≈ <7 ms" — still well under ≤50 ms with PostProcessStack dominant (5–15 ms Vulkan + descriptor heap D3D12) | ✅ Within budget (stragglers fixed this run — see §Amendment Tail below) |
| ADR-0007 cross-autoload reference safety rules vs Combat at line 7 | CombatSystemNode has no cross-autoload `_init()` or `_ready()` references per godot-specialist 2026-04-23; per-dart / per-GuardFireController `Events.respawn_triggered` subscriptions happen in scene-node `_ready()` instances that always run after the autoload chain | ✅ Safe |
| Amendment fences (`unregistered_autoload`, `autoload_init_cross_reference`) vs Combat at line 7 | Existing fences apply identically; no new forbidden patterns needed | ✅ Covered |

**No cross-ADR conflicts detected.**

### Dependency ordering — unchanged

ADR-0007 remains foundational (no dependencies). ADR-0008 soft-deps ADR-0001
/ -0002 / -0007 (numeric inputs). No cycles; no stale dependency references.

```
Foundation (no ADR deps):
  1. ADR-0001: Stencil ID Contract
  2. ADR-0002: Signal Bus + Event Taxonomy
  3. ADR-0006: Collision Layer Contract
  4. ADR-0007: Autoload Load Order Registry (amended 2026-04-23: 7 entries)

Depends on Foundation:
  5. ADR-0003: Save Format Contract (soft-deps ADR-0002)
  6. ADR-0005: FPS Hands Outline Rendering (exception to ADR-0001)

Depends on Foundation + Feature:
  7. ADR-0004: UI Framework (hard-deps ADR-0002 + ADR-0003)

Consolidator (soft-deps Foundation numeric inputs):
  8. ADR-0008: Performance Budget Distribution (inputs from ADR-0001 / -0002 / -0007)
```

⚠️ **All 8 ADRs remain `Proposed`.** 24 verification gates outstanding across
the chain (unchanged from prior run). Stories referencing a Proposed ADR are
auto-blocked.

| ADR | Gate count | Δ |
|-----|-----------:|---|
| ADR-0001 | 4 | — |
| ADR-0002 | 1 | — |
| ADR-0003 | 3 | — |
| ADR-0004 | 3 | — |
| ADR-0005 | 5 | — |
| ADR-0006 | 3 | — |
| ADR-0007 | 1 (byte-match against amended 7-entry `[autoload]` block) | — (amended; still one gate, now checks 7 entries) |
| ADR-0008 | 4 | — |
| **Total** | **24** | — |

---

## Amendment Tail Cleanup (this run)

The ADR-0007 2026-04-23 amendment landed 13 edits to ADR-0007 + 1 row in
`docs/registry/architecture.yaml`, but left 5 narrative/reference sites
enumerating "6 autoloads" in adjacent documents. These are **editorial
staleness**, not conflicts — they do not change any architectural claim, and
they do not break Gate 1 byte-match (which checks `project.godot [autoload]`
against ADR-0007 §Key Interfaces, which was correctly amended to 7 entries).

Fixed this run:

| File | Site | Before | After |
|---|---|---|---|
| `docs/architecture/adr-0007-autoload-load-order-registry.md` | §Requirements L124 | "all 6 project autoloads" | "all 7 project autoloads (6 original + Combat added 2026-04-23)" |
| `docs/architecture/architecture.md` | §2 Principle 4 (L141) | "6 autoloads, canonical line order: ... PostProcessStack (6)" | "7 autoloads (per 2026-04-23 amendment), canonical line order: ... PostProcessStack (6) → Combat (7)" |
| `docs/architecture/architecture.md` | §6.4 ADR-0007 row (L1456) | "Combat omission recorded in §6.3 above" | "...; ✅ RESOLVED 2026-04-23 via in-place amendment (canonical table now 7 entries; Combat at line 7)" |
| `docs/architecture/architecture.md` | §6.3 Required follow-up (L1441–1442) | Action item text | Appended "**✅ LANDED 2026-04-23**" annotation |
| `docs/architecture/architecture.md` | §6.5 Audit Summary (L1463) | "1 cross-session conflict ... Tracked in §7 Required ADRs as the sole new ADR follow-up" | "...; ✅ LANDED 2026-04-23 — ADR-0007 in-place amendment. Concern closed on fourth-run verdict" |
| `docs/architecture/architecture.md` | §7.2.1 ADR-0007 amendment row (L1492–1502) | Scope/Owner/Effort fields describing the action | Added **Status** row with ✅ LANDED; retitled "✅ LANDED 2026-04-23" |
| `docs/architecture/adr-0008-performance-budget-distribution.md` | ADR Dependencies (L26) | "6 autoloads' boot cascade" | "7 autoloads' boot cascade per 2026-04-23 amendment" |
| `docs/architecture/adr-0008-performance-budget-distribution.md` | Non-frame budgets table (L119) | "cascade across 6 autoloads ... ~6 × <1 ms ≈ <6 ms" | "cascade across 7 autoloads ... ~7 × <1 ms ≈ <7 ms"; Combat at 7 appended; note about Combat's stateless negligible cost |
| `docs/architecture/adr-0008-performance-budget-distribution.md` | ASCII summary (L181) | "(6 autoloads, PostProcessStack dominant)" | "(7 autoloads per ADR-0007 2026-04-23 amendment, PostProcessStack dominant)" |
| `docs/architecture/requirements-traceability.md` | Gap-2 resolution note (L201) | "6 autoloads now have a single canonical line order" | "7 autoloads" + Combat=7 added |
| `docs/architecture/requirements-traceability.md` | Gaps 3/4/5 (GDD coordination) | All 3 listed as open | All 3 marked **CLOSED 2026-04-23** with specifics |
| `docs/architecture/tr-registry.yaml` | TR-LS-007 (L792) | Enumerated 5 autoloads (missing PP + Combat) | Now points to ADR-0007 §Key Interfaces as authoritative source; `revised: 2026-04-23` |
| `docs/architecture/tr-registry.yaml` | `last_updated` comment | "TR-INP-002 revised..." | Added TR-LS-007 revision note |

**Total sites touched this run**: 13 surgical edits across 5 files. No
behavioural or numerical claims changed — all are text-alignment updates
bringing narrative in sync with ADR-0007's amended canonical table.

**Budget check on ADR-0008 autoload boot claim**: "~7 × <1 ms ≈ <7 ms pure
autoload instantiation" still fits inside the ≤50 ms cold-start envelope
(dominated by PostProcessStack at 5–15 ms Vulkan + descriptor heap +5–10 ms
D3D12). Combat autoload is stateless enum + method definitions (negligible
instantiation). No budget pressure from the amendment.

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-02-12)
**ADRs with Engine Compatibility section**: **8 / 8** ✓ (unchanged)

### Post-Cutoff API Usage — unchanged from prior run

No new post-cutoff APIs introduced by the ADR-0007 amendment (autoload
`[autoload]` block syntax stable since 4.0 per `breaking-changes.md`) or by
the three GDD touch-ups (all align to already-declared contracts in
ADR-0002 / ADR-0004 / combat-damage.md).

| API | Since | ADRs consuming |
|-----|-------|----------------|
| Stencil buffer (`BaseMaterial3D` / `ShaderMaterial` write; `CompositorEffect` read) | 4.5 | ADR-0001 |
| `CompositorEffect` + `Compositor` node | 4.3 | ADR-0001, ADR-0005, ADR-0008 (inherits) |
| Shader Baker | 4.5 | ADR-0001, ADR-0005 (A5), ADR-0008 (non-frame budgets; first-run cost) |
| D3D12 default on Windows | 4.6 | ADR-0001, ADR-0005, ADR-0008 (descriptor heap reserve + post-stream warm-up) |
| `Resource.duplicate_deep()` | 4.5 | ADR-0003 |
| AccessKit screen reader | 4.5 | ADR-0004 |
| Dual-focus (mouse vs keyboard/gamepad) | 4.6 | ADR-0004 |
| Jolt 3D default | 4.6 | ADR-0006, ADR-0008 (Slot #4 + first-contact reserve) |
| `RenderingServer.get_frame_profile_measurement()` | 4.4 | ADR-0008 (CI-time per-slot measurement) |

### Deprecated API Check

`grep` across all 8 ADRs for patterns in `deprecated-apis.md`: **clean**. No
`connect("sig", obj, "method")` at load-bearing sites, no `yield`, no bare
`duplicate()` without `_deep`, no `get_world()`, no `VisibilityNotifier*`, no
`TileMap`, no `Navigation2D`/`3D`, no `Texture2D` in shader-parameter type
annotations at load-bearing sites.

### Stale Version References

None. All 8 ADRs pinned to 4.6. ADR-0007 Last Verified = 2026-04-23
(amendment date). ADR-0008 Last Verified = 2026-04-23. All others unchanged
from prior run.

### Post-Cutoff API Conflicts Between ADRs

None. ADR-0007 amendment introduces no new post-cutoff APIs; all other
ADR-to-ADR post-cutoff consistency checks from the prior run hold.

### Engine Specialist Consultation

**Skipped this review run.** Same rationale as the third 2026-04-23 run, with
additional justification:

- **ADR-0007 amendment**: already pre-validated by godot-specialist
  consultation 2026-04-23 (Path A endorsed). Re-validating a 1-line table
  append + 1 bullet addition + narrative edits provides negligible new signal
  for a LOW-risk engine domain (autoload `[autoload]` syntax stable since
  Godot 4.0 per `breaking-changes.md`).
- **3 GDD touch-ups**: all align GDD text to already-existing ADR contracts
  (ADR-0002 signal signatures; Combat CR-3 action catalog; ADR-0002 OQ-CD-1
  bundle Combat autoload split). No new engine behaviour invoked.
- **No new ADRs authored**, no new post-cutoff APIs consumed, no engine
  version pin change.

**Re-run the specialist next cycle** if (a) any verification gate surfaces
engine behaviour not captured in the reference docs, (b) a previously-deferred
ADR (outline algorithm, audio architecture, post-process chain) is promoted,
(c) engine version pin changes, or (d) `/design-system failure-respawn`
triggers a potential second ADR-0007 amendment for line 8.

---

## Design Revision Flags (Architecture → Design Feedback)

### ✅ All three prior coordination items CLOSED this session

#### ✅ PC `CombatSystem.*` → `CombatSystemNode.*` rename — LANDED 2026-04-23

| GDD | Status |
|-----|--------|
| `design/gdd/player-character.md` | All 10 sites renamed (L162, 200, 228, 426, 457, 466, 561, 762, 878, 885) — verified via `grep CombatSystem\\.` returning zero hits this run. |

#### ✅ Audio LS-Gate-3 — LANDED 2026-04-23

`design/gdd/audio.md` §Mission handler table L188–189 now documents 2-param
`section_entered(section_id, reason)` and `section_exited(section_id,
reason)` with full 4-way branching on `reason:
LevelStreamingService.TransitionReason` per LS GDD CR-8. Reverb bus swap
ordering (first, always) + music crossfade branching (FORWARD / RESPAWN /
NEW_GAME / LOAD_FROM_SAVE) documented. Audio-owned touch-up complete.

#### ✅ Input ↔ Combat Takedown coordination — LANDED 2026-04-23

`design/gdd/input.md` L90 now declares dedicated `takedown` action (kbd F /
gamepad Y) distinct from `fire_primary`, live only when
`SAI.takedown_prompt_active()` returns true; `use_gadget` retains F / Y
binding with a documented mutex rule (both handlers check
`SAI.takedown_prompt_active()` and early-return as appropriate). Action
catalog grew 29 → 30 (TR-INP-002 revised; AC-3 invariant updated).

### No new GDD revision flags

No GDD assumptions conflict with verified engine behaviour or current ADR
state (ADR-0007 amended + ADR-0002 + ADR-0008). GDDs and ADRs are fully
aligned as of this run.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` **exists** (v1.0, ~1688 lines, authored
`/create-architecture` 2026-04-23). This review run applied 5 straggler edits
to the document (§2 Principle 4; §6.3 follow-up annotation; §6.4 ADR-0007
row; §6.5 Audit Summary; §7.2.1 status row) to reflect the ADR-0007
amendment state. No structural or load-bearing content changes; all edits
are narrative-alignment annotations.

No systems from `systems-index.md` are missing from the architecture
document's layer map. No orphaned architecture entries. Data flow section
covers all cross-system communication defined in GDDs.

---

## Verdict: **PASS**

### Why PASS (re-affirmed)

- **Zero hard ADR-level gaps** — every TR has at least one ADR addressing it, or is intentionally GDD-scope.
- **Zero cross-ADR conflicts** — ADR-0007 amendment closes the final cross-session editorial conflict (TD-ARCHITECTURE Concern 1) flagged by `/create-architecture`. No new conflicts introduced.
- **Engine consistent** — 8 ADRs all pinned to Godot 4.6; no stale version references; no deprecated-API consumption; no contradictory post-cutoff API assumptions.
- **Dependency graph clean** — no cycles; topological order unchanged.
- **3 GDD coordination items CLOSED this session** — PC rename pass, Audio LS-Gate-3, Input takedown split. Cleaner than any prior review point.
- **Amendment-tail staleness fixed** — 13 surgical edits across 5 files bring narrative references in sync with ADR-0007's amended 7-entry canonical table.

### Upgrade impact on `/create-architecture` TD verdict

`/create-architecture` 2026-04-23 TD self-review verdict was **APPROVED WITH
CONCERNS** (1 concern: Combat-autoload in ADR-0002 + combat-damage.md §350 +
TR-CD-022 vs. ADR-0007's 6-autoload canonical table). This amendment closes
that concern. The architecture document inherits **APPROVED (without
CONCERNS)** status on the strength of this review run.

### Execution-phase items remaining (do not block PASS)

These are story-level and production-level concerns, not architectural:

1. **24 verification gates outstanding** across 8 Proposed ADRs. These move
   ADRs Proposed → Accepted. Priority order unchanged from third-run
   recommendation.

2. **2 infrastructure stories** (tooling):
   - `tests/reference_scenes/restaurant_dense_interior.tscn` — prototyper / qa-lead story.
   - GitHub Actions `perf-gate` job — devops-engineer story.
   Both gate ADR-0008 Gates 1–4.

3. **Potential second ADR-0007 amendment** if `/design-system
   failure-respawn` elects autoload (line 8). Non-blocking; deferred to the
   F&R design session.

---

## Priority Action List (next 2–3 sessions)

### Session A — Advance foundational ADRs to Accepted

Begin ADR verification gate passes in the Godot 4.6 editor, recommended
order unchanged from third-run:

1. **ADR-0001 Gates 1–3** (stencil buffer API in BaseMaterial3D,
   CompositorEffect stencil read on Vulkan, then on D3D12). Unblocks outline
   pipeline stories.
2. **ADR-0002 Gate 1** (smoke test: emit + subscribe + EventLogger).
   Simultaneously validates ADR-0007's cross-autoload reference safety +
   amended 7-entry table (ADR-0007 Gate 2 is coincident; Gate 1 byte-match
   also runs here for the first time).
3. **ADR-0003 / ADR-0005 / ADR-0007 Gate 1 / ADR-0008 Gates 1–4** as tooling
   lands.

### Session B — Author reference scene + configure CI perf-gate

Parallel to Session A. Unchanged from third-run.

### Session C — Continue MVP GDD authoring

Next unblocked GDD: **Inventory & Gadgets** (system #12). Combat + SAI both
define interfaces Inventory will consume; fully unblocked by existing ADRs.
Alternative: `/design-system failure-respawn` (system #13); if autoload
chosen, triggers a second ADR-0007 amendment for line 8.

---

**Re-run trigger**: `/architecture-review` after (a) any verification gate
passes (an ADR moves Proposed → Accepted), (b) next MVP GDD lands
(Inventory / Failure & Respawn / Civilian AI / Mission Scripting / Document
Collection / Dialogue / Settings & Accessibility / HUD Core / Menus / Pause
Menu — 13 outstanding), or (c) `/design-system failure-respawn` elects
autoload (triggers ADR-0007 2nd amendment).

**Gate guidance**: `/gate-check pre-production` is eligible. Running it now
will likely return CONCERNS due to the 24 outstanding verification gates and
13 outstanding MVP GDDs. Running it after Session A's first gates pass + a
few more GDDs land should yield a clearer verdict.

---

## Related

- `docs/architecture/requirements-traceability.md` — refreshed this run (Gap 2 / coordination items 3–5 now all CLOSED; fourth-run history entry to be appended)
- `docs/architecture/tr-registry.yaml` — 2 revisions this run (TR-INP-002; TR-LS-007); `last_updated: 2026-04-23` comment updated
- `docs/architecture/architecture-review-2026-04-22.md` — initial full-matrix baseline (pre-ADR-0007 / ADR-0008)
- `docs/architecture/adr-0007-autoload-load-order-registry.md` — **amended 2026-04-23** (Combat at line 7; 13 edits + registry row)
- `docs/architecture/adr-0008-performance-budget-distribution.md` — 3 straggler edits this run ("6 autoloads" → "7 autoloads")
- `docs/architecture/architecture.md` — 5 straggler edits this run (§2 Principle 4; §6.3; §6.4; §6.5; §7.2.1)
- `docs/registry/architecture.yaml` — `autoload_registration_order` api_decisions row updated (6 → 7 autoloads; `revised: 2026-04-23`)
- `design/gdd/player-character.md` — 10-site `CombatSystem.*` → `CombatSystemNode.*` rename applied
- `design/gdd/audio.md` — §Mission handler table 2-param signatures + 4-way branching documented
- `design/gdd/input.md` — `takedown` / `use_gadget` split; action catalog 29 → 30
- `design/gdd/systems-index.md` — no Status changes this run
- `production/session-state/active.md` — to be updated with fourth-run extract
