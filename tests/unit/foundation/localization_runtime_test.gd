# tests/unit/foundation/localization_runtime_test.gd
#
# LocalizationRuntimeTest — GdUnit4 suite for Story LOC-001.
#
# PURPOSE
#   Verifies the project's localization scaffold is sound:
#     • All 10 domain CSVs exist with valid headers + at least one row
#     • project.godot [internationalization] block lists all 10 translation artifacts
#     • locale/fallback = "en"
#     • tr() returns English values for known keys
#     • tr() returns the key verbatim for unknown keys (loud-and-obvious miss)
#     • Fallback locale path: setting locale to a non-loaded locale still returns en
#     • Every CSV row's `# context` cell is non-empty
#     • All keys match the 3-segment domain.context.identifier regex
#     • Existing overlay.csv keys still resolve (regression guard)
#
# METHOD
#   Read project.godot + each translations/*.csv via FileAccess; call tr() against
#   the live TranslationServer for resolution checks. Saves and restores
#   TranslationServer.set_locale() across tests to avoid cross-test pollution.
#
# GATE STATUS
#   Story LOC-001 | Logic type → BLOCKING gate. TR-LOC-002, TR-LOC-003.

class_name LocalizationRuntimeTest
extends GdUnitTestSuite

const _PROJECT_PATH: String = "res://project.godot"
const _TRANSLATIONS_DIR: String = "res://translations"
const _DOMAINS: Array[String] = [
	"overlay", "hud", "menu", "settings", "meta",
	"dialogue", "cutscenes", "mission", "credits", "doc"
]
## 3-segment minimum: domain.context.identifier; lowercase snake_case dot-separated;
## additional sub-segments allowed (e.g. dialogue.guard.patrol.line_03).
const _KEY_REGEX_PATTERN: String = "^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*(\\.[a-z0-9_]+)*$"

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_saved_locale)


# ── AC-1: project.godot internationalization block ───────────────────────────

## AC-1: All 10 domain translation artifacts listed in project.godot.
func test_project_godot_lists_all_10_translation_artifacts() -> void:
	var content: String = _read_project_godot()
	for domain: String in _DOMAINS:
		var artifact: String = "res://translations/%s.en.translation" % domain
		assert_str(content).override_failure_message(
			"project.godot [internationalization] must list '%s'." % artifact
		).contains(artifact)


## AC-1: locale/fallback is set to "en".
func test_project_godot_locale_fallback_is_en() -> void:
	var content: String = _read_project_godot()
	assert_str(content).override_failure_message(
		"project.godot must contain locale/fallback=\"en\"."
	).contains("locale/fallback=\"en\"")


## AC-1: TranslationServer reports "en" among loaded locales after import.
func test_translation_server_loaded_locales_contains_en() -> void:
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	var has_en: bool = false
	for loc: String in locales:
		if loc == "en":
			has_en = true
			break
	assert_bool(has_en).override_failure_message(
		"TranslationServer.get_loaded_locales() must contain 'en'. Got: %s" % [locales]
	).is_true()


# ── AC-2: Each domain CSV exists with header + at least one data row ─────────

## AC-2: All 10 domain CSV files exist.
func test_all_10_domain_csv_files_exist() -> void:
	for domain: String in _DOMAINS:
		var path: String = "%s/%s.csv" % [_TRANSLATIONS_DIR, domain]
		assert_bool(FileAccess.file_exists(path)).override_failure_message(
			"Domain CSV file must exist at '%s'." % path
		).is_true()


## AC-2: Every CSV has a valid header row.
func test_every_csv_has_valid_header_row() -> void:
	for domain: String in _DOMAINS:
		var path: String = "%s/%s.csv" % [_TRANSLATIONS_DIR, domain]
		var first_line: String = _read_first_line(path)
		assert_str(first_line).override_failure_message(
			"%s.csv first line must be 'keys,en,# context'. Got: '%s'" % [domain, first_line]
		).is_equal("keys,en,# context")


## AC-2: Every CSV has at least one data row beyond the header.
func test_every_csv_has_at_least_one_data_row() -> void:
	for domain: String in _DOMAINS:
		var path: String = "%s/%s.csv" % [_TRANSLATIONS_DIR, domain]
		var lines: PackedStringArray = _read_all_lines(path)
		assert_int(lines.size()).override_failure_message(
			"%s.csv must have at least 2 lines (header + data). Got: %d" % [domain, lines.size()]
		).is_greater_equal(2)


# ── AC-3: tr() resolves a known key ──────────────────────────────────────────

## AC-3: tr("menu.main.start_mission") returns "Start Mission".
func test_tr_resolves_known_menu_key_to_english() -> void:
	TranslationServer.set_locale("en")
	var resolved: String = tr("menu.main.start_mission")
	assert_str(resolved).override_failure_message(
		"tr('menu.main.start_mission') must return 'Start Mission'. Got: '%s'" % resolved
	).is_equal("Start Mission")


# ── AC-4: tr() returns key verbatim for missing key ──────────────────────────

## AC-4: Missing key returns the key string itself (Godot fallback contract).
func test_tr_missing_key_returns_key_verbatim() -> void:
	TranslationServer.set_locale("en")
	var resolved: String = tr("nonexistent.fake.key")
	assert_str(resolved).override_failure_message(
		"tr('nonexistent.fake.key') must return the key verbatim. Got: '%s'" % resolved
	).is_equal("nonexistent.fake.key")


# ── AC-5: Fallback to base locale ────────────────────────────────────────────

## AC-5: Setting locale to a non-loaded locale (e.g. fr) → tr() falls back to en.
## At MVP only "en" is loaded; this AC validates the fallback CONFIG works.
func test_tr_falls_back_to_en_when_locale_is_not_loaded() -> void:
	TranslationServer.set_locale("fr")  # not loaded
	var resolved: String = tr("menu.main.start_mission")
	assert_str(resolved).override_failure_message(
		"tr() with locale='fr' (not loaded) must fall back to en. Got: '%s'" % resolved
	).is_equal("Start Mission")


# ── AC-6: Every CSV row's `# context` cell is non-empty ──────────────────────

## AC-6: Every data row in every CSV has non-empty `# context` cell.
## Whitespace-only does NOT count as filled. Tests parse each CSV and inspect.
func test_every_csv_row_has_nonempty_context() -> void:
	for domain: String in _DOMAINS:
		var path: String = "%s/%s.csv" % [_TRANSLATIONS_DIR, domain]
		var lines: PackedStringArray = _read_all_lines(path)
		for i: int in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				continue  # skip blank trailing lines
			var context_cell: String = _extract_third_cell(line)
			assert_bool(context_cell.strip_edges() != "").override_failure_message(
				"%s.csv line %d must have non-empty # context cell. Line: '%s'" % [domain, i + 1, line]
			).is_true()


# ── AC-7: All keys match 3-segment regex ─────────────────────────────────────

## AC-7: Every key across every CSV matches `domain.context.identifier`.
func test_every_key_matches_three_segment_regex() -> void:
	var key_regex: RegEx = RegEx.new()
	var compile_result: int = key_regex.compile(_KEY_REGEX_PATTERN)
	assert_int(compile_result).override_failure_message(
		"Failed to compile key regex pattern."
	).is_equal(OK)

	var all_keys: Array[String] = []
	var failures: Array[String] = []
	for domain: String in _DOMAINS:
		var path: String = "%s/%s.csv" % [_TRANSLATIONS_DIR, domain]
		var lines: PackedStringArray = _read_all_lines(path)
		for i: int in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				continue
			var key: String = _extract_first_cell(line).strip_edges()
			all_keys.append(key)
			if key_regex.search(key) == null:
				failures.append("%s.csv:%d → '%s'" % [domain, i + 1, key])

	assert_int(all_keys.size()).override_failure_message(
		"Expected at least 1 key across all CSVs."
	).is_greater(0)
	assert_int(failures.size()).override_failure_message(
		"All keys must match 3-segment regex. Failures: %s" % [failures]
	).is_equal(0)


# ── AC-8: Existing overlay.csv keys still resolve ────────────────────────────

## AC-8: overlay.footer.dismiss_hint (Sprint 01) still resolves correctly.
func test_existing_overlay_dismiss_hint_still_resolves() -> void:
	TranslationServer.set_locale("en")
	var resolved: String = tr("overlay.footer.dismiss_hint")
	# Don't pin the exact string (it has em-dash + Unicode glyphs that may break
	# this comment); just verify it resolved (returned something other than the key).
	assert_str(resolved).override_failure_message(
		"tr('overlay.footer.dismiss_hint') must resolve to its English value, not return the key. Got: '%s'" % resolved
	).is_not_equal("overlay.footer.dismiss_hint")
	assert_int(resolved.length()).override_failure_message(
		"Resolved overlay.footer.dismiss_hint must be non-empty. Got length: %d" % resolved.length()
	).is_greater(0)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _read_project_godot() -> String:
	var f: FileAccess = FileAccess.open(_PROJECT_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	return content


func _read_first_line(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var line: String = f.get_line()
	f.close()
	return line


func _read_all_lines(path: String) -> PackedStringArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var content: String = f.get_as_text()
	f.close()
	return content.split("\n")


## Extract the first comma-separated cell, respecting quoted strings.
## Simple CSV parser sufficient for our 3-column files.
func _extract_first_cell(line: String) -> String:
	var i: int = 0
	var in_quote: bool = false
	var out: String = ""
	while i < line.length():
		var c: String = line[i]
		if c == "\"":
			in_quote = not in_quote
		elif c == "," and not in_quote:
			break
		else:
			out += c
		i += 1
	return out


## Extract the third cell (skipping cells 1 + 2). Quote-aware.
func _extract_third_cell(line: String) -> String:
	var commas_seen: int = 0
	var i: int = 0
	var in_quote: bool = false
	var out: String = ""
	while i < line.length():
		var c: String = line[i]
		if c == "\"":
			in_quote = not in_quote
		elif c == "," and not in_quote:
			commas_seen += 1
		elif commas_seen >= 2:
			out += c
		i += 1
	# Strip wrapping quotes if present.
	out = out.strip_edges()
	if out.begins_with("\"") and out.ends_with("\""):
		out = out.substr(1, out.length() - 2)
	return out
