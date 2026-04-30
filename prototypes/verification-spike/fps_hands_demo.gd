# prototypes/verification-spike/fps_hands_demo.gd
#
# ADR-0005 FPS Hands Inverted-Hull — visual verification scene controller.
#
# Builds three objects side-by-side in a single 3D scene:
#   1. LEFT — a stand-in "hand" mesh (capsule) using the inverted-hull
#      outline shader (this prototype's `inverted_hull_outline.gdshader`).
#   2. CENTER — the same capsule WITHOUT the inverted-hull pass (control —
#      no outline at all).
#   3. RIGHT — the same capsule using Godot 4.6's native
#      `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` at TIER-HEAVIEST
#      thickness (matches `stencil_outline_demo.gd`'s leftmost cube).
#
# WHAT TO VISUALLY VERIFY
#   1. The LEFT capsule has a visible black outline (proves inverted-hull
#      shader compiles and renders correctly on Godot 4.6 / Vulkan/D3D12).
#   2. The CENTER capsule has NO outline (sanity check — without the shader,
#      no outline appears).
#   3. The LEFT and RIGHT outlines are visually similar in thickness (proves
#      inverted-hull thickness can be tuned to match stencil tier-HEAVIEST,
#      satisfying ADR-0005 §Verification Required item 1).
#   4. Outlines remain pixel-stable as the camera distance changes (in the
#      editor, orbit around the scene with mouse — outlines should NOT
#      visibly grow or shrink with distance).
#
# SCOPE NOTE
#   This is a SINGLE-VIEWPORT demo. ADR-0005's full design uses a SubViewport
#   for the FPS hands so they can have a separate FOV / near-clip from the
#   world camera. This prototype skips the SubViewport — that lifecycle
#   integration is a production-story concern. The shader works identically
#   in a SubViewport (verification deferred to the FPS Hands production story
#   under the presentation epic).
#
# HOW TO RUN
#   - Open the .tscn in the Godot editor and press F6 (Run Current Scene)
#   - Or: godot --headless --quit-after 60 res://prototypes/verification-spike/fps_hands_demo.tscn
#     (headless catches parse/compile errors only — visual verification
#     requires the editor)

extends Node3D

const INVERTED_HULL_SHADER := preload("res://prototypes/verification-spike/inverted_hull_outline.gdshader")


func _ready() -> void:
	_build_lighting()
	_build_camera()
	_build_capsules()
	print("[fps_hands_demo] Scene built — open in editor to visually verify outlines")


func _build_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.92, 0.85)  # parchment so black outlines read
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.4
	env_node.environment = env
	add_child(env_node)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 4.5)
	cam.current = true
	add_child(cam)
	# look_at requires the node to be inside the tree.
	cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)


func _build_capsules() -> void:
	# LEFT — inverted-hull outline.
	_make_capsule_with_inverted_hull(Vector3(-2.5, 0.5, 0.0), "LEFT: inverted-hull outline")
	# CENTER — control, no outline.
	_make_basic_capsule(Vector3(0.0, 0.5, 0.0), "CENTER: no outline (control)")
	# RIGHT — native stencil_mode = Outline at HEAVIEST thickness.
	_make_capsule_with_stencil_outline(Vector3(2.5, 0.5, 0.0), 0.05, "RIGHT: stencil tier HEAVIEST (0.05 m)")


# ─── LEFT — inverted-hull outline ──────────────────────────────────────
# Two MeshInstance3D nodes share the same CapsuleMesh resource.
# The first (outline_mesh) uses the inverted-hull shader; the second
# (body_mesh) uses a regular StandardMaterial3D. The body renders on top of
# the expanded outline shell, producing the silhouette effect.
func _make_capsule_with_inverted_hull(at: Vector3, label: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)

	var mesh_resource := CapsuleMesh.new()
	mesh_resource.height = 1.6
	mesh_resource.radius = 0.18

	# Outline pass — inverted-hull
	var outline_mesh := MeshInstance3D.new()
	outline_mesh.mesh = mesh_resource
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = INVERTED_HULL_SHADER
	outline_mat.set_shader_parameter("outline_color", Color(0.0, 0.0, 0.0, 1.0))
	outline_mat.set_shader_parameter("outline_thickness", 0.012)
	outline_mesh.material_override = outline_mat
	pivot.add_child(outline_mesh)

	# Body pass — regular material on top
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = mesh_resource
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.65, 0.55)  # skin tone stand-in
	body_mesh.material_override = body_mat
	pivot.add_child(body_mesh)

	print("  %s @ %s" % [label, str(at)])
	return pivot


# ─── CENTER — control, no outline ──────────────────────────────────────
func _make_basic_capsule(at: Vector3, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.6
	capsule.radius = 0.18
	mesh.mesh = capsule
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.55)
	mesh.material_override = mat
	add_child(mesh)
	print("  %s @ %s" % [label, str(at)])
	return mesh


# ─── RIGHT — native stencil outline ────────────────────────────────────
func _make_capsule_with_stencil_outline(at: Vector3, outline_thickness: float, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.6
	capsule.radius = 0.18
	mesh.mesh = capsule
	mesh.position = at

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.55)
	# Native Godot 4.6 stencil-outline API.
	mat.set("stencil_mode", 1)  # STENCIL_MODE_OUTLINE
	mat.set("stencil_color", Color(0.0, 0.0, 0.0, 1.0))
	mat.set("stencil_outline_thickness", outline_thickness)
	mesh.material_override = mat
	add_child(mesh)
	print("  %s @ %s (thickness=%.3f m)" % [label, str(at), outline_thickness])
	return mesh
