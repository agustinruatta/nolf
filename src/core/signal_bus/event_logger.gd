# res://src/core/signal_bus/event_logger.gd
#
# EventLogger — debug-only signal-tracing autoload. Per ADR-0002 (Signal Bus +
# Event Taxonomy). Registered as autoload key `EventLogger` at line 2 of
# project.godot per ADR-0007 §Key Interfaces.
#
# This minimal implementation closes ADR-0002 G1 (emit → EventLogger prints →
# subscriber receives) and ADR-0007 G(b) (Cross-Autoload Reference Safety —
# EventLogger at line 2 successfully references Events at line 1 from its
# _ready() callback). The full implementation (subscribe to every Events
# signal, self-remove in non-debug builds, formatted log lines) lands in the
# Signal Bus production story.
#
# Per ADR-0007 §Cross-Autoload Reference Safety rule 2: this _ready() may
# reference autoloads at earlier line numbers. `Events` is at line 1; this
# script is at line 2. Reference is safe.

extends Node

const LOG_PREFIX: String = "[EventLogger]"


func _ready() -> void:
	# In debug builds, subscribe to the smoke-test signal. Real impl will
	# subscribe to every Events.* signal and add a self-remove in
	# non-debug builds via OS.is_debug_build().
	Events.smoke_test_pulse.connect(_on_smoke_test_pulse)


func _on_smoke_test_pulse(payload: int) -> void:
	print("%s smoke_test_pulse received: payload=%d" % [LOG_PREFIX, payload])
