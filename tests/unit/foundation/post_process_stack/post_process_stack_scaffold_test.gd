# tests/unit/foundation/post_process_stack/post_process_stack_scaffold_test.gd
#
# PostProcessStackScaffoldTest — GdUnit4 tests for Story PPS-001.
#
# WHAT IS TESTED
#   AC-1: class_name PostProcessStackService extends Node; is_sepia_active
#         is a bool defaulting to false; enable/disable_sepia_dim are
#         callable methods; CHAIN_ORDER is a const Array.
#   AC-3: PostProcessStack is registered as an autoload (resolves to a
#         PostProcessStackService instance at runtime).
#   AC-4: CHAIN_ORDER equals [&"outline", &"sepia_dim", &"resolution_scale"]
#         exactly — Core Rule 1 lock trip-wire.
#   AC-5: post_process_stack.gd source contains zero forward-autoload
#         references (no calls to Combat/FailureRespawn/
#         MissionLevelScripting/SettingsService in the source body).
#
# WHAT IS NOT TESTED HERE
#   - AC-2 (project.godot ordering) — manual review of the [autoload] block;
#     git-diff visibility is the lock mechanism.
#   - AC-6 (cold-boot ≤50 ms) — performance gate; advisory until ADR-0008
#     reaches Accepted with hardware verification.
#
# GATE STATUS
#   Story PPS-001 — Logic type → BLOCKING gate (test-evidence requirement).
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name PostProcessStackScaffoldTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# AC-1: Class declaration & API surface
# ---------------------------------------------------------------------------

## class_name is registered as PostProcessStackService (matches story spec
## and the SaveLoad/Events autoload-key/class-name split precedent).
func test_post_process_stack_class_name_is_registered() -> void:
	# Arrange
	var script: Script = load("res://src/core/rendering/post_process_stack.gd") as Script
	# Assert
	assert_object(script).override_failure_message(
		"AC-1: post_process_stack.gd must be loadable as a Script."
	).is_not_null()
	assert_str(String(script.get_global_name())).override_failure_message(
		"AC-1: class_name must be PostProcessStackService."
	).is_equal("PostProcessStackService")


## is_sepia_active is a bool field defaulting to false on a fresh instance.
func test_post_process_stack_is_sepia_active_default_false() -> void:
	# Arrange
	var instance: PostProcessStackService = auto_free(PostProcessStackService.new())
	# Assert
	assert_bool(instance.is_sepia_active).override_failure_message(
		"AC-1: is_sepia_active must default to false on a fresh instance."
	).is_false()


## enable_sepia_dim() is a callable method that returns void without crashing
## on the stub body (Story PPS-003 fills it in).
func test_post_process_stack_enable_sepia_dim_is_callable_stub() -> void:
	# Arrange
	var instance: PostProcessStackService = auto_free(PostProcessStackService.new())
	# Act + Assert — should not crash
	instance.enable_sepia_dim()
	# Stub body is `pass` so is_sepia_active remains false (state machine in PPS-003).
	assert_bool(instance.is_sepia_active).override_failure_message(
		"AC-1: enable_sepia_dim() stub must not flip state (state machine in PPS-003)."
	).is_false()


## disable_sepia_dim() is a callable method that returns void without crashing.
func test_post_process_stack_disable_sepia_dim_is_callable_stub() -> void:
	# Arrange
	var instance: PostProcessStackService = auto_free(PostProcessStackService.new())
	# Act + Assert — should not crash
	instance.disable_sepia_dim()
	assert_bool(instance.is_sepia_active).override_failure_message(
		"AC-1: disable_sepia_dim() stub must not flip state."
	).is_false()


# ---------------------------------------------------------------------------
# AC-3: Autoload registration
# ---------------------------------------------------------------------------

## PostProcessStack autoload resolves to a PostProcessStackService instance
## at runtime — proves project.godot [autoload] entry is correct.
func test_post_process_stack_autoload_present_in_root_tree() -> void:
	# Arrange
	var root: Window = get_tree().root
	# Act
	var node: Node = root.get_node_or_null("PostProcessStack")
	# Assert
	assert_object(node).override_failure_message(
		"AC-3: /root/PostProcessStack must exist (autoload registered)."
	).is_not_null()
	assert_bool(node is PostProcessStackService).override_failure_message(
		"AC-3: /root/PostProcessStack must be a PostProcessStackService instance."
	).is_true()


# ---------------------------------------------------------------------------
# AC-4: CHAIN_ORDER constant lock
# ---------------------------------------------------------------------------

## CHAIN_ORDER has exactly 3 entries (outline, sepia_dim, resolution_scale).
## This is the GDD Core Rule 1 lock trip-wire — any reorder must update this
## test alongside the const, making the change git-diff-able.
func test_post_process_stack_chain_order_has_three_entries() -> void:
	assert_int(PostProcessStackService.CHAIN_ORDER.size()).override_failure_message(
		"AC-4: CHAIN_ORDER must have exactly 3 entries (outline, sepia_dim, resolution_scale)."
	).is_equal(3)


## CHAIN_ORDER[0] == &"outline" — outline pass runs first.
func test_post_process_stack_chain_order_first_is_outline() -> void:
	assert_str(String(PostProcessStackService.CHAIN_ORDER[0])).override_failure_message(
		"AC-4: CHAIN_ORDER[0] must be &\"outline\" (first pass)."
	).is_equal("outline")


## CHAIN_ORDER[1] == &"sepia_dim" — sepia tints over the outline.
func test_post_process_stack_chain_order_second_is_sepia_dim() -> void:
	assert_str(String(PostProcessStackService.CHAIN_ORDER[1])).override_failure_message(
		"AC-4: CHAIN_ORDER[1] must be &\"sepia_dim\" (second pass)."
	).is_equal("sepia_dim")


## CHAIN_ORDER[2] == &"resolution_scale" — final upscale.
func test_post_process_stack_chain_order_third_is_resolution_scale() -> void:
	assert_str(String(PostProcessStackService.CHAIN_ORDER[2])).override_failure_message(
		"AC-4: CHAIN_ORDER[2] must be &\"resolution_scale\" (final upscale pass)."
	).is_equal("resolution_scale")


# ---------------------------------------------------------------------------
# AC-5: No forward-autoload references in _ready
# ---------------------------------------------------------------------------

## Source-level grep guard: post_process_stack.gd source must NOT reference
## any autoload at position 7+ (Combat, FailureRespawn,
## MissionLevelScripting, SettingsService). Strips comment lines so doc
## comments mentioning these names (allowed) don't trip the guard.
func test_post_process_stack_no_forward_autoload_references_in_source() -> void:
	# Arrange
	var source_path: String = "res://src/core/rendering/post_process_stack.gd"
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	assert_object(file).override_failure_message(
		"AC-5 setup: must be able to open post_process_stack.gd for grep."
	).is_not_null()

	var forward_autoloads: PackedStringArray = PackedStringArray([
		"Combat",
		"FailureRespawn",
		"MissionLevelScripting",
		"SettingsService",
	])

	var offenders: Array[String] = []

	# Act — read line by line, skip comment lines (lines starting with `#`
	# after leading whitespace), look for any forward autoload identifier
	# followed by `.` (member access) or `(` (constructor) — i.e., real
	# code references rather than incidental name mentions.
	while not file.eof_reached():
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped.is_empty():
			continue
		for autoload_name: String in forward_autoloads:
			# Match `Name.` or `Name(` only — bare token references are unusual
			# in GDScript and would be a parse error anyway.
			if stripped.contains(autoload_name + ".") \
				or stripped.contains(autoload_name + "("):
				offenders.append("Line: '%s' references '%s'" % [stripped, autoload_name])

	file.close()

	# Assert
	assert_int(offenders.size()).override_failure_message(
		"AC-5: post_process_stack.gd must not reference any autoload at "
		+ "position 7+ in source code (Combat, FailureRespawn, "
		+ "MissionLevelScripting, SettingsService). Offenders:\n  %s"
		% "\n  ".join(offenders)
	).is_equal(0)
