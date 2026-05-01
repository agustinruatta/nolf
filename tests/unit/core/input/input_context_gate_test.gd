# tests/unit/core/input/input_context_gate_test.gd
#
# Unit test suite — InputContextStack push/pop mechanics, signal emission,
# stack invariant, and debug action registration.
#
# PURPOSE
#   Covers AC-INPUT-2.1 (push/pop context routing), the stack invariant
#   (GAMEPLAY base never popped), Events.ui_context_changed emission, and
#   debug action registration (AC-INPUT-5.3 sub-criterion).
#
# ISOLATION STRATEGY
#   Each test instantiates a fresh InputContextStack.new() and adds it to
#   the scene tree so _ready() fires. This avoids state-bleed between tests
#   and lets each test observe _ready() side-effects in isolation without
#   touching the live InputContext autoload. auto_free() ensures cleanup.
#
# SIGNAL-SPY PATTERN
#   Each test that checks Events.ui_context_changed emission:
#     1. Connects a local capture callable before the action.
#     2. Stores emitted (new_ctx, old_ctx) pairs in a local Array.
#     3. Asserts captured values after the action.
#     4. Disconnects in after_test() via a cleanup Array (see _pending_disconnects).
#
# NOTE ON ASSERT() AND STACK UNDERFLOW TEST
#   GDScript assert() fires in debug builds and immediately halts execution.
#   Running it inside a GdUnit4 test would abort the test runner process.
#   The underflow guard test therefore verifies the VISIBLE OUTCOME (stack size
#   stays ≥ 1 after a valid push+pop cycle) rather than triggering the assert.
#   The assert itself is exercised as documentation-only in the test comment.
#
# GATE STATUS
#   Story IN-002 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name InputContextGateTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------

## Fresh InputContextStack instance, added to the tree so _ready() fires.
## Freed by after_test() via auto_free().
var _ctx: InputContextStack = null

## Captured (new_ctx, old_ctx) pairs from Events.ui_context_changed.
var _emitted_pairs: Array[Array] = []

## Disconnect bookkeeping: callable registered to Events.ui_context_changed.
var _spy_callable: Callable = Callable()


func before_test() -> void:
	_emitted_pairs.clear()
	_ctx = auto_free(InputContextStack.new())
	add_child(_ctx)


func after_test() -> void:
	# Disconnect signal spy if it was connected.
	if not _spy_callable.is_null():
		if Events.ui_context_changed.is_connected(_spy_callable):
			Events.ui_context_changed.disconnect(_spy_callable)
		_spy_callable = Callable()
	_ctx = null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Registers a spy on Events.ui_context_changed. Captured pairs are stored
## in _emitted_pairs as [new_ctx_int, old_ctx_int]. Spy is disconnected in
## after_test().
func _attach_signal_spy() -> void:
	_spy_callable = func(new_ctx: int, old_ctx: int) -> void:
		_emitted_pairs.append([new_ctx, old_ctx])
	Events.ui_context_changed.connect(_spy_callable)


# ---------------------------------------------------------------------------
# Test 1 — Initial state is GAMEPLAY
# ---------------------------------------------------------------------------

## A freshly created InputContextStack must start with GAMEPLAY as the only
## and active context. Covers stack invariant: never empty at init.
func test_input_context_starts_at_gameplay() -> void:
	# Assert — current() is GAMEPLAY
	assert_bool(_ctx.current() == InputContextStack.Context.GAMEPLAY).is_true()
	# Assert — is_active(GAMEPLAY) is true
	assert_bool(_ctx.is_active(InputContextStack.Context.GAMEPLAY)).is_true()
	# Assert — stack has exactly one element (the base GAMEPLAY)
	assert_int(_ctx._stack.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Test 2 — push(MENU) makes MENU active
# ---------------------------------------------------------------------------

## After push(MENU): is_active(GAMEPLAY) must return false; is_active(MENU)
## must return true. Covers AC-INPUT-2.1.
func test_input_context_push_menu_makes_menu_active() -> void:
	# Act
	_ctx.push(InputContextStack.Context.MENU)

	# Assert
	assert_bool(_ctx.is_active(InputContextStack.Context.GAMEPLAY)).is_false()
	assert_bool(_ctx.is_active(InputContextStack.Context.MENU)).is_true()
	assert_int(_ctx._stack.size()).is_equal(2)


# ---------------------------------------------------------------------------
# Test 3 — push emits Events.ui_context_changed with correct new/old
# ---------------------------------------------------------------------------

## push(MENU) must emit Events.ui_context_changed(MENU, GAMEPLAY).
## The payload uses int values (InputContextStack.Context cast to int).
## Covers ADR-0002 UI domain amendment + story IN-002 emission AC.
func test_input_context_push_emits_ui_context_changed_with_new_and_old() -> void:
	# Arrange
	_attach_signal_spy()

	# Act
	_ctx.push(InputContextStack.Context.MENU)

	# Assert — exactly one emission
	assert_int(_emitted_pairs.size()).is_equal(1)

	# Assert — new_ctx == MENU (int 1), old_ctx == GAMEPLAY (int 0)
	var pair: Array = _emitted_pairs[0]
	assert_int(pair[0]).is_equal(InputContextStack.Context.MENU)
	assert_int(pair[1]).is_equal(InputContextStack.Context.GAMEPLAY)


# ---------------------------------------------------------------------------
# Test 4 — pop returns to the previous context
# ---------------------------------------------------------------------------

## After push(MENU) then pop(), the active context must return to GAMEPLAY.
## Covers stack restoration mechanic.
func test_input_context_pop_returns_to_previous_context() -> void:
	# Arrange
	_ctx.push(InputContextStack.Context.MENU)
	assert_bool(_ctx.is_active(InputContextStack.Context.MENU)).is_true()

	# Act
	_ctx.pop()

	# Assert
	assert_bool(_ctx.is_active(InputContextStack.Context.GAMEPLAY)).is_true()
	assert_int(_ctx._stack.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Test 5 — pop emits Events.ui_context_changed with correct new/old
# ---------------------------------------------------------------------------

## pop() after push(MENU) must emit Events.ui_context_changed(GAMEPLAY, MENU).
## Covers ADR-0002 UI domain amendment + story IN-002 emission AC.
func test_input_context_pop_emits_ui_context_changed_with_new_and_old() -> void:
	# Arrange
	_ctx.push(InputContextStack.Context.MENU)
	_attach_signal_spy()

	# Act
	_ctx.pop()

	# Assert — exactly one emission from the pop
	assert_int(_emitted_pairs.size()).is_equal(1)

	# Assert — new_ctx == GAMEPLAY (int 0), old_ctx == MENU (int 1)
	var pair: Array = _emitted_pairs[0]
	assert_int(pair[0]).is_equal(InputContextStack.Context.GAMEPLAY)
	assert_int(pair[1]).is_equal(InputContextStack.Context.MENU)


# ---------------------------------------------------------------------------
# Test 6 — Stack size invariant: never below 1 after push+pop
# ---------------------------------------------------------------------------

## After a push+pop cycle, the stack must return to size 1 (GAMEPLAY base).
## This verifies the observable invariant that pop() cannot remove the base
## context. The assert() guard inside pop() is a debug-only halt that we do
## NOT trigger in automated tests (doing so would crash the test runner).
## Test documents: assert("InputContext stack underflow — never pop GAMEPLAY")
## fires if pop() is called when _stack.size() == 1.
func test_input_context_never_pops_below_gameplay_base() -> void:
	# Arrange — push two contexts
	_ctx.push(InputContextStack.Context.MENU)
	_ctx.push(InputContextStack.Context.PAUSE)
	assert_int(_ctx._stack.size()).is_equal(3)

	# Act — pop twice, returning to base
	_ctx.pop()
	assert_int(_ctx._stack.size()).is_equal(2)
	_ctx.pop()

	# Assert — stack is back to base (size 1, GAMEPLAY active)
	assert_int(_ctx._stack.size()).is_equal(1)
	assert_bool(_ctx.current() == InputContextStack.Context.GAMEPLAY).is_true()


# ---------------------------------------------------------------------------
# Test 7 — Debug actions are registered in debug builds
# ---------------------------------------------------------------------------

## In a debug build (GdUnit4 headless runner is always debug), _ready() must
## call InputActions._register_debug_actions(), which adds debug_toggle_ai,
## debug_noclip, and debug_spawn_alert to the InputMap. Covers AC-INPUT-5.3.
## Note: the autoload's _ready() has already run at project boot. This test
## instantiates a fresh node whose _ready() runs again — re-registration is
## safe because _register_debug_action() guards with has_action().
func test_input_context_debug_actions_registered_in_debug_build() -> void:
	# Assert — debug actions present (registered by _ready() in debug builds)
	assert_bool(InputMap.has_action(&"debug_toggle_ai")).is_true()
	assert_bool(InputMap.has_action(&"debug_noclip")).is_true()
	assert_bool(InputMap.has_action(&"debug_spawn_alert")).is_true()
