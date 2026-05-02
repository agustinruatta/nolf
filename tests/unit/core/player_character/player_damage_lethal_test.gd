# tests/unit/core/player_character/player_damage_lethal_test.gd
#
# PlayerDamageLethalTest — Story PC-006 AC-5.3.
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-5.3: lethal damage transitions to DEAD and fires player_died exactly once.
#     - apply_damage(999.0) → health=0, current_state=DEAD, player_died fires
#     - subsequent apply_damage calls emit zero signals (DEAD-state guard)
#     - cause == damage_type_to_death_cause(DamageType.TEST) — UNKNOWN at MVP
#   E.7 (simultaneous lethal damage): two lethal calls on same frame → player_died
#     fires exactly once.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerDamageLethalTest
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


# ── AC-5.3: lethal damage transitions to DEAD ───────────────────────────────

func test_lethal_damage_transitions_to_dead_state() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)

	assert_int(player.health).override_failure_message(
		"AC-5.3: lethal damage must clamp health to 0."
	).is_equal(0)
	assert_int(int(player.current_state)).override_failure_message(
		"AC-5.3: current_state must transition to DEAD on lethal damage."
	).is_equal(PlayerEnums.MovementState.DEAD)


# ── AC-5.3: player_died fires exactly once with correct cause ──────────────

func test_lethal_damage_fires_player_died_once_with_correct_cause() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var died_count: Array[int] = [0]
	var captured_cause: Array[int] = [-1]
	var on_died: Callable = func(cause: int):
		died_count[0] += 1
		captured_cause[0] = cause
	Events.player_died.connect(on_died)

	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_died.disconnect(on_died)

	assert_int(died_count[0]).override_failure_message(
		"AC-5.3: player_died must fire exactly once."
	).is_equal(1)
	# Stub: damage_type_to_death_cause returns UNKNOWN (0) at MVP
	assert_int(captured_cause[0]).override_failure_message(
		"AC-5.3: cause must equal damage_type_to_death_cause(DamageType.TEST) = UNKNOWN."
	).is_equal(int(CombatSystemNode.DeathCause.UNKNOWN))


# ── AC-5.3: DEAD-state guard — subsequent apply_damage emits zero signals ──

func test_dead_state_guard_blocks_subsequent_damage() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	# Kill the player first
	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)
	assert_int(int(player.current_state)).is_equal(PlayerEnums.MovementState.DEAD)

	# Now connect spies and try to damage again
	var damaged_count: Array[int] = [0]
	var changed_count: Array[int] = [0]
	var died_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): damaged_count[0] += 1
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1
	var on_died: Callable = func(_c): died_count[0] += 1
	Events.player_damaged.connect(on_damaged)
	Events.player_health_changed.connect(on_changed)
	Events.player_died.connect(on_died)

	# Act — additional damage while DEAD
	player.apply_damage(10.0, source, CombatSystemNode.DamageType.TEST)
	player.apply_damage(50.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)
	Events.player_health_changed.disconnect(on_changed)
	Events.player_died.disconnect(on_died)

	# Assert — no further signals; health stays 0; state stays DEAD
	assert_int(damaged_count[0]).override_failure_message(
		"AC-5.3 DEAD guard: player_damaged must not fire when DEAD."
	).is_equal(0)
	assert_int(changed_count[0]).override_failure_message(
		"AC-5.3 DEAD guard: player_health_changed must not fire when DEAD."
	).is_equal(0)
	assert_int(died_count[0]).override_failure_message(
		"AC-5.3 DEAD guard: player_died must not re-fire (max once per death)."
	).is_equal(0)
	assert_int(player.health).is_equal(0)
	assert_int(int(player.current_state)).is_equal(PlayerEnums.MovementState.DEAD)


# ── E.7: simultaneous lethal damage — player_died fires only once ──────────

func test_simultaneous_lethal_damage_fires_player_died_once() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var died_count: Array[int] = [0]
	var on_died: Callable = func(_c): died_count[0] += 1
	Events.player_died.connect(on_died)

	# Two lethal calls in the same stack frame
	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)
	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_died.disconnect(on_died)

	assert_int(died_count[0]).override_failure_message(
		"E.7: simultaneous lethal damage on same frame must fire player_died exactly once."
	).is_equal(1)
