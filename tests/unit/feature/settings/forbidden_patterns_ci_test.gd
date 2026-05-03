# tests/unit/feature/settings/forbidden_patterns_ci_test.gd
#
# SettingsForbiddenPatternsCITest — GdUnit4 suite for Story SA-001.
#
# PURPOSE
#   AC-2 / AC-3 / AC-4 / AC-8 — static-analysis CI gates for Settings &
#   Accessibility forbidden patterns.
#
#   FP-1 (AC-2): Events.setting_changed.emit only inside settings_service.gd
#   FP-2 (AC-3): ConfigFile.{load,save}("user://settings.cfg") only inside
#                settings_service.gd
#   FP-4 (AC-4): No settings key name appears in SaveGame capture/restore paths
#   FP-5/6 (AC-8): _on_setting_changed handlers must (a) early-return on
#                  category mismatch, (b) NOT contain `else:` in match name
#
# Method
#   Pure file-system scan + regex grep. No engine state required. Tests run
#   alongside other unit tests but enforce CI-blocking discipline.

class_name SettingsForbiddenPatternsCITest
extends GdUnitTestSuite

const _SRC_DIR: String = "res://src"
const _SETTINGS_SERVICE_PATH: String = "res://src/core/settings/settings_service.gd"
const _SAVE_LOAD_DIR: String = "res://src/core/save_load"

## Settings key names that must NOT appear in SaveGame capture/restore paths.
const _SETTINGS_KEY_NAMES: Array[String] = [
	"master_volume_db",
	"music_volume_db",
	"sfx_volume_db",
	"ambient_volume_db",
	"voice_volume_db",
	"ui_volume_db",
	"damage_flash_enabled",
	"damage_flash_cooldown_ms",
	"crosshair_enabled",
	"photosensitivity_warning_dismissed",
	"subtitles_enabled",
	"subtitle_size_scale",
	"subtitle_background",
	"subtitle_speaker_labels",
	"subtitle_line_spacing_scale",
	"subtitle_letter_spacing_em",
	"clock_tick_enabled",
	"sprint_is_toggle",
	"crouch_is_toggle",
	"ads_is_toggle",
	"mouse_sensitivity_x",
	"mouse_sensitivity_y",
	"gamepad_look_sensitivity",
	"invert_y_axis",
]


# ── AC-2 / FP-1: setting_changed sole publisher ─────────────────────────────

## AC-2 / FP-1: Events.setting_changed.emit(...) MAY appear only in
## settings_service.gd. Any other src/ file with a non-comment match fails.
func test_fp1_setting_changed_sole_publisher_in_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	var pattern: RegEx = RegEx.new()
	pattern.compile("Events\\.setting_changed\\.emit\\(")

	for file_path: String in gd_files:
		if file_path == _SETTINGS_SERVICE_PATH:
			continue
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if pattern.search(line) != null:
				violations.append("%s:%d — %s" % [file_path, i + 1, stripped])

	assert_int(violations.size()).override_failure_message(
		(
			"FP-1 sole-publisher violation (TR-SET-001): Events.setting_changed.emit(...) "
			+ "may only appear in settings_service.gd. Violations:\n  %s"
		) % "\n  ".join(violations)
	).is_equal(0)


# ── AC-3 / FP-2: settings.cfg sole reader/writer ────────────────────────────

## AC-3 / FP-2: ConfigFile.load("user://settings.cfg") and
## ConfigFile.save("user://settings.cfg") may appear only in settings_service.gd.
func test_fp2_settings_cfg_sole_reader_writer_in_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	# Match: ConfigFile usage with the settings.cfg path. Settings_service uses a
	# constant _SETTINGS_PATH, so it doesn't have a literal match — we look for
	# the literal "user://settings.cfg" string in src/ outside the service.
	var settings_path_literal: String = "user://settings.cfg"

	for file_path: String in gd_files:
		if file_path == _SETTINGS_SERVICE_PATH:
			continue
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.contains(settings_path_literal):
				violations.append("%s:%d — %s" % [file_path, i + 1, stripped])

	assert_int(violations.size()).override_failure_message(
		(
			"FP-2 sole-reader/writer violation (TR-SET-003): 'user://settings.cfg' literal "
			+ "may only appear in settings_service.gd. Violations:\n  %s"
		) % "\n  ".join(violations)
	).is_equal(0)


# ── AC-4 / FP-4: No settings keys in SaveGame paths ─────────────────────────

## AC-4 / FP-4: No settings key string literal may appear in any src/core/save_load/
## file. Catches accidental coupling of settings into the save domain.
func test_fp4_no_settings_keys_in_save_load_files() -> void:
	var save_load_files: Array[String] = _collect_gd_files(_SAVE_LOAD_DIR)
	var violations: Array[String] = []

	for file_path: String in save_load_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			for key_name: String in _SETTINGS_KEY_NAMES:
				# Match the string literal form "<key>" or &"<key>" — not substrings of
				# other tokens.
				var literal_double: String = "\"%s\"" % key_name
				var literal_string_name: String = "&\"%s\"" % key_name
				if stripped.contains(literal_double) or stripped.contains(literal_string_name):
					violations.append("%s:%d — settings key '%s' must not appear in save_load: %s" % [file_path, i + 1, key_name, stripped])
					break  # one violation per line is sufficient

	assert_int(violations.size()).override_failure_message(
		(
			"FP-4 settings-in-save-slot violation (TR-SET-014): no settings key name "
			+ "may appear in any src/core/save_load/ file. Violations:\n  %s"
		) % "\n  ".join(violations)
	).is_equal(0)


# ── AC-8 / FP-5+6: _on_setting_changed handler discipline ───────────────────

## AC-8 / FP-5: every _on_setting_changed handler's first non-comment statement
## (after the function declaration is fully parsed) must filter by category —
## either the early-return form `if category != &"<cat>": return` or the
## inline-filter form `if category == &"<cat>" and ...:` (semantically equivalent).
## AC-8 / FP-6: no `match name:` block inside _on_setting_changed may have an
## `else:` (or `_:`) clause — catch-all defeats type safety.
##
## Exceptions:
##   • event_logger.gd — debug logger by design taps every category.
func test_fp5_fp6_setting_changed_handler_discipline() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var fp5_violations: Array[String] = []
	var fp6_violations: Array[String] = []
	# Exception list: files exempt from FP-5 (logger taps all categories).
	var fp5_exemptions: Array[String] = [
		"res://src/core/signal_bus/event_logger.gd",
	]

	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var is_exempt: bool = file_path in fp5_exemptions
		# Find _on_setting_changed function bodies and inspect them.
		var lines: PackedStringArray = content.split("\n")
		var i: int = 0
		while i < lines.size():
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if not stripped.begins_with("func _on_setting_changed"):
				i += 1
				continue
			var func_indent: int = _leading_indent(line)
			# Skip multi-line function signature continuation lines until we hit
			# the line ending in `) -> ...:` or just `) :` or just `):`.
			var sig_end: int = i
			while sig_end < lines.size():
				var sl: String = lines[sig_end].strip_edges()
				if sl.ends_with(":"):
					break
				sig_end += 1
			var body_start: int = sig_end + 1
			var body_end: int = lines.size()
			for j: int in range(body_start, lines.size()):
				var bline: String = lines[j]
				var bstripped: String = bline.strip_edges()
				if bstripped.begins_with("func ") and _leading_indent(bline) <= func_indent:
					body_end = j
					break
			var body_lines: PackedStringArray = PackedStringArray()
			for k: int in range(body_start, body_end):
				body_lines.append(lines[k])
			# FP-5 check: first non-comment, non-blank body statement.
			if not is_exempt:
				var first_stmt: String = ""
				for bline: String in body_lines:
					var bs: String = bline.strip_edges()
					if bs == "" or bs.begins_with("#"):
						continue
					first_stmt = bs
					break
				if first_stmt != "":
					# Accept any of:
					#   if category != &"<cat>": return                   (early-return single)
					#   if category != &"<a>" and category != &"<b>": return  (early-return dual)
					#   if category == &"<cat>" ...                       (inline-filter single)
					var fp5_early_return: RegEx = RegEx.new()
					fp5_early_return.compile("^if\\s+category\\s*!=\\s*&?\"[^\"]+\"")
					var fp5_inline_filter: RegEx = RegEx.new()
					fp5_inline_filter.compile("^if\\s+category\\s*==\\s*&?\"[^\"]+\"")
					var ok: bool = (
						fp5_early_return.search(first_stmt) != null
						or fp5_inline_filter.search(first_stmt) != null
					)
					if not ok:
						fp5_violations.append(
							(
								"%s:%d — _on_setting_changed first statement must filter by "
								+ "category (either 'if category != &\"<cat>\": return' or "
								+ "'if category == &\"<cat>\" ...'). Got: '%s'"
							) % [file_path, body_start + 1, first_stmt]
						)
			# FP-6 check: any `else:` or `_:` inside a `match name:` block.
			var in_match_name: bool = false
			var match_indent: int = -1
			for k: int in range(body_lines.size()):
				var bs: String = body_lines[k].strip_edges()
				if bs.begins_with("match name") or bs.begins_with("match name:"):
					in_match_name = true
					match_indent = _leading_indent(body_lines[k])
					continue
				if in_match_name:
					var line_indent: int = _leading_indent(body_lines[k])
					if bs != "" and line_indent <= match_indent:
						in_match_name = false
					if bs == "_:" or bs == "else:":
						fp6_violations.append(
							"%s:%d — _on_setting_changed match name block must NOT contain '%s' clause."
							% [file_path, body_start + k + 1, bs]
						)
			i = body_end

	assert_int(fp5_violations.size()).override_failure_message(
		"FP-5 violation (TR-SET-001): %s" % "\n  ".join(fp5_violations)
	).is_equal(0)
	assert_int(fp6_violations.size()).override_failure_message(
		"FP-6 violation (TR-SET-001): %s" % "\n  ".join(fp6_violations)
	).is_equal(0)


# ── AC-10 / FP-9: No await or call_deferred in _on_setting_changed ──────────

## SA-002 AC-10 / FP-9: burst-emit synchronicity requires every
## _on_setting_changed handler to complete inline. await + call_deferred
## defer work to a later frame; both break the synchronous-burst guarantee.
func test_fp9_no_await_or_call_deferred_in_setting_changed_handlers() -> void:
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	var await_pattern: RegEx = RegEx.new()
	await_pattern.compile("\\bawait\\b")
	var call_deferred_pattern: RegEx = RegEx.new()
	call_deferred_pattern.compile("\\bcall_deferred\\(")

	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content == "":
			continue
		var lines: PackedStringArray = content.split("\n")
		var i: int = 0
		while i < lines.size():
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if not stripped.begins_with("func _on_setting_changed"):
				i += 1
				continue
			var func_indent: int = _leading_indent(line)
			# Skip multi-line signature continuation.
			var sig_end: int = i
			while sig_end < lines.size():
				if lines[sig_end].strip_edges().ends_with(":"):
					break
				sig_end += 1
			var body_start: int = sig_end + 1
			var body_end: int = lines.size()
			for j: int in range(body_start, lines.size()):
				var bline: String = lines[j]
				var bstripped: String = bline.strip_edges()
				if bstripped.begins_with("func ") and _leading_indent(bline) <= func_indent:
					body_end = j
					break
			# Scan body for await + call_deferred.
			for k: int in range(body_start, body_end):
				var bline: String = lines[k]
				var bstripped: String = bline.strip_edges()
				if bstripped.begins_with("#"):
					continue
				if await_pattern.search(bline) != null:
					violations.append("%s:%d — `await` in _on_setting_changed: %s" % [file_path, k + 1, bstripped])
				if call_deferred_pattern.search(bline) != null:
					violations.append("%s:%d — `call_deferred(...)` in _on_setting_changed: %s" % [file_path, k + 1, bstripped])
			i = body_end

	assert_int(violations.size()).override_failure_message(
		(
			"FP-9 violation (TR-SET-005 burst synchronicity): _on_setting_changed handlers "
			+ "must complete inline. `await` and `call_deferred` defer work to a later frame "
			+ "and break the synchronous boot-burst contract.\nViolations:\n  %s"
		) % "\n  ".join(violations)
	).is_equal(0)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _read_file(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content: String = f.get_as_text()
	f.close()
	return content


func _collect_gd_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			results.append_array(_collect_gd_files(full_path))
		elif entry.ends_with(".gd"):
			results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


func _leading_indent(line: String) -> int:
	var n: int = 0
	for c: String in line:
		if c == "\t" or c == " ":
			n += 1
		else:
			break
	return n
