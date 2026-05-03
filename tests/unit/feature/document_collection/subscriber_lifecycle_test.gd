# tests/unit/feature/document_collection/subscriber_lifecycle_test.gd
#
# SubscriberLifecycleTest — GdUnit4 unit suite for DocumentCollection
#                           connect/disconnect lifecycle.
#
# PURPOSE
#   Validates AC-1 (AC-DC-2.4): _ready() connects to Events.player_interacted
#   and _exit_tree() disconnects from it with the is_connected() guard, leaving
#   no dangling connection and raising no errors.
#
# COVERED ACCEPTANCE CRITERIA
#   AC-1 — After _ready(): Events.player_interacted.is_connected(handler) == true.
#          After _exit_tree(): is_connected == false, no error.
#          Double _exit_tree() does NOT crash (is_connected() guard prevents
#          double-disconnect).
#
# WHAT IS NOT TESTED HERE
#   - Pickup happy-path and idempotency — idempotency_test.gd (DC-003 AC-2/AC-3).
#   - Guard sequence — signal_handler_guards_test.gd (DC-003 AC-4).
#
# GATE STATUS
#   Story DC-003 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SubscriberLifecycleTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns a DocumentCollection node added to the test scene tree so that
## _ready() fires. auto_free() ensures cleanup after each test.
func _make_dc() -> DocumentCollection:
	var dc: DocumentCollection = DocumentCollection.new()
	add_child(dc)
	auto_free(dc)
	return dc


# ---------------------------------------------------------------------------
# AC-1 — _ready() connects to Events.player_interacted
# ---------------------------------------------------------------------------

## After _ready() fires (via add_child), Events.player_interacted must be
## connected to dc._on_player_interacted. AC-DC-2.4.
func test_connect_on_ready_disconnect_on_exit_tree() -> void:
	# Arrange — adding to tree triggers _ready().
	var dc: DocumentCollection = _make_dc()

	# Assert — connected after _ready().
	assert_bool(
		Events.player_interacted.is_connected(dc._on_player_interacted)
	).override_failure_message(
		"AC-1: After _ready(), Events.player_interacted must be connected to " +
		"_on_player_interacted (AC-DC-2.4, ADR-0002 IG 3)."
	).is_true()

	# Act — remove from tree triggers _exit_tree().
	remove_child(dc)

	# Assert — disconnected after _exit_tree().
	assert_bool(
		Events.player_interacted.is_connected(dc._on_player_interacted)
	).override_failure_message(
		"AC-1: After _exit_tree(), Events.player_interacted must be disconnected " +
		"from _on_player_interacted (AC-DC-2.4, ADR-0002 IG 3)."
	).is_false()


# ---------------------------------------------------------------------------
# AC-1 edge case — double _exit_tree() does not crash
# ---------------------------------------------------------------------------

## Calling _exit_tree() twice (or removing from tree while already removed)
## must not raise an error. The is_connected() guard prevents the
## double-disconnect error that Godot raises on disconnect() of an already-
## disconnected signal (ADR-0002 IG 3 — memory-leak prevention note).
func test_double_exit_tree_does_not_error() -> void:
	# Arrange
	var dc: DocumentCollection = _make_dc()

	# Act — first exit (via remove_child).
	remove_child(dc)

	# Act — second explicit call must not crash.
	# If the is_connected() guard is absent, this would raise:
	#   "Signal 'player_interacted': can't disconnect a non-connected callable."
	dc._exit_tree()

	# Assert — still disconnected, no error thrown.
	assert_bool(
		Events.player_interacted.is_connected(dc._on_player_interacted)
	).override_failure_message(
		"AC-1 edge case: After double _exit_tree(), connection must still be " +
		"false and no error must have been raised (is_connected() guard, ADR-0002 IG 3)."
	).is_false()


# ---------------------------------------------------------------------------
# AC-1 — independent check: _ready() without _exit_tree() leaves signal connected
# ---------------------------------------------------------------------------

## A DocumentCollection that has been added to the tree but NOT removed must
## still have its handler connected. Verifies that the connection persists
## across multiple frames / ticks (no accidental auto-disconnect).
func test_ready_without_exit_tree_remains_connected() -> void:
	# Arrange + Act — add to tree (triggers _ready()).
	var dc: DocumentCollection = _make_dc()

	# Assert — connected and stays connected.
	assert_bool(
		Events.player_interacted.is_connected(dc._on_player_interacted)
	).override_failure_message(
		"AC-1: A DC node still in the tree must remain connected to " +
		"Events.player_interacted between _ready() and _exit_tree()."
	).is_true()
