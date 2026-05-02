# tests/ci/hands_not_on_outline_tier_lint.gd
#
# HandsNotOnOutlineTierLintTest — GdUnit4 CI lint suite for Story PC-008 AC-9.1.
#
# PURPOSE
#   Enforces the ADR-0005 inverted-hull exception: the FPS hands MeshInstance3D
#   must NEVER be passed to OutlineTier.set_tier(). Hands use their own
#   inverted-hull pipeline (ADR-0005), not ADR-0001's stencil contract.
#   Any future developer who accidentally routes hands through the stencil
#   tier system is caught here before merge.
#
# CI GATE
#   This test runs on every push to main and every PR (same CI sweep as all
#   other tests). A failure here means a forbidden pattern was introduced.
#   ADR-0005 IG 1: hands are the ONLY mesh class excepted from ADR-0001.
#
# AC-9.1 SPEC
#   GIVEN all .gd files under src/ are grepped for the pattern
#         `hands` + any chars + `OutlineTier.set_tier`  (case-insensitive)
#   WHEN the grep returns results
#   THEN zero matches — the hands mesh must NOT call OutlineTier.set_tier
#   (CI lint pattern `hands.*OutlineTier\.set_tier`).
#
# PATTERN NOTES
#   The pattern is deliberately broad: any code line containing both
#   "hands" (case-insensitive) and "OutlineTier.set_tier" is a violation.
#   Comment lines (# and ##) are stripped before matching to prevent
#   false-positives from documentation that references the pattern by name.
#
# GATE STATUS
#   Story PC-008 | Logic type → BLOCKING gate.
#   Test is a CI structural guard; if it fails, do not merge.

class_name HandsNotOnOutlineTierLintTest
extends GdUnitTestSuite


const _SRC_DIR: String = "res://src/"
const _PATTERN: String = "hands.*OutlineTier\\.set_tier"


# ── Helper: recursive file-system walk collecting .gd paths ────────────────

## Returns all .gd file absolute paths under dir_path, recursively.
## Uses DirAccess for portable Godot-native file enumeration.
static func _collect_gd_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var da: DirAccess = DirAccess.open(dir_path)
	if da == null:
		return results
	da.include_navigational = false
	da.include_hidden = false
	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if da.current_is_dir():
			results.append_array(_collect_gd_files(full))
		elif entry.ends_with(".gd"):
			results.append(full)
		entry = da.get_next()
	da.list_dir_end()
	return results


# ── Main lint test ──────────────────────────────────────────────────────────

## AC-9.1: No .gd file under src/ contains a code line matching
## `hands.*OutlineTier\.set_tier` (case-insensitive).
## Hands use the inverted-hull pipeline (ADR-0005), not stencil tiers (ADR-0001).
func test_hands_not_passed_to_outline_tier_set_tier() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	assert_int(gd_files.size()).override_failure_message(
		("AC-9.1 precondition: no .gd files found under %s. "
		+ "If the src/ directory was moved, update _SRC_DIR in this test.") % _SRC_DIR
	).is_greater(0)

	var lint_regex: RegEx = RegEx.new()
	# Case-insensitive flag (?i) on the pattern so "Hands", "HANDS", etc. are caught.
	lint_regex.compile("(?i)hands.*OutlineTier\\.set_tier")

	var violations: Array[String] = []

	for file_path: String in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var content: String = f.get_as_text()
		f.close()

		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			# Skip blank lines and comment lines (doc-comments start with ##).
			var stripped: String = line.strip_edges()
			if stripped == "" or stripped.begins_with("#"):
				continue
			# Strip trailing inline comment before pattern matching to avoid
			# false-positives from inline docs that reference the pattern by name.
			var hash_idx: int = line.find(" #")
			var code_part: String = line if hash_idx < 0 else line.substr(0, hash_idx)
			if lint_regex.search(code_part) != null:
				violations.append("  %s:%d → %s" % [file_path, i + 1, stripped])

	assert_int(violations.size()).override_failure_message(
		("AC-9.1 FAIL: Hands mesh is being passed to OutlineTier.set_tier "
		+ "(ADR-0005 inverted-hull exception violated). "
		+ "Pattern `hands.*OutlineTier\\.set_tier` found %d time(s):\n%s\n"
		+ "Hands must use material_overlay with hands_outline_material.tres "
		+ "(ADR-0005 IG 7), NOT the stencil tier pipeline (ADR-0001). "
		+ "Remove or relocate these set_tier calls.") % [violations.size(), "\n".join(violations)]
	).is_equal(0)
