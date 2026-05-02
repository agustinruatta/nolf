# res://src/gameplay/stealth/perception_cache.gd
#
# PerceptionCache — Typed struct holding the most-recent F.1 perception result.
#
# Each guard holds one _perception_cache instance. F.1 (Story 004) writes to it
# once per physics frame. Public accessors (has_los_to_player, etc.) read from
# it without issuing fresh raycasts — at most 1-physics-frame stale.
#
# Cold-start contract: initialized == false on spawn. Accessors return false-safe
# when initialized is false. F.1 sets initialized = true on first tick.
# On section reload or wake-up, F.1 resets initialized = false; the cache is
# re-populated on the next tick.
#
# Implements: Story SAI-003 (TR-SAI-017)
# GDD: design/gdd/stealth-ai.md §F.1 — Perception cache struct

class_name PerceptionCache extends RefCounted

## Whether F.1 has ticked at least once since spawn or reset.
## Accessors return false-safe when this is false (cold-start safety).
var initialized: bool = false

## Engine.get_physics_frames() value at the time of the last F.1 cache write.
## Used to detect stale cache entries (at most 1 frame old between ticks).
var frame_stamp: int = 0

## Whether the last F.1 LOS raycast to the player succeeded.
## False on cold-start (before F.1 has ticked).
var los_to_player: bool = false

## Eve's head position at the last F.1 cache write.
## Vector3.ZERO on cold-start.
var los_to_player_position: Vector3 = Vector3.ZERO

## LOS result per dead-guard body currently tracked in the vision cone.
## Key: instance_id (int) of the dead Guard node.
## Value: bool — true if F.1 raycast to that body succeeded.
## Populated by F.1 (Story 004); schema only here (post-VS body mechanics).
var los_to_dead_bodies: Dictionary[int, bool] = {}

## The AlertCause that drove the last sight-stimulus write.
## SAW_PLAYER when target is Eve; SAW_BODY when target is a dead guard.
## Defaults to SAW_PLAYER for the cold-start safe-false state.
var last_sight_stimulus_cause: StealthAI.AlertCause = StealthAI.AlertCause.SAW_PLAYER

## Eve's position at the last F.1 cache write where LOS succeeded.
## Used as the LKP source on AlertState transitions.
## Vector3.ZERO on cold-start.
var last_sight_position: Vector3 = Vector3.ZERO
