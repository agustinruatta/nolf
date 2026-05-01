# tests/unit/core/footstep_component/stubs/stub_player_character.gd
#
# Test fixture builder for FootstepComponent cadence tests.
#
# DEPRECATED — see footstep_cadence_walk_test.gd's `_build_grounded_player()`
# helper. The original plan to subclass PlayerCharacter and override
# `is_on_floor()` was blocked by GDScript's native-method-override warning
# (treated as error in headless test mode).
#
# Replacement pattern: tests load PlayerCharacter.tscn, build a StaticBody3D
# floor, position the player on it, and run one move_and_slide() to register
# floor contact. After that, `is_on_floor()` returns true throughout the test
# (until the next move_and_slide call). FootstepComponent reads the cached
# on-floor flag via `_player.is_on_floor()` and behaves correctly.

extends Node
