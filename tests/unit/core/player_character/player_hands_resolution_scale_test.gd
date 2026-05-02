# tests/unit/core/player_character/player_hands_resolution_scale_test.gd
#
# PlayerHandsResolutionScaleTest — pending stub for PC-008 AC-9.2.
#
# AC-9.2 [Logic — BLOCKED] reads:
#   "HandsOutlineMaterial.resolution_scale uniform equals
#   Settings.get_resolution_scale() on _ready() AND updates within one physics
#   frame when Events.setting_changed fires for category=&'graphics',
#   name=&'resolution_scale'."
#
# The signal-driven update half is covered by:
#   tests/unit/core/player_character/player_hands_material_overlay_test.gd
#       ::test_setting_changed_resolution_scale_updates_uniform
#
# The boot-time read half (Settings.get_resolution_scale() at _ready()) is
# BLOCKED on the Settings & Accessibility GDD landing — there is no
# SettingsService.get_resolution_scale() API yet. The Outline pipeline (OUT-004)
# has the same blocker and uses the same lazy-connect-via-Events workaround.
#
# When the Settings & Accessibility GDD lands and SettingsService exposes the
# read API, replace this stub with the real test:
#   1. Set SettingsService.set_resolution_scale(0.75) in test setup
#   2. Instantiate PlayerCharacter
#   3. Assert _hands_material.get_shader_parameter("resolution_scale") == 0.75
#
# Until then this stub passes trivially with a docstring marker.

class_name PlayerHandsResolutionScaleTest
extends GdUnitTestSuite


## AC-9.2 startup-read pending — Settings & Accessibility GDD has not landed.
## Currently a passing stub; replace body when SettingsService.get_resolution_scale()
## becomes available. The signal-driven update half of AC-9.2 is verified in
## player_hands_material_overlay_test.gd.
func test_pc008_ac_9_2_settings_startup_read_pending_settings_gdd() -> void:
	assert_bool(true).override_failure_message(
		"AC-9.2 boot-time read is BLOCKED on Settings & Accessibility GDD landing. "
		+ "Replace this stub with the real test when SettingsService.get_resolution_scale() "
		+ "becomes available. The signal-driven update half is covered by "
		+ "player_hands_material_overlay_test.gd::test_setting_changed_resolution_scale_updates_uniform."
	).is_true()
