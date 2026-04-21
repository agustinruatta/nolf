# Player Character GDD — Review Log

Revision history for `design/gdd/player-character.md`.

---

## Review — 2026-04-19 — Verdict: MAJOR REVISION NEEDED

- **Scope signal**: L
- **Specialists**: game-designer, systems-designer, qa-lead, gameplay-programmer, godot-specialist, ai-programmer, audio-director, creative-director
- **Blocking items**: 15 | **Recommended**: 25 | **Nice-to-Have**: 9
- **Full report**: `design/gdd/reviews/player-character-review-2026-04-19.md`
- **Working punch list**: `production/revision-notes/player-character-blockers.md`

**Summary**: Contract violations vs ADR-0002 (signal taxonomy, autoload naming) and vs Audio GDD (mix bus names) would fail at first integration. F.1 divides by zero at safe-range boundary; F.3 hard-landing threshold decouples silently from gravity tuning. Rendering pipeline conflict (hands-in-SubViewport loses ADR-0001 outline stencil) requires an ADR amendment. Hidden-stamina subsystem conflicts with Pillar 5 and needs an OQ opened — NOLF1 shipped without stamina and the addition is unjustified. Creative-director recommends splitting revision into 4 focused sessions (creative → architecture → contracts → specification); ~30% of fixes cascade from resolving the stamina question first.

**Prior verdict resolved**: First review — no prior verdict.

---

## Revision — 2026-04-19 — Session A (creative decision)

- Blocking resolved: B-14 (stamina cut entirely), R-4 (CrouchSprint cut), R-22 (idle breath loop added at −24 dB)
- Auto-resolved side effects: R-7 (sprint→walk exhaustion transition timing), R-23 (breathing stamina thresholds)
- GDD edits: 28 surgical edits — stamina system fully excised (F.4 deleted, AC-7 deleted, Tuning Knobs Stamina subsection deleted); F/E/AC renumbered to close the gaps. Rejected-features block added under Core Rules with Pillar 5 rationale.

## Revision — 2026-04-19 — Session B (architecture)

- Blocking resolved: B-10 (FPS hands outline pipeline — new ADR-0005), B-2 (ADR-0002 taxonomy amended with Player domain + 2 signals), B-6 (mix bus names reconciled to canonical SFX), R-18 (collision-layer constants — new ADR-0006)
- Bonus resolved: save-load.md `PlayerState` row stamina field removed (ADR-0003 itself required no amendment — PlayerState shape is not inlined there)
- Key mid-session finding: godot-shader-specialist memo revealed Option A (dual-camera shared framebuffer) for B-10 is not buildable in GDScript in Godot 4.6 → pivoted to inverted-hull shader approach. Decision documented in ADR-0005 Alternatives Considered.
- ADRs authored: ADR-0005 (FPS Hands Outline Rendering, Proposed, 4 gates), ADR-0006 (Collision Layer Contract, Proposed, 3 gates)
- ADRs amended: ADR-0002 (Revision History block; 32→34 signal count; new Player domain containing `player_interacted` + `player_footstep` with `noise_radius_m` parameter)
- GDDs edited: `design/gdd/player-character.md` (19 targeted edits), `design/gdd/save-load.md` (1 edit)

## Revision — 2026-04-19 — Session C (contract alignment)

- Blocking resolved: **B-1** (signal signatures conformed to ADR-0002: `player_damaged(amount: float, source: Node, is_critical: bool)`, `player_died(cause: CombatSystem.DeathCause)`, `player_health_changed(current: float, max_health: float)`), **B-3** (`SignalBus` autoload name replaced with `Events` across F.6 pseudocode and AC-9.1 — zero `SignalBus` residuals verified by grep), **B-4** (`apply_damage` rewritten to `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)` at all 9 call sites including AC-6.1–6.5 and E.12 kill-plane), **B-5** (`PlayerState.current_state: String` → `current_state: int` backed by new `PlayerCharacter.MovementState` inner enum `{IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, DEAD}`; save-load.md row also reconciled `health: float` → `int`)
- Recommended resolved: **R-9** (F.6 literal `100` replaced with `max_health` property read), **R-16** (mouse sensitivity ownership reconciled — Input GDD says sensitivity lives in PC GDD; PC GDD Camera paragraph corrected and three tuning knobs `mouse_sensitivity_x`, `mouse_sensitivity_y`, `gamepad_look_sensitivity` added with ownership note delineating Input raw capture vs PC transformation vs Settings runtime override)
- Load-bearing design decisions (settled before drafting): `is_critical = false` at MVP (Combat & Damage GDD will define crit rules later without touching PC interface); `DeathCause` is sourced from the killing blow's `damage_type` via the pure helper `CombatSystem.damage_type_to_death_cause` (owned by Combat & Damage GDD per ADR-0002 Implementation Guideline 2); `MovementState` enum is an inner enum on `PlayerCharacter` (not on `Events.gd`, not on a shared `Types.gd`)
- GDDs edited: `design/gdd/player-character.md` (19 targeted edits across Summary, Core Rules Health + Camera, State enum declaration, Interactions table × 3 rows, F.6 full rewrite, E.12 kill-plane, Dependencies × 2 rows + risk note, UI Requirements signals table, Tuning Knobs Camera subsection, Cross-References, AC-6.1–6.5, AC-8.1, AC-9.1), `design/gdd/save-load.md` (1 edit: PlayerState row health + current_state types aligned)
- No new ADRs required — all 6 items are GDD edits against already-fixed ADR contracts (Sessions A and B set those contracts)
- Contracts now aligned: Every `player_*` signal emission, every `apply_damage` reference, every `PlayerState` schema citation, and every `Events` autoload reference in this GDD now matches ADR-0002 and ADR-0003 verbatim.

**Pending**: Session D only (specification / math / AI contracts — 6 blocking + ~22 recommended). Re-run `/design-review` in a fresh session after D completes.

## Revision — 2026-04-20 — Session D (specification / math / AI contracts — blockers only)

- **Blocking resolved (7/7)**:
  - **B-7** F.1 NaN guards: `max(accel_time, 0.001)` / `max(decel_time, 0.001)` with `@export_range` pinned to the **design envelope** (walk_accel 0.08–0.18, walk_decel 0.12–0.25, sprint_accel 0.10–0.22). Rationale: `@export_range` communicates designer intent while `max(..., 0.001)` handles NaN — different jobs. `crouch_transition_time` excluded (animation duration, not a rate divisor).
  - **B-8** Hard-landing threshold decoupling (Option A): `hard_land_threshold: 6.0 m/s` knob renamed to `hard_land_height: 1.5 m` knob (safe range 1.0–3.0 m). F.3 computes `v_land_hard = sqrt(2 × gravity × hard_land_height)` at runtime so gravity changes auto-rescale the noise trigger. Worked examples at g=9.8/12.0/15.0. Tuning Knobs Vertical subsection gained `gravity × hard_land_height interaction` note showing [4.43, 9.49] m/s across safe-range extremes.
  - **B-9** Δt clamp applied globally to F.1 AND F.2 (not F.1-only): `Δt_clamped = min(Δt, 1.0 / 30.0)`. Prevents hitches from fabricating false hard-landing noise spikes (stealth-gameplay false-positive where AI would "hear" physics artifacts). Preamble added before F.1; F.2 gravity line uses `Δt_clamped`; F.3 is a threshold comparison and needs no own clamp.
  - **B-11** F.5 Interact Raycast rewrite — **Option (a) iterative raycast with exclusion list** (cap 4, range 2–6 via new `raycast_max_iterations` knob). Rejected (b) `intersect_shape` thin-capsule (over-captures off-axis — breaks priority semantics) and (c) single-hit redesign (would leave stacking to level-design promise). F.5 pseudocode replaced with Godot-4.6-idiomatic GDScript using `PhysicsRayQueryParameters3D.create()` + `space_state.intersect_ray()` looped with `query.exclude.append(hit.rid)`. Priority delegated to `get_interact_priority()` method on each interactable (duck-typed, testable). Bonus: Core Rules rule 5 tightened so the continuous HUD-highlight raycast uses the same `_resolve_interact_target()` — outlined object always matches E-press target.
  - **B-12** Noise interface richness — **Option B** (scalar + companion). `get_noise_level() -> float` retained (hot path, 80 Hz aggregate); `get_noise_event() -> NoiseEvent` added (returns and clears latched event). `NoiseEvent` is a lightweight `class_name` in its own file `res://src/gameplay/player/noise_event.gd` — NOT `Resource` (ref-count overhead). `NoiseType` inner enum on `PlayerCharacter` with 6 values: `FOOTSTEP_SOFT / FOOTSTEP_NORMAL / FOOTSTEP_LOUD / JUMP_TAKEOFF / LANDING_SOFT / LANDING_HARD`. Walk/Sprint/Crouch separately typed so Stealth AI can type-switch on suspicion-increment rate, not just scalar radius. No ADR-0002 amendment — pull-method implementation detail, not a signal.
  - **B-13** Spike frame-alignment fix — **latched NoiseEvent consumed on next poll** (not the fixed-duration option). Rules: immediate-on-transition recording; highest-radius-wins stacking collapse; auto-expiry after `spike_latch_duration_frames` (new knob, default 6 physics frames = one AI tick window at 10 Hz, safe range 6–12). Zero steady-state allocation (single reused instance). Removed the old "1-in-6 miss probability" rationale from F.4 — it was non-deterministic and untestable.
  - **B-15** E.5 stacking rewrite — replaced "Level designers must not stack..." prose with **both** a code-guarantee (F.5's priority resolution) **and** a level-design QA rule (`interact_min_separation = 0.15 m` new knob, safe range 0.0–0.5 m). Rule is not runtime-enforced — it's a content-review checkpoint designed to keep stacked-interactable counts below `raycast_max_iterations` in practice.
- **Opportunistic recommended resolved (R-5)**: F.1 scope-gating note added ("Runs only in ground states; Jump/Fall preserve ground-frame momentum; air control not yet specified — see OQ-8"). One-line comment cost during the B-7/B-9 edit.
- **Bonus delineation (B-12 cascade)**: `player_footstep` signal explicitly marked Audio-only. "Stealth AI MUST NOT subscribe to `player_footstep`" now appears in three places: Interactions table Audio row, Cross-References Downstream Stealth AI row, and the bidirectional dependency statement. Enforces single-perception-path rule at code review.
- **Registry reconciliation (5 entries, `design/registry/entities.yaml`)**:
  - `player_hard_land_threshold` renamed to `player_hard_land_height` (value 6.0 m/s → 1.5 m; unit m/s → m; formula-derived threshold documented in notes per B-8)
  - `player_noise_hard_landing` notes updated (latched-event model, drops "1 frame" claim)
  - `player_noise_jump_takeoff` notes updated (latched-event model, drops "1 frame" claim)
  - `player_noise_landing_soft` — NEW entry (5.0 m, registered explicitly per B-13 for cross-GDD consumption)
  - `player_noise_crouch_sprint` — status `active → deprecated` (orphan cleanup from Session A R-4; CrouchSprint state was cut; entry retained for audit trail only)
- **Open Questions opened**: OQ-7 (hard-landing noise severity: binary vs scaled — deferred to Stealth AI GDD noise-perception design) · OQ-8 (air control specification: None / Partial / Full — deferred to level-design review)
- **Specialist consultations**: systems-designer (B-7/B-8/B-9/R-5 cluster), gameplay-programmer (B-11/B-15 cluster, Godot 4.6 + Jolt performance analysis), ai-programmer (B-12/B-13 cluster, architecture recommendation + ADR-0002 compliance check)
- **Load-bearing design decisions (settled before drafting)**:
  - B-7 `@export_range` uses design-envelope bounds (not safety-floor 0.001), because it's a designer-facing affordance; the NaN guard is separate
  - B-8 chose runtime-derived threshold over manual-recalc note because stealth gameplay consequences (8 m AI alert) make silent gravity-coupling bugs unacceptable
  - B-9 clamp applied globally to avoid F.2 hitches producing physics-fabricated hard-landing noise (subtler bug than F.1 overshoot alone)
  - B-11 iterative raycast over shape-sweep because shape sweeps over-capture radially, breaking priority semantics
  - B-12 companion-method pattern (not pure struct replacement) preserves `get_noise_level()` hot path and AC-5 contract continuity
  - B-13 latched event over duration-extension because latching is deterministic and testable; duration-extension is probabilistic
  - NoiseEvent as `class_name` in own file (not inner class on PlayerCharacter) — globally visible to Stealth AI without importing PlayerCharacter, zero per-call allocation via instance reuse
- No new ADRs required; no ADR amendments required (ADR-0002 pull-method contract absorbs the latched-event queue without modification)
- GDDs edited: `design/gdd/player-character.md` (~25 targeted edits across Formulas preamble, F.1/F.2/F.3/F.4/F.5 rewrites, Core Rules rule 5 + noise footprint + new NoiseType/NoiseEvent declarations, E.5, Interactions table × 2, Tuning Knobs Acceleration/Vertical/Interact/Noise, Cross-References Downstream Stealth AI row + bidirectional statement + risk note, AC-3.4, AC-5.1–5.6, +OQ-7, +OQ-8), `design/registry/entities.yaml` (5 entries)

**Pending**: Session E (21 recommended items deferred — see blockers file "Session E scope"). First run `/design-review design/gdd/player-character.md` in a fresh session — verdict informs Session E re-prioritisation.

---

## Review — 2026-04-20 — Verdict: NEEDS REVISION

- **Scope signal**: S (blocker-cleanup pass + 1 real design decision; ~4–6 hours focused work)
- **Specialists**: game-designer, systems-designer, qa-lead, gameplay-programmer, godot-specialist, ai-programmer, audio-director, creative-director
- **Blocking items**: 8 new | **Recommended**: ~18 | **Nice-to-Have**: ~7
- **Prior verdict resolved**: Yes — all 15 original blockers verified fixed in current GDD (Sessions A–D regression check passed). No regressions.
- **New findings summary**: (1) F.5 `INT_MAX` parse error; (2) F.1 `input_magnitude` undefined in variable table; (3) `noise_global_multiplier` orphaned — declared but never applied in F.4; (4) stale `> 6 m/s` literals on 3 lines where B-8 decoupled the threshold; (5) F.5 missing `.has_method()` guard on `get_interact_priority()`; (6) AC-10.1 `material_override` ambiguity clobbers multi-surface PBR; (7) Walk/Sprint/Crouch → Fall ledge-walk-off transition undefined in state machine; (8) **AI-1 — single-consumption latch breaks multi-guard parity** (Pillar 3 fidelity issue — creative-director flag).
- **Creative-director verdict**: *"The cost/impact curve has inverted: we are no longer fighting design ambiguity, we are fighting residue."* Pillars 1 (Deadpan Witness) and 5 (Period Authenticity) HELD. Pillar 3 (Stealth is Theatre) AT RISK on AI-1. Drift risk: contract metadata accretion slightly burying kinesthetic spec.

---

## Revision — 2026-04-20 — Session E-Prime (blocker-cleanup pass)

- **All 8 new blockers resolved** + 5 promoted recommendeds (R-8, R-10, R-11, R-12, R-17) + 1 nice-to-have (R-1 turn_overshoot default raise) + opportunistic new recommendeds from re-review (AI-R1, AI-R2, GDT-R6 runtime settings-change, AC preamble fix, NOISE_BY_STATE declaration).
- **Load-bearing design decisions** (user-confirmed before drafting):
  - **AI-1 latch semantics**: idempotent-read + auto-expiry (no clear-on-read). All guards polling within the latch window see the same `NoiseEvent`; caller contract documented for reference retention.
  - **R-10 Crouch-idle mechanism**: velocity threshold inside `get_noise_level()` (new `idle_velocity_threshold` knob, default 0.1 m/s). Keeps 7-state MovementState; avoids save-format migration. Applies to Walk-at-rest too.
  - **R-17 tick-rate independence**: rename `spike_latch_duration_frames` → `spike_latch_duration_sec` (default 0.1 s, range 0.1–0.2). Frame count computed at runtime via `Engine.physics_ticks_per_second`.
  - **R-1 turn_overshoot**: default raised 2.5° → 4.0° (safe range 2.5–4.5°). Playtest-validation AC deferred to Session E batch 2.
- **Key edits (player-character.md, ~15 targeted edits)**:
  - Variables table: added `input_magnitude`, `NOISE_BY_STATE` declarations (SD-1, AI-2)
  - Core Rules Vertical motion + Noise table: replaced 3 stale `> 6 m/s` literals with `> v_land_hard` references (SD-3)
  - Core Rules noise interface paragraph: idempotent-read semantic + auto-expiry sole-clear (AI-1)
  - F.4 full rewrite: idempotent-read `get_noise_event()`, velocity-threshold for Crouch/Walk idle, `noise_global_multiplier` applied at return, multi-guard parity note, caller contract note, physics-tick-rate-independent latch duration (AI-1, SD-2, R-10, R-17)
  - F.5 pseudocode: `INT_MAX` → `2147483647`, `.has_method()` guard on `get_interact_priority()`, `InteractPriority` owning file designated (GP-2, GP-3, R-11)
  - F.5 contract notes: Jolt hit-order-not-assumed note (clarifies correctness)
  - F.6 `apply_damage`: non-positive amount guard + `push_warning` (R-12)
  - States & Transitions table: new `Any ground state → Fall` row for ledge walk-off + coyote-time placeholder tied to R-13 (GD-1)
  - E.6: `is_hand_busy()` same-frame clear clarification + `interact_damage_cancel_threshold` knob reference (R-8)
  - Dependencies → risk notes: propagation-geometry split (AI-3, AI-R1), continuous-footstep origin localisation (AI-R2), multi-guard Bidirectional Dependency Statement for Stealth AI
  - Interactions table Stealth AI row + Downstream Stealth AI row: idempotent-read semantic updates
  - Tuning Knobs Camera: `turn_overshoot_deg` default 2.5 → 4.0, safe range 1.5–4.0 → 2.5–4.5 (R-1)
  - Tuning Knobs Noise: `spike_latch_duration_frames` → `spike_latch_duration_sec`; new `idle_velocity_threshold`, `coyote_time_frames` knobs; `noise_global_multiplier` application note (SD-2, R-10, R-17, R-13 placeholder)
  - AC preamble: remove "testable without developer consultation" false claim; note Session E batch 2 for labeling pass (QA-S1)
  - AC-5.1–5.6 rewrite for idempotent-read + multiplier + Walk/Crouch-still 0.0 + AC-5.4 re-framed as multi-guard parity assertion (AI-1, SD-2, R-10)
  - AC-10.1 rewrite: `material_overlay` mandated; runtime settings-change assertion added; grep-clause moved to CI forbidden-pattern note (GDT-1, GDT-R6)
- **Registry**: 3 entries updated (`player_noise_jump_takeoff`, `player_noise_hard_landing`, `player_noise_landing_soft`) with idempotent-read + spike_latch_duration_sec rename + noise_global_multiplier applicability notes.
- **No new ADRs required.** No ADR amendments required — the idempotent-read latch is still a pull-method implementation detail; ADR-0002 contract holds.
- **Status 2026-04-20**: User accepted revisions and marked Player Character **Approved** mid-day. Subsequent `/review-all-gdds` 2026-04-20 cross-review downgraded to **Needs Revision** for 2 residual propagation issues (B4 AC-3.4 stale single-consumption semantics + `_frames`; B5 two residual 2.5° turn_overshoot references in Visual/Feel table line 630 and AC-7.2) + 1 design-theory blocker (GD-B3 Sprint dominance in vertical level sections). Systems-index Player Character row updated to `Needs Revision`.

---

## Revision — 2026-04-20 — Session 2 (post-cross-review B4/B5 sweep)

- **B4 resolved** — AC-3.4 rewritten to cite idempotent-read latch, `spike_latch_duration_sec × Engine.physics_ticks_per_second` frame computation, and `noise_global_multiplier` application. Now consistent with F.4 and AC-5.2/5.6.
- **B5 resolved** — Visual/Feel table line 630 and AC-7.2 both updated from 2.5° to 4.0° with safe range 2.5–4.5°. AC-7.2 gains a ±0.5° tolerance. Consistent with Tuning Knob default Session E-Prime raised.
- **Outstanding (deferred to fresh session)**: GD-B3 Sprint dominance — creative-director flagged this as a Pillar 3 fidelity risk requiring explicit design decision before Stealth AI GDD authoring. Options: (a) vertical sound propagation note, (b) raise Sprint noise, (c) accept Sprint-dominant + document. Not a surgical fix; belongs in a new design conversation.

---

## Review — 2026-04-20 — Verdict: MAJOR REVISION NEEDED (3rd re-review)

- **Scope signal**: L (pillar-compliance re-draft path, Session F) — XL if surgical-patch path is chosen against CD recommendation
- **Specialists**: game-designer, systems-designer, qa-lead, gameplay-programmer, ai-programmer, godot-specialist, audio-director, creative-director (senior)
- **Blocking items**: ~20 new | **Recommended**: ~23 | **Nice-to-Have**: ~5
- **Prior verdict resolved**: Partial — Session 2 B4/B5 sweep verified; GD-B3 still outstanding and **compounded by new Pillar-5 finding (jump_velocity safe-range enables 1.28 m parkour apex)** and **engine-reality bug (`CapsuleShape3D.height` spec is wrong by 0.6 m — collider is 2.3 m standing, not 1.7 m)**.

**Blocker clusters (de-duplicated across specialists):**

- **Engine-reality bugs** [godot-specialist, gameplay-programmer]: `CapsuleShape3D` geometry error; `v.xz` swizzle invalid GDScript; `NoiseEvent.type: PlayerCharacter.NoiseType` circular parse dependency (2 independent specialists converged); SubViewport/CanvasLayer compositing-order claim incorrect.
- **Cross-formula pillar violations** [systems-designer]: flat-ground jump triggers hard landing at safe-range extremes; `jump_velocity` max → 1.28 m apex violates Pillar 5; `jump_velocity` min → 0.30 m apex unplayable; F.5 silent priority inversion at cap exceeded; F.6 spurious `player_damaged` for sub-0.5 amounts.
- **Design-theory blockers** [game-designer + creative-director]: GD-B3 Sprint dominance (second session outstanding, Pillar 3); OQ-7 binary vs scaled hard-landing noise; OQ-8 air control; R-19 FootstepComponent split promoted (child-component seam breaks Stealth AI perception + Audio simultaneously).
- **AI contract gaps** [ai-programmer]: `reset_for_respawn(checkpoint)` referenced but never defined; noise-event collapse loses sequencing info; latch tick-boundary risk; `NoiseEvent` retention footgun has no AC.
- **Forward references to undefined systems** [gameplay-programmer]: `Settings.get_resolution_scale()` (autoload not in any ADR); camera rotation pattern deferred (R-15).
- **QA** [qa-lead]: 10 ACs not independently testable; preamble claim of "implementable-as-worded" is false.

**Creative-director senior verdict**: *"Pillar-compliance re-draft, not surgical patch."* GATE: REJECT. Recommends freezing current GDD as `player-character-v0.3-frozen.md` and rewriting against reduced surface area (4 pillar-serving tuning knobs, 3-4 concrete ACs, FootstepComponent split to sibling doc, collider geometry verified against Godot 4.6 reality). Budget: one focused session (~4-6 hours), NOT another surgical iteration. Pillar status: Pillar 1 HELD; **Pillar 3 AT RISK (degraded from E-Prime)**; **Pillar 5 AT RISK (new finding)**.

**Key quote**: *"23 blockers × ~20 min each = 8 hours of patch work that still leaves the document at current complexity, still vulnerable to the next review surfacing a 24th class of issue. Paying down complexity is cheaper than paying down bugs-at-current-complexity."*

**User decision 2026-04-20**: Pillar-compliance re-draft path accepted. Current GDD frozen; Session F scope brief written to `production/revision-notes/player-character-session-f-redraft-scope.md`. **Stealth AI and Level Streaming remain blocked** against this document until re-draft APPROVED.

**Summary**: Session A-D + E-Prime + Session 2 executed cleanly but the iteration trajectory surfaced pillar violations from within the tuning envelope and engine-reality bugs that section-by-section review could not catch. Document complexity has exceeded the return rate of surgical revision. Decision is to freeze and re-draft against a smaller, pillar-anchored surface.

---

## Revision — 2026-04-21 — Session F pillar-compliance re-draft (executed)

- **Path**: pillar-compliance re-draft per creative-director Session 3 recommendation. Frozen baseline at `player-character-v0.3-frozen.md` (973 lines) retained read-only for audit.
- **Four decision gates closed** via multi-tab AskUserQuestion (pre-draft):
  - GD-B3 Sprint dominance → Option (b): Sprint noise 9 → 12 m. Speed-per-noise: Walk 0.70 / Crouch 0.60 / Sprint 0.46 — Pillar 3 restored via tuning.
  - OQ-7 Hard-landing noise → Scaled formula `8.0 × clamp(|v.y|/v_land_hard, 1.0, 2.0)` capped at 16 m (2×).
  - OQ-8 Air control → Option A (no air control — Deadpan Witness doesn't steer mid-air).
  - CapsuleShape3D correction → **KEEP v0.3 spec** as a godot-specialist-verified FALSE POSITIVE. The 3rd re-review's claim that `height` excludes caps was incorrect — Godot 4.6 `CapsuleShape3D.height` IS total height (including hemispherical caps) with `height >= 2 * radius` engine-enforced. Applying the scope brief's "Option A correction" would have INTRODUCED a 0.6 m collider-height bug.
- **Re-draft delivered**: 881 lines (down from 973). Structural changes: (1) Player Fantasy preserved near-verbatim; (2) FootstepComponent extracted to sibling GDD `design/gdd/footstep-component.md` resolving R-19 AI/Audio seam; (3) Tuning Knobs collapsed from ~44 to 15 designer-facing + Correctness Parameters sidebar; (4) Acceptance Criteria collapsed from 35+ to 12 labeled groups with measurement + threshold + test-evidence path; (5) `PlayerEnums` extracted to break NoiseEvent circular parse dep; (6) safe ranges tightened (gravity 11-13, jump_velocity 3.5-4.2, hard_land_height 1.2-3.0) with numerical proof of max-apex ≤ 0.80 m, min-apex ≥ 0.45 m, no-flat-jump-hard-landing invariants.
- **Phase 5 verification** (3 specialists pre-`/design-review`): game-designer APPROVED, godot-specialist MINOR CONCERNS, qa-lead NEEDS MINOR FIXES — all fixes applied pre-review.

## Review — 2026-04-21 — Verdict: NEEDS REVISION → resolved inline
- **Scope signal**: M (surgical, not structural)
- **Specialists**: game-designer, systems-designer, qa-lead, gameplay-programmer, ai-programmer, godot-specialist, audio-director + creative-director (senior synthesis)
- **Blocking items**: 21 | **Recommended**: ~25 | **Nice-to-have**: ~8
- **Summary**: All 7 specialists returned NEEDS REVISION — not because the re-draft failed its mission (Session F's structural work survived; identity crisis resolved) but because the cross-document contracts, state-machine correctness, and AC-determinism introduced fresh precision gaps. Creative-director meta-pattern: "the re-draft fixed WHAT the game is, but not HOW IT CONNECTS." Pillar status: Pillar 1 HELD; Pillar 3 AT RISK (sprint-sway + noise_global_multiplier governance — recoverable surgically); Pillar 5 VIOLATED-recoverable (five determinism/correctness breaks). Verdict: NEEDS REVISION (not MAJOR). Directive: surgical fixes across 4 files, then re-review.
- **Prior verdict resolved**: YES. Session F re-draft's structural work survives intact; remaining blockers were editorial rigor, not structural rot. v0.3 → Session F closed structural issues; Session F → revision pass closes precision issues.

### Revision pass 2026-04-21 (executed inline — user opted to resolve in-session)

**21 blockers resolved**:
1. [godot-specialist] ADR-0005 `material_override` → `material_overlay` (PC AC-9.1 and ADR-0005 now aligned).
2-4. [audio-director] FC/Audio bucket thresholds unified on 4-bucket scheme (≤3.5 / 3.5-6.5 / 6.5-10 / >10) across FC GDD + Audio GDD — closes threshold contradiction AND gives Sprint (12m) + hard-landing-max (16m) their own stem set; hard-landing vocal differentiation via the extreme bucket.
5. [ai-programmer] `get_silhouette_height()` defined as F.8 with explicit mid-transition interpolation + AC-6bis.1.
6. [ai-programmer] F.6 clears `_latched_event = null` on DEAD transition; F.4 `get_noise_level/event` early-return on DEAD; AC-6.2 new.
7. [ai-programmer] `spike_latch_duration_sec` raised 0.1 → 0.15 s (9 frames @ 60Hz covers all 10Hz guard phases + jitter).
8. [ai-programmer] AC-6.1 rewrite with same-frame assertions.
9. [game-designer] Sprint sway defended explicitly in Player Fantasy AND Forbidden Patterns (single permitted Deadpan Witness exception).
10. [game-designer] `noise_global_multiplier` ship-locked to 1.0; removed from designer tuning surface; Forbidden Patterns forbids runtime writes.
11. [game-designer] F.5 adds squared-distance tie-break for same-priority hits; loop + prose updated.
12. [systems-designer] F.6 documents round-half-away-from-zero boundary; AC-5.2 parametrized {0.3, 0.49, 0.5, 1.5}.
13. [systems-designer] F.3 documents 5→8m discontinuity as intentional design cliff.
14-16. [qa-lead] AC-7.1 split into Logic FOV + Integration clamp; pitch-clamp boundary uses `deg_to_rad(85.0) + 0.001`; input injection API named (`Input.parse_input_event(InputEventMouseMotion)`).
17, 19. [qa-lead] AC-10.2 + AC-FC-4.2 rewritten as fixed-delta tick sequences (determinism).
18. [qa-lead] AC-FC-3.2 split to own test file.
20. [gameplay-programmer] F.5 cites engine-reference for `query.exclude` live-array semantics.
21. [gameplay-programmer] ShapeCast3D ceiling check: persistent `@onready` child at local zero, `target_position` + `force_shapecast_update()` specified.

**Plus 5 folded recommendeds**: AC-9.3 / AC-FC-5.2 / AC-7.4 sign-off criteria (binary rubrics); camera input consumed in `_unhandled_input`; NoiseEvent mutation-site comment anchor. **Plus one new Open Question**: OQ-FC-5 (stairs surface tags) — deferred to content-production scoping.

**Files modified** (4): `design/gdd/player-character.md` (881 → 957 lines), `design/gdd/footstep-component.md` (4-bucket + AC splits), `design/gdd/audio.md` (+extreme variant column + behavior row + GWT scenario), `docs/architecture/adr-0005-fps-hands-outline-rendering.md` (material_overlay correction × 2 sites).

**User decision 2026-04-21**: accept revisions as Approved; skip re-review. Systems-index Player Character (#8) + FootstepComponent (#8b) marked Approved. Stealth AI authoring unblocked.
