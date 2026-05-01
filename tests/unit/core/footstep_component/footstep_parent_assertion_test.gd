# tests/unit/core/footstep_component/footstep_parent_assertion_test.gd
#
# FootstepParentAssertionTest — GdUnit4 suite for Story FS-001 AC-1 + AC-2.
#
# PURPOSE
#   Verifies FootstepComponent's _ready() parent-type assertion:
#     • Wrong parent (Node3D, not PlayerCharacter) → _is_disabled = true
#     • Correct parent (PlayerCharacter) → _is_disabled = false, _player set
#     • Disabled instance's _physics_process emits zero player_footstep signals
#
# METHOD
#   Build FootstepComponent under different parents; trigger _ready() via add_child;
#   inspect _is_disabled. For AC-2, count player_footstep emissions over a tick.
#
# GATE STATUS
#   Story FS-001 | Logic type → BLOCKING gate. TR-FC-001, TR-FC-008.

class_name FootstepParentAssertionTest
extends GdUnitTestSuite


## AC-1: Wrong parent (bare Node3D) → _is_disabled true.
func test_wrong_parent_node3d_sets_disabled_true() -> void:
	var wrong_parent: Node3D = Node3D.new()
	auto_free(wrong_parent)
	add_child(wrong_parent)

	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	wrong_parent.add_child(fc)  # triggers _ready

	assert_bool(fc._is_disabled).override_failure_message(
		"Wrong parent (Node3D) must set _is_disabled = true."
	).is_true()
	assert_object(fc._player).override_failure_message(
		"Wrong parent must leave _player as null."
	).is_null()


## AC-1: Correct parent (PlayerCharacter scene) → _is_disabled false.
func test_correct_parent_player_character_keeps_enabled() -> void:
	var packed: PackedScene = load("res://src/gameplay/player/PlayerCharacter.tscn") as PackedScene
	var player: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(player)
	add_child(player)

	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	player.add_child(fc)  # triggers _ready

	assert_bool(fc._is_disabled).override_failure_message(
		"Correct parent (PlayerCharacter) must keep _is_disabled = false."
	).is_false()
	assert_object(fc._player).override_failure_message(
		"Correct parent must set _player to the PlayerCharacter."
	).is_same(player)


## AC-1 edge case: parent is null at _ready time.
## (Calling _ready() manually on an unparented FootstepComponent.)
func test_null_parent_sets_disabled_true_without_crash() -> void:
	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	# Don't add_child — invoke _ready directly with no parent in the tree.
	fc._ready()

	assert_bool(fc._is_disabled).override_failure_message(
		"Null parent must set _is_disabled = true without crash."
	).is_true()


## AC-2: Disabled FootstepComponent's _physics_process emits zero player_footstep.
func test_disabled_physics_process_emits_zero_footsteps() -> void:
	var wrong_parent: Node3D = Node3D.new()
	auto_free(wrong_parent)
	add_child(wrong_parent)

	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	wrong_parent.add_child(fc)
	# Sanity precondition.
	assert_bool(fc._is_disabled).is_true()

	# Track footstep emissions.
	var emit_count: int = 0
	var on_footstep: Callable = func(_surface: StringName, _radius: float) -> void:
		emit_count += 1
	Events.player_footstep.connect(on_footstep)

	# Call _physics_process several times.
	for _i: int in range(10):
		fc._physics_process(1.0 / 60.0)

	Events.player_footstep.disconnect(on_footstep)

	assert_int(emit_count).override_failure_message(
		"Disabled FootstepComponent must emit zero player_footstep signals over 10 physics ticks. Got: %d" % emit_count
	).is_equal(0)


## AC-2 (positive control): Enabled FootstepComponent does not crash on
## _physics_process — Story FS-002 lands the actual emit logic, but the
## scaffold's no-op stub must run without errors.
func test_enabled_physics_process_does_not_crash_in_scaffold() -> void:
	var packed: PackedScene = load("res://src/gameplay/player/PlayerCharacter.tscn") as PackedScene
	var player: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(player)
	add_child(player)

	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	player.add_child(fc)

	# Run several ticks. Scaffold has no emit logic yet; this just verifies
	# the no-op path is safe and doesn't reference _player improperly.
	for _i: int in range(5):
		fc._physics_process(1.0 / 60.0)

	# Reaching this point without an error is the assertion.
	assert_bool(true).override_failure_message(
		"Enabled scaffold _physics_process must not crash."
	).is_true()
