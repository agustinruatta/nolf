// outline.glsl
//
// Sprint 01 verification spike — ADR-0001 G2 prototype.
//
// Compute shader that reads the tier-mask intermediate texture (written by
// the 3 stencil-test passes) and writes outline pixels into the scene color
// buffer.
//
// Algorithm:
//   - For each output pixel:
//     - Sample tier-mask at center; if interior to ANY tier, leave color
//       untouched (interior fill is preserved).
//     - Otherwise scan a max-radius neighborhood; for each non-zero sample,
//       compute Euclidean distance and which tier it is. If distance is
//       within that tier's pixel radius, mark this pixel as outline.
//     - The narrowest qualifying tier wins (HEAVIEST > MEDIUM > LIGHT) so
//       overlapping outlines from different-tier objects produce the
//       widest applicable outline.
//
// Tier widths are screen-space pixel radii — they do NOT scale with depth.
// This is the screen-space stability property ADR-0001 requires (and which
// the native BaseMaterial3D.stencil_mode = Outline API does NOT provide;
// see Finding F4).

#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D u_tier_mask;
layout(rgba16f, set = 0, binding = 1) uniform image2D u_color;

layout(push_constant, std430) uniform Params {
    vec4 outline_color;
    int max_radius_px;   // upper bound for the scan; HEAVIEST radius
} params;

const float TIER1_MARKER = 1.00;
const float TIER2_MARKER = 0.66;
const float TIER3_MARKER = 0.33;

const float TIER1_RADIUS = 4.0;
const float TIER2_RADIUS = 2.5;
const float TIER3_RADIUS = 1.5;

const float MARKER_TOLERANCE = 0.08;

int tier_of(float v) {
    if (abs(v - TIER1_MARKER) < MARKER_TOLERANCE) return 1;
    if (abs(v - TIER2_MARKER) < MARKER_TOLERANCE) return 2;
    if (abs(v - TIER3_MARKER) < MARKER_TOLERANCE) return 3;
    return 0;
}

float radius_for(int tier) {
    if (tier == 1) return TIER1_RADIUS;
    if (tier == 2) return TIER2_RADIUS;
    if (tier == 3) return TIER3_RADIUS;
    return 0.0;
}

void main() {
    ivec2 size = imageSize(u_tier_mask);
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    if (coord.x >= size.x || coord.y >= size.y) return;

    vec4 center = imageLoad(u_tier_mask, coord);
    if (tier_of(center.r) > 0) return;

    int radius = params.max_radius_px;
    int best_tier = 0;
    float best_dist = 1e9;

    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            ivec2 sample_coord = coord + ivec2(dx, dy);
            if (sample_coord.x < 0 || sample_coord.y < 0 ||
                sample_coord.x >= size.x || sample_coord.y >= size.y) continue;

            vec4 s = imageLoad(u_tier_mask, sample_coord);
            int t = tier_of(s.r);
            if (t == 0) continue;

            float d = sqrt(float(dx * dx + dy * dy));
            float r = radius_for(t);
            if (d <= r && d < best_dist) {
                best_dist = d;
                best_tier = t;
            }
        }
    }

    if (best_tier > 0) {
        imageStore(u_color, coord, params.outline_color);
    }
}
