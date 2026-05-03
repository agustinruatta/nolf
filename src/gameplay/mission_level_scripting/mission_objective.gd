# res://src/gameplay/mission_level_scripting/mission_objective.gd
#
# MissionObjective — authored Resource describing a single objective within a
# MissionResource. Stored as a .tres file under
# `assets/data/missions/<mission_id>/objectives/`.
#
# Per GDD design/gdd/mission-level-scripting.md §CR-18.
# Implements: Story MLS-002 (Mission state machine + objective resource schema).

## Single objective descriptor serialised to a .tres file.
##
## Completion is diegetic (CR-4): the objective listens for a Signal Bus event
## that Eve's action already produces — never a proximity-to-marker trigger.
## When [member completion_signal] fires and the optional
## [member completion_filter_method] returns true, MissionLevelScriptingService
## transitions this objective ACTIVE→COMPLETED and emits
## [code]Events.objective_completed(objective_id)[/code].
class_name MissionObjective
extends Resource


## Unique identifier for this objective. Used as the key in
## [code]MissionState.objective_states[/code] and as the payload for
## [code]Events.objective_started[/code] / [code]Events.objective_completed[/code].
@export var objective_id: StringName

## Localisation key for the player-visible objective name (consumed by HUD Core
## in the VS milestone). Empty string is allowed for hidden/internal objectives.
@export var display_name_key: StringName

## IDs of objectives that must all be COMPLETED before this objective can
## activate (PENDING→ACTIVE). Empty array means no prerequisites — the
## objective activates immediately at mission start (F.2 vacuously true).
@export var prereq_objective_ids: Array[StringName] = []

## StringName of the [code]Events[/code] signal whose emission completes this
## objective. E.g. [code]&"document_collected"[/code]. Must be a real signal
## declared on [code]events.gd[/code] (CR-4). MissionLevelScriptingService
## subscribes to this signal when the objective enters ACTIVE state and
## unsubscribes on COMPLETED.
@export var completion_signal: StringName

## Optional name of a method defined on MissionLevelScriptingService to call
## when [member completion_signal] fires. The method receives the signal
## argument and must return [code]bool[/code]: [code]true[/code] = completion
## accepted; [code]false[/code] = ignore. Empty string means always-complete.
## MUST be a StringName, NOT a Callable — Godot 4.6 cannot serialise Callable
## in .tres files (CR-18).
@export var completion_filter_method: StringName = &""

## IDs of sibling objectives that should be automatically COMPLETED in the same
## frame when THIS objective completes (CR-3 alt-route cascade). Used for
## mutually-exclusive objective paths: completing one supersedes the others so
## the HUD and save-state stay consistent without a separate SUPERSEDED enum
## value. Cascade depth is capped at MissionLevelScriptingService.SUPERSEDE_CASCADE_MAX.
@export var supersedes: Array[StringName] = []

## When true this objective must reach COMPLETED for the F.1 mission-complete
## gate to open. When false the objective is optional — the mission can complete
## regardless of this objective's state. At least one objective in a
## MissionResource must have [code]required_for_completion = true[/code] (CR-18
## validation enforced at load time).
@export var required_for_completion: bool = true
