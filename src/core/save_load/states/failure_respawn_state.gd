# res://src/core/save_load/states/failure_respawn_state.gd
#
# FailureRespawnState — saved failure & respawn state per ADR-0003 §Key
# Interfaces + Failure & Respawn GDD CR-3, CR-6.
#
# Story FR-002 fills in the production field contract (replaces the Save/Load
# story-001 scaffold placeholder). F&R epic owns the semantic contract; the
# file path lives under src/core/save_load/states/ per ADR-0003 IG 11.
#
# ADR-0003 IG 11 compliance: top-level class_name-registered Resource in its
# own file; inner-class typed @export fields come back null after
# ResourceLoader.load (Sprint 01 verification finding F2).

## FailureRespawnState — per-death snapshot of failure & respawn bookkeeping.
## Captured by FailureRespawnState.capture() at the moment of player death.
## Implements: design/gdd/failure-respawn.md CR-3, CR-6
## Story: FR-002
class_name FailureRespawnState
extends Resource

## True when the ammo-floor was already applied during the current checkpoint
## interval (i.e., the player received the ammo-top-up after their previous
## death this checkpoint). FR-004 sets this flag on the first respawn within a
## checkpoint; FR-005 clears it when a fresh section_entered resets the
## checkpoint. At VS scope this is always false (no ammo floor mechanic in VS).
@export var floor_applied_this_checkpoint: bool = false


## Explicit constructor. Defaults match the VS "no floor applied" state.
## Required per ADR-0003 Resource-subclass contract — Godot 4 Resource._init()
## must be explicit when the Resource has state that must survive
## ResourceLoader.load → instantiate round-trips.
##
## Usage:
##   FailureRespawnState.new()        # floor not applied (default)
##   FailureRespawnState.new(true)    # floor already applied this checkpoint
func _init(flag: bool = false) -> void:
	floor_applied_this_checkpoint = flag


## Returns a new FailureRespawnState mirroring the given live flag value.
## Does NOT advance the live flag — capture is read-only per CR-6.
##
## Called by FailureRespawnService._assemble_save_game() during CAPTURING.
## The MLS-owned capture() pattern means every system provides its own static
## factory that reads live state without modifying it.
##
## Usage:
##   sg.failure_respawn = FailureRespawnState.capture(_floor_applied_this_checkpoint)
static func capture(live_flag: bool) -> FailureRespawnState:
	return FailureRespawnState.new(live_flag)
