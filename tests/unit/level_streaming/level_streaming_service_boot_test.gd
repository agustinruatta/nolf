# tests/unit/level_streaming/level_streaming_service_boot_test.gd
#
# LevelStreamingServiceBootTest — GdUnit4 suite for Story LS-001 (autoload boot).
#
# Covers AC-1 (class shape), AC-2 (autoload registration), AC-3 (SectionRegistry
# class), AC-4 (.tres entries), AC-5 (registry load + validity flag), AC-6
# (FadeOverlay setup), AC-7 (ErrorFallback layer + preload), AC-8 (.tscn
# loadable), AC-9 (cross-autoload reference safety — static grep), AC-10
# (autoload + fade survive scene transitions).
#
# GATE STATUS
#   Story LS-001 | Logic type → BLOCKING gate.
#   TR-LS-001, TR-LS-002, TR-LS-004, TR-LS-012.

class_name LevelStreamingServiceBootTest
extends GdUnitTestSuite

const _LSS_PATH: String = "res://src/core/level_streaming/level_streaming_service.gd"
const _REGISTRY_TRES: String = "res://assets/data/section_registry.tres"
const _ERROR_FALLBACK_TSCN: String = "res://scenes/ErrorFallback.tscn"
const _PROJECT_GODOT: String = "res://project.godot"


# ── AC-1: LevelStreamingService class shape ──────────────────────────────────

func test_lss_has_transition_reason_enum_with_4_members() -> void:
	# The autoload is loaded as a Node — TransitionReason is on the script.
	# Access via the singleton path.
	assert_int(LevelStreamingService.TransitionReason.FORWARD).is_equal(0)
	assert_int(LevelStreamingService.TransitionReason.RESPAWN).is_equal(1)
	assert_int(LevelStreamingService.TransitionReason.NEW_GAME).is_equal(2)
	assert_int(LevelStreamingService.TransitionReason.LOAD_FROM_SAVE).is_equal(3)


# ── AC-2: Autoload registered at line 5 ──────────────────────────────────────

func test_project_godot_registers_lss_at_autoload_line_5() -> void:
	var f: FileAccess = FileAccess.open(_PROJECT_GODOT, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	# Find the [autoload] block.
	var autoload_idx: int = content.find("[autoload]")
	assert_int(autoload_idx).override_failure_message(
		"project.godot must contain an [autoload] block."
	).is_greater_equal(0)
	var autoload_section: String = content.substr(autoload_idx)
	# Take just the autoload section (until next [section] header).
	var next_section: int = autoload_section.find("\n[", 1)
	if next_section > 0:
		autoload_section = autoload_section.substr(0, next_section)

	# Parse line-by-line for the named entries in expected order.
	var lines: PackedStringArray = autoload_section.split("\n")
	var entries: Array[String] = []
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped == "" or stripped.begins_with("[") or stripped.begins_with("#"):
			continue
		# Lines like `Events="*res://..."`.
		var eq_idx: int = stripped.find("=")
		if eq_idx > 0:
			entries.append(stripped.substr(0, eq_idx))

	# ADR-0007 §Key Interfaces: lines 1-5 must be Events / EventLogger / SaveLoad
	# / InputContext / LevelStreamingService.
	assert_int(entries.size()).override_failure_message(
		"Expected at least 5 autoload entries. Got: %s" % [entries]
	).is_greater_equal(5)
	assert_str(entries[0]).is_equal("Events")
	assert_str(entries[1]).is_equal("EventLogger")
	assert_str(entries[2]).is_equal("SaveLoad")
	assert_str(entries[3]).is_equal("InputContext")
	assert_str(entries[4]).override_failure_message(
		"Autoload line 5 must be 'LevelStreamingService' per ADR-0007. Got: %s" % entries[4]
	).is_equal("LevelStreamingService")


func test_lss_autoload_uses_scene_mode_prefix() -> void:
	var f: FileAccess = FileAccess.open(_PROJECT_GODOT, FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	# The line must contain `LevelStreamingService="*res://...`. The asterisk
	# is the scene-mode prefix (per ADR-0007 IG 2). Without it, Godot loads in
	# script mode which cannot set up the fade overlay properly.
	assert_str(content).override_failure_message(
		"LSS autoload entry must use scene-mode prefix '*res://'."
	).contains("LevelStreamingService=\"*res://")


# ── AC-3: SectionRegistry class shape ────────────────────────────────────────

func test_section_registry_class_basic_shape() -> void:
	var reg: SectionRegistry = SectionRegistry.new()
	assert_int(reg.sections.size()).override_failure_message(
		"Default-constructed SectionRegistry must have empty sections dict."
	).is_equal(0)
	assert_bool(reg.has_section(&"nonexistent")).is_false()
	assert_str(reg.path(&"nonexistent")).is_equal("")
	assert_str(reg.display_name_loc_key(&"nonexistent")).is_equal("")


# ── AC-4: section_registry.tres has plaza + stub_b entries ───────────────────

func test_section_registry_tres_has_plaza_and_stub_b() -> void:
	var loaded: Resource = ResourceLoader.load(_REGISTRY_TRES)
	assert_object(loaded).override_failure_message(
		"section_registry.tres must load."
	).is_not_null()
	assert_bool(loaded is SectionRegistry).override_failure_message(
		"Loaded resource must be a SectionRegistry. Got: %s" % loaded.get_class()
	).is_true()
	var registry: SectionRegistry = loaded as SectionRegistry

	assert_bool(registry.has_section(&"plaza")).override_failure_message(
		"Registry must contain &'plaza' entry."
	).is_true()
	assert_bool(registry.has_section(&"stub_b")).override_failure_message(
		"Registry must contain &'stub_b' entry."
	).is_true()
	assert_str(registry.path(&"plaza")).override_failure_message(
		"plaza path must be non-empty."
	).is_not_empty()
	assert_str(registry.display_name_loc_key(&"plaza")).override_failure_message(
		"plaza display_name_loc_key must be non-empty."
	).is_not_empty()


# ── AC-5: Registry load + validity flag ──────────────────────────────────────

func test_lss_loads_registry_and_sets_valid_flag() -> void:
	# The autoload's _ready() ran on game start. By the time this test runs,
	# the registry should be loaded.
	assert_bool(LevelStreamingService.has_valid_registry()).override_failure_message(
		"LSS must report _registry_valid=true after successful load."
	).is_true()
	var registry: SectionRegistry = LevelStreamingService.get_registry()
	assert_object(registry).override_failure_message(
		"LSS.get_registry() must return non-null after successful load."
	).is_not_null()


# ── AC-6: Fade overlay setup ─────────────────────────────────────────────────

func test_fade_overlay_canvaslayer_127_with_colorrect() -> void:
	var overlay: CanvasLayer = LevelStreamingService.get_fade_overlay()
	assert_object(overlay).override_failure_message(
		"FadeOverlay CanvasLayer must exist as a child of the LSS autoload."
	).is_not_null()
	assert_int(overlay.layer).override_failure_message(
		"FadeOverlay must use CanvasLayer.layer = 127 (max signed-8-bit). Got: %d" % overlay.layer
	).is_equal(127)
	# Inspect the ColorRect child.
	var rect: ColorRect = null
	for child: Node in overlay.get_children():
		if child is ColorRect:
			rect = child as ColorRect
			break
	assert_object(rect).override_failure_message(
		"FadeOverlay must contain a ColorRect child."
	).is_not_null()
	assert_bool(rect.color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.0))).override_failure_message(
		"FadeRect default color must be Color(0,0,0,0). Got: %s" % [rect.color]
	).is_true()


# ── AC-7: ErrorFallback layer setup + preload ────────────────────────────────

func test_error_fallback_canvaslayer_126() -> void:
	var layer: CanvasLayer = LevelStreamingService.get_error_fallback_layer()
	assert_object(layer).override_failure_message(
		"ErrorFallbackLayer CanvasLayer must exist."
	).is_not_null()
	assert_int(layer.layer).override_failure_message(
		"ErrorFallbackLayer must use layer 126 (one below FadeOverlay). Got: %d" % layer.layer
	).is_equal(126)
	# At LS-001 scaffold time, no instance is mounted under the layer — Story
	# LS-005 mounts the ErrorFallback scene on transition abort.
	assert_int(layer.get_child_count()).override_failure_message(
		"ErrorFallbackLayer must have NO child nodes at scaffold boot. Got: %d" % layer.get_child_count()
	).is_equal(0)


# ── AC-8: ErrorFallback.tscn is loadable ─────────────────────────────────────

func test_error_fallback_tscn_loads_and_instantiates() -> void:
	var loaded: Resource = ResourceLoader.load(_ERROR_FALLBACK_TSCN)
	assert_object(loaded).override_failure_message(
		"ErrorFallback.tscn must load."
	).is_not_null()
	assert_bool(loaded is PackedScene).override_failure_message(
		"Loaded resource must be PackedScene."
	).is_true()
	var packed: PackedScene = loaded as PackedScene
	var instance: Node = packed.instantiate()
	assert_object(instance).override_failure_message(
		"ErrorFallback.tscn must instantiate without error."
	).is_not_null()
	assert_bool(instance is Control).override_failure_message(
		"ErrorFallback root must be a Control node."
	).is_true()
	instance.free()


# ── AC-9: Cross-autoload reference safety — static grep ──────────────────────

func test_lss_init_references_no_autoloads() -> void:
	var f: FileAccess = FileAccess.open(_LSS_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	# Find any `_init` function declaration; if present, scan its body.
	# This implementation has no _init; the test passes by absence.
	# If a future revision adds _init, the body must not reference the named
	# autoloads.
	var init_idx: int = content.find("func _init(")
	if init_idx < 0:
		# No _init defined — vacuously safe. Pass.
		assert_bool(true).is_true()
		return
	# Extract the function body by scanning forward to the next top-level
	# `func` declaration.
	var body_start: int = content.find("\n", init_idx) + 1
	var next_func: int = content.find("\nfunc ", body_start)
	var body: String = content.substr(body_start, next_func - body_start) if next_func > 0 else content.substr(body_start)
	# Forbidden references in _init.
	var forbidden_autoloads: Array[String] = [
		"Events.", "EventLogger.", "SaveLoad.", "InputContext.",
		"PostProcessStack.", "Combat.", "FailureRespawn.",
		"MissionLevelScripting.", "SettingsService."
	]
	for tok: String in forbidden_autoloads:
		assert_bool(tok in body).override_failure_message(
			"LSS _init() must not reference autoload '%s'." % tok
		).is_false()


func test_lss_ready_does_not_reference_later_autoloads() -> void:
	var f: FileAccess = FileAccess.open(_LSS_PATH, FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	# Forbidden in _ready: autoloads at line 6+.
	# (Line 5 is THIS autoload; lines 1-4 are the safe consumption set.)
	var forbidden_later: Array[String] = [
		"PostProcessStack.", "Combat.", "FailureRespawn.",
		"MissionLevelScripting.", "SettingsService."
	]
	# Quick scan: _ready body extraction.
	var ready_idx: int = content.find("func _ready(")
	if ready_idx < 0:
		assert_bool(false).override_failure_message(
			"LSS must define _ready()."
		).is_true()
		return
	var body_start: int = content.find("\n", ready_idx) + 1
	var next_func: int = content.find("\nfunc ", body_start)
	var body: String = content.substr(body_start, next_func - body_start) if next_func > 0 else content.substr(body_start)
	for tok: String in forbidden_later:
		assert_bool(tok in body).override_failure_message(
			"LSS _ready() must not reference later autoload '%s' per ADR-0007 IG 4." % tok
		).is_false()


# ── AC-10: Autoload + fade overlay survive scene transitions ─────────────────

func test_lss_persists_across_test_lifecycle() -> void:
	# The autoload is alive throughout the test session — by the time this
	# test runs, it has already survived the test framework's scene swaps
	# (each test suite gets its own scene tree). If the autoload were
	# misconfigured (e.g., mode='node' instead of '*res://'), this query
	# would fail.
	assert_bool(is_instance_valid(LevelStreamingService)).override_failure_message(
		"LevelStreamingService autoload must be valid throughout the test lifecycle."
	).is_true()
	# Fade overlay still attached.
	assert_object(LevelStreamingService.get_fade_overlay()).override_failure_message(
		"FadeOverlay must persist alongside the autoload."
	).is_not_null()
