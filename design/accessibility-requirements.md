# Accessibility Requirements: The Paris Affair

> **Status**: Committed
> **Author**: ux-designer + producer (solo studio — agustin.ruatta@vdx.tv)
> **Last Updated**: 2026-04-28 night (created post-`/gate-check pre-production` FAIL — closes blocker #4 of 7)
> **Accessibility Tier Target**: **Standard**
> **Platform(s)**: PC (Linux + Windows, Steam)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (text contrast, sizing, input requirements)
> - Game Accessibility Guidelines (https://gameaccessibilityguidelines.com) — Standard tier
> - AbleGamers Player Panel — aspirational, not engaged at v1.0
> - Xbox Accessibility Guidelines (XAG) — N/A (no Xbox release planned)
> - PlayStation Accessibility (Sony Guidelines) — N/A (no PlayStation release planned)
> - Apple / Google Accessibility Guidelines — N/A (no mobile release planned)
> - Linux Steam Deck verification — soft target (informs control-scheme defaults, not a tier driver)
> **Accessibility Consultant**: None engaged at v1.0; flagged for post-launch evaluation if budget allows.
> **Linked Documents**: `design/gdd/systems-index.md` · `design/gdd/settings-accessibility.md` · `design/gdd/hud-core.md` · `design/gdd/dialogue-subtitles.md` · `design/gdd/cutscenes-and-mission-cards.md` · `design/ux/interaction-patterns.md` (TBD per `/gate-check` blocker #5)

> **Why this document exists**: Per-screen accessibility annotations belong in
> UX specs. This document captures the project-wide accessibility commitments,
> the feature matrix across all 23 systems, the test plan, and the audit history.
> Created during Technical Setup; updated as features are added and audits are
> completed. If a feature conflicts with a commitment made here, this document
> wins — change the feature, not the commitment, unless the producer approves a
> formal revision.
>
> **When to update**: After each `/gate-check` pass, after any accessibility
> audit, after any Settings & Accessibility GDD revision, and whenever a new
> game system is added to `systems-index.md`.

> **Pillar 5 carve-out posture (load-bearing for this project)**: *The Paris Affair*
> commits to Pillar 5 (Period Authenticity Over Modernization) as load-bearing.
> Where accessibility settings would conflict with period authenticity (e.g., the
> "no first-watch cinematic skip" rule in Cutscenes & Mission Cards FP-CMC-2),
> the resolution pattern is the **Stage-Manager carve-out**: a Settings-gated
> opt-in toggle, default `false`, that preserves Pillar 5 as the shipping default
> while honoring accessibility as an explicit player choice. This pattern is
> anchored to the Combat §B precedent and replicated in Cutscenes §C.2.2.
> Future systems that want to lock a Pillar-5 absolute MUST follow this pattern
> when the absolute would create a WCAG 2.1 SC 2.2.x or 2.1.1 issue.

---

## Accessibility Tier Definition

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical text readable at standard resolution; no color-only signals; independent volume sliders for music/SFX/voice; no photosensitivity risk. | Low — design constraints |
| **Standard** ⬅ **target** | Basic + full input remapping + subtitles with speaker ID + adjustable text size + ≥1 colorblind mode + no un-extendable timed inputs. | Medium — dedicated implementation work |
| **Comprehensive** | Standard + screen reader for menus + mono audio + difficulty assist + HUD repositioning + reduced motion + visual indicators for all gameplay-critical audio. | High — platform API + UI architecture |
| **Exemplary** | Comprehensive + full subtitle customization + high contrast + cognitive load tools + tactile/haptic alternatives + external third-party audit. | Very High — dedicated budget + specialist consultation |

### This Project's Commitment

**Target Tier**: **Standard**

**Rationale**: *The Paris Affair* is a single-player 1965 stealth-spy comic targeting PC (Linux + Windows, Steam) with a solo developer. The stealth puzzle genre creates moderate motor barriers (timed observation, gadget aim) and significant cognitive barriers (multi-actor surveillance, multi-objective tracking) — Standard tier addresses both via input remapping, toggle-input alternatives, scalable UI, and quest-clarity rules. The reading-heavy dossier surface (Document Collection #17 — 21 in-world documents, dialogue-subtitles #18 — 40+ banter lines, Cutscenes & Mission Cards #22 — 7 authored beats with localized text) creates significant visual and reading-pace barriers; subtitle support with speaker identification + scalable text + ≥1 colorblind mode are committed-in-Standard. **Comprehensive is aspirational** — the project already exceeds Standard in some places (AccessKit per-widget table on HUD/Cutscenes/Document Overlay; Cutscenes Settings-gated skip carve-out; D&S SCRIPTED Category 8 captions for narrative-critical SFX) but does NOT commit to HUD repositioning, difficulty assist, or audio mono mode at v1.0 — those are Comprehensive-tier features that would require systems-design work this project's scope does not allow. Dropping to Basic would exclude players who rely on input remapping or colorblind modes (~8-12% of the target audience per AbleGamers data) and would also be inconsistent with commitments already locked in Settings & Accessibility GDD #23 + HUD Core #16 + Dialogue & Subtitles #18.

**Features explicitly in scope (beyond Standard tier baseline)**:
- **Photosensitivity boot-warning modal** (Settings & Accessibility CR-23 + HUD Core REV-2026-04-26 D2 promoted to HARD MVP DEP) — exceeds Basic; required because Cutscenes CT-03 contains a single-frame chromatic flash and op-art rapid letterbox slide-in.
- **AccessKit per-widget table** for menus + HUD + Cutscenes + Document Overlay (Comprehensive-tier menu screen reader support partial — covers menu navigation but NOT in-world objects/NPCs per Cutscenes UI.3 and Document Overlay UI §F).
- **Cinematic skip Settings carve-out** (`accessibility_allow_cinematic_skip` per Cutscenes §C.2.2, default `false`, Stage-Manager precedent) — addresses WCAG 2.1 SC 2.2.1 / 2.2.2 / 2.1.1 for the no-first-watch-skip Pillar-5 absolute.
- **`text_summary_of_cinematic`** (Cutscenes OQ-CMC-11 promoted to BLOCKING/MVP-recommended) — narrative-prose summary fallback for players who cannot process visual-audio cinematic composition; Settings-gated.
- **D&S SCRIPTED Category 8 captions** (Cutscenes OQ-CMC-18) — closed captions for narrative-critical non-dialogue SFX (CT-05 device-tick cessation, wire-cut, tick-cessation). Core narrative beats remain accessible to deaf/HoH players.
- **HoH/deaf alert-state cue** (HUD State Signaling REV-2026-04-26 D3 promoted to HARD MVP DEP) — visual cue for stealth alert-state changes, complements stinger audio.
- **Subtitles default ON** (Settings VS commitment) — exceeds industry standard (most games default OFF). Dialogue-heavy game register justifies the inversion.
- **Toggle-Sprint / Toggle-Crouch / Toggle-ADS** (Settings Day-1 MVP per CR-22) — exceeds Standard baseline; addresses sustained-hold motor barriers.
- **Separate rebind for `use_gadget` and `takedown`** (Settings CR-22 + Input GDD §C.2.4) — exceeds Standard baseline; resolves a 3-way GDD contradiction by giving each action its own bindable slot.

**Features explicitly out of scope (documented in Known Intentional Limitations below)**:
- Screen reader for in-world objects, NPCs, environmental text — covered by AccessKit menus only; Godot 4.6 in-world spatial audio description is engine-work-beyond-scope.
- HUD element repositioning — Comprehensive-tier; not in v1.0 scope.
- Difficulty assist modes (damage scaling, enemy aggression sliders) — Comprehensive-tier; conflicts with stealth-puzzle design (puzzle has correct/incorrect solutions, not adjustable difficulty).
- Mono audio output — Comprehensive-tier; not in v1.0 scope; spatial audio is a Pillar-3 (Stealth as Theatre) feature.
- Tactile/haptic alternatives — Exemplary-tier; PC controllers have inconsistent haptic support; Steam Deck haptic API is the only deterministic target and is post-launch evaluation.
- External third-party accessibility audit — Exemplary-tier; cost-prohibitive for solo project at v1.0.
- Full subtitle customization (font/color/background) — Exemplary-tier; project ships with 1 default + 1 high-readability preset (Settings VS scope per G.3 — `subtitle_size_scale` / `subtitle_background` / `subtitle_speaker_labels`).
- Multiplayer / network accessibility (voice chat captions, etc.) — N/A (single-player game per game-concept.md).

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menu UI | Standard | All menu screens (Menu System #21 + Settings panel #23) | Designed (Settings GDD §G.3 `subtitle_size_scale`) | 24 px minimum at 1080p. Scaling proportional at 4K. WCAG 2.1 SC 1.4.4 (resizable to 200%). |
| Minimum text size — subtitles | Standard | Dialogue & Subtitles (#18) + Cutscenes (#22) HANDLER VO captions | Designed | 32 px minimum at 1080p (Courier Prime per D&S V.1). Players viewing on TV at 3 m are the constraint. |
| Minimum text size — HUD | Standard | HUD Core (#16) + HUD State Signaling (#19) | Designed (HUD Core CR-19) | 18 px floor enforced via FontRegistry scale-aware call (REV-2026-04-26 D2 fix). |
| Minimum text size — Mission Cards / Document Overlay | Standard | Cutscenes (#22) Mission Cards + Document Overlay UI (#20) | Designed (Cutscenes V.1) | Briefing/Closing card body 18 px; Document Overlay body 18 px (Art Bible §3.3). |
| Text contrast — UI text on backgrounds | Standard | All UI text | Not Started | Minimum 4.5:1 (WCAG AA body); 3:1 large text (≥18 px or ≥14 px bold). Audit using `tools/ci/contrast_check.sh` (TBD) on final color values. |
| Text contrast — subtitles | Standard | D&S subtitle display | Designed (D&S V.1) | Minimum 7:1 (WCAG AAA) — opaque background scrim per Settings G.3 `subtitle_background` (3 modes: none / scrim / opaque). |
| Colorblind mode — Protanopia | Standard | All color-coded gameplay | Designed (Settings GDD §G.3) | Affects ~6% of men. Primary concerns: HUD health bar (HUD Core), enemy alert-state colors (HUD State Signaling), document rarity (Document Collection). Shift red signals to orange/yellow; verify via Coblis simulator. |
| Colorblind mode — Deuteranopia | Standard | All color-coded gameplay | Designed (Settings GDD §G.3) | Affects ~1% of men. Often same palette adjustment as Protanopia. |
| Colorblind mode — Tritanopia | Standard | All color-coded gameplay | Designed (Settings GDD §G.3) | Rarer (~0.001%). Op-art cyan `#00B4D8` in CT-05 — verify legibility per Cutscenes accessibility-specialist Finding 7. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | See table below. Each color-only signal must have a non-color backup before VS sprint review. |
| UI scaling | Standard | All UI elements | Designed (Settings GDD §G.3 `ui_scale`) | Range 75–150%. Default 100%. HUD scaling independent from menu scaling. |
| High contrast mode | Comprehensive | OUT OF SCOPE — see Known Intentional Limitations | Not Planned | Listed for completeness — not committed to Standard tier. |
| Brightness/gamma controls | Basic | Global | Designed (Settings G.3) | Reference calibration image required. Range -50% to +50%. |
| Screen flash / strobe warning + photosensitivity opt-out | Basic + project-elevated | All cutscenes, VFX (HUD Core damage_flash + Cutscenes CT-03 chromatic) | Designed (Settings CR-23 boot-warning modal + HUD Core `hud_damage_flash_enabled` opt-out per REV-2026-04-26 D2 HARD MVP DEP) | Boot-warning modal at first launch (38-word "Stage Manager"-register copy per Settings); `hud_damage_flash_enabled` Day-1 MVP toggle; CT-03 single-frame chromatic flash audited against Harding FPA standard before VS lock. |
| Motion/animation reduction mode | Standard | UI transitions, camera shake, VFX | Designed (Settings G.3 `reduced_motion`) | Reduces: screen shake, camera bob, motion blur, parallax in menus, looping background animations, Document Overlay sepia-dim transition. **Hard-cuts in Mission Cards (Cutscenes CR-CMC-19)** are vestibular-safe by design — no change needed under reduced-motion. **Letterbox slide-in (CT-05 12-frame Tween)** — reduced motion replaces with hard-cut variant. |
| Subtitles — on/off | Basic | All voiced content | Designed (Settings G.3 `subtitles_enabled`) | **Default: ON** (Settings VS commitment — exceeds industry default OFF). Toggle in Accessibility subcategory. |
| Subtitles — speaker identification | Standard | All voiced content | Designed (Settings G.3 `subtitle_speaker_labels` + D&S CR-DS-18 + dialogue-writer-brief.md) | Speaker name displayed before line per D&S 7-speaker-category convention (`[GUARD]:`, `[CLERK]:`, `[LT.MOREAU]:`, `[VISITOR]:`, `[STAFF]:`, `[HANDLER]:`, `[STERLING.]`). |
| Subtitles — style customization | Comprehensive (partial) | D&S subtitle display | Designed (Settings G.3 — 3 background modes + size scale only) | Project commits 3 background modes (none / scrim / opaque) + `subtitle_size_scale` slider + speaker-label toggle. Full font/color/position customization is Exemplary — out of scope. |
| Subtitles — sound effect captions | Comprehensive (CT-05 narrative-critical only) | Cutscenes CT-05 narrative-critical SFX (device-tick / wire-cut / tick-cessation) | Designed (Cutscenes OQ-CMC-18 — D&S SCRIPTED Category 8) | NEW D&S SCRIPTED Category 8 — non-dialogue narrative captions, MLS-triggered via `scripted_caption_trigger(scene_id, caption_key)`. Caption position must be within active letterbox image area (817 px on CT-05). Closes accessibility-specialist Finding 4 (deaf players miss CT-05 narrative climax). |
| Cinematic accessibility skip (Stage-Manager carve-out) | Standard (project-elevated) | Cutscenes CT-03/CT-04/CT-05 first-watch | Designed (Cutscenes §C.2.2 + OQ-CMC-17) | `accessibility_allow_cinematic_skip` Settings toggle (default `false` — Pillar 5 preserved as default). When `true`, `cutscene_dismiss` honored at any time during cinematic. WCAG 2.1 SC 2.2.1 / SC 2.2.2 mitigation. |
| `text_summary_of_cinematic` accessibility fallback | Standard (project-elevated, MVP-recommended) | All cinematics | Designed (Cutscenes OQ-CMC-11 promoted from Polish-spike) | Settings-gated 3–5 sentence prose summary per cinematic, replaces standard playback when enabled. WCAG 1.1.1 / 1.2.5 mitigation for players who cannot process visual-audio cinematic composition. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| HUD health bar | Red ramp at low HP | Player near death | Numeric value + flash + audio clock-tick (HUD Core F.5 critical-state pulse paired with Audio per CR-12) | Designed |
| HUD State Signaling alert state | Red flash on alert escalation | Stealth alert-state changed | Margin-note Label text (HoH/deaf alert-cue MVP per HSS REV-2026-04-26 D3) + AccessKit polite live-region | Designed |
| Document rarity (Document Collection) | Color-coded `#1B3A6B` BQA Blue vs Parchment | Document type taxonomy (BQA / PHANTOM / civilian / etc.) | Typographic register (Futura header vs American Typewriter body); paper palette varies per category, NOT color-only | Designed (DC §V.1) |
| Op-art (CT-05) | Saturated cyan `#00B4D8` rings on Ink Black | Compositional accent during bomb-disarm climax | Decorative only — narrative beat carries no color-only information; tick-cessation captioned per D&S Cat 8 | Designed |
| Crosshair (HUD Core) | Default white/Ink Black | Aim target | `crosshair_enabled` toggle in Settings (player can disable; aim is gun-position-anchored regardless) | Designed |
| Document Overlay sepia-dim | Warm amber `#E8A020` tint | "Lectern Pause" reading mode entered | Card animation (paper-translate-in 12-frame) + InputContext push (HUD hides) — multiple non-color signals | Designed |
| PHANTOM Red `#C8102E` indicator lamps (CT-05 device) | Red blinks once per 0.5 Hz | Bomb device active | Caption "[device hum]" (D&S Cat 8) + tick audio (Audio bus 3D spatial) | Designed |
| Mission Card classification stamp | Ink Black on Parchment, rotated -5° | Card type (briefing / closing / objective) | Stamp text differs per card type (`CLASSIFIED`, `MISSION CLOSED`, `OBJECTIVE`); typographic register, not color-only | Designed |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | All gameplay inputs (KB+M + gamepad) | Designed (Input GDD §C + Settings CR-22) | KB+M rebinding **MVP**; gamepad rebinding **post-MVP** (per technical-preferences.md) — see Known Intentional Limitations. Every default-bound input must be rebindable. Conflict warning required (Settings 3-state rebind machine: NORMAL_BROWSE → CAPTURING → CONFLICT_RESOLUTION). Persist to player profile. |
| Input method switching | Standard | PC | Designed | KB+M and gamepad switchable at any moment; UI updates prompts dynamically per HUD Core CR-21 (rebinding contract for runtime key glyphs). |
| One-hand mode | Standard (partial) | Movement + observation gameplay | Designed (Toggle-Sprint/Crouch/ADS Day-1 MVP per Settings CR-22) | Toggle alternatives for sustained-hold inputs cover the most severe one-hand barriers. **Full one-hand mode (chord-input elimination) is NOT committed**. Stealth gameplay's puzzle-observation register is more amenable to one-hand play than action games. Document at VS playtest. |
| Hold-to-press alternatives | Standard | All hold inputs (sprint, crouch, ADS, gadget-charge) | Designed (Settings CR-22 toggle alternatives Day-1 MVP) | Every "hold [button] to [action]" offers a toggle alternative. Toggle mode: first press activates, second press deactivates. Inputs covered: `sprint`, `crouch`, `ads`, `gadget_charge`. |
| Rapid input alternatives | Standard | No rapid-input mechanics in MVP/VS | N/A (design constraint) | Stealth-puzzle game has no button-mashing or sustained rapid-input sequences by design. If post-launch content adds any (e.g., struggle-out QTE), this row must be re-evaluated and a toggle alternative added. |
| Input timing adjustments | Standard | No timed inputs in MVP/VS gameplay | N/A (design constraint) | Stealth observation has no QTEs or rhythm inputs. **Mission Card dismiss-gate (4.0/5.0/3.0 s)** is a silent-drop convention, not a timing test — `cutscene_dismiss` is honored after gate expiry without timing precision; gate duration is tunable per Cutscenes G.1 within [3.0, 8.0] s and is also the fallback path for slow readers (closing-card 5.0 s gate per Cutscenes G.1 + GAP-4). |
| Aim assist | Standard | Combat & Damage (#11) gadget aim | Designed (Settings G.3 `aim_assist_*`) | Granular sliders: `aim_assist_strength` (0–100%), `aim_assist_radius`, `aim_magnetism`, `aim_slowdown`. Default values tuned to feel helpful, not intrusive. Combat is gadget-based (non-lethal) — aim assist is permissive. |
| Auto-sprint / movement assists | Standard | Player movement | Designed (Settings CR-22 toggle-sprint) | Toggle-sprint = de facto auto-sprint. Auto-run (hold direction continues without input) NOT committed — Pillar 3 (Stealth as Theatre) requires intentional movement; auto-run could break observation pacing. Document at VS playtest. |
| Platforming / traversal assists | N/A | Game has no platforming | N/A (design constraint) | The Paris Affair is a stealth-puzzle game without jump or ledge-grab mechanics. Mark N/A unless post-launch content adds vertical traversal (e.g., Tier 2 Rome/Vatican). |
| HUD element repositioning | Comprehensive | OUT OF SCOPE — see Known Intentional Limitations | Not Planned | Listed for completeness — not committed to Standard tier. HUD anchoring is fixed per HUD Core §V (top-left health/ammo, bottom-right gadget, etc.). |
| Adaptive controller cinematic auto-dismiss | Project-elevated (Standard+) | Cutscenes Mission Cards | Designed (Cutscenes accessibility-specialist Finding 6) | `cutscenes_auto_dismiss_timeout_s` Settings (default 0 / disabled). When > 0, Mission Cards auto-dismiss N seconds after gate expiry — protects adaptive-controller players who cannot produce default `cutscene_dismiss` (Esc/B). Does not violate FP-CMC-3 (visible affordance forbidden; auto-dismiss is invisible). |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard (partial) | Gameplay difficulty | Out of scope — see Known Intentional Limitations | Stealth-puzzle design has correct/incorrect solutions; granular difficulty sliders would conflict with puzzle integrity. **Aim assist** (Motor table) provides the primary difficulty assist for the combat layer. **Saved-game count** (Save/Load `quicksave` + autosave + manual saves) provides retry tolerance. Document trade-off at VS playtest. |
| Pause anywhere | Basic | All gameplay states | Designed (Menu System CR-7 + Cutscenes CR-CMC-7) | Pause works during gameplay. **Pause is BLOCKED during Cutscenes** (CUTSCENE context blocks `ui_menu`). The Stage-Manager carve-out (`accessibility_allow_cinematic_skip`) provides the cinematic exit path; combined with `text_summary_of_cinematic`, the pause-blocked-during-cinematic restriction has accessibility mitigation. Document Overlay reading similarly blocks pause but Lectern-Pause is itself the pause register. |
| Tutorial persistence | Standard | Plaza MVP-Day-1 tutorial (5 D&S lines) + per-section first-encounter prompts | Designed (D&S Plaza tutorial 5-line set; HUD Core prompt-strip lifecycle) | Plaza tutorial dialogue lines are accessible from Pause Menu → Help section. HUD prompt-strip uses `cutscene_dismiss`-style silent-drop OFF by default; first-encounter prompts persist until acknowledged. |
| Quest / objective clarity | Standard | Mission & Level Scripting (#13) + HUD Core | Designed (HUD Core objective Label widget) | Active objective accessible via HUD prompt-strip + Pause Menu's Mission tab. Display full objective text, not truncated marker. **Objective markers / arrows / map pings forbidden by Pillar 5** (Cutscenes FC-2 + game-concept.md `forbidden patterns`) — objectives describe *what* to find, not *where*. Mitigation: dossier writing (Document Collection) provides spatial context narratively; Quest Log shows full text without map pings. |
| Visual indicators for audio-only information | Standard | Stealth alert-state, document-pickup, cutscene cues | Designed | (1) HUD State Signaling HoH/deaf alert-cue (MVP HARD DEP per REV-2026-04-26 D3) — visual + audio. (2) D&S SCRIPTED Category 8 captions for CT-05 narrative SFX (Cutscenes OQ-CMC-18). (3) Document pickup chime paired with HUD State Signaling MEMO_NOTIFICATION (HSS §C). (4) Save-failed advisory routed to non-blocking HUD State Signaling SAVE_FAILED state. |
| Reading time for UI | Standard | All auto-dismissing dialogs | Designed | Mission Card dismiss-gate is **silent-drop, not auto-dismiss** — player retains control over dismissal. Cutscenes 4.0/5.0/3.0 s gate is the **minimum** read time, not a maximum. Closing card 5.0 s gate covers Rome cliffhanger seed (Cutscenes GAP-4 reading-speed test). Localization expansion (German/French ~30%) addressed via tunable `cutscenes_dismiss_gate_closing_s` range [4.0, 8.0]. |
| Cognitive load documentation | Comprehensive (partial — high-load systems flagged) | Per system in systems-index.md | Documented per-GDD (Cluster B / Cluster C edge cases) | High-cognitive-load systems flagged in Per-Feature Matrix below. Stealth AI (#10) + Civilian AI (#15) parallel actor tracking is the highest cognitive-load system in MVP — mitigation via reduced civilian count (Plaza 4-6, Eiffel 4-6 per CAI). |
| Navigation assists | Standard (partial) | World navigation | Designed | Fast travel: NOT committed (linear mission structure per game-concept.md — Sections 1-5). Waypoint system: NOT committed (Pillar 5 forbids map pings). **Optional objective indicator** (Pillar 5 fallback): HUD Core's prompt-strip + Mission Cards (Cutscenes briefing/closing) provide *narrative* objective clarity; the dossier register replaces the map waypoint. |
| Saved-game count + autosave | Standard | Save/Load (#6) | Designed (Save/Load §C — quicksave + autosave + 5 manual slots) | Multiple save points reduce cognitive load on retry. Autosave on `section_entered`, `mission_started`, `objective_completed`. Quicksave (F5) + Quickload (F9) for fast iteration. |
| Cutscenes accessibility fallbacks (Stage-Manager carve-out + text_summary) | Project-elevated | Cutscenes CT-03/CT-04/CT-05 + all Mission Cards | Designed (Cutscenes §C.2.2 + OQ-CMC-11 + OQ-CMC-17 + OQ-CMC-18) | Three layers of accessibility for cinematic content: (1) Settings-gated skip (`accessibility_allow_cinematic_skip`). (2) Settings-gated text summary (`cinematic_text_summary_enabled` — 3-5 sentence prose per cinematic). (3) Closed captions for narrative-critical SFX (D&S Category 8). Players who cannot process visual-audio cinematic composition have at least one of these three accessible paths. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | Basic | All voiced content (D&S 7 speaker categories + Cutscenes CT-04 HANDLER VO) | Designed (D&S §C + dialogue-writer-brief.md) | 100% coverage. 40-line per-section roster (Plaza 5 / Lower 8 / Restaurant 12 / Upper 10 / Bomb 5). Test subtitle sync against voice-acting timing per VG-DS-1. **Default ON** (Settings VS commitment). |
| Closed captions for gameplay-critical SFX | Comprehensive (narrative-critical only) | Cutscenes CT-05 narrative SFX | Designed (Cutscenes OQ-CMC-18 — D&S SCRIPTED Category 8) | Caption keys: `cutscenes.caption.ct_05.tick_steady`, `tick_cessation`, `wire_cut`. Position within active letterbox image area (817 px on CT-05). **Other gameplay SFX** (footsteps, gunshots, alert-state stingers) are NOT captioned — covered by visual equivalents (HUD State Signaling alert-cue, footstep-component visual cue when in stealth). |
| Mono audio option | Comprehensive | OUT OF SCOPE — see Known Intentional Limitations | Not Planned | Spatial audio is Pillar 3 (Stealth as Theatre) load-bearing — directional enemy footsteps + 3D bomb tick are gameplay-critical signals. Mono audio output would degrade these signals; instead, **visual indicators** (HUD State Signaling alert-cue + footstep visual when AI within audible range + D&S Category 8 captions) provide the non-spatial fallback. |
| Independent volume controls | Basic | Music / SFX / Voice / UI buses | Designed (Settings G.3 + audio.md 4-bus architecture) | Four independent sliders (Music / SFX / Voice / UI). Range 0–100%, default 80%. Persist to player profile. Exposed in main settings + pause menu. |
| Visual representations for directional audio | Comprehensive (partial — alert state only) | Stealth AI alert-state + footstep visual when in stealth | Designed (HUD State Signaling alert-cue + footstep-component visual cue) | Alert-state visual indicators (HSS) cover the highest-stakes directional audio (enemy detected nearby). **Off-screen footstep audio** has visual equivalent only when player is in stealth crouch and footsteps are gameplay-critical (footstep-component §C). Full screen-edge directional audio indicator is NOT committed (Comprehensive-tier). |
| Hearing aid compatibility (low-frequency cues) | Standard | All audio cues | Designed (audio.md §G.3 frequency audit) | Hammond F-minor 2nd inversion bass note C2 (~65 Hz per Cutscenes A.4 audio-director correction) + Hardware-accurate device tick (~600-1200 Hz per Cutscenes audio Finding 2 recommendation) — neither relies on high-frequency cues alone. Voice bus EQ is mid-range (HANDLER VO HP 400 / LP 3200 Hz baked-asset per Cutscenes OQ-CMC-10) — within hearing-aid passband. |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Enemy alert-state stinger (Audio §States) | Stealth detection escalating | HUD State Signaling alert-cue (HSS REV-2026-04-26 D3 HARD MVP) | No — visual is sufficient | Designed |
| Footstep audio (player + AI) | AI position; player noise radius | Footstep-component visual cue when in stealth + HUD State Signaling alert-cue when AI is alerted | No — visual is sufficient when relevant | Designed |
| Document pickup chime (D&S audio cue Cluster A) | Document collected | HUD State Signaling MEMO_NOTIFICATION + HUD prompt-strip update | No — visual is sufficient | Designed |
| Gadget activation foley | Gadget used (per Inventory) | HUD Core gadget-slot tile state change + HUD prompt-strip | No — visual is sufficient | Designed |
| Save-failed audio | Save error | HUD State Signaling SAVE_FAILED state (margin-note Label) | No — visual is sufficient | Designed |
| Cutscenes Hammond chord (CT-05 only) | Atmospheric — no gameplay-critical state | None required (atmospheric) | No — atmospheric | Designed |
| Cutscenes wire-cut SFX (CT-05) | Bomb disarm executed | None — narrative-critical, not visual on first-watch | **YES** — D&S Category 8 caption `cutscenes.caption.ct_05.wire_cut` | Designed (OQ-CMC-18) |
| Cutscenes device-tick cessation (CT-05) | Bomb disarmed (the climactic narrative confirmation) | None — narrative-critical, not visual | **YES** — D&S Category 8 caption `cutscenes.caption.ct_05.tick_cessation` | Designed (OQ-CMC-18) |
| Cutscenes device-tick steady-state (CT-05) | Bomb is active (atmospheric stress) | Op-art op-art rings on sub-CanvasLayer 11 (visual atmospheric backup) | **YES** — D&S Category 8 caption `cutscenes.caption.ct_05.tick_steady` | Designed (OQ-CMC-18) |
| Period radio static + 3-blink Morse (mission_started SFX) | Mission begins | Briefing card hard-cut entry (visual is the dominant signal) | No — visual is sufficient | Designed |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Steam (PC — Linux + Windows) | Steam Accessibility Features / SDL | Controller input remapping via Steam Input (PC layer); subtitle support; adaptive-controller support via Steam Input templates | Designed | Steam Input allows system-level remapping independent of in-game remapping. In-game remapping still required for KB+M (Settings CR-22). Steam Deck verified is a soft target (not v1.0 commitment). |
| PC (Screen Reader) | Godot 4.5+ AccessKit / NVDA / Windows Narrator / Orca (Linux) | Menu navigation announcements + HUD state announcements (HUD Core polite live-region) + Cutscenes card announcements (assertive on hard-cut entry) + Document Overlay card announcements (assertive on open) | Designed (per UI.3 of Cutscenes + UI.3 of HUD Core + DOV ADR-0004 §IG7) | Requires UI elements to expose `accessibility_role`, `accessibility_name`, `accessibility_description`, `accessibility_live`. ADR-0004 Gates 1+2 still OPEN — engine-verification gates pending Godot 4.6 confirmation. **OQ-CMC-19 batch verification** scheduled. |
| Xbox (GDK) | Xbox Game Core Accessibility / XAG | N/A | Not Planned | No Xbox release planned. If post-launch port is considered, this row reactivates. |
| PlayStation 5 | Sony Accessibility Guidelines / AccessibilityNode | N/A | Not Planned | No PS5 release planned. |
| iOS / Android | UIAccessibility / TalkBack | N/A | Not Planned | No mobile release planned. |
| Linux Steam Deck | Steam Deck Accessibility | Soft target — verifies Standard-tier features work on Steam Deck input model (gamepad-only, no keyboard) | Aspirational | Verifies the gamepad-only path is complete; if gamepad rebinding is post-MVP per technical-preferences.md, Steam Deck Verified status is post-launch. |

---

## Per-Feature Accessibility Matrix

> When a new system is added to `systems-index.md`, a row must be added here. If a
> system has an unaddressed accessibility concern, it cannot be marked Approved
> in the systems index.

| # | System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|---|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| 1 | Player Character | Camera / FOV | Gamepad rebinding post-MVP | Movement-input cognitive load | None | Partial | Toggle-sprint Day-1 covers most motor; gamepad rebinding is Known Intentional Limitation |
| 2 | Input | None direct | Full remapping (KB+M MVP, gamepad post-MVP) | Conflict resolution UX | None | Designed | Settings 3-state rebind machine |
| 3 | Audio | None | None | None | All — owns 4-bus architecture, ducking, mono-fallback design | Designed | Independent volume sliders, period-mono mix register |
| 4 | Outline Pipeline | High contrast (Tier 1 stencil) | None | None | None | Designed (improves visual accessibility) |
| 5 | Post-Process Stack | Sepia-dim / fade-to-black + reduced-motion mode | None | Cognitive-overload during sepia? | None | Designed | Reduced-motion replaces sepia transition with hard-cut |
| 6 | Save / Load | None direct | None | Save-frequency cognitive load | Save-failed audio → HSS visual | Designed | F5 silently dropped during blocked contexts |
| 7 | Localization Scaffold | Text-length variants in non-English | None | None | None | Partial | Reading-speed test for non-English locales (GAP-4 Cutscenes) |
| 8 | Footstep Component | None | None | None | Spatial audio + visual equivalent in stealth | Designed | Visual cue when player in stealth |
| 9 | Level Streaming | None | None | Section-transition cognitive load | LSS fade audio | Designed | Hard-cut + crossfade |
| 10 | Stealth AI | Alert-state color-coding | None | Multi-actor parallel state tracking (HIGH cognitive load) | Alert-state stinger → HUD State Signaling alert-cue | Partial — high cognitive load flagged | Restaurant 12-AI scene = highest load; MVP-Day-1 reduced to 4-6 |
| 11 | Combat & Damage | Damage-flash photosensitivity | Aim assist tunable | Combat-resolution cognitive load | Audio damage-flash paired | Designed | `hud_damage_flash_enabled` opt-out HARD MVP |
| 12 | Inventory & Gadgets | Gadget-slot color (rarity) | Hold-to-charge → toggle alternative | Multi-gadget cognitive load | Gadget activation foley | Designed | Toggle alternatives per Settings CR-22 |
| 13 | Mission & Level Scripting | None direct | None | Quest cognitive load via dossier register | None | Designed | Mission Card briefings + Pause Menu mission tab |
| 14 | Failure & Respawn | Damage-flash photosensitivity | None | Respawn cognitive load | Respawn audio + HSS RESPAWN_BEAT | Designed | Photosensitivity toggle covers visual flash |
| 15 | Civilian AI | Panic-state visual | None | Multi-civilian parallel state tracking | Civilian VO + ambient | Partial | Restaurant 12-civilian = high load; reduced for VS |
| 16 | HUD Core | Color-coded health + crosshair toggle + scaling | None | HUD information density | Critical-state pulse paired with Audio | Designed | All Standard-tier features met + `hud_damage_flash_enabled` HARD MVP |
| 17 | Document Collection | Color-coded paper register (NOT color-only) | Pickup interact distance + height | Document quantity (21) cognitive load | Document pickup chime → HSS visual | Designed | 21 documents distributed 86% off-path (DC §C.5) |
| 18 | Dialogue & Subtitles | Subtitle contrast + size + 3 background modes | None | Caption-vs-HUD overlap (VG-DS-5 1.25× scale 1280×720) | All — owns subtitle rendering | Designed | Default ON, speaker labels, Courier Prime 28px |
| 19 | HUD State Signaling | Margin-note Label (NOT color-only) | None | 6-state visual cue cognitive load | All — visual equivalent for alert/save/respawn audio | Designed | HoH/deaf alert-cue HARD MVP |
| 20 | Document Overlay UI | Sepia-dim + reduced-motion variant + scrollbar | None | Reading-pace cognitive load | None (silence-cut to room-tone) | Designed | AccessKit dialog role + assertive on open |
| 21 | Menu System | Manila-folder color (NOT color-only) + scaling | Save card grid keyboard navigation | Multi-tab cognitive load | UI bus foley + reduced-motion alt | Designed | All key screens AccessKit-instrumented |
| 22 | Cutscenes & Mission Cards | Op-art cyan vs tritanopia + letterbox slide-in (reduced-motion variant) | `cutscene_dismiss` silent-drop UX + auto-dismiss timeout | First-watch-no-skip default + 5.0s closing-card reading time | All — D&S Category 8 captions for narrative SFX | Designed (post-cross-review revision 2026-04-28 night) | Stage-Manager carve-out + text_summary fallback + closed captions = 3 accessibility layers |
| 23 | Settings & Accessibility | Owns all visual accessibility features | Owns all motor accessibility features | Owns all cognitive accessibility features | Owns all auditory accessibility features | Designed | Day-1 minimum slice = HARD MVP DEP per HUD Core REV-2026-04-26 D2 |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated — `tools/ci/contrast_check.sh` (TBD) on all UI screenshots | All text/background combinations at all game states | Body text ≥ 4.5:1; large text ≥ 3:1; subtitle backgrounds ≥ 7:1 | ux-designer | Not Started (CI script TBD) |
| Colorblind modes | Manual — Coblis simulator on all gameplay screenshots with each mode enabled | Plaza, Lower, Restaurant, Upper, Bomb sections + HUD all states + Cutscenes CT-05 op-art + Document Overlay | No essential information lost in any mode; player can complete all objectives without color discrimination | ux-designer | Not Started |
| Input remapping | Manual — remap all 36 actions to non-default bindings, complete Plaza MVP | All default inputs rebound; gameplay functions correctly; no binding conflict possible | All actions accessible after remapping; conflict prevention works (Settings 3-state machine); bindings persist | qa-tester | Not Started |
| Subtitle accuracy | Manual — verify against `dialogue-writer-brief.md` 40-line roster | All voiced content per D&S §C + Cutscenes CT-04 HANDLER + D&S Category 8 CT-05 captions | 100% of voiced lines subtitled; speaker identified for all multi-character scenes; no caption display > 3 s after line ends; CT-05 captions render within 817 px letterbox area | qa-tester | Not Started (BLOCKED-on D&S Category 8 implementation per OQ-CMC-18) |
| Hold input toggles | Manual — enable Toggle-Sprint/Crouch/ADS, complete Plaza MVP | All hold inputs in toggle mode | All hold actions completable in toggle mode; no gameplay state requires sustained hold when toggle is enabled | qa-tester | Not Started |
| Reduced motion mode | Manual — enable mode, complete Plaza MVP + watch CT-03/CT-04/CT-05 | All menu transitions; HUD animations; camera shake events; Cutscenes letterbox slide-in (reduced-motion variant) | No looping animations in menus; no camera shake above threshold; CT-05 letterbox replaced with hard-cut variant | ux-designer | Not Started |
| Photosensitivity boot-warning | Manual — first-launch user flow | Warning modal fires before main menu; opt-out persists; CT-03 chromatic flash respects toggle | Modal appears at first launch; opt-out persists across sessions; CT-03 chromatic flash audited via Harding FPA standard | ux-designer | Not Started |
| Cinematic skip carve-out | Manual — enable `accessibility_allow_cinematic_skip`, watch CT-03/CT-04/CT-05 | First-watch skip with toggle ON / OFF | OFF: cinematic plays full (FP-CMC-2 default). ON: `cutscene_dismiss` honored at any time during cinematic. `triggers_fired` written regardless of skip. | qa-tester | Not Started (BLOCKED-on Settings OQ-CMC-17) |
| `text_summary_of_cinematic` accessibility fallback | Manual — enable `cinematic_text_summary_enabled`, watch CT-03/CT-04/CT-05 | Setting toggled per cinematic | Settings-gated text replaces cinematic; 3-5 sentences per cinematic; localized via `cutscenes.cinematic_summary.<ct_id>.*` keys | writer + qa-tester | Not Started (BLOCKED-on Cutscenes OQ-CMC-11 + Localization OQ-CMC-8) |
| AccessKit screen reader (menu + HUD + Cutscenes) | Manual — enable Linux Orca / Windows Narrator, navigate all menus + HUD overlays + Cutscenes cards | Main menu, settings, pause menu, inventory, map, Cutscenes Mission Cards, Document Overlay | All interactive menu elements have screen reader announcements; HUD state changes use polite live-region; Cutscenes hard-cut entry uses assertive announcement | ux-designer | Not Started (BLOCKED-on ADR-0004 Gates 1+2 + OQ-CMC-19 verification batch) |
| User testing — colorblind | User testing with colorblind participants (Discord communities / AbleGamers Player Panel if budget allows) | Full Plaza MVP session with each colorblind mode | Participants complete Plaza MVP without requesting color clarification; no session-stopping confusion | producer | Not Started — post-VS scope |
| User testing — motor impairment | User testing with participants using one hand or adaptive controllers | Full Plaza MVP session with toggle and aim-assist enabled | Participants complete Plaza MVP within tolerance of able-bodied completion time | producer | Not Started — post-VS scope |
| Reading-speed validation (GAP-4 Cutscenes) | Manual — non-English-locale playtester reads Mission Closing Card | Mission Closing Card 5.0 s gate test + Rome cliffhanger seed comprehension | Slow readers + non-English locales can read all body copy + REF: line within `cutscenes_dismiss_gate_closing_s` range [4.0, 8.0] | qa-tester | Not Started (BLOCKED-on Localization OQ-CMC-8 + non-English locale availability) |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader for in-game world (NPCs, environmental text, world objects) | Exemplary | Godot 4.6 AccessKit covers menu + HUD + UI overlays only; in-world spatial audio description requires custom system beyond v1.0 scope | Affects blind players who can navigate menus but cannot independently explore the game world | All critical world information duplicated in accessible Pause Menu (Mission tab + Inventory + Document Collection archive). Document Overlay UI provides text-readable equivalent of in-world documents. Cinematic content has `text_summary_of_cinematic` fallback. |
| Full subtitle customization (custom font / position / multiple color schemes) | Exemplary | Custom font rendering in Godot requires asset-pipeline work beyond solo-dev v1.0 scope | Affects deaf/HoH players with specific legibility needs (particularly dyslexia users with custom fonts) | Project ships 3 background modes (none / scrim / opaque) + size scale slider + speaker-label toggle (Settings G.3). Two preset styles cover ~80% of legibility needs per Game Accessibility Guidelines. Log for post-launch update. |
| Tactile/haptic alternatives for all audio cues | Exemplary | PC controllers have inconsistent haptic support; no Steam Deck / Xbox controller-only commitment at v1.0 | Affects deaf players relying on haptic feedback; PC players with non-Xbox/non-Steam-Deck controllers get no haptic response | Visual indicators (HUD State Signaling alert-cue + footstep visual + D&S Category 8 captions) provide non-haptic equivalent. Steam Deck haptic API integration is post-launch evaluation. |
| External third-party accessibility audit (AbleGamers Player Panel / Game Accessibility Nexus) | Exemplary | Cost-prohibitive for solo-dev v1.0 budget | No formal certification; affects player-trust signaling for accessibility-aware audiences | Post-launch evaluation. Project commits to internal audit + community feedback channel for v1.0; external audit considered post-v1.0 if revenue / community engagement justifies. |
| HUD element repositioning | Comprehensive | UI architecture work beyond solo-dev v1.0 scope | Affects players using head-tracking / eye-gaze hardware with reduced peripheral vision; affects ultrawide-monitor users | HUD anchoring is fixed per HUD Core §V; HUD scaling slider (75–150%) provides partial mitigation. Document for post-launch evaluation. |
| Difficulty assist modes (damage scaling, enemy aggression) | Comprehensive | Stealth-puzzle design has correct/incorrect solutions; granular difficulty would conflict with puzzle integrity | Affects players who cannot complete stealth-puzzle MVP at any difficulty | **Aim assist** (Settings G.3 `aim_assist_*` granular sliders) covers combat layer. **Multiple save slots + autosave + quicksave** cover retry tolerance. **`accessibility_allow_cinematic_skip`** covers cinematic-blocking failure mode. If post-launch playtest data shows MVP completion rate < 80% for accessibility-tier players, revisit. |
| Mono audio output | Comprehensive | Spatial audio is Pillar 3 (Stealth as Theatre) load-bearing — directional enemy footsteps + 3D bomb tick are gameplay-critical signals | Affects players with single-sided deafness; spatial audio cues degrade to L/R binary | Visual indicators (HUD State Signaling alert-cue + footstep visual + D&S Category 8 captions) cover the highest-stakes spatial audio cues. Aim-assist + quicksave mitigate competitive disadvantage. |
| Gamepad rebinding parity (post-MVP per technical-preferences.md) | Standard (technically required for full Standard tier) | Solo-dev scope reduction at MVP — KB+M rebinding ships first | Affects gamepad-only players + adaptive-controller users who need to remap default `cutscene_dismiss`, `interact`, etc. | Steam Input system-level remapping is the v1.0 mitigation (Steam Input templates allow controller-side remapping independent of in-game). Gamepad rebinding committed for VS scope per Settings OQ-SA-5 — must close before VS sprint. **`cutscenes_auto_dismiss_timeout_s`** (Cutscenes Finding 6) provides a fallback for adaptive-controller players who cannot produce default dismiss inputs. |
| Multiplayer / network accessibility (voice chat captions) | N/A | Game is single-player only per `game-concept.md` §Core Identity | None — feature does not exist | N/A |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-04-28 night | Internal — accessibility-specialist (`/design-review` cross-review on Cutscenes & Mission Cards) | Internal review (single-system) | Cutscenes & Mission Cards GDD #22 — 11-item accessibility audit | 4 BLOCKING items resolved inline (no first-watch skip → Stage-Manager carve-out; silent-drop screen-reader announcement → AccessKit polite live-region on gate-open; closed captions for narrative-critical SFX → D&S Category 8; text_summary_of_cinematic promoted from Polish-spike to MVP-recommended). 6 RECOMMENDED items: AccessKit role/announcement spec under-specified; reading-speed for non-English locales unverified; adaptive-controller auto-dismiss path; tritanopia documentation; HANDLER VO subtitle persistence vs D&S defaults; Settings GDD intersection enumeration. | All BLOCKING resolved; RECOMMENDED tracked in `design/gdd/reviews/cutscenes-and-mission-cards-review-log.md` |
| 2026-04-28 night | Internal — gate-check skill | Pre-Production gate audit | All 23 systems + ADRs + tests + UX | Blocker #4 = "design/accessibility-requirements.md MISSING — accessibility tier undefined" — closed by this document | Closed |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Foundational — contrast ratios, text sizing, input requirements |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist organized by category and cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing service (post-v1.0 evaluation) |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free tool for simulating colorblind modes on screenshots |
| Accessible Games Database | https://accessible.games | Research and examples of accessible game design decisions |
| Godot 4.6 Accessibility (AccessKit) | https://docs.godotengine.org/en/stable/tutorials/ui/accessibility.html | Engine API for `accessibility_*` properties (roles, names, live regions); ADR-0004 Gates 1+2 verification scope |
| Steam Deck Verified Programme | https://partner.steamgames.com/doc/deckverified | Soft target for Linux Steam Deck verification (post-v1.0) |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Godot 4.6 AccessKit support the full `accessibility_role` taxonomy used in the Per-Feature Matrix (DIALOG, STATUS, REGION, TEXT, HEADING, DOCUMENT, SCROLL_AREA)? | ux-designer + godot-specialist | Before VS sprint kickoff (per OQ-CMC-19 batch verification) | Unresolved — ADR-0004 Gate 1 verification still open |
| Does Godot 4.6 `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` constant name remain stable from 4.5 introduction? | godot-specialist | Before VS sprint kickoff (per VG-CMC-4) | Unresolved — engine-reference cross-check pending |
| Is the dual-focus split in Godot 4.6 `_unhandled_input` a hard requirement for `mouse_filter = MOUSE_FILTER_IGNORE` on all card-tree Controls? (per Cutscenes VG-CMC-2) | godot-specialist | Before VS sprint kickoff | Unresolved — editor verification gate |
| Will the `text_summary_of_cinematic` 3-5 sentence prose summary localize cleanly in German/French (~30% expansion) without exceeding the 817 px letterbox area? | writer + localization-lead | Before VS sprint review (per OQ-CMC-11 + GAP-4) | Unresolved — needs first translation pass |
| Should the `cutscenes_auto_dismiss_timeout_s` setting (default 0 / disabled) honor a global `accessibility_*_enabled` master toggle, or remain independent per-knob? | ux-designer + accessibility-specialist | Before VS sprint kickoff | Unresolved — UX architecture decision |
| Is internal audit sufficient for v1.0 launch, or should AbleGamers Player Panel engagement be budgeted? | producer | Before launch-checklist phase | Unresolved — budget evaluation |
