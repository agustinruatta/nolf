# Session State

**Last updated:** 2026-04-21 (Session F re-draft + `/design-review` revision pass COMPLETE · Stealth AI GDD authored, 606 lines, pending `/design-review` in fresh session)

## Current task

✅ `design/gdd/player-character.md` — **Session F re-draft COMPLETE (2026-04-21)**. Down from 973 → 879 lines. All ~20 blockers from 3rd re-review (2026-04-20) addressed inline. FootstepComponent extracted to sibling GDD at `design/gdd/footstep-component.md` to resolve R-19 AI/Audio seam.

**Next action** (user runs in a FRESH session, not here): `/design-review design/gdd/player-character.md`

## Session F execution summary

### Four decision gates closed (multi-tab AskUserQuestion 2026-04-20)
- **GD-B3 Sprint dominance** → Option (b): `noise_sprint` 9 m → **12 m**. Speed-per-noise: Walk 0.70, Crouch 0.60, Sprint 0.46 — Sprint now strictly dominated. Pillar 3 restored.
- **OQ-7 Hard-landing noise** → Scaled formula `noise_radius = 8.0 × clamp(|v.y|/v_land_hard, 1.0, 2.0)` (cap 16 m at 2×).
- **OQ-8 Air control** → Option A (no air control — Deadpan Witness doesn't steer mid-air).
- **CapsuleShape3D correction** → **KEEP v0.3 spec (false positive)**. godot-specialist verified Godot 4.6 `CapsuleShape3D.height` IS total height (including hemispheres), `height >= 2*radius`. Scope brief's "Option A" would have INTRODUCED a 0.6 m collider-height bug. Retained `height=1.7/1.1 m, radius=0.3 m`.

### Additional blocker fixes inline in re-draft
- `v.xz` swizzle → `Vector2(velocity.x, velocity.z)` intermediate in F.1
- `NoiseEvent.type: PlayerCharacter.NoiseType` circular parse dep → extracted to `PlayerEnums` on `res://src/gameplay/player/player_enums.gd`
- F.5 silent priority inversion → `push_warning` on cap-exceeded
- F.6 sub-0.5 rounding → post-rounding guard `if rounded <= 0: return`
- `reset_for_respawn(checkpoint)` → new Core Rules section documenting the contract
- SubViewport/CanvasLayer compositing wording → rewritten (outline baked INSIDE SubViewport; not stacked via shared stencil)
- Camera rotation R-15 → body-yaw + camera-pitch (standard FPS) committed
- Cross-formula jump-apex blockers → safe ranges tightened: gravity 11-13 (from 9.8-15), jump_velocity 3.5-4.2 (from 3.0-5.0), hard_land_height 1.2-3.0 (from 1.0-3.0). Max apex 0.80 m, min 0.47 m, flat-ground jump never hard-lands at any safe combination.
- ACs collapsed from 35+ to ~12 groups, each with story-type label + measurement method + threshold + test-evidence path
- Tuning Knobs collapsed from ~44 to 15 designer-facing + Correctness Parameters sidebar
- AC-11 Pillar compliance → replaced with Forbidden Patterns cross-reference (Control Manifest excerpt)

### Phase 5 specialist verification (all returned 2026-04-21)

| Specialist | Verdict | Fixes applied |
|---|---|---|
| godot-specialist | MINOR CONCERNS (no blockers) | NoiseEvent `extends RefCounted` shown; Tween.kill ordering clarified in respawn contract; ShapeCast3D as `@onready` child noted; StringName metadata-type authoring note added to FC OQ-FC-1; coyote-window accumulator interaction noted in FC.E.4 |
| qa-lead | NEEDS MINOR FIXES | AC-9.2 `@if_settings_gdd_exists` → BLOCKED status + `pending()` stub; AC-2.2 parametrized sweep clarified to explicitly name 4 corner cases; AC-FC-5.1 float tolerance named (epsilon 0.001 m); AC-2.1 tolerance widened [0.58, 0.62] → [0.55, 0.65] per game-designer Jolt advisory |
| game-designer | APPROVED FOR /design-review | No revisions required. Three advisory notes captured (AC-2.1 Jolt tolerance applied; FC split discipline via Forbidden Patterns already handled; noise_global_multiplier flagged for producer awareness re: future accessibility — out of scope for this GDD) |

## Persisted artifacts

- **Re-drafted working doc**: `design/gdd/player-character.md` (879 lines, Session F + specialist-verification fixes applied)
- **Sibling doc**: `design/gdd/footstep-component.md` (~480 lines, NEW — R-19 split)
- **Frozen baseline** (read-only, retained for review audit): `design/gdd/player-character-v0.3-frozen.md`
- **Blockers archive**: `production/revision-notes/player-character-blockers-pre-session-f.md` (renamed from `player-character-blockers.md` per scope brief Section 7)
- **Scope brief** (retained): `production/revision-notes/player-character-session-f-redraft-scope.md`
- **Systems index**: `design/gdd/systems-index.md` — Player Character row updated to Session F complete; new FootstepComponent row 8b added

## Status

- ✅ Engine configured: Godot 4.6, GDScript
- ✅ Game concept: `design/gdd/game-concept.md` (The Paris Affair)
- ✅ Art bible complete (9 sections)
- ✅ Systems index: 23 + 1 (FootstepComponent) systems
- ✅ ADRs: 6 authored (0001–0006), all Proposed. No new ADRs required for Session F.
- ⏳ System GDDs: 7/23 Foundation done + **Player Character re-drafted (pending fresh-session /design-review)** + **FootstepComponent new (pending fresh-session /design-review)**
- ⏳ Architecture document: not started
- 🔶 **Downstream still blocked pending re-review**: Stealth AI (System 10), Combat & Damage (11), Inventory & Gadgets (12), HUD Core, Failure & Respawn, Mission Scripting, Document Collection — unblock ONLY after `/design-review` returns APPROVED

## Key files modified in this session (2026-04-21)

- `design/gdd/player-character.md` — Session F re-draft (879 lines, full rewrite) + specialist fixes
- `design/gdd/footstep-component.md` — NEW sibling GDD (R-19 split)
- `design/gdd/systems-index.md` — Player Character status + new FootstepComponent row 8b + Last Updated
- `production/revision-notes/player-character-blockers.md` → renamed to `player-character-blockers-pre-session-f.md`
- `production/session-state/active.md` — this file

## Next steps (fresh session)

**All prior Player Character + FootstepComponent / design-review work is RESOLVED**. PC + FC are APPROVED in systems-index. Stealth AI was authored in the same session (606 lines; 8 sections + Visual/Audio + UI + Open Qs).

1. **Primary**: `/clear` — session carried PC re-draft + full /design-review (7 specialists + CD synthesis) + 21-blocker revision + FC sibling + Stealth AI authoring.
2. **In fresh session**: Run `/design-review design/gdd/stealth-ai.md --depth lean` to validate the graduated-suspicion GDD. Lean depth is sufficient — the authoring pass baked in most concerns the full-depth review would surface.
3. **Alternatives** (can happen in parallel with #2 or next):
   - `/consistency-check` — confirm Stealth AI's values align with the refreshed registry.
   - `/design-system combat-damage` — next MVP system (#11). Closes the Stealth AI forward-dep for guard health + silenced-pistol damage.
   - `/gate-check pre-production` — 9 of 16 MVP GDDs now designed; see if the gate can advance.

## Stealth AI authoring summary (for fresh-session context)

- **Design decisions made (user-approved, 2026-04-21)**:
  - 4 alert states (NOLF1 classic): UNAWARE → SUSPICIOUS → SEARCHING → COMBAT + DEAD terminal
  - Takedowns: melee non-lethal + silenced pistol (lethal)
  - Perception: dual-channel (vision cone + hearing polling at 10 Hz), independent suspicion accumulators
  - Implementation: hand-rolled GDScript state machine + scoring (no behaviour-tree addon at MVP)
  - Overview framing: both data-layer + player-facing (guards are co-stars)
- **Formulas authored**: F.1 sight fill (5 factors), F.2a/b sound fill (continuous + spike), F.3 state-keyed decay, F.4 one-hop propagation, F.5 threshold table (5 thresholds).
- **Forward deps (explicitly documented)**: Combat & Damage (`apply_damage_to_actor`), Inventory & Gadgets (takedown verb), Civilian AI (`civilian_witnessed_event`), Mission Scripting (patrol routes), Dialogue & Subtitles (voice pool), HUD State Signaling (VS-tier alert indicator).
- **Six OQs deferred**: civilian propagation bidirectionality, cover-to-cover pathfinding, cross-section memory, silenced-pistol hearing (Combat & Damage-gated), BT addon post-MVP, ragdoll vs slump poses.
- **Key registry additions**: `phantom_guard` entity; 6 stealth_ai_* constants (propagation radius, 3 thresholds, vision range, FOV).

## Open design questions (active)

All Session F gate questions are CLOSED. Remaining OQs are deferred or awaiting downstream GDDs:

- **OQ-2** Fall damage — deferred to VS
- **OQ-3** Lean system — deferred, revisit after Stealth AI + first playtest
- **OQ-4** Mirror full body mesh — deferred to VS
- **OQ-5** Surface detection method — moved to footstep-component.md
- **OQ-6** Eve verbalizes — deferred, narrative dep
- **OQ-FC-1** Surface metadata authoring workflow — deferred, Level Streaming dep
- **OQ-FC-2** Noise level sampling timing — deferred, Audio playtest dep
- **OQ-FC-3** FC execution order vs PC state — deferred, playtest dep
- **OQ-FC-4** Non-player footstep sources — deferred, Stealth AI dep
- **(Advisory — from game-designer Session F verification)** `noise_global_multiplier` as accessibility lever post-MVP: flag for producer awareness; not a GDD change

## Specialist verification artifacts

- godot-specialist report (MINOR CONCERNS): received 2026-04-21, fixes applied
- qa-lead report (NEEDS MINOR FIXES): received 2026-04-21, all 3 concerns fixed
- game-designer report (APPROVED FOR /design-review): received 2026-04-21, advisory items applied

(Full reports in conversation history of session that authored the re-draft — not persisted to files since they are verification artifacts, not authoritative specs.)
