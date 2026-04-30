# prototypes/verification-spike/stencil_compositor_demo.gd
#
# Sprint 01 verification spike — ADR-0001 G2 + G4 prototype scene.
#
# Test scene for the StencilCompositorOutline CompositorEffect. Builds:
#   - 3 foreground cubes side-by-side, each writing a different stencil tier
#     (1=HEAVIEST, 2=MEDIUM, 3=LIGHT) via STENCIL_MODE_CUSTOM.
#   - 1 control cube at the right (no stencil — should NOT receive an outline).
#   - 1 distance-test cube at z=-10 with stencil_reference=1. CRITICAL CHECK:
#     its outline pixel-width must equal the foreground HEAVIEST cube's
#     outline pixel-width. If smaller → our screen-space pass is broken.
#
# Compare to stencil_outline_demo.tscn (which uses the native world-space
# outline API and produces depth-scaling outlines per Finding F4).

extends Node3D


const STENCIL_MODE_DISABLED: int = 0
const STENCIL_MODE_CUSTOM: int = 3
const STENCIL_FLAG_WRITE: int = 2
const STENCIL_COMPARE_ALWAYS: int = 0


func _ready() -> void:
	_build_environment_with_compositor()
	_build_lighting()
	_build_camera()
	_build_cubes()
	print("[stencil_compositor_demo] scene built — capture screenshot to verify")


func _build_environment_with_compositor() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.92, 0.85)  # parchment for contrast
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.4
	env_node.environment = env

	var compositor := Compositor.new()
	var effect := StencilCompositorOutline.new()
	compositor.compositor_effects = [effect]
	env_node.compositor = compositor

	add_child(env_node)


func _build_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_energy = 1.2
	add_child(light)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(-1.5, 1.5, 6)
	cam.current = true
	add_child(cam)
	cam.look_at(Vector3(-1.5, 0.5, -3), Vector3.UP)


func _build_cubes() -> void:
	# Foreground row — 3 tiers + 1 control (no outline).
	_make_cube(Vector3(-3.0, 0.5, 0.0), 1, "TIER 1: HEAVIEST")
	_make_cube(Vector3(0.0, 0.5, 0.0), 2, "TIER 2: MEDIUM")
	_make_cube(Vector3(3.0, 0.5, 0.0), 3, "TIER 3: LIGHT")
	_make_cube(Vector3(5.0, 0.5, 0.0), 0, "TIER 0: NO OUTLINE (control)")

	# Distance test — same HEAVIEST tier as leftmost foreground cube.
	# Outline pixel-width must match (screen-space stable, NOT world-space).
	_make_cube(Vector3(-7.0, 0.5, -10.0), 1, "DISTANCE TEST: HEAVIEST @ z=-10")


func _make_cube(at: Vector3, tier: int, label: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh.mesh = box
	mesh.position = at

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.92, 0.85)
	if tier == 0:
		mat.set("stencil_mode", STENCIL_MODE_DISABLED)
	else:
		# IMPORTANT: STENCIL_MODE_CUSTOM (NOT STENCIL_MODE_OUTLINE — that's
		# the world-space native API ADR-0001 rejected per Finding F4).
		mat.set("stencil_mode", STENCIL_MODE_CUSTOM)
		mat.set("stencil_flags", STENCIL_FLAG_WRITE)
		mat.set("stencil_compare", STENCIL_COMPARE_ALWAYS)
		mat.set("stencil_reference", tier)
	mesh.material_override = mat
	add_child(mesh)
	print("  cube @ %s — %s" % [str(at), label])
	return mesh
