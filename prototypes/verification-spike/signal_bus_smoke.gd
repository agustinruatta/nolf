# prototypes/verification-spike/signal_bus_smoke.gd
#
# Signal Bus end-to-end smoke test — closes ADR-0002 G1 and ADR-0007 G(b).
#
# WHAT IT VERIFIES
#   1. Events autoload is registered and reachable at /root/Events.
#   2. EventLogger autoload is registered and reachable at /root/EventLogger.
#   3. EventLogger's _ready() successfully connected to Events.smoke_test_pulse
#      (proves Cross-Autoload Reference Safety — line 2 → line 1 reference works).
#   4. Emit → subscriber receives the correct typed payload.
#   5. EventLogger printed the expected log line (visible above this script's
#      output in the run log).
#
# HOW TO RUN
#   From project root:
#     godot --headless res://prototypes/verification-spike/signal_bus_smoke.tscn
#
# OUTPUT
#   Per-check PASS/FAIL plus a summary line. Exits with code 0 on full PASS,
#   code 1 on any check failure. EventLogger's print appears interleaved.

extends Node

var _received_payloads: Array[int] = []
var _all_passed: bool = true


func _ready() -> void:
	print()
	print("=== ADR-0002 G1 + ADR-0007 G(b) — Signal Bus Smoke Test ===")
	print("Engine version (runtime): %s" % Engine.get_version_info().string)
	print("Date: %s" % Time.get_datetime_string_from_system())
	print()

	_check_events_autoload()
	_check_event_logger_autoload()
	_check_event_logger_subscribed()
	await _check_emit_receives()

	print()
	if _all_passed:
		print("=== Result: PASS — Events autoload OK, cross-autoload reference safe, emit/receive end-to-end OK ===")
		get_tree().quit(0)
	else:
		print("=== Result: FAIL — see check-level output above ===")
		get_tree().quit(1)


# ─── Check 1 ───────────────────────────────────────────────────────────
# Events autoload is reachable at /root/Events with type SignalBusEvents.
func _check_events_autoload() -> void:
	print("[Check 1] Events autoload reachable")
	var node := get_node_or_null("/root/Events")
	if node == null:
		_fail("Check 1", "Events autoload not found at /root/Events")
		return
	if not node is SignalBusEvents:
		_fail("Check 1", "/root/Events is not SignalBusEvents (got %s)" % node.get_class())
		return
	print("  PASS — Events at /root/Events, type SignalBusEvents")


# ─── Check 2 ───────────────────────────────────────────────────────────
# EventLogger autoload is reachable at /root/EventLogger.
func _check_event_logger_autoload() -> void:
	print("[Check 2] EventLogger autoload reachable")
	var node := get_node_or_null("/root/EventLogger")
	if node == null:
		_fail("Check 2", "EventLogger autoload not found at /root/EventLogger")
		return
	print("  PASS — EventLogger at /root/EventLogger")


# ─── Check 3 ───────────────────────────────────────────────────────────
# Cross-autoload reference safety: EventLogger._ready() successfully connected
# to Events.smoke_test_pulse. If the connect() call had null-derefed Events
# (because Events wasn't in the tree yet at line 2's _ready), there would be
# no subscribers on this signal.
func _check_event_logger_subscribed() -> void:
	print("[Check 3] EventLogger subscribed to Events.smoke_test_pulse (cross-autoload reference safety)")
	var connections := Events.smoke_test_pulse.get_connections()
	if connections.is_empty():
		_fail("Check 3", "No subscribers registered on Events.smoke_test_pulse — EventLogger._ready() likely null-derefed Events")
		return
	# At least one connection must be from EventLogger.
	var found_logger := false
	for c in connections:
		var callable: Callable = c.callable
		var subscriber: Object = callable.get_object()
		if subscriber != null and subscriber.get_path() == NodePath("/root/EventLogger"):
			found_logger = true
			break
	if not found_logger:
		_fail("Check 3", "Subscribers exist (%d) but none belong to /root/EventLogger" % connections.size())
		return
	print("  PASS — EventLogger registered as subscriber (total subscribers: %d)" % connections.size())


# ─── Check 4 ───────────────────────────────────────────────────────────
# Emit → subscriber receives correct payload. Local subscriber on the smoke
# test scene receives the same emission EventLogger receives.
func _check_emit_receives() -> void:
	print("[Check 4] Emit → subscriber receives correct payload")
	# Connect a local subscriber on this scene; EventLogger is already
	# subscribed (verified in Check 3). Both should receive the emission.
	Events.smoke_test_pulse.connect(_on_pulse)
	Events.smoke_test_pulse.emit(42)
	# Allow the engine one frame to dispatch deferred work (signal emission
	# itself is synchronous, but quit() on the same frame can race).
	await get_tree().process_frame

	if _received_payloads.size() != 1:
		_fail("Check 4", "Expected 1 received payload, got %d" % _received_payloads.size())
		return
	if _received_payloads[0] != 42:
		_fail("Check 4", "Expected payload=42, got %d" % _received_payloads[0])
		return
	print("  PASS — local subscriber received payload=42 (EventLogger's print should appear above this line)")


# ─── Helpers ───────────────────────────────────────────────────────────

func _on_pulse(payload: int) -> void:
	_received_payloads.append(payload)


func _fail(check: String, msg: String) -> void:
	_all_passed = false
	print("  FAIL — %s" % msg)
