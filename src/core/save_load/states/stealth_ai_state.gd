# res://src/core/save_load/states/stealth_ai_state.gd
#
# StealthAIState — saved stealth AI state per ADR-0003 §Key Interfaces +
# Stealth AI GDD. Keyed by stable actor_id: StringName per ADR-0003 IG 6
# (NodePath/Node refs forbidden — they cannot survive a scene reload).

class_name StealthAIState
extends Resource

## StringName -> GuardRecord (untyped Dictionary; values are top-level
## class_name GuardRecord Resources per ADR-0003 IG 11).
@export var guards: Dictionary = {}
