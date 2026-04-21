# Player Character GDD — Session F Re-Draft Scope Brief

> **Purpose**: One-session re-draft of `design/gdd/player-character.md` per creative-director recommendation (2026-04-20, `/design-review` 3rd re-review, verdict MAJOR REVISION NEEDED).
> **Baseline**: Freeze at `design/gdd/player-character-v0.3-frozen.md` (973 lines, 2026-04-20).
> **Budget**: One focused session, ~4–6 hours. NOT a surgical iteration — a structural re-anchor.
> **Working doc**: `design/gdd/player-character.md` (re-drafted in place, working copy overwritten).

---

## 1. Why Re-Draft (not patch)

The 3rd re-review surfaced ~20 blockers across 6 specialists that patch-review cycles could not catch:
- **Pillar violations from inside the tuning envelope**: `jump_velocity` safe-range max produces a 1.28 m apex (clears desk height, violates Pillar 5 no-parkour). Sprint's 57%/80% speed-to-noise ratio produces the opposite of Deadpan Witness.
- **Engine-reality drift**: `CapsuleShape3D.height` in Godot 4.6 does NOT include hemispherical caps — every spatial spec in the GDD is off by 0.6 m.
- **Composed formula bugs**: flat-ground jump at safe-range extremes triggers hard landing; F.5 silent priority inversion when cap exceeded.
- **Complexity compounding**: 21 deferred Session E recommendeds + 20 new blockers + 23 new recommendeds. Revision backlog growing faster than burn-down.

Creative-director quote: *"23 blockers × ~20 min each = 8 hours of patch work that still leaves the document at current complexity, still vulnerable to the next review surfacing a 24th class of issue."*

**The goal is not fewer bugs in a complex document. The goal is a simpler document that bugs cannot hide in.**

---

## 2. Design Test for Re-Draft Success

The re-draft is a success if:
- **(a)** Next `/design-review` surfaces ≤5 blockers.
- **(b)** GD-B3 is resolved by tuning that *makes Sneak/Crouch the dominant stealth strategy* in vertical mission sections (not just legal).
- **(c)** No specialist flags a pillar violation (Pillar 1 Comedy, Pillar 3 Stealth-is-Theatre, Pillar 5 Period Authenticity).
- **(d)** `CapsuleShape3D` dimensions verified against Godot 4.6 source-of-truth docs, not assumed.
- **(e)** Every AC names its measurement method (what to read, what threshold, what tool).

---

## 3. What to KEEP (verified surviving from v0.3-frozen)

- **Player Fantasy section** — Deadpan Witness, Emma Peel / Modesty Blaise / Cate Archer references. This is the strongest section of the v0.3 doc. Preserve near-verbatim.
- **7-state MovementState enum** (IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, DEAD) — still correct.
- **Core pillar framing** — this GDD serves Pillars 1, 3, 5. Preserved.
- **Signal taxonomy conformance** (`Events.player_damaged`, `player_died`, `player_health_changed`, `player_interacted`, `player_footstep`) per ADR-0002 — all correct.
- **ADR-0005 hands outline exception** — inverted-hull material_overlay. Preserve, but correct the compositing-order wording (godot-specialist finding #6).
- **ADR-0006 collision layer usage** — `PhysicsLayers.*` constants. Preserve verbatim.
- **OQ-1 closure** (no regen, diegetic medkits) — preserve, but add `apply_heal` stub to Interactions table (recommendation #42).

---

## 4. What to CUT or COLLAPSE

### Tuning Knobs — reduce from ~44 to ~15 pillar-serving

Keep only knobs that directly serve a pillar or are balance-critical:

| Keep | Cut or move | Rationale |
|---|---|---|
| `walk_speed`, `sprint_speed`, `crouch_speed` | — | Core feel, pillar-serving |
| `gravity`, `jump_velocity`, `hard_land_height` | — | Core feel, verify cross-knob constraints |
| 6 per-state noise radii (Walk 5, Sprint 9 *or 12 per GD-B3*, Crouch 3, Jump Takeoff 4, Landing Soft 5, Landing Hard 8) | — | Stealth AI consumes; MUST be explicit in Tuning Knobs table with Safe ranges |
| `max_health`, `interact_ray_length`, `interact_pre_reach_ms` | — | Pillar-serving: Deadpan Witness pause, NOLF1 interact |
| `camera_fov`, `turn_overshoot_deg` | — | Pillar 5 (period FOV), Deadpan Witness feel |
| — | Acceleration times (`walk_accel_time`, `walk_decel_time`, `sprint_accel_time`, `crouch_transition_time`) | Move to an "Advanced Feel" subsection or a separate `PlayerFeel.tres` resource with a single sentence in the main GDD pointing to it |
| — | `mouse_sensitivity_x`, `mouse_sensitivity_y`, `gamepad_look_sensitivity` | Move to Settings & Accessibility GDD (Input-derived); keep single reference sentence in Camera section |
| — | `raycast_max_iterations`, `interact_min_separation`, `interact_damage_cancel_threshold`, `interact_reach_duration_ms` | Correctness parameters — move to a Correctness Parameters sidebar (not mixed with feel knobs) |
| — | `kill_plane_y` | Correctness — move to Correctness Parameters sidebar |
| — | `pitch_clamp_deg`, `camera_y_standing`, `camera_y_crouched`, `turn_overshoot_return_ms` | Move to Correctness Parameters or fold into spec |
| — | `noise_global_multiplier`, `idle_velocity_threshold`, `spike_latch_duration_sec`, `coyote_time_frames` | Move to Correctness Parameters (not designer-tuning) |

**Goal**: Main Tuning Knobs table is ~15 rows of designer-facing knobs, each tied to a specific pillar or playtest verdict. All correctness parameters live in a separate sidebar or internal constants file.

### Acceptance Criteria — collapse 35+ to ~12 concrete, labeled

Keep only ACs that:
- Name the specific measurement (e.g., `player.velocity.length()` at frame 9).
- Provide a numeric threshold with tolerance.
- Are independently testable without developer consultation.
- Carry a story-type label (`[Logic]` / `[Integration]` / `[Visual/Feel]` / `[UI]`) and test-evidence path.

**Drop these categories entirely**:
- "Pillar compliance" ACs (AC-11.x) — replace with a single "Forbidden Patterns" code-review checklist referenced from Control Manifest.
- ACs that rephrase the spec without measuring anything (e.g., "Pressing E starts a 150 ms pause" — this IS the spec, not a test).
- ACs that assert internal implementation details (e.g., "idempotent-read" — replace with observable: "calling get_noise_event() N times in frame F returns same reference").

**Target AC count**: ~12, down from 35+. Each one gated by one measurement + one threshold + one test-evidence path.

### Edge Cases — keep structurally, rewrite three

- **E.1 Uncrouch blocked by low ceiling** — verify against corrected `CapsuleShape3D` math.
- **E.5 Stacked interactables** — needs `push_warning` when cap exceeded (systems-designer blocker #5).
- **E.6 Damage during interact** — resolve Tween vs AnimationPlayer (gameplay-programmer recommendation #7).

---

## 5. What to RESTRUCTURE

### Sibling doc: FootstepComponent

**Problem**: FootstepComponent currently owns both (a) `player_footstep` emission (Audio lane) AND (b) `get_noise_level()` scalar updates (AI lane). This creates a single failure point where an audio-cadence bug silently breaks AI perception.

**Solution**: Extract FootstepComponent into its own sibling doc: `design/gdd/footstep-component.md`. PC GDD references it but does NOT own the Audio/AI split.

**Split contract**:
- FootstepComponent emits `player_footstep(surface, noise_radius_m)` — Audio subscribes.
- PlayerCharacter itself owns `get_noise_level()` — reads its own `MovementState` + `velocity.length()` — does NOT depend on FootstepComponent.
- PC GDD's `get_noise_event()` latch is PC-internal; FootstepComponent does NOT touch it.

This resolves R-19 (game-designer promotion) and removes the child-component seam.

### Correction ticket: CapsuleShape3D geometry

**Problem**: `CapsuleShape3D.height` in Godot 4.6 does NOT include hemispherical caps. Total height = `height + 2 × radius`.

**Spec to replace** (v0.3-frozen line 53):
> Standing: 1.7 m height, 0.3 m radius. Crouched: 1.1 m height, 0.3 m radius.

**Corrected spec** (choose ONE and state it explicitly):
- **Option A (recommended)**: Keep 1.7 m / 1.1 m as **TOTAL body height** design intent. Set `CapsuleShape3D.height = 1.1 m` standing / `0.5 m` crouched at `radius = 0.3 m` — resulting total height matches intent. Camera Y = 1.6 m standing / 1.0 m crouched unchanged.
- **Option B**: Keep `CapsuleShape3D.height = 1.7 m` as the cylinder-only height and declare Eve's TOTAL collider = 2.3 m. Does NOT match Eve's 1.7 m body model — not recommended.

**Verify against**: `/home/agu/Projects/Claude-Code-Game-Studios/docs/engine-reference/godot/modules/physics.md` before committing.

### GD-B3 Sprint dominance resolution

**Required decision** (game-designer + creative-director alignment):

- **Option (a)** — document-only: add a "Sprint is interior-unsafe" constraint note for level designers. Cheap, honest, does NOT fix optimal-strategy problem.
- **Option (b)** — tuning: raise Sprint noise 9 m → 12 m. Makes Sprint costly even with guards on same floor. Game-designer's recommended resolution.
- **Option (c)** — accept Sprint-dominant, rewrite Player Fantasy. NOT recommended (sacrifices Pillar 3).

**Re-draft default**: Option (b). Commit unless user redirects.

### OQ-7 + OQ-8 — close before re-draft gates

- **OQ-7** (binary vs scaled hard-landing noise): game-designer recommends scaled formula `noise_radius = 8.0 × clamp(|v.y| / v_land_hard, 1.0, 2.0)`.
- **OQ-8** (air control): game-designer recommends Option A (no air control — Deadpan Witness does not steer in mid-air).

Both resolutions are in scope for Session F. If user contests, surface as an `AskUserQuestion` widget at the top of the re-draft session before any writing begins.

---

## 6. Blocking Items Mapped to Re-Draft Sections

Each of the ~20 blockers from the 2026-04-20 3rd re-review is assigned a destination in the re-draft:

| Blocker | Specialist | Destination in re-draft |
|---|---|---|
| CapsuleShape3D height wrong | godot-specialist | Core Rules → Physical body (new correction) |
| v.xz swizzle invalid | gameplay-programmer | F.1 rewrite with Vector2 intermediate |
| NoiseEvent circular parse dep | gameplay-programmer + godot-specialist | Move NoiseType to `player_enums.gd` + update F.4 + Interactions table |
| SubViewport compositing wording | godot-specialist | Visual/Hands rewrite (cite ADR-0005 depth isolation) |
| Flat-ground jump triggers hard landing | systems-designer | New cross-knob constraints table under Tuning Knobs Vertical |
| F.5 silent priority inversion | systems-designer | F.5 + E.5 — add push_warning on cap-exceeded |
| jump_velocity max → 1.28 m apex | systems-designer | Tuning Knobs Vertical — lower safe-range ceiling with apex constraint documented |
| jump_velocity min → 0.30 m apex | systems-designer | Tuning Knobs Vertical — cross-constraint note (apex ≥ 0.45 m) |
| Spurious player_damaged sub-0.5 | systems-designer | F.6 — add post-rounding guard |
| GD-B3 Sprint dominance | game-designer | Tuning Knobs Noise — apply Option (b) 9→12 m |
| OQ-7 hard-landing scaled | game-designer | Close in F.3 — apply scaled formula |
| OQ-8 air control | game-designer | Close in F.1 — Option A (no air control) |
| R-19 FootstepComponent split | game-designer + audio-director | Extract to sibling doc `footstep-component.md` |
| reset_for_respawn undefined | ai-programmer | New Core Rules section — reset contract (clears _latched_event, state→IDLE, is_hand_busy→false) |
| Noise event sequencing collapse | ai-programmer | F.4 — document as intentional loss OR add preceding_event_type |
| Latch tick-boundary risk | ai-programmer | F.4 + Dependencies risk note for Stealth AI |
| NoiseEvent retention footgun no AC | ai-programmer | New AC-5.x — unit test verifying post-next-spike retention reads subsequent data |
| Settings.get_resolution_scale undefined | gameplay-programmer | AC-10.1 — replace with Settings-agnostic observable (or gate pending Settings GDD authoring) |
| Camera rotation R-15 pattern | gameplay-programmer | Core Rules Camera — commit to body-yaw + camera-pitch (standard FPS pattern) |
| 10 AC measurement gaps | qa-lead | All ACs rewritten with measurement method + threshold + test-evidence path |

---

## 7. Recommended Items Mapped (~23 items)

All 23 recommendeds from the 3rd re-review, plus the 21 deferred Session E recommendeds, will either:
- **Resolve automatically** by the re-draft's structural changes (e.g., R-1 turn_overshoot is preserved as the single Camera feel knob; R-4/R-7/R-22/R-23 already resolved).
- **Fold into the re-draft** at the appropriate section.
- **Defer to post-re-draft** only if they describe implementation polish that survives the simpler doc unchanged.

Maintain the deferred-items tracking in `production/revision-notes/player-character-blockers.md` — archive that file as `player-character-blockers-pre-session-f.md` before re-draft begins.

---

## 8. ADR Implications

**Expected**: No new ADRs. No ADR amendments required (ADR-0002 pull-method contract, ADR-0005 inverted-hull, ADR-0006 collision layers all hold).

**Watch items**:
- If Settings.get_resolution_scale is pushed into a new Settings GDD, AC-10.1 must wait on that GDD's authoring — may require an ADR for the Settings autoload pattern.
- If FootstepComponent split reveals a cross-signal ordering constraint (Audio emission vs AI pull-method timing), it may warrant a note in ADR-0002's Implementation Guidelines.

---

## 9. Session F Execution Order

1. **Pre-session (5 min)**: Read this brief. Read `player-character-v0.3-frozen.md` for reference. Confirm `/clear` performed.
2. **Decision phase (15 min)**: Confirm GD-B3 → Option (b), OQ-7 → scaled, OQ-8 → Option A, CapsuleShape3D → Option A (1.1 m / 0.5 m cylinder heights). Use one `AskUserQuestion` multi-tab widget to gate all four.
3. **Structural phase (60 min)**: Rewrite in this order: Summary → Player Fantasy (preserve) → Core Rules (new collider + noise mapping) → F.1–F.6 (systems-designer + gameplay-programmer co-review) → Edge Cases (3 rewritten) → Tuning Knobs (collapsed to ~15) → Acceptance Criteria (collapsed to ~12) → Open Questions.
4. **Sibling-doc phase (45 min)**: Write `footstep-component.md` from scratch. Update PC GDD to reference it.
5. **Verification phase (30 min)**: Spawn godot-specialist to verify CapsuleShape3D math; spawn qa-lead to verify AC measurement methods; spawn game-designer to verify GD-B3/Pillar-3 alignment.
6. **Re-review (fresh session)**: User runs `/design-review design/gdd/player-character.md` in a new session. Target: APPROVED with ≤5 recommendeds.

**Total budget**: ~4 hours authoring + ~2 hours specialist verification = ~6 hours.

---

## 10. Non-Goals for Session F

- **NOT merging this re-draft with a Stealth AI or Combat & Damage GDD authoring pass**. Those remain gated until this re-draft is APPROVED.
- **NOT resolving Session E's 21 deferred recommendeds individually** — many auto-resolve; survivors fold into the simpler doc; genuine polish items may be re-deferred to post-approval.
- **NOT authoring a new ADR** unless the CapsuleShape3D correction or the FootstepComponent split reveals a cross-cutting pattern worth codifying.
- **NOT changing pillars** (Pillar 1 Comedy, Pillar 3 Stealth-is-Theatre, Pillar 5 Period Authenticity remain the anchor — the re-draft makes them more compliant, not revisit them).

---

## Appendix A: Specialist review summary (2026-04-20 3rd re-review)

See `design/gdd/reviews/player-character-review-log.md` — "Review — 2026-04-20 — Verdict: MAJOR REVISION NEEDED (3rd re-review)" entry.

## Appendix B: Frozen baseline

`design/gdd/player-character-v0.3-frozen.md` — do NOT edit. This is the reference document the re-draft measures against.
