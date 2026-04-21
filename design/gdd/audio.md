# Audio

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (game-designer, audio-director, sound-designer per routing)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Pillar 3 (Stealth is Theatre — alert state via music); Pillar 1 (Comedy Without Punchlines — guard banter, absurd SFX); Pillar 5 (Period Authenticity — 1960s jazz/lounge score)

## Summary

Audio is *The Paris Affair*'s most identity-defining Foundation system — it carries the game's NOLF1 fidelity commitment by signaling AI alert state through **dynamic music transitions** (never through visuals) and delivers the 1960s jazz-lounge score, guard banter VO, spatialized gunfire, and period SFX that the game's tone lives or dies on. Audio subscribes to 5 event domains on the Signal Bus (AI/Stealth, Combat, Mission, Civilian, Dialogue); it publishes nothing. Implementation uses Godot 4.6's audio bus system with pooled `AudioStreamPlayer3D` for spatial SFX and `AudioStreamPlayer` for BGM/UI. Settings & Accessibility owns volume persistence.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Signal Bus (ADR-0002)` · Key subscriptions: AI/Stealth + Combat + Mission + Civilian + Dialogue event domains

## Overview

Audio is the backbone of *The Paris Affair*'s atmosphere and the carrier of its most important design rule: **alert state is signaled through music, not visuals** (per the NOLF1 fidelity commitment locked in `feedback_visual_state_signaling` memory). When Eve slips from unaware into "suspicious" AI range, the music shifts. When a guard spots her, it swells. When she slips back into cover and the alert de-escalates, the music settles. The player learns to trust their ears more than the HUD — which is exactly what stealth theatre requires.

Architecturally, Audio is a **subscriber-only** system. It listens to the Signal Bus (ADR-0002) for events in **eight domains** (revised 2026-04-20 re-review — added Player + Documents + Persistence):

- **AI/Stealth** — `alert_state_changed` drives music; `actor_became_alerted` drives positional stingers
- **Combat** — `weapon_fired`, `player_damaged`, `player_health_changed` drive SFX and critical-health clock-tick
- **Player** *(ADR-0002 amendment 2026-04-19)* — `player_footstep` drives surface-mapped footstep SFX; `player_interacted` drives interact-confirmation SFX
- **Mission** — `section_entered`, `objective_completed` drive music-location transitions + sting hits
- **Civilian** — `civilian_panicked` drives distress SFX + music bedlam-layer
- **Dialogue** — `dialogue_line_started` / `dialogue_line_finished` drive VO playback and music ducking
- **Documents** — `document_collected` drives pickup SFX; `document_opened` / `document_closed` drive overlay music duck
- **Persistence** *(added 2026-04-20)* — `game_saved` / `save_failed` drive confirm/error chimes on save

Audio does NOT publish cross-system events. Audio does NOT know about individual systems — it reacts to typed signals. **VO playback clarification (2026-04-20 re-review)**: Audio plays VO audio files but does not own dialogue-timing semantics. `dialogue_line_started` and `dialogue_line_finished` are both emitted by Dialogue & Subtitles GDD (VS-tier, unwritten) using VO-metadata duration fields — NOT by Audio via `AudioStreamPlayer.finished` callback. Audio stays strictly subscriber-only; the two systems react to the same signals independently.

At the bus level, Audio defines five named `AudioServer` buses (Music, SFX, Ambient, Voice, UI) so Settings & Accessibility can expose per-category volume sliders. Spatial 3D audio (guard footsteps, gunfire, civilian chatter) uses pooled `AudioStreamPlayer3D` nodes with inverse-distance attenuation. Music and UI sounds use non-spatial `AudioStreamPlayer`. Crossfades between music tracks use Tweens on `volume_db`. Godot 4.6 introduced no breaking changes to the audio API — this GDD uses the stable 4.0+ pattern.

## Player Fantasy

**"The Operative in the Spotlight."** The player is a guest at a party that is secretly hostile — and the soundtrack knows it.

**Diegetic audio carries the fantasy first.** In the Plaza, a live quartet plays a slinky vibraphone-led bossa (Mancini's *"Lujon"* / *Pink Panther* lounge-cut register); champagne flutes clink, distant French laughter, the muted clack of heels on marble. At the Restaurant, a small combo, chandelier glassware, table conversation in three overlapping registers. In the Upper Structure, wind and the distant Paris city-hum.

**Non-diegetic score sits underneath.** When the player ducks behind a pillar to pick a lock, a non-diegetic layer slides in beneath the diegetic source — a walking upright bass and brushed snare, *Our Man Flint* "westerns-meets-Paris" register. This is the stealth cool.

**Alert transitions are the stealth state machine made audible.** When a guard turns and perceives Eve, the diegetic quartet drops out and Goldsmith-style brass stabs punch in on the downbeat the guard's head moves. When Eve slips back behind cover and alert de-escalates, the brass pulls back and the bossa returns. The player does not need to check a HUD to know what the AI knows — the music tells them. (Pillar 3: Stealth is Theatre.)

**Comedy layers over the straight score.** Guard banter is deadpan ("Henri said the shrimp were *suspect*"), ambient chatter is absurdist, and the score plays everything straight beneath it — which is exactly how Pillar 1 (Comedy Without Punchlines) is defined: the world is funny; the protagonist (and, by extension, the score) is not. (Pillar 1: Comedy Without Punchlines.)

**Every sonic element is period-authentic.** Brass (Goldsmith, Mancini), Hammond organ accents, pizzicato strings, bongos and finger-snaps as percussion, vibraphone lead, upright bass. Period SFX: champagne flute clinks, period revolver ratchet (not modern pistol), tube-radio static, 1960s Bell telephone ring. No modern synth, no reverb-heavy ambient pads, no orchestral Hollywood swells. (Pillar 5: Period Authenticity.)

Reference touchstones, per the Art Bible: Mancini (*Peter Gunn*, *Pink Panther*, "Lujon"), Goldsmith (*The Man from U.N.C.L.E.*), Jerry Goldsmith + John Barry brass writing, *Our Man Flint* (1966), *The Avengers* ITV scores (1965 Laurie Johnson), *Matt Helm* film scores, the *Mission: Impossible* TV theme (Schifrin) — used sparingly as a tempo reference, not as a period cue.

## Detailed Design

### Core Rules

1. **Bus structure is the volume contract.** Five `AudioServer` buses exist: `Music`, `SFX`, `Ambient`, `Voice`, `UI`. Every `AudioStreamPlayer` / `AudioStreamPlayer3D` in the game sets its `bus` property to one of these five names at node creation. No node routes to `Master` directly. Settings & Accessibility maps one slider per bus: `setting_changed("audio", "[bus]_volume", value_db)` → `AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"[bus]"), value_db)`.
2. **Per-section reverb buses.** Each section (Plaza, Lower Scaffolds, Restaurant, Upper Structure, Bomb Chamber) has one `AudioEffectReverb` preset applied as a bus effect on the `SFX` bus. The preset is swapped on `section_entered`. Plaza = exterior open; Scaffolds = metal-resonant medium; Restaurant = warm medium room; Upper Structure = exterior cold (long tail); Bomb Chamber = small hard-surface (bright, short).
3. **Audio connects to Events at startup; disconnects on exit.** `AudioManager.gd` is a scene-tree `Node`, NOT an autoload (settled 2026-04-20 — closes prior OQ; subscriber lifecycle fits a Node better; autoload reserved for truly global contracts like `Events`, `SaveLoad`). It connects all subscriptions in `_ready()` and disconnects with `is_connected` guards in `_exit_tree()` — the mandatory Signal Bus subscriber lifecycle from ADR-0002. Subscriptions (**27 signals across 6 domains + Settings**, 2026-04-20 re-review):
   - **AI/Stealth (4)**: `alert_state_changed`, `actor_became_alerted`, `actor_lost_target`, `takedown_performed`
   - **Combat (5)**: `weapon_fired`, `player_damaged`, `player_health_changed`, `enemy_damaged`, `enemy_killed`, `player_died` (6 total — `player_health_changed` added 2026-04-20 re-review to drive the 25%-threshold clock-tick trigger in Critical Health section)
   - **Player (2)** *(ADR-0002 amendment 2026-04-19 / Audio GDD revision 2026-04-20)*: `player_footstep`, `player_interacted`
   - **Mission (5)**: `section_entered`, `objective_started`, `objective_completed`, `mission_started`, `mission_completed`, `respawn_triggered` (6 total — `respawn_triggered` was always subscribed; list corrected)
   - **Civilian (2)**: `civilian_panicked`, `civilian_witnessed_event`
   - **Dialogue (2)**: `dialogue_line_started`, `dialogue_line_finished` *(subscribed-only — Audio plays the VO file; Dialogue & Subtitles GDD owns emission timing via VO-metadata duration fields, not via `AudioStreamPlayer.finished`. Audio remains subscriber-only.)*
   - **Documents (3)**: `document_collected`, `document_opened`, `document_closed` (added `document_collected` 2026-04-20 re-review — the SFX catalog already defined the envelope-slide SFX for this signal; subscription list now matches)
   - **Persistence (3)** *(added 2026-04-20 re-review, resolves cross-review B6)*: `game_saved`, `game_loaded`, `save_failed`
   - **Settings (1)**: `setting_changed`
4. **Music is two simultaneous layers, not one track.** The Music bus carries three persistent `AudioStreamPlayer` nodes: `MusicDiegetic` (in-world source — quartet, combo, city hum), `MusicNonDiegetic` (non-diegetic score — upright bass, brushed snare, stealth cool), and `MusicSting` (one-shot alert stabs and victory stings). The `MusicDiegetic` and `MusicNonDiegetic` volume_db values are driven independently by the state machine (below). `MusicSting` is fire-and-forget and returns to silence on `finished`.
5. **Spatial SFX uses one global pool of 16 `AudioStreamPlayer3D` nodes.** Pre-created in `_ready()`, all routed to `SFX` bus. A single global pool (not per-category) — this game's SFX density does not stress 16 slots. Anti-starvation: if all slots are occupied, the new request steals the oldest-started slot that is not gameplay-critical (voice and UI are exempt; they use non-spatial `AudioStreamPlayer`).
6. **Music crossfade rule: Tween on `volume_db`, never stop-and-start.** All music transitions use `create_tween().tween_property(player, "volume_db", target_db, duration)`. In-coming layer fades up; out-going layer fades down in parallel. **Default crossfade: 2.0 s ease-in-out** for non-alert transitions (section changes, document-overlay restores). Silence-cut only for mission-complete sting and cutscene track swap. Alert-state crossfades use the table in C.2.
7. **Voice (VO) ducking.** When `dialogue_line_started` fires, `AudioManager` tweens `Music` bus volume by **−8 dB** and `Ambient` bus volume by **−6 dB** over 0.3 s. When `dialogue_line_finished` fires, both buses restore over 0.5 s. The `Voice` bus is not ducked (it is the source). The `UI` bus is not ducked. `MusicDiegetic` and `MusicNonDiegetic` duck equally.
8. **Music is preloaded per section, not streamed.** Both music layers (diegetic + non-diegetic) for the current section are fully loaded into memory when `section_entered` fires. Total budget: ~8–12 MB per section, two stereo OGG layers. Rationale: tight crossfades are load-bearing for Pillar 3 (music signals alert state); a 30–80 ms seek-latency gap undermines the design promise. Memory cost is negligible on PC.
9. **Anti-pattern fences.**
   - NEVER call `AudioStreamPlayer.new()` at runtime for SFX — all SFX nodes are pre-allocated.
   - NEVER set `bus = "Master"` on any node.
   - NEVER drive music state from a timer or `_process()` — music state changes only in response to `Events` signal handlers.
   - NEVER let `AudioManager` query any other system (no `get_node("/root/StealthAI")`). Subscriber only.
   - NEVER play VO through the `SFX` bus — VO uses dedicated `AudioStreamPlayer` on the `Voice` bus.

### States and Transitions

Music state is `[location]_[alert_level]`. Location ∈ `{plaza, scaffolds, restaurant, upper, chamber}`. Alert level ∈ `{calm, suspicious, searching, combat}`. Special states override the grid.

#### State table

| State ID | `MusicDiegetic` | `MusicNonDiegetic` | Notes |
|---|---|---|---|
| `*_calm` | 0 dB (full) | −12 dB (low bed) | Quartet/combo audible; score barely present |
| `*_suspicious` | −6 dB (receding) | −3 dB (rising) | Score emerges; diegetic dims |
| `*_searching` | −18 dB (far) | 0 dB (full) | Score dominates; diegetic barely audible |
| `*_combat` | −80 dB (silent) | 0 dB (full) | Pure score; brass-heavy variation |
| `DOCUMENT_OVERLAY` | −10 dB | −20 dB (suppressed) | Both layers recede while doc is open |
| `CUTSCENE` | −80 dB | Crossfade to `cutscene` track | Cutscene track routed to Music bus |
| `MAIN_MENU` | −80 dB (silent) | Menu track at 0 dB | Menu track is a separate non-diegetic asset |
| `MISSION_COMPLETE` | −80 dB | −80 dB | Victory sting plays on `MusicSting`; ambient returns after |

#### Trigger table

| Signal | Payload condition | State transition | Crossfade |
|---|---|---|---|
| `section_entered` | any | `*_calm` for new location | **2.0 s ease-in-out** |
| `alert_state_changed` | `new == StealthAI.AlertState.SUSPICIOUS` | `*_suspicious` | 1.5 s linear |
| `alert_state_changed` | `new == StealthAI.AlertState.SEARCHING` | `*_searching` | 0.8 s linear |
| `alert_state_changed` | `new == StealthAI.AlertState.COMBAT` | `*_combat` | 0.3 s cut |
| `alert_state_changed` | `new == StealthAI.AlertState.UNAWARE` | `*_calm` | 3.0 s ease-in-out |
| `actor_became_alerted` | any | sting plays on next downbeat | additive, ~4 s |
| `document_opened` | — | `DOCUMENT_OVERLAY` | 0.5 s linear |
| `document_closed` | — | restore prior state | 0.5 s linear |
| `mission_completed` | — | `MISSION_COMPLETE` | instant cut + sting |
| `respawn_triggered` | — | `*_calm` for current section | 0.5 s linear |
| `dialogue_line_started` | — | VO duck (not a state change — see Rule 7) | 0.3 s |
| `dialogue_line_finished` | — | VO duck restore | 0.5 s |

**Dominant-guard rule:** `alert_state_changed` carries `actor: Node`. `AudioManager` maintains a `Dictionary[Node, StealthAI.AlertState]`. Music state is driven by the **highest** alert level across all tracked actors. If any actor is `StealthAI.AlertState.COMBAT`, state is `*_combat`; if none are COMBAT but any are SEARCHING, state is `*_searching`; else the highest of the remaining; else `calm`. Actors are removed from the dictionary on `actor_lost_target` or `enemy_killed`. **Respawn reset (2026-04-20 re-review, R7)**: on `respawn_triggered`, the dominant-guard dict is cleared — respawn re-enters a calm section and prior combat state does not bleed into the replay.

**Alert sting quantization:** the `MusicSting` brass stab on `actor_became_alerted` is quantized to the next 120 BPM downbeat (0.5 s resolution). Rationale: the sting must feel musically integrated, not arbitrary. A timer on the `MusicNonDiegetic` player tracks beat position; the sting schedules itself on the next beat.

### Interactions with Other Systems

#### AI / Stealth domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `alert_state_changed(actor, old, new)` | Update dominant-guard dict → drive music state machine | Always |
| `actor_became_alerted(actor, cause, pos)` | Quantize `MusicSting` to next 120 BPM downbeat | Always |
| `actor_lost_target(actor)` | Remove actor from dict; recalc dominant | Always |
| `takedown_performed(actor, target)` | Play takedown impact SFX at target position (pooled 3D) | Always |

#### Combat domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `weapon_fired(weapon, pos, dir)` | Play weapon fire SFX at pos (pooled 3D). Silenced pistol = period-accurate ~110 dB suppressed pop + mechanical ratchet | Always |
| `player_damaged(amount, source, is_critical)` | Play player hit SFX (non-spatial). Does NOT trigger clock-tick (see `player_health_changed` below — threshold-crossing, not damage events, drives the tick). | `amount > 5.0` (below threshold suppressed — no chip-damage spam) |
| `player_health_changed(current, max_health)` | Evaluate 25%-threshold per Formula 4; start or stop clock-tick loop with debounce | Always (per-change) |
| `enemy_damaged` | Play guard hit SFX at enemy position (pooled 3D) | Always |
| `enemy_killed(enemy, killer)` | Play guard death SFX at enemy position (pooled 3D) | Always |
| `player_died(cause)` | Play mission failure sting (non-spatial, Music bus) | Always |

#### Player domain *(ADR-0002 amendment 2026-04-19; Audio GDD revision 2026-04-20)*

| Signal | Audio behavior | Condition |
|---|---|---|
| `player_footstep(surface, noise_radius_m)` | Play footstep SFX: select variant (soft / normal / loud / **extreme**) per `noise_radius_m` thresholds (see `§Footstep Surface Map` below — 4-bucket scheme adopted 2026-04-21) and surface-specific SFX from the map. Pooled 3D at player position. | Always |
| `player_interacted(target)` | If `target != null`: play soft interact-confirm chime (~150 ms, non-spatial, UI bus). Target-specific pickup SFX is the responsibility of the downstream Document Collection / Inventory GDDs. | `is_instance_valid(target)` per ADR-0002 IG4 |

*Stealth AI MUST NOT subscribe to `player_footstep` — Stealth AI reads audibility through PC's `get_noise_level()` / `get_noise_event()` pull methods per PC GDD F.4. `player_footstep` is an Audio-only channel for SFX variant selection.*

#### Documents domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `document_collected(document_id)` | Play pickup SFX (envelope slide + paper crisp + metallic click, ~300 ms). Pooled 3D at player position. | Always |
| `document_opened(document_id)` | Transition music state to `DOCUMENT_OVERLAY`; play overlay-open SFX (paper rustle + pen-cap tock). Non-spatial, UI bus. | Always |
| `document_closed(document_id)` | Restore prior music state (per trigger table); play overlay-close SFX (paper slide). Non-spatial, UI bus. | Always |

#### Persistence domain *(added 2026-04-20 re-review, resolves cross-review B6)*

| Signal | Audio behavior | Condition |
|---|---|---|
| `game_saved(slot, section_id)` | Play brief save-confirm chime (single soft tock, ~200 ms, non-spatial, SFX bus). | Always |
| `save_failed(reason)` | Play save-error sting (descending minor two-note, ~400 ms, non-spatial, SFX bus). | Always |
| `game_loaded(slot)` | No SFX — Save-Load flow proceeds straight to `section_entered` which handles music swap. Subscribed for symmetry and future hooks. | No-op at MVP |

#### Mission domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `section_entered(section_id)` | Swap music layer assets (preloaded); swap reverb bus preset; transition to `[section]_calm` | Always |
| `objective_started` | Brief ascending chime (non-spatial, UI bus) | Always |
| `objective_completed` | Brass fanfare stinger (non-spatial, Music bus) | Fires once per objective |
| `mission_started(mission_id)` | Period radio static + 3-blink morse BQA signature | Always |
| `mission_completed(mission_id)` | Instant music cut → `MusicSting` victory sting → ambient return | Always |

#### Civilian domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `civilian_panicked(civilian, pos)` | Period-appropriate French vocal gasp ("Mon Dieu!") at civilian pos (pooled 3D, Voice bus). Add +2 dB to `MusicNonDiegetic` bedlam-layer (max stack 3) | Always |
| `civilian_witnessed_event` | Crowd murmur uptick on Ambient bus (non-spatial layer intensification) | Always |

#### Dialogue domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `dialogue_line_started(speaker, line)` | Load and play `vo_[speaker]_[line].ogg` on Voice bus; apply VO duck (Rule 7) | Always |
| `dialogue_line_finished` | Stop VO player; restore duck | Always |

**VO timing contract (clarified 2026-04-20 re-review, B8):** Dialogue & Subtitles GDD (VS-tier, unwritten) is the **sole publisher** of both `dialogue_line_started` and `dialogue_line_finished`. Emission is driven by VO-metadata duration fields (authored alongside each VO line), NOT by `AudioStreamPlayer.finished` callbacks. Audio is subscriber-only for both signals: on `dialogue_line_started` it loads and plays `vo_[speaker]_[line].ogg`; on `dialogue_line_finished` it stops and restores duck. Subtitle display timing is owned by Dialogue & Subtitles using the same signals. No direct calls between Audio and Dialogue & Subtitles. This preserves Audio's subscriber-only architectural promise (Overview).

#### Settings & Accessibility

`setting_changed("audio", "[bus]_volume", value_db)` — `AudioManager` handles by calling `AudioServer.set_bus_volume_db()`. Settings owns persistence in `user://settings.cfg`; Audio only reads on `setting_changed` and on a one-time direct read at `AudioManager._ready()` startup.

#### Ambient (location-based)

Each section has a **base ambient loop** (Ambient bus, non-spatial) that plays while the section is active:

| Section | Base loop | Detail layer | Notable 3D spatial ambients |
|---|---|---|---|
| Plaza | Paris night (traffic hum, wind, sodium-lamp buzz) | Distant traffic, occasional siren | **Guard-post radio chatter** (3D positional at guard post with wide `max_distance = 40m`; audible throughout Plaza but louder when closer — lets player infer guard-post direction) |
| Lower Scaffolds | Tower wind resonance, metal creak | Rigging ping | Swinging lamp clank (3D, tied to signature lamp prop) |
| Restaurant | French dining murmur, glassware clink | Chair scrape | Chandelier crystal resonance (3D at central chandelier) |
| Upper Structure | Wind across ironwork, distant city | City glow, 1–2 km sirens | Navigation beacon pulse (3D positional) |
| Bomb Chamber | Fluorescent ballast hum, mechanical clock tick (bomb) | Relay switch click | Red indicator lamp click (3D at device) |

#### Critical health clock-tick (Art Bible 4.4)

When player health drops below 25%, a **looping clock-tick bed** plays at 80–120 bpm on the `UI` bus until health is restored above 25%. **Settings & Accessibility exposes a toggle** (`setting_changed("accessibility", "clock_tick_enabled", bool)`) for players who find it anxiety-inducing. Default: enabled. The loop mirrors the Bomb Chamber's mechanical ticking motif — thematic consistency.

## Formulas

Audio has a small number of quantitative rules. All dB values are Godot's `volume_db` convention: `0.0` = unity; negative values = attenuation; `-80.0` = effectively silent.

### Formula 1 — VO ducking target

`music_ducked_db = setting_music_volume_db - 8.0`
`ambient_ducked_db = setting_ambient_volume_db - 6.0`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `setting_music_volume_db` | M | float | −40.0 to 0.0 | Music bus volume as set by Settings |
| `setting_ambient_volume_db` | A | float | −40.0 to 0.0 | Ambient bus volume as set by Settings |
| `music_ducked_db` | — | float | −48.0 to −8.0 | Music bus volume during VO playback |
| `ambient_ducked_db` | — | float | −46.0 to −6.0 | Ambient bus volume during VO playback |

**Output range:** Under normal settings (music at 0 dB, ambient at 0 dB), duck targets are −8 dB and −6 dB respectively. Under Music muted (−40 dB), duck target is −48 dB (already inaudible — duck is a no-op). Ducks never push the bus below −80 dB.

**Example:** Player has Music slider at −6 dB (comfortable) and Ambient at 0 dB. VO starts. Music ducks to `-6 + (-8) = -14 dB`; Ambient ducks to `0 + (-6) = -6 dB`. On VO end, both restore to the stored setting values (−6 and 0).

### Formula 2 — Civilian bedlam-layer stacking

`bedlam_boost_db = min(panic_count * 2.0, 6.0)`
`music_non_diegetic_effective_db = base_state_db + bedlam_boost_db`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `panic_count` | p | int | 0 to many | Number of civilians currently in panic state |
| `bedlam_boost_db` | — | float | 0.0 to 6.0 | Additive boost to MusicNonDiegetic volume |
| `base_state_db` | — | float | −18.0 to 0.0 | Current MusicNonDiegetic level from the state machine |

**Output range:** 0 panicked civilians = +0 dB boost; 1 civilian = +2 dB; 2 civilians = +4 dB; 3+ civilians = +6 dB (hard cap, prevents mix overload). Civilians returning to calm state decrement `panic_count`.

**Example:** In the Restaurant during `*_suspicious` state (MusicNonDiegetic at −3 dB base), 2 civilians panic. Music boosts to `-3 + 4 = +1 dB` (above unity, but within bus headroom). Transition duration: 0.5 s ease-in.

### Formula 3 — 3D spatial attenuation (engine-provided)

`AudioStreamPlayer3D` uses Godot's `AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE` model, which this GDD inherits without redefining. The parameters we set:

| Parameter | Value | Effect |
|---|---|---|
| `max_distance` | 50.0 m (default) | Sound fully inaudible beyond this distance |
| `unit_size` | 10.0 m (default) | Distance at which sound is at reference volume |
| `attenuation_model` | `ATTENUATION_INVERSE_DISTANCE` | Standard 1/r falloff |

**Exception — Plaza guard-post radio chatter:** `max_distance = 40.0 m`, `unit_size = 6.0 m`. Wider range ensures the chatter is always faintly audible throughout the Plaza section while letting distance-based attenuation signal direction to the player. This is the locked hybrid decision from Section C Interactions.

### Formula 4 — Clock-tick start/stop trigger (critical health)

**Settled 2026-04-20 re-review, B6**: tempo is **fixed at 90 bpm** — the prior tempo-scaling proposal has been removed. The Open Question is closed in favor of simplicity (no per-frame tempo tracking, no PC-GDD coupling on `current_health`).

```
# Start condition — triggered on receipt of player_health_changed(current, max_health):
health_pct = float(current) / float(max_health)  # PC stores health as int; cast to float for the percent
if health_pct < clock_tick_threshold_pct / 100.0 and not tick_playing and tick_last_stopped_age_s >= clock_tick_debounce_s:
    start_clock_tick_loop(clock_tick_bpm)  # fixed 90 bpm from Tuning Knobs

# Stop condition — same signal:
if health_pct >= clock_tick_threshold_pct / 100.0 and tick_playing:
    stop_clock_tick_loop()
    tick_last_stopped_age_s = 0.0  # reset debounce timer
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current` | — | int | 0 to max_health | Eve's current health (PC GDD enforces int) |
| `max_health` | — | int | 100 (default), safe 50–200 | Eve's maximum health |
| `health_pct` | — | float | 0.0 to 1.0 | Computed ratio |
| `clock_tick_threshold_pct` | — | int | 25 (default), safe 10–40 | % below which loop triggers |
| `clock_tick_debounce_s` | — | float | 1.0 default | Minimum off-time before restart |

**Output**: the loop starts once when `health_pct` drops below the threshold (and debounce permits) and stops once when it rises back above. Tempo is fixed at 90 bpm from the `clock_tick_bpm` Tuning Knob; loop is pre-authored at that tempo.

**Rationale for fixed tempo**: health-scaled tempo would couple Audio to the PC GDD's `health: int` field at per-frame read rates, add floating-point tempo tracking, and demand a variable-tempo audio asset. Fixed 90 bpm delivers the same "critical health = urgency" signal at a fraction of the implementation cost. Playtest may revisit in Tier 0.

## Edge Cases

- **If 17 or more SFX requests fire in the same frame** → the 16-slot SFX pool is exhausted. **Resolution**: the oldest-started slot that is not voice or UI is stolen; the new SFX plays. Rationale: cutting the oldest non-critical sound is preferable to dropping the new one. Voice and UI are exempt because dropping them would break dialogue timing and menu feedback.
- **If two alert-state transitions fire in the same frame** (e.g., one guard goes SEARCHING → COMBAT while another goes UNAWARE → SUSPICIOUS) → dominant-guard rule applies: music state is driven by the highest alert level across all actors. COMBAT wins over SUSPICIOUS. The second transition is registered in the dict but does not change music state. **Resolution**: intended.
- **If `actor_became_alerted` fires but no music is currently playing** (mission start, edge case) → the `MusicSting` plays immediately (not quantized) and `MusicNonDiegetic` fades in from −80 dB to the target state over 0.8 s. **Resolution**: fallback behavior when beat-tracking has no reference.
- **If a document is opened during active combat** → `DOCUMENT_OVERLAY` state overrides the `*_combat` state. Music ducks to the overlay levels. On `document_closed`, music returns to `*_combat` (assuming combat is still active). **Resolution**: intended. The overlay suppression respects player's pause; but this exposes a design tension — should reading a document while guards are actively shooting be possible? That's a question for Mission & Level Scripting + Document Overlay UI GDDs; Audio just executes the music rule.
- **If `player_damaged` fires with `amount ≤ 5.0`** → no hit SFX plays (chip-damage suppression). **Resolution**: intended. Prevents rapid-fire small-damage events (bumping into a wall, environmental scrapes if any) from spamming hit feedback.
- **If the player's health crosses the 25% threshold rapidly (e.g., heals from 20% to 50%, then drops back to 20%)** → clock-tick loop starts, stops, and starts again. **Resolution**: debounce with a 1-second minimum — once the loop stops, it must stay stopped for ≥1 s before restarting. Prevents audio glitch-flicker near the threshold.
- **If VO plays during `MISSION_COMPLETE`** → the mission sting has already cut music to silence; the VO duck is a no-op. VO plays on the Voice bus as normal. **Resolution**: intended. Mission-end VO is expected to play over silence.
- **If the player mutes the Master bus via OS-level volume (not in-game settings)** → all buses receive zero audio; game behavior unaffected; music state transitions still occur internally. **Resolution**: intended. Audio does not introspect OS volume. Settings toggles operate on bus_volume_db, which is compositional with OS volume.
- **If a pooled `AudioStreamPlayer3D` is stolen mid-playback to play a new SFX** → the old sound cuts abruptly. **Resolution**: intended. A 50 ms fade-out ramp applied before steal would be ideal but adds implementation complexity. MVP uses hard cut; fade-out on steal is a Vertical Slice polish item.
- **If an `actor_lost_target` signal fires for an actor not in the dominant-guard dict** (e.g., a guard that was never added because AI was disabled via debug) → the removal is a no-op; `Dictionary.erase()` returns false silently. **Resolution**: intended. No error; no state change.
- **If `setting_changed` fires with a non-audio category** → `AudioManager` checks `category == "audio"` and returns early if not. **Resolution**: intended. Audio only listens for its own category of settings.
- **If the game is paused (InputContext != GAMEPLAY) and music state transitions occur** (e.g., scripted mission progression during a cutscene) → music transitions fire as normal. `InputContext` gates player INPUT, not AudioManager event subscriptions. **Resolution**: intended. Music continues to respond to events during menus, which is correct for mission-state music transitions during cutscenes.

## Dependencies

### Upstream dependencies

| System | Nature |
|---|---|
| **Signal Bus** (system 1) | Audio subscribes to **27 events across 8 domains + Settings** (revised 2026-04-20 re-review — added Player domain 2 signals, Persistence domain 3 signals, `player_health_changed`, `document_collected`). Hard dependency — no Audio without the bus. |
| Godot 4.6 `AudioServer` + `AudioStreamPlayer`/`AudioStreamPlayer3D` | Engine dependency. Stable since 4.0. |
| ADR-0002 (Signal Bus + Event Taxonomy) | Contract defining the events Audio consumes and the subscriber lifecycle pattern. |

### Downstream dependents

| System | Direction | Nature |
|---|---|---|
| **Dialogue & Subtitles** (system 18) | Dialogue → Audio | Dialogue publishes `dialogue_line_started` / `_finished`; Audio plays VO on Voice bus. Dialogue does NOT call Audio directly — both subscribe independently to the same signals. |
| **Cutscenes & Mission Cards** (system 22) | Cutscenes → Audio | Cutscene SFX and music track swaps triggered by `mission_started` / `section_entered` / custom cutscene signals (to be added to ADR-0002 during Cutscenes GDD authoring). |
| **Settings & Accessibility** (system 23) | Settings → Audio | Settings persists volume values to `user://settings.cfg` and emits `setting_changed("audio", ...)` events. Audio applies via `AudioServer.set_bus_volume_db`. |

### No interaction

- **ADR-0001 (Stencil)**: independent.
- **ADR-0003 (Save Format)**: Audio state is not serialized. Settings file (which contains volume values) is separate from SaveGame per ADR-0003.
- **ADR-0004 (UI Framework)**: Audio does not participate in UI focus or input handling. UI SFX (menu clicks) route through the UI bus but are triggered by UI system event subscriptions, not direct Audio API calls.

## Tuning Knobs

### Per-bus volumes (player-adjustable via Settings)

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| Master volume | 0.0 dB | −80.0 to 0.0 | Composed with OS volume; absolute cap |
| Music bus | 0.0 dB | −80.0 to 0.0 | All music layers |
| SFX bus | 0.0 dB | −80.0 to 0.0 | All spatial + non-spatial SFX |
| Ambient bus | 0.0 dB | −80.0 to 0.0 | Per-location ambient loops + detail layers |
| Voice bus | 0.0 dB | −80.0 to 0.0 | VO playback; never ducked |
| UI bus | 0.0 dB | −80.0 to 0.0 | Menu clicks, document overlay SFX, clock-tick |

### Transition durations (designer-adjustable)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `music_crossfade_default_s` | 2.0 | 0.5 to 5.0 | Non-alert transitions (section enter, doc overlay restore) |
| `alert_unaware_to_suspicious_s` | 1.5 | 0.5 to 3.0 | Slower = more grace period for player to hear shift |
| `alert_suspicious_to_searching_s` | 0.8 | 0.2 to 2.0 | Faster = more urgent feel |
| `alert_to_combat_s` | 0.3 | 0.1 to 1.0 | Effectively a cut; should feel abrupt |
| `alert_deescalate_s` | 3.0 | 1.5 to 6.0 | Slow relief; stealth exhale |
| `vo_duck_attack_s` | 0.3 | 0.1 to 0.8 | Time to reach ducked volume |
| `vo_duck_release_s` | 0.5 | 0.2 to 1.5 | Time to restore after VO end |

### Duck amounts

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `music_duck_db` | −8.0 | −3.0 to −15.0 | Higher magnitude = music more suppressed during VO |
| `ambient_duck_db` | −6.0 | −2.0 to −12.0 | Ambient duck is gentler than music duck |
| `document_overlay_music_db` | −10.0 | −5.0 to −15.0 | Music level during document reading |
| `document_overlay_ambient_db` | −20.0 | −10.0 to −30.0 | Ambient level during document reading (more suppressed — the world recedes) |

### Spatial audio parameters

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `sfx_pool_size` | 16 | 8 to 32 | Global `AudioStreamPlayer3D` pool count |
| `spatial_max_distance_m` | 50.0 | 20.0 to 100.0 | Default max audible distance for pooled 3D SFX |
| `spatial_unit_size_m` | 10.0 | 5.0 to 20.0 | Distance at which sound is at reference volume |
| `plaza_radio_max_distance_m` | 40.0 | 30.0 to 60.0 | **Exception** — wider range for guard-post radio chatter |
| `plaza_radio_unit_size_m` | 6.0 | 4.0 to 10.0 | Matches the "bed with direction" hybrid decision |

### Civilian bedlam

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `bedlam_boost_per_civilian_db` | +2.0 | +1.0 to +4.0 | Music non-diegetic boost per panicked civilian |
| `bedlam_boost_max_db` | +6.0 | +3.0 to +10.0 | Hard cap |

### Critical health clock-tick

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `clock_tick_enabled` | `true` | Boolean | **Accessibility toggle only** — for players who find the tick anxiety-inducing. Disabling this does NOT change difficulty; damage intake / perception thresholds / save behavior are unaffected. Player Character's `noise_global_multiplier` is also a designer-tuning scalar, not a difficulty knob (cross-review GD-B1, 2026-04-20). The game ships with no Difficulty Selection. |
| `clock_tick_bpm` | 90 | 60 to 150 | Fixed rate at MVP (tempo-scaling is Open Question) |
| `clock_tick_threshold_pct` | 25 | 10 to 40 | Health % below which loop starts |
| `clock_tick_debounce_s` | 1.0 | 0.5 to 2.0 | Minimum gap before loop can restart after stopping |

### NOT owned by this GDD

- Music composition (tempo, key, instrumentation) → owned by composer / audio-director contract, documented in `design/art/art-bible.md` references + future asset spec
- VO line content and performance → owned by Dialogue & Subtitles GDD + writer
- Specific SFX sample files → owned by sound-designer contract, documented in future asset spec

## Visual/Audio Requirements

**Visual feedback from Audio events**: None owned here. Subscribers may produce visual reactions to the same signals Audio consumes (HUD displays muzzle flash from `weapon_fired`; Post-Process Stack sepia-dim on `document_opened`), but those reactions live in their respective GDDs.

**Audio asset production spec** — this section is the seed for the future `/asset-spec system:audio` run after the art bible is approved. For now, the SFX event catalog is specified per signal below.

### SFX event catalog (by subscribed event)

| Signal | SFX description (period-authentic, NOLF1-faithful) | Spatial | Bus | Pool hint |
|---|---|---|---|---|
| `actor_became_alerted` | Guard alert stinger — brass punch (Goldsmith-style 2-note accent, trumpet + French horn, ~500 ms) | 3D @ source | SFX | 4 |
| `actor_lost_target` | Soft woodwind decay (clarinet tail, dry, ~800 ms) | 3D @ source | SFX | 3 |
| `takedown_performed` | Muffled thud + fabric rustle (silenced cloth-bag impact, ~200 ms, 60–150 Hz) | 3D @ target | SFX | 2 |
| `weapon_fired` (silenced pistol) | **Period-accurate** ~110 dB suppressed pop + mechanical ratchet tick | 3D @ muzzle | SFX | 6 |
| `weapon_fired` (dart gun) | Compressed air puff + dart whistle (~400 ms) | 3D @ muzzle | SFX | 6 |
| `weapon_fired` (optional rifle) | Louder single-shot report + bolt action | 3D @ muzzle | SFX | 6 |
| `weapon_fired` (fists) | Cloth impact + knuckle thud | 3D @ target | SFX | 4 |
| `player_damaged` | Body impact (ballistic gelatin thud, ~150 ms, 200–400 Hz) | Non-spatial | SFX | 1 |
| `enemy_damaged` | Guard gasp + impact thud (~120 ms) | 3D @ guard | SFX | 4 |
| `enemy_killed` | Body+armor collapse + helmet ring (~800 ms decay) | 3D @ corpse | SFX | 2 |
| `player_died` | Mission failure sting — minor-key trumpet swell (2–3 s) | Non-spatial | Music | 1 |
| `document_collected` | Envelope slide into pocket — paper crisp + metallic click (~300 ms) | 3D @ pickup | SFX | 3 |
| `document_opened` | Paper rustle + pen-cap tock (Art Bible 7D) (~400 ms + 150 ms) | Non-spatial | UI | 1 |
| `document_closed` | Paper slide dismissal (~250 ms) | Non-spatial | UI | 1 |
| `objective_started` | 2-note ascending chime (period bell, major 3rd, ~600 ms) | Non-spatial | UI | 1 |
| `objective_completed` | 3-note brass fanfare (restrained Goldsmith major key, ~1.2 s) | Non-spatial | Music | 1 |
| `mission_started` | Period radio static + 3-blink morse BQA signature (~800 ms) | Non-spatial | SFX | 1 |
| `mission_completed` | Victory sting (composer spec) | Non-spatial | Music | 1 |
| `civilian_panicked` | French vocal gasp ("Mon Dieu!", "Quoi?!") (~500 ms) | 3D @ civilian | Voice | 4 |
| `civilian_witnessed_event` | Crowd murmur uptick (ambient layer intensification) | Non-spatial | Ambient | 1 |
| `player_footstep` (soft) | Surface-variant footstep (see `§Footstep Surface Map`); ~150–250 ms per step; 7 surfaces × 4 variants × 2–4 samples + pitch rand | 3D @ player | SFX | 4 |
| `player_footstep` (normal) | Surface-variant footstep; louder + longer transient | 3D @ player | SFX | 4 |
| `player_footstep` (loud) | Surface-variant footstep; bright + long tail (hard-land at threshold) | 3D @ player | SFX | 4 |
| `player_footstep` (extreme) | Surface-variant footstep; brightest + longest tail (Sprint locomotion 12 m, panic drops to 16 m cap) | 3D @ player | SFX | 4 |
| `player_interacted` | Soft interact-confirm chime (~150 ms, single bell tock); downstream GDDs own target-specific pickup SFX | Non-spatial | UI | 1 |
| `game_saved` | Save-confirm chime (single soft tock, ~200 ms) — settled 2026-04-20 | Non-spatial | SFX | 1 |
| `save_failed` | Save-error sting (descending minor two-note, ~400 ms) | Non-spatial | SFX | 1 |
| Critical health loop | Clock-tick metronome (**fixed 90 bpm**, Bomb Chamber motif) — tempo lock settled 2026-04-20 re-review B6 | Non-spatial | UI | 1 |

### Ambient loops (per location)

| Location | Base ambient loop (Ambient bus) | 3D spatial ambient elements |
|---|---|---|
| **Plaza** | Paris night (traffic hum, wind, sodium lamp buzz ~60 Hz, distant siren) | Guard-post radio chatter (3D @ guard post, max_dist=40m); street lamp-specific buzz (3D near each lamp) |
| **Lower Scaffolds** | Tower wind resonance (40–80 Hz rumble), metal creak | Swinging lamp clank (3D @ signature lamp); rigging ping (stochastic, multiple positions) |
| **Restaurant** | French dining murmur (3–4 overlapping conversations, non-semantic), distant glassware clink | Central chandelier crystal resonance (3D @ chandelier); per-table chatter (3D, reduced volume) |
| **Upper Structure** | Wind across ironwork (1–3 kHz shear), faint Paris city glow | Navigation beacon pulse (3D @ beacon, ~60 bpm low-frequency click) |
| **Bomb Chamber** | Fluorescent ballast hum (failing 60 Hz, irregular flicker-crackle every 3–8 s), mechanical clock tick (bomb device, ~100 bpm) | Device indicator lamp relay click (3D @ device) |

### Footstep Surface Map (added 2026-04-20; 4-bucket scheme adopted 2026-04-21 per PC /design-review)

PC GDD and FC GDD cite this section as the canonical owner of the surface→SFX mapping. This table is the seed for asset production (28 asset sets = 7 surfaces × 4 loudness variants).

**Loudness-to-variant thresholds** (4-bucket scheme — adopted 2026-04-21 per audio-director B1+B2 / PC design-review; aligns with FC GDD Visual/Audio section exactly):

| Variant | `noise_radius_m` range | PC states that route here |
|---|---|---|
| `soft` | ≤ 3.5 m | Crouch locomotion (3.0 m); Crouch-idle (0.0 m also routes here — silent, no SFX plays) |
| `normal` | > 3.5 and ≤ 6.5 m | Walk locomotion (5.0 m); Jump takeoff spike (4.0 m); Landing-soft spike (5.0 m) |
| `loud` | > 6.5 and ≤ 10 m | Hard landing at threshold (8.0 m base); lower-range hard-landing scale outputs |
| `extreme` | > 10 m | **Sprint locomotion (12.0 m default)**; Hard landing scaled above ~1.25× threshold (up to 16 m cap per F.3) |

**Why 4 buckets, not 3** (2026-04-21): PC's Session F raised Sprint to 12 m and the scaled hard-landing formula (F.3) caps at 16 m. Under the previous 3-bucket scheme both a brisk Sprint and a panic-drop collapsed into a single `loud` stem with no audible differentiation across 9.5 m of radius range. The `extreme` bucket gives Sprint locomotion and panic-drops their own stem set — preserving dynamic-range legibility for both player feedback and Stealth AI contextual cues.

**Note — `noise_global_multiplier` is ship-locked to 1.0** (per PC GDD game-designer B-2 closure, 2026-04-21). All thresholds above assume multiplier = 1.0; no runtime scaling applies.

**Surface SFX map** (each cell names the authored SFX asset set; ×4 variants per cell):

| Surface | soft variant | normal variant | loud variant | extreme variant | Notes |
|---|---|---|---|---|---|
| `marble` | `sfx_footstep_marble_soft_*` | `sfx_footstep_marble_normal_*` | `sfx_footstep_marble_loud_*` | `sfx_footstep_marble_extreme_*` | Plaza ground surface. Bright, glassy, mid-high transient. Hero surface — most-heard. Sprint-on-marble is the canonical `extreme` reference sound. |
| `tile` | `sfx_footstep_tile_soft_*` | `sfx_footstep_tile_normal_*` | `sfx_footstep_tile_loud_*` | `sfx_footstep_tile_extreme_*` | Restaurant kitchen. Hard ceramic, slightly damped. |
| `wood_stage` | `sfx_footstep_wood_soft_*` | `sfx_footstep_wood_normal_*` | `sfx_footstep_wood_loud_*` | `sfx_footstep_wood_extreme_*` | Cabaret (future level). Resonant hollow wood — Pillar 5 signature. |
| `carpet` | `sfx_footstep_carpet_soft_*` | `sfx_footstep_carpet_normal_*` | `sfx_footstep_carpet_loud_*` | `sfx_footstep_carpet_extreme_*` | Office suite, cinema corridors. Damped, low-transient. |
| `metal_grate` | `sfx_footstep_grate_soft_*` | `sfx_footstep_grate_normal_*` | `sfx_footstep_grate_loud_*` | `sfx_footstep_grate_extreme_*` | Observation Deck service ladders. Metallic rattle + tuning harmonics. Sprint-on-grate `extreme` is a signature loudness cue. |
| `gravel` | `sfx_footstep_gravel_soft_*` | `sfx_footstep_gravel_normal_*` | `sfx_footstep_gravel_loud_*` | `sfx_footstep_gravel_extreme_*` | Plaza outdoor path, Tier 2 Rome. Stochastic crunch — high sample-fatigue risk, 4+ variants. |
| `water_puddle` | `sfx_footstep_puddle_soft_*` | `sfx_footstep_puddle_normal_*` | `sfx_footstep_puddle_loud_*` | `sfx_footstep_puddle_extreme_*` | Rare, mission-script spawned. Distinct splash transient. |

**Variant count per cell**: 2–4 samples per variant (per Audio authoring conventions below), with ±5–10% pitch randomization applied at playback. Total audio asset count = 7 surfaces × 4 variants × ~3 samples = ~84 footstep audio files (up from ~63 under the prior 3-bucket scheme).

**Playback behavior**: On `player_footstep(surface, noise_radius_m)`:
1. Select variant per the threshold table above.
2. Look up `sfx_footstep_<surface>_<variant>` asset set; pick one sample uniformly at random with pitch randomization.
3. Play via pooled `AudioStreamPlayer3D` at player position, `SFX` bus, `max_distance=50m`, `unit_size=10m` (per Formula 3).
4. If all 16 pool slots are busy, apply the steal-oldest rule (Edge Cases / Rule 5) — footsteps are pool-eligible.

**Cross-ref enforcement**: `player_footstep` signal is Audio-only per ADR-0002 Implementation Guideline (Player domain delineation + PC GDD Session D B-12). Stealth AI MUST NOT subscribe to this signal. AI perception of footstep audibility is through PC's `get_noise_level()` / `get_noise_event()` pull methods exclusively.

### Audio authoring conventions

- **All audio files** use Ogg Vorbis (`.ogg`) for music, ambient loops, and long samples; WAV (`.wav`) for short one-shot SFX (per `technical-preferences.md`).
- **Sample rate**: 48 kHz for all assets.
- **Bit depth**: 16-bit for music and ambient; 16-bit for SFX.
- **Loudness normalization**: all source assets normalized to −14 LUFS integrated loudness target (streaming-era standard; provides headroom for mixing).
- **Period authenticity rules**: NO modern synth, NO reverb-heavy ambient pads, NO orchestral Hollywood swells, NO modern suppressor whispers. References in Section B (Player Fantasy) are authoritative.
- **Variation**: every repeating SFX ships with 2–4 sample variants + ±5–10% pitch randomization to prevent sample fatigue.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:audio` to produce per-asset descriptions, durations, and production specifications from this section.

## UI Requirements

**None directly owned by Audio.** Settings & Accessibility (system 23) owns the audio-options UI — per-bus volume sliders (Master, Music, SFX, Ambient, Voice, UI) and the clock-tick toggle. Audio provides the `AudioServer.get_bus_volume_db()` query for the UI to display current values and the `setting_changed("audio", ...)` signal handler to apply them. The rebinding UI for these values is part of Settings' scope, not Audio's.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Signal Bus subscriptions | `design/gdd/signal-bus.md` + `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | 27 signals across 8 event domains (AI/Stealth, Combat, Player, Mission, Civilian, Dialogue, Documents, Persistence) + Settings | Data dependency (Audio subscribes) |
| Subscriber lifecycle | `design/gdd/signal-bus.md` Rule 4 + ADR-0002 Implementation Guideline 3 | `_ready()` connect / `_exit_tree()` disconnect pattern with `is_connected` guard | Rule dependency |
| Alert state rule (music signals state, not visuals) | `feedback_visual_state_signaling` memory + `design/gdd/game-concept.md` Visual Identity Anchor | Alert state changes via music/audio, NOT lighting or color shifts | Rule dependency |
| Audio mood per location | `design/art/art-bible.md` Section 2 | Mood targets per Plaza/Scaffolds/Restaurant/Upper Structure/Bomb Chamber | Data dependency (Audio sections realize the mood targets) |
| HUD critical-health clock-tick | `design/art/art-bible.md` Section 4.4 | Alarm Orange numeral + clock-tick SFX pairing | Data dependency |
| VO line timing | `design/gdd/game-concept.md` MVP scope | 30–50 VO lines at MVP | Scope reference |
| Settings persistence | `docs/architecture/adr-0003-save-format-contract.md` | Settings in `user://settings.cfg`, not SaveGame | Rule dependency |
| Period audio references (Mancini, Goldsmith, *Our Man Flint*) | `design/gdd/game-concept.md` inspirations | Score style anchor | Tone reference |

## Acceptance Criteria

### Bus + subscriber infrastructure

1. **GIVEN** the project is launched, **WHEN** the `AudioServer` bus list is inspected, **THEN** five buses exist: `Music`, `SFX`, `Ambient`, `Voice`, `UI`. Each has its own effects chain (reverb on SFX is section-swappable).
2. **GIVEN** `AudioManager.gd`, **WHEN** `_ready()` completes, **THEN** it has connected to all 27 signals from ADR-0002 listed in Section C.1 Rule 3 (8 domains + Settings). **AND** on `_exit_tree()`, it disconnects every connection with `is_connected` guards.
3. **GIVEN** any project source file, **WHEN** grepped for `AudioStreamPlayer.new()` or `AudioStreamPlayer3D.new()` calls in `_process` or `_physics_process` or runtime non-startup code, **THEN** zero matches (pooling rule).
4. **GIVEN** any `AudioStreamPlayer` or `AudioStreamPlayer3D` in the scene tree, **WHEN** its `bus` property is inspected, **THEN** it is one of the five named buses — never `Master`.

### Music layer behavior

5. **GIVEN** the game is in `plaza_calm` state (MusicDiegetic 0 dB, MusicNonDiegetic −12 dB), **WHEN** a guard transitions UNAWARE → SUSPICIOUS, **THEN** over 1.5 s linear, MusicDiegetic drops to −6 dB and MusicNonDiegetic rises to −3 dB.
6. **GIVEN** the game is in `*_combat` state, **WHEN** the last combat-tier actor leaves combat (via `enemy_killed` or `actor_lost_target`), **THEN** over 3.0 s ease-in-out, music transitions back to `*_calm`.
7. **GIVEN** `actor_became_alerted` fires, **WHEN** the next 120 BPM downbeat arrives (within 0.5 s), **THEN** `MusicSting` plays the brass stab SFX additively over the evolving music layer.
8. **GIVEN** `section_entered(NEW_SECTION)` fires, **WHEN** Audio responds, **THEN** it swaps the music layer assets to the new section's preloaded streams AND swaps the `AudioEffectReverb` preset on the SFX bus.

### VO ducking

9. **GIVEN** music is playing at Music bus 0 dB, **WHEN** `dialogue_line_started` fires, **THEN** over 0.3 s, Music bus volume drops to −8 dB. **AND** on `dialogue_line_finished`, Music bus restores to 0 dB over 0.5 s.
10. **GIVEN** VO is playing, **WHEN** the Voice bus volume is queried, **THEN** it is unducked (same as Settings configured value).

### Spatial SFX

11. **GIVEN** 17 simultaneous `weapon_fired` events in the same frame, **WHEN** Audio handles them, **THEN** 16 play via the pool and the 17th steals the oldest non-Voice-non-UI slot. No error; no dropped SFX (the new request always plays).
12. **GIVEN** `weapon_fired(silenced_pistol, pos, dir)` at 20 m from the listener, **WHEN** the SFX plays, **THEN** its volume is attenuated per `AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE` with `unit_size=10.0` — verifiable by measuring output dB vs source dB.
13. **GIVEN** the player is standing in Plaza, **WHEN** they walk 40 m away from the guard post, **THEN** the guard radio chatter is at or below the `max_distance` cutoff (effectively inaudible). At 10 m away: clearly audible. At 20 m: attenuated but audible. (Direction-inferring requirement.)

### Settings integration

14. **GIVEN** the player moves the Music volume slider to −20 dB, **WHEN** Settings emits `setting_changed("audio", "music_volume", -20.0)`, **THEN** `AudioServer.get_bus_volume_db(Music)` returns −20.0.
15. **GIVEN** the game starts after a previous session where the player muted the Voice bus, **WHEN** `AudioManager._ready()` runs, **THEN** it reads `user://settings.cfg` and applies the stored volume to the Voice bus.
16. **GIVEN** the clock-tick accessibility toggle is OFF, **WHEN** player health drops below 25%, **THEN** no clock-tick loop plays.

### Edge case behavior

17. **GIVEN** `player_damaged(4.0, source, false)` fires (chip damage below threshold), **WHEN** Audio handles it, **THEN** no hit SFX plays. **GIVEN** `player_damaged(10.0, source, false)`, **THEN** the hit SFX plays.
18. **GIVEN** player health oscillates across 25% within 500 ms, **WHEN** the clock-tick debounce evaluates, **THEN** the loop does not restart within 1.0 s of stopping.
19. **GIVEN** 3 civilians panic simultaneously, **WHEN** bedlam-boost is calculated, **THEN** `MusicNonDiegetic` is boosted by +6 dB (capped, not +6 dB × 3).
20. **GIVEN** a `DOCUMENT_OVERLAY` state is entered during `*_combat`, **WHEN** `document_opened` fires, **THEN** music ducks to overlay levels (−10 dB / −20 dB). On `document_closed`, music returns to `*_combat` levels (if combat is still active).

### Player domain + Persistence (added 2026-04-20 re-review)

23. **GIVEN** `player_footstep(&"marble", 5.0)` fires, **WHEN** Audio handles it, **THEN** it selects the `normal` variant (3.5 < 5.0 ≤ 6.5 per `§Footstep Surface Map`) and plays `sfx_footstep_marble_normal_*` via a pooled `AudioStreamPlayer3D` at the player's position on the `SFX` bus.
24. **GIVEN** `player_footstep(&"metal_grate", 9.0)` fires, **WHEN** Audio handles it, **THEN** it selects the `loud` variant (6.5 < 9.0 ≤ 10 per 4-bucket scheme) and plays `sfx_footstep_grate_loud_*`.
24a. **GIVEN** `player_footstep(&"marble", 12.0)` fires (Sprint on marble), **WHEN** Audio handles it, **THEN** it selects the `extreme` variant (12.0 > 10) and plays `sfx_footstep_marble_extreme_*` — the canonical `extreme` bucket reference.
25. **GIVEN** `player_health_changed(24.0, 100.0)` fires (crosses threshold downward), **WHEN** `clock_tick_enabled == true` AND debounce permits, **THEN** the clock-tick loop starts at 90 bpm on the `UI` bus.
26. **GIVEN** `game_saved(1, &"plaza")` fires, **WHEN** Audio handles it, **THEN** the save-confirm chime plays on the `SFX` bus (non-spatial, ~200 ms).
27. **GIVEN** `player_footstep` fires, **WHEN** inspected at code-review, **THEN** Stealth AI is NOT a subscriber (enforce via `forbidden_pattern` stealth_ai_subscribes_to_player_footstep).

### Anti-pattern enforcement

21. **GIVEN** any system source file, **WHEN** code-reviewed, **THEN** no system calls `AudioManager.play_music()` or similar method on Audio's autoload/node directly — all Audio behavior is triggered via `Events` signals. *Classification: code-review checkpoint.*
22. **GIVEN** `Events.gd`, **WHEN** the signal taxonomy is inspected, **THEN** `AudioManager` does NOT re-emit any built-in Godot signals through `Events` (per ADR-0002 forbidden_pattern `reemit_engine_signals_through_bus`).
28. **GIVEN** Audio's complete subscription list, **WHEN** compared to publishers' signal lists, **THEN** Audio does NOT subscribe to any signal it also publishes (enforce subscriber-only architectural rule — Audio publishes zero cross-system signals). Specifically Audio does NOT fire `dialogue_line_finished` despite playing the VO — that signal is emitted by Dialogue & Subtitles using VO-metadata duration fields.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| ~~Clock-tick tempo: fixed or health-scaled?~~ | — | — | **Resolved 2026-04-20 re-review B6** — fixed 90 bpm. Formula 4 rewritten; tempo-scaling branch removed. |
| ~~Should `AudioManager` be a singleton/autoload or a scene-tree Node?~~ | — | — | **Resolved 2026-04-20 re-review R1** — scene-tree Node. Settled in Detailed Design Rule 3. |
| Should dialogue reading during active combat be possible? (Design tension flagged in Edge Cases) | Game designer + Mission & Level Scripting GDD author | During Document Overlay UI GDD authoring | Audio handles whatever rule is decided; this is a Mission/Document design question, not Audio's. |
| Should pooled `AudioStreamPlayer3D` slot-steal apply a 50 ms fade-out ramp to prevent hard cuts? | Gameplay-programmer | Vertical Slice polish phase | MVP uses hard cut. Add fade-out if playtest reveals audible clicks. |
| Reverb preset tuning: specific reverb parameters per section (room size, damping, wet-level) | Audio-director | Before music recording begins | Defer to audio-director's reverb-authoring pass; document final presets in `/asset-spec system:audio` output. |
| Music streaming vs preload at scale: is 8–12 MB per section preload sustainable if Tier 2 (Rome/Vatican) adds more sections? | Audio-director + performance-analyst | Before Tier 2 development begins | Revisit when Tier 2 is scoped. MVP is comfortable within PC memory; later scaling may force stream-on-demand. |
