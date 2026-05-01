# res://src/gameplay/player/noise_event.gd
#
# NoiseEvent — the player's instantaneous noise emission, polled by Stealth
# AI's aggregate perception loop at 80 Hz. Per Player Character GDD §F.4.
#
# In-place mutation is intentional (zero-allocation at 80 Hz aggregate AI
# polling). Callers MUST copy fields before the next physics frame. DO NOT
# "fix" this by allocating a new NoiseEvent per spike — see GDD F.4.
#
# RefCounted (NOT Resource) — the Resource allocator overhead at 80 Hz is
# unacceptable, and we do not need ResourceSaver/ResourceLoader semantics
# (NoiseEvent is ephemeral runtime data, never persisted to disk).
#
# Implements: Story PC-001 (scene root scaffold)

class_name NoiseEvent
extends RefCounted

## The kind of noise emitted (footstep variant or jump/landing variant).
@export var type: PlayerEnums.NoiseType = PlayerEnums.NoiseType.FOOTSTEP_SOFT

## Audible radius in metres. Stealth AI compares against guard hearing range.
@export var radius_m: float = 0.0

## World-space origin of the noise. Stealth AI uses this for percept location.
@export var origin: Vector3 = Vector3.ZERO
