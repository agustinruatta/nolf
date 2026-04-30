// prototypes/verification-spike/inverted_hull_outline.gdshader
//
// Inverted-hull outline shader for FPS hands per ADR-0005.
//
// Technique: render the mesh TWICE.
//   1. Pass 1 (this shader) — back-faces only (cull_front), expanded outward
//      along normals by `outline_thickness`. Pure outline_color. Renders FIRST
//      (z-prepass via depth_draw_opaque).
//   2. Pass 2 (a separate StandardMaterial3D on a sibling MeshInstance3D
//      with the same mesh) — the actual hand body. Renders ON TOP of the
//      expanded back-face shell, "carving out" the visible outline.
//
// The visual effect: a uniform-thickness outline silhouettes the mesh,
// looking like an inked drawing — exactly what Art Bible §3 calls for.
//
// USAGE
//   - Apply this material to a MeshInstance3D parented under the hand mesh
//     (or as `material_override` on a duplicate MeshInstance3D sharing the
//     same `mesh` resource as the actual hand).
//   - The hand mesh itself uses StandardMaterial3D / a regular shader.
//
// PARAMETERS
//   - outline_color: typically pure black per Art Bible.
//   - outline_thickness: world-space units (meters). For FPS hands inside
//     a SubViewport, ~0.005–0.015 m typically reads as "matches the
//     stencil tier-HEAVIEST 4 px world outline" — final value tuned during
//     visual verification.
//
// CROSS-PLATFORM NOTE
//   Inverted-hull is geometry-shader-free; works identically on Vulkan and
//   D3D12 (no backend-specific behavior to verify).

shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 0.1, 0.001) = 0.01;


void vertex() {
	// Push the back-face vertex outward along the surface normal by
	// outline_thickness. Because cull_front discards the front faces, only
	// the expanded "shell" of back-faces remains visible — the silhouette.
	VERTEX += NORMAL * outline_thickness;
}


void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
	// unshaded render_mode means lighting is bypassed; ALBEDO becomes the
	// final color directly. Outline is uniform regardless of light direction.
}
