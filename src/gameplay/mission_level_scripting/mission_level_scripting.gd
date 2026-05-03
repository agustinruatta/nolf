# res://src/gameplay/mission_level_scripting/mission_level_scripting.gd
#
# MissionLevelScripting — mission state machine + scripted-event trigger
# system + section authoring contract owner + ADR-0003 SaveGame assembler on
# section_entered(FORWARD). Per `design/gdd/mission-level-scripting.md`
# (CR-17). Registered as autoload key `MissionLevelScripting` at line 9 of
# project.godot per ADR-0007 §Key Interfaces.
#
# Real behaviour: subscribes to Events.respawn_triggered (from
# FailureRespawn at line 8), section_entered, guard_woke_up, enemy_killed,
# alert_state_changed; emits Events.mission_started / mission_completed /
# objective_started / objective_completed / scripted_dialogue_trigger.
#
# Position is load-bearing — line-after-FailureRespawn satisfies ADR-0007
# §Cross-Autoload Reference Safety rule 3 (MLS may reference F&R at line 8
# from _ready()).
#
# Implements: design/gdd/mission-level-scripting.md (CR-17, CR-18, CR-2, CR-3,
#             CR-4, CR-5, F.1, F.2, F.5)
# Story: MLS-002 (mission state machine + objective state machine)
# ADR: ADR-0007 (Autoload Load Order Registry), ADR-0002 (Signal Bus)

## MissionLevelScriptingService — mission lifecycle, objective state machine,
## and scripted-beat trigger system. Registered as MissionLevelScripting autoload.
##
## State machines:
## - Mission:   IDLE → RUNNING → COMPLETED (terminal)
## - Objective: PENDING → ACTIVE → COMPLETED (terminal, per-objective)
##
## Signals emitted exclusively via Events.* per ADR-0002 — never wrapper methods.
class_name MissionLevelScriptingService extends Node


# ── Public inner enums ────────────────────────────────────────────────────────

## Mission lifecycle phases (C.2 state machine).
## IDLE: boot state; no mission loaded.
## RUNNING: mission active; objectives processing.
## COMPLETED: terminal; all required objectives done.
enum MissionPhase {
	IDLE,
	RUNNING,
	COMPLETED,
}

## Per-objective lifecycle state (C.3 state machine).
## Integer values stored in MissionState.objective_states Dictionary.
## PENDING: loaded but prereqs not satisfied.
## ACTIVE: prereqs satisfied; listening for completion_signal.
## COMPLETED: terminal; completion_signal fired and filter passed.
enum ObjectiveState {
	PENDING,   # = 0
	ACTIVE,    # = 1
	COMPLETED, # = 2
}


# ── Constants ─────────────────────────────────────────────────────────────────

## Maximum allowed recursive depth for the supersede cascade (F.5 / GDD CR-3).
## Cascade at depth > SUPERSEDE_CASCADE_MAX aborts with push_error; completed
## objectives at depths 1..SUPERSEDE_CASCADE_MAX are NOT rolled back.
const SUPERSEDE_CASCADE_MAX: int = 3

## Maps section IDs to mission IDs for VS-tier dispatch.
## Production: each section scene exports mission_id; this table is the VS fallback.
const _SECTION_TO_MISSION: Dictionary = {
	&"plaza": &"eiffel_tower",
}


# ── Private state ─────────────────────────────────────────────────────────────

## Current mission lifecycle phase.
var _phase: MissionPhase = MissionPhase.IDLE

## The loaded MissionResource for the active mission. null when IDLE.
var _active_mission: MissionResource = null

## Persistent per-mission state (objective_states, triggers_fired, fired_beats).
## Owned here; written to SaveGame by Story MLS-004.
var _mission_state: MissionState = null

## Tracks whether we are connected to Events.document_collected for objective
## completion dispatch. Guards against double-connect.
var _document_collected_connected: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Called when this autoload enters the scene tree. All cross-autoload signal
## connections live here per ADR-0007 IG 3 (_init() must remain clean).
## Events (line 1) is safely reachable from position line 9.
func _ready() -> void:
	Events.section_entered.connect(_on_section_entered)
	Events.respawn_triggered.connect(_on_respawn_triggered)


## Called when this autoload exits the scene tree. Disconnects all signal
## connections with is_connected guards per ADR-0002 IG 3.
func _exit_tree() -> void:
	if Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.disconnect(_on_section_entered)
	if Events.respawn_triggered.is_connected(_on_respawn_triggered):
		Events.respawn_triggered.disconnect(_on_respawn_triggered)
	_disconnect_document_collected()


# ── Section entered handler ───────────────────────────────────────────────────

## Handles Events.section_entered. On NEW_GAME: loads MissionResource, runs
## CR-18 validation, transitions IDLE→RUNNING, activates zero-prereq objectives.
## FORWARD: SaveGame assembly (Story MLS-004). RESPAWN/LOAD_FROM_SAVE: no-op here
## (Stories MLS-004/MLS-005). Idempotent: double NEW_GAME push_errors + drops.
##
## [param section_id] The StringName identifier of the entered section.
## [param reason] LevelStreamingService.TransitionReason as int (avoids circular
##   import — same pattern as all events.gd int-typed enum payloads).
func _on_section_entered(section_id: StringName, reason: int) -> void:
	# MLS-004: FORWARD branch — synchronous capture chain + slot-0 autosave.
	# RESPAWN/LOAD_FROM_SAVE: explicit no-op (no autosave write per FP-4).
	if reason == LevelStreamingService.TransitionReason.FORWARD:
		if _phase == MissionPhase.RUNNING:
			_assemble_and_save_forward(section_id)
		return

	if reason != LevelStreamingService.TransitionReason.NEW_GAME:
		return

	# AC-MLS-1.3: idempotency guard — RUNNING + non-null mission drops with error.
	if _phase == MissionPhase.RUNNING and _active_mission != null:
		push_error(
			"MLS: section_entered(NEW_GAME) while already RUNNING mission '%s' — dropping request." \
			% str(_active_mission.mission_id)
		)
		return

	# Resolve mission_id for this section.
	var mission_id: StringName = _SECTION_TO_MISSION.get(section_id, &"")
	if mission_id == &"":
		push_error("MLS: no mission mapping found for section '%s' — staying IDLE." % str(section_id))
		return

	# Load MissionResource from disk (CR-18 canonical load pattern).
	var resource: MissionResource = _load_mission_resource(mission_id)
	if resource == null:
		push_error(
			"MLS: ResourceLoader.load() returned null for mission '%s' — staying IDLE." \
			% str(mission_id)
		)
		return

	# CR-18 load-time validation. Any failure stays IDLE.
	if not _validate_mission_resource(resource):
		return

	# Initialise MissionState.
	_mission_state = MissionState.new()
	_mission_state.section_id = section_id

	# Initialise all objectives as PENDING.
	for obj: MissionObjective in resource.objectives:
		_mission_state.objective_states[obj.objective_id] = ObjectiveState.PENDING

	# Commit active mission and transition to RUNNING.
	_active_mission = resource
	_phase = MissionPhase.RUNNING

	# Emit mission_started (ADR-0002 — direct emit, never wrapper).
	Events.mission_started.emit(mission_id)

	# Activate objectives with no prerequisites (F.2 vacuously true).
	for obj: MissionObjective in _active_mission.objectives:
		if _can_activate(obj):
			_activate_objective(obj)


# ── FORWARD autosave assembly chain (MLS-004) ────────────────────────────────

## Assembles a SaveGame via synchronous capture chain and writes slot 0.
## CR-15: NO await, NO call_deferred — entire chain completes atomically in
## the same handler frame as section_entered(FORWARD).
##
## VS scope: the capture chain is minimal — MissionState is the only sub-resource
## with live state. Post-VS systems (PlayerState, InventoryState, StealthAIState,
## DocumentCollectionState, FailureRespawnState) get their own capture() calls
## added here as their epics ship.
##
## On any capture failure (null return from a system's capture()): emit
## save_failed(IO_ERROR) and abort — do not call save_to_slot.
##
## FP-4: this method is reachable ONLY from the FORWARD branch. The RESPAWN
## branch must never reach here (lint enforced separately).
func _assemble_and_save_forward(section_id: StringName) -> void:
	# Capture MissionState — VS path captures objective states + section_id.
	var captured_mission: MissionState = _capture_mission_state(section_id)
	if captured_mission == null:
		push_error("MLS: _capture_mission_state returned null — aborting FORWARD autosave")
		Events.save_failed.emit(SaveLoadService.FailureReason.IO_ERROR)
		return

	var sg: SaveGame = SaveGame.new()
	sg.section_id = section_id
	sg.mission = captured_mission
	# Other capture sub-resources (PlayerState, InventoryState, etc.) will be
	# wired here as their owning epics land — currently default-null which is
	# acceptable VS scope.

	var ok: bool = SaveLoad.save_to_slot(0, sg)
	if not ok:
		push_error("MLS: save_to_slot(0) returned false during FORWARD autosave")


## Captures the current mission state into a fresh MissionState resource.
## Returns null on assembly failure.
func _capture_mission_state(section_id: StringName) -> MissionState:
	var ms: MissionState = MissionState.new()
	ms.section_id = section_id
	if _mission_state != null:
		ms.objective_states = _mission_state.objective_states.duplicate()
		ms.objectives_completed = _mission_state.objectives_completed.duplicate()
		ms.triggers_fired = _mission_state.triggers_fired.duplicate()
	return ms


# ── Respawn handler ───────────────────────────────────────────────────────────

## Handles Events.respawn_triggered. MLS is a no-op here — F&R owns reload.
## MUST NOT emit any Events.* from this handler (F&R CR-8 re-entrancy fence,
## GDD CR-20 FP-8).
##
## [param section_id] The StringName identifier of the respawn target section.
func _on_respawn_triggered(section_id: StringName) -> void:
	pass


# ── Objective activation ──────────────────────────────────────────────────────

## Transitions [param obj] from PENDING to ACTIVE, emits objective_started, and
## subscribes to its completion_signal. Internal; called only when _can_activate
## returns true.
func _activate_objective(obj: MissionObjective) -> void:
	_mission_state.objective_states[obj.objective_id] = ObjectiveState.ACTIVE
	Events.objective_started.emit(obj.objective_id)
	_subscribe_completion_signal(obj)


## Subscribes to the completion signal for [param obj]. At MVP scope only
## "document_collected" is wired; other completion_signal values are logged but
## not connected (Story MLS-005 will extend this dispatch table).
func _subscribe_completion_signal(obj: MissionObjective) -> void:
	if obj.completion_signal == &"document_collected":
		if not _document_collected_connected:
			Events.document_collected.connect(_on_document_collected_for_objective)
			_document_collected_connected = true
	else:
		if obj.completion_signal != &"":
			push_error(
				"MLS: objective '%s' uses completion_signal '%s' which is not wired at MVP scope." \
				% [str(obj.objective_id), str(obj.completion_signal)]
			)


# ── Completion signal handlers ────────────────────────────────────────────────

## Handles Events.document_collected. Finds the first ACTIVE objective whose
## completion_signal == "document_collected", evaluates any completion_filter_method,
## and if the filter passes calls _on_objective_completed_internal.
## Unsubscribes after the first matching objective completes (one-shot per
## objective; re-subscribes if a subsequent objective also needs document_collected).
##
## [param document_id] The StringName identifier of the collected document.
func _on_document_collected_for_objective(document_id: StringName) -> void:
	if _phase != MissionPhase.RUNNING:
		return

	# Find first ACTIVE objective listening for document_collected.
	var target_obj: MissionObjective = null
	for obj: MissionObjective in _active_mission.objectives:
		if obj.completion_signal == &"document_collected":
			var state: int = _mission_state.objective_states.get(obj.objective_id, ObjectiveState.PENDING)
			if state == ObjectiveState.ACTIVE:
				target_obj = obj
				break

	if target_obj == null:
		return

	# Evaluate optional completion filter (CR-18 filter pattern).
	if target_obj.completion_filter_method != &"":
		var filter_result: bool = call(target_obj.completion_filter_method, document_id)
		if not filter_result:
			return

	# AC-MLS-2.4 idempotency: already COMPLETED objectives are silently ignored.
	var current_state: int = _mission_state.objective_states.get(
		target_obj.objective_id, ObjectiveState.PENDING
	)
	if current_state == ObjectiveState.COMPLETED:
		return

	# Disconnect before completing (one-shot pattern for document_collected).
	_disconnect_document_collected()

	_on_objective_completed_internal(target_obj.objective_id)

	# Re-subscribe if any ACTIVE objective still needs document_collected (handles
	# the case where multiple objectives share the completion_signal and the next
	# ACTIVE one was already activated before this one completed — i.e. it will
	# not be re-subscribed by _activate_newly_unlocked_objectives since its state
	# is already ACTIVE, not PENDING).
	if not _document_collected_connected and _phase == MissionPhase.RUNNING:
		for obj: MissionObjective in _active_mission.objectives:
			if obj.completion_signal == &"document_collected":
				var state: int = _mission_state.objective_states.get(
					obj.objective_id, ObjectiveState.PENDING
				)
				if state == ObjectiveState.ACTIVE:
					Events.document_collected.connect(_on_document_collected_for_objective)
					_document_collected_connected = true
					break


# ── Objective completion ──────────────────────────────────────────────────────

## Marks [param objective_id] COMPLETED, emits objective_completed, triggers the
## supersede cascade for any sibling objectives listed in this objective's
## [code]supersedes[/code] field, re-evaluates pending objectives for new
## activations, and checks the F.1 mission-complete gate.
##
## AC-MLS-1.4: if _phase is COMPLETED this method returns immediately (terminal).
## AC-MLS-2.4: if objective is already COMPLETED this method is a no-op.
##
## [param objective_id] The StringName identifier of the completing objective.
func _on_objective_completed_internal(objective_id: StringName) -> void:
	# AC-MLS-1.4: terminal state guard.
	if _phase == MissionPhase.COMPLETED:
		return

	# AC-MLS-2.4: idempotent guard.
	var current_state: int = _mission_state.objective_states.get(
		objective_id, ObjectiveState.PENDING
	)
	if current_state == ObjectiveState.COMPLETED:
		return

	# Mark COMPLETED in state.
	_mission_state.objective_states[objective_id] = ObjectiveState.COMPLETED

	# Emit objective_completed (ADR-0002 — direct emit, never wrapper).
	Events.objective_completed.emit(objective_id)

	# Run supersede cascade for any sibling objectives (CR-3, F.5).
	var completing_obj: MissionObjective = _find_objective(objective_id)
	if completing_obj != null and completing_obj.supersedes.size() > 0:
		_supersede_cascade(objective_id, 1)

	# Re-evaluate PENDING objectives — newly unlocked ones can now activate.
	_activate_newly_unlocked_objectives()

	# F.1 mission-complete gate.
	if _is_mission_complete():
		_phase = MissionPhase.COMPLETED
		Events.mission_completed.emit(_active_mission.mission_id)


# ── Supersede cascade ─────────────────────────────────────────────────────────

## Recursively completes objectives listed in the [code]supersedes[/code] field
## of the objective identified by [param triggering_id]. Called same-frame (GDScript
## single-threaded dispatch guarantees this — GDD F.5).
##
## Cascade depth is capped at [constant SUPERSEDE_CASCADE_MAX] = 3. If depth
## exceeds the cap [method push_error] is called and the cascade stops; already-
## completed objectives at depths 1..MAX are NOT rolled back (AC-MLS-13.4).
##
## [param triggering_id] The objective that triggered this cascade level.
## [param depth] Current recursion depth (1-indexed; first call is depth 1).
func _supersede_cascade(triggering_id: StringName, depth: int) -> void:
	if depth > SUPERSEDE_CASCADE_MAX:
		push_error(
			"MLS: supersede cascade depth exceeded SUPERSEDE_CASCADE_MAX=%d at objective '%s' — aborting cascade." \
			% [SUPERSEDE_CASCADE_MAX, str(triggering_id)]
		)
		return

	var triggering_obj: MissionObjective = _find_objective(triggering_id)
	if triggering_obj == null:
		return

	for sibling_id: StringName in triggering_obj.supersedes:
		var sibling_state: int = _mission_state.objective_states.get(
			sibling_id, ObjectiveState.PENDING
		)
		# Only supersede objectives that are not already COMPLETED.
		if sibling_state == ObjectiveState.COMPLETED:
			continue

		# Mark the sibling COMPLETED and emit for HUD / subscribers.
		_mission_state.objective_states[sibling_id] = ObjectiveState.COMPLETED
		Events.objective_completed.emit(sibling_id)

		# Recurse for any objectives superseded by this sibling (depth-first).
		var sibling_obj: MissionObjective = _find_objective(sibling_id)
		if sibling_obj != null and sibling_obj.supersedes.size() > 0:
			_supersede_cascade(sibling_id, depth + 1)


# ── F.1 / F.2 gate functions ─────────────────────────────────────────────────

## F.1 mission COMPLETED gate (GDD §F.1). Returns true when every objective
## with required_for_completion == true has state COMPLETED. Optional objectives
## (required_for_completion == false) never block completion. O(N), N ≤ 10 MVP.
##
## Returns: true if all required objectives are COMPLETED; false otherwise.
func _is_mission_complete() -> bool:
	if _active_mission == null or _mission_state == null:
		return false
	for obj: MissionObjective in _active_mission.objectives:
		if obj.required_for_completion:
			var state: int = _mission_state.objective_states.get(
				obj.objective_id, ObjectiveState.PENDING
			)
			if state != ObjectiveState.COMPLETED:
				return false
	return true


## F.2 objective ACTIVE gate (GDD §F.2). Returns true when every objective ID
## in [param obj].prereq_objective_ids has state COMPLETED. Vacuously true for
## empty prereq list (objective activates at mission start).
##
## [param obj] The MissionObjective to test.
## Returns: true if all prerequisites are COMPLETED.
func _can_activate(obj: MissionObjective) -> bool:
	if _mission_state == null:
		return false
	for prereq_id: StringName in obj.prereq_objective_ids:
		var state: int = _mission_state.objective_states.get(prereq_id, ObjectiveState.PENDING)
		if state != ObjectiveState.COMPLETED:
			return false
	return true


# ── CR-18 validation ──────────────────────────────────────────────────────────

## CR-18 load-time validation for [param resource]. Checks:
## 1. objectives.size() >= 1.
## 2. At least one objective has required_for_completion == true.
## 3. No objective lists itself in prereq_objective_ids (self-prereq).
## 4. No mutual prereq cycles (DFS from each node).
##
## [param resource] The MissionResource to validate.
## Returns: true if validation passes; false if any rule fails (push_error called).
func _validate_mission_resource(resource: MissionResource) -> bool:
	# Rule 1 + 2: must have objectives and at least one required.
	if resource.objectives.size() < 1:
		push_error(
			"MLS: MissionResource '%s' has no required objectives — mission cannot complete." \
			% str(resource.mission_id)
		)
		return false

	var has_required: bool = false
	for obj: MissionObjective in resource.objectives:
		if obj.required_for_completion:
			has_required = true
			break
	if not has_required:
		push_error(
			"MLS: MissionResource '%s' has no required objectives — mission cannot complete." \
			% str(resource.mission_id)
		)
		return false

	# Build a lookup set for valid objective IDs for prereq validation.
	var valid_ids: Dictionary = {}
	for obj: MissionObjective in resource.objectives:
		valid_ids[obj.objective_id] = true

	# Rule 3 + 4: self-prereq and cycle detection (DFS).
	for obj: MissionObjective in resource.objectives:
		# Self-prereq check (AC-MLS-13.3 also removes the self-ref; here we error and reject).
		if obj.prereq_objective_ids.has(obj.objective_id):
			push_error(
				"MLS: prereq cycle detected at '%s' (self-prereq)." % str(obj.objective_id)
			)
			return false

	# DFS cycle check over entire prereq graph.
	for obj: MissionObjective in resource.objectives:
		var visited: Dictionary = {}
		var stack: Dictionary = {}
		if _prereq_dfs_has_cycle(obj.objective_id, resource, visited, stack):
			push_error("MLS: prereq cycle detected at '%s'." % str(obj.objective_id))
			return false

	return true


## Depth-first search for cycles in the prerequisite graph starting from
## [param start_id]. Uses a recursion stack to detect back-edges.
##
## [param start_id] The objective ID to start DFS from.
## [param resource] The MissionResource providing the objective graph.
## [param visited] Dictionary tracking fully-explored nodes (StringName → bool).
## [param stack] Dictionary tracking the current DFS path (StringName → bool).
## Returns: true if a cycle is found; false otherwise.
func _prereq_dfs_has_cycle(
	start_id: StringName,
	resource: MissionResource,
	visited: Dictionary,
	stack: Dictionary
) -> bool:
	if stack.has(start_id):
		return true
	if visited.has(start_id):
		return false

	stack[start_id] = true

	var obj: MissionObjective = _find_objective_in(start_id, resource)
	if obj != null:
		for prereq_id: StringName in obj.prereq_objective_ids:
			if _prereq_dfs_has_cycle(prereq_id, resource, visited, stack):
				return true

	stack.erase(start_id)
	visited[start_id] = true
	return false


# ── Helpers ───────────────────────────────────────────────────────────────────

## Scans _active_mission for the objective with [param objective_id].
## Returns null if not found or if no mission is active.
##
## [param objective_id] The StringName objective identifier.
## Returns: MissionObjective or null.
func _find_objective(objective_id: StringName) -> MissionObjective:
	if _active_mission == null:
		return null
	return _find_objective_in(objective_id, _active_mission)


## Scans [param resource] for the objective with [param objective_id].
## Returns null if not found.
##
## [param objective_id] The StringName objective identifier.
## [param resource] The MissionResource to search.
## Returns: MissionObjective or null.
func _find_objective_in(objective_id: StringName, resource: MissionResource) -> MissionObjective:
	for obj: MissionObjective in resource.objectives:
		if obj.objective_id == objective_id:
			return obj
	return null


## Iterates all PENDING objectives and activates any whose prereqs are now
## satisfied. Called after each objective completes to propagate the chain.
func _activate_newly_unlocked_objectives() -> void:
	if _active_mission == null or _mission_state == null:
		return
	for obj: MissionObjective in _active_mission.objectives:
		var state: int = _mission_state.objective_states.get(obj.objective_id, ObjectiveState.PENDING)
		if state == ObjectiveState.PENDING and _can_activate(obj):
			_activate_objective(obj)


## Disconnects from Events.document_collected if currently connected.
## Guards with is_connected to satisfy ADR-0002 IG 3.
func _disconnect_document_collected() -> void:
	if _document_collected_connected:
		if Events.document_collected.is_connected(_on_document_collected_for_objective):
			Events.document_collected.disconnect(_on_document_collected_for_objective)
		_document_collected_connected = false


## DI seam: loads MissionResource for [param mission_id] from the canonical
## path. Override in test subclasses to inject in-memory fixtures without
## touching the filesystem.
##
## [param mission_id] The StringName mission identifier.
## Returns: MissionResource or null on load failure.
func _load_mission_resource(mission_id: StringName) -> MissionResource:
	var path: String = "res://assets/data/missions/" + str(mission_id) + "/mission.tres"
	var loaded: Resource = ResourceLoader.load(path)
	if loaded == null or not (loaded is MissionResource):
		return null
	return loaded as MissionResource
