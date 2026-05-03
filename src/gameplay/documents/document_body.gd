# res://src/gameplay/documents/document_body.gd
#
# DocumentBody — uncollected document pickup body node.
#
# Implements: design/gdd/document-collection.md AC-DC-1.1 (§H.1, §C.3, §C.5.8)
# ADR refs: ADR-0006 (Collision Layer Contract), ADR-0001 (Stencil ID Contract)
# Story: DC-002 (DocumentBody node — collision layer, stencil tier, interact priority)
#
# PHYSICS ENCODING (ADR-0006 IG 8)
#   collision_layer = PhysicsLayers.MASK_INTERACTABLES (Layer 4 only; bitmask = 8)
#   collision_mask  = 0 — participates in raycasts, does NOT block movement
#   ("documents don't push Eve")
#   Values are scene-baked in document_body.tscn using the computed bitmask integer
#   (Godot .tscn serialisation format); PhysicsLayers.* constants are the
#   source of truth per ADR-0006 IG 5. No collision_layer assignment in this script
#   means zero risk of bare integer literals in gameplay code (ADR-0006 IG 1).
#
# STENCIL TIER (ADR-0001 IG 2)
#   Tier 1 (HEAVIEST — 4 px @ 1080p). Scene-baked on the MeshInstance3D
#   surface_material_override/0 in document_body.tscn. No runtime set_tier()
#   call — every instance inherits Tier 1 from the template automatically.
#
# PERFORMANCE (CR-15 zero-steady-state budget)
#   No _process or _physics_process override. Zero per-frame cost.
#   Pure data-presentation node.

## Uncollected document pickup body. Carries a Document Resource reference.
## Lives at Section/Documents/ in the section scene tree; freed on pickup
## by DocumentCollection (Story DC-003).
## Layer: LAYER_INTERACTABLES only (bitmask = PhysicsLayers.MASK_INTERACTABLES).
## Stencil: Tier 1 (4 px, heaviest) — scene-baked in document_body.tscn.
class_name DocumentBody
extends StaticBody3D


# Explicit preload to ensure Document class is resolved at parse time.
# Without this, scenes that load document_body.gd before the global class
# registry has scanned src/gameplay/documents/ trigger "Could not find type
# Document" parse errors (cascade from document_collection.gd preload).
const _DOCUMENT_SCRIPT: Script = preload("res://src/gameplay/documents/document.gd")


## The Document Resource for this pickup. Must be non-null with a non-empty id.
## Assigned by the Level Designer in the instanced scene.
## CI lint §C.5.6 lint #1 enforces non-null + non-empty id at build time.
##
## Typed as Resource (not Document) at parse-time to avoid the global-class-
## registry race during scene reload chains (level_streaming_swap_test load
## path triggered "Could not find type Document" parse errors). Runtime check
## via `document.get_script() == _DOCUMENT_SCRIPT` is performed by callers.
@export var document: Resource


## Returns the DOCUMENT interact priority (0 = highest).
## Beats TERMINAL=1, PICKUP=2, DOOR=3 — ensures documents win overlap resolution
## when multiple interactable bodies are within interact range simultaneously.
## Per GDD §C.3 + AC-DC-1.1 §H.1.
func get_interact_priority() -> int:
	return 0
