# tests/unit/foundation/save_load_anti_pattern_lint_test.gd
#
# SaveLoadAntiPatternLintTest — GdUnit4 static lint guards for Story SL-009.
#
# PURPOSE
#   CI-time enforcement of three forbidden patterns declared in ADR-0003
#   §Risks + §Validation Criteria and registered in docs/registry/architecture.yaml.
#   Each test is a grep/regex structural check that catches forbidden patterns
#   before they reach main. All tests are pure file-system reads; no engine state
#   is mutated.
#
# COVERED ACCEPTANCE CRITERIA (Story SL-009)
#   AC-1  — registry entry present: save_service_assembles_state
#   AC-2  — registry entry present: save_state_uses_node_references
#   AC-3  — registry entry present: forgotten_duplicate_deep_on_load
#   AC-4  — lint test functions for all three patterns
#   AC-5  — GDD AC-24 enforced by Pattern 1 lint; GDD AC-25 by Pattern 2 lint
#   AC-6  — actionable failure messages (file, pattern name, ADR cite, refactor hint)
#   AC-7  — discovered by standard test runner (no separate invocation needed)
#   AC-8  — control manifest / registry cross-reference consistency check
#
# SCHEMA DEVIATION NOTE
#   The story's example YAML schema uses `pattern_name` / `severity: HIGH`.
#   The project's existing registry convention uses `pattern` / `status: active` /
#   `description` / `why` / `adr` / `added` (no severity field). The registry
#   entries already committed on 2026-04-19 follow the project convention. This
#   test asserts the project-convention fields (`pattern`, `status: active`) and
#   does NOT assert `pattern_name` or `severity`. This is the intended behaviour.
#
# FORBIDDEN GAMEPLAY CLASS NOTE
#   The story spec lists `Combat` in the Pattern 1 grep list. `Combat` has been
#   omitted because it is too short a substring to grep reliably (it appears in
#   identifiers like `CombatSystem`, combat in comments, etc.) and the story
#   author accepted this omission. The remaining 7 class names are unambiguous.
#
# GATE STATUS
#   Story SL-009 | Config/Data type → BLOCKING per CI rules.
#   Any failure here means a forbidden pattern was introduced — do not merge.

class_name SaveLoadAntiPatternLintTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

const _REGISTRY_PATH: String = "res://docs/registry/architecture.yaml"
const _SAVE_LOAD_SERVICE_PATH: String = "res://src/core/save_load/save_load_service.gd"
const _STATES_DIR: String = "res://src/core/save_load/states"
const _CONTROL_MANIFEST_PATH: String = "res://docs/architecture/control-manifest.md"
const _ADR_0003_RELATIVE: String = "docs/architecture/adr-0003-save-format-contract.md"

## Gameplay system class names that MUST NOT appear in save_load_service.gd source.
## `Combat` is intentionally omitted — too short a substring for reliable grep.
## See file-header note for rationale.
const _FORBIDDEN_GAMEPLAY_CLASSES: Array[String] = [
	"PlayerCharacter",
	"StealthAI",
	"CivilianAI",
	"Inventory",
	"MissionLevelScripting",
	"FailureRespawn",
	"DocumentCollection",
]


# ---------------------------------------------------------------------------
# AC-1: Registry entry — save_service_assembles_state
# ---------------------------------------------------------------------------

## AC-1: docs/registry/architecture.yaml contains an active entry for the
## save_service_assembles_state forbidden pattern, paired with ADR-0003.
## The entry must use the project's schema convention:
##   pattern: save_service_assembles_state
##   status: active
##   adr: docs/architecture/adr-0003-save-format-contract.md
func test_lint_registry_save_service_assembles_state_entry_present() -> void:
	var registry: String = _read_file(_REGISTRY_PATH)

	assert_str(registry).override_failure_message(
		"AC-1 FAIL: docs/registry/architecture.yaml must exist and be readable. "
		+ "If the file was moved, update _REGISTRY_PATH in this test."
	).is_not_empty()

	assert_bool(registry.contains("pattern: save_service_assembles_state")).override_failure_message(
		"AC-1 FAIL: docs/registry/architecture.yaml must contain "
		+ "'pattern: save_service_assembles_state'. "
		+ "The entry was expected to be committed on 2026-04-19 per ADR-0003 §Validation Criteria. "
		+ "Check the registry file and add the missing entry."
	).is_true()

	assert_bool(registry.contains("status: active")).override_failure_message(
		"AC-1 FAIL: The registry must contain at least one 'status: active' entry. "
		+ "Verify the save_service_assembles_state entry is marked active."
	).is_true()

	assert_bool(registry.contains(_ADR_0003_RELATIVE)).override_failure_message(
		"AC-1 FAIL: docs/registry/architecture.yaml must contain a reference to '%s'. "
		% _ADR_0003_RELATIVE
		+ "The save_service_assembles_state entry's 'adr' field must point to ADR-0003."
	).is_true()


# ---------------------------------------------------------------------------
# AC-2: Registry entry — save_state_uses_node_references
# ---------------------------------------------------------------------------

## AC-2: docs/registry/architecture.yaml contains an active entry for the
## save_state_uses_node_references forbidden pattern, paired with ADR-0003.
## Project schema: `pattern: save_state_uses_node_references`, `status: active`.
func test_lint_registry_save_state_uses_node_references_entry_present() -> void:
	var registry: String = _read_file(_REGISTRY_PATH)

	assert_str(registry).override_failure_message(
		"AC-2 FAIL: docs/registry/architecture.yaml must exist and be readable."
	).is_not_empty()

	assert_bool(registry.contains("pattern: save_state_uses_node_references")).override_failure_message(
		"AC-2 FAIL: docs/registry/architecture.yaml must contain "
		+ "'pattern: save_state_uses_node_references'. "
		+ "See ADR-0003 IG 6 + §Risks (NodePath / Node references do not survive scene reload). "
		+ "Add the missing entry using the project schema convention."
	).is_true()


# ---------------------------------------------------------------------------
# AC-3: Registry entry — forgotten_duplicate_deep_on_load
# ---------------------------------------------------------------------------

## AC-3: docs/registry/architecture.yaml contains an active entry for the
## forgotten_duplicate_deep_on_load forbidden pattern, paired with ADR-0003.
## Project schema: `pattern: forgotten_duplicate_deep_on_load`, `status: active`.
func test_lint_registry_forgotten_duplicate_deep_on_load_entry_present() -> void:
	var registry: String = _read_file(_REGISTRY_PATH)

	assert_str(registry).override_failure_message(
		"AC-3 FAIL: docs/registry/architecture.yaml must exist and be readable."
	).is_not_empty()

	assert_bool(registry.contains("pattern: forgotten_duplicate_deep_on_load")).override_failure_message(
		"AC-3 FAIL: docs/registry/architecture.yaml must contain "
		+ "'pattern: forgotten_duplicate_deep_on_load'. "
		+ "See ADR-0003 IG 3 + §Risks (callers must duplicate_deep before handing state to "
		+ "live systems). Add the missing entry using the project schema convention."
	).is_true()


# ---------------------------------------------------------------------------
# AC-4 / AC-5 / AC-6 — Pattern 1: no gameplay class references in service
# ---------------------------------------------------------------------------

## AC-4 (Pattern 1) + AC-5 (GDD AC-24) + AC-6 (actionable message):
## src/core/save_load/save_load_service.gd must not reference any gameplay
## system class by name. Comment lines are stripped before searching so that
## documentation mentioning a class name does not false-positive.
## Enforces GDD AC-24: SaveLoadService contains no game-system references.
##
## Forbidden class list (Combat omitted — too short for reliable grep; see header):
##   PlayerCharacter, StealthAI, CivilianAI, Inventory,
##   MissionLevelScripting, FailureRespawn, DocumentCollection
func test_lint_save_service_no_gameplay_class_references() -> void:
	var source: String = _read_file_no_comments(_SAVE_LOAD_SERVICE_PATH)

	assert_str(source).override_failure_message(
		"AC-4 precondition: %s must exist and be readable. " % _SAVE_LOAD_SERVICE_PATH
		+ "If the file was moved, update _SAVE_LOAD_SERVICE_PATH in this test."
	).is_not_empty()

	var violations: Array[String] = []
	for class_name_str: String in _FORBIDDEN_GAMEPLAY_CLASSES:
		if class_name_str in source:
			violations.append(class_name_str)

	assert_int(violations.size()).override_failure_message(
		("Forbidden pattern save_service_assembles_state detected: "
		+ "%s in save_load_service.gd. "
		+ "See ADR-0003 §Risks. "
		+ "Refactor: SaveLoadService accepts a pre-assembled SaveGame from callers; "
		+ "it must NOT query gameplay systems. "
		+ "Forbidden classes found: [%s]") % [
			violations[0] if violations.size() > 0 else "(none)",
			", ".join(violations)
		]
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-4 / AC-5 / AC-6 — Pattern 2: no NodePath / Node @export in state files
# ---------------------------------------------------------------------------

## AC-4 (Pattern 2) + AC-5 (GDD AC-25) + AC-6 (actionable message):
## Every .gd file in src/core/save_load/states/ must not declare @export fields
## typed as NodePath or Node (bare). Enforces GDD AC-25.
##
## Regex patterns checked:
##   @export\s+var\s+\w+\s*:\s*NodePath   — NodePath-typed export
##   @export\s+var\s+\w+\s*:\s*Node\b    — Node-typed export (word boundary
##                                          excludes Node3D, Node2D, NodePath)
##
## AC-6 failure message identifies the file + matched line for each violation.
func test_lint_state_files_no_node_or_nodepath_export() -> void:
	var nodepath_re: RegEx = RegEx.new()
	nodepath_re.compile("@export\\s+var\\s+\\w+\\s*:\\s*NodePath")

	var node_re: RegEx = RegEx.new()
	node_re.compile("@export\\s+var\\s+\\w+\\s*:\\s*Node\\b")

	var violations: Array[String] = []

	var dir: DirAccess = DirAccess.open(_STATES_DIR)
	assert_object(dir).override_failure_message(
		"AC-4 precondition: DirAccess.open('%s') failed. " % _STATES_DIR
		+ "Verify the states directory exists (Story SL-001 should have created it)."
	).is_not_null()

	if dir == null:
		return

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if filename.ends_with(".gd"):
			var full_path: String = _STATES_DIR + "/" + filename
			var lines: PackedStringArray = _read_file(full_path).split("\n")
			for i: int in range(lines.size()):
				var line: String = lines[i]
				var stripped: String = line.strip_edges()
				# Skip comment lines — a comment mentioning NodePath is not a violation.
				if stripped.begins_with("#"):
					continue
				if nodepath_re.search(line) != null:
					violations.append(
						"Forbidden pattern save_state_uses_node_references detected: "
						+ "NodePath @export in %s:%d → '%s'. "
						% [full_path, i + 1, stripped]
						+ "See ADR-0003 §Risks. "
						+ "Refactor: replace NodePath with actor_id: StringName."
					)
				elif node_re.search(line) != null:
					violations.append(
						"Forbidden pattern save_state_uses_node_references detected: "
						+ "Node @export in %s:%d → '%s'. "
						% [full_path, i + 1, stripped]
						+ "See ADR-0003 §Risks. "
						+ "Refactor: replace Node reference with actor_id: StringName."
					)
		filename = dir.get_next()
	dir.list_dir_end()

	assert_int(violations.size()).override_failure_message(
		("AC-4 FAIL: @export NodePath / @export Node fields found in *_State files. "
		+ "These references cannot survive a scene reload. "
		+ "Per ADR-0003 IG 6, use stable actor_id: StringName instead.\n  %s")
		% "\n  ".join(violations)
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-4 — Pattern 3: forgotten_duplicate_deep — registry assertion (MVP)
# ---------------------------------------------------------------------------

## AC-4 (Pattern 3) — deferred caller-site lint.
##
## At MVP, no callers of SaveLoad.load_from_slot exist outside the SaveLoad
## service tests (Mission Scripting / Failure & Respawn / Menu System are
## post-Foundation epics). This test asserts only that the registry entry
## exists, which is the required CI gate for this pattern at this stage.
##
## DEFERRED LINT: When the first caller of SaveLoad.load_from_slot is
## introduced (expected in the Mission Scripting or Failure & Respawn epic),
## this test must be extended to:
##   1. Grep project-wide for `load_from_slot` call sites (excluding service + tests).
##   2. For each call site, verify a `.duplicate_deep()` call appears within
##      ~10 lines of the load result being assigned to a variable.
##   3. Fail with an actionable message if any call site lacks duplicate_deep.
## See Story SL-009 §Out of Scope + ADR-0003 IG 3 for full spec.
func test_lint_forgotten_duplicate_deep_registry_entry_only_at_mvp() -> void:
	var registry: String = _read_file(_REGISTRY_PATH)

	assert_str(registry).override_failure_message(
		"AC-4 (Pattern 3) FAIL: docs/registry/architecture.yaml must exist and be readable."
	).is_not_empty()

	# Registry existence check mirrors test_lint_registry_forgotten_duplicate_deep_on_load_entry_present.
	# This function makes the deferred-lint contract explicit and documents the
	# activation condition for the next implementer.
	assert_bool(registry.contains("pattern: forgotten_duplicate_deep_on_load")).override_failure_message(
		"AC-4 (Pattern 3) FAIL: Registry entry 'forgotten_duplicate_deep_on_load' is missing. "
		+ "See ADR-0003 IG 3 + §Risks. "
		+ "Caller-site lint is deferred until Mission Scripting / F&R / Menu System ship "
		+ "(those are the first callers of SaveLoad.load_from_slot). "
		+ "Add the registry entry to unblock this test."
	).is_true()


# ---------------------------------------------------------------------------
# AC-8: Control manifest / registry cross-reference consistency
# ---------------------------------------------------------------------------

## AC-8: docs/architecture/control-manifest.md mentions all three pattern
## names, and docs/registry/architecture.yaml has a matching entry for each.
## This ensures the declarative manifest and the enforced registry stay in sync.
##
## Matching strategy: simple String.contains() on both files.
## The manifest already references all three patterns by name (lines 88-90).
## A future manifest revision adding a 4th Save/Load anti-pattern row without
## a corresponding registry entry will cause this test to fire.
func test_lint_control_manifest_cross_references_registry() -> void:
	var manifest: String = _read_file(_CONTROL_MANIFEST_PATH)
	var registry: String = _read_file(_REGISTRY_PATH)

	assert_str(manifest).override_failure_message(
		"AC-8 precondition: %s must exist and be readable." % _CONTROL_MANIFEST_PATH
	).is_not_empty()

	assert_str(registry).override_failure_message(
		"AC-8 precondition: %s must exist and be readable." % _REGISTRY_PATH
	).is_not_empty()

	# All three patterns the manifest cites must have registry entries.
	const PATTERNS: Array[String] = [
		"save_service_assembles_state",
		"save_state_uses_node_references",
		"forgotten_duplicate_deep_on_load",
	]

	for pattern_name: String in PATTERNS:
		var in_manifest: bool = manifest.contains(pattern_name)
		var in_registry: bool = registry.contains("pattern: " + pattern_name)

		assert_bool(in_manifest).override_failure_message(
			("AC-8 FAIL: control-manifest.md does not mention pattern '%s'. "
			+ "Either the manifest needs a row for this pattern, or the registry "
			+ "entry should be retired. Manifest path: %s") % [pattern_name, _CONTROL_MANIFEST_PATH]
		).is_true()

		assert_bool(in_registry).override_failure_message(
			("AC-8 FAIL: docs/registry/architecture.yaml has no entry for pattern '%s' "
			+ "even though control-manifest.md references it. "
			+ "Add the registry entry or remove the manifest reference. "
			+ "See ADR-0003 §Validation Criteria.") % pattern_name
		).is_true()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Reads the full text of a res:// file. Returns empty string on failure.
func _read_file(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


## Reads a res:// file and strips all comment lines (lines whose first non-
## whitespace character is `#`). Used for Pattern 1 grep so that a class name
## appearing only in a doc-comment does not trigger a false-positive.
func _read_file_no_comments(path: String) -> String:
	var content: String = _read_file(path)
	if content.is_empty():
		return ""
	var lines: PackedStringArray = content.split("\n")
	var out_lines: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var stripped: String = line.strip_edges()
		# Drop full-line comments (both `##` doc comments and `#` inline comments).
		if stripped.begins_with("#"):
			continue
		out_lines.append(line)
	return "\n".join(out_lines)
