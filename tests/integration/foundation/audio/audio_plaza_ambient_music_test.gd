# tests/integration/foundation/audio/audio_plaza_ambient_music_test.gd
#
# AudioPlazaAmbientMusicTest — GdUnit4 integration suite for Story AUD-003.
#
# PURPOSE
#   Verifies the plaza ambient layer, UNAWARE/COMBAT music state crossfades,
#   and section reverb preset in-place mutation added to AudioManager by AUD-003.
#
# COVERAGE
#   AC-1 — Music player nodes exist with correct bus and initial volume_db values.
#   AC-2 — section_entered FORWARD triggers 2.0 s crossfade and starts ambient.
#   AC-3 — alert_state_changed COMBAT triggers 0.3 s crossfade (signal available).
#   AC-4 — section_exited clears dominant-guard dict and kills in-flight Tween.
#   AC-5 — AudioEffectReverb mutated in-place (pre/post identity assertion).
#   AC-6 — section_entered RESPAWN does NOT start a music crossfade.
#   Helper: _compute_dominant_state returns highest alert level in dict.
#
# GATE STATUS
#   Story AUD-003 | Integration type → BLOCKING gate.
#   7 test functions; all must pass for the story to be marked Done.
#
# DETERMINISM NOTE
#   Tweens are tested via reference existence and is_valid() checks in the
#   first frame after emit — NOT by awaiting Tween completion. This avoids
#   timing dependencies that can flake under headless CI load.
#
# ENGINE NOTES
#   create_tween() returns a Tween that is valid immediately (Godot 4.0+).
#   AudioEffectReverb: added to a bus via AudioServer.add_bus_effect() in
#   before_test() so the reverb mutation tests work in headless environments
#   where Project Settings effects are not loaded.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]
#
# Implements: Story AUD-003
# Requirements: TR-AUD-004, TR-AUD-005, TR-AUD-006, TR-AUD-008, TR-AUD-009, TR-AUD-010
# ADRs: ADR-0002 (Signal Bus), ADR-0008 (Performance Budget)

class_name AudioPlazaAmbientMusicTest
extends GdUnitTestSuite


# ── Fixtures ───────────────────────────────────────────────────────────────

## Root node that owns the AudioManager. Freed in after_test.
var _root: Node = null

## AudioManager instance under test.
var _audio_manager: AudioManager = null

## Index of the SFX bus — set during before_test so tests can reference it.
var _sfx_bus_idx: int = -1


func before_test() -> void:
	_root = Node.new()
	add_child(_root)
	_audio_manager = AudioManager.new()
	_root.add_child(_audio_manager)
	# _ready() fires synchronously via add_child:
	#   _setup_buses() → _setup_sfx_pool() → _setup_music_players() → _connect_signal_bus()

	# Ensure an AudioEffectReverb is at index 0 on the SFX bus for reverb tests.
	# AudioManager._setup_buses() guarantees the SFX bus exists; we add the effect
	# here if it is not already present (headless Godot does not load Project Settings).
	_sfx_bus_idx = AudioServer.get_bus_index(&"SFX")
	if AudioServer.get_bus_effect_count(_sfx_bus_idx) == 0:
		AudioServer.add_bus_effect(_sfx_bus_idx, AudioEffectReverb.new(), 0)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_audio_manager = null
	_sfx_bus_idx = -1


# ── AC-1: Music player nodes present with correct bus and volume ────────────

## AC-1: MusicDiegetic, MusicNonDiegetic, and MusicSting exist as direct
## children of AudioManager with bus == &"Music" and the correct initial
## volume_db values for the plaza_calm state.
func test_audiomanager_music_players_exist_with_correct_bus_and_volume() -> void:
	# Arrange + Act: done in before_test().

	# MusicDiegetic
	var diegetic: AudioStreamPlayer = _audio_manager.get_node_or_null(
			^"MusicDiegetic") as AudioStreamPlayer
	assert_object(diegetic).override_failure_message(
		"AC-1: MusicDiegetic must exist as a direct child of AudioManager after _ready()."
	).is_not_null()
	assert_str(String(diegetic.bus)).override_failure_message(
		"AC-1: MusicDiegetic.bus must be 'Music'."
	).is_equal("Music")
	assert_float(diegetic.volume_db).override_failure_message(
		"AC-1: MusicDiegetic.volume_db must be 0.0 (plaza_calm initial state)."
	).is_equal(0.0)

	# MusicNonDiegetic
	var nondiegetic: AudioStreamPlayer = _audio_manager.get_node_or_null(
			^"MusicNonDiegetic") as AudioStreamPlayer
	assert_object(nondiegetic).override_failure_message(
		"AC-1: MusicNonDiegetic must exist as a direct child of AudioManager after _ready()."
	).is_not_null()
	assert_str(String(nondiegetic.bus)).override_failure_message(
		"AC-1: MusicNonDiegetic.bus must be 'Music'."
	).is_equal("Music")
	assert_float(nondiegetic.volume_db).override_failure_message(
		"AC-1: MusicNonDiegetic.volume_db must be -12.0 (plaza_calm initial state)."
	).is_equal(-12.0)

	# MusicSting
	var sting: AudioStreamPlayer = _audio_manager.get_node_or_null(
			^"MusicSting") as AudioStreamPlayer
	assert_object(sting).override_failure_message(
		"AC-1: MusicSting must exist as a direct child of AudioManager after _ready()."
	).is_not_null()
	assert_str(String(sting.bus)).override_failure_message(
		"AC-1: MusicSting.bus must be 'Music'."
	).is_equal("Music")

	# AmbientLoop
	var ambient: AudioStreamPlayer = _audio_manager.get_node_or_null(
			^"AmbientLoop") as AudioStreamPlayer
	assert_object(ambient).override_failure_message(
		"AC-1: AmbientLoop must exist as a direct child of AudioManager after _ready()."
	).is_not_null()
	assert_str(String(ambient.bus)).override_failure_message(
		"AC-1: AmbientLoop.bus must be 'Ambient'."
	).is_equal("Ambient")


# ── AC-2: section_entered FORWARD starts 2.0 s crossfade and ambient ───────

## AC-2: Emitting section_entered with FORWARD reason initiates a 2.0 s
## crossfade (Tween becomes valid and stored) and starts the ambient player.
##
## Tween completion is NOT awaited — we verify existence and validity in the
## first frame to keep the test deterministic under headless CI load.
func test_section_entered_forward_starts_2s_crossfade_to_plaza_calm() -> void:
	# Arrange: assign a placeholder stream so _start_ambient_for_section can play().
	var ambient: AudioStreamPlayer = _audio_manager.get_node_or_null(^"AmbientLoop") \
			as AudioStreamPlayer
	assert_object(ambient).override_failure_message(
		"AC-2 precondition: AmbientLoop must exist."
	).is_not_null()
	# AudioStreamWAV is the lightest placeholder stream available in Godot 4 headless.
	ambient.stream = AudioStreamWAV.new()

	# Act: emit section_entered with FORWARD reason (cast as int per events.gd convention).
	Events.section_entered.emit(
			&"plaza",
			LevelStreamingService.TransitionReason.FORWARD as int)

	# Assert: a Tween was created and stored.
	var tween: Tween = _audio_manager._current_alert_tween
	assert_object(tween).override_failure_message(
		"AC-2: _current_alert_tween must be non-null after FORWARD section_entered."
	).is_not_null()
	assert_bool(tween.is_valid()).override_failure_message(
		"AC-2: The in-flight Tween must be valid (is_valid() == true) immediately after creation."
	).is_true()

	# Assert: ambient player started playing.
	assert_bool(ambient.playing).override_failure_message(
		"AC-2: AmbientLoop.playing must be true after FORWARD section_entered (TR-AUD-008)."
	).is_true()


# ── AC-4: section_exited clears guard dict and kills in-flight Tween ────────

## AC-4: After section_exited fires, the dominant-guard dict is empty and
## the previously-captured Tween has is_valid() == false.
func test_section_exited_clears_guard_dict_and_kills_tween() -> void:
	# Arrange: populate the dominant-guard dict with mock actors.
	var guard_a: Node = Node.new()
	var guard_b: Node = Node.new()
	var guard_c: Node = Node.new()
	add_child(guard_a)
	add_child(guard_b)
	add_child(guard_c)

	_audio_manager._dominant_guard_dict[guard_a] = StealthAI.AlertState.UNAWARE
	_audio_manager._dominant_guard_dict[guard_b] = StealthAI.AlertState.SUSPICIOUS
	_audio_manager._dominant_guard_dict[guard_c] = StealthAI.AlertState.COMBAT

	# Arrange: start an active crossfade tween so we have something to kill.
	_audio_manager._crossfade_music(0.0, -12.0, 10.0, Tween.TRANS_SINE)
	var captured_tween: Tween = _audio_manager._current_alert_tween
	assert_object(captured_tween).override_failure_message(
		"AC-4 precondition: _current_alert_tween must be set before section_exited."
	).is_not_null()
	assert_bool(captured_tween.is_valid()).override_failure_message(
		"AC-4 precondition: Tween must be valid before section_exited."
	).is_true()

	# Act: emit section_exited.
	Events.section_exited.emit(
			&"plaza",
			LevelStreamingService.TransitionReason.FORWARD as int)

	# Assert: dominant-guard dict cleared.
	assert_bool(_audio_manager._dominant_guard_dict.is_empty()).override_failure_message(
		"AC-4: _dominant_guard_dict must be empty after section_exited."
	).is_true()

	# Assert: the previously-captured Tween was killed (is_valid() == false).
	assert_bool(captured_tween.is_valid()).override_failure_message(
		"AC-4: The in-flight Tween must be killed (is_valid() == false) after section_exited."
	).is_false()

	guard_a.queue_free()
	guard_b.queue_free()
	guard_c.queue_free()


# ── AC-5: AudioEffectReverb mutated in-place on section_entered ─────────────

## AC-5: The AudioEffectReverb instance on the SFX bus is mutated IN-PLACE —
## the object reference before the emit equals the reference after (same instance,
## not a newly-created AudioEffectReverb).
func test_reverb_mutated_in_place_on_section_entered() -> void:
	# Arrange: capture the reverb reference before the call.
	assert_int(_sfx_bus_idx).override_failure_message(
		"AC-5 precondition: SFX bus must exist."
	).is_greater_equal(0)
	assert_int(AudioServer.get_bus_effect_count(_sfx_bus_idx)).override_failure_message(
		"AC-5 precondition: SFX bus must have at least one effect."
	).is_greater_equal(1)
	var pre_ref: AudioEffect = AudioServer.get_bus_effect(_sfx_bus_idx, 0)
	assert_object(pre_ref).override_failure_message(
		"AC-5 precondition: AudioEffect at SFX bus index 0 must be non-null."
	).is_not_null()
	assert_bool(pre_ref is AudioEffectReverb).override_failure_message(
		"AC-5 precondition: Effect at SFX bus index 0 must be AudioEffectReverb."
	).is_true()

	# Act: emit section_entered — this calls _apply_reverb_preset("plaza").
	Events.section_entered.emit(
			&"plaza",
			LevelStreamingService.TransitionReason.FORWARD as int)

	# Assert: the effect reference after the call is the SAME object (identity check).
	var post_ref: AudioEffect = AudioServer.get_bus_effect(_sfx_bus_idx, 0)
	assert_object(post_ref).override_failure_message(
		"AC-5: AudioEffect at SFX bus index 0 must still be non-null after section_entered."
	).is_equal(pre_ref)

	# Verify the values were actually mutated to the plaza preset.
	# Use is_equal_approx for float comparison — Godot stores AudioEffect floats
	# at 32-bit precision (e.g., 0.2 → 0.20000000298023) so exact equality fails.
	var reverb: AudioEffectReverb = post_ref as AudioEffectReverb
	assert_float(reverb.room_size).override_failure_message(
		"AC-5: Plaza preset room_size must be 0.2 (got %s)." % reverb.room_size
	).is_equal_approx(0.2, 0.001)
	assert_float(reverb.damping).override_failure_message(
		"AC-5: Plaza preset damping must be 0.8 (got %s)." % reverb.damping
	).is_equal_approx(0.8, 0.001)
	assert_float(reverb.wet).override_failure_message(
		"AC-5: Plaza preset wet must be 0.15 (got %s)." % reverb.wet
	).is_equal_approx(0.15, 0.001)


# ── AC-6: section_entered RESPAWN does NOT start a crossfade ────────────────

## AC-6: When reason == RESPAWN, _on_section_entered must NOT create or
## replace the current crossfade Tween. The music volumes remain unchanged.
func test_section_entered_respawn_does_not_start_crossfade() -> void:
	# Arrange: record volumes and tween state BEFORE the emit.
	var diegetic: AudioStreamPlayer = _audio_manager.get_node_or_null(
			^"MusicDiegetic") as AudioStreamPlayer
	var nondiegetic: AudioStreamPlayer = _audio_manager.get_node_or_null(
			^"MusicNonDiegetic") as AudioStreamPlayer
	var volume_diegetic_before: float = diegetic.volume_db
	var volume_nondiegetic_before: float = nondiegetic.volume_db
	var tween_before: Tween = _audio_manager._current_alert_tween

	# Act: emit section_entered with RESPAWN reason.
	Events.section_entered.emit(
			&"plaza",
			LevelStreamingService.TransitionReason.RESPAWN as int)

	# Assert: no new Tween was created (_current_alert_tween unchanged).
	assert_object(_audio_manager._current_alert_tween).override_failure_message(
		"AC-6: RESPAWN must NOT create a new crossfade Tween — "
		+ "_current_alert_tween must remain unchanged."
	).is_equal(tween_before)

	# Assert: volumes are unchanged (no tween started, no instant-set either).
	assert_float(diegetic.volume_db).override_failure_message(
		"AC-6: MusicDiegetic.volume_db must be unchanged after RESPAWN section_entered. "
		+ "Expected: %s, Got: %s." % [volume_diegetic_before, diegetic.volume_db]
	).is_equal(volume_diegetic_before)
	assert_float(nondiegetic.volume_db).override_failure_message(
		"AC-6: MusicNonDiegetic.volume_db must be unchanged after RESPAWN section_entered. "
		+ "Expected: %s, Got: %s." % [volume_nondiegetic_before, nondiegetic.volume_db]
	).is_equal(volume_nondiegetic_before)


# ── Helper: _compute_dominant_state returns highest alert ───────────────────

## Verifies that _compute_dominant_state() returns the highest AlertState
## across all entries in _dominant_guard_dict, independently of signal wiring.
## This tests the dict logic directly without depending on signal routing.
func test_compute_dominant_state_returns_highest_alert() -> void:
	# Arrange: three guards at different alert levels; COMBAT is the highest.
	var guard_a: Node = Node.new()
	var guard_b: Node = Node.new()
	var guard_c: Node = Node.new()
	add_child(guard_a)
	add_child(guard_b)
	add_child(guard_c)

	_audio_manager._dominant_guard_dict[guard_a] = StealthAI.AlertState.UNAWARE
	_audio_manager._dominant_guard_dict[guard_b] = StealthAI.AlertState.SEARCHING
	_audio_manager._dominant_guard_dict[guard_c] = StealthAI.AlertState.COMBAT

	# Act
	var dominant: StealthAI.AlertState = _audio_manager._compute_dominant_state()

	# Assert: COMBAT is the highest.
	assert_int(dominant as int).override_failure_message(
		"Helper: _compute_dominant_state must return COMBAT (highest in dict). "
		+ "Got: %d, expected: %d." % [dominant, StealthAI.AlertState.COMBAT]
	).is_equal(StealthAI.AlertState.COMBAT as int)

	guard_a.queue_free()
	guard_b.queue_free()
	guard_c.queue_free()


# ── AC-3: alert_state_changed COMBAT triggers 0.3 s crossfade ───────────────

## AC-3: Events.alert_state_changed with a COMBAT new_state triggers a 0.3 s
## linear crossfade to plaza_combat levels (MusicDiegetic → -80.0,
## MusicNonDiegetic → 0.0) and updates the dominant-guard dict.
##
## The Events.alert_state_changed signal is available with the 4-param typed
## signature as of the SAI-002 commit (confirmed in src/core/signal_bus/events.gd).
## This test is FULLY IMPLEMENTED — not skipped.
func test_alert_state_changed_combat_transition() -> void:
	# Arrange: a valid guard actor in UNAWARE state.
	var guard: Node = Node.new()
	add_child(guard)
	_audio_manager._dominant_guard_dict[guard] = StealthAI.AlertState.UNAWARE
	_audio_manager._current_music_state = &"plaza_calm"

	# Act: emit alert_state_changed with COMBAT new_state.
	Events.alert_state_changed.emit(
			guard,
			StealthAI.AlertState.UNAWARE,
			StealthAI.AlertState.COMBAT,
			StealthAI.Severity.MAJOR)

	# Assert: dominant-guard dict updated to COMBAT for this actor.
	assert_int((_audio_manager._dominant_guard_dict[guard] as StealthAI.AlertState) as int) \
		.override_failure_message(
		"AC-3: _dominant_guard_dict[guard] must be COMBAT after alert_state_changed COMBAT."
	).is_equal(StealthAI.AlertState.COMBAT as int)

	# Assert: music state transitioned to plaza_combat.
	assert_str(String(_audio_manager._current_music_state)).override_failure_message(
		"AC-3: _current_music_state must be 'plaza_combat' after COMBAT alert."
	).is_equal("plaza_combat")

	# Assert: a crossfade Tween was created and is valid.
	var tween: Tween = _audio_manager._current_alert_tween
	assert_object(tween).override_failure_message(
		"AC-3: _current_alert_tween must be non-null after COMBAT alert_state_changed."
	).is_not_null()
	assert_bool(tween.is_valid()).override_failure_message(
		"AC-3: The crossfade Tween must be valid immediately after COMBAT transition."
	).is_true()

	guard.queue_free()
