# tests/fixtures/level_streaming/violation_bypass_protocol.gd
#
# DELIBERATE VIOLATION FIXTURE — do NOT import into production code.
#
# Contains a simulated bypass_thirteen_step_protocol violation: a direct
# change_scene_to_file call outside of the authorised LSS / main entry point
# files. Lives under tests/fixtures/ — explicitly excluded from production
# lint scope but explicitly INCLUDED in the AC-8 fixture-scan test.
#
# Story LS-009. GDD CR-5. ADR-0007.

extends Node


# Intentional violation — fixture-only code, never executed.
# Matches the lint regex `\bchange_scene_to_(file|packed)\s*\(`.
func _illegal_bypass_demo() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
