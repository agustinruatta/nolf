# Story 005: Footstep variant routing (marble) + COMBAT stinger on actor_became_alerted

> **Epic**: Audio
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — variant selection logic + stinger debounce + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/audio.md`
**Requirement**: TR-AUD-007, TR-AUD-011
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `player_footstep(surface: StringName, noise_radius_m: float)` drives surface-keyed SFX variant selection via a 4-bucket loudness scheme (soft ≤3.5 m, normal >3.5–6.5 m, loud >6.5–10 m, extreme >10 m). SFX plays through the pre-allocated pool (`AudioStreamPlayer3D` on SFX bus). `actor_became_alerted(actor, cause, pos, severity)` schedules a brass stinger on `MusicSting` ONLY when `severity == MAJOR` AND `cause != SCRIPTED` — quantized to the next 120 BPM downbeat (0.5 s resolution) with a per-beat-window debounce (at most one stinger per 0.5 s window). The pool uses the oldest-non-critical steal rule on overflow (GDD Rule 5 + Edge Case). ADR-0008 Slot 6 is the audio dispatch performance slot (0.3 ms p95 cap, advisory until Accepted).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioStreamPlayer3D.play()`, `AudioStreamPlayer3D.get_playback_position()`, `AudioStreamPlayer.play()`, `AudioStreamPlayer.get_playback_position()` are stable 4.0+. `AudioStream.get_length()` is stable. `randi_range()` for random sample selection is stable GDScript. The stinger quantization helper is a pure float function — no engine-specific APIs needed.

**Control Manifest Rules (Foundation)**:
- Required: every Node-typed signal payload checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4) — the `actor` parameter in `_on_actor_became_alerted` must be guarded
- Forbidden: `AudioStreamPlayer.new()` at runtime for SFX — all SFX uses the pre-allocated pool from Story 001 (GDD Rule 9)
- Forbidden: any `player_footstep` subscription by Stealth AI — this signal is Audio-only per ADR-0002 Player domain delineation; enforced by Story 002's CI lint test
- Guardrail: audio dispatch slot 0.3 ms p95 cap on Iris Xe (ADR-0008 Slot 6 — advisory until Gates 1+2 pass)

---

## Acceptance Criteria

*From GDD `design/gdd/audio.md` §Footstep Surface Map + §States and Transitions stinger table + AC-7, AC-9, AC-10, AC-11, AC-34, AC-35, AC-36 scoped to VS:*

- [ ] **AC-1**: GIVEN `player_footstep(&"marble", 5.0)` fires (noise_radius in normal bucket: >3.5 ≤6.5), WHEN `AudioManager._on_player_footstep` handles it, THEN a pooled `AudioStreamPlayer3D` at the player position is playing a stream whose resource path matches `sfx_footstep_marble_normal_*` on the SFX bus. (VS: actual audio asset may be a placeholder stub; the bus routing and variant key selection are what's tested.)
- [ ] **AC-2**: GIVEN `player_footstep(&"marble", 2.0)` fires (soft bucket: ≤3.5 m), WHEN Audio handles it, THEN the selected variant key is `normal: false, loud: false, extreme: false` — i.e., the `soft` branch. If `noise_radius_m == 0.0` (crouch-idle — GDD footnote: silent, no SFX plays), THEN no pool slot is consumed.
- [ ] **AC-3**: GIVEN `player_footstep(&"marble", 12.0)` fires (extreme bucket: >10 m), WHEN Audio handles it, THEN the selected variant key is `extreme` and a pool slot is consumed with the marble-extreme stream.
- [ ] **AC-4**: GIVEN all 16 pool slots are occupied by active playbacks, WHEN `player_footstep` fires, THEN the oldest-started slot that is NOT on the Voice bus and NOT on the UI bus is stolen (its stream is replaced and play() is called). No pool slot is allocated via `AudioStreamPlayer3D.new()` — the pool is fixed size.
- [ ] **AC-5**: GIVEN `actor_became_alerted(actor, StealthAI.AlertCause.SAW_PLAYER, pos, StealthAI.Severity.MAJOR)` fires with no stinger already queued, WHEN `AudioManager._on_actor_became_alerted` handles it, THEN a stinger is scheduled to fire on the next 120 BPM downbeat (offset computed by `get_next_beat_offset_s(current_playback_pos, 120.0)`). Verified by reading `_pending_stinger_beat_time` (or equivalent pending-schedule field).
- [ ] **AC-6**: GIVEN a stinger is already queued for the upcoming downbeat AND `actor_became_alerted(_, SAW_PLAYER, _, MAJOR)` fires again within the same 0.5 s window, WHEN the second signal is handled, THEN no NEW stinger is scheduled — the second arrival is silently discarded (§Concurrency Policies Rule 1 — per-beat-window debounce).
- [ ] **AC-7**: GIVEN `actor_became_alerted(_, StealthAI.AlertCause.SCRIPTED, _, StealthAI.Severity.MAJOR)` fires (cutscene force-alert), WHEN Audio handles it, THEN NO stinger is scheduled — SCRIPTED-cause suppression (§Concurrency Policies Rule 3).
- [ ] **AC-8**: GIVEN `actor_became_alerted(_, SAW_PLAYER, _, StealthAI.Severity.MINOR)` fires, WHEN Audio handles it, THEN NO stinger is scheduled — severity filter (only MAJOR triggers stinger per GDD §AI/Stealth domain interactions table + AC-9).
- [ ] **AC-9** (pure helper unit test): GIVEN `get_next_beat_offset_s(current_playback_pos_s, 120.0)` is called with 6 parametrized inputs: `(0.0) → 0.0`, `(0.1) → 0.4`, `(0.24) → 0.26`, `(0.5) → 0.0`, `(0.3) → 0.2`, `(0.499) → 0.001`, THEN each returns the specified offset within ±0.001 s tolerance. (GDD AC-7 — pure function, no scene-tree required.)

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines + GDD §Footstep Surface Map + §States Dominant-guard rule + §Concurrency Policies Rules 1, 3:*

**Footstep variant selection** — 4-bucket lookup per GDD §Footstep Surface Map:

```gdscript
enum FootstepVariant { SOFT, NORMAL, LOUD, EXTREME }

func _select_footstep_variant(noise_radius_m: float) -> FootstepVariant:
    if noise_radius_m <= 3.5:
        return FootstepVariant.SOFT
    elif noise_radius_m <= 6.5:
        return FootstepVariant.NORMAL
    elif noise_radius_m <= 10.0:
        return FootstepVariant.LOUD
    else:
        return FootstepVariant.EXTREME

func _on_player_footstep(surface: StringName, noise_radius_m: float) -> void:
    # Silent threshold: noise_radius_m == 0.0 → crouch-idle, no SFX
    if noise_radius_m == 0.0:
        return
    var variant: FootstepVariant = _select_footstep_variant(noise_radius_m)
    var variant_key: String = "%s_%s" % [
        surface,
        FootstepVariant.find_key(variant).to_lower()
    ]
    var stream: AudioStream = _load_footstep_stream(variant_key)
    if stream == null:
        return  # asset not yet present (VS stub behavior)
    var player: AudioStreamPlayer3D = _get_or_steal_sfx_slot()
    player.stream = stream
    player.global_position = _get_player_position()
    player.play()
```

**SFX pool slot management** — steal-oldest rule (GDD Rule 5 + Edge Cases):

```gdscript
func _get_or_steal_sfx_slot() -> AudioStreamPlayer3D:
    # First pass: find an idle slot
    for player: AudioStreamPlayer3D in _sfx_pool:
        if not player.playing:
            return player
    # Second pass: steal oldest non-exempt slot
    var oldest_player: AudioStreamPlayer3D = null
    var oldest_pos: float = INF
    for player: AudioStreamPlayer3D in _sfx_pool:
        # Exempt: Voice and UI buses (GDD Edge Case — "voice and UI are exempt")
        if player.bus == &"Voice" or player.bus == &"UI":
            continue
        # Closest to start = smallest playback_position relative to stream length
        # "Oldest started" = has been playing longest = smallest remaining time
        # Using playback_position as a proxy for time-since-start
        # NOTE: get_playback_position() returns position in the stream, not wall time.
        # We invert: oldest = highest playback_position (most of stream consumed)
        if player.get_playback_position() > oldest_pos or oldest_player == null:
            oldest_pos = player.get_playback_position()
            oldest_player = player
    return oldest_player  # may be null if all slots are exempt (edge case, never happens in VS)
```

**Stinger beat quantization** — pure static helper function (GDD §States and Transitions §Alert sting quantization + AC-7 note):

```gdscript
## Returns the time in seconds until the next 120 BPM downbeat from the given playback position.
## Pure function — deterministically unit-testable without a real-time scene-tree timebase.
## Beat interval at 120 BPM = 60.0 / 120.0 = 0.5 seconds.
static func get_next_beat_offset_s(current_playback_pos_s: float, bpm: float) -> float:
    var beat_interval_s: float = 60.0 / bpm
    var pos_in_beat: float = fmod(current_playback_pos_s, beat_interval_s)
    if pos_in_beat < 0.0001:
        return 0.0  # on the beat already
    return beat_interval_s - pos_in_beat
```

**Stinger scheduling with per-beat-window debounce** (§Concurrency Policies Rule 1, Rule 3):

```gdscript
var _stinger_queued_for_beat_time: float = -INF  # -INF means no stinger queued

func _on_actor_became_alerted(
        actor: Node,
        cause: StealthAI.AlertCause,
        _source_position: Vector3,
        severity: StealthAI.Severity) -> void:
    if not is_instance_valid(actor):
        return
    # Severity filter: only MAJOR triggers a stinger
    if severity != StealthAI.Severity.MAJOR:
        return
    # SCRIPTED-cause suppression (Concurrency Policies Rule 3)
    if cause == StealthAI.AlertCause.SCRIPTED:
        return
    # Per-beat-window debounce (Concurrency Policies Rule 1)
    var current_pos: float = _music_nondiegetic.get_playback_position() \
        if _music_nondiegetic.playing else 0.0
    var next_beat_offset: float = get_next_beat_offset_s(current_pos, 120.0)
    var next_beat_abs: float = current_pos + next_beat_offset
    # Debounce: if a stinger is already queued for the same beat window, discard
    const BEAT_WINDOW_S: float = 0.5  # 120 BPM = 0.5 s per beat
    if absf(next_beat_abs - _stinger_queued_for_beat_time) < BEAT_WINDOW_S * 0.9:
        return
    # Schedule the stinger
    _stinger_queued_for_beat_time = next_beat_abs
    get_tree().create_timer(next_beat_offset).timeout.connect(
        func() -> void:
            _play_stinger()
            _stinger_queued_for_beat_time = -INF,
        CONNECT_ONE_SHOT)

func _play_stinger() -> void:
    if _music_sting == null:
        return
    _music_sting.stop()
    _music_sting.play()
```

**VS simplification**: `_load_footstep_stream()` returns a stub stream (or `null`) in VS since audio assets are not yet produced. The variant key routing logic and pool slot selection are fully testable against stub or null streams.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 003, 004: already handle section music, reverb, VO ducking, document mute, respawn

**Deferred post-VS** (do NOT implement in this story):
- TR-AUD-012 (full takedown SFX library): no takedowns in VS; `_on_takedown_performed` handler body deferred to post-VS
- TR-AUD-007 full pool: the 16-slot steal logic is implemented; actual spatial SFX asset loading (guard footsteps, weapon fire variants) is deferred to content production
- TR-AUD-011 full footstep matrix: only `marble` surface implemented for VS; remaining 6 surfaces (`tile`, `wood_stage`, `carpet`, `metal_grate`, `gravel`, `water_puddle`) deferred to post-VS content production
- TR-AUD-005 music state SUSPICIOUS/SEARCHING transitions: VS validates UNAWARE + COMBAT only; the `alert_state_changed` handler for these intermediate states deferred
- Stinger "no music playing" fallback (GDD Edge Case — if `actor_became_alerted` fires with no active music, `MusicSting` plays immediately and `MusicNonDiegetic` fades in): deferred to post-VS (VS always starts in `plaza_calm` with music active)

---

## QA Test Cases

**AC-1 — marble normal variant selected for 5.0 m noise radius**
- **Given**: AudioManager with a populated SFX pool; a stub stream registered for key `marble_normal`
- **When**: `Events.player_footstep.emit(&"marble", 5.0)`
- **Then**: `_select_footstep_variant(5.0) == FootstepVariant.NORMAL`; an SFX pool slot is playing with the marble-normal stream key; pool slot bus is `&"SFX"`
- **Edge cases**: boundary exactly at 3.5 → SOFT (not NORMAL); boundary exactly at 6.5 → NORMAL (not LOUD)

**AC-2 — zero noise radius is silent (crouch-idle)**
- **Given**: all 16 pool slots are idle
- **When**: `Events.player_footstep.emit(&"marble", 0.0)`
- **Then**: all 16 pool slots remain not-playing; no stream was assigned or started
- **Edge cases**: 0.001 m is above the threshold → SOFT variant plays (test boundary)

**AC-3 — extreme variant for Sprint (12.0 m)**
- **Given**: AudioManager with marble-extreme stub stream registered
- **When**: `Events.player_footstep.emit(&"marble", 12.0)`
- **Then**: `_select_footstep_variant(12.0) == FootstepVariant.EXTREME`; pool slot playing marble-extreme stream
- **Edge cases**: 10.0 m exactly → LOUD boundary (not EXTREME); 10.001 m → EXTREME

**AC-4 — pool steal: oldest non-exempt slot stolen when pool full**
- **Given**: all 16 pool slots are playing; one is the oldest (highest playback_position); none are on Voice or UI bus
- **When**: `_get_or_steal_sfx_slot()` is called
- **Then**: the returned player is the one with the highest playback_position (oldest started) among non-exempt slots; no `AudioStreamPlayer3D.new()` is called
- **Edge cases**: all occupied slots are on Voice/UI (impossible in practice for SFX pool, but guard returns null)

**AC-5 — MAJOR stinger is scheduled on next downbeat**
- **Given**: AudioManager with MusicNonDiegetic playing at position 0.1 s; no stinger queued
- **When**: `Events.actor_became_alerted.emit(guard_node, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MAJOR)`
- **Then**: `get_next_beat_offset_s(0.1, 120.0) == 0.4`; a timer of 0.4 s is scheduled; `_stinger_queued_for_beat_time` is set to `0.1 + 0.4 = 0.5`
- **Edge cases**: actor is a freed Node → `is_instance_valid` guard returns early; MINOR → no schedule (AC-8)

**AC-6 — per-beat-window debounce: second MAJOR in same window discarded**
- **Given**: a stinger already queued for beat time 0.5 s
- **When**: a second `actor_became_alerted(_, SAW_PLAYER, _, MAJOR)` fires with `current_pos = 0.15 s` (next beat at 0.5 s — same window)
- **Then**: `_stinger_queued_for_beat_time` is still the original 0.5 s (not updated); no new timer is created
- **Edge cases**: second arrival in the NEXT window (≥0.5 s after first) → new stinger IS scheduled

**AC-7 — SCRIPTED cause: no stinger**
- **Given**: no stinger queued
- **When**: `Events.actor_became_alerted.emit(guard_node, StealthAI.AlertCause.SCRIPTED, Vector3.ZERO, StealthAI.Severity.MAJOR)`
- **Then**: `_stinger_queued_for_beat_time` remains at `−INF`; no timer created; `_music_sting.playing == false`
- **Edge cases**: SCRIPTED + MINOR → still no stinger (both filters apply)

**AC-8 — MINOR severity: no stinger**
- **Given**: no stinger queued
- **When**: `Events.actor_became_alerted.emit(guard_node, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MINOR)`
- **Then**: `_stinger_queued_for_beat_time` remains at `−INF`; no timer created
- **Edge cases**: MINOR + SCRIPTED (double suppression) → still no stinger

**AC-9 — get_next_beat_offset_s pure function: 6 parametrized inputs**
- **Given**: the static pure function `get_next_beat_offset_s(pos, 120.0)` with no scene dependencies
- **When**: called with each of the 6 values: 0.0, 0.1, 0.24, 0.5, 0.3, 0.499
- **Then**: returns 0.0, 0.4, 0.26, 0.0, 0.2, 0.001 respectively (±0.001 tolerance for float precision)
- **Edge cases**: negative input (non-physical; function should handle gracefully via `fmod` wrapping or clamp)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/audio/audio_footstep_variant_selection_test.gd` — covers AC-1, AC-2, AC-3 (parametrized footstep table)
- `tests/unit/foundation/audio/audio_sfx_pool_steal_test.gd` — covers AC-4 (steal logic)
- `tests/unit/foundation/audio/audio_stinger_debounce_test.gd` — covers AC-5, AC-6, AC-7, AC-8
- `tests/unit/foundation/audio/audio_beat_quantization_test.gd` — covers AC-9 (pure function, no scene required)
- Determinism: all tests use fixed `noise_radius_m` constants; `get_next_beat_offset_s` is a pure function with no random component; stinger scheduling is tested via `_stinger_queued_for_beat_time` field inspection (not by waiting for the timer)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (SFX pool), Story 002 DONE (subscription wiring), Story 003 DONE (MusicNonDiegetic + MusicSting players for stinger scheduling)
- Unlocks: VS Epic Definition of Done — all VS acceptance criteria implemented and testable

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 9/9 passing (27 test functions exceed minimum, including parametrized AC-9 quantization variants)
**Deviations**: None blocking. Two VS stubs documented:
- `_load_footstep_stream(variant_key)` returns null per TR-AUD-007 deferral (audio asset content production post-VS); footstep handler returns silently on null stream
- `_get_player_position()` returns Vector3.ZERO (PlayerCharacter reference wiring is post-VS)

**Test Evidence**: `tests/unit/foundation/audio/audio_footstep_stinger_test.gd` (27 test functions covering AC-1..AC-9; pure-function `get_next_beat_offset_s` parametrized for 6 input/output pairs)

**Implementation Highlights**:
- 16-slot SFX pool created in `_setup_sfx_pool()` called from `_ready()` (per GDD Rule 9 — pre-allocated, never `AudioStreamPlayer.new()` at runtime)
- `_get_or_steal_sfx_slot()` two-pass algorithm: first idle, then oldest non-Voice/UI exempt
- `get_next_beat_offset_s()` is pure `static func` — testable independently of scene tree
- 4-bucket variant selection: SOFT (≤3.5m), NORMAL (>3.5–6.5m), LOUD (>6.5–10m), EXTREME (>10m)
- Stinger debounce via `_stinger_queued_for_beat_time` per-beat-window check
- SCRIPTED-cause + non-MAJOR severity early-returns implemented per AC-7/AC-8
- Subscriber-only invariant maintained — zero `Events.*.emit(` calls in audio_manager.gd

**Code Review**: Static structural verification PASS. LP-CODE-REVIEW + QL-TEST-COVERAGE gates skipped (Lean review mode).

**Audio Epic Status**: All 5 must-have stories Complete (AUD-001+002 from Sprint 02, AUD-003+004+005 this sprint). VS Epic Definition of Done reached.
