# tests/unit/foundation/events_purity_test.gd
#
# Structural purity test — events.gd source file.
#
# PURPOSE
#   Proves that src/core/signal_bus/events.gd contains ONLY signal declarations
#   (plus its class_name / extends header and comment lines).  This is a CI
#   regression fence: if anyone accidentally adds a func, var, or const to the
#   signal bus, this test fails loudly before the PR merges.
#
# WHAT IS TESTED
#   AC-2: Zero func / var / const declarations in events.gd (excluding header).
#   AC-3: The verification-only smoke_test_pulse signal has been removed.
#
# WHAT IS NOT TESTED HERE
#   - Whether the autoload is registered (see events_autoload_registration_test.gd).
#   - Whether signals can be emitted (see signal_bus_smoke_test.gd).
#
# GATE STATUS
#   Story SB-001 — Logic type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name EventsPurityTest
extends GdUnitTestSuite


const _EVENTS_PATH: String = "res://src/core/signal_bus/events.gd"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns all non-comment, non-blank lines from events.gd.
## Comment lines are those whose first non-whitespace character is '#'.
## The class_name and extends lines are header lines and are excluded.
func _get_non_header_code_lines() -> Array[String]:
	var file: FileAccess = FileAccess.open(_EVENTS_PATH, FileAccess.READ)
	assert_object(file).is_not_null()

	var raw_text: String = file.get_as_text()
	file.close()

	var all_lines: PackedStringArray = raw_text.split("\n")
	var code_lines: Array[String] = []

	for raw_line: String in all_lines:
		var stripped: String = raw_line.strip_edges()
		# Skip blank lines
		if stripped.is_empty():
			continue
		# Skip comment-only lines
		if stripped.begins_with("#"):
			continue
		# Skip header lines (class_name and extends declarations)
		if stripped.begins_with("class_name ") or stripped.begins_with("extends "):
			continue
		code_lines.append(raw_line)

	return code_lines


## Counts lines that match a regex pattern applied to the raw (non-stripped)
## line, to correctly handle indentation-based matches.
func _count_matching_lines(lines: Array[String], pattern: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	var count: int = 0
	for line: String in lines:
		if regex.search(line) != null:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Tests — AC-2: Structural purity (no func / var / const)
# ---------------------------------------------------------------------------

## events.gd must contain zero func declarations outside comment lines.
## Pattern catches plain `func` AND `static func` to close the regression fence
## per code-review GAP-1 (qa-tester, 2026-04-30).
## Covers ADR-0002 forbidden pattern: events_with_state_or_methods.
func test_events_gd_has_zero_func_declarations() -> void:
	# Arrange
	var code_lines: Array[String] = _get_non_header_code_lines()

	# Act
	# Match lines beginning with optional whitespace, optional `static ` prefix,
	# then 'func ' keyword.
	var match_count: int = _count_matching_lines(code_lines, "^\\s*(static\\s+)?func\\s")

	# Assert
	assert_int(match_count).is_equal(0)


## events.gd must contain zero var declarations outside comment lines.
## Pattern catches plain `var` AND decorated `@onready var` / `@export var` to
## close the regression fence per code-review GAP-1 (qa-tester, 2026-04-30).
## Covers ADR-0002 forbidden pattern: events_with_state_or_methods.
func test_events_gd_has_zero_var_declarations() -> void:
	# Arrange
	var code_lines: Array[String] = _get_non_header_code_lines()

	# Act
	# Match lines beginning with optional whitespace, any number of `@decorator`
	# annotations, then 'var ' keyword.
	var match_count: int = _count_matching_lines(code_lines, "^\\s*(@\\w+\\s+)*var\\s")

	# Assert
	assert_int(match_count).is_equal(0)


## events.gd must contain zero const declarations outside comment lines.
## Covers ADR-0002 forbidden pattern: events_with_state_or_methods.
func test_events_gd_has_zero_const_declarations() -> void:
	# Arrange
	var code_lines: Array[String] = _get_non_header_code_lines()

	# Act
	var match_count: int = _count_matching_lines(code_lines, "^\\s*const\\s")

	# Assert
	assert_int(match_count).is_equal(0)


# ---------------------------------------------------------------------------
# Tests — AC-3: Smoke-test-pulse cleanup
# ---------------------------------------------------------------------------

## The verification-only smoke_test_pulse signal must not appear in events.gd.
## Covers SB-001 AC-3: skeleton verification signal removed from production file.
func test_events_gd_smoke_test_pulse_signal_removed() -> void:
	# Arrange
	var file: FileAccess = FileAccess.open(_EVENTS_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var full_text: String = file.get_as_text()
	file.close()

	# Act — search the entire file text for the signal declaration substring.
	# A leftover comment mentioning smoke_test_pulse is acceptable;
	# only the actual 'signal smoke_test_pulse' declaration is forbidden.
	var regex: RegEx = RegEx.new()
	regex.compile("^\\s*signal\\s+smoke_test_pulse")
	var all_lines: PackedStringArray = full_text.split("\n")
	var declaration_count: int = 0
	for line: String in all_lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if regex.search(line) != null:
			declaration_count += 1

	# Assert
	assert_int(declaration_count).is_equal(0)
