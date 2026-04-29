# Document Overlay UI

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (per UI category routing)
> **Last Updated**: 2026-04-27
> **Last Verified**: 2026-04-27
> **Implements Pillar**: Primary 2 (Discovery Rewards Patience) + Primary 3 (Stealth as Theatre — "suspended parenthesis"); Supporting 1 (Comedy Without Punchlines — typography carries the BQA dossier register) + Supporting 5 (Period Authenticity — sepia-dim register, hard-edged paper card, no modern UX)

> **Quick reference** — Layer: `Presentation` · Priority: `Vertical Slice` · Effort: TBD · Key deps: Document Collection ✅, Post-Process Stack ✅, Input ✅, Localization Scaffold ✅, ADR-0004 (Proposed) · Key contracts: ADR-0004 (CanvasLayer 5, InputContext push/pop, FontRegistry, Theme inheritance, sepia-dim lifecycle), ADR-0008 Slot 7 (0.3 ms UI cap)

## Overview

Document Overlay UI is *The Paris Affair*'s **Vertical-Slice reading surface plus the modal-lifecycle host** that turns a pocketed document into a moment of patient observation. As a **data layer** it owns: a per-section `CanvasLayer` scene at **index 5** (locked by **ADR-0004 §IG7** — between Post-Process Stack's sepia ColorRect at 4 and Pause Menu at 8); the **modal lifecycle** that on open pushes `InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)` per **ADR-0004 §IG2**, calls `PostProcessStack.enable_sepia_dim()` per **ADR-0004 §IG4**, sets `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE` per **Input CR-8** (saving the previous mode for restore), instantiates the document card scene, populates header via `Label.text = tr(document.title_key)` and body via `RichTextLabel.append_text(tr(document.body_key))` per **ADR-0004 §IG11** + **Localization Scaffold CR-1**, and on close performs the symmetric reversal in the order specified by **Input CR-7** (`get_viewport().set_input_as_handled()` BEFORE `InputContext.pop()` to prevent the same-frame Esc silent-swallow); the **subscriber contract** to **Document Collection's** 2 frozen UI-relevant signals declared in **ADR-0002** (`document_opened(StringName)` to render-and-show the card, `document_closed(StringName)` to tear it down — Document Overlay is **subscriber-only**, **never** an emitter, since Document Collection is sole publisher per **DC CR-7** + **CR-11**); the public **call-out methods** `DC.open_document(document_id)` and `DC.close_document()` invoked on `interact` activation and on dismiss respectively (per **DC CR-11** Option C contract); the **modal dismiss handler** at the surface root that reads `event.is_action_pressed(&"ui_cancel")` in `_unhandled_input()` per **ADR-0004 §IG3** (NEVER a focused Close button — sidesteps Godot 4.6's dual-focus split); and the **`NOTIFICATION_TRANSLATION_CHANGED` handler** that re-resolves both `title_key` and `body_key` and calls `RichTextLabel.clear()` + `append_text(...)` so a locale change while the overlay is open refreshes text without a scene reload (**Localization CR-9** forbids `cached_translation_at_ready`). As a **player-facing surface** it is the **suspended parenthesis** — a 12-frame fade in which the 3D world recedes into Art Bible §2's sepia register at 30% luminance, the paper card on its own CanvasLayer holds full saturation, the music ducks to `document_overlay_music_db = -10 dB` and ambient to `document_overlay_ambient_db = -20 dB` per Audio's `*_overlay` mix profile (Audio owns the dB values via its own `document_opened` subscription — the Overlay just enables sepia and reads the keys), and Eve Sterling's act of reading becomes the only event that matters. The card is staged in the **BQA dossier register** (**Art Bible §7D** + **§4.4**): hard-edged BQA Blue header bar `#1B3A6B` on Parchment `#F2E8C8`, American Typewriter Bold for the title via `FontRegistry.document_header()` and American Typewriter Regular for the body via `FontRegistry.document_body()` per **ADR-0004 §FontRegistry**, no rounded corners, no drop shadows, no glow (forbidden project-wide by **PPS CR-7**), no inline icons, no body animation. Document Overlay UI is **NOT autoload** per **ADR-0007** (the autoload registry is full at slot #9 = MLS; this is a per-section `CanvasLayer` scene analogous to HUD Core's pattern, instantiated by Mission & Level Scripting per-section authoring and torn down on section unload). It claims its share of the **ADR-0008 Slot 7 (UI = 0.3 ms shared with HUD Core)** envelope only when active — when open, HUD Core hides per HUD Core's `InputContext.current() != GAMEPLAY` visibility gate (HUD CR pending OQ-HUD-3 verification) and the Slot 7 cap is effectively held by the Overlay alone; when closed, Overlay contributes 0 ms (queue_freed instance) and Slot 7 returns to HUD Core. **Pillar fit**: Primary **2 (Discovery Rewards Patience)** is load-bearing — without the Overlay, the document collection loop is a stat-bar; the reading is the reward; Primary **3 (Stealth is Theatre, Not Punishment)** is load-bearing through the sepia-dim "suspended parenthesis" register (**Art Bible §2 Document Discovery**) that makes reading feel like a theatrical cue change rather than a menu interrupt; Supporting **1 (Comedy Without Punchlines)** is served by the typographic register — American Typewriter on Parchment with dry BQA voice carries the joke; Supporting **5 (Period Authenticity Over Modernization)** is served by what the Overlay refuses to render (no zoom/pan, no inline icons, no progress bars, no "swipe to next page", no auto-scroll, no time-based dismissal). **Phasing**: this is a **pure Vertical-Slice system** — Document Collection's MVP slice ships pickup-only (DC §A "MVP scope" + DC CR-11 [VS] tag), so this entire GDD is VS scope; there is no MVP slice to phase out. **This GDD defines**: the modal scene structure, the open/close lifecycle (InputContext + PPS + mouse mode + tr() rendering + dismiss), the Theme + FontRegistry + AccessKit + locale-change re-resolve integration, the scroll/keyboard-navigation grammar within the body, the Pillar-5 forbidden patterns that keep modern reading-app conventions out, and the `ADR-0008` Slot 7 sub-claim accounting. **This GDD does NOT define**: the `Document` Resource schema or which 21 documents ship (**Document Collection #17** owns); the document body content or `# context` cells in `translations/doc.csv` (**Writer + Localization Scaffold #7** own); the `document_collected` signal or pickup lifecycle (**DC** owns — Overlay never sees `document_collected`); the sepia-dim shader, transition curve, or per-pixel formula (**Post-Process Stack #5** owns — Overlay only calls the lifecycle API); the music duck dB values or ambient suppression curve (**Audio #3** owns); the font asset files, the size-floor substitution, or the `project_theme.tres` base (**ADR-0004 + FontRegistry static class** own — Overlay only inherits and consumes); the subtitle suppression rule (**ADR-0004 §IG5** + **Subtitle System** own — Subtitle subscribes to `document_opened`/`document_closed` directly); the `ui_cancel` InputMap binding (**Input #2** owns); the HUD visibility gate (**HUD Core #16** owns its own `InputContext.current()` check); the mission-dossier card or cutscene flows (**Cutscenes & Mission Cards #22** owns); and the polished case-file archive (revisiting collected documents from Pause Menu — explicitly **Polish-or-later** per **DC §E.12**, NOT in this GDD).

## Player Fantasy

**The Lectern Pause.** The player feels Eve stop walking and *give the page her full attention* — the way a careful operative reads when she knows the next move depends on what's printed here, and the way a 1965 professional reads paper that someone else typed.

The fantasy is **posture**. Eve has stepped into an alcove off the patrol route. She has the document in her hands. The room's saturated colors fall back into Art Bible §2's sepia register, and the world holds its breath the way a stage darkens around a downstage spotlight when the cue changes. The Parchment card is high-contrast against the dim; her shoulders are still; her foot isn't tapping. The player isn't looking at a UI overlay — they're standing next to Eve at a lectern, reading what she's reading. The body might be a PHANTOM logistics memo about ensuring "the sample's vessel does not leak before showtime," or a BQA dispatch acknowledging receipt of one (1) silenced sidearm, or a Restaurant manager's terse note about table 14's standing reservation — the kind of dossier where the comedy is in *who would write this and how*. Eve doesn't react. The player reads. When they're done, both of them put the page away and the room's color resumes. The act is unhurried but not lazy; it is what a professional looks like when she is doing her job.

This fantasy makes **Pillar 3 (Stealth is Theatre, Not Punishment)** load-bearing — the sepia-dim register *is* the cue change; the Overlay does not interrupt the world, it stages a beat inside it — and **Pillar 2 (Discovery Rewards Patience)** load-bearing — the reward for the patient observer is not a stat-bar increment but the **posture of attention**, the eight-to-thirty seconds of giving the page what it asks for. **Pillar 1 (Comedy Without Punchlines)** is supporting and decisive: the dry BQA register lands harder when read with this much composure, because the player and Eve share the joke without ever exchanging a wink — neither of them quips, and the document is allowed to be funny on its own terms. **Pillar 5 (Period Authenticity Over Modernization)** is supporting structurally: paper rewards stillness, not scrolling; the Overlay's behavioral grammar matches what a 1965 operative would expect from a piece of paper.

The fantasy refuses **five specific shapes** the Overlay could otherwise take and would be wrong:

- **Not a codex.** No archive vibe, no library-shelf metaphor, no "lore unlocked" notification, no document-X-of-Y counter visible during the read, no cross-reference links between documents. Each card is a single object held for its own sake. (The polished case-file archive — revisiting collected documents from the Pause Menu — is explicitly **Polish-or-later** per **DC §E.12**, NOT in this GDD; the read-once moment is the design target.)
- **Not cinematic.** No dramatic zoom-in on the card. No music swell on open. No camera tilt or letterbox. The sepia dim does the entire dramaturgical job — anything more makes the moment performative rather than attentive. (Music *ducks* per Audio's `document_overlay_music_db = -10 dB` profile; it does NOT swell or change track.)
- **Not interactive.** No flipping animation, no swipe-to-next-page, no hold-to-progress, no "tap to reveal," no inline images that animate in. The body text is laid out, the player reads, the player dismisses. The only verbs the player has during the read are **scroll** (if the body is longer than the card) and **dismiss**.
- **Not fast.** No 2-second auto-dismiss, no "press any key to skip," no time-based fade-out if the player stops scrolling. Anyone who treats this like a tooltip has misread the room. The dismiss is **only** the player's choice, via `ui_cancel` (`Esc` or `B/Circle`).
- **Not narrated.** No voiceover, no Eve-reads-aloud, no whispered translation for screen readers (AccessKit reads the body text directly, not a recorded VO). The document is a piece of paper. The player reads the paper. (VO localization would be ~10× the cost of text localization per **Localization Scaffold OQ-2**; the entire reading model assumes silent reading.)

These refusals are **load-bearing, not aesthetic preferences** — each one corresponds to a behavior in a modern reading-app or AAA-tutorial UI that the Overlay must explicitly *not* adopt. They are catalogued as forbidden patterns in §C.

**Fantasy test for any new behavior added to this Overlay** (use this verbatim when reviewing future amendments):

> *"Does this respect the Lectern Pause?"* — meaning: would a professional reader, in 1965, doing her job, accept this behavior from the page in front of her? If the answer requires the word "cool" or "satisfying" or "feels good," it is the wrong behavior. If the answer is "yes, that's what reading looks like," it is the right one.

## Detailed Design

### C.1 Core Rules

**CR-1 [VS]** Sole-subscriber discipline (**ADR-0002**): Document Overlay UI subscribes to `Events.document_opened(StringName)` and `Events.document_closed(StringName)` only. It does NOT subscribe to `Events.document_collected`. It emits ZERO domain signals — Document Collection is sole publisher per **DC CR-7**. Any direct emission of `document_opened`, `document_closed`, or `document_collected` from inside the Overlay scene tree is a CR-7 violation, caught by the project-wide sole-publisher CI lint (FP-OV-1).

**CR-2 [VS]** Open-trigger contract (**Option A — auto-open on pickup, NOLF1 model**): the Overlay opens immediately as part of the pickup interaction. On the same `interact` press that triggers `DocumentCollection.collect()`, DC also calls its own public `open_document(id)` method (per **DC CR-11** Option C). DC emits `document_opened(id)` synchronously in the same frame. The Overlay's subscriber fires; the lifecycle in C.4 runs. There is no separate "read" verb; there is no intermediate state where a document is collected but no Overlay has opened. The pickup → read is one continuous beat. **Coord item OQ-DOV-COORD-1 (BLOCKING for sprint)**: DC §C.10 / CR-11 must confirm this contract — DC's `_on_player_interacted` handler executes `collect()` then `open_document()` in the same frame, before frame end.

**CR-2-bis [VS] Option A-delayed (named fallback)**: Per game-designer review 2026-04-27 (REJECT-LOCKED finding), Option A is the **VS default but no longer LOCKED in §G.4**. If VS playtest reveals patrol-density issues — players dying mid-read because auto-open traps them in a modal while AI ticks (Pillar 3 violation), or players dismissing immediately without reading because the read is involuntary — the named fallback is **Option A-delayed**: `DC.open_document(id)` is deferred 1.0–2.0 s after `DC.collect()` (configurable via new tuning knob `document_auto_open_delay_s`, default 0.0 = immediate). The delay window is gameplay-blocking-cleared (player can move; sepia not yet engaged). On window expiry, the standard C.4 lifecycle runs. Trip conditions for switching to Option A-delayed: ≥ 30% of playtest deaths occur within 5 s of document pickup; OR ≥ 50% of playtest dismissals occur < 1 s after open with body unread (instrumented via Analytics). The fallback is named here to preserve a documented design path, not to predetermine its activation.

**CR-3 [VS]** Single-document-open invariant (per **DC CR-12**): if `document_opened` fires while the Overlay is already in `READING` state, log `push_error("document_opened while already reading: %s" % new_id)` and discard the new event. Do NOT close the current document and open the new one — that path is not specified at VS scope. In normal gameplay this is unreachable because `InputContext.DOCUMENT_OVERLAY` blocks `player_interacted` from firing while open, but the defensive guard is required for the test fixture (see §H).

**CR-4 [VS]** Open lifecycle: see §C.4 for the strict 8-step order. Lifecycle must execute synchronously within the `_on_document_opened` handler (no `await` between steps; no `call_deferred` chains except the AccessKit one-shot live-region clear). All steps happen on the same frame the signal fires.

**CR-5 [VS]** Close lifecycle: see §C.5 for the strict 6-step order. The first step (`get_viewport().set_input_as_handled()`) MUST precede `InputContext.pop()` per **Input CR-7**. The card teardown happens synchronously on dismiss (Option B): `Card.visible = false`, `RichTextLabel.text = ""`, `Label.text = ""` — the player sees the world resume immediately, with no lingering paper.

**CR-6 [VS]** Dismiss policy: the only legal dismiss input is `ui_cancel` (`Esc` / `B/Circle`). The handler lives in `_unhandled_input(event)` at the Overlay's root Control node — NEVER in a focused Button widget (per **ADR-0004 §IG3** — sidesteps Godot 4.6's dual-focus split; `dismiss_via_focused_button` is forbidden as FP-OV-9). No other input path triggers dismiss. Explicit prohibitions: no time-based auto-dismiss, no dismiss on `player_damaged` (combat doesn't fire while the Overlay is open since `InputContext` blocks gameplay input), no dismiss on `section_unloading` except via CR-12, no dismiss by clicking outside the card area.

**CR-7 [VS]** `tr()` at render time (per **Localization Scaffold CR-9**): `tr(title_key)` and `tr(body_key)` are called exclusively at the moment of card population (C.4 step 6). They are NEVER called in `_ready()`, NEVER stored as resolved-string member variables, and NEVER cached between document opens. Cached members are limited to the **keys** (`StringName _current_title_key`, `StringName _current_body_key`) so the locale-change handler can re-resolve. This implements `cached_translation_at_ready` forbidden pattern (carried forward from Localization Scaffold + repeated as FP-OV-4 here).

**CR-8 [VS]** `NOTIFICATION_TRANSLATION_CHANGED` re-resolve: the Overlay's root node overrides `_notification(what)`. When `what == NOTIFICATION_TRANSLATION_CHANGED` AND `_state == READING`, the handler reassigns: `Label.text = tr(_current_title_key)` and `RichTextLabel.text = tr(_current_body_key)`. Direct `text` reassignment on `RichTextLabel` with `bbcode_enabled = true` is the correct idempotent re-render path in Godot 4.6 because **`append_text()` accumulates** (would double the text on re-resolve), while `text = ...` assignment internally calls `clear()` followed by a fresh BBCode parse — equivalent to a full re-render with no leaked tokenizer state. (See **Verification Gate E** — promoted to BLOCKING 2026-04-27 per ux-designer; Gate F ADVISORY.) Scroll position resets to top on locale change — **this is a deliberate trade-off, not a correctness claim** (per localization-lead 2026-04-27 reframing): for RTL locales the reset is correct (reading direction changes); for LTR-to-LTR switches (e.g., German→English) the reset loses the player's relative scroll position. The decision is to accept this trade-off at VS for simplicity; a relative-position-preservation strategy (`scroll_vertical_fraction = scroll_vertical / max_scroll`) may be revisited when FR/DE locales ship if playtest reveals the reset is jarring. If `_state != READING`, the notification is silently ignored.

**CR-9 [VS]** Scroll grammar (see §C.6 for full detail): if the body overflows the card's visible height, scroll is provided by a `ScrollContainer` wrapping the `RichTextLabel`. Scroll verbs: mouse wheel (primary), `ui_up`/`ui_down` arrow keys (1 line per press, ~28 px), `ui_page_up`/`ui_page_down` (1 page minus 1 line for context preservation), gamepad right-stick Y-axis (analog magnitude → scroll velocity, dead-zone `right_stick_scroll_deadzone = 0.15` rejects sub-threshold drift, clamped to `right_stick_scroll_max_step_px_per_frame = 18 px`). **Gamepad analog routing implementation (per godot-specialist 2026-04-27)**: `ScrollContainer` does NOT natively consume `InputEventJoypadMotion` — the Overlay's `_unhandled_input(event)` must include an explicit branch reading `event.get_action_strength(&"ui_scroll_down") - event.get_action_strength(&"ui_scroll_up")` (or the right-stick raw axis if no action is bound) and writing `BodyScrollContainer.scroll_vertical += int(magnitude * max_step)` per frame, after the dead-zone reject and the clamp. Mouse wheel and arrow keys are consumed by `ScrollContainer` natively; only the analog stick path needs a manual handler. No auto-scroll. No `smooth_scroll_enabled = true` (forbidden FP-OV-12 — platform-constraint floor: Steam targets PC/Linux without touch input; smooth-scroll inertia is a mobile/tablet affordance with no period or platform justification). Scroll bar visibility: thin 4 px Ink Black `#1A1A1A` bar on right edge, `vertical_scroll_mode = SCROLL_MODE_AUTO` (auto-hides when content fits). Custom styling via `document_overlay_theme.tres` (coord item OQ-DOV-COORD-7: art-director defines the StyleBoxFlat). **Dead-zone rationale (per ux-designer review 2026-04-27)**: most controllers exhibit 0.05–0.10 magnitude resting drift; without a 0.15 floor, an idle gamepad would auto-scroll a document the player is trying to read still — a direct Lectern Pause violation ("the paper should be still when the player is still"). Both `right_stick_scroll_deadzone` and `right_stick_scroll_max_step_px_per_frame` are added to §G.1 tunables.

**CR-10 [VS]** What the player CANNOT do during the Overlay (explicit prohibition list, enforced by §C.9 forbidden patterns):
- Cannot zoom or pan the card (no post-render transform — FP-OV-3)
- Cannot change font size **within the Overlay session via in-overlay controls** (e.g., no "A+ / A−" buttons on the card; no in-card pinch-to-zoom; no overlay-local font slider). System-level `text_scale_multiplier` from Settings & Accessibility (per **OQ-DOV-COORD-12** added 2026-04-27, accessibility-specialist BLOCKING for WCAG 2.1 AA SC 1.4.4) IS applied to all `FontRegistry.document_*()` font sizes at section-load time and persists across the overlay session — the prohibition is on session-local controls, not on globally-scaled fonts.
- Cannot copy text to clipboard, print, share, or bookmark
- Cannot navigate to another document without dismissing first (CR-3 invariant)
- Cannot interact with the 3D world (`InputContext.DOCUMENT_OVERLAY` blocks `player_interacted` per **Input CR-3**)
- Cannot open a gadget or weapon menu (`InputContext` gates Inventory inputs)
- Cannot pause via Pause Menu while reading: the Overlay's `_unhandled_input` consumes `ui_cancel` first (it's the active modal in the InputContext stack); the player must dismiss the Overlay first, then a second `ui_cancel` press reaches the Pause Menu. Reading and pausing are sequential, not nested
- Cannot click anywhere outside the card to dismiss (`MOUSE_FILTER_STOP` on root absorbs all mouse clicks; only `ui_cancel` action dismisses)

**CR-11 [VS]** HUD non-interference: HUD Core hides itself when `InputContext.current() != GAMEPLAY` per HUD Core's own visibility CR (pending **OQ-HUD-3** verification). The Overlay does NOT manipulate `HUDCore.visible` directly — that would violate FP-OV-5 (`overlay_manages_hud_visibility`). The Overlay trusts that HUD Core's `InputContext` check fires correctly when `DOCUMENT_OVERLAY` is pushed.

**CR-12 [VS]** Section-unload close: when Mission & Level Scripting fires its pre-unload signal, if `_state == READING`, the Overlay must execute the close lifecycle (§C.5) synchronously before acknowledging the unload, WITHOUT waiting for player `ui_cancel`. This is the only non-player-initiated dismiss. Rationale: per **CR-13** the Overlay is per-section; its lifetime is bounded by the section. The close must call `DC.close_document()` BEFORE DC's `_exit_tree()` runs. **Coord item OQ-DOV-COORD-3 (BLOCKING for sprint)**: MLS GDD must define and emit a pre-unload signal (e.g., `section_unloading(section_id: StringName)`) before any `queue_free()` on section nodes; the Overlay subscribes to this. If `_state == OPENING` or `CLOSING` when section unload fires, the Overlay short-circuits the in-progress transition and runs teardown immediately (skip sepia-out fade — section is going away).

**CR-13 [VS]** Per-section instantiation (per **ADR-0007**): Document Overlay UI is NOT autoload (autoload registry is full at slot #9 = MLS). The Overlay scene is `CanvasLayer` at index 5 (per **ADR-0004 §IG7**), instantiated by MLS as a child of the section root (or a dedicated UI container in the section tree) when the section loads. Lifetime = section lifetime. `queue_free()` happens only at section unload, by MLS — NOT on document dismiss. On dismiss, the card sub-tree is hidden + cleared, but the Overlay scene root persists for the next pickup. The card's content nodes are pooled / re-used across multiple document opens within a section.

**CR-14 [VS]** ADR-0008 Slot 7 sub-claim: when `_state == READING`, the Overlay holds the full 0.3 ms shared Slot 7 cap (HUD Core hides per CR-11, so they do not share simultaneously). When `_state == IDLE` (closed), the Overlay contributes 0 ms — `Card.visible = false`, `RichTextLabel.text = ""`, no `_process` / `_physics_process` (CR-15). Godot does not render invisible CanvasLayer sub-trees. The Overlay does not add per-frame cost in IDLE state. **First-render cost** for a 200-word body in `RichTextLabel` with American Typewriter Regular at 16-18 px: ~1–3 ms one-time spike on Iris Xe at 810p (per **ADR-0004 §Performance Implications**). This spike falls on the open frame, hidden behind the 0.5 s sepia fade transition (player perception masks the spike). **Verification Gate E (ADVISORY)**: confirm first-render time on Iris Xe with worst-case 250-word body; target ≤ 5 ms on the open frame. If > 10 ms, pre-warm the RichTextLabel by assigning `text` one frame before the sepia fade completes.

**CR-15 [VS]** No per-frame processing while open: Overlay has `_process` and `_physics_process` absent (or explicitly `set_process(false)` / `set_physics_process(false)` in `_ready()`). All state transitions are signal-driven (`_on_document_opened`, `_on_document_closed`, `_notification(NOTIFICATION_TRANSLATION_CHANGED)`, `_on_section_unloading`) or input-driven (`_unhandled_input` for `ui_cancel`). `process_mode = Node.PROCESS_MODE_ALWAYS` is set on the Overlay root to ensure `_unhandled_input` continues to fire even if a future system pauses the SceneTree (the project does NOT currently pause SceneTree during reading — InputContext is the input-gating mechanism — but the property is a one-line defensive setting at zero runtime cost). **Contingency (per godot-specialist 2026-04-27)**: the `PROCESS_MODE_ALWAYS` choice is contingent on InputContext remaining the **sole** input-gating mechanism for the Overlay. If a future system introduces SceneTree pausing during reading (e.g., a panic-save dialog), event ordering between the Overlay's `_unhandled_input` and any other `PROCESS_MODE_ALWAYS` consumer of `ui_cancel` becomes undefined; a re-review of the Overlay's process mode is required. This contingency is documented to prevent silent regression if a future contributor adds SceneTree pausing assuming the Overlay tolerates it.

**CR-16 [VS]** Tab / focus-cycle consumption (per accessibility-specialist 2026-04-27, WCAG 2.1 SC 2.1.1 / 2.1.2): the Overlay's `_unhandled_input(event)` consumes `ui_focus_next` (Tab) and `ui_focus_prev` (Shift+Tab) actions when `InputContext.is_active(DOCUMENT_OVERLAY)`. Both actions are absorbed (no focus movement) and `set_input_as_handled()` is called. Rationale: the only legal focused-control inside the Overlay is `BodyScrollContainer` (for keyboard scrolling); there is no second focusable interactive node (FP-OV-9 forbids a Close Button). If Tab were allowed to propagate, focus would either (a) escape the modal subtree to a gameplay node — a focus-trap-escape failure under SC 2.1.2's spirit — or (b) cycle to a hidden HUD widget (HUD is hidden but its focus targets remain registered until HUD's own `InputContext` gate clears them, ordering unverified). Consumption is the safest behavior. Optional AT enhancement (post-VS): on Tab consumption, fire a one-shot polite-priority AccessKit announcement: "Document — use arrow keys to scroll, Escape to close." This avoids the silent-Tab UX surprise without violating the Lectern Pause register.

### C.2 Modal Scene Structure

The Overlay's scene is a per-section `CanvasLayer` instance (CR-13). Card dimensions target **960 × 680 px at 1080p reference** (rationale: 200-word body × ~28 px line-height ≈ 380 px body text + 64 px header + 32+32 px body padding + 30 px footer ≈ 538 px content / 680 px card ≈ comfortable fit without scroll for the median document; longer documents scroll within the body region). Card clamps to `min_size.x = 800` at sub-1280 px viewports (American Typewriter at body size becomes illegible below 800 px wide).

**Scene tree (Godot 4.6 canonical hierarchy):**

```
DocumentOverlayUI (CanvasLayer, layer = 5)              # ADR-0004 §IG7 — locked
└─ ModalBackdrop (Control)
        mouse_filter = MOUSE_FILTER_STOP                # absorbs all mouse clicks behind card
        anchors = PRESET_FULL_RECT                      # full viewport
        process_mode = PROCESS_MODE_ALWAYS              # CR-15
        # _unhandled_input handler lives here (CR-6)
        # accessibility_role = "dialog" (Gate A pending)
   └─ CenterContainer
      └─ DocumentCard (PanelContainer)
            theme_type_variation = "DocumentCard"        # document_overlay_theme.tres
            custom_minimum_size = Vector2(800, 0)
            size = Vector2(960, 680)
         └─ VBoxContainer
            ├─ CardHeader (PanelContainer, h = 64 px)
            │     # BQA Blue #1B3A6B background via StyleBoxFlat
            │  └─ MarginContainer (12 px top/bottom, 24 px left/right)
            │     └─ TitleLabel (Label)
            │             theme_type_variation = "DocumentTitle"
            │             # FontRegistry.document_header() — American Typewriter Bold 20 px
            │             auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED  # CR-7 manual handling
            │             clip_contents = true                                # long titles truncate, never wrap
            │             text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_CHAR
            │                                                                 # ux-designer 2026-04-27: ellipsis on truncate (period-correct typed-document register)
            │             # accessibility_role hint: heading (pending Gate A)
            ├─ CardBody (MarginContainer, 32 px top/bottom + 48 px left/right)
            │     # Parchment #F2E8C8 (inherited from DocumentCard StyleBoxFlat)
            │  └─ BodyScrollContainer (ScrollContainer)
            │          horizontal_scroll_mode = SCROLL_MODE_DISABLED
            │          vertical_scroll_mode = SCROLL_MODE_AUTO                # CR-9 auto-hide bar
            │          smooth_scroll_enabled = false                          # FP-OV-12
            │          theme_type_variation = "DocumentScroll"                # custom 4 px Ink Black bar
            │          mouse_filter = MOUSE_FILTER_STOP
            │          # grab_focus() on this node in C.4 step 7
            │     └─ BodyText (RichTextLabel)
            │             bbcode_enabled = true
            │             fit_content = true
            │             scroll_active = false                               # ScrollContainer owns scroll
            │             autowrap_mode = TextServer.AUTOWRAP_WORD
            │             auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED  # CR-7 manual handling
            │             mouse_filter = MOUSE_FILTER_PASS                    # let mouse wheel reach ScrollContainer
            │             # FontRegistry.document_body() — American Typewriter Regular 16-18 px
            └─ CardFooter (PanelContainer, h = 30 px when only DismissHintLabel; 44 px when ScrollHintLabel is also visible)
               └─ MarginContainer (4 px top/bottom)
                  └─ FooterVBox (VBoxContainer)
                     ├─ ScrollHintLabel (Label)
                     │       text = "overlay.scroll_hint"                     # tr value: "SCROLL — ↑ ↓ / Right Stick"
                     │       auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS
                     │       horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                     │       visible = false                                  # toggled by ScrollContainer overflow detection in C.4
                     │       # FontRegistry.document_body() at 12 px, Ink Black on Parchment
                     │       # ux-designer 2026-04-27: only shown when body overflows card height
                     └─ DismissHintLabel (Label)
                             text = "overlay.dismiss_hint"                    # set in editor
                             auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS  # static key, engine handles
                             horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                             # FontRegistry.document_body() at 12 px, Ink Black on Parchment
                             # tr value: "ESC / B — Return to Operation"
```

**Theme inheritance** (per **ADR-0004 §Decision item 1**, **Gate B BLOCKING**): `document_overlay_theme.tres` sets `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")` — `fallback_theme` is the verified Godot 4.x property for `Theme` parent-chaining (`base_theme` does NOT exist on `Theme` in any 4.x release; reviewer fix per godot-specialist 2026-04-27). All descendant Controls inherit; only the scroll-bar StyleBox + per-widget color overrides live in this surface theme.

**Localization keys required** (Coord OQ-DOV-COORD-5, BLOCKING — **4 keys** as of 2026-04-27 revision):

| Key | English value | Max chars | `# context` cell |
|---|---|---|---|
| `overlay.dismiss_hint` | "ESC / B — Return to Operation" | 55 (raised from 40 per localization-lead 2026-04-27 to fit German 1.5× expansion of "Operation" + glyph tokens) | Footer hint shown at bottom of every document card. Period dossier register; do NOT punch up. The "ESC" and "B" tokens are **literal device-label strings** (not translated); some locales may need to reorder them around the em-dash. Translator must preserve token positions or use a culturally-equivalent device-label convention. Pseudolocalization smoke-test required at 140% before VS milestone close (see new ADVISORY AC in §H.16). |
| `overlay.scroll_hint` | "SCROLL — ↑ ↓ / Right Stick" | 50 | **NEW key per ux-designer 2026-04-27 BLOCKING finding (scroll-discoverability gap)**. Footer hint shown ONLY when body overflows card height (ScrollContainer `vertical_scroll_mode = SCROLL_MODE_AUTO` triggers visibility). Period register; arrow glyphs are literal Unicode (U+2191, U+2193). "Right Stick" refers to the gamepad right thumbstick — translate as the locale's standard term for this controller affordance. |
| `overlay.accessibility.dialog_name` | "Document" | 20 | AccessKit modal dialog announce name. Read on every overlay open before title + body. Translator: keep terse, single noun. |
| `overlay.accessibility.scroll_name` | "Document body" | 25 | AccessKit scroll-region announce name. Fired when body overflows + scroll is engaged. |

**CSV ownership clarification (per localization-lead 2026-04-27, OQ-DOV-COORD-5 amendment)**: the 4 `overlay.*` keys above belong in `translations/overlay.csv` (a NEW file, not in `translations/doc.csv` which is content). `translations/doc.csv` is reserved for document title/body content owned by Writer. The Localization Scaffold §Interactions ownership table must be amended to add a new row for the `overlay.*` namespace owned by this GDD.

**`mouse_filter` configuration:**

| Node | Filter | Rationale |
|---|---|---|
| `ModalBackdrop` (root) | `MOUSE_FILTER_STOP` | Absorb all mouse clicks behind card |
| `BodyScrollContainer` | `MOUSE_FILTER_STOP` | Owns mouse-wheel scroll |
| `BodyText` (RichTextLabel) | `MOUSE_FILTER_PASS` | Let mouse wheel reach ScrollContainer |
| `TitleLabel`, `DismissHintLabel` | `MOUSE_FILTER_IGNORE` | Pure display; no input |

### C.3 State Machine

| State | Description | Entry | Exit | Per-frame cost |
|---|---|---|---|---|
| `IDLE` | No document open. `Card.visible = false`. `RichTextLabel.text = ""`. No `InputContext.DOCUMENT_OVERLAY` on stack. No sepia. Default state on instantiation. | Section load (initial); CLOSING completes | `document_opened` signal received | 0 ms |
| `OPENING` | The 0.5 s sepia-dim transition is in progress (PPS owns the Tween). Card snaps to `visible = true` at frame 0 of OPENING (instant card — no fade-in animation per UX recommendation). InputContext is already pushed. Player can read immediately; sepia fades in around the still card. | C.4 lifecycle executed | Sepia transition complete (Timer or PPS signal — see Coord OQ-DOV-COORD-2) | ≤ 0.3 ms (Slot 7 cap; first-render spike masked by fade) |
| `READING` | Sepia fully active. Card fully readable. Scroll active if body overflows. Only accepted inputs: scroll verbs (CR-9) + `ui_cancel` (CR-6). All gameplay actions blocked by `InputContext`. | OPENING transition complete | `ui_cancel` consumed in `_unhandled_input`; OR `section_unloading` received | ~0.05 ms (idle widget cost; no per-frame work) |
| `CLOSING` | Brief teardown beat. Card has been hidden + cleared synchronously (Option B). PPS sepia is still fading out (0.5 s ease_in_out). `DC.close_document()` has been called. Awaiting `document_closed` signal callback to finalize. | C.5 lifecycle executed | `document_closed` callback receipt | ~0 ms (card invisible; only PPS fade-out runs) |

**Transition table:**

| From | To | Trigger | Guard | Action |
|---|---|---|---|---|
| IDLE | OPENING | `Events.document_opened(id)` | `_state == IDLE` | Execute C.4 open lifecycle (8 steps); `_state = OPENING`; start sepia fade (PPS-owned 0.5 s) |
| OPENING | READING | Sepia transition complete | `_state == OPENING` | `_state = READING` |
| READING | CLOSING | `_unhandled_input` consumes `ui_cancel` | `_state == READING` | Execute C.5 close lifecycle (6 steps); `_state = CLOSING` |
| READING | CLOSING | `section_unloading(section_id)` matches Overlay's section | `_state == READING` | Execute C.5 close lifecycle synchronously, skip sepia-out fade (PPS being torn down by section); `_state = CLOSING` then immediate IDLE |
| CLOSING | IDLE | `Events.document_closed(id)` callback | `_state == CLOSING` | Clear cached keys; `_state = IDLE` |
| OPENING | IDLE | `section_unloading(section_id)` mid-fade | `_state == OPENING` AND id matches | Skip remaining open work; teardown immediately; `_state = IDLE` |
| CLOSING | IDLE | `section_unloading(section_id)` mid-fade | `_state == CLOSING` AND id matches | Already closing; tolerate missing `document_closed` if DC freed first; `_state = IDLE` |

**Defensive transitions:**
- `document_opened` received while `_state ∈ {OPENING, READING, CLOSING}`: `push_error("document_opened in unexpected state: %s" % _state)`; discard (CR-3).
- `ui_cancel` received while `_state ∈ {IDLE, OPENING, CLOSING}`: not consumed by Overlay's `_unhandled_input` because the early-return at the start of the handler checks `if not InputContext.is_active(InputContext.Context.DOCUMENT_OVERLAY): return`.

**Same-frame race row (added 2026-04-27 per systems-designer review)**:

| From | To | Trigger | Guard | Action |
|---|---|---|---|---|
| IDLE | IDLE | `section_unloading(section_id)` matches Overlay's section AND fires same frame as a queued `document_opened(id)` whose Document Resource lives in the section being torn down | `_state == IDLE` | (1) Run E.18 IDLE no-op for `section_unloading`; (2) set internal flag `_section_teardown_in_progress = true`; (3) when the queued `document_opened(id)` fires later in the same frame's signal queue, the C.4 step 1 guard checks both `is_instance_valid(doc)` AND `_section_teardown_in_progress` — if either fails, `push_error("document_opened during section teardown: %s" % document_id)` and early return. The flag clears in `_exit_tree()` (no Overlay reuse expected post-section-unload). This closes the narrow window where DC is mid-`_exit_tree` (still alive but tearing down) and `is_instance_valid()` alone is insufficient. |

### C.4 Open Lifecycle — strict 8-step order

Executed synchronously inside `_on_document_opened(document_id: StringName)`. No `await` between steps; only the AccessKit live-region clear uses `call_deferred`.

```gdscript
func _on_document_opened(document_id: StringName) -> void:
    # CR-3 defensive guard
    if _state != State.IDLE:
        push_error("document_opened in state %s — discarding %s" % [_state, document_id])
        return

    # 1. Cache document keys (NOT resolved values — Localization CR-9 + CR-7)
    var doc: Document = DocumentCollection.get_document(document_id)
    if not is_instance_valid(doc):
        push_error("document_opened with invalid id: %s" % document_id)
        return
    _current_doc_id = document_id
    _current_title_key = doc.title_key
    _current_body_key = doc.body_key

    # 2. Save previous mouse mode (Input CR-8 push/pop discipline)
    _prev_mouse_mode = Input.mouse_mode

    # 3. Push InputContext (ADR-0004 §IG2 — input locked first, before visual change)
    InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)

    # 4. Set mouse mode VISIBLE (Input CR-8)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    # 5. Engage sepia (ADR-0004 §IG4) — respect reduced-motion
    var reduced_motion: bool = SettingsService.get_value(
        "accessibility", "reduced_motion_enabled", false
    )
    if reduced_motion:
        PostProcessStack.enable_sepia_dim(0.0)  # snap, no fade — Coord OQ-DOV-COORD-2
    else:
        PostProcessStack.enable_sepia_dim()      # default 0.5s ease_in_out

    # 6. Resolve tr() at THIS moment (CR-7 + Localization CR-9)
    %TitleLabel.text = tr(_current_title_key)
    %BodyText.text = tr(_current_body_key)  # bbcode_enabled=true → auto-parses

    # 7. Show card + toggle conditional scroll hint + grab focus
    %DocumentCard.visible = true
    %BodyScrollContainer.scroll_vertical = 0  # reset scroll on every open
    # 7a. Toggle ScrollHintLabel based on overflow detection (ux-designer 2026-04-27)
    #     fit_content = true on RichTextLabel means body height is set after _ready;
    #     defer overflow check by one frame to let layout settle.
    call_deferred("_update_scroll_hint_visibility")
    # 7b. Focus target: TitleLabel (heading role announce per accessibility-specialist 2026-04-27)
    #     NOT BodyScrollContainer — heading announce is the AT-correct first focus target.
    #     Keyboard scroll still works because ScrollContainer responds to ui_up/ui_down via
    #     the bubbled action when no other Control consumes them; for analog stick, see CR-9
    #     manual handler in _unhandled_input.
    %TitleLabel.grab_focus()

    # 8. AccessKit one-shot assertive announce (Menu System F.7 pattern)
    #    PSEUDOCODE NOTICE (per godot-specialist 2026-04-27): the property names
    #    `accessibility_live` / `accessibility_role` / `accessibility_name` below
    #    are PENDING Gate A verification against the actual Godot 4.6 AccessKit API.
    #    Confirmed-likely real names: `accessibility_description` (instead of
    #    `accessibility_name`); `accessibility_role` may NOT exist as settable string
    #    on generic Control nodes (roles inferred from node type). Until Gate A closes,
    #    treat steps 7b–8 as DESIGN INTENT, not compilable GDScript. Implementation
    #    must mirror Menu System §F.7's verified pattern, whatever properties that
    #    pattern actually uses in 4.6.
    %ModalBackdrop.accessibility_live = "assertive"  # Gate A pending
    call_deferred("_clear_accessibility_live")        # off next frame
    #    Note (godot-specialist 2026-04-27): if Gate A reveals AT flush happens
    #    BEFORE deferred callbacks within the same frame, switch to two-deep deferral:
    #    `call_deferred("_deferred_clear_dispatch")` where `_deferred_clear_dispatch`
    #    itself calls `call_deferred("_clear_accessibility_live")`. This survives
    #    one extra idle phase and guarantees the assertive state persists through
    #    AT flush. Verified in Gate A; pseudocode here uses the simpler pattern.

    _state = State.OPENING
    _start_opening_to_reading_transition()  # Coord OQ-DOV-COORD-2 — Timer or PPS signal
```

**Lifecycle decisions baked into this order:**
- **Mouse mode saved BEFORE pushing context** (step 2) so the cached value reflects gameplay state, not modal-stack state.
- **Card snaps to `visible = true` at frame 0 of OPENING** (step 7) — instant card, no fade-in animation. The 0.5 s sepia transition happens around the still card (UX-designer recommendation: "the card snapping into position against a still-full-saturation world at frame 0 is correct").
- **Audio duck fires from Audio's own `document_opened` subscription** — NOT called by the Overlay (FP-OV-7 forbids `overlay_calls_audio_api`).
- **Subtitle suppression fires from Subtitle system's own `document_opened` subscription** — NOT called by the Overlay (FP-OV-6 forbids `overlay_manages_subtitles`; ADR-0004 §IG5 owns the rule).

### C.5 Close Lifecycle — strict 6-step order (Input CR-7 silent-swallow prevention)

Executed inside `_unhandled_input(event)` when `event.is_action_pressed(&"ui_cancel")` AND `InputContext.is_active(InputContextStack.Context.DOCUMENT_OVERLAY)`.

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not InputContext.is_active(InputContextStack.Context.DOCUMENT_OVERLAY):
        return  # CR-6: only consume input when this surface is the active modal
    if event.is_action_pressed(&"ui_cancel"):
        _close()

func _close() -> void:
    # CR-3 defensive guard
    if _state != State.READING:
        return  # cannot close from OPENING or CLOSING

    # 1. Consume input event FIRST (Input CR-7 — silent-swallow prevention)
    get_viewport().set_input_as_handled()

    # 2. Restore previous mouse mode (Input CR-8 push/pop discipline)
    Input.mouse_mode = _prev_mouse_mode

    # 3. Pop InputContext (ADR-0004 §IG2)
    InputContext.pop()

    # 4. Disable sepia (ADR-0004 §IG4 — PPS fades over 0.5s; respects reduced-motion via PPS-owned Tween)
    PostProcessStack.disable_sepia_dim()

    # 5. Hide card + clear text SYNCHRONOUSLY (Option B — snappy dismiss)
    %DocumentCard.visible = false
    %TitleLabel.text = ""
    %BodyText.text = ""

    # 6. Notify DC (DC emits document_closed; Overlay's _on_document_closed callback fires)
    DocumentCollection.close_document()

    _state = State.CLOSING

func _on_document_closed(document_id: StringName) -> void:
    # Final state transition: CLOSING → IDLE
    _current_doc_id = &""
    _current_title_key = &""
    _current_body_key = &""
    _state = State.IDLE
```

**ADR-0004 §IG3 documentation inconsistency** (NEW — flag for review): the ADR's illustrative code snippet shows `close()` calling `InputContext.pop()` BEFORE `get_viewport().set_input_as_handled()`. Per **Input CR-7** (the prose contract) and per `AC-INPUT-7.1` (the integration test), the **correct order is consume FIRST, pop second**. The ADR-0004 code snippet is illustrative, not normative; this GDD adopts CR-7 order. **Coord item OQ-DOV-COORD-6 (BLOCKING for sprint)**: ADR-0004 §IG3 code snippet should be amended to match CR-7 prose, OR an explicit "the prose order is authoritative" annotation added.

### C.6 Scroll & Keyboard Navigation Grammar

| Input | Effect | Scroll step | Permitted? |
|---|---|---|---|
| Mouse wheel up/down | `BodyScrollContainer.scroll_vertical -= / += wheel_step` | Engine default (~3 lines per click) | ✅ Primary scroll affordance |
| `ui_up` / `ui_down` (Arrow keys) | Scroll by 1 line-height (~28 px) per keypress | 1 line | ✅ Keyboard parity |
| `ui_page_up` / `ui_page_down` (PageUp/PageDn) | Scroll by 1 page minus 1 line (preserves context) | viewport_h − line_height | ✅ Long-document parity |
| Gamepad right-stick Y | Analog magnitude → scroll velocity, clamped to max step/frame | analog × max_step | ✅ Gamepad parity |
| `Home` / `End` | Jump to top / bottom of body | full | ✅ Period-coherent (1965 reader flips to front/back) |
| Gamepad left-stick | NO effect | — | ❌ Reserved for character movement; remap-during-read causes mental-model confusion |
| `ui_accept` (Enter / A / Cross) | NO effect | — | ❌ No "confirm" verb on documents; nothing to accept |
| Mouse click on body | NO effect | — | ❌ Pillar 5 — no click-to-progress (FP-OV-13 inline glossary links) |
| Touch / swipe | N/A — touch not supported | — | ❌ Platform constraint per `technical-preferences.md` |

**Scroll bar styling**: thin 4 px Ink Black `#1A1A1A` `StyleBoxFlat`, no rounded corners, `MOUSE_FILTER_PASS` so mouse-wheel passes through it. Visible only when content overflows (`SCROLL_MODE_AUTO`). When content fits exactly, no scroll bar; player sees the card bottom and infers there is no more text. `smooth_scroll_enabled = false` (FP-OV-12 forbidden — mobile/tablet inertia is a Pillar 5 violation).

**Coord item OQ-DOV-COORD-7 (ADVISORY)**: art-director defines exact `StyleBoxFlat` for the scroll bar in `document_overlay_theme.tres` — see §V Visual/Audio.

### C.7 NOTIFICATION_TRANSLATION_CHANGED Re-Resolve

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _state == State.READING:
        # Re-resolve from cached keys (CR-7 + CR-8)
        %TitleLabel.text = tr(_current_title_key)
        %BodyText.text = tr(_current_body_key)
        # Reset scroll position — deliberate trade-off (see CR-8 note);
        # may revisit when LTR locales (FR/DE) ship if playtest reveals jarring reset
        %BodyScrollContainer.scroll_vertical = 0
        # Re-grab focus on TitleLabel so AT re-reads the heading (per accessibility-specialist 2026-04-27)
        %TitleLabel.grab_focus()
        # Schedule debounced AT re-announce (300 ms trailing-edge — see C.8 debounce note)
        _restart_locale_announce_debounce()  # timer-driven; suppresses mid-sentence interrupts
```

**Why direct `text` reassignment, not `clear()` + `append_text()`** (rationale clarified 2026-04-27 per godot-specialist review): the load-bearing reason is that **`append_text()` accumulates** — calling it on a re-resolve would concatenate the new locale's body to the previous locale's body, doubling the text. Direct `.text = tr(body_key)` assignment with `bbcode_enabled = true` performs a full internal clear-and-reparse: the engine calls its internal `clear()` and re-tokenizes the BBCode source. This is safe **provided no other code path adds programmatic effects to `BodyText` after the initial render** (e.g., `push_custom_fx`, programmatic tag insertion); the GDD specifies body content is a single `tr()` string with no programmatic post-render effects, so no leak risk exists. **Verification Gate E — promoted to BLOCKING 2026-04-27** per ux-designer (the snap-vs-fade-in argument depends on confirming first-render render is masked by sepia, which depends on this re-render path being clean): confirm in Godot 4.6 editor that `text = tr(body_key)` reassignment after locale change produces no doubled text, no BBCode leakage, and no programmatic-effect carryover. Gate F (ADVISORY) covers the gamepad scroll routing.

**Why `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` on `TitleLabel` and `BodyText`**: these nodes set their `text` property at runtime from cached keys; engine auto-resolution would call `tr()` at the wrong moment (with potentially-stale key state). The footer's `DismissHintLabel` uses `AUTO_TRANSLATE_MODE_ALWAYS` because its key is static and engine handling is safe. **Verification Gate D — CLOSED 2026-04-27** per godot-specialist review: enum is `Node.AutoTranslateMode` introduced in Godot 4.5, with verified constants `Node.AUTO_TRANSLATE_MODE_ALWAYS`, `Node.AUTO_TRANSLATE_MODE_DISABLED`, `Node.AUTO_TRANSLATE_MODE_INHERIT`. Bare identifiers in scene files serialize to integer values; bare identifiers in GDScript resolve via `Node` inheritance.

### C.8 AccessKit / Accessibility Floor

(All `accessibility_*` property names below are pending **Verification Gate A** — ADR-0004 Gate 1 BLOCKING. Treat the property assignments in this section as **pseudocode / design intent** until Gate A confirms actual Godot 4.6 AccessKit API surface — likely real names: `accessibility_description` instead of `accessibility_name`; `accessibility_role` may be inferred from node type rather than settable as a string property; `accessibility_live` semantics unverified. Per godot-specialist 2026-04-27.)

**New BLOCKING Verification Gate G** (added 2026-04-27 per accessibility-specialist review): confirm whether `RichTextLabel` with `bbcode_enabled = true` exposes the **parsed plain text** to AccessKit, or the **raw BBCode source string** including markup tags (e.g., `[b]CLASSIFIED[/b]`). If raw BBCode is exposed, a screen-reader user hears literal "open bracket b close bracket CLASSIFIED open bracket slash b close bracket" — a SC 1.3.1 (Info and Relationships) failure for every document body using formatting. Resolution paths if Gate G fails: (a) maintain a parallel BBCode-stripped plain-text string written to a separate AT-only property (e.g., `accessibility_description`); (b) restrict body content authoring to BBCode-free strings (heavy constraint on Writer brief — would forbid `[b]`, `[i]`, `[color]` in document bodies). Gate G must close before any body content using BBCode formatting can ship.

| Node | `accessibility_role` | `accessibility_name` source | Notes |
|---|---|---|---|
| `ModalBackdrop` | `dialog` | `tr("overlay.accessibility.dialog_name")` → "Document" | Modal-dialog role; AT treats focus as trapped inside until dismissed (matches Menu System ModalScaffold pattern) |
| `TitleLabel` | `heading` (level 1 if available; else `label` with explicit `accessibility_name`) | `TitleLabel.text` | First focus-announce target on open |
| `BodyText` | `text` / `document` | `BodyText.text` | AT reads full body content; `accessibility_multiline = true` if exposed |
| `BodyScrollContainer` | `scroll_area` (or `scrollbar` container equivalent) | `tr("overlay.accessibility.scroll_name")` → "Document body" | AT announces as scrollable when content overflows |
| `DismissHintLabel` | `static_text` | `DismissHintLabel.text` | Low-priority static announcement; NOT in initial open-announce sequence |

**Open-announce sequence (revised 2026-04-27 per accessibility-specialist):**

The previous spec described a single flat assertive flush on `ModalBackdrop` containing "Document. Title. Body." as one undifferentiated string. That is **not** the AT-correct pattern: screen readers traverse accessibility trees and child-node read order is not guaranteed by setting `accessibility_live` on a parent container; flattening also negates the heading role on `TitleLabel`. Revised pattern:

1. **C.4 step 7b** moves keyboard focus to `TitleLabel` via `grab_focus()`. AT (NVDA / Orca) reads the focused element automatically — `TitleLabel`'s `heading` role triggers a "heading level 1: [title]" announcement natively.
2. **C.4 step 8** sets `ModalBackdrop.accessibility_live = "assertive"` for ONE frame to announce the dialog-role context: "Document." This is the modal-context cue, not a content dump.
3. The body is reachable via subsequent focus navigation: arrow keys scroll the body within the focused `TitleLabel` → `BodyScrollContainer` flow (per Godot 4.6 ScrollContainer focus chain). AT users either read the body via screen-reader virtual buffer (mode-dependent) OR via explicit `BodyText` focus on Tab — but Tab is consumed by CR-16, so the virtual-buffer / arrow-key-through-content path is the primary mechanism.

Implementation: focus + assertive together. `call_deferred` to set assertive back to `"off"` next frame (or two-deep deferral per CR-Gate-A note above). Same one-shot pattern used by **Menu System §F.7** + **Settings & Accessibility AC-SA-5.X**.

**Locale-change announce** (C.7): re-announce both title (via re-grab_focus on TitleLabel — fires fresh focus event) and dialog-role assertive. **Debounce (added 2026-04-27 per accessibility-specialist E.24 finding)**: if `NOTIFICATION_TRANSLATION_CHANGED` fires multiple times within 300 ms (rare but possible if a locale switcher debouncer is missing upstream), the assertive re-announce fires only once at the trailing edge of the burst. Implementation: a single shared `Timer` with `wait_time = 0.3, one_shot = true`; each notification restarts it; on `timeout`, the actual re-announce executes. Suppresses mid-sentence assertive interruption of AT readout. The content has changed; AT users hear it once at the end of the burst, not multiple times.

**Close announce**: silent. AT context returns to gameplay.

**Reduced-motion** (`accessibility.reduced_motion_enabled == true`): the 0.5 s sepia fade must be instant (0 s). The card-snap (already instant) is unaffected. **Audio duck is NOT suppressed** by reduced-motion (per Audio's reduced-motion rule + Settings GDD CR-21). **Coord item OQ-DOV-COORD-2 (BLOCKING for sprint)**: PPS GDD must expose either `enable_sepia_dim(duration_override: float = 0.5)` (recommended) OR `enable_sepia_dim_instant()` for reduced-motion compliance. Until that API lands, the Overlay's reduced-motion path cannot be implemented.

### C.9 Forbidden Patterns

Sixteen patterns. Each registered in `docs/registry/architecture.yaml` under `forbidden_patterns` and enforced by CI grep + code review.

| ID | Pattern | Violation form | Enforced by |
|---|---|---|---|
| **FP-OV-1** | `overlay_emits_document_signal` | `Events.document_opened.emit(...)` / `Events.document_closed.emit(...)` / `Events.document_collected.emit(...)` from Overlay scene tree | DC CR-7 sole-publisher; project-wide CI lint |
| **FP-OV-2** | `auto_dismiss_overlay` | Any `Timer`, `Tween`, or signal handler that closes the Overlay without explicit `ui_cancel` (except CR-12 section-unload) | §B refusal "Not fast"; CR-6 |
| **FP-OV-3** | `overlay_zoom_or_pan` | Post-render transform on the card (scale tween, position tween, shader zoom effect) | §B refusal "Not cinematic"; Lectern Pause anchor |
| **FP-OV-4** | `cached_translation_value` | `var _body_text: String = tr(body_key)` cached without re-resolve on `NOTIFICATION_TRANSLATION_CHANGED` | Localization CR-9; CR-7 |
| **FP-OV-5** | `overlay_manages_hud_visibility` | Overlay sets `HUDCore.visible = false` or calls HUD visibility methods | CR-11; HUD Core owns its own `InputContext` gate |
| **FP-OV-6** | `overlay_manages_subtitles` | Overlay suppresses, hides, or re-enables subtitles | ADR-0004 §IG5; Subtitle subscribes itself |
| **FP-OV-7** | `overlay_calls_audio_api` | Overlay calls `AudioServer` duck/unduck, sets bus volumes, or touches Audio system directly | Audio owns music duck via own subscriptions |
| **FP-OV-8** | `nested_document_open` | Code path that opens a second Overlay instance while one is active | DC CR-12 invariant; CR-3 defensive guard |
| **FP-OV-9** | `dismiss_via_focused_button` | Visible Close/Done Button that holds focus and is activated with `ui_accept` | ADR-0004 §IG3; sidesteps 4.6 dual-focus split; CR-6 |
| **FP-OV-10** | `progress_indicator_during_read` | X-of-Y / scroll-percentage / word-count / "time spent reading" indicator | §B refusal "Not a codex"; Lectern Pause |
| **FP-OV-11** | `secondary_action_buttons` | "Add to favorites", "Share", "Translate this", "Mark as important" Buttons | §B refusal "Not interactive"; Pillar 5 |
| **FP-OV-12** | `smooth_scroll_interpolation` | `ScrollContainer.smooth_scroll_enabled = true` | §B refusal "Not interactive"; Pillar 5 |
| **FP-OV-13** | `inline_glossary_links` | BBCode `[url=doc.X]term[/url]` in body content; clickable terms branching to other documents | §B refusal "Not a codex"; CSV body cells must contain no `[url=...]` tags |
| **FP-OV-14** | `typewriter_entry_animation` | Body text appears character-by-character on open via Tween reveal | §B refusal "Not cinematic"; photosensitivity |
| **FP-OV-15** | `overlay_subscribes_gameplay_events` | Overlay subscribes to `player_damaged`, `alert_state_changed`, `enemy_killed`, etc. | InputContext blocks gameplay during DOCUMENT_OVERLAY; CR-1 sole-subscriber |
| **FP-OV-16** | `richtext_append_on_open` | Calling `BodyText.append_text(tr(body_key))` instead of `BodyText.text = tr(body_key)` for initial render or re-resolve | Godot-specialist Section 2; CR-8 idempotent re-render |

### C.10 Interactions Matrix

| System | Direction | Nature of interaction |
|---|---|---|
| **Document Collection (#17)** | Overlay subscribes; DC initiates | DC fires `document_opened` per CR-2 Option A; Overlay's `_on_document_opened` runs C.4 lifecycle. On dismiss, Overlay calls `DC.close_document()` (C.5 step 6); DC emits `document_closed`; Overlay's `_on_document_closed` finalizes IDLE (CR-1 + CR-2). DC is sole publisher per DC CR-7. |
| **Post-Process Stack (#5)** | Overlay calls API | Calls `PostProcessStack.enable_sepia_dim()` on open (C.4 step 5), `disable_sepia_dim()` on close (C.5 step 4). Reduced-motion: `enable_sepia_dim(duration_override=0.0)` per Coord OQ-DOV-COORD-2 (BLOCKING amendment). PPS owns the shader, the transition curve, and the Tween. Overlay owns the timing only. |
| **Input (#2)** | Overlay reads action + writes mouse mode | Reads `event.is_action_pressed(&"ui_cancel")` in `_unhandled_input` (C.5). Reads `Input.mouse_mode` (save) and writes `Input.mouse_mode = MOUSE_MODE_VISIBLE / _prev_mouse_mode` (C.4 step 4 / C.5 step 2 per Input CR-8). Consumes input via `get_viewport().set_input_as_handled()` (C.5 step 1 per Input CR-7). |
| **InputContext autoload (ADR-0004)** | Overlay calls API | Calls `InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)` on open (C.4 step 3), `InputContext.pop()` on close (C.5 step 3). Reads `InputContext.is_active(...)` in `_unhandled_input` to gate the dismiss handler. |
| **Localization Scaffold (#7)** | Overlay calls `tr()` | Calls `tr(_current_title_key)` and `tr(_current_body_key)` at C.4 step 6 + C.7 re-resolve. Handles `NOTIFICATION_TRANSLATION_CHANGED` for live locale change. Per Localization CR-9, NEVER caches resolved values; only keys. Adds 3 new translation keys to `translations/doc.csv` or `translations/overlay.csv` (Coord OQ-DOV-COORD-5). |
| **Audio (#3)** | Indirect (Audio subscribes DC's signals) | Audio's `document_opened` subscription ducks music to `document_overlay_music_db = -10 dB` and ambient to `document_overlay_ambient_db = -20 dB`. Overlay does NOT call any Audio API (FP-OV-7 forbids). Audio's reduced-motion behavior: cues NOT suppressed (Audio reduced-motion rule). |
| **Subtitle System (Dialogue & Subtitles #18, when authored)** | Indirect (Subtitle subscribes DC's signals + InputContext) | Subtitle suppresses ambient VO when `InputContext.is_active(DOCUMENT_OVERLAY)` per ADR-0004 §IG5. Subtitle subscribes to `document_opened`/`document_closed` directly. Overlay does NOT manage subtitles (FP-OV-6 forbids). |
| **HUD Core (#16)** | Indirect (HUD's own InputContext gate) | HUD Core hides itself when `InputContext.current() != GAMEPLAY` (HUD's own visibility CR pending OQ-HUD-3). Overlay does NOT manipulate HUD visibility (FP-OV-5 forbids). |
| **Mission & Level Scripting (#13)** | MLS instantiates + section-unload signal | MLS instantiates the Overlay scene per-section per CR-13. MLS emits `section_unloading(section_id)` (NEW signal — Coord OQ-DOV-COORD-3 BLOCKING). Overlay subscribes; on receipt during READING, executes C.5 close lifecycle synchronously (CR-12). |
| **Settings & Accessibility (#23)** | Overlay reads setting | Reads `SettingsService.get_value("accessibility", "reduced_motion_enabled", false)` at C.4 step 5 to decide between `enable_sepia_dim()` (default 0.5 s fade) and `enable_sepia_dim(0.0)` (instant) per Coord OQ-DOV-COORD-2. |
| **Save / Load (#6)** | NO interaction | Overlay state is ephemeral. `_open_document_id` is NOT persisted (DC §E.12 confirmed). On load-from-save, no document is open by design. |
| **Combat & Damage (#11)** | NO interaction | Combat doesn't fire while `InputContext.DOCUMENT_OVERLAY` is active (per Combat's own context gate). Overlay does NOT subscribe to combat signals (FP-OV-15 forbids). |
| **Civilian AI (#15) / Stealth AI (#10)** | NO interaction | AI doesn't pause for reading; the world ticks normally. NPC behavior is independent of Overlay state. (Pillar 3 — the world doesn't actually freeze; sepia is dramaturgical, not literal.) |
| **Outline Pipeline (#4)** | NO interaction | Outline pass runs before sepia per ADR-0001. Card is on CanvasLayer 5 (above sepia at 4) — outlines don't apply to UI. |
| **Failure & Respawn (#14)** | NO interaction | Death cannot occur while DOCUMENT_OVERLAY is active (combat blocked). Save/Load doesn't persist overlay state. |

### C.11 Bidirectional Consistency Check

| Upstream GDD reference | Element | Status |
|---|---|---|
| `design/gdd/document-collection.md` §C.10 + CR-11 + §F.5 item #6 + §G | Forward-dep contract: "Overlay calls DC.open_document(id)/DC.close_document()" + "Overlay GDD when authored must adopt this contract" | ✅ Adopted (CR-2 + CR-3 + C.4-C.5) |
| `design/gdd/document-collection.md` §E.12 | "Overlay's UI is not auto-restored on load" | ✅ Aligned (Save/Load NO interaction in C.10) |
| `design/gdd/post-process-stack.md` §Interactions row Document Overlay UI | "Calls PostProcessStack.enable_sepia_dim() on open(), disable_sepia_dim() on close(). Per ADR-0004." | ✅ Adopted (C.4 step 5 + C.5 step 4) — but PPS GDD must amend to expose duration override (Coord OQ-DOV-COORD-2) |
| `design/gdd/post-process-stack.md` §Open Questions row 1 | "Should Menu System's pause overlay use the same sepia dim as Document Overlay?" | ℹ️ Closed by Menu System (uses 52% Ink Black overlay, NOT sepia tint per registry note) — Document Overlay is the only consumer of sepia tint at MVP/VS |
| `design/gdd/input.md` §Interactions Group 5 | "ui_cancel — Document Overlay UI consumer" | ✅ Adopted (CR-6 + C.5 step 1) |
| `design/gdd/input.md` Core Rule 7 | "consume first, pop second" | ✅ Adopted (C.5 step 1 BEFORE step 3) |
| `design/gdd/input.md` Core Rule 8 | "modals push MOUSE_MODE_VISIBLE on open, restore on close" | ✅ Adopted (C.4 step 2 + step 4 + C.5 step 2) |
| `design/gdd/localization-scaffold.md` Interactions row Document Overlay UI | "Consumes doc.header.* + overlay UI labels" | ✅ Adopted (3 new keys per Coord OQ-DOV-COORD-5) |
| `design/gdd/localization-scaffold.md` CR-9 (`cached_translation_at_ready`) | Forbidden pattern | ✅ Adopted as FP-OV-4 |
| `design/gdd/audio.md` §Tuning Knobs L446-447 | `document_overlay_music_db = -10 dB`, `document_overlay_ambient_db = -20 dB` | ✅ Aligned (Audio owns dB; Overlay just enables sepia) |
| `design/gdd/hud-core.md` §UI-2 + InputContext gate | "HUD hides when InputContext.current() != GAMEPLAY" | ✅ Aligned (Overlay doesn't manipulate HUD per FP-OV-5) |
| `docs/architecture/adr-0001-stencil-id-contract.md` §103 | Sepia ColorRect is stencil-0 exception | ✅ Aligned (PPS owns the ColorRect; Overlay never touches stencil) |
| `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` Document domain | DC sole publisher; Overlay subscriber-only | ✅ Adopted (CR-1 + FP-OV-1) |
| `docs/architecture/adr-0004-ui-framework.md` §IG2 + §IG3 + §IG4 + §IG7 + §IG11 | All 5 contracts (InputContext push/pop, dismiss pattern, sepia lifecycle, CanvasLayer 5, RichTextLabel) | ✅ Adopted — but flag IG3 code/prose order inconsistency (Coord OQ-DOV-COORD-6) |
| `docs/architecture/adr-0007-autoload-load-order-registry.md` | "Document Overlay UI is NOT autoload" (slot #9 = MLS) | ✅ Adopted (CR-13) |
| `docs/architecture/adr-0008-performance-budget-distribution.md` Slot 7 | UI 0.3 ms shared | ✅ Adopted (CR-14) |

### C.12 Coordination Items + Verification Gates Emerging from §C

**11 BLOCKING coord items for sprint** (revised 2026-04-27 from 6 → 11; consolidated for §F Dependencies):

1. **OQ-DOV-COORD-1**: DC §C.10 / CR-11 confirmation — DC adopts Option A auto-open contract (single `interact` triggers `DC.collect()` + `DC.open_document()` in same handler, before frame end)
2. **OQ-DOV-COORD-2**: PPS GDD amendment — expose `enable_sepia_dim(duration_override: float = 0.5)` (recommended) OR `enable_sepia_dim_instant()` for reduced-motion compliance
3. **OQ-DOV-COORD-3**: MLS GDD amendment — define + emit `section_unloading(section_id: StringName)` pre-unload signal that Overlay subscribes for CR-12 force-close
4. **OQ-DOV-COORD-4**: Writer brief amendment — body word-count ceiling **no minimum, 250 words English hard ceiling** per document (per game-designer 2026-04-27: 150-word floor unjustified, comedy benefits from terse dispatches; Lectern Pause requires single-read absorption; documents above 250 words violate the fantasy). German document/dossier register expansion ceiling 1.5× → 375 words rendered max.
5. **OQ-DOV-COORD-5**: Localization Scaffold authoring — **4 new keys** (raised from 3 per ux-designer 2026-04-27 scroll-discoverability finding): `overlay.dismiss_hint`, `overlay.scroll_hint` (NEW), `overlay.accessibility.dialog_name`, `overlay.accessibility.scroll_name`. Owned in NEW file `translations/overlay.csv` (NOT `translations/doc.csv` — content vs UI separation). Localization Scaffold §Interactions ownership table must be amended to add `overlay.*` namespace row.
6. **OQ-DOV-COORD-6**: ADR-0004 §IG3 documentation fix — code snippet shows wrong dismiss order (pop before set_input_as_handled); annotate that Input CR-7 prose order is authoritative
7. **OQ-DOV-COORD-8**: Confirm whether `DC.close_document()` emits `document_closed` synchronously (within same call stack) NOT via `call_deferred`. Synchronous strongly preferred — collapses CLOSING state duration to zero, eliminates E.4 exposure window
8. **OQ-DOV-COORD-9**: `_on_section_unloading` handler must include OPENING-state teardown branch (not just READING via C.5 `_close()`). Required for E.7, E.19. Branch: pop InputContext, restore mouse mode, `disable_sepia_dim()`, hide card, `_state = IDLE` — without `DC.close_document()`
9. **OQ-DOV-COORD-10**: CI lint verifying MLS section scripts do not instantiate more than one `DocumentOverlayUI` per section. Plus runtime group-tag assertion in Overlay's `_ready()` (group `&"document_overlay_instances"`, count ≤ 1)
10. **OQ-DOV-COORD-11**: Author `tools/ci/check_forbidden_patterns_overlay.sh` — 13+ ACs cite this script. **Sprint-day-1 task** per qa-lead 2026-04-27 + user decision Q3 (CI script + call-order helper promoted to sprint-day-1, both authored alongside implementation epic). The script itself needs a meta-test AC asserting it catches violations.
11. **OQ-DOV-COORD-12 (NEW 2026-04-27 BLOCKING)**: Settings & Accessibility GDD must add `text_scale_multiplier` (range [1.0, 2.0], default 1.0; safe step 0.25) applied via `FontRegistry.document_*()` to all overlay font sizes at section-load time. Required for WCAG 2.1 AA SC 1.4.4 (Resize Text) compliance per accessibility-specialist 2026-04-27. Without this, the overlay cannot claim SC 1.4.4 conformance — 16 px body + 12 px footer are otherwise unscalable. CR-10 wording amended to clarify the prohibition is on in-overlay session-local controls, not on system-level scaling.
12. **OQ-DOV-COORD-13 (NEW 2026-04-27 BLOCKING)**: Author `tests/unit/helpers/call_order_recorder.gd` — a shared GDScript helper that mocks append to an `Array[StringName]` so tests can assert call ORDER (not just call count). Cited by AC-DOV-1.1 / 2.1 / 4.1 / 5.2. Without it, lifecycle-order ACs cannot be verified in GUT. Pair with a viewport-mock seam for `set_input_as_handled()` per qa-lead 2026-04-27.
13. **OQ-DOV-COORD-14 (NEW 2026-04-27 BLOCKING)**: HUD Core GDD / OQ-HUD-3 must require HUD Core to **kill or pause Tweens** on `InputContext` change to non-GAMEPLAY (not just hide widgets). Otherwise HUD's ADR-0008 Slot 7 contribution is non-zero during overlay open if a Tween is mid-animation — invalidates Overlay's CR-14 "holds full Slot 7 cap alone" claim. Per performance-analyst 2026-04-27.

**1 ADVISORY coord item:**

14. **OQ-DOV-COORD-7**: art-director defines exact `StyleBoxFlat` for the 4 px Ink Black scroll bar in `document_overlay_theme.tres` — covered in §V Visual/Audio

**6 verification gates** (4 BLOCKING + 1 CLOSED + 2 ADVISORY-or-promoted, status revised 2026-04-27):

- **Gate A** [BLOCKING] (ADR-0004 Gate 1): `accessibility_*` property names on custom Controls — required for §C.8 AccessKit table. **Highest implementation risk** per godot-specialist + accessibility-specialist 2026-04-27 — likely real names `accessibility_description` (not `_name`); `accessibility_role` may not exist as settable string. C.4 step 8 + C.7 + C.8 are pseudocode pending Gate A.
- **Gate B** [BLOCKING] (ADR-0004 Gate 2): `base_theme` vs `fallback_theme` — **CLOSED 2026-04-27** by godot-specialist (`fallback_theme` is the correct Godot 4.x property; `base_theme` does not exist). §C.2 corrected.
- **Gate C** [BLOCKING] (ADR-0004 Gate 3): `_unhandled_input()` + `ui_cancel` modal dismiss on KB/M + gamepad — required for CR-6
- **Gate D** [CLOSED 2026-04-27]: `auto_translate_mode` enum names verified — `Node.AUTO_TRANSLATE_MODE_*` exists in Godot 4.5+ (godot-specialist sign-off)
- **Gate E** [BLOCKING — promoted 2026-04-27 from ADVISORY per ux-designer]: `RichTextLabel.text = tr(body_key)` reassignment after locale change produces no doubled text or programmatic-effect carryover in Godot 4.6. Promoted because the snap-vs-fade-in choice (C.4 step 7) depends on first-render being clean and masked by sepia.
- **Gate F** [ADVISORY → RECOMMENDED upgrade for gamepad path per godot-specialist]: ScrollContainer keyboard scroll routing (`ui_up`/`ui_down` etc.) is native; gamepad analog stick is NOT native — CR-9 specifies a manual `_unhandled_input` handler. Verify both paths in Godot 4.6 editor.
- **Gate G** [BLOCKING NEW 2026-04-27 per accessibility-specialist]: `RichTextLabel` with `bbcode_enabled = true` exposes parsed plain text to AccessKit (NOT raw BBCode). If raw BBCode is exposed, every formatted document body fails SC 1.3.1; resolution = parallel AT-only plain-text property OR forbid BBCode in body content. Must close before any body content using BBCode formatting can ship.

## Formulas

> **Honest scope statement**: Document Overlay UI has no balance values. There are no XP curves, no probability distributions, no economy levers, no tuning ranges requiring simulation. Formulas F.1–F.4 below are exclusively rendering and lifecycle budget formulas: F.1 and F.3 account for one-time open and close frame spikes; F.2 characterizes the steady-state per-frame cost during the READING state; F.4 defines the card layout predicate as a clamping identity. None of these contain a free tuning parameter that a designer would adjust to change the player experience. The only values that are tunable belong to upstream systems that this Overlay calls (PPS fade duration, ADR-0008 budget, font size floor, word-count ceiling from §C Coord OQ-DOV-COORD-4) and are documented in §G Tuning Knobs as inherited or upstream-owned constants, NOT as Overlay-owned formulas.

### F.1 — Open-Frame Budget Composition

The open-frame budget formula is defined as:

`T_open = t_signal_dispatch + t_ic_push + t_mousemode_set + t_pps_enable + t_tr_title + t_tr_body + t_rtl_parse + t_title_set + t_scrollcontainer_reset + t_grabfocus + t_accesskit_assertive`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `T_open` | total | float | [0.5, 5.0] ms with FontRegistry preload; [0.5, 10.0] ms cold-atlas without preload (anti-pattern, performance-analyst 2026-04-27) | Total cost of the open-frame one-time spike (all work done synchronously in `_on_document_opened`). Effective worst-case input: **350-word rendered body** (250 English × 1.5 German expansion ceiling per E.11 amendment). |
| `t_signal_dispatch` | s | float | ~0.001–0.005 ms | `Events.document_opened.emit(id)` traversal — depends on N\_subscribers; N=5 (Audio, Overlay, Subtitle, HUD-ctx-listener, MLS-listener). **Assumption**: subscriber handlers return within their own budget; Audio handler cost is Audio's budget, not Overlay's |
| `t_ic_push` | i | float | ~0.001–0.005 ms | `InputContext.push(DOCUMENT_OVERLAY)` — array append + state update on singleton |
| `t_mousemode_set` | m | float | ~0.001 ms | `Input.mouse_mode = MOUSE_MODE_VISIBLE` — OS call, sub-0.01 ms on PC |
| `t_pps_enable` | p | float | ~0.01–0.05 ms | `PostProcessStack.enable_sepia_dim()` — starts PPS-owned Tween; not per-frame cost |
| `t_tr_title` | tt | float | ~0.01–0.03 ms | `tr(title_key)` — TranslationServer hash-lookup of a short string (1–8 words); negligible |
| `t_tr_body` | tb | float | ~0.05–0.30 ms | `tr(body_key)` — lookup of a body string up to 350 words rendered (250 English × 1.5 German); depends on CSV row length and table size |
| `t_rtl_parse` | rp | float | ~0.50–4.20 ms warm-atlas; ~5.0–9.5 ms cold-atlas | `RichTextLabel.text = ...` with `bbcode_enabled = true` — internal BBCode tokenizer + TextServer shaping per line + **glyph atlas population on first font use (cold-atlas case)**; **dominant term** for long-body documents. Cold-atlas case eliminated by `FontRegistry.preload_font_atlas()` at section-load (see 3D-budget mitigation §F.1) |
| `t_title_set` | ts | float | ~0.01–0.05 ms | `Label.text = tr(title_key)` — Label layout recalculation, single line |
| `t_scrollcontainer_reset` | sr | float | ~0.001 ms | `scroll_vertical = 0` — integer write, no layout work |
| `t_grabfocus` | gf | float | ~0.01–0.03 ms | `BodyScrollContainer.grab_focus()` — focus-change notification propagation |
| `t_accesskit_assertive` | ak | float | ~0.001–0.01 ms | Property write + `call_deferred(...)` — deferred, not executed this frame |

**Output Range** (revised 2026-04-27 per systems-designer + performance-analyst): 0.5 ms (50-word English, **warm font atlas**, warm CSV cache) to **~10 ms cold-atlas worst case** (350-word German rendered = 250 English × 1.5 expansion ceiling — see §G.3 amended ceiling — first session-open with FontRegistry NOT yet pre-populating American Typewriter glyphs on Iris Xe at 810p). The previous 5.0 ms ceiling assumed warm-cache subsequent opens; cold-atlas first-open on minimum hardware is realistically 5–15 ms because TextServer (ICU + HarfBuzz) populates the glyph atlas synchronously on first font use. The spike falls on the open frame only; it does NOT recur on subsequent frames within a session.

**Dominant terms:** `t_rtl_parse` and `t_tr_body` account for ~80–95% of T\_open for documents at or above 150 words. `t_rtl_parse` is dominant in cold-atlas case (atlas population work) and remains dominant in warm-cache case (BBCode tokenizer + TextServer shaping per line, scaling with line count).

**3D-render-budget interaction (added 2026-04-27 per performance-analyst BLOCKING)**: T_open is NOT independent of the rest of the open frame. The 16.6 ms 60 fps frame budget is shared with 3D scene render. On the Eiffel Tower scene at Iris Xe 810p, 3D render typically runs ~14 ms; available headroom for the open-frame spike is ~2.6 ms before a frame is dropped. A 5 ms T_open on a 14 ms 3D frame produces a 19 ms frame — a perceptible 50 fps stutter even though the visual content is partially masked by the sepia fade. **Perceptual masking ≠ frame-budget reservation.** Mitigation strategies, in priority order:

1. **FontRegistry.preload_font_atlas() at section-load time (REQUIRED per performance-analyst)**: when MLS instantiates the section, call `FontRegistry.preload_font_atlas(["DocumentTitle", "DocumentBody", "DocumentFooter"])` synchronously during the section's async load (which already absorbs first-time costs). Brings cold-atlas case to warm-cache case before any document is ever opened. Drops T_open ceiling from ~10 ms to ~3 ms. **New coord requirement** — adds row to Coord-2 / FontRegistry: `FontRegistry.preload_font_atlas(font_keys: Array[StringName]) -> void` API.
2. **Pre-warm RichTextLabel** (deprecated as primary mitigation per performance-analyst — fragile timing): the previous "assign text one frame before sepia fade completes" CR-14 note is replaced by atlas pre-population, which is deterministic.
3. Accept stutter as masked: only valid if 3D budget on minimum hardware leaves ≥ 5 ms headroom on the open frame. Verified post-Gate-A in profiler.

**Relationship to ADR-0008 Slot 7:** T\_open is a **one-time spike**, not a per-frame budget claim. It occurs on the open frame only. The Slot 7 0.3 ms cap applies to the steady-state READING per-frame cost (F.2 below). The spike is acceptable because: (a) the sepia fade masks perceptual content artifacts (NOT frame-pacing stutter); (b) the open-frame is not a gameplay-critical frame (the player cannot be harmed while DOCUMENT_OVERLAY is active); (c) the 5 ms ceiling is a soft target with FontRegistry preload; without preload, the realistic ceiling is ~10 ms.

**Worked examples:**
- **Warm-atlas, 200-word English body, Iris Xe at 810p**: t_signal_dispatch ≈ 0.003 ms; t_ic_push ≈ 0.002 ms; t_mousemode_set ≈ 0.001 ms; t_pps_enable ≈ 0.020 ms; t_tr_title ≈ 0.015 ms; t_tr_body ≈ 0.180 ms; t_rtl_parse ≈ 1.800 ms; t_title_set ≈ 0.025 ms; t_scrollcontainer_reset ≈ 0.001 ms; t_grabfocus ≈ 0.015 ms; t_accesskit_assertive ≈ 0.003 ms. **T_open ≈ 2.065 ms**. Comfortably within the 5 ms soft target.
- **Cold-atlas, 350-word German body (worst-case post-FontRegistry-preload)**: same values except `t_rtl_parse` ≈ 4.2 ms (linear-with-lines scaling for 1.5× expansion). **T_open ≈ 4.5 ms**. Within 5 ms ceiling because FontRegistry has already populated the atlas.
- **Cold-atlas, 350-word German body (without preload — anti-pattern)**: `t_rtl_parse` ≈ 9.5 ms (atlas population synchronous on first font use). **T_open ≈ 9.8 ms**. Demonstrates why FontRegistry preload is required, not optional.

### F.2 — Steady-State READING Per-Frame Budget

The steady-state per-frame cost formula is defined as:

`T_read_frame = t_input_idle + t_canvaslayer_render`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `T_read_frame` | total | float | [0.02, 0.10] ms | Total per-frame cost while in READING state (replaces the 0.3 ms Slot 7 cap that HUD Core would otherwise hold) |
| `t_input_idle` | ii | float | ~0.001–0.005 ms | `_unhandled_input` early-return path: checks `InputContext.is_active(DOCUMENT_OVERLAY)`, returns if no `ui_cancel`; near-zero on quiescent frames |
| `t_canvaslayer_render` | cr | float | ~0.02–0.09 ms | Godot renderer: CanvasLayer 5 draw call for `ModalBackdrop`, `DocumentCard`, `TitleLabel`, `BodyText`, `DismissHintLabel`, scroll bar. Static layout = 1 batch per visible element. No shader passes on CanvasLayer 5 nodes |

**Zero terms (must be explicitly confirmed):** The Overlay has `_process` and `_physics_process` absent (CR-15). There is **no per-frame GDScript execution** unless an input event fires or a signal arrives. ScrollContainer has no per-frame GDScript driver; scroll rendering is engine-internal and included in `t_canvaslayer_render`.

**Output Range:** ~0.02 ms (card visible, nothing changing, no scroll input) to ~0.10 ms (scroll bar visible, scroll event processing). Always below the 0.3 ms Slot 7 cap. HUD Core is hidden while overlay is open (CR-11), so the cap is held by the Overlay alone — both simultaneously would be a forbidden state.

**Documented exception (added 2026-04-27 per systems-designer): locale-change frames.** When `NOTIFICATION_TRANSLATION_CHANGED` fires while `_state == READING`, the C.7 handler executes a re-resolve that includes `RichTextLabel.text = tr(_current_body_key)` — the same `t_rtl_parse` cost as F.1's open-frame spike (warm atlas: 0.5–4.2 ms; effectively never cold because the same font has rendered already this session). The [0.02, 0.10] ms steady-state bounds **do NOT apply** on locale-change frames; on those frames T_read_frame ≈ T_open of F.1 (warm atlas). This is one-time-per-locale-event (rare in normal play because InputContext blocks Settings during overlay open per CR-10; reachable via debug injection or external locale change). Slot 7 budget is exceeded for that single frame — the spike is acceptable for the same reasons as F.1's open spike (gameplay-blocking-cleared by InputContext; player not harmable).

**Worked example:** READING state, 200-word body, scroll bar visible, no input this frame. Iris Xe at 810p. t_input_idle ≈ 0.002 ms (DOCUMENT_OVERLAY active, no cancel pressed, early-return executes). t_canvaslayer_render ≈ 0.045 ms (static card, single batch). **T_read_frame ≈ 0.047 ms**. Comfortably within 0.3 ms cap; Slot 7 has ~0.25 ms margin on a quiescent reading frame.

### F.3 — Close-Frame Budget Composition

The close-frame budget formula is defined as:

`T_close = t_input_consume + t_mousemode_restore + t_ic_pop + t_pps_disable + t_card_hide + t_text_clear + t_dc_close`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `T_close` | total | float | [0.05, 1.0] ms | Total cost of the close-frame one-time spike (all work in `_close()`, synchronous) |
| `t_input_consume` | ic | float | ~0.001 ms | `get_viewport().set_input_as_handled()` — sets a flag on the InputEvent in flight; effectively free |
| `t_mousemode_restore` | mr | float | ~0.001 ms | `Input.mouse_mode = _prev_mouse_mode` — OS call, same cost as set in open |
| `t_ic_pop` | ip | float | ~0.001–0.005 ms | `InputContext.pop()` — array pop + state update on singleton |
| `t_pps_disable` | pd | float | ~0.01–0.05 ms | `PostProcessStack.disable_sepia_dim()` — starts the reverse PPS Tween; one-time call |
| `t_card_hide` | ch | float | ~0.001–0.005 ms | `DocumentCard.visible = false` — visibility flag change; Godot skips rendering hidden subtrees on next frame |
| `t_text_clear` | tc | float | ~0.01–0.20 ms | `TitleLabel.text = ""` + `BodyText.text = ""` — clearing text triggers layout invalidation; **much cheaper than setting text** because BBCode parser processes empty string |
| `t_dc_close` | dc | float | ~0.001–0.010 ms | `DocumentCollection.close_document()` — triggers `document_closed` emit synchronously (per Coord OQ-DOV-COORD-8 confirmation pending); DC internal state update + N_subscribers notification |

**Why T_close << T_open:** No `tr()` resolution and no `RichTextLabel` BBCode parse of a long body from source text. `t_rtl_parse` does not appear because `BodyText.text = ""` runs the BBCode tokenizer on an empty string. **Caveat (added 2026-04-27 per systems-designer)**: `RichTextLabel.text = ""` with `bbcode_enabled = true` internally calls `clear()`, which resets internal data structures (item lists, paragraph caches) that **scale with previous content size**. For a 350-word German body that filled many paragraph items, this reset is non-trivial — the cost is O(N) in content items, not constant-time. Verification target: pair with Gate E to measure clear cost at 350-word German.

**Output Range:** ~0.05 ms (minimal path, short document cleared quickly) to ~1.0 ms (pathological case: very long body text clearing on slow hardware with deep BBCode item nesting). Target ≤ 1.0 ms on Iris Xe at 810p. No pre-warm or deferred trick needed.

**Worked examples:**
- **200-word English body dismissal, Iris Xe at 810p**: t_input_consume ≈ 0.001 ms; t_mousemode_restore ≈ 0.001 ms; t_ic_pop ≈ 0.002 ms; t_pps_disable ≈ 0.020 ms; t_card_hide ≈ 0.002 ms; t_text_clear ≈ 0.030 ms; t_dc_close ≈ 0.005 ms. **T_close ≈ 0.061 ms**. Well under 1.0 ms.
- **350-word German body dismissal, Iris Xe at 810p (added 2026-04-27 per systems-designer)**: same values except t_text_clear ≈ 0.450 ms (O(N) clear of larger paragraph item list). **T_close ≈ 0.481 ms**. Still under 1.0 ms ceiling but no longer comfortably so. Verification target post-implementation: confirm in profiler at worst-case 350-word German body.

### F.4 — Card Layout Dimension Predicate

The card width clamping predicate is defined as:

`card_width = clamp(REF_CARD_WIDTH, MIN_CARD_WIDTH, viewport_width)`

and card height is fixed:

`card_height = FIXED_CARD_HEIGHT`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `card_width` | w | int | [800, 960] px | Resolved card width, clamped between minimum readable width and reference design width |
| `REF_CARD_WIDTH` | W_ref | int | 960 px (constant) | Design-reference width at 1920×1080; maximum card width |
| `MIN_CARD_WIDTH` | W_min | int | 800 px (constant) | Minimum readable width for American Typewriter Regular at 16–18 px without forced line breaks degrading readability |
| `viewport_width` | vw | int | [800, 7680] px (runtime) | Current viewport width via `get_viewport_rect().size.x` |
| `card_height` | h | int | 680 px (constant) | Fixed card height at all viewport sizes; ScrollContainer handles overflow |
| `FIXED_CARD_HEIGHT` | H | int | 680 px (constant) | Derived: 200-word body × ~28 px line-height ≈ 380 px + 64 px header + 64 px body padding + 30 px footer + ~142 px margin ≈ 680 px |

**Output Range:** `card_width` ∈ [800, 960] px, clamped. At viewport widths below 800 px (not a supported resolution per `technical-preferences.md` 1080p target), `card_width` = 800 px and CenterContainer may clip — unsupported. At 1920×1080 and above, `card_width` = 960 px (clamped to REF_CARD_WIDTH). `card_height` = 680 px at all viewport sizes — ScrollContainer absorbs overflow.

**Card height clamp added 2026-04-27** (per systems-designer + ux-designer reviews):

`card_height_resolved = min(FIXED_CARD_HEIGHT, viewport_height * MAX_CARD_HEIGHT_VH)`

- `MAX_CARD_HEIGHT_VH = 0.80` (default 80% of viewport height; safe range [0.70, 0.90])
- At 720p viewport: `min(680, 720 * 0.80) = min(680, 576) = 576 px`. Body region absorbs the difference via ScrollContainer; footer dismiss hint remains visible.
- At 1080p+ viewport: `min(680, ≥864) = 680 px`. Reference design size preserved.
- At unsupported 800×600 viewport: `min(680, 480) = 480 px`. Card shrinks; footer remains on-screen (vs prior spec where 680 px card on 600 px viewport clipped the footer with the dismiss hint off-screen — worst-case loss).

**Implementation note:** Godot's `custom_minimum_size = Vector2(800, 0)` on `DocumentCard` handles the width clamp. The height clamp requires a runtime calculation in `_ready()` (or `_on_viewport_size_changed()` for handling resize): `var max_h = get_viewport_rect().size.y * MAX_CARD_HEIGHT_VH; %DocumentCard.size.y = min(FIXED_CARD_HEIGHT, max_h)`. This is a one-time calculation per viewport-size-change, zero per-frame cost. `MAX_CARD_HEIGHT_VH` added as G.1 tunable.

**Worked examples:**
- Viewport 1280×720 → `clamp(960, 800, 1280)` → `card_width = 960`; `card_height = 680`. Card 960×680, centered in 1280×720 viewport (20 px total vertical margin; acceptable)
- Viewport 1920×1080 → `clamp(960, 800, 1920)` → `card_width = 960`; `card_height = 680`. Reference design size
- Viewport 2560×1440 → `clamp(960, 800, 2560)` → `card_width = 960` (clamped to REF_CARD_WIDTH; card does not grow above reference on large monitors). Card 960×680, centered in larger viewport

## Edge Cases

33 edge cases across 8 clusters. Each in the form: condition → exact resolution.

### Cluster A — Open-trigger / lifecycle storm cases (7)

- **E.1** *Double-emit in same frame — DC emits `document_opened` twice (test injection or DC bug)*: `_on_document_opened` fires for `id_A`, sets `_state = OPENING`. Same frame, `_on_document_opened` fires again for `id_B`. **Resolution**: CR-3 guard fires (`_state != IDLE` → `push_error("document_opened in state OPENING — discarding id_B")` → early return). Second event silently discarded. DC CR-12 single-open invariant + CR-3 defensive guard together make this fully contained. Verified by AC-OV-defensive-guard test.
- **E.2** *`document_opened` fires while `_state == OPENING` (pre-sepia-complete)*: **Resolution**: Same as E.1 — CR-3 guard fires, push_error, discard. Currently-opening document unaffected. Reachable only via test injection (DC CR-12 prevents two opens in normal play).
- **E.3** *`document_opened` fires while `_state == READING` (player somehow reaches a second document without dismissing)*: **Resolution**: InputContext.DOCUMENT_OVERLAY blocks `player_interacted` (Input CR-3); DC should not call `open_document()` while `_state == READING`. If reached: CR-3 guard fires, push_error, discard. Open document remains visible; player not in broken state.
- **E.4** *`document_opened` fires while `_state == CLOSING` (race: dismiss in progress, but `document_closed` callback hasn't arrived, and a new pickup fires)*: **Resolution**: CR-3 guard fires (`_state == CLOSING` → push_error → discard). The exposure window depends on DC's emission semantics — if `DC.close_document()` emits `document_closed` synchronously (same call stack), CLOSING duration is zero and this window doesn't exist. **NEW BLOCKING coord item OQ-DOV-COORD-8**: Confirm DC emits synchronously, not via `call_deferred`.
- **E.5** *Player presses `interact` on a new DocumentBody while CLOSING (InputContext popped, gameplay briefly re-enabled)*: **Resolution**: If DC emits synchronously, CLOSING transitions to IDLE within same frame; not exposed. If deferred, `_on_document_opened` fires while `_state == CLOSING` → E.4 guard handles. Either way, defensive guard covers.
- **E.6** *DC is freed (section unloads) mid-OPENING — `DocumentCollection.get_document(id)` at C.4 step 1 returns invalid reference*: **Resolution**: `is_instance_valid(doc)` check at C.4 step 1 catches this: `push_error("document_opened with invalid id: %s")` → early return. `_state` remains IDLE. No sepia, no InputContext push, no mouse mode change. Scene clean.
- **E.7** *MLS fires `section_unloading` while `_state == OPENING` (sepia transition in progress, card visible, InputContext pushed)* — **rephrased 2026-04-27 per systems-designer**: C.4 is specified as synchronous (no `await` between steps), so `section_unloading` cannot interrupt C.4 mid-step. The reachable scenario is: C.4 has fully completed (leaving `_state = OPENING`); the OPENING → READING transition is in progress (sepia fade Tween running); then `section_unloading` arrives. **Resolution**: `_on_section_unloading` must check `_state ∈ {OPENING, READING, CLOSING}` and execute teardown unconditionally for OPENING. For OPENING-state teardown: pop InputContext, restore mouse mode, call `disable_sepia_dim()` (instant — section going away), hide card, `_state = IDLE`. Skip `DC.close_document()` (DC being freed). **BLOCKING coord item OQ-DOV-COORD-9**: `_on_section_unloading` handler must include OPENING-state teardown branch (not just READING).

### Cluster B — Locale + tr() cases (5)

- **E.8** *Locale changes while `_state == READING`*: **Resolution**: C.7 `NOTIFICATION_TRANSLATION_CHANGED` handler fires: `_state == READING` → `TitleLabel.text = tr(_current_title_key)`; `BodyText.text = tr(_current_body_key)`; `scroll_vertical = 0`; AccessKit one-shot assertive re-announce. Player sees title and body refresh in-place; scroll resets to top. Audio duck unaffected (Audio's own subscription). Normal path.
- **E.9** *Locale changes during OPENING (after C.4 step 1 caches keys but before step 6 renders text)*: **Resolution**: NOTIFICATION_TRANSLATION_CHANGED fires while `_state == OPENING`; C.7 handler checks `_state == READING` and returns early (guard). Title and body render correctly at step 6 because step 6 calls `tr(_current_title_key)` fresh — `tr()` at render time uses current locale at execution moment. Happy path for CR-7.
- **E.10** *`title_key` or `body_key` is missing from active locale's CSV (typo or missing translation row)*: **Resolution (clarified 2026-04-27 per localization-lead)**: Godot's TranslationServer fallback chain is: try active locale → fall back to base locale (English per Localization Scaffold default) → return key verbatim if missing from base too. So the "key returned verbatim" outcome only manifests when the key is **absent from the base locale**, not when it's only missing from a secondary locale (which falls back to English). The DC §C.12 lint rule #7 validates every `doc.[id].title` + `doc.[id].body` key pair exists in **the primary/base locale CSV** before section validation passes — this catches the "raw key visible to player" path. Secondary-locale missing keys produce graceful English-fallback output (cosmetic mid-locale-mix; not a Lectern Pause crisis). No Overlay-side handling required.
- **E.11** *Body text expands significantly in non-English locale (German up to 1.5× document/dossier register, French ~1.3×, Russian Cyrillic ~1.2×, CJK ~0.6–0.7× word count but larger glyph minima — CJK out of MVP scope)*: **Resolution (revised 2026-04-27 per localization-lead)**: `RichTextLabel` with `fit_content = true` + `autowrap_mode = AUTOWRAP_WORD` wraps lines normally. Body height increases. `BodyScrollContainer` auto-shows scroll bar (`SCROLL_MODE_AUTO`). Player scrolls normally. The 680 px card height (clamped per F.4 height predicate at small viewports) is not a hard ceiling for body — ScrollContainer clips overflow. The 250-word English ceiling in OQ-DOV-COORD-4 accounts for localization expansion: **250 × 1.5 = 375 words rendered worst-case in German** (raised from 1.4× per localization-lead — workplace-bureaucratic German memoranda/dispatches reach 1.5–1.6× for short-clause-heavy strings due to articles + case endings). 375 words still fits within scroll UX. Reading time at 1.5× expansion: ~110 seconds for German (vs ~75 seconds for English) — within Lectern Pause acceptable band. Authoring constraint propagated to Writer brief via OQ-DOV-COORD-4; not an Overlay edge case.
- **E.12** *`TranslationServer` not yet fully loaded when Overlay's NOTIFICATION_TRANSLATION_CHANGED fires (impossible in normal lifecycle but defensive)*: **Resolution**: This notification is generated by TranslationServer when it finishes loading; cannot fire before initialization. In Godot 4.6 lifecycle, TranslationServer is loaded before any scene's `_ready()`. If `tr()` somehow called pre-init (broken boot): returns key verbatim (same as E.10). External boot-order bug; Overlay behavior correct.

### Cluster C — Mouse mode + InputContext cases (5)

- **E.13** *Overlay opens while previous mouse mode was already MOUSE_MODE_VISIBLE*: **Resolution**: C.4 step 2 saves `_prev_mouse_mode` regardless of current value. Step 4 sets VISIBLE. On close, restore `_prev_mouse_mode = VISIBLE`. Mouse mode is VISIBLE before, during, and after — no net change. Correct regardless of prior modal state.
- **E.14** *InputContext is in unexpected state when C.4 step 3 tries to push DOCUMENT_OVERLAY (orphaned context from prior section's Overlay)*: **Resolution**: `InputContext.push()` unconditionally pushes. Overlay's `_unhandled_input` guard uses `is_active(DOCUMENT_OVERLAY)` which checks TOP of stack, not mere presence. If stale context beneath, Overlay operates correctly. On close, `pop()` removes top (DOCUMENT_OVERLAY). Stale context beneath remains — not Overlay's responsibility. CR-12 section-unload close prevents stale contexts.
- **E.15** *`InputContext.pop()` called before `set_input_as_handled()` (Input CR-7 violation — developer error)*: **Resolution**: `pop()` before `set_input_as_handled()` on the SAME `ui_cancel` event means the event propagates unhandled past the Overlay to the next consumer (Pause Menu opens). Player presses Esc once; Overlay closes AND Pause Menu opens. AC-INPUT-7.1 integration test catches this: synthetic `ui_cancel` to Overlay; verify no Pause-layer signal fires within same frame. AC is BLOCKING for VS, maintained in regression.
- **E.16** *Mouse mode lost on abnormal Overlay exit (`queue_free()` called without `_close()`)*: **Resolution**: `_exit_tree()` safety net: if `_state != IDLE` when exit_tree runs, execute: `Input.mouse_mode = _prev_mouse_mode` (if captured), `InputContext.pop()` (only if DOCUMENT_OVERLAY currently at top of stack — `is_active()` check). Do NOT call `DC.close_document()` (DC may be in own _exit_tree — `is_instance_valid(DocumentCollection)` guard required). Minimal safety net only; primary path is CR-12 section-unload close.
- **E.17** *Overlay closes during same frame another system pushes a new context*: **Resolution**: C.5 step 3 calls `InputContext.pop()` removing DOCUMENT_OVERLAY. If another system pushes new context same frame (e.g. MLS triggers cutscene): stack ordering depends on signal-processing queue order. Per ADR-0004 §IG2, calling systems must check current context before pushing. Overlay just pops its own.

### Cluster D — Section / lifetime cases (5)

- **E.18** *`section_unloading` received while `_state == IDLE`*: **Resolution**: `_on_section_unloading` checks `_state`. IDLE → no-op. Overlay freed normally by MLS. Clean exit.
- **E.19** *`section_unloading` received while `_state == OPENING` (sepia in progress, card visible, InputContext pushed)*: **Resolution**: Per E.7 — execute OPENING-specific teardown branch. Pop InputContext, restore mouse mode, disable sepia (instant — section going away, no player sees it), hide card, `_state = IDLE`. Skip `DC.close_document()`. Coord OQ-DOV-COORD-9 BLOCKING.
- **E.20** *`section_unloading` received while `_state == CLOSING`*: **Resolution**: Overlay already in teardown. C.5 steps 1–3 already done (consumed input, restored mouse mode, popped context). `DC.close_document()` already called (step 6). The `_on_document_closed` callback may or may not arrive before `_exit_tree()`. Set `_state = IDLE` immediately on section_unloading. If `_on_document_closed` fires after, the IDLE-state guard returns early (idempotent clear safe). Tolerate missing `document_closed` callback.
- **E.21** *DC freed (queue_free during section unload) before `document_closed` arrives — DC.close_document() called in C.5 step 6, but DC emits via deferred mechanism*: **Resolution**: If DC emits `document_closed` synchronously (per Coord OQ-DOV-COORD-8 BLOCKING confirmation), this cannot happen. If deferred and DC freed before deferred-emit processes: signal never fires; `_state` stuck CLOSING. `_exit_tree()` safety net (E.16) transitions to IDLE. **Node-teardown ordering caveat (added 2026-04-27 per systems-designer)**: if MLS frees nodes in scene-tree order such that DC's `_exit_tree()` runs **before** the Overlay's `_exit_tree()`, a brief window exists where DOCUMENT_OVERLAY context is still active on the InputContext stack but DC is already freed. During this window, any other system that queries `InputContext.is_active(DOCUMENT_OVERLAY)` (e.g., HUD's visibility gate, Subtitle's suppression check) will see DOCUMENT_OVERLAY active even though no Overlay logic can run. Resolution: the Overlay's `_exit_tree()` safety net MUST execute `InputContext.pop()` before any other consumer reads the stack. MLS authoring convention (per OQ-DOV-COORD-3 amendment) must guarantee Overlay's `_exit_tree()` runs before DC's, OR `InputContext.pop()` must be idempotent on a freed Overlay scene. Document this in MLS GDD section-teardown order spec.
- **E.22** *MLS instantiates a second Overlay scene per section (authoring bug)*: **Resolution**: Both Overlay instances subscribe to `document_opened`. Both fire C.4 lifecycle. Both push InputContext. Both attempt to show card. Result: double-sepia-dim call (PPS must guard or coalesce), double card visible, two InputContext pushes. Serious authoring bug. **NEW BLOCKING coord item OQ-DOV-COORD-10**: Group-tag assertion in `_ready()`: register in `&"document_overlay_instances"` group; assert `get_tree().get_nodes_in_group("document_overlay_instances").size() <= 1` else `push_error("Multiple DocumentOverlayUI instances in section — only one allowed.")`. Plus CI lint on MLS section scripts: max one DocumentOverlayUI scene per section.

### Cluster E — Reduced-motion + accessibility cases (3)

- **E.23** *`reduced_motion_enabled` toggled while `_state == READING`*: **Resolution**: InputContext.DOCUMENT_OVERLAY blocks Settings input (CR-10). Player cannot open Settings while overlay open. Unreachable in normal gameplay. If reached via test harness: current sepia fade Tween (PPS-owned) is not interrupted. The `reduced_motion_enabled` value is read only at C.4 step 5 when `enable_sepia_dim()` is called. Mid-read toggle has no effect on current session; next open reads new value.
- **E.24** *AccessKit screen reader is reading body when locale changes*: **Resolution**: C.7 fires one-shot assertive re-announce: `accessibility_live = "assertive"` on ModalBackdrop; `call_deferred("_clear_accessibility_live")`. The assertive announcement interrupts in-progress AT readout and restarts from beginning of new locale's content. Correct AT behavior — stale content should not continue after locale change. AT user hears "Document. [new title]. [new body]." from start.
- **E.25** *AccessKit property names not yet verified (Gate A BLOCKING-pending) — AT user opens Overlay before Gate A resolved*: **Resolution**: Graceful degradation. If `accessibility_role` is not a valid property in Godot 4.6, assignment is silently ignored (release build) or push_warning (debug). AT user still sees card text via platform accessibility APIs traversing the visual tree. Role announcement ("Document") is lost, but content accessible. Gate A remains BLOCKING for full compliance; this graceful degradation is the pre-Gate-A floor. Tracked in §H ADVISORY gap note.

### Cluster F — Save-load cases (3)

- **E.26** *Player quicksaves while `_state == READING` (quicksave bypasses normal gameplay input)*: **Resolution**: InputContext stack: DOCUMENT_OVERLAY active. Save input actions in GAMEPLAY/PAUSE context, not DOCUMENT_OVERLAY. Quicksave input blocked. If quicksave somehow fires (future system uses polling rather than `_unhandled_input`): DC §E.12 confirms `_open_document_id` NOT persisted in `DocumentCollectionState`. Save captures `collected: Array[StringName]`, no "currently open" flag. On reload, no document open. Correct regardless of whether save fires during read.
- **E.27** *Player loads save (via Main Menu Load Game) while `_state == CLOSING`*: **Resolution**: Loading triggers full scene reload. Section tree (including Overlay scene) `queue_freed`. `_exit_tree()` runs on Overlay (E.16 safety net). Close lifecycle not relevant — scene replaced, not gracefully torn down. New section loads fresh with `_state = IDLE`. No stale state persists per DC §E.12.
- **E.28** *Autosave fires at `section_entered` while `_state == READING` (DC §E.21 / Audio §A.4 coord)*: **Resolution**: Autosave writes `DocumentCollectionState.collected` to disk. Overlay still open and reading. Save does NOT capture `_open_document_id` (DC §E.12). After save completes, Overlay still in READING state. Player continues; dismisses normally. Autosave represents state as of section entry — document collected but not "open." No Overlay-side handling.

### Cluster G — Photosensitivity / visual contract cases (2)

- **E.29** *Sepia fade transition fires same frame as `damage_flash` from Combat (photosensitivity concern — two visual events same frame)*: **Resolution**: While `_state == READING`, InputContext.DOCUMENT_OVERLAY active. Combat's input context gate blocks `player_damaged` from being relevant — but AI ticks and player could theoretically be damaged mid-read. Per C.10: "Combat doesn't fire while DOCUMENT_OVERLAY is active." Overlay's assumption. If Combat damage does fire (future change): `damage_flash` governed by `hud_damage_flash_cooldown_ms = 333 ms` (HUD CR). Sepia fade is separate full-screen ColorRect on CanvasLayer 4 (PPS-owned). Both can coexist. Rate-gate on damage flash (HUD F.1) prevents flash frequency violations regardless of sepia state.
- **E.30** *`reduced_motion_enabled == true` AND `damage_flash_enabled == false` (both accessibility settings active)*: **Resolution**: Sepia is instant (0.0 s per OQ-DOV-COORD-2). Audio duck still fires (Audio reduced-motion rule: cues NOT suppressed). Damage flash globally suppressed by `damage_flash_enabled = false` (Settings CR-16 / Combat subscription). Overlay unaffected — does not call audio API; does not manage damage flash. Card appears instantly. No interaction at Overlay level.

### Cluster H — Forbidden-pattern violation defensive cases (3)

- **E.31** *FP-OV-7 violation: developer adds `AudioServer.set_bus_volume_db(...)` inside Overlay's close handler*: **Resolution**: CI grep rule: scan all `.gd` files under `src/ui/document_overlay/` for `AudioServer`, `AudioStreamPlayer`, `audio_bus`. Any match = BLOCKING CI failure. Caught before merge. If somehow merged: Audio's own `document_closed` subscription handles unduck correctly; Overlay's manual call creates double-unduck race condition.
- **E.32** *FP-OV-1 violation: developer adds `Events.document_opened.emit(new_id)` inside Overlay (misguided "read again" feature)*: **Resolution**: Project-wide sole-publisher CI lint per DC CR-7: scan all files in Overlay scene directory for `Events.document_opened.emit` / `document_closed.emit` / `document_collected.emit`. Any match = BLOCKING CI failure. If merged: Overlay becomes second publisher; its own subscriber fires, triggering C.4 from within C.4, causing infinite re-entrancy. CR-3 guard (`_state != IDLE → push_error → return`) prevents infinite recursion on second re-emit (because `_state == OPENING` after first execution), but first emit still executes C.4 partially twice. CI lint primary defense; CR-3 guard runtime safety net.
- **E.33** *FP-OV-9 violation: developer adds "Done" Button to card footer wiring `ui_accept` to `_close()`*: **Resolution**: CI grep: search for `Button` nodes in Overlay scene `.tscn` and `ui_accept` in `.gd` files. Any Button with `pressed` connected to `_close` = BLOCKING CI failure. Code Review catches: §C.2 scene tree spec has no Button nodes. If merged: Button holds keyboard focus after `BodyScrollContainer.grab_focus()`; if Button steals focus, ScrollContainer no longer receives keyboard scroll. ADR-0004 §IG3 dual-focus split concern realized — `ui_accept` on Button fires dismiss, but Button default `ui_cancel` also fires, causing double-dismiss attempts. CI lint on `.tscn` and `.gd` files is primary guard.

### New BLOCKING Coordination Items Emerging from §E

**OQ-DOV-COORD-8 (BLOCKING)**: Confirm whether `DC.close_document()` emits `document_closed` synchronously (within same call stack) or via `call_deferred`. Synchronous emission strongly preferred: collapses CLOSING state duration to zero, eliminates E.4 exposure window, simplifies E.20 section-unload race. If deferred, Overlay needs one-frame CLOSING window guard.

**OQ-DOV-COORD-9 (BLOCKING)**: `_on_section_unloading` handler must include dedicated OPENING-state teardown branch (not just READING branch from C.5 `_close()`). Required for E.7 + E.19. Teardown for OPENING: pop InputContext, restore mouse mode, call `disable_sepia_dim()`, hide card, `_state = IDLE` — without calling `DC.close_document()` (DC freed).

**OQ-DOV-COORD-10 (BLOCKING)**: CI lint verifying MLS section scripts do not instantiate more than one `DocumentOverlayUI` scene per section. Runtime guard: `_ready()` registers in `&"document_overlay_instances"` group; asserts count ≤ 1 (E.22). Coord with MLS GDD author to add CI check to section-validation lint suite.

## Dependencies

### F.1 Hard upstream dependencies

| System | Why it's hard | Status | Contract Overlay consumes |
|---|---|---|---|
| **Document Collection (#17)** | Without DC, no document data to display; no `document_opened`/`document_closed` signals to subscribe; no `Document` Resource schema to read `title_key`/`body_key` from | ✅ APPROVED 2026-04-27 | DC publishes `document_opened(StringName)` + `document_closed(StringName)`; exposes public methods `DC.open_document(id)` / `DC.close_document()`; Overlay calls these per DC CR-11 |
| **Post-Process Stack (#5)** | The sepia-dim register is the entire dramaturgical contract for the Lectern Pause fantasy. Without PPS's `enable_sepia_dim()` / `disable_sepia_dim()` API, the Overlay has no way to engage the world-recede effect | ✅ Designed (pending review) | PPS exposes lifecycle API; Overlay calls in C.4 step 5 + C.5 step 4. **Pending OQ-DOV-COORD-2 amendment**: duration override for reduced-motion |
| **Input (#2)** | `ui_cancel` action is the only legal dismiss verb (CR-6); `Input.mouse_mode` save/restore (CR-8); `get_viewport().set_input_as_handled()` for CR-7 silent-swallow prevention | ✅ Approved 2026-04-27 pending coord | Input declares `ui_cancel` action (Esc + B/Circle); InputContext autoload (per ADR-0004) |
| **Localization Scaffold (#7)** | All visible text routes through `tr()`; `NOTIFICATION_TRANSLATION_CHANGED` is the live-locale-change mechanism | ✅ Designed (pending review) | `tr()` resolution; `NOTIFICATION_TRANSLATION_CHANGED` notification semantics; CSV authoring for 3 new keys per OQ-DOV-COORD-5 |
| **Mission & Level Scripting (#13)** | MLS instantiates the per-section Overlay scene (CR-13); MLS owns the `section_unloading` pre-unload signal that drives CR-12 force-close | ✅ Designed (pending review) | Per-section scene instantiation; `section_unloading(section_id)` signal contract per OQ-DOV-COORD-3 |
| **Settings & Accessibility (#23)** | Reduced-motion setting drives the sepia-fade-instant path | ✅ Designed (pending review) | `SettingsService.get_value("accessibility", "reduced_motion_enabled", false)` query |
| **Signal Bus (#1)** + **ADR-0002** | Overlay subscribes to Document-domain signals via `Events` autoload | ✅ Revised 2026-04-20 | `Events.document_opened` + `Events.document_closed` declared in ADR-0002 Document domain |
| **ADR-0004 (UI Framework)** | InputContext autoload + FontRegistry static class + Theme inheritance + modal dismiss pattern + sepia-dim lifecycle + CanvasLayer 5 z-order are all from this ADR | Proposed (Gates 1+2+3 BLOCKING) | All 5 contracts (§Decision items 1-3 + IG3 + IG4 + IG7 + IG11) |
| **ADR-0007 (Autoload Order)** | Establishes that Overlay is NOT autoload (per-section scene); registry full at slot #9 = MLS | ✅ Accepted | Confirms per-section instantiation pattern per CR-13 |
| **ADR-0008 (Performance Budget)** | Slot 7 0.3 ms shared UI cap | ✅ Accepted | Slot 7 sub-claim per CR-14 + F.2 budget characterization |

### F.2 Soft upstream dependencies (enhancers, not blockers)

| System | Nature |
|---|---|
| **Audio (#3)** | Audio's own `document_opened`/`document_closed` subscription ducks music to `document_overlay_music_db = -10 dB`. Overlay does NOT call Audio API (FP-OV-7); Audio acts independently. If Audio is silent, Overlay still functions — sepia register is the load-bearing contract; ducked audio is enhancement |
| **Subtitle System (Dialogue & Subtitles #18, when authored)** | Subtitle's own `document_opened`/`document_closed` subscription suppresses ambient VO during DOCUMENT_OVERLAY (ADR-0004 §IG5). Overlay does NOT manage subtitles (FP-OV-6). If Subtitle system is absent (pre-VS), Overlay still functions |
| **HUD Core (#16)** | HUD's own `InputContext.current() != GAMEPLAY` check hides HUD widgets during DOCUMENT_OVERLAY. Overlay does NOT manipulate HUD visibility (FP-OV-5). If HUD is absent, Overlay still renders — but HUD widgets would visually overlap |
| **Outline Pipeline (#4)** | Outline pass runs before sepia per ADR-0001. Outlines render correctly through sepia tint (PPS CR-3 explicit). Indirect — Overlay never touches stencil |

### F.3 Forward dependents (systems that depend on this Overlay)

**None.** Document Overlay UI is a **leaf node** in the dependency graph. No system in the systems-index depends on Document Overlay UI for its own contract. The closest relationships are sibling systems (Audio, Subtitle, HUD Core) that subscribe to DC's signals independently and react to InputContext state — they depend on **DC** and **InputContext**, not on this Overlay.

This means:
- This GDD's revision rarely propagates downstream (only the reverse — upstream changes propagate here)
- This GDD does NOT publish any cross-system contract; all contracts are inherited
- The sole-subscriber + no-emission architecture (CR-1) makes this leaf status structural, not coincidental

### F.4 ADR contracts

| ADR | Status | What this Overlay consumes | What this Overlay supplies (none) |
|---|---|---|---|
| **ADR-0001** (Stencil ID Contract) | ✅ Accepted | Acknowledges that PPS sepia ColorRect is stencil-0 exception; Overlay never touches stencil (UI is screen-space) | — |
| **ADR-0002** (Signal Bus + Event Taxonomy) | ✅ Revised 2026-04-20 (re-review pending) | Subscribes to `document_opened` + `document_closed` from Document domain (DC sole publisher); subscribes to `setting_changed` (filtered to `accessibility.reduced_motion_enabled` only) per query API | — (CR-1 zero-emission) |
| **ADR-0003** (Save Format) | ✅ Accepted | None — Overlay state ephemeral; not persisted (DC §E.12 confirms `_open_document_id` not in save) | — |
| **ADR-0004** (UI Framework) | **Proposed** (3 verification gates BLOCKING) | All 5 contracts: InputContext push/pop §IG2; modal dismiss `_unhandled_input()` + `ui_cancel` §IG3; sepia-dim lifecycle §IG4; CanvasLayer 5 §IG7; FontRegistry static class + RichTextLabel §IG11; Theme inheritance §Decision item 1 | — |
| **ADR-0007** (Autoload Order Registry) | ✅ Accepted | Confirms NOT autoload (slot #9 = MLS); per-section scene per CR-13 | — |
| **ADR-0008** (Performance Budget Distribution) | ✅ Accepted | Slot 7 0.3 ms shared UI cap; CR-14 sub-claim accounting + F.2 characterization | — |

**ADR pre-implementation gates inherited (BLOCKING for sprint start):**
- ADR-0004 Proposed → Accepted promotion (Gates 1 + 2 + 3 below)
- ADR-0004 §IG3 code/prose order documentation fix (Coord OQ-DOV-COORD-6)

### F.5 Forbidden non-dependencies (systems Overlay must NOT touch)

| System | Why forbidden |
|---|---|
| **Combat & Damage (#11)** | InputContext blocks gameplay during DOCUMENT_OVERLAY; Overlay must not subscribe to combat signals (FP-OV-15) |
| **Stealth AI (#10)** | World ticks normally during reading; AI behavior independent (Pillar 3 — sepia is dramaturgical, not literal pause) |
| **Civilian AI (#15)** | Same as Stealth AI; civilians never appear in any UI per CAI Pillar 5 zero-UI absolute |
| **Player Character (#8)** | Overlay does not query PC state; does not modify PC velocity, mouse mode is the only PC-adjacent concern (Input CR-8 ownership) |
| **Failure & Respawn (#14)** | Death cannot occur while DOCUMENT_OVERLAY active (combat blocked); Overlay state ephemeral (not in save) |
| **Save / Load (#6)** | Overlay state NOT persisted (DC §E.12); Overlay does not save/restore anything |
| **Outline Pipeline (#4)** | Card on CanvasLayer 5 (above sepia at 4); outlines do not apply to UI; no stencil writes |
| **Inventory & Gadgets (#12)** | Overlay does not query inventory; pocketing is DC's concern |
| **Cutscenes & Mission Cards (#22)** | Separate VS surface; Overlay and Cutscenes never simultaneously active (Cutscene at CanvasLayer 10; Overlay's InputContext blocks cutscene input anyway) |
| **HUD State Signaling (#19)** | Overlay does not toast events; HSS subscribes to DC's `document_collected` (which Overlay never sees per CR-1) |

### F.6 Coordination items (consolidated from §C + §E)

> **Note (revised 2026-04-27)**: Section §C.12 is the **authoritative** consolidated coord list (13 BLOCKING coord items + 7 verification gates after this revision pass). §F.6 below preserves the original 10-item list for revision-traceability; net additions COORD-12 / COORD-13 / COORD-14 + new Gate G live in §C.12. See §C.12 for current status.

**10 BLOCKING coord items for sprint start** (original list — see §C.12 for the revised 13-item list):

1. **OQ-DOV-COORD-1**: DC §C.10 / CR-11 confirmation — DC adopts Option A auto-open contract (single `interact` triggers `DC.collect()` + `DC.open_document()` in same handler, before frame end)
2. **OQ-DOV-COORD-2**: PPS GDD amendment — expose `enable_sepia_dim(duration_override: float = 0.5)` (recommended) OR `enable_sepia_dim_instant()` for reduced-motion compliance
3. **OQ-DOV-COORD-3**: MLS GDD amendment — define + emit `section_unloading(section_id: StringName)` pre-unload signal that Overlay subscribes for CR-12 force-close
4. **OQ-DOV-COORD-4**: Writer brief amendment — body word-count ceiling 150–250 words per document (Lectern Pause requires single-read absorption); document at `design/narrative/document-writer-brief.md`
5. **OQ-DOV-COORD-5**: Localization Scaffold authoring — 3 new keys (`overlay.dismiss_hint`, `overlay.accessibility.dialog_name`, `overlay.accessibility.scroll_name`) with `# context` cells per §C.2 table + character limits + AT semantics
6. **OQ-DOV-COORD-6**: ADR-0004 §IG3 documentation fix — code snippet shows wrong dismiss order (pop before set_input_as_handled); annotate that Input CR-7 prose order is authoritative
7. **OQ-DOV-COORD-8**: Confirm whether `DC.close_document()` emits `document_closed` synchronously or via `call_deferred`. Synchronous strongly preferred: collapses CLOSING state duration to zero, eliminates E.4 exposure window
8. **OQ-DOV-COORD-9**: `_on_section_unloading` handler must include OPENING-state teardown branch (not just READING via C.5 `_close()`). Required for E.7 + E.19
9. **OQ-DOV-COORD-10**: CI lint verifying MLS section scripts do not instantiate more than one `DocumentOverlayUI` scene per section + runtime group-tag assertion in `_ready()`. Coord with MLS author for CI check
10. **ADR-0004 verification gates** (3 — inherited): Gate A (`accessibility_*` prop names), Gate B (`base_theme` vs `fallback_theme`), Gate C (`_unhandled_input()` + `ui_cancel` dismiss on KB/M + gamepad)

**1 ADVISORY coord item:**

11. **OQ-DOV-COORD-7**: art-director defines exact `StyleBoxFlat` for the 4 px Ink Black scroll bar in `document_overlay_theme.tres` — see §V Visual/Audio

**6 verification gates** (4 BLOCKING + 2 ADVISORY) — see §C.12 for full detail:

- **Gate A** [BLOCKING]: `accessibility_*` property names (ADR-0004 Gate 1 inherited)
- **Gate B** [BLOCKING]: `base_theme` vs `fallback_theme` Theme inheritance prop name (ADR-0004 Gate 2 inherited)
- **Gate C** [BLOCKING]: `_unhandled_input()` + `ui_cancel` dismiss on KB/M + gamepad (ADR-0004 Gate 3 inherited)
- **Gate D** [CLOSED 2026-04-27]: `auto_translate_mode` enum names verified — `Node.AUTO_TRANSLATE_MODE_*` exists in Godot 4.5+ (godot-specialist sign-off)
- **Gate E** [ADVISORY]: RichTextLabel + tr() + NOTIFICATION_TRANSLATION_CHANGED interaction
- **Gate F** [ADVISORY]: ScrollContainer + RichTextLabel keyboard/gamepad scroll routing

### F.7 Bidirectional Consistency Check

Already specified in §C.11 — see that table. All 16 upstream-GDD references checked; ✅ alignment with one OQ-DOV-COORD-6 documentation flag pending on ADR-0004 §IG3.

## Tuning Knobs

> Document Overlay UI owns **zero gameplay tuning knobs** — no balance values, no XP rates, no economy levers, no playtest-tunable feel parameters. The Overlay's behavior is fully specified by upstream contracts. The few "knobs" listed below are: (1) Overlay-owned layout constants that art-direction may amend during Polish; (2) inherited / referenced upstream constants the Overlay consumes; (3) constants explicitly LOCKED by ADR or pillar that cannot be tuned without amendment. The split is documented to make ownership unambiguous.

### G.1 Overlay-owned tunables (7 — revised 2026-04-27 from 3 → 7; Polish-phase art-direction or VS playtest may amend)

| Parameter | Default | Safe range | Effect of increase | Effect of decrease | Owner |
|---|---|---|---|---|---|
| `overlay_card_width_px` | 960 px | [800, 1200] | Wider card; more chars per line; less margin against viewport edges; may break at sub-1280 px viewports | Narrower card; more line breaks; tighter density; below 800 px American Typewriter at body size becomes illegible | art-director (with FontRegistry consultation) |
| `overlay_card_height_px` | 680 px | [540, 800] | Taller card; less scroll for long documents; more vertical viewport coverage; dominates 720p more aggressively | Shorter card; more scroll required; tighter visual presence | art-director |
| `overlay_max_card_height_vh` | 0.80 | [0.70, 0.90] | Card permitted to occupy more vertical viewport at small viewports; risks "dialog-eat-screen" register at 720p above 0.85 | Card more constrained at small viewports; more body content scrolled; risks footer dismiss hint truncation if combined with low viewport-height | ux-designer + art-director (added 2026-04-27 per ux-designer F.4 height-clamp finding) |
| `overlay_scroll_bar_width_px` | 4 px | [2, 6] | Heavier scroll-bar visual weight; more period-anachronistic | Thinner; harder to grab with mouse; sub-2 px is invisible | art-director (per OQ-DOV-COORD-7) |
| `right_stick_scroll_deadzone` | 0.15 | [0.10, 0.25] | Higher floor; more tolerant of controller drift but slower to respond at light deflection; player may feel scroll is unresponsive | Lower floor; more responsive but vulnerable to idle controller drift below 0.10 — direct Lectern Pause violation | game-designer + ux-designer (added 2026-04-27; CR-9 dead-zone) |
| `right_stick_scroll_max_step_px_per_frame` | 18 px | [10, 32] | Faster max scroll velocity; player can skim quickly; risks overshoot past target reading position | Slower max scroll; gentler scroll feel; long German documents take longer to traverse | game-designer + ux-designer (added 2026-04-27; CR-9 max-step) |
| `document_auto_open_delay_s` | 0.0 s (Option A immediate) | [0.0, 2.0] | Adds buffer between pickup and overlay open; safer for patrol-density encounters; risks "input-eaten" feel | Tighter pickup→read coupling per NOLF1 model | game-designer (added 2026-04-27; CR-2-bis Option A-delayed fallback) |

**Why these are tunable**: pure visual / layout choices that don't affect functional contracts. Art-director may revisit during Polish if playtest reveals 720p users feel cramped or 4K users feel cards float in too much empty space.

**Why no others are tunable**: open/close timing is locked by PPS (0.5 s sepia fade — PPS-owned); scroll step sizes are locked by Godot defaults + period grammar (CR-9); mouse-mode push/pop is Input-owned (CR-8); InputContext push/pop is ADR-0004-owned; sepia color/saturation/luminance are PPS-owned (PPS Tuning Knobs §G); audio dB levels are Audio-owned (audio.md §Tuning Knobs); typeface and size floor are FontRegistry-owned (ADR-0004 §IG11).

### G.2 Inherited / referenced upstream constants (Overlay consumes, does NOT own)

| Constant | Value | Owner GDD/ADR | How Overlay uses it |
|---|---|---|---|
| `sepia_dim_transition_duration_s` | 0.5 s | post-process-stack.md §Tuning Knobs | Implicit — Overlay calls `enable_sepia_dim()` and trusts PPS's Tween. The OPENING → READING transition timer (alternative to PPS sepia_dim_complete signal per OQ-DOV-COORD-2) uses this duration |
| `document_overlay_music_db` | -10.0 dB | audio.md §Tuning Knobs L446 | Audio's own subscription consumes; Overlay does NOT call audio API (FP-OV-7) |
| `document_overlay_ambient_db` | -20.0 dB | audio.md §Tuning Knobs L447 | Audio's own subscription consumes; Overlay does NOT call audio API (FP-OV-7) |
| `HUD_SIZE_FLOOR_PX` | 18 px | ADR-0004 §FontRegistry | Implicit — `FontRegistry.document_header()` and `document_body()` return Fonts independent of size; the size floor only applies to HUD numerals via `FontRegistry.hud_numeral(size)` |
| `ui_cancel` action binding | Esc + B/Circle | input.md §C Group 5 | Overlay reads `event.is_action_pressed(&"ui_cancel")` (CR-6) |
| `MOUSE_MODE_VISIBLE` | enum value | Input CR-8 / Godot engine | Overlay sets and restores per discipline |
| `InputContextStack.Context.DOCUMENT_OVERLAY` | enum value 2 | ADR-0004 §IG2 | Overlay pushes/pops |
| `accessibility.reduced_motion_enabled` | false (default) | settings-accessibility.md §C / OQ-SA-3 | Overlay reads at C.4 step 5 to choose sepia fade duration |
| `damage_flash_enabled` | true (default) | settings-accessibility.md §G / Combat CR-16 | Indirect — Combat's subscription gates damage flash; Overlay never sees this directly |
| ADR-0008 Slot 7 cap | 0.3 ms | adr-0008-performance-budget-distribution.md §76 | Overlay's CR-14 sub-claim + F.2 budget characterization respect this cap |

### G.3 Forward-dep tunables (introduced by this GDD; consumed by other systems)

| Parameter | Default | Safe range | Owner | Consumer behavior |
|---|---|---|---|---|
| `document_body_word_count_ceiling` | 250 words English **hard ceiling**, **no minimum** (revised 2026-04-27 per game-designer) | [no_min, 250] hard | Writer brief (`design/narrative/document-writer-brief.md`) per OQ-DOV-COORD-4 | Documents above 250 words English violate the Lectern Pause fantasy (single-read absorption). **No minimum**: 30–50 word terse dispatches are stronger comedy beats than padded-to-floor lore documents (Pillar 1 — the joke should not be explained). German 1.5× expansion ceiling → 375 words rendered worst case, fits scroll UX. The 300-word upper safe-range from the original spec is **removed** — 250 is hard. |

This is the only constant this GDD introduces that another system must respect. Writer + Localization Scaffold consume by enforcing the cap during document authoring + CSV authoring. **The 150-word floor in the previous spec is deleted** per game-designer 2026-04-27: "writers filling space to hit a floor produces verbose lore documents that undermine Pillar 1."

### G.4 LOCKED constants (explicitly NOT tunable — require ADR amendment)

| Constant | Value | Why LOCKED |
|---|---|---|
| Document Overlay CanvasLayer index | 5 | ADR-0004 §IG7 explicit z-order registry — locked by registry note `modal_scaffold_canvas_layer = 20.notes` ("Document Overlay = 5"). Changing breaks layer collision avoidance for HUD/PPS/Pause/Settings/Cutscenes/Subtitles/ModalScaffold/LS-fade |
| Modal dismiss verb | `ui_cancel` action | ADR-0004 §IG3 — Esc + B/Circle binding via Input GDD §C Group 5. Changing requires Input + ADR amendment |
| Sole-publisher of `document_opened`/`document_closed` | Document Collection | DC CR-7 + ADR-0002 sole-publisher discipline. Overlay emitting these signals is a forbidden pattern (FP-OV-1). Cannot be relaxed without breaking architecture |
| Modal dismiss pattern | `_unhandled_input()` + `ui_cancel` action | ADR-0004 §IG3 — sidesteps Godot 4.6 dual-focus split. Cannot use focused Button widget (FP-OV-9) |
| ~~Open trigger contract~~ | ~~Auto-open on pickup (Option A — NOLF1 model)~~ — **REMOVED FROM LOCKED LIST 2026-04-27** per game-designer + creative-director adjudication. Option A is the VS default, but Option A-delayed (per CR-2-bis) is a documented fallback if VS playtest reveals patrol-density issues. **What remains LOCKED**: Option B (archive-only — no auto-open at any time, requiring a separate "read" verb) is locked OUT of VS scope because it rebreaks DC §E.12 deferral. The choice between immediate (Option A, default = 0.0 s) and delayed (Option A-delayed, configurable via `document_auto_open_delay_s` tuning knob) is a feel decision resolved by playtest, not an architectural lock. | n/a — moved to G.1 tunables |
| `tr()` resolution timing | At render time, NOT at `_ready()` | Localization CR-9 — `cached_translation_at_ready` forbidden pattern. Cannot relax without breaking live-locale-change |
| Per-section instantiation (NOT autoload) | Per-section CanvasLayer scene instantiated by MLS | ADR-0007 — autoload registry full at slot #9 = MLS. Cannot become autoload without breaking the registry |
| Visual register | Sepia-dim "suspended parenthesis" | Art Bible §2 + Pillar 3 — locked by player fantasy (Lectern Pause). Cannot ship a different register (e.g. blur, vignette, dark overlay) without redesigning §B fantasy |

### G.5 Absolutes — NOT tuning knobs, design-anchor floors

These are NOT tunable values; they are anchor-enforced absolutes that no Overlay amendment may compromise. **Anchor labels revised 2026-04-27 per game-designer + accessibility-specialist** to distinguish Pillar 5 (period authenticity) from Lectern Pause (player fantasy) from platform-constraint floors — the labels were previously conflated, which obscured the load-bearing reason for each prohibition.

1. **No zoom or pan on the card** — Lectern Pause refusal "Not interactive" + Pillar 5; FP-OV-3
2. **No auto-dismiss timer** — Lectern Pause refusal "Not fast"; FP-OV-2
3. **No music swell on open** — **Lectern Pause anchor (relabeled 2026-04-27 from Pillar 5)** "Not cinematic"; Audio owns duck (not swell). A period-coherent jazz sting on pickup would not violate Pillar 5 (NOLF1 used them); the prohibition is load-bearing for the *fantasy* (the moment is attentive, not theatrical), not for period authenticity.
4. **No "swipe to next page" / horizontal navigation** — Lectern Pause refusal "Not interactive" + Pillar 5
5. **No typewriter character-reveal animation on open** — Lectern Pause refusal "Not cinematic" + photosensitivity floor; FP-OV-14
6. **No inline glossary links / clickable terms** — Lectern Pause refusal "Not a codex" + Pillar 5; FP-OV-13
7. **No progress percentage / X-of-Y counter visible during read** — Lectern Pause refusal "Not a codex" + Pillar 5; FP-OV-10
8. **No recorded voiceover / no Eve-reads-aloud (narrowed 2026-04-27 per accessibility-specialist + user decision Q4)** — Lectern Pause refusal "Not narrated" + Pillar 5 + production-economics floor (Localization Scaffold OQ-2: VO localization is ~10× the cost of text). This absolute prohibits **recorded VO assets**. **Synthesized platform TTS via `DisplayServer.tts_speak()` (Godot 4.4+) is permitted** as a Settings-owned accessibility opt-in (`tts_body_reading_enabled`, default false, a future Settings & Accessibility addition) — TTS is assistive technology, not narrative voice; it has zero localization cost; it does NOT violate Pillar 5 because it is OS-level scaffolding not a diegetic voice. The silent-reading model remains the default; TTS is opt-in only.
9. **No smooth-scroll inertia** — **Platform-constraint floor (relabeled 2026-04-27 from Pillar 5)**: smooth-scroll inertia is a mobile/tablet/touch idiom; Steam targets PC/Linux + Windows without touch input per `technical-preferences.md`. The prohibition is platform-correctness, not period-authenticity (a heavy-paper-page inertia could plausibly be period-coherent; the issue is that touch affordances don't apply to KB/M + gamepad). FP-OV-12.
10. **(NEW 2026-04-27 per game-designer)** **No in-overlay font resize controls** — Pillar 5 + Lectern Pause refusal "Not interactive". The card does not present "A+ / A−" buttons, pinch-to-zoom, font-size sliders, or any session-local typographic-size affordance. CR-10 enforces it mechanically; this absolute names it. **Note**: system-level `text_scale_multiplier` from Settings (per OQ-DOV-COORD-12) is permitted and required for SC 1.4.4 — that knob is owned by Settings & Accessibility and applies globally to FontRegistry, not to in-overlay session state.

A future GDD amendment that proposes relaxing any of these triggers a creative-director gate and must justify against the relevant anchor (Pillar 5, Lectern Pause, platform constraint, or accessibility floor) and the anchor test ("would a 1965 professional reader accept this from the page in front of her?"). Anchor-mislabeling is not allowed: an amendment that wants to add a music swell must justify against the *Lectern Pause* anchor, not Pillar 5.

### G.6 Ownership matrix

| Concern | Owner | Overlay's role |
|---|---|---|
| Card width/height/scroll bar styling | art-director (this GDD §G.1) | Owner |
| Sepia color / saturation / luminance / fade duration | post-process-stack.md §Tuning Knobs | Consumer (calls API only) |
| Music duck dB levels | audio.md §Tuning Knobs | Consumer (Audio's own subscription, indirect) |
| Subtitle suppression rule | ADR-0004 §IG5 + Subtitle System | Consumer (Subtitle's own subscription, indirect) |
| HUD visibility during overlay | hud-core.md (HUD's `InputContext` gate) | Consumer (HUD's own check, indirect) |
| Document body word-count ceiling | Writer brief (introduced by this GDD §G.3) | Forward-dep specifier |
| Document Resource schema (`title_key`/`body_key`) | document-collection.md CR | Consumer |
| Translation key naming convention | localization-scaffold.md §C Rule 2 | Consumer (3 new keys per OQ-DOV-COORD-5) |
| `ui_cancel` action binding | input.md §C Group 5 | Consumer |
| Mouse mode discipline | input.md CR-8 | Consumer (push/pop) |
| `tr()` discipline + `NOTIFICATION_TRANSLATION_CHANGED` | localization-scaffold.md CR-9 | Consumer |
| Per-frame budget Slot 7 | adr-0008 §76 | Consumer (sub-claim + F.2 characterization) |
| AccessKit per-widget roles | settings-accessibility.md AccessKit table + this GDD §C.8 | Co-owner (Overlay-specific surface) |

## Visual/Audio Requirements

### V.1 Card visual register (BQA dossier — Art Bible §7D + §4.4 + ADR-0004 FontRegistry)

The card is a single hard-edged paper artifact rendered at full saturation against the sepia-dimmed world (sepia is on CanvasLayer 4; card on CanvasLayer 5 — sepia does NOT affect the card per PPS CR-3).

| Element | Spec | Source |
|---|---|---|
| Card frame `PanelContainer` | `StyleBoxFlat` Parchment `#F2E8C8`, no rounded corners, no border, no drop shadow, no glow | Art Bible §4.4 + §7D |
| Card header bar `PanelContainer` | `StyleBoxFlat` BQA Blue `#1B3A6B`, 64 px tall, hard-edged top of card | Art Bible §4.4 BQA Blue field |
| Title text `Label` | American Typewriter Bold 20 px, Parchment `#F2E8C8` (text on BQA Blue), `clip_contents = true` + `text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_CHAR` so long titles truncate with "…" (no wrap, no hard pixel-clip) | ADR-0004 §IG11 + FontRegistry.document_header() |
| Body text `RichTextLabel` | American Typewriter Regular 16 px, Ink Black `#1A1A1A` text on Parchment, `bbcode_enabled = true`, `autowrap_mode = AUTOWRAP_WORD`, line-height ~28 px (1.6× leading) | ADR-0004 §IG11 + FontRegistry.document_body() |
| Body padding | 32 px top/bottom, 48 px left/right inside `MarginContainer` | This GDD §C.2 |
| Footer hint `Label` | American Typewriter Regular 12 px, Ink Black on Parchment, centered, 30 px tall, `tr("overlay.dismiss_hint")` ("ESC / B — Return to Operation") | This GDD §C.2 + OQ-DOV-COORD-5 |
| Scroll bar (when content overflows) | `StyleBoxFlat` Ink Black `#1A1A1A`, 4 px wide, no rounded corners, right edge of card body | This GDD §G.1 + OQ-DOV-COORD-7 |
| Card overall dimensions | 960 × 680 px at 1080p; clamps to `min_size.x = 800` at sub-1280 viewports | This GDD §C.2 + F.4 |

**Key visual rules from Art Bible §7D (already applied by Theme inheritance from `project_theme.tres`):**
- Hard-edged rectangles only — no rounded corners, no soft glows, no drop shadows
- BQA Blue header field = "the look of a stamped file folder tab"
- Parchment background = "the look of 1965 carbon paper"
- Ink Black `#1A1A1A` for all text and the scroll bar — never pure `#000000`
- No icons, no decorative ornaments, no flourishes anywhere on the card

### V.2 Sepia-dim register integration (PPS-owned, Overlay calls API)

The sepia-dim effect that sits behind the card is owned by **Post-Process Stack §Formulas F.1** — Overlay does NOT specify any sepia values. Overlay's only role: call `PostProcessStack.enable_sepia_dim()` on open, `disable_sepia_dim()` on close. The 0.5 s ease_in_out fade duration, the 30% luminance multiplier, the 25% saturation, and the warm sepia tint `(1.10, 1.00, 0.75)` are all PPS Tuning Knobs.

The card renders against the sepia-dimmed world. Visually:
- World behind card: 30% luminance, 25% saturation, warm sepia tint
- Card itself: full saturation Parchment + BQA Blue + Ink Black (composes on CanvasLayer 5, above sepia at 4)
- Outline pass runs before sepia, so outlines are still drawn into the dimmed world (PPS CR-3) — cards are screen-space and do not have outlines

### V.3 Scene tree visual layout reference

See §C.2 for the full scene tree. Visual stack from back to front (z-order via CanvasLayer index):

```
CanvasLayer 0 — Gameplay viewport (3D world, may have outline pass)
CanvasLayer 4 — PPS sepia-dim ColorRect (when active; full-screen)
CanvasLayer 5 — Document Overlay UI (this scene)
              └─ ModalBackdrop (full-screen Control, MOUSE_FILTER_STOP)
                 └─ CenterContainer
                    └─ DocumentCard (PanelContainer 960×680 px)
                       └─ VBox: Header / Body / Footer
CanvasLayer 8 — Pause Menu (never simultaneously active per InputContext)
CanvasLayer 15 — Subtitle layer (suppressed during DOCUMENT_OVERLAY per ADR-0004 §IG5)
```

### V.4 Open / close visual choreography

**Open** (per §C.4):
- Frame 0: Card appears at full opacity, full saturation, instantly (no fade-in animation per UX-designer recommendation + §B Lectern Pause refusal "Not cinematic")
- Frames 0–30 (0.5 s at 60 fps): PPS sepia fades in around the still card (PPS-owned Tween)
- Player can begin reading at frame 0 — fade does NOT gate reading

**Close** (per §C.5 + Option B):
- Frame 0: Card disappears synchronously (visible = false; text cleared); player perceives instant return to gameplay color
- Frames 0–30 (0.5 s): PPS sepia fades out (PPS-owned Tween) with no card present
- Card does NOT linger during fade-out (Option B — "operative puts the document away briskly")

**Reduced-motion path** (per §C.4 step 5 + OQ-DOV-COORD-2):
- When `accessibility.reduced_motion_enabled == true`: PPS sepia engages instantly (0 s fade); card behavior unchanged (already instant)
- Audio duck still fires per Audio's reduced-motion rule (cues NOT suppressed)

### V.5 Visual restraint compliance check (Pillar 5 + Lectern Pause)

The card MUST NOT include any of the following visual elements (all forbidden per FP-OV-N + §B refusals):

1. ❌ Inline icons next to the title (no document-type badge, no PHANTOM/BQA logo, no period stamp graphic)
2. ❌ Decorative borders / frames / paper-edge curl
3. ❌ Drop shadows / soft outer glow on the card
4. ❌ Page-flip animation on open or close
5. ❌ Slide-in / fly-in / scale-up entry animation
6. ❌ Typewriter character-reveal animation (FP-OV-14)
7. ❌ ~~Cursor blink in the body~~ — **REMOVED 2026-04-27** per ux-designer review: the body is a `RichTextLabel` with `mouse_filter = MOUSE_FILTER_PASS`, not a `TextEdit` — there is no editable cursor that could blink. The chosen control type structurally prevents this affordance; listing it adds noise without protection.
8. ❌ Inline images (illustrations, photos, signatures embedded in body)
9. ❌ Color-coded category labels (no "MISSION-CRITICAL" red badge, no "LORE" gray badge)
10. ❌ Progress bar / scroll percentage / X-of-Y counter (FP-OV-10)
11. ❌ "Done" / "Close" Button (FP-OV-9)
12. ❌ "Mark as read" / "Add to favorites" / secondary action buttons (FP-OV-11)
13. ❌ Glossary tooltip on hover over body terms (FP-OV-13)
14. ❌ Search bar / filter UI
15. ❌ Tab navigation (Overlay shows ONE document at a time per CR-3; Tab/Shift+Tab consumed and absorbed by CR-16 to prevent focus escape)
16. ❌ Any modern reading-app affordance (chapter list, table of contents, breadcrumbs)
17. ✅ **NEW 2026-04-27 per ux-designer**: Title text MUST truncate with "…" ellipsis at right edge (`TextServer.OVERRUN_TRIM_ELLIPSIS_CHAR`) — never hard-clip without indication, never wrap to a second line. Long titles like "PHANTOM LOGISTICS MEMORANDUM — RE: SHOWTIME VESSEL INTEGRITY — DRAFT 3" truncate to "PHANTOM LOGISTICS MEMORANDUM — RE: SHOWTIME VES…" (period-correct typed-document register where the typist ran out of column space).

### V.6 Asset Spec Flag

📌 **Asset Spec** — Visual requirements for Document Overlay UI are defined. After the art bible is approved, run `/asset-spec system:document-overlay-ui` to produce per-asset visual descriptions for:
- `document_overlay_theme.tres` (Theme resource — `fallback_theme` inheritance to project_theme.tres; Gate B closed 2026-04-27)
- `card_header_stylebox.tres` (BQA Blue StyleBoxFlat, 64 px)
- `card_body_stylebox.tres` (Parchment StyleBoxFlat, full card frame)
- `card_footer_stylebox.tres` (Parchment StyleBoxFlat, 30 px footer continuation)
- `scroll_bar_stylebox.tres` (4 px Ink Black StyleBoxFlat per OQ-DOV-COORD-7)
- Reference screenshots: card at 720p / 1080p / 1440p with worst-case 250-word body / median 200-word body / minimum 50-word body / German pseudolocalization (140% expansion)

### A.1 Audio contracts

Document Overlay UI **owns ZERO audio assets, audio buses, or audio knobs**. All audio behavior associated with the overlay lifecycle is owned by **Audio (system #3)** via its own subscriptions to `Events.document_opened` and `Events.document_closed`.

**Specifically:**
- Music duck to `document_overlay_music_db = -10 dB`: owned by Audio §Tuning Knobs L446
- Ambient suppression to `document_overlay_ambient_db = -20 dB`: owned by Audio §Tuning Knobs L447
- Optional paper-rustle / pen-cap-tock SFX on open/close (per ADR-0004 §Risks "Document Overlay open/close SFX (paper rustle, pen-cap tock per Art Bible 7D) are owned by Audio GDD"): owned by Audio
- Reduced-motion audio behavior (cues NOT suppressed): owned by Audio's reduced-motion rule

**The Overlay does NOT call any audio API** (FP-OV-7). The Overlay's only audio-adjacent action is calling `PostProcessStack.enable_sepia_dim()` — which happens to correlate with Audio's duck, but the Overlay has no knowledge of music state, mix bus levels, or audio assets.

### A.2 Audio reduced-motion rule (inherited from Audio)

When `accessibility.reduced_motion_enabled == true`:
- Visual sepia transition is instant (0 s) — handled by Overlay → PPS via OQ-DOV-COORD-2
- Audio duck and any open/close SFX are NOT suppressed (Audio reduced-motion rule preserves cues for spatial awareness)
- This is a deliberate cross-system asymmetry: visual transitions respect reduced-motion; audio cues do not

### A.3 Forbidden audio patterns (Overlay-specific)

| ID | Pattern | Violation form |
|---|---|---|
| **AFP-OV-1** | `overlay_calls_audio_api` | Overlay calls `AudioServer.set_bus_volume_db()`, `AudioStreamPlayer.play()`, or any audio bus modification (duplicates FP-OV-7 from §C.9 — same pattern, audio-domain framing) |
| **AFP-OV-2** | `overlay_specifies_audio_assets` | This GDD names a specific audio file or SFX cue path (would create dual ownership with Audio GDD) |
| **AFP-OV-3** | `overlay_owns_dB_value` | This GDD specifies a dB value for music or ambient ducking (Audio owns; Overlay only emits the signal indirectly via DC) |

### A.4 Audio coordination (no NEW BLOCKING items from this GDD)

Audio GDD already lists `document_overlay_music_db` and `document_overlay_ambient_db` in its Tuning Knobs (audio.md L446-447) — these are existing constants. Audio also already has a subscription contract for `document_opened` / `document_closed` per ADR-0002 Document domain. No new audio coord items emerge from this GDD; existing audio.md spec is sufficient.

## UI Requirements

### UI-1 Boundary statement

Document Overlay UI **IS** UI — this entire GDD specifies a UI surface. Where most GDDs say "this system has no UI" in this section, this Overlay's §C.2 + §V already cover the full UI specification. This section consolidates the cross-system UI contracts and surfaces the per-screen `/ux-design` flag.

### UI-2 Day-1 vs VS scope matrix

| Concern | Scope | Owner |
|---|---|---|
| Modal scene tree (CanvasLayer 5 + Control hierarchy) | VS — full from sprint start | This GDD §C.2 |
| Open / close lifecycle (8 + 6 step orders) | VS — full from sprint start | This GDD §C.4 + §C.5 |
| Sepia-dim transitions (0.5 s ease_in_out) | VS — full from sprint start | PPS owns; Overlay calls API |
| Scroll grammar (mouse wheel + arrow keys + Page Up/Dn + gamepad right-stick + Home/End) | VS — full from sprint start | This GDD §C.6 |
| `tr()` rendering + `NOTIFICATION_TRANSLATION_CHANGED` re-resolve | VS — full from sprint start | This GDD §C.7 |
| AccessKit per-widget roles + one-shot assertive announce | VS — full from sprint start (pending Gate A) | This GDD §C.8 |
| Reduced-motion sepia-fade-instant path | VS — full from sprint start (pending OQ-DOV-COORD-2) | This GDD §C.4 step 5 |
| Footer dismiss hint ("ESC / B — Return to Operation") | VS — full from sprint start | This GDD §C.2 + OQ-DOV-COORD-5 |
| Document body word-count ceiling (250 words English) | VS — Writer brief amendment per OQ-DOV-COORD-4 | Writer + this GDD §G.3 |
| Subtitle suppression during DOCUMENT_OVERLAY | VS — Subtitle System owns its own subscription | ADR-0004 §IG5 + Subtitle GDD (when authored) |
| Audio music duck + ambient suppression | VS — Audio owns its own subscription | audio.md §Tuning Knobs |
| HUD visibility hide during DOCUMENT_OVERLAY | MVP HARD dep on HUD Core (HUD's own gate) | hud-core.md (pending OQ-HUD-3 verification) |
| Polished case-file archive (re-read collected documents from Pause Menu) | **Polish-or-later** per DC §E.12 — explicitly NOT in this GDD | Future Polish phase work |
| Dynamic glyph swapping for rebound `ui_cancel` keys (footer hint shows current binding) | **Post-VS forward dep** | Settings & Accessibility (rebinding owner) |

### UI-3 Per-screen UX spec flag for Phase 4

📌 **UX Flag — Document Overlay UI**: This system has UI requirements at VS scope. In Phase 4 (Pre-Production / VS sprint planning), run `/ux-design` to create a UX spec at `design/ux/document-overlay.md` covering:

- Card layout final visual spec (margins, padding, header/footer ratios, scroll bar styling — closes OQ-DOV-COORD-7)
- Open / close transition choreography (visual + audio handoff timing)
- AccessKit announcement strings + locale-change re-announce flow
- Reduced-motion path verification (PPS API confirmation per OQ-DOV-COORD-2)
- Pseudolocalization stress test (German 1.4× expansion, French 1.3×, RTL placeholder)
- 720p / 1080p / 1440p reference screenshots with min/median/max document body lengths
- Footer dismiss hint per-locale rendering (Esc / B / Circle glyph swap depending on input device — gamepad-detection logic owned by HUD/Settings, consumed indirectly)

The UX spec is the production-ready hand-off artifact; this GDD specifies the design contract; the UX spec specifies the implementation visual + interaction details.

### UI-4 Anchor-enforced absolute floor (re-stated for UX visibility)

The **10 anchor-enforced absolutes** from §G.5 are restated here as UI requirements (so they are visible to UX/UI implementers). Note: per the 2026-04-27 anchor relabeling in §G.5, these are **NOT all "Pillar 5 absolutes"** — the anchor mix is Pillar 5 + Lectern Pause + photosensitivity floor + production-economics floor + platform-constraint floor. Refer to §G.5 for per-item anchor labels.

1. No zoom / pan on the card *(Lectern Pause + Pillar 5; FP-OV-3)*
2. No auto-dismiss timer *(Lectern Pause; FP-OV-2)*
3. No music swell on open *(Lectern Pause anchor — relabeled 2026-04-27 from Pillar 5; Audio ducks, never swells)*
4. No "swipe to next page" / horizontal navigation *(Lectern Pause + Pillar 5)*
5. No typewriter character-reveal animation *(Lectern Pause + photosensitivity floor; FP-OV-14)*
6. No inline glossary links / clickable terms *(Lectern Pause + Pillar 5; FP-OV-13)*
7. No progress percentage / X-of-Y counter visible during read *(Lectern Pause + Pillar 5; FP-OV-10)*
8. No recorded voiceover / narrated reading *(Lectern Pause + Pillar 5 + production-economics floor; AccessKit reads body directly; synthesized platform TTS via `DisplayServer.tts_speak()` is permitted as a Settings-owned opt-in per §G.5)*
9. No smooth-scroll inertia *(Platform-constraint floor — relabeled 2026-04-27 from Pillar 5; FP-OV-12)*
10. No in-overlay font resize controls *(Pillar 5 + Lectern Pause; system-level `text_scale_multiplier` from Settings is permitted and required for SC 1.4.4 — added 2026-04-27 per game-designer)*

Any UX spec, UI implementation, or future amendment that proposes relaxing any of these triggers a creative-director gate per the relevant anchor test ("would a 1965 professional reader accept this from the page in front of her?"). Anchor-mislabeling is not allowed: an amendment that wants to add a music swell must justify against the *Lectern Pause* anchor, not Pillar 5.

### UI-5 Boundary — what this Overlay does NOT render

Reaffirming §A "This GDD does NOT define" — these surfaces are explicitly NOT this Overlay's UI:

- **HUD widgets** — owned by HUD Core (#16); HUD hides during DOCUMENT_OVERLAY per its own InputContext gate
- **Subtitles** — Subtitle System (#18, when authored) suppresses ambient VO during DOCUMENT_OVERLAY per ADR-0004 §IG5
- **Mission-dossier cards / cutscene transitions** — Cutscenes & Mission Cards (#22)
- **Pause Menu / Save Game grid / Settings panel** — Menu System (#21) + Settings & Accessibility (#23)
- **Document pickup toast / collection counter** — HUD State Signaling (#19, VS) subscribes `document_collected` (which this Overlay never sees)
- **Polished case-file archive** — Polish-or-later per DC §E.12; NOT in this GDD

## Acceptance Criteria

> **Notation**: All ACs **BLOCKING** unless tagged ADVISORY. Story types: **[Logic]** (GUT unit), **[Integration]** (multi-system), **[Visual]** (screenshot + sign-off), **[UI]** (manual walkthrough doc), **[Code-Review]** (grep / static analysis). Evidence paths in `tests/unit/`, `tests/integration/`, `tools/ci/`, or `production/qa/evidence/`. ACs marked **BLOCKED-pending [item]** cannot be verified until that dependency resolves.

### H.1 Lifecycle: Open

- **AC-DOV-1.1 [Logic] BLOCKING**: GIVEN Overlay state IDLE, WHEN `_on_document_opened(valid_doc_id)` is called, THEN all 8 C.4 lifecycle steps execute in exact order within same frame: (1) `_current_title_key`/`_current_body_key` cached; (2) `_prev_mouse_mode` recorded; (3) `InputContext.push(DOCUMENT_OVERLAY)`; (4) `Input.mouse_mode = MOUSE_MODE_VISIBLE`; (5) `PostProcessStack.enable_sepia_dim()`; (6) labels populated via `tr(key)`; (7) `DocumentCard.visible == true` + `BodyScrollContainer.scroll_vertical == 0` + focus grabbed; (8) `accessibility_live = "assertive"` (deferred-cleared); `_state == OPENING` on exit. Evidence: `tests/unit/document_overlay/lifecycle_open_test.gd`
- **AC-DOV-1.2 [Logic] BLOCKING (BLOCKED-pending OQ-DOV-COORD-2)**: GIVEN Overlay IDLE + `reduced_motion_enabled == true`, WHEN `_on_document_opened(valid_doc_id)`, THEN `PostProcessStack.enable_sepia_dim(0.0)` called exactly once with duration override 0.0. Evidence: `tests/unit/document_overlay/lifecycle_open_test.gd` (PPS spy double)
- **AC-DOV-1.3 [Logic] BLOCKING**: GIVEN Overlay IDLE, WHEN `_on_document_opened(invalid_id)` (null/freed Document resource), THEN `push_error("document_opened with invalid id")` emitted; `_state` unchanged; no InputContext push; no mouse mode write; `DocumentCard.visible == false`. Evidence: `tests/unit/document_overlay/lifecycle_open_test.gd`
- **AC-DOV-1.4 [Logic] BLOCKING (BLOCKED-pending OQ-DOV-COORD-2)**: GIVEN Overlay state OPENING, WHEN sepia transition completion event fires (Timer or PPS signal — pending COORD-2), THEN `_state` transitions to READING. Evidence: `tests/unit/document_overlay/state_machine_test.gd`

### H.2 Lifecycle: Close

- **AC-DOV-2.1 [Logic] BLOCKING**: GIVEN Overlay state READING, WHEN `_close()` called, THEN all 6 C.5 lifecycle steps execute in exact order: (1) `set_input_as_handled()`; (2) `Input.mouse_mode = _prev_mouse_mode`; (3) `InputContext.pop()`; (4) `PostProcessStack.disable_sepia_dim()`; (5) `DocumentCard.visible == false` + `TitleLabel.text == ""` + `BodyText.text == ""`; (6) `DocumentCollection.close_document()`; `_state == CLOSING` on exit. Evidence: `tests/unit/document_overlay/lifecycle_close_test.gd` with call-order spies
- **AC-DOV-2.2 [Logic] BLOCKING (variant pending OQ-DOV-COORD-8)**: GIVEN Overlay CLOSING, WHEN `_on_document_closed(doc_id)` callback fires, THEN cached keys all empty (`_current_doc_id == &""`, etc.); `_state == IDLE`. Evidence: `tests/unit/document_overlay/lifecycle_close_test.gd`
- **AC-DOV-2.3 [Logic] BLOCKING**: GIVEN Overlay CLOSING, WHEN `_close()` called again (idempotency), THEN early-return guard fires; no second lifecycle pass; each API called exactly once total. Evidence: `tests/unit/document_overlay/lifecycle_close_test.gd`

### H.3 Subscriber Discipline + Defensive Guard (CR-1, CR-3)

- **AC-DOV-3.1 [Code-Review] BLOCKING**: GIVEN all `.gd` files under `src/ui/document_overlay/`, WHEN CI grep `fp_ov_1_sole_publisher` runs (`grep -rn "Events\.document_(opened\|closed\|collected)\.emit" src/ui/document_overlay/`), THEN zero matches. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh` exit 0
- **AC-DOV-3.2 [Logic] BLOCKING**: GIVEN Overlay state OPENING, WHEN `_on_document_opened(new_id)` called (simulated double-emit), THEN `push_error("document_opened in state OPENING")`; `_state == OPENING` unchanged; no second `InputContext.push`; labels unchanged. Evidence: `tests/unit/document_overlay/defensive_guard_test.gd`
- **AC-DOV-3.3 [Logic] BLOCKING**: GIVEN Overlay state READING, WHEN `_on_document_opened(another_id)`, THEN `push_error`; `_state == READING`; current title/body unchanged; no InputContext push. Evidence: `tests/unit/document_overlay/defensive_guard_test.gd`
- **AC-DOV-3.4 [Logic] BLOCKING (NEW 2026-04-27 per qa-lead — closes E.4 race coverage gap)**: GIVEN Overlay state CLOSING (post-`_close()`, awaiting `document_closed` callback), WHEN `_on_document_opened(third_id)` fires (the E.4 race window), THEN CR-3 guard fires (`_state != IDLE` → push_error → discard); `_state == CLOSING` unchanged; no second `InputContext.push`; no labels mutated; no sepia call. Evidence: `tests/unit/document_overlay/defensive_guard_test.gd` covering all three OPENING/READING/CLOSING guard branches.
- **AC-DOV-3.5 [Logic] BLOCKING (NEW 2026-04-27 per qa-lead — malformed Document)**: GIVEN Overlay IDLE, WHEN `_on_document_opened(id)` resolves to a Document Resource with empty `title_key` (`&""`) or empty `body_key`, THEN `push_error("document_opened with malformed Document: empty key field for %s" % id)`; `_state == IDLE` unchanged; no InputContext push; labels untouched. Evidence: `tests/unit/document_overlay/defensive_guard_test.gd`.
- **AC-DOV-3.6 [Logic] BLOCKING (NEW 2026-04-27 per qa-lead — non-matching section_id)**: GIVEN Overlay state READING for section A, WHEN `section_unloading(section_B_id)` fires (different section), THEN no-op; `_state == READING` unchanged; no `_close()` call. Evidence: `tests/unit/document_overlay/section_unload_test.gd`.

### H.4 InputContext + Dismiss Contract (CR-5, CR-6, Input CR-7)

- **AC-DOV-4.1 [Integration] BLOCKING**: GIVEN Overlay READING + `InputContext.is_active(DOCUMENT_OVERLAY) == true`, WHEN synthetic `ui_cancel` injected to `_unhandled_input`, THEN `set_input_as_handled()` called BEFORE `InputContext.pop()` (call-order spy verifies); event consumed; `_state` transitions to CLOSING. Evidence: `tests/integration/document_overlay/dismiss_input_test.gd`
- **AC-DOV-4.2 [Integration] BLOCKING**: GIVEN Overlay READING + active modal, WHEN synthetic `ui_cancel` (Esc OR B/Circle) injected, THEN no Pause Menu signal emits same frame; event does NOT propagate past Overlay. Evidence: `tests/integration/document_overlay/dismiss_input_test.gd` (Pause spy assert call_count == 0)
- **AC-DOV-4.3 [Logic] BLOCKING**: GIVEN Overlay IDLE (DOCUMENT_OVERLAY NOT active), WHEN `_unhandled_input` receives `ui_cancel`, THEN early-return fires; `set_input_as_handled` NOT called; `_state == IDLE`. Evidence: `tests/unit/document_overlay/dismiss_guard_test.gd`
- **AC-DOV-4.4 [UI] ADVISORY (BLOCKED-pending Gate C)**: GIVEN live Editor session with Overlay open, WHEN tester presses Esc on KB then opens new doc and presses B on gamepad, THEN both inputs dismiss; Pause Menu does NOT open on first press; Overlay returns to IDLE. Evidence: `production/qa/evidence/ac-dov-4-4-dismiss-walkthrough.md` + Gate C result

### H.5 Mouse Mode Push/Pop (Input CR-8)

- **AC-DOV-5.1 [Logic] BLOCKING**: GIVEN Overlay IDLE + `Input.mouse_mode == MOUSE_MODE_CAPTURED`, WHEN open lifecycle runs, THEN `_prev_mouse_mode == CAPTURED` recorded at step 2; `Input.mouse_mode == VISIBLE` at step 4. Evidence: `tests/unit/document_overlay/mouse_mode_test.gd`
- **AC-DOV-5.2 [Logic] BLOCKING**: GIVEN open ran with `_prev_mouse_mode == CAPTURED`, Overlay READING, WHEN `_close()`, THEN mode restored to CAPTURED at C.5 step 2 BEFORE pop at step 3 (call-order spy). Evidence: `tests/unit/document_overlay/mouse_mode_test.gd`
- **AC-DOV-5.3 [Logic] BLOCKING**: GIVEN precondition mouse mode VISIBLE (E.13 — prior modal active), WHEN open + close runs, THEN mode is VISIBLE throughout; net change == none. Evidence: `tests/unit/document_overlay/mouse_mode_test.gd`

### H.6 Localization: tr() at Render, Re-Resolve, Missing Keys (CR-7, CR-8, FP-OV-4, FP-OV-16)

- **AC-DOV-6.1 [Code-Review] BLOCKING (grep pattern broadened 2026-04-27 per localization-lead)**: GIVEN `document_overlay_ui.gd`, WHEN CI grep `fp_ov_4_cached_translation_value` runs against the broadened pattern catching both explicit-typed and inferred-typed locals: `grep -nE '\bvar\b\s+\w+(\s*:\s*String)?\s*:?=\s*tr\(' src/ui/document_overlay/document_overlay_ui.gd`, THEN zero matches; `_current_title_key`/`_current_body_key` are `StringName` (key-only); no local variable in any function caches a `tr()` result. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh`
- **AC-DOV-6.2 [Logic] BLOCKING (Gate E ADVISORY)**: GIVEN Overlay READING with cached keys, WHEN `_notification(NOTIFICATION_TRANSLATION_CHANGED)` fires, THEN `TitleLabel.text == tr(_current_title_key)` (new locale); `BodyText.text == tr(_current_body_key)` (new locale, no doubled text); `BodyScrollContainer.scroll_vertical == 0`; `accessibility_live == "assertive"` deferred-cleared. Evidence: `tests/unit/document_overlay/localization_test.gd`
- **AC-DOV-6.3 [Logic] BLOCKING**: GIVEN Overlay OPENING with cached keys, WHEN NOTIFICATION_TRANSLATION_CHANGED fires, THEN handler returns early (`_state != READING`); labels unchanged. Evidence: `tests/unit/document_overlay/localization_test.gd`
- **AC-DOV-6.4 [Logic] BLOCKING**: GIVEN document with `title_key = "doc.missing_key_xyz"` not in CSV, WHEN open lifecycle step 6 calls `tr(...)`, THEN `TitleLabel.text == "doc.missing_key_xyz"` (key returned verbatim — graceful fallback per Localization E.10); no Overlay-side crash or push_error. Evidence: `tests/unit/document_overlay/localization_test.gd`
- **AC-DOV-6.5 [Code-Review] BLOCKING**: GIVEN all `.gd` files under `src/ui/document_overlay/`, WHEN CI grep `fp_ov_16_richtext_append` (`grep -n "BodyText\.append_text\|append_text(tr(" ...`), THEN zero matches (FP-OV-16 forbids append_text for re-render; only direct `text =` assignment). Evidence: `tools/ci/check_forbidden_patterns_overlay.sh`
- **AC-DOV-6.6 [Code-Review] BLOCKING (BLOCKED-pending Gate D)**: GIVEN scene tree spec, WHEN CI grep `auto_translate_mode` value verification, THEN `TitleLabel` and `BodyText` declare `AUTO_TRANSLATE_MODE_DISABLED`; `DismissHintLabel` declares `AUTO_TRANSLATE_MODE_ALWAYS`; no other values. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh` + `.tscn` inspection

### H.7 Scroll Grammar (CR-9, FP-OV-12)

- **AC-DOV-7.1 [UI] ADVISORY (Gate F ADVISORY)**: GIVEN live run with body exceeding card height, WHEN tester applies sequence (mouse wheel up/down, ↑↓ arrows, PgUp/PgDn, Home, End), THEN each input scrolls per CR-9 spec (~28 px per arrow, viewport_h-line_height per page, jumps to top/bottom for Home/End). Evidence: `production/qa/evidence/ac-dov-7-1-scroll-walkthrough.md`
- **AC-DOV-7.2 [UI] ADVISORY (Gate F ADVISORY)**: GIVEN gamepad connected + scrollable doc open, WHEN tester deflects right stick Y, THEN body scrolls with magnitude proportional to deflection; left stick produces NO scroll; no input leak to gameplay. Evidence: `production/qa/evidence/ac-dov-7-2-gamepad-scroll-walkthrough.md`
- **AC-DOV-7.3 [Code-Review] BLOCKING**: GIVEN `BodyScrollContainer` in `DocumentOverlayUI.tscn`, WHEN static analysis checks properties, THEN `smooth_scroll_enabled = false` (FP-OV-12); `vertical_scroll_mode = SCROLL_MODE_AUTO`; `horizontal_scroll_mode = SCROLL_MODE_DISABLED`. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh`

### H.8 Section-Unload Close (CR-12, OQ-DOV-COORD-9, E.7, E.19)

- **AC-DOV-8.1 [Integration] BLOCKING (BLOCKED-pending OQ-DOV-COORD-3)**: GIVEN Overlay READING, WHEN `section_unloading(matching_section_id)` fires, THEN full C.5 lifecycle executes synchronously; `_state == IDLE` before handler returns; `DC.close_document()` called; `InputContext.pop()` called; mouse mode restored. Evidence: `tests/integration/document_overlay/section_unload_test.gd`
- **AC-DOV-8.2 [Integration] BLOCKING (BLOCKED-pending OQ-DOV-COORD-9)**: GIVEN Overlay OPENING (sepia in progress, card visible, InputContext pushed), WHEN `section_unloading` fires, THEN OPENING-state teardown branch executes: `InputContext.pop()`, mouse mode restored, `disable_sepia_dim()`, card hidden, `_state == IDLE`. `DC.close_document()` is NOT called. Evidence: `tests/integration/document_overlay/section_unload_test.gd`
- **AC-DOV-8.3 [Integration] BLOCKING**: GIVEN Overlay IDLE, WHEN `section_unloading` fires, THEN no-op; no API calls; `_state == IDLE`. Evidence: `tests/integration/document_overlay/section_unload_test.gd`

### H.9 Performance: ADR-0008 Slot 7 (CR-14, CR-15, F.2)

- **AC-DOV-9.1 [Logic] BLOCKING**: GIVEN Overlay instantiated + IDLE, WHEN 100 frames advance with no signals, THEN `is_processing() == false` AND `is_physics_processing() == false`; 0 ms GDScript per-frame cost. Evidence: `tests/unit/document_overlay/performance_test.gd`
- **AC-DOV-9.2 [Integration] ADVISORY (reclassified 2026-04-27 from BLOCKING per qa-lead — manual-only profiler evidence is incompatible with BLOCKING CI gate; 0.3 ms threshold is sub-GUT-resolution)**: GIVEN Overlay READING with 200-word body on Iris Xe at 810p (or equivalent profiler run), WHEN 300 steady-state READING frames elapse with no input (excluding open-frame and locale-change-frame spikes), THEN p95 per-frame CanvasLayer render cost ≤ 0.3 ms (ADR-0008 Slot 7 cap); single-frame outliers above 0.3 ms acceptable provided p95 holds. Evidence: profiler capture `production/qa/evidence/ac-dov-9-2-slot7-profile.png` + lead sign-off
- **AC-DOV-9.2-bis [Logic] BLOCKING (NEW 2026-04-27 — GUT-runnable proxy for AC-DOV-9.2)**: GIVEN Overlay READING, WHEN `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` is sampled over 60 frames after card is fully rendered, THEN average ≤ 10 draw calls (ModalBackdrop + DocumentCard + CardHeader + TitleLabel + CardBody + BodyText + CardFooter + ScrollHintLabel + DismissHintLabel + VScrollBar = ~10; some StyleBoxes add 1 each → total cap 12). This is a GUT-verifiable proxy for the 0.3 ms render-cost target; integer draw-call count is reliably measurable in headless test mode. Evidence: `tests/unit/document_overlay/performance_test.gd`
- **AC-DOV-9.3 [Integration] ADVISORY (Gate E)**: GIVEN worst-case 250-word body, first session-open, Iris Xe at 810p, WHEN open frame executes, THEN T_open ≤ 5 ms (F.1 target); if > 5 ms a pre-warm strategy is required pre-VS milestone. Evidence: profiler capture `production/qa/evidence/ac-dov-9-3-openframe-profile.png`

### H.10 Forbidden Patterns CI Enforcement (FP-OV-1, 2, 3, 5, 7, 9, 14, 15, 16)

- **AC-DOV-10.1 [Code-Review] BLOCKING**: CI grep `fp_ov_7_audio_api` (`grep -rn "AudioServer\|AudioStreamPlayer\|set_bus_volume_db\|audio_bus" src/ui/document_overlay/`) → zero matches. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh`
- **AC-DOV-10.2 [Code-Review] BLOCKING**: CI grep `fp_ov_9_dismiss_button` (`grep -n "Button\|ui_accept" src/ui/document_overlay/DocumentOverlayUI.tscn`) → zero matches for Button node types or ui_accept dismiss handlers. Evidence: same script
- **AC-DOV-10.3 [Code-Review] BLOCKING**: CI grep `fp_ov_15_gameplay_events` (`grep -rn "player_damaged\|alert_state_changed\|enemy_killed\|player_interacted\|document_collected" src/ui/document_overlay/document_overlay_ui.gd`) → zero matches; Overlay subscribes only to `document_opened`/`document_closed`. Evidence: same script
- **AC-DOV-10.4 [Code-Review] BLOCKING**: CI grep `fp_ov_14_typewriter` (`grep -rn "Tween.*text\|text.*Tween\|typewriter\|append_text.*await\|call_deferred.*append_text" src/ui/document_overlay/`) → zero matches. Evidence: same script
- **AC-DOV-10.5 [Code-Review] BLOCKING**: CI grep `fp_ov_2_auto_dismiss` (`grep -rn "Timer.*_close\|Tween.*_close\|auto_dismiss\|dismiss_timer" src/ui/document_overlay/`) → zero matches; only `section_unloading` may force close (CR-12). Evidence: same script
- **AC-DOV-10.6 [Code-Review] BLOCKING**: CI grep `fp_ov_5_hud_visibility` (`grep -rn "HUDCore\.visible\|hud_core.*visible\|set_hud_visible" src/ui/document_overlay/`) → zero matches; HUD owns its own InputContext gate. Evidence: same script
- **AC-DOV-10.7 [Code-Review] BLOCKING (NEW 2026-04-27 per qa-lead — FP-OV-13 inline glossary)**: CI grep over body content CSV cells for forbidden inline-link BBCode patterns (`grep -E '\[url=|\[hint=' translations/doc.csv translations/overlay.csv`) → zero matches. Document body content must not contain `[url]`, `[hint]`, or any branching-link BBCode tag. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh` (CSV-grep mode)
- **AC-DOV-10.8 [Code-Review] BLOCKING (NEW 2026-04-27 per qa-lead — FP-OV-11 secondary action nodes)**: CI grep over `DocumentOverlayUI.tscn` for any interactive node type other than `ScrollContainer` (for scroll input) and `RichTextLabel` (for body — `mouse_filter = MOUSE_FILTER_PASS`); explicit deny list: `Button`, `LinkButton`, `MenuButton`, `OptionButton`, `CheckBox`, `CheckButton`, `LineEdit`, `TextEdit`, `TabContainer`, `Tree`, `ItemList`. Any match in the Overlay scene tree = BLOCKING failure. Evidence: same script (TSCN-grep mode)
- **AC-DOV-10.9 [Code-Review] BLOCKING (NEW 2026-04-27 per qa-lead — CI script meta-test)**: GIVEN `tools/ci/check_forbidden_patterns_overlay.sh` exists per OQ-DOV-COORD-11, WHEN executed against (a) a clean Overlay implementation, exit code = 0; AND (b) a synthetic broken implementation containing one violation per pattern (FP-OV-1, 2, 3, 4, 5, 7, 9, 13, 14, 15, 16 + FP-OV-11), exit code != 0 with each violation reported with file path + line number. Evidence: `tools/ci/check_forbidden_patterns_overlay_meta_test.sh` + fixtures in `tests/fixtures/overlay_violations/`

### H.11 AccessKit / Accessibility (§C.8, E.24, E.25)

- **AC-DOV-11.1 [Integration] BLOCKING (BLOCKED-pending Gate A)**: GIVEN Overlay IDLE, WHEN open lifecycle runs (C.4 step 8), THEN `ModalBackdrop.accessibility_live == "assertive"` on open frame; reset to `"off"` next frame via deferred call. Evidence: `tests/integration/document_overlay/accessibility_test.gd`
- **AC-DOV-11.2 [Integration] BLOCKING (BLOCKED-pending Gate A)**: GIVEN Overlay READING + locale change, WHEN C.7 re-resolve runs, THEN `accessibility_live == "assertive"` on re-resolve frame; reset next frame (one-shot pattern). Evidence: same script
- **AC-DOV-11.3 [Logic] BLOCKING (BLOCKED-pending OQ-DOV-COORD-2)**: GIVEN `reduced_motion_enabled == true`, WHEN open at C.4 step 5, THEN sepia engages with 0.0 s duration; no fade Tween started from Overlay. Evidence: `tests/unit/document_overlay/lifecycle_open_test.gd`
- **AC-DOV-11.4-NVDA [UI] ADVISORY → BLOCKING post-Gate-A (split per qa-lead + accessibility-specialist 2026-04-27)**: GIVEN Windows build + NVDA 2024.x active + live run, WHEN document opens (Overlay reaches READING), THEN screen reader announces in order: (1) "Document" dialog role; (2) heading-1 announcement of document title (via TitleLabel `grab_focus()` + heading role); (3) body content reachable via virtual-buffer arrow-key navigation. Evidence: `production/qa/evidence/ac-dov-11-4-nvda-walkthrough.md`
- **AC-DOV-11.4-Orca [UI] ADVISORY → BLOCKING post-Gate-A (split per qa-lead 2026-04-27 — AT-SPI2 + Steam Linux risk)**: GIVEN Linux build (native or Proton) launched via Steam + Orca 46.x active + `at-spi2-core` daemon running, WHEN document opens, THEN equivalent announcement sequence as AC-DOV-11.4-NVDA. **Pre-test verification**: confirm `at-spi2-core` daemon is reachable from Steam-launched process (not blocked by Steam's sandbox); confirm Godot 4.6 AT-SPI2 path is functional from a Steam-launched native binary. If AT-SPI2 unreachable from Steam launch, document as known limitation requiring user-side launch-script workaround. Evidence: `production/qa/evidence/ac-dov-11-4-orca-walkthrough.md`
- **AC-DOV-11.5 [Logic] BLOCKING (NEW 2026-04-27 per accessibility-specialist — CR-16 Tab consumption)**: GIVEN Overlay state READING + `InputContext.is_active(DOCUMENT_OVERLAY) == true`, WHEN synthetic `ui_focus_next` (Tab) AND synthetic `ui_focus_prev` (Shift+Tab) actions are injected to `_unhandled_input`, THEN both events are consumed via `set_input_as_handled()`; focus does NOT move (current focused control unchanged); `_state == READING` unchanged; no node outside the Overlay subtree receives focus. Evidence: `tests/unit/document_overlay/focus_trap_test.gd`

### H.12 Visual Contract + Pillar 5 Floor (§B refusals, §G.5)

- **AC-DOV-12.1 [Visual] ADVISORY**: GIVEN live Editor at 1920×1080 + Overlay READING, WHEN screenshot captured, THEN: card 960×680 px centered; BQA Blue `#1B3A6B` header; Parchment `#F2E8C8` body; American Typewriter Bold title + Regular body; thin 4 px Ink Black scroll bar (if overflows); no rounded corners, drop shadows, glow; sepia-dim world visible behind; HUD widgets not visible. Evidence: `production/qa/evidence/ac-dov-12-1-visual-1080p.png` + art-director sign-off
- **AC-DOV-12.2 [Visual] ADVISORY**: GIVEN live run at 1280×720 (min supported), WHEN screenshot captured, THEN: card ≥ 800 px wide (F.4 clamp); body text legible at 16-18 px; no text or card-edge clipping. Evidence: `production/qa/evidence/ac-dov-12-2-visual-720p.png` + art-director sign-off
- **AC-DOV-12.3 [Code-Review] BLOCKING**: CI grep `fp_ov_3_zoom_pan` (`grep -rn "scale.*Tween\|Tween.*scale\|pivot_offset\|zoom\|pan\|RenderingServer.*transform" src/ui/document_overlay/`) → zero matches; no post-render transform on card. Evidence: `tools/ci/check_forbidden_patterns_overlay.sh`

### H.13 Save/Load Ephemerality (E.26, E.27, E.28)

- **AC-DOV-13.1 [Integration] BLOCKING (variant pending OQ-DOV-COORD-8)**: GIVEN game saved while Overlay READING, WHEN save written + loaded in fresh session, THEN load opens NO Overlay; `_state == IDLE`; save payload contains no `_open_document_id` or equivalent field; loaded session begins with Overlay invisible. Evidence: `tests/integration/document_overlay/save_load_test.gd`
- **AC-DOV-13.2 [Logic] BLOCKING**: GIVEN Overlay READING, WHEN quicksave fires (assuming bypass — E.26), THEN `_state` remains READING unchanged; save proceeds; dismiss still requires `ui_cancel`; no corrupted state. Evidence: `tests/unit/document_overlay/save_load_test.gd`

### H.14 Per-Section Instantiation + Multiple-Instance Guard (CR-13, OQ-DOV-COORD-10, E.22)

- **AC-DOV-14.1 [Logic] BLOCKING (strengthened 2026-04-27 per qa-lead — push_error does not halt)**: GIVEN Overlay's `_ready()` runs, WHEN `get_tree().get_nodes_in_group("document_overlay_instances")` queried, THEN count == 1 (this instance registered); IF count > 1, `push_error("Multiple DocumentOverlayUI instances in section — only one allowed.")` AND second instance sets `_disabled = true`, **explicitly exits `_ready()` early before any signal subscription**, AND if `document_opened` somehow reaches the disabled instance later, `_on_document_opened` returns early (`if _disabled: return`); the disabled instance's `_state` remains IDLE permanently and never proceeds to open lifecycle. The test asserts: (a) push_error fired; (b) `_disabled == true` on the second instance; (c) signal subscriptions on the second instance are absent (`Events.document_opened.is_connected(...)` returns false); (d) after firing `Events.document_opened.emit("test_id")`, only the first instance proceeds with C.4 lifecycle. Evidence: `tests/unit/document_overlay/instantiation_test.gd`
- **AC-DOV-14.2 [Code-Review] BLOCKING (BLOCKED-pending OQ-DOV-COORD-10)**: CI lint scans MLS section scripts; no section script contains more than one `DocumentOverlayUI` instantiation. Evidence: `tools/ci/check_mls_section_lint.sh`

### H.15 End-to-End Lifecycle Integration (NEW 2026-04-27 per qa-lead — Integration coverage thinness gap)

- **AC-DOV-15.1 [Integration] BLOCKING**: GIVEN Overlay IDLE + InputContext stack [GAMEPLAY] + DC autoload mocked + PPS autoload mocked, WHEN simulated `Events.document_opened.emit(test_doc_id)` followed (after sepia transition timer) by simulated `_unhandled_input(ui_cancel)` followed by simulated `_on_document_closed(test_doc_id)`, THEN the full sequence executes: IDLE → OPENING (8 C.4 steps) → READING → CLOSING (6 C.5 steps) → IDLE; final state assertions: `_state == IDLE`, InputContext stack == [GAMEPLAY], `Input.mouse_mode == _initial_mouse_mode`, all cached keys empty, card invisible, all spies report exact call counts (PPS enable=1+disable=1, IC push=1+pop=1, mouse VISIBLE=1+restore=1, DC.close_document=1). Inter-step coupling (e.g., InputContext push at step 3 must not be skipped if mouse-mode-restore at close step 2 fails) is verified by spy ordering. Evidence: `tests/integration/document_overlay/full_open_read_dismiss_test.gd`

### H.16 Pseudolocalization smoke (NEW 2026-04-27 per localization-lead)

- **AC-DOV-16.1 [UI] ADVISORY**: GIVEN dev build with `_dev_pseudo.csv` active at 140% expansion factor (Localization Scaffold §G `pseudolocalization_length_factor = 1.4`), WHEN tester opens overlay with longest English document body (250 words) AND each of the 4 `overlay.*` keys, THEN: (a) all card text remains within card boundaries with scroll absorbing overflow; (b) footer dismiss hint does NOT clip; (c) ScrollHintLabel (when visible) does NOT clip; (d) no text spills outside card frame. Evidence: `production/qa/evidence/ac-dov-16-1-pseudoloc.md` (screenshots at 140% pseudoloc per `overlay.*` key + 250-word English body)

### H.GAPS — Coverage gaps identified during AC authoring (revised 2026-04-27 per qa-lead)

- **GAP-1 (PROMOTED TO VS per qa-lead 2026-04-27)**: `_exit_tree()` safety-net behavior (E.16 abnormal `queue_free()` while `_state != IDLE`) is normal-gameplay path during section unload — moved from Polish to VS scope. Add **AC-DOV-14.3 [Logic] BLOCKING**: GIVEN Overlay `_state == READING`, WHEN `queue_free()` is called externally without `_close()` first, THEN `_exit_tree()` safety net runs: `Input.mouse_mode = _prev_mouse_mode` (if currently captured); `InputContext.pop()` (only if `is_active(DOCUMENT_OVERLAY)` returns true at top of stack); `DC.close_document()` SKIPPED (DC may be in own `_exit_tree`, guarded by `is_instance_valid(DocumentCollection)`); no errors raised. Evidence: `tests/unit/document_overlay/exit_tree_safety_net_test.gd`
- **GAP-2**: No AC covers PPS Tween killed mid-fade (external bug). Recommend PPS integration test in Polish.
- **GAP-3 (CONDITIONAL on COORD-8 per qa-lead 2026-04-27)**: `document_closed` never-arriving (E.21). If COORD-8 confirms DC synchronous emission, GAP-3 dissolves and CLOSING duration is zero. If COORD-8 confirms deferred emission, GAP-3 becomes BLOCKING integration test requirement; not unconditionally Polish-deferrable.
- **GAP-4 (PROMOTED TO VS per qa-lead 2026-04-27)**: Gamepad right-stick scroll velocity is a **logic path**, not a feel path — belongs in Logic AC, not Polish. Add **AC-DOV-7.4 [Logic] BLOCKING**: GIVEN Overlay READING with overflowing body, WHEN three synthetic `InputEventJoypadMotion` events are injected with magnitudes 0.0 / 0.10 / 0.50 / 1.0 across the dead-zone boundary, THEN: 0.0 produces zero scroll delta; 0.10 (below 0.15 dead-zone) produces zero scroll delta; 0.50 produces `scroll_vertical_delta` proportional to magnitude × `right_stick_scroll_max_step_px_per_frame`; 1.0 produces exactly `right_stick_scroll_max_step_px_per_frame` (clamp). Evidence: `tests/unit/document_overlay/gamepad_scroll_test.gd`
- **GAP-5 RESOLVED 2026-04-27** by AC-DOV-14.1 strengthened wording (push_error does not halt — explicit `_disabled` flag now asserted).

### H.NEW — New blocking items emerging from AC analysis (added to §F.6 coord list)

- **OQ-DOV-COORD-11 (BLOCKING)**: Author `tools/ci/check_forbidden_patterns_overlay.sh` — 12 ACs (3.1, 6.1, 6.5, 6.6, 7.3, 10.1–10.6, 12.3) cite this script. Must be created (or MLS CI script extended) before any CI grep AC can return meaningful result. Sprint task alongside Overlay implementation.

## Open Questions

### 13 BLOCKING coordination items for sprint start (revised 2026-04-27 from 11 → 13; see §C.12 for authoritative list)

| ID | Owner | Question / Required action | Deadline |
|---|---|---|---|
| **OQ-DOV-COORD-1** | Document Collection GDD author | DC §C.10 / CR-11 must confirm Option A auto-open contract — DC's `_on_player_interacted` handler executes `collect()` then `open_document()` in same frame, before frame end | Before any Overlay sprint story is written |
| **OQ-DOV-COORD-2** | Post-Process Stack GDD author | PPS GDD amendment to expose `enable_sepia_dim(duration_override: float = 0.5)` (recommended) OR `enable_sepia_dim_instant()` for reduced-motion compliance | Before AC-DOV-1.2 / 11.3 implementation |
| **OQ-DOV-COORD-3** | Mission & Level Scripting GDD author | MLS GDD amendment to define + emit `section_unloading(section_id: StringName)` pre-unload signal; Overlay subscribes for CR-12 force-close. **PLUS section-teardown order convention** (added 2026-04-27 per E.21 systems-designer): MLS must guarantee Overlay's `_exit_tree()` runs before DC's, OR `InputContext.pop()` is idempotent on freed scenes | Before AC-DOV-8.1 / 8.3 implementation |
| **OQ-DOV-COORD-4** | Writer + narrative-director | Writer brief amendment at `design/narrative/document-writer-brief.md` to add body word-count ceiling: **no minimum, 250 words English hard ceiling** (revised 2026-04-27 per game-designer — 150-word floor deleted; comedy benefits from terse dispatches). Lectern Pause requires single-read absorption; >250 words violates fantasy. German 1.5× expansion → 375 rendered worst case | Before any document body content is authored |
| **OQ-DOV-COORD-5** | Localization Scaffold author | Add **4 new keys** (revised from 3) in NEW file `translations/overlay.csv`: `overlay.dismiss_hint` (≤55 chars), `overlay.scroll_hint` (NEW, ≤50 chars), `overlay.accessibility.dialog_name` (≤20 chars), `overlay.accessibility.scroll_name` (≤25 chars). Plus Localization Scaffold §Interactions ownership table amendment to add `overlay.*` namespace row | Before AC-DOV-6.x localization tests |
| **OQ-DOV-COORD-6** | ADR-0004 author | Documentation fix: §IG3 code snippet shows `InputContext.pop()` BEFORE `set_input_as_handled()`; Input CR-7 prose order is authoritative. Either amend code OR add explicit annotation | Before sprint stories citing ADR-0004 §IG3 |
| **OQ-DOV-COORD-8** | Document Collection GDD author | Confirm `DC.close_document()` emits `document_closed` synchronously (within same call stack) NOT via `call_deferred`. Synchronous strongly preferred — collapses CLOSING state duration to zero, eliminates E.4 exposure window | Before AC-DOV-2.2 / 13.1 finalization |
| **OQ-DOV-COORD-9** | This GDD (implementation) | `_on_section_unloading` handler must include OPENING-state teardown branch (not just READING via C.5 `_close()`). Required for E.7, E.19. Branch: pop InputContext, restore mouse mode, `disable_sepia_dim()`, hide card, `_state = IDLE` — without `DC.close_document()` | Before AC-DOV-8.2 implementation |
| **OQ-DOV-COORD-10** | MLS GDD author + tools-programmer | CI lint verifying MLS section scripts do not instantiate more than one `DocumentOverlayUI` per section. Plus runtime group-tag assertion in Overlay's `_ready()` (group `&"document_overlay_instances"`, count ≤ 1) with explicit `_disabled` flag (per AC-DOV-14.1 strengthened) | Before AC-DOV-14.2 implementation |
| **OQ-DOV-COORD-11** | tools-programmer | **Sprint-day-1** authoring of `tools/ci/check_forbidden_patterns_overlay.sh` (broadened scope per qa-lead 2026-04-27): 13+ ACs cite this script (3.1, 6.1, 6.5, 6.6, 7.3, 10.1–10.9, 12.3). Plus meta-test (AC-DOV-10.9) verifying the script catches violations on synthetic broken implementation. Must be created before any CI grep AC can be verified | Sprint day 1, before any implementation work |
| **OQ-DOV-COORD-12 (NEW 2026-04-27)** | Settings & Accessibility GDD author + FontRegistry owner | Settings GDD must add `text_scale_multiplier` setting (range [1.0, 2.0], default 1.0, safe step 0.25) applied via FontRegistry to all `document_*()` font sizes at section-load. Required for WCAG 2.1 AA SC 1.4.4 (Resize Text) compliance per accessibility-specialist | Before VS milestone close (WCAG conformance gate) |
| **OQ-DOV-COORD-13 (NEW 2026-04-27)** | tools-programmer + qa-lead | Author `tests/unit/helpers/call_order_recorder.gd` (shared GDScript helper for asserting call ORDER, not just count, in GUT) AND a viewport-mock seam for `set_input_as_handled()` testability. Required for AC-DOV-1.1, 2.1, 4.1, 5.2 (call-order verification) | Sprint day 1, alongside COORD-11 |
| **OQ-DOV-COORD-14 (NEW 2026-04-27)** | HUD Core GDD author | HUD Core / OQ-HUD-3 must require HUD to **kill or pause Tweens** on `InputContext` change to non-GAMEPLAY (not just hide widgets). Otherwise HUD's Slot 7 contribution is non-zero during overlay open if a Tween is mid-animation; invalidates Overlay's CR-14 "holds full Slot 7 cap alone" claim | Before AC-DOV-9.2 / 9.2-bis verification |
| **OQ-DOV-COORD-ADR-0004** | godot-specialist + creative-director | ADR-0004 Proposed → Accepted promotion: gates A + C remain BLOCKING (Gate B closed 2026-04-27; Gate D closed 2026-04-27; Gate E now BLOCKING; new Gate G BLOCKING). Per `Docs CLAUDE.md`: "stories referencing a Proposed ADR are auto-blocked" | Before any sprint story referencing ADR-0004 |

### 1 ADVISORY coordination item

| ID | Owner | Action | Deadline |
|---|---|---|---|
| **OQ-DOV-COORD-7** | art-director | Define exact `StyleBoxFlat` for the 4 px Ink Black scroll bar in `document_overlay_theme.tres` (covered visually in §V Visual/Audio + per-screen UX spec at Phase 4) | Polish or VS UX-spec phase |

### 7 verification gates (3 BLOCKING + 1 NEW BLOCKING + 2 CLOSED + 1 ADVISORY) — revised 2026-04-27

| Gate | Status | Source | Required check | Why blocking |
|---|---|---|---|---|
| **Gate A** | BLOCKING (inherited) | ADR-0004 Gate 1 | Open Godot 4.6 editor; inspect AccessKit-introduced properties on `Control` and subclasses. **Likely real names per godot-specialist 2026-04-27**: `accessibility_description` (NOT `accessibility_name`); `accessibility_role` may be **inferred from node type** rather than settable as string property; `accessibility_live` semantics + AT-flush timing require verification (potential two-deep deferral pattern). Cross-reference Menu System §F.7 verified pattern | §C.4 step 8, §C.7, §C.8 are PSEUDOCODE pending Gate A; AC-DOV-11.1, 11.2, 11.4-NVDA, 11.4-Orca, 11.5 BLOCKED. **Highest implementation risk in entire GDD.** |
| **Gate B** | **CLOSED 2026-04-27** | ADR-0004 Gate 2 | Verified: `Theme.fallback_theme` is the correct Godot 4.x property; `base_theme` does NOT exist in any 4.x release. §C.2 corrected | Closed |
| **Gate C** | BLOCKING (inherited) | ADR-0004 Gate 3 | Smoke-test `_unhandled_input()` + `ui_cancel` modal dismiss on both KB/M (Esc) and gamepad (B/Circle) in Godot 4.6 with dual-focus active | Modal dismiss path is the sole legal close mechanism (CR-6); AC-DOV-4.4 BLOCKED |
| **Gate D** | **CLOSED 2026-04-27** | This GDD §C.7 | Verified: `Node.AUTO_TRANSLATE_MODE_*` enum exists in Godot 4.5+ with constants ALWAYS / DISABLED / INHERIT. Bare identifiers in scene files serialize to integer values; bare identifiers in GDScript resolve via `Node` inheritance | Closed |
| **Gate E** | **BLOCKING (PROMOTED 2026-04-27 from ADVISORY per ux-designer)** | This GDD §C.7 + §F.1 | Confirm in 4.6 editor: `RichTextLabel.text = tr(body_key)` reassignment after locale change produces no doubled text, no BBCode leakage, no programmatic-effect carryover; AND confirm first-render render-cost spike on Iris Xe 810p (after FontRegistry preload) ≤ 5 ms for 350-word German body | AC-DOV-6.2 + AC-DOV-9.3 verification depend; promoted because the snap-vs-fade-in choice (C.4 step 7) depends on first-render being clean and masked by sepia |
| **Gate F** | ADVISORY → RECOMMENDED upgrade for gamepad path | This GDD §C.6 + CR-9 | Confirm `ScrollContainer` correctly routes `ui_up`/`ui_down`/`ui_page_up`/`ui_page_down` natively (keyboard); CONFIRM `InputEventJoypadMotion` analog-stick is NOT consumed natively and Overlay's manual `_unhandled_input` handler per CR-9 routes it correctly with dead-zone + clamp | AC-DOV-7.1, 7.2, 7.4 manual walkthroughs + Logic AC depend |
| **Gate G** | **BLOCKING (NEW 2026-04-27 per accessibility-specialist)** | This GDD §C.8 | Confirm whether `RichTextLabel` with `bbcode_enabled = true` exposes parsed plain text to AccessKit (NOT raw BBCode source). If raw, every formatted document body fails SC 1.3.1; resolution = parallel AT-only plain-text property OR forbid BBCode in body content | Body content using BBCode formatting cannot ship until Gate G closes. Affects all AC-DOV-11.* ACs and AC-DOV-16.1 |

### 4 deferred design questions (Polish phase or playtest-resolvable)

| Question | Owner | Deadline | Recommendation |
|---|---|---|---|
| Polished case-file archive (re-read collected documents from Pause Menu) | Menu System + Document Collection | Polish phase | Currently explicitly deferred per DC §E.12. Decision: Polish-or-later. The VS Lectern Pause fantasy is built around the read-once moment; if playtest reveals players routinely miss nuance, that's the trigger to add the archive |
| Dynamic glyph swapping for rebound `ui_cancel` keys in footer hint | Settings & Accessibility (rebinding owner) | Post-VS | Currently the footer says "ESC / B — Return to Operation" (static). When Settings ships rebinding UI at VS, the footer should reflect the player's actual binding. Settings owns the input-glyph mapping system; Overlay subscribes |
| Document-pickup → open transition timing | Game design + UX | VS playtest | Currently auto-open on pickup (Option A — NOLF1 model per CR-2). If VS playtest shows players want a beat between "pocket" and "read" (e.g., the player wants to reach safe ground first), revisit. The fix is small: DC's `open_document()` could be deferred by 1–2 seconds, not the design itself |
| Scroll bar visual register confirmation | art-director | Polish phase | OQ-DOV-COORD-7 — Polish-phase decision on exact `StyleBoxFlat` for the 4 px Ink Black scroll bar. Default to "thin Ink Black, no rounded corners, 4 px wide" per §V.1 unless playtest shows it competes with body text for attention |

### Deliberately omitted items (NOT open questions — explicitly out of scope)

The following were considered and consciously excluded from this GDD's scope; they should NOT be added without an amendment + creative-director approval:

1. **Document categorization / filtering UI** — out of scope; one document at a time, no categories, no filters
2. **Search bar / find-in-document** — out of scope; documents are short (≤ 250 words), no search needed
3. **Bookmarking / favoriting documents** — out of scope; FP-OV-11 secondary action buttons forbidden
4. **Document re-read counter** ("you've read this 3 times") — out of scope; FP-OV-10 progress indicator forbidden
5. **Cross-reference links** between documents — out of scope; FP-OV-13 inline glossary links forbidden; documents stand alone
6. **Document handout / print-to-file** — out of scope; CR-10 player cannot copy/print; Pillar 5 (no modern affordances)
7. **Highlight / annotation** ("mark as important", "underline") — out of scope; documents are read-only
8. **Document timestamp / metadata visible during read** — out of scope; FP-OV-10 progress indicator forbidden
9. **Speaker / author photo on documents** — out of scope; V.5 forbids inline images
10. **Audio narration of body text** — out of scope; §B refusal "Not narrated"; AccessKit reads body directly via screen reader
11. **Animated entry / exit (slide, scale, fade-in)** — out of scope; FP-OV-3 + FP-OV-14 forbid animations on the card
12. **Mobile / touch / swipe controls** — out of scope; platform constraint per `technical-preferences.md` (no touch support)

These are explicitly listed so future contributors don't accidentally rediscover them as "obvious" features. Each one would compromise the Lectern Pause fantasy or violate Pillar 5.
