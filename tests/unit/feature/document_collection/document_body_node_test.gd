# tests/unit/feature/document_collection/document_body_node_test.gd
#
# DocumentBodyNodeTest — GdUnit4 unit suite for the DocumentBody scene node.
#
# PURPOSE
#   Validates DocumentBody per Document Collection GDD AC-DC-1.1 (§H.1, §C.3,
#   §C.5.8). This suite is the automated evidence gate for Story DC-002.
#
# COVERED ACCEPTANCE CRITERIA
#   AC-1  — get_interact_priority() returns 0 (DOCUMENT priority, highest).
#   AC-2  — collision_layer == PhysicsLayers.MASK_INTERACTABLES; no other bits set.
#   AC-2  — collision_mask == 0 (non-blocking; "documents don't push Eve").
#   AC-3  — Template scene structure: StaticBody3D root with CollisionShape3D
#            (BoxShape3D ≈ Vector3(0.30, 0.05, 0.20)) + MeshInstance3D child;
#            root in group "section_documents".
#   AC-4  — MeshInstance3D surface_material_override/0 has stencil_mode == 3
#            (CUSTOM) and stencil_reference == 1 (Tier 1 HEAVIEST).
#   AC-5  — Full integration: instantiate template, verify priority + layers.
#   CR-15 — No _process or _physics_process override in document_body.gd.
#
# WHAT IS NOT TESTED HERE
#   - DocumentCollection pickup logic (DC-003).
#   - Plaza-section .tres Document Resources (DC-005).
#   - Runtime OutlineTier.set_tier() — template is scene-baked (ADR-0001 IG 2).
#   - The 7 category meshes (art pipeline, not code).
#
# GATE STATUS
#   Story DC-002 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name DocumentBodyNodeTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/documents/document_body.tscn"
const _SCRIPT_PATH: String = "res://src/gameplay/documents/document_body.gd"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a freshly instantiated DocumentBody from the template scene.
## auto_free() ensures cleanup after each test regardless of assertions.
func _make_body() -> DocumentBody:
	var scene: PackedScene = load(_SCENE_PATH)
	var body: DocumentBody = scene.instantiate() as DocumentBody
	auto_free(body)
	return body


# ---------------------------------------------------------------------------
# AC-1 / AC-5 — get_interact_priority() returns 0
# ---------------------------------------------------------------------------

## get_interact_priority() must return 0 (DOCUMENT priority = highest).
## Beats TERMINAL=1, PICKUP=2, DOOR=3 — GDD §C.3 + AC-DC-1.1 §H.1.
func test_interact_priority_returns_zero() -> void:
	# Arrange
	var body: DocumentBody = _make_body()

	# Act
	var priority: int = body.get_interact_priority()

	# Assert
	assert_int(priority).override_failure_message(
		"AC-1/AC-5: get_interact_priority() must return 0 (DOCUMENT priority — highest)."
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-2 / AC-5 — collision_layer is MASK_INTERACTABLES with no other bits
# ---------------------------------------------------------------------------

## collision_layer must equal PhysicsLayers.MASK_INTERACTABLES (bitmask = 8)
## with no other bits set. ADR-0006 IG 1 + IG 8 + GDD §C.5.6 lint #5.
func test_collision_layer_is_interactables_only() -> void:
	# Arrange
	var body: DocumentBody = _make_body()

	# Act
	var layer: int = body.collision_layer

	# Assert — exact equality confirms no extra bits are set
	assert_int(layer).override_failure_message(
		"AC-2/AC-5: collision_layer must equal PhysicsLayers.MASK_INTERACTABLES (%d). Got %d."
		% [PhysicsLayers.MASK_INTERACTABLES, layer]
	).is_equal(PhysicsLayers.MASK_INTERACTABLES)


## collision_mask must equal 0 — documents participate in raycasts but do NOT
## block any movement (ADR-0006 IG 8 — "documents don't push Eve").
func test_collision_mask_is_zero() -> void:
	# Arrange
	var body: DocumentBody = _make_body()

	# Act
	var mask: int = body.collision_mask

	# Assert
	assert_int(mask).override_failure_message(
		"AC-2/AC-5: collision_mask must equal 0 (non-blocking; 'documents don't push Eve')."
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-3 — Template scene has correct child structure
# ---------------------------------------------------------------------------

## Root is DocumentBody (StaticBody3D), has CollisionShape3D with BoxShape3D
## sized approximately Vector3(0.30, 0.05, 0.20), has MeshInstance3D child,
## and root is in group "section_documents".
func test_template_scene_has_correct_child_structure() -> void:
	# Arrange
	var body: DocumentBody = _make_body()

	# Assert — root is StaticBody3D
	assert_bool(body is StaticBody3D).override_failure_message(
		"AC-3: DocumentBody root must be a StaticBody3D."
	).is_true()

	# Assert — CollisionShape3D child is present
	var col: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_object(col).override_failure_message(
		"AC-3: DocumentBody must have a CollisionShape3D child named 'CollisionShape3D'."
	).is_not_null()

	# Assert — shape is BoxShape3D
	assert_bool(col.shape is BoxShape3D).override_failure_message(
		"AC-3: CollisionShape3D.shape must be a BoxShape3D."
	).is_true()

	# Assert — box dimensions within 0.001 tolerance of Vector3(0.30, 0.05, 0.20)
	var box: BoxShape3D = col.shape as BoxShape3D
	var expected_size: Vector3 = Vector3(0.3, 0.05, 0.2)
	assert_bool(box.size.distance_to(expected_size) < 0.001).override_failure_message(
		"AC-3: BoxShape3D.size must be approximately Vector3(0.30, 0.05, 0.20). Got %s."
		% str(box.size)
	).is_true()

	# Assert — MeshInstance3D child is present
	var mesh: MeshInstance3D = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_object(mesh).override_failure_message(
		"AC-3: DocumentBody must have a MeshInstance3D child named 'MeshInstance3D'."
	).is_not_null()

	# Assert — root is in group "section_documents"
	assert_bool(body.is_in_group(&"section_documents")).override_failure_message(
		"AC-3: DocumentBody root must be in group 'section_documents'."
	).is_true()


# ---------------------------------------------------------------------------
# AC-4 — Stencil Tier 1 scene-baked on MeshInstance3D override material
# ---------------------------------------------------------------------------

## MeshInstance3D surface_material_override/0 must exist with stencil_mode == 3
## (STENCIL_MODE_CUSTOM per ADR-0001 + Sprint 01 finding F4) and
## stencil_reference == 1 (Tier 1 HEAVIEST — 4 px @ 1080p per ADR-0001 §Decision).
## Override slot is used (not mesh surface material) because mesh is null in template.
## Per ADR-0001 IG 2: scene-baked, NOT set via runtime OutlineTier.set_tier().
func test_stencil_tier_one_scene_baked() -> void:
	# Arrange
	var body: DocumentBody = _make_body()
	var mesh: MeshInstance3D = body.get_node_or_null("MeshInstance3D") as MeshInstance3D

	assert_object(mesh).override_failure_message(
		"AC-4: MeshInstance3D child must exist to read stencil material."
	).is_not_null()

	# Act — read surface override material (independent of mesh; mesh is null in template)
	var mat: Material = mesh.get_surface_override_material(0)

	# Assert — override material is present
	assert_object(mat).override_failure_message(
		"AC-4: MeshInstance3D surface_material_override/0 must be non-null. " +
		"Stencil tier is baked on the override material slot per ADR-0001 IG 2 " +
		"(mesh is null in template so material must live on the override slot)."
	).is_not_null()

	assert_bool(mat is BaseMaterial3D).override_failure_message(
		"AC-4: surface_material_override/0 must be a BaseMaterial3D (StandardMaterial3D). " +
		"Got: %s." % mat.get_class()
	).is_true()

	var base_mat: BaseMaterial3D = mat as BaseMaterial3D

	# Assert — stencil_mode == 3 (STENCIL_MODE_CUSTOM)
	assert_int(base_mat.stencil_mode).override_failure_message(
		"AC-4: stencil_mode must be 3 (STENCIL_MODE_CUSTOM per ADR-0001 + finding F4). Got %d."
		% base_mat.stencil_mode
	).is_equal(3)

	# Assert — stencil_reference == 1 (Tier 1 HEAVIEST)
	assert_int(base_mat.stencil_reference).override_failure_message(
		"AC-4: stencil_reference must be 1 (Tier 1 HEAVIEST — 4 px @ 1080p). Got %d."
		% base_mat.stencil_reference
	).is_equal(1)


# ---------------------------------------------------------------------------
# CR-15 — No _process or _physics_process override in document_body.gd
# ---------------------------------------------------------------------------

## document_body.gd must NOT define func _process or func _physics_process.
## Verified by scanning the GDScript source text (headless-safe approach;
## has_method() returns true for inherited methods and cannot distinguish overrides).
## ADR rationale: CR-15 zero-steady-state budget — DocumentBody is a pure
## data-presentation node with zero per-frame cost.
func test_no_process_or_physics_process_override() -> void:
	# Arrange
	var script: GDScript = load(_SCRIPT_PATH) as GDScript

	assert_object(script).override_failure_message(
		"CR-15: document_body.gd must load as a GDScript resource."
	).is_not_null()

	# Act
	var source: String = script.source_code

	# Assert — no func _process definition
	assert_bool(source.contains("func _process(")).override_failure_message(
		"CR-15: document_body.gd must NOT define _process (zero-steady-state budget per CR-15)."
	).is_false()

	# Assert — no func _physics_process definition
	assert_bool(source.contains("func _physics_process(")).override_failure_message(
		"CR-15: document_body.gd must NOT define _physics_process (zero-steady-state budget per CR-15)."
	).is_false()
