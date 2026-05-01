# res://src/core/save_load/states/player_state.gd
#
# PlayerState — saved player character state per ADR-0003 §Key Interfaces +
# Player Character GDD. Owned by Player Character epic; populated on save by
# the player save action and restored on load.

class_name PlayerState
extends Resource

## World-space position at save time, in metres.
@export var position: Vector3 = Vector3.ZERO

## World-space Euler rotation at save time, in radians (XYZ order).
@export var rotation: Vector3 = Vector3.ZERO

## Current health in points (0 = dead). Range and max are owned by Player
## Character GDD; the save layer stores whatever value the consumer system
## supplies and restores it verbatim.
@export var health: int = 0

## PlayerCharacter.MovementState enum value (int — enum lives on the consumer
## class per ADR-0002 IG 2; we store the int value here for serialization).
@export var current_state: int = 0
