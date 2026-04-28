# Cross-GDD Review Report — 2026-04-27

**GDDs Reviewed**: 21 system GDDs + game-concept + systems-index + ADR-0001/0002/0003/0004/0006/0007/0008 spot-checks + entity registry baseline + prior review (2026-04-20)
**Systems Covered**: Signal Bus, Input, Audio, Outline Pipeline, Post-Process Stack, Save/Load, Localization Scaffold, Player Character, Footstep Component, Stealth AI, Combat & Damage, Inventory & Gadgets, Civilian AI, Document Collection, Failure & Respawn, Mission & Level Scripting, Level Streaming, HUD Core, Menu System, Settings & Accessibility, Document Overlay UI
**Scope**: full (consistency + design theory + 5 cross-system scenarios). Phase 2 + Phase 3/4 spawned as parallel subagents per skill spec.
**Verdict**: **FAIL** — 13 blocking issues (9 consistency + 4 design theory + 2 scenario blockers); resolvable in a propagation/sweep pass plus 4 scoped design adjudications. None are re-design-level.

---

## Consistency Issues

### Blocking 🔴

**🔴 B1. Signal Bus signal-count drift — three different totals cited (34 / 36 / 38).**
- `signal-bus.md:17` says "36 typed signals across 9 gameplay domains"; lines :40, :48, :137, :165 still say "34"; ADR-0002 line :21 says "38 events"; registry agrees with ADR-0002.
- Root cause: 2026-04-19 Player domain, 2026-04-22 SAI 4th-pass, 2026-04-24 Inventory amendment cascading without full sweep.
- **Fix:** Sweep `signal-bus.md` to 38 (or 39 once `settings_loaded` lands). Update AC-3 + AC-13 + Consumer Matrix.

**🔴 B2. ADR-0007 autoload registry — three GDDs each claim slot #8.**
- `settings-accessibility.md:60` (CR-3): SettingsService at slot #8.
- `failure-respawn.md:271, :309, :494`: F&R at slot #8.
- `mission-level-scripting.md:60` (CR-17), :527, :542, :825: MLS at slot #9 (after F&R at #8).
- `document-collection.md:18, :115, :463, :653, :733`: quotes "F&R = #8, MLS = #9".
- ADR-0007 itself currently has 7 slots; nothing past Combat is registered.
- **Fix:** Single bundled ADR-0007 amendment. Producer + technical-director must adjudicate slot order (likely Events(1)→…→Combat(7)→F&R(8)→MLS(9)→SettingsService(10)). Sweep all 4 GDDs.

**🔴 B3. HUD Core subscribes to wrong category for `crosshair_enabled`.**
- `settings-accessibility.md:185` (CR-2 single-canonical-home): "`accessibility.crosshair_enabled` is the sole canonical key."
- `hud-core.md:62, :99, :117, :153, :244, :527, :587, :697`: 8+ sites still subscribe under `("hud", "crosshair_enabled", _)`.
- Settings line 359 explicitly flags this revision required.
- **Fix:** Sweep hud-core.md to subscribe under `accessibility` category. Update HUD CR-15.

**🔴 B4. menu-system.md uses `Context.MODAL` and `Context.LOADING` enum values input.md doesn't acknowledge.**
- `menu-system.md:55, :117–120, :910` use both freely.
- `input.md:55` flags only `LOADING` as a pending ADR-0004 amendment, not `MODAL`.
- **Fix:** Reconcile pending-amendment list; either input.md adds `MODAL`, or menu-system.md uses an existing context.

**🔴 B5. menu-system.md cites `screen_fade_layer = 1024`; level-streaming.md uses 127.**
- `menu-system.md:1335` (FP-9) — 1024 is impossible (Godot signed 8-bit `CanvasLayer.layer` range −128..127).
- `level-streaming.md:36` (CR-1) — explicit value 127 with rationale.
- **Fix:** Replace 1024 with 127 (or strip the magic number; reference LS CR-1).

**🔴 B6. Audio's `setting_changed` early-return filter drops events it claims to consume.**
- `audio.md:377`: filter returns early if `category != "audio"`.
- `audio.md:237` + Settings line 180: `clock_tick_enabled` lives in the `accessibility` category (moved there 2026-04-27).
- **Fix:** Update filter to allow `audio` OR `accessibility` (with key allowlist).

**🔴 B7. CanvasLayer 10 collision — Settings panel + Cutscenes both claim it.**
- `settings-accessibility.md:238` and Cutscenes references in `document-overlay-ui.md:763`.
- `menu-system.md:1713` (OQ-MENU-15) acknowledges as advisory but provides no formal mutual-exclusion annotation.
- **Fix:** ADR-0004 §IG7 owner annotates layer 10 as "shared between Settings panel and Cutscenes letterbox; mutually exclusive InputContext gates prevent simultaneity." Mirror in both GDDs.

**🔴 B8. Save-Load schema missing `fired_beats` field MLS depends on.**
- `mission-level-scripting.md:40` (CR-7) and 9+ other sites: `MissionState.fired_beats` is load-bearing for savepoint-persistent beats.
- `save-load.md:99` `MissionState` schema: only `section_id`, `objectives_completed`, `triggers_fired`. No `fired_beats`.
- ADR-0003 line :364 schema agrees with save-load.md (no `fired_beats`).
- **Fix:** Add `fired_beats: Dictionary[StringName, bool]` (matching MLS CR-6 type lock) to save-load.md + ADR-0003.

**🔴 B9. ADR-0003 InventoryState ammo schema obsolete vs Inventory + Save-Load.**
- `adr-0003-save-format-contract.md:361` cites single `ammo: Dictionary`.
- `inventory-gadgets.md:249-250` and `save-load.md:102` use `ammo_magazine: Dictionary` + `ammo_reserve: Dictionary` (split during Inventory revision).
- **Fix:** Update ADR-0003 §GDD Requirements row to cite both new fields.

### Warnings ⚠️

- **W1.** ADR-0008 Slot 8 pooled-residual sub-claims: DC CR-15 (`document-collection.md:117`) cites stale CAI 0.15 ms; CAI is now 0.30 ms (`civilian-ai.md:394`). Sub-slot ADR-0008 amendment hasn't landed. Sweep + register.
- **W2.** Slot 7 (UI = 0.3 ms) — Document Overlay claims it "holds it alone" while open, conditional on HUD Core killing Tweens, which HUD Core doesn't yet spec (`document-overlay-ui.md:484` OQ-DOV-COORD-14 vs `hud-core.md:531` OQ-HUD-3). HUD Core needs explicit Tween-cleanup contract on InputContext leaving GAMEPLAY.
- **W3.** Localization Scaffold has no `game_loaded` translation-refresh contract — prior S3-W carryforward; cached `tr()` consumers may keep stale text after locale-crossed load.
- **W4.** `signal-bus.md:64` Settings domain row omits `settings_loaded` (Settings CR-9 pending ADR-0002 amendment). Bundle with B1.
- **W5.** `stealth-ai.md:10` overview prose says "four-state lattice"; enum at :67 has 6 values (UNCONSCIOUS + DEAD added). Cosmetic but a reader-trap.
- **W6.** `civilian-ai.md:132` and Save-Load Interactions table reference `CivilianAIState`; ADR-0003 SaveGame `@export` block (lines 146–151) doesn't list it. Same gap exists for `FailureRespawnState`.
- **W7.** `document-collection.md` 6 sites parenthetically claim "F&R = #8, MLS = #9" — strip the forward-claim (DC is not autoload regardless).
- **W8.** Photosensitivity cooldown name divergence: `hud_damage_flash_cooldown_ms` (Combat/HUD) vs `accessibility.damage_flash_cooldown_ms` (Settings). Harmonize or document the two-name convention.

### Prior-review carryforward (2026-04-20)

| Prior issue | Status | Evidence |
|---|---|---|
| **B1** Outline Pipeline vs PC FPS hands ADR-0005 carve-out | RESOLVED | PC GDD :201, :600 cite the carve-out; review log marks landed. |
| **B2** Audio missing Footstep Surface Map + Player-domain subscriptions | RESOLVED | `audio.md:23, :63, :163, :164, :516-520` add Player-domain subscriptions; §Footstep Surface Map present. |
| **B3** Signal Bus stale "32 signals / 8 domains" | PARTIALLY-RESOLVED → **NEW DRIFT** | Updated to 36 in some sites, 34 in others, 38 in ADR-0002. See current B1. |
| **B4** PC AC-3.4 idempotent-read latch + `_sec` units | RESOLVED | `player-character.md:867` AC-3.4 rewritten; `:355, :696` use `spike_latch_duration_sec`. |
| **B5** PC `turn_overshoot_deg` 2.5°→4.0° sweep | RESOLVED | `:668, :721, :904` all show 4.0°. |
| **B6** Save-Load save-confirm chime / Audio Persistence subscription | RESOLVED | `save-load.md:165, :224` reconciled; `audio.md:29` declares Persistence subscription. |

---

## Game Design Issues

### Blocking 🔴

**🔴 GD-B1. Pillar 4 (Iconic Locations as Co-Stars) is critically thin; the Pillar Coverage Matrix is misleading.**
- `systems-index.md:196` claims 4 systems serve P4: Level Streaming, Mission Scripting, Outline Pipeline, Post-Process Stack.
- Verifying each GDD: only LS (`level-streaming.md:6`) and MLS (`mission-level-scripting.md:6, :20`) actually claim P4 as primary. Outline Pipeline (`outline-pipeline.md:7`) claims P1/3/5; Post-Process Stack (`post-process-stack.md:7`) claims P3/5. Document Collection (`document-collection.md:9`) genuinely supports P4 (Tower-bound furniture) but the matrix omits it.
- Why blocking: P4 is the differentiator in the elevator pitch; matrix gives false confidence. Pillar enforcement collapses onto MLS's per-section authoring as the single bottleneck.
- **Recommendation:** Rewrite `systems-index.md` Pillar 4 row to LS + MLS primary, DC + CAI(MVP chorus) supporting; remove Outline + PPS. Add Pillar 4 hand-off audit (CI: every section scene must contain at least one entity tracing back to a P4 commitment in MLS §C.5). Optionally promote Stealth AI to P4-supporting (vertical line-of-sight is architecture-coupled).

**🔴 GD-B2. Player attention budget at the typical Plaza moment now exceeds the 4-active threshold.**
- 6 simultaneously active decision channels in MVP: PC noise/silhouette, SAI alert (audio), Inventory cycle, DC pickup-prompt, HUD Core interact-prompt, CAI panic threat (Plaza 4–6 civilians). Plus Audio dynamic-music as a passive channel.
- Pillar 5 forbids UI consolidation; channels compete for ear/eye bandwidth.
- Prior GD-W2 already flagged 6+ channels; new GDDs (HUD Core, Doc Overlay, CAI, Settings) compound it.
- **Recommendation:** Add a per-section attention budget appendix to systems-index.md. Plaza is the tutorial — consider deliberately suppressing CAI panic triggers + DC off-path docs there until Lower Scaffolds (push GD-W2 from advisory to a sectional-onboarding requirement in MLS §C.9). OR accept compound count and instrument Tier-0 cue-detection telemetry.

**🔴 GD-B3. Inventory's "Pre-Packed Bag" fantasy structurally conflicts with Mission Scripting's mission-pickup placement.**
- `inventory-gadgets.md:20` — "Eve does not scavenge her identity" / Bureau already predicted it.
- `mission-level-scripting.md:46` (CR-10) — rifle-carrier-per-section + Parfum-Restaurant off-path caches authored by level designers.
- The pickup verb is identical; player can't tell "pre-packed" from "found." Two Inventory load-bearing pillars (5 + 2) pull against each other through the same interact-pickup.
- **Recommendation:** (a) Carve out off-path caches as visibly Bureau-dispatched ("Bureau dispatch — cache validated"). (b) Demote Pre-Packed Bag from primary fantasy to Mission-1 cold-open framing only. (c) Re-route off-path caches as ammo-only — preserves the bag's *shape* even if contents refill. Combat-aligned NOLF1 model; cleanest fix.

**🔴 GD-B4. Health regen sink closure (prior GD-B2) is partially closed — sources are front-loaded and can starve late mission.**
- `player-character.md:24` reports OQ-1 closed ("diegetic medkits only"). Inventory caps at 3 medkits/mission. MLS authors 3 medkit caches.
- 3 medkits across a 2–4 hour 5-section mission means a player damaged in Lower Scaffolds + Restaurant has no budget for Upper Structure → Bomb Chamber. Pillar 3 breaks: low HP into final section forces save-scumming.
- F&R restores ammo via floor (CR-5) but not health; sectional respawn restores 100 HP only on death.
- **Recommendation:** (a) per-section medkit budget (1 guaranteed past Plaza), (b) section-entry-on-FORWARD partial heal (+20 HP, capped under 80, "Eve catches her breath"), or (c) accept-as-designed and add explicit playtest evidence to F&R AC.

### Warnings ⚠️

- **GD-W1.** Sprint-vs-Walk noise dominance (prior GD-B3) **STILL-OPEN** — `player-character.md:86` keeps Sprint at 12 m noise vs Walk 5 m; vertical-propagation rule still not visible. Close with one of: vertical sound propagation stub / raise Sprint noise / explicit "intentional dominance" doc.
- **GD-W2.** Crouch-dominates-Walk (prior GD-W3) **STILL-OPEN** — no mechanic where Crouch costs more than Walk. Stealth AI must specify (surface-scrape / lower-cover visibility) OR PC adds ceiling-mantle penalty.
- **GD-W3.** Document-overlay-during-combat — `document-overlay-ui.md` CR-2-bis trip conditions reasonable but require Tier-0 instrumentation that doesn't exist yet.
- **GD-W4.** CAI MVP delivers panic substrate only; Pillar 1 chorus comedy is VS-tier. Tier-0 playtest will not have the felt fantasy. Flag in matrix.
- **GD-W5.** Eve identity drift across 6 framings — Deadpan Witness / cockpit-dial pilot / stage manager / Case Officer / Lectern Pause reader / Pre-Packed Bag. Settings is non-diegetic; Menu System is fully diegetic Case File. Player-as-case-officer (Menu) and player-as-Eve (PC/HUD/Inventory) are different POVs. Creative-director adjudicate: collapse Menu's framing OR accept dual-POV explicitly.
- **GD-W6.** Pillar 1 Coverage Matrix tri-state tracking (prior GD-W5) **STILL-OPEN** — 2 of 5 P1 systems unauthored (Dialogue, Cutscenes); CAI chorus is VS-deferred. Adopt designed/planned/pending tracking.
- **GD-W7.** `damage_flash_enabled = false` removes a load-bearing P3 cockpit-dial cue. Without Enhanced Hit Feedback as MVP substitute, photosensitive players fight combats with degraded feedback. Promote EHF to MVP.
- **GD-W8.** Document overlay sepia-dim conflicts with PC death sepia (prior S2-W carryforward, now upgraded). Two sepia sources can fire same frame. Either Doc Overlay CR-12 gates on `Events.player_died` OR PPS adopts stack-of-requesters pattern.
- **GD-W9.** Difficulty curve compounds in Restaurant — peaks for documents (6) AND civilians (6–8) AND confined geometry simultaneously. Then Upper Structure adds vertical traversal + 5 docs. Rebalance (Restaurant 5 / Upper 6) OR accept Restaurant as documented difficulty peak.

### Prior-review carryforward (2026-04-20)

| Item | Status | Evidence |
|---|---|---|
| GD-B1 hidden difficulty | RESOLVED | `systems-index.md:211` clarifies `noise_global_multiplier` + `clock_tick_enabled` are dev/accessibility scalars; new GDDs (Settings) follow this. |
| GD-B2 health regen sink closure | PARTIALLY | OQ-1 reports closed (PC GDD); per-section refill not specified — see new GD-B4. |
| GD-B3 Sprint dominance | STILL-OPEN | PC GDD still 12 m / 5 m; no vertical-propagation rule visible — see new GD-W1. |
| GD-W1 8-slot save grid as progression UI | RESOLVED | Save/Load CR-10 + Menu System Case File register reframes slots as Dispatches. |
| GD-W2 Plaza simultaneous channels | STILL-OPEN | Now compounded by HUD Core / Doc Overlay / CAI shipping — see new GD-B2. |
| GD-W3 Crouch-dominates-Walk | STILL-OPEN | No mechanic surfaced where Crouch is worse — see new GD-W2. |
| GD-W4 Document dossier-vs-one-and-done | RESOLVED | DC §E.12 + Doc Overlay GDD explicitly defer the case-file archive to Polish. |
| GD-W5 Pillar 1 tri-state tracking | STILL-OPEN | systems-index.md still uses simple count — see new GD-W6. |
| GD-W6 Audio sting-as-narrator | PARTIALLY | Audio GDD R-9 SCRIPTED-cause stinger suppression closes guard-reaction stings; Dialogue still unwritten. |
| GD-W7 noise_global_multiplier analytics | STILL-OPEN | No analytics-side decision visible. |

---

## Cross-System Scenario Issues

**Scenarios walked: 5**
1. Plaza tutorial pickup with guard nearby
2. Mid-combat document-pickup attempt
3. Post-takedown civilian witness cascade (MVP and VS)
4. Mid-section quicksave/quickload roundtrip
5. Section transition during chase + locale change while document overlay open

### Blockers 🔴

**🔴 S1-B. Plaza pickup — HUD Core hides mid-damage-flash if pickup happens while taking damage.**
- Step: Document Overlay opens → InputContext ≠ GAMEPLAY → HUD Core hides (visibility false); same frame `player_damaged` fires → photosensitivity rate-gate timer queues a flash that may render against hidden widget; on overlay close the queued flash may render immediately (potentially exceeding 333 ms WCAG floor) OR be silently dropped.
- **Resolution:** HUD Core GDD specifies `_pending_flash` cleanup on InputContext leaving GAMEPLAY. Either (a) cancel pending flashes, or (b) buffer + re-evaluate on return-to-GAMEPLAY against the 333 ms floor.

**🔴 S2-B. Mid-combat document overlay creates an opaque "is the player paused?" state for AI.**
- Step: Combat returns early on `_unhandled_input` InputContext gate; AI's `_physics_process` runs unmodified; civilians continue panic; guards continue firing. Player can die at 0 HP while reading.
- Failure mode: contradictory messaging — Lectern Pause demands theatrical pause; live combat demands accountability.
- **Resolution:** Doc Overlay UI's CR-2-bis (Option A-delayed) becomes MVP default, not fallback. OR MLS blocks doc pickup when any tracked guard is in `AlertState.COMBAT`. OR PC auto-dismisses overlay on `player_damaged`.

### Warnings ⚠️

- **⚠️ S3-W.** CAI MVP doesn't subscribe to `takedown_performed` — civilians ignore knockouts within line of sight. Either add at MVP scope or document the Plaza tutorial authoring constraint (no civilians within LoS of takedown opportunities).
- **⚠️ S4-W.** `game_loaded` is still not a Localization re-render trigger (carryforward of prior S3-W). Either Localization §C.5 adds `game_loaded` as a TR_CHANGED trigger, or each consumer (HUD Core mirror cache) subscribes manually.
- **⚠️ S5-W.** Document Overlay teardown vs locale-change race during section-unloading is defined but untested. Add explicit AC: "locale change during section_unloading collapses correctly to closed state."
- **⚠️ S5-W2.** Guard chase that crosses section boundary loses alert state (drops chase narrative). Confirm with creative-director that this is intentional; if so, document in Stealth AI Pillar 3 narrative section.

### Info

- **ℹ️ i1.** Audio's `game_saved` subscription claim (prior B6) needs re-verification — sample didn't show explicit `game_saved` chime handler.
- **ℹ️ i2.** Save/Load CR-7 ("CAN save during active combat") + Document Overlay's combat-time behavior together create save-scum vector for stealth puzzles. Acceptable per Pillar 2; flag for QA.
- **ℹ️ i3.** ADR-0004 Proposed → Accepted promotion is a hard pre-impl gate referenced by Input, HUD Core, Doc Overlay, Menu System, and Settings — single dependency choke point.
- **ℹ️ i4.** F&R's `respawn_triggered` re-entrancy fence (CR-8) is well-specified but not yet enforced by CI lint per AC-FR-12.4.

---

## Pillar Alignment Matrix (Phase 3f)

| System | P1 Comedy | P2 Discovery | P3 Theatre | P4 Locations | P5 Period | Concern |
|---|---|---|---|---|---|---|
| signal-bus | — | — | Sup | — | Sup | — |
| input | — | — | Sup | — | **Pri** | — |
| audio | **Pri** | — | **Pri** | Sup | **Pri** | — |
| outline-pipeline | Sup | Sup | **Pri** | — | Sup | matrix mis-attribution |
| post-process-stack | — | — | **Pri** | — | **Pri** | matrix mis-attribution |
| save-load | — | Sup | **Pri** | — | Sup | — |
| localization-scaffold | — | — | — | — | Sup | — |
| player-character | **Pri** (deadpan) | — | **Pri** | — | **Pri** | — |
| footstep-component | — | — | Sup | — | **Pri** | — |
| stealth-ai | Sup | — | **Pri** | — | Sup | — |
| combat-damage | Sup | **Pri** | **Pri** | — | **Pri** | watch fists Matt-Helm |
| inventory-gadgets | Sup | **Pri** | Sup | — | **Pri** | GD-B3 bag-vs-cache |
| civilian-ai | **Pri** (MVP chorus) | Sup (VS) | Sup (VS) | Sup | **Pri** | GD-W4 VS-deferred |
| document-collection | Sup (typo) | **Pri** | — | Sup | **Pri** | matrix omission |
| failure-respawn | — | Sup | **Pri** | — | **Pri** | — |
| mission-level-scripting | **Pri** | Sup | Sup | **Pri** | **Pri** | — |
| level-streaming | — | — | **Pri** | **Pri** | **Pri** | — |
| hud-core | Sup | **Pri** (no waypoints) | Sup | Sup | **Pri** | — |
| menu-system | **Pri** (Case File) | — | Sup | — | **Pri** | GD-W5 POV drift |
| settings-accessibility | Sup (restraint) | — | Sup | — | **Pri** (carve-out) | GD-W7 EHF MVP |
| document-overlay-ui | Sup (typo) | **Pri** | **Pri** | — | Sup | — |

**Primary tally:** P1=4, P2=5, P3=8, **P4=2** (thin), P5=11.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| `signal-bus.md` | B1 sweep 34→38 (4 sites); W4 add `settings_loaded` | Consistency | Blocking |
| `settings-accessibility.md` | B2 slot #8 conflict; B7 layer 10 annotation; W8 cooldown name | Consistency | Blocking |
| `failure-respawn.md` | B2 slot #8 bundle; W6 FailureRespawnState in SaveGame | Consistency | Blocking |
| `mission-level-scripting.md` | B2 slot #9 bundle; B8 `fired_beats` schema | Consistency | Blocking |
| `hud-core.md` | B3 crosshair category sweep (8 sites); W2 Tween-kill contract; S1-B pending-flash cleanup; GD-B2 attention budget | Consistency + Design | Blocking |
| `menu-system.md` | B4 `Context.MODAL` enum; B5 fade layer 1024→127; B7 layer 10 annotation; GD-W5 POV adjudication | Consistency + Design | Blocking |
| `input.md` | B4 add `MODAL` to pending amendment list | Consistency | Blocking |
| `audio.md` | B6 filter early-return rule | Consistency | Blocking |
| `save-load.md` | B8 add `fired_beats`; W3 game_loaded translation refresh | Consistency | Blocking |
| `adr-0003-save-format-contract.md` | B9 ammo schema; W6 add CivilianAIState + FailureRespawnState | Consistency | Blocking |
| `adr-0007-autoload-load-order-registry.md` | B2 single bundled amendment | Consistency | Blocking |
| `inventory-gadgets.md` | GD-B3 Pre-Packed Bag vs caches adjudication | Design | Blocking |
| `combat-damage.md` | GD-B4 medkit budget + section-entry heal | Design | Blocking |
| `player-character.md` | GD-W1 Sprint dominance closure; GD-W2 Crouch-vs-Walk closure | Design | Warning |
| `systems-index.md` | GD-B1 Pillar 4 matrix correction; GD-B2 attention budget appendix; GD-W6 tri-state tracking | Design | Blocking |
| `document-overlay-ui.md` | W1 budget math sweep; S2-B CR-2-bis promotion to MVP; GD-W8 sepia stack | Consistency + Design | Blocking |
| `document-collection.md` | W7 strip stale slot parenthetical (6 sites) | Consistency | Warning |
| `civilian-ai.md` | W1 ADR-0008 amendment; W6 SaveGame field; S3-W takedown subscription | Consistency + Design | Warning |
| `localization-scaffold.md` | W3/S4-W game_loaded trigger | Consistency | Warning |
| `stealth-ai.md` | W5 4-state vs 6-state framing; GD-W2 Crouch-vs-Walk owner | Consistency + Design | Warning |

---

## Verdict: **FAIL**

13 blocking issues across consistency (9), design theory (4), and scenarios (2). Pattern is the same as 2026-04-20: most are **propagation failures** from in-flight ADR amendments not landing, plus 4 scoped design adjudications that need creative-director and producer sign-off. None require re-design.

### Required actions before re-running `/review-all-gdds`:

**Top urgency cluster (do first):**
1. **B2 + ADR-0007 amendment** — single bundled adjudication unblocks 4 GDDs.
2. **B1 Signal Bus sweep** — 4-site sweep + amendment for `settings_loaded`.
3. **B3 + B6 + S1-B** — three category/filter sweeps in HUD Core / Audio / HUD-state-on-context-change.
4. **GD-B1 Pillar 4 matrix correction** — single edit to systems-index.md prevents future false-confidence reviews.
5. **GD-B3 Inventory Pre-Packed Bag adjudication** — creative-director call; option (c) ammo-only caches is the cleanest.
6. **S2-B + GD-W3 Doc Overlay during combat** — promote CR-2-bis to MVP default OR MLS blocks pickup during COMBAT.

Once these land, the 7 Warning-tier carryforwards (GD-W1 Sprint, GD-W2 Crouch, GD-W6 Pillar 1 tri-state) and the propagation Warnings (W1–W8) can be addressed in a single sweep PR. Re-run `/review-all-gdds` after the bundled amendment + sweeps.
