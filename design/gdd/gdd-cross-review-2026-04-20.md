# Cross-GDD Review Report — 2026-04-20

**GDDs Reviewed**: 8 (signal-bus, input, audio, outline-pipeline, post-process-stack, save-load, localization-scaffold, player-character)
**Systems Covered**: 7 Foundation + Player Character (Core layer)
**Scope**: full (consistency + design theory + cross-system scenario walkthrough)
**Specialists**: Phase 2 (consistency) + Phase 3+4 (design-theory + scenarios) run as parallel subagents
**Verdict**: **FAIL** — 9 blocking issues across consistency and design theory; none require re-design-level rework

---

## Consistency Issues

### Blocking 🔴

**🔴 B1. Outline Pipeline GDD contradicts PC GDD + ADR-0005 on FPS hands rendering.**
- `design/gdd/outline-pipeline.md:107` + `:334` (AC-5) register Eve's FPS hands mesh at stencil Tier 1 via `OutlineTier.set_tier`.
- `design/gdd/player-character.md:207`, `:617`, `:622` + AC-10.1 mandate the inverted-hull shader (ADR-0005) and explicitly forbid `OutlineTier.set_tier` on the hands mesh.
- ADR-0001 never mentions the ADR-0005 exception.
- **Root cause**: ADR-0005 (authored Session B of PC revision, 2026-04-19) did not propagate back to Outline Pipeline GDD or ADR-0001.
- **Fix**: Outline Pipeline GDD §C.3 + AC-5 must carve out the ADR-0005 exception; ADR-0001 "Related" section must cite ADR-0005.

**🔴 B2. Audio GDD missing Footstep Surface Map + Player-domain subscriptions.**
- PC GDD hard-cites "Audio GDD §Footstep Surface Map" at `:211`, `:643`, `:749`.
- No such section exists in `design/gdd/audio.md` (grep confirms zero hits).
- `player_footstep` and `player_interacted` (ADR-0002 Player domain, added 2026-04-19 Session B) are absent from Audio's 22-subscription list at `audio.md:53`.
- **Root cause**: ADR-0002 amendment did not propagate to Audio GDD.
- **Fix**: Author `§Footstep Surface Map` in Audio GDD (7 surfaces × 3 loudness variants = the R-24 threshold table); add Player-domain subscription rows.

**🔴 B3. Signal Bus GDD stale vs ADR-0002 Revision History.**
- `signal-bus.md:17`, `:40`, `:48`, `:162`, `:217` repeatedly state "32 typed signals across 8 domains".
- ADR-0002 `:21` says 34 events across 9 domains (Player domain + 2 signals added 2026-04-19).
- Signal Bus domain table `:54–63` omits Player domain; Consumer Matrix `:65–84` omits Player column.
- AC-3 `:176` and AC-14 `:205` key off "32 signals" count and still pass, masking the drift.
- **Fix**: bump counts to 34 / 9; add Player domain row + consumer matrix column.

**🔴 B4. PC AC-3.4 encodes obsolete single-consumption latch semantics.**
- `player-character.md:815` still says `get_noise_level()` returns 8.0 "until the latch is consumed by `get_noise_event()` or auto-expires after `spike_latch_duration_frames` (default 6 frames ≈ 100 ms)."
- Session E-Prime AI-1 made the latch idempotent-read; auto-expiry is the sole clear (reflected in F.4 + AC-5.2 + AC-5.6). AC-3.4 contradicts these.
- Also uses `_frames` where Tuning Knobs now canonically use `spike_latch_duration_sec` (Session E-Prime R-17).
- **Fix**: rewrite AC-3.4 to cite idempotent-read and `spike_latch_duration_sec × Engine.physics_ticks_per_second`.

**🔴 B5. PC `turn_overshoot_deg` inconsistency.**
- Tuning Knob default raised 2.5°→4.0° in Session E-Prime R-1 (`:568`).
- Visual/Feel table at `:630` still says "2.5° overshoot, 90 ms ease-out return".
- AC-7.2 at `:848` still says "produces a 2.5° overshoot".
- **Fix**: sweep 2.5°→4.0° at both residual locations.

**🔴 B6. Save-Load claims Audio subscribes to `game_saved`; Audio does not.**
- `save-load.md:224`: "Save-confirm chime … triggered by Audio's subscription to `Events.game_saved`. See Audio GDD Section C.3 Mission domain."
- Audio's 22 subscriptions don't include `game_saved` / `game_loaded` / `save_failed`.
- Signal Bus Consumer Matrix `:71` Persist column: Audio has no ✓.
- **Fix**: either add Persistence-domain subscription in Audio GDD OR strip the cross-ref from save-load.md + Signal Bus matrix.

### Warnings ⚠️

- **W1.** Audio GDD uses unqualified `SUSPICIOUS / SEARCHING / COMBAT` — should be `StealthAI.AlertState.*` per ADR-0002 Guideline 2.
- **W2.** `is_critical` signal arg: verified matching — no issue.
- **W3.** `entities.yaml:340–384` stores collision layers as bare integers; notes should cite `PhysicsLayers.LAYER_*` canonical names.
- **W4.** `player_noise_crouch_sprint` deprecated entry still has non-empty `referenced_by`.
- **W5.** Dependencies bidirectionality gaps (Outline↔PC-hands, Audio↔PC-footstep, Save-Load→Audio-chime) — all trace to B1/B2/B6 root causes.
- **W6.** `systems-index.md:5` Last Updated: 2026-04-19, but PC row shows Approved 2026-04-20.
- **W7.** Audio Formula 4 (clock-tick tempo scaling by health) is self-contradicting — formula published while Tuning Knob declares fixed 90 bpm in MVP; also uses `current_health / max_health` as float when PC now enforces `health: int`.
- **W8.** Save-Load `PlayerState` shape verified aligned (`health: int`, `current_state: int`) — no issue (noted per specific ask).
- **W9.** ADR-0003 delegates PlayerState schema — should cross-reference PC + Save-Load GDDs as schema owners.
- **W10.** Signal Bus OQ tracks "32-signal count" (B3 cascade).
- **W11.** No stale `SignalBus` (autoload-name) references in any live GDD — verified.
- **W12.** Localization CSV count: no contradiction spotted; verify against ADR-0004 later.

---

## Game Design Issues

### Blocking 🔴

**🔴 GD-B1. Hidden/scattered difficulty levers violate "Difficulty Selection omitted" claim.**
- `systems-index.md` "Deliberately Omitted Systems" locks Difficulty Tiers as Tier 3 / out-of-scope.
- But PC GDD ships `noise_global_multiplier` with explicit Easy=0.8 / Hard=1.2 semantics.
- Audio GDD ships `clock_tick_enabled` as an accessibility toggle with anxiety framing.
- These are de-facto difficulty levers hiding in accessibility/tuning spaces, scattered across two GDDs, with no owning system and no UI.
- **Fix options**: (a) promote a single "Accessibility Scaling" owner, OR (b) strip Easy/Normal/Hard annotations and keep the knob as a private designer tuning scalar until difficulty is actually scoped.

**🔴 GD-B2. Health economy has no sink closure; OQ-1 blocks ship.**
- PC OQ-1 (regen policy) deferred to Combat & Damage GDD (Not Started).
- MVP has no regen, no medkits, no respawn-heal. Only heal path is dying-via-respawn.
- In a 5-section linear mission, a player at 30 HP with no regen must reload or intentionally suicide to heal. Both violate Pillar 3 (Stealth is Theatre, Not Punishment).
- **Fix**: resolve OQ-1 BEFORE Combat & Damage GDD authoring — decision cascades into Save-Load (CR-4), Failure & Respawn, Stealth AI tuning.

**🔴 GD-B3. Sprint is de-facto dominant in 4/5 Eiffel Tower sections.**
- Walk 3.5 m/s / 5 m noise; Sprint 5.5 m/s / 9 m noise (80% more noise for 57% more speed).
- Per PC AI-R1: noise does NOT propagate cross-floor (NOLF1 precedent = planar attenuation, vertical = 0).
- In a vertical Eiffel Tower mission, Sprint's noise cost is bounded to the current floor; traversal benefit is unbounded.
- No stamina, no cooldown, no animation penalty (Pillar 5 rejected all three).
- Stealth AI (undesigned) cannot rebalance without a PC amendment.
- **Fix options**: (a) add vertical sound propagation stub ("stairwells carry sound"), (b) raise Sprint noise to make it punishing in open rooms, or (c) accept Sprint-dominant and document as intentional.

### Warnings ⚠️

- **GD-W1.** Save-Load 8-slot grid accidentally reads as progression UI. Player-authored chapter ladder emerges from intended mechanics.
- **GD-W2.** Plaza scenario demands 6+ simultaneous audio/visual channels (music, radio chatter, outline hierarchy, guard body language, civilian murmurs, signage outlines). Pillar 5 forbids UI consolidation. Flag Tier 0 playtest for cue-detection measurement.
- **GD-W3.** Crouch dominates Walk — 51% slower but 40% quieter + ceiling-relevant. Walk becomes UX tax. Stealth AI must specify at least one mechanic where Crouch is worse (surface-scrape noise, lower-cover visibility) OR movement trichotomy collapses to Crouch/Sprint.
- **GD-W4.** Document Collection source-only; no re-read/dossier sink specced. Document Overlay UI GDD (unwritten) must explicitly choose dossier-ship or one-and-done.
- **GD-W5.** Pillar 1 Coverage Matrix counts 5 systems as serving Comedy Without Punchlines; 0/5 designed. Matrix gives false confidence. Recommend tri-state tracking (designed / planned / pending).
- **GD-W6.** Audio's "sting on guard head-turn" makes the score the punchline-deliverer — narrator-voiced world. Alignment needed in Dialogue/Subtitles GDD to prevent scripted banter from wink-at-camera drift.
- **GD-W7.** `noise_global_multiplier` applied pre-AI-read — Stealth AI analytics logs mix player preference with designer intent. Store unmultiplied version if analytics needs it.

---

## Cross-System Scenario Issues

**Scenarios walked**: 5
1. Eve sprints across Plaza, lands hard on marble, guard hears
2. Eve is damaged mid-interact and dies
3. Game loaded from mid-mission save
4. Player changes resolution_scale mid-mission
5. Document opened during active combat

### Blockers
**None** — all 5 scenarios complete with defined data flow.

### Warnings ⚠️

- **S1-W (Sprint+land).** Audio world-occlusion (AudioStreamPlayer3D attenuates noise through walls) vs Stealth AI perception-occlusion (PC AI-R1 delegates to Stealth AI) can disagree. Guard alerted without audible cue = "magical" detection. Stealth AI GDD must align its occlusion model with Audio's audible-range model, OR ship a compensating audible cue.
- **S2-W (Die mid-interact).** PC Visual Dead State runs its own 1.5 s sepia fade parallel to `PostProcessStack.enable_sepia_dim` (0.5 s default Tween). Undefined collision if document overlay is active when Eve dies. Delegate death-sepia to Post-Process Stack entirely via a new `request_death_fade(duration_s)` API OR reconcile durations.
- **S3-W (Load save).** `game_loaded` is not a translation-refresh trigger in Localization Scaffold. Cached `tr()` consumers don't re-render post-load. Missing contract in Localization Edge Cases.
- **S4-W (Resolution scale mid-mission).** Settings UI is VS scope (system 23); AC-10.1 runtime-coherence for hands `resolution_scale` (wired via `Events.setting_changed`) cannot be integration-tested at MVP because the trigger UI doesn't exist. Add debug command to force `setting_changed("resolution_scale")` emission.
- **S5-W (Document during combat).** Document overlay during active combat creates contradictory messaging — theatrical pause (overlay sepia + music duck) vs live gunfire (SFX bus unducked). Mission Scripting must choose: block overlay during combat / duck SFX under overlay / accept tension as Pillar 1 absurdism. Resolve before Document Overlay UI GDD authoring.

### Info
- **i1.** Signal Bus ordering unspecified but no ordering-dependent scenarios detected.
- **i2.** Save-Load slot semantics coherent per CR-4.
- **i3.** Outline + Post-Process chain order locked consistently across both GDDs.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `outline-pipeline.md` | B1: add ADR-0005 exception for FPS hands in C.3 + AC-5 | Consistency | Blocking |
| `audio.md` | B2: author Footstep Surface Map + add Player-domain subscriptions; B6 save-chime reconciliation; W7 Formula 4 vs Tuning Knobs | Consistency + Design | Blocking |
| `signal-bus.md` | B3: bump 32→34 signals / 8→9 domains; add Player column to matrix | Consistency | Blocking |
| `player-character.md` | B4 AC-3.4 rewrite (idempotent-read + `_sec`); B5 sweep 2.5°→4.0°; GD-B3 Sprint dominance risk note | Consistency + Design | Blocking |
| `save-load.md` | B6: reconcile save-chime Audio subscription claim | Consistency | Blocking |
| `systems-index.md` | GD-B1: decide difficulty ownership; W6 bump Last Updated | Design | Blocking |
| `adr-0001-stencil-id-contract.md` | Follow-up to B1: cite ADR-0005 exception | Consistency | Warning |
| `entities.yaml` | W3, W4 hygiene | Consistency | Warning |

---

## Verdict: **FAIL**

**6 consistency blockers** (5 propagation failures from the ADR-0002 2026-04-19 Player-domain amendment + ADR-0005 hands exception + Session E-Prime PC edits not fully sweeping through AC tables) + **3 design-theory blockers** (GD-B1 hidden difficulty, GD-B2 health sink closure, GD-B3 Sprint dominance).

None of the blockers are re-design-level. Most critical:
1. **GD-B3 Sprint dominance** and **GD-B2 health sink closure** block Stealth AI and Combat & Damage GDD authoring respectively.
2. **B1–B6 propagation failures** are a ~2-hour sweep across the named GDDs.

### Required actions before re-running `/review-all-gdds`:

1. **Audio GDD**: author `§Footstep Surface Map` (7 surfaces × 3 variants threshold table) + add Player-domain subscription rows (`player_footstep`, `player_interacted`) + reconcile Formula 4 vs fixed-90-bpm Tuning Knob + decide save-chime subscription.
2. **Signal Bus GDD**: bump counts to 34/9; add Player domain row + consumer matrix column.
3. **Outline Pipeline GDD**: carve out ADR-0005 exception for PC hands in C.3 + AC-5; update ADR-0001 "Related" section.
4. **Player Character GDD**: rewrite AC-3.4 (idempotent-read + `spike_latch_duration_sec`); sweep 2.5°→4.0° at `:630` and AC-7.2; add Sprint-dominance risk note in Cross-References.
5. **Save-Load**: reconcile save-chime Audio claim (author the Audio subscription OR strip the cross-ref).
6. **Systems-index**: decide difficulty ownership (promote to named system OR strip Easy/Normal/Hard annotations); bump Last Updated.
7. **PC GDD or systems-index**: resolve OQ-1 (health regen policy) before Combat & Damage GDD authoring.

After these 7 fixes + OQ-1 decision, re-run `/review-all-gdds` (expected PASS) and proceed to `/create-architecture`.
