# Architecture Review Report

| Field | Value |
|-------|-------|
| **Date** | 2026-04-24 (fifth run — post-`/design-system inventory-gadgets` + ADR-0002 2026-04-24 amendment) |
| **Mode** | `/architecture-review` (full, delta-verification since fourth 2026-04-23 run) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **GDDs Reviewed** | 14 (**1 NEW** — `design/gdd/inventory-gadgets.md`, 1608 lines; all other GDDs unchanged since 4th-run PASS) |
| **ADRs Reviewed** | **8** (ADR-0002 amended in-place 2026-04-24; all others unchanged) |
| **TR Registry State on Entry** | 160 active TRs |
| **Prior Review** | `docs/architecture/architecture-review-2026-04-23.md` (fourth run, PASS) |
| **Verdict** | **PASS** (re-affirmed) |

---

## Summary

One new MVP GDD + one ADR amendment + four registry touch-ups landed between
the fourth 2026-04-23 run and this run:

1. **`/design-system inventory-gadgets`** — new GDD at
   `design/gdd/inventory-gadgets.md` (1608 lines). Solo-mode authorship
   2026-04-24 across 11 sections; `/design-review` verdict MAJOR REVISION
   NEEDED resolved in-session. Status: **Approved pending Coord items
   2026-04-24** in `systems-index.md` row 12. 6 BLOCKING coord items open
   (see §GDD Revision Flags below) — none architectural.

2. **`/architecture-decision adr-0002-amendment`** — in-place edit to
   `docs/architecture/adr-0002-signal-bus-event-taxonomy.md`. Signal count
   grew **36 → 38**; `guard_incapacitated(guard: Node)` grew
   `guard_incapacitated(guard: Node, cause: int)`;
   `CombatSystemNode.DamageType` gained `MELEE_PARFUM` member (non-lethal).
   Atomic-commit Risks row documents the signature-breaking migration
   requirement. Bundled resolution of OQ-INV-1 (Option B: Parfum-KO drops
   nothing).

3. **Registry Phase 5b** (`design/registry/entities.yaml`): 1 stale-value fix
   (`guard_drop_pistol_rounds` 8 → 3; Combat-authoritative since
   2026-04-22 never propagated), 6 new entries (`rifle_max_reserve = 12`,
   `medkit_heal_amount = 40`, `gadget_compact`, `gadget_cigarette_case`,
   `gadget_parfum`, `WorldItem`), 5 `referenced_by` updates.

4. **`docs/registry/architecture.yaml`** `gameplay_event_dispatch` row
   refreshed to 38 signals (`revised: 2026-04-24`). New
   `guard_drop_dart_on_parfum_ko = 0 LOCKED` forbidden-patterns entry
   adjacent to `guard_drop_dart_on_fist_ko = 0 LOCKED`.

This delta review (a) extracts 15 new Inventory TRs and verifies each maps
to an existing ADR, (b) validates the ADR-0002 amendment is internally
consistent and conflict-free, (c) flags two engine-verification gates
surfaced by Inventory's coord-item list, (d) confirms no new cross-ADR
conflicts were introduced.

**Verdict stays PASS**: architecture remains the cleanest it has been since
the fourth-run. The 15 Inventory TRs all have ADR coverage; the 2026-04-24
ADR-0002 amendment covers the 3 architectural changes Inventory requires
(2 new signals, 1 signature extension, 1 enum member). Zero hard
ADR-level gaps, zero cross-ADR conflicts, engine consistent.

---

## Traceability Summary

| | Prior 2026-04-23 (4th run) | This run | Δ |
|---|---|---|---|
| Total TRs | 160 | **175** | +15 new **TR-INV-001..015** |
| ✅ Covered | ~156 | ~171 | +15 (all Inventory TRs covered by existing ADRs) |
| ⚠️ Partial | ~3 | ~3 | — |
| ❌ Hard Gap | **0** | **0** | — |

### New Inventory TR coverage (TR-INV-001..015)

| TR-ID | Requirement (brief) | Covering ADR | Status |
|---|---|---|---|
| TR-INV-001 | `InventorySystem extends Node` as PC scene child — NOT autoload (7-slot cap holds) | ADR-0007 + arch.md §3.3 | ✅ |
| TR-INV-002 | 4 frozen Inventory signals (`gadget_equipped`, `gadget_used`, `weapon_switched`, `ammo_changed`) + `weapon_fired` emit-site | ADR-0002 | ✅ |
| TR-INV-003 | 2 new signals: `gadget_activation_rejected(gadget_id)` + `weapon_dry_fire_click(weapon_id)` | ADR-0002 (amended 2026-04-24) | ✅ |
| TR-INV-004 | `guard_incapacitated(guard: Node, cause: int)` — 2-param extension | ADR-0002 (amended 2026-04-24) | ✅ |
| TR-INV-005 | `CombatSystemNode.DamageType.MELEE_PARFUM` enum member (non-lethal; Parfum KO path) | ADR-0002 (amended 2026-04-24) + Combat GDD downstream-coord | ✅ |
| TR-INV-006 | `InventoryState extends Resource` with `ammo_magazine` + `ammo_reserve` two-dict split (untyped `Dictionary`) | ADR-0003 | ✅ |
| TR-INV-007 | Save registration via `LevelStreamingService.register_restore_callback` (NOT `SaveLoad.*`) | ADR-0003 + LS CR-10 | ✅ |
| TR-INV-008 | Tier 1 Heaviest outline on held weapons, held gadgets, and WorldItem pickups; FPS-hands ADR-0005 exception does NOT extend to held objects | ADR-0001 | ✅ |
| TR-INV-009 | `LAYER_PROJECTILES` for darts; `MASK_INTERACTABLES` for WorldItem; `MASK_GUARDS` for Parfum cone; `MASK_WORLD` for Cigarette Case placement raycast | ADR-0006 | ✅ |
| TR-INV-010 | HUD Core consumes Inventory signals via `project_theme.tres` + `FontRegistry`; Inventory does NOT touch UI | ADR-0004 | ✅ |
| TR-INV-011 | Event-driven; no `_process` / `_physics_process` tick; worst-case one-shot < 0.3 ms inside ADR-0008 Slot #8 pooled residual (0.8 ms) | ADR-0008 | ✅ |
| TR-INV-012 | Subscribes to `Events.enemy_killed`, `Events.guard_incapacitated`, `Events.player_interacted` via ADR-0002 `_ready`/`_exit_tree` lifecycle | ADR-0002 | ✅ |
| TR-INV-013 | Combat autoload (ADR-0007 line 7) `_unhandled_input` dispatches shared-binding `use_gadget`/`takedown` via `InventorySystem.try_use_gadget()` direct method call | ADR-0007 | ✅ (engine-verification gate — Coord #12) |
| TR-INV-014 | `SkeletonModifier3D` IK target for rifle held-mesh cross-subtree NodePath (HandAnchor under Camera3D vs body Skeleton3D) | — | ⚠️ Engine-verification gate — Coord #11 (rifle IK optional MVP; fallback: scope-out) |
| TR-INV-015 | `InteractPriority.Kind.PICKUP = 2` for Inventory; Document Collection owns `DOCUMENT = 0`; PC owns the enum declaration | PC GDD + Inventory GDD | ✅ GDD-scope |

**All 15 TRs covered.** TR-INV-013 and TR-INV-014 carry engine-verification
gate callouts (see §Engine Compatibility Audit); they are not ADR-level
gaps — they are Tech Setup phase engineering work.

### Coverage delta — other systems unchanged

| # | System | Covering ADRs | Status |
|---|--------|---------------|--------|
| 1–11, 13, 14 | Signal Bus, Input, Audio, Outline, Post-Process, Save/Load, Localization, Player Character, FootstepComponent, Level Streaming, Stealth AI, Combat & Damage | As 4th-run matrix | ✅ (unchanged) |
| 12 | **Inventory & Gadgets (NEW)** | ADR-0001, ADR-0002 (amended 2026-04-24), ADR-0003, ADR-0004, ADR-0006, ADR-0007, ADR-0008 | ✅ (all 15 TRs covered at system level) |

---

## Cross-ADR Conflict Detection

### ✅ All prior conflicts remain closed

- Conflict 1 (autoload line-4 collision) — CLOSED 2026-04-23 by ADR-0007.
- Conflict 2 (ADR-0002 section signals outdated) — CLOSED 2026-04-22 by
  ADR-0002 4th-pass.
- Conflict 3 (ADR-0002 missing SAI 4th-pass signals) — CLOSED 2026-04-22 by
  ADR-0002 4th-pass.
- Concern 1 (Combat-autoload in ADR-0002 + TR-CD-022 vs ADR-0007
  "6 autoloads") — CLOSED 2026-04-23 by ADR-0007 Path A amendment.

### ✅ ADR-0002 2026-04-24 amendment — no new cross-ADR conflicts

| Candidate conflict | Check | Result |
|--------------------|-------|--------|
| ADR-0002 amendment (38 signals, 2-param `guard_incapacitated`, `MELEE_PARFUM`) vs ADR-0007 (Combat line 7 autoload) | No autoload change; `Events.gd` + Combat both unchanged in boot position | ✅ Aligned |
| ADR-0002 amendment vs ADR-0003 (Resource schema) | No Resource schema changes in amendment | ✅ Aligned |
| ADR-0002 amendment vs ADR-0008 (frame budgets) | Both new signals bounded by player input rate (`gadget_activation_rejected` ≤1 per `use_gadget` press; `weapon_dry_fire_click` ≤1 per `fire_primary` press on dry weapon); trivially within Implementation Guideline 5 per-physics-frame envelope | ✅ Within budget |
| Enum-ownership list updated with `MELEE_PARFUM` | Combat owns the enum; SAI consumes `cause: int` via cross-autoload convention (no import graph coupling). Consistent with `LevelStreamingService.TransitionReason` precedent. | ✅ Consistent |
| Atomic-commit requirement for `guard_incapacitated` 1→2 param migration | Amendment explicitly documents: ADR + SAI GDD + Inventory GDD + `events.gd` in single PR; partial merges fail at autoload-register time | ✅ Documented in Risks row |

**No cross-ADR conflicts detected.**

### Dependency ordering — unchanged

```
Foundation (no ADR deps):
  1. ADR-0001: Stencil ID Contract
  2. ADR-0002: Signal Bus + Event Taxonomy (amended 2026-04-22 4th-pass + 2026-04-24 Inventory amendment)
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

⚠️ **All 8 ADRs remain `Proposed`.** Verification gate count **grew from 24 →
26** with two new godot-specialist engine gates surfaced by Inventory's
design review (see §Engine Compatibility Audit). Stories referencing a
Proposed ADR are auto-blocked.

| ADR | Gate count | Δ from 4th run |
|-----|-----------:|---|
| ADR-0001 | 4 | — |
| ADR-0002 | 1 | — (amendment does not retire Gate 1) |
| ADR-0003 | 3 | — |
| ADR-0004 | 3 | — |
| ADR-0005 | 5 | — |
| ADR-0006 | 3 | — |
| ADR-0007 | 1 | — (still byte-match against amended 7-entry `[autoload]` block) |
| ADR-0008 | 4 | — |
| (Engine) | +2 | **+2 new godot-specialist gates** (Coord #11 + #12) |
| **Total** | **26** | **+2** |

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-02-12)
**ADRs with Engine Compatibility section**: **8 / 8** ✓ (unchanged)

### Post-Cutoff API Usage — unchanged from prior run

The ADR-0002 2026-04-24 amendment introduces no new post-cutoff APIs.
Signal-declaration syntax is stable since Godot 4.0 per
`breaking-changes.md`. New `MELEE_PARFUM` enum member is pure GDScript enum
bodywork. No engine API contract changes.

| API | Since | ADRs consuming |
|-----|-------|----------------|
| Stencil buffer (`BaseMaterial3D` / `ShaderMaterial` write; `CompositorEffect` read) | 4.5 | ADR-0001 |
| `CompositorEffect` + `Compositor` node | 4.3 | ADR-0001, ADR-0005, ADR-0008 |
| Shader Baker | 4.5 | ADR-0001, ADR-0005 (A5), ADR-0008 |
| D3D12 default on Windows | 4.6 | ADR-0001, ADR-0005, ADR-0008 |
| `Resource.duplicate_deep()` | 4.5 | ADR-0003 |
| AccessKit screen reader | 4.5 | ADR-0004 |
| Dual-focus (mouse vs kb/gamepad) | 4.6 | ADR-0004 |
| Jolt 3D default | 4.6 | ADR-0006, ADR-0008 |
| `RenderingServer.get_frame_profile_measurement()` | 4.4 | ADR-0008 |

### Deprecated API Check

`grep` across all 8 ADRs for patterns in `deprecated-apis.md`: **clean**. No
`connect("sig", obj, "method")` at load-bearing sites, no `yield`, no bare
`duplicate()` without `_deep`, no `get_world()`, no `VisibilityNotifier*`,
no `TileMap`, no `Navigation2D`/`3D`. The Inventory GDD explicitly chose
**untyped `Dictionary`** over `TypedDictionary[StringName, int]` (CR-11 +
CR-6 rationale: `TypedDictionary` serialization stability with
`ResourceSaver` unverified post-cutoff; the ADR-0003-compliant choice is
untyped `Dictionary` with `## StringName -> int` doc comment) — this is
consistent with ADR-0003 and is flagged as a VERIFY-AT-IMPL upgrade
candidate for Technical Setup.

### Stale Version References

None. All 8 ADRs pinned to 4.6.
- ADR-0002 Last Verified updated to 2026-04-24 (amendment date).
- ADR-0007 Last Verified = 2026-04-23 (prior amendment).
- ADR-0008 Last Verified = 2026-04-23.
- All others unchanged from prior runs.

### Post-Cutoff API Conflicts Between ADRs

None. No new inter-ADR post-cutoff API claims introduced this run.

### 🟡 New Engine-Verification Gates (Inventory Coord items #11 and #12)

These two gates are **Tech Setup scope**, not architectural gaps. They are
Inventory-GDD-surfaced engine behavior questions that must be verified in
the Godot 4.6 editor before the Inventory sprint begins.

| Coord item | Engine concern | Risk | Fallback |
|---|---|---|---|
| **#11** | Does `SkeletonModifier3D` target NodePath resolve across scene-subtree boundaries? Specifically: HandAnchor lives under `Camera3D`; player body `Skeleton3D` lives in a different subtree. If NodePath cannot cross the boundary, the rifle IK target cannot reach `Marker3D` nodes inside the weapon's PackedScene. | MEDIUM — rifle IK is a V.5 animation spec; failure means reaching for option (a) world-space `Transform3D` propagation per frame (perf cost in Slot #5), or option (b) scope rifle IK out of MVP (visual regression) | (a) or (b); confirmed by godot-specialist + TD |
| **#12** | Combat is an autoload (ADR-0007 line 7). Inventory CR-4 relies on Combat's autoload `_unhandled_input` to receive `use_gadget` / `takedown` events reliably **after** GUI/scene-node consumption. Autoload + `_unhandled_input` tree-order is non-obvious in Godot 4.6. | HIGH for Inventory sprint day 1 — failure requires refactoring Combat's input capture from `_unhandled_input` to `Input.is_action_just_pressed()` polling in `_physics_process`; doable but changes the entire dispatch pattern | Fallback pattern is documented in Coord item #12; doesn't require an ADR amendment (implementation choice) |

**Engine specialist consultation: SKIPPED** for this review run (same
rationale as prior runs — amendment is signal-declaration-only; no new
engine API). Both engine-verification gates above should be executed by
godot-specialist in Tech Setup phase before Inventory sprint commences.

**Re-run the specialist next cycle if** (a) Coord #11 or #12 verification
yields unexpected behavior, (b) any ADR verification gate surfaces engine
behavior not captured in reference docs, (c) a previously-deferred ADR
(outline algorithm, audio architecture, post-process chain) is promoted,
(d) engine version pin changes, or (e) `/design-system failure-respawn`
triggers a second ADR-0007 amendment for line 8.

---

## Design Revision Flags (Architecture → Design Feedback)

### ⚠️ Two GDD assumptions conflict with Inventory GDD CR contracts

Both are **already acknowledged** as Inventory coord items (#9, #10) and as
downstream-scope items in the ADR-0002 2026-04-24 amendment. They are not
architectural conflicts — they are text-alignment coordination items.
Equivalent in nature to the 4th-run PC rename / Audio LS-Gate-3 / Input
takedown-split coordination that all closed within one session.

| GDD | Current text | Reality (per Inventory GDD) | Action |
|-----|---|---|---|
| `design/gdd/input.md` L91 | "Both systems check their own gate" (two independent handlers with mutex) | Combat owns a **single-dispatch** `_unhandled_input` handler that calls `InventorySystem.try_use_gadget()` directly; Inventory does NOT install a handler for `use_gadget` | Revise L91 to "Dispatched by Combat's single `_unhandled_input` handler per Inventory CR-4; Inventory exposes `try_use_gadget()` as a public method and does not install a handler for this action." |
| `design/gdd/save-load.md` L102 | `InventoryState`: `ammo: Dictionary[StringName, int]` (single flat dict) | Two dicts: `ammo_magazine` + `ammo_reserve` per Inventory CR-11; registered via `LevelStreamingService.register_restore_callback` (not `SaveLoad.*`) | Update row to the two-dict split; add clarification that Inventory registers via LSS, not SaveLoad |

Inventory's Coord items #9 and #10 are BLOCKING pre-sprint. Both are small
text edits (estimated <5 min each) and should close within one follow-up
session.

### ✅ No GDD-to-engine revision flags

No GDD assumption conflicts with verified engine behavior. The 2026-04-24
amendment preserves all prior GDD-to-ADR alignment achieved in the 4th
run.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v1.0, ~1688 lines, 2026-04-23) remains
accurate for this delta:

- **§3.3** (System Layer Map — Feature Layer): correctly lists
  InventorySystem as a child node of PlayerCharacter, consuming the
  priority-2 `interact` slot. No update needed.
- **§4** (Module Ownership): Inventory module row exists with
  Owns/Exposes/Consumes fields accurate as of this GDD. No update needed.
- **§5** (Data Flow): the `weapon_fired` emit → subscriber fan-out flow
  unchanged. The new `gadget_activation_rejected` and
  `weapon_dry_fire_click` signals fit the existing event-driven model
  (bounded cadence; no flow diagram change needed).
- **§6** (API Boundaries): no new static helpers introduced;
  `InputActions.TAKEDOWN_OR_GADGET` constant is covered by the existing
  `InputActions` helper.

No structural or load-bearing content changes. No orphaned architecture
entries. No systems from `systems-index.md` missing from the layer map.

---

## Verdict: **PASS**

### Why PASS (re-affirmed)

- **Zero hard ADR-level gaps** — all 15 new Inventory TRs map to existing
  ADRs; the 2026-04-24 amendment covers the 3 architectural changes
  Inventory needs (2 new signals, 1 signature extension, 1 enum member).
- **Zero cross-ADR conflicts** — ADR-0002 2026-04-24 amendment is
  internally consistent and preserves all prior invariants.
- **Engine consistent** — 8 ADRs pinned to Godot 4.6; no deprecated-API
  consumption; no contradictory post-cutoff API assumptions. 2 new
  engine-verification gates are Tech Setup scope, not architectural
  decisions.
- **Dependency graph clean** — no cycles; topological order unchanged.
- **GDD revision flags are coordinative, not architectural** — Input L91
  and save-load.md L102 are small text edits already tracked as
  pre-sprint BLOCKING coord items.
- **OQ-INV-1 RESOLVED (Option B)** — Parfum-KO drops nothing; ADR-0002
  amendment reflects this; registry invariant
  `guard_drop_dart_on_parfum_ko = 0 LOCKED` registered.

### Execution-phase items remaining (do not block PASS)

1. **26 verification gates outstanding** across 8 Proposed ADRs + 2 new
   godot-specialist gates (Coord #11 + #12). These move ADRs Proposed →
   Accepted and resolve Inventory engine-behavior assumptions.

2. **6 BLOCKING Inventory coord items**:
   - **#2 ADR-0002 amendment** — ✅ CLOSED 2026-04-24 (this review verified).
   - **#3 Registry Phase 5b** — ✅ PARTIALLY CLOSED 2026-04-24 (6 entries +
     stale-fix landed; 2 small registry entries `compact_activation_noise_radius`,
     `medkit_max_per_mission` can land during sprint).
   - **#7 SAI BAIT_SOURCE EVENT_WEIGHT row** — OPEN (SAI GDD maintainer).
   - **#8 Combat `apply_fire_path` method declaration** — OPEN (combat-damage.md maintainer).
   - **#9 Input GDD L91 single-dispatch clarification** — OPEN (Input GDD maintainer).
   - **#10 save-load.md InventoryState two-dict schema** — OPEN (save-load.md maintainer).

3. **OQ-INV-3** (PC `is_hand_busy()` scope during SWITCHING) — BLOCKING per
   Inventory; Option B default (Inventory-internal gate, defensive)
   implementable if PC decision slips.

4. **12 MVP GDDs outstanding** — Inventory landed as 11/23 designed this
   session. Next unblocked: `failure-respawn` (#14; may trigger second
   ADR-0007 amendment for line 8) or `mission-level-scripting` (#13;
   forward-dep consumer of Inventory's `WorldItem` + F&R contract).

---

## Priority Action List (next 2–3 sessions)

### Session A — Close Inventory BLOCKING coord items (text edits)

1. SAI GDD row touch-up (Coord #1) + SAI GDD BAIT_SOURCE EVENT_WEIGHT row
   (Coord #7) + SAI `guard_incapacitated` emit-site extension (pass
   `_last_damage_type` as 2nd param per atomic-commit requirement).
2. Combat GDD `apply_fire_path` method declaration (Coord #8) + Combat §C.3
   DamageType table `MELEE_PARFUM` row.
3. Input GDD L91 single-dispatch clarification (Coord #9).
4. save-load.md line 102 two-dict `ammo_magazine`/`ammo_reserve` + LSS
   registration note (Coord #10).

Estimated effort: 4 small edits; 1 short session total (<1 hour).

### Session B — Execute godot-specialist engine-verification gates

1. **Coord #11**: Spike test in Godot 4.6 editor — does
   `SkeletonModifier3D` target NodePath resolve across Camera3D subtree
   boundary? If NO, choose option (a) world-space Transform3D or option
   (b) scope-out rifle IK.
2. **Coord #12**: Spike test — does Combat autoload's `_unhandled_input`
   receive `use_gadget`/`takedown` events reliably after GUI/scene-node
   consumption? If NO, refactor to `Input.is_action_just_pressed()` polling
   in `_physics_process`.

Both gates should execute before Inventory sprint day 1.

### Session C — Continue MVP GDD authoring

Next unblocked:
- `/design-system failure-respawn` (system #14) — if autoload elected,
  triggers second ADR-0007 amendment for line 8.
- `/design-system mission-level-scripting` (system #13) — forward-dep
  consumer of Inventory's `WorldItem` + F&R restore contract.

---

**Re-run trigger**: `/architecture-review` after (a) any verification gate
passes (an ADR moves Proposed → Accepted), (b) next MVP GDD lands, (c)
godot-specialist engine gates Coord #11 or #12 surface unexpected
behavior requiring an ADR amendment, or (d) `/design-system
failure-respawn` elects autoload (triggers ADR-0007 2nd amendment for
line 8).

**Gate guidance**: `/gate-check pre-production` remains premature until
(a) the 4 remaining Inventory BLOCKING coord items close, (b) some
verification gates begin passing, (c) a few more MVP GDDs land.

---

## Related

- `docs/architecture/requirements-traceability.md` — refreshed this run
  (System 12 Inventory added; 15 new TR-INV-* entries registered;
  fifth-run history entry appended)
- `docs/architecture/tr-registry.yaml` — **15 new TR-INV-* entries
  appended** (TR-INV-001 through TR-INV-015); `last_updated: 2026-04-24`
- `docs/architecture/architecture-review-2026-04-23.md` — prior (fourth)
  run baseline
- `docs/architecture/architecture-review-2026-04-22.md` — initial
  full-matrix baseline
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — **amended
  2026-04-24** (38 signals; `guard_incapacitated` 2-param;
  `MELEE_PARFUM`)
- `design/gdd/inventory-gadgets.md` — **NEW 2026-04-24** (1608 lines;
  Approved pending Coord items)
- `design/gdd/systems-index.md` — row 12 marked Approved pending Coord
  items; Progress Tracker 10/16 → 11/16 MVP designed
- `design/registry/entities.yaml` — Phase 5b landed (stale-fix + 6 new +
  5 referenced_by)
- `docs/registry/architecture.yaml` — `gameplay_event_dispatch` row
  refreshed (38 signals); `guard_drop_dart_on_parfum_ko = 0 LOCKED` added
- `production/session-state/active.md` — fifth-run extract appended
