# res://src/audio/audio_manager.gd
#
# AudioManager — scene-tree Node that owns the 5-bus AudioServer structure and
# pre-allocates the SFX pool. Lives as a direct child of the persistent root
# scene (NOT an autoload — see ADR-0007 §Key Interfaces and the GDD Rule 1).
#
# RESPONSIBILITIES (this story, AUD-001):
#   • Ensure 5 named AudioServer buses exist (Music, SFX, Ambient, Voice, UI).
#   • Pre-allocate 16 AudioStreamPlayer3D nodes in the SFX pool, all routed to
#     the SFX bus, added as children so they are freed automatically with this
#     node (AC-5).
#
# OUT OF SCOPE in AUD-001 (deferred to later stories):
#   • Signal Bus subscriptions — AUD-002
#   • Music layer players, ambient loop, reverb swap — AUD-003
#   • VO ducking, document overlay mute, respawn cut — AUD-004
#   • Footstep variant routing, COMBAT stinger scheduling — AUD-005
#
# DESIGN RULES ENFORCED:
#   GDD Rule 1 — no AudioStreamPlayer may route to Master bus.
#   GDD Rule 9 — AudioStreamPlayer.new() at runtime (per-SFX-event) is forbidden;
#                the pre-allocation below is the one-time pool init, which is
#                explicitly permitted.
#
# Implements: Story AUD-001
# Requirements: TR-AUD-002, TR-AUD-003
# ADRs: ADR-0007 (Autoload Load Order — AudioManager is NOT in the autoload chain)
#       ADR-0002 (Signal Bus — subscriptions deferred to AUD-002)

class_name AudioManager
extends Node

# ── Constants ──────────────────────────────────────────────────────────────

## The 5 named buses this manager guarantees exist after _ready().
## Order reflects the GDD §Volume Contract; Master (index 0) is implicit.
const BUS_NAMES: Array[StringName] = [&"Music", &"SFX", &"Ambient", &"Voice", &"UI"]

## Number of AudioStreamPlayer3D nodes pre-allocated in the SFX pool.
## GDD §Pool Contract: 16 voices covers simultaneous SFX playback budget.
const SFX_POOL_SIZE: int = 16

# ── Private state ──────────────────────────────────────────────────────────

## Pre-allocated SFX voice pool. All entries are children of this node so they
## are freed automatically when AudioManager exits the tree (AC-5).
## Never allocate new entries at runtime (GDD Rule 9).
var _sfx_pool: Array[AudioStreamPlayer3D] = []

# ── Lifecycle ──────────────────────────────────────────────────────────────

## Initialise the audio infrastructure.
## Sets up the 5 named buses, then pre-allocates the SFX pool. No autoload
## references — no dependency on load order. Node._ready is virtual with no
## default body, so super._ready() is intentionally not called (parser-rejected
## in GDScript 4 when the parent has no concrete implementation).
func _ready() -> void:
	_setup_buses()
	_setup_sfx_pool()


# ── Private setup ──────────────────────────────────────────────────────────

## Ensures the 5 named AudioServer buses exist.
##
## Idempotent: skips any bus whose name already exists (safe across multiple
## test runs and safe when project.godot has the buses pre-declared). Master
## bus at index 0 is always present in Godot and is never renamed.
##
## In production builds the buses are declared in Project Settings (Audio tab)
## so they persist across loads. This method is both the production fallback
## and the headless-test bootstrap (headless Godot starts with only Master).
func _setup_buses() -> void:
	for bus_name: StringName in BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)


## Pre-allocates SFX_POOL_SIZE AudioStreamPlayer3D nodes and adds them as
## children so they share this node's lifetime (AC-5).
##
## Pool parameters follow the GDD §SFX Voice Contract:
##   • bus = &"SFX" — never Master (GDD Rule 1)
##   • ATTENUATION_INVERSE_DISTANCE — standard distance falloff
##   • max_distance = 50.0 m — culling radius per GDD §Audio Budget
##   • unit_size = 10.0 m — reference distance for 0 dB (GDD §SFX Attenuation)
func _setup_sfx_pool() -> void:
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.bus = &"SFX"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_distance = 50.0
		player.unit_size = 10.0
		add_child(player)
		_sfx_pool.append(player)
