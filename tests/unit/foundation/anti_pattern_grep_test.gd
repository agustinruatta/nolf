# tests/unit/foundation/anti_pattern_grep_test.gd
#
# AntiPatternGrepTest — GdUnit4 grep-style guards for Story SB-005.
#
# PURPOSE
#   CI-time enforcement of Signal Bus anti-patterns documented in ADR-0002 §Risks
#   and registered in docs/registry/architecture.yaml. Each test below catches
#   one structural violation that code review historically misses.
#
# Covered acceptance criteria (Signal Bus AC):
#   • AC-10 — no wrapper emit methods (`Events.emit_*` is forbidden; use `Events.<sig>.emit`)
#   • AC-13 — no enum declarations on events.gd (enums live on their concept's class)
#   • AC-14 — exactly one `: Variant` annotation on events.gd (the setting_changed exception)
#
# AC-9 (cross-autoload method-call coupling) is NOT automated — it is a
# code-review checkpoint per ADR-0002 §Accessor Conventions exemption clause.
# See `docs/registry/code-review-checklist.md` for the manual review item.
#
# GATE STATUS
#   Story SB-005 | Config/Data type → ADVISORY (per coding-standards Test Evidence
#   table for Config/Data stories). The grep tests themselves are still BLOCKING
#   on PR — a failing grep means a forbidden pattern was introduced.

class_name AntiPatternGrepTest
extends GdUnitTestSuite

const _SRC_ROOT: String = "res://src"
const _EVENTS_GD: String = "res://src/core/signal_bus/events.gd"


# ── AC-10: No wrapper emit methods ───────────────────────────────────────────

## AC-10: `Events.emit_<signal>(args)` wrapper-emit pattern is forbidden.
## All emits must go through `Events.<signal>.emit(args)` directly.
func test_no_events_emit_wrapper_calls_in_src() -> void:
	var failures: Array[String] = _grep_lines(_SRC_ROOT, "Events\\.emit_")
	# Filter false-positives: comments mentioning the forbidden pattern by name.
	var real_failures: Array[String] = []
	for line: String in failures:
		# A line is a real call if it contains `Events.emit_` AND is NOT a comment.
		# Strip leading whitespace and check first non-blank char isn't `#`.
		var idx_path_end: int = line.find(":")
		if idx_path_end < 0:
			continue
		var idx_line_end: int = line.find(":", idx_path_end + 1)
		if idx_line_end < 0:
			continue
		var code: String = line.substr(idx_line_end + 1).strip_edges()
		if code.begins_with("#") or code.begins_with("##"):
			continue
		real_failures.append(line)

	assert_int(real_failures.size()).override_failure_message(
		"AC-10: `Events.emit_*(...)` wrapper-emit calls are forbidden. Use `Events.<signal>.emit(...)` directly. Found:\n  %s"
		% "\n  ".join(real_failures)
	).is_equal(0)


# ── AC-13: No enum declarations on events.gd ─────────────────────────────────

## AC-13: events.gd is structural-pure — no enums (enums live on concept classes).
func test_no_enum_declarations_on_events_gd() -> void:
	var lines: PackedStringArray = _read_lines(_EVENTS_GD)
	var failures: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		# Skip comments.
		if stripped.begins_with("#"):
			continue
		# Match `enum ` at start of stripped line (anchored).
		if stripped.begins_with("enum "):
			failures.append("%s:%d → '%s'" % [_EVENTS_GD, i + 1, stripped])

	assert_int(failures.size()).override_failure_message(
		"AC-13: events.gd must declare zero enums. Found:\n  %s" % "\n  ".join(failures)
	).is_equal(0)


# ── AC-14: events.gd has exactly 1 `: Variant` (the setting_changed exception) ─

## AC-14: events.gd has exactly one `: Variant` annotation (the setting_changed
## value parameter — sole intentional Variant exception per ADR-0002).
func test_events_gd_has_exactly_one_variant_annotation() -> void:
	var lines: PackedStringArray = _read_lines(_EVENTS_GD)
	var matches: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		# Skip comment lines.
		if stripped.begins_with("#"):
			continue
		# Strip any inline-trailing comment so a `# : Variant` in a comment
		# doesn't false-positive.
		var hash_idx: int = line.find("#")
		var code: String = line if hash_idx < 0 else line.substr(0, hash_idx)
		if ": Variant" in code:
			matches.append("%s:%d → '%s'" % [_EVENTS_GD, i + 1, stripped])

	assert_int(matches.size()).override_failure_message(
		"AC-14: events.gd must have EXACTLY one `: Variant` (the setting_changed exception). Found %d:\n  %s"
		% [matches.size(), "\n  ".join(matches)]
	).is_equal(1)
	# Sanity: the matching line should be the `setting_changed` signal.
	if matches.size() == 1:
		assert_str(matches[0]).override_failure_message(
			"The single `: Variant` must be on the setting_changed signal declaration. Got: %s" % matches[0]
		).contains("setting_changed")


# ── Recap: events.gd structural purity (overlap with Story SB-001) ───────────

## Defense-in-depth: events.gd has zero func/var/const declarations beyond the
## signal block. Story SB-001 already enforces this; AC-13 + AC-14 + this test
## together harden the events.gd surface.
func test_events_gd_has_no_func_var_const_declarations() -> void:
	var lines: PackedStringArray = _read_lines(_EVENTS_GD)
	var failures: Array[String] = []
	var func_re: RegEx = RegEx.new()
	func_re.compile("^\\s*(static\\s+)?func\\s+")
	var var_re: RegEx = RegEx.new()
	# Allow signals (`signal foo(...)`) but reject `var ` and `const `.
	var_re.compile("^\\s*(@export\\s+)?(var|const)\\s+")
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		if func_re.search(line) != null:
			failures.append("%s:%d (func) → '%s'" % [_EVENTS_GD, i + 1, stripped])
		if var_re.search(line) != null:
			failures.append("%s:%d (var/const) → '%s'" % [_EVENTS_GD, i + 1, stripped])

	assert_int(failures.size()).override_failure_message(
		"events.gd must contain ONLY signal declarations + the class-name header. Found:\n  %s"
		% "\n  ".join(failures)
	).is_equal(0)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _read_lines(path: String) -> PackedStringArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var content: String = f.get_as_text()
	f.close()
	return content.split("\n")


## Recursively grep all .gd files under `root` for `pattern` (regex). Returns
## an array of "<path>:<line_num>:<line_content>" strings.
func _grep_lines(root: String, pattern: String) -> Array[String]:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	var out: Array[String] = []
	var files: Array[String] = _collect_gd_files(root)
	for path: String in files:
		var lines: PackedStringArray = _read_lines(path)
		for i: int in range(lines.size()):
			if regex.search(lines[i]) != null:
				out.append("%s:%d:%s" % [path, i + 1, lines[i]])
	return out


func _collect_gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full_path: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			out.append_array(_collect_gd_files(full_path))
		elif name.ends_with(".gd"):
			out.append(full_path)
		name = dir.get_next()
	dir.list_dir_end()
	return out
