# Epic: Stealth AI

> **Layer**: Feature
> **GDD**: `design/gdd/stealth-ai.md`
> **Architecture Module**: Stealth AI (per-section scene-tree NPCs — `CharacterBody3D` + `NavigationAgent3D` + perception/state components; NOT autoload per ADR-0007)
> **Engine Risk**: MEDIUM (`NavigationAgent3D` 4.6 changes; raycast cache pattern; Jolt physics interaction)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories stealth-ai`
> **Manifest Version**: 2026-04-30

## Overview

Stealth AI is *The Paris Affair*'s **graduated-suspicion engine** — the system that makes stealth feel theatrical (Pillar 3) rather than punitive — plus the **NPC guard archetype** the player outwits. The engine consumes Player Character's perception surface (`get_noise_level()`, `get_silhouette_height()`, `global_transform.origin`), runs dual-channel perception (vision cone + 10 Hz hearing poll with occlusion/distance modifiers), and drives each guard through a six-state alert lattice: **UNAWARE → SUSPICIOUS → SEARCHING → COMBAT** plus terminal **UNCONSCIOUS** (non-lethal KO with wake-up clock) and **DEAD** (lethal). All three non-combat transitions are fully reversible — losing a cue returns the guard to UNAWARE (Pillar 3: "Stealth is Theatre, Not Punishment").

Guards are scene-tree NPCs (per ADR-0007 — not autoload). They publish six SAI-domain signals through `Events` per ADR-0002 (`alert_state_changed`, `actor_became_alerted`, `actor_lost_target`, `takedown_performed`, `guard_incapacitated`, `guard_woke_up`). Audio subscribes for music ducking + stingers; Mission Scripting subscribes for objective triggers; Civilian AI subscribes for secondary-observer behaviour; Dialogue & Subtitles subscribes for guard banter. Stealth AI claims a dedicated slot in the ADR-0008 performance budget.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Stencil ID Contract | Guards = **Tier 2 (medium, 3 px @ 1080p)** outline weight; stencil written by guard mesh stencil_mode | LOW |
| ADR-0002: Signal Bus + Event Taxonomy | Six SAI-domain signals (frozen post-amendment for `guard_incapacitated`, `guard_woke_up`); enums (`AlertState`, `Severity`, `AlertCause`, `TakedownType`) live on `StealthAI` class, never on `Events.gd` | LOW |
| ADR-0006: Collision Layer Contract | Guards on `LAYER_NPCS`; perception raycasts query `LAYER_WORLD` + `LAYER_PLAYER`; vision Area3D on `LAYER_PERCEPTION` | LOW |
| ADR-0008: Performance Budget Distribution | Stealth AI claims a dedicated slot in the 16.6 ms frame budget — perception polling, navigation, state machine combined ceiling per ADR-0008 | MEDIUM (Proposed — pending hardware measurement; perception cache + 10 Hz polling already prototyped in Sprint 01) |

## GDD Requirements

**18 TR-IDs** in `tr-registry.yaml` (`TR-SAI-001` .. `TR-SAI-018`) cover:

- Guard NPC node hierarchy (`CharacterBody3D` + `NavigationAgent3D` + perception/state components)
- Six-state alert state machine + transition table (19 edges including wake-up edge)
- Six SAI-domain signals + four enum types (`AlertState`, `Severity`, `AlertCause`, `TakedownType`)
- F.1 Sight fill formula (range linear falloff to 18 m; state multipliers; body factor)
- F.2 Sound fill formula (10 Hz poll, occlusion raycast, elevation factor)
- F.3 Per-state accumulator decay
- F.4 Alert propagation (`ALERT_PROPAGATION_RADIUS_M = 25` m, `PROPAGATION_BUMP = 0.4`)
- F.5 State-transition thresholds (`T_SUSPICIOUS = 0.3`, `T_SEARCHING = 0.6`, `T_COMBAT = 0.95`)
- `RaycastProvider` DI interface (perception accepts `IRaycastProvider` at init for testability)
- `WAKE_UP_SEC = 45` UNCONSCIOUS → SUSPICIOUS recovery clock
- Save/Load integration (per-actor `actor_id: StringName`, patrol state serialisation per ADR-0003)
- Forbidden-pattern fences (no SAI subscription to `player_footstep`; no `Events.gd` enum coupling)

Full requirement text: `docs/architecture/tr-registry.yaml` Stealth AI section.

## VS Scope Guidance (for `/create-stories`)

The Vertical Slice exercises this system at **minimum viable depth** to validate the architecture:
- **Include**: 1 Plaza guard with `CharacterBody3D` + `NavigationAgent3D` patrol; UNAWARE → SUSPICIOUS → COMBAT subset of state machine; F.1 sight fill + F.5 thresholds; one `alert_state_changed` signal subscriber (Audio stinger).
- **Defer post-VS**: F.4 alert propagation between guards (no second guard in VS); UNCONSCIOUS + wake-up clock (no chloroform gadget in VS — see Inventory deferral); `SAW_BODY` 2× multiplier (no body to find); patrol-state save serialisation (1 guard at known-mid-patrol-point on load is acceptable).

Story authors: split TR-IDs into VS-required vs. post-VS-deferred lists in story metadata.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- All `design/gdd/stealth-ai.md` acceptance criteria verified (or explicitly deferred with rationale).
- One Plaza guard demonstrably patrols, detects Eve via vision cone, transitions UNAWARE → SUSPICIOUS → COMBAT, fires `alert_state_changed` audibly.
- Six SAI-domain signals declared on `Events.gd` per ADR-0002; signal payload contracts verified via integration test.
- Forbidden-pattern fences registered (`sai_subscribing_to_player_footstep`, `events_with_state_or_methods` for SAI enums).
- Logic stories (state machine, F.1/F.2/F.5 formulas, accumulator decay) have passing unit tests in `tests/unit/feature/stealth_ai/`; integration stories in `tests/integration/feature/stealth_ai/`.
- Evidence doc with screenshot + sign-off for "guard sees Eve and transitions to COMBAT" beat in `production/qa/evidence/`.

## Stories

Not yet created. Run `/create-stories stealth-ai` (with VS-narrowed scope flag) to break this epic into implementable stories.
