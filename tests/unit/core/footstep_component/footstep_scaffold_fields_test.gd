# tests/unit/core/footstep_component/footstep_scaffold_fields_test.gd
#
# FootstepScaffoldFieldsTest — GdUnit4 suite for Story FS-001 AC-3 + AC-4.
#
# PURPOSE
#   Verifies FootstepComponent declares all required fields with correct
#   defaults and types, AND that the source file has no untyped `var`
#   declarations (static-typing lint).
#
# GATE STATUS
#   Story FS-001 | Logic type → BLOCKING gate.

class_name FootstepScaffoldFieldsTest
extends GdUnitTestSuite

const _SOURCE_PATH: String = "res://src/gameplay/player/footstep_component.gd"


## AC-3: All four exported knobs default to GDD-specified values.
func test_exported_knobs_have_correct_defaults() -> void:
	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)

	assert_float(fc.cadence_walk_hz).override_failure_message(
		"cadence_walk_hz default must be 2.2 Hz (GDD §Tuning Knobs)."
	).is_equal_approx(2.2, 0.001)
	assert_float(fc.cadence_sprint_hz).override_failure_message(
		"cadence_sprint_hz default must be 3.0 Hz."
	).is_equal_approx(3.0, 0.001)
	assert_float(fc.cadence_crouch_hz).override_failure_message(
		"cadence_crouch_hz default must be 1.6 Hz."
	).is_equal_approx(1.6, 0.001)
	assert_float(fc.surface_raycast_depth_m).override_failure_message(
		"surface_raycast_depth_m default must be 2.0 m."
	).is_equal_approx(2.0, 0.001)


## AC-3: Private state defaults are correct.
func test_private_state_defaults() -> void:
	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)

	assert_bool(fc._is_disabled).override_failure_message(
		"_is_disabled default must be false."
	).is_false()
	assert_float(fc._step_accumulator).override_failure_message(
		"_step_accumulator default must be 0.0."
	).is_equal_approx(0.0, 0.001)
	assert_object(fc._player).override_failure_message(
		"_player default must be null (set in _ready when parent is correct)."
	).is_null()


## AC-3: CADENCE_BY_STATE is populated after _ready (with correct parent),
## and the values equal 1 / cadence.
func test_cadence_by_state_populated_in_ready() -> void:
	var packed: PackedScene = load("res://src/gameplay/player/PlayerCharacter.tscn") as PackedScene
	var player: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(player)
	add_child(player)

	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	player.add_child(fc)  # triggers _ready

	assert_int(fc.CADENCE_BY_STATE.size()).override_failure_message(
		"CADENCE_BY_STATE must contain WALK + SPRINT + CROUCH (3 entries)."
	).is_equal(3)

	assert_float(fc.CADENCE_BY_STATE[PlayerEnums.MovementState.WALK]).override_failure_message(
		"CADENCE_BY_STATE[WALK] must equal 1 / cadence_walk_hz = 1/2.2."
	).is_equal_approx(1.0 / 2.2, 0.001)
	assert_float(fc.CADENCE_BY_STATE[PlayerEnums.MovementState.SPRINT]).override_failure_message(
		"CADENCE_BY_STATE[SPRINT] must equal 1 / cadence_sprint_hz = 1/3.0."
	).is_equal_approx(1.0 / 3.0, 0.001)
	assert_float(fc.CADENCE_BY_STATE[PlayerEnums.MovementState.CROUCH]).override_failure_message(
		"CADENCE_BY_STATE[CROUCH] must equal 1 / cadence_crouch_hz = 1/1.6."
	).is_equal_approx(1.0 / 1.6, 0.001)


## AC-3: CADENCE_BY_STATE excludes IDLE / JUMP / FALL / DEAD per design
## (those states suppress footstep emission in Story FS-002's loop).
func test_cadence_by_state_excludes_non_locomotion_states() -> void:
	var packed: PackedScene = load("res://src/gameplay/player/PlayerCharacter.tscn") as PackedScene
	var player: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(player)
	add_child(player)

	var fc: FootstepComponent = FootstepComponent.new()
	auto_free(fc)
	player.add_child(fc)

	assert_bool(fc.CADENCE_BY_STATE.has(PlayerEnums.MovementState.IDLE)).override_failure_message(
		"CADENCE_BY_STATE must NOT contain IDLE — emission suppressed."
	).is_false()
	assert_bool(fc.CADENCE_BY_STATE.has(PlayerEnums.MovementState.JUMP)).override_failure_message(
		"CADENCE_BY_STATE must NOT contain JUMP."
	).is_false()
	assert_bool(fc.CADENCE_BY_STATE.has(PlayerEnums.MovementState.FALL)).override_failure_message(
		"CADENCE_BY_STATE must NOT contain FALL."
	).is_false()
	assert_bool(fc.CADENCE_BY_STATE.has(PlayerEnums.MovementState.DEAD)).override_failure_message(
		"CADENCE_BY_STATE must NOT contain DEAD."
	).is_false()


## AC-4: Static-typing lint — no untyped `var` declarations in the source.
## Pattern matches `var <name>` followed by `=` or end-of-line, but NOT `var <name>:`.
func test_no_untyped_var_declarations() -> void:
	var f: FileAccess = FileAccess.open(_SOURCE_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	var lines: PackedStringArray = content.split("\n")
	var failures: Array[String] = []
	# Match a `var` declaration that does NOT have a type annotation.
	# Pattern: leading whitespace, `var ` or `@export var ` prefix, identifier,
	# optional initializer or end of line, but NO colon.
	var untyped_re: RegEx = RegEx.new()
	# Negative lookahead via simpler form: `var <ident>` followed by space/=/EOL,
	# excluding a colon between var and = or EOL.
	untyped_re.compile("^\\s*(@export\\s+)?var\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*(=|$)")

	for i: int in range(lines.size()):
		var line: String = lines[i]
		# Skip comment-only lines.
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or stripped == "":
			continue
		# Strip trailing comments before regex.
		var hash_idx: int = line.find("#")
		var code_part: String = line if hash_idx < 0 else line.substr(0, hash_idx)
		if untyped_re.search(code_part) != null:
			failures.append("%s:%d → '%s'" % [_SOURCE_PATH, i + 1, line])

	assert_int(failures.size()).override_failure_message(
		"Source file must have NO untyped `var` declarations. Failures:\n  %s" % "\n  ".join(failures)
	).is_equal(0)


## AC-4: All exported properties have a doc comment line immediately above.
func test_exported_properties_have_doc_comments() -> void:
	var f: FileAccess = FileAccess.open(_SOURCE_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	var lines: PackedStringArray = content.split("\n")
	var failures: Array[String] = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		if line.strip_edges().begins_with("@export"):
			# Look at preceding lines; skip blank lines; the most recent
			# non-blank line above must start with `##`.
			var found_doc: bool = false
			var j: int = i - 1
			while j >= 0:
				var above: String = lines[j].strip_edges()
				if above == "":
					j -= 1
					continue
				if above.begins_with("##"):
					found_doc = true
				break
			if not found_doc:
				failures.append("%s:%d → '%s'" % [_SOURCE_PATH, i + 1, line.strip_edges()])

	assert_int(failures.size()).override_failure_message(
		"All @export properties must have a `##` doc comment above. Missing:\n  %s" % "\n  ".join(failures)
	).is_equal(0)
