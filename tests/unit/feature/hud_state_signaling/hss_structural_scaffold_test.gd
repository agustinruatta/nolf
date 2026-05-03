# tests/unit/feature/hud_state_signaling/hss_structural_scaffold_test.gd
#
# HSSStructuralScaffoldTest — GdUnit4 suite for Story HSS-001.

class_name HSSStructuralScaffoldTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"
const _HSS_SCRIPT: String = "res://src/ui/hud_state_signaling.gd"


# ── AC-HSS-1.1: alert_state_changed connected exactly once after _ready ─────

func test_alert_state_changed_signal_connected_once_after_ready() -> void:
	# Need a HUD Core in the tree first per E.20.
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	assert_bool(Events.alert_state_changed.is_connected(hss._on_alert_state_changed)).is_true()
	# Exactly one connection per HSS instance.
	var conn_count: int = 0
	for c in Events.alert_state_changed.get_connections():
		if c.callable.get_object() == hss:
			conn_count += 1
	assert_int(conn_count).is_equal(1)


# ── AC-HSS-1.3: HSS holds Label + registered with HUD Core resolver ─────────

func test_hss_holds_label_and_registers_resolver_extension() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	assert_object(hss._label).override_failure_message(
		"HSS must hold a Label reference borrowed from HUDCore.get_prompt_label()."
	).is_not_null()
	# Resolver extension registered with HUD Core.
	assert_int(hud._resolver_extensions.size()).is_equal(1)


# ── AC-HSS-1.4: _exit_tree unregisters resolver + clears state ──────────────

func test_exit_tree_unregisters_resolver_and_clears_rate_gates() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	await get_tree().process_frame

	# Pre-condition: registered.
	assert_int(hud._resolver_extensions.size()).is_equal(1)
	# Pollute rate-gate dicts.
	hss._alert_cue_last_fired_per_actor[hss] = 0.0
	hss._alert_cue_last_state_per_actor[hss] = 0

	# Act: remove → triggers _exit_tree.
	remove_child(hss)
	await get_tree().process_frame

	# Assert: resolver extension unregistered + rate-gate dicts cleared.
	assert_int(hud._resolver_extensions.size()).is_equal(0)
	assert_int(hss._alert_cue_last_fired_per_actor.size()).is_equal(0)
	assert_int(hss._alert_cue_last_state_per_actor.size()).is_equal(0)
	assert_bool(Events.alert_state_changed.is_connected(hss._on_alert_state_changed)).is_false()
	hss.free()


# ── E.20: null-guard makes HSS inert if HUD Core absent ─────────────────────

func test_hss_disabled_when_hud_core_absent() -> void:
	# No HUD Core in tree.
	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	# Per E.20: HSS becomes inert (set_process disabled).
	assert_bool(hss.is_processing()).is_false()
	# No Label borrowed.
	assert_object(hss._label).is_null()
	# Not connected to events (null-guarded early-return).
	assert_bool(Events.alert_state_changed.is_connected(hss._on_alert_state_changed)).is_false()


# ── Subscriber-only posture (FP-HSS-8): HSS emits zero signals ──────────────

func test_hss_emits_zero_events_signals() -> void:
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
	assert_int(violations.size()).override_failure_message(
		"FP-HSS-8 subscriber-only: HSS must NOT emit Events signals.\nViolations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


# ── Resolver callback returns HIDDEN sentinel when no state active ──────────

func test_resolve_hss_state_returns_hidden_sentinel_when_inactive() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	var result: Dictionary = hss._resolve_hss_state()
	assert_str(String(result.get("text", "missing"))).is_equal("")
	assert_int(int(result.get("state_id", -1))).is_equal(int(hss.HSSState.HIDDEN))


# ── Context-leave clears HSS state immediately ──────────────────────────────

func test_context_leave_clears_hss_state() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	await get_tree().process_frame

	# Manually set an active state (simulate HSS-002 having fired).
	hss._current_state = hss.HSSState.ALERT_CUE
	hss._current_text = "Alerted!"

	# Context leave.
	hss._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))

	# State cleared.
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_str(hss._current_text).is_equal("")
