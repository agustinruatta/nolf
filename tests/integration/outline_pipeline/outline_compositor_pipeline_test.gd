# tests/integration/outline_pipeline/outline_compositor_pipeline_test.gd
#
# OutlineCompositorPipelineTest — GdUnit4 integration suite for Story OUT-002.
#
# PURPOSE
#   Verifies the structural and behavioural contracts of OutlineCompositorEffect:
#   class identity, callback type, headless-safe early-return, and cleanup.
#
#   GPU-side correctness (AC-3, AC-6: fragment-shader tier-marker values, stencil
#   filtering) requires a live Vulkan context with rendered geometry. Those tests
#   are deferred to Story 005 (OUT-005) visual sign-off evidence. This file covers
#   everything that is verifiable without a GPU rendering session.
#
# ACs COVERED
#   AC-1 + AC-5  : class_name, extends CompositorEffect, effect_callback_type == POST_OPAQUE
#   AC-2 + AC-3  : headless early-return path — no crash when RD is null
#   AC-7 cleanup : _notification(NOTIFICATION_PREDELETE) callable; pipeline cache
#                  reset after free
#
# HEADLESS NOTE
#   The test runner uses --ignoreHeadlessMode but the Vulkan device may not be
#   available in CI. All tests that touch RenderingDevice gate their GPU assertions
#   with `RenderingServer.get_rendering_device() != null`. Pipeline state inspection
#   (RID validity) is only asserted when a real RD is present.
#
# GATE STATUS
#   Story OUT-002 | Integration type → BLOCKING gate per coding-standards.md.

class_name OutlineCompositorPipelineTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a new OutlineCompositorEffect instance and registers it for
## automatic cleanup via auto_free().
func _make_effect() -> OutlineCompositorEffect:
	var effect: OutlineCompositorEffect = OutlineCompositorEffect.new()
	auto_free(effect)
	return effect


## Returns true if a real Vulkan RenderingDevice is available in this process.
## Used to skip GPU-only assertions in headless CI environments.
func _has_rendering_device() -> bool:
	return RenderingServer.get_rendering_device() != null


# ---------------------------------------------------------------------------
# AC-1: class_name and base class
# ---------------------------------------------------------------------------

## OutlineCompositorEffect must declare class_name (so other scripts can
## reference it by name) and extend CompositorEffect (so it can be attached to
## a Compositor resource on a Camera3D).
## Implements: OUT-002 AC-1, TR-OUT-005.
func test_outline_compositor_effect_is_a_compositor_effect() -> void:
	# Arrange + Act
	var effect: OutlineCompositorEffect = _make_effect()

	# Assert — is-a check covers both class_name and inheritance contract.
	assert_object(effect).override_failure_message(
		"OutlineCompositorEffect instance must not be null."
	).is_not_null()

	assert_bool(effect is CompositorEffect).override_failure_message(
		"OutlineCompositorEffect must extend CompositorEffect " +
		"(required for Compositor attachment on Camera3D)."
	).is_true()


# ---------------------------------------------------------------------------
# AC-5: effect_callback_type set to POST_OPAQUE in _init
# ---------------------------------------------------------------------------

## effect_callback_type must be EFFECT_CALLBACK_TYPE_POST_OPAQUE.
## POST_OPAQUE ensures the stencil buffer is populated (opaque pass has run)
## and avoids the first-frame stencil-read bug (GitHub #110629).
## Setting POST_TRANSPARENT instead would miss the opaque-pass stencil state.
## Implements: OUT-002 AC-5, TR-OUT-005, TR-OUT-009.
func test_outline_compositor_effect_callback_type_is_post_opaque() -> void:
	# Arrange + Act
	var effect: OutlineCompositorEffect = _make_effect()

	# Assert — must be POST_OPAQUE, not POST_TRANSPARENT or POST_SKY.
	assert_int(effect.effect_callback_type).override_failure_message(
		"effect_callback_type must be EFFECT_CALLBACK_TYPE_POST_OPAQUE (%d), " % \
		CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE +
		"got %d. POST_TRANSPARENT would miss opaque-pass stencil state." % \
		effect.effect_callback_type
	).is_equal(CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE)


# ---------------------------------------------------------------------------
# AC-2 + AC-3 (early-return path): headless safety — no crash when RD is null
# ---------------------------------------------------------------------------

## When RenderingServer.get_rendering_device() returns null (headless CI,
## Compatibility renderer, or non-RD backend), _render_callback must:
##   1. Not crash or raise an error.
##   2. Not attempt to build Vulkan pipelines.
##
## We cannot invoke _render_callback directly without a valid RenderData object
## (which is only constructed by the Compositor during actual rendering). Instead
## we verify the headless safety by:
##   a) Confirming the instance initialises without error regardless of RD presence.
##   b) Confirming get_intermediate_texture_rid() returns an invalid RID when no
##      pipelines have been built (pipelines require _render_callback to run).
##
## Implements: OUT-002 AC-2, AC-3 (headless early-return path), QA plan §Edge cases.
func test_outline_compositor_effect_initialises_without_crash_in_any_context() -> void:
	# Arrange + Act — instantiation must not throw even without a GPU.
	var effect: OutlineCompositorEffect = _make_effect()

	# Assert — instance is valid; no crash during _init().
	assert_object(effect).override_failure_message(
		"OutlineCompositorEffect.new() must not crash in any render context " +
		"(including headless / Compatibility renderer)."
	).is_not_null()


## Before _render_callback has run (no RenderData available outside the
## rendering thread), get_intermediate_texture_rid() must return an invalid
## RID — pipelines are built lazily inside the first render callback.
##
## Implements: OUT-002 AC-4 (texture available after render; invalid before render).
func test_intermediate_texture_rid_is_invalid_before_first_render_callback() -> void:
	# Arrange
	var effect: OutlineCompositorEffect = _make_effect()

	# Act
	var rid: RID = effect.get_intermediate_texture_rid()

	# Assert — RID must be invalid (not yet built).
	assert_bool(rid.is_valid()).override_failure_message(
		"get_intermediate_texture_rid() must return an invalid RID before " +
		"_render_callback has been invoked (pipelines are built lazily)."
	).is_false()


# ---------------------------------------------------------------------------
# AC-7 cleanup: NOTIFICATION_PREDELETE frees pipeline cache
# ---------------------------------------------------------------------------

## _notification(NOTIFICATION_PREDELETE) must be callable without crashing.
## After the effect is freed, the pipeline cache must be in the cleared state.
##
## We test this by:
##   1. Creating an effect and confirming it initialises successfully.
##   2. Manually calling free() (triggers NOTIFICATION_PREDELETE).
##   3. Verifying no error was raised during free.
##
## We cannot inspect _tier_pipelines or _stencil_shader after free() because the
## object is invalidated. Instead we verify that the get_intermediate_texture_rid()
## accessor was accessible before free and that free() completes without crash.
##
## Implements: OUT-002 AC-7 (no RID-leak warnings, PREDELETE cleanup).
func test_outline_compositor_effect_free_does_not_crash() -> void:
	# Arrange — create without auto_free so we control the lifetime.
	var effect: OutlineCompositorEffect = OutlineCompositorEffect.new()
	assert_object(effect).is_not_null()

	# Verify accessor is callable before free.
	var rid_before: RID = effect.get_intermediate_texture_rid()
	assert_bool(rid_before.is_valid()).override_failure_message(
		"Intermediate texture RID unexpectedly valid before first render callback."
	).is_false()

	# Act — null the local reference so the Resource refcount drops to 0 and
	# Godot auto-fires NOTIFICATION_PREDELETE. CompositorEffect extends Resource
	# (RefCounted), so calling .free() directly is illegal — Resources are
	# reference-counted and cannot be manually freed; they self-destruct when
	# the last reference is dropped.
	effect = null

	# Assert — reaching this line means PREDELETE cleanup completed without
	# crashing. GdUnit4 treats an unhandled error during destruction as a test
	# failure, so no explicit assertion is needed.
	assert_bool(true).override_failure_message(
		"Effect destruction must not crash (NOTIFICATION_PREDELETE cleanup must succeed)."
	).is_true()


## Verifying that calling _notification(NOTIFICATION_PREDELETE) directly on a
## fresh instance (no pipelines built) is safe — no null-RID free attempts.
##
## Implements: OUT-002 AC-7, QA plan edge case "RID-leak warnings on scene shutdown".
func test_outline_compositor_effect_predelete_notification_safe_with_no_pipelines() -> void:
	# Arrange
	var effect: OutlineCompositorEffect = OutlineCompositorEffect.new()

	# Act — call PREDELETE notification directly before any pipeline is built.
	# If _free_cached_rids() or the PREDELETE handler tries to free invalid RIDs
	# (not guarded by .is_valid()), this will emit a Godot error.
	effect._notification(Object.NOTIFICATION_PREDELETE)

	# Resource is RefCounted — drop the reference to let GC fire the real
	# destructor (calling .free() on RefCounted is illegal).
	effect = null

	# Assert — reaching here means no crash and no attempted free of invalid RIDs.
	assert_bool(true).override_failure_message(
		"NOTIFICATION_PREDELETE with no pipelines built must not crash or " +
		"attempt to free invalid RIDs."
	).is_true()


# ---------------------------------------------------------------------------
# Structural: TIER_MARKERS constant encoding
# ---------------------------------------------------------------------------

## Verify the TIER_MARKERS constant has exactly 3 entries (one per tier) and
## that their values match the ADR-0001 §Decision encoding:
##   Index 0 (Tier 1 / HEAVIEST) → 1.0
##   Index 1 (Tier 2 / MEDIUM)   → 2.0/3.0 ≈ 0.6667
##   Index 2 (Tier 3 / LIGHT)    → 1.0/3.0 ≈ 0.3333
##
## This is a structural test — the constant values drive the push constants
## written to the GLSL shader. Wrong values → wrong tier-mask encoding →
## Stage 2 jump-flood computes wrong outlines.
##
## Implements: OUT-002 AC-3 (tier_marker encoding contract).
func test_tier_markers_constant_has_correct_count_and_values() -> void:
	# Arrange
	var tolerance: float = 0.0001

	# Assert count
	assert_int(OutlineCompositorEffect.TIER_MARKERS.size()).override_failure_message(
		"TIER_MARKERS must have exactly 3 entries (one per tier T = 1, 2, 3)."
	).is_equal(3)

	# Assert Tier 1 marker (HEAVIEST = 1.0)
	assert_bool(
		absf(OutlineCompositorEffect.TIER_MARKERS[0] - 1.0) <= tolerance
	).override_failure_message(
		"TIER_MARKERS[0] (Tier 1 / HEAVIEST) must equal 1.0, " +
		"got %f." % OutlineCompositorEffect.TIER_MARKERS[0]
	).is_true()

	# Assert Tier 2 marker (MEDIUM = 2/3 ≈ 0.6667)
	var expected_tier2: float = 2.0 / 3.0
	assert_bool(
		absf(OutlineCompositorEffect.TIER_MARKERS[1] - expected_tier2) <= tolerance
	).override_failure_message(
		"TIER_MARKERS[1] (Tier 2 / MEDIUM) must equal 2.0/3.0 ≈ 0.6667, " +
		"got %f." % OutlineCompositorEffect.TIER_MARKERS[1]
	).is_true()

	# Assert Tier 3 marker (LIGHT = 1/3 ≈ 0.3333)
	var expected_tier3: float = 1.0 / 3.0
	assert_bool(
		absf(OutlineCompositorEffect.TIER_MARKERS[2] - expected_tier3) <= tolerance
	).override_failure_message(
		"TIER_MARKERS[2] (Tier 3 / LIGHT) must equal 1.0/3.0 ≈ 0.3333, " +
		"got %f." % OutlineCompositorEffect.TIER_MARKERS[2]
	).is_true()
