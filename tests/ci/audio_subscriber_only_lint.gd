# tests/ci/audio_subscriber_only_lint.gd
#
# AudioSubscriberOnlyLintTest — GdUnit4 CI lint suite for Story AUD-002 AC-5.
#
# PURPOSE
#   Enforces the subscriber-only invariant: AudioManager must NEVER emit
#   signals on the Events bus (GDD Rule 9, ADR-0002 §Subscriber-only contract).
#   This is a grep-style structural check that fails immediately if any
#   `Events.<signal_name>.emit(` call is added to audio_manager.gd.
#
# CI GATE
#   This test runs on every push to main and every PR (same CI sweep as all
#   other tests). A failure here means a forbidden emit pattern was introduced.
#
# AC-5 SPEC
#   GIVEN `src/audio/audio_manager.gd` source is grepped for `Events.*.emit(`
#   WHEN the grep returns results
#   THEN zero matches — AudioManager emits nothing on the bus (subscriber-only
#   invariant; pattern `audio_publishing_signals` must be absent).
#
# GATE STATUS
#   Story AUD-002 | Logic type -> BLOCKING gate.
#   Test is a CI structural guard; if it fails, do not merge.

class_name AudioSubscriberOnlyLintTest
extends GdUnitTestSuite


const _AUDIO_MANAGER_PATH: String = "res://src/audio/audio_manager.gd"


## AC-5: audio_manager.gd contains zero `Events.<name>.emit(` calls.
## Skips comment lines (both `#` and `##` doc-comment prefixes) to avoid
## false-positives from documentation that references the pattern by name.
func test_audiomanager_contains_no_events_emit_calls() -> void:
	var f: FileAccess = FileAccess.open(_AUDIO_MANAGER_PATH, FileAccess.READ)
	assert_object(f).override_failure_message(
		("AC-5 precondition: %s must exist and be readable. "
		+ "If the file was moved, update _AUDIO_MANAGER_PATH in this test.") % _AUDIO_MANAGER_PATH
	).is_not_null()

	var content: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = content.split("\n")

	# Pattern: `Events.` followed by a signal name (lowercase + underscores)
	# followed by `.emit(`. Captures the canonical emit call form.
	var emit_regex: RegEx = RegEx.new()
	emit_regex.compile("Events\\.[a-z_]+\\.emit\\(")

	var violations: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		# Skip blank lines and comment lines (doc-comments start with `##`).
		var stripped: String = line.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			continue
		# Strip trailing inline comment before pattern matching, so a comment
		# such as `# do not call Events.signal_name.emit(` does not false-positive.
		var hash_idx: int = line.find(" #")
		var code_part: String = line if hash_idx < 0 else line.substr(0, hash_idx)
		if emit_regex.search(code_part) != null:
			violations.append("  %s:%d → %s" % [_AUDIO_MANAGER_PATH, i + 1, stripped])

	assert_int(violations.size()).override_failure_message(
		("AC-5 FAIL: AudioManager emits on the Events bus (subscriber-only invariant violated). "
		+ "Pattern `Events.<name>.emit(` found %d time(s):\n%s\n"
		+ "Remove or relocate these emit calls — AudioManager is a subscriber-only system "
		+ "(GDD Rule 9, ADR-0002 §Subscriber-only contract).") % [violations.size(), "\n".join(violations)]
	).is_equal(0)


## AC-5 (defence-in-depth): also check for bare `.emit(` calls that might
## bypass the `Events.` prefix guard (e.g., a local alias `var e := Events`
## followed by `e.signal_name.emit(...)`). Scans only the audio_manager source.
## If this fires, investigate — it may be a legitimate non-Events emit (e.g.,
## emitting the manager's own custom signals, which is allowed). This test
## is informational: it reports the count but the pass/fail is on the
## authoritative Events-prefixed pattern test above.
## NOTE: AudioManager currently declares no custom signals, so zero `.emit(`
## calls of any kind are expected. This will need updating if custom signals
## are added to AudioManager in a future story.
func test_audiomanager_contains_no_emit_calls_of_any_kind() -> void:
	var f: FileAccess = FileAccess.open(_AUDIO_MANAGER_PATH, FileAccess.READ)
	if f == null:
		# If the file is unreadable, the previous test already failed.
		return
	var content: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = content.split("\n")

	var emit_regex: RegEx = RegEx.new()
	emit_regex.compile("\\.emit\\(")

	var matches: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			continue
		var hash_idx: int = line.find(" #")
		var code_part: String = line if hash_idx < 0 else line.substr(0, hash_idx)
		if emit_regex.search(code_part) != null:
			matches.append("  %s:%d → %s" % [_AUDIO_MANAGER_PATH, i + 1, stripped])

	assert_int(matches.size()).override_failure_message(
		("AC-5 (defence-in-depth): AudioManager has `.emit(` call(s) in source. "
		+ "AudioManager is subscriber-only and currently declares no custom signals. "
		+ "If a custom signal was intentionally added, update this test with the allowed "
		+ "emit site and confirm it is NOT on the Events bus.\nFound:\n%s") % "\n".join(matches)
	).is_equal(0)
