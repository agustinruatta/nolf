# tests/unit/core/player_character/player_interact_cap_warning_test.gd
#
# PlayerInteractCapWarningTest — GdUnit4 suite for Story PC-005 AC-4.2.
#
# PURPOSE
#   Verifies _resolve_interact_target() emits push_warning when the iteration
#   cap is reached AND still returns a non-null best candidate from within the
#   iteration window. Cap-exceeded must NEVER crash or return null when a valid
#   target exists within the cap.
#
# WARNING-CAPTURE NOTE
#   GdUnit4 does not expose a standard `assert_warned` helper. This suite
#   asserts the OBSERVABLE behavior: best-within-cap return is non-null and
#   from within the first N stubs. Regressions in the warning emit itself
#   surface in Godot's stderr; reviewable manually.
#
# GATE STATUS
#   Story PC-005 | Logic type → BLOCKING gate. TR-PC-008.

class_name PlayerInteractCapWarningTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0

var _inst: PlayerCharacter = null


func before_test() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)
	_inst._physics_process(_PHYSICS_DELTA)
	_inst.global_position = Vector3.ZERO


# Sprint 05 close-out documented these 3 tests as full-suite-only flakies due
# to PhysicsServer3D space pollution from prior test files' auto_free'd bodies.
# Sprint 06 attempted a `await get_tree().physics_frame` drain in before_test
# but it broke isolation timing without resolving the full-suite case.
# Tech-debt: the fix needs PhysicsServer3D-level space introspection (which
# bodies are queued for removal) — beyond the scope of a one-line cleanup.
# Defer to a follow-up TD-009 entry: investigate PhysicsServer3D.space_get_*
# APIs OR move these tests to an isolated suite that runs in its own headless
# Godot session (no shared physics state with the rest of the suite).


func _build_stub(priority: int, position: Vector3) -> StubInteractable:
	var body: StubInteractable = StubInteractable.new()
	body.priority = priority
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.05, 0.05, 0.05)
	col.shape = box
	body.add_child(col)
	body.position = position
	body.set_collision_layer_value(PhysicsLayers.LAYER_INTERACTABLES, true)
	body.collision_mask = 0
	auto_free(body)
	add_child(body)
	return body


## AC-4.2: Cap=4 with 5 stacked → return is non-null and from within cap.
func test_resolve_cap_exceeded_returns_within_cap() -> void:
	_inst.raycast_max_iterations = 4
	var stubs: Array[StubInteractable] = []
	for i: int in range(5):
		stubs.append(_build_stub(
			InteractPriority.Kind.DOCUMENT,
			Vector3(0.0, _inst._STAND_EYE_Y, -0.4 - 0.2 * float(i))
		))
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"Cap-exceeded must still return a non-null best candidate from within the iteration window."
	).is_not_null()
	# Must be one of the first 4 stubs (5th is beyond cap).
	var first_four: Array = stubs.slice(0, 4)
	var contains: bool = false
	for stub: StubInteractable in first_four:
		if is_same(resolved, stub):
			contains = true
			break
	assert_bool(contains).override_failure_message(
		"Resolved target must be one of the first 4 stubs (cap=4); 5th stub beyond cap."
	).is_true()


## AC-4.2: Cap=1 with 2 stacked → returns the one within reach.
func test_resolve_cap_one_returns_a_stub() -> void:
	_inst.raycast_max_iterations = 1
	var first: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -0.5)
	)
	var second: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -1.2)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"Cap=1 must still return a non-null target."
	).is_not_null()
	# With cap=1, only the first hit is processed. The geometrically nearer one
	# is hit first, so resolver should return `first` (closer).
	assert_object(resolved).override_failure_message(
		"Cap=1 should resolve to the geometrically-first hit (nearer stub)."
	).is_same(first)
	assert_object(second).is_not_null()


## AC-4.2: Within-cap with mixed priorities → priority winner returned.
func test_resolve_within_cap_returns_priority_winner() -> void:
	_inst.raycast_max_iterations = 4
	var doc: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -0.8)
	)
	var door: StubInteractable = _build_stub(
		InteractPriority.Kind.DOOR,
		Vector3(0.0, _inst._STAND_EYE_Y, -1.0)
	)
	var pickup: StubInteractable = _build_stub(
		InteractPriority.Kind.PICKUP,
		Vector3(0.0, _inst._STAND_EYE_Y, -1.4)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"Within-cap mixed priorities → Document (0) wins over Door (3) and Pickup (2)."
	).is_same(doc)
	assert_object(door).is_not_null()
	assert_object(pickup).is_not_null()
