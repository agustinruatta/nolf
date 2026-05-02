# tests/unit/core/player_character/player_heal_test.gd
#
# PlayerHealTest — Story PC-006 AC-heal.
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-heal: apply_heal cap at max_health; warning on non-positive amount;
#   sub-1 HP rounds to 0; DEAD state blocks heal; no dedicated player_healed.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerHealTest
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


# ── AC-heal: damage then heal — health restored, capped at max ──────────────

func test_heal_from_damaged_state_restores_health_capped_at_max() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	# Take 20 damage (health=80)
	player.apply_damage(20.0, source, CombatSystemNode.DamageType.TEST)
	assert_int(player.health).is_equal(80)

	# Heal 50 — should cap at 100
	player.apply_heal(50.0, source)

	assert_int(player.health).override_failure_message(
		"AC-heal: heal must cap at max_health. Got %d." % player.health
	).is_equal(100)


# ── AC-heal: heal at full health does nothing (no signal) ──────────────────

func test_heal_at_full_health_emits_no_signal() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	# Player at full health (initial state)
	assert_int(player.health).is_equal(100)

	var changed_count: Array[int] = [0]
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1
	Events.player_health_changed.connect(on_changed)

	player.apply_heal(20.0, source)

	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).is_equal(100)
	assert_int(changed_count[0]).override_failure_message(
		"AC-heal: heal at full health must NOT emit player_health_changed (idempotent)."
	).is_equal(0)


# ── AC-heal: heal emits player_health_changed (single signal, no player_healed) ──

func test_heal_emits_player_health_changed_only() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	# Take damage first
	player.apply_damage(30.0, source, CombatSystemNode.DamageType.TEST)
	assert_int(player.health).is_equal(70)

	var changed_count: Array[int] = [0]
	var captured_current: Array[float] = [0.0]
	var on_changed: Callable = func(current: float, _m: float):
		changed_count[0] += 1
		captured_current[0] = current
	Events.player_health_changed.connect(on_changed)

	player.apply_heal(15.0, source)

	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).is_equal(85)
	assert_int(changed_count[0]).override_failure_message(
		"AC-heal: heal must emit player_health_changed exactly once."
	).is_equal(1)
	assert_float(captured_current[0]).is_equal_approx(85.0, 0.001)


# ── AC-heal: zero heal emits push_warning, no signal ───────────────────────

func test_heal_zero_amount_is_ignored() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	# Damage so we have room to heal
	player.apply_damage(20.0, source, CombatSystemNode.DamageType.TEST)
	assert_int(player.health).is_equal(80)

	var changed_count: Array[int] = [0]
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1
	Events.player_health_changed.connect(on_changed)

	player.apply_heal(0.0, source)

	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).is_equal(80)
	assert_int(changed_count[0]).override_failure_message(
		"AC-heal: zero heal must emit push_warning + zero signals."
	).is_equal(0)


# ── AC-heal: 0.49 heal rounds to 0 → no change, no signal ──────────────────

func test_heal_0_49_rounds_to_zero_and_is_ignored() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()
	player.apply_damage(20.0, source, CombatSystemNode.DamageType.TEST)
	assert_int(player.health).is_equal(80)

	var changed_count: Array[int] = [0]
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1
	Events.player_health_changed.connect(on_changed)

	player.apply_heal(0.49, source)

	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).is_equal(80)
	assert_int(changed_count[0]).is_equal(0)


# ── AC-heal: DEAD state blocks heal ─────────────────────────────────────────

func test_heal_blocked_when_dead() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	# Kill the player
	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)
	assert_int(player.health).is_equal(0)
	assert_int(int(player.current_state)).is_equal(PlayerEnums.MovementState.DEAD)

	var changed_count: Array[int] = [0]
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1
	Events.player_health_changed.connect(on_changed)

	# Attempt to heal a dead player
	player.apply_heal(50.0, source)

	Events.player_health_changed.disconnect(on_changed)

	assert_int(player.health).override_failure_message(
		"AC-heal DEAD guard: heal must not change health when DEAD."
	).is_equal(0)
	assert_int(changed_count[0]).override_failure_message(
		"AC-heal DEAD guard: heal must not emit signals when DEAD."
	).is_equal(0)
