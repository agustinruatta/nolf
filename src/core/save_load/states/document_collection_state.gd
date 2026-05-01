# res://src/core/save_load/states/document_collection_state.gd
#
# DocumentCollectionState — saved document collection state per ADR-0003
# §Key Interfaces + Document Collection GDD.

class_name DocumentCollectionState
extends Resource

## Document IDs the player has collected this run.
@export var collected: Array[StringName] = []
