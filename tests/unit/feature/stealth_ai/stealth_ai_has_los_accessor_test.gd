# tests/unit/feature/stealth_ai/stealth_ai_has_los_accessor_test.gd
#
# StealthAIHasLosAccessorTest — GdUnit4 test suite for Story SAI-003 ACs 2–6.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-003)
#   AC-2 — PerceptionCache default field values
#   AC-3 — Perception.init() stores the provided raycast provider
#   AC-4 — has_los_to_player() returns false on cold-start (no crash, no raycast)
#   AC-5 — has_los_to_player() reads from cache (no new raycast on cache-hit)
#   AC-6 — Stale-by-1-frame: accessor returns stale cached value, no new raycast
#
# DEPENDENCIES
#   Story SAI-002 must be DONE (needs StealthAI.AlertCause for PerceptionCache default)
#
# TEST FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe (no scene tree for
#   PerceptionCache tests; Perception is a Node but instantiated without tree
#   for accessor tests — no _ready() dependencies in this class).

class_name StealthAIHasLosAccessorTest
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh Perception node with a CountingRaycastProvider injected.
## Registers with auto_free() for cleanup. Returns [perception, counter] as
## an untyped Array because GDScript does not yet support tuple/struct returns;
## callers cast the elements at the call site.
func _make_perception_with_counter() -> Array[Object]:
	var perception: Perception = Perception.new()
	add_child(perception)
	auto_free(perception)
	var counter: CountingRaycastProvider = CountingRaycastProvider.new()
	perception.init(counter)
	return [perception, counter]


# ── AC-2: PerceptionCache default field values ────────────────────────────────

## AC-2: All PerceptionCache fields have the correct default values on construction.
func test_perception_cache_default_field_values() -> void:
	# Arrange + Act
	var cache: PerceptionCache = PerceptionCache.new()

	# Assert — each field individually for clear failure messages
	assert_bool(cache.initialized).override_failure_message(
			"AC-2: PerceptionCache.initialized must default to false."
	).is_false()

	assert_int(cache.frame_stamp).override_failure_message(
			"AC-2: PerceptionCache.frame_stamp must default to 0."
	).is_equal(0)

	assert_bool(cache.los_to_player).override_failure_message(
			"AC-2: PerceptionCache.los_to_player must default to false."
	).is_false()

	assert_bool(cache.los_to_player_position == Vector3.ZERO).override_failure_message(
			"AC-2: PerceptionCache.los_to_player_position must default to Vector3.ZERO."
	).is_true()

	assert_bool(cache.los_to_dead_bodies.is_empty()).override_failure_message(
			"AC-2: PerceptionCache.los_to_dead_bodies must default to empty dict."
	).is_true()

	assert_int(cache.last_sight_stimulus_cause).override_failure_message(
			"AC-2: PerceptionCache.last_sight_stimulus_cause must default to StealthAI.AlertCause.SAW_PLAYER."
	).is_equal(StealthAI.AlertCause.SAW_PLAYER)

	assert_bool(cache.last_sight_position == Vector3.ZERO).override_failure_message(
			"AC-2: PerceptionCache.last_sight_position must default to Vector3.ZERO."
	).is_true()


# ── AC-3: Perception.init() stores the provided raycast provider ──────────────

## AC-3: After init(provider), Perception holds the reference — verified via
## the internal _raycast_provider field.
func test_perception_init_stores_provided_raycast_provider() -> void:
	# Arrange
	var perception: Perception = Perception.new()
	add_child(perception)
	auto_free(perception)
	var counter: CountingRaycastProvider = CountingRaycastProvider.new()

	# Act
	perception.init(counter)

	# Assert — provider is stored
	assert_object(perception._raycast_provider).override_failure_message(
			"AC-3: After init(provider), Perception._raycast_provider must be non-null."
	).is_not_null()

	assert_bool(perception._raycast_provider == counter).override_failure_message(
			"AC-3: Perception._raycast_provider must be the exact provider passed to init()."
	).is_true()


# ── AC-4: Cold-start safe-false ───────────────────────────────────────────────

## AC-4: has_los_to_player() returns false when no init() called and cache
## is at default (initialized == false). No crash.
func test_has_los_to_player_returns_false_on_cold_start() -> void:
	# Arrange — Perception with NO init() call
	var perception: Perception = Perception.new()
	add_child(perception)
	auto_free(perception)

	# Act + Assert
	assert_bool(perception.has_los_to_player()).override_failure_message(
			"AC-4: has_los_to_player() must return false on cold-start (no init, no F.1 tick)."
	).is_false()


## AC-4: has_los_to_player() does not issue a raycast on cold-start.
## CountingRaycastProvider.call_count must remain 0 after accessor calls.
func test_has_los_to_player_does_not_issue_raycast_on_cold_start() -> void:
	# Arrange
	var result: Array[Object] = _make_perception_with_counter()
	var perception: Perception = result[0]
	var counter: CountingRaycastProvider = result[1]
	# Cold-start: perception_cache.initialized is still false
	# (init() was called with the counter but F.1 has never ticked)

	# Act
	var _ignored: bool = perception.has_los_to_player()
	var _ignored2: bool = perception.has_los_to_player()

	# Assert
	assert_int(counter.call_count).override_failure_message(
			"AC-4: has_los_to_player() must not issue any raycast on cold-start. " +
			"CountingRaycastProvider.call_count must remain 0."
	).is_equal(0)


# ── AC-5: Cache-hit path (no raycast issued) ──────────────────────────────────

## AC-5: GIVEN initialized=true, los_to_player=true → returns true, no new raycast.
func test_has_los_to_player_returns_cached_true_when_initialized() -> void:
	# Arrange
	var result: Array[Object] = _make_perception_with_counter()
	var perception: Perception = result[0]
	var counter: CountingRaycastProvider = result[1]
	perception._perception_cache.initialized = true
	perception._perception_cache.los_to_player = true

	# Act
	var los_result: bool = perception.has_los_to_player()

	# Assert
	assert_bool(los_result).override_failure_message(
			"AC-5: has_los_to_player() must return true when cache shows los_to_player=true."
	).is_true()
	assert_int(counter.call_count).override_failure_message(
			"AC-5: has_los_to_player() must not issue a raycast on cache-hit (call_count must be 0)."
	).is_equal(0)


## AC-5: GIVEN initialized=true, los_to_player=false → returns false, no new raycast.
func test_has_los_to_player_returns_cached_false_when_not_in_los() -> void:
	# Arrange
	var result: Array[Object] = _make_perception_with_counter()
	var perception: Perception = result[0]
	var counter: CountingRaycastProvider = result[1]
	perception._perception_cache.initialized = true
	perception._perception_cache.los_to_player = false

	# Act
	var los_result: bool = perception.has_los_to_player()

	# Assert
	assert_bool(los_result).override_failure_message(
			"AC-5: has_los_to_player() must return false when cache shows los_to_player=false."
	).is_false()
	assert_int(counter.call_count).override_failure_message(
			"AC-5: has_los_to_player() must not issue a raycast on cache-hit (call_count must be 0)."
	).is_equal(0)


## AC-5: Calling has_los_to_player() 3 times on a warm cache issues 0 raycasts.
func test_has_los_to_player_does_not_issue_raycast_on_cache_hit() -> void:
	# Arrange
	var result: Array[Object] = _make_perception_with_counter()
	var perception: Perception = result[0]
	var counter: CountingRaycastProvider = result[1]
	perception._perception_cache.initialized = true
	perception._perception_cache.los_to_player = true

	# Act
	var _r1: bool = perception.has_los_to_player()
	var _r2: bool = perception.has_los_to_player()
	var _r3: bool = perception.has_los_to_player()

	# Assert
	assert_int(counter.call_count).override_failure_message(
			"AC-5: 3 accessor calls on a warm cache must issue 0 raycasts (call_count must be 0)."
	).is_equal(0)


# ── AC-6: Stale-by-1-frame ────────────────────────────────────────────────────

## AC-6: Write cache at frame N, advance simulated frame counter by 1, call
## accessor — gets stale cached value without issuing a new raycast.
## (frame_stamp is informational in the cache; the accessor reads the raw bool.)
func test_perception_cache_returns_stale_value_when_no_new_frame_tick() -> void:
	# Arrange
	var result: Array[Object] = _make_perception_with_counter()
	var perception: Perception = result[0]
	var counter: CountingRaycastProvider = result[1]

	# Simulate F.1 writing the cache at a known frame
	var simulated_frame: int = 42
	perception._perception_cache.initialized = true
	perception._perception_cache.frame_stamp = simulated_frame
	perception._perception_cache.los_to_player = true

	# Act — "advance" to frame N+1 (we can't advance Engine.get_physics_frames()
	# headlessly, but we can verify the accessor reads stale without raycast).
	# The stale-by-1-frame contract is: accessor returns whatever is in the cache,
	# no new raycast issued regardless of how many frames have elapsed since the write.
	var los_result: bool = perception.has_los_to_player()

	# Assert — stale true value returned, zero raycasts
	assert_bool(los_result).override_failure_message(
			"AC-6: has_los_to_player() must return the stale cached value (true) " +
			"when no new F.1 tick has occurred."
	).is_true()
	assert_int(counter.call_count).override_failure_message(
			"AC-6: Accessor must not issue a new raycast when reading a stale cache value."
	).is_equal(0)
