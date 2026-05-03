# Story 003: Plaza ambient layer + UNAWARE/COMBAT music states + section reverb

> **Epic**: Audio
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4 hours (L — music player setup, crossfade Tween logic, reverb swap, integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/audio.md`
**Requirement**: TR-AUD-004, TR-AUD-005, TR-AUD-006, TR-AUD-008, TR-AUD-009, TR-AUD-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: Music is two simultaneous `AudioStreamPlayer` layers (`MusicDiegetic` + `MusicNonDiegetic`) plus a one-shot `MusicSting`, all on the Music bus. All transitions use `Tween.tween_property(player, "volume_db", target_db, duration)` — never stop-and-start (GDD Rule 6). A `Dictionary[Node, StealthAI.AlertState]` (dominant-guard dict) tracks per-actor alert state; music state is driven by the highest alert level (GDD §States and Transitions — Dominant-guard rule). VS scope: Plaza ambient loop + UNAWARE (`plaza_calm`) and COMBAT (`plaza_combat`) states only. ADR-0008 Slot 6 caps audio dispatch at 0.3 ms p95 on Iris Xe (advisory until ADR-0008 Gates 1+2 pass).

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM
**Engine Notes**: `create_tween().tween_property(player, "volume_db", target_db, duration_s)` is stable Godot 4.0+. `AudioEffectReverb` in-place property mutation (NOT remove/re-add) avoids audio click during active crossfade — the GDD explicitly requires in-place mutation (GDD Rule 2 + AC-8). `AudioServer.get_bus_effect_count(bus_idx)` and `AudioServer.get_bus_effect(bus_idx, effect_idx)` are stable 4.0+ APIs. `AudioStreamPlayer.play()` and `.volume_db` are stable. Risk is LOW-MEDIUM because Tween API saw minor changes in 4.0–4.4 (old `$Tween` scene-node pattern is deprecated; use `create_tween()` per control-manifest Forbidden APIs).

**Control Manifest Rules (Foundation)**:
- Required: subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3) — handled by Story 002; this story adds handler bodies
- Required: every Node-typed payload checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4)
- Required: use `create_tween()` (Godot 4.0+ scene-independent Tween) — NOT the deprecated `$Tween` scene-node or `Tween.new()` patterns
- Forbidden: stop-and-start music transitions — all music transitions via `Tween.tween_property` on `volume_db` (GDD Rule 6)
- Forbidden: `AudioStreamPlayer.new()` at runtime for SFX (GDD Rule 9) — music players are pre-instantiated in `_ready()`
- Guardrail: audio dispatch slot 0.3 ms p95 cap (ADR-0008 Slot 6 — advisory until Gates 1+2 pass)

---

## Acceptance Criteria

*From GDD `design/gdd/audio.md` Rules 2, 4, 6 + AC-5, AC-6, AC-8 scoped to VS (plaza + UNAWARE + COMBAT):*

- [ ] **AC-1**: GIVEN `AudioManager._ready()` completes, WHEN the node children are inspected, THEN three `AudioStreamPlayer` nodes exist as direct children named `MusicDiegetic`, `MusicNonDiegetic`, and `MusicSting`, all with `bus = &"Music"` and initial `volume_db` values matching the `plaza_calm` state table: `MusicDiegetic.volume_db == 0.0`, `MusicNonDiegetic.volume_db == -12.0`.
- [ ] **AC-2**: GIVEN `section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)` fires, WHEN `AudioManager._on_section_entered` handles it, THEN: (a) `MusicDiegetic` tweens to `0.0 dB` over `2.0 s` ease-in-out; (b) `MusicNonDiegetic` tweens to `-12.0 dB` over `2.0 s` ease-in-out; (c) the ambient loop player starts playing the Plaza ambient stream. Verified by inspecting the in-flight Tween target and the ambient player's `playing` state.
- [ ] **AC-3**: GIVEN music is in `plaza_calm` state AND `alert_state_changed(guard_node, UNAWARE, COMBAT, MAJOR)` fires, WHEN `AudioManager` handles it, THEN: (a) the dominant-guard dict is updated with `guard_node → COMBAT`; (b) `MusicDiegetic` begins a `0.3 s` linear tween toward `-80.0 dB`; (c) `MusicNonDiegetic` begins a `0.3 s` linear tween toward `0.0 dB`. Note: this AC depends on the ADR-0002 amendment landing (see Out of Scope). Skip test until amendment is confirmed.
- [ ] **AC-4**: GIVEN music is in `plaza_combat` state AND `section_exited(&"plaza", reason)` fires, WHEN `AudioManager._on_section_exited` handles it, THEN the dominant-guard dict is cleared (size == 0) AND any in-flight Tween on `MusicDiegetic`/`MusicNonDiegetic` is killed (verified via `Tween.is_valid() == false` after the call).
- [ ] **AC-5**: GIVEN `section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)` fires, WHEN `AudioManager` handles it, THEN the `AudioEffectReverb` instance on the SFX bus is mutated IN-PLACE (the pre/post object identity is the same — verified by capturing the reference before and after and asserting `pre_ref == post_ref`), not removed and re-added (which would cause a click during active crossfade).
- [ ] **AC-6**: GIVEN `section_entered(&"plaza", LevelStreamingService.TransitionReason.RESPAWN)` fires (respawn path), WHEN `AudioManager._on_section_entered` handles the RESPAWN reason, THEN it does NOT re-trigger a music crossfade (the `respawn_triggered` handler in Story 004 owns the 2.0 s ease-in; this handler must early-return on RESPAWN branch). The ambient player continues playing undisturbed.

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines + GDD §Detailed Design Rules 2, 4, 6 + §States and Transitions:*

**Music player setup** — three persistent `AudioStreamPlayer` nodes created in `_ready()`:

```gdscript
var _music_diegetic: AudioStreamPlayer
var _music_nondiegetic: AudioStreamPlayer
var _music_sting: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

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
```

**Dominant-guard dict** — tracks highest alert per actor:

```gdscript
var _dominant_guard_dict: Dictionary = {}  # Dictionary[Node, StealthAI.AlertState]
var _current_music_state: StringName = &""

func _compute_dominant_state() -> StealthAI.AlertState:
    var highest: StealthAI.AlertState = StealthAI.AlertState.UNAWARE
    for state: StealthAI.AlertState in _dominant_guard_dict.values():
        if state > highest:
            highest = state
    return highest
```

**Crossfade helper** — extracted pure function per GDD Rule 6 (Tween on volume_db only):

```gdscript
func _crossfade_music(diegetic_target_db: float, nondiegetic_target_db: float,
        duration_s: float, trans: Tween.TransitionType) -> void:
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(_music_diegetic, "volume_db", diegetic_target_db, duration_s) \
        .set_trans(trans)
    tween.tween_property(_music_nondiegetic, "volume_db", nondiegetic_target_db, duration_s) \
        .set_trans(trans)
    _current_alert_tween = tween
```

**section_entered handler** (VS — FORWARD branch only):

```gdscript
func _on_section_entered(section_id: StringName,
        reason: LevelStreamingService.TransitionReason) -> void:
    # Swap reverb preset IN-PLACE (Rule 2 — not remove/re-add)
    _apply_reverb_preset(section_id)
    match reason:
        LevelStreamingService.TransitionReason.FORWARD:
            _crossfade_music(0.0, -12.0, 2.0, Tween.TRANS_SINE)  # plaza_calm
            _start_ambient_for_section(section_id)
        LevelStreamingService.TransitionReason.RESPAWN:
            pass  # respawn_triggered handler owns the fade-in — do NOT crossfade here
        LevelStreamingService.TransitionReason.NEW_GAME:
            _crossfade_music(0.0, -12.0, 2.0, Tween.TRANS_SINE)
            _start_ambient_for_section(section_id)
        LevelStreamingService.TransitionReason.LOAD_FROM_SAVE:
            # Instant-set, no crossfade ceremony (GDD §Mission domain section_entered)
            _music_diegetic.volume_db = 0.0
            _music_nondiegetic.volume_db = -12.0
            _start_ambient_for_section(section_id)
```

**section_exited handler** (GDD §Concurrency Policies Rule 4):

```gdscript
func _on_section_exited(section_id: StringName,
        reason: LevelStreamingService.TransitionReason) -> void:
    _dominant_guard_dict.clear()
    if is_instance_valid(_current_alert_tween) and _current_alert_tween.is_valid():
        _current_alert_tween.kill()
```

**Reverb swap** — in-place property mutation:

```gdscript
func _apply_reverb_preset(section_id: StringName) -> void:
    var sfx_bus_idx: int = AudioServer.get_bus_index(&"SFX")
    # Assumes the first effect on SFX bus is the AudioEffectReverb (set in project settings)
    var effect: AudioEffect = AudioServer.get_bus_effect(sfx_bus_idx, 0)
    if not (effect is AudioEffectReverb):
        return
    var reverb: AudioEffectReverb = effect as AudioEffectReverb
    # VS: only Plaza preset implemented; other sections use the same values until Story 003 expands
    match section_id:
        &"plaza":
            reverb.room_size = 0.2   # exterior open — short decay
            reverb.damping = 0.8
            reverb.wet = 0.15
        _:
            reverb.room_size = 0.4   # fallback medium room
            reverb.damping = 0.6
            reverb.wet = 0.25
```

**VS simplification**: the `alert_state_changed` handler (COMBAT transition, AC-3) is stubbed but marked with `# TODO: blocked on ADR-0002 amendment` — the 4-param signature is not available until the amendment lands. The dominant-guard dict and `_compute_dominant_state` are implemented and testable; only the signal connection is deferred.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: VO ducking (`_on_dialogue_line_started`/`_finished`), document overlay world-bus mute, respawn cut-to-silence
- Story 005: footstep SFX routing, COMBAT stinger scheduling (`_on_actor_became_alerted`)

**Deferred post-VS** (do NOT implement in this story):
- TR-AUD-008 (full music preload at section_entered): placeholder `AudioStreamOggVorbis` or null stream is acceptable for VS; real asset loading deferred to content production
- TR-AUD-009 (full 5-section reverb preset library): only Plaza preset is implemented here; other 4 sections deferred
- TR-AUD-005 (full 5×4 music state grid): SUSPICIOUS and SEARCHING alert states are deferred; VS validates UNAWARE + COMBAT only
- AC-3 signal connection blocked on ADR-0002 amendment (alert_state_changed 4-param signature)
- Full dominant-guard dict SUSPICIOUS/SEARCHING transitions deferred to post-VS

---

## QA Test Cases

**AC-1 — MusicDiegetic/NonDiegetic/Sting nodes present with correct initial volumes**
- **Given**: AudioManager instantiated in a headless test scene (with Story 001 + Story 002 in place)
- **When**: `_ready()` completes
- **Then**: `get_node("MusicDiegetic").bus == &"Music"` AND `volume_db == 0.0`; `get_node("MusicNonDiegetic").volume_db == -12.0`; `get_node("MusicSting").bus == &"Music"`
- **Edge cases**: player nodes not added as children → `get_node()` fails; wrong bus → fails AC-4 from Story 001

**AC-2 — section_entered FORWARD triggers 2.0 s ease-in crossfade to plaza_calm**
- **Given**: AudioManager with music players initialized
- **When**: `Events.section_entered.emit(&"plaza", LevelStreamingService.TransitionReason.FORWARD)`
- **Then**: within 1 frame, a Tween is active targeting `MusicDiegetic.volume_db == 0.0` over `2.0 s` AND `MusicNonDiegetic.volume_db == -12.0` over `2.0 s`; ambient player `.playing == true`
- **Edge cases**: RESPAWN reason should NOT start a crossfade (AC-6); NEW_GAME should crossfade identically to FORWARD

**AC-3 — alert_state_changed COMBAT triggers 0.3 s cut to combat levels (blocked on ADR-0002 amendment)**
- **Given**: AudioManager in `plaza_calm` state; dominant-guard dict populated with one guard at UNAWARE
- **When**: `Events.alert_state_changed.emit(guard_node, StealthAI.AlertState.UNAWARE, StealthAI.AlertState.COMBAT, StealthAI.Severity.MAJOR)` [requires post-amendment 4-param signature]
- **Then**: dict updated; `_compute_dominant_state() == COMBAT`; Tween launched targeting `MusicDiegetic → -80.0` and `MusicNonDiegetic → 0.0` over `0.3 s` linear
- **Edge cases**: SKIP this test until ADR-0002 amendment is Accepted — mark as `skip("blocked: ADR-0002 amendment not yet landed")`

**AC-4 — section_exited clears dominant-guard dict and kills in-flight Tween**
- **Given**: AudioManager with dominant-guard dict populated (3 guards) AND an active crossfade Tween in progress
- **When**: `Events.section_exited.emit(&"plaza", LevelStreamingService.TransitionReason.FORWARD)`
- **Then**: `_dominant_guard_dict.is_empty() == true`; the previously-captured Tween reference has `is_valid() == false`
- **Edge cases**: dict already empty (no crash — clear() is safe on empty dict); no active tween (guard for `is_instance_valid` + `is_valid()` prevents crash)

**AC-5 — AudioEffectReverb mutated in-place on section_entered**
- **Given**: AudioManager with an `AudioEffectReverb` on the SFX bus (index 0)
- **When**: `Events.section_entered.emit(&"plaza", LevelStreamingService.TransitionReason.FORWARD)`
- **Then**: the effect object reference before the call equals the reference after the call (same instance, not a new AudioEffectReverb)
- **Edge cases**: no effect on SFX bus (guard against null → test asserts effect exists before calling); wrong effect type at index 0 (guard for `effect is AudioEffectReverb` check)

**AC-6 — section_entered RESPAWN does NOT start a crossfade**
- **Given**: AudioManager with music players
- **When**: `Events.section_entered.emit(&"plaza", LevelStreamingService.TransitionReason.RESPAWN)`
- **Then**: `_current_alert_tween` is NOT a newly-created Tween (unchanged from state before the emit); music volumes are unchanged
- **Edge cases**: RESPAWN branch falls through to FORWARD case (common error) → volumes change, test fails correctly

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/foundation/audio/audio_plaza_ambient_music_test.gd` — must exist and pass
- Covers AC-1 (music player nodes), AC-2 (section_entered crossfade), AC-4 (section_exited cleanup), AC-5 (reverb in-place mutation), AC-6 (RESPAWN branch isolation)
- AC-3 marked `skip()` until ADR-0002 amendment lands; skip annotation must include reason string
- Determinism: Tweens tested via target inspection in the first frame, not by waiting for tween completion (avoids `await` timing dependencies in headless tests)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (bus structure), Story 002 DONE (subscription wiring)
- Unlocks: Story 004 (ducking handlers require music players to tween against), Story 005 (stinger scheduling requires MusicSting player)

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 6/6 passing (AC-3 alert_state_changed signal IS available with 4-param signature; ADR-0002 amendment dependency resolved)
**Deviations**: None blocking. Two notes:
- AC-3 was originally documented as potentially blocked on ADR-0002 amendment; verification showed `Events.alert_state_changed` exists with the 4-param signature `(guard_node, old_state, new_state, severity)` — handler implemented and connected in _ready().
- VS placeholder for ambient stream loading per TR-AUD-008 deferral (real asset loading deferred to content production); `_start_ambient_for_section()` skips `play()` if no stream loaded, defensive against headless tests.

**Test Evidence**: `tests/integration/foundation/audio/audio_plaza_ambient_music_test.gd` (7 test functions covering AC-1..AC-6 + dominant-state helper test)

**Code Review**: Static structural verification PASS — `create_tween().set_parallel(true)` modern Godot 4.x pattern verified, in-place reverb mutation verified (no remove/re-add), is_connected guards on disconnect, no Tween.new() or scene-node $Tween (forbidden patterns absent). LP-CODE-REVIEW + QL-TEST-COVERAGE gates skipped (Lean review mode).
