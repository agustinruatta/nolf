# tests/unit/foundation/post_process_stack/glow_ban_lint_test.gd
#
# GlowBanLintTest — GdUnit4 static analysis suite for Story PPS-005.
#
# WHAT IS TESTED
#   AC-4: Zero occurrences of the literal string "glow_enabled = true" in any
#         GDScript file under src/. This is the CI lint check required by
#         design/gdd/post-process-stack.md §Core Rule 4 and the control manifest
#         (forbidden pattern: modern_post_process_stack).
#
# WHAT IS NOT TESTED HERE
#   - The runtime enforcement hook behavior (see glow_ban_enforcement_test.gd)
#   - test/ files are explicitly excluded from the grep scope (tests may
#     legitimately set glow_enabled for behavior verification)
#
# EXCEPTION LOGIC
#   Lines that contain "env.glow_enabled = false" or contain the string
#   "glow_enabled = false" are NOT violations — they are the enforcement code
#   that forces glow off. Lines must contain the exact string
#   "glow_enabled = true" (not "glow_enabled = false", not "glow_enabled") to
#   be flagged. Comment lines (stripped line starts with #) are skipped.
#
# GATE STATUS
#   Story PPS-005 | Logic type → BLOCKING gate (test-evidence requirement).
#   AC-4 lint failure blocks the story from Done.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[system]_[scenario]_[expected_result]
#
# REFERENCES
#   Implements: Story PPS-005 AC-4 (GDD §AC-22)
#   GDD: design/gdd/post-process-stack.md §Core Rule 4, §anti-pattern fences
#   Control Manifest: forbidden pattern modern_post_process_stack

class_name GlowBanLintTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# AC-4: No "glow_enabled = true" in src/
# ---------------------------------------------------------------------------

## AC-4: Zero occurrences of the literal string "glow_enabled = true" in any
## GDScript file under src/.
##
## This test walks src/ recursively, reads each .gd file, and flags any
## non-comment line containing the exact forbidden pattern.
##
## Permitted exceptions: lines containing "glow_enabled = false" are NOT
## violations — they are the enforcement code that forces glow off. The validator
## in post_process_stack.gd writes `env.glow_enabled = false` which contains
## "false" not "true", so it is never flagged.
##
## Files in tests/ are NOT scanned — test files may set glow_enabled=true to
## verify enforcement behavior. The scan scope is exclusively res://src/.
func test_no_glow_enabled_true_in_src() -> void:
	# Arrange
	var violations: Array[String] = []
	_scan_directory("res://src", violations)

	# Assert
	assert_int(violations.size()).override_failure_message(
		"AC-4: 'glow_enabled = true' must not appear in any src/ GDScript file. "
		+ "Violations:\n%s" % "\n".join(violations)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Recursively walks [path], calling _scan_file() for each .gd file found.
## Skips hidden directories (names beginning with ".").
##
## Uses DirAccess.open() — returns null if the path does not exist; silently
## skips absent directories to avoid false failures on partial checkouts.
func _scan_directory(path: String, violations: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		# Path does not exist or is not accessible — skip silently.
		# This is expected when src/ is empty at project inception.
		return

	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full_path: String = path + "/" + name
		if dir.current_is_dir():
			# Skip hidden directories (e.g. .git, .godot).
			if not name.begins_with("."):
				_scan_directory(full_path, violations)
		elif name.ends_with(".gd"):
			_scan_file(full_path, violations)
		name = dir.get_next()
	dir.list_dir_end()


## Reads [file_path] line by line and appends to [violations] any non-comment
## line containing the exact forbidden string "glow_enabled = true".
##
## Skipping logic:
##   • Lines whose stripped content begins with "#" are pure comments — skip.
##   • Lines containing "glow_enabled = false" are enforcement code — skip.
##     (The enforcement code in post_process_stack.gd writes `env.glow_enabled = false`,
##     which contains "false", not "true". This skip is a defensive guard against
##     future refactors that might put both strings on the same line.)
##
## Uses FileAccess.open() — returns null if the file is unreadable; silently
## skips unreadable files (permissions issue, not a lint violation).
func _scan_file(file_path: String, violations: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		# File unreadable — skip. Not a lint violation.
		return

	var line_num: int = 0
	while not file.eof_reached():
		line_num += 1
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()

		# Skip pure comment lines.
		if stripped.begins_with("#"):
			continue

		# Skip empty lines (no violation possible).
		if stripped.is_empty():
			continue

		# Check for the forbidden pattern.
		if "glow_enabled = true" in stripped:
			# Allow the enforcement code that disables glow — it contains "= false"
			# and would never match "= true", but guard defensively.
			if "glow_enabled = false" in stripped:
				continue
			violations.append(
				"%s:%d: %s" % [file_path, line_num, stripped]
			)

	file.close()
