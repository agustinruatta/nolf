# res://src/core/save_load/states/failure_respawn_state.gd
#
# FailureRespawnState — saved failure & respawn state per ADR-0003 §Key
# Interfaces + Failure & Respawn GDD CR-3. SCAFFOLD ONLY: this story declares
# the class with class_name registration and a single placeholder @export
# field that survives round-trip. The Failure & Respawn epic owns refinement
# of the actual fields (dying-state save_capture, retry-from-savepoint
# bookkeeping, etc.).

class_name FailureRespawnState
extends Resource

## Placeholder; F&R epic replaces with the real field set. Kept as a
## non-trivial type so the round-trip test confirms the file participates in
## ResourceSaver/Loader correctly.
@export var last_section_id: StringName = &""
