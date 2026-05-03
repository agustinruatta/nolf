# res://src/gameplay/shared/checkpoint.gd
#
# Shared checkpoint resource passed between Failure & Respawn, MissionLevelScripting,
# and PlayerCharacter — per GDD CR-11 location decision (live in `shared/` to avoid
# PC→F&R load-order dependency). Referenced by FailureRespawnService._current_checkpoint.
#
# Populated by FR-004 (_on_section_entered handler body) and FR-005 (LS restore
# callback body). Fields declared here now so dependents can reference the type
# from day one; values are set in the above stories.
#
# Implements: design/gdd/failure-respawn.md CR-11 (checkpoint location contract).

class_name Checkpoint
extends Resource

## World-space position where the player will be respawned.
## Set by _on_section_entered (FR-004) from the section anchor node transform.
@export var respawn_position: Vector3 = Vector3.ZERO

## The section this checkpoint belongs to.
## Used by FR-005 to verify the restore callback applies to the correct section.
## Matches the section_id emitted in Events.section_entered.
@export var section_id: StringName = &""

## Floor flag at the time the checkpoint was recorded.
## Used by FR-004's floor flag state machine (declared now; populated in FR-004).
## Interpretation: 0 = unknown / not yet recorded.
@export var floor_flag: int = 0
