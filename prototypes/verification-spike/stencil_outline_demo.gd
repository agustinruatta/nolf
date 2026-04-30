# prototypes/verification-spike/stencil_outline_demo.gd
#
# ADR-0001 Stencil Outline — visual verification scene controller.
#
# Key finding from `stencil_property_probe.gd` (Sprint 01 Group 3): Godot
# 4.6 has BUILT-IN stencil-based outline rendering on BaseMaterial3D via
# `stencil_mode = Outline` + `stencil_outline_thickness`. This is a major
# departure from ADR-0001's custom CompositorEffect design (the ADR may
# need to be superseded — see verification-log.md Finding F4).
#
# This demo uses the native API. It builds a 3-cube row, each cube using
# StandardMaterial3D with `stencil_mode = STENCIL_MODE_OUTLINE` and a
# different `stencil_outline_thickness` boosted from ADR-0001's design
# values for visual discrimination:
#   - HEAVIEST: 0.10 m (boosted from ADR-0001 4 px target)
#   - MEDIUM:   0.06 m (boosted from ADR-0001 2.5 px target)
#   - LIGHT:    0.035 m (boosted from ADR-0001 1.5 px target)
# (Original ADR values 0.05 / 0.03 / 0.018 m read as nearly-identical thin
# lines at the camera distance and antialiasing noise floor — see
# verification-log Finding F4 first iteration. These boosted values let
# tier discrimination be visually unambiguous; production thickness
# tuning happens in the rendering production story.)
#
# Tier 0 (no outline) = `stencil_mode = STENCIL_MODE_DISABLED`. A 4th cube
# placed further back tests distance-stability of pixel-width.
#
# WHAT TO VISUALLY VERIFY (open in Godot editor or run scene)
#   1. The three foreground cubes show three visibly different outline
#      thicknesses — heaviest leftmost, lightest rightmost.
#   2. The 4th cube (no outline) renders without any outline.
#   3. The "distance test" 5th cube placed further back has the SAME
#      pixel-width outline as the foreground HEAVIEST cube — i.e., the
#      thickness is screen-space-stable. (If it's smaller / scales with
#      distance, the native API is world-space and ADR-0001's screen-
#      space tier intent is NOT satisfied — finding follow-up needed.)
#   4. Outline color is the per-material `stencil_color` (set to BQA
#      Blue here for visual readability).
#
# HOW TO RUN
#   godot --headless --quit-after 60 res://prototypes/verification-spike/stencil_outline_demo.tscn
#   (headless gives parse/load verification only — visual verification
#    requires opening the scene in the editor and running it normally)

extends Node3D


func _ready() -> void:
	# Build the demo programmatically so the .tscn stays minimal and
	# version-control-stable.
	_build_lighting()
	_build_camera()
	_build_cubes()
	print("[stencil_outline_demo] Scene built — open in editor to visually verify outline tiers")


func _build_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.92, 0.85)  # parchment-ish so blue outline reads
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.4
	env_node.environment = env
	add_child(env_node)


func _build_camera() -> void:
	var cam := Camera3D.new()
	# Camera framing — pulled slightly back so the distance-test cube at
	# (-7, 0.5, -10) is in frame on the left, and the foreground row
	# remains visible on the right. Look-at slightly down so foreground
	# cubes don't crowd the top of the screen.
	cam.position = Vector3(-1.5, 1.5, 6)
	cam.current = true
	add_child(cam)
	# look_at requires the node to be inside the tree.
	cam.look_at(Vector3(-1.5, 0.5, -3), Vector3.UP)


func _build_cubes() -> void:
	# Three foreground cubes — three outline tiers, side-by-side at z=0.
	# Spacing 2.5 m along x. Boosted tier widths for visual discrimination.
	_make_cube(Vector3(-3.0, 0.5, 0.0), 0.10, "TIER 1: HEAVIEST (0.10 m)")
	_make_cube(Vector3(0.0, 0.5, 0.0), 0.06, "TIER 2: MEDIUM (0.06 m)")
	_make_cube(Vector3(3.0, 0.5, 0.0), 0.035, "TIER 3: LIGHT (0.035 m)")

	# 4th cube — no outline (TIER 0 = disabled). Placed clearly off-row at
	# x=+5 (right of the LIGHT cube) so it sits alone for visual control —
	# previously placed behind HEAVIEST which made the comparison ambiguous.
	_make_basic_cube(Vector3(5.0, 0.5, 0.0), Color(0.95, 0.92, 0.85))

	# 5th cube — distance test. Same HEAVIEST thickness as the leftmost
	# foreground cube, but placed at z=-10 (much further) AND at x=-7
	# (further left of the row) so it appears in its own column on screen,
	# unoccluded by any foreground cube. Side-by-side comparison: HEAVIEST
	# at z=0 vs HEAVIEST at z=-10, both at thickness=0.10m.
	#
	# CRITICAL VISUAL CHECK:
	#   - Same pixel-width outline → native API is screen-space-stable
	#     → ADR-0001 SUPERSEDABLE with "use native stencil_mode" ADR
	#   - Smaller pixel-width on distance cube → world-space (outline
	#     scales with distance)
	#     → ADR-0001 CompositorEffect design is still required
	_make_cube(Vector3(-7.0, 0.5, -10.0), 0.10, "DISTANCE TEST: HEAVIEST @ x=-7 z=-10")


# Convenience: build a cube with stencil-outline material at given position
# and outline thickness.
func _make_cube(at: Vector3, outline_thickness: float, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh.mesh = box
	mesh.position = at

	var mat := StandardMaterial3D.new()
	# White cube body — high contrast against pure black outline so the
	# outline pixel-width is visually unambiguous. Production materials
	# use Art Bible 4 colors; this is a verification-only choice.
	mat.albedo_color = Color(0.95, 0.92, 0.85)  # parchment-white

	# Native Godot 4.6 stencil-outline API — discovered via probe.
	# `stencil_mode` enum constants on BaseMaterial3D:
	#   STENCIL_MODE_DISABLED = 0
	#   STENCIL_MODE_OUTLINE = 1
	#   STENCIL_MODE_XRAY    = 2
	#   STENCIL_MODE_CUSTOM  = 3
	mat.set("stencil_mode", 1)  # STENCIL_MODE_OUTLINE
	mat.set("stencil_color", Color(0.0, 0.0, 0.0, 1.0))  # pure black for max contrast
	mat.set("stencil_outline_thickness", outline_thickness)

	mesh.material_override = mat
	add_child(mesh)
	# Print so the run log makes the scene composition obvious.
	print("  cube @ %s — %s" % [str(at), label])
	return mesh


func _make_basic_cube(at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)
	print("  cube @ %s — TIER 0: NO OUTLINE (stencil_mode disabled)" % str(at))
	return mesh
