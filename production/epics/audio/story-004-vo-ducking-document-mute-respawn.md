# Story 004: VO ducking (Formula 1) + document world-bus mute + respawn cut-to-silence

> **Epic**: Audio
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — Formula 1 implementation + 3 handler bodies + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/audio.md`
**Requirement**: TR-AUD-004, TR-AUD-006, TR-AUD-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: AudioManager reacts to `dialogue_line_started` / `dialogue_line_finished` by applying Formula 1 state-keyed per-layer VO ducking via Tween on `volume_db` (not a global volume call — per-player volume targeting only). It reacts to `document_opened` by muting the world/Music+Ambient buses and applying the Voice bus `−12 dB` duck per D&S CR-DS-17 v0.3. It reacts to `respawn_triggered` by cutting all music to silence for ~200 ms, then easing in to `[section_id]_calm` over 2.0 s (GDD §Failure/Respawn domain). AudioManager is subscriber-only in all three handlers — it publishes nothing. Formula 1 uses the `max(..., -80.0)` clamp to stay within the Music bus safe range.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioServer.set_bus_volume_db(bus_idx, value_db)` for the Voice bus duck is stable 4.0+. Tween's `tween_property` on `AudioStreamPlayer.volume_db` and on `AudioServer` bus volume are distinct patterns — the Voice bus duck uses `AudioServer.set_bus_volume_db` via Tween's method call, while VO layer ducking uses per-player `volume_db` tween. `get_tree().create_timer(delay_s)` is used for the 200 ms respawn silence gap. No post-cutoff APIs required.

**Control Manifest Rules (Foundation)**:
- Required: subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3) — already wired by Story 002
- Required: every Node-typed payload MUST be checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4)
- Forbidden: `dialogue_line_finished.emit()` — AudioManager must NOT re-emit Dialogue signals (subscriber-only invariant per GDD §Dialogue domain + EPIC.md forbidden patterns)
- Forbidden: playing VO through the SFX bus — VO uses a dedicated `AudioStreamPlayer` on the Voice bus owned by Dialogue & Subtitles (GDD Rule 9 + D&S §C.3 v0.3 amendment — Audio does NOT load or play VO files)

---

## Acceptance Criteria

*From GDD `design/gdd/audio.md` Rules 7 + §Formula 1 + AC-14, AC-15, AC-16, AC-17, AC-32, AC-33 scoped to VS:*

- [ ] **AC-1**: GIVEN music state is `plaza_calm` (MusicDiegetic 0 dB, MusicNonDiegetic −12 dB) AND Music setting slider at 0 dB, WHEN `dialogue_line_started(speaker, line_id)` fires, THEN over 0.3 s: `MusicDiegetic` tweens to `max(0.0 + (-14.0), -80.0) = -14.0 dB` (calm state duck); `MusicNonDiegetic` tweens to `max(-12.0 + (-6.0), -80.0) = -18.0 dB`; Ambient bus volume tweens to `max(0.0 + (-6.0), -80.0) = -6.0 dB`. Verified by reading the Tween's target values within 1 frame of the emit.
- [ ] **AC-2**: GIVEN VO ducking is active, WHEN `dialogue_line_finished` fires, THEN over 0.5 s: `MusicDiegetic`, `MusicNonDiegetic`, and Ambient bus all tween back to their pre-duck stored values (the values captured before the attack tween began).
- [ ] **AC-3**: GIVEN a 150 ms VO clip (attack tween of 0.3 s still in progress), WHEN `dialogue_line_finished` fires while the attack tween is still running, THEN the attack tween is killed AND the release tween starts from the LIVE current `volume_db` value (not from the attack target). Verified by: (a) starting an attack tween, (b) advancing the test clock partway through the attack, (c) emitting `dialogue_line_finished`, (d) asserting the release tween's start value equals the live volume at the kill point.
- [ ] **AC-4**: GIVEN Music setting at −80 dB, WHEN `dialogue_line_started` fires in `plaza_calm` state, THEN the computed duck target for `MusicDiegetic` is `max(-80.0 + (-14.0), -80.0) = -80.0 dB` (clamp applied — not −94 dB). Verified by reading the Tween target.
- [ ] **AC-5**: GIVEN `document_opened(document_id)` fires, WHEN `AudioManager._on_document_opened` handles it, THEN: (a) `MusicDiegetic` tweens to `−10 dB` additional attenuation over `0.5 s` linear; (b) `MusicNonDiegetic` tweens to `−20 dB` additional over `0.5 s`; (c) Voice bus volume tweens to `voice_current_db + (-12.0)` clamped to `max(..., -80.0)` over `0.3 s` attack.
- [ ] **AC-6**: GIVEN `document_closed(document_id)` fires after a `document_opened` duck, WHEN `AudioManager._on_document_closed` handles it, THEN: (a) Music layers restore to the pre-overlay volumes over `0.5 s`; (b) Voice bus restores to pre-duck Voice bus level over `0.5 s` release.
- [ ] **AC-7**: GIVEN `respawn_triggered(&"plaza")` fires, WHEN `AudioManager._on_respawn_triggered` handles it, THEN: (a) `MusicDiegetic` and `MusicNonDiegetic` cut to −80 dB immediately (no Tween — instant cut); (b) after a 200 ms delay (`respawn_silence_s` tuning knob), `MusicDiegetic` tweens to `0.0 dB` and `MusicNonDiegetic` tweens to `−12.0 dB` over `2.0 s` ease-in-out (`respawn_fade_in_s` tuning knob); (c) the dominant-guard dict is cleared.
- [ ] **AC-8**: GIVEN the Voice bus is NOT ducked by VO playback (the Voice bus level is unaffected by `dialogue_line_started` — only MusicDiegetic/MusicNonDiegetic/Ambient duck), WHEN `dialogue_line_started` fires, THEN `AudioServer.get_bus_volume_db(voice_bus_idx)` is UNCHANGED from before the emit. (Distinct from the `document_opened` Voice bus duck which is a separate mechanism.)

---

## Implementation Notes

*Derived from ADR-0002 IG 3, IG 4 + GDD §Formula 1 + §Failure/Respawn domain + §Documents domain:*

**Formula 1 duck-depth constants** — exported from AudioManager for designer tuning:

```gdscript
## Duck depth table for MusicDiegetic per alert state (Formula 1).
## Negative values = attenuation. Safe range: -14.0 to -6.0 per GDD §Tuning Knobs.
@export var diegetic_duck_calm_db: float = -14.0
@export var diegetic_duck_suspicious_db: float = -10.0
@export var diegetic_duck_searching_db: float = -8.0
@export var diegetic_duck_combat_db: float = -6.0

## Duck depth for MusicNonDiegetic per alert state (Formula 1). Safe range: -6.0 to -4.0.
@export var nondiegetic_duck_calm_db: float = -6.0
@export var nondiegetic_duck_combat_db: float = -4.0  # signal preservation

## Flat ambient duck depth (all states). Safe range: -2.0 to -12.0.
@export var ambient_duck_db: float = -6.0

## VO duck attack/release timings (seconds). Safe ranges per GDD §Tuning Knobs.
@export var vo_duck_attack_s: float = 0.3
@export var vo_duck_release_s: float = 0.5

## Voice bus duck depth on document_opened (D&S CR-DS-17 v0.3). Safe range: -18.0 to 0.0.
@export var voice_overlay_duck_db: float = -12.0

## Respawn timing constants. See GDD §Tuning Knobs.
@export var respawn_silence_s: float = 0.2
@export var respawn_fade_in_s: float = 2.0
```

**VO duck handler** — implements Formula 1 per-layer, per-state:

```gdscript
var _pre_duck_diegetic_db: float = 0.0
var _pre_duck_nondiegetic_db: float = -12.0
var _pre_duck_ambient_bus_db: float = 0.0
var _attack_tween: Tween = null

func _on_dialogue_line_started(_speaker: StringName, _line_id: StringName) -> void:
    # Store current volumes BEFORE modifying (for release tween)
    _pre_duck_diegetic_db = _music_diegetic.volume_db
    _pre_duck_nondiegetic_db = _music_nondiegetic.volume_db
    var ambient_bus_idx: int = AudioServer.get_bus_index(&"Ambient")
    _pre_duck_ambient_bus_db = AudioServer.get_bus_volume_db(ambient_bus_idx)

    var diegetic_duck: float = _get_diegetic_duck_for_state()
    var nondiegetic_duck: float = _get_nondiegetic_duck_for_state()

    var setting_music_db: float = _get_setting_music_db()
    var setting_ambient_db: float = _get_setting_ambient_db()

    var diegetic_target: float = maxf(setting_music_db + diegetic_duck, -80.0)
    var nondiegetic_target: float = maxf(setting_music_db + nondiegetic_duck, -80.0)
    var ambient_target: float = maxf(setting_ambient_db + ambient_duck_db, -80.0)

    # Kill any in-progress attack tween before starting a new one
    if is_instance_valid(_attack_tween) and _attack_tween.is_valid():
        _attack_tween.kill()

    _attack_tween = create_tween().set_parallel(true)
    _attack_tween.tween_property(_music_diegetic, "volume_db", diegetic_target, vo_duck_attack_s)
    _attack_tween.tween_property(_music_nondiegetic, "volume_db", nondiegetic_target, vo_duck_attack_s)
    # Ambient bus: tween via AudioServer — GDScript Callable syntax
    # NOTE: AudioServer bus volume requires a lambda or a method call via Tween.tween_method
    _attack_tween.tween_method(
        func(v: float) -> void:
            AudioServer.set_bus_volume_db(ambient_bus_idx, v),
        _pre_duck_ambient_bus_db, ambient_target, vo_duck_attack_s)
```

**Tween interrupt on short VO** (GDD §Formula 1 short-VO tween interrupt edge case):

```gdscript
func _on_dialogue_line_finished() -> void:
    # Kill in-progress attack if still running — start release from LIVE volume
    if is_instance_valid(_attack_tween) and _attack_tween.is_valid():
        _attack_tween.kill()
    # Read live values (may be partially ducked if attack was interrupted)
    var live_diegetic: float = _music_diegetic.volume_db
    var live_nondiegetic: float = _music_nondiegetic.volume_db
    var ambient_bus_idx: int = AudioServer.get_bus_index(&"Ambient")
    var live_ambient: float = AudioServer.get_bus_volume_db(ambient_bus_idx)

    var release_tween: Tween = create_tween().set_parallel(true)
    release_tween.tween_property(_music_diegetic, "volume_db",
        _pre_duck_diegetic_db, vo_duck_release_s)
    release_tween.tween_property(_music_nondiegetic, "volume_db",
        _pre_duck_nondiegetic_db, vo_duck_release_s)
    release_tween.tween_method(
        func(v: float) -> void:
            AudioServer.set_bus_volume_db(ambient_bus_idx, v),
        live_ambient, _pre_duck_ambient_bus_db, vo_duck_release_s)
```

**Respawn handler** (GDD §Failure/Respawn domain):

```gdscript
func _on_respawn_triggered(section_id: StringName) -> void:
    # 1. Instant cut to silence
    _music_diegetic.volume_db = -80.0
    _music_nondiegetic.volume_db = -80.0
    # 2. Clear dominant-guard dict (redundant with section_exited but safe per GDD §Concurrency Rule 4)
    _dominant_guard_dict.clear()
    # 3. After silence gap, ease in to section_calm
    get_tree().create_timer(respawn_silence_s).timeout.connect(
        func() -> void:
            var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
            tween.tween_property(_music_diegetic, "volume_db", 0.0, respawn_fade_in_s)
            tween.tween_property(_music_nondiegetic, "volume_db", -12.0, respawn_fade_in_s),
        CONNECT_ONE_SHOT)
```

**Document overlay duck** (GDD §Documents domain + D&S CR-DS-17 v0.3):

```gdscript
var _pre_overlay_diegetic_db: float = 0.0
var _pre_overlay_nondiegetic_db: float = -12.0
var _pre_overlay_voice_db: float = 0.0

func _on_document_opened(_document_id: StringName) -> void:
    _pre_overlay_diegetic_db = _music_diegetic.volume_db
    _pre_overlay_nondiegetic_db = _music_nondiegetic.volume_db
    var voice_bus_idx: int = AudioServer.get_bus_index(&"Voice")
    _pre_overlay_voice_db = AudioServer.get_bus_volume_db(voice_bus_idx)

    var tween: Tween = create_tween().set_parallel(true)
    # Music layers duck to DOCUMENT_OVERLAY levels (−10 dB / −20 dB additional, GDD §States table)
    tween.tween_property(_music_diegetic, "volume_db",
        maxf(_pre_overlay_diegetic_db - 10.0, -80.0), 0.5)
    tween.tween_property(_music_nondiegetic, "volume_db",
        maxf(_pre_overlay_nondiegetic_db - 20.0, -80.0), 0.5)
    # Voice bus duck −12 dB (D&S CR-DS-17 v0.3)
    tween.tween_method(
        func(v: float) -> void:
            AudioServer.set_bus_volume_db(voice_bus_idx, v),
        _pre_overlay_voice_db, maxf(_pre_overlay_voice_db + voice_overlay_duck_db, -80.0), 0.3)
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: section_entered handler (crossfade logic)
- Story 005: footstep variant routing, COMBAT stinger scheduling

**Deferred post-VS** (do NOT implement in this story):
- GDD §Concurrency Policies Rule 6 (Document Overlay suspends alert-music transitions): the `_pending_dominant_state` caching during overlay is deferred — VS does not exercise concurrent guard-state changes during document reading
- GDD §Formula 1 `DOCUMENT_OVERLAY` state duck-depth row (−8 dB additional on each layer): the GDD specifies this as an additive overlay duck ON TOP OF the VO duck; only the document_opened standalone case is implemented here for VS
- TR-AUD-005 special-state music: CUTSCENE, MAIN_MENU, MISSION_COMPLETE music states deferred

---

## QA Test Cases

**AC-1 — VO duck in plaza_calm: MusicDiegetic −14 dB, MusicNonDiegetic −18 dB, Ambient −6 dB**
- **Given**: AudioManager in plaza_calm state (MusicDiegetic 0 dB, MusicNonDiegetic −12 dB); Music/Ambient settings at 0 dB
- **When**: `Events.dialogue_line_started.emit(&"guard_01", &"line_001")`
- **Then**: within 1 frame, attack Tween targeting `MusicDiegetic → -14.0`, `MusicNonDiegetic → -18.0`, Ambient bus → `-6.0`
- **Edge cases**: settings slider at non-zero value → verify Formula 1 is applied relative to settings value, not relative to 0 dB

**AC-2 — VO release restores pre-duck volumes**
- **Given**: audio in ducked state after `dialogue_line_started`
- **When**: `Events.dialogue_line_finished.emit()`
- **Then**: release Tween targets the stored pre-duck values (`_pre_duck_diegetic_db`, `_pre_duck_nondiegetic_db`, ambient stored value)
- **Edge cases**: release fired without prior attack (no crash; `_pre_duck_*` defaults match current volume)

**AC-3 — short VO: release starts from live volume, not duck target**
- **Given**: attack Tween at 50% progress (MusicDiegetic currently at −7 dB, partway to −14 dB target)
- **When**: `Events.dialogue_line_finished.emit()` fires while attack is still running
- **Then**: attack Tween is killed; release Tween's start value is the live −7 dB (NOT the −14 dB target); pre-duck stored value is still the value captured before the attack
- **Edge cases**: attack completes naturally before test can advance clock → skip this case if `_attack_tween.is_valid() == false` already

**AC-4 — Formula 1 clamp at −80 dB floor**
- **Given**: Music setting at −80 dB (slider fully muted)
- **When**: `Events.dialogue_line_started.emit(...)` in `plaza_calm` state
- **Then**: Tween target for MusicDiegetic is exactly `−80.0` (not −94.0); same for MusicNonDiegetic (not −86.0)
- **Edge cases**: clamp omitted → values below −80 dB are accepted by Godot but produce the floor output; test must explicitly check the tween target, not the AudioServer output

**AC-5 — document_opened ducks music and Voice bus**
- **Given**: AudioManager in plaza_calm; Voice bus at 0 dB
- **When**: `Events.document_opened.emit(&"doc_001")`
- **Then**: within 1 frame, MusicDiegetic Tween targeting max(0 − 10, −80) = −10 dB; MusicNonDiegetic targeting max(−12 − 20, −80) = −32 dB (note: capped at −80 if below); Voice bus Tween targeting max(0 + (−12), −80) = −12 dB
- **Edge cases**: document already open when another `document_opened` fires → implementation should store pre-open values once (first call only)

**AC-6 — document_closed restores pre-overlay volumes**
- **Given**: audio in document overlay duck state
- **When**: `Events.document_closed.emit(&"doc_001")`
- **Then**: Music layers tween back to `_pre_overlay_diegetic_db` / `_pre_overlay_nondiegetic_db` over 0.5 s; Voice bus restores to `_pre_overlay_voice_db` over 0.5 s
- **Edge cases**: closed without prior opened (no crash; stores default values)

**AC-7 — respawn_triggered: instant cut + 200 ms silence + 2.0 s ease-in**
- **Given**: AudioManager in any music state; dominant-guard dict with 2 active guards
- **When**: `Events.respawn_triggered.emit(&"plaza")`
- **Then**: within 1 frame: `_music_diegetic.volume_db == -80.0` (instant, not tweened); `_dominant_guard_dict.is_empty() == true`; after `respawn_silence_s` (200 ms via timer), a Tween starts targeting `MusicDiegetic → 0.0` and `MusicNonDiegetic → -12.0` over `2.0 s` TRANS_SINE
- **Edge cases**: respawn fired while document overlay is active → dominant-guard dict still cleared; overlay state restoration behavior deferred to post-VS concurrency rule

**AC-8 — Voice bus NOT ducked by VO dialogue_line_started**
- **Given**: Voice bus at 0 dB
- **When**: `Events.dialogue_line_started.emit(...)` fires
- **Then**: `AudioServer.get_bus_volume_db(voice_bus_idx)` is still `0.0` (VO duck only affects Music + Ambient, not Voice)
- **Edge cases**: implementation incorrectly calls `set_bus_volume_db` on Voice from `dialogue_line_started` handler → test catches it

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/audio/audio_vo_duck_formula1_test.gd` — covers AC-1, AC-2, AC-3, AC-4, AC-8
- `tests/unit/foundation/audio/audio_document_world_mute_test.gd` — covers AC-5, AC-6
- `tests/unit/foundation/audio/audio_respawn_cut_to_silence_test.gd` — covers AC-7
- Determinism: Formula 1 is a pure arithmetic expression; tween targets are read in the same frame as the emit (no `await`); respawn timer is advanced via `_process(delta)` in test or via timer mock

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (bus structure), Story 002 DONE (subscription wiring), Story 003 DONE (music players exist for volume targeting)
- Unlocks: Story 005 (all core audio behaviors in place; footstep/stinger are additive)
