# tests/unit/core/player_character/player_signal_taxonomy_test.gd
#
# PlayerSignalTaxonomyTest — Story PC-006 AC-10.1 + AC-10.2.
#
# COVERED ACCEPTANCE CRITERIA (Story PC-006)
#   AC-10.1: all player signals emit through Events autoload, NOT direct
#            node-to-node signals. Verified by spying on Events emissions
#            during apply_damage / apply_heal sequences.
#   AC-10.2: signal-rate guard — across 300 simulated invocations, no signal
#            exceeds 150 emissions (damaged/health_changed/interacted ≤ 150,
#            died ≤ 5).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name PlayerSignalTaxonomyTest
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


# ── AC-10.1: signals emit on Events autoload ───────────────────────────────

## AC-10.1: subscribers connecting to Events.player_damaged see the emission;
## verifies the signal is routed through the autoload.
func test_player_damaged_emits_via_events_autoload() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var via_events_count: Array[int] = [0]
	var on_events: Callable = func(_a, _s, _c): via_events_count[0] += 1
	Events.player_damaged.connect(on_events)

	player.apply_damage(10.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_events)

	assert_int(via_events_count[0]).override_failure_message(
		"AC-10.1: player_damaged must emit through Events autoload."
	).is_equal(1)


## AC-10.1: player_health_changed emits via Events autoload.
func test_player_health_changed_emits_via_events_autoload() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var count: Array[int] = [0]
	var on_changed: Callable = func(_c, _m): count[0] += 1
	Events.player_health_changed.connect(on_changed)

	player.apply_damage(10.0, source, CombatSystemNode.DamageType.TEST)
	player.apply_heal(5.0, source)

	Events.player_health_changed.disconnect(on_changed)

	assert_int(count[0]).override_failure_message(
		"AC-10.1: player_health_changed must emit via Events on damage AND heal."
	).is_equal(2)


## AC-10.1: player_died emits via Events autoload.
func test_player_died_emits_via_events_autoload() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var count: Array[int] = [0]
	var on_died: Callable = func(_c): count[0] += 1
	Events.player_died.connect(on_died)

	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_died.disconnect(on_died)

	assert_int(count[0]).is_equal(1)


# ── AC-10.2: signal-rate guard ──────────────────────────────────────────────

## AC-10.2: 300 sub-1-HP damage calls (each rounds to 0) produce ZERO
## emissions — the rounding floor prevents spam from sub-threshold input.
func test_signal_rate_300_sub_threshold_calls_emit_zero() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var damaged_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): damaged_count[0] += 1
	Events.player_damaged.connect(on_damaged)

	for i: int in range(300):
		player.apply_damage(0.3, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)

	# 300 sub-threshold (0.3) calls → 0 emissions
	assert_int(damaged_count[0]).override_failure_message(
		"AC-10.2: 300 sub-threshold (0.3) damage calls must emit 0 signals."
	).is_equal(0)


## AC-10.2: 50 valid damage calls + 1 lethal — bounds:
##   - player_damaged ≤ 150 (got 50 + 1 = 51)
##   - player_health_changed ≤ 150 (got 51)
##   - player_died ≤ 5 (got 1)
func test_signal_rate_within_bounds_for_realistic_sequence() -> void:
	var player: PlayerCharacter = _make_player()
	var source: Node = _make_source()

	var damaged_count: Array[int] = [0]
	var changed_count: Array[int] = [0]
	var died_count: Array[int] = [0]
	var on_damaged: Callable = func(_a, _s, _c): damaged_count[0] += 1
	var on_changed: Callable = func(_c, _m): changed_count[0] += 1
	var on_died: Callable = func(_c): died_count[0] += 1
	Events.player_damaged.connect(on_damaged)
	Events.player_health_changed.connect(on_changed)
	Events.player_died.connect(on_died)

	# 50 small damages of 1.0 each (total 50 HP lost)
	for i: int in range(50):
		player.apply_damage(1.0, source, CombatSystemNode.DamageType.TEST)
	# Then a lethal hit
	player.apply_damage(999.0, source, CombatSystemNode.DamageType.TEST)
	# Then 50 more attempts while DEAD (should emit 0)
	for i: int in range(50):
		player.apply_damage(10.0, source, CombatSystemNode.DamageType.TEST)

	Events.player_damaged.disconnect(on_damaged)
	Events.player_health_changed.disconnect(on_changed)
	Events.player_died.disconnect(on_died)

	# AC-10.2 bounds — generous ceilings; expect concrete counts
	assert_int(damaged_count[0]).override_failure_message(
		"AC-10.2: player_damaged must be ≤ 150. Got %d." % damaged_count[0]
	).is_less_equal(150)
	assert_int(changed_count[0]).is_less_equal(150)
	assert_int(died_count[0]).override_failure_message(
		"AC-10.2: player_died must be ≤ 5. Got %d." % died_count[0]
	).is_less_equal(5)
	# Concrete: 51 damaged emits (50 alive + 1 lethal); 0 after DEAD
	assert_int(damaged_count[0]).is_equal(51)
	assert_int(died_count[0]).is_equal(1)
