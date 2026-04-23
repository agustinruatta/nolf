# Architecture Traceability Index

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-04-22 |
| **Engine** | Godot 4.6 |
| **Populated by** | `/architecture-review` (full mode) |

---

## Coverage Summary

| | Count | % |
|---|-------|---|
| Total TRs registered | **158** | 100% |
| ✅ Covered (ADR-addressed) | ~145 | ~92% |
| ⚠️ Partial (ADR coverage exists but scope incomplete or pending amendment) | ~10 | ~6% |
| ❌ Gap (no ADR addresses) | ~3 | ~2% |

*The ~ figures reflect that coverage is reported at system-level granularity; individual TR-level coverage may shift slightly when stories are authored. The 3 hard gaps are all inside the pending ADR-0002 amendment bundle.*

---

## Full Matrix

System → ADR coverage with per-TR detail. Systems with hard GAPs are expanded; systems with full coverage are summarised at the system level.

### System 1 — Signal Bus (TR-SB-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-SB-001 — Signal Bus as sole cross-system dispatch | ADR-0002 | ✅ |
| TR-SB-002 — 34-signal taxonomy (→ 36 post-amendment) | ADR-0002 | ⚠️ Partial (count update pending amendment) |
| TR-SB-003 — Autoload ordering Events=1, EventLogger=2 | ADR-0002 | ✅ |
| TR-SB-004 — Events.gd contains only signal declarations | ADR-0002 | ✅ |
| TR-SB-005 — Subscriber _ready / _exit_tree lifecycle | ADR-0002 | ✅ |
| TR-SB-006 — is_instance_valid() on Node-typed payloads | ADR-0002 | ✅ |
| TR-SB-007 — Enum ownership on publishing class, not Events.gd | ADR-0002 | ✅ |
| TR-SB-008 — Five forbidden patterns | ADR-0002 | ✅ |
| TR-SB-009 — EventLogger debug self-removal | ADR-0002 | ✅ |
| TR-SB-010 — SAI→Combat Accessor Conventions carve-out | ADR-0002 | ✅ |

### System 2 — Input (TR-INP-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-INP-001 — Named InputMap actions, no raw KEY_* | ADR-0004 (by-pattern) | ✅ |
| TR-INP-002 — 29 actions via InputActions StringName constants | (GDD-scope) | ⚠️ Not ADR-locked (acceptable) |
| TR-INP-003 — Input.get_vector vs press/hold routing | (GDD-scope) | ✅ (implementation detail) |
| TR-INP-004 — InputContext gating via _unhandled_input | ADR-0004 | ✅ |
| TR-INP-005 — ui_cancel / interact / pause action bindings | ADR-0004 | ✅ |
| TR-INP-006 — Rebinding persists to settings.cfg | ADR-0003 | ✅ |
| TR-INP-007 — Modal dismiss via _unhandled_input + ui_cancel | ADR-0004 | ✅ |
| TR-INP-008 — get_viewport().set_input_as_handled() after consume | ADR-0004 | ✅ |
| TR-INP-009 — Gamepad partial at MVP | (GDD-scope) | ✅ |
| TR-INP-010 — InputContext.LOADING context | ADR-0004 (defines context enum) | ⚠️ Partial — LS-Gate-2 adds LOADING value; pending Input GDD amendment |

**Additional note**: Combat GDD CR-3 introduces a dedicated `takedown` input action. This is NOT yet in the Input GDD's 29-action catalog. A small Input GDD touch-up is needed (downstream coordination, not an ADR gap). Flag tracked in the review report.

### System 3 — Audio (TR-AUD-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-AUD-001 — Subscriber-only (30 signals) | ADR-0002 | ✅ |
| TR-AUD-002 — Five named buses | (GDD-scope) | ⚠️ Not ADR-locked (acceptable — audio pipeline is Audio GDD scope) |
| TR-AUD-003 — AudioManager as persistent-root Node (not autoload) | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-004 — Two music layers + sting architecture | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-005 — Music state grid | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-006 — Crossfade-only music transitions | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-007 — 16-voice spatial SFX pool | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-008 — Section music preload at section_entered | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-009 — Per-section reverb swap | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-010 — Dominant-guard dictionary | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-011 — Stinger debounce + SCRIPTED suppression | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-012 — Takedown SFX routing by takedown_type | ADR-0002 (signature) | ✅ |

**System status**: ⚠️ Partial. Signal-contract side fully covered by ADR-0002. Audio architecture internals (buses, pools, state machine) intentionally left GDD-only. Architecture ADR deferred as marginal — raise only if implementation stories hit ambiguity.

### System 4 — Outline Pipeline (TR-OUT-*)

All 10 TRs: ✅ Covered by ADR-0001 (stencil contract) + ADR-0005 (hands exception). Outline shader algorithm (Sobel vs Laplacian, edge_threshold tuning) deferred to a future ADR — explicitly acknowledged.

### System 5 — Post-Process Stack (TR-PP-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-PP-001 — Chain order | (GDD-scope) | ⚠️ Partial |
| TR-PP-002 — Sepia Dim lifecycle via enable/disable API | ADR-0004 | ✅ |
| TR-PP-003 — Sepia parameters 30%/25%/warm amber | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-PP-004 — Glow disabled project-wide | Art Bible 8J / GDD-scope | ⚠️ Not ADR-locked |
| TR-PP-005 — Forbidden effects (bloom, CA, SSR, etc.) | Pillar 5 / GDD-scope | ✅ (Pillar-level) |
| TR-PP-006 — Tonemap neutral linear | (GDD-scope) | ⚠️ |
| TR-PP-007 — PostProcessStack autoload + API | ADR-0004 | ✅ |
| TR-PP-008 — Resolution scale via Viewport.scaling_3d_scale + settings.cfg | ADR-0003 (persistence) + GDD-scope | ⚠️ Partial |
| TR-PP-009 — Performance budget | (GDD-scope) | ⚠️ Partial (coverage via Perf Budget ADR — Gap 2) |
| TR-PP-010 — Only Settings writes resolution_scale | (GDD-scope anti-pattern) | ✅ |

**System status**: ⚠️ Partial. API lifecycle is ADR-locked; rendering details are GDD-scope. Acceptable for MVP.

### System 6 — Save / Load (TR-SAV-*)

All 15 TRs: ✅ Covered by ADR-0003 (format, atomicity, versioning, metadata, actor_id, duplicate_deep, settings separation) + ADR-0002 (Persistence signals). Specialist §5 recommended Gate 3 scope-refinement to explicitly test `duplicate_deep()` on `Dictionary[StringName, GuardRecord]` — addressed in ADR-0003 amendment list.

### System 7 — Localization Scaffold (TR-LOC-*)

All 10 TRs: ✅ Covered. ADR-0004 mandates `tr()` usage + forbidden pattern; ADR-0003 owns the locale-preference location (settings.cfg, not SaveGame). Remaining details (CSV structure, plural forms, pseudolocalization) are scaffold-level.

### System 8 — Player Character (TR-PC-*)

All 20 TRs: ✅ Covered. Touches 5 ADRs:
- ADR-0001 (all non-hands meshes write stencil tiers)
- ADR-0002 (player signals: player_damaged, player_died, player_health_changed, player_interacted, player_footstep)
- ADR-0003 (PlayerState sub-resource schema)
- ADR-0005 (FPS hands exception — inverted-hull via material_overlay)
- ADR-0006 (Eve on LAYER_PLAYER; interact raycast on MASK_INTERACT_RAYCAST)

### System 8b — FootstepComponent (TR-FC-*)

All 8 TRs: ✅ Covered. ADR-0002 (`player_footstep` signal), ADR-0006 (MASK_FOOTSTEP_SURFACE). Surface metadata authoring contract resolved by Level Streaming CR-10 (cross-GDD handoff).

### System 9 — Level Streaming (TR-LS-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-LS-001 — Autoload; registration order | ADR-0002 (order convention) | ⚠️ **Partial — load-order collision with InputContext (Conflict 1)** |
| TR-LS-002 — CanvasLayer 127 fade overlay | (GDD-scope) | ✅ |
| TR-LS-003 — Public API (transition/reload/register_restore_callback) | (GDD-scope) | ✅ |
| TR-LS-004 — SectionRegistry Resource | (GDD-scope) | ✅ |
| TR-LS-005 — 13-step fixed-sequence swap | (GDD-scope) | ✅ |
| TR-LS-006 — Queued-respawn during transition | (GDD-scope) | ✅ |
| TR-LS-007 — TransitionReason enum param on section_entered/exited | ADR-0002 (PENDING AMENDMENT) | ❌ **GAP — LS-Gate-1** |
| TR-LS-008 — Section scene authoring contract CR-9 | (GDD-scope) | ✅ |
| TR-LS-009 — InputContext.LOADING push/pop | ADR-0004 (context enum) | ⚠️ Partial — LOADING value pending Input GDD amendment |
| TR-LS-010 — CACHE_MODE_REUSE default | (GDD-scope) | ✅ |
| TR-LS-011 — ≤0.57 s p90 performance budget | (GDD-scope + Perf Budget ADR Gap 2) | ⚠️ Partial |
| TR-LS-012 — Persistent fade overlay parented to autoload | (GDD-scope) | ✅ |
| TR-LS-013 — Step-9 synchronous registered-callback | (GDD-scope) | ✅ |
| TR-LS-014 — Same-section no-op + focus-loss handling | (GDD-scope + project.godot setting) | ✅ |
| TR-LS-015 — Surface metadata contract (resolves OQ-FC-1) | (GDD-scope) | ✅ |

**System status**: ❌ GAP on TR-LS-007 (TransitionReason parameter missing from ADR-0002). Blocks all LS signal subscribers.

### System 10 — Stealth AI (TR-SAI-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-SAI-001 — Guard hierarchy | (GDD-scope) | ✅ |
| TR-SAI-002 — 6-state alert machine | (GDD-scope) | ✅ |
| TR-SAI-003 — Six SAI signals | ADR-0002 | ❌ **GAP — guard_incapacitated + guard_woke_up missing from Key Interfaces** |
| TR-SAI-004 — Severity enum | ADR-0002 | ✅ (amended 2026-04-22) |
| TR-SAI-005 — AlertCause enum | ADR-0002 | ✅ |
| TR-SAI-006 — TakedownType enum | ADR-0002 | ✅ (amended 2026-04-22) |
| TR-SAI-007 — F.1 Sight fill formula | (GDD-scope) | ✅ |
| TR-SAI-008 — F.2 Sound fill | (GDD-scope) | ✅ |
| TR-SAI-009 — F.3 Accumulator decay | (GDD-scope) | ✅ |
| TR-SAI-010 — F.4 Alert propagation | (GDD-scope) | ✅ |
| TR-SAI-011 — F.5 Transition thresholds | (GDD-scope) | ✅ |
| TR-SAI-012 — has_los_to_player() accessor | ADR-0002 (Accessor Conventions) | ✅ (amended 2026-04-22) |
| TR-SAI-013 — takedown_prompt_active() accessor | ADR-0002 (Accessor Conventions) | ✅ (amended 2026-04-22) |
| TR-SAI-014 — receive_damage synchronous mutation | (GDD-scope, Combat cross-ref) | ✅ |
| TR-SAI-015 — Wake-up clock 45 s | (GDD-scope) | ✅ |
| TR-SAI-016 — RaycastProvider DI interface | (GDD-scope) | ✅ |
| TR-SAI-017 — _perception_cache struct | (GDD-scope) | ✅ |
| TR-SAI-018 — 6 ms performance budget per 12 guards | (GDD-scope + Perf Budget ADR Gap 2) | ⚠️ Partial |

**System status**: ❌ GAP on TR-SAI-003 (2 of 6 signals pending ADR-0002 amendment).

### System 11 — Combat & Damage (TR-CD-*)

All 22 TRs: ✅ Covered (with one cross-GDD coordination gap). Touches 4 ADRs:
- ADR-0001 (guard outline tier MEDIUM, dart outline LIGHT, muzzle-flash stencil)
- ADR-0002 (4 Combat signals + 4-param amendment consumption)
- ADR-0003 (ammo + reserve state serialization)
- ADR-0006 (MASK_PROJECTILES for darts, hitscan masks per-shot from SectionConfig)

Downstream coordination gap: Combat's dedicated `takedown` input action is not yet in Input GDD's 29-action catalog.

---

## Known Gaps (❌ only)

Priority-ordered fix list:

### Foundation-layer gaps
*(None — Signal Bus, Save/Load, Collision, UI, Stencil foundations all complete at system level.)*

### Core-layer gaps

1. **TR-LS-007** — `TransitionReason` parameter on `section_entered`/`section_exited`
   → Fix: ADR-0002 amendment bundle (see review report §Required ADR Amendments)

2. **TR-SAI-003** — `guard_incapacitated` + `guard_woke_up` signals in ADR-0002 Key Interfaces
   → Fix: same ADR-0002 amendment bundle (atomic commit per Specialist §2)

### Feature / Presentation-layer gaps

*(None beyond the Core-layer amendments above.)*

### Cross-cutting (not system-specific) gaps

3. **Performance Budget Distribution ADR** — recommended to lock cross-system frame-time allocation (SAI pre-impl gate #5). Affects SAI, Combat GuardFireController, Audio, Outline, Post-Process, Save/Load, Level Streaming simultaneously.

4. **Autoload registration contract** — either dedicated ADR or surgical amendments to resolve InputContext vs LevelStreamingService load-order collision.

---

## Superseded Requirements

*(None — this is the initial registry population.)*

---

## History

| Date | Total TRs | Full Chain % (ADR-covered) | Notes |
|------|-----------|-----------------------------|-------|
| 2026-04-22 | 158 | ~92% | Initial registry population. System-level granularity. 2 hard gaps on pending ADR-0002 amendment; 1 coordination gap on Input GDD takedown action. |

---

## How to Read This Matrix

- **✅** — ADR explicitly addresses this requirement (directly or via its decision text)
- **⚠️ Partial** — ADR covers some aspect but scope incomplete, pending amendment, or reasonably GDD-scope
- **❌ Gap** — no ADR addresses this requirement; must be authored before Pre-Production gate

TR-IDs are stable across review runs. When a GDD requirement's text is reworded (same intent), the TR-ID stays the same and `revised` date is bumped in `tr-registry.yaml`. When a requirement is removed, the entry is marked `status: deprecated`.

## Related

- `docs/architecture/architecture-review-2026-04-22.md` — full review report with verdict, conflicts, and engine specialist findings
- `docs/architecture/tr-registry.yaml` — authoritative TR-ID source
- `docs/architecture/adr-0001-*.md` through `adr-0006-*.md` — architectural decisions
- `design/gdd/systems-index.md` — system enumeration + status
