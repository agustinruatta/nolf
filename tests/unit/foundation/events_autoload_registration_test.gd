# tests/unit/foundation/events_autoload_registration_test.gd
#
# Autoload registration test — Events and EventLogger presence + order.
#
# PURPOSE
#   Proves that the Events autoload is present in the scene tree at the
#   position declared by ADR-0007 (line 1, before EventLogger at line 2),
#   and that it is of the expected type (SignalBusEvents).
#
# WHAT IS TESTED
#   AC-1: Events is a child of root, is of type SignalBusEvents, and its
#         index in root.get_children() precedes EventLogger's index.
#
# WHAT IS NOT TESTED HERE
#   - Signal purity / structural correctness (see events_purity_test.gd).
#   - Signal emission / delivery (see signal_bus_smoke_test.gd).
#
# IMPLEMENTATION NOTE
#   GdUnit4's test runner adds the test scene under the autoloads, so all
#   project autoloads are already present in the tree when the test runs.
#   No manual node setup is required.
#
# GATE STATUS
#   Story SB-001 — Logic type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name EventsAutoloadRegistrationTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Tests — AC-1: Autoload registration + order
# ---------------------------------------------------------------------------

## Events must be a direct child of the scene root and of type SignalBusEvents.
## Covers ADR-0007 §Key Interfaces: Events at line 1, *res:// scene-mode.
func test_events_autoload_is_registered_and_correct_type() -> void:
	# Arrange + Act
	var events_node: Node = get_tree().root.get_node_or_null(^"Events")

	# Assert — node must exist and be the correct type
	assert_object(events_node).is_not_null()
	assert_bool(events_node is SignalBusEvents).is_true()


## Events index in root.get_children() must precede EventLogger's index.
## Covers ADR-0007 §Canonical Registration Table: Events(1) before EventLogger(2).
func test_events_autoload_registered_at_line_one() -> void:
	# Arrange
	var root_children: Array[Node] = get_tree().root.get_children()

	var events_index: int = -1
	var event_logger_index: int = -1

	for i: int in range(root_children.size()):
		var child: Node = root_children[i]
		if child.name == &"Events":
			events_index = i
		elif child.name == &"EventLogger":
			event_logger_index = i

	# Act + Assert — both must be found, and Events must appear first
	assert_int(events_index).is_not_equal(-1)
	assert_int(event_logger_index).is_not_equal(-1)
	assert_bool(events_index < event_logger_index).is_true()
