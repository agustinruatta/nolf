# res://src/core/physics_layers.gd
#
# Single source of truth for all collision-layer and collision-mask assignments
# in The Paris Affair. Per ADR-0006 (Collision Layer Contract).
#
# Bare integer literals (e.g. `collision_layer = 2`, `set_collision_mask_value(3, true)`)
# are forbidden in gameplay code. Every consumer references PhysicsLayers.* constants.
#
# Adding a new layer: see ADR-0006 §Implementation Guideline 4.
# Layer INDICES vs MASKS: see ADR-0006 §Implementation Guideline 3.
#
# This file closes ADR-0006 verification gate G1.

class_name PhysicsLayers extends RefCounted

# ─── Layer INDICES (1-based; passed to set_collision_*_value()) ─────────────
const LAYER_WORLD: int = 1            # Static geometry + interactable surfaces
const LAYER_PLAYER: int = 2           # Eve's CharacterBody3D
const LAYER_AI: int = 3               # Guards, civilians (CharacterBody3D)
const LAYER_INTERACTABLES: int = 4    # Documents, terminals, pickups, doors (raycast-only)
const LAYER_PROJECTILES: int = 5      # Bullets, thrown gadgets

# ─── Layer BITMASKS (assigned to collision_layer / collision_mask directly) ──
const MASK_WORLD: int         = 1 << 0    #  1
const MASK_PLAYER: int        = 1 << 1    #  2
const MASK_AI: int            = 1 << 2    #  4
const MASK_INTERACTABLES: int = 1 << 3    #  8
const MASK_PROJECTILES: int   = 1 << 4    # 16

# ─── Composite masks (named by intent, not by composition) ──────────────────

# AI vision raycasts treat world AND player as occluders. World stops the ray
# (occluder). Player stops the ray (target). AI does NOT occlude other AI.
const MASK_AI_VISION_OCCLUDERS: int = MASK_WORLD | MASK_PLAYER

# AI perception casts only pick up the player as a target. World is an occluder
# (separate mask above), not a target.
const MASK_AI_PERCEIVABLE: int = MASK_PLAYER

# Player interact raycast only scans the Interactables layer. Non-blocking.
const MASK_INTERACT_RAYCAST: int = MASK_INTERACTABLES

# Projectiles collide with world, AI, and player. Friendly-fire policy is a
# gameplay-layer decision in Combat GDD, not a physics-layer decision.
const MASK_PROJECTILE_HITS: int = MASK_WORLD | MASK_AI | MASK_PLAYER

# Footstep surface raycast — downward into world to read material metadata.
const MASK_FOOTSTEP_SURFACE: int = MASK_WORLD
