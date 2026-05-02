// res://src/gameplay/player/hands_outline_material.gdshader
//
// HandsOutlineMaterial — inverted-hull outline shader for FPS hands.
//
// Implements: Story PC-008 (FPS hands rendering), ADR-0005 §Key Interfaces.
// GDD: design/gdd/player-character.md §AC-9.1
//
// Technique: inverted-hull (front-face-culled extrusion).
//   The hands mesh is rendered twice:
//     Pass 1 (this shader, material_overlay): cull_front — only the expanded
//       back-face shell is visible; outputs flat outline_color. This is the
//       outline silhouette.
//     Pass 2 (the mesh's own StandardMaterial3D fill): cull_back — the solid
//       hand body carves out the interior of the shell, revealing only the
//       border edge.
//
// Applied via MeshInstance3D.material_overlay (NOT material_override).
// material_overlay preserves the mesh's per-surface PBR fill materials;
// material_override would clobber them. ADR-0005 IG 7, GDD AC-9.1.
//
// Hands do NOT participate in ADR-0001's stencil pipeline. Do NOT call
// OutlineTier.set_tier() on the hands MeshInstance3D. CI lint guard
// tests/ci/hands_not_on_outline_tier_lint.gd enforces this at file level.
//
// UNIFORMS
//   outline_color        — flat output color (Art Bible §4.4: #1A1A1A near-black)
//   outline_world_width  — extrusion distance in local-space metres.
//                          0.006 ≈ 4 px visual width at 1080p native for hands
//                          at typical 0.5–0.8 m camera distance. Tuning knob.
//   resolution_scale     — driven by Events.setting_changed(graphics, resolution_scale).
//                          Set to 1.0 at default; 0.75 on Iris Xe integrated graphics.
//                          Scales outline proportionally with the world outline
//                          (ADR-0005 IG 4, ADR-0001 Constraint §resolution scale).
//
// CROSS-PLATFORM NOTE
//   Pure vertex math — no stencil, no geometry shaders, no backend-specific
//   extensions. Identical output on Vulkan/Linux and Vulkan/Windows.
//
// SHADER BAKER (Godot 4.5+)
//   This shader will be pre-compiled by Shader Baker at export time when
//   assigned via material_overlay. If material_overlay is excluded from
//   Baker's discovery pass, switch to the two-surface fallback per
//   ADR-0005 IG 7 and document in the G5 amendment.

shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_front, unshaded;

/// Flat outline color. Art Bible §4.4 specifies #1A1A1A (vec4 ≈ 0.102, 0.102, 0.102).
uniform vec4 outline_color : source_color = vec4(0.102, 0.102, 0.102, 1.0);

/// Extrusion distance in local-space metres. Starting value 0.006 produces
/// ~4 px visual thickness at 1080p native at typical FPS-hands camera distance.
/// Re-tune if hand mesh scale or typical viewing distance changes significantly.
uniform float outline_world_width : hint_range(0.001, 0.02) = 0.006;

/// Wired to Settings.get_resolution_scale() on _ready() and updated via
/// Events.setting_changed signal in player_character.gd. Default 1.0.
/// At 0.75 (Iris Xe branch) the outline scales proportionally with the world outline.
uniform float resolution_scale = 1.0;


void vertex() {
	// Extrude the back-face shell outward along the vertex normal by
	// outline_world_width * resolution_scale (local space).
	// Skeletal deformation runs before user vertex() code in Godot's pipeline —
	// extrusion is applied to the post-skinned vertex position, so animated
	// hands deform correctly (ADR-0005 IG 6).
	VERTEX += NORMAL * outline_world_width * resolution_scale;
}


void fragment() {
	// unshaded render_mode bypasses lighting — ALBEDO is the direct output color.
	// Outline is uniform regardless of light direction (Art Bible visual target).
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
