# res://src/core/level_streaming/level_streaming_service.gd
#
# LevelStreamingService — section/level swap orchestration autoload. Per
# `design/gdd/level-streaming.md` CR-1. Registered as autoload key
# `LevelStreamingService` at line 5 of project.godot per ADR-0007 §Key
# Interfaces.
#
# Real behaviour: owns the 13-step section swap contract; pushes
# InputContext.LOADING; emits Events.section_entered / section_exited with
# TransitionReason payload; consumes SaveGame via register_restore_callback
# chain.
#
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands in the Level Streaming
# production story under the core layer epic.

extends Node


func _ready() -> void:
	pass
