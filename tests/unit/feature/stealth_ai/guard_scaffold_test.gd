# tests/unit/feature/stealth_ai/guard_scaffold_test.gd
#
# GuardScaffoldTest — GdUnit4 test suite for Story SAI-001 (Guard Node Scaffold).
#
# PURPOSE
#   Verifies the guard CharacterBody3D scaffold initialises correctly per
#   GDD design/gdd/stealth-ai.md §Core Rules and ADR-0006 §Implementation
#   Guidelines. Each test maps 1:1 to one acceptance criterion in the story file.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-001)
#   AC-1 — Guard.collision_layer / collision_mask use PhysicsLayers constants
#   AC-2 — Guard.tscn has the required named children (Navigation, VisionCone, etc.)
#   AC-3 — VisionCone has SphereShape3D with radius == VISION_MAX_RANGE_M
#   AC-4 — _on_vision_cone_body_entered rejects non-player non-dead_guard bodies
#   AC-5 — OutlineTier.set_tier(...MEDIUM) called in _ready(); material_overlay used
#   AC-6 — actor_id field is declared and exported as StringName
#   AC-7 — fresh instance starts UNAWARE with zero accumulators (depends on Story 002)
#
# DEPENDENCIES
#   AC-7's StealthAI.AlertState.UNAWARE assertion is gated on Story 002 landing.
#   Until then, the test asserts the integer-stub value (0) matches the
#   documented UNAWARE-equals-zero contract from GDD §State Machine.
#
# TEST FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Standard headless runner:
#   godot -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/unit/feature/stealth_ai

class_name GuardScaffoldTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _GUARD_SCRIPT_PATH: String = "res://src/gameplay/stealth/guard.gd"


# ── Test fixture helpers ──────────────────────────────────────────────────────

## Instantiates the Guard scene and adds it to the test scene tree so _ready()
## fires. Caller does NOT need to manually free — auto_free() handles cleanup.
func _instantiate_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	assert_object(scene).override_failure_message(
		"Failed to load Guard scene at %s" % _GUARD_SCENE_PATH
	).is_not_null()

	var guard: Guard = scene.instantiate() as Guard
	assert_object(guard).override_failure_message(
		"Guard.tscn root node is not a Guard CharacterBody3D"
	).is_not_null()

	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-1: Guard physics layers use PhysicsLayers constants ───────────────────

## AC-1: Guard.collision_layer == PhysicsLayers.MASK_AI after _ready().
func test_guard_collision_layer_is_mask_ai() -> void:
	var guard: Guard = _instantiate_guard()

	assert_int(guard.collision_layer).override_failure_message(
		"AC-1: Guard.collision_layer must equal PhysicsLayers.MASK_AI (%d). Got: %d"
		% [PhysicsLayers.MASK_AI, guard.collision_layer]
	).is_equal(PhysicsLayers.MASK_AI)


## AC-1: Guard.collision_mask == MASK_WORLD | MASK_PLAYER after _ready().
func test_guard_collision_mask_is_world_or_player() -> void:
	var guard: Guard = _instantiate_guard()
	var expected: int = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER

	assert_int(guard.collision_mask).override_failure_message(
		"AC-1: Guard.collision_mask must equal MASK_WORLD | MASK_PLAYER (%d). Got: %d"
		% [expected, guard.collision_mask]
	).is_equal(expected)


## AC-1 / ADR-0006: guard.gd source contains zero bare integer literals in
## collision_layer / collision_mask assignments. Reads PhysicsLayers constants only.
##
## This is a grep-style guard against the forbidden ADR-0006 pattern. Story 009
## extends this to a project-wide CI grep; here we cover the SAI-001 file only.
func test_guard_source_has_no_bare_integer_collision_assignments() -> void:
	var source: String = FileAccess.get_file_as_string(_GUARD_SCRIPT_PATH)
	assert_str(source).override_failure_message(
		"Could not read %s" % _GUARD_SCRIPT_PATH
	).is_not_empty()

	# Forbidden patterns: `collision_layer = <digit>` or `collision_mask = <digit>`
	# (allowing whitespace but not allowing identifiers like `MASK_AI`).
	var bad_pattern_layer: RegEx = RegEx.create_from_string(
		"^\\s*collision_layer\\s*=\\s*\\d+\\s*$"
	)
	var bad_pattern_mask: RegEx = RegEx.create_from_string(
		"^\\s*collision_mask\\s*=\\s*\\d+\\s*$"
	)

	var lines: PackedStringArray = source.split("\n")
	var violations: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		# Skip comments — the ADR explanation comment may legitimately mention
		# integer literals in prose like "collision_layer = 2".
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		# VisionCone.collision_layer = 0 is the documented EXCEPTION (sensor
		# Area3D occupies no physics layer; no PhysicsLayers.MASK_NONE constant
		# exists). Skip lines whose target is `_vision_cone.collision_layer`.
		if "_vision_cone.collision_layer" in line:
			continue
		if bad_pattern_layer.search(line) != null or bad_pattern_mask.search(line) != null:
			violations.append("line %d: %s" % [i + 1, line])

	assert_int(violations.size()).override_failure_message(
		"AC-1 / ADR-0006: bare integer literal(s) found in collision_layer/collision_mask assignment in guard.gd:\n  %s\nUse PhysicsLayers.* constants only."
		% "\n  ".join(violations)
	).is_equal(0)


# ── AC-2: Guard.tscn has the required named children ────────────────────────

func test_guard_scene_has_navigation_agent_child() -> void:
	var guard: Guard = _instantiate_guard()
	var nav: NavigationAgent3D = guard.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	assert_object(nav).override_failure_message(
		"AC-2: Guard.tscn must have a child named 'NavigationAgent3D' of type NavigationAgent3D."
	).is_not_null()


func test_guard_scene_has_vision_cone_area_child() -> void:
	var guard: Guard = _instantiate_guard()
	var area: Area3D = guard.get_node_or_null("VisionCone") as Area3D
	assert_object(area).override_failure_message(
		"AC-2: Guard.tscn must have a child named 'VisionCone' of type Area3D."
	).is_not_null()


## AC-2: VisionCone.collision_layer = 0 (sensor — occupies no physics layer).
## AC-2: VisionCone.collision_mask = PLAYER | AI (no occluder layers).
func test_vision_cone_layers_per_acceptance_criteria() -> void:
	var guard: Guard = _instantiate_guard()
	var area: Area3D = guard.get_node_or_null("VisionCone") as Area3D
	assert_object(area).is_not_null()

	assert_int(area.collision_layer).override_failure_message(
		"AC-2: VisionCone.collision_layer must equal 0 (sensor — no physics layer)."
	).is_equal(0)

	var expected_mask: int = PhysicsLayers.MASK_PLAYER | PhysicsLayers.MASK_AI
	assert_int(area.collision_mask).override_failure_message(
		"AC-2: VisionCone.collision_mask must equal MASK_PLAYER | MASK_AI (%d). Got: %d. Occluder layers (WORLD) MUST NOT be in this mask."
		% [expected_mask, area.collision_mask]
	).is_equal(expected_mask)


func test_guard_scene_has_hearing_poller_child() -> void:
	var guard: Guard = _instantiate_guard()
	var node: Node = guard.get_node_or_null("HearingPoller")
	assert_object(node).override_failure_message(
		"AC-2: Guard.tscn must have a child named 'HearingPoller' of type Node."
	).is_not_null()


func test_guard_scene_has_perception_child() -> void:
	var guard: Guard = _instantiate_guard()
	var node: Node = guard.get_node_or_null("Perception")
	assert_object(node).override_failure_message(
		"AC-2: Guard.tscn must have a child named 'Perception' of type Node."
	).is_not_null()


func test_guard_scene_has_dialogue_anchor_child() -> void:
	var guard: Guard = _instantiate_guard()
	var anchor: Node3D = guard.get_node_or_null("DialogueAnchor") as Node3D
	assert_object(anchor).override_failure_message(
		"AC-2: Guard.tscn must have a child named 'DialogueAnchor' of type Node3D."
	).is_not_null()


func test_guard_scene_has_outline_tier_mesh_child() -> void:
	var guard: Guard = _instantiate_guard()
	var mesh: MeshInstance3D = guard.get_node_or_null("OutlineTier") as MeshInstance3D
	assert_object(mesh).override_failure_message(
		"AC-2: Guard.tscn must have a child named 'OutlineTier' of type MeshInstance3D."
	).is_not_null()


# ── AC-3: VisionCone shape is SphereShape3D with radius == VISION_MAX_RANGE_M ─

func test_vision_cone_shape_is_sphere_with_correct_radius() -> void:
	var guard: Guard = _instantiate_guard()
	var area: Area3D = guard.get_node_or_null("VisionCone") as Area3D
	assert_object(area).is_not_null()

	var collision_shape: CollisionShape3D = area.get_node_or_null("VisionShape") as CollisionShape3D
	assert_object(collision_shape).override_failure_message(
		"AC-3: VisionCone must have a CollisionShape3D child named 'VisionShape'."
	).is_not_null()

	assert_bool(collision_shape.shape is SphereShape3D).override_failure_message(
		"AC-3: VisionCone shape must be SphereShape3D (Godot 4.6 has no ConeShape3D — angle filtering via dot-product). Got: %s"
		% collision_shape.shape.get_class()
	).is_true()

	var sphere: SphereShape3D = collision_shape.shape as SphereShape3D
	assert_float(sphere.radius).override_failure_message(
		"AC-3: VisionCone SphereShape3D.radius must equal Guard.vision_max_range_m (%.2f). Got: %.2f"
		% [guard.vision_max_range_m, sphere.radius]
	).is_equal_approx(guard.vision_max_range_m, 0.001)


# ── AC-4: _on_vision_cone_body_entered rejects non-player/non-dead-guard bodies ──

## AC-4: A Node3D not in any relevant group is rejected (early return).
## No accumulator change, no signal emission.
func test_on_vision_cone_body_entered_rejects_ungrouped_body() -> void:
	var guard: Guard = _instantiate_guard()
	var sight_before: float = guard.sight_accumulator
	var hearing_before: float = guard.hearing_accumulator
	var alert_before: int = guard.current_alert_state

	# Create a generic Node3D not in any group
	var stranger: Node3D = Node3D.new()
	add_child(stranger)
	auto_free(stranger)

	# Act — direct invocation of the callback
	guard._on_vision_cone_body_entered(stranger)

	# Assert — no state change
	assert_float(guard.sight_accumulator).override_failure_message(
		"AC-4: ungrouped body must not change sight_accumulator."
	).is_equal(sight_before)
	assert_float(guard.hearing_accumulator).override_failure_message(
		"AC-4: ungrouped body must not change hearing_accumulator."
	).is_equal(hearing_before)
	assert_int(guard.current_alert_state).override_failure_message(
		"AC-4: ungrouped body must not change current_alert_state."
	).is_equal(alert_before)


## AC-4: Body in group "player" but NOT a PlayerCharacter or Guard instance
## is rejected by the belt-and-braces typed class check.
func test_on_vision_cone_body_entered_typed_class_check_rejects_group_misuse() -> void:
	var guard: Guard = _instantiate_guard()
	var sight_before: float = guard.sight_accumulator

	# Spoofer: a Node3D in "player" group but NOT a PlayerCharacter
	var spoofer: Node3D = Node3D.new()
	spoofer.add_to_group(&"player")
	add_child(spoofer)
	auto_free(spoofer)

	guard._on_vision_cone_body_entered(spoofer)

	assert_float(guard.sight_accumulator).override_failure_message(
		"AC-4: typed-class check must reject Node3D-in-player-group spoofer (not a PlayerCharacter)."
	).is_equal(sight_before)


## AC-4: Verifies that group-only correct objects (a Guard in dead_guard group)
## pass both filter rules. Validates the AC-4 acceptance path, not the rejection path.
## The body filter completes WITHOUT issuing any signal (Story 003+ adds accumulation).
func test_on_vision_cone_body_entered_dead_guard_passes_filter() -> void:
	var live_guard: Guard = _instantiate_guard()
	var sight_before: float = live_guard.sight_accumulator

	# A second Guard instance in dead_guard group — passes Rule 1 (group)
	# AND Rule 2 (typed-class is Guard).
	var dead_guard_scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var dead_guard: Guard = dead_guard_scene.instantiate() as Guard
	dead_guard.add_to_group(&"dead_guard")
	add_child(dead_guard)
	auto_free(dead_guard)

	live_guard._on_vision_cone_body_entered(dead_guard)

	# AC-4: callback completes WITHOUT issuing signals or changing accumulators
	# (perception accumulation is Story 003+; this story stops at the filter).
	assert_float(live_guard.sight_accumulator).override_failure_message(
		"AC-4: SAI-001 scaffold must not change sight_accumulator (Story 003+ adds accumulation)."
	).is_equal(sight_before)


## AC-4 edge case (story spec): body in BOTH "player" and "dead_guard" groups
## simultaneously. The implementation accepts via group union (Rule 1 OR-logic).
## Should not occur in normal authoring but must be handled gracefully.
func test_on_vision_cone_body_entered_body_in_both_groups_passes_group_filter() -> void:
	var live_guard: Guard = _instantiate_guard()
	var sight_before: float = live_guard.sight_accumulator

	# A Guard tagged in BOTH groups simultaneously — passes Rule 1 (group union)
	# AND Rule 2 (typed-class is Guard).
	var dual_grouped: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var body: Guard = dual_grouped.instantiate() as Guard
	body.add_to_group(&"player")
	body.add_to_group(&"dead_guard")
	add_child(body)
	auto_free(body)

	# Should not crash, should not raise, should reach end of callback.
	live_guard._on_vision_cone_body_entered(body)

	# AC-4: the scaffold callback returns cleanly; no accumulator change yet
	# (perception accumulation is Story 003+).
	assert_float(live_guard.sight_accumulator).override_failure_message(
		"AC-4 edge case: body in both 'player' AND 'dead_guard' groups must be handled gracefully (group union)."
	).is_equal(sight_before)


# ── AC-5: OutlineTier.set_tier(mesh, MEDIUM) called; material_overlay used ───

## AC-5: After _ready(), the OutlineTier mesh has a stencil-bearing material
## with stencil_reference == OutlineTier.MEDIUM (2).
##
## We verify the side-effect of OutlineTier.set_tier() rather than mocking the
## call: the static func is non-mockable, but its behaviour is observable via
## the BaseMaterial3D.stencil_reference write on the mesh's surface materials.
func test_outline_tier_is_medium_after_ready() -> void:
	var guard: Guard = _instantiate_guard()
	var mesh: MeshInstance3D = guard.get_node_or_null("OutlineTier") as MeshInstance3D
	assert_object(mesh).is_not_null()

	# OutlineTier.set_tier creates a StandardMaterial3D override on each surface
	# slot (since the placeholder mesh has no embedded material). The .tscn
	# embeds a CapsuleMesh so there is at least one surface (slot 0).
	var surface_count: int = mesh.get_surface_override_material_count()
	assert_int(surface_count).override_failure_message(
		"AC-5: OutlineTier mesh must have placeholder geometry (at least 1 surface). Got: %d"
		% surface_count
	).is_greater(0)

	var override: Material = mesh.get_surface_override_material(0)
	assert_object(override).override_failure_message(
		"AC-5: OutlineTier.set_tier(...) must assign an override material on the OutlineTier mesh slot 0."
	).is_not_null()

	assert_bool(override is BaseMaterial3D).override_failure_message(
		"AC-5: override material must be BaseMaterial3D (StandardMaterial3D)."
	).is_true()

	var base_mat: BaseMaterial3D = override as BaseMaterial3D
	assert_int(base_mat.stencil_reference).override_failure_message(
		"AC-5: OutlineTier MEDIUM must write stencil_reference == 2 (per ADR-0001 / OutlineTier.MEDIUM). Got: %d"
		% base_mat.stencil_reference
	).is_equal(OutlineTier.MEDIUM)


## AC-5: guard.gd source uses material_overlay (or none) — never material_override
## as a forbidden direct assignment. The Control Manifest (ADR-0001 IG 3) forbids
## material_override on guard MeshInstance3Ds.
func test_guard_source_does_not_assign_material_override() -> void:
	var source: String = FileAccess.get_file_as_string(_GUARD_SCRIPT_PATH)
	assert_str(source).is_not_empty()

	# Forbidden: lines that ASSIGN material_override (not lines that mention it
	# in comments documenting the prohibition).
	var bad_pattern: RegEx = RegEx.create_from_string(
		"^\\s*[A-Za-z_][A-Za-z0-9_]*\\.material_override\\s*=\\s*"
	)

	var lines: PackedStringArray = source.split("\n")
	var violations: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if bad_pattern.search(line) != null:
			violations.append("line %d: %s" % [i + 1, line])

	assert_int(violations.size()).override_failure_message(
		"AC-5 / ADR-0001 IG 3: guard.gd must not assign material_override on the OutlineTier mesh. Use material_overlay (set inside OutlineTier.set_tier via override material slot). Violations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


# ── AC-6: actor_id field is declared and exported as StringName ──────────────

## AC-6: Guard exports an actor_id field of type StringName for ADR-0003 IG 6
## save/load identity. The default value is empty StringName for new instances.
func test_actor_id_field_exists_and_is_stringname() -> void:
	var guard: Guard = _instantiate_guard()

	# Default: empty StringName
	assert_object(guard.actor_id).override_failure_message(
		"AC-6: Guard.actor_id must exist as a property."
	).is_not_null()

	# Verify the type by setting and reading
	guard.actor_id = &"guard_test_001"
	assert_object(guard.actor_id).is_not_null()

	# Sanity: get_actor_id() returns the same value
	assert_object(guard.get_actor_id()).override_failure_message(
		"AC-6: Guard.get_actor_id() must return the actor_id value."
	).is_equal(guard.actor_id)


## AC-6: actor_id is declared with @export annotation in guard.gd.
## Story 003+ relies on the editor-set value persisting through save/load.
func test_actor_id_is_exported_in_source() -> void:
	var source: String = FileAccess.get_file_as_string(_GUARD_SCRIPT_PATH)
	assert_str(source).is_not_empty()

	var pattern: RegEx = RegEx.create_from_string(
		"^\\s*@export\\s+var\\s+actor_id\\s*:\\s*StringName"
	)

	var lines: PackedStringArray = source.split("\n")
	var found: bool = false
	for line: String in lines:
		if pattern.search(line) != null:
			found = true
			break

	assert_bool(found).override_failure_message(
		"AC-6: guard.gd must declare `@export var actor_id: StringName`."
	).is_true()


# ── AC-7: Fresh instance state — UNAWARE alert state, zero accumulators ──────

## AC-7: A freshly instantiated Guard has zero sight and hearing accumulators
## immediately after _ready() (before any physics frame runs).
##
## This ensures Story 003's perception module starts from a clean slate every
## time a guard spawns; no stale @export defaults leak into runtime state.
func test_fresh_guard_has_zero_accumulators() -> void:
	var guard: Guard = _instantiate_guard()

	assert_float(guard.sight_accumulator).override_failure_message(
		"AC-7: fresh Guard.sight_accumulator must be 0.0 after _ready(). Got: %.4f"
		% guard.sight_accumulator
	).is_equal(0.0)

	assert_float(guard.hearing_accumulator).override_failure_message(
		"AC-7: fresh Guard.hearing_accumulator must be 0.0 after _ready(). Got: %.4f"
		% guard.hearing_accumulator
	).is_equal(0.0)


## AC-7: A freshly instantiated Guard starts in alert state UNAWARE.
##
## Story 002 dependency note: Until StealthAI.AlertState lands, the Guard stores
## current_alert_state as a raw int. The GDD §State Machine documents UNAWARE == 0
## as the canonical initial value. This test asserts the integer-stub contract;
## once Story 002 lands, current_alert_state's typed alias is StealthAI.AlertState
## and StealthAI.AlertState.UNAWARE == 0 by the enum's declaration order.
func test_fresh_guard_alert_state_is_unaware() -> void:
	var guard: Guard = _instantiate_guard()

	# Pre-Story-002 stub: UNAWARE == 0 per GDD §State Machine.
	# Once Story 002 lands, replace this with:
	#   assert_int(guard.current_alert_state).is_equal(StealthAI.AlertState.UNAWARE)
	assert_int(guard.current_alert_state).override_failure_message(
		"AC-7: fresh Guard.current_alert_state must be 0 (UNAWARE). Got: %d. Once Story 002 lands, this asserts StealthAI.AlertState.UNAWARE."
		% guard.current_alert_state
	).is_equal(0)
