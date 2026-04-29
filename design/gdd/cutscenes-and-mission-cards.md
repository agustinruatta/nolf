# Cutscenes & Mission Cards

> **Status**: In Design
> **System**: #22 (Narrative / Presentation layer)
> **Phasing**: Pure Vertical Slice — no MVP slice (MVP ships silent on `mission_started`; no briefing card; no section-transition cinematics; no `InputContext.CUTSCENE`)
> **Author**: agustin.ruatta@vdx.tv + agents (`/design-system cutscenes-and-mission-cards`, solo review mode)
> **Last Updated**: 2026-04-28 night (post-cross-review revision pass — 16 BLOCKING items + FP-CMC-2 Stage-Manager carve-out applied)
> **Implements Pillar**: 5 (Period Authenticity Over Modernization) — load-bearing primary; Pillar 1 (Comedy Without Punchlines) + Pillar 4 (Iconic Locations as Co-Stars) — supporting
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED per solo mode (`.claude/docs/director-gates.md`)

## Overview

**Cutscenes & Mission Cards** is *The Paris Affair*'s **Vertical-Slice cinematic + title-card surface** — the system that turns mission-state transitions into Saul Bass-grammar punctuation between the player's micro-stealth-puzzles. As a **data layer** it owns: a per-section `CanvasLayer` scene at **index 10** (locked by **ADR-0004 §IG7** — mutually exclusive with Settings panel via lazy-instance discipline; the two surfaces' `CanvasLayer` nodes never coexist even if the InputContext gate is bypassed by a future bug); a **new `InputContext.CUTSCENE` enum value** added to `InputContext.Context` via **ADR-0004 amendment** (push at cutscene-start, pop at cutscene-end — mutually exclusive with `MENU` / `SETTINGS` / `DOCUMENT_OVERLAY` / `MODAL` / `LOADING` per **ADR-0004 §IG3** stack-discipline; **Mission Scripting cutscene triggers gate on `InputContext.current() == GAMEPLAY` per ADR-0004 L270**; **Save/Load CR-6 silent-drops F5 during `CUTSCENE`**); the **subscriber contract** to **Mission domain** signals declared in **ADR-0002** (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`) plus **`section_entered(reason)`** (LSS-published) — **subscriber-only, never an emitter** of Mission-domain signals (MLS sole-publisher per **MLS CR-7** + **CR-13 direct-reference anti-pattern fence**: MLS does NOT hold a reference to Cutscenes; if Cutscenes is absent in pre-VS builds, signals fire into void and gameplay beats still resolve); the **replay-suppression record** via **`MissionState.triggers_fired: Array[StringName]`** (ADR-0003 frozen schema, MLS-owned) — Cutscenes consults it on `game_loaded` and on `section_entered(reason)` to determine first-arrival firing (`reason == FORWARD` and beat not in `triggers_fired`) vs. suppression (`reason in {RESPAWN, NEW_GAME, LOAD_FROM_SAVE}` always suppress; `FORWARD` with beat already fired suppress); the **stencil escape-hatch** via `OutlineTier.set_tier` on specific meshes at cutscene-start with restoration on cutscene-end (per **outline-pipeline.md L226 + ADR-0001**) for the rare case a cinematic wants all-Tier-1 emphasis or all-outline-off; the **PPS lifecycle calls** `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` for narrative dim beats and a new fade-to-black API surface (PPS amendment per **OQ-PPS-2** resolution open at GDD authoring time); the **Audio track-swap orchestration** via the silence-cut allowance in **audio.md Crossfade Rule 6** ("Silence-cut only for mission-complete sting and cutscene track swap") plus the **SCRIPTED-cause stinger suppression** (audio.md §Concurrency Rule 3 — `force_alert_state(StealthAI.AlertCause.SCRIPTED)` produces NO stinger because cutscenes own their composed audio); the **localization key namespace** `cutscenes.*` in `translations/cutscenes.csv` per **localization-scaffold.md L132** with one-shot resolution at scene-trigger via `tr()` and `NOTIFICATION_TRANSLATION_CHANGED` re-resolve while a card is on-screen; and the **`ADR-0008` performance budget claims** — Slot 7 (UI 0.3 ms shared) when a card or letterbox is rendering and Slot 8 (residual 0.8 ms peak event-frame) for trigger-evaluation logic on Mission/Section signals. Cutscenes is **NOT autoload** per **ADR-0007** (autoload registry is full at slot #9 = MLS; Cutscenes is a per-section `CanvasLayer` scene instantiated lazily by Mission & Level Scripting per-section authoring and torn down on section unload — pattern analogous to HUD Core / Document Overlay UI). As a **player-facing surface** it is the **paragraph break** between Eve's stealth sentences: the briefing card that opens the mission with `OPERATION: PARIS AFFAIR — DOSSIER #PA-1965-441` set in Futura Extra Bold Condensed @ 36 px on Parchment with a hard-cut entry (per **Art Bible §3.7 — "Saul Bass title sequences cut; they do not wipe or cross-fade"**); the per-objective opt-in card triggered by `MissionObjective.show_card_on_activate: bool` (forward dep added to MLS GDD §C); the section-transition cinematics (Restaurant kitchen-explosion → Upper Structure transition; the bomb-disarm climactic sequence in the Bomb Chamber) that stage 3rd-person cinematic camera + scripted character animation + composed audio without quipping protagonist (per **Pillar 1 — Comedy Without Punchlines**); and the mission-complete card that closes `mission_completed` with a cliffhanger dossier stamp seeding the post-launch Rome arc. The card's typographic register is **BQA dossier letterhead** (Art Bible §3.3 + §7B): Futura Extra Bold Condensed for the title, American Typewriter Regular for the body, no rounded corners, no drop shadows, no glow (forbidden project-wide by **PPS CR-7** + **outline-pipeline.md FP-OP-3**), no inline icons, no body animation beyond the paper-translate-in motion shared with Document Overlay for visual coherence (Art Bible §7B). The cinematic register is **letterboxed 2.35:1** with hard top + bottom bars at `#0A0A0A` (Ink Black) sliding in over a 12-frame Tween, period-jazz score ducked to the cutscene track via Audio's silence-cut, and AI guards force-alerted into scripted poses via `StealthAI.force_alert_state(_, SCRIPTED)`. **Pillar fit**: Primary **5 (Period Authenticity Over Modernization)** is **load-bearing** — the entire Saul Bass / Futura Extra Bold Condensed / hard-cut grammar / no-skip-cinematic-by-default register IS the period authenticity proof; without the cards, *The Paris Affair* would feel like a 2026 indie stealth game rather than a 1965 spy comic; Supporting **1 (Comedy Without Punchlines)** is served by what cards refuse — no quippy protagonist, no AAA snark, no mission-complete fanfare ("**MISSION ACCOMPLISHED**" never appears on screen — the dossier reads `OPERATION: PARIS AFFAIR — STATUS: CLOSED`); Supporting **4 (Iconic Locations as Co-Stars)** is served by the section-transition cinematics that frame the Eiffel Tower's actual architecture (the Restaurant level's wrought-iron supports, the Upper Structure's antenna scaffold, the Bomb Chamber's pneumatic tubing). **Phasing**: this is a **pure Vertical-Slice system** — the **MVP ships silent on `mission_started`** (no briefing card, no per-section cinematics, no `InputContext.CUTSCENE` declared in code, no `cutscenes.csv`); MLS CR-13 explicitly defends the gameplay loop's resolution in the absence of this system. There is no MVP slice to phase out. **This GDD defines**: the cinematic + card scene structure on CanvasLayer 10; the lazy-instance discipline that prevents Layer 10 collision with Settings; the `InputContext.CUTSCENE` push/pop lifecycle and skip-grammar; the Mission-domain signal subscription contract (replay-suppression via `MissionState.triggers_fired`); the section-cinematic + briefing-card + objective-card + mission-complete-card content roster per Eiffel Tower section; the PPS + Audio + Outline + Localization integration call points; the `ADR-0008` Slot 7 + Slot 8 sub-claims; the Pillar-5 forbidden patterns that keep modern cinematic conventions (skip-by-default, "Press any key", subtitle bar overlap, fade-to-cross-cut, action-movie quippy beats) out; and the per-section per-card per-cinematic asset list. **This GDD does NOT define**: the Mission state machine or `MissionState.triggers_fired` schema (**Mission & Level Scripting #13** owns); the `mission_started` / `mission_completed` / `objective_started` / `objective_completed` / `section_entered` signal signatures (**ADR-0002 + MLS** own); the in-cutscene character dialogue lines (**Dialogue & Subtitles #18 SCRIPTED Category 7** owns via MLS `scripted_dialogue_trigger` — Cutscenes only owns title-card text and letterbox UI per the boundary clarified in §C); the Stealth AI alert state machine that `force_alert_state(_, SCRIPTED)` interacts with (**Stealth AI #10** owns); the Civilian AI panic / cower state machines that scripted scenes may override (**Civilian AI #15** owns); the `OutlineTier.set_tier` API or stencil-ID contract (**Outline Pipeline #4 + ADR-0001** own — Cutscenes only consumes the escape-hatch); the `enable_sepia_dim()` / sepia shader or per-pixel formula or fade-to-black implementation (**Post-Process Stack #5** owns — Cutscenes only calls the lifecycle API); the music duck dB values, cutscene-track route, or composed-audio file pipeline (**Audio #3** owns — Cutscenes only triggers track-swap signals); the `cutscenes.csv` asset format or string-table mechanics (**Localization Scaffold #7** owns — Cutscenes only uses `cutscenes.*` keys); the InputMap binding for cutscene-skip (**Input #2** owns — Cutscenes proposes the action name); the HUD visibility gate during `CUTSCENE` (**HUD Core #16 CR-10** owns its own `InputContext.current() != GAMEPLAY` check); the Subtitles auto-suppression rule (**ADR-0004 §IG5** + **Dialogue & Subtitles** own — D&S subscribes to `ui_context_changed` and self-suppresses); the cinematic 3rd-person camera rig or character cinematic animation pipeline (**Polish-or-later** — Cutscenes specs the trigger contract + skip lifecycle + asset slots; the actual cinematic cinematography is delegated to a future authoring pass with a level-designer + animation-tools handoff); the cutscene-skip Settings toggle (**explicitly out of scope for Settings & Accessibility** per settings-accessibility.md L1346 — Cutscenes owns its own skip behavior in §C); the case-file post-credits flashback / collected-document review (**Polish-or-later** per DC §E.12); the Tier 2 Rome / Vatican mission cinematics (**post-launch** per game-concept.md §Scope Tiers); and the cutscene-replay-from-Pause-Menu (**Polish-or-later** — `MissionState.triggers_fired` is the source of truth and is one-shot at MVP/VS).

## Player Fantasy

### Anchor: "The Title Sequence Drops"

**Player verb**: *the cinema asserts itself*. **Posture**: alert, briefly suspended, recognising "the film is talking now." **Register**: graphic-design-as-narration — typography, geometric shape, letterbox composition, and a single deliberate musical cue carry the emotional weight that a quipping protagonist would carry in a worse game.

**Pillar load**: **Pillar 5 (Period Authenticity Over Modernization)** is *load-bearing*. The Saul Bass / *Our Man Flint* / 1965 Air-France-poster title-sequence grammar is the *proof* of period authenticity — without these surfaces declaring themselves as 1965 cinema, *The Paris Affair* slips into the texture of a 2026 indie stealth game wearing 1960s clothes. The cards and cinematics are the **assertion** that this is a 1965 spy picture, made with the same authored confidence Saul Bass wielded for Otto Preminger. Pillar 1 (*Comedy Without Punchlines*) is supporting — the wit is in the *frame*, not in Eve's mouth; the cinema is winking, the protagonist is silent. Pillar 4 (*Iconic Locations as Co-Stars*) is supporting — section-transition cinematics frame the Eiffel Tower's actual architecture (the Restaurant level's wrought-iron supports, the Upper Structure's antenna scaffold, the Bomb Chamber's pneumatic tubing) as compositional subjects, not as backdrops.

### What the player feels when a card or cinematic plays

When the briefing dossier hard-cuts onto screen at `mission_started` — `OPERATION: PARIS AFFAIR — DOSSIER #PA-1965-441` set in Futura Extra Bold Condensed @ 36 px on Parchment, single Ink Black underline, held for a deliberate beat — the player should feel the same brief jolt of recognition they get when a Saul Bass main title cuts black-on-orange across the screen at the start of *The Man with the Golden Arm*. This is the picture *announcing itself*. When the bomb-disarm cinematic letterboxes in over a 12-frame Tween — Ink Black bars `#0A0A0A` sliding to occlude top and bottom of the frame — the player should feel the same posture-shift they'd feel watching *Our Man Flint*'s opening: leaning slightly back, alert to the composition rather than to character performance, ready to read what the *frame* is saying. Eve does not need to quip the joke because the **typography** is delivering it. Eve does not need to celebrate the win because the **composition** has already filed it. The cinema knows it's cinema.

### Five explicit refusals

The fantasy is **NOT**:

1. **NOT modern-AAA cinematic camera grammar.** No anime-style camera flourish, no slow-mo dolly-into-hero, no shaky-cam during action beats, no continuity-edited shot-reverse-shot. (Violates Pillar 5 — 1965 picture grammar predates that visual language entirely.)
2. **NOT a place for stinger reuse, victory fanfare, or musical swell.** Audio Crossfade Rule 6 applies: silence-cut to cutscene track is the rule, brass-stab on alert-state is suppressed (`audio.md` §Concurrency Rule 3 — `force_alert_state(StealthAI.AlertCause.SCRIPTED)` produces NO stinger). Cutscenes own their composed audio; the score does not signal "this is the dramatic part."
3. **NOT extradiegetic Eve commentary.** Eve does not narrate, voiceover, recap, or quip during cards or cinematics. (Violates anti-pillar: quip-heavy protagonist. The world quips around her, never her own voice in a frame the cinema owns.)
4. **NOT longer than 90 seconds per cinematic** (and most should be 30–60 s). Patience is for *observation* in gameplay, not for sitting through cutscenes that interrupt the loop. (Violates Pillar 2 — patience is observational currency, not a passive endurance test.)
5. **NOT a generic "stylish transition."** Every card and cinematic must be **period-coded** — Saul Bass / op-art / 1965 Air-France-poster / Steranko-era spy-comic — never abstract motion graphics, never modern-indie-game-cutscene template, never "stylized for stylized's sake." If the composition could appear in a 2024 stylish indie cinematic, redesign it. (Violates Pillar 5 the most directly — period authenticity is verified at the level of every individual frame composition.)

### Tonal-anchor question

When designing or reviewing any future card, cinematic beat, transition, or letterbox composition, the team must ask:

> *"Would Saul Bass or the Our Man Flint title designer sign their name to this composition?"*

If the answer is no, the composition is wrong for *The Paris Affair*'s cutscene register and must be redesigned. This is the single load-bearing fantasy test for §C content authoring, §V visual direction, and §H acceptance criteria.

### Reference vignettes (the fantasy in execution)

**Vignette 1 — `mission_started` Briefing Dossier (mission-arc opener).** Application boots into Plaza section. `mission_started` fires. Briefing card cuts in on a hard cut (no fade, per Art Bible §3.7 — "Saul Bass title sequences cut; they do not wipe or cross-fade"). Composition: full-screen Parchment ground `#F2E8C8`. Top quadrant: BQA Blue `#1B3A6B` strip 64 px tall with Futura Extra Bold Condensed white text "**BUREAU OF QUIET AFFAIRS — DOSSIER**." Center: Futura Extra Bold Condensed @ 36 px Ink Black "**OPERATION: PARIS AFFAIR**". Below: American Typewriter Regular @ 18 px subtitle "Mission #PA-1965-441 / Paris, France / Initiated 14 March 1965." Bottom: a single Ink Black underline rule. Held for 2.4 seconds. Hard cut to gameplay. No music sting, no Eve voiceover, no "Press any key." The card is *the page in the file*; Eve is already on the Plaza. The frame, not the protagonist, has briefed the player.

**Vignette 2 — Bomb Chamber climactic disarm (mission climactic cinematic).** Eve approaches the bomb device. `objective_completed("bomb_chamber_reached")` fires. Letterbox sweeps in over 12 frames (Ink Black bars `#0A0A0A` Tween in from top and bottom; HUD hides via `InputContext.current() != GAMEPLAY`). Camera transitions to 3rd-person low-angle. Op-art concentric circles bleed in behind the bomb on a separate canvas-sub-layer (Saturated Pop cyan + Ink Black, period-coded — *not* modern motion graphics). No dialogue. No score. Just a sustained Hammond organ chord and the *tick* of the device. Eve's gloved hand cuts the wire. Cut to black for 8 frames. Mission-completed card cuts in on a hard cut: "**OPERATION: PARIS AFFAIR — STATUS: CLOSED**" set in the same Bass typography, Parchment ground, single Ink Black rule, held for 2.4 seconds. Hard cut to credits or post-mission state. The frame, not the protagonist, has *delivered* the climactic line.

**Vignette 3 — Restaurant kitchen-explosion section transition (section-transition cinematic).** Eve plants the charge in the Restaurant kitchen, walks toward the door. `objective_completed("kitchen_charge_planted")` fires; MLS calls `LS.transition_to_section(upper_structure_id, …, TransitionReason.FORWARD)`. Letterbox sweeps in. Camera transitions to wide 3rd-person of the kitchen door from across the dining room. The door bulges. Plates rattle. Two waiters freeze mid-tray-balance (Civilian AI in scripted-cower state). No Eve smirk, no slow-mo, no walk-away-from-the-explosion shot. Hard cut to a section-transition card: "**SECTION 3 / RESTAURANT — CLEARED**" set in Futura Extra Bold Condensed, Parchment ground, single Ink Black underline. Held for 1.4 seconds. Cut to LSS fade-to-black. The explosion is *evidence in a report*, not a movie moment. The cinema, not the protagonist, has stamped the section closed.

### Fantasy test for future content

Before any new card, cinematic beat, transition composition, or letterbox sequence is approved:

1. **The Bass test**: would Saul Bass sign his name to this composition? (If no → redesign.)
2. **The quip test**: does Eve speak, narrate, or react with personality during this beat? (If yes → cut Eve's line; let the frame speak.)
3. **The 1965 test**: could this composition appear in *Our Man Flint*, *The Avengers*, or a vintage Air France travel poster? (If you cannot place it within 1965 visual culture → redesign.)
4. **The score test**: is the audio doing emotional signaling work the *composition* should be doing? (If yes → cut the swell; trust the frame.)
5. **The patience test**: is this beat under 90 seconds, and does it earn its interruption of the stealth loop? (If no → cut the beat or restructure.)

Cards and cinematics that fail any of the five tests are not Cutscenes & Mission Cards content; they are some other system's responsibility (Document Overlay, Dialogue, HUD prompt) or they should not ship.

## Detailed Design

### C.1 — Core Rules (CR-CMC-1..22)

**CR-CMC-1 — Subscriber-only discipline (MLS CR-7 alignment).** Cutscenes & Mission Cards subscribes to Mission-domain signals (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`) and to `section_entered(section_id, reason)` via the Signal Bus (ADR-0002). It **never emits** any of these signals and is never the publisher of any Mission-domain signal. `Events.mission_started`, `.mission_completed`, `.objective_started`, `.objective_completed` are MLS's sole published property per **MLS CR-7**; Cutscenes holds zero authority over them. Code-review forbidden pattern: any `Events.mission_started.emit(...)` or similar call inside any Cutscenes or MissionCard source file is a defect.

**CR-CMC-2 — Replay suppression via `MissionState.triggers_fired`.** At the start of every cutscene or section-transition cinematic, Cutscenes queries `MissionState.triggers_fired: Array[StringName]` (owned by MLS per **ADR-0003**) before the CanvasLayer is instanced. If the cinematic's `scene_id` is already a member of `triggers_fired`, the cinematic is silently dropped — no CanvasLayer, no InputContext push, no audio change. This check is performed synchronously, before any side effects, in the same frame the triggering signal fires. This is the sole replay-suppression gate for cinematics; it is read-only (Cutscenes never writes to `triggers_fired` — that is MLS's exclusive write path).

**CR-CMC-3 — First-arrival firing rule.** Section-transition cinematics (CT-03, CT-04) fire when **both** conditions hold: (a) `section_entered` was received with `reason == TransitionReason.FORWARD`, AND (b) the cinematic's `scene_id` is NOT in `MissionState.triggers_fired`. On any other `reason` value (`RESPAWN`, `NEW_GAME`, `LOAD_FROM_SAVE`), the check in CR-CMC-2 is bypassed entirely — no check needed, because the conditions in (a) simply do not hold and the cinematic branch is never entered.

**CR-CMC-4 — Unconditional suppression on non-FORWARD reasons.** On `section_entered(_, reason)` where `reason ∈ {RESPAWN, NEW_GAME, LOAD_FROM_SAVE}`, Cutscenes performs no cinematic evaluation. No per-cinematic check, no `triggers_fired` read, no CanvasLayer creation. The intent: section cinematics are first-arrival rewards, not re-run mechanics. A player who reloads a save mid-level sees the gameplay world, not the cinematic they watched on their first pass.

**CR-CMC-5 — InputContext.CUTSCENE push/pop must be paired 1:1.** At cutscene-or-card start: push `InputContext.CUTSCENE` to the context stack (**ADR-0004 §IG2** + Amendment A7 — to be added in this GDD's BLOCKING coord). At cutscene-or-card end (normal dismiss, timer dismiss, skip): pop `InputContext.CUTSCENE`. These two operations are always paired; no early return, no exception path, may skip the pop. If a cutscene is terminated by an error path (scene instantiation failure, etc.), the abort handler is responsible for calling the pop before returning. The stack must never be left in a permanently pushed state. Analogous discipline to Document Overlay UI CR-7's `ui_cancel` handling and LS's `InputContext.LOADING` abort recovery.

**CR-CMC-6 — InputContext.CUTSCENE blocks: F5 quicksave.** While `InputContext.CUTSCENE` is on the stack, `quicksave` (F5) is silently dropped per **Save/Load CR-6** (extended 2026-04-28 — `CUTSCENE` is explicitly in the excluded-context list). No toast, no queuing. The player must wait for the card or cinematic to end before F5 is honoured.

**CR-CMC-7 — InputContext.CUTSCENE blocks: pause menu.** While `InputContext.CUTSCENE` is on the stack, the `ui_menu` action (Esc / Start) does not open the Pause Menu. The Menu System's Pause entry-point checks `InputContext.current() == GAMEPLAY` before responding to the action (Menu System forward contract). Cutscenes does not need to enforce this itself — the context gate at Menu System is the enforcement site. No "pausing during a cutscene" state is possible.

**CR-CMC-8 — InputContext.CUTSCENE blocks: Document interact and Settings.** The Document Overlay UI interact gate (`ui_interact` on a document pickup zone) checks that the context is `GAMEPLAY` before activating (DC forward contract). Settings entry-point similarly requires `GAMEPLAY` or `MENU` context (Settings §C.3, forward contract). Both systems are blocked by the `CUTSCENE` context without any additional enforcement by Cutscenes itself.

**CR-CMC-9 — HUD auto-hide is HUD Core's responsibility.** HUD Core subscribes to `Events.ui_context_changed` and hides itself when context is not `GAMEPLAY` (**HUD Core CR-10**). Cutscenes does not call any HUD method directly to hide or show the HUD. The HUD's visibility state is an outcome of the InputContext push, not of a direct Cutscenes→HUD call. Cutscenes must never reference `HUDCore` or call `.visible = false` on it. **Boundary-frame ordering rule (per OQ-CMC-19, performance review 2026-04-28 night):** HUD Core's `_on_ui_context_changed` handler must complete its `visible = false` write + CR-22 `Tween.kill` calls *before* Cutscenes' first AnimationPlayer/Tween tick on the same frame. This prevents HUD Core + HSS Slot 7 peak (~0.306 ms) from overlapping with the Cutscenes Slot 7 onset on the cutscene-start frame. Implementation: HUD Core connects to `ui_context_changed` with default (synchronous) connection flag — no `CONNECT_DEFERRED` — and Cutscenes' first tick is in the *next* frame after the context push (Tween/AnimationPlayer is created in the same frame but advances starting next frame per Godot SceneTree dispatch order). The non-concurrency claim in §F.1 depends on this ordering; HUD Core CR-10 spec must echo this requirement.

**CR-CMC-10 — Subtitle auto-suppression is D&S's responsibility; Cutscenes owns title-card text only.** Dialogue & Subtitles subscribes to `Events.ui_context_changed` and self-suppresses when context is not `GAMEPLAY` (**ADR-0004 §IG5**, **D&S §F.3**) — **with two explicit exemptions during CUTSCENE context**: (a) **D&S SCRIPTED Category 7** (in-cutscene character dialogue, e.g., CT-04 HANDLER line) renders normally during CUTSCENE; (b) **D&S SCRIPTED Category 8** (NEW, per accessibility BLOCKING via OQ-CMC-18) renders captions for narrative-critical non-dialogue SFX during cinematics (CT-05 device-tick cessation, wire-cut). Cutscenes does not suppress subtitles; it does not call D&S methods. Cutscenes owns **title-card text only** (mission name, objective name, section label, classification stamps) rendered via its own Label nodes on CanvasLayer 10. **In-cutscene character dialogue lines (D&S SCRIPTED Category 7) are authored via MLS `scripted_dialogue_trigger(scene_id)` and owned by D&S** (**D&S §F.4 row 2**). **Non-dialogue narrative SFX captions (D&S SCRIPTED Category 8) are authored via MLS `scripted_caption_trigger(scene_id, caption_key)` and owned by D&S** — Cutscenes specifies the trigger points (CT-05 wire-cut frame, tick-cessation frame, etc.) but does NOT render captions itself. Caption render position must be within the active letterbox image area (817 px on CT-05) — D&S coord item OQ-CMC-18 specifies position-aware rendering. Cutscenes never writes subtitle/caption text to D&S's surface directly. This boundary clarification closes D&S L886 + L1399 forward-dep contradiction and addresses accessibility-specialist Finding 4 (closed-caption equivalent for narrative-critical SFX).

**CR-CMC-11 — Audio: silence-cut to cutscene track on start; crossfade-restore on end.** At cinematic start, AudioManager receives the cutscene's `scene_id` context via the Music bus state table entry `CUTSCENE` (**audio.md §States** → `MusicDiegetic` ducked to −80 dB; `MusicNonDiegetic` crossfade to `cutscene` track at Music bus). Cutscenes does not call AudioManager directly — instead, the new **`cutscene_started(scene_id: StringName)` signal** (added to ADR-0002 in a new Cutscenes domain via this GDD's BLOCKING coord, per audio.md L407 forward-dep note) drives AudioManager state. At cinematic end, **`cutscene_ended(scene_id: StringName)`** fires and AudioManager resumes section music via standard `music_crossfade_default_s` crossfade (**2.0 s**, audio.md Tuning + Crossfade Rule 6). Cutscenes holds no direct reference to AudioManager.

**CR-CMC-12 — SCRIPTED-cause stinger suppression.** When a cinematic calls `StealthAI.force_alert_state(guard, StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SCRIPTED)` for scripted choreography (e.g., CT-03 kitchen explosion reveals a guard), no `MusicSting` brass stab is scheduled (**Audio Concurrency Policy 3** — `cause == SCRIPTED` suppresses the stinger). The `alert_state_changed` handler fires normally (music-state transitions during cinematics are expected) but the stinger is suppressed. Cutscenes is responsible for authoring the `AlertCause.SCRIPTED` cause in its force-alert calls; using any other cause is a defect that will produce unintended audio stabs over scripted narrative music.

**CR-CMC-13 — Anti-pattern fence: no direct cross-system references.** Cutscenes holds no direct node references to: MLS (no `get_node("/root/MissionScripting")`), HUD Core or HUD State Signaling, AudioManager, Dialogue & Subtitles, Combat systems, Stealth AI node trees, Civilian AI, Inventory, Document Collection, or Document Overlay. All inter-system coordination flows exclusively through the Signal Bus (**ADR-0002**). The only permitted exceptions are: (a) read of `MissionState.triggers_fired` at cutscene-start via `MissionLevelScripting.get_mission_state()` accessor (CR-CMC-2) — this is a Resource read, not a live-node reference; (b) call to `OutlinePipeline.set_tier()` / `restore_prior_tier()` per CR-CMC-14; (c) call to `PostProcessStack.enable_sepia_dim()` / `enable_fade_to_black()` per CR-CMC-22. Code-review forbidden pattern: any `get_node` call in Cutscenes GDScript targeting an autoload path other than `Events`, `MissionLevelScripting` (read-only accessor), `OutlinePipeline`, or `PostProcessStack`.

**CR-CMC-14 — Outline tier: save-restore discipline.** At cinematic start, Cutscenes MAY call `OutlinePipeline.set_tier(OutlineTier.NONE)` (per **outline-pipeline.md L226** escape-hatch + **ADR-0001**) to disable the outline post-process during letterboxed cinematics. At cinematic end — regardless of how the cinematic ended (timer, skip, abort) — Cutscenes MUST restore the previous outline tier via `OutlinePipeline.restore_prior_tier()`. It is never acceptable to leave outline state mutated across a cinematic boundary. Enforcement: the cinematic's `_cleanup()` function, called from all exit paths, is the sole site of `restore_prior_tier()`. Code review must verify the call appears in every exit path.

**CR-CMC-15 — Localization: keys-only at render time + live re-resolve.** All visible strings on Mission Cards and objective cards are LocalizationScaffold keys (`StringName`), never hardcoded English. Labels on card nodes are set with `label.text = tr(key)` at instantiation. `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` is set on all card Label nodes (NOT `ALWAYS` — manual `_notification` handler is the resolution path; see C.11). If `NOTIFICATION_TRANSLATION_CHANGED` fires while a card is on-screen (locale switch mid-display, possible via Settings language switcher), all card Labels re-resolve their current key via the notification path without requiring the card to be rebuilt. Cutscenes never embeds a raw English string in any card text field. **CR-CMC-15 closes Localization GDD forward-dep contract per L132 + L186.**

**CR-CMC-16 — Lazy-instance discipline + section-root parenting.** The CanvasLayer 10 node (Cutscenes root) is created at cutscene-or-card start and freed at section unload via section-root teardown. The CanvasLayer is **parented to the section root node** (NOT to MLS autoload, NOT to the tree root) — instantiated by MLS as a child of the section scene at section load. This matches Document Overlay UI CR-13 exactly. The section root is freed on `section_exited`, which frees the CanvasLayer with it — no manual cleanup needed beyond the MLS-owned `queue_free` pass. The CanvasLayer must never coexist with the Settings panel (Settings pushes `InputContext.SETTINGS`; the CUTSCENE context gate prevents any card from launching while Settings is open, and vice versa — the one-active invariant in CR-CMC-17 enforces this further). Rationale: lazy-instance + section-scoped parenting keeps the scene tree clean during gameplay and avoids the Settings-panel CanvasLayer-10 collision.

**CR-CMC-17 — One-active invariant: drop, do not queue.** At most one cutscene or Mission Card may be active at any moment. If a second trigger fires (any combination of `mission_started`, `objective_started`, cinematic beat) while `InputContext.CUTSCENE` is already on the stack, the second trigger is **silently dropped** — it is not queued. Rationale: a per-objective card that arrives 30+ seconds after the objective was already activated is no longer the right card for the moment (Pillar 2: Discovery Rewards Patience — a stale card is a noise card). Same-frame conflicts resolve by priority: **Mission Card > Cinematic > Objective Card** (see C.3). The priority check is evaluated at trigger time using the current InputContext state as the enforcement mechanism: if context is already `CUTSCENE`, the lower-priority trigger is dropped without evaluation. Drops are logged in debug builds with `push_warning("[Cutscenes] card/cinematic drop: [scene_id] — context was already CUTSCENE at dispatch time")` to assist LD authoring diagnostics.

**CR-CMC-18 — Letterbox 2.35:1 reserved for CT-05 exclusively.** The 2.35:1 black-bar letterbox is applied only for the mission-climactic cinematic CT-05 (bomb-disarm, 25–30 s). All other surface types (Mission Cards, objective cards, CT-03, CT-04) render at full viewport without letterbox bars. This is an art-director enforcement rule (**FP-V-CMC-9**) and is structurally enforced: only `CT_05_BombDisarm` cinematic resource sets `letterbox: bool = true`; the CutscenePlayer node tree conditionally creates letterbox `ColorRect` nodes only when `letterbox == true` on the resource. Rationale: the letterbox is the game's once-earned cinematic upgrade; reserving it for the single most consequential beat preserves its compositional power. (User decision Q1, 2026-04-28 night.)

**CR-CMC-19 — Entry transitions: hard-cut for cards, hard-cut to black for cinematics.** Mission Cards (briefing and closing) use a **hard cut** — no fade, no paper-translate, no scale animation. The card appears on the frame the trigger fires and disappears on the frame of dismiss. Per-objective opt-in cards use a **paper-translate-in** (8-frame Tween from below, `TRANS_SINE` `EASE_OUT` per Art Bible §7D) coherent with Document Overlay paper-in motion. Cinematics use a **hard cut to black** at start (no fade-out from gameplay — the cut IS the cut) and a **hard cut reveal** at end. There are no dissolves, no crossfades on the card entry/exit. The Mission Closing Card uniquely uses a **24-frame fade-to-black exit** (ColorRect alpha 0→1, linear) before cutting to credits or post-mission state — this is the only fade in the system and is reserved for the mission-end transition. Rationale: Saul Bass title-card aesthetic; hard cuts read as period-confident composition.

**CR-CMC-20 — Eve never narrates or vocalises in cutscenes.** No VO line attributed to Eve Sterling (`PROTAGONIST` / `[STERLING.]` speaker category per D&S §C.8) may play during any Mission Card, objective card, or cinematic. This is an absolute enforcement of **Pillar 1 (Comedy Without Punchlines)**: the frame carries the wit; the protagonist does not editorialize. Mission Cards display mission titles and section labels. Cinematics may contain guard / civilian / handler VO (D&S SCRIPTED Category 7 via MLS `scripted_dialogue_trigger`) — the explicit one exception is **CT-04 The Rappel**'s `[HANDLER]: Sterling. Clock is running.` line where the HANDLER (off-screen radio voice) speaks; Eve's response is silence. Code-review forbidden pattern: `speaker == &"PROTAGONIST"` in any dialogue line triggered from a Cutscenes-authored MLS beat.

**CR-CMC-21 — Cutscene state is included in save capture (via MissionState.triggers_fired).** `MissionState.triggers_fired` (owned by MLS, read by Cutscenes) includes the `scene_id` of every cinematic and card that has completed on this save. MLS writes to this array when a `cutscene_ended(scene_id)` signal is received. Cutscenes does not write to `triggers_fired` directly. On `game_loaded`, Cutscenes subscribes to `Events.game_loaded` and confirms its replay-suppression gate is consistent with the loaded `MissionState.triggers_fired` state (CR-CMC-2 read is re-validated on load; no cinematic that appears in `triggers_fired` will re-fire). **CR-CMC-21 closes Save/Load L107 + L162 forward-dep contract.**

**CR-CMC-22 — PostProcessStack lifecycle: separate fade-to-black API.** Cutscenes invokes two distinct PPS lifecycle calls: `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` for narrative dim beats during Mission Briefing card display (warm amber tint, Document Overlay register), and the new **`PostProcessStack.enable_fade_to_black(duration_s: float)` / `disable_fade_to_black(duration_s: float)`** API pair (added via PPS GDD amendment per this GDD's BLOCKING coord) for cinematic fade-to-black transitions (CT-05 entry, Mission Closing Card entry). Sepia-dim is *NOT* repurposed at maximum intensity for fade-to-black — the two effects are visually distinct (sepia = warm amber tint, fade = neutral black) and live as independent PPS state machines. (User decision Q4, 2026-04-28 night.)

---

### C.2 — Skip and Dismiss Grammar

**Design principle.** **Pillar 5 (Period Authenticity Over Modernization)** is the load-bearing constraint. A "Press any key to continue" prompt is a modern UX convenience that does not belong in a 1965 spy-comedy aesthetic. The skip grammar must feel like a period theatre: the curtain opens, the scene plays, the curtain closes. The player may acknowledge when the moment is ready to release them — not before.

#### C.2.1 Card dismiss-gate hold (silent drop before gate expiry)

| Surface | Dismiss-gate duration | After gate |
|---|---|---|
| Mission Card — briefing | **4.0 s** | `cutscene_dismiss` (Esc / B) dismisses |
| Mission Card — closing | **5.0 s** | `cutscene_dismiss` dismisses (then 24-frame fade-to-black to credits) |
| Per-objective opt-in card | **3.0 s** | `cutscene_dismiss` dismisses |

Before the dismiss-gate expires, pressing Esc or B is **silently dropped**. No "you must wait" message, no visual feedback, no sound. The keypress is consumed and discarded per the established silent-drop convention (Save/Load CR-6; Document Overlay UI CR-7 `ui_cancel` discipline). This approach is chosen over a "greyed-out button" or progress bar because those UI patterns break the Saul Bass / period-card aesthetic (**FP-CMC-3**: no "Press any key" prompt). The player learns the rhythm by observing it once; from then on it is legible.

The dismiss gate is implemented via `SceneTree.create_timer(duration, true)` (the `process_always = true` argument ensures the timer fires regardless of any future `SceneTree.paused` state). On timer fire, the per-card `_dismiss_gate_active` boolean clears and Esc/B input is honoured. (User decision Q3, 2026-04-28 night.)

#### C.2.2 No mid-cinematic skip on first-watch (default) — accessibility carve-out

**Default (Pillar 5 absolute, shipping default):** On first arrival (`scene_id` NOT in `triggers_fired`), cinematics CT-03 / CT-04 / CT-05 are **watched in full**. There is no skip surface during first-watch. The dismiss-gate concept does not apply to cinematics; cinematics are not interactive during playback. Rationale: CT-05 is 25–30 s — short enough that the design can assert the player watches it. Pillar 5 demands cinematics earn their interruption; the first-watch rule is that demand made concrete. (User decision Q3, 2026-04-28 night — locked.)

**Accessibility carve-out (Settings-gated, default off):** Anchored to the Combat §B Stage-Manager precedent (creative-director adjudication, 2026-04-28 night re-review). To address the WCAG 2.1 SC 2.2.1 / SC 2.2.2 / SC 2.1.1 gap surfaced by the cross-review (`text_summary_of_cinematic` is the complementary fallback per OQ-CMC-11), Settings & Accessibility introduces an opt-in toggle `accessibility_allow_cinematic_skip: bool` (default `false`). When `true`, the `cutscene_dismiss` action is honored at any time during cinematic first-watch via the same handler in §C.2.4 — the InputContext.CUTSCENE pop and `_cleanup()` path fire identically to a card dismiss. When the toggle is `false` (shipping default), this rule is absolute as stated above. Cutscenes reads the setting via `Settings.get("accessibility", "cinematic_skip_enabled")` at cinematic-start (cached for the cinematic's lifetime so a mid-cinematic Settings change doesn't fire a half-skip). The accessibility carve-out does **not** alter `triggers_fired` write semantics: a skipped cinematic is still recorded as fired (preventing replay-on-respawn). This carve-out preserves Pillar 5 as the default while honoring accessibility as an explicit player choice — the same posture used in Combat §B for failure-state surfaces. Coord item: **OQ-CMC-17** (settings-accessibility.md amendment) — BLOCKING.

#### C.2.3 Skip on subsequent watches: not applicable

CR-CMC-4 establishes that cinematics do not replay on `RESPAWN`, `NEW_GAME`, or `LOAD_FROM_SAVE`. There is therefore no "re-watch" surface during normal play. If a player intentionally loads an earlier save to re-experience a cinematic that had already fired on that save slot, the cinematic would appear in `triggers_fired` on that slot, and CR-CMC-2 would suppress it. **Practical outcome**: there is no scenario in which a cinematic plays a second time in a normal play session. The first-watch-no-skip rule is the only rule needed; a separate skip-on-rewatch rule is moot.

#### C.2.4 Input action naming: `cutscene_dismiss`, not `ui_cancel`

The dismiss action is bound to a dedicated InputMap action named **`cutscene_dismiss`** (default: keyboard Esc, gamepad B/Circle). **Not** `ui_cancel`. Rationale: `ui_cancel` also opens the Pause Menu. During a card, `InputContext.CUTSCENE` is on the stack and blocks `ui_cancel` from reaching the Pause Menu entry-point (CR-CMC-7); but using the same action name creates an action-routing ambiguity that would require a fragile context-check at the handler. A dedicated `cutscene_dismiss` action is unambiguous: it exists solely to dismiss cards after the gate expires. It does not interact with pause or any other system. The `cutscene_dismiss` action is registered in the **Input GDD's action catalog (forward coord item: Input GDD must add this action entry).**

The `_unhandled_input` handler:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not InputContext.is_active(InputContext.Context.CUTSCENE):
        return
    if not event.is_action_pressed(&"cutscene_dismiss"):
        return
    if _dismiss_gate_active:
        get_viewport().set_input_as_handled()
        return  # silent drop
    _dismiss()
    get_viewport().set_input_as_handled()
```

---

### C.3 — One-Active Invariant and Priority Resolution

**Invariant.** At most one Cutscenes surface (Mission Card, objective card, or cinematic) may be active simultaneously. "Active" means `InputContext.CUTSCENE` is on the stack. The invariant is enforced mechanically by the InputContext check: any trigger handler's first operation is to check whether context is already `CUTSCENE`; if so, it returns immediately (drop, not queue).

#### C.3.1 Priority table

| Priority | Surface | Drop rule |
|---|---|---|
| 1 (highest) | **Mission Card** (briefing / closing) | Never dropped unless context is already `CUTSCENE` from a higher-priority source |
| 2 | **Section-transition or mission-climactic Cinematic** | Dropped if Mission Card is active |
| 3 (lowest) | **Per-objective opt-in card** | Dropped if any higher-priority surface is active |

#### C.3.2 Same-frame conflict — `mission_started` + `objective_started`

If both fire in the same frame (which MLS's synchronous emission model allows, since `section_entered` could trigger both via a scripted MLS beat), Mission Card wins. The `objective_started` handler runs, checks context = `CUTSCENE` (set by the `mission_started` handler which ran first in the same frame's signal dispatch order), and drops. The MLS signal dispatch order within the same physics frame is: `mission_started` is processed before `objective_started` because `mission_started` fires at mission initialisation and `objective_started` fires as the first objective activates; in MLS's synchronous model these fire sequentially, and by the time `objective_started` reaches Cutscenes, the `mission_started` Mission Card has already pushed the context.

#### C.3.3 Cinematic active + objective card fires

Same mechanism: objective card handler checks context = `CUTSCENE`, drops silently. The objective card for the beat that triggered CT-03 will never appear — this is correct authoring discipline: the LD must not place a `show_card_on_activate = true` objective on the same beat as a cinematic trigger.

#### C.3.4 Do not queue: rationale

Queuing creates temporal displacement — a card that arrives after the delay is no longer contextually appropriate (Pillar 2). A 30-second delayed objective card serves neither Discovery nor Patience; it disrupts the player's present moment with a stale past event. Drops are logged in debug builds (CR-CMC-17 push_warning) to assist LD authoring diagnostics.

---

### C.4 — Per-Section Content Roster

**Total VS scope**: 2 Mission Cards + 2 Per-Objective Opt-In Cards (1 VS2-reserved slot) + 2 Section-Transition Cinematics + 1 Mission-Climactic Cinematic = **7 authored beats**. (User decision Q2, 2026-04-28 night — 2 cards locked + 1 reserved.)

#### C.4.1 Mission Briefing Card

| Field | Value |
|---|---|
| Surface | Mission Card |
| Trigger signal | `mission_started` |
| Condition | Unconditional — fires on mission load, before player control. **LSS clearance ordering (per ux-designer cross-review 2026-04-28 night)**: `mission_started` MUST fire AFTER LSS pops `InputContext.LOADING` and the LSS fade overlay (CanvasLayer 127) has cleared. MLS guarantees this ordering by emitting `mission_started` from a deferred call queued in the same frame as `section_loaded(plaza_id, FORWARD)`, ensuring the LSS overlay clears one frame before the briefing card hard-cuts in. This prevents a transient gameplay-frame flash between LSS overlay clearance and Cutscenes' CUTSCENE push. Coord item: MLS GDD §C amendment (added to OQ-CMC-6). |
| `scene_id` | `&"mc_briefing_paris_affair"` |
| Card title | `OPERATION: PARIS AFFAIR` |
| Body | BQA SECTION 4 — FIELD DIRECTIVE PA-65-001 / PARIS, FRANCE. 14 JUNE 1965. / [3 lines: PHANTOM biochemical device + Eiffel Tower confirmed + 20:00 hours detonation] / [2 lines: Agent directive + civilian management] / AUTHORISED: SECTION 4 DIRECTOR / CLASSIFICATION: EYES ONLY |
| Hold duration | 4.0 s dismiss-gate (Esc/B silently dropped before; dismisses after) |
| Composition | Hard-cut entry; full-screen Parchment with BQA Blue header strip + Futura Extra Bold Condensed @ 36 px title + American Typewriter Regular body + classification stamp `CLASSIFIED — BQA EYES ONLY` rotated −5° bottom-right |
| Pillar fit | Pillar 5 (1965 intelligence-service language); Pillar 1 ("managed accordingly" understatement) |

#### C.4.2 Mission Closing Card

| Field | Value |
|---|---|
| Surface | Mission Card |
| Trigger signal | `mission_completed` |
| Condition | Unconditional — fires after CT-05 climactic ends |
| `scene_id` | `&"mc_closing_paris_affair"` |
| Card title | `OPERATION: PARIS AFFAIR — STATUS: CLOSED` |
| Body | BQA SECTION 4 — FIELD REPORT PA-65-001 / PARIS, FRANCE. 14 JUNE 1965. 19:58 HRS. / Device rendered inoperative. Tower secured. / PHANTOM cell neutralised. No BQA casualties. / Agent extraction confirmed via Embassy contact. / CLASSIFICATION: EYES ONLY / STATUS: CLOSED / [REF line — see C.7 Rome cliffhanger seed] |
| Hold duration | 5.0 s dismiss-gate; then 24-frame fade-to-black to credits |
| Composition | Hard-cut entry; same dossier letterhead grammar as briefing; closing stamp `MISSION CLOSED — FILE TO ARCHIVE` |
| Pillar fit | Pillar 1 (closing has no triumph language); Pillar 2 (`IT-65-002` REF rewards observant readers); Pillar 5 (`STATUS: CLOSED` over modern equivalent) |

#### C.4.3 Per-Objective Opt-In Cards

**Card OBJ-1 — The Telephone (Lower Scaffolds)**

| Field | Value |
|---|---|
| Surface | Per-objective card |
| Trigger signal | `objective_started` for `objective_id == &"find_bomb_device"` AND `MissionObjective.show_card_on_activate == true` |
| `scene_id` | `&"oc_find_bomb_device"` |
| Card title | `PHANTOM FIELD EQUIPMENT — ITEM OF INTEREST` |
| Body | "Intelligence indicates PHANTOM is operating a / portable signal-detection unit disguised as a / standard telephone handset." / "Field agents are reminded that PHANTOM / procurement favours theatrical concealment." |
| Hold duration | 3.0 s dismiss-gate |
| Composition | 720 × 200 px slide-in from bottom (8-frame Tween); BQA Blue 36 px header + American Typewriter Regular 16 px body |
| Pillar fit | Pillar 2 (describes object without depicting it); Pillar 4 (Tower architecture context); Pillar 5 (intelligence-brief framing) |

**Card OBJ-2 — The Radio Cipher (Upper Structure)**

| Field | Value |
|---|---|
| Surface | Per-objective card |
| Trigger signal | `objective_started` for `objective_id == &"intercept_cipher"` AND `MissionObjective.show_card_on_activate == true` |
| `scene_id` | `&"oc_intercept_cipher"` |
| Card title | `COMMUNICATIONS INTERCEPT — STANDING ORDERS` |
| Body | "PHANTOM field units are known to use a / one-time pad cipher rotating on the hour." / "Current intercept window: 14 minutes. / Decryption materials are on Agent's person." / "Field discretion applies." |
| Hold duration | 3.0 s dismiss-gate |
| Composition | Same as OBJ-1 |
| Pillar fit | Pillar 3 (stealth as discretion); Pillar 5 (period signals-intelligence vocabulary); Pillar 1 ("field discretion applies" understatement) |

**Card OBJ-3 — VS2 RESERVED slot (Upper Structure)**

`show_card_on_activate` defaults to `false` until VS2 objective set is finalised and content is authored. Authoring deferred to VS2 sprint.

#### C.4.4 Section-Transition Cinematic Roster

| Transition | Cinematic? | Rationale |
|---|---|---|
| Plaza entry (mission start) | No cinematic | Mission opens mid-operation; Eve does not arrive, she is already there |
| Plaza → Lower Scaffolds | **Silent LSS fade** | Spatial descent, no dramatic register change. Withholding cinematic here makes Restaurant reveal land harder |
| Lower Scaffolds → Restaurant | **Silent LSS fade** | Same logic: accumulate tension without spending budget |
| Restaurant → Upper Structure | **CT-03 Kitchen Egress** | See below |
| Upper Structure → Bomb Chamber | **CT-04 The Rappel** | See below |

#### C.4.5 CT-03 — Kitchen Egress (Restaurant → Upper Structure)

| Field | Value |
|---|---|
| Surface | Section-transition cinematic |
| Trigger signal | `section_entered(upper_structure_id, FORWARD)` AND `objective_completed("kitchen_charge_planted")` already in `triggers_fired` |
| `scene_id` | `&"ct_03_kitchen_egress"` |
| Duration | 12–15 s |
| Letterbox | NO (full-frame) |
| Description | Demolition charge Eve set earlier detonates in kitchen service corridor — practical egress that removes a guard post and opens a maintenance shaft. Cinematic is staged as consequence, not action beat. Cut to shaft entrance. Kitchen already in motion. Eve moves through it without looking back. Comedy is that the explosion is incidental to her route — not the point, simply the method. |
| Embedded card | `CHARGE: SET` per-objective card fires at detonation frame with 1.0 s dismiss-gate hold inside the cinematic — bureaucratic acknowledgment of an active explosion dismissed in 1 second IS the joke (Pillar 1) |
| Pillar fit | Pillar 1 (comedy in disproportion); Pillar 3 (stealth is theatre); Pillar 4 (real Tower kitchen + maintenance shaft) |

#### C.4.6 CT-04 — The Rappel (Upper Structure → Bomb Chamber)

| Field | Value |
|---|---|
| Surface | Section-transition cinematic |
| Trigger signal | `section_entered(bomb_chamber_id, FORWARD)` AND not in `triggers_fired` |
| `scene_id` | `&"ct_04_the_rappel"` |
| Duration | 18–22 s |
| Letterbox | NO (full-frame) |
| Description | Eve clips a rappel line to the structural rail — not dramatically, procedurally, the way a person does something they have done before. Camera stays wide. Paris at dusk below. Tower's geometry dominates the frame. Halfway down, the HANDLER line fires. |
| In-cinematic VO | `[HANDLER]: Sterling. Clock is running.` (single line via MLS `scripted_dialogue_trigger("ct_04_handler_line")` → D&S SCRIPTED Category 7) |
| Eve response | Silence. She descends. |
| Pillar fit | Pillar 4 (Tower earns wide shot — Iconic Location moment); Pillar 1 (HANDLER's most alarmed line; Eve's non-response is the wit); Pillar 5 (no quip, no acknowledgment) |

#### C.4.7 CT-05 — Bomb Disarm (Mission-Climactic)

| Field | Value |
|---|---|
| Surface | Mission-climactic cinematic |
| Trigger signal | Custom MLS `mission_climactic_triggered` OR `objective_completed("bomb_chamber_reached")` AND not in `triggers_fired` |
| `scene_id` | `&"ct_05_bomb_disarm"` |
| Duration | 25–30 s |
| Letterbox | **YES — 2.35:1, EXCLUSIVELY this cinematic** (CR-CMC-18 / FP-V-CMC-9) |
| Description | Close on device casing — mundane, almost bureaucratic object. Eve's hands enter frame. No music crescendo; held single Hammond chord (not a swell). Concentric circle op-art motif on sub-CanvasLayer at index 11 (saturated cyan + Ink Black, period-coded). She works. Counter reads `00:02` when she disconnects final lead. Cut to black for 8 frames. Mission Closing Card fades in. |
| Pillar fit | Pillar 1 (climax underplayed); Pillar 3 (stealth is theatre — theatrical restraint); Pillar 4 (Tower not shown — earned in CT-04; Bomb Chamber confined makes stakes intimate not spectacular); Pillar 5 (Saul Bass register inscribes the climax) |

---

### C.5 — Title-Card Text Rules (TR-1..TR-10)

**TR-1.** All card titles use ALL-CAPS. Body copy uses Title Case for proper nouns and ALL-CAPS for BQA classification markers (`EYES ONLY`, `STATUS: CLOSED`, `PHANTOM`). No mixed-register headers.

**TR-2.** Mission codename always appears as `OPERATION: PARIS AFFAIR` — colon after `OPERATION`, no quotes, no definite article. The colon is typographic, not grammatical.

**TR-3.** All reference numbers follow the pattern `XX-YY-NNN` where `XX` is the country ISO code, `YY` is the two-digit year, and `NNN` is the sequential case number. Paris mission: `PA-65-001`. Rome seed: `IT-65-002`. Numbers appear in routing lines only — never in card titles.

**TR-4.** No exclamation marks on any card surface or in any in-cinematic caption. Period or restructure.

**TR-5.** Cards do not address the player or the protagonist in second person. No "you must," no "your objective," no "Eve needs to." Passive bureaucratic construction only: "Agent is to locate," "Device is to be rendered inoperative."

**TR-6.** No status line reads "MISSION ACCOMPLISHED," "SUCCESS," "OBJECTIVE COMPLETE," or any modern-action-game equivalent. Terminal status is `STATUS: CLOSED`. Per-objective completion carries no card — the MissionObjective fires a signal; the HUD State Signaling system handles acknowledgment without authored copy.

**TR-7.** Card copy may be dry, may be understated, may carry wit through omission or understatement. It may not carry wit through a punchline, a wink, an exclamation, or any copy that could be read as the author stepping outside the dossier register.

**TR-8.** The word "spy" does not appear on any BQA surface. The register is "agent," "field operative," or "SECTION 4 DIRECTOR." "Spy" is civilian vocabulary; BQA does not use it.

**TR-9.** Body copy line length should not exceed 52 characters — this preserves the teleprinter column width and prevents the card from reading as a modern UI panel.

**TR-10.** Closing `CLASSIFICATION:` and `STATUS:` stamps are always the final two lines of a mission card body, in that order, followed by any `REF:` routing addendum on a new line below the stamp block.

---

### C.6 — Localization Key Naming Convention

Pattern: `cutscenes.<surface>.<scope>.<beat>` (or `<beat>.<field>` for multi-line VO).

| Field | Allowed values |
|---|---|
| `surface` | `mission_card`, `objective_card`, `cinematic_caption`, `cinematic_vo` |
| `scope` | `briefing`, `closing`, `[objective_id]`, `ct_03`, `ct_04`, `ct_05` |
| `beat` | `title`, `body`, `stamp_classification`, `stamp_status`, `stamp_ref`, `handler_line`, etc. |

**Examples**:

```
cutscenes.mission_card.briefing.title
cutscenes.mission_card.briefing.body
cutscenes.mission_card.briefing.stamp_classification
cutscenes.mission_card.closing.stamp_status
cutscenes.mission_card.closing.stamp_ref

cutscenes.objective_card.find_bomb_device.title
cutscenes.objective_card.find_bomb_device.body
cutscenes.objective_card.intercept_cipher.title
cutscenes.objective_card.intercept_cipher.body

cutscenes.cinematic_vo.ct_04.handler_line
cutscenes.cinematic_caption.ct_05.title
```

`stamp_ref` keys are present only on the closing mission card. Localization of the `REF:` line must preserve the reference number verbatim — only the surrounding routing language is localized. This is a **forward coord item for Localization Scaffold**: `translations/cutscenes.csv` must include all keys above (minimum 14 keys for VS scope: 5 briefing + 5 closing + 4 objective × 2 + 1 ct_04 VO + 1 ct_05 caption = 16 keys conservatively).

---

### C.7 — Closing-Dossier Rome Cliffhanger Seed

The closing card's `REF: IT-65-002 ROUTED TO SECTION 6. ROME STATION ADVISED.` line must do two things simultaneously and must not be seen to be doing either of them.

First, it must close the Paris Affair with the register of a dossier being filed and archived — not a story being continued, but a case being stamped shut. `STATUS: CLOSED` is the correct emotional note: competent, quiet, final.

Second, it must place a single, unexplained routing note below that closure that means nothing to a player who is not paying attention and means everything to a player who is. The reference number `IT-65-002` implies that `PA-65-001` was not an isolated incident but the first in a numbered sequence. The routing to `SECTION 6` implies a different department, a different jurisdiction, a different kind of problem — one that Section 4's Paris station has already handed off. `ROME STATION ADVISED` does not say why Rome was advised. The player does not need to know why. The Paris Affair is over. Whatever Rome was advised about is not in this dossier.

The seed must not be explained, glossed, or followed by a sting in the music. If the card is authored correctly, the last thing the player sees before the screen goes to black is a line of bureaucratic paperwork that implies, without stating, that PHANTOM did not stop at Paris.

---

### C.8 — Class Architecture and Scene-Tree Pattern

The root node is a `CanvasLayer`. Not a `Node`, not a `Control`. A `CanvasLayer` as the root is the correct Godot 4.6 idiom because the system's job is screen-space rendering independent of the 3D viewport transform. This matches the Document Overlay UI pattern (CanvasLayer at index 5, per DOV CR-13 + ADR-0004 §IG7).

**Scene path**: `res://src/gameplay/cutscenes/cutscenes_and_mission_cards.tscn`

This is **NOT an autoload**. The autoload registry is full at 10 slots (ADR-0007 canonical table, 2026-04-27 amendment). MLS instantiates the scene per-section as a child of the section root. Lifetime equals section lifetime. `queue_free()` is called only on section unload by MLS — not on card dismiss.

```gdscript
# res://src/gameplay/cutscenes/cutscenes_and_mission_cards.gd
class_name CutscenesAndMissionCards extends CanvasLayer

signal card_dismissed(scene_id: StringName)
signal cinematic_finished(scene_id: StringName)

enum CardType { MISSION_BRIEFING, MISSION_CLOSING, OBJECTIVE_OPT_IN }

@onready var _briefing_card: Control = $BriefingCard
@onready var _closing_card: Control = $ClosingCard
@onready var _objective_card: Control = $ObjectiveCard
@onready var _letterbox_top: ColorRect = $LetterboxTop
@onready var _letterbox_bottom: ColorRect = $LetterboxBottom

var _dismiss_gate_active: bool = false
var _context_pushed: bool = false
var _current_scene_id: StringName = &""
var _current_title_key: StringName = &""
var _current_body_key: StringName = &""

func _ready() -> void:
    layer = 10
    Events.mission_started.connect(_on_mission_started)
    Events.mission_completed.connect(_on_mission_completed)
    Events.objective_started.connect(_on_objective_started)
    Events.section_entered.connect(_on_section_entered)
    Events.game_loaded.connect(_on_game_loaded)

func _exit_tree() -> void:
    # Symmetric disconnects + paired pop guard
    if _context_pushed:
        InputContext.pop()
        _context_pushed = false
```

The `class_name CutscenesAndMissionCards` is registered for type-annotation use in MLS section authoring; MLS holds it via a typed member variable, not via global `get_node` paths.

**Scene-tree input invariants (BLOCKING — defends VG-CMC-2 dual-focus split per godot-specialist 2026-04-28 night):** Every `Control` node within the Cutscenes scene tree (Mission Briefing Card, Mission Closing Card, Per-Objective Card, including all child `Label` / `RichTextLabel` / `ColorRect` / classification-stamp nodes) MUST set `mouse_filter = MOUSE_FILTER_IGNORE` and MUST NOT be focusable (`focus_mode = FOCUS_NONE`). Rationale: Godot 4.6's dual-focus split (keyboard/gamepad focus separated from mouse/touch focus) means a focusable Control in the card tree could consume `Esc` via its own `_gui_input` *before* the CanvasLayer root's `_unhandled_input` handler runs — the dismiss-gate would never fire. The card surface is non-interactive UI; nothing in the card tree should accept focus or capture mouse. Code-review forbidden patterns: `mouse_filter = MOUSE_FILTER_STOP` (default for Buttons), `focus_mode = FOCUS_ALL`, or any Button / LinkButton / TextEdit node within the card scene tree. Direct instantiation via `CutscenesAndMissionCards.new()` is also forbidden (must go through `PackedScene.instantiate()`); see FP-CMC-13. The `@onready` card sub-node references (`$BriefingCard` / `$ClosingCard` / `$ObjectiveCard`) require these nodes to be **pre-baked as children in the packed `.tscn` file** — dynamic attach post-`_ready()` is unsupported and would leave the @onready vars stale.

---

### C.9 — InputContext.CUTSCENE Lifecycle and Cinematic Implementation

**Push site** — `_open_card()` or `_start_cinematic()` methods, called by signal handlers. Push happens as the first step in the open lifecycle, before any visual change. Sets `_context_pushed = true`.

**Pop site** — `_dismiss()` private method, called by dismiss-gate expiry + `cutscene_dismiss` input (cards) or AnimationPlayer `finished` signal (cinematics). Asserts `_context_pushed == true`, calls `InputContext.pop()`, clears `_context_pushed`.

**1:1 pairing enforcement** — `_context_pushed: bool` guard is the single source of truth. Push sets `true`; pop clears and asserts. Mirrors ADR-0004's `assert(_stack.size() > 1)` underflow guard.

**Cinematic implementation** — `AnimationPlayer` for sequenced multi-track timelines (CT-03/CT-04/CT-05) coordinating: camera position track (via `RemoteTransform3D` driving the player's `Camera3D`), NPC animation tracks (deferred to Polish), audio cue method-call tracks (invoking `Events.cutscene_started` / state queries), CanvasLayer visibility tracks. `Tween` for purely parametric transitions (letterbox 12-frame slide-in, sub-CanvasLayer op-art reveal, fade-to-black ColorRect alpha).

**CT-05 specific** — letterbox bars are `ColorRect` nodes (not authored textures — zero VRAM, simpler lifetime). 12-frame Tween: `Tween.tween_property(letterbox_top, "size:y", 131, 0.2).set_trans(Tween.TRANS_LINEAR)`. Op-art sub-CanvasLayer at **index 11** (validated — ADR-0004 §IG7 does not assign 11; available between Cutscenes layer 10 and Subtitles layer 15). Op-art is a child of the CT-05 cinematic scene node, instantiated lazily, freed on cinematic-end.

**Camera transition (deferred to Polish)** — `RemoteTransform3D.remote_path` on the player's `Camera3D`; AnimationPlayer animates the `RemoteTransform3D`'s position/rotation tracks; Camera3D follows. **Polish-deferral note**: per §A, the cinematic camera rig is deferred. The GDD specs the trigger contract + skip lifecycle + asset slots, not the rig itself. In MVP/VS, CT-05 may fire as a black-screen hold with audio + Mission Closing Card transition only — the camera rig snaps in at Polish without breaking the trigger/skip/InputContext contract.

---

### C.10 — Replay Suppression Pseudocode

```gdscript
# Called from signal handlers (e.g., _on_mission_started, _on_section_entered)
func _try_fire_card(scene_id: StringName, card_type: CardType,
        reason: LevelStreamingService.TransitionReason) -> void:
    # CR-CMC-17 — one-active invariant
    if InputContext.is_active(InputContext.Context.CUTSCENE):
        push_warning("[Cutscenes] drop: %s — context already CUTSCENE" % scene_id)
        return

    # CR-CMC-4 — unconditional suppression on non-FORWARD reasons
    if reason in [LevelStreamingService.TransitionReason.RESPAWN,
                   LevelStreamingService.TransitionReason.NEW_GAME,
                   LevelStreamingService.TransitionReason.LOAD_FROM_SAVE]:
        return

    # CR-CMC-2 — replay suppression via MissionState.triggers_fired
    # Null-safety guard (defends F.3 + EC-CMC-B.8): if MissionState resource is not yet
    # initialised (pre-mission_started boot, corrupt save), suppress all cutscenes.
    var state := MissionLevelScripting.get_mission_state()
    if state == null or state.triggers_fired == null:
        push_warning("[Cutscenes] drop: %s — MissionState/triggers_fired null; suppressing" % scene_id)
        return
    var triggers: Array[StringName] = state.triggers_fired
    if scene_id in triggers:
        return  # already fired in this run; suppress silently

    # All gates passed — fire the card
    _open_card(scene_id, card_type)

func _open_card(scene_id: StringName, card_type: CardType) -> void:
    InputContext.push(InputContext.Context.CUTSCENE)
    _context_pushed = true
    _current_scene_id = scene_id
    _dismiss_gate_active = true
    var gate_duration: float = _gate_duration_for(card_type)
    get_tree().create_timer(gate_duration, true).timeout.connect(
        func(): _dismiss_gate_active = false)
    # ...populate Labels via tr() per CR-CMC-15...
    _show_card(card_type)
```

The `MissionLevelScripting.get_mission_state()` accessor is a public read-only method returning the current `MissionState` resource. Cutscenes is read-only — only MLS writes `triggers_fired` (per MLS CR-6).

---

### C.11 — Localization Integration Pattern

```gdscript
func _populate_briefing_card(title_key: StringName, body_key: StringName) -> void:
    _briefing_title_label.text = tr(title_key)
    _briefing_body_label.text = tr(body_key)
    _current_title_key = title_key
    _current_body_key = body_key

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        if not _briefing_card.visible:
            return
        _briefing_title_label.text = tr(_current_title_key)
        _briefing_body_label.text = tr(_current_body_key)
```

`auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` on all card Label nodes. Rationale: `ALWAYS` would race with the manual `NOTIFICATION_TRANSLATION_CHANGED` handler. `DISABLED` + manual `_notification` is the correct pattern (matches Document Overlay UI CR-7/CR-8).

---

### C.12 — PostProcessStack Lifecycle Integration

PPS GDD amendment **BLOCKING coord item**: add `enable_fade_to_black(duration_s: float)` / `disable_fade_to_black(duration_s: float)` API pair to `PostProcessStack` autoload. This is a separate state machine from `enable_sepia_dim()` / `disable_sepia_dim()`:

| API | Visual effect | Used by |
|---|---|---|
| `enable_sepia_dim()` | Warm amber tint at 30% luminance | Document Overlay UI on `document_opened`; Cutscenes for narrative dim during Briefing card display (intensity tunable via PPS coord) |
| `enable_fade_to_black(duration_s)` | Neutral black ramp via ColorRect alpha 0→1 over `duration_s` | Cutscenes for CT-05 entry/exit + Mission Closing Card 24-frame fade-to-black |

Sepia-dim is *NOT* repurposed at maximum intensity for fade-to-black. (User decision Q4, 2026-04-28 night.)

---

### C.13 — Verification Gates (VG-CMC-1..VG-CMC-5)

**VG-CMC-1 [BLOCKING]** — `CanvasLayer.layer = 10` simultaneous-instance behavior. Instantiate both `CutscenesAndMissionCards` (layer 10) and a stub Settings panel scene (layer 10) simultaneously into the same SceneTree. Confirm Godot 4.6 renders later-added child on top with no z-fighting / undefined render order. The lazy-instance discipline (CR-CMC-16 + ADR-0004 §IG7) is the primary mitigation; this gate confirms failure mode is visually detectable, not a silent crash, if ever bypassed by a future bug.

**VG-CMC-2 [BLOCKING]** — `_unhandled_input` + `cutscene_dismiss` during letterbox + AnimationPlayer. Open CT-05; confirm: (a) `cutscene_dismiss` before dismiss-gate is silently absorbed; (b) `cutscene_dismiss` after gate triggers `_dismiss()` + `InputContext.pop()`; (c) no other system receives the event after `set_input_as_handled()`. Relates to ADR-0004 Gate 3 (modal dismiss via `_unhandled_input` on KB/M + gamepad given Godot 4.6 dual-focus split).

**VG-CMC-3 [BLOCKING]** — `Tween` + `AnimationPlayer` parallel orchestration for CT-05. Confirm a `Tween` animating letterbox `ColorRect.size` and an `AnimationPlayer` running camera/NPC tracks compose cleanly without one cancelling the other. Godot 4.6's `Tween` is tree-bound (`get_tree().create_tween()`) and independent of `AnimationPlayer`. Verify on actual CT-05 scene stub before Polish camera-rig implementation.

**VG-CMC-4 [BLOCKING]** — `auto_translate_mode = DISABLED` + `NOTIFICATION_TRANSLATION_CHANGED` re-resolve. Change locale mid-card-display via Settings; confirm title and body Labels update correctly without double-resolution artifacts. Confirm notification fires on the CanvasLayer root, not just on individual Label nodes. Closes Cutscenes-side of ADR-0004 Gate 4 (`AUTO_TRANSLATE_MODE_*` constants).

**VG-CMC-5 [ADVISORY]** — `SceneTree.create_timer(duration, true)` dismiss-gate behavior with `InputContext.CUTSCENE` active. Timer fires on main thread; confirm not paused by any future `SceneTree.paused = true`. The `process_always = true` second argument is the defensive measure; document choice in implementation.

---

### C.14 — Forbidden Patterns

#### C.14.1 Mechanic Forbidden Patterns (FP-CMC-1..FP-CMC-12)

| # | Pattern | Pillar / rule violated |
|---|---|---|
| **FP-CMC-1** | Protagonist VO / quip during any Mission Card, objective card, or cinematic (`speaker == &"PROTAGONIST"` in any Cutscenes-triggered dialogue line) | Pillar 1 absolute (frame carries the wit, not the protagonist) |
| **FP-CMC-2** | Skip-cinematic-by-default on first-watch; any skip surface that fires before cinematic completes on first arrival | Pillar 5 default (period UX — cinematics earn their interruption). **Carve-out:** Settings-gated `accessibility_allow_cinematic_skip` (default `false`) honors `cutscene_dismiss` during first-watch when player explicitly opts in (per §C.2.2 Stage-Manager precedent). The forbidden pattern remains the *default* shipping behavior; the carve-out is opt-in only. |
| **FP-CMC-3** | "Press any key to continue" prompt, progress bar, greyed-out skip button, or any visible dismiss affordance on a card before dismiss-gate expires | Pillar 5 (period UX — silent-drop convention enforces patience without advertising it) |
| **FP-CMC-4** | Kill cam, slow-motion objective-completed effect, or any post-action replay tied to a card or cinematic beat | Pillar 5 absolute (no post-modern feedback language) |
| **FP-CMC-5** | Climactic music swell at a narrative beat authored inside a cinematic (e.g., swelling strings as CT-05 wire is cut) | Audio + narrative-director FC-5 (score stays deadpan; cinematics are Saul Bass-register, not Hollywood-swelling) |
| **FP-CMC-6** | Launching a Mission Card or objective card while `InputContext.DOCUMENT_OVERLAY` is on the stack | InputContext mutex (Document Overlay owns the screen during Lectern Pause; simultaneous card would be invisible and dismiss-gate would run silently) |
| **FP-CMC-7** | Launching a Mission Card or objective card while `InputContext.SETTINGS`, `MENU`, `PAUSE`, `MODAL`, or `LOADING` is on the stack | InputContext mutex (the CUTSCENE context gate enforces this without additional checks; one-active invariant) |
| **FP-CMC-8** | Procedural / runtime-authored camera moves in cinematics (automated camera tween to a position not scripted in the cinematic resource) | Cinematics require scripted authoring — every shot composed by LD/director. No `CameraRig.follow_target()` or auto-pan during a cinematic |
| **FP-CMC-9** | Leaving `OutlinePipeline` tier mutated across a cinematic end (not restoring prior tier in cleanup path) | Outline integrity (CR-CMC-14); world rendering outside cinematics must not be affected by a cinematic's outline state decision |
| **FP-CMC-10** | Emitting any Mission-domain signal from Cutscenes code (`Events.mission_started.emit(...)`, `Events.objective_started.emit(...)`, etc.) | ADR-0002 sole-publisher discipline (MLS CR-7 + CR-CMC-1) |
| **FP-CMC-11** | Holding a direct node reference to MLS, HUD Core, AudioManager, Dialogue & Subtitles, StealthAI nodes, Combat nodes, or any system outside the Signal Bus (per CR-CMC-13 exceptions) | CR-CMC-13 anti-pattern fence |
| **FP-CMC-12** | Applying the 2.35:1 letterbox to any surface other than CT-05 | Art-director enforcement FP-V-CMC-9 (CR-CMC-18); incorrect letterbox breaks compositional power on non-climactic cards/cinematics |
| **FP-CMC-13** | Direct instantiation via `CutscenesAndMissionCards.new()` (skipping `PackedScene.instantiate()`) | `class_name` registration enables `.new()` from anywhere in the project; bare `.new()` produces a node with no children — every `@onready` ref is `null`. All instantiation MUST go through `PackedScene.instantiate()` (per CR-CMC-16 + §C.8 scene-tree invariants). Code-review grep: `CutscenesAndMissionCards\.new\(\)` returns zero matches (godot-specialist coord, 2026-04-28). |
| **FP-CMC-14** | Focusable Control or `mouse_filter = MOUSE_FILTER_STOP` on any Control inside the Cutscenes scene tree | Defends VG-CMC-2 (dual-focus split). Every card sub-node must be `MOUSE_FILTER_IGNORE` + `FOCUS_NONE`. A focusable Button/LinkButton/TextEdit in the card tree captures `Esc` via `_gui_input` before the CanvasLayer root's `_unhandled_input` fires — dismiss-gate never honors. |

#### C.14.2 Content Forbidden Rules (FC-1..FC-8)

**FC-1.** No protagonist VO on any card or cinematic surface except the authorized `[STERLING.]` telex-radio lines defined in `design/narrative/dialogue-writer-brief.md`. Eve does not narrate, react aloud, or confirm objectives in her own voice. (Per CR-CMC-20.)

**FC-2.** No objective markers, arrows, map pings, or spatial cues embedded in card body copy. Cards may describe what to find; they may not direct where to find it.

**FC-3.** No countdown UI on objective cards. The `CHARGE: SET` card fires during an active countdown (CT-03) but does not display the countdown timer on the card surface. Tension belongs to gameplay layer, not dossier layer.

**FC-4.** No hero-shot composition in cinematics. Camera does not worship Eve. Wide shots show the Tower. Close shots show hands, objects, mechanisms. Eve's face appears only when scene requires absence of expression — not to signal emotion.

**FC-5.** No cinematic uses a music swell at the moment of resolution. CT-05 specifically prohibits a crescendo at the disarm beat. Audio direction: held tone resolves, does not build.

**FC-6.** No card copy uses the word "bomb" except in internal production title `BOMB CHAMBER` (never shown to player). BQA copy uses "device," "PHANTOM field equipment," or "biochemical ordnance." "Bomb" is tabloid vocabulary.

**FC-7.** The 2.35:1 letterbox format is reserved exclusively for CT-05. No other cinematic, card surface, or transition may use letterboxing. Using it earlier depreciates the signal.

**FC-8.** No cinematic exceeds 30 seconds without producer approval. CT-05 authorised at 25–30 s. CT-04 at 18–22 s. CT-03 at 12–15 s. Silent fades are not cinematics and carry no duration constraint.

---

### C.15 — Interactions Matrix

| System | Direction | Contract | Coord status |
|---|---|---|---|
| **Mission & Level Scripting (#13)** | MLS → Cutscenes (publisher) | Cutscenes subscribes to `mission_started`, `mission_completed`, `objective_started`, `objective_completed`. MLS sole emitter (CR-CMC-1). Cutscenes reads `MissionState.triggers_fired` (read-only, CR-CMC-2). MLS writes triggers_fired on `cutscene_ended` receipt. | ✅ MLS L296 + L554 confirm; MLS coord #11 closes on Cutscenes approval |
| **Level Streaming (#9)** | LS → Cutscenes (publisher via Events) | Cutscenes subscribes to `section_entered(section_id, reason)`. On FORWARD + not in triggers_fired: evaluate cinematic. On RESPAWN/NEW_GAME/LOAD_FROM_SAVE: suppress unconditionally (CR-CMC-4). | ✅ LS L320 consistent; **L204 ADVISORY touch-up needed** (RESPAWN branch should read "suppresses unconditionally" not "checks triggers_fired") |
| **HUD Core (#16)** | Cutscenes → HUD (indirect via InputContext) | HUD auto-hides when `InputContext != GAMEPLAY` (HUD CR-10). Cutscenes pushes CUTSCENE; HUD reacts without direct call. | ✅ |
| **HUD State Signaling (#19)** | No interaction | HSS suppressed when context != GAMEPLAY (own design). | ✅ |
| **Audio (#3)** | Signal Bus → Audio | Audio subscribes to NEW `cutscene_started(scene_id)` / `cutscene_ended(scene_id)` (BLOCKING ADR-0002 amendment). Crossfade Rule 6 silence-cut on start; standard 2.0 s crossfade on end. SCRIPTED-cause stinger suppression throughout. | **BLOCKING**: ADR-0002 amendment + Audio §F update |
| **Post-Process Stack (#5) / Outline Pipeline (#4)** | Cutscenes → PPS (lifecycle calls) | `enable_sepia_dim()` for narrative dim; new `enable_fade_to_black(duration_s)` for cinematic fade-to-black; outline tier escape-hatch via `OutlineTier.set_tier(NONE)` + `restore_prior_tier()` (CR-CMC-14). | **BLOCKING**: PPS GDD amendment for `enable_fade_to_black()` API + ADVISORY: confirm L97/L229/L356 reflect Cutscenes as valid escape-hatch caller |
| **Stealth AI (#10)** | Cutscenes → SAI (call); SAI → Events (publish) | Cutscenes calls `StealthAI.force_alert_state(guard, state, AlertCause.SCRIPTED)` for cinematic choreography. `cause` MUST be SCRIPTED to suppress audio stinger (CR-CMC-12). | ✅ SAI exposes `force_alert_state` per MLS CR-8 |
| **Civilian AI (#15)** | No interaction at MVP | Civilian positions during cinematics are LD-authored in cinematic scene. | No coupling |
| **Combat & Damage (#11)** | No direct interaction | Combat is not paused during CUTSCENE (only INPUT is blocked; physics + AI continue unless cinematic LD authoring explicitly halts via scripted MLS beat). | ADVISORY: LD authoring guide note |
| **Inventory & Gadgets (#12)** | No interaction during cutscene | Player cannot use gadgets during CUTSCENE (Input blocked). No inventory state modified. | ✅ |
| **Document Collection (#17)** | No interaction | DC interact gate blocked by CUTSCENE (DC forward contract, CR-CMC-8). | ✅ |
| **Document Overlay UI (#20)** | Mutually exclusive via InputContext | DOCUMENT_OVERLAY active → Cutscenes drops (FP-CMC-6). CUTSCENE active → Overlay can't open (DC interact gate, CR-CMC-8). Two systems can never be simultaneously active. | ✅ |
| **Dialogue & Subtitles (#18)** | D&S self-suppresses; Cutscenes owns title-card text only | D&S subscribes to `ui_context_changed`, suppresses while context != GAMEPLAY (ADR-0004 §IG5, D&S §F.3). Cutscenes owns title-card text on CanvasLayer 10. SCRIPTED Category 7 in-cinematic dialogue flows via MLS `scripted_dialogue_trigger` → D&S, NOT via Cutscenes→D&S call. | ✅ D&S L886 + L1399 confirm; boundary clarified in CR-CMC-10 |
| **Save / Load (#6)** | F5 silently dropped; subscribes to game_loaded | F5 quicksave silently dropped during CUTSCENE (Save/Load CR-6 — CUTSCENE excluded context). Cutscenes subscribes to `game_loaded` to re-validate triggers_fired (CR-CMC-21). | ✅ Save/Load L107 + L162 consistent |
| **Menu System (#21)** | Mutually exclusive via InputContext | PAUSE blocked by CUTSCENE (CR-CMC-7). Menu cannot open during card/cinematic. | ADVISORY: Menu System (when authored beyond Day-1 MVP) must document CUTSCENE as blocked-entry context |
| **Settings & Accessibility (#23)** | Settings entry blocked; cinematic skip toggle out of scope | Settings cannot open during CUTSCENE (Settings forward contract). Settings L1346 explicitly defers cinematic-skip-toggle to Cutscenes' own skip behavior (CR-CMC-2 / C.2.2). | ✅ |
| **Localization Scaffold (#7)** | Cutscenes → Localization (consumer) | All card text via `tr(key)` with `auto_translate_mode = DISABLED` + `NOTIFICATION_TRANSLATION_CHANGED` re-resolve (CR-CMC-15). `cutscenes.csv` table required. | **BLOCKING**: Localization Scaffold authoring contract for `cutscenes.*` keys (16 minimum) + ADVISORY: confirm L132 + L186 include `NOTIFICATION_TRANSLATION_CHANGED` live-resolution as consumer guarantee |
| **Input (#2)** | InputContext.CUTSCENE blocks all gameplay input; `cutscene_dismiss` action added | Cutscenes pushes/pops CUTSCENE (CR-CMC-5). Input GDD must add `cutscene_dismiss` action + CUTSCENE to blocked-actions table. ADR-0004 §IG2 push/pop authority. | **BLOCKING**: Input GDD + ADR-0004 amendment (add `Context.CUTSCENE` enum value) |

---

### C.16 — Bidirectional Consistency Check

| Source | Claim | Verdict |
|---|---|---|
| **MLS L296** | "Cutscenes & Mission Cards (VS) consumes mission_started/_completed/objective_started/_completed via Signal Bus. CR-13 — direct-reference fence." | ✅ Consistent — CR-CMC-1 + CR-CMC-13 |
| **MLS L554** | "Subscribes to all 4 Mission-domain signals for card triggers" | ✅ Consistent |
| **MLS L592 + L918** | "coord item #11: Cutscenes & Mission Cards (VS) forward API verification when authored" | ✅ Closes on this GDD's approval — CR-CMC-1..22 is the forward API |
| **Audio L407** | "Cutscene SFX and music track swaps triggered by mission_started / section_entered / **custom cutscene signals (to be added to ADR-0002 during Cutscenes GDD authoring)**" | **BLOCKING discrepancy resolution**: ADR-0002 amendment adds `cutscene_started(scene_id)` + `cutscene_ended(scene_id)` in new Cutscenes domain (CR-CMC-11) |
| **Audio L727** | `music_crossfade_default_s = 2.0` for non-alert transitions | ✅ Consistent — CR-CMC-11 references this knob by name |
| **PPS L97** | Outline tier escape-hatch API | ✅ Consistent with CR-CMC-14; ADVISORY: PPS GDD should document Cutscenes as a valid escape-hatch caller |
| **PPS L229** | "Cutscenes & Mission Cards (22) potential API consumer — narrative dim beats may use same API" | ✅ Consistent — `enable_sepia_dim()` for narrative dim |
| **PPS L356** | "Should Cutscenes use the sepia dim for any specific narrative beats? Resolved at Cutscenes GDD authoring" | ✅ Resolved here: sepia-dim for Mission Briefing dim; separate `enable_fade_to_black()` for cinematic fade — BLOCKING PPS GDD amendment per CR-CMC-22 |
| **Localization L132** | `translations/cutscenes.csv` + `cutscenes.*` keys + "One-shot at scene trigger" | ✅ Consistent — CR-CMC-15 + C.6 key convention |
| **Localization L186** | "Consumes `cutscenes.*` keys" | ✅ Consistent; ADVISORY: confirm `NOTIFICATION_TRANSLATION_CHANGED` live-resolve guarantee documented |
| **D&S L886** | "Cutscenes #22 Not Started — Forward dep: when designed, may trigger SCRIPTED Category 7 lines via MLS scripted_dialogue_trigger. No D&S contract surface yet." | ✅ Resolved — CR-CMC-10 + interactions matrix D&S row |
| **D&S L1399** | "Captions during cutscenes — Cutscenes #22 own their own captioning; D&S does NOT render during cutscene" | ✅ Consistent — CR-CMC-10 boundary |
| **Save/Load L107 + L162** | Cutscenes subscribes to `game_loaded` to check triggers_fired and suppress already-played replays | ✅ Consistent — CR-CMC-2 + CR-CMC-21 |
| **Save/Load CR-6** | F5 silently dropped during CUTSCENE context | ✅ Consistent — CR-CMC-6 |
| **LS L122 + L320** | Cutscenes branch table: FORWARD = first-arrival check vs triggers_fired; RESPAWN/NEW_GAME/LOAD_FROM_SAVE = suppress unconditionally | ✅ Consistent — CR-CMC-3 + CR-CMC-4 |
| **LS L204** | "RESPAWN checks `triggers_fired` to suppress replays" | **ADVISORY discrepancy**: text should read "suppresses unconditionally" (RESPAWN never checks triggers_fired per CR-CMC-4). LS GDD touch-up needed. |
| **HUD Core L1007** | "Cutscenes & Mission Cards (system #22) — distinct CanvasLayer at index 10" | ✅ Consistent — CR-CMC-16 lazy-instance + parented to section root; HUD CR-10 auto-hide |
| **Settings L1346** | "Cinematic cutscene skip toggle — out of scope for Settings; Cutscenes #22 owns its own skip behavior" | ✅ Consistent — C.2.2 + CR-CMC-2 |
| **ADR-0004 L270** | "Layer 10 shared between Settings panel and Cutscene letterbox / Mission cards (mutually exclusive by InputContext gate). Cutscenes hold a context (currently undeclared, owned by Cutscenes & Mission Cards GDD #22 when authored) that is pushed at cutscene start and popped at cutscene end." | ✅ Resolved — `InputContext.CUTSCENE` declared in this GDD via BLOCKING ADR-0004 amendment; lazy-instance discipline confirmed CR-CMC-16 |
| **ADR-0002 L103** | "ui_context_changed subscribers: HUD Core; Audio; Cutscenes & Mission Cards (suppress UI overlap during letterbox state — pending GDD #22); Subtitles" | ✅ Resolved — CR-CMC-9 (HUD owns its own auto-hide) + CR-CMC-10 (subtitle suppression) + CR-CMC-7 (pause/menu blocked); Cutscenes does NOT subscribe to `ui_context_changed` directly (it pushes the CUTSCENE context that triggers the signal for downstream subscribers) |

## Formulas

**Honest scope statement.** Cutscenes & Mission Cards has **no balance math** (no progression curves, no damage formulas, no economy curves). The five formulas below are: (F.1) a frame-cost claim for ADR-0008 Slot 7; (F.2) a trigger-evaluation event-frame claim for Slot 8; (F.3) a formal first-arrival firing predicate; (F.4) the dismiss-gate timing state machine; (F.5) a Pillar 2 + Pillar 5 budget-allocation honesty statement. F.6 provides exact prose for the ADR-0008 amendment that registers F.1 + F.2 sub-claims.

### F.1 — Cinematic-Active Frame Cost Claim (ADR-0008 Slot 7)

**Slot assignment clarification.** This formula covers **CPU-side Control processing** that lands in **Slot 7 (UI, 0.3 ms shared)**. The op-art sub-CanvasLayer (index 11, CT-05 only) renders pre-baked concentric-ring `TextureRect` nodes — this is **GPU draw-call cost absorbed into Slot 1 (Rendering, 3.8 ms)** as 3–5 additional CanvasItem draws (0.02–0.05 ms GPU on Iris Xe), NOT a Slot 7 or Slot 3 cost. Slot 7 measures CPU-side `CanvasItem`/`Control` process ticks; Slot 3 covers `CompositorEffect`-based full-screen passes only. The op-art is neither.

**The `t_cutscene_slot7` formula is defined as:**

`t_cutscene_slot7 = t_colorect_cpu + t_animation_player_tick + t_label_process + t_loc_resolve + t_unhandled_input`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| ColorRect CPU tick (CT-05 letterbox bars only) | `t_colorect_cpu` | float ms | [0.00, 0.02] | 2 `ColorRect` nodes; flat fill; no shader; no physics. Zero on all other surfaces. |
| AnimationPlayer advance | `t_animation_player_tick` | float ms | [0.00, 0.10] | `AnimationPlayer.advance()` per frame. MVP: camera `RemoteTransform3D` track only (0.03–0.05 ms). Polish: + NPC method-call tracks (+0.03–0.05 ms). **Hard track-count cap: ≤ 4 tracks total (1 camera + 3 NPC method-call). Exceeding this invalidates the F.1 0.20 ms ceiling without a re-profile.** Zero when no cinematic active. |
| Label process | `t_label_process` | float ms | [0.01, 0.05] | Title + body Label `_process()`. Mission Card 3–5 Labels; objective card 1–2. Zero when no card active. |
| Locale resolve | `t_loc_resolve` | float ms | [0.00, 0.02] | `tr()` resolve cost; fires only on `NOTIFICATION_TRANSLATION_CHANGED` while a card is visible. Zero every other frame. |
| `_unhandled_input` cost | `t_unhandled_input` | float ms | [0.00, 0.02] | `_unhandled_input` fires per InputEvent during active CUTSCENE (KB+M+gamepad polling = 60–120 events/s). Each call: `InputContext.is_active()` check + `event.is_action_pressed()` lookup. Approximate 0.0001 ms per call × 120 events = ≤ 0.012 ms/frame. Zero when CanvasLayer not in tree. |
| Total | `t_cutscene_slot7` | float ms | [0.00, 0.20] | Total CPU-side Control process cost for Cutscenes & Mission Cards in Slot 7. |

**Output Range:** [0.00, 0.20] ms. Bounded below the Slot 7 0.3 ms shared cap (with HUD Core / HUD State Signaling — mutually exclusive by InputContext gate per HUD CR-10).

| Active surface | Slot 7 contribution |
|---|---|
| No card / cinematic active | **0.00 ms** (CanvasLayer not in tree) |
| Mission Card display | 0.03–0.07 ms (2–5 Labels, no AnimationPlayer, no ColorRect) |
| CT-03 / CT-04 peak | 0.05–0.10 ms (camera track only at MVP) |
| CT-05 peak (MVP) | 0.10–0.16 ms (ColorRect 0.01 + AnimationPlayer 0.05 + Labels 0.04 + loc 0.0) |
| CT-05 peak (Polish) | 0.14–0.20 ms (+ NPC method-call tracks 0.04–0.05 ms) |

**Example (CT-05 at MVP):** `t_colorect_cpu = 0.01` (2 letterbox bars, one `_process` tick each); `t_animation_player_tick = 0.05` (camera RemoteTransform3D track, linear interpolation); `t_label_process = 0.04` (3 card Labels on closing-card transition); `t_loc_resolve = 0.00` (no locale switch on this frame). **Sum: 0.10 ms.** At Polish with NPC tracks: `0.01 + 0.09 + 0.06 + 0.00 = 0.16 ms`. Both well under the 0.20 ms Cutscenes sub-claim ceiling and the 0.3 ms shared Slot 7 cap.

---

### F.2 — Trigger-Evaluation Event-Frame Cost Claim (ADR-0008 Slot 8)

**The `t_trigger_slot8` formula is defined as:**

`t_trigger_slot8 = t_dict_has + t_input_push + t_timer_create + t_tween_create`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Triggers-fired membership check | `t_dict_has` | float ms | [0.000, 0.002] | `MissionState.triggers_fired.has(scene_id)` — O(N) `Array[StringName]` linear scan over ≤20 entries. Amortised ≈ 0.001 ms. |
| InputContext push | `t_input_push` | float ms | [0.001, 0.003] | `InputContext.push(Context.CUTSCENE)` — dictionary write + `ui_context_changed` emit (1 signal, 1 subscriber: HUD Core). |
| SceneTreeTimer create | `t_timer_create` | float ms | [0.001, 0.003] | `SceneTree.create_timer(duration_s, true)` — allocates 1 `SceneTreeTimer` object. |
| Tween create | `t_tween_create` | float ms | [0.001, 0.003] | `create_tween().tween_property(...)` for dismiss-gate or letterbox-sweep — allocates 1 `Tween` + 1 `PropertyTweener`. |
| Total | `t_trigger_slot8` | float ms | [0.003, 0.011] | Total Slot 8 event-frame cost on the frame a cutscene/card trigger fires. |

**Output Range:** [0.003, 0.011] ms on the event frame. Steady-state between trigger events: **0.00 ms** (no per-frame ticking in Slot 8 from Cutscenes). The 0.011 ms worst-case is the cost on the single frame where all four operations execute together (cinematic-start event frame). **Absorbed within the existing 0.25 ms Slot 8 residual margin** (per ADR-0008 2026-04-28 night amendment) — no new pool consumption is registered as a named sub-claim.

**Example:** `mission_started` fires. `t_dict_has = 0.001` (`triggers_fired` has 0 entries on first play). `t_input_push = 0.002`. `t_timer_create = 0.002` (briefing card 4.0 s gate timer). `t_tween_create = 0.002` (objective-card paper-translate-in Tween — fires only for objective cards; briefing card has no entry Tween). **Sum: 0.007 ms.** Absorbed within margin; no slot claim required.

---

### F.3 — First-Arrival Firing Predicate

**The `fires` predicate is defined as:**

`fires(scene_id, event) = (reason(event) == TransitionReason.FORWARD) AND (scene_id NOT IN MissionState.triggers_fired) AND (InputContext.current() != Context.CUTSCENE)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cinematic / card identifier | `scene_id` | StringName | set of ≤7 VS beat IDs | Unique identifier for the cinematic or card resource being evaluated |
| Transition reason | `reason(event)` | TransitionReason enum | `{FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE}` | Reason extracted from `section_entered` event payload |
| Replay-suppression record | `MissionState.triggers_fired` | Array[StringName] | ≤20 entries | Read-only from Cutscenes; owned by MLS + ADR-0003 |
| Active context | `InputContext.current()` | Context enum | `{GAMEPLAY, CUTSCENE, MENU, SETTINGS, DOCUMENT_OVERLAY, MODAL, LOADING}` | Top of InputContext stack |
| Predicate result | `fires(...)` | bool | `{true, false}` | Whether the cinematic/card is instantiated this event |

**Clause-to-rule mapping:**

| Predicate clause | Source rule |
|---|---|
| `reason == FORWARD` | CR-CMC-3 (first-arrival) + CR-CMC-4 (unconditional suppression on non-FORWARD) |
| `scene_id NOT IN triggers_fired` | CR-CMC-2 (replay suppression) |
| `InputContext.current() != CUTSCENE` | CR-CMC-17 (one-active invariant) |

**Edge case — same-frame `mission_started` + `section_entered(FORWARD)`** (both not in `triggers_fired`): per CR-CMC-17 + C.3.2, Mission Card priority wins. The `mission_started` handler runs first in signal dispatch order and pushes `InputContext.CUTSCENE`. When `section_entered` evaluates `fires()`, the third clause returns `false` because the Mission Card has taken the context. The cinematic is dropped — `fires(ct03_scene_id, ...) = false`. The cinematic beat is permanently suppressed for this session unless the LD authors these as mutually exclusive in section data (which they should be by design — the briefing card and CT-03 do not co-occur on Plaza entry; CT-03 fires on `section_entered(upper_structure_id, FORWARD)` after `objective_completed("kitchen_charge_planted")`).

---

### F.4 — Dismiss-Gate Timing Model

**State variable:** `_dismiss_gate_active: bool` (one instance per active card surface; not applicable to cinematics — cinematics use full-duration playback per CR-CMC-2.2).

**The `dismiss_allowed` transition guard is defined as:**

`dismiss_allowed(t_elapsed, action_pressed) = (NOT _dismiss_gate_active) AND action_pressed("cutscene_dismiss")`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Gate state | `_dismiss_gate_active` | bool | `{true, false}` | `true` = input dropped silently; `false` = input honoured |
| Per-surface gate duration | `gate_duration_s` | float s | `{3.0, 4.0, 5.0}` | Briefing 4.0 / Closing 5.0 / Objective 3.0 |
| Time since instantiation | `t_elapsed` | float s | [0.0, ∞) | Advanced by SceneTreeTimer (NOT polled) |
| Input action pressed | `action_pressed` | bool | `{true, false}` | `InputEvent.is_action_pressed("cutscene_dismiss")` result |
| Transition decision | `dismiss_allowed` | bool | `{true, false}` | Whether `_dismiss()` is called this event |

**State transitions:**

```
ON card_instantiated:
    _dismiss_gate_active = true
    SceneTree.create_timer(gate_duration_s, process_always=true).timeout
        connects to → _dismiss_gate_active = false

ON timer_timeout:
    _dismiss_gate_active = false                        # gate opens

ON "cutscene_dismiss" pressed AND _dismiss_gate_active == true:
    get_viewport().set_input_as_handled()               # silent drop

ON "cutscene_dismiss" pressed AND _dismiss_gate_active == false:
    _dismiss()                                          # gate has opened
    get_viewport().set_input_as_handled()
```

**Per-surface gate durations:**

| Surface | `gate_duration_s` | Post-gate behaviour |
|---|---|---|
| Mission Card — briefing | **4.0 s** | `cutscene_dismiss` calls `_dismiss()` → hard cut to gameplay |
| Mission Card — closing | **5.0 s** | `cutscene_dismiss` calls `_dismiss()` → 24-frame fade-to-black to credits (CR-CMC-19) |
| Per-objective opt-in card | **3.0 s** | `cutscene_dismiss` calls `_dismiss()` → 4-frame translate-out (objective card only) |
| Cinematics CT-03 / CT-04 / CT-05 | **N/A** | Full-duration playback; no dismiss gate; no input during first-watch (CR-CMC-2.2) |

**Output range:** `_dismiss_gate_active` transitions `true → false` exactly once per card instance, at `gate_duration_s` after instantiation. It never transitions back to `true`. The gate is one-shot per card lifetime. (User decision Q3, 2026-04-28 night.)

**`process_always = true` rationale:** while CR-CMC-7 blocks the Pause Menu from opening during `CUTSCENE` (so `SceneTree.paused` should never be `true` during a card), the second arg is a defensive invariant against future engine pause-paths or debug-mode pauses.

---

### F.5 — Cinematic Budget Allocation Across Mission (Pillar 2 + Pillar 5 Honesty Statement)

**This formula contains no balance math.** It is a time-budget accounting statement verifying that all cards and cinematics combined consume an acceptable fraction of session time — a Pillar 2 (Discovery Rewards Patience) and Pillar 5 (Period Authenticity) acceptance criterion.

**The `t_non_gameplay_total` formula is defined as:**

`t_non_gameplay_total = t_cards + t_cinematics`
`session_fraction = t_non_gameplay_total / t_session`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Briefing card duration | `t_mission_card_briefing` | float s | [4.0, 8.0] | 4.0 s gate + typical player dismiss |
| Closing card duration | `t_mission_card_closing` | float s | [5.0, 9.0] | 5.0 s gate + 24-frame fade (0.4 s) + typical |
| Objective card — Telephone | `t_obj_card_telephone` | float s | [3.0, 5.0] | 3.0 s gate + typical player dismiss |
| Objective card — Cipher | `t_obj_card_cipher` | float s | [3.0, 5.0] | 3.0 s gate + typical |
| Total card surface time | `t_cards` | float s | [15.0, 27.0] | Sum of 4 card surfaces |
| CT-03 cinematic | `t_ct03` | float s | [12.0, 15.0] | Restaurant kitchen explosion |
| CT-04 cinematic | `t_ct04` | float s | [18.0, 22.0] | Upper Structure rappel |
| CT-05 cinematic | `t_ct05` | float s | [25.0, 30.0] | Bomb Chamber disarm climactic |
| Total cinematic time | `t_cinematics` | float s | [55.0, 67.0] | Sum of 3 cinematics |
| Total non-gameplay surface | `t_non_gameplay_total` | float s | [70.0, 94.0] | Sum across mission |
| Session length | `t_session` | float s | [7200.0, 14400.0] | 2–4 hours per game-concept.md |
| Session fraction | `session_fraction` | float | [0.005, 0.013] | Non-gameplay surface as fraction of session |

**Output Range:** `session_fraction` ∈ [0.5%, 1.3%] of session time. Worst-case (94 s non-gameplay against a 2-hour session) yields 1.3%, comfortably under a conservative 2.0% patience-rule budget. The constraint is non-binding by construction — the VS cinematic roster is too small to threaten player patience.

**Per-section breakdown (worst-case durations):**

| Section | Non-gameplay surface | Worst-case duration |
|---|---|---|
| Plaza / Mission Open | Briefing card (fires on `mission_started` before player control) | 8 s |
| Plaza | None | 0 s |
| Lower Scaffolds | None (silent LSS fade Plaza→Lower) | 0 s |
| Restaurant | Telephone objective card (Lower→Restaurant silent fade; objective fires in Restaurant) + CT-03 transition (Restaurant→Upper) | 5 + 15 = **20 s** |
| Upper Structure | Radio Cipher objective card + CT-04 entry cinematic (Upper→Bomb) | 5 + 22 = **27 s** |
| Bomb Chamber | CT-05 climactic + Closing card | 30 + 9 = **39 s** |
| **Mission total** | | **94 s worst-case** |

**Acceptance criterion (Pillar 2 + Pillar 5 budget claim):**

> **AC-CMC-BUDGET**: All Cutscenes & Mission Cards surfaces combined must consume **≤ 108 s of total non-gameplay surface time across the entire mission** (sum of cap durations from §G.1 + §G.2). The worst-case VS roster sums to ≤ 94 s, satisfying the 108 s absolute cap by a 14 s margin. The "1.5% of a 2-hour session" framing is **illustrative only**: at the stated 2-hour expected playtime the budget is 1.3%, but for sub-2-hour speed-runs (e.g., 60-minute completion = 94/3600 = 2.6%) the fraction grows above 1.5% — this is acceptable because the **absolute total (≤ 94 s) is the binding criterion**, not the session fraction. The Pillar 2 constraint is on total cinematic time, not on its fractional ratio to playtime. This criterion is verifiable at authoring time from the per-surface duration caps in this GDD — no runtime measurement required. (See AC-CMC-BUDGET-1 in §H for QA verification.)

---

### F.6 — Recommended ADR-0008 Amendment Language (BLOCKING coord)

The following prose should be added to **ADR-0008 §Negative**, within the Slot 8 sub-claims paragraph, immediately after the D&S entry:

---

**Cutscenes & Mission Cards sub-claims (Slot 7 + Slot 8) — registered 2026-04-28 per `cutscenes-and-mission-cards.md` §D authoring pass:**

**Slot 7 sub-claim: 0.00–0.20 ms peak event-frame** (`cutscenes-and-mission-cards.md §D F.1`). Cost driver = CPU-side Control processing: `ColorRect` tick (CT-05 letterbox bars only) + `AnimationPlayer.advance()` (camera track MVP; + NPC tracks Polish) + `Label._process()` (card Labels) + `tr()` locale-resolve (NOTIFICATION_TRANSLATION_CHANGED only). Steady-state 0.00 ms (CanvasLayer not in tree). CT-05 peak 0.14–0.20 ms (Polish). Cutscenes Slot 7 contribution and HUD Core Slot 7 peak are non-concurrent (HUD hides during `CUTSCENE` per HUD Core CR-10), so the combined Slot 7 usage stays below the 0.3 ms cap. Provisional pending profiler measurement at Polish milestone. Note on op-art sub-layer (CanvasLayer 11, CT-05 only): the concentric-ring `TextureRect` draw calls land in **Slot 1 (Rendering)** as standard CanvasItem draw calls (3–5 additional draws, 0.02–0.05 ms GPU on Iris Xe). This is not a Slot 3 (Post-Process) or Slot 7 (UI CPU) cost.

**Slot 8 sub-claim: absorbed within residual margin** (`cutscenes-and-mission-cards.md §D F.2`). Trigger-evaluation path on signal receipt (`dict.has()` + `InputContext.push()` + `SceneTree.create_timer()` + `create_tween()`) = 0.007–0.011 ms peak event-frame. Absorbed within the existing 0.25 ms Slot 8 residual margin with no named pool consumption. No steady-state Slot 8 cost.

**Steady-state pool sum unchanged: 0.55 ms** (CAI 0.30 + MLS 0.10 + DC 0.05 + D&S 0.10; Cutscenes Slot 8 absorbed in margin). **Slot 8 residual margin unchanged: 0.25 ms.** Slot 7 Cutscenes contribution is non-concurrent with HUD Core peak by virtue of HUD Core CR-10 mutual exclusion; the 0.3 ms Slot 7 cap is not threatened.

---

The **Revision History** entry for this amendment should read:

> **2026-04-28 night** — Amendment per Cutscenes & Mission Cards §D authoring pass: (1) Slot 7 Cutscenes sub-claim **0.00–0.20 ms peak** registered — CPU-side Control processing (ColorRect + AnimationPlayer + Label; op-art CanvasLayer 11 texture draws routed to Slot 1 Rendering, not Slot 7 or Slot 3). (2) Slot 8 Cutscenes trigger-evaluation cost (0.007–0.011 ms peak event-frame) **absorbed within existing 0.25 ms residual margin** — no pool-sum update. (3) HUD Core CR-10 mutual exclusion confirmed: Cutscenes Slot 7 peak and HUD Core Slot 7 peak are non-concurrent. Slot 8 steady-state pool sum unchanged at 0.55 ms. — `cutscenes-and-mission-cards.md §D` — closes Cutscenes Slot 7 + Slot 8 sub-claim registration.

## Edge Cases

36 edge cases across 8 clusters (Cluster B grew to 8 entries with EC-CMC-B.8 null-safety addition, 2026-04-28 night cross-review). Each is formatted as **EC-CMC-N.M — *If [condition]***: *[outcome]*. *Defended by* [rule references].

### Cluster A — Same-frame signal storms (6)

- **EC-CMC-A.1 — If `mission_started` and `section_entered(FORWARD)` fire in the same physics frame**: Mission Card wins. `mission_started` handler runs first in MLS's synchronous dispatch order; by the time the `section_entered` handler evaluates, `InputContext.CUTSCENE` is already on the stack and any cinematic for that forward transition is dropped per CR-CMC-17. Drop logged in debug builds. *Defended by* CR-CMC-17, C.3.1.
- **EC-CMC-A.2 — If `mission_completed` and `objective_completed("bomb_chamber_disarmed")` fire in the same frame**: Mission Card (`mc_closing_paris_affair`) wins. `mission_completed` handler pushes `CUTSCENE` first; `objective_completed` finds context taken and drops. This is the expected CT-05 epilogue: closing card displays, last objective completion drops cleanly. *Defended by* CR-CMC-17, CR-CMC-1.
- **EC-CMC-A.3 — If two `objective_started` signals fire same frame (two opt-in objectives activate simultaneously)**: First handler pushes CUTSCENE + displays its card. Second finds context CUTSCENE and drops. LD authoring constraint: never place two `show_card_on_activate = true` objectives that activate on the same frame. The drop is the defined behavior, not a bug. *Defended by* CR-CMC-17, C.3.4.
- **EC-CMC-A.4 — If `section_entered(FORWARD)` and `section_entered(LOAD_FROM_SAVE)` arrive in the same frame**: Debug-build invariant violation — LSS emits exactly one `section_entered` per transition. Assert in debug: `assert(false, "[Cutscenes] Two section_entered signals with conflicting reasons in one frame.")`. In release, whichever fires first is processed; second is dropped by one-active invariant if a cutscene was triggered. *Defended by* CR-CMC-3, CR-CMC-4.
- **EC-CMC-A.5 — If `cutscene_started` fires while another cutscene is active (impossible per CR-CMC-17, but document)**: Handler checks `InputContext.current() == CUTSCENE`, drops + logs. No second CanvasLayer, no second push, no double-pop hazard. *Defended by* CR-CMC-17, CR-CMC-5.
- **EC-CMC-A.6 — If `objective_started` fires while a Mission Card is mid-display**: Per-objective opt-in card drops silently. The card for that beat is permanently lost for this session — `objective_started` does not re-fire. Acceptable: the Mission Card is the dominant narrative event; the objective's information is recoverable from gameplay context. *Defended by* CR-CMC-17, C.3.1, C.3.4.

### Cluster B — Save/load and replay suppression (8)

- **EC-CMC-B.1 — If player loads a save captured mid-cinematic** (cinematic was triggered but `cutscene_ended` had not yet fired, so `scene_id` was not yet written to `triggers_fired`): On `section_entered(LOAD_FROM_SAVE)`, CR-CMC-4 unconditionally suppresses all cinematic evaluation. Cinematic does not re-fire. Player resumes at save point. If they later reach the trigger via FORWARD navigation, cinematic fires as first-watch. *Defended by* CR-CMC-4, CR-CMC-21.
- **EC-CMC-B.2 — If player loads a save where `triggers_fired` is corrupt or empty but the save section is past the trigger point**: CR-CMC-4 unconditional suppression on LOAD_FROM_SAVE. No cinematic fires regardless of `triggers_fired` content. If player navigates forward, cinematic fires as first-watch (preferred over silently skipping a beat the player may never have seen). *Defended by* CR-CMC-2, CR-CMC-4.
- **EC-CMC-B.3 — If player loads a save during a card display**: Structurally impossible. CR-CMC-6 silently drops F5 quicksave during CUTSCENE; CR-CMC-7 blocks Pause Menu opening during CUTSCENE; manual save thus cannot be made while a card is active. Debug-build assert: if a save file's `InputContext` field encodes CUTSCENE at save time, flag corrupt save — do not restore CUTSCENE on load. *Defended by* CR-CMC-6, CR-CMC-7.
- **EC-CMC-B.4 — If New Game on slot 1, then immediately loads slot 5**: NEW_GAME initializes a fresh MissionState. Loading slot 5 replaces the autoload MissionState resource entirely. Cutscenes' replay-suppression always reads the current MissionState resource (not a cached copy) so slot 1 state never contaminates slot 5. *Defended by* CR-CMC-21, CR-CMC-2.
- **EC-CMC-B.5 — If F5 quicksave fires during a cutscene**: Silently dropped per Save/Load CR-6. No toast, no queue, no deferred save. Player must wait until CUTSCENE is popped and GAMEPLAY restored before F5 is honored. *Defended by* CR-CMC-6.
- **EC-CMC-B.6 — If player completes mission → `game_loaded` fires for credits → Cutscenes must not re-fire closing card**: `game_loaded` does not re-emit `mission_completed`. Cutscenes subscribes to `mission_completed` (not `game_loaded`) for closing-card trigger. On `game_loaded`, Cutscenes only validates `triggers_fired` consistency (CR-CMC-21). No closing card re-fires. *Defended by* CR-CMC-21, CR-CMC-1.
- **EC-CMC-B.7 — If player loads a save captured BEFORE `mission_started` has fired**: `section_entered(LOAD_FROM_SAVE)` → CR-CMC-4 unconditional suppress. `mission_started` has not fired → no Mission Card evaluation. Cutscenes' subscribers receive nothing. Gameplay resumes normally. When the player reaches the `mission_started` trigger via FORWARD, the briefing card fires as first-watch. *Defended by* CR-CMC-4, CR-CMC-3.
- **EC-CMC-B.8 — If `MissionLevelScripting.get_mission_state()` returns `null` (pre-init boot, corrupt save, or MissionState resource not yet created)** (NEW per systems-designer + godot-specialist cross-review 2026-04-28 night): `_try_fire_card` returns immediately after `push_warning("[Cutscenes] drop: %s — MissionState/triggers_fired null; suppressing" % scene_id)`. No CanvasLayer instanced, no InputContext push, no crash. The null-guard in §C.10 pseudocode is the defense. The structural defense is ADR-0007 autoload load order: MLS (slot #9) is in-tree before Cutscenes (per-section, post-autoload), so `get_mission_state()` returning `null` indicates either (a) corrupt MissionState resource on the loaded save, or (b) pre-NEW_GAME state. Both conditions are recoverable by suppression. The corollary BLOCKING contract on MLS (per OQ-CMC-6) is that `get_mission_state()` returns the **live MissionState reference**, never a `duplicate()` or `duplicate_deep()` copy — a live `null` is recoverable; a stale duplicate breaks replay-suppression invisibly. *Defended by* CR-CMC-2, F.3 null-guard pseudocode, OQ-CMC-6 live-reference contract.

### Cluster C — Section-transition + cinematic + LSS (7)

- **EC-CMC-C.1 — If LSS `transition_failed` fires during a cutscene**: `InputContext.LOADING` is pushed by LSS abort recovery. `LOADING` takes precedence over `CUTSCENE` per ADR-0004 §IG3 mutual-exclusion rules. Cutscenes subscribes to `Events.ui_context_changed`; when `LOADING` appears, the cutscene cleanup handler fires and pops `CUTSCENE` before LSS's loading overlay renders. Post-abort: stack contains only `LOADING`. No `CUTSCENE` orphan remains. *Defended by* CR-CMC-5, CR-CMC-14.
- **EC-CMC-C.2 — If player triggers `section_entered(FORWARD)` then `section_entered(RESPAWN)` within same frame**: FORWARD handler runs first, evaluates cinematic. RESPAWN handler runs second — CR-CMC-4 unconditionally suppresses any cinematic for RESPAWN reason. If FORWARD triggered a cinematic, RESPAWN handler finds no new cinematic to suppress (would not evaluate anyway). If this represents an LSS bug, debug-assert. *Defended by* CR-CMC-3, CR-CMC-4.
- **EC-CMC-C.3 — If cinematic is mid-playback when `section_unloading` fires**: Cutscenes' `_exit_tree` fires (CanvasLayer is child of section root). `_cleanup()` runs: pop CUTSCENE, call `restore_prior_tier()`, call `disable_fade_to_black()`, stop AnimationPlayer, disconnect signals. Pop occurs in `_exit_tree` before tree teardown completes; stack is clean when section root finishes freeing. *Defended by* CR-CMC-5, CR-CMC-14, CR-CMC-22.
- **EC-CMC-C.4 — If LSS auto-fade overlay (CanvasLayer 127) overlaps with cutscene CanvasLayer 10**: CanvasLayer 127 renders above CanvasLayer 10. LSS fade correctly occludes the cinematic. By design — LSS's fade signals a section boundary that supersedes the cinematic context. No code change needed. *Defended by* CR-CMC-16, ADR-0004 §IG7.
- **EC-CMC-C.5 — If CT-03 trigger fires but destination Upper Structure scene is NULL (failed scene load)**: `section_entered` fires before LSS confirms scene validity. LSS emits `transition_failed` shortly after — EC-CMC-C.1 handles InputContext cleanup. Guard: check `InputContext.is_active(LOADING)` at the top of cinematic-start; if true, abort before pushing CUTSCENE. *Defended by* CR-CMC-5, CR-CMC-3.
- **EC-CMC-C.6 — If multiple `section_entered(FORWARD)` in same physics frame (NEW_GAME boot)**: One-active invariant drops the second if first triggered a cinematic. If neither triggered a cinematic, both processed (benign — same `triggers_fired` state). Assert in debug if both FORWARD events carry different `section_id` values (LSS authoring defect). *Defended by* CR-CMC-17, CR-CMC-3.
- **EC-CMC-C.7 — If section root is freed mid-cinematic, `InputContext.CUTSCENE` could be orphaned**: Addressed by `_exit_tree` calling `_cleanup()` unconditionally, which always pops CUTSCENE. **BLOCKING coord item**: LSS section-load preamble should assert `not InputContext.is_active(CUTSCENE)` before proceeding (defensive belt-and-suspenders reset). *Defended by* CR-CMC-5; LSS coord item.

### Cluster D — Locale + tr() integration (5)

- **EC-CMC-D.1 — If player switches locale mid-card-display**: `NOTIFICATION_TRANSLATION_CHANGED` fires on all nodes. Card Labels have `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` (CR-CMC-15); the `_notification` handler re-calls `label.text = tr(key)` for each Label. Card re-renders new locale text on same frame. No card rebuild, no dismiss-gate reset. *Defended by* CR-CMC-15.
- **EC-CMC-D.2 — If player switches locale mid-cinematic (no card visible during CT-03/04/05)**: No Cutscenes-owned Label nodes are visible during a cinematic. In-cinematic HANDLER VO line is D&S SCRIPTED Category 7; D&S handles its own re-resolve per D&S §F.3. Cutscenes takes no action on locale change during cinematic playback. *Defended by* CR-CMC-10, CR-CMC-15.
- **EC-CMC-D.3 — If locale switches between `mission_started` dispatch and card Label render (race window)**: Card Labels are set at `_ready()` synchronously in the same frame as the context push. `NOTIFICATION_TRANSLATION_CHANGED` is a deferred notification dispatched at end-of-frame; if locale change fires in the same frame, the notification arrives after `_ready()` set the text, and `_notification` re-resolves to the new locale in the same frame's deferred pass. No stale locale text visible for more than one frame. *Defended by* CR-CMC-15.
- **EC-CMC-D.4 — If translation key missing from `cutscenes.csv`**: Godot's `tr()` returns the raw key string as display value (standard Godot fallback per localization-scaffold.md L132). Card displays raw key (e.g., `cutscenes.mc_briefing_title`) — immediately legible in QA, flags missing translation. No crash. Debug log: `push_warning("[Cutscenes] Missing translation key: [key]")`. *Defended by* CR-CMC-15.
- **EC-CMC-D.5 — If player chooses locale before any `mission_started` fires (first-run locale selection at boot)**: At `mission_started` → card instantiation → `_ready()` → `label.text = tr(key)` resolves against currently active locale (the player's choice). No special handling required. First briefing card displays in correct locale unconditionally. *Defended by* CR-CMC-15.

### Cluster E — Audio interaction (5)

- **EC-CMC-E.1 — If `cutscene_started` fires but AudioManager is not yet ready (init order)**: Structurally impossible. Per ADR-0007, AudioManager is autoload slot #1; Cutscenes is per-section (instantiated after all autoloads). By the time any signal reaches Cutscenes, AudioManager has been in-tree for the entire session. Document as invariant. *Defended by* ADR-0007, CR-CMC-16.
- **EC-CMC-E.2 — If `force_alert_state(SCRIPTED)` fires during a cutscene**: No stinger scheduled. Audio Concurrency Policy 3 (`cause == SCRIPTED` suppresses MusicSting) applies unconditionally. Cutscenes must always use `AlertCause.SCRIPTED` (CR-CMC-12). Code-review gate: search for `force_alert_state` in Cutscenes-authored files and verify SCRIPTED argument. *Defended by* CR-CMC-12, audio.md §Concurrency Rule 3.
- **EC-CMC-E.3 — If cutscene ends while StealthAI is in COMBAT (force-alert during cinematic put a guard in COMBAT state)**: On `cutscene_ended`, AudioManager restores section music — current state table is COMBAT (because `alert_state_changed → COMBAT` reached AudioManager during cinematic). AudioManager restores to COMBAT music track, not ambient stealth track. Correct: cinematic may have scripted a guard-combat scenario; post-cinematic world is in combat state. Cutscenes does not override or reset StealthAI state on cinematic end. *Defended by* CR-CMC-11, CR-CMC-13.
- **EC-CMC-E.4 — If player has Voice bus muted via Settings during CT-04 (HANDLER VO line)**: HANDLER line is D&S SCRIPTED Category 7 routed through Voice bus. Muted Voice bus → VO plays silently. Caption behavior is D&S + Settings jurisdiction (D&S subscribes to its own subtitles toggle, not Voice mute). Cutscenes takes no action. *Defended by* CR-CMC-10, CR-CMC-13.
- **EC-CMC-E.5 — If cinematic has zero audio cues (Mission Cards only, no music change)**: Mission Cards do not emit `cutscene_started` / `cutscene_ended` signals — those are reserved for cinematics (CT-03/04/05). Cards push CUTSCENE + display text; no AudioManager state change. Section music continues uninterrupted under the briefing dossier. Correct — dossier is paper surface, not a cinematic event. *Defended by* CR-CMC-11, C.4.1.

### Cluster F — Outline pipeline (3)

- **EC-CMC-F.1 — If cinematic calls `set_tier(NONE)`, then crashes before `restore_prior_tier()`**: Outline state permanently mutated. Primary defense: `restore_prior_tier()` is called in `_cleanup()` from all exit paths including `_exit_tree`. Secondary defense (BLOCKING coord): LSS section-teardown calls `OutlinePipeline.restore_prior_tier()` defensively as belt-and-suspenders. Code review must verify `_cleanup()` is reachable from every exit path. *Defended by* CR-CMC-14; LSS coord item.
- **EC-CMC-F.2 — If outline tier was already `NONE` before cinematic start (Settings has outline disabled)**: `set_tier(NONE)` on already-NONE is a no-op (OutlinePipeline must be idempotent — forward contract for Outline Pipeline GDD). `restore_prior_tier()` restores to NONE (no-op). Outline remains disabled post-cinematic, matching player's Settings preference. No visual artifact. *Defended by* CR-CMC-14; OutlinePipeline idempotency forward contract.
- **EC-CMC-F.3 — If CT-04 ends → CT-05 starts back-to-back; `restore_prior_tier()` re-enables outline 1-2 frames between**: 1-2 frame outline flash visual artifact. Mitigation: if LD authors CT-04+CT-05 as contiguous sequence, hold `set_tier(NONE)` across the boundary — single set/restore around the entire CT-04+CT-05 sequence. Requires MLS to emit `cutscene_sequence_started` / `_ended` rather than per-cinematic signals. **VS2 authoring decision** when CT-04/CT-05 sequencing is finalized. *Defended by* CR-CMC-14; VS2 consideration.

### Cluster G — Subscriber lifecycle + section authoring (4)

- **EC-CMC-G.1 — If `_exit_tree` fires while a card is visible**: Cutscenes' `_cleanup()` runs in `_exit_tree`: pop CUTSCENE, restore tier, disable fade, disconnect signals. Card Labels + CanvasLayer freed by engine as part of section root teardown. Brief last-frame visible before LSS fade overlay (CanvasLayer 127) occludes — acceptable. *Defended by* CR-CMC-5, CR-CMC-14, CR-CMC-16.
- **EC-CMC-G.2 — If second `CutscenesAndMissionCards` instance is accidentally instantiated in same section**: Both subscribe to same signals, both fire on `mission_started`, both attempt to push CUTSCENE — double-push violates CR-CMC-5 1:1 pairing. Debug assert: `assert(not InputContext.is_active(CUTSCENE), "[Cutscenes] Double-instance: context already CUTSCENE — authoring defect.")`. Authoring lint must enforce single-instance per section. *Defended by* CR-CMC-5, CR-CMC-16.
- **EC-CMC-G.3 — If Cutscenes node is missing from a section (forgot to instantiate)**: Mission-domain signals fire via Signal Bus and find no Cutscenes subscriber. Per ADR-0002 fire-and-forget model + MLS CR-13 anti-pattern fence, MLS gameplay beats resolve normally. Section plays silently — acceptable for pre-VS builds; QA gap in VS builds. **BLOCKING coord**: LSS section-load validation should assert Cutscenes node presence in each VS-target section. *Defended by* CR-CMC-1, MLS CR-13.
- **EC-CMC-G.4 — If Cutscenes scene fails to load (`PackedScene.instantiate()` returns null)**: MLS section-load logic must guard against null instantiation. MLS logs error and continues without Cutscenes node — same outcome as G.3 (silent section). MLS must not crash on null Cutscenes. P1 asset pipeline defect requiring QA triage, not runtime-recoverable design state. *Defended by* CR-CMC-16; MLS null-guard required.

### Cluster H — Pillar / FP enforcement (5)

- **EC-CMC-H.1 — If LD authors `show_card_on_activate = true` on the same objective beat as a cinematic trigger**: Per-objective card and cinematic trigger fire same-frame; one wins via priority (CR-CMC-17), the other drops. LD authoring rule: never place opt-in cards on objectives whose activation also triggers a cinematic. **BLOCKING coord**: authoring lint should flag this pattern. *Defended by* CR-CMC-17, FP-CMC-7.
- **EC-CMC-H.2 — If writer authors an Eve VO line in a Cutscenes-triggered MLS beat**: Code review catches `speaker == &"PROTAGONIST"` in any dialogue line authored under Cutscenes' `scripted_dialogue_trigger` call. Line rejected at review. CR-CMC-20 + Pillar 1 are absolute. CT-04 HANDLER exception is the only off-screen voice permitted; must not set precedent for protagonist VO. *Defended by* CR-CMC-20, FP-CMC-1.
- **EC-CMC-H.3 — If designer requests letterbox on CT-03 or CT-04**: Rejected. `letterbox: bool = true` is set only on `CT_05_BombDisarm` resource. CutscenePlayer creates letterbox `ColorRect` nodes only when `letterbox == true`. Structural enforcement, not soft convention. *Defended by* CR-CMC-18, FP-V-CMC-9, FP-CMC-12.
- **EC-CMC-H.4 — If designer requests skip-cinematic-by-default for accessibility**: Refer to settings-accessibility.md L1346 — cutscene skip toggle is out of scope for Settings; Cutscenes owns its own skip behavior (C.2.2: no first-watch skip). **Polish accessibility spike**: a `text_summary_of_cinematic` accessibility feature (brief on-screen prose description for players who cannot process visual-audio composition) flagged for Polish-phase consultation with accessibility-specialist. NOT an MVP/VS commitment. *Defended by* CR-CMC-2, FP-CMC-2; Polish spike.
- **EC-CMC-H.5 — If player files a feature request for "skip cutscene"**: No scenario exists in which a player is trapped re-watching a cinematic. CR-CMC-4 unconditionally suppresses cinematics on RESPAWN/NEW_GAME/LOAD_FROM_SAVE. A cinematic in `triggers_fired` is suppressed by CR-CMC-2. Total first-watch cinematic time is <75 s across the entire session. The "skip cutscene" request is answered by the suppression architecture: the problem it would solve does not arise in practice. Communicate clearly in player documentation if the request recurs. *Defended by* CR-CMC-2, CR-CMC-4, FP-CMC-2.

---

**§E summary — coord items emerging:**

| # | Coord item | Status | Owner |
|---|---|---|---|
| EC-C.7 / EC-F.1 | LSS section-teardown defensive `restore_prior_tier()` + `assert(not InputContext.is_active(CUTSCENE))` | BLOCKING | LSS GDD coord |
| EC-G.3 | LSS section-load validation: assert Cutscenes node present in each VS-target section | BLOCKING | LSS GDD coord + CI lint |
| EC-G.4 | MLS null-guard on `PackedScene.instantiate()` for Cutscenes scene | BLOCKING | MLS GDD coord |
| EC-F.2 | OutlinePipeline.set_tier idempotency forward contract | ADVISORY | Outline Pipeline GDD coord |
| EC-F.3 | MLS `cutscene_sequence_started`/`_ended` if CT-04+CT-05 are authored back-to-back | ADVISORY (VS2) | MLS GDD coord at VS2 |
| EC-H.1 | Authoring lint: opt-in objective + cinematic trigger same-frame collision | ADVISORY | Tools-Programmer (lint) |
| EC-H.4 | Polish accessibility spike: `text_summary_of_cinematic` for players who cannot process visual-audio composition | POLISH SPIKE | accessibility-specialist consult |

## Dependencies

### F.1 — Hard Upstream Dependencies (this GDD cannot ship without these)

| # | Dependency | Status | Contract |
|---|---|---|---|
| 1 | **Mission & Level Scripting (#13)** | ✅ APPROVED 2026-04-24 + cross-review closure 2026-04-28 | Sole publisher of Mission-domain signals (`mission_started`/`_completed`/`objective_started`/`_completed`); owner of `MissionState.triggers_fired` write authority; per-section scene authoring instantiates Cutscenes CanvasLayer; null-guard on `PackedScene.instantiate()` (EC-G.4); section-teardown defensive `restore_prior_tier()` + InputContext clean-stack assertion (EC-C.7 / EC-F.1) |
| 2 | **ADR-0002 Signal Bus Event Taxonomy** | ACCEPTED + amendments landed 2026-04-28 | Mission-domain signals frozen in §Mission domain block; **NEW Cutscenes domain** to be added via this GDD's BLOCKING coord (`cutscene_started(scene_id)` + `cutscene_ended(scene_id)`); `ui_context_changed` already declared (UI domain, 2026-04-28 amendment) |
| 3 | **ADR-0003 Save Format Contract** | ACCEPTED | `MissionState.triggers_fired: Array[StringName]` frozen schema; Cutscenes is read-only consumer (per CR-CMC-2 + CR-CMC-21); MLS is sole writer |
| 4 | **ADR-0004 UI Framework** | ACCEPTED + Amendment A6 (MODAL/LOADING) landed; **NEW Amendment A7 required** to add `Context.CUTSCENE` enum value | CanvasLayer 10 z-order locked + lazy-instance discipline; InputContext.CUTSCENE push/pop authority assigned to CutscenesAndMissionCards; modal-dismiss grammar via `_unhandled_input` + `cutscene_dismiss` action |
| 5 | **ADR-0007 Autoload Load Order Registry** | ACCEPTED + amendments landed 2026-04-27 | Cutscenes is **NOT autoload** (slot #9 = MLS; registry full at 10 slots). Per-section CanvasLayer scene instantiated by MLS section authoring |
| 6 | **ADR-0008 Performance Budget Distribution** | PROPOSED + amendments landed 2026-04-28 night | **NEW amendment required** (BLOCKING coord) to register Slot 7 sub-claim 0.00–0.20 ms peak event-frame + Slot 8 trigger-evaluation absorbed in residual margin |
| 7 | **Audio (#3)** | ✅ APPROVED 2026-04-21 + cross-review closure 2026-04-28 | Music bus state table `CUTSCENE` row; silence-cut for cutscene track swap (Crossfade Rule 6); SCRIPTED-cause stinger suppression (Concurrency Rule 3); subscribes to NEW `cutscene_started`/`_ended` signals; `music_crossfade_default_s = 2.0 s` |
| 8 | **Post-Process Stack (#5)** | DESIGNED + cross-review pending fresh re-review | Owns `enable_sepia_dim()`/`disable_sepia_dim()` API (consumed by CR-CMC-22); **NEW API required** (BLOCKING coord) `enable_fade_to_black(duration_s)`/`disable_fade_to_black(duration_s)` for cinematic fade; idempotency contract for `set_tier()` (EC-F.2) |
| 9 | **Outline Pipeline (#4)** | DESIGNED + cross-review pending fresh re-review | Owns `OutlineTier.set_tier()` + `restore_prior_tier()` escape-hatch APIs (consumed by CR-CMC-14 with strict save-restore symmetry); idempotency required if tier already at requested value |
| 10 | **Localization Scaffold (#7)** | DESIGNED + cross-review pending fresh re-review | `cutscenes.csv` table with `cutscenes.*` key namespace; `tr()` at render time with `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`; `NOTIFICATION_TRANSLATION_CHANGED` live-resolve as documented consumer guarantee (ADVISORY coord per L132/L186) |
| 11 | **Stealth AI (#10)** | ✅ APPROVED | Exposes `force_alert_state(guard, state, AlertCause.SCRIPTED)` API consumed by CR-CMC-12; SCRIPTED cause is the contract for stinger suppression |
| 12 | **Level Streaming (#9)** | ✅ APPROVED 2026-04-22 + cross-review closure 2026-04-28 | Sole publisher of `section_entered(section_id, reason: TransitionReason)`; LS L320 confirms Cutscenes branch table; **L204 ADVISORY touch-up** (RESPAWN branch should read "suppresses unconditionally"); LSS section-load + section-teardown defensive calls (EC-C.7/EC-G.3) |
| 13 | **Save / Load (#6)** | DESIGNED 2026-04-28 + cross-review CR-6 extension closure | F5 silently dropped during CUTSCENE (CR-6 already extended); subscribes to `Events.game_loaded` (CR-CMC-21); does not hold direct reference to Cutscenes |
| 14 | **HUD Core (#16)** | ✅ APPROVED 2026-04-26 + cross-review closure | CR-10 auto-hide on `InputContext != GAMEPLAY`; HUD CR-22 `Tween.kill` on `ui_context_changed` defends against tween orphans; HUD does not coordinate directly with Cutscenes |
| 15 | **Dialogue & Subtitles (#18)** | ✅ APPROVED 2026-04-28 night (Phase 2 closure) | Self-suppresses on `ui_context_changed != GAMEPLAY` (ADR-0004 §IG5 + D&S §F.3); D&S handles SCRIPTED Category 7 in-cinematic dialogue via MLS `scripted_dialogue_trigger`; Cutscenes owns title-card text only |
| 16 | **Settings & Accessibility (#23)** | ✅ APPROVED 2026-04-27 + cross-review closure | Cinematic-skip toggle out of scope per L1346; Cutscenes owns its own skip behavior; Voice bus mute affects in-cinematic VO at AudioManager level (not Cutscenes' concern) |
| 17 | **Input (#2)** | ✅ APPROVED pending coord items 2026-04-27 | **NEW BLOCKING coord**: add `cutscene_dismiss` action to action catalog; add `Context.CUTSCENE` to blocked-actions table; document push/pop authority |

### F.2 — Soft Upstream Dependencies (enhanced by but works without)

| # | Dependency | Status | Contract |
|---|---|---|---|
| 1 | **Menu System (#21)** | ✅ APPROVED 2026-04-26 PM | When Pause Menu is authored beyond Day-1 MVP, must document `CUTSCENE` as blocked-entry context for Pause entry-point (forward dep) |
| 2 | **Civilian AI (#15)** | ✅ APPROVED 2026-04-25 + cross-review closure | Civilian positions during cinematics are LD-authored in cinematic scene; no runtime coordination with Cutscenes |
| 3 | **Combat & Damage (#11)** | ✅ APPROVED 2026-04-22 + cross-review closure | Combat is not paused during CUTSCENE (only INPUT is blocked); LD authoring guide documents that guards remain active unless frozen by scripted MLS beat |
| 4 | **Document Collection (#17)** | ✅ APPROVED 2026-04-27 + cross-review closure | DC interact gate blocked by CUTSCENE context (DC forward contract); no direct coupling |
| 5 | **Document Overlay UI (#20)** | DESIGNED 2026-04-27 + cross-review pending fresh re-review | Mutually exclusive via InputContext (DOCUMENT_OVERLAY at CanvasLayer 5; CUTSCENE at 10; FP-CMC-6 enforced) |
| 6 | **HUD State Signaling (#19)** | DESIGNED 2026-04-28 evening + cross-review pending fresh re-review | HSS suppressed when context != GAMEPLAY (own design); no coordination with Cutscenes |
| 7 | **Failure & Respawn (#14)** | ✅ APPROVED 2026-04-24 + cross-review closure | F&R triggers `LS.transition_to_section(_, _, RESPAWN)`; CR-CMC-4 unconditionally suppresses cinematics on RESPAWN |

### F.3 — Forward Dependencies (downstream systems consume Cutscenes outputs)

None. Cutscenes is a leaf node of the system graph: it consumes signals + APIs from upstream systems but emits no signals consumed by other systems (the `cutscene_started` / `cutscene_ended` signals are consumed by AudioManager only, which is also upstream by load-order — Audio is autoload slot #1, instantiated long before Cutscenes per-section scene loads). MLS reads `MissionState.triggers_fired` via its own API; Cutscenes never writes to it. No system depends on Cutscenes for its own correctness.

### F.4 — Forbidden Non-Dependencies (Cutscenes must NEVER reference these directly)

| System | Reason |
|---|---|
| MLS, HUD Core, HSS, AudioManager, Dialogue & Subtitles, Combat, Stealth AI, Civilian AI, Inventory, Document Collection, Document Overlay UI | CR-CMC-13 anti-pattern fence — all coordination via Signal Bus only |
| Tier 2 Rome / Vatican mission systems | Per game-concept.md §Scope Tiers, post-launch only — no forward-leaning architectural commitment |
| Multiplayer / network systems | Game is single-player only (game-concept.md §Core Identity); no network-domain signals |

The only permitted exceptions to CR-CMC-13 are: (a) read of `MissionState.triggers_fired` via `MissionLevelScripting.get_mission_state()` accessor (Resource read, not live-node); (b) `OutlinePipeline.set_tier()` / `restore_prior_tier()` calls; (c) `PostProcessStack.enable_sepia_dim()` / `enable_fade_to_black()` lifecycle calls.

### F.5 — Coord Items Consolidated

#### F.5.1 BLOCKING for VS sprint kickoff (10)

| # | Item | Owner | Source |
|---|---|---|---|
| OQ-CMC-1 | ADR-0004 Amendment A7: add `Context.CUTSCENE` to `InputContext.Context` enum + push/pop authority table entry assigning Cutscenes as sole pusher/popper | TD + Lead Programmer | CR-CMC-5, ADR-0004 L270 |
| OQ-CMC-2 | ADR-0002 amendment: add Cutscenes domain section with `signal cutscene_started(scene_id: StringName)` + `signal cutscene_ended(scene_id: StringName)`; signal count grows 41 → 43 | Signal Bus owner | CR-CMC-11, audio.md L407 forward-dep |
| OQ-CMC-3 | ADR-0008 amendment: register Slot 7 Cutscenes sub-claim 0.00–0.20 ms peak event-frame + Slot 8 absorbed in residual margin (per F.6 amendment language in §D) | Performance Analyst + TD | F.1 + F.2 + F.6 |
| OQ-CMC-4 | Audio §F amendment: subscribe to NEW `cutscene_started`/`_ended` signals; document `CUTSCENE` row in Music bus state table per §States; verify Crossfade Rule 6 silence-cut covers cutscene track swap from `cutscene_started` payload | Audio Director | CR-CMC-11, EC-CMC-E.5 |
| OQ-CMC-5 | PPS GDD amendment: add `enable_fade_to_black(duration_s)` / `disable_fade_to_black(duration_s)` API pair; document Cutscenes as valid caller of outline-tier escape-hatch (`set_tier(NONE)` + `restore_prior_tier()`); add `set_tier()` idempotency forward contract per EC-CMC-F.2 | PPS GDD owner | CR-CMC-22, CR-CMC-14, EC-F.2 |
| OQ-CMC-6 | MLS GDD §C.4 amendment: add `MissionObjective.show_card_on_activate: bool = false` field; add per-section cutscene + card trigger roster (CT-03 / CT-04 / CT-05 + briefing + closing + 2 objective cards + VS2-reserved) for section-validation pipeline; add MLS-emitted `cutscene_started`/`_ended` from cinematic completion callbacks; add MLS section-load null-guard on the **PackedScene load() call** (NOT on `instantiate()` return — `instantiate()` does not return null on OOM in Godot 4.6; null-guard on `load()` per godot-specialist 2026-04-28 night) per EC-CMC-G.4; add `MissionLevelScripting.get_mission_state()` public read-only accessor — **must return the live `MissionState` instance, NOT a `duplicate()` or `duplicate_deep()` copy** (godot-specialist BLOCKING — replay-suppression breaks silently if a copy is returned); add MLS-side AC pinning dispatch order `mission_started` before `objective_started` for same-frame dispatch (per AC-CMC-5.2 forward dep); guarantee `mission_started` fires AFTER LSS overlay clears (deferred-call queued in same frame as `section_loaded` per §C.4.1 + ux-designer 2026-04-28 night) | MLS GDD owner + Tools-Programmer | C.4, EC-CMC-G.4, CR-CMC-2, AC-CMC-5.2, §C.4.1 |
| OQ-CMC-7 | LSS GDD edits: (a) **L204 touch-up** correct RESPAWN branch description from "checks `triggers_fired`" to "suppresses unconditionally" (aligns CR-CMC-4); (b) section-teardown defensive `OutlinePipeline.restore_prior_tier()` + `assert(not InputContext.is_active(CUTSCENE))` per EC-CMC-C.7 / EC-CMC-F.1; (c) section-load validation: assert Cutscenes node presence in each VS-target section per EC-CMC-G.3 | LSS GDD owner | EC-C.7, EC-G.3, F.1 |
| OQ-CMC-8 | Localization Scaffold authoring contract: register `cutscenes.csv` table + 16-key minimum roster (5 briefing + 5 closing + 4 × 2 objective cards + 1 ct_04 VO + 1 ct_05 caption); confirm `NOTIFICATION_TRANSLATION_CHANGED` live-resolve as documented consumer guarantee (ADVISORY) | Localization Lead + Writer | C.6, EC-D.1 |
| OQ-CMC-9 | Input GDD action catalog: add `cutscene_dismiss` action (default Esc / B); add `CUTSCENE` to InputContext blocked-actions table | Input GDD owner | CR-CMC-5, C.2.4 |
| OQ-CMC-10 | Writer Brief authoring (`design/narrative/cutscenes-writer-brief.md`): mirror structure of `document-writer-brief.md` and `dialogue-writer-brief.md` — 4 surface-type voice rules + 7-card roster (2 mission cards + 2 objective cards + 3 cinematic captions/VO) + Saul Bass typographic register guide + Rome cliffhanger seed authoring guidance (note narrative-director finding: PA-65-001/IT-65-002 numbering implies parallel registries, not threat-continuation — Rome implication rests on `ROME STATION ADVISED` alone) + classification stamp lexicon (CLASSIFIED — BQA EYES ONLY / MISSION CLOSED — FILE TO ARCHIVE / STATUS: CLOSED) + 12-word card body cap + tonal-anchor question reuse from §B "Would Saul Bass sign their name to this?" + concrete examples of permissible understatement vs. forbidden wink (TR-7 boundary) + **HANDLER VO production exception**: CT-04 line is the only VO asset with baked transceiver EQ (HP 400 / LP 3200 / BP 1800 Hz); all other VO assets are clean recordings (audio.md Voice bus has no runtime EQ insert per audio-director 2026-04-28 night). **Promoted to BLOCKING per game-designer cross-review 2026-04-28 night** — Pillar 1 voice cannot be authored without this brief; card body copy is gated on its existence. | Writer + Narrative Director | C.4, C.5, C.7, GAP-2, A.3 |
| OQ-CMC-11 (PROMOTED to BLOCKING) | **`text_summary_of_cinematic` accessibility feature** (per accessibility-specialist + ux-designer + creative-director cross-review 2026-04-28 night — moved from Polish-spike): Settings-gated reveal of a 3–5 sentence prose summary per cinematic (CT-03/CT-04/CT-05) for players who cannot process visual-audio cinematic composition. Implementation: 1 Label on CanvasLayer 10 + 3 `cutscenes.cinematic_summary.<ct_id>` localization keys + `Settings.get("accessibility", "cinematic_text_summary_enabled")` gate. Renders within active letterbox area (817 px on CT-05). When enabled, replaces — not augments — the standard cinematic playback. **VS-recommended MVP** per CD adjudication; complementary fallback to OQ-CMC-17 skip carve-out. | Accessibility Specialist + Writer | EC-CMC-H.4, OQ-CMC-17 (carve-out pair) |
| OQ-CMC-17 | **settings-accessibility.md amendment** (per FP-CMC-2 Stage-Manager carve-out, creative-director adjudicated 2026-04-28 night): add `accessibility_allow_cinematic_skip: bool` setting in Accessibility subcategory, default `false` (Pillar 5 preserved as shipping default). When `true`, Cutscenes honors `cutscene_dismiss` action during cinematic first-watch via §C.2.4 handler (skipped cinematic still records to `triggers_fired`; no replay on respawn). Companion to OQ-CMC-11 (`text_summary_of_cinematic`). Anchored to Combat §B Stage-Manager precedent for accessibility opt-in carve-outs to Pillar absolutes. | Settings & Accessibility GDD owner | §C.2.2, FP-CMC-2 carve-out, AC-CMC-4.4b |
| OQ-CMC-18 | **Dialogue & Subtitles GDD amendment — SCRIPTED Category 8 (non-dialogue narrative captions)**: extend D&S §F to add Category 8 for narrative-critical SFX captions during cinematics. Define `MLS scripted_caption_trigger(scene_id, caption_key)` API (separate from `scripted_dialogue_trigger`). Categories 7+8 are exempted from D&S's `ui_context_changed != GAMEPLAY` self-suppression (per CR-CMC-10 boundary clarification). Caption render position must be within active letterbox image area (817 px on CT-05). Roster minimum: 3 caption keys for CT-05 (`cutscenes.caption.ct_05.tick_steady`, `tick_cessation`, `wire_cut`). Closes accessibility-specialist Finding 4 (deaf players miss CT-05 narrative climax). | D&S GDD owner + Writer | CR-CMC-10, accessibility BLOCKING #4 |
| OQ-CMC-19 | **HUD Core CR-10 ordering rule + Godot 4.6 verification tasks**: (a) HUD Core CR-10 spec must echo the boundary-frame ordering rule from Cutscenes CR-CMC-9 (HUD `_on_ui_context_changed` synchronous handler, no `CONNECT_DEFERRED`, completes `visible = false` + Tween.kill before Cutscenes' first AnimationPlayer/Tween advance); (b) Godot 4.6 docs cross-check for `AUTO_TRANSLATE_MODE_DISABLED` constant name (introduced 4.5; verify 4.6 stability); (c) AccessKit `accessibility_*` property names verified against Godot 4.6 (closes ADR-0004 Gate 1 inherited flag); (d) downgrade VG-CMC-1, VG-CMC-3, VG-CMC-5 from BLOCKING to documentation-notes per godot-specialist 2026-04-28 night (answerable from engine-reference docs without editor verification); VG-CMC-2 (dual-focus split) and VG-CMC-4 (constant verification) remain BLOCKING. | HUD Core GDD owner + godot-specialist | CR-CMC-9, performance BLOCKING #1, godot-specialist findings |

#### F.5.2 ADVISORY (defer to Polish or VS2)

| # | Item | Owner | Source |
|---|---|---|---|
| OQ-CMC-11 | Polish accessibility spike: `text_summary_of_cinematic` feature for players who cannot process visual-audio cinematic composition (EC-CMC-H.4) | Accessibility Specialist | EC-H.4 |
| OQ-CMC-12 | VS2 authoring decision: if CT-04 + CT-05 are authored as a contiguous beat-chain, MLS emits `cutscene_sequence_started`/`_ended` rather than per-cinematic signals to avoid 1-2 frame outline flash between (EC-CMC-F.3) | MLS GDD owner | EC-F.3 |
| OQ-CMC-13 | Tools-Programmer authoring lint: flag `show_card_on_activate = true` on objectives whose activation also triggers a cinematic (EC-CMC-H.1) | Tools-Programmer | EC-H.1 |
| OQ-CMC-14 | OutlinePipeline `set_tier()` idempotency forward contract verification (EC-CMC-F.2) | Outline Pipeline GDD owner | EC-F.2 |
| OQ-CMC-15 | Polish: 3rd-person cinematic camera rig + character cinematic animation pipeline (deferred per §A — "the GDD specs trigger contract + skip lifecycle + asset slots, not camera rig") | Animation + Tools | §A |
| OQ-CMC-16 | Polish: case-file post-credits flashback / cutscene-replay-from-Pause-Menu (deferred; `MissionState.triggers_fired` is one-shot at MVP/VS) | Menu System owner + Cutscenes | §A |

### F.6 — Bidirectional Consistency Check Reprise (cross-reference §C.16)

§C.16 contains the full row-by-row verification of every claim about Cutscenes in the existing GDDs/ADRs. The summary verdict:

| Source GDD/ADR | Verdict |
|---|---|
| MLS L296 / L554 / L592 / L918 | ✅ Consistent — MLS coord #11 closes on this GDD's approval |
| Audio L407 / L727 | ✅ + BLOCKING ADR-0002 amendment per OQ-CMC-2 |
| PPS L97 / L229 / L356 | ✅ + BLOCKING PPS amendment per OQ-CMC-5 |
| Localization L132 / L186 | ✅ + ADVISORY consumer-guarantee touch-up |
| D&S L886 / L1399 | ✅ Resolved — boundary clarified in CR-CMC-10 |
| Save/Load L107 / L162 / CR-6 | ✅ Consistent |
| LS L122 / L320 | ✅ Consistent |
| LS L204 | **ADVISORY discrepancy** — touch-up per OQ-CMC-7(a) |
| HUD Core L1007 | ✅ Consistent |
| Settings L1346 | ✅ Consistent |
| ADR-0004 L270 | ✅ Resolved — `InputContext.CUTSCENE` declared via OQ-CMC-1 |
| ADR-0002 L103 | ✅ Resolved — Cutscenes does NOT subscribe to `ui_context_changed` directly (it pushes the context that triggers the signal) |

## Tuning Knobs

Cutscenes & Mission Cards has a deliberately small tunable surface. The system's player-facing values are tightly coupled to the Saul Bass / Pillar 5 register — most numeric values are NOT designer-adjustable because adjusting them breaks the period-authentic frame composition (e.g., Pillar 5 forbids "fade durations" because Saul Bass cuts; the dismiss-gate hold values are hand-tuned to the specific Bass-grammar pacing). The knobs that ARE tunable cluster into three groups: per-surface dismiss-gate durations, per-cinematic durations, and ADR-locked / Pillar-absolute values that look tunable but aren't.

### G.1 — Cutscenes-Owned Tuning Knobs (5)

| # | Knob | Default | Safe range | Affects | Tuning gameplay aspect |
|---|---|---|---|---|---|
| 1 | `cutscenes_dismiss_gate_briefing_s` | **4.0 s** | [3.0, 6.0] | Mission Briefing Card silent-drop window before Esc/B is honored | Below 3.0 s the player can dismiss before the card has been read; above 6.0 s feels punitive and breaks the "silent gate, observed once" rhythm (FP-CMC-3) |
| 2 | `cutscenes_dismiss_gate_closing_s` | **5.0 s** | [4.0, 8.0] | Mission Closing Card silent-drop window | Closing card carries Rome cliffhanger seed (REF: IT-65-002 line) — the extra 1.0 s vs briefing exists to ensure the player notices the routing line. Below 4.0 s the cliffhanger is missable; above 8.0 s feels theatrical (Pillar 5 violation — Bass cuts, doesn't linger) |
| 3 | `cutscenes_dismiss_gate_objective_s` | **3.0 s** | [2.0, 5.0] | Per-objective opt-in card silent-drop window | Objective cards carry less critical content than Mission Cards; faster gate maintains gameplay flow. Below 2.0 s the card is unreadable; above 5.0 s it overstays into stealth-loop interruption |
| 4 | `cutscenes_letterbox_slidein_frames` | **12 frames (0.20 s @ 60 fps)** | [8, 24] | CT-05 letterbox bar Tween-in duration | Below 8 frames feels jarring (no perceived "curtain coming down"); above 24 frames feels theatrical and breaks the hard-cut grammar (Pillar 5). Linear easing is locked (`TRANS_LINEAR`) — easing function is NOT a tunable knob |
| 5 | `cutscenes_closing_fade_to_black_frames` | **24 frames (0.40 s @ 60 fps)** | [16, 48] | Mission Closing Card → credits fade-to-black duration | Below 16 frames feels abrupt for a credits transition; above 48 frames creeps into modern-cinematic-fade register (Pillar 5 violation) |

### G.2 — Cinematic Duration Caps (3) — bounded by FC-8 + AC-CMC-BUDGET

| # | Knob | Authored default | Range cap | Pillar enforcement |
|---|---|---|---|---|
| 1 | `cutscenes_ct03_duration_s` | 12–15 s authored target | ≤ 15 s hard cap | Pillar 5 + Pillar 2 (FC-8 + AC-CMC-BUDGET-1); LD authoring discipline |
| 2 | `cutscenes_ct04_duration_s` | 18–22 s authored target | ≤ 22 s hard cap | Pillar 5 + Pillar 2 |
| 3 | `cutscenes_ct05_duration_s` | 25–30 s authored target | ≤ 30 s hard cap | Pillar 5 + Pillar 2 |

These are not runtime-tunable knobs; they are AnimationPlayer track lengths set at authoring time. The CI lint should verify `AnimationPlayer.length` ≤ caps for each cinematic resource.

### G.3 — Inherited Tuning Knobs (Cutscenes consumes; not owned)

| Knob | Owner | Default | Cutscenes' relationship |
|---|---|---|---|
| `music_crossfade_default_s` | Audio (`audio.md` Tuning) | 2.0 s | Used at `cutscene_ended` for Music bus crossfade-restore (CR-CMC-11) |
| `voice_overlay_duck_db` | Audio | -12.0 dB | Inherited Voice bus duck during cinematics with HANDLER VO; Audio-side, not Cutscenes' concern |
| `subtitle_size_scale` / `subtitle_background` / `subtitle_speaker_labels` | Settings & Accessibility (Phase 2 propagation 2026-04-28 night) | per Settings G.3 | D&S handles in-cinematic subtitle rendering (SCRIPTED Category 7); Cutscenes does NOT render subtitles |
| `outline_thickness_px` (Tier 1) | Outline Pipeline | 4 px | Cutscenes consumes via `set_tier(NONE)` / `restore_prior_tier()` escape-hatch (CR-CMC-14); per-tier thickness is Outline Pipeline's |
| `pps_sepia_dim_intensity` | Post-Process Stack | per PPS GDD | Cutscenes calls `enable_sepia_dim()` for Mission Briefing dim; intensity is PPS-side |
| `pps_fade_to_black_default_duration_s` | Post-Process Stack (NEW per OQ-CMC-5) | TBD via PPS coord | Cutscenes calls `enable_fade_to_black(duration_s)` with explicit duration; PPS may have a default for callers that omit duration |

### G.4 — ADR-Locked Values (look tunable but aren't)

| Value | Locked by | Rationale |
|---|---|---|
| **CanvasLayer index = 10** | ADR-0004 §IG7 + HUD Core L1007 | Z-order registry is project-wide locked; mutually exclusive with Settings panel via lazy-instance discipline |
| **Op-art sub-CanvasLayer index = 11** | This GDD §C.9 + ADR-0004 §IG7 (proposed addition via OQ-CMC-1) | Single layer between Cutscenes (10) and Subtitles (15) with no other claim; index 11 is reserved for CT-05 op-art only |
| **ADR-0008 Slot 7 sub-claim 0.00–0.20 ms peak event-frame** | ADR-0008 (NEW amendment per OQ-CMC-3) | Sub-claim ceiling is contractual; cannot be raised without renegotiating Slot 7 with HUD Core / HSS |
| **Mission Card title typeface = Futura Extra Bold Condensed @ 36 px** | Art Bible §3.7 + §8C + §Typography table L539 | Asset standard, not tunable |
| **BQA Blue color = `#1B3A6B`** | Art Bible §3.3 + §Color Palette + Document Overlay UI §A | Color palette is project-locked |
| **Parchment color = `#F2E8C8`** | Art Bible + Document Overlay UI + DC §V | Color palette is project-locked |
| **Ink Black color = `#0A0A0A`** | Art Bible + Outline Pipeline (4 px Tier 1 stroke color) | Color palette is project-locked |
| **Letterbox aspect ratio = 2.35:1 (CT-05 only)** | CR-CMC-18 + FP-V-CMC-9 | Reserved exclusively for CT-05; cannot be applied elsewhere or changed |
| **Cinematic skip on first-watch = NEVER (default)** | §C.2.2 + Pillar 5 default | Architecturally locked as the *default*. The Settings-gated `accessibility_allow_cinematic_skip` carve-out (default `false`, per Stage-Manager precedent) does NOT count as a tuning knob — it is an opt-in accessibility setting owned by Settings & Accessibility GDD #23 (per OQ-CMC-17). Any *tuning* that allows mid-cinematic skip without the explicit Settings opt-in is a Pillar 5 violation |
| **`reason in {RESPAWN, NEW_GAME, LOAD_FROM_SAVE}` → unconditional suppress** | CR-CMC-4 | Architecturally locked |

### G.5 — Pillar Absolutes (changing these breaks the design)

| Absolute | Pillar enforcement |
|---|---|
| Eve never narrates / quips during any Cutscenes surface | Pillar 1 (CR-CMC-20 + FP-CMC-1) |
| Mission-complete card never reads "MISSION ACCOMPLISHED" or any modern-action-game equivalent | Pillar 5 (TR-6 + FC-1 narrative-director enforced) |
| No "Press any key" prompt, no progress bar, no greyed-out skip button | Pillar 5 (FP-CMC-3) |
| Hard-cut entry for Mission Cards (no fade-in) | Pillar 5 + Art Bible §3.7 (CR-CMC-19) |
| Saul Bass / *Our Man Flint* / 1965 cinema-graphic-design register | Pillar 5 load-bearing (§B tonal-anchor question) |
| Total non-gameplay surface time ≤ 1.5% of session | Pillar 2 + Pillar 5 (AC-CMC-BUDGET, F.5) |
| Cutscenes is NOT autoload; per-section CanvasLayer | ADR-0007 |
| Single-instance discipline per section | CR-CMC-16 |
| Mission-domain signals are MLS sole-publisher | ADR-0002 + MLS CR-7 + CR-CMC-1 |
| `cutscene_dismiss` is a dedicated InputMap action (NOT `ui_cancel`) | CR-CMC-5 + C.2.4 |

### G.6 — Ownership Matrix (which system owns each tuning value)

| Knob | Owner | Source of truth |
|---|---|---|
| Dismiss-gate durations | Cutscenes | This GDD §G.1 |
| Cinematic duration caps | Cutscenes (LD-authored AnimationPlayer length) | This GDD §G.2 |
| CanvasLayer 10 / sub-layer 11 z-order | ADR-0004 + this GDD | ADR-0004 §IG7 |
| Music crossfade durations | Audio | `audio.md` Tuning |
| Voice bus duck | Audio | `audio.md` Tuning |
| Subtitle styling | Settings + D&S | settings-accessibility.md §G.3 |
| Sepia-dim intensity / fade-to-black duration default | Post-Process Stack | post-process-stack.md (after OQ-CMC-5 amendment) |
| Outline tier thickness | Outline Pipeline | outline-pipeline.md |
| Color palette | Art Bible (§Color) + project_theme.tres | Art Bible §3.3 |
| Typography | Art Bible (§Typography) + FontRegistry | Art Bible §8C |
| Localization key strings | Writer + Localization Scaffold | `translations/cutscenes.csv` (per OQ-CMC-8) |

## Visual/Audio Requirements

### V.1 — Mission Card Visual Spec (Briefing + Closing)

**Background fill**: Full-screen Parchment `#F2E8C8` `ColorRect` anchored `PRESET_FULL_RECT` on the cutscene CanvasLayer at index 10. No texture grain, no noise overlay, no vignette. Flat Parchment field, indistinguishable from the Document Overlay's card body register. Shared Parchment `StyleBoxFlat` material with Document Overlay UI.

**Header strip**: BQA Blue `#1B3A6B` horizontal band, full screen width, **80 px tall at 1080p**, flush to top edge. Hard rectangle, no radius, no shadow. Contents in 24 px left margin: BQA logotype glyph (~28 px tall, Parchment fill) + `"OPERATION: THE PARIS AFFAIR"` in `FontRegistry.menu_title()` (Futura Extra Bold Condensed) white `#FFFFFF` 18 px tracked +60 + REF routing string `"BQA/CMC-[mission_id]/[date_code]"` American Typewriter Regular 13 px Parchment right-aligned 24 px right margin. Header is identical on briefing + closing; REF string differentiates (`-BR` briefing, `-CL` closing).

**Title block**: Centered horizontally; positioned **148 px from top** (68 px below header strip + 80 px breathing margin — Saul Bass anchors titles in upper third, not center). `FontRegistry.menu_title()` **36 px** Ink Black `#0A0A0A` tracking −10 (condensed face tightened — poster, not headline). Two lines max; if title exceeds single line at 36 px, break at semantic division; second line LEFT-aligned (deliberate Bass asymmetry).

For the **briefing card**: title block contains mission name only (`OPERATION: PARIS AFFAIR`).
For the **closing card**: title block contains the mission name + closing status `OPERATION: PARIS AFFAIR — STATUS: CLOSED` (per §C.4.2 + TR-6); the title is a single line at 36 px Futura Extra Bold Condensed; the cliffhanger `REF:` routing line appears below the body block, NOT in the title block (per TR-10). The phrase `OBJECTIVE COMPLETE` is forbidden per TR-6 + AC-CMC-9.2 — do not author it on this surface.

**Body block**: American Typewriter Regular 18 px Ink Black `#0A0A0A`. Positioned 40 px below title block baseline. Left-aligned at 72 px margin. Line-length cap **52 chars** per TR-9, enforced via `custom_minimum_size` clamp on `RichTextLabel` at ~560 px wide @ 1080p. Hard wrap. No hyphenation. Line height 1.4× (25 px leading at 18 px). Max body length: **6 lines briefing / 4 lines closing + 1 cliffhanger line**.

**Rules and stamps**: Two Ink Black 1 px horizontal rules — one 8 px below header strip bottom edge (full-width seam), one 8 px above footer row. `StyleBoxFlat` border-bottom entries, not separate nodes. Third 2 px rule separates title block from body block (weight-step signals hierarchy).

Classification stamp: American Typewriter Bold 16 px tracking +100 Ink Black, positioned bottom-right at 32 px from bottom + 72 px from right. **Rotated −5 degrees** (hard rotate transform, not font slant — stamp landed at slight angle, as stamps do). Briefing: `"CLASSIFIED — BQA EYES ONLY"`. Closing: `"MISSION CLOSED — FILE TO ARCHIVE"`.

**Entry transition**: **Hard cut, 0 frames**, per Art Bible §3.7 ("Saul Bass title sequences cut; they do not wipe or cross-fade"). Card appears instantaneously.

**Hold duration**: Briefing 4.0 s dismiss-gate; Closing 5.0 s dismiss-gate (per CR-CMC-2.1).

**Exit transition**: Briefing → hard-cut to gameplay (0 frames; symmetrical with entry). Closing → **24-frame fade-to-black** (0.4 s linear, ColorRect alpha 0→1 via Tween) then cut to credits or post-mission state (CR-CMC-19; user decision Q4 separate fade-to-black PPS API).

### V.2 — Objective Card Visual Spec (Per-Objective Opt-In)

**Position**: Bottom-third of screen, centered horizontally, **bottom edge 120 px from viewport bottom** (clears HUD health/ammo strips at ~28 px).

**Dimensions**: **720 × 200 px @ 1080p**. Body (4-line American Typewriter 16 px @ 28 px leading) = 112 px + header 40 px + 24 px padding = 200 px exactly. Width 720 px gives 50-char line length at American Typewriter 16 px (~13.8 px/char × 52 chars = 731 px → trim to 720 px enforces 50-char max).

**Background**: Parchment `#F2E8C8` `StyleBoxFlat` with Ink Black `#0A0A0A` 1 px border on all four edges. No shadow, no glow, no radius. Thin rule is the only frame.

**Header**: BQA Blue `#1B3A6B` strip, full card width, **36 px tall**. Contents: BQA classification stamp glyph 16 px Parchment left-aligned 16 px margin + objective label in Futura Extra Bold Condensed 16 px Parchment tracking +40 left-center of strip. Reads: `"OBJECTIVE"` or `"CHARGE: SET"` in stamp register. No icon, no bullet.

**Body**: American Typewriter Regular 16 px Ink Black. Top padding 8 px below header. Left/right margin 16 px. Max 4 lines at 28 px leading. Tracking 0 (body, not stamp). Authored short — target 1–2 lines; 4-line cap is hard maximum.

**Slide-in motion**: Paper-translate from below. Tween `TRANS_SINE` `EASE_OUT` **8 frames (0.133 s @ 60 fps)**. Start `position.y = viewport_height + 20`; end at final anchor. Coherent with Document Overlay paper-translate-in grammar (Art Bible §7D — translates 15% below final resting position over 12 frames; Objective Card uses same vocabulary at faster duration). No fade — translate only.

**Hold duration**: 3.0 s dismiss-gate. If `cutscene_dismiss` pressed before 3.0 s, silently dropped per CR-CMC-2.1.

**Slide-out motion**: **Hard cut to invisible (0 frames)**. Recommendation against translate-out — translate-out creates visual noise in lower third while player is re-engaging gameplay; hard cut is a clean dismissal. The card has done its job; vanishes cleanly.

### V.3 — Letterbox Visual Spec (CT-05 EXCLUSIVELY)

Per CR-CMC-18 + FP-V-CMC-9: 2.35:1 letterbox is reserved for CT-05 only. Forbidden on CT-03, CT-04, briefing, closing, objective cards.

**Bar dimensions @ 1080p (2.35:1 crop)**: Active image area 1920 × 817 px. **Top bar 131 px** + **bottom bar 132 px** (1 px asymmetry acceptable at integer rounding; align top-131/bottom-132 convention). Both bars: full viewport width, Ink Black `#0A0A0A` `ColorRect` on Cutscenes CanvasLayer.

**Slide-in Tween**: Top bar from `position.y = -131` → `position.y = 0`. Bottom bar from `position.y = 1080` → `position.y = 948`. Tween duration **12 frames (0.20 s @ 60 fps)**, `TRANS_LINEAR` (no softness — bars arrive with mechanical finality, not cinematic dissolve). The letterbox closing should feel like a gate coming down, not a curtain drawing.

**Bar color**: Ink Black `#0A0A0A` (slight warmth reads as printed black, not digital void — coherent with comic-panel register).

**Sub-CanvasLayer at index 11 — CT-05 op-art**: Concentric circle motif rendered inside the 817 px active image area. **5–7 concentric circles** centered on bomb device's detonator face in screen space, 2 px Ink Black `#0A0A0A` stroke rings + alternating fill in **saturated cyan `#00B4D8`** and Ink Black. Radii stepping outward: 24, 52, 84, 120, 160, 204, 250 px @ 1080p. Cyan selected as spectral complement to PHANTOM Red `#C8102E` (cool cyan vs warm red — classic 1965 threat/agency opposition displaced onto the device). Circles appear at letterbox-slide-in completion (frame 13 of CT-05 entry); hold for cinematic duration. **NOT animated** (no rotation, no pulsing, no opacity flicker — still graphic element on moving shot, not VFX). Exit with letterbox bars on CT-05 close.

### V.4 — Per-Cinematic Visual Direction

**CT-03 Kitchen Egress (12–15 s, full-frame)**: Restaurant warm interior grammar (Paris Amber `#E8A020` dominant + Parchment walls + crystal pendant lights) collides with one saturated chromatic event — explosion as **single-frame color-field expansion** in saturated **Comedy Yellow `#F5D000`** (closer to comic-register than lethal-orange) pushing outward from kitchen service door, bleaching warm palette to white at peak, returning to Paris Amber over 3–4 frames. Saul Bass title-sequence chromatic hit — color held as flat field, NOT particle system. Post-explosion trail: kitchen steam as flat white silhouette shapes against warm amber recovery. **No lens flare, no motion blur, no bloom.** Composition: medium shot of Eve exiting through service door; explosion graphic flat shape behind her; door frame defining vertical axis. Door frame is dominant compositional line — dark Eiffel Grey `#6B7280` ironwork against saturated flash; Eve small silhouette cutting through center. Should read as Saul Bass frame frozen at maximum graphic clarity.

**CT-04 The Rappel (18–22 s, full-frame)**: Upper Structure palette — **Moonlight Blue `#B0C4D8`** sky, **Eiffel Grey `#6B7280`** ironwork, **Paris Amber `#E8A020`** city-glow rising from below. Tower geometry becomes the entire visual content: ironwork lattice rendered as **flat graphic black lattice** (Ink Black `#0A0A0A` heaviest outline weight) against dusk-orange-to-deep-blue **two-stop flat gradient** sky (Paris Amber at horizon → Moonlight Blue above — consistent with Upper Structure mood: "warm city glow below / cool moonlit iron above"). Eve rappelling is a small silhouette — Tower geometry owns the frame. The shot's compositional hero is the Tower as flat graphic shape: Pillar 4 (Iconic Locations as Co-Stars) load-bearing here. Viewer should briefly mistake this for a Saul Bass title card before Eve's motion confirms it as a game sequence. **Pacing**: first 8 frames held static (Eve not yet moving), then rappel motion begins — Saul Bass grammar applying itself.

**CT-05 Bomb Disarm (25–30 s, letterboxed 2.35:1)**: Bomb Chamber palette — **clinical cool fluorescent overhead `#C8E6F0`**, **PHANTOM Red `#C8102E`** on device indicator lamps, near-black `#0A0A0A` corners, **op-art cyan `#00B4D8`** circles rendering through letterbox. Shot structure: **close on device casing → cut to Eve's hands on detonator → wide on Tower exterior visible through antenna maintenance aperture**. Device close = tightest frame — concentric circle op-art appears here, centered on detonator face. PHANTOM Red indicator lamps blink once (one cycle ~0.5 Hz, consistent with §4.2's "only object that blinks" rule). Hands-on-detonator cut = flat-angle medium close — Eve's midnight-navy jacket against device casing, op-art circles at periphery. **Eve's face NOT shown** (she is a pair of hands and a jacket — FPS register collapsing into cinematic). Wide on Tower = graphic payoff: Eiffel Tower as flat silhouette shape against Paris city-sky (warm amber street-grid below, Moonlight Blue above) — entire mission's city-visibility arc resolves in this single frame. **No quip, no reaction shot.** Sequence ends on Tower wide as letterbox bars reverse out (12-frame slide-out). Cinema releases.

### V.5 — Forbidden Visual Patterns (FP-V-CMC-1..FP-V-CMC-9)

| # | Pattern | Pillar / rule violated |
|---|---|---|
| **FP-V-CMC-1** | Motion blur on any cinematic or card surface | Pillar 5 (post-2000 cinematic convention contradicts comic-panel register); also project-wide forbidden by PPS Core Rule (outline shader needs clean geometry edges) |
| **FP-V-CMC-2** | Depth-of-field rack focus on any cinematic | Pillar 5 (rack focus is film-stock cinema register, not Saul Bass graphic cinema) — `DOFBlurFar` / `DOFBlurNear` nodes never activated during cinematics |
| **FP-V-CMC-3** | Bloom on Mission Cards, objective cards, or BQA header strips | PPS Core Rule 8 (project-wide); also: BQA Blue header must read as printed ink (luminance bleed destroys letterhead register) |
| **FP-V-CMC-4** | "Filmic" tonemapping (ACES, Filmic Blender, Godot's TONE_MAPPER_FILMIC) during cinematics | Project palette designed for unlit rendering; filmic tonemap shifts hues. Cinematics use `Environment.tone_mapper = TONE_MAPPER_LINEAR` |
| **FP-V-CMC-5** | Drop shadows on text in mission cards, objective cards, or cinematic title treatments | No precedent in 1965 printed materials; drop shadows are digital-design convention. Legibility via color contrast + outline weight, not shadow |
| **FP-V-CMC-6** | Rounded corners on any card, strip, or compositional rectangle (`StyleBoxFlat.corner_radius_*` must be 0) | Hard-edged geometry only; rounded corners = post-2000 interface convention (iOS 7 grammar) |
| **FP-V-CMC-7** | Inline icons within body copy of mission cards or objective cards | Body copy is typewriter text; typewriters cannot produce inline icons |
| **FP-V-CMC-8** | Pixel-art, lo-fi dithering, retro-CRT visual registers on any cutscene/card surface | Game's identity is HIGH graphic design (Saul Bass / Air France / Courrèges 1965), NOT lo-fi or retro-pixel |
| **FP-V-CMC-9** | Letterbox bars on CT-03 or CT-04 (per FC-7 + CR-CMC-18) | 2.35:1 letterbox reserved exclusively for CT-05; applying earlier dilutes the grammar |

### V.6 — Asset List (4–6 bitmap assets total)

**Shared with Document Overlay UI (no duplication required)**:
- Parchment `#F2E8C8` flat `StyleBoxFlat` material (1 shared resource)
- `FontRegistry.document_body()` — American Typewriter Regular (already registered)
- `FontRegistry.document_header()` — American Typewriter Bold (already registered)
- `FontRegistry.menu_title()` — Futura Extra Bold Condensed (already registered)

**Mission Card–specific authored assets**:
1. `ui_bqa_crest_glyph_28.png` — BQA logotype silhouette glyph, Parchment on transparent, 28 × 28 px (shared with Document Overlay if asset already exists)
2. `ui_stamp_classified_bqa.png` — "CLASSIFIED — BQA EYES ONLY" stamp, Ink Black on transparent, pre-rotated −5°, ~280 × 60 px
3. `ui_stamp_missionclosed.png` — "MISSION CLOSED — FILE TO ARCHIVE" stamp, same spec, separate asset
4. (Rule tiles and border `StyleBoxFlat` resources are procedural — not authored bitmaps)

**Objective Card–specific**:
5. `ui_objectivecard_border_stylebox.tres` — Theme entry, not standalone asset

**CT-05 Op-Art Compositional Elements**:
6. `vfx_ct05_opart_concentric_loop_large.png` — pre-rendered concentric ring motif, 7 rings, alternating cyan `#00B4D8` + Ink Black, 2 px stroke, 512 × 512 px transparent. Per-shot offset alignment (detonator screen-space position); not auto-tracked
7. Letterbox bars implemented as `ColorRect` nodes (not authored textures — zero VRAM)

**PHANTOM mark / BQA crest**: deferred to Document Collection asset pass (where all in-world PHANTOM typographic elements are authored together); referenced here, not introduced.

**Approximate total authored bitmap assets**: 4–6.

---

### A.1 — Per-Surface Audio Specification

#### A.1.1 Mission Briefing Card

**Music**: Section ambient music continues unmodified during entire card display. **No duck.** Card is diegetic-paper interrupting in-progress scene, NOT theatrical mode. Both `MusicDiegetic` + `MusicNonDiegetic` layers stay at current `volume_db` throughout 4.0 s gate + dismiss. Rationale: 4.0 s hold is shorter than any meaningful crossfade cycle; ducking and restoring would produce two audible tween events reading as "the game acknowledging the card" — Bass grammar refuses this.

**SFX**: None card-specific. The `period radio static + 3-blink morse BQA signature` from `mission_started` (audio.md SFX catalog) plays at signal fire — already specified, completes before the briefing card's dismiss-gate expires. That signal-blip IS the briefing card's audio identity.

**Forbidden**: AFP-CMC-3 (card-open sting), AFP-CMC-4 (room-tone bed during card display).

#### A.1.2 Mission Closing Card

**Entry audio state**: When `mission_completed` fires after CT-05's `cutscene_ended`, the `MISSION_COMPLETE` state instant-cuts both music layers to −80 dB. The `MusicSting` victory sting plays on the Music bus (already authored per audio.md). **No music to restore — `MISSION_COMPLETE` instant cut IS the silent entry condition for closing card.** No additional silence logic required.

**During 5.0 s dismiss-gate**: Silence (except any in-flight `MusicSting` victory sting from `mission_completed` — fire-and-forget, completes naturally).

**On dismiss + 24-frame fade-to-black**: Silence holds through fade-to-black. **No credits theme at MVP.** See A.4.

**SFX**: None. **No dossier-stamp foley** on closing card. The `STATUS: CLOSED` stamp is typographic punctuation, not a sound effect. AFP-CMC-3 enforced.

#### A.1.3 Per-Objective Opt-In Cards

**Entry**: Silence (no card-open sting per AFP-CMC-3).

**Paper-translate-in SFX (8-frame slide)**: **Single brief paper-shuffle foley hit** — non-spatial UI bus, ~120 ms, 800–2,400 Hz, no reverb tail (period dry), timed to start of 8-frame Tween. Coherent with `document_opened`'s paper rustle register. **Loudness: −22 LUFS peak, UI bus.** Asset: `sfx_ui_card_slide_in_01.ogg`.

**Dismiss SFX**: NONE recommended. A typewriter clack would carry connotations of completion/punctuation — editorializes. Dismiss is procedural event, not narrative beat. AFP-CMC-3 applies regardless of timbre.

**Underlying music**: Section `*_calm` music continues unmodified during 3.0 s gate + dismiss.

#### A.1.4 Cinematics CT-03 / CT-04 / CT-05

**On `cutscene_started(scene_id)` signal** (per OQ-CMC-2 + audio.md Crossfade Rule 6):
- `MusicDiegetic` instant-cuts to −80 dB (silence-cut, NOT crossfade)
- `MusicNonDiegetic` instant-cuts to −80 dB
- Music bus enters `CUTSCENE` state
- `MusicNonDiegetic` player loads + begins per-cinematic composed audio file (resolved by `scene_id` from `cutscene_track_dict`)
- Any in-flight alert-state tween cancelled immediately

**On `cutscene_ended(scene_id)`**: AudioManager crossfades back to `[section]_calm` over `cutscene_restore_crossfade_s` (default 2.0 s). Exception: CT-05 — `mission_completed` fires same-frame and `MISSION_COMPLETE` instant cut overrides the restore (same-frame priority guard required in AudioManager).

### A.2 — CT-03 Kitchen Egress (12–15 s)

**Music**: **Pure silence-cut.** No composed non-diegetic music plays during CT-03. Absence of score is load-bearing — explosion is "evidence in a report, not a movie moment" (§B Vignette 3). Hammond pedal note or jazz drumbeat would signal "this is exciting" — Pillar 1 refuses this editorial. Restaurant ambient (`French dining murmur, glassware clink`) continues at current level — kitchen explosion happens *within* the restaurant world; dining-room ambient continuing reinforces disproportion comedy.

**SFX sequence (AnimationPlayer-cued, pooled 3D)**:
1. **Detonation crack** — frame 0: single transient, 150–200 ms, 80–6000 Hz shaped, peak energy 200 Hz, hard high-pass above 8000 Hz (period — no modern sub-bass boom), reverb tail ≤ 0.4 s. Asset: `sfx_env_explosion_charge_crack_01.ogg`.
2. **Kitchen contents clatter** — begins 80 ms after detonation, 600–800 ms duration: controlled irregular ceramic/glass/metal clatter (consequence, not spectacle); 3–4 pooled 3D hits, staggered positions, no reverb tail > 0.5 s.
3. **Eve footsteps** — tile surface, `normal` variant (5.0 m noise radius); 3–5 steps over 12–15 s.
4. **Service-door hinge** — 2-stage: hinge creak as door bulges (~600 ms, 300–900 Hz wood-frame resonance) + burst-open clatter (~200 ms metallic). 3D positional. Assets: `sfx_env_door_hinge_strain_01.ogg` + `sfx_env_door_burst_01.ogg`.

**Dialogue**: NONE. AFP-CMC-5 enforced.

**Stinger suppression**: Any guard `force_alert_state(_, SCRIPTED)` during cinematic = NO MusicSting per Concurrency Rule 3. AFP-CMC-1 enforced.

### A.3 — CT-04 The Rappel (18–22 s)

**Music**: **Silence holds for full cinematic.** No Hammond chord, no sustained string, no period-jazz minor swell at HANDLER line. The HANDLER line is the only emotional weight; scoring underneath would signal how to feel about it — Bass grammar refuses (§B score-test). CT-04's composed audio file = **null/silent track** — AudioManager loads it on `cutscene_started`, produces no audible output. Upper Structure ambient (`wind across ironwork, distant city`) continues at current level — wind ambience already authored as section ambient loop; ambient bus NOT ducked during cinematic.

**SFX sequence**:
1. **Rappel-line** — carabiner clip onto rail (~150 ms metallic click, 1000–4000 Hz, non-spatial — listener close to Eve) + rope friction whir (~2–3 s continuous tone, pitch-rising slightly as descent accelerates, 300–800 Hz). 3D positional at Eve. Assets: `sfx_env_rappel_carabiner_01.ogg`, `sfx_env_rappel_rope_descent_loop.ogg`.
2. **Wind at altitude**: Upper Structure ambient already contains ironwork wind — no additional layer.
3. **Distant Paris**: ambient already contains `distant city glow, 1–2 km sirens` — no additional layer.

**HANDLER VO line `[HANDLER]: Sterling. Clock is running.`**:
Render as **diegetic low-fi radio** — tinny EQ (high-pass 400 Hz, low-pass 3200 Hz, slight bandpass resonance 1800 Hz simulating 1965 portable transceiver), brief noise-floor crackle (−30 dB under signal) at line start + line end. Rationale: HANDLER communicates via field radio; non-diegetic narrator register would imply voice in Eve's head, breaking Pillar 1. Low-fi places HANDLER firmly in the world. **EQ values are production guidance for the D&S VO asset file**; Audio's Voice bus mix applies no additional per-channel EQ. D&S owns the AudioStreamPlayer + plays the VO file; Audio applies VO duck (Ambient ducks −6 dB from current Upper Structure level under the HANDLER line — wind recedes slightly, line stays audible without removing world entirely). AFP-CMC-5 enforced (Eve silent throughout).

**Post-HANDLER through landing**: Silence. No resolution swell. Eve's non-response IS the wit (Pillar 1).

**Mid-cinematic transition out**: On `cutscene_ended`, AudioManager crossfades to `chamber_calm` over 2.0 s. Bomb Chamber ambient (`fluorescent ballast hum, mechanical clock tick`) fades in.

### A.4 — CT-05 Bomb Disarm Audio (25–30 s, letterboxed 2.35:1)

The system's sole composed-audio cinematic. All prior cinematics refuse the score; CT-05 earns a single composed element.

**Hammond chord specification**:
- **Pitch**: F minor triad voiced 2nd inversion (C–F–Ab). **Bass note (lowest sounding pitch): C2 (~65.4 Hz)** — the chord's 5th is in the bass, per 2nd inversion definition. Chord root: F (the chord is F minor). The "F2 (87 Hz)" reference applies to the *chord root pitch class for theory bookkeeping only*, NOT the lowest-played note. Hammond drawbars at 8' / 4' / 2' on bass note C2 — NO 16' sub (period authentic; Shirley Scott / Jimmy Smith register, NOT orchestral pad). Sound designer handoff note: deliver the chord with bass note C2; do NOT record bass note F2 or the voicing inverts to root position.
- **Dynamics**: Enter at −18 dB on `cutscene_started` downbeat; passively swell to −10 dB over 8 s (Leslie rotary speaker simulation, slow mode — amplitude modulation ~0.7 Hz, NO pitch vibrato above ±15 cents). Hold at −10 dB for remainder. **NO crescendo toward wire-cut. NO dynamic change on wire-cut event.** Held tone resolves into silence (§B: "held tones resolve, do not build").
- **Duration**: Sustains from cinematic start through 8-frame black hold; fades to −80 dB over 0.5 s after `cutscene_ended` (fade-out overlaps with hard-cut to black, inaudible).
- **Asset**: `mus_cutscene_ct05_hammond_chord.ogg`, stereo, 48 kHz, −14 LUFS integrated, routed to `MusicNonDiegetic`.

**Device tick**: Bomb Chamber ambient loop already authors `mechanical clock tick (bomb)` at ~100 BPM on Ambient bus as diegetic 3D spatial element at device position. **This tick IS the cinematic's rhythmic element** — NOT a separate cinematic event. Camera close on device → 3D spatial tick prominent in near-field mix. **No new tick SFX added for cinematic.**

**Wire-cut SFX**: **Single muted snip** — NOT a sharp metallic clack. Rationale: sharp clack reads as decisive/satisfying/triumphant; the smallness of the sound IS the joke (Pillar 1 — climax proportionate to nothing). ~80 ms, 200–1200 Hz shaped centered 600 Hz, **−30 dB relative to Hammond chord**, no reverb tail. Asset: `sfx_env_wire_cut_01.ogg`, non-spatial, SFX bus.

**Post-wire-cut**: Hammond chord holds. Ticks continue 2 frames, then 3D device tick (Ambient bus) **stops abruptly** on `objective_completed` — bomb disarmed; tick's cessation is the only confirmation. No fanfare.

**Post-disarm silence before hard-cut to black**: 1.2 s held silence (Hammond chord still sustaining at −10 dB; device tick stopped; no other SFX). Tuning Knob: `cutscene_ct05_postdisarm_hold_s = 1.2`, safe [0.8, 2.0].

**8-frame black hold**: Hammond chord begins 0.5 s fade-out here. Silence arrives before Mission Closing Card cuts in.

### A.5 — Mission-Complete Music Handoff (MVP/VS)

After Closing Card's 5.0 s gate + 24-frame fade-to-black + cut to credits → **silence**. **No credits theme at MVP/VS.** audio.md L727 logic: at MVP, mission-complete state is the victory sting on `MusicSting` (already specified) followed by silence. `MISSION_COMPLETE` state in Music bus state table holds through closing card + credits fade. If credits authored as VS deliverable, composed credits theme (`mus_credits_paris_affair_loop.ogg`, period-jazz vibraphone lead, Mancini register, −14 LUFS) may be added in subsequent pass — **this GDD does not commission it.**

### A.6 — Audio-Side Coordination Items (BLOCKING)

**Item A.6.1 — `audio.md` §F amendment**: AudioManager subscribes to NEW `cutscene_started(scene_id: StringName)` + `cutscene_ended(scene_id: StringName)` signals (per OQ-CMC-2). Subscription in `_ready()`, unsubscribe in `_exit_tree()` per audio.md Rule 3 lifecycle. Handler `_on_cutscene_started(scene_id)` routes Music bus to `CUTSCENE` state (silence-cut Rule 6) + loads per-cinematic composed audio from `cutscene_track_dict`. Handler `_on_cutscene_ended(scene_id)` triggers `cutscene_restore_crossfade_s` restore — except same-frame `mission_completed` (CT-05 path) where `MISSION_COMPLETE` instant cut takes precedence. **Same-frame priority guard required in AudioManager (per audio-director cross-review 2026-04-28 night):** the `MISSION_COMPLETE` handler MUST call `Tween.kill()` on every in-flight Music bus crossfade tween before applying the instant cut, regardless of frame-ordering. Without explicit `Tween.kill()`, an in-flight cross-fade started on the prior frame will continue advancing `volume_db` even after the instant-cut assignment, fighting the manual write. This is a new audio.md Concurrency Policy item (Policy 4): "On `MISSION_COMPLETE` state entry, AudioManager kills all in-flight Music bus tweens before applying state-defined volumes." Codify in `audio.md §Concurrency` as a forward-coord BLOCKING amendment.

**Item A.6.2 — `audio.md` §C amendment**: `CUTSCENE` row already exists; amend to clarify `MusicNonDiegetic` is **silence-cut** (NOT crossfade) per Rule 6, and `cutscene` track is NOT shared single track — resolved per `scene_id` at `cutscene_started` time from `Dictionary[StringName, String]` owned by AudioManager.

**Item A.6.3 — `audio.md` §Tuning amendment**: Add 5 new knobs:
- `cutscene_track_dict` (authored Dictionary `scene_id → composed audio file path`; AudioManager-owned)
- `cutscene_restore_crossfade_s = 2.0` (safe [0.5, 4.0])
- `cutscene_ct05_postdisarm_hold_s = 1.2` (safe [0.8, 2.0])
- `cutscene_ct05_hammond_fade_out_s = 0.5` (safe [0.2, 1.0])
- `cutscene_card_slide_sfx_db = -22.0` (safe [-30.0, -16.0])

### A.7 — Forbidden Audio Patterns (AFP-CMC-1..AFP-CMC-8)

| AFP # | Forbidden pattern | Pillar / rule | Enforcement site |
|---|---|---|---|
| **AFP-CMC-1** | Stinger / brass stab on `actor_became_alerted(_, SCRIPTED, _, _)` during any cinematic | Pillar 1 + audio.md Concurrency Policy 3 | AudioManager `_on_actor_became_alerted`: `cause == SCRIPTED` guard blocks stinger schedule |
| **AFP-CMC-2** | Music swell, crescendo, or dynamic build toward a climactic cinematic beat | Pillar 1 + §B refusal #2 + FP-CMC-5 | Composed audio file spec (CT-05 chord holds; never grows); audio director signs off pre-integration |
| **AFP-CMC-3** | Card-open sting, card-dismiss chime, musical punctuation on card entry/exit | Pillar 5 (Bass cuts; doesn't sting) | No SFX event in CutscenePlayer card-entry/dismiss code path for musical events; paper-slide foley (A.1.3) is UI bus + non-musical |
| **AFP-CMC-4** | Room-tone or ambient-bed introduced specifically for Mission Card display | Period authenticity — cards are diegetic-paper, not theatrical-mode | Section ambient continues unchanged; no new ambient layer instantiated |
| **AFP-CMC-5** | Any VO line attributed to `PROTAGONIST` / `STERLING` speaker during any card, objective card, or cinematic | Pillar 1 (Eve doesn't narrate) | Code-review: `speaker == &"PROTAGONIST"` in MLS scripted beat inside Cutscenes-owned surface = defect |
| **AFP-CMC-6** | Reverb tail on cinematic SFX exceeding 0.5 s | Pillar 5 (1965 mix register) | All cinematic SFX assets authored dry; SFX bus reverb section-specific + short |
| **AFP-CMC-7** | Stereo-pan automation on Music bus or VO during cinematics | Period mono mix register | Hammond chord mono-centered; HANDLER VO mono center; diegetic SFX 3D-positioned engine attenuation only — synthetic LFO pan automation forbidden |
| **AFP-CMC-8** | Silence-cut music restore at `cutscene_ended` when section music layers are coherent | Craft — abrupt restore breaks Pillar 3 (stealth is theatre) | `_on_cutscene_ended` always uses crossfade Tween, never hard stop-and-start; exception is CT-05 path (`mission_completed` same-frame override) |

## UI Requirements

### UI.1 — Boundaries: what Cutscenes & Mission Cards owns vs. delegates

**Cutscenes owns the rendering of**:
- Mission Briefing Card (full-screen Parchment letterhead on CanvasLayer 10)
- Mission Closing Card (full-screen Parchment letterhead + 24-frame fade-to-black)
- Per-Objective Opt-In Cards (720 × 200 px slide-in card on CanvasLayer 10)
- CT-05 Letterbox bars (`ColorRect` on CanvasLayer 10) + op-art sub-CanvasLayer 11 (`TextureRect`)
- The `cutscene_dismiss` action handling within `_unhandled_input` on the CanvasLayer root

**Cutscenes does NOT own**:
- HUD visibility — HUD Core CR-10 owns `InputContext != GAMEPLAY` auto-hide
- Subtitle rendering / suppression — D&S §F.3 owns `ui_context_changed` self-suppression; D&S handles SCRIPTED Category 7 in-cinematic dialogue (CT-04 HANDLER line)
- Sepia-dim shader / fade-to-black implementation — Post-Process Stack owns `enable_sepia_dim()` / `enable_fade_to_black()`
- Outline post-process — Outline Pipeline owns `OutlineTier.set_tier()` / `restore_prior_tier()`
- Theme inheritance / FontRegistry — ADR-0004 + project_theme.tres own
- Music bus state / track loading — AudioManager owns
- Player camera rig — Polish-deferred (§A); Cutscenes owns the trigger contract + skip lifecycle + asset slots, NOT camera rig internals
- Pause Menu / Settings entry — Menu System / Settings own (Cutscenes pushes `InputContext.CUTSCENE` which the entry-points self-gate)

### UI.2 — Per-Surface UX Forward Dependencies

For VS Phase 4 sprint planning, the following per-surface UX specs must be authored via `/ux-design` BEFORE epic/story creation:

1. **Mission Briefing Card** — `/ux-design cutscenes-mission-briefing-card`
2. **Mission Closing Card** — `/ux-design cutscenes-mission-closing-card`
3. **Per-Objective Opt-In Card** — `/ux-design cutscenes-objective-card`
4. **CT-05 Letterbox + Op-Art Composite** — `/ux-design cutscenes-ct05-letterbox`

The 3rd-person cinematic camera rig + character cinematic animation pipeline (per Polish deferral OQ-CMC-15) does NOT need a UX spec at VS — it specs trigger + skip + asset slots only.

### UI.3 — Pillar Absolutes Re-Stated for UI Implementation

- **Pillar 5 absolute (FP-CMC-3)**: NO "Press any key to continue" prompt, progress bar, greyed-out skip button, or visible dismiss affordance on cards before dismiss-gate expires. The silent-drop convention IS the UX.
- **Pillar 5 absolute (FP-CMC-2)**: NO mid-cinematic skip on first-watch. No skip surface visible during cinematics CT-03/04/05.
- **Pillar 1 absolute (FP-CMC-1)**: NO Eve VO during any Cutscenes-owned surface. Frame carries the wit.
- **Pillar 1 absolute (CR-CMC-19)**: NO fade-in entry on Mission Cards (hard-cut). No paper-translate-in on Mission Cards (objective cards only). The Bass grammar is hard cuts.
- **Pillar 5 absolute (CR-CMC-18 / FP-V-CMC-9)**: 2.35:1 letterbox ONLY on CT-05.
- **AccessKit per-widget table** (revised per accessibility-specialist cross-review 2026-04-28 night):
  - **Mission Briefing Card / Mission Closing Card**: `accessibility_role = ROLE_DIALOG` (modal — CUTSCENE context blocks all other input) + `accessibility_name = tr(title_key)` + `accessibility_description = tr(body_key) + " " + tr(stamp_key)`. On hard-cut entry, push focus to the card root via `grab_focus()` so screen reader announces title → body → stamp in scripted order. `accessibility_live = LIVE_ASSERTIVE` (hard-cut entry warrants assertive announcement on appear).
  - **Per-Objective Card**: `accessibility_role = ROLE_STATUS` (non-modal — gameplay continues) + `accessibility_live = LIVE_POLITE`. No focus grab (player retains gameplay focus); screen reader announces politely without interrupting gameplay context.
  - **Cinematics CT-03/CT-04/CT-05**: `accessibility_role = ROLE_REGION` + `accessibility_live = LIVE_POLITE` on the CanvasLayer root for HANDLER VO line render path (CT-04). For CT-05, the closed-caption Label nodes (per OQ-CMC-18 D&S Category 8 contract) inherit `LIVE_POLITE` for SFX caption announcements.
  - **Dismiss-gate open announcement (NEW per accessibility BLOCKING):** When the SceneTreeTimer fires and `_dismiss_gate_active = false`, Cutscenes emits a polite live-region announcement via the card root's `accessibility_live = LIVE_POLITE` channel (e.g., set `accessibility_description += " — ready to dismiss"` then revert one frame later, or use AccessKit's queued-announcement API). This satisfies WCAG 2.1 SC 4.1.3 Status Messages without violating FP-CMC-3 (which forbids *visible* affordances; screen-reader-channel updates are exempt). Implementation: one line in the timer's `timeout` callback. Closes accessibility-specialist Finding 2 (silent-drop UX trap for blind/low-vision players).
  - **ADR-0004 Gate 1 verification**: `accessibility_*` property names confirmed in Godot 4.6 per OQ-CMC-19 verification task (engine-reference cross-check); flag inherited from prior GDDs is closed by this verification + the per-role table above.

### UI.4 — UX Flag for VS Phase 4

> **📌 UX Flag — Cutscenes & Mission Cards**: This system has 4 distinct player-facing UI surfaces (briefing card / closing card / objective card / CT-05 letterbox+op-art). In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for **each** surface BEFORE writing epics. Stories that reference Cutscenes UI should cite `design/ux/cutscenes-[surface].md`, NOT this GDD directly.

## Acceptance Criteria

> **Notation**: All ACs are **BLOCKING** unless tagged **ADVISORY**. Story types: **[Logic]** (GUT unit test), **[Integration]** (multi-system test), **[Visual]** (screenshot + lead sign-off), **[UI]** (manual walkthrough doc), **[Code-Review]** (grep / static analysis), **[Config/Data]** (smoke check). Evidence paths in `tests/unit/`, `tests/integration/`, `tools/ci/`, or `production/qa/evidence/`. ACs marked **BLOCKED-on [OQ-CMC-N]** cannot be verified until that coord item closes.

### H.1 — Subscription + Sole-Publisher Discipline (CR-CMC-1, CR-CMC-13; F.3)

**AC-CMC-1.1** [Code-Review] [BLOCKING] — BLOCKED-on OQ-CMC-2 (signal names declared)
GIVEN the full `src/` tree, WHEN CI runs `grep -rn --exclude-dir=tests "Events\.mission_started\.emit\|Events\.mission_completed\.emit\|Events\.objective_started\.emit\|Events\.objective_completed\.emit" src/` filtering out the sole-publisher file (`src/gameplay/mission_scripting/mission_level_scripting.gd`), THEN zero matches. Any match in `src/gameplay/cutscenes/` is a BLOCKING defect.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh` exit 0. *Defended by* CR-CMC-1, FP-CMC-10.

**AC-CMC-1.2** [Logic] [BLOCKING]
GIVEN `CutscenesAndMissionCards._ready()` executes, WHEN `Events.mission_started.is_connected(_on_mission_started)` is queried, THEN it returns `true`. Repeat for all 4 Mission-domain subscriptions (`mission_completed`, `objective_started`, `section_entered`) and for `game_loaded`. GIVEN `_exit_tree()` fires, THEN all five `is_connected()` checks return `false`.
*Evidence*: `tests/unit/cutscenes/subscriber_lifecycle_test.gd` — `test_all_signals_connected_on_ready`, `test_all_signals_disconnected_on_exit_tree`. *Defended by* CR-CMC-1, CR-CMC-13.

**AC-CMC-1.3** [Code-Review] [BLOCKING]
GIVEN `src/gameplay/cutscenes/cutscenes_and_mission_cards.gd`, WHEN CI runs `grep -n "get_node\|get_parent\|get_node_or_null"`, THEN zero matches except self-referential `@onready` declarations OR calls targeting the four ADR-0004-permitted exceptions (`Events`, `MissionLevelScripting.get_mission_state()`, `OutlinePipeline`, `PostProcessStack`).
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* CR-CMC-13, FP-CMC-11.

**AC-CMC-1.4** [Logic] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night
GIVEN a fresh section load with Cutscenes in tree, WHEN the test calls `watch_signals(Events)` (GUT built-in) and emits `Events.mission_started.emit(...)` directly, THEN `assert_signal_emit_count(Events, "mission_started", 1)` passes (handler ran once) AND `assert_signal_emit_count(Events, "objective_started", 0)` AND `assert_signal_emit_count(Events, "objective_completed", 0)` AND `assert_signal_emit_count(Events, "mission_completed", 0)` (Cutscenes did not re-emit any Mission-domain signal). Spy mechanism: GUT's `watch_signals(node_or_object)` registers signal-emit interception on the `Events` autoload for the duration of the test. Re-emit detection is via the assertion that no Cutscenes-originated emit increments the count beyond the test's own controlled emit.
*Evidence*: `tests/unit/cutscenes/subscriber_lifecycle_test.gd` — `test_mission_started_received_not_re_emitted` using `watch_signals(Events)` + `assert_signal_emit_count`. *Defended by* CR-CMC-1, FP-CMC-10.

### H.2 — InputContext.CUTSCENE Lifecycle (CR-CMC-5, CR-CMC-6, CR-CMC-7)

**AC-CMC-2.1** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-1 (Context.CUTSCENE enum value declared)
GIVEN `_context_pushed == false` and `InputContext.current() == GAMEPLAY`, WHEN `_open_card(scene_id, CardType.MISSION_BRIEFING)` is called, THEN `InputContext.is_active(Context.CUTSCENE) == true` AND `_context_pushed == true` (same frame, before visual change). GIVEN `_dismiss()` subsequently called, THEN `InputContext.is_active(CUTSCENE) == false` AND `_context_pushed == false`.
*Evidence*: `tests/unit/cutscenes/input_context_lifecycle_test.gd` — `test_push_on_open_pop_on_dismiss_paired_1to1`. *Defended by* CR-CMC-5, ADR-0004 §IG2.

**AC-CMC-2.2** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-1
GIVEN `InputContext.CUTSCENE` is on the stack, WHEN `_exit_tree()` fires with `_context_pushed == true`, THEN `_cleanup()` calls `InputContext.pop()` and clears `_context_pushed = false` before function returns. GIVEN `_exit_tree()` fires with `_context_pushed == false`, THEN `InputContext.pop()` is NOT called and no underflow error is raised.
*Evidence*: `tests/unit/cutscenes/input_context_lifecycle_test.gd` — `test_exit_tree_pops_context_only_if_pushed`. *Defended by* CR-CMC-5, EC-CMC-C.3.

**AC-CMC-2.3** [Integration] [BLOCKING] — BLOCKED-on OQ-CMC-1
GIVEN `InputContext.CUTSCENE` is on the stack, WHEN a synthetic `ui_menu` (Esc/Start) event is delivered to `_unhandled_input`, THEN the event is consumed (`set_input_as_handled()` called) and no Pause Menu signal fires.
*Evidence*: `tests/integration/cutscenes/input_context_blocks_test.gd` — `test_ui_menu_dropped_during_cutscene`. *Defended by* CR-CMC-7, ADR-0004 §IG3.

**AC-CMC-2.4** [Integration] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night
GIVEN `InputContext.CUTSCENE` is on the stack AND **the gate-location invariant: SaveManager's `_unhandled_input` checks `InputContext.is_active(CUTSCENE)` and returns before calling `quicksave()`**, WHEN a spy on `SaveManager.quicksave()` is registered and a synthetic `quicksave` (F5) action is delivered to SaveManager's `_unhandled_input`, THEN spy records zero calls (silently dropped per Save/Load CR-6). GIVEN `CUTSCENE` NOT on stack, F5 calls `quicksave()` exactly once. The gate-location precondition is verifiable by code-review grep: `tools/ci/check_save_input_gate.sh` confirms `InputContext.is_active(CUTSCENE)` appears in SaveManager's `_unhandled_input` body.
*Evidence*: `tests/integration/cutscenes/input_context_blocks_test.gd` — `test_f5_dropped_during_cutscene`. *Defended by* CR-CMC-6, Save/Load CR-6.

### H.3 — Replay Suppression (CR-CMC-2, CR-CMC-3, CR-CMC-4, CR-CMC-21; F.3)

**AC-CMC-3.1** [Logic] [BLOCKING]
GIVEN `MissionState.triggers_fired` does NOT contain `&"mc_briefing_paris_affair"` AND `reason == FORWARD` AND `InputContext.current() == GAMEPLAY`, WHEN `_try_fire_card(...)` is called, THEN `fires(...)` evaluates `true`, `_open_card()` is called, `InputContext.CUTSCENE` is pushed.
*Evidence*: `tests/unit/cutscenes/replay_suppression_test.gd` — `test_first_arrival_forward_not_fired_fires`. *Defended by* CR-CMC-3, F.3.

**AC-CMC-3.2** [Logic] [BLOCKING]
GIVEN `MissionState.triggers_fired` already contains `&"mc_briefing_paris_affair"`, WHEN `_try_fire_card(_, _, FORWARD)` is called, THEN `_open_card()` NOT called, `InputContext` not pushed, no CanvasLayer instanced.
*Evidence*: `tests/unit/cutscenes/replay_suppression_test.gd` — `test_already_fired_suppresses`. *Defended by* CR-CMC-2, F.3.

**AC-CMC-3.3** [Logic] [BLOCKING]
GIVEN `triggers_fired` does NOT contain `&"ct_03_kitchen_egress"`, WHEN `_try_fire_card(_, _, RESPAWN)` is called, THEN function returns immediately before any `triggers_fired` membership check (RESPAWN branch short-circuits per CR-CMC-4 before CR-CMC-2). `_open_card()` NOT called. Spy on `dict.has()` records zero calls.
*Evidence*: `tests/unit/cutscenes/replay_suppression_test.gd` — `test_respawn_unconditionally_suppresses_no_fired_check`. *Defended by* CR-CMC-4, F.3 clause 1.

**AC-CMC-3.4** [Logic] [BLOCKING]
GIVEN `triggers_fired` does NOT contain `&"ct_04_the_rappel"`, WHEN `_try_fire_card` is called with `reason == NEW_GAME` then `reason == LOAD_FROM_SAVE`, THEN both calls suppress unconditionally; spy on `triggers_fired.has()` records zero calls for both.
*Evidence*: `tests/unit/cutscenes/replay_suppression_test.gd` — `test_new_game_and_load_from_save_unconditional_suppress`. *Defended by* CR-CMC-4.

**AC-CMC-3.5** [Integration] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night
GIVEN Cutscenes subscribes to `Events.game_loaded`, WHEN `game_loaded` fires and loaded `triggers_fired` contains `&"mc_briefing_paris_affair"` and `&"ct_03_kitchen_egress"`, THEN: (a) `_on_game_loaded()` executes without pushing CUTSCENE — assert `InputContext.is_active(CUTSCENE) == false` after handler returns; (b) `_open_card()` not called — spy on `_open_card` records zero calls; (c) subsequent `Events.mission_started.emit(...)` is suppressed by CR-CMC-2's replay check — spy on `_open_card` records zero calls after the second emit. The word "validates" is replaced with concrete observable post-conditions; no implicit consistency check beyond the read-only `triggers_fired` lookup is required.
*Evidence*: `tests/integration/cutscenes/replay_suppression_test.gd` — `test_game_loaded_suppresses_replays_no_implicit_validation`. *Defended by* CR-CMC-21, CR-CMC-2.

### H.4 — Dismiss Grammar (F.4; C.2)

**AC-CMC-4.1** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-9 (cutscene_dismiss in InputMap)
GIVEN Mission Briefing Card displayed (`_dismiss_gate_active == true`, `t_elapsed < 4.0 s`), WHEN synthetic `cutscene_dismiss` action delivered, THEN `set_input_as_handled()` called, `_dismiss()` NOT called, `_dismiss_gate_active` remains `true`.
*Evidence*: `tests/unit/cutscenes/dismiss_gate_test.gd` — `test_dismiss_before_gate_silently_dropped`. *Defended by* CR-CMC-6, F.4.

**AC-CMC-4.2** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-9
GIVEN Briefing Card displayed and `SceneTree.create_timer(4.0, true)` has fired (mocked clock), WHEN synthetic `cutscene_dismiss` delivered, THEN `_dismiss_gate_active == false`, `_dismiss()` called once, `InputContext.pop()` fires, `_context_pushed == false`. Hard-cut to gameplay.
*Evidence*: `tests/unit/cutscenes/dismiss_gate_test.gd` — `test_dismiss_after_gate_calls_dismiss`. *Defended by* CR-CMC-5, F.4.

**AC-CMC-4.3** [Logic] [BLOCKING]
GIVEN three card types instantiated separately (Briefing, Closing, Objective), WHEN dismiss-gate timer fires per surface, THEN `gate_duration_s` matches: Briefing 4.0 s / Closing 5.0 s / Objective 3.0 s. Assert via spy on `create_timer(duration, true)`.
*Evidence*: `tests/unit/cutscenes/dismiss_gate_test.gd` — `test_gate_duration_per_surface`. *Defended by* F.4, G.1.

**AC-CMC-4.4** [Logic] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night
GIVEN CT-05 cinematic playing (no dismiss-gate for cinematics) **AND `accessibility_allow_cinematic_skip == false` (default)** AND **first-watch precondition asserted: `assert_false(&"ct_05_bomb_disarm" in mock_state.triggers_fired, "first-watch precondition")`**, WHEN synthetic `cutscene_dismiss` delivered at any point during first-watch, THEN `_dismiss()` NOT called. Cinematics use full-duration playback per §C.2.2 default; assert `_dismiss()` call count == 0 throughout AnimationPlayer timeline. **Carve-out test (separate AC-CMC-4.4b)**: GIVEN same setup but `accessibility_allow_cinematic_skip == true`, WHEN synthetic `cutscene_dismiss` delivered, THEN `_dismiss()` called once and `InputContext.pop()` fires.
*Evidence*: `tests/unit/cutscenes/dismiss_gate_test.gd` — `test_cinematic_no_mid_watch_dismiss_default` + `test_cinematic_skip_carve_out_when_setting_enabled`. *Defended by* §C.2.2 default + Stage-Manager carve-out, FP-CMC-2.

**AC-CMC-4.5** [Code-Review] [BLOCKING] — BLOCKED-on OQ-CMC-9
GIVEN `cutscenes_and_mission_cards.gd`, WHEN CI runs `grep -n "ui_cancel"`, THEN zero matches. Sole dismiss action in `_unhandled_input` is `cutscene_dismiss`.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* C.2.4, CR-CMC-5.

### H.5 — One-Active Invariant + Priority Resolution (CR-CMC-17; C.3)

**AC-CMC-5.1** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-1
GIVEN `InputContext.CUTSCENE` already on stack, WHEN any second trigger handler fires, THEN handler checks `InputContext.is_active(CUTSCENE)` first, returns immediately without `_open_card()` or `_start_cinematic()`, emits `push_warning("[Cutscenes] drop: [scene_id] — context already CUTSCENE")` in debug builds.
*Evidence*: `tests/unit/cutscenes/one_active_invariant_test.gd` — `test_second_trigger_while_cutscene_active_drops`. *Defended by* CR-CMC-17.

**AC-CMC-5.2** [Logic] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night
GIVEN `mission_started` and `objective_started` fire same frame (sequential synchronous dispatch in test, with `mission_started` emitted first per MLS dispatch contract), WHEN both handlers execute, THEN Mission Card wins. Spy on `_open_card`: 1 call (Mission Card). Spy on `push_warning`: 1 (dropped objective). `_current_scene_id` = Mission Card scene_id. **NOTE on coverage gap**: this AC verifies Cutscenes' priority logic only. **MLS dispatch order (mission_started before objective_started) must be independently guaranteed by an MLS integration test** — if a future MLS refactor reverses the order, this AC will continue to pass while production behavior breaks. MLS coord item OQ-CMC-6 must include an MLS-side dispatch-order AC.
*Evidence*: `tests/unit/cutscenes/priority_resolution_test.gd` — `test_mission_card_beats_objective_card_same_frame`. *Defended by* CR-CMC-17, C.3.2; MLS dispatch order pinned by MLS-side AC (forward coord).

**AC-CMC-5.3** [Logic] [BLOCKING]
GIVEN cinematic active (CT-03/04/05 pushed CUTSCENE), WHEN `objective_started` fires for an opt-in objective, THEN handler finds CUTSCENE active and drops silently. `push_warning` contains dropped scene_id; `_current_scene_id` unchanged.
*Evidence*: `tests/unit/cutscenes/priority_resolution_test.gd` — `test_objective_card_dropped_during_cinematic`. *Defended by* CR-CMC-17, C.3.3.

**AC-CMC-5.4** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-1
GIVEN `CUTSCENE` on stack and `_context_pushed == true`, WHEN `_cleanup()` called from any exit path, THEN `InputContext.pop()` called once and `_context_pushed = false`. GIVEN `_context_pushed == false` when `_cleanup()` called, THEN `InputContext.pop()` NOT called.
*Evidence*: `tests/unit/cutscenes/one_active_invariant_test.gd` — `test_cleanup_pops_only_if_pushed`. *Defended by* CR-CMC-5, CR-CMC-17.

### H.6 — Outline + PPS Lifecycle (CR-CMC-14, CR-CMC-22)

**AC-CMC-6.1** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-5
GIVEN `OutlinePipeline.set_tier(OutlineTier.NONE)` called at cinematic start, WHEN `_cleanup()` called from normal dismiss, THEN `OutlinePipeline.restore_prior_tier()` called once. Spy: call count == 1.
*Evidence*: `tests/unit/cutscenes/outline_lifecycle_test.gd` — `test_restore_prior_tier_called_in_cleanup`. *Defended by* CR-CMC-14.

**AC-CMC-6.2** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-5
GIVEN `set_tier(NONE)` called at cinematic start, WHEN `_cleanup()` called via `_exit_tree` abort path (simulated section unload), THEN `restore_prior_tier()` still called once. Spy confirms call count == 1 regardless of exit route.
*Evidence*: `tests/unit/cutscenes/outline_lifecycle_test.gd` — `test_restore_called_on_abort_path`. *Defended by* CR-CMC-14, EC-CMC-F.1.

**AC-CMC-6.3** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-5
GIVEN Mission Closing Card dismissal triggers 24-frame fade-to-black, WHEN `_dismiss()` called on Closing Card, THEN `PostProcessStack.enable_fade_to_black(0.4)` called once (24 × 1/60 = 0.4 s). WHEN fade completes, `disable_fade_to_black()` called once. Spy confirms 1:1.
*Evidence*: `tests/unit/cutscenes/pps_lifecycle_test.gd` — `test_fade_to_black_enable_disable_paired`. *Defended by* CR-CMC-22.

**AC-CMC-6.4** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-5
GIVEN Briefing Card displayed, WHEN `_open_card()` executes, THEN `enable_sepia_dim()` called once. WHEN `_dismiss()` executes, `disable_sepia_dim()` called once. Spy confirms 1:1. `enable_fade_to_black()` NOT called for briefing (briefing exits via hard cut). Sepia-dim and fade-to-black never called simultaneously for the same surface lifecycle.
*Evidence*: `tests/unit/cutscenes/pps_lifecycle_test.gd` — `test_sepia_dim_paired_briefing_card`. *Defended by* CR-CMC-22, C.12.

### H.7 — Audio Integration (CR-CMC-11, CR-CMC-12; AFP-CMC-1..8)

**AC-CMC-7.1** [Integration] [BLOCKING] — BLOCKED-on OQ-CMC-2
GIVEN cinematic CT-03 triggered, WHEN `_start_cinematic(&"ct_03_kitchen_egress")` executes, THEN `Events.cutscene_started` fires with `scene_id == &"ct_03_kitchen_egress"` before any AnimationPlayer track advances. WHEN cinematic ends, `Events.cutscene_ended` fires with same scene_id. Spy: emit counts each == 1, ordered.
*Evidence*: `tests/integration/cutscenes/audio_signal_test.gd` — `test_cutscene_started_ended_emit_ordered`. *Defended by* CR-CMC-11, OQ-CMC-2.

**AC-CMC-7.2** [Integration] [BLOCKING] — BLOCKED-on OQ-CMC-4
GIVEN AudioManager subscribed to `cutscene_started`, WHEN `cutscene_started(&"ct_04_the_rappel")` fires, THEN `_on_cutscene_started` executes and both `MusicDiegetic` + `MusicNonDiegetic` instant-cut to −80 dB within same frame. No crossfade Tween started.
*Evidence*: `tests/integration/cutscenes/audio_signal_test.gd` — `test_cutscene_started_triggers_silence_cut`. *Defended by* CR-CMC-11, AFP-CMC-8.

**AC-CMC-7.3** [Logic] [BLOCKING]
GIVEN cinematic calls `force_alert_state(guard, AlertState.COMBAT, AlertCause.SCRIPTED)`, WHEN `alert_state_changed` propagates to AudioManager's stinger scheduler, THEN scheduler finds `cause == SCRIPTED` and schedules zero `MusicSting` events. Spy: schedule call count == 0.
*Evidence*: `tests/unit/cutscenes/audio_stinger_test.gd` — `test_scripted_cause_suppresses_stinger`. *Defended by* CR-CMC-12, AFP-CMC-1.

**AC-CMC-7.4** [Code-Review] [BLOCKING]
GIVEN `cutscenes_and_mission_cards.gd`, WHEN CI runs `grep -n "force_alert_state"`, THEN every match is followed by `AlertCause.SCRIPTED` as third argument. Any `force_alert_state` call using different cause = BLOCKING defect.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* CR-CMC-12, EC-CMC-E.2.

**AC-CMC-7.5** [Integration] [BLOCKING] — BLOCKED-on OQ-CMC-2 + OQ-CMC-4 — REWRITE per qa-lead + audio-director cross-review 2026-04-28 night
GIVEN CT-05 ends, **WHEN the test emits `Events.cutscene_ended(&"ct_05_bomb_disarm")` and `Events.mission_completed()` within the same synchronous call block (NO `await get_tree().process_frame` between them — both handlers execute in the same `_notification(NOTIFICATION_INTERNAL_PROCESS)` batch)**, THEN: (a) `MISSION_COMPLETE` instant cut takes precedence: `MusicDiegetic.volume_db == -80.0` after both handlers return; (b) **AudioManager's `MISSION_COMPLETE` handler calls `Tween.kill()` on every in-flight Music bus tween before applying the instant cut** — assert via spy on Tween creation/kill counts that no in-flight crossfade tween survives the `MISSION_COMPLETE` transition (per audio.md Concurrency Policy 4, OQ-CMC-4); (c) no crossfade-restore Tween is started after the instant cut.
*Evidence*: `tests/integration/cutscenes/audio_signal_test.gd` — `test_ct05_mission_complete_same_frame_priority_with_tween_kill`. *Defended by* CR-CMC-11, A.1.4, audio.md Concurrency Policy 4 (forward coord).

### H.8 — Localization (CR-CMC-15)

**AC-CMC-8.1** [Logic] [BLOCKING]
GIVEN Briefing Card with `title_key = &"cutscenes.mission_card.briefing.title"` and `body_key = &"cutscenes.mission_card.briefing.body"`, WHEN `_populate_briefing_card(title_key, body_key)` executes, THEN `_briefing_title_label.text == tr(title_key)` AND `_briefing_body_label.text == tr(body_key)`. `_current_title_key` stores StringName key, not translated string.
*Evidence*: `tests/unit/cutscenes/localization_test.gd` — `test_labels_populated_via_tr_at_render`. *Defended by* CR-CMC-15.

**AC-CMC-8.2** [Code-Review] [BLOCKING]
GIVEN `cutscenes_and_mission_cards.gd` + `.tscn`, WHEN CI runs `grep -nE "auto_translate_mode\s*=\s*(ALWAYS|AUTO_TRANSLATE_MODE_ALWAYS)"`, THEN zero matches on card Label nodes. All card Labels must declare `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` per CR-CMC-15 + C.11.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* CR-CMC-15, C.11.

**AC-CMC-8.3** [Logic] [BLOCKING]
GIVEN Briefing Card displayed with title Label visible, WHEN `_notification(NOTIFICATION_TRANSLATION_CHANGED)` fires (locale switch), THEN `_briefing_title_label.text == tr(_current_title_key)` in new locale AND `_briefing_body_label.text == tr(_current_body_key)` — same frame as notification. No card rebuild, no gate reset. If no card visible, handler returns early.
*Evidence*: `tests/unit/cutscenes/localization_test.gd` — `test_notification_translation_changed_rerenders_visible_card`. *Defended by* CR-CMC-15, EC-CMC-D.1.

**AC-CMC-8.4** [Config/Data] [ADVISORY] — BLOCKED-on OQ-CMC-8
GIVEN `translations/cutscenes.csv` exists per OQ-CMC-8, WHEN CI runs key-roster lint counting entries matching `cutscenes.<surface>.<scope>.<beat>` pattern, THEN CSV contains minimum 16 keys (5 briefing + 5 closing + 4 objective × 2 + 1 ct_04 VO + 1 ct_05 caption). Smoke check: all 16 keys present before VS sprint review.
*Evidence*: `tools/ci/check_localization_key_roster.sh` (cutscenes namespace). *Defended by* CR-CMC-15, C.6.

### H.9 — Forbidden Pattern Enforcement (FP-CMC-1..12, TR-6)

**AC-CMC-9.1** [Code-Review] [BLOCKING]
GIVEN DialogueLine `.tres` resources for Cutscenes-triggered MLS beats, WHEN CI runs `grep -rn "speaker.*=.*\"PROTAGONIST\"\|speaker.*=.*&\"PROTAGONIST\"" assets/dialogue/cutscenes/`, THEN zero matches. Any PROTAGONIST speaker in a Cutscenes-triggered beat = BLOCKING defect.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* CR-CMC-20, FP-CMC-1, AFP-CMC-5.

**AC-CMC-9.2** [Code-Review] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night (V.1 contradiction resolved)
GIVEN `translations/cutscenes.csv` AND all `.tscn`/`.gd` files under `src/gameplay/cutscenes/`, WHEN CI runs `grep -irE "MISSION ACCOMPLISHED|OBJECTIVE COMPLETE|^SUCCESS$|MISSION SUCCESS"` across both the CSV and the source/scene files, THEN zero matches. Terminal status for Closing Card is `STATUS: CLOSED` only (per §C.4.2 + TR-6 + V.1 corrected). The grep scope is widened beyond the CSV because hardcoded English strings in `.tscn` Label nodes would not be caught by a CSV-only grep — the V.1 L1088 contradiction is closed by removing `OBJECTIVE COMPLETE` from V.1 entirely (revision 2026-04-28 night) and broadening this AC's grep scope.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh` (extended scope). *Defended by* TR-6, FP-CMC-10, FC-1, V.1 corrected.

**AC-CMC-9.3** [Code-Review] [BLOCKING]
GIVEN `cutscenes_and_mission_cards.gd` + `.tscn`, WHEN CI runs `grep -n "create_timer.*card_open\|AudioStreamPlayer.*sting\|SFX.*card.*sting" src/gameplay/cutscenes/`, THEN zero matches for card-open sting or card-dismiss chime SFX (AFP-CMC-3). Only permitted card-adjacent SFX is `sfx_ui_card_slide_in_01.ogg` UI bus non-musical ≤ 120 ms (A.1.3).
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* AFP-CMC-3.

**AC-CMC-9.4** [Code-Review] [BLOCKING]
GIVEN `CutscenesAndMissionCards.tscn` and CT-03/CT-04 cinematic scene files, WHEN CI runs `grep -n "letterbox.*=.*true\|letterbox_top.*visible.*=.*true" ct_03*.tscn ct_04*.tscn`, THEN zero matches. `letterbox: bool = true` must only appear on `CT_05_BombDisarm` resource.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* CR-CMC-18, FP-CMC-12, FP-V-CMC-9.

**AC-CMC-9.5** [Code-Review] [BLOCKING]
GIVEN `src/gameplay/cutscenes/`, WHEN CI runs `grep -rn "corner_radius\|shadow\|glow\|drop_shadow\|rounded"` on all `.tres` StyleBoxFlat resources and `.tscn` files, THEN zero matches. All card StyleBoxFlat instances must have `corner_radius_*` == 0, zero shadow offset/size, zero glow.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh`. *Defended by* FP-V-CMC-5, FP-V-CMC-6, FP-V-CMC-3.

### H.10 — Performance Budget (F.1, F.2; ADR-0008 Slots 7 + 8)

**AC-CMC-10.1** [Logic] [BLOCKING]
GIVEN Cutscenes in-tree but no card/cinematic active, WHEN `is_processing()` and `is_physics_processing()` queried, THEN both return `false`. Sample `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` over 60 frames: zero additional draw calls vs baseline.
*Evidence*: `tests/unit/cutscenes/performance_test.gd` — `test_zero_steady_state_cost_no_card_active`. *Defended by* F.1, F.2.

**AC-CMC-10.2** [Logic] [BLOCKING] — BLOCKED-on OQ-CMC-3 — REWRITE per systems-designer + performance-analyst cross-review 2026-04-28 night
GIVEN ALL `.gd` and `.tscn` files under `src/gameplay/cutscenes/**` (including `cutscenes_and_mission_cards.gd`, the CT-03/CT-04/CT-05 cinematic subscene scripts, the op-art CanvasLayer 11 scene, and any per-card sub-scenes), WHEN CI runs `grep -rnE "func _process|func _physics_process|set_process\(true\)|set_physics_process\(true\)"` across the full subdirectory tree, THEN zero matches. The widened scope catches child-node `_process` callbacks in cinematic subscenes that would silently inflate the F.1 Slot 7 ceiling beyond 0.20 ms. GUT-testable proxy for 0.00 ms steady-state Slot 8 + bounded Slot 7.
*Evidence*: `tools/ci/check_forbidden_patterns_cutscenes.sh` (widened scope to `src/gameplay/cutscenes/**`). *Defended by* F.1, F.2, ADR-0008 Slot 7 + 8.

**AC-CMC-10.3** [Integration] [ADVISORY]
GIVEN CT-05 cinematic active at Polish (letterbox + AnimationPlayer camera + NPC tracks + 3 closing-card Labels), WHEN profiler captures 60 frames on Iris Xe @ 1080p, THEN peak CPU CanvasLayer processing ≤ 0.20 ms; p95 ≤ 0.20 ms. Lead sign-off required. Non-concurrent with HUD Core peak (HUD hides during CUTSCENE per HUD CR-10).
*Evidence*: `production/qa/evidence/ac-cmc-10-3-ct05-slot7-profile.png` + lead sign-off. *Defended by* F.1, ADR-0008 Slot 7.

**AC-CMC-10.4** [Logic] [ADVISORY]
GIVEN `_try_fire_card()` hot-path executes (4 ops: `dict.has()` + `InputContext.push()` + `create_timer()` + `create_tween()`) in single test frame, WHEN elapsed frame time measured via mock clock, THEN total event-frame cost ≤ 0.011 ms.
*Evidence*: `tests/unit/cutscenes/performance_test.gd` — `test_trigger_evaluation_event_frame_cost`. *Defended by* F.2.

### H.11 — Visual Fidelity (V.1, V.2, V.3)

**AC-CMC-11.1** [Visual] [ADVISORY]
GIVEN live Editor session at 1920×1080 with Mission Briefing Card displayed, WHEN screenshot captured, THEN: full-screen Parchment `#F2E8C8`; BQA Blue `#1B3A6B` header strip 80 px tall flush top; `OPERATION: PARIS AFFAIR` Futura Extra Bold Condensed @ 36 px Ink Black tracking −10 at 148 px from top; American Typewriter Regular @ 18 px body left-aligned 72 px margin; classification stamp rotated −5° bottom-right; zero rounded corners, zero drop shadows, zero glow; HUD hidden. Art-director sign-off.
*Evidence*: `production/qa/evidence/ac-cmc-11-1-briefing-card-1080p.png` + art-director sign-off. *Defended by* V.1, G.4.

**AC-CMC-11.2** [Visual] [ADVISORY]
GIVEN CT-05 letterbox active, WHEN screenshot captured at 1920×1080, THEN: top bar 131 px, bottom 132 px, both `#0A0A0A`; active image 1920×817; concentric circles on sub-CanvasLayer 11 (5–7 rings, alternating cyan `#00B4D8` + Ink Black, 2 px stroke, centered on detonator); zero chromatic aberration, zero bloom, zero filmic tonemap on cards. Art-director sign-off.
*Evidence*: `production/qa/evidence/ac-cmc-11-2-ct05-letterbox-1080p.png` + art-director sign-off. *Defended by* V.3, CR-CMC-18, FP-V-CMC-3, FP-V-CMC-4.

**AC-CMC-11.3** [Visual] [ADVISORY]
GIVEN per-objective opt-in card displayed at 1920×1080, WHEN screenshot captured, THEN: card 720×200 px centered horizontally, bottom edge 120 px from viewport bottom; Parchment fill with Ink Black 1 px border; BQA Blue header 36 px; Futura Extra Bold Condensed 16 px header text; American Typewriter Regular 16 px body; zero shadow / glow / radius; HUD strips below 28 px not occluded.
*Evidence*: `production/qa/evidence/ac-cmc-11-3-objective-card-1080p.png` + art-director sign-off. *Defended by* V.2.

### H.12 — Plaza MVP Smoke Check

**AC-CMC-12.1** [Integration] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night (replace untestable "no warning" with positive assertions)
GIVEN Plaza MVP build (no Cutscenes node — pure VS system absent at MVP), WHEN test calls `watch_signals(Events)` then `Events.mission_started.emit(...)`, THEN: (a) `assert_signal_emit_count(Events, "mission_started", 1)` (signal emitted once); (b) spy on MLS `_on_mission_started` records call count == 1 (MLS handler executed); (c) `InputContext.current() == GAMEPLAY` after handler returns (no CUTSCENE push occurred — the absence-of-Cutscenes-subscriber path is proven by stack state, not by warning absence); (d) `get_tree().get_nodes_in_group("cutscene_canvas_layer")` returns empty array. Godot's signal fire-and-forget semantics mean "no warning" is structurally untestable; positive context/handler assertions replace it.
*Evidence*: `tests/integration/cutscenes/plaza_mvp_smoke_test.gd` — `test_mission_started_no_cutscenes_node_gameplay_proceeds`. *Defended by* CR-CMC-1, MLS CR-13.

**AC-CMC-12.2** [Integration] [BLOCKING] — REWRITE per qa-lead cross-review 2026-04-28 night
GIVEN Plaza MVP build (no Cutscenes node), WHEN `Events.section_entered.emit(plaza_id, FORWARD)`, THEN: (a) no CT-03/CT-04/CT-05 PackedScene resources are loaded (assert via static-analysis grep on `preload(ct_0?_*)` returning zero matches AND runtime check that `ResourceLoader.has_cached(ct_03_path) == false`); (b) `InputContext.current() == GAMEPLAY`, `InputContext.stack.size() == 1`; (c) `get_tree().get_nodes_in_group("cutscene_canvas_layer").is_empty() == true`. Replaces "no warning" with positive scene-graph + InputContext-state assertions.
*Evidence*: `tests/integration/cutscenes/plaza_mvp_smoke_test.gd` — `test_section_entered_no_cutscenes_node_clean_state`. *Defended by* CR-CMC-1, ADR-0007.

**AC-CMC-12.3** [Integration] [BLOCKING] — BLOCKED-on OQ-CMC-6
GIVEN VS build with Cutscenes in tree and save file containing `triggers_fired = [&"mc_briefing_paris_affair"]`, WHEN save loaded and `section_entered(_, LOAD_FROM_SAVE)` fires, THEN CR-CMC-4 unconditionally suppresses — no card fires, CUTSCENE not pushed, zero CanvasLayer created. Subsequently, `Events.mission_started` via FORWARD: CR-CMC-2 reads triggers_fired and suppresses briefing card. Player gets gameplay without card repeat.
*Evidence*: `tests/integration/cutscenes/replay_suppression_test.gd` — `test_end_to_end_save_load_suppression`. *Defended by* CR-CMC-2, CR-CMC-4, CR-CMC-21.

### H.13a — Section-Lifecycle Discipline (CR-CMC-16, CR-CMC-19)

**AC-CMC-16.1** [Integration] [BLOCKING] — NEW per qa-lead cross-review 2026-04-28 night (closes CR-CMC-16 coverage gap)
GIVEN Cutscenes CanvasLayer parented to a section root node and instantiated via MLS section authoring, WHEN `Events.section_exited(section_id)` fires and the section root calls `queue_free()`, THEN: (a) one frame later, `is_instance_valid(canvas_layer_ref) == false` (CanvasLayer is freed by parent teardown); (b) `get_tree().get_nodes_in_group("cutscene_canvas_layer").is_empty() == true`; (c) `_exit_tree()` ran (`_cleanup()` was called — assert via spy that `InputContext.pop()` was called if `_context_pushed` was true at teardown time). Tests both happy-path (no card active at unload) and worst-path (card mid-display at unload — `_cleanup()` must pop CUTSCENE before `_exit_tree` returns).
*Evidence*: `tests/integration/cutscenes/section_lifecycle_test.gd` — `test_canvas_layer_freed_on_section_exit_happy_and_worst_path`. *Defended by* CR-CMC-16, EC-CMC-G.1, EC-CMC-C.3.

**AC-CMC-19.1** [Logic] [BLOCKING] — NEW per qa-lead cross-review 2026-04-28 night (closes CR-CMC-19 hard-cut entry coverage gap)
GIVEN `_open_card(scene_id, CardType.MISSION_BRIEFING)` or `_open_card(_, CardType.MISSION_CLOSING)` is called, WHEN execution completes through to the visible card state, THEN spy on `create_tween()` records **zero** tween creations on the Mission Card's appear path (hard-cut entry per CR-CMC-19; Saul Bass grammar). Tween IS used legitimately for Per-Objective Card slide-in (8-frame paper-translate) and CT-05 letterbox slide-in (12-frame) — those paths must not trigger this AC. Test isolates the Mission Briefing/Closing path by spy scope-filtering on `_open_card(_, MISSION_BRIEFING)` / `(_, MISSION_CLOSING)` only.
*Evidence*: `tests/unit/cutscenes/hard_cut_entry_test.gd` — `test_mission_card_appear_creates_no_tween`. *Defended by* CR-CMC-19, FP-CMC-3.

### H.13 — Budget Verification

**AC-CMC-BUDGET-1** [Config/Data] [BLOCKING]
GIVEN the authored content roster (2 mission cards + 2 objective cards + 3 cinematics) and the per-surface duration caps in F.5, WHEN total non-gameplay surface time is computed at authoring time (sum of cap durations), THEN total ≤ 108 s (1.5% of 2-hour session). Worst-case roster sums to ≤ 94 s = 1.3% — passes by 14 s margin.
*Evidence*: `tools/ci/check_cutscene_budget.sh` (CSV roster sum vs cap). *Defended by* F.5, AC-CMC-BUDGET.

### H.GAP — Playtest-Verdict Items (Non-Automatable)

Design-quality criteria evaluable only via structured playtest or lead review. None BLOCKING for CI; all ADVISORY before VS sprint review sign-off.

**GAP-1 — The Bass Test** [Visual] [ADVISORY]
GIVEN playtest of full VS build with all 7 authored beats, WHEN art-director + creative-director review each surface against the tonal-anchor question ("Would Saul Bass sign their name?"), THEN lead sign-off granted per surface. Failing surfaces re-authored before VS sprint review.
*Evidence*: `production/qa/evidence/ac-cmc-gap1-bass-test-signoff.md` + creative-director + art-director sign-off.

**GAP-2 — 1965 Period Register** [Visual] [ADVISORY]
GIVEN all authored card copy (16+ `cutscenes.*` keys) and cinematic visual direction, WHEN narrative-director reviews against TR-1..TR-10 and the "could this appear in *Our Man Flint* or a 1965 Air-France poster?" test, THEN no TR violation; BQA-register voice confirmed. Written verdict in evidence file.
*Evidence*: `production/qa/evidence/ac-cmc-gap2-1965-register-review.md` + narrative-director sign-off.

**GAP-3 — Cinema-Knows-It's-Cinema** [UI] [ADVISORY]
GIVEN first-time player (zero prior exposure) watching CT-05 + dismiss-gate expiry on Closing Card, WHEN observed during structured playtest, THEN: player does not attempt to skip CT-05 first-watch; reads `STATUS: CLOSED` + `REF: IT-65-002` lines before dismissing; ≥ 2 of 3 playtesters verbally acknowledge Rome seed without prompt.
*Evidence*: `production/qa/evidence/ac-cmc-gap3-cinema-knows-playtest.md`.

**GAP-4 — Cliffhanger Lands Without Explanation** [UI] [ADVISORY]
GIVEN Mission Closing Card displayed at game end, WHEN `REF: IT-65-002 ROUTED TO SECTION 6. ROME STATION ADVISED.` line visible, THEN QA lead confirms (a) no tooltip, no hover annotation, no UI affordance draws attention; (b) line not glossed by in-game narration; (c) 5.0 s dismiss-gate sufficient for reading-speed-calibrated player. If hold fails reading-speed test, `cutscenes_dismiss_gate_closing_s` adjusted within [4.0, 8.0].
*Evidence*: `production/qa/evidence/ac-cmc-gap4-cliffhanger-reading-time.md` + QA lead sign-off. *Defended by* C.7, G.1.

---

**§H total: 51 ACs** (43 BLOCKING + 8 ADVISORY across Logic / Integration / Code-Review / Config / Visual / UI). 2026-04-28 night cross-review revision: 10 ACs rewritten (1.4 / 2.4 / 3.5 / 4.4 + 4.4b / 5.2 / 7.5 / 9.2 / 10.2 / 12.1 / 12.2) + 2 new ACs added (16.1 CanvasLayer free-on-section-unload, 19.1 hard-cut entry no-Tween). Story type classification per AC follows the table in `coding-standards.md`. All BLOCKED-on tags reference OQ-CMC-N coord items in §F.5.1; no BLOCKED AC may be marked Complete until its coord item closes.

## Open Questions

This section consolidates every open coordination item that emerged during §A–§H authoring. **10 BLOCKING for VS sprint kickoff** (must close before Cutscenes implementation begins) + **6 ADVISORY** (defer to Polish or VS2). 4 user decisions adjudicated 2026-04-28 night are recorded inline as RESOLVED.

### OQ.1 — BLOCKING for VS sprint kickoff (14)
*(Grew from 10 to 14 per 2026-04-28 night cross-review: OQ-CMC-11 promoted from Polish-spike; new OQ-CMC-17 [Settings carve-out], OQ-CMC-18 [D&S Category 8], OQ-CMC-19 [HUD ordering + Godot 4.6 verification].)*

| # | Coord item | Owner | Source |
|---|---|---|---|
| **OQ-CMC-1** | **ADR-0004 Amendment A7**: add `Context.CUTSCENE` to `InputContext.Context` enum + push/pop authority table entry assigning `CutscenesAndMissionCards` as sole pusher/popper | TD + Lead Programmer | CR-CMC-5, ADR-0004 L270, AC-CMC-2.1/2.2/2.3, AC-CMC-5.1/5.4 |
| **OQ-CMC-2** | **ADR-0002 amendment**: add Cutscenes domain section with `signal cutscene_started(scene_id: StringName)` + `signal cutscene_ended(scene_id: StringName)`; signal count grows 41 → 43 | Signal Bus owner (TD) | CR-CMC-11, audio.md L407, AC-CMC-7.1 |
| **OQ-CMC-3** | **ADR-0008 amendment**: register Slot 7 Cutscenes sub-claim 0.00–0.20 ms peak event-frame + Slot 8 trigger-evaluation absorbed in residual margin (per F.6 amendment language in §D) | Performance Analyst + TD | F.1, F.2, F.6, AC-CMC-10.2 |
| **OQ-CMC-4** | **Audio §F amendment**: subscribe to NEW `cutscene_started`/`_ended` signals; document `CUTSCENE` row in Music bus state table per §States; verify Crossfade Rule 6 silence-cut covers cutscene track swap from `cutscene_started` payload; add 5 new tuning knobs (`cutscene_track_dict` / `cutscene_restore_crossfade_s` / `cutscene_ct05_postdisarm_hold_s` / `cutscene_ct05_hammond_fade_out_s` / `cutscene_card_slide_sfx_db`); same-frame priority guard for CT-05 + `mission_completed` override | Audio Director | A.6.1, A.6.2, A.6.3, AC-CMC-7.2/7.5 |
| **OQ-CMC-5** | **PPS GDD amendment**: add `enable_fade_to_black(duration_s)` / `disable_fade_to_black(duration_s)` API pair; document Cutscenes as valid caller of outline-tier escape-hatch (`set_tier(NONE)` + `restore_prior_tier()`); add `set_tier()` idempotency forward contract per EC-CMC-F.2 | PPS GDD owner | CR-CMC-22, CR-CMC-14, EC-F.2, AC-CMC-6.1..6.4 |
| **OQ-CMC-6** | **MLS GDD §C.4 amendment**: add `MissionObjective.show_card_on_activate: bool = false` field; add per-section cutscene + card trigger roster (CT-03 / CT-04 / CT-05 + briefing + closing + 2 objective cards + VS2-reserved) for section-validation pipeline; add MLS-emitted `cutscene_started`/`_ended` from cinematic completion callbacks; add MLS section-load null-guard on Cutscenes `PackedScene.instantiate()` per EC-CMC-G.4; add `MissionLevelScripting.get_mission_state()` public read-only accessor | MLS GDD owner + Tools-Programmer | C.4, EC-CMC-G.4, CR-CMC-2, AC-CMC-12.3 |
| **OQ-CMC-7** | **LSS GDD edits**: (a) **L204 touch-up** — correct RESPAWN branch description from "checks `triggers_fired`" to "suppresses unconditionally" (aligns CR-CMC-4); (b) section-teardown defensive `OutlinePipeline.restore_prior_tier()` + `assert(not InputContext.is_active(CUTSCENE))` per EC-CMC-C.7 / EC-CMC-F.1; (c) section-load validation: assert Cutscenes node presence in each VS-target section per EC-CMC-G.3 | LSS GDD owner | EC-C.7, EC-G.3, F.1, AC-CMC-1.2 |
| **OQ-CMC-8** | **Localization Scaffold authoring contract**: register `cutscenes.csv` table + 16-key minimum roster (5 briefing + 5 closing + 4 × 2 objective cards + 1 ct_04 VO + 1 ct_05 caption); confirm `NOTIFICATION_TRANSLATION_CHANGED` live-resolve as documented consumer guarantee (ADVISORY touch-up of L132 + L186) | Localization Lead + Writer | C.6, EC-D.1, AC-CMC-8.4 |
| **OQ-CMC-9** | **Input GDD action catalog**: add `cutscene_dismiss` action (default Esc / B); add `CUTSCENE` to InputContext blocked-actions table | Input GDD owner | CR-CMC-5, C.2.4, AC-CMC-4.1/4.2/4.5 |
| **OQ-CMC-10** | **Writer Brief authoring** at `design/narrative/cutscenes-writer-brief.md`: mirror `document-writer-brief.md` + `dialogue-writer-brief.md` structure — 4 surface-type voice rules + 7-card roster + Saul Bass typographic register guide + Rome cliffhanger seed authoring guidance + classification stamp lexicon (CLASSIFIED / MISSION CLOSED / STATUS: CLOSED) + 12-word card body cap + tonal-anchor question reuse from §B "Would Saul Bass sign their name?" | Writer + Narrative Director | C.4, C.5, C.7, GAP-2 |

### OQ.2 — ADVISORY (defer to Polish or VS2) (5)

| # | Coord item | Owner | Source |
|---|---|---|---|
| ~~OQ-CMC-11~~ | **PROMOTED to BLOCKING (OQ.1)** per CD cross-review 2026-04-28 night — see OQ-CMC-11 in OQ.1 above | (moved) | (moved) |
| **OQ-CMC-12** | **VS2 authoring decision**: if CT-04 + CT-05 are authored as a contiguous beat-chain, MLS emits `cutscene_sequence_started`/`_ended` rather than per-cinematic signals to avoid 1–2 frame outline flash between (EC-CMC-F.3) | MLS GDD owner | EC-F.3 |
| **OQ-CMC-13** | **Tools-Programmer authoring lint**: flag `show_card_on_activate = true` on objectives whose activation also triggers a cinematic (EC-CMC-H.1) | Tools-Programmer | EC-H.1 |
| **OQ-CMC-14** | **OutlinePipeline `set_tier()` idempotency forward contract** verification (EC-CMC-F.2) | Outline Pipeline GDD owner | EC-F.2 |
| **OQ-CMC-15** | **Polish: 3rd-person cinematic camera rig + character cinematic animation pipeline** (deferred per §A — "the GDD specs trigger contract + skip lifecycle + asset slots, not camera rig"). At MVP/VS, CT-05 may fire as black-screen hold with audio + Mission Closing Card transition only — camera rig snaps in at Polish without breaking trigger/skip/InputContext contract | Animation + Tools-Programmer | §A |
| **OQ-CMC-16** | **Polish: case-file post-credits flashback / cutscene-replay-from-Pause-Menu** (deferred; `MissionState.triggers_fired` is one-shot at MVP/VS) | Menu System owner + Cutscenes | §A |

### OQ.3 — RESOLVED (user decisions adjudicated 2026-04-28 night)

- **Q1 — CT-05 letterbox**: **Letterboxed 2.35:1, reserved exclusively for CT-05** (CR-CMC-18 + FP-V-CMC-9). User confirmed Recommended. CT-03 / CT-04 stay full-frame.
- **Q2 — Per-objective opt-in card count**: **2 cards locked** (Telephone `find_bomb_device` + Radio Cipher `intercept_cipher`) **+ 1 VS2 reserved** Upper Structure slot. User confirmed Recommended.
- **Q3 — Skip-grammar policy on first-watch**: **NO mid-cinematic skip on first-watch** (CR-CMC-2.2 + Pillar 5 absolute). Cards have 4.0/5.0/3.0 s dismiss-gate; cinematics watched in full. User confirmed Recommended.
- **Q4 — Fade-to-black API**: **Separate `enable_fade_to_black()` / `disable_fade_to_black()` PPS API** (CR-CMC-22). Sepia-dim NOT repurposed. User confirmed Recommended; PPS amendment via OQ-CMC-5.

### OQ.4 — Verification Gates (engine-knowledge-gap items, 2026-04-28 night solo-mode unresolved)

| Gate | Risk | Required action |
|---|---|---|
| **VG-CMC-1 [BLOCKING]** | CanvasLayer 10 simultaneous-instance behavior in Godot 4.6 | Editor verification: instantiate Cutscenes + Settings stub at layer 10 simultaneously; confirm later-added child renders on top with no z-fighting; document failure mode for `_unhandled_input` discipline |
| **VG-CMC-2 [BLOCKING]** | `_unhandled_input` + `cutscene_dismiss` during letterbox + AnimationPlayer | Editor verification: open CT-05 stub; confirm input event flow during letterbox-active state; closes ADR-0004 Gate 3 (modal dismiss via `_unhandled_input` on KB/M + gamepad given Godot 4.6 dual-focus split) |
| **VG-CMC-3 [BLOCKING]** | `Tween` + `AnimationPlayer` parallel orchestration | Editor verification: animate letterbox `ColorRect.size` Tween while AnimationPlayer runs camera/NPC tracks; confirm clean composition (Godot 4.6 `Tween` is tree-bound + independent of `AnimationPlayer` per docs, but not yet measured on actual cinematic stub) |
| **VG-CMC-4 [BLOCKING]** | `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` + `NOTIFICATION_TRANSLATION_CHANGED` re-resolve | Editor verification: change locale mid-card-display via Settings; confirm title + body Labels update correctly without double-resolution artifacts; closes Cutscenes-side of ADR-0004 Gate 4 (`AUTO_TRANSLATE_MODE_*` constants in Godot 4.5+) |
| **VG-CMC-5 [ADVISORY]** | `SceneTree.create_timer(duration, true)` dismiss-gate behavior with `InputContext.CUTSCENE` active | Editor verification: confirm timer fires on main thread regardless of any future `SceneTree.paused = true`; document `process_always = true` argument as defensive invariant |

### OQ.5 — Items deliberately omitted from this GDD

| Item | Rationale |
|---|---|
| 3rd-person cinematic camera rig + character cinematic animation pipeline | OQ-CMC-15 — Polish-deferred; GDD specs trigger contract + skip lifecycle + asset slots, not rig internals |
| Tier 2 Rome / Vatican mission cinematics | game-concept.md §Scope Tiers — post-launch only |
| Case-file post-credits flashback / cutscene-replay-from-Pause-Menu | OQ-CMC-16 — Polish-deferred; `MissionState.triggers_fired` is one-shot at MVP/VS |
| Cutscene-skip-by-default Settings toggle | settings-accessibility.md L1346 — explicitly out of scope; Cutscenes owns own skip behavior |
| Mid-cinematic skip on first-watch | CR-CMC-2.2 + Pillar 5 absolute — never |
| Mission-card replay from Pause Menu | Polish-deferred; analogous to case-file archive |
| Save state for Cutscenes (separate from MLS `MissionState.triggers_fired`) | CR-CMC-2 + CR-CMC-21 — proxy via `MissionState.triggers_fired`; no Cutscenes-owned save state |
| Multiplayer cinematic synchronisation | Single-player game per game-concept.md; no network-domain signals |
| Mission Cards on `objective_completed` (per-objective completion cards) | Per TR-6 + narrative-director: completion is HUD State Signaling's surface, not Cutscenes; only on-activate (`objective_started` + `show_card_on_activate=true`) is in scope |
| Music swell at any narrative beat | Pillar 1 absolute (FP-CMC-5 + AFP-CMC-2 + FC-5) — never |
| Eve VO during any Cutscenes-owned surface | Pillar 1 absolute (CR-CMC-20 + FP-CMC-1 + AFP-CMC-5 + FC-1) — never |
| Per-objective card on the same beat as a cinematic trigger | LD authoring discipline rule (FP-CMC-7 + EC-CMC-H.1); authoring lint per OQ-CMC-13 |
