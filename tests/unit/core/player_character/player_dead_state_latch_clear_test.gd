# tests/unit/core/player_character/player_dead_state_latch_clear_test.gd
#
# PlayerDeadStateLatchClearTest — Story PC-006 AC-latch-clear (E.13).
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-latch-clear (E.13): when apply_damage transitions the player to DEAD,
#   the existing _latched_event noise spike is cleared. Verified via
#   get_noise_event() == null AND get_noise_level() == 0.0 on the same
#   post-damage frame.
#
# DESIGN
#   This test directly mutates `_latched_event` to simulate a JUMP_TAKEOFF
#   spike (Story PC-004 owns the spike-emission path; PC-006 only owns the
#   DEAD-on-damage clear path). Then apply_damage(999) is called and the
#   accessors are checked.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerDeadStateLatchClearTest
extends GdUnitTestSuite

const _PLAYER_SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"


func _make_player() -> PlayerCharacter:
	var scene: PackedScene = load(_PLAYER_SCENE_PATH) as PackedScene
	var player: PlayerCharacter = scene.instantiate() as PlayerCharacter
	add_child(player)
	auto_free(player)
	return player


func _make_source() -> Node:
	var src: Node = Node.new()
	add_child(src)
	auto_free(src)
	return src


# ── AC-latch-clear: lethal damage clears the noise latch ───────────────────

func test_dead_transition_clears_latched_noise_event() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	# Simulate a latched JUMP_TAKEOFF spike (PC-004 owns the spike-write path;
	# PC-006 tests only verify the clear behaviour on DEAD transition).
	var spike: NoiseEvent = NoiseEvent.new()
	spike.type = PlayerEnums.NoiseType.JUMP_TAKEOFF
	spike.radius_m = 8.0
	player._latched_event = spike
	player._latch_frames_remaining = 9  # arbitrary positive value

	# Pre-condition: latch is active
	assert_object(player.get_noise_event()).override_failure_message(
		"AC-latch-clear pre: spike must be latched before lethal damage."
	).is_not_null()

	# Act — lethal damage triggers DEAD transition + latch clear (E.13)
	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)

	# Assert — DEAD state + latch fully cleared
	assert_int(int(player.current_state)).is_equal(PlayerEnums.MovementState.DEAD)
	assert_object(player.get_noise_event()).override_failure_message(
		"AC-latch-clear: get_noise_event() must return null after DEAD transition (E.13)."
	).is_null()
	# get_noise_level() returns 0.0 when DEAD (per existing PlayerCharacter contract).
	assert_float(player.get_noise_level()).override_failure_message(
		"AC-latch-clear: get_noise_level() must return 0.0 in DEAD state."
	).is_equal_approx(0.0, 0.001)


# ── AC-latch-clear: latch frames remaining reset to 0 ──────────────────────

func test_dead_transition_resets_latch_frames_remaining() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var spike: NoiseEvent = NoiseEvent.new()
	spike.type = PlayerEnums.NoiseType.JUMP_TAKEOFF
	spike.radius_m = 8.0
	player._latched_event = spike
	player._latch_frames_remaining = 9

	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)

	assert_int(player._latch_frames_remaining).override_failure_message(
		"AC-latch-clear: _latch_frames_remaining must be reset to 0 on DEAD transition."
	).is_equal(0)


# ── AC-latch-clear: non-lethal damage does NOT clear an active latch ───────

## Documents the contract: the latch-clear is tied to the DEAD transition,
## not to receiving damage. Sub-lethal damage must leave the latch intact
## (Story PC-004 auto-expiry remains the sole non-DEAD clear mechanism).
func test_non_lethal_damage_does_not_clear_active_latch() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var spike: NoiseEvent = NoiseEvent.new()
	spike.type = PlayerEnums.NoiseType.JUMP_TAKEOFF
	spike.radius_m = 8.0
	player._latched_event = spike
	player._latch_frames_remaining = 9

	# Take 25 damage — non-lethal; player remains alive
	player.apply_damage(25.0, source, CombatSystemNode.DamageType.TEST)

	assert_int(int(player.current_state)).is_not_equal(PlayerEnums.MovementState.DEAD)
	assert_object(player.get_noise_event()).override_failure_message(
		"AC-latch-clear: non-lethal damage must NOT clear the active latch (only DEAD transition clears)."
	).is_not_null()
