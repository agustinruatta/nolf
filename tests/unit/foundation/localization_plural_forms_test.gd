# tests/unit/foundation/localization_plural_forms_test.gd
#
# LocalizationPluralFormsTest — GdUnit4 suite for Story LOC-003.
#
# PURPOSE
#   Verifies plural form CSV support and named-placeholder discipline:
#     • hud.csv has the required `?plural` marker column + ?pluralrule directive
#       row + row-repetition continuation rows for hud.collection.count
#     • tr_n() returns the correct plural form for counts 0 / 1 / 7
#     • String.format() named-placeholder substitution works on tr() result
#     • No positional % substitution on tr() results in src/ (AC-6 grep)
#     • Godot 4.6 plural API smoke: counts 0/1/2/7 each return correct distinct form
#
# GOVERNING REQUIREMENTS
#   TR-LOC-004 (named placeholders {count} via String.format; positional %s forbidden)
#   TR-LOC-005 (plural forms via Godot 4.6 CSV plural columns en_0/en_1/en_other)
#   ADR-0004 §Engine Compatibility — this test closes the plural API verification gate
#
# ENGINE API DISCOVERY (LOC-003 close-out, 2026-05-03)
#   Godot 4.6 CSV plural support does NOT use locale-suffixed columns
#   (en_0/en_1/en_other or en_zero/en_one/en_other). The actual format is:
#     • a `?plural` marker column (header) — holds msgid_plural per key
#     • a special `?pluralrule` directive row (column-0 == "?pluralrule") that
#       declares the gettext-style plural function per locale
#     • row-repetition: subsequent rows with empty msgid carry plural-form values
#       in the locale column, indexed per the plural rule
#   Source: editor/import/resource_importer_csv_translation.cpp +
#   docs.godotengine.org/en/4.6/tutorials/i18n/localization_using_spreadsheets.html
#   (See story LOC-003 Completion Notes + GDD §Detailed Design Rule 5 amendment.)
#
# GATE STATUS
#   Story LOC-003 | Logic type → BLOCKING gate. TR-LOC-004, TR-LOC-005.

class_name LocalizationPluralFormsTest
extends GdUnitTestSuite

const _HUD_CSV: String = "res://translations/hud.csv"
const _SRC_DIR: String = "res://src"
const _PLURAL_KEY: StringName = &"hud.collection.count"
## msgid_plural value from the `?plural` column for hud.collection.count.
const _PLURAL_MSGID: StringName = &"1 document"

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_saved_locale)


# ── AC-1: Plural CSV row + ?plural marker + ?pluralrule directive ─────────────

## AC-1: hud.csv has the `?plural` marker column in the header, the
## `?pluralrule` directive row declaring the English nplurals=3 rule, and the
## hud.collection.count row's `?plural` cell is populated with the plural msgid.
## The `# context` cell includes a `# plural_rule` annotation per Rule 5.
func test_plural_csv_row_has_required_columns_and_directive() -> void:
	# Arrange
	var f: FileAccess = FileAccess.open(_HUD_CSV, FileAccess.READ)
	assert_object(f).override_failure_message(
		"hud.csv must be readable at %s." % _HUD_CSV
	).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = content.split("\n")

	assert_bool(lines.size() > 0).override_failure_message(
		"hud.csv must not be empty."
	).is_true()
	var header_cells: Array[String] = _split_csv_cells(lines[0])
	var col_index: Dictionary = {}
	for i: int in range(header_cells.size()):
		col_index[header_cells[i].strip_edges()] = i

	# Assert: required columns present.
	for required_col: String in ["keys", "?plural", "en", "# context"]:
		assert_bool(col_index.has(required_col)).override_failure_message(
			"hud.csv header must contain column '%s'. Header: '%s'" % [required_col, lines[0]]
		).is_true()

	# Find the ?pluralrule directive row + the hud.collection.count row.
	var pluralrule_row: Array[String] = []
	var target_row: Array[String] = []
	for i: int in range(1, lines.size()):
		var line: String = lines[i]
		if line.strip_edges() == "":
			continue
		var cells: Array[String] = _split_csv_cells(line)
		if cells.size() == 0:
			continue
		var key: String = cells[0].strip_edges()
		if key == "?pluralrule":
			pluralrule_row = cells
		elif key == "hud.collection.count":
			target_row = cells

	# Assert: ?pluralrule directive exists and declares 3 plural forms for English.
	assert_bool(pluralrule_row.size() > 0).override_failure_message(
		"hud.csv must contain a '?pluralrule' directive row to declare the English plural function."
	).is_true()
	var en_idx: int = col_index["en"]
	var rule_text: String = pluralrule_row[en_idx] if en_idx < pluralrule_row.size() else ""
	assert_bool(rule_text.contains("nplurals=3")).override_failure_message(
		"?pluralrule for 'en' must declare nplurals=3 (zero/one/other). Got: '%s'" % rule_text
	).is_true()

	# Assert: hud.collection.count row exists with populated ?plural + en cells.
	assert_bool(target_row.size() > 0).override_failure_message(
		"hud.csv must contain a row with key 'hud.collection.count'."
	).is_true()
	var plural_msgid: String = target_row[col_index["?plural"]] if col_index["?plural"] < target_row.size() else ""
	var en_cell: String = target_row[en_idx] if en_idx < target_row.size() else ""
	var context_cell: String = target_row[col_index["# context"]] if col_index["# context"] < target_row.size() else ""
	assert_str(plural_msgid).override_failure_message(
		"hud.collection.count ?plural cell must be '1 document'. Got: '%s'" % plural_msgid
	).is_equal("1 document")
	assert_str(en_cell).override_failure_message(
		"hud.collection.count en cell must be the zero-form 'no documents'. Got: '%s'" % en_cell
	).is_equal("no documents")
	assert_bool(context_cell.contains("# plural_rule")).override_failure_message(
		"hud.collection.count # context must contain '# plural_rule' annotation. Got: '%s'" % context_cell
	).is_true()


# ── AC-2: tr_n count=0 returns zero form ─────────────────────────────────────

## AC-2: tr_n("hud.collection.count", "1 document", 0) returns "no documents".
## Per the custom ?pluralrule for English (n==0?0:n==1?1:2), count=0 selects form 0.
func test_tr_n_count_zero_returns_no_documents_form() -> void:
	# Arrange: locale is "en" (set in before_test).

	# Act
	var result: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 0)

	# Assert
	assert_str(result).override_failure_message(
		(
			"tr_n('hud.collection.count', '1 document', 0) must return 'no documents' (form 0)."
			+ " Got: '%s'."
			+ " DIAGNOSTIC: If this returns the msgid_plural verbatim or another form, the"
			+ " ?pluralrule directive may not have been imported, or the English plural rule"
			+ " (n==0?0:n==1?1:2) is not being applied. Verify hud.csv was re-imported and"
			+ " the ?pluralrule row uses the correct gettext expression."
		) % result
	).is_equal("no documents")


# ── AC-3: tr_n count=1 returns singular form ──────────────────────────────────

## AC-3: tr_n("hud.collection.count", "1 document", 1) returns "1 document".
## Per the custom ?pluralrule, count=1 selects form 1.
func test_tr_n_count_one_returns_singular_form() -> void:
	# Arrange: locale is "en".

	# Act
	var result: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 1)

	# Assert
	assert_str(result).override_failure_message(
		"tr_n('hud.collection.count', '1 document', 1) must return '1 document' (form 1). Got: '%s'" % result
	).is_equal("1 document")


# ── AC-4: tr_n count=7 returns other form with {count} substitution ───────────

## AC-4: tr_n("hud.collection.count", "1 document", 7).format({"count": 7})
## returns "7 documents collected". Form 2 is the en "other" form template.
func test_tr_n_count_seven_format_returns_other_form_with_substitution() -> void:
	# Arrange: locale is "en".

	# Act
	var raw_result: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 7)
	var final_result: String = raw_result.format({"count": 7})

	# Assert: raw result is the form-2 template.
	assert_str(raw_result).override_failure_message(
		"tr_n(..., 7) must return form 2 ('{count} documents collected'). Got: '%s'" % raw_result
	).is_equal("{count} documents collected")
	assert_str(final_result).override_failure_message(
		"After .format({'count': 7}), result must be '7 documents collected'. Got: '%s'" % final_result
	).is_equal("7 documents collected")


# ── AC-5: Named placeholder substitution (non-plural) ────────────────────────

## AC-5: tr("hud.section.entered_label").format({"section_name": "Plaza"})
## returns "Entering: Plaza". Named placeholder {section_name} is substituted.
func test_tr_format_named_placeholder_substitution_substitutes_section_name() -> void:
	# Arrange: locale is "en".

	# Act
	var result: String = tr("hud.section.entered_label").format({"section_name": "Plaza"})

	# Assert
	assert_str(result).override_failure_message(
		"tr('hud.section.entered_label').format({'section_name': 'Plaza'}) must return 'Entering: Plaza'. Got: '%s'" % result
	).is_equal("Entering: Plaza")


## AC-5 edge case: passing wrong key in format dict leaves the placeholder intact.
## Godot's String.format() returns the original {section_name} when the key is absent.
func test_tr_format_missing_placeholder_key_leaves_placeholder_intact() -> void:
	# Arrange
	var raw: String = tr("hud.section.entered_label")

	# Act: pass a wrong key — {section_name} must remain unchanged.
	var result: String = raw.format({"wrong_key": "X"})

	# Assert: no crash, placeholder unchanged.
	assert_str(result).override_failure_message(
		"tr('hud.section.entered_label').format({'wrong_key': 'X'}) must leave '{section_name}' intact. Got: '%s'" % result
	).contains("{section_name}")


# ── AC-6: No positional tr() % [...] format in src/ ──────────────────────────

## AC-6: Zero occurrences of `tr(...) % [...]` positional substitution in src/.
## Forbidden pattern: TR-LOC-004 mandates named placeholders only (String.format).
## Formal lint registration is in Story LOC-005; this test closes the grep gate.
func test_no_positional_format_substitution_in_src_production_code() -> void:
	# Arrange: recursive scan of res://src/ for .gd files.
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []

	# Regex: tr(...) followed by optional whitespace, then % [  (positional array substitution).
	var pattern: RegEx = RegEx.new()
	var compile_result: int = pattern.compile("tr\\([^)]*\\)\\s*%\\s*\\[")
	assert_int(compile_result).override_failure_message(
		"Failed to compile positional-substitution grep regex."
	).is_equal(OK)

	# Act: scan each file for the forbidden pattern.
	for file_path: String in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var content: String = f.get_as_text()
		f.close()
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			# Skip comment lines.
			if line.strip_edges().begins_with("#"):
				continue
			if pattern.search(line) != null:
				violations.append("%s:%d — %s" % [file_path, i + 1, line.strip_edges()])

	# Assert: zero matches.
	assert_int(violations.size()).override_failure_message(
		(
			"FORBIDDEN PATTERN (TR-LOC-004): positional tr() %% [...] substitution found in src/.\n"
			+ "Use String.format({'name': value}) on tr() result instead.\n"
			+ "Violations:\n  %s"
		) % "\n  ".join(violations)
	).is_equal(0)


# ── AC-7: Godot 4.6 plural API smoke — counts 0/1/2/7 all return distinct forms ─

## AC-7: Smoke test verifying Godot 4.6 CSV plural API for counts 0/1/2/7.
## Counts 0 and 1 select forms 0 and 1; counts 2 and 7 both select form 2 (other).
## Closes ADR-0004 §Engine Compatibility verification gate.
func test_godot_4_6_plural_api_smoke_distinct_strings_for_counts() -> void:
	# Arrange: locale is "en".
	var test_cases: Array = [
		{"count": 0, "expected_raw": "no documents", "description": "count=0 → form 0 (zero)"},
		{"count": 1, "expected_raw": "1 document", "description": "count=1 → form 1 (one)"},
		{"count": 2, "expected_raw": "{count} documents collected", "description": "count=2 → form 2 (other)"},
		{"count": 7, "expected_raw": "{count} documents collected", "description": "count=7 → form 2 (other)"},
	]

	var mismatches: Array[String] = []

	for tc: Dictionary in test_cases:
		var count_val: int = tc["count"]
		var expected_raw: String = tc["expected_raw"]
		var description: String = tc["description"]

		# Act
		var raw: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, count_val)
		var resolved: String = raw.format({"count": count_val}) if raw.contains("{count}") else raw

		# Determine expected final string after substitution.
		var expected_final: String = expected_raw.format({"count": count_val}) if expected_raw.contains("{count}") else expected_raw

		if resolved != expected_final:
			mismatches.append(
				"%s: expected '%s', got '%s' (raw from tr_n: '%s')" % [description, expected_final, resolved, raw]
			)

	# Assert: all four must match.
	assert_int(mismatches.size()).override_failure_message(
		(
			"Godot 4.6 plural API mismatch — see ADR-0004 §Engine Compatibility verification gate.\n"
			+ "Mismatches:\n  %s\n"
			+ "DIAGNOSTIC: Verify hud.csv has been re-imported and ?pluralrule directive uses the\n"
			+ "expected gettext expression: nplurals=3; plural=(n==0?0:n==1?1:2);"
		) % "\n  ".join(mismatches)
	).is_equal(0)

	# Additionally verify forms 0 and 1 are DISTINCT from form 2.
	var result_0: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 0)
	var result_1: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 1)
	var result_2: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 2)
	var result_7: String = tr_n(_PLURAL_KEY, _PLURAL_MSGID, 7)

	assert_bool(result_0 != result_1).override_failure_message(
		"count=0 and count=1 must return DISTINCT raw strings. Both returned: '%s'" % result_0
	).is_true()
	assert_bool(result_0 != result_7).override_failure_message(
		"count=0 and count=7 must return DISTINCT raw strings. Both returned: '%s'" % result_0
	).is_true()
	assert_bool(result_1 != result_7).override_failure_message(
		"count=1 and count=7 must return DISTINCT raw strings. Both returned: '%s'" % result_1
	).is_true()
	# count=2 and count=7 are both form 2 (other) — expect the same raw template.
	assert_str(result_2).override_failure_message(
		"count=2 must return form 2 (same template as count=7). count_2='%s', count_7='%s'" % [result_2, result_7]
	).is_equal(result_7)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Recursively collect all .gd files under a res:// directory path.
func _collect_gd_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			results.append_array(_collect_gd_files(full_path))
		elif entry.ends_with(".gd"):
			results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


## Split a CSV line into all its cells, respecting double-quoted fields.
## Strips surrounding double-quote characters from quoted cells.
func _split_csv_cells(line: String) -> Array[String]:
	var cells: Array[String] = []
	var current: String = ""
	var in_quote: bool = false
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if c == "\"":
			in_quote = not in_quote
		elif c == "," and not in_quote:
			cells.append(current)
			current = ""
		else:
			current += c
		i += 1
	cells.append(current)
	return cells
