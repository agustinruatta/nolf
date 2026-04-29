# Audio

> **Status**: In Design — pending 3rd `/design-review` after ADR-0002 amendment lands
> **Author**: User + `/design-system` skill + specialists (audio-director, sound-designer, game-designer, systems-designer, qa-lead, godot-specialist per 2026-04-21 adversarial re-review; creative-director synthesis)
> **Last Updated**: 2026-04-21 (2nd `/design-review` revision pass — 15 blockers resolved inline; 6 Stealth AI pre-impl-gate items closed; 4 load-bearing design decisions locked: Formula 2 diegetic-recedes, SCRIPTED-cause stinger suppression, 2.0 s respawn fade, state-keyed per-layer VO duck)
> **Last Verified**: 2026-04-21
> **Implements Pillar**: Pillar 3 (Stealth is Theatre — alert state via music); Pillar 1 (Comedy Without Punchlines — guard banter, absurd SFX); Pillar 5 (Period Authenticity — 1960s jazz/lounge score)

## Summary

Audio is *The Paris Affair*'s most identity-defining Foundation system — it carries the game's NOLF1 fidelity commitment by signaling AI alert state through **dynamic music transitions** (never through visuals) and delivers the 1960s jazz-lounge score, guard banter VO, spatialized gunfire, and period SFX that the game's tone lives or dies on. Audio subscribes to **30 signals across 9 gameplay event domains + Settings** on the Signal Bus (AI/Stealth, Combat, Player, Mission, Failure/Respawn, Civilian, Dialogue, Documents, Persistence); it publishes nothing. Implementation uses Godot 4.6's audio bus system with pooled `AudioStreamPlayer3D` for spatial SFX and `AudioStreamPlayer` for BGM/UI. Settings & Accessibility owns volume persistence.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Signal Bus (ADR-0002)` · Key subscriptions: AI/Stealth + Combat + Player + Mission + Failure/Respawn + Civilian + Dialogue + Documents + Persistence + Settings (30 signals, 9 gameplay domains + Settings)

## Overview

Audio is the backbone of *The Paris Affair*'s atmosphere and the carrier of its most important design rule: **alert state is signaled through music, not visuals** (per the NOLF1 fidelity commitment locked in `feedback_visual_state_signaling` memory). When Eve slips from unaware into "suspicious" AI range, the music shifts. When a guard spots her, it swells. When she slips back into cover and the alert de-escalates, the music settles. The player learns to trust their ears more than the HUD — which is exactly what stealth theatre requires.

Architecturally, Audio is a **subscriber-only** system. It listens to the Signal Bus (ADR-0002) for events in **nine gameplay domains + Settings** (revised 2026-04-21 re-review — Failure/Respawn separated from Mission per ADR-0002:183; `section_exited` added for dominant-guard-dict cleanup):

- **AI/Stealth** — `alert_state_changed` drives music; `actor_became_alerted` drives positional stingers (filtered by severity + cause per §Concurrency Policies)
- **Combat** — `weapon_fired`, `player_damaged`, `player_health_changed` drive SFX and critical-health clock-tick
- **Player** — `player_footstep` drives surface-mapped footstep SFX; `player_interacted` drives interact-confirmation SFX
- **Mission** — `section_entered`, `section_exited`, `objective_completed` drive music-location transitions + dict cleanup + sting hits
- **Failure/Respawn** — `respawn_triggered` drives the 2.0 s ease-in reset to `*_calm`
- **Civilian** — `civilian_panicked` drives distress SFX + bedlam response (diegetic recedes, non-diegetic holds)
- **Dialogue** — `dialogue_line_started` / `dialogue_line_finished` drive VO playback and state-keyed per-layer music ducking
- **Documents** — `document_collected` drives pickup SFX; `document_opened` / `document_closed` drive overlay music duck
- **Persistence** — `game_saved` / `save_failed` drive confirm/error chimes on save

Audio does NOT publish cross-system events. Audio does NOT know about individual systems — it reacts to typed signals. **VO ownership clarification (D&S v0.3 §F.6 #5 amendment 2026-04-28; supersedes 2026-04-20 B8 clarification):** Dialogue & Subtitles owns the AudioStreamPlayer that plays VO files (per D&S §C.3); Audio is **subscriber-only ducking** on `dialogue_line_started` / `_finished` (Music + Ambient via Formula 1; Voice bus via CR-DS-17 on `document_opened`). Audio does NOT load or play VO files. Both systems react to the same signals independently.

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
3. **Audio connects to Events at startup; disconnects on exit.** `AudioManager.gd` is a scene-tree `Node`, NOT an autoload (settled 2026-04-20 — subscriber lifecycle fits a Node better; autoload reserved for truly global contracts like `Events`, `SaveLoad`). `AudioManager` lives in the **persistent root scene** (a child of the main scene node, never a child of a per-section scene that gets freed on transition) so `_exit_tree()` fires only on game quit, not on section change. It connects all subscriptions in `_ready()` and disconnects with `is_connected` guards in `_exit_tree()` — the mandatory Signal Bus subscriber lifecycle from ADR-0002. Subscriptions (**30 signals across 9 gameplay domains + Settings**, revised 2026-04-21 re-review — added Failure/Respawn domain split, added `section_exited`, updated to post-ADR-0002-amendment 4-param/3-param signatures for AI/Stealth):

   > **⚠️ ADR-0002 amendment is a hard prerequisite for these handler signatures.** The 4-param / 3-param forms below reflect the post-amendment signal signatures mandated by the Stealth AI GDD (approved 2026-04-21). ADR-0002 amendment (owned by `technical-director` per Stealth AI pre-implementation gate #1) MUST land before Audio implementation begins — otherwise handler arities will not match and `AudioManager` will crash on first signal emission. Until ADR-0002 is amended, AC-2 and the AI/Stealth handler ACs are gated on that work.

   - **AI/Stealth (4)** — post-amendment signatures: `alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState, severity: StealthAI.Severity)`, `actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3, severity: StealthAI.Severity)`, `actor_lost_target(actor: Node, severity: StealthAI.Severity)`, `takedown_performed(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)`
   - **Combat (6)**: `weapon_fired`, `player_damaged`, `player_health_changed`, `enemy_damaged`, `enemy_killed`, `player_died` (`player_health_changed` added 2026-04-20 to drive the 25%-threshold clock-tick trigger)
   - **Player (2)** *(ADR-0002 amendment 2026-04-19)*: `player_footstep`, `player_interacted`
   - **Mission (6)**: `section_entered`, `section_exited`, `objective_started`, `objective_completed`, `mission_started`, `mission_completed` — `section_exited` is 2026-04-21 addition; AudioManager uses it to clear the dominant-guard dict before the new section's `section_entered` fires (see §Concurrency Policies)
   - **Failure/Respawn (1)** *(moved from Mission 2026-04-21 — ADR-0002:183 places `respawn_triggered` in this domain)*: `respawn_triggered`
   - **Civilian (2)**: `civilian_panicked`, `civilian_witnessed_event`
   - **Dialogue (2)**: `dialogue_line_started`, `dialogue_line_finished` *(subscriber-only ducking — Dialogue & Subtitles owns the AudioStreamPlayer and plays VO files itself per D&S §C.3; Audio applies VO duck per Formula 1 on receipt and restores on `dialogue_line_finished`. **Audio does NOT load or play VO files.** Per D&S v0.3 §F.6 #5 amendment 2026-04-28.)*
   - **Documents (3)**: `document_collected`, `document_opened`, `document_closed`
   - **Persistence (3)**: `game_saved`, `game_loaded`, `save_failed`
   - **Settings (1)**: `setting_changed`
4. **Music is two simultaneous layers, not one track.** The Music bus carries three persistent `AudioStreamPlayer` nodes: `MusicDiegetic` (in-world source — quartet, combo, city hum), `MusicNonDiegetic` (non-diegetic score — upright bass, brushed snare, stealth cool), and `MusicSting` (one-shot alert stabs and victory stings). The `MusicDiegetic` and `MusicNonDiegetic` volume_db values are driven independently by the state machine (below). `MusicSting` is fire-and-forget and returns to silence on `finished`.
5. **Spatial SFX uses one global pool of 16 `AudioStreamPlayer3D` nodes.** Pre-created in `_ready()`, all routed to `SFX` bus. A single global pool (not per-category) — this game's SFX density does not stress 16 slots. Anti-starvation: if all slots are occupied, the new request steals the oldest-started slot that is not gameplay-critical (voice and UI are exempt; they use non-spatial `AudioStreamPlayer`).
6. **Music crossfade rule: Tween on `volume_db`, never stop-and-start.** All music transitions use `create_tween().tween_property(player, "volume_db", target_db, duration)`. In-coming layer fades up; out-going layer fades down in parallel. **Default crossfade: 2.0 s ease-in-out** for non-alert transitions (section changes, document-overlay restores). Silence-cut only for mission-complete sting and cutscene track swap. Alert-state crossfades use the table in C.2.
7. **Voice (VO) ducking.** When `dialogue_line_started` fires, `AudioManager` ducks the two music layers independently per Formula 1's state-keyed per-layer table — `MusicDiegetic` ducks deeper during calm states (comedy priority when jazz is loud), `MusicNonDiegetic` ducks lighter during combat states (signal preservation when the score IS the alert cue). `Ambient` bus ducks a flat −6 dB. Attack 0.3 s, release 0.5 s (tuning knobs). On `dialogue_line_finished` all three restore to stored setting values over 0.5 s. The `Voice` bus is **not ducked by VO itself** (it is the source). The `UI` bus is not ducked.

   **Voice-bus duck-exception table (D&S v0.3 §F.6 #5 amendment 2026-04-28):** the Voice bus IS ducked on the following exception, separate from VO ducking:

   | Trigger | Voice bus duck | Attack | Release | Source |
   |---|---|---|---|---|
   | `document_opened` | **−12 dB** *(was −6 dB pre-v0.3 of D&S; deepened to broadcast intelligibility floor)* | 0.3 s | 0.5 s (on `document_closed`) | D&S CR-DS-17 v0.3; tuning knob `voice_overlay_duck_db = -12.0` |

   Rationale: a player reading a document while VO continues at native pace (worst case: fast localized German/French BQA briefing) cannot read and listen simultaneously at −6 dB Voice. −12 dB recedes VO substantially while preserving Pillar 3 stealth-as-theatre (audio-director's recommendation against stopping VO mid-line). Playtest-tunable; deepen toward −18 dB if VS playtest finds VO still competes for cognitive bandwidth.
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
| `actor_became_alerted` | `severity == MAJOR AND cause != SCRIPTED` (else no-op) | sting plays on next downbeat | additive, ~4 s |
| `document_opened` | — | `DOCUMENT_OVERLAY` + **Voice bus duck −12 dB** *(v0.3 — D&S CR-DS-17)* | 0.5 s linear (music) / 0.3 s attack (Voice) |
| `document_closed` | — | restore prior state + **restore Voice bus** | 0.5 s linear (music) / 0.5 s release (Voice) |
| `mission_completed` | — | `MISSION_COMPLETE` | instant cut + sting |
| `respawn_triggered` | — | cut to silence for ~200 ms, then `*_calm` for current section | **2.0 s ease-in from silence** (matches `section_entered` — 2026-04-21 revision: short linear fade read as cinema hard-cut and violated Pillar 3's theatre-not-punishment. 2.0 s from silence reads as scene reset, not game-punishes-you). Also clears the dominant-guard dict — see §Concurrency Policies. |
| `dialogue_line_started` | — | VO duck (not a state change — see Rule 7) | 0.3 s |
| `dialogue_line_finished` | — | VO duck restore | 0.5 s |

**Dominant-guard rule:** `alert_state_changed` carries `actor: Node`. `AudioManager` maintains a `Dictionary[Node, StealthAI.AlertState]`. Music state is driven by the **highest** alert level across all tracked actors. If any actor is `StealthAI.AlertState.COMBAT`, state is `*_combat`; if none are COMBAT but any are SEARCHING, state is `*_searching`; else the highest of the remaining; else `calm`. Actors are removed from the dictionary on `actor_lost_target` or `enemy_killed`. See §Concurrency Policies for dict-clearing semantics on respawn and section transitions.

**Alert sting quantization:** the `MusicSting` brass stab on `actor_became_alerted` is quantized to the next 120 BPM downbeat (0.5 s resolution). Rationale: the sting must feel musically integrated, not arbitrary. A timer on the `MusicNonDiegetic` player tracks beat position; the sting schedules itself on the next beat. **Implementation note**: the quantization math is extracted into a pure helper `get_next_beat_offset_s(current_playback_pos_s: float, bpm: float) -> float` so it can be unit-tested deterministically against fixed inputs (AC-7) without requiring a real-time scene-tree timebase.

### Concurrency Policies

Signals arrive in bursts. An open-plan area can send 3+ `actor_became_alerted(MAJOR)` in a single physics frame; a propagation wave can bump 5 guards to SUSPICIOUS in one tick; a section transition can briefly retain stale Node refs in the dominant-guard dict. These rules fence the concurrency surface so handler bursts produce clean mixes, not level-hunting artifacts or crashes.

1. **Stinger per-beat-window debounce.** At most **one** `MusicSting` brass stab may be scheduled per 120 BPM downbeat window (0.5 s). When `actor_became_alerted(_, cause, _, MAJOR)` with `cause != SCRIPTED` fires and a stinger is already queued for the upcoming downbeat, the second and subsequent arrivals within that window are silently discarded (no new schedule). The queued stinger plays on schedule; fresh stingers queue only after the current one completes or the next beat window opens. **Rationale**: three simultaneous MAJOR detections collapsing onto the same brass stab produce clip-level transient stacking and a mix disaster. Audio-director burst-contract per Stealth AI GDD pre-impl gate #2(d).

2. **Same-state idempotence on `alert_state_changed`.** When propagation bumps N guards to SUSPICIOUS in one frame, each guard fires its own `alert_state_changed(_, _, SUSPICIOUS, MINOR)`. The dominant-guard dict updates N times, but the dominant state returns the same value (`SUSPICIOUS`) on every computation. `AudioManager`'s handler computes the new dominant state AFTER updating the dict and **early-returns** if the computed dominant state equals the currently-playing music state. Result: one `*_suspicious` tween is launched per transition, never N concurrent tweens competing on the same `volume_db` target. Stealth AI GDD pre-impl gate #2(e).

3. **SCRIPTED-cause stinger suppression.** Stealth AI's `force_alert_state(new_state, StealthAI.AlertCause.SCRIPTED)` (used by cutscene directors) fires `actor_became_alerted(_, SCRIPTED, _, MAJOR)`. `AudioManager` recognizes `cause == SCRIPTED` and does NOT schedule a stinger — cutscenes own their composed audio, and a brass punch over scripted narrative music is an authoring collision. The `alert_state_changed` handler still fires normally (music-state transitions during cutscenes are expected); only the stinger is suppressed. Stealth AI GDD pre-impl gate #2(f).

4. **Dominant-guard dict clear on section transitions.** On `section_exited`, `AudioManager` clears the entire dominant-guard dict. Rationale: guards from the exited section are about to be freed (or are already freed by Stealth AI's lifecycle); retaining their Node keys produces stale references that crash on the next iteration ("Invalid get index on base Null instance"). `section_entered` then arrives with an empty dict and resolves to `*_calm` for the new section — matching the intended behavior. This also naturally handles the `respawn_triggered` case (section re-entry): the dict is cleared via the paired `section_exited`/`section_entered` that Failure & Respawn owns on sectional respawn, or via the explicit clear documented in the respawn trigger table row.

5. **Bedlam tween mid-decrement policy.** Civilian de-panic (civilian transitions from panic back to calm) decrements `panic_count`; any in-progress bedlam tween on either music layer is cancelled and a new tween from the current `volume_db` to the freshly computed target starts immediately. No chained tweens in opposite directions; no audible "pump."

6. **Document Overlay suspends alert-music transitions.** *(NEW 2026-04-28 per `/review-all-gdds` 2026-04-28 finding 1c-W12 — Document-overlay duck vs alert-state escalation interaction was previously undefined.)* While `InputContext.current() == DOCUMENT_OVERLAY` (Document Overlay UI #20 has pushed its context per its CR-7 lifecycle), `AudioManager` continues to update its dominant-guard dict on incoming `alert_state_changed` / `actor_became_alerted` signals BUT does NOT issue a music-state tween or a brass-stinger schedule. The dominant-state computation is performed and cached as `_pending_dominant_state`; if it differs from the currently-playing music layer state when the overlay closes (`ui_context_changed(GAMEPLAY, DOCUMENT_OVERLAY)` arrives at `AudioManager`'s subscriber), the standard music tween fires at that frame using the cached value (no replay of the queued events; only the *current ground-truth* state at close time is applied). **Stinger queue during overlay**: brass stabs from MAJOR escalations are NOT scheduled while overlay is open — they would compete with the document-room ambience that owns the soundscape during Lectern Pause (Pillar 1: theatrical-mode refusal per Document Overlay UI §A.3 / Document Collection §A.3). Stingers are not retroactively replayed on close — only state changes; the brass beat is a momentary cue, not a durable artifact. **Rationale**: Document Overlay UI's Lectern Pause owns the entire soundscape during reading (sepia-dim + ducked music + suppressed banter per D&S CR-DS-4 + suppressed HUD per HUD CR-22 Tween.kill). Music transitions firing under the overlay would either bleed through the duck (audible) or schedule against an inaudible bus (queued audio decision drift). Suspension is the only correct policy. **Pairing**: this rule pairs with HUD Core CR-22 (Tween.kill on context change leaving GAMEPLAY) — both systems hold zero residual cost during DOCUMENT_OVERLAY READING, supporting the Slot-7 sole-occupant claim per Document Overlay UI §F.5 / AC-DOV-9.2. **Edge case**: if the player presses Esc to close the overlay and Eve has been spotted while reading, the music transitions to `*_alarmed` immediately on the close frame — there is no grace period. The overlay close itself is the audible cue that the world has changed, not the music. **AC obligation**: AudioManager test must verify that `alert_state_changed` arriving during DOCUMENT_OVERLAY does NOT advance the music tween's elapsed time and does NOT schedule a stinger; on context restore to GAMEPLAY, the transition fires with `_pending_dominant_state`. (Audio §Concurrency rule, AudioManager-owned implementation, depends on `Events.ui_context_changed` subscription per ADR-0002 amendment landed 2026-04-28.)

### Interactions with Other Systems

#### AI / Stealth domain

Signatures below reflect the post-ADR-0002-amendment 4-param / 4-param / 2-param / 3-param forms mandated by Stealth AI GDD (approved 2026-04-21). ADR-0002 amendment is a pre-implementation prerequisite — see §Detailed Rules Rule 3.

| Signal | Audio behavior | Condition |
|---|---|---|
| `alert_state_changed(actor, old, new, severity)` | Update dominant-guard dict → drive music state machine. See §Concurrency Policies (same-state idempotence). | Always |
| `actor_became_alerted(actor, cause, pos, severity)` | Quantize `MusicSting` brass stab to next 120 BPM downbeat | **ONLY when `severity == StealthAI.Severity.MAJOR` AND `cause != StealthAI.AlertCause.SCRIPTED`** — MINOR propagation bumps and casual SUSPICIOUS investigations produce NO stinger (Pillar 1: comedy-without-punchlines requires the score to stay deadpan under MINOR escalations); SCRIPTED cutscene escalations produce NO stinger (cutscenes own their composed audio — see §Concurrency Policies). Also subject to per-beat-window debounce (§Concurrency Policies). |
| `actor_lost_target(actor, severity)` | Remove actor from dict; recalc dominant | Always |
| `takedown_performed(actor, attacker, takedown_type)` | Play takedown SFX at actor position (pooled 3D). **SFX variant is routed by `takedown_type`**: `MELEE_NONLETHAL` → chloroform-style soft whoosh + cloth-drape + body-slump (~300 ms, 80–200 Hz muffled); `STEALTH_BLADE` → brief blade stroke + muffled body-drop (~250 ms, 60–150 Hz; no metal-ring — stealth weapon). See §SFX event catalog. | Always |

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
| `section_entered(section_id, reason)` | Branches on `reason: LevelStreamingService.TransitionReason` per LS GDD CR-8. **All branches first:** swap reverb bus preset (in-place property mutation on the live `AudioEffectReverb` instance, NOT remove/re-add — prevents click during active crossfade). Then: **FORWARD** → full music-location crossfade: swap music layer assets (preloaded) and transition to `[section]_calm`. **RESPAWN** → no additional music action; `respawn_triggered` (Failure/Respawn domain) already began the 2.0 s ease-in from silence toward `[section_id]_calm`; this handler MUST NOT re-trigger a crossfade (would cut off the in-flight ease-in). **NEW_GAME** → stop menu ambient (if any), preload music layer assets, crossfade to `[section]_calm` as the menu→section handoff; dominant-guard dict initialized empty. (Menu ambient fade-out curve pending — Audio OQ.) **LOAD_FROM_SAVE** → resume-from-save: preload music layer assets and instant-set to `[section]_calm` with no crossfade ceremony (matches "continue where you left off" UX). | Always |
| `section_exited(section_id, reason)` | All reasons: clear the dominant-guard dict; cancel any in-flight alert-state tween on `MusicDiegetic`/`MusicNonDiegetic`. `reason` is consumed for EventLogger diagnostic context only; audible behavior is uniform — section exit is always a clean slate regardless of why. | Always — §Concurrency Policies Rule 4 |
| `objective_started` | Brief ascending chime (non-spatial, UI bus) | Always |
| `objective_completed` | Brass fanfare stinger (non-spatial, Music bus) | Fires once per objective |
| `mission_started(mission_id)` | Period radio static + 3-blink morse BQA signature | Always |
| `mission_completed(mission_id)` | Instant music cut → `MusicSting` victory sting → ambient return | Always |

#### Failure/Respawn domain

Moved from Mission domain 2026-04-21 re-review — ADR-0002:183 places `respawn_triggered` in its own Failure/Respawn domain per the system-ownership rule (Failure & Respawn is system 14 and is the publisher).

| Signal | Audio behavior | Condition |
|---|---|---|
| `respawn_triggered(section_id)` | Cut all music to silence for ~200 ms; clear dominant-guard dict (redundant with paired `section_exited` but safe); ease-in to `[section_id]_calm` over 2.0 s | Always |

#### Civilian domain

| Signal | Audio behavior | Condition |
|---|---|---|
| `civilian_panicked(civilian, pos)` | Period-appropriate French vocal gasp ("Mon Dieu!") at civilian pos (pooled 3D, Voice bus). Increment `panic_count` → recompute Formula 2 (diegetic recedes up to −3 dB, non-diegetic rises up to +2 dB, both capped; see §Formulas Formula 2) | Always |
| `civilian_witnessed_event` | Crowd murmur uptick on Ambient bus (non-spatial layer intensification) | Always |

#### Dialogue domain *(D&S v0.3 §F.6 #5 amendment applied 2026-04-28)*

| Signal | Audio behavior | Condition |
|---|---|---|
| `dialogue_line_started(speaker, line_id)` | Apply VO duck per Formula 1 + Rule 7 (Music + Ambient duck) — **Audio is subscriber-only and does NOT play VO files; D&S owns the AudioStreamPlayer per dialogue-subtitles.md §C.3** | Always |
| `dialogue_line_finished` | Restore Music + Ambient duck over 0.5 s release | Always |
| `document_opened` *(v0.3 — D&S CR-DS-17 entry)* | **Voice bus duck −12 dB** (`voice_overlay_duck_db = -12.0`); 0.3 s attack | Always (independent of VO duck) |
| `document_closed` *(v0.3 — D&S CR-DS-17 entry)* | Restore Voice bus over 0.5 s release | Always |

**VO ownership contract (D&S v0.3 §F.6 #5 amendment 2026-04-28; supersedes 2026-04-20 B8 clarification):** Dialogue & Subtitles is the **sole publisher** of `dialogue_line_started` and `dialogue_line_finished` AND **owns the AudioStreamPlayer node** that plays VO files. D&S maintains its own `AudioLinePlayer` (AudioStreamPlayer routed to Voice bus) per `dialogue-subtitles.md` §C.3 scene tree. Audio is **subscriber-only ducking**: on `dialogue_line_started` it ducks Music + Ambient per Rule 7 / Formula 1; on `dialogue_line_finished` it restores. Audio does NOT load or play VO files. The `dialogue-subtitles.md §A.1` VO file naming convention `assets/audio/vo/[speaker_category]/[line_id]_[locale].ogg` is **canonical** — the previous Audio GDD references to `vo_[speaker]_[line].ogg` are obsolete and have been removed. Subtitle display timing is owned by D&S using the same signals. No direct calls between Audio and D&S. This preserves Audio's subscriber-only architectural promise (Overview).

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

### Formula 1 — VO ducking target (state-keyed, per-layer)

Revised 2026-04-21 re-review (audio-director + game-designer merged fix): a flat −8 dB duck is too shallow when the diegetic quartet is at 0 dB (broadcast norm for dialog masking is −18 to −24 dB; vibraphone + upright-bass sit in VO intelligibility range), and a flat duck over-suppresses the non-diegetic score during combat when that score IS the alert signal (Pillar 3). The revised formula is **state-keyed and per-layer**: `MusicDiegetic` ducks deeper during calm states (comedy priority), `MusicNonDiegetic` ducks lighter during combat states (signal preservation).

#### Duck-depth table

| Alert state | `MusicDiegetic` duck | `MusicNonDiegetic` duck | Ambient duck |
|---|---|---|---|
| `*_calm` | **−14 dB** | −6 dB | −6 dB |
| `*_suspicious` | −10 dB | −6 dB | −6 dB |
| `*_searching` | −8 dB | −5 dB | −6 dB |
| `*_combat` | −6 dB (mostly silent already) | **−4 dB** (signal preservation) | −6 dB |
| `DOCUMENT_OVERLAY` | −8 dB additional | −8 dB additional | −6 dB |

#### Formula

```
music_diegetic_ducked_db   = max(setting_music_volume_db   + diegetic_duck_db[state],   -80.0)
music_nondiegetic_ducked_db = max(setting_music_volume_db   + nondiegetic_duck_db[state], -80.0)
ambient_ducked_db          = max(setting_ambient_volume_db + ambient_duck_db,            -80.0)
```

The `max(..., -80.0)` clamp is load-bearing: the Music bus safe range is −80 to 0 dB (Tuning Knobs), so at slider=−80 dB plus any non-zero duck offset, the unclamped computation goes below −80 dB. Godot accepts writes below −80 dB but clips the true output at that floor; writing the literal floor value is the hygienic path.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `setting_music_volume_db` | M | float | −80.0 to 0.0 | Music bus volume as set by Settings |
| `setting_ambient_volume_db` | A | float | −80.0 to 0.0 | Ambient bus volume as set by Settings |
| `diegetic_duck_db[state]` | — | float | −14.0 to −6.0 | Per-state diegetic duck (see table) |
| `nondiegetic_duck_db[state]` | — | float | −6.0 to −4.0 | Per-state non-diegetic duck (see table) |
| `ambient_duck_db` | — | float | −6.0 default, safe −2.0 to −12.0 | Ambient duck (flat across states) |
| `music_diegetic_ducked_db` | — | float | −80.0 to −6.0 | MusicDiegetic player `volume_db` during VO |
| `music_nondiegetic_ducked_db` | — | float | −80.0 to −4.0 | MusicNonDiegetic player `volume_db` during VO |
| `ambient_ducked_db` | — | float | −80.0 to −2.0 | Ambient bus volume during VO playback |

**Output range:** Under normal settings (music at 0 dB, ambient at 0 dB), a `*_calm` VO produces `MusicDiegetic` at −14 dB, `MusicNonDiegetic` at −6 dB, Ambient at −6 dB. A `*_combat` VO produces `MusicDiegetic` at −6 dB (already near-silent at base −80 dB), `MusicNonDiegetic` at −4 dB (barely ducked — the signal is preserved), Ambient at −6 dB. Clamp prevents any computed target from going below −80 dB.

**Example:** Player has Music slider at −6 dB (comfortable) and Ambient at 0 dB. VO starts during `*_suspicious`. `MusicDiegetic` ducks to `max(-6 + -10, -80) = -16 dB`; `MusicNonDiegetic` ducks to `max(-6 + -6, -80) = -12 dB`; Ambient ducks to `max(0 + -6, -80) = -6 dB`. On VO end, all restore to stored setting values (−6 and 0).

**Short-VO tween interrupt edge case:** if `dialogue_line_finished` fires while the attack tween is still in progress (e.g., a 150 ms VO clip with 0.3 s attack), the release tween must start from the **current partially-ducked volume**, not from the duck target. Implementation: each attack tween stores its `Tween` handle; the finished handler kills the attack tween (if active) and spawns a release tween from the live `volume_db` value.

### Formula 2 — Civilian bedlam response (diegetic recedes, non-diegetic holds)

Revised 2026-04-21 re-review (game-designer + creative-director direction): the prior formula boosted `MusicNonDiegetic` by up to +6 dB on panicked civilians, which is a Pillar 1 violation — the score loudly commenting on the chaos reads as Hollywood cartoon punchline, the opposite of "comedy without punchlines." It also produced a +1 dB computed target above unity (clipping risk). The revised formula inverts the response: **the diegetic layer recedes (the quartet recoils from the crowd), the non-diegetic score barely rises (stealth cool stays unfazed).**

#### Formula

```
diegetic_duck_bedlam_db    = -min(panic_count * 1.0, 3.0)          # negative — attenuation
nondiegetic_boost_bedlam_db = min(panic_count * 0.5, 2.0)          # positive — gentle boost
music_diegetic_effective_db    = max(base_diegetic_state_db    + diegetic_duck_bedlam_db,    -80.0)
music_nondiegetic_effective_db = min(base_nondiegetic_state_db + nondiegetic_boost_bedlam_db,  0.0)
```

The `min(..., 0.0)` clamp on the non-diegetic layer prevents any computed target from exceeding unity — no clipping risk regardless of base state or tuning knob values.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `panic_count` | p | int | 0 to many | Number of civilians currently in panic state |
| `diegetic_duck_bedlam_db` | — | float | −3.0 to 0.0 | Attenuation applied to `MusicDiegetic` volume (negative = quieter) |
| `nondiegetic_boost_bedlam_db` | — | float | 0.0 to +2.0 | Additive boost applied to `MusicNonDiegetic` volume (positive = louder) |
| `base_diegetic_state_db` | — | float | −80.0 to 0.0 | Current `MusicDiegetic` level from state machine (see §States table) |
| `base_nondiegetic_state_db` | — | float | −18.0 to 0.0 | Current `MusicNonDiegetic` level from state machine |

**Output range:** 0 panicked civilians → no effect. 1 civilian → diegetic −1 dB, non-diegetic +0.5 dB. 2 civilians → diegetic −2 dB, non-diegetic +1 dB. 3+ civilians → diegetic −3 dB (hard cap), non-diegetic +2 dB (hard cap). Civilians returning to calm state decrement `panic_count`; an in-progress bedlam tween is cancelled and re-targeted per §Concurrency Policies Rule 5.

**Example:** In the Restaurant during `*_suspicious` state (MusicDiegetic at −6 dB base, MusicNonDiegetic at −3 dB base), 2 civilians panic. `MusicDiegetic` attenuates to `max(-6 + -2, -80) = -8 dB` (the quartet recoils); `MusicNonDiegetic` rises to `min(-3 + 1, 0) = -2 dB` (stealth cool barely inflects). Transition duration: 0.5 s ease-in. Pillar 1 preserved: the world falls apart while Eve's underscoring holds steady.

### Formula 3 — 3D spatial attenuation (engine-provided)

`AudioStreamPlayer3D` uses Godot's `AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE` model, which this GDD inherits without redefining. The parameters we set:

| Parameter | Value | Effect |
|---|---|---|
| `max_distance` | 50.0 m (default) | Sound fully inaudible beyond this distance |
| `unit_size` | 10.0 m (default) | Distance at which sound is at reference volume |
| `attenuation_model` | `ATTENUATION_INVERSE_DISTANCE` | Standard 1/r falloff |

**Exception — Plaza guard-post radio chatter:** `max_distance = 40.0 m`, `unit_size = 6.0 m`. Wider range ensures the chatter is always faintly audible throughout the Plaza section while letting distance-based attenuation signal direction to the player. This is the locked hybrid decision from Section C Interactions.

### Formula 4 — Clock-tick start/stop trigger (critical health)

**Settled 2026-04-20 re-review**: tempo is **fixed at 90 bpm** — the prior tempo-scaling proposal has been removed. The Open Question is closed in favor of simplicity (no per-frame tempo tracking, no PC-GDD coupling on `current_health`).

Signal signature per ADR-0002:151 is `player_health_changed(current: float, max_health: float)` — both are floats at the signal boundary even if the underlying PC state is int.

```
# Start condition — triggered on receipt of player_health_changed(current, max_health):
if max_health <= 0.0:
    return  # config-error guard — prevents divide-by-zero crash

health_pct = current / max_health
if health_pct < clock_tick_threshold_pct / 100.0 and not tick_playing and tick_last_stopped_age_s >= clock_tick_debounce_s:
    start_clock_tick_loop(clock_tick_bpm)  # fixed 90 bpm from Tuning Knobs

# Stop condition — same signal:
if health_pct >= clock_tick_threshold_pct / 100.0 and tick_playing:
    stop_clock_tick_loop()
    tick_last_stopped_age_s = 0.0  # reset debounce timer
```

`tick_last_stopped_age_s` is initialized to `INF` at `AudioManager._ready()` — ensures the first threshold-crossing of the game is not blocked by a cold debounce.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current` | — | float | 0.0 to max_health | Eve's current health from `player_health_changed` signal payload |
| `max_health` | — | float | 100.0 (default), safe 50.0–200.0 | Eve's maximum health from signal payload; values ≤ 0.0 trigger early return |
| `health_pct` | — | float | 0.0 to 1.0 | Computed ratio |
| `clock_tick_threshold_pct` | — | int | 25 (default), safe 10–40 | % below which loop triggers |
| `clock_tick_debounce_s` | — | float | 1.0 default | Minimum off-time before restart |
| `tick_last_stopped_age_s` | — | float | init `INF`; else 0.0 at stop; frame-advanced | Debounce timer accumulator |

**Output**: the loop starts once when `health_pct` drops below the threshold (and debounce permits) and stops once when it rises back above. Tempo is fixed at 90 bpm from the `clock_tick_bpm` Tuning Knob; loop is pre-authored at that tempo. `max_health <= 0.0` is a guarded no-op (config-error safety).

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
- **If `setting_changed` fires with a non-audio, non-accessibility category** → `AudioManager` checks whether the event is one Audio actually consumes (`category == "audio"` for bus volumes, OR `category == "accessibility"` for the `clock_tick_enabled` opt-out per Settings line 180 — `clock_tick_enabled` was moved from `audio` to `accessibility` 2026-04-27 to match Audio GDD's existing emit pattern at line 237) and returns early otherwise. The filter is a key-allowlist within both categories — `audio.<bus_name>_volume_db` keys + `accessibility.clock_tick_enabled` are the only events Audio responds to. **Resolution**: revised 2026-04-27 sweep (closes B6 from /review-all-gdds 2026-04-27). The earlier "Audio only listens for its own category" framing was correct when `clock_tick_enabled` lived in `audio`; after the 2026-04-27 Settings revision moved it to `accessibility`, the filter must allow both categories. Pre-sweep filter was a self-contradicting silent-drop bug — Audio claimed to consume `accessibility.clock_tick_enabled` at line 237 + AC line 650 while line 377's filter would have early-returned on it.
- **If the game is paused (InputContext != GAMEPLAY) and music state transitions occur** (e.g., scripted mission progression during a cutscene) → music transitions fire as normal. `InputContext` gates player INPUT, not AudioManager event subscriptions. **Resolution**: intended. Music continues to respond to events during menus, which is correct for mission-state music transitions during cutscenes.

## Dependencies

### Upstream dependencies

| System | Nature |
|---|---|
| **Signal Bus** (system 1) | Audio subscribes to **30 events across 9 gameplay domains + Settings** (revised 2026-04-21 re-review — added `section_exited`, separated Failure/Respawn from Mission, updated AI/Stealth to post-ADR-0002-amendment 4-param/3-param signatures). Hard dependency — no Audio without the bus. ADR-0002 amendment for the AI/Stealth severity parameter is a pre-implementation prerequisite. |
| Godot 4.6 `AudioServer` + `AudioStreamPlayer`/`AudioStreamPlayer3D` | Engine dependency. Stable since 4.0. |
| ADR-0002 (Signal Bus + Event Taxonomy) | Contract defining the events Audio consumes and the subscriber lifecycle pattern. |

### Downstream dependents

| System | Direction | Nature |
|---|---|---|
| **Dialogue & Subtitles** (system 18) | Dialogue → Audio | D&S publishes `dialogue_line_started` / `_finished` AND owns the AudioStreamPlayer that plays VO files (per D&S §C.3 + v0.3 §F.6 #5 amendment 2026-04-28). Audio is **subscriber-only ducking**: applies Music + Ambient duck per Formula 1 / Rule 7 on `_started` and Voice-bus duck −12 dB on `document_opened` per CR-DS-17. Audio does NOT load or play VO files. D&S does NOT call Audio directly — both subscribe independently to overlay signals. |
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
| Voice bus | 0.0 dB | −80.0 to 0.0 | VO playback; ducks **−12 dB on `document_opened`** per CR-DS-17 (v0.3 — D&S §F.6 #5 amendment); not ducked by VO itself |
| UI bus | 0.0 dB | −80.0 to 0.0 | Menu clicks, document overlay SFX, clock-tick |

### Transition durations (designer-adjustable)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `music_crossfade_default_s` | 2.0 | 0.5 to 5.0 | Non-alert transitions (section enter, doc overlay restore) |
| `alert_unaware_to_suspicious_s` | 1.5 | 0.5 to 3.0 | Slower = more grace period for player to hear shift |
| `alert_suspicious_to_searching_s` | 0.8 | 0.2 to 2.0 | Faster = more urgent feel |
| `alert_to_combat_s` | 0.3 | 0.1 to 1.0 | Effectively a cut; scene-opens feel (theatre), NOT a punishment signal — see §Player Fantasy Combat transition position statement |
| `alert_deescalate_s` | 3.0 | 1.5 to 6.0 | Slow relief; stealth exhale |
| `respawn_fade_in_s` | 2.0 | 1.0 to 3.0 | Ease-in from silence to `*_calm` after respawn. 2.0 s reads as scene reset (Pillar 3 theatre). Lower values drift toward cinema hard-cut feel — violates Pillar 3. |
| `respawn_silence_s` | 0.2 | 0.0 to 0.5 | Silence gap between `respawn_triggered` and the start of the fade-in. Gives the "house lights up between scenes" beat. |
| `vo_duck_attack_s` | 0.3 | 0.1 to 0.8 | Time to reach ducked volume |
| `vo_duck_release_s` | 0.5 | 0.2 to 1.5 | Time to restore after VO end |

### Duck amounts (state-keyed per-layer — Formula 1)

Revised 2026-04-21 — flat `music_duck_db` replaced by state-keyed per-layer duck. See Formula 1 duck-depth table for the authoritative values; knobs below are the underlying configurable constants.

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `diegetic_duck_calm_db` | −14.0 | −10.0 to −18.0 | `MusicDiegetic` duck during `*_calm` (deep — comedy priority, quartet is loud) |
| `diegetic_duck_suspicious_db` | −10.0 | −6.0 to −14.0 | `MusicDiegetic` duck during `*_suspicious` |
| `diegetic_duck_searching_db` | −8.0 | −5.0 to −12.0 | `MusicDiegetic` duck during `*_searching` |
| `diegetic_duck_combat_db` | −6.0 | −3.0 to −10.0 | `MusicDiegetic` duck during `*_combat` (layer already silent at −80 dB base) |
| `nondiegetic_duck_calm_db` | −6.0 | −4.0 to −10.0 | `MusicNonDiegetic` duck during `*_calm` (layer is already at −12 dB bed) |
| `nondiegetic_duck_suspicious_db` | −6.0 | −4.0 to −10.0 | `MusicNonDiegetic` duck during `*_suspicious` |
| `nondiegetic_duck_searching_db` | −5.0 | −3.0 to −8.0 | `MusicNonDiegetic` duck during `*_searching` |
| `nondiegetic_duck_combat_db` | −4.0 | −2.0 to −6.0 | `MusicNonDiegetic` duck during `*_combat` (lightest — score IS the alert signal) |
| `ambient_duck_db` | −6.0 | −2.0 to −12.0 | Ambient duck (flat across states) |
| `document_overlay_music_db` | −10.0 | −5.0 to −15.0 | Music level during document reading |
| `voice_overlay_duck_db` *(v0.3 NEW — D&S CR-DS-17 amendment 2026-04-28)* | **−12.0** | −18.0 to 0.0 | Voice bus duck on `document_opened` so VO recedes while player reads; restores on `document_closed`. v0.3 deepened from initial −6.0 dB target to broadcast intelligibility floor per audio-director re-review. Playtest-tunable. |
| `document_overlay_ambient_db` | −20.0 | −10.0 to −30.0 | Ambient level during document reading (more suppressed — the world recedes) |

### Spatial audio parameters

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `sfx_pool_size` | 16 | 8 to 32 | Global `AudioStreamPlayer3D` pool count |
| `spatial_max_distance_m` | 50.0 | 20.0 to 100.0 | Default max audible distance for pooled 3D SFX |
| `spatial_unit_size_m` | 10.0 | 5.0 to 20.0 | Distance at which sound is at reference volume |
| `plaza_radio_max_distance_m` | 40.0 | 30.0 to 60.0 | **Exception** — wider range for guard-post radio chatter |
| `plaza_radio_unit_size_m` | 6.0 | 4.0 to 10.0 | Matches the "bed with direction" hybrid decision |

### Civilian bedlam (revised Formula 2 — diegetic recedes, non-diegetic holds)

Revised 2026-04-21 — prior +2 dB/civ non-diegetic boost with +6 dB cap was a Pillar 1 violation (score loudly commenting on chaos = Hollywood cartoon). New direction: the quartet recoils from the crowd, the stealth cool barely inflects.

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `bedlam_diegetic_attenuation_per_civilian_db` | −1.0 | −0.5 to −2.0 | `MusicDiegetic` attenuation per panicked civilian (negative = quieter — Pillar 1: quartet recoils) |
| `bedlam_diegetic_attenuation_max_db` | −3.0 | −1.5 to −6.0 | Diegetic attenuation hard cap (floor on the attenuation — reaches at 3 civilians by default) |
| `bedlam_nondiegetic_boost_per_civilian_db` | +0.5 | +0.0 to +1.0 | `MusicNonDiegetic` boost per panicked civilian (gentle; preserves stealth-cool feel) |
| `bedlam_nondiegetic_boost_max_db` | +2.0 | +0.5 to +3.0 | Non-diegetic boost hard cap. The `min(base + boost, 0.0)` ceiling in Formula 2 further constrains the effective volume — no clip risk at any boost value. |

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
| `takedown_performed` (MELEE_NONLETHAL) | Chloroform-style soft whoosh + cloth-drape + body-slump impact (~300 ms, 80–200 Hz muffled; distinct from blade — reads as non-lethal knockout) | 3D @ target | SFX | 2 |
| `takedown_performed` (STEALTH_BLADE) | Brief blade stroke (short leather-sheath draw + quiet stroke, no metal-ring — stealth weapon) + muffled body-drop (~250 ms, 60–150 Hz) | 3D @ target | SFX | 2 |
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
| Signal Bus subscriptions | `design/gdd/signal-bus.md` + `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | 30 signals across 9 gameplay event domains (AI/Stealth, Combat, Player, Mission, Failure/Respawn, Civilian, Dialogue, Documents, Persistence) + Settings | Data dependency (Audio subscribes) — post-ADR-0002-amendment signatures |
| Subscriber lifecycle | `design/gdd/signal-bus.md` Rule 4 + ADR-0002 Implementation Guideline 3 | `_ready()` connect / `_exit_tree()` disconnect pattern with `is_connected` guard | Rule dependency |
| Alert state rule (music signals state, not visuals) | `feedback_visual_state_signaling` memory + `design/gdd/game-concept.md` Visual Identity Anchor | Alert state changes via music/audio, NOT lighting or color shifts | Rule dependency |
| Audio mood per location | `design/art/art-bible.md` Section 2 | Mood targets per Plaza/Scaffolds/Restaurant/Upper Structure/Bomb Chamber | Data dependency (Audio sections realize the mood targets) |
| HUD critical-health clock-tick | `design/art/art-bible.md` Section 4.4 | Alarm Orange numeral + clock-tick SFX pairing | Data dependency |
| VO line timing | `design/gdd/game-concept.md` MVP scope | 30–50 VO lines at MVP | Scope reference |
| Settings persistence | `docs/architecture/adr-0003-save-format-contract.md` | Settings in `user://settings.cfg`, not SaveGame | Rule dependency |
| Period audio references (Mancini, Goldsmith, *Our Man Flint*) | `design/gdd/game-concept.md` inspirations | Score style anchor | Tone reference |

## Acceptance Criteria

Each AC is tagged with a story type ([Logic], [Integration], [Visual/Feel], [Code-Review]) and cites its test-evidence file path. Clean-renumbered 1–40 in the 2026-04-21 re-review.

### Bus + subscriber infrastructure

1. **[Logic]** **GIVEN** the project is launched, **WHEN** the `AudioServer` bus list is inspected, **THEN** five buses exist: `Music`, `SFX`, `Ambient`, `Voice`, `UI`. Each has its own effects chain. Evidence: `tests/unit/audio/audio_bus_structure_test.gd`.
2. **[Logic]** **GIVEN** `AudioManager.gd`, **WHEN** `_ready()` completes, **THEN** it has connected to all 30 signals from ADR-0002 listed in Section C.1 Rule 3 (9 gameplay domains + Settings). **AND** on `_exit_tree()`, it disconnects every connection with `is_connected` guards. **⚠️ Gated on ADR-0002 amendment**: the AI/Stealth signals in this count use the post-amendment 4-param / 3-param signatures; test is `skip("blocked on ADR-0002 amendment")` until the amendment lands. Evidence: `tests/unit/audio/audio_subscription_count_test.gd`.
3. **[Code-Review]** **GIVEN** any project source file, **WHEN** grepped for `AudioStreamPlayer.new()` or `AudioStreamPlayer3D.new()` calls in `_process` or `_physics_process` or runtime non-startup code, **THEN** zero matches (pooling rule). Grep pattern: `(AudioStreamPlayer|AudioStreamPlayer3D)\.new\(\).*_process`. Evidence: `tests/ci/audio_pooling_lint.gd`.
4. **[Code-Review]** **GIVEN** any `AudioStreamPlayer` or `AudioStreamPlayer3D` in the scene tree, **WHEN** its `bus` property is inspected, **THEN** it is one of the five named buses — never `Master`. Evidence: `tests/unit/audio/audio_no_master_bus_test.gd` (scene-tree scan at test startup).

### Music layer behavior

5. **[Logic]** **GIVEN** the game is in `plaza_calm` state (MusicDiegetic 0 dB, MusicNonDiegetic −12 dB), **WHEN** a guard transitions UNAWARE → SUSPICIOUS (via `alert_state_changed(_, UNAWARE, SUSPICIOUS, MINOR)`), **THEN** over 1.5 s linear, MusicDiegetic drops to −6 dB and MusicNonDiegetic rises to −3 dB. Evidence: `tests/unit/audio/audio_calm_to_suspicious_test.gd`.
6. **[Logic]** **GIVEN** the game is in `*_combat` state, **WHEN** the last combat-tier actor leaves combat (via `enemy_killed` or `actor_lost_target`), **THEN** over 3.0 s ease-in-out, music transitions back to `*_calm`. Evidence: `tests/unit/audio/audio_combat_to_calm_test.gd`.
7. **[Logic]** **GIVEN** `actor_became_alerted(_, SAW_PLAYER, pos, MAJOR)` fires, **WHEN** the pure helper `get_next_beat_offset_s(current_playback_pos, 120.0)` is computed, **THEN** the returned offset is the time until the next 120 BPM downbeat (0.0 ≤ offset < 0.5 s). Parametrized over 6 inputs: `(0.0) → 0.0`, `(0.1) → 0.4`, `(0.24) → 0.26`, `(0.5) → 0.0`, `(0.3) → 0.2`, `(0.499) → 0.001`. Helper is a pure function — unit-tested deterministically against fixed inputs without requiring a real-time scene-tree timebase. Evidence: `tests/unit/audio/audio_beat_quantization_test.gd`.
8. **[Integration]** **GIVEN** `section_entered(NEW_SECTION)` fires, **WHEN** Audio responds, **THEN** it swaps the music layer assets to the new section's preloaded streams AND mutates the existing `AudioEffectReverb` instance on the SFX bus (in-place property update, not remove/re-add — asserted by capturing the effect node reference before/after and verifying identity). Evidence: `tests/integration/audio/audio_section_swap_test.gd`.

### Severity filter + concurrency policies (new 2026-04-21)

9. **[Logic]** **GIVEN** `actor_became_alerted(_, SAW_PLAYER, pos, MINOR)` fires, **WHEN** Audio handles it, **THEN** no `MusicSting` schedule occurs — no stinger plays now, no stinger plays on the next beat. Severity-filter gate: only MAJOR stingers are scheduled. Evidence: `tests/unit/audio/audio_stinger_severity_filter_test.gd`.
10. **[Logic]** **GIVEN** `actor_became_alerted(_, SCRIPTED, pos, MAJOR)` fires (cutscene force-alert), **WHEN** Audio handles it, **THEN** no `MusicSting` schedule occurs. SCRIPTED-cause suppression (§Concurrency Policies Rule 3). Evidence: `tests/unit/audio/audio_stinger_scripted_suppression_test.gd`.
11. **[Logic]** **GIVEN** 3 guards fire `actor_became_alerted(_, SAW_PLAYER, pos, MAJOR)` in the same physics frame, **WHEN** Audio handles them, **THEN** exactly 1 `MusicSting` is scheduled on the upcoming downbeat. Subsequent MAJOR arrivals within the same 0.5 s window are silently discarded (§Concurrency Policies Rule 1). Evidence: `tests/unit/audio/audio_stinger_debounce_test.gd`.
12. **[Logic]** **GIVEN** music state is already `*_suspicious` and 5 guards fire `alert_state_changed(_, UNAWARE, SUSPICIOUS, MINOR)` in one frame, **WHEN** Audio handles them, **THEN** zero new tweens are created on `MusicDiegetic`/`MusicNonDiegetic` — same-state idempotence early-returns after dict update (§Concurrency Policies Rule 2). Asserted via Tween spy: tween-creation count == 0. Evidence: `tests/unit/audio/audio_same_state_idempotence_test.gd`.
13. **[Logic]** **GIVEN** a dominant-guard dict populated with 4 active guards, **WHEN** `section_exited(&"plaza")` fires, **THEN** the dict has 0 entries AND any in-flight alert-state tween on `MusicDiegetic`/`MusicNonDiegetic` is killed (Tween.is_valid() == false). Evidence: `tests/unit/audio/audio_section_exit_cleanup_test.gd`.

### VO ducking (state-keyed per-layer, Formula 1)

14. **[Logic]** **GIVEN** music state is `plaza_calm` (MusicDiegetic 0 dB, MusicNonDiegetic −12 dB), **WHEN** `dialogue_line_started` fires, **THEN** over 0.3 s: MusicDiegetic ducks to −14 dB (deep — calm-state comedy priority), MusicNonDiegetic ducks to −18 dB (already quiet bed, further suppressed by Formula 1's calm-state −6 dB duck), Ambient ducks to −6 dB. Evidence: `tests/unit/audio/audio_vo_duck_calm_test.gd`.
15. **[Logic]** **GIVEN** music state is `plaza_combat` (MusicDiegetic −80 dB, MusicNonDiegetic 0 dB), **WHEN** `dialogue_line_started` fires, **THEN** over 0.3 s: MusicNonDiegetic ducks to −4 dB only (signal preservation — the score IS the combat alert cue), MusicDiegetic is already near-silent, Ambient ducks to −6 dB. Evidence: `tests/unit/audio/audio_vo_duck_combat_test.gd`.
16. **[Logic]** **GIVEN** Music setting slider at −80 dB, **WHEN** `dialogue_line_started` fires in any alert state, **THEN** the computed duck target is clamped to −80 dB (not −94 or −86 — Formula 1 `max(..., -80.0)` clamp). Evidence: `tests/unit/audio/audio_vo_duck_clamp_test.gd`.
17. **[Logic]** **GIVEN** a 150 ms VO clip with 0.3 s attack + 0.5 s release, **WHEN** `dialogue_line_finished` fires while the attack tween is still in progress, **THEN** the attack tween is killed AND the release tween starts from the live (partial) `volume_db` value, not from the duck target. Asserted via tween spy: release tween's source value equals the live volume at the kill point. Evidence: `tests/unit/audio/audio_vo_short_line_tween_interrupt_test.gd`.
18. **[Logic]** **GIVEN** VO is playing, **WHEN** the Voice bus volume is queried, **THEN** it is unducked (same as Settings configured value). Evidence: same file as AC-14.

### Spatial SFX

19. **[Logic]** **GIVEN** 17 simultaneous `weapon_fired` events in the same frame, **WHEN** Audio handles them, **THEN** `AudioManager.get_active_voices()` returns 16 non-idle slots AND `AudioManager.get_last_stolen_slot_id()` returns the slot index that was previously occupied the longest among non-Voice-non-UI voices. No error; no dropped SFX. Inspector API (`get_active_voices`, `get_last_stolen_slot_id`) is part of AudioManager's public interface. Evidence: `tests/unit/audio/audio_pool_steal_oldest_test.gd`.
20. **[Logic]** **GIVEN** `weapon_fired(silenced_pistol, pos, dir)` is assigned to a pooled `AudioStreamPlayer3D`, **WHEN** the player's properties are inspected, **THEN** `attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE` AND `unit_size == 10.0` AND `max_distance == 50.0`. White-box property assertion — Godot headless does not expose per-emitter output-dB measurement; this AC validates the configured attenuation contract. Evidence: `tests/unit/audio/audio_attenuation_config_test.gd`.
21. **[Logic]** **GIVEN** the Plaza guard-post radio `AudioStreamPlayer3D`, **WHEN** its properties are inspected, **THEN** `max_distance == 40.0` AND `unit_size == 6.0` (exception values per Formula 3). AND per Godot's `ATTENUATION_INVERSE_DISTANCE` model, computed gain at 40 m == 0 (silence cutoff); computed gain at 10 m ≈ 0.6× reference (−4.4 dB); computed gain at 20 m ≈ 0.3× reference (−10.5 dB). Assertions are against the analytical model (pure-function gain computation given `unit_size`, `max_distance`, `r`), not runtime output dB. Evidence: `tests/unit/audio/audio_plaza_radio_attenuation_test.gd`.

### Settings integration

22. **[Logic]** **GIVEN** the player moves the Music volume slider to −20 dB, **WHEN** Settings emits `setting_changed("audio", "music_volume", -20.0)`, **THEN** `AudioServer.get_bus_volume_db(Music)` returns −20.0. Evidence: `tests/unit/audio/audio_settings_volume_passthrough_test.gd`.
23. **[Integration]** **GIVEN** the game starts after a previous session where the player muted the Voice bus, **WHEN** `AudioManager._ready()` runs, **THEN** it reads `user://settings.cfg` and applies the stored volume to the Voice bus. Evidence: `tests/integration/audio/audio_settings_restore_on_startup_test.gd`.
24. **[Logic]** **GIVEN** the clock-tick accessibility toggle is OFF, **WHEN** player health drops below 25%, **THEN** no clock-tick loop plays. Evidence: `tests/unit/audio/audio_clock_tick_accessibility_toggle_test.gd`.

### Clock-tick + health (Formula 4)

25. **[Logic]** **GIVEN** `player_health_changed(24.0, 100.0)` fires (crosses threshold downward), **WHEN** `clock_tick_enabled == true` AND `tick_last_stopped_age_s >= clock_tick_debounce_s`, **THEN** the clock-tick loop starts at 90 bpm on the `UI` bus. Evidence: `tests/unit/audio/audio_clock_tick_threshold_test.gd`.
26. **[Logic]** **GIVEN** player health oscillates across 25% within 500 ms, **WHEN** the clock-tick debounce evaluates, **THEN** the loop does not restart within 1.0 s of stopping. Evidence: `tests/unit/audio/audio_clock_tick_debounce_test.gd`.
27. **[Logic]** **GIVEN** `player_health_changed(50.0, 0.0)` fires (config-error max_health=0), **WHEN** Formula 4 evaluates, **THEN** the handler early-returns via the `max_health <= 0.0` guard — no error is raised and the clock-tick loop does not start. Evidence: `tests/unit/audio/audio_clock_tick_max_health_zero_guard_test.gd`.
28. **[Logic]** **GIVEN** the clock-tick loop is active AND `player_died(cause)` fires, **WHEN** Audio handles `player_died`, **THEN** the clock-tick loop stops immediately (no release tween) and the mission-failure sting plays unobstructed. Evidence: `tests/unit/audio/audio_clock_tick_stops_on_death_test.gd`.

### Edge case behavior

29. **[Logic]** **GIVEN** `player_damaged(4.0, source, false)` fires (chip damage below threshold), **WHEN** Audio handles it, **THEN** no hit SFX plays. **GIVEN** `player_damaged(10.0, source, false)`, **THEN** the hit SFX plays. Evidence: `tests/unit/audio/audio_chip_damage_threshold_test.gd`.
30. **[Logic]** **GIVEN** 3 civilians panic simultaneously, **WHEN** Formula 2 evaluates, **THEN** `MusicDiegetic` attenuates by −3 dB (capped — quartet recoils) AND `MusicNonDiegetic` rises by +2 dB (capped — stealth cool barely inflects). Neither boost exceeds the caps `diegetic_duck_bedlam_db >= -3.0` and `nondiegetic_boost_bedlam_db <= +2.0`. Evidence: `tests/unit/audio/audio_bedlam_diegetic_recedes_test.gd`.
31. **[Logic]** **GIVEN** `MusicNonDiegetic` base state is 0 dB (`*_combat`) AND 3 civilians panic, **WHEN** Formula 2's `min(..., 0.0)` ceiling evaluates, **THEN** the computed effective_db == 0.0 dB (not +2 dB). No clipping risk. Evidence: `tests/unit/audio/audio_bedlam_nondiegetic_ceiling_test.gd`.
32. **[Logic]** **GIVEN** a `DOCUMENT_OVERLAY` state is entered during `*_combat`, **WHEN** `document_opened` fires, **THEN** music ducks to overlay levels (−10 dB / −20 dB additional). On `document_closed`, music returns to `*_combat` levels (if combat is still active). Evidence: `tests/unit/audio/audio_document_overlay_during_combat_test.gd`.
33. **[Logic]** **GIVEN** the dominant-guard dict is populated, **WHEN** `respawn_triggered(&"plaza")` fires, **THEN** the dict is cleared AND music cuts to silence for ~200 ms then eases in to `plaza_calm` over 2.0 s. Evidence: `tests/unit/audio/audio_respawn_2s_ease_in_test.gd`.

### Player domain + Persistence

34. **[Logic]** **GIVEN** `player_footstep(&"marble", 5.0)` fires, **WHEN** Audio handles it, **THEN** it selects the `normal` variant (3.5 < 5.0 ≤ 6.5 per §Footstep Surface Map) and plays `sfx_footstep_marble_normal_*` via a pooled `AudioStreamPlayer3D` at the player's position on the `SFX` bus. Evidence: `tests/unit/audio/audio_footstep_variant_selection_test.gd`.
35. **[Logic]** **GIVEN** `player_footstep(&"metal_grate", 9.0)` fires, **WHEN** Audio handles it, **THEN** it selects the `loud` variant (6.5 < 9.0 ≤ 10) and plays `sfx_footstep_grate_loud_*`. Evidence: same file as AC-34 (parametrized).
36. **[Logic]** **GIVEN** `player_footstep(&"marble", 12.0)` fires (Sprint), **WHEN** Audio handles it, **THEN** it selects the `extreme` variant (12.0 > 10) and plays `sfx_footstep_marble_extreme_*` — canonical `extreme` bucket reference. Evidence: same file as AC-34 (parametrized).
37. **[Logic]** **GIVEN** `game_saved(1, &"plaza")` fires, **WHEN** Audio handles it, **THEN** the save-confirm chime plays on the `SFX` bus (non-spatial, ~200 ms). Evidence: `tests/unit/audio/audio_save_chime_test.gd`.
38. **[Logic]** **GIVEN** `takedown_performed(guard_node, eve_node, StealthAI.TakedownType.MELEE_NONLETHAL)` fires, **WHEN** Audio handles it, **THEN** `sfx_takedown_melee_nonlethal_*` plays (pooled 3D @ guard position, SFX bus). **GIVEN** `takedown_performed(guard_node, eve_node, StealthAI.TakedownType.STEALTH_BLADE)` fires, **THEN** `sfx_takedown_stealth_blade_*` plays. Parametrized. Evidence: `tests/unit/audio/audio_takedown_type_branching_test.gd`.

### Anti-pattern enforcement

39. **[Code-Review]** **GIVEN** any system source file, **WHEN** grepped for direct method calls on AudioManager (`AudioManager\.(play_music|play_sfx|set_music_state)`), **THEN** zero matches — all Audio behavior is triggered via `Events` signals. Evidence: `tests/ci/audio_no_direct_api_lint.gd`.
40. **[Code-Review]** **GIVEN** Audio source files, **WHEN** grepped for `(Events\.player_footstep\.connect|Events\.player_footstep\.emit|dialogue_line_finished\.emit|dialogue_line_started\.emit)` within `src/audio/`, **THEN** zero matches — Stealth AI may not subscribe to `player_footstep` via Audio (ownership enforcement), and Audio may not publish any Dialogue signal (subscriber-only invariant). Evidence: `tests/ci/audio_subscriber_only_lint.gd`.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| ~~Clock-tick tempo: fixed or health-scaled?~~ | — | — | **Resolved 2026-04-20** — fixed 90 bpm. Formula 4 rewritten; tempo-scaling branch removed. |
| ~~Should `AudioManager` be a singleton/autoload or a scene-tree Node?~~ | — | — | **Resolved 2026-04-20** — scene-tree Node, persistent root scene. Rule 3. |
| ~~Bedlam response direction — score swells with panic, or diegetic recedes?~~ | — | — | **Resolved 2026-04-21 (this review)** — diegetic recedes, non-diegetic holds. Formula 2 rewritten. Pillar 1 fix. |
| ~~SCRIPTED-cause stinger — suppress or fire?~~ | — | — | **Resolved 2026-04-21 (this review)** — suppress. Cutscene composers own their audio. §Concurrency Policies Rule 3. |
| ~~Respawn crossfade duration — 0.5 s or longer?~~ | — | — | **Resolved 2026-04-21 (this review)** — 200 ms silence then 2.0 s ease-in. Pillar 3 theatre, not cinema hard-cut. |
| ~~VO duck depth — flat or state-varying?~~ | — | — | **Resolved 2026-04-21 (this review)** — state-keyed per-layer table. Formula 1 rewritten. |
| **Pre-implementation gate: ADR-0002 amendment** (AI/Stealth severity parameter + takedown_type parameter) | `technical-director` | Before first Audio or Stealth AI story is played | Owned by Stealth AI pre-impl gate #1. ADR-0002's `Events.gd` code block must carry the post-amendment 4-param / 3-param signatures matching this GDD's §Interactions tables. Runs in a separate session (`/architecture-decision adr-0002-amendment`). |
| Stairs surface (`stairs_metal` / `stairs_stone`) — add to Footstep Surface Map at MVP or defer? | Audio-director + level-designer | Before Observation Deck or Restaurant level authoring | FootstepComponent OQ-FC-5 flagged this. Per sound-designer 2026-04-21: defer to content-production scoping pass; meanwhile stairs inherit their primary surface material (marble-plaza stairs → marble stems; restaurant stone stairs → tile stems). Revisit if playtest surfaces an auditory legibility gap. |
| 50 Hz European grid for Paris sodium-lamp buzz (currently asset spec says ~60 Hz) | Sound-designer | Before ambient asset production begins | Period-authenticity pillar hit. Retune Plaza ambient buzz stem to 50 Hz fundamental + 100 Hz harmonic at asset-production time. No GDD-level design change; asset spec correction. |
| Civilian vocal gasp VO ownership (casting + localization) | Audio-director + narrative-director | Before civilian AI enters content production | Crowd panic gasps ("Mon Dieu!", "Quoi?!") are neither dialogue lines nor SFX cleanly. Likely routed through Dialogue & Subtitles GDD's VO pipeline when that GDD lands. |
| Should dialogue reading during active combat be possible? | Game designer + Mission & Level Scripting GDD author | During Document Overlay UI GDD authoring | Audio handles whatever rule is decided. |
| Should pooled `AudioStreamPlayer3D` slot-steal apply a 50 ms fade-out ramp? | Gameplay-programmer | Vertical Slice polish phase | MVP uses hard cut. Add fade-out if playtest reveals audible clicks. |
| Reverb preset tuning (room size, damping, wet-level per section) | Audio-director | Before music recording begins | Defer to audio-director's reverb-authoring pass; final presets documented in `/asset-spec system:audio` output. |
| Music streaming vs preload at scale (Tier 2 Rome/Vatican) | Audio-director + performance-analyst | Before Tier 2 development begins | Revisit when Tier 2 is scoped. MVP comfortable within PC memory. |
