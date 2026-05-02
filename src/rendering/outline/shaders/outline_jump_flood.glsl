// src/rendering/outline/shaders/outline_jump_flood.glsl
//
// Stage 2 jump-flood compute shader for the OutlineCompositorEffect.
//
// Requirements: TR-OUT-003, TR-OUT-006, TR-OUT-008
// Governing ADR: ADR-0001 (Stencil ID Contract for Tiered Outline Rendering)
//               ADR-0008 (Performance Budget Distribution — Slot 3)
//
// ---------------------------------------------------------------------------
// ALGORITHM: Jump-Flood Distance Field (Bgolus "Wide Outlines" approach)
// ---------------------------------------------------------------------------
// Reference implementation: dmlary/godot-stencil-based-outline-compositor-effect
//   https://github.com/dmlary/godot-stencil-based-outline-compositor-effect
//   License: MIT
//
// Algorithm description (Bgolus jump-flood blog post):
//   https://bgolus.medium.com/the-quest-for-very-wide-outlines-ba82ed442cd9
//
// The naive (2·max_radius_px+1)² scan is FORBIDDEN per ADR-0001 IG 7. It was
// measured at ~0.92 ms on RTX 4070 at 1080p (Sprint 01 Finding F6) and
// extrapolated to ~6.4 ms on Intel Iris Xe at 1080p native, exceeding the
// 2.0 ms ADR-0008 Slot 3 budget. Jump-flood is estimated at ~0.4 ms on Iris
// Xe at 75% scale — well within budget.
//
// ---------------------------------------------------------------------------
// THREE-PASS DESIGN (single shader, pass_type selector)
// ---------------------------------------------------------------------------
// This file compiles to ONE compute shader (one SPIR-V). OutlineCompositorEffect
// dispatches it three ways by setting `pass_type` in the push constant:
//
//   pass_type = 0 (PASS_SEED):
//     Reads tier_mask_texture, writes INVALID_UV sentinel or own-UV seed into
//     seed_write ping-pong buffer.
//
//   pass_type = 1 (PASS_JUMP):
//     Reads seed_read ping buffer, samples 8 neighbours at ±step_size,
//     keeps nearest valid seed, writes to seed_write buffer.
//     Dispatched ceil(log2(max_radius_px)) times with halving step_size.
//
//   pass_type = 2 (PASS_OUTPUT):
//     Reads final seed_read buffer, re-reads tier_mask_texture for the current
//     pixel, and writes outline_color to scene_color_texture for all pixels
//     that are (a) within tier_radius of a seed AND (b) not interior to that tier.
//
// This avoids the need for three separate shader files while keeping all logic
// in one maintainable location.
//
// ---------------------------------------------------------------------------
// PING-PONG REPRESENTATION
// ---------------------------------------------------------------------------
// Two RGBA16F textures serve as ping-pong buffers (set=1, binding=0 and 1).
// Each pixel stores: vec4(seed_uv.x, seed_uv.y, tier_marker, 0.0)
//   seed_uv.xy  — UV coordinates [0,1]² of the nearest tier-marked pixel found
//                 so far. (-1.0, -1.0) is the INVALID sentinel (no seed yet).
//   tier_marker — tier encoding of the nearest seed pixel:
//                   1.0000 = Tier 1 HEAVIEST
//                   0.6667 = Tier 2 MEDIUM
//                   0.3333 = Tier 3 LIGHT
//                   0.0    = no valid seed
//   .w          — reserved / unused.
//
// A single RGBA16F pair is used (rather than separate RG16F + R8) so that all
// seed data is retrieved in one texel read per neighbour sample, reducing
// memory bandwidth and keeping binding count within set limits.
//
// ---------------------------------------------------------------------------
// GLOW NOTE (Godot 4.6)
// ---------------------------------------------------------------------------
// NOTE: Godot 4.6 glow runs BEFORE tonemapping. Art Bible 8J item 7 disables
// glow in this project — outline pixels are NOT subject to glow bloom. If glow
// is re-enabled in the future, outline pixels may bloom; verify and re-disable
// glow (or add an exclusion mask) if needed.
//
// ---------------------------------------------------------------------------
// TIER MARKERS (must match OutlineCompositorEffect.TIER_MARKERS)
// ---------------------------------------------------------------------------
//   Tier 1 HEAVIEST → R = 1.0000   (4 px outline — Eve, key interactives)
//   Tier 2 MEDIUM   → R = 0.6667   (2.5 px outline — PHANTOM guards)
//   Tier 3 LIGHT    → R = 0.3333   (1.5 px outline — environment, civilians)
//   Tier 0 / none   → R = 0.0000   (no outline; left at cleared value)

#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// ---------------------------------------------------------------------------
// Bindings — Set 0: primary inputs / output (all passes)
// ---------------------------------------------------------------------------

// Tier-mask texture produced by Stage 1 (stencil_pass.glsl).
// R channel = tier_marker float. Used by seed pass and output pass.
// Sampled at integer texel coordinates (texelFetch) — no filtering needed.
layout(set = 0, binding = 0) uniform sampler2D tier_mask_texture;

// Scene color buffer (read+write). Output pass writes outline_color here
// for exterior pixels within the outline band. Other passes leave it unchanged.
// AC-1: layout format matches the RGBA16F intermediate tier-mask format.
layout(set = 0, binding = 1, rgba16f) uniform restrict image2D scene_color_texture;

// ---------------------------------------------------------------------------
// Bindings — Set 1: ping-pong seed buffers (swapped each pass)
// ---------------------------------------------------------------------------

// Read buffer for the current pass (caller swaps set 1 bindings each dispatch).
layout(set = 1, binding = 0, rgba16f) uniform restrict readonly image2D seed_read;

// Write buffer for the current pass.
layout(set = 1, binding = 1, rgba16f) uniform restrict image2D seed_write;

// ---------------------------------------------------------------------------
// Push constants
// ---------------------------------------------------------------------------
// OutlineCompositorEffect sets these before each dispatch. std430 layout.
//
// Memory layout (std430, offsets in bytes):
//   offset  0: int   pass_type        (4 bytes)
//   offset  4: int   step_size        (4 bytes)
//   offset  8: float frame_width      (4 bytes)
//   offset 12: float frame_height     (4 bytes)
//   offset 16: float tier1_radius_px  (4 bytes)
//   offset 20: float tier2_radius_px  (4 bytes)
//   offset 24: float tier3_radius_px  (4 bytes)
//   offset 28: float _align_pad       (4 bytes — pads to vec4 alignment at 32)
//   offset 32: vec4  outline_color    (16 bytes — vec4 requires 16-byte alignment)
//   Total: 48 bytes (multiple of 16 — valid Vulkan push constant block).
layout(push_constant, std430) uniform Params {
    // Selects the pass to run:
    //   0 (PASS_SEED)   — initialise ping buffer from tier_mask_texture
    //   1 (PASS_JUMP)   — propagate nearest seeds at ±step_size offset
    //   2 (PASS_OUTPUT) — write outline_color to scene_color_texture
    int  pass_type;

    // Jump pass: current step size in pixels (halves each iteration).
    // Set to 0 for seed pass and output pass (not used).
    int  step_size;

    // Render target dimensions in pixels (used for UV ↔ pixel conversion).
    float frame_width;
    float frame_height;

    // Per-tier outline radii in pixels at the current resolution.
    // AC-3: set from TIER[1|2|3]_RADIUS_PX_BASE × resolution_scale by
    // OutlineCompositorEffect. For VS (story 003) resolution_scale = 1.0.
    float tier1_radius_px;   // base 4.0 px at 1080p
    float tier2_radius_px;   // base 2.5 px at 1080p
    float tier3_radius_px;   // base 1.5 px at 1080p

    // Alignment padding: vec4 requires 16-byte alignment; the 7 preceding
    // scalars occupy 28 bytes, so one float pad reaches offset 32.
    float _align_pad;

    // Outline color written to scene_color_texture.
    // AC-4: default vec4(0.10196, 0.10196, 0.10196, 1.0) = #1A1A1A (26/255 each).
    // Verified: 26.0 / 255.0 = 0.101960... matches ADR-0001 requirement exactly.
    vec4 outline_color;
} params;

// ---------------------------------------------------------------------------
// Pass-type constants
// ---------------------------------------------------------------------------
const int PASS_SEED   = 0;
const int PASS_JUMP   = 1;
const int PASS_OUTPUT = 2;

// ---------------------------------------------------------------------------
// Tier-marker constants (must match OutlineCompositorEffect.TIER_MARKERS)
// ---------------------------------------------------------------------------
const float TIER1_MARKER = 1.0;
const float TIER2_MARKER = 2.0 / 3.0;   // ≈ 0.6667
const float TIER3_MARKER = 1.0 / 3.0;   // ≈ 0.3333

// Tolerance for comparing tier-marker floats. RGBA16F stores at ~3.3 decimal
// digits of precision; tier separations are ~0.333 apart, so 0.1 is safe.
const float MARKER_TOLERANCE = 0.1;

// Sentinel UV meaning "no valid seed found yet". x < 0 is the check condition.
const vec2  INVALID_UV = vec2(-1.0, -1.0);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the canonical tier-marker bucket for raw R value r,
/// or 0.0 if it does not match any tier (background / Tier 0).
float canonical_tier_marker(float r) {
    if (abs(r - TIER1_MARKER) < MARKER_TOLERANCE) return TIER1_MARKER;
    if (abs(r - TIER2_MARKER) < MARKER_TOLERANCE) return TIER2_MARKER;
    if (abs(r - TIER3_MARKER) < MARKER_TOLERANCE) return TIER3_MARKER;
    return 0.0;
}

/// Returns the outline radius (pixels) for the given tier_marker value,
/// sourced from push constant uniforms. Returns 0.0 for unrecognised marker.
float radius_for_marker(float marker) {
    if (abs(marker - TIER1_MARKER) < MARKER_TOLERANCE) return params.tier1_radius_px;
    if (abs(marker - TIER2_MARKER) < MARKER_TOLERANCE) return params.tier2_radius_px;
    if (abs(marker - TIER3_MARKER) < MARKER_TOLERANCE) return params.tier3_radius_px;
    return 0.0;
}

/// Returns true when seed_uv holds a real seed (not the INVALID sentinel).
/// All legitimate UVs are in [0, 1]; INVALID_UV.x = -1 < 0.
bool is_valid_seed(vec2 seed_uv) {
    return seed_uv.x >= 0.0;
}

/// Converts a pixel integer coordinate to normalised UV centre.
/// Adds 0.5 to hit the texel centre, then divides by frame size.
vec2 pixel_to_uv(vec2 px) {
    return (px + vec2(0.5)) / vec2(params.frame_width, params.frame_height);
}

/// Converts a UV-space distance to approximate pixel distance.
/// Uses frame_width as the reference axis (correct for non-square renders
/// only along X; a full ellipse-correct version is out of spec for VS).
float uv_dist_to_px(float d) {
    // UV distance 1.0 corresponds to frame_width pixels along X.
    // For most outline sizes (< 8 px) the approximation error is negligible.
    return d * params.frame_width;
}

// ---------------------------------------------------------------------------
// Pass implementations
// ---------------------------------------------------------------------------

/// Seed pass: reads tier_mask_texture and initialises the seed_write buffer.
/// Interior pixels (tier_marker > 0) store their own UV as the nearest seed.
/// Non-interior pixels store INVALID_UV with tier_marker 0.0.
void do_seed_pass(ivec2 coord, ivec2 size) {
    float mask_r = texelFetch(tier_mask_texture, coord, 0).r;
    float marker = canonical_tier_marker(mask_r);

    vec4 out_val;
    if (marker > 0.0) {
        // This pixel is inside a tier — it is its own nearest seed.
        vec2 uv = pixel_to_uv(vec2(coord));
        out_val = vec4(uv, marker, 0.0);
    } else {
        // No tier marker — no seed found yet.
        out_val = vec4(INVALID_UV, 0.0, 0.0);
    }

    imageStore(seed_write, coord, out_val);
}

/// Jump pass: propagates nearest-seed information across the image.
/// Samples 8 neighbours at offsets ±step_size (cardinal + diagonal).
/// Keeps the neighbour whose seed is closest to the current pixel's UV.
void do_jump_pass(ivec2 coord, ivec2 size) {
    // Retrieve current best seed from the read buffer.
    vec4  cur       = imageLoad(seed_read, coord);
    vec2  best_uv   = cur.xy;
    float best_tier = cur.z;
    vec2  pixel_uv  = pixel_to_uv(vec2(coord));

    // Initialise best distance from current stored seed (or +inf if none).
    float best_dist = is_valid_seed(best_uv)
        ? distance(pixel_uv, best_uv)
        : 1.0e9;

    // Sample all 8 neighbours (3×3 grid minus centre).
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;  // skip centre

            // Clamp to frame bounds — prevents OOB reads for edge pixels.
            ivec2 ncoord = clamp(
                coord + ivec2(dx, dy) * params.step_size,
                ivec2(0),
                size - ivec2(1)
            );

            vec4  nb      = imageLoad(seed_read, ncoord);
            vec2  nb_seed = nb.xy;
            float nb_tier = nb.z;

            if (!is_valid_seed(nb_seed)) continue;

            float d = distance(pixel_uv, nb_seed);
            if (d < best_dist) {
                best_dist = d;
                best_uv   = nb_seed;
                best_tier = nb_tier;
            }
        }
    }

    imageStore(seed_write, coord, vec4(best_uv, best_tier, 0.0));
}

/// Output pass: writes outline_color to scene_color_texture for pixels that
/// are (a) within tier_radius of a tier-marked seed AND (b) not interior to
/// the same tier.
///
/// AC-4: outline_color is the push constant default #1A1A1A (26/255 each).
/// AC-6: colour is written unconditionally (overwrites lit scene pixels) so
///       lighting has no effect on the outline hue.
void do_output_pass(ivec2 coord) {
    // Read the final seed result for this pixel.
    vec4  seed_data = imageLoad(seed_read, coord);
    vec2  seed_uv   = seed_data.xy;
    float seed_tier = seed_data.z;

    // No valid seed nearby — nothing to draw.
    if (!is_valid_seed(seed_uv) || seed_tier <= 0.0) return;

    // Distance from this pixel to its nearest seed, converted to pixels.
    vec2  pixel_uv = pixel_to_uv(vec2(coord));
    float dist_px  = uv_dist_to_px(distance(pixel_uv, seed_uv));

    float tier_radius = radius_for_marker(seed_tier);
    // Outside the outline band — nothing to draw.
    if (dist_px > tier_radius) return;

    // Interior check: if this pixel is itself interior to the same tier,
    // preserve its scene color (the object's lit surface must remain).
    float own_mask_r = texelFetch(tier_mask_texture, coord, 0).r;
    float own_marker = canonical_tier_marker(own_mask_r);
    if (abs(own_marker - seed_tier) < MARKER_TOLERANCE) return;

    // Exterior pixel within the outline band — write the flat outline color.
    // AC-4: outline_color push constant default = vec4(0.10196, 0.10196, 0.10196, 1.0)
    //       = #1A1A1A. Written unconditionally; no blend with scene lighting.
    imageStore(scene_color_texture, coord, params.outline_color);
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------
void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size  = ivec2(params.frame_width, params.frame_height);

    // Bounds guard — excess workgroup threads beyond the framebuffer edge.
    if (coord.x >= size.x || coord.y >= size.y) return;

    if (params.pass_type == PASS_SEED) {
        do_seed_pass(coord, size);
    } else if (params.pass_type == PASS_JUMP) {
        do_jump_pass(coord, size);
    } else if (params.pass_type == PASS_OUTPUT) {
        do_output_pass(coord);
    }
    // Unknown pass_type: no-op (safe fallback).
}
