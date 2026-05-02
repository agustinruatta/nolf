# tests/unit/core/player_character/player_damage_basic_test.gd
#
# PlayerDamageBasicTest — Story PC-006 AC-5.1.
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-5.1: apply_damage(25.0, source, DamageType.TEST) from health=100:
#     - health == 75 afterwards
#     - player_damaged(25.0, source, false) fires BEFORE player_health_changed(75, 100)
#     - signal emission order verified via emission-log spy
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerDamageBasicTest
extends GdUnitTestSuite

const _PLAYER_SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"


func _make_player() -> PlayerCharacter:
	var scene: PackedScene = load(_PLAYER_SCENE_PATH) as PackedScene
	var player: PlayerCharacter = scene.instantiate() as PlayerCharacter
	add_child(player)
	auto_free(player)
	return player


func _make_source_stub() -> Node:
	var src: Node = Node.new()
	add_child(src)
	auto_free(src)
	return src


# ── AC-5.1: 25 damage reduces health to 75 + correct signal payload ─────────

func test_apply_damage_reduces_health_by_rounded_amount() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source_stub()

	# Pre-condition
	assert_int(player.health).is_equal(100)

	# Act
	player.apply_damage(25.0, source, CombatSystemNode.DamageType.TEST)

	# Assert
	assert_int(player.health).override_failure_message(
		"AC-5.1: health must be 75 after 25 damage. Got %d." % player.health
	).is_equal(75)


# ── AC-5.1: signal emission order — player_damaged FIRST, then health_changed ──

func test_apply_damage_emits_signals_in_correct_order() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source_stub()

	var emission_log: Array[String] = []
	var on_damaged: Callable = func(amount: float, _src, _crit):
		emission_log.append("damaged:%.1f" % amount)
	var on_changed: Callable = func(current: float, max_h: float):
		emission_log.append("health:%.0f/%.0f" % [current, max_h])

	Events.player_damaged.connect(on_damaged)
	Events.player_health_changed.connect(on_changed)

	# Act
	player.apply_damage(25.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)
	Events.player_health_changed.disconnect(on_changed)

	# Assert — exactly 2 emissions, in the correct order
	assert_int(emission_log.size()).is_equal(2)
	assert_str(emission_log[0]).override_failure_message(
		"AC-5.1: player_damaged must fire FIRST. Order: %s" % str(emission_log)
	).is_equal("damaged:25.0")
	assert_str(emission_log[1]).override_failure_message(
		"AC-5.1: player_health_changed must fire SECOND. Order: %s" % str(emission_log)
	).is_equal("health:75/100")


# ── AC-5.1: payload values match spec (amount, source, is_critical=false) ───

func test_apply_damage_signal_payload_matches_spec() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source_stub()

	var captured: Array = [0.0, null, true]  # amount, src, is_critical
	var on_damaged: Callable = func(amount: float, src, is_critical: bool):
		captured[0] = amount
		captured[1] = src
		captured[2] = is_critical
	Events.player_damaged.connect(on_damaged)

	player.apply_damage(25.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)

	assert_float(captured[0] as float).is_equal_approx(25.0, 0.001)
	assert_object(captured[1] as Object).is_equal(source)
	assert_bool(captured[2] as bool).override_failure_message(
		"AC-5.1: is_critical must be false at MVP."
	).is_false()
