# Epic: Player Character

> **Layer**: Core (per `architecture.md` §3.2)
> **GDD**: `design/gdd/player-character.md`
> **Architecture Module**: Player Character — `PlayerCharacter` scene root (`CharacterBody3D`) (`architecture.md` §3.2)
> **Engine Risk**: MEDIUM (Jolt physics 4.6 default; `material_overlay` slot for FPS hands outline; `SubViewport` FOV 55° for hands rendering)
> **Status**: Ready (with note: governing ADR-0005 + ADR-0008 are Proposed — Gates 1+2 closed; gates 3, 4, 5 require this epic's hands rendering production story to close — chicken-and-egg by design)
> **Stories**: Not yet created — run `/create-stories player-character`
> **Manifest Version**: 2026-04-30

## Overview

Player Character is the Core-layer module that implements **Eve Sterling** (BQA field agent, 1965): a `CharacterBody3D` scene root with a `CapsuleShape3D` collider (1.7 m standing / 1.1 m crouched), a movement state machine (IDLE / WALK / SPRINT / CROUCH / JUMP / FALL / DEAD), health 0–100 (100 default), `apply_damage(amount, source, type)` as the ONLY health mutator, `reset_for_respawn(checkpoint)` as the ordered-reset API, an interact raycast (2.0 m, priority 0–3), a `NoiseEvent` spike-latch driving `get_noise_event()` for Stealth AI perception, and the FPS hands outline rendering via `material_overlay` (ADR-0005 exception to ADR-0001's stencil pipeline — first-person hands need a different rendering path than world geometry).

The system is the gameplay-anchor — it consumes Input (via the GAMEPLAY context), publishes `player_damaged` / `player_died` / `player_health_changed` / `player_interacted` signals, and provides the `get_noise_level() -> float` accessor that FootstepComponent and Stealth AI both query. Movement runs on Jolt physics (Godot 4.6 default) at 60 Hz via `_physics_process`; movement uses `velocity + move_and_slide()` per ADR-0006's collision layer contract.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: FPS Hands Outline Rendering | First-person hands use `material_overlay` slot for outline rendering — explicit exception to ADR-0001's stencil pipeline (which targets world geometry). Inverted-hull capsule outline shader. SubViewport FOV 55° for hands rendering. | MEDIUM |
| ADR-0006: Collision Layer Contract | `LAYER_PLAYER = 1`, masks per `MASK_*` constants in `src/core/physics_layers.gd`. Player's CharacterBody3D collision_layer/mask use the constants (no bare integer literals). Interact raycast on `MASK_INTERACT`; downward floor check on `MASK_FOOTSTEP_SURFACE`. | LOW |
| ADR-0008: Performance Budget Distribution | Player Character at Slot 1 (combined CPU + physics budget). Movement state machine + `_physics_process` ≤2 ms/frame; interact raycast amortized via priority cache. | MEDIUM |
| ADR-0002: Signal Bus + Event Taxonomy | Owns Player domain signals: `player_damaged`, `player_died`, `player_health_changed`, `player_interacted`, `player_footstep` (delegated to FootstepComponent epic) | LOW |
| ADR-0007: Autoload Load Order Registry | Player Character is a scene-rooted node, NOT an autoload. Consumes autoloads `Events`, `InputContext`, `Combat` (line 7) for damage routing | LOW |

**Status note**: ADR-0005 is `Proposed` — Gate 1 (inverted-hull outline rendering on Linux Vulkan) and Gate 2 (D3D12 closed by removal — single-Vulkan target per ADR-0001 A2) are CLOSED. Gates 3 (resolution-scale toggle), 4 (animated rigged hand mesh), 5 (Shader Baker × `material_overlay`) are PRODUCTION-SCOPE — they close via this epic's hands rendering production story (chicken-and-egg by design per ADR-0005). Stories that require gates 3-5 will be marked Blocked until paired ADR amendment lands; structural Player Character stories (movement, health, interact, NoiseEvent) proceed without ADR-0005 dependency.

ADR-0008 is `Proposed` — slot allocations + autoload-cascade row count fixed via 2026-04-28 amendments; architectural decision unchanged. Stories proceed against the slot-1 PC budget (steady-state 0.55 ms target, 0.25 ms margin).

## GDD Requirements

The `player-character.md` GDD specifies:

- `CharacterBody3D` root with `CapsuleShape3D` (1.7 m standing / 1.1 m crouched)
- Movement state machine: 7 states (IDLE / WALK / SPRINT / CROUCH / JUMP / FALL / DEAD); transitions via `_physics_process` + input + collision detection
- Health 0–100; `apply_damage(amount, source, damage_type) -> bool died` is the SOLE mutator; `reset_for_respawn(checkpoint)` ordered-reset (position → state → health → noise → outline → camera)
- Interact raycast 2.0 m, priority 0-3 (cached per-frame)
- `NoiseEvent` spike-latch: `get_noise_level() -> float` returns current noise (sprint > walk > crouch > idle); `get_noise_event() -> NoiseEvent` returns latched event for Stealth AI perception
- FPS hands rendering via `SubViewport` (FOV 55°) + `material_overlay` slot (ADR-0005 exception)
- Save state: `PlayerState` Resource with `position: Vector3`, `rotation: Vector3`, `health: int`, `current_state: int` (MovementState enum value)
- Forbidden patterns: `health_mutation_outside_apply_damage` (only `apply_damage` may modify health); `direct_position_assignment_during_respawn` (use `reset_for_respawn` ordered API)

Specific requirement IDs `TR-PC-001` through `TR-PC-024` (24 TRs) are in `docs/architecture/tr-registry.yaml`.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/player-character.md` are verified.
- `PlayerCharacter` scene root exists at `res://src/gameplay/player/player_character.tscn` with `CharacterBody3D` root + the documented child node hierarchy.
- Movement state machine: 7 states + canonical transitions; integration test covers IDLE → WALK → SPRINT → JUMP → FALL → IDLE round-trip.
- `apply_damage(amount, source, type)` is the only health mutator (verifiable by lint); on `health <= 0` emits `player_died` exactly once.
- `reset_for_respawn(checkpoint)` is ordered (position → state → health → noise → outline → camera); used by Failure & Respawn epic's death-respawn path.
- `get_noise_level()` returns float; `get_noise_event()` returns latched NoiseEvent; FootstepComponent + Stealth AI consume these.
- Interact raycast 2.0 m at priority 0–3 cached per `_physics_process` frame; `player_interacted` signal fires on completed interaction.
- FPS hands SubViewport + `material_overlay` outline material attached (closes ADR-0005 G3, G4, G5 via paired amendment).
- Collision layer/mask use `PhysicsLayers.*` constants (ADR-0006); zero bare integer literals.
- Logic stories have passing unit tests; integration stories cover Input → movement, damage → die, respawn → reset.

## Verification Spike Status (Sprint 01, 2026-04-29)

ADR-0005 G1 (inverted-hull capsule outline on Linux Vulkan) PASSED via `prototypes/verification-spike/fps_hands_demo.tscn`. ADR-0006 fully Accepted (collision layer constants + project.godot layer_names verified end-to-end). ADR-0001 fully Accepted. The PlayerCharacter scaffold has not yet been created; this epic's stories will create it from scratch following the GDD + ADR-0005 hands rendering contract.

## Next Step

Run `/create-stories player-character` to break this epic into implementable stories.
