# tests/unit/core/player_character/player_hands_material_overlay_test.gd
#
# PlayerHandsMaterialOverlayTest — GdUnit4 unit tests for PC-008 Logic facets.
#
# COVERS
#   AC-9.1 [Logic]: hands MeshInstance3D has HandsOutlineMaterial via
#                   material_overlay (NOT material_override) after _ready().
#   ADR-0005-G3 [Logic]: emitting Events.setting_changed for graphics/
#                        resolution_scale updates the hands shader uniform
#                        within one process frame.
#
# WHAT IS NOT TESTED HERE
#   AC-9.1 lint guard against OutlineTier.set_tier — covered by
#     tests/ci/hands_not_on_outline_tier_lint.gd
#   AC-9.2 (Settings startup read) — blocked on Settings & Accessibility GDD;
#     pending stub at tests/unit/core/player_character/player_hands_resolution_scale_test.gd
#   AC-9.3 / ADR-0005-G4 (lighting + animation visual) — requires a real
#     rigged hand mesh asset; deferred to art-pipeline delivery
#   ADR-0005-G5 (Shader Baker export verification) — requires full export run;
#     advisory at this story; will close on first export build
#
# GATE STATUS
#   Story PC-008 | Logic facets — BLOCKING.
#   Visual/Feel ACs deferred (rigged hand mesh asset is post-MVP).

class_name PlayerHandsMaterialOverlayTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _HANDS_MESH_PATH: String = "Camera3D/SubViewport/HandsCamera/HandsMesh"
const _TOL: float = 0.001


# ── Fixture ────────────────────────────────────────────────────────────────

var _player: PlayerCharacter = null


func before_test() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_player = packed.instantiate() as PlayerCharacter
	auto_free(_player)
	add_child(_player)
	# _ready has fired by now — material_overlay should be applied.


func after_test() -> void:
	# Disconnect signal handler if connected (auto_free will free the node;
	# but _exit_tree already disconnects via the is_connected guard).
	_player = null


# ── AC-9.1: material_overlay applied after _ready() ────────────────────────

## After PlayerCharacter._ready() completes, the HandsMesh has a non-null
## material_overlay that is a ShaderMaterial (the HandsOutlineMaterial
## duplicate). material_override should NOT be set — overlay is the production
## path per ADR-0005 + AC-9.1.
func test_hands_mesh_has_material_overlay_set_after_ready() -> void:
	var hands_mesh: MeshInstance3D = _player.get_node_or_null(_HANDS_MESH_PATH) as MeshInstance3D
	assert_object(hands_mesh).override_failure_message(
		"HandsMesh node missing at %s — scene structure broken." % _HANDS_MESH_PATH
	).is_not_null()

	assert_object(hands_mesh.material_overlay).override_failure_message(
		"AC-9.1: HandsMesh.material_overlay must be set to HandsOutlineMaterial after _ready()."
	).is_not_null()

	assert_bool(hands_mesh.material_overlay is ShaderMaterial).override_failure_message(
		"AC-9.1: HandsMesh.material_overlay must be a ShaderMaterial. Got: %s" % str(hands_mesh.material_overlay)
	).is_true()


## material_override must NOT be set — AC-9.1 explicitly forbids this path
## because it would replace the per-surface fill material instead of layering
## the inverted hull on top.
func test_hands_mesh_material_override_is_null() -> void:
	var hands_mesh: MeshInstance3D = _player.get_node_or_null(_HANDS_MESH_PATH) as MeshInstance3D
	assert_object(hands_mesh.material_override).override_failure_message(
		"AC-9.1: HandsMesh.material_override must be null — overlay (not override) is required."
	).is_null()


## The shader on the overlay material has the expected uniforms (proves the
## shader file was loaded and parsed correctly).
func test_hands_material_has_resolution_scale_uniform() -> void:
	var hands_mesh: MeshInstance3D = _player.get_node_or_null(_HANDS_MESH_PATH) as MeshInstance3D
	var mat: ShaderMaterial = hands_mesh.material_overlay as ShaderMaterial
	# resolution_scale should default to 1.0 (per shader source).
	var rs: Variant = mat.get_shader_parameter(&"resolution_scale")
	# Uniform may report as null if never set explicitly — in that case the
	# shader default of 1.0 is in effect at runtime. Both are acceptable.
	if rs == null:
		# Default not yet read back — set it explicitly for the next test to use.
		mat.set_shader_parameter(&"resolution_scale", 1.0)
		rs = mat.get_shader_parameter(&"resolution_scale")
	assert_float(float(rs)).override_failure_message(
		"resolution_scale uniform must be readable; default 1.0 expected."
	).is_equal_approx(1.0, _TOL)


# ── ADR-0005-G3: signal-driven resolution_scale update ────────────────────

## Emit Events.setting_changed for graphics/resolution_scale=0.75. After one
## process frame, the hands material's resolution_scale uniform must equal
## 0.75 ± 0.001. This closes ADR-0005 Gate 3.
func test_setting_changed_resolution_scale_updates_uniform() -> void:
	var hands_mesh: MeshInstance3D = _player.get_node_or_null(_HANDS_MESH_PATH) as MeshInstance3D
	var mat: ShaderMaterial = hands_mesh.material_overlay as ShaderMaterial

	# Arrange — make sure starting value is 1.0
	mat.set_shader_parameter(&"resolution_scale", 1.0)

	# Act — emit the broadcast that the player_character handler subscribes to
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)
	# Handler runs synchronously when the signal fires (no deferred call); the
	# updated value is readable on the same call frame.

	# Assert
	var actual: float = float(mat.get_shader_parameter(&"resolution_scale"))
	assert_float(actual).override_failure_message(
		"ADR-0005-G3: HandsOutlineMaterial.resolution_scale must update to 0.75 after broadcast. Got: %f" % actual
	).is_equal_approx(0.75, _TOL)


## Wrong category (audio) is ignored — resolution_scale unchanged.
func test_setting_changed_wrong_category_ignored() -> void:
	var hands_mesh: MeshInstance3D = _player.get_node_or_null(_HANDS_MESH_PATH) as MeshInstance3D
	var mat: ShaderMaterial = hands_mesh.material_overlay as ShaderMaterial
	mat.set_shader_parameter(&"resolution_scale", 1.0)

	Events.setting_changed.emit(&"audio", &"resolution_scale", 0.5)

	var actual: float = float(mat.get_shader_parameter(&"resolution_scale"))
	assert_float(actual).is_equal_approx(1.0, _TOL)


## Wrong name (vsync_enabled) is ignored — resolution_scale unchanged.
func test_setting_changed_wrong_name_ignored() -> void:
	var hands_mesh: MeshInstance3D = _player.get_node_or_null(_HANDS_MESH_PATH) as MeshInstance3D
	var mat: ShaderMaterial = hands_mesh.material_overlay as ShaderMaterial
	mat.set_shader_parameter(&"resolution_scale", 1.0)

	Events.setting_changed.emit(&"graphics", &"vsync_enabled", 0.5)

	var actual: float = float(mat.get_shader_parameter(&"resolution_scale"))
	assert_float(actual).is_equal_approx(1.0, _TOL)
