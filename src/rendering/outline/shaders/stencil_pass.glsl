// src/rendering/outline/shaders/stencil_pass.glsl
//
// Stencil-test pass for the OutlineCompositorEffect Stage 1 pipeline.
//
// Requirements: TR-OUT-002, TR-OUT-005
// Governing ADR: ADR-0001 (Stencil ID Contract for Tiered Outline Rendering)
//
// OVERVIEW
//   One graphics pipeline pass is run per outline tier (T = 1, 2, 3). The
//   pipeline is created with RDPipelineDepthStencilState.enable_stencil = true
//   and front_op_reference = T, so the GPU's stencil-test hardware filters
//   fragments: only pixels whose scene stencil value equals T execute the
//   fragment shader.
//
//   The fragment shader writes a tier-marker float into the R channel of the
//   RGBA16F intermediate texture:
//     Tier 1 (HEAVIEST) → R = 1.0000
//     Tier 2 (MEDIUM)   → R = 0.6667
//     Tier 3 (LIGHT)    → R = 0.3333
//     Tier 0 / no match → R = 0.0    (intermediate texture retains cleared value)
//
// VERTEX SHADER
//   Reconstructs a fullscreen-covering triangle entirely from gl_VertexIndex —
//   no vertex buffer or attributes required. Invoked with draw count = 3.
//   Outputs UV [0,1] for use by future shader variants; unused in this pass.
//
// FRAGMENT SHADER
//   Receives tier_marker via push constant (std430, 16-byte aligned block).
//   Writes vec4(tier_marker, 0.0, 0.0, 1.0) to color attachment 0.
//   Pixels that do not pass the stencil test do not execute this shader and
//   leave the intermediate texture at its cleared value (vec4(0.0)).
//
// COMPILATION
//   This file is processed by Godot's .glsl importer at edit time and compiled
//   to SPIR-V. The RDShaderFile resource is loaded via ResourceLoader.load()
//   in OutlineCompositorEffect; .get_spirv() retrieves the pre-compiled SPIR-V
//   for shader_create_from_spirv(). (Finding F2, ADR-0001)
//
// STAGE 2 CONTRACT
//   The intermediate texture layout produced by these passes is the input
//   contract for Story 003's jump-flood compute shader. Do NOT change the
//   R-channel encoding without updating the Stage 2 consumer.
//
// Reference: dmlary/godot-stencil-based-outline-compositor-effect (MIT)
//            Sprint 01 spike: prototypes/verification-spike/shaders/stencil_pass.glsl

#[vertex]
#version 450

// Fullscreen triangle reconstruction from vertex index.
// gl_VertexIndex:  0 → (-1,-1)  1 → (3,-1)  2 → (-1,3)
// Covers the entire clip-space [-1,1]×[-1,1] NDC square with a single triangle.
// The triangle extends off-screen — rasterization clips it safely.
//
// Winding order: counter-clockwise in NDC (looking from +Z toward -Z),
// so the triangle is front-facing in Vulkan's default rasterizer state
// (VK_FRONT_FACE_COUNTER_CLOCKWISE).
layout(location = 0) out vec2 frag_uv;

void main() {
    // Map vertex index to clip-space position.
    // Index 0 → (x=-1, y=-1)  → UV (0, 0)
    // Index 1 → (x= 3, y=-1)  → UV (2, 0)
    // Index 2 → (x=-1, y= 3)  → UV (0, 2)
    vec2 pos = vec2(
        float((gl_VertexIndex & 1) << 1) - 1.0,   // -1 or 3
        float((gl_VertexIndex >> 1) << 1) - 1.0    // -1 or 3
    );
    frag_uv = pos * 0.5 + 0.5;
    gl_Position = vec4(pos, 0.0, 1.0);
}

#[fragment]
#version 450

layout(location = 0) in vec2 frag_uv;
layout(location = 0) out vec4 frag_color;

// Push constant block — must be 16-byte aligned (std430 rule).
// The GDScript caller allocates a 16-byte PackedByteArray and encodes
// tier_marker as a float at byte offset 0.
//
// Tier-marker encoding (matches OutlineCompositorEffect.TIER_MARKERS):
//   Tier 1 (HEAVIEST) → 1.0
//   Tier 2 (MEDIUM)   → 2.0/3.0  ≈ 0.6667
//   Tier 3 (LIGHT)    → 1.0/3.0  ≈ 0.3333
layout(push_constant, std430) uniform Params {
    float tier_marker;
    float _pad0;
    float _pad1;
    float _pad2;
} params;

void main() {
    // Write tier marker to R channel. G, B = 0 (reserved for Stage 2 data).
    // A = 1 to ensure the color attachment blend equation writes correctly when
    // blend is disabled (which it is — this is an opaque tier-mask write).
    frag_color = vec4(params.tier_marker, 0.0, 0.0, 1.0);
}
