# Player Character GDD — Design Review

> **Reviewed file**: `design/gdd/player-character.md`
> **Review date**: 2026-04-19
> **Reviewer**: `/design-review` skill (full mode)
> **Specialists consulted**: game-designer, systems-designer, qa-lead, gameplay-programmer, godot-specialist, ai-programmer, audio-director, creative-director
> **Verdict**: **MAJOR REVISION NEEDED**
> **Scope signal**: **L (Large)**
> **Counts**: 15 Blocking · 25 Recommended · 9 Nice-to-Have

---

## Completeness: 8/8 sections present

All 8 required sections present, plus optional Cross-References, UI Requirements, Open Questions.

## Dependency Graph

- `input.md` ✓ exists
- `signal-bus.md` ✓ exists
- `outline-pipeline.md` ✓ exists
- `post-process-stack.md` ✓ exists
- `audio.md` ✓ exists
- `save-load.md` ✓ exists
- ADR-0001 through ADR-0004 ✓ all exist
- Downstream GDDs (Stealth AI, Combat & Damage, Inventory & Gadgets, HUD Core, Failure & Respawn, Mission Scripting, Document Collection) ⏳ not yet written — correctly flagged in GDD

---

## Blocking (15) — Must resolve before implementation

### Contract violations vs existing ADRs/GDDs

**B-1 · Signal payloads contradict ADR-0002** — [gameplay-programmer, godot-specialist]
GDD declares `player_damaged(amount: int, source: String)`, but ADR-0002 defines `(amount: float, source: Node, is_critical: bool)`. `player_died()` vs ADR `player_died(cause: CombatSystem.DeathCause)`. `player_health_changed(int, int)` vs ADR `(float, float)`. The GDD claims ADR-0002 compliance for signals whose types don't match the ADR. Must adopt ADR-0002 signatures verbatim; GDD must document how `is_critical` is determined and how `DeathCause` is sourced from `apply_damage`.

**B-2 · `player_interacted` and `player_footstep` are NOT in ADR-0002's taxonomy** — [gameplay-programmer]
ADR-0002 enumerates 32 signals across 8 domains. Neither `player_interacted(target: Node3D)` nor `player_footstep(surface: String, loudness: float)` appear anywhere in it. Either amend ADR-0002 (ADR change) or remove the ADR-0002 compliance claim. Must be reconciled before `Events.gd` is authored.

**B-3 · Autoload naming drift: `SignalBus` vs `Events`** — [godot-specialist]
F.7 pseudocode uses `SignalBus.player_damaged.emit(...)`. ADR-0002 registers the autoload as `Events`. AC-10.1 also says "SignalBus autoload." Will fail at runtime with null ref. Replace all occurrences of `SignalBus` with `Events`.

**B-4 · `apply_damage(amount: int, source: String)` cannot produce ADR-0002 `Node` payload** — [gameplay-programmer]
When Combat & Damage calls `apply_damage`, the implementation must emit `Events.player_damaged(amount, source, is_critical)` — but ADR-0002 requires `source: Node`. A string cannot satisfy that. Subscribers doing `is_instance_valid(source)` per ADR-0002 Implementation Guideline 4 will crash. Method signature must become `apply_damage(amount: float, source: Node, damage_type: int)` or equivalent.

**B-5 · `PlayerState.current_state: String` is save-format fragile** — [gameplay-programmer, godot-specialist]
GDD serializes the movement state as a raw string. ADR-0003's precedent (guard state) serializes an `int` enum. Renaming a state constant silently breaks all saves with no version-mismatch signal. Replace with `enum MovementState` stored as int in `PlayerState`.

**B-6 · Mix bus names `SFX_WORLD` and `SFX_FOLEY` don't exist in Audio GDD** — [audio-director]
Audio GDD defines 5 buses: `Music, SFX, Ambient, Voice, UI`. GDD routes footsteps to `SFX_WORLD`, breathing to `SFX_FOLEY` — neither exists. Either Audio GDD adds sub-bus taxonomy or this GDD uses canonical names.

### Formula safety

**B-7 · F.1 — `accel_time = 0` causes division by zero** — [systems-designer]
`rate = 1.0 / accel_time`. Safe range (0.08–0.18) is only in a comment table, not runtime-enforced. A typo of 0.0 in `PlayerTuning.tres` yields `inf`, snapping velocity in one frame. Guard with `1.0 / max(accel_time, 0.001)` and add `@export_range(0.001, 0.25)` to the tuning property.

**B-8 · F.3 — `hard_land_threshold` decouples from `gravity`** — [systems-designer]
F.3 derives `v_land_hard = sqrt(2·g·H)` as documentation only. The runtime gate is the independent tuning knob `hard_land_threshold` (default 6.0). At `g=9.8, H=1.5`: derived = 5.42 m/s — a 1.5 m drop now never triggers hard landing. Either compute the threshold from gravity at runtime (parameterize by a `hard_land_height` knob instead), or explicitly document manual-recalc requirement when gravity is tuned.

**B-9 · F.1 — Δt physics spike destroys acceleration profile** — [systems-designer]
At a physics hitch (Δt = 0.1 s), the acceleration step becomes `(1/0.12) × 3.5 × 0.1 = 2.92 m/s` in one frame — 83% of walk speed from rest in one tick. GDD claims "0.12 s to full speed" but this breaks under any frame spike. Clamp `Δt = min(Δt, 1.0/30.0)` inside F.1, and document.

### Architectural conflicts

**B-10 · FPS hands SubViewport vs ADR-0001 stencil outline — incompatible** — [godot-specialist]
GDD specifies hands render at FOV 55° "on a dedicated viewport layer" AND registers hands at tier HEAVIEST in ADR-0001's stencil system. Stencil buffer is per-framebuffer. If hands render to a `SubViewport`, their stencil writes never reach the main camera's `CompositorEffect`, and AC-11.1 cannot hold. Resolve one of two ways:
- **Option A (preferred)**: Cull-mask + second Camera3D child of the main camera, depth-clear flag, shared framebuffer. Stencil reaches outline pass; outline applies to hands. Requires documenting cull-layer assignment for every mesh in the project.
- **Option B**: Accept no outline on hands; remove `set_tier` call and AC-11.1.

May require ADR-0001 amendment to lock the chosen approach.

**B-11 · F.6 multi-hit raycast pseudocode doesn't match Godot API** — [gameplay-programmer, godot-specialist]
Pseudocode iterates `for hit in hits:` over multiple results to resolve priority. Godot's `RayCast3D.get_collider()` returns one hit. `PhysicsDirectSpaceState3D.intersect_ray()` also returns one hit. Multi-hit requires either (a) iterative raycast with exclusion lists (non-trivial), or (b) `intersect_shape()` against a thin capsule, or (c) redesign — priority resolved by Layer 4 object metadata at a single hit point, with level-design constraints preventing ambiguous stacking. GDD must pick an approach and specify it.

### Interface gaps for Stealth AI

**B-12 · `get_noise_level() -> float` scalar-only** — [ai-programmer]
No noise type (footstep vs landing vs gunshot vs gadget), no occlusion flag (pre/post-wall), no noise origin position. Stealth AI cannot implement wall occlusion, elevation attenuation, or alert-class escalation without this data. Minimum fix: add a `NoiseType` enum (FOOTSTEP, SPIKE_JUMP, SPIKE_LANDING, SPIKE_LANDING_HARD) and either return a `NoiseEvent` struct or expose a companion `get_noise_event() -> NoiseEvent`.

**B-13 · 1-physics-frame spike at 10 Hz AI tick = ~83% miss per guard** — [ai-programmer]
GDD calls this "acceptable" because "multiple guards improve detection," but the Plaza (Tier 0) has one guard. Hard landings go undetected 83% of the time by that guard. No mechanism is provided for Stealth AI to "notice and investigate" a missed spike. Either extend spike duration to ≥6 physics frames (one AI tick) or emit a latched event the AI can poll on next tick.

### Pillar compliance

**B-14 · Stamina subsystem conflicts with Pillar 5** — [game-designer, creative-director]
NOLF1 had no stamina. Hidden stamina is still a "modern verb" in period costume — the GDD spends 500 words on a system whose effects (mid-sprint drop to walk + heavy breathing) are fully visible to the player. 3.8 s max-sprint + 0.43 s wait creates frustration, not comedy; the Deadpan Witness does not run out of breath mid-clutch. Open an OQ explicitly: **does stamina exist at all?** If cut, cascades through F.4, state machine, AC-7, breathing audio, and multiple Tuning Knobs. If kept, GDD must justify with a Pillar 5 design test, not hand-wave "invisible so it's fine."

### Level-design debt

**B-15 · E.5 interact-stacking rule delegates to nonexistent GDD** — [game-designer]
GDD says level designers "must not stack a lower-priority interactable in front of a higher one without deliberate intent." No minimum-separation distance specified. No level-design GDD exists yet. Either add a minimum-separation rule here (e.g., "interactables of different priorities must be ≥0.5 m apart along any ray Eve might trace") or add a priority-resolution tiebreaker that doesn't depend on level-design discipline.

---

## Recommended (25) — Important, not blocking

### Game design

**R-1 · `turn_overshoot_deg = 2.5°` is below perceptual threshold** — [game-designer]
Usable range (2.5–4°) is pathologically narrow; overshoot indistinguishable from mouse bug or frame spike. AC-8.2's trigger (180°/s) is DPI-sensitive — may never fire for some players. QA cannot distinguish intended from regression. Either raise default + widen safe range, or replace camera-level effect with a hands/prop-level micro-animation that's robust across DPI/framerate.

**R-2 · Crouch → Interact stacked animations = ~500 ms non-responsive window** — [game-designer]
120 ms crouch + 150 ms interact pause + 200–250 ms reach. Most common stealth action is "approach desk, crouch, read." GDD doesn't specify whether interact pre-reach starts during the crouch drop, queues after, or resets the 150 ms. Specify exact interleaving.

**R-3 · AC-12.3 "dry, short text" not portable to localized comedic register** — [game-designer]
"Take note" is an English pun. "Prendre note" / "Notiz nehmen" are clinical, not funny. AC-12.3 is untestable in any language but English. Add per-locale sign-off criterion or declare the comedic register as English-only.

**R-4 · CrouchSprint is strictly worse than Walk** — [game-designer]
At 2.4 m/s < Walk 3.5 m/s, noise 9.0 m = Sprint (louder than Walk 5.0 m). Only advantage is silhouette. GDD doesn't quantify when silhouette matters vs noise, so players have no reason to ever use it. Document the intended use-case or acknowledge it as a dead mechanic.

### Specification / state machine

**R-5 · Lateral velocity during Jump is undefined** — [gameplay-programmer]
GDD says "No air control acceleration (preserves lateral velocity at takeoff)." F.1 is conditional on `input_magnitude > 0` applying deceleration. If F.1 runs during Jump with no input, lateral velocity decelerates mid-air — contradicting the stated rule. State explicitly: F.1 does not run during Jump/Fall states.

**R-6 · State-diagram contradicts E.3** — [gameplay-programmer]
ASCII diagram shows `CrouchSprint → Jump` via Space. E.3 says Jump is blocked in CrouchSprint. Either fix the diagram or revise E.3 to allow CrouchSprint jumps.

**R-7 · Sprint → Walk transition timing on stamina exhaustion unspecified** — [gameplay-programmer]
When stamina drops from 0.10 to 0.04 (crossing 0.05 exhaust floor), does `current_state` change that frame (noise table flips 9.0 → 5.0 instantly) or after velocity decelerates? Matters for AI perception during the transition.

**R-8 · `is_hand_busy()` teardown on damage-cancel (E.6) unspecified** — [gameplay-programmer]
If cancel is implemented deferred, there's a one-frame window where `is_hand_busy()` is still true but animation is gone. State: on damage-cancel, flag clears same physics frame.

**R-9 · F.7 pseudocode emits literal `100`, not `max_health`** — [gameplay-programmer]
`Events.player_health_changed.emit(health, 100)` will lie to subscribers if `max_health` is tuned to 150. Use the exported property.

**R-10 · F.4 references `CrouchIdle` state not in the state machine** — [systems-designer]
Pseudocode has `elif state == Crouch or state == CrouchIdle`. State machine lists only `Crouch`. Clarify: is `CrouchIdle` a distinct state or `Crouch` at zero velocity?

**R-11 · Interact priority `InteractType` enum has no owning file** — [systems-designer]
Priorities (`0=Document, 1=Terminal, 2=Pickup, 3=Door`) live only in F.6 comment. Adding a new interactable type requires editing a GDD comment. Designate a `.gd` enum file and reference it.

**R-12 · `apply_damage` does not validate `amount > 0`** — [systems-designer]
Negative values silently heal (`max(0, 80 - (-20)) = 100`). Either assert `amount > 0` or define a separate `apply_heal()`.

### Engine / platform

**R-13 · Jolt `is_on_floor()` transient-false on stairs — no coyote-time specified** — [godot-specialist]
Known 4.6 quirk: Jolt + `move_and_slide()` can return `is_on_floor() = false` for 1–2 frames on step edges. Jump on stairs silently fails. Add coyote-time window (2–4 frames) where `can_jump = true` after last-true `is_on_floor()`.

**R-14 · IK node type unspecified** — [godot-specialist]
GDD references `LeftHandIK`/`RightHandIK` but doesn't say whether they're `BoneAttachment3D`, `TwoBoneIK`, or `SkeletonModifier3D` (Godot 4.6 IK is restored). For two-handed gadget poses `TwoBoneIK` is likely intended. Specify.

**R-15 · Camera pitch-rotation pattern unspecified** — [godot-specialist]
Pattern (a) rotate body for yaw, camera for pitch — yaw rotates physics body. Pattern (b) CameraPivot child owns pitch, body owns yaw — cleaner. Pattern (c) Basis-based. GDD implies (a); (b) is the conventional Godot first-person pattern. Decide before impl.

**R-16 · Mouse sensitivity ownership conflict** — [godot-specialist]
Input GDD line 146: "Player Character owns sensitivity." This GDD: "Mouse sensitivity driven by Input GDD." Reconcile — one canonical owner (likely Settings & Accessibility autoload, consumed by PC).

**R-17 · `_physics_process` 60 Hz not locked as project setting** — [godot-specialist]
Godot's `physics_ticks_per_second` is user-configurable. Spike-duration of "one frame" changes meaning at 30 or 120 Hz. Either lock 60 Hz as a project-settings constraint or confirm all formulas are Δt-parameterized correctly (they mostly are; spike definition is not).

**R-18 · No central collision-layers constants file** — [systems-designer, godot-specialist]
Layers 1–5 live in prose in this GDD and in entities.yaml. Adding Layer 6 later requires manual updates across every GDD and script. Mandate `res://src/core/physics_layers.gd` (or `.tres`) as the single source of truth with named constants.

### Audio

**R-19 · FootstepComponent dual-consumer coupling** — [audio-director]
One component emits Audio events AND updates the noise model — two domains with different update contracts. Changes cascade. Split: FootstepComponent owns audio events only; `get_noise_level()` remains a pure state-lookup.

**R-20 · Surface tag enum has no authoritative source file** — [audio-director]
7 surfaces (`marble`, `tile`, …) named in Player Character GDD; Audio GDD says it owns the surface→SFX map. Designate which file defines the enum. Adding Rome's `snow` surface needs one point of truth.

**R-21 · Step cadence fixed-Hz desyncs with `walk_speed` tuning** — [audio-director]
Walk cadence 2.2 Hz + Walk speed 3.5 m/s = stride 1.59 m. If `walk_speed` tuned to 4.2, stride becomes 1.91 m — footfall no longer matches weight transfer. Derive `cadence = speed / stride_length` with `stride_length` as a new tuning knob.

**R-22 · Idle/walk breathing silence unjustified against Pillar 5** — [audio-director]
Hitman, Dishonored, NOLF1 all have audible idle breathing at low volume. Absence here reads as oversight. Either add a quiet idle loop at −24 dB or document the rejection rationale.

**R-23 · Breathing fade-in/fade-out thresholds unnamed in Tuning Knobs** — [audio-director]
0.2 fade-in and 0.5 fade-out are in prose only. Add `breathing_fadein_stamina` and `breathing_fadeout_stamina` to Tuning Knobs with safe ranges.

**R-24 · Loudness-to-variant (soft/normal/loud) thresholds undefined** — [audio-director]
GDD says Audio picks variants based on `get_noise_level()` output. But noise values are 8 discrete floats — threshold boundaries not defined in either GDD. Audio GDD should own the threshold table.

**R-25 · No temp-audio policy for pre-VO development** — [audio-director]
"No placeholder male ughs from library packs" is correct but leaves no guidance for development before VO is recorded. Add: "Royalty-free labeled-TEMP female breathing stems allowed during dev; replaced before VS lock."

### QA / testability

**R-26 · ACs lack story-type labels and test-evidence paths** — [qa-lead]
Per CLAUDE.md test-evidence table, Logic ACs need automated unit tests, Visual/Feel need screenshots + sign-off. GDD doesn't label ACs by story type, and many ACs are mixed (e.g., AC-3.4 — camera dip is Visual, noise spike is Logic). Label each AC `[Logic] / [Integration] / [Visual/Feel] / [UI]` and attach `tests/unit/player-character/[file].gd` path for Logic/Integration ones.

**R-27 · Many ACs not independently QA-testable** — [qa-lead]
Examples requiring concrete rewrites:
- AC-3.4: "4–6° downward camera pitch dip" — how does QA measure rotation degrees?
- AC-8.2: "Rapid mouse yaw (> 180°/s)" — DPI-dependent; can QA trigger reliably?
- AC-10.2: "No signal fires > 30 Hz" — requires profiler.
- AC-12.1: negative assertion "no head-bob, no sprint whoosh, no damage-edge vignette" — needs an exhaustive checklist of all possible feedback channels to prove absence.
- AC-12.3: "dry, short text" — subjective; define with character-count or linguist sign-off.

### Interface / AI

**R-28 · `get_silhouette_height() -> float` too reductive** — [ai-programmer]
Single scalar forces Stealth AI to guess raycast target Y offset. Partial-occlusion behind waist-high cover requires multi-point sampling. Expose `get_perception_points() -> Array[Vector3]` returning [feet, center, eyes] in world space.

**R-29 · Canonical "can I see Eve" contract missing** — [ai-programmer]
Dependencies table says Stealth AI reads "collision Layer 2 membership" with no raycast target point, occlusion layer rules, or partial-occlusion behavior. Two implementers would produce two different vision systems. Specify: raycast target = `origin + Vector3(0, silhouette_height * 0.5, 0)`; treat Layer 1 as occluder, Layer 2 as hit; Layer 3 guards don't occlude each other (or do — decide).

**R-30 · Hard-landing noise (8.0 m) is surface-agnostic; footsteps are surface-weighted** — [ai-programmer]
Inconsistency: either route hard-landings through FootstepComponent so surface applies, or explicitly document hard-landing spikes bypass surface attenuation by design.

---

## Nice-to-Have (9)

- **N-1** Walk 3.5 m/s + FOV 75° + no head-bob may read as "sluggish" for first 10–15 minutes. Plaza tutorial should give early sprint context. [game-designer]
- **N-2** `reset_for_respawn(checkpoint)` referenced in bidirectional deps but not specified in this GDD (`is_hand_busy` reset, stamina reset behavior). [game-designer]
- **N-3** "One outfit per mission" ludonarrative friction not flagged (kitchen context, mirror consistency). [game-designer]
- **N-4** Footstep cadence timer reset on crouch/uncrouch toggle not specified. [gameplay-programmer, audio-director]
- **N-5** `ShapeCast3D` node vs one-shot `intersect_shape()` for ceiling check (E.1) unspecified — one-shot is correct. [godot-specialist]
- **N-6** Hands viewport cull-layer assignment is cross-cutting — document in a Rendering Layers section of future Control Manifest. [godot-specialist]
- **N-7** Crouch transition SFX (cloth, belt-settle) and jump takeoff SFX missing from audio section. [audio-director]
- **N-8** No ducking note for audio mix under alert music (Music vs Footsteps during combat). [audio-director]
- **N-9** Localization scope for Eve's huf vocal / controlled-exhale across DE/FR/ES/IT dubs not scoped (Narrative GDD concern). [audio-director]

---

## Specialist Disagreements

**Stamina — framing disagreement** (surfaced by creative-director):

- `game-designer` treats stamina as a **pillar violation** (cut or justify).
- `gameplay-programmer` + `systems-designer` treat it as a **specification defect** (fix math, state machine).
- `qa-lead` treats it as a **testability gap** (fix ACs).

All correct in their domain, but they point in different directions. **Creative-director resolution**: resolve the creative question (does stamina exist at all?) **first**, or engineering spends effort on a system that may be cut. This is the key decision gating ~30% of downstream fixes.

No other direct specialist contradictions observed.

---

## Senior Verdict [creative-director]

> The Player Character GDD is not ready for implementation. It contains contract violations against ADR-0002 (signal taxonomy, autoload naming) and the Audio GDD (mix bus names) that would fail at first integration, a division-by-zero in movement acceleration, and a rendering pipeline conflict (hands-in-SubViewport loses the comic-book outline stencil) that requires an ADR amendment before it can be resolved. The hidden-stamina subsystem conflicts with Pillar 5 and must be re-examined as an open question — NOLF1 shipped without stamina and the GDD does not justify the addition. Recommend splitting revision into **four focused sessions** (creative → architecture → contracts → specification) rather than one pass. Downstream Stealth AI and Audio work should not begin until the noise-perception contract (direction, occlusion, type enum) and mix bus taxonomy are fixed.

---

## Scope Signal

**L (Large)** — 7 downstream systems consume this contract; 7 formulas; blockers span creative, architectural, and contract domains; likely requires ADR-0001 amendment (hands-outline pipeline) and ADR-0002 amendment (add `player_interacted`, `player_footstep`).

---

## Cross-References

- Working punch list: `production/revision-notes/player-character-blockers.md`
- Review-log index entry: `design/gdd/reviews/player-character-review-log.md`
- Reviewed GDD: `design/gdd/player-character.md`
- Prior verdict: none (first review)
