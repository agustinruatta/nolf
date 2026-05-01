# res://src/core/signal_bus/subscriber_template.gd
#
# SubscriberTemplate — canonical reference pattern for any system that subscribes
# to `Events.*` signals. Every consumer epic's subscribers MUST follow this
# pattern. ADR-0002 §Implementation Guideline 3 (lifecycle) + IG 4 (validity).
#
# THE PATTERN (non-negotiable):
#
#   1. Connect ONCE in `_ready()` — single connect per signal subscribed.
#   2. Disconnect ONCE in `_exit_tree()` with an `is_connected` guard so a
#      re-entrant `_exit_tree` (Godot can call it twice during free) doesn't
#      raise "callable was not connected" errors.
#   3. Every Node-typed signal payload MUST be checked with
#      `is_instance_valid(node)` before any property/method access. Signals
#      can be queued and the source Node may be freed before the subscriber
#      runs. Dereferencing a freed Node crashes Godot.
#
# This file is a DOCUMENTED REFERENCE — it is NOT autoloaded. Consumer epics
# either:
#   (a) `extends SubscriberTemplate` to inherit the lifecycle bookkeeping, or
#   (b) copy the pattern verbatim into their own `extends Node` script.
#
# Story SB-004. ADR-0002 IG 3 + IG 4 + Core Rule 4. GDD signal-bus.md AC 7/8/12.

class_name SubscriberTemplate
extends Node

# ── Lifecycle ──────────────────────────────────────────────────────────────

## Connect to Events signals here. ADR-0002 IG 3: `_ready()` is the canonical
## connection site. Connecting elsewhere risks (a) connecting before the
## autoload is fully initialised, (b) double-connection on re-add to tree.
##
## Override in subclasses; subclasses should chain `super._ready()` if they
## want template-level connections. The base template subscribes to
## `Events.player_damaged` as the canonical example.
func _ready() -> void:
	Events.player_damaged.connect(_on_player_damaged)


## Disconnect on tree exit. ADR-0002 IG 3: the `is_connected` guard is REQUIRED
## because Godot may call `_exit_tree()` more than once during a Node's free
## sequence (e.g. once on remove_child, once on queue_free flush). Without the
## guard, the second call raises "Signal Object.disconnect: Nothing connected
## to signal."
##
## Override in subclasses; subclasses should chain `super._exit_tree()`.
func _exit_tree() -> void:
	if Events.player_damaged.is_connected(_on_player_damaged):
		Events.player_damaged.disconnect(_on_player_damaged)


# ── Handlers ───────────────────────────────────────────────────────────────

## Canonical handler showing the validity guard pattern (ADR-0002 IG 4).
##
## `source` is a `Node`-typed payload — the dispatcher (CombatSystemNode in
## this case) emits the signal then may immediately queue_free the source on
## the same tick. By the time this handler runs (synchronous emit OR deferred
## connect), `source` may be a freed reference. Always guard before deref.
##
## Override in subclasses to do real work; the base implementation is a no-op
## that demonstrates the guard idiom.
func _on_player_damaged(_amount: float, source: Node, _is_critical: bool) -> void:
	# IG 4 guard. `source` may be null (no source — environmental damage)
	# OR may be a freed Node (source killed before handler runs).
	# `is_instance_valid(null)` returns false, covering both cases.
	if not is_instance_valid(source):
		return
	# Real subscribers do work here — read source.global_position, source.team,
	# etc. Anything that DEREFERENCES `source` MUST be after the guard.
	# (Base template intentionally does nothing.)


## Reference handler for enemy_damaged showing the pattern with TWO Node-typed
## params. Each Node-typed param needs its own `is_instance_valid` check —
## one may be valid while the other is freed.
##
## Not auto-connected; subclasses that need this signal connect it themselves
## (override `_ready()` and call super, then add their connection).
func _on_enemy_damaged(enemy: Node, _amount: float, source: Node) -> void:
	# Each Node param gets its own guard. Returning early on either invalid
	# value is the simplest correct policy; subscribers that need partial
	# behaviour (e.g. log enemy death even with unknown source) handle that
	# explicitly with separate is_instance_valid checks per param.
	if not is_instance_valid(enemy) or not is_instance_valid(source):
		return
	# Real subscribers act on `enemy` and `source` here.
