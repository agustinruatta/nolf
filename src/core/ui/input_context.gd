# res://src/core/ui/input_context.gd
#
# InputContext — modal input routing autoload. Per ADR-0004 (UI Framework).
# Registered as autoload key `InputContext` at line 4 of project.godot per
# ADR-0007 §Key Interfaces.
#
# Real behaviour (per ADR-0004): owns the input-context stack (GAMEPLAY,
# PAUSE, MENU, MODAL, LOADING, etc.) and routes input by mapping the active
# context to the InputMap action set.
#
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands during ADR-0004
# verification (Group 2.2) or in the UI Framework production story.

extends Node


func _ready() -> void:
	pass
