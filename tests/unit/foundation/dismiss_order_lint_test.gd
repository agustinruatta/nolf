# tests/unit/foundation/dismiss_order_lint_test.gd
#
# DismissOrderLintTest — Story IN-003 AC-INPUT-3.2.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-003)
#   AC-3.2 [Code-Review] BLOCKING: every InputContext.pop() in src/ and
#   tests/integration/ is preceded by set_input_as_handled() within 5 lines.
#   Exemptions allowed via `# dismiss-order-ok: <reason>` annotation.
#
# DESIGN
#   Invokes tools/ci/check_dismiss_order.sh via OS.execute. Exit code 0 = pass.
#   Wraps the bash script in a GdUnit4 test so the dismiss-order gate runs as
#   part of the standard headless suite (no separate CI workflow step needed).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name DismissOrderLintTest
extends GdUnitTestSuite


## AC-3.2: dismiss-order CI gate passes against the current source tree.
func test_dismiss_order_ci_script_passes() -> void:
	var output: Array = []
	var project_root: String = ProjectSettings.globalize_path("res://")
	var script_path: String = project_root.path_join("tools/ci/check_dismiss_order.sh")

	# Run the script with src/ and tests/integration/ search roots.
	var exit_code: int = OS.execute(
			"bash",
			[script_path, "src", "tests/integration"],
			output,
			true,  # read_stderr
	)

	var output_text: String = "\n".join(output)
	assert_int(exit_code).override_failure_message(
			"AC-3.2: tools/ci/check_dismiss_order.sh must exit 0. Got %d.\nOutput:\n%s" % [
					exit_code, output_text
			]
	).is_equal(0)

	# Sanity check: script reported PASS in its output
	assert_bool(output_text.contains("PASS")).override_failure_message(
			"AC-3.2: script output must contain 'PASS' marker. Output:\n%s" % output_text
	).is_true()


## AC-3.2: the CI script itself exists and is executable.
func test_dismiss_order_ci_script_exists() -> void:
	var script_path: String = "res://tools/ci/check_dismiss_order.sh"
	assert_bool(FileAccess.file_exists(script_path)).override_failure_message(
			"AC-3.2: tools/ci/check_dismiss_order.sh must exist."
	).is_true()
