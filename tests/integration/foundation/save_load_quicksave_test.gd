# tests/integration/foundation/save_load_quicksave_test.gd
#
# Integration test suite — Story SL-007: Quicksave (F5) / Quickload (F9)
# + InputContext gating.
#
# PURPOSE
#   Validates all 10 Acceptance Criteria of SL-007 at integration level:
#   three autoloads (Events line 1, SaveLoad line 3, InputContext line 4)
#   cooperating at input-event time through QuicksaveInputHandler.
#
# WHAT IS TESTED
#   AC-1 : F5 in GAMEPLAY context fires save_to_slot + game_saved + toast.
#   AC-2 : F5 in SETTINGS context (CUTSCENE substitute — see Completion Notes)
#           is a silent no-op: zero signal emissions.
#   AC-3 : F5 in DOCUMENT_OVERLAY context is a silent no-op.
#   AC-4 : F5 in MODAL context is a silent no-op.
#   AC-5 : F5 in LOADING context is a silent no-op.
#   AC-6 : F9 with empty slot 0 emits hud_toast_requested(&"quicksave_unavailable").
#   AC-7 : F9 with occupied slot 0 calls load_from_slot + game_loaded fires.
#   AC-8 : F5 debounce: second press within 500 ms is dropped; press at 600 ms fires.
#   AC-9 : save_load_service.gd _ready() body contains zero "InputContext" references.
#   AC-10: F5 handler calls save_to_slot and returns — no internal queue.
#
# DETERMINISM
#   - InputContext is pushed/popped per-test via InputContext.push / .pop.
#   - Debounce clock is injected via handler.set_debounce_clock() — no
#     Time.get_ticks_msec() dependency in debounce tests.
#   - Signal spy arrays are cleared before each test.
#
# GATE STATUS
#   Story SL-007 — Integration type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveLoadQuicksaveTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Signal spy state
# ---------------------------------------------------------------------------

var _game_saved_calls: Array[Dictionary] = []
var _game_loaded_slots: Array[int] = []
var _save_failed_reasons: Array[int] = []
var _toast_calls: Array[Dictionary] = []


func _on_game_saved(slot: int, section_id: StringName) -> void:
	_game_saved_calls.append({"slot": slot, "section_id": section_id})


func _on_game_loaded(slot: int) -> void:
	_game_loaded_slots.append(slot)


func _on_save_failed(reason: int) -> void:
	_save_failed_reasons.append(reason)


func _on_hud_toast_requested(toast_id: StringName, payload: Dictionary) -> void:
	_toast_calls.append({"toast_id": toast_id, "payload": payload})


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_test() -> void:
	_game_saved_calls.clear()
	_game_loaded_slots.clear()
	_save_failed_reasons.clear()
	_toast_calls.clear()
	_clean_save_dir()
	# Connect spy handlers to the live autoload.
	Events.game_saved.connect(_on_game_saved)
	Events.game_loaded.connect(_on_game_loaded)
	Events.save_failed.connect(_on_save_failed)
	Events.hud_toast_requested.connect(_on_hud_toast_requested)


func after_test() -> void:
	# Disconnect spies (ADR-0002 IG 3: is_connected guard before disconnect).
	if Events.game_saved.is_connected(_on_game_saved):
		Events.game_saved.disconnect(_on_game_saved)
	if Events.game_loaded.is_connected(_on_game_loaded):
		Events.game_loaded.disconnect(_on_game_loaded)
	if Events.save_failed.is_connected(_on_save_failed):
		Events.save_failed.disconnect(_on_save_failed)
	if Events.hud_toast_requested.is_connected(_on_hud_toast_requested):
		Events.hud_toast_requested.disconnect(_on_hud_toast_requested)
	# Restore InputContext to GAMEPLAY baseline (pop any contexts pushed in test).
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event
	_clean_save_dir()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Removes every regular file under user://saves/ but keeps the directory.
func _clean_save_dir() -> void:
	var dir: DirAccess = DirAccess.open(SaveLoadService.SAVE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


## Builds a minimal valid SaveGame suitable for quicksave tests.
func _build_stub_save_game() -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.saved_at_iso8601 = "2026-05-02T10:00:00"
	sg.section_id = &"plaza"
	sg.elapsed_seconds = 60.0
	return sg


## Creates a QuicksaveInputHandler wired to a stub assembler that returns a
## valid SaveGame. Caller owns lifecycle (auto_free or explicit queue_free).
func _make_handler_with_stub_assembler() -> QuicksaveInputHandler:
	var handler: QuicksaveInputHandler = auto_free(QuicksaveInputHandler.new())
	handler.set_assembler(func() -> SaveGame: return _build_stub_save_game())
	return handler


## Simulate an F5 quicksave press through the handler's _unhandled_input path
## without using Input.parse_input_event (avoids InputMap registration dependency
## in headless test context). Calls the internal _try_quicksave directly.
## This tests the same code path _unhandled_input would call.
func _fire_quicksave(handler: QuicksaveInputHandler) -> void:
	handler._try_quicksave()


## Simulate an F9 quickload press.
func _fire_quickload(handler: QuicksaveInputHandler) -> void:
	handler._try_quickload()


# ---------------------------------------------------------------------------
# AC-1 — F5 in GAMEPLAY context fires save, game_saved, and toast
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == GAMEPLAY AND assembler returns a valid SaveGame
## WHEN F5 handler fires
## THEN save_to_slot(0, sg) is called, game_saved fires once with slot=0,
## hud_toast_requested fires once with toast_id &"quicksave_success".
func test_quicksave_gameplay_context_fires_save_and_emits_signals() -> void:
	# Arrange — InputContext starts as GAMEPLAY (baseline invariant).
	assert_bool(InputContext.current() == InputContextStack.Context.GAMEPLAY).is_true()
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quicksave(handler)

	# Assert — slot 0 file created on disk (save_to_slot ran)
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()

	# Assert — game_saved fired exactly once for slot 0
	assert_int(_game_saved_calls.size()).is_equal(1)
	assert_int(int(_game_saved_calls[0]["slot"])).is_equal(0)

	# Assert — HUD toast fired once with correct toast_id and slot payload
	assert_int(_toast_calls.size()).is_equal(1)
	assert_str(String(_toast_calls[0]["toast_id"])).is_equal("quicksave_success")
	assert_int(int(_toast_calls[0]["payload"]["slot"])).is_equal(0)

	# Assert — no failure signals
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-2 — F5 in SETTINGS context (CUTSCENE substitute) is silent no-op
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == SETTINGS (substitutes for story's CUTSCENE
## which does not exist — see Completion Notes)
## WHEN F5 handler fires
## THEN zero signals fire, no file created.
func test_quicksave_settings_context_is_silent_noop() -> void:
	# Arrange
	InputContext.push(InputContextStack.Context.SETTINGS)
	assert_bool(InputContext.current() == InputContextStack.Context.SETTINGS).is_true()
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quicksave(handler)

	# Assert — no file, no signals
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_int(_save_failed_reasons.size()).is_equal(0)
	assert_int(_toast_calls.size()).is_equal(0)

	# Cleanup — restore context
	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ---------------------------------------------------------------------------
# AC-3 — F5 in DOCUMENT_OVERLAY context is silent no-op
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == DOCUMENT_OVERLAY
## WHEN F5 handler fires
## THEN zero signals fire, no file created (CR-6 extension 2026-04-28).
func test_quicksave_document_overlay_context_is_silent_noop() -> void:
	# Arrange
	InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quicksave(handler)

	# Assert
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_int(_save_failed_reasons.size()).is_equal(0)
	assert_int(_toast_calls.size()).is_equal(0)

	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ---------------------------------------------------------------------------
# AC-4 — F5 in MODAL context is silent no-op
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == MODAL
## WHEN F5 handler fires
## THEN zero signals fire, no file created.
func test_quicksave_modal_context_is_silent_noop() -> void:
	# Arrange
	InputContext.push(InputContextStack.Context.MODAL)
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quicksave(handler)

	# Assert
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_int(_save_failed_reasons.size()).is_equal(0)
	assert_int(_toast_calls.size()).is_equal(0)

	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ---------------------------------------------------------------------------
# AC-5 — F5 in LOADING context is silent no-op
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == LOADING
## WHEN F5 handler fires
## THEN zero signals fire, no file created.
func test_quicksave_loading_context_is_silent_noop() -> void:
	# Arrange
	InputContext.push(InputContextStack.Context.LOADING)
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quicksave(handler)

	# Assert
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_int(_save_failed_reasons.size()).is_equal(0)
	assert_int(_toast_calls.size()).is_equal(0)

	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ---------------------------------------------------------------------------
# AC-6 — F9 with empty slot 0 emits unavailable toast
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == GAMEPLAY AND slot 0 does not exist
## WHEN F9 handler fires
## THEN hud_toast_requested fires with &"quicksave_unavailable", no game_loaded.
func test_quickload_empty_slot_emits_unavailable_toast() -> void:
	# Arrange — slot 0 absent (clean dir from before_test)
	assert_bool(SaveLoad.slot_exists(0)).is_false()
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quickload(handler)

	# Assert — unavailable toast fired once
	assert_int(_toast_calls.size()).is_equal(1)
	assert_str(String(_toast_calls[0]["toast_id"])).is_equal("quicksave_unavailable")

	# Assert — no load signals, no save signals
	assert_int(_game_loaded_slots.size()).is_equal(0)
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-7 — F9 with occupied slot 0 fires load and game_loaded
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == GAMEPLAY AND slot 0 exists
## WHEN F9 handler fires
## THEN game_loaded fires once with slot=0; no error signals.
func test_quickload_occupied_slot_fires_game_loaded() -> void:
	# Arrange — write slot 0 via the service directly (simulates a prior save).
	var service: SaveLoadService = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_stub_save_game()
	assert_bool(service.save_to_slot(0, sg)).is_true()

	# Clear spy state from the bootstrapping save above.
	_game_saved_calls.clear()
	_save_failed_reasons.clear()
	_toast_calls.clear()

	# Confirm slot 0 exists before F9.
	assert_bool(SaveLoad.slot_exists(0)).is_true()
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quickload(handler)

	# Assert — game_loaded fired once for slot 0
	assert_int(_game_loaded_slots.size()).is_equal(1)
	assert_int(_game_loaded_slots[0]).is_equal(0)

	# Assert — no failure or toast signals for a successful load
	assert_int(_save_failed_reasons.size()).is_equal(0)
	assert_int(_toast_calls.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-7 (MENU context) — F9 also works in MENU context
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == MENU AND slot 0 exists
## WHEN F9 handler fires
## THEN game_loaded fires — confirms MENU is save-eligible for quickload.
func test_quickload_menu_context_occupied_slot_fires_game_loaded() -> void:
	# Arrange — write slot 0
	var service: SaveLoadService = auto_free(SaveLoadService.new())
	assert_bool(service.save_to_slot(0, _build_stub_save_game())).is_true()
	_game_saved_calls.clear()
	_save_failed_reasons.clear()
	_toast_calls.clear()

	InputContext.push(InputContextStack.Context.MENU)
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quickload(handler)

	# Assert
	assert_int(_game_loaded_slots.size()).is_equal(1)
	assert_int(_game_loaded_slots[0]).is_equal(0)

	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ---------------------------------------------------------------------------
# AC-8 — Debounce: second F5 within 500 ms dropped; third at 600 ms fires
# ---------------------------------------------------------------------------

## GIVEN F5 fires at t=0 (success), then at t=300 (within debounce window),
## then at t=600 (beyond window)
## THEN exactly 2 game_saved emissions at t=0 and t=600; t=300 is dropped.
## Uses injected clock for determinism — no real time dependency.
func test_quicksave_debounce_drops_rapid_press_allows_after_window() -> void:
	# Arrange — injectable clock starting at t=0.
	# Use Array[int] container so the lambda captures the array by reference,
	# allowing clock_state[0] mutations to be visible inside the closure.
	# GDScript lambdas capture local primitives by value at creation time;
	# capturing a container object (Array) gives mutable-by-reference semantics.
	var clock_state: Array[int] = [0]
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()
	handler.set_debounce_clock(func() -> int: return clock_state[0])

	# Act + Assert — t=0: first press succeeds.
	clock_state[0] = 0
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(1)

	# Act + Assert — t=300: within 500 ms window, dropped.
	clock_state[0] = 300
	_game_saved_calls.clear()
	_toast_calls.clear()
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_int(_toast_calls.size()).is_equal(0)

	# Act + Assert — t=600: beyond 500 ms window, fires successfully.
	clock_state[0] = 600
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(1)
	assert_int(_toast_calls.size()).is_equal(1)
	assert_str(String(_toast_calls[0]["toast_id"])).is_equal("quicksave_success")


## GIVEN a gated F5 press (SETTINGS context) does NOT update the debounce clock
## WHEN InputContext returns to GAMEPLAY and F5 fires immediately after
## THEN the save fires immediately (gated presses do not consume the debounce window).
func test_quicksave_debounce_gated_press_does_not_consume_window() -> void:
	# Arrange — injectable clock at t=0.
	# Use Array[int] container so the lambda captures the array by reference.
	# GDScript lambdas capture local primitives by value at creation time;
	# capturing a container object (Array) gives mutable-by-reference semantics.
	var clock_state: Array[int] = [0]
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()
	handler.set_debounce_clock(func() -> int: return clock_state[0])

	# Act — first GAMEPLAY press succeeds at t=0.
	clock_state[0] = 0
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(1)

	# Act — at t=200 (within window), press in SETTINGS — should not update clock.
	clock_state[0] = 200
	InputContext.push(InputContextStack.Context.SETTINGS)
	_game_saved_calls.clear()
	_toast_calls.clear()
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(0)  # Gated — no save.
	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event

	# Act — at t=200 back in GAMEPLAY: still within original debounce window
	# (last SUCCESSFUL save was at t=0, now is t=200 < 500).
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(0)  # Still debounced from t=0 success.

	# Act — at t=600: beyond window, fires successfully.
	clock_state[0] = 600
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(1)


# ---------------------------------------------------------------------------
# AC-9 — save_load_service.gd _ready() body has zero InputContext references
# ---------------------------------------------------------------------------

## The _ready() body of save_load_service.gd must contain zero occurrences of
## "InputContext" — per ADR-0007 §Cross-Autoload Reference Safety rule 3.
## Grep is intentionally strict: even comments inside _ready() must not
## reference InputContext (to avoid false-positive grep matches that mask
## real violations). The AC-9 story spec permits this strictness.
##
## Note: the QuicksaveInputHandler is *instantiated* in _ready() but the word
## "InputContext" must not appear in the _ready() body itself — the handler
## file is separate and references InputContext only at event time.
func test_save_load_service_ready_body_has_no_input_context_reference() -> void:
	# Arrange — read the service source.
	var src: String = FileAccess.get_file_as_string(
		"res://src/core/save_load/save_load_service.gd"
	)
	assert_str(src).is_not_empty()

	# Extract _ready() body using the same helper as the neighbouring save test.
	var ready_body: String = _extract_function_body(src, "_ready")

	# Assert — "InputContext" must not appear inside _ready().
	assert_int(ready_body.find("InputContext")).override_failure_message(
		"'InputContext' found inside save_load_service.gd _ready() — violates ADR-0007 rule 3"
	).is_equal(-1)


## Returns the substring of `src` from `func <name>(` to the next top-level
## `func ` (or end-of-file). Returns empty string if the function is absent.
## Duplicated here so this test file is standalone (no cross-test imports).
func _extract_function_body(src: String, func_name: String) -> String:
	var start_idx: int = src.find("func %s(" % func_name)
	if start_idx == -1:
		return ""
	var search_from: int = start_idx + len("func %s(" % func_name)
	var end_idx: int = src.find("\nfunc ", search_from)
	if end_idx == -1:
		return src.substr(start_idx)
	return src.substr(start_idx, end_idx - start_idx)


# ---------------------------------------------------------------------------
# AC-10 — F5 calls save_to_slot and returns without internal queuing
# ---------------------------------------------------------------------------

## GIVEN F5 fires while InputContext == GAMEPLAY
## WHEN save_to_slot returns (success or failure)
## THEN the handler returns immediately — no blocking, no internal queue.
## This test verifies the fire-and-forget contract by checking that two
## consecutive F5 presses (both past the debounce window) each independently
## call save_to_slot rather than piling up. The state-machine queueing is
## Story 008's responsibility.
func test_quicksave_fire_and_forget_no_internal_queue() -> void:
	# Arrange — use a mock clock far ahead so debounce is not a factor.
	# Use Array[int] container so the lambda captures the array by reference.
	# GDScript lambdas capture local primitives by value at creation time;
	# capturing a container object (Array) gives mutable-by-reference semantics.
	var clock_state: Array[int] = [0]
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()
	handler.set_debounce_clock(func() -> int: return clock_state[0])

	# Act — first save at t=0.
	clock_state[0] = 0
	_fire_quicksave(handler)
	assert_int(_game_saved_calls.size()).is_equal(1)

	# Act — second save at t=1000 (well past debounce window).
	clock_state[0] = 1000
	_fire_quicksave(handler)

	# Assert — two independent calls to save_to_slot produced two game_saved emits.
	# If the handler were queuing, only one would fire in this synchronous test.
	assert_int(_game_saved_calls.size()).is_equal(2)
	assert_int(_game_saved_calls[0]["slot"]).is_equal(0)
	assert_int(_game_saved_calls[1]["slot"]).is_equal(0)

	# Assert — no failure signals — both saves succeeded independently.
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-1 bonus — F5 in PAUSE context also fires save (PAUSE is save-eligible)
# ---------------------------------------------------------------------------

## GIVEN InputContext.current() == PAUSE
## WHEN F5 handler fires
## THEN save fires (PAUSE is a save-eligible context per GDD CR-6).
func test_quicksave_pause_context_fires_save() -> void:
	# Arrange
	InputContext.push(InputContextStack.Context.PAUSE)
	var handler: QuicksaveInputHandler = _make_handler_with_stub_assembler()

	# Act
	_fire_quicksave(handler)

	# Assert — save and toast fired
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	assert_int(_game_saved_calls.size()).is_equal(1)
	assert_int(_toast_calls.size()).is_equal(1)
	assert_str(String(_toast_calls[0]["toast_id"])).is_equal("quicksave_success")

	InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ---------------------------------------------------------------------------
# Signal declaration — hud_toast_requested must be in Events
# ---------------------------------------------------------------------------

## Events autoload must declare hud_toast_requested(toast_id: StringName,
## payload: Dictionary) as required by SL-007 (first story to emit this signal).
func test_events_declares_hud_toast_requested_signal() -> void:
	# Arrange
	var events_node: Node = get_tree().root.get_node_or_null(^"Events")
	assert_object(events_node).is_not_null()

	# Build signal map (filter out Node built-ins).
	var bare: Node = Node.new()
	var bare_sigs: Dictionary = {}
	for sig: Dictionary in bare.get_signal_list():
		bare_sigs[sig["name"]] = true
	bare.free()

	var sig_map: Dictionary = {}
	for sig: Dictionary in events_node.get_signal_list():
		if not bare_sigs.has(sig["name"]):
			sig_map[sig["name"]] = sig

	# Assert — signal present
	assert_bool(sig_map.has(&"hud_toast_requested")).override_failure_message(
		"Events.hud_toast_requested not declared — required by SL-007"
	).is_true()

	if not sig_map.has(&"hud_toast_requested"):
		return

	# Assert — signature: (toast_id: StringName, payload: Dictionary)
	var args: Array = sig_map[&"hud_toast_requested"]["args"]
	assert_int(args.size()).is_equal(2)
	# TYPE_STRING_NAME = 21, TYPE_DICTIONARY = 27
	assert_int(args[0]["type"]).is_equal(TYPE_STRING_NAME)
	assert_int(args[1]["type"]).is_equal(TYPE_DICTIONARY)
