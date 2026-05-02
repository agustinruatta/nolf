# tests/unit/foundation/input_ci_lints_test.gd
#
# InputCILintsTest — Story IN-004 CI script gate runner.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-004)
#   AC-1.2 (BLOCKING): check_action_literals.sh exit 0
#   AC-5.3 (BLOCKING): check_debug_action_gating.sh exit 0
#   AC-6.1 (BLOCKING): check_raw_input_constants.sh exit 0
#   AC-6.2 (BLOCKING): check_action_add_event_validation.sh exit 0
#   AC-6.3 (ADVISORY): check_unhandled_input_default.sh exit 0 (always)
#
# DESIGN
#   Each CI script is invoked via OS.execute and asserted to return exit code 0.
#   This wraps the bash CI gates in the standard headless test suite so the
#   anti-pattern enforcement runs as part of `/smoke-check sprint`.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name InputCILintsTest
extends GdUnitTestSuite


## Generic helper: runs a CI script and asserts exit code 0.
func _run_script_and_assert_pass(script_name: String, ac_label: String) -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var script_path: String = project_root.path_join("tools/ci/").path_join(script_name)

	var output: Array = []
	var exit_code: int = OS.execute("bash", [script_path], output, true)
	var output_text: String = "\n".join(output)

	assert_int(exit_code).override_failure_message(
		"%s: %s must exit 0. Got %d.\nOutput:\n%s" % [
			ac_label, script_name, exit_code, output_text
		]
	).is_equal(0)


# ── AC-1.2: check_action_literals.sh ─────────────────────────────────────────

func test_check_action_literals_passes() -> void:
	_run_script_and_assert_pass("check_action_literals.sh", "AC-INPUT-1.2")


# ── AC-5.3: check_debug_action_gating.sh ─────────────────────────────────────

func test_check_debug_action_gating_passes() -> void:
	_run_script_and_assert_pass("check_debug_action_gating.sh", "AC-INPUT-5.3")


# ── AC-6.1: check_raw_input_constants.sh ─────────────────────────────────────

func test_check_raw_input_constants_passes() -> void:
	_run_script_and_assert_pass("check_raw_input_constants.sh", "AC-INPUT-6.1")


# ── AC-6.2: check_action_add_event_validation.sh ─────────────────────────────

func test_check_action_add_event_validation_passes() -> void:
	_run_script_and_assert_pass("check_action_add_event_validation.sh", "AC-INPUT-6.2")


# ── AC-6.3: check_unhandled_input_default.sh (ADVISORY — always exits 0) ────

func test_check_unhandled_input_default_runs() -> void:
	# AC-6.3 is advisory — script always exits 0 by design (lists, never blocks).
	_run_script_and_assert_pass("check_unhandled_input_default.sh", "AC-INPUT-6.3")


# ── All 5 scripts exist and are executable ──────────────────────────────────

func test_all_ci_scripts_exist() -> void:
	var script_names: Array[String] = [
		"check_action_literals.sh",
		"check_debug_action_gating.sh",
		"check_raw_input_constants.sh",
		"check_action_add_event_validation.sh",
		"check_unhandled_input_default.sh",
	]
	var missing: Array[String] = []
	for name: String in script_names:
		var path: String = "res://tools/ci/".path_join(name)
		if not FileAccess.file_exists(path):
			missing.append(name)

	assert_int(missing.size()).override_failure_message(
		"Story IN-004 requires 5 CI scripts in tools/ci/. Missing: %s" % str(missing)
	).is_equal(0)
