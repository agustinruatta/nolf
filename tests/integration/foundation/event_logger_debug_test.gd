# tests/integration/foundation/event_logger_debug_test.gd
#
# Integration test suite — EventLogger debug subscription and log formatting.
#
# PURPOSE
#   Validates that EventLogger (a) connects to all 33 Events.* signals in debug
#   builds, (b) formats log lines correctly, and (c) disconnects cleanly on
#   _exit_tree(). These tests run in editor/headless mode, which is always a
#   debug build, so the OS.is_debug_build() branch is exercised here. The
#   non-debug (release) self-removal path requires a release export and is
#   covered by manual evidence in production/qa/evidence/event_logger_release_self_removal.md.
#
# IMPLEMENTATION NOTE — class_name / autoload-key split
#   The autoload key is `EventLogger` (accessible as /root/EventLogger in the
#   scene tree). The GDScript class_name is `SignalBusEventLogger` (used for
#   parse-time instanceof checks). This mirrors the Events/SignalBusEvents split
#   per ADR-0002 OQ-CD-1 amendment. Tests that need a fresh isolated instance
#   call `SignalBusEventLogger.new()`. Tests that need the live autoload call
#   `get_tree().root.get_node_or_null(^"EventLogger") as SignalBusEventLogger`.
#
# WHAT IS TESTED
#   1. _connections.size() == 33 after _ready() in debug build.
#   2. _format_log_line() includes the signal name in the output.
#   3. _format_log_line() includes a timestamp prefix ("[NNN ms]").
#   4. _format_log_line() produces empty parens for a zero-argument signal.
#   5. _format_log_line() includes the "[EventLogger]" log prefix.
#   6. _exit_tree() disconnects all signals and clears _connections.
#
# WHAT IS NOT TESTED HERE
#   - Release-build self-removal (OS.is_debug_build() == false path) — manual
#     verification only; see production/qa/evidence/event_logger_release_self_removal.md.
#   - Actual print() output (no stdout capture in GdUnit4 headless mode).
#   - Per-signal callback correctness beyond the connection count assertion.
#
# GATE STATUS
#   Story SB-003 — Logic story type → BLOCKING gate.
#   Tests must pass before SB-003 may be marked Done.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name EventLoggerDebugTest
extends GdUnitTestSuite

## Total number of Events.* signals that EventLogger must subscribe to.
## Update this constant whenever a new signal is added to events.gd AND
## a corresponding callback is added to event_logger.gd.
const EXPECTED_CONNECTION_COUNT: int = 33


# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

## A fresh SignalBusEventLogger instance, added to the scene tree in tests that
## need _ready() to fire. Freed by after_test() in all cases.
var _logger: SignalBusEventLogger = null


func after_test() -> void:
	# auto_free() registered each instance — GdUnit4 frees them automatically.
	_logger = null


# ---------------------------------------------------------------------------
# Test 1 — Connection count
# ---------------------------------------------------------------------------

## In a debug build, _ready() must subscribe to every Events.* signal.
## The canonical count is EXPECTED_CONNECTION_COUNT (currently 31).
func test_event_logger_subscribes_to_every_events_signal() -> void:
	# Arrange — add to tree so _ready() fires
	_logger = auto_free(SignalBusEventLogger.new())
	add_child(_logger)

	# Assert
	assert_int(_logger._connections.size()).is_equal(EXPECTED_CONNECTION_COUNT)


# ---------------------------------------------------------------------------
# Test 2 — Log line includes signal name
# ---------------------------------------------------------------------------

## _format_log_line must embed the signal name in the returned string.
func test_event_logger_format_log_line_includes_signal_name() -> void:
	# Arrange — standalone instance; _ready() does NOT fire without add_child
	_logger = auto_free(SignalBusEventLogger.new())

	# Act
	var result: String = _logger._format_log_line(&"player_health_changed", [50.0, 100.0])

	# Assert
	assert_str(result).contains("player_health_changed")


# ---------------------------------------------------------------------------
# Test 3 — Log line includes timestamp prefix
# ---------------------------------------------------------------------------

## _format_log_line must begin with "[" and contain " ms]" (timestamp format).
func test_event_logger_format_log_line_includes_timestamp_prefix() -> void:
	# Arrange
	_logger = auto_free(SignalBusEventLogger.new())

	# Act
	var result: String = _logger._format_log_line(&"weapon_fired", [null, Vector3.ZERO, Vector3.FORWARD])

	# Assert
	assert_str(result).starts_with("[")
	assert_str(result).contains(" ms]")


# ---------------------------------------------------------------------------
# Test 4 — Zero-argument signal produces empty parens
# ---------------------------------------------------------------------------

## settings_loaded has no parameters; the formatted output must end with "()".
func test_event_logger_format_log_line_handles_no_payload_signal() -> void:
	# Arrange
	_logger = auto_free(SignalBusEventLogger.new())

	# Act
	var result: String = _logger._format_log_line(&"settings_loaded", [])

	# Assert
	assert_str(result).contains("settings_loaded()")


# ---------------------------------------------------------------------------
# Test 5 — Log line includes the [EventLogger] prefix
# ---------------------------------------------------------------------------

## Every log line must include the LOG_PREFIX constant so grep-based filtering
## works in development sessions.
func test_event_logger_format_log_line_includes_log_prefix() -> void:
	# Arrange
	_logger = auto_free(SignalBusEventLogger.new())

	# Act
	var result: String = _logger._format_log_line(&"game_saved", [0, &"paris_01"])

	# Assert
	assert_str(result).contains("[EventLogger]")


# ---------------------------------------------------------------------------
# Test 6 — _exit_tree disconnects all signals
# ---------------------------------------------------------------------------

## After remove_child() fires _exit_tree(), _connections must be empty and
## representative Events signals must no longer be connected to the logger.
func test_event_logger_disconnects_in_exit_tree() -> void:
	# Arrange — add to tree so _ready() runs _connect_all()
	_logger = auto_free(SignalBusEventLogger.new())
	add_child(_logger)
	assert_int(_logger._connections.size()).is_equal(EXPECTED_CONNECTION_COUNT)

	# Act — remove_child triggers _exit_tree()
	remove_child(_logger)

	# Assert — bookkeeping cleared
	assert_int(_logger._connections.size()).is_equal(0)

	# Assert — sampled signals are no longer connected to this logger instance
	assert_bool(
		Events.player_interacted.is_connected(_logger._on_player_interacted)
	).is_false()
	assert_bool(
		Events.player_health_changed.is_connected(_logger._on_player_health_changed)
	).is_false()
	assert_bool(
		Events.settings_loaded.is_connected(_logger._on_settings_loaded)
	).is_false()
