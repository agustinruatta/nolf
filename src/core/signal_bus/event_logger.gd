# res://src/core/signal_bus/event_logger.gd
#
# EventLogger — debug-only signal-tracing autoload. Per ADR-0002 (Signal Bus +
# Event Taxonomy). Registered as autoload key `EventLogger` at line 2 of
# project.godot per ADR-0007 §Key Interfaces.
#
# Real behaviour (per ADR-0002): connects to every Events signal at _ready()
# and prints emissions to the console; self-removes in non-debug builds via
# OS.is_debug_build().
#
# This file is a Sprint 01 verification-spike stub — pass-through so that
# project.godot's autoload entry resolves to a script and Godot stops logging
# "Script not found". Real implementation lands during ADR-0002 verification
# (Sprint 01 Group 2.4 smoke test pipeline) or in the Signal Bus production
# story under the foundation epic.

extends Node


func _ready() -> void:
	pass
