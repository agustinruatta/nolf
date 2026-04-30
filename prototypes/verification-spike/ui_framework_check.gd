# prototypes/verification-spike/ui_framework_check.gd
#
# ADR-0004 UI Framework — verification script for the gates closeable
# without a runtime AT (assistive technology) inspection.
#
# CLOSES
#   G1 — `accessibility_description` (and related accessibility_*) properties
#        on Control are settable; values persist via property API.
#   G3 — `_unhandled_input()` modal dismiss grammar:
#        * `ui_cancel` action exists in InputMap
#        * `ui_cancel` is bound to KEY_ESCAPE (KB/M dismiss)
#        * `ui_cancel` is bound to a gamepad button (gamepad dismiss)
#        * an `InputEventKey` with keycode=KEY_ESCAPE pressed satisfies
#          `event.is_action_pressed("ui_cancel")` (the `_unhandled_input`
#          dispatch path used by ADR-0004 modal dismiss)
#        Note: this verifies the input grammar that modal dismiss relies on.
#        The full `_unhandled_input` lifecycle on a real Control hierarchy
#        is engine-stable since 4.0 and not a Godot 4.6-specific risk.
#
# DOES NOT CLOSE
#   G5 — `RichTextLabel` BBCode → AccessKit plain-text serialization.
#        Requires runtime AccessKit inspection (querying what an actual
#        screen reader announces). AccessKit is engine-internal and does
#        not expose a public API for headless plain-text query at the time
#        of this verification. G5 must be closed via runtime AT testing
#        with a real screen reader (NVDA/Orca) reading the Document Overlay
#        prototype scene. Deferred to Group 3 visual+AT verification or
#        the Settings & Accessibility production story.
#
# HOW TO RUN
#   godot --headless --script res://prototypes/verification-spike/ui_framework_check.gd
#
# OUTPUT
#   Per-check PASS/FAIL plus summary. Exits 0 on full PASS, 1 on any failure.
#   Exits PARTIAL (code 0 with note) if G1+G3 pass but G5 is deferred.

extends SceneTree

var _all_passed: bool = true


func _initialize() -> void:
	print()
	print("=== ADR-0004 UI Framework — Verification (G1 + G3) ===")
	print("Engine version (runtime): %s" % Engine.get_version_info().string)
	print("Date: %s" % Time.get_datetime_string_from_system())
	print()

	_check_1_accessibility_description_settable()
	_check_2_accessibility_role_settability()
	_check_3_ui_cancel_action_exists()
	_check_4_ui_cancel_kbm_binding()
	_check_5_ui_cancel_gamepad_binding()
	_check_6_input_event_action_dispatch()

	print()
	print("--- Note on G5 (BBCode → AccessKit plain-text) ---")
	print("  G5 cannot be closed headlessly. AccessKit's plain-text serialization")
	print("  is observable only via a real assistive technology (NVDA/Orca) reading")
	print("  the running Document Overlay scene. G5 is DEFERRED to runtime AT testing.")

	print()
	if _all_passed:
		print("=== Result: PASS — G1 closed; G3 (input grammar half) closed; G5 deferred ===")
		quit(0)
	else:
		print("=== Result: FAIL — see check-level output above ===")
		quit(1)


# ─── Check 1 ───────────────────────────────────────────────────────────
# G1: `accessibility_description` is settable on a Control and persists.
func _check_1_accessibility_description_settable() -> void:
	print("[Check 1] Control.accessibility_description settable + readable (G1)")
	var ctrl := Control.new()

	# `accessibility_description` was introduced for AccessKit screen reader
	# support (4.5+). It must be settable as a String property and reads
	# back the same value.
	if not "accessibility_description" in ctrl:
		# Fall back to the old API name to detect a renaming.
		if "accessibility_name" in ctrl:
			_fail("Check 1", "Control has `accessibility_name` (old name) but NOT `accessibility_description` (new name expected by ADR-0004 G1) — ADR may need amendment to use `accessibility_name`")
		else:
			_fail("Check 1", "Control has neither `accessibility_description` nor `accessibility_name` properties")
		ctrl.queue_free()
		return

	ctrl.set("accessibility_description", "Spike test description")
	var read_back: Variant = ctrl.get("accessibility_description")
	if read_back != "Spike test description":
		_fail("Check 1", "accessibility_description set/get round-trip failed: read back %s" % str(read_back))
		ctrl.queue_free()
		return
	ctrl.queue_free()
	print("  PASS — `accessibility_description` exists, settable as String, round-trips")


# ─── Check 2 ───────────────────────────────────────────────────────────
# G1 sub-check: `accessibility_role` settability — ADR-0004 G1 explicitly
# flags this as "may not be settable as string property — inferred from
# node type instead." Verify the actual situation.
func _check_2_accessibility_role_settability() -> void:
	print("[Check 2] Control.accessibility_role settability (G1 sub-check)")
	var ctrl := Control.new()
	if not "accessibility_role" in ctrl:
		print("  INFO — `accessibility_role` is NOT a Control property; AT role is inferred from node type (matches ADR-0004 G1 hypothesis)")
		ctrl.queue_free()
		return
	# If it does exist, try setting it as a string and see what happens.
	var initial = ctrl.get("accessibility_role")
	ctrl.set("accessibility_role", "button")
	var read_back: Variant = ctrl.get("accessibility_role")
	ctrl.queue_free()
	if read_back == "button":
		print("  INFO — `accessibility_role` exists AND is settable as String (initial: %s, after-set: %s)" % [str(initial), str(read_back)])
	else:
		print("  INFO — `accessibility_role` exists but did NOT round-trip String set (initial: %s, after-set: %s) — likely enum-typed" % [str(initial), str(read_back)])


# ─── Check 3 ───────────────────────────────────────────────────────────
# G3: ui_cancel action is registered.
func _check_3_ui_cancel_action_exists() -> void:
	print("[Check 3] InputMap has `ui_cancel` action (G3)")
	if not InputMap.has_action("ui_cancel"):
		_fail("Check 3", "`ui_cancel` action is not registered in InputMap")
		return
	print("  PASS — `ui_cancel` is a registered action")


# ─── Check 4 ───────────────────────────────────────────────────────────
# G3: ui_cancel is bound to KEY_ESCAPE (the KB/M dismiss).
func _check_4_ui_cancel_kbm_binding() -> void:
	print("[Check 4] `ui_cancel` is bound to KEY_ESCAPE (KB/M dismiss) (G3)")
	if not InputMap.has_action("ui_cancel"):
		_fail("Check 4", "Skipping — `ui_cancel` not registered (Check 3 already failed)")
		return
	var events: Array = InputMap.action_get_events("ui_cancel")
	var found_esc: bool = false
	for ev in events:
		if ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE:
			found_esc = true
			break
	if not found_esc:
		# It might be encoded with `keycode` instead of `physical_keycode`.
		for ev in events:
			if ev is InputEventKey and ev.keycode == KEY_ESCAPE:
				found_esc = true
				break
	if not found_esc:
		_fail("Check 4", "`ui_cancel` does NOT contain a KEY_ESCAPE binding among %d event(s)" % events.size())
		return
	print("  PASS — `ui_cancel` includes KEY_ESCAPE")


# ─── Check 5 ───────────────────────────────────────────────────────────
# G3: ui_cancel is bound to a gamepad button (gamepad dismiss).
func _check_5_ui_cancel_gamepad_binding() -> void:
	print("[Check 5] `ui_cancel` is bound to a gamepad button (gamepad dismiss) (G3)")
	if not InputMap.has_action("ui_cancel"):
		_fail("Check 5", "Skipping — `ui_cancel` not registered (Check 3 already failed)")
		return
	var events: Array = InputMap.action_get_events("ui_cancel")
	var gamepad_button_event: InputEventJoypadButton = null
	for ev in events:
		if ev is InputEventJoypadButton:
			gamepad_button_event = ev
			break
	if gamepad_button_event == null:
		_fail("Check 5", "`ui_cancel` does NOT contain any InputEventJoypadButton — gamepad dismiss not bound by default")
		return
	# JOY_BUTTON_B = 1 in Godot 4.x (the "B / Circle" right-side button per Art Bible 7D).
	# Note: JOY_BUTTON_A (bottom) = Accept; JOY_BUTTON_B (right) = Cancel/Back per
	# default Godot 4.x InputMap.
	if gamepad_button_event.button_index != JOY_BUTTON_B:
		print("  INFO — `ui_cancel` is bound to gamepad button index %d (expected JOY_BUTTON_B = %d for B/Circle per Art Bible 7D)" % [gamepad_button_event.button_index, JOY_BUTTON_B])
	print("  PASS — `ui_cancel` includes a gamepad button binding (button_index=%d)" % gamepad_button_event.button_index)


# ─── Check 6 ───────────────────────────────────────────────────────────
# G3: an InputEventKey with KEY_ESCAPE pressed satisfies
# `event.is_action_pressed("ui_cancel")` — the API path used by
# ADR-0004's modal dismiss `_unhandled_input()` handlers.
func _check_6_input_event_action_dispatch() -> void:
	print("[Check 6] InputEventKey(KEY_ESCAPE, pressed=true).is_action_pressed(\"ui_cancel\") returns true (G3)")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	if not ev.is_action_pressed("ui_cancel"):
		_fail("Check 6", "InputEventKey(KEY_ESCAPE, pressed=true) does NOT match ui_cancel — modal dismiss grammar broken")
		return
	# Confirm a non-pressed event does NOT match.
	ev.pressed = false
	if ev.is_action_pressed("ui_cancel"):
		_fail("Check 6", "InputEventKey(KEY_ESCAPE, pressed=false) incorrectly matches ui_cancel pressed")
		return
	print("  PASS — InputEventKey dispatch correctly resolves to ui_cancel action")


# ─── Helpers ───────────────────────────────────────────────────────────

func _fail(check: String, msg: String) -> void:
	_all_passed = false
	print("  FAIL — %s" % msg)
