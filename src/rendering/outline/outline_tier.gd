# src/rendering/outline/outline_tier.gd
#
# OutlineTier — project-wide stencil tier constants and convenience setter.
#
# Requirements: TR-OUT-001, TR-OUT-010
# Governing ADR: ADR-0001 (Stencil ID Contract for Tiered Outline Rendering)
#
# OVERVIEW
#   Every visible MeshInstance3D in The Paris Affair writes one of four reserved
#   stencil-buffer values so the comic-book outline CompositorEffect can apply
#   the correct kernel width per pixel:
#
#     0 = NONE     — no outline
#     1 = HEAVIEST — 4 px @ 1080p  (Eve, key interactives, gadget pickups)
#     2 = MEDIUM   — 2.5 px @ 1080p (PHANTOM guards)
#     3 = LIGHT    — 1.5 px @ 1080p (environment geometry, Paris civilians)
#
# USAGE
#   Call OutlineTier.set_tier(mesh_instance, OutlineTier.HEAVIEST) at spawn
#   time for dynamic objects, or set once in .tscn for static environment
#   meshes (ADR-0001 IG 1, IG 2).
#
# ADR-0005 EXEMPTION
#   Eve's FPS hands mesh is the ONLY object exempt from set_tier(). Hands render
#   in a SubViewport using an inverted-hull shader (HandsOutlineMaterial). Do NOT
#   call set_tier() on the hands mesh — it has a separate framebuffer and its
#   stencil writes never reach the outline CompositorEffect pass. Enforced by
#   code-review checklist (ADR-0005 Validation Criteria), not in this code.
#
# DESIGN NOTES
#   - NOT an autoload. Use class_name directly: OutlineTier.HEAVIEST, set_tier().
#   - const int (not enum) so values are usable as @export defaults and in match.
#   - Zero runtime memory footprint (static func only, no instance state).

class_name OutlineTier extends RefCounted


## No outline — default cleared stencil value. Invisible meshes, collision-only
## geometry, the document-overlay dim ColorRect, and any object intentionally
## receiving no outline. (ADR-0001 §Decision)
const NONE: int = 0

## Heaviest outline — 4 px at 1080p. Eve Sterling, gadget pickups, bomb device,
## uncollected documents, comedic hero props when locally promoted. (TR-OUT-001)
const HEAVIEST: int = 1

## Medium outline — 2.5 px at 1080p. PHANTOM guards, all variants. (TR-OUT-001)
const MEDIUM: int = 2

## Light outline — 1.5 px at 1080p. Environment geometry (ironwork, furniture,
## dressing), Paris civilians. (TR-OUT-001)
const LIGHT: int = 3


## Assigns the stencil outline tier to every surface material on [param mesh].
##
## Writes STENCIL_MODE_CUSTOM (3) + stencil_flags=Write (2) +
## stencil_compare=Always (0) + stencil_reference=[param tier] onto each
## BaseMaterial3D surface. For ShaderMaterial surfaces, sets the
## "stencil_reference" shader parameter instead (shader code owns the
## stencil_mode / stencil_flags / stencil_compare state for those materials).
## If a surface slot has no material at all, creates a new StandardMaterial3D
## with the correct stencil state and assigns it as the override.
##
## Calling this method again (escape-hatch) overwrites the previous tier value
## immediately — there is no tween or transition (ADR-0001 IG 3).
##
## Example:
##   [codeblock]
##   # At spawn time:
##   OutlineTier.set_tier(guard_mesh, OutlineTier.MEDIUM)
##
##   # Runtime escape-hatch promotion (e.g., swinging lamp focal moment):
##   OutlineTier.set_tier(lamp_mesh, OutlineTier.HEAVIEST)
##   [/codeblock]
##
## ADR-0005 note: do NOT call this for Eve's FPS hands mesh. See class header.
static func set_tier(mesh: MeshInstance3D, tier: int) -> void:
	# Debug-build diagnostic: log on any out-of-range value so callers catch
	# mis-wiring early. push_error here (rather than assert()) so the function
	# continues into the clampi guard below — assert() aborts the function and
	# would skip the defense-in-depth clamp. (TR-OUT-010, GDD AC-18)
	if OS.is_debug_build() and (tier < 0 or tier > 3):
		push_error("OutlineTier: invalid tier " + str(tier) + " (must be 0..3)")

	# Defense-in-depth clamp: runs in both debug and release. In release, an
	# out-of-range value silently becomes LIGHT (3) for tier > 3, or NONE (0)
	# for tier < 0 — never writes garbage into the stencil buffer. (TR-OUT-010)
	var safe_tier: int = clampi(tier, 0, 3)

	var surface_count: int = mesh.get_surface_override_material_count()
	for i: int in range(surface_count):
		# Prefer the override-material slot (editor-assigned materials land here).
		# Fall back to the mesh-embedded material if no override is set.
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null and mesh.mesh != null:
			mat = mesh.mesh.surface_get_material(i)

		if mat == null:
			# No material at all on this surface — create a new StandardMaterial3D
			# with correct stencil state and assign it as the override.
			var new_mat: StandardMaterial3D = StandardMaterial3D.new()
			_apply_stencil_to_base_material(new_mat, safe_tier)
			mesh.set_surface_override_material(i, new_mat)
		elif mat is BaseMaterial3D:
			# StandardMaterial3D inherits BaseMaterial3D; set stencil properties
			# directly via the Godot 4.6 BaseMaterial3D stencil API (post-cutoff,
			# verified Sprint 01 finding F4 — available since Godot 4.5).
			_apply_stencil_to_base_material(mat as BaseMaterial3D, safe_tier)
		elif mat is ShaderMaterial:
			# For shader-authored materials the stencil_mode / stencil_flags /
			# stencil_compare state is declared in the shader source. Only the
			# reference value is set here so the shader can branch on tier.
			(mat as ShaderMaterial).set_shader_parameter("stencil_reference", safe_tier)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Applies the four stencil properties to a BaseMaterial3D (or subclass).
##
## Godot 4.6 BaseMaterial3D stencil API (post-cutoff, verified finding F4):
##   stencil_mode    int: 0=Disabled, 1=Outline (world-space, FORBIDDEN per
##                        ADR-0001), 2=XRay, 3=Custom
##   stencil_flags   int bitfield: 1=Read, 2=Write, 4=WriteDepthFail
##   stencil_compare int: 0=Always, 1=Less, 2=Equal, 3=LessOrEqual,
##                        4=Greater, 5=NotEqual, 6=GreaterOrEqual
##   stencil_reference int: 0–255 (project reserves 0–3, ADR-0001 §Decision)
##
## Named constants for these enums may or may not be exposed in 4.6;
## if BaseMaterial3D.STENCIL_MODE_CUSTOM is available at runtime, the
## integer literals below are functionally identical to it.
static func _apply_stencil_to_base_material(mat: BaseMaterial3D, safe_tier: int) -> void:
	# Godot 4.6 stencil API: 3 == STENCIL_MODE_CUSTOM
	mat.stencil_mode = 3
	# Godot 4.6 stencil API: 2 == Write (bitfield flag)
	mat.stencil_flags = 2
	# Godot 4.6 stencil API: 0 == Always (compare op)
	mat.stencil_compare = 0
	mat.stencil_reference = safe_tier
