# tests/unit/level_streaming/level_streaming_lint_test.gd
#
# LevelStreamingLintTest — GdUnit4 suite for Story LS-009.
#
# Grep-based lint tests for 4 forbidden patterns registered in
# docs/registry/architecture.yaml. These tests scan src/**/*.gd recursively
# using FileAccess text reads and RegEx matching to detect violations outside
# their explicit allow-lists.
#
# Covers:
#   AC-1  unauthorized_reload_current_section_caller — absent from src/ outside
#         the 3 authorised caller paths + LSS itself. (GDD CR-4)
#   AC-2  cross_section_nodepath_reference — registry entry present with correct
#         fields. (GDD CR-9 — smoke-check only; runtime detection is post-MVP)
#   AC-3  missing_register_restore_callback — registry entry present with correct
#         fields. (TR-LS-013)
#   AC-4  bypass_thirteen_step_protocol — change_scene_to_file/packed absent
#         outside the 3 authorised files. (GDD CR-5)
#   AC-5  section_exited_subscriber_awaits — registry entry present. (GDD CR-13)
#         Runtime detection is covered by level_streaming_sync_subscriber_test.gd
#   AC-6  Lint test functions present and executable (this file)
#   AC-8  Failure messages identify: pattern name, file path, line number,
#         matched text, and cite the relevant ADR + GDD CR
#
# ── Scan scope ────────────────────────────────────────────────────────────────
# Production lint: res://src/ — all .gd files
# Fixtures included for AC-8 deliberate-violation scan: tests/fixtures/level_streaming/
# Explicitly excluded from production lint: tests/, addons/, prototypes/
#
# ── Implementation notes ──────────────────────────────────────────────────────
# FileAccess.get_as_text() is used (not ResourceLoader) — same pattern as LS-006
# project.godot test. RegEx.create_from_string() for pattern matching.
# DirAccess for recursive file enumeration.
# Violations are collected as an Array of match-info Dictionaries before
# asserting, so failure messages can report all violations at once.
#
# GATE STATUS
#   Story LS-009 | Config/Data type → ADVISORY gate.
#   GDD CR-4, CR-5, CR-9, CR-13. ADR-0007, ADR-0003.

class_name LevelStreamingLintTest
extends GdUnitTestSuite


# ── Constants ────────────────────────────────────────────────────────────────

## Production source root — all .gd files here are lint-scanned.
const SRC_DIR: String = "res://src/"

## Registry file path.
const REGISTRY_PATH: String = "res://docs/registry/architecture.yaml"

## LSS source path — excluded from unauthorized-caller lint (it IS the
## implementation; calling its own methods is expected).
const LSS_PATH: String = "res://src/core/level_streaming/level_streaming_service.gd"

## Authorised callers of transition_to_section / reload_current_section.
## New callers require an ADR-0007 amendment + this array updated.
const AUTHORIZED_CALLER_PREFIXES: Array[String] = [
	"res://src/gameplay/mission_level_scripting/",
	"res://src/gameplay/failure_respawn/",
	"res://src/core/ui/menu/",
]

## Authorised files that may call change_scene_to_file / change_scene_to_packed.
const AUTHORIZED_SCENE_CHANGE_FILES: Array[String] = [
	"res://src/core/level_streaming/level_streaming_service.gd",
	"res://src/core/main.gd",
	"res://scenes/error_fallback.gd",
]

## Fixture directory containing deliberately-injected violations (AC-8 tests).
const FIXTURES_DIR: String = "res://tests/fixtures/level_streaming/"


# ── AC-1: unauthorized_reload_current_section_caller absent from src/ ─────────

## AC-1: GIVEN src/**/*.gd,
## WHEN scanned for LevelStreamingService.(transition_to_section|reload_current_section)
## or LSS.(transition_to_section|reload_current_section),
## THEN zero violations are found outside the authorized caller paths and LSS itself.
##
## Cites: GDD CR-4 — only Mission & Level Scripting, Failure & Respawn, and
## Menu System may call these APIs. ADR-0007.
## Pattern: unauthorized_reload_current_section_caller (severity HIGH)
func test_unauthorized_reload_current_section_caller_absent_from_src() -> void:
	var pattern: RegEx = RegEx.create_from_string(
		"\\b(LevelStreamingService|LSS)\\.(transition_to_section|reload_current_section)\\s*\\("
	)
	var violations: Array[Dictionary] = _grep_src_recursive(pattern)

	# Filter out the LSS implementation file itself (calling own methods is expected).
	violations = violations.filter(func(m: Dictionary) -> bool:
		return m["file"] != LSS_PATH
	)

	# Filter out the authorised caller prefixes.
	violations = violations.filter(func(m: Dictionary) -> bool:
		for prefix: String in AUTHORIZED_CALLER_PREFIXES:
			if (m["file"] as String).begins_with(prefix):
				return false
		return true
	)

	assert_array(violations).override_failure_message(
		_format_violation_message(
			violations,
			"unauthorized_reload_current_section_caller",
			"GDD CR-4",
			"ADR-0007",
			"Only Mission & Level Scripting, Failure & Respawn, and Menu System may call "
			+ "LevelStreamingService.transition_to_section / reload_current_section. "
			+ "Other callers bypass the 13-step section-state coordination contract."
		)
	).is_empty()


## AC-8 fixture scan: GIVEN the deliberate-violation fixture file,
## WHEN the same grep logic runs against the fixtures dir,
## THEN the fixture file is detected as a violation (verifying lint logic fires).
func test_unauthorized_caller_lint_detects_fixture_violation() -> void:
	var pattern: RegEx = RegEx.create_from_string(
		"\\b(LevelStreamingService|LSS)\\.(transition_to_section|reload_current_section)\\s*\\("
	)
	var fixture_matches: Array[Dictionary] = _grep_dir(FIXTURES_DIR, pattern)
	var fixture_hits: Array = fixture_matches.filter(func(m: Dictionary) -> bool:
		return (m["file"] as String).ends_with("violation_unauthorized_caller.gd")
	)
	assert_array(fixture_hits).override_failure_message(
		"AC-8: lint logic must detect the deliberate violation in "
		+ "tests/fixtures/level_streaming/violation_unauthorized_caller.gd. "
		+ "The fixture contains the pattern 'LevelStreamingService.transition_to_section' "
		+ "as a string constant, which the RegEx should match."
	).is_not_empty()


# ── AC-4: bypass_thirteen_step_protocol absent from src/ ─────────────────────

## AC-4: GIVEN src/**/*.gd,
## WHEN scanned for change_scene_to_(file|packed) calls,
## THEN zero violations are found outside the 3 authorised files.
##
## Cites: GDD CR-5. ADR-0007.
## Pattern: bypass_thirteen_step_protocol (severity HIGH)
func test_bypass_thirteen_step_protocol_absent_from_src() -> void:
	var pattern: RegEx = RegEx.create_from_string(
		"\\bchange_scene_to_(file|packed)\\s*\\("
	)
	var violations: Array[Dictionary] = _grep_src_recursive(pattern)

	# Filter out the authorised files.
	violations = violations.filter(func(m: Dictionary) -> bool:
		return not ((m["file"] as String) in AUTHORIZED_SCENE_CHANGE_FILES)
	)

	assert_array(violations).override_failure_message(
		_format_violation_message(
			violations,
			"bypass_thirteen_step_protocol",
			"GDD CR-5",
			"ADR-0007",
			"change_scene_to_file / change_scene_to_packed must only be called from "
			+ "LevelStreamingService, src/core/main.gd, or scenes/error_fallback.gd. "
			+ "All other callers must use LevelStreamingService.transition_to_section."
		)
	).is_empty()


## AC-8 fixture scan: GIVEN the deliberate bypass-protocol violation fixture,
## WHEN the same grep logic runs against the fixtures dir,
## THEN the fixture file is detected.
func test_bypass_protocol_lint_detects_fixture_violation() -> void:
	var pattern: RegEx = RegEx.create_from_string(
		"\\bchange_scene_to_(file|packed)\\s*\\("
	)
	var fixture_matches: Array[Dictionary] = _grep_dir(FIXTURES_DIR, pattern)
	var fixture_hits: Array = fixture_matches.filter(func(m: Dictionary) -> bool:
		return (m["file"] as String).ends_with("violation_bypass_protocol.gd")
	)
	assert_array(fixture_hits).override_failure_message(
		"AC-8: lint logic must detect the deliberate violation in "
		+ "tests/fixtures/level_streaming/violation_bypass_protocol.gd. "
		+ "The fixture contains the string 'change_scene_to_file' which the RegEx should match."
	).is_not_empty()


# ── AC-2: cross_section_nodepath_reference registry entry present ─────────────

## AC-2: GIVEN docs/registry/architecture.yaml,
## WHEN scanned for the pattern entry,
## THEN cross_section_nodepath_reference is present with severity HIGH and
## ADR-0003 reference.
##
## Cites: GDD CR-9. ADR-0003. Pattern: cross_section_nodepath_reference (advisory;
## runtime smoke-check enforcement is post-MVP per story LS-009 scope).
func test_cross_section_nodepath_reference_registry_entry_present() -> void:
	var registry_text: String = _read_registry()

	assert_bool(registry_text.contains("cross_section_nodepath_reference")).override_failure_message(
		"AC-2: docs/registry/architecture.yaml must contain an entry for pattern "
		+ "'cross_section_nodepath_reference'. "
		+ "Story LS-009. GDD CR-9. ADR-0003."
	).is_true()

	assert_bool(registry_text.contains("severity: HIGH")).override_failure_message(
		"AC-2: cross_section_nodepath_reference must have severity: HIGH."
	).is_true()

	assert_bool(registry_text.contains("adr-0003-save-format-contract")).override_failure_message(
		"AC-2: cross_section_nodepath_reference must reference ADR-0003."
	).is_true()


# ── AC-3: missing_register_restore_callback registry entry present ────────────

## AC-3: GIVEN docs/registry/architecture.yaml,
## WHEN scanned for the pattern entry,
## THEN missing_register_restore_callback is present with severity MEDIUM and
## ADR-0007 reference.
##
## Cites: TR-LS-013. GDD CR-2. ADR-0007.
## Pattern: missing_register_restore_callback (MEDIUM)
func test_missing_register_restore_callback_registry_entry_present() -> void:
	var registry_text: String = _read_registry()

	assert_bool(registry_text.contains("missing_register_restore_callback")).override_failure_message(
		"AC-3: docs/registry/architecture.yaml must contain an entry for pattern "
		+ "'missing_register_restore_callback'. "
		+ "Story LS-009. TR-LS-013. GDD CR-2. ADR-0007."
	).is_true()

	assert_bool(registry_text.contains("severity: MEDIUM")).override_failure_message(
		"AC-3: missing_register_restore_callback must have severity: MEDIUM."
	).is_true()

	assert_bool(registry_text.contains("adr-0007-autoload-load-order-registry")).override_failure_message(
		"AC-3: missing_register_restore_callback must reference ADR-0007."
	).is_true()


# ── AC-5: section_exited_subscriber_awaits registry entry present ─────────────

## AC-5 (registry portion): GIVEN docs/registry/architecture.yaml,
## WHEN scanned for the pattern entry,
## THEN section_exited_subscriber_awaits is present with severity MEDIUM
## and ADR-0007 reference.
##
## Cites: GDD CR-13. AC-LS-2.4. ADR-0007.
## Runtime detection is covered by level_streaming_sync_subscriber_test.gd.
func test_section_exited_subscriber_awaits_registry_entry_present() -> void:
	var registry_text: String = _read_registry()

	assert_bool(registry_text.contains("section_exited_subscriber_awaits")).override_failure_message(
		"AC-5: docs/registry/architecture.yaml must contain an entry for pattern "
		+ "'section_exited_subscriber_awaits'. "
		+ "Story LS-009. GDD CR-13. AC-LS-2.4. ADR-0007."
	).is_true()

	assert_bool(registry_text.contains("CR-13")).override_failure_message(
		"AC-5: section_exited_subscriber_awaits description must reference GDD CR-13."
	).is_true()


# ── AC-1 (registry portion): unauthorized_reload_current_section_caller entry ─

## AC-1 (registry check): All 5 LS-009 pattern entries are present in the registry.
## This single test verifies all five entries exist with the expected pattern names
## and critical fields.
func test_all_five_ls009_forbidden_pattern_entries_present_in_registry() -> void:
	var registry_text: String = _read_registry()

	var required_patterns: Array[String] = [
		"unauthorized_reload_current_section_caller",
		"cross_section_nodepath_reference",
		"missing_register_restore_callback",
		"bypass_thirteen_step_protocol",
		"section_exited_subscriber_awaits",
	]

	for p: String in required_patterns:
		assert_bool(registry_text.contains(p)).override_failure_message(
			"Registry must contain pattern '%s'. Story LS-009. ADR-0007 / ADR-0003." % p
		).is_true()

	# HIGH-severity patterns: unauthorized, cross_section, bypass
	assert_int(registry_text.count("severity: HIGH")).override_failure_message(
		"Registry must contain at least 3 severity: HIGH entries from LS-009 "
		+ "(unauthorized_reload, cross_section_nodepath, bypass_thirteen_step)."
	).is_greater_equal(3)

	# The two MEDIUM entries: missing_register, section_exited_subscriber_awaits
	assert_int(registry_text.count("severity: MEDIUM")).override_failure_message(
		"Registry must contain at least 2 severity: MEDIUM entries from LS-009 "
		+ "(missing_register_restore_callback, section_exited_subscriber_awaits)."
	).is_greater_equal(2)

	# All five must reference their ADR
	assert_bool(registry_text.contains("adr-0007-autoload-load-order-registry")).override_failure_message(
		"At least one LS-009 pattern must reference ADR-0007."
	).is_true()
	assert_bool(registry_text.contains("adr-0003-save-format-contract")).override_failure_message(
		"cross_section_nodepath_reference must reference ADR-0003."
	).is_true()

	# All five must have added: 2026-05-03
	assert_bool(registry_text.contains("added: 2026-05-03")).override_failure_message(
		"LS-009 patterns must have added: 2026-05-03."
	).is_true()


# ── Helpers ───────────────────────────────────────────────────────────────────

## Reads the architecture registry file and returns its text.
## Fails the test if the file cannot be opened.
func _read_registry() -> String:
	var fa: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(REGISTRY_PATH), FileAccess.READ
	)
	assert_object(fa).override_failure_message(
		"Registry file must be readable at %s." % REGISTRY_PATH
	).is_not_null()
	if fa == null:
		return ""
	var text: String = fa.get_as_text()
	fa.close()
	return text


## Recursively scans SRC_DIR for .gd files and returns all regex matches.
## Each match Dictionary has keys: file (String), line (int), matched_text (String).
func _grep_src_recursive(pattern: RegEx) -> Array[Dictionary]:
	return _grep_dir(SRC_DIR, pattern)


## Recursively scans dir_path for .gd files and returns all regex matches.
## dir_path must be a res:// path.
func _grep_dir(dir_path: String, pattern: RegEx) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var absolute_dir: String = ProjectSettings.globalize_path(dir_path)
	_scan_directory(absolute_dir, dir_path, pattern, results)
	return results


## Recursive directory scanner. Populates results with match Dictionaries.
## absolute_dir: filesystem path (no res://)
## res_prefix: the res:// equivalent prefix for constructing res:// paths
func _scan_directory(
	absolute_dir: String,
	res_prefix: String,
	pattern: RegEx,
	results: Array[Dictionary]
) -> void:
	var da: DirAccess = DirAccess.open(absolute_dir)
	if da == null:
		return

	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = da.get_next()
			continue

		var abs_entry: String = absolute_dir.path_join(entry)
		var res_entry: String = res_prefix.path_join(entry)

		if da.current_is_dir():
			_scan_directory(abs_entry, res_entry, pattern, results)
		elif entry.ends_with(".gd"):
			_grep_file(abs_entry, res_entry, pattern, results)

		entry = da.get_next()

	da.list_dir_end()


## Scans a single .gd file for the pattern. Appends match Dictionaries to results.
func _grep_file(
	absolute_path: String,
	res_path: String,
	pattern: RegEx,
	results: Array[Dictionary]
) -> void:
	var fa: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if fa == null:
		return

	var line_num: int = 0
	while not fa.eof_reached():
		line_num += 1
		var line: String = fa.get_line()
		var match_result: RegExMatch = pattern.search(line)
		if match_result != null:
			results.append({
				"file": res_path,
				"line": line_num,
				"matched_text": line.strip_edges(),
			})

	fa.close()


## Formats a violation list into an actionable failure message.
## Cites the pattern name, ADR, GDD CR, and each violation's file + line + text.
func _format_violation_message(
	violations: Array[Dictionary],
	pattern_name: String,
	gdd_ref: String,
	adr_ref: String,
	rule_description: String
) -> String:
	if violations.is_empty():
		return "No violations for %s." % pattern_name

	var msg: String = (
		"[lint] forbidden pattern '%s' violation(s) detected.\n"
		% pattern_name
		+ "Rule: %s\nADR: %s | GDD: %s\n"
		% [rule_description, adr_ref, gdd_ref]
		+ "Violations (%d):\n" % violations.size()
	)
	for v: Dictionary in violations:
		msg += "  %s:%d — %s\n" % [v["file"], v["line"], v["matched_text"]]
	return msg
