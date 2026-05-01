# tests/unit/foundation/node_payload_validity_grep_test.gd
#
# NodePayloadValidityGrepTest — GdUnit4 lint-style guard for Story SB-004 AC-12.
#
# PURPOSE
#   Scans `src/` for handler functions whose first parameter is `Node`-typed
#   and asserts that the function body either:
#     (a) starts with an `is_instance_valid(<param>)` check, OR
#     (b) carries an `# @lint-ignore validity-guard <reason>` annotation that
#         documents why the guard is intentionally omitted.
#
# This is a HEURISTIC lint — it WILL flag false positives on subscribers that
# legitimately don't dereference the Node param. Mark those with the lint-ignore
# annotation. Hard requirement: the annotation must include a `<reason>` so
# reviewers can audit later.
#
# WHY THIS EXISTS
#   ADR-0002 IG 4 mandates the validity guard. Code review can miss it — this
#   automated check makes the omission CI-visible. SB-004 AC-12 §lint-style
#   grep guard.
#
# GATE STATUS
#   Story SB-004 | Logic type → BLOCKING gate. ADR-0002 IG 4.

class_name NodePayloadValidityGrepTest
extends GdUnitTestSuite

const _SRC_ROOT: String = "res://src"
## Match handler signatures with a Node-typed first parameter:
##   func _on_<signal_name>(<param>: Node, ...) -> void:
##   func _on_<signal_name>(<param>: Node3D, ...) -> void:
##   func _on_<signal_name>(<param>: CharacterBody3D, ...) -> void:
## We accept any "Node" superclass — Node, Node2D, Node3D, CharacterBody3D, etc.
const _HANDLER_REGEX: String = "^func\\s+_on_\\w+\\s*\\(\\s*(\\w+)\\s*:\\s*(Node|Node2D|Node3D|CharacterBody[23]D|StaticBody[23]D|Area[23]D|Control)\\b"


## Recursively enumerate all .gd files under src/.
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


## Read a file and return its lines.
func _read_lines(path: String) -> PackedStringArray:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var content: String = f.get_as_text()
	f.close()
	return content.split("\n")


## AC-12 lint guard: every Node-typed handler in src/ has the validity guard
## or the lint-ignore annotation.
func test_every_node_typed_handler_has_validity_guard_or_annotation() -> void:
	var regex: RegEx = RegEx.new()
	var ok: int = regex.compile(_HANDLER_REGEX)
	assert_int(ok).is_equal(OK)

	var files: Array[String] = _collect_gd_files(_SRC_ROOT)
	assert_int(files.size()).override_failure_message(
		"Expected at least one .gd file under src/."
	).is_greater(0)

	var failures: Array[String] = []

	for path: String in files:
		var lines: PackedStringArray = _read_lines(path)
		var i: int = 0
		while i < lines.size():
			var line: String = lines[i]
			var m: RegExMatch = regex.search(line)
			if m == null:
				i += 1
				continue
			var param_name: String = m.get_string(1)
			# Look ahead: skip blank lines, find first non-comment / non-blank line
			# of the function body. That line must contain
			# `is_instance_valid(<param_name>)` OR a lint-ignore annotation must
			# appear in the line(s) above the func or in the func body header.
			var has_guard: bool = false
			var has_ignore: bool = false
			# Check the 3 lines above the func declaration for an annotation.
			var look_back: int = max(0, i - 3)
			for j: int in range(look_back, i):
				if lines[j].contains("@lint-ignore validity-guard"):
					has_ignore = true
					break
			# Check the next 8 lines of the function body for the guard.
			var look_ahead: int = mini(lines.size(), i + 8)
			for j: int in range(i + 1, look_ahead):
				var body_line: String = lines[j]
				var stripped: String = body_line.strip_edges()
				if stripped == "" or stripped.begins_with("#"):
					if body_line.contains("@lint-ignore validity-guard"):
						has_ignore = true
					continue
				if body_line.contains("is_instance_valid(%s)" % param_name):
					has_guard = true
					break
				# First non-blank/non-comment line of the body — if it's not the
				# guard, fall through to fail.
				break

			if not (has_guard or has_ignore):
				failures.append("%s:%d → handler `%s` lacks is_instance_valid(%s) guard and has no @lint-ignore annotation"
					% [path, i + 1, line.strip_edges(), param_name])
			i += 1

	assert_int(failures.size()).override_failure_message(
		"Node-typed signal handlers must have validity guards or lint-ignore annotations. Failures:\n  %s"
		% "\n  ".join(failures)
	).is_equal(0)


## Sanity: the test's own regex correctly identifies the canonical handler in
## SubscriberTemplate. Without this, the lint could pass vacuously by failing
## to match anything.
func test_grep_recognises_subscriber_template_handler() -> void:
	var regex: RegEx = RegEx.new()
	regex.compile(_HANDLER_REGEX)
	var lines: PackedStringArray = _read_lines("res://src/core/signal_bus/subscriber_template.gd")
	var matched: bool = false
	for line: String in lines:
		if regex.search(line) != null:
			matched = true
			break
	assert_bool(matched).override_failure_message(
		"Lint regex must match SubscriberTemplate's handler signatures (positive control)."
	).is_true()
