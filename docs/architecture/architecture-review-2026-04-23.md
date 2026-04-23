# Architecture Review Report

| Field | Value |
|-------|-------|
| **Date** | 2026-04-23 (third run — supersedes earlier 2026-04-23 snapshots after ADR-0008 landed same day) |
| **Mode** | `/architecture-review` (full, delta-verification since second 2026-04-23 run) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **GDDs Reviewed** | 12 (no new authorship since 2026-04-22) |
| **ADRs Reviewed** | **8** (was 7; ADR-0008 added; all 8 Proposed) |
| **TR Registry State on Entry** | 158 TRs from v2 (no new TRs this run; no revisions) |
| **Prior Review** | This file overwrites the second 2026-04-23 snapshot (pre-ADR-0008). See `docs/architecture/architecture-review-2026-04-22.md` for the full-matrix baseline. |
| **Verdict** | **PASS** (upgraded from CONCERNS — Gap 2 closed; zero remaining ADR-level architectural gaps) |

---

## Summary

One session landed between the second 2026-04-23 review and this run:

**`/architecture-decision performance-budget-distribution`** authored **ADR-0008
Performance Budget Distribution** (Proposed, 13 sections, ~390 lines), closing
the only remaining architectural gap from the prior review. The ADR allocates
the full 16.6 ms / 60 fps frame budget across **9 named Iris Xe Gen 12 slots**
summing to exactly 16.6 ms (Rendering 3.8 · Guard systems 6.5 · Post-Process
chain 2.5 · Jolt physics 0.5 · Player/FC/Combat non-GF 0.3 · Audio dispatch 0.3
· UI refresh 0.3 · Pooled residual 0.8 · Reserve 1.6), documents non-frame
latencies (save/load, LS transition, shader bake, autoload boot cold-start +
D3D12 post-stream warm-up allowance), and defines a CI-time verification
contract against a single reference scene (`tests/reference_scenes/restaurant_dense_interior.tscn`).
Four validation gates pending empirical measurement to move Proposed → Accepted.

The ADR received a pre-authoring godot-specialist consultation that returned
**YELLOW with 3 prose constraints folded in before write**:
(a) directional shadow cascade cap = 1 named as explicit Constraint + Risk row
+ forbidden pattern; (b) PostProcessStack cold-boot dominance (5–15 ms Vulkan,
+5–10 ms D3D12 for compositor pipeline + descriptor heap setup) documented in
non-frame budgets table + Risk row; (c) D3D12 post-stream 3-frame warm-up
allowance added to non-frame budgets + Validation Gate 3. Plus GREEN on the
Jolt 0.5 ms slot sizing. Specialist's AudioServer reverb-swap observation (0.3–0.8
ms CPU stall on bus graph rebuild) absorbed by the 1.6 ms reserve slot.

This delta review verifies Gap 2 closure, audits ADR-0008 for cross-ADR conflicts
against the prior 7 ADRs, and reassesses outstanding scope. **Gap 2 is the only
remaining architectural gap from the prior run, and it is now CLOSED.** Zero
cross-ADR conflicts. Zero hard ADR gaps. Three GDD-coordination items remain
producer-tracked and non-blocking at ADR level.

**Verdict moves from CONCERNS → PASS**: the architectural design is complete.
Execution-phase work remains (verification-gate measurements + 3 GDD touch-ups)
but no architectural decision is outstanding.

---

## Traceability Summary

| | Prior 2026-04-23 (2nd run) | This run | Δ |
|---|---|---|---|
| Total TRs | 158 | 158 | — |
| ✅ Covered | ~148 | ~154 | **+6** (perf budget TRs now ADR-locked) |
| ⚠️ Partial | ~9 | ~3 | **−6** |
| ❌ Hard Gap | ~1 | **0** | **−1** |

No new TRs were extracted. ADR-0008 consolidates existing per-system
performance claims rather than introducing new requirements. The matrix in
`docs/architecture/requirements-traceability.md` stands; updates this run are
limited to:

- TR-SAI-018 (SAI 6 ms / 12 guards): ⚠️ Partial → ✅ (absorbed into Slot #2's 6.5 ms envelope)
- TR-PP-009 (post-process chain ≤2.5 ms Iris Xe): ⚠️ Partial → ✅ (Slot #3)
- TR-LS-011 (LS ≤0.57 s p90): ⚠️ Partial → ✅ (non-frame budgets)
- TR-OUT-006 (outline ≤2.0 ms): ✅ → ✅ strengthened (Slot #3 + ADR-0001 stand)
- TR-SAV-013 (save ≤10 ms / load ≤2 ms): ✅ → ✅ strengthened (non-frame budgets + ADR-0003 stand)
- TR-AUD-007 (16-voice spatial pool frame cost): ⚠️ → ✅ dispatch slot (Slot #6 0.3 ms); pool size remains GDD-scope.
- `design/gdd/combat-damage.md` L233 GuardFireController independence claim: ⚠️ Partial → ✅ (absorbed into Slot #2's 6.5 ms envelope; cross-system reconciliation flag CLOSED).

The sole "hard gap" from prior reviews — the Combat ↔ Input `takedown` action
coordination — is reclassified correctly this run as a GDD-coordination item
(design-level), not an ADR-level gap. It is addressed via Input GDD amendment,
not via a new ADR. With ADR-level gaps now at 0, the Traceability coverage
percentage lands at **~99%**.

### Coverage Matrix (high-level, delta only)

| # | System | Covering ADRs | Status (was → is) |
|---|--------|---------------|-------------------|
| 3 | Audio | ADR-0002, **ADR-0008** (dispatch cost Slot #6) | ⚠️ Partial → ✅ (dispatch-budget line locked; internals remain GDD-scope by design) |
| 4 | Outline Pipeline | ADR-0001, ADR-0005, **ADR-0008** (Slot #3 aggregate) | ✅ → ✅ strengthened |
| 5 | Post-Process Stack | ADR-0004, ADR-0007, **ADR-0008** (Slot #3 aggregate) | ⚠️ Partial → ✅ (perf budget row now ADR-locked) |
| 6 | Save / Load | ADR-0002, ADR-0003, ADR-0007, **ADR-0008** (non-frame) | ✅ → ✅ strengthened |
| 9 | Level Streaming | ADR-0002, ADR-0003, ADR-0007, **ADR-0008** (non-frame) | ✅ → ✅ strengthened |
| 10 | Stealth AI | ADR-0001, ADR-0002, ADR-0006, **ADR-0008** (Slot #2) | ✅ → ✅ strengthened; SAI Recommended Follow-up #5 CLOSED |
| 11 | Combat & Damage | ADR-0001, ADR-0002, ADR-0003, ADR-0006, **ADR-0008** (Slot #2 GuardFire + Slot #5 non-GF) | ✅ → ✅ strengthened; combat-damage.md L233 cross-system reconciliation CLOSED |

All other rows unchanged from the 2026-04-22 / 2026-04-23 matrix.

---

## Coverage Gaps

### ✅ Gap 2 — CLOSED (this run)

ADR-0008 (`docs/architecture/adr-0008-performance-budget-distribution.md`)
allocates the full 16.6 ms frame budget across 9 named slots, preserving every
prior per-system claim and pooling 0.8 ms for not-yet-designed systems:

| # | Slot | Budget (ms) | Source ADR / GDD |
|---|------|------------:|------------------|
| 1 | Rendering (Forward+ Mobile + dir. shadows + cull + trans.) | 3.8 | Engine (residual after explicit claims; specialist-validated) |
| 2 | Guard systems (SAI perception 3.0 + nav 2.0 + signals 1.0 + Combat GuardFireController 0.5 P95) | 6.5 | TR-SAI-018 + combat-damage.md L233 |
| 3 | Post-Process chain (outline 2.0 + sepia 0.5 + res-scale composite) | 2.5 | TR-OUT-006 + TR-PP-009 |
| 4 | Jolt physics step (player + 12 guards + darts + world) | 0.5 | Specialist GREEN |
| 5 | Player / FootstepComponent / Combat non-GuardFire logic | 0.3 | Aggregate event-driven |
| 6 | Audio dispatch (AudioServer mix + 16-voice pool + 30 subscribers) | 0.3 | TR-AUD-007 |
| 7 | UI refresh (HUD signal-driven + modal Control.process) | 0.3 | ADR-0004 no-polling |
| 8 | Pooled residual (Civilian AI, Mission Scripting, Doc Collection, Dialogue, Failure & Respawn, SB dispatch overhead) | 0.8 | Shared envelope — each GDD claims sub-slot |
| 9 | Reserve (OS jitter / D3D12 heap / Jolt spikes / reverb swap) | 1.6 | 10% margin |
| | **TOTAL** | **16.6** | 60 fps contract |

**Non-frame budgets consolidated**: save ≤10 ms, load ≤2 ms (inside LS), LS
transition ≤570 ms p90, shader bake 0–500 ms one-time, autoload boot ≤50 ms
cold-start (PostProcessStack dominant), D3D12 post-stream warm-up 3 frames
(~50 ms) allowed.

**Verification contract**: `/perf-profile` against
`tests/reference_scenes/restaurant_dense_interior.tscn` (pending). CI
`perf-gate` fails on (a) p99 > 16.6 ms, (b) any slot > its Iris Xe cap at p95,
(c) post-stream warm-up > 3 frames.

**Two new forbidden patterns** fence the contract:
- `unbudgeted_per_frame_ticking` — per-frame `_process` / `_physics_process` /
  Timer / running Tween without an ADR-0008 slot assignment is blocked at
  `/story-readiness` and `/code-review`.
- `directional_shadow_second_cascade` — second PSSM cascade busts Slot #1
  (+0.8–1.2 ms at 810p Iris Xe); requires ADR-0008 amendment with
  re-allocation pass.

**One new API decision** registered: `performance_budget_enforcement` (CI-time
reference scene gate, not runtime BudgetRegistry — explicit anti-pattern:
runtime instrumentation drift).

### ⚠️ Partials — reduced to 2

- **Audio architecture internals** (buses, pools, state-machine specifics live GDD-only). Acceptable for MVP; signal-contract side fully covered by ADR-0002. Frame-dispatch cost now covered by ADR-0008 Slot #6.
- **Post-Process Stack GDD-internal details** (chain order is in the Post-Process GDD; forbidden effects list is Pillar-level). Acceptable for MVP; lifecycle API covered by ADR-0004; perf budget covered by ADR-0008 Slot #3.

These are not gaps — they are deliberate GDD-scope scoping decisions.

---

## Cross-ADR Conflicts

### ✅ All prior conflicts remain closed

Conflict 1 (autoload collision) — CLOSED 2026-04-23 by ADR-0007.
Conflict 2 (ADR-0002 section signals outdated) — CLOSED 2026-04-22 by ADR-0002 4th-pass.
Conflict 3 (ADR-0002 missing SAI 4th-pass signals) — CLOSED 2026-04-22 by ADR-0002 4th-pass.

### ✅ ADR-0008 vs prior 7 ADRs — clean

| Candidate conflict | Check | Result |
|--------------------|-------|--------|
| ADR-0001 outline 2.0 ms vs ADR-0008 Slot #3 | Slot #3 aggregate = 2.5 ms = outline 2.0 + sepia 0.5 | Consistent (ADR-0001 input preserved verbatim) |
| ADR-0002 signal dispatch cost | Absorbed into emitter slots; no standalone line | Explicit in ADR-0008 Decision + GDD Requirements Addressed |
| ADR-0003 save ≤10 ms / load ≤2 ms | Preserved in non-frame budgets table | Identical values |
| ADR-0005 FPS hands SubViewport render | Absorbed into Slot #1 Rendering 3.8 ms | Explicit cross-reference |
| ADR-0006 Jolt 3D default | Slot #4 0.5 ms; specialist GREEN | Consistent with collision-layer contract |
| ADR-0007 autoload cascade ≤50 ms | Non-frame budgets table; PostProcessStack named dominant | Consistent with §Canonical Registration Table |
| SAI pre-impl gate #5 | Slot #2 6.5 ms envelope | CLOSED |
| combat-damage.md L233 reconciliation | Slot #2 absorbs 0.5 ms P95 | CLOSED |

**No cross-ADR conflicts detected.**

### Dependency ordering

ADR-0008 `Depends On` declares soft dependence on ADR-0001 / ADR-0002 / ADR-0007
(numeric inputs). None of those depend on ADR-0008 — **no cycle**.

ADR-0008 sits at the Feature layer (consolidator), above the Foundation ADRs.

```
Foundation (no ADR deps):
  1. ADR-0001: Stencil ID Contract
  2. ADR-0002: Signal Bus + Event Taxonomy
  3. ADR-0006: Collision Layer Contract
  4. ADR-0007: Autoload Load Order Registry

Depends on Foundation:
  5. ADR-0003: Save Format Contract (soft-deps ADR-0002)
  6. ADR-0005: FPS Hands Outline Rendering (exception to ADR-0001)

Depends on Foundation + Feature:
  7. ADR-0004: UI Framework (hard-deps ADR-0002 + ADR-0003)

Consolidator (soft-deps Foundation numeric inputs):
  8. ADR-0008: Performance Budget Distribution (inputs from ADR-0001 / -0002 / -0007)
```

⚠️ **All 8 ADRs are currently `Proposed` — none Accepted.** Stories
referencing a Proposed ADR are auto-blocked. 21 verification gates
outstanding across the chain:

| ADR | Gate count | Scope | Δ |
|-----|-----------:|-------|---|
| ADR-0001 | 4 | BaseMaterial3D stencil API · CompositorEffect stencil read Vulkan · same on D3D12 · perf on Iris Xe | — |
| ADR-0002 | 1 | smoke test (emit + subscribe + EventLogger + cross-autoload reference safety) | — |
| ADR-0003 | 3 | ResourceSaver FLAG_COMPRESS · DirAccess.rename · `duplicate_deep()` on nested typed Resources (A3 scope) | — |
| ADR-0004 | 3 | `accessibility_*` property names · `base_theme` property name · modal dismiss KB/M + gamepad | — |
| ADR-0005 | 5 | Vulkan prototype · D3D12 prototype · `resolution_scale` parity · rigged-animation no-artifacts · Gate 5 Shader Baker × `material_overlay` 4.6 export (A5) | — |
| ADR-0006 | 3 | class compiles · `project.godot` named slots · one migrated gameplay file | — |
| ADR-0007 | 2 | `[autoload]` block byte-match §Key Interfaces · ADR-0002 Gate 1 piggyback | — |
| ADR-0008 | **4** | Iris Xe reference scene measurement · RTX 2060 informative · D3D12 post-stream warm-up · Autoload boot cold-start | **+4 (new ADR)** |

Totals: 25 nominal gates, **21 distinct** in practice (ADR-0007 Gate 2 is
coincident with ADR-0002 Gate 1; ADR-0008 gates stand alone).

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-02-12)
**ADRs with Engine Compatibility section**: **8 / 8** ✓ (ADR-0008 added;
section present with correctly declared Knowledge Risk = MEDIUM — numeric
claims depend on 4.4–4.6 post-cutoff APIs and require empirical measurement
before Accepted).

### Post-Cutoff API Usage (ADR-0008 delta)

| API | Since | ADRs consuming |
|-----|-------|----------------|
| Stencil buffer (`BaseMaterial3D` / `ShaderMaterial` write; `CompositorEffect` read) | 4.5 | ADR-0001 |
| `CompositorEffect` + `Compositor` node | 4.3 | ADR-0001, ADR-0005, **ADR-0008 (inherits)** |
| Shader Baker | 4.5 | ADR-0001, ADR-0005 (A5), **ADR-0008 (non-frame budgets; first-run cost)** |
| D3D12 default on Windows | 4.6 | ADR-0001, ADR-0005, **ADR-0008 (descriptor heap reserve + post-stream warm-up)** |
| `Resource.duplicate_deep()` | 4.5 | ADR-0003 |
| AccessKit screen reader | 4.5 | ADR-0004 |
| Dual-focus (mouse vs keyboard/gamepad) | 4.6 | ADR-0004 |
| Jolt 3D default | 4.6 | ADR-0006, **ADR-0008 (Slot #4 + first-contact reserve)** |

ADR-0008 declares `RenderingServer.get_frame_profile_measurement()` as its
primary per-slot measurement tool (noted in Verification Contract as a
post-cutoff API). No conflict with ADR-0001's profiling strategy — ADR-0008
uses it at CI time against the reference scene, not at runtime.

### Deprecated API Check

`grep` across all 8 ADRs for patterns in `deprecated-apis.md`: **clean**. No
`connect("sig", obj, "method")`, no `yield`, no bare `duplicate()` without
`_deep`, no `get_world()`, no `VisibilityNotifier*`, no `TileMap`, no
`Navigation2D`/`3D`, no `Texture2D` in shader-parameter type annotations at
load-bearing sites. ADR-0008 explicitly rules out runtime BudgetRegistry
autoload (would have required ADR-0007 amendment + runtime instrumentation
drift — flagged in the `performance_budget_enforcement` api_decisions entry's
`not:` list).

### Stale Version References

None. All ADRs pinned to 4.6. ADR-0008 Last Verified = 2026-04-23. ADR-0007
Last Verified = 2026-04-23. ADR-0002 Last Verified = 2026-04-22 (4th-pass +
OQ-CD-1). ADR-0003 / 0004 / 0005 / 0006 Last Verified = 2026-04-23 (A3/A4/A5/A6).

### Post-Cutoff API Conflicts Between ADRs

None. ADR-0008's Jolt dependency (Slot #4 0.5 ms) is compatible with
ADR-0006's Jolt layer contract and A6 Risks row (fast-body `Area3D` tunneling
MEDIUM×LOW). ADR-0008's CompositorEffect scheduling assumptions inherit from
ADR-0001 verbatim — no contradiction.

### Engine Specialist Consultation

**Skipped this review run.** Rationale:

- ADR-0008 received its own pre-authoring godot-specialist consultation on
  2026-04-23 (**YELLOW** with 3 prose constraints + GREEN on Jolt 0.5 ms slot
  sizing). All 3 constraints were folded into the published ADR before write
  (shadow cascade = 1; PostProcessStack cold-boot dominance; D3D12
  post-stream 3-frame warm-up). Specialist's AudioServer reverb-swap
  observation (0.3–0.8 ms CPU stall on bus graph rebuild in the same frame as
  reverb swap) was absorbed by the 1.6 ms reserve slot in Slot #9 — logged
  for code-review phase when Audio's `section_entered` handler lands.
- No new GDDs or other ADRs authored beyond ADR-0008.
- A3–A6 amendments already validated in prior runs.

**Re-run the specialist next cycle** if (a) any verification gate surfaces
engine behaviour not captured in the reference docs, (b) a previously-deferred
ADR (outline algorithm, audio architecture, post-process chain) is promoted,
(c) engine version pin changes.

---

## Design Revision Flags (Architecture → Design Feedback)

### Three items carry forward unchanged — all producer-tracked

#### PC `CombatSystem.*` → `CombatSystemNode.*` rename

| GDD | Assumption | Reality | Action |
|-----|-----------|---------|--------|
| `design/gdd/player-character.md` L162, 200, 228, 426, 457, 466, 561, 762, 878, 885 (**10 sites**) | References frozen `CombatSystem.DamageType` / `CombatSystem.DeathCause` enum qualifiers | ADR-0002 OQ-CD-1 amendment renamed to `CombatSystemNode.*` (2026-04-22) | Producer-sequenced rename pass |

#### Audio LS-Gate-3

`design/gdd/audio.md` §Mission handler table L188–189 still 1-param
`section_entered(section_id)` / `section_exited(section_id)`. ADR-0002 Key
Interfaces declares these as 2-param (`reason:
LevelStreamingService.TransitionReason` appended). Audio GDD must grow the
handler table to show the 2nd param and document the 4-way `FORWARD / RESPAWN
/ NEW_GAME / LOAD_FROM_SAVE` branching per LS GDD CR-8.

**Action**: Audio-owned GDD touch-up.

#### Input ↔ Combat Takedown coordination

Combat GDD CR-3 specifies a **dedicated** `takedown` input (kbd F / gamepad Y)
distinct from `fire_primary`, live only when `SAI.takedown_prompt_active()`.
Input GDD L90 currently routes F / Y through a single `use_gadget` action that
"context-resolves to takedown" — older model predating Combat CR-3.

**Action**: Small Input GDD edit to split `use_gadget` into `use_gadget` +
dedicated `takedown` actions (catalog grows 29 → 30 actions).

---

**Flag these GDDs for revision in the systems index?** — **deferred (fourth
consecutive review).** PC rename is in producer queue; LS-Gate-3 is a
pre-impl gate tracked in LS GDD + SAI GDD; INP is an outstanding coordination
gap flagged in four consecutive reviews. All three will close as Audio /
Input / PC GDDs reach their next revision pass.

No new GDD assumptions conflict with verified engine behaviour or the current
ADR-0002 / ADR-0007 / ADR-0008 state.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` **does not exist**. Unchanged from prior
reviews. **Now actionable**: with all 8 priority ADRs written and Gap 2
closed, `/create-architecture` becomes the next natural artifact. Current
state (**8 ADRs Proposed**, 10/16 MVP GDDs designed) meets the recommended
pre-condition for architecture-document authoring once foundational ADRs
reach Accepted.

**Not a gap for this review**; flagged as the next architecture-level
artifact, after:
(a) the 3 GDD-coordination items close, and
(b) at least the foundation-layer ADRs (ADR-0001, ADR-0002, ADR-0006,
ADR-0007) pass their verification gates.

---

## Verdict: **PASS**

### Why PASS

- **Gap 2 CLOSED** — ADR-0008 allocates the full 16.6 ms / 60 fps budget across 9 named slots summing to exactly 16.6 ms. Verification contract defined. Two new forbidden patterns fence the contract.
- **Zero cross-ADR conflicts** — ADR-0008 is a consolidator; every numeric input matches existing claims in prior ADRs / GDDs verbatim.
- **Zero hard ADR gaps** — every extracted TR has at least one ADR addressing it, or is intentionally GDD-scope.
- **Engine consistent** — 8 ADRs all pinned to Godot 4.6; no stale version references; no deprecated-API consumption; no contradictory post-cutoff API assumptions.
- **Dependency graph clean** — no cycles; ADR-0008 soft-deps ADR-0001 / -0002 / -0007; topological order unchanged.
- **SAI pre-impl gate #5 CLOSED**, **combat-damage.md L233 reconciliation CLOSED** — two long-tracked cross-system flags resolved by ADR-0008.

### Execution-phase items remaining (do not block PASS)

These are story-level and production-level concerns, not architectural:

1. **21 verification gates outstanding** across 8 ADRs. These move ADRs
   Proposed → Accepted. Recommended priority order:
   - ADR-0001 Gates 1–3 (stencil API + CompositorEffect stencil read Vulkan/D3D12)
   - ADR-0002 Gate 1 (smoke test, coincident with ADR-0007 Gate 2)
   - ADR-0003 Gates 1–3 (A3 scope)
   - ADR-0005 Gate 5 (A5, Shader Baker × `material_overlay`)
   - ADR-0007 Gate 1 (`[autoload]` byte-match)
   - **ADR-0008 Gates 1–4** (reference scene measurements on Iris Xe + RTX 2060, D3D12 post-stream warm-up, autoload cold-start) — depends on reference scene authoring + CI perf-gate job configuration (both are separate tooling stories scoped out of this ADR)

2. **3 GDD-coordination touch-ups** (producer-owned, design-level):
   - PC rename pass: `CombatSystem.*` → `CombatSystemNode.*` (10 sites in `design/gdd/player-character.md`)
   - Audio GDD §Mission handler table L188–189: 1-param → 2-param with `reason: TransitionReason` + 4-way branching (LS-Gate-3)
   - Input GDD L90: split `use_gadget` into `use_gadget` + dedicated `takedown` (29 → 30 actions)

3. **Reference scene + CI perf-gate** (tooling):
   - `tests/reference_scenes/restaurant_dense_interior.tscn` — scoped to a prototyper / qa-lead story
   - GitHub Actions `perf-gate` job — scoped to a devops-engineer story

---

## Priority Action List (next 2–3 sessions)

### Session A — Advance foundational ADRs to Accepted

Begin ADR verification gate passes in the Godot 4.6 editor, recommended order:

1. **ADR-0001 Gates 1–3** (stencil buffer API in BaseMaterial3D, CompositorEffect stencil read on Vulkan, then on D3D12). Unblocks outline pipeline stories.
2. **ADR-0002 Gate 1** (smoke test: emit + subscribe + EventLogger). Simultaneously validates ADR-0007's cross-autoload reference safety (Gate 2 is coincident).
3. **ADR-0007 Gate 1** (`[autoload]` block byte-match vs §Key Interfaces). Runs the first time `project.godot` is generated in Technical Setup.

### Session B — Author reference scene + configure CI perf-gate

Parallel to Session A. Two separate tooling stories:

1. **Prototyper / qa-lead**: author `tests/reference_scenes/restaurant_dense_interior.tscn` — 12 guards at alert-density spike, stylized flat lighting, one autosave mid-capture, one music-state transition mid-capture.
2. **Devops-engineer**: configure GitHub Actions `perf-gate` job — runs `/perf-profile` capture, extracts per-slot p95, fails on cap breach or post-stream warm-up > 3 frames.

Once both land, ADR-0008 Gates 1–4 become executable.

### Session C — Close 3 GDD coordination items (producer-owned)

Can run parallel to Session A/B:

1. **PC rename pass**: `CombatSystem.*` → `CombatSystemNode.*` (10 sites).
2. **Audio GDD §Mission handler table**: 1-param → 2-param + branching.
3. **Input GDD**: split `use_gadget` into `use_gadget` + dedicated `takedown`.

---

**Re-run trigger**: `/architecture-review` after Session A passes its first
verification gate (any ADR moves Proposed → Accepted) OR after Session B
lands the reference scene, whichever comes first. Verdict stays PASS unless a
new design session introduces a fresh cross-ADR conflict.

**Gate guidance**: `/gate-check pre-production` is now eligible. Running it
now will likely return CONCERNS due to the 21 outstanding verification gates
(not ADRs, but their promotion path) and 10/16 MVP GDD authoring progress.
Running it after Session A's first gates pass + 3 coordination items close
should yield a clearer verdict.

**`/create-architecture`** (the master architecture document) can start any
time now — all 8 ADRs provide stable inputs. Recommended after Session A's
foundational ADR gates pass.

---

## Related

- `docs/architecture/requirements-traceability.md` — full TR matrix (refreshed 2026-04-23 third-run history entry added; coverage ~94% → ~99%)
- `docs/architecture/tr-registry.yaml` — stable TR-ID registry (v2, `last_updated: 2026-04-23`; no new TRs this run, no revisions)
- `docs/architecture/architecture-review-2026-04-22.md` — initial full-matrix baseline (pre-ADR-0007 / ADR-0008)
- `docs/architecture/adr-0008-performance-budget-distribution.md` — **new** — closes Gap 2; 9-slot allocation + non-frame budgets + 4 validation gates + 7 risks
- `docs/architecture/adr-0007-autoload-load-order-registry.md` — closed Conflict 1 + Gap 3 from prior review
- `docs/architecture/adr-0003-save-format-contract.md` — A3 applied (Gate 3 scope refined)
- `docs/architecture/adr-0004-ui-framework.md` — A4 applied (IG2 `InputContext.*` addendum)
- `docs/architecture/adr-0005-fps-hands-outline-rendering.md` — A5 applied (Gate 5 + Prototype-phase move)
- `docs/architecture/adr-0006-collision-layer-contract.md` — A6 applied (Jolt tunneling Risks row)
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — 4th-pass amendment + 20+ downstream "load order N" → "per ADR-0007" redirects
- `docs/registry/architecture.yaml` — 9 performance_budgets + 1 api_decision (`performance_budget_enforcement`) + 2 forbidden patterns (`unbudgeted_per_frame_ticking`, `directional_shadow_second_cascade`) registered from ADR-0008
- `design/gdd/stealth-ai.md` L684 — Recommended Follow-up #5 CLOSED by ADR-0008
- `design/gdd/combat-damage.md` L233 — cross-system reconciliation CLOSED by ADR-0008 Slot #2
- `design/gdd/systems-index.md`
- `production/session-state/active.md`
