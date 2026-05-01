# Player System (`src/gameplay/player/`)

> **Status**: Reference Index — derived from approved sibling GDDs (Player Character, FootstepComponent). No new design introduced.
> **Author**: `/project-stage-detect` polish pass (reverse-doc from existing implementation)
> **Last Updated**: 2026-05-01
> **Last Verified**: 2026-05-01
> **Implements Pillar**: 1 (Comedy Without Punchlines), 3 (Stealth is Theatre), 5 (Period Authenticity) — via sibling GDDs
> **Type**: Umbrella system index — maps every file under `src/gameplay/player/` to its owning detailed GDD and codifies the directory's outward boundary contract.

## Overview

The Player System is the directory-scoped umbrella covering every file under `src/gameplay/player/` (5 files: `player_character.gd` + `PlayerCharacter.tscn` + `footstep_component.gd` + `player_enums.gd` + `noise_event.gd`). Two primary domain GDDs already own the detailed mechanics — **Player Character** (Eve Sterling's locomotion, camera, interact, health, hands) and **FootstepComponent** (cadenced footstep emission). This document exists as a navigation index for new contributors and as the system-level boundary contract — what the directory exposes to the rest of the codebase, which detailed GDD owns each rule, and which support types live here without a dedicated GDD. **No new mechanics, formulas, or tuning knobs are introduced in this file.**

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Effort: tracked per sibling GDD · Files: 5

## Player Fantasy

The Player System's fantasy is owned by `design/gdd/player-character.md` §Player Fantasy ("The Deadpan Witness" — Eve Sterling). FootstepComponent's audio cadence is the kinesthetic surface of that fantasy; it does not introduce its own fantasy beat. See:

- `design/gdd/player-character.md` §Player Fantasy — Eve's deadpan-witness framing
- `design/gdd/footstep-component.md` §Player Fantasy — cadence as audible signature

This file does not duplicate that copy.

## Detailed Rules

### File-to-GDD mapping

| File | Owning GDD | Section anchor |
|---|---|---|
| `player_character.gd` | `player-character.md` | All sections |
| `PlayerCharacter.tscn` | `player-character.md` | §Detailed Design Core Rules — Node hierarchy + camera rotation |
| `footstep_component.gd` | `footstep-component.md` | All sections |
| `player_enums.gd` | `player-character.md` | §Detailed Design Core Rules — Enums (`PlayerEnums.MovementState`, `PlayerEnums.NoiseType`) |
| `noise_event.gd` | `player-character.md` | §Detailed Design Core Rules — NoiseEvent + §F.4 |

### System boundary contract

The Player System exposes the following surface to the rest of the codebase:

**Signals (publishers)** — see ADR-0002 §Implementation Guideline 5 (sole-publisher rule):

| Signal | Publisher file | Owning GDD |
|---|---|---|
| `player_damaged` | `player_character.gd` | `player-character.md` |
| `player_died` | `player_character.gd` | `player-character.md` |
| `player_health_changed` | `player_character.gd` | `player-character.md` |
| `player_interacted` | `player_character.gd` | `player-character.md` |
| `player_footstep` | `footstep_component.gd` | `footstep-component.md` |

**Pull accessors** — read by Stealth AI, Combat, Inventory, etc.:

| Method | Owning GDD | Caller |
|---|---|---|
| `PlayerCharacter.get_noise_level() -> float` | `player-character.md` §F.4 | Stealth AI scalar perception, FootstepComponent noise mirror |
| `PlayerCharacter.get_noise_event() -> NoiseEvent` | `player-character.md` §F.4 | Stealth AI latched-spike perception |
| `PlayerCharacter.get_silhouette_height() -> float` | `player-character.md` §F.8 | Stealth AI sight-cone test |

**Save/Load** — `PlayerState` sub-resource per ADR-0003. Field schema owned by `player-character.md` §State serialization.

**Forbidden inbound dependencies** — Stealth AI MUST NOT subscribe to `player_footstep` (Stealth AI GDD §Forbidden Patterns + FootstepComponent GDD R-19). Stealth AI consumes player noise exclusively via the pull accessors above. The grep rule lives in AC-PS-3 below.

### Support types (no dedicated GDD)

Two RefCounted helper types live in this directory without their own GDD. They are intentional architectural primitives, not orphan code:

- **`PlayerEnums`** (`player_enums.gd`) — pure enum host (`MovementState`, `NoiseType`). It exists to break the circular parse dependency that would otherwise form if `NoiseEvent.type` were typed `PlayerCharacter.NoiseType` (NoiseEvent → PlayerCharacter → NoiseEvent). ADR-0002 IG 2 forbids non-signal types on `Events.gd`, and the project intentionally has no shared `Types.gd`. `PlayerEnums` is the cycle-break. **Do not consolidate** these enums onto `PlayerCharacter` thinking the host file is dead code — see EC-PS-1.
- **`NoiseEvent`** (`noise_event.gd`) — lightweight value object returned by `get_noise_event()`. `RefCounted`, NOT `Resource`: the Resource allocator overhead at 80 Hz aggregate AI polling is unacceptable, and `NoiseEvent` is ephemeral runtime data never persisted to disk. PlayerCharacter reuses a single `NoiseEvent` instance and mutates fields in place — callers that need to remember a spike MUST copy `{type, radius_m, origin}` before the next physics frame. The reference-retention footgun is documented at the mutation site in `player_character.gd` and in `player-character.md` §F.4.

Both types are defined inline in `player-character.md` §Detailed Design Core Rules; this file references those definitions without duplicating them.

## Formulas

No formulas owned at the system level. All player-domain math lives in:

- `player-character.md` §Formulas — F.1 (planar velocity), F.2 (vertical motion), F.3 (landing scaling), F.4 (noise propagation), F.5 (interact priority), F.6 (camera overshoot), F.7 (crouch transition), F.8 (silhouette height)
- `footstep-component.md` §Formulas — FC.1 (phase-preserving cadence accumulator), FC.3 (noise mirror)

This file does not redeclare or alias any of the above.

## Edge Cases

System-level edges only — **mechanic edges live in the sibling GDDs**:

- **EC-PS-1: `PlayerEnums` file removed or renamed.** Both `noise_event.gd` and `player_character.gd` fail to parse. The class is a load-bearing parse-cycle break. **Resolution:** parse-error surface in editor → restore from git history. Do not "consolidate" the enums onto `PlayerCharacter` as a fix.
- **EC-PS-2: `FootstepComponent` re-parented away from `PlayerCharacter`.** FC asserts in `_ready()` that its parent is `PlayerCharacter`; assertion failure flips `_is_disabled = true`, all `_physics_process` ticks become no-ops, and one `push_error` is logged. No null-deref cascade. **Resolution:** in `PlayerCharacter.tscn`, `FootstepComponent` must be a direct child of the `PlayerCharacter` root. See `footstep-component.md` AC-FC-6.1.
- **EC-PS-3: `Events.player_footstep` subscribed by AI.** Forbidden by ADR-0002, Stealth AI GDD §Forbidden Patterns, and FootstepComponent GDD R-19. **Resolution:** AC-PS-3 grep rule below; CI gate.
- **EC-PS-4: `NoiseEvent` reference retained across physics frames.** Caller MUST copy fields before the next frame (in-place mutation contract). **Resolution:** documented at the mutation site in `player_character.gd`; AC documented in `player-character.md` §F.4 and AC-3.5.
- **EC-PS-5: New publisher of a player-domain signal added outside this directory.** Violates ADR-0002 IG 5 (sole publisher per signal). **Resolution:** AC-PS-4 file-scope grep gate below.

## Dependencies

System-level inbound dependencies (other systems consume the Player System):

| Consumer | Channel | Purpose |
|---|---|---|
| Stealth AI | `get_noise_level` / `get_noise_event` (pull) + `get_silhouette_height` | Perception scalar + spike + sight-cone |
| Combat & Damage | `player_damaged` / `player_died` signals + `receive_damage(...)` API | Damage application |
| Inventory & Gadgets | `HandAnchor` node + `player_interacted` signal | Held-item attachment + interact triggers |
| Document Collection | `player_interacted` signal + interact raycast result | Pickup trigger |
| Mission & Level Scripting | Player position read (no direct API) | Trigger volume tests |
| HUD Core | `player_health_changed` signal | Health readout |
| FootstepComponent | parent reference + `get_noise_level()` | Sole publisher of `player_footstep` |
| Save/Load | `PlayerState` sub-resource (ADR-0003) | Persistence |

System-level outbound dependencies (the Player System consumes):

| Provider | Channel | Purpose |
|---|---|---|
| Input GDD | action mappings (`move_*`, `look_*`, `interact`, `jump`, `crouch`, `sprint`) | All player actions |
| Settings & Accessibility | mouse + gamepad sensitivities | Camera input scaling |
| Outline Pipeline / ADR-0005 | hands `SubViewport` outline (inverted-hull exception) | First-person hand rendering |
| ADR-0001 | rendering pipeline + stencil ID contract | Outline contract |
| ADR-0002 | Signal Bus (5 published signals + sole-publisher rule) | Cross-system events |
| ADR-0003 | Save Format Contract | `PlayerState` sub-resource schema |
| ADR-0006 | Collision Layer Contract | `PhysicsLayers.MASK_*` constants |

Bidirectional cross-references: every consumer above lists the Player System (or its sibling GDDs) as a dependency in their own GDD's §Dependencies section. Verified per design-docs rule "Dependencies must be bidirectional".

## Tuning Knobs

No tuning knobs owned at the system level. Knob ownership:

- **Movement, camera, jump, noise, interact, health** → `player-character.md` §Tuning Knobs (Walk speed 3.5 m/s, Sprint speed 5.5 m/s, Crouch speed 1.8 m/s, gravity 12.0 m/s², jump_velocity 3.8 m/s, noise radii Walk 5 m / Sprint 12 m / Crouch 3 m, idle_velocity_threshold 0.1 m/s, interact_max_range, etc.)
- **Footstep cadence + raycast depth** → `footstep-component.md` §Tuning Knobs (cadence_walk_hz 2.2, cadence_sprint_hz 3.0, cadence_crouch_hz 1.6, surface_raycast_depth_m 2.0)

This file does not redeclare or alias any of the above.

## Acceptance Criteria

System-level invariants — **mechanic-level ACs live in the sibling GDDs**:

- **AC-PS-1 (file presence):** All five files exist at `src/gameplay/player/`: `player_character.gd`, `PlayerCharacter.tscn`, `footstep_component.gd`, `player_enums.gd`, `noise_event.gd`. Verifiable via directory listing.
- **AC-PS-2 (scene wiring):** `PlayerCharacter.tscn` contains a `FootstepComponent` node as a direct child of the root `PlayerCharacter` node. Verifiable by parsing the `.tscn` text for the parent-path declaration.
- **AC-PS-3 (forbidden subscriber grep):** No file outside `src/gameplay/player/` contains `Events.player_footstep.connect(`. Stealth AI must consume player noise via the pull accessors only. Verifiable: `grep -r "Events.player_footstep.connect" src/ | grep -v "src/gameplay/player/"` returns empty.
- **AC-PS-4 (sole-publisher invariant):** `player_damaged`, `player_died`, `player_health_changed`, `player_interacted`, `player_footstep` are emitted only from files under `src/gameplay/player/`. Verifiable: `grep -rn "Events\.<signal>\.emit" src/` returns hits only inside this directory. ADR-0002 IG 5 contract.
- **AC-PS-5 (cross-doc reference integrity):** Every "see player-character.md §X" or "see footstep-component.md §X" reference in this file resolves to an existing section heading in the named GDD. Verifiable via doc-link audit.

---

## References

- `design/gdd/player-character.md` — owning GDD for `player_character.gd`, `PlayerCharacter.tscn`, `player_enums.gd`, `noise_event.gd`
- `design/gdd/footstep-component.md` — owning GDD for `footstep_component.gd`
- `design/gdd/player-character-v0.3-frozen.md` — frozen review baseline (read-only; do not edit)
- `design/gdd/systems-index.md` — row 8 (Player Character) + row 8b (FootstepComponent)
- `docs/architecture/adr-0001-stencil-id-contract.md` — Rendering / stencil ID contract
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — Signal authorship + sole-publisher rule
- `docs/architecture/adr-0003-save-format-contract.md` — `PlayerState` sub-resource schema
- `docs/architecture/adr-0005-fps-hands-outline-rendering.md` — Hands outline (inverted-hull exception)
- `docs/architecture/adr-0006-collision-layer-contract.md` — `PhysicsLayers.MASK_*` constants
