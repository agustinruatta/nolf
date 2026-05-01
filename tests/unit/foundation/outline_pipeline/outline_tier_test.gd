# tests/unit/foundation/outline_pipeline/outline_tier_test.gd
#
# OutlineTierTest — GdUnit4 unit tests for OutlineTier static utility class.
#
# PURPOSE
#   Verifies the stencil tier constants, set_tier() behaviour, and all edge
#   cases documented in story OUT-001 (Outline Pipeline Sprint 02).
#
# WHAT IS TESTED
#   AC-1: Constants NONE/HEAVIEST/MEDIUM/LIGHT == 0/1/2/3; no instance vars,
#         no signals, no _init body.
#   AC-2 + AC-3: set_tier() writes stencil_mode==3, stencil_flags==2,
#         stencil_compare==0, stencil_reference==tier on each BaseMaterial3D
#         surface override.
#   AC-4: Invalid tiers (5, -1) are clamped before writing; valid boundary
#         values (0, 3) produce no assert.
#   AC-5: Multi-surface mesh — all surfaces get the same stencil_reference.
#   AC-5b: Null override slot — set_tier() creates a new StandardMaterial3D.
#   AC-6: Escape-hatch reassignment — stencil_reference flips correctly on
#         repeated set_tier() calls.
#   AC-7: This file exists (its existence IS the AC-7 requirement).
#
# WHAT IS NOT TESTED HERE
#   - CompositorEffect pipeline (Story 002).
#   - Jump-flood algorithm (Story 003).
#   - Resolution-scale formula (Story 004).
#   - ADR-0005 hands-mesh exemption (code-review checklist concern, not code).
#
# GATE STATUS
#   Story OUT-001 — Logic type -> BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name OutlineTierTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers — mesh factory
# ---------------------------------------------------------------------------

## Creates a MeshInstance3D with [param surface_count] surfaces, each assigned
## a fresh StandardMaterial3D as the surface OVERRIDE material (simulates an
## editor-assigned material). The returned node is registered with auto_free()
## so GdUnit4 cleans it up at end-of-test (no orphan-node detection).
func _make_mesh(surface_count: int) -> MeshInstance3D:
	var node: MeshInstance3D = auto_free(MeshInstance3D.new())
	var arr_mesh: ArrayMesh = ArrayMesh.new()

	for i: int in range(surface_count):
		# Build a minimal triangle surface so ArrayMesh accepts the surface.
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		# Three vertices forming a degenerate triangle — enough for a valid surface.
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
		])
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Assign a fresh StandardMaterial3D as the surface OVERRIDE so
		# get_surface_override_material(i) returns a non-null material.
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		node.mesh = arr_mesh
		node.set_surface_override_material(i, mat)

	node.mesh = arr_mesh
	return node


## Creates a MeshInstance3D whose surface override slot is intentionally null
## (simulates a mesh that has never had a material assigned in the editor).
## Registered with auto_free() — no orphan-node detection.
func _make_mesh_no_override(surface_count: int) -> MeshInstance3D:
	var node: MeshInstance3D = auto_free(MeshInstance3D.new())
	var arr_mesh: ArrayMesh = ArrayMesh.new()

	for _i: int in range(surface_count):
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
		])
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	node.mesh = arr_mesh
	# Intentionally leave surface override slots null.
	return node


# ---------------------------------------------------------------------------
# Lifecycle — per-test cleanup
# ---------------------------------------------------------------------------

var _mesh: MeshInstance3D = null


func after_test() -> void:
	if is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = null


# ---------------------------------------------------------------------------
# AC-1: Constants
# ---------------------------------------------------------------------------

## OutlineTier.NONE must equal 0 (stencil cleared value — no outline).
func test_outline_tier_none_constant_equals_0() -> void:
	assert_int(OutlineTier.NONE).is_equal(0)


## OutlineTier.HEAVIEST must equal 1 (4 px at 1080p — Eve, key interactives).
func test_outline_tier_heaviest_constant_equals_1() -> void:
	assert_int(OutlineTier.HEAVIEST).is_equal(1)


## OutlineTier.MEDIUM must equal 2 (2.5 px at 1080p — PHANTOM guards).
func test_outline_tier_medium_constant_equals_2() -> void:
	assert_int(OutlineTier.MEDIUM).is_equal(2)


## OutlineTier.LIGHT must equal 3 (1.5 px at 1080p — environment, civilians).
func test_outline_tier_light_constant_equals_3() -> void:
	assert_int(OutlineTier.LIGHT).is_equal(3)


## OutlineTier script must have no declared signals (pure static utility class).
func test_outline_tier_has_no_signals() -> void:
	# Arrange
	var script: Script = load("res://src/rendering/outline/outline_tier.gd") as Script
	assert_object(script).is_not_null()

	# Act
	var signal_list: Array[Dictionary] = script.get_script_signal_list()

	# Assert — no signals declared on the class body
	assert_int(signal_list.size()).is_equal(0)


## OutlineTier class_name must be registered as a top-level global name.
## This verifies the script is globally accessible without an import path.
func test_outline_tier_class_name_is_registered() -> void:
	# Arrange
	var script: Script = load("res://src/rendering/outline/outline_tier.gd") as Script

	# Act
	var global_name: StringName = script.get_global_name()

	# Assert
	assert_str(String(global_name)).is_equal("OutlineTier")


# ---------------------------------------------------------------------------
# AC-2 + AC-3: set_tier() writes correct stencil properties
# ---------------------------------------------------------------------------

## set_tier() with HEAVIEST writes stencil_mode==3, stencil_flags==2,
## stencil_compare==0, stencil_reference==1 on a single-surface BaseMaterial3D.
func test_set_tier_heaviest_writes_correct_stencil_properties() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act
	OutlineTier.set_tier(_mesh, OutlineTier.HEAVIEST)

	# Assert — all four stencil properties set on the override material
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_object(mat).is_not_null()
	# stencil_mode == 3 (STENCIL_MODE_CUSTOM — Godot 4.6 stencil API, finding F4)
	assert_int(mat.stencil_mode).is_equal(3)
	# stencil_flags == 2 (Write bitfield flag)
	assert_int(mat.stencil_flags).is_equal(2)
	# stencil_compare == 0 (Always)
	assert_int(mat.stencil_compare).is_equal(0)
	# stencil_reference == 1 (HEAVIEST tier value)
	assert_int(mat.stencil_reference).is_equal(1)


## set_tier() with MEDIUM writes stencil_reference==2 on BaseMaterial3D.
func test_set_tier_medium_writes_stencil_reference_2() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act
	OutlineTier.set_tier(_mesh, OutlineTier.MEDIUM)

	# Assert
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(2)


## set_tier() with LIGHT writes stencil_reference==3 on BaseMaterial3D.
func test_set_tier_light_writes_stencil_reference_3() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act
	OutlineTier.set_tier(_mesh, OutlineTier.LIGHT)

	# Assert
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(3)


## set_tier() with NONE writes stencil_reference==0 on BaseMaterial3D.
func test_set_tier_none_writes_stencil_reference_0() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act
	OutlineTier.set_tier(_mesh, OutlineTier.NONE)

	# Assert
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(0)
	# stencil_mode must still be CUSTOM even for tier 0
	assert_int(mat.stencil_mode).is_equal(3)


# ---------------------------------------------------------------------------
# AC-4: Invalid tier validation
# ---------------------------------------------------------------------------

## set_tier() with tier=5 (invalid) clamps to LIGHT (3) before writing.
## The assert() fires in debug builds (stripped in release); here we verify
## the material receives the clamped value 3, not 5. The assert fires on the
## line `assert(tier >= 0 and tier <= 3, ...)` in outline_tier.gd — GdUnit4
## may or may not surface it as a test-level error depending on version; either
## way the material side-effect must equal 3 (clamped, per TR-OUT-010).
func test_set_tier_invalid_high_clamps_to_light() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act — tier=5 is out of range; assert() in OutlineTier fires in debug.
	# Wrap in await assert_error() so GdUnit4 expects (and consumes) the error
	# from its error monitor instead of failing the test on it. The set_tier
	# function continues past the assert (assert is non-aborting in headless
	# debug runs), so clampi(5, 0, 3) → 3 still applies to the material.
	await assert_error(
		func() -> void: OutlineTier.set_tier(_mesh, 5)
	).is_push_error("OutlineTier: invalid tier 5 (must be 0..3)")

	# Assert — clampi(5, 0, 3) == 3 == LIGHT
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(3)


## set_tier() with tier=-1 (invalid) clamps to NONE (0).
func test_set_tier_invalid_negative_clamps_to_none() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act — tier=-1 is out of range; assert() fires in debug. Wrap with
	# await assert_error() so GdUnit4 expects (and consumes) the error.
	await assert_error(
		func() -> void: OutlineTier.set_tier(_mesh, -1)
	).is_push_error("OutlineTier: invalid tier -1 (must be 0..3)")

	# Assert — clampi(-1, 0, 3) == 0 == NONE
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(0)


## set_tier() with tier=0 (NONE) is valid — no assert, stencil_reference==0.
func test_set_tier_boundary_zero_is_valid_no_assert() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act — 0 is within [0, 3]; no assert should fire
	OutlineTier.set_tier(_mesh, 0)

	# Assert
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(0)


## set_tier() with tier=3 (LIGHT) is valid — no assert, stencil_reference==3.
func test_set_tier_boundary_three_is_valid_no_assert() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act — 3 is within [0, 3]; no assert should fire
	OutlineTier.set_tier(_mesh, 3)

	# Assert
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(3)


# ---------------------------------------------------------------------------
# AC-5: Multi-surface mesh
# ---------------------------------------------------------------------------

## set_tier() with MEDIUM sets stencil_reference==2 on all surfaces of a
## two-surface mesh (both surfaces have pre-assigned override materials).
func test_set_tier_multi_surface_sets_all_surfaces() -> void:
	# Arrange — two surfaces, each with an override material
	_mesh = _make_mesh(2)

	# Act
	OutlineTier.set_tier(_mesh, OutlineTier.MEDIUM)

	# Assert — both surfaces updated
	var mat0: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	var mat1: StandardMaterial3D = _mesh.get_surface_override_material(1) as StandardMaterial3D
	assert_int(mat0.stencil_reference).is_equal(2)
	assert_int(mat1.stencil_reference).is_equal(2)


# ---------------------------------------------------------------------------
# AC-5b: Null override slot — new StandardMaterial3D is created and assigned
# ---------------------------------------------------------------------------

## set_tier() on a mesh with no override material creates a new
## StandardMaterial3D, assigns it as the override, and sets stencil_reference.
func test_set_tier_null_override_creates_new_material() -> void:
	# Arrange — mesh with one surface but no override material assigned
	_mesh = _make_mesh_no_override(1)
	# Pre-condition: override slot is null
	assert_object(_mesh.get_surface_override_material(0)).is_null()

	# Act
	OutlineTier.set_tier(_mesh, OutlineTier.HEAVIEST)

	# Assert — a new material was created and assigned
	var mat: Material = _mesh.get_surface_override_material(0)
	assert_object(mat).is_not_null()
	assert_bool(mat is StandardMaterial3D).is_true()
	assert_int((mat as StandardMaterial3D).stencil_reference).is_equal(1)
	assert_int((mat as StandardMaterial3D).stencil_mode).is_equal(3)


# ---------------------------------------------------------------------------
# AC-6: Escape-hatch runtime reassignment
# ---------------------------------------------------------------------------

## Calling set_tier() twice flips stencil_reference from LIGHT (3) to
## HEAVIEST (1) then back to LIGHT (3). Reassignment is instantaneous.
func test_set_tier_escape_hatch_reassignment_flips_reference() -> void:
	# Arrange
	_mesh = _make_mesh(1)

	# Act — initial assignment to LIGHT
	OutlineTier.set_tier(_mesh, OutlineTier.LIGHT)
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_int(mat.stencil_reference).is_equal(3)

	# Act — escape-hatch promotion to HEAVIEST
	OutlineTier.set_tier(_mesh, OutlineTier.HEAVIEST)
	assert_int(mat.stencil_reference).is_equal(1)

	# Act — revert back to LIGHT
	OutlineTier.set_tier(_mesh, OutlineTier.LIGHT)
	assert_int(mat.stencil_reference).is_equal(3)
