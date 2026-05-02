# tests/unit/core/player_character/player_damage_rounding_guard_test.gd
#
# PlayerDamageRoundingGuardTest — Story PC-006 AC-5.2.
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-5.2: rounding boundary parametrized over {0.3, 0.49, 0.5, 1.5}:
#     - 0.3 → no change, 0 signals
#     - 0.49 → no change, 0 signals
#     - 0.5 → -1 HP, both signals fire
#     - 1.5 → -2 HP, both signals fire (raw 1.5 in player_damaged.amount)
#
# Godot 4.6 round-half-away-from-zero semantics: round(0.5) == 1.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerDamageRoundingGuardTest
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


# ── AC-5.2: 0.3 damage rounds to 0 → no health change, no signal ───────────

func test_apply_damage_0_3_is_dropped() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	var signal_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): signal_count[0] += 1
	var on_changed: Callable = func(_c, _m): signal_count[0] += 1
	Events.player_damaged.connect(on_damaged)
	Events.player_health_changed.connect(on_changed)

	player.apply_damage(0.3, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)
	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).override_failure_message(
		"AC-5.2: 0.3 damage rounds to 0; health must be unchanged."
	).is_equal(100)
	assert_int(signal_count[0]).override_failure_message(
		"AC-5.2: 0.3 damage must emit zero signals. Got %d." % signal_count[0]
	).is_equal(0)


# ── AC-5.2: 0.49 damage rounds to 0 → no change, no signal ─────────────────

func test_apply_damage_0_49_is_dropped() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	var signal_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): signal_count[0] += 1
	Events.player_damaged.connect(on_damaged)

	player.apply_damage(0.49, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)

	assert_int(player.health).is_equal(100)
	assert_int(signal_count[0]).override_failure_message(
		"AC-5.2: 0.49 damage must emit zero signals (rounds to 0)."
	).is_equal(0)


# ── AC-5.2: 0.5 damage rounds to 1 → -1 HP, both signals fire ──────────────

func test_apply_damage_0_5_rounds_to_one_via_round_half_away_from_zero() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var damaged_count: Array[int] = [0]
	var changed_count: Array[int] = [0]
	var captured_amount: Array[float] = [0.0]
	var on_damaged: Callable = func(amount: float, _s, _c):
		damaged_count[0] += 1
		captured_amount[0] = amount
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1

	Events.player_damaged.connect(on_damaged)
	Events.player_health_changed.connect(on_changed)

	player.apply_damage(0.5, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)
	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).override_failure_message(
		"AC-5.2 boundary: round(0.5) = 1 (round-half-away-from-zero); health = 99."
	).is_equal(99)
	assert_int(damaged_count[0]).is_equal(1)
	assert_int(changed_count[0]).is_equal(1)
	# Raw amount preserved in payload (not the rounded value)
	assert_float(captured_amount[0]).override_failure_message(
		"AC-5.2: player_damaged.amount must carry the RAW float (0.5), not the rounded int."
	).is_equal_approx(0.5, 0.001)


# ── AC-5.2: 1.5 damage rounds to 2 → -2 HP, raw 1.5 in payload ─────────────

func test_apply_damage_1_5_rounds_to_two() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var captured_amount: Array[float] = [0.0]
	var on_damaged: Callable = func(amount: float, _s, _c):
		captured_amount[0] = amount
	Events.player_damaged.connect(on_damaged)

	player.apply_damage(1.5, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)

	assert_int(player.health).override_failure_message(
		"AC-5.2: round(1.5) = 2; health = 98."
	).is_equal(98)
	assert_float(captured_amount[0]).override_failure_message(
		"AC-5.2: payload amount must be raw 1.5, not rounded."
	).is_equal_approx(1.5, 0.001)


# ── AC-5.2: zero damage emits push_warning, no signals ─────────────────────

func test_apply_damage_zero_amount_is_ignored() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	var signal_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): signal_count[0] += 1
	Events.player_damaged.connect(on_damaged)

	player.apply_damage(0.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)

	assert_int(player.health).is_equal(100)
	assert_int(signal_count[0]).is_equal(0)


# ── AC-5.2: negative damage emits push_warning, no signals ─────────────────

func test_apply_damage_negative_amount_is_ignored() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	var signal_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): signal_count[0] += 1
	Events.player_damaged.connect(on_damaged)

	player.apply_damage(-10.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)

	assert_int(player.health).is_equal(100)
	assert_int(signal_count[0]).override_failure_message(
		"AC-5.2: negative damage must NOT change health (no smuggled heal). Signals must be 0."
	).is_equal(0)
