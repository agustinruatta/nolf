# res://src/core/save_load/save_load_service.gd
#
# SaveLoad service — persistence autoload. Per ADR-0003 (Save Format Contract).
# Registered as autoload key `SaveLoad` at line 3 of project.godot per ADR-0007
# §Key Interfaces.
#
# Real behaviour (per ADR-0003): owns SaveGame Resource serialization via
# ResourceSaver.save(... FLAG_COMPRESS); writes via temp-file + atomic
# DirAccess.rename; emits Events.game_saved / game_loaded / save_failed.
#
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands during ADR-0003
# verification (Group 2.1) or in the SaveLoad production story.

extends Node


func _ready() -> void:
	pass
