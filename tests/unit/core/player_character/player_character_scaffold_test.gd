# tests/unit/core/player_character/player_character_scaffold_test.gd
#
# PlayerCharacterScaffoldTest — GdUnit4 suite for Story PC-001 acceptance criteria.
#
# PURPOSE
#   Proves that the PlayerCharacter scaffold (PC-001) satisfies AC-1 through AC-6:
#   enum host correctness, NoiseEvent field contract, scene hierarchy, collision
#   layer setup via PhysicsLayers constants, capsule dimensions, and script vars.
#
# WHAT IS TESTED
#   AC-1: PlayerEnums.MovementState has 7 members (IDLE=0 … DEAD=6).
#   AC-2: PlayerEnums.NoiseType has 6 members.
#   AC-3: NoiseEvent default fields, RefCounted (not Resource), in-place mutation doc.
#   AC-4: PlayerCharacter scene loads, root is CharacterBody3D / PlayerCharacter.
#   AC-5: Scene has required child nodes (CollisionShape3D, ShapeCast3D, Camera3D,
#         Camera3D/HandAnchor).
#   AC-6: CollisionShape3D uses CapsuleShape3D with height=1.7, radius=0.3.
#   AC-7: Camera3D at local Y = 1.6 m.
#   AC-8: Collision layer/mask set via PhysicsLayers constants in _ready().
#   AC-9: No bare integer collision literals in player_character.gd source.
#   AC-10: PlayerCharacter declares current_state (IDLE) and _physics_process.
#
# WHAT IS NOT TESTED HERE
#   - Movement logic (Story PC-003).
#   - Noise spike emission (Story PC-004).
#   - Interact raycast (Story PC-005).
#   - Health system (Story PC-006).
#
# GATE STATUS
#   Story PC-001 | Logic type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name PlayerCharacterScaffoldTest
extends GdUnitTestSuite

# Capsule tolerance for floating-point comparisons.
const _TOLERANCE: float = 0.001


# ---------------------------------------------------------------------------
# AC-1: PlayerEnums.MovementState — 7 members, correct ordinal values
# ---------------------------------------------------------------------------

## MovementState must have exactly 7 members with the ordinal assignment
## IDLE=0, WALK=1, SPRINT=2, CROUCH=3, JUMP=4, FALL=5, DEAD=6.
func test_player_enums_movement_state_has_seven_members() -> void:
	# Arrange + Act (direct const access — no instantiation needed)
	# Assert ordinal values match the GDD enum declaration order.
	assert_int(PlayerEnums.MovementState.IDLE).is_equal(0)
	assert_int(PlayerEnums.MovementState.WALK).is_equal(1)
	assert_int(PlayerEnums.MovementState.SPRINT).is_equal(2)
	assert_int(PlayerEnums.MovementState.CROUCH).is_equal(3)
	assert_int(PlayerEnums.MovementState.JUMP).is_equal(4)
	assert_int(PlayerEnums.MovementState.FALL).is_equal(5)
	assert_int(PlayerEnums.MovementState.DEAD).is_equal(6)


# ---------------------------------------------------------------------------
# AC-2: PlayerEnums.NoiseType — 6 members
# ---------------------------------------------------------------------------

## NoiseType must declare exactly 6 members in the GDD-specified order.
func test_player_enums_noise_type_has_six_members() -> void:
	# Arrange + Act (direct const access)
	assert_int(PlayerEnums.NoiseType.FOOTSTEP_SOFT).is_equal(0)
	assert_int(PlayerEnums.NoiseType.FOOTSTEP_NORMAL).is_equal(1)
	assert_int(PlayerEnums.NoiseType.FOOTSTEP_LOUD).is_equal(2)
	assert_int(PlayerEnums.NoiseType.JUMP_TAKEOFF).is_equal(3)
	assert_int(PlayerEnums.NoiseType.LANDING_SOFT).is_equal(4)
	assert_int(PlayerEnums.NoiseType.LANDING_HARD).is_equal(5)


# ---------------------------------------------------------------------------
# AC-3a: NoiseEvent — default field values + RefCounted (not Resource)
# ---------------------------------------------------------------------------

## NoiseEvent.new() must expose type=FOOTSTEP_SOFT, radius_m=0.0, origin=ZERO.
## Instance must be RefCounted but NOT Resource (wrong allocator overhead).
func test_noise_event_default_field_values() -> void:
	# Arrange
	var ne: NoiseEvent = NoiseEvent.new()

	# Act + Assert — field defaults
	assert_int(ne.type).is_equal(PlayerEnums.NoiseType.FOOTSTEP_SOFT)
	assert_float(ne.radius_m).is_equal(0.0)
	assert_bool(ne.origin == Vector3.ZERO).is_true()

	# Assert — must be RefCounted.
	assert_bool(ne is RefCounted).is_true()

	# Assert — must NOT be Resource. GDScript static typing rejects `ne is Resource`
	# at parse time (NoiseEvent extends RefCounted, not Resource — the type system
	# knows it can never be true). Use ClassDB.is_parent_class to verify the
	# inheritance chain does NOT pass through Resource at runtime.
	var inherits_resource: bool = ClassDB.is_parent_class(ne.get_class(), "Resource")
	assert_bool(inherits_resource).override_failure_message(
		"NoiseEvent must NOT extend Resource (wrong allocator — see GDD F.4)."
	).is_false()


# ---------------------------------------------------------------------------
# AC-3b: NoiseEvent — "In-place mutation is intentional" doc comment present
# ---------------------------------------------------------------------------

## The NoiseEvent source must contain the exact design-intent doc comment
## "In-place mutation is intentional" so future readers understand the
## zero-allocation design contract (GDD F.4).
func test_noise_event_doc_comment_explains_in_place_mutation() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(
		"res://src/gameplay/player/noise_event.gd"
	)

	# Act + Assert
	assert_bool(source.length() > 0).override_failure_message(
		"noise_event.gd could not be read — file missing or empty."
	).is_true()
	assert_bool(source.contains("In-place mutation is intentional")).override_failure_message(
		"noise_event.gd missing required doc comment 'In-place mutation is intentional'."
	).is_true()


# ---------------------------------------------------------------------------
# AC-4: Scene loads — root is PlayerCharacter / CharacterBody3D
# ---------------------------------------------------------------------------

## PlayerCharacter.tscn must load as a PackedScene; instantiating it must
## yield a node that is both CharacterBody3D and PlayerCharacter.
func test_player_character_scene_loads_with_correct_root_class() -> void:
	# Arrange
	var packed: PackedScene = load(
		"res://src/gameplay/player/PlayerCharacter.tscn"
	) as PackedScene

	# Assert — packed scene is non-null
	assert_object(packed).is_not_null()

	# Act — instantiate
	var inst: Node = packed.instantiate()
	auto_free(inst)

	# Assert — root is correct types
	assert_bool(inst is CharacterBody3D).override_failure_message(
		"Scene root must be CharacterBody3D."
	).is_true()
	assert_bool(inst is PlayerCharacter).override_failure_message(
		"Scene root must be PlayerCharacter (class_name on script)."
	).is_true()


# ---------------------------------------------------------------------------
# AC-5: Scene hierarchy — required children present
# ---------------------------------------------------------------------------

## The scene must contain CollisionShape3D, ShapeCast3D, Camera3D, and
## Camera3D/HandAnchor as direct or nested children per the GDD hierarchy.
func test_player_character_scene_has_required_child_nodes() -> void:
	# Arrange
	var packed: PackedScene = load(
		"res://src/gameplay/player/PlayerCharacter.tscn"
	) as PackedScene
	var inst: Node = packed.instantiate()
	auto_free(inst)

	# Act + Assert — direct children
	assert_object(inst.get_node_or_null(^"CollisionShape3D")).override_failure_message(
		"Missing required child: CollisionShape3D"
	).is_not_null()

	assert_object(inst.get_node_or_null(^"ShapeCast3D")).override_failure_message(
		"Missing required child: ShapeCast3D"
	).is_not_null()

	assert_object(inst.get_node_or_null(^"Camera3D")).override_failure_message(
		"Missing required child: Camera3D"
	).is_not_null()

	# Assert — HandAnchor nested under Camera3D
	var cam: Node = inst.get_node(^"Camera3D")
	assert_object(cam.get_node_or_null(^"HandAnchor")).override_failure_message(
		"Missing required child: Camera3D/HandAnchor"
	).is_not_null()


# ---------------------------------------------------------------------------
# AC-6: Capsule dimensions — height=1.7, radius=0.3
# ---------------------------------------------------------------------------

## The CollisionShape3D child must use a CapsuleShape3D with height=1.7 and
## radius=0.3 (total capsule height including hemispherical caps, per GDD
## §Detailed Design Core Rules — standing pose).
func test_player_character_capsule_shape_dimensions() -> void:
	# Arrange
	var packed: PackedScene = load(
		"res://src/gameplay/player/PlayerCharacter.tscn"
	) as PackedScene
	var inst: Node = packed.instantiate()
	auto_free(inst)

	var col_shape: CollisionShape3D = inst.get_node(^"CollisionShape3D") as CollisionShape3D
	assert_object(col_shape).override_failure_message(
		"CollisionShape3D child not found or wrong type."
	).is_not_null()

	var capsule: CapsuleShape3D = col_shape.shape as CapsuleShape3D
	assert_object(capsule).override_failure_message(
		"CollisionShape3D.shape must be a CapsuleShape3D."
	).is_not_null()

	# Act + Assert — dimensions within tolerance
	assert_bool(is_equal_approx(capsule.height, 1.7)).override_failure_message(
		"CapsuleShape3D.height must be 1.7 (got %f)" % capsule.height
	).is_true()
	assert_bool(is_equal_approx(capsule.radius, 0.3)).override_failure_message(
		"CapsuleShape3D.radius must be 0.3 (got %f)" % capsule.radius
	).is_true()


# ---------------------------------------------------------------------------
# AC-7: Camera at eye height — local Y = 1.6
# ---------------------------------------------------------------------------

## Camera3D must be positioned at local Y = 1.6 m (approximate eye level for
## a 1.7 m standing capsule). Tolerance 0.001 m.
func test_player_character_camera_at_eye_height() -> void:
	# Arrange
	var packed: PackedScene = load(
		"res://src/gameplay/player/PlayerCharacter.tscn"
	) as PackedScene
	var inst: Node = packed.instantiate()
	auto_free(inst)

	# Act
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D
	assert_object(cam).override_failure_message(
		"Camera3D child not found or wrong type."
	).is_not_null()

	# Assert
	assert_bool(absf(cam.position.y - 1.6) <= _TOLERANCE).override_failure_message(
		"Camera3D.position.y must be 1.6 (got %f)" % cam.position.y
	).is_true()


# ---------------------------------------------------------------------------
# AC-8: Collision layer setup uses PhysicsLayers constants after _ready()
# ---------------------------------------------------------------------------

## After _ready() fires (requires add_child to a tree), the PlayerCharacter body
## must have LAYER_PLAYER set on its layer and LAYER_WORLD + LAYER_AI set on its
## mask. Non-player layer indices must NOT be set on the body's own layer.
func test_player_character_collision_layer_setup_uses_physics_layers() -> void:
	# Arrange — instantiate and add to tree so _ready() fires
	var packed: PackedScene = load(
		"res://src/gameplay/player/PlayerCharacter.tscn"
	) as PackedScene
	var inst: CharacterBody3D = packed.instantiate() as CharacterBody3D
	auto_free(inst)
	add_child(inst)

	# Assert — own layer has LAYER_PLAYER set
	assert_bool(inst.get_collision_layer_value(PhysicsLayers.LAYER_PLAYER)).override_failure_message(
		"PlayerCharacter must have LAYER_PLAYER (%d) set on its collision_layer." % PhysicsLayers.LAYER_PLAYER
	).is_true()

	# Assert — mask has LAYER_WORLD and LAYER_AI set
	assert_bool(inst.get_collision_mask_value(PhysicsLayers.LAYER_WORLD)).override_failure_message(
		"PlayerCharacter must mask LAYER_WORLD (%d)." % PhysicsLayers.LAYER_WORLD
	).is_true()
	assert_bool(inst.get_collision_mask_value(PhysicsLayers.LAYER_AI)).override_failure_message(
		"PlayerCharacter must mask LAYER_AI (%d)." % PhysicsLayers.LAYER_AI
	).is_true()

	# Assert — non-player layers must NOT appear on the body's own layer bit.
	# Sample WORLD, AI, INTERACTABLES as representative non-PLAYER layer indices.
	assert_bool(inst.get_collision_layer_value(PhysicsLayers.LAYER_WORLD)).override_failure_message(
		"LAYER_WORLD must NOT be set on PlayerCharacter's own collision_layer."
	).is_false()
	assert_bool(inst.get_collision_layer_value(PhysicsLayers.LAYER_AI)).override_failure_message(
		"LAYER_AI must NOT be set on PlayerCharacter's own collision_layer."
	).is_false()
	assert_bool(inst.get_collision_layer_value(PhysicsLayers.LAYER_INTERACTABLES)).override_failure_message(
		"LAYER_INTERACTABLES must NOT be set on PlayerCharacter's own collision_layer."
	).is_false()


# ---------------------------------------------------------------------------
# AC-9: No bare integer collision literals in player_character.gd source
# ---------------------------------------------------------------------------

## player_character.gd must contain zero bare integer literals for collision
## layer/mask assignments. ADR-0006 IG 1 forbids patterns such as
## `collision_layer = 1`, `collision_mask = 2`, `set_collision_layer_value(1,`,
## `set_collision_mask_value(2,` etc.
func test_player_character_no_bare_integer_collision_literals_in_source() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(
		"res://src/gameplay/player/player_character.gd"
	)
	assert_bool(source.length() > 0).override_failure_message(
		"player_character.gd could not be read — file missing or empty."
	).is_true()

	# Act + Assert — forbidden direct property assignment patterns (indices 0–8)
	for i: int in range(9):
		var layer_pattern: String = "collision_layer = %d" % i
		var mask_pattern: String = "collision_mask = %d" % i
		assert_bool(source.contains(layer_pattern)).override_failure_message(
			"Forbidden bare integer pattern found: '%s'" % layer_pattern
		).is_false()
		assert_bool(source.contains(mask_pattern)).override_failure_message(
			"Forbidden bare integer pattern found: '%s'" % mask_pattern
		).is_false()

	# Act + Assert — forbidden set_*_value(bare_int, ...) patterns (indices 0–8)
	for i: int in range(9):
		var set_layer_pattern: String = "set_collision_layer_value(%d" % i
		var set_mask_pattern: String = "set_collision_mask_value(%d" % i
		assert_bool(source.contains(set_layer_pattern)).override_failure_message(
			"Forbidden bare integer pattern found: '%s'" % set_layer_pattern
		).is_false()
		assert_bool(source.contains(set_mask_pattern)).override_failure_message(
			"Forbidden bare integer pattern found: '%s'" % set_mask_pattern
		).is_false()


# ---------------------------------------------------------------------------
# AC-10: PlayerCharacter declares required state vars + _physics_process
# ---------------------------------------------------------------------------

## PlayerCharacter must declare current_state (typed, defaulting to IDLE)
## and must have a _physics_process method (stub body acceptable at PC-001
## scope). current_state must be IDLE at construction time.
func test_player_character_declares_required_state_vars() -> void:
	# Arrange
	var packed: PackedScene = load(
		"res://src/gameplay/player/PlayerCharacter.tscn"
	) as PackedScene
	var inst: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(inst)

	# Assert — current_state defaults to IDLE
	assert_int(inst.current_state).is_equal(PlayerEnums.MovementState.IDLE)

	# Assert — _physics_process method is present (lifecycle hook installed)
	assert_bool(inst.has_method(&"_physics_process")).override_failure_message(
		"PlayerCharacter must declare _physics_process (stub body at PC-001 scope)."
	).is_true()
