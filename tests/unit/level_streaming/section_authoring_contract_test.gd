# tests/unit/level_streaming/section_authoring_contract_test.gd
#
# SectionAuthoringContractTest — GdUnit4 unit suite for Story LS-008.
#
# Covers:
#   AC-1  plaza.tscn structure (Node3D root, section_root group, exports,
#         distinct EntryPoint+RespawnPoint, SectionBoundsHint, Floor with surface_tag)
#   AC-2  stub_b.tscn matching structure
#   AC-6  Smoke check 5 invariants per scene
#   AC-7  section_bounds AABB computation
#   AC-8  Floor surface_tag meta == &"default"
#   AC-9  SectionRoot script attached to both scenes
#
# AC-3/4/5 covered by section_environment_assignment_test.gd (integration tier).
#
# GATE STATUS
#   Story LS-008 | Config/Data → ADVISORY gate (smoke check evidence).
#   TR-LS-008.

class_name SectionAuthoringContractTest
extends GdUnitTestSuite


const PLAZA_PATH: String = "res://scenes/sections/plaza.tscn"
const STUB_B_PATH: String = "res://scenes/sections/stub_b.tscn"


# ── AC-1, AC-9: plaza.tscn structure ─────────────────────────────────────────

func test_plaza_scene_root_is_section_root_node3d_in_section_root_group() -> void:
	var scene: PackedScene = load(PLAZA_PATH) as PackedScene
	assert_object(scene).override_failure_message(
		"AC-1: plaza.tscn must load as a PackedScene at %s." % PLAZA_PATH
	).is_not_null()

	var inst: Node = scene.instantiate()
	add_child(inst)  # add to tree so _ready() fires
	await get_tree().process_frame

	assert_bool(inst is Node3D).override_failure_message(
		"AC-1: plaza root must be Node3D-or-subclass. Got: %s" % inst.get_class()
	).is_true()

	# AC-9: SectionRoot script attached (duck-typed via signature: has_method
	# get_section_bounds + script path matches src/gameplay/sections/section_root.gd).
	assert_bool(inst.has_method("get_section_bounds")).override_failure_message(
		"AC-9: plaza root must have SectionRoot.get_section_bounds() method."
	).is_true()
	var script: Script = inst.get_script() as Script
	assert_object(script).override_failure_message(
		"AC-9: plaza root must have a script attached."
	).is_not_null()
	assert_str(script.resource_path).override_failure_message(
		"AC-9: plaza root script must be SectionRoot at expected path."
	).is_equal("res://src/gameplay/sections/section_root.gd")

	# AC-1: section_root group
	assert_bool(inst.is_in_group("section_root")).override_failure_message(
		"AC-1: plaza root must be in 'section_root' group (added by SectionRoot._ready())."
	).is_true()

	# AC-1: section_id
	var sid: StringName = inst.get(&"section_id")
	assert_str(String(sid)).override_failure_message(
		"AC-1: plaza section_id must be 'plaza'. Got: '%s'" % sid
	).is_equal("plaza")

	inst.queue_free()
	await get_tree().process_frame


func test_plaza_entry_and_respawn_points_resolve_to_distinct_marker3d_nodes() -> void:
	var scene: PackedScene = load(PLAZA_PATH) as PackedScene
	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var entry_path: NodePath = inst.get(&"player_entry_point")
	var respawn_path: NodePath = inst.get(&"player_respawn_point")
	var entry: Node = inst.get_node_or_null(entry_path)
	var respawn: Node = inst.get_node_or_null(respawn_path)

	assert_object(entry).override_failure_message(
		"AC-1: plaza player_entry_point must resolve. Path: '%s'" % entry_path
	).is_not_null()
	assert_object(respawn).override_failure_message(
		"AC-1: plaza player_respawn_point must resolve. Path: '%s'" % respawn_path
	).is_not_null()
	assert_bool(entry is Marker3D).override_failure_message(
		"AC-1: plaza EntryPoint must be Marker3D."
	).is_true()
	assert_bool(respawn is Marker3D).override_failure_message(
		"AC-1: plaza RespawnPoint must be Marker3D."
	).is_true()
	assert_bool(entry == respawn).override_failure_message(
		"AC-1: plaza EntryPoint and RespawnPoint must be DISTINCT node instances (CR-9)."
	).is_false()

	inst.queue_free()
	await get_tree().process_frame


# ── AC-2, AC-9: stub_b.tscn structure ────────────────────────────────────────

func test_stub_b_scene_root_satisfies_cr9_contract() -> void:
	var scene: PackedScene = load(STUB_B_PATH) as PackedScene
	assert_object(scene).override_failure_message(
		"AC-2: stub_b.tscn must load at %s." % STUB_B_PATH
	).is_not_null()

	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	# AC-2+AC-9: SectionRoot script attached (duck-typed)
	assert_bool(inst.has_method("get_section_bounds")).override_failure_message(
		"AC-2+AC-9: stub_b root must have SectionRoot.get_section_bounds() method."
	).is_true()
	var script: Script = inst.get_script() as Script
	assert_object(script).is_not_null()
	assert_str(script.resource_path).override_failure_message(
		"AC-9: stub_b root script must be SectionRoot at expected path."
	).is_equal("res://src/gameplay/sections/section_root.gd")
	assert_bool(inst.is_in_group("section_root")).override_failure_message(
		"AC-2: stub_b root must be in 'section_root' group."
	).is_true()
	var sid: StringName = inst.get(&"section_id")
	assert_str(String(sid)).override_failure_message(
		"AC-2: stub_b section_id must be 'stub_b'. Got: '%s'" % sid
	).is_equal("stub_b")

	inst.queue_free()
	await get_tree().process_frame


# ── AC-6: 5-invariant smoke check parameterized over both scenes ─────────────

func test_smoke_check_invariants_pass_for_plaza_and_stub_b() -> void:
	var scenes: Array = [
		{"path": PLAZA_PATH, "id": &"plaza"},
		{"path": STUB_B_PATH, "id": &"stub_b"},
	]

	for entry: Dictionary in scenes:
		var scene: PackedScene = load(entry["path"]) as PackedScene
		assert_object(scene).override_failure_message(
			"AC-6 smoke: scene must load: %s" % entry["path"]
		).is_not_null()

		var inst: Node = scene.instantiate()
		add_child(inst)
		await get_tree().process_frame

		# (a) Node3D root
		assert_bool(inst is Node3D).override_failure_message(
			"AC-6 smoke (a): %s root must be Node3D." % entry["path"]
		).is_true()
		# (b) section_root group
		assert_bool(inst.is_in_group("section_root")).override_failure_message(
			"AC-6 smoke (b): %s root must be in 'section_root' group." % entry["path"]
		).is_true()
		# (c) section_id matches registry key
		assert_str(String(inst.get(&"section_id"))).override_failure_message(
			"AC-6 smoke (c): %s section_id mismatch." % entry["path"]
		).is_equal(String(entry["id"]))
		# (d) entry/respawn distinct Marker3D
		var entry_n: Node = inst.get_node_or_null(inst.get(&"player_entry_point"))
		var respawn_n: Node = inst.get_node_or_null(inst.get(&"player_respawn_point"))
		assert_bool(entry_n != null and entry_n is Marker3D).override_failure_message(
			"AC-6 smoke (d): %s EntryPoint must resolve to Marker3D." % entry["path"]
		).is_true()
		assert_bool(respawn_n != null and respawn_n is Marker3D).override_failure_message(
			"AC-6 smoke (d): %s RespawnPoint must resolve to Marker3D." % entry["path"]
		).is_true()
		assert_bool(entry_n != respawn_n).override_failure_message(
			"AC-6 smoke (d): %s EntryPoint and RespawnPoint must be distinct." % entry["path"]
		).is_true()
		# (e) non-zero section_bounds AABB (call via has_method to avoid SectionRoot
		# type literal at parse time; see test_plaza_scene_root_is_section_root_node3d
		# for the duck-typing rationale)
		var bounds: AABB = inst.call("get_section_bounds")
		assert_bool(bounds.size != Vector3.ZERO).override_failure_message(
			"AC-6 smoke (e): %s section_bounds must be non-zero." % entry["path"]
		).is_true()

		inst.queue_free()
		await get_tree().process_frame


# ── AC-7: section_bounds computed from SectionBoundsHint ─────────────────────

func test_section_bounds_is_non_zero_after_ready() -> void:
	var scene: PackedScene = load(PLAZA_PATH) as PackedScene
	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var bounds: AABB = inst.call("get_section_bounds")
	assert_bool(bounds.size != Vector3.ZERO).override_failure_message(
		"AC-7: get_section_bounds() must return non-zero AABB after _ready(). Got: %s" % bounds
	).is_true()

	inst.queue_free()
	await get_tree().process_frame


# ── AC-8: Floor surface_tag meta ─────────────────────────────────────────────

func test_floor_static_body_has_surface_tag_meta_default() -> void:
	var scenes: Array = [PLAZA_PATH, STUB_B_PATH]
	for path: String in scenes:
		var scene: PackedScene = load(path) as PackedScene
		var inst: Node = scene.instantiate()
		add_child(inst)
		await get_tree().process_frame

		var floor_n: Node = _find_static_body_named(inst, "Floor")
		assert_object(floor_n).override_failure_message(
			"AC-8: %s must have a StaticBody3D child named 'Floor'." % path
		).is_not_null()
		assert_bool(floor_n.has_meta("surface_tag")).override_failure_message(
			"AC-8: %s Floor must have meta 'surface_tag' set." % path
		).is_true()
		assert_str(String(floor_n.get_meta("surface_tag") as StringName)).override_failure_message(
			"AC-8: %s Floor surface_tag must be 'default'. Got: '%s'"
			% [path, floor_n.get_meta("surface_tag")]
		).is_equal("default")

		inst.queue_free()
		await get_tree().process_frame


# ── Helpers ──────────────────────────────────────────────────────────────────

func _find_static_body_named(root: Node, name: String) -> Node:
	for child: Node in root.get_children():
		if child is StaticBody3D and child.name == name:
			return child
	return null
