# res://src/core/save_load/states/civilian_ai_state.gd
#
# CivilianAIState — saved civilian AI state per ADR-0003 §Key Interfaces +
# Civilian AI GDD. MVP scope: single dictionary tracking which civilians have
# panicked. Future expansion (witness state, schedule progress, etc.) lands
# when the Civilian AI epic comes online.

class_name CivilianAIState
extends Resource

## StringName -> bool (untyped Dictionary; actor_id keyed per ADR-0003 IG 6).
@export var panicked: Dictionary = {}
