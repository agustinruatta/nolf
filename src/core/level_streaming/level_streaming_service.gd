# res://src/core/level_streaming/level_streaming_service.gd
#
# LevelStreamingService — section/level swap orchestration autoload.
#
# Story LS-001 SCAFFOLD — provides the autoload entry, TransitionReason enum,
# SectionRegistry loader, persistent fade overlay (CanvasLayer 127), and
# ErrorFallback layer (CanvasLayer 126) that survive scene swaps.
#
# The 13-step section-swap state machine + register_restore_callback chain land
# in Stories LS-002 + LS-003. This file is the foundation those stories build
# on.
#
# Autoload position: line 5 (after Events 1, EventLogger 2, SaveLoad 3,
# InputContext 4) per ADR-0007 §Key Interfaces. `_ready()` may safely reference
# autoloads at lines 1–4 only (Cross-Autoload Reference Safety rule 2).
#
# Implements: Story LS-001 (autoload boot + fade overlay scaffold)
# Requirements: TR-LS-001, TR-LS-002, TR-LS-004, TR-LS-012
# GDD: design/gdd/level-streaming.md §Detailed Design CR-1, CR-3
# ADRs: ADR-0007 (Autoload Load Order Registry), ADR-0003 (Save Format Contract)

extends Node


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


# ── Lifecycle ──────────────────────────────────────────────────────────────

## Story LS-001 boot sequence:
##   1. Build the persistent fade overlay (CanvasLayer 127 + ColorRect)
##   2. Build the persistent error-fallback layer (CanvasLayer 126) and preload
##      the ErrorFallback.tscn scene
##   3. Load section_registry.tres; set `_registry_valid` accordingly
##
## Cross-autoload reference safety: this `_ready()` must reference ONLY
## autoloads at lines 1–4 per ADR-0007 IG 4. Currently references none —
## the registry path is a literal `res://` URL, not an autoload accessor.
func _ready() -> void:
	_setup_fade_overlay()
	_setup_error_fallback_layer()
	_load_registry()


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
## save_game is reserved for RESPAWN / LOAD_FROM_SAVE flows (consumed by the
## restore-callback chain in Story LS-003).
##
## TR-LS-005, TR-LS-007, TR-LS-009. Story LS-002.
func transition_to_section(
	section_id: StringName,
	save_game: SaveGame = null,
	reason: TransitionReason = TransitionReason.FORWARD
) -> void:
	if not _registry_valid:
		push_error("[LevelStreamingService] transition rejected — registry invalid")
		return
	if _transitioning:
		push_error("[LevelStreamingService] transition rejected — another transition in flight (Story LS-004 will queue)")
		return

	# Step 1: synchronous push so AC-LS-1.0 holds on the same call frame.
	InputContext.push(InputContext.Context.LOADING)
	_transitioning = true
	_state = State.FADING_OUT

	# Launch coroutine without awaiting — sync return per public contract.
	_run_swap_sequence(section_id, save_game, reason)


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
	var outgoing_id: StringName = _current_section_id
	var outgoing_scene: Node = get_tree().current_scene

	# Step 2: SNAP overlay 0 → 1 over 2 frames.
	_fade_rect.color.a = 0.0
	await get_tree().process_frame
	_fade_rect.color.a = 0.5
	await get_tree().process_frame
	_fade_rect.color.a = 1.0

	_state = State.SWAPPING

	# Step 3: emit section_exited BEFORE freeing the outgoing scene.
	Events.section_exited.emit(outgoing_id, reason)

	# Step 4: registry pre-check + queue_free outgoing.
	if not _registry.has_section(target_id):
		_abort_transition()
		push_error("[LevelStreamingService] section_id '%s' not in registry" % target_id)
		return
	if outgoing_scene != null and is_instance_valid(outgoing_scene):
		outgoing_scene.queue_free()

	# Step 5: ResourceLoader.load PackedScene.
	var path: String = _registry.path(target_id)
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		_abort_transition()
		push_error("[LevelStreamingService] PackedScene load failed for '%s' at '%s'" % [target_id, path])
		return

	# Step 6: instantiate.
	var instance: Node = packed.instantiate()
	if instance == null:
		_abort_transition()
		push_error("[LevelStreamingService] instantiate failed for '%s'" % target_id)
		return

	# Step 7: add to tree + reassign current_scene (OQ-LS-11).
	get_tree().root.add_child(instance)
	get_tree().current_scene = instance

	# Step 8: await one frame so _ready()'s call_deferred chains run.
	await get_tree().process_frame

	# Step 9: invoke registered restore callbacks. Story LS-003 implements;
	# this story leaves a no-op stub so the call site is in the right place.
	_invoke_restore_callbacks(target_id, save_game, reason)

	# Step 10: emit section_entered (state changes to FADING_IN immediately
	# after, so subscribers can poll get_state() if they need to know which
	# phase the emit fired in).
	_current_section_id = target_id
	Events.section_entered.emit(target_id, reason)

	_state = State.FADING_IN

	# Step 11: SNAP overlay 1 → 0 over 2 frames.
	_fade_rect.color.a = 1.0
	await get_tree().process_frame
	_fade_rect.color.a = 0.5
	await get_tree().process_frame
	_fade_rect.color.a = 0.0

	# Step 12: pop InputContext.LOADING.
	InputContext.pop()

	# Step 13: drain queued respawn / quicksave (stub — Story LS-004 / LS-007).
	# Reset state machine cursor + transitioning flag.
	_state = State.IDLE
	_transitioning = false


## Story LS-003 stub — no-op for LS-002. The full callback chain registers
## handlers via `register_restore_callback(section_id, callback)` and invokes
## them here with `(target_id, save_game, reason)`. LS-002 leaves the call
## site in the right place; LS-003 implements the chain.
func _invoke_restore_callbacks(
	_target_id: StringName,
	_save_game: SaveGame,
	_reason: TransitionReason
) -> void:
	pass


## Story LS-005 stub — minimal abort recovery for LS-002. Resets state, pops
## InputContext.LOADING (if present), clears overlay alpha. The full LS-005
## implementation mounts the ErrorFallback scene + clears pending queues.
func _abort_transition() -> void:
	if _fade_rect != null:
		_fade_rect.color.a = 0.0
	if InputContext.is_active(InputContext.Context.LOADING):
		InputContext.pop()
	_state = State.IDLE
	_transitioning = false


# ── Private helpers ────────────────────────────────────────────────────────

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
