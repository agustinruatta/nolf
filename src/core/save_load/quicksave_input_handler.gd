# res://src/core/save_load/quicksave_input_handler.gd
#
# QuicksaveInputHandler — companion Node added as a child of the SaveLoad
# autoload (line 3) by SaveLoadService._ready(). Handles F5 / F9 key events
# via _unhandled_input, gating them through InputContext (line 4) and a
# debounce timer before forwarding to SaveLoad.save_to_slot / load_from_slot.
#
# Why a child Node and not inlined in SaveLoadService._ready()?
# ADR-0007 §Cross-Autoload Reference Safety rule 3: a line-3 autoload's
# _ready() MUST NOT reference line-4 (InputContext). This Node defers any
# InputContext query until _unhandled_input fires — guaranteed post tree-init.
#
# Consumed signals on success / no-slot:
#   Events.hud_toast_requested(&"quicksave_success",     {"slot": 0})
#   Events.hud_toast_requested(&"quicksave_unavailable", {})
#
# Reference: Story SL-007, ADR-0003, ADR-0004, ADR-0007.

class_name QuicksaveInputHandler
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Minimum milliseconds between two consecutive SUCCESSFUL quicksaves.
## A second F5 press within this window after a successful save is dropped.
## Prevents rapid duplicate saves from F5 key-repeat. GDD §Tuning Knobs.
## AC-8: only successful saves update the debounce clock — failed / gated
## presses do NOT advance the window.
const QUICKSAVE_DEBOUNCE_MS: int = 500

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Timestamp of the last SUCCESSFUL quicksave in milliseconds. Initialised
## far in the past so the first F5 press is never debounced.
var _last_quicksave_msec: int = -100_000

## Injectable clock callable for deterministic test control. Production code
## uses Time.get_ticks_msec(); test code overrides via set_debounce_clock().
## Signature: func() -> int.
var _debounce_clock: Callable = func() -> int: return Time.get_ticks_msec()

## Injectable SaveGame assembler callable for deterministic test control.
## Production code returns null (caller provides real game state); test code
## overrides via set_assembler() with a stub that returns a valid SaveGame.
## Signature: func() -> SaveGame.
## Returning null from the assembler aborts the quicksave silently (no toast,
## no signal) — the assembler is responsible for any error feedback.
var _assembler: Callable = func() -> SaveGame: return null


# ---------------------------------------------------------------------------
# Dependency injection (test seams)
# ---------------------------------------------------------------------------

## Override the clock used for debounce calculations.
## Call from test setup to control time deterministically.
##
## Usage example (test):
##   var t: int = 0
##   handler.set_debounce_clock(func() -> int: return t)
##   t = 600  # fast-forward past debounce window
func set_debounce_clock(clock: Callable) -> void:
	_debounce_clock = clock


## Override the SaveGame assembler.
## Call from test setup to inject a stub SaveGame without a live game scene.
##
## Usage example (test):
##   handler.set_assembler(func() -> SaveGame: return SaveGame.new())
func set_assembler(assembler: Callable) -> void:
	_assembler = assembler


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

## Intercepts F5 (quicksave) and F9 (quickload) before other handlers see them.
## Per ADR-0004: set_input_as_handled() prevents the event from propagating to
## other subscribers (e.g., debug menus that might also bind F-keys).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.QUICKSAVE):
		_try_quicksave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.QUICKLOAD):
		_try_quickload()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Private — quicksave path
# ---------------------------------------------------------------------------

## Attempt a quicksave.
##
## Gate order:
##   1. InputContext gate — save-eligible contexts: GAMEPLAY, MENU, PAUSE.
##      Any other context results in a silent no-op (GDD CR-6, 2026-04-28).
##   2. Debounce — suppress if within QUICKSAVE_DEBOUNCE_MS of last SUCCESS.
##   3. Delegate to LevelStreamingService.queue_quicksave_or_fire() (Story LS-007).
##      If a transition is in flight, LSS queues the save for step-13 drain.
##      If IDLE, LSS fires SaveLoad.save_to_slot(0, ...) immediately via its
##      own _assemble_quicksave_payload() stub (Mission Scripting epic provides
##      the production assembler). SaveLoad emits Events.game_saved on success.
##
## Note: the injected `_assembler` field is retained for test backward-compat
## but is no longer called from this path — LSS owns the assembly. Tests that
## exercise the direct-save path should call queue_quicksave_or_fire() via LSS.
func _try_quicksave() -> void:
	# Gate 1 — InputContext (line 4 autoload — safe at _unhandled_input time).
	var ctx: InputContextStack.Context = InputContext.current()
	if not _is_save_eligible(ctx):
		return  # Silent no-op per GDD CR-6 / AC-2, AC-3, AC-4, AC-5.

	# Gate 2 — Debounce. Only count elapsed time against the last SUCCESSFUL
	# save so that a string of gated/failed presses does not reset the window.
	var now_msec: int = _debounce_clock.call()
	if now_msec - _last_quicksave_msec < QUICKSAVE_DEBOUNCE_MS:
		return  # Silent no-op per AC-8.

	# Step 3 — Delegate to LSS (Story LS-007 AC-9). LSS handles both the IDLE
	# (fire-now) and in-transition (queue) paths transparently. The debounce
	# clock is updated here regardless of whether LSS fires immediately or
	# queues — accepting the intent is sufficient to reset the window.
	_last_quicksave_msec = now_msec
	LevelStreamingService.queue_quicksave_or_fire()


# ---------------------------------------------------------------------------
# Private — quickload path
# ---------------------------------------------------------------------------

## Attempt a quickload.
##
## Gate order:
##   1. InputContext gate — same save-eligible contexts (GAMEPLAY, MENU, PAUSE).
##      Any other context results in a silent no-op (same CR-6 rule as quicksave).
##   2. Slot existence check. If slot 0 is empty, emit unavailable toast (AC-6).
##   3. Call SaveLoad.load_from_slot(0). The service emits game_loaded on success
##      (AC-7). Callers (Mission Scripting) handle scene transition + duplicate_deep.
func _try_quickload() -> void:
	# Gate 1 — InputContext gate. Same save-eligible set as quicksave.
	var ctx: InputContextStack.Context = InputContext.current()
	if not _is_save_eligible(ctx):
		return  # Silent no-op.

	# Gate 2 — Slot existence (AC-6: emit unavailable toast if slot 0 is empty).
	if not SaveLoad.slot_exists(0):
		Events.hud_toast_requested.emit(&"quicksave_unavailable", {})
		return

	# Step 3 — Load. load_from_slot emits game_loaded on success (AC-7).
	# Caller applies duplicate_deep per ADR-0003 IG 3.
	var _sg: SaveGame = SaveLoad.load_from_slot(0)
	# Result is intentionally unused here — downstream systems react to the
	# game_loaded signal. If load returns null, save_failed was already emitted
	# by the service (Story SL-003 protocol).


# ---------------------------------------------------------------------------
# Private — helpers
# ---------------------------------------------------------------------------

## Returns true if the given context permits quicksave / quickload.
## Save-eligible contexts (GDD CR-6, extended 2026-04-28):
##   GAMEPLAY, MENU, PAUSE.
## All others (DOCUMENT_OVERLAY, SETTINGS, MODAL, LOADING) are blocked.
## Note: CUTSCENE does not exist in InputContextStack.Context as of Godot 4.6
## project configuration — SETTINGS is the analogous non-save context used in
## SL-007 AC-2 substitution (see Completion Notes).
func _is_save_eligible(ctx: InputContextStack.Context) -> bool:
	return (
		ctx == InputContextStack.Context.GAMEPLAY
		or ctx == InputContextStack.Context.MENU
		or ctx == InputContextStack.Context.PAUSE
	)
