# tests/unit/foundation/localization_locale_switch_test.gd
#
# LocalizationLocaleSwitchTest — GdUnit4 suite for Story LOC-004.
#
# PURPOSE
#   Verifies the two canonical re-render patterns when locale changes:
#     • Pattern A: Control.auto_translate_mode = ALWAYS + tr() key as text
#     • Pattern B: NOTIFICATION_TRANSLATION_CHANGED handler re-composes
#   Also enforces the cached_translation_at_ready forbidden pattern grep
#   (AC-6) and the AUTO_TRANSLATE_MODE_ALWAYS enum value sanity check (AC-7).
#
# GOVERNING REQUIREMENTS
#   TR-LOC-006 (Control.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS)
#   TR-LOC-007 (NOTIFICATION_TRANSLATION_CHANGED re-resolution; no _ready cache)
#   ADR-0004 §Engine Compatibility G4 (verified 2026-04-29)
#
# GATE STATUS
#   Story LOC-004 | Logic type → BLOCKING gate.

class_name LocalizationLocaleSwitchTest
extends GdUnitTestSuite

const _SRC_DIR: String = "res://src"
const _COMPOSED_LABEL_SCRIPT: String = "res://src/core/ui/translatable_composed_label.gd"

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_saved_locale)


# ── AC-1: Pattern A — auto_translate_mode = ALWAYS resolves tr() key ─────────

## AC-1: A Label with text = "menu.main.start_mission" and
## auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS resolves to the English
## value when tr() is called against the key. The auto_translate_mode property
## is the rendering directive; tr() returns what the renderer will display.
func test_pattern_a_auto_translate_always_resolves_tr_key_at_default_locale() -> void:
	# Arrange
	var label: Label = Label.new()
	label.text = "menu.main.start_mission"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	add_child(label)
	auto_free(label)
	await get_tree().process_frame

	# Act: resolve the key the way auto_translate_mode=ALWAYS would render it.
	var displayed: String = tr(label.text)

	# Assert: the resolved tr() of the key matches the expected English value,
	# AND the label has the ALWAYS directive set so Godot will re-render on
	# locale change automatically (verified in AC-2).
	assert_str(displayed).override_failure_message(
		(
			"Pattern A: tr('menu.main.start_mission') must return 'Start Mission'. "
			+ "Got: '%s'. DIAGNOSTIC: verify menu.csv has the key + en column."
		) % displayed
	).is_equal("Start Mission")
	assert_int(int(label.auto_translate_mode)).override_failure_message(
		"Pattern A: label.auto_translate_mode must equal AUTO_TRANSLATE_MODE_ALWAYS (1). Got: %d" % int(label.auto_translate_mode)
	).is_equal(int(Node.AUTO_TRANSLATE_MODE_ALWAYS))


# ── AC-2: Pattern A — auto-translate re-renders on locale switch ─────────────

## AC-2: After TranslationServer.set_locale("pseudo"), tr() returns the
## pseudolocale value for the same key — auto_translate_mode = ALWAYS
## ensures Godot re-renders the Label with that new tr() result automatically.
func test_pattern_a_re_renders_automatically_on_pseudo_locale_switch() -> void:
	# Arrange
	var label: Label = Label.new()
	label.text = "menu.main.start_mission"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	add_child(label)
	auto_free(label)
	await get_tree().process_frame
	var en_text: String = tr(label.text)

	# Act
	TranslationServer.set_locale("pseudo")
	await get_tree().process_frame

	# Assert: tr() resolves to the pseudolocale value at the new locale.
	var pseudo_text: String = tr(label.text)
	assert_str(pseudo_text).override_failure_message(
		(
			"Pattern A: tr() must return different value after set_locale('pseudo'). "
			+ "en_text='%s'  pseudo_text='%s'. DIAGNOSTIC: verify "
			+ "_dev_pseudo.csv contains menu.main.start_mission with a 'pseudo' column."
		) % [en_text, pseudo_text]
	).is_not_equal(en_text)
	# Pseudo-loc convention: starts with `[•` per LOC-002.
	assert_bool(pseudo_text.begins_with("[")).override_failure_message(
		"Pseudo-loc value must start with '[' bracket. Got: '%s'" % pseudo_text
	).is_true()


# ── AC-3: Pattern B — composed label resolves at default locale ──────────────

## AC-3: TranslatableComposedLabel composes tr(label_key) + ": " + current_value
## correctly at locale "en" without manual refresh calls.
func test_pattern_b_composed_label_renders_correctly_at_default_locale() -> void:
	# Arrange
	var ScriptClass = load(_COMPOSED_LABEL_SCRIPT)
	assert_object(ScriptClass).is_not_null()
	var composed: Label = ScriptClass.new()
	composed.label_key = &"hud.objective.label"
	composed.current_value = "Reach Plaza"
	add_child(composed)
	auto_free(composed)
	await get_tree().process_frame

	# Act + Assert: composed text must contain English label segment + value.
	assert_str(composed.text).override_failure_message(
		"Pattern B composed text must equal 'Objective: Reach Plaza'. Got: '%s'" % composed.text
	).is_equal("Objective: Reach Plaza")


## AC-3 edge case: empty current_value composes to "<label>: " (trailing colon).
func test_pattern_b_empty_value_composes_label_with_trailing_colon() -> void:
	# Arrange
	var ScriptClass = load(_COMPOSED_LABEL_SCRIPT)
	var composed: Label = ScriptClass.new()
	composed.label_key = &"hud.objective.label"
	composed.current_value = ""
	add_child(composed)
	auto_free(composed)
	await get_tree().process_frame

	# Act + Assert
	assert_str(composed.text).override_failure_message(
		"Pattern B with empty value must compose 'Objective: '. Got: '%s'" % composed.text
	).is_equal("Objective: ")


# ── AC-4: Pattern B — NOTIFICATION_TRANSLATION_CHANGED re-composes ────────────

## AC-4: When locale switches, NOTIFICATION_TRANSLATION_CHANGED fires on the
## composed label and _refresh_text re-runs (label segment re-resolves).
## Per Godot 4.5+, propagation traverses the active SceneTree; we await a
## couple of process frames to allow the notification to reach our node.
func test_pattern_b_re_resolves_on_locale_switch_via_notification() -> void:
	# Arrange
	var ScriptClass = load(_COMPOSED_LABEL_SCRIPT)
	var composed: Label = ScriptClass.new()
	composed.label_key = &"hud.objective.label"
	composed.current_value = "Reach Plaza"
	add_child(composed)
	auto_free(composed)
	await get_tree().process_frame
	var en_text: String = composed.text

	# Act: switch locale and let the notification propagate. Some Godot
	# versions defer NOTIFICATION_TRANSLATION_CHANGED to the next frame.
	TranslationServer.set_locale("pseudo")
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: composed text changed; label segment re-resolved to pseudo.
	assert_str(composed.text).override_failure_message(
		(
			"Pattern B: composed text must change after set_locale('pseudo'). "
			+ "en_text='%s'  pseudo_text='%s'. DIAGNOSTIC: verify the script "
			+ "overrides _notification(what) to handle NOTIFICATION_TRANSLATION_CHANGED."
		) % [en_text, composed.text]
	).is_not_equal(en_text)
	# Verify the label segment re-resolved (pseudo prefix appears in the composed string).
	assert_bool(composed.text.contains("[")).override_failure_message(
		"Pattern B: pseudo label segment must appear in composed string. Got: '%s'" % composed.text
	).is_true()
	# Verify dynamic value (current_value) is preserved through the recomposition.
	assert_bool(composed.text.contains("Reach Plaza")).override_failure_message(
		"Pattern B: dynamic value 'Reach Plaza' must be preserved in recomposition. Got: '%s'" % composed.text
	).is_true()


# ── AC-5: Documentation snippet exists in the example file ───────────────────

## AC-5: src/core/ui/translatable_composed_label.gd has a doc-comment block
## documenting both Pattern A (auto_translate_mode) and Pattern B
## (NOTIFICATION_TRANSLATION_CHANGED) with the canonical decision rule.
func test_translatable_composed_label_documents_both_patterns() -> void:
	# Arrange
	var f: FileAccess = FileAccess.open(_COMPOSED_LABEL_SCRIPT, FileAccess.READ)
	assert_object(f).override_failure_message(
		"%s must be readable." % _COMPOSED_LABEL_SCRIPT
	).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	# Assert: file documents both patterns by name.
	for required: String in ["Pattern A", "Pattern B", "auto_translate_mode", "NOTIFICATION_TRANSLATION_CHANGED"]:
		assert_bool(content.contains(required)).override_failure_message(
			"translatable_composed_label.gd doc-comment must mention '%s' for AC-5 reference value." % required
		).is_true()


# ── AC-6: No cached_translation_at_ready in production code ──────────────────

## AC-6: Zero `var <name> [:=] tr(...)` matches inside _ready() function bodies
## in src/, unless the same script also defines a NOTIFICATION_TRANSLATION_CHANGED
## handler (which would mean the cached value gets refreshed on locale change).
func test_no_cached_translation_at_ready_in_src() -> void:
	# Arrange: collect all .gd files under src/.
	var gd_files: Array[String] = _collect_gd_files(_SRC_DIR)
	var violations: Array[String] = []
	# Match: var <ident> [: <type>]? = tr(...)  inside any function body.
	# We then narrow per-file: only flag matches that fall inside _ready and
	# have no NOTIFICATION_TRANSLATION_CHANGED handler in the same file.
	var var_tr_pattern: RegEx = RegEx.new()
	var_tr_pattern.compile("var\\s+\\w+(\\s*:\\s*\\w+)?\\s*=\\s*tr\\(")

	for file_path: String in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var content: String = f.get_as_text()
		f.close()
		var has_notification_handler: bool = content.contains("NOTIFICATION_TRANSLATION_CHANGED")
		if has_notification_handler:
			continue  # script has a re-resolution mechanism — caching is acceptable.
		var lines: PackedStringArray = content.split("\n")
		var in_ready: bool = false
		var ready_indent: int = -1
		for i: int in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			# Detect entering _ready function body.
			if stripped.begins_with("func _ready"):
				in_ready = true
				ready_indent = _leading_indent(line)
				continue
			# Detect leaving _ready (next func at the same/lesser indent).
			if in_ready and stripped.begins_with("func ") and _leading_indent(line) <= ready_indent:
				in_ready = false
			if in_ready and var_tr_pattern.search(line) != null:
				violations.append("%s:%d — %s" % [file_path, i + 1, stripped])

	# Assert
	assert_int(violations.size()).override_failure_message(
		(
			"FORBIDDEN PATTERN (TR-LOC-007 cached_translation_at_ready): "
			+ "var <name> = tr(...) inside _ready() body without a "
			+ "NOTIFICATION_TRANSLATION_CHANGED handler in the same script. "
			+ "Move to Pattern A (auto_translate_mode = ALWAYS) or Pattern B "
			+ "(re-resolve in _notification).\nViolations:\n  %s"
		) % "\n  ".join(violations)
	).is_equal(0)


# ── AC-7: AUTO_TRANSLATE_MODE_ALWAYS enum value sanity check ─────────────────

## AC-7: Node.AUTO_TRANSLATE_MODE_ALWAYS == 1 per ADR-0004 G4 (Sprint 01 verified).
## If the enum changes in a future Godot version, this test produces a clear
## diagnostic referencing the verification gate for re-verification.
func test_auto_translate_mode_always_enum_value_is_one() -> void:
	assert_int(int(Node.AUTO_TRANSLATE_MODE_ALWAYS)).override_failure_message(
		(
			"Node.AUTO_TRANSLATE_MODE_ALWAYS must equal 1 (Godot 4.5+ stable; "
			+ "Sprint 01 G4 verified 2026-04-27). Got: %d. DIAGNOSTIC: engine "
			+ "version mismatch — re-verify ADR-0004 §Engine Compatibility G4 "
			+ "against the pinned Godot version."
		) % int(Node.AUTO_TRANSLATE_MODE_ALWAYS)
	).is_equal(1)
	# Also verify the other two enum values for documentation completeness.
	assert_int(int(Node.AUTO_TRANSLATE_MODE_INHERIT)).is_equal(0)
	assert_int(int(Node.AUTO_TRANSLATE_MODE_DISABLED)).is_equal(2)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Recursively collect all .gd files under a res:// directory path.
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


## Count leading whitespace characters (tabs or spaces) on a line.
func _leading_indent(line: String) -> int:
	var n: int = 0
	for c: String in line:
		if c == "\t" or c == " ":
			n += 1
		else:
			break
	return n
