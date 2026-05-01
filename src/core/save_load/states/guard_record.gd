# res://src/core/save_load/states/guard_record.gd
#
# GuardRecord — per-guard state record per ADR-0003 §Key Interfaces. Used as
# the value type of StealthAIState.guards: Dictionary keyed by guard actor_id.
# Top-level class_name registration is REQUIRED by ADR-0003 IG 11 — declaring
# this as an inner class on StealthAIState would cause the @export field to
# come back null after ResourceLoader.load (Sprint 01 finding F2).

class_name GuardRecord
extends Resource

## StealthAI.AlertState enum value (int — enum lives on the consumer class per
## ADR-0002 IG 2; stored as int for serialization).
@export var alert_state: int = 0

## Index into the guard's patrol path (per Stealth AI GDD).
@export var patrol_index: int = 0

## Last position where the guard registered the player as a percept; reset to
## Vector3.ZERO when the guard de-escalates to UNAWARE.
@export var last_known_target_position: Vector3 = Vector3.ZERO

## Current world position at save time.
@export var current_position: Vector3 = Vector3.ZERO
