# tests/unit/feature/hud_core/hud_core_health_widget_test.gd
#
# HUDCoreHealthWidgetTest — GdUnit4 suite for Story HC-003.
#
# PURPOSE
#   AC-1 / AC-2 / AC-3 / AC-4 / AC-5 / AC-6 / AC-7 / AC-8 — damage flash +
#   critical-state edge trigger + rate-gate + photosensitivity opt-out +
#   context-hide Tween.kill safety.

class_name HUDCoreHealthWidgetTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"


# ── AC-4: critical-state edge trigger sets Alarm Orange override ────────────

func test_health_below_25_percent_triggers_alarm_orange_override() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Pre-condition: not critical.
	assert_bool(hud._was_critical).is_false()

	# Act: drop to 20% (24/100).
	hud._on_health_changed(24.0, 100.0)

	# Assert: critical state set, Alarm Orange applied.
	assert_bool(hud._was_critical).is_true()
	var color: Color = hud._health_label_numeral.get_theme_color(&"font_color")
	# Alarm Orange #E85D2A == Color(0.910, 0.365, 0.165).
	assert_float(color.r).is_equal_approx(0.910, 0.01)
	assert_float(color.g).is_equal_approx(0.365, 0.01)


# ── AC-5: level-triggered guard prevents redundant override ─────────────────

func test_health_repeated_critical_emits_does_not_re_apply_override() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Cross into critical first.
	hud._on_health_changed(24.0, 100.0)
	var was_critical_after_first: bool = hud._was_critical
	# Re-emit same critical state — _was_critical stays true; no edge trigger.
	hud._on_health_changed(15.0, 100.0)
	hud._on_health_changed(10.0, 100.0)

	assert_bool(was_critical_after_first).is_true()
	assert_bool(hud._was_critical).is_true()
	# Numeral text reflects latest value.
	assert_str(hud._health_label_numeral.text).is_equal("10")


# ── AC-6: recovery above 25% reverts to Parchment ───────────────────────────

func test_health_recovery_above_25_percent_reverts_to_parchment() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Drop to critical.
	hud._on_health_changed(20.0, 100.0)
	assert_bool(hud._was_critical).is_true()

	# Recover to 30%.
	hud._on_health_changed(30.0, 100.0)
	assert_bool(hud._was_critical).is_false()
	# _current_health_color reverts to Parchment.
	var c: Color = hud._current_health_color
	assert_float(c.r).is_equal_approx(0.949, 0.01)
	assert_float(c.g).is_equal_approx(0.910, 0.01)
	assert_float(c.b).is_equal_approx(0.784, 0.01)


# ── AC-1 / AC-2: rate-gate fires + latches deferred flash ───────────────────

func test_first_damage_event_fires_immediately_when_gate_open() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Pre-condition: gate open (timer stopped).
	assert_bool(hud._flash_timer.is_stopped()).is_true()
	assert_bool(hud._pending_flash).is_false()

	# Act: fire damage event.
	hud._on_player_damaged(10.0, null, false)

	# Assert: timer started (gate closed) — flash fired.
	assert_bool(hud._flash_timer.is_stopped()).is_false()
	assert_bool(hud._pending_flash).is_false()


func test_second_damage_event_within_window_latches_pending_flash() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Fire first event (opens gate).
	hud._on_player_damaged(10.0, null, false)
	# Gate closed; second event must latch.
	hud._on_player_damaged(10.0, null, false)

	assert_bool(hud._pending_flash).is_true()


# ── AC-3: photosensitivity opt-out suppresses flash ─────────────────────────

func test_photosensitivity_opt_out_suppresses_damage_flash() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Disable damage flash via setting_changed handler.
	hud._on_setting_changed(&"accessibility", &"damage_flash_enabled", false)
	assert_bool(hud._flash_suppressed).is_true()

	# Fire damage — must NOT start timer (suppressed early-return).
	hud._on_player_damaged(10.0, null, false)
	assert_bool(hud._flash_timer.is_stopped()).is_true()


func test_photosensitivity_opt_in_unsuppresses_flash() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Disable then re-enable.
	hud._on_setting_changed(&"accessibility", &"damage_flash_enabled", false)
	assert_bool(hud._flash_suppressed).is_true()
	hud._on_setting_changed(&"accessibility", &"damage_flash_enabled", true)
	assert_bool(hud._flash_suppressed).is_false()


# ── AC-8: context-hide + Tween.kill safety (null-guard) ─────────────────────

func test_context_change_to_menu_hides_hud_and_safely_kills_tweens_when_null() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Pre: visible (GAMEPLAY context).
	hud.visible = true
	assert_bool(hud._damage_flash_tween == null).is_true()

	# Act: switch to non-gameplay context.
	hud._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))

	# Assert: hidden, no errors from null Tween kill attempts.
	assert_bool(hud.visible).is_false()


func test_context_change_back_to_gameplay_shows_hud() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# Hide
	hud._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))
	assert_bool(hud.visible).is_false()

	# Show
	hud._on_ui_context_changed(int(InputContext.Context.GAMEPLAY), int(InputContext.Context.MENU))
	assert_bool(hud.visible).is_true()
