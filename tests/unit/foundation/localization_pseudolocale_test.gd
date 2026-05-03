# tests/unit/foundation/localization_pseudolocale_test.gd
#
# LocalizationPseudolocaleTest — GdUnit4 suite for Story LOC-002.
#
# PURPOSE
#   Verifies the pseudolocalization scaffold:
#     • _dev_pseudo.csv exists with header `keys,en,pseudo,# context`
#     • Every production-CSV key has a corresponding pseudo entry
#     • Pseudo strings follow structural rules: bracket-wrapped, ~140% length,
#       all-caps, recognizable English substring inside the brackets
#     • TranslationServer.set_locale("pseudo") activates pseudolocalization
#     • get_loaded_locales() includes "pseudo" in editor/debug builds
#
# AC-5 NOTE (export filter)
#   Export-preset filter verification cannot be automated headlessly without
#   running the export pipeline. Documented as ADVISORY in
#   `production/qa/evidence/localization_export_filter_evidence.md` (manual
#   verification on first export pass). Not a blocking gate for this story.
#
# GATE STATUS
#   Story LOC-002 | Logic type → BLOCKING gate (AC-1..4, 6, 7). TR-LOC-010.

class_name LocalizationPseudolocaleTest
extends GdUnitTestSuite

const _PSEUDO_CSV: String = "res://translations/_dev_pseudo.csv"
const _TRANSLATIONS_DIR: String = "res://translations"
const _PRODUCTION_DOMAINS: Array[String] = [
	"overlay", "hud", "menu", "settings", "meta",
	"dialogue", "cutscenes", "mission", "credits", "doc"
]
const _PSEUDO_LOCALE: String = "pseudo"

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_saved_locale)


# ── AC-1: _dev_pseudo.csv exists with valid header ───────────────────────────

func test_pseudo_csv_exists() -> void:
	assert_bool(FileAccess.file_exists(_PSEUDO_CSV)).override_failure_message(
		"_dev_pseudo.csv must exist at %s." % _PSEUDO_CSV
	).is_true()


func test_pseudo_csv_header_is_valid() -> void:
	var f: FileAccess = FileAccess.open(_PSEUDO_CSV, FileAccess.READ)
	assert_object(f).is_not_null()
	var first_line: String = f.get_line()
	f.close()
	assert_str(first_line).override_failure_message(
		"_dev_pseudo.csv first line must be 'keys,en,pseudo,# context'. Got: '%s'" % first_line
	).is_equal("keys,en,pseudo,# context")


# ── AC-2: Every production key has a pseudo entry ────────────────────────────

func test_every_production_key_has_pseudo_entry() -> void:
	var production_keys: Array[String] = _collect_keys_from_csvs(_PRODUCTION_DOMAINS)
	var pseudo_keys: Array[String] = _collect_keys_from_pseudo_csv()

	var missing: Array[String] = []
	for key: String in production_keys:
		if not pseudo_keys.has(key):
			missing.append(key)

	assert_int(missing.size()).override_failure_message(
		"Every production key must have a _dev_pseudo.csv row. Missing: %s" % [missing]
	).is_equal(0)
	assert_int(pseudo_keys.size()).override_failure_message(
		"_dev_pseudo.csv must contain at least one row."
	).is_greater(0)


# ── AC-3: Pseudo strings match structural rules ──────────────────────────────

## AC-3: Each pseudo cell starts with `[`, ends with `]`, and is uppercase
## (in the body). Length factor is checked permissively (≥ 1.0× to ≤ 2.0×) —
## short strings (1–4 chars) get bracket overhead that pushes them above 1.4×.
func test_pseudo_strings_have_brackets_and_uppercase() -> void:
	var rows: Array = _read_pseudo_rows()
	var failures: Array[String] = []

	for row: Dictionary in rows:
		var key: String = row["key"]
		var en: String = row["en"]
		var pseudo: String = row["pseudo"]

		if not pseudo.begins_with("["):
			failures.append("'%s' pseudo must start with '['. Got: '%s'" % [key, pseudo])
			continue
		if not pseudo.ends_with("]"):
			failures.append("'%s' pseudo must end with ']'. Got: '%s'" % [key, pseudo])
			continue
		# Body uppercase check: extract the part between brackets and verify
		# no lowercase ASCII letters appear (apostrophes, digits, punctuation OK).
		var body: String = pseudo.substr(1, pseudo.length() - 2)
		var has_lower: bool = false
		for ch: String in body:
			if ch >= "a" and ch <= "z":
				has_lower = true
				break
		if has_lower:
			failures.append("'%s' pseudo body must be all-caps. Got: '%s'" % [key, pseudo])

	assert_int(failures.size()).override_failure_message(
		"Pseudo string structural rules violations:\n  %s" % "\n  ".join(failures)
	).is_equal(0)


## AC-3: Pseudo length is at least 1.2× the English source (rejects no-op
## pseudo entries that just bracket-wrap without padding) and at most 5.0×
## (catches catastrophically over-padded entries). Bracket overhead `[• ... •]`
## is 6 fixed characters which inflates the factor on short strings; the upper
## bound is intentionally permissive. The GDD's own example
## `[• ENGLISH PADDED ENGLISH ÉNGLÏSH •]` for `ENGLISH` (7 chars) is ~5.1×, so
## treating 5.0 as the cap matches the spec's authoring intent.
func test_pseudo_length_factor_within_safe_range() -> void:
	var rows: Array = _read_pseudo_rows()
	var failures: Array[String] = []

	for row: Dictionary in rows:
		var key: String = row["key"]
		var en: String = row["en"]
		var pseudo: String = row["pseudo"]

		# Strings under 4 chars exempt from upper bound — `[• X X X •]` framing
		# dominates the byte count. Lower bound still applies (catches no-op).
		if en.length() < 4:
			var min_pseudo: int = en.length() + 6  # at least the bracket framing
			if pseudo.length() < min_pseudo:
				failures.append("'%s' (short) pseudo must include bracket framing — length < %d. Got: %d"
					% [key, min_pseudo, pseudo.length()])
			continue

		var factor: float = float(pseudo.length()) / float(en.length())
		if factor < 1.2 or factor > 5.0:
			failures.append("'%s' length factor %.2f outside [1.2, 5.0]. en=%d, pseudo=%d. en='%s', pseudo='%s'"
				% [key, factor, en.length(), pseudo.length(), en, pseudo])

	assert_int(failures.size()).override_failure_message(
		"Pseudo length factor outside the [1.2, 5.0] safe range:\n  %s"
		% "\n  ".join(failures)
	).is_equal(0)


## AC-3: Pseudo body contains the original English (uppercased) as a recognizable
## substring. Verifies reversibility — a developer can read past the bracketing
## to see what English string was being padded.
func test_pseudo_contains_uppercase_english_source() -> void:
	var rows: Array = _read_pseudo_rows()
	var failures: Array[String] = []

	for row: Dictionary in rows:
		var key: String = row["key"]
		var en: String = row["en"]
		var pseudo: String = row["pseudo"]

		var en_upper: String = en.to_upper()
		if not pseudo.contains(en_upper):
			failures.append("'%s' pseudo must contain uppercased en '%s' as a substring. en='%s', pseudo='%s'"
				% [key, en_upper, en, pseudo])

	assert_int(failures.size()).override_failure_message(
		"Pseudo strings must contain the uppercased English source for reversibility:\n  %s"
		% "\n  ".join(failures)
	).is_equal(0)


# ── AC-4 + AC-6: Pseudolocale activates at runtime ───────────────────────────

func test_pseudo_locale_is_loaded_in_editor_or_debug() -> void:
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	var has_pseudo: bool = false
	for loc: String in locales:
		if loc == _PSEUDO_LOCALE:
			has_pseudo = true
			break
	assert_bool(has_pseudo).override_failure_message(
		"TranslationServer.get_loaded_locales() must contain '%s' in editor/debug. Got: %s"
			% [_PSEUDO_LOCALE, locales]
	).is_true()


func test_set_locale_pseudo_activates_pseudo_translation() -> void:
	TranslationServer.set_locale(_PSEUDO_LOCALE)
	var resolved: String = tr("menu.main.start_mission")
	assert_str(resolved).override_failure_message(
		"With locale=pseudo, tr('menu.main.start_mission') must return the pseudo string, not 'Start Mission'. Got: '%s'" % resolved
	).is_not_equal("Start Mission")
	assert_bool(resolved.begins_with("[")).override_failure_message(
		"Pseudo-translated string must start with '['. Got: '%s'" % resolved
	).is_true()
	assert_bool(resolved.ends_with("]")).override_failure_message(
		"Pseudo-translated string must end with ']'. Got: '%s'" % resolved
	).is_true()


# ── AC-7: Smoke test on a known key ──────────────────────────────────────────

func test_pseudo_smoke_for_start_mission() -> void:
	TranslationServer.set_locale(_PSEUDO_LOCALE)
	var resolved: String = tr("menu.main.start_mission")
	# Source is "Start Mission" (13 chars).
	assert_int(resolved.length()).override_failure_message(
		"Pseudo for 'Start Mission' (13 chars) must be ≥ 1.2 × 13 = 15.6 chars. Got: %d" % resolved.length()
	).is_greater_equal(16)
	assert_bool(resolved.contains("START MISSION")).override_failure_message(
		"Pseudo body must contain uppercased English 'START MISSION'. Got: '%s'" % resolved
	).is_true()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _collect_keys_from_csvs(domains: Array[String]) -> Array[String]:
	var keys: Array[String] = []
	for domain: String in domains:
		var path: String = "%s/%s.csv" % [_TRANSLATIONS_DIR, domain]
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var content: String = f.get_as_text()
		f.close()
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(1, lines.size()):
			var line: String = lines[i]
			if line.strip_edges() == "":
				continue
			var key: String = _extract_first_cell(line).strip_edges()
			# Skip Godot 4.6 plural-format meta rows (?pluralrule directive +
			# row-repetition continuation rows). Pseudo only mirrors real keys.
			if key == "" or key.begins_with("?"):
				continue
			keys.append(key)
	return keys


func _collect_keys_from_pseudo_csv() -> Array[String]:
	var f: FileAccess = FileAccess.open(_PSEUDO_CSV, FileAccess.READ)
	if f == null:
		return []
	var content: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = content.split("\n")
	var keys: Array[String] = []
	for i: int in range(1, lines.size()):
		var line: String = lines[i]
		if line.strip_edges() == "":
			continue
		var key: String = _extract_first_cell(line).strip_edges()
		if key != "":
			keys.append(key)
	return keys


func _read_pseudo_rows() -> Array:
	var f: FileAccess = FileAccess.open(_PSEUDO_CSV, FileAccess.READ)
	if f == null:
		return []
	var content: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = content.split("\n")
	var rows: Array = []
	for i: int in range(1, lines.size()):
		var line: String = lines[i]
		if line.strip_edges() == "":
			continue
		var cells: Array[String] = _split_csv_line(line)
		if cells.size() < 4:
			continue
		rows.append({"key": cells[0], "en": cells[1], "pseudo": cells[2], "context": cells[3]})
	return rows


## Split a CSV line into its 4 cells, respecting double-quoted fields.
func _split_csv_line(line: String) -> Array[String]:
	var out: Array[String] = []
	var current: String = ""
	var in_quote: bool = false
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if c == "\"":
			in_quote = not in_quote
		elif c == "," and not in_quote:
			out.append(_strip_quotes(current))
			current = ""
		else:
			current += c
		i += 1
	out.append(_strip_quotes(current))
	return out


func _strip_quotes(s: String) -> String:
	var t: String = s.strip_edges()
	if t.begins_with("\"") and t.ends_with("\""):
		t = t.substr(1, t.length() - 2)
	return t


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
