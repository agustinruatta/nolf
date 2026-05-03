# tests/unit/feature/document_collection/document_resource_schema_test.gd
#
# DocumentResourceSchemaTest — GdUnit4 unit suite for the Document Resource schema.
#
# PURPOSE
#   Validates the `Document` Resource class per Document Collection GDD AC-DC-1.1
#   (§H.1). This suite is the automated evidence gate for Story DC-001.
#
# COVERED ACCEPTANCE CRITERIA (AC-DC-1.1, §H.1)
#   AC-1 — Document extends Resource and is class_name-registered.
#   AC-2 — All six fields are present with correct GDScript types.
#   AC-3 — Default values match the §C.2 schema table:
#             id = &""
#             title_key = &""
#             body_key = &""
#             section_id = &""
#             interact_label_key = &"ui.interact.read_document"
#             tier_override = -1
#   AC-4 — title_key / body_key / interact_label_key are StringName (key-only),
#           not resolved strings; a freshly-constructed Document stores no
#           visible user-facing string (no tr() call, no raw content).
#   AC-5 — tier_override default is -1 (meaning "use ADR-0001 Tier 1";
#           any other value would override the stencil tier).
#   AC-6 — Fields accept valid authored values without type coercion errors.
#   AC-7 — A Document with a well-formed id round-trips through ResourceSaver /
#           ResourceLoader and returns field-equal values.
#
# WHAT IS NOT TESTED HERE
#   - DocumentBody node (scene-level, not testable headlessly) — CI lint §C.5.6.
#   - mission-wide id uniqueness — CI scene-validation lint §C.5.6 lint #2.
#   - tr() resolution — subscriber responsibility (Document Overlay UI #20, VS).
#   - `collect()` / `restore()` lifecycle — tests/unit/feature/document_collection/
#     (separate suite, Story DC-002+).
#
# GATE STATUS
#   Story DC-001 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name DocumentResourceSchemaTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a freshly constructed Document. auto_free() ensures cleanup after
## each test regardless of assertions.
func _make_document() -> Document:
	var doc: Document = Document.new()
	auto_free(doc)
	return doc


## Returns a Document populated with valid authored values for round-trip tests.
func _make_valid_document() -> Document:
	var doc: Document = Document.new()
	doc.id = &"plaza_security_logbook_001"
	doc.title_key = &"doc.plaza_security_logbook_001.title"
	doc.body_key = &"doc.plaza_security_logbook_001.body"
	doc.section_id = &"plaza"
	doc.interact_label_key = &"ui.interact.read_document"
	doc.tier_override = -1
	auto_free(doc)
	return doc


# ---------------------------------------------------------------------------
# AC-1 — Document extends Resource and is class_name-registered
# ---------------------------------------------------------------------------

## Document.new() returns a non-null instance that is a Resource and a Document.
func test_document_extends_resource_and_class_name_resolves() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert
	assert_object(doc).override_failure_message(
		"AC-1: Document.new() must return a non-null instance."
	).is_not_null()

	assert_bool(doc is Resource).override_failure_message(
		"AC-1: Document must extend Resource."
	).is_true()

	assert_bool(doc is Document).override_failure_message(
		"AC-1: class_name Document must be resolvable (not an anonymous Resource)."
	).is_true()


# ---------------------------------------------------------------------------
# AC-2 — All six fields present with correct GDScript types
# ---------------------------------------------------------------------------

## `id` field is present and is of type StringName (TYPE_STRING_NAME).
func test_document_id_field_is_string_name_type() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert
	assert_int(typeof(doc.id)).override_failure_message(
		"AC-2: Document.id must be TYPE_STRING_NAME (%d). Got type %d."
		% [TYPE_STRING_NAME, typeof(doc.id)]
	).is_equal(TYPE_STRING_NAME)


## `title_key` field is present and is of type StringName.
func test_document_title_key_field_is_string_name_type() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert
	assert_int(typeof(doc.title_key)).override_failure_message(
		"AC-2: Document.title_key must be TYPE_STRING_NAME (%d). Got type %d."
		% [TYPE_STRING_NAME, typeof(doc.title_key)]
	).is_equal(TYPE_STRING_NAME)


## `body_key` field is present and is of type StringName.
func test_document_body_key_field_is_string_name_type() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert
	assert_int(typeof(doc.body_key)).override_failure_message(
		"AC-2: Document.body_key must be TYPE_STRING_NAME (%d). Got type %d."
		% [TYPE_STRING_NAME, typeof(doc.body_key)]
	).is_equal(TYPE_STRING_NAME)


## `section_id` field is present and is of type StringName.
func test_document_section_id_field_is_string_name_type() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert
	assert_int(typeof(doc.section_id)).override_failure_message(
		"AC-2: Document.section_id must be TYPE_STRING_NAME (%d). Got type %d."
		% [TYPE_STRING_NAME, typeof(doc.section_id)]
	).is_equal(TYPE_STRING_NAME)


## `interact_label_key` field is present and is of type StringName.
func test_document_interact_label_key_field_is_string_name_type() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert
	assert_int(typeof(doc.interact_label_key)).override_failure_message(
		"AC-2: Document.interact_label_key must be TYPE_STRING_NAME (%d). Got type %d."
		% [TYPE_STRING_NAME, typeof(doc.interact_label_key)]
	).is_equal(TYPE_STRING_NAME)


## `tier_override` field is present and is of type int (TYPE_INT).
func test_document_tier_override_field_is_int_type() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert
	assert_int(typeof(doc.tier_override)).override_failure_message(
		"AC-2: Document.tier_override must be TYPE_INT (%d). Got type %d."
		% [TYPE_INT, typeof(doc.tier_override)]
	).is_equal(TYPE_INT)


# ---------------------------------------------------------------------------
# AC-3 — Default values match the §C.2 schema table
# ---------------------------------------------------------------------------

## id defaults to the empty StringName (&"").
func test_document_default_id_is_empty_string_name() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert
	assert_str(String(doc.id)).override_failure_message(
		"AC-3: Document.id must default to the empty StringName (&\"\")."
	).is_empty()


## title_key defaults to the empty StringName.
func test_document_default_title_key_is_empty_string_name() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert
	assert_str(String(doc.title_key)).override_failure_message(
		"AC-3: Document.title_key must default to the empty StringName (&\"\")."
	).is_empty()


## body_key defaults to the empty StringName.
func test_document_default_body_key_is_empty_string_name() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert
	assert_str(String(doc.body_key)).override_failure_message(
		"AC-3: Document.body_key must default to the empty StringName (&\"\")."
	).is_empty()


## section_id defaults to the empty StringName.
func test_document_default_section_id_is_empty_string_name() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert
	assert_str(String(doc.section_id)).override_failure_message(
		"AC-3: Document.section_id must default to the empty StringName (&\"\")."
	).is_empty()


## interact_label_key defaults to &"ui.interact.read_document" (canonical schema default per §C.2).
func test_document_default_interact_label_key_is_read_document() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert — exact StringName equality.
	assert_str(String(doc.interact_label_key)).override_failure_message(
		"AC-3: Document.interact_label_key must default to &\"ui.interact.read_document\" (canonical schema default per §C.2)."
	).is_equal("ui.interact.read_document")


## tier_override defaults to -1 (= no override; use ADR-0001 Tier 1).
func test_document_default_tier_override_is_minus_one() -> void:
	# Arrange / Act
	var doc: Document = _make_document()

	# Assert
	assert_int(doc.tier_override).override_failure_message(
		"AC-3: Document.tier_override must default to -1 (ADR-0001 Tier 1, no override)."
	).is_equal(-1)


# ---------------------------------------------------------------------------
# AC-4 — Content fields are Localization keys, not resolved strings
# ---------------------------------------------------------------------------

## title_key and body_key on a freshly-constructed Document do not contain any
## period-delimited resolved content — they are either empty or follow the
## `doc.[id].title` / `doc.[id].body` key convention (plain StringName, never
## a tr()-resolved visible string). This test verifies that no hardcoded
## visible content leaks into the default Resource.
##
## Note: CR-8 forbids this Resource from calling tr(). The test cannot run
## tr() (headless Godot has no locale data), so it verifies the structural
## invariant: the default values contain no visible prose.
func test_document_content_fields_are_keys_not_resolved_strings() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert: default title_key is empty — no hardcoded visible string.
	assert_str(String(doc.title_key)).override_failure_message(
		"AC-4: Document.title_key must be an empty StringName by default (key-only; no hardcoded visible string per CR-8 + ADR-0004)."
	).is_empty()

	# Assert: default body_key is empty — no hardcoded visible string.
	assert_str(String(doc.body_key)).override_failure_message(
		"AC-4: Document.body_key must be an empty StringName by default (key-only; no hardcoded visible string per CR-8 + ADR-0004)."
	).is_empty()


## A Document with authored keys follows the `doc.[id].*` convention —
## the key strings contain no spaces (raw keys, not resolved prose).
func test_document_authored_keys_contain_no_spaces() -> void:
	# Arrange — populate as a level-designer would in a .tres file.
	var doc: Document = _make_valid_document()

	# Assert: key strings must not contain spaces (a resolved string would have spaces).
	assert_bool(String(doc.title_key).contains(" ")).override_failure_message(
		"AC-4: Document.title_key must not contain spaces — it is a Localization key, not resolved prose. Got: '%s'" % String(doc.title_key)
	).is_false()

	assert_bool(String(doc.body_key).contains(" ")).override_failure_message(
		"AC-4: Document.body_key must not contain spaces — it is a Localization key, not resolved prose. Got: '%s'" % String(doc.body_key)
	).is_false()

	assert_bool(String(doc.interact_label_key).contains(" ")).override_failure_message(
		"AC-4: Document.interact_label_key must not contain spaces — it is a Localization key, not resolved prose. Got: '%s'" % String(doc.interact_label_key)
	).is_false()


# ---------------------------------------------------------------------------
# AC-5 — tier_override default is -1 (Tier 1 pass-through)
# ---------------------------------------------------------------------------

## tier_override == -1 means "use ADR-0001 Tier 1 globally"; any other value
## is an explicit per-document override requiring art-director sign-off.
## This test is a named alias of the AC-3 tier_override test, included
## separately because AC-5 is a distinct acceptance criterion.
func test_document_tier_override_default_sentinel_is_minus_one() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Assert: sentinel value for "no override" must be exactly -1.
	assert_int(doc.tier_override).override_failure_message(
		"AC-5: tier_override == -1 is the sentinel for 'use ADR-0001 Tier 1'. Default must be -1."
	).is_equal(-1)


## A non-(-1) tier_override is accepted without type error (reserved for VS edge cases).
func test_document_tier_override_accepts_valid_tier_values() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Act — set to each valid ADR-0001 tier (1, 2, 3) and back to -1.
	for tier: int in [1, 2, 3, -1]:
		doc.tier_override = tier
		# Assert: value round-trips without coercion.
		assert_int(doc.tier_override).override_failure_message(
			"AC-5: tier_override must accept value %d without coercion." % tier
		).is_equal(tier)


# ---------------------------------------------------------------------------
# AC-6 — Fields accept valid authored values without type coercion errors
# ---------------------------------------------------------------------------

## All six fields can be set to representative authored values in one call
## without type errors, null crashes, or silent coercions.
func test_document_all_fields_accept_valid_authored_values() -> void:
	# Arrange
	var doc: Document = _make_document()

	# Act — assign representative Plaza MVP document values.
	doc.id = &"plaza_tourist_register_001"
	doc.title_key = &"doc.plaza_tourist_register_001.title"
	doc.body_key = &"doc.plaza_tourist_register_001.body"
	doc.section_id = &"plaza"
	doc.interact_label_key = &"ui.interact.pocket_document"
	doc.tier_override = -1

	# Assert — each field round-trips its assigned value.
	assert_str(String(doc.id)).override_failure_message(
		"AC-6: id must round-trip the assigned StringName value."
	).is_equal("plaza_tourist_register_001")

	assert_str(String(doc.title_key)).override_failure_message(
		"AC-6: title_key must round-trip the assigned StringName value."
	).is_equal("doc.plaza_tourist_register_001.title")

	assert_str(String(doc.body_key)).override_failure_message(
		"AC-6: body_key must round-trip the assigned StringName value."
	).is_equal("doc.plaza_tourist_register_001.body")

	assert_str(String(doc.section_id)).override_failure_message(
		"AC-6: section_id must round-trip the assigned StringName value."
	).is_equal("plaza")

	assert_str(String(doc.interact_label_key)).override_failure_message(
		"AC-6: interact_label_key must round-trip the assigned StringName value."
	).is_equal("ui.interact.read_document")

	assert_int(doc.tier_override).override_failure_message(
		"AC-6: tier_override must round-trip the assigned int value (-1)."
	).is_equal(-1)


# ---------------------------------------------------------------------------
# AC-7 — ResourceSaver / ResourceLoader round-trip preserves all fields
# ---------------------------------------------------------------------------

## A Document saved via ResourceSaver and loaded via ResourceLoader returns
## field-equal values across all six fields. This validates that the @export
## annotations survive Godot's serialization round-trip (critical for .tres
## authoring by level-designers).
##
## The test writes to a deterministic user:// path and cleans up in after_test().
## ResourceLoader logs an internal error on a missing file — that is expected
## Godot behaviour when the path doesn't exist yet. This test creates the file.
func test_document_resource_round_trip_preserves_all_fields() -> void:
	const _ROUND_TRIP_PATH: String = "user://test_doc_schema_round_trip.tres"

	# Arrange — clean up any stale file from a prior failed run.
	if FileAccess.file_exists(_ROUND_TRIP_PATH):
		DirAccess.remove_absolute(_ROUND_TRIP_PATH)

	var original: Document = Document.new()
	original.id = &"plaza_security_logbook_001"
	original.title_key = &"doc.plaza_security_logbook_001.title"
	original.body_key = &"doc.plaza_security_logbook_001.body"
	original.section_id = &"plaza"
	original.interact_label_key = &"ui.interact.read_document"
	original.tier_override = -1

	# Act — save.
	var save_err: Error = ResourceSaver.save(original, _ROUND_TRIP_PATH)
	assert_int(save_err).override_failure_message(
		"AC-7: ResourceSaver.save must return OK for a valid Document Resource."
	).is_equal(OK)

	# Act — load (CACHE_MODE_IGNORE forces a fresh disk read).
	var loaded: Resource = ResourceLoader.load(
		_ROUND_TRIP_PATH,
		"Document",
		ResourceLoader.CACHE_MODE_IGNORE
	)

	# Assert — type guard.
	assert_object(loaded).override_failure_message(
		"AC-7: ResourceLoader.load must return a non-null Resource for the saved Document."
	).is_not_null()

	assert_bool(loaded is Document).override_failure_message(
		"AC-7: Loaded Resource must be a Document instance (class_name preserved across round-trip)."
	).is_true()

	var loaded_doc: Document = loaded as Document

	# Assert — field equality.
	assert_str(String(loaded_doc.id)).override_failure_message(
		"AC-7: id must survive ResourceSaver round-trip unchanged."
	).is_equal("plaza_security_logbook_001")

	assert_str(String(loaded_doc.title_key)).override_failure_message(
		"AC-7: title_key must survive ResourceSaver round-trip unchanged."
	).is_equal("doc.plaza_security_logbook_001.title")

	assert_str(String(loaded_doc.body_key)).override_failure_message(
		"AC-7: body_key must survive ResourceSaver round-trip unchanged."
	).is_equal("doc.plaza_security_logbook_001.body")

	assert_str(String(loaded_doc.section_id)).override_failure_message(
		"AC-7: section_id must survive ResourceSaver round-trip unchanged."
	).is_equal("plaza")

	assert_str(String(loaded_doc.interact_label_key)).override_failure_message(
		"AC-7: interact_label_key must survive ResourceSaver round-trip unchanged."
	).is_equal("ui.interact.pocket_document")

	assert_int(loaded_doc.tier_override).override_failure_message(
		"AC-7: tier_override must survive ResourceSaver round-trip unchanged (-1)."
	).is_equal(-1)

	# Cleanup — remove the temp file.
	DirAccess.remove_absolute(_ROUND_TRIP_PATH)
