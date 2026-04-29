# res://src/gameplay/failure_respawn/failure_respawn_service.gd
#
# FailureRespawnService — player_died → autosave → reload_current_section →
# respawn_triggered orchestrator. Per `design/gdd/failure-respawn.md` (CR-1).
# Registered as autoload key `FailureRespawn` at line 8 of project.godot per
# ADR-0007 §Key Interfaces.
#
# Real behaviour: subscribes to Events.player_died; assembles slot-0 autosave
# via SaveLoad; calls LevelStreamingService.reload_current_section; emits
# Events.respawn_triggered(section_id) once the section is restored.
#
# Position is load-bearing — MUST precede MissionLevelScripting at line 9
# because MLS subscribes to respawn_triggered from its own _ready() (per
# ADR-0007 §Cross-Autoload Reference Safety rule 3).
#
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands in the Failure & Respawn
# production story under the core layer epic.

extends Node


func _ready() -> void:
	pass
