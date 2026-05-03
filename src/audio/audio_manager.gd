# res://src/audio/audio_manager.gd
#
# AudioManager — scene-tree Node that owns the 5-bus AudioServer structure,
# pre-allocates the SFX pool, subscribes to the VS-subset of Events.* signals,
# manages music player state, crossfades, section reverb presets, VO ducking,
# document world-bus muting, and respawn cut-to-silence behaviour.
# Lives as a direct child of the persistent root scene (NOT an autoload —
# see ADR-0007 §Key Interfaces and the GDD Rule 1).
#
# SUBSCRIBER-ONLY INVARIANT (AUD-002, GDD Rule 9 + ADR-0002):
#   AudioManager NEVER emits signals on the Events bus. It only subscribes.
#   Enforced architecturally (no design reason to publish) and verified by
#   the CI grep test in tests/ci/audio_subscriber_only_lint.gd (AC-5).
#
# RESPONSIBILITIES (AUD-001 + AUD-002 + AUD-003 + AUD-004 + AUD-005):
#   • Ensure 5 named AudioServer buses exist (Music, SFX, Ambient, Voice, UI).
#   • Pre-allocate 16 AudioStreamPlayer3D nodes in the SFX pool, all routed to
#     the SFX bus, added as children so they are freed automatically with this
#     node.
#   • Pre-allocate 4 music/ambient AudioStreamPlayer nodes (MusicDiegetic,
#     MusicNonDiegetic, MusicSting, AmbientLoop) in _ready() — never at runtime.
#   • Connect 10 VS-subset Events signals in _ready(); disconnect in _exit_tree()
#     with is_connected guards (ADR-0002 IG 3).
#   • Drive music crossfades and section reverb presets via section_entered /
#     section_exited / alert_state_changed signals (AUD-003).
#   • Apply Formula 1 state-keyed VO ducking on dialogue_line_started/finished
#     with parallel Tween attack/release (AUD-004).
#   • Mute Music+Ambient and duck Voice bus on document_opened; restore on
#     document_closed (AUD-004, D&S CR-DS-17 v0.3).
#   • Cut all music to silence on respawn_triggered, wait respawn_silence_s,
#     then ease back in over respawn_fade_in_s (AUD-004).
#   • Route player_footstep to 4-bucket variant key + SFX pool steal (AUD-005).
#   • Schedule MusicSting on actor_became_alerted (MAJOR + non-SCRIPTED only),
#     quantized to next 120 BPM downbeat with per-beat-window debounce (AUD-005).
#
# DESIGN RULES ENFORCED:
#   GDD Rule 1 — no AudioStreamPlayer may route to Master bus.
#   GDD Rule 2 — AudioEffectReverb mutated IN-PLACE (not remove/re-add) to
#                prevent audio click during active crossfades (AC-5).
#   GDD Rule 6 — all music transitions via Tween.tween_property on volume_db;
#                never stop-and-start (crossfade helper enforces this).
#   GDD Rule 9 — AudioStreamPlayer.new() at runtime (per-SFX-event) is forbidden;
#                the pre-allocation in _ready() is the one-time pool init.
#
# Implements: Story AUD-001, Story AUD-002, Story AUD-003, Story AUD-004,
#             Story AUD-005
# Requirements: TR-AUD-001, TR-AUD-002, TR-AUD-003, TR-AUD-004, TR-AUD-005,
#               TR-AUD-006, TR-AUD-007, TR-AUD-008, TR-AUD-009, TR-AUD-010,
#               TR-AUD-011
# ADRs: ADR-0007 (Autoload Load Order — AudioManager is NOT in the autoload chain)
#       ADR-0002 (Signal Bus — subscriptions wired per IG 3 + IG 4)
#       ADR-0008 (Performance Budget — audio dispatch ≤0.3 ms p95, Slot 6)

class_name AudioManager
extends Node

# ── Constants ──────────────────────────────────────────────────────────────

## The 5 named buses this manager guarantees exist after _ready().
## Order reflects the GDD §Volume Contract; Master (index 0) is implicit.
const BUS_NAMES: Array[StringName] = [&"Music", &"SFX", &"Ambient", &"Voice", &"UI"]

## Number of AudioStreamPlayer3D nodes pre-allocated in the SFX pool.
## GDD §Pool Contract: 16 voices covers simultaneous SFX playback budget.
const SFX_POOL_SIZE: int = 16

# ── AUD-005: Footstep variant + stinger constants ──────────────────────────

## BPM used for stinger beat quantization.
## GDD §States and Transitions §Alert sting quantization: 120 BPM = 0.5 s per beat.
## Implements: Story AUD-005 AC-5, AC-6, AC-9.
const STINGER_BPM: float = 120.0

# ── AUD-005: Footstep loudness bucket ─────────────────────────────────────

## 4-bucket loudness classification for footstep SFX variant selection.
## GDD §Footstep Surface Map — noise_radius_m thresholds:
##   SOFT    : ≤3.5 m  (crouch-walk, cautious movement)
##   NORMAL  : >3.5–6.5 m (standard walk speed)
##   LOUD    : >6.5–10.0 m (jog / run)
##   EXTREME : >10.0 m    (sprint)
## Implements: Story AUD-005 AC-1, AC-2, AC-3.
enum FootstepVariant { SOFT, NORMAL, LOUD, EXTREME }

# ── AUD-004: VO ducking tuning knobs (Formula 1) — all exported for designer tuning ──

## Duck depth applied to MusicDiegetic when dominant alert state is UNAWARE.
## Formula 1: target = maxf(current_db + duck_db, -80.0). Safe range: -14.0 to -6.0.
## Implements: Story AUD-004 AC-1, AC-4.
@export var diegetic_duck_calm_db: float = -14.0

## Duck depth applied to MusicDiegetic when dominant alert state is SUSPICIOUS.
@export var diegetic_duck_suspicious_db: float = -10.0

## Duck depth applied to MusicDiegetic when dominant alert state is SEARCHING.
@export var diegetic_duck_searching_db: float = -8.0

## Duck depth applied to MusicDiegetic when dominant alert state is COMBAT.
@export var diegetic_duck_combat_db: float = -6.0

## Duck depth applied to MusicNonDiegetic in UNAWARE/SUSPICIOUS/SEARCHING states.
## Only 2 distinct non-diegetic values per Formula 1 (calm vs. combat).
## Safe range: -6.0 to -4.0.
@export var nondiegetic_duck_calm_db: float = -6.0

## Duck depth applied to MusicNonDiegetic in COMBAT state (signal preservation).
@export var nondiegetic_duck_combat_db: float = -4.0

## Flat ambient bus duck depth — applied at all alert states.
## Safe range: -2.0 to -12.0.
@export var ambient_duck_db: float = -6.0

## VO duck attack duration in seconds. Tween from current to ducked volume.
## Safe range: 0.1 to 1.0.
@export var vo_duck_attack_s: float = 0.3

## VO duck release duration in seconds. Tween from live ducked volume to pre-duck.
## Safe range: 0.1 to 2.0.
@export var vo_duck_release_s: float = 0.5

## Voice bus duck depth applied on document_opened (D&S CR-DS-17 v0.3).
## AC-5: only document_opened ducks the Voice bus; dialogue_line_started does NOT.
## Safe range: -18.0 to 0.0.
@export var voice_overlay_duck_db: float = -12.0

## Silence gap after instant respawn cut, before the ease-in tween begins.
## Implements: Story AUD-004 AC-7.
@export var respawn_silence_s: float = 0.2

## Fade-in duration after the respawn silence gap. Uses TRANS_SINE ease-in-out.
@export var respawn_fade_in_s: float = 2.0

# ── Private state ──────────────────────────────────────────────────────────

## Pre-allocated SFX voice pool. All entries are children of this node so they
## are freed automatically when AudioManager exits the tree (AC-5).
## Never allocate new entries at runtime (GDD Rule 9).
var _sfx_pool: Array[AudioStreamPlayer3D] = []

# ── AUD-004: VO duck state ─────────────────────────────────────────────────

## MusicDiegetic volume captured before the VO attack tween starts.
## Restored by the release tween after dialogue_line_finished.
var _pre_duck_diegetic_db: float = 0.0

## MusicNonDiegetic volume captured before the VO attack tween starts.
var _pre_duck_nondiegetic_db: float = -12.0

## Ambient bus volume captured before the VO attack tween starts.
var _pre_duck_ambient_bus_db: float = 0.0

## Voice bus volume captured before document_opened mute (not used by VO duck).
var _pre_duck_voice_bus_db: float = 0.0

## In-flight VO duck attack Tween. Killed on dialogue_line_finished (AC-3).
var _attack_tween: Tween = null

## In-flight VO duck release Tween. Killed if a new attack supersedes it.
var _release_tween: Tween = null

# ── AUD-004: Document overlay duck state ──────────────────────────────────

## MusicDiegetic volume captured before document_opened additional attenuation.
## Restored by document_closed.
var _pre_overlay_diegetic_db: float = 0.0

## MusicNonDiegetic volume captured before document_opened additional attenuation.
var _pre_overlay_nondiegetic_db: float = -12.0

## Voice bus volume captured before document_opened duck. Restored by document_closed.
var _pre_overlay_voice_db: float = 0.0

# ── Music / Ambient players (AUD-003) ──────────────────────────────────────

## Diegetic music layer — in-world source at 0.0 dB for plaza_calm.
## Tweened to -80.0 dB on COMBAT. Bus: Music.
var _music_diegetic: AudioStreamPlayer

## Non-diegetic music layer — score underscore at -12.0 dB for plaza_calm.
## Tweened to 0.0 dB on COMBAT. Bus: Music.
var _music_nondiegetic: AudioStreamPlayer

## One-shot sting player — reserved for stinger scheduling (AUD-005).
## Bus: Music.
var _music_sting: AudioStreamPlayer

## Looping ambient layer — section-specific ambient soundscape. Bus: Ambient.
var _ambient_player: AudioStreamPlayer

# ── Music state tracking (AUD-003) ─────────────────────────────────────────

## Maps guard Node → StealthAI.AlertState. Tracks the per-actor alert level;
## _compute_dominant_state() derives the current music state from the highest
## value (GDD §States and Transitions — Dominant-guard rule).
## Cleared on section_exited (GDD §Concurrency Policies Rule 4).
var _dominant_guard_dict: Dictionary = {}

## The active music state StringName (e.g., &"plaza_calm", &"plaza_combat").
## Updated whenever a crossfade is initiated.
var _current_music_state: StringName = &""

## The currently-running crossfade Tween, or null when no crossfade is active.
## Killed on section_exited before the dict is cleared (AC-4).
var _current_alert_tween: Tween = null

# ── AUD-005: Stinger debounce state ───────────────────────────────────────

## The music playback position (in seconds) of the next downbeat for which a
## stinger is already queued. -INF means no stinger is currently queued.
## Used by the per-beat-window debounce in _on_actor_became_alerted (AC-6).
## Implements: Story AUD-005 AC-5, AC-6, AC-7, AC-8.
var _stinger_queued_for_beat_time: float = -INF

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
	_setup_music_players()
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


## Creates the 4 persistent music/ambient AudioStreamPlayer nodes and adds them
## as direct children so they are freed automatically with this node (GDD Rule 9).
##
## Must be called BEFORE _connect_signal_bus() so that signal handlers can safely
## reference the player nodes without nil checks.
##
## Initial volumes reflect the plaza_calm state table (AC-1):
##   MusicDiegetic    : 0.0 dB  (full diegetic presence)
##   MusicNonDiegetic : -12.0 dB (score underscore blend)
##   MusicSting       : 0.0 dB  (neutral — only played on one-shot triggers)
func _setup_music_players() -> void:
	_music_diegetic = AudioStreamPlayer.new()
	_music_diegetic.name = &"MusicDiegetic"
	_music_diegetic.bus = &"Music"
	_music_diegetic.volume_db = 0.0
	add_child(_music_diegetic)

	_music_nondiegetic = AudioStreamPlayer.new()
	_music_nondiegetic.name = &"MusicNonDiegetic"
	_music_nondiegetic.bus = &"Music"
	_music_nondiegetic.volume_db = -12.0
	add_child(_music_nondiegetic)

	_music_sting = AudioStreamPlayer.new()
	_music_sting.name = &"MusicSting"
	_music_sting.bus = &"Music"
	_music_sting.volume_db = 0.0
	add_child(_music_sting)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = &"AmbientLoop"
	_ambient_player.bus = &"Ambient"
	add_child(_ambient_player)


# ── Signal Bus subscription registry (AUD-002 + AUD-003) ───────────────────

## Connects the 10 VS-subset Events signals to their handler methods.
## Idempotent: each connect is guarded by is_connected so calling this method
## more than once (e.g., node re-added to tree) does not create duplicate
## connections (ADR-0002 IG 3).
##
## AUD-003: Events.alert_state_changed is connected — the 4-param typed
## signature (actor, old_state, new_state, severity) landed in events.gd via
## the SAI-002 commit. _on_alert_state_changed drives the dominant-guard dict
## and music UNAWARE↔COMBAT crossfades (AC-3).
##
## AUD-005: Events.actor_became_alerted is now connected — drives the
## MusicSting brass-punch stinger quantized to the next 120 BPM downbeat.
## Suppressed for SCRIPTED cause and non-MAJOR severity (AC-5, AC-6, AC-7, AC-8).
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
	if not Events.alert_state_changed.is_connected(_on_alert_state_changed):
		Events.alert_state_changed.connect(_on_alert_state_changed)
	if not Events.actor_became_alerted.is_connected(_on_actor_became_alerted):
		Events.actor_became_alerted.connect(_on_actor_became_alerted)


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
	if Events.alert_state_changed.is_connected(_on_alert_state_changed):
		Events.alert_state_changed.disconnect(_on_alert_state_changed)
	if Events.actor_became_alerted.is_connected(_on_actor_became_alerted):
		Events.actor_became_alerted.disconnect(_on_actor_became_alerted)


# ── Signal callbacks (AUD-002 stubs — bodies filled by AUD-003/004/005) ───

## Documents domain: a document read prop was opened.
##
## Implements: Story AUD-004 AC-5 (document world-bus mute).
## Captures pre-overlay Music + Voice bus levels, then applies additional
## attenuation over 0.5 s (MusicDiegetic −10 dB, MusicNonDiegetic −20 dB) and
## ducks the Voice bus by voice_overlay_duck_db over 0.3 s (D&S CR-DS-17 v0.3).
##
## ADR-0002 IG 4: _document_id is StringName — not a Node-typed payload,
## no is_instance_valid guard needed.
func _on_document_opened(_document_id: StringName) -> void:
	# Capture pre-overlay volumes for restoration on document_closed (AC-6).
	_pre_overlay_diegetic_db = _music_diegetic.volume_db
	_pre_overlay_nondiegetic_db = _music_nondiegetic.volume_db
	var voice_bus_idx: int = AudioServer.get_bus_index(&"Voice")
	_pre_overlay_voice_db = AudioServer.get_bus_volume_db(voice_bus_idx)

	# Music layers: additional attenuation (−10 dB diegetic, −20 dB nondiegetic).
	# Voice bus: duck by voice_overlay_duck_db over 0.3 s attack.
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_music_diegetic, "volume_db",
			maxf(_pre_overlay_diegetic_db - 10.0, -80.0), 0.5) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_music_nondiegetic, "volume_db",
			maxf(_pre_overlay_nondiegetic_db - 20.0, -80.0), 0.5) \
		.set_trans(Tween.TRANS_LINEAR)
	var voice_target: float = maxf(_pre_overlay_voice_db + voice_overlay_duck_db, -80.0)
	tween.tween_method(
			func(v: float) -> void:
				AudioServer.set_bus_volume_db(voice_bus_idx, v),
			_pre_overlay_voice_db, voice_target, 0.3)


## Documents domain: the document overlay was closed.
##
## Implements: Story AUD-004 AC-6 (document overlay restore).
## Restores Music layers to pre-overlay levels and Voice bus to pre-duck level
## over 0.5 s each.
func _on_document_closed(_document_id: StringName) -> void:
	var voice_bus_idx: int = AudioServer.get_bus_index(&"Voice")
	var voice_current: float = AudioServer.get_bus_volume_db(voice_bus_idx)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_music_diegetic, "volume_db",
			_pre_overlay_diegetic_db, 0.5) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_music_nondiegetic, "volume_db",
			_pre_overlay_nondiegetic_db, 0.5) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(
			func(v: float) -> void:
				AudioServer.set_bus_volume_db(voice_bus_idx, v),
			voice_current, _pre_overlay_voice_db, 0.5)


## Failure & Respawn domain: player respawned at a section checkpoint.
##
## Implements: Story AUD-004 AC-7 (respawn cut-to-silence + ease-in).
## (a) Instantly cuts MusicDiegetic and MusicNonDiegetic to −80 dB (no Tween).
## (b) Clears the dominant-guard dict (redundant with section_exited but safe
##     per GDD §Concurrency Policies Rule 4).
## (c) After respawn_silence_s (200 ms timer), tweens back to section_calm
##     (diegetic 0.0, nondiegetic −12.0) over respawn_fade_in_s via TRANS_SINE.
func _on_respawn_triggered(_section_id: StringName) -> void:
	# (a) Instant cut — no Tween (GDD §Failure/Respawn domain).
	_music_diegetic.volume_db = -80.0
	_music_nondiegetic.volume_db = -80.0
	# (b) Clear dominant-guard dict.
	_dominant_guard_dict.clear()
	# (c) After silence gap, ease in to section_calm volumes.
	get_tree().create_timer(respawn_silence_s).timeout.connect(
			func() -> void:
				var tween: Tween = create_tween().set_parallel(true)
				tween.tween_property(_music_diegetic, "volume_db",
						0.0, respawn_fade_in_s).set_trans(Tween.TRANS_SINE)
				tween.tween_property(_music_nondiegetic, "volume_db",
						-12.0, respawn_fade_in_s).set_trans(Tween.TRANS_SINE),
			CONNECT_ONE_SHOT)


## Player domain: a footstep occurred on a named surface.
## Routes to a 4-bucket variant key (e.g. "marble_normal") and plays via the
## pre-allocated SFX pool using the steal-oldest-non-exempt rule on overflow.
##
## Implements: Story AUD-005 AC-1, AC-2, AC-3, AC-4.
## GDD §Footstep Surface Map — 4-bucket loudness scheme + GDD Rule 5 (pool steal).
##
## Silent threshold: noise_radius_m == 0.0 means crouch-idle; no SFX plays
## (GDD footnote — crouch-idle is intentionally inaudible, AC-2).
##
## VS scope: only the "marble" surface is implemented for Vertical Slice.
## Remaining 6 surfaces (tile, wood_stage, carpet, metal_grate, gravel,
## water_puddle) are deferred to post-VS content production (TR-AUD-011).
func _on_player_footstep(surface: StringName, noise_radius_m: float) -> void:
	# AC-2: crouch-idle silent threshold — no pool slot consumed.
	if noise_radius_m == 0.0:
		return
	var variant: FootstepVariant = _select_footstep_variant(noise_radius_m)
	# Build the surface+variant key: e.g. "marble_normal", "marble_extreme".
	var variant_key: String = "%s_%s" % [surface, FootstepVariant.find_key(variant).to_lower()]
	var stream: AudioStream = _load_footstep_stream(variant_key)
	# VS stub: _load_footstep_stream returns null until assets are produced.
	if stream == null:
		return
	var player: AudioStreamPlayer3D = _get_or_steal_sfx_slot()
	if player == null:
		# All pool slots are exempt (Voice/UI) — should never happen in VS.
		return
	player.stream = stream
	player.global_position = _get_player_position()
	player.play()


## Dialogue domain: a voiced dialogue line began playing.
##
## Implements: Story AUD-004 AC-1, AC-3, AC-4, AC-8 (VO ducking, Formula 1).
## Captures pre-duck Music + Ambient levels, computes state-keyed duck targets
## using Formula 1 (target = maxf(current_db + duck_db, -80.0)), kills any
## in-flight release tween, then creates a parallel attack tween over
## vo_duck_attack_s. The Voice bus is NOT modified here (AC-8 invariant).
##
## ADR-0002 IG 4: speaker_id/line_id are StringName — not Node-typed payloads.
func _on_dialogue_line_started(_speaker_id: StringName, _line_id: StringName) -> void:
	# Capture pre-duck volumes before any modification (used by release tween).
	_pre_duck_diegetic_db = _music_diegetic.volume_db
	_pre_duck_nondiegetic_db = _music_nondiegetic.volume_db
	var ambient_bus_idx: int = AudioServer.get_bus_index(&"Ambient")
	_pre_duck_ambient_bus_db = AudioServer.get_bus_volume_db(ambient_bus_idx)

	# Compute state-keyed duck depths (Formula 1).
	var diegetic_duck: float = _get_diegetic_duck_for_state()
	var nondiegetic_duck: float = _get_nondiegetic_duck_for_state()

	# Formula 1: target = maxf(current_db + duck_db, -80.0) per GDD §Formula 1.
	var diegetic_target: float = maxf(_pre_duck_diegetic_db + diegetic_duck, -80.0)
	var nondiegetic_target: float = maxf(_pre_duck_nondiegetic_db + nondiegetic_duck, -80.0)
	var ambient_target: float = maxf(_pre_duck_ambient_bus_db + ambient_duck_db, -80.0)

	# Kill any in-flight release tween (attack supersedes release).
	if is_instance_valid(_release_tween) and _release_tween.is_valid():
		_release_tween.kill()

	# Kill any in-flight attack tween (re-trigger guard).
	if is_instance_valid(_attack_tween) and _attack_tween.is_valid():
		_attack_tween.kill()

	# Create parallel attack tween — Voice bus NOT touched (AC-8 invariant).
	_attack_tween = create_tween().set_parallel(true)
	_attack_tween.tween_property(_music_diegetic, "volume_db",
			diegetic_target, vo_duck_attack_s).set_trans(Tween.TRANS_LINEAR)
	_attack_tween.tween_property(_music_nondiegetic, "volume_db",
			nondiegetic_target, vo_duck_attack_s).set_trans(Tween.TRANS_LINEAR)
	_attack_tween.tween_method(
			func(v: float) -> void:
				AudioServer.set_bus_volume_db(ambient_bus_idx, v),
			_pre_duck_ambient_bus_db, ambient_target, vo_duck_attack_s)


## Dialogue domain: the active voiced dialogue line finished.
##
## Implements: Story AUD-004 AC-2, AC-3 (VO release + interrupt safety).
## Kills the attack tween if still running (AC-3: release starts from the LIVE
## current volume, not the attack target). Creates a parallel release tween
## over vo_duck_release_s back to the pre-duck stored values.
func _on_dialogue_line_finished(_speaker_id: StringName) -> void:
	# Kill in-progress attack tween — release starts from LIVE volume (AC-3).
	if is_instance_valid(_attack_tween) and _attack_tween.is_valid():
		_attack_tween.kill()

	# Read live ambient bus volume at the moment of kill (may be partially ducked).
	var ambient_bus_idx: int = AudioServer.get_bus_index(&"Ambient")
	var live_ambient: float = AudioServer.get_bus_volume_db(ambient_bus_idx)

	_release_tween = create_tween().set_parallel(true)
	_release_tween.tween_property(_music_diegetic, "volume_db",
			_pre_duck_diegetic_db, vo_duck_release_s).set_trans(Tween.TRANS_LINEAR)
	_release_tween.tween_property(_music_nondiegetic, "volume_db",
			_pre_duck_nondiegetic_db, vo_duck_release_s).set_trans(Tween.TRANS_LINEAR)
	_release_tween.tween_method(
			func(v: float) -> void:
				AudioServer.set_bus_volume_db(ambient_bus_idx, v),
			live_ambient, _pre_duck_ambient_bus_db, vo_duck_release_s)


## Mission domain: player entered a level section.
## `reason` is LevelStreamingService.TransitionReason emitted as int (per
## events.gd cross-autoload convention). Cast to TransitionReason at call site.
##
## Handles three of four TransitionReason branches (AUD-003):
##   FORWARD      — 2.0 s ease-in crossfade to plaza_calm + start ambient.
##   NEW_GAME     — 2.0 s ease-in crossfade to plaza_calm + start ambient.
##   LOAD_FROM_SAVE — instant-set volumes (no tween) + start ambient.
##   RESPAWN      — no-op here; respawn_triggered handler (AUD-004) owns this path.
##
## Reverb preset is always applied IN-PLACE first (GDD Rule 2 + AC-5).
func _on_section_entered(section_id: StringName, reason: int) -> void:
	# Mutate the SFX bus reverb IN-PLACE before any crossfade begins (GDD Rule 2).
	_apply_reverb_preset(section_id)
	var transition_reason: LevelStreamingService.TransitionReason = \
			reason as LevelStreamingService.TransitionReason
	match transition_reason:
		LevelStreamingService.TransitionReason.FORWARD:
			_crossfade_music(0.0, -12.0, 2.0, Tween.TRANS_SINE)  # plaza_calm
			_start_ambient_for_section(section_id)
		LevelStreamingService.TransitionReason.NEW_GAME:
			_crossfade_music(0.0, -12.0, 2.0, Tween.TRANS_SINE)  # plaza_calm
			_start_ambient_for_section(section_id)
		LevelStreamingService.TransitionReason.LOAD_FROM_SAVE:
			# Instant-set — no tween ceremony on save-load (GDD §Mission domain).
			_music_diegetic.volume_db = 0.0
			_music_nondiegetic.volume_db = -12.0
			_start_ambient_for_section(section_id)
		LevelStreamingService.TransitionReason.RESPAWN:
			pass  # respawn_triggered handler (AUD-004) owns the fade-in — do NOT crossfade.


## Mission domain: player exited a level section.
## `reason` is LevelStreamingService.TransitionReason emitted as int.
##
## Clears the dominant-guard dict and kills any in-flight crossfade Tween so
## the next section's handler starts from a clean state (GDD §Concurrency
## Policies Rule 4 + AC-4).
func _on_section_exited(_section_id: StringName, _reason: int) -> void:
	_dominant_guard_dict.clear()
	if is_instance_valid(_current_alert_tween) and _current_alert_tween.is_valid():
		_current_alert_tween.kill()


## AI/Stealth domain: an actor's alert state changed.
## Drives the dominant-guard dict and music UNAWARE↔COMBAT crossfades (AC-3).
##
## Updates the guard→state mapping, recomputes the dominant alert level, and
## triggers a crossfade if the music state changes:
##   UNAWARE/SUSPICIOUS/SEARCHING → plaza_calm  (0.0 diegetic, -12.0 nondiegetic)
##   COMBAT                       → plaza_combat (–80.0 diegetic, 0.0 nondiegetic)
##
## ADR-0002 IG 4: actor Node-typed payload checked with is_instance_valid FIRST.
func _on_alert_state_changed(
		actor: Node,
		_old_state: StealthAI.AlertState,
		new_state: StealthAI.AlertState,
		_severity: StealthAI.Severity) -> void:
	# ADR-0002 IG 4: guard Node-typed payload before any dereferencing.
	if not is_instance_valid(actor):
		return
	_dominant_guard_dict[actor] = new_state
	var dominant: StealthAI.AlertState = _compute_dominant_state()
	if dominant == StealthAI.AlertState.COMBAT:
		if _current_music_state != &"plaza_combat":
			_current_music_state = &"plaza_combat"
			_crossfade_music(-80.0, 0.0, 0.3, Tween.TRANS_LINEAR)
	else:
		if _current_music_state != &"plaza_calm":
			_current_music_state = &"plaza_calm"
			_crossfade_music(0.0, -12.0, 0.3, Tween.TRANS_LINEAR)


## AI/Stealth domain: an actor transitioned to a fully-alerted (COMBAT) state.
## Schedules a brass-punch stinger on MusicSting quantized to the next 120 BPM
## downbeat. Suppressed when cause == SCRIPTED (Pillar 1 comedy preservation)
## or severity != MAJOR (only high-salience COMBAT transitions warrant a stinger).
##
## Per-beat-window debounce (§Concurrency Policies Rule 1): at most one stinger
## is scheduled per 0.5 s beat window. A second signal firing within the same
## window is silently discarded (AC-6).
##
## Implements: Story AUD-005 AC-5, AC-6, AC-7, AC-8.
## GDD §States and Transitions §Alert sting quantization + §Concurrency Policies
## Rules 1, 3. ADR-0002 IG 4: is_instance_valid guard before any dereferencing.
func _on_actor_became_alerted(
		actor: Node,
		cause: StealthAI.AlertCause,
		_source_position: Vector3,
		severity: StealthAI.Severity) -> void:
	# ADR-0002 IG 4: check Node-typed payload validity BEFORE any property access.
	if not is_instance_valid(actor):
		return
	# AC-7: SCRIPTED cause suppresses stinger (cutscene force-alert, Pillar 1).
	if cause == StealthAI.AlertCause.SCRIPTED:
		return
	# AC-8: Only MAJOR severity triggers a stinger (MINOR = low-salience transition).
	if severity != StealthAI.Severity.MAJOR:
		return
	# Derive the reference playback position from MusicNonDiegetic.
	# If it is not playing (e.g., section not yet started), fall back to 0.0.
	var current_pos: float = _music_nondiegetic.get_playback_position() \
		if _music_nondiegetic.playing else 0.0
	var offset: float = get_next_beat_offset_s(current_pos, STINGER_BPM)
	var target_beat_time: float = current_pos + offset
	# AC-6: Per-beat-window debounce — discard if already queued for this beat.
	# The beat window at 120 BPM is 0.5 s; we use a tight equality tolerance
	# (0.0001 s) on the absolute beat-position to identify the same window.
	if absf(target_beat_time - _stinger_queued_for_beat_time) < 0.0001:
		return
	_stinger_queued_for_beat_time = target_beat_time
	# Schedule the stinger: play immediately if already on the beat, else delay.
	if offset == 0.0:
		_play_stinger()
	else:
		get_tree().create_timer(offset).timeout.connect(
			func() -> void:
				_play_stinger()
				_stinger_queued_for_beat_time = -INF,
			CONNECT_ONE_SHOT)


# ── AUD-003: Music crossfade + reverb + ambient helpers ────────────────────

## Computes the highest AlertState across all entries in _dominant_guard_dict.
## Returns UNAWARE when the dict is empty (safe default — no active threats).
##
## Used by _on_alert_state_changed to derive the target music state without
## direct coupling to any individual guard actor.
func _compute_dominant_state() -> StealthAI.AlertState:
	var highest: StealthAI.AlertState = StealthAI.AlertState.UNAWARE
	for state: StealthAI.AlertState in _dominant_guard_dict.values():
		if state > highest:
			highest = state
	return highest


## Initiates a parallel volume crossfade on both music players (GDD Rule 6).
##
## Both players are tweened simultaneously via set_parallel(true) so neither
## layer leads the other. The resulting Tween is stored in _current_alert_tween
## so it can be killed on section_exited (AC-4).
##
## Parameters:
##   diegetic_target_db    — target volume_db for MusicDiegetic
##   nondiegetic_target_db — target volume_db for MusicNonDiegetic
##   duration_s            — crossfade duration in seconds
##   trans                 — Tween.TransitionType (SINE for section enters, LINEAR for alert)
func _crossfade_music(diegetic_target_db: float, nondiegetic_target_db: float,
		duration_s: float, trans: Tween.TransitionType) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_music_diegetic, "volume_db", diegetic_target_db, duration_s) \
		.set_trans(trans)
	tween.tween_property(_music_nondiegetic, "volume_db", nondiegetic_target_db, duration_s) \
		.set_trans(trans)
	_current_alert_tween = tween


## Applies the section reverb preset to the SFX bus AudioEffectReverb IN-PLACE.
##
## Mutates room_size, damping, and wet on the existing AudioEffectReverb instance
## rather than removing and re-adding it. Removing would cause an audible click
## during an active crossfade (GDD Rule 2 + AC-5).
##
## Assumes the SFX bus effect at index 0 is an AudioEffectReverb (configured in
## Project Settings → Audio tab). Silently returns if the effect is missing or
## is a different type (defensive — prevents a crash in headless test environments
## where the effect may not be pre-configured).
##
## VS scope: only the Plaza preset is implemented. Additional section presets
## land in Story 003 post-VS (TR-AUD-009 full 5-section library deferred).
func _apply_reverb_preset(section_id: StringName) -> void:
	var sfx_bus_idx: int = AudioServer.get_bus_index(&"SFX")
	if sfx_bus_idx == -1 or AudioServer.get_bus_effect_count(sfx_bus_idx) == 0:
		return
	var effect: AudioEffect = AudioServer.get_bus_effect(sfx_bus_idx, 0)
	if not (effect is AudioEffectReverb):
		return
	var reverb: AudioEffectReverb = effect as AudioEffectReverb
	match section_id:
		&"plaza":
			reverb.room_size = 0.2   # exterior open — short decay
			reverb.damping = 0.8
			reverb.wet = 0.15
		_:
			reverb.room_size = 0.4   # fallback medium room
			reverb.damping = 0.6
			reverb.wet = 0.25


## Starts the ambient loop stream for the given section.
##
## VS STUB: Real audio asset loading is deferred to content production
## (TR-AUD-008 — full music preload at section_entered). A null/placeholder
## stream is acceptable for VS; the `playing` state is what matters for AC-2.
##
## If no stream is loaded, the `play()` call is skipped and a debug note is
## printed (not an error — this is expected during headless tests).
func _start_ambient_for_section(_section_id: StringName) -> void:
	if _ambient_player.stream != null:
		_ambient_player.play()
	else:
		# VS stub: no asset loaded yet (TR-AUD-008 deferred). Playing state
		# cannot be verified via `playing` property without a stream; tests
		# that need to verify ambient start should assign a placeholder stream first.
		print_debug("AudioManager: no ambient stream loaded for section '%s' — skipping play() (TR-AUD-008 deferred)" % _section_id)


# ── AUD-004: Formula 1 duck-depth helpers ─────────────────────────────────

## Returns the diegetic duck depth constant for the current dominant alert state.
##
## Formula 1 mapping (GDD §Formula 1 + AUD-004 Implementation Notes):
##   UNAWARE    → diegetic_duck_calm_db     (-14.0)
##   SUSPICIOUS → diegetic_duck_suspicious_db (-10.0)
##   SEARCHING  → diegetic_duck_searching_db  (-8.0)
##   COMBAT     → diegetic_duck_combat_db     (-6.0)
##
## Called by _on_dialogue_line_started to resolve the per-state duck depth.
func _get_diegetic_duck_for_state() -> float:
	match _compute_dominant_state():
		StealthAI.AlertState.COMBAT:
			return diegetic_duck_combat_db
		StealthAI.AlertState.SEARCHING:
			return diegetic_duck_searching_db
		StealthAI.AlertState.SUSPICIOUS:
			return diegetic_duck_suspicious_db
		_:  # UNAWARE (and any future states before SUSPICIOUS)
			return diegetic_duck_calm_db


## Returns the non-diegetic duck depth constant for the current dominant alert state.
##
## Formula 1 mapping — only 2 distinct values per GDD §Formula 1:
##   UNAWARE / SUSPICIOUS / SEARCHING → nondiegetic_duck_calm_db   (-6.0)
##   COMBAT                           → nondiegetic_duck_combat_db (-4.0)
##
## Called by _on_dialogue_line_started to resolve the per-state duck depth.
func _get_nondiegetic_duck_for_state() -> float:
	if _compute_dominant_state() == StealthAI.AlertState.COMBAT:
		return nondiegetic_duck_combat_db
	return nondiegetic_duck_calm_db


## Returns the Music bus setting offset in dB for use in Formula 1 duck calculations.
##
## VS STUB: Returns 0.0 (slider at max). Real settings integration
## (Events.setting_changed for category &"audio", name &"music_volume") is
## post-VS — deferred to Story AUD-006 (settings persistence epic).
## When real settings land, replace this stub body with a lookup in the
## settings registry (dependency-injected or via a settings autoload).
func _get_setting_music_db() -> float:
	return 0.0


## Returns the Ambient bus setting offset in dB for use in Formula 1 duck calculations.
##
## VS STUB: Returns 0.0 (slider at max). Same deferral rationale as
## _get_setting_music_db(). Real integration lands with AUD-006.
func _get_setting_ambient_db() -> float:
	return 0.0


# ── AUD-005: Footstep variant selection + SFX pool helpers ────────────────

## Classifies noise_radius_m into one of 4 FootstepVariant buckets.
## Thresholds from GDD §Footstep Surface Map (AC-1, AC-2, AC-3):
##   SOFT    : ≤ 3.5 m  (crouch-walk)
##   NORMAL  : > 3.5 – 6.5 m (walk)
##   LOUD    : > 6.5 – 10.0 m (jog)
##   EXTREME : > 10.0 m       (sprint)
##
## Note: noise_radius_m == 0.0 (crouch-idle) is handled upstream by
## _on_player_footstep before this function is reached (AC-2 silent threshold).
func _select_footstep_variant(noise_radius_m: float) -> FootstepVariant:
	if noise_radius_m <= 3.5:
		return FootstepVariant.SOFT
	elif noise_radius_m <= 6.5:
		return FootstepVariant.NORMAL
	elif noise_radius_m <= 10.0:
		return FootstepVariant.LOUD
	else:
		return FootstepVariant.EXTREME


## Loads the AudioStream for the given surface+variant key (e.g. "marble_normal").
##
## VS STUB: Returns null — audio asset production deferred to post-VS content
## pipeline. The variant key routing and pool slot selection are fully verified
## by unit tests using null stream as a stub (story spec §VS simplification).
##
## TODO(TR-AUD-007): Replace with real asset loading from the footstep library
## once audio assets are produced. Likely: load("res://assets/audio/sfx/footsteps/%s.ogg" % key)
## or a preloaded ResourcePreloader lookup.
func _load_footstep_stream(_variant_key: String) -> AudioStream:
	return null  # TR-AUD-007 deferred — asset loading post-VS


## Returns an idle SFX pool slot, or steals the oldest-started non-exempt slot.
##
## First pass: return the first AudioStreamPlayer3D that is not playing (idle).
## Second pass: among all playing slots, skip those on the &"Voice" or &"UI"
## bus (exempt per GDD §Edge Cases — "voice and UI are exempt from steal").
## Among the remaining slots, return the one with the highest
## get_playback_position() — i.e., the slot that has been playing longest
## and therefore has least remaining content (oldest-started proxy).
##
## Returns null if every slot is on an exempt bus — this is unreachable in VS
## because the pool is exclusively on the SFX bus, but the null guard in
## _on_player_footstep handles it defensively.
##
## Implements: Story AUD-005 AC-4.
## GDD Rule 5 (pool steal) + GDD §Edge Cases (Voice/UI exemption).
## GDD Rule 9: NO AudioStreamPlayer3D.new() call — fixed-size pool only.
func _get_or_steal_sfx_slot() -> AudioStreamPlayer3D:
	# First pass: find an idle (not playing) slot — Voice/UI buses are exempt
	# from selection in BOTH passes (GDD Edge Case — "voice and UI are exempt"
	# applies to allocation, not just stealing).
	for player: AudioStreamPlayer3D in _sfx_pool:
		if player.bus == &"Voice" or player.bus == &"UI":
			continue
		if not player.playing:
			return player
	# Second pass: steal oldest non-exempt slot.
	var oldest_player: AudioStreamPlayer3D = null
	var oldest_pos: float = -INF
	for player: AudioStreamPlayer3D in _sfx_pool:
		# Exempt: Voice and UI buses must never be stolen.
		if player.bus == &"Voice" or player.bus == &"UI":
			continue
		# "Oldest started" = highest playback_position (most stream consumed).
		if player.get_playback_position() > oldest_pos:
			oldest_pos = player.get_playback_position()
			oldest_player = player
	return oldest_player


## Returns the current world-space position of the player character.
##
## VS STUB: Returns Vector3.ZERO until the PlayerCharacter reference is
## available via dependency injection. Spatial accuracy is deferred to the
## PlayerCharacter integration sprint.
##
## TODO: Replace with a real PlayerCharacter reference (injected or resolved
## via a group query) once the PlayerCharacter node is stable in the scene tree.
func _get_player_position() -> Vector3:
	return Vector3.ZERO  # VS stub — real reference deferred to PlayerCharacter integration


# ── AUD-005: Stinger beat quantization (pure static helper) ───────────────

## Computes the time in seconds until the next downbeat from the given playback
## position at the specified BPM.
##
## Pure static function — no scene-tree dependencies. Deterministically unit-
## testable without a running AudioStreamPlayer (GdUnit4 AC-9 parametrized table).
##
## At 120 BPM: beat_interval_s = 0.5 s. Examples:
##   current_playback_pos_s = 0.0  → 0.0  (already on the beat)
##   current_playback_pos_s = 0.1  → 0.4  (0.4 s to next beat)
##   current_playback_pos_s = 0.5  → 0.0  (exactly on the beat — fmod = 0)
##
## If pos_in_beat < 0.0001 s, the position is considered on-beat (returns 0.0)
## to avoid scheduling a near-zero-offset timer due to float precision.
##
## Implements: Story AUD-005 AC-9.
## GDD §States and Transitions §Alert sting quantization.
static func get_next_beat_offset_s(current_playback_pos_s: float, bpm: float) -> float:
	var beat_interval_s: float = 60.0 / bpm
	var pos_in_beat: float = fmod(current_playback_pos_s, beat_interval_s)
	if pos_in_beat < 0.0001:
		return 0.0  # on the beat already — play immediately
	return beat_interval_s - pos_in_beat


## Fires the MusicSting one-shot stinger player.
## Stops any currently-playing sting first (prevents overlap on fast re-alerts).
## Called directly when offset == 0.0, or from the deferred timer callback.
##
## Implements: Story AUD-005 AC-5 (stinger fires at next downbeat).
func _play_stinger() -> void:
	if not is_instance_valid(_music_sting):
		return
	_music_sting.stop()
	_music_sting.play()
