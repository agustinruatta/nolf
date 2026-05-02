# tests/unit/feature/stealth_ai/stealth_ai_takedown_prompt_active_test.gd
#
# StealthAITakedownPromptActiveTest — Story SAI-006 AC-6 / AC-SAI-3.10.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-006)
#   AC-6: takedown_prompt_active(attacker) returns true iff ALL of:
#     1. current_alert_state in {UNAWARE, SUSPICIOUS}
#     2. attacker within rear half-cone (forward.dot(dir) <= 0)
#     3. XZ-plane distance <= takedown_range_m (1.5m default)
#     4. _perception_cache.los_to_player == false
#     5. is_instance_valid(attacker) == true
#   Edge: zero-distance → returns false (no normalized() call)
#   Edge: attacker exactly at 90° (dot == 0) → returns true (inclusive boundary)
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAITakedownPromptActiveTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


## Creates a Node3D attacker stub at the given world-space position.
func _make_attacker(pos: Vector3) -> Node3D:
	var attacker: Node3D = Node3D.new()
	add_child(attacker)
	auto_free(attacker)
	attacker.global_position = pos
	return attacker


# ── Dim 1: state check ────────────────────────────────────────────────────────

## AC-6 dim-1: UNAWARE state allows takedown when other dimensions pass.
func test_takedown_returns_true_when_state_is_unaware_and_all_dims_pass() -> void:
	var guard: Guard = _make_guard()
	# Place attacker BEHIND guard (forward is -Z, so behind is +Z)
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 1.0))

	# Guard already in UNAWARE on spawn; los_to_player default false (cache uninitialized)
	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-1: UNAWARE state with attacker at (0,0,1) (behind, 1m) and no LOS must allow takedown."
	).is_true()


## AC-6 dim-1: SUSPICIOUS state ALSO allows takedown (per AC-6 spec).
func test_takedown_returns_true_when_state_is_suspicious() -> void:
	var guard: Guard = _make_guard()
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 1.0))

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-1: SUSPICIOUS state must allow takedown (per AC-6 state list)."
	).is_true()


## AC-6 dim-1: SEARCHING state REJECTS takedown.
func test_takedown_returns_false_when_state_is_searching() -> void:
	var guard: Guard = _make_guard()
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 1.0))

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-1: SEARCHING state must reject takedown (only UNAWARE/SUSPICIOUS allowed)."
	).is_false()


## AC-6 dim-1: COMBAT state REJECTS takedown.
func test_takedown_returns_false_when_state_is_combat() -> void:
	var guard: Guard = _make_guard()
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER)
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 1.0))

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-1: COMBAT state must reject takedown."
	).is_false()


# ── Dim 2: rear-arc dot product ───────────────────────────────────────────────

## AC-6 dim-2: attacker in front of guard (dot > 0) rejects.
## Guard's forward is -Z; attacker at (0,0,-1) is IN FRONT.
func test_takedown_returns_false_when_attacker_is_in_front() -> void:
	var guard: Guard = _make_guard()
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, -1.0))  # in front (-Z)

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-2: attacker in front (dot > 0) must reject takedown."
	).is_false()


## AC-6 dim-2 boundary: attacker at exactly 90° (dot == 0, perpendicular) ALLOWS takedown.
## Guard's forward is -Z; attacker at (1,0,0) is to the RIGHT (perpendicular).
func test_takedown_returns_true_at_exactly_90_degrees_boundary() -> void:
	var guard: Guard = _make_guard()
	var attacker: Node3D = _make_attacker(Vector3(1.0, 0.0, 0.0))  # exactly perpendicular

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-2 boundary: attacker at exactly 90° (dot == 0) must allow takedown (inclusive)."
	).is_true()


# ── Dim 3: distance ───────────────────────────────────────────────────────────

## AC-6 dim-3: attacker beyond takedown_range_m (1.5m default) rejects.
func test_takedown_returns_false_when_attacker_beyond_range() -> void:
	var guard: Guard = _make_guard()
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 2.0))  # 2m behind, > 1.5m range

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-3: attacker at 2m (> takedown_range_m=1.5m) must reject."
	).is_false()


## AC-6 dim-3: XZ-plane distance ignores Y component (height differences don't matter).
## Attacker 1m behind on Z, but 5m above on Y → still in range (XZ distance = 1m).
func test_takedown_distance_uses_xz_plane_only_ignores_y() -> void:
	var guard: Guard = _make_guard()
	var attacker: Node3D = _make_attacker(Vector3(0.0, 5.0, 1.0))  # high above, 1m behind XZ

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-3: XZ-plane distance must ignore Y; attacker at Y=5 with XZ-distance=1m must allow."
	).is_true()


# ── Dim 4: LOS to attacker ────────────────────────────────────────────────────

## AC-6 dim-4: if perception cache says guard sees attacker, REJECT.
func test_takedown_returns_false_when_los_to_player_is_true() -> void:
	var guard: Guard = _make_guard()
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = true
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 1.0))

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-4: los_to_player=true means guard sees attacker; takedown must reject."
	).is_false()


## AC-6 dim-4: cold-start cache (initialized=false) is treated as no-LOS — allows takedown.
func test_takedown_returns_true_when_perception_cache_uninitialized() -> void:
	var guard: Guard = _make_guard()
	# Cache initialized=false on cold start; treat as no LOS, takedown allowed.
	var attacker: Node3D = _make_attacker(Vector3(0.0, 0.0, 1.0))

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 dim-4: cold-start cache (initialized=false) must allow takedown (treated as no-LOS)."
	).is_true()


# ── Dim 5: validity guard ─────────────────────────────────────────────────────

## AC-6 dim-5: null attacker rejects.
func test_takedown_returns_false_when_attacker_is_null() -> void:
	var guard: Guard = _make_guard()
	assert_bool(guard.takedown_prompt_active(null)).override_failure_message(
		"AC-6 dim-5: null attacker must reject (is_instance_valid guard)."
	).is_false()


## AC-6 dim-5: freed-attacker test is intentionally NOT included.
## Godot 4.6 validates typed function arguments BEFORE the function body runs;
## passing a freed Node to `takedown_prompt_active(attacker: Node)` triggers a
## runtime type-check error before `is_instance_valid()` can guard. The null
## attacker test above covers dim-5; freed-attacker safety is a runtime
## guarantee at the language level rather than something to assert here.


# ── Edge: zero-distance ──────────────────────────────────────────────────────

## AC-6 edge: attacker overlapping guard (zero XZ distance) returns FALSE.
## No normalized() call on near-zero vector (length_squared < 1e-4 short-circuit).
func test_takedown_returns_false_when_attacker_at_zero_distance() -> void:
	var guard: Guard = _make_guard()
	var attacker: Node3D = _make_attacker(Vector3.ZERO)  # exactly overlapping

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 edge zero-distance: overlapping attacker must reject (avoid normalized() on zero vector)."
	).is_false()


## AC-6 edge: attacker at very-near-zero XZ distance (< 1e-4 squared) also returns false.
func test_takedown_returns_false_when_attacker_at_near_zero_distance() -> void:
	var guard: Guard = _make_guard()
	# 0.005m offset → length_squared ≈ 2.5e-5 < 1e-4
	var attacker: Node3D = _make_attacker(Vector3(0.005, 0.0, 0.0))

	assert_bool(guard.takedown_prompt_active(attacker)).override_failure_message(
		"AC-6 edge near-zero: attacker at 0.005m (length_squared < 1e-4) must reject."
	).is_false()
