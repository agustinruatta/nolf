# res://src/core/ui/input_context.gd
#
# InputContext autoload — modal input-routing context stack. Per ADR-0004
# (UI Framework — Theme + InputContext + FontRegistry) + ADR-0007 §Key
# Interfaces (autoload line 4, after Events / EventLogger / SaveLoad).
#
# Push/pop a Context enum to direct gameplay vs modal input routing. Every
# push and every pop emits Events.ui_context_changed(new_ctx_int, old_ctx_int)
# per ADR-0002's 2026-04-28 UI domain amendment. Payload is `int` (cast from
# Context) to avoid Events↔InputContextStack circular import — same pattern
# as SaveLoadService.FailureReason → save_failed.
#
# class_name / autoload-key split (mirrors Events/SignalBusEvents,
# EventLogger/SignalBusEventLogger, SaveLoad/SaveLoadService precedents):
#   class_name = InputContextStack  (used for parse-time enum references:
#                                    InputContextStack.Context.MENU)
#   autoload key = InputContext     (used at call sites: InputContext.push)
#
# Cross-Autoload Reference Safety per ADR-0007: _init() references no other
# autoloads. _ready() may reference autoloads at lines 1–3 only (Events,
# EventLogger, SaveLoad). InputActions is NOT an autoload — it is a static
# class loaded via class_name; calling InputActions._register_debug_actions()
# from _ready() does not violate the cross-autoload rule.
#
# FORBIDDEN: this autoload emits no signals directly — it always routes
# through Events. ADR-0004 IG 2 + Control Manifest Core layer rule.

class_name InputContextStack
extends Node

## Input-routing context. Each value has exactly one authorised pusher and
## popper per ADR-0004 IG 13 (push/pop authority table). InputContextStack
## itself only manages stack mechanics — it does NOT push/pop on behalf of
## other systems.
enum Context {
	GAMEPLAY,
	MENU,
	DOCUMENT_OVERLAY,
	PAUSE,
	SETTINGS,
	MODAL,
	LOADING,
}

## Stack invariant: never empty; always starts with GAMEPLAY at index 0.
## ADR-0004 IG 12: pop() with single-element stack fires assert (never pop
## the base GAMEPLAY context).
var _stack: Array[Context] = [Context.GAMEPLAY]


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Debug actions (debug_toggle_ai, debug_noclip, debug_spawn_alert) are
	# runtime-registered in debug builds only. InputActions is a static class
	# (not an autoload), so this call does not violate ADR-0007 §Cross-Autoload
	# Reference Safety. AC-INPUT-5.3 verifies debug actions are absent from
	# project.godot and present after this call in debug builds.
	if OS.is_debug_build():
		InputActions._register_debug_actions()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Push a new context onto the stack. Emits Events.ui_context_changed
## with the new context (top of stack) and the previous context.
func push(ctx: Context) -> void:
	var old_ctx: Context = current()
	_stack.push_back(ctx)
	Events.ui_context_changed.emit(ctx, old_ctx)


## Pop the current context. NEVER pops the base GAMEPLAY context — fires an
## assert on empty-stack pop attempt per ADR-0004 IG 12. Emits
## Events.ui_context_changed with (new_ctx_after_pop, old_ctx_being_popped).
func pop() -> void:
	assert(_stack.size() > 1, "InputContext stack underflow — never pop GAMEPLAY")
	var old_ctx: Context = _stack.pop_back()
	Events.ui_context_changed.emit(current(), old_ctx)


## Returns the currently active context (top of stack).
func current() -> Context:
	return _stack.back()


## Returns true if the given context is currently at the top of the stack.
## Modal handlers use this to gate their _unhandled_input early-return.
func is_active(ctx: Context) -> bool:
	return current() == ctx
