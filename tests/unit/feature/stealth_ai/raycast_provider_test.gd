# tests/unit/feature/stealth_ai/raycast_provider_test.gd
#
# RaycastProviderTest — GdUnit4 test suite for IRaycastProvider DI interface.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-003)
#   AC-1 — IRaycastProvider @abstract prevents direct instantiation
#   AC-1 — RealRaycastProvider._init requires non-null PhysicsDirectSpaceState3D
#   AC-1 — CountingRaycastProvider call_count starts at 0, increments per cast()
#   AC-1 — CountingRaycastProvider.scripted_result returned verbatim from cast()
#
# NOTE on RealRaycastProvider null-assertion test (AC-7):
#   GDScript assertions (assert()) cannot be caught by GdUnit4 in the same way
#   as GDScript errors — they abort the running script. The test verifies
#   the assert exists in source rather than calling with null (which would crash
#   the test runner). AC-7's "obtain in _ready not _init" contract is documented
#   via the source-pattern test below.
#
# TEST FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe (no scene tree).

class_name RaycastProviderTest
extends GdUnitTestSuite


# ── AC-1: IRaycastProvider @abstract prevents direct instantiation ───────────

## AC-1: Verifies @abstract annotation is present on IRaycastProvider class
## declaration. The annotation prevents IRaycastProvider.new() from succeeding
## (GDScript 4.5+ enforces this at runtime).
func test_iraycast_provider_is_abstract_class() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(
			"res://src/gameplay/stealth/raycast_provider.gd"
	)
	assert_str(source).override_failure_message(
			"Could not read raycast_provider.gd"
	).is_not_empty()

	# Act + Assert — @abstract annotation is present immediately before
	# `class_name IRaycastProvider`.
	var lines: PackedStringArray = source.split("\n")
	var found_abstract: bool = false
	for i: int in range(lines.size()):
		var line: String = lines[i].strip_edges()
		if line == "@abstract":
			# Check next non-empty line for class_name IRaycastProvider
			for j: int in range(i + 1, mini(i + 4, lines.size())):
				var follow: String = lines[j].strip_edges()
				if follow.begins_with("class_name IRaycastProvider"):
					found_abstract = true
					break
		if found_abstract:
			break

	assert_bool(found_abstract).override_failure_message(
			"AC-1: IRaycastProvider must declare '@abstract' before 'class_name IRaycastProvider'."
	).is_true()


# ── AC-7 / AC-1: RealRaycastProvider._init asserts non-null space_state ──────

## AC-7: RealRaycastProvider._init contains an assert for non-null space_state.
## Direct null-call would abort the test runner, so we verify via source pattern.
func test_real_raycast_provider_init_has_null_assert() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(
			"res://src/gameplay/stealth/real_raycast_provider.gd"
	)
	assert_str(source).override_failure_message(
			"Could not read real_raycast_provider.gd"
	).is_not_empty()

	# Act + Assert — assert(space_state != null, ...) pattern present in source
	var pattern: RegEx = RegEx.create_from_string(
			"assert\\s*\\(\\s*space_state\\s*!=\\s*null"
	)
	var found: bool = false
	for line: String in source.split("\n"):
		if pattern.search(line) != null:
			found = true
			break

	assert_bool(found).override_failure_message(
			"AC-7: RealRaycastProvider._init must contain assert(space_state != null, ...) " +
			"to guard against obtaining space_state before node enters the scene tree."
	).is_true()


# ── AC-1: CountingRaycastProvider call_count starts at 0 ─────────────────────

## AC-1: Fresh CountingRaycastProvider has call_count == 0 before any cast() call.
func test_counting_provider_call_count_starts_at_zero() -> void:
	# Arrange
	var provider: CountingRaycastProvider = CountingRaycastProvider.new()

	# Assert
	assert_int(provider.call_count).override_failure_message(
			"AC-1: CountingRaycastProvider.call_count must start at 0."
	).is_equal(0)


# ── AC-1: CountingRaycastProvider.call_count increments per cast() call ──────

## AC-1: call_count increments by 1 for each cast() call.
func test_counting_provider_call_count_increments_per_cast() -> void:
	# Arrange
	var provider: CountingRaycastProvider = CountingRaycastProvider.new()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

	# Act
	provider.cast(query)
	provider.cast(query)
	provider.cast(query)

	# Assert
	assert_int(provider.call_count).override_failure_message(
			"AC-1: CountingRaycastProvider.call_count must increment once per cast() call. " +
			"Expected 3 after 3 calls."
	).is_equal(3)


# ── AC-1: CountingRaycastProvider.scripted_result returned verbatim ──────────

## AC-1: cast() returns scripted_result verbatim — the exact dict assigned.
func test_counting_provider_returns_scripted_result_verbatim() -> void:
	# Arrange
	var provider: CountingRaycastProvider = CountingRaycastProvider.new()
	var expected: Dictionary = {"position": Vector3(1.0, 2.0, 3.0), "collider_id": 42}
	provider.scripted_result = expected
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

	# Act
	var result: Dictionary = provider.cast(query)

	# Assert
	assert_bool(result == expected).override_failure_message(
			"AC-1: CountingRaycastProvider.cast() must return scripted_result verbatim."
	).is_true()


## AC-1: Default scripted_result is {} (empty — no hit).
func test_counting_provider_default_scripted_result_is_empty() -> void:
	# Arrange
	var provider: CountingRaycastProvider = CountingRaycastProvider.new()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()

	# Act
	var result: Dictionary = provider.cast(query)

	# Assert
	assert_bool(result.is_empty()).override_failure_message(
			"AC-1: CountingRaycastProvider default scripted_result must be {} (empty dict)."
	).is_true()
