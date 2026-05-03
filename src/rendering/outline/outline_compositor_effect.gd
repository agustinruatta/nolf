# src/rendering/outline/outline_compositor_effect.gd
#
# OutlineCompositorEffect — Stage 1 + Stage 2 of the tiered comic-book outline.
#
# Requirements: TR-OUT-002, TR-OUT-003, TR-OUT-005, TR-OUT-006, TR-OUT-008,
#               TR-OUT-009
# Governing ADR: ADR-0001 (Stencil ID Contract for Tiered Outline Rendering)
#               ADR-0008 (Performance Budget Distribution — Slot 3)
#
# OVERVIEW
#   This CompositorEffect implements both stages of the two-stage outline pipeline.
#
#   Stage 1 (Story 002): builds a per-pixel tier-mask texture (RGBA16F) by
#   running three graphics pipelines — one per outline tier T ∈ {1, 2, 3}.
#   Each pipeline uses RDPipelineDepthStencilState with enable_stencil = true
#   and front_op_reference = T, so the GPU's stencil-test hardware filters
#   fragments. Only pixels whose scene stencil equals T execute the fragment
#   shader, which writes a tier-marker float into the R channel:
#
#     Tier 1 (HEAVIEST) → R = 1.0000   (4 px outline — Eve, key interactives)
#     Tier 2 (MEDIUM)   → R = 0.6667   (2.5 px outline — PHANTOM guards)
#     Tier 3 (LIGHT)    → R = 0.3333   (1.5 px outline — environment, civilians)
#     No tier / Tier 0  → R = 0.0000   (no outline — retained from clear)
#
#   Stage 2 (Story 003): jump-flood compute shader reads the tier-mask and
#   writes outline pixels (#1A1A1A) to the scene color buffer. Algorithm:
#     1. Seed pass: interior pixels store own UV as nearest seed.
#     2. Jump passes (N = ceil(log2(max_radius_px))): 8-neighbour sample at
#        ±step_size; update nearest seed. Step size halves each pass.
#     3. Output pass: pixels within tier_radius of a seed AND not interior
#        receive outline_color in scene_color_texture.
#   ADR-0001 IG 7: naive scan is FORBIDDEN — jump-flood is mandatory.
#
# STENCIL READ PATTERN (Finding F5, ADR-0001)
#   The stencil aspect of the depth-stencil texture is NOT directly sampleable
#   from a compute shader in Godot 4.6. Stage 1 attaches the scene's
#   depth-stencil texture as the depth attachment of the framebuffer; the GPU
#   stencil-test hardware filters fragments based on the per-pipeline reference.
#
# CALLBACK TYPE
#   effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE ensures the stencil
#   buffer is populated (opaque geometry has rendered) and we run before
#   transparents and UI. Avoids first-frame stencil-read bug (GitHub #110629).
#
# PIPELINE CACHING
#   All RIDs (pipelines, shaders, framebuffer, textures) are cached in member
#   variables. A resize guard triggers a full rebuild on resolution change.
#   _rebuild_pipelines() is called lazily from _render_callback, NOT from _init,
#   because RenderSceneBuffersRD is only available during the render callback.
#
# PERFORMANCE BUDGET (ADR-0008 Slot 3)
#   CPU setup: < 0.1 ms per frame (pipeline dispatch overhead only).
#   GPU Stage 1: < 0.5 ms on Iris Xe at 75% render scale (3 fullscreen passes).
#   GPU Stage 2 (jump-flood): ~0.4 ms on Iris Xe at 75% scale (estimated).
#   Combined outline pass budget: <= 2.0 ms on Iris Xe per ADR-0008 Slot 3.
#   Measurement deferred to Story 005 (Plaza scene /perf-profile).
#
# CLEANUP
#   _notification(NOTIFICATION_PREDELETE) frees all cached RIDs to prevent the
#   RID-leak warnings seen in the spike's shutdown scenario.
#
# WIRING
#   Attach this resource to a Camera3D's Compositor for validation (Story 005).
#   Production wiring into PostProcessStack autoload is out of scope — that is
#   a PostProcessStack epic concern.
#   resolution_scale is a placeholder at 1.0; Story 004 wires the real
#   Events.setting_changed subscription.
#   # OUT-004: wire Events.setting_changed("graphics", "resolution_scale", ...)
#   # here to update resolution_scale and recompute per-tier radii each frame.

class_name OutlineCompositorEffect extends CompositorEffect


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Tier-marker values written to the R channel of the intermediate texture.
## Matches the stencil reference values in ADR-0001 §Decision.
## These constants drive the push constant encoding in _run_stencil_pass().
const TIER_MARKERS: Array[float] = [
	1.0,          # Tier 1 (HEAVIEST) — 4 px at 1080p
	2.0 / 3.0,    # Tier 2 (MEDIUM)   — 2.5 px at 1080p  ≈ 0.6667
	1.0 / 3.0,    # Tier 3 (LIGHT)    — 1.5 px at 1080p  ≈ 0.3333
]

## Path to the stencil-pass GLSL shader resource.
## Loaded as RDShaderFile; Godot's .glsl importer pre-compiles to SPIR-V at
## edit time (Finding F2, ADR-0001).
const _STENCIL_SHADER_PATH: String = \
	"res://src/rendering/outline/shaders/stencil_pass.glsl"

## Path to the jump-flood compute shader (Stage 2 — Story 003).
## Same .glsl importer pipeline as stencil_pass: SPIR-V pre-compiled at import.
const _JUMP_FLOOD_SHADER_PATH: String = \
	"res://src/rendering/outline/shaders/outline_jump_flood.glsl"

## Stage 1 push constant block size in bytes (std430 — one vec4, 16-byte aligned).
const _PUSH_CONSTANT_SIZE: int = 16

## Stage 2 push constant block size in bytes (std430, 48 bytes).
## Layout: int pass_type(4) + int step_size(4) + float×5(20) + float _align_pad(4) + vec4(16) = 48.
const _JUMP_FLOOD_PC_SIZE: int = 48

## Stage 2 pass_type values — must match GLSL constants in outline_jump_flood.glsl.
const _PASS_SEED:   int = 0
const _PASS_JUMP:   int = 1
const _PASS_OUTPUT: int = 2

## Base tier outline radii in pixels at 1080p reference (resolution_scale = 1.0).
## AC-3: these are multiplied by resolution_scale at dispatch time.
## Story 004 wires the real resolution_scale; VS uses 1.0.
const TIER1_RADIUS_PX_BASE: float = 4.0
const TIER2_RADIUS_PX_BASE: float = 2.5
const TIER3_RADIUS_PX_BASE: float = 1.5

## Outline color as RGBA. AC-4: must equal #1A1A1A (26/255 each channel).
## 26.0 / 255.0 = 0.10196... Stored as Color for convenience; converted to vec4
## in the push constant encoding.
const OUTLINE_COLOR: Color = Color(0.10196, 0.10196, 0.10196, 1.0)


# ---------------------------------------------------------------------------
# Cached RenderingDevice state
# (all RIDs are freed in _notification(NOTIFICATION_PREDELETE))
# ---------------------------------------------------------------------------

## The RenderingDevice obtained once at init time. Null in headless / non-RD
## render contexts; all render-callback logic is guarded by a null check.
var _rd: RenderingDevice

## Compiled stencil-pass shader RID. One shader serves all three tier pipelines.
var _stencil_shader: RID

## Per-tier graphics pipeline RIDs. Index 0 = Tier 1, 1 = Tier 2, 2 = Tier 3.
## Each pipeline bakes a different front_op_reference value.
var _tier_pipelines: Array[RID] = [RID(), RID(), RID()]

## Framebuffer RID combining the intermediate color texture + scene depth-stencil.
## Rebuilt on resize.
var _framebuffer: RID

## RGBA16F intermediate texture RID (the tier-mask written by Stage 1 and read
## by Stage 2's jump-flood compute shader). Rebuilt on resize.
var _intermediate_texture: RID

## Cached render resolution from the last _render_callback. Used to detect
## resize and trigger a pipeline rebuild.
var _cached_size: Vector2i = Vector2i.ZERO

## Cached depth-stencil texture RID from the last _render_callback. If Godot
## invalidates the RenderSceneBuffersRD between frames (e.g., scene reload),
## this changes and triggers a framebuffer rebuild.
var _cached_depth_texture: RID


# ---------------------------------------------------------------------------
# Stage 2 — jump-flood compute pipeline (Story 003)
# (all RIDs freed in _notification(NOTIFICATION_PREDELETE) / _free_cached_rids)
# ---------------------------------------------------------------------------

## Compiled jump-flood compute shader RID (shared across all dispatch passes).
var _jf_shader: RID

## Compute pipeline RID for the jump-flood shader.
var _jf_pipeline: RID

## Ping-pong seed buffers for the jump-flood passes.
## _jf_ping is written by the seed pass and read by the first jump pass.
## Ownership alternates each pass: the caller tracks which is current read/write.
var _jf_ping: RID
var _jf_pong: RID

## Resolution-scale multiplier for tier radii. Updated on the main thread by
## Events.setting_changed handler (OUT-004); read on the rendering thread by
## _render_callback. Single-float read/write is atomic in GDScript so no lock
## is needed between threads.
##
## Default 1.0 = native render resolution. Settings & Accessibility epic owns
## the Iris Xe (0.75 default) vs RTX 2060+ (1.0 default) auto-detection per
## ADR-0001 IG 6 + GDD AC-13. Until SettingsService exposes the real value,
## the lazy connect in _ensure_signal_connected reads it via Events broadcast.
var resolution_scale: float = 1.0

## Whether we have already connected to Events.setting_changed. Resources are
## not in the scene tree, so signal connections cannot live in _init (autoload
## may not be ready when the .tres is parsed). Lazy-connect on first
## _render_callback when the Events autoload is guaranteed to exist.
var _settings_signal_connected: bool = false

## Nearest-neighbour sampler RID used to bind _intermediate_texture as the
## tier_mask_texture sampler2D in Set 0 binding 0 of the jump-flood shader.
## Created once in _rebuild_pipelines; freed in _free_cached_rids.
var _jf_sampler: RID


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Initialises the CompositorEffect and caches the RenderingDevice reference.
##
## Sets effect_callback_type to POST_OPAQUE so the outline pass runs after
## opaque geometry (stencil buffer populated) and before transparents + UI.
## This prevents the first-frame stencil-read bug (GitHub issue #110629).
##
## Example:
##   [codeblock]
##   var outline_effect := OutlineCompositorEffect.new()
##   # Attach to a Camera3D Compositor resource in the scene.
##   [/codeblock]
func _init() -> void:
	# AC-5: POST_OPAQUE ensures the stencil buffer is populated before we read it.
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE

	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		# Headless / non-RD backend (e.g., Compatibility renderer, CI without GPU).
		# All render-callback logic is guarded; this is not an error in those
		# contexts, but it is unexpected on Vulkan builds.
		push_warning("OutlineCompositorEffect: no RenderingDevice — " +
			"stencil pipeline will not render. " +
			"Expected cause: headless mode or Compatibility renderer.")


func _notification(what: int) -> void:
	# NOTIFICATION_PREDELETE: free all cached RIDs before the object is destroyed.
	# Direct field access is used rather than a helper method because calling
	# methods on self at PREDELETE can intermittently fail if GDScript has
	# partially torn down the script state (same pattern as the verified spike).
	if what != NOTIFICATION_PREDELETE:
		return
	if _rd == null:
		return

	# Free shader first (pipelines depend on it but Vulkan reference-counts them)
	if _stencil_shader.is_valid():
		_rd.free_rid(_stencil_shader)
		_stencil_shader = RID()

	# Free per-tier pipelines
	for i: int in range(_tier_pipelines.size()):
		if _tier_pipelines[i].is_valid():
			_rd.free_rid(_tier_pipelines[i])
			_tier_pipelines[i] = RID()

	# Free framebuffer (holds references to color + depth attachments; freeing
	# it does not free the underlying textures — scene owns the depth texture)
	if _framebuffer.is_valid():
		_rd.free_rid(_framebuffer)
		_framebuffer = RID()

	# Free intermediate texture (we own this one)
	if _intermediate_texture.is_valid():
		_rd.free_rid(_intermediate_texture)
		_intermediate_texture = RID()

	# Free Stage 2 (jump-flood) resources.
	if _jf_pipeline.is_valid():
		_rd.free_rid(_jf_pipeline)
		_jf_pipeline = RID()

	if _jf_shader.is_valid():
		_rd.free_rid(_jf_shader)
		_jf_shader = RID()

	if _jf_ping.is_valid():
		_rd.free_rid(_jf_ping)
		_jf_ping = RID()

	if _jf_pong.is_valid():
		_rd.free_rid(_jf_pong)
		_jf_pong = RID()

	if _jf_sampler.is_valid():
		_rd.free_rid(_jf_sampler)
		_jf_sampler = RID()

	print("OutlineCompositorEffect: freed all cached RIDs (Stage 1 + Stage 2).")


# ---------------------------------------------------------------------------
# CompositorEffect entry point
# ---------------------------------------------------------------------------

## Render callback invoked by the Compositor once per frame.
##
## Performs an early-return (no work, no error) when:
##   - Called for a non-POST_OPAQUE callback type (Compositor routes multiple
##     types through the same method; the check guards against wrong-type calls)
##   - No RenderingDevice is available (headless / Compatibility renderer)
##   - The render scene buffers are unavailable or report a zero-size render target
##
## On the happy path:
##   1. Detects resize and triggers pipeline rebuild via _rebuild_pipelines().
##   2. Clears the intermediate texture.
##   3. Runs three stencil-test graphics passes (one per tier).
##
## [param effect_callback_type] The callback type dispatched by the Compositor.
## [param render_data] Frame render data providing access to scene buffers.
func _render_callback(effect_callback_type: int, render_data: RenderData) -> void:
	# AC-5: guard — only process the POST_OPAQUE callback.
	if effect_callback_type != CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE:
		return

	# AC-2 / headless safety: abort if no RenderingDevice (headless CI, Compat).
	if _rd == null:
		return

	# OUT-004: lazy-connect to Events.setting_changed on first render callback.
	# Resources are not in the scene tree, so connecting in _init can race with
	# autoload availability. By the time _render_callback fires, Events is up.
	_ensure_settings_signal_connected()

	var scene_buffers: RenderSceneBuffersRD = \
		render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if scene_buffers == null:
		push_warning("OutlineCompositorEffect: RenderSceneBuffersRD unavailable.")
		return

	var render_size: Vector2i = scene_buffers.get_internal_size()
	if render_size.x == 0 or render_size.y == 0:
		return

	var depth_texture: RID = scene_buffers.get_depth_layer(0)

	# Rebuild pipelines if resolution changed or scene buffer textures changed.
	var needs_rebuild: bool = (
		render_size != _cached_size
		or depth_texture != _cached_depth_texture
		or not _framebuffer.is_valid()
		or not _stencil_shader.is_valid()
	)

	if needs_rebuild:
		_cached_size = render_size
		_cached_depth_texture = depth_texture
		_rebuild_pipelines(render_size, depth_texture)

	# If pipeline build failed (shader load error, etc.), bail gracefully.
	if not _framebuffer.is_valid():
		return

	# Run one stencil-test pass per tier.
	for i: int in range(3):
		var tier: int = i + 1  # Tier values 1, 2, 3
		if not _tier_pipelines[i].is_valid():
			push_warning(
				"OutlineCompositorEffect: pipeline for tier %d is invalid; skipping." % tier
			)
			continue
		_run_stencil_pass(i, tier, i == 0)

	# --------------------------------------------------------------------------
	# Stage 2: jump-flood compute shader dispatch (Story 003)
	# --------------------------------------------------------------------------
	# Guard: Stage 2 RIDs must all be valid before we can dispatch.
	if not _jf_pipeline.is_valid() or not _jf_ping.is_valid() or not _jf_pong.is_valid():
		# Stage 2 pipeline was not built (shader load error or first-frame skip).
		# Stage 1 tier-mask is still produced; Stage 2 outline is silently skipped.
		push_warning("OutlineCompositorEffect: Stage 2 jump-flood pipeline invalid; skipping.")
		return

	# Acquire the scene color buffer that Stage 2 will write outline pixels to.
	var color_texture: RID = scene_buffers.get_color_layer(0)
	if not color_texture.is_valid():
		push_warning("OutlineCompositorEffect: scene color texture unavailable for Stage 2.")
		return

	# Compute per-tier radii via Formula 2 (OUT-004 AC-3, AC-4, AC-5).
	# kernel_actual = base × resolution_scale × (current_height / 1080), clamped to ≥0.5 px.
	# resolution_scale is updated on the main thread by Events.setting_changed handler;
	# the float read here is atomic so no lock is needed across threads.
	var current_height: int = render_size.y
	var t1_r: float = _compute_kernel_actual(TIER1_RADIUS_PX_BASE, resolution_scale, current_height)
	var t2_r: float = _compute_kernel_actual(TIER2_RADIUS_PX_BASE, resolution_scale, current_height)
	var t3_r: float = _compute_kernel_actual(TIER3_RADIUS_PX_BASE, resolution_scale, current_height)
	var max_radius: float = maxf(t1_r, maxf(t2_r, t3_r))

	# Number of jump passes: ceil(log2(max_radius_px)), minimum 1.
	var num_passes: int = pingpong_pass_count(max_radius)

	# Dispatch sizes: ceil(render_size / 8) workgroups in each dimension.
	var groups_x: int = ceili(float(render_size.x) / 8.0)
	var groups_y: int = ceili(float(render_size.y) / 8.0)

	# --- Seed pass (pass_type = 0) ---
	# Reads _intermediate_texture (tier-mask from Stage 1), writes seeds to _jf_ping.
	_dispatch_jump_flood_pass(
		_PASS_SEED,
		0,                   # step_size unused in seed pass
		render_size,
		t1_r, t2_r, t3_r,
		_intermediate_texture,
		color_texture,
		_jf_ping,            # seed_read (unused in seed pass — reads tier_mask)
		_jf_ping,            # seed_write: seed pass writes into ping
		groups_x, groups_y
	)

	# --- Jump passes (pass_type = 1) ---
	# Ping-pong: each pass reads from one buffer and writes to the other.
	# After N passes, the final result is in whichever buffer was last written.
	var read_buf: RID = _jf_ping
	var write_buf: RID = _jf_pong

	for i: int in range(num_passes):
		# step_size halves each pass. First pass: 2^(num_passes-1), last pass: 1.
		var step_size: int = int(pow(2.0, float(num_passes - 1 - i)))
		_dispatch_jump_flood_pass(
			_PASS_JUMP,
			step_size,
			render_size,
			t1_r, t2_r, t3_r,
			_intermediate_texture,
			color_texture,
			read_buf,
			write_buf,
			groups_x, groups_y
		)
		# Swap ping-pong for next iteration.
		var tmp: RID = read_buf
		read_buf = write_buf
		write_buf = tmp

	# --- Output pass (pass_type = 2) ---
	# read_buf now contains the final seed-distance field result.
	# Writes outline_color (#1A1A1A) to scene color buffer.
	_dispatch_jump_flood_pass(
		_PASS_OUTPUT,
		0,                   # step_size unused in output pass
		render_size,
		t1_r, t2_r, t3_r,
		_intermediate_texture,
		color_texture,
		read_buf,            # seed_read: final result
		write_buf,           # seed_write: unused in output pass
		groups_x, groups_y
	)


# ---------------------------------------------------------------------------
# Public accessors
# ---------------------------------------------------------------------------

## Returns the RID of the RGBA16F intermediate tier-mask texture.
##
## Story 003's jump-flood compute shader binds this texture as its input.
## The RID is valid only after the first _render_callback has executed and
## _rebuild_pipelines has succeeded. Returns an invalid RID if the pipeline
## has not yet been built (e.g., before the first frame or after a resize).
##
## Example:
##   [codeblock]
##   var tier_mask_rid: RID = outline_effect.get_intermediate_texture_rid()
##   if tier_mask_rid.is_valid():
##       # Bind to jump-flood compute shader uniform set.
##   [/codeblock]
func get_intermediate_texture_rid() -> RID:
	return _intermediate_texture


## Returns the number of jump-flood ping-pong passes needed for the given
## maximum outline radius in pixels.
##
## Formula: max(1, ceil(log2(max_radius_px)))
## Clamps to a minimum of 1 pass so that outlines up to 1 px wide are
## always drawn. Defensive against zero and negative inputs (returns 1).
##
## This is the testable AC-2 logic facet for Story 003.
##
## Examples:
##   pingpong_pass_count(4.0) → 2   (ceil(log2(4)) = ceil(2.0) = 2)
##   pingpong_pass_count(2.5) → 2   (ceil(log2(2.5)) = ceil(1.32) = 2)
##   pingpong_pass_count(1.5) → 1   (ceil(log2(1.5)) = ceil(0.58) = 1)
##   pingpong_pass_count(8.0) → 3   (ceil(log2(8)) = ceil(3.0) = 3)
##   pingpong_pass_count(1.0) → 1   (log2(1) = 0; clamp to min 1)
##   pingpong_pass_count(0.0) → 1   (defensive clamp — avoid log2(0))
##   pingpong_pass_count(-5.0) → 1  (defensive clamp — avoid log2(negative))
##
## [param max_radius_px] Maximum outline radius in pixels. Values ≤ 0 return 1.
## [return] Number of ping-pong jump passes (always ≥ 1).
func pingpong_pass_count(max_radius_px: float) -> int:
	if max_radius_px <= 0.0:
		# Defensive clamp: log2 of zero or negative is undefined.
		# Minimum 1 pass ensures the output pass has at least one seed propagation.
		return 1
	# GDScript has no log2 global — derive from natural log: log2(x) = log(x) / log(2).
	return maxi(1, ceili(log(max_radius_px) / log(2.0)))


## Computes the actual outline kernel radius in pixels for a given base tier
## radius, the current resolution_scale setting, and the current internal
## render-target height. This is GDD §Formulas Formula 2.
##
## kernel_actual = max(0.5, kernel_px × res_scale × (render_height / 1080))
##
## The 0.5 px minimum clamp prevents sub-pixel outlines that would render as
## nothing in 8-bit color space (per GDD §Formulas "minimum 0.5 px" clause).
##
## Static and pure — testable without instantiating the effect or a GPU context.
##
## Examples:
##   _compute_kernel_actual(4.0, 1.0, 1080)  → 4.0    (native 1080p)
##   _compute_kernel_actual(2.5, 0.75, 1080) → 1.875  (75% scale, no height delta)
##   _compute_kernel_actual(1.5, 0.4, 540)   → 0.5    (clamped from 0.3)
##   _compute_kernel_actual(4.0, 1.0, 1440)  → 5.333  (1440p scale-up)
##   _compute_kernel_actual(0.0, 1.0, 1080)  → 0.5    (zero base → minimum)
##
## [param kernel_px] Base radius at 1080p reference (one of TIER*_RADIUS_PX_BASE)
## [param res_scale] Player's resolution_scale setting (0.0–2.0 range expected)
## [param render_height] Current internal render-target height in pixels
## [return] Actual kernel radius for the jump-flood shader uniform, ≥0.5 px
static func _compute_kernel_actual(
	kernel_px: float,
	res_scale: float,
	render_height: int
) -> float:
	# Defensive: divide-by-zero guard. render_height should never be 0 in
	# practice (Godot's render-target is at least 1 px), but a malicious or
	# malformed scene could theoretically produce 0; clamp to 1 to avoid NaN.
	var safe_height: int = maxi(1, render_height)
	var raw: float = kernel_px * res_scale * (float(safe_height) / 1080.0)
	return maxf(raw, 0.5)


## Lazy-connects to Events.setting_changed on first _render_callback. Idempotent.
##
## Resources are not in the scene tree, so this cannot live in _init: the
## Events autoload may not yet be constructed when an OutlineCompositorEffect
## is instantiated as a sub-resource. By the time _render_callback fires we
## are well past autoload boot, so the connection is guaranteed safe.
func _ensure_settings_signal_connected() -> void:
	if _settings_signal_connected:
		return
	if Events == null:
		return
	# Connect the AC-2 handler. Safe to call once; idempotency is guaranteed by
	# the bool flag plus the is_connected guard.
	if not Events.setting_changed.is_connected(_on_setting_changed):
		Events.setting_changed.connect(_on_setting_changed)
	_settings_signal_connected = true


## Handles Events.setting_changed broadcasts. Updates resolution_scale when the
## graphics/resolution_scale setting changes; ignores all other categories/names.
##
## AC-2: validates `value is float` before assignment so a malformed broadcast
## (e.g., "not_a_float" payload) does NOT corrupt resolution_scale. Wrong
## category (e.g., &"audio") is silently ignored.
##
## Reference: ADR-0005 IG 4 — HandsOutlineMaterial subscribes to the same signal
## (see Player Character epic FPS hands story).
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
	if category != &"graphics":
		return
	if name != &"resolution_scale":
		return
	if not (value is float):
		return
	resolution_scale = value as float


# ---------------------------------------------------------------------------
# Stage 2 — jump-flood dispatch (full GPU command stream)
# ---------------------------------------------------------------------------

## Dispatch a single jump-flood compute pass.
##
## Builds a per-pass uniform set (Set 0: tier-mask + scene color; Set 1:
## ping-pong seed buffers), encodes the 48-byte std430 push-constant block,
## opens a compute list, dispatches `groups_x × groups_y × 1` workgroups,
## inserts a memory barrier, and closes the list. The barrier serialises
## image writes between successive jump-flood passes so seed propagation is
## correct.
##
## Push-constant byte layout matches the GLSL `Params` block in
## `outline_jump_flood.glsl`. UniformSetCacheRD memoises the per-frame
## uniform sets so repeat dispatches with identical bindings reuse the
## same RID without per-frame allocation.
##
## [param pass_type] One of _PASS_SEED, _PASS_JUMP, _PASS_OUTPUT
## [param step_size] Pixel offset for jump pass; 0 for seed/output passes
## [param render_size] Render-target dimensions in pixels
## [param t1_r] Tier 1 radius in pixels (after resolution_scale)
## [param t2_r] Tier 2 radius in pixels (after resolution_scale)
## [param t3_r] Tier 3 radius in pixels (after resolution_scale)
## [param tier_mask_rid] Stage 1 RGBA16F intermediate texture (read-only input)
## [param color_target_rid] Scene color buffer (output for _PASS_OUTPUT only)
## [param seed_read_rid] Ping-pong read source
## [param seed_write_rid] Ping-pong write target
## [param groups_x] Workgroup count X (= ceil(render_size.x / 8))
## [param groups_y] Workgroup count Y (= ceil(render_size.y / 8))
func _dispatch_jump_flood_pass(
	_pass_type: int,
	_step_size: int,
	_render_size: Vector2i,
	_t1_r: float,
	_t2_r: float,
	_t3_r: float,
	_tier_mask_rid: RID,
	_color_target_rid: RID,
	_seed_read_rid: RID,
	_seed_write_rid: RID,
	_groups_x: int,
	_groups_y: int
) -> void:
	# Headless / no-RD guard — should not be reached (caller guards too), but
	# defensive here in case _dispatch_jump_flood_pass is called standalone.
	if _rd == null:
		return

	# --- Set 0: tier_mask_texture (sampler2D, binding 0) + scene_color_texture
	#            (image2D, binding 1). Same for all three pass types.
	#
	# binding 0: SAMPLER_WITH_TEXTURE — pairs the linear sampler with the Stage 1
	#            tier-mask RGBA16F texture. The shader reads it via texelFetch in the
	#            seed pass and output pass; the sampler is still required for the
	#            SAMPLER_WITH_TEXTURE uniform type even though no filtering is used.
	var tier_mask_uniform := RDUniform.new()
	tier_mask_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	tier_mask_uniform.binding = 0
	tier_mask_uniform.add_id(_jf_sampler)
	tier_mask_uniform.add_id(_tier_mask_rid)

	# binding 1: IMAGE — scene color buffer. Writable only in the output pass;
	# the GLSL declares it restrict, so the driver may optimise for write-only in
	# non-OUTPUT passes where do_seed_pass / do_jump_pass never call imageStore on it.
	var scene_color_uniform := RDUniform.new()
	scene_color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	scene_color_uniform.binding = 1
	scene_color_uniform.add_id(_color_target_rid)

	# UniformSetCacheRD manages per-frame uniform set lifetime automatically.
	# The cache keyed on (shader, set_index, uniforms) so identical bindings across
	# passes reuse the same set without allocating a new RID each frame.
	var set0: RID = UniformSetCacheRD.get_cache(
		_jf_shader, 0, [tier_mask_uniform, scene_color_uniform]
	)
	if not set0.is_valid():
		push_error(
			"OutlineCompositorEffect: failed to create Set 0 uniform set for pass_type=%d."
			% _pass_type
		)
		return

	# --- Set 1: ping-pong seed buffers (image2D, bindings 0 and 1). Swapped
	#     per-pass by the caller: seed pass writes to ping, jump passes alternate,
	#     output pass reads the final result.
	var seed_read_uniform := RDUniform.new()
	seed_read_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	seed_read_uniform.binding = 0
	seed_read_uniform.add_id(_seed_read_rid)

	var seed_write_uniform := RDUniform.new()
	seed_write_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	seed_write_uniform.binding = 1
	seed_write_uniform.add_id(_seed_write_rid)

	var set1: RID = UniformSetCacheRD.get_cache(
		_jf_shader, 1, [seed_read_uniform, seed_write_uniform]
	)
	if not set1.is_valid():
		push_error(
			"OutlineCompositorEffect: failed to create Set 1 uniform set for pass_type=%d."
			% _pass_type
		)
		return

	# --- Push constant (48 bytes, std430 — must match outline_jump_flood.glsl
	#     Params block exactly).
	#
	# Byte layout:
	#   offset  0: int   pass_type       (encode_s32)
	#   offset  4: int   step_size       (encode_s32)
	#   offset  8: float frame_width     (encode_float)
	#   offset 12: float frame_height    (encode_float)
	#   offset 16: float tier1_radius_px (encode_float)
	#   offset 20: float tier2_radius_px (encode_float)
	#   offset 24: float tier3_radius_px (encode_float)
	#   offset 28: float _align_pad      (encode_float, 0.0)
	#   offset 32: vec4  outline_color   (4 × encode_float)
	var pc := PackedByteArray()
	pc.resize(_JUMP_FLOOD_PC_SIZE)
	pc.encode_s32(0,  _pass_type)
	pc.encode_s32(4,  _step_size)
	pc.encode_float(8,  float(_render_size.x))
	pc.encode_float(12, float(_render_size.y))
	pc.encode_float(16, _t1_r)
	pc.encode_float(20, _t2_r)
	pc.encode_float(24, _t3_r)
	pc.encode_float(28, 0.0)              # _align_pad: must be 0.0 (reserved)
	pc.encode_float(32, OUTLINE_COLOR.r)
	pc.encode_float(36, OUTLINE_COLOR.g)
	pc.encode_float(40, OUTLINE_COLOR.b)
	pc.encode_float(44, OUTLINE_COLOR.a)

	# --- Dispatch: one compute list per pass.
	#
	# Each call to _dispatch_jump_flood_pass opens its own compute list and
	# appends a memory barrier (compute_list_add_barrier) before closing it.
	# This ensures the write from pass N is fully visible to the image reads of
	# pass N+1, preventing read-after-write hazards in the ping-pong chain:
	#   SEED writes _jf_ping → barrier → JUMP reads _jf_ping, writes _jf_pong
	#   → barrier → next JUMP or OUTPUT reads _jf_pong / _jf_ping.
	#
	# Note: compute_list_add_barrier is a Godot 4.5+ API (confirmed available
	# in 4.6). It inserts a Vulkan pipeline barrier synchronising the compute
	# stage with itself before the list is ended.
	var cl: int = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _jf_pipeline)
	_rd.compute_list_bind_uniform_set(cl, set0, 0)
	_rd.compute_list_bind_uniform_set(cl, set1, 1)
	_rd.compute_list_set_push_constant(cl, pc, pc.size())
	_rd.compute_list_dispatch(cl, _groups_x, _groups_y, 1)
	# Memory barrier: ensure the imageStore writes from this dispatch are visible
	# to the imageLoad reads of the next dispatch. Required for correct ping-pong.
	_rd.compute_list_add_barrier(cl)
	_rd.compute_list_end()


# ---------------------------------------------------------------------------
# Private — pipeline construction
# ---------------------------------------------------------------------------

## Builds or rebuilds the stencil-pass shader, three tier pipelines, and
## the RGBA16F intermediate texture for the given render resolution.
##
## Called lazily from _render_callback when a resize is detected or on the
## first frame. Frees existing RIDs before recreating them.
##
## [param render_size] Current render-target dimensions in pixels.
## [param depth_texture] Scene depth-stencil texture RID from RenderSceneBuffersRD.
func _rebuild_pipelines(render_size: Vector2i, depth_texture: RID) -> void:
	# Free previously built resources before recreating.
	_free_cached_rids()

	# Load and compile the stencil-pass shader from the pre-baked SPIR-V.
	var shader_file: RDShaderFile = ResourceLoader.load(_STENCIL_SHADER_PATH) \
		as RDShaderFile
	if shader_file == null:
		push_error(
			"OutlineCompositorEffect: failed to load shader at '%s'. " % _STENCIL_SHADER_PATH +
			"Ensure the file exists and Godot's .glsl importer has run."
		)
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	if spirv == null:
		push_error(
			"OutlineCompositorEffect: get_spirv() returned null for '%s'." \
			% _STENCIL_SHADER_PATH
		)
		return

	_stencil_shader = _rd.shader_create_from_spirv(spirv)
	if not _stencil_shader.is_valid():
		push_error("OutlineCompositorEffect: shader_create_from_spirv() failed.")
		return

	# Create the RGBA16F intermediate texture.
	# Usage bits: color attachment (written by Stage 1 graphics pipelines) +
	# sampling (read by Stage 2 compute shader) + storage (image2D binding) +
	# copy-to (debug screenshot support per QA plan AC-6 debug mode).
	var tex_format: RDTextureFormat = RDTextureFormat.new()
	tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_format.width = render_size.x
	tex_format.height = render_size.y
	tex_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tex_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	_intermediate_texture = _rd.texture_create(tex_format, RDTextureView.new())
	if not _intermediate_texture.is_valid():
		push_error("OutlineCompositorEffect: failed to create intermediate texture.")
		return

	# Build the framebuffer format combining intermediate color + scene depth-stencil.
	# The depth attachment is the scene's existing depth-stencil texture — we do
	# NOT create a new depth buffer (zero memory overhead, per ADR-0001 §Performance).
	var color_af: RDAttachmentFormat = RDAttachmentFormat.new()
	var color_fmt: RDTextureFormat = _rd.texture_get_format(_intermediate_texture)
	color_af.format = color_fmt.format
	color_af.usage_flags = color_fmt.usage_bits
	color_af.samples = RenderingDevice.TEXTURE_SAMPLES_1

	var depth_af: RDAttachmentFormat = RDAttachmentFormat.new()
	var depth_fmt: RDTextureFormat = _rd.texture_get_format(depth_texture)
	depth_af.format = depth_fmt.format
	depth_af.usage_flags = depth_fmt.usage_bits
	depth_af.samples = RenderingDevice.TEXTURE_SAMPLES_1

	var fb_format: int = _rd.framebuffer_format_create([color_af, depth_af])
	_framebuffer = _rd.framebuffer_create(
		[_intermediate_texture, depth_texture],
		fb_format
	)
	if not _framebuffer.is_valid():
		push_error("OutlineCompositorEffect: framebuffer_create() failed.")
		return

	# Build one stencil-test graphics pipeline per tier.
	for i: int in range(3):
		var tier: int = i + 1
		_tier_pipelines[i] = _build_tier_pipeline(tier, fb_format)
		if not _tier_pipelines[i].is_valid():
			push_error(
				"OutlineCompositorEffect: pipeline build failed for tier %d." % tier
			)

	# -------------------------------------------------------------------------
	# Stage 2: build the jump-flood compute pipeline and ping-pong textures.
	# -------------------------------------------------------------------------
	# Load the jump-flood compute shader.
	var jf_shader_file: RDShaderFile = \
		ResourceLoader.load(_JUMP_FLOOD_SHADER_PATH) as RDShaderFile
	if jf_shader_file == null:
		push_error(
			"OutlineCompositorEffect: failed to load jump-flood shader at '%s'. " \
			% _JUMP_FLOOD_SHADER_PATH +
			"Ensure the file exists and the .glsl importer has run (Finding G4)."
		)
		return

	var jf_spirv: RDShaderSPIRV = jf_shader_file.get_spirv()
	if jf_spirv == null:
		push_error(
			"OutlineCompositorEffect: get_spirv() returned null for '%s'." \
			% _JUMP_FLOOD_SHADER_PATH
		)
		return

	_jf_shader = _rd.shader_create_from_spirv(jf_spirv)
	if not _jf_shader.is_valid():
		push_error("OutlineCompositorEffect: shader_create_from_spirv() failed for jump-flood.")
		return

	_jf_pipeline = _rd.compute_pipeline_create(_jf_shader)
	if not _jf_pipeline.is_valid():
		push_error("OutlineCompositorEffect: compute_pipeline_create() failed for jump-flood.")
		return

	# Create the two ping-pong RGBA16F textures for the jump-flood seed buffers.
	# Each texel stores (seed_uv.x, seed_uv.y, tier_marker, 0.0).
	# Usage: STORAGE_BIT (image2D read+write) + SAMPLING_BIT (sampler2D read).
	var pp_fmt: RDTextureFormat = RDTextureFormat.new()
	pp_fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	pp_fmt.width  = render_size.x
	pp_fmt.height = render_size.y
	pp_fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	pp_fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	_jf_ping = _rd.texture_create(pp_fmt, RDTextureView.new())
	if not _jf_ping.is_valid():
		push_error("OutlineCompositorEffect: failed to create jump-flood ping texture.")
		return

	_jf_pong = _rd.texture_create(pp_fmt, RDTextureView.new())
	if not _jf_pong.is_valid():
		push_error("OutlineCompositorEffect: failed to create jump-flood pong texture.")
		return

	# Create a nearest-neighbour sampler for binding _intermediate_texture as
	# the tier_mask_texture sampler2D (Set 0, binding 0) in the jump-flood shader.
	# The shader reads tier_mask via texelFetch (integer coordinates), so filtering
	# mode does not affect output — but Vulkan requires a valid sampler RID when
	# the descriptor type is COMBINED_IMAGE_SAMPLER (UNIFORM_TYPE_SAMPLER_WITH_TEXTURE).
	# SAMPLER_FILTER_NEAREST avoids any filtering artefacts on the tier-mask edges.
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u   = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v   = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_w   = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_jf_sampler = _rd.sampler_create(sampler_state)
	if not _jf_sampler.is_valid():
		push_error("OutlineCompositorEffect: failed to create jump-flood tier-mask sampler.")
		return


## Creates a graphics pipeline for one outline tier with the correct stencil-test
## state baked in.
##
## The pipeline uses:
##   - enable_stencil = true          : enable per-fragment stencil test
##   - front_op_compare = EQUAL       : pass only if scene stencil == reference
##   - front_op_reference = [tier]    : the tier value written by materials
##   - front_op_compare_mask = 0xFF   : compare all 8 stencil bits
##   - front_op_write_mask = 0x00     : read-only — do NOT overwrite scene stencil
##   - front_op_fail/pass/depth_fail  : KEEP — never modify the stencil buffer
##
## Vertex format: an empty format (no attributes) is created so the vertex
## shader can use gl_VertexIndex to reconstruct the fullscreen triangle without
## any vertex buffer. draw_list_draw(false, 3) provides the 3 vertex invocations.
##
## [param tier] Stencil reference value (1, 2, or 3).
## [param framebuffer_format] Framebuffer format integer from framebuffer_format_create().
## [return] Valid pipeline RID on success; invalid RID if render_pipeline_create fails.
func _build_tier_pipeline(tier: int, framebuffer_format: int) -> RID:
	var depth_stencil: RDPipelineDepthStencilState = RDPipelineDepthStencilState.new()
	# AC-2: stencil-test settings mandated by ADR-0001 §Key Interfaces.
	depth_stencil.enable_stencil = true
	depth_stencil.front_op_compare = RenderingDevice.COMPARE_OP_EQUAL
	depth_stencil.front_op_reference = tier
	depth_stencil.front_op_compare_mask = 0xFF
	# Write mask = 0x00 — this pass MUST NOT overwrite the scene stencil buffer.
	# The stencil was written by object materials (OutlineTier.set_tier) and must
	# remain intact for all three tier passes.
	depth_stencil.front_op_write_mask = 0x00
	# KEEP on all operations: even if the test passes or fails, never mutate stencil.
	depth_stencil.front_op_fail = RenderingDevice.STENCIL_OP_KEEP
	depth_stencil.front_op_pass = RenderingDevice.STENCIL_OP_KEEP
	depth_stencil.front_op_depth_fail = RenderingDevice.STENCIL_OP_KEEP

	# Standard opaque color blend — single attachment, no blending.
	# The fragment shader writes unconditionally; pixels failing the stencil test
	# never reach the fragment shader and leave the intermediate texture unchanged.
	var blend: RDPipelineColorBlendState = RDPipelineColorBlendState.new()
	var blend_attachment: RDPipelineColorBlendStateAttachment = \
		RDPipelineColorBlendStateAttachment.new()
	blend.attachments.push_back(blend_attachment)

	# Empty vertex format: no vertex attributes. The vertex shader uses
	# gl_VertexIndex to reconstruct the fullscreen triangle. vertex_format_create
	# with an empty array gives a format handle with no attribute slots;
	# draw_list_draw(false, 3) invokes the vertex shader 3 times without binding
	# a vertex array (use draw_list_draw instead of draw_list_bind_vertex_array).
	var vertex_format: int = _rd.vertex_format_create([])

	return _rd.render_pipeline_create(
		_stencil_shader,
		framebuffer_format,
		vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),
		RDPipelineMultisampleState.new(),
		depth_stencil,
		blend,
	)


# ---------------------------------------------------------------------------
# Private — per-frame pass execution
# ---------------------------------------------------------------------------

## Executes one stencil-test graphics pass for the given tier index.
##
## On the first pass (is_first_pass = true), the intermediate texture is cleared
## to vec4(0.0) so previous frame data does not bleed into the new tier-mask.
## Subsequent passes load the existing intermediate texture content and draw
## their tier's pixels on top (stencil test ensures no overlap between tiers).
##
## draw_list_begin call matches the Godot 4.6.2 verified spike signature:
##   (framebuffer, initial_color_action, clear_color_values,
##    clear_depth, clear_stencil, region, breadcrumb)
## Ref: prototypes/verification-spike/stencil_compositor_outline.gd (4.6.2 verified)
## Breaking-changes note: Godot 4.4 removed several parameters and added
## breadcrumb; this call pattern was validated against 4.6.2 in Sprint 01.
##
## [param pipeline_index] Array index into _tier_pipelines (0, 1, or 2).
## [param tier] Stencil reference value (1, 2, or 3) — used to look up the
##              tier_marker in TIER_MARKERS.
## [param is_first_pass] True for the first tier pass (tier 1); clears the
##                       intermediate texture before drawing.
func _run_stencil_pass(pipeline_index: int, tier: int, is_first_pass: bool) -> void:
	# DRAW_CLEAR_COLOR_0 (0x1) on first pass clears the intermediate texture to
	# vec4(0,0,0,0) before any tier markers are written.
	# 0 (no-clear / load) on subsequent passes preserves previously written pixels.
	# Depth attachment action: 0 = load existing depth-stencil (we must not clear
	# the scene's stencil buffer — that would erase the tier markers we're reading).
	var color_action: int = RenderingDevice.DRAW_CLEAR_COLOR_0 if is_first_pass else 0
	# GDScript 4.6 typed-array inference: a ternary expression mixing
	# `[Color(...)]` and `[]` resolves to untyped `Array`, which cannot be
	# assigned to `Array[Color]`. Initialize empty + conditionally append.
	var clear_color_values: Array[Color] = []
	if is_first_pass:
		clear_color_values.append(Color(0.0, 0.0, 0.0, 0.0))

	var draw_list: int = _rd.draw_list_begin(
		_framebuffer,
		color_action,
		clear_color_values,
		1.0,                              # clear_depth (unused: depth attachment is loaded)
		0,                                # clear_stencil (unused: stencil is loaded, not cleared)
		Rect2(),                          # region: empty = full framebuffer
		RenderingDevice.OPAQUE_PASS,      # breadcrumb for Vulkan debug markers (Godot 4.4+)
	)

	_rd.draw_list_bind_render_pipeline(draw_list, _tier_pipelines[pipeline_index])

	# Push constant: tier_marker float + 12 bytes padding to reach 16-byte alignment.
	# Encoding matches the GLSL push_constant block in stencil_pass.glsl:
	#   layout(push_constant, std430) uniform Params { float tier_marker; float _pad[3]; }
	var push_constant: PackedByteArray = PackedByteArray()
	push_constant.resize(_PUSH_CONSTANT_SIZE)
	push_constant.encode_float(0, TIER_MARKERS[pipeline_index])
	# Padding bytes 4-15 are left as zero (PackedByteArray zero-initialises).
	_rd.draw_list_set_push_constant(draw_list, push_constant, push_constant.size())

	# Draw 3 vertices — no vertex buffer. The vertex shader reconstructs the
	# fullscreen triangle from gl_VertexIndex (0, 1, 2).
	_rd.draw_list_draw(draw_list, false, 3)
	_rd.draw_list_end()


# ---------------------------------------------------------------------------
# Private — RID cleanup helper
# ---------------------------------------------------------------------------

## Frees all currently cached rendering RIDs without resetting _rd.
## Called at the start of _rebuild_pipelines to release stale resources
## before recreating them at the new resolution. Covers both Stage 1 and
## Stage 2 RIDs so that a resize rebuild is always clean.
func _free_cached_rids() -> void:
	if _rd == null:
		return

	# Stage 1 cleanup.
	if _stencil_shader.is_valid():
		_rd.free_rid(_stencil_shader)
		_stencil_shader = RID()

	for i: int in range(_tier_pipelines.size()):
		if _tier_pipelines[i].is_valid():
			_rd.free_rid(_tier_pipelines[i])
			_tier_pipelines[i] = RID()

	if _framebuffer.is_valid():
		_rd.free_rid(_framebuffer)
		_framebuffer = RID()

	if _intermediate_texture.is_valid():
		_rd.free_rid(_intermediate_texture)
		_intermediate_texture = RID()

	# Stage 2 cleanup.
	if _jf_pipeline.is_valid():
		_rd.free_rid(_jf_pipeline)
		_jf_pipeline = RID()

	if _jf_shader.is_valid():
		_rd.free_rid(_jf_shader)
		_jf_shader = RID()

	if _jf_ping.is_valid():
		_rd.free_rid(_jf_ping)
		_jf_ping = RID()

	if _jf_pong.is_valid():
		_rd.free_rid(_jf_pong)
		_jf_pong = RID()

	if _jf_sampler.is_valid():
		_rd.free_rid(_jf_sampler)
		_jf_sampler = RID()
