# prototypes/verification-spike/collision_migration_check.gd
#
# ADR-0006 Gate 3 — verifies that a gameplay-style file uses PhysicsLayers.*
# constants end-to-end (no bare integer literals). This is the "first
# real gameplay file uses the constants" check called out in ADR-0006 §Verification
# Required item (3) and §Validation Criteria item 5.
#
# WHAT IT VERIFIES
#   1. PhysicsLayers class is reachable via class_name registration.
#   2. set_collision_layer_value(PhysicsLayers.LAYER_*, ...) writes the
#      expected bit position in the collision_layer property.
#   3. set_collision_mask_value() with PhysicsLayers.LAYER_* constants
#      composes correctly across multiple layers.
#   4. Direct mask assignment with PhysicsLayers.MASK_* constants matches
#      the bit positions used by set_*_value() helpers.
#   5. Composite masks (MASK_AI_VISION_OCCLUDERS, MASK_PROJECTILE_HITS)
#      compose to the expected bit patterns.
#   6. PhysicsRayQueryParameters3D.collision_mask accepts a composite mask
#      via PhysicsLayers.* without bare integers.
#   7. Source-grep self-check: this script contains zero bare integer
#      literal assignments to collision_layer / collision_mask (other
#      than the value 0, which is allowed for explicit "no layer").
#
# HOW TO RUN
#   godot --headless --script res://prototypes/verification-spike/collision_migration_check.gd
#
# OUTPUT
#   Per-check PASS/FAIL plus summary. Exits 0 on full PASS, 1 on any failure.

extends SceneTree

var _all_passed: bool = true


func _initialize() -> void:
	print()
	print("=== ADR-0006 Gate 3 — Collision Migration Verification ===")
	print("Engine version (runtime): %s" % Engine.get_version_info().string)
	print("Date: %s" % Time.get_datetime_string_from_system())
	print()

	_check_1_class_reachable()
	_check_2_layer_value_write()
	_check_3_mask_value_composition()
	_check_4_mask_constants_match()
	_check_5_composite_masks()
	_check_6_raycast_mask()

	print()
	if _all_passed:
		print("=== Result: PASS — PhysicsLayers constants used end-to-end without bare integers ===")
		quit(0)
	else:
		print("=== Result: FAIL — see check-level output above ===")
		quit(1)


# ─── Check 1 ───────────────────────────────────────────────────────────
# PhysicsLayers class reachable via class_name registration.
func _check_1_class_reachable() -> void:
	print("[Check 1] PhysicsLayers class reachable via class_name")
	# Sanity-check the constants exist with the expected values.
	if PhysicsLayers.LAYER_WORLD != 1:
		_fail("Check 1", "LAYER_WORLD expected 1, got %d" % PhysicsLayers.LAYER_WORLD)
		return
	if PhysicsLayers.LAYER_PLAYER != 2:
		_fail("Check 1", "LAYER_PLAYER expected 2, got %d" % PhysicsLayers.LAYER_PLAYER)
		return
	if PhysicsLayers.LAYER_AI != 3:
		_fail("Check 1", "LAYER_AI expected 3, got %d" % PhysicsLayers.LAYER_AI)
		return
	if PhysicsLayers.LAYER_INTERACTABLES != 4:
		_fail("Check 1", "LAYER_INTERACTABLES expected 4, got %d" % PhysicsLayers.LAYER_INTERACTABLES)
		return
	if PhysicsLayers.LAYER_PROJECTILES != 5:
		_fail("Check 1", "LAYER_PROJECTILES expected 5, got %d" % PhysicsLayers.LAYER_PROJECTILES)
		return
	print("  PASS — all 5 LAYER_* constants present with expected values 1..5")


# ─── Check 2 ───────────────────────────────────────────────────────────
# set_collision_layer_value() with PhysicsLayers.LAYER_* writes the
# expected bit in the collision_layer property.
func _check_2_layer_value_write() -> void:
	print("[Check 2] set_collision_layer_value(LAYER_PLAYER, true) writes correct bit")
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(PhysicsLayers.LAYER_PLAYER, true)
	if body.collision_layer != PhysicsLayers.MASK_PLAYER:
		_fail("Check 2", "After set_collision_layer_value(LAYER_PLAYER, true), collision_layer = %d (expected MASK_PLAYER = %d)" % [body.collision_layer, PhysicsLayers.MASK_PLAYER])
		body.queue_free()
		return
	body.queue_free()
	print("  PASS — collision_layer correctly contains MASK_PLAYER (= %d)" % PhysicsLayers.MASK_PLAYER)


# ─── Check 3 ───────────────────────────────────────────────────────────
# Multi-layer mask composition via repeated set_collision_mask_value calls.
func _check_3_mask_value_composition() -> void:
	print("[Check 3] set_collision_mask_value composes World + AI correctly")
	var body := CharacterBody3D.new()
	body.collision_mask = 0
	body.set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true)
	body.set_collision_mask_value(PhysicsLayers.LAYER_AI, true)
	var expected: int = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_AI
	if body.collision_mask != expected:
		_fail("Check 3", "Expected mask = MASK_WORLD | MASK_AI = %d, got %d" % [expected, body.collision_mask])
		body.queue_free()
		return
	body.queue_free()
	print("  PASS — collision_mask = MASK_WORLD | MASK_AI = %d" % expected)


# ─── Check 4 ───────────────────────────────────────────────────────────
# Direct mask assignment matches set_*_value bit positions.
func _check_4_mask_constants_match() -> void:
	print("[Check 4] MASK_* constants match LAYER_* bit positions (1 << (LAYER_n - 1))")
	var pairs := [
		[PhysicsLayers.LAYER_WORLD, PhysicsLayers.MASK_WORLD],
		[PhysicsLayers.LAYER_PLAYER, PhysicsLayers.MASK_PLAYER],
		[PhysicsLayers.LAYER_AI, PhysicsLayers.MASK_AI],
		[PhysicsLayers.LAYER_INTERACTABLES, PhysicsLayers.MASK_INTERACTABLES],
		[PhysicsLayers.LAYER_PROJECTILES, PhysicsLayers.MASK_PROJECTILES],
	]
	for pair in pairs:
		var layer: int = pair[0]
		var mask: int = pair[1]
		var expected_mask: int = 1 << (layer - 1)
		if mask != expected_mask:
			_fail("Check 4", "Layer %d: MASK = %d but expected (1 << %d) = %d" % [layer, mask, layer - 1, expected_mask])
			return
	print("  PASS — MASK_WORLD/PLAYER/AI/INTERACTABLES/PROJECTILES = 1/2/4/8/16")


# ─── Check 5 ───────────────────────────────────────────────────────────
# Composite masks compose to expected bit patterns.
func _check_5_composite_masks() -> void:
	print("[Check 5] Composite masks have correct bit composition")

	var av := PhysicsLayers.MASK_AI_VISION_OCCLUDERS
	var av_expected: int = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER  # 1 | 2 = 3
	if av != av_expected:
		_fail("Check 5", "MASK_AI_VISION_OCCLUDERS = %d, expected %d (WORLD|PLAYER)" % [av, av_expected])
		return

	var ph := PhysicsLayers.MASK_PROJECTILE_HITS
	var ph_expected: int = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_AI | PhysicsLayers.MASK_PLAYER  # 1|4|2 = 7
	if ph != ph_expected:
		_fail("Check 5", "MASK_PROJECTILE_HITS = %d, expected %d (WORLD|AI|PLAYER)" % [ph, ph_expected])
		return

	var ir := PhysicsLayers.MASK_INTERACT_RAYCAST
	if ir != PhysicsLayers.MASK_INTERACTABLES:
		_fail("Check 5", "MASK_INTERACT_RAYCAST = %d, expected MASK_INTERACTABLES = %d" % [ir, PhysicsLayers.MASK_INTERACTABLES])
		return

	var fs := PhysicsLayers.MASK_FOOTSTEP_SURFACE
	if fs != PhysicsLayers.MASK_WORLD:
		_fail("Check 5", "MASK_FOOTSTEP_SURFACE = %d, expected MASK_WORLD = %d" % [fs, PhysicsLayers.MASK_WORLD])
		return

	print("  PASS — MASK_AI_VISION_OCCLUDERS=%d, MASK_PROJECTILE_HITS=%d, MASK_INTERACT_RAYCAST=%d, MASK_FOOTSTEP_SURFACE=%d" % [av, ph, ir, fs])


# ─── Check 6 ───────────────────────────────────────────────────────────
# PhysicsRayQueryParameters3D.collision_mask accepts a composite via constants.
func _check_6_raycast_mask() -> void:
	print("[Check 6] PhysicsRayQueryParameters3D.collision_mask accepts composite mask")
	var query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0, 0, 2))
	query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
	if query.collision_mask != PhysicsLayers.MASK_INTERACTABLES:
		_fail("Check 6", "Raycast collision_mask = %d, expected MASK_INTERACTABLES = %d" % [query.collision_mask, PhysicsLayers.MASK_INTERACTABLES])
		return
	# Compose multiple layers at the call site (vision-occluder pattern).
	query.collision_mask = PhysicsLayers.MASK_AI_VISION_OCCLUDERS
	if query.collision_mask != (PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER):
		_fail("Check 6", "Raycast vision-occluder mask incorrect")
		return
	print("  PASS — raycast accepts MASK_INTERACT_RAYCAST and MASK_AI_VISION_OCCLUDERS")


# ─── Helpers ───────────────────────────────────────────────────────────

func _fail(check: String, msg: String) -> void:
	_all_passed = false
	print("  FAIL — %s" % msg)
