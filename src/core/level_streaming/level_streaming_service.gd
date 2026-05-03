# res://src/core/level_streaming/level_streaming_service.gd
#
# LevelStreamingService — section/level swap orchestration autoload.
#
# Story LS-001 SCAFFOLD — provides the autoload entry, TransitionReason enum,
# SectionRegistry loader, persistent fade overlay (CanvasLayer 127), and
# ErrorFallback layer (CanvasLayer 126) that survive scene swaps.
#
# The 13-step section-swap state machine landed in Story LS-002.
# The register_restore_callback chain (step 9 synchronous invocation) landed
# in Story LS-003.
# Concurrency control (forward-drop, respawn-queue, abort recovery) landed in
# Story LS-004.
# Registry failure paths, _simulate_registry_failure test hook, and
# _show_error_fallback recovery helper landed in Story LS-005.
# F5/F9 quicksave/quickload queue during transition landed in Story LS-007.
# CR-13 sync-subscriber violation detection (step-3 frame-counter check) landed
# in Story LS-009.
# VERBOSE_TRANSITION_LOGGING + _step_timings instrumentation landed in Story LS-010.
#
# Autoload position: line 5 (after Events 1, EventLogger 2, SaveLoad 3,
# InputContext 4) per ADR-0007 §Key Interfaces. `_ready()` may safely reference
# autoloads at lines 1–4 only (Cross-Autoload Reference Safety rule 2).
#
# Implements: Story LS-001 (autoload boot + fade overlay scaffold)
#             Story LS-002 (13-step section-swap coroutine)
#             Story LS-003 (register_restore_callback chain + step 9 sync invocation)
#             Story LS-004 (concurrency control: forward-drop, respawn-queue, abort recovery)
#             Story LS-005 (registry failure paths + ErrorFallback CanvasLayer recovery)
#             Story LS-006 (same-section guard, CACHE_MODE_REUSE, evict stub, focus-loss handling)
#             Story LS-007 (F5/F9 quicksave/quickload queue during transition)
#             Story LS-009 (anti-pattern fences + CR-13 sync-subscriber detection)
#             Story LS-010 (VERBOSE_TRANSITION_LOGGING + _step_timings + perf budget verification)
# Requirements: TR-LS-001, TR-LS-002, TR-LS-003, TR-LS-004, TR-LS-006, TR-LS-010, TR-LS-011,
#               TR-LS-012, TR-LS-013, TR-LS-014
# GDD: design/gdd/level-streaming.md §Detailed Design CR-1, CR-2, CR-3, CR-5, CR-6, CR-8,
#      CR-9, CR-11, CR-13, CR-14, CR-15
# ADRs: ADR-0007 (Autoload Load Order Registry), ADR-0003 (Save Format Contract)

extends Node


# ── Constants ─────────────────────────────────────────────────────────────

## When true, `_log_step` records each step's timestamp to `_step_timings`
## and prints a console line.  Set to false in ship builds to eliminate all
## per-step allocation and print overhead with a single flag change.
## Story LS-010 | AC-1 | TR-LS-011.
const VERBOSE_TRANSITION_LOGGING_ENABLED: bool = true


# ── Public types ───────────────────────────────────────────────────────────

## Reason a transition was initiated. Payload param on
## `Events.section_entered` and `Events.section_exited` (per ADR-0002 §Cutscenes
## & Mission Cards amendment 2026-04-22).
enum TransitionReason {
	FORWARD,         # Normal forward progression (mission tick)
	RESPAWN,         # Failure-respawn: load last manual save into same section
	NEW_GAME,        # Boot a fresh new-game session (initial section load)
	LOAD_FROM_SAVE,  # Player loaded a save slot from menu
}


## Internal state machine for the 13-step section swap. Story LS-002.
## Transition flow: IDLE → FADING_OUT → SWAPPING → FADING_IN → IDLE.
enum State {
	IDLE,         # No transition in flight
	FADING_OUT,   # Steps 1-2: pushing LOADING + snapping overlay 0→1
	SWAPPING,    # Steps 3-9: emit section_exited, free outgoing, load+instantiate, add to tree, await frame, restore callbacks
	FADING_IN,    # Steps 10-12: emit section_entered, snapping overlay 1→0, pop LOADING
}


# ── Private state ──────────────────────────────────────────────────────────

## SectionRegistry instance loaded from `res://assets/data/section_registry.tres`
## at `_ready()`. Null when load fails (see `_registry_valid`).
var _registry: SectionRegistry = null

## True when `_registry` was loaded successfully and is a SectionRegistry.
## Read by Story LS-002's `transition_to_section` before dispatching; if false,
## that path push_errors and returns. Autoload boot is NOT halted on registry
## failure (per GDD §Edge Cases — halting cascades into ADR-0007 ordering).
var _registry_valid: bool = false

## Persistent CanvasLayer (layer 127) hosting the full-screen fade ColorRect.
## Parented to this autoload Node so it survives change_scene_to_file() per
## TR-LS-012. Story LS-002 animates the rect's alpha during section swaps.
var _fade_overlay: CanvasLayer = null

## ColorRect inside `_fade_overlay`, default fully transparent.
var _fade_rect: ColorRect = null

## Persistent CanvasLayer (layer 126) for the ErrorFallback scene. The scene
## is preloaded but NOT instantiated during normal play; `_abort_transition`
## (Story LS-005) instantiates it on transition failure.
var _error_fallback_layer: CanvasLayer = null

## Preloaded ErrorFallback scene. Mounting deferred to Story LS-005.
var _error_fallback_scene: PackedScene = null

## Story LS-002 state machine cursor.
var _state: State = State.IDLE

## True from `transition_to_section` entry until step 13 completes.
var _transitioning: bool = false

## The currently-active section_id. Updated at step 10 of the swap.
## Empty StringName indicates no section is active (boot state).
var _current_section_id: StringName = &""

## Pending respawn save_game queued during a transition (Story LS-004 owns
## the queue-drain at step 13). Story LS-002 leaves this as a stub field.
var _pending_respawn_save_game: SaveGame = null

## Pending quicksave flag queued during a transition (Story LS-007 owns the
## drain). Story LS-002 leaves this as a stub field.
var _pending_quicksave: bool = false

## Pending quickload slot queued during a transition (Story LS-007).
## -1 = no quickload pending. 0 = the quicksave slot (the only valid quickload
## target at MVP). Set by `queue_quickload_or_fire()` when called mid-transition;
## cleared at step 13 drain or by `_abort_transition`.
var _pending_quickload_slot: int = -1

## Ordered list of restore callbacks registered at autoload boot (Story LS-003).
## Each callable receives (target_section_id: StringName, save_game: SaveGame,
## reason: TransitionReason) and MUST return synchronously (no `await`).
## Registration order determines invocation order at step 9 of the swap.
## Deregistration is post-MVP; callbacks registered here live for the
## application lifetime.
var _restore_callbacks: Array[Callable] = []

## Last error message produced by a failure path in the 13-step coroutine.
## Written by `_show_error_fallback(message)` and read by ErrorFallback.tscn's
## `_ready()` to display the failure reason. Cleared to "" after a successful
## `transition_to_section` completes step 10 (section_entered emit). Story LS-005.
var _last_error_message: String = ""

## Per-transition step timestamps (µs) recorded by `_log_step`.
## Keys are step IDs (int); values are `Time.get_ticks_usec()` snapshots taken
## at each step entry.  Cleared at the beginning of every `_run_swap_sequence`
## call so that each transition starts with a fresh dictionary.
## Only populated when `VERBOSE_TRANSITION_LOGGING_ENABLED == true`.
## Consumed by `get_step_timings_for_test()` and the perf harness.
## Story LS-010 | AC-2 | TR-LS-011.
var _step_timings: Dictionary = {}


# ── Lifecycle ──────────────────────────────────────────────────────────────

## Story LS-001 boot sequence:
##   1. Build the persistent fade overlay (CanvasLayer 127 + ColorRect)
##   2. Build the persistent error-fallback layer (CanvasLayer 126) and preload
##      the ErrorFallback.tscn scene
##   3. Load section_registry.tres; set `_registry_valid` accordingly
##
## Story LS-005 adds: `_last_error_message` module field for ErrorFallback
## display; `_simulate_registry_failure()` test hook; `_show_error_fallback()`
## recovery helper. No boot-sequence changes.
##
## Cross-autoload reference safety: this `_ready()` must reference ONLY
## autoloads at lines 1–4 per ADR-0007 IG 4. Currently references none —
## the registry path is a literal `res://` URL, not an autoload accessor.
func _ready() -> void:
	# Autoload must keep processing while the SceneTree is paused so
	# NOTIFICATION_APPLICATION_FOCUS_IN can resume it (otherwise the
	# notification fires but the resume call sits behind a paused tree).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_overlay()
	_setup_error_fallback_layer()
	_load_registry()


## Story LS-006 focus-loss handling (CR-15, TR-LS-014).
##
## When the application regains focus while a transition is in flight, the
## SceneTree resumes (because `pause_on_focus_lost = true` in project.godot).
## Any coroutine that was mid-frame-await resumes from the next process frame.
## The fade overlay alpha may have been left at an intermediate value (e.g. 0.5
## from step 2's two-frame ramp) during the pause. This handler snaps it to the
## correct target value before the coroutine continues, eliminating the visible
## "alpha stalled at partial opacity" UX gap.
##
## On FADING_OUT or SWAPPING: snap to 1.0 (fully opaque — transition is dark).
## On FADING_IN: snap to 0.0 (transitional; the fade-in ramp will overwrite
##   this immediately as it resumes from its own await, so the player sees a
##   seamless fade-in rather than a flash of white/black).
## On IDLE: snap to 0.0 (no transition; overlay should be fully transparent).
##
## Only acts when `_transitioning == true` to avoid touching the overlay during
## normal gameplay (where `_fade_rect` may already be at 0.0).
##
## AC-8. TR-LS-014. Story LS-006.
func _notification(what: int) -> void:
	# FOCUS_OUT: pause the SceneTree. Godot 4.6 has no built-in
	# `application/run/pause_on_focus_lost` ProjectSetting (the line in
	# project.godot is a no-op marker — Godot ignores unknown settings).
	# Manual pause is required.
	#
	# `process_mode = PROCESS_MODE_ALWAYS` is set on this autoload so the
	# notification handler still fires even after `get_tree().paused = true`.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var tree: SceneTree = get_tree()
		if tree != null and not tree.paused:
			tree.paused = true
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Resume the tree first so the coroutine can advance.
		var tree: SceneTree = get_tree()
		if tree != null and tree.paused:
			tree.paused = false
		# CR-15 fade-overlay snap: only act when a transition is in flight.
		if not _transitioning:
			return
		if _fade_rect == null:
			return
		match _state:
			State.FADING_OUT, State.SWAPPING:
				_fade_rect.color.a = 1.0
			State.FADING_IN:
				_fade_rect.color.a = 0.0  # transitional; coroutine overrides on next frame
			State.IDLE:
				_fade_rect.color.a = 0.0


# ── Public query API ───────────────────────────────────────────────────────

## Returns true if the SectionRegistry was loaded successfully.
## Story LS-002's `transition_to_section` checks this before dispatching.
func has_valid_registry() -> bool:
	return _registry_valid


## Returns the loaded SectionRegistry, or null if load failed.
## Read-only access for scripts that need the section list (e.g., debug menus).
func get_registry() -> SectionRegistry:
	return _registry


## Returns the persistent FadeOverlay CanvasLayer (or null in failure modes).
## Story LS-002 animates `_fade_rect.color.a` for fade-out / fade-in transitions.
func get_fade_overlay() -> CanvasLayer:
	return _fade_overlay


## Returns the persistent ErrorFallback CanvasLayer (or null in failure modes).
## Story LS-005 instantiates the preloaded ErrorFallback scene under this layer
## on transition abort.
func get_error_fallback_layer() -> CanvasLayer:
	return _error_fallback_layer


## Returns the current state-machine cursor (IDLE / FADING_OUT / SWAPPING /
## FADING_IN). Read-only; tests + UI debug use this.
func get_state() -> State:
	return _state


## Returns true while a transition is in flight (between transition_to_section
## entry and step 13 completion).
func is_transitioning() -> bool:
	return _transitioning


## Returns the current section_id (or &"" before any transition has occurred).
func get_current_section_id() -> StringName:
	return _current_section_id


## Registers a callable to be invoked synchronously at step 9 of every
## section-swap sequence (Story LS-003, TR-LS-013, ADR-0007 CR-2).
##
## CONTRACT:
## - Call ONLY at autoload boot (during the registering system's `_ready()`).
##   Post-boot registration is unsupported at MVP; deregistration is post-MVP.
## - The callback MUST NOT `await` anything. Violations are detected in debug
##   builds via pre/post-frame-counter comparison and logged via `push_error`.
## - The callback receives 3 positional args:
##     target_section_id: StringName — the incoming section
##     save_game: SaveGame           — the restore data (null on NEW_GAME)
##     reason: TransitionReason      — why the transition was triggered
## - The callback MUST call `save_game.duplicate_deep()` before assigning
##   sub-resource state to live systems (per ADR-0003 caller-side discipline).
## - If `save_game == null` (NEW_GAME path), initialize system defaults; skip
##   restore logic.
##
## Why frame-delta detection: `await get_tree().process_frame` (the dominant
## violation pattern) advances Engine.get_process_frames() by 1+. A synchronous
## callback returns within the same engine frame; post_frame == pre_frame.
##
## Example (called from a save-consumer autoload's _ready):
##   func _ready() -> void:
##       LevelStreamingService.register_restore_callback(_on_restore)
##
##   func _on_restore(section_id: StringName, save_game: SaveGame, reason: int) -> void:
##       if save_game == null:
##           _reset_to_defaults()
##           return
##       var data: MissionState = save_game.duplicate_deep().mission
##       _apply_mission_state(data)
func register_restore_callback(callback: Callable) -> void:
	if not callback.is_valid():
		push_warning("[LSS] register_restore_callback called with invalid Callable; skipping")
		return
	_restore_callbacks.append(callback)


## Returns the number of registered restore callbacks.
## TEST-ONLY helper — do NOT call from production code.
## Exists because `_restore_callbacks` is private; unit tests cannot directly
## read its size. This accessor avoids making the array public.
## Name intentionally lacks the leading underscore so the public-callable
## intent is unambiguous (a `_`-prefixed name signals "internal" which would
## conflict with cross-class test invocation).
func get_restore_callback_count_for_test() -> int:
	return _restore_callbacks.size()


## Clears the registered restore callbacks. TEST-ONLY helper — do NOT call
## from production code. Exists exclusively to let unit tests exercise the
## empty-array path of `_invoke_restore_callbacks` (AC-2 edge case from
## Story LS-003 §QA Test Cases). After calling this, callers MUST re-register
## any callbacks they need; the autoload otherwise persists for the
## application lifetime.
func clear_restore_callbacks_for_test() -> void:
	_restore_callbacks.clear()


## Returns the last error message stored by a failure-path call to
## `_show_error_fallback(message)`. TEST-ONLY helper — do NOT call from
## production code. ErrorFallback.tscn reads `_last_error_message` directly
## via the LevelStreamingService autoload reference; this accessor exists for
## test assertions without exposing the field as public. Story LS-005.
func get_last_error_message_for_test() -> String:
	return _last_error_message


## Returns the current `_pending_quicksave` flag. TEST-ONLY helper — do NOT
## call from production code. Exists so integration tests can assert the
## queuing and drain behavior without exposing the field as public.
## Story LS-007.
func get_pending_quicksave_for_test() -> bool:
	return _pending_quicksave


## Returns the current `_pending_quickload_slot` value (-1 = none, 0 = queued).
## TEST-ONLY helper — do NOT call from production code. Exists so integration
## tests can assert the queuing and drain behavior. Story LS-007.
func get_pending_quickload_slot_for_test() -> int:
	return _pending_quickload_slot


## Returns a shallow copy of `_step_timings` after a transition completes.
## TEST-ONLY — do NOT call from production code.
##
## Keys are step IDs (int: 1, 2, 3, 5, 6, 7, 9, 10, 12, 13); values are
## `Time.get_ticks_usec()` snapshots taken at each step entry.  Only populated
## when `VERBOSE_TRANSITION_LOGGING_ENABLED == true`.  Returns an empty
## Dictionary when the flag is false or before any transition has run.
##
## Shallow copy prevents test mutations from corrupting LSS internal state.
##
## Usage example (perf harness):
##   var timings: Dictionary = LevelStreamingService.get_step_timings_for_test()
##   var total_usec: int = timings[12] - timings[1]
##
## AC-2, AC-3, AC-5, AC-9. Story LS-010.
func get_step_timings_for_test() -> Dictionary:
	return _step_timings.duplicate()


## Test-only hook: forces `_registry_valid = false` to simulate a registry
## failure. Debug builds only — shipping builds return immediately.
##
## Use in tests to exercise the early-exit guard in `transition_to_section`:
##   `LSS._simulate_registry_failure()`
##   → subsequent `transition_to_section` calls `push_error` and returns
##
## AC-1, AC-8. Story LS-005.
func _simulate_registry_failure() -> void:
	if not OS.is_debug_build():
		return  # test-only hook; shipping no-op (AC-8)
	_registry_valid = false


# ── Public transition API ──────────────────────────────────────────────────

## Triggers a section swap to `section_id`. Story LS-002 13-step coroutine.
##
## Synchronous side effects on this call frame (BEFORE any await — AC-LS-1.0):
##   1. Push InputContext.LOADING
##   2. Set _transitioning = true
##   3. Set _state = State.FADING_OUT
##   4. Launch the swap coroutine (fire-and-forget)
##
## Callers don't await this method; they subscribe to `Events.section_entered`
## and `Events.section_exited` for transition events. The coroutine runs
## detached and emits both signals as it progresses.
##
## Same-section guard (Story LS-006, CR-14, TR-LS-014 — runs FIRST, before
## all other guards):
##   - section_id == _current_section_id AND reason != RESPAWN:
##     Debug: assert(false, ...) + return (caller bug — Mission Scripting error).
##     Shipping: silent early return (no state change, no signal emit).
##   - section_id == _current_section_id AND reason == RESPAWN:
##     Guard bypassed — respawn-in-place (CR-8) is a valid designed flow.
##
## Re-entrance semantics (Story LS-004, TR-LS-006, ADR-0007 CR-6):
##   - FORWARD / NEW_GAME / LOAD_FROM_SAVE while `_transitioning == true`:
##     DROPPED with `push_warning`. No second coroutine is launched.
##   - RESPAWN while `_transitioning == true`: QUEUED in
##     `_pending_respawn_save_game`. Drained at step 13 from IDLE (last-wins
##     if queued again before drain).
##
## save_game is reserved for RESPAWN / LOAD_FROM_SAVE flows (consumed by the
## restore-callback chain in Story LS-003).
##
## TR-LS-005, TR-LS-006, TR-LS-007, TR-LS-009, TR-LS-014. Stories LS-002, LS-004, LS-006.
func transition_to_section(
	section_id: StringName,
	save_game: SaveGame = null,
	reason: TransitionReason = TransitionReason.FORWARD
) -> void:
	if not _registry_valid:
		push_error("[LevelStreamingService] transition rejected — registry invalid")
		return

	# CR-14 same-section guard — runs BEFORE the `_transitioning` re-entrance
	# guard (Story LS-004) so that same-section forwards short-circuit even
	# during a live transition (the guard fires on the call frame, not inside
	# the coroutine). RESPAWN is explicitly excluded: respawn-in-place (CR-8) is
	# a designed flow and must reach the full 13-step coroutine.
	# Debug build: push_error (loud, caller-visible) — Mission Scripting must
	# never forward-transition to the already-active section. We use push_error
	# rather than assert(false, ...) because gdunit4's debug runner intercepts
	# assertion failures as test crashes, breaking the test session. push_error
	# is functionally equivalent (visible in editor + console; flagged by
	# project-wide error monitors) without halting test execution. (Story
	# implementation notes explicitly accept push_error as the wrapping helper.)
	# Shipping build: silent early return — no state change, no signal emit.
	# AC-1, AC-2, AC-3, TR-LS-014. Story LS-006.
	if section_id == _current_section_id and reason != TransitionReason.RESPAWN:
		if OS.is_debug_build():
			push_error(
				"[LSS] same-section forward transition is a caller bug: %s"
				% section_id
			)
		return

	if _transitioning:
		# Re-entrance guard (Story LS-004, ADR-0007 CR-6).
		# Non-RESPAWN calls are silently dropped — forward transitions should
		# never be queued (AC-1). RESPAWN calls are queued so that a player
		# death during a transition is never swallowed (AC-2, AC-7).
		if reason != TransitionReason.RESPAWN:
			push_warning(
				"[LSS] forward transition to '%s' dropped — transition already in progress."
				% section_id
			)
			return
		# RESPAWN reason while in-flight — queue for drain at step 13 (AC-2, AC-7).
		# Last-wins: a second RESPAWN call before step 13 simply overwrites (AC-3).
		_pending_respawn_save_game = save_game
		return

	# Step 1: synchronous push so AC-LS-1.0 holds on the same call frame.
	InputContext.push(InputContext.Context.LOADING)
	_transitioning = true
	_state = State.FADING_OUT

	# Story LS-010: step 1 timestamp captured HERE — before the coroutine
	# launches — so the synchronous-setup time is included in the total budget.
	# The coroutine clears _step_timings at its entry, so this call must come
	# after the clear-and-log sequence in _run_swap_sequence would be too late.
	# We pre-record here; _run_swap_sequence.clear() must NOT run before this.
	# Implementation: _run_swap_sequence calls _step_timings.clear() then
	# immediately re-records step 1 via _log_step to update the cleared dict.
	# AC-1, AC-2. Story LS-010.
	_log_step(1, "transition begin")

	# Launch coroutine without awaiting — sync return per public contract.
	_run_swap_sequence(section_id, save_game, reason)


## Queues a quicksave (F5) or fires it immediately when the service is IDLE.
##
## Idempotent: a second call before the pending flag is drained is a no-op —
## the intent "save after this transition" is already recorded.
##
## IDLE path: calls `SaveLoad.save_to_slot(0, _assemble_quicksave_payload())`
##   directly. Returns early without calling save_to_slot when
##   `_assemble_quicksave_payload()` returns null (no active section, or Mission
##   Scripting assembler not yet ready). `SaveLoad.save_to_slot` emits
##   `Events.game_saved` on success — LSS does NOT emit it separately.
##
## In-transition path: sets `_pending_quicksave = true`. The flag is drained at
## step 13 of the active coroutine (after state IDLE + _transitioning false).
##
## AC-2, AC-4, AC-5, AC-6. Story LS-007.
##
## Example (called from QuicksaveInputHandler or a test):
##   LevelStreamingService.queue_quicksave_or_fire()
func queue_quicksave_or_fire() -> void:
	if _state != State.IDLE:
		if not _pending_quicksave:
			_pending_quicksave = true
		return
	var payload: SaveGame = _assemble_quicksave_payload()
	if payload == null:
		return
	SaveLoad.save_to_slot(0, payload)


## Queues a quickload (F9) or fires it immediately when the service is IDLE.
##
## Idempotent: a second call before drain is a no-op (slot 0 is always the
## quickload target; multiple queues of the same slot are redundant).
##
## IDLE path:
##   - If `SaveLoad.slot_exists(0)` → calls `SaveLoad.load_from_slot(0)` and
##     triggers a `LOAD_FROM_SAVE` transition to the current section. The loaded
##     SaveGame is passed to the restore-callback chain at step 9.
##   - If slot 0 does not exist → emits
##     `Events.hud_toast_requested(&"quicksave_unavailable", {})` and returns.
##
## In-transition path: sets `_pending_quickload_slot = 0`. Drained at step 13
## AFTER the quicksave drain (F5 intent is preserved first).
##
## AC-3, AC-4, AC-5. Story LS-007.
##
## Example:
##   LevelStreamingService.queue_quickload_or_fire()
func queue_quickload_or_fire() -> void:
	if _state != State.IDLE:
		if _pending_quickload_slot == -1:
			_pending_quickload_slot = 0
		return
	if not SaveLoad.slot_exists(0):
		Events.hud_toast_requested.emit(&"quicksave_unavailable", {})
		return
	var sg: SaveGame = SaveLoad.load_from_slot(0)
	if sg == null:
		return
	transition_to_section(_current_section_id, sg, TransitionReason.LOAD_FROM_SAVE)


## Evicts a section's cached PackedScene from the ResourceLoader cache.
##
## MVP STUB — no-op. The public API surface is reserved for Tier 2 expansion.
##
## Tier 2 intent: implement an eviction policy (e.g. LRU by session dwell time,
## or explicit caller-driven eviction on memory pressure) that calls
## `ResourceLoader.remove_cached(path)` or equivalent. MVP has ≤5 sections ×
## ~1–2 MB each ≈ 5–10 MB cached scene memory — well under the 4 GB memory
## ceiling. Eviction is deferred per GDD §Tuning Knobs + ADR-0007 OQ-LS-2.
##
## CONTRACT (Tier 2): method must remain a public API; callers outside this
## module will call `LevelStreamingService.evict_section_from_cache(section_id)`
## with no change required at the call site.
##
## AC-6, TR-LS-010. Story LS-006.
##
## Example (future Tier 2 caller):
##   LevelStreamingService.evict_section_from_cache(&"rome_01")
func evict_section_from_cache(section_id: StringName) -> void:
	# Tier 2: implement eviction policy (e.g., LRU based on session dwell time,
	# memory pressure trigger). MVP: no-op. ResourceLoader.CACHE_MODE_REUSE keeps
	# first-visit entries for the session lifetime (ADR-0007 CR-11, TR-LS-010).
	pass


## Reloads the current section from `save_game` (RESPAWN path). Story LS-004.
##
## Thin facade over `transition_to_section(_current_section_id, save_game,
## TransitionReason.RESPAWN)` per ADR-0007 CR-2. The re-entrance guard inside
## `transition_to_section` handles the in-flight case: if `_transitioning ==
## true` when this facade reaches the delegate call, the RESPAWN reason causes
## the request to be queued in `_pending_respawn_save_game` (last-wins) rather
## than dropped, and the drain fires at step 13.
##
## Called by the Failure & Respawn epic after it has assembled the
## checkpoint SaveGame. Callers must NOT call this before the first
## NEW_GAME transition (i.e., while `_current_section_id == &""`) unless they
## accept an abort at step 4 (registry miss on the empty key).
##
## AC-2, AC-7, TR-LS-006. Story LS-004.
##
## Example (from a failure-respawn system):
##   func _on_player_died() -> void:
##       var checkpoint_save: SaveGame = SaveLoad.assemble_checkpoint_save()
##       LevelStreamingService.reload_current_section(checkpoint_save)
func reload_current_section(save_game: SaveGame) -> void:
	# The re-entrance guard in transition_to_section handles both paths:
	# • _transitioning == true  → RESPAWN reason queues into _pending_respawn_save_game
	# • _transitioning == false → RESPAWN transition fires immediately from IDLE
	transition_to_section(_current_section_id, save_game, TransitionReason.RESPAWN)


# ── Private 13-step swap coroutine ──────────────────────────────────────────

## Executes the 13-step section-swap sequence (GDD §Detailed Design CR-5).
## Steps:
##   1. (Done by transition_to_section before this coroutine begins)
##   2. SNAP overlay 0 → 1 over 2 frames  (FADING_OUT)
##   3. emit section_exited (outgoing scene STILL in tree)
##   4. registry pre-check, queue_free outgoing scene
##   5. ResourceLoader.load PackedScene
##   6. PackedScene.instantiate
##   7. add_child(instance) + set get_tree().current_scene
##   8. await one frame for _ready()'s call_deferred chains
##   9. invoke registered restore callbacks (Story LS-003 stub here)
##   10. emit section_entered
##   11. SNAP overlay 1 → 0 over 2 frames  (FADING_IN)
##   12. pop InputContext.LOADING
##   13. drain pending respawn / quicksave (Story LS-004/007 stubs here)
func _run_swap_sequence(
	target_id: StringName,
	save_game: SaveGame,
	reason: TransitionReason
) -> void:
	# Story LS-010: clear per-transition timings, then re-record step 1 so
	# the dictionary is consistent with the timestamp captured in
	# transition_to_section (before the coroutine launched).  The re-record
	# overwrites the pre-coroutine value with a fresh usec call; the delta
	# between the two is negligible (< 1 µs on the same call stack).
	# AC-2. Story LS-010.
	_step_timings.clear()
	_log_step(1, "transition begin")

	var outgoing_id: StringName = _current_section_id
	var outgoing_scene: Node = get_tree().current_scene

	# Step 2: SNAP overlay 0 → 1 over 2 frames.
	_log_step(2, "fade out start")
	_fade_rect.color.a = 0.0
	await get_tree().process_frame
	_fade_rect.color.a = 0.5
	await get_tree().process_frame
	_fade_rect.color.a = 1.0

	_state = State.SWAPPING

	# Step 3: emit section_exited BEFORE freeing the outgoing scene.
	# CR-13 sync-subscriber violation detection (debug builds only): record the
	# engine frame counter before and after the emit. If any subscriber awaits,
	# the frame counter advances — the subscriber returned control to LSS and the
	# engine processed at least one frame before LSS continued. That subscriber
	# will later resume against a freed outgoing scene (freed at step 4), which
	# is a use-after-free class of bug. push_error fires with marker "CR-13
	# violation" so test suites and the debug console can detect it.
	# In shipping builds the check compiles out entirely (no runtime cost).
	# Story LS-009. GDD CR-13. ADR-0007.
	_log_step(3, "section_exited emit")
	var _cr13_pre_frame: int = Engine.get_process_frames() if OS.is_debug_build() else 0
	Events.section_exited.emit(outgoing_id, reason)
	if OS.is_debug_build():
		var _cr13_post_frame: int = Engine.get_process_frames()
		if _cr13_post_frame != _cr13_pre_frame:
			push_error(
				("[LSS] CR-13 violation: section_exited subscriber awaited "
				+ "(pre=%d post=%d). Subscriber resumed after queue_free of outgoing scene "
				+ "— use-after-free risk. Inspect Events.section_exited connected callables.")
				% [_cr13_pre_frame, _cr13_post_frame]
			)

	# Step 4: registry pre-check BEFORE queue_free (AC-2, CR-5 ordering: abort
	# must run before the outgoing scene is freed, so the player is never left
	# in a sceneless state on registry miss). Story LS-005 adds _show_error_fallback.
	if not _registry.has_section(target_id):
		_abort_transition()
		push_error("[LevelStreamingService] section_id '%s' not in registry" % target_id)
		_show_error_fallback("File not found: %s" % target_id)
		return
	if outgoing_scene != null and is_instance_valid(outgoing_scene):
		outgoing_scene.queue_free()

	# Step 5: ResourceLoader.load PackedScene with explicit CACHE_MODE_REUSE.
	# CACHE_MODE_REUSE is the Godot default, but specifying it explicitly
	# documents the intent: first load performs a disk read + parse + cache;
	# subsequent loads for the same path return the cached PackedScene without
	# re-reading disk. `instantiate()` always produces a fresh Node tree from
	# the cached resource, so sections are remounted cleanly on repeat visits.
	# Story LS-005 adds _show_error_fallback. AC-4, AC-5, TR-LS-010. Story LS-006.
	_log_step(5, "load begin")
	var path: String = _registry.path(target_id)
	var packed: PackedScene = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_REUSE
	) as PackedScene
	if packed == null:
		_abort_transition()
		push_error("[LevelStreamingService] PackedScene load failed for '%s' at '%s'" % [target_id, path])
		_show_error_fallback("Scene load failed")
		return

	# Step 6: instantiate. Story LS-005 adds _show_error_fallback.
	_log_step(6, "instantiate")
	var instance: Node = packed.instantiate()
	if instance == null:
		_abort_transition()
		push_error("[LevelStreamingService] instantiate failed for '%s'" % target_id)
		_show_error_fallback("Instantiate failed")
		return

	# Step 7: add to tree + post-add validity check (OQ-LS-11, AC-5).
	# The validity check is a defense-in-depth guard: add_child to the scene
	# tree root should always succeed for a freshly-instantiated Node, but an
	# invalid or already-parented Node can silently result in an out-of-tree
	# instance. Story LS-005 adds this check and the _show_error_fallback path.
	_log_step(7, "add_child")
	get_tree().root.add_child(instance)
	if not is_instance_valid(instance) or not instance.is_inside_tree():
		_abort_transition()
		push_error("[LevelStreamingService] add_child failed — instance not in tree for '%s'" % target_id)
		_show_error_fallback("Tree mount failed")
		return
	get_tree().current_scene = instance

	# Step 8: await one frame so _ready()'s call_deferred chains run.
	await get_tree().process_frame

	# Story LS-008: CR-9 contract assertion (debug builds only, AC-3).
	# Runs after step 8 so _ready() has completed (add_to_group fires in _ready).
	# push_error on violation — does NOT halt the transition per CR-9 spec.
	if OS.is_debug_build():
		_assert_cr9_contract(instance, target_id)

	# Story LS-008: Environment assignment (AC-4, AC-5).
	# Applies the section's environment to the camera's world, or falls back to
	# the default_environment.tres when environment is null. Skipped when no
	# Camera3D is active (Player Character provides the camera; stub scenes may
	# lack one — acceptable degradation per AC-4 edge case).
	_apply_section_environment(instance)

	# Step 9: invoke registered restore callbacks synchronously in registration
	# order (Story LS-003). All callbacks must complete before step 10's
	# section_entered emit so that subscribers observe fully-restored state.
	_log_step(9, "callback chain begin")
	_invoke_restore_callbacks(target_id, save_game, reason)

	# Step 10: emit section_entered (state changes to FADING_IN immediately
	# after, so subscribers can poll get_state() if they need to know which
	# phase the emit fired in). Clear _last_error_message on successful
	# transition completion (Story LS-005).
	_log_step(10, "section_entered emit")
	_current_section_id = target_id
	_last_error_message = ""
	Events.section_entered.emit(target_id, reason)

	_state = State.FADING_IN

	# Step 11: SNAP overlay 1 → 0 over 2 frames.
	_fade_rect.color.a = 1.0
	await get_tree().process_frame
	_fade_rect.color.a = 0.5
	await get_tree().process_frame
	_fade_rect.color.a = 0.0

	# Step 12: pop InputContext.LOADING.
	_log_step(12, "LOADING pop")
	InputContext.pop()  # dismiss-order-ok: LOADING context pop is state-machine driven, not input-event driven (no consume needed).

	# Step 13: reset state machine cursor + transitioning flag, then drain queued
	# F5/F9 (Story LS-007) and respawn (Story LS-004).
	# The state MUST reach IDLE and _transitioning MUST be false BEFORE any drain
	# fires a re-entrant transition_to_section call — otherwise the new call
	# would itself hit the re-entrance guard and re-queue (loop).
	#
	# Drain order per Story LS-007 Implementation Notes:
	#   1. F5 quicksave — preserves "I want to save NOW" intent from mid-transition
	#   2. F9 quickload — runs after save so the save lands before the load wipes it
	#   3. Respawn — lowest priority; a death queue during a load transition is
	#      handled last so the just-loaded state is what the player respawns into.
	_log_step(13, "IDLE")
	_state = State.IDLE
	_transitioning = false

	# Drain F5 quicksave (Story LS-007 AC-4, AC-5).
	# Clear-then-call: field is false BEFORE the re-entrant call so a new F5
	# during this drain's own (synchronous) save_to_slot path is stored cleanly.
	if _pending_quicksave:
		_pending_quicksave = false  # clear first
		var qs_payload: SaveGame = _assemble_quicksave_payload()
		if qs_payload != null:
			SaveLoad.save_to_slot(0, qs_payload)

	# Drain F9 quickload (Story LS-007 AC-4, AC-5).
	# Clear-then-call: field is -1 BEFORE the re-entrant transition_to_section
	# call so a new F9 during the resulting transition is stored cleanly.
	if _pending_quickload_slot != -1:
		var load_slot: int = _pending_quickload_slot
		_pending_quickload_slot = -1  # clear first
		if SaveLoad.slot_exists(load_slot):
			var ql_save: SaveGame = SaveLoad.load_from_slot(load_slot)
			if ql_save != null:
				transition_to_section(_current_section_id, ql_save, TransitionReason.LOAD_FROM_SAVE)
		else:
			Events.hud_toast_requested.emit(&"quicksave_unavailable", {})

	# Drain pending respawn queue (LS-004 AC-5, ADR-0007 CR-6).
	# Clear-then-call ordering: clear the field BEFORE re-entrant call so that
	# any new RESPAWN queue events that arrive during the drain's own coroutine
	# are stored cleanly into the (now-null) field, not clobbered by us.
	if _pending_respawn_save_game != null:
		var queued_save: SaveGame = _pending_respawn_save_game
		_pending_respawn_save_game = null  # clear first (AC-5)
		transition_to_section(_current_section_id, queued_save, TransitionReason.RESPAWN)


## Iterates `_restore_callbacks` in registration order and calls each one
## synchronously with `(target_id, save_game, reason)` (Story LS-003,
## TR-LS-013). Invoked at step 9 — after step 8's await, before step 10's
## section_entered emit.
##
## No-await contract enforcement (debug builds only, per AC-6):
## Pre- and post-call frame counters are compared. A non-zero delta means the
## callback issued an `await`, which violates the synchronous-return contract
## and would cause step 10 to fire from a different engine frame than intended.
## The violation is logged but does NOT halt the chain — subsequent callbacks
## still run. This is intentional: per AC-5, errors inside a callback must not
## skip later callbacks. GDScript's interpreter does not unwind the for-loop on
## `push_error`; the iteration continues naturally.
##
## Runtime-invalid callables (freed object, bad method name) are skipped with a
## push_warning — distinct from the registration-time validity check in
## `register_restore_callback`.
func _invoke_restore_callbacks(
	target_id: StringName,
	save_game: SaveGame,
	reason: TransitionReason
) -> void:
	for cb: Callable in _restore_callbacks:
		if not cb.is_valid():
			push_warning("[LSS] restore callback invalid at step 9; skipping")
			continue

		var pre_frame: int = Engine.get_process_frames()
		cb.call(target_id, save_game, reason)
		var post_frame: int = Engine.get_process_frames()

		# AC-6: debug-only no-await contract check. The frame counter advances
		# by 1+ if the callback issued any `await`. This check is intentionally
		# debug-only — shipping builds skip it and let the transition continue
		# even if a violation occurred.
		if OS.is_debug_build() and post_frame != pre_frame:
			var cb_name: String = cb.get_method() if cb.get_object() != null else "<unknown>"
			push_error(
				"[LSS] restore callback violated no-await contract: %s (pre=%d post=%d frames)"
				% [cb_name, pre_frame, post_frame]
			)


## Aborts the in-flight transition and resets all LSS state to a clean IDLE
## baseline. Stories LS-004, LS-005, LS-007.
##
## Called from every error path in the 13-step coroutine (registry miss,
## ResourceLoader null, instantiate null, add_child validity failure). Safe to
## call from IDLE (no-op for state changes; still clears pending queues
## defensively).
##
## Post-conditions (AC-4, AC-9, LS-007 AC-7):
##   • _transitioning == false
##   • _state == IDLE
##   • InputContext.LOADING not on stack
##   • _fade_rect.color.a == 0.0
##   • _pending_respawn_save_game == null
##   • _pending_quicksave == false
##   • _pending_quickload_slot == -1
##
## AC-4, AC-7, AC-9, TR-LS-006. Stories LS-004, LS-005, LS-007.
func _abort_transition() -> void:
	if _fade_rect != null:
		_fade_rect.color.a = 0.0
	if InputContext.is_active(InputContext.Context.LOADING):
		InputContext.pop()  # dismiss-order-ok: abort path; LOADING context cleanup is state-machine driven.
	_transitioning = false
	_pending_respawn_save_game = null
	_pending_quicksave = false
	_pending_quickload_slot = -1
	_state = State.IDLE


## Routes to the ErrorFallback or MainMenu scene after a failure in the 13-step
## coroutine. Always called AFTER `_abort_transition()` so LSS internal state
## is already clean (IDLE, LOADING popped, fade alpha 0) before the
## SceneTree-level scene swap fires.
##
## Recovery routing:
##   Debug build: stores `message` in `_last_error_message` then calls
##     `change_scene_to_file("res://scenes/ErrorFallback.tscn")` so the player
##     sees the error message for ≥2s before auto-routing to MainMenu.
##   Shipping build (or ErrorFallback missing): routes directly to MainMenu via
##     `change_scene_to_file("res://scenes/MainMenu.tscn")`.
##
## Defense-in-depth: if ErrorFallback.tscn does not exist at runtime (broken
## asset), `ResourceLoader.exists` is checked first and the fallback routes to
## MainMenu without change_scene_to_file for ErrorFallback.
##
## Note: `change_scene_to_file` queues the scene change for the next frame.
## Callers MUST NOT expect the old scene to be gone on the same call frame.
##
## AC-3, AC-4, AC-5, AC-6, AC-7. Story LS-005.
func _show_error_fallback(message: String) -> void:
	_last_error_message = message
	const EF_PATH: String = "res://scenes/ErrorFallback.tscn"
	const MM_PATH: String = "res://scenes/MainMenu.tscn"
	if OS.is_debug_build() and ResourceLoader.exists(EF_PATH):
		# Debug: display error message in ErrorFallback for ≥2s, then auto-route.
		get_tree().change_scene_to_file(EF_PATH)
	else:
		# Shipping build, or ErrorFallback asset missing: route directly to MainMenu.
		get_tree().change_scene_to_file(MM_PATH)


## Story LS-008 — verifies the loaded scene satisfies the CR-9 Section Authoring
## Contract. Called from `_run_swap_sequence` after step 8 (frame await) and
## before step 9 (restore callbacks). DEBUG-BUILDS-ONLY. Each violation
## emits a `push_error` describing the rule + section_id; the transition is
## NOT halted (CR-9 spec — assertions are diagnostic, not aborting).
##
## Rules enforced (from GDD §Detailed Design CR-9 + AC-3):
##   1. Root is Node3D-or-subclass
##   2. Root is in group "section_root"
##   3. Root.section_id == expected_id (caller-supplied target_id)
##   4. player_entry_point + player_respawn_point resolve to DISTINCT nodes
##
## AC-3. Story LS-008.
func _assert_cr9_contract(scene_root: Node, expected_id: StringName) -> void:
	if not (scene_root is Node3D):
		push_error("[LSS] CR-9 violation: %s root is not Node3D" % expected_id)
		return  # subsequent rules can't be evaluated without Node3D base
	if not scene_root.is_in_group("section_root"):
		push_error("[LSS] CR-9 violation: %s root not in 'section_root' group" % expected_id)
	var actual_id: Variant = scene_root.get(&"section_id")
	if actual_id != expected_id:
		push_error(
			"[LSS] CR-9 violation: section_id mismatch (expected %s, got %s)"
			% [expected_id, actual_id]
		)
	var entry_path: NodePath = scene_root.get(&"player_entry_point")
	var respawn_path: NodePath = scene_root.get(&"player_respawn_point")
	var entry: Node = scene_root.get_node_or_null(entry_path)
	var respawn: Node = scene_root.get_node_or_null(respawn_path)
	if entry == null or respawn == null:
		push_error(
			"[LSS] CR-9 violation: %s entry/respawn NodePath unresolvable"
			% expected_id
		)
	elif entry == respawn:
		push_error(
			"[LSS] CR-9 violation: %s entry and respawn point to the SAME node instance"
			% expected_id
		)


## Story LS-008 — applies the section's Environment to the camera's world, or
## falls back to default_environment.tres when section_root.environment is null.
## Skipped silently when no Camera3D is active (PlayerCharacter provides it;
## stub scenes may lack one — acceptable degradation per AC-4 edge case).
##
## AC-4, AC-5. Story LS-008.
func _apply_section_environment(scene_root: Node) -> void:
	# Duck-typed SectionRoot detection: avoid the literal `SectionRoot` type
	# reference at parse time so LSS doesn't depend on the SectionRoot script
	# being loaded at autoload-parse time. SectionRoot's distinguishing
	# surface here is the `environment` export — if the scene root has it
	# typed as Environment-or-null, we treat it as a SectionRoot.
	if not scene_root.is_in_group("section_root"):
		return  # non-SectionRoot scenes (e.g., legacy stubs) get no environment apply
	var env_value: Variant = scene_root.get(&"environment")
	var env: Environment = null
	if env_value is Environment:
		env = env_value as Environment
	if env == null:
		# Fallback: default_environment.tres. ResourceLoader.load returns null if
		# the asset is missing — acceptable degradation, log + continue.
		const DEFAULT_ENV_PATH: String = "res://assets/data/default_environment.tres"
		var loaded: Resource = ResourceLoader.load(DEFAULT_ENV_PATH)
		if loaded != null and loaded is Environment:
			env = loaded as Environment
		else:
			push_warning(
				"[LSS] default_environment.tres not loadable at %s; world environment unchanged"
				% DEFAULT_ENV_PATH
			)
			return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.get_world_3d() == null:
		return  # AC-4 edge case: stub scenes without cameras skip the apply
	camera.get_world_3d().environment = env


# ── Private helpers ────────────────────────────────────────────────────────

## Assembles the SaveGame payload for a quicksave to slot 0. MVP STUB.
##
## Returns null when no section is currently active (boot state,
## `_current_section_id == &""`). A null return causes both
## `queue_quicksave_or_fire()` and the step-13 drain to skip the
## `SaveLoad.save_to_slot` call — no partial save is written.
##
## TODO (Mission Scripting epic): replace this stub with the production
## assembler that reads live system state (inventory, mission flags, player
## position) and returns a fully-populated SaveGame Resource. Until that
## epic lands, all quicksaves produce a minimal placeholder SaveGame.
##
## AC-2. Story LS-007.
func _assemble_quicksave_payload() -> SaveGame:
	if _current_section_id == &"":
		return null
	# MVP stub: return a placeholder SaveGame. The Mission Scripting epic
	# provides the production assembler that populates all save fields.
	var sg: SaveGame = SaveGame.new()
	return sg


## Records a step-entry timestamp to `_step_timings` and (when
## `VERBOSE_TRANSITION_LOGGING_ENABLED` is true) prints a console line.
##
## Called at each of the 10 instrumented step entries in the 13-step sequence.
## Step 1 is recorded in `transition_to_section` BEFORE the coroutine launches
## so the synchronous-setup time is included; steps 2–13 are recorded inside
## `_run_swap_sequence`.
##
## When the flag is false this function is a no-op — zero allocations, zero
## prints.  Ship builds can disable all instrumentation with the single const.
##
## step_id: int — step number (1, 2, 3, 5, 6, 7, 9, 10, 12, 13).
## label:   String — human-readable name for the console line.
##
## AC-1, AC-2. Story LS-010.
func _log_step(step_id: int, label: String) -> void:
	if not VERBOSE_TRANSITION_LOGGING_ENABLED:
		return
	var now: int = Time.get_ticks_usec()
	_step_timings[step_id] = now
	print("[LSS] step %d (%s) at %d µs" % [step_id, label, now])


## Builds the FadeOverlay CanvasLayer + ColorRect. Layer 127 is the maximum
## signed-8-bit value Godot accepts; setting 128 overflows. Per GDD §Detailed
## Design CR-1, this layer must always render on top of all gameplay UI.
func _setup_fade_overlay() -> void:
	_fade_overlay = CanvasLayer.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.layer = 127
	add_child(_fade_overlay)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.add_child(_fade_rect)


## Builds the ErrorFallback CanvasLayer (one below FadeOverlay) and preloads
## the ErrorFallback scene. The scene is NOT instantiated yet — Story LS-005
## mounts it under this layer when a transition fails.
func _setup_error_fallback_layer() -> void:
	_error_fallback_layer = CanvasLayer.new()
	_error_fallback_layer.name = "ErrorFallbackLayer"
	_error_fallback_layer.layer = 126
	add_child(_error_fallback_layer)

	# Use ResourceLoader (not `preload`) so a missing scene doesn't fail at
	# parse time — autoload completion still proceeds with a logged error
	# (consistent with the registry-load failure mode).
	var ef_path: String = "res://scenes/ErrorFallback.tscn"
	var loaded: Resource = ResourceLoader.load(ef_path)
	if loaded == null or not (loaded is PackedScene):
		push_error("[LevelStreamingService] ErrorFallback scene load failed at %s" % ef_path)
		_error_fallback_scene = null
		return
	_error_fallback_scene = loaded as PackedScene


## Loads section_registry.tres into `_registry` and sets `_registry_valid`.
## On failure: push_errors and leaves `_registry_valid = false`. Autoload boot
## continues — Story LS-002's transition gate refuses to dispatch when invalid.
func _load_registry() -> void:
	var path: String = "res://assets/data/section_registry.tres"
	var loaded: Resource = ResourceLoader.load(path)
	if loaded == null:
		push_error("[LevelStreamingService] SectionRegistry load failed at %s — file missing or corrupt" % path)
		_registry_valid = false
		return
	if not (loaded is SectionRegistry):
		push_error(
			"[LevelStreamingService] Resource at %s is not a SectionRegistry (got: %s)"
			% [path, loaded.get_class()]
		)
		_registry_valid = false
		return
	_registry = loaded as SectionRegistry
	_registry_valid = true
