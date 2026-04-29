# res://src/core/rendering/post_process_stack.gd
#
# PostProcessStack — sepia dim + outline post-process owner. Per ADR-0004
# Implementation Guideline 7 + `design/gdd/post-process-stack.md` §5.
# Registered as autoload key `PostProcessStack` at line 6 of project.godot
# per ADR-0007 §Key Interfaces.
#
# Real behaviour: owns sepia-dim CanvasLayer state; subscribes to
# Events.setting_changed for resolution_scale; coordinates with the
# CompositorEffect outline pass (per ADR-0001).
#
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands during ADR-0001 / 0004
# verification or in the Post-Process Stack production story.

extends Node


func _ready() -> void:
	pass
