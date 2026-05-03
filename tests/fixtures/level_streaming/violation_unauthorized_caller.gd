# tests/fixtures/level_streaming/violation_unauthorized_caller.gd
#
# DELIBERATE VIOLATION FIXTURE — do NOT import into production code.
#
# This file contains a simulated unauthorized call to
# LevelStreamingService.transition_to_section. It exists to verify that the
# lint test (level_streaming_lint_test.gd AC-1 / AC-8 fixture scan) correctly
# detects and reports the pattern when it appears outside the authorised caller
# paths.
#
# This file lives under tests/fixtures/ which is EXCLUDED from the production
# lint scope (the lint test scans res://src/ only). The fixture-scan tests
# (AC-8) explicitly include this path to verify that the grep logic fires.
#
# Story LS-009. GDD CR-4. ADR-0007.

# Intentional violation — this is fixture-only code, never executed.
# LevelStreamingService.transition_to_section(&"stub_b", null, 0)
# ^ Commented out so the parser does not try to resolve LevelStreamingService
#   at fixture-load time; the lint test uses FileAccess text-grep, not parse.
# Uncommented version for grep detection (string only, no execution path):
const _VIOLATION_MARKER: String = "LevelStreamingService.transition_to_section"
