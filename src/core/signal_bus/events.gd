# res://src/core/signal_bus/events.gd
#
# Signal Bus — typed-signal hub. Per ADR-0002 (Signal Bus + Event Taxonomy).
# Registered as autoload key `Events` at line 1 of project.godot per ADR-0007
# §Key Interfaces.
#
# class_name / autoload-key split (per ADR-0002 OQ-CD-1 amendment):
#   class_name = SignalBusEvents  (used for parse-time references like
#                                  SignalBusEvents.SomeEnum if added)
#   autoload key = Events         (used for emit/connect call sites:
#                                  Events.player_damaged.emit(...))
#
# Subscribers connect via Events.<signal>.connect(<callable>) at their own
# _ready(). Per ADR-0007 §Cross-Autoload Reference Safety, only autoloads at
# earlier line numbers may be referenced from this script's _ready().
#
# ─── SKELETON STATUS ──────────────────────────────────────────────────────
# This is a verification skeleton, not the full taxonomy. The signals below
# are a representative subset selected to:
#   1. Verify the autoload registers correctly (ADR-0007 G(a)).
#   2. Validate the emit → EventLogger prints → subscriber receives pipeline
#      (ADR-0002 G1 / ADR-0007 G(b)).
#   3. Use only built-in types so this file parses before its consumer classes
#      (StealthAI, CombatSystemNode, LevelStreamingService, etc.) are written.
#
# The full 30+ signal taxonomy lands later — when each consumer class is
# implemented, the corresponding signal(s) are added here in a paired commit.
# See ADR-0002 §Key Interfaces for the full intended signal list.

class_name SignalBusEvents extends Node

# ─── Combat domain (skeleton subset) ────────────────────────────────
signal player_damaged(amount: float, source: Node, is_critical: bool)
signal player_health_changed(current: float, max_health: float)

# ─── Player domain (skeleton subset) ────────────────────────────────
signal player_interacted(target: Node3D)
signal player_footstep(surface: StringName, noise_radius_m: float)

# ─── Documents domain (skeleton subset) ─────────────────────────────
signal document_collected(document_id: StringName)

# ─── Save/Load domain (skeleton subset) ─────────────────────────────
# `reason` is a plain int here; will be retyped to SaveLoad.FailureReason once
# the SaveLoad service is implemented (paired with ADR-0003 verification).
signal game_saved(slot: int, section_id: StringName)
signal game_loaded(slot: int)
signal save_failed(reason: int)

# ─── Skeleton self-test signal ──────────────────────────────────────
# Used only by prototypes/verification-spike/signal_bus_smoke.tscn to validate
# the emit → EventLogger → subscriber pipeline. Removed when the skeleton is
# fleshed out into the full taxonomy.
signal smoke_test_pulse(payload: int)


func _ready() -> void:
	# Skeleton has no init logic. Real Events autoload may later register
	# debug-only signal-tracing in DEBUG builds (per ADR-0002), but per
	# ADR-0007 §Cross-Autoload Reference Safety rule 2, this _ready() may NOT
	# reference any later autoload (EventLogger at line 2, etc.) by name.
	# EventLogger subscribes to Events; not the other way around.
	pass
