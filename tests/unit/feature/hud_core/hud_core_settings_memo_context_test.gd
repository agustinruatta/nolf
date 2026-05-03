# tests/unit/feature/hud_core/hud_core_settings_memo_context_test.gd
#
# HUDCoreSettingsMemoContextTest — GdUnit4 suite for Story HC-005.
#
# PURPOSE
#   AC-1 / AC-3 / AC-4 / AC-5 / AC-6 / AC-7 / AC-8 / AC-10 / AC-11 — settings
#   live-update wiring, locale invalidation, document-collected memo,
#   full context-hide with set_process toggle + Timer.stop, 15th connection.

class_name HUDCoreSettingsMemoContextTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"


# ── AC-1: Crosshair toggle responds to setting_changed ──────────────────────

func test_crosshair_toggle_responds_to_crosshair_enabled_setting() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Default: crosshair_enabled = true → mirror is true.
	assert_bool(hud._crosshair_enabled_mirror).is_true()

	# Disable.
	hud._on_setting_changed(&"accessibility", &"crosshair_enabled", false)
	assert_bool(hud._crosshair_enabled_mirror).is_false()
	assert_bool(hud._crosshair.visible).is_false()

	# Re-enable (HUD root visible — GAMEPLAY context).
	hud.visible = true
	hud._on_setting_changed(&"accessibility", &"crosshair_enabled", true)
	assert_bool(hud._crosshair_enabled_mirror).is_true()
	assert_bool(hud._crosshair.visible).is_true()


# ── AC-3: Locale change invalidates tr() caches ─────────────────────────────

func test_locale_change_invalidates_tr_caches() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Pre-populate the interact-key cache.
	hud._last_interact_label_key = &"hud.health.label"

	# Trigger a locale change.
	hud._on_setting_changed(&"language", &"locale", "fr")

	# Assert: cache invalidated (_last_interact_label_key reset).
	assert_str(String(hud._last_interact_label_key)).is_equal("")


# ── AC-4: Unknown category/key is silently ignored ──────────────────────────

func test_unknown_category_setting_change_is_silently_ignored() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# This must not crash or mutate any HUD state.
	hud._on_setting_changed(&"graphics", &"shadow_quality", 2)

	# Default mirrors unchanged.
	assert_bool(hud._crosshair_enabled_mirror).is_true()
	assert_bool(hud._flash_suppressed).is_false()


# ── AC-5: Pickup memo on document_collected ─────────────────────────────────

func test_document_collected_renders_memo_and_starts_timer() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	hud._on_document_collected(&"plaza_dossier")

	assert_bool(hud._prompt_label.visible).is_true()
	assert_bool(hud._memo_active).is_true()
	assert_bool(hud._memo_timer.is_stopped()).is_false()
	assert_bool(hud._prompt_label.text.contains("plaza_dossier")).is_true()


# ── AC-5: memo timer expiry hides the prompt ────────────────────────────────

func test_memo_timer_timeout_hides_prompt_label() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	hud._on_document_collected(&"any_doc")
	assert_bool(hud._prompt_label.visible).is_true()

	# Simulate the timer timeout.
	hud._on_memo_timer_timeout()

	assert_bool(hud._memo_active).is_false()
	assert_bool(hud._prompt_label.visible).is_false()


# ── AC-6: empty document_id is rejected ─────────────────────────────────────

func test_empty_document_id_payload_is_ignored_by_memo_handler() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Pre-condition: memo timer stopped.
	assert_bool(hud._memo_timer.is_stopped()).is_true()

	# Empty StringName must early-return.
	hud._on_document_collected(&"")

	assert_bool(hud._memo_active).is_false()
	assert_bool(hud._memo_timer.is_stopped()).is_true()


# ── AC-7 / AC-10: Full context-hide stops processing + timers ───────────────

func test_context_change_to_menu_stops_process_and_all_timers() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Start some timers + tween references to verify cleanup.
	hud._flash_timer.start()
	hud._memo_timer.start()
	hud._pending_flash = true
	hud._memo_active = true

	# Pre-condition: processing.
	assert_bool(hud.is_processing()).is_true()

	# Act: leave gameplay.
	hud._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))

	# Assert: visible false, process disabled, timers stopped, latches cleared.
	assert_bool(hud.visible).is_false()
	assert_bool(hud.is_processing()).is_false()
	assert_bool(hud._flash_timer.is_stopped()).is_true()
	assert_bool(hud._memo_timer.is_stopped()).is_true()
	assert_bool(hud._pending_flash).is_false()
	assert_bool(hud._memo_active).is_false()


# ── AC-8: Restoration re-enables processing and visibility ──────────────────

func test_context_restore_re_enables_process_and_visibility() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Hide.
	hud._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))
	assert_bool(hud.is_processing()).is_false()

	# Restore.
	hud._on_ui_context_changed(int(InputContext.Context.GAMEPLAY), int(InputContext.Context.MENU))

	assert_bool(hud.visible).is_true()
	assert_bool(hud.is_processing()).is_true()


# ── AC-11: 15th connection — document_collected ─────────────────────────────

func test_document_collected_signal_is_15th_connection() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	assert_bool(Events.document_collected.is_connected(hud._on_document_collected)).is_true()


# ── HC-005 cleanup verification: document_collected disconnects on _exit_tree ─

func test_document_collected_disconnects_on_exit_tree() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	await get_tree().process_frame
	assert_bool(Events.document_collected.is_connected(hud._on_document_collected)).is_true()

	remove_child(hud)
	await get_tree().process_frame
	assert_bool(Events.document_collected.is_connected(hud._on_document_collected)).is_false()
	hud.free()
