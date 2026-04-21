# Player Character GDD — Revision Punch List

> **Source review**: `design/gdd/reviews/player-character-review-2026-04-19.md`
> **Target GDD**: `design/gdd/player-character.md`
> **Verdict**: MAJOR REVISION NEEDED · 15 Blocking · 25 Recommended · 9 Nice-to-Have
> **Structure**: Organized per creative-director's 4-session plan (creative → architecture → contracts → specification).

---

## Session A — Creative decision (resolve first) ✅ COMPLETE 2026-04-19

One decision here cascades through ~30% of the engineering blockers.

- [x] **B-14** · **Stamina system: does it exist at all?** [game-designer / creative-director] → **Option A selected: Cut entirely.**
  - Deleted: F.4 Stamina Dynamics (F-numbers renumbered down: F.5→F.4, F.6→F.5, F.7→F.6), AC-7 (renumbered AC-8..AC-12 down to AC-7..AC-11), E.10 (renumbered E.11..E.14 down to E.10..E.13), Stamina tuning subsection (5 knobs), stamina-exhaust breathing tier (was line 553), stamina conditions in transition rules, `s` from formula variables, `stamina: float` from PlayerState schema.
  - Added: Rejected-features block in Detailed Design → Core Rules with Pillar-5 rationale. AC-11.1 reinforced: "no stamina system of any kind (visible or hidden)."
  - **Downstream cascades resolved here**: R-7 (sprint→walk transition timing — moot), R-23 (breathing fade thresholds — moot).

- [x] **R-4** · CrouchSprint cut alongside stamina. State machine now 7 states (was 8). Removed: Movement speeds row, Noise table row, state-diagram box + Shift+Ctrl edge, Crouch→CrouchSprint transition rule, `crouch_sprint_speed` tuning knob, CrouchSprint cadence, AC-1.4, CrouchSprint references in AC-2.3 and AC-5.1. Rationale captured in Rejected-features block.

- [x] **R-22** · Added quiet continuous breath loop at −24 dB during Idle AND Walk. Sprint retains its subtle −12 dB breathing (replaces the idle loop when active — single bed, not a stack). No stamina-tied heavier tier.

---

## Session B — Architecture (ADR amendments before contract work) ✅ COMPLETE 2026-04-19

These require drafting / amending ADRs, not just GDD edits.

- [x] **B-10** · FPS hands SubViewport vs ADR-0001 stencil outline conflict. **Resolved via Option C (specialist-proposed mid-session): inverted-hull shader on hands mesh inside SubViewport.** godot-shader-specialist memo revealed Option A (dual-camera shared framebuffer) is not buildable in GDScript without GDExtension — `Camera3D` cannot share a framebuffer from GDScript in Godot 4.6. Option C sidesteps the stencil entirely via hull extrusion on `HandsOutlineMaterial`. Outcome: **ADR-0005 (FPS Hands Outline Rendering) authored as Proposed** with 4 verification gates (Vulkan + D3D12 render parity, `resolution_scale` sync, rigged-animation artifact check). PC GDD updated: 7 edits including Summary line 23, Interactions table row (Outline Pipeline), Visual/Audio "Outline" + "Camera relationship" bullets, Dependencies table (added ADR-0005 row), AC-10.1 rewritten to test the inverted-hull material. AC-11.1 unchanged (hands remain outlined — only the technique changed).

- [x] **B-2** · Add `player_interacted` and `player_footstep` to ADR-0002's taxonomy. **Resolved.** Domain: new **Player** domain (minimal amendment — existing Combat-domain `player_*` signals not moved to avoid touching Session C's B-1 scope). Signatures: `player_interacted(target: Node3D)` (target may be null — see PC GDD E.5 + ADR-0002 Implementation Guideline 4), `player_footstep(surface: StringName, noise_radius_m: float)` (renamed from `loudness` for self-description — 0–9 m per PC GDD noise table). **ADR-0002 amended** with Revision History block, 9→34 signal count updated across Summary + Decision + Implementation Guideline 5 + Migration Plan + Validation Criteria; Alternative-3 rejection paragraph updated to `~30 events`. PC GDD updated: Interactions table Audio row + Dependencies Audio row + FootstepComponent block all cite new signature.

- [x] **B-6** · Mix bus names. **Resolved by PC GDD adopting canonical `SFX` bus.** Audio GDD's 5-bus model (Music/SFX/Ambient/Voice/UI) is authoritative; `SFX_WORLD` / `SFX_FOLEY` were fictional. All four PC audio routings (footsteps/breathing/hard-landing/dead-exhale) now route to canonical `SFX` bus — breathing on SFX means it ducks correctly under VO per Audio GDD Rule 7. Foley survives as an asset-spec authoring convention only (stem tagging for variants + loudness normalization), not a bus. Audio GDD NOT amended (clean resolution from PC GDD side only). PC GDD Visual/Audio "Audio — Mix Bus Routing" block rewritten with rationale note.

- [x] **R-18** · Central collision-layers constants file. **Resolved via ADR-0006 (Collision Layer Contract) authored as Proposed.** Source of truth: `res://src/core/physics_layers.gd` (static class, not autoload) with 5 layer indices + 5 bitmask constants + 5 composite masks (`MASK_AI_VISION_OCCLUDERS`, `MASK_INTERACT_RAYCAST`, etc.). `project.godot` `[layer_names]/3d_physics/layer_1..5` also populated. Forbidden pattern registered: `hardcoded_physics_layer_number` (PR review flags bare integer layer indices in gameplay code). 3 verification gates. PC GDD updated: 9 edits total — Core Rules rule 5 replaced with `PhysicsLayers.*` reference table, interact raycast (line 101) cites `MASK_INTERACT_RAYCAST`, Stealth AI dependency rows cite `LAYER_PLAYER`, FootstepComponent raycast cites `MASK_FOOTSTEP_SURFACE`, AC-4.1 + Open Questions downward-raycast both updated, Cross-References ADR list has new ADR-0006 bullet.

---

## Session C — Contract alignment (mechanical, after A + B decisions) ✅ COMPLETE 2026-04-19

- [x] **B-1** · Updated F.6 pseudocode + all signal references to ADR-0002 signatures. Signatures now verbatim: `player_damaged(amount: float, source: Node, is_critical: bool)`, `player_died(cause: CombatSystem.DeathCause)`, `player_health_changed(current: float, max_health: float)`. Decisions: `is_critical = false` at MVP (Combat & Damage GDD will define crit rules later); `DeathCause` derived from killing blow's `damage_type` via `CombatSystem.damage_type_to_death_cause` pure helper owned by Combat & Damage (default `DeathCause.UNKNOWN` for unmapped types per ADR-0002 Implementation Guideline 2).
- [x] **B-3** · Replaced all `SignalBus` with `Events` (F.6 pseudocode × 3 lines, AC-9.1). Verified zero residuals via grep: `SignalBus|apply_damage\(amount: int|player_damaged\(amount: int|player_died\(\)|, max: int\)` returns no matches.
- [x] **B-4** · Rewrote `apply_damage` signature: `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)`. Updated 9 call sites: Summary, Core Rules Health paragraph, Interactions table Combat & Damage row, F.6 pseudocode, E.12 kill-plane, Dependencies Combat & Damage row + Bidirectional statement + stale risk note, Cross-References Downstream, AC-6.1–6.5 (all five test cases rewritten with `test_source_node` placeholder + `CombatSystem.DamageType.TEST`).
- [x] **B-5** · `PlayerState.current_state: String` → `current_state: int`. New `PlayerCharacter.MovementState` inner enum `{IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, DEAD}` declared in Core Rules with explicit note on ADR-0002 Guideline 2 (enum owned by PlayerCharacter, NOT on Events.gd, NOT on shared Types.gd). Updated Interactions table Save/Load row, AC-8.1, and F.6 `MovementState.DEAD` state checks. **Cascade**: `design/gdd/save-load.md` line 101 PlayerState row also aligned — `health: float` → `int` and `current_state: String` → `int` enum (Session B surfaced both divergences; closed here).
- [x] **R-9** · F.6 pseudocode `Events.player_health_changed.emit(float(health), float(max_health))` — literal `100` replaced with `max_health` property reference. Explicit note added under F.6's contract notes. `max_health` already existed as a tuning knob (default 100, safe range 50–200).
- [x] **R-16** · Mouse sensitivity ownership: PC GDD Camera paragraph previously said "Mouse sensitivity driven by Input GDD" — backwards per Input GDD §Formulas ("mouse sensitivity…live[s] in Player Character"). PC GDD Camera paragraph corrected: Input owns raw event capture; PC owns transformation including `mouse_sensitivity_x`/`mouse_sensitivity_y`/`gamepad_look_sensitivity` knobs (three new rows added to Tuning Knobs → Camera); Settings & Accessibility autoload persists runtime overrides to `user://settings.cfg`. Ownership note appended to Tuning Knobs → Camera subsection.

---

## Session D — Specification / math / AI contracts

- [x] **B-7** · F.1 NaN guards added (`max(accel_time, 0.001)` + `max(decel_time, 0.001)`). Inspector `@export_range` pinned to **design envelope** (walk_accel 0.08–0.18, walk_decel 0.12–0.25, sprint_accel 0.10–0.22), not the pure-safety 0.001 floor — `@export_range` communicates designer intent while `max(..., 0.001)` handles NaN. `crouch_transition_time` explicitly excluded (animation duration, not a rate divisor). Tuning Knobs Acceleration-times subsection gained a dedicated "Inspector validation" note. Specialist: systems-designer. Resolved 2026-04-19.

- [x] **B-8** · `hard_land_threshold` renamed to `hard_land_height` (Option A — specialist recommended + user confirmed). Tuning Knob row now: `hard_land_height: 1.5 m, range 1.0–3.0`; velocity derived at runtime via `v_land_hard = sqrt(2 × gravity × hard_land_height)`. F.3 formula + worked examples rewritten (g=9.8/12/15 cases shown). Tuning Knobs Vertical subsection gained a `gravity × hard_land_height interaction` note covering the [4.43, 9.49] m/s safe-range extremes. Registry reconciled: entry renamed + value/unit updated + `player_noise_hard_landing` notes cleaned of stale `>6.0 m/s` literal. Specialist: systems-designer. Resolved 2026-04-19.

- [x] **B-9** · Global Δt clamp applied to F.1 + F.2 (specialist recommended over F.1-only scope). Prevents hitches from fabricating false hard-landing noise spikes (stealth-gameplay false-positive where AI hears physics artifacts). Preamble block added to the Formulas section before F.1: `Δt_clamped = min(Δt, 1.0 / 30.0)`. F.1 velocity blend + F.2 gravity line both consume `Δt_clamped` (jump impulse is instant and needs no clamp; F.3 is a threshold comparison and needs no own clamp). Variables-used list updated. Specialist: systems-designer. Resolved 2026-04-19.

- [x] **B-11** · F.5 multi-hit raycast resolved via **Option (a) iterative raycast with exclusion list**, capped at `raycast_max_iterations` (default 4, range 2–6). Specialist (gameplay-programmer) memo ruled out (b) intersect_shape thin capsule — over-captures off-axis, breaks priority semantics; and (c) single-hit redesign — would leave stacking discipline as a level-design promise rather than a code guarantee. F.5 pseudocode replaced with Godot-4.6-idiomatic GDScript using `PhysicsRayQueryParameters3D.create()` + `space_state.intersect_ray()` in a loop with `query.exclude.append(hit.rid)`. Priority data delegated to `get_interact_priority()` method on each interactable (duck-typed, testable, extensible). Cap exceeded: graceful degradation — best-so-far returned, no crash. Jolt broad-phase honors exclude list natively; sub-linear cost scaling. **Bonus HUD-coherence fix**: Core Rules rule 5 now states the continuous HUD-highlight query uses the same `_resolve_interact_target()` F.5 uses — outlined object always matches E-press target. Note: the review punch list referenced this as "F.6 multi-hit raycast" but the raycast actually lives in F.5 (F.6 is damage application); corrected. Resolved 2026-04-19.

- [x] **B-12** · Resolved via **Option B** (scalar + companion method). `get_noise_level() -> float` kept for the 80 Hz hot path; new `get_noise_event() -> NoiseEvent` returns and clears a latched discrete-spike event (null when no spike is latched). Continuous locomotion (Walk/Sprint/Crouch) does NOT latch — it's covered by `get_noise_level()` alone. `NoiseEvent` is a `class_name` in its own file (`res://src/gameplay/player/noise_event.gd`, globally visible), NOT a `Resource` (no ref-counted allocator overhead at 80 Hz aggregate polling). Fields: `{ type: PlayerCharacter.NoiseType, radius_m: float, origin: Vector3 }`. `NoiseType` enum added as inner enum on `PlayerCharacter` alongside `MovementState` (same ADR-0002 Guideline 2 pattern from Session C B-5) with 6 values: `FOOTSTEP_SOFT / FOOTSTEP_NORMAL / FOOTSTEP_LOUD / JUMP_TAKEOFF / LANDING_SOFT / LANDING_HARD`. Crouch / Walk / Sprint are separately typed so Stealth AI can type-switch on suspicion-increment rate (not just scalar radius). No ADR-0002 amendment required — latched queue is a pull-method implementation detail, not a signal. Specialist: ai-programmer. **Bonus delineation**: `player_footstep` signal clarified as Audio-only; "Stealth AI MUST NOT subscribe to `player_footstep`" note added to Interactions table Audio row, Cross-References Downstream Stealth AI row, and the bidirectional dependency statement. Resolved 2026-04-20.

- [x] **B-13** · Resolved via **latched `NoiseEvent` the AI consumes on next poll** (not the "extend spike to 6 frames" option — latching is deterministic, duration-extension is not). Rules: (1) Jump takeoff + landing variants record `NoiseEvent` to `_latched_event` immediately on state transition (no deferral). (2) Stacked spikes within the latch window collapse **highest-radius-wins** (metal-grate scenario: footstep-normal 5.0 m > takeoff 4.0 m → footstep wins). (3) Latch auto-expires after `spike_latch_duration_frames` (new tuning knob, default 6 physics frames = one AI tick window at 10 Hz, safe range 6–12) even if no AI consumed it — prevents stale investigate markers. (4) Continuous-locomotion state transitions do NOT touch the latch. Performance: single reused `NoiseEvent` instance, zero steady-state allocation. F.4 pseudocode fully rewritten; 1-frame-spike + 1-in-6 probability rationale removed (was non-deterministic and untestable per Session D review). AC-5 rewritten: AC-5.1 updated for scalar-with-latched-spike semantics; AC-5.2/5.3 rewritten for latched NoiseEvent delivery + single-consumption; new AC-5.5 (stacking collapse) + AC-5.6 (auto-expiry). AC-3.4 updated for latched model. Resolved 2026-04-20.

- [x] **B-15** · E.5 rewritten — replaced the "Level designers must not stack..." prose warning with **both** a code-guarantee (F.5's priority resolution applies within the iteration cap, no level-design arrangement can defeat it) **and** a level-design QA rule (`interact_min_separation` = 0.15 m, safe range 0.0–0.5 m, added to Tuning Knobs). Rule is not runtime-enforced — it's a content-review checkpoint designed to keep stacked-interactable counts below `raycast_max_iterations` in practice. Cap-violation failure mode documented: skipped items beyond cap are unreachable without repositioning (no crash). Resolved alongside B-11 2026-04-19.

### Recommended — Game design

- [ ] **R-1** · `turn_overshoot_deg` rework (raise default, widen range, OR replace with hands/prop micro-animation).
- [ ] **R-2** · Specify Crouch + Interact stacked-animation interleaving.
- [ ] **R-3** · AC-12.3 localization: per-locale sign-off criterion or English-only scope note.

### Recommended — State machine / spec

- [x] **R-5** · F.1 scope-gating note added opportunistically alongside B-7/B-9 (one-line comment: "Runs only in Idle/Walk/Sprint/Crouch; Jump/Fall preserve ground-frame momentum; air control not specified — see OQ-8"). New **OQ-8** (Air control specification) opened in Open Questions section capturing the three options (None / Partial / Full) for later design decision. Resolved 2026-04-19.
- [ ] **R-6** · Fix state diagram: remove `CrouchSprint → Jump` edge OR revise E.3 to allow it.
- [x] **R-7** · ~~Specify Sprint → Walk transition timing on stamina exhaustion~~ — **AUTO-RESOLVED by Session A B-14 (stamina cut; no exhaustion event exists).**
- [ ] **R-8** · On damage-cancel (E.6), `is_hand_busy()` clears same physics frame.
- [ ] **R-10** · Reconcile F.4's `CrouchIdle` reference with state machine (either add CrouchIdle to states, or rewrite F.4).
- [ ] **R-11** · Designate `InteractType` enum-owning file; reference from F.6.
- [ ] **R-12** · `apply_damage` — assert `amount > 0` or define separate `apply_heal()`.

### Recommended — Engine / platform

- [ ] **R-13** · Add coyote-time window (2–4 frames) for Jolt `is_on_floor()` transient-false.
- [ ] **R-14** · Specify IK node type for `LeftHandIK` / `RightHandIK` (likely `TwoBoneIK`).
- [ ] **R-15** · Commit to camera pitch-rotation pattern (body-yaw + camera-pitch vs CameraPivot intermediate).
- [ ] **R-17** · Lock `physics_ticks_per_second = 60` as project-settings constraint OR parameterize spike duration in seconds not frames.

### Recommended — Audio

- [ ] **R-19** · Split FootstepComponent: audio-event side remains; noise-model side moves to PlayerCharacter state-lookup.
- [ ] **R-20** · Designate surface-tag enum-owning file.
- [ ] **R-21** · Rewrite step cadence: `cadence = current_speed / stride_length` with `stride_length_per_state` tuning knobs.
- [x] **R-23** · ~~Add `breathing_fadein_stamina` and `breathing_fadeout_stamina` to Tuning Knobs~~ — **AUTO-RESOLVED by Session A B-14 (stamina-tied breathing tier removed; idle loop is unconditional per R-22).**
- [ ] **R-24** · Audio GDD: define loudness-to-variant threshold table.
- [ ] **R-25** · Add temp-audio policy note ("labeled TEMP, replaced before VS lock").

### Recommended — QA

- [ ] **R-26** · Label every AC with `[Logic] / [Integration] / [Visual/Feel] / [UI]` and attach `tests/unit/player-character/[file].gd` path for Logic/Integration.
- [ ] **R-27** · Concrete rewrites for AC-3.4 (measurement method), AC-8.2 (DPI-independent trigger), AC-10.2 (profiler method), AC-12.1 (exhaustive negative-assertion checklist), AC-12.3 (character-count or linguist sign-off).

### Recommended — AI / interface

- [ ] **R-28** · Expose `get_perception_points() -> Array[Vector3]` for multi-point LOS raycast targets.
- [ ] **R-29** · Document canonical "can I see Eve" contract (raycast target Y, occluder layers, partial-occlusion behavior).
- [ ] **R-30** · Resolve hard-landing noise inconsistency (surface-aware vs surface-agnostic).

---

## Nice-to-Have (defer to post-revision or VS tier)

- [ ] **N-1** Plaza tutorial: early sprint opportunity in safe context (belongs to Mission Scripting GDD).
- [ ] **N-2** Specify `reset_for_respawn(checkpoint)` contract in this GDD.
- [ ] **N-3** Flag "one outfit per mission" ludonarrative consideration.
- [ ] **N-4** Footstep cadence timer reset on crouch/uncrouch toggle.
- [ ] **N-5** Specify ceiling-check = one-shot `intersect_shape()` (not `ShapeCast3D` node).
- [ ] **N-6** Cull-layer assignment documented in Control Manifest.
- [ ] **N-7** Crouch transition + jump takeoff SFX added to audio section.
- [ ] **N-8** Ducking note for audio mix under alert music.
- [ ] **N-9** VO localization scope flag for Narrative GDD.

---

## Progress tracker

| Session | Status | Blockers resolved |
|---|---|---|
| A — Creative decision | ✅ complete 2026-04-19 | 3 / 3 (B-14, R-4, R-22) |
| B — Architecture | ✅ complete 2026-04-19 | 4 / 4 (B-10, B-2, B-6, R-18) + bonus ADR-0003 stamina sync |
| C — Contract alignment | ✅ complete 2026-04-19 | 6 / 6 (B-1, B-3, B-4, B-5, R-9, R-16) + bonus save-load.md health/current_state cascade |
| D — Specification / math / AI (blockers) | ✅ complete 2026-04-20 | **7 / 7 blockers** (B-7, B-8, B-9, B-11, B-12, B-13, B-15) + R-5 opportunistic + registry sync (5 entries) + 2 new OQs (OQ-7, OQ-8) |
| E — Recommended items (deferred) | ⏳ pending re-review | 21 recommended items deferred from Session D scope: R-1, R-2, R-3, R-6, R-8, R-10, R-11, R-12, R-13, R-14, R-15, R-17, R-19, R-20, R-21, R-24, R-25, R-26, R-27, R-28, R-29, R-30 (R-5 resolved in D; R-7/R-22/R-23 auto-resolved in A; R-9/R-16 done in C). See "Session E scope" section below. |

**Session A side effects (all resolved in Session B):**
- ✅ ADR-0003 `PlayerState` schema verification: ADR-0003 itself does NOT inline the PlayerState shape (only references `@export var player: PlayerState`), so no ADR amendment was needed. Downstream save-load.md DID have a stale `stamina: float` in its Interactions table row — removed 2026-04-19. Also noted that save-load.md still has two discrepancies vs PC GDD (health `float` vs `int`, missing `current_state` field) — Session C B-5 will reconcile those.
- **R-7** (sprint→walk exhaustion transition timing) and **R-23** (breathing fade-in/out stamina thresholds) are auto-resolved by stamina removal — strike from Session D when its pass runs.

**Session B artifacts:**
- `docs/architecture/adr-0005-fps-hands-outline-rendering.md` — new, Proposed, 4 verification gates
- `docs/architecture/adr-0006-collision-layer-contract.md` — new, Proposed, 3 verification gates
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — amended (Revision History block added; 32→34 signals; new Player domain)
- `design/gdd/player-character.md` — 19 targeted edits across Summary, Core Rules, Interactions, Dependencies, Visual/Audio Hands + Mix Bus, AC-4.1, AC-10.1/10.2, Cross-References, Open Questions
- `design/gdd/save-load.md` — 1 edit (stamina removed from PlayerState row)

**Session C artifacts:**
- `design/gdd/player-character.md` — 19 targeted edits across Summary, Core Rules (Health paragraph + Camera paragraph + new MovementState enum block), Interactions table × 3 rows, F.6 full rewrite, E.12 kill-plane, Dependencies × 2 rows + risk note, UI Requirements signals table, Tuning Knobs Camera subsection (+ 3 knobs + ownership note), Cross-References Downstream, AC-6.1–6.5, AC-8.1, AC-9.1
- `design/gdd/save-load.md` — 1 edit: PlayerState row `health: float` → `int` and `current_state: String` → `int` enum
- `design/gdd/reviews/player-character-review-log.md` — Session C entry appended with full item list and load-bearing design decisions
- No new ADRs; no ADR amendments (all 6 items were GDD edits against contracts already fixed by Sessions A + B)

**Session D artifacts (2026-04-20):**
- `design/gdd/player-character.md` — ~25 targeted edits:
  - Formulas preamble + F.1 full rewrite (Δt_clamped preamble, NaN guards `max(accel_time, 0.001)`, R-5 scope-gating note)
  - F.2 gravity line uses `Δt_clamped`
  - F.3 full rewrite (runtime `v_land_hard = sqrt(2 × gravity × hard_land_height)` formula; worked examples at g=9.8/12/15)
  - F.4 full rewrite (two pull methods, latched NoiseEvent, highest-radius-wins stacking, auto-expiry)
  - F.5 full rewrite (Godot-4.6 iterative raycast with `PhysicsRayQueryParameters3D` + exclusion list + `get_interact_priority()` delegation)
  - Core Rules rule 5 (interact raycast) tightened — continuous HUD highlight uses same F.5 resolver
  - Core Rules — added `NoiseType` inner enum + `NoiseEvent` `class_name` declaration + state-to-NoiseType mapping (alongside MovementState pattern from Session C)
  - E.5 rewrite (priority-resolution code guarantee + min-separation rule, removes level-design-discipline prose)
  - Interactions table × 3 rows (Stealth AI, Audio with "MUST NOT subscribe" delineation)
  - Tuning Knobs: Acceleration times note (B-7), Vertical table (`hard_land_threshold` → `hard_land_height` + interaction note), Interact table (+2 knobs: `raycast_max_iterations`, `interact_min_separation`), Noise table (+1 knob: `spike_latch_duration_frames`)
  - Cross-References Downstream Stealth AI row (+ bidirectional statement + risk note) — perception-path-blurring risk call-out
  - AC-3.4 updated for latched landing model
  - AC-5 rewrite: 5.1/5.2/5.3 updated + new 5.5 (stacking collapse) + 5.6 (auto-expiry)
  - Open Questions: +OQ-7 (binary vs scaled hard-landing noise severity), +OQ-8 (air control specification)
- `design/registry/entities.yaml` — 5 entries reconciled:
  - `player_hard_land_threshold` → renamed to `player_hard_land_height` (value 6.0 m/s → 1.5 m; unit m/s → m; formula-derived threshold documented)
  - `player_noise_hard_landing` — notes updated (v_land_hard formula, latched-event model, OQ-7 ref)
  - `player_noise_jump_takeoff` — notes updated (latched-event model, drops "1 frame" claim)
  - `player_noise_landing_soft` — NEW entry (5.0 m, registered explicitly per B-13)
  - `player_noise_crouch_sprint` — status active → deprecated (orphan cleanup from Session A R-4 cascade)
- No new ADRs required; no ADR amendments required. ADR-0002 latched-event queue is a pull-method implementation detail, not a signal.

**Session E scope (21 recommended items, deferred — await /design-review re-run first):**
- **Game design** (Task batch 4): R-1 turn_overshoot_deg rework · R-2 Crouch+Interact animation interleaving · R-3 AC-12.3 localization · R-6 state-diagram CrouchSprint→Jump edge · R-8 damage-cancel is_hand_busy same-frame · R-10 F.4 CrouchIdle reference · R-11 InteractType enum-owning file · R-12 apply_damage amount>0 assert
- **Engine / platform** (Task batch 5): R-13 coyote-time window · R-14 IK node type (TwoBoneIK) · R-15 camera pitch-rotation pattern · R-17 physics_ticks_per_second=60 lock or spike-duration seconds parameterization
- **Audio** (Task batch 6): R-19 FootstepComponent split (audio-event vs noise-model sides) · R-20 surface-tag enum-owning file · R-21 step cadence rewrite (speed/stride_length) · R-24 loudness-variant threshold table · R-25 temp-audio policy note
- **QA** (Task batch 7): R-26 AC labeling by test type + test path citations · R-27 concrete rewrites for AC-3.4/8.2/10.2/12.1/12.3
- **AI interface** (Task batch 8): R-28 get_perception_points() multi-point LOS · R-29 canonical "can I see Eve" LOS contract · R-30 hard-landing noise surface-awareness consistency (ties to B-12/13 + R-19)

**Order of operations for Session E:**
1. First run `/design-review design/gdd/player-character.md` in a fresh session. The re-review may auto-resolve some recommendeds (changes from Session D may make them moot) and may surface new issues to fold in.
2. Use the re-review verdict to re-prioritise the Session E list. Auto-resolved items strike; new blockers promote.
3. Then work through surviving recommendeds in batches by specialist: game-designer → systems-designer → godot-specialist → audio-director/sound-designer → qa-lead → ai-programmer.
4. After Session E completes: final `/design-review` for APPROVED verdict.
