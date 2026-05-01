# res://src/core/save_load/states/inventory_state.gd
#
# InventoryState — saved inventory state per ADR-0003 §Key Interfaces +
# Inventory & Gadgets GDD. Per Inventory CR-11, ammo dictionaries are untyped
# Dictionary (NOT TypedDictionary[StringName, int]) because TypedDictionary
# ResourceSaver stability is unverified post-cutoff.

class_name InventoryState
extends Resource

## Currently equipped gadget ID (e.g., &"silenced_p38"); &"" when empty.
@export var equipped_gadget: StringName = &""

## StringName -> int (untyped Dictionary per Inventory CR-11; TypedDictionary
## avoided pending ResourceSaver round-trip verification post-cutoff).
@export var ammo_magazine: Dictionary = {}

## StringName -> int (untyped Dictionary per Inventory CR-11; TypedDictionary
## avoided pending ResourceSaver round-trip verification post-cutoff).
@export var ammo_reserve: Dictionary = {}

## StringName -> bool (untyped Dictionary; documents which gadgets the player
## has collected this run).
@export var collected_gadget_flags: Dictionary = {}

## Whether the level-supplied mission pickup is still available.
@export var mission_pickup_available: bool = false
