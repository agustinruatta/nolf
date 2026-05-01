# tests/fixtures/stub_interactable.gd
#
# StubInteractable — minimal fixture for PC-005 interact resolver tests.
# Implements get_interact_priority() so it satisfies the resolver's contract.
# Test-only — never used in production code.

class_name StubInteractable
extends StaticBody3D

var priority: int = 0

func get_interact_priority() -> int:
	return priority
