# res://src/gameplay/failure_respawn/failure_respawn_service.gd
#
# Implements: design/gdd/failure-respawn.md (CR-1, CR-2, CR-3, CR-4, CR-6,
#             CR-12 Steps 1–6, E.23, E.24)
# Stories: FR-001 (autoload scaffold + state machine + signal subscriptions
#                  + restore callback registration)
#          FR-002 (CAPTURING body: assemble SaveGame, save_to_slot(0),
#                  in-memory handoff to LevelStreamingService.transition_to_section)
# Registered as autoload key `FailureRespawn` at line 8 of project.godot per
# ADR-0007 §Key Interfaces (after Combat at line 7, before MissionLevelScripting
# at line 9).
#
# Cross-autoload safety (ADR-0007 §Cross-Autoload Reference Safety):
#   _ready() references lines 1–7 only: Events (1), SaveLoad (3),
#   LevelStreamingService (5), Combat (7).
#   Must NOT reference MissionLevelScripting (9) or SettingsService (10) from _ready().

## FailureRespawnService — autoload that catches player death and orchestrates
## the 13-step respawn flow. Sole publisher of respawn_triggered per ADR-0002:183.
## Registered at project.godot autoload line 8 (after Combat, before MLS) per ADR-0007.
##
## FlowState governs re-entrancy (CR-2 idempotency): only IDLE state accepts a new
## player_died event. CAPTURING and RESTORING states drop subsequent events silently.
class_name FailureRespawnService
extends Node


## Internal flow state for the 13-step respawn sequence (GDD CR-1, CR-2).
## IDLE:       Waiting for the player to die. Accepts new player_died events.
## CAPTURING:  Autosave in progress — assembles SaveGame, writes slot-0, hands
##             off to LevelStreamingService (FR-002 fills the body).
## RESTORING:  Level reload and player reset in progress (FR-005 fills the body).
enum FlowState { IDLE, CAPTURING, RESTORING }


## Current position in the respawn flow.
## Starts IDLE at boot; must never be null or out-of-range (GDD E.23).
var _flow_state: FlowState = FlowState.IDLE

## Last recorded checkpoint. Null until the first section_entered event is processed
## by FR-004's handler body. Safe to be null at boot (GDD E.23).
var _current_checkpoint: Checkpoint = null

## Tracks the current section_id for the RESPAWN transition target.
## Populated from _on_section_entered when FR-004 lands its full body.
## For FR-002, _resolve_current_section_id() falls back to
## _ls_service.get_current_section_id() if this is empty.
var _current_section_id: StringName = &""

## Ammo-floor flag per CR-3 (GDD §Detailed Rules). True once the floor top-up
## has been applied for the current checkpoint interval. FR-004 sets it on
## first respawn within a checkpoint; FR-005 clears it at section_entered reset.
## Always false at VS scope (no ammo mechanic in Vertical Slice).
var _floor_applied_this_checkpoint: bool = false

# DI seams — default to the real autoloads; overridden by the test harness.
# Using a local var so production code and test code reference the same path.
var _ls_service: Node = null   # type: LevelStreamingService (set in _ready or injected)
var _sl_service: Node = null   # type: SaveLoadService (set in _ready or injected)

## Test-only seam for _resolve_current_scene. Production leaves this null and
## falls through to get_tree().current_scene. FR-004 tests inject a fixture
## scene tree containing the player_respawn_point Marker3D for AC-1 / AC-2.
var _injected_scene: Node = null

## Test-only seam for _resolve_player_character. Production leaves this null
## and falls through to get_tree().get_nodes_in_group("player_character").
var _injected_player: Node = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Resolve to real autoloads if not already injected by the test harness.
	if _ls_service == null:
		_ls_service = LevelStreamingService
	if _sl_service == null:
		_sl_service = SaveLoad

	# Subscribe to Events signals (ADR-0002 IG 3: is_connected guard before connect).
	if not Events.player_died.is_connected(_on_player_died):
		Events.player_died.connect(_on_player_died)
	if not Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.connect(_on_section_entered)

	# Register the LS restore callback unconditionally — replace-semantics handle
	# editor hot-reload stale-Callable correctly (GDD E.24). LevelStreamingService
	# overwrites the previous registration rather than appending.
	_ls_service.register_restore_callback(_on_ls_restore)


func _exit_tree() -> void:
	# Disconnect both signals (ADR-0002 IG 3: is_connected guard before disconnect).
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.disconnect(_on_section_entered)


# ── Signal handlers ────────────────────────────────────────────────────────────

## Handles player death events from the Combat domain.
## Implements GDD CR-2 idempotency: only processes the event when IDLE.
## CAPTURING and RESTORING states silently drop the event (no retry, no queue).
##
## Transition: IDLE → CAPTURING → RESTORING (CR-12 Steps 1–6).
## Idempotency: non-IDLE states return immediately (CR-2).
##
## NO await anywhere between save_to_slot and transition_to_section —
## synchronous same-call-stack ordering is a hard invariant (CR-4, AC-6).
## `cause` is cast to CombatSystemNode.DeathCause at the call site (Events convention).
func _on_player_died(cause: int) -> void:
	# CR-2 idempotency guard — drop if already mid-flow.
	if _flow_state != FlowState.IDLE:
		return
	_flow_state = FlowState.CAPTURING

	# Step 2: push LOADING input context — FR-005 pops it in the restore callback.
	InputContext.push(InputContextStack.Context.LOADING)

	# Step 3: assemble the SaveGame from live system state (MLS capture chain).
	var assembled_save: SaveGame = _assemble_save_game()

	# Step 4: write slot-0 synchronously (no await between here and transition_to_section).
	# On IO failure: log error and continue — in-memory handoff still enables respawn.
	var save_ok: bool = _sl_service.save_to_slot(0, assembled_save)
	if not save_ok:
		push_error("[FR] slot-0 save failed — continuing with in-memory save (in-memory handoff preserves respawn)")

	# Step 5: emit respawn_triggered BEFORE the LS transition begins (CR-8 ordering).
	# Subscribers receive the notification before LS frees scene nodes (Audio starts
	# its silence gap; in-flight darts cancel; GuardFireController stops). F&R is the
	# sole publisher of this signal per ADR-0002:183 + AC-FR-12.4.
	# Sting suppression: this emit fires within ≤100 ms of player_died (synchronous
	# capture body), satisfying Audio's no-op condition for mission-failure sting
	# (per TR-FR-014 — Audio is responsible for the suppression check; F&R guarantees
	# the timing window).
	Events.respawn_triggered.emit(_resolve_current_section_id())

	# Step 6: hand the same in-memory SaveGame to LS — no re-read from disk (CR-4).
	# TransitionReason.RESPAWN ensures LS restore callbacks receive the assembled save.
	_ls_service.transition_to_section(
		_resolve_current_section_id(),
		assembled_save,
		LevelStreamingService.TransitionReason.RESPAWN,
	)

	# CAPTURING body complete — now awaiting the step-9 LS restore callback.
	_flow_state = FlowState.RESTORING


## Handles section transition events.
## Per FR-004: assembles _current_checkpoint from the section's player_respawn_point
## Marker3D, manages the F.1 floor-flag state machine, and tracks _current_section_id.
## CR-7 IDLE guard: only mutates state when _flow_state == IDLE. This prevents the
## queued-respawn overwrite defect (GDD CR-10) — a stray FORWARD transition during
## RESTORING would otherwise teleport Eve to the wrong respawn point.
## `reason` is cast to LevelStreamingService.TransitionReason at the call site.
func _on_section_entered(section_id: StringName, reason: int) -> void:
	# CR-7 IDLE guard: drop state-mutating work when not IDLE.
	# Story FR-005 handles the RESPAWN dispatch inside _on_ls_restore (step-9 path).
	if _flow_state != FlowState.IDLE:
		return

	match reason:
		LevelStreamingService.TransitionReason.FORWARD, \
		LevelStreamingService.TransitionReason.NEW_GAME, \
		LevelStreamingService.TransitionReason.LOAD_FROM_SAVE:
			# F.1 row 1: fresh checkpoint — reset floor flag.
			_current_section_id = section_id
			_floor_applied_this_checkpoint = false
			_assemble_checkpoint_from_scene()
		LevelStreamingService.TransitionReason.RESPAWN:
			# Unreachable in normal play (RESPAWN fires while RESTORING, gated above).
			# CR-7 sanity: do not overwrite _current_section_id; do not reset floor flag.
			pass
		_:
			push_warning(
				"[FR] _on_section_entered: unrecognized TransitionReason %s — live flag preserved" % reason
			)


## Assembles _current_checkpoint from the active section's player_respawn_point Marker3D.
## On missing marker: push_error and leave _current_checkpoint unchanged (E.9 edge case).
## Per CR-11: marker MUST be a direct child of the section root (find_child owned=false
## still finds it, but section authoring contract MLS-003 enforces direct-child placement).
func _assemble_checkpoint_from_scene() -> void:
	var scene: Node = _resolve_current_scene()
	if scene == null:
		push_error("[FR] no current_scene when assembling checkpoint")
		return
	var marker: Node = scene.find_child("player_respawn_point", true, false)
	if marker == null or not (marker is Marker3D):
		push_error(
			"[FR] 'player_respawn_point' Marker3D not found in section scene — _current_checkpoint unchanged"
		)
		return
	var cp: Checkpoint = Checkpoint.new()
	cp.respawn_position = (marker as Marker3D).global_position
	cp.section_id = _current_section_id
	_current_checkpoint = cp


## Resolves the active scene to search for the respawn marker.
## Tests can override this via _inject_current_scene to inject a fixture scene.
func _resolve_current_scene() -> Node:
	if _injected_scene != null:
		return _injected_scene
	if get_tree() == null:
		return null
	return get_tree().current_scene


## LS step-9 restore callback — invoked by LevelStreamingService during level reload.
## FR-005 body: applies the saved Checkpoint to position the player, calls
## PlayerCharacter.reset_for_respawn(), pops the LOADING InputContext that
## FR-002's CAPTURING body pushed, and transitions RESTORING → IDLE.
##
## Per LSS no-await contract: body must be synchronous (no await) — verified
## by LSS's debug-build pre/post Engine.get_process_frames() check.
##
## Per CR-12 step 9 ordering:
##   1. Apply checkpoint position (teleport before reset to avoid damage on first frame)
##   2. Reset PlayerCharacter (clear DEAD state, refill health, clear transient flags)
##   3. Re-enable input by popping LOADING context (paired with FR-002's push)
##   4. Transition state RESTORING → IDLE (player_died now accepted again)
##
## Signature mirrors LevelStreamingService._invoke_restore_callbacks (3 args):
##   target_id: section being entered after the reload
##   save_game: SaveGame loaded by LS step 6 (may be null if no slot existed)
##   reason: LevelStreamingService.TransitionReason — RESPAWN / FORWARD / etc.
func _on_ls_restore(_target_id: StringName, _save_game: SaveGame, reason: int) -> void:
	# Only the RESPAWN path runs the restore beat. FORWARD / NEW_GAME / LOAD_FROM_SAVE
	# are handled by section_entered (FR-004). E.27: spurious callback fires while IDLE
	# are dropped silently.
	if reason != LevelStreamingService.TransitionReason.RESPAWN:
		return
	if _flow_state != FlowState.RESTORING:
		return

	# Step 9.1: apply Checkpoint position to PlayerCharacter (if checkpoint exists).
	# E.9 edge case: _current_checkpoint may be null if section_entered never fired
	# (e.g., death immediately at boot before FR-004 captures the marker). In that
	# case, leave position unchanged — LS already restored the section's spawn
	# point via player_entry_point per MLS-003.
	var pc: Node = _resolve_player_character()
	if pc != null and _current_checkpoint != null:
		(pc as Node3D).global_position = _current_checkpoint.respawn_position

	# Step 9.2: reset PlayerCharacter state (clear DEAD, refill health).
	if pc != null and pc.has_method(&"reset_for_respawn"):
		pc.call(&"reset_for_respawn")

	# Step 9.3: pop LOADING InputContext paired with FR-002's push (CR-12 step 2).
	# Wrapped in a check because LS's own loading overlay also pushes/pops LOADING;
	# under normal flow our push is the inner one and should pop here.
	if InputContext.current() == InputContextStack.Context.LOADING:
		InputContext.pop() # dismiss-order-ok: paired pop with FR-002 push, no input event

	# Step 9.4: complete the respawn flow.
	_flow_state = FlowState.IDLE


## Resolves the active PlayerCharacter via group lookup. Tests inject via
## _inject_player_character. Production: PlayerCharacter is added to the
## "player_character" group on _ready (PC-006 conventions).
func _resolve_player_character() -> Node:
	if _injected_player != null:
		return _injected_player
	if get_tree() == null:
		return null
	var nodes: Array = get_tree().get_nodes_in_group("player_character") # action-literal-ok: scene-tree group name, not an InputMap action
	if nodes.is_empty():
		return null
	return nodes[0]


# ── Private assembly helpers ───────────────────────────────────────────────────

## Assembles the SaveGame snapshot used for both the slot-0 write and the
## in-memory handoff to LevelStreamingService (CR-4, CR-12 Step 3).
##
## MLS-owned capture chain: each system provides a static capture() factory that
## reads live state without modifying it (CR-6 read-only at capture time).
## At VS scope only FailureRespawnState is populated here; other sub-resources
## (PlayerState, InventoryState, MissionState, etc.) are MLS-004's scope.
## The in-memory handoff to LS preserves respawn even with a sparse SaveGame,
## and the slot-0 file is a record rather than a load source for FR.
func _assemble_save_game() -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.section_id = _resolve_current_section_id()
	sg.failure_respawn = FailureRespawnState.capture(_floor_applied_this_checkpoint)
	# Other capture sub-resources (PlayerState, InventoryState, MissionState, etc.)
	# are MLS's responsibility — MLS-004 will fill them in. At VS scope here,
	# leave them at their default null/empty values; the in-memory handoff to
	# LS preserves respawn even with sparse SaveGame, and the slot-0 file is
	# incomplete but won't be loaded by FR (it's just a record).
	return sg


## Returns the current section_id for use as the RESPAWN transition target.
## Prefers the locally-tracked _current_section_id (populated from section_entered).
## Falls back to _ls_service.get_current_section_id() if not yet set (e.g., at
## boot before any section_entered event, or in test contexts).
func _resolve_current_section_id() -> StringName:
	if _current_section_id != &"":
		return _current_section_id
	return _ls_service.get_current_section_id()


# ── Dependency injection (test seams — do NOT call from production code) ──────

## Replaces the LevelStreamingService reference used by _ready().
## Call BEFORE adding this node to the scene tree so _ready() picks up the double.
## Test harness pattern: `svc._inject_level_streaming(double); add_child(svc)`.
func _inject_level_streaming(svc: Node) -> void:
	_ls_service = svc


## Replaces the SaveLoadService reference used by FR-002+ handler bodies.
## Call BEFORE adding this node to the scene tree.
func _inject_save_load(svc: Node) -> void:
	_sl_service = svc


## Replaces the active scene reference used by _assemble_checkpoint_from_scene.
## Tests inject a fixture Node3D containing a player_respawn_point Marker3D child.
func _inject_current_scene(scene: Node) -> void:
	_injected_scene = scene


## Replaces the PlayerCharacter reference used by _on_ls_restore step 9.
## Tests inject a fixture Node (or PlayerCharacter stub).
func _inject_player_character(pc: Node) -> void:
	_injected_player = pc
