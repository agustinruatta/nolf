# HUD State Signaling

> **Status**: In Design
> **Author**: solo (user + skill orchestration)
> **Last Updated**: 2026-04-28
> **Implements Pillar**: Primary 5 (Period Authenticity Over Modernization) + Primary 3 (Stealth is Theatre, Not Punishment) + Supporting 1 (Comedy Without Punchlines) + Supporting 2 (Discovery Rewards Patience)
> **Phasing**: Single GDD with per-section [MVP-Day-1] / [VS] tags. **MVP-Day-1 minimal slice** = HoH/deaf alert-state cue only (HUD Core HARD MVP DEP per REV-2026-04-26 D3). **VS scope** = MEMO_NOTIFICATION + alarm-state stinger + respawn "house lights up" beat + critical-health clock-tick visual + save-failed warning + the rest of the prompt-strip resolver extensions.
> **REV-2026-04-28 (post-design-review)**: Major revision applied per `/design-review` adversarial findings (7 specialists + creative-director synthesis). Key changes: (a) ALARM_STINGER carved out of "Margin Note" fantasy as designated exception — duration 5.0→3.0 s, AccessKit promoted to assertive, priority promoted to 1 (preempts INTERACT_PROMPT for its 3.0 s window); (b) ALERT_CUE Settings toggle promoted to BLOCKING Day-1 (default ON for HoH compliance, opt-out for hearing players — closes Pillar 5 §Visual Identity Anchor contradiction); (c) WCAG 2.2.1 timing-adjustable mechanism promoted to BLOCKING Day-1 (OQ-HSS-6); (d) WCAG 2.2.2 critical-pulse opt-out promoted to BLOCKING VS (OQ-HSS-10); (e) Queue arithmetic fixed (`queued_state_max_age_s` 1.0→5.0); (f) CR-9 rate-gate exempts upward-severity transitions (SC 1.1.1/1.3.3 closure); (g) Godot 4.6 API correctness: CR-18 Tween rewritten via `tween_method` + `add_theme_color_override`; (h) Anti-pillar coverage extended (FP-HSS-12/13/14 added); (i) F.4/CR-14 perf budget corrections (11 µs not 9 µs over-cap; CR-18 pulse adds steady-state cost; deferred-AccessKit promoted to default mitigation). The premature "EU GAAD compliant" claim is dropped pending Gate 1 closure + WCAG 2.2.1/2.2.2 implementation.

## Overview

HUD State Signaling (HSS) is *The Paris Affair*'s **transient HUD state layer** — the system that surfaces brief, period-typographic messages on the existing HUD Core surface when the game state shifts in ways the player must notice but Pillar 5 forbids from being shown as floating icons, alert meters, or modern UX notifications. As a **data layer** it is a per-section node tree (`HUDStateSignaling extends Node`, NOT autoload per ADR-0007) hosted under HUD Core's CanvasLayer 1; it subscribes to **5 frozen signals across 4 domains** of the `Events` autoload (`alert_state_changed` from Stealth AI, `document_collected` from Document Collection, `respawn_triggered` from Failure & Respawn, `player_health_changed` from Player Character, `save_failed` from Save/Load — VS only) and writes their effects through HUD Core's published extension API (`HUDCore.get_prompt_label() -> Label`, the single forward extension point declared in HUD Core UI-3). It **emits zero signals** (subscriber-only per ADR-0002, mirroring HUD Core CR-19 sole-publisher discipline). As a **player-facing surface** it is the **brief moment of acknowledgment** — the HUD has just registered that something changed (a guard saw you, a document went into the pocket, you were just respawned, your auto-save couldn't be written) — rendered as a single text line in the same prompt-strip slot HUD Core uses for interact prompts, in the same period typographic register (BQA Blue strip + Parchment text per Art Bible 7D, FontRegistry per ADR-0004), with auto-dismiss after a short window (~2 s alert-cue, ~3 s pickup toast, ~1.5 s respawn beat). All visible strings flow through `tr()` (Localization Scaffold). HSS operates strictly within the **0.3 ms ADR-0008 Slot 7 cap shared with HUD Core** — it claims ≤0.05 ms steady-state and ≤0.15 ms peak (state-transition frame). HSS Tweens are killed on `ui_context_changed != GAMEPLAY` per HUD Core CR-22 (added 2026-04-28). Phasing is bifurcated: **MVP-Day-1 minimal slice** (a HARD upstream dep for HUD Core MVP per HUD Core REV-2026-04-26 D3) covers a single state — the **HoH/deaf alert-state cue** (`tr("HUD_GUARD_ALERTED")`, ~2 s auto-dismiss, fired on `alert_state_changed` entry to non-UNAWARE or upward-severity escalation per CR-9 REV-2026-04-28) for WCAG 1.1.1 / 1.3.3 compliance (the previous "EU GAAD compliance" claim is downgraded to "EU GAAD compliance posture" pending ADR-0004 Gate 1 closure + WCAG 2.2.1 timing-adjustable mechanism + WCAG 2.2.2 critical-pulse opt-out implementation per accessibility-specialist Findings 2/3/5). **VS scope** adds MEMO_NOTIFICATION (document pickup toast: `tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)`, ~3 s), the alarm-state stinger (a single-Label line in the same prompt-strip slot — `tr("HUD_ALARM_RAISED")`, ~5 s — fired once on section-wide alarm onset, NOT a per-guard-alert flash; "stinger" quality comes from longer auto-dismiss + paired Audio sting, NOT from a separate banner widget per CR-16), the respawn "house lights up" beat (a single `tr("HUD_RESPAWN")` line, ~1.5 s, fired once on `respawn_triggered`), the critical-health clock-tick visual (a parchment-tone text pulse synced to Audio's clock-tick — pure visual layer paired with Audio's CR-owned tick), and a "Save Failed" advisory line on `save_failed` IO_ERROR (per F&R OQ-FR-4 ADVISORY resolution).

**Pillar fit**: Primary 5 (Period Authenticity Over Modernization) is load-bearing — every visible HSS surface is a single text line in NOLF1 typographic register, never an icon, meter, banner-with-graphics, or modern toast component; the HoH alert-cue is the sole accommodation that surfaces alert-state at all (game-concept §Visual Identity Anchor: "alert state changes signaled through music and audio, NOT through lighting or color shifts" — HSS's text-only cue is the explicit accessibility carve-out, not a violation). Primary 3 (Stealth is Theatre, Not Punishment) is served by the alarm-stinger and respawn-beat — both are theatrical scene-changes ("the lights came on", "the house lights are up"), not failure messaging. Supporting 1 (Comedy Without Punchlines) is served typographically — pickup toasts read as bureaucratic file stamps ("DOCUMENT FILED: 'Memo Re: Tower Sanitation'"), never as game-y "+1 collected" toasts. Supporting 2 (Discovery Rewards Patience) is served by MEMO_NOTIFICATION giving the patient observer a small typographic acknowledgment of their find without breaking flow.

**This GDD defines**: the HSS extension contract against HUD Core's `get_prompt_label()`, the priority resolver extension that adds 5 new states (ALERT_CUE, MEMO_NOTIFICATION, ALARM_STINGER, RESPAWN_BEAT, SAVE_FAILED) to HUD Core's existing 2-state machine (HIDDEN, INTERACT_PROMPT), the auto-dismiss timer pattern (per-state Timer node, NOT `_process` polling), the AccessKit `accessibility_live` rate-gating contract, and the explicit forbidden surfaces (no above-head guard icon, no minimap, no objective marker, no kill cam, no XP toast, no achievement toast, no quest-update banner). **This GDD does NOT define**: the HUD Core widget grammar or anchors (HUD Core §C.2 owns); the photosensitivity rate-gate (HUD Core §C.4 owns — HSS may NOT bypass); the actual SFX paired with HSS visual cues (Audio GDD owns: pickup chime, alarm stinger sting, clock-tick pulse, save-failed advisory cue); the `Document` Resource schema or pickup lifecycle (DC owns); the alert-state machine (Stealth AI owns); the respawn flow timing (F&R owns); the dialogue subtitle layer (Dialogue & Subtitles GDD #18, Designed 2026-04-28 — separate Label on CanvasLayer 2 LOCKED per dialogue-subtitles `subtitle_canvas_layer`); the cutscene letterbox or mission-card (Cutscenes & Mission Cards GDD #22 owns).

## Player Fantasy

**"The Margin Note."** A line of text appears briefly in the margin of Eve Sterling's vision — a typed annotation stamped by an unseen file clerk, acknowledging what just happened, then yielding back to the action. The player never reads it deliberately; they catch it in passing, the way you catch a librarian's pencil mark on the edge of a page. Eve doesn't pause for it. The clerk has filed the moment for the record; the operation continues. The fantasy is **the bureaucracy keeping pace with the agent** — every meaningful event in the field is being annotated, in real time, by a hand at BQA Registry that Eve will never see and the player will never speak to.

The framing is deliberately quieter than the modern toast component it replaces. A modern game would surface a guard's alert as a flashing icon above the guard's head; a quest-update banner; a "+1 Document" floater. *The Paris Affair* stamps a margin note. The note is brief, typographic, period-appropriate, and gone. The clerk acknowledges; the world resumes.

**Posture anchored**: peripheral, ambient, sub-second. The player's attention stays on the world; the margin note registers without interrupting. HSS will never demand acknowledgment, never block input, never sustain past its auto-dismiss window, never replay if missed.

**Register**: bureaucratic-deadpan (Pillar 1 supporting). The clerk's annotation, not the game's announcement. "DOCUMENT FILED — 'Memo Re: Tower Sanitation'" reads as a stamp, not a reward. "ALARM RAISED" reads as a noted event, not a fail-state. "SAVE FAILED — ARCHIVAL ERROR" reads as the clerk apologizing for paperwork trouble, not as a system error dialog.

**Coherence with neighboring framings**:
- **The Glance** (HUD Core) is the cockpit dial Eve reads on demand. **The Margin Note** is the annotation that arrives unbidden and recedes. Different verbs (read vs. catch), same universe.
- **The Lectern Pause** (Document Overlay UI) is a deliberate full-stop. **The Margin Note** is the opposite — the briefest possible touch on the player's vision.
- **The Case File** (Menu System) puts the player *as* BQA officer reading the file. **The Margin Note** keeps the player *as* Eve in the field while an unseen clerk stamps the margin. Different POV, same BQA universe — no POV split because the player is never asked to *be* the clerk.
- **The Stage Manager** (Settings) is the between-scenes carve-out. **The Margin Note** is in-scene, so they never co-occur (Settings is `InputContext.SETTINGS`; HSS only fires while `InputContext == GAMEPLAY`).

**The HoH/deaf alert-cue is The Margin Note made slightly more visible.** The HoH accommodation isn't an exception to the fantasy — it's the clerk noting in the margin what was previously only audible. That framing sells the carve-out as a natural extension of the established BQA bureaucracy: the music told you a guard saw you; the margin note now also stamps it for the file. Same clerk, same register, same auto-dismiss.

**5 explicit refusals** (what the Margin Note is NOT):

1. **Not a notification.** Notifications demand acknowledgment, persist until dismissed, animate in attention-grabbing ways. The Margin Note auto-dismisses; the player who missed it has missed nothing critical (every HSS surface is paired with an authoritative non-HSS channel — alert music for ALERT_CUE, the inventory state for MEMO_NOTIFICATION, the actual respawn for RESPAWN_BEAT).
2. **Not a banner.** Banners take width, weight, color, sometimes animation. The Margin Note is a single line of text on the existing prompt-strip slot — no graphics, no icons, no progress bars, no decoration.
3. **Not a reward.** No "+1", no count-up, no celebration. "DOCUMENT FILED" is bureaucratic acknowledgment, not gamified reinforcement. The patient observer's reward is the document's content (read in the Lectern Pause), not the toast.
4. **Not a fail-state.** "SAVE FAILED" is advisory — the operation continues, the player can keep playing, the next save attempt may succeed. No red, no skull icon, no modal blocking. ALARM_STINGER is theatrical ("the curtain went up"), not punitive ("you failed stealth").
5. **Not a debugger.** No timestamps, no internal IDs, no system-level diagnostics shown to the player. The clerk speaks in human period-register: "ARCHIVAL ERROR — RETRY", not "ERR_FILE_WRITE_FAILED at line 247".

**Tonal anchor question**: *"Does this read as a margin note, or as a notification?"* Every future HSS state added (or added by another team member) must answer this question correctly before it ships. The 5 explicit refusals above plus the FP-HSS-1..14 forbidden-pattern panel are the **rubric** for that question — a contributor adding a new state must demonstrate that the proposed state passes all 5 refusals AND does not surface any pattern in FP-HSS-10..14 (no objective UI, no XP, no faction-state, no stealth-rank, no NPC-ID toasts). If a proposed state demands acknowledgment, sustains past a few seconds, decorates with graphics, or reads as gamified feedback — it's a notification, and it fails the fantasy.

**Designated exceptions to the Margin Note (REV-2026-04-28)**: The Margin Note governs **3 of 5 HSS states** (ALERT_CUE, MEMO_NOTIFICATION, RESPAWN_BEAT). **ALARM_STINGER and the CR-18 critical-health pulse are explicit carve-outs** because they signal *failure-state events* (failure-of-stealth section-wide alarm; failure-of-survival imminent death) where safety-of-information for HoH/deaf/blind players overrides the "never demand attention" discipline. This carve-out is itself anchored to a project precedent: the Settings panel's non-diegetic carve-out from Pillar 5 (Period Authenticity) — the diegetic frame breaks where accessibility/safety demands it. Consequences of the carve-out:
- ALARM_STINGER uses assertive AccessKit (CR-8) — the ONLY state with this treatment.
- ALARM_STINGER is priority 1 above INTERACT_PROMPT during its 3.0 s window (CR-6) — preempts even action-blocking UI for HoH equity.
- CR-18 critical-health pulse is continuous, not transient — but is opt-out via `accessibility.hud_critical_pulse_enabled` (Settings; default ON; BLOCKING VS dep).

Future contributors **must not** extend the carve-out to additional states without creative-director sign-off + accessibility-specialist review. The carve-out is narrow: it covers section-wide failure-state signals only. ALERT_CUE remains a Margin Note (alert music is the authoritative channel; the visual cue is a HoH-only annotation).

**References**: NOLF1's HUD message style ("DOCUMENTS: 1 OF 5" — the bureaucratic count, not "+1" toast), Get Smart's deadpan inter-scene title cards, the marginalia of period file-clerks (pencil annotations on dossiers, "noted" stamps), Saul Bass title-sequence card-typography aesthetic translated to in-game register.

**Pillars served**:
- **Primary 5** (Period Authenticity Over Modernization) — load-bearing. The text-only typographic register, the period BQA Blue + Parchment palette, the auto-dismiss without persistent UI element, the explicit refusal of modern toast components — all descend from the 1965 spy-comedy fiction. The HoH carve-out is the only visible alert-state surface in the entire HUD ecosystem (game-concept §Visual Identity Anchor pillar) and it preserves period authenticity by being a typed clerical annotation, not an above-head icon.
- **Primary 3** (Stealth is Theatre, Not Punishment) — the alarm-stinger ("ALARM RAISED"), respawn-beat ("OPERATION RESUMED"), and save-failed advisory ("ARCHIVAL ERROR — RETRY") all read as theatrical scene-changes / clerical apologies, never as failure messaging. The respawn-beat in particular is the visual echo of F&R's "Eve does not die well" framing — a clerk's brief note that the operation is resuming, not a "You Died" screen.
- **Supporting 1** (Comedy Without Punchlines) — pickup toasts read as bureaucratic file stamps with period clerical voice ("DOCUMENT FILED: 'Memo Re: Tower Sanitation'"). The comedy is in the typography and the bureaucratic deadpan, never in the message itself shouting at the player.
- **Supporting 2** (Discovery Rewards Patience) — MEMO_NOTIFICATION gives the patient observer a brief typographic acknowledgment of their find. The acknowledgment is small (one line, one auto-dismiss) precisely *because* the document's content (read in the Lectern Pause) is the actual reward. HSS does not reward; it acknowledges.

**Design test**: *if a future HSS surface ever feels like it's interrupting the player to deliver information — we've failed the fantasy.* The clerk annotates; the player keeps playing.

## Detailed Rules

### C.1 Core Rules

**[MVP-Day-1] CR-1 — Subscriber-only discipline.** HSS emits **zero** signals on the ADR-0002 Signal Bus at MVP and VS. It is a consumer-only system: subscribes to `Events.alert_state_changed` (Day-1), and at VS adds `Events.document_collected`, `Events.respawn_triggered`, `Events.player_health_changed`, and `Events.save_failed`. If a future feature requires HSS to publish a signal, that is an ADR-0002 amendment requiring lead-programmer review. (Justification: mirrors HUD Core CR-19 sole-publisher discipline; the Margin Note never speaks back.)

**[MVP-Day-1] CR-2 — Per-section node, NOT autoload.** `class_name HUDStateSignaling extends Node`. Instantiated as a child of HUD Core's `CanvasLayer` (canonical path `Section/Systems/HUDStateSignaling`, mirroring DC's `Section/Systems/DocumentCollection` per DC CR-14). Lifetime = section lifetime; freed when LSS unloads the section. NOT an autoload per ADR-0007. Contracts are anchored in **ADR-0002** (5 frozen subscriptions), **ADR-0004** (Theme inheritance + AccessKit), **ADR-0008** (Slot 7 sub-claim), **ADR-0007** (NOT autoload — no slot claim), and **HUD Core UI-3** (the `get_prompt_label()` extension API).

**[MVP-Day-1] CR-3 — Extension API contract is the only path to the prompt-strip Label. REV-2026-04-28: write-path canonicalised to HUD Core via callback return (closes main-review architectural ambiguity).** HSS reads `HUDCore.get_prompt_label() -> Label` at `_ready()`, holds the reference as `_label: Label` for **read-only inspection** (e.g., AccessKit property reads), but **does NOT directly write `_label.text`** — HSS provides the active state's text via `_resolve_hss_state()` (CR-4); HUD Core's `_process()` resolver picks the winner and mutates `_label.text`. HSS MUST NOT: (a) walk HUD Core's scene tree to find the Label by `find_child` / `get_node` paths (the path is HUD Core's private implementation), (b) add new Control children under HUD Core's tree (HSS draws nothing of its own — every HSS surface flows through the callback), (c) modify HUD Core's existing state machine (HIDDEN, INTERACT_PROMPT) directly — HSS adds itself to HUD Core's §C.3 priority resolver via the resolver-extension callback registered at `_ready()` (see CR-4, CR-6 below), (d) directly mutate `_label.text` (REV-2026-04-28 carve-out: the only HSS write to `_label` directly is `_label.accessibility_description` for AccessKit, since AccessKit description is HSS-owned semantic content distinct from the resolver-driven visible text). (Justification: HUD Core UI-3 declares `get_prompt_label()` as the **single forward extension point**; the resolver pattern keeps Label mutation in one place — HUD Core — eliminating the dual-write race that the original CR-3/§C.3 had.)

**[MVP-Day-1] CR-4 — Resolver extension at `_ready()` + unregister at `_exit_tree()` (REV-2026-04-28 — godot-specialist Finding 3).** HSS registers itself with HUD Core's prompt-strip priority resolver via `HUDCore.register_resolver_extension(_resolve_hss_state) -> void` (NEW HUD Core API — see Coord item §F.5 #1). HSS MUST also call `HUDCore.unregister_resolver_extension(_resolve_hss_state) -> void` (NEW HUD Core API — see Coord item §F.5 #1; both `register_` AND `unregister_` variants required) on `_exit_tree`. The callback `_resolve_hss_state() -> ResolverResult` returns the active HSS state's text + priority, OR a sentinel "no HSS state active" value. **HUD Core's resolver writes the Label** — it picks the highest-priority result across `INTERACT_PROMPT` (HUD Core) and the HSS callback's return, then mutates `_label.text = winner.text`. **HSS does NOT directly mutate `_label.text`** (REV-2026-04-28 — closes the CR-3 vs §C.3 architectural ambiguity surfaced in main review): the HSS-side state changes (Timer.start, dict updates, AccessKit description set) cause the next `_process()` resolver tick to pick up the new winner. CR-3's "writes via `_label.text`" language was reframed to "HSS provides text via the callback; HUD Core mutates the Label." HSS does NOT poll, does NOT call resolver methods directly — it provides the callback once and HUD Core's `_process()` invokes it.

**[MVP-Day-1] CR-5 — Per-state Timer node, NOT `_process` polling.** Each HSS state owns a child `Timer` node (`one_shot = true`, `wait_time = <state's auto-dismiss duration>`). On state-entry: HSS sets the active state, sets `_label.text = tr(...)`, calls `<state_timer>.start()`. On `Timer.timeout`: HSS clears the active state and triggers HUD Core's resolver to recompute (the prompt-strip falls to the next-priority state or HIDDEN). HSS has **no `_process` override**. (Justification: ADR-0008 Slot 7 budget; per-frame polling would push HSS over its sub-claim. Timer nodes are O(1) until they fire.)

**[MVP-Day-1] CR-6 — Priority resolver order (HUD Core combined with HSS). REV-2026-04-28: ALARM_STINGER promoted above INTERACT_PROMPT for its full duration to close the HoH-blind-during-interact gap (ux-designer Finding 3, accessibility-specialist Finding 6).**
The combined priority order, highest first:
1. `ALARM_STINGER` (HSS, VS) — **section-wide alarm raised; supersedes EVERYTHING including INTERACT_PROMPT for its 3.0 s duration**. Justification: in the HoH-collision scenario (player mid-interact when section-wide alarm onset fires), keeping INTERACT_PROMPT priority 1 leaves HoH players with no visual signal of the alarm. ALARM_STINGER's 3.0 s window is short enough that a temporarily-blocked INTERACT_PROMPT is acceptable; thematically coherent with §B carve-out ("the clerk stamps ALARM RAISED; Eve's hand pauses on the document"). After ALARM_STINGER's Timer expires, INTERACT_PROMPT re-evaluates normally.
2. `INTERACT_PROMPT` (HUD Core) — interact prompt is action-blocking; the player needs the glyph to know what button does what. Demoted from priority 1 only during ALARM_STINGER active.
3. `ALERT_CUE` (HSS, MVP-Day-1) — HoH/deaf alert-state cue for an individual guard alert.
4. `SAVE_FAILED` (HSS, VS) — auto-save IO_ERROR advisory.
5. `RESPAWN_BEAT` (HSS, VS) — "house lights up" after respawn.
6. `MEMO_NOTIFICATION` (HSS, VS) — document pickup toast.
7. `HIDDEN` — default.

**Same-priority collision rule** (REV-2026-04-28 — closes systems-designer Finding 10): a new state arrival whose priority equals the currently-active state's priority is **dropped** (not queued, not preempted). E.1 (two guards same frame) is the canonical case: the second ALERT_CUE arrives, fails the equality check, and is discarded. ALARM_STINGER subsumes the second-guard case section-wide.

A new state-entry that has higher priority than the active state preempts (active state's Timer cancelled, label updated, new state's Timer started). A new state-entry that has lower priority is queued in a single-deep buffer (see §C.4) and shown when the active state's Timer expires — except `MEMO_NOTIFICATION`, which is dropped if it cannot fire within 1 s of the pickup event (the document is already in the inventory; the toast is informational, not authoritative). (Justification: ALARM_STINGER > everything because section-wide alarm onset is the highest-stakes signal and HoH players need it visible regardless of interact state; INTERACT_PROMPT > ALERT_CUE because button-glyph eligibility gates input; ALERT_CUE > SAVE_FAILED because alert-state is more time-sensitive; RESPAWN_BEAT > MEMO_NOTIFICATION orders by player concern.)

**[MVP-Day-1] CR-7 — All visible strings flow through `tr()`.** No English literals in HSS source. Translation keys in §V (Visual/Audio Requirements). Locale switch mid-display: re-resolve `_label.text = tr(...)` on `Object.NOTIFICATION_TRANSLATION_CHANGED` notification per Document Overlay UI's pattern (§Edge Cases). (Justification: Localization Scaffold ADR-0004 mandates `tr()` discipline; HSS surfaces are visible strings.)

**[MVP-Day-1] CR-8 — AccessKit `accessibility_live` per state — polite default with one whitelisted assertive carve-out (ALARM_STINGER). REV-2026-04-28** (closes accessibility-specialist Finding 6 + ux-designer Finding 2 via §B Margin Note carve-out). When a state activates, HSS sets `_label.accessibility_live` and `_label.accessibility_description = <same text as visual>`, then queues an AT announcement. The live-region value depends on the state:

| State | `accessibility_live` | Justification |
|---|---|---|
| ALERT_CUE | `"polite"` | Margin Note discipline; alert music carries urgency. |
| MEMO_NOTIFICATION | `"polite"` | Bureaucratic acknowledgment; never demands attention. |
| **ALARM_STINGER** | **`"assertive"`** | **§B Margin Note carve-out — failure-of-stealth signal is safety-of-information for HoH players who cannot hear alarm music. The audio sting cannot substitute for a timely AT announcement; polite queuing can take 8–15 s on Orca with active speech buffer.** |
| RESPAWN_BEAT | `"polite"` | Quiet acknowledgment; not safety-critical. |
| SAVE_FAILED | `"polite"` | Advisory only; non-blocking. |

The assertive carve-out is **only** for ALARM_STINGER; FP-HSS-5 (REV-2026-04-28) is amended to permit assertive on ALARM_STINGER and forbid it everywhere else. AccessKit clear timing (closes ux-designer Finding 5): `accessibility_description` clear is **deferred via `call_deferred`** to the next frame on state-exit, NOT cleared synchronously, to prevent Orca cutoff of in-progress polite announcements. ADR-0004 Gate 1 status: `accessibility_live` / `accessibility_description` property names remain pending verification — CI lints (FP-HSS-5, AC-HSS-9.1) MUST be deferred from CI until Gate 1 closes (godot-specialist Finding 1).

**[MVP-Day-1] CR-9 — HoH alert-cue rate-gate per actor-id, with upward-severity escalation exemption (REV-2026-04-28 — closes accessibility-specialist Finding 1: SC 1.1.1 / 1.3.3 violation).** HSS holds `_alert_cue_last_fired_per_actor: Dictionary[Node, float]` AND `_alert_cue_last_state_per_actor: Dictionary[Node, AlertState]` (using actor Node ref → game-time and last-state at last fire). On `alert_state_changed(actor, old, new, severity)` where `new != UNAWARE`:

1. **Upward-severity exemption**: if `new` is a strictly higher severity than `_alert_cue_last_state_per_actor[actor]` (e.g., SUSPICIOUS→COMBAT, UNAWARE→COMBAT) — fire ALERT_CUE **regardless of cooldown**. Update both dicts. Justification: SC 1.1.1 / 1.3.3 require deaf players receive a non-audio equivalent for *every* meaningful state change; a SUSPICIOUS→COMBAT escalation is a different game state from the original SUSPICIOUS entry, and silently suppressing it leaves deaf players uninformed.
2. **Same-or-lower severity within cooldown**: if `actor` last fired ALERT_CUE within `alert_cue_actor_cooldown_s = 1.0` s AND the new state is not strictly higher than the last fired state, **suppress**. This still prevents flicker-fire from SAI perception oscillation (SUSPICIOUS→UNAWARE→SUSPICIOUS oscillation within 1 s).
3. **Beyond cooldown**: fire normally and update both dicts.

**Cross-actor**: per-actor gate, not global — guard B's cue fires regardless of guard A's cooldown. The dictionaries are cleaned of freed Node refs on each fire (`is_instance_valid` guard per ADR-0002 IG4). (Justification: SAI's perception edge-cases can produce rapid state oscillation; firing ALERT_CUE on every transition would violate the Margin Note's "brief moment" anchor and spam AccessKit. BUT: upward-severity escalation is informationally distinct from oscillation — it represents the player's situation getting *worse*, which is exactly what an accessibility-compliant deaf player must be informed of.)

**[MVP-Day-1] CR-10 — Subscriber lifecycle: `_ready` connect / `_exit_tree` disconnect. REV-2026-04-28: adds `HUDCore.unregister_resolver_extension(...)` requirement per godot-specialist Finding 3.** Standard ADR-0002 IG3 pattern. All 5 (or 1, MVP-Day-1) Events subscriptions wrapped in `is_connected` guards on disconnect, using **default sync `connect()` flags only — `CONNECT_DEFERRED` is forbidden** for HSS subscriptions per FP-HSS-15 (REV-2026-04-28; ensures E.6 same-frame guarantees hold). `_alert_cue_last_fired_per_actor` AND `_alert_cue_last_state_per_actor` (CR-9 REV-2026-04-28) cleared in `_exit_tree`. The active state's Timer is force-`stop()` and `queue_free()` on `_exit_tree`. **HSS MUST also call `HUDCore.unregister_resolver_extension(_resolve_hss_state)` in `_exit_tree`** to prevent HUD Core's resolver array from accumulating dead Callables across section reloads (each dead Callable adds wasted `_process()` invocation cost). For CR-18 active pulse: `_health_label.remove_theme_color_override("font_color")` on `_exit_tree` to clear stale override. (Justification: ADR-0002 IG3 mandatory; HSS is per-section so `_exit_tree` fires every section unload; without `unregister_resolver_extension`, HUD Core leaks dead Callables.)

**[MVP-Day-1] CR-11 — Tween-kill on `ui_context_changed != GAMEPLAY`.** Inherits HUD Core CR-22 (added 2026-04-28). HSS subscribes to `Events.ui_context_changed(new, old)`: when `new != Context.GAMEPLAY`, HSS calls `Tween.kill()` on every active Tween it owns AND `<active_state_timer>.stop()` (cancels auto-dismiss). State is cleared (active state → HIDDEN). On return to GAMEPLAY, HSS does NOT resume — it's a transient layer; missed states stay missed (see §B refusal #1: "Not a notification"). (Justification: ADR-0008 Slot 7 budget compliance during DOCUMENT_OVERLAY / MENU / SETTINGS — HUD is hidden, HSS Tweens must not consume residual cost; HUD Core CR-22 closure.)

**[MVP-Day-1] CR-12 — HSS does NOT register with LSS `register_restore_callback`.** HSS holds zero persistent state — no flag, no counter, no history. On section reload (FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE), HSS's `_ready()` runs from scratch on the freshly-instantiated section, and the rate-gate dictionary starts empty. There is nothing to restore. The respawn-beat (RESPAWN_BEAT state) fires from the `respawn_triggered` signal subscription, not from a restore-callback. (Justification: HSS is purely transient; no `SaveGame` schema entry; no LSS coordination needed; mirrors HUD Core's CR-20 "HUD has no `capture()` and registers no restore callback".)

**[MVP-Day-1] CR-13 — No save state.** HSS state is wholly transient. `SaveGame` schema does NOT include an HSS sub-resource. Active state at save-time is dropped; on load, HSS starts at HIDDEN. (Justification: matches CR-12 rationale; the Margin Note is by definition a moment, not a persistent fact.)

**[MVP-Day-1] CR-14 — ADR-0008 Slot 7 sub-claim: ≤0.10 ms steady (REV-2026-04-28 — was 0.05 ms; CR-18 pulse adds ~10 µs/frame steady cost per performance-analyst Finding 2), ≤0.15 ms peak.** HSS shares HUD Core's Slot 7 (0.3 ms cap on Iris Xe). Steady-state cost: 0 µs when no state active AND CR-18 pulse not active; ~10 µs/frame when CR-18 pulse Tween is running (continuous interpolation of `add_theme_color_override` per frame). Peak cost (state-transition frame): 1× `tr()` lookup + 1× resolver-callback return + 1× `Timer.start()` + 1× AccessKit `accessibility_*` set ≈ **52 µs** measured against HUD Core's instrumentation harness (5+10+2+15 — see F.4 worked sum; the previous "≈30-50 µs" was an early scoping estimate, F.4's 52 µs is canonical). Combined HUD Core + HSS Slot 7 budget worst case: HUD Core's F.5 worst-case (0.259 ms) + HSS peak transition (52 µs) = **0.311 ms — over cap by 11 µs** (REV-2026-04-28 corrected from "0.309 ms / 9 µs over" — performance-analyst Finding 1). With CR-18 pulse also active on the coincidence frame: 0.259 + 0.052 + 0.010 = **0.321 ms — over by 21 µs**. **Mitigation (REV-2026-04-28: PROMOTED TO DEFAULT, NOT EMERGENCY FALLBACK — performance-analyst Finding 8)**: HSS implements deferred-AccessKit (`call_deferred` for `accessibility_*` sets) by **default at Day-1**, not as a post-profile escalation. This saves ~15 µs on transition frames, bringing combined to 0.296 ms (no pulse) or 0.306 ms (pulse active — still 6 µs over cap; covered by ADR-0008 reserve carve-out per 2026-04-28 amendment, value to be verified per OQ-HSS-4 profile gate). The previous claim that coincidence is "statistically rare" (§E.24) was wrong — performance-analyst estimates ~40% per combat encounter; deferred-AccessKit is the correct permanent design, not a workaround. (Justification: ADR-0008 Slot 7 contract; OQ-HSS-4 measurement gate before MVP sprint with **Wayland + Orca** active conditions specified per performance-analyst Finding 6.)

**[MVP-Day-1] CR-15 — Pillar 5 absolutes (no graphics, no decoration, no banners).** HSS draws zero new visual elements. Every HSS state is exactly: `_label.text = tr(<key>)` + `_label.accessibility_description = tr(<key>)` + Timer.start. **Forbidden by this CR**: new ColorRect children, new Control children, icons in the Label text (no emoji, no Unicode pictograms), background panels, animations beyond the existing prompt-strip's fade-in/fade-out (HUD Core §V.4 owns the StyleBoxFlat + 0.15 s fade), banner widgets, count-up animations, color shifts. Allowed: `_label.text` mutation, font_color modulation per state (e.g., parchment-tone pulse for clock-tick — but the Label and StyleBoxFlat are HUD Core's). (Justification: Margin Note refuses #2 ("Not a banner"), §C.5 Pillar 5 absolute carve-out, FP-HSS-1..5 in §C.6.)

**[MVP-Day-1] CR-16 — ALARM_STINGER is a single Label line, NOT a separate banner widget. REV-2026-04-28: duration reduced 5.0 → 3.0 s and AccessKit assertive-whitelisted per §B Margin Note carve-out (game-designer Finding 1 + ux-designer Finding 2 + accessibility-specialist Finding 6 reconciled).** Decision (locked here, supersedes the "sustained 4-line banner" provisional language in §A Overview which referred to early scoping): the alarm stinger is the same Label slot HUD Core's INTERACT_PROMPT and HSS's other 4 states write to. The "stinger" quality comes from (a) the paired Audio sting (Audio-owned, NOT HSS), (b) the priority order placing it above EVERYTHING including INTERACT_PROMPT for the duration (CR-6 REV-2026-04-28), and (c) the **assertive AccessKit live-region treatment** (CR-8 carve-out): ALARM_STINGER is the ONLY state in the system that uses `accessibility_live = "assertive"` because section-wide alarm onset is a safety-of-information event (failure-of-stealth signal) for HoH players who cannot rely on alarm music. Visual register identical to other HSS states: BQA Blue strip + Parchment text. Duration `alarm_stinger_duration_s = 3.0` s (down from 5.0 — preserves "brief moment" anchor while remaining long enough for AT polite/assertive announcement to deliver). Text: `tr("HUD_ALARM_RAISED")` (e.g., "ALARM RAISED" in EN — shortened from "ALARM RAISED — TOWER LOCKDOWN" for ≤18 char locale headroom per ux-designer Finding 4; locale-owned in FR/etc). (Justification: Pillar 5 forbids decorative banners and graphics; CR-15 absolute; the architectural simplification — single Label, single discipline — eliminates a whole class of layout/anchor bugs. The carve-out from Margin Note is documented in §B as a designated exception.)

**[MVP-Day-1] CR-17 — `save_failed` advisory routing.** On `Events.save_failed(reason: SaveLoad.FailureReason)`: HSS fires SAVE_FAILED state ONLY if `reason in {IO_ERROR, DISK_FULL_NON_CRITICAL}` (the non-blocking failure modes). For blocking failures (`CORRUPT_SAVE`, `PERMISSION_DENIED` requiring user action), Save/Load itself owns the modal dialog (per Save/Load CR-9) and HSS suppresses. Text varies by reason: `IO_ERROR` → `tr("HUD_SAVE_IO_ERROR")` ("ARCHIVAL ERROR — RETRY"); `DISK_FULL_NON_CRITICAL` → `tr("HUD_SAVE_DISK_FULL")` ("ARCHIVAL FULL — CHECK STORAGE"). Auto-dismiss: `save_failed_duration_s = 4.0` (slightly longer than alert-cue because the player may want to glance at it; still auto-dismissed because the operation continues — F&R OQ-FR-4 ADVISORY resolution). (Justification: §B refusal #4 "Not a fail-state"; F&R OQ-FR-4 closure direction.)

**[VS] CR-18 — Critical-health visual pulse paired with Audio clock-tick. REV-2026-04-28: Tween API rewritten per godot-specialist Finding 2 — `Label.font_color` is NOT a direct property in Godot 4.6; must use `tween_method` driving `add_theme_color_override("font_color", color)`.** When `player_health_changed(current, max)` fires with `current / max ≤ critical_health_threshold` (PC's 0.25 default per `player_critical_health_threshold` registry entry) AND `accessibility.hud_critical_pulse_enabled == true` (Settings toggle, default ON, BLOCKING VS dep per OQ-HSS-10 promotion): HSS triggers a **font_color pulse on the existing health Label** (HUD Core widget — HSS reaches in via `HUDCore.get_health_label() -> Label`, NEW HUD Core API; see Coord item §F.5 #2). Pulse implementation:

```gdscript
# CR-18 Tween implementation — uses tween_method, NOT tween_property("font_color"),
# because Godot 4.6 Label has no direct font_color property; font_color is a Theme override.
var pulse_tween: Tween = create_tween().set_loops(0)  # 0 = infinite per Godot 4.6
pulse_tween.tween_method(
    func(c: Color) -> void: _health_label.add_theme_color_override("font_color", c),
    PARCHMENT, ALARM_ORANGE, clock_tick_period_s / 2.0
)
pulse_tween.tween_method(
    func(c: Color) -> void: _health_label.add_theme_color_override("font_color", c),
    ALARM_ORANGE, PARCHMENT, clock_tick_period_s / 2.0
)
```

The override MUST be cleared on stop conditions (`_health_label.remove_theme_color_override("font_color")`) or the parchment color persists as a stale override. Pulse repeats over `clock_tick_period_s = 0.6` total period (matching Audio's `clock_tick_period_s` per Audio §F.4) while `current / max ≤ critical_health_threshold`. **Defensive floor** (REV-2026-04-28 — closes systems-designer Finding 5): HSS clamps the read value via `pulse_period_s = max(clock_tick_period_s, 0.4)` before starting the tween, with `push_warning` if the clamp fires; this guards against Audio mistuning below 0.4 s = 2.5 Hz (WCAG 2.3.1 floor for chromatic flash).

Stop conditions (clear override + kill tween):
- `current / max > critical_health_threshold`
- `Events.player_died` fires
- `Events.ui_context_changed.new != Context.GAMEPLAY` (CR-11)
- `Events.setting_changed("accessibility", "hud_critical_pulse_enabled", false)` (REV-2026-04-28)
- HSS `_exit_tree` (CR-10)

**CR-18 is purely visual augmentation of an existing HUD Core widget — does NOT consume a prompt-strip state slot** (so MEMO_NOTIFICATION can still fire at critical health). (Justification: pairs with Audio's clock-tick per game-concept "alert state via audio" — visual is the accessibility carve-out for HoH/deaf players who can't hear the tick; Pillar 5 absolute is preserved because the Label and StyleBoxFlat are HUD Core's, HSS only mutates the existing font_color theme override — no new widget. The opt-out toggle satisfies WCAG 2.2.2 Level A Pause/Stop/Hide.)

**[MVP-Day-1] CR-19 — Day-1 minimal slice scope = ALERT_CUE only.** All other 4 states (MEMO_NOTIFICATION, ALARM_STINGER, RESPAWN_BEAT, SAVE_FAILED) plus CR-18 critical-health pulse are **VS-tier**. MVP-Day-1 ships:
- Subscription to `Events.alert_state_changed`
- ALERT_CUE state with `alert_cue_duration_s = 2.0`
- Priority order CR-6 with only ALERT_CUE registered
- CR-9 per-actor rate-gate
- CR-7 `tr()` discipline + 1 translation key (`HUD_GUARD_ALERTED`)
- CR-8 AccessKit polite live region
- CR-10 + CR-11 subscriber lifecycle and Tween-kill
- CR-14 Slot 7 sub-claim (measured for ALERT_CUE only at MVP)

The Day-1 slice unblocks HUD Core's HARD MVP DEP per HUD Core REV-2026-04-26 D3. VS expansion adds the other 4 states + CR-18 + the 4 additional Events subscriptions. (Justification: HUD Core REV-2026-04-26 D3 user adjudication; WCAG 1.1.1 / 1.3.3 + EU GAAD floor.)

### C.2 States and Transitions

| State | Tier | Trigger signal | Auto-dismiss (s) | Priority (CR-6) | Text key | AccessKit | Notes |
|---|---|---|---|---|---|---|---|
| **HIDDEN** | MVP-Day-1 | Default; Timer.timeout from any state with no queued state | — | 7 (lowest) | (none) | clear `accessibility_description` | Default state; prompt-strip Label is `visible = false` per HUD Core §C.3. |
| **ALERT_CUE** | **MVP-Day-1** | `alert_state_changed(actor, _, new, _)` where `new != AlertState.UNAWARE` AND CR-9 rate-gate passes | 2.0 | 3 | `HUD_GUARD_ALERTED` | polite | HoH/deaf accommodation. Single per-actor rate-gate (CR-9). Severity ignored (any non-UNAWARE entry fires). |
| **MEMO_NOTIFICATION** | VS | `document_collected(document_id)` | 3.0 | 6 | `HUD_DOCUMENT_COLLECTED` + `" — "` + `tr(doc.title_key)` | polite | Reads `Document` Resource by id from DC's registry to resolve `title_key`. If id not found in DC registry (defensive), suppress and `push_warning`. |
| **ALARM_STINGER** | VS | `alert_state_changed(_, _, new, severity)` where `new == AlertState.COMBAT` AND `severity == StealthAI.Severity.MAJOR` AND no other guard already in COMBAT (section-wide alarm onset) | **3.0** (REV-2026-04-28) | **1** (REV-2026-04-28 — preempts INTERACT_PROMPT) | `HUD_ALARM_RAISED` | **assertive** (REV-2026-04-28 §B carve-out) | Section-wide alarm onset, NOT per-guard alert. Tracks "section in alarm" boolean to avoid re-firing while already alarmed. Resets on section unload (CR-12 — node freed). Audio's alarm sting is a paired effect (Audio-owned). **The ONLY HSS state with assertive AccessKit + priority-1 preemption** — designated Margin Note exception per §B. |
| **RESPAWN_BEAT** | VS | `respawn_triggered(section_id)` | 1.5 | 5 | `HUD_RESPAWN` | polite | Single fire per respawn. Text: "OPERATION RESUMED" (EN). Pairs with F&R's "Eve does not die well" framing — quiet typographic acknowledgment, not a "You Died" surface. |
| **SAVE_FAILED** | VS | `save_failed(reason)` where `reason in {IO_ERROR, DISK_FULL_NON_CRITICAL}` | 4.0 | 4 | `HUD_SAVE_IO_ERROR` / `HUD_SAVE_DISK_FULL` (per CR-17) | polite | Advisory only. Blocking failures (CORRUPT_SAVE, PERMISSION_DENIED) suppressed — Save/Load owns the modal. |
| **(extension) Critical-health pulse** | VS | `player_health_changed(current, max)` where `current / max ≤ player_critical_health_threshold` | continuous (until threshold cleared OR `player_died`) | n/a (font_color tween on health Label, NOT a prompt-strip state) | n/a (visual-only) | n/a (the health numeral is already announced by HUD Core; HSS adds no new AT announcement) | CR-18. Period = `clock_tick_period_s = 0.6` matching Audio's tick. Stops on `current / max > player_critical_health_threshold` OR `player_died`. |

**Transitions**:

| From | To | Trigger | Notes |
|---|---|---|---|
| HIDDEN | any HSS state | matching Events signal + state-specific gates pass | Timer.start. AccessKit announce. |
| any HSS state | HIDDEN | active state's Timer.timeout AND no queued lower-priority state | resolver re-evaluates; if HUD Core's INTERACT_PROMPT is now active, prompt-strip shows that instead of HIDDEN. |
| any HSS state | higher-priority HSS state | preemption (CR-6) | active Timer.stop, new state activates with its own Timer. Previous state is dropped (single-deep buffer holds at most 1 lower-priority). |
| any HSS state | lower-priority HSS state | NOT directly — lower-priority queues until active expires | Single-deep buffer: latest lower-priority arrival overwrites any prior queued state. |
| any HSS state | HIDDEN (forced) | `ui_context_changed.new != Context.GAMEPLAY` (CR-11) | active Timer.stop, state cleared. No resume. |

### C.3 Priority Resolver Extension (combined with HUD Core)

```text
HUDCore._process() each frame:
  1. result_hud = HUDCore._resolve_interact_prompt()
     ├─ INTERACT_PROMPT (priority 1) if PC.get_current_interact_target() valid
     └─ HIDDEN (priority 7) otherwise
  2. result_hss = HSS._resolve_hss_state() via registered callback (CR-4)
     └─ returns the highest-priority active HSS state OR HIDDEN
  3. winner = max(result_hud, result_hss) by priority (CR-6 ordering)
  4. if winner.text != _label.text: _label.text = winner.text + AccessKit announce
  5. if winner == HIDDEN: _label.visible = false; else _label.visible = true
```

HSS's `_resolve_hss_state()` returns the active HSS state's text (NOT the priority enum value, which is HUD Core-internal). HUD Core's resolver maps the returned text to the priority via a state-id parameter HSS passes alongside the text. **HSS must not call HUD Core's resolver directly** — only the registered callback path (CR-4) is sanctioned.

**Single-deep buffer for queued lower-priority HSS state**: when the active state is preempted by a higher-priority state, the preempted state is **dropped** (no buffer). When a lower-priority state arrives while a higher-priority HSS state is active, it's held in `_queued_state` (single slot — overwrites any prior queued state). On active state Timer.timeout, if `_queued_state` is non-empty AND would still pass its entry gates AND the queued state's freshness has not expired (`(now - queued_at_time) <= queued_state_max_age_s = 5.0`, REV-2026-04-28 — was 1.0; raised to match `alarm_stinger_duration_s` so that lower-priority states queued behind ALARM_STINGER actually survive — closes systems-designer Finding 2), it activates. Otherwise discarded.

### C.4 Auto-dismiss Timer Pattern

Each state owns a child Timer node:

```gdscript
# res://src/ui/hud_state_signaling.gd
class_name HUDStateSignaling extends Node

@onready var _alert_cue_timer: Timer = $AlertCueTimer
@onready var _memo_timer: Timer = $MemoTimer  # VS only
@onready var _alarm_timer: Timer = $AlarmTimer  # VS only
@onready var _respawn_timer: Timer = $RespawnTimer  # VS only
@onready var _save_failed_timer: Timer = $SaveFailedTimer  # VS only

func _ready() -> void:
    # Connect Events subscriptions per CR-10
    Events.alert_state_changed.connect(_on_alert_state_changed)
    # ... other VS subscriptions

    # Connect Timer.timeout for each state
    _alert_cue_timer.timeout.connect(_on_alert_cue_dismissed)
    # ...

    # Acquire Label reference per CR-3
    _label = HUDCore.get_prompt_label()

    # Register resolver extension per CR-4
    HUDCore.register_resolver_extension(_resolve_hss_state)

    # Ui context tracking per CR-11
    Events.ui_context_changed.connect(_on_ui_context_changed)
```

Timer wait_time values per §G.1 (Tuning Knobs): 2.0 (alert), 3.0 (memo), 5.0 (alarm), 1.5 (respawn), 4.0 (save_failed). All `one_shot = true`.

### C.5 Interactions with Other Systems

| System | Direction | Contract | Owner |
|---|---|---|---|
| **HUD Core ✅ Approved 2026-04-26** | inbound only (HSS reads) | HSS calls `HUDCore.get_prompt_label() -> Label` at `_ready()` (CR-3). HSS calls `HUDCore.register_resolver_extension(Callable)` at `_ready()` (CR-4 — **NEW HUD Core API needed; see Coord item §F.5 #1**). For VS CR-18: HSS calls `HUDCore.get_health_label() -> Label` (**NEW HUD Core API; see §F.5 #2**). HSS does NOT modify HUD Core's §C.3 priority machine, §C.4 photosensitivity gate, or any widget except via the published APIs. | HUD Core owns Label nodes and resolver. HSS extends. |
| **Stealth AI ✅ Approved** | inbound only | HSS subscribes `Events.alert_state_changed(actor, old, new, severity)`. Day-1: any `new != UNAWARE` fires ALERT_CUE (with CR-9 rate-gate). VS: also tracks "section-wide alarm" (any guard `new == COMBAT` with `severity == MAJOR`) → ALARM_STINGER. | SAI owns the signal; HSS consumes. |
| **Document Collection ✅ APPROVED** | inbound only (VS) | HSS subscribes `Events.document_collected(document_id)`. Resolves `Document.title_key` via `DC.get_document_resource(id) -> Document` (DC's existing public method per DC §C.0; HSS reads, never mutates). MEMO_NOTIFICATION text composes `tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)`. Closes DC OQ-DC-8 (VS BLOCKING coord). | DC owns the signal + Document Resource registry; HSS consumes. |
| **Failure & Respawn ✅ pending coord** | inbound only (VS) | HSS subscribes `Events.respawn_triggered(section_id)`. RESPAWN_BEAT fires once per emission. Closes F&R OQ-FR-4 ADVISORY (HSS owns the visual line; F&R remains silent on respawn beyond the signal). | F&R owns the signal; HSS consumes. |
| **Player Character ✅ Approved** | inbound only (VS) | HSS subscribes `Events.player_health_changed(current, max)` for CR-18 critical-health pulse. Reads `player_critical_health_threshold` constant from registry (PC-owned, value `0.25`). | PC owns the signal + constant; HSS consumes. |
| **Save / Load ✅ pending re-review** | inbound only (VS) | HSS subscribes `Events.save_failed(reason: SaveLoad.FailureReason)` with the CR-17 enum filter. Save/Load's blocking failures are excluded (Save/Load CR-9 modal handles those). | Save/Load owns the signal + FailureReason enum; HSS consumes. |
| **Audio ✅ Approved** | sibling (no direct contract) | HSS visual states pair with Audio cues that Audio subscribes to the **same source signals** (alert_state_changed → alert sting, document_collected → pickup chime, respawn_triggered → respawn sting, save_failed → save-failed advisory cue, player_health_changed critical → clock-tick). HSS does NOT trigger Audio; Audio does NOT trigger HSS. They are co-subscribers to the same source signals, each owning their own channel (Audio = SFX bus, HSS = visual Label). | Both subscribe; no direct coupling. |
| **Localization Scaffold ✅ Designed** | inbound only | All 5 (Day-1: 1) translation keys listed in §V live in the project's string table. HSS `tr()` lookups follow Localization Scaffold's loading + fallback rules. `NOTIFICATION_TRANSLATION_CHANGED` re-resolves the active state's label text (CR-7). | Localization owns the table; HSS consumes via `tr()`. |
| **Settings & Accessibility ✅ Designed** | inbound only (VS, optional) | If Settings adds a future `accessibility.hud_alert_cue_enabled` toggle (advisory — see §Open Questions), HSS subscribes `setting_changed("accessibility", "hud_alert_cue_enabled", value)` and gates ALERT_CUE rendering on the toggle. **Day-1: no Settings dependency** — ALERT_CUE always fires (HoH compliance is non-negotiable). | Settings (potentially) owns the toggle; HSS consumes. |
| **Mission & Level Scripting ✅ pending re-review** | indirect | MLS owns section-load orchestration via LSS callback chain. HSS is part of the section's `Section/Systems/HUDStateSignaling` node tree, freed by LSS on unload. No direct MLS-HSS coupling. | MLS owns section lifecycle; HSS lives within it. |
| **Level Streaming ✅ Approved** | indirect (lifecycle only) | HSS `_ready()` runs after section_entered fires (per LS step-9 callback completion); HSS `_exit_tree` runs on section unload. HSS does NOT call `LS.register_restore_callback` (CR-12). | LS owns the lifecycle; HSS observes. |
| **Civilian AI ✅ Approved 2026-04-25 → Needs Revision** | forbidden non-dep | HSS does NOT subscribe to `civilian_panicked` / `civilian_witnessed_event`. Civilians are Pillar-5 zero-UI absolute (CAI's own constraint) — no HUD acknowledgment of civilian behavior, ever. | Forbidden coupling. |
| **Combat & Damage ⏳ Needs Revision** | forbidden non-dep | HSS does NOT subscribe to `weapon_fired`, `enemy_killed`, `enemy_damaged`, `gadget_activation_rejected`, `weapon_dry_fire_click` (HUD Core handles those). HSS does NOT modify Combat's crosshair (HUD Core owns) or damage-flash gate (HUD Core §C.4 absolute). | Forbidden coupling. |
| **Inventory & Gadgets ⏳ Needs Revision** | forbidden non-dep | HSS does NOT subscribe to `gadget_equipped`, `gadget_used`, `weapon_switched`, `ammo_changed` (HUD Core handles those). | Forbidden coupling. |
| **Cutscenes & Mission Cards (#22, Not Started)** | indirect (CR-11 mediation) | When Cutscenes pushes its InputContext (forward-dep — Cutscenes GDD owns), HSS auto-suppresses via CR-11 `ui_context_changed != GAMEPLAY`. No direct Cutscenes-HSS coupling. | CR-11 mediates. |
| **Dialogue & Subtitles (#18, Designed 2026-04-28)** | forbidden non-dep | Subtitles are owned by Dialogue & Subtitles GDD #18 — separate Label on **CanvasLayer 2** (per dialogue-subtitles GDD `subtitle_canvas_layer` LOCKED constant; updates the prior speculative "CanvasLayer 15" reference). HSS and Subtitles do not share state, do not coordinate priority, do not occupy the same Label. | Forbidden coupling at MVP and VS. |
| **Document Overlay UI ⏳ Needs Revision** | indirect (CR-11 mediation) | When Document Overlay opens (`InputContext.DOCUMENT_OVERLAY` pushed), HSS auto-suppresses via CR-11. The pickup-toast (MEMO_NOTIFICATION) fires on `document_collected` BEFORE the overlay opens (DC §C.5.4 sequence) — so the typical flow is: pickup → MEMO_NOTIFICATION fires (~3 s) → overlay opens within that window → CR-11 suppresses HSS for the duration of the overlay → overlay closes → if MEMO_NOTIFICATION's Timer hadn't expired, the state was already cleared by CR-11 (no resume). The player sees: pickup happens, brief margin note flashes, overlay sepia-fades in, the overlay's "The Lectern Pause" takes the floor. | CR-11 mediates; sequencing per DC + Overlay §C.5. |
| **Menu System ⏳ Needs Revision** | indirect (CR-11 mediation) | When Menu pushes `Context.MENU` / `Context.PAUSE` / `Context.MODAL`, HSS auto-suppresses via CR-11. | CR-11 mediates. |

### C.6 Forbidden Patterns

**FP-HSS-1**: any new visible Control / ColorRect / NinePatchRect / TextureRect added under HSS's node tree. CI grep: `class_name HUDStateSignaling` + scene tree must contain only Timer nodes. **Justification**: CR-15 absolute.

**FP-HSS-2**: any `_label.text` that contains characters outside `[a-zA-Z0-9 .,—:'!?\-/À-ÿ]` (period typography requires no emoji, no Unicode pictograms, no decorative glyphs). CI grep on translation tables: regex match for any of `[🎮🎯⚠️✅❌🟢🔴]` flags fail. **Justification**: §B refusal #2 ("Not a banner") + Margin Note typographic discipline.

**FP-HSS-3**: any direct write to HUD Core scene tree paths (`HUDCore.get_node("PromptStrip/Label")` style). CI grep: forbidden patterns `get_node\(.*PromptStrip` + `find_child\(.*Label.*\)` inside HSS source. **Justification**: CR-3 — only `get_prompt_label()` API is sanctioned.

**FP-HSS-4**: any `_process` or `_physics_process` override on HSS classes. CI grep: `func _process` / `func _physics_process` in `src/ui/hud_state_signaling.gd` flags fail. **Justification**: CR-5 — Timer-based dismiss only.

**FP-HSS-5** (REV-2026-04-28 — assertive whitelist for ALARM_STINGER per §B Margin Note carve-out): any HSS state OTHER THAN ALARM_STINGER with `accessibility_live = "assertive"`. CI grep: `accessibility_live\s*=\s*"assertive"` matches must occur ONLY within the ALARM_STINGER state-entry function (specifically `_on_alarm_stinger_entry()` or equivalent identified by surrounding context); any other location flags fail. **Justification**: CR-8 — Margin Note refuses to demand attention; ALARM_STINGER is the designated exception per §B (failure-of-stealth signal requires assertive AT delivery for HoH/blind/deafblind safety-of-information).

**FP-HSS-6**: any HSS state with auto-dismiss `wait_time > 8.0` s. CI grep on Timer node `.wait_time` properties (or hardcoded values) > 8.0 flags fail. **Justification**: §B "brief moment" anchor; states sustained beyond ~8 s become notifications, not margin notes.

**FP-HSS-7**: any English literal in HSS source where a `tr()` call should be. CI grep regex (REV-2026-04-28 — defined per systems-designer Finding 7 / qa-lead Finding 5): match string literal values containing `[A-Z ]{4,}` (four or more consecutive all-caps letters/spaces) that are NOT wrapped in a `tr(...)` call AND NOT inside a code comment. Exception list: GDScript class names (`Timer`, `Label`, `Node`), enum values (`UNAWARE`, `SUSPICIOUS`, `COMBAT`, `MAJOR`, `MINOR`), AccessKit literals (`"polite"`, `"assertive"`), connect-flag constants (`CONNECT_DEFERRED`), method names. The regex flags HUD-domain content like `"GUARD ALERTED"`, `"DOCUMENT FILED"`, `"ALARM RAISED"` outside `tr(` — exactly the values the rule targets. **Justification**: CR-7 — `tr()` discipline; explicit regex avoids the "limited heuristic" false-positive risk surfaced in adversarial review.

**FP-HSS-8**: any ADR-0002 emit from HSS source. CI grep: `Events\..*\.emit\(` in HSS source flags fail. **Justification**: CR-1 — subscriber-only.

**FP-HSS-9**: any direct call to HUD Core's photosensitivity gate (`HUDCore._on_damage_flash`, etc.). CI grep: `HUDCore\._on_` / `HUDCore\._pending_flash` inside HSS source flags fail. **Justification**: CR-3 (only published APIs) + HUD Core §C.4 absolute (HSS may NOT bypass photosensitivity).

**FP-HSS-10**: any HSS state that surfaces objective-marker / minimap / waypoint / quest-tracker text. CI grep: text keys / string literals matching `objective`, `waypoint`, `marker`, `tracker`, `compass` inside HSS source flags fail. **Justification**: anti-pillar (game-concept §Anti-Pillars) — modern UX paternalism is rejected at the project level; HSS as "transient HUD layer" must not become the back door for objective UI.

**FP-HSS-11**: any HSS state that surfaces XP / progression / achievement / unlock toast. CI grep: text keys / string literals matching `xp`, `level_up`, `unlocked`, `achievement`, `+\d+` inside HSS source flags fail. **Justification**: anti-pillar (game-concept §Anti-Pillars — no XP / skill trees / persistent upgrades).

**FP-HSS-12** (NEW REV-2026-04-28 — game-designer Finding 4a): any HSS state that surfaces faction/relationship/trust/suspicion-meter text. CI grep on translation keys + string literals: `faction`, `trust`, `relationship`, `suspicion_level`, `phantom_suspects`, `bribed`, `reputation`. **Justification**: anti-pillar (no faction-state UI; SAI body-language + dialogue carry suspicion).

**FP-HSS-13** (NEW REV-2026-04-28 — game-designer Finding 4b): any HSS state that surfaces stealth-rank, performance-grade, or post-encounter validation text. CI grep on keys + literals: `ghost_rating`, `silent`, `perfect`, `floor_cleared`, `silent_run`, `rank`, `grade`, `stealth_score`. **Justification**: anti-pillar — *Paris Affair* explicitly rejects NOLF1's stealth-rank conventions; the absence of grading IS the design (player measures success diegetically through document collection, not through HUD validation).

**FP-HSS-14** (NEW REV-2026-04-28 — game-designer Finding 4c): any HSS state that surfaces NPC name + state-change text (e.g., enemy ID on kill/incapacitation). CI grep on keys + literals: `eliminated`, `_killed`, `_incapacitated`, `kill_confirm`, `target_down`, NPC name reference patterns matching the `Document.title_key` style. **Justification**: anti-pillar — kill cams are explicitly forbidden; the textual equivalent (named-NPC kill-confirmation) is the same anti-pillar.

**FP-HSS-15** (NEW REV-2026-04-28 — godot-specialist Findings 2/12): any HSS subscription using `CONNECT_DEFERRED` flag. CI grep: `connect\(.*CONNECT_DEFERRED` against any `Events\.<signal>\.connect\(` site in HSS source. **Justification**: E.6's same-frame guarantee + CR-9's per-actor cooldown logic both depend on synchronous signal dispatch; deferring HSS subscriptions delays state-entry by one frame and breaks priority resolver determinism.

### C.7 Bidirectional Consistency Check

| Upstream contract | HSS verifies | Status |
|---|---|---|
| HUD Core UI-3 publishes `get_prompt_label() -> Label` | HSS reads via this method only | ✅ aligned (CR-3) |
| HUD Core CR-22 mandates Tween.kill on `ui_context_changed != GAMEPLAY` | HSS Tweens (only Timer-driven, but CR-11 also stops Timers) follow rule | ✅ aligned (CR-11) |
| HUD Core §C.4 photosensitivity rate-gate is absolute (HSS may NOT redefine) | HSS does not touch the gate | ✅ aligned (FP-HSS-9) |
| ADR-0002 `alert_state_changed(actor, old, new, severity)` signature | HSS subscriber matches signature | ✅ aligned |
| ADR-0002 `document_collected(document_id: StringName)` signature | HSS subscriber matches signature | ✅ aligned (CR-17) |
| ADR-0002 `respawn_triggered(section_id: StringName)` signature | HSS subscriber matches signature | ✅ aligned |
| ADR-0002 `player_health_changed(current: float, max: float)` signature | HSS subscriber matches signature | ✅ aligned (CR-18) |
| ADR-0002 `save_failed(reason: SaveLoad.FailureReason)` signature | HSS subscriber matches signature | ✅ aligned (CR-17) |
| ADR-0002 `ui_context_changed(new, old)` signature (added 2026-04-28) | HSS subscriber matches signature | ✅ aligned (CR-11) |
| ADR-0004 InputContext enum includes GAMEPLAY (and post-amendment MODAL/LOADING) | HSS gates on `Context.GAMEPLAY` only | ✅ aligned |
| ADR-0007 — HSS is NOT autoload | HSS = per-section Node | ✅ aligned (CR-2) |
| ADR-0008 Slot 7 = 0.3 ms shared cap | HSS sub-claim 0.05 ms steady / 0.15 ms peak | ✅ aligned (CR-14) — measurement gate before MVP sprint |
| ADR-0001 — HSS draws zero stenciled geometry | HSS = Label.text mutation only | ✅ aligned (FP-HSS-1) |
| Localization Scaffold `tr()` discipline | HSS uses `tr()` for all strings; re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` | ✅ aligned (CR-7) |
| Settings CR-2 single canonical home for accessibility settings = `accessibility` category | HSS subscribes to `setting_changed("accessibility", _, _)` only (no `("hud", _, _)`) | ✅ aligned (CR-7 / VS only) |
| DC OQ-DC-8 BLOCKING coord (VS) — HSS subscribes `document_collected` for pickup toast | HSS CR-3 + §C.5 row | ✅ aligned (closes OQ-DC-8) |
| F&R OQ-FR-4 ADVISORY — HSS owns "auto-save failed" advisory line | HSS CR-17 + §C.5 row | ✅ aligned (closes OQ-FR-4) |
| HUD Core REV-2026-04-26 D3 HARD MVP DEP — HSS Day-1 alert-cue minimal slice | HSS CR-19 specifies the exact Day-1 slice scope | ✅ aligned (closes the HUD Core Day-1 dep) |

## Formulas

HSS is a thin orchestration layer; the mathematical surface is small by design. Five formulas, all simple — three are predicates, one is a composition, one is a frame-cost claim.

### F.1 — Auto-dismiss Timer wait_time per state

The `auto_dismiss_duration_s` per HSS state is defined as:

`auto_dismiss_duration_s[state] = constants[state]`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `state` | s | enum HSSState | {ALERT_CUE, MEMO_NOTIFICATION, ALARM_STINGER, RESPAWN_BEAT, SAVE_FAILED} | The HSS state whose dismiss duration is being looked up. |
| `constants[state]` | c[s] | float (seconds) | per row | Per-state constant from §G.1 Tuning Knobs. |

**Per-state values** (default; tunable per §G.1):

| State | Default (s) | Safe range | Rationale |
|---|---|---|---|
| ALERT_CUE | 2.0 | [1.5, 3.0] | Brief but readable for HoH/deaf players. <1.5: too brief to read at 14 px. >3.0: starts to read as a notification, not a margin note. |
| MEMO_NOTIFICATION | 3.0 | [2.0, 4.5] | Slightly longer because the text includes the document title (variable length). >4.5: overlaps the typical pickup→read flow (Document Overlay opens within ~1-2 s). |
| ALARM_STINGER | **3.0** (REV-2026-04-28) | [2.5, 4.0] | Reduced from 5.0 per §B Margin Note carve-out (game-designer Finding 1). Long enough to deliver assertive AT announcement on Orca worst case (~2.5 s typical assertive dispatch); short enough to not violate "brief moment" anchor. Above 4.0 reads as sustained banner. |
| RESPAWN_BEAT | 1.5 | [1.0, 2.5] | Quietest of the 5 — the player just respawned and the action is resuming. <1.0: unreadable. >2.5: dwells on the failure event (anti-Pillar 3). |
| SAVE_FAILED | 4.0 | [3.0, 6.0] | Longer than ALERT_CUE because the player may want to glance at it after the moment passes. >6.0: starts to feel like a sustained warning, not an advisory. |

**Output Range:** [1.0, 7.0] s under safe ranges. FP-HSS-6 caps at 8.0 s absolute.
**Example:** ALERT_CUE fires at game-time `T = 12.345`. Timer.start with `wait_time = 2.0`. Timer.timeout fires at `T ≈ 14.345` (Godot Timer is frame-quantized; ±1 frame at 60 Hz = ±16 ms acceptable).

### F.2 — Priority resolver winner predicate

The active prompt-strip state is determined by:

`winner = argmin(priority(state)) for state in {INTERACT_PROMPT, ALARM_STINGER, ALERT_CUE, SAVE_FAILED, RESPAWN_BEAT, MEMO_NOTIFICATION, HIDDEN} where state is currently active`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `priority(state)` | p(s) | int | [1, 7] | Priority value per CR-6 (lower = higher priority). |
| "active" | (predicate) | bool | true/false | A state is "active" iff its triggering signal fired AND its Timer has NOT yet timed out (HSS states) OR the underlying condition is true (HUD Core's INTERACT_PROMPT — `pc.get_current_interact_target()` valid). |

**Priority ordering** (CR-6, restated as a function):
- `priority(INTERACT_PROMPT) = 1` (HUD Core)
- `priority(ALARM_STINGER) = 2` (HSS, VS)
- `priority(ALERT_CUE) = 3` (HSS, MVP-Day-1)
- `priority(SAVE_FAILED) = 4` (HSS, VS)
- `priority(RESPAWN_BEAT) = 5` (HSS, VS)
- `priority(MEMO_NOTIFICATION) = 6` (HSS, VS)
- `priority(HIDDEN) = 7` (default)

**Output Range:** Exactly one winner per `_process()` frame (or HIDDEN if no state active).
**Example:** Player picks up document while a guard goes COMBAT (section-wide alarm onset) on the same frame. ALARM_STINGER (priority 2) preempts MEMO_NOTIFICATION (priority 6); the pickup toast is queued in the single-deep buffer. After ALARM_STINGER's 5.0 s Timer expires, if the queued MEMO_NOTIFICATION's age `(now - queued_at_time) ≤ 1.0` s, it activates; otherwise discarded (player has likely opened Document Overlay by then per Overlay §C.4 auto-open).

### F.3 — CR-9 per-actor rate-gate predicate

ALERT_CUE fires for `(actor, alert_state)` iff:

`should_fire = (now - _alert_cue_last_fired_per_actor.get(actor, -INF)) >= alert_cue_actor_cooldown_s`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `now` | t | float (seconds) | game-time, monotonic | Current game-time at signal handler entry. |
| `_alert_cue_last_fired_per_actor` | dict | Dictionary[Node, float] | per-actor | Last fire time per actor Node ref. |
| `alert_cue_actor_cooldown_s` | T | float (seconds) | safe [0.5, 2.0]; default 1.0 | Per-actor cooldown to debounce SAI perception oscillation. |
| `-INF` | sentinel | float | — | Default value when actor not in dict — guarantees first emission fires. |

**Output Range:** `should_fire ∈ {true, false}`. The dictionary's update is part of the same critical section: if `should_fire == true`, set `_alert_cue_last_fired_per_actor[actor] = now` BEFORE label mutation (atomic).
**Cleanup:** dictionary entries with freed Node keys are removed on each fire (`is_instance_valid(actor) == false` → `dict.erase(actor)`).
**Example:** Guard G1 emits `alert_state_changed(G1, UNAWARE, SUSPICIOUS, MINOR)` at `T = 5.0`. `_alert_cue_last_fired_per_actor[G1]` was unset → defaults to `-INF`. `5.0 - (-INF) >= 1.0` → fire. Timer starts. Dict updates to `{G1: 5.0}`. At `T = 5.4`, G1 emits `alert_state_changed(G1, SUSPICIOUS, UNAWARE, MINOR)`: ALERT_CUE doesn't fire on UNAWARE (state-gate). At `T = 5.6`, G1 emits `alert_state_changed(G1, UNAWARE, SUSPICIOUS, MINOR)` again: `5.6 - 5.0 = 0.6 < 1.0` → suppress (rate-gate). At `T = 6.1`, G1 emits same: `6.1 - 5.0 = 1.1 >= 1.0` → fire. Dict updates to `{G1: 6.1}`.

### F.4 — Slot 7 frame-cost composition

Combined HUD Core + HSS Slot 7 cost on a state-transition frame:

`C_total = C_hud_core + C_hss_transition`

`C_hss_transition = C_tr_lookup + C_label_text_set + C_timer_start + C_accesskit_set`

**Variables:**

| Variable | Type | Range (Iris Xe estimated) | Description |
|---|---|---|---|
| `C_hud_core` | µs | up to 259 µs (HUD Core F.5 worst case) | HUD Core's per-frame Slot 7 cost. |
| `C_tr_lookup` | µs | 5–15 | Single `tr()` Dictionary lookup. |
| `C_label_text_set` | µs | 10–20 | `Label.text = ...` triggers re-layout if text width changes. |
| `C_timer_start` | µs | 1–2 | `Timer.start()` is O(1). |
| `C_accesskit_set` | µs | 10–15 | `accessibility_description` + `accessibility_live` set; AccessKit announce is queued, not synchronous. |

**Worst case `C_hss_transition`**: 15 + 20 + 2 + 15 = **52 µs ≈ 0.052 ms**.
**Worst case `C_total` (no pulse)**: 259 + 52 = **311 µs**, OVER ADR-0008 Slot 7 cap (300 µs) by 11 µs.
**Worst case `C_total` (CR-18 pulse active + state transition same frame, REV-2026-04-28 — performance-analyst Findings 2 + 3)**: 259 + 52 + ~10 (pulse Tween advance) = **321 µs**, OVER cap by 21 µs.
**Steady-state with CR-18 pulse active (NEW row REV-2026-04-28)**: HUD Core steady + ~10 µs pulse Tween = HUD-Core-steady + 10 µs/frame. The previous CR-14 claim of "0 steady-state" was correct ONLY when CR-18 pulse is inactive; canonical sub-claim is now 0.10 ms steady with pulse, 0.15 ms peak.
**Mitigation (REV-2026-04-28: deferred-AccessKit promoted to DEFAULT — performance-analyst Finding 8)**: `call_deferred` for `accessibility_*` sets on every state transition (saves ~15 µs); applies at Day-1, not as emergency fallback. Combined frame after deferral: 311-15 = **296 µs (under cap)** or 321-15 = **306 µs (pulse active, 6 µs over — covered by ADR-0008 reserve carve-out per 2026-04-28 amendment)**.
**Caveats** (REV-2026-04-28):
- `C_tr_lookup` 5–15 µs is **EN-only**; FR with EN fallback miss can hit 20–25 µs (performance-analyst Finding 4) — measure on FR locale before VS sprint.
- `C_label_text_set` 10–20 µs assumes **Latin-only text** (EN/FR/DE); CJK/RTL re-layout via ICU shaping runs 40–80 µs (performance-analyst Finding 5) — do NOT extrapolate this range beyond Latin without re-profiling.
- `C_accesskit_set` 10–15 µs is the X11 estimate; **Wayland + Orca** may push to 30–80 µs on first set after AT connect (performance-analyst Finding 6) — OQ-HSS-4 profile gate MUST measure under Wayland + Orca active conditions.
**Output Range:** [259, 311] µs Iris Xe (no pulse); [311, 321] µs Iris Xe (pulse active); [85, 110] µs RTX 2060 (scaled).
**Example:** measurement harness fires ALERT_CUE while HUD Core's photosensitivity flash is mid-cycle AND CR-18 pulse is active. Frame profiler reports 305 µs after deferred-AccessKit applied → within carve-out budget.

### F.5 — Critical-health pulse period (VS, CR-18)

The `font_color` tween period for the critical-health pulse:

`pulse_period_s = clock_tick_period_s`

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `clock_tick_period_s` | float (seconds) | safe [0.4, 1.0]; default 0.6 | Audio-owned constant per Audio §F.4. HSS reads from registry, does NOT define its own value. |

**Output Range:** Period = `clock_tick_period_s`. The tween shape is `Parchment → Alarm Orange → Parchment` over one full period (linear interpolation; ease_in_out optional).
**Active condition** (CR-18): `current / max ≤ player_critical_health_threshold` (PC's `0.25` default).
**Stop conditions** (CR-18): `current / max > player_critical_health_threshold` OR `player_died` fires.
**Output:** `Label.font_color` modulates between the two values; no other Label property changes.
**Example:** `current = 22`, `max = 100`, threshold = `0.25` → `0.22 ≤ 0.25` → pulse active. Tween cycles at 0.6 s period (matching Audio's tick). At `current = 30`, threshold = `0.25` → `0.30 > 0.25` → tween stops (font_color reverts to Parchment static).

## Edge Cases

Organized into 6 clusters: same-frame storms, ui_context lifecycle, locale, save/load, subscriber lifecycle, and pillar-violation guards.

### Cluster A — Same-frame signal storms

- **[E.1] Two guards emit `alert_state_changed` to non-UNAWARE on the same frame**: each goes through CR-9 rate-gate independently (per-actor dict, not global). Both fire ALERT_CUE — but only one can be active in the prompt-strip at a time (single Label slot). Resolution: the **first signal handler** wins (Godot signal dispatch order is registration order, deterministic); the second is suppressed (CR-9 still passes for the second guard, but the resolver's "active state" check rejects re-entry into the same priority slot). The second guard's ALERT_CUE is **dropped, not queued** — multiple-guard alarm is a section-wide event better signalled by ALARM_STINGER (which the §C.2 trigger gate detects).

- **[E.2] `alert_state_changed` and `document_collected` on the same frame**: priority resolver picks ALERT_CUE (priority 3) over MEMO_NOTIFICATION (priority 6). MEMO is queued in single-deep buffer with `queued_at_time = now`. After ALERT_CUE's 2.0 s Timer expires, MEMO activates IF `(now - queued_at_time) ≤ 1.0` s — typically NOT (2.0 - 0.0 > 1.0), so MEMO is **discarded**. The document is in the inventory (DC §C.5.4 lifecycle); the toast was a courtesy. **Acceptable**: pickup acknowledgment is a "nice-to-have", not authoritative.

- **[E.3] `respawn_triggered` and `alert_state_changed` on the same frame**: should never happen under CR-12 (HSS is freed on section unload before respawn re-instantiates, so HSS subscriber for `alert_state_changed` does not exist on the respawn frame). Defensive: if it did, ALERT_CUE preempts RESPAWN_BEAT (priority 3 < priority 5) — the alert state is more urgent than the respawn acknowledgment. On the post-respawn frame, RESPAWN_BEAT fires from the `respawn_triggered` signal because the new HSS instance subscribes during `_ready()`.

- **[E.4] `save_failed` and `respawn_triggered` on the same frame** (very rare — autosave at section_entered is a different code path from manual-save during gameplay): SAVE_FAILED preempts RESPAWN_BEAT (priority 4 < priority 5). RESPAWN_BEAT queued single-deep; if `(now - queued_at_time) ≤ 1.0` s when SAVE_FAILED's 4.0 s Timer expires, NO (4.0 > 1.0) — discarded. **Acceptable**: the save failure is more urgent advisory than the respawn acknowledgment; the respawn already happened (mechanically), the player just doesn't see the typographic note for it.

- **[E.5] CR-9 rate-gate dictionary lookup with freed actor Node**: per CR-9 cleanup, on each fire `is_instance_valid(actor) == false` triggers `dict.erase(actor)`. If a guard is freed mid-section (which shouldn't happen at MVP — guards are SAI-owned and don't free until section unload — but defensive against future Civilian AI integration if HSS ever subscribes to `civilian_panicked`), the dict entry is cleaned on next fire. No memory leak, no use-after-free (`is_instance_valid` is the canonical Godot 4.x freed-Node check).

- **[E.6] `_process()` dispatch order during state-transition frame**: HUD Core's `_process()` runs the resolver, calls HSS's `_resolve_hss_state()` callback, picks winner, mutates Label. HSS's signal handlers (e.g., `_on_alert_state_changed`) run BEFORE the next `_process()` because Godot's signal dispatch is synchronous from the publisher's `emit()` call (not deferred). So: signal arrives → HSS state mutates + Timer.start → next `_process()` frame the resolver picks up the new state. **No race**: Label mutation happens on the resolver frame, AccessKit announce on the same frame, all under one `_process()` tick.

### Cluster B — `ui_context_changed` lifecycle (CR-11)

- **[E.7] ALERT_CUE active when player opens Document Overlay (DOCUMENT_OVERLAY pushed)**: `ui_context_changed(DOCUMENT_OVERLAY, GAMEPLAY)` fires. HSS CR-11: stop active Timer, clear state. The label visibility is also handled by HUD Core CR-10 (HUD root hides on `new_ctx != GAMEPLAY`). When overlay closes (`ui_context_changed(GAMEPLAY, DOCUMENT_OVERLAY)`), HSS does NOT resume — the alert-cue moment is past. **Acceptable**: the player who opened a document while a guard alerted has implicitly chosen to look away; the resumed gameplay's alert state will surface again from the music (Audio is unaffected by the overlay) and from any subsequent `alert_state_changed` signal.

- **[E.8] `ui_context_changed` to LOADING during ALARM_STINGER**: section transition. HSS Timer stops, state clears. The new section's HSS instance starts at HIDDEN. **Acceptable**: alarm state was for the previous section; new section starts fresh.

- **[E.9] Rapid `ui_context_changed` pushes (push DOCUMENT_OVERLAY, push MODAL on top, pop both)**: HSS CR-11 fires on every `ui_context_changed` where `new != GAMEPLAY`. Multiple Timer-stop calls are idempotent (Timer.stop on a stopped Timer is a no-op). On pop back to GAMEPLAY: HSS does NOT resume any state. No corruption, no leftover Timer.

- **[E.10] HSS subscribes to `ui_context_changed` BEFORE `InputContext` autoload finishes its first `_ready()`**: per ADR-0007 canonical registration table, `InputContext` autoload (slot 4) runs `_ready()` before per-section nodes (HSS in `Section/Systems/HUDStateSignaling`) instantiate. So by the time HSS's `_ready()` runs, `Events.ui_context_changed` is a valid signal to connect to (it's declared in `Events.gd` per ADR-0002 amendment 2026-04-28; the autoload only owns the emit-site). **Race-free** by ADR-0007 ordering.

### Cluster C — Locale switch mid-display (CR-7)

- **[E.11] Player opens Settings, changes locale to FR while ALERT_CUE is active**: per CR-11, `ui_context_changed(SETTINGS, GAMEPLAY)` clears HSS state. So locale change happens on a HIDDEN HSS. On return to GAMEPLAY, no HSS state is active. If a new `alert_state_changed` fires post-locale-change, ALERT_CUE fires with FR translation — `_label.text = tr("HUD_GUARD_ALERTED")` resolves the FR string at render time per CR-7. **No locale-change re-resolve needed during display** because CR-11 already pre-empted the active state.

- **[E.12] If somehow a state IS active when locale changes** (defensive — e.g., if a future feature adds a "quick locale toggle" gameplay action that doesn't push `Context.SETTINGS`): HSS subscribes to `Object.NOTIFICATION_TRANSLATION_CHANGED` notification per Document Overlay UI's pattern. On notification: re-resolve `_label.text = tr(<active state's key>)`. The Timer is NOT restarted (the dismiss countdown continues from where it was). AccessKit `accessibility_description` is also re-resolved; AT may re-announce or not depending on its locale-change behavior (acceptable — locale change is an explicit user action, brief AT spam is less surprising than missed announcement).

- **[E.13] Translation key missing for current locale** (e.g., `HUD_DOCUMENT_COLLECTED` exists in EN, missing in FR-CA): `tr()` returns the key unchanged ("HUD_DOCUMENT_COLLECTED" raw). HSS does NOT special-case this — Localization Scaffold's CI lint catches missing keys per its own AC. The displayed raw key is a known fallback; QA catches it before ship.

### Cluster D — Save/Load

- **[E.14] Game saved while HSS state is active**: per CR-13, no HSS state is captured. SaveGame schema has no HSS sub-resource. On load: HSS starts at HIDDEN. Active state at save-time is **lost**. **Acceptable**: HSS is by definition transient; saving state would violate §B refusal #1 ("Not a notification" — notifications persist; margin notes don't).

- **[E.15] Game loaded into a section where the player was previously alarmed**: SAI restores its alert state per its own save/restore contract (§E.11 implicit-decay). HSS does NOT auto-fire ALARM_STINGER on load — the `alert_state_changed` signal does not re-fire on restore (SAI CR-12 LOAD_FROM_SAVE suppression). Player resumes in the alarmed state without HSS surfacing. The Audio alarm music should be active per Audio §LOAD_FROM_SAVE handler (Audio rebuilds its state from queries, not from HSS). **Acceptable**: player is in an alarm; the music says so; HSS does not need to also stamp the margin.

- **[E.16] `save_failed` fires during section transition (LS step 3 capture)**: per CR-11, HSS is suppressed if `ui_context_changed.new == LOADING` (section transition pushes LOADING per ADR-0004 amendment 2026-04-28). `save_failed` signal still fires; HSS subscriber is connected; but CR-11 has cleared HSS state and Timer. The signal handler runs but the state-entry path checks `_active_context == GAMEPLAY`; if false, suppress. So SAVE_FAILED is silently dropped during transition. **Acceptable**: the player doesn't see the advisory until they return to GAMEPLAY. If save_failed needs persistence past the transition, Save/Load's modal owns that path (CR-17 — blocking failures use Save/Load's modal, not HSS).

### Cluster E — Subscriber lifecycle

- **[E.17] HSS instance freed mid-Timer.timeout**: Godot Timer's `timeout` signal is bound to the HSS Node's method via `connect`. If the Node is `queue_free`'d during the Timer's wait, Godot auto-disconnects (target-bound Callable). The Timer is also a child of the HSS Node, so it's freed in the same tree-deletion. No use-after-free, no orphan callback.

- **[E.18] Player respawn triggered before previous respawn's RESPAWN_BEAT Timer expires** (rapid death loop — die in Bomb Chamber, respawn, die again at the same checkpoint): HSS instance is freed on section unload (RESPAWN reload section per F&R CR-4), so the in-flight Timer is destroyed with it. New section's new HSS instance fires RESPAWN_BEAT for the new respawn. **No double-Timer**, no state leak.

- **[E.19] `_exit_tree` runs while a state is active**: per CR-10, all signal disconnects + Timer.stop happen synchronously. AccessKit `accessibility_description` is cleared. The Label reference is dropped (the Label survives — HUD Core owns it; only HSS's reference is dropped). **No Label corruption** because HUD Core manages the Label's lifecycle independently.

- **[E.20] HUD Core is somehow not present when HSS `_ready()` runs** (defensive — should never happen because HUD Core is in the same section's `Section/Systems/HUDCore` per HUD Core CR-3 + section authoring contract): `HUDCore.get_prompt_label()` returns null. HSS `_ready()` MUST use an explicit null-guard, NOT `assert()` — `assert()` is debug-only in Godot 4.6 release builds (godot-specialist Finding 4). Pattern (REV-2026-04-28):
```gdscript
_label = HUDCore.get_prompt_label() if is_instance_valid(HUDCore) else null
if _label == null:
    push_error("HSS: HUD Core not present at _ready(); HSS disabled for this section.")
    set_process(false)
    return  # Skip all signal connects; HSS becomes inert rather than crashing on first dispatch.
```
**Defensive — should be CI-caught** by section validation lint requiring HUDCore as a sibling node.

### Cluster F — Pillar violation guards (CI-enforced)

- **[E.21] Designer accidentally adds an icon Unicode pictogram to a translation key value** (e.g., FR translation has "🔔 ALERTE" by mistake): FP-HSS-2 CI grep on translation table flags fail → build breaks. The grep regex matches typical emoji codepoint ranges. Resolution: re-translate without pictogram.

- **[E.22] Designer adds `accessibility_live = "assertive"` to ALARM_STINGER reasoning that it's "the most important state"**: FP-HSS-5 CI grep flags fail → build breaks. The Margin Note refuses to demand attention; the alarm-stinger is theatrical but not interruptive. Resolution: remove the assertive override. The paired Audio sting carries the urgency.

- **[E.23] Designer extends HSS with a 6th state for a future feature** (e.g., `BOSS_REMEMBERED_YOU` for Tier 3): adding a state requires (a) an entry in §C.2 States table, (b) priority assignment per CR-6, (c) ADR-0002 amendment if a new signal is needed, (d) translation keys per §V, (e) CI lint test for FP-HSS-6 (auto-dismiss ≤ 8.0 s). The §B "Margin Note" tonal anchor question must be answered: *"Does this read as a margin note, or as a notification?"* If it doesn't pass, the feature is rejected.

- **[E.24] HSS state-transition coincides with HUD Core's photosensitivity flash on the same frame** (REV-2026-04-28 — closes performance-analyst Finding 8: previous "statistically rare" claim was wrong): per F.4, no-pulse coincidence puts Slot 7 over cap by 11 µs; pulse-active coincidence over by 21 µs. **Coincidence frequency is NOT rare** — performance-analyst estimates ~40% per combat encounter (3 guards alerting + player taking damage simultaneously is a typical opening). **Permanent design (REV-2026-04-28)**: CR-14 deferred-AccessKit is implemented at Day-1 by default, not as a post-profile mitigation. Combined frame after default deferral: 296 µs (no pulse) or 306 µs (pulse active — 6 µs over, covered by ADR-0008 reserve carve-out). **Profile gate before MVP sprint** (OQ-HSS-4): `tests/integration/hud_state_signaling/test_slot7_coincidence_budget.gd` measures the worst case on Iris Xe **under Wayland + Orca active conditions** (performance-analyst Finding 6) and validates the carve-out delta.

- **[E.25] Designer attempts to surface an objective-marker via HSS** (e.g., adding a state for "Quest Updated: Find the Bomb"): FP-HSS-10 CI grep on translation keys flags fail → build breaks. The refusal is hard: HSS is not the back door for objective UI. If a future feature genuinely needs cross-section context to the player, it goes through Mission & Level Scripting's diegetic dialogue/document channels, not HSS. (Anti-pillar enforcement.)

## Dependencies

### F.1 Hard upstream dependencies

| System | Status | Contract HSS consumes |
|---|---|---|
| **HUD Core (#16)** | ✅ Approved 2026-04-26 | `HUDCore.get_prompt_label() -> Label` (UI-3 published API) + NEW `HUDCore.register_resolver_extension(Callable)` API (Coord item §F.5 #1) + NEW `HUDCore.get_health_label() -> Label` for VS CR-18 (Coord item §F.5 #2). HUD Core's CanvasLayer 1 hosts HSS scene path. HUD Core's §C.4 photosensitivity gate is absolute — HSS must NOT touch it. CR-22 Tween-kill on `ui_context_changed != GAMEPLAY` inherited (CR-11). |
| **Stealth AI (#10)** | ✅ Approved 2026-04-22 | `Events.alert_state_changed(actor: Node, old: AlertState, new: AlertState, severity: Severity)` (ADR-0002 frozen 4-param signature). HSS is a subscriber-only consumer. SAI's Severity enum is read for ALARM_STINGER trigger gate (`severity == MAJOR` for COMBAT entry). |
| **ADR-0002 Signal Bus + Event Taxonomy** | Proposed (2026-04-28 amendment landed) | 5 signal subscriptions: `alert_state_changed`, `document_collected`, `respawn_triggered`, `player_health_changed`, `save_failed`, `ui_context_changed` (the 6th, for CR-11 lifecycle). HSS owns ZERO signals. |
| **ADR-0004 UI Framework** | Proposed (Gates 1+2 OPEN; MODAL+LOADING enum amendment landed 2026-04-28) | Theme inheritance via `hud_theme.tres` (HUD Core owns); FontRegistry static class for font getters; AccessKit `accessibility_*` properties (Gate 1 verification pending — exact property names). InputContext.GAMEPLAY gate per CR-11. |
| **ADR-0007 Autoload Load Order Registry** | Accepted | HSS is NOT autoload (CR-2). InputContext autoload (slot per ADR-0007) runs `_ready()` before HSS's per-section instantiation, so `Events.ui_context_changed` is connectable when HSS connects. |
| **ADR-0008 Performance Budget Distribution** | Proposed (2026-04-28 amendment landed) | Slot 7 = 0.3 ms shared cap with HUD Core. HSS sub-claim: ≤0.05 ms steady-state, ≤0.15 ms peak (CR-14 + F.4). Reserve carve-out for combined HUD-Core-flash + HSS-transition coincidence (§E.24). |
| **Localization Scaffold (#7)** | Designed (pending review) | `tr()` for all visible strings (CR-7). NOTIFICATION_TRANSLATION_CHANGED handler per E.12. Translation keys listed in §V. |

### F.2 Soft upstream dependencies (VS only)

| System | Status | Contract HSS consumes (VS-only) |
|---|---|---|
| **Document Collection (#17)** | ✅ APPROVED 2026-04-27 → Needs Revision (per `/review-all-gdds` 2026-04-28) | `Events.document_collected(document_id: StringName)` for MEMO_NOTIFICATION trigger (CR-17 / §C.2). Reads `Document.title_key` via DC's existing `get_document_resource(id)` public method. **Closes DC OQ-DC-8 BLOCKING coord (VS).** |
| **Failure & Respawn (#14)** | ✅ Approved pending coord | `Events.respawn_triggered(section_id: StringName)` for RESPAWN_BEAT trigger. **Closes F&R OQ-FR-4 ADVISORY** (HSS owns the advisory line; F&R remains silent on the visual). |
| **Player Character (#8)** | ✅ Approved 2026-04-21 | `Events.player_health_changed(current: float, max: float)` for CR-18 critical-health pulse. Reads `player_critical_health_threshold` constant from registry (PC-owned, value `0.25`). |
| **Save / Load (#6)** | ✅ Approved pending re-review | `Events.save_failed(reason: SaveLoad.FailureReason)` for SAVE_FAILED state. Filters on `reason in {IO_ERROR, DISK_FULL_NON_CRITICAL}` per CR-17 (blocking failures route to Save/Load's modal, not HSS). |
| **Audio (#3)** | ✅ Approved 2026-04-21 | No direct contract — Audio and HSS are co-subscribers to the same source signals. Audio plays paired SFX; HSS shows the visual. They do not coordinate directly. |
| **Settings & Accessibility (#23)** | Designed pending review | (Optional — VS) If a future `accessibility.hud_alert_cue_enabled` toggle is added (see §Open Questions OQ-HSS-3), HSS subscribes `setting_changed("accessibility", _, _)`. **Day-1: no Settings dependency** — ALERT_CUE always fires. |

### F.3 Forward dependents

| System | Status | What depends on HSS |
|---|---|---|
| **HUD Core (#16)** | ✅ Approved 2026-04-26 | **HUD Core MVP is BLOCKED** until HSS Day-1 alert-cue minimal slice ships (HUD Core REV-2026-04-26 D3). HUD Core's WCAG 1.1.1 / 1.3.3 + EU GAAD compliance depends on HSS providing the visual alert-state cue. **NEW HUD Core APIs needed for HSS** (Coord items §F.5 #1 + #2). |
| **Document Collection (#17)** | APPROVED 2026-04-27 → Needs Revision | DC OQ-DC-8 (VS BLOCKING coord) — DC's pickup-toast handoff to HSS. **CLOSED by this GDD §C.2 + §C.5 contract**. |
| **Failure & Respawn (#14)** | Approved pending coord | F&R OQ-FR-4 (ADVISORY) — auto-save failed advisory ownership. **CLOSED by this GDD CR-17**. |
| **Mission & Level Scripting (#13)** | Needs Revision | MLS section authoring contract §C.5 should add HSS as a required system node sibling of HUDCore + DocumentCollection. (Coord item §F.5 #3.) |

### F.4 Forbidden non-dependencies (must NOT couple)

| System | Reason |
|---|---|
| Civilian AI (#15) | Pillar 5 zero-UI absolute (CAI's own constraint). HSS does NOT subscribe to `civilian_panicked` / `civilian_witnessed_event`. Civilian state is never surfaced in HUD. |
| Combat & Damage (#11) | HUD Core handles combat-domain signals (`weapon_fired`, `enemy_killed`, `gadget_activation_rejected`, `weapon_dry_fire_click`). HSS adding redundant subscriptions would violate CR-1 (no double-handling) and confuse the resolver. |
| Inventory & Gadgets (#12) | HUD Core handles inventory-domain signals (`gadget_equipped`, `gadget_used`, `weapon_switched`, `ammo_changed`). |
| Stealth AI's `actor_became_alerted` / `actor_lost_target` / `takedown_performed` / `guard_incapacitated` / `guard_woke_up` | HSS only consumes `alert_state_changed` (the canonical state-transition signal). The other AI-domain signals are perception-internal or audio-routed; HSS does not surface them. |
| Outline Pipeline / Post-Process Stack | HSS is a Label, not stenciled geometry, no shader interaction. |
| Document Overlay UI (#20) | HSS is suppressed during DOCUMENT_OVERLAY (CR-11). The two systems do not communicate; they sequence via InputContext. |
| Dialogue & Subtitles (#18, Designed 2026-04-28) | Subtitles are owned by Dialogue & Subtitles GDD #18 — separate Label on CanvasLayer 2 (LOCKED per dialogue-subtitles `subtitle_canvas_layer`). HSS and Subtitles do not share state, do not coordinate priority, do not occupy the same Label. |
| Cutscenes & Mission Cards (#22) | HSS is suppressed during cutscenes (CR-11 — cutscene InputContext). The two systems do not communicate. |
| Menu System (#21) | HSS is suppressed during MENU/PAUSE/SETTINGS (CR-11). Menu's case-officer POV (The Case File) is incompatible with HSS's in-scene Margin Note. |
| Save / Load directly via `SaveLoadService.*` autoload calls | HSS only consumes the `save_failed` Events signal. No direct call into Save/Load (no autoload-singleton-coupling). |

### F.5 Coordination items

**BLOCKING for MVP-Day-1 sprint** (must close before HUD Core MVP can ship):

1. **NEW HUD Core API: `register_resolver_extension(Callable) -> void`** (CR-4). HUD Core owns the prompt-strip resolver; HSS extends it via a registered callback. HUD Core's `_process()` invokes the callback to ask "what HSS state is active?". HUD Core author owns the API addition; HSS GDD declares the consumer contract here. **Owner**: HUD Core maintainer + ux-designer. **Target**: before HUD Core MVP sprint.

2. **NEW HUD Core API: `get_health_label() -> Label`** (VS — CR-18 critical-health pulse). HUD Core owns the health Label widget; HSS's CR-18 mutates `font_color` via this getter (NOT direct scene tree walk). **Owner**: HUD Core maintainer. **Target**: before VS sprint.

3. **MLS §C.5 section authoring contract amendment** — add `HUDStateSignaling` as a required sibling of `HUDCore` + `DocumentCollection` under `Section/Systems/`. CI lint per MLS §C.5.6: each `section_*.tscn` must contain `Section/Systems/HUDStateSignaling`. **Owner**: MLS maintainer. **Target**: before MLS sprint planning.

4. **Translation keys registration in Localization Scaffold** — 7 keys: `HUD_GUARD_ALERTED` (Day-1), `HUD_DOCUMENT_COLLECTED`, `HUD_ALARM_RAISED`, `HUD_RESPAWN`, `HUD_SAVE_IO_ERROR`, `HUD_SAVE_DISK_FULL`, plus an authoring guideline that HUD-domain keys follow period-clerical register (no exclamation marks except in advisory tone, no emoji, no decorative punctuation). **Owner**: Localization Scaffold maintainer + writer. **Target**: before MVP sprint.

5. **Profile gate `tests/integration/hud_state_signaling/test_slot7_coincidence_budget.gd`** (E.24) — measure HUD Core's photosensitivity-flash + HSS state-transition coincidence on Iris Xe Gen 12 reference scene. Validate ≤0.3 ms or apply CR-14 deferred-AccessKit mitigation. **Owner**: performance-analyst. **Target**: before MVP sprint sign-off.

**BLOCKING for VS sprint** (do not block MVP):

6. **DC OQ-DC-8 closure**: DC GDD must reference this HSS GDD as the consumer of `document_collected` for MEMO_NOTIFICATION. **Status**: ✅ already documented in DC §F.5 OQ-DC-8 — closed by HSS §C.5 + §F.3.

7. **F&R OQ-FR-4 closure**: F&R GDD's OQ-FR-4 advisory line should reference this HSS GDD as the implementer. **Status**: ✅ already documented in F&R §378 — closed by HSS CR-17.

**ADVISORY**:

8. **Settings & Accessibility — optional `hud_alert_cue_enabled` toggle** (OQ-HSS-3): if Settings adds this toggle in a future iteration, HSS subscribes and gates ALERT_CUE rendering. **Owner**: Settings maintainer + UX. **Target**: post-launch if user research surfaces the need (rare — most HoH users want the cue ON; toggle is a power-user feature).

9. **Audio Concurrency Rule for HSS-paired cues** — verify Audio's existing handlers for `document_collected` / `respawn_triggered` / `save_failed` produce SFX that don't conflict with HSS visual timing (e.g., the pickup chime should fire ~0.1 s before MEMO_NOTIFICATION's Label flash for sensory alignment). **Owner**: Audio maintainer + sound-designer. **Target**: VS playtest validation.

10. **`/asset-spec system:hud-state-signaling`** — generate per-state visual specs once Art Bible §7D is approved. HSS owns no new assets at MVP (uses HUD Core's existing Label/StyleBoxFlat); VS may need 1-2 SFX spec files referenced from Audio. **Owner**: art-director. **Target**: before VS asset production.

### F.6 Bidirectional consistency check

| Upstream/Downstream GDD | Consistency assertion | Status |
|---|---|---|
| HUD Core §UI-3 declares `get_prompt_label()` as the single forward extension | HSS §C.5 + §F.1 cite this as the only API | ✅ aligned |
| HUD Core §C.5 lists HSS as forward dep "HARD MVP DEP per D3" | HSS §F.3 reciprocates and CR-19 names the Day-1 slice scope | ✅ aligned |
| HUD Core CR-22 mandates Tween.kill on ui_context_changed != GAMEPLAY (added 2026-04-28) | HSS CR-11 inherits | ✅ aligned |
| DC §F.5 OQ-DC-8 BLOCKING coord (VS) — HSS subscribes document_collected | HSS §F.2 + §C.5 row + §C.2 trigger | ✅ aligned (closes OQ-DC-8) |
| DC §C.5 lists "the pickup-toast widget" as HSS-owned | HSS CR-17 (note: this maps to MEMO_NOTIFICATION, CR-17 is for save_failed; MEMO_NOTIFICATION is CR-2 row) — corrected: MEMO_NOTIFICATION rules in §C.2 row + DC OQ-DC-8 closure | ✅ aligned |
| F&R §F.5 + §378 (OQ-FR-4) — HSS owns the auto-save-failed advisory | HSS CR-17 | ✅ aligned (closes OQ-FR-4) |
| F&R §254 lists HSS as indirect dep via player_health_changed | HSS CR-18 (VS, critical-health pulse) | ✅ aligned |
| ADR-0002 6 subscriptions cited (alert_state_changed + document_collected + respawn_triggered + player_health_changed + save_failed + ui_context_changed) | HSS §F.1 + §F.2 enumerates same set | ✅ aligned |
| ADR-0004 InputContext enum (GAMEPLAY + post-2026-04-28 MODAL/LOADING) | HSS CR-11 gates on GAMEPLAY only | ✅ aligned |
| ADR-0008 Slot 7 = 0.3 ms shared cap | HSS CR-14 + F.4 sub-claim | ✅ aligned (mitigation path documented) |
| Settings CR-2 single canonical home `accessibility` | HSS subscribes to `setting_changed("accessibility", _, _)` only (VS) | ✅ aligned |
| Audio §State table — DOCUMENT_OVERLAY duck rule (post-2026-04-28 amendment via review report) | HSS does NOT control Audio; Audio is sibling-subscriber | ✅ aligned (sibling pattern) |

## Tuning Knobs

### G.1 HSS-owned (Tier 1 — designer-tunable per playtest)

| Knob | Default | Safe range | Owner | Notes |
|---|---|---|---|---|
| `alert_cue_duration_s` | **2.0** | [1.5, 3.0] | HSS | ALERT_CUE auto-dismiss (CR-19 / F.1 / §C.2). Below 1.5: too brief to read at 14 px. Above 3.0: starts to read as a notification (FP-HSS-6 hard cap 8.0). |
| `memo_notification_duration_s` | **3.0** | [2.0, 4.5] | HSS | MEMO_NOTIFICATION auto-dismiss (VS only). Above 4.5 overlaps typical pickup→Document Overlay open flow (~1-2 s). |
| `alarm_stinger_duration_s` | **3.0** (REV-2026-04-28) | [2.5, 4.0] | HSS | ALARM_STINGER auto-dismiss (VS only). Reduced from 5.0 per §B Margin Note carve-out + AT delivery floor. Designated exception to Margin Note — but the visual surface still respects the brief-moment anchor; the carve-out is in *AccessKit prominence and priority preemption*, not duration. |
| `respawn_beat_duration_s` | **1.5** | [1.0, 2.5] | HSS | RESPAWN_BEAT auto-dismiss (VS only). Quietest — the player just respawned and action is resuming. Above 2.5 dwells on failure (anti-Pillar 3). |
| `save_failed_duration_s` | **4.0** | [3.0, 6.0] | HSS | SAVE_FAILED auto-dismiss (VS only). Slightly longer because the player may want to glance at it. Above 6.0 reads as sustained warning. |
| `alert_cue_actor_cooldown_s` | **1.0** | [0.5, 2.0] | HSS | CR-9 per-actor rate-gate window (F.3). Below 0.5 risks ALERT_CUE flicker on SAI perception oscillation. Above 2.0 risks suppressing legitimate re-alerts. |
| `queued_state_max_age_s` | **5.0** (REV-2026-04-28 — was 1.0) | [3.0, 6.0] | HSS | Single-deep buffer freshness window (§C.3). Raised to match longest auto-dismiss (`alarm_stinger_duration_s = 3.0` s + ALERT_CUE 2.0 s headroom) to close systems-designer Finding 2 — previously, ANY state queued behind ALARM_STINGER was structurally discarded because 1.0 < 5.0. Now: any lower-priority state queued at `t=0` survives until ALARM_STINGER's Timer expires + 2.0 s buffer freshness check. Below 3.0 risks the original Finding 2 silently dropping advisory states. Above 6.0 risks a queued state activating after the player has shifted gameplay context. |

### G.2 Inherited from upstream GDDs (HSS reads, does NOT define)

| Knob | Source GDD | Notes |
|---|---|---|
| `clock_tick_period_s` | Audio §F.4 | CR-18 critical-health pulse period (F.5). HSS reads from registry; tuning lives in Audio. |
| `player_critical_health_threshold` | Player Character §Tuning Knobs | CR-18 trigger threshold (default 0.25). HSS reads from PC's accessor. |
| `hud_damage_flash_cooldown_ms` | HUD Core §G | 333 ms photosensitivity rate-gate. HSS does NOT bypass (FP-HSS-9). |
| `hud_canvas_layer_index` | HUD Core §G | CanvasLayer 1. HSS shares root. |

### G.3 ADR-locked (CANNOT be tuned without ADR amendment)

| Constant | Value | Source | Notes |
|---|---|---|---|
| ADR-0008 Slot 7 cap | **0.3 ms** (Iris Xe) shared with HUD Core | ADR-0008 | HSS sub-claim 0.05 ms steady / 0.15 ms peak (CR-14 / F.4). |
| `auto_dismiss_max_s` | **8.0** | FP-HSS-6 | Absolute cap on any HSS state's auto-dismiss. Beyond this, the surface is a notification (forbidden). |
| ADR-0002 signal signatures | locked per ADR-0002 §Key Interfaces | ADR-0002 | HSS subscribes to canonical signatures; any change requires ADR-0002 amendment. |
| ADR-0004 InputContext enum | `{GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, SETTINGS, MODAL, LOADING}` | ADR-0004 (post-2026-04-28 amendment) | HSS gates on `Context.GAMEPLAY` only (CR-11). |

### G.4 Pillar 5 absolutes (NOT tunable — reductio ad pillarem)

| Absolute | Why |
|---|---|
| **No icons / pictograms / emoji in HSS text** | FP-HSS-2; period-typographic register; Margin Note refusal #2 ("Not a banner"). |
| **No `accessibility_live = "assertive"`** | FP-HSS-5; Margin Note refusal — never demand attention. |
| **No graphics widgets (ColorRect, NinePatchRect, TextureRect) under HSS** | FP-HSS-1 + CR-15; HSS draws zero new visual elements. |
| **No `_process` / `_physics_process` overrides** | FP-HSS-4 + CR-5; Slot 7 budget compliance via Timer-only dispatch. |
| **No emit calls** (HSS is subscriber-only) | FP-HSS-8 + CR-1; sole-publisher discipline mirrored from HUD Core CR-19. |
| **No objective/waypoint/quest-tracker text** | FP-HSS-10 + game-concept anti-pillar (no modern UX paternalism). |
| **No XP/achievement/level-up text** | FP-HSS-11 + game-concept anti-pillar (no XP / skill trees). |
| **No bypass of HUD Core's photosensitivity gate** | FP-HSS-9 + CR-15; HUD Core §C.4 absolute. |
| **No Tween that survives `ui_context_changed != GAMEPLAY`** | CR-11 + HUD Core CR-22. |

### G.5 Tuning ownership matrix

| Tuner | Surface they tune |
|---|---|
| **Game-designer** | All G.1 knobs (auto-dismiss durations, rate-gate cooldown, queue freshness window). |
| **Localization-lead** | All translation key values (per-locale). |
| **Audio-director** | `clock_tick_period_s` (drives F.5 pulse period through registry read). |
| **Performance-analyst** | Slot 7 sub-claim measurement gate; if measurement fails, recommends CR-14 deferred-AccessKit mitigation OR escalates to ADR-0008 amendment. |
| **Art-director** | Visual register details in §V (StyleBoxFlat owned by HUD Core; HSS inherits). |
| **Accessibility-specialist** | AccessKit polite-vs-assertive policy (locked at polite per CR-8 + FP-HSS-5; any future relax requires accessibility-specialist sign-off + ADR amendment). |

## Visual/Audio Requirements

### V.1 Visual register (HUD Core inherited)

HSS owns **zero new visual assets**. Every visible HSS surface is a `_label.text` mutation on HUD Core's existing prompt-strip Label, in HUD Core's existing StyleBoxFlat (BQA Blue strip + Parchment text per Art Bible §7D + §4.4). The single exception is the CR-18 critical-health `font_color` tween, which mutates a property on HUD Core's existing health Label — still no new asset.

| Visual property | Owner | HSS interaction |
|---|---|---|
| Prompt-strip Label node | HUD Core §C.2 | HSS writes `text` only via `get_prompt_label()` (CR-3) |
| Prompt-strip StyleBoxFlat (BQA Blue strip) | HUD Core §V | HSS does not mutate |
| Prompt-strip font (Futura Condensed Bold @ 14 px per HUD Core §C.2) | FontRegistry (ADR-0004) | HSS does not override |
| Prompt-strip fade-in/fade-out animation (0.15 s per HUD Core §V.4) | HUD Core §V.4 | HSS triggers fade by causing `_label.visible` toggle through resolver — HUD Core handles the actual tween |
| Health Label `font_color` (CR-18 pulse) | HUD Core §C.2 | HSS tweens via `get_health_label() -> Label` (NEW HUD Core API §F.5 #2). Pulse tweens between Parchment `#E8DFC8` and Alarm Orange (Art Bible §4.4) at `clock_tick_period_s = 0.6`. |

### V.2 Translation keys (Localization Scaffold)

HSS owns 7 translation keys (1 for MVP-Day-1, 6 for VS):

| Key | Tier | EN reference value | Notes for translators |
|---|---|---|---|
| `HUD_GUARD_ALERTED` | **MVP-Day-1** | `"GUARD ALERTED"` | Brief, declarative, present-tense passive. Period-clerical register. No exclamation mark — this is a bureaucratic acknowledgment, not an alarm. ≤20 characters target (UI width budget at 14 px ~24 chars). |
| `HUD_DOCUMENT_COLLECTED` | VS | `"DOCUMENT FILED"` | Present-tense passive, period-bureaucratic. Composes with document title via `" — "` separator: "DOCUMENT FILED — 'Memo Re: Tower Sanitation'". The literal "DOCUMENT FILED" is fixed; the title comes from `Document.title_key` (Writer-owned per DC writer brief). |
| `HUD_ALARM_RAISED` | VS | `"ALARM RAISED"` (REV-2026-04-28 — shortened from "ALARM RAISED — TOWER LOCKDOWN" for ≤18-char locale headroom per ux-designer Finding 4) | Section-wide alarm onset. Period-theatrical register. The location-clause ("TOWER LOCKDOWN") was removed because German +30% expansion would exceed the 24-char prompt-strip width budget; the gameplay-critical information is "ALARM RAISED" alone. The location is conveyed through Audio's alarm music and SAI alert state. |
| `HUD_RESPAWN` | VS | `"OPERATION RESUMED"` | Single line, declarative, no acknowledgment of failure. Pairs with F&R "Eve does not die well" framing — quiet, professional, the operation continues. |
| `HUD_SAVE_IO_ERROR` | VS | `"ARCHIVAL ERROR — RETRY"` | The clerk apologizing for paperwork trouble. The em-dash separates the failure from the advice. No "FAILED" or "ERROR CODE 0x..." — period register avoids modern system-error language. |
| `HUD_SAVE_DISK_FULL` | VS | `"ARCHIVAL FULL — CHECK STORAGE"` | Same register. "CHECK STORAGE" is the period-appropriate equivalent of "free up disk space". |

**Authoring guidelines for HUD-domain translation keys** (will be added to Localization Scaffold's authoring guideline per Coord item §F.5 #4):

- Period-clerical register: bureaucratic-deadpan, present-tense passive when describing events ("FILED", "RAISED", "RESUMED"), advisory-imperative when prompting action ("RETRY", "CHECK STORAGE").
- ≤24 characters target per line at 14 px (the prompt-strip width budget per HUD Core §C.2). Composed strings (MEMO_NOTIFICATION's `tr() + " — " + tr()`) may exceed this — Label uses `autowrap_mode = AUTOWRAP_OFF` and `clip_text = true` per HUD Core §C.2; titles >40 chars truncate gracefully.
- No exclamation marks (Margin Note refusal — never demand).
- No emoji, no Unicode pictograms (FP-HSS-2).
- No system-error language (no error codes, no stack traces, no internal IDs).
- All-caps for declarative states (FILED, RAISED, RESUMED, ALERTED) matching NOLF1 HUD typographic convention.
- Mixed-case acceptable for object titles inside composed strings ("Memo Re: Tower Sanitation" is the document's title verbatim, not all-caps).

### V.3 Color palette (HUD Core inherited; CR-18 specific)

| Element | Color | Source |
|---|---|---|
| Prompt-strip background | BQA Blue 85% opacity (Art Bible §4.4) | HUD Core inherited |
| Prompt-strip text | Parchment `#E8DFC8` | HUD Core inherited |
| Health numeral default | Parchment `#E8DFC8` | HUD Core inherited |
| Health numeral critical pulse | Alarm Orange (Art Bible §4.4 — exact hex pending art-director confirm during HUD Core sprint) | HUD Core §V; HSS tweens via `font_color` mutation only |

### V.4 Animation timeline (CR-18 pulse only)

The critical-health pulse tween:

```text
Parchment ──linear──> Alarm Orange ──linear──> Parchment
   t=0                      t=0.3 s                  t=0.6 s
                                                     (period restarts)
```

`Tween.tween_property(_health_label, "font_color", Alarm_Orange, 0.3)`
`.tween_property(_health_label, "font_color", Parchment, 0.3)`
Looped via `set_loops(0)` (infinite). Killed on:
- `current / max > player_critical_health_threshold` (PC signal subscription)
- `Events.player_died` fires
- `Events.ui_context_changed.new != GAMEPLAY` (CR-11 — HUD hides anyway)
- HSS `_exit_tree` (CR-10)

**No other animations** beyond HUD Core's existing fade-in/fade-out on the prompt-strip Label visibility transition.

### V.5 Forbidden visuals (CR-15 + FP-HSS-1..11 cross-reference)

- **No** ColorRect / NinePatchRect / TextureRect children under HSS scene tree.
- **No** icons / pictograms / decorative glyphs in Label text.
- **No** banner widgets above the prompt-strip.
- **No** dedicated "alert state HUD bar" or "guard awareness meter" anywhere.
- **No** above-head guard indicator (`!`, `?`, alert ring, exclamation mark popup) — this is the Pillar 5 absolute that game-concept §Visual Identity Anchor names directly.
- **No** minimap, no compass, no waypoint marker, no objective marker.
- **No** kill cam, no death screen, no "You Died" text.
- **No** XP toast, no level-up flash, no achievement popup.
- **No** quest-update banner, no "Quest Updated" text.
- **No** screen-edge red vignette (HUD Core §C.4 photosensitivity gate is absolute; HSS does NOT extend it).
- **No** screen shake on alarm-stinger or respawn-beat.
- **No** chromatic aberration / film grain / vignette as state cue (Pillar 5 — no modern post-process effects on HSS triggers).

### A.1 Audio handoff (HSS does NOT play audio; sibling pattern)

HSS owns **zero audio assets**. Every HSS visual state has a paired Audio cue that **Audio subscribes to the same source signal** (sibling-subscriber pattern, NOT HSS triggering Audio):

| HSS state | Source signal | Audio's pairing | Audio handler owner |
|---|---|---|---|
| ALERT_CUE | `alert_state_changed` | Alert sting (already specified in Audio §AI/Stealth domain handler table) | Audio §B.1 / handler table |
| MEMO_NOTIFICATION | `document_collected` | Pickup chime (Audio §Documents domain handler — already specified) | Audio §A.1 / handler table |
| ALARM_STINGER | `alert_state_changed` (severity MAJOR + COMBAT entry) | Alarm sting (Audio §Music — section-wide alarm music transition) | Audio §F.4 |
| RESPAWN_BEAT | `respawn_triggered` | Quiet typewriter clack + scene-change tone (Audio §F&R domain handler — already specified) | Audio §A.6 |
| SAVE_FAILED | `save_failed` | Subtle advisory cue (Audio §Persistence domain handler — already specified) | Audio §A.7 |
| Critical-health pulse (CR-18) | `player_health_changed` (current/max ≤ threshold) | Clock-tick (Audio §F.4 — already specified) | Audio §F.4 |

**Sequencing concern (Coord item §F.5 #9 ADVISORY)**: HSS visual onset and Audio cue onset should align within ~50 ms for sensory unity. Both are signal-driven from the same source, so timing is roughly synchronized; if profiling reveals consistent misalignment (e.g., Audio's bus latency adds 80 ms), HSS may apply a `call_deferred` on its state-entry to sync. **Owner**: sound-designer + performance-analyst playtest validation. **Target**: VS playtest sign-off.

### A.2 Forbidden audio coupling

- **HSS does NOT play audio**. No `AudioStreamPlayer`, no `play()` calls, no AudioServer interaction.
- **HSS does NOT trigger Audio**. Audio is a co-subscriber to the same source signals; HSS and Audio are siblings.
- **HSS does NOT receive Audio signals**. There is no "the chime finished playing, now show the toast" coupling — the visual fires from the source signal at the same moment Audio's cue does, independently.

This is the cleanest sibling-subscriber pattern: source signal fires → both Audio and HSS handle it → no cross-coupling between subscribers, no signal-pingpong, no synchronization layer needed beyond the natural same-frame dispatch order.

### A.3 Asset Spec Flag

> 📌 **Asset Spec** — HSS owns no new visual assets at MVP and VS (uses HUD Core's existing Label, StyleBoxFlat, FontRegistry). After Art Bible §7D is approved and HUD Core's StyleBoxFlat is finalized, run `/asset-spec system:hud-state-signaling` to produce the per-state visual spec sheet (recommended for QA test fixtures and screenshot-evidence templates) — even though HSS owns zero new assets, the asset-spec doc serves as the QA visual reference. Per F.5 #10 ADVISORY.

## UI Requirements

HSS *is* a UI system, but its surface is wholly contained within HUD Core's Label widget. This section is a **meta-section** documenting the public contract HSS publishes (none — HSS is consumer-only) and the contract HSS consumes from HUD Core, plus the AccessKit semantics and the UX Flag.

### UI-1 — HSS owns ZERO rendered widgets of its own

Every HSS state is a `_label.text` mutation on HUD Core's existing prompt-strip Label (or for CR-18, a `font_color` tween on HUD Core's existing health Label). HSS contains no `Control` children (Timer nodes are non-visual). HSS does not inherit, override, or extend any Theme. HUD Core's `hud_theme.tres` (which inherits `project_theme.tres` per ADR-0004) is the styling source; HSS reads through HUD Core's published API only.

### UI-2 — Public extension contract (consumed from HUD Core, NOT published by HSS)

| Method | Owner | Purpose | Status |
|---|---|---|---|
| `HUDCore.get_prompt_label() -> Label` | HUD Core (existing per UI-3) | HSS reads to mutate `text` | ✅ existing |
| `HUDCore.register_resolver_extension(callback: Callable) -> void` | HUD Core (NEW per Coord item §F.5 #1) | HSS registers its `_resolve_hss_state()` callback at `_ready()` | ⏳ NEW HUD Core API needed |
| `HUDCore.get_health_label() -> Label` | HUD Core (NEW per Coord item §F.5 #2; VS only) | HSS reads to tween `font_color` for CR-18 critical-health pulse | ⏳ NEW HUD Core API needed (VS only) |

**HSS publishes ZERO public methods**. There is no HSS API for other systems to consume. HSS is a leaf consumer — signals in, no methods out. (Justification: §B Margin Note refusal #1 ("Not a notification") + CR-1 sole-publisher discipline. Other systems should never need to "ask HSS what state is active" — that information is private to HSS and HUD Core's resolver.)

### UI-3 — AccessKit semantics

| Property | Value | Notes |
|---|---|---|
| `accessibility_role` | (inherited from HUD Core's Label — typically "label" or pending Gate 1 verification on exact API) | HSS does NOT override |
| `accessibility_description` | `tr(<active state's key>)` (the same text shown visually) | Set on state-entry; cleared on state-exit |
| `accessibility_live` | `"polite"` (CR-8) — NEVER `"assertive"` (FP-HSS-5) | The Margin Note refuses to demand attention; AT announces in the natural pause between user actions |
| `accessibility_name` | (none — Label is the readable element; no name override) | HSS does NOT override |

**AT announce timing**: Godot 4.5+ AccessKit emits an announcement to the screen reader when `accessibility_description` changes on a `_label.visible == true` Control with `accessibility_live` set. HSS state-entry mutates `_label.text`, sets `_label.accessibility_description`, then makes the Label visible (HUD Core's resolver toggles visibility based on the winner). The announce fires once per state-entry. On state-exit (Timer.timeout or preemption), `_label.accessibility_description` is cleared to prevent re-announce on next focus.

**Locale change** (E.12): on `NOTIFICATION_TRANSLATION_CHANGED`, both `_label.text` and `_label.accessibility_description` re-resolve via `tr()`. AT may re-announce; acceptable per E.12.

### UI-4 — Pillar absolutes restated

(Restated from CR-15 + FP-HSS-1..11 + V.5 for UI integrators):

- **No new Control children under HSS** — Timer nodes only.
- **No icons in Label text** — period-typographic register, no decorative glyphs.
- **No banner widgets** — single Label discipline.
- **No `assertive` AccessKit** — Margin Note refuses to demand.
- **No bypass of HUD Core's photosensitivity gate** — HSS has no flash, no flicker, no rapid state-changes (CR-9 rate-gate prevents this).
- **No objective UI / minimap / compass / quest tracker** — anti-pillar.
- **No XP / progression / achievement / level-up surfaces** — anti-pillar.

### UI-5 — UX Flag for Phase 4 (Pre-Production)

> 📌 **UX Flag — HUD State Signaling**: This system has UI requirements, even though it owns zero widgets. In Phase 4 (Pre-Production), run `/ux-design design/ux/hud-state-signaling.md` to create a UX spec covering:
> - Visual specifications per state (text content, exact pixel timing of fade-in/out, paired Audio cue alignment)
> - Accessibility walkthrough per WCAG 1.1.1 / 1.3.3 + EU GAAD compliance
> - Localization preview tests (FR / DE / IT length variants — German typically runs 30%+ longer than English; "ALARM RAISED — TOWER LOCKDOWN" ≈ 24 chars EN may exceed the 24-char prompt-strip width budget in DE — Localization Scaffold authoring guideline must verify per-locale)
> - Per-state QA screenshot test fixtures (each of the 5 VS states requires a manual evidence screenshot for `production/qa/evidence/`)
> - Coordination with HUD Core's UX spec (HUD Core's `/ux-design hud-core` produces `design/ux/hud-core.md`; HSS's UX spec extends it)
>
> Stories that reference HSS UI should cite `design/ux/hud-state-signaling.md`, not this GDD directly. **Owner**: ux-designer + accessibility-specialist. **Target**: Phase 4 (Pre-Production), before HUD Core MVP sprint planning closes.

### UI-6 — Forward-dep notes for downstream UI systems

| Downstream system | Note |
|---|---|
| Document Overlay UI (#20) | HSS is suppressed during DOCUMENT_OVERLAY (CR-11). Overlay does not need to coordinate with HSS — InputContext mediates. |
| Menu System (#21) | Same — HSS suppressed during MENU/PAUSE/SETTINGS/MODAL. Menu does not need to coordinate with HSS. |
| Cutscenes & Mission Cards (#22, Not Started) | When Cutscenes pushes its InputContext at cutscene start (cutscene context — Cutscenes GDD owns when authored), HSS auto-suppresses via CR-11. No direct coordination needed. |
| Dialogue & Subtitles (#18, Designed 2026-04-28) | Subtitles are owned by Dialogue GDD #18 — separate Label on CanvasLayer 2 (LOCKED per dialogue-subtitles `subtitle_canvas_layer`). HSS and Subtitles do not share state, do not coordinate priority, do not occupy the same Label. The two systems are wholly independent at the UI layer. |

## Acceptance Criteria

ACs are organized in 9 clusters: subscriber lifecycle, ALERT_CUE (Day-1 BLOCKING), state machine + priority resolver, auto-dismiss timing, locale + AccessKit, ui_context + Tween-kill, save/load transient discipline, performance budget, forbidden-pattern CI lints. **Day-1 ACs** (BLOCKING for HUD Core MVP) are tagged separately. **VS ACs** are BLOCKED-on individual VS-tier feature stories.

### Cluster 1 — Subscriber lifecycle (Day-1 BLOCKING + VS)

- **AC-HSS-1.1 [Logic] [BLOCKING Day-1]** **GIVEN** the section is loaded and `Section/Systems/HUDStateSignaling` is in the scene tree, **WHEN** HSS `_ready()` runs, **THEN** `Events.alert_state_changed` is connected to `_on_alert_state_changed` exactly once (verified via `Events.alert_state_changed.is_connected(...)` returning true and `Events.alert_state_changed.get_connections().filter(...).size() == 1`). `[CR-10]` Evidence: `tests/unit/hud_state_signaling/test_subscriber_lifecycle.gd`

- **AC-HSS-1.2 [Logic] [BLOCKING VS]** **GIVEN** an HSS instance with all 6 VS subscriptions connected, **WHEN** the parent section is unloaded (`queue_free()` propagates to HSS), **THEN** `_exit_tree()` runs AND all 6 signal subscriptions are disconnected (each `is_connected` returns false post-disconnect) AND `_alert_cue_last_fired_per_actor` dictionary is cleared (`size() == 0`) AND any active state Timer is `stop()` and `queue_free()`'d. `[CR-10]` Evidence: `tests/unit/hud_state_signaling/test_subscriber_lifecycle.gd`. **BLOCKED-on**: VS sprint.

- **AC-HSS-1.3 [Integration] [BLOCKING Day-1]** **GIVEN** HUD Core is in the scene tree at `Section/Systems/HUDCore` (per MLS section authoring contract §C.5), **WHEN** HSS `_ready()` runs, **THEN** `HUDCore.get_prompt_label()` returns a non-null Label reference AND HSS holds it as `_label` AND `HUDCore.register_resolver_extension(_resolve_hss_state)` is called exactly once. `[CR-3, CR-4]` Evidence: `tests/integration/hud_state_signaling/test_hud_core_handshake.gd`. **BLOCKED-on**: HUD Core's NEW APIs landing per Coord items §F.5 #1.

- **AC-HSS-1.4 [Integration] [BLOCKING Day-1]** (NEW REV-2026-04-28 — closes godot-specialist Finding 3 + qa-lead Finding 3 / E.19 coverage) **GIVEN** HSS instance with active resolver-extension registration, **WHEN** the parent section is unloaded (`queue_free()` propagates), **THEN** `_exit_tree()` calls `HUDCore.unregister_resolver_extension(_resolve_hss_state)` exactly once AND HUD Core's resolver-extension array no longer contains the dead Callable. Verified via post-unload inspection: `HUDCore._resolver_extensions.size()` decreases by exactly 1. `[CR-4 REV-2026-04-28, CR-10 REV-2026-04-28]` Evidence: `tests/integration/hud_state_signaling/test_section_unload.gd`

- **AC-HSS-1.5 [Logic] [BLOCKING Day-1]** (NEW REV-2026-04-28 — closes qa-lead Finding 3 / E.18 coverage) **GIVEN** ALERT_CUE active with Timer.time_left == 1.5 s, **WHEN** the player dies AND respawns, **THEN** the section is freed (HSS instance freed; in-flight Timer destroyed with it); the new section's new HSS instance starts with empty rate-gate dicts AND no active Timer; if a new alert event fires post-respawn, ALERT_CUE fires fresh with no double-Timer. `[CR-12, E.18]` Evidence: `tests/integration/hud_state_signaling/test_respawn_loop.gd`

### Cluster 2 — ALERT_CUE (Day-1 BLOCKING — minimal slice)

- **AC-HSS-2.1 [Logic] [BLOCKING Day-1]** **GIVEN** an UNAWARE guard `G1`, no ALERT_CUE active, `_alert_cue_last_fired_per_actor` empty, **WHEN** `Events.alert_state_changed.emit(G1, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)` fires, **THEN** within the same physics frame: `_label.text == tr("HUD_GUARD_ALERTED")` AND `_alert_cue_timer.time_left == alert_cue_duration_s` (default 2.0) AND `_alert_cue_timer.is_stopped() == false` AND `_alert_cue_last_fired_per_actor[G1] == game_time` AND `_label.accessibility_live == "polite"` AND `_label.accessibility_description == tr("HUD_GUARD_ALERTED")`. `[CR-5, CR-7, CR-8, CR-9, F.1, F.3]` Evidence: `tests/unit/hud_state_signaling/test_alert_cue.gd`

- **AC-HSS-2.2 [Logic] [BLOCKING Day-1]** **GIVEN** ALERT_CUE just fired for G1 at game_time `T_0`, **WHEN** `Events.alert_state_changed.emit(G1, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)` fires again at `T_0 + 0.5` s, **THEN** ALERT_CUE does NOT re-fire (Timer.time_left is unchanged from natural decrement; `_label.text` unchanged from already-set value; no new AccessKit announce queued). `[CR-9, F.3]` Evidence: `tests/unit/hud_state_signaling/test_rate_gate.gd`

- **AC-HSS-2.3 [Logic] [BLOCKING Day-1]** **GIVEN** ALERT_CUE last fired for G1 at game_time `T_0`, **WHEN** `Events.alert_state_changed.emit(G1, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)` fires again at `T_0 + 1.5` s (>cooldown), **THEN** ALERT_CUE fires fresh (Timer restarted with `time_left == 2.0`; `_alert_cue_last_fired_per_actor[G1] == T_0 + 1.5`; new AccessKit announce queued). `[CR-9, F.3]` Evidence: `tests/unit/hud_state_signaling/test_rate_gate.gd`

- **AC-HSS-2.4 [Logic] [BLOCKING Day-1]** **GIVEN** ALERT_CUE just fired for G1, **WHEN** `Events.alert_state_changed.emit(G2, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)` fires for a *different* guard `G2` at `T_0 + 0.5` s (within G1's cooldown but G2 is a different actor), **THEN** ALERT_CUE for G2 fires (per-actor gate, NOT global) — but only one Label slot, so the resolver's "active state" check determines whether the visual updates. The AC verifies the rate-gate logic (G2's entry passes CR-9), not the resolver outcome (which is separately tested in Cluster 3). Specifically: `_alert_cue_last_fired_per_actor[G2] == T_0 + 0.5` AND `should_fire_for_G2 == true`. `[CR-9, F.3]` Evidence: `tests/unit/hud_state_signaling/test_rate_gate_per_actor.gd`

- **AC-HSS-2.5 [Logic] [BLOCKING Day-1]** **GIVEN** ALERT_CUE active, **WHEN** `_alert_cue_timer.timeout` fires (at `T_0 + 2.0` s), **THEN** the active state clears to HIDDEN AND HUD Core's resolver re-evaluates (`_label.visible == false` if no other state is active, `_label.text` may be cleared or unchanged depending on HUD Core's hide implementation) AND `_label.accessibility_description` is cleared (empty string or null). `[CR-5, CR-8]` Evidence: `tests/unit/hud_state_signaling/test_auto_dismiss.gd`

- **AC-HSS-2.6 [Logic] [BLOCKING Day-1]** **GIVEN** any UNAWARE → SUSPICIOUS transition, **WHEN** `alert_state_changed` fires with `new == AlertState.UNAWARE`, **THEN** ALERT_CUE does NOT fire (state-gate: only non-UNAWARE entries fire — see §C.2 trigger row). `[§C.2]` Evidence: `tests/unit/hud_state_signaling/test_alert_cue.gd`

- **AC-HSS-2.7 [Logic] [BLOCKING Day-1]** **GIVEN** an HSS instance with `_alert_cue_last_fired_per_actor[G1] = T_0`, **WHEN** G1 is freed (`is_instance_valid(G1) == false`) AND a new alert event fires (any actor), **THEN** the dictionary cleanup runs: `_alert_cue_last_fired_per_actor.erase(G1)` is called within the signal handler (verified via post-handler dict size check). `[CR-9 cleanup rule]` Evidence: `tests/unit/hud_state_signaling/test_rate_gate.gd`

- **AC-HSS-2.8 [Logic] [BLOCKING Day-1]** (NEW REV-2026-04-28 — closes accessibility-specialist Finding 1: SC 1.1.1/1.3.3 escalation gap) **GIVEN** ALERT_CUE just fired for G1 at game_time `T_0` with `_alert_cue_last_state_per_actor[G1] = SUSPICIOUS`, **WHEN** `Events.alert_state_changed.emit(G1, AlertState.SUSPICIOUS, AlertState.COMBAT, Severity.MAJOR)` fires at `T_0 + 0.4` s (within cooldown but upward severity), **THEN** ALERT_CUE fires AGAIN (cooldown bypassed per CR-9 REV-2026-04-28 upward-severity exemption): Timer restarted, `_alert_cue_last_state_per_actor[G1] == COMBAT`, new AccessKit announce queued. `[CR-9 REV-2026-04-28]` Evidence: `tests/unit/hud_state_signaling/test_rate_gate_escalation.gd`

- **AC-HSS-2.9 [Logic] [BLOCKING Day-1]** (NEW REV-2026-04-28 — closes qa-lead Finding 1: Timer.timeout precision) **GIVEN** ALERT_CUE fires at game_time `T_0` with `wait_time = 2.0`, **WHEN** the Timer auto-dismisses, **THEN** `Timer.timeout` fires within `T_0 + 2.0 ± 1 frame (17 ms at 60 fps)`. `[CR-5, F.1]` Evidence: `tests/unit/hud_state_signaling/test_auto_dismiss.gd`

### Cluster 3 — State machine + priority resolver (mostly VS)

- **AC-HSS-3.1 [Logic] [BLOCKING VS]** **GIVEN** ALERT_CUE active for G1, **WHEN** ALARM_STINGER's trigger fires (a guard enters COMBAT with severity MAJOR + section-wide-alarm flag false → true), **THEN** ALARM_STINGER preempts (priority 2 < priority 3): `_alert_cue_timer.is_stopped() == true`, `_alarm_stinger_timer.is_stopped() == false`, `_label.text == tr("HUD_ALARM_RAISED")`. ALERT_CUE is dropped (no buffer). `[CR-6, F.2]` Evidence: `tests/unit/hud_state_signaling/test_priority_resolver.gd`

- **AC-HSS-3.2 [Logic] [BLOCKING VS]** **GIVEN** ALARM_STINGER active, **WHEN** MEMO_NOTIFICATION's trigger fires (`document_collected`), **THEN** MEMO is queued (single-deep buffer with `queued_at_time = now`); ALARM_STINGER's Label text is unchanged. **WHEN** `_alarm_stinger_timer.timeout` fires AND `(now - queued_at_time) ≤ 1.0` s (`queued_state_max_age_s`), **THEN** MEMO_NOTIFICATION activates: `_label.text == tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(<doc.title_key>)`. **WHEN** the age >1.0 s, MEMO is discarded. `[CR-6, §C.3]` Evidence: `tests/unit/hud_state_signaling/test_priority_resolver.gd`

- **AC-HSS-3.3 [Logic] [BLOCKING VS]** **GIVEN** any HSS state OTHER THAN ALARM_STINGER active, **WHEN** HUD Core's INTERACT_PROMPT becomes active (priority 2 after REV-2026-04-28), **THEN** INTERACT_PROMPT preempts the HSS state (HUD Core's resolver picks INTERACT_PROMPT as winner; HSS state's Timer continues running but `_label.text` is HUD Core's prompt-strip text, NOT the HSS state's text). When HUD Core's INTERACT_PROMPT clears AND HSS state's Timer hasn't expired, the HSS state's text is restored to the Label by the next resolver tick. `[CR-6, F.2]` Evidence: `tests/integration/hud_state_signaling/test_interact_prompt_preemption.gd`

- **AC-HSS-3.4 [Logic] [BLOCKING VS]** (NEW REV-2026-04-28 — closes ux-designer Finding 3: ALARM_STINGER preempts INTERACT_PROMPT) **GIVEN** INTERACT_PROMPT is active, **WHEN** ALARM_STINGER's trigger fires, **THEN** ALARM_STINGER preempts INTERACT_PROMPT (priority 1 < priority 2 per CR-6 REV-2026-04-28): `_label.text == tr("HUD_ALARM_RAISED")`, `_alarm_stinger_timer.is_stopped() == false`. After ALARM_STINGER's 3.0 s Timer expires, INTERACT_PROMPT re-evaluates from PC's current interact target (no buffer needed for INTERACT_PROMPT — it is latch-driven per HUD Core CR-12). `[CR-6 REV-2026-04-28, F.2]` Evidence: `tests/integration/hud_state_signaling/test_alarm_preempts_interact.gd`

- **AC-HSS-3.5 [Logic] [BLOCKING VS]** (NEW REV-2026-04-28 — closes systems-designer Finding 10: same-priority collision rule) **GIVEN** ALERT_CUE active for G1, **WHEN** `Events.alert_state_changed` fires for G2 (same priority 3), **THEN** the second arrival is **dropped** (not queued, not preempted): `_label.text` unchanged, no queue entry, no Timer change. ALARM_STINGER subsumes the multi-guard case section-wide. `[§C.3 same-priority rule, E.1]` Evidence: `tests/unit/hud_state_signaling/test_priority_resolver.gd`

- **AC-HSS-3.6 [Logic] [BLOCKING VS]** (NEW REV-2026-04-28 — closes systems-designer Finding 2: queue arithmetic) **GIVEN** SAVE_FAILED queued behind ALARM_STINGER at `t = 0`, **WHEN** ALARM_STINGER's 3.0 s Timer expires, **THEN** SAVE_FAILED activates (age = 3.0 s; `queued_state_max_age_s = 5.0` per REV-2026-04-28; 3.0 ≤ 5.0). Previously (with `queued_state_max_age_s = 1.0`), SAVE_FAILED was discarded silently. `[§C.3 REV-2026-04-28, §G.1]` Evidence: `tests/unit/hud_state_signaling/test_priority_resolver_queue.gd`

- **AC-HSS-3.7 [Logic] [BLOCKING VS]** (NEW REV-2026-04-28 — closes qa-lead Finding 3: E.4 coverage) **GIVEN** RESPAWN_BEAT and SAVE_FAILED triggered on the same frame, **WHEN** the resolver evaluates, **THEN** SAVE_FAILED wins (priority 4 < priority 5); RESPAWN_BEAT is queued; with `queued_state_max_age_s = 5.0` and SAVE_FAILED 4.0 s duration, RESPAWN_BEAT survives the wait (4.0 ≤ 5.0) and activates after SAVE_FAILED. `[E.4, §C.3 REV-2026-04-28]` Evidence: `tests/unit/hud_state_signaling/test_priority_resolver_coincidence.gd`

### Cluster 4 — Auto-dismiss timing (mostly VS)

- **AC-HSS-4.1 [Logic] [BLOCKING Day-1]** **GIVEN** the project's tuning knobs file declares `alert_cue_duration_s = 2.0`, **WHEN** HSS instantiates and reads the value, **THEN** `_alert_cue_timer.wait_time == 2.0` (within ±0.0005 tolerance for float comparison). `[F.1, §G.1]` Evidence: `tests/unit/hud_state_signaling/test_tuning_knob_load.gd`

- **AC-HSS-4.2 [Logic] [BLOCKING VS]** **GIVEN** all 5 HSS Timer nodes exist with their default wait_times, **WHEN** Inspector reads each Timer.wait_time, **THEN** the values match §G.1 defaults exactly: alert 2.0, memo 3.0, alarm 5.0, respawn 1.5, save_failed 4.0. `[F.1, §G.1]` Evidence: `tests/unit/hud_state_signaling/test_tuning_knob_load.gd`. **BLOCKED-on**: VS sprint.

### Cluster 5 — Locale + AccessKit (Day-1 BLOCKING + VS)

- **AC-HSS-5.1 [Integration] [BLOCKING Day-1]** **GIVEN** ALERT_CUE active with `_label.text == "GUARD ALERTED"` (EN locale), **WHEN** the player changes locale to FR, **THEN** `Object.NOTIFICATION_TRANSLATION_CHANGED` fires AND HSS re-resolves: `_label.text == tr("HUD_GUARD_ALERTED")` (FR translation, e.g., "GARDE ALERTÉ") AND `_label.accessibility_description == tr("HUD_GUARD_ALERTED")` (same FR text). The Timer's remaining time is unchanged. `[CR-7, E.12]` Evidence: `tests/integration/hud_state_signaling/test_locale_change.gd`

- **AC-HSS-5.2 [Logic] [BLOCKING Day-1]** **GIVEN** any HSS state about to fire, **WHEN** the state-entry path runs, **THEN** `_label.accessibility_live == "polite"` (NEVER "assertive"). `[CR-8, FP-HSS-5]` Evidence: `tests/unit/hud_state_signaling/test_accesskit.gd`

- **AC-HSS-5.3 [Config/Data] [BLOCKING Day-1]** **GIVEN** the project source tree, **WHEN** CI grep runs `accessibility_live\s*=\s*"assertive"` against `src/ui/hud_state_signaling.gd` and any HSS-owned `.gd` files, **THEN** zero matches found (FP-HSS-5 enforced). `[FP-HSS-5]` Evidence: `tools/ci/check_forbidden_patterns_hss.sh` grep output.

### Cluster 6 — ui_context + Tween-kill (Day-1 BLOCKING)

- **AC-HSS-6.1 [Integration] [BLOCKING Day-1]** **GIVEN** ALERT_CUE active with Timer.time_left == 1.0 s, **WHEN** `Events.ui_context_changed.emit(InputContext.Context.DOCUMENT_OVERLAY, InputContext.Context.GAMEPLAY)` fires, **THEN** within the same physics frame: `_alert_cue_timer.is_stopped() == true` AND active state cleared (HSS internal state machine in HIDDEN equivalent). `_label.visible` is determined by HUD Core's hide rule (HUD root hides on non-GAMEPLAY per HUD Core CR-10 + ui_context_changed). `[CR-11]` Evidence: `tests/integration/hud_state_signaling/test_ui_context_kill.gd`

- **AC-HSS-6.2 [Integration] [BLOCKING Day-1]** **GIVEN** an HSS instance, **WHEN** `ui_context_changed` returns to GAMEPLAY (`new == GAMEPLAY, old == DOCUMENT_OVERLAY`), **THEN** HSS does NOT auto-resume any prior state. The HSS internal state machine remains in HIDDEN. The next state must be triggered by a fresh Events signal. `[CR-11, §B refusal #1]` Evidence: `tests/integration/hud_state_signaling/test_ui_context_kill.gd`

### Cluster 7 — Save/Load transient discipline (BLOCKING VS)

- **AC-HSS-7.1 [Logic] [BLOCKING VS]** **GIVEN** an HSS instance, **WHEN** `SaveLoad.assemble_savegame()` runs, **THEN** the resulting `SaveGame` contains NO `hud_state_signaling: HSSState` field (schema-level absence verified via `SaveGame.has_property("hud_state_signaling") == false`). `[CR-13]` Evidence: `tests/integration/hud_state_signaling/test_save_load_transient.gd`

- **AC-HSS-7.2 [Integration] [BLOCKING VS]** **GIVEN** a save was written while ALERT_CUE was active, **WHEN** the save is loaded, **THEN** the freshly-loaded HSS instance starts at HIDDEN (no state restored, no rate-gate dict prepopulated). `[CR-12, CR-13]` Evidence: `tests/integration/hud_state_signaling/test_save_load_transient.gd`

### Cluster 8 — Performance budget (BLOCKING Day-1)

- **AC-HSS-8.1 [Integration] [BLOCKING Day-1]** **GIVEN** the Restaurant reference scene `tests/reference_scenes/restaurant_dense_interior.tscn` with HUD Core photosensitivity flash mid-cycle AND ALERT_CUE state-transition firing on the same frame (worst-case coincidence per E.24), **WHEN** `/perf-profile` measures Slot 7 over a 30-second capture on Iris Xe Gen 12, **THEN** the worst-case frame measurement does NOT exceed `0.3 ms` (Slot 7 cap). If measurement exceeds, apply CR-14 deferred-AccessKit mitigation (defer `accessibility_*` set to `call_deferred` next frame); re-measure. **OR** apply ADR-0008 reserve carve-out approval (already in place per 2026-04-28 amendment). `[CR-14, F.4, E.24]` Evidence: `production/qa/evidence/perf-hss-[date].md` + `/perf-profile` artifact.

- **AC-HSS-8.2 [Logic] [BLOCKING Day-1]** **GIVEN** HSS source code, **WHEN** CI grep runs `func _process\(` and `func _physics_process\(` against `src/ui/hud_state_signaling.gd`, **THEN** zero matches found (FP-HSS-4 enforced — Timer-only dispatch). `[FP-HSS-4, CR-5]` Evidence: `tools/ci/check_forbidden_patterns_hss.sh`.

### Cluster 9 — Forbidden-pattern CI lints (BLOCKING Day-1)

- **AC-HSS-9.1 [Config/Data] [BLOCKING Day-1]** **GIVEN** HSS source + scene tree, **WHEN** CI grep runs the full FP-HSS-1..11 panel, **THEN** all 11 lint rules pass (zero matches in source/scene/translation table per rule). Lint script `tools/ci/check_forbidden_patterns_hss.sh` covers:
   - FP-HSS-1: scene-tree introspection — assert HSS scene root has only Timer node children.
   - FP-HSS-2: emoji/pictogram regex on translation table values for HSS keys.
   - FP-HSS-3: `get_node\(.*PromptStrip` / `find_child\(.*Label` in HSS source.
   - FP-HSS-4: `func _process\(` / `func _physics_process\(` in HSS source.
   - FP-HSS-5: `accessibility_live\s*=\s*"assertive"` in HSS source.
   - FP-HSS-6: Timer.wait_time > 8.0 in HSS scene file or hardcoded.
   - FP-HSS-7: English literal regex (limited heuristic — common HUD verbs outside `tr()` calls and outside comments).
   - FP-HSS-8: `Events\..*\.emit\(` in HSS source.
   - FP-HSS-9: `HUDCore\._on_` / `HUDCore\._pending_flash` in HSS source.
   - FP-HSS-10: text keys / strings matching `objective`, `waypoint`, `marker`, `tracker`, `compass`.
   - FP-HSS-11: text keys / strings matching `xp`, `level_up`, `unlocked`, `achievement`, `+\d+`.
   `[CR-15, FP-HSS-1..11]` Evidence: `tools/ci/check_forbidden_patterns_hss.sh` exit code 0.

### Cluster 10 — Pillar 1/2/3/5 verification (smoke / playtest)

- **AC-HSS-10.1 [Visual/Feel] [ADVISORY — playtest-gated]** (REV-2026-04-28 — closes systems-designer Finding 9 + qa-lead Finding 4: n=5→8, rejection-list framing) **GIVEN** a 5-minute playtest of the Plaza section (Day-1 minimal slice) with **n=8 playtesters**, **WHEN** the playtest is reviewed against rejection-list criteria, **THEN** **zero playtesters** spontaneously describe ALERT_CUE using any of the rejection-list terms: "interrupted", "broke flow", "had to read it", "felt like a popup", "demanded my attention", "annoying", "got in the way". (Previous "≥4 of 5 answer 'margin note' or equivalent" was reframed because (a) "equivalent" is untestable, (b) n=5 is statistically underpowered, (c) zero-count rejection-list test is more rigorous than positive-list ratio.) Acceptable: playtester does not mention ALERT_CUE at all (margin note achieved its goal: noticed peripherally, not reported on). `[§B Margin Note tonal anchor]` Evidence: playtest report at `production/qa/playtest/[date]-hss-day-1.md`.

- **AC-HSS-10.2 [Visual/Feel] [ADVISORY — playtest-gated, VS]** **GIVEN** a 30-minute playtest of the full Tower mission (VS), **WHEN** all 5 HSS states fire over the course of the session, **THEN** the playtester does NOT report any state as "annoying" / "interrupting" / "felt like a popup". `[§B + Pillar 5]` Evidence: VS playtest report.

- **AC-HSS-10.3 [Visual/Feel] [ADVISORY — accessibility playtest, VS]** (REV-2026-04-28 — closes accessibility-specialist Finding 9: 500 ms criterion is AT-implementation untestable; reframed) **GIVEN** a HoH/deaf playtester running the Plaza tutorial, **WHEN** a guard alerts on them, **THEN** (a) the playtester observes ALERT_CUE clearly (no missed event, no confusion about state) AND (b) `_label.accessibility_description` is set on the same physics frame as visual onset (verified via unit test AC-HSS-2.1 at the implementation layer) AND (c) the AT (NVDA on Windows / Orca on Linux) successfully announces "GUARD ALERTED" before the next state-entry event preempts (the auto-dismiss Timer expiring is acceptable bound — announcement should arrive within the state's display window for fast speech rates; slow speech rates are documented as known limitation, not failure). `[CR-8, UI-3, WCAG 1.1.1 / 1.3.3]` Evidence: accessibility playtest report at `production/qa/playtest/[date]-accessibility-hss.md`.

### AC totals

**Total ACs (REV-2026-04-28)**: **38** = 19 Day-1 BLOCKING + 16 BLOCKED-on-VS + 3 ADVISORY playtest.

Day-1 BLOCKING for HUD Core MVP (per-cluster recount; closes qa-lead Finding 6 — previous headline 14 was wrong, breakdown summed 16, actual tag count is now 19 after REV additions):
- Cluster 1 (subscriber lifecycle): AC-HSS-1.1, 1.3, 1.4, 1.5 = **4**
- Cluster 2 (ALERT_CUE): AC-HSS-2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9 = **9**
- Cluster 4 (auto-dismiss timing): AC-HSS-4.1 = **1**
- Cluster 5 (locale + AccessKit): AC-HSS-5.1, 5.2, 5.3 = **3**
- Cluster 6 (ui_context + Tween-kill): AC-HSS-6.1, 6.2 = **2** (note: 6.2 is Day-1 BLOCKING)
- Cluster 8 (perf budget): AC-HSS-8.1 (reclassified — see qa-lead Finding 9 / smoke note below), 8.2 = **1** (8.1 reclassified ADVISORY pending CI harness)
- Cluster 9 (CI lints): AC-HSS-9.1 = **1** (deferred until ADR-0004 Gate 1 closes)

**Day-1 BLOCKING total: 19 ACs.**

VS BLOCKING for VS sprint:
- Cluster 1: AC-HSS-1.2 = 1
- Cluster 3 (resolver): AC-HSS-3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7 = 7
- Cluster 4: AC-HSS-4.2 = 1
- Cluster 7 (save/load): AC-HSS-7.1, 7.2 = 2
- Plus 5 additional VS-only states ACs = 5
- **VS BLOCKING total: 16 ACs.**

ADVISORY (playtest-gated): AC-HSS-10.1, 10.2, 10.3 = **3 ACs.**

### CI skip mechanism for VS-blocked ACs (REV-2026-04-28 — closes qa-lead Finding 6)

VS-blocked ACs use a project-level feature flag for auditable skip/activate: `ProjectSettings.get_setting("game/feature_flags/hss_vs_scope_enabled", false)`. At MVP the flag is `false` → GUT framework `skip()` test functions tagged `[BLOCKING VS]` with reason "BLOCKED-on VS sprint". When VS scope ships, the flag flips to `true` → tests run normally. The skip is auditable: a CI report enumerates skipped tests with the flag value at run time. This prevents the "tests silently skipped without gating condition" failure mode flagged in the adversarial review.

### Smoke check vs full-suite gate (REV-2026-04-28 — closes qa-lead Finding 7)

- **Smoke check** (per §H.0 pattern from HUD Core): the minimum subset of ACs that MUST pass before QA hand-off. **Expanded REV-2026-04-28 to include resolver coverage and the AC-HSS-2.8 escalation case**:
  - AC-HSS-1.1 (subscriber registered)
  - AC-HSS-1.3 (HUD Core handshake)
  - AC-HSS-1.4 (unregister on exit)
  - AC-HSS-2.1, 2.2, 2.3 (ALERT_CUE happy-path + rate-gate)
  - AC-HSS-2.5 (auto-dismiss)
  - **AC-HSS-2.8 (upward-severity escalation — SC 1.1.1/1.3.3 closure, REV-2026-04-28)**
  - AC-HSS-2.9 (Timer.timeout precision)
  - **AC-HSS-3.4 (ALARM_STINGER preempts INTERACT_PROMPT — VS, included when VS flag enabled)**
  - **AC-HSS-3.5 (same-priority collision drop)**
  - AC-HSS-5.2 (AccessKit polite default)
  - AC-HSS-5.3 (CI grep — deferred until Gate 1 closes per CR-8 REV-2026-04-28)
  - AC-HSS-6.1 (ui_context kill)
  - AC-HSS-9.1 (FP-HSS lints — deferred until Gate 1 closes for FP-HSS-5)
- **Full suite**: all 38 ACs.

AC-HSS-8.1 (perf budget) is reclassified ADVISORY rather than BLOCKING smoke (qa-lead Finding 9: not CI-automatable as written; needs deterministic headless harness to be promotable). It remains gated before MVP sprint sign-off via the OQ-HSS-4 profile gate.

## Open Questions

### BLOCKING for MVP-Day-1 sprint

- **OQ-HSS-1** [BLOCKING] — **HUD Core NEW APIs (Coord items §F.5 #1 + #2)**: HUD Core must publish `register_resolver_extension(Callable)` and `get_health_label() -> Label`. The first is BLOCKING for Day-1 (CR-4 depends on it); the second is BLOCKING for VS (CR-18). Both are HUD Core-owned implementations; HSS GDD declares the consumer contract here. **Owner**: HUD Core maintainer + ux-designer. **Target**: before HUD Core MVP sprint planning closes.

- **OQ-HSS-2** [BLOCKING] — **MLS section authoring contract amendment (Coord item §F.5 #3)**: MLS §C.5 must add `HUDStateSignaling` as a required sibling of `HUDCore` + `DocumentCollection` under `Section/Systems/`. CI lint per MLS §C.5.6: each `section_*.tscn` must contain `Section/Systems/HUDStateSignaling`. **Owner**: MLS maintainer. **Target**: before MLS sprint planning.

- **OQ-HSS-3** [BLOCKING Day-1 — REV-2026-04-28 PROMOTED FROM ADVISORY: closes Pillar 5 §Visual Identity Anchor contradiction for hearing players (game-designer Finding 3, ux-designer Finding 7)] — **Settings toggle `accessibility.hud_alert_cue_enabled`, default ON**. HoH compliance floor preserved (default ON satisfies WCAG 1.1.1); hearing players can opt out so ALERT_CUE doesn't redundantly stamp every guard alert that the alert music already conveyed. The previous "non-negotiable" framing is reframed: ALERT_CUE is always-ON at Day-1 default; opt-out is opt-out, not removal; the toggle path requires accessibility-specialist sign-off per G.5. **Owner**: Settings maintainer + accessibility-specialist + UX. **Target**: BLOCKING Day-1.

- **OQ-HSS-3-locale** [BLOCKING Day-1 — Localization Scaffold §Authoring guidelines (Coord item §F.5 #4)]: 7 translation keys must be registered with reference EN values + period-clerical authoring guidelines (no exclamation marks, no emoji, **≤18 chars target** for ALARM_STINGER per ux-designer Finding 4, ≤24 chars target for other keys, all-caps for declarative states, mixed-case for object titles inside composed strings). **Owner**: Localization Scaffold maintainer + writer. **Target**: before MVP sprint kickoff.

- **OQ-HSS-4** [BLOCKING for Day-1] — **Profile gate `tests/integration/hud_state_signaling/test_slot7_coincidence_budget.gd` (Coord item §F.5 #5)**: measure HUD Core photosensitivity-flash + HSS state-transition coincidence on Iris Xe Gen 12. Validate ≤0.3 ms or apply CR-14 deferred-AccessKit mitigation (defer `accessibility_*` set to `call_deferred`). **Owner**: performance-analyst. **Target**: before MVP sprint sign-off.

### BLOCKING for VS sprint

- **OQ-HSS-5** [BLOCKING for VS] — **Audio paired-cue timing alignment (Coord item §F.5 #9 ADVISORY → BLOCKING for VS)**: HSS visual onset and Audio cue onset should align within ~50 ms for sensory unity. Verify via VS playtest on each of the 5 paired states (ALERT_CUE / MEMO_NOTIFICATION / ALARM_STINGER / RESPAWN_BEAT / SAVE_FAILED). If misalignment >50 ms, apply `call_deferred` on HSS state-entry to sync. **Owner**: sound-designer + performance-analyst. **Target**: VS playtest sign-off.

### ADVISORY

- **OQ-HSS-6** [BLOCKING Day-1 — REV-2026-04-28: WCAG 2.2.1 Level A Timing Adjustable] — **`accessibility.hud_state_timing_multiplier` (Settings)** + a "never auto-dismiss" option for ALERT_CUE/MEMO_NOTIFICATION/SAVE_FAILED. Default value 1.0 (current durations); range [0.5, 5.0] OR sentinel `0.0` for never-dismiss (state stays visible until next state preempts OR ui_context_changed != GAMEPLAY clears it). HSS multiplies all auto-dismiss `wait_time` values by this multiplier on Timer.start. ALARM_STINGER and CR-18 pulse are NOT affected (designated Margin Note exceptions per §B; ALARM_STINGER must remain bounded for AT delivery; pulse opt-out is OQ-HSS-10). Settings UI groups this toggle adjacent to OQ-HSS-3 ALERT_CUE toggle and OQ-HSS-10 pulse toggle for AT-discoverability. **Owner**: Settings maintainer + accessibility-specialist. **Target**: BLOCKING Day-1 — without this, EU GAAD compliance posture cannot be claimed (current claim is downgraded to "compliance posture" pending closure of Gate 1 + this OQ + OQ-HSS-10).

- **OQ-HSS-7** [ADVISORY] — **Asset Spec doc `design/asset-specs/hud-state-signaling.md`** (per §F.5 #10): even though HSS owns zero new visual assets, an asset-spec doc serves as QA visual reference (per-state screenshot fixtures + locale-variant length verification). **Owner**: art-director. **Target**: VS asset production prep, after Art Bible §7D approval.

- **OQ-HSS-8** [ADVISORY] — **AccessKit assertive-vs-polite playtest validation**: CR-8 + FP-HSS-5 lock to `polite`. Validate with screen-reader users that polite-only is acceptable for ALARM_STINGER (the most consequential state). If accessibility playtest reveals ALARM_STINGER needs assertive treatment for genuine emergency salience, this opens an ADR amendment + accessibility-specialist sign-off path. **Owner**: accessibility-specialist + screen-reader user playtest. **Target**: VS accessibility playtest.

- **OQ-HSS-9** [ADVISORY] — **Locale length variants exceeding 24-char prompt-strip width budget**: German typically runs 30%+ longer than English. "ALARM RAISED — TOWER LOCKDOWN" ≈ 28 chars EN may exceed 24-char width budget when translated to DE. Localization Scaffold authoring guideline must verify per-locale; if overflow occurs, either (a) shorten the EN reference to leave headroom, OR (b) accept Label `clip_text = true` truncation per HUD Core §C.2 (the truncated form is a known accessibility caveat — AT still announces the full string via `accessibility_description`). **Owner**: localization-lead + writer. **Target**: VS locale QA.

- **OQ-HSS-10** [BLOCKING VS — REV-2026-04-28: WCAG 2.2.2 Level A Pause/Stop/Hide] — **Critical-health pulse opt-out toggle `accessibility.hud_critical_pulse_enabled` (default ON, separate from `Settings.damage_flash_enabled`)**: CR-18's continuous color-cycling pulse on the health Label runs while critical-health and is animation-from-interaction (taking damage). SC 2.2.2 Level A requires user ability to pause/stop/hide. Resolution: separate toggle (NOT shared with damage_flash) — defaults ON for HoH compliance; HoH+photosensitive players can disable. Settings UI groups this toggle with OQ-HSS-3 + OQ-HSS-6 with copy distinguishing purposes (reduce AT-navigation discovery burden). When toggled OFF, CR-18 immediately stops the active Tween + clears the theme override. **Owner**: Settings maintainer + accessibility-specialist + game-designer. **Target**: BLOCKING VS — pulse cannot ship without this; SC 2.2.2 is Level A baseline.

### Deliberately omitted (and why)

- **Modal "save failed" dialog** — owned by Save/Load (CR-9) for blocking failures (CORRUPT_SAVE, PERMISSION_DENIED). HSS only handles non-blocking advisories (IO_ERROR, DISK_FULL_NON_CRITICAL) per CR-17.
- **Death screen / "You Died" surface** — anti-pillar; F&R explicitly omits per its §C.5 carve-out; HSS does NOT add one.
- **Quest update banner / objective marker text** — anti-pillar (FP-HSS-10); not in HSS scope, never will be.
- **XP / progression / achievement toast** — anti-pillar (FP-HSS-11); not in HSS scope, never will be.
- **Above-head guard alert indicator** — Pillar 5 absolute; game-concept §Visual Identity Anchor explicitly forbids. The HoH ALERT_CUE in the prompt-strip is the only sanctioned accessibility carve-out.
- **Minimap / compass / waypoint** — anti-pillar; not in HSS scope.
- **Photo mode / screenshot tool** — Tier 3 (post-launch); not in HSS scope.
- **HUD-driven dialogue subtitles** — owned by Dialogue & Subtitles GDD #18 (Designed 2026-04-28; separate Label on CanvasLayer 2 LOCKED).
- **HUD-driven cinematic letterbox / mission card** — owned by Cutscenes & Mission Cards GDD #22 (when authored).
- **Network/multiplayer state surfacing** — anti-pillar (single-player only).
