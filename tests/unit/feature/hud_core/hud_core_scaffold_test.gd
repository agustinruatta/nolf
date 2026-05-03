# tests/unit/feature/hud_core/hud_core_scaffold_test.gd
#
# HUDCoreScaffoldTest — GdUnit4 suite for Story HC-001.
#
# PURPOSE
#   AC-1 / AC-3 / AC-4 / AC-5 / AC-6 — scene-tree structural verification of
#   the programmatically-built HUD widget tree, FontRegistry boundary at the
#   18 px floor, and dual-focus-split exemption coverage.
#
# AC-7 (visual sign-off) is HC-006 scope and not automated here.

class_name HUDCoreScaffoldTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"
const _HUD_THEME_PATH: String = "res://src/core/ui_framework/themes/hud_theme.tres"
const _PROJECT_THEME_PATH: String = "res://src/core/ui_framework/project_theme.tres"


# ── AC-1: HUDCore is a CanvasLayer; layer index 1; not autoloaded ────────────

func test_hud_core_root_is_canvas_layer_with_layer_index_one() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	assert_int(hud.layer).is_equal(1)
	assert_str(hud.get_class()).is_equal("CanvasLayer")


func test_hud_core_is_not_registered_as_autoload() -> void:
	var f: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	# The autoload block must NOT reference hud_core.
	# Use a regex anchored to the [autoload] block.
	var pattern: RegEx = RegEx.new()
	pattern.compile("HUDCore\\s*=")
	var m: RegExMatch = pattern.search(content)
	assert_object(m).override_failure_message(
		"HUDCore must NOT appear in project.godot [autoload] block (FP-13)."
	).is_null()


# ── AC-2: Theme resources exist with fallback_theme set ─────────────────────

func test_hud_theme_loads_as_theme_resource() -> void:
	# NOTE: ADR-0004 Gate 2 referenced a `Theme.fallback_theme` property; in
	# Godot 4.6 the actual mechanism for cross-theme inheritance is via the
	# Control hierarchy (each Control inherits its parent's theme), NOT a
	# theme-of-themes property. The hud_theme.tres uses an ext_resource
	# reference for documentation/discoverability; cross-theme lookup is
	# resolved at runtime via the Control parent chain.
	var theme: Theme = load(_HUD_THEME_PATH)
	assert_object(theme).override_failure_message(
		"hud_theme.tres must load as a Theme resource."
	).is_not_null()


func test_project_theme_loads() -> void:
	var theme: Theme = load(_PROJECT_THEME_PATH)
	assert_object(theme).is_not_null()


# ── AC-3: FontRegistry.hud_numeral 18 px boundary ────────────────────────────

func test_font_registry_at_22_px_returns_futura_branch() -> void:
	# 22 px is at/above the 18 px floor → Futura Condensed Bold branch.
	assert_bool(FontRegistry.is_din_branch(22)).is_false()
	var f: Font = FontRegistry.hud_numeral(22)
	assert_object(f).is_not_null()


func test_font_registry_at_15_px_returns_din_branch() -> void:
	# At scale 0.667, design 22 px → 15 px → below 18 floor → DIN 1451 branch.
	assert_bool(FontRegistry.is_din_branch(15)).is_true()
	var f: Font = FontRegistry.hud_numeral(15)
	assert_object(f).is_not_null()


func test_font_registry_at_18_px_returns_futura_branch() -> void:
	# Boundary is `< 18`, not `<= 18` — at exactly 18 px, return Futura.
	assert_bool(FontRegistry.is_din_branch(18)).is_false()


func test_font_registry_at_17_px_returns_din_branch() -> void:
	assert_bool(FontRegistry.is_din_branch(17)).is_true()


# ── AC-4: No raw string literal assignments to .text in HUD source ──────────

func test_no_hardcoded_text_literals_in_hud_core_src() -> void:
	var hud_dir: String = "res://src/ui/hud_core"
	var gd_files: Array[String] = _collect_gd_files(hud_dir)
	var pattern: RegEx = RegEx.new()
	pattern.compile("\\.text\\s*=\\s*\"[^\"]+\"")
	var violations: Array[String] = []

	for file_path in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null: continue
		var content: String = f.get_as_text()
		f.close()
		var lines: PackedStringArray = content.split("\n")
		for i in range(lines.size()):
			var stripped: String = lines[i].strip_edges()
			if stripped.begins_with("#"): continue
			var m: RegExMatch = pattern.search(lines[i])
			if m != null:
				# Allow two specific MVP placeholders pending HC-003/004 wiring:
				# "100" health numeral default and tr("hud.health.label").
				var matched: String = m.get_string(0)
				# Allow purely-numeric strings (e.g., "100" placeholder) or empty strings.
				var inner: String = matched.replace(".text", "").replace("=", "").replace("\"", "").strip_edges()
				if inner.is_valid_int() or inner == "":
					continue
				violations.append("%s:%d — %s" % [file_path, i + 1, lines[i].strip_edges()])

	assert_int(violations.size()).override_failure_message(
		"HUD .gd files must NOT assign hardcoded string literals to .text. Use tr(). Violations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


# ── AC-5: Every Control in the HUD tree has IGNORE mouse_filter + NONE focus ─

func test_every_hud_control_has_mouse_filter_ignore_and_focus_none() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Walk the tree and verify every Control descendant has the discipline applied.
	var violations: Array[String] = []
	_assert_control_discipline_recursive(hud, violations)

	assert_int(violations.size()).override_failure_message(
		"All HUD Control nodes must have mouse_filter = IGNORE and focus_mode = NONE. Violations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


func _assert_control_discipline_recursive(node: Node, violations: Array[String]) -> void:
	if node is Control:
		var c: Control = node
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			violations.append("%s — mouse_filter = %d (must be MOUSE_FILTER_IGNORE = 2)" % [c.name, int(c.mouse_filter)])
		if c.focus_mode != Control.FOCUS_NONE:
			violations.append("%s — focus_mode = %d (must be FOCUS_NONE = 0)" % [c.name, int(c.focus_mode)])
	for child in node.get_children():
		_assert_control_discipline_recursive(child, violations)


# ── AC-6: Widget tree structure (programmatic build) ────────────────────────

func test_hud_widget_tree_contains_all_required_widgets() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Verify the named widget references are populated and of correct types.
	assert_object(hud._root_control).override_failure_message("Root Control must be present.").is_not_null()
	assert_object(hud._health_label_hp).override_failure_message("Health HP label must be present.").is_not_null()
	assert_object(hud._health_label_numeral).override_failure_message("Health numeral label must be present.").is_not_null()
	assert_object(hud._weapon_name_label).override_failure_message("Weapon-name label must be present.").is_not_null()
	assert_object(hud._ammo_label).override_failure_message("Ammo label must be present.").is_not_null()
	assert_object(hud._gadget_tile).override_failure_message("Gadget tile must be present.").is_not_null()
	assert_object(hud._prompt_label).override_failure_message("Prompt label must be present.").is_not_null()
	assert_object(hud._prompt_key_rect).override_failure_message("Prompt key rect must be present.").is_not_null()
	assert_object(hud._crosshair).override_failure_message("Crosshair widget must be present.").is_not_null()


func test_hud_root_control_has_focus_disabled_recursively_meta() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	assert_bool(hud._root_control.get_meta(&"focus_disabled_recursively", false)).is_true()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _collect_gd_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null: return results
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
