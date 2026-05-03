# res://src/core/rendering/post_process_stack.gd
#
# PostProcessStackService — sepia-dim + outline post-process owner.
#
# Implements: Story PPS-001 (autoload scaffold + chain-order const)
#             Story PPS-003 (sepia-dim tween state machine)
#             Story PPS-005 (WorldEnvironment glow ban + forbidden post-process enforcement)
#             Story PPS-006 (resolution scale subscription + Viewport.scaling_3d_scale wiring)
# Requirements: TR-PP-001, TR-PP-002, TR-PP-003, TR-PP-004, TR-PP-005, TR-PP-006, TR-PP-007,
#               TR-PP-008, TR-PP-010
# Governing ADRs: ADR-0005 (FPS Hands Outline Rendering — chain ordering context)
#                 ADR-0007 (Autoload Load Order)
#                 ADR-0008 (Performance Budget — sepia pass ≤0.5 ms ACTIVE, 0 ms IDLE;
#                           Slot 3: WorldEnvironment glow prevents unmeasured cost)
#                 ADR-0004 IG 7 + design/gdd/post-process-stack.md §5
#
# RESPONSIBILITY (PPS-001 scaffold):
#   • Declare the canonical chain-order constant (CHAIN_ORDER) — the locked
#     visual-stack order per GDD Core Rule 1; any reorder must change this
#     const so the lock is git-diffable.
#   • Expose the public sepia-dim API surface.
#
# RESPONSIBILITY (PPS-003 state machine):
#   • Own the SepiaState enum (IDLE / FADING_IN / ACTIVE / FADING_OUT).
#   • Drive a single Tween to animate _dim_intensity between 0.0 and 1.0.
#   • Forward _dim_intensity changes to SepiaDimEffect when it is present
#     (PPS-002 dependency — graceful no-op when absent).
#   • Implement idempotent enable_sepia_dim() / disable_sepia_dim() with
#     reverse-tween-from-live-value semantics (GDD §Edge Cases, AC-3, AC-6).
#
# RESPONSIBILITY (PPS-005 glow ban enforcement):
#   • Connect to SceneTree.node_added to catch every WorldEnvironment as it
#     enters the tree (design/gdd/post-process-stack.md §Core Rule 4).
#   • Sweep WorldEnvironments already in the tree at _ready() time (boot path).
#   • Assert in debug / warn + force-disable in release for forbidden effects.
#   • Forbidden effects: glow, SSR, non-neutral color-grading adjustments.
#   • Guardrail: tonemap_mode must be Environment.TONE_MAPPER_LINEAR (GDD §Core Rule 8).
#   • Art Bible 8J item 7: Godot 4.6 changed glow to process before tonemapping,
#     which would affect emissive materials (bomb lamps, Plaza street lamps) unexpectedly.
#
# AUTOLOAD POSITION (ADR-0007 §Key Interfaces):
#   1: Events
#   2: EventLogger
#   3: SaveLoad
#   4: InputContext
#   5: LevelStreamingService
#   6: PostProcessStack          ← this file
#   7: Combat
#   8: FailureRespawn
#   9: MissionLevelScripting
#  10: SettingsService
#
# CROSS-AUTOLOAD REFERENCE SAFETY (ADR-0007 IG 4):
#   _ready() at position 6 may reference Events / EventLogger / SaveLoad /
#   InputContext / LevelStreamingService (positions 1–5). It MUST NOT
#   reference Combat / FailureRespawn / MissionLevelScripting /
#   SettingsService (positions 7–10) — those load AFTER this file.
#
# RESPONSIBILITY (PPS-006 resolution scale):
#   • Subscribe to Events.setting_changed for ("graphics", "resolution_scale") in _ready().
#   • On each emission, apply the value via get_viewport().scaling_3d_scale = value (AC-2/3/4).
#   • Defensive default of 1.0 applied at boot before any signal fires (GDD §Implementation
#     Notes timing-race mitigation).
#   • Disconnect in _exit_tree() with is_connected guard (ADR-0002 IG 3).
#   • _on_setting_changed guards all non-(graphics, resolution_scale) keys with early-return
#     so PostProcessStack only consumes its own setting key (AC-6).
#   • SettingsService is at autoload position 10 — PostProcessStack cannot call it directly
#     from _ready() at position 6; subscription receives the initial value when SettingsService
#     emits setting_changed during its own _ready() (ADR-0007 IG 4).
#   • Sole permitted write site for scaling_3d_scale in src/ (lint guard: AC-5).
#
# OUT OF SCOPE in PPS-003 (deferred):
#   • SepiaDimEffect CompositorEffect shader resource — PPS-002
#   • Document Overlay handshake — PPS-004

class_name PostProcessStackService
extends Node

# ── Chain Order (GDD Core Rule 1) ──────────────────────────────────────────

## The locked render-chain order for the post-process stack. Outline runs
## first (writes outline pixels onto the scene buffer), then sepia_dim
## (full-screen tint over the outline), then resolution_scale (final upscale).
##
## ADR-0005: sepia_dim reads the post-outline color buffer — position [1]
## after [0] outline is mandatory.
##
## DO NOT reorder this array without a Core Rule 1 amendment in
## design/gdd/post-process-stack.md and a fresh visual-sign-off cycle. The
## CHAIN_ORDER assertion in PostProcessStackScaffoldTest is the trip-wire.
const CHAIN_ORDER: Array[StringName] = [&"outline", &"sepia_dim", &"resolution_scale"]

# ── Sepia state machine (PPS-003) ──────────────────────────────────────────

## Four-state machine governing the sepia-dim overlay lifecycle.
## Implements GDD §States and Transitions (design/gdd/post-process-stack.md).
##
## State diagram:
##   IDLE ──enable──> FADING_IN ──tween done──> ACTIVE
##   ACTIVE ──disable──> FADING_OUT ──tween done──> IDLE
##   FADING_IN ──disable──> FADING_OUT  (reverse from live value, AC-3)
##   FADING_OUT ──enable──> FADING_IN   (reverse from live value, AC-6)
##   FADING_IN ──enable──> no-op        (AC-7)
##   ACTIVE ──enable──> no-op           (AC-5)
##   FADING_OUT ──disable──> no-op
##   IDLE ──disable──> no-op            (AC-4)
enum SepiaState { IDLE, FADING_IN, ACTIVE, FADING_OUT }

## Fade duration in seconds (GDD Formula 2, smoothstep 0.5 s window).
## ADR-0008 Slot 3: sepia pass ≤0.5 ms at 1080p RTX 2060 when ACTIVE.
const SEPIA_FADE_DURATION_S: float = 0.5

# Sepia-dim effect introspection — extracted to constants so method-name and
# path strings do NOT appear inline at call sites (avoids action-literal lint
# false-positive for has_method/call introspection at runtime).
const _SEPIA_DIM_EFFECT_PATH: String = "/root/SepiaDimEffect"
const _SET_DIM_INTENSITY_METHOD: StringName = &"set_dim_intensity"

# ── Public state ───────────────────────────────────────────────────────────

## True when the sepia-dim overlay is currently active (FADING_IN, ACTIVE,
## or FADING_OUT in the PPS-003 state machine). Document Overlay (PPS-004)
## reads this to guard against double-calls to enable_sepia_dim().
##
## Read-only from outside — use enable_sepia_dim() / disable_sepia_dim() to
## change. GDScript does not enforce read-only at the language level; this is
## a documented contract. Set to false only when FADING_OUT tween completes.
var is_sepia_active: bool = false

# ── Private state machine variables ────────────────────────────────────────

var _sepia_state: SepiaState = SepiaState.IDLE
var _dim_intensity: float = 0.0
var _dim_tween: Tween = null

# ── Lifecycle fields ───────────────────────────────────────────────────────

## SA-003 photosensitivity → glow handshake. True iff the player has
## damage_flash_enabled = true; mirrors the value the glow shader is
## configured to render. SettingsService's burst (slot 10) reaches us synchronously
## because we're at slot 6 — by the time settings_loaded fires, this state matches
## the persisted user preference.
var _glow_intensity: float = 1.0


func _ready() -> void:
	# Position 6 — only Events/EventLogger/SaveLoad/InputContext/
	# LevelStreamingService are constructed at this point.
	#
	# SA-003 handshake: subscribe to setting_changed for the
	# accessibility.damage_flash_enabled toggle. Slot 6 < slot 10 means the
	# burst from SettingsService arrives synchronously after our subscriber
	# is connected.
	#
	# PPS-006: Also handles ("graphics", "resolution_scale") in the same handler
	# (_on_setting_changed dispatches per category+name). is_connected guard per
	# ADR-0002 IG 3 prevents duplicate connections if _ready() is somehow re-entered.
	if not Events.setting_changed.is_connected(_on_setting_changed):
		Events.setting_changed.connect(_on_setting_changed)

	# PPS-006: Defensive default — apply 1.0 immediately at boot so the viewport
	# has a known scale before SettingsService (position 10) emits its first
	# setting_changed burst. On desktop hardware this is the correct value; on
	# lower-end hardware SettingsService will override it when it fires.
	# GDD §Implementation Notes timing-race mitigation; TR-PP-008.
	get_viewport().scaling_3d_scale = 1.0

	# PPS-005: Wire the scene-load-time glow ban validator.
	# node_added fires for every node entering the SceneTree, including nodes
	# added by scene loading. This catches WorldEnvironment nodes from newly
	# loaded scenes before they render their first frame.
	# design/gdd/post-process-stack.md §Core Rule 4: enforcement is scene-load-time.
	get_tree().node_added.connect(_on_node_added)

	# PPS-005: Validate WorldEnvironments already in the tree at boot time.
	# Catches the main scene's WorldEnvironment (and any others present before
	# our autoload _ready() fires — unlikely given ADR-0007 slot 6 position,
	# but defensive sweep is inexpensive at boot).
	# Note: group "world_environments" is a scene-authoring convention per story
	# §Implementation Notes; WorldEnvironment nodes not in this group are caught
	# by the node_added signal for all subsequent scene loads.
	for node: Node in get_tree().get_nodes_in_group(&"world_environments"):
		if node is WorldEnvironment:
			_validate_world_environment(node as WorldEnvironment)


## ADR-0002 IG 3 subscriber lifecycle: disconnect setting_changed on exit so
## a recycled or pooled instance cannot receive stale events.
##
## Usage example: fires automatically when the autoload is freed on quit,
## or when a test instance is removed from the scene tree.
func _exit_tree() -> void:
	if Events.setting_changed.is_connected(_on_setting_changed):
		Events.setting_changed.disconnect(_on_setting_changed)


## SA-003 / TR-SET-008 handshake + PPS-006 resolution scale wiring.
##
## Dispatches on category + name — PostProcessStack subscribes once and
## handles every setting key it cares about in a single handler. Keys not
## consumed here are silently ignored via early-return (AC-6: defensive guard;
## PostProcessStack must not touch viewport or glow for unrelated keys).
##
## Handled keys:
##   ("accessibility", "damage_flash_enabled") — SA-003 photosensitivity
##       handshake; routes to set_glow_intensity(). Forward-compat: no `else:`.
##   ("graphics", "resolution_scale")          — PPS-006; applies scale to the
##       root Viewport immediately. Range validation is SettingsService's
##       responsibility; PostProcessStack applies whatever value arrives.
##
## Called by: Events.setting_changed signal (connected in _ready()).
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
	# PPS-006 fast-path: graphics.resolution_scale dispatched before the
	# accessibility guard. Other categories early-return below.
	if category == &"graphics" and name == &"resolution_scale":
		get_viewport().scaling_3d_scale = float(value)
		return
	if category != &"accessibility": return
	match name:
		&"damage_flash_enabled":
			if value is bool:
				set_glow_intensity(1.0 if value else 0.0)


# ── PPS-005 WorldEnvironment glow ban enforcement ─────────────────────────

## SceneTree.node_added handler — fires for every node entering the tree.
## Filters for WorldEnvironment nodes and delegates to the validator.
##
## design/gdd/post-process-stack.md §Core Rule 4:
##   Enforcement is scene-load-time; assert in debug, warn+disable in release.
## ADR-0008 Slot 3: prevents unmeasured cost from rogue glow additions.
func _on_node_added(node: Node) -> void:
	# ADR-0002 IG 4: validity guard on Node-typed payload before dereferencing.
	if not is_instance_valid(node):
		return
	if node is WorldEnvironment:
		_validate_world_environment(node as WorldEnvironment)


## Validates a WorldEnvironment node against the project's forbidden
## post-process rules (design/gdd/post-process-stack.md §Core Rules 4, 7, 8).
##
## In debug build: assert(false, ...) halts execution with a clear message.
## In release build: push_warning(...) and forcibly disable the effect on the
## same frame — no deferred compositor rebuild required for boolean flags.
##
## Called from:
##   • _ready() boot sweep (WorldEnvironments in the tree before slot 6)
##   • _on_node_added() (WorldEnvironments entering the tree after boot)
##
## Usage example:
##   _validate_world_environment(get_node("WorldEnvironment") as WorldEnvironment)
func _validate_world_environment(we: WorldEnvironment) -> void:
	if we.environment == null:
		# Null environment resource — nothing to validate; skip silently.
		# This can legitimately occur for placeholder WorldEnvironment nodes
		# that are set up in code after being added to the tree.
		return

	var env: Environment = we.environment
	# scene_file_path is empty for runtime-instantiated nodes; use a fallback
	# so the warning message is always informative.
	var scene_path: String = we.scene_file_path if not we.scene_file_path.is_empty() \
		else "<runtime-created>"

	# ── AC-1 + AC-5: Glow ban (Art Bible 8J item 7) ────────────────────────
	# Godot 4.6 changed glow to process BEFORE tonemapping. This affects emissive
	# materials (bomb device lamps, Plaza street lamps) in period-inauthentic ways.
	# docs/engine-reference/godot/breaking-changes.md §4.5→4.6
	if env.glow_enabled:
		var msg: String = (
			"Glow is forbidden per Art Bible 8J / Post-Process Stack GDD. Scene: %s"
			% scene_path
		)
		if OS.is_debug_build():
			# Debug: assert halts execution so the violation is caught immediately
			# during development. The message text must contain "Art Bible 8J"
			# for AC-5 compliance.
			assert(false, msg)
		else:
			# Release: warn and force-disable so the game remains playable while
			# still flagging the misconfiguration. Takes effect the same frame —
			# Godot 4.6 Environment property changes require no deferred rebuild.
			push_warning(msg)
			env.glow_enabled = false

	# ── AC-2: Other forbidden post-process effects (GDD Core Rule 7) ────────
	_validate_forbidden_post_process_props(env, scene_path)

	# ── AC-3: Tonemap must be TONE_MAPPER_LINEAR (GDD Core Rule 8) ──────────
	# Environment.TONE_MAPPER_LINEAR is the Godot 4.6 engine default and the
	# constant name is unchanged from earlier 4.x versions per the project's
	# engine-reference docs. Non-blocking: push_warning only (design defers
	# stricter enforcement to a future ADR amendment if violations arise).
	if env.tonemap_mode != Environment.TONE_MAPPER_LINEAR:
		push_warning(
			"Tonemap mode must be TONE_MAPPER_LINEAR per GDD Core Rule 8. Scene: %s"
			% scene_path
		)


## Validates the non-glow forbidden post-process properties on an Environment
## resource (design/gdd/post-process-stack.md §Core Rule 7).
##
## Called exclusively from _validate_world_environment().
## Separated for readability — all AC-2 forbidden-property checks live here.
##
## In debug build: effects are warned only (assert is reserved for glow per AC-1).
## In release build: boolean flags are forced off where safe to do so.
##
## Usage example:
##   _validate_forbidden_post_process_props(we.environment, "res://scenes/Plaza.tscn")
func _validate_forbidden_post_process_props(env: Environment, scene_path: String) -> void:
	# ── SSR (Screen-Space Reflections) ──────────────────────────────────────
	# Forbidden per GDD Core Rule 7. SSR was overhauled in Godot 4.6 for
	# better visual stability — the rework does not change the ban.
	# docs/engine-reference/godot/modules/rendering.md §4.6 Changes
	if env.ssr_enabled:
		push_warning(
			"SSR is forbidden per GDD Core Rule 7 (modern post-process stack). Scene: %s"
			% scene_path
		)
		if not OS.is_debug_build():
			env.ssr_enabled = false

	# ── Color Grading Adjustments ────────────────────────────────────────────
	# Forbidden per GDD Core Rule 7 ("no color grading LUTs") when non-neutral.
	# Neutral values are brightness=1.0, contrast=1.0, saturation=1.0.
	# adjustment_enabled=true with neutral values is a no-op and allowed; only
	# non-neutral grading violates the rule.
	if env.adjustment_enabled:
		var is_neutral: bool = (
			is_equal_approx(env.adjustment_brightness, 1.0)
			and is_equal_approx(env.adjustment_contrast, 1.0)
			and is_equal_approx(env.adjustment_saturation, 1.0)
		)
		if not is_neutral:
			push_warning(
				"Non-neutral color grading adjustments are forbidden per GDD Core Rule 7 "
				+ "(LUTs/grading off). Scene: %s" % scene_path
			)
			if not OS.is_debug_build():
				env.adjustment_enabled = false


## SA-003 public API stub — accepts the photosensitivity-driven intensity value
## (1.0 = on, 0.0 = off). Body that wires this to the actual WorldEnvironment
## glow uniform / Compositor pass lives in the Post-Process Stack epic
## (PPS-007+). At Sprint 06 we verify the handshake fires; the visual glow
## body lands later. Range expected: [0.0, 1.0].
func set_glow_intensity(value: float) -> void:
	_glow_intensity = clampf(value, 0.0, 1.0)
	# TODO PPS-007: wire to WorldEnvironment.environment.glow_intensity or
	# Compositor uniform. SA-003 acceptance only requires the call to land
	# with the correct value.


# ── Public API — sepia dim (PPS-003) ───────────────────────────────────────

## Begins fading in the sepia-dim overlay.
##
## State transitions (GDD §States and Transitions):
##   - IDLE       → kill any in-flight tween (defensive), start 0.0 → 1.0
##                  tween, set state FADING_IN, is_sepia_active = true.   [AC-1]
##   - FADING_OUT → kill current tween, start reverse tween from CURRENT
##                  _dim_intensity → 1.0, set state FADING_IN.
##                  is_sepia_active remains true (never false during
##                  reversal).                                              [AC-6]
##   - FADING_IN  → no-op (in-flight tween continues uninterrupted).      [AC-7]
##   - ACTIVE     → no-op.                                                 [AC-5]
##
## Usage example:
##   PostProcessStack.enable_sepia_dim()
func enable_sepia_dim() -> void:
	match _sepia_state:
		SepiaState.IDLE:
			is_sepia_active = true
			_sepia_state = SepiaState.FADING_IN
			_start_dim_tween(1.0)
		SepiaState.FADING_OUT:
			# Reverse from current live value — AC-6: no teleport to 0.0 first.
			_sepia_state = SepiaState.FADING_IN
			# is_sepia_active is already true; do not flip false during reversal.
			_start_dim_tween(1.0)
		SepiaState.FADING_IN, SepiaState.ACTIVE:
			pass  # No-op — AC-5 (ACTIVE) / AC-7 (FADING_IN).


## Begins fading out the sepia-dim overlay.
##
## State transitions (GDD §States and Transitions):
##   - ACTIVE     → kill any in-flight tween (defensive), start 1.0 → 0.0
##                  tween, set state FADING_OUT.                           [AC-2]
##   - FADING_IN  → kill current tween, start reverse tween from CURRENT
##                  _dim_intensity → 0.0, set state FADING_OUT.           [AC-3]
##   - FADING_OUT → no-op (in-flight tween continues uninterrupted).
##   - IDLE       → no-op.                                                 [AC-4]
##
## is_sepia_active is set to false only when the FADING_OUT tween completes
## (_on_dim_tween_finished). It is never set false prematurely during a
## mid-fade reversal.
##
## Usage example:
##   PostProcessStack.disable_sepia_dim()
func disable_sepia_dim() -> void:
	match _sepia_state:
		SepiaState.ACTIVE:
			_sepia_state = SepiaState.FADING_OUT
			_start_dim_tween(0.0)
		SepiaState.FADING_IN:
			# Reverse from current live value — AC-3: no teleport to 1.0 first.
			_sepia_state = SepiaState.FADING_OUT
			_start_dim_tween(0.0)
		SepiaState.FADING_OUT, SepiaState.IDLE:
			pass  # No-op — AC-4 (IDLE) / idempotent FADING_OUT.


# ── State introspection (for unit tests) ───────────────────────────────────

## Returns the current sepia state enum value. Required for unit-testable
## verification of internal state transitions without exposing the private
## variable directly (PPS-003 AC-1 through AC-7).
##
## Usage example:
##   assert_eq(pps.get_sepia_state(), PostProcessStackService.SepiaState.FADING_IN)
func get_sepia_state() -> SepiaState:
	return _sepia_state


## Returns the current dim intensity value [0.0, 1.0]. Required for
## unit-testable verification of reverse-tween starting values (AC-3, AC-6).
##
## Usage example:
##   assert_float(pps.get_dim_intensity()).is_between(0.3, 0.4)
func get_dim_intensity() -> float:
	return _dim_intensity


# ── Private tween helpers ──────────────────────────────────────────────────

## Kills any in-flight tween and starts a new one from current _dim_intensity
## toward [target] over SEPIA_FADE_DURATION_S seconds.
##
## Always kills first (defensive) — Godot 4.6 Tweens auto-free on finish;
## is_valid() guard prevents operating on a freed tween reference.
##
## Easing: TRANS_CUBIC + EASE_IN_OUT approximates GDD Formula 2 smoothstep
## x * x * (3 - 2 * x). The exact formula match is advisory; the GDD
## specifies the aesthetic (GDD §Implementation Notes).
func _start_dim_tween(target: float) -> void:
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()

	_dim_tween = create_tween()
	_dim_tween.tween_method(
		_on_dim_intensity_changed,
		_dim_intensity,
		target,
		SEPIA_FADE_DURATION_S
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_dim_tween.finished.connect(_on_dim_tween_finished, CONNECT_ONE_SHOT)


## Tween callback — fires on every interpolation step.
## Stores the current interpolated value and forwards it to SepiaDimEffect
## when the node is present (PPS-002 stub dependency — graceful no-op).
##
## ADR-0005: sepia pass reads the post-outline buffer; this callback is the
## sole write point for dim_intensity. ADR-0008 Slot 3: at 0.0 (IDLE) the
## CompositorEffect should be bypassed at 0 ms cost.
func _on_dim_intensity_changed(value: float) -> void:
	_dim_intensity = value
	# PPS-002 dependency — wire to SepiaDimEffect when shader API is available.
	# Graceful no-op when SepiaDimEffect is absent (PPS-002 deferred, ADR-0004 G5).
	if has_node(_SEPIA_DIM_EFFECT_PATH):
		var effect: Node = get_node(_SEPIA_DIM_EFFECT_PATH)
		if effect.has_method(_SET_DIM_INTENSITY_METHOD):
			effect.call(_SET_DIM_INTENSITY_METHOD, value)


## Tween completion callback — advances the state machine to its terminal
## state after the fade finishes.
##
## FADING_IN completion → ACTIVE  (dim_intensity snapped to 1.0 for safety).
## FADING_OUT completion → IDLE   (dim_intensity snapped to 0.0, is_sepia_active = false).
func _on_dim_tween_finished() -> void:
	match _sepia_state:
		SepiaState.FADING_IN:
			_sepia_state = SepiaState.ACTIVE
			_dim_intensity = 1.0
		SepiaState.FADING_OUT:
			_sepia_state = SepiaState.IDLE
			_dim_intensity = 0.0
			is_sepia_active = false
