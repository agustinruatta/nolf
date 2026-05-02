# res://src/gameplay/stealth/guard.gd
#
# Guard — CharacterBody3D root for all PHANTOM guards in The Paris Affair.
#
# This is the base scaffold that all Stealth AI guard variants inherit from.
# Downstream stories extend this class with patrol, perception, and behaviour.
#
# Implements: Story SAI-001 (Guard Node Scaffold) — TR-SAI-001
#             Story SAI-005 (F.5 thresholds + combined score + state escalation) — TR-SAI-002, TR-SAI-011
#             Story SAI-006 (Patrol + investigate + combat behavior dispatch) — TR-SAI-002, TR-SAI-013
# GDD: design/gdd/stealth-ai.md §Core Rules, §F.5, §States and Transitions, §Detailed Rules,
#      §Investigate behavior, §Combat behavior, §COMBAT recovery pacing spec
# ADR-0006: Collision Layer Contract — all layer/mask assignments use PhysicsLayers.*
# ADR-0001: Stencil ID Contract — OutlineTier.set_tier() called at spawn (MEDIUM tier)
# ADR-0003: Save Format Contract — actor_id is the stable per-guard identity key (IG 6)
# ADR-0002: Signal Bus Contract — all SAI-domain signals emitted through Events autoload

class_name Guard extends CharacterBody3D

# ── Exported gameplay values (data-driven — designers tune without touching code) ──
# Note: snake_case naming (not UPPER_SNAKE_CASE) — these are mutable @export vars,
# not const. UPPER_SNAKE_CASE is reserved for const per GDScript conventions.

## Maximum detection range of this guard's vision cone in metres.
## GDD §Core Rules — default 18.0 m.
@export var vision_max_range_m: float = 18.0

## Half-angle of the vision cone in degrees. Dot-product filtering in
## _on_vision_cone_body_entered uses cos(FOV/2) as the threshold.
## GDD §Core Rules — default 110.0°.
@export var vision_fov_deg: float = 110.0

## Downward tilt of the eye forward vector in degrees. Guards look slightly
## down (floor-level) rather than perfectly horizontal.
## GDD §Core Rules — default 15.0°.
@export var vision_cone_downward_angle_deg: float = 15.0

# ── Save/Load identity (ADR-0003 IG 6) ────────────────────────────────────────

## Stable per-actor identity string. Set once in the scene editor; never changes
## at runtime. Used as the key in StealthAIState.guards dictionary (ADR-0003).
## Empty StringName is valid only for prototype guards that do not save state.
@export var actor_id: StringName

# ── F.5 thresholds (Story 005 / AC-7) ─────────────────────────────────────────
# GDD §F.5 — all thresholds are @export_range vars; never hardcoded in logic.
# Guardrail (ADR-0002 control manifest): combined score reads these, never literals.

## Combined-score threshold to transition UNAWARE / SUSPICIOUS → SUSPICIOUS.
## GDD §F.5 T_SUSPICIOUS — safe range [0.2, 0.4]; default 0.3.
@export_range(0.2, 0.4) var t_suspicious: float = 0.3

## Combined-score threshold to transition → SEARCHING.
## GDD §F.5 T_SEARCHING — safe range [0.5, 0.75]; default 0.6.
@export_range(0.5, 0.75) var t_searching: float = 0.6

## Combined-score threshold to transition → COMBAT.
## GDD §F.5 T_COMBAT — safe range [0.9, 1.0]; default 0.95.
@export_range(0.9, 1.0) var t_combat: float = 0.95

## De-escalation decay threshold: if combined falls below this while SUSPICIOUS,
## the suspicion timer counts toward UNAWARE. GDD §F.5 T_DECAY_UNAWARE.
@export_range(0.05, 0.2) var t_decay_unaware: float = 0.1

## De-escalation decay threshold: if combined falls below this while SEARCHING,
## the search timer counts toward SUSPICIOUS. GDD §F.5 T_DECAY_SEARCHING.
@export_range(0.25, 0.45) var t_decay_searching: float = 0.35

# ── Timer exports (de-escalation source, Story 007 wires the timers) ──────────

## Seconds of combined score < T_DECAY_UNAWARE before SUSPICIOUS → UNAWARE.
## GDD §Detailed Rules — SUSPICION_TIMEOUT_SEC default 4.0 s.
@export var suspicion_timeout_sec: float = 4.0

## Seconds of combined score < T_DECAY_SEARCHING before SEARCHING → SUSPICIOUS.
## GDD §Detailed Rules — SEARCH_TIMEOUT_SEC default 12.0 s.
@export var search_timeout_sec: float = 12.0

## Seconds of no confirmed sighting before COMBAT → SEARCHING de-escalation.
## GDD §Detailed Rules — COMBAT_LOST_TARGET_SEC default 8.0 s.
@export var combat_lost_target_sec: float = 8.0

# ── Story 006 behavior dispatch — speed exports ───────────────────────────────
# GDD §Detailed Rules (Investigate behavior, Combat behavior, COMBAT recovery pacing spec)
# SAI-006 AC-1..AC-5 — these are @export vars (designer-tunable), not consts.

## Guard movement speed in UNAWARE / patrolling state (m/s).
## GDD §Tuning Knobs — PATROL_SPEED default 1.2 m/s.
@export var patrol_speed_mps: float = 1.2

## Guard movement speed in SEARCHING / investigate state (m/s).
## GDD §Tuning Knobs — INVESTIGATE_SPEED default 1.6 m/s.
@export var investigate_speed_mps: float = 1.6

## Guard movement speed in COMBAT state (m/s).
## GDD §Tuning Knobs — COMBAT_SPRINT_SPEED default 3.0 m/s.
@export var combat_sprint_speed_mps: float = 3.0

## Maximum XZ-plane distance (m) at which the player can initiate a stealth takedown.
## GDD §Tuning Knobs — TAKEDOWN_RANGE_M default 1.5 m.
@export var takedown_range_m: float = 1.5

## Arrival epsilon for SEARCHING → sweep: guard considers LKP reached when within
## this XZ-plane distance (m). Story 006 dispatches the nav target; sweep is Story 007.
## GDD §Tuning Knobs — INVESTIGATE_ARRIVAL_EPSILON_M default 0.5 m.
@export var investigate_arrival_epsilon_m: float = 0.5

# ── Repath guardrails (const — ADR-0006 control manifest + GDD §Tuning Knobs) ──
# Minimum delta and interval floors for navigation repath requests.
# GDD §Tuning Knobs: "REPATH_MIN_DELTA_M and REPATH_INTERVAL_SEC are const, not @export."
# Asserted in _ready() to catch accidental source edits lowering these below safe minimums.

## Minimum player movement in metres before a repath is triggered.
## Hard floor per GDD §Tuning Knobs.
const REPATH_MIN_DELTA_M: float = 1.0

## Minimum interval in seconds between successive repath requests.
## Hard floor per GDD §Tuning Knobs.
const REPATH_INTERVAL_SEC: float = 1.0

# ── Alert state ────────────────────────────────────────────────────────────────

## Current alert level. Typed to StealthAI.AlertState (Story 002).
## Mandatory initial state: UNAWARE (GDD §State Machine).
## GDD §Detailed Rules — Alert state ownership: Guard owns the mutable state;
## StealthAI owns the enum. Mutation via _transition_to() / _de_escalate_to()
## only — never assigned directly from outside this class.
var current_alert_state: StealthAI.AlertState = StealthAI.AlertState.UNAWARE

# ── De-escalation timer countdowns (Story SAI-007 / GDD §Detailed Rules) ─────
# Float countdown fields decremented by delta each physics frame.
# NOT Godot Timer nodes — kept synchronous with the state machine to avoid
# deferred-signal complexity. Initialised by _initialize_timer_for_state().

## Remaining seconds before SUSPICIOUS → UNAWARE de-escalation fires.
## Initialised to suspicion_timeout_sec when entering SUSPICIOUS.
## Saved/loaded as part of the live guard save schema (post-VS serialisation).
var _suspicion_timeout_remaining: float = 0.0

## Remaining seconds before SEARCHING → SUSPICIOUS de-escalation fires.
## Initialised to search_timeout_sec when entering SEARCHING.
## Saved/loaded as part of the live guard save schema (post-VS serialisation).
var _search_timeout_remaining: float = 0.0

## Remaining seconds before COMBAT → SEARCHING de-escalation fires when
## the guard has no confirmed LOS and has not taken damage.
## Initialised to combat_lost_target_sec when entering COMBAT.
## Saved/loaded as part of the live guard save schema (post-VS serialisation).
var _combat_lost_target_remaining: float = 0.0

# ── Perception accumulators (backward compat — Story 003 stub fields) ─────────
# These fields on Guard itself are the SAI-001 stubs. Story 003+ moved authoritative
# accumulator storage to Perception child. Kept here for test backward compatibility
# (guard_scaffold_test.gd AC-7 reads guard.sight_accumulator and guard.hearing_accumulator).

## Sight fill accumulator. Range [0.0, 1.0]. Story 003 writes this value;
## GuardScaffoldTest (SAI-001 AC-7) verifies it starts at 0.0.
var sight_accumulator: float = 0.0

## Hearing accumulator. Range [0.0, ∞). Story 004 writes this value;
## GuardScaffoldTest (SAI-001 AC-7) verifies it starts at 0.0.
var hearing_accumulator: float = 0.0

# ── Private runtime state ─────────────────────────────────────────────────────

## Last known stimulus world position, updated before each signal emission.
## Sourced from _perception._perception_cache.last_sight_position when available.
var _last_stimulus_position: Vector3 = Vector3.ZERO

# ── @onready — Cached child node references ───────────────────────────────────

@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _vision_cone: Area3D = $VisionCone
@onready var _vision_cone_shape: CollisionShape3D = $VisionCone/VisionShape
@onready var _hearing_poller: Node = $HearingPoller
@onready var _perception: Perception = $Perception
@onready var _dialogue_anchor: Node3D = $DialogueAnchor
@onready var _outline_tier_mesh: MeshInstance3D = $OutlineTier

## PatrolController child — optional (guard scenes without a patrol route omit it).
## Story SAI-006 AC-1: null when the scene has no PatrolController child.
@onready var _patrol_controller: PatrolController = (
		$PatrolController if has_node(^"PatrolController") else null
)


# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	# ── Repath guardrail asserts (Story SAI-006 / GDD §Tuning Knobs) ─────────
	# Verify the const hard floors have not been edited below safe minimums.
	assert(REPATH_MIN_DELTA_M >= 0.5, "REPATH_MIN_DELTA_M must be >= 0.5 m (GDD §Tuning Knobs)")
	assert(REPATH_INTERVAL_SEC >= 0.5, "REPATH_INTERVAL_SEC must be >= 0.5 s (GDD §Tuning Knobs)")

	# ── Alert state initialisation (SAI-005 follow-up of SAI-001 stub) ────────
	current_alert_state = StealthAI.AlertState.UNAWARE

	# ── Collision layer contract (ADR-0006 IG 1) ─────────────────────────────
	# Guards occupy the AI layer. They collide against world geometry and the player.
	# Bitmask direct assignment per AC-1. Zero bare integer literals (ADR-0006).
	collision_layer = PhysicsLayers.MASK_AI
	collision_mask = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER

	# ── VisionCone Area3D layer contract (ADR-0006 / AC-2) ───────────────────
	# VisionCone detects player and dead guards (AI layer) entering range.
	# layer = 0: the Area3D itself occupies no physics layer (it is a sensor).
	#   This is the only valid value for an unindexed sensor — there is no
	#   PhysicsLayers.MASK_NONE constant; integer 0 here means "no layer".
	# mask = PLAYER | AI: overlaps reported for player bodies and other guards
	#   (dead_guard group filter applied in _on_vision_cone_body_entered).
	# NO occluder layers — occlusion is handled by F.1 raycast (Story 004),
	# not by Area3D mask. (GDD §Core Rules explicit constraint.)
	_vision_cone.collision_layer = 0
	_vision_cone.collision_mask = PhysicsLayers.MASK_PLAYER | PhysicsLayers.MASK_AI

	# ── Sync VisionCone shape radius with exported vision_max_range_m ────────
	# AC-3: SphereShape3D radius MUST equal vision_max_range_m. The .tscn holds
	# the default (18.0); this assignment keeps the shape in sync if a designer
	# tunes the export var via the Inspector.
	if _vision_cone_shape != null and _vision_cone_shape.shape is SphereShape3D:
		(_vision_cone_shape.shape as SphereShape3D).radius = vision_max_range_m

	# ── Connect vision cone body-entered signal (ADR-0002: connect in _ready) ──
	if not _vision_cone.body_entered.is_connected(_on_vision_cone_body_entered):
		_vision_cone.body_entered.connect(_on_vision_cone_body_entered)

	# ── Outline tier (ADR-0001 IG 2 — guards are MEDIUM tier, stencil value 2) ──
	# material_overlay, NOT material_override. overlay preserves the base PBR fill
	# while adding the outline stencil; override would clobber fill materials.
	# ADR-0001 IG 3 / Control Manifest: forbidden to use material_override here.
	if _outline_tier_mesh != null:
		OutlineTier.set_tier(_outline_tier_mesh, OutlineTier.MEDIUM)

	# ── Initial behavior dispatch (Story SAI-006 AC-1) ─────────────────────────
	# Guard spawns in UNAWARE — dispatch patrol behavior at startup so
	# NavigationAgent3D.max_speed is set and PatrolController begins its route.
	# _dispatch_behavior_for_state is called AFTER all @onready refs are resolved.
	_dispatch_behavior_for_state(StealthAI.AlertState.UNAWARE)


func _exit_tree() -> void:
	# ── Signal disconnect (ADR-0002 IG 3: always guard with is_connected) ────
	if _vision_cone != null and _vision_cone.body_entered.is_connected(_on_vision_cone_body_entered):
		_vision_cone.body_entered.disconnect(_on_vision_cone_body_entered)


# ── Public query API ──────────────────────────────────────────────────────────

## Returns the stable per-actor identity string for Save/Load (ADR-0003 IG 6).
## Consumers: StealthAIState.guards dictionary key, save/load serialisation.
func get_actor_id() -> StringName:
	return actor_id


## Returns true iff the guard is currently in a state where the player can
## perform a stealth takedown from behind.
##
## Eligibility dimensions (ALL five must hold for true return):
##   1. current_alert_state in {UNAWARE, SUSPICIOUS}
##   2. Guard does NOT currently have LOS to attacker (perception cache read)
##   3. XZ-plane distance <= takedown_range_m (1.5 m default)
##   4. Attacker is within rear half-cone: forward.dot(attacker_dir) <= 0
##      Boundary at exactly 90° is INCLUSIVE (dot == 0 returns true).
##   5. is_instance_valid(attacker) == true
##   Edge: zero-distance (|delta_xz| < 1e-4) → returns false (no normalized() call)
##
## Forward axis: -global_transform.basis.z per Godot 4.6 convention.
## XZ-plane projection: Vector3(delta.x, 0, delta.z) — no .with_y(0) in Godot 4.x.
##
## Story SAI-006 AC-6 / AC-SAI-3.10
## GDD: design/gdd/stealth-ai.md §Takedown eligibility gate + §Tuning Knobs (TAKEDOWN_RANGE_M)
func takedown_prompt_active(attacker: Node) -> bool:
	# Dim 5 — validity guard (ADR-0002 IG 4)
	if not is_instance_valid(attacker):
		return false
	if not (attacker is Node3D):
		return false

	# Dim 1 — state check
	var s: StealthAI.AlertState = current_alert_state
	if s != StealthAI.AlertState.UNAWARE and s != StealthAI.AlertState.SUSPICIOUS:
		return false

	# Dim 2 — guard must NOT have LOS to attacker (perception cache)
	if _perception != null and _perception._perception_cache.initialized:
		if _perception._perception_cache.los_to_player:
			return false

	# Geometry — XZ-plane delta
	var attacker_3d: Node3D = attacker as Node3D
	var delta_3d: Vector3 = attacker_3d.global_position - global_position
	var delta_xz: Vector3 = Vector3(delta_3d.x, 0.0, delta_3d.z)

	# Zero-distance short-circuit — avoids normalized() on near-zero vector
	if delta_xz.length_squared() < 1e-4:
		return false

	# Dim 3 — XZ-plane distance check
	if delta_xz.length() > takedown_range_m:
		return false

	# Dim 4 — rear-arc check: dot <= 0 means attacker is behind or at exact 90°
	var attacker_dir: Vector3 = delta_xz.normalized()
	var forward: Vector3 = -global_transform.basis.z
	var dot: float = forward.dot(attacker_dir)
	if dot > 0.0:
		return false  # attacker is in front half-cone

	return true


## Force a state transition (escalation only) with explicit cause.
## Returns true if transition occurred, false if rejected.
##
## Rules (AC-6 / GDD §Detailed Rules):
##   - Lattice escalation only: new_state must be strictly above current via
##     lattice order UNAWARE(0) < SUSPICIOUS(1) < SEARCHING(2) < COMBAT(3).
##   - DEAD and UNCONSCIOUS always rejected — terminal states reached only via
##     takedown/damage routing (post-VS).
##   - SCRIPTED cause: stimulus_position = guard.global_position (designer trigger).
##   - Returns false for de-escalation or same-state (idempotent rejection).
##
## GDD: design/gdd/stealth-ai.md §F.5 + §Detailed Rules (force_alert_state).
func force_alert_state(new_state: StealthAI.AlertState, cause: StealthAI.AlertCause) -> bool:
	# Reject terminal states — only reachable via takedown/damage (post-VS)
	if new_state == StealthAI.AlertState.UNCONSCIOUS or new_state == StealthAI.AlertState.DEAD:
		return false
	# Lattice ordering check (escalation only; same-state also rejected)
	var current_rank: int = int(current_alert_state)
	var new_rank: int = int(new_state)
	if new_rank <= current_rank:
		return false
	_transition_to(new_state, int(cause))
	return true


# ── F.5 state-machine methods (Story 005) ─────────────────────────────────────

## F.5 combined score (GDD §Detailed Rules — Channel combination score).
## Derived value, never stored. Reads accumulators from _perception child.
## Formula: max(sight, sound) + 0.5 × min(sight, sound).
## GDD: design/gdd/stealth-ai.md §F.5 §Formulas.
func _compute_combined() -> float:
	var sight: float = _perception.sight_accumulator
	var sound: float = _perception.sound_accumulator
	return maxf(sight, sound) + 0.5 * minf(sight, sound)


## Determines the AlertCause for a transition based on which channel led the
## stimulus. AC-5: sight >= sound → SAW_PLAYER; sound > sight → HEARD_NOISE.
## Tie-break: ties go to SAW_PLAYER (sight wins).
func _determine_cause() -> StealthAI.AlertCause:
	var sight: float = _perception.sight_accumulator
	var sound: float = _perception.sound_accumulator
	if sight >= sound:
		return StealthAI.AlertCause.SAW_PLAYER
	return StealthAI.AlertCause.HEARD_NOISE


## Per-frame state escalation evaluator. Reads accumulators, computes combined
## score, escalates state if a threshold is crossed. Called from _physics_process
## by Story 006/007 orchestration, or directly from tests.
##
## Synchronicity contract (AC-8 / AC-SAI-1.11): current_alert_state is mutated
## BEFORE any signal fires. No call_deferred; no await. Subscribers connected
## before this method runs observe the post-mutation state at handler invocation.
##
## Forbidden transitions (per GDD §States and Transitions transition table):
##   - COMBAT → UNAWARE direct (must step through SEARCHING then SUSPICIOUS)
##   - COMBAT → SUSPICIOUS direct (must step through SEARCHING)
##   - SEARCHING → UNAWARE direct (must step through SUSPICIOUS)
## De-escalation through these forbidden direct paths is handled by Story 007's
## timer mechanics, not by _evaluate_transitions.
##
## GDD: design/gdd/stealth-ai.md §F.5 §Detailed Rules (State escalation rule).
func _evaluate_transitions() -> void:
	var combined: float = _compute_combined()
	match current_alert_state:
		StealthAI.AlertState.UNAWARE:
			if combined >= t_combat:
				_transition_to(StealthAI.AlertState.COMBAT)
			elif combined >= t_searching:
				_transition_to(StealthAI.AlertState.SEARCHING)
			elif combined >= t_suspicious:
				_transition_to(StealthAI.AlertState.SUSPICIOUS)
		StealthAI.AlertState.SUSPICIOUS:
			if combined >= t_combat:
				_transition_to(StealthAI.AlertState.COMBAT)
			elif combined >= t_searching:
				_transition_to(StealthAI.AlertState.SEARCHING)
			# SUSPICIOUS → UNAWARE de-escalation: timer-based (Story 007)
		StealthAI.AlertState.SEARCHING:
			if combined >= t_combat:
				_transition_to(StealthAI.AlertState.COMBAT)
			# SEARCHING → SUSPICIOUS de-escalation: timer-based (Story 007)
		StealthAI.AlertState.COMBAT:
			# COMBAT → SEARCHING de-escalation: timer-based (Story 007)
			pass


## Drives state-dependent navigation behavior after every state mutation.
##
## Called from _transition_to() and _de_escalate_to() AFTER the state mutation
## and BEFORE signal emission so signal subscribers observe consistent nav state.
##
## Per-state semantics (Story SAI-006 AC-2..AC-5):
##   UNAWARE   → patrol speed + start PatrolController
##   SUSPICIOUS → stop in place (max_speed=0, target=global_position) + stop patrol
##   SEARCHING  → investigate speed + navigate to last_sight_position (LKP)
##   COMBAT     → sprint speed + navigate to last_sight_position (VS: no cover eval)
##   UNCONSCIOUS/DEAD → cleanup is post-VS; no dispatch issued
##
## GDD: design/gdd/stealth-ai.md §Investigate behavior, §Combat behavior
func _dispatch_behavior_for_state(new_state: StealthAI.AlertState) -> void:
	if _navigation_agent == null:
		return
	match new_state:
		StealthAI.AlertState.UNAWARE:
			_navigation_agent.max_speed = patrol_speed_mps
			if _patrol_controller != null:
				_patrol_controller.start_patrol()
		StealthAI.AlertState.SUSPICIOUS:
			_navigation_agent.max_speed = 0.0
			_navigation_agent.target_position = global_position  # stop in place
			if _patrol_controller != null:
				_patrol_controller.stop_patrol()
		StealthAI.AlertState.SEARCHING:
			_navigation_agent.max_speed = investigate_speed_mps
			if _patrol_controller != null:
				_patrol_controller.stop_patrol()
			# Navigate to last known position from perception cache.
			if _perception != null and _perception._perception_cache.initialized:
				_navigation_agent.target_position = _perception._perception_cache.last_sight_position
		StealthAI.AlertState.COMBAT:
			_navigation_agent.max_speed = combat_sprint_speed_mps
			if _patrol_controller != null:
				_patrol_controller.stop_patrol()
			# VS scope: navigate directly toward last_sight_position.
			# Tactical cover evaluation is post-VS (GDD OQ-SAI-2).
			if _perception != null and _perception._perception_cache.initialized:
				_navigation_agent.target_position = _perception._perception_cache.last_sight_position
		_:
			pass  # UNCONSCIOUS / DEAD — agent stop is handled by takedown target-side cleanup (post-VS)


## De-escalation transition driver. Called by Story 007 timer logic when a guard
## has spent enough time below the decay threshold. Also called directly by tests
## to exercise the de-escalation signal path without the timer mechanism.
##
## Permitted de-escalation paths:
##   SUSPICIOUS → UNAWARE   (SUSPICION_TIMEOUT_SEC of combined < T_DECAY_UNAWARE)
##   SEARCHING  → SUSPICIOUS (SEARCH_TIMEOUT_SEC of combined < T_DECAY_SEARCHING)
##   COMBAT     → SEARCHING  (COMBAT_LOST_TARGET_SEC with no confirmed sight)
##
## Emits actor_lost_target (AC-2) in addition to alert_state_changed.
## Severity for de-escalation is computed by _compute_severity (MINOR for
## SUSPICIOUS → UNAWARE and SEARCHING → SUSPICIOUS per the GDD rule).
##
## GDD: design/gdd/stealth-ai.md §Detailed Rules (State de-escalation rule).
func _de_escalate_to(new_state: StealthAI.AlertState) -> void:
	var prev_state: StealthAI.AlertState = current_alert_state
	if prev_state == new_state:
		return  # idempotent

	current_alert_state = new_state  # MUTATION FIRST (synchronicity AC-8)

	# Story SAI-007: reset the de-escalation timer for the newly entered state so
	# a re-escalation followed by another de-escalation gets a fresh window.
	_initialize_timer_for_state(new_state)

	# Story SAI-006: dispatch behavior after mutation, before signal emit.
	_dispatch_behavior_for_state(new_state)

	var severity: StealthAI.Severity = StealthAI._compute_severity(
			new_state, StealthAI.AlertCause.SAW_PLAYER
	)

	Events.alert_state_changed.emit(self, prev_state, new_state, severity)
	Events.actor_lost_target.emit(self, severity)


## Decrements de-escalation timers based on current state and combined score.
## Resets the active timer when stimulus rises above the state's decay threshold.
## Fires _de_escalate_to() when the timer expires and the combined score is still
## below the threshold.
##
## Timer semantics per GDD §Detailed Rules (State de-escalation rule):
##   AC-2: SUSPICIOUS — combined < t_decay_unaware for suspicion_timeout_sec → UNAWARE.
##   AC-3: SEARCHING  — no new stimulus for search_timeout_sec → SUSPICIOUS,
##                      accumulators set to t_decay_searching (0.35) before transition.
##   AC-4: COMBAT     — combat_lost_target_sec elapsed (sight blocked, no damage) → SEARCHING,
##                      sight set to t_searching - 0.01 (0.59) before transition.
##
## Called once per physics frame from orchestration (Story 008+) or directly
## from unit tests for deterministic simulation.
##
## Implements: Story SAI-007 (TR-SAI-009 §F.3 de-escalation timers)
## GDD: design/gdd/stealth-ai.md §Detailed Rules (State de-escalation rule)
func tick_de_escalation_timers(delta: float) -> void:
	var combined: float = _compute_combined()
	match current_alert_state:
		StealthAI.AlertState.SUSPICIOUS:
			if combined >= t_decay_unaware:
				# New stimulus — reset the countdown so the guard must spend a full
				# suspicion_timeout_sec below threshold before de-escalating.
				_suspicion_timeout_remaining = suspicion_timeout_sec
			else:
				_suspicion_timeout_remaining -= delta
				if _suspicion_timeout_remaining <= 0.0:
					_de_escalate_to(StealthAI.AlertState.UNAWARE)
		StealthAI.AlertState.SEARCHING:
			# AC-3: count down unconditionally; reset on combined rising above
			# t_decay_searching (new stimulus during sweep).
			if combined >= t_decay_searching:
				_search_timeout_remaining = search_timeout_sec
			else:
				_search_timeout_remaining -= delta
				if _search_timeout_remaining <= 0.0:
					# AC-3: set both accumulators to t_decay_searching (0.35) before
					# transition so the guard enters SUSPICIOUS as "edgy, not calm".
					_perception.sight_accumulator = t_decay_searching
					_perception.sound_accumulator = t_decay_searching
					_de_escalate_to(StealthAI.AlertState.SUSPICIOUS)
		StealthAI.AlertState.COMBAT:
			# AC-4: reset timer whenever sight is confirmed (LOS to player exists).
			if _perception._perception_cache.initialized and _perception._perception_cache.los_to_player:
				_combat_lost_target_remaining = combat_lost_target_sec
			else:
				_combat_lost_target_remaining -= delta
				if _combat_lost_target_remaining <= 0.0:
					# AC-4: set sight to t_searching - 0.01 (0.59) before transition
					# so the guard enters SEARCHING with a strong-but-not-combat stimulus.
					_perception.sight_accumulator = t_searching - 0.01
					_de_escalate_to(StealthAI.AlertState.SEARCHING)
		_:
			pass  # UNAWARE / UNCONSCIOUS / DEAD: no de-escalation timer to tick


## Internal escalation transition driver. Mutates state synchronously, then
## emits signals in deterministic order:
##   1. alert_state_changed (always)
##   2. actor_became_alerted (when cause != ALERTED_BY_OTHER — one-hop invariant)
##
## Synchronicity contract (ADR-0002 / AC-8): current_alert_state mutation happens
## BEFORE any signal emit. No call_deferred on state mutation.
##
## [param new_state]      The target AlertState to transition to.
## [param cause_override] If >= 0, use this AlertCause int directly instead of
##                        calling _determine_cause(). Pass -1 for auto-derive.
func _transition_to(new_state: StealthAI.AlertState, cause_override: int = -1) -> void:
	var prev_state: StealthAI.AlertState = current_alert_state
	if prev_state == new_state:
		return  # idempotent

	current_alert_state = new_state  # MUTATION FIRST (synchronicity AC-8)

	# Story SAI-007: initialise the de-escalation timer for the newly entered state.
	_initialize_timer_for_state(new_state)

	# Story SAI-006: dispatch behavior after mutation, before signal emit.
	_dispatch_behavior_for_state(new_state)

	var cause: StealthAI.AlertCause = (
			cause_override as StealthAI.AlertCause if cause_override >= 0
			else _determine_cause()
	)
	var severity: StealthAI.Severity = StealthAI._compute_severity(new_state, cause)

	# Update _last_stimulus_position from the perception cache before emit.
	# Defensive: _perception may not have ticked yet (cold start).
	if _perception != null and _perception._perception_cache.initialized:
		_last_stimulus_position = _perception._perception_cache.last_sight_position

	Events.alert_state_changed.emit(self, prev_state, new_state, severity)

	# Suppress actor_became_alerted propagation when ALERTED_BY_OTHER
	# (one-hop invariant — the propagation chain must not loop).
	# SCRIPTED cause DOES emit actor_became_alerted; propagation suppression for
	# SCRIPTED is post-VS (F.4 propagation chain is post-VS scope).
	if cause != StealthAI.AlertCause.ALERTED_BY_OTHER:
		var stimulus_pos: Vector3 = (
				global_position if cause == StealthAI.AlertCause.SCRIPTED
				else _last_stimulus_position
		)
		Events.actor_became_alerted.emit(self, cause, stimulus_pos, severity)


## Initialises the de-escalation timer for the newly-entered state to its full
## timeout value. Called from both _transition_to and _de_escalate_to so that:
##   - Escalation into a state always starts its timer fresh.
##   - De-escalation into a lower state also resets the timer, so a re-escalation
##     followed by a second de-escalation gets a fresh countdown window.
##
## States without a de-escalation timer (UNAWARE, UNCONSCIOUS, DEAD) are no-ops.
##
## Implements: Story SAI-007 (TR-SAI-009 §F.3 timer-reset-on-enter)
func _initialize_timer_for_state(new_state: StealthAI.AlertState) -> void:
	match new_state:
		StealthAI.AlertState.SUSPICIOUS:
			_suspicion_timeout_remaining = suspicion_timeout_sec
		StealthAI.AlertState.SEARCHING:
			_search_timeout_remaining = search_timeout_sec
		StealthAI.AlertState.COMBAT:
			_combat_lost_target_remaining = combat_lost_target_sec
		_:
			pass  # UNAWARE / UNCONSCIOUS / DEAD: no timer to initialise


# ── Private callbacks ─────────────────────────────────────────────────────────

## Called when a PhysicsBody3D enters the VisionCone sphere.
##
## Filter rules (GDD §Core Rules, AC-4):
##   1. Reject unless body is in group "player" OR group "dead_guard" (early return).
##   2. Belt-and-braces typed class check: reject unless body is PlayerCharacter OR Guard.
##      (Live guards on LAYER_AI in the alive_guard group are filtered by Rule 1's
##       group check; this rule guards against group-tag misuse during scene authoring.)
##   3. Neither check issues any signal — perception accumulation is Story 003.
##
## Forward axis: -global_transform.basis.z (Godot 4.6 — NOT basis * Vector3.FORWARD).
## Zero-distance edge (GDD E.18) and dot-product cone filtering: Story 004.
func _on_vision_cone_body_entered(body: Node3D) -> void:
	# ADR-0002 IG 4 — Node-typed signal payload validity guard.
	# Defends against same-frame queue-free races where the body is freed before
	# the deferred body_entered callback fires.
	if not is_instance_valid(body):
		return

	# Rule 1 — group filter
	if not (body.is_in_group(&"player") or body.is_in_group(&"dead_guard")):
		return

	# Rule 2 — belt-and-braces typed class check
	if not (body is PlayerCharacter or body is Guard):
		return

	# Rule 3 — no signal issued here. Perception accumulation: Story 003.
	# Dot-product cone angle check and raycast occlusion: Story 004.
	pass
