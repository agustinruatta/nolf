# UX Spec: Settings & Accessibility Panel

> **Status**: In Design
> **Author**: agustin.ruatta@vdx.tv + ux-designer
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: Cross-phase — accessed from Main Menu (pre-mission) AND Pause Menu (mid-mission); no journey doc exists at time of authoring
> **Template**: UX Spec
> **Related GDDs**: `design/gdd/settings-accessibility.md` (26 CRs, 65 ACs, 14 OQs)
> **Related Specs**: `design/ux/main-menu.md` (APPROVED), `design/ux/photosensitivity-boot-warning.md` (APPROVED), `design/ux/quit-confirm.md` (APPROVED), `design/ux/hud.md` (consumer of `setting_changed`), `design/ux/interaction-patterns.md` (13 patterns referenced)
> **Pillar Fit**: **Pillar-5 carve-out (load-bearing)** — Settings is the canonical Stage Manager non-diegetic register. Supporting: Pillar 3 (Stealth is Theatre — invisible scene-change), Pillar 1 (Comedy Without Punchlines — restraint matches Eve's deadpan).

---

## Purpose & Player Need

The player arrives at this panel wanting to **make the game work for them** — by reducing photosensitive harm, enlarging text, rebinding inputs, balancing volume, choosing a hold-vs-toggle motor pattern, or matching the resolution to their hardware. The Settings panel is the **only** surface in *The Paris Affair* where the player negotiates with the game's defaults; if a thing is configurable, it is configurable here. The panel's success metric is not engagement — it is **how invisibly it lets the player get back to playing**.

### Player goal

> **"I want to make the game work for me, then disappear back into the world."**

The Settings panel is **load-bearing for accessibility commitments**: every promise made in `design/accessibility-requirements.md` — Standard tier subtitles, photosensitivity opt-out, KB+M rebinding, Toggle-Sprint/Crouch/ADS, scalable text, three colourblind modes (VS), reduced motion, mono audio (VS), volume independence, aim assist, cinematic skip carve-out, `text_summary_of_cinematic` — has its **player-visible affordance here**. If a setting cannot be reached from this panel, the project has reneged on its accessibility tier.

### Player Fantasy: "The Stage Manager" (locked, CD-ruled 2026-04-21)

When the player opens Settings, the game **steps offstage**. The fiction is suspended. There is no Eve voice, no PHANTOM red, no Case File framing, no rubber-stamp typography, no period jazz. The panel speaks in plain, professional, brisk English — the register of a competent stage manager during a scene change: doing the work, not asking to be appreciated, never apologising for being a menu.

This is the project's canonical **Pillar-5 carve-out**. The creative-director ruling (2026-04-21, originally in Combat §B) makes accessibility scaffolding **decided on accessibility grounds, not on whether Eve could plausibly experience it in 1965**. The panel exists outside the diegetic period fiction so that the fiction need not bend around WCAG 2.1 SC 2.3.1.

### Refusals (what this panel is NOT)

This panel **MUST NOT**:

1. **Frame itself as in-fiction.** No "MI6 Personnel File" wrapper around setting categories. No manila folders, no carbon-paper backgrounds, no rubber stamps, no Case File typography on category headers or button chrome. The Main Menu's `[Personnel File]` button (Menu System CR-7) is bureaucratic-neutral — a **pointer to** Settings, not a frame around it.
2. **Celebrate state changes.** No SFX on toggle. No animated check-mark flourish. No green "Accessibility ON ✓" banner. No swelling music when a slider crosses 0 dB. Toggling `damage_flash_enabled` to `false` is a medical decision; the panel responds with **silence and the changed state**.
3. **Apologise.** No "we know menus break immersion, but…", no "we want everyone to enjoy this game", no moral framing of accessibility as a kindness. The settings exist; they are configurable; that is the whole communication.
4. **Use Eve's voice or any character voice.** Body copy is omniscient-impersonal. The panel never says "I" or "we"; it never refers to "the player" in second person beyond direct affordance labels (e.g., "Press a key to bind." not "Tell us what key you'd like.").
5. **Play game audio while open.** Music + Ambient + SFX buses suppress per ADR-0004 InputContext.SETTINGS lifecycle. Only the UI bus is live, and the UI bus on this panel is **silent at rest** (no hover chimes, no slider-tick clicks). The exception is the **audio-bus volume sliders themselves** — when the player drags `audio.music_volume_db`, music must be audible to verify the change. (See OQ-SA-7 below.)
6. **Animate at rest.** No fade-in on panel mount. No scale-in on category swap. No tween between detail panes. The revert-banner countdown text update (1 Hz) is the **only** time-varying visual in the entire panel.

### Pillar Fit

| Pillar | Role | How it manifests in this spec |
|---|---|---|
| **Pillar 5: Period Authenticity Over Modernization** | **Primary (carve-out)** | Settings sits explicitly outside Pillar 5's diegetic frame, but **Pillar-5-authentic defaults are preserved**: crosshair OFF, subtitles ON (WCAG floor), clock-tick ON, hold-to-press not toggle, no objective markers exposed. Modern accessibility is opt-IN; period authenticity is the shipping default. |
| **Pillar 3: Stealth is Theatre, Not Punishment** | Supporting | The panel is the invisible stage hand. It removes friction so the show runs. Restraint is the contribution. |
| **Pillar 1: Comedy Without Punchlines** | Supporting | The panel does not crack jokes, wink at the player, or apologise for being itself. Restraint matches Eve's deadpan; the panel is the same character of competence. |

### What goes wrong if this screen is hard to use

- A photosensitive player cannot find or reach `damage_flash_enabled` before the first chromatic flash — **medical onset**. (CR-18 boot-warning is the first defence; this panel is the second.)
- A player using one hand cannot enable Toggle-Sprint and stops playing in Section 1 — **abandonment at MVP gate**.
- A KB+M player needs WASD remapped (e.g., for AZERTY layout, single-hand layouts, custom switch hardware) and cannot — **abandonment**.
- A photosensitive player who set `damage_flash_cooldown_ms = 1000 ms` (maximum protection) presses Restore Defaults to fix a different issue and silently has it reset to 333 ms — **medical regression**. (CR-25 preserves the safety cluster specifically to prevent this.)
- A player drags `graphics.resolution_scale` to 0.5 on a 4K display, the panel becomes unreadable, and there is no recovery path — **lockout**. (CR-15 revert banner with close-as-confirm exists for this.)
- A player rebinds Esc to Fire Weapon and is now unable to close any modal — **lockout**. (Esc + ui_cancel are reserved per OQ #3 of `interaction-patterns.md`.)

Each of the above has a corresponding rule (CR-18, CR-21, CR-22, CR-25, CR-15, reserved-keys list) — this panel is where each rule becomes player-visible.

---

## Player Context on Arrival

The Settings panel has **three distinct arrival paths**, each with a different player goal, emotional register, and time pressure. The panel must serve all three without specialising for any one — but each path has a corresponding entry shape that the design must honour.

### Path 1: Pre-mission, voluntary — from Main Menu

The most common arrival. Player has booted the game, dismissed the photosensitivity warning if applicable, and is on the Main Menu. They press the `[Personnel File]` button (Menu System CR-7, Main Menu Z2). The transition is hard-cut.

| Aspect | Value |
|---|---|
| **What they were just doing** | Reading the Main Menu — possibly confused, possibly oriented; not yet in mission. |
| **Emotional state** | **Curious / preparing** — not stressed. Time is not pressing. They have the patience to read a category list and explore. |
| **Voluntary?** | Yes. They chose this. |
| **Goal** | Either (a) browsing — "what can I configure?" — or (b) targeted change — "I need to enable Toggle-Sprint before I start" or "I need to re-bind WASD because I'm on AZERTY". |
| **Time pressure** | None. Player will read labels. |
| **Frequency** | First-launch is dominant. Returning players may visit before each session if hardware/setup changed. |

The Main Menu pre-mission arrival is the **default design context**. Optimise label legibility, scrollable detail, and discoverability for this case.

### Path 2: Mid-mission, voluntary — from Pause Menu

The player is mid-Plaza or mid-Restaurant section. They press Esc, the Pause Menu opens (Pause Menu UX spec — TBD), they navigate to `[Settings]`. The transition is hard-cut. Game world is paused per Menu System CR-7.

| Aspect | Value |
|---|---|
| **What they were just doing** | In gameplay — possibly mid-stealth-encounter, possibly mid-document-reading, possibly mid-respawn. |
| **Emotional state** | **Mid-flow / interrupted** — they are stopping the game to fix something. There is a **specific friction** prompting the visit. |
| **Voluntary?** | Yes, but reactive (a concrete problem prompted it). |
| **Goal** | Almost always **a single targeted change**: too loud, too dim, sub-optimal sensitivity, want to enable subtitle speaker labels, want to flip Toggle-Crouch on. |
| **Time pressure** | Soft. Game is paused but the player wants to return to gameplay quickly. They will skim categories, not browse. |
| **Frequency** | Less common than Path 1, but more frequent than Path 3. Likely 1-3 visits per playthrough. |

For Path 2, the **resume-from-last-category** behaviour matters: a player who fixed sensitivity 20 minutes ago and now wants to fix volume should not have to re-discover the Audio category. The panel preserves the **last-visited category** within a session (`SettingsService` may forget cross-launch — see Open Question OQ-UX-3 below).

### Path 3: Cold-boot deep-link — from Photosensitivity Boot-Warning

A photosensitive player on first launch has just dismissed the boot-warning modal via the **Go to Settings** button. They land on the Settings panel with the **Accessibility category pre-loaded** and **focus on `damage_flash_enabled`** (per `photosensitivity-boot-warning.md` Section B3 + Settings CR-18).

| Aspect | Value |
|---|---|
| **What they were just doing** | Reading a 38-word locked photosensitivity warning. They have just been informed that the game contains flashing imagery. |
| **Emotional state** | **Cautious / time-pressured** — possibly anxious. They have an active concern about medical safety. They want to find the toggle, change it, and continue. |
| **Voluntary?** | Yes, but the boot-warning's "Go to Settings" button promised to take them somewhere specific. |
| **Goal** | **Disable damage flash** (or reduce its frequency via the cooldown slider). One change, then exit to Main Menu. |
| **Time pressure** | High (they may close the game if they cannot find the setting in seconds). |
| **Frequency** | Once per affected player per launch where boot-warning fires. |

For Path 3, the design **must** make the deep-link target obvious — focus indicator visible the instant the panel mounts (per `interaction-patterns.md` `dual-focus-dismiss` and ADR-0004 §IG7 focus-ring spec), Accessibility category row pre-highlighted in the left ItemList, scroll position at `damage_flash_enabled` (not the top of the Accessibility detail pane). Failure to land focus correctly = silent regression of the photosensitivity safety contract.

### Design implications across paths

| Implication | Reason |
|---|---|
| **Categories must be skim-able by label alone** | Path 2 readers skim. |
| **Default category on first-ever open is Audio** | First-launch pre-mission player; Audio is the most-frequently-touched category and is already MVP-complete (no VS-only knobs). |
| **Last-visited category is restored within session, NOT across launches** | Within-session: serves Path 2 (return to fix related setting). Cross-launch: forget — first-launch dominance, fresh-state predictability. |
| **`open_panel(pre_navigate:)` overrides last-visited** | Path 3 (deep-link) must always win over remembered state. Last-visited is a within-session convenience; deep-link is a contract obligation. |
| **No tutorial layer, no first-time onboarding overlay** | Pillar 5 (no objective markers, no modern AAA hand-holding); the panel is self-explanatory because labels are clear. |
| **Help/tutorial is OUT OF SCOPE** | If a setting needs explanation beyond its label, the label is wrong. Tooltips are flagged as a future pattern (`tooltip-on-hover` in `interaction-patterns.md` Gaps) but are NOT MVP. |

---

## Navigation Position

The Settings panel is **modal-mounted**: it sits on top of its caller (Main Menu OR Pause Menu OR Photosensitivity boot-warning) without replacing it. The caller remains in the scene tree but is gated by `InputContext.SETTINGS` (per ADR-0004 §IG7 — the parent context's input handlers gate-check and early-return while SETTINGS is on the stack). Closing the panel pops the context and returns control to the caller without scene rebuild.

### Tree position (pre-mission Path 1)

```
Main Menu (root)
  └── [Personnel File] button pressed
       └── SettingsService.open_panel("")
            └── Settings Panel (CanvasLayer 10, InputContext.SETTINGS)
```

### Tree position (mid-mission Path 2)

```
Gameplay scene (Plaza/Lower/etc.)
  └── Esc → Pause Menu mounted (CanvasLayer 9, InputContext.PAUSE)
       └── [Settings] button pressed
            └── SettingsService.open_panel("")
                 └── Settings Panel (CanvasLayer 10, InputContext.SETTINGS)
                      [Pause Menu remains in tree, input-gated]
```

### Tree position (cold-boot Path 3)

```
Boot
  └── Main Menu mounted (InputContext.MENU)
       └── Photosensitivity boot-warning modal (InputContext.MODAL, depth-1 from MENU)
            └── [Go to Settings] pressed
                 ├── SettingsService.dismiss_warning() writes flag
                 ├── ModalScaffold.hide_modal() (InputContext.MODAL pops)
                 └── SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")
                      └── Settings Panel (CanvasLayer 10, InputContext.SETTINGS)
```

### Layer placement

- **CanvasLayer 10** — exclusively owned by Settings panel per ADR-0004 §IG7 layer-10 mutex. No siblings on layer 10.
- **Cutscenes letterbox shares CanvasLayer 10** at a different time — mutex enforced via InputContext mutual-exclusion: `InputContext.SETTINGS` and `InputContext.CUTSCENE` cannot be simultaneously on the stack (ADR-0004 §IG7 amended 2026-04-27).
- The boot-warning modal mounts at depth-1 from its parent (so when it dismisses cleanly, depth returns to MENU stack); the Settings panel mounts at depth-1 from its caller (MENU or PAUSE), pushes SETTINGS, and pops SETTINGS on exit.

### One-paragraph orientation map

> **This screen lives at**: `Main Menu → [Personnel File]` OR `Pause Menu → [Settings]` OR `Photosensitivity boot-warning → [Go to Settings]` → **Settings Panel** (CanvasLayer 10, InputContext.SETTINGS, modal over caller).
> Inside the panel, the player navigates: `Settings Panel → Category list (Audio / Graphics / Accessibility / HUD / Controls / Language) → Detail pane`. Some Settings actions launch their own modals: `Restore Defaults → Restore Defaults Confirmation Modal` and `[Show Photosensitivity Notice] → Photosensitivity Review Modal` (both InputContext.MODAL, depth-1 from SETTINGS).

---

## Entry & Exit Points

### Entry Sources

| # | Entry Source | Trigger | API call | Player carries this context | InputContext after entry |
|---|---|---|---|---|---|
| 1 | **Main Menu — `[Personnel File]` button** (Z2 button, Menu System CR-7) | KB+M: `LMB` or `Enter` while focused; Gamepad: `A`; Keyboard nav: `Enter` after `ui_up/ui_down` to focus | `SettingsService.open_panel("")` | Pre-mission. No saved state. Either first launch or returning. Last-visited category may exist in service-side memory if same session. | SETTINGS pushed (depth-1 from MENU) |
| 2 | **Pause Menu — `[Settings]` button** (Pause Menu UX TBD; Menu System CR-3) | KB+M: `LMB` or `Enter`; Gamepad: `A` | `SettingsService.open_panel("")` | Mid-mission. Game paused. Last-visited category preserved within session. | SETTINGS pushed (depth-1 from PAUSE) |
| 3 | **Photosensitivity boot-warning — `[Go to Settings]` button** (per `photosensitivity-boot-warning.md` Section B3, Settings CR-18) | KB+M: `LMB` or `Enter`; Gamepad: `A` | `SettingsService.dismiss_warning()` then `SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")` | Cold-boot. Player has just acknowledged the photosensitivity notice. Photosensitivity_warning_dismissed flag is now `true`. | SETTINGS pushed (depth-1 from MENU; MODAL was popped on dismiss) |

**Notes on entry**:
- Entries 1 and 2 carry an **empty `pre_navigate`** which means: load Audio category by default OR load last-visited category from same-session memory if any. (See OQ-UX-3.)
- Entry 3 always wins — `pre_navigate: "accessibility.damage_flash_enabled"` overrides any stored last-visited category.
- Entries 1 and 3 from MENU context: closing the panel returns to Main Menu.
- Entry 2 from PAUSE context: closing the panel returns to Pause Menu (which still has the player paused mid-mission).
- The boot-warning's `[Continue]` button (sibling to `[Go to Settings]`) does **NOT** open Settings — it dismisses the warning and returns focus to Main Menu's `[Continue/Begin Operation]` button. That path does not enter the Settings panel.

### Exit Destinations

| # | Exit Destination | Trigger | API call | Notes |
|---|---|---|---|---|
| 1 | **Caller (Main Menu OR Pause Menu OR Main Menu)** | KB: `Esc` (`ui_cancel`) at panel root level (NOT during rebind CAPTURING). Gamepad: `B`. Mouse: footer `[Back]` button (LMB). | `SettingsService._dismiss_panel()` → `InputContext.pop()` | Standard exit. All settings already persisted (write-through commit per CR-8). No "save changes?" prompt; nothing to save. |
| 2 | **Caller — close-as-confirm** (resolution-scale special case) | Same as Exit #1, BUT a revert banner is currently active for `graphics.resolution_scale` | `SettingsService._dismiss_panel()` PLUS commit pending resolution_scale to disk (CR-15 close-as-confirm) | New resolution value is **kept** (NOT reverted). The banner copy `"Closing this panel will keep the new resolution."` discloses this in advance. AC-SA-4.6 + AC-SA-11.10. |
| 3 | **Caller — restore-defaults completion** | `[Restore]` pressed in Restore Defaults Confirmation Modal | `SettingsService.restore_defaults()` then modal closes; panel remains open | NOT actually an exit from the panel — the **modal** dismisses, but the Settings panel itself stays open. Listed here for completeness because the action's player-facing label may suggest "exiting back to defaults". Player still has to press `[Back]` to leave the panel. |
| 4 | **Caller — disk-full failure during boot-warning dismiss** | Player chose `[Go to Settings]` from boot-warning, but `dismiss_warning()` returned `false` | None — boot-warning modal stays open, Settings panel does NOT mount | Per AC-MENU-6.4, the warning modal stays mounted with disk-full feedback. Settings panel never opened. This is a non-entry, listed for completeness. |

**Exit invariants**:
- **All changes persist on exit** — there is no "Apply" button, no "Cancel" button. CR-8 write-through commit means every change has already been written to `user://settings.cfg` when the player presses Back. Exception: `graphics.resolution_scale` writes on Exit #2.
- **No "unsaved changes" warning ever appears** on exit. The concept does not exist in this panel.
- **Esc during rebind CAPTURING does NOT exit the panel** — it cancels the capture and returns to NORMAL_BROWSE (AC-SA-6.6, FP-2 reserved-keys list). Capture-cancel is a one-state-back action, not a panel-close action.
- **Esc during CONFLICT_RESOLUTION** behaves as `[Cancel]` on the conflict banner — discards the captured event, returns to NORMAL_BROWSE. Does not exit the panel.
- **Esc with Restore Defaults Confirmation Modal open**: Esc dismisses the modal (default focus is `[Cancel]` so this is the safer outcome). Does not exit the Settings panel.
- **Esc with Photosensitivity Review Modal open** (CR-24 path): Esc dismisses the review modal. Focus returns to `[Show Photosensitivity Notice]` button in Accessibility detail pane. Settings panel stays open. AC-SA-5.10.

### One-way exits

There are **no one-way exits** from this panel. Every exit returns to the caller without state loss; the panel can be re-entered immediately. Settings persist; the player is never locked out of re-entering.

The only **state-changing irreversible action** during a single panel session is Restore Defaults — and even that is reversible by reopening the panel and manually re-tuning. The photosensitivity safety cluster (CR-25) is preserved across Restore Defaults specifically to prevent accidental medical-onset regression.

---

## Layout Specification

### Information Hierarchy

The player must see, in this order:

1. **What screen am I on?** — The header label `"Settings"` (Z1). Confirms the panel mounted correctly. Also the AccessKit `accessibility_name` boundary for screen readers entering the panel.
2. **What categories exist?** — The 6-row category list (Z2). The list IS the navigation; everything else is contingent on which category is selected. Every category name must read on first glance without acronym lookup. (We use `Audio / Graphics / Accessibility / HUD / Controls / Language` — all unambiguous English.)
3. **What category am I currently viewing?** — Selected row in Z2 has a focus-ring + selected-state highlight. This is "you are here".
4. **What can I change in this category?** — The detail pane (Z3) labels first, controls second. Player reads "Master Volume" before they see the slider. Label-on-left, control-on-right per ADR-0004 Theme.
5. **Is there something time-sensitive?** — The revert banner (Z4) appears only when resolution_scale changed in the last 7s. When present, it interrupts the bottom of the visual stack to demand acknowledgment.
6. **How do I leave?** — The footer (Z5): `[Restore Defaults]` left, `[Back]` right. Always present, always visible, never scrolls.
7. **What setting is this?** (per-widget) — Label first, current value second, control third (slider/toggle/dropdown/RebindRow). Help text NOT included at MVP (Pillar 5 — labels must self-explain).

**Hierarchy rule**: nothing in the detail pane (Z3) can hide or override the footer (Z5). The footer is an immortal layer; even if the detail pane scrolls 4× the viewport height, the footer stays anchored and visible. This protects exit paths from being scrolled away.

**Rejected hierarchies**:
- ❌ "Search bar at top to find any setting." Pillar 5 carve-out limits modern UX conveniences; Settings is small enough (≤30 keys at MVP) that linear category navigation is fine. Search adds discoverability benefit only at >100 keys.
- ❌ "Recently changed settings" or "Recommended for you" sub-sections. The panel does not remember or suggest; it presents all configurable values flat per category.
- ❌ "Wizard / first-time setup walkthrough." Path 1 (pre-mission) does not need it; Path 3 (deep-link) is the only first-time-onboarding case and is handled by the boot-warning's existing copy.

---

### Layout Zones

5 zones across a single fixed viewport. Sized for **1920 × 1080 reference** (1080p target per `technical-preferences.md`). Scaling per `accessibility.ui_scale` (75–150% range, VS); MVP layout is 100%-only.

```
┌────────────────────────────────────────────────────────────────┐
│ Z1 — Header (panel title) — 56 px tall                          │
├──────────────┬─────────────────────────────────────────────────┤
│              │                                                  │
│              │                                                  │
│  Z2 — Cat    │  Z3 — Detail Pane (ScrollContainer)              │
│  List        │                                                  │
│  (480 px W,  │                                                  │
│   ~880 px H) │  Settings widgets per selected category          │
│              │                                                  │
│              │                                                  │
│              │                                                  │
├──────────────┴─────────────────────────────────────────────────┤
│ Z4 — Revert Banner (CONDITIONAL — visible only when             │
│      graphics.resolution_scale just changed). 80 px tall.       │
├────────────────────────────────────────────────────────────────┤
│ Z5 — Footer ([Restore Defaults] left / [Back] right) 80 px tall │
└────────────────────────────────────────────────────────────────┘
```

| Zone | Anchor | Dimensions | Always visible? | Notes |
|---|---|---|---|---|
| **Z1 — Header** | Top, full-width | 100% W × 56 px H | Yes | Single Label, centered text `tr("SETTINGS_HEADER_TITLE")` → `"Settings"`. Decorative thin 2 px Ink Black border-bottom. No icon. |
| **Z2 — Category List** | Left, beneath Z1 | 480 px W × ~880 px H (fills available) | Yes | `ItemList` (Godot Control) with 6 rows. Each row is 80 px tall × full Z2 width. Selected row has 4 px BQA Blue focus-ring inset + Parchment background fill. Unselected rows are Ink Black on Parchment-tinted background. NOT a scroll list at MVP (6 items fit). |
| **Z3 — Detail Pane** | Right, beneath Z1 | 1440 px W × ~880 px H (fills available) | Yes (content varies per category) | `ScrollContainer` containing a `VBoxContainer` of widget rows. Scrolls vertically only. Per-row layout: Label-left (40% Z3 width) / Control-right (55% Z3 width) / 5% spacing. Row height varies: Slider 80 px / Toggle 64 px / Dropdown 80 px / RebindRow 96 px / Button 80 px / SubHeader 56 px. |
| **Z4 — Revert Banner** | Bottom, full-width, above Z5 | 100% W × 80 px H | **CONDITIONAL** — only visible when `graphics.resolution_scale` was changed in last 7 s | Inline banner (NOT a modal); contains: countdown text `"Resolution scale changed to {value_pct}. Confirm or revert in {N} seconds."` + `[Keep This Resolution]` button (left, BQA Blue fill) + `[Revert]` button (right, Parchment fill, Ink Black text). Plus inline disclosure label below: `"Closing this panel will keep the new resolution."` (smaller text, regular weight). |
| **Z5 — Footer** | Bottom, full-width, beneath Z4 (or directly beneath Z3 if Z4 hidden) | 100% W × 80 px H | Yes | `[Restore Defaults]` button (left, secondary styling — Parchment fill, Ink Black text) + `[Back]` button (right, BQA Blue fill, Parchment text — primary action). 32 px horizontal padding. |

**Visual register** (per Stage Manager carve-out — Section A refusals):
- Background fill: warm white `#F4EFE2` (Parchment) — the SAME paper colour used in Case File register, but **NO** stamps, NO manila-folder framing, NO carbon-paper texture. The colour is shared so the panel doesn't visually crash with the Main Menu's BQA Blue field, but the panel is plain.
- Border: 2 px Ink Black `#1A1A1A` panel border (full perimeter).
- Typography: Sans-serif (Inter or system fallback per ADR-0004 FontRegistry). NO Futura, NO American Typewriter, NO Courier Prime — those are reserved for diegetic Case File elements.
- Body weight: Regular for labels, Medium for buttons, Bold for the panel header only.
- Font sizes (1080p reference): Header `28 px`, Category-list rows `20 px`, Section sub-headers in detail pane `18 px`, Setting labels `16 px`, Slider value labels `14 px`, Modifier-feedback transient label `14 px`, Footer button labels `18 px`, Revert banner body `16 px`, Revert banner disclosure `14 px`. **All sizes ≥ 14 px** to meet WCAG 2.1 SC 1.4.4 (18 px floor for body where committed; 14 px floor here is justified by `accessibility.ui_scale` 75–150% slider expanding to 24 px at 150%).
- Color palette in panel: Ink Black `#1A1A1A` (text + borders), Parchment `#F4EFE2` (background), BQA Blue `#1B3A6B` (primary action / selected category / focus ring), PHANTOM Red `#C8102E` (used **only** in conflict banner — assertive alert state). NO additional colours.
- No icons MVP. Category names are text-only. Conflict banner has a triangle warning glyph (icon-font, U+26A0) to triple-encode the conflict signal alongside text and PHANTOM Red colour (color-independence per accessibility-requirements.md row 4 — `Conflict banner` triple-encoding).

---

### Component Inventory

Every widget instance the panel may render, per category. Pattern references resolve to `design/ux/interaction-patterns.md` entries.

#### Z1 Header

| Component | Type | Pattern | Content | Interactive? |
|---|---|---|---|---|
| `HeaderTitle` | Label | (none — atomic) | `tr("SETTINGS_HEADER_TITLE")` → `"Settings"` | No (decorative + AccessKit anchor) |

#### Z2 Category List (6 rows)

| Component | Type | Pattern | Content | Interactive? |
|---|---|---|---|---|
| `CategoryList` | ItemList | (none — atomic; nav handled by `input-context-stack` semantics) | 6 rows: `Audio / Graphics / Accessibility / HUD / Controls / Language`. tr-keys: `SETTINGS_CATEGORY_AUDIO`, `_GRAPHICS`, `_ACCESSIBILITY`, `_HUD`, `_CONTROLS`, `_LANGUAGE`. | Yes (selectable; `item_selected` swaps detail pane) |

#### Z3 Detail Pane — Audio category (6 sliders, all MVP)

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `MasterVolumeSlider` | HSlider + Label + ValueLabel | **NEW** `settings-slider-pattern` (gap-flagged, lifted at handoff) | `audio.master_volume_db` | 0.0 dB *(tentative; OQ-SA-14)* | [-80.0, 0.0] | Yes (drag/keyboard step ±1 dB; gamepad d-pad fine ±1 dB) |
| `MusicVolumeSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `audio.music_volume_db` | 0.0 dB | [-80.0, 0.0] | Yes |
| `SfxVolumeSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `audio.sfx_volume_db` | 0.0 dB | [-80.0, 0.0] | Yes |
| `AmbientVolumeSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `audio.ambient_volume_db` | 0.0 dB | [-80.0, 0.0] | Yes |
| `VoiceVolumeSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `audio.voice_volume_db` | 0.0 dB | [-80.0, 0.0] | Yes |
| `UiVolumeSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `audio.ui_volume_db` | 0.0 dB | [-80.0, 0.0] | Yes |

Audio category is fully MVP. No VS additions planned at MVP scope.

#### Z3 Detail Pane — Graphics category (1 dropdown MVP, more reserved VS)

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `ResolutionScaleDropdown` | OptionButton + Label + ValueLabel | `accessibility-opt-in-toggle` (variant for OptionButton) | `graphics.resolution_scale` | hardware-detected (CR-11): Iris Xe → 0.75; RTX 2060+ → 1.0; unknown → 1.0 | {0.5 = "50%", 0.6 = "60%", 0.75 = "75%", 1.0 = "100%"} | Yes (dropdown; `item_selected` triggers revert banner, see CR-15) |
| `OutlineThicknessSlider` (VS) | HSlider | `settings-slider-pattern` | `graphics.outline_thickness_px` | 2.0 | [1.0, 4.0] | VS — placeholder, not rendered at MVP |

Graphics MVP: 1 widget. VS: +1 widget.

#### Z3 Detail Pane — Accessibility category (PRIMARY MVP CLUSTER — 11 widgets MVP, 5 VS)

The most consequential detail pane. Photosensitivity cluster is rendered **first** (top of pane, highest visual priority — Path 3 deep-link landing zone). Subtitle cluster second. Hold-vs-toggle cluster lives under Controls category, NOT here, per CR-21.

**Photosensitivity cluster (top of pane)**:

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `PhotosensitivitySubHeader` | Label (sub-header style) | (decorative) | `tr("SETTINGS_ACCESSIBILITY_SUBHEADER_PHOTOSENSITIVITY")` → `"Photosensitivity"` | n/a | n/a | No |
| `DamageFlashEnabledToggle` | CheckButton + Label | `accessibility-opt-in-toggle` (opt-OUT variant: default ON) | `accessibility.damage_flash_enabled` | `true` | bool | Yes — **deep-link target for Path 3** |
| `DamageFlashCooldownSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `accessibility.damage_flash_cooldown_ms` | 333 | [333, 1000] — **333 SAFETY FLOOR** clamped UI + load-time | Yes |
| `ShowPhotosensitivityNoticeButton` | Button | (atomic — wraps `modal-scaffold`) | n/a (button-only, calls `SettingsService.open_modal_photosensitivity_review()`) | n/a | n/a | Yes (re-fires CR-24 review modal) |

**Visual + audio cluster**:

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `VisualAudioSubHeader` | Label | (decorative) | `tr("SETTINGS_ACCESSIBILITY_SUBHEADER_VISUAL_AUDIO")` → `"Visual & Audio"` | n/a | n/a | No |
| `CrosshairEnabledToggle` | CheckButton + Label | `accessibility-opt-in-toggle` (opt-OUT variant: default ON) | `accessibility.crosshair_enabled` | `true` | bool | Yes |
| `ClockTickEnabledToggle` | CheckButton + Label | `stage-manager-carve-out` | `accessibility.clock_tick_enabled` | `true` | bool | Yes |

**Subtitle cluster**:

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `SubtitlesSubHeader` | Label | (decorative) | `tr("SETTINGS_ACCESSIBILITY_SUBHEADER_SUBTITLES")` → `"Subtitles"` | n/a | n/a | No |
| `SubtitlesEnabledToggle` | CheckButton + Label | `accessibility-opt-in-toggle` (opt-OUT — WCAG SC 1.2.2 default ON) | `accessibility.subtitles_enabled` | `true` | bool | Yes |
| `SubtitleSizeScaleDropdown` | OptionButton + Label | `accessibility-opt-in-toggle` (OptionButton variant) | `accessibility.subtitle_size_scale` | 1.0 (M) | {0.8 = "S", 1.0 = "M", 1.5 = "L", 2.0 = "XL"} | Yes |
| `SubtitleBackgroundDropdown` | OptionButton + Label | `accessibility-opt-in-toggle` (OptionButton variant) | `accessibility.subtitle_background` | `scrim` | {none, scrim, opaque} | Yes |
| `SubtitleSpeakerLabelsToggle` | CheckButton + Label | `accessibility-opt-in-toggle` (opt-OUT variant) | `accessibility.subtitle_speaker_labels` | `true` | bool | Yes |
| `SubtitleLineSpacingSlider` (MVP-write only) | HSlider + Label + ValueLabel | `settings-slider-pattern` | `accessibility.subtitle_line_spacing_scale` | 1.0 | [1.0, 1.5] | Yes (MVP-write; D&S consumes at VS) |
| `SubtitleLetterSpacingSlider` (MVP-write only) | HSlider + Label + ValueLabel | `settings-slider-pattern` | `accessibility.subtitle_letter_spacing_em` | 0.0 em | [0.0, 0.12] em | Yes (MVP-write; D&S consumes at VS) |

**VS cluster** (rendered at VS only — not in MVP detail pane):

| Component | Type | Pattern | Setting key | Default | Range | Scope |
|---|---|---|---|---|---|---|
| `EnhancedHitFeedbackToggle` (VS) | CheckButton + Label | `accessibility-opt-in-toggle` | `accessibility.enhanced_hit_feedback_enabled` | `false` | bool | VS |
| `GadgetReadyIndicatorToggle` (VS) | CheckButton + Label | `accessibility-opt-in-toggle` | `accessibility.gadget_ready_indicator_enabled` | `false` | bool | VS |
| `HapticFeedbackToggle` (VS) | CheckButton + Label | `accessibility-opt-in-toggle` | `accessibility.haptic_feedback_enabled` | `true` | bool | VS |
| `DamageFlashDurationSlider` (VS) | HSlider | `settings-slider-pattern` | `accessibility.damage_flash_duration_frames` | 1 | [1, 6] | VS |
| `AdsTweenMultiplierSlider` (VS) | HSlider | `settings-slider-pattern` | `accessibility.ads_tween_duration_multiplier` | 1.0× | [1.0, 3.0] | VS |
| `ReducedMotionToggle` (VS) | CheckButton + Label | `accessibility-opt-in-toggle` (opt-IN — default OFF for period authenticity) | `accessibility.reduced_motion_enabled` | `false` | bool | VS — gates Cutscenes letterbox slide-in, F&R sepia transition, etc. |
| `ColorblindModeDropdown` (VS) | OptionButton | (none) | `accessibility.colorblind_mode` | `none` | {none, protanopia, deuteranopia, tritanopia} | VS |

#### Z3 Detail Pane — HUD category (cross-ref label MVP, 3 widgets VS)

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `CrosshairCrossRefLabel` (MVP) | Label + Button | (atomic) | `tr("SETTINGS_HUD_CROSSHAIR_REDIRECT")` → `"Crosshair settings live in Accessibility → Visual & Audio."` + `[Go to Accessibility]` | n/a | n/a | Yes (button calls `SettingsService.open_panel(pre_navigate: "accessibility.crosshair_enabled")`) |
| `HudScaleSlider` (VS) | HSlider | `settings-slider-pattern` | `hud.hud_scale` | 1.0 | [0.75, 1.5] | VS |
| `CrosshairDotSizeSlider` (VS) | HSlider | `settings-slider-pattern` | `hud.crosshair_dot_size_pct_v` | 0.19% | [0.15%, 0.30%] | VS |
| `CrosshairHaloDropdown` (VS) | OptionButton | (atomic) | `hud.crosshair_halo_style` | `tri_band` | {none, parchment_only, tri_band} | VS |

HUD MVP renders only the cross-ref label (cross-discoverability); no other HUD knobs at MVP.

#### Z3 Detail Pane — Controls category (4 toggles + 4 sliders + 2 axis-toggles + 36 RebindRows MVP, gamepad column VS)

**Toggle cluster**:

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `MotorSubHeader` | Label | (decorative) | `tr("SETTINGS_CONTROLS_SUBHEADER_MOTOR")` → `"Motor accessibility"` | n/a | n/a | No |
| `SprintIsToggleCheckbox` | CheckButton + Label | `toggle-hold-alternative` | `controls.sprint_is_toggle` | `false` (hold-to-press is period-authentic default) | bool | Yes |
| `CrouchIsToggleCheckbox` | CheckButton + Label | `toggle-hold-alternative` | `controls.crouch_is_toggle` | `false` | bool | Yes |
| `AdsIsToggleCheckbox` | CheckButton + Label | `toggle-hold-alternative` | `controls.ads_is_toggle` | `false` | bool | Yes |

**Sensitivity cluster**:

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `SensitivitySubHeader` | Label | (decorative) | `tr("SETTINGS_CONTROLS_SUBHEADER_SENSITIVITY")` → `"Sensitivity"` | n/a | n/a | No |
| `MouseSensitivityXSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `controls.mouse_sensitivity_x` | 1.0× | [0.1, 5.0] | Yes |
| `MouseSensitivityYSlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `controls.mouse_sensitivity_y` | 1.0× | [0.1, 5.0] | Yes |
| `GamepadLookSensitivitySlider` | HSlider + Label + ValueLabel | `settings-slider-pattern` | `controls.gamepad_look_sensitivity` | 1.0× | [0.1, 5.0] | Yes |
| `InvertYAxisCheckbox` | CheckButton + Label | (atomic) | `controls.invert_y_axis` | `false` | bool | Yes |

**Rebind cluster (36 RebindRows — MVP renders KB+M column only; gamepad column reserved VS per OQ-SA-5)**:

| Component | Type | Pattern | Action | Default KB+M | Default Gamepad | Interactive? |
|---|---|---|---|---|---|---|
| `RebindSubHeader` | Label | (decorative) | `tr("SETTINGS_CONTROLS_SUBHEADER_REBIND")` → `"Key bindings"` + sub-text `"Press a key to bind. Esc to cancel."` (transient hint MVP) | n/a | n/a | No |
| `RebindRow_move_forward` | RebindRow (Label + CaptureButton) | `rebind-three-state-machine` + `held-key-flush-after-rebind` | `move_forward` | `KEY_W` | `JOY_AXIS_LEFT_Y_NEG` | Yes |
| `RebindRow_move_backward` | RebindRow | `rebind-three-state-machine` | `move_backward` | `KEY_S` | `JOY_AXIS_LEFT_Y_POS` | Yes |
| `RebindRow_move_left` | RebindRow | `rebind-three-state-machine` | `move_left` | `KEY_A` | `JOY_AXIS_LEFT_X_NEG` | Yes |
| `RebindRow_move_right` | RebindRow | `rebind-three-state-machine` | `move_right` | `KEY_D` | `JOY_AXIS_LEFT_X_POS` | Yes |
| `RebindRow_jump` | RebindRow | `rebind-three-state-machine` | `jump` | `KEY_SPACE` | `JOY_BUTTON_A` | Yes (note: jump may not be in MVP gameplay set; if absent from InputMap, row is hidden) |
| `RebindRow_sprint` | RebindRow | `rebind-three-state-machine` | `sprint` | `KEY_SHIFT` | `JOY_BUTTON_LEFT_SHOULDER` | Yes |
| `RebindRow_crouch` | RebindRow | `rebind-three-state-machine` | `crouch` | `KEY_CTRL` | `JOY_BUTTON_RIGHT_STICK` | Yes |
| `RebindRow_ads` | RebindRow | `rebind-three-state-machine` | `ads` | `MOUSE_RIGHT_BUTTON` | `JOY_AXIS_TRIGGER_LEFT` | Yes |
| `RebindRow_fire` | RebindRow | `rebind-three-state-machine` | `fire` | `MOUSE_LEFT_BUTTON` | `JOY_AXIS_TRIGGER_RIGHT` | Yes |
| `RebindRow_reload` | RebindRow | `rebind-three-state-machine` | `reload` | `KEY_R` | `JOY_BUTTON_X` | Yes |
| `RebindRow_use_gadget` | RebindRow | `rebind-three-state-machine` | `use_gadget` (CR-22 differentiated) | `KEY_F` | `JOY_BUTTON_Y` | Yes |
| `RebindRow_takedown` | RebindRow | `rebind-three-state-machine` | `takedown` (CR-22 differentiated) | `KEY_Q` | `JOY_BUTTON_X` | Yes (note: `takedown`'s gamepad default `JOY_BUTTON_X` will conflict with `reload`; first-launch InputMap may differ — see Open Question OQ-UX-2) |
| `RebindRow_interact` | RebindRow | `rebind-three-state-machine` | `interact` | `KEY_E` | `JOY_BUTTON_A` | Yes |
| `RebindRow_inventory` | RebindRow | `rebind-three-state-machine` | `inventory` | `KEY_TAB` | `JOY_BUTTON_BACK` | Yes |
| `RebindRow_quicksave` | RebindRow | `rebind-three-state-machine` | `quicksave` | `KEY_F5` | (none) | Yes |
| `RebindRow_quickload` | RebindRow | `rebind-three-state-machine` | `quickload` | `KEY_F9` | (none) | Yes |
| `RebindRow_pause` | RebindRow | `rebind-three-state-machine` | `pause` | `KEY_ESCAPE` | `JOY_BUTTON_START` | **No** — Esc / ui_cancel are reserved (per `interaction-patterns.md` OQ #3 recommendation: lock Esc as non-rebindable). Row is rendered as **disabled** with a footnote `tr("SETTINGS_REBIND_RESERVED")` → `"System reserved."` |

**Reserved (non-rebindable) actions** — rendered with `disabled = true`, capture button greyed, `accessibility_description = tr("SETTINGS_REBIND_RESERVED_DESC")` → `"This binding is reserved by the game and cannot be changed."`:

- `pause` / `ui_cancel` (Esc / B / Start) — lockout protection
- `ui_accept` (Enter / A) — focus interaction reserved
- `ui_focus_next` / `ui_focus_prev` (Tab / Shift+Tab) — focus chain reserved

**Note on count**: ~36 actions is upper bound counting all Player Character + Combat + UI actions. The Settings panel renders **only** rebindable gameplay+UI actions; reserved actions are still shown (greyed) so players can see them; engine-reserved actions (e.g., `ui_text_*`) are not shown at all. Final action list is owned by Input GDD §C and tr-keys are owned by Input GDD per OQ-SA-11.

#### Z3 Detail Pane — Language category (1 label MVP, 1 dropdown VS)

| Component | Type | Pattern | Setting key | Default | Range | Interactive? |
|---|---|---|---|---|---|---|
| `LanguageMvpNoticeLabel` (MVP) | Label | (atomic) | `tr("LANGUAGE_MVP_NOTICE")` → `"English (additional languages coming in a future update)"` | n/a | n/a | No (info-only) |
| `LocaleDropdown` (VS) | OptionButton | (atomic) | `language.locale` | `"en"` | per `TranslationServer.get_loaded_locales()` | Yes (VS only — when 2nd locale ships) |

#### Z4 Revert Banner (conditional)

| Component | Type | Pattern | Content | Interactive? |
|---|---|---|---|---|
| `RevertBannerBody` | Label | (atomic) | `tr("SETTINGS_RESOLUTION_REVERT_PROMPT")` → `"Resolution scale changed to {value_pct}. Confirm or revert in {N} seconds."` | No |
| `RevertBannerDisclosure` | Label | (atomic) | `tr("SETTINGS_RESOLUTION_REVERT_DISCLOSURE")` → `"Closing this panel will keep the new resolution."` | No |
| `KeepResolutionButton` | Button (primary) | (atomic) | `tr("SETTINGS_RESOLUTION_KEEP")` → `"Keep This Resolution"` | Yes |
| `RevertResolutionButton` | Button (secondary) | (atomic) | `tr("SETTINGS_RESOLUTION_REVERT")` → `"Revert"` | Yes |

#### Z5 Footer

| Component | Type | Pattern | Content | Interactive? |
|---|---|---|---|---|
| `RestoreDefaultsButton` | Button (secondary) | (wraps `modal-scaffold` for confirmation) | `tr("SETTINGS_RESTORE_DEFAULTS")` → `"Restore Defaults"` | Yes (opens confirmation modal) |
| `BackButton` | Button (primary) | (atomic — wraps `unhandled-input-dismiss` + `set-handled-before-pop`) | `tr("SETTINGS_BACK")` → `"Back"` | Yes |

#### Modal sub-surfaces (depth-1 from SETTINGS, InputContext.MODAL)

| Modal | Trigger | Pattern | Content | Inheriting? |
|---|---|---|---|---|
| `RestoreDefaultsConfirmModal` | `[Restore Defaults]` button pressed | `modal-scaffold` (Stage Manager variant — NOT Case File) | Body: `tr("SETTINGS_RESTORE_DEFAULTS_CONFIRM")` → `"Restore all settings to defaults? Your photosensitivity preferences will be preserved."` Buttons: `[Restore]` (left, secondary) + `[Cancel]` (right, primary, default focus). | Inherits modal-scaffold mechanics; visual register = Stage Manager (Parchment + BQA Blue, NOT Case File destructive). |
| `PhotosensitivityReviewModal` | `[Show Photosensitivity Notice]` button pressed (CR-24 path) | `modal-scaffold` + `photosensitivity-boot-warning` (review variant — `dismiss_warning()` NOT called) | Body: identical 38-word locked CR-18 copy. Buttons: `[Continue]` + `[Go to Settings]` (both close modal; do NOT call dismiss_warning since flag stays true). Default focus: `[Continue]`. | Inherits boot-warning content + scaffold; differs in dismiss-flag behaviour. |

**Component inventory totals**:
- **MVP**: 1 (header) + 1 (cat list with 6 rows) + 6 (Audio) + 1 (Graphics) + 14 (Accessibility cluster) + 1 (HUD redirect) + 12 (Controls toggles+sliders+axis) + ~16 (Controls RebindRows MVP rendered) + 1 (Language) + 4 (revert banner conditional) + 2 (footer) + 2 (modal sub-surfaces) = **~60 widgets**
- **VS**: +6 Accessibility (EHF, gadget-ready, haptic, flash duration, ADS multiplier, reduced-motion, colorblind) + 3 HUD + 1 Language dropdown + ~16 gamepad-column RebindRows = **+~26 widgets** (roughly +43%)

---

### ASCII Wireframe

Default state — Path 1 (pre-mission, Audio category, no banner). Drawn to scale at 1080p reference (1920 × 1080); each char ≈ 16 px horizontal × 16 px vertical (approximate).

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  Settings                                             │  Z1 Header (56 px)
├──────────────────┬──────────────────────────────────────────────────────────────────┤
│                  │                                                                    │
│  ▶ Audio    [F]  │  ┌──────────────────────────────────────────────────────────────┐ │
│                  │  │                                                                │ │
│    Graphics      │  │   Master Volume         ◄═══════════════════════════════►     │ │
│                  │  │                                                       0 dB    │ │
│    Accessibility │  │                                                                │ │
│                  │  │   Music Volume          ◄══════════════════════════════►      │ │
│    HUD           │  │                                                       0 dB    │ │
│                  │  │                                                                │ │
│    Controls      │  │   SFX Volume            ◄══════════════════════════════►      │ │
│                  │  │                                                       0 dB    │ │
│    Language      │  │                                                                │ │
│                  │  │   Ambient Volume        ◄══════════════════════════════►      │ │
│                  │  │                                                       0 dB    │ │
│                  │  │                                                                │ │
│                  │  │   Voice Volume          ◄══════════════════════════════►      │ │
│                  │  │                                                       0 dB    │ │
│                  │  │                                                                │ │
│                  │  │   UI Volume             ◄══════════════════════════════►      │ │
│                  │  │                                                       0 dB    │ │
│                  │  │                                                                │ │
│                  │  │                  ⌃ scrolls if content > viewport ⌄             │ │
│                  │  └──────────────────────────────────────────────────────────────┘ │
│                  │                                                                    │
│                  │                                                                    │
├──────────────────┴──────────────────────────────────────────────────────────────────┤
│                                                                                       │
│  [ Restore Defaults ]                                              [ Back ]          │  Z5 Footer (80 px)
│                                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Variant — Path 3 (cold-boot deep-link, Accessibility category, focus on `damage_flash_enabled`)**:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  Settings                                             │  Z1 Header
├──────────────────┬──────────────────────────────────────────────────────────────────┤
│                  │                                                                    │
│    Audio         │   Photosensitivity                                                 │
│                  │                                                                    │
│    Graphics      │  ┌──────────────────────────────────────────────────────────────┐ │
│                  │  │ Damage flash                                          [ ◉ ] ⤴ │ │  ← focus ring
│  ▶ Accessibility │  └──────────────────────────────────────────────────────────────┘ │     (4 px BQA Blue)
│                  │                                                                    │
│    HUD           │   Damage flash interval     ◄═══════════════════════════════►     │
│                  │                                                       333 ms      │
│    Controls      │                                                                    │
│                  │   [ Show Photosensitivity Notice ]                                 │
│    Language      │                                                                    │
│                  │   Visual & Audio                                                   │
│                  │                                                                    │
│                  │   Crosshair                                              [ ◉ ]    │
│                  │                                                                    │
│                  │   Clock tick                                             [ ◉ ]    │
│                  │                                                                    │
│                  │   Subtitles                                                        │
│                  │                                                                    │
│                  │   Subtitles                                              [ ◉ ]    │
│                  │   Subtitle size            [ M ▼ ]                                 │
│                  │   Subtitle background      [ Scrim ▼ ]                             │
│                  │   Speaker labels                                         [ ◉ ]    │
│                  │                  ⌃ scrolls — more below ⌄                          │
├──────────────────┴──────────────────────────────────────────────────────────────────┤
│  [ Restore Defaults ]                                              [ Back ]          │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Variant — Resolution-scale revert banner active (Z4 visible)**:

```
├──────────────────┴──────────────────────────────────────────────────────────────────┤
│  Resolution scale changed to 75%. Confirm or revert in 5 seconds.                    │  Z4 (80 px)
│  Closing this panel will keep the new resolution.                                    │
│                       [ Keep This Resolution ]    [ Revert ]                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  [ Restore Defaults ]                                              [ Back ]          │  Z5
└─────────────────────────────────────────────────────────────────────────────────────┘
```

**Variant — Rebind CAPTURING state (Controls category, captured `move_forward`)**:

```
│   Move Forward            [ Press a key to bind. Esc to cancel. ] ⤴               │
│                                                                                     │
│   Move Backward           [ S ]                                                    │
│                                                                                     │
│   Move Left               [ A ] (disabled — resolve current capture first)         │
│   Move Right              [ D ] (disabled — resolve current capture first)         │
```

**Variant — CONFLICT_RESOLUTION state (RebindRow with conflict banner inline)**:

```
│   Move Forward            ⚠  Conflict: Sprint is already bound to this key.        │
│                              [ Replace ]    [ Cancel ]                              │
│                                                                                     │
│   Move Backward           [ S ] (disabled — resolve current conflict first)        │
│   Move Left               [ A ] (disabled — resolve current conflict first)        │
```

---

## States & Variants

The panel can be in one of **11 distinct states** at any moment. Many overlap; rules of mutual exclusion are documented per state.

| State / Variant | Trigger | What Changes | Mutually Exclusive With |
|---|---|---|---|
| **Default — NORMAL_BROWSE** | Panel mounted, no modal open, no banner active | Z1+Z2+Z3+Z5 visible; Z4 hidden; selected category from `pre_navigate` (Path 3) OR last-visited within session (Path 2) OR Audio (Path 1 first-launch); first focusable widget in detail pane has focus ring | All other states except `Resolution-scale revert banner active` (which can compose on top) |
| **Resolution-scale revert banner active** | `graphics.resolution_scale` changed via dropdown; 7 s timer running | Z4 banner visible at bottom (above Z5); detail pane scroll continues to work; player can interact with any other widget; banner countdown updates 1 Hz: `"…in 7s"` → `"…in 6s"` → … → auto-revert at 0s | Coexists with NORMAL_BROWSE; mutually exclusive with `RestoreDefaultsConfirmModal open` (banner timer pauses while modal blocks) |
| **Rebind — CAPTURING** | Player clicked CaptureButton on a RebindRow in Controls | All OTHER RebindRows render `disabled = true` ("Resolve current capture first"); Z2 category list focus blocked; transient capture-hint label visible inline on the active RebindRow: `"Press a key to bind. Esc to cancel."`; modifier-feedback inline label may appear if modifier held; Esc cancels capture (does NOT close panel) | All other states |
| **Rebind — CONFLICT_RESOLUTION** | Captured key matches existing binding | Active RebindRow shows inline conflict banner with `[Replace]` and `[Cancel]` buttons + warning glyph + PHANTOM Red `#C8102E` border; all OTHER widgets in panel render `disabled = true` | All other states except (rare) Resolution-scale revert banner active |
| **Restore Defaults Confirmation Modal open** | Player pressed `[Restore Defaults]` button in Z5 | Settings panel input-gated; modal mounted at depth-1 from SETTINGS (InputContext.MODAL); modal body: `"Restore all settings to defaults? Your photosensitivity preferences will be preserved."`; default focus on `[Cancel]`; revert banner timer **pauses** while modal blocks | All other states (modal is exclusive blocking layer) |
| **Photosensitivity Review Modal open (CR-24 path)** | Player pressed `[Show Photosensitivity Notice]` button in Accessibility detail pane | Settings panel input-gated; modal mounted at depth-1 from SETTINGS; modal content identical to CR-18 boot-warning copy; `dismiss_warning()` is NOT called; closing the modal returns focus to `[Show Photosensitivity Notice]` button (AC-SA-5.10) | All other states |
| **First-launch (no `settings.cfg` on disk)** | First time player opens panel after fresh install | `settings_loaded` not yet emitted at panel mount may cause `_boot_warning_pending = true` → boot-warning modal (CR-18) gates Main Menu first; this state is not technically a Settings-panel state, but it is the precondition that ALL Path 3 entries depend on | (sequenced: completes before any panel state) |
| **Pre-navigated (Path 3 deep-link landing)** | Panel mounted via `open_panel(pre_navigate: "accessibility.damage_flash_enabled")` | Selected category = Accessibility; ScrollContainer scrolled so `DamageFlashEnabledToggle` widget is in centre 50% of viewport; widget has focus ring; AccessKit announces widget on mount (live="polite") | Variant of NORMAL_BROWSE; coexists with all non-modal states |
| **Settings-loaded-pending boot edge case** | Panel mounted before `Events.settings_loaded` has fired (theoretically possible only via developer-tools direct invocation; CR-3 + CR-9 + autoload ordering should prevent) | Detail pane shows current values which may be hardware-defaulted but not yet burst-emitted to consumers; this is a transient invariant — `settings_loaded` fires within milliseconds. UX MUST NOT show "Loading…" placeholder; values are read-immediately from in-memory state. | Coexists with NORMAL_BROWSE; resolves silently within frame |
| **Disk-full failure** | Any write-through commit returns `false` from `ConfigFile.save()` | Inline transient label appears beneath the affected widget: `tr("SETTINGS_WRITE_FAILED")` → `"Could not save. Check disk space."` (4 s display, AccessKit `live="assertive"`); the in-memory value still applies (consumers received their `setting_changed`); only persistence failed; on next interaction with that widget, retry occurs automatically | Coexists with NORMAL_BROWSE |
| **Settings panel hidden / closed** | Panel dismissed via `[Back]` / Esc / close-as-confirm | Panel removed from scene tree; CanvasLayer 10 freed; InputContext.SETTINGS popped; caller (MENU/PAUSE) regains input | Terminal state — no other states apply |

**Edge cases the GDD does not cover** (flagged for verification or design decision):

| Scenario | Behaviour | Open question? |
|---|---|---|
| Banner timer running, modal opens (e.g., player presses Restore Defaults during banner) | Banner timer **pauses** while any modal is on the stack. When modal dismisses, timer resumes from where it paused. | YES — see OQ-UX-1 |
| Capture in progress, player tries to switch category via mouse click | Click is intercepted: capture-cancel runs first, THEN the click is processed (single-action takes precedence). Documented in `interaction-patterns.md` `set-handled-before-pop` extension. | NO — documented |
| Player presses Restore Defaults during CAPTURING | Restore Defaults button is disabled in Z5 while CAPTURING (because all OTHER widgets are disabled per state spec). | NO — covered by CAPTURING semantics |
| Two RebindRows are mid-conflict simultaneously | Cannot happen — CONFLICT_RESOLUTION blocks all other RebindRows, including their CaptureButtons. Sequential conflict resolution only. | NO — invariant by state machine |
| Resolution-scale revert banner timer expires while player is inside a non-Graphics category | Auto-revert fires, banner dismisses, focus is **not stolen** — player continues interacting with their current widget. AccessKit announces revert: `live="polite"` (NOT assertive). | NO — design choice (don't steal focus during background timeout) |
| Settings opened from boot-warning, but `dismiss_warning()` returned false (disk full) | Settings panel does NOT mount; boot-warning modal stays open with disk-full feedback (per AC-MENU-6.4). The Settings panel state is "not entered". | NO — covered |

---

## Interaction Map

Mapping interactions for **Keyboard/Mouse (MVP, primary input) and Gamepad (Partial — full menu navigation, post-MVP rebinding parity)** per `technical-preferences.md`. No touch.

Interactions are presented per **widget archetype** (since instances share semantics) with per-instance variations called out where relevant.

### Archetype 1: `CategoryList` (Z2)

The 6-row navigation list. Selecting a row swaps the detail pane.

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Browse rows** | `↑` / `↓` (`ui_up`/`ui_down`) | D-pad `↑`/`↓` OR Left stick `↑`/`↓` | Focus ring moves to next/previous row; AccessKit announces `accessibility_name` of focused row + position (`"Audio, 1 of 6"`) | Selected row in ItemList changes; **detail pane does NOT swap on focus-only**. |
| **Activate row (load detail pane)** | `Enter` (`ui_accept`) OR `→` (`ui_right`) OR mouse click | `A` (`ui_accept`) OR D-pad `→` | No audio (Stage Manager #5); detail pane swap is zero-frame (Stage Manager #6); first focusable widget in new detail pane gains focus ring | `setting_changed` not emitted (this is navigation, not a setting); `ItemList.item_selected` signal fires; detail pane content swaps (no animation per Stage Manager refusal). |
| **Hover row (mouse)** | Mouse hover | n/a | Hover-state fill: lighter Parchment tint on the hovered row (no border change) | No outcome until click — hover does NOT swap detail pane (prevents accidental thrash on mouse moves; per Settings GDD §C.4). |
| **Mouse click row** | LMB on row | n/a | Selection updates immediately | Equivalent to `ui_accept` activate. |
| **Wrap-around** | `↑` at top OR `↓` at bottom | D-pad/stick equivalent | Focus wraps to opposite end (top→bottom, bottom→top) | Wrap is **enabled** for Z2 ItemList (6 items, easy to over-shoot). Detail pane does NOT wrap. |
| **Cross-column (left-to-right)** | `→` (`ui_right`) | D-pad `→` | Focus jumps to first focusable widget in detail pane | Detail pane is loaded for the currently-selected category (NOT the focused-but-not-yet-selected row — they are the same in Z2). |
| **Tab navigation** | `Tab` | (n/a — gamepad does not use Tab) | Focus advances to next widget within the **current column only** (Z2 only); does NOT cross to detail pane via Tab. (Per AC-SA-11.7 amended 2026-04-27.) | Tab cycles within Z2 column; reaches Z5 footer via explicit focus-chain after column escape (`↓` past last row → focus jumps to Z5). |
| **Esc** | `Esc` (`ui_cancel`) | `B` | Triggers panel dismiss (per Z5 `[Back]` button semantics) | Closes panel. AC-SA-6.6 exception: NOT during CAPTURING. |

### Archetype 2: `HSlider` (settings-slider-pattern — 13 instances)

Continuous-value slider with live-preview on drag, commit-on-release. **First concrete instance of `settings-slider-pattern`** — pattern abstracted to library at handoff (see Open Question OQ-UX-LIB-1).

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Focus slider** | Tab/`↓` to slider | D-pad `↓` to slider | Focus ring (4 px BQA Blue) on slider track | None (focus only) |
| **Drag slider (mouse)** | LMB drag on track | n/a | (a) Slider thumb moves with cursor; (b) value label updates in real time (`"-12 dB"`, `"75%"`, `"333 ms"`); (c) `setting_changed` emits per `value_changed` tick → consumers preview live | Per-tick preview only; **NOT written to disk per tick** (CR-8). |
| **Click track** | LMB on track | n/a | Thumb jumps to clicked position; value label updates | Same as drag start at click position. |
| **Coarse step (KB)** | `←` / `→` | D-pad `←` / `→` | Slider thumb advances by `step` (1 dB / 5% / 1 ms / etc., per slider's `step` value); value label updates; `setting_changed` emits with new value | Live preview emits per step; **NOT written to disk per step** (CR-8). |
| **Fine step (gamepad)** | n/a | Left stick `←/→` (analog, deadzone-respecting; clamped to slider range) | Slider thumb advances proportionally to stick deflection per frame | Same live-preview semantics. |
| **Page step** | `Page Up` / `Page Down` | (n/a — gamepad uses fine step instead) | Slider thumb advances by 10× step | Live preview emits. |
| **Home / End** | `Home` / `End` | (n/a) | Slider thumb jumps to `min_value` / `max_value` | Single `setting_changed` emit. |
| **Commit** | Release LMB drag OR release `←/→` key (no separate commit input) | Release stick | Slider stays at final position; value label final | `ConfigFile.save()` called once on `drag_ended(value_changed=true)` (CR-8). Single disk write per drag/step interaction sequence. |
| **Special — DamageFlashCooldownSlider safety floor** | Cannot drag below 333 (UI clamp at `min_value=333` per CR-17 + AC-SA-5.3) | Same | Slider thumb visually stops at 333 ms; subsequent drag-left attempts have no visual effect | UI clamp; defensive clamp also applied at load-time. |
| **Special — VolumeSlider live mix preview** | Drag emits `setting_changed`; Audio service applies dB to bus; player hears the change | Same | Audio bus volume changes audibly mid-drag (this is the only live audio in panel) | OQ-SA-7 ADVISORY: should panel-open suppress music? Recommendation: NO duck (players hear live preview). |

### Archetype 3: `CheckButton` (Toggle — 16+ instances)

Boolean toggle. Single-press commit.

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Focus toggle** | Tab/`↓` | D-pad `↓` | Focus ring | None |
| **Toggle state** | `Space` OR `Enter` (`ui_accept`) OR LMB on checkbox area | `A` (`ui_accept`) | Visual swap: empty box → filled box (or vice versa); NO sound, NO animation (Stage Manager #2 + #6); NO check-mark flourish | `setting_changed` emits with new value; `ConfigFile.save()` synchronous same-frame (CR-8). |
| **Special — DamageFlashEnabledToggle (Path 3 deep-link target)** | Same as above | Same | When pre-navigated, focus ring already on this widget at panel-mount; AccessKit announces immediately on mount (live="polite") | First commit toggles ON→OFF (default ON, opt-OUT); subsequent immediate. |
| **Special — Opt-OUT toggles (default ON)** | Same | Same | Default state shows filled checkbox; "I am ON" is the period-authentic register | Toggle to OFF = opt-OUT decision. Crosshair, Subtitles, Clock-tick, Damage flash all default ON. |

### Archetype 4: `OptionButton` (Dropdown — 4 instances)

Discrete enum selection. Resolution-scale dropdown has the special revert behaviour.

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Focus dropdown** | Tab/`↓` | D-pad `↓` | Focus ring on dropdown body | None |
| **Open dropdown** | `Space` / `Enter` / mouse click | `A` | Dropdown items list expands beneath; first item focused | None until selection |
| **Browse items** | `↑`/`↓` | D-pad `↑`/`↓` | Focus moves between items; AccessKit announces each item | None |
| **Select item** | `Enter` / mouse click | `A` | Dropdown closes; selected item visible in dropdown body | `setting_changed` emits; `ConfigFile.save()` synchronous. **EXCEPTION**: `ResolutionScaleDropdown` does NOT save synchronously — see below. |
| **Close without selecting** | `Esc` | `B` | Dropdown closes; previous selection retained | None (dropdown was open, now closed) |
| **Special — `ResolutionScaleDropdown` (CR-15 revert flow)** | Same as above | Same | (a) New value applies immediately (renderer updates — `setting_changed` emits); (b) `ConfigFile.save()` is **NOT called yet**; (c) Z4 revert banner mounts at bottom; (d) 7 s timer starts | Banner stays until: `[Keep This Resolution]` pressed (saves cfg, dismisses banner, cancels timer), `[Revert]` pressed (reverts to previous value, dismisses banner), timer elapses (saves cfg, dismisses banner — auto-confirm), or panel closed (close-as-confirm — saves cfg). |

### Archetype 5: `RebindRow` (rebind-three-state-machine — ~16 MVP)

The most complex widget archetype. Per-action capture flow with conflict resolution.

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Focus capture button** | Tab/`↓` to RebindRow's CaptureButton | D-pad `↓` | Focus ring on CaptureButton | None |
| **Begin capture** | `Enter` / `Space` / LMB on CaptureButton | `A` | (a) RebindRow shows transient inline label `"Press a key to bind. Esc to cancel."`; (b) all OTHER RebindRows render `disabled=true` with description `"Resolve current capture first"`; (c) Z2 category list disabled; (d) Z5 buttons disabled; (e) AccessKit announces "Press a key to bind" `live="polite"` | State transitions to CAPTURING; widget enters key-capture mode (keyboard input is intercepted, gamepad too). |
| **Capture key (key UP, not down)** | Press a key + RELEASE (capture fires on release per CR-19 + AC-SA-6.5) | Press a button + RELEASE | (a) On press: no commit yet; (b) on release: capture fires; check conflict | If no conflict: rebind applied, `Input.action_release(action)` called (held-key flush per `held-key-flush-after-rebind` pattern), state → NORMAL_BROWSE. If conflict: state → CONFLICT_RESOLUTION. |
| **Modifier-only capture** | Hold modifier (Shift/Ctrl/Alt/Meta) + press a key | n/a | Modifier-feedback inline label appears: `"Modifier keys ignored. Bound as: {key_label}."` (4 s persist, AccessKit `live="assertive"`) | Capture proceeds; modifiers stripped from event before binding (per CR-19 / C.5 REVISED 2026-04-27). |
| **Cancel capture** | `Esc` (`ui_cancel`) | `B` (`ui_cancel`) | Transient hint label disappears; all OTHER RebindRows re-enable | State → NORMAL_BROWSE; **does NOT close panel** (AC-SA-6.6); previous binding for this action retained. |
| **Resolve conflict — Replace** | `Tab` to `[Replace]` button + `Enter` (or LMB click) | D-pad to `[Replace]` + `A` | Conflict banner dismisses; new rebind applied; conflicting action's binding is erased | State → NORMAL_BROWSE; both affected RebindRows update their displayed bindings; `Input.action_release()` for both actions; rebind-row labels re-render. |
| **Resolve conflict — Cancel** | `Tab` to `[Cancel]` button + `Enter` OR `Esc` | D-pad to `[Cancel]` + `A` OR `B` | Conflict banner dismisses; captured event discarded; all OTHER RebindRows re-enable | State → NORMAL_BROWSE; previous binding retained. |
| **Reserved-key capture attempt** | Player tries to bind Esc / Enter / Tab / Shift+Tab to a reserved action | n/a | RebindRow's CaptureButton renders `disabled=true` from the start; cannot enter CAPTURING | Player cannot rebind reserved keys. AccessKit description: `"This binding is reserved by the game and cannot be changed."` |

### Archetype 6: `Button` — Z5 footer + per-pane

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Focus button** | Tab to button | D-pad to button | Focus ring | None |
| **Press button** | `Enter` / `Space` / LMB on button | `A` | Visual press-down state (subtle — 2 px Y-translate, NO sound per Stage Manager #2); on release, button springs back; action fires | Per-button: `[Back]` → close panel; `[Restore Defaults]` → open Restore Defaults Confirm Modal; `[Show Photosensitivity Notice]` → open Photosensitivity Review Modal; `[Keep This Resolution]` → save cfg + dismiss banner; `[Revert]` → revert + dismiss banner. |

### Archetype 7: Modal sub-surfaces

#### `RestoreDefaultsConfirmModal`

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Open** | (triggered from `[Restore Defaults]` button) | Same | Modal mounts at depth-1 from SETTINGS; Settings panel input-gated; default focus = `[Cancel]` (safer non-destructive) | InputContext.MODAL pushed |
| **Press [Restore]** | Tab to `[Restore]` + `Enter` (or LMB) | D-pad to `[Restore]` + `A` | Modal dismisses; Settings panel re-enables; per-key `setting_changed` bursts emit (consumers update live); revert banner cancels if active | `SettingsService.restore_defaults()` runs; photosensitivity safety cluster preserved per CR-25; modal dismisses. |
| **Press [Cancel] or Esc** | LMB on `[Cancel]` OR `Esc` | `A` on `[Cancel]` OR `B` | Modal dismisses; no state change | InputContext.MODAL popped; focus returns to `[Restore Defaults]` button in Z5. |
| **Mouse click outside (modal-scaffold dual-focus-dismiss)** | LMB on Settings panel area outside modal | n/a | Treated as `[Cancel]` (safer for destructive confirmation) | Per `interaction-patterns.md` `dual-focus-dismiss` Open Question recommendation: default OFF for destructive-confirm modals — but Restore Defaults is **destructive enough** that mouse-click-outside should NOT trigger Cancel by default. **Decision**: NO mouse-click-outside dismiss for this modal. (See Open Question OQ-UX-2 below.) |

#### `PhotosensitivityReviewModal` (CR-24 path)

| Action | KB+M input | Gamepad input | Immediate feedback | Outcome |
|---|---|---|---|---|
| **Open** | `[Show Photosensitivity Notice]` button pressed | Same | Modal mounts at depth-1 from SETTINGS; default focus = `[Continue]`; modal copy = identical 38-word CR-18 locked string | InputContext.MODAL pushed; `dismiss_warning()` is **NOT called** (flag stays true). |
| **Press [Continue]** | LMB on `[Continue]` OR `Enter` | `A` | Modal dismisses; Settings panel re-enables; focus returns to `[Show Photosensitivity Notice]` button (AC-SA-5.10) | InputContext.MODAL popped. Settings panel scroll position preserved. |
| **Press [Go to Settings]** | LMB on `[Go to Settings]` OR Tab + `Enter` | D-pad + `A` | Modal dismisses; **Settings panel pre-navigates** to `accessibility.damage_flash_enabled` (re-entering the same panel, scroll position resets) | Equivalent to a re-entry of Path 3 from the panel itself; ensures the player who opened the review modal can also reach the toggle. |
| **Press Esc** | `Esc` | `B` | Modal dismisses; behaviour identical to `[Continue]` | InputContext.MODAL popped; focus returns to `[Show Photosensitivity Notice]`. |

### Audio feedback summary

Per Stage Manager refusal #5 + #2, the panel **does not play UI sounds on interaction**. The only audio that occurs while the panel is open:

- **Volume slider live mix preview** — when player drags `audio.master_volume_db` etc., the audio bus changes audibly (this is the point of the slider). Other sliders are silent.
- **No hover sounds. No click sounds. No toggle sounds. No focus-change sounds.** The ADR-0004 Theme's UI-bus inventory does NOT include Settings-specific SFX.
- **No celebratory chimes or success sounds** on Restore Defaults, on rebind, on save success.

This is an intentional Stage Manager quality. Audio is reserved for the gameplay layer + the diegetic Case File register.

### Haptic feedback (gamepad)

Steam Input may apply haptic feedback during gamepad interaction at the OS layer (system-level rumble for focus changes if Steam Input config does so). The Settings panel itself does **NOT emit haptic events** — same restraint as audio. Future haptic-feedback toggle (`accessibility.haptic_feedback_enabled`, VS) gates haptic in gameplay, not in menus.

---

## Events Fired

The Settings panel is a **publisher** of two domain signals (`setting_changed`, `settings_loaded`) and **consumes** one (`ui_context_changed`). All signals are routed through the `Events` autoload per ADR-0002 sole-publisher discipline.

The project does not yet have a telemetry / analytics layer (no analytics-engineer artifacts at time of authoring). Events listed here are **gameplay-state signals**, not telemetry events.

### Per-action event mapping

| Player Action | Signal Fired | Payload | Frequency | Consumer(s) |
|---|---|---|---|---|
| Volume slider drag tick (live preview) | `Events.setting_changed` | `(category: &"audio", name: &"master_volume_db", value: -12.0)` etc. | Per `value_changed` tick during drag | Audio (live bus apply per F.1 inverse formula) |
| Volume slider release (commit) | `Events.setting_changed` | (last value) | Once on `drag_ended(value_changed=true)` | Audio (final bus apply) + ConfigFile.save() |
| Toggle CheckButton press | `Events.setting_changed` | `(category, name, value: bool)` | Once per toggle | Variable per consumer (HUD for crosshair_enabled, Combat for damage_flash_enabled, D&S for subtitles_enabled, etc.) |
| OptionButton selection (non-resolution-scale) | `Events.setting_changed` | `(category, name, value: enum/string/float)` | Once per selection | Variable per consumer |
| `ResolutionScaleDropdown` selection | `Events.setting_changed` | `(category: &"graphics", name: &"resolution_scale", value: 0.75)` | Once on selection | Outline Pipeline (apply shader uniform); cfg.save() **deferred** to Keep/Revert/timer/close-as-confirm |
| `ResolutionScaleDropdown` Keep button | (no additional signal — `setting_changed` already fired on selection) | n/a | Once | cfg.save() commits |
| `ResolutionScaleDropdown` Revert button | `Events.setting_changed` | `(category: &"graphics", name: &"resolution_scale", value: <previous>)` | Once on revert | Outline Pipeline reverts; cfg.save() commits previous value |
| `ResolutionScaleDropdown` timer auto-revert (banner expires) | (no signal — value already in memory; cfg.save() commits) | n/a | Once on timeout | cfg.save() commits |
| `ResolutionScaleDropdown` close-as-confirm (panel close while banner active) | (no additional signal) | n/a | Once on close | cfg.save() commits before panel dismiss |
| RebindRow capture commit (no conflict) | **NO `setting_changed` emission** (CR-19) | n/a | Once per rebind | InputMap updated directly via `action_erase_events` + `action_add_event`; `Input.action_release()` called; `[controls]` ConfigFile section written; AC-SA-6.4 + AC-SA-6.5 |
| RebindRow conflict Replace | NO setting_changed (per CR-19) | n/a | Once | InputMap updated for both actions; ConfigFile written |
| RebindRow conflict Cancel | NO signals | n/a | n/a | No state change |
| Capture button cancel (Esc during CAPTURING) | NO signals | n/a | n/a | State machine returns to NORMAL_BROWSE only |
| Restore Defaults Confirm `[Restore]` | `Events.setting_changed` | Per reset key (burst), each with default value | One emission per non-photosensitivity-cluster key | All consumers re-receive their settings; live re-apply |
| Restore Defaults Confirm `[Cancel]` | NO signals | n/a | n/a | Modal dismisses |
| `[Show Photosensitivity Notice]` press | NO signals (modal opens; flag NOT changed) | n/a | n/a | Review modal mounts |
| `[Back]` press / Esc at panel level | `Events.ui_context_changed(new: MENU/PAUSE, old: SETTINGS)` (auto-fired by InputContext.pop per ADR-0004) | (auto-fired by stack) | Once on close | HUD un-suppresses if returning to GAMEPLAY (via PAUSE→GAMEPLAY chain); Audio buses un-suppress |
| Panel mount (open_panel called) | `Events.ui_context_changed(new: SETTINGS, old: <caller>)` (auto-fired by InputContext.push) | (auto-fired by stack) | Once on mount | HUD suppresses, game audio buses suppress |
| Boot — first frame after Events autoload ready | `Events.settings_loaded` | (no payload — one-shot) | Exactly once per session | All Settings consumers (Audio buses re-apply, Combat damage flash gate, HUD crosshair gate, etc.). NEVER re-emitted (CR-9 + AC-SA-1.5). |

### Special — boot burst sequence

Per CR-9, on application boot:

1. `SettingsService._ready()` runs (slot 10 per ADR-0007)
2. `_load_cfg()` reads `user://settings.cfg` (or applies hardware-default on absence per CR-11)
3. `_apply_rebinds()` writes captured events back into `InputMap` BEFORE burst emit (CR-19; ensures consumers see correct InputMap state when burst fires)
4. `_emit_burst()` emits `Events.setting_changed` once per stored key
5. `Events.settings_loaded.emit()` fires **once** as the final step

The Settings **panel** is not yet mounted at this point — it mounts on demand later. The boot burst happens in the SettingsService autoload, not the panel. The panel's relationship to the burst is: when the panel mounts, all consumer state is already correct (settings already applied), so the panel just renders the in-memory values.

### Signals NOT emitted

The Settings panel **does NOT emit**:

- Telemetry / analytics events (no analytics layer at MVP; if added, this section will need amendment)
- `Events.cutscene_*`, `Events.respawn_*`, `Events.civilian_*`, `Events.guard_*`, `Events.document_*`, etc. (not Settings' domain — sole-publisher discipline per CR-1)
- `Events.audio_*` (Audio is sole publisher of audio-domain signals; Settings emits `setting_changed` only, Audio listens and acts)
- Any signal during CAPTURING state (rebind capture is fully internal — no signal-bus traffic)
- Any "panel opened" / "panel closed" signal beyond `ui_context_changed` (no need; consumers gate on InputContext, not on Settings-specific events)

### Persistent state changes

Several actions modify persistent player state (`user://settings.cfg`). Per the skill's standard, these need explicit attention from the architecture team:

| Action | Persistent state change | Architecture note |
|---|---|---|
| Any non-RebindRow setting change | `user://settings.cfg` write (per-widget commit semantics per CR-8) | Settings is sole owner of `settings.cfg` per ADR-0003; no other system writes to this file |
| RebindRow capture commit | `user://settings.cfg` `[controls]` section write | Same file, separate section, separate pathway |
| Restore Defaults | Bulk re-write of `settings.cfg` excluding photosensitivity safety cluster | Single bulk write, then per-key burst-emit |
| Photosensitivity boot-warning dismissal | `user://settings.cfg` write of `accessibility.photosensitivity_warning_dismissed = true` | Called from boot-warning, not from this panel directly |
| `[Show Photosensitivity Notice]` (CR-24 path) | **NO persistent state change** — flag stays `true`, modal is review-only | This is by design (CR-24): re-display without re-acceptance |

---

## Transitions & Animations

This panel commits to **near-zero animation** as a Pillar-5-carve-out design rule (Stage Manager refusal #6). Document the absence; the absence is the design.

### Panel enter

| Aspect | Specification |
|---|---|
| **Transition** | **Hard cut** — panel mounts on the same frame `open_panel()` is called. No fade-in. No scale-in. No translate-in. |
| **Duration** | 0 frames |
| **Audio** | Silence. No mount sound, no whoosh, no UI-bus event. The InputContext.SETTINGS push duck handler suppresses Music + Ambient + SFX buses **on the same frame** (per ADR-0004). |
| **Reduced-motion variant** | N/A — there is no animation to gate. |
| **Rationale** | Stage Manager carve-out forbids ceremony. The panel appearing instantly is part of its quiet competence. |

### Panel exit

| Aspect | Specification |
|---|---|
| **Transition** | Hard cut. Panel un-mounts on the frame `_dismiss_panel()` is called. |
| **Duration** | 0 frames |
| **Audio** | Silence. The InputContext.SETTINGS pop unducks Music + Ambient + SFX buses on the same frame. |
| **Reduced-motion variant** | N/A. |

### Detail-pane swap (Z3 content change when category selected)

| Aspect | Specification |
|---|---|
| **Transition** | Hard cut. New detail pane content renders the same frame the previous category's content un-mounts. |
| **Duration** | 0 frames (per Settings GDD §C.4 explicit decision: "Detail pane swap: zero-frame (no animation, no fade) per Stage Manager refusal #2") |
| **Audio** | Silence. |
| **Reduced-motion variant** | N/A. |

### State-change "animations"

| State change | Visual response | Animation? |
|---|---|---|
| NORMAL_BROWSE → CAPTURING | Transient hint label appears inline; CaptureButton outline shifts to highlighted; other RebindRows render `disabled=true` | **No animation** — instant property changes |
| CAPTURING → CONFLICT_RESOLUTION | Inline conflict banner renders inline within same RebindRow; warning glyph + PHANTOM Red border appear | **No animation** — instant render |
| CONFLICT_RESOLUTION → NORMAL_BROWSE | Inline banner un-renders; RebindRow displays new binding label; other RebindRows re-enable | **No animation** — instant |
| Resolution-scale change → revert banner mounts | Z4 banner appears at bottom of panel above Z5 | **No animation** on mount; the banner is rendered the same frame as the dropdown selection commits |
| Revert banner timer ticks | Body label text updates from `"…in 7s"` to `"…in 6s"` to … | **The only time-varying visual in the panel** — text update at 1 Hz (every 1.0 s of wall time). Visually, this is character substitution within an existing label, not an animation. |
| Revert banner timer expires (auto-revert OR auto-keep) | Banner un-mounts | Hard cut, instant |
| Modifier-feedback transient label | Inline label appears in RebindRow with `"Modifier keys ignored. Bound as: …"` and persists 4 s OR until next input | **No animation** on appearance; **no fade-out** on dismissal — instant un-mount when timer expires or input received. AccessKit `live="assertive"` announce IS ephemeral, but the visual handling is non-animated. |
| Disk-full inline failure label | Appears beneath affected widget, persists 4 s | **No animation** — instant appear, instant dismiss |
| Modal mount (Restore Defaults Confirm OR Photosensitivity Review) | Modal scaffold mounts at depth-1 from SETTINGS | **Hard cut** — modal-scaffold pattern in `interaction-patterns.md` does NOT specify enter/exit animations for any modal in this project (Stage Manager rule applies to all modals). |
| Modal dismiss | Modal un-mounts | Hard cut |
| Focus-ring movement (KB/gamepad navigation) | Focus indicator (4 px BQA Blue ring) moves between widgets | **No animation** — instant relocation. (Compare: many modern game UIs animate focus-ring with a tween. This panel does not.) |

### Reduced-motion (`accessibility.reduced_motion_enabled`)

This setting is **VS-only** (the toggle does not exist in MVP). Documented here for forward-looking consistency.

When the toggle ships at VS, the Settings panel itself **already complies** because it has no animations to suppress. The toggle's effect is on **other** systems (Cutscenes letterbox, F&R sepia transition, post-process slide-in, etc.).

Future-proofing: if any future Settings UX work introduces animations (e.g., a polish-phase fade-in panel mount), it MUST follow the `reduced-motion-conditional-branch` pattern:

```gdscript
if Settings.get_value(&"accessibility", &"reduced_motion_enabled"):
    _show_panel_immediately()  # hard-cut variant — vestibular-safe
else:
    _show_panel_fade_in()      # tweened variant
```

Per pattern spec, the hard-cut variant must be **vestibular-safe by design**. The current MVP panel IS the hard-cut variant; if a tweened variant ships post-MVP, this section will require amendment.

### Vestibular safety claim

Because the panel has zero animations and zero motion at MVP, **no vestibular safety audit is required** for the panel itself. (Vestibular audits ARE required for the systems Settings consumes — Cutscenes letterbox, F&R sepia transition, post-process — those audits are owned by their respective UX specs.)

### Photosensitivity safety claim

Because the panel has zero flash, zero rapid colour change, and zero strobe, **no photosensitivity audit is required** for the panel itself. The PHANTOM Red colour used in the conflict banner does NOT flash; it is a static border. This is consistent with the panel's role as the photosensitivity *safe haven* — the place a photosensitive player goes to lock down flashing risk. The panel itself contains no risk.

---

## Data Requirements

The Settings panel is **the canonical UI surface for ALL configurable player state**. Cross-references: Settings GDD §G.1–G.6 (canonical key inventory), ADR-0002 §Decision (signal-bus contract), ADR-0003 §SaveGame schema (settings persistence boundary), Input GDD §C (action registry).

### Data ownership table

| Data | Source System | Read / Write | Real-time? | Notes |
|---|---|---|---|---|
| 6 audio bus volume keys (`audio.master_volume_db`, `music_volume_db`, `sfx_volume_db`, `ambient_volume_db`, `voice_volume_db`, `ui_volume_db`) | SettingsService (sole owner per CR-2) | Read on widget mount; Write per slider commit | Yes — slider drag emits `setting_changed` per-tick (consumers preview live); cfg.save() once on drag_ended |
| `graphics.resolution_scale` | SettingsService (key) + Outline Pipeline (consumer) | Read on mount; Write per dropdown selection (cfg.save deferred per CR-15) | Yes — value applies on selection; cfg.save() deferred to revert/keep/timer/close-as-confirm |
| 12 accessibility keys (photosensitivity cluster, visual+audio, subtitles MVP-write/VS-consume) | SettingsService | Read on mount; Write per widget commit | Yes — `setting_changed` per commit |
| `accessibility.photosensitivity_warning_dismissed` | SettingsService | Read on mount (gates `[Show Photosensitivity Notice]` button visibility — no, actually always visible — gates whether boot-warning fires next launch); Write via `dismiss_warning()` from boot-warning context, NOT from this panel | No — flag-only |
| `accessibility.subtitle_*` keys (size/background/spacing/letter-spacing) | SettingsService writes (MVP); Dialogue & Subtitles consumes (VS) | Read on mount (display current value in widget); Write per widget commit | MVP-write only — D&S applies the values when D&S ships at VS |
| 4 controls toggle keys (`controls.sprint_is_toggle`, `crouch_is_toggle`, `ads_is_toggle`, `invert_y_axis`) | SettingsService | Read on mount; Write per toggle | Yes — per `setting_changed` |
| 3 controls sensitivity keys (`controls.mouse_sensitivity_x`, `_y`, `gamepad_look_sensitivity`) | SettingsService writes; Player Character consumes | Read on mount; Write per slider | Yes |
| `[controls]` ConfigFile section (rebinds — InputEvent serialised) | SettingsService is sole writer; `InputMap` is the runtime state | Read on mount (reflect current InputMap); Write per RebindRow capture commit (CR-19 separate pathway, NOT via `setting_changed`) | Yes — InputMap updates immediately on commit |
| `language.locale` | SettingsService writes; TranslationServer consumes | Read on mount (display current locale); Write on dropdown selection (VS only) | Yes — locale change is immediate-apply per CR-12 |
| `_boot_warning_pending: bool` (SettingsService internal state) | SettingsService | Read by Menu System (NOT by this panel); Reset by `dismiss_warning()` | n/a — not displayed in panel |
| Hardware capability — `OutlinePipeline.get_hardware_default_resolution_scale()` | Outline Pipeline (per CR-11 — provides API per OQ-SA-1) | Read once on first-launch (no cfg present) to set initial `graphics.resolution_scale` | One-shot at first-launch |
| `Events.settings_loaded` signal one-shot | Events autoload | Listen at consumer boot; never emitted again per session | No real-time component beyond boot |
| `Events.setting_changed` signal | Events autoload (Settings is sole publisher per CR-1) | Subscribe per consumer (filter-first per CR-5) | Yes — per setting commit |
| `Events.ui_context_changed` signal | InputContextStack autoload (auto-emitted on push/pop per ADR-0002 + ADR-0004) | Listen at consumer boot | Yes — per panel mount/dismiss |

### Read-on-mount sequence

When the panel mounts (`open_panel()` is called), the panel populates widget state by reading current values from `SettingsService` via:

1. For each widget: read in-memory value (NOT cfg file — cfg is loaded once at boot via CR-9; in-memory cache is authoritative during runtime).
2. For RebindRows: read current `InputMap.action_get_events(action)` for each action; display as key-label string via `tr("INPUT_ACTION_NAME_<ACTION>")` (per OQ-SA-11 REVISED). Note: action display uses Input GDD's tr-key map, NOT `OS.get_keycode_string()` (which is OS-locale-dependent and would break the localisation contract).
3. For category list: render all 6 categories with current values' impact summarised in any per-row sub-label (NO sub-labels at MVP — per Stage Manager refusal, no "summary line" beneath each category like "Audio (75% music volume)"; just the category name).

**Read pattern**: the panel does NOT call `SettingsService.get_value()` synchronously at panel mount — that would risk a load-order race per CR-6 / FP-3 (Consumer Default Strategy). Instead, the panel either: (a) reads its widget's setting key from in-memory state (panel is mounted post-boot, so values exist), OR (b) sets up its own widget defaults from `settings_defaults.gd` and waits for the first `setting_changed` to update display. Pattern (a) is correct for the panel — it is NOT a consumer with a `_ready()` race; it is mounted on-demand and `settings_loaded` has fired by then.

### Write-back semantics (consolidated)

Per CR-8 widget-aware commit semantics:

| Widget archetype | Commit trigger | Disk write timing |
|---|---|---|
| HSlider | `drag_ended(value_changed=true)` OR keyboard step release OR mouse-click track | Once per drag/step sequence |
| CheckButton | `toggled` | Synchronous same frame |
| OptionButton (non-resolution-scale) | `item_selected` | Synchronous same frame |
| OptionButton (resolution-scale) | `item_selected` (preview) → Keep / Revert / timer / close-as-confirm (commit) | Deferred 7 s (or until explicit confirm) |
| RebindRow | CAPTURING → NORMAL_BROWSE transition (post-conflict-resolution if needed) | Synchronous same frame; written to `[controls]` section, NOT via `setting_changed` |
| Restore Defaults | `[Restore]` button in confirmation modal | Single bulk write of all non-photosensitivity-cluster keys |

### Settings persistence boundary

Per ADR-0003 + Settings CR-2: `user://settings.cfg` is **not** part of the SaveGame contract. Settings persist independently of save slots. A New Game / Save Wipe action does NOT clear settings (AC-SA-2.7). A player who configures their game once retains that configuration across all future playthroughs.

### Forward-dependency risk

The panel reads the following data that **other systems must produce**:

| Data | Producer | Status | Risk if missing |
|---|---|---|---|
| Hardware-default resolution scale | Outline Pipeline `get_hardware_default_resolution_scale()` | OQ-SA-1 BLOCKING | Without this API, Settings cannot honour CR-11; would fall back to 1.0 default for all hardware (risks sub-30 FPS on weak GPUs at first launch — bad UX for low-end users) |
| Action display name tr-keys (`INPUT_ACTION_NAME_<ACTION>` family) | Input GDD's localisation registry | OQ-SA-11 BLOCKING | Without these tr-keys, RebindRow conflict banner would show raw action IDs (`"action_fire"`) instead of localised labels — breaks i18n + readability |
| Modal scaffold node tree | Menu System (via `ModalScaffold` provided per CR-18) | OQ-SA-3 (CLOSES with Menu CR-8) | Without scaffold, Restore Defaults Confirm + Photosensitivity Review modals have no mount surface |
| ADR-0002 amendment for `settings_loaded` signal + `settings` domain | Producer (already landed 2026-04-28) | RESOLVED | n/a |
| ADR-0004 verification gates (accessibility_* property names + Theme `base_theme`/`fallback_theme`) | godot-specialist (5-min editor check) | OQ-SA-4 BLOCKING | Without verification, AccessKit per-widget contract may have invalid property names |

---

## Accessibility

> **OQ-SA-12 deliverable**: this section is the canonical per-widget AccessKit contract for the entire Settings panel. Section length is intentional. Implementation MUST conform to this table; deviations require a documented exception.

### Tier commitment

This panel **fully delivers Standard tier** per `design/accessibility-requirements.md`. Settings is the **load-bearing** screen for project-wide accessibility commitments — every Standard-tier feature has its player-visible affordance here. Any setting that goes missing from this panel is a tier regression.

This panel also delivers **partial Comprehensive tier** for menu screen-reader support (per AccessKit per-widget table on every widget) — Comprehensive in-world screen-reader is out of project scope per `accessibility-requirements.md` Known Intentional Limitations.

### Keyboard navigation map (KB+M MVP)

The panel is **fully keyboard-traversable**. Every interactive widget has a focus state; focus order is deterministic.

```
Panel mount (focus arrives at):
  if pre_navigate set: → focus first matching widget in detail pane
  elif last_visited_category exists (within session): → focus first widget in that category's detail pane
  else: → focus first row of Z2 (Audio category)

Top-level focus chain (when no modal open, no banner active):
  [Z2 Category List, current row]
    ↓/Tab  → next category row (wraps within Z2)
    →/Tab→ next column → first widget of detail pane
  [Z3 Detail Pane, first widget]
    ↓/Tab  → next widget (no wrap; dead-end announce on overflow)
    ←      → back to Z2 selected category row
    Tab    → cycles within detail pane only (does not cross to Z2 per AC-SA-11.7)
  [Z3 Detail Pane, last widget]
    ↓      → no movement; AccessKit polite announce: "End of section"
  [Z3 Detail Pane, first widget]
    ↑      → no movement; AccessKit polite announce: "Start of section"
  Z5 reached via post-detail-pane focus chain (not via Tab from detail pane)
  [Z5 Footer, [Restore Defaults]]
    Tab    → [Z5 Footer, [Back]]
    Shift+Tab → back to [Restore Defaults]

When Z4 banner active:
  Insert into focus chain between Z3 and Z5:
  [Z4 Banner, [Keep This Resolution]] ⇄ [[Revert]]

When CAPTURING:
  Focus locked to RebindRow's CaptureButton; Esc cancels capture (returns to NORMAL_BROWSE), focus stays at CaptureButton

When CONFLICT_RESOLUTION:
  Focus locked to inline conflict banner's [Replace] button (default focus); Tab cycles between [Replace] and [Cancel]; Esc treats as [Cancel]

When modal open (Restore Defaults Confirm / Photosensitivity Review):
  Focus trap: focus cycles only within modal; default focus on safer/non-destructive button
  Esc dismisses modal; focus returns to caller button
```

### Gamepad navigation map (Partial — full menu nav, post-MVP rebinding parity)

Identical semantics to KB+M with input substitutions:

| KB+M action | Gamepad equivalent |
|---|---|
| `↑` / `↓` (`ui_up`/`ui_down`) | D-pad `↑/↓` OR Left stick `↑/↓` |
| `←` / `→` (`ui_left`/`ui_right`) | D-pad `←/→` OR Left stick `←/→` |
| `Enter` / `Space` (`ui_accept`) | `A` |
| `Esc` (`ui_cancel`) | `B` |
| `Tab` | (n/a — gamepad uses focus-chain `↓` + `↑` only) |
| Slider drag | Left stick analog (deadzone-respecting) |
| RebindRow capture | n/a at MVP — gamepad rebinding parity is post-MVP per OQ-SA-5 |

**Gamepad-specific dead-ends**: Gamepad players cannot rebind controls at MVP (see OQ-SA-5). The Controls category renders the Rebind cluster as **disabled with a footnote** when input method = gamepad: `"Gamepad rebinding requires keyboard. Coming in a future update."` (post-MVP). This footnote is itself accessible (AccessKit description).

### Per-widget AccessKit contract (OQ-SA-12 deliverable)

Per ADR-0004 §IG7 + Godot 4.6 AccessKit API. Every interactive widget exposes:

- `accessibility_role` — semantic role (slider / checkbox / button / dialog / etc.)
- `accessibility_name` — short label (resolves through `tr()`)
- `accessibility_description` — longer description (resolves through `tr()`)
- `accessibility_live` — live-region hint for state changes (`live="off"` / `"polite"` / `"assertive"`)
- `accessibility_value` — for sliders, the current value text (re-resolved on `value_changed`)
- `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` — every Label per `auto-translate-always` pattern
- `_notification(NOTIFICATION_TRANSLATION_CHANGED)` handler — re-resolves accessibility_name / accessibility_description when locale changes per `accessibility-name-re-resolve` pattern

**Standard widget rules** apply unless overridden per-widget below:
- Focus-ring: 4 px BQA Blue `#1B3A6B` outset ring; 200 ms persistence (no animation, instant on focus change)
- AccessKit announces `accessibility_name` on focus + `accessibility_description` on focus + `accessibility_value` for sliders
- Tab order matches visual top-to-bottom-left-to-right reading order

#### Z1 Header

| Widget | Role | name (tr-key) | description (tr-key) | live | Notes |
|---|---|---|---|---|---|
| `HeaderTitle` | `ROLE_HEADING` (level 1) | `SETTINGS_HEADER_TITLE` → "Settings" | (none) | `off` | Anchor point for screen reader entering panel |

#### Z2 CategoryList

| Widget | Role | name (tr-key) | description (tr-key) | live | Notes |
|---|---|---|---|---|---|
| `CategoryList` (ItemList container) | `ROLE_LIST_BOX` | `SETTINGS_CATEGORIES_NAME` → "Settings categories" | `SETTINGS_CATEGORIES_DESC` → "Choose a category to configure." | `off` | Container-level role |
| Each row (6 rows) | `ROLE_LIST_BOX_OPTION` | `SETTINGS_CATEGORY_AUDIO` / `_GRAPHICS` / `_ACCESSIBILITY` / `_HUD` / `_CONTROLS` / `_LANGUAGE` | (none — name is sufficient) | `off` | AccessKit auto-announces `"{name}, {n} of 6"` |

#### Z3 Detail pane — common widget archetypes

| Archetype | Role | name source | description source | live | Special handling |
|---|---|---|---|---|---|
| HSlider (volume / sensitivity / cooldown / etc.) | `ROLE_SLIDER` | `tr("SETTINGS_<KEY>_NAME")` (per setting) | `tr("SETTINGS_<KEY>_DESC")` | `off` | `accessibility_value = "{value} {unit}"` — re-resolves on `value_changed`; e.g., `"-12 dB"`, `"75%"`, `"333 ms"`, `"1.5×"`. Floor/ceiling enforced (e.g., DamageFlashCooldownSlider clamped at 333 ms). |
| CheckButton (toggle) | `ROLE_CHECK_BOX` | `tr("SETTINGS_<KEY>_NAME")` | `tr("SETTINGS_<KEY>_DESC")` | `off` | AccessKit auto-announces toggled state (`"checked"`/`"unchecked"`). |
| OptionButton (dropdown) | `ROLE_COMBO_BOX` | `tr("SETTINGS_<KEY>_NAME")` | `tr("SETTINGS_<KEY>_DESC")` | `off` | Each item announced via `accessibility_name` per `tr("SETTINGS_<KEY>_OPTION_<VALUE>")`. |
| Sub-header Label | `ROLE_HEADING` (level 2) | `tr("SETTINGS_<CATEGORY>_SUBHEADER_<NAME>")` | (none) | `off` | Decorative + AccessKit anchor for screen reader to recognise group structure |
| Section button (e.g., `[Show Photosensitivity Notice]`) | `ROLE_BUTTON` | `tr("SETTINGS_REVIEW_PHOTOSENSITIVITY_NOTICE")` | `tr("SETTINGS_REVIEW_PHOTOSENSITIVITY_NOTICE_DESC")` → "Open the photosensitivity warning to review the safety information." | `off` | Standard button |
| RebindRow CaptureButton | `ROLE_BUTTON` | `tr("INPUT_ACTION_NAME_<ACTION>")` (e.g., "Move Forward") | `tr("SETTINGS_REBIND_CAPTUREBUTTON_DESC")` → "Currently bound to {key_label}. Press to rebind." | `off` | Description re-resolves when binding changes; `{key_label}` resolved via `tr("INPUT_ACTION_NAME_<ACTION>")` per OQ-SA-11 |
| RebindRow capture-hint label (transient) | `ROLE_LIVE_REGION` | `SETTINGS_CAPTURE_HINT` → "Press a key to bind. Esc to cancel." | (none) | `polite` | Appears only during CAPTURING |
| RebindRow modifier-feedback label (transient) | `ROLE_LIVE_REGION` | `SETTINGS_MODIFIERS_DROPPED` → "Modifier keys ignored. Bound as: {key_label}." | (none) | `assertive` | Persists 4 s OR until next input. `live=assertive` because it overrides intent — must announce |
| RebindRow conflict banner | `ROLE_ALERT` | `SETTINGS_REBIND_CONFLICT_BANNER` → "Conflict: {action_label} is already bound to this key." | (none) | `assertive` | The `{action_label}` is the conflicting action. The banner must announce on appearance to interrupt screen-reader queue |
| RebindRow conflict `[Replace]` button | `ROLE_BUTTON` | `SETTINGS_REBIND_REPLACE` → "Replace" | `SETTINGS_REBIND_REPLACE_DESC` → "Erase the conflicting binding and apply the new one." | `off` | |
| RebindRow conflict `[Cancel]` button | `ROLE_BUTTON` | `SETTINGS_REBIND_CANCEL` → "Cancel" | `SETTINGS_REBIND_CANCEL_DESC` → "Discard the new binding and keep the previous one." | `off` | |
| RebindRow disabled (reserved) | `ROLE_BUTTON` (`disabled = true`) | `tr("INPUT_ACTION_NAME_<ACTION>")` | `SETTINGS_REBIND_RESERVED_DESC` → "This binding is reserved by the game and cannot be changed." | `off` | Greyed visual + AccessKit description signals non-rebindability |

#### Z4 Revert banner

| Widget | Role | name (tr-key) | description (tr-key) | live | Notes |
|---|---|---|---|---|---|
| `RevertBanner` (container) | `ROLE_ALERT` | `SETTINGS_RESOLUTION_REVERT_PROMPT` (interpolated with `{value_pct}` and `{N}`) | `SETTINGS_RESOLUTION_REVERT_DISCLOSURE` → "Closing this panel will keep the new resolution." | `assertive` ON MOUNT only; `polite` for countdown ticks (does not announce every second) | Mounts on selection; assertive announce once on mount; subsequent countdown updates do NOT re-announce (would be screen-reader spam). Auto-revert at 0 s announces `live="polite"`. |
| `KeepResolutionButton` | `ROLE_BUTTON` | `SETTINGS_RESOLUTION_KEEP` → "Keep This Resolution" | `SETTINGS_RESOLUTION_KEEP_DESC` → "Confirm the new resolution and close this banner." | `off` | |
| `RevertResolutionButton` | `ROLE_BUTTON` | `SETTINGS_RESOLUTION_REVERT` → "Revert" | `SETTINGS_RESOLUTION_REVERT_DESC` → "Restore the previous resolution and close this banner." | `off` | |

#### Z5 Footer

| Widget | Role | name (tr-key) | description (tr-key) | live | Notes |
|---|---|---|---|---|---|
| `RestoreDefaultsButton` | `ROLE_BUTTON` | `SETTINGS_RESTORE_DEFAULTS` → "Restore Defaults" | `SETTINGS_RESTORE_DEFAULTS_DESC` → "Reset every setting to its default. Photosensitivity preferences will be preserved." | `off` | |
| `BackButton` | `ROLE_BUTTON` | `SETTINGS_BACK` → "Back" | `SETTINGS_BACK_DESC` → "Close Settings and return." | `off` | |

#### Modal sub-surfaces

| Modal | Role | name (tr-key) | description (tr-key) | live | Notes |
|---|---|---|---|---|---|
| `RestoreDefaultsConfirmModal` | `ROLE_DIALOG` | `SETTINGS_RESTORE_DEFAULTS_CONFIRM_TITLE` → "Confirm restore defaults" | `SETTINGS_RESTORE_DEFAULTS_CONFIRM` → "Restore all settings to defaults? Your photosensitivity preferences will be preserved." | `assertive` | Default focus = `[Cancel]` |
| `[Restore]` button | `ROLE_BUTTON` | `SETTINGS_RESTORE_DEFAULTS_CONFIRM_RESTORE` → "Restore" | (none) | `off` | |
| `[Cancel]` button | `ROLE_BUTTON` | `SETTINGS_RESTORE_DEFAULTS_CONFIRM_CANCEL` → "Cancel" | (none) | `off` | Default focus |
| `PhotosensitivityReviewModal` | `ROLE_DIALOG` | `SETTINGS_PHOTOSENSITIVITY_REVIEW_TITLE` → "Photosensitivity warning" | `SETTINGS_PHOTOSENSITIVITY_WARNING_BODY` (CR-18 38-word locked) | `assertive` | Default focus = `[Continue]` |
| Modal `[Continue]` | `ROLE_BUTTON` | `menu.main.continue` → "Continue" (shared with Main Menu) | (none) | `off` | |
| Modal `[Go to Settings]` | `ROLE_BUTTON` | `menu.photo_warning.go_to_settings` → "Go to Settings" | (none) | `off` | |

### Dead-end announcements (AC-SA-11.8)

When a player tries to navigate beyond the focus chain's bounds in the detail pane, AccessKit announces:

| Direction | tr-key | Locked text (English) | live |
|---|---|---|---|
| `ui_down` at last widget in detail pane | `SETTINGS_NAV_DEAD_END_BOTTOM` | "End of section" | `polite` |
| `ui_up` at first widget in detail pane | `SETTINGS_NAV_DEAD_END_TOP` | "Start of section" | `polite` |

These announcements are **non-disruptive** (`polite` not `assertive`) — the screen reader queues them. Players using KB only get a "no movement" silent dead-end with audio confirmation; visual focus ring stays put.

### Color-independence audit

Per `design/accessibility-requirements.md` Per-Feature Matrix, no signal in this panel is communicated by colour alone.

| Element | Colour signal | Non-colour backup | Status |
|---|---|---|---|
| Focus ring (BQA Blue 4 px) | Blue | Width is the primary signal — 4 px ring is large enough to register without colour. AccessKit live-region also speaks the focused widget. | Triple-encoded |
| Selected category in Z2 | Parchment fill behind selected row | Selection-state visual (filled vs. unfilled cell) + AccessKit `ROLE_LIST_BOX_OPTION` selected state announcement | Triple-encoded |
| Conflict banner (PHANTOM Red border) | Red | Triangle warning glyph (U+26A0, icon-font) + body text "Conflict: …" + AccessKit `ROLE_ALERT` assertive announce + disabled state on other RebindRows | **Quadruple-encoded** |
| Modal default-focus button | BQA Blue fill on default | Focus ring + AccessKit announce | Triple-encoded |
| Disabled / reserved RebindRow | Grey-tinted text | `disabled = true` (mouse cursor changes) + AccessKit description `"This binding is reserved by the game and cannot be changed."` | Triple-encoded |
| Resolution-scale revert banner (Parchment + buttons) | Background fill | Body text describes the action; assertive announce on mount; countdown is text not colour | Triple-encoded |

**No** signal in this panel is colour-only. The PHANTOM Red border on the conflict banner is the most colour-leaning signal and is quadruple-encoded.

### Text scaling (per `accessibility.ui_scale` — VS)

At MVP, `ui_scale` is fixed at 100% (the slider exists in Settings GDD G.3 but is rendered VS). All MVP layouts use 1080p reference sizes:

- Header `28 px` → 200% scale = 56 px (well above all WCAG floors)
- Category-list rows `20 px` → 200% scale = 40 px (well above WCAG SC 1.4.4)
- Detail pane labels `16 px` → 200% scale = 32 px (above WCAG SC 1.4.4 18 px floor for body)
- Slider value labels `14 px` → 200% scale = 28 px

When the `ui_scale` slider ships at VS, **the panel must reflow** without text overflow at 150% scale. Settings UX may need to grow Z3's width or convert single-line labels to two-line. Tested at VS sprint kickoff per AC-VS.

### Subtitles + reading-pace

This panel does not display subtitles (no spoken dialogue). However, transient text labels (modifier feedback, dead-end announces, disk-full failure) must respect reading-pace floors:

- Modifier feedback persists **4 s** per CR `SETTINGS_MODIFIERS_DROPPED` — sufficient for slow readers per `accessibility-requirements.md` reading-speed floor (90 cpm)
- Disk-full feedback persists **4 s** — same rationale
- Dead-end announces are non-blocking screen-reader queues; visual focus ring stays put indefinitely

### Standard tier checklist

| Standard tier requirement (from `accessibility-requirements.md`) | Met by this panel | Implementation |
|---|---|---|
| Full input remapping (KB+M MVP, gamepad post-MVP) | Yes | Controls category renders 16+ RebindRows MVP; gamepad column reserved VS |
| Subtitles default ON with speaker labels | Yes (UI surface) | Subtitle cluster in Accessibility category; `subtitles_enabled` opt-OUT default ON |
| Adjustable text size | Partial (UI surface present, application VS) | `subtitle_size_scale` rendered MVP; `ui_scale` rendered VS |
| ≥1 colorblind mode | VS — UI surface deferred to VS | `colorblind_mode` dropdown in Accessibility VS cluster |
| Toggle-Sprint / Crouch / ADS | Yes | Controls category, 3 toggles MVP |
| Photosensitivity opt-out | Yes | Damage flash toggle + cooldown slider + Show Photosensitivity Notice button MVP |
| Aim assist sliders | VS — UI surface deferred | Aim assist sliders rendered VS in Accessibility category |
| Independent volume sliders | Yes | 6 audio bus sliders MVP |
| Reduced motion | VS — UI surface deferred | `reduced_motion_enabled` toggle rendered VS |
| Screen reader (menu) | Yes | AccessKit per-widget contract (this section) |
| No timed inputs in gameplay | N/A — gameplay design | Settings panel itself has 7 s revert banner (the only timed input); revert is **non-destructive timeout** (auto-confirm, not auto-revert per CR-15 close-as-confirm) |

### Open accessibility questions

(Detailed in §Open Questions — quick summary here for cross-reference: focus-ring spec verification, gamepad rebinding parity timeline, dual-focus-dismiss policy on Restore Defaults Confirm modal.)

---

## Localization Considerations

This panel ships **English-only at MVP** with a full tr-key infrastructure ready for VS-locale addition (CR-13: Language dropdown hidden until 2nd locale ships; the `LANGUAGE_MVP_NOTICE` label communicates this state).

### Locked tr-keys (inherited from Settings GDD)

Per Settings GDD §G — already locked, do not re-debate:

| tr-key | Locked English text | Owner | Length budget |
|---|---|---|---|
| `SETTINGS_HEADER_TITLE` | "Settings" | Settings | 12 chars (header) |
| `SETTINGS_CATEGORY_AUDIO` | "Audio" | Settings (or Menu, if split) | 16 chars (left column 480 px) |
| `SETTINGS_CATEGORY_GRAPHICS` | "Graphics" | Settings | 16 chars |
| `SETTINGS_CATEGORY_ACCESSIBILITY` | "Accessibility" | Settings | 18 chars (note: longer in DE: "Barrierefreiheit" = 16 chars; FR: "Accessibilité" = 13 chars; both fit) |
| `SETTINGS_CATEGORY_HUD` | "HUD" | Settings | 16 chars |
| `SETTINGS_CATEGORY_CONTROLS` | "Controls" | Settings | 16 chars |
| `SETTINGS_CATEGORY_LANGUAGE` | "Language" | Settings | 16 chars |
| `SETTINGS_PHOTOSENSITIVITY_WARNING_BODY` | (CR-18 38-word locked text — see `photosensitivity-boot-warning.md`) | Settings CR-18 | 300 char ceiling |
| `menu.main.continue` / `menu.main.continue_empty` | "Continue" / "Begin Operation" | Menu System CR-5 | 14 chars |
| `menu.photo_warning.go_to_settings` | "Go to Settings" | Menu System | 14 chars |
| `SETTINGS_REVIEW_PHOTOSENSITIVITY_NOTICE` | "Show Photosensitivity Notice" | Settings CR-24 | 32 chars (button label, longer than typical) |
| `SETTINGS_RESTORE_DEFAULTS_CONFIRM` | "Restore all settings to defaults? Your photosensitivity preferences will be preserved." | Settings CR-25 | 120 chars |
| `SETTINGS_RESOLUTION_REVERT_PROMPT` | "Resolution scale changed to {value_pct}. Confirm or revert in {N} seconds." | Settings CR-15 | 100 chars + interpolated values |
| `SETTINGS_CAPTURE_HINT` | "Press a key to bind. Esc to cancel." | Settings C.5 | 40 chars |
| `SETTINGS_MODIFIERS_DROPPED` | "Modifier keys ignored. Bound as: {key_label}." | Settings C.5 (REVISED 2026-04-27) | 60 chars |
| `SETTINGS_NAV_DEAD_END_BOTTOM` | "End of section" | Settings C.4 (NEW 2026-04-27) | 24 chars |
| `SETTINGS_NAV_DEAD_END_TOP` | "Start of section" | Settings C.4 (NEW 2026-04-27) | 24 chars |
| `LANGUAGE_MVP_NOTICE` | "English (additional languages coming in a future update)" | Settings CR-13 | 80 chars |
| `INPUT_ACTION_NAME_<ACTION>` (family) | per Input GDD registry — e.g., "Move Forward", "Sprint", "Crouch", "Fire", "Reload", etc. | Input GDD | 24 chars per action |

### Tr-keys introduced by this UX spec

Per OQ-SA-12 (this spec is the deliverable for the per-widget contract), these tr-keys are introduced here and need registration in the central localisation catalog:

| tr-key | Locked English text | Length budget | Notes |
|---|---|---|---|
| **Per-widget AccessKit names + descriptions** (~60 widgets) | varies | 60 chars name / 120 chars description | Pattern: `SETTINGS_<KEY>_NAME` and `SETTINGS_<KEY>_DESC`. e.g., `SETTINGS_AUDIO_MASTER_VOLUME_DB_NAME` → "Master Volume", `SETTINGS_AUDIO_MASTER_VOLUME_DB_DESC` → "Adjust the overall game volume." Full list in code. |
| `SETTINGS_CATEGORIES_NAME` | "Settings categories" | 30 chars | Z2 ItemList container |
| `SETTINGS_CATEGORIES_DESC` | "Choose a category to configure." | 60 chars | Z2 ItemList container |
| `SETTINGS_REBIND_REPLACE` | "Replace" | 14 chars | Conflict banner button |
| `SETTINGS_REBIND_REPLACE_DESC` | "Erase the conflicting binding and apply the new one." | 80 chars | |
| `SETTINGS_REBIND_CANCEL` | "Cancel" | 14 chars | |
| `SETTINGS_REBIND_CANCEL_DESC` | "Discard the new binding and keep the previous one." | 80 chars | |
| `SETTINGS_REBIND_RESERVED` | "System reserved." | 24 chars | Footnote on disabled RebindRows |
| `SETTINGS_REBIND_RESERVED_DESC` | "This binding is reserved by the game and cannot be changed." | 80 chars | AccessKit description |
| `SETTINGS_REBIND_CAPTUREBUTTON_DESC` | "Currently bound to {key_label}. Press to rebind." | 80 chars + interpolation | RebindRow CaptureButton AccessKit description; re-resolves on rebind |
| `SETTINGS_REBIND_CONFLICT_BANNER` | "Conflict: {action_label} is already bound to this key." | 80 chars + interpolation | Conflict banner body (assertive announce) |
| `SETTINGS_REBIND_GAMEPAD_DEFERRED` | "Gamepad rebinding requires keyboard. Coming in a future update." | 100 chars | Footnote when input method = gamepad MVP |
| `SETTINGS_RESOLUTION_REVERT_DISCLOSURE` | "Closing this panel will keep the new resolution." | 60 chars | Banner sub-disclosure |
| `SETTINGS_RESOLUTION_KEEP` | "Keep This Resolution" | 24 chars | Banner button |
| `SETTINGS_RESOLUTION_KEEP_DESC` | "Confirm the new resolution and close this banner." | 80 chars | |
| `SETTINGS_RESOLUTION_REVERT` | "Revert" | 14 chars | Banner button |
| `SETTINGS_RESOLUTION_REVERT_DESC` | "Restore the previous resolution and close this banner." | 80 chars | |
| `SETTINGS_RESTORE_DEFAULTS` | "Restore Defaults" | 24 chars | Z5 footer button |
| `SETTINGS_RESTORE_DEFAULTS_DESC` | "Reset every setting to its default. Photosensitivity preferences will be preserved." | 120 chars | Z5 button AccessKit description |
| `SETTINGS_RESTORE_DEFAULTS_CONFIRM_TITLE` | "Confirm restore defaults" | 40 chars | Modal dialog title |
| `SETTINGS_RESTORE_DEFAULTS_CONFIRM_RESTORE` | "Restore" | 14 chars | Modal button |
| `SETTINGS_RESTORE_DEFAULTS_CONFIRM_CANCEL` | "Cancel" | 14 chars | Modal button (default focus) |
| `SETTINGS_PHOTOSENSITIVITY_REVIEW_TITLE` | "Photosensitivity warning" | 40 chars | Review modal title |
| `SETTINGS_BACK` | "Back" | 14 chars | Z5 footer button |
| `SETTINGS_BACK_DESC` | "Close Settings and return." | 60 chars | |
| `SETTINGS_HUD_CROSSHAIR_REDIRECT` | "Crosshair settings live in Accessibility → Visual & Audio." + `[Go to Accessibility]` | 80 chars | HUD category MVP body label |
| `SETTINGS_WRITE_FAILED` | "Could not save. Check disk space." | 50 chars | Disk-full inline transient feedback |
| `SETTINGS_<CATEGORY>_SUBHEADER_<NAME>` family | e.g., `SETTINGS_ACCESSIBILITY_SUBHEADER_PHOTOSENSITIVITY` → "Photosensitivity" | 24 chars | Sub-header labels per category |
| `SETTINGS_<KEY>_OPTION_<VALUE>` family | e.g., `SETTINGS_GRAPHICS_RESOLUTION_SCALE_OPTION_75` → "75%" | 24 chars | Dropdown option labels |

**Total tr-keys touched by this panel**: ~100 (counting per-widget name/desc pairs, options, sub-headers, and atomic strings).

### Length budget commitments

The most length-constrained elements are **button labels** (must fit on a single line within button width) and **stamp-band labels** (n/a — Settings is non-diegetic, no stamp bands).

| Element | Budget | Reason |
|---|---|---|
| Button label (footer + modal + banner) | 14 chars | 280 px wide button hit-target × 16 px font × ~17 char fit |
| Sub-header (detail pane) | 24 chars | Sub-header is left-aligned inside detail pane, no wrap |
| Setting label (detail pane label-left side) | 30 chars | 40% of Z3 width = 576 px; at 16 px font = 30 chars + 2-line fallback |
| Slider value label | 8 chars | "+" + "−" + 3 digits + 2-char unit (e.g., `"-12 dB"`, `"100 ms"`) |
| Modal body | 120 chars | Modal is 880 × 280 px; body wraps |
| Photosensitivity body | 300 chars (CR-18 ceiling) | Already locked at 38 English words ≈ 250 chars |
| Sub-disclosure (banner) | 60 chars | Smaller font, tighter constraint |
| Capture hint | 40 chars | Single-line transient |
| Modifier feedback | 60 chars + interpolation | Two-line OK (assertive announce reads either way) |

### Locale-specific risks

| Locale | Risk | Mitigation |
|---|---|---|
| **DE (German)** | Compound words expand text length 30-40%; "Barrierefreiheit" for "Accessibility", "Tastenbelegung" for "Key bindings", "Wiedereinstellen" for "Restore" | Z2 ItemList row width 480 px (vs ~190 px text width @ 20 px font); long labels wrap at 2 lines OR truncate with ellipsis (decision deferred to first DE translation pass — see Open Question OQ-UX-LOC-1) |
| **FR (French)** | Common verb-noun forms expand text length ~25%; "Restaurer les paramètres par défaut" for "Restore Defaults" (33 chars vs 16 EN) | Footer button width 280 px; FR text at 18 px font ≈ 28 chars fit; "Restaurer" alone (9 chars) acceptable shortened form. Length-critical buttons must use shortened forms. |
| **ES (Spanish)** | Similar expansion to FR | Same mitigation |
| **JA (Japanese)** | Different writing direction (LTR but vertical-friendly fonts); requires separate font validation | Out of MVP scope; flagged for VS locale-add evaluation |
| **AR (Arabic) / HE (Hebrew)** | RTL writing direction; mirroring of all directional UI elements (focus-chain, slider direction, button order) | Out of MVP/VS scope; post-launch evaluation per `interaction-patterns.md` Open Question #6 |

### Locale-change immediate-apply (CR-12)

When the player changes `language.locale` (VS only):

1. `SettingsService` calls `TranslationServer.set_locale(new_locale)`
2. Every `tr()` resolution re-resolves immediately (same frame)
3. Every Label with `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (per `auto-translate-always` pattern) updates its displayed text
4. Every AccessKit-tagged widget re-resolves `accessibility_name` + `accessibility_description` via `_notification(NOTIFICATION_TRANSLATION_CHANGED)` per `accessibility-name-re-resolve` pattern
5. Player sees the entire UI in the new locale within the same frame; no restart, no re-mount

The Settings panel itself complies with both patterns. Verification gate: ADR-0004 §IG7 confirms `auto_translate_mode` constant name (Godot 4.5+ — VG-CMC-4 in Cutscenes). OQ-SA-4 verification gate covers this.

### Reading-speed floor

Per `accessibility-requirements.md` Reading Time row + `dialogue-subtitles.md` 90 cpm floor:

- All transient labels (modifier feedback 4 s, disk-full feedback 4 s) hold long enough for a 90 cpm reader to consume their content + take action.
- Modal bodies are non-timed (player reads at their own pace).
- Revert banner countdown is 7 s default — sufficient for reading the prompt + considering action + interacting (validated post-MVP playtest per OQ-SA-6 ADVISORY).

### Pseudo-localisation testing (recommended)

Before any VS-locale ship, run a pseudo-localisation pass (e.g., wrap every English string with `[ÇǍ]<original>[ÆØ]`) to verify:

1. No layout breaks at 40% expansion
2. No tr-key omitted (unwrapped strings = bugs)
3. AccessKit announces wrapped strings (verifies live-region propagation)

This is a tools-programmer task, owned at VS sprint start.

---

## Acceptance Criteria

These are **UX-spec-level acceptance criteria** for a QA tester / `/story-done` verifier. Each is independently verifiable without reading the full Settings GDD. Underlying mechanical ACs from Settings GDD (AC-SA-1.* through AC-SA-11.*) remain authoritative for the SettingsService implementation; the criteria below verify that the **panel UX** correctly surfaces those mechanics.

### Performance & mount

- [ ] **AC-UX-1.1 [BLOCKING]**: Panel mounts within **120 ms** from `open_panel()` call to first render of Z1+Z2+Z3+Z5 visible. (Frame budget: 16.6 ms × 7 frames = 116 ms; 120 ms allows a small margin for layout + AccessKit announce.)
- [ ] **AC-UX-1.2 [BLOCKING]**: Panel mount with `pre_navigate: "accessibility.damage_flash_enabled"` results in `DamageFlashEnabledToggle` having focus AND being scrolled into the centre 50% of the Z3 viewport on the same frame as Z1+Z2+Z3+Z5 render. No "scroll-into-view tween".
- [ ] **AC-UX-1.3 [BLOCKING]**: Detail pane swap (player selects different Z2 row) completes in **0 frames** (no fade, no tween, no animation per Stage Manager refusal #6).
- [ ] **AC-UX-1.4 [ADVISORY]**: Panel close (`[Back]` or Esc) un-mounts panel within 1 frame.

### Navigation paths

- [ ] **AC-UX-2.1 [BLOCKING]**: Path 1 (Main Menu → Settings) — pressing `[Personnel File]` button opens panel with **Audio category selected by default** (first launch) OR last-visited category (within-session return). No `pre_navigate` parameter is passed by Main Menu's `[Personnel File]` button.
- [ ] **AC-UX-2.2 [BLOCKING]**: Path 2 (Pause Menu → Settings) — pressing `[Settings]` from Pause opens panel with **last-visited category restored within session**, OR Audio category if no last-visited memory exists.
- [ ] **AC-UX-2.3 [BLOCKING]**: Path 3 (Photosensitivity boot-warning → Settings) — pressing `[Go to Settings]` button results in: (a) Settings panel mounts, (b) Accessibility category is selected, (c) `DamageFlashEnabledToggle` has focus, (d) AccessKit announces the focused toggle on mount (`live="polite"`). All four conditions must hold simultaneously.
- [ ] **AC-UX-2.4 [BLOCKING]**: Closing the panel returns control to caller without scene rebuild — Main Menu / Pause Menu remains in the scene tree throughout, just input-gated by InputContext.SETTINGS push, then re-enabled on pop. No call to `change_scene_to_packed` or scene rebuild during open or close.

### Keyboard-only completion

- [ ] **AC-UX-3.1 [BLOCKING]**: A KB-only player (no mouse) can navigate from panel mount to every interactive widget in every category and either change OR explicitly choose not to change every setting. Verify via test: tester uses ONLY keyboard, completes task "set master volume to 50%, enable subtitles, rebind move-forward to W, restore defaults, exit panel". All actions complete; no mouse touched.
- [ ] **AC-UX-3.2 [BLOCKING]**: A gamepad-only player (no keyboard) can perform the same task EXCEPT rebinding (gamepad rebinding is post-MVP per OQ-SA-5). Verify via same test minus rebind step. Rebind cluster shows footnote `"Gamepad rebinding requires keyboard. Coming in a future update."` (per `SETTINGS_REBIND_GAMEPAD_DEFERRED`).

### Error & edge states

- [ ] **AC-UX-4.1 [BLOCKING]**: Disk-full failure — when `ConfigFile.save()` returns `false`, an inline transient label appears beneath the affected widget for 4 s with text `"Could not save. Check disk space."` AND AccessKit announces it `live="assertive"`. The in-memory value is still applied (consumers received `setting_changed`); only persistence failed.
- [ ] **AC-UX-4.2 [BLOCKING]**: Capture cancel — pressing Esc during CAPTURING returns RebindRow to NORMAL_BROWSE state and **does not close the Settings panel** (AC-SA-6.6 reinforced).
- [ ] **AC-UX-4.3 [BLOCKING]**: Capture cancel returns focus to the same RebindRow's CaptureButton (not to a different widget, not to Z2).
- [ ] **AC-UX-4.4 [BLOCKING]**: CONFLICT_RESOLUTION inline banner — when capture results in conflict, banner renders inline within the active RebindRow (NOT as a separate modal); all OTHER RebindRows render `disabled=true`; banner has `accessibility_role = "alert"` + `accessibility_live = "assertive"`.
- [ ] **AC-UX-4.5 [BLOCKING]**: Modifier-feedback transient label appears within 1 frame when player holds a modifier (Shift/Ctrl/Alt/Meta) during capture; persists 4 s OR until next input; AccessKit announces `live="assertive"` once.
- [ ] **AC-UX-4.6 [BLOCKING]**: `ResolutionScaleDropdown` selection triggers Z4 revert banner within 1 frame; banner persists 7 s with countdown text updating at 1 Hz; close-as-confirm semantics apply (panel close = keep new resolution per AC-SA-4.6).

### Accessibility

- [ ] **AC-UX-5.1 [BLOCKING]**: Every interactive widget has a non-empty `accessibility_role`. (Verify via grep test: scan Settings panel scene file; every Control with `mouse_filter = STOP` has a non-empty role.)
- [ ] **AC-UX-5.2 [BLOCKING]**: Every interactive widget has a non-empty `accessibility_name` resolved via `tr()` (NOT a hardcoded English string). FP-8 violation if any widget has bare-string label.
- [ ] **AC-UX-5.3 [BLOCKING]**: Tab order within Z3 detail pane is deterministic and matches visual top-to-bottom-left-to-right order. Tab does NOT cross from Z3 to Z2 (per AC-SA-11.7).
- [ ] **AC-UX-5.4 [BLOCKING]**: Dead-end navigation announces — `ui_down` at last widget in detail pane → AccessKit announces `tr("SETTINGS_NAV_DEAD_END_BOTTOM")` `live="polite"`; `ui_up` at first widget announces `_TOP` (per AC-SA-11.8).
- [ ] **AC-UX-5.5 [BLOCKING]**: Focus ring is **visible** on all focused widgets at all times. (Verify: take screenshots at each widget focused; focus ring must be at least 4 px wide and contrast against widget background.)
- [ ] **AC-UX-5.6 [BLOCKING]**: Color-independence — every signal in the panel is communicated via at least 2 non-color channels. Verify per Color-Independence Audit table.
- [ ] **AC-UX-5.7 [ADVISORY]**: Settings panel passes contrast audit at WCAG AA (4.5:1 body, 3:1 large text). Verified once `tools/ci/contrast_check.sh` ships (TBD per `accessibility-requirements.md`).
- [ ] **AC-UX-5.8 [BLOCKING]**: Reserved actions (Esc / Enter / Tab / Shift+Tab) are rendered as **disabled RebindRows** with footnote — they cannot be rebound by the player.
- [ ] **AC-UX-5.9 [BLOCKING]**: AccessKit per-widget contract complete — every interactive widget in this panel has an entry in this spec's Section G per-widget table. (Verify via cross-reference.)

### Stage Manager refusals (audit)

- [ ] **AC-UX-6.1 [BLOCKING]**: No UI sound is played in response to any panel interaction except slider drag of `audio.*_volume_db` keys (which produce live mix preview, not feedback). Hover, focus change, click, toggle, dropdown selection, button press, modal mount/dismiss — all silent.
- [ ] **AC-UX-6.2 [BLOCKING]**: No animation is played by the panel itself. Panel mount is hard-cut. Panel exit is hard-cut. Detail pane swap is hard-cut. Modal mount is hard-cut. Focus ring movement is instant (no tween).
- [ ] **AC-UX-6.3 [BLOCKING]**: No celebratory feedback on toggle state change — no checkmark flourish, no confetti, no "Accessibility ON ✓" banner. Toggling a CheckButton renders the new boxed state silently.
- [ ] **AC-UX-6.4 [BLOCKING]**: Panel uses Stage Manager visual register: NO Case File typography (Futura / American Typewriter / Courier Prime) on panel chrome; NO manila-folder framing; NO rubber stamps; NO PHANTOM Red except in conflict banner; NO BQA Blue except as primary action color + focus ring + selected category.

### Photosensitivity safety

- [ ] **AC-UX-7.1 [BLOCKING]**: Restore Defaults preserves all 3 keys of the photosensitivity safety cluster (`accessibility.photosensitivity_warning_dismissed`, `accessibility.damage_flash_enabled`, `accessibility.damage_flash_cooldown_ms`). Verify: set damage_flash_enabled=false, cooldown=1000ms, then press Restore Defaults; re-open Accessibility; both values must remain false / 1000ms (per CR-25 / AC-SA-11.2).
- [ ] **AC-UX-7.2 [BLOCKING]**: `[Show Photosensitivity Notice]` button re-displays the modal without changing `accessibility.photosensitivity_warning_dismissed`. Verify: dismiss via boot-warning, then in Settings press button; close modal; relaunch game; boot-warning does NOT reappear (flag still true) (per CR-24 / AC-SA-5.9).
- [ ] **AC-UX-7.3 [BLOCKING]**: `DamageFlashCooldownSlider` cannot be dragged below 333 ms via UI. Verify: drag slider thumb to extreme left; thumb stops at 333 ms (per AC-SA-5.3 / CR-17 333 SAFETY FLOOR).

### Localization

- [ ] **AC-UX-8.1 [BLOCKING]**: All player-visible strings in this panel resolve through `tr()`. No bare-string labels (FP-8). Verify via grep across panel scene + script files.
- [ ] **AC-UX-8.2 [BLOCKING]**: Locale change via `language.locale` dropdown (VS) re-translates all panel labels within the same frame (per `auto-translate-always` pattern; CR-12). Verify at VS only.
- [ ] **AC-UX-8.3 [ADVISORY]**: Pseudo-localisation pass — wrap all English strings with `[ÇǍ]…[ÆØ]` markers and verify no layout breaks at 40% expansion. Run before any VS-locale ship.

### MVP/VS scope adherence

- [ ] **AC-UX-9.1 [BLOCKING]**: At MVP, the panel renders 6 categories with the following content scope: Audio (6 sliders), Graphics (1 dropdown), Accessibility (12 widgets), HUD (cross-ref label only), Controls (4 toggles + 4 sensitivity sliders + 1 axis-toggle + 16 RebindRows MVP-rendered), Language (1 info label).
- [ ] **AC-UX-9.2 [BLOCKING]**: At MVP, gamepad rebinding column is NOT rendered (per OQ-SA-5 deferred to VS).
- [ ] **AC-UX-9.3 [ADVISORY]**: At VS, the panel adds: Accessibility VS cluster (6 widgets), HUD detail pane (3 widgets), Language dropdown (1 widget), Controls gamepad column (~16 RebindRows).

### Cross-pattern compliance

- [ ] **AC-UX-10.1 [BLOCKING]**: Panel uses `input-context-stack` pattern — pushes InputContext.SETTINGS on mount, pops on close.
- [ ] **AC-UX-10.2 [BLOCKING]**: Panel uses `unhandled-input-dismiss` pattern for Esc handling at panel root. Rebind capture exception uses `_input(event)` priority swallow.
- [ ] **AC-UX-10.3 [BLOCKING]**: Panel uses `set-handled-before-pop` pattern in `[Back]` / Esc handler — `set_input_as_handled()` runs BEFORE `InputContext.pop()`.
- [ ] **AC-UX-10.4 [BLOCKING]**: Rebind flow uses `held-key-flush-after-rebind` pattern — `Input.action_release()` called after every successful rebind.
- [ ] **AC-UX-10.5 [BLOCKING]**: All sliders use the (NEW) `settings-slider-pattern` once it is lifted to the library; this UX spec is the first concrete instance and the pattern lift is BLOCKING for `/ux-review`. (See Open Question OQ-UX-LIB-1.)

### Confirmation question for sign-off

> Do these criteria cover what would actually make this panel "done" for QA?

The criteria split: 32 BLOCKING + 5 ADVISORY = 37 ACs total. Photosensitivity safety + Stage Manager refusals + AccessKit per-widget completeness are the irreducibles; failing any BLOCKING criterion blocks `/story-done`. Advisory criteria are tracked but not gating.

---

## Open Questions

UX-spec-level open questions surfaced during authoring. Each carries a recommendation; if accepted at `/ux-review`, the recommendation becomes the locked decision.

| OQ | Title | Owner | Severity | Recommendation |
|---|---|---|---|---|
| **OQ-UX-1** | Banner timer behaviour during modal | UX designer + Settings author | ADVISORY | When any modal mounts (Restore Defaults Confirm, Photosensitivity Review) while a Z4 revert banner is active, the banner timer **pauses**. When modal dismisses, timer resumes from where it paused. Rationale: a player who opens a modal mid-banner-countdown should not have the banner auto-confirm or auto-revert silently while their attention is on the modal. Decision needed pre-implementation. |
| **OQ-UX-2** | Mouse-click-outside dismiss on `RestoreDefaultsConfirmModal` | UX designer | BLOCKING for `/ux-review` | Per `interaction-patterns.md` `dual-focus-dismiss` Open Question: default OFF for destructive-confirm modals. Restore Defaults is destructive (reverts ~25 keys); recommend mouse-click-outside does NOT trigger Cancel. Player must explicitly press `[Cancel]` or Esc. (Same posture as `quit-confirm.md` and `new-game-overwrite` — all destructive-confirm modals reject click-outside.) |
| **OQ-UX-3** | Last-visited category persistence scope | UX designer + Settings author | ADVISORY | Within session: yes (Path 2 returns to last-visited). Cross-launch: NO (first-launch dominance and fresh-state predictability). Recommendation: `SettingsService` holds a non-persistent `_last_visited_category` field initialised to Audio. `open_panel(pre_navigate:)` overrides this. Cleared on autoload reset. Confirm at `/ux-review`. |
| **OQ-UX-4** | takedown gamepad default conflict with reload | Input GDD author + Settings author | BLOCKING for sprint | CR-22 specifies `use_gadget` = JOY_BUTTON_Y and `takedown` = JOY_BUTTON_X as differentiated defaults. But `reload` also defaults to JOY_BUTTON_X per Input GDD §C. **Conflict at first launch**: takedown and reload both bound to JOY_BUTTON_X by default. Resolution options: (a) change takedown gamepad default to a different button; (b) change reload gamepad default; (c) accept the conflict and require player to rebind on first launch (BAD UX). Recommendation: **option (a)** — change takedown gamepad default to JOY_BUTTON_LEFT_STICK_BUTTON (L3 click). Requires Input GDD amendment. |
| **OQ-UX-LIB-1** | `settings-slider-pattern` library lift (BLOCKING gap closure) | UX designer | BLOCKING for `/ux-review` | Per `interaction-patterns.md` Gaps section: `settings-slider-pattern` is BLOCKING and "author after first Settings UX spec is drafted." This spec contains 13 concrete slider instances. Recommended: lift the abstract pattern into the library at `/ux-review` time. Pattern shape: live preview vs commit-on-release semantics, AccessKit `ROLE_SLIDER` + `accessibility_value` per value-changed, KB step (`←/→`), gamepad analog (left stick), Page Up/Down for 10× step, Home/End for min/max, value-label format per slider (dB / % / ms / × multiplier). |
| **OQ-UX-LOC-1** | DE/FR locale length budget breakage | localization-lead | ADVISORY | German "Barrierefreiheit" + French "Restaurer les paramètres par défaut" risk overflowing footer button + category list. First DE/FR translation pass (post-MVP) will surface actual breakage; mitigations are: (a) shorten translations, (b) wrap to 2 lines, (c) grow widget. Decision deferred to first translation pass. |
| **OQ-UX-FOCUS-1** | Focus ring spec — verify Godot 4.6 default | godot-specialist | BLOCKING for sprint | ADR-0004 §IG7 specifies focus ring as 4 px BQA Blue outset. Godot 4.6 may render focus ring via Theme override or default Stylebox. Verification: 5-min editor test confirming `BackButton.theme.set_stylebox("focus", custom_stylebox)` produces the spec'd 4 px outset and no animation. Fold into ADR-0004 Gate 1 verification (OQ-SA-4). |
| **OQ-UX-PATH-2-LAYOUT** | Pause Menu → Settings entry-point label | Pause Menu UX author | ADVISORY (pre-Pause Menu UX spec) | Pause Menu UX spec is not yet authored. The entry button label could be `[Settings]` (consistent with industry convention) OR `[Personnel File]` (consistent with Main Menu's bureaucratic-neutral register). Recommendation: `[Settings]` — Pause is mid-mission and the player is task-focused; bureaucratic-neutral framing matters less here than label clarity. Confirm when Pause Menu UX spec is authored. |
| **OQ-UX-RESET-PER-CATEGORY** | Per-category Restore Defaults | UX designer | ADVISORY (post-VS feature evaluation) | CR-25 specifies global Restore Defaults only. Some players may want category-scoped reset (e.g., "reset only Audio"). Decision: NOT MVP (would complicate the UX); revisit at Polish if playtest shows demand. |
| **OQ-UX-DEFAULT-FOCUS-ENTRY** | Path 1 default-focus widget | UX designer | ADVISORY | When player opens panel from Main Menu (Path 1) with no last-visited memory, focus lands on... what? Recommendation: the first interactive widget in the Audio detail pane (`MasterVolumeSlider`). Rationale: most-frequent first action, immediate audio feedback if dragged. Confirm at `/ux-review`. |
| **OQ-UX-AUDIO-PANEL-DUCK** | Audio panel-open ducking policy | Audio director + Settings author | ADVISORY (post-MVP playtest) | OQ-SA-7 (re-surfaced at UX layer): when Settings panel opens from gameplay (Path 2), should Music + Ambient duck or be muted? Recommendation: **suppress** Music + Ambient + SFX per InputContext.SETTINGS (already locked in ADR-0004); BUT keep SFX active when player is dragging volume sliders (live preview). Decision: live mix preview takes precedence over panel-open suppression for the slider being dragged. |
| **OQ-UX-OUTLINE-VS** | Graphics category outline-thickness slider VS scope | Graphics author + Settings author | ADVISORY | Graphics MVP has 1 widget (resolution_scale dropdown). Are there other VS-only graphics knobs to reserve in this UX? Recommendation: reserve `outline_thickness_px` + `bloom_intensity` + `vignette_strength` for VS, all rendered as future detail-pane widgets. Confirm with art-director / Outline Pipeline GDD owner. |
| **OQ-UX-INPUT-METHOD-DETECT** | Input-method auto-detection | UX designer + Input GDD author | ADVISORY | The Controls Rebind cluster's `SETTINGS_REBIND_GAMEPAD_DEFERRED` footnote should appear only when the player's input method is gamepad. How is input-method detected? Options: (a) last-used input event, (b) Steam Input platform query, (c) UI never shows footnote, always shows KB rebinds + gamepad-deferred message. Recommendation: (a) — track last-used input class; auto-show appropriate prompt set per HUD Core CR-21 rebinding contract. |

### Open questions inherited from upstream sources (NOT closed by this spec)

These remain open and visible to the Settings sprint planner:

- **OQ-SA-1** (BLOCKING, sprint) — Outline Pipeline `get_hardware_default_resolution_scale()` API
- **OQ-SA-3** (BLOCKING, sprint) — Menu System scaffold for boot-warning modal (CR-18) — closes with Menu CR-8
- **OQ-SA-4** (BLOCKING, sprint) — ADR-0004 verification gates Gate 1 + Gate 2
- **OQ-SA-5** (BLOCKING, VS) — Gamepad rebind UI column layout (one column MVP vs two-column VS) — partially answered by this UX (MVP renders one column with gamepad-deferred footnote; VS adds gamepad column)
- **OQ-SA-6** (ADVISORY, post-MVP playtest) — `RESOLUTION_REVERT_TIMEOUT_SEC` duration
- **OQ-SA-9** (BLOCKING, sprint) — Combat weapon-roster muzzle-flash WCAG 2.3.1 verification
- **OQ-SA-10** (BLOCKING, sprint) — Godot 4.6 dual-focus audit (keyboard/gamepad vs mouse/touch focus separation)
- **OQ-SA-11** (BLOCKING, sprint) — Action-name tr-key registration in Input GDD
- **OQ-SA-13** (BLOCKING, sprint) — Audio GDD `clock_tick_enabled` category alignment
- **OQ-SA-14** (BLOCKING, sprint) — Audio GDD six-bus 0 dB clipping risk resolution

This spec **does not** close these — they require Input GDD / Audio GDD / Outline Pipeline / Menu System work. The Settings sprint plan must surface them as gating dependencies.
