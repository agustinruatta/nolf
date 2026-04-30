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
	# smoke_test_pulse removed (SB-001). Full EventLogger implementation
	# (subscribe to all Events.* signals, self-remove in non-debug builds)
	# lands in Story SB-003.
	pass
