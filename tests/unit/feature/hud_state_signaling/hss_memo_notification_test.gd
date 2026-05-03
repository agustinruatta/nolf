# tests/unit/feature/hud_state_signaling/hss_memo_notification_test.gd
#
# HSSMemoNotificationTest — GdUnit4 suite for Story HSS-003.
#
# PURPOSE
#   AC-MEMO-1..AC-MEMO-9 — document_collected toast, priority dispatch,
#   single-deep queue, freshness window discard, ui_context kill,
#   subscriber lifecycle.

class_name HSSMemoNotificationTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"
const _HSS_SCRIPT: String = "res://src/ui/hud_state_signaling.gd"


func _spawn_hss() -> Node:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	return hss


# ── AC-MEMO-1: Direct activation when no higher-priority state is active ────

func test_document_collected_activates_memo_state_when_idle() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	hss._on_document_collected(&"plaza_dossier")

	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.MEMO_NOTIFICATION))
	assert_bool(hss._memo_timer.is_stopped()).is_false()
	assert_bool(hss._current_text.contains("plaza_dossier")).is_true()


# ── AC-MEMO-2: ALERT_CUE active → MEMO queued, ALERT text unchanged ─────────

func test_document_collected_queues_memo_when_alert_active() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	# Set ALERT_CUE active.
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	var alert_text: String = hss._current_text

	# Document collected — must queue, not override.
	hss._on_document_collected(&"queued_doc")

	# Current state is still ALERT_CUE.
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.ALERT_CUE))
	assert_str(hss._current_text).is_equal(alert_text)
	# Queue populated.
	assert_str(String(hss._queued_memo_doc_id)).is_equal("queued_doc")
	assert_float(hss._queued_memo_at_time).is_greater_equal(0.0)


# ── AC-MEMO-3: Queued MEMO promoted on ALERT_CUE expiry within freshness ────

func test_queued_memo_activates_when_alert_cue_dismisses_within_freshness() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	hss._on_document_collected(&"fresh_doc")
	# Pre-condition: queued.
	assert_str(String(hss._queued_memo_doc_id)).is_equal("fresh_doc")

	# Simulate ALERT_CUE timer expiry.
	hss._on_alert_cue_dismissed()

	# MEMO should now be active.
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.MEMO_NOTIFICATION))
	assert_bool(hss._current_text.contains("fresh_doc")).is_true()
	# Queue cleared.
	assert_str(String(hss._queued_memo_doc_id)).is_equal("")


# ── AC-MEMO-4: Queued MEMO discarded when freshness window expires ──────────

func test_stale_queued_memo_is_discarded_on_alert_cue_dismiss() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	# Manually set a queued MEMO that's "stale" (older than 5.0s).
	hss._queued_memo_doc_id = &"stale_doc"
	hss._queued_memo_at_time = (float(Time.get_ticks_msec()) / 1000.0) - 10.0
	hss._current_state = hss.HSSState.ALERT_CUE
	hss._current_text = "Alerted"

	# ALERT_CUE dismisses.
	hss._on_alert_cue_dismissed()

	# MEMO must be discarded → state HIDDEN, queue cleared.
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_str(String(hss._queued_memo_doc_id)).is_equal("")


# ── AC-MEMO-5: empty document_id is rejected ────────────────────────────────

func test_empty_document_id_is_rejected() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	hss._on_document_collected(&"")

	# State unchanged.
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_bool(hss._memo_timer.is_stopped()).is_true()


# ── AC-MEMO-6: ui_context leave kills MEMO + clears queue ───────────────────

func test_ui_context_leave_kills_memo_and_clears_queue() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	hss._on_document_collected(&"to_kill")
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.MEMO_NOTIFICATION))

	hss._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))

	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_bool(hss._memo_timer.is_stopped()).is_true()
	assert_str(String(hss._queued_memo_doc_id)).is_equal("")


# ── AC-MEMO-7: HSS still emits zero signals after HSS-003 work ──────────────

func test_hss_emits_zero_signals_after_memo_notification_added() -> void:
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


# ── AC-MEMO-8: document_collected subscription lifecycle ────────────────────

func test_document_collected_subscribed_in_ready_and_disconnected_in_exit() -> void:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	await get_tree().process_frame

	assert_bool(Events.document_collected.is_connected(hss._on_document_collected)).is_true()

	remove_child(hss)
	await get_tree().process_frame
	assert_bool(Events.document_collected.is_connected(hss._on_document_collected)).is_false()
	hss.free()


# ── AC-MEMO-9: memo timer wait_time matches the GDD §G.1 default ───────────

func test_memo_timer_wait_time_is_3_seconds() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	assert_float(hss._memo_timer.wait_time).is_equal(3.0)
