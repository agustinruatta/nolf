# tests/unit/foundation/signal_bus_smoke_test.gd
#
# Foundation smoke test — signal bus wiring.
#
# PURPOSE
#   Proves that GdUnit4 is installed and functional, and validates the typed
#   signal architecture pattern that all Autoload event buses in this project
#   must follow.  This file has ZERO external dependencies: it defines an
#   inline MinimalSignalBus node so the test compiles and runs before any
#   game system exists.
#
# WHAT IS TESTED
#   1. A signal can be declared with typed parameters.
#   2. A Callable can be connected to that signal using the 4.0+ API.
#   3. Emitting the signal delivers the correct typed arguments to the listener.
#   4. Disconnecting a Callable prevents further delivery.
#   5. CONNECT_ONE_SHOT fires exactly once and auto-disconnects.
#
# WHAT IS NOT TESTED HERE
#   - The real EventBus autoload (not yet authored — see design/gdd/).
#   - Cross-scene signal routing.
#   - Signal ordering / priority (not a feature of Godot's signal system).
#
# GATE STATUS
#   Authorized by gate-check on 2026-04-28 (agent ab1aba599f495a847).
#   Story type: Logic → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SignalBusSmokeTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Minimal inline signal bus — mirrors the pattern the real EventBus will use.
# Defined as an inner class so this file has no external class dependency.
# ---------------------------------------------------------------------------
class MinimalSignalBus extends Node:
	signal value_changed(new_value: int, source_id: StringName)
	signal one_shot_fired(payload: String)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
var _bus: MinimalSignalBus = null
var _received_values: Array[int] = []
var _received_sources: Array[StringName] = []
var _one_shot_count: int = 0


func before_test() -> void:
	_bus = MinimalSignalBus.new()
	add_child(_bus)
	_received_values.clear()
	_received_sources.clear()
	_one_shot_count = 0


func after_test() -> void:
	if is_instance_valid(_bus):
		_bus.queue_free()
	_bus = null


# ---------------------------------------------------------------------------
# Signal listener callbacks
# ---------------------------------------------------------------------------
func _on_value_changed(new_value: int, source_id: StringName) -> void:
	_received_values.append(new_value)
	_received_sources.append(source_id)


func _on_one_shot_fired(_payload: String) -> void:
	_one_shot_count += 1


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## Emitting a signal with typed args delivers the exact values to the listener.
func test_signal_bus_emit_delivers_typed_args() -> void:
	# Arrange
	_bus.value_changed.connect(_on_value_changed)

	# Act
	_bus.value_changed.emit(42, &"player")

	# Assert
	assert_int(_received_values.size()).is_equal(1)
	assert_int(_received_values[0]).is_equal(42)
	assert_str(String(_received_sources[0])).is_equal("player")


## Emitting multiple times accumulates all deliveries.
func test_signal_bus_multiple_emits_accumulate() -> void:
	# Arrange
	_bus.value_changed.connect(_on_value_changed)

	# Act
	_bus.value_changed.emit(1, &"system_a")
	_bus.value_changed.emit(2, &"system_b")
	_bus.value_changed.emit(3, &"system_c")

	# Assert
	assert_int(_received_values.size()).is_equal(3)
	assert_int(_received_values[0]).is_equal(1)
	assert_int(_received_values[1]).is_equal(2)
	assert_int(_received_values[2]).is_equal(3)


## Disconnecting a Callable stops delivery on subsequent emits.
func test_signal_bus_disconnect_stops_delivery() -> void:
	# Arrange
	_bus.value_changed.connect(_on_value_changed)
	_bus.value_changed.emit(10, &"pre_disconnect")

	# Act
	_bus.value_changed.disconnect(_on_value_changed)
	_bus.value_changed.emit(99, &"post_disconnect")

	# Assert — only the pre-disconnect emit was received
	assert_int(_received_values.size()).is_equal(1)
	assert_int(_received_values[0]).is_equal(10)


## CONNECT_ONE_SHOT fires the listener exactly once, then auto-disconnects.
func test_signal_bus_one_shot_fires_exactly_once() -> void:
	# Arrange
	_bus.one_shot_fired.connect(_on_one_shot_fired, CONNECT_ONE_SHOT)

	# Act — emit twice
	_bus.one_shot_fired.emit("first")
	_bus.one_shot_fired.emit("second")

	# Assert — listener called only on the first emit
	assert_int(_one_shot_count).is_equal(1)


## A signal with no connections emits without error (defensive baseline).
func test_signal_bus_emit_with_no_listeners_is_safe() -> void:
	# Arrange — no connections made

	# Act + Assert — must not throw
	_bus.value_changed.emit(0, &"nobody_listening")
	assert_bool(true).is_true()  # Reaching this line means no crash occurred.


## is_connected() correctly tracks connection state.
func test_signal_bus_is_connected_reflects_state() -> void:
	# Arrange — not yet connected
	assert_bool(_bus.value_changed.is_connected(_on_value_changed)).is_false()

	# Act — connect
	_bus.value_changed.connect(_on_value_changed)
	assert_bool(_bus.value_changed.is_connected(_on_value_changed)).is_true()

	# Act — disconnect
	_bus.value_changed.disconnect(_on_value_changed)
	assert_bool(_bus.value_changed.is_connected(_on_value_changed)).is_false()
