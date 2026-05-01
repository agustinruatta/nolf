# tests/unit/core/footstep_component/footstep_surface_resolution_test.gd
#
# FootstepSurfaceResolutionTest — GdUnit4 suite for Story FS-003.
# Consolidates AC-1 (marble), AC-2 (default-fallback), AC-3 (boundary crossing),
# AC-4 (all 7 tags), AC-5 (ADR-0006 grep compliance) into one file.
#
# Each test builds a tagged StaticBody3D below the player and calls
# _resolve_surface_tag() directly (bypasses cadence loop for unit isolation).
#
# GATE STATUS
#   Story FS-003 | Logic type → BLOCKING gate. TR-FC-003, TR-FC-004, TR-FC-008.

class_name FootstepSurfaceResolutionTest
extends GdUnitTestSuite

const _PHYSICS_DELTA: float = 1.0 / 60.0
const _SURFACE_TAGS: Array[StringName] = [
	&"marble", &"tile", &"wood_stage", &"carpet",
	&"metal_grate", &"gravel", &"water_puddle"
]
const _SOURCE_PATH: String = "res://src/gameplay/player/footstep_component.gd"

var _player: PlayerCharacter = null
var _floor: StaticBody3D = null
var _fc: FootstepComponent = null
var _bodies: Array[StaticBody3D] = []


func before_test() -> void:
	# Build a floor so PC's _ready works (PC-005 checks needed children).
	_floor = _build_tagged_body(&"floor_default", Vector3(0.0, -0.1, 0.0), null)
	add_child(_floor)

	var packed: PackedScene = load("res://src/gameplay/player/PlayerCharacter.tscn") as PackedScene
	_player = packed.instantiate() as PlayerCharacter
	auto_free(_player)
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.85, 0.0)
	for _i: int in range(3):
		_player._physics_process(_PHYSICS_DELTA)

	_fc = FootstepComponent.new()
	auto_free(_fc)
	_player.add_child(_fc)
	_bodies = []


func after_test() -> void:
	for body: StaticBody3D in _bodies:
		if is_instance_valid(body):
			body.queue_free()
	if is_instance_valid(_floor):
		_floor.queue_free()


## Build a StaticBody3D with optional surface_tag meta and add to scene.
func _build_tagged_body(name: StringName, pos: Vector3, tag: Variant) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = String(name)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 0.1, 2.0)
	col.shape = box
	body.add_child(col)
	body.position = pos
	body.set_collision_layer_value(PhysicsLayers.LAYER_WORLD, true)
	if tag != null:
		body.set_meta("surface_tag", tag)
	return body


## Place a tagged body just below the player (within 2 m raycast depth).
func _spawn_tag_below(tag: Variant) -> StaticBody3D:
	# Player is at y=~0.85; place body at y=0.4 (below player but above floor at y=-0.1).
	var body: StaticBody3D = _build_tagged_body(&"tag_test", Vector3(0.0, 0.4, 0.0), tag)
	add_child(body)
	_bodies.append(body)
	return body


# ── AC-1: Marble surface resolves correctly ──────────────────────────────────

func test_resolve_marble_returns_marble_stringname() -> void:
	_spawn_tag_below(&"marble")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tag: StringName = _fc._resolve_surface_tag()
	assert_str(String(tag)).override_failure_message(
		"Body with surface_tag &'marble' must resolve to &'marble'. Got: %s" % [String(tag)]
	).is_equal("marble")


# ── AC-2: Missing metadata → default + warning once ──────────────────────────

func test_no_body_below_returns_default() -> void:
	# Player above floor only; no extra body close enough. Floor is at y=-0.1
	# (top surface y=-0.05); player at y=0.85. Ray from y=0.80 down 2.0 m
	# reaches y=-1.20 — DOES hit the floor body.
	# Floor body has NO surface_tag meta, so resolver should return &"default".
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tag: StringName = _fc._resolve_surface_tag()
	assert_str(String(tag)).override_failure_message(
		"Body without surface_tag meta must resolve to &'default'. Got: %s" % [String(tag)]
	).is_equal("default")


func test_missing_tag_warns_once_per_body() -> void:
	var body: StaticBody3D = _spawn_tag_below(null)  # no tag meta
	await get_tree().physics_frame
	await get_tree().physics_frame

	# First call — warning fires; tag stored in _warned_bodies.
	_fc._resolve_surface_tag()
	assert_int(_fc._warned_bodies.size()).override_failure_message(
		"After first resolve on untagged body, _warned_bodies must have ≥1 entry."
	).is_greater_equal(1)
	var size_after_first: int = _fc._warned_bodies.size()

	# Second call — same body — must NOT add a new entry (already warned).
	_fc._resolve_surface_tag()
	assert_int(_fc._warned_bodies.size()).override_failure_message(
		"Second resolve on same untagged body must NOT add a new _warned_bodies entry."
	).is_equal(size_after_first)


# ── AC-3: Surface boundary crossing (no caching) ────────────────────────────

func test_surface_crossing_returns_new_tag() -> void:
	# Spawn marble below player; resolve.
	var marble: StaticBody3D = _spawn_tag_below(&"marble")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tag1: StringName = _fc._resolve_surface_tag()
	assert_str(String(tag1)).is_equal("marble")

	# Move marble out of the way; spawn carpet.
	marble.queue_free()
	await get_tree().process_frame
	_spawn_tag_below(&"carpet")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tag2: StringName = _fc._resolve_surface_tag()
	assert_str(String(tag2)).override_failure_message(
		"After crossing from marble to carpet, resolver must return &'carpet' (no caching). Got: %s" % [String(tag2)]
	).is_equal("carpet")


# ── AC-4: All 7 surface tags + default ───────────────────────────────────────

func test_all_seven_surface_tags_resolve_correctly() -> void:
	for expected_tag: StringName in _SURFACE_TAGS:
		# Clean any previous bodies.
		for b: StaticBody3D in _bodies:
			if is_instance_valid(b):
				b.queue_free()
		_bodies = []
		await get_tree().process_frame

		_spawn_tag_below(expected_tag)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var resolved: StringName = _fc._resolve_surface_tag()
		assert_str(String(resolved)).override_failure_message(
			"Tag '%s' must resolve to itself. Got: '%s'" % [String(expected_tag), String(resolved)]
		).is_equal(String(expected_tag))


# ── AC-5: ADR-0006 compliance — collision_mask is a constant, not a literal ──

## Static-source grep guard: no `collision_mask = <integer>` in the file.
func test_collision_mask_uses_physics_layers_constant_not_literal() -> void:
	var f: FileAccess = FileAccess.open(_SOURCE_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	# Match `collision_mask` followed by `=` followed by a digit (any integer
	# literal). Allowed assignments are `= PhysicsLayers.MASK_*`.
	var re: RegEx = RegEx.new()
	re.compile("collision_mask\\s*=\\s*[0-9]")
	var match: RegExMatch = re.search(content)
	assert_object(match).override_failure_message(
		"footstep_component.gd must NOT assign collision_mask to an integer literal. Use PhysicsLayers.MASK_*."
	).is_null()
	# Positive control: must contain the constant reference.
	assert_str(content).override_failure_message(
		"footstep_component.gd must reference PhysicsLayers.MASK_FOOTSTEP_SURFACE."
	).contains("PhysicsLayers.MASK_FOOTSTEP_SURFACE")
