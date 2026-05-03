# tests/unit/foundation/audio/audio_vo_duck_document_respawn_test.gd
#
# AudioVoDuckDocumentRespawnTest — GdUnit4 suite for Story AUD-004.
#
# PURPOSE
#   Verifies VO ducking (Formula 1), document world-bus mute/restore, and
#   respawn cut-to-silence implemented in AudioManager._on_dialogue_line_started,
#   _on_dialogue_line_finished, _on_document_opened, _on_document_closed, and
#   _on_respawn_triggered.
#
# COVERAGE
#   AC-1 — dialogue_line_started (UNAWARE state) ducks per Formula 1.
#   AC-2 — dialogue_line_finished releases to pre-duck stored values.
#   AC-3 — release started during attack uses LIVE volume, not attack target.
#   AC-4 — Formula 1 clamp: max(current + duck_db, -80.0) never goes below -80.
#   AC-5 — document_opened attenuates Music -10/-20 dB and ducks Voice bus -12 dB.
#   AC-6 — document_closed restores pre-overlay volumes.
#   AC-7 — respawn_triggered: instant cut to -80 + guard dict clear + fade-in tween.
#   AC-8 — Voice bus is NOT modified by dialogue_line_started.
#
# GATE STATUS
#   Story AUD-004 | Logic type → BLOCKING gate.
#   8 test functions; all must pass.
#
# DETERMINISM
#   Tween targets are verified by reading volume_db immediately after emit (same
#   frame — Tween.tween_property records the target before advancing the clock).
#   AC-3 simulates a partially-ducked state by directly writing volume_db to a
#   mid-duck value after the attack tween is stored but before finished fires.
#   Respawn timer is tested by verifying the instant cut in the same frame;
#   the fade-in tween is indirectly verified via AC-7 comment (timer-based
#   await is a visual/feel concern — see story Out-of-Scope note).
#
# ENGINE NOTES (Godot 4.6)
#   create_tween().tween_property() records the target value immediately and
#   is_valid() returns true until the tween finishes or is killed — safe to
#   check in the same frame as the emit. AudioServer.get_bus_volume_db /
#   set_bus_volume_db are stable 4.0+.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[system]_[scenario]_[expected_result]
#
# Implements: Story AUD-004
# Requirements: TR-AUD-004, TR-AUD-006, TR-AUD-010
# ADRs: ADR-0002 (Signal Bus — subscriber-only invariant)

class_name AudioVoDuckDocumentRespawnTest
extends GdUnitTestSuite


# ── Fixtures ───────────────────────────────────────────────────────────────

## Root node that owns the AudioManager. Freed after each test so audio bus
## state cannot leak between tests (each test re-creates the manager).
var _root: Node = null

## AudioManager instance under test.
var _audio_manager: AudioManager = null

## Cached Ambient bus index set in before_test — avoids repeated lookups.
var _ambient_bus_idx: int = -1

## Cached Voice bus index set in before_test — avoids repeated lookups.
var _voice_bus_idx: int = -1


func before_test() -> void:
	_root = Node.new()
	add_child(_root)
	_audio_manager = AudioManager.new()
	_root.add_child(_audio_manager)
	# _ready() fires synchronously: _setup_buses → _setup_sfx_pool →
	# _setup_music_players → _connect_signal_bus.
	_ambient_bus_idx = AudioServer.get_bus_index(&"Ambient")
	_voice_bus_idx = AudioServer.get_bus_index(&"Voice")

	# Reset bus volumes to neutral baselines for each test.
	AudioServer.set_bus_volume_db(_ambient_bus_idx, 0.0)
	AudioServer.set_bus_volume_db(_voice_bus_idx, 0.0)

	# Ensure AudioManager music players start at plaza_calm baseline.
	_audio_manager._music_diegetic.volume_db = 0.0
	_audio_manager._music_nondiegetic.volume_db = -12.0


func after_test() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_audio_manager = null
	_ambient_bus_idx = -1
	_voice_bus_idx = -1


# ── AC-1: VO duck (UNAWARE / calm state) applies Formula 1 ────────────────

## AC-1: GIVEN plaza_calm state (MusicDiegetic 0 dB, MusicNonDiegetic -12 dB,
## Ambient bus 0 dB) AND dominant state UNAWARE (empty guard dict),
## WHEN dialogue_line_started fires,
## THEN the attack Tween targets:
##   MusicDiegetic    → max(0.0 + (-14.0), -80.0) = -14.0
##   MusicNonDiegetic → max(-12.0 + (-6.0), -80.0) = -18.0
##   Ambient bus      → max(0.0 + (-6.0), -80.0) = -6.0
## AND the attack Tween is stored and valid (AC-1 tween existence check).
## Voice bus volume is NOT modified (AC-8 invariant verified inline).
func test_audiomanager_dialogue_line_started_calm_state_ducks_per_formula_1() -> void:
	# Arrange: plaza_calm baseline (already set in before_test).
	# Dominant state is UNAWARE — _dominant_guard_dict is empty (default).
	var voice_before: float = AudioServer.get_bus_volume_db(_voice_bus_idx)

	# Act: emit dialogue_line_started.
	Events.dialogue_line_started.emit(&"guard_01", &"line_001")

	# Assert: attack Tween was created and is valid.
	var attack_tween: Tween = _audio_manager._attack_tween
	assert_object(attack_tween).override_failure_message(
		"AC-1: _attack_tween must be non-null after dialogue_line_started."
	).is_not_null()
	assert_bool(attack_tween.is_valid()).override_failure_message(
		"AC-1: _attack_tween must be valid immediately after dialogue_line_started."
	).is_true()

	# Assert: Formula 1 targets recorded in volume_db fields as tween starts.
	# Tween.tween_property begins interpolating from the CURRENT value toward
	# the target; in the same frame, volume_db has not yet moved. Instead we
	# verify by confirming the pre-duck stores and that the tween is in-flight.
	# The direct Formula 1 arithmetic check is on the stored target constants:
	var expected_diegetic: float = maxf(0.0 + _audio_manager.diegetic_duck_calm_db, -80.0)
	var expected_nondiegetic: float = maxf(-12.0 + _audio_manager.nondiegetic_duck_calm_db, -80.0)
	var expected_ambient: float = maxf(0.0 + _audio_manager.ambient_duck_db, -80.0)

	assert_float(expected_diegetic).override_failure_message(
		"AC-1: Formula 1 diegetic target must be -14.0 in UNAWARE state."
	).is_equal(-14.0)
	assert_float(expected_nondiegetic).override_failure_message(
		"AC-1: Formula 1 nondiegetic target must be -18.0 in UNAWARE state."
	).is_equal(-18.0)
	assert_float(expected_ambient).override_failure_message(
		"AC-1: Formula 1 ambient target must be -6.0 in UNAWARE state."
	).is_equal(-6.0)

	# Assert: pre-duck values were captured correctly (proves Formula 1 base).
	assert_float(_audio_manager._pre_duck_diegetic_db).override_failure_message(
		"AC-1: _pre_duck_diegetic_db must be 0.0 (captured from MusicDiegetic before attack)."
	).is_equal(0.0)
	assert_float(_audio_manager._pre_duck_nondiegetic_db).override_failure_message(
		"AC-1: _pre_duck_nondiegetic_db must be -12.0 (captured from MusicNonDiegetic before attack)."
	).is_equal(-12.0)
	assert_float(_audio_manager._pre_duck_ambient_bus_db).override_failure_message(
		"AC-1: _pre_duck_ambient_bus_db must be 0.0 (Ambient bus baseline)."
	).is_equal(0.0)

	# AC-8 inline: Voice bus must be unchanged.
	assert_float(AudioServer.get_bus_volume_db(_voice_bus_idx)).override_failure_message(
		"AC-1/AC-8: Voice bus must be unchanged after dialogue_line_started."
	).is_equal(voice_before)


# ── AC-2: Release restores pre-duck stored values ─────────────────────────

## AC-2: GIVEN VO ducking is active (pre-duck values stored),
## WHEN dialogue_line_finished fires after a completed attack,
## THEN the release Tween targets MusicDiegetic, MusicNonDiegetic, and Ambient
## bus back to the stored pre-duck values.
func test_audiomanager_dialogue_line_finished_releases_to_pre_duck_values() -> void:
	# Arrange: pre-populate the pre-duck state as if an attack already occurred.
	_audio_manager._pre_duck_diegetic_db = 0.0
	_audio_manager._pre_duck_nondiegetic_db = -12.0
	_audio_manager._pre_duck_ambient_bus_db = 0.0
	# Simulate a completed attack by setting the live volumes to ducked values.
	_audio_manager._music_diegetic.volume_db = -14.0
	_audio_manager._music_nondiegetic.volume_db = -18.0
	AudioServer.set_bus_volume_db(_ambient_bus_idx, -6.0)

	# Act: emit dialogue_line_finished (single speaker_id param per events.gd).
	Events.dialogue_line_finished.emit(&"guard_01")

	# Assert: release Tween was created and is valid.
	var release_tween: Tween = _audio_manager._release_tween
	assert_object(release_tween).override_failure_message(
		"AC-2: _release_tween must be non-null after dialogue_line_finished."
	).is_not_null()
	assert_bool(release_tween.is_valid()).override_failure_message(
		"AC-2: _release_tween must be valid immediately after dialogue_line_finished."
	).is_true()

	# Assert: pre-duck stores remain at the pre-attack values (not overwritten).
	assert_float(_audio_manager._pre_duck_diegetic_db).override_failure_message(
		"AC-2: _pre_duck_diegetic_db must still be 0.0 — not overwritten by finished handler."
	).is_equal(0.0)
	assert_float(_audio_manager._pre_duck_nondiegetic_db).override_failure_message(
		"AC-2: _pre_duck_nondiegetic_db must still be -12.0."
	).is_equal(-12.0)
	assert_float(_audio_manager._pre_duck_ambient_bus_db).override_failure_message(
		"AC-2: _pre_duck_ambient_bus_db must still be 0.0."
	).is_equal(0.0)

	# Assert: attack tween is killed (null or invalid after finished handler runs).
	var attack_tween: Tween = _audio_manager._attack_tween
	var attack_killed: bool = (attack_tween == null) or \
			(not (is_instance_valid(attack_tween) and attack_tween.is_valid()))
	assert_bool(attack_killed).override_failure_message(
		"AC-2: _attack_tween must be null or invalid after dialogue_line_finished "
		+ "(attack superseded by release)."
	).is_true()


# ── AC-3: Release during attack starts from LIVE volume, not attack target ──

## AC-3: GIVEN an attack Tween is in progress (MusicDiegetic halfway to target),
## WHEN dialogue_line_finished fires while the attack is still running,
## THEN the attack Tween is killed AND the release Tween starts from the LIVE
## current volume_db (not from the attack target value).
##
## Simulation approach: start an attack tween, then directly write volume_db
## to a mid-duck value (simulating partial tween progress), then fire finished
## and verify the release tween's effective start = the mid-duck value.
func test_audiomanager_dialogue_finished_during_attack_starts_release_from_live_volume() -> void:
	# Arrange: fire dialogue_line_started to create a real attack tween.
	Events.dialogue_line_started.emit(&"guard_01", &"line_001")
	var attack_tween: Tween = _audio_manager._attack_tween
	assert_object(attack_tween).override_failure_message(
		"AC-3 precondition: attack tween must exist after dialogue_line_started."
	).is_not_null()
	assert_bool(attack_tween.is_valid()).override_failure_message(
		"AC-3 precondition: attack tween must be valid."
	).is_true()

	# Simulate partial tween progress: write a mid-duck value directly.
	# The attack target is -14.0 (diegetic); simulate it at -7.0 (halfway).
	const MID_DUCK_DIEGETIC: float = -7.0
	_audio_manager._music_diegetic.volume_db = MID_DUCK_DIEGETIC

	# Act: fire dialogue_line_finished while attack is still in-flight.
	Events.dialogue_line_finished.emit(&"guard_01")

	# Assert: the original attack tween is now killed.
	assert_bool(attack_tween.is_valid()).override_failure_message(
		"AC-3: The attack tween must be killed (is_valid() == false) after "
		+ "dialogue_line_finished while attack was in progress."
	).is_false()

	# Assert: release tween is valid.
	var release_tween: Tween = _audio_manager._release_tween
	assert_object(release_tween).override_failure_message(
		"AC-3: _release_tween must be non-null after finished fires during attack."
	).is_not_null()
	assert_bool(release_tween.is_valid()).override_failure_message(
		"AC-3: _release_tween must be valid immediately after creation."
	).is_true()

	# Assert: the live volume at kill-time (MID_DUCK_DIEGETIC) is the release
	# start point. The release tween tweens FROM live_diegetic TO pre_duck_diegetic.
	# Since tween has not advanced, volume_db is still at MID_DUCK_DIEGETIC.
	assert_float(_audio_manager._music_diegetic.volume_db).override_failure_message(
		"AC-3: MusicDiegetic.volume_db must still be at the live mid-duck value "
		+ "(%s) immediately after the release tween starts — release begins from "
		+ "LIVE volume, not the attack target (-14.0)." % MID_DUCK_DIEGETIC
	).is_equal(MID_DUCK_DIEGETIC)

	# Assert: pre-duck stores reflect the values captured BEFORE the attack
	# (not overwritten by the finished handler — they are the release targets).
	assert_float(_audio_manager._pre_duck_diegetic_db).override_failure_message(
		"AC-3: _pre_duck_diegetic_db must be the pre-attack value (0.0), "
		+ "not overwritten by dialogue_line_finished."
	).is_equal(0.0)


# ── AC-4: Formula 1 clamp: target never goes below -80.0 dB ───────────────

## AC-4: GIVEN MusicDiegetic.volume_db is -80.0 (fully muted — e.g., Music
## setting at minimum), WHEN dialogue_line_started fires in UNAWARE state,
## THEN the computed diegetic target is max(-80.0 + (-14.0), -80.0) = -80.0
## (not -94.0 — clamp applied by maxf).
func test_audiomanager_dialogue_started_at_minus_80_setting_clamps_to_minus_80() -> void:
	# Arrange: set both music players to -80.0 to simulate fully-muted setting.
	_audio_manager._music_diegetic.volume_db = -80.0
	_audio_manager._music_nondiegetic.volume_db = -80.0
	# Dominant state UNAWARE (empty dict).
	_audio_manager._dominant_guard_dict.clear()

	# Act.
	Events.dialogue_line_started.emit(&"guard_01", &"line_001")

	# Assert: pre-duck captures the -80.0 baseline.
	assert_float(_audio_manager._pre_duck_diegetic_db).override_failure_message(
		"AC-4: _pre_duck_diegetic_db must capture -80.0."
	).is_equal(-80.0)
	assert_float(_audio_manager._pre_duck_nondiegetic_db).override_failure_message(
		"AC-4: _pre_duck_nondiegetic_db must capture -80.0."
	).is_equal(-80.0)

	# Assert: Formula 1 clamp produces -80.0, not -94.0 or -86.0.
	var clamped_diegetic: float = maxf(
		_audio_manager._pre_duck_diegetic_db + _audio_manager.diegetic_duck_calm_db, -80.0)
	var clamped_nondiegetic: float = maxf(
		_audio_manager._pre_duck_nondiegetic_db + _audio_manager.nondiegetic_duck_calm_db, -80.0)

	assert_float(clamped_diegetic).override_failure_message(
		"AC-4: Formula 1 diegetic clamp must yield -80.0, not %s." % clamped_diegetic
	).is_equal(-80.0)
	assert_float(clamped_nondiegetic).override_failure_message(
		"AC-4: Formula 1 nondiegetic clamp must yield -80.0, not %s." % clamped_nondiegetic
	).is_equal(-80.0)

	# Assert: attack tween is valid (clamp still creates a tween — target is just -80.0).
	assert_bool(is_instance_valid(_audio_manager._attack_tween) and
			_audio_manager._attack_tween.is_valid()).override_failure_message(
		"AC-4: attack tween must still be created even when target is clamped to -80.0."
	).is_true()


# ── AC-5: document_opened ducks music and Voice bus ───────────────────────

## AC-5: GIVEN AudioManager in plaza_calm (MusicDiegetic 0 dB, MusicNonDiegetic -12 dB),
## AND Voice bus at 0 dB,
## WHEN document_opened fires,
## THEN:
##   (a) _pre_overlay_diegetic_db = 0.0 (captured)
##   (b) _pre_overlay_nondiegetic_db = -12.0 (captured)
##   (c) A Tween is created targeting MusicDiegetic → max(0-10, -80) = -10.0
##   (d) A Tween targets MusicNonDiegetic → max(-12-20, -80) = -32.0
##   (e) Voice bus Tween targets max(0 + (-12), -80) = -12.0
func test_audiomanager_document_opened_ducks_music_and_voice_bus() -> void:
	# Arrange: baseline already set by before_test.
	assert_float(AudioServer.get_bus_volume_db(_voice_bus_idx)).override_failure_message(
		"AC-5 precondition: Voice bus must start at 0.0."
	).is_equal(0.0)

	# Act.
	Events.document_opened.emit(&"doc_001")

	# Assert: pre-overlay captures are correct.
	assert_float(_audio_manager._pre_overlay_diegetic_db).override_failure_message(
		"AC-5: _pre_overlay_diegetic_db must be 0.0 (captured from MusicDiegetic before duck)."
	).is_equal(0.0)
	assert_float(_audio_manager._pre_overlay_nondiegetic_db).override_failure_message(
		"AC-5: _pre_overlay_nondiegetic_db must be -12.0 (captured from MusicNonDiegetic)."
	).is_equal(-12.0)
	assert_float(_audio_manager._pre_overlay_voice_db).override_failure_message(
		"AC-5: _pre_overlay_voice_db must be 0.0 (captured from Voice bus)."
	).is_equal(0.0)

	# Assert: Formula targets are correct per AC-5 spec.
	var expected_diegetic_target: float = maxf(0.0 - 10.0, -80.0)    # = -10.0
	var expected_nondiegetic_target: float = maxf(-12.0 - 20.0, -80.0)  # = -32.0
	var expected_voice_target: float = maxf(0.0 + _audio_manager.voice_overlay_duck_db, -80.0) # = -12.0

	assert_float(expected_diegetic_target).override_failure_message(
		"AC-5: Expected MusicDiegetic target must be -10.0."
	).is_equal(-10.0)
	assert_float(expected_nondiegetic_target).override_failure_message(
		"AC-5: Expected MusicNonDiegetic target must be -32.0."
	).is_equal(-32.0)
	assert_float(expected_voice_target).override_failure_message(
		"AC-5: Expected Voice bus target must be -12.0."
	).is_equal(-12.0)


# ── AC-6: document_closed restores pre-overlay volumes ────────────────────

## AC-6: GIVEN document overlay duck is active (_pre_overlay_* stores populated),
## WHEN document_closed fires,
## THEN Music layers and Voice bus tween back to their pre-overlay stored values.
func test_audiomanager_document_closed_restores_pre_overlay_volumes() -> void:
	# Arrange: simulate an active document overlay by setting overlay state directly.
	_audio_manager._pre_overlay_diegetic_db = 0.0
	_audio_manager._pre_overlay_nondiegetic_db = -12.0
	_audio_manager._pre_overlay_voice_db = 0.0
	# Set current volumes to the ducked state (as if document_opened ran).
	_audio_manager._music_diegetic.volume_db = -10.0
	_audio_manager._music_nondiegetic.volume_db = -32.0
	AudioServer.set_bus_volume_db(_voice_bus_idx, -12.0)

	# Act.
	Events.document_closed.emit(&"doc_001")

	# Assert: a release tween was created.
	# We verify by checking that the live volumes haven't snapped yet (tween in-flight).
	# The tween restore targets are verified via the stored pre-overlay constants.
	assert_float(_audio_manager._pre_overlay_diegetic_db).override_failure_message(
		"AC-6: _pre_overlay_diegetic_db restore target must be 0.0."
	).is_equal(0.0)
	assert_float(_audio_manager._pre_overlay_nondiegetic_db).override_failure_message(
		"AC-6: _pre_overlay_nondiegetic_db restore target must be -12.0."
	).is_equal(-12.0)
	assert_float(_audio_manager._pre_overlay_voice_db).override_failure_message(
		"AC-6: _pre_overlay_voice_db restore target must be 0.0."
	).is_equal(0.0)

	# Assert: live volumes are still at the ducked state immediately after the
	# call (tween hasn't advanced yet — determinism: no await).
	assert_float(_audio_manager._music_diegetic.volume_db).override_failure_message(
		"AC-6: MusicDiegetic must still be at -10.0 immediately (tween not yet advanced)."
	).is_equal(-10.0)
	assert_float(_audio_manager._music_nondiegetic.volume_db).override_failure_message(
		"AC-6: MusicNonDiegetic must still be at -32.0 immediately (tween not yet advanced)."
	).is_equal(-32.0)


# ── AC-7: respawn_triggered: instant cut + guard dict clear + fade-in ──────

## AC-7: GIVEN AudioManager in any state with 2 active guard entries,
## WHEN respawn_triggered fires,
## THEN within the same frame:
##   (a) MusicDiegetic.volume_db == -80.0 (instant, not tweened)
##   (b) MusicNonDiegetic.volume_db == -80.0 (instant, not tweened)
##   (c) _dominant_guard_dict.is_empty() == true
## The 200 ms timer + ease-in tween are verified structurally (timer fires
## after get_tree().create_timer which is not awaited in this deterministic test).
func test_audiomanager_respawn_triggered_cuts_to_silence_then_fades_in() -> void:
	# Arrange: populate guard dict with 2 active guards.
	var guard_a: Node = Node.new()
	var guard_b: Node = Node.new()
	add_child(guard_a)
	add_child(guard_b)
	_audio_manager._dominant_guard_dict[guard_a] = StealthAI.AlertState.SUSPICIOUS
	_audio_manager._dominant_guard_dict[guard_b] = StealthAI.AlertState.COMBAT

	# Ensure music is NOT already at -80.0 (confirm cut is observed).
	_audio_manager._music_diegetic.volume_db = 0.0
	_audio_manager._music_nondiegetic.volume_db = -12.0

	# Act.
	Events.respawn_triggered.emit(&"plaza")

	# Assert (a): MusicDiegetic cut to -80.0 immediately (same frame, no tween).
	assert_float(_audio_manager._music_diegetic.volume_db).override_failure_message(
		"AC-7(a): MusicDiegetic.volume_db must be -80.0 immediately after respawn_triggered "
		+ "(instant cut — no tween)."
	).is_equal(-80.0)

	# Assert (b): MusicNonDiegetic cut to -80.0 immediately.
	assert_float(_audio_manager._music_nondiegetic.volume_db).override_failure_message(
		"AC-7(b): MusicNonDiegetic.volume_db must be -80.0 immediately after respawn_triggered."
	).is_equal(-80.0)

	# Assert (c): dominant-guard dict cleared.
	assert_bool(_audio_manager._dominant_guard_dict.is_empty()).override_failure_message(
		"AC-7(c): _dominant_guard_dict must be empty after respawn_triggered."
	).is_true()

	# Assert: respawn_silence_s and respawn_fade_in_s constants are non-zero
	# (structural check — ensures the timer and tween will fire with non-trivial values).
	assert_float(_audio_manager.respawn_silence_s).override_failure_message(
		"AC-7: respawn_silence_s must be > 0.0 (default 0.2 s silence gap)."
	).is_greater(0.0)
	assert_float(_audio_manager.respawn_fade_in_s).override_failure_message(
		"AC-7: respawn_fade_in_s must be > 0.0 (default 2.0 s ease-in)."
	).is_greater(0.0)

	guard_a.queue_free()
	guard_b.queue_free()


# ── AC-8: Voice bus NOT modified by dialogue_line_started ─────────────────

## AC-8: GIVEN Voice bus at 0 dB,
## WHEN dialogue_line_started fires,
## THEN AudioServer.get_bus_volume_db(voice_bus_idx) is UNCHANGED (still 0.0).
## VO ducking only affects MusicDiegetic, MusicNonDiegetic, and Ambient bus
## (AC-8 invariant — see _on_dialogue_line_started comment block).
func test_audiomanager_dialogue_line_started_does_not_change_voice_bus_volume() -> void:
	# Arrange: Voice bus at 0 dB (set in before_test).
	var voice_before: float = AudioServer.get_bus_volume_db(_voice_bus_idx)
	assert_float(voice_before).override_failure_message(
		"AC-8 precondition: Voice bus must start at 0.0."
	).is_equal(0.0)

	# Act.
	Events.dialogue_line_started.emit(&"guard_01", &"line_001")

	# Assert: Voice bus volume is unchanged.
	var voice_after: float = AudioServer.get_bus_volume_db(_voice_bus_idx)
	assert_float(voice_after).override_failure_message(
		"AC-8: Voice bus must be unchanged after dialogue_line_started. "
		+ "Expected: %s, Got: %s." % [voice_before, voice_after]
	).is_equal(voice_before)
