# src/gameplay/sections/plaza_section.gd
#
# PlazaSection — Section-root script for the Plaza scene.
#
# IMPLEMENTS: GDD §C.5 Section Authoring Contract, §C.5.1, §C.5.2, §C.5.3,
#             §C.5.6, CR-9, CR-21
# STORY: MLS-003 — Plaza section authoring contract
#
# PURPOSE
#   Declares the required @export bindings for the Section Authoring Contract
#   (GDD §C.5). Attached to the root Node3D of res://scenes/sections/plaza.tscn.
#   The Level Streaming Service and Failure-and-Respawn system consume entry_point,
#   respawn_point, and section_id at runtime. The discovery_surface_ids field is
#   consumed by CI (AC-MLS-14.4) and future runtime discovery logic.
#
# SECTION PASSIVITY RULE (GDD §C.5.2, AC-MLS-6.5)
#   This script MUST NOT emit any signal from _ready() or _enter_tree().
#   The _ready() body is limited to debug-build NodePath sanity assertions.
#   All runtime signal emission is driven externally by MissionLevelScriptingService
#   and LevelStreamingService after section_entered fires.
#
# ADR-0006 NOTE
#   PlazaSection is a Node3D with no physics body — no collision_layer or
#   collision_mask assignments are present in this script. Child physics nodes
#   (floor, walls, WorldItem) are authored in the .tscn scene file and reference
#   PhysicsLayers.* constants per ADR-0006.


## Section-root script implementing the Section Authoring Contract (GDD §C.5).
## Attach to the root Node3D of Plaza.tscn.
class_name PlazaSection extends Node3D


# ── Section identity ──────────────────────────────────────────────────────────

## Unique section identifier. Must match a key in assets/data/section_registry.tres.
## (AC-MLS-6.3, GDD §C.5.3)
@export var section_id: StringName = &"plaza"


# ── Spawn / entry markers ─────────────────────────────────────────────────────

## NodePath to the Marker3D child named `player_entry_point`.
## Resolved by LevelStreamingService when transitioning INTO this section.
## (GDD §C.5.1, AC-MLS-6.1, AC-MLS-6.2)
@export var entry_point: NodePath

## NodePath to the Marker3D child named `player_respawn_point`.
## Resolved by FailureRespawnService on player death inside this section.
## MUST be a distinct node instance from entry_point even when co-located
## (CR-9 / AC-MLS-6.2 identity check — position equality is irrelevant).
## (GDD §C.5.1, §C.5.6, AC-MLS-6.1, AC-MLS-6.2, F&R coord item #11)
@export var respawn_point: NodePath


# ── Discovery surfaces ────────────────────────────────────────────────────────

## StringName IDs of Discovery Surface props authored in this section.
## CI requires length >= 1 for each of sections 1–4 (AC-MLS-14.4, GDD §C.9).
## "ds_plaza_maintenance_schedule" = the maintenance-roster clipboard on the
## guard hut wall — T2 Environmental Gag, no beat_id, no triggered audio.
@export var discovery_surface_ids: Array[StringName] = [&"ds_plaza_maintenance_schedule"]


# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Validates that exported NodePaths resolve in debug builds only.
## NO signals are emitted here — section passivity rule (GDD §C.5.2, AC-MLS-6.5).
func _ready() -> void:
	if OS.is_debug_build():
		assert(get_node_or_null(entry_point) != null,
			"PlazaSection: entry_point NodePath does not resolve")
		assert(get_node_or_null(respawn_point) != null,
			"PlazaSection: respawn_point NodePath does not resolve")
		assert(get_node(entry_point) != get_node(respawn_point),
			"PlazaSection: entry_point and respawn_point must resolve to distinct nodes (CR-9 / AC-MLS-6.2)")
