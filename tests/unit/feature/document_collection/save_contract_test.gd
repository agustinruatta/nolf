# tests/unit/feature/document_collection/save_contract_test.gd
#
# SaveContractTest — GdUnit4 unit suite for DocumentCollection capture/restore
#                   save contract (DC-004, ADR-0003, GDD §H.4–§H.5).
#
# PURPOSE
#   Validates the pure capture/restore behaviour (no scene tree, no DocumentBody
#   instances). These are purely logical tests that verify aliasing breaks,
#   null-guard behaviour, and the invariant that _open_document_id is excluded
#   from the save schema.
#
# COVERED ACCEPTANCE CRITERIA
#   AC-1 (AC-DC-5.1) — capture() returns defensive copy (aliasing break via duplicate).
#   AC-2 (AC-DC-5.2) — restore() populates _collected without aliasing.
#   AC-3              — restore(null) clears _collected and does not crash.
#   AC-7 (AC-DC-5.4) — _open_document_id is NOT persisted in save; not auto-restored.
#   AC-8 (bonus)      — capture() works regardless of _open_document_id state.
#
# WHAT IS NOT TESTED HERE
#   - spawn-gate behaviour (requires scene tree) — spawn_gate_test.gd (integration).
#   - pickup happy-path / idempotency — idempotency_test.gd (DC-003).
#
# GATE STATUS
#   Story DC-004 — Integration story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveContractTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a DocumentCollection added to the test scene tree so _ready() fires.
## auto_free() ensures cleanup after each test.
func _make_dc() -> DocumentCollection:
	var dc: DocumentCollection = DocumentCollection.new()
	add_child(dc)
	auto_free(dc)
	return dc


## Creates a DocumentCollectionState with the provided ids in collected.
## auto_free() ensures cleanup after each test.
func _make_state(ids: Array[StringName]) -> DocumentCollectionState:
	var state: DocumentCollectionState = DocumentCollectionState.new()
	state.collected = ids.duplicate()
	auto_free(state)
	return state


# ---------------------------------------------------------------------------
# AC-1 (AC-DC-5.1) — capture() returns defensive copy
# ---------------------------------------------------------------------------

## GIVEN DC has _collected = [&"plaza_logbook"]
## WHEN capture() is called
## THEN returned state.collected equals [&"plaza_logbook"]
## AND modifying _collected afterward does NOT modify the captured state.
## Aliasing break is via _collected.duplicate() in capture() (CR-6 + ADR-0003 IG 3).
func test_capture_returns_deep_copy() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	dc._collected = [&"plaza_logbook"]

	# Act
	var state: DocumentCollectionState = dc.capture()

	# Assert — state contains the correct id.
	assert_int(state.collected.size()).override_failure_message(
		"AC-1: capture() must return state with exactly one collected id."
	).is_equal(1)
	assert_bool(state.collected.has(&"plaza_logbook")).override_failure_message(
		"AC-1: capture() must include plaza_logbook in state.collected."
	).is_true()

	# Act — mutate DC's live _collected after capture.
	dc._collected.append(&"extra_id")

	# Assert — captured state is unaffected by the mutation (aliasing break).
	assert_int(state.collected.size()).override_failure_message(
		"AC-1: Mutation of _collected after capture() must NOT affect state.collected. "
		+ "Aliasing break (CR-6 + ADR-0003 IG 3) is required."
	).is_equal(1)


# ---------------------------------------------------------------------------
# AC-2 (AC-DC-5.2) — restore() populates _collected without aliasing
# ---------------------------------------------------------------------------

## GIVEN a DocumentCollectionState with collected = [&"plaza_logbook", &"lower_clipboard"]
## WHEN restore(state) is called
## THEN _collected equals [&"plaza_logbook", &"lower_clipboard"]
## AND modifying state.collected after restore does NOT affect _collected.
## Aliasing break is via state.collected.duplicate() in restore() (CR-6 + ADR-0003 IG 3).
func test_restore_populates_collected_without_aliasing() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()
	var ids: Array[StringName] = [&"plaza_logbook", &"lower_clipboard"]
	var state: DocumentCollectionState = _make_state(ids)

	# Act
	dc.restore(state)

	# Assert — _collected populated correctly.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-2: After restore(), _collected must have 2 elements."
	).is_equal(2)
	assert_bool(dc._collected.has(&"plaza_logbook")).override_failure_message(
		"AC-2: _collected must contain plaza_logbook after restore()."
	).is_true()
	assert_bool(dc._collected.has(&"lower_clipboard")).override_failure_message(
		"AC-2: _collected must contain lower_clipboard after restore()."
	).is_true()

	# Act — mutate state.collected after restore.
	state.collected.append(&"extra_id")

	# Assert — _collected is unaffected (aliasing break).
	assert_int(dc._collected.size()).override_failure_message(
		"AC-2: Mutation of state.collected after restore() must NOT affect _collected. "
		+ "Aliasing break (CR-6 + ADR-0003 IG 3) is required."
	).is_equal(2)


# ---------------------------------------------------------------------------
# AC-3 — restore(null) clears _collected and does not crash
# ---------------------------------------------------------------------------

## GIVEN restore(null) is called on a DC with existing _collected entries
## THEN _collected is cleared to []
## AND no crash occurs (null-guard per GDD §C.6).
func test_null_state_restore_clears_collected() -> void:
	# Arrange — DC with pre-existing collected ids.
	var dc: DocumentCollection = _make_dc()
	dc._collected = [&"plaza_logbook", &"embassy_dossier"]

	# Act — restore with null state (GDD §C.6 null-guard).
	dc.restore(null)

	# Assert — _collected cleared.
	assert_int(dc._collected.size()).override_failure_message(
		"AC-3: restore(null) must set _collected = [] (null-guard per GDD §C.6)."
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-7 (AC-DC-5.4) — _open_document_id not persisted in save
# ---------------------------------------------------------------------------

## GIVEN DC's _open_document_id is set to a non-empty value
## WHEN capture() is called
## THEN the returned state contains only collected: Array[StringName]
##      with no _open_document_id field.
## WHEN restore(state) is subsequently called
## THEN _open_document_id == &"" (not auto-restored).
func test_open_document_id_not_persisted_in_save() -> void:
	# Arrange — simulate an open document state.
	var dc: DocumentCollection = _make_dc()
	dc._collected = [&"plaza_logbook"]
	dc._open_document_id = &"plaza_logbook"

	# Act — capture state.
	var state: DocumentCollectionState = dc.capture()

	# Assert — state has collected but no open_document_id field.
	# DocumentCollectionState schema only has 'collected' (ADR-0003 frozen schema).
	assert_bool(state.collected.has(&"plaza_logbook")).override_failure_message(
		"AC-7: captured state must include plaza_logbook in collected."
	).is_true()
	# Verify the schema does NOT expose _open_document_id via property inspection.
	var prop_names: Array = []
	for prop in state.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			prop_names.append(prop["name"])
	assert_bool("_open_document_id" in prop_names).override_failure_message(
		"AC-7: DocumentCollectionState must NOT have an _open_document_id field "
		+ "(schema frozen per ADR-0003). Found these script properties: %s" % str(prop_names)
	).is_false()

	# Act — set a sentinel value to prove restore() doesn't touch _open_document_id.
	# We use a marker value so we can verify restore() leaves it untouched (not
	# auto-restored from state, not reset to default — simply ignored entirely).
	const SENTINEL: StringName = &"sentinel_overlay_state"
	dc._open_document_id = SENTINEL
	dc.restore(state)

	# Assert — _open_document_id is unchanged after restore (AC-DC-5.4).
	# restore() must NOT auto-populate _open_document_id from state (which has no
	# such field per ADR-0003 frozen schema), and must NOT reset it either —
	# Document Overlay UI manages _open_document_id independently of save/load.
	assert_str(String(dc._open_document_id)).override_failure_message(
		"AC-7: restore() must NOT touch _open_document_id (neither auto-restore "
		+ "from state nor reset to default). Expected sentinel '%s' to be unchanged, "
		+ "got: '%s'" % [String(SENTINEL), String(dc._open_document_id)]
	).is_equal(String(SENTINEL))


# ---------------------------------------------------------------------------
# AC-8 (bonus) — capture() succeeds regardless of _open_document_id state
# ---------------------------------------------------------------------------

## GIVEN DC has a non-empty _open_document_id (simulating mid-read state)
## AND has entries in _collected
## WHEN capture() is called
## THEN the returned state correctly reflects _collected
##      and the open_document state does not corrupt the snapshot.
func test_capture_succeeds_with_open_document_state() -> void:
	# Arrange — DC in "document open" state.
	var dc: DocumentCollection = _make_dc()
	dc._collected = [&"eiffel_memo", &"lobby_dossier"]
	dc._open_document_id = &"eiffel_memo"

	# Act
	var state: DocumentCollectionState = dc.capture()

	# Assert — state reflects _collected accurately.
	assert_int(state.collected.size()).override_failure_message(
		"AC-8: capture() while a document is open must still return correct state.collected."
	).is_equal(2)
	assert_bool(state.collected.has(&"eiffel_memo")).override_failure_message(
		"AC-8: state.collected must include eiffel_memo."
	).is_true()
	assert_bool(state.collected.has(&"lobby_dossier")).override_failure_message(
		"AC-8: state.collected must include lobby_dossier."
	).is_true()
