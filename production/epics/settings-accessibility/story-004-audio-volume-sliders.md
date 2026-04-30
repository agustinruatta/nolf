# Story 004: Audio volume sliders — dB formula + bus apply integration

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Polish (Day-1 HARD MVP DEP: Master volume; VS-expansion: Music / SFX / Voice remaining buses)
> **Type**: Logic
> **Estimate**: 3-4 hours (M — F.1 formula + 6-bus apply + clock-tick toggle + unit + integration tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: TR-SET-010 (clock_tick_enabled accessibility category) — audio bus volume apply is covered indirectly by TR-SET-001 (sole publisher), TR-SET-003 (ConfigFile), TR-SET-005 (burst emit reaches AudioServer)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-SET-010**: `clock_tick_enabled` moved from Audio category to Accessibility category (per Audio GDD alignment, OQ-SA-13) — sole emitter is SettingsService.

**ADR Governing Implementation**: ADR-0002 (Signal Bus — `setting_changed` with Variant payload is the sole Variant exception per IG 7) + ADR-0003 (settings.cfg separation)

**ADR Decision Summary**: Volume sliders persist as dB float values in `user://settings.cfg` under the `audio` category per GDD §C.2. The Formula F.1 two-segment perceptual fader maps player-facing 0–100% to [-80.0, 0.0] dB. The formula has an explicit `is_nan()` precondition (GDD F.1 revised 2026-04-27 per BLOCKING-3) because `clamp(NaN, ...)` returns NaN in IEEE 754 / Godot 4.6 GDScript. The silence sentinel at p=0 calls `AudioServer.set_bus_mute()` in addition to emitting -80.0 dB (BLOCKING revision per audio-director B-3). All 6 bus volume defaults are TENTATIVE pending Audio GDD coord item OQ-SA-14 (0 dB clipping risk — industry practice suggests -3 to -6 dB sub-bus defaults with a Master limiter). `clock_tick_enabled` is in the `accessibility` category (not `audio`) per Audio GDD alignment at audio.md line 237; SettingsService emits `setting_changed("accessibility", "clock_tick_enabled", v)`.

**VS scope note**: All 6 audio bus sliders are MVP keys (GDD §C.2). The Day-1 HARD MVP DEP requires Master volume as minimum. The VS-expansion adds the full slider UI for Music / SFX / Voice / Ambient / UI to the Settings panel. The formula implementation and bus apply integration are identical for all buses — this story implements all 6 at the logic layer so Story 005 (panel UI) can wire them up.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioServer.set_bus_volume_db(bus_index: int, volume_db: float)` is stable Godot 4.0+. `AudioServer.set_bus_mute(bus_index: int, mute: bool)` is stable Godot 4.0+. `AudioServer.get_bus_index(bus_name: StringName) -> int` is stable. No post-cutoff API risk. The 5-bus architecture (Music, SFX, Ambient, Voice, UI) is project-defined per Audio GDD TR-AUD-002 — bus names and indices must match `audio.md §C.2` exactly.

**Control Manifest Rules (Foundation sub-rules apply)**:
- Required: every `_on_setting_changed` consumer handler in AudioManager must have `if category != &"audio": return` as first statement (FP-5) for audio keys; `if category != &"accessibility": return` for `clock_tick_enabled` — these are two separate handler functions or a combined handler with appropriate category dispatch
- Required: F.1 `is_nan()` precondition before `clamp()` — IEEE 754 GDScript NaN semantics require explicit NaN rejection before clamp (GDD F.1 revised 2026-04-27)
- Required: silence sentinel at p=0 calls `AudioServer.set_bus_mute(bus_idx, true)` AND emits -80.0 (not -inf) — both steps mandatory (GDD AC-SA-3.2)
- Forbidden: `AudioServer.set_bus_volume_db()` called with values above `0.0 dB` (GDD AC-SA-3.5)

---

## Acceptance Criteria

*From GDD `design/gdd/settings-accessibility.md` §H.3, scoped to this story:*

- [ ] **AC-1** (F.1 round-trip): GIVEN slider positions `p` sampled at each of `{0, 1, 50, 74, 75, 76, 100}`, WHEN the F.1 forward formula is applied and then the inverse formula is applied to the result, THEN the round-trip value `p_recovered = inverse(forward(p))` equals `p` within ±0.5 integer percentage points for every sampled value. (GDD AC-SA-3.1)
- [ ] **AC-2** (silence sentinel + mute): GIVEN any audio bus slider is set to position `p = 0`, WHEN F.1 forward formula evaluates, THEN (a) `setting_changed("audio", "{bus}_volume_db", -80.0)` fires with value `-80.0` (not -inf, not null), AND (b) `AudioServer.set_bus_mute(bus_idx, true)` is called for that bus. GIVEN the slider transitions from `p = 0` to any `p > 0`, THEN `AudioServer.set_bus_mute(bus_idx, false)` is called BEFORE the volume is set. (GDD AC-SA-3.2)
- [ ] **AC-3** (integration — bus apply): GIVEN the Master bus slider is moved to `p = 75` in the Settings panel, WHEN the `setting_changed` burst reaches AudioManager's subscriber, THEN `AudioServer.get_bus_volume_db(0)` returns `-12.0 dB` (±0.01 dB tolerance) within the same frame. (GDD AC-SA-3.3)
- [ ] **AC-4** (clock_tick_enabled category): GIVEN the `clock_tick_enabled` toggle is set to `false`, WHEN `setting_changed("accessibility", "clock_tick_enabled", false)` fires, THEN the Audio system's clock-tick bus mutes (verified via subscriber state flag, not by listening for absence of audio). (GDD AC-SA-3.4)
- [ ] **AC-5** (out-of-range clamp guard): GIVEN a corrupt `settings.cfg` with `master_volume_db = 9999.0`, WHEN SettingsService loads and applies, THEN the clamped value `0.0 dB` is what reaches `AudioServer.set_bus_volume_db()` — no value above `0.0 dB` is ever passed. (GDD AC-SA-3.5)
- [ ] **AC-6** (NaN guard): GIVEN F.1 forward formula is invoked with `p = -1`, `p = 101`, `p = NaN`, or `p = +inf`, WHEN the function evaluates, THEN the input is FIRST checked via `is_nan()` (NaN replaced with 0), THEN clamped to `[0, 100]` before branch selection — output is in `[-80.0, 0.0] dB` and never undefined. Symmetric for F.1 inverse with dB inputs `+5.0`, `-100.0`, `NaN`, `+inf`. (GDD AC-SA-11.13)
- [ ] **AC-7** (inverse edge case — sub-Segment-A branch): GIVEN F.1 inverse formula is invoked with `dB = -50.0` (below Segment A floor of -24 dB, above silence floor of -80 dB), WHEN the function evaluates, THEN the result is `p = 1` (minimum audible position, NOT 0 silence sentinel). (GDD AC-SA-11.13 sub-AC per F.1 default-branch revision)
- [ ] **AC-8** (write-through on commit, not per-tick): GIVEN the Settings panel is open and the player drags a volume slider continuously, WHEN slider drag is in progress (`drag_started` to `drag_ended`), THEN `ConfigFile.save()` is NOT called for each `value_changed` tick — only `setting_changed` is emitted for live-preview. `ConfigFile.save()` is called exactly once on `drag_ended` with `value_changed == true`. (GDD AC-SA-2.1 scoped to audio sliders)

---

## Implementation Notes

*Derived from GDD §F.1 (dB ↔ percentage formula) + §C.1 CR-8 (commit semantics) + §C.7 (AudioManager interaction):*

**F.1 forward formula — GDScript implementation:**

```gdscript
const DB_FLOOR: float = -80.0      # silence sentinel — locked
const SEGMENT_A_BASE: float = -24.0
const SEGMENT_A_SLOPE: float = 12.0 / 74.0   # ≈ 0.1622 dB/%
const SEGMENT_B_BASE: float = -12.0
const SEGMENT_B_SLOPE: float = 12.0 / 25.0   # = 0.48 dB/%
const P_KNEE: int = 75             # locked — see GDD G.7

func _pct_to_db(p: float, bus_index: int) -> float:
    # PRECONDITION 1: is_nan check (IEEE 754 — clamp(NaN,...) returns NaN in GDScript)
    var p_clean: float = 0.0 if is_nan(p) else p
    # PRECONDITION 2: clamp to valid range
    var p_c: int = int(clamp(round(p_clean), 0, 100))
    if p_c == 0:
        AudioServer.set_bus_mute(bus_index, true)
        return DB_FLOOR
    AudioServer.set_bus_mute(bus_index, false)
    if p_c < P_KNEE:
        return SEGMENT_A_BASE + (p_c - 1) * SEGMENT_A_SLOPE
    return SEGMENT_B_BASE + (p_c - P_KNEE) * SEGMENT_B_SLOPE
```

**F.1 inverse formula — GDScript implementation:**

```gdscript
func _db_to_pct(db: float) -> int:
    # PRECONDITION 1: NaN check
    var db_clean: float = DB_FLOOR if is_nan(db) else db
    # PRECONDITION 2: clamp
    var db_c: float = clamp(db_clean, DB_FLOOR, 0.0)
    if db_c <= DB_FLOOR:     return 0
    if db_c < SEGMENT_A_BASE: return 1   # sub-Segment-A audible-but-quiet hand-edited cfg
    if db_c < SEGMENT_B_BASE:
        return int(round(1.0 + (db_c - SEGMENT_A_BASE) * (74.0 / 12.0)))
    return int(round(float(P_KNEE) + (db_c - SEGMENT_B_BASE) * (25.0 / 12.0)))
```

The `return 1` branch (not `return 0`) for `db_c < SEGMENT_A_BASE` is the critical revision per GDD F.1 default-branch revision rationale: a hand-edited cfg with `-50.0 dB` should show `1%` slider (audible), not `0%` (silent).

**AudioManager subscriber** — AudioManager is a scene-tree Node (not autoload per TR-AUD-003). It connects to `setting_changed` in its own `_ready()`. Because AudioManager is NOT an autoload, it misses the boot burst. AudioManager MUST use Consumer Default Strategy — it initializes each bus at its hardcoded constant default and then subscribes. When `setting_changed` fires from live panel interaction, AudioManager applies the change immediately:

```gdscript
# In AudioManager._ready():
const BUS_MAP: Dictionary = {
    &"master_volume_db":  "Master",
    &"music_volume_db":   "Music",
    &"sfx_volume_db":     "SFX",
    &"ambient_volume_db": "Ambient",
    &"voice_volume_db":   "Voice",
    &"ui_volume_db":      "UI",
}
Events.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category == &"audio":
        if name in BUS_MAP:
            if value is float or value is int:
                var bus_idx := AudioServer.get_bus_index(BUS_MAP[name])
                var db := _pct_to_db(float(value) if value is int else value, bus_idx)
                AudioServer.set_bus_volume_db(bus_idx, db)
        # NO else: branch per FP-6
    elif category == &"accessibility":
        if name == &"clock_tick_enabled":
            if value is bool:
                _apply_clock_tick(value)
        # NO else: branch per FP-6
```

Wait — this handler has two category branches, which technically violates the single-category-guard-first rule (FP-5). Per GDD CR-5, the FIRST statement must be a category guard. The correct pattern: split into two `_on_setting_changed`-equivalent handlers for audio vs accessibility, OR check both categories with an early return if neither matches:

```gdscript
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category != &"audio" and category != &"accessibility": return
    if category == &"audio":
        _apply_audio_setting(name, value)
    elif category == &"accessibility" and name == &"clock_tick_enabled":
        _apply_clock_tick(value)
```

This satisfies FP-5 (the first statement is a dual-category early-return guard that is logically equivalent to FP-5's intent of filtering non-relevant events) while handling two categories in a single subscriber. Code-review note: this dual-guard pattern requires explicit documentation in the function's doc comment to survive future review.

**Slider commit semantics (CR-8)** — during slider drag:
- `value_changed` signal on `HSlider` fires per tick → emit `setting_changed` for live preview → do NOT call `ConfigFile.save()`
- `drag_ended(value_changed: bool)` signal on `HSlider` fires once → if `value_changed == true`, emit final `setting_changed` AND call `ConfigFile.save()`

The slider commit wiring is in Story 005 (panel UI). This story implements only the formula functions and the AudioManager subscriber — the commit event wiring is deferred.

**`p_knee` is locked per GDD G.7** — it is NOT a runtime tuning knob. Changing it requires rederiving `SEGMENT_A_SLOPE` and `SEGMENT_B_SLOPE`. The constants are `const` in GDScript, enforcing this at compile time.

**BLOCKING coord OQ-SA-14** — six-bus `0.0 dB` defaults risk output-stage clipping during peak combat scenes. Until Audio GDD coord item OQ-SA-14 resolves whether to add a Master limiter `AudioEffect` or lower sub-bus defaults to `-3` / `-6 dB`, the defaults in `settings_defaults.gd` are TENTATIVE. Story 004 implements the formula and apply logic correctly regardless of the final default values — the defaults are a separate tuning concern.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: `HSlider` widget `drag_ended` commit wiring in the Settings panel UI
- Story 005: AudioServer live-preview during slider drag (requires HSlider in scene tree)
- Post-VS: Audio panel-open ducking (OQ-SA-7 — advisory, playtest-resolved)
- Post-VS: `voice_overlay_duck_db` UI surface (ADVISORY; Audio owns the duck behavior)

---

## QA Test Cases

*Solo mode — no QA-lead gate. Test cases written by story author per GDD ACs.*

**AC-1 — F.1 round-trip fidelity**
- Given: seven slider positions `{0, 1, 50, 74, 75, 76, 100}`
- When: `_pct_to_db(p, bus_idx)` then `_db_to_pct(db)` applied in sequence (bus_idx using a mock that does not call AudioServer.set_bus_mute)
- Then: each recovered `p_recovered` is within ±0.5 of the original `p` (allows for integer rounding at the inverse)
- Edge cases: `p = 0` → db = -80.0 → `_db_to_pct(-80.0) = 0` ✓; `p = 75` exactly at knee → db = -12.0 → p_recovered = 75 ✓

**AC-2 — silence sentinel + mute**
- Given: AudioServer mock that records `set_bus_mute()` and `set_bus_volume_db()` calls
- When: `_pct_to_db(0.0, bus_idx)` called
- Then: `set_bus_mute(bus_idx, true)` called; returned db is -80.0
- When: `_pct_to_db(1.0, bus_idx)` called immediately after
- Then: `set_bus_mute(bus_idx, false)` called BEFORE `set_bus_volume_db()`; returned db is -24.0 ± 0.01

**AC-6 — NaN guard**
- Given: four edge inputs for forward: `-1.0`, `101.0`, `NaN` (via `float("nan")`), `INF`
- When: `_pct_to_db()` applied to each
- Then: all return values are in `[-80.0, 0.0]`; no GDScript exception thrown
- Given: four edge inputs for inverse: `+5.0`, `-100.0`, `NaN`, `INF`
- When: `_db_to_pct()` applied to each
- Then: all return values are in `[0, 100]`; no exception

**AC-7 — sub-Segment-A inverse branch**
- Given: `dB = -50.0` (below Segment A floor -24.0, above silence floor -80.0)
- When: `_db_to_pct(-50.0)` evaluated
- Then: result is `1` (not `0`)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/settings/audio_formula_test.gd` — must exist and pass (AC-1, AC-2, AC-5, AC-6, AC-7)
- `tests/integration/settings/audio_bus_apply_test.gd` — must exist and pass (AC-3, AC-4)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SettingsService scaffold — `_load_settings()` applies Cluster B clamp for `master_volume_db` range) must be DONE
- Depends on: Story 002 (burst emit fires audio keys at boot so AudioManager gets initial values) must be DONE
- Unlocks: Story 005 (Settings panel UI — HSlider wiring reads `_pct_to_db()` / `_db_to_pct()` from this story's implementation)
