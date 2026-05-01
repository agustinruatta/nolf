# tests/unit/core/input/input_context_autoload_load_order_test.gd
#
# Unit test suite — InputContext autoload load-order and initial state.
#
# PURPOSE
#   Verifies AC-INPUT-9.2: the InputContext autoload node resolves at
#   /root/InputContext, is an InputContextStack instance, and starts with
#   GAMEPLAY as the active context. These tests use the LIVE autoload (not
#   a fresh instance) to prove the project.godot [autoload] configuration
#   is correct.
#
# COVERAGE
#   AC-INPUT-9.2 [Logic] BLOCKING — autoload resolves from scene tree.
#
# GATE STATUS
#   Story IN-002 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name InputContextAutoloadLoadOrderTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Test 1 — Autoload resolves at /root/InputContext
# ---------------------------------------------------------------------------

## The InputContext autoload must be present at /root/InputContext per ADR-0007
## §Key Interfaces line 4. Covers AC-INPUT-9.2.
func test_input_context_autoload_resolves_at_root() -> void:
	# Arrange + Act
	var node: Node = get_tree().root.get_node_or_null(^"InputContext")

	# Assert — node is present
	assert_object(node).is_not_null()

	# Assert — node is an InputContextStack instance
	# (autoload key/class_name split: key = InputContext, class = InputContextStack)
	assert_bool(node is InputContextStack).is_true()


# ---------------------------------------------------------------------------
# Test 2 — Initial context is GAMEPLAY
# ---------------------------------------------------------------------------

## The live InputContext autoload must start (and at test time remain) at
## GAMEPLAY. Covers stack invariant + AC-INPUT-9.2 initial state assertion.
## Note: other tests use isolated instances to avoid mutating this autoload.
func test_input_context_initial_context_is_gameplay() -> void:
	# Arrange
	var node: InputContextStack = get_tree().root.get_node_or_null(^"InputContext") as InputContextStack
	assert_object(node).is_not_null()

	# Assert — current() returns GAMEPLAY
	assert_bool(node.current() == InputContextStack.Context.GAMEPLAY).is_true()

	# Assert — is_active(GAMEPLAY) returns true
	assert_bool(node.is_active(InputContextStack.Context.GAMEPLAY)).is_true()
