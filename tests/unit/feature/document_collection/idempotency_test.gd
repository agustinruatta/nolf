# tests/unit/feature/document_collection/idempotency_test.gd
#
# IdempotencyTest — GdUnit4 unit suite for DocumentCollection duplicate-pickup
#                   behaviour (AC-DC-2.2 idempotency net).
#
# PURPOSE
#   Validates AC-2 (happy-path: single pickup appends, emits, defers free)
#   and AC-3 (idempotency: duplicate pickup does NOT re-emit document_collected
#   and does NOT grow _collected).
#
# COVERED ACCEPTANCE CRITERIA
#   AC-2 — First pickup: _collected gains the id; document_collected fires once.
#   AC-3 — Duplicate pickup on the same id: document_collected fires zero new
#           times; _collected.size() unchanged.
#   AC-3 edge — duplicate_id_bodies with different body instances but same id
#               emit exactly once total.
#
# WHAT IS NOT TESTED HERE
#   - connect/disconnect lifecycle — subscriber_lifecycle_test.gd (AC-1).
#   - Guard sequence — signal_handler_guards_test.gd (AC-4).
#
# GATE STATUS
#   Story DC-003 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name IdempotencyTest
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


## Returns a DocumentBody carrying a Document with the given id.
## The body is NOT added to the tree (pickup is triggered via signal, not tree
## membership). auto_free() cleans up after the test.
func _make_body(id: StringName) -> DocumentBody:
	var doc: Document = Document.new()
	doc.id = id
	doc.section_id = &"plaza"

	var body: DocumentBody = DocumentBody.new()
	body.document = doc
	auto_free(body)
	return body


## Signal spy helper — records how many times document_collected fired and
## what id was received last.
class CollectedSpy:
	var call_count: int = 0
	var last_id: StringName = &""

	func on_collected(id: StringName) -> void:
		call_count += 1
		last_id = id


## Connects a CollectedSpy to Events.document_collected and returns it.
## The returned spy is auto-freed via the provided test suite reference.
func _make_spy(suite: GdUnitTestSuite) -> CollectedSpy:
	var spy: CollectedSpy = CollectedSpy.new()
	Events.document_collected.connect(spy.on_collected)
	suite.auto_free(spy)
	return spy


# ---------------------------------------------------------------------------
# AC-2 — Happy-path: single pickup appends and emits exactly once
# ---------------------------------------------------------------------------

## Emitting player_interacted with a valid DocumentBody causes:
##   (a) _collected to contain the id; (b) document_collected fires exactly once.
## AC-DC-2.1.
func test_first_pickup_appends_id_and_emits_once() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var body: DocumentBody = _make_body(&"plaza_logbook")
	var spy: CollectedSpy = _make_spy(self)

	# Act
	Events.player_interacted.emit(body)

	# Assert — id is in _collected.
	assert_bool(dc._collected.has(&"plaza_logbook")).override_failure_message(
		"AC-2: After pickup, _collected must contain the document id."
	).is_true()

	# Assert — document_collected fired exactly once.
	assert_int(spy.call_count).override_failure_message(
		"AC-2: Events.document_collected must fire exactly once on first pickup."
	).is_equal(1)

	# Assert — correct id was emitted.
	assert_str(String(spy.last_id)).override_failure_message(
		"AC-2: Events.document_collected must emit the correct document id."
	).is_equal("plaza_logbook")

	# Cleanup — disconnect spy to avoid cross-test interference.
	Events.document_collected.disconnect(spy.on_collected)


# ---------------------------------------------------------------------------
# AC-3 — Duplicate pickup: no re-emit, _collected unchanged
# ---------------------------------------------------------------------------

## Emitting player_interacted twice for the same id must NOT fire
## document_collected a second time and must NOT grow _collected.
## AC-DC-2.2.
func test_duplicate_pickup_does_not_re_emit() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var body: DocumentBody = _make_body(&"plaza_logbook")
	var spy: CollectedSpy = _make_spy(self)

	# Act — first pickup.
	Events.player_interacted.emit(body)
	var count_after_first: int = spy.call_count
	var size_after_first: int = dc._collected.size()

	# Act — second pickup (same body reference; body is still valid for test purposes).
	Events.player_interacted.emit(body)

	# Assert — document_collected count unchanged after second emit.
	assert_int(spy.call_count).override_failure_message(
		"AC-3: document_collected must NOT fire again on duplicate pickup. " +
		"Expected total %d calls, got %d." % [count_after_first, spy.call_count]
	).is_equal(count_after_first)

	# Assert — _collected.size() unchanged after second emit.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-3: _collected.size() must not grow on duplicate pickup. " +
		"Expected %d, got %d." % [size_after_first, dc._collected.size()]
	).is_equal(size_after_first)

	# Cleanup
	Events.document_collected.disconnect(spy.on_collected)


# ---------------------------------------------------------------------------
# AC-3 edge — two different body instances with the same id emit only once
# ---------------------------------------------------------------------------

## If two DocumentBody instances share the same document id (scene-duplication
## error or deferred free race), document_collected must still fire exactly once
## total. The second body is a distinct object but carries the same id.
## AC-DC-2.2 variant.
func test_duplicate_id_bodies_emit_once() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var body_a: DocumentBody = _make_body(&"plaza_memo")
	var body_b: DocumentBody = _make_body(&"plaza_memo")  # different instance, same id
	var spy: CollectedSpy = _make_spy(self)

	# Act — first body collected.
	Events.player_interacted.emit(body_a)

	# Act — second body with same id (simulates deferred-free race or designer error).
	Events.player_interacted.emit(body_b)

	# Assert — exactly one emission total.
	assert_int(spy.call_count).override_failure_message(
		"AC-3 edge: Two DocumentBodies with the same id must result in exactly " +
		"one document_collected emission. Got %d." % spy.call_count
	).is_equal(1)

	# Assert — _collected has exactly one entry.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-3 edge: _collected must have exactly one entry for the duplicated id."
	).is_equal(1)

	# Cleanup
	Events.document_collected.disconnect(spy.on_collected)
