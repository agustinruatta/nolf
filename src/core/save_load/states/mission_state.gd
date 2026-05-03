# res://src/core/save_load/states/mission_state.gd
#
# MissionState — saved mission/level state per ADR-0003 §Key Interfaces +
# Mission Level Scripting GDD. fired_beats is REQUIRED per MLS CR-7
# (savepoint-persistent-beats invariant).

class_name MissionState
extends Resource

## Current section ID (e.g., &"plaza"); duplicates SaveGame.section_id at
## save time but lives here too because mission system is the owner of the
## "what section am I in" concept.
@export var section_id: StringName = &""

## Objective IDs that have been completed.
@export var objectives_completed: Array[StringName] = []

## StringName -> bool (untyped Dictionary; trigger_id -> fired flag).
@export var triggers_fired: Dictionary = {}

## StringName -> bool (untyped Dictionary; beat_id -> fired flag).
## Required per MLS CR-7 (savepoint-persistent-beats invariant — beats fired
## before a save must remain fired across save/load).
@export var fired_beats: Dictionary = {}

## StringName -> int mapping from objective_id to ObjectiveState enum value.
## The int values correspond to MissionLevelScriptingService.ObjectiveState:
##   0 = PENDING, 1 = ACTIVE, 2 = COMPLETED
## This field is the authoritative per-objective state for save/load (MLS-002).
## Key: StringName objective_id; Value: int (MissionLevelScriptingService.ObjectiveState).
@export var objective_states: Dictionary = {}
