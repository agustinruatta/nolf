# prototypes/verification-spike/_benchmark_outline.gd
#
# Sprint 01 verification spike — ADR-0001 G3 measurement.
#
# Headless benchmark that loads stencil_compositor_demo, runs N frames with
# vsync OFF and the CompositorEffect attached vs detached, and reports the
# frame-time delta. Underscore prefix marks it as a tooling helper.
#
# Method:
#   1. Build the demo scene with the effect attached. Render WARMUP frames
#      so shader compile + pipeline bake settle.
#   2. Render N timed frames; record wall-clock delta (start→end of N
#      RenderingServer.frame_post_draw ticks).
#   3. Detach the effect; render WARMUP frames again, then N timed frames.
#   4. Print: frame_time_with, frame_time_without, delta (= outline cost).
#
# Caveats:
#   - Wall-clock measures CPU+GPU end-to-end. Without GPU timestamp queries
#     (which Godot 4.6 doesn't expose at the GDScript layer in a stable
#     form), this is the closest approximation. For our purpose (does the
#     pass fit in the 2 ms budget) this is sufficient — wall-clock IS the
#     budget.
#   - On an isolated 5-cube scene the rest-of-frame cost is tiny, so the
#     delta is dominated by the outline pass. Production scenes with
#     hundreds of objects would show a smaller proportional delta but the
#     absolute outline cost is the same.
#   - vsync is disabled via Engine.max_fps = 0 + window flag in main loop
#     setup. xvfb-run does not vsync by default.

extends Node

const WARMUP_FRAMES := 120
const TIMED_FRAMES := 600
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360),    # diagnostic: clearly below xvfb bottleneck
	Vector2i(960, 540),    # diagnostic: half of 1080p
	Vector2i(1440, 810),   # 75% of 1080p (ADR-0001 IG-6 Iris Xe fallback)
	Vector2i(1920, 1080),  # native 1080p target
]

var _demo: Node3D
var _world_env: WorldEnvironment
var _compositor_with_effect: Compositor
var _empty_compositor: Compositor


func _ready() -> void:
	# Try to disable vsync if possible (xvfb-run usually has no vsync anyway).
	Engine.max_fps = 0

	for res in RESOLUTIONS:
		get_viewport().size = res
		await _bench_at_resolution(res)
		# Small breather between runs so prior frame state doesn't bleed.
		await _wait_frames(20)

	get_tree().quit(0)


func _bench_at_resolution(res: Vector2i) -> void:
	print()
	print("=" .repeat(60))
	print("[bench] resolution: %d x %d  (%.2f Mpix)" % [
		res.x, res.y, (res.x * res.y) / 1_000_000.0
	])
	print("=" .repeat(60))

	# Build scene fresh each pass so warmup conditions are equivalent.
	_build_demo()
	await _wait_frames(WARMUP_FRAMES)

	# WITH effect
	var t0 := Time.get_ticks_usec()
	await _wait_frames(TIMED_FRAMES)
	var with_us := Time.get_ticks_usec() - t0
	var with_per_frame_us := float(with_us) / TIMED_FRAMES

	# Detach the effect (replace compositor with empty one) and warm up again.
	_world_env.compositor = _empty_compositor
	await _wait_frames(WARMUP_FRAMES)

	var t1 := Time.get_ticks_usec()
	await _wait_frames(TIMED_FRAMES)
	var without_us := Time.get_ticks_usec() - t1
	var without_per_frame_us := float(without_us) / TIMED_FRAMES

	# Reattach so cleanup is consistent
	_world_env.compositor = _compositor_with_effect

	var delta_us := with_per_frame_us - without_per_frame_us

	print("[bench] WITHOUT effect : %8.1f us / frame  (%.2f ms)" % [
		without_per_frame_us, without_per_frame_us / 1000.0])
	print("[bench] WITH effect    : %8.1f us / frame  (%.2f ms)" % [
		with_per_frame_us, with_per_frame_us / 1000.0])
	print("[bench] OUTLINE PASS   : %8.1f us / frame  (%.3f ms)" % [
		delta_us, delta_us / 1000.0])
	print("[bench] FPS uncapped   : %.0f (with) / %.0f (without)" % [
		1_000_000.0 / max(with_per_frame_us, 1.0),
		1_000_000.0 / max(without_per_frame_us, 1.0)])

	# Tear down for next iteration
	_demo.queue_free()
	await _wait_frames(2)


func _build_demo() -> void:
	# Manually build the same scene as stencil_compositor_demo.gd, but keep
	# references to the WorldEnvironment + compositors so we can swap
	# effect on/off without rebuilding the world.
	_demo = Node3D.new()
	add_child(_demo)

	# WorldEnvironment + dual compositors
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.92, 0.85)
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.4
	_world_env.environment = env

	_compositor_with_effect = Compositor.new()
	_compositor_with_effect.compositor_effects = [StencilCompositorOutline.new()]
	_empty_compositor = Compositor.new()
	_empty_compositor.compositor_effects = []
	_world_env.compositor = _compositor_with_effect

	_demo.add_child(_world_env)

	# Light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.light_energy = 1.2
	_demo.add_child(light)

	# Camera
	var cam := Camera3D.new()
	cam.position = Vector3(-1.5, 1.5, 6)
	cam.current = true
	_demo.add_child(cam)
	cam.look_at(Vector3(-1.5, 0.5, -3), Vector3.UP)

	# Cubes — same as demo
	_make_cube(Vector3(-3.0, 0.5, 0.0), 1)
	_make_cube(Vector3(0.0, 0.5, 0.0), 2)
	_make_cube(Vector3(3.0, 0.5, 0.0), 3)
	_make_cube(Vector3(5.0, 0.5, 0.0), 0)
	_make_cube(Vector3(-7.0, 0.5, -10.0), 1)


func _make_cube(at: Vector3, tier: int) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh.mesh = box
	mesh.position = at

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.92, 0.85)
	if tier == 0:
		mat.set("stencil_mode", 0)  # Disabled
	else:
		mat.set("stencil_mode", 3)  # Custom
		mat.set("stencil_flags", 2)  # Write
		mat.set("stencil_compare", 0)  # Always
		mat.set("stencil_reference", tier)
	mesh.material_override = mat
	_demo.add_child(mesh)
	return mesh


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await RenderingServer.frame_post_draw
