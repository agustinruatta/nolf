# src/gameplay/sections/section_root.gd
#
# SectionRoot — Base section-root script implementing the CR-9 Section
# Authoring Contract (GDD §Detailed Design CR-9, ADR-0007).
#
# IMPLEMENTS: Story LS-008, TR-LS-008, CR-9
# REQUIREMENTS: TR-LS-008
# GDD: design/gdd/level-streaming.md §Detailed Design CR-9
# ADRs: ADR-0007 (Autoload Load Order Registry)
#
# PURPOSE
#   Every section scene's root Node3D attaches this script. It declares the
#   4 mandatory exports and computes `_section_bounds` at _ready() from a
#   SectionBoundsHint MeshInstance3D child, falling back to StaticBody3D
#   children when the hint is absent.
#
#   A single script is intentional (MVP: sections are composition-driven, not
#   behaviour-driven). Section-specific logic arrives via scene composition
#   and Mission Scripting hooks, NOT per-section subclass scripts.
#
# SECTION PASSIVITY RULE (GDD §C.5.2, CR-9)
#   This script MUST NOT emit any signal from _ready() or _enter_tree().
#   _ready() only calls add_to_group and _compute_section_bounds. All runtime
#   signal emission is driven externally by LevelStreamingService.
#
# AUTHORING DISCIPLINE (ADR-0006 cross-ref)
#   SectionRoot is a Node3D with no physics body. Child physics nodes (floors,
#   walls, props) are authored in the .tscn file with explicit collision_layer
#   values per ADR-0006 PhysicsLayers.


## Section-root script implementing the CR-9 Section Authoring Contract.
## Attach to the root Node3D of every section scene.
##
## Example (_ready on load):
##   var inst: SectionRoot = load("res://scenes/sections/plaza.tscn").instantiate()
##   assert(inst is SectionRoot)
##   assert(inst.section_id == &"plaza")
##   assert(inst.get_section_bounds().size != Vector3.ZERO)
class_name SectionRoot extends Node3D


# ── Section identity ───────────────────────────────────────────────────────────

## Unique section identifier. Must match a key in assets/data/section_registry.tres.
## (CR-9, TR-LS-008, GDD §C.5.3)
@export var section_id: StringName = &""


# ── Spawn / entry markers ──────────────────────────────────────────────────────

## NodePath to the Marker3D child used as the player spawn location when
## entering this section for the first time. Resolved by LevelStreamingService
## on section transition. Must point to a Marker3D node.
## (CR-9, TR-LS-008)
@export var player_entry_point: NodePath

## NodePath to the Marker3D child used as the respawn location after player
## death inside this section. MUST resolve to a DISTINCT node instance from
## player_entry_point (CR-9 identity check — position equality is irrelevant).
## (CR-9, TR-LS-008)
@export var player_respawn_point: NodePath


# ── Environment ────────────────────────────────────────────────────────────────

## Per-section Environment resource. When non-null, LevelStreamingService applies
## it to get_viewport().get_camera_3d().get_world_3d().environment after the
## section is mounted. When null, LSS falls back to default_environment.tres.
## (CR-9, TR-LS-008, AC-4, AC-5)
@export var environment: Environment = null


# ── Section bounds (computed, not exported) ────────────────────────────────────

## Computed section AABB in world-space. Populated by _compute_section_bounds()
## during _ready(). Not exported — derived from SectionBoundsHint geometry.
var _section_bounds: AABB = AABB()


# ── Lifecycle ──────────────────────────────────────────────────────────────────

## Adds this node to the "section_root" group (required by CR-9) and computes
## the section bounds from the SectionBoundsHint child mesh.
##
## Section passivity: NO signals are emitted here. The group registration is
## synchronous and side-effect-free for external observers.
func _ready() -> void:
	add_to_group("section_root")
	_compute_section_bounds()


# ── Public API ─────────────────────────────────────────────────────────────────

## Returns the computed section bounds AABB in world-space.
## Non-zero after _ready() when either SectionBoundsHint is present or at
## least one StaticBody3D child exists. Zero AABB indicates an authoring error.
##
## Example:
##   var bounds: AABB = section_root.get_section_bounds()
##   assert(bounds.size != Vector3.ZERO)
func get_section_bounds() -> AABB:
	return _section_bounds


# ── Private helpers ────────────────────────────────────────────────────────────

## Derives _section_bounds from SectionBoundsHint (preferred) or StaticBody3D
## children (fallback). Called once from _ready().
##
## Primary path: if a MeshInstance3D named "SectionBoundsHint" exists as a
## direct child, compute the transformed AABB:
##   section_aabb = global_transform * hint.get_aabb()
## The multiplication by global_transform converts mesh-local AABB to
## world-space AABB, accounting for section root position, rotation, and scale.
##
## Fallback path: when SectionBoundsHint is missing, iterate all direct children
## typed StaticBody3D and union their global_transform.origin into a growing AABB.
## This produces a coarser bounds but ensures a non-zero result for simple scenes.
func _compute_section_bounds() -> void:
	var hint: Node = get_node_or_null("SectionBoundsHint")
	if hint != null and hint is MeshInstance3D:
		var mesh_aabb: AABB = (hint as MeshInstance3D).get_aabb()
		_section_bounds = (hint as MeshInstance3D).global_transform * mesh_aabb
	else:
		_section_bounds = _derive_aabb_from_children()


## Fallback AABB computation from StaticBody3D direct children.
## Iterates all children, unions position of each StaticBody3D into a
## growing AABB. Returns AABB() (zero) if no StaticBody3D children found.
func _derive_aabb_from_children() -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for child: Node in get_children():
		if not (child is StaticBody3D):
			continue
		var origin: Vector3 = (child as StaticBody3D).global_transform.origin
		if first:
			result = AABB(origin, Vector3.ZERO)
			first = false
		else:
			result = result.expand(origin)
	return result
