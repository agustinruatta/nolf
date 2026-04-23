# ADR-0007: Autoload Load Order Registry

## Status

**Proposed** — moves to Accepted once (a) the `project.godot` `[autoload]` block is
generated with the line order specified in §Key Interfaces, and (b) ADR-0002 Gate 1
smoke test passes (emit → EventLogger prints → subscriber receives — incidentally
validates the cross-autoload reference safety discipline).

## Date

2026-04-23

## Last Verified

2026-04-23

## Decision Makers

User (project owner) · godot-specialist (validation 2026-04-22 §1 + 2026-04-23
pre-authoring Claims 1/2/3) · `/architecture-decision` skill

## Summary

*The Paris Affair* registers **6 autoloads** in a single canonical order that this
ADR defines and owns:

**Events (1) → EventLogger (2) → SaveLoad (3) → InputContext (4) → LevelStreamingService (5) → PostProcessStack (6)**

The engine only honours line order within the `project.godot [autoload]` block —
"load order N" labels in ADRs and GDDs are team-documentation and drift-prone. This
ADR supersedes every "load order N" statement in existing ADRs/GDDs with a pointer
to this registry. Adding a new autoload, removing one, or changing the order
requires an amendment to this ADR in the same PR that edits `project.godot`. A
forbidden pattern (`unregistered_autoload`) fences against ad-hoc registration via
editor plugins, `@tool` scripts, or `add_autoload_singleton()` runtime calls.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (autoload infrastructure) |
| **Knowledge Risk** | LOW — `[autoload]` block semantics stable since Godot 4.0; no changes in 4.4 / 4.5 / 4.6 per `breaking-changes.md`. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, godot-specialist validation 2026-04-22 §1 (line-order authority) and 2026-04-23 pre-authoring consultation (Claims 1/2/3 GREEN/YELLOW/YELLOW). |
| **Post-Cutoff APIs Used** | None. `project.godot` `[autoload]` block syntax is stable since 4.0. `*res://` path-prefix-star syntax confirmed correct for "scene-mode" autoloads (Node added to root; `_ready()` fires; tree lifecycle active). |
| **Verification Required** | None new. ADR-0002 Gate 1 (smoke test: emit one signal → EventLogger prints it → subscriber receives it) incidentally validates line-order-based cross-autoload reference safety — EventLogger is at line 2 and must successfully subscribe to Events signals declared by the line-1 autoload. |

> **Note**: LOW Knowledge Risk. The specialist consultation confirmed the `[autoload]`
> block line order is the engine's sole authoritative declaration across 4.3 → 4.6.
> No behaviour change in this area.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — foundational infrastructure ADR. The registry table *references* but does not *require Acceptance* of ADR-0002 (Events + EventLogger), ADR-0003 (SaveLoad), ADR-0004 (InputContext + PostProcessStack). |
| **Enables** | `project.godot` scaffolding at Technical Setup phase; resolves the autoload-ordering coordination that was blocking `/gate-check pre-production`. |
| **Blocks** | `project.godot [autoload]` block generation; `/architecture-review pass` verdict (Gap 3 closure). |
| **Ordering Note** | Can be Accepted in parallel with ADR-0002 through ADR-0006 — this ADR documents and disambiguates what those already say, it does not redefine behaviour. Downstream ADR/GDD edits are in-place text amendments, not re-decisions. |

## Context

### Problem Statement

Six autoloads across four existing ADRs and three GDDs specify load orders
independently:

- `Events` at "load order 1" (ADR-0002)
- `EventLogger` at "load order 2" (ADR-0002)
- `SaveLoad` at "load order 3" (ADR-0003)
- `InputContext` at "load order 4" (ADR-0004)
- **`LevelStreamingService` at "load order 4"** (LS GDD CR-1) — **collision with `InputContext`**
- `PostProcessStack` — autoload per ADR-0004 Implementation Guideline 7 + PP GDD §5, but **order unstated**

The `/architecture-review 2026-04-22` flagged the collision as Conflict 1 and the
editorial hazard as Gap 3. A godot-specialist consultation on 2026-04-22 §1
established that "load order N" labels in ADRs and GDDs are team-documentation —
the engine only honours line order within the `project.godot [autoload]` block. A
future developer reading both "load order 4" statements could write wire-up
assuming simultaneous init; whichever autoload initialises second would be
observed as `null`.

A 2026-04-23 targeted specialist consultation against the draft of this ADR
confirmed three engine realities:

1. **Line-order authority** (GREEN) — re-confirmed across 4.3 → 4.6.
2. **Cross-autoload reference safety in `_ready()`** (YELLOW) — correct in substance
   but requires framing correction (instantiation order vs `_ready()` order
   distinction) and an explicit `_init()` restriction.
3. **Tooling stability** (YELLOW) — stable in normal operation, but `@tool` scripts
   calling `add_autoload_singleton()` and runtime `Engine.register_singleton()` can
   silently mutate the block.

All three findings are incorporated below.

### Current State

Pre-production. `project.godot` does not yet exist. No source code. No autoload
registration has been attempted. This ADR is the source of truth from which the
`[autoload]` block will be generated at Technical Setup.

### Constraints

- Engine: Godot 4.6; GDScript primary.
- "load order N" labels are team-documentation, not engine-enforced (specialist §1).
- The `[autoload]` block is the single authoritative declaration.
- No project plugins or `@tool` scripts exist yet; the stability assumption holds for current state but is fenced for future plugin additions.
- All 6 autoloads use `*res://` "scene-mode" (Node added to root; `_ready()` fires; tree lifecycle active) — confirmed correct syntax by specialist.

### Requirements

- Single canonical registration order for all 6 project autoloads.
- Order MUST satisfy every forward-dependency edge (a consumer-autoload initialises after every producer-autoload it references in `_ready()`).
- Fence against ad-hoc registration drift (`@tool` scripts, `add_autoload_singleton()`, editor plugins).
- Downstream ADRs/GDDs reference this ADR for order; do NOT re-state order numbers.
- Amendment bar for new autoloads: (a) justification that the new system cannot be a static class / scene Node / RefCounted; (b) row added to this registry; (c) `project.godot` edit in the same PR.

## Decision

**Establish a single canonical autoload registration order, locked in the table
below. Generate the `project.godot [autoload]` block from this table. Downstream
ADRs/GDDs reference this ADR for the authoritative order; they do NOT re-state
specific line numbers.** A forbidden pattern (`unregistered_autoload`) prevents
ad-hoc registration.

### Canonical Registration Table

| Line | Autoload Key | Script Path | Source ADR / GDD | Consumes (autoloads only) |
|------|--------------|-------------|------------------|---------------------------|
| 1 | `Events` | `*res://src/core/signal_bus/events.gd` | ADR-0002 | — (foundational hub; no autoload dependencies) |
| 2 | `EventLogger` | `*res://src/core/signal_bus/event_logger.gd` | ADR-0002 | `Events` (subscribes to all signals at `_ready()`) |
| 3 | `SaveLoad` | `*res://src/core/save_load/save_load_service.gd` | ADR-0003 | `Events` (emits `game_saved` / `game_loaded` / `save_failed`) |
| 4 | `InputContext` | `*res://src/core/ui/input_context.gd` | ADR-0004 | — (no signals; no autoload references in `_ready()`) |
| 5 | `LevelStreamingService` | `*res://src/core/level_streaming/level_streaming_service.gd` | LS GDD CR-1 | `InputContext` (pushes `LOADING` at 13-step swap step 1), `Events` (emits `section_entered` / `section_exited`), `SaveLoad` (consumes `SaveGame` via `register_restore_callback` chain at step 9) |
| 6 | `PostProcessStack` | `*res://src/core/rendering/post_process_stack.gd` | ADR-0004 IG7 + PP GDD §5 | `Events` (subscribes to `setting_changed` for `resolution_scale`) |

### Rationale for line order

- **(1) Events first** — foundational typed-signal hub; every other autoload either subscribes to Events signals or emits through them. Must precede every autoload that touches the bus.
- **(2) EventLogger** — debug-only; connects to every Events signal at `_ready()` then self-removes in non-debug builds via `OS.is_debug_build()`. Load-bearing dependency on line 1.
- **(3) SaveLoad** — foundational persistence. Consumed by LSS at step 9 of the swap contract. No dependency on InputContext / LSS / PostProcessStack.
- **(4) InputContext** — consumed by LSS (`InputContext.push(LOADING)` at step 1 of the 13-step swap). Must load BEFORE LSS.
- **(5) LevelStreamingService** — consumer of InputContext + Events + SaveLoad. Position IS load-bearing per specialist Claim 2: LSS's `_ready()` safely references autoloads 1–4 because they are all earlier in the block.
- **(6) PostProcessStack** — consumes only `Events.setting_changed` (valid at any position ≥ 2). Placed last because nothing else depends on it at `_ready()` time; position 6 minimises the insertion-point for a future "order shuffled by editor plugin" hazard affecting upstream consumers.

### Key Interfaces

```gdscript
# project.godot — [autoload] block MUST match this exact line order.
# Each entry uses the `*res://` path-prefix-star syntax to declare scene-mode
# (Node added to root at startup; _ready() fires; tree lifecycle active).
#
# The `*` prefix is REQUIRED. Without it, the entry is script-mode (script
# loaded, name available, but no Node in the tree, no _ready(), no signal
# lifecycle) — which breaks every autoload in this registry, all of which
# extend Node and rely on _ready() and/or tree membership.

[autoload]

Events="*res://src/core/signal_bus/events.gd"
EventLogger="*res://src/core/signal_bus/event_logger.gd"
SaveLoad="*res://src/core/save_load/save_load_service.gd"
InputContext="*res://src/core/ui/input_context.gd"
LevelStreamingService="*res://src/core/level_streaming/level_streaming_service.gd"
PostProcessStack="*res://src/core/rendering/post_process_stack.gd"
```

### Cross-Autoload Reference Safety

*Authoritative specification — supersedes any equivalent statement in existing
ADRs/GDDs. Derived from godot-specialist 2026-04-23 Claim 2 YELLOW verdict with
framing corrections folded in.*

1. **By the time autoload N's `_ready()` fires, autoloads 1 through N−1 are all in the scene tree** (instantiated and added via `add_child()` on the root). Their `_ready()` calls may or may not have completed but their variables are initialized and they are reachable by autoload key.
2. **An autoload's `_ready()` MAY reference any earlier autoload by name.** Example: `EventLogger._ready()` may call `Events.signal_name.connect(...)` because `Events` is at line 1 and `EventLogger` is at line 2.
3. **An autoload's `_ready()` MUST NOT reference a later autoload by name.** The later autoload is not yet in the tree when the earlier one's `_ready()` runs; the reference would resolve to `null`.
4. **No autoload's `_init()` may reference any other autoload.** `_init()` fires during object construction, before the node is added to the tree. Other autoloads are unreachable via the tree from `_init()`. Registered as forbidden pattern `autoload_init_cross_reference`.
5. **GDScript parse-time class references (e.g., `LevelStreamingService.TransitionReason` as a signal payload type on `Events.gd`) are resolved across the project at parse time regardless of autoload order** — so a parse failure here is NOT a load-order issue; it is a commit-atomicity issue handled by the ADR-0002 2026-04-22 Risks row. Autoload order does not fix or cause that class of failure.

### Implementation Guidelines

1. **The `project.godot [autoload]` block MUST be generated from §Key Interfaces verbatim.** No reordering by the Godot editor UI, no alphabetisation, no rewrites by `@tool` scripts.
2. **All 6 entries use `*res://` path-prefix-star syntax.** Script-mode (no `*` prefix) is not supported by this registry — every autoload in the table extends `Node` and requires tree lifecycle.
3. **`_init()` MUST NOT reference any other autoload by name.** Registered as forbidden pattern `autoload_init_cross_reference`. Cross-autoload setup belongs in `_ready()`.
4. **`_ready()` MAY reference autoloads at earlier line numbers only.** Referencing a later autoload from `_ready()` is undefined (the later autoload is not yet in the tree).
5. **Game code MUST NOT call `Engine.register_singleton()` at runtime.** Registered as optional forbidden pattern `runtime_singleton_registration`. Test doubles that need named-instance registration use dependency injection (per the existing project test pattern), not runtime singleton registration.
6. **`@tool` scripts and editor plugins MUST NOT call `ProjectSettings.set_setting()` / `add_autoload_singleton()` on autoload paths.** Registered under the `unregistered_autoload` forbidden pattern. Any future plugin addition requires a paired ADR-0007 amendment documenting the resulting `[autoload]` block order.
7. **Downstream ADRs/GDDs MUST NOT restate specific line numbers.** Reference this ADR instead: e.g., *"`LevelStreamingService` is an autoload (per ADR-0007)"* rather than *"`LevelStreamingService` is an autoload at load order 5"*. Line numbers in *this ADR* (§Canonical Registration Table) are the sole authoritative statement.

## Alternatives Considered

### Alternative 1: Surgical in-place fix across ADR-0004 + LS GDD + `project.godot` (no new ADR)

- **Description**: Amend ADR-0004 to confirm `InputContext` at order 4; amend LS GDD CR-1 to move `LevelStreamingService` to order 5; establish the `project.godot [autoload]` block line order directly without a separate ADR.
- **Pros**: Minimum-viable fix; no new ADR to maintain; fewer documents to update.
- **Cons**: Does not address `PostProcessStack`'s unstated order. Does not prevent future recurrence — the same collision hazard could re-emerge when Inventory / Civilian AI / Mission Scripting systems propose autoloads. Scattered authority — no single place to see "what autoloads does the project register, and why?".
- **Rejection reason**: The scale of the current problem (6 autoloads, 1 collision, 1 unstated) and the projected scale as more systems are authored (Inventory, Civilian AI, Mission Scripting may each propose an autoload) justify a dedicated registry. Fence design requires a single authoritative artifact.

### Alternative 2: Rely on `project.godot` alone as documentation

- **Description**: Delete every "load order N" statement from ADRs and GDDs. Treat `project.godot` as the single source of truth. No ADR-level documentation of order or rationale.
- **Pros**: Zero documentation drift by construction; matches engine reality (only `project.godot` matters).
- **Cons**: Loses design-time rationale ("why is LSS after InputContext?"). Reviewers cannot validate ordering in code review without opening `project.godot` and reconstructing intent. The dependency graph becomes tribal knowledge.
- **Rejection reason**: The sequencing rationale (which consumer depends on which producer) is load-bearing design knowledge that belongs in an ADR. `project.godot` shows the WHAT; the ADR shows the WHY.

### Alternative 3: Multiple per-domain registries

- **Description**: Split the registry into foundational (Events, EventLogger, SaveLoad), UI (InputContext, PostProcessStack), and level-system (LevelStreamingService) sub-registries, each documented in the owning domain's ADR.
- **Pros**: Each registry smaller; domain-owned.
- **Cons**: No single cross-cutting view; re-introduces the exact problem this ADR solves (multiple sources of truth for order). The `[autoload]` block is inherently global.
- **Rejection reason**: The block is a single global ordering; splitting documentation across sub-registries defeats the purpose.

## Consequences

### Positive

- Conflict 1 from `/architecture-review 2026-04-22` resolved (`InputContext`→4, `LevelStreamingService`→5).
- Gap 3 from `/architecture-review 2026-04-22` resolved (`PostProcessStack` explicit at 6).
- Single authoritative source for autoload order; future developers have one document to consult.
- Fence (`unregistered_autoload` forbidden pattern) prevents the four drift hazards identified by specialist: (a) plugin-added autoloads, (b) `@tool` `add_autoload_singleton()` calls, (c) runtime `Engine.register_singleton()` calls, (d) manual `project.godot` reshuffling without ADR amendment.
- Cross-autoload reference safety (`_ready()` vs `_init()`) finally specified authoritatively. Previously scattered across ADR-0002, LS GDD, and implicit developer knowledge.

### Negative

- Bulk downstream text edits required across ADR-0002, ADR-0003, ADR-0004, `signal-bus.md`, `level-streaming.md` (20+ sites) to redirect "load order N" statements to "per ADR-0007". Scheduled to land in the same PR as this ADR.
- One more ADR to maintain. Amendment required on every new autoload — bars entry but adds friction. Justified by the cost of the collision-class bug.

### Neutral

- This ADR only documents and fences what already exists implicitly. It does not change any runtime behaviour beyond making the `project.godot` line order explicit.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A future developer adds an autoload via the Godot Project Settings GUI without an ADR amendment | MEDIUM | HIGH | `unregistered_autoload` forbidden pattern in `architecture.yaml`; code review checklist item: "if this PR edits `project.godot [autoload]` block, is there a paired ADR-0007 amendment?"; optional CI guard: a script diffs the `[autoload]` block against this ADR's §Key Interfaces table. |
| An editor plugin or `@tool` script calls `ProjectSettings.set_setting()` / `add_autoload_singleton()` and silently mutates the block | LOW (no plugins in current project state) | HIGH | Explicit fence in Implementation Guideline 6: no `@tool` scripts or editor plugins may call these APIs on autoload paths without a paired ADR-0007 amendment documenting the resulting block order. Re-verify at every plugin addition. |
| Game code calls `Engine.register_singleton()` at runtime, shadowing an autoload name | LOW | HIGH | Forbidden pattern `runtime_singleton_registration` (optional). No production use case. Test doubles use dependency injection, not runtime singleton registration. |
| An autoload's `_init()` references another autoload by name and silently null-derefs (or an earlier autoload references a later autoload from `_ready()`) | MEDIUM | MEDIUM | §Cross-Autoload Reference Safety is authoritative. Implementation Guidelines 3 + 4. Forbidden pattern `autoload_init_cross_reference`. Code review every new autoload `_init()` / `_ready()` edit. |
| GDScript parse-time class reference failure (e.g., `Events.gd` references `LevelStreamingService.TransitionReason` before the owning script declares the enum) | LOW | HIGH | NOT a load-order issue — GDScript resolves class references at parse time across the project regardless of autoload order. Handled by ADR-0002's 2026-04-22 atomic-commit Risks row (same-PR enum + signal + consumer changes). Noted here for clarity so that reviewers do not try to "fix" it by reshuffling autoload order. |
| Order drifts over time as ADR text + `project.godot` diverge | LOW | MEDIUM | Optional CI script parses the `project.godot [autoload]` block and compares to §Key Interfaces. Drift = CI failure. Implementation of the script is post-MVP. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (autoload instantiation at startup) | N/A (no project.godot yet) | ~6 × <1 ms ≈ <6 ms total startup autoload cost | <50 ms total project startup budget |
| Memory (static autoload cost) | N/A | 6 nodes in tree, <50 KB combined; SaveLoadService + LevelStreamingService hold the most state via Resources and fade overlay | <1 MB steady-state autoload footprint |
| Runtime | N/A | Zero runtime impact — this ADR is a registration/documentation contract | — |

## Migration Plan

No existing code. Implementation order:

1. **This ADR lands** with a paired bulk text edit across the 20+ downstream "load order N" sites (see §Downstream sites requiring paired text edits below) replacing each with "per ADR-0007" references. Single atomic PR.
2. When Technical Setup phase creates `project.godot`, the `[autoload]` block is generated from §Key Interfaces verbatim.
3. ADR-0002 Gate 1 (smoke test) incidentally validates the `_ready()`-ordering discipline: `EventLogger`'s `_ready()` successfully subscribes to `Events` signals declared in `events.gd`. If Gate 1 passes, line-order authority (specialist Claim 1) and cross-autoload reference safety (specialist Claim 2) are both confirmed empirically.
4. No rollback scenario. The registration order is derived from dependency edges in §Decision. If a new dependency edge is discovered that conflicts with this order, the ADR amendment fixes it; the same PR edits `project.godot`.

## Validation Criteria

- [ ] **Gate 1**: `project.godot [autoload]` block contains exactly 6 entries in the §Key Interfaces order, using `*res://` prefix on every entry, matching the §Key Interfaces block byte-for-byte (modulo whitespace).
- [ ] **Gate 2**: ADR-0002 Gate 1 smoke test (emit → EventLogger prints → subscriber receives) passes. Incidentally validates Cross-Autoload Reference Safety.
- [ ] All "load order N" statements in ADR-0002, ADR-0003, ADR-0004, `signal-bus.md`, `level-streaming.md` are replaced with "per ADR-0007" references (see §Downstream sites).
- [ ] 2 forbidden patterns registered in `docs/registry/architecture.yaml`: `unregistered_autoload`, `autoload_init_cross_reference`. Optional third: `runtime_singleton_registration`.
- [ ] 1 `api_decisions` row registered: `autoload_registration_order` → pattern `declarative_registry`, owner `adr-0007`.

## GDD Requirements Addressed

### Direct GDD drivers

| GDD Document | Requirement | How This ADR Satisfies It |
|--------------|-------------|---------------------------|
| `design/gdd/signal-bus.md` | "The `Events.gd` autoload is registered at game start. The optional `EventLogger.gd` debug autoload self-removes in non-debug builds" (§Stateless infrastructure) | `Events` at line 1, `EventLogger` at line 2. |
| `design/gdd/save-load.md` | "SaveLoadService autoload writes/reads only" | `SaveLoad` at line 3. |
| `design/gdd/level-streaming.md` | CR-1: "`LevelStreamingService` is an autoload. Load order 4 (after Events at 1, EventLogger at 2, SaveLoad at 3)." | **Supersedes** CR-1's "Load order 4" → line 5 (after `InputContext` at 4). LS GDD CR-1 text updated in the paired edit. |
| `design/gdd/post-process-stack.md` | §5: "The PostProcessStack autoload owns the sepia dim state." | `PostProcessStack` at line 6 (now explicit). |
| `design/gdd/input.md` | (via ADR-0004) `InputContext` autoload for modal input routing. | `InputContext` at line 4. |

### Downstream sites requiring paired text edits

The following sites restate "load order N" and are updated in the paired PR to
reference "per ADR-0007":

- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — L56 (Revision History parenthetical), L141 (diagram), L163 (diagram), L174 (header comment), L328–329 (Implementation Guideline 1), L330 (Implementation Guideline 2 parenthetical for LSS), L428–429 (Migration Plan), L438 + L442 (Validation Criteria), L466 (Related)
- `docs/architecture/adr-0003-save-format-contract.md` — L99 (diagram), L156 (comment), L348 (Validation Criteria)
- `docs/architecture/adr-0004-ui-framework.md` — L90 (Implementation Guideline 2), L132 (diagram), L184 (comment), L365 (Migration Plan), L381 (Validation Criteria)
- `design/gdd/signal-bus.md` — L44 (Stateless infra), L106 (Edge cases), L149 (Tuning Knobs row), L177 (AC-1)
- `design/gdd/level-streaming.md` — L36 (CR-1 — includes the `InputContext`→4 / `LevelStreamingService`→5 order flip)

## Related

- **ADR-0002** (Signal Bus + Event Taxonomy) — declares `Events` + `EventLogger` autoloads; this ADR pins their line-order and supersedes their individual "load order 1/2" statements.
- **ADR-0003** (Save Format Contract) — declares `SaveLoad` autoload; this ADR pins its line-order and supersedes its "load order 3" statements.
- **ADR-0004** (UI Framework) — declares `InputContext` + `PostProcessStack` autoloads; this ADR pins their line-order, resolves the ADR-0004 `InputContext`-vs-LS GDD collision, and makes `PostProcessStack` position explicit.
- **`design/gdd/level-streaming.md`** CR-1 — declares `LevelStreamingService` autoload; this ADR supersedes the CR-1 "Load order 4" statement and moves LSS to line 5.
- **`docs/registry/architecture.yaml`** — 2 forbidden patterns (`unregistered_autoload`, `autoload_init_cross_reference`) and 1 `api_decisions` row (`autoload_registration_order` → `declarative_registry`) registered by this ADR. Optional 3rd forbidden pattern: `runtime_singleton_registration`.
- **godot-specialist validation** — 2026-04-22 §1 (line-order authority) + 2026-04-23 pre-authoring consultation (Claims 1/2/3 GREEN/YELLOW/YELLOW; framing correction for Claim 2 incorporated into §Cross-Autoload Reference Safety; hazards #1/#2/#3 incorporated into Risks table).
- **`docs/architecture/architecture-review-2026-04-23.md`** — identifies Gap 3 + Conflict 1 that this ADR resolves; recommends "dedicated registry ADR" over the surgical alternative.
