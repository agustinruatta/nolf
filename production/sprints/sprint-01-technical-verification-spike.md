# Sprint 01 — Technical Verification Spike

| Field | Value |
|-------|-------|
| **Sprint Number** | 01 |
| **Sprint Type** | Verification Spike (Pre-Production) |
| **Status** | In Progress |
| **Start Date** | 2026-04-29 |
| **Target End Date** | TBD — gated on user availability for Godot editor checks |
| **Stage Context** | Pre-Production (per `production/stage.txt`) |

## Goal

Close all open verification gates on ADR-0001 through ADR-0008 so they can advance from `Proposed` → `Accepted` status. This unblocks the downstream chain of artifacts that depend on Accepted ADRs:

1. `/create-control-manifest` (currently blocked — all 8 ADRs are Proposed)
2. `/create-epics` and `/create-stories` (blocked — would auto-block on Proposed ADR references)
3. First Production sprint (blocked — needs the manifest + epics)

Secondary goal: satisfy three Pre-Production → Production gate-check blockers in the process — `prototypes/` directory (item 1), first sprint plan (item 2), and the first prototype itself (items 1 + 10).

## Source Documents

- Gate-check verdict: this session, 2026-04-29 (verdict: FAIL — all 8 ADRs Proposed)
- ADR-0001 through ADR-0008 in `docs/architecture/`
- `docs/engine-reference/godot/VERSION.md` (Godot 4.6, post-cutoff knowledge risk HIGH)
- `.claude/docs/technical-preferences.md` (Forward+, Jolt 3D, GDScript)

## Scope

This is a verification spike, NOT a feature build. Code written here exists solely to close verification gates — it is intentionally minimal. Production-grade implementation of these systems happens in subsequent sprints under the normal epic/story flow.

## Work Groups

### Group 1 — Foundation scaffolding (autonomous, paper verification)

| ID | Deliverable | Closes ADR Gate(s) | Status |
|----|-------------|--------------------|--------|
| 1.1 | `src/core/physics_layers.gd` — 5 named constants + masks + composites | ADR-0006 G1 | ✅ Done (2026-04-29) |
| 1.2 | `project.godot` named 3D physics layer slots 1–5 | ADR-0006 G2 | ✅ Done (2026-04-29) |
| 1.3 | `src/core/signal_bus/events.gd` — Signal Bus autoload skeleton | ADR-0002 (skeleton) | ✅ Done (2026-04-29) |
| 1.4 | `project.godot` `[autoload]` block per ADR-0007 §Key Interfaces (10 entries) | ADR-0007 G(a) | ✅ Done (2026-04-29) |

Group 1 acceptance: files exist with correct content; `project.godot` parses cleanly when opened in Godot 4.6 editor.

### Group 2 — Editor-runnable verification scripts (user runs in Godot 4.6)

| ID | Deliverable | Closes ADR Gate(s) | Status |
|----|-------------|--------------------|--------|
| 2.1 | `prototypes/verification-spike/save_format_check.gd` — `ResourceSaver.save(...FLAG_COMPRESS)` round-trip + `DirAccess.rename` atomic + `Resource.duplicate_deep()` isolation | ADR-0003 G1 + G2 + G3 | ✅ Done (2026-04-29) — 2 findings, ADR amendment proposed |
| 2.2 | `prototypes/verification-spike/ui_framework_check.gd` — verify `accessibility_description`, `accessibility_role` settability, `ui_cancel` action grammar (KB/M + gamepad). G5 (BBCode→AccessKit) DEFERRED — needs runtime AT. | ADR-0004 G1 + G3 (✅); G5 DEFERRED | ✅ Done (2026-04-29) — F3 finding fixed in project.godot + ADR IG 14 |
| 2.3 | First gameplay file migrated to `PhysicsLayers.*` constants — end-to-end usage check | ADR-0006 G3 | ✅ Done (2026-04-29) — all 6 checks PASS |
| 2.4 | `prototypes/verification-spike/signal_bus_smoke.tscn` — emit→EventLogger→subscriber signal pipeline test | ADR-0002 G1 (incidentally closes ADR-0007 G(b)) | ✅ Done (2026-04-29) — all 4 checks PASS |

Group 2 acceptance: each verification script returns the expected output; results logged in `verification-log.md`.

### Group 3 — Visual verification prototypes (user views in Godot 4.6 editor)

| ID | Deliverable | Closes ADR Gate(s) | Status |
|----|-------------|--------------------|--------|
| 3.1 | `stencil_outline_demo.tscn` — uses native Godot 4.6 `stencil_mode = Outline` API (Finding F4 — see verification-log). 5 cubes covering 3 active tiers + no-outline control + distance test. Loads cleanly headless. | ADR-0001 G1 (closed via Finding F4 path); ADR-0001 design itself pending user visual verification | Code ✅ written 2026-04-29; visual verify pending |
| 3.2 | `fps_hands_demo.tscn` + `inverted_hull_outline.gdshader` — 3 capsules: inverted-hull outline / no outline / native stencil tier-HEAVIEST. Single-viewport (SubViewport integration deferred to FPS Hands production story). Loads cleanly headless. | ADR-0005 G1 | Code ✅ written 2026-04-29; visual verify pending |
| 3.3 | Cross-platform Vulkan + D3D12 spot-check on prototypes 3.1 + 3.2 | ADR-0001 G2, ADR-0005 G2 | Pending |
| 3.4 | Profile outline pass on integrated graphics @ 1080p + 75% scale | ADR-0001 G3 | Pending |
| 3.5 | Shader Baker compatibility check on `CompositorEffect` shaders | ADR-0001 G4 | Pending |

Group 3 acceptance: visual outputs match the prototype expectations documented in each ADR; user signs off on visual verification per prototype.

### Group 4 — Wrap-up

| ID | Deliverable | Status |
|----|-------------|--------|
| 4.1 | `prototypes/verification-spike/verification-log.md` populated with per-ADR-per-gate evidence | ✅ Active (running log; populated as gates close) |
| 4.2 | ADR status edits — `Status:` and `Last Verified:` updated to `Accepted` once all gates close | ✅ 4 of 8 done (ADR-0002, 0003, 0006, 0007); 4 still Proposed (0001, 0004, 0005, 0008) |
| 4.3 | Re-run `/architecture-review` (sanity check on Accepted ADR set) | Pending — defer until rendering ADRs Accepted |
| 4.4 | Re-run `/create-control-manifest` (resumes the original chain) | ✅ Done (2026-04-29) — PARTIAL manifest (Foundation + Core) at `docs/architecture/control-manifest.md`; regenerate when rendering ADRs Accept |
| 4.5 | Re-run `/gate-check` Pre-Production → Production | Pending — would still FAIL (no VS, no playtests, half of ADRs Proposed); re-run after VS sprint completes |

## Acceptance Criteria

- AC-01: All 8 ADRs (0001–0008) reach `Status: Accepted` with a stamped `Last Verified: 2026-MM-DD` date.
- AC-02: `prototypes/verification-spike/` exists with a README, verification log, and ≥4 prototype scenes/scripts.
- AC-03: `src/core/physics_layers.gd` exists, parses, and is referenced from at least one consumer (Group 2.3).
- AC-04: `src/core/signal_bus/events.gd` exists, parses, and successfully fires ≥1 signal that EventLogger receives in the smoke test (Group 2.4).
- AC-05: `project.godot` exists with the `[autoload]` block matching ADR-0007 §Key Interfaces verbatim (10 entries, `*res://` prefix on every entry) and `[layer_names]/3d_physics/layer_1..5` populated per ADR-0006.
- AC-06: Verification log preserves evidence (output snippets, screenshots references, dates, who verified) for every gate.
- AC-07: Any ADR that fails verification is amended with a Risks-table entry documenting the failure and either a workaround or a Superseded marker pointing to the replacement ADR.

## Out of Scope

- Production-grade implementation of any system listed above (Combat, MLS, F&R, SettingsService, LSS, etc.) — those land in their own sprints under the epic/story flow.
- Full taxonomy of the Signal Bus (ADR-0002 declares 30+ signals; the skeleton declares only enough to verify the pipeline).
- Visual fidelity tuning of the outline shader — verification only checks "the pipeline works on both backends," not "the outline looks right per the Art Bible."
- UI screen implementation — UI framework verification only confirms API names; actual UMG screens are post-spike.

## Dependencies

- Godot 4.6 installed locally (user confirmed).
- Linux Vulkan rendering available (default on user's Arch Linux).
- Windows D3D12 access required for prototype 3.3 (user-side; may be deferred or use a dual-boot / VM).
- Intel Iris Xe-class hardware required for prototype 3.4 (user-side).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Godot 4.6 stencil API differs from ADR-0001's assumption (e.g., `BaseMaterial3D` does not expose stencil write property) | MEDIUM | HIGH | If gate fails, ADR-0001 is amended to mandate `ShaderMaterial`-only path; prototype rebuilds. Outcome documented in verification log. |
| `accessibility_*` properties have different names than ADR-0004 assumes | MEDIUM | MEDIUM | ADR-0004 already flags Gate 1 as BLOCKING. If property names differ, ADR-0004 is amended; UI specs that cite the old names get a paired sweep. |
| Cross-platform parity fails (Vulkan ≠ D3D12 outline behavior) | LOW | HIGH | If detected, ADR-0001 is amended with a per-backend code path. Worst case: drop D3D12 from MVP scope (Linux-only Steam target preserves the period authenticity pillar). |
| User unavailable for visual verification (Group 3) for extended period | MEDIUM | LOW | Group 1 + Group 2 paper-verification gates close independently of Group 3. ADR-0001 + ADR-0005 may remain Proposed longer than the others, but Foundation-layer ADRs (0002/0003/0006/0007) can be promoted to Accepted on Group 1 + 2 alone. Control manifest can be partially populated against Foundation-layer Accepted ADRs while rendering ADRs catch up. |
| Engine version surprises requiring substantial ADR rewrites (not just amendments) | LOW | HIGH | A failed gate triggers the Superseded → new-ADR workflow. Sprint is paused until the replacement ADR is drafted and re-verified. |

## Cadence

- Group 1 (autonomous): single session.
- Group 2 (write + user runs): writes in 1 session; user runs at own pace.
- Group 3 (write + user views): writes in 1–2 sessions; visual verification likely spans multiple sessions.
- Group 4 (wrap-up): single session after all Groups complete.

Estimated total: 1–2 weeks calendar time depending on user availability for editor checks.

## Status Tracker

Updated after each work item closes. Source of truth for sprint progress.

```text
Group 1 (4 items):  ☑☑☑☑
Group 2 (4 items):  ☑☑☑☑
Group 3 (5 items):  ⌛✅☐☐☐  (3.1 partial: G1 closed, G2/3/4 need CompositorEffect; 3.2 verified)
Group 4 (5 items):  ☑☑☐☑☐  (4.1 + 4.2 + 4.4 done; 4.3 + 4.5 deferred to post-VS)
```

ADR Promotion Checklist (8 ADRs):

```text
ADR-0001 Stencil ID Contract:               Proposed (G1 ✅ closed via probe + demo; native API confirmed world-space — does NOT supersede ADR-0001; G2/G3/G4 need CompositorEffect prototype = post-spike spike)
ADR-0002 Signal Bus Event Taxonomy:         ✅ ACCEPTED (2026-04-29) — Group 2.4 smoke test PASS
ADR-0003 Save Format Contract:              ✅ ACCEPTED (2026-04-29) — Amendment A5 lands F1+F2; 3/3 gates passed
ADR-0004 UI Framework:                      Proposed (G1+G2+G3+G4 ✅; G5 BBCode→AccessKit DEFERRED to runtime AT testing; F3 amended into IG 14 + project.godot)
ADR-0005 FPS Hands Outline Rendering:       G1 ✅ PASS (2026-04-29 visual verify); G2 (cross-platform Vulkan + D3D12 parity) still pending Windows access; remains Proposed pending G2
ADR-0006 Collision Layer Contract:          ✅ ACCEPTED (2026-04-29) — all 3 gates PASS
ADR-0007 Autoload Load Order Registry:      ✅ ACCEPTED (2026-04-29) — G(a) + G(b) PASS
ADR-0008 Performance Budget Distribution:   Proposed (composite — depends on the rendering ADRs)
```

## Related

- Gate-check verdict (this session): triggered this spike.
- `prototypes/verification-spike/verification-log.md` — running evidence trail.
- `docs/architecture/architecture.md` — master architecture (no changes expected from this spike unless an ADR is rewritten).
- `docs/engine-reference/godot/VERSION.md` — referenced for every gate.
- Future: `docs/architecture/control-manifest.md` — resumes after AC-01 closes.
