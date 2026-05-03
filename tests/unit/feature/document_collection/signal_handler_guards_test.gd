# tests/unit/feature/document_collection/signal_handler_guards_test.gd
#
# SignalHandlerGuardsTest — GdUnit4 unit suite for DocumentCollection
#                           _on_player_interacted() guard sequence.
#
# PURPOSE
#   Validates AC-4 (AC-DC-6.5): the mandatory 4-step guard sequence in
#   _on_player_interacted() must filter invalid payloads silently (or with a
#   push_warning) and never append to _collected or emit document_collected.
#
# COVERED ACCEPTANCE CRITERIA
#   AC-4a — null target returns immediately; no emit; _collected empty.
#   AC-4b — a valid Node3D that is NOT a DocumentBody is filtered; no emit.
#   AC-4c — a DocumentBody whose .document export is null triggers push_warning
#            and returns; no emit; _collected empty.
#
# GUARD SEQUENCE (CR-17, mandatory order — GDD §C.6 pseudocode):
#   1. is_instance_valid(target)  — ADR-0002 IG 4 first-line guard
#   2. target is DocumentBody     — non-document filter
#   3. target.document == null    — GDD E.15 null-export guard
#   4. _collected.has(doc_id)     — idempotency (covered in idempotency_test.gd)
#
# WHAT IS NOT TESTED HERE
#   - connect/disconnect lifecycle — subscriber_lifecycle_test.gd (AC-1).
#   - Happy-path and idempotency — idempotency_test.gd (AC-2/AC-3).
#
# GATE STATUS
#   Story DC-003 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SignalHandlerGuardsTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a DocumentCollection added to the tree so _ready() fires.
func _make_dc() -> DocumentCollection:
	var dc: DocumentCollection = DocumentCollection.new()
	add_child(dc)
	auto_free(dc)
	return dc


## Signal spy — counts document_collected emissions.
class CollectedSpy:
	var call_count: int = 0

	func on_collected(_id: StringName) -> void:
		call_count += 1


func _make_spy(suite: GdUnitTestSuite) -> CollectedSpy:
	var spy: CollectedSpy = CollectedSpy.new()
	Events.document_collected.connect(spy.on_collected)
	suite.auto_free(spy)
	return spy


# ---------------------------------------------------------------------------
# AC-4a — Guard 1: null target is rejected silently
# ---------------------------------------------------------------------------

## Emitting player_interacted(null) must return immediately with no error and
## no document_collected emission. Validates ADR-0002 IG 4 first-line guard.
func test_null_target_is_rejected() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var spy: CollectedSpy = _make_spy(self)

	# Act — emit null as the target (GDD E.5: target may be null).
	Events.player_interacted.emit(null)

	# Assert — no document_collected emission.
	assert_int(spy.call_count).override_failure_message(
		"AC-4a: document_collected must NOT fire when target is null. " +
		"Guard 1 (is_instance_valid) must return early (ADR-0002 IG 4)."
	).is_equal(0)

	# Assert — _collected remains empty.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-4a: _collected must remain empty when target is null."
	).is_equal(0)

	# Cleanup
	Events.document_collected.disconnect(spy.on_collected)


# ---------------------------------------------------------------------------
# AC-4b — Guard 2: non-DocumentBody Node3D is filtered
# ---------------------------------------------------------------------------

## A valid Node3D that is NOT a DocumentBody must be filtered at Guard 2
## (target is DocumentBody check). No emit, no _collected entry.
func test_non_document_body_target_is_filtered() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var spy: CollectedSpy = _make_spy(self)

	# A plain StaticBody3D — valid node, but not a DocumentBody.
	var non_body: StaticBody3D = StaticBody3D.new()
	auto_free(non_body)

	# Act
	Events.player_interacted.emit(non_body)

	# Assert — no document_collected emission.
	assert_int(spy.call_count).override_failure_message(
		"AC-4b: document_collected must NOT fire for a non-DocumentBody Node3D. " +
		"Guard 2 (target is DocumentBody) must return early."
	).is_equal(0)

	# Assert — _collected remains empty.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-4b: _collected must remain empty for a non-DocumentBody payload."
	).is_equal(0)

	# Cleanup
	Events.document_collected.disconnect(spy.on_collected)


# ---------------------------------------------------------------------------
# AC-4b variant — a plain Node3D (not even a physics body) is also filtered
# ---------------------------------------------------------------------------

## Confirms the `is DocumentBody` guard also blocks non-physics-body Node3D
## instances (e.g., an Area3D, a plain Node3D, or any other interactable type).
func test_plain_node3d_target_is_filtered() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var spy: CollectedSpy = _make_spy(self)

	var node: Node3D = Node3D.new()
	auto_free(node)

	# Act
	Events.player_interacted.emit(node)

	# Assert
	assert_int(spy.call_count).override_failure_message(
		"AC-4b variant: document_collected must NOT fire for a plain Node3D. " +
		"Guard 2 (target is DocumentBody) must return early."
	).is_equal(0)

	assert_int(dc._collected.size()).override_failure_message(
		"AC-4b variant: _collected must remain empty for a plain Node3D payload."
	).is_equal(0)

	# Cleanup
	Events.document_collected.disconnect(spy.on_collected)


# ---------------------------------------------------------------------------
# AC-4c — Guard 3: DocumentBody with null .document export triggers warning
# ---------------------------------------------------------------------------

## A DocumentBody whose .document export is null must trigger push_warning()
## and return early. No document_collected emission. _collected unchanged.
## Validates GDD E.15 null-export guard.
##
## Note: GdUnit4 does not capture push_warning() natively, so this test
## verifies the behavioral postconditions (no emit, no _collected growth)
## rather than the warning text itself. The warning is verified by code
## inspection and the CI grep for `push_warning` in the source.
func test_null_document_export_is_warned_and_filtered() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var spy: CollectedSpy = _make_spy(self)

	var body: DocumentBody = DocumentBody.new()
	# .document is null by default (no assignment) — per GDD E.15.
	auto_free(body)

	# Act
	Events.player_interacted.emit(body)

	# Assert — no document_collected emission.
	assert_int(spy.call_count).override_failure_message(
		"AC-4c: document_collected must NOT fire when DocumentBody.document is null. " +
		"Guard 3 (target.document == null) must push_warning and return early (GDD E.15)."
	).is_equal(0)

	# Assert — _collected remains empty.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-4c: _collected must remain empty when DocumentBody.document is null."
	).is_equal(0)

	# Cleanup
	Events.document_collected.disconnect(spy.on_collected)


# ---------------------------------------------------------------------------
# CR-15 — No _process or _physics_process override in document_collection.gd
# ---------------------------------------------------------------------------

## document_collection.gd must NOT define func _process or func _physics_process.
## Zero per-frame cost required by CR-15 (zero-steady-state budget).
## Source-scan approach used because has_method() returns true for inherited
## methods and cannot distinguish overrides.
func test_no_process_or_physics_process_override() -> void:
	# Arrange
	const _SCRIPT_PATH: String = "res://src/gameplay/documents/document_collection.gd"
	var script: GDScript = load(_SCRIPT_PATH) as GDScript

	assert_object(script).override_failure_message(
		"CR-15: document_collection.gd must load as a GDScript resource."
	).is_not_null()

	# Act
	var source: String = script.source_code

	# Assert — no func _process definition.
	assert_bool(source.contains("func _process(")).override_failure_message(
		"CR-15: document_collection.gd must NOT define _process " +
		"(zero-steady-state budget per CR-15 / AC-DC-9.3)."
	).is_false()

	# Assert — no func _physics_process definition.
	assert_bool(source.contains("func _physics_process(")).override_failure_message(
		"CR-15: document_collection.gd must NOT define _physics_process " +
		"(zero-steady-state budget per CR-15 / AC-DC-9.3)."
	).is_false()
