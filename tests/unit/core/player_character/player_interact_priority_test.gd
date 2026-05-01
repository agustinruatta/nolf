# tests/unit/core/player_character/player_interact_priority_test.gd
#
# PlayerInteractPriorityTest — GdUnit4 suite for Story PC-005 AC-4.1.
#
# PURPOSE
#   Verifies _resolve_interact_target() priority ordering: lower numeric value
#   in InteractPriority.Kind wins regardless of geometric order along the ray.
#
# METHOD
#   Spawn PlayerCharacter + StubInteractable instances on LAYER_INTERACTABLES.
#   Await two physics frames so Jolt/PhysicsServer3D registers the static bodies
#   for direct_space_state.intersect_ray() queries. Then call
#   _resolve_interact_target() and assert the priority winner.
#
# GATE STATUS
#   Story PC-005 | Logic type → BLOCKING gate. TR-PC-008.

class_name PlayerInteractPriorityTest
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


func _build_stub(priority: int, position: Vector3) -> StubInteractable:
	var body: StubInteractable = StubInteractable.new()
	body.priority = priority
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.1)
	col.shape = box
	body.add_child(col)
	body.position = position
	body.set_collision_layer_value(PhysicsLayers.LAYER_INTERACTABLES, true)
	body.collision_mask = 0
	auto_free(body)
	add_child(body)
	return body


## AC-4.1: Document (priority 0) beats Door (priority 3) regardless of distance.
func test_resolve_interact_document_beats_geometrically_closer_door() -> void:
	# Door closer to camera (-Z 0.7); Document farther (-Z 1.4). Both within range.
	var door: StubInteractable = _build_stub(
		InteractPriority.Kind.DOOR,
		Vector3(0.0, _inst._STAND_EYE_Y, -0.7)
	)
	var doc: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -1.4)
	)
	# Let Jolt register the bodies.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"Resolver must return Document (priority 0) over geometrically-closer Door (priority 3). Got: %s" % [resolved]
	).is_same(doc)
	assert_object(door).is_not_null()


## AC-4.1: Two same-priority interactables → nearer wins (distance tie-break).
func test_resolve_interact_same_priority_nearer_wins() -> void:
	var doc_far: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -1.6)
	)
	var doc_near: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -0.7)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"Same-priority tie-break: nearer Document (-0.7 m) must win over farther (-1.6 m)."
	).is_same(doc_near)
	assert_object(doc_far).is_not_null()


## AC-4.1: No interactables in range → null.
func test_resolve_interact_no_targets_returns_null() -> void:
	# No stubs spawned.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"No interactables in range → resolver must return null."
	).is_null()


## AC-4.1: Single Document is returned.
func test_resolve_interact_single_document_returned() -> void:
	var doc: StubInteractable = _build_stub(
		InteractPriority.Kind.DOCUMENT,
		Vector3(0.0, _inst._STAND_EYE_Y, -1.0)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var resolved: Node3D = _inst._resolve_interact_target()

	assert_object(resolved).override_failure_message(
		"Single Document must be returned. Got: %s" % [resolved]
	).is_same(doc)
