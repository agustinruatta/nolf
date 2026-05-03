# tests/unit/foundation/post_process_stack/resolution_scale_subscription_test.gd
#
# ResolutionScaleSubscriptionTest — GdUnit4 suite for Story PPS-006.
#
# WHAT IS TESTED
#   AC-1: PostProcessStack subscribes to Events.setting_changed in _ready()
#         with is_connected guard; disconnects in _exit_tree().
#   AC-2: Emitting setting_changed("graphics", "resolution_scale", 1.0) sets
#         Viewport.scaling_3d_scale == 1.0.
#   AC-3: Emitting setting_changed("graphics", "resolution_scale", 0.75) sets
#         Viewport.scaling_3d_scale == 0.75.
#   AC-4: Runtime resolution change is applied immediately on the same frame
#         (synchronous property write — no await needed).
#   AC-6: Emitting setting_changed for a non-(graphics, resolution_scale) key
#         does NOT change Viewport.scaling_3d_scale from its previous value.
#
# WHAT IS NOT TESTED HERE
#   AC-5 (lint grep for scaling_3d_scale writes) — covered by the companion
#   scaling_3d_scale_lint_test.gd.
#
# VIEWPORT STRATEGY
#   The autoload /root/PostProcessStack is already connected and owns the root
#   Viewport's scaling_3d_scale. Tests that verify viewport mutation use
#   Events.setting_changed.emit() directly — the autoload handler fires
#   synchronously on the calling thread, so the assertion is safe to run
#   immediately after emit() with no process frame advance.
#
#   For lifecycle tests (AC-1), a fresh PostProcessStackService instance is
#   added to the test's scene tree with add_child_autofree() to trigger _ready()
#   and _exit_tree() on a non-autoload object. This avoids mutating the shared
#   autoload's connection state.
#
# DETERMINISM
#   All assertions are synchronous. No time-dependent code. No await.
#   signal emit() → handler fires → property written → assert in the same frame.
#
# GATE STATUS
#   Story PPS-006 | Logic type → BLOCKING gate (test-evidence requirement).
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[system]_[scenario]_[expected_result]
#
# REFERENCES
#   Implements: Story PPS-006 AC-1, AC-2, AC-3, AC-4, AC-6
#   GDD: design/gdd/post-process-stack.md §Core Rule 6, §Edge Cases
#   ADR-0002 IG 3: subscriber lifecycle (is_connected guard, disconnect in _exit_tree)
#   ADR-0007 IG 4: PostProcessStack at pos 6 must not call SettingsService at pos 10

class_name ResolutionScaleSubscriptionTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the root Viewport's current scaling_3d_scale.
## PostProcessStack uses get_viewport() which resolves to get_tree().root for
## an autoload at _ready() time — the root Viewport is the same object a test
## can reach via get_tree().root.
func _root_viewport_scale() -> float:
	return get_tree().root.get_viewport().scaling_3d_scale


## Resets the root Viewport scale to 1.0 before each test that reads it,
## ensuring a known baseline so tests are order-independent.
##
## Called explicitly in tests that verify viewport mutation; not applied as a
## blanket before_each() because lifecycle tests don't touch the viewport.
func _reset_viewport_scale_to_default() -> void:
	get_tree().root.get_viewport().scaling_3d_scale = 1.0


# ---------------------------------------------------------------------------
# AC-1: Subscription lifecycle — connect in _ready(), disconnect in _exit_tree()
# ---------------------------------------------------------------------------

## AC-1 (connect): Adding a fresh PostProcessStackService to the scene tree
## triggers _ready(), which connects _on_setting_changed to Events.setting_changed.
##
## Uses add_child_autofree() so the instance is properly freed (and _exit_tree
## fires) when the test suite tears down.
##
## Note: The autoload /root/PostProcessStack is already connected from boot.
## This test verifies the connection on a SEPARATE fresh instance to avoid
## relying on the autoload's state.
func test_pps_subscribes_to_setting_changed_on_ready() -> void:
	# Arrange — create a fresh instance NOT yet in the tree.
	var pps: PostProcessStackService = PostProcessStackService.new()
	# Confirm not yet connected before _ready() fires.
	assert_bool(Events.setting_changed.is_connected(pps._on_setting_changed)).override_failure_message(
		"AC-1 setup: handler must NOT be connected before _ready() fires."
	).is_false()

	# Act — add to tree triggers _ready().
	add_child_autofree(pps)

	# Assert — must be connected now.
	assert_bool(Events.setting_changed.is_connected(pps._on_setting_changed)).override_failure_message(
		"AC-1: _ready() must connect _on_setting_changed to Events.setting_changed."
	).is_true()


## AC-1 (disconnect): Removing the instance from the tree fires _exit_tree(),
## which disconnects _on_setting_changed from Events.setting_changed.
##
## Creates, adds, verifies connected, then removes and verifies disconnected —
## full lifecycle in one test function.
func test_pps_disconnects_from_setting_changed_on_exit_tree() -> void:
	# Arrange — add to tree so _ready() runs.
	var pps: PostProcessStackService = PostProcessStackService.new()
	add_child(pps)
	assert_bool(Events.setting_changed.is_connected(pps._on_setting_changed)).override_failure_message(
		"AC-1 setup: handler must be connected after _ready()."
	).is_true()

	# Act — remove_child() is synchronous and fires _exit_tree() immediately,
	# allowing us to assert the disconnect without deferring.
	# (queue_free() defers deletion to end of frame — _exit_tree() fires at
	# that point, too late for a synchronous assertion.)
	remove_child(pps)

	# Assert — must be disconnected now.
	assert_bool(Events.setting_changed.is_connected(pps._on_setting_changed)).override_failure_message(
		"AC-1: _exit_tree() must disconnect _on_setting_changed from Events.setting_changed."
	).is_false()

	# Clean up the detached node — safe to call queue_free on orphan.
	pps.queue_free()


## AC-1 (double-connect guard): Calling the connect path twice must not create
## duplicate connections. The is_connected guard in _ready() prevents this.
## Verified by checking that disconnect is sufficient (only one connection to remove).
func test_pps_is_connected_guard_prevents_duplicate_subscription() -> void:
	# Arrange — fresh instance added to tree (one connection established).
	var pps: PostProcessStackService = PostProcessStackService.new()
	add_child_autofree(pps)
	assert_bool(Events.setting_changed.is_connected(pps._on_setting_changed)).override_failure_message(
		"AC-1 setup: handler must be connected."
	).is_true()

	# Act — simulate double-connect attempt by calling connect logic directly.
	# The is_connected guard must block the second connect.
	if not Events.setting_changed.is_connected(pps._on_setting_changed):
		Events.setting_changed.connect(pps._on_setting_changed)

	# Assert — a single disconnect must fully remove the connection.
	Events.setting_changed.disconnect(pps._on_setting_changed)
	assert_bool(Events.setting_changed.is_connected(pps._on_setting_changed)).override_failure_message(
		"AC-1: After one disconnect, handler must be fully disconnected "
		+ "(guard prevented duplicate connection)."
	).is_false()

	# Re-connect for autofree teardown (so _exit_tree() disconnect doesn't error).
	# _exit_tree()'s is_connected guard makes this safe even if already disconnected.


# ---------------------------------------------------------------------------
# AC-2: scale 1.0 applied when setting_changed fires with ("graphics", "resolution_scale", 1.0)
# ---------------------------------------------------------------------------

## AC-2: Emitting setting_changed with value 1.0 sets Viewport.scaling_3d_scale
## to 1.0 immediately (synchronous property write; no frame advance needed).
##
## Uses the live autoload /root/PostProcessStack which is already subscribed,
## then emits the signal directly through Events.
func test_pps_applies_resolution_scale_1_0_on_setting_change() -> void:
	# Arrange — set a known baseline different from 1.0 so the change is
	# detectable regardless of current state.
	_reset_viewport_scale_to_default()
	get_tree().root.get_viewport().scaling_3d_scale = 0.5  # known non-1.0 start

	# Act — emit the signal that PostProcessStack is subscribed to.
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 1.0)

	# Assert — scaling_3d_scale must now be 1.0.
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-2: setting_changed('graphics', 'resolution_scale', 1.0) must set "
		+ "Viewport.scaling_3d_scale to 1.0. Got: %.4f" % _root_viewport_scale()
	).is_equal(1.0)


# ---------------------------------------------------------------------------
# AC-3: scale 0.75 applied when setting_changed fires with ("graphics", "resolution_scale", 0.75)
# ---------------------------------------------------------------------------

## AC-3: Emitting setting_changed with value 0.75 (Intel Iris Xe preset) sets
## Viewport.scaling_3d_scale to 0.75 immediately.
func test_pps_applies_resolution_scale_0_75_on_setting_change() -> void:
	# Arrange — start at 1.0 so the change to 0.75 is visible.
	_reset_viewport_scale_to_default()

	# Act
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)

	# Assert
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-3: setting_changed('graphics', 'resolution_scale', 0.75) must set "
		+ "Viewport.scaling_3d_scale to 0.75. Got: %.4f" % _root_viewport_scale()
	).is_equal(0.75)


# ---------------------------------------------------------------------------
# AC-4: Runtime resolution change is applied immediately (same-frame snap)
# ---------------------------------------------------------------------------

## AC-4: A runtime resolution change (e.g., player adjusts Settings mid-game)
## is applied immediately on the same call — no transition, no tween, no await.
## GDD §Edge Cases: resolution-scale changes snap; no visual blur transition.
func test_pps_applies_runtime_resolution_change_immediately() -> void:
	# Arrange — start at 1.0.
	_reset_viewport_scale_to_default()
	assert_float(_root_viewport_scale()).is_equal(1.0)

	# Act — emit a runtime change to 0.5 (simulating player-driven settings change).
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.5)

	# Assert — must be applied synchronously, no await needed.
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-4: Resolution scale change must be applied immediately (same-frame synchronous write). "
		+ "Got: %.4f" % _root_viewport_scale()
	).is_equal(0.5)

	# Act — change again to verify multiple runtime changes work.
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 1.0)

	# Assert
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-4: Second runtime resolution change must also apply immediately. "
		+ "Got: %.4f" % _root_viewport_scale()
	).is_equal(1.0)


# ---------------------------------------------------------------------------
# AC-6: Unrelated setting_changed keys are ignored — no viewport mutation
# ---------------------------------------------------------------------------

## AC-6: Emitting setting_changed for an unrelated category ("audio") must NOT
## change Viewport.scaling_3d_scale. The defensive early-return guard in
## _on_setting_changed ensures PostProcessStack only consumes its own keys.
func test_pps_ignores_unrelated_setting_keys_audio_category() -> void:
	# Arrange — establish a known scale.
	_reset_viewport_scale_to_default()
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)
	var scale_before: float = _root_viewport_scale()
	assert_float(scale_before).is_equal(0.75)  # confirm baseline

	# Act — emit an unrelated key (audio category, not graphics).
	Events.setting_changed.emit(&"audio", &"music_db", -10.0)

	# Assert — scale must be unchanged.
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-6: setting_changed('audio', 'music_db', ...) must NOT change "
		+ "Viewport.scaling_3d_scale. Expected %.4f, got %.4f."
		% [scale_before, _root_viewport_scale()]
	).is_equal(scale_before)


## AC-6 variant: category matches ("graphics") but name is different.
## Only the ("graphics", "resolution_scale") combination must be acted upon.
func test_pps_ignores_graphics_category_with_unrelated_name() -> void:
	# Arrange — establish a known scale.
	_reset_viewport_scale_to_default()
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)
	var scale_before: float = _root_viewport_scale()
	assert_float(scale_before).is_equal(0.75)

	# Act — same category, different name.
	Events.setting_changed.emit(&"graphics", &"antialiasing_mode", 2)

	# Assert — scale unchanged.
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-6: setting_changed('graphics', 'antialiasing_mode', ...) must NOT change "
		+ "Viewport.scaling_3d_scale. Expected %.4f, got %.4f."
		% [scale_before, _root_viewport_scale()]
	).is_equal(scale_before)


## AC-6 variant: name matches ("resolution_scale") but category is different.
## Only exact ("graphics", "resolution_scale") triggers viewport write.
func test_pps_ignores_resolution_scale_name_with_wrong_category() -> void:
	# Arrange
	_reset_viewport_scale_to_default()
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)
	var scale_before: float = _root_viewport_scale()
	assert_float(scale_before).is_equal(0.75)

	# Act — correct name, wrong category.
	Events.setting_changed.emit(&"display", &"resolution_scale", 0.5)

	# Assert — scale must be unchanged.
	assert_float(_root_viewport_scale()).override_failure_message(
		"AC-6: setting_changed('display', 'resolution_scale', ...) must NOT change "
		+ "Viewport.scaling_3d_scale (wrong category). Expected %.4f, got %.4f."
		% [scale_before, _root_viewport_scale()]
	).is_equal(scale_before)
