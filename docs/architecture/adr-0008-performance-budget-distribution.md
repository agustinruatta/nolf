# ADR-0008: Performance Budget Distribution

## Status

Proposed *(amended 2026-04-28 per `/review-all-gdds` — Slot-8 panic-onset reserve allocation registered + autoload-cascade row count 7 → 10. Further amended 2026-04-28 night per Dialogue & Subtitles Phase 2 propagation cycle — D&S Slot 8 sub-claim 0.10 ms peak event-frame registered (steady-state pool sum 0.45 → 0.55 ms / margin 0.35 → 0.25 ms). Architectural decision unchanged.)*

## Date

2026-04-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Performance |
| **Knowledge Risk** | MEDIUM — budget allocation itself is numerical (engine-agnostic), but the Iris Xe numbers below depend on Godot 4.6 defaults: Jolt as the 3D physics backend, **Vulkan on both Linux and Windows** (project Amendment A2 disables the Godot 4.6 D3D12 Windows default — `project.godot [rendering] rendering_device/driver.windows="vulkan"`), Forward+ Mobile renderer, Shader Baker first-run cost, and CompositorEffect scheduling. LLM training data predates 4.4–4.6. Every numeric claim below requires empirical verification against Godot 4.6 on the reference scene before Accepted (see Validation Criteria). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/modules/rendering.md`; `docs/engine-reference/godot/modules/physics.md`; `docs/engine-reference/godot/breaking-changes.md`; `docs/engine-reference/godot/deprecated-apis.md`; ADR-0001 (outline pipeline); ADR-0007 (autoload registration order); `design/gdd/stealth-ai.md` AC-SAI-4.4 + Recommended Follow-ups; `design/gdd/combat-damage.md` L233 GuardFireController budget note. |
| **Post-Cutoff APIs Used** | Jolt 3D physics (Godot 4.4 optional → 4.6 default); Shader Baker (Godot 4.5+, referenced for cold-boot accounting); CompositorEffect (Godot 4.6 outline pipeline, budget inherited from ADR-0001). ~~D3D12 backend (Godot 4.6 Windows default, budget reserve sized for descriptor heap behaviour).~~ **REMOVED 2026-04-30 Amendment A2** — D3D12 not targeted; reserve rationale tightened (see §Risks closures). |
| **Verification Required** | (a) Restaurant dense-interior reference scene must sustain 60 fps on Iris Xe Gen 12 @ 1080p × 0.75 scale with all 9 allocated slots active simultaneously (12 guards in COMBAT, outline + sepia active, music swap event, one save write). (b) Per-slot measurements must match the allocation below within tolerance specified per slot. ~~(c) D3D12 post-stream warm-up allowance (3 frames) must be confirmed on Windows.~~ **CLOSED BY REMOVAL 2026-04-30 (Amendment A2)** — D3D12 not targeted; Vulkan-only on both platforms. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (outline pipeline budget — 2.0 ms per-frame claim is a fixed input); ADR-0002 (signal dispatch cost — Signal Bus emits allocated to publisher slots, not its own line); ADR-0007 (autoload registration order — **10 autoloads' boot cascade per 2026-04-27 amendment** [Events, EventLogger, SaveLoad, InputContext, LevelStreamingService, PostProcessStack, Combat, FailureRespawn, MissionLevelScripting, SettingsService] is budgeted here as ≤50 ms cold-start; row updated 2026-04-28 from prior 7-autoload claim). All three must remain Accepted or Proposed; a revision that changes their cost claims invalidates the allocation. |
| **Enables** | SAI pre-implementation gate #5 (stealth-ai.md Recommended Follow-up line 540); all ticking-system stories (each story can now cite its ADR-0008 slot and be tested against the Restaurant reference scene); Pre-Production phase gate (consolidates the cross-cutting frame-time contract that was previously distributed across 5 GDDs). |
| **Blocks** | No epic is hard-blocked, but stealth-ai.md and combat-damage.md both name this ADR as the authority that finalises the SAI/Combat GuardFireController reconciliation. Those systems can start implementation without it, but story-level perf gates cannot pass without the reference-scene measurements this ADR defines. |
| **Ordering Note** | This ADR is a *consolidator*, not a *decider of new behaviour*. Every numeric input comes from a prior ADR or GDD; the novelty is (a) the sum fits 16.6 ms, (b) the residual slice is explicitly pooled for not-yet-designed systems, (c) verification is centralised on a single reference scene. |

## Context

### Problem Statement

The project's 60 fps / 16.6 ms frame-time contract is declared in `technical-preferences.md` and in ADR-0001's registry entry, but has never been distributed to per-system allocations. Six independent GDDs and one ADR have each carved a per-frame or per-operation budget slot in isolation:

- Outline Pipeline 2.0 ms (ADR-0001)
- Post-Process chain 2.5 ms on Iris Xe (`design/gdd/post-process-stack.md` TR-PP-009)
- Stealth AI 6.0 ms mean per 12 guards (`design/gdd/stealth-ai.md` TR-SAI-018)
- Combat GuardFireController 0.3 ms mean / 0.5 ms P95 declared as an INDEPENDENT line (`design/gdd/combat-damage.md` L233, specifically flagged for reconciliation here)
- Save latency ≤10 ms, load I/O ≤2 ms (`design/gdd/save-load.md` / ADR-0003)
- Level Streaming transition ≤0.57 s p90 (`design/gdd/level-streaming.md` TR-LS-011)
- Audio 16-voice pool sized but no per-frame ms claim (TR-AUD-007)

Two structural gaps result:

1. **Sum never verified**: 2.0 + 2.5 + 6.0 + 0.5 = 11.0 ms of per-frame claims. No artifact verifies that the remaining 5.6 ms is sufficient for rendering + Jolt physics + all other ticking systems (Player, FC, Combat non-GF, Civilian AI, Mission Scripting, Document Collection, Dialogue, HUD, Audio dispatch, UI, Signal Bus).
2. **Residual unclaimed**: systems not yet designed (Civilian AI, Mission & Level Scripting, Failure & Respawn, HUD Core, Document Collection, Dialogue & Subtitles) will each claim frame-time when their GDDs land. Without a pre-agreed pool, late-arriving systems can push the total over 16.6 ms and force retroactive cuts to already-implemented systems.

`architecture-review-2026-04-23.md` Gap 2 is the tracking record: this is the *last remaining architectural gap* before Pre-Production can advance. SAI pre-implementation gate #5 is blocked on it.

### Constraints

- **16.6 ms hard cap at 60 fps** (technical-preferences.md, ADR-0001 registry entry). Non-negotiable for MVP — degraded FPS is inconsistent with the project's period-authenticity pillar (no dynamic scaling framerate UX).
- **Iris Xe Gen 12 min-spec** at 1080p × 0.75 scale = 810p effective. Shipping target: PC (Linux + Windows, Steam). No mobile, no console. Iris Xe is the binding constraint because it is the weakest GPU the project commits to.
- **RTX 2060 target hardware** at 1080p native. Used for target-experience measurements, not for contract enforcement.
- **Fixed Godot 4.6 defaults**: Jolt 3D physics (cannot substitute Godot Physics 3D without cost re-measurement), Forward+ Mobile renderer (Mobile profile required on Iris Xe — Forward+ Desktop is out of budget). **Vulkan on both Linux and Windows** per project decision (Amendment A2 — `project.godot [rendering] rendering_device/driver.windows="vulkan"` disables Godot 4.6's D3D12 default).
- **No dynamic resolution scaling, no dynamic LOD falloff, no runtime post-process toggling**. Iris Xe's 0.75 scale is applied at startup and held. (ADR-0001 validation gate 4; `design/gdd/post-process-stack.md` TR-PP-008.)
- **Directional shadows only, one cascade**. The specialist review of this ADR (2026-04-23) identified cascade count as the single largest optimism risk in the rendering allocation: a second cascade adds roughly 0.8–1.2 ms at 810p on Iris Xe, which would bust the rendering slot. Enforced as a Consequences risk + Validation Gate.

### Requirements

- Allocate the full 16.6 ms across named slots that sum exactly to 16.6 ms (no arithmetic drift).
- Preserve every prior budget claim: outline 2.0 ms stands, post-process chain 2.5 ms stands, SAI 6.0 ms stands, GuardFireController 0.5 ms P95 stands.
- Provide a mechanism for not-yet-designed systems to claim a slot without negotiating against already-implemented systems: a pooled residual.
- Hold a 10% reserve (1.6 ms) unallocated for OS jitter, Jolt first-contact spikes, AudioServer reverb-swap CPU stalls, and unknowns. (Was originally sized in part for D3D12 descriptor heap pressure; D3D12 dropped 2026-04-30 Amendment A2. The 1.6 ms reserve magnitude stays — same justification holds for OS jitter + Jolt spikes + AudioServer + unknowns alone.)
- Scope this ADR to per-frame budgets AND non-frame synchronous operations (save, load, LS transition, shader bake, autoload boot). Memory budgets (4 GB ceiling) are out of scope — deferred to a future ADR.
- Produce a verification contract that CI can enforce on every PR: one reference scene (Restaurant dense-interior), one command (`/perf-profile`), one pass/fail threshold (16.6 ms total frame time).

## Decision

### Per-Frame Budget Allocation — Iris Xe min-spec (normative, 60 fps, worst-case)

The 16.6 ms frame budget is divided into **9 named slots** summing to exactly 16.6 ms at 1080p × 0.75 scale (810p effective) on Intel Iris Xe Gen 12:

| # | Slot | Owner | Budget (ms) | Source |
|---|------|-------|------------:|--------|
| 1 | Rendering (opaque + directional shadows + cull + transparent) | Godot 4.6 engine (Forward+ Mobile) | **3.8** | Residual after explicit claims; specialist-validated at 810p stylized flat Forward+ with 1500 draw calls |
| 2 | Guard systems (SAI perception 3.0 + nav 2.0 + signals 1.0 for 12 guards; + Combat GuardFireController 0.5 ms P95 at 3-guard COMBAT density) | stealth-ai-system + combat-damage-system | **6.5** | TR-SAI-018 + combat-damage.md L233 (reconciliation resolved by this ADR) |
| 3 | Post-Process chain (outline CompositorEffect + sepia dim + resolution-scale composite) | outline-pipeline-system + post-process-stack-system | **2.5** | TR-OUT-006 (2.0) + TR-PP-009 sepia (0.5) |
| 4 | Jolt physics step (player + 12 guard CharacterBody3D + dart RigidBody3D + static world) | Godot 4.6 engine (Jolt default) | **0.5** | Specialist GREEN; includes first-contact allocation margin |
| 5 | Player Character + FootstepComponent + Combat non-GuardFire logic (move_and_slide, footstep emit ~3.5 Hz, damage routing, hitscan on fire, dart tick, fist ShapeCast swing) | player-character + footstep-component + combat-damage | **0.3** | Event-driven + light per-frame tickers |
| 6 | Audio dispatch (AudioServer mix + 16-voice spatial pool + subscriber handlers on Events signals) | audio-manager | **0.3** | TR-AUD-007 pool size fixed; no per-frame alloc |
| 7 | UI (HUD signal-driven refresh + Control.process on active modal surface only) | hud-core + modal surfaces | **0.3** | ADR-0004 forbids polling; refresh on signal emission only |
| 8 | Pooled residual (Civilian AI, Mission & Level Scripting, Document Collection, Dialogue & Subtitles, Failure & Respawn, Signal Bus dispatch overhead not absorbed by emitters) | systems not yet designed | **0.8** | Each GDD claims its sub-slot at design time; this pool is the binding cap for the group |
| 9 | Reserve (unallocated, 10% margin) | — | **1.6** | OS jitter / shader compile / Jolt spikes / AudioServer reverb-swap CPU stalls / unknowns. (D3D12 heap pressure dropped 2026-04-30 Amendment A2 — D3D12 not targeted.) |
| | **TOTAL** | | **16.6** | 60 fps contract (technical-preferences.md) |

**Binding rule**: every per-frame slot is a **cap**, not a target. A system that exceeds its slot at the Restaurant reference scene fails CI regardless of whether total frame time is below 16.6 ms — because exceeding one slot robs another system's headroom and may mask a compounding bust in the field.

### Per-Frame Budget Allocation — RTX 2060 target (informative, not a cap)

RTX 2060 at 1080p native typically delivers ~7.6 ms of idle headroom against the same allocation. Per-system means on RTX 2060 land near:

| Slot | RTX 2060 typical (ms) | Iris Xe cap (ms) | Headroom |
|------|----------------------:|-----------------:|---------:|
| Rendering | 2.5 | 3.8 | 1.3 |
| Guard systems | 4.5 | 6.5 | 2.0 |
| Post-Process chain | 1.5 | 2.5 | 1.0 |
| Jolt physics step | 0.3 | 0.5 | 0.2 |
| Player/FC/Combat non-GF | 0.2 | 0.3 | 0.1 |
| Audio dispatch | 0.2 | 0.3 | 0.1 |
| UI | 0.2 | 0.3 | 0.1 |
| Pooled residual | 0.5 | 0.8 | 0.3 |
| **Sum typical** | **~9.9** | **—** | **6.7 idle** |

RTX 2060 numbers are for target-experience telemetry (not CI gates). Mirrors the approach in ADR-0001 (outline: 2.0 ms Iris Xe cap vs 0.8–1.5 ms RTX 2060 target).

### Non-Frame Budgets

Synchronous operations that do not run every frame but have latency contracts:

| Operation | Budget | Source / Rationale |
|-----------|--------|---------------------|
| Save slot write (sync, hidden behind fade-to-black for manual saves; invisible for autosave at section entry) | ≤10 ms | ADR-0003 / TR-SAV-013 — atomic write with tmp → rename + sidecar |
| Load slot I/O (hidden inside LS section load) | ≤2 ms | ADR-0003 / TR-SAV-013 — amortised into the 200–500 ms SWAPPING phase |
| Level Streaming section transition (p90 Iris Xe) | ≤570 ms | TR-LS-011: 33 ms snap-out + ≤500 ms SWAPPING + 33 ms snap-in |
| Shader compile (first-run via Shader Baker) | 0–500 ms one-time | `design/gdd/outline-pipeline.md` §BAKING; scoped out of frame budget |
| Autoload boot (`_ready()` cascade across **10 autoloads** per ADR-0007, 2026-04-27 amendment) | ≤50 ms total cold-start | Events (1) → EventLogger (2) → SaveLoad (3) → InputContext (4) → LevelStreamingService (5) → PostProcessStack (6) → Combat (7) → FailureRespawn (8) → MissionLevelScripting (9) → SettingsService (10). ADR-0007's own estimate (~10 × <1 ms ≈ <10 ms pure autoload instantiation) plus scene tree setup and compositor pipeline registration. **PostProcessStack is the dominant contributor** (5–15 ms Vulkan compositor pipeline registration — specialist note 2026-04-23, originally 5–15 ms Vulkan + 5–10 ms D3D12 additional; D3D12 contribution dropped 2026-04-30 Amendment A2 since D3D12 not targeted). If autoload boot is profiled as slow, check PostProcessStack first. Combat (slot 7), FailureRespawn (slot 8), and MissionLevelScripting (slot 9) are stateless enum + method definitions (negligible instantiation cost); SettingsService (slot 10) reads `user://settings.cfg` via FileAccess (~1–3 ms first-launch / ~0.5 ms thereafter). 50 ms cap absorbs the new claimants with margin; row count 7 → 10 updated 2026-04-28 by `/review-all-gdds` to reflect ADR-0007's current canonical table. |
| ~~**Post-stream warm-up window on Windows/D3D12**~~ | ~~**3 frames (~50 ms)** allowed over-budget immediately after a Level Streaming transition completes before frame-budget SLAs resume~~ | **REMOVED 2026-04-30 Amendment A2** — D3D12 not targeted; this allowance was D3D12-specific. On Vulkan there is no analogous descriptor-heap-driven post-stream stall. The 1.6 ms reserve is adequate for Vulkan post-stream behavior. CI perf-gate no longer needs the post-stream skip-frames logic. |

**Memory ceiling (4 GB, technical-preferences.md)** is explicitly **out of scope** for this ADR. A future ADR will distribute the memory budget per system once Level Streaming implementation lands (per-section geometry + audio streams + guard NavMeshes + save snapshots dominate).

### Verification Contract

**Reference scene**: `tests/reference_scenes/restaurant_dense_interior.tscn` — a worst-case authoring of the Restaurant section with:

- 12 guards at alert density spike (3 in COMBAT firing, 5 in SEARCHING, 4 in SUSPICIOUS)
- Player at Eve starting position, moving at Sprint
- Outline + sepia post-process active (e.g., Document Overlay open mid-measurement for one pass; closed for baseline pass)
- Music state transition triggered mid-capture (forces AudioEffectReverb swap + crossfade)
- One autosave write triggered mid-capture
- Lighting: directional shadows = 1 cascade only, no dynamic lights, stylized flat materials

**Measurement tools**:

- `/perf-profile` skill runs a scripted 30-second capture of the scene on the current build
- Per-slot timings extracted from Godot profiler + AI-programmer-owned `tests/integration/stealth-ai/stealth_ai_perf_budget_test.gd` for the guard-systems slot
- Rendering slot measured via `RenderingServer.get_frame_profile_measurement()` (post-cutoff API, see Engine Compatibility)

**CI enforcement**:

- GitHub Actions `perf-gate` job on every merge-to-main and every PR touching `src/` or reference-scene authoring
- Fails the build if: (a) total frame time p99 > 16.6 ms, OR (b) any slot exceeds its Iris Xe cap at p95 (guard-systems 6.5 ms, post-process 2.5 ms, rendering 3.8 ms, etc.), OR (c) post-stream warm-up exceeds 3 frames to return under cap
- Passes with warnings if any slot is within 10% of its cap (advisory to the owning system's lead)

**Per-story budget gate**: every story that introduces per-frame ticking work embeds its ADR-0008 slot reference in its Acceptance Criteria row, following the pattern:

> AC-XXX-N: **GIVEN** Restaurant reference scene with [system] active, **WHEN** `/perf-profile` runs 30-second capture, **THEN** [system]'s slot (ADR-0008 slot N) stays within [N.N] ms p95.

### Architecture Diagram

```
┌─────────────────────────── 16.6 ms / frame (60 fps cap) ───────────────────────────┐
│                                                                                      │
│  Rendering        Guard Systems         Post-Process    Jolt   Other    Reserve      │
│  (Forward+M)      (SAI + GuardFire)     (Outline+Sepia) Phys.  (5+6+7+8) (10%)      │
│                                                                                      │
│  ┌──────────┬─────────────────┬──────────┬───────────┬───┬───────────────┬────────┐ │
│  │  3.8 ms  │     6.5 ms      │  2.5 ms  │  0.5 ms   │0.3│ 0.3│0.3│ 0.8  │ 1.6 ms │ │
│  │          │                 │          │           │   │    │   │      │        │ │
│  │ opaque   │ perception 3.0  │ outline  │ Jolt step │P/F│Audi│UI │pooled│OS jit- │ │
│  │ shadows  │ nav 2.0         │  2.0     │ first-    │/C │ mix│   │resi- │ ter,   │ │
│  │ cull     │ signals 1.0     │ sepia    │ contact   │no │    │   │dual  │shader  │ │
│  │ trans-   │ GuardFire 0.5   │  0.5     │ margin    │n- │    │   │(CAI, │bake,   │ │
│  │ parent   │                 │          │           │GF │    │   │Miss, │reverb  │ │
│  │          │ (Combat P95     │          │           │   │    │   │Doc,  │swap,   │ │
│  │          │  absorbed)      │          │           │   │    │   │Dial, │...)    │ │
│  │          │                 │          │           │   │    │   │FR,SB)│        │ │
│  └──────────┴─────────────────┴──────────┴───────────┴───┴────┴───┴──────┴────────┘ │
│                                                                                      │
│  Constraint: directional shadow cascade = 1  (busts slot #1 if raised)              │
│  Constraint: Vulkan-only on both Linux and Windows (project Amendment A2)           │
└──────────────────────────────────────────────────────────────────────────────────────┘

Non-frame latencies (sync, not on the 16.6 ms clock):
  Save write       ≤10 ms (ADR-0003)
  Load I/O         ≤2 ms  (amortised into LS SWAPPING)
  LS transition    ≤570 ms p90 (snap-out 33 + SWAPPING ≤500 + snap-in 33)
  Shader bake      0–500 ms one-time (4.5+ Baker)
  Autoload boot    ≤50 ms cold-start (10 autoloads per ADR-0007 2026-04-27 amendment, PostProcessStack dominant)
```

### Key Interfaces

This ADR does not introduce code interfaces. It introduces a **contract** that other ADRs and GDDs reference:

```gdscript
# Per-slot budget lookup (informative; not a runtime API).
# This ADR does not add a runtime BudgetRegistry class or autoload — that would
# be instrumentation drift. Budgets are verified at CI time against the reference
# scene, not polled at runtime.
#
# Cross-reference pattern in downstream ADRs and GDDs:
#   "[System] stays within its ADR-0008 Slot N cap of N.N ms p95."
#
# Registry entry in docs/registry/architecture.yaml:
#   performance_budgets entries are added per slot (see Migration Plan step 3).
```

## Alternatives Considered

### Alternative A: Strict per-system allocation (CHOSEN)

- **Description**: Enumerate every ticking system with a hard ms budget. CI perf-profile gates enforce per-slot caps. Not-yet-designed systems share a named pooled residual they subdivide at GDD authoring time.
- **Pros**: (a) Sum is verifiable (∑ slots = 16.6 ms); (b) CI can fail a PR that busts a specific slot without needing the total to bust; (c) single owner per slot simplifies accountability; (d) pooled residual gives late-arriving systems a pre-agreed envelope without renegotiating against already-implemented systems.
- **Cons**: (a) Requires discipline from every ADR/GDD to cite its slot; (b) pooled residual relies on each not-yet-designed system's author accepting that 0.8 ms is shared; (c) numerical claims may need revision as measurements come in (this ADR treats Iris Xe numbers as commitments, not guesses — Validation Gate 1 forces measurement before Accepted).
- **Rejection Reason**: Not rejected — chosen.

### Alternative B: Tiered band allocation

- **Description**: Group systems into tiers (Foundation / Core / Auxiliary) with aggregate tier budgets. Each tier's owners self-subdivide without a fixed per-system cap.
- **Pros**: (a) Less churn when a system slightly exceeds its expected slot if another system in the same tier is under; (b) less verbose registry.
- **Cons**: (a) Loses per-system accountability — a single system can silently consume another system's headroom without CI flagging; (b) tier-level CI gates catch total bust but not cross-system drift; (c) when a tier owner is unclear (who owns "Core" perf enforcement?), decisions escalate without a clear path.
- **Rejection Reason**: The project already treats perf as a pillar-adjacent concern (period authenticity requires stable 60 fps); accountability-per-owner is the stronger discipline. Tiered bands would delay the SAI/Combat GuardFireController reconciliation (combat-damage.md L233) because there'd be no named slot to reconcile against.

### Alternative C: Critical-path enumeration only

- **Description**: Enumerate budgets only for systems with prior claims (outline, SAI, post-process, GuardFire, save/load, LS transition). Leave all other systems as "best-effort within residual" without a named pool.
- **Pros**: (a) Minimal ADR scope; (b) no risk of wrong numbers for not-yet-designed systems.
- **Cons**: (a) Leaves residual unclaimed — systems can blow the budget by accumulation without any single system being obviously at fault; (b) no mechanism for late-arriving systems to know how much they have; (c) doesn't actually resolve Gap 2 from the architecture review because the sum is still unverified.
- **Rejection Reason**: Fails the stated requirement "Produce a verification contract that CI can enforce." Without a named pool for the residual, CI can only measure total frame time — which detects problems but doesn't attribute them.

## Consequences

### Positive

- **Gap 2 from `architecture-review-2026-04-23.md` closes** with this ADR Accepted; Pre-Production gate becomes achievable pending the 4 validation gates below.
- **SAI pre-implementation gate #5 unblocks** — stealth-ai.md Recommended Follow-up line 540 is resolved.
- **Combat GuardFireController reconciliation closes** — combat-damage.md L233 "Cross-system budget reconciliation is flagged for the pending performance-budget ADR" now has a named slot (combined 6.5 ms envelope).
- **Late-arriving systems have a pre-agreed pool** (0.8 ms for Civilian AI, Mission Scripting, Document Collection, Dialogue & Subtitles, Failure & Respawn, Signal Bus dispatch). No renegotiation needed against already-implemented systems.
- **One reference scene, one verification command** (`/perf-profile` on `tests/reference_scenes/restaurant_dense_interior.tscn`) replaces ad-hoc per-system benchmarks with a single measurable artifact.
- **Per-story perf gates become writable** — every story can cite its ADR-0008 slot and have a measurable acceptance criterion, rather than hand-waving "within budget."

### Negative

- **Rendering 3.8 ms is tight on Iris Xe** — specialist-validated achievable, but sits at the optimistic edge of the plausible range for Forward+ Mobile stylized @ 810p with 1500 draw calls. Any art-side decision to raise draw call cap, add a second shadow cascade, or introduce non-flat shading invalidates this number.
- **Guard systems 6.5 ms is a large slice** (39% of frame budget) — reflects the SAI + Combat pillar weight of the project, but leaves less room for future systems that weren't in the original scoping. 12-guard cap is load-bearing; raising it to 16 requires a re-allocation pass.
- **Pooled residual 0.8 ms across 6 not-yet-designed systems** is thin — roughly 0.13 ms per system average. Systems with heavier runtime needs (Civilian AI at crowd density, Mission Scripting during scripted sequences) may need to renegotiate by pulling from the 1.6 ms reserve via a future ADR-0008 amendment. **Sub-claims registered as of 2026-04-28 night** (informative — not contractual): CAI 0.30 ms p95 (`civilian-ai.md:394`); MLS 0.1 ms steady-state + 0.3 ms peak (`mission-level-scripting.md:528`); DC 0.05 ms peak event-frame (`document-collection.md:117`); F&R ~0 ms outside flow (`failure-respawn.md:272`); **Dialogue & Subtitles 0.10 ms peak event-frame** (`dialogue-subtitles.md:692` — registered 2026-04-28 night per D&S Phase 2 propagation cycle / OQ-DS-2; cost driver = signal-emit event frame composition F.4 = `audio_play_call + dictionary_write + queue_eviction + dialogue_line_started_emit + tr_render_resolve` ≈ 0.075 ms typical worst case + 0.001 ms unconditional `_stopping_for_interrupt` flag guard per CR-DS-7 v0.3; provisional pending tools-programmer profiler measurement on minimum-spec hardware per AC-DS-9.1 ADVISORY); Signal-Bus dispatch overhead unspecified. Steady-state sum ≈ **0.55 ms** (CAI 0.30 + MLS 0.1 + DC 0.05 + D&S 0.10) — within 0.8 ms cap with 0.25 ms residual margin for Signal-Bus dispatch + future systems. Panic-onset frame is the worst case and is governed by the reserve carve-out registered in §Risks (2026-04-28 amendment); D&S's rare three-way priority-resolver eviction (in-flight line interrupted, queue evicted, new line started) may momentarily burst to ~0.13 ms — acceptable brief exceedance on a non-recurring frame, not a steady-state violation per `dialogue-subtitles.md:692`.
- ~~**Windows/D3D12 post-stream warm-up allowance adds complexity** to CI gate enforcement — the gate must track section-transition timing and skip the first 3 frames. Engineering cost borne by devops-engineer (perf-gate job).~~ **REMOVED 2026-04-30 Amendment A2** — D3D12 not targeted; CI perf-gate is simpler now (no skip-frames logic needed).
- **Measurements are Godot 4.6-specific** — any engine upgrade (4.7, 5.0) requires full re-measurement across all 9 slots before this ADR can be considered still Accepted. Documented as a revisit trigger.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|:-----------:|:------:|------------|
| **Directional shadow cascade count raised to 2** (for visual quality) busts rendering slot by 0.8–1.2 ms | LOW | HIGH | Cascade count = 1 locked as explicit Constraint in this ADR; Art Bible 8 already restricts shadow treatment; CI perf-gate would catch the regression but ship-blocking if art direction pushes back. Escalation path: ADR-0008 amendment with re-allocation pass. |
| **PostProcessStack cold-boot exceeds autoload budget** (compositor pipeline registration is the dominant contributor) | LOW | LOW | 50 ms autoload budget absorbs the specialist-estimated 5–15 ms Vulkan compositor pipeline registration with margin. (Pre-2026-04-30 also factored in 5–10 ms additional D3D12 cost; D3D12 dropped per Amendment A2 reduces this risk profile from MEDIUM probability to LOW.) If the number is ever profiled over cap, ADR-0007 and ADR-0001 are revisited together. Non-blocking — first-run cost is off the 60 fps clock. |
| ~~**D3D12 descriptor heap stall mid-session** (new shader variants or texture bindings crossing heap page boundary after a section transition)~~ | ~~MEDIUM~~ CLOSED | MEDIUM | **CLOSED BY REMOVAL 2026-04-30 Amendment A2** — D3D12 not targeted. Vulkan does not have the same descriptor-heap stall behavior. The 1.6 ms reserve absorbs single-frame stalls on Vulkan adequately. Shader Baker pre-compilation (ADR-0005 Gate 5) remains valuable for cold-boot, but the mid-session descriptor-heap-stall risk is eliminated by Vulkan-only. |
| **AudioEffectReverb swap CPU stall on section transition** (Godot 4.6 synchronous rebuild of bus graph, 0.3–0.8 ms CPU stall on game thread) | MEDIUM | LOW | Absorbed by 1.6 ms reserve on the transition frame; scene transition fade-to-black hides any one-frame hitch. TR-AUD-009 per-section reverb swap already fires on `section_entered`. No additional mitigation. |
| **Jolt first-contact allocation spike** (new collision pair adds 0.1–0.3 ms transient) | LOW | LOW | Covered by 0.5 ms Jolt slot margin + 1.6 ms reserve. Specialist GREEN on slot sizing. |
| **Pooled residual 0.8 ms exceeded** by not-yet-designed systems (Civilian AI crowd density, Mission Scripting cutscene logic) | MEDIUM | MEDIUM | Each system's GDD must claim its sub-slot at design time — authoring gate. If the pool is insufficient, producer escalates to ADR-0008 amendment before GDD is Approved. Early-warning via `/design-review` checking budget claims against the pool. |
| **Slot 8 panic-onset frame busts pooled-residual 0.8 ms cap** at the worst-case Restaurant 8-civilian gunfight (8 × ~112 µs = ~896 µs CAI alone, before MLS / DC / Dialogue / F&R / Signal-Bus dispatch claim their share) — registered 2026-04-28 per `/review-all-gdds` finding. | MEDIUM | HIGH | **Reserve carve-out (registered 2026-04-28 amendment)**: up to **0.6 ms of the 1.6 ms global reserve** is pre-allocated to absorb single-frame Slot-8 panic-onset spikes. Trigger conditions: (a) `civilian_panicked` emission count ≥ 4 within a single physics frame; OR (b) any frame where Slot 8 measured cost exceeds 0.8 ms. The carve-out is single-frame only — sustained Slot-8 over-cap is a design defect that requires a re-allocation pass. CI perf-gate exempts panic-onset frames from the Slot-8 cap if (a) holds; the global reserve cap (1.6 ms) is unchanged but the available reserve outside panic frames effectively becomes 1.0 ms. **Producer + technical-director sign-off required** to invoke this carve-out per civilian-ai.md §C.0; recorded as a use of the global reserve, not a permanent Slot-8 expansion. Mitigations to avoid invocation: (i) cap concurrent panic transitions at 4 with a 1-frame stagger (CAI design call); (ii) reduce Restaurant N_active_max from 8 to 6. |
| **Numbers are Iris Xe-specific** — Intel roadmap changes (Lunar Lake Xe2, Battlemage) may shift baseline; Steam user hardware distribution may drift | LOW | MEDIUM | Revisit trigger: any change to `technical-preferences.md` min-spec hardware or engine version triggers full re-measurement. Steam hardware survey review scheduled at Polish phase gate. |
| **Godot 4.7 / 5.0 engine upgrade** invalidates the 4.6-specific measurements | LOW (pinned 4.6) | HIGH | Engine version is pinned in `docs/engine-reference/godot/VERSION.md`. Any upgrade re-runs all 9 slots against the reference scene. Documented revisit trigger. |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `design/gdd/outline-pipeline.md` | TR-OUT-006: "Performance budget: ≤2.0 ms at 1080p (target 0.8-1.5 ms on RTX 2060); fits within 75% scale on Iris Xe." | Outline 2.0 ms is a fixed input to Slot #3 (Post-Process chain 2.5 ms total); ADR-0001's claim stands. |
| `design/gdd/post-process-stack.md` | TR-PP-009: "Performance budget: sepia pass ≤0.5 ms at 1080p RTX 2060; full chain ≤2.5 ms on Iris Xe at 0.75 scale." | Slot #3 allocated 2.5 ms total — matches exactly. Outline + sepia + resolution-scale composite fits. |
| `design/gdd/stealth-ai.md` | TR-SAI-018: "Performance budget: 6 ms mean per 12 guards (perception 3 + nav 2 + signals 1)." + Recommended Follow-up line 540: "`/architecture-decision performance-budget-distribution` as a cross-system ADR." | Slot #2 allocated 6.5 ms combined envelope (6.0 SAI + 0.5 Combat GuardFireController P95). Recommended Follow-up is resolved by this ADR being Proposed and tracked to Accepted. |
| `design/gdd/combat-damage.md` | L233 GuardFireController budget note: "Combat's per-guard timer cost is now declared as an INDEPENDENT Combat budget line of 0.3 ms mean / 0.5 ms P95 at 3-guard-COMBAT density... Cross-system budget reconciliation is flagged for the pending performance-budget ADR." | Slot #2 absorbs Combat GuardFireController into the combined 6.5 ms guard-systems envelope. Reconciliation flag is resolved. |
| `design/gdd/save-load.md` | TR-SAV-013: "Performance budget: ≤10 ms save latency, ≤2 ms I/O load (hidden in Level Streaming cost)." | Non-frame budgets table: save ≤10 ms, load ≤2 ms. Budgets stand unchanged; this ADR consolidates them into the verification contract. |
| `design/gdd/level-streaming.md` | TR-LS-011: "Performance budget: ≤0.57 s total p90 on Iris Xe (33 ms snap-out + ≤500 ms SWAPPING + 33 ms snap-in)." | Non-frame budgets table: LS transition ≤570 ms p90 Iris Xe. Budget stands unchanged. |
| `design/gdd/audio.md` | TR-AUD-007: "Spatial SFX pool: 16 pre-allocated AudioStreamPlayer3D nodes, oldest-non-critical steal on overflow; no runtime allocation." | Slot #6 (Audio dispatch 0.3 ms) covers AudioServer mix + pool + subscriber handlers. Pool size is the existing contract; frame-time allocation is new here. |
| `design/gdd/player-character.md` | TR-PC-002: "Physics at 60 Hz via _physics_process; movement via velocity + move_and_slide(); Jolt physics engine." | Player move_and_slide cost absorbed into Slot #5 (Player/FC/Combat non-GF 0.3 ms); Jolt physics step (the engine side of move_and_slide) allocated to Slot #4 (0.5 ms). |
| `design/gdd/signal-bus.md` | Section C Rule 6: "Per-frame-per-multiple-entities events require GDD-level performance notes." | Signal Bus dispatch cost is absorbed into emitter slots (SAI signals within guard-systems, player signals within Player/FC/Combat). Residual dispatch overhead falls to Slot #8 (pooled residual 0.8 ms). No standalone Signal Bus slot because the bus itself owns no state. |

## Performance Implications

This ADR's own runtime cost is **zero** — it introduces no runtime instrumentation, no BudgetRegistry autoload, no per-frame polling. All enforcement is CI-time against the reference scene.

- **CPU**: None at runtime. At CI time, `/perf-profile` capture runs a 30-second scripted scene on headless Godot (~30 seconds of CI job time per run).
- **Memory**: None at runtime. Reference scene `.tscn` file ~KB-class.
- **Load Time**: None at runtime. Reference scene only loaded in CI.
- **Network**: N/A — single-player game.

## Migration Plan

1. **Write this ADR** (Status: Proposed) — done at file creation.
2. **Close upstream GDD flags in the same PR**:
   - `design/gdd/combat-damage.md` L233: replace "Cross-system budget reconciliation is flagged for the pending performance-budget ADR..." with "Cross-system budget reconciliation landed in ADR-0008 Slot #2 (6.5 ms combined guard-systems envelope covering SAI 6.0 + GuardFireController 0.5 P95)."
   - `design/gdd/stealth-ai.md` L684: mark Recommended Follow-up #5 as CLOSED by ADR-0008.
3. **Register 9 performance budget slots** in `docs/registry/architecture.yaml` under `performance_budgets:` (see Step 6 of `/architecture-decision` flow — user approval required separately).
4. **Add reference scene** at `tests/reference_scenes/restaurant_dense_interior.tscn` — scoped to a separate tooling story (prototyper or qa-lead), not this ADR's write.
5. **Configure CI `perf-gate` job** — scoped to a separate devops story; this ADR defines the contract, not the pipeline.
6. **Per-story embedding**: as each ticking-system story is authored, its Acceptance Criteria cites its ADR-0008 slot (owner: `/create-stories` skill at story authoring time).
7. **Amendment trigger**: any ADR or GDD that wants to change a slot cap opens an ADR-0008 amendment PR with a re-allocation pass across the other 8 slots to keep the sum at 16.6 ms.

## Validation Criteria

This ADR moves from Proposed → Accepted when **all four gates** pass. Gates are scoped to the perf-profile skill + manual measurement evidence.

### Gate 1 — Reference scene measurement (Iris Xe)

- **Scope**: Run `/perf-profile` on `tests/reference_scenes/restaurant_dense_interior.tscn` on an Iris Xe Gen 12 machine (devops-engineer owned CI runner or manual measurement on representative hardware).
- **Pass criterion**: Total frame time p99 ≤ 16.6 ms over a 30-second capture AND each slot stays within its Iris Xe cap at p95.
- **Evidence**: `production/qa/evidence/adr-0008-gate-1-iris-xe-[YYYY-MM-DD].md` with: CPU model, GPU model, OS + graphics driver version, physics backend (Jolt), graphics API (Vulkan — project decision A2), per-slot histogram with p50/p95/p99/max, total frame-time histogram, reference scene commit hash.

### Gate 2 — Reference scene measurement (RTX 2060, informative)

- **Scope**: Same as Gate 1 on RTX 2060 hardware at 1080p native.
- **Pass criterion**: Total frame time p99 ≤ 10 ms (~6.6 ms of headroom is informative target, not a cap). No slot exceeds its Iris Xe cap (RTX 2060 must be universally below Iris Xe numbers).
- **Evidence**: `production/qa/evidence/adr-0008-gate-2-rtx-2060-[YYYY-MM-DD].md` same format.

### ~~Gate 3 — D3D12 post-stream warm-up verification (Windows)~~

**CLOSED BY REMOVAL 2026-04-30 Amendment A2** — D3D12 is no longer a target backend per project decision (`project.godot [rendering] rendering_device/driver.windows="vulkan"` + ADR-0001 Amendment A2). The post-stream warm-up window was D3D12-specific; on Vulkan there is no analogous descriptor-heap stall behavior. The 1.6 ms reserve absorbs Vulkan's post-stream behavior adequately. CI perf-gate no longer needs section-transition skip-frames logic.

### Gate 4 — Autoload boot cold-start (both platforms)

- **Scope**: Cold-launch the game on Iris Xe Gen 12 (Linux Vulkan) and on representative Windows hardware running Vulkan (per project Amendment A2 — D3D12 not targeted). Measure wall-clock time from process start to `_ready()` completion on the last autoload (PostProcessStack).
- **Pass criterion**: ≤50 ms on both platforms. Shader Baker first-run time is measured separately (0–500 ms one-time) and not counted against this gate.
- **Evidence**: `production/qa/evidence/adr-0008-gate-4-autoload-boot-[YYYY-MM-DD].md` with per-autoload timing breakdown.

Failure of any gate returns the ADR to Proposed with a revision pass: re-allocate slots against measurements, re-run gates.

## Related Decisions

- **ADR-0001** (`docs/architecture/adr-0001-stencil-id-contract.md`) — outline pipeline budget 2.0 ms is a fixed input to Slot #3.
- **ADR-0002** (`docs/architecture/adr-0002-signal-bus-event-taxonomy.md`) — Signal Bus dispatch cost absorbed into emitter slots (no standalone line); Section C Rule 6 per-frame-per-entity obligation fulfilled here.
- **ADR-0003** (`docs/architecture/adr-0003-save-format-contract.md`) — save ≤10 ms / load ≤2 ms non-frame budgets stand unchanged.
- **ADR-0005** (`docs/architecture/adr-0005-fps-hands-outline-rendering.md`) — FPS hands SubViewport rendering absorbed into Slot #1 (Rendering) alongside main-viewport opaque pass. Gate 5 (Shader Baker × `material_overlay`) remains relevant for cold-boot pre-compilation; the prior cross-reference to D3D12 post-stream warm-up is moot per Amendment A2 (D3D12 not targeted).
- **ADR-0007** (`docs/architecture/adr-0007-autoload-load-order-registry.md`) — autoload cascade ≤50 ms cold-start budget defined in non-frame budgets table; PostProcessStack identified as dominant contributor.
- `design/gdd/stealth-ai.md` — TR-SAI-018 (6.0 ms) absorbed into Slot #2; Recommended Follow-up #5 closed by this ADR.
- `design/gdd/combat-damage.md` — L233 GuardFireController 0.5 ms P95 absorbed into Slot #2; cross-system reconciliation flag closed by this ADR.
- `design/gdd/outline-pipeline.md`, `design/gdd/post-process-stack.md`, `design/gdd/save-load.md`, `design/gdd/level-streaming.md`, `design/gdd/audio.md`, `design/gdd/player-character.md`, `design/gdd/signal-bus.md` — each system's per-frame claim is mapped to a slot in the GDD Requirements Addressed table.
- `technical-preferences.md` — 60 fps / 16.6 ms / 1500 draw call / 4 GB memory ceiling is the source contract.
- `architecture-review-2026-04-23.md` — Gap 2 closes with this ADR Accepted.

## Revision History

| Date | Change | Author / Rationale |
|------|--------|--------------------|
| 2026-04-23 | Initial draft — Proposed. All 9 frame slots allocated; non-frame budgets consolidated from ADR-0003, TR-LS-011, outline-pipeline.md §BAKING, ADR-0007. Engine specialist validation (godot-specialist, 2026-04-23) returned YELLOW with 3 prose constraints folded in: (a) shadow cascade count = 1 named as explicit Constraint + Risk row; (b) PostProcessStack cold-boot dominance documented in non-frame budgets table + Risk row; (c) D3D12 post-stream warm-up 3-frame allowance added to non-frame budgets table + Validation Gate 3. TD-ADR step 4.6 skipped (solo mode per `production/review-mode.txt`). Upstream GDD flag closures: `combat-damage.md` L233 + `stealth-ai.md` L684 updated in same PR. | Authored via `/architecture-decision performance-budget-distribution`. |
| 2026-04-28 | Amendment per `/review-all-gdds` 2026-04-28: (1) Slot-8 panic-onset reserve carve-out registered in §Risks — up to 0.6 ms of the 1.6 ms global reserve pre-allocated to absorb single-frame Slot-8 spikes when `civilian_panicked` emission count ≥ 4 within a single physics frame; producer + TD sign-off required to invoke per `civilian-ai.md` §C.0. (2) Autoload-cascade row 7 → 10 to reflect ADR-0007's current canonical table (Events / EventLogger / SaveLoad / InputContext / LevelStreamingService / PostProcessStack / Combat / FailureRespawn / MissionLevelScripting / SettingsService); 50 ms cold-start cap unchanged. (3) Sub-claims of Slot 8 explicitly enumerated in §Negative (CAI 0.30 + MLS 0.1 + DC 0.05 ≈ 0.45 ms steady-state) — informative, not contractual. (4) §ADR Dependencies row updated to "10 autoloads". | `/review-all-gdds` 2026-04-28 finding 2e.1 + 2c.2 — closes the Slot-8 panic-onset BLOCKING and the ADR-0008-says-7-but-ADR-0007-now-10 stale reference. |
| 2026-04-28 night | Amendment per Dialogue & Subtitles Phase 2 sibling-doc propagation cycle: (1) D&S Slot 8 sub-claim **0.10 ms peak event-frame** registered in §Negative — alongside CAI / MLS / DC / F&R / Signal-Bus dispatch (D&S was previously enumerated as "unspecified"). v0.3 of `dialogue-subtitles.md` corrected the prior Slot 7 misattribution: D&S is logic-tier dispatch + audio orchestration with no per-frame UI render component (Slot 7 = HUD Core / HSS / Document Overlay / Menu's UI render slot, not D&S). (2) Steady-state pool sum updated 0.45 ms → **0.55 ms** (within 0.8 ms cap with 0.25 ms residual margin); panic-onset spike scenario unchanged (governed by the existing Slot-8 reserve carve-out in §Risks). (3) D&S's three-way priority-resolver eviction may momentarily burst to ~0.13 ms — documented as an acceptable non-recurring exceedance, not a steady-state violation. (4) D&S sub-claim is provisional pending tools-programmer profiler measurement per AC-DS-9.1 ADVISORY (lead sign-off, not CI gate). | D&S Phase 2 propagation per `dialogue-subtitles.md` §F.6 P6 + OQ-DS-2 — closes the BLOCKING sub-claim registration coord item. |
| 2026-04-30 | **Amendment A2 — D3D12 removal**: project-level decision to force Vulkan on Windows (`project.godot [rendering] rendering_device/driver.windows="vulkan"`) per ADR-0001 Amendment A2 cascades into this ADR. Effects: (1) §Knowledge Risk simplified to Vulkan-only baseline; (2) §Post-Cutoff APIs Used drops the D3D12 row; (3) §Verification Required (c) closed by removal; (4) §Constraints Godot 4.6 defaults updated to "Vulkan on both platforms"; (5) §Reserve rationale tightens — drops "D3D12 heap pressure" reason (1.6 ms magnitude unchanged, justification holds for OS jitter + Jolt + AudioServer + unknowns); (6) §Non-Frame Budgets Post-stream warm-up window row removed (D3D12-specific); (7) Autoload-boot row drops "+5–10 ms D3D12 additional" qualifier; (8) ASCII diagram updated; (9) §Negative consequence about D3D12 post-stream allowance removed; (10) §Risks "PostProcessStack cold-boot" probability MEDIUM→LOW; (11) §Risks "D3D12 descriptor heap stall mid-session" CLOSED BY REMOVAL; (12) §Validation Gate 3 (D3D12 post-stream warm-up verification) CLOSED BY REMOVAL; (13) §Validation Gate 4 platform list updated (Windows Vulkan, not Windows D3D12); (14) §Related cross-ref to ADR-0005 Gate 5 reframed (Shader Baker still relevant for cold-boot, post-stream warm-up reference moot). Architectural decision unchanged; budget envelope unchanged in absolute terms; rationale tightened to Vulkan-only. Status stays Proposed (Gates 1, 2, 4 still need Iris Xe + Windows-Vulkan measurement). | Cascade from `architecture-review-2026-04-30.md` Vulkan-only sweep. |

## Last Verified

2026-04-28 night (D&S Phase 2 propagation amendment — D&S Slot 8 sub-claim 0.10 ms peak event-frame registered. Steady-state pool sum 0.45 → 0.55 ms within 0.8 ms cap. Architectural decision unchanged; budget envelope unchanged. Prior: 2026-04-28 (`/review-all-gdds` amendment — Slot-8 panic-onset reserve carve-out + autoload-cascade row 7 → 10. Architectural decision unchanged; budget envelope unchanged; reserve allocation policy made explicit). Earliest: 2026-04-23 (initial draft; specialist validation folded in; all four validation gates pending execution to promote Proposed → Accepted)).
