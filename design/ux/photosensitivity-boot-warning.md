# UX Spec: Photosensitivity Boot Warning

> **Status**: In Design
> **Author**: user (agustin.ruatta@vdx.tv) + ux-designer
> **Last Updated**: 2026-04-28
> **Journey Phase(s)**: First-Launch Boot (HARD-blocking, before Main Menu interactivity) / Player-Initiated Review (post-MVP first-launch via Settings → Accessibility → "Show Photosensitivity Notice")
> **Implements Pillar**: Accessibility-first carve-out (Standard tier project-elevated to safety-critical Basic+); Pillar 5 (Period Authenticity Over Modernization) explicitly DEFERRED for this surface — Settings & Accessibility GDD §Player Fantasy already documents the non-diegetic carve-out
> **Phasing**: All elements `[MVP]` — Day-1 HARD-blocking dep per Settings CR-18 + HUD Core REV-2026-04-26 D2 + menu-system.md CR-8. No `[VS]` additions. CR-24 (player-initiated review) is also MVP per Settings GDD.
> **Template**: UX Spec
> **Authoritative GDDs**: `design/gdd/settings-accessibility.md` CR-18 (locked body copy + button labels + AccessKit semantics + dismiss-flag contract), CR-24 (player-initiated review reuses this same scaffold), CR-25 (Restore Defaults preserves the safety cluster); `design/gdd/menu-system.md` CR-8 (boot-warning poll mechanism), AC-MENU-6.1–6.5 (boot lifecycle ACs)
> **Hosting Spec**: `design/ux/main-menu.md` (Z5 Modal layer mounts this — Entry table row "Engine cold boot" branch)
> **Related Specs (planned)**: `design/ux/quit-confirm.md` (sibling modal — shares `modal-scaffold` pattern); `design/ux/settings-accessibility.md` (target of "Go to Settings" pre-navigation — not yet authored)

---

## Purpose & Player Need

**Purpose**. This modal is the project's **safety-floor surface** — the first interactive element a first-launch player encounters, and the only screen authored explicitly to prevent harm before any game content runs. It exists to satisfy a single non-negotiable obligation: warn photosensitive players that *The Paris Affair* contains rapid screen flashes (combat damage flash + Cutscenes CT-03 chromatic flash + op-art letterbox slide-in per CT-05) **before** any of those flashes can play, AND offer them a path to mitigation (reduce intensity / disable entirely) **before** they have to leave a running game session to find Settings.

**Player need on arrival**. The player arrives at this modal wanting **to know whether this game is safe for them, and how to make it safer if it isn't**. They are not yet invested in the experience; nothing on screen has rewarded them yet. The modal must communicate the medical advisory clearly, briefly, and without scaring off players who have no photosensitivity concern. The 38-word locked body copy (CR-18) is calibrated for both populations: photosensitive players get the actionable mitigation path; non-photosensitive players get a one-paragraph notice they can dismiss with a single keypress.

**Failure mode if the modal is missing or hard to use**:

1. **Medical harm**. A photosensitive player launches the game; combat starts; the damage flash fires at automatic-fire rate; the player has a seizure or migraine onset. This is the floor risk this modal exists to prevent — the only failure mode in the project where "the design didn't ship" causes physical injury.
2. **Modal is dismissible too easily, missed by AT users**. If the modal can be `ui_cancel`-dismissed before the screen reader has read it (per AC-MENU-6.2 it cannot — but if that AC failed in implementation), AT users would miss the warning entirely. Hence the non-dismissible-by-Esc constraint.
3. **"Go to Settings" doesn't pre-navigate**. If the player presses "Go to Settings" hoping to find the flash-intensity slider but lands on a generic Settings root screen, they have to navigate through 6 categories to find Accessibility → Photosensitivity. For a player who just learned this game has flashes that affect them, that navigation overhead is a friction tax on the safety path. Pre-navigation is required (CR-18 specifies "pre-navigated to Accessibility category with focus on `damage_flash_enabled` toggle").
4. **Modal blocks the player who already saw it**. If the modal re-appears on every cold boot, returning players develop dismiss-without-reading reflex; on the rare boot where the warning content has materially changed (e.g., a patch adds a new flash type), the player misses the update. Hence the persistent dismissed-flag (`accessibility.photosensitivity_warning_dismissed`) and the explicit player-initiated review path via Settings (CR-24).

**Single-sentence formulation**. *"The player arrives at this modal wanting to be told — once, briefly, and before any game content runs — whether this game contains content that could harm them, and how to mitigate it if so; the modal must serve both the photosensitive player who needs the actionable path and the non-photosensitive player who needs a fast dismiss."*

**Pillar carve-out note**. This screen explicitly DEFERS Pillar 5 (Period Authenticity Over Modernization). The Case File register that governs Main Menu / Pause Menu / Save grids does NOT apply here — there is no manila folder, no typewriter SFX, no "Stage Manager" reframing. The modal speaks plain medical-advisory English. This carve-out is documented in Settings GDD §Player Fantasy ("Settings sits outside Pillar 5's diegetic period fiction by explicit creative-director carve-out") and Main Menu §Acknowledgement (boot warning is the one surface that will not be staged as bureaucracy). The same carve-out applies to Settings panel internals — both are non-diegetic by design.

---

## Player Context on Arrival

**When the player first encounters this modal**: This modal appears **before Main Menu becomes interactive on first launch** (cold boot, when `accessibility.photosensitivity_warning_dismissed` key is **absent** from `user://settings.cfg` per CR-18 — absence-not-`false` is the trigger). It does not appear on subsequent cold boots once dismissed; the dismissed-flag persists. CR-25 (Restore Defaults) preserves this flag, so the warning never re-fires from a settings reset alone. Only `settings.cfg` deletion (or first-ever launch) re-triggers it.

**Three arrival paths**:

| Arrival path | Frequency | Immediately before | Emotional register |
|---|---|---|---|
| **Cold boot, first launch** | Once per fresh install | Player double-clicked Steam shortcut; engine booted; `SettingsService._ready()` set `_boot_warning_pending = true`; `MainMenu._ready()` polled the flag and called `ModalScaffold.show_modal(PhotosensitivityWarningContent)` | **Mid-boot interruption** — player expected to play, suddenly confronted with a medical advisory before any game content runs. Not stressed; not invested yet. Cautious, attentive (or in the photosensitive case, watchful for what they'd hoped to find) |
| **Player-initiated review** (per CR-24) | Any time post-MVP first-launch | Player navigated Settings → Accessibility → pressed `[Show Photosensitivity Notice]` button | **Deliberate** — player has specific intent (re-read the notice, possibly investigating a flash that startled them, or reminding themselves of mitigation options). Lower attentional cost than first-launch since they know what's coming |
| **Post-`settings.cfg` deletion** (rare; manual file delete or fresh-install-after-uninstall) | Once per fresh install equivalent | Player deleted `settings.cfg` directly (advanced/uncommon path), then launched the game | Same as cold-boot first launch |

**Emotional state design assumes**. **Cautious-attentive**. The player is not stressed (no gameplay tension exists yet), but they are not contemplative either — a medical advisory pre-empts any other tone. The modal must read as **clear and brief, not ominous**. The 38-word body copy (CR-18) is calibrated for this register: factual, actionable, no scare-language ("seizure", "epilepsy", "warning" in red) that would cause non-photosensitive players to dismiss reflexively without reading.

**Voluntary or sent-here**. **Sent-here** — the only modal in the project where the game routes the player without an explicit player action. The first launch could not have asked for the warning; the warning has to appear unbidden. The Restore Defaults confirmation, the Quit-Confirm, the New-Game-Overwrite all follow a player action; this modal precedes one. That distinction shapes the dismissal contract: every other modal can default-Cancel because the player initiated the action; this modal cannot default-Cancel because there is no action to cancel. Default focus is `[Continue]` (the safe path forward) per CR-18.

**What the screen must NOT assume about player context**:

- The player is **not necessarily a fluent reader** — keep the body copy at the locked 38 words, no longer. Reading-impaired players (cognitive accessibility) need short, scannable copy. The locked text is calibrated for this.
- The player is **not necessarily English-speaking** — every text element is `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. Locale switch happens in Settings, but the photosensitivity modal must respect whatever locale `SettingsService` set during its own `_ready()` (which runs before this modal mounts).
- The player **may be using assistive tech (screen reader)** — `accessibility_role = "dialog"` + `accessibility_live = "assertive"` ensure the AT announces the modal's content the moment it mounts, before the player can interact. AT users get the warning even if they cannot see the screen.
- The player **may be photosensitive and reading this modal at risk** — the modal itself contains zero flashing content, zero rapid color change, zero animation that could cause harm. The modal that warns about flashes must not itself flash.
- The player **may have launched the game in a hurry** (e.g., friend just bought it, wants to demo it). The modal must be quick to dismiss for the non-photosensitive case (`Continue` + Enter = ~2 seconds), but cannot be auto-dismissed (the player must consent — see Section E).

---

## Navigation Position

**This modal is a transient overlay child of `MainMenu`** mounted via `ModalScaffold.show_modal(PhotosensitivityWarningContent)` per CR-18. It has no parent screen of its own (the modal does not navigate from anywhere — it is a side-effect of `MainMenu._ready()` polling `_boot_warning_pending`). It has two exit destinations: dismiss-back-to-Main-Menu (default), or dismiss-and-pre-navigate-to-Settings.

**Position summary**:

```
[Engine boot] → MainMenu.tscn
                     │
                     └── ModalScaffold (CanvasLayer, lazy-instantiated child of MainMenu)
                             │
                             └── PhotosensitivityWarningContent  ← (this modal)
                                      │
                                      ├── [Continue] button  ──►  hide_modal() → focus to Continue/Begin Operation on MainMenu
                                      │
                                      └── [Go to Settings]  ──►  hide_modal() → SettingsService.open_panel(pre_navigate: damage_flash_enabled)
                                                                                      │
                                                                                      └── Settings panel (Accessibility category, focus on damage_flash_enabled toggle)
```

**Top-level vs context-dependent**: This modal is **strictly context-dependent**. It mounts only when `_boot_warning_pending == true` at the moment `MainMenu._ready()` runs (cold boot first launch) OR when `SettingsService` re-fires it via the player-initiated review button (CR-24). It cannot be reached from any other screen — there is no navigation path that opens this modal from gameplay, from Pause Menu, from the Operations Archive, etc.

**Sibling-of-which surface**: The modal lives at the same hierarchy level as `QuitConfirmContent`, `NewGameOverwriteContent`, and `SaveFailedContent` — all are mounted via the shared `ModalScaffold` per the depth-1-queue rule (`menu-system.md` C.4: most-recent-wins, never depth-2). However, `_boot_warning_pending` is checked BEFORE any of those modals can fire (the boot-warning is gated on `MainMenu._ready()` synchronous execution; user-initiated modals require the Main Menu to be interactive first). So in practice the boot-warning modal never co-occurs with another modal.

**CR-24 review path**: When the player presses Settings → Accessibility → `[Show Photosensitivity Notice]`, the modal mounts via the same `ModalScaffold` instance that Settings owns or via the global one (implementation detail — flag in Open Questions if the scaffold ownership is ambiguous). The modal content is identical; the dismiss path differs: review-mode dismiss returns focus to the `[Show Photosensitivity Notice]` button in Settings, NOT to Main Menu's Continue button. Both `[Continue]` and `[Go to Settings]` buttons in review-mode have semantically identical effects (they don't reset the dismissed-flag — it was already `true`); they just close the modal.

**No deep-link**: The player cannot bookmark or URL-link to this modal; it cannot be triggered from a debug console (in MVP — debug-trigger paths might be added in Polish for QA testing). Re-firing on cold boot requires either deleting `settings.cfg` or programmatically deleting the dismissed-flag key.

---

## Entry & Exit Points

**Entry Sources** (every way the modal can mount):

| Entry Source | Trigger | Player carries this context | MVP/VS |
|---|---|---|---|
| **Cold boot, first launch** | `SettingsService._ready()` detects absent `accessibility.photosensitivity_warning_dismissed` key in `user://settings.cfg`, sets `_boot_warning_pending = true` → `MainMenu._ready()` polls flag synchronously per CR-8 → calls `ModalScaffold.show_modal(PhotosensitivityWarningContent)` → modal mounts BEFORE Main Menu becomes interactive | Locale already loaded by SettingsService (via `TranslationServer.set_locale()` during its own `_ready()`); `Context.MENU` already on stack from `MainMenu._ready()`; modal mount pushes `Context.MODAL` (depth-1 from MENU) | MVP — Day-1 HARD-blocking dep |
| **Player-initiated review (CR-24)** | Player navigates Main Menu → Personnel File → Settings panel opens → Accessibility category → presses `[Show Photosensitivity Notice]` button | `Context.SETTINGS` on stack; modal mount pushes `Context.MODAL` (depth-1 from SETTINGS); dismissed-flag is already `true` (re-firing modal does NOT change it) | MVP — per CR-24 |
| **Post-`settings.cfg` deletion (rare)** | Player manually deletes `user://settings.cfg` (advanced/uncommon path: settings file location varies per platform — `~/.local/share/godot/...` on Linux, `%APPDATA%\Godot\...` on Windows); subsequent launch behaves as fresh-install per CR-18 absence-not-`false` rule | Same as cold-boot first launch | MVP (covered by the same code path) |

**Exit Destinations** (every way the modal dismisses):

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Dismiss-to-Main-Menu (Continue path)** | `[Continue]` button activated (default focus per CR-18) | (a) `SettingsService.dismiss_warning()` called → returns `true` (success) OR `false` (disk-full failure); (b) on `true`: `accessibility.photosensitivity_warning_dismissed = true` written to `settings.cfg`, `setting_changed` emitted, `ModalScaffold.hide_modal()` called, `Context.MODAL` pops, focus restored to Main Menu's Continue/Begin Operation button per AC-MENU-6.3; (c) on `false`: modal stays open, `Context.MODAL` remains on stack, button retains process_input, second activation re-attempts `dismiss_warning()` per AC-MENU-6.4 |
| **Dismiss-to-Settings (Go to Settings path)** | `[Go to Settings]` button activated | (a) `SettingsService.dismiss_warning()` called (same success/failure semantics as Continue); (b) on success: `hide_modal()` → `Context.MODAL` pops → `SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")` called → `Context.SETTINGS` pushed by Settings → focus moves to `damage_flash_enabled` toggle within Settings panel; (c) on failure: same as Continue's failure path — modal stays open |
| **Dismiss-to-Settings (review-mode return)** | `[Continue]` OR `[Go to Settings]` activated when modal was opened from Settings → Accessibility (CR-24 review path) | `dismiss_warning()` is NOT called (dismissed-flag stays as-is, already `true`); `hide_modal()` → `Context.MODAL` pops → focus restored to `[Show Photosensitivity Notice]` button in Settings panel (NOT to Main Menu) |
| **`ui_cancel` (Esc / B button) — non-dismissible** | Player presses Esc or gamepad B while modal is open, BEFORE successful dismiss_warning() | Per AC-MENU-6.2: event is consumed, modal stays open. The non-dismissibility is a SAFETY constraint — the player must explicitly choose Continue or Go to Settings to acknowledge they read (or chose not to read) the warning. This is the ONE modal in the project that does NOT honor `dual-focus-dismiss` for `ui_cancel`. **Exception**: in CR-24 review-mode, `ui_cancel` IS allowed to dismiss (because the player has already seen the warning at boot — re-review doesn't gate safety). Open Question — confirm whether AC-MENU-6.2's non-dismissibility extends to review-mode. |
| **Mouse-click-outside — non-dismissible** | Player clicks on dimmed area outside modal rect | Same as `ui_cancel`: event consumed, modal stays open in boot path; allowed-to-dismiss in CR-24 review-mode (pending Open Question resolution). Per `dual-focus-dismiss` pattern this would normally trigger the Cancel button — but this modal has no Cancel button (Continue is not Cancel; it's an explicit acknowledgement) |
| **Window/app close (Alt+F4 / Cmd+Q)** | OS-level window close while modal is open | OS-level signal forces application exit; modal does not get a chance to call `dismiss_warning()`. On next launch: `_boot_warning_pending == true` again (key still absent) → modal re-fires. This is correct behavior — the player did NOT acknowledge the warning, so they should see it again |

**Irreversible exits**: None. Every dismiss path is reversible: the player can re-open the modal via Settings → Accessibility → `[Show Photosensitivity Notice]` (CR-24) at any time. The dismissed-flag write is reversible only by `settings.cfg` deletion (or, at the file-level, by manually editing the key) — but the modal itself is replayable.

**State transitions on dismiss**:

```
     [_boot_warning_pending = true]                 ← cold boot, fresh install
                 │
                 ▼
    [Modal mounted, Context.MODAL pushed]          ← AC-MENU-6.1
                 │
                 ├──[Continue / Go to Settings activated]
                 │       │
                 │       ▼
                 │  [SettingsService.dismiss_warning()]
                 │       │
                 │       ├──[returns true]                                 ├──[returns false (disk full)]
                 │       │                                                  │
                 │       ▼                                                  ▼
                 │  [dismissed_flag = true persisted]              [Modal stays open, AC-MENU-6.4]
                 │  [hide_modal(), Context.MODAL pops]
                 │  [focus restored per CR-8 step]
                 │
                 └──[ui_cancel / outside-click — boot path only]
                         │
                         ▼
                    [event consumed, modal stays open per AC-MENU-6.2]
```

---

## Layout Specification

### Information Hierarchy

**Information items the modal must communicate** (full inventory):

| # | Item | Source | MVP/VS |
|---|---|---|---|
| 1 | The locked 38-word body copy (medical advisory + mitigation path) | settings-accessibility.md CR-18 | MVP |
| 2 | Action options: `[Continue]` (default focus) + `[Go to Settings]` | CR-18 | MVP |
| 3 | Modal title — `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE")` (per Settings GDD §C.5 AccessKit row, language-agnostic placeholder TBD) | CR-18 + Settings C.5 | MVP |
| 4 | Backdrop dim (visual indicator that everything else is inert) | `modal-scaffold` pattern | MVP |
| 5 | Visual containment frame (the modal "card") | `modal-scaffold` pattern | MVP |
| 6 | Optional: warning icon (e.g., ⚠ glyph or accessibility symbol) | Not in CR-18; convention | flag as Open Question |
| 7 | Disk-full failure feedback (shown when `dismiss_warning()` returns `false`) | AC-MENU-6.4 | MVP — though no GDD specifies the visual treatment |

**Ranking — what does the player need to see first?**

1. **Most critical**: **The body copy** itself. The 38-word advisory is the entire reason this screen exists. It must be the visual focus the moment the modal mounts.
2. **Second**: **The action options** (`[Continue]` + `[Go to Settings]`). The player needs to know what to do as soon as they finish reading. Below the body, in reading order.
3. **Third**: **The title**. Orients the screen (what is this dialog?). At top, smaller weight than body — title is contextual; body is content.
4. **Discoverable, not visible at glance**: **The backdrop dim** (signals "everything else is inert") and **the modal frame** (signals "this is a dialog, not a screen takeover"). Composition primitives, not information.
5. **Invisible unless triggered**: **The disk-full failure feedback**. Most plays never see it; rendered as inline text below the buttons OR as a status-bar style message inside the modal — see Open Question #2 below.

**Conflict check — minimal information vs medical-advisory genre conventions**:

Medical-advisory dialogs (epilepsy warnings on game boot screens, photosensitivity disclosures) commonly include: a warning icon (⚠ or accessibility symbol), bold "WARNING" header, sometimes red color highlighting. CR-18's locked copy explicitly avoids "warning" language ("This game contains flashing images" vs "WARNING: This game contains flashing images"). The Stage Manager register (Settings GDD Player Fantasy) favors **plain, factual, advisory voice** over **alarming voice**.

Decision: **No warning icon, no "WARNING" header, no red color**. The title is `"Photosensitivity Notice"` (placeholder — final string TBD via Settings GDD title key) — neutral, factual, locale-agnostic. The body carries the safety information without scare-language. This matches CR-18's intent.

If MVP playtest reveals players are dismissing without reading (low engagement signal — e.g., AT users skip past, or non-photosensitive players treat it as boilerplate), a warning icon could be added in patch 1. Flag as Open Question #1.

### Layout Zones

**Selected arrangement**: **Option B — Wider band, more readable line length**. Rationale: the 38-word body is the modal's load-bearing content; fewer line-wraps (~3 lines vs ~5) reduces reading time for the non-photosensitive player and minimizes scroll/tracking effort for cognitive-accessibility users. The wider modal reads as a "banner" rather than a "dialog" — which matches the boot-time, sent-here, advisory register of this surface.

**Reference resolution**: 1920 × 1080 (technical-preferences.md target hardware floor). All zone allocations scale with `Window.content_scale_factor` and `ui_scale` (Settings G.3 — 75–150%). 16:9 only in MVP.

**Modal sizing** (1080p reference):

- **Modal card**: 880 × 280 px, centered horizontally and vertically
- **Backdrop dim**: full-screen `ColorRect` at Ink Black `#1A1A1A` 52% opacity (matches `desk_overlay_alpha = 0.52` from menu-system.md AC-MENU-2.5 — same token reused for visual consistency across all overlays)
- **Outer modal padding**: 32 px from card edge to inner content

**Zone allocation** (within the 880 × 280 px modal card):

| Zone | Position | Allocation | Contents | MVP/VS |
|---|---|---|---|---|
| **Z1 — Title bar** | Top | 0–14% V (≈40 px) | Modal title `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE")` ("Photosensitivity Notice") — left-aligned, Futura/DIN bold 22 px, BQA Blue on Parchment-tinted modal frame; thin 1 px Ink Black rule below | MVP |
| **Z2 — Body content** | Center | 14–75% V (≈170 px) | Locked 38-word body copy from CR-18 — left-aligned, American Typewriter 18 px, Ink Black on Parchment-tinted modal frame; line-height ≈ 1.4× (~25 px); paragraph break between sentences 2 and 3 (between "...disable it entirely." and "This notice can be...") | MVP |
| **Z3 — Button row** | Bottom | 75–100% V (≈70 px) | Two `Button` controls right-aligned: `[Go to Settings]` (left) + `[Continue]` (right, default focus, primary action); 16 px gap between buttons; thin 1 px Ink Black rule above | MVP |
| **Z4 — Inline failure feedback** | Bottom (above Z3 buttons, below Z2 body) | conditional, ~30 px when shown | Inline status text shown ONLY when `dismiss_warning()` returns `false` (disk-full case per AC-MENU-6.4); copy: `tr("SETTINGS_PHOTOSENSITIVITY_DISMISS_FAILED")` ("*Could not save your acknowledgment. Please try again or check disk space.*") in Ink Black 14 px italic | MVP |
| **Backdrop** | Full-screen, behind modal card | 100% V × 100% H | `ColorRect` at Ink Black `#1A1A1A` 52% opacity over Main Menu — main menu remains visible (no full grey-out) per `modal-scaffold` pattern §spec | MVP |

**Modal frame palette** (non-diegetic carve-out — does NOT inherit Pillar 5 dossier register):

- Modal background fill: **Parchment** `#E8DCC4` (matches the project palette per art-bible §4 — but used as solid plain card, no manila folder framing, no period stamps)
- Modal border: 2 px Ink Black `#1A1A1A` solid line (no rounded corners — hard-edged per art-bible §3.3 UI shape grammar; the carve-out applies to register, not to base shape language)
- No drop shadow (Pillar 5 Refusal applies even to the carve-out — hard-edged rectangles, no shadows)
- No accent color on title bar (the title is text only; no colored band)

**Margins & safe zones**:

- **Outer padding (modal card edge to content)**: 32 px on all 4 sides
- **Title-to-body gap**: 16 px below the title rule
- **Body-to-button-row gap**: 16 px above the button row rule
- **Inter-button gap**: 16 px between `[Go to Settings]` and `[Continue]`
- **Button hit-target**: minimum 280 × 56 px per WCAG SC 2.5.5 (matches main-menu.md button sizing)

**Resolution scaling**:

- At 4K (2160p), all dimensions × 2 (modal becomes 1760 × 560 px). Centered position is preserved.
- ui_scale 75–150% per Settings G.3 multiplies all dimensions. At 75%: 660 × 210 px (still legible — body wraps to 4 lines); at 150%: 1320 × 420 px (longer body line, fewer wraps). Backdrop dim is unaffected by ui_scale.
- Outer padding floor at 75% ui_scale: 24 px (still > 18 px focus-ring buffer).

### Component Inventory

Per-zone component list. Pattern references point to `design/ux/interaction-patterns.md`. **NEW** indicates a pattern not yet in the library.

**Backdrop** [MVP infrastructure]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `BackdropDim` | `ColorRect` | Full-screen Ink Black `#1A1A1A` at 52% opacity, mounted by `ModalScaffold` parent CanvasLayer | Yes (intercepts mouse-clicks per `modal-scaffold` — for boot path: clicks consumed but no dismiss; for CR-24 review path: clicks dismiss like Cancel) | `modal-scaffold` |

**Modal card** [MVP frame]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `ModalCardFrame` | `Panel` (or `PanelContainer`) | Parchment `#E8DCC4` fill, 2 px Ink Black border, hard-edged corners (no `corner_radius` Theme override) | No (decorative; focus is on child controls) | `modal-scaffold` |

**Z1 — Title bar** [MVP]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `TitleLabel` | `Label` | `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE")` ("Photosensitivity Notice"); Futura/DIN bold 22 px, BQA Blue on Parchment, left-aligned | No | `auto-translate-always` |
| `TitleRule` | `HSeparator` (or `ColorRect`) | 1 px Ink Black line, full-width within outer padding | No | n/a (visual primitive) |

**Z2 — Body content** [MVP core]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `BodyLabel` | `Label` (with `autowrap_mode = AUTO_WRAP_WORD_SMART`) | The locked CR-18 38-word body copy. American Typewriter 18 px, Ink Black on Parchment, left-aligned, line-height ≈ 1.4×. Paragraph break between sentences 2 and 3. | No (text only) | `auto-translate-always` + `accessibility-name-re-resolve` |

**Z3 — Button row** [MVP core]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `ButtonRowRule` | `HSeparator` (or `ColorRect`) | 1 px Ink Black line above the buttons, full-width within outer padding | No | n/a |
| `GoToSettingsButton` | `Button` | Label: `tr("SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS")` ("Go to Settings"). Hit-target ≥ 280 × 56 px. Standard ADR-0004 Theme styling (BQA Blue fill, Parchment label). | Yes — opens Settings panel pre-navigated to `damage_flash_enabled` toggle | `auto-translate-always` + `modal-scaffold` (target) + `accessibility-name-re-resolve` |
| `ContinueButton` | `Button` | Label: `tr("SETTINGS_PHOTOSENSITIVITY_CONTINUE")` ("Continue"). **Default focus** on modal mount per CR-18. Same hit-target and styling as GoToSettings. | Yes — primary action: dismisses modal and proceeds | `auto-translate-always` + `modal-scaffold` (target) + `accessibility-name-re-resolve` |

**Z4 — Inline failure feedback** [MVP, conditional]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `FailureFeedbackLabel` | `Label` | `tr("SETTINGS_PHOTOSENSITIVITY_DISMISS_FAILED")` ("*Could not save your acknowledgment. Please try again or check disk space.*"). Ink Black 14 px italic, left-aligned. **Visibility**: hidden at modal mount; shown when `dismiss_warning()` returns `false`; reset to hidden when modal next mounts (or on next successful dismiss attempt) | No (status only — `accessibility_live = "polite"` so AT announces it without interrupting the user) | `auto-translate-always` + **NEW pattern candidate**: `inline-action-failure-feedback` (composition primitive for in-modal failure status — distinct from `save-failed-advisory` which is a full modal). Re-evaluate library addition once a second modal needs the same primitive (e.g., New-Game-Overwrite confirm-write failure). |

**Hidden / structural — not visible at rest**:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `FocusTrap` | (logical, owned by `ModalScaffold`) | Tab cycles within Z3 buttons only — escape blocked by ADR-0004 §97 `_unhandled_input` interception | n/a | `modal-scaffold` (focus trap) |
| `AssertiveAnnounceTimer` | (one-shot, `call_deferred`) | Sets modal root `accessibility_live = "assertive"` on mount, then `"off"` on next frame per CR-21 + AC-MENU-6.5 | n/a | `modal-scaffold` |

**NEW patterns flagged for library addition**: 1 candidate — `inline-action-failure-feedback` (in-modal status text shown when an asynchronous-feeling sync action fails; distinct from the full `save-failed-advisory` modal). Recommendation: defer until a second consumer exists; this MVP modal is the only known consumer.

### ASCII Wireframe

**Default state** (post-mount, before any button activated):

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← BackdropDim
│ ░░  Main Menu visible underneath: BQA Blue field + Eiffel silhouette + buttons   ░░ │     (52% Ink Black
│ ░░  (faded by the dim, Z2 buttons in process_input=false state per CR-8)         ░░ │      over Main Menu)
│ ░░                                                                               ░░ │
│ ░░       ┌──────────────────────────────────────────────────────────────┐       ░░ │
│ ░░       │ Photosensitivity Notice                                      │       ░░ │  ← Z1 TitleLabel
│ ░░       │ ──────────────────────────────────────────────────────────── │       ░░ │     + TitleRule
│ ░░       │                                                              │       ░░ │
│ ░░       │  This game contains flashing images, including rapid screen │       ░░ │
│ ░░       │  flashes during combat. You can reduce flash intensity in   │       ░░ │  ← Z2 BodyLabel
│ ░░       │  Settings → Accessibility, or disable it entirely.          │       ░░ │     (locked 38-word
│ ░░       │                                                              │       ░░ │      CR-18 copy)
│ ░░       │  This notice can be reviewed again at any time from the     │       ░░ │
│ ░░       │  Settings menu.                                              │       ░░ │
│ ░░       │                                                              │       ░░ │
│ ░░       │ ──────────────────────────────────────────────────────────── │       ░░ │  ← ButtonRowRule
│ ░░       │              ┌──────────────────┐  ┌──── ▶ ─────────┐       │       ░░ │
│ ░░       │              │  Go to Settings  │  │   Continue     │       │       ░░ │  ← Z3 ButtonRow
│ ░░       │              └──────────────────┘  └────────────────┘       │       ░░ │     (Continue
│ ░░       │                                       ↑ default focus,      │       ░░ │      rightmost,
│ ░░       │                                         inverted fill        │       ░░ │      default focus)
│ ░░       └──────────────────────────────────────────────────────────────┘       ░░ │
│ ░░                                                                               ░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────────────────────────────────────────────────┘

  Modal: 880 × 280 px @ 1080p, centered horizontally + vertically
  Modal frame: Parchment fill, 2 px Ink Black border, no rounded corners, no drop shadow
```

**Disk-full failure state** (after `[Continue]` activated, `dismiss_warning()` returned `false`):

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ░░                                                                               ░░ │
│ ░░       ┌──────────────────────────────────────────────────────────────┐       ░░ │
│ ░░       │ Photosensitivity Notice                                      │       ░░ │
│ ░░       │ ──────────────────────────────────────────────────────────── │       ░░ │
│ ░░       │                                                              │       ░░ │
│ ░░       │  This game contains flashing images, including rapid screen │       ░░ │
│ ░░       │  flashes during combat. You can reduce flash intensity in   │       ░░ │
│ ░░       │  Settings → Accessibility, or disable it entirely.          │       ░░ │
│ ░░       │                                                              │       ░░ │
│ ░░       │  This notice can be reviewed again at any time from the     │       ░░ │
│ ░░       │  Settings menu.                                              │       ░░ │
│ ░░       │                                                              │       ░░ │
│ ░░       │  Could not save your acknowledgment. Please try again       │       ░░ │  ← Z4 FailureFeedback
│ ░░       │  or check disk space.                                       │       ░░ │     (Ink Black 14 px italic)
│ ░░       │                                                              │       ░░ │
│ ░░       │ ──────────────────────────────────────────────────────────── │       ░░ │
│ ░░       │              ┌──────────────────┐  ┌──── ▶ ─────────┐       │       ░░ │
│ ░░       │              │  Go to Settings  │  │   Continue     │       │       ░░ │
│ ░░       │              └──────────────────┘  └────────────────┘       │       ░░ │
│ ░░       └──────────────────────────────────────────────────────────────┘       ░░ │
│ ░░                                                                               ░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────────────────────────────────────────────────┘

  Modal grows ~30 px taller to accommodate failure feedback row
  Buttons remain enabled (player can retry by re-pressing)
```

**Focus indicator**: Same as Main Menu's pattern (4 px BQA Blue solid border, inverted fill on focused button — Parchment fill, BQA Blue text). Snap, no animation.

**Default focus on mount**: `ContinueButton` per CR-18.

**Tab order**:

- Cold boot path: `ContinueButton` ↔ `GoToSettingsButton` (only 2 focusable elements; Tab/Shift+Tab cycles between them; FocusTrap blocks escape from the modal)
- CR-24 review path: same 2-element cycle

**Layout-direction note**: In RTL locales (out of MVP/VS scope; flagged in Localization), the button row would mirror — `[Continue]` would be leftmost, `[Go to Settings]` rightmost. RTL is post-launch per main-menu.md Localization §RTL.

---

## States & Variants

**State table** (every visual/interactive variant of the modal):

| State / Variant | Trigger | What Changes | MVP/VS |
|---|---|---|---|
| **Default — modal mounted** | `ModalScaffold.show_modal(PhotosensitivityWarningContent)` called by Main Menu (boot path) OR by Settings (CR-24 review path) | Standard layout (per C.4 default wireframe). Continue button focused; FocusTrap active; AccessKit assertive announce on first frame; `Context.MODAL` on stack | MVP |
| **Disk-full failure** | `[Continue]` or `[Go to Settings]` activated → `SettingsService.dismiss_warning()` returns `false` (per AC-MENU-6.4) | Z4 `FailureFeedbackLabel` becomes visible (modal grows ~30 px taller); buttons retain `process_input = true` and remain focusable; modal stays open; `Context.MODAL` remains on stack; second activation re-attempts `dismiss_warning()` | MVP |
| **Disk-full failure cleared** | Second activation succeeds → `dismiss_warning()` returns `true` | Z4 hides; modal proceeds with normal dismiss path (per Continue or Go-to-Settings flow). FailureFeedback visibility resets | MVP |
| **Pending dismiss (transient)** | Between button activation and `dismiss_warning()` return | One frame: button is registered as activated but state hasn't resolved. Buttons should NOT enter `disabled = true` here (re-entrancy is acceptable on this modal — re-pressing during the same-frame call is a no-op since the API is synchronous per Settings GDD CR-9 invariant) | MVP |
| **Locale changed mid-modal** | `NOTIFICATION_TRANSLATION_CHANGED` received while modal is open | All Labels (Title, Body, Button labels, FailureFeedback) re-translate via `auto-translate-always`; AccessKit `accessibility_name` re-resolves via `accessibility-name-re-resolve`. Layout reflows to accommodate new locale's body length. **Edge case**: if locale changes during boot path (rare — locale is set by SettingsService before modal mounts), the body re-wraps; if change occurs in review path (player went to Settings → Language sub-screen → returned to Accessibility → re-opened the notice), this is normal. | MVP (plumbing) → VS (FR + DE locales ship) |
| **ui_scale changed mid-modal** | `setting_changed("graphics", "ui_scale", value)` received while modal is open (rare — Settings panel is a sibling overlay; ui_scale slider lives in Graphics sub-screen, not Accessibility, so player cannot change it without leaving the modal first) | Layout reflows on next layout pass. Modal dimensions scale; backdrop dim is unaffected. | MVP (plumbing) |
| **Reduced-motion active** | `Settings.reduced_motion == true` | No effect — modal has no animations to gate at rest (mount and dismiss are both snap-cuts per Section E3 of main-menu.md inheritance). The `reduced-motion-conditional-branch` plumbing exists but consumes nothing here | MVP (plumbing) |
| **CR-24 review path mounted from Settings** | Player presses `[Show Photosensitivity Notice]` from Settings → Accessibility | Identical visual presentation to default state; behavioral difference only in dismiss path (per Section B3 — `dismiss_warning()` not called; focus restored to `[Show Photosensitivity Notice]` button on dismiss instead of Main Menu's Continue button). `ui_cancel` IS allowed to dismiss in this state (review-mode exception; user-locked decision per Section B3 approval) | MVP |

**Platform variants**: None. Linux + Windows render identically. No mobile, no console-specific variant.

**Combined-state matrix**:

| | Default | Disk-full | Pending dismiss | Locale changed | ui_scale changed | CR-24 review |
|---|---|---|---|---|---|---|
| **Default** | — | one-frame transition | one-frame transition | applies on receipt | applies on receipt | mutually exclusive (mount-time choice) |
| **Disk-full** | one-frame transition (cleared) | — | one-frame transition (re-attempt) | applies on receipt | applies on receipt | NOT possible from review path (review path doesn't call dismiss_warning) |
| **Pending dismiss** | terminal (success or failure resolves) | terminal | — | rare (transient) | rare (transient) | possible during review-mode dismiss button press |
| **Locale changed** | applies | applies | applies | — | independent | applies |
| **ui_scale changed** | applies | applies | applies | independent | — | applies |
| **CR-24 review** | mutually exclusive (entry-time) | NOT possible | n/a | applies | applies | — |

**State-transition invariants**:

1. `Context.MODAL` is on the stack from `show_modal()` return until `hide_modal()` returns.
2. The modal cannot be dismissed by `ui_cancel` in boot path (per AC-MENU-6.2) — the `_unhandled_input` consumes `ui_cancel` events without acting.
3. The modal CAN be dismissed by `ui_cancel` in CR-24 review path (per Section B3 user-locked decision).
4. Z4 `FailureFeedbackLabel` visibility is one-shot per dismiss attempt — it shows on failure, hides on next mount or on next successful dismiss.
5. `[Continue]` retains default focus across all visual states (focus does not move when Z4 appears).
6. AccessKit assertive announce is one-shot per modal mount (set on `_ready()`, cleared via `call_deferred` on next frame).

---

## Interaction Map

**Input methods**: KB/Mouse primary + Gamepad partial (per technical-preferences.md). All interactions consumed via `_unhandled_input(event)` checking `event.is_action_pressed(...)` per ADR-0004 §97.

**Per-component interaction map**:

| Component | Action | KB/Mouse | Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **`ContinueButton`** (default focus) | Activate | `LMB` click OR `Enter` / `Space` while focused | `JOY_BUTTON_A` while focused | Button fill snap-inverts (Parchment / BQA Blue) for 1 frame; no SFX (this modal is non-diegetic, no Case File typewriter sounds — see Section E3 audio note) | Calls `SettingsService.dismiss_warning()`. On `true`: `hide_modal()` → `Context.MODAL` pops → focus restored to Main Menu Continue button. On `false`: Z4 `FailureFeedbackLabel` becomes visible; modal stays open |
| **`ContinueButton`** | Focus | `Tab` (KB) / `↑↓` D-pad / mouse hover | `↑↓` D-pad / left stick | Focus indicator (4 px BQA Blue border, inverted fill); no SFX | None — focus only |
| **`GoToSettingsButton`** | Activate | LMB / Enter / Space | A button | Same snap-invert as Continue | Calls `SettingsService.dismiss_warning()` (same success/failure semantics). On `true`: `hide_modal()` → `Context.MODAL` pops → `SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")` → focus moves to `damage_flash_enabled` toggle in Settings panel. On `false`: same as Continue's failure path |
| **`GoToSettingsButton`** | Focus | Tab / D-pad / mouse hover | D-pad / left stick | Focus indicator | None |
| **Esc / `ui_cancel`** (boot path) | Press | `Esc` | `JOY_BUTTON_B` | None | **No effect** per AC-MENU-6.2 — event consumed by `_unhandled_input` and ignored. Modal cannot be dismissed by Esc until the player explicitly chooses Continue or Go to Settings |
| **Esc / `ui_cancel`** (CR-24 review path) | Press | `Esc` | `JOY_BUTTON_B` | None | **Dismisses modal** — equivalent to `[Continue]` activation in review mode. `dismiss_warning()` is NOT called (dismissed-flag stays `true` from the boot acknowledge); `hide_modal()` → focus restored to `[Show Photosensitivity Notice]` button in Settings |
| **Mouse-click-outside** (boot path) | Click | LMB outside modal rect (on `BackdropDim`) | n/a | None | **No effect** — `BackdropDim` consumes click events but does not dismiss in boot path |
| **Mouse-click-outside** (CR-24 review path) | Click | LMB outside modal rect | n/a | None | **Dismisses modal** — equivalent to `ui_cancel` in review mode (per `dual-focus-dismiss` pattern, with the review-mode exception locked) |
| **`Tab`** | Focus cycle forward | `Tab` while modal focused | (gamepad has no Tab equivalent — uses ↑↓ instead) | Focus indicator moves to next button | Cycles `Continue` ↔ `GoToSettings`; FocusTrap blocks escape from modal |
| **`Shift+Tab`** | Focus cycle backward | `Shift+Tab` | (n/a — gamepad uses ↓ for backward in this 2-button cycle) | Focus indicator moves to previous button | Reverse of Tab cycle |
| **Mouse hover** (any button) | Hover | Mouse motion entering button rect | (n/a — gamepad uses focus, not hover) | Focus indicator (treated as focus per Godot Button default) | None |

**No long-press / no hold-to-confirm**: Per the medical-advisory register, single-press activation only. No "hold for 2 seconds to confirm" pattern.

**No drag / no swipe**: No draggable elements. Touch is out of scope.

**No keyboard shortcuts beyond Tab + Enter + Esc**: This modal does NOT respond to letter keys (e.g., `C` for Continue, `S` for Settings). The locked button labels are localized; letter-key shortcuts would not work cross-locale and are not part of CR-18.

**Held-key flush note**: When the modal mounts (cold boot OR CR-24 review), held-action input from the prior context (Main Menu in boot, Settings panel in review) does not auto-activate the focused button. Per the `held-key-flush-after-rebind` pattern applied to context transitions (per main-menu.md Section E note), held `ui_accept` is flushed before modal becomes interactive.

**Cross-references**: `unhandled-input-dismiss` (ADR-0004 §97), `set-handled-before-pop` (every dismiss), `dual-focus-dismiss` (review-mode exit only — boot path explicitly violates this for safety), `modal-scaffold` (focus trap), `input-context-stack` (push/pop discipline).

---

## Events Fired

Per ADR-0002, this modal — like its parent Menu System — is **subscribe-only** in MVP. Player actions trigger events from `SettingsService` (the dismiss-flag write fires `setting_changed`); the modal itself authors no Signal Bus signals.

| Player Action | Event Fired | Payload | Owner |
|---|---|---|---|
| `[Continue]` activated, `dismiss_warning()` returns `true` | `Events.setting_changed("accessibility", "photosensitivity_warning_dismissed", true)` | `category: "accessibility"`, `name: "photosensitivity_warning_dismissed"`, `value: true` | SettingsService (NOT this modal) |
| `[Continue]` activated, `dismiss_warning()` returns `false` | None — failure does not emit `setting_changed` (Settings GDD CR-9 rule: emit on successful write only) | n/a | n/a |
| `[Go to Settings]` activated, `dismiss_warning()` returns `true` | Same as `[Continue]`: `setting_changed("accessibility", "photosensitivity_warning_dismissed", true)` PLUS Settings panel mounts (Settings owns its own InputContext push, no separate event) | per Settings GDD §G.2 | SettingsService (NOT this modal) |
| `[Go to Settings]` activated, `dismiss_warning()` returns `false` | None — same as `[Continue]` failure path | n/a | n/a |
| CR-24 review-mode `[Continue]` or `[Go to Settings]` | None — `dismiss_warning()` not called in review path; flag stays `true`; no event fires | n/a | n/a |
| `ui_cancel` in boot path | None — event consumed and ignored | n/a | n/a |
| `ui_cancel` in CR-24 review path | None — modal dismisses but no event fires | n/a | n/a |

**Subscriptions** (this modal is a receiver, not emitter):

- `NOTIFICATION_TRANSLATION_CHANGED` — handled by Label children for re-translate; modal root re-resolves AccessKit `accessibility_name` / `accessibility_description` via `accessibility-name-re-resolve` pattern.
- `setting_changed("graphics", "ui_scale", value)` — only relevant in CR-24 review mode (since boot path can't change ui_scale without leaving the modal first); modal layout reflows on receipt.

**Analytics events**: OUT OF SCOPE for MVP. If analytics ship in Polish, instrumentation candidates: modal mount (count first-launches), `[Continue]` activate vs `[Go to Settings]` activate ratio (informs UX optimization), disk-full failure rate (operational health metric). No PII.

---

## Transitions & Animations

**Pillar 5 carve-out applies**: this modal is non-diegetic, so the Case File-register paper-shuffle / typewriter-clack / rubber-stamp SFX do NOT fire on its interactions. The audio register here is the system bus default (or silence) — see Open Question #3.

**Modal enter**:

| Trigger | Animation | Reduced-motion variant |
|---|---|---|
| `ModalScaffold.show_modal(PhotosensitivityWarningContent)` (boot path) | None — modal snaps in instantly. AccessKit assertive announce fires within 1 frame; backdrop dim appears in same frame as modal card | Identical (already snap) |
| `ModalScaffold.show_modal(...)` (CR-24 review path) | Same as boot path — instant snap | Identical |

**Modal exit**:

| Trigger | Animation |
|---|---|
| `[Continue]` activated, `dismiss_warning()` returns `true` | None — modal snaps out. `Context.MODAL` pops; backdrop dim removed in same frame |
| `[Go to Settings]` activated, `dismiss_warning()` returns `true` | Modal snaps out; Settings panel snaps in (separate transition owned by Settings) |
| CR-24 review-mode dismiss (Continue / Go to Settings / `ui_cancel` / mouse-click-outside) | Modal snaps out; focus restored to Settings `[Show Photosensitivity Notice]` button (no animation on focus restore) |

**In-modal state-change animations**:

| State change | Animation | Reduced-motion variant |
|---|---|---|
| Button focus change (Tab / D-pad) | Hard snap — focus indicator border appears/disappears in 1 frame | Identical |
| Button activate | Hard snap fill-invert for 1 frame | Identical |
| Z4 `FailureFeedbackLabel` reveal (after `dismiss_warning()` returns `false`) | Hard snap — Z4 visible from `false` to `true`; modal grows ~30 px taller in same frame; AT announces failure feedback via `accessibility_live = "polite"` | Identical |
| Z4 hide (after successful retry) | Hard snap — Z4 hides; modal shrinks back to default height | Identical |
| Locale change re-render | All Labels re-translate in the same frame as `NOTIFICATION_TRANSLATION_CHANGED` receipt | Identical |
| ui_scale reflow | Layout reflows on next layout pass; may be 1-frame visual pop (acceptable, ui_scale changes are infrequent) | Identical |

**Audio register**:

The non-diegetic Pillar 5 carve-out means Main Menu's typewriter-clack / paper-shuffle SFX do NOT fire on this modal's interactions. Two options were considered:

1. **Silence** (recommended for medical-advisory register): no SFX on focus, activate, mount, dismiss. The modal is quiet; the player's reading is uninterrupted by audio.
2. **System default UI bus SFX**: a generic click/confirm SFX from the project's default UI sound palette (no period flavor). Distinguishes interactions from Main Menu's flavored SFX while maintaining minimal feedback.

Decision: **Silence** for MVP. The medical-advisory register doesn't benefit from confirm SFX; AT users already get audio via screen reader announcement; sighted players have visual feedback. Flag as Open Question #3 if playtest reveals players don't realize their button press registered.

**Vestibular-safety claim**: All animations are hard cuts. No tween, no parallax, no color flicker, no rotation. The modal that warns about flashes is itself flash-free. ✓ Vestibular-safe by design.

---

## Data Requirements

This modal is **read-only** — it owns no persistent state, calls `SettingsService.dismiss_warning()` to trigger the write but does not perform the write itself.

| Data | Source System | Read / Write | Real-time? | Notes |
|---|---|---|---|---|
| `_boot_warning_pending: bool` | `SettingsService` autoload (Settings GDD CR-18) | (Read by Main Menu, NOT by this modal) | n/a | Main Menu polls this in `_ready()` to decide whether to mount this modal at all. The modal itself never reads it. |
| `dismiss_warning() -> bool` return | `SettingsService.dismiss_warning()` API | Read (via call) | Push (call returns true/false) | Synchronous call. On `true`: modal proceeds with dismiss path. On `false`: Z4 `FailureFeedbackLabel` becomes visible. AC-MENU-6.4 mandates this two-branch handling. |
| `open_panel(pre_navigate: StringName)` call | `SettingsService.open_panel()` API | Call (no return value used) | n/a | Called only from `[Go to Settings]` button after successful `dismiss_warning()`. Pre-navigation target: `"accessibility.damage_flash_enabled"` per CR-18. |
| Locale (current `TranslationServer.get_locale()`) | `TranslationServer` (Godot built-in) | Read | Push via `NOTIFICATION_TRANSLATION_CHANGED` | Triggers re-render of all Label text in modal + AccessKit `accessibility_name` re-resolve. |
| `ui_scale` (75–150%) | `SettingsService` (Settings G.3) → applied to `Window.content_scale_factor` | Read | Push via `setting_changed` (rare for this modal — see Section D) | Layout reflows on next pass. |
| Active language string table (for label display) | `TranslationServer` + `*.po` files in `assets/locale/[locale]/` | Read | Push via `NOTIFICATION_TRANSLATION_CHANGED` | All Labels use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. The 5 string keys: `SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE`, `SETTINGS_PHOTOSENSITIVITY_BODY` (38-word locked copy), `SETTINGS_PHOTOSENSITIVITY_CONTINUE`, `SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS`, `SETTINGS_PHOTOSENSITIVITY_DISMISS_FAILED`. |

**Writes performed by this modal**: NONE. The dismissed-flag write is performed by `SettingsService.dismiss_warning()`, not by this modal directly. The modal calls the API; SettingsService owns the persistence. This separation is load-bearing: the modal cannot accidentally bypass Settings' validation or burst-emit logic.

**Architectural concerns flagged**:

1. **Locked body copy must survive middleware unchanged**. The 38-word CR-18 copy is calibrated for cognitive accessibility and medical-advisory clarity. Translation pipelines, string-extract tools, and CI checks must NOT line-break, hyphenate, or apply word-wrap heuristics that change semantic content. The locale-specific translations may differ in word count (German tends to expand, Japanese tends to compact) but each translation is independently locked once approved. Flag for translator-brief: `SETTINGS_PHOTOSENSITIVITY_BODY` is a **locked-content key** — translators must signoff on the final wording per locale, not iterate without review.
2. **`dismiss_warning()` MUST return a bool, not throw**. AC-MENU-6.4 specifies disk-full failure as a `false` return, NOT an exception. Settings GDD CR-9 confirms the synchronous API contract. If the implementation throws, this modal's failure-handling branch never fires and the player sees an uncaught error — a critical safety regression.
3. **`SettingsService` autoload ordering**. This modal mounts during `MainMenu._ready()`, which runs after all autoload `_ready()` calls per ADR-0007. So `SettingsService` is guaranteed available when the modal needs to call `dismiss_warning()`. If ADR-0007 is amended to reorder, validate this assumption.
4. **`open_panel(pre_navigate:)` parameter contract**. The pre-navigation key string format (`"accessibility.damage_flash_enabled"`) is invented in CR-18 and not yet formally specified by Settings GDD. If Settings adopts a different key-path format (e.g., dotted-namespace vs StringName-array), this modal's `[Go to Settings]` button needs to follow. Flag for Settings GDD amendment review.

**No PII / no secret data**: All data this modal reads is local-only. No network calls. No telemetry beacons in MVP.

---

## Accessibility

**Committed tier**: **Standard** (project default) + **project-elevated to safety-critical Basic+** for this modal specifically (per `accessibility-requirements.md`: "Photosensitivity boot-warning modal — exceeds Basic; required because Cutscenes CT-03 contains a single-frame chromatic flash and op-art rapid letterbox slide-in"). This modal exists explicitly to serve accessibility users.

**Keyboard-only navigation path** [Day-1 MVP]:

```
  Modal mounted → focus lands on [Continue]  ← default focus per CR-18
    ↓ Tab
  [Go to Settings]
    ↓ Tab → wraps to [Continue]
  (Shift+Tab cycles backward; FocusTrap blocks escape from modal)
```

100% of interactive elements reachable via Tab + Enter. No mouse-only interactions. No hover-only secondary affordances.

**Modal focus trap** [Day-1 MVP, BLOCKING]:

When this modal is active, focus cannot escape via Tab. The two focusable buttons are the only Tab targets. `ui_cancel` does NOT release focus in boot path (AC-MENU-6.2). Per `modal-scaffold` pattern §spec.

**AccessKit per-Control table** [Day-1 MVP per ADR-0004 IG10]:

| Component | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| Modal root (`PhotosensitivityWarningContent`) | `"dialog"` per AC-MENU-6.1 | `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE")` ("Photosensitivity Notice") | (none — dialog name is the title) | `"assertive"` one-shot on mount, then `"off"` next frame via `call_deferred` per CR-21 + AC-MENU-6.5 |
| `BodyLabel` (Z2) | `"text"` (default Label role) | (none — text content is announced as-is) | (none) | `"off"` (text is announced via parent dialog's assertive announce — Body content is part of the dialog's content per WAI-ARIA dialog spec) |
| `ContinueButton` (Z3, default focus) | `"button"` | "Continue" (per `tr("SETTINGS_PHOTOSENSITIVITY_CONTINUE")`) | `tr("SETTINGS_PHOTOSENSITIVITY_CONTINUE_DESC")` ("Acknowledge the notice and proceed to the main menu.") — explicit description because "Continue" is a generic verb that benefits from context for AT users | `"off"` |
| `GoToSettingsButton` (Z3) | `"button"` | "Go to Settings" (per `tr("SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS")`) | `tr("SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS_DESC")` ("Acknowledge the notice and open the accessibility settings to adjust flash intensity.") | `"off"` |
| `FailureFeedbackLabel` (Z4, conditional) | `"alert"` (per WAI-ARIA `role="alert"` semantics — hidden until shown, then announced) | (text content) | (none) | `"polite"` — announces without interrupting the user's current focus state per `inline-action-failure-feedback` NEW pattern candidate |

All `accessibility_name` and `accessibility_description` values resolve via `auto-translate-always` and re-resolve on `NOTIFICATION_TRANSLATION_CHANGED` per `accessibility-name-re-resolve` pattern.

**Live regions**:

| Trigger | Live region behavior | AT outcome |
|---|---|---|
| Modal mount (boot path) | Modal root `accessibility_live = "assertive"` for one frame | Screen reader announces dialog title + body content immediately, interrupting any prior announcement (this is the safety-critical announce — players cannot miss it) |
| Modal mount (CR-24 review) | Same as boot path | AT-aware players who initiate review still get the assertive announce — gives them confidence the modal opened |
| `[Continue]` activated, success | (none — modal dismisses; no announce needed) | n/a |
| `[Continue]` activated, disk-full failure | `FailureFeedbackLabel` becomes visible with `accessibility_live = "polite"` | AT announces "Could not save your acknowledgment..." after the user finishes whatever they were doing (e.g., reading another button) — does not interrupt |
| Locale change re-render | (none — labels swap silently; AT re-announces on next focus change) | AT-aware players can re-trigger announce by Shift+Tab → Tab |

**Text contrast** [Standard tier — WCAG 2.1 AA, project-elevated to AAA where reasonable]:

| Element | Foreground | Background | Contrast ratio | Status |
|---|---|---|---|---|
| Title (`TitleLabel`) | BQA Blue `#1B3A6B` | Parchment `#E8DCC4` modal frame | ≥ 7:1 estimate | Designed (verify with `tools/ci/contrast_check.sh` once available) |
| Body (`BodyLabel`, 18 px) | Ink Black `#1A1A1A` | Parchment `#E8DCC4` | ≥ 12:1 | Designed (very high contrast — body is the load-bearing content) |
| Button label (default state) | Parchment `#E8DCC4` | BQA Blue `#1B3A6B` | ≥ 7:1 | Same as Main Menu buttons |
| Button label (focus state — inverted) | BQA Blue `#1B3A6B` | Parchment `#E8DCC4` | ≥ 7:1 | Designed |
| Failure feedback (`FailureFeedbackLabel`, 14 px italic) | Ink Black `#1A1A1A` | Parchment `#E8DCC4` | ≥ 12:1 | Designed |
| Title rule + Button-row rule (1 px) | Ink Black at 30% opacity | Parchment `#E8DCC4` | ~3:1 (decorative; below SC 1.4.3 threshold) | Decorative only — flag in Open Question per main-menu.md precedent (build stamp), but visual rules are auxiliary |
| Backdrop dim over Main Menu BQA Blue | (no foreground; backdrop is decorative) | n/a | n/a | Decorative |

**Minimum text sizes** [per `accessibility-requirements.md`]:

- Title: 22 px (above the 24 px menu UI floor — flag: TitleLabel may need to be bumped to 24 px to match the floor; OR classify as decorative per art-bible §7B; **Open Question #4**).
- Body: 18 px (matches HUD floor and Cutscenes Mission Card body; below the 24 px menu UI floor — but body content is reading-oriented prose, distinct from menu chrome; OK per cognitive accessibility rationale).
- Button labels: 24 px (at the menu UI floor; unambiguous).
- Failure feedback: 14 px italic (decorative; per main-menu.md precedent for footer/auxiliary text — Open Question #5).

**Color-independent communication**:

Modal mounting is signaled by **layout** (modal card appears centered) + **focus** (Continue button gets focus indicator) + **AccessKit** (assertive announce). No color-only signal. ✓ Color-blind safe.

Failure state is signaled by **text** (FailureFeedbackLabel) + **layout** (modal grows taller) + **AccessKit** (polite announce). No red color, no error-icon (the locked design doesn't use color-coded severity). ✓ Color-blind safe.

**Screen flash / strobe / photosensitivity**:

The photosensitivity warning modal itself contains **zero flashing content, zero rapid color change, zero animation that could cause photosensitive harm**. The modal that warns about flashes does not itself flash. Backdrop dim appears in 1 frame (snap, not pulse). Focus indicator snaps. Button activate is 1-frame snap-invert. None of these meet WCAG 2.3.1 thresholds. ✓ Photosensitivity-safe by design.

**Motion / vestibular accessibility**:

All Main Menu animations on this modal are hard cuts (per Section E3). `reduced_motion` setting does not need to alter rendering. ✓ Vestibular-safe by design.

**Motor accessibility**:

- No timed inputs on this modal — modal does NOT auto-dismiss (per CR-18 "Modal does not auto-dismiss"). Players have unlimited time to read.
- Single-press activation (no hold-to-confirm).
- Hit-target floor: 280 × 56 px buttons at 100% ui_scale (well above WCAG SC 2.5.5 44 × 44 floor).
- No mouse-precision required — buttons are large rectangular targets.

**Cognitive accessibility**:

- Modal has **2 buttons** (well below cognitive-load thresholds).
- Body copy is **38 words** — calibrated for short, scannable reading.
- No jargon — plain medical-advisory English ("flashing images", "flash intensity", "Settings → Accessibility").
- **No time pressure** to read or decide — modal stays open until acknowledged.
- Same dismiss path on every entry (Continue or Go to Settings — invariant).

**Out of scope for this spec** (committed elsewhere or deferred):

- Audio description of the warning content for blind players who can't read text via screen reader: covered by `accessibility_role = "dialog"` + assertive announce — screen reader reads the body text aloud automatically. No separate audio file needed.
- Translation to all locales: MVP ships English only; FR + DE at VS per accessibility-requirements.md commitment.
- Letter-key shortcuts (e.g., `C` for Continue): per Section E "no keyboard shortcuts beyond Tab + Enter + Esc" — not in MVP scope.

---

## Localization Considerations

**Locale targets**: English (MVP — only locale at MVP), French (FR-fr) and German (DE-de) at VS per accessibility-requirements.md commitment. Per CR-18 the body copy is **locked content** — translators must sign off on the final wording per locale, not iterate without review.

**String inventory**:

| Key | English source | EN char count | Layout budget @ 100% ui_scale | 40% expansion target | Status |
|---|---|---|---|---|---|
| `SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE` | "Photosensitivity Notice" | 23 | ~50 chars (Z1 title bar at 22 px Futura/DIN bold) | ≤ 32 | ✓ likely fits FR ("Avis de photosensibilité" ~24 chars) and DE ("Hinweis zur Photosensibilität" ~30 chars) |
| `SETTINGS_PHOTOSENSITIVITY_BODY` | "This game contains flashing images, including rapid screen flashes during combat. You can reduce flash intensity in Settings → Accessibility, or disable it entirely. This notice can be reviewed again at any time from the Settings menu." | 234 | ≤ 5 lines @ 18 px in 880 × 280 px modal (~80 chars per line × 5 lines = ~400 chars hard cap) | ≤ 328 | ⚠ FR + DE typical 30–40% expansion → ~300–325 chars; fits the 5-line cap but flag for QA verification per locale |
| `SETTINGS_PHOTOSENSITIVITY_CONTINUE` | "Continue" | 8 | ~20 chars (button label) | ≤ 12 | ✓ FR "Continuer" 9 chars / DE "Weiter" 6 chars — both fit |
| `SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS` | "Go to Settings" | 14 | ~20 chars | ≤ 20 | ⚠ FR "Aller aux paramètres" ~20 chars / DE "Zu den Einstellungen" ~21 chars — both AT or slightly OVER budget. **Open Question #6**: shorten FR to "Paramètres" (10 chars) and DE to "Einstellungen" (13 chars) at translator-brief stage, OR widen the button to 320 px |
| `SETTINGS_PHOTOSENSITIVITY_CONTINUE_DESC` | "Acknowledge the notice and proceed to the main menu." | 53 | unbounded (AccessKit description, AT-only — not visible) | unbounded | ✓ all locales fit |
| `SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS_DESC` | "Acknowledge the notice and open the accessibility settings to adjust flash intensity." | 87 | unbounded (AT-only) | unbounded | ✓ |
| `SETTINGS_PHOTOSENSITIVITY_DISMISS_FAILED` | "Could not save your acknowledgment. Please try again or check disk space." | 73 | ~80 chars × 1 line @ 14 px italic in Z4 | ≤ 102 | ⚠ FR "Échec de l'enregistrement de votre acceptation. Veuillez réessayer ou vérifier l'espace disque." ~98 chars — fits but tight |

**Layout-critical elements**:

| Element | Why critical | Mitigation if FR/DE overflows |
|---|---|---|
| Body copy 5-line cap | menu-system.md AC-MENU-6.6 specifies `Label.get_line_count() ≤ 5` for the body. Exceeding this means the locale needs translator revision. | Per AC-MENU-6.6 the original GDD specifies font scale-down (11 px → 10 px per char range). **This UX spec rejects font scale-down** — 11 px falls below accessibility-requirements.md minimum text size for menu UI (24 px) and Mission Card body (18 px). **Open Question #7**: amend AC-MENU-6.6 to keep 18 px body and instead allow modal height to grow per locale (default 280 px → up to ~340 px to accommodate 5–6 lines without font shrinkage). |
| Button width parity | Both `[Continue]` and `[Go to Settings]` should be visually similar width. Big disparity reads as awkward. | Width = max of the two labels' rendered width per locale. If a locale makes them very different, use a shared min-width derived from the longer label. |
| Failure feedback width | `FailureFeedbackLabel` at 14 px italic must fit in 1 line within Z2 width (~~~80 chars at 14 px). | If FR/DE pushes past 80 chars, allow 2-line wrap (modal grows another 20 px tall). Don't shrink the font. |

**Locale-specific formatting**:

| Element | Formatting | MVP/VS |
|---|---|---|
| "Settings → Accessibility" arrow in body copy | The `→` Unicode character (U+2192) is locale-invariant. Keep as `→`. Translators may rephrase the path expression but should keep the arrow notation. | MVP English; VS FR/DE |
| Numerical values | None in this modal (no flash count, no duration shown to player). | n/a |

**What this modal does NOT localize**:

- The backdrop dim color / opacity (visual primitive)
- The Eiffel Tower silhouette behind the modal (decorative — though it's not part of this modal's scope, it's the Main Menu rendered underneath)
- Audio cues (none fire on this modal per Section E3 silence decision)

**RTL (right-to-left) support**: OUT OF SCOPE for MVP and VS (Arabic / Hebrew not planned). Post-launch evaluation. The button row would mirror — `[Continue]` leftmost, `[Go to Settings]` rightmost — per Godot `Control.layout_direction`.

**Translator brief priority items**:

1. **`SETTINGS_PHOTOSENSITIVITY_BODY`** — locked content. Each locale's translation must be approved by a native speaker who is also briefed on the medical-advisory register (factual, plain, not alarming). Translator MAY adjust word count for grammatical naturalness but the semantic content and tone must match: "this game has flashes; you can reduce them; you can disable them; you can review this later".
2. **`SETTINGS_PHOTOSENSITIVITY_GO_TO_SETTINGS`** — short forms preferred ("Paramètres", "Einstellungen") over long forms ("Aller aux paramètres", "Zu den Einstellungen") when button width is constrained.
3. **No scare-language** — the modal must NOT translate "flashing images" as alarming euphemisms ("dangerous lights", "harmful flashes"). Keep clinical-factual register.
4. **"Settings → Accessibility" path notation** — keep the `→` arrow. Translators may rephrase the surrounding prose but the arrow notation is consistent across locales.

---

## Acceptance Criteria

UX spec ACs verify UX-specific outcomes; many cross-reference `menu-system.md` H.6 (AC-MENU-6.1 through 6.6) and `settings-accessibility.md` AC-SA-11.x.

**Format**: GIVEN/WHEN/THEN with story type tags `[Logic]` / `[Integration]` / `[UI]` / `[Visual]` and gate level `[BLOCKING]` / `[ADVISORY]`.

### Modal Mount & Default State

- **AC-PSBW-1.1 [Visual] [BLOCKING]** GIVEN a fresh `settings.cfg`-absent state on cold boot, WHEN the modal mounts via `MainMenu._ready()`, THEN: (a) modal card is centered horizontally and vertically at 1920 × 1080; (b) modal dimensions are 880 × 280 px ± 10 px; (c) backdrop dim covers full screen at Ink Black `#1A1A1A` 52% opacity; (d) Main Menu is visible underneath (no full grey-out); (e) Z1 title, Z2 body, Z3 buttons all rendered. Evidence: `production/qa/evidence/photosensitivity-mount-[date].png` + art-director sign-off.
- **AC-PSBW-1.2 [Logic] [BLOCKING]** GIVEN the modal mounted on cold boot, WHEN inspected within the same `_ready()` frame as the mount, THEN: (a) `ContinueButton.has_focus() == true`; (b) `Context.MODAL` on top of stack; (c) `accessibility_role` of modal root == `"dialog"` (per AC-MENU-6.1); (d) `accessibility_live` == `"assertive"`; (e) FocusTrap active (Tab cannot leave the 2-button cycle).
- **AC-PSBW-1.3 [Logic] [BLOCKING]** GIVEN the modal mounted, WHEN one frame elapses after mount, THEN modal root `accessibility_live == "off"` (one-shot pattern via `call_deferred` per CR-21).

### Body Copy Integrity

- **AC-PSBW-2.1 [Logic] [BLOCKING]** GIVEN the modal mounted in EN locale, WHEN `BodyLabel.text` is read, THEN it equals exactly the locked CR-18 38-word string verbatim — no character drift, no word substitution, no whitespace alteration. Verifies CR-18.
- **AC-PSBW-2.2 [UI] [BLOCKING — before any non-EN locale ships]** GIVEN the modal mounted in any locale, WHEN `BodyLabel.get_line_count()` is queried after layout, THEN result ≤ 5 lines. Verifies AC-MENU-6.6 line-count cap (with the 18 px font preserved per Open Question #7).
- **AC-PSBW-2.3 [Visual] [ADVISORY]** GIVEN the modal mounted with a screenshot taken, WHEN inspected, THEN body text is left-aligned, 18 px, Ink Black `#1A1A1A` on Parchment `#E8DCC4`, line-height ≈ 1.4×, with paragraph break between sentences 2 and 3.

### Dismiss Paths

- **AC-PSBW-3.1 [Logic] [BLOCKING]** GIVEN the modal mounted in boot path, WHEN `[Continue]` is activated AND `SettingsService.dismiss_warning()` returns `true`, THEN within one frame of the call returning: (a) `accessibility.photosensitivity_warning_dismissed == true` in `settings.cfg`; (b) `setting_changed("accessibility", "photosensitivity_warning_dismissed", true)` emitted; (c) `ModalScaffold.hide_modal()` called; (d) `Context.MODAL` popped; (e) focus restored to Main Menu's Continue button. Per AC-MENU-6.3.
- **AC-PSBW-3.2 [Logic] [BLOCKING]** GIVEN the modal mounted, WHEN `[Go to Settings]` is activated AND `dismiss_warning()` returns `true`, THEN: (a) dismissed-flag persisted same as AC-PSBW-3.1; (b) `hide_modal()` called; (c) `Context.MODAL` popped; (d) `SettingsService.open_panel(pre_navigate: "accessibility.damage_flash_enabled")` called; (e) `Context.SETTINGS` pushed by Settings; (f) focus on `damage_flash_enabled` toggle in Settings panel.
- **AC-PSBW-3.3 [Logic] [BLOCKING]** GIVEN the modal mounted, WHEN `[Continue]` is activated AND `dismiss_warning()` returns `false` (disk-full), THEN: (a) modal stays open (`Context.MODAL` still on stack); (b) Z4 `FailureFeedbackLabel` becomes visible; (c) buttons retain `process_input == true`; (d) modal grows ~30 px taller; (e) AT announces failure feedback via `accessibility_live == "polite"`. Per AC-MENU-6.4.
- **AC-PSBW-3.4 [Logic] [BLOCKING]** GIVEN the disk-full failure state from AC-PSBW-3.3, WHEN `[Continue]` is activated again AND `dismiss_warning()` returns `true`, THEN: (a) Z4 hides; (b) modal proceeds with normal dismiss path per AC-PSBW-3.1; (c) Z4 visibility resets to hidden if modal is ever re-shown.

### Non-Dismissibility (Boot Path Safety)

- **AC-PSBW-4.1 [Logic] [BLOCKING]** GIVEN the modal mounted in boot path AND `Context.MODAL` on stack, WHEN `ui_cancel` (Esc / B button) is pressed, THEN: (a) event is consumed; (b) modal stays open; (c) `hide_modal()` is NOT called; (d) `Context.MODAL` stays on stack; (e) no SFX plays; (f) `dismiss_warning()` is NOT called. Per AC-MENU-6.2.
- **AC-PSBW-4.2 [Logic] [BLOCKING]** GIVEN the modal mounted in boot path, WHEN mouse-click occurs on `BackdropDim` outside modal rect, THEN event is consumed and modal stays open (same outcome as AC-PSBW-4.1). The `dual-focus-dismiss` pattern is intentionally violated for this surface in boot path.

### CR-24 Review Path

- **AC-PSBW-5.1 [Logic] [BLOCKING]** GIVEN dismissed-flag is `true` AND player presses Settings → Accessibility → `[Show Photosensitivity Notice]` button, WHEN modal mounts, THEN: (a) modal is visually identical to boot path mount (per AC-PSBW-1.1); (b) `dismissed-flag` value remains `true` (NOT reset); (c) `Context.MODAL` pushed.
- **AC-PSBW-5.2 [Logic] [BLOCKING]** GIVEN modal mounted in CR-24 review path, WHEN `[Continue]` OR `[Go to Settings]` activated, THEN: (a) `dismiss_warning()` is NOT called (flag is already `true`); (b) `hide_modal()` called; (c) `Context.MODAL` popped; (d) focus restored to `[Show Photosensitivity Notice]` button in Settings panel (NOT to Main Menu).
- **AC-PSBW-5.3 [Logic] [BLOCKING]** GIVEN modal mounted in CR-24 review path, WHEN `ui_cancel` OR mouse-click-outside occurs, THEN modal dismisses (review-mode exception per Section B3). Outcome same as AC-PSBW-5.2 dismiss path.

### Performance

- **AC-PSBW-6.1 [Integration] [BLOCKING]** GIVEN cold boot on minimum-target hardware, WHEN measured from `MainMenu._ready()` start to first frame where modal is mounted AND `accessibility_live == "assertive"` is set, THEN elapsed time < 100 ms. (Modal mount is synchronous and should not delay boot perceptibly.)
- **AC-PSBW-6.2 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN `[Continue]` activated AND `dismiss_warning()` returns synchronously, THEN total elapsed time from button-press to `hide_modal()` return ≤ 50 ms (excluding disk-write latency, which is captured separately by AC-PSBW-3.3 disk-full path).

### Accessibility

- **AC-PSBW-7.1 [Integration] [BLOCKING]** GIVEN modal mounted, WHEN AccessKit tree queried, THEN every interactive Control (`ContinueButton`, `GoToSettingsButton`) has non-empty `accessibility_role`, `accessibility_name`, AND `accessibility_description`. Modal root has `accessibility_role == "dialog"`. Verifies Day-1 MVP per ADR-0004 IG10.
- **AC-PSBW-7.2 [Integration] [BLOCKING]** GIVEN modal mounted with screen reader active, WHEN modal first appears, THEN AT announces dialog title + body content within 1 second of mount. Manual walkthrough doc filed at `production/qa/evidence/photosensitivity-at-walkthrough-[date].md`. Verifies AC-MENU-6.5.
- **AC-PSBW-7.3 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN Tab is pressed twice in succession from default focus, THEN focus moves Continue → GoToSettings → Continue (wraps; FocusTrap holds).
- **AC-PSBW-7.4 [Logic] [BLOCKING]** GIVEN modal in disk-full failure state, WHEN AccessKit `accessibility_live` is read on `FailureFeedbackLabel`, THEN value == `"polite"` (NOT `"assertive"` — failure feedback should not interrupt the user).
- **AC-PSBW-7.5 [Logic] [BLOCKING]** GIVEN modal at 100% ui_scale, WHEN button rect is inspected, THEN width × height ≥ 280 × 56 px (above WCAG SC 2.5.5 floor of 44 × 44).
- **AC-PSBW-7.6 [Logic] [BLOCKING]** GIVEN body label rendered with WCAG contrast formula applied, WHEN sampled, THEN ratio between body text Ink Black and Parchment background ≥ 7:1 (project-elevated to AAA for safety-critical content).
- **AC-PSBW-7.7 [Logic] [BLOCKING]** GIVEN `Settings.reduced_motion == true`, WHEN modal mounts and dismisses, THEN no animation behaves differently than `reduced_motion == false` — the modal is fully snap-cut by design (vestibular-safe claim).

### Localization

- **AC-PSBW-8.1 [Integration] [BLOCKING — before any non-EN locale ships]** GIVEN modal mounted, WHEN locale is changed via Settings → dismissed → modal re-rendered (CR-24 path), THEN: (a) `NOTIFICATION_TRANSLATION_CHANGED` propagates within 1 frame; (b) all Label `text` re-resolves to new-locale strings; (c) AccessKit `accessibility_name` and `accessibility_description` re-resolve.
- **AC-PSBW-8.2 [UI] [BLOCKING — before any non-EN locale ships]** GIVEN modal mounted in FR locale at 100% ui_scale, WHEN button rects are inspected, THEN no button label clips outside its rect AND no Label exceeds 1 line per button.

### State Invariants

- **AC-PSBW-9.1 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN ANY state observed (Default, Disk-Full, Pending Dismiss, Locale Changed, ui_scale Changed, CR-24 Review), THEN `Context.MODAL` is on top of `Context` stack throughout the modal's lifetime; popped only on `hide_modal()`.
- **AC-PSBW-9.2 [Logic] [BLOCKING]** GIVEN modal mounted in boot path, WHEN dismiss_warning() returns `true` and modal dismisses, THEN: (a) `Context.MENU` is now on top of stack; (b) Main Menu buttons have `process_input == true` (per AC-MENU-6.3.e).

**Total**: 22 UX-specific ACs (3 Mount/Default + 3 Body Copy + 4 Dismiss + 2 Non-Dismissibility + 3 CR-24 Review + 2 Performance + 7 Accessibility + 2 Localization + 2 State Invariants). Cross-references to GDD ACs noted where this spec narrows scope.

---

## Open Questions

All Open Questions raised throughout this spec, consolidated.

| # | Question | Where raised | Owner | Recommended resolution | Decision needed by |
|---|---|---|---|---|---|
| **1** | Should the modal include a warning icon (⚠ or accessibility symbol) at top-left of Z1, in addition to the text title? | Section C.1 (Information Hierarchy) | ux-designer + accessibility-specialist | **Recommended: NO icon for MVP.** The Stage Manager register favors plain factual prose. If MVP playtest shows ≥30% of players dismiss without reading (low-engagement signal), add a small accessibility icon in patch 1. | First MVP playtest report |
| **2** | Should the disk-full failure feedback render as inline text in Z4 (per current spec), as a status-bar-style message below the modal, or as a second modal on top? | Section C.1 + C.3 | ux-designer | **Recommended: Z4 inline (current spec).** A second modal would violate menu-system.md C.4 depth-1 queue. A status bar reads as too gameplay-y for a non-diegetic dialog. Z4 inline keeps the modal coherent and AT-discoverable via `accessibility_live = "polite"`. | Before MVP sprint kickoff |
| **3** | Audio register for this modal — silence (current spec), system-default UI click, or Pillar 5 typewriter SFX (rejected by carve-out)? | Section E3 | sound-designer + ux-designer + accessibility-specialist | **Recommended: silence (current spec).** Re-evaluate after MVP playtest if ≥1 playtester reports "I clicked but nothing seemed to happen". | First MVP playtest |
| **4** | TitleLabel at 22 px is BELOW the menu UI floor of 24 px from `accessibility-requirements.md`. Bump to 24 px, OR classify as decorative per art-bible §7B? | Section G (Min text sizes) | accessibility-specialist + art-director | **Recommended: bump to 24 px** (matches the floor; visual difference is negligible; removes ambiguity). | Before MVP implementation |
| **5** | FailureFeedbackLabel at 14 px italic is BELOW SC 1.4.4 floor. Classify as decorative (matches main-menu.md build stamp precedent), or raise to 16 px? | Section G | accessibility-specialist | **Recommended: raise to 16 px** (closer to floor; still visually distinct from 18 px body via italic styling). The error message is informational (not decorative) since it instructs the player to act ("Please try again or check disk space"). | Before MVP implementation |
| **6** | FR + DE translations of `[Go to Settings]` (~20–21 chars) potentially overflow the 280 px button budget at 100% ui_scale. Shorten translations to "Paramètres" / "Einstellungen", or widen the button to 320 px? | Section H (string inventory + layout-critical) | localization-lead + ux-designer | **Recommended: shorten translations** at translator-brief stage. Avoid asymmetric button widths. | Before FR/DE locale ships |
| **7** | menu-system.md AC-MENU-6.6 specifies font scale-down (11 px → 10 px) for non-EN locales whose body exceeds 5-line cap. **This conflicts with `accessibility-requirements.md` minimum text size** (24 px menu UI / 18 px Mission Card body). | Section H (layout-critical) | accessibility-specialist + game-designer (menu-system.md owner) | **Recommended: amend AC-MENU-6.6** to keep 18 px body and instead allow modal height to grow per locale (default 280 px → up to ~340 px). Reject font scale-down. | **BLOCKING** — must resolve before any non-EN locale ships. Flag back to menu-system.md GDD for amendment. |
| **8** | menu-system.md uses "Acknowledge" as the button label in AC-MENU-6.3 / 6.5. settings-accessibility.md CR-18 (authoritative) locks "Continue". Which label ships? | Header "Found inconsistency to flag" | game-designer (menu-system.md owner) + ux-designer | **Recommended: amend menu-system.md to use "Continue"** (the authoritative source). This UX spec uses "Continue" throughout. The AC-MENU-6.3 / 6.5 wording is inherited from an earlier draft and predates the locked CR-18 text. | Before MVP sprint kickoff |
| **9** | AC-MENU-6.6 permits `Label.get_line_count() ≤ 5` for the body. With Option B's 880 × 280 px modal at 18 px body, EN renders in ~3 lines; FR/DE may push to 4–5; very-long-locale (e.g., Japanese expanded gloss) could exceed 5. What happens when a locale exceeds 5 lines AND modal-height-grow per OQ #7 isn't enough? | Section H | localization-lead + ux-designer | **Recommended: per CR-18 locked-content rule, the locale needs translator revision before it ships.** CI gate fails the locale bundle. No silent runtime fallback. | Before any locale's CI bundle approval |
| **10** | `SettingsService.open_panel(pre_navigate: StringName)` parameter format ("accessibility.damage_flash_enabled") is invented in CR-18 but not formally specified by Settings GDD. Will Settings adopt this exact key-path syntax, or will it differ (e.g., `["accessibility", "damage_flash_enabled"]` array)? | Section F (Architectural concerns) | game-designer (Settings GDD owner) + ux-designer | **Recommended: lock as dotted string** (`"accessibility.damage_flash_enabled"`) per CR-18's text. Consistent with Settings GDD §C.2 category-key namespace which already uses dotted convention. Confirm in Settings GDD amendment. | Before MVP sprint kickoff |

**Cross-references**:
- OQ #6, #7, #9 feed `localization-scaffold.md` translator-brief work
- OQ #4, #5 feed `accessibility-requirements.md` Visual Accessibility table updates
- OQ #7 (BLOCKING) requires menu-system.md AC-MENU-6.6 amendment
- OQ #8 requires menu-system.md AC-MENU-6.3 / 6.5 amendment
- OQ #10 requires settings-accessibility.md amendment
