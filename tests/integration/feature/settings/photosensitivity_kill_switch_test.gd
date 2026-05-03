# tests/integration/feature/settings/photosensitivity_kill_switch_test.gd
#
# PhotosensitivityKillSwitchTest — GdUnit4 integration suite for Story SA-003.
#
# PURPOSE
#   AC-3 / AC-4 / AC-5 — kill-switch gate routes through Events.setting_changed
#   to PostProcessStack (and consumer subscribers when implemented). Verifies
#   the handshake with the live PostProcessStack autoload.
#
# GOVERNING REQUIREMENTS
#   TR-SET-008 (damage_flash_enabled toggle + persistent flag)
#   ADR-0002 (signal bus delivery contract)

class_name PhotosensitivityKillSwitchTest
extends GdUnitTestSuite


func before_test() -> void:
	# Reset PostProcessStack glow intensity to a known state before each test.
	if PostProcessStack:
		PostProcessStack.set_glow_intensity(1.0)


# ── AC-4 / AC-5: PostProcessStack routes setting_changed → set_glow_intensity ─

## AC-4: When SettingsService emits damage_flash_enabled = false, PostProcessStack
## routes to set_glow_intensity(0.0) within the same synchronous emit.
## AC-5: Toggling back to true routes set_glow_intensity(1.0).
func test_post_process_stack_glow_responds_to_damage_flash_enabled_emit() -> void:
	# Arrange: pre-condition.
	assert_object(PostProcessStack).override_failure_message(
		"PostProcessStack autoload must be present."
	).is_not_null()
	PostProcessStack.set_glow_intensity(1.0)

	# Act: emit damage_flash_enabled = false.
	Events.setting_changed.emit(&"accessibility", &"damage_flash_enabled", false)

	# Assert: glow intensity routed to 0.0.
	assert_float(PostProcessStack._glow_intensity).override_failure_message(
		"After Events.setting_changed(accessibility, damage_flash_enabled, false), "
		+ "PostProcessStack._glow_intensity must be 0.0. Got: %f" % PostProcessStack._glow_intensity
	).is_equal(0.0)

	# Act: toggle back.
	Events.setting_changed.emit(&"accessibility", &"damage_flash_enabled", true)

	# Assert: glow intensity routed to 1.0.
	assert_float(PostProcessStack._glow_intensity).override_failure_message(
		"After toggling damage_flash_enabled = true, glow_intensity must be 1.0. Got: %f" % PostProcessStack._glow_intensity
	).is_equal(1.0)


## AC-4 edge: non-accessibility category must NOT change glow.
func test_non_accessibility_category_does_not_change_glow() -> void:
	PostProcessStack.set_glow_intensity(1.0)

	# Emit a non-accessibility setting — glow must not change.
	Events.setting_changed.emit(&"audio", &"master_volume_db", -12.0)

	assert_float(PostProcessStack._glow_intensity).override_failure_message(
		"Non-accessibility setting must not affect PostProcessStack glow."
	).is_equal(1.0)


## AC-3 / AC-7 (consumer guard): non-bool value type must NOT change glow.
func test_non_bool_damage_flash_value_does_not_change_glow() -> void:
	PostProcessStack.set_glow_intensity(1.0)

	# Emit damage_flash_enabled with a wrong type.
	Events.setting_changed.emit(&"accessibility", &"damage_flash_enabled", 0)

	# Per CR-7 type guard, non-bool values are skipped — glow stays at 1.0.
	assert_float(PostProcessStack._glow_intensity).override_failure_message(
		"Non-bool damage_flash_enabled value must not change glow (CR-7 type guard)."
	).is_equal(1.0)


## AC-5 edge: irrelevant accessibility key must NOT change glow.
func test_irrelevant_accessibility_key_does_not_change_glow() -> void:
	PostProcessStack.set_glow_intensity(1.0)

	# Emit a different accessibility setting — glow must not change.
	Events.setting_changed.emit(&"accessibility", &"subtitles_enabled", true)

	assert_float(PostProcessStack._glow_intensity).override_failure_message(
		"Non-damage_flash accessibility setting must not affect glow."
	).is_equal(1.0)


# ── AC-7 / AC-8 source inspection: PostProcessStack consumer guard ───────────

## AC-7: PostProcessStack._on_setting_changed first body statement is the
## category != &"accessibility" early-return guard.
## AC-8: No `else:` clause inside any match name block.
func test_post_process_stack_handler_has_category_guard_first() -> void:
	var f: FileAccess = FileAccess.open("res://src/core/rendering/post_process_stack.gd", FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	# Find the _on_setting_changed function body and inspect its first statement.
	var marker: String = "func _on_setting_changed"
	var idx: int = content.find(marker)
	assert_int(idx).override_failure_message(
		"post_process_stack.gd must define _on_setting_changed."
	).is_greater(-1)

	# Slice the first ~20 lines after the marker.
	var after: String = content.substr(idx, 600)
	# Verify the early-return guard is present immediately in the body.
	assert_bool(after.contains("if category != &\"accessibility\": return")).override_failure_message(
		(
			"post_process_stack.gd _on_setting_changed first body statement must be "
			+ "'if category != &\"accessibility\": return'. Body excerpt: %s" % after.substr(0, 300)
		)
	).is_true()

	# AC-8: no `else:` or `_:` inside the handler body.
	# Find the next top-level func after this one to bound the body.
	var body_end_marker: String = "\nfunc "
	var body_end_idx: int = content.find(body_end_marker, idx + marker.length())
	if body_end_idx < 0:
		body_end_idx = content.length()
	var body: String = content.substr(idx, body_end_idx - idx)
	# Look for problematic patterns.
	var bad_else: bool = false
	for line in body.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped == "else:" or stripped == "_:":
			bad_else = true
			break
	assert_bool(bad_else).override_failure_message(
		"post_process_stack.gd _on_setting_changed must NOT contain `else:` or `_:` clause (FP-6 forward-compat)."
	).is_false()
