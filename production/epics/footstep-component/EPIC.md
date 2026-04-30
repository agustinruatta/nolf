# Epic: FootstepComponent

> **Layer**: Core (sibling of Player Character per `architecture.md` §3.2 — has its own GDD, TR-FC-* namespace, and is a distinct publisher of `Events.player_footstep`)
> **GDD**: `design/gdd/footstep-component.md`
> **Architecture Module**: FootstepComponent — child node of PlayerCharacter (`architecture.md` §3.2)
> **Engine Risk**: LOW (Object.get_meta/set_meta stable since 4.0; `PhysicsRayQueryParameters3D` stable; `_physics_process` cadence)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories footstep-component`
> **Manifest Version**: 2026-04-30

## Overview

FootstepComponent is a Core-layer module that lives as a child node of `PlayerCharacter` and owns the **step cadence state machine** + **surface tag lookup** for *The Paris Affair*'s footstep audio system. It runs three step rates (Walk 2.2 Hz / Sprint 3.0 Hz / Crouch 1.6 Hz) with a phase-preservation accumulator (so transitions between movement states don't reset cadence mid-stride). On each step, it casts a downward ray to detect the surface body, reads `body.get_meta("surface_tag", &"default")` (CR-10 from Level Streaming GDD — surface metadata authoring contract), and emits `Events.player_footstep(surface: StringName, noise_radius_m: float)`.

The component is the single canonical source of `Events.player_footstep` per ADR-0002 — Audio subscribes for SFX, Stealth AI subscribes for noise-based perception. It's intentionally split from PlayerCharacter to maintain the "PC owns AI noise channel (`get_noise_event`); FC owns Audio channel (`player_footstep`)" seam established at PC GDD approval (2026-04-21).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | FootstepComponent is sole publisher of `Events.player_footstep(surface: StringName, noise_radius_m: float)`; Audio + Stealth AI subscribe | LOW |
| ADR-0006: Collision Layer Contract | Downward raycast on `MASK_FOOTSTEP_SURFACE`; Player Character collision layer contract for `is_on_floor()` semantics | LOW |
| ADR-0008: Performance Budget Distribution | FootstepComponent budget rolled into Slot 1 (Player Character + FC combined ≤2 ms/frame); raycast cost amortized at 1.6–3.0 Hz (not per-frame) | LOW |

**Cross-reference**: Surface metadata authoring contract is owned by Level Streaming GDD CR-10 (`set_meta("surface_tag", StringName)` on every `StaticBody3D` Eve can stand on; Tools Programmer plugin at `res://addons/surface_tagger/` mass-assigns; headless validator). FootstepComponent CONSUMES this vocabulary at runtime; LSS Story 008 ships the authoring contract on stub plaza.tscn / stub_b.tscn Floor StaticBody3Ds.

## GDD Requirements

The `footstep-component.md` GDD specifies:

- Step cadence state machine: 3 rates (Walk 2.2 Hz, Sprint 3.0 Hz, Crouch 1.6 Hz); rate changes on parent CharacterBody3D state transition
- Phase-preservation accumulator: when state changes mid-stride, the next step fires at the new rate's phase relative to the prior rate's accumulated time (NOT a hard reset to 0)
- Per-step downward ray: `PhysicsRayQueryParameters3D` from PC origin downward, mask = `MASK_FOOTSTEP_SURFACE`; reads `body.get_meta("surface_tag", &"default")` on hit
- Per-step noise radius derived from cadence rate + parent's `get_noise_level()` (sprint > walk > crouch)
- Emits `Events.player_footstep(surface: StringName, noise_radius_m: float)` on each step
- Suppression rules: no emit when `is_on_floor() == false` (jumping/falling); no emit during DEAD state
- Multi-shape body limitation: `set_meta` lives on body, not per-shape — split bodies at authoring time OR accept dominant-material wins (per LSS GDD CR-10)
- Area3D volume override: when an Area3D with `surface_tag` overlaps the player, that tag wins over body meta (e.g., wet carpet, puddle zones); FC checks `get_overlapping_areas()` before falling back to body meta

Specific requirement IDs `TR-FC-001` through `TR-FC-005` (5 TRs) are in `docs/architecture/tr-registry.yaml`.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/footstep-component.md` are verified.
- `FootstepComponent` script exists at `src/gameplay/player/footstep_component.gd` (or sibling location aligned with PlayerCharacter scene structure).
- Step cadence state machine: 3 rates with phase-preservation accumulator; integration test covers Walk → Sprint → Crouch cadence transitions without a hard phase reset.
- Surface tag lookup: downward raycast + `body.get_meta("surface_tag")` works on stub plaza/stub_b Floor (Level Streaming Story 008's authoring); Area3D override logic correctly prioritizes overlap tag over body tag.
- `Events.player_footstep(surface, noise_radius_m)` fires at the correct cadence; signal-spy verifies for each rate.
- Suppression in jump/fall/dead states verified.
- Logic stories have passing unit tests; integration stories cover at least one full Walk → Sprint → Jump → Fall → Walk cadence cycle.

## Verification Spike Status (Sprint 01, 2026-04-29)

ADR-0006 fully Accepted; `MASK_FOOTSTEP_SURFACE` constant defined in `src/core/physics_layers.gd`. ADR-0002 fully Accepted; `Events.player_footstep` declared as part of the production signal taxonomy (lands incrementally as consumer epics are implemented per ADR-0002 §Skeleton Status). No FC-specific verification spike was required — surface metadata authoring contract was verified via Level Streaming GDD §CR-10 + Tools Programmer plugin scope.

## Next Step

Run `/create-stories footstep-component` to break this epic into implementable stories.
