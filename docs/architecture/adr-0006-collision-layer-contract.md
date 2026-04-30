# ADR-0006: Collision Layer Contract

## Status

**Accepted** — promoted 2026-04-29 after Sprint 01 Technical Verification Spike: (1) ✅ `res://src/core/physics_layers.gd` exists with all 5 `LAYER_*` constants, all 5 `MASK_*` constants, and 5 composite masks (Group 1.1 — verbatim per §Key Interfaces); (2) ✅ `project.godot` `[layer_names]/3d_physics/layer_1..5` populated to match constant names (Group 1.2 — preserved through Godot 4.6 editor save); (3) ✅ end-to-end gameplay-style usage of `PhysicsLayers.*` constants verified via `prototypes/verification-spike/collision_migration_check.gd` (Group 2.3 headless run, all 6 checks PASS — `set_collision_layer_value` / `set_collision_mask_value` / direct mask assignment / composite masks / `PhysicsRayQueryParameters3D.collision_mask` all consume the constants without bare integer literals). Verification log: `prototypes/verification-spike/verification-log.md`. No findings; ADR text needed no amendment.

## Date

2026-04-19

## Last Verified

2026-04-29 (Sprint 01 Technical Verification Spike — all 3 verification gates PASS; Status flipped Proposed → Accepted; see Revision History entry below). Prior: 2026-04-23 (Amendment A6: Risks table gained a row for Jolt `Area3D.body_entered` broadphase tunneling of fast-moving bodies — e.g., Combat darts at 20 m/s on `LAYER_PROJECTILES` — per godot-specialist 2026-04-22 §7; mitigation folded into Combat GDD OQ-CD-2 Jolt prototype scope)

## Decision Makers

User (project owner) · systems-designer (layer schema validation) · godot-specialist (API validation) · `/architecture-decision` skill (via Session B of `/design-system player-character` revision; review finding R-18)

## Summary

All collision-layer and collision-mask assignments in *The Paris Affair* reference named constants from a single-source-of-truth GDScript static class (`PhysicsLayers` in `res://src/core/physics_layers.gd`). Five project-wide layers are defined: **1 World · 2 Player · 3 AI · 4 Interactables · 5 Projectiles**. Every gameplay system MUST import and use the constants; hardcoded integer layer indices in gameplay code are a forbidden pattern. The `project.godot` named-layer slots are populated to match, so the editor inspector shows meaningful names alongside raw bit indices. Composite masks (e.g., `MASK_AI_VISION_OCCLUDERS`) are precomputed on the class to keep call sites readable and to centralize compositional layer decisions.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics / Core |
| **Knowledge Risk** | LOW — `CollisionObject3D.collision_layer` / `collision_mask` + `set_collision_layer_value(index, bool)` / `set_collision_mask_value(index, bool)` helpers have been stable since Godot 4.0. Project-settings layer-name registration (`layer_names/3d_physics/layer_N`) is also stable. Godot 4.6 default physics (Jolt 3D, pinned by `technical-preferences.md`) honors the same layer bitmask contract as GodotPhysics 3D. No post-cutoff APIs are load-bearing. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/physics.md` (if present), `.claude/docs/technical-preferences.md`, Player Character GDD (layer usage), `design/gdd/reviews/player-character-review-2026-04-19.md` (R-18) |
| **Post-Cutoff APIs Used** | None. Jolt 3D (4.4 option, 4.6 default) uses the same collision-layer API as GodotPhysics. |
| **Verification Required** | (1) `PhysicsLayers` class compiles and can be referenced from any gameplay script. (2) `project.godot` has named 3D physics layer slots populated. (3) A real gameplay file (e.g., `player_character.gd` when it lands) uses the constants end-to-end; a grep for bare `collision_layer = N` / `collision_mask = N` in `src/gameplay/` returns zero hits. |

> **Note**: LOW Knowledge Risk. This contract sits entirely in well-documented, stable Godot 4.0+ territory.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — foundational. |
| **Enables** | Every gameplay system that uses physics: Player Character, Stealth AI, Combat & Damage, Inventory & Gadgets (projectiles + raycast pickups), Civilian AI, Mission & Level Scripting (trigger volumes), Document Collection (interact raycasts), Failure & Respawn (respawn collision resets). |
| **Blocks** | No system is strictly blocked by the ABSENCE of this ADR (each system could hardcode layer numbers), but every system authored before this ADR is Accepted must be audited and migrated to `PhysicsLayers` constants afterwards. It is cheaper to accept this ADR first and author systems against the constants from the start. |
| **Ordering Note** | Drafted during Session B of the Player Character GDD revision (2026-04-19) to resolve review finding R-18. Sibling-level to ADR-0001/0002/0003/0004/0005. Does not conflict with any existing ADR. |

## Context

### Problem Statement

The Player Character GDD (Core Rules rule 5) defines five collision layers in prose: Layer 1 (World), Layer 2 (Player), Layer 3 (AI), Layer 4 (Interactables), Layer 5 (Projectiles). This assignment is also referenced in `design/registry/entities.yaml` and (implicitly) in every future system GDD that reads, writes, or raycasts against these layers.

Without a central source of truth:

1. **Schema drift** — Stealth AI GDD might reasonably assume Layer 3 = "AI" and cast against `1 << 2` = 4. Combat & Damage GDD might then call projectiles Layer 5 (`1 << 4` = 16). But some other system might quietly introduce "Layer 6 = Hazards" or silently treat "Layer 3" as "Interactables" because nobody reviewed the index. Drift is quiet — it only surfaces as a physics bug at runtime, usually expressed as "raycast hits nothing" or "player walks through guard."
2. **Hardcoded magic numbers** — gameplay code will say `set_collision_mask_value(4, true)` without naming the layer. Reviewers cannot tell at a glance whether the intent is "cast against Interactables" or "cast against some other layer 4 we introduced later." Renaming a layer becomes a grep-and-pray exercise across the entire codebase.
3. **Editor inspector is illegible** — without named layer slots in `project.godot`, the inspector shows "Layer 1 / Layer 2 / …" with no hint of which is which. Scene authors guess.
4. **Adding Layer 6 later** — adding a new layer requires updating every GDD and every script that compositionally depends on "the current layer set." Without a single source, omissions are silent bugs.

Review finding R-18 (design-review 2026-04-19) flagged this explicitly: "Layers 1–5 live in prose in this GDD and in `entities.yaml`. Adding Layer 6 later requires manual updates across every GDD and script." The reviewer recommended mandating `res://src/core/physics_layers.gd` as the single source of truth.

### Current State

- Project is in pre-production. No gameplay source code exists yet.
- The Player Character GDD Core Rules rule 5 enumerates Layers 1–5 in prose.
- `design/registry/entities.yaml` references some of these layer numbers (PlayerCharacter is on Layer 2, etc.).
- `project.godot` does not have named 3D physics layer slots populated — slots are blank.
- No other GDDs have been authored that reference layer numbers yet (Stealth AI is next and will consume this contract directly).

### Constraints

- **Engine: Godot 4.6, Jolt 3D default (per `technical-preferences.md`).** Collision-layer API is the same across GodotPhysics and Jolt.
- **First-time solo Godot dev, 6–9 month MVP timeline.** Contract must be simple to implement (single file) and simple to enforce (one forbidden-pattern rule).
- **Must NOT become a runtime autoload.** Collision layer constants do not need a runtime singleton — a static class resolves at import time with zero memory or load cost.
- **Must be bidirectionally consistent** with `project.godot` named layer slots, so editor-time layer assignment (inspector dropdowns) shows the same names as code-time references.
- **Extension mechanism required.** Adding Layer 6+ later must be a one-line addition to `PhysicsLayers.gd` plus one project-settings edit — not a search-and-replace across multiple files.

### Requirements

- One project-wide source of truth file: `res://src/core/physics_layers.gd`.
- Named integer constants for every layer: `LAYER_WORLD`, `LAYER_PLAYER`, `LAYER_AI`, `LAYER_INTERACTABLES`, `LAYER_PROJECTILES`. These are 1-based layer INDICES (the value passed to `set_collision_layer_value(index, true)`).
- Precomputed bitmask constants for every layer: `MASK_WORLD = 1 << 0`, `MASK_PLAYER = 1 << 1`, etc. These are the values assigned to `collision_layer` / `collision_mask` properties directly.
- Composite masks for commonly-composed use cases, named by intent: `MASK_AI_VISION_OCCLUDERS` (World + Player), `MASK_INTERACT_RAYCAST` (Interactables), etc.
- `project.godot` named 3D physics layer slots 1–5 match the constant names.
- A forbidden-pattern rule: hardcoded integer layer numbers in gameplay code (`collision_layer = 2`, `set_collision_mask_value(3, true)`, etc.) are review-rejected.
- Every future system GDD that references layers cites this ADR and uses constant names, never bare integers.

## Decision

**Create `res://src/core/physics_layers.gd` as a `class_name`-registered static class holding all layer INDICES, bitmask values, and composite masks as `const` members. Populate `project.godot` named 3D physics layer slots 1–5 to match. Register a forbidden-pattern rule (`hardcoded_physics_layer_number`) that blocks PRs using bare layer integers in gameplay code. Every system GDD references `PhysicsLayers.*` constants by name; this ADR is the single source of truth for what each layer means.**

### Architecture

```
                  ┌─────────────────────────────────────────────┐
                  │  res://src/core/physics_layers.gd           │
                  │  ───────────────────────────────────────────│
                  │  class_name PhysicsLayers extends RefCounted│
                  │                                             │
                  │  const LAYER_WORLD = 1                      │
                  │  const LAYER_PLAYER = 2                     │
                  │  const LAYER_AI = 3                         │
                  │  const LAYER_INTERACTABLES = 4              │
                  │  const LAYER_PROJECTILES = 5                │
                  │                                             │
                  │  const MASK_WORLD = 1 << 0  (1)             │
                  │  const MASK_PLAYER = 1 << 1 (2)             │
                  │  const MASK_AI = 1 << 2     (4)             │
                  │  const MASK_INTERACTABLES = 1 << 3 (8)      │
                  │  const MASK_PROJECTILES = 1 << 4   (16)     │
                  │                                             │
                  │  const MASK_AI_VISION_OCCLUDERS =           │
                  │    MASK_WORLD | MASK_PLAYER                 │
                  │  const MASK_AI_PERCEIVABLE = MASK_PLAYER    │
                  │  const MASK_INTERACT_RAYCAST =              │
                  │    MASK_INTERACTABLES                       │
                  │  const MASK_PROJECTILE_HITS =               │
                  │    MASK_WORLD | MASK_AI | MASK_PLAYER       │
                  └─────────────────┬───────────────────────────┘
                                    │ consumed by
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │  Every gameplay script touching physics                  │
       │                                                          │
       │  var ray := PhysicsRayQueryParameters3D.new()            │
       │  ray.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST│
       │                                                          │
       │  body.set_collision_layer_value(PhysicsLayers.LAYER_PLAYER, true)│
       │  body.set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true) │
       │  body.set_collision_mask_value(PhysicsLayers.LAYER_AI, true)    │
       └──────────────────────────────────────────────────────────┘

       Parallel editor support:
       ┌──────────────────────────────────────────────────────────┐
       │  project.godot                                           │
       │  [layer_names]                                           │
       │  3d_physics/layer_1="World"                              │
       │  3d_physics/layer_2="Player"                             │
       │  3d_physics/layer_3="AI"                                 │
       │  3d_physics/layer_4="Interactables"                      │
       │  3d_physics/layer_5="Projectiles"                        │
       │                                                          │
       │  → Inspector dropdowns show these names on every         │
       │    CollisionObject3D's collision_layer / collision_mask. │
       └──────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# res://src/core/physics_layers.gd
# Single source of truth for all collision-layer and collision-mask assignments.
# Per ADR-0006. Do NOT add layers here without updating this ADR.

class_name PhysicsLayers extends RefCounted

# ─── Layer INDICES (1-based, passed to set_collision_*_value) ────────────
const LAYER_WORLD: int = 1           # Static geometry + interactable surfaces (floors, walls)
const LAYER_PLAYER: int = 2          # Eve's CharacterBody3D
const LAYER_AI: int = 3              # Guards, civilians (CharacterBody3D)
const LAYER_INTERACTABLES: int = 4   # Documents, terminals, pickups, doors (raycast-only, non-blocking)
const LAYER_PROJECTILES: int = 5     # Bullets, thrown gadgets

# ─── Layer BITMASKS (assigned to collision_layer / collision_mask directly) ──
const MASK_WORLD: int         = 1 << 0   #  1
const MASK_PLAYER: int        = 1 << 1   #  2
const MASK_AI: int            = 1 << 2   #  4
const MASK_INTERACTABLES: int = 1 << 3   #  8
const MASK_PROJECTILES: int   = 1 << 4   # 16

# ─── Composite masks (named by intent, not by composition) ───────────────
# AI vision raycasts treat world AND player as occluders — if an AI ray hits
# the world first, it stops. If it hits the player, it stops (the player IS
# the target). AI does NOT occlude other AI.
const MASK_AI_VISION_OCCLUDERS: int = MASK_WORLD | MASK_PLAYER

# AI perception casts only pick up the player as a target. World is an occluder
# (above mask), not a target.
const MASK_AI_PERCEIVABLE: int = MASK_PLAYER

# Player interact raycast only scans the Interactables layer. Non-blocking.
const MASK_INTERACT_RAYCAST: int = MASK_INTERACTABLES

# Projectiles collide with world, AI, and player (friendly-fire off is a
# gameplay-layer decision in Combat GDD, not a physics-layer decision).
const MASK_PROJECTILE_HITS: int = MASK_WORLD | MASK_AI | MASK_PLAYER

# Footstep surface raycast — downward into world to read material metadata.
const MASK_FOOTSTEP_SURFACE: int = MASK_WORLD
```

```gdscript
# Usage examples in gameplay code
# ─── Player Character body setup ────────────────────────────────────────
func _ready() -> void:
    set_collision_layer_value(PhysicsLayers.LAYER_PLAYER, true)    # I am Player
    set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true)      # I collide with World
    set_collision_mask_value(PhysicsLayers.LAYER_AI, true)         # I collide with AI bodies

# ─── Interact raycast (PlayerCharacter F.6) ─────────────────────────────
func _get_interact_target() -> Node3D:
    var query := PhysicsRayQueryParameters3D.create(
        camera.global_position,
        camera.global_position - camera.global_transform.basis.z * 2.0
    )
    query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.get("collider")

# ─── Guard vision raycast (Stealth AI, future) ──────────────────────────
func _guard_can_see_player(perception_point: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(eye_position, perception_point)
    query.collision_mask = PhysicsLayers.MASK_AI_VISION_OCCLUDERS
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return hit.get("collider") and hit.collider.collision_layer & PhysicsLayers.MASK_PLAYER
```

```ini
# project.godot (additions — see existing file for surrounding context)

[layer_names]

3d_physics/layer_1="World"
3d_physics/layer_2="Player"
3d_physics/layer_3="AI"
3d_physics/layer_4="Interactables"
3d_physics/layer_5="Projectiles"
```

### Implementation Guidelines

1. **Every gameplay script that touches `collision_layer`, `collision_mask`, `set_collision_layer_value()`, `set_collision_mask_value()`, or `PhysicsRayQueryParameters3D.collision_mask` MUST reference `PhysicsLayers.*` constants.** Bare integer literals (`2`, `4`, `8`…) are forbidden in gameplay code. Exception: the `PhysicsLayers` class itself, which defines the values.
2. **Prefer composite masks over manual bitwise composition at call sites.** If you find yourself writing `PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER` more than once, add it as a named constant on `PhysicsLayers` (e.g., `MASK_AI_VISION_OCCLUDERS`). Composite masks encode design intent; ad-hoc bitwise OR at call sites loses that intent.
3. **Layer INDICES vs MASKS are different things.** `set_collision_layer_value(2, true)` takes an INDEX (`LAYER_PLAYER = 2`); `collision_layer = 2` takes a BITMASK (`MASK_PLAYER = 2` — coincidentally also 2, because bit 1 is value 2). This is confusing; the constants split them explicitly. Use `LAYER_*` with `set_*_value` helpers, and `MASK_*` with direct property assignment.
4. **Adding Layer 6 (or beyond).** (a) Add a new `LAYER_X` constant and `MASK_X` constant to `PhysicsLayers`. (b) Add `3d_physics/layer_6="X"` to `project.godot`. (c) If X participates in any existing composite mask (e.g., X should be occluder for AI vision), update the composite mask. (d) Update this ADR's summary table. (e) No other files need to change — existing systems that don't care about X do nothing.
5. **Project.godot naming is documentation, NOT a source of truth.** If `project.godot` says `layer_2="Guards"` but `PhysicsLayers.LAYER_PLAYER = 2`, the GDScript constant wins at runtime. Keep them in sync via code review; do not introduce divergence.
6. **Physics bodies set their OWN layer; they MASK the layers they collide against.** A common mistake is to set `collision_mask` to include self ("Player masks against Player"). The Godot convention: a body is ON its own layer, and masks AGAINST layers whose bodies should affect it. A player who collides with world and AI sets `layer = MASK_PLAYER`, `mask = MASK_WORLD | MASK_AI`.
7. **Raycasts use `collision_mask` only.** Raycasts are not collision bodies — they have no layer, only a mask. Set `PhysicsRayQueryParameters3D.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST` etc.
8. **Non-blocking raycast layers.** `LAYER_INTERACTABLES` bodies have `collision_layer = MASK_INTERACTABLES` but their `collision_mask = 0` — they participate in raycasts (queried via mask) but do not block any movement. This is the physics encoding of "documents don't push Eve."

## Alternatives Considered

### Alternative 1: No source file; layer numbers in prose only

- **Description**: Status quo at the time of this ADR. Each GDD documents layer numbers in prose; gameplay code hardcodes integers.
- **Pros**: Zero implementation work. No file to maintain.
- **Cons**: All the problems enumerated in the Problem Statement. Silent schema drift, unreadable call sites, editor inspector blank, adding Layer 6 requires grep-and-pray.
- **Estimated Effort**: Negligible now; much higher total cost over the project.
- **Rejection Reason**: Review finding R-18 explicitly rejected this path. Deferring the constants file until drift appears is strictly worse than investing 30 minutes now.

### Alternative 2: `.tres` Resource file instead of static class

- **Description**: Define a `PhysicsLayersResource extends Resource` with `@export` fields; load it as a singleton resource.
- **Pros**: Values editable in editor; theoretically hot-reloadable.
- **Cons**: Adds runtime load cost, however small. Values are `var`, not `const` — compiler cannot inline them. No semantic benefit: layer indices are not designer-tunable knobs, they are structural. Every consumer must `preload()` the resource or reference it via autoload — more verbose than `PhysicsLayers.MASK_PLAYER`.
- **Estimated Effort**: Similar to chosen approach, with more boilerplate at consumer call sites.
- **Rejection Reason**: `Resource` is for designer-tunable, hot-reloadable data. Collision layers are structural constants — wrong tool. Static `class_name` class with `const` members is the idiomatic Godot pattern for this kind of shared schema.

### Alternative 3: Autoload singleton exposing the same values

- **Description**: Register `PhysicsLayers` as an autoload node in `project.godot`. Access via `PhysicsLayers.MASK_PLAYER` at runtime.
- **Pros**: Semantically similar to chosen approach.
- **Cons**: Autoload implies runtime state or services. A class with only `const` members is wasted as an autoload — autoloads consume project.godot slots, load-order mind-share, and mental-model overhead for no benefit. The static `class_name` class is a compile-time name lookup; the autoload is a runtime node lookup. No advantage, small cost.
- **Estimated Effort**: Same as chosen approach.
- **Rejection Reason**: Autoloads are for runtime services (Events, SaveLoadService, Settings). Constants classes do not need runtime registration.

### Alternative 4: Enum-based layer definition

- **Description**: Define `enum Layer { WORLD = 1, PLAYER = 2, AI = 3, INTERACTABLES = 4, PROJECTILES = 5 }` and a separate set of composite mask functions.
- **Pros**: Type-enforced at enum sites (can't accidentally pass a non-layer integer).
- **Cons**: GDScript enums do not compose with bitmask operations naturally (`Layer.PLAYER | Layer.AI` requires casting). Composite masks become functions instead of constants, adding call overhead. The type-safety benefit evaporates because bitmask operations must use raw integers anyway.
- **Estimated Effort**: Similar to chosen approach.
- **Rejection Reason**: Godot's collision API expects raw integers (`collision_layer: int`, `collision_mask: int`). An enum would need casting at every call site. The simplicity of `const int` wins.

## Consequences

### Positive

- Single place to read "what does each layer mean in this project."
- Layer indices and bitmasks are both available as named constants — correct value for correct API.
- Composite masks encode design intent (`MASK_AI_VISION_OCCLUDERS` reads better than `MASK_WORLD | MASK_PLAYER`).
- Editor inspector shows named layers on every `CollisionObject3D` — scene authors no longer guess.
- Adding Layer 6 is a single-file + single-project-setting edit; no grep-and-pray across systems.
- Forbidden-pattern rule makes layer drift visible at code-review time (grep for bare integers in `src/gameplay/`).
- Zero runtime cost: `const` members inline at compile time; no autoload overhead.

### Negative

- One more file to maintain. Total size: ~40 lines including documentation comments.
- Two representations (INDEX vs MASK) may confuse new contributors briefly. Implementation Guideline 3 addresses this with explicit disambiguation.
- `project.godot` named-layer section requires manual sync with the constants class — code review catches drift but cannot prevent it.

### Neutral

- The chosen five layers (World/Player/AI/Interactables/Projectiles) are sufficient for the MVP scope per Player Character GDD + Stealth AI GDD + Combat & Damage GDD plans. Later layers (e.g., "Hazards," "Water Volumes," "Physics Debris") can be added without disturbing existing ones.
- Composite-mask naming by intent (`MASK_AI_VISION_OCCLUDERS`) rather than composition (`MASK_WORLD_PLUS_PLAYER`) is a style choice. This ADR locks intent-based naming.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Gameplay code hardcodes integer layer numbers ignoring this ADR (contract drift) | MEDIUM | MEDIUM | Forbidden-pattern registered in `docs/registry/architecture.yaml`: `hardcoded_physics_layer_number`. Code review + grep check at PR time. |
| `project.godot` named layers drift from `PhysicsLayers` constants (e.g., someone renames "AI" to "Enemies" in the .godot file but not in the .gd) | MEDIUM | LOW | Code review checkpoint; also, GDScript constants win at runtime so the impact is only inspector confusion. A smoke-test lint could compare the two at CI time. |
| Adding Layer 6 without updating composite masks (e.g., new "Hazards" layer but `MASK_AI_VISION_OCCLUDERS` not updated to include it if relevant) | LOW | MEDIUM | Implementation Guideline 4 lists the steps; ADR update is one of them. If a new layer is purely non-interacting with existing composites, no change to composites is needed — but reviewer must verify the analysis. |
| Two layers with "the same purpose" get added later (e.g., "AI" and "Guards" as distinct layers) | LOW | MEDIUM | ADR review requirement — adding a new layer requires updating this ADR, which triggers a design review of whether the new layer is actually distinct from existing ones. |
| Godot 4.7 or beyond changes the collision-layer API | LOW | MEDIUM | Re-verify against `engine-reference/godot/VERSION.md` at each engine upgrade. Breaking changes doc reviewed per project-wide policy. |
| Jolt `Area3D.body_entered` may occasionally miss fast-moving bodies (e.g., Combat darts at 20 m/s on `LAYER_PROJECTILES`) due to broadphase tunneling (added 2026-04-23 per godot-specialist 2026-04-22 §7) | MEDIUM | LOW | Fast projectiles fire trigger signals via their own `move_and_collide` hit-response rather than relying on `Area3D` overlap detection. Dovetails with Combat GDD OQ-CD-2 Jolt prototype scope — the Combat dart's `body_entered` + `area_entered` handler design should treat `Area3D` overlap as a backup channel, not the primary dispatch. Impact is LOW for this project: only darts (20 m/s) and potentially Bullet projectiles if they are migrated from hitscan are fast enough to tunnel; every other physics body (Eve at ≤5.5 m/s, guards at patrol speeds, civilians) is well below the tunneling threshold. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (constant lookup) | N/A | Zero — `const int` inlined at compile time | N/A |
| CPU (autoload lookup overhead) | N/A | Zero — not an autoload | N/A |
| Memory (class static size) | N/A | <1 KB (handful of int constants) | N/A |
| Load Time | N/A | Negligible (class registered via `class_name` at startup like any script) | N/A |

> This ADR is purely organizational. No runtime cost.

## Migration Plan

Project is in pre-production; no gameplay code exists yet. Implementation order:

1. Create `res://src/core/physics_layers.gd` with the constants and composite masks defined above.
2. Edit `project.godot` to populate `[layer_names]/3d_physics/layer_1..5`.
3. Update Player Character GDD Core Rules rule 5 to reference `PhysicsLayers.*` constants and cite this ADR.
4. Register the forbidden pattern `hardcoded_physics_layer_number` in `docs/registry/architecture.yaml` when that registry is authored (or in the Control Manifest once it lands).
5. Future system GDDs (Stealth AI, Combat & Damage, Inventory & Gadgets, etc.) reference `PhysicsLayers.*` by name, not by integer.
6. When the first gameplay script lands that uses physics, verify it references the constants. Close the verification gate.
7. Set ADR-0006 status Proposed → Accepted.

**Rollback plan**: None needed. If this ADR is rejected before Accepted, no code exists that depends on it; the status reverts to "layer numbers in prose" (Alternative 1). If issues surface after Accepted (e.g., a better organization is discovered), this ADR can be superseded — the constants file remains valid; only the composite-mask set or naming would change.

## Validation Criteria

- [x] `res://src/core/physics_layers.gd` exists with all five `LAYER_*` constants, all five `MASK_*` constants, and at least the composite masks listed in Key Interfaces. ✅ **Verified 2026-04-29** (Sprint 01 Group 1.1 — file written verbatim per §Key Interfaces; Godot 4.6.2 editor parsed it successfully and registered the `class_name PhysicsLayers` in `.godot/global_script_class_cache.cfg`).
- [x] `project.godot` `[layer_names]/3d_physics/layer_1..5` populated to match constant names. ✅ **Verified 2026-04-29** (Sprint 01 Group 1.2 — `[layer_names]/3d_physics/layer_1="World"` through `layer_5="Projectiles"` written; preserved verbatim through Godot 4.6.2 editor save pass).
- [ ] Player Character GDD Core Rules rule 5 updated to reference `PhysicsLayers.*` constants (cascading edit; part of Session B). *(Out of spike scope; the GDD edit was the original Session B pass and is independent of ADR Acceptance.)*
- [ ] Forbidden pattern `hardcoded_physics_layer_number` registered in the architecture registry or Control Manifest. *(Pending — registers when `/create-control-manifest` runs against the foundational Accepted ADR set, which now includes ADR-0006.)*
- [x] First gameplay script using physics references the constants (no bare integer literals for layers/masks in `src/gameplay/`). ✅ **Verified 2026-04-29** via `prototypes/verification-spike/collision_migration_check.gd` headless run (Sprint 01 Group 2.3 — all 6 checks PASS): (a) PhysicsLayers class reachable via class_name; (b) `set_collision_layer_value(LAYER_PLAYER, true)` writes `MASK_PLAYER` (= 2) to `collision_layer`; (c) `set_collision_mask_value` composes World + AI to MASK 5 = MASK_WORLD | MASK_AI; (d) MASK_* constants match `1 << (LAYER_n - 1)` for all 5 layers; (e) composite masks `MASK_AI_VISION_OCCLUDERS=3` / `MASK_PROJECTILE_HITS=7` / `MASK_INTERACT_RAYCAST=8` / `MASK_FOOTSTEP_SURFACE=1` compose correctly; (f) `PhysicsRayQueryParameters3D.collision_mask` accepts both single-layer and composite masks via constants. The verification script itself is the "gameplay-style file using only constants" — it contains zero bare integer literals for collision_layer/collision_mask.
- [ ] Code review checklist entry: "Does this PR set `collision_layer`/`collision_mask` directly or via `set_*_value`? If yes, does it use `PhysicsLayers.*` constants? If no, reject." *(Process item; lands when Control Manifest is generated.)*

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/player-character.md` | Player Character (system 8) Core Rules rule 5 | "Layer 1: World … Layer 5: Projectiles" (currently in prose) | This ADR is the formal, centralized source. PC GDD cites `PhysicsLayers.*` constants instead of prose numbers. |
| `design/gdd/player-character.md` | PC GDD interact raycast (F.6) | `mask = Layer 4 (Interactables)` | PC GDD updated to cite `PhysicsLayers.MASK_INTERACT_RAYCAST`. |
| `design/gdd/stealth-ai.md` (pending) | Stealth AI — vision raycasts | AI casts against World + Player (not other AI) | `MASK_AI_VISION_OCCLUDERS` encodes this intent directly. |
| `design/gdd/combat-damage.md` (pending) | Combat & Damage — projectile resolution | Projectiles hit World, AI, Player | `MASK_PROJECTILE_HITS` encodes this. |
| `design/gdd/reviews/player-character-review-2026-04-19.md` | Review finding R-18 | "Mandate `res://src/core/physics_layers.gd` … as the single source of truth with named constants" | This ADR implements the recommendation verbatim. |

## Related

- **ADR-0001** (Stencil ID Contract) — independent. Stencil is per-pixel rendering metadata; collision layers are per-body physics metadata. Different buses.
- **ADR-0002** (Signal Bus + Event Taxonomy) — independent, but parallel in spirit: both establish project-wide contracts for a specific cross-cutting concern. Drift-prevention via forbidden patterns is the shared pattern.
- **ADR-0005** (FPS Hands Outline Rendering) — independent. Hands use a SubViewport; no physics implications.
- **Player Character GDD** — primary downstream consumer. Core Rules rule 5 cites this ADR after Session B cascading edits.
- **`design/registry/entities.yaml`** — references Player's physical layer (2). After Accepted, entity registry entries that mention layer numbers should reference constant names where possible.
- **`.claude/docs/technical-preferences.md`** — confirms Jolt 3D is the pinned physics engine; collision-layer API is identical across Jolt and GodotPhysics.
- **Review finding R-18** — the explicit source for this ADR.
- **Future Control Manifest** — will include the `hardcoded_physics_layer_number` forbidden-pattern entry.
