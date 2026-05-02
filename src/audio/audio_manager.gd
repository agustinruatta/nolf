# res://src/audio/audio_manager.gd
#
# AudioManager — scene-tree Node that owns the 5-bus AudioServer structure,
# pre-allocates the SFX pool, and subscribes to the VS-subset of Events.*
# signals. Lives as a direct child of the persistent root scene (NOT an
# autoload — see ADR-0007 §Key Interfaces and the GDD Rule 1).
#
# SUBSCRIBER-ONLY INVARIANT (AUD-002, GDD Rule 9 + ADR-0002):
#   AudioManager NEVER emits signals on the Events bus. It only subscribes.
#   Enforced architecturally (no design reason to publish) and verified by
#   the CI grep test in tests/ci/audio_subscriber_only_lint.gd (AC-5).
#
# RESPONSIBILITIES (AUD-001 + AUD-002):
#   • Ensure 5 named AudioServer buses exist (Music, SFX, Ambient, Voice, UI).
#   • Pre-allocate 16 AudioStreamPlayer3D nodes in the SFX pool, all routed to
#     the SFX bus, added as children so they are freed automatically with this
#     node.
#   • Connect 8 VS-subset Events signals in _ready(); disconnect in _exit_tree()
#     with is_connected guards (ADR-0002 IG 3).
#
# DEFERRED SIGNAL (AUD-002 deviation):
#   Events.actor_became_alerted is NOT yet declared in events.gd (deferred with
#   the AI/Stealth domain — requires StealthAI.AlertCause + StealthAI.Severity
#   enums from the ADR-0002 amendment). The _on_actor_became_alerted stub exists
#   in this file but is NOT wired until the signal lands in events.gd.
#
# OUT OF SCOPE in AUD-001/002 (deferred to later stories):
#   • AUD-003: _on_section_entered / _on_section_exited handler bodies
#   • AUD-004: _on_dialogue_line_started, _on_dialogue_line_finished,
#              _on_document_opened, _on_document_closed, _on_respawn_triggered
#   • AUD-005: _on_player_footstep, _on_actor_became_alerted handler bodies
#
# DESIGN RULES ENFORCED:
#   GDD Rule 1 — no AudioStreamPlayer may route to Master bus.
#   GDD Rule 9 — AudioStreamPlayer.new() at runtime (per-SFX-event) is forbidden;
#                the pre-allocation below is the one-time pool init, which is
#                explicitly permitted.
#
# Implements: Story AUD-001, Story AUD-002
# Requirements: TR-AUD-001, TR-AUD-002, TR-AUD-003
# ADRs: ADR-0007 (Autoload Load Order — AudioManager is NOT in the autoload chain)
#       ADR-0002 (Signal Bus — subscriptions wired per IG 3 + IG 4)

class_name AudioManager
extends Node

# ── Constants ──────────────────────────────────────────────────────────────

## The 5 named buses this manager guarantees exist after _ready().
## Order reflects the GDD §Volume Contract; Master (index 0) is implicit.
const BUS_NAMES: Array[StringName] = [&"Music", &"SFX", &"Ambient", &"Voice", &"UI"]

## Number of AudioStreamPlayer3D nodes pre-allocated in the SFX pool.
## GDD §Pool Contract: 16 voices covers simultaneous SFX playback budget.
const SFX_POOL_SIZE: int = 16

# ── Private state ──────────────────────────────────────────────────────────

## Pre-allocated SFX voice pool. All entries are children of this node so they
## are freed automatically when AudioManager exits the tree (AC-5).
## Never allocate new entries at runtime (GDD Rule 9).
var _sfx_pool: Array[AudioStreamPlayer3D] = []

# ── Lifecycle ──────────────────────────────────────────────────────────────

## Initialise the audio infrastructure.
## Sets up the 5 named buses, pre-allocates the SFX pool, then connects all
## VS-subset Events signal subscriptions. No autoload references beyond
## Events (safe per ADR-0007 — autoloads precede scene nodes in load order).
## Node._ready is virtual with no default body, so super._ready() is
## intentionally not called (parser-rejected in GDScript 4 when the parent
## has no concrete implementation).
func _ready() -> void:
	_setup_buses()
	_setup_sfx_pool()
	_connect_signal_bus()


## Disconnect all VS-subset Events signal subscriptions before this node
## exits the tree. Each disconnect is guarded by is_connected to prevent
## ERR_INVALID_PARAMETER on double-disconnect (ADR-0002 IG 3).
func _exit_tree() -> void:
	_disconnect_signal_bus()


# ── Private setup ──────────────────────────────────────────────────────────

## Ensures the 5 named AudioServer buses exist.
##
## Idempotent: skips any bus whose name already exists (safe across multiple
## test runs and safe when project.godot has the buses pre-declared). Master
## bus at index 0 is always present in Godot and is never renamed.
##
## In production builds the buses are declared in Project Settings (Audio tab)
## so they persist across loads. This method is both the production fallback
## and the headless-test bootstrap (headless Godot starts with only Master).
func _setup_buses() -> void:
	for bus_name: StringName in BUS_NAMES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)


## Pre-allocates SFX_POOL_SIZE AudioStreamPlayer3D nodes and adds them as
## children so they share this node's lifetime (AC-5).
##
## Pool parameters follow the GDD §SFX Voice Contract:
##   • bus = &"SFX" — never Master (GDD Rule 1)
##   • ATTENUATION_INVERSE_DISTANCE — standard distance falloff
##   • max_distance = 50.0 m — culling radius per GDD §Audio Budget
##   • unit_size = 10.0 m — reference distance for 0 dB (GDD §SFX Attenuation)
func _setup_sfx_pool() -> void:
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.bus = &"SFX"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_distance = 50.0
		player.unit_size = 10.0
		add_child(player)
		_sfx_pool.append(player)


# ── Signal Bus subscription registry (AUD-002) ─────────────────────────────

## Connects the 8 VS-subset Events signals to their handler methods.
## Idempotent: each connect is guarded by is_connected so calling this method
## more than once (e.g., node re-added to tree) does not create duplicate
## connections (ADR-0002 IG 3).
##
## DEVIATION (AUD-002): Events.actor_became_alerted is NOT yet declared in
## events.gd (deferred — requires StealthAI.AlertCause + StealthAI.Severity
## from the ADR-0002 amendment). The handler stub _on_actor_became_alerted
## exists below but is not connected here until the signal lands.
func _connect_signal_bus() -> void:
	if not Events.document_opened.is_connected(_on_document_opened):
		Events.document_opened.connect(_on_document_opened)
	if not Events.document_closed.is_connected(_on_document_closed):
		Events.document_closed.connect(_on_document_closed)
	if not Events.respawn_triggered.is_connected(_on_respawn_triggered):
		Events.respawn_triggered.connect(_on_respawn_triggered)
	if not Events.player_footstep.is_connected(_on_player_footstep):
		Events.player_footstep.connect(_on_player_footstep)
	if not Events.dialogue_line_started.is_connected(_on_dialogue_line_started):
		Events.dialogue_line_started.connect(_on_dialogue_line_started)
	if not Events.dialogue_line_finished.is_connected(_on_dialogue_line_finished):
		Events.dialogue_line_finished.connect(_on_dialogue_line_finished)
	if not Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.connect(_on_section_entered)
	if not Events.section_exited.is_connected(_on_section_exited):
		Events.section_exited.connect(_on_section_exited)
	# NOTE: Events.actor_became_alerted not wired — see DEVIATION note above.


## Disconnects all VS-subset Events signals with is_connected guards.
## Safe to call multiple times (double-disconnect cannot raise
## ERR_INVALID_PARAMETER — ADR-0002 IG 3).
func _disconnect_signal_bus() -> void:
	if Events.document_opened.is_connected(_on_document_opened):
		Events.document_opened.disconnect(_on_document_opened)
	if Events.document_closed.is_connected(_on_document_closed):
		Events.document_closed.disconnect(_on_document_closed)
	if Events.respawn_triggered.is_connected(_on_respawn_triggered):
		Events.respawn_triggered.disconnect(_on_respawn_triggered)
	if Events.player_footstep.is_connected(_on_player_footstep):
		Events.player_footstep.disconnect(_on_player_footstep)
	if Events.dialogue_line_started.is_connected(_on_dialogue_line_started):
		Events.dialogue_line_started.disconnect(_on_dialogue_line_started)
	if Events.dialogue_line_finished.is_connected(_on_dialogue_line_finished):
		Events.dialogue_line_finished.disconnect(_on_dialogue_line_finished)
	if Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.disconnect(_on_section_entered)
	if Events.section_exited.is_connected(_on_section_exited):
		Events.section_exited.disconnect(_on_section_exited)
	# NOTE: Events.actor_became_alerted not disconnected — never connected
	# (signal not yet declared; see DEVIATION note in _connect_signal_bus).


# ── Signal callbacks (AUD-002 stubs — bodies filled by AUD-003/004/005) ───

## Documents domain: a document read prop was opened.
## Body: AUD-004 fills in overlay mute logic.
func _on_document_opened(_document_id: StringName) -> void:
	pass


## Documents domain: the document overlay was closed.
## Body: AUD-004 fills in unmute logic.
func _on_document_closed(_document_id: StringName) -> void:
	pass


## Failure & Respawn domain: player respawned at a section checkpoint.
## Body: AUD-004 fills in audio cut + reset logic.
func _on_respawn_triggered(_section_id: StringName) -> void:
	pass


## Player domain: a footstep occurred on a named surface.
## Signature: (surface: StringName, noise_radius_m: float) per events.gd line 27.
## Body: AUD-005 fills in footstep variant routing.
func _on_player_footstep(_surface: StringName, _noise_radius_m: float) -> void:
	pass


## Dialogue domain: a voiced dialogue line began playing.
## Body: AUD-004 fills in VO ducking logic.
func _on_dialogue_line_started(_speaker_id: StringName, _line_id: StringName) -> void:
	pass


## Dialogue domain: the active voiced dialogue line finished.
## Body: AUD-004 fills in VO un-duck logic.
func _on_dialogue_line_finished(_speaker_id: StringName) -> void:
	pass


## Mission domain: player entered a level section.
## `reason` is LevelStreamingService.TransitionReason cast to int at emit site.
## Body: AUD-003 fills in music swap + reverb swap logic.
func _on_section_entered(_section_id: StringName, _reason: int) -> void:
	pass


## Mission domain: player exited a level section.
## `reason` is LevelStreamingService.TransitionReason cast to int at emit site.
## Body: AUD-003 fills in dominant-guard dict clear logic.
func _on_section_exited(_section_id: StringName, _reason: int) -> void:
	pass


## AI/Stealth domain: an actor transitioned to an alerted state.
## DEFERRED: Events.actor_became_alerted not yet declared in events.gd.
## This stub exists to demonstrate the is_instance_valid discipline (ADR-0002
## IG 4) and will be connected once the signal lands in the AI/Stealth epic.
##
## Signature when the signal lands:
##   actor_became_alerted(actor: Node, cause: StealthAI.AlertCause,
##                        source_position: Vector3, severity: StealthAI.Severity)
## The `cause` and `severity` parameters use int here until StealthAI enums land.
## Body: AUD-005 fills in combat stinger scheduling logic.
func _on_actor_became_alerted(
		actor: Node,
		_cause: int,
		_source_position: Vector3,
		_severity: int) -> void:
	# ADR-0002 IG 4: check Node-typed payload validity BEFORE any property access.
	if not is_instance_valid(actor):
		return
	# TODO: AUD-005 fills in stinger scheduling logic.
