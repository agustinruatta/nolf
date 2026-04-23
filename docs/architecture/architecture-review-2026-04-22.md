# Architecture Review Report

| Field | Value |
|-------|-------|
| **Date** | 2026-04-22 |
| **Mode** | `/architecture-review` (full) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **GDDs Reviewed** | 12 |
| **ADRs Reviewed** | 6 (all Proposed; none Accepted) |
| **TR Registry State on Entry** | empty — this review populates it |
| **Verdict** | **CONCERNS** |

---

## Summary

First full architecture review for *The Paris Affair*. The ADR set covers the major architectural contracts — stencil outlining, signal bus, save format, UI framework, FPS-hands render exception, collision layers — and the majority of MVP system GDDs have clean ADR coverage. **Two structural gaps are blocking, both inside the existing ADR-0002 amendment scope**: the 2026-04-22 amendment landed only the Stealth-AI-side changes and left (a) Level Streaming's `TransitionReason` signal parameter and (b) the SAI 4th-pass `guard_incapacitated` / `guard_woke_up` signals still missing from `Events.gd` Key Interfaces. The autoload-registration sequence in `project.godot` is also under-specified: ADR-0004 (`InputContext`) and the Level Streaming GDD (`LevelStreamingService`) both declare "load order 4" using non-engine-enforced documentation labels — the engine itself honours line order in the `[autoload]` block, so the risk is editorial, not runtime. Engine-compatibility is otherwise clean: no deprecated-API references across the six ADRs, no cross-ADR contradictions on post-cutoff APIs, no dependency cycles. All six ADRs remain `Proposed` with pending verification gates — this is not a FAIL (Foundation layer is addressed) but it IS a hard pre-requisite for advancing to the Pre-Production gate.

---

## Traceability Summary

- **Total systems reviewed**: 12 authored GDDs out of 23 in the systems index (11 MVP + FootstepComponent sibling)
- **System-level coverage**: 9 fully covered · 3 partial · **2 hard gaps on incomplete ADR-0002 amendment**
- **TR count** (system-aggregated, this review's baseline): **~158 TRs** across the 12 GDDs
- **Full matrix**: see `docs/architecture/requirements-traceability.md`

### Coverage Matrix (high-level)

| # | System | TR slug | TR count | Covering ADRs | Status |
|---|--------|---------|----------|---------------|--------|
| 1 | Signal Bus | `TR-SB-` | ~10 | ADR-0002 | ✅ Covered |
| 2 | Input | `TR-INP-` | ~10 | ADR-0004 (3 mandated actions), ADR-0003 (settings.cfg) | ⚠️ Partial — Combat Takedown action missing from Input GDD catalog |
| 3 | Audio | `TR-AUD-` | ~12 | ADR-0002 (signal contract) | ⚠️ Partial — bus/pool/state-machine architecture is GDD-scope only |
| 4 | Outline Pipeline | `TR-OUT-` | ~10 | ADR-0001, ADR-0005 | ✅ Covered (shader-algorithm future ADR acknowledged) |
| 5 | Post-Process Stack | `TR-PP-` | ~10 | ADR-0004 (sepia dim API only) | ⚠️ Partial — chain order, WorldEnvironment constraints, resolution-scale wiring GDD-only |
| 6 | Save / Load | `TR-SAV-` | ~15 | ADR-0003, ADR-0002 | ✅ Covered |
| 7 | Localization Scaffold | `TR-LOC-` | ~10 | ADR-0004 (`tr()` mandate), ADR-0003 (settings.cfg) | ✅ Covered at ADR-level |
| 8 | Player Character | `TR-PC-` | ~20 | ADR-0001, -0002, -0003, -0005, -0006 | ✅ Covered |
| 8b | FootstepComponent | `TR-FC-` | ~8 | ADR-0002, ADR-0006 | ✅ Covered |
| 9 | Level Streaming | `TR-LS-` | ~15 | ADR-0002 (**outdated**), ADR-0003 | ❌ **GAP** — `TransitionReason` param on `section_entered`/`section_exited` missing from ADR-0002 Key Interfaces |
| 10 | Stealth AI | `TR-SAI-` | ~18 | ADR-0001, -0002, -0003, -0006 | ❌ **GAP** — `guard_incapacitated`/`guard_woke_up` signals missing from ADR-0002 Key Interfaces |
| 11 | Combat & Damage | `TR-CD-` | ~22 | ADR-0001, -0002, -0003, -0006 | ✅ Covered (Takedown-input downstream coordination noted above under Input) |

---

## Coverage Gaps

### ❌ Gap 1 — ADR-0002 amendment completion (incomplete, not missing ADR)

The 2026-04-22 amendment bundle landed the Stealth-AI-side signature changes (severity, takedown_type, CombatSystem→CombatSystemNode rename, Accessor Conventions subsection). The following downstream scope is still outstanding:

| Item | Source | Impact |
|------|--------|--------|
| `section_entered(section_id: StringName, reason: LevelStreamingService.TransitionReason)` | Level Streaming GDD LS-Gate-1 | Audio, Cutscenes, Mission Scripting, F&R subscriber handlers depend on the 2nd param to distinguish FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE |
| `section_exited(section_id: StringName, reason: LevelStreamingService.TransitionReason)` | Level Streaming GDD LS-Gate-1 | Same |
| `signal guard_incapacitated(guard: Node)` | SAI 4th-pass pre-impl gate #1 | Cross-guard unregistration protocol for dead-body raycast targets |
| `signal guard_woke_up(guard: Node)` | SAI 4th-pass pre-impl gate #1 | Audio wake sting + ambient breathing loop routing |
| `LevelStreamingService.TransitionReason` in Implementation Guideline 2 enum-ownership list | Level Streaming GDD | Owner declaration |
| Signal count: "34 events" → "36 events" | ADR-0002 Summary + `architecture.yaml` | Taxonomy count update |

**Suggested next step**: `/architecture-decision adr-0002-amendment-ls-plus-sai-4th-pass` (bundles all six items in one amendment to avoid partial-commit compile hazards — see Specialist Findings §2).

**Engine Risk**: LOW.

### ❌ Gap 2 — Performance Budget Distribution ADR (new ADR recommended)

Per-system budgets are scattered across GDDs without a cross-cutting contract:

- Stealth AI 6 ms total (perception 3 / nav 2 / signals 1) per 12 guards
- Combat GuardFireController 0.3 ms / 0.5 ms P95 (independently carved out of SAI's slot)
- Outline Pipeline ≤2.0 ms (≤1.5 ms target on RTX 2060, ~2.0 ms accepted on Iris Xe at 75% scale)
- Post-Process Stack sepia dim ≤0.5 ms, chain total ≤2.5 ms on Iris Xe
- Save/Load ≤10 ms save latency, ≤2 ms load I/O
- Audio 16-voice global spatial pool
- Level Streaming ≤0.57 s p90 transition, 33 + ≤500 + 33 ms per phase

Total 16.6 ms frame budget at 60 fps is not explicitly allocated. SAI's 4th-pass flagged this as pre-impl gate #5.

**Suggested next step**: `/architecture-decision performance-budget-distribution`.

**Engine Risk**: MEDIUM. Affects Stealth AI, Combat, Outline Pipeline, Post-Process Stack, Audio simultaneously.

### ❌ Gap 3 — Autoload registration contract (surgical amendment OR new ADR)

Currently scattered:
- Events = load order 1 (ADR-0002)
- EventLogger = load order 2 (ADR-0002)
- SaveLoad = load order 3 (ADR-0003)
- InputContext = load order 4 (ADR-0004)
- **LevelStreamingService = load order 4 (Level Streaming GDD)** ← collision

Per specialist finding §1, "load order N" labels are a team-documentation convention; the engine honours `project.godot` line order. The hazard is editorial: a future developer may write wire-up code assuming both init simultaneously, and whichever lands second will observe the first as null.

**Suggested next step**: either `/architecture-decision autoload-load-order-registry` (durable), or surgical amendments to ADR-0004 (InputContext→4) and the Level Streaming GDD (LevelStreamingService→5) plus updated `project.godot` line ordering. The former is preferred because PostProcessStack is also an autoload (per ADR-0004 Implementation Guideline 7) with unstated load order, and more autoloads may be added.

**Engine Risk**: LOW (editorial).

### ⚠️ Partial — Audio Architecture ADR (marginal; defer)

Bus structure, 16-voice spatial pool sizing, 5-layer music state machine, and Formula 1/2/3/4 all live GDD-only. Audio GDD is dense, Approved, and specialist-validated — raise only if implementation uncovers ambiguity.

### ⚠️ Partial — Post-Process Stack architecture (marginal; defer)

Chain order, WorldEnvironment constraints, resolution-scale subscription wiring all live GDD-only. ADR-0004 locks only the `enable_sepia_dim()`/`disable_sepia_dim()` API contract. Acceptable for MVP unless Post-Process stories hit design gaps.

### ⚠️ Partial — Combat Takedown input action (downstream coordination, not a missing ADR)

Combat GDD CR-3 introduces a dedicated `takedown` input (kbd F / gamepad Y). Input GDD's 29-action catalog was authored before Combat's revision and does not yet include the action name. This is a GDD-to-GDD coordination gap, not an ADR gap.

**Suggested next step**: small Input GDD touch-up to add the `takedown` action alongside the existing 26 gameplay + 3 debug actions.

---

## Cross-ADR Conflicts

### 🔴 Conflict 1 — Autoload load-order collision (editorial)

| | |
|---|---|
| Type | Dependency / documentation convention |
| ADR-0004 claims | `InputContext` at load order 4 |
| Level Streaming GDD claims | `LevelStreamingService` at load order 4 |
| Engine reality (per specialist §1) | `project.godot` line order wins; "load order N" labels are team documentation, not engine-enforced |
| Impact | Future dev reads both as "4" and writes wire-up assuming simultaneous init; whichever initialises second observes the other as null |
| Resolution options | (1) InputContext→4, LevelStreamingService→5, update ADRs **and** `project.godot` line order. (2) Treat as a load-order registry gap and author a dedicated ADR (see Gap 3). |
| Preferred | Option (1) for minimum-viable fix now; Option (2) if a registry ADR is authored in the same cycle |

### 🔴 Conflict 2 — ADR-0002 Key Interfaces incomplete vs. Level Streaming GDD

| | |
|---|---|
| Type | Integration contract |
| ADR-0002 L199-200 | `signal section_entered(section_id: StringName)` / `section_exited(section_id: StringName)` (1-param) |
| Level Streaming GDD | Mandates `reason: TransitionReason` 2nd param (4-value enum: FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE) |
| Impact | Audio, Cutscenes, Mission Scripting, F&R subscriber handlers cannot dispatch correctly without the 2nd param |
| Resolution | Fold into the ADR-0002 amendment described in Gap 1 |

### 🔴 Conflict 3 — ADR-0002 Key Interfaces missing SAI 4th-pass signals

| | |
|---|---|
| Type | Integration contract |
| Missing | `signal guard_incapacitated(guard: Node)`, `signal guard_woke_up(guard: Node)` |
| Source | SAI GDD 4th-pass revision (2026-04-22), pre-impl gate #1 |
| Impact | Cross-guard dead-body raycast unregistration + Audio wake-sting routing have no bus contract |
| Resolution | Fold into the ADR-0002 amendment described in Gap 1. **Specialist-flagged hazard (see §2 below): enum + signal changes must commit atomically or autoload chain fails to start.** |

---

## ADR Dependency Order (topologically sorted)

```
Foundation (no ADR deps):
  1. ADR-0001: Stencil ID Contract
  2. ADR-0002: Signal Bus + Event Taxonomy
  3. ADR-0006: Collision Layer Contract

Depends on Foundation:
  4. ADR-0003: Save Format Contract (soft-deps ADR-0002 for Persistence signals + FailureReason enum)
  5. ADR-0005: FPS Hands Outline Rendering (explicit exception to ADR-0001)

Depends on Foundation + Feature:
  6. ADR-0004: UI Framework (hard-deps ADR-0002 + ADR-0003)
```

**No dependency cycles.**

⚠️ **All 6 ADRs are currently `Proposed` — none Accepted.** Per `docs/CLAUDE.md`, stories referencing a Proposed ADR are auto-blocked. This means the full dependency chain has unresolved verification gates:

| ADR | Gate count | Scope |
|-----|-----------|-------|
| ADR-0001 | 4 | BaseMaterial3D stencil API · CompositorEffect stencil read Vulkan · same on D3D12 · perf on Iris Xe |
| ADR-0002 | 1 | smoke test (emit + subscribe + EventLogger) |
| ADR-0003 | 3 | ResourceSaver FLAG_COMPRESS · DirAccess.rename · `duplicate_deep()` on nested typed Resources |
| ADR-0004 | 3 | `accessibility_*` property names · `base_theme` property name · modal dismiss KB/M + gamepad |
| ADR-0005 | 4 | Vulkan prototype · D3D12 prototype · `resolution_scale` parity · rigged-animation no-artifacts |
| ADR-0006 | 3 | class compiles · `project.godot` named slots · one migrated gameplay file |

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-02-12)
**ADRs with Engine Compatibility section**: 6 / 6 ✓

### Post-Cutoff API Usage (all correctly flagged)

| API | Since | ADRs consuming |
|-----|-------|----------------|
| Stencil buffer (`BaseMaterial3D` / `ShaderMaterial` write; `CompositorEffect` read) | 4.5 | ADR-0001 |
| `CompositorEffect` + `Compositor` node | 4.3 | ADR-0001, ADR-0005 (coexists via SubViewport) |
| Shader Baker | 4.5 | ADR-0001, ADR-0005 |
| D3D12 default on Windows | 4.6 | ADR-0001, ADR-0005 (both run outline passes cross-platform) |
| `Resource.duplicate_deep()` | 4.5 | ADR-0003 (load-bearing) |
| AccessKit screen reader | 4.5 | ADR-0004 |
| Dual-focus (mouse vs keyboard/gamepad) | 4.6 | ADR-0004 |
| Jolt 3D default | 4.6 | ADR-0006 |

### Deprecated API Check

`grep` across all 6 ADRs for patterns in `deprecated-apis.md`: **clean**. No `connect("sig", obj, "method")`, no `yield`, no bare `duplicate()` without `_deep`, no `get_world()`, no `VisibilityNotifier*`, no `TileMap`, no `Navigation2D`/`3D`, no `Texture2D` in shader-parameter type annotations at load-bearing sites. ADR-0001's outline fragment shader pseudocode has `sampler2D depth_stencil_texture` with "exact hint name TBD" — acknowledged by Gate 2 and scoped to resolution during verification; not a deprecation hit.

### Stale Version References

None. All ADRs pinned to 4.6; ADR-0002 `Last Verified` bumped to 2026-04-22 post-amendment; others at 2026-04-19 remain valid within their scope.

### Post-Cutoff API Conflicts Between ADRs

None. ADR-0001 and ADR-0005 co-consume `Settings.get_resolution_scale()` without contradictory assumptions.

### Engine Specialist Findings

Consulted `godot-specialist` with 7 targeted spot-checks. Verdict: **YELLOW**. Incorporated findings:

| # | Finding | Status | Incorporation |
|---|---------|--------|---------------|
| 1 | Autoload load-order labels are team-documentation, not engine-enforced. Engine honours `project.godot` line order. | **CHALLENGE / upgraded** | Reclassified Conflict 1 as editorial hazard; resolution unchanged |
| 2 | `BaseMaterial3D.stencil_write_value` NOT exposed in 4.6. Plan for `ShaderMaterial`-mandatory branch; Gate 1 is confirmation, not discovery. | **CHALLENGE** | Advance implementation planning to assume `ShaderMaterial` path |
| 3 | `CompositorEffect` stencil read on D3D12/Windows parity | **UNKNOWN** | Gate 3 prototype remains correctly sized; risk stays MEDIUM probability / HIGH impact |
| 4 | ADR-0002 amendment atomicity hazard: enum + signal changes must commit in the same PR or the autoload chain fails to start (not just the documented reimport nuance) | **CONFIRM + new consideration** | New Risks row recommended on ADR-0002 (see Required Amendments below); amendment must land atomically |
| 5 | `duplicate_deep()` on `Dictionary[StringName, GuardRecord]` works in 4.5+; `StringName` keys are interned and correctly not duplicated (identity preservation is the intended behaviour) | **CHALLENGE (partial) / useful detail** | ADR-0003 Gate 3 scope-refinement: explicitly exercise mutating a loaded-and-duplicated GuardRecord to confirm isolation |
| 6 | Shader Baker × `material_overlay` compatibility in 4.6 | **UNKNOWN / elevate priority** | New Gate 5 recommended on ADR-0005; move verification from Polish phase to Prototype phase |
| 7 | Jolt collision_layer parity with GodotPhysics | **CONFIRM + nuance** | New Risks row recommended on ADR-0006: fast-body `Area3D` tunneling (MEDIUM prob / LOW impact for mission triggers + Combat darts at 20 m/s); mitigation — use `move_and_collide` + projectile-side signalling for fast bodies |

**Additional finding (not in the main audit)**: ADR-0004 has the same `class_name` / autoload-key split as ADR-0002's `CombatSystemNode`/`Combat`, but does not document the `InputContextStack.*` (class) vs `InputContext.*` (autoload) discoverability trap explicitly. Recommend a 1-paragraph addendum to Implementation Guideline 2 of ADR-0004 mandating call sites use `InputContext.*` only.

---

## Required ADR Amendments (from findings)

All are in-place amendments to existing ADRs — no ADRs need superseding.

### ADR-0002 amendment bundle (ties to Gap 1)

- Add `reason: LevelStreamingService.TransitionReason` parameter to `section_entered` + `section_exited` signal declarations
- Add `signal guard_incapacitated(guard: Node)` + `signal guard_woke_up(guard: Node)` declarations
- Update Summary signal count 34 → 36
- Add `LevelStreamingService.TransitionReason` to Implementation Guideline 2 enum-ownership list
- Add new Risks row: *"Inner-enum additions + new signal declarations MUST commit atomically. Partial PRs (e.g., `Events.gd` updated before the owning class's enum declaration lands) produce a compile error that blocks the entire autoload chain at startup. Mitigation: single-PR amendments with both changes."* (Specialist §2.)

### ADR-0003 amendment

- Refine Gate 3 scope: explicitly test mutating a loaded-and-`duplicate_deep`-copied `GuardRecord` inside `StealthAIState.guards: Dictionary[StringName, GuardRecord]` and confirm the original stays clean. (Specialist §5.)

### ADR-0004 amendment

- Add 1-paragraph addendum to Implementation Guideline 2: call sites MUST use autoload key `InputContext.*`, MUST NOT use `InputContextStack.*` — identical split pattern to ADR-0002's `CombatSystemNode`/`Combat` treatment.
- Resolve the load-order-4 collision per Gap 3.

### ADR-0005 amendment

- Add Gate 5: verify Shader Baker in 4.6 bakes `material_overlay` slots during export. (Specialist §6.)
- Move this verification from Polish phase to Prototype phase — discovering exclusion during Polish forces a costly refactor to the two-surface approach.

### ADR-0006 amendment

- Add Risks row: *"Jolt `Area3D.body_entered` may occasionally miss fast-moving bodies (e.g., Combat darts at 20 m/s on Layer 5) due to broadphase tunneling. MEDIUM probability / LOW impact. Mitigation: fast projectiles fire trigger signals via their own `move_and_collide` hit-response rather than relying on Area3D overlap detection."* (Specialist §7.) Note this dovetails with Combat GDD's existing OQ-CD-2 Jolt prototype scope.

---

## GDD Revision Flags (Architecture → Design Feedback)

| GDD | Assumption | Reality | Action |
|-----|-----------|---------|--------|
| `design/gdd/player-character.md` (lines ~200, 457, 591) | References frozen `CombatSystem.DeathCause` enum qualifier | ADR-0002 amendment renamed to `CombatSystemNode.DeathCause` (2026-04-22) | Producer-sequenced rename pass (already tracked in `production/session-state/active.md`) |

No other GDDs make assumptions that conflict with verified engine behaviour.

**Should I flag these GDDs for revision in the systems index?** — deferred; already tracked as producer sequence in session state. No write-action required from this review.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` **does not exist**. This is expected — the project's "Architecture Document" phase (`/create-architecture`) is slated for after all 4 required ADRs + 5-8 GDDs are complete. Current state (6 ADRs authored but Proposed, 10/16 MVP GDDs designed) is approaching that threshold.

**Not a gap for this review**; noted as the next natural artifact after verdict unblocks.

---

## Verdict: **CONCERNS**

### Why not PASS
- ADR-0002 amendment is incomplete (2 signal-parameter gaps + 2 new signals missing)
- Autoload load-order collision unresolved
- All 6 ADRs still Proposed with pending verification gates
- Performance Budget Distribution ADR recommended for cross-system coordination

### Why not FAIL
- Foundation-layer coverage is complete (Signal Bus, Save/Load, Stencil, Collision, UI, Hands all have ADRs)
- No wrong engine-version decisions; no deprecated-API references
- No dependency cycles
- No cross-ADR contradictions on post-cutoff API assumptions
- No GDD revision flags beyond the already-tracked producer rename pass

### Blocking Issues (must resolve before PASS)

1. **ADR-0002 amendment completion** — atomically add (a) TransitionReason on section signals, (b) guard_incapacitated/guard_woke_up signals, (c) enum-ownership list entry, (d) new Risks row per Specialist §2
2. **Autoload load-order collision** — in-place amendments to ADR-0004 + Level Streaming GDD + `project.godot` registration order, OR dedicated autoload-registry ADR
3. **ADR verification gates** — at minimum, ADR-0001 Gates 1-3 (stencil pipeline cross-platform), ADR-0002 smoke test (amendment verification), ADR-0003 Gates 1-3 (save round-trip) must pass before Pre-Production gate can advance

---

## Priority Action List (next 3 sessions)

1. **Session A** — `/architecture-decision adr-0002-amendment-ls-plus-sai-4th-pass` (bundles Gap 1 + Conflicts 2 & 3)
2. **Session B** — Either `/architecture-decision autoload-load-order-registry` OR surgical amendments to ADR-0004 + Level Streaming GDD
3. **Session C** — `/architecture-decision performance-budget-distribution` (unblocks SAI pre-impl gate #5 + Combat GuardFireController independence claim + frame-time reconciliation)

**Re-run trigger**: `/architecture-review` after each of the above lands, to verify coverage improves.

**Gate guidance**: After all three blocking issues are resolved and verification gates on ADR-0001 through ADR-0003 have passed, run `/gate-check pre-production` to advance.

---

## Related

- `docs/architecture/requirements-traceability.md` — full TR matrix populated by this review
- `docs/architecture/tr-registry.yaml` — stable TR-ID registry (populated for the first time by this review)
- `docs/architecture/adr-0001-stencil-id-contract.md` through `adr-0006-collision-layer-contract.md`
- `design/gdd/systems-index.md`
- `production/session-state/active.md`
