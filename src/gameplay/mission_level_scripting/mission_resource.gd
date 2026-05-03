# res://src/gameplay/mission_level_scripting/mission_resource.gd
#
# MissionResource — authored Resource describing an entire mission.
# Stored at `assets/data/missions/<mission_id>/mission.tres`.
#
# Load pattern (CR-18): section root exports `mission_id: StringName`.
# MissionLevelScriptingService calls
#   ResourceLoader.load("res://assets/data/missions/" + mission_id + "/mission.tres")
# at section_entered(NEW_GAME). Do NOT @export this resource on the section root
# node — that would force a load on scene-load before section_entered fires.
#
# Per GDD design/gdd/mission-level-scripting.md §CR-18.
# Implements: Story MLS-002 (Mission state machine + objective resource schema).

## Top-level mission descriptor serialised to a .tres file. Contains the full
## ordered list of [MissionObjective] resources that make up the mission.
##
## CR-18 load-time validation (enforced by MissionLevelScriptingService):
## - [member objectives] must contain at least one entry.
## - At least one objective must have [code]required_for_completion = true[/code].
## - No objective may list itself in [code]prereq_objective_ids[/code].
## - No mutual prereq cycles (DFS check).
## On any violation MissionLevelScriptingService calls [code]push_error[/code]
## and remains IDLE — the mission does NOT start.
class_name MissionResource
extends Resource


## Unique identifier for this mission. Emitted as the payload of
## [code]Events.mission_started[/code] and [code]Events.mission_completed[/code].
## Must match the directory name under [code]assets/data/missions/[/code].
@export var mission_id: StringName

## Ordered list of objectives in this mission. All objectives are PENDING at
## mission start; MissionLevelScriptingService applies F.2 (prereq gate) to
## determine which activate immediately. Must contain at least one entry with
## [code]required_for_completion = true[/code] (validated at load time).
@export var objectives: Array[MissionObjective] = []
