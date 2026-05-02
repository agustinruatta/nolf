# tests/unit/feature/stealth_ai/stealth_ai_forbidden_patterns_test.gd
#
# StealthAIForbiddenPatternsTest — Story SAI-009 (CI grep fences).
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-009)
#   AC-1: SAI must NOT subscribe to Events.player_footstep — pull-only via
#         player.get_noise_level(). (player_footstep grep across SAI source.)
#   AC-2: NavigationServer3D.map_get_path synchronous calls forbidden in SAI;
#         must use NavigationAgent3D async dispatch (ADR-0006 IG).
#   AC-3: call_deferred forbidden in guard.gd — synchronicity contract for
#         the state machine + damage routing.
#   AC-4: Bare integer literals in collision_layer/collision_mask assignments
#         forbidden in SAI source; PhysicsLayers.* constants required (ADR-0006).
#         EXCEPTION: integer 0 (sensor / no-layer Area3D) is the only allowed
#         literal — VisionCone uses `_vision_cone.collision_layer = 0` per
#         ADR-0006 IG and there is no PhysicsLayers.MASK_NONE constant.
#   AC-5: events.gd contains zero `enum` declarations (ADR-0002 IG 2 fence).
#   AC-6: events.gd contains all 6 SAI-domain signal declarations (presence sweep).
#
# DESIGN
#   These tests run static source-file grep assertions via OS.execute. They
#   provide a regression fence against future edits that introduce forbidden
#   patterns. Failures here block CI per coding-standards.md.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIForbiddenPatternsTest
extends GdUnitTestSuite

const _SAI_DIRS: Array[String] = [
		"res://src/gameplay/stealth/",
]
const _EVENTS_GD_PATH: String = "res://src/core/signal_bus/events.gd"
const _GUARD_GD_PATH: String = "res://src/gameplay/stealth/guard.gd"


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns the absolute filesystem path for a res:// URI, suitable for shell tools.
func _abs_path(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path)


## Returns the contents of a res:// file, or an empty string if missing.
func _read_file(res_path: String) -> String:
	var file: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return ""
	var contents: String = file.get_as_text()
	file.close()
	return contents


## Lists all .gd files under the given res:// directory using DirAccess
## (recursive). Returns res:// paths.
func _list_gd_files_in(res_dir: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(res_dir)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				results.append_array(_list_gd_files_in(res_dir.path_join(entry)))
		else:
			if entry.ends_with(".gd"):
				results.append(res_dir.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return results


## Lists all .gd files in any of _SAI_DIRS. Excludes _exclude_paths if provided.
func _list_all_sai_gd_files(exclude_paths: Array[String] = []) -> Array[String]:
	var results: Array[String] = []
	for dir: String in _SAI_DIRS:
		results.append_array(_list_gd_files_in(dir))
	# Filter out excluded paths
	var filtered: Array[String] = []
	for path: String in results:
		if not exclude_paths.has(path):
			filtered.append(path)
	return filtered


# ── AC-1: No player_footstep subscription in SAI source ──────────────────────

## Returns true if the file contains `needle` in any non-comment line.
## Strips full-line comments (line starts with `#`) and inline comments
## (everything after the first `#` on a line) so doc-comments documenting
## the forbidden pattern do not produce false positives.
func _file_contains_in_code(path: String, needle: String) -> bool:
	var contents: String = _read_file(path)
	for line: String in contents.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var code_part: String = line
		var hash_idx: int = line.find("#")
		if hash_idx >= 0:
			code_part = line.substr(0, hash_idx)
		if code_part.contains(needle):
			return true
	return false


## AC-1: SAI must use pull model (player.get_noise_level()), not push (subscribe
## to Events.player_footstep). Grep for the literal string "player_footstep"
## across all SAI source files (skip comments to avoid doc-comment false positives).
func test_no_player_footstep_subscription_in_sai_source() -> void:
	var offending: Array[String] = []
	for path: String in _list_all_sai_gd_files():
		if _file_contains_in_code(path, "player_footstep"):
			offending.append(path)

	assert_int(offending.size()).override_failure_message(
			"AC-1: SAI source must NOT reference 'player_footstep' (push-mode subscription forbidden). "
			+ "Offending files: %s" % str(offending)
	).is_equal(0)


# ── AC-2: No NavigationServer3D.map_get_path synchronous calls ──────────────

## AC-2: SAI gameplay code must use NavigationAgent3D async dispatch only.
## Synchronous map_get_path calls violate the async-nav budget (ADR-0006 IG).
## Skips comments to avoid doc-comment false positives.
func test_no_sync_navigation_server_calls_in_sai_source() -> void:
	var offending: Array[String] = []
	for path: String in _list_all_sai_gd_files():
		if _file_contains_in_code(path, "NavigationServer3D.map_get_path"):
			offending.append(path)

	assert_int(offending.size()).override_failure_message(
			"AC-2: SAI source must NOT call NavigationServer3D.map_get_path "
			+ "(use NavigationAgent3D async dispatch only — ADR-0006). "
			+ "Offending files: %s" % str(offending)
	).is_equal(0)


# ── AC-3: No call_deferred in guard.gd ───────────────────────────────────────

## AC-3: Guard's state machine + damage routing must be synchronous.
## call_deferred breaks the AC-SAI-1.11 synchronicity contract.
func test_no_call_deferred_in_guard_gd() -> void:
	var contents: String = _read_file(_GUARD_GD_PATH)
	assert_str(contents).is_not_empty()

	# Skip comment lines containing "call_deferred" (doc comments may legitimately
	# describe the forbidden pattern).
	var found_lines: Array[String] = []
	var line_number: int = 0
	for line: String in contents.split("\n"):
		line_number += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		# Strip trailing inline comments before checking
		var code_part: String = line
		var hash_idx: int = line.find("#")
		if hash_idx >= 0:
			code_part = line.substr(0, hash_idx)
		if code_part.contains("call_deferred"):
			found_lines.append("line %d: %s" % [line_number, stripped])

	assert_int(found_lines.size()).override_failure_message(
			"AC-3: guard.gd must NOT use call_deferred — synchronicity contract (AC-SAI-1.11). "
			+ "Offending lines: %s" % str(found_lines)
	).is_equal(0)


# ── AC-4: No bare physics layer integer literals (ADR-0006) ─────────────────

## AC-4: collision_layer and collision_mask assignments must use PhysicsLayers.*
## constants, not bare integer literals. EXCEPTION: integer 0 is allowed for
## sensor/unindexed-layer Area3D (no PhysicsLayers.MASK_NONE constant exists).
##
## The grep pattern matches `collision_layer = N` or `collision_mask = N`
## where N is any non-zero digit. The 0 literal is the only allowed bare integer.
func test_no_bare_physics_layer_integers_in_sai_source() -> void:
	var pattern: RegEx = RegEx.create_from_string(
			"(collision_layer|collision_mask)\\s*=\\s*([1-9][0-9]*)"
	)
	var offending: Array[String] = []

	for path: String in _list_all_sai_gd_files():
		var contents: String = _read_file(path)
		var line_number: int = 0
		for line: String in contents.split("\n"):
			line_number += 1
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			# Strip trailing inline comments
			var code_part: String = line
			var hash_idx: int = line.find("#")
			if hash_idx >= 0:
				code_part = line.substr(0, hash_idx)
			if pattern.search(code_part) != null:
				offending.append("%s:%d: %s" % [path, line_number, stripped])

	assert_int(offending.size()).override_failure_message(
			"AC-4: SAI source must NOT use bare integer literals for collision_layer/collision_mask "
			+ "(use PhysicsLayers.* constants — ADR-0006). Integer 0 is allowed (sensor). "
			+ "Offending lines: %s" % str(offending)
	).is_equal(0)


# ── AC-5: events.gd contains zero enum declarations (ADR-0002 IG 2) ─────────

## AC-5: events.gd is a signal-bus pure declaration file. enum declarations
## belong on the system class that owns the concept, never on the bus.
## (Already partially covered by Story 002's events_sai_signals_test.gd; this
## fence provides a story-specific failure message and a permanent regression
## guard against future edits.)
func test_events_gd_has_zero_enum_declarations() -> void:
	var contents: String = _read_file(_EVENTS_GD_PATH)
	assert_str(contents).is_not_empty()

	var enum_decl_count: int = 0
	for line: String in contents.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if stripped.begins_with("enum "):
			enum_decl_count += 1

	assert_int(enum_decl_count).override_failure_message(
			"AC-5: events.gd must contain ZERO enum declarations per ADR-0002 IG 2. Found %d." % enum_decl_count
	).is_equal(0)


# ── AC-6: events.gd contains all 6 SAI-domain signal declarations ────────────

## AC-6: events.gd declares all 6 SAI signals as a presence sweep. Failure here
## means a signal was silently dropped (e.g., a refactor that broke the SAI bus).
func test_events_gd_contains_all_six_sai_signal_declarations() -> void:
	var contents: String = _read_file(_EVENTS_GD_PATH)
	assert_str(contents).is_not_empty()

	var expected_signals: Array[String] = [
			"signal alert_state_changed(",
			"signal actor_became_alerted(",
			"signal actor_lost_target(",
			"signal takedown_performed(",
			"signal guard_incapacitated(",
			"signal guard_woke_up(",
	]
	var missing: Array[String] = []
	for sig_decl: String in expected_signals:
		if not contents.contains(sig_decl):
			missing.append(sig_decl)

	assert_int(missing.size()).override_failure_message(
			"AC-6: events.gd must declare all 6 SAI-domain signals. Missing: %s" % str(missing)
	).is_equal(0)


## AC-6 + AC-2 of Story 002: Verify guard_incapacitated.cause is `int` (not enum).
## Cross-autoload convention — events.gd must not import CombatSystemNode IN CODE
## (doc-comments mentioning the forbidden import are allowed for documentation).
func test_guard_incapacitated_cause_is_typed_as_int_not_enum() -> void:
	# Must contain the int-typed signature
	var contents: String = _read_file(_EVENTS_GD_PATH)
	assert_str(contents).is_not_empty()
	assert_bool(contents.contains("signal guard_incapacitated(guard: Node, cause: int)")).override_failure_message(
			"AC-6: guard_incapacitated.cause must be `int`, not enum (cross-autoload convention)."
	).is_true()

	# CombatSystemNode.DamageType must not appear in non-comment code
	assert_bool(_file_contains_in_code(_EVENTS_GD_PATH, "CombatSystemNode.DamageType")).override_failure_message(
			"AC-6: events.gd code must NOT import CombatSystemNode.DamageType (cross-autoload import forbidden)."
	).is_false()
