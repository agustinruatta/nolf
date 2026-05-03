# tests/unit/foundation/localization_lint_test.gd
#
# LocalizationLintTest — GdUnit4 suite for Story LOC-005 (Localization Scaffold).
#
# PURPOSE
#   CI-enforced lint guards for the five Localization Scaffold forbidden
#   patterns plus cross-CSV uniqueness + key-naming sanity checks. Runs on
#   every PR; catches regressions cheaply via regex grep + CSV parse.
#
#   Five patterns enforced (per docs/registry/architecture.yaml ADR-0004 fences):
#     • hardcoded_visible_string         — bare Label.text="..." literals
#     • key_in_code_as_english           — tr("Start Mission") English-as-key
#     • positional_format_substitution   — tr(...) % [...] positional %s
#     • context_column_omitted           — CSV rows missing # context
#     • cached_translation_at_ready      — var x = tr() in _ready w/o _notification
#
# /localize AUDIT (heavier, manual/scheduled):
#   The audit at .claude/skills/localize/ provides deeper drift detection
#   (orphan keys, missing translations, key-rename impact). Run before merging
#   large UI / content PRs:
#       /localize audit
#   Lint here is fast (~1 second) and blocks PRs cheaply; audit is thorough
#   (parses every tr() call site + every CSV) and complements lint.
#
# GOVERNING REQUIREMENTS
#   TR-LOC-001..008 (full localization-scaffold tail)
#   ADR-0004 §Risks + §Engine Compatibility (UI Framework forbidden patterns)
#
# GATE STATUS
#   Story LOC-005 | Config/Data type → ADVISORY gate (smoke).
#   Lint failures here ARE blocking on PRs (CI integration); the test type
#   classifies the story not the lint enforcement strength.

class_name LocalizationLintTest
extends GdUnitTestSuite

const _SRC_DIR: String = "res://src"
const _TRANSLATIONS_DIR: String = "res://translations"
const _PSEUDO_CSV: String = "res://translations/_dev_pseudo.csv"
const _ADR_REF: String = "ADR-0004 §Risks + GDD §Detailed Design Rule 9"
## 3-segment minimum: domain.context.identifier; lowercase snake_case dot-separated.
const _KEY_REGEX_PATTERN: String = "^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*(\\.[a-z0-9_]+)*$"


# ── AC-1: hardcoded_visible_string registry entry ─────────────────────────────

func test_hardcoded_visible_string_registered_in_yaml_with_high_severity() -> void:
	_assert_pattern_registered("hardcoded_visible_string", "HIGH")


# ── AC-2: key_in_code_as_english registry entry ───────────────────────────────

func test_key_in_code_as_english_registered_in_yaml_with_medium_severity() -> void:
	_assert_pattern_registered("key_in_code_as_english", "MEDIUM")


# ── AC-3: positional_format_substitution registry entry ───────────────────────

func test_positional_format_substitution_registered_in_yaml_with_medium_severity() -> void:
	_assert_pattern_registered("positional_format_substitution", "MEDIUM")


# ── AC-4: context_column_omitted registry entry ───────────────────────────────

func test_context_column_omitted_registered_in_yaml_with_high_severity() -> void:
	_assert_pattern_registered("context_column_omitted", "HIGH")


# ── AC-5: cached_translation_at_ready registry entry ──────────────────────────

func test_cached_translation_at_ready_registered_in_yaml_with_medium_severity() -> void:
	_assert_pattern_registered("cached_translation_at_ready", "MEDIUM")


# ── AC-6 / Pattern 1: hardcoded_visible_string lint ──────────────────────────

## Lint: detect bare-literal assignments to Label.text / Button.text /
## RichTextLabel.text / .bbcode_text / .dialog_text in src/. Empty-string
## clearing and tr()-wrapped values are allowed.
func test_lint_no_hardcoded_visible_string_in_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []

	# Match: <ident>.{text|bbcode_text|dialog_text} = "..."
	# Reject: empty string ("") and tr-wrapped values are checked separately.
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\.(text|bbcode_text|dialog_text)\\s*=\\s*\"([^\"]*)\"")

	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			var match_result: RegExMatch = pattern.search(line)
			if match_result == null:
				continue
			var assigned_value: String = match_result.get_string(2)
			# Allow empty literal (clearing).
			if assigned_value == "":
				continue
			# Allow tr-wrapped — though regex wouldn't match because tr() is no string literal.
			# Real violation: bare non-empty literal assignment.
			violations.append(
				"%s:%d — %s\n  → %s" % [file_path, i + 1, stripped, _refactor_hint("hardcoded_visible_string")]
			)

	assert_int(violations.size()).override_failure_message(
		_format_lint_failure("hardcoded_visible_string", violations)
	).is_equal(0)


# ── AC-6 / Pattern 2: key_in_code_as_english lint ────────────────────────────

## Lint: detect tr("string") arguments that look like English (contain a space
## or a capital letter) — keys must be lowercase snake_case dot-notation.
func test_lint_no_key_in_code_as_english_in_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	# Match: tr("...") and capture the inner string literal (named StringName & or "...").
	var pattern: RegEx = RegEx.new()
	pattern.compile("tr\\(\\s*\"([^\"]+)\"")

	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			var matches: Array[RegExMatch] = pattern.search_all(line)
			for m: RegExMatch in matches:
				var key_arg: String = m.get_string(1)
				if _looks_like_english(key_arg):
					violations.append(
						"%s:%d — tr(\"%s\")\n  → %s" % [file_path, i + 1, key_arg, _refactor_hint("key_in_code_as_english")]
					)

	assert_int(violations.size()).override_failure_message(
		_format_lint_failure("key_in_code_as_english", violations)
	).is_equal(0)


# ── AC-6 / Pattern 3: positional_format_substitution lint ────────────────────

## Lint: detect tr(...) %  [...] positional substitution. Per TR-LOC-004,
## parameterized strings must use named placeholders + String.format().
func test_lint_no_positional_format_substitution_in_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	var pattern: RegEx = RegEx.new()
	pattern.compile("tr\\([^)]+\\)\\s*%\\s*\\[")

	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if pattern.search(line) != null:
				violations.append(
					"%s:%d — %s\n  → %s" % [file_path, i + 1, stripped, _refactor_hint("positional_format_substitution")]
				)

	assert_int(violations.size()).override_failure_message(
		_format_lint_failure("positional_format_substitution", violations)
	).is_equal(0)


# ── AC-6 / Pattern 4: context_column_omitted lint ────────────────────────────

## Lint: every production CSV row has non-empty # context cell. Skips
## _dev_pseudo.csv (different schema), Godot 4.6 plural ?-prefixed directive
## rows, and row-repetition continuation rows (empty key).
func test_lint_no_context_column_omitted_in_production_csvs() -> void:
	var csv_files: Array[String] = _list_production_csvs()
	var violations: Array[String] = []

	for csv_path: String in csv_files:
		var content: String = _read_file(csv_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		if lines.size() == 0:
			continue
		var header_cells: Array[String] = _split_csv_cells(lines[0])
		var context_idx: int = -1
		for ci: int in range(header_cells.size()):
			if header_cells[ci].strip_edges() == "# context":
				context_idx = ci
				break
		if context_idx < 0:
			violations.append("%s — header missing '# context' column" % csv_path)
			continue
		for i: int in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				continue
			var cells: Array[String] = _split_csv_cells(line)
			# Skip Godot 4.6 plural meta rows.
			var first: String = cells[0].strip_edges() if cells.size() > 0 else ""
			if first == "" or first.begins_with("?"):
				continue
			var ctx: String = cells[context_idx] if context_idx < cells.size() else ""
			if ctx.strip_edges() == "":
				violations.append(
					"%s:%d — key '%s' has empty # context\n  → %s"
					% [csv_path, i + 1, first, _refactor_hint("context_column_omitted")]
				)

	assert_int(violations.size()).override_failure_message(
		_format_lint_failure("context_column_omitted", violations)
	).is_equal(0)


# ── AC-6 / Pattern 5: cached_translation_at_ready lint ───────────────────────

## Lint: detect `var <name> [:=] tr(...)` inside _ready() function bodies
## when the same script does NOT contain NOTIFICATION_TRANSLATION_CHANGED.
func test_lint_no_cached_translation_at_ready_in_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	var var_tr_pattern: RegEx = RegEx.new()
	var_tr_pattern.compile("var\\s+\\w+(\\s*:\\s*\\w+)?\\s*=\\s*tr\\(")

	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		# If the script defines a NOTIFICATION_TRANSLATION_CHANGED handler,
		# caching is acceptable (the handler will refresh on locale switch).
		if content.contains("NOTIFICATION_TRANSLATION_CHANGED"):
			continue
		var lines: PackedStringArray = content.split("\n")
		var in_ready: bool = false
		var ready_indent: int = -1
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.begins_with("func _ready"):
				in_ready = true
				ready_indent = _leading_indent(line)
				continue
			if in_ready and stripped.begins_with("func ") and _leading_indent(line) <= ready_indent:
				in_ready = false
			if in_ready and var_tr_pattern.search(line) != null:
				violations.append(
					"%s:%d — %s\n  → %s" % [file_path, i + 1, stripped, _refactor_hint("cached_translation_at_ready")]
				)

	assert_int(violations.size()).override_failure_message(
		_format_lint_failure("cached_translation_at_ready", violations)
	).is_equal(0)


# ── AC-7: Cross-domain key uniqueness ────────────────────────────────────────

## Lint: every key across all production CSVs must be unique. Catches
## accidental duplication during cross-domain refactors.
func test_lint_no_cross_domain_key_collisions_in_production_csvs() -> void:
	var keys_seen: Dictionary = {}
	var collisions: Array[String] = []
	for csv_path: String in _list_production_csvs():
		var content: String = _read_file(csv_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				continue
			var cells: Array[String] = _split_csv_cells(line)
			var key: String = cells[0].strip_edges() if cells.size() > 0 else ""
			# Skip Godot 4.6 plural meta rows.
			if key == "" or key.begins_with("?"):
				continue
			if keys_seen.has(key):
				collisions.append("'%s' in %s and %s" % [key, keys_seen[key], csv_path])
			else:
				keys_seen[key] = csv_path

	assert_int(collisions.size()).override_failure_message(
		"Cross-domain key collisions detected (each key must appear in only ONE CSV):\n  %s" % "\n  ".join(collisions)
	).is_equal(0)


# ── AC-8: All keys match 3-segment regex ─────────────────────────────────────

## Lint: every production-CSV key matches domain.context.identifier dot-notation.
func test_lint_all_production_keys_match_3_segment_regex() -> void:
	var key_regex: RegEx = RegEx.new()
	key_regex.compile(_KEY_REGEX_PATTERN)
	var failures: Array[String] = []
	for csv_path: String in _list_production_csvs():
		var content: String = _read_file(csv_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				continue
			var cells: Array[String] = _split_csv_cells(line)
			var key: String = cells[0].strip_edges() if cells.size() > 0 else ""
			if key == "" or key.begins_with("?"):
				continue
			if key_regex.search(key) == null:
				failures.append("%s:%d — '%s' does not match domain.context.identifier" % [csv_path, i + 1, key])

	assert_int(failures.size()).override_failure_message(
		"Keys must match 3-segment regex %s. Violations:\n  %s" % [_KEY_REGEX_PATTERN, "\n  ".join(failures)]
	).is_equal(0)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _read_file(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


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


func _list_production_csvs() -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(_TRANSLATIONS_DIR)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		if entry.ends_with(".csv") and not entry.begins_with("_dev_pseudo"):
			results.append(_TRANSLATIONS_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return results


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


func _leading_indent(line: String) -> int:
	var n: int = 0
	for c: String in line:
		if c == "\t" or c == " ":
			n += 1
		else:
			break
	return n


## Heuristic: a key arg "looks like English" if it contains a space or a
## capital ASCII letter. Production keys are lowercase snake_case dot-separated.
func _looks_like_english(key_arg: String) -> bool:
	if key_arg.contains(" "):
		return true
	for c: String in key_arg:
		if c >= "A" and c <= "Z":
			return true
	return false


## Verify a forbidden_pattern entry exists in docs/registry/architecture.yaml
## with the given pattern_name and severity. AC-1..AC-5.
func _assert_pattern_registered(pattern_name: String, expected_severity: String) -> void:
	var registry_path: String = "res://docs/registry/architecture.yaml"
	var content: String = _read_file(registry_path)
	assert_str(content).override_failure_message(
		"docs/registry/architecture.yaml must exist and be readable."
	).is_not_empty()

	# Find the line "  - pattern: <name>".
	var pattern_marker: String = "- pattern: %s" % pattern_name
	var marker_idx: int = content.find(pattern_marker)
	assert_int(marker_idx).override_failure_message(
		"docs/registry/architecture.yaml must contain a forbidden_patterns entry for '%s'." % pattern_name
	).is_greater(-1)

	# Read the next ~10 lines after the marker to find the `severity:` field.
	var after: String = content.substr(marker_idx, 800)
	var severity_marker: String = "severity: %s" % expected_severity
	assert_bool(after.contains(severity_marker)).override_failure_message(
		(
			"forbidden_patterns entry '%s' must declare 'severity: %s' "
			+ "within its block. Block excerpt: %s"
		) % [pattern_name, expected_severity, after.substr(0, 400)]
	).is_true()


## Standardised refactor hint per pattern. AC-9 surface.
func _refactor_hint(pattern_name: String) -> String:
	match pattern_name:
		"hardcoded_visible_string":
			return "Replace bare literal with tr(\"<domain>.<context>.<identifier>\"); add the key to the appropriate translations/*.csv with English value + non-empty # context."
		"key_in_code_as_english":
			return "Replace English string with a dot-notation key (e.g. tr(\"menu.main.start_mission\") not tr(\"Start Mission\")). Add the canonical English value to translations/*.csv."
		"positional_format_substitution":
			return "Replace `tr(...) % [v]` with `tr(...).format({\"name\": v})`. Use named placeholders so each translator can place the variable per their language's grammar."
		"context_column_omitted":
			return "Add a non-empty # context cell describing tone, max length, register, and any placeholder variables."
		"cached_translation_at_ready":
			return "Either (a) use auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS on the Control and assign the tr() KEY to .text (Pattern A), or (b) override _notification(NOTIFICATION_TRANSLATION_CHANGED) and re-resolve the cached value (Pattern B). See src/core/ui/translatable_composed_label.gd."
		_:
			return "See ADR-0004 §Risks + GDD Localization Scaffold Rule 9."


## Standardised lint failure message format. AC-9 surface.
func _format_lint_failure(pattern_name: String, violations: Array[String]) -> String:
	if violations.size() == 0:
		return ""
	return (
		"FORBIDDEN PATTERN '%s' detected (%d instance%s). See %s.\n%s"
		% [
			pattern_name,
			violations.size(),
			"" if violations.size() == 1 else "s",
			_ADR_REF,
			"\n".join(violations),
		]
	)
