# tests/unit/core/player_character/player_damage_cancel_interact_test.gd
#
# PlayerDamageCancelInteractTest — Story PC-006 AC-damage-cancel-interact (E.6).
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-damage-cancel-interact (E.6): if amount >= interact_damage_cancel_threshold
#   (default 10.0 HP) AND _is_hand_busy == true, the in-flight interact tween
#   is killed and _is_hand_busy is cleared in the SAME stack frame as the kill
#   call. player_interacted is NOT emitted for the cancelled interact.
#
# DESIGN
#   PC-005 owns _interact_reach_tween creation; PC-006 only verifies the
#   cancel-on-damage path. Tests directly set _is_hand_busy = true and create
#   a stub Tween, then verify apply_damage clears the flag and kills the tween.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerDamageCancelInteractTest
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


## Creates a real Tween bound to the player so kill() / is_valid() behave
## correctly. The tween itself doesn't need to do meaningful work — it just
## needs to be is_valid() == true so the test can verify kill() ran.
func _make_in_flight_tween(player: PlayerCharacter) -> Tween:
	var tween: Tween = player.create_tween()
	tween.tween_interval(10.0)  # long-running so it stays in-flight during the test
	return tween


# ── E.6: damage at threshold cancels in-flight interact ─────────────────────

func test_damage_at_threshold_cancels_interact_and_clears_busy_flag() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	# Simulate an interact in flight (PC-005 normally writes these fields)
	player._is_hand_busy = true
	player._interact_reach_tween = _make_in_flight_tween(player)
	assert_bool(player._interact_reach_tween.is_valid()).is_true()

	# Act — damage at exactly the threshold (10 HP default)
	player.apply_damage(player.interact_damage_cancel_threshold, source, CombatSystemNode.DamageType.TEST)

	# Assert — flag cleared in same stack frame; tween killed
	assert_bool(player._is_hand_busy).override_failure_message(
		"E.6: _is_hand_busy must be false after threshold-damage cancel."
	).is_false()
	assert_bool(player._interact_reach_tween.is_valid()).override_failure_message(
		"E.6: _interact_reach_tween.is_valid() must be false after kill() (canceled)."
	).is_false()


# ── E.6: damage above threshold also cancels ───────────────────────────────

func test_damage_above_threshold_cancels_interact() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	player._is_hand_busy = true
	player._interact_reach_tween = _make_in_flight_tween(player)

	# Damage well above threshold
	player.apply_damage(50.0, source, CombatSystemNode.DamageType.TEST)

	assert_bool(player._is_hand_busy).is_false()
	assert_bool(player._interact_reach_tween.is_valid()).is_false()


# ── E.6: sub-threshold damage does NOT cancel interact ──────────────────────

## Documents the contract: only damage >= threshold triggers the cancel.
## Smaller damage tickles the player but does not interrupt the interact.
func test_sub_threshold_damage_does_not_cancel_interact() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	player._is_hand_busy = true
	player._interact_reach_tween = _make_in_flight_tween(player)

	# Damage below threshold (5 < default 10)
	player.apply_damage(5.0, source, CombatSystemNode.DamageType.TEST)

	# Flag and tween untouched
	assert_bool(player._is_hand_busy).override_failure_message(
		"E.6: sub-threshold damage must NOT cancel interact. _is_hand_busy must stay true."
	).is_true()
	assert_bool(player._interact_reach_tween.is_valid()).override_failure_message(
		"E.6: sub-threshold damage must NOT kill the interact tween."
	).is_true()


# ── E.6: damage when not in interact does nothing extra ─────────────────────

## When _is_hand_busy is false, apply_damage takes the normal path. No tween
## kill, no flag toggle (it stays false). Verifies the cancel logic is gated
## on the busy flag.
func test_damage_when_not_in_interact_takes_normal_path() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	# _is_hand_busy starts false; no tween in flight
	assert_bool(player._is_hand_busy).is_false()

	player.apply_damage(15.0, source, CombatSystemNode.DamageType.TEST)

	# Damage applied normally; flag still false
	assert_int(player.health).is_equal(85)
	assert_bool(player._is_hand_busy).is_false()


# ── E.6: cancelled interact does NOT emit player_interacted ─────────────────

## Tests that no player_interacted signal fires from the cancel path.
## (player_interacted is part of the interact-completion path; cancel must
## NOT trigger it.)
func test_cancelled_interact_does_not_emit_player_interacted() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	player._is_hand_busy = true
	player._interact_reach_tween = _make_in_flight_tween(player)

	var interacted_count: Array[int] = [0]
	var on_interacted: Callable = func(_target): interacted_count[0] += 1
	Events.player_interacted.connect(on_interacted)

	player.apply_damage(15.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_interacted.disconnect(on_interacted)

	assert_int(interacted_count[0]).override_failure_message(
		"E.6: cancelled interact must NOT fire player_interacted. Got %d emissions." % interacted_count[0]
	).is_equal(0)
