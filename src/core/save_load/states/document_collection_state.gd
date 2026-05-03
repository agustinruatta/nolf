# res://src/core/save_load/states/document_collection_state.gd
#
# DocumentCollectionState — saved document collection state per ADR-0003
# §Key Interfaces + Document Collection GDD.

## DocumentCollectionState — saved snapshot of all document IDs the player has
## collected in the current run. Schema frozen per ADR-0003; only `id` values
## are persisted — no document content is stored in the save file (CR-6).
##
## Owned by the Document Collection system (DC). Populated via
## `DocumentCollection.capture()` during MLS-orchestrated save assembly.
## Restored via `DocumentCollection.restore(state)` within MLS's LS step-9
## callback (CR-5 revised 2026-04-27 — DC does NOT register its own LS callback).
##
## Duplicate discipline (CR-6): the outer SaveGame is duplicate_deep()-ed by
## Save/Load at the save/load boundary. DC's `restore()` calls
## `state.collected.duplicate()` on the inner Array[StringName] to break the
## residual aliasing between DC's live `_collected` and the throw-away dup —
## sufficient at this nesting depth because StringName is value-typed.
##
## Usage example (capture):
##   var state := DocumentCollectionState.new()
##   state.collected = _collected.duplicate()
##   sg.documents = state
##
## Usage example (restore):
##   _collected = state.collected.duplicate()
##   _run_spawn_gate()
class_name DocumentCollectionState
extends Resource

## Document IDs the player has collected this run.
## StringName values only — no content strings. Array[StringName] round-trips
## correctly through ResourceSaver/ResourceLoader per ADR-0003 verification.
@export var collected: Array[StringName] = []
