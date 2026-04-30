# prototypes/verification-spike/test_save_game.gd
#
# Minimal Resource shape that mirrors the nested-typed-Resource structure of
# the production SaveGame (per ADR-0003 §Key Interfaces) just enough to
# exercise the three verification gates:
#   - Top-level Resource with primitive @export fields (int, String,
#     StringName, float)
#   - One nested typed-Resource field (TestSubState — declared in its own
#     file per Godot inner-class @export limitation finding)
#   - Dictionary[StringName, int] / Dictionary[StringName, bool] fields on
#     the sub-state — mirrors InventoryState.ammo_magazine + MissionState.
#     fired_beats shape (Dictionary[K,V] is 4.4+; round-trip is implicit
#     Gate 1 sub-coverage).
#
# This is verification scaffolding only. Production SaveGame lives at
# `src/core/save_load/save_game.gd` and is NOT touched by the spike.

class_name TestSaveGame extends Resource

@export var save_format_version: int = 1
@export var saved_at_iso8601: String = ""
@export var section_id: StringName = &""
@export var elapsed_seconds: float = 0.0

# Nested typed Resource — exercises multi-level Resource serialization
# AND duplicate_deep() isolation (Gate 3). Declared in its own file
# (test_sub_state.gd) because inner-class @export types don't round-trip
# via ResourceSaver/ResourceLoader (Sprint 01 verification finding).
@export var sub_state: TestSubState
