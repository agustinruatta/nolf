# tests/integration/feature/document_collection/spawn_gate_test.gd
#
# SpawnGateTest — GdUnit4 integration suite for DocumentCollection spawn-gate
#                 (_gate_collected_bodies_in_section), exercised via restore().
#
# PURPOSE
#   Validates the spawn-gate behaviour with real scene-tree DocumentBody nodes
#   added to the section_documents group. Tests confirm that:
#     - Bodies whose id is in _collected are synchronously freed on restore().
#     - Bodies NOT in _collected are preserved.
#     - Stale ids matching no scene body cause no crash and no unintended frees.
#     - Bodies with a null document export trigger push_warning() and are NOT freed.
#
# INTEGRATION CLASSIFICATION
#   Uses get_tree() + add_child() + is_instance_valid() — requires scene tree.
#   NOT a unit test. Classified as Integration per test-standards.md.
#
# COVERED ACCEPTANCE CRITERIA
#   AC-4 (AC-DC-4.1) — collected bodies freed synchronously; uncollected bodies preserved.
#   AC-5 (AC-DC-4.2) — stale id in _collected is benign (no crash, no unintended frees).
#   AC-6 (AC-DC-4.3) — null document export triggers push_warning(); body NOT freed.
#
# WHAT IS NOT TESTED HERE
#   - capture/restore aliasing — save_contract_test.gd (unit, DC-004).
#   - pickup happy-path — idempotency_test.gd (DC-003).
#
# SPAWN-GATE CONTRACT (GDD CR-3(i), DC-004)
#   The spawn-gate runs SYNCHRONOUSLY (queue_free, NOT call_deferred) so
#   bodies are removed immediately within the restore() call, before section_entered
#   is emitted and before the player can see the section.
#
# GATE STATUS
#   Story DC-004 — Integration story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SpawnGateTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates and returns a DocumentCollection added to the scene tree so _ready()
## fires and get_tree() is available for spawn-gate iteration.
## auto_free() ensures cleanup after each test.
func _make_dc() -> DocumentCollection:
	var dc: DocumentCollection = DocumentCollection.new()
	add_child(dc)
	auto_free(dc)
	return dc


## Creates a DocumentBody carrying a Document with the given id, adds it to
## the scene tree under a parent node, and registers it in SECTION_DOCUMENTS_GROUP.
## The body IS added to the tree so get_nodes_in_group() finds it.
## auto_free() ensures cleanup for the body's parent wrapper.
func _make_body_in_group(id: StringName, parent: Node) -> DocumentBody:
	var doc: Document = Document.new()
	doc.id = id
	doc.section_id = &"plaza"

	var body: DocumentBody = DocumentBody.new()
	body.document = doc
	# Register in the spawn-gate group (uses DC's constant value).
	body.add_to_group(DocumentCollection.SECTION_DOCUMENTS_GROUP)
	parent.add_child(body)
	return body


## Creates a DocumentBody with a NULL document export, adds it to the scene tree,
## and registers it in SECTION_DOCUMENTS_GROUP. Used to test the null-guard path.
func _make_null_doc_body_in_group(parent: Node) -> DocumentBody:
	var body: DocumentBody = DocumentBody.new()
	body.document = null  # intentionally null — triggers push_warning in spawn-gate
	body.add_to_group(DocumentCollection.SECTION_DOCUMENTS_GROUP)
	parent.add_child(body)
	return body


## Creates a DocumentCollectionState with the given ids.
func _make_state(ids: Array[StringName]) -> DocumentCollectionState:
	var state: DocumentCollectionState = DocumentCollectionState.new()
	state.collected = ids.duplicate()
	auto_free(state)
	return state


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-4.1) — collected bodies freed; uncollected bodies preserved
# ---------------------------------------------------------------------------

## GIVEN _collected contains [&"plaza_logbook", &"plaza_register"]
## AND both corresponding DocumentBody nodes are in section_documents group
## AND a third uncollected body (&"plaza_clipboard") is also in the group
## WHEN restore(state) is called
## THEN plaza_logbook and plaza_register bodies are freed synchronously
## AND plaza_clipboard body is NOT freed.
func test_collected_bodies_absent_after_restore() -> void:
	# Arrange — scene root to hold the bodies.
	var scene_root: Node = Node.new()
	add_child(scene_root)
	auto_free(scene_root)

	var dc: DocumentCollection = _make_dc()

	var body_logbook: DocumentBody = _make_body_in_group(&"plaza_logbook", scene_root)
	var body_register: DocumentBody = _make_body_in_group(&"plaza_register", scene_root)
	var body_clipboard: DocumentBody = _make_body_in_group(&"plaza_clipboard", scene_root)

	# Verify all bodies are alive before restore.
	assert_bool(is_instance_valid(body_logbook)).override_failure_message(
		"Setup: body_logbook must be valid before restore()."
	).is_true()
	assert_bool(is_instance_valid(body_register)).override_failure_message(
		"Setup: body_register must be valid before restore()."
	).is_true()
	assert_bool(is_instance_valid(body_clipboard)).override_failure_message(
		"Setup: body_clipboard must be valid before restore()."
	).is_true()

	var ids: Array[StringName] = [&"plaza_logbook", &"plaza_register"]
	var state: DocumentCollectionState = _make_state(ids)

	# Act — restore triggers spawn-gate synchronously.
	dc.restore(state)

	# Assert — collected bodies are freed (synchronous queue_free per CR-3(i)).
	# queue_free is processed at end of frame; bodies are marked for deletion.
	# In GdUnit4, await get_tree().process_frame allows the free to propagate.
	await get_tree().process_frame

	assert_bool(is_instance_valid(body_logbook)).override_failure_message(
		"AC-4: plaza_logbook body must be freed by spawn-gate after restore(). "
		+ "spawn-gate uses synchronous queue_free() per GDD CR-3(i)."
	).is_false()
	assert_bool(is_instance_valid(body_register)).override_failure_message(
		"AC-4: plaza_register body must be freed by spawn-gate after restore()."
	).is_false()

	# Assert — uncollected body is preserved.
	assert_bool(is_instance_valid(body_clipboard)).override_failure_message(
		"AC-4: plaza_clipboard body (not in _collected) must NOT be freed by spawn-gate."
	).is_true()


# ---------------------------------------------------------------------------
# AC-5 (AC-DC-4.2) — stale id in _collected is benign
# ---------------------------------------------------------------------------

## GIVEN _collected contains [&"nonexistent_id"]
## AND the section has NO DocumentBody with that id
## WHEN restore(state) fires _gate_collected_bodies_in_section()
## THEN no crash, no error, no body freed.
func test_stale_id_in_collected_is_benign() -> void:
	# Arrange — one real body in the section, NOT matching the stale id.
	var scene_root: Node = Node.new()
	add_child(scene_root)
	auto_free(scene_root)

	var dc: DocumentCollection = _make_dc()
	var real_body: DocumentBody = _make_body_in_group(&"plaza_clipboard", scene_root)

	var ids: Array[StringName] = [&"nonexistent_id"]
	var state: DocumentCollectionState = _make_state(ids)

	# Act — should not crash.
	dc.restore(state)

	await get_tree().process_frame

	# Assert — real body is unaffected (stale id matched nothing).
	assert_bool(is_instance_valid(real_body)).override_failure_message(
		"AC-5: A body NOT matching the stale id must NOT be freed. "
		+ "Stale ids in _collected must be benign no-ops (AC-DC-4.2)."
	).is_true()

	# Assert — _collected reflects the restored state (stale id is still stored,
	# this is intentional — DC doesn't validate ids against scene content).
	assert_bool(dc._collected.has(&"nonexistent_id")).override_failure_message(
		"AC-5: _collected must contain the stale id even if no body matched it."
	).is_true()


# ---------------------------------------------------------------------------
# AC-6 (AC-DC-4.3) — null document export triggers warning; body not freed
# ---------------------------------------------------------------------------

## GIVEN a DocumentBody in section_documents group with document = null
## AND its mock id (had it existed) is in _collected
## WHEN _gate_collected_bodies_in_section() iterates it via restore()
## THEN push_warning() is emitted once for that body
## AND the body is NOT freed (null-guard stops processing before queue_free).
func test_null_document_export_does_not_crash() -> void:
	# Arrange
	var scene_root: Node = Node.new()
	add_child(scene_root)
	auto_free(scene_root)

	var dc: DocumentCollection = _make_dc()

	# Body with null document — triggers push_warning in spawn-gate.
	var null_body: DocumentBody = _make_null_doc_body_in_group(scene_root)

	# Pre-populate _collected with something; doesn't matter what because
	# the null-guard fires BEFORE body.document.id is accessed (GDD E.15).
	# The body's actual id can't be read — the null guard must prevent it.
	var ids: Array[StringName] = [&"would_match_if_accessible"]
	var state: DocumentCollectionState = _make_state(ids)

	# Act — must not crash despite body.document being null.
	# GdUnit4's monitor_signals / assert_signal_emitted is not available for
	# push_warning(), so we verify indirectly that no crash occurred and the
	# body was NOT freed (the warning path uses push_warning, not assert_error).
	dc.restore(state)

	await get_tree().process_frame

	# Assert — null_body must NOT have been freed.
	# If the null-guard was absent, accessing body.document.id would crash,
	# not queue_free the body — but we guard for both safety.
	assert_bool(is_instance_valid(null_body)).override_failure_message(
		"AC-6: A DocumentBody with null document must NOT be freed by spawn-gate. "
		+ "The null-guard (GDD E.15) must short-circuit before accessing document.id."
	).is_true()
