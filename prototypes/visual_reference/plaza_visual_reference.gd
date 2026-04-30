# prototypes/visual_reference/plaza_visual_reference.gd
#
# NOLF 1 visual-register calibration scene. NOT a production scene; not the
# real Plaza level. This is a prototype per `.claude/rules/prototype-code.md`
# — placeholder primitives, hardcoded values, the goal is reaction-tuning the
# art direction by looking at it rather than by spec.
#
# READ FIRST: prototypes/visual_reference/README.md
#
# WHAT TO LOOK AT
#   1. Outline tier deltas (Eve hand / document / guard / environment)
#   2. Two-temperature lighting (warm pendant pool vs cool ambient fill)
#   3. Color contrast (PHANTOM red on guard, BQA blue on document, Parisian
#      yellow walls, Eiffel grey floor)
#   4. Silhouette grammar (does the guard's bowl helmet read as a circle?)
#
# CONTROLS
#   WASD = walk; mouse = look; Q/E = down/up; Esc = quit.
#
# REUSES the inverted-hull outline shader from the Sprint 01 verification
# spike (`prototypes/verification-spike/inverted_hull_outline.gdshader`) —
# this is fine: prototypes may reference other prototypes (per project rules),
# only production code is forbidden from referencing prototypes.

extends Node3D


const INVERTED_HULL_SHADER := preload("res://prototypes/verification-spike/inverted_hull_outline.gdshader")

# Outline thickness per tier — matches ADR-0001 stencil tier values for visual
# parity with the eventual production shader (which will use stencil-buffer +
# jump-flood; this is a quick-and-dirty inverted-hull preview).
const TIER_WIDTH_M := {
	0: 0.040,   # HEAVIEST (Eve, 5 px @ 1080p)
	1: 0.032,   # HEAVY (documents, 4 px @ 1080p)
	2: 0.024,   # MEDIUM (guards, 3 px @ 1080p)
	3: 0.016,   # LIGHTEST (environment, 2 px @ 1080p)
}

# NOLF1-grammar palette — sourced from art-bible.md §4 (Color System):
#   "Saturated primaries and complementary contrasts (PHANTOM red against BQA
#    blue; warm Parisian yellow against cool Eiffel grey)."
const COLOR_OUTLINE     := Color(0.05, 0.05, 0.08)        # near-black ink
const COLOR_PARIS_YELLOW := Color(0.93, 0.82, 0.45)       # warm Parisian wall
const COLOR_EIFFEL_GREY  := Color(0.42, 0.46, 0.52)       # cool Eiffel floor
const COLOR_PHANTOM_RED  := Color(0.78, 0.18, 0.18)       # PHANTOM faction red
const COLOR_BQA_BLUE     := Color(0.20, 0.32, 0.56)       # BQA institutional blue
const COLOR_GUARD_BODY   := Color(0.26, 0.28, 0.30)       # guard tunic dark grey
const COLOR_HELMET_DOME  := Color(0.32, 0.34, 0.36)       # helmet metal
const COLOR_EVE_GLOVE    := Color(0.65, 0.42, 0.28)       # Eve placeholder leather
const COLOR_PODIUM       := Color(0.55, 0.50, 0.45)       # period stone

# Camera + input.
@onready var _camera: Camera3D = null
var _yaw: float = 0.0
var _pitch: float = 0.0
const MOUSE_SENS := 0.0025
const MOVE_SPEED := 3.0


func _ready() -> void:
	_build_environment()
	_build_lighting()
	_build_camera()
	_build_room()
	_build_eve_hand()
	_build_guard()
	_build_document_on_podium()
	_print_summary()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _print_summary() -> void:
	print("[plaza_visual_reference] NOLF 1 calibration scene loaded.")
	print("  Outline tiers: Eve=Tier0 (heaviest), Doc=Tier1, Guard=Tier2, Env=Tier3 (lightest)")
	print("  Palette: Parisian yellow walls / Eiffel grey floor / PHANTOM red trim / BQA blue")
	print("  Lighting: warm pendant pool + cool ambient fill (two-temperature philosophy)")
	print("  Controls: WASD walk, mouse look, Q/E down/up, Esc quit")


# ─── Environment + lighting ────────────────────────────────────────────────

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.22, 0.28)  # cool dim — between-pendant fill
	env.ambient_light_color = Color(0.55, 0.60, 0.72)  # cool ambient (Eiffel grey tint)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env_node.environment = env
	add_child(env_node)


func _build_lighting() -> void:
	# Warm pendant overhead — diegetic light source per art-bible §2.
	var pendant := OmniLight3D.new()
	pendant.position = Vector3(0.0, 3.4, 0.0)
	pendant.light_color = Color(1.0, 0.78, 0.42)  # warm tungsten
	pendant.light_energy = 4.5
	pendant.omni_range = 8.0
	pendant.omni_attenuation = 1.4
	pendant.shadow_enabled = true
	add_child(pendant)

	# Pendant fixture cosmetic — small dark sphere with warm emissive ring so
	# the pendant reads as in-world even though it casts the actual light.
	var fixture := MeshInstance3D.new()
	var fixture_mesh := SphereMesh.new()
	fixture_mesh.radius = 0.10
	fixture_mesh.height = 0.20
	fixture.mesh = fixture_mesh
	var fixture_mat := StandardMaterial3D.new()
	fixture_mat.albedo_color = Color(0.08, 0.06, 0.04)
	fixture_mat.emission_enabled = true
	fixture_mat.emission = Color(1.0, 0.78, 0.42)
	fixture_mat.emission_energy_multiplier = 2.0
	fixture.material_override = fixture_mat
	fixture.position = Vector3(0.0, 3.45, 0.0)
	add_child(fixture)

	# Cool fill — cool sky-bias secondary so the unlit walls don't crush black.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, 35.0, 0.0)
	fill.light_color = Color(0.65, 0.78, 1.0)  # cool sky
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	add_child(fill)


# ─── Camera + input ────────────────────────────────────────────────────────

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 1.65, 4.0)
	_camera.fov = 75.0
	_camera.current = true
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.5, 0.0), Vector3.UP)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clampf(_pitch, -1.4, 1.4)
		var basis := Basis()
		basis = basis.rotated(Vector3.UP, _yaw)
		basis = basis.rotated(basis.x, _pitch)
		_camera.basis = basis
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_dir -= _camera.basis.z
	if Input.is_key_pressed(KEY_S): input_dir += _camera.basis.z
	if Input.is_key_pressed(KEY_A): input_dir -= _camera.basis.x
	if Input.is_key_pressed(KEY_D): input_dir += _camera.basis.x
	if Input.is_key_pressed(KEY_Q): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_E): input_dir.y += 1.0
	if input_dir.length_squared() > 0.001:
		_camera.position += input_dir.normalized() * MOVE_SPEED * delta


# ─── Room ──────────────────────────────────────────────────────────────────
# Plaza-flavoured enclosed test box: 10 × 6 × 4 m with two-temperature shell.
func _build_room() -> void:
	# Floor — cool Eiffel grey with light period-stone variation.
	_make_box(Vector3(0.0, -0.05, 0.0), Vector3(10.0, 0.1, 10.0), COLOR_EIFFEL_GREY, 3)

	# Walls — warm Parisian yellow.
	_make_box(Vector3(0.0, 2.0, -5.0), Vector3(10.0, 4.0, 0.1), COLOR_PARIS_YELLOW, 3)  # back
	_make_box(Vector3(0.0, 2.0, 5.0), Vector3(10.0, 4.0, 0.1), COLOR_PARIS_YELLOW, 3)   # front
	_make_box(Vector3(-5.0, 2.0, 0.0), Vector3(0.1, 4.0, 10.0), COLOR_PARIS_YELLOW, 3)  # left
	_make_box(Vector3(5.0, 2.0, 0.0), Vector3(0.1, 4.0, 10.0), COLOR_PARIS_YELLOW, 3)   # right

	# Ceiling — slightly darker so the pendant pool reads.
	_make_box(Vector3(0.0, 4.05, 0.0), Vector3(10.0, 0.1, 10.0), COLOR_PARIS_YELLOW * 0.7, 3)

	# Wainscot strip — Eiffel grey accent at floor line for two-temperature read.
	_make_box(Vector3(0.0, 0.4, -4.95), Vector3(10.0, 0.8, 0.05), COLOR_EIFFEL_GREY, 3)
	_make_box(Vector3(0.0, 0.4, 4.95), Vector3(10.0, 0.8, 0.05), COLOR_EIFFEL_GREY, 3)


# ─── Eve hand placeholder (Tier 0 — HEAVIEST) ──────────────────────────────
# A single capsule rotated to suggest a forearm reaching forward. Not a real
# hand — calibration target for outline weight on the foreground HEAVIEST tier.
func _build_eve_hand() -> void:
	var pivot := Node3D.new()
	pivot.name = "Eve_HandPlaceholder_Tier0"
	pivot.position = Vector3(0.6, 1.45, 2.6)
	pivot.rotation_degrees = Vector3(75.0, -10.0, 0.0)
	add_child(pivot)
	_make_outlined_capsule(pivot, 0.4, 0.07, COLOR_EVE_GLOVE, 0)


# ─── PHANTOM guard placeholder (Tier 2 — MEDIUM) ───────────────────────────
# Capsule body + dome helmet + red trim ring. The art-bible specifies "rounded
# industrial mass: bowl helmet with slight forward overhang, padded shoulders,
# short wide stance" — this is a primitive approximation to test silhouette.
func _build_guard() -> void:
	var pivot := Node3D.new()
	pivot.name = "PHANTOM_Guard_Tier2"
	pivot.position = Vector3(-2.4, 0.0, -3.0)
	pivot.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	add_child(pivot)

	# Body — capsule, "short wide stance"
	_make_outlined_capsule(pivot, 1.4, 0.32, COLOR_GUARD_BODY, 2, Vector3(0.0, 0.95, 0.0))

	# Padded shoulders — flat box stub on top of body, slightly wider than body
	var shoulders := MeshInstance3D.new()
	var shoulder_mesh := BoxMesh.new()
	shoulder_mesh.size = Vector3(0.85, 0.18, 0.50)
	shoulders.mesh = shoulder_mesh
	shoulders.position = Vector3(0.0, 1.55, 0.0)
	shoulders.material_override = _make_albedo_material(COLOR_GUARD_BODY)
	pivot.add_child(shoulders)
	_attach_outline_pass(shoulders, shoulder_mesh, COLOR_OUTLINE, TIER_WIDTH_M[2])

	# Helmet dome — sphere; the identifier silhouette
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.22
	helmet_mesh.height = 0.40
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 1.86, 0.05)  # slight forward overhang per art-bible
	helmet.material_override = _make_albedo_material(COLOR_HELMET_DOME)
	pivot.add_child(helmet)
	_attach_outline_pass(helmet, helmet_mesh, COLOR_OUTLINE, TIER_WIDTH_M[2])

	# Red trim ring around helmet base — the PHANTOM-red faction confirmer
	var trim := MeshInstance3D.new()
	var trim_mesh := TorusMesh.new()
	trim_mesh.inner_radius = 0.20
	trim_mesh.outer_radius = 0.235
	trim.mesh = trim_mesh
	trim.position = Vector3(0.0, 1.71, 0.05)
	trim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = COLOR_PHANTOM_RED
	trim_mat.metallic = 0.0
	trim_mat.roughness = 0.55
	trim.material_override = trim_mat
	pivot.add_child(trim)
	# Trim does NOT get its own outline — the helmet sphere outline encompasses it


# ─── Document placeholder on podium (Tier 1 — HEAVY) ───────────────────────
# Flat plane in BQA blue on a period-stone podium. Tests the "foreground
# graphic artifact" reading per art-bible §9 NOLF 1 reference.
func _build_document_on_podium() -> void:
	var pivot := Node3D.new()
	pivot.name = "PlazaDocument_Tier1_OnPodium"
	pivot.position = Vector3(2.4, 0.0, -2.0)
	add_child(pivot)

	# Podium — three boxes (base, column, top) — Tier 3 (environment)
	_make_box(Vector3(0.0, 0.10, 0.0), Vector3(0.8, 0.20, 0.5), COLOR_PODIUM, 3, pivot)
	_make_box(Vector3(0.0, 0.55, 0.0), Vector3(0.5, 0.70, 0.35), COLOR_PODIUM * 1.05, 3, pivot)
	_make_box(Vector3(0.0, 0.95, 0.0), Vector3(0.7, 0.10, 0.45), COLOR_PODIUM * 0.85, 3, pivot)

	# Document — flat plane angled toward viewer
	var doc := MeshInstance3D.new()
	doc.name = "Document_Tier1"
	var doc_mesh := BoxMesh.new()
	doc_mesh.size = Vector3(0.32, 0.005, 0.42)
	doc.mesh = doc_mesh
	doc.position = Vector3(0.0, 1.005, 0.0)
	doc.rotation_degrees = Vector3(-12.0, 0.0, 0.0)  # tilted toward camera
	var doc_mat := StandardMaterial3D.new()
	doc_mat.albedo_color = COLOR_BQA_BLUE
	doc_mat.metallic = 0.0
	doc_mat.roughness = 0.85
	doc.material_override = doc_mat
	pivot.add_child(doc)
	_attach_outline_pass(doc, doc_mesh, COLOR_OUTLINE, TIER_WIDTH_M[1])

	# Cream paper accent strip across the document — period-document register
	# (BQA letterhead dark band over cream)
	var paper := MeshInstance3D.new()
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(0.26, 0.006, 0.32)
	paper.mesh = paper_mesh
	paper.position = Vector3(0.0, 0.001, 0.0)
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.92, 0.88, 0.78)  # cream
	paper.material_override = paper_mat
	doc.add_child(paper)


# ─── Helpers ───────────────────────────────────────────────────────────────

func _make_box(center: Vector3, size: Vector3, color: Color, tier: int, parent: Node = null) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = center
	box.material_override = _make_albedo_material(color)
	if parent != null:
		parent.add_child(box)
	else:
		add_child(box)
	# Walls / floor / ceiling get the lightest outline (tier 3)
	if tier in TIER_WIDTH_M:
		_attach_outline_pass(box, mesh, COLOR_OUTLINE, TIER_WIDTH_M[tier])
	return box


func _make_outlined_capsule(parent: Node3D, height: float, radius: float, color: Color, tier: int, offset: Vector3 = Vector3.ZERO) -> void:
	var mesh_resource := CapsuleMesh.new()
	mesh_resource.height = height
	mesh_resource.radius = radius

	var body := MeshInstance3D.new()
	body.mesh = mesh_resource
	body.position = offset
	body.material_override = _make_albedo_material(color)
	parent.add_child(body)
	_attach_outline_pass(body, mesh_resource, COLOR_OUTLINE, TIER_WIDTH_M[tier])


func _attach_outline_pass(host: MeshInstance3D, mesh_resource: Mesh, outline_color: Color, width: float) -> void:
	# Inverted-hull outline pass — child MeshInstance3D sharing the host mesh,
	# rendered with the inverted-hull shader. Follows the same pattern as
	# prototypes/verification-spike/fps_hands_demo.gd.
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = INVERTED_HULL_SHADER
	outline_mat.set_shader_parameter("outline_color", outline_color)
	# Shader parameter is named `outline_thickness` in the inverted-hull shader
	# (range 0..0.1 m). Clamp to that range.
	outline_mat.set_shader_parameter("outline_thickness", clampf(width, 0.0, 0.1))

	var outline_mesh := MeshInstance3D.new()
	outline_mesh.mesh = mesh_resource
	outline_mesh.material_override = outline_mat
	# Host's local transform applies to outline; outline is in same local space.
	host.add_child(outline_mesh)


func _make_albedo_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.78
	return mat
