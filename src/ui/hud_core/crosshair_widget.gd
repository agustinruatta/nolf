# res://src/ui/hud_core/crosshair_widget.gd
#
# CrosshairWidget — Control subclass that renders the HUD's center crosshair.
#
# HC-001 SCAFFOLD ONLY — _draw() body is implemented in HC-003.
# This stub establishes the node type, focus/mouse settings, and the
# enabled-flag wiring (settings.crosshair_enabled subscriber + initial state).
# The actual draw call lives in the next story.

class_name CrosshairWidget extends Control

var _enabled: bool = SettingsDefaults.CROSSHAIR_ENABLED


func _ready() -> void:
	# HUD Control discipline — never receives input or focus (ADR-0004 §IG8).
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## HC-001 stub. Body lands in HC-003.
func _draw() -> void:
	pass
