// stencil_pass.glsl
//
// Sprint 01 verification spike — ADR-0001 G2 prototype.
//
// Graphics pipeline that draws a fullscreen triangle. The pipeline is created
// with depth-stencil state that performs an EQUAL stencil test against a
// per-pass reference value, so the fragment shader only writes pixels where
// the scene's stencil buffer matches that tier.
//
// We set the output channel via push constant — pass 1 writes R=tier_marker,
// pass 2 same, pass 3 same — but each pass uses a different reference, so the
// resulting intermediate texture stores per-pixel "this pixel is tier T" by
// the value written.
//
// Reference: dmlary/godot-stencil-based-outline-compositor-effect (MIT).

#[vertex]
#version 450 core
layout(location = 0) in vec3 vertex_attrib;

void main() {
    gl_Position = vec4(vertex_attrib, 1.0);
}

#[fragment]
#version 450 core

layout(location = 0) out vec4 frag_color;

layout(push_constant, std430) uniform Params {
    float tier_marker;  // 1.0 / 0.66 / 0.33 — encodes which tier this pass is for
} params;

void main() {
    frag_color = vec4(params.tier_marker, 0.0, 0.0, 1.0);
}
