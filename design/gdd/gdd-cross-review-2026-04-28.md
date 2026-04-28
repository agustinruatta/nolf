# Cross-GDD Review Report — 2026-04-28

**Date**: 2026-04-28
**Trigger**: `/review-all-gdds` (full mode — both consistency and design-theory passes + cross-system scenario walks)
**Reviewer**: Producer (synthesis) — Phase 2 by general-purpose agent, Phase 3 by game-designer agent, Phase 4 walked by producer
**GDDs reviewed**: 21 active system GDDs (frozen baseline `player-character-v0.3-frozen.md` excluded by design)
**Prior reviews considered**: 2026-04-20 (B-tier carryforward) and 2026-04-27 (W-tier carryforward)

---

## Verdict: **CONCERNS**

- **9 BLOCKING** items (all addressable through targeted sweeps + 3 ADR amendments + 2 small design decisions)
- **13 WARNINGS**
- **8 INFO**

No FAIL, because no GDD is structurally broken. The pattern is **drift between corrected sites and uncorrected sites** (multiple ADR amendments landed but downstream GDDs only partially swept), plus two design holes (mid-mission medkit budget, fist noise event) that need a small explicit decision rather than rework. Architecture work can proceed in parallel with sweep work, but **ADR-0002, ADR-0004, and ADR-0008 amendments should land before MVP sprint planning ships.**

---

## Section 1 — Cross-GDD Consistency (Phase 2)

### 1a: Dependency Bidirectionality

- **⚠️ Inventory's Save/Load callback path is asymmetric.** `inventory-gadgets.md:508` and `:874` still describe registration as `SaveLoad.register_restore_callback(_serialize_inventory)`, while CR-11 elsewhere in the same file (`inventory-gadgets.md:259`) and `save-load.md:102` correctly attribute the API to `LevelStreamingService.register_restore_callback(...)`. The `save-load.md` Downstream-Dependents row only says "Passive". **Resolution**: rewrite Inventory:508/:874 to LSS; expand Save/Load Inventory row to cite LS CR-2.

- **🔴 CivilianAI claims per-civilian `LevelStreamingService.register_restore_callback` registration, but neither LS GDD nor MLS GDD lists CAI as a registered caller.** `civilian-ai.md:132` (CR-10) says each civilian self-registers in `_ready()`. `level-streaming.md:55` enumerates only "Mission Scripting, Failure & Respawn, Menu System — one callable each", and `mission-level-scripting.md:496` repeats that list. The DC GDD's revision explicitly retracted "DC self-registers" in favor of MLS-orchestrated `restore()` (`document-collection.md:8`). CAI's per-civilian self-register contradicts that orchestration pattern by 4–8× per section. **Resolution (design call)**: pick one authoritative pattern. Either (a) document the per-civilian self-register as an explicit exception in LS CR-2 with replace-semantics + use-after-free guard already present in CAI CR-10, OR (b) move CAI restore through MLS like DC. (a) keeps CAI's E.11 race-free claim valid; (b) keeps the LSS callback registry small and bounded.

- **⚠️ HUD's `ui_context_changed` subscription is declared in HUD but not in ADR-0002 taxonomy.** `hud-core.md:61, :115, :249, :595, :1078, :1148` treat `ui_context_changed` as part of the HUD's 9-signal bus subscription (CR-1 + AC-HUD-1.1). `signal-bus.md:64` Settings/Mission/UI domain rows do NOT include it; `signal-bus.md:219` and `adr-0002-...md:492` still list `ui_context_changed` as a hypothetical "if needed" addition. **Resolution**: bundle the `ui_context_changed` ADR-0002 amendment with the `settings_loaded` amendment (W4 carryforward). OR retire HUD's CR-10 signal-driven contract in favor of polling `InputContext.current()` at a single re-render hook.

### 1b: Rule Contradictions

- **🔴 ADR-0002 §Decision and §Migration Plan say "36 events / 34 signals"** despite the Revision History at `:68` saying "Signal count grows 36 → 38". `:155, :455, :362, :468` all carry stale numbers; `signal-bus.md:17` and AC-3 are correctly canonicalized to 38. **Resolution**: sweep ADR-0002 §Decision + §Migration Plan + §Validation Criteria to 38 (or 39 once `settings_loaded` is added).

- **🔴 menu-system.md publishes a wrong autoload slot order that contradicts ADR-0007's amended canonical table.** `menu-system.md:136` lists *"Slot 1 Signal Bus → Slot 2 InputContextStack → Slot 3 SaveLoad → Slot 4 LevelStreamingService → Slot 5 FailureRespawn → Slot 6 MissionScriptingService → Slot 7 FontRegistry → Slot 8 SettingsService"*, and ~10 sites including `:985, :1015, :1057, :1070, :1484, :1697` repeat "SettingsService at slot 8" / "8 autoload `_ready()` calls". ADR-0007 §Canonical Registration Table (authoritative) has 10 entries with `Events(1) → EventLogger(2) → SaveLoad(3) → InputContext(4) → LevelStreamingService(5) → PostProcessStack(6) → Combat(7) → FailureRespawn(8) → MissionLevelScripting(9) → SettingsService(10)`. FontRegistry is **not an autoload** per ADR-0004 §FontRegistry. **Resolution**: sweep all ~10 sites to "per ADR-0007"; remove FontRegistry from any autoload enumeration; add menu-system.md to ADR-0007 §Downstream sites (currently absent).

- **🔴 Inventory CR-11 vs Inventory:508/:874** — three contradictory claims about which autoload owns `register_restore_callback`. Authoritative source is `level-streaming.md:46` (`func register_restore_callback(callback: Callable)` is a method on `LevelStreamingService`). **Resolution**: sweep lines 508 + 874 of `inventory-gadgets.md` to match the corrected line 259 wording.

- **🔴 Document Overlay UI's Slot-7 sole-occupant claim depends on a HUD Tween-cleanup contract that HUD Core does not specify.** `document-overlay-ui.md:484` (OQ-DOV-COORD-14) states HUD Core must kill/pause tweens on `InputContext` change to non-GAMEPLAY. Without that, HUD's Slot-7 contribution is non-zero during overlay open and Overlay's CR-14 "holds full Slot 7 cap alone" claim is invalid. `hud-core.md:62, :115` only specifies `hud_root.visible = false` on `ui_context_changed` — Tween nodes continue running on hidden `Control` children in Godot. AC-DOV-9.2 (`document-overlay-ui.md:1148`) treats Slot-7 as exclusively held during READING. **Resolution**: add an explicit CR to `hud-core.md` requiring `Tween.kill()` on every active widget tween when `ui_context_changed` leaves GAMEPLAY, OR rewrite Overlay's CR-14 to budget for HUD's residual cost.

- **⚠️ Overlay HUD-hide gate is "pending OQ-HUD-3 verification" in DOV but documented as load-bearing in HUD.** `document-overlay-ui.md:13, :77` say HUD hides via "HUD CR pending OQ-HUD-3 verification". `hud-core.md:62, :115` make CR-10 normative. **Resolution**: HUD Core should drop the OQ-HUD-3 conditionality on the `InputContext != GAMEPLAY` hide rule and elevate it to a closed CR; Overlay should drop the "pending verification" qualifier.

### 1c: Stale References

- **⚠️ `civilian-ai.md:573` cites the obsolete CAI 0.15 ms ADR-0008 sub-claim, while `:394, :398, :659` raise it to 0.30 ms p95.** Internal contradiction. `document-collection.md:117, :489, :699, :813, :847` repeat the stale "CAI 0.15 ms" enumeration when listing the Slot-8 pool sharing. **Resolution**: in CAI sweep both internal sites + tuning row to 0.30 ms; sweep DC's six "joins CAI 0.15" enumerations to "joins CAI 0.30".

- **⚠️ ADR-0008 §Risks autoload-cascade row still says "7 autoloads" / "5–15 ms Vulkan + 5–10 ms additional D3D12".** `adr-0008-...md:181, :248, :119` budget the autoload cascade against 7 autoloads (Combat-amendment era, not the 2026-04-27 F&R + MLS + SettingsService amendment). ADR-0007 §Performance Implications memory row was updated to 10; ADR-0008 wasn't. **Resolution**: ADR-0008 §Non-Frame Budgets row + Risk row swept to 10 autoloads.

- **⚠️ `hud-core.md:319` says "ADR-0007 caps autoloads at 7 (Combat took the last slot)"** — current count is 10. **Resolution**: rewrite to "per ADR-0007".

- **⚠️ `hud-core.md:587` Settings & Accessibility row still says "Must emit `setting_changed("hud", _, _)`"** — but Settings GDD CR-2 + line 185 makes `accessibility` the sole canonical home for `crosshair_enabled` etc. Likewise `hud-core.md:697` still mentions a "`Settings → HUD → Crosshair`" UI path. **Resolution**: replace `"hud"` with `"accessibility"` at lines 587 and 697.

- **⚠️ `signal-bus.md:64` Settings domain row omits `settings_loaded` — W4 carryforward.** Settings CR-9 (`settings-accessibility.md:91, :221`) declares `Events.settings_loaded()` as a one-shot, but it is absent from ADR-0002 §Key Interfaces and from the signal-bus.md domain table. ADR-0007 §Canonical Registration Table line 10 footnote already calls out this as "pending ADR-0002 amendment per W4". **Resolution**: ADR-0002 amendment to add `signal settings_loaded()` (no payload); sweep `signal-bus.md:64` Settings row; recount to 39.

- **⚠️ `inventory-gadgets.md:3, :14` revision-trail header says "ADR-0007 caps the autoload registry at 7 entries and Combat took the last slot".** Same stale-claim pattern as HUD. **Resolution**: sweep to "per ADR-0007".

- **ℹ️ `level-streaming.md:284, :354, :420, :589` still flag OQ-LS-9 as "godot-specialist verification of Godot 4.6 `CanvasLayer.layer` max-value".** ADR-0007 amendment 2026-04-27 confirmed verification implicitly via specialist consultations for layer 127. Editorial debt; not a contradiction. **Resolution**: close OQ-LS-9 or document specialist confirmation.

### 1d: Ownership Conflicts

- **⚠️ ADR-0008 Slot 8 (0.8 ms pooled residual) is over-subscribed at the panic-onset frame.** Current sub-claims: CAI 0.30 ms p95 (`civilian-ai.md:394`), MLS 0.1 ms steady-state + 0.3 ms peak (`mission-level-scripting.md:528`), DC 0.05 ms peak (`document-collection.md:117`), F&R "~0 ms outside flow" (`failure-respawn.md:272`), Dialogue & Subtitles unspecified, Signal-Bus dispatch overhead unspecified. Sum of registered sub-claims at steady state ≈ 0.45 ms (within budget); but `civilian-ai.md:388` itself acknowledges that an 8-civilian panic-onset frame ≈ 896 µs alone, before MLS / DC / Dialogue / F&R / Signal-Bus claim their share of the same frame. ADR-0008 has not been amended to register the per-system sub-slots or the panic-onset reserve allocation. **Resolution**: ADR-0008 amendment registering each sub-claim, OR escalation to producer per `civilian-ai.md:398`.

- **⚠️ Audio Documents-domain dB-semantic ownership flagged ADVISORY-DC-AUD-1 in DC, uncorrected on Audio side.** `document-collection.md:507, :704, :720, :937` repeatedly declare `audio.md:95` (DOCUMENT_OVERLAY −10 dB / −20 dB absolute) and Formula 1 line 255 (−8 dB additional VO duck) as needing audio-side clarification. The two semantics aren't strictly contradictory but they collide at the same state. **Resolution**: Audio author edit per the DC-side annotation.

- **ℹ️ CanvasLayer 10 collision (Settings panel + Cutscenes letterbox)** — formally resolved in ADR-0004 §253 (mutually exclusive InputContext gates) and Menu System OQ-MENU-15 acknowledges this. No outstanding conflict, but Cutscenes & Mission Cards GDD is still unauthored, so the "cutscene InputContext" referenced as the gate has no binding declaration yet.

### 1e: Formula Range / Compatibility Mismatches

- **🔴 ADR-0008 sum-of-claims at the panic-onset frame exceeds Slot 8's 800 µs cap by the GDD's own math.** `civilian-ai.md:388` quantifies the panic-onset frame at ~896 µs (8 civilians × (20 + 80 + 12) µs) without RVO; the same paragraph admits this exceeds the pool. Resolution path indicated by the GDD ("allocated against ADR-0008 §F.3 reserve [1.6 ms]") requires an ADR-0008 amendment that has not landed. **Resolution**: amend ADR-0008 reserve allocation, OR reduce N_active_max below 8 at Restaurant, OR cap concurrent panic transitions at 4 with a 1-frame stagger.

- **⚠️ Document-Collection F.1 worst-case at N_subscribers = 6 yields ~0.070 ms — already breaches its own 0.05 ms sub-claim.** `document-collection.md:531, :630, :718, :1235` enumerate this as E.32 with mitigation = `CONNECT_DEFERRED` on Audio + HSS. The mitigation is annotated but no integrating GDD (Audio, HSS) actually declares the deferred-connect. **Resolution**: Audio GDD declares deferred-connection on `document_collected` if/when N_subscribers grows, OR cap subscriber count at 5 in the Signal Bus consumer matrix.

### 1f: Acceptance Criteria Contradictions

- **🔴 AC-MENU-1.1 vs ADR-0007 Gate 1.** AC-MENU-1.1 (`menu-system.md:1484`) explicitly tests "8 autoload `_ready()` calls in ADR-0007 slot order (slots 1 through 8, including SettingsService at slot 8)". ADR-0007 Gate 1 wants 10 entries. Both cannot pass. **Resolution**: rewrite AC-MENU-1.1 to "10 autoload `_ready()` calls in ADR-0007 canonical order"; remove SettingsService-at-slot-8 specific assertion (cite ADR-0007 instead).

- **⚠️ HUD AC-HUD-1.1 vs Signal-Bus AC-3.** AC-HUD-1.1 (`hud-core.md:1078`) asserts 9 Events bus connections including `ui_context_changed`; Signal-Bus AC-3 (`signal-bus.md:179`) asserts the project's Events.gd is parsed against ADR-0002's 38-signal canonical list (which does NOT include `ui_context_changed`). A test enforcing AC-HUD-1.1 will fail under AC-3 enforcement until the ADR-0002 amendment lands. **Resolution**: bundle the `ui_context_changed` ADR-0002 amendment with the `settings_loaded` amendment.

### 1g: ADR ↔ GDD Divergence

- **🔴 ADR-0004 InputContext enum is missing `MODAL` and `LOADING`.** `adr-0004-ui-framework.md:189` lists `{GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, SETTINGS}`. `menu-system.md:55, :117–120, :910`, `failure-respawn.md`, `level-streaming.md`, `input.md:55, :220` all use `Context.MODAL` and `Context.LOADING` freely. The prior review's B4 is unresolved. **Resolution**: ADR-0004 amendment adding `MODAL` and `LOADING` enum values + their push/pop contracts; sweep enum literal references after amendment lands.

- **⚠️ ADR-0003 vs F&R `FailureRespawnState` schema additivity.** `failure-respawn.md:48` (CR-6) says the resource is "forward-extensible (Resource additivity) — `checkpoint_id: StringName` or `Dictionary[StringName, bool]` may be added post-MVP when Mission Scripting introduces mid-section checkpoints; no FORMAT_VERSION bump required under ADR-0003's additive-field rule." ADR-0003 §Implementation Guidelines does not codify the additive-field rule against FORMAT_VERSION. **Resolution (needs human verification)**: either ADR-0003 explicitly endorses additive-field-no-bump, OR F&R retracts the additivity claim.

- **⚠️ ADR-0007 IG7 forbids restating slot numbers in GDDs; multiple GDDs are still in violation.** `menu-system.md` (~10 sites) is conspicuously absent from ADR-0007 §Downstream sites; `settings-accessibility.md:194-202` still has an ASCII diagram with explicit slot numbers (1-10). **Resolution**: add `menu-system.md` and `settings-accessibility.md` to ADR-0007 §Downstream sites; sweep both.

---

## Section 2 — Game Design Holism (Phase 3)

### 2a: Progression Loop Competition

**No competing progression loops.** The document/mission spine remains the sole progression vector. The anti-pillar prohibition on XP, skill trees, currency, and crafting is universally honored across all 21 GDDs.

The one structural tension worth noting is not a competing loop but a **loop coherence gap** that was already resolved: Inventory + MLS create an implicit resource-accumulation arc as Eve finds caches, which reads as de-facto progression even without XP. The GD-B3 prior-review resolution (Option C — only ammo and medkits in off-path caches; gadgets are pre-packed or single special-case) is correctly in place.

### 2b: Attention Budget

Active systems during the 30-second core loop (observe → move → act → listen):

| # | System | Channel | Active/Passive |
|---|---|---|---|
| 1 | Stealth AI awareness | Guard position, facing, audible alert state | **Active** every step |
| 2 | PC noise/silhouette management | Walk/Crouch/Sprint choice | **Active** every step |
| 3 | Inventory selection / ammo state | Weapon slot, ammo count | Semi-active (spikes during encounters) |
| 4 | Document spotting | Stencil Tier 1 outline scan | Passive → active on room entry |
| 5 | Civilian-witness avoidance (Plaza, Restaurant) | Civilian proximity, panic radius | **Active** in sections 1 + 3 |
| 6 | HUD Core readout | Cockpit-dial peripheral glance | Passive by design |
| 7 | Audio dynamic-music tracking | Alert-state music transitions | Passive substrate |

**Verdict**: 4 simultaneously active channels in normal Plaza play — at the comfortable ceiling. **Restaurant section spikes to 5** (channels 1+2+3+4+5 all active or repeatedly spiking). Channel 4 (document spotting) spikes hardest in Restaurant because it has the highest document density (6 docs).

GD-W9 from prior review (Restaurant attention spike) remains open; no GDD has implemented the Restaurant 5 / Upper 6 redistribution.

### 2c: Dominant Strategy Detection

- **⚠️ Crouch dominates Walk as the unchallenged stealth verb** (GD-W2 carryforward). Walk: 3.5 m/s, 5 m noise radius, 1.0 m silhouette. Crouch: 1.8 m/s, 3 m noise radius, 1.0 m silhouette. Crouch costs 49% speed but gains a smaller noise radius AND lower silhouette AND access to low-cover navigation. There is no scenario in active stealth play where Walk is strictly better. Recommendation: SAI/PC GDDs should specify either a surface-scrape penalty at low ground clearance, a vision-cone acceptance change for crouching-behind-cover, OR an explicit decision document that "Crouch dominance is the NOLF1 baseline and intended."

- **🔴 Fist-KO creates a cost-free non-lethal verb if fist swings produce no noise event.** Combat CR-7 specifies the 3-swing 2.1 s cycle and `fist_base_damage = 40` (3 swings vs 100 HP guard works). Drop table correctly awards 0 darts on fist-KO (anti-farm invariant LOCKED). However: **fist swings do not have an assigned noise event in any GDD.** If silent, a patient player can sequentially fist-KO every isolated guard with zero resource cost, no ammo depletion, and no clock pressure — bypassing the dart economy that Pillar 2 leans on. **Resolution**: assign `MELEE_FIST` a 2–3 m noise radius (between Crouch 3 m and Walk 5 m), audible to adjacent guards but not through walls. Specify in Combat §CR-7 + Audio §Concurrency table.

- **⚠️ Headshot economy potentially breaks ammo scarcity.** Combat CR-11 establishes the silenced pistol as net-negative (3 rounds dropped, 3-shot body TTK = +0). Combat §B.1 specifies 2× headshot damage. A skilled player landing reliable 2-shot headshot KOs (1 head + 1 body = 70 + 35 ≈ 105 HP at ~35 HP/round) consumes 2 rounds per kill, drops 3, **net +1**. This is a soft dominant strategy at higher skill levels. **Resolution**: either drop-cap (max 2 rounds dropped per kill regardless of lethality), OR explicit decision that headshot economy break is an acceptable skill-ceiling expression of Pillar 2's mastery-as-progression intent.

- **No dominant strategy** between dart gun vs silenced pistol. The dart gun (non-lethal, 1-shot KO, dart-KO net 0 darts, no body risk) and the pistol (lethal, 3-shot TTK, net-negative economy) serve genuinely different scenarios because UNCONSCIOUS guards wake at 45 s and re-enter play; DEAD guards do not. Interplay is well-designed.

- **No dominant strategy** between document patience vs speedrun. MLS §CR-21 mandates a Discovery Surface guarantee per section, ≥75% off-path (DC §C.5 CR-9), Tier 1 outlines, and the Pillar 2 design test holds.

### 2d: Economic Loop Analysis

| Resource | Sources | Sinks | Status |
|---|---|---|---|
| **Health** | Authored medkit caches (3/mission); F&R respawn restores 100 HP only on death | Damage from guards; environmental death; no regen | **Scarcity risk in late mission (BLOCKING — GD-B4 carryforward)** |
| **Ammo (pistol)** | Mission start 32; off-path caches 8; guard drop 3/lethal kill | 3-shot body TTK / 2-shot headshot TTK; reload overhead | Net-negative for aggressive play; net-positive for headshot-proficient |
| **Ammo (darts)** | Mission start 16; off-path caches 2; dart-KO drops 1 dart (break-even) | Dart fire 1 shot/KO | Break-even; no infinite loop |
| **Ammo (rifle)** | Pickup-only (1 carrier per section + 3 caches) | Rifle fire 1-shot body TTK | Scarcity intentional; tonal exception |
| **Gadgets** | Pre-packed 2 + Parfum mid-mission | Per-use; no cooldowns/charges | Effectively unlimited per Inventory CR-5b — design intent is ammo as the scarcity lever |
| **Suspicion (SAI)** | Faucets: time at low noise, distance, natural decay | Sinks: noise, sight, body discoveries, propagation | Well-designed balancing loop |

**Findings**:

- **🔴 Health scarcity in late mission (GD-B4 carryforward, still open)**: 3 medkits across a 2–4 hour 5-section mission is genuinely lean. The F&R respawn floor returns ammo on first death per checkpoint but NOT health. A player who burns 2 medkits in sections 2–3 enters sections 4–5 with 1 medkit and potentially <80 HP. Pillar 3 ("Stealth is Theatre, Not Punishment") creates a real soft-lock risk. **Resolution**: per-section medkit budget guarantee (1 per section after Plaza), section-entry partial heal, explicit playtest gate, OR documented design decision that scarcity is intended.

- **No exploit** in UNCONSCIOUS wake-up (45 s real-time clock, body still produces SAW_BODY suspicion at 2× → 1× decay, Transitional UNCONSCIOUS→DEAD edge available). Tension preserved.

- **No infinite-bait exploit** in Cigarette Case (consumed per use; queue_frees on guard return-to-UNAWARE per Inventory CR-5b revision). Single-distraction-beat design preserved.

### 2e: Difficulty Curve Consistency

| Section | Guard density | Civilians | Documents | Notes |
|---|---|---|---|---|
| Plaza (1) | Low (tutorial) | 4–6 | 3 | Guided micro-tutorial |
| Lower Scaffolds (2) | Moderate | 4–6 | 4 | Vertical traversal |
| Restaurant (3) | Moderate-heavy | **6–8** | **6** | Peak civilian + peak document + cluttered geometry |
| Upper Structure (4) | Heavy | 4–6 | 5 | Vertical escalation |
| Bomb Chamber (5) | Heaviest (finale) | 0 | 3 | No civilians; PHANTOM core |

- **⚠️ Restaurant section 3 peaks on three independent dimensions simultaneously** (civilian count, document count, enclosed geometry). Recommend redistribution: Restaurant 5 / Upper 6 (or other rebalance).
- **ℹ️ Bomb Chamber discovery trough** — only 3 documents at the narrative climax. Consider 4 documents (the planned detonation telex + 2 echoing operational memos) for stronger payoff.
- **ℹ️ Upper Structure and Lower Scaffolds share identical 4–6 civilian range** — graduated curve would prefer differentiation. Consider Upper 2–4 (operational, restricted) reserving 6–8 exclusively for Restaurant.

### 2f: Pillar Alignment

| Pillar | Primary servers | Supporting servers | Status |
|---|---|---|---|
| 1. Comedy Without Punchlines | DC, MLS, CAI, Menu System, Audio (5) | HUD Core, PC (restraint) | Well-served |
| 2. Discovery Rewards Patience | DC, HUD Core, Document Overlay UI, Inventory (4) | F&R, SAI, Combat | Strong |
| 3. Stealth is Theatre, Not Punishment | SAI, F&R, Combat, Document Overlay UI, LS (5) | Save/Load, Input, HUD Core, Settings | Strongest |
| 4. Iconic Locations as Co-Stars | LS, MLS (2) | DC (Tower-bound furniture), CAI (location archetypes) | **🔴 Thin — only 2 primary** |
| 5. Period Authenticity Over Modernization | HUD Core, Input, PC, Audio, Menu, Settings, F&R, Inventory, FootstepComponent, LS, DC (11) | — | Dominantly covered |

**🔴 Pillar 4 critically thin (BLOCKING — GD-B1 carryforward, matrix corrected but coverage gap unfilled)**: Only LS + MLS serve P4 primary. SAI's vertical-LOS behavior and Tower-architecture-coupled patrol geometry (guards needing to look up stairways, through ironwork grating) is architecture-coupled in a P4-serving way but is not formally claimed in SAI's pillar section. **Resolution**: SAI claims P4 supporting; systems-index Pillar Coverage Matrix updates row 4 to "Level Streaming, Mission Scripting (primary); Stealth AI, DC, CAI (supporting) — 5 total"; MLS §CR-21 Discovery Surface Guarantee credited explicitly as P4 enforcement.

**Anti-pillar compliance**: clean. No system introduces XP, skill trees, currency, crafting, shops, microtransactions, multiplayer, procedural generation, or modern UX paternalism.

### 2g: Player Fantasy Coherence

Nine named framings across GDDs:

1. **The Deadpan Witness** (PC §B) — Eve is the eye of the storm.
2. **Composed Removal of an Obstacle** (Combat §B) — Eve doesn't change register.
3. **The Pre-Packed Bag** (Inventory §B) — Bureau predicted every problem.
4. **Reading the Room** (DC §B) — Documents yield to the curious.
5. **The Lectern Pause** (Document Overlay UI §B) — World holds its breath.
6. **The Case File** (Menu System §B) — Player IS the case officer at BQA Registry.
7. **The Stage Manager** (Settings §B) — Brief moment between scenes.
8. **The Glance** (HUD Core §B) — Cockpit-dial peripheral read.
9. **Eve does not die well** (F&R §B) — Reshuffle, not reprimand.

**Coherent cluster**: Framings 1–5, 8, 9 all reinforce the same operational identity (competent 1965 spy, never theatrical). No conflicts.

**⚠️ Structural POV split (GD-W5 carryforward)**: The Case File (Menu) puts the player as the BQA case officer; every other framing puts the player as Eve. Defensible via spy-fiction precedent (briefing scenes, dossier consultations) but creates subtle cognitive dissonance. **Resolution**: creative-director adjudication — accept dual-POV explicitly, OR align Menu to a third-person-bureaucratic extension of Eve's own experience ("Eve pauses to consult her own dossier" rather than "the player IS BQA's case officer").

**No conflict** between HUD's "Glance" and Overlay's "Lectern Pause" (sequential states, mutually exclusive). **No conflict** between Menu's "Case File" and Settings' "Stage Manager" — Settings explicitly carves itself out as the non-diegetic exception inside the Case File's Personnel File sub-screen, and the boundary is drawn (Menu CR-7).

**Minor friction**: Combat's "Composed Removal" and the rifle-as-tonal-exception (§B.1 "escalation has reached the rooftop") creates an internal register range from composed-blade to escalated-rifle. Addressed by "the world changes register, not Eve" framing — playtest-validation risk, not a design conflict.

---

## Section 3 — Cross-System Scenario Walks (Phase 4)

Four high-risk multi-system scenarios walked step-by-step.

### Scenario A — Restaurant gunfight + civilian panic cascade in same frame as a previously-chloroformed guard sighting
**Trigger**: Player fires silenced pistol at guard G1 in section 3, killing it. Guard G2 (UNCONSCIOUS at 30 s, 15 s wake remaining) is partially in G3's vision cone. 8 civilians within 12 m panic radius.

**Activation order** (single physics frame):
1. Combat: `weapon_fired` → `enemy_damaged(G1)` → `enemy_killed(G1)` → `guard_incapacitated(G1, BULLET)` (2-param per ADR-0002 amendment)
2. SAI: G3, G4, G5 (alive) all subscribe to `enemy_killed` → propagate `actor_became_alerted` (with F.4 `PROPAGATION_BUMP`)
3. CAI: 8 × `civilian_panicked(civilian, cause_position)` emit same frame
4. Audio: re-evaluates panic_count + alert level → applies Formula 2 ducking + escalates BGM
5. HUD: updates ammo via subscriber to `weapon_fired`; updates critical-state via `player_health_changed` (no change here)
6. Inventory: drop-router subscribes to `guard_incapacitated(G1, BULLET)` → drops 3 rounds at G1.position

**Failure mode (WARNING — performance budget)**: ADR-0008 Slot 8 budget at this exact frame: 8 civilian panic transitions × ~112 µs each (per `civilian-ai.md:388`) ≈ 896 µs alone, **before** Audio router cost, Inventory drop-router cost, HUD updates, Signal Bus dispatch overhead. The frame exceeds the 0.8 ms slot cap by GDD admission. **The Restaurant gunfight is the design's worst case** — section 3 is built around 6–8 civilians + dense guards. Mitigation requires ADR-0008 reserve allocation or stagger-cap on concurrent panic transitions.

### Scenario B — Player picks up document during stealth → opens overlay → guard suddenly enters search radius mid-read
**Trigger**: Eve (UNAWARE world) interacts with `DocumentBody` in Lower Scaffolds. DC fires `document_collected(id)`. Document Overlay auto-opens (NOLF1 model per Overlay §C — 8-step open lifecycle).

**Activation order**:
1. PC `player_interacted` → DC validates + emits `document_collected`
2. Overlay opens: push InputContext.DOCUMENT_OVERLAY → MOUSE_VISIBLE → enable PPS sepia → grab focus → AccessKit assertive announce
3. HUD subscribes to `ui_context_changed` → hides
4. Audio subscribes to `ui_context_changed` → ducks BGM −10 dB absolute (audio.md:95)

Meanwhile a patrolling guard advances; Eve enters their cone:

5. SAI: emits `actor_became_alerted` → Audio escalates BGM toward SUSPICIOUS

**Failure mode (WARNING — undefined behavior)**: Audio receives both `ui_context_changed → DOCUMENT_OVERLAY` (duck to −10 dB absolute) and `alert_state_changed → SUSPICIOUS` (escalate) in close succession. The Lectern Pause is intentionally non-interruptible (Overlay §C 5 explicit refusals — "Not interactive"), but the player still hears alert music swelling under the ducked mix. **Question**: does the overlay's sepia-suspended state suppress alert-state-music transitions, or honor them? Neither GDD is explicit. **Resolution**: add an explicit rule in Audio §Concurrency: "While `ui_context_changed.current == DOCUMENT_OVERLAY`, alert-state music transitions are suspended; BGM holds at the document-overlay duck level until Overlay closes, then re-evaluates." This may already be intended but is not specified.

### Scenario C — F5 quicksave during overlay-open with active UNCONSCIOUS guard (10 s wake remaining) + PANICKED civilian
**Trigger**: Player presses F5 mid-overlay.

**Activation order** per Input GDD CR-7 (silent-swallow prevention):
1. F5 input enters Overlay's CLOSING lifecycle (6-step per §C.5)
2. Step 1: consume input
3. Step 2: restore mouse mode
4. Step 3: pop InputContext (now GAMEPLAY)
5. Step 4: disable sepia
6. Step 5: hide + clear card synchronously (Option B)
7. Step 6: call DC.close_document
8. Save/Load executes F5 quicksave: assembles SaveGame via per-system `*_State.capture()` cascade

**Failure mode (BLOCKER candidate — needs verification)**: Save/Load CR-2 gates F5 on `InputContext == GAMEPLAY` AND (presumably) `Overlay.state == IDLE`. After Overlay's step 3 InputContext pop, the context is GAMEPLAY mid-frame. **Question**: does F5 fire its quicksave in the same frame as the CLOSING lifecycle, or the next? `input.md:55` (CR-7) says "consume input FIRST". If quicksave fires same-frame after Overlay close, the saved state should correctly read `_wake_remaining_sec = 10.0` for SAI and `panicked: true` for CAI. On load, F&R/MLS hydrate, LSS step 9 fires CAI restore (no `civilian_panicked` re-emit per CR-10), SAI restores guard with `_wake_remaining_sec = 10.0` and resumes countdown. **This works if Overlay is fully closed before save executes.** If save executes mid-CLOSING (e.g., after step 3 InputContext pop but before step 5 hide+clear), Overlay state may be visible-but-detached at the moment of capture — none of the captured sub-resources include Overlay state (Overlay is per-section, not autoload), so the save itself is not corrupted. But the player sees a frame of "Overlay still showing while quicksave SFX plays" which violates the Lectern Pause's "world holds its breath" intent.

**Action**: confirm Save/Load CR-2 explicitly requires `current_input_context == GAMEPLAY` AND `Overlay.state == IDLE` as preconditions, OR that Overlay's CLOSING lifecycle is fully synchronous within one frame (no `await`). Today neither precondition is explicit.

### Scenario D — Section transition during active panic with PANICKED civilian + UNCONSCIOUS guard + open document overlay
**Trigger**: Eve enters section-exit `TriggerVolume3D` while:
- Guard G1 UNCONSCIOUS with 5 s wake remaining
- Civilian C1 PANICKED
- Document Overlay open

**Activation order**:
1. MLS detects `transition_to_section(next_id, FORWARD)`
2. LS pushes InputContext.LOADING (assuming amendment lands)
3. Overlay subscribes to LOADING → forces dismiss via CLOSING lifecycle
4. Save assembles via per-system `*_State.capture()` cascade including `_wake_remaining_sec = 5.0` (SAI) and CivilianAIState `panicked: true` for C1
5. Slot 0 autosave writes (FORWARD branch — autosave ON per MLS:247)
6. Plaza section unloads; Lower Scaffolds loads
7. LS step 9 invokes registered restore callbacks (MLS, F&R, Menu, plus per-civilian if CAI keeps that pattern)
8. SAI guard G1 doesn't exist in Lower Scaffolds (guards are per-section) — wake-state captured-but-discarded
9. New section's NPCs spawn fresh

**Failure mode (WARNING — implicit but undocumented)**: Section forward-transition discards the previous section's runtime state by design (Plaza guards don't follow Eve to Restaurant). The `_wake_remaining_sec = 5.0` is captured but the saved state going to slot 0 carries it — and on a resume from autosave the previous section is unloaded, so the captured wake-state is dead data in the save file. **This is correct behavior, but stealth-ai.md:296 and the F&R + LS interaction matrix don't explicitly state that captured Plaza guard wake-state is dropped on FORWARD transition.** Question: if a player saves manually mid-Plaza (slot 1), then transitions FORWARD to Lower Scaffolds, then loads slot 1 — the UNCONSCIOUS guard restores with 5 s remaining, correct? Yes, per Save/Load round-trip — `save.current_section_id` was Plaza when assembled. **Action**: add an explicit cross-doc note in MLS or LS that section-FORWARD transition saves the previous section as the section-of-record (not the next section), which is correct for resume semantics. An integration test should explicitly cover the forward-then-load round-trip.

---

## Section 4 — GDDs Flagged for Revision

| GDD | Reason | Severity | Current status | Action |
|---|---|---|---|---|
| `menu-system.md` | ~10 sites stale autoload-slot numbering + FontRegistry-as-autoload + AC-MENU-1.1 asserts 8-not-10 | **BLOCKING** | Needs Revision (no change) | Sweep all sites; rewrite AC-MENU-1.1; add to ADR-0007 §Downstream |
| `inventory-gadgets.md` | Lines 508 + 874 say `SaveLoad.register_restore_callback` (CR-11 corrected, two sites stale) | **BLOCKING** | Needs Revision (no change) | Sweep two sites |
| `civilian-ai.md` | F.3 sub-claim 0.30 ms vs §573 stale 0.15 ms internal drift; LSS callback-ownership disagreement | **WARNING** | **Approved 2026-04-25** → flip to Needs Revision | Sweep tuning row + dependencies; LS CR-2 negotiation |
| `document-collection.md` | 6 sites enumerate stale "CAI 0.15" Slot-8 sharing | **WARNING** | **APPROVED 2026-04-27** → flip to Needs Revision | Sweep 6 enumerations to 0.30 |
| `hud-core.md` | Stale "caps autoloads at 7" + L587/L697 stale `setting_changed("hud", _)` + Tween-cleanup CR missing | **BLOCKING** | Approved 2026-04-26 → flip to Needs Revision | Replace stale references; add CR for `Tween.kill()` on `ui_context_changed != GAMEPLAY` |
| `signal-bus.md` | Settings domain row missing `settings_loaded` (W4) | **WARNING** | Needs Revision (no change) | Add row after ADR-0002 amendment lands |
| `combat-damage.md` | CR-7 missing `MELEE_FIST` noise event spec | **BLOCKING** | Needs Revision (no change) | Add 2–3 m noise radius for fist swings |
| `failure-respawn.md` | Health-budget/medkit per-section policy unspecified (GD-B4) | **BLOCKING** | Needs Revision (no change) | Design decision: medkit guarantee OR section-entry partial heal OR playtest-gate |
| `mission-level-scripting.md` | Section-FORWARD wake-state-discard not documented | **INFO** | Needs Revision (no change) | Add cross-doc note on forward-transition section-of-record |
| `audio.md` | Document-overlay duck vs alert-state escalation interaction undefined; Documents-domain dB semantics ADVISORY uncorrected | **WARNING** | Needs Revision (no change) | Add §Concurrency rule for overlay-suspends-alert-music; clarify dB-absolute |
| `save-load.md` | F5 precondition `Overlay.state == IDLE` not explicit | **WARNING** | Needs Revision (no change) | Add explicit preconditions to CR-2 |
| `stealth-ai.md` | Pillar 4 supporting role not formally claimed | **INFO** | Approved 2026-04-22 → leave as-is, request §Pillars edit only | Add P4 supporting claim in Player Fantasy section |

### Required ADR amendments (out of GDD scope)

| ADR | Change | Severity | Owner |
|---|---|---|---|
| ADR-0002 | §Decision + §Migration Plan sweep "36 events / 34 signals" → 38 (or 39 with `settings_loaded`); add `settings_loaded()` and `ui_context_changed` to taxonomy | **BLOCKING** | technical-director + lead-programmer |
| ADR-0004 | Add `MODAL` and `LOADING` to InputContext enum + push/pop contracts | **BLOCKING** (B4 carryforward) | ux-designer + godot-specialist |
| ADR-0008 | Reserve allocation for Slot-8 panic-onset spikes (Restaurant 8-civilian frame); update §Risks autoload-cascade row 7 → 10 | **BLOCKING** | technical-director |

### Required design decisions (out of GDD scope until decided)

| Decision | Owner | Severity |
|---|---|---|
| Mid-mission medkit budget (per-section guarantee, partial heal on section entry, OR documented playtest-gate) | game-designer + creative-director | BLOCKING |
| Fist-swing noise event radius (recommend 2–3 m) | systems-designer + game-designer | BLOCKING |
| Headshot-economy net-positive: cap drops vs accept as skill-ceiling expression | systems-designer | WARNING |
| Crouch-vs-Walk balance: penalty mechanism OR explicit NOLF1-baseline acceptance | game-designer | WARNING |
| Menu-as-case-officer dual-POV: accept explicitly OR realign to Eve's POV | creative-director | WARNING |
| ADR-0003 additive-field-no-version-bump: codify in ADR or retract from F&R | technical-director | WARNING |
| LS callback registration pattern for CAI: per-civilian self-register (with LS CR-2 update) OR move through MLS | game-designer + ai-programmer | WARNING |

---

## Section 5 — Severity Roll-up

### BLOCKING (9)
1. menu-system.md ~10 sites stale autoload-slot numbering + AC-MENU-1.1 assertion conflict
2. ADR-0002 §Decision/Migration "36/34" vs Revision History "38" sweep
3. ADR-0004 InputContext enum missing `MODAL` + `LOADING` (B4 carryforward)
4. inventory-gadgets.md `SaveLoad.register_restore_callback` self-contradiction (3 sites)
5. Document Overlay UI Slot-7 sole-occupant claim depends on uncodified HUD Tween cleanup
6. ADR-0008 Slot-8 panic-onset frame busts 0.8 ms cap by GDD's own math
7. Health scarcity death-spiral risk in late mission (GD-B4 carryforward)
8. Fist-swing noise event undefined → cost-free non-lethal dominant strategy
9. Pillar 4 primary coverage at 2 systems only (GD-B1 carryforward — matrix corrected, gap unfilled)

### WARNINGS (13)
1. Inventory ↔ LSS bidirectionality
2. CivilianAI per-civilian self-register vs LSS CR-2 caller list
3. `ui_context_changed` declared in HUD but not in ADR-0002 taxonomy
4. OQ-HUD-3 conditionality across HUD ↔ Overlay
5. CAI 0.15 vs 0.30 ms internal drift + 6 stale enumerations in DC
6. ADR-0008 §Risks autoload-cascade row says 7 (now 10)
7. `signal-bus.md:64` Settings domain missing `settings_loaded` (W4 carryforward)
8. Restaurant section 5-channel attention spike (GD-W9 carryforward)
9. Crouch-dominates-Walk (GD-W2 carryforward)
10. Headshot-economy net-positive
11. Menu-as-case-officer dual-POV (GD-W5 carryforward)
12. Audio document-overlay duck vs alert-state interaction undefined
13. ADR-0003 additive-field-no-bump claim needs human verification

### INFO (8)
1. `hud-core.md:319` "caps autoloads at 7" wording
2. `hud-core.md:587, :697` stale `setting_changed("hud", _)` for crosshair
3. OQ-LS-9 status (verified implicitly)
4. Audio dB-semantic clarification ADVISORY uncorrected
5. CanvasLayer 10 collision (mitigated, pending Cutscenes GDD)
6. Bomb Chamber 3-document discovery trough at narrative climax
7. Upper Structure / Lower Scaffolds identical 4–6 civilian range
8. Section-FORWARD wake-state discard documented implicitly

---

## Section 6 — Required Actions Before Re-Review

1. Sweep menu-system.md ~10 stale-slot sites + add to ADR-0007 §Downstream
2. Sweep inventory-gadgets.md:508 + :874 to LSS
3. Sweep ADR-0002 §Decision + §Migration "36/34" → 38
4. Bundle ADR-0002 amendment: add `settings_loaded()` and `ui_context_changed` to taxonomy (recount → 39 or 40)
5. ADR-0004 amendment: add `MODAL` + `LOADING` to InputContext enum
6. ADR-0008 amendment: reserve allocation for Slot-8 panic-onset; update §Risks autoload-cascade 7 → 10
7. Combat §CR-7: assign `MELEE_FIST` 2–3 m noise event
8. F&R or MLS: medkit budget decision (per-section guarantee, partial heal, OR playtest-gate)
9. HUD CR: `Tween.kill()` on `ui_context_changed != GAMEPLAY`
10. Audio §Concurrency: overlay-suspends-alert-music rule
11. Save/Load CR-2: explicit `Overlay.state == IDLE` precondition for F5
12. SAI §Pillars: claim P4 supporting; systems-index Pillar Coverage Matrix update
13. Sweep CAI 0.30 ms internal + DC 6 enumerations
14. CAI vs LS callback registration pattern: producer adjudication

---

*Prior reviews: `gdd-cross-review-2026-04-20.md`, `gdd-cross-review-2026-04-27.md`. Carryforwards explicitly tagged GD-B1, GD-B3, GD-B4, GD-W2, GD-W5, GD-W9, B4, W4, W6.*
