# tests/integration/feature/hud_core/hud_core_vs_smoke_test.gd
#
# HUDCoreVsSmokeTest — GdUnit4 integration suite for Story HC-006.
#
# PURPOSE
#   AC-1 / AC-7 / AC-8 architectural smoke + cross-story end-to-end signal
#   path: HUDCore + HUDStateSignaling instanced together, exercised through
#   the full HC-001..HC-005 + HSS-001..HSS-003 surface area.
#
#   Visual sign-off (AC-2/3/4/6) and Slot 7 perf measurement (AC-5) require
#   the actual Plaza VS scene + the Godot profiler — they are documented in
#   the evidence skeleton at
#   production/qa/evidence/hud_core/vs_smoke_evidence_skeleton.md
#   and produced manually by the developer running the Plaza scene.

class_name HUDCoreVsSmokeTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"
const _HSS_SCRIPT: String = "res://src/ui/hud_state_signaling.gd"


# ── AC-1: HUD + HSS instance together without errors ────────────────────────

func test_hud_and_hss_coexist_in_scene_without_errors() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)

	await get_tree().process_frame

	# Both alive + connected.
	assert_int(hud.layer).is_equal(1)
	assert_object(hss._label).is_not_null()
	assert_int(hud._resolver_extensions.size()).is_equal(1)


# ── AC-1 + Pillar 5: no minimap/marker tokens reach the HUD scene tree ─────

func test_hud_scene_tree_has_no_excluded_widget_names() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var excluded: Array[String] = ["minimap", "waypoint", "objective_marker", "radar", "compass_overlay"]
	var violations: Array[String] = []
	_walk_for_names(hud, excluded, violations)

	assert_int(violations.size()).override_failure_message(
		"FP-6 Pillar 2/5 violation — HUD scene must contain no excluded widget names. Violations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


func _walk_for_names(node: Node, excluded: Array[String], violations: Array[String]) -> void:
	var name_lower: String = String(node.name).to_lower()
	for token in excluded:
		if name_lower.contains(token):
			violations.append("%s — contains '%s'" % [node.name, token])
	for child in node.get_children():
		_walk_for_names(child, excluded, violations)


# ── End-to-end signal path: damage event → flash + critical-state ───────────

func test_damage_event_triggers_health_widget_flash() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Set baseline health.
	Events.player_health_changed.emit(100.0, 100.0)
	# Drop to critical via Events bus.
	Events.player_health_changed.emit(20.0, 100.0)

	assert_bool(hud._was_critical).is_true()

	# Damage event opens the rate-gate timer.
	Events.player_damaged.emit(10.0, null, false)
	assert_bool(hud._flash_timer.is_stopped()).is_false()


# ── End-to-end: alert → HSS → MEMO queued → ALERT timer dismiss → MEMO ─────

func test_alert_followed_by_doc_collected_promotes_memo_after_alert_dismiss() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	# Trigger ALERT_CUE.
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)
	Events.alert_state_changed.emit(
		actor,
		StealthAI.AlertState.UNAWARE,
		StealthAI.AlertState.SUSPICIOUS,
		StealthAI.Severity.MINOR
	)
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.ALERT_CUE))

	# Document collected → queued behind ALERT_CUE.
	Events.document_collected.emit(&"plaza_dossier")
	assert_str(String(hss._queued_memo_doc_id)).is_equal("plaza_dossier")
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.ALERT_CUE))

	# Simulate ALERT_CUE timer expiry → MEMO promoted.
	hss._on_alert_cue_dismissed()
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.MEMO_NOTIFICATION))
	assert_bool(hss._current_text.contains("plaza_dossier")).is_true()


# ── AC-7: ui_context kill propagates to both HUD and HSS ────────────────────

func test_ui_context_change_to_menu_hides_hud_and_clears_hss_state() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	# Activate HSS state, then change context.
	Events.document_collected.emit(&"to_kill")
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.MEMO_NOTIFICATION))

	Events.ui_context_changed.emit(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))

	# HUD root hidden + HSS state cleared.
	assert_bool(hud.visible).is_false()
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_bool(hud.is_processing()).is_false()


# ── AC-8: HUD Core is not in the autoload list ──────────────────────────────

func test_hud_core_is_not_listed_as_autoload() -> void:
	var f: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	var pattern: RegEx = RegEx.new()
	pattern.compile("(?m)^HUDCore\\s*=\\s*\"")
	var m: RegExMatch = pattern.search(content)
	assert_object(m).override_failure_message(
		"FP-13: HUD Core must NOT be registered as an autoload."
	).is_null()


# ── HSS subscriber-only posture preserved across all 3 stories ──────────────

func test_hss_emits_zero_signals_after_all_three_stories() -> void:
	var f: FileAccess = FileAccess.open(_HSS_SCRIPT, FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	var pattern: RegEx = RegEx.new()
	pattern.compile("Events\\.[a-zA-Z_]+\\.emit\\(")
	var lines: PackedStringArray = content.split("\n")
	var violations: Array[String] = []
	for i in range(lines.size()):
		var stripped: String = lines[i].strip_edges()
		if stripped.begins_with("#"): continue
		if pattern.search(lines[i]) != null:
			violations.append("hud_state_signaling.gd:%d — %s" % [i + 1, stripped])
	assert_int(violations.size()).is_equal(0)
