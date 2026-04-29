# res://src/core/settings/settings_service.gd
#
# SettingsService — settings.cfg owner + sole publisher of
# Events.setting_changed. Per `design/gdd/settings-accessibility.md` CR-3 +
# CR-9. Registered as autoload key `SettingsService` at line 10 of
# project.godot per ADR-0007 §Key Interfaces.
#
# Real behaviour: loads user://settings.cfg on boot; emits settings_loaded
# one-shot once boot-load completes; sole emitter of setting_changed for
# every category/name/value triple.
#
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands in the Settings &
# Accessibility production story.

extends Node


func _ready() -> void:
	pass
