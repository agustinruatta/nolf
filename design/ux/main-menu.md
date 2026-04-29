# UX Spec: Main Menu

> **Status**: In Design
> **Author**: user (agustin.ruatta@vdx.tv) + ux-designer
> **Last Updated**: 2026-04-28
> **Journey Phase(s)**: Cold Boot (first impression) / Re-Entry (between sessions) / Return-from-Mission (post-`Return to Registry`)
> **Implements Pillar**: Primary 5 (Period Authenticity Over Modernization); Supporting 1 (Comedy Without Punchlines), Supporting 3 (Stealth is Theatre, Not Punishment)
> **Phasing**: Per-element `[MVP]` / `[VS]` tags inherited from `design/gdd/menu-system.md` UI-3 priority list. **Day-1 MVP** = Continue (label-swap) / New Game (conditional) / Personnel File / Close File. **VS** = Operations Archive button + dossier-card backdrop + gamepad nav + fountain-pen cursor + mission title block.
> **Template**: UX Spec
> **Authoritative GDD**: `design/gdd/menu-system.md` (CR-1, CR-2, CR-5, CR-6, CR-7, CR-8, CR-9, CR-10, CR-16 [VS], CR-17 [VS])
> **Related Specs (planned)**: `design/ux/photosensitivity-boot-warning.md` (Day-1 MVP, blocks main menu interactivity), `design/ux/quit-confirm.md` (Day-1 MVP, modal pattern shared with 3 other modals), `design/ux/pause-menu.md` (VS), `design/ux/load-game-screen.md` (VS), `design/ux/save-failed-dialog.md` (VS)

---

## Purpose & Player Need

**Purpose**. The Main Menu is the player's first interactive surface on every cold boot and the only re-entry point between sessions. It serves four player goals — **resume an in-progress operation**, **begin a new operation**, **adjust personal settings**, **close the application** — and one register-setting goal: **establish the 1965 BQA Case File voice before a single frame of gameplay runs**, so the player learns within seconds that this game's tone is bureaucratic-neutral period-comedy, not modern game-launcher chrome.

**Player need on arrival**. The player arrives at this screen wanting to **act on Eve's behalf as her dispatcher** — to consult the file, then resume or open an operation. The screen must answer "what's my last save?" and "how do I get back in?" within two seconds of cold boot, without the player needing to read instructions. After the boot warning is acknowledged on first launch (separate spec), the screen must be silent and self-explanatory.

**Failure mode if the screen is missing or hard to use**. The player fails to locate their autosave (slot 0 is the player's primary continuity vehicle — losing visibility into it means losing trust that the game preserved their progress); the player accidentally overwrites an autosave when starting a new game (CR-6 mitigates this with a confirm modal — the UX must make the modal's destructive nature legible at a glance); the player misses the photosensitivity opt-out path (Settings entry-point must be discoverable, hence its `accessibility_description`); the period register fails to land on first impression and the player carries modern game-menu expectations into gameplay (Pillar 5 fails by Section 1).

**Single-sentence formulation**. *"The player arrives at this screen wanting to know whether their last operation is still on file, and how to either resume it, open a new one, adjust their kit, or close out for the day — staged as a 1965 dispatcher consulting a manila folder, not as a player navigating a modern game launcher."*

---

## Player Context on Arrival

**When the player first encounters this screen**. Cold boot is the only entry path on first launch (after the photosensitivity boot-warning modal is acknowledged, if pending — see CR-8 + separate spec). On every subsequent session, this is the screen the engine loads as `Main Scene` (CR-1). The same screen also receives the player on return from gameplay via the Pause Menu's `Return to Registry` action (CR-14, VS scope) and after dismissing the Quit-Confirm modal with Cancel.

**What the player was doing immediately before**:

| Arrival path | Immediately before | Emotional register |
|---|---|---|
| **Cold boot, first launch** | Player double-clicked the Steam shortcut; the Steam splash dismissed; engine booted | Curious, exploratory, slightly cautious (the photosensitivity modal landed first if `_boot_warning_pending` was true) |
| **Cold boot, returning player** | Player launched the game expecting to resume; engine booted directly into Main Menu (no boot warning if dismissed_flag persisted) | Anticipatory — wants to find Continue immediately |
| **Return to Registry, mid-mission** | Player pressed Esc, navigated Pause → `Return to Registry`, confirmed in modal | Deliberate exit (closing out for the day, switching saves, abandoning a botched run) |
| **Quit-Confirm dismissed** | Player pressed `Close File`, then `Continue Mission` (Cancel) on the modal | Re-engaging — already decided to keep playing |

**Emotional state design assumes**. **Contemplative** (per art-bible §2.7 "energy level: contemplative"). The player is not stressed — gameplay tension does not exist on this screen. The screen never adds pressure: no countdown timers, no autosave-progress indicators, no "3 unread messages" chrome, no "what's new" carousels. The screen is a desk surface — quiet, composed, willing to wait.

**Voluntary or sent-here**. Always voluntary. There is no path where the game involuntarily routes the player to this screen — even gameplay failure (`Failure & Respawn` system) sends the player to its own respawn surface, not the Main Menu. Return to Registry requires the player to confirm a destructive modal first. The Main Menu is something the player chose to be at.

**What the screen must NOT assume about player context**:

- The player is not necessarily a returning player on the boot we're rendering — slot 0 may be empty (first launch) or corrupted (rare) or occupied (most common after first session). The Continue button's CR-5 label-swap is the one place this matters; everywhere else the screen's behavior is identical regardless of save state.
- The player is not necessarily an English speaker — every static label uses `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (CR-22 + Localization GDD).
- The player is not necessarily using mouse + keyboard — gamepad navigation must reach every interactive element on this screen (`[VS]` scope per CR-17).
- The player is not necessarily sighted, fully-able-handed, or able to process flashing imagery — the photosensitivity boot-warning modal handles the latter; AccessKit role+name on every Control handles screen reader access (Day-1 MVP per `accessibility-requirements.md`).

---

## Navigation Position

**This screen is the application's boot scene.** It sits at the root of every navigation graph in the game — there is no parent screen above it (CR-1: `MainMenu.tscn` is set as Project Settings → Application → Run → Main Scene; the engine loads it directly on cold boot, with no `change_scene_to_file()` call).

**Position summary**:

```
[Engine boot] → MainMenu.tscn  ← (this screen)
                     │
                     ├── Photosensitivity boot-warning modal  (mounted as overlay if _boot_warning_pending == true)
                     ├── Settings panel  (mounted as CanvasLayer 10 overlay; owned by Settings system #23)
                     ├── New-Game-Overwrite modal  (mounted as ModalScaffold overlay, conditional per CR-6)
                     ├── Quit-Confirm modal  (mounted as ModalScaffold overlay)
                     ├── Save-Failed modal  (mounted as ModalScaffold overlay, signal-driven)
                     └── Operations Archive  [VS]  (mounted as overlay; navigates to load-game-screen)

[Engine boot] → MainMenu.tscn  ──────►  LevelStreaming  ──►  Section scene
                                         (NEW_GAME or LOAD_FROM_SAVE)
```

**Top-level vs context-dependent**: This screen is a **top-level destination** with **two arrival paths** — engine boot (always available) and `Pause Menu → Return to Registry` (only available mid-gameplay). It is never a deep-linked screen; the player cannot reach it from inside Settings or from inside any modal — those overlays return *to* this screen on dismiss, they don't navigate *to* it.

**Sibling-overlay model**: The Main Menu does not navigate *to* its modals; it *mounts* them as children. Settings, Quit-Confirm, New-Game-Overwrite, Save-Failed, and (VS) the Operations Archive are all overlays mounted on top of the live Main Menu scene tree, not separate scenes. The Main Menu remains visible underneath every overlay (per Pillar 5 Refusal 1: no translucent grey-out — the desk is always there).

**Exit destinations** (covered in detail in Entry & Exit Points): three terminal exits (`get_tree().quit()` via Close File; `LS.transition_to_section(NEW_GAME)`; `LS.transition_to_section(LOAD_FROM_SAVE)`) — all of which destroy the Main Menu scene tree.

---

## Entry & Exit Points

**Entry Sources** (every way the player can land on the active Main Menu surface):

| Entry Source | Trigger | Player carries this context | MVP/VS |
|---|---|---|---|
| **Engine cold boot** | OS launches the game → Godot loads `MainMenu.tscn` as Main Scene (CR-1) → autoloads `_ready()` cascade per ADR-0007 → `MainMenu._ready()` pushes `Context.MENU` and polls `_boot_warning_pending` | Whatever `SettingsService` autoload restored from `user://settings.cfg` (locale, ui_scale, accessibility flags); Continue button label-swap reflects whatever `SaveLoad.slot_metadata(0)` returns | MVP |
| **Return to Registry** (scene change from Pause Menu) | Player Pause → `Return to Registry` → confirms modal → `change_scene_to_file("res://scenes/MainMenu.tscn")` (CR-14) | Returning from a destroyed gameplay session; mid-mission progress lost unless saved; same context as cold boot from this point | VS |
| **Photosensitivity boot-warning dismiss** | Modal Acknowledge → `dismiss_warning()` → `hide_modal()` → focus restored to Continue / Begin Operation (CR-8) | First-launch only (or when warning re-shown via Settings opt-in); Main Menu was waiting underneath the modal with `process_input = false` | MVP |
| **Settings panel dismiss** | Settings Esc/Back → `Context.SETTINGS` pops → focus returns to Personnel File button (CR-7 + AC-MENU-5.2) | Settings may have changed locale, ui_scale, accessibility flags — Main Menu must re-render any text that depends on these; `accessibility-name-re-resolve` pattern handles locale switches via `NOTIFICATION_TRANSLATION_CHANGED` | MVP (Settings overlay infra) |
| **Modal dismiss (Quit-Confirm Cancel, New-Game-Overwrite Cancel, Save-Failed Abandon)** | `ModalScaffold.hide_modal()` → `Context.MODAL` pops → focus restored to originating button per modal contract | The Main Menu was waiting underneath; no state change beyond focus restoration | MVP (each modal individually [MVP]) |
| **Operations Archive dismiss** | Load Game grid Esc/Back → mount unwound → focus restored to Operations Archive button | No state change unless player loaded a slot (in which case it's not a dismiss — it's a transition_to_section exit, see Exit table) | VS |

**Exit Destinations** (every way the Main Menu surface stops being active):

| Exit Destination | Trigger | Notes |
|---|---|---|
| **`get_tree().quit()` → application terminates** | Close File button → Quit-Confirm modal → confirm `Close File` (CR-9) | One-way, irreversible (process exit). No save triggered automatically. `Context.MENU` popped before quit per AC-MENU-7.3. |
| **Section scene (LOAD_FROM_SAVE)** | Continue button → fade menu music → `SaveLoad.load_from_slot(0)` → `LS.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)` → register step-9 restore callback (CR-5 occupied path) | Destroys Main Menu scene tree. Slot 0 must be valid (state ≠ CORRUPT, non-null Dictionary). Returning to Main Menu requires Pause → Return to Registry. |
| **Section scene (LOAD_FROM_SAVE — slot N)** | Operations Archive → slot card activate → `SaveLoad.load_from_slot(N)` → same path as above (CR-11) | VS scope. Slot 0 cards in the grid use the same path; slots 1–7 are manual saves. |
| **Section scene (NEW_GAME)** | New Game / Begin Operation button → maybe-confirm-modal (CR-6) → fade menu music → push `Context.LOADING` → `LS.transition_to_section(first_section_id, null, NEW_GAME)` | Destroys Main Menu. Slot 0 created later by LS first-autosave trigger — Menu does not call `SaveLoad`. |
| **Settings panel** | Personnel File button → `SettingsService.open_panel()` (CR-7) | NOT a true exit — Main Menu remains mounted underneath, this is an overlay. Settings pushes `Context.SETTINGS`. Reverse path is the "Settings panel dismiss" entry. |
| **Modal overlay (Quit-Confirm, New-Game-Overwrite, Save-Failed)** | Various button activations / signal receipts | NOT a true exit — overlay only. Modal pushes `Context.MODAL`. Reverse path is the "Modal dismiss" entry. |
| **Operations Archive (Load Game grid)** | Operations Archive button (VS) | NOT a true exit until a slot is activated — overlay only. Slot activation IS a true exit (LOAD_FROM_SAVE row above). |

**Irreversible exits**: Only `Close File` (process exit) and `transition_to_section` (NEW_GAME or LOAD_FROM_SAVE — destroys the menu scene tree). All other "exits" are overlays that the player can dismiss back to the Main Menu surface.

---

## Layout Specification

### Information Hierarchy

**Information items the screen must communicate** (full inventory):

| # | Item | Source | MVP/VS |
|---|---|---|---|
| 1 | The action set: how to resume, start, configure, quit | menu-system.md CR-5/6/7/9 | MVP |
| 2 | Slot 0 state (occupied / empty / corrupt — communicated only via Continue button label-swap, per Pillar 5 Refusal: no separate "no save" dialog) | CR-5 + Save/Load slot 0 contract | MVP |
| 3 | The 1965 BQA Case File register (visual identity — bureaucratic, period, composed) | art-bible §2.7 + §3.3 + §7D + menu-system.md Player Fantasy | MVP (typography + palette only) → VS (full mission-dossier-card backdrop) |
| 4 | Game title block — *The Paris Affair* (or equivalent BQA-stamped logotype) | art-bible §2.7 + CR-16 [VS] | VS |
| 5 | Settings entry-point (ambiguous label "Personnel File" needs `accessibility_description`) | CR-7 + AccessKit row of menu-system.md C.9 | MVP |
| 6 | Save-failed advisory (signal-driven, modal — not always visible) | CR-10 + Events.save_failed | MVP (signal sub) → VS (full PHANTOM Red header band per `save-failed-advisory` pattern) |
| 7 | Build/version stamp (e.g., "BQA/65 Build 0.1.4") | Convention; not in GDD | VS — flag as Open Question |
| 8 | Quicksave / Quickload feedback card (NOT visible on Main Menu — only on gameplay; Main Menu sub but card never shows over Main Menu) | CR-15 [VS] | n/a for this spec |

**Ranking — what does the player need to see first?**

1. **Most critical** (eye lands here within 2 seconds of cold boot): **Continue button** — labeled "Resume Surveillance" (occupied) or "Begin Operation" (empty/corrupt). This is the dominant player decision; default focus targets this button on every entry.
2. **Second**: **New Game button** ("Open New Operation"). Discoverable below Continue. Only shown in MVP when slot 0 is OCCUPIED (otherwise the Continue button's "Begin Operation" label serves both functions — see Open Question #1 below).
3. **Third**: **Operations Archive button** [VS] — "Open Saved Dispatch". Below New Game. Not present in MVP.
4. **Fourth**: **Personnel File button** (Settings). Below Operations Archive (or directly below New Game in MVP).
5. **Fifth**: **Close File button** (Quit). Always last in the stack — visual position reinforces destructive nature.
6. **Visual register** is always-on (Layout Zones sub-section): the 1965 BQA Case File aesthetic communicates itself through palette + typography + composition before the player parses any individual button.
7. **Discoverable, not visible at rest**: build/version stamp (small footer, low contrast); save-failed advisory (signal-driven modal); modal feedback for destructive actions (Quit-Confirm, New-Game-Overwrite when triggered).

**Conflict check — Pillar 5 vs density**: The MVP stack is 4 buttons + register. The VS stack is 5 buttons + title block + dossier-card backdrop + register. Neither approaches the "information-dense" end of the spectrum (per art-bible §2.7 "energy: contemplative"). The screen's information budget is intentionally low — ~85% of the visual surface is register/composition, ~15% is action affordances. This matches the period graphic-design poster register (Air France travel poster grammar) which prioritizes composition over chrome.

### Layout Zones

**Selected arrangement**: **Option A — Asymmetric Air France poster (Saul Bass register)**. Rationale: matches art-bible §2.7 "vintage Air France travel poster graphic language" most directly; asymmetry creates compositional weight that pulls eye to action affordances (left, Western reading order) before the visual register element (right, Eiffel silhouette); solo-developer-friendly (silhouette is one flat shape, no per-section variation).

**Reference resolution**: 1920 × 1080 (target framerate hardware floor per `.claude/docs/technical-preferences.md`). All zone allocations scale proportionally at higher resolutions; 16:9 is the only locked aspect ratio (no 21:9 or 4:3 variants in MVP).

**Zone allocation** (horizontal × vertical):

| Zone | Position | Allocation | Contents | MVP/VS |
|---|---|---|---|---|
| **Z1 — Header** | Top, full-width | 0–10% V (108 px) | Title block "THE PARIS AFFAIR" + sub-stamp "─── CASE FILE BQA/65 ───" | VS (MVP ships header empty — see Conflict Note below) |
| **Z2 — Action Stack** | Left side, vertically centered | 10–80% V × 0–55% H | Vertical button stack: Continue / New Game / Operations Archive [VS] / Personnel File / Close File | MVP (4 buttons) → VS (5 buttons, adds Operations Archive) |
| **Z3 — Hero Silhouette** | Right side, anchored bottom | 10–95% V × 55–100% H | Eiffel Tower flat silhouette in Ink Black on BQA Blue field, anchored to bottom-right corner per Air France poster grammar | MVP (silhouette only, no title) → VS (full mission-dossier-card backdrop layered behind silhouette per CR-16) |
| **Z4 — Footer** | Bottom, full-width | 95–100% V | Build/version stamp at low contrast (BQA Blue on Ink Black, ~30% contrast); locale indicator | VS — flag as Open Question whether MVP needs build stamp |
| **Z5 — Modal layer** | Full-screen overlay | 0–100% × 0–100% | Mounted as ModalScaffold child when active (Quit-Confirm, New-Game-Overwrite, Save-Failed); never visible at rest | MVP (overlay infrastructure must exist Day-1) |
| **Z6 — Settings overlay** | CanvasLayer 10, owned by Settings #23 | full-screen | Settings panel HSplitContainer; mounted by Z2 Personnel File button | MVP (entry-point only; panel internals owned by Settings GDD) |

**Conflict note — MVP without title**: Z1 is VS-scope per CR-16 (mission dossier card backdrop). MVP ships with Z1 empty (a flat blue band at top, ~108 px high). At MVP, the Eiffel silhouette in Z3 carries the entire register-setting load — the player sees a saturated BQA blue field, a flat silhouette, and 4 typeset buttons. This is intentional: MVP is the "stub" that lands the register; VS adds the title block as the register's emphatic statement. **Decision flagged**: if the MVP playtest reveals the empty header reads as unfinished rather than "registered minimalism", elevate the title block to MVP scope (covered as Open Question #2 below).

**Margins & safe zones** (1080p reference):

- **Outer margin**: 64 px from screen edges on all four sides (no UI element touches the edge — the comic-book outline post-process shader needs breathing room around composed shapes).
- **Inter-zone gutter**: 32 px minimum between Z2 and Z3.
- **Inter-button spacing within Z2**: 16 px vertical separation between buttons; 8 px focus-ring buffer.
- **Title baseline (Z1)**: 64 px from top edge (matches outer margin).
- **Footer baseline (Z4)**: 32 px from bottom edge (smaller than outer margin — footer is intentionally close to the edge as a 1965 print convention; build stamps live in the gutter).

**Resolution scaling**:

- At 4K (2160p), all dimensions × 2 (Godot's stretch_mode = `canvas_items` per ADR-0004; UI scales by `Window.content_scale_factor`).
- ui_scale Settings slider (75–150% per `accessibility-requirements.md`) multiplies all dimensions further, applied to font sizes and button hit-targets but NOT to the Eiffel silhouette (silhouette is composition, not text — it does not scale with ui_scale).
- Outer margin minimum at 75% ui_scale: 48 px (still > comic-book outline shader's 4 px breathing-room minimum).

### Component Inventory

Per-zone component list. Pattern references point to `design/ux/interaction-patterns.md`. **NEW** indicates a pattern not yet in the library — these are flagged for cross-reference check (Phase 5).

**Z1 — Header** [VS only]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `TitleLabel` | `Label` | "THE PARIS AFFAIR" (Futura/DIN bold, condensed, 96 px @ 1080p, BQA Blue on Parchment per art-bible §7B) | No | `auto-translate-always` |
| `SubStampLabel` | `Label` | "─── CASE FILE BQA/65 ───" (American Typewriter, 18 px, Ink Black on Parchment) | No | `auto-translate-always` |

**Z2 — Action Stack** [MVP core]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `ContinueButton` | `Button` | Label: `tr("menu.main.continue")` ("Resume Surveillance") OR `tr("menu.main.continue_empty")` ("Begin Operation") per CR-5 label-swap | Yes — primary action, default focus on every entry | `auto-translate-always` + `accessibility-name-re-resolve` + `dual-focus-dismiss` |
| `NewGameButton` | `Button` | Label: `tr("menu.main.new_game")` ("Open New Operation"); **conditional visibility** — see Open Question #1 (visible only when slot 0 OCCUPIED in MVP) | Yes — opens New-Game-Overwrite modal per CR-6 | `auto-translate-always` + `modal-scaffold` (target) |
| `OperationsArchiveButton` [VS] | `Button` | Label: `tr("menu.main.load")` ("Operations Archive") | Yes — mounts `LoadGameScreen` overlay per CR-11 | `auto-translate-always` + `save-load-grid` (target) |
| `PersonnelFileButton` | `Button` | Label: `tr("menu.main.settings")` ("Personnel File"); `accessibility_description = tr("menu.main.settings.desc")` ("Adjust audio, graphics, accessibility, and control settings.") per CR-7 | Yes — calls `SettingsService.open_panel()` | `auto-translate-always` + `accessibility-name-re-resolve` |
| `CloseFileButton` | `Button` | Label: `tr("menu.main.quit")` ("Close File") | Yes — opens Quit-Confirm modal per CR-9 | `auto-translate-always` + `modal-scaffold` (target) |

**Z3 — Hero Silhouette** [MVP core]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `BackgroundFill` | `ColorRect` | Solid BQA Blue `#1B3A6B` (per art-bible §4.1 + accessibility audit row) | No | n/a (engineering primitive) |
| `EiffelSilhouette` | `TextureRect` (or `Sprite2D`) | Single flat-fill black silhouette PNG, no internal detail (per art-bible §3.2 simplify-the-lattice + §2.7 single flat shape); anchored bottom-right; ~35% horizontal × ~85% vertical | No (decorative) | n/a — **NEW pattern candidate**: `flat-graphic-hero-silhouette` (composition primitive, not interactive — flag if pattern library wants it) |
| `DossierCardBackdrop` [VS] | `TextureRect` | Mission dossier card per art-bible §7D + CR-16 (Eiffel surveillance photography with stamped intelligence metadata) — sits BEHIND the EiffelSilhouette + behind action stack with 30% darkened modulate to preserve button contrast | No | n/a |

**Z4 — Footer** [VS only]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `BuildStampLabel` | `Label` | "bqa/65 build 0.1.4" (American Typewriter, 12 px, BQA Blue on Ink Black, ~30% contrast — discoverable, not visible at glance) | No | `auto-translate-always` (locale-formatted version number; no English content) |
| `LocaleIndicatorLabel` [VS optional] | `Label` | Current locale code (e.g., "EN" / "FR") in same low-contrast register; click-to-cycle behavior is OUT OF SCOPE — locale changes through Settings only | No | `auto-translate-always` |

**Z5 — Modal layer** [MVP infrastructure]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `ModalScaffold` | `CanvasLayer` (lazy-instantiated, child of MainMenu) | Hosts: PhotosensitivityWarningContent (separate spec), QuitConfirmContent (separate spec), NewGameOverwriteContent (separate spec), SaveFailedContent (separate spec). Single instance reused across all modals per menu-system.md C.4 depth-1 queue | Yes — focus trap when active | `modal-scaffold` |

**Z6 — Settings overlay** [Settings system #23 owns]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `SettingsPanel` | `CanvasLayer 10` (owned by SettingsService autoload) | Opaque panel, owned by Settings GDD #23 — this spec only references its mount/dismiss contract | Yes (focus trap) | `input-context-stack` (Settings push) |

**NEW patterns flagged for library addition**: 1 candidate — `flat-graphic-hero-silhouette` (composition primitive for full-bleed flat-shape backgrounds against solid color fields; non-interactive; serves Pillar 5 graphic-design poster register). Addition to pattern library is OPTIONAL — this is a one-screen pattern in MVP. Re-evaluate after `pause-menu.md` is authored to see if Pause uses the same primitive.

### ASCII Wireframe

**MVP wireframe** (Day-1 slice — 1920 × 1080 reference, ~64 px outer margin, BQA Blue field, Eiffel silhouette anchored bottom-right):

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  (Z1 empty at MVP — flat blue band, 108 px high)                             │
│                                                                              │
│  ────────────────────────────────────────────────────────────────────────    │
│                                                                              │
│   Z2  Action Stack                                       Z3                  │
│   ════════════════════════                                                   │
│                                                          ▒                   │
│                                                          ▒▒                  │
│      ┌─────────────────────────┐                        ▒▒░                 │
│      │  ▶ Resume Surveillance  │  ← default focus       ▒░░▒                 │
│      └─────────────────────────┘                       ▒░░░▒                 │
│                                                       ░░░▒▒░░                │
│      ┌─────────────────────────┐                      ▒░░▒▒░░░               │
│      │    Open New Operation   │  (visible only when ░░░░▒▒░░░               │
│      └─────────────────────────┘   slot 0 OCCUPIED)  ░▒▒▒▒▒░░░░              │
│                                                     ░░░░░░░░░░░              │
│      ┌─────────────────────────┐                    ░▒▒▒▒▒▒░░░░             │
│      │      Personnel File     │                    ░░░░░░░░░░░░             │
│      └─────────────────────────┘                  ░▒▒▒▒▒▒▒░░░░░░             │
│                                                  ░░░░░░░░░░░░░░░             │
│      ┌─────────────────────────┐                ░░▒▒▒▒▒▒▒▒░░░░░░░            │
│      │       Close File        │                ░░░░░░░░░░░░░░░░░            │
│      └─────────────────────────┘                ░░▒▒▒▒▒▒▒▒▒░░░░░░░           │
│                                                                              │
│  (Z4 empty at MVP — no build stamp)                                          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

  Legend: ▒/░ = Eiffel silhouette in Ink Black (#1A1A1A) against BQA Blue (#1B3A6B)
          ┌─┐  = Button rectangle, hard-edged, no drop shadow, BQA Blue fill on Parchment label
          ─── = Section divider rule (1 px, 30% Ink Black)
```

**VS wireframe** (full slice — adds Z1 title block, Operations Archive button, Z4 footer, dossier-card backdrop):

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   THE PARIS AFFAIR                                                           │
│   ─── CASE FILE BQA/65 ───                                                   │
│                                                                              │
│  ────────────────────────────────────────────────────────────────────────    │
│  ░ ░ ░  Z3 dossier-card backdrop layered behind Z3 silhouette  ░ ░ ░ ░       │
│  ░ ░ (Eiffel surveillance photography, stamped intelligence metadata,        │
│  ░ ░  30% darkened modulate to preserve button contrast — see CR-16)         │
│  ░ ░                                                                  ░ ░    │
│   Z2  Action Stack                                       Z3                  │
│   ════════════════════════                                                   │
│                                                          ▒                   │
│      ┌─────────────────────────┐                        ▒▒                  │
│      │  ▶ Resume Surveillance  │  ← default focus       ▒░░                 │
│      └─────────────────────────┘                       ▒░░▒                 │
│                                                       ░▒░░▒░                │
│      ┌─────────────────────────┐                      ░░░░░▒░               │
│      │    Open New Operation   │                      ▒░░░░░▒░              │
│      └─────────────────────────┘                     ░░▒▒░░░▒░              │
│                                                     ░░░░░░░░▒░              │
│      ┌─────────────────────────┐                    ░▒░░░░░░░▒░             │
│      │   Operations Archive    │  ← VS-added         ░░░░░░░░░▒░             │
│      └─────────────────────────┘                    ▒▒▒▒▒▒░░░░░▒            │
│                                                                              │
│      ┌─────────────────────────┐                                             │
│      │      Personnel File     │                                             │
│      └─────────────────────────┘                                             │
│                                                                              │
│      ┌─────────────────────────┐                                             │
│      │       Close File        │                                             │
│      └─────────────────────────┘                                             │
│                                                                              │
│  bqa/65 build 0.1.4                                                  EN      │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Focus indicator**: A 4 px BQA Blue solid border with 2 px Ink Black inset (per ADR-0004 + art-bible §3.3 hard-edged-rectangle grammar). Focus indicator overrides the button's default fill — focused button reads as inverted (Parchment fill, BQA Blue text). The indicator is **shape-driven**, not animated — focus does not pulse, glow, or transition; it snaps in/out per Pillar 5 Refusal 5 (no eased animation).

**Default focus on entry** (per CR-5 + AC-MENU-3.1):

- Cold boot, slot 0 OCCUPIED → `ContinueButton` ("Resume Surveillance")
- Cold boot, slot 0 EMPTY/CORRUPT → `ContinueButton` ("Begin Operation")
- Photosensitivity-warning dismiss → `ContinueButton` (whichever label per slot 0)
- Settings dismiss → `PersonnelFileButton`
- Modal Cancel → originating button (Continue / NewGame / CloseFile per which modal triggered)
- Operations Archive dismiss [VS] → `OperationsArchiveButton`

**Tab order** (keyboard `Tab` / D-pad-down — gamepad partial per CR-17 [VS]):

- MVP, slot 0 OCCUPIED: Continue → New Game → Personnel File → Close File → wraps to Continue
- MVP, slot 0 EMPTY/CORRUPT: Continue (label "Begin Operation") → Personnel File → Close File → wraps
- VS, all states: Continue → New Game (when shown) → Operations Archive → Personnel File → Close File → wraps

---

## States & Variants

**State table** (every visual/interactive variant of the screen):

| State / Variant | Trigger | What Changes | MVP/VS |
|---|---|---|---|
| **Default — slot 0 occupied** | `slot_metadata(0)` returns non-null Dictionary, state ≠ CORRUPT | Standard layout. Continue label = "Resume Surveillance". Default focus = Continue. New Game button visible ("Open New Operation"). Per AC-MENU-3.1. | MVP |
| **Empty / Corrupt — slot 0** | `slot_metadata(0)` returns null OR empty Dictionary OR state == CORRUPT (CR-5 corrupt-slot fall-through) | Continue label swaps to "Begin Operation". Continue activation always opens New-Game-Overwrite modal (CR-5 destructive guard). New Game button visibility = Open Question #1. | MVP |
| **Pre-Acknowledge** (photosensitivity warning open) | `_boot_warning_pending == true` AND modal not yet acknowledged | All Z2 buttons have `process_input = false` (CR-8 step). Modal is mounted as overlay; focus trapped in modal. ButtonContainer visually visible (no grey-out per Pillar 5 Refusal 1) but inert. | MVP (Day-1 HARD-blocking dep per CR-8) |
| **Modal active** (Quit-Confirm / New-Game-Overwrite / Save-Failed) | Modal mounted via `ModalScaffold.show_modal(...)` | All Z2 buttons remain visible, focus trapped in modal (per `modal-scaffold` pattern). `Context.MODAL` on stack. AC-MENU-7.1 / 4.1 / 8.2. Underlying buttons NOT disabled (per CR-10 non-blocking). | MVP |
| **Settings overlay active** | Personnel File button activated → `SettingsService.open_panel()` (CR-7) | Settings panel mounted on CanvasLayer 10 (opaque, owned by Settings #23). Z2 buttons remain visible underneath; focus moves to Settings panel content. `Context.SETTINGS` on stack. AC-MENU-5.1. | MVP (entry-point only) |
| **Loading transition** | Continue / New Game / Operations Archive activated → music fade started | Activated button has `disabled = true` immediately on first press (CR-6 re-entrant guard, AC-MENU-4.3.a). Music fades over `menu_music_fade_out_ms` (default 800 ms). Other buttons remain visible but unfocused. After `await` fade completes, `Context.LOADING` pushed and `LS.transition_to_section()` called. Screen is destroyed shortly after. | MVP |
| **Operations Archive open** [VS] | Operations Archive button activated → mounts Load Game grid overlay | Z2 buttons remain visible behind grid; grid is the focus surface; `Context.MENU` remains (grid does NOT push MODAL — it's a sub-screen, not a modal). | VS |
| **Locale changed** (returned from Settings with locale swap) | `NOTIFICATION_TRANSLATION_CHANGED` received | All Labels re-translate via `auto-translate-always` pattern. AccessKit `accessibility_name` / `accessibility_description` re-resolve via `accessibility-name-re-resolve` pattern. ui_scale may have changed — re-layout buttons if so. | MVP (plumbing) → VS (FR + DE locales ship) |
| **Reduced-motion active** | `Settings.reduced_motion == true` | No animation differences AT REST (Main Menu has no resting animation per Pillar 5 Refusal 5). Modal mount/dismiss animations branch via `reduced-motion-conditional-branch` pattern — modals snap rather than tween. Music fade is NOT considered motion (per `accessibility-requirements.md` definition). | MVP (plumbing) → VS (modals use animation) |
| **ui_scale = 75% / 150%** | Settings ui_scale slider value | Button hit-targets and font sizes scale per `Window.content_scale_factor`. Eiffel silhouette does NOT scale (it's composition, not text). Outer margin floor: 48 px @ 75%. AC must verify min-targets per WCAG SC 2.5.5 (44 × 44 CSS px equivalent). | MVP (plumbing) → VS (full audit) |
| **Quicksave/Quickload feedback** | (N/A on Main Menu — F5/F9 fire only during gameplay per Save/Load CR-5) | No state — feedback card only appears on gameplay HUD, never on Main Menu. Documented for completeness. | n/a |

**Platform variants**: None. Linux + Windows render the same UI (Forward+ Vulkan on Linux, D3D12 on Windows per ADR + technical-preferences). No mobile, no console-specific overlays, no Steam Deck variant in MVP (Steam Deck is informed-but-not-targeted per accessibility-requirements.md). The only platform-conditional behavior is `Input.set_custom_mouse_cursor()` for the fountain-pen-nib cursor (CR-17 [VS]) — this is a Godot API that works identically across PC platforms.

**Locked-content variants**: None — Main Menu has no locked content. Achievement tracking, "what's new" banners, premium content gates are all out of scope (Pillar 5 forbids all of these conventions explicitly).

**Combined-state matrix** (which states can co-occur):

| | Default | Pre-Ack | Modal | Settings | Loading | Locale change |
|---|---|---|---|---|---|---|
| **Default** | — | mutually exclusive | overlay | overlay | brief transition | applies on next entry |
| **Pre-Ack** | — | — | mutually exclusive (Pre-Ack IS a modal) | mutually exclusive | mutually exclusive | applies on dismiss |
| **Modal** | overlay | — | depth-1 queue (per C.4 — most-recent-wins, never depth-2) | mutually exclusive | mutually exclusive | applies on dismiss |
| **Settings** | overlay | — | mutually exclusive (Settings has its own modal stack internally) | — | mutually exclusive | applies on dismiss |
| **Loading** | brief | — | — | — | — | terminal — screen destroyed before locale event reaches it |

**State-transition invariants** (checked by AC-MENU-10.x):

1. `Context.MENU` must be on the stack while Main Menu is interactive.
2. `Context.MODAL` is pushed when ANY modal opens, popped when it closes — depth never exceeds 1 modal-active.
3. `Context.LOADING` is pushed BEFORE `LS.transition_to_section()` and never popped explicitly (LS scene change destroys the menu tree, taking the autoload state with it).
4. `Context.SETTINGS` is owned and managed by Settings #23 — Main Menu does not push it.

---

## Interaction Map

**Input methods**: Keyboard/Mouse (primary) + Gamepad (Partial — full menu navigation per CR-17 [VS]). All interactions consumed via `_unhandled_input(event)` checking `event.is_action_pressed(...)` per ADR-0004 §97 (sidesteps Godot 4.6 dual-focus split). Raw `KEY_ESCAPE` is never tested — actions only.

**Per-component interaction map**:

| Component | Action | KB/Mouse | Gamepad [VS] | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **`ContinueButton`** | Activate | `LMB` click OR `Enter` / `Space` while focused | `JOY_BUTTON_A` while focused | Typewriter-clack one-shot SFX on UI bus (Audio §UI bus); button fill snap-inverts (Parchment / BQA Blue) for 1 frame | Slot 0 OK: fade menu music → `SaveLoad.load_from_slot(0)` → `LS.transition_to_section(LOAD_FROM_SAVE)`. Slot 0 EMPTY/CORRUPT: open New-Game-Overwrite modal (CR-5 destructive guard). |
| **`ContinueButton`** | Focus | `Tab` (KB) / `↑↓` (D-pad) / mouse hover | `↑↓` D-pad / left stick | Focus indicator (4 px BQA Blue border, inverted fill); paper-shuffle one-shot SFX on focus change (UI bus, ducked when same-button refocus) | None — focus only |
| **`NewGameButton`** (when shown) | Activate | LMB / Enter / Space | A button | Typewriter-clack | Slots 1–7 all empty: open New-Game-Overwrite modal (CR-6 conditional). At least one of slots 1–7 non-empty: skip confirm, fade music → `LS.transition_to_section(NEW_GAME)`. |
| **`OperationsArchiveButton` [VS]** | Activate | LMB / Enter / Space | A button | Typewriter-clack; paper-shuffle on grid mount | Mount LoadGameScreen overlay; focus moves to slot 0 card (default focus per save-load-grid pattern) |
| **`PersonnelFileButton`** | Activate | LMB / Enter / Space | A button | Typewriter-clack | `SettingsService.open_panel()` — Settings owns push of `Context.SETTINGS`. Main Menu remains visible underneath. AC-MENU-5.1. |
| **`CloseFileButton`** | Activate | LMB / Enter / Space | A button | Typewriter-clack; rubber-stamp thud SFX (Pillar 5 register: destructive actions get the stamp) | Open Quit-Confirm modal (`ModalScaffold.show_modal(QuitConfirmContent)`); push `Context.MODAL`; default focus = Cancel ("Continue Mission") per AC-MENU-7.1. |
| **Esc / `ui_cancel` at Main Menu top level** | n/a | `Esc` | `JOY_BUTTON_B` | None | **No effect** per CR-9 + AC-MENU-11.1 (event consumed and ignored). Important: Main Menu does NOT open Quit-Confirm on Esc. The player must explicitly activate Close File. This is a Pillar 5 register choice — modern launchers prompt "exit?" on Esc; the Case File makes you stamp the form. |
| **Mouse hover (any button)** | Hover | Mouse motion entering button rect | (n/a — gamepad uses focus, not hover) | Same as focus: shape-driven inverted fill. **No hover-only animation** (no glow, no scale-up) per Pillar 5 Refusal 5. | None |
| **Mouse-click-outside** (when modal active) | Click on dimmed area outside modal | LMB on coordinates outside modal rect | (n/a) | Per `dual-focus-dismiss` pattern: behaves identically to `ui_cancel` (Cancel button activated). | Modal dismiss path (Cancel). Open Question #2 in `interaction-patterns.md` is about default policy — confirm: this spec's modals all dismiss on outside-click-via-Cancel, never destructive. |

**No long-press / no hold-to-confirm**: Per Pillar 5 register, no menu button uses press-and-hold semantics. All activation is single-press. (Hold-to-confirm is a modern UX convention; the Case File register stamps decisions immediately.)

**No drag / no swipe**: No draggable elements on Main Menu. Touch is out of scope; mouse-drag has no semantic.

**No double-click**: Single-click is sufficient. Double-click does not unlock different behavior. Mouse-click on a non-focused button focuses AND activates in a single press (Godot Button default behavior).

**Held-key flush on entry**: When Main Menu mounts (cold boot or Return-to-Registry), any held actions from the prior context are flushed via `held-key-flush-after-rebind` pattern (Settings owns this for rebind specifically; same pattern applies to context transitions per Input GDD AC-INPUT-5.1). Otherwise a held `ui_accept` from gameplay would auto-activate the Continue button on cold boot — a subtle but real risk.

**Cross-references**: `unhandled-input-dismiss` (ADR-0004 §97), `set-handled-before-pop` (every dismiss), `dual-focus-dismiss` (modal exits), `input-context-stack` (push/pop discipline).

---

## Events Fired

Per ADR-0002, Menu System is **subscribe-only** in MVP — it emits no Signal Bus domain signals. Player actions on Main Menu trigger events from *other* systems (SaveLoad, LevelStreaming, SettingsService) which Menu does not author.

| Player Action | Event Fired | Payload | Owner |
|---|---|---|---|
| Continue / Resume Surveillance activate (slot 0 OK) | `Events.game_loaded(slot=0)` after `SaveLoad.load_from_slot(0)` returns; later `Events.section_entered(section_id, reason)` from LS | `slot: int`, `section_id: StringName`, `reason: TransitionReason.LOAD_FROM_SAVE` | SaveLoad + LS (NOT Menu) |
| Continue activate, slot 0 EMPTY/CORRUPT (CR-5 fall-through) | (none directly — opens New-Game-Overwrite modal; no analytics event until confirmed) | n/a | n/a |
| New Game / Begin Operation confirmed | `Events.section_entered(first_section_id, NEW_GAME)` from LS after transition completes | `section_id: StringName`, `reason: TransitionReason.NEW_GAME` | LS (NOT Menu) |
| Personnel File activate | `Events.setting_changed("...", key, value)` may fire from SettingsService later if the player changes anything | per Settings GDD §G.2 | SettingsService (NOT Menu) |
| Close File confirmed | `get_tree().quit()` — direct OS-level call, no Signal Bus event | n/a | OS (NOT Menu) |
| Esc / `ui_cancel` at Main Menu top level | None — event consumed and ignored per CR-9 / AC-MENU-11.1 | n/a | n/a |
| Photosensitivity Acknowledge | `Events.setting_changed("accessibility", "photosensitivity_warning_dismissed", true)` from SettingsService | per Settings GDD CR-18 | SettingsService (NOT Menu) |
| Save-Failed received | (Menu *receives* `Events.save_failed(reason)` per CR-10 — does not fire it; SaveLoad fires it) | `reason: SaveLoad.FailureReason` | SaveLoad (NOT Menu) |

**Subscriptions** (Menu is the receiver, not emitter):

- `Events.save_failed(reason)` — subscribed in `MainMenu._ready()`, unsubscribed in `_exit_tree()` per ADR-0002 §IG-3 with `is_connected()` guard. AC-MENU-8.1.
- `NOTIFICATION_TRANSLATION_CHANGED` — handled at the Node level (not a Signal Bus event); triggers locale-driven re-render via `accessibility-name-re-resolve` pattern.

**Analytics events**: OUT OF SCOPE for MVP. Flagged as Open Question #3 for Polish — once an analytics platform is chosen, instrumentation candidates would be: Continue activate (count returning players), New Game activate (count first-launch flows), Close File activate (count session ends), Settings open (count config-engagement). No PII.

---

## Transitions & Animations

**Pillar 5 Refusal 5 binding constraint**: "No animated transitions other than paper movement. No crossfades, no Material Design slide-ins, no parallax scroll, no card-flip animations. Things enter as paper enters: dropped, pulled, stamped, advanced. Animation curves are mechanical, not eased."

**Screen enter**:

| Trigger | Animation | Reduced-motion variant |
|---|---|---|
| Cold boot | None (engine loads scene; first frame is the resting Main Menu). Menu music fade-in starts at 0.0 s and ramps over `menu_music_fade_in_ms` (default 1200 ms — Audio §UI bus) | Identical (audio fade is not motion) |
| Return-to-Registry from Pause | None (scene change via `change_scene_to_file()` is engine hard cut). Menu music fade-in over 1200 ms | Identical |
| Photosensitivity-warning dismiss | None — buttons go from `process_input = false` to `process_input = true` instantly. Focus indicator snaps to Continue. | Identical |
| Settings dismiss | None — focus indicator snaps to Personnel File button | Identical |
| Modal Cancel | Modal snaps out (no fade); paper-shuffle SFX one-shot on UI bus; focus snaps to originating button | Identical (already snap) |

**Screen exit**:

| Trigger | Animation |
|---|---|
| Continue / Operations Archive slot activate | Music fade-out over `menu_music_fade_out_ms` (default 800 ms, linear). Awaited before LS call. Screen still visible during fade. After fade, `LS.transition_to_section()` destroys the scene. |
| New Game confirmed | Same: music fade-out 800 ms → LS destroys scene |
| Close File confirmed | None — `get_tree().quit()` is instant; no fade, no farewell screen, no rubber-stamp animation. The rubber-stamp SFX on Close File button activation IS the parting note. |

**In-screen state-change animations**:

| State change | Animation | Reduced-motion variant |
|---|---|---|
| Button focus change | Hard snap — focus indicator border appears/disappears in 1 frame. No tween. | Identical |
| Button activate | Hard snap — fill inverts for 1 frame (then either modal opens / scene changes / Settings mounts). | Identical |
| Modal mount | Modal snaps in instantly. Paper-shuffle SFX cues the appearance. ModalScaffold pattern §spec specifies snap, not tween. | Identical (already snap) |
| Modal dismiss | Modal snaps out instantly. Paper-shuffle SFX. | Identical |
| Locale change re-render | All Labels re-translate in the same frame (`NOTIFICATION_TRANSLATION_CHANGED` is synchronous). No fade, no shimmer. | Identical |
| ui_scale change re-layout | Layout reflows on next layout pass (`Window.content_scale_factor` change). May be a 1-frame visual pop — acceptable; ui_scale changes are infrequent (Settings dismiss). | Identical |
| Continue button label-swap | Hard snap on `_ready()`. No crossfade between "Resume Surveillance" and "Begin Operation" — the swap happens before the screen is interactive on each entry. | Identical |

**Audio-as-transition-cue**: Per Audio GDD § UI bus, every paper/typewriter SFX is an *event marker*, not a "transition curtain". Menu uses these SFX to cue what would otherwise be invisible transitions:

- Paper-shuffle: focus change, modal mount, modal dismiss, scene transition prep
- Typewriter-clack: button activate (any button)
- Rubber-stamp thud: destructive action confirm (Close File, Quit-Confirm-Confirm, New-Game-Overwrite-Confirm)
- Drawer-slide: Pause Menu mount/dismiss (Pause Menu only — not Main Menu — but documented for register continuity)

**Vestibular-safety claim**: All Main Menu animations are hard cuts. There is no parallax, no camera shake, no tween-eased motion, no rapid color flicker, no rotation. The screen is vestibular-safe by design — `reduced_motion = true` does not need to alter Main Menu rendering. (`reduced-motion-conditional-branch` plumbing exists per CR-23 but consumes nothing on this surface in MVP. VS scope: if any modal mount tween is added in future, the branch is ready.)

**Music fade is not motion**: Per `accessibility-requirements.md` definition, audio fades are not "motion" for reduced-motion purposes. The 800 ms music fade on screen exit fires unconditionally regardless of `reduced_motion` setting.

---

## Data Requirements

Main Menu is **read-only** at MVP — it owns no persistent state, makes no writes, never opens save files directly. All persistence is read through the SaveLoad sidecar API (per ADR-0003) or through SettingsService autoload state.

| Data | Source System | Read / Write | Real-time? | Notes |
|---|---|---|---|---|
| Slot 0 metadata (`{state, section_id, saved_at_iso8601, elapsed_time, ...}`) | `SaveLoad.slot_metadata(0)` per ADR-0003 | Read | No — resolved once in `MainMenu._ready()` for Continue button label-swap | Menu MUST NOT open `.res` directly. AC-MENU-3.1 / 3.2 / 3.3. |
| Slots 1–7 metadata | `SaveLoad.slot_metadata(N)` for N in 1..7 | Read | No — resolved on New Game button activation for CR-6 conditional confirm | Cached for the duration of `_ready()`; not re-polled. If a save is written while Main Menu is open (rare — would require Pause Menu's File Dispatch which can't open with Main Menu mounted), the cache is stale. Acceptable: this case can't occur in MVP; flag for VS audit. |
| `_boot_warning_pending: bool` | `SettingsService` autoload (Settings GDD CR-18) | Read | No — synchronous read at top of `_ready()` per CR-8 (no `await`) | Autoload ordering guarantees `SettingsService._ready()` completes before `MainMenu._ready()` per ADR-0007. |
| `dismiss_warning() -> bool` return | `SettingsService.dismiss_warning()` | Read (via call) | Push (call returns true/false) | Disk-full failure case: returns false → modal stays open, AC-MENU-6.4. |
| Locale (current `TranslationServer.get_locale()`) | `TranslationServer` (Godot built-in) + Settings `locale` key | Read | Push via `NOTIFICATION_TRANSLATION_CHANGED` | Triggers re-render of all Label text + AccessKit re-resolve. |
| `ui_scale` (75–150%) | `SettingsService` (Settings G.3) → applied to `Window.content_scale_factor` | Read | Push via `setting_changed` signal subscription on Settings dismiss | Layout reflows on next pass. |
| `reduced_motion` flag | `SettingsService` (Settings G.3) | Read | Push — but Main Menu has no animations to gate at rest, so consumed only by Modal mount path (VS scope) | `reduced-motion-conditional-branch` plumbing per CR-23. |
| Build version string | `ProjectSettings.get_setting("application/config/version")` (Godot built-in) | Read | No — static at load time | VS scope (footer Z4); MVP doesn't render this. |
| `Events.save_failed(reason)` payload | `SaveLoad` autoload via Signal Bus (`Events`) | Read (via signal subscription) | Push — signal-driven | Subscribed in `_ready()`, unsubscribed in `_exit_tree()` per AC-MENU-8.1. |
| Active language string table (for label display) | `TranslationServer` + `*.po`/`*.csv` translation files in `assets/locale/` | Read | Push via `NOTIFICATION_TRANSLATION_CHANGED` | All Labels use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. |

**Writes performed by Main Menu**: NONE. Confirmed against menu-system.md C.7 ("Menu does not push directly … emits no domain signals at MVP"). Even on Quit, `Context.MENU` pop is a stack mutation but not a "write" to persistent storage. Photosensitivity Acknowledge calls `SettingsService.dismiss_warning()` which causes Settings to write — but Main Menu does not perform the write itself.

**Architectural concerns flagged**:

1. **Slot metadata caching**: Main Menu does not auto-refresh slot metadata if a save is created while Main Menu is open. In MVP this can't happen (Save flow requires Pause Menu, which is mutually exclusive with Main Menu). For VS, if a future feature lets the player save from outside Pause (e.g., a quicksave keybind that fires on Main Menu — currently rejected by Save/Load CR-5), this assumption breaks. Flag for VS audit.
2. **`SettingsService` autoload ordering**: Menu reads `_boot_warning_pending` synchronously, assuming `SettingsService._ready()` ran first. This is guaranteed by ADR-0007 §Canonical Registration Table. If ADR-0007 is amended to reorder autoloads, Menu's CR-8 contract may break — flag for ADR-0007 amendment review.
3. **`TranslationServer` locale at boot**: `SettingsService` must call `TranslationServer.set_locale(...)` BEFORE `MainMenu._ready()` runs, otherwise the first frame of Main Menu renders in the engine default locale (English regardless of Settings). This is `SettingsService`'s responsibility, but we flag it here for traceability.

**No PII / no secret data**: All data Main Menu reads is local-only (save metadata, settings, build version). No network calls. No telemetry beacons in MVP. No external dependencies beyond Godot's `TranslationServer`.

---

## Accessibility

**Committed tier**: **Standard** per `design/accessibility-requirements.md`. This screen exceeds Standard in some places (AccessKit per-Control on Day-1 MVP, photosensitivity boot-warning poll, reduced-motion plumbing) but does not extend to Comprehensive features (no in-world screen reader, no HUD repositioning).

**Keyboard-only navigation path** [Day-1 MVP]:

Cold boot, slot 0 OCCUPIED:

```
  [Continue]  ←  default focus on entry
    ↓ Tab / D-pad-down
  [New Game]
    ↓ Tab / D-pad-down
  [Personnel File]
    ↓ Tab / D-pad-down
  [Close File]
    ↓ Tab / D-pad-down  →  wraps to [Continue]
```

100% of interactive elements reachable via Tab + Enter (or D-pad + A on gamepad). No mouse-only interactions. No hover-only secondary affordances. AC-MENU-AX.1 (new — added in Section I).

**Modal focus trap** [Day-1 MVP for boot-warning + Quit-Confirm]:

When a modal is active, focus cannot escape the modal via Tab. The modal's first focusable child has focus on mount (default = Cancel for destructive modals per AC-MENU-7.1; default = Acknowledge for boot-warning per AC-MENU-6.5). Tab cycles within the modal only. `ui_cancel` dismisses the modal (boot-warning excepted per AC-MENU-6.2 — non-dismissible-by-ui_cancel until `dismiss_warning()` returns true). Per `modal-scaffold` pattern §spec.

**AccessKit per-Control table** [Day-1 MVP per ADR-0004 IG10]:

| Component | `accessibility_role` | `accessibility_name` | `accessibility_description` |
|---|---|---|---|
| `MainMenu` (root) | `"main"` | "Main Menu" (per `tr("menu.main.title")`) | (none) |
| `ContinueButton` (slot 0 OK) | `"button"` | "Resume Surveillance" | (none — label is self-describing) |
| `ContinueButton` (slot 0 EMPTY/CORRUPT) | `"button"` | "Begin Operation" | "Start a new operation. No saved file detected." (per Open Question #4 — needs locale review) |
| `NewGameButton` | `"button"` | "Open New Operation" | (none — label is self-describing) |
| `OperationsArchiveButton` [VS] | `"button"` | "Operations Archive" | "Open the saved-dispatch grid." |
| `PersonnelFileButton` | `"button"` | "Personnel File" | **"Adjust audio, graphics, accessibility, and control settings."** (per CR-7 — "Personnel File" is the one Case File label genuinely ambiguous to first-time AT users; description is mandatory) |
| `CloseFileButton` | `"button"` | "Close File" | "Quit the application." |

All labels resolved via `auto-translate-always` pattern; `accessibility_name` and `accessibility_description` re-resolve on `NOTIFICATION_TRANSLATION_CHANGED` per `accessibility-name-re-resolve` pattern.

**Live regions**:

| Trigger | `accessibility_live` value | Pattern |
|---|---|---|
| Modal mount (any modal) | `"assertive"` (one-shot — set on mount, cleared to `"off"` next frame via `call_deferred`) | per CR-21 + F.7 + AC-MENU-6.5 |
| Save-Failed modal (high-stakes loss event) | `"assertive"` (one-shot) | per CR-10 |
| Continue button label-swap | (none — label changes silently; AccessKit announces the new value when focus lands on it) | n/a |

**Text contrast** [Standard tier — WCAG 2.1 AA]:

| Element | Foreground | Background | Contrast ratio | Status |
|---|---|---|---|---|
| Button label (default state) | Parchment `#E8DCC4` (per art-bible §4) | BQA Blue `#1B3A6B` | ≥ 7:1 (estimate — verify with `tools/ci/contrast_check.sh` once available) | Designed (per `accessibility-requirements.md` table) |
| Button label (focus state — inverted) | BQA Blue `#1B3A6B` | Parchment `#E8DCC4` | ≥ 7:1 (same ratio inverted) | Designed |
| Title block (VS) | BQA Blue `#1B3A6B` on Parchment band | Parchment `#E8DCC4` | ≥ 7:1 | Designed |
| Build stamp (footer, low contrast) | BQA Blue at 30% opacity | Ink Black `#1A1A1A` field | ~3:1 (intentionally low — discoverable, not visible at glance) | **Open Question #5**: does 30% opacity build stamp meet WCAG SC 1.4.3? Probably not (likely fails AA at 4.5:1). Resolution: build stamp is auxiliary content (not informational at the SC 1.4.3 level — it's a print convention), but if AA conformance is asserted globally, raise to 50% opacity (≥ 4.5:1). |

**Minimum text sizes** [per `accessibility-requirements.md`]:

- Button labels: 24 px floor at 1080p (Standard tier menu UI minimum).
- Title block: 96 px (well above floor).
- Sub-stamp: 18 px (per art-bible §7B condensed register; verify against floor — 18 px IS the HUD floor; menu UI floor is 24 px → **flag**: sub-stamp may need to scale to 24 px or be reclassified as decorative).
- Build stamp: 12 px (decorative; below the floor by design — see contrast Open Question #5).
- Scaling: `ui_scale` 75–150% per Settings G.3 multiplies all menu text. At 75% the 24 px floor becomes 18 px (matches HUD floor — acceptable). At 150% the 24 px becomes 36 px.

**Color-independent communication**:

The Continue button's slot-0-state communication ("Resume Surveillance" vs "Begin Operation") is conveyed purely by **label text**, not color. The button's BQA Blue fill is identical in both states. ✓ Color-blind safe.

The Close File button has no color-coded "destructive" tag at rest — destructive nature is conveyed by **position** (last in stack) and **label** ("Close File" not "Quit"). The destructive header band (Ink Black) only appears on the Quit-Confirm modal, paired with text "CLOSE FILE — Y/N". ✓ Color-blind safe.

Focus indicator is shape-driven (4 px border) AND color-driven (BQA Blue). ✓ Players who don't perceive blue still see the border thickness.

**Screen flash / strobe / photosensitivity**:

The Main Menu itself contains no flashing, no strobing, no rapid color changes. The photosensitivity boot-warning modal is mounted by Main Menu but is owned by a separate UX spec (`design/ux/photosensitivity-boot-warning.md`). Per accessibility-requirements.md: HARDING FPA standard verification is required for any new flashing content; Main Menu has none.

**Motion / vestibular accessibility**:

All Main Menu animations are hard cuts (per Section E3). `reduced_motion` setting does not need to alter Main Menu rendering. ✓ Vestibular-safe by design.

**Motor accessibility**:

- Toggle-Sprint / Toggle-Crouch / Toggle-ADS — n/a on Main Menu (no movement actions).
- No timed inputs on Main Menu (no countdowns, no auto-dismiss with timer).
- Single-press activation (no hold-to-confirm, no double-click).
- Hit-target floor: 44 × 44 px equivalent at 1080p (WCAG SC 2.5.5 compliance). Buttons sized ~280 × 56 px at 100% ui_scale; well above floor.
- Custom mouse cursor (fountain-pen-nib) [VS] does not change effective hit-targets — pointer-position resolution is per-pixel.

**Cognitive accessibility**:

- 4 buttons in MVP (5 in VS) — well below cognitive-load thresholds (Miller's 7±2).
- Labels are short (1–3 words each).
- No unexplained jargon (the period register IS the jargon — but `accessibility_description` on the one ambiguous label closes the comprehension gap for AT users).
- No time-pressure to read or decide.
- Same screen state on every entry (Continue → New Game → Personnel File → Close File order is invariant).

**Out of scope for this spec** (committed elsewhere or deferred):

- Screen reader for in-world objects: per accessibility-requirements.md §Out of Scope.
- HUD repositioning: Comprehensive tier; OUT OF SCOPE.
- Difficulty assist modes: Comprehensive tier; OUT OF SCOPE.
- Mono audio: Comprehensive tier; OUT OF SCOPE.

---

## Localization Considerations

**Locale targets**: English (MVP — only locale that ships at MVP), French (FR-fr) and German (DE-de) at VS per Settings GDD locale switcher commitment.

**String inventory** (all label keys; resolved via `auto-translate-always`):

| Key | English source | EN char count | Layout budget @ 100% ui_scale | 40% expansion target | Status |
|---|---|---|---|---|---|
| `menu.main.continue` | "Resume Surveillance" | 19 | ~25–30 chars | ≤ 27 | ✓ likely fits FR/DE |
| `menu.main.continue_empty` | "Begin Operation" | 15 | ~25–30 chars | ≤ 21 | ✓ likely fits FR/DE |
| `menu.main.new_game` | "Open New Operation" | 18 | ~25–30 chars | ≤ 25 | ⚠ FR estimate "Ouvrir une nouvelle opération" ~30 chars — **potential overflow at 100% ui_scale**. Mitigation: shorten FR translation to "Nouvelle opération" (18 chars) at translator-brief stage. **Open Question #6**. |
| `menu.main.load` [VS] | "Operations Archive" | 18 | ~25–30 chars | ≤ 25 | ⚠ FR estimate "Archives des opérations" ~24 chars — borderline. Watch in QA. |
| `menu.main.settings` | "Personnel File" | 14 | ~25–30 chars | ≤ 20 | ✓ fits |
| `menu.main.quit` | "Close File" | 10 | ~25–30 chars | ≤ 14 | ⚠ FR estimate "Fermer le dossier" ~17 chars — **potential overflow at 100% ui_scale**. Mitigation: shorten FR translation to "Fermer" (6 chars) at translator-brief stage. **Open Question #7**. |
| `menu.main.settings.desc` | "Adjust audio, graphics, accessibility, and control settings." | 60 | ~80 chars (AccessKit description; not visible — read by AT) | ≤ 84 | ✓ fits (AT description is unbounded) |
| `menu.main.title` (root accessibility_name) | "Main Menu" | 9 | n/a (AT only) | unbounded | ✓ |
| `menu.main.title_block` [VS] | "THE PARIS AFFAIR" | 16 | spans full Z1 width | unbounded (title is hero text) | ⚠ FR/DE may keep "THE PARIS AFFAIR" untranslated as a brand title (recommend: do not translate; treat as series logotype) |
| `menu.main.title_substamp` [VS] | "─── CASE FILE BQA/65 ───" | 24 | ~40 chars at 18 px | ≤ 33 | ⚠ FR/DE: do BQA acronym + period stamps localize? **Open Question #8** — BQA is fictional period bureaucracy; localizing creates inconsistency. Recommend: keep "CASE FILE BQA/65" untranslated. Translate "CASE FILE" only if narrative-director approves. |

**Layout-critical elements** (where overflow breaks the design):

| Element | Why critical | Mitigation if FR/DE overflows |
|---|---|---|
| Action stack buttons (5 buttons stacked) | Vertical alignment requires consistent button height. Multi-line labels would break the rhythm. | All buttons constrained to single-line via Godot Label `clip_text = false` + `autowrap_mode = OFF`; if overflow detected, font scales down per FontRegistry rule (or — preferred — translator-brief shortens the translation). |
| Continue button label-swap | The two labels share the same button slot. Both must fit the same width. | Width = max("Resume Surveillance", "Begin Operation") + padding. The longer wins. Locale-specific: max(`menu.main.continue`, `menu.main.continue_empty`) per locale. |
| New Game button label | Conditional visibility — when shown, sits between Continue and Personnel File. | Same width-budget as siblings; flag FR overflow per Open Question #6. |

**Locale-specific formatting**:

| Element | Formatting | MVP/VS |
|---|---|---|
| Build version stamp ("bqa/65 build 0.1.4") | Format string `"bqa/65 build %s"` interpolating `ProjectSettings.get_setting("application/config/version")`. Numerical version is **not localized** (semver is invariant); the "build" word IS localized via `tr("menu.main.build_label")` | VS |
| Locale indicator (footer "EN" / "FR" / "DE") | Two-letter ISO 639-1 code. Not translated. | VS |
| Accessibility description (Personnel File) | Localized full sentence; AccessKit re-resolves on locale change | MVP |

**What this screen does NOT localize**:

- Save slot dates/times (these appear in the Operations Archive grid spec, not here — owned by `save-load-grid` pattern + Save/Load GDD).
- The Eiffel Tower silhouette (it's an image, not text).
- Audio SFX (typewriter-clack, paper-shuffle, rubber-stamp — period-faithful sounds, locale-invariant).

**RTL (right-to-left) support**: OUT OF SCOPE for MVP and VS. No Arabic or Hebrew locale planned. If RTL is added post-launch, the asymmetric layout (Z2 left, Z3 right) would mirror to (Z2 right, Z3 left) per Godot's `Control.layout_direction` — flag as Polish-tier work.

**Translation pipeline**: Per `localization-scaffold.md` GDD (referenced; not read in detail). Strings extracted via `tools/ci/string_extract.sh` (TBD); translated `.po` files in `assets/locale/[locale]/main_menu.po`; loaded by `TranslationServer` at boot.

**Translator brief priority items** (for the eventual `tools/translator-brief.md`):

1. "Resume Surveillance" — period-bureaucratic register; aim for FR/DE equivalents that read as 1965 case-officer prose, NOT modern game-launcher prose.
2. "Personnel File" — must be ambiguous enough to need an `accessibility_description`. The description is the safety net.
3. "Close File" — must NOT translate as "Quitter le jeu" / "Spiel verlassen" (that breaks Pillar 5). Translate as the equivalent of "Close the file" / "Schließe die Akte" — bureaucratic-neutral.
4. "BQA/65" — keep untranslated (period-acronym; fictional bureaucracy).

---

## Acceptance Criteria

UX spec ACs are narrower than the GDD's 61 ACs in `menu-system.md` H.1–H.13 — these verify UX-specific outcomes (layout, focus, accessibility, localization) and reference the GDD ACs they support rather than duplicating them.

**Format**: each criterion is testable by a human QA tester or an automated test, with no ambiguity. Story type tags: `[Logic]` = automated unit test; `[UI]` = manual walkthrough or interaction test; `[Visual]` = screenshot + lead sign-off; `[Integration]` = cross-system test. Gate level: `[BLOCKING]` (build-gating) or `[ADVISORY]` (lead-reviewed).

### Layout & Visual

- **AC-MMUX-1.1 [Visual] [BLOCKING]** GIVEN MainMenu rendered at 1920 × 1080 with all MVP buttons present, WHEN a screenshot is taken, THEN: (a) outer margin ≥ 64 px on all 4 sides; (b) Z2 action stack is left-aligned and vertically centered between Z1 (bottom edge of empty Z1 band) and Z4 (top edge of footer area); (c) Z3 Eiffel silhouette is anchored bottom-right and occupies 30–40% of horizontal width × 80–90% of vertical height. Evidence: `production/qa/evidence/main-menu-mvp-layout-[date].png` + art-director sign-off.
- **AC-MMUX-1.2 [Visual] [ADVISORY]** GIVEN MainMenu rendered with focus on any button, WHEN a screenshot is taken, THEN: (a) focus indicator is a 4 px solid BQA Blue `#1B3A6B` border with no glow / drop shadow / animation; (b) focused button fill is inverted (Parchment fill, BQA Blue text); (c) focus indicator snaps in within 1 frame (no eased transition).
- **AC-MMUX-1.3 [Logic] [ADVISORY]** GIVEN any Main Menu Button at 100% ui_scale, WHEN button rect is inspected, THEN width × height ≥ 280 × 56 px (above WCAG SC 2.5.5 target floor of 44 × 44 CSS px). Verifies motor-accessibility claim.

### Navigation & Focus

- **AC-MMUX-2.1 [Logic] [BLOCKING]** GIVEN MainMenu just mounted on cold boot with slot 0 OCCUPIED, WHEN the first frame is interactive (after Pre-Acknowledge state if applicable), THEN `ContinueButton.has_focus() == true` and the focus indicator is rendered. Same applies for slot 0 EMPTY/CORRUPT (Continue button still gets focus, regardless of label).
- **AC-MMUX-2.2 [Logic] [BLOCKING]** GIVEN MainMenu MVP mounted with slot 0 OCCUPIED (4 buttons visible), WHEN Tab is pressed 4 times in succession, THEN focus moves Continue → NewGame → PersonnelFile → CloseFile and wraps to Continue on the 5th press. Reverse: Shift+Tab × 4 cycles backward in the same order.
- **AC-MMUX-2.3 [Logic] [BLOCKING]** GIVEN MainMenu MVP mounted with slot 0 EMPTY/CORRUPT (NewGameButton hidden — assuming Open Question #1 resolves to "hide"), WHEN Tab is pressed in succession, THEN focus moves Continue → PersonnelFile → CloseFile and wraps. NewGameButton is excluded from tab order. **Resolution-dependent**: if Open Question #1 resolves to "always show NewGameButton", this AC instead asserts the 4-button order from AC-MMUX-2.2.
- **AC-MMUX-2.4 [Logic] [BLOCKING]** GIVEN MainMenu mounted with `Context.MENU` on stack and no modal/sub-screen active, WHEN `ui_cancel` (Esc/B) is pressed, THEN no UI change occurs — no modal opens, focus state is preserved, no SFX plays. Verifies CR-9 / AC-MENU-11.1 from UX-side.
- **AC-MMUX-2.5 [Logic] [BLOCKING]** GIVEN any modal mounted (Quit-Confirm, Photosensitivity, New-Game-Overwrite, Save-Failed), WHEN Tab is pressed, THEN focus cycles only within the modal — no Tab press can move focus to Z2 buttons or any element outside the modal until the modal is dismissed. Verifies `modal-scaffold` focus-trap pattern from UX-side.

### Slot 0 Label-Swap

- **AC-MMUX-3.1 [Logic] [BLOCKING]** GIVEN slot 0 in OCCUPIED state, WHEN MainMenu rendered, THEN `ContinueButton.text == tr("menu.main.continue")` and English string == "Resume Surveillance". *(Mirrors AC-MENU-3.1 from GDD.)*
- **AC-MMUX-3.2 [Logic] [BLOCKING]** GIVEN slot 0 in EMPTY or CORRUPT state, WHEN MainMenu rendered, THEN `ContinueButton.text == tr("menu.main.continue_empty")` and English string == "Begin Operation"; AND the button width is the same as in OCCUPIED state (AC-MMUX-1.1 outer margin invariant holds — width budgeted to fit the longer label per locale, max("Resume Surveillance", "Begin Operation") → "Resume Surveillance" in English).
- **AC-MMUX-3.3 [UI] [ADVISORY]** GIVEN slot 0 EMPTY and ContinueButton focused with screen reader active, WHEN focus lands on Continue, THEN AT announces the new label "Begin Operation" — not the previous "Resume Surveillance". Manual walkthrough doc filed at `production/qa/evidence/`.

### Performance

- **AC-MMUX-4.1 [Integration] [BLOCKING]** GIVEN cold boot on minimum-target hardware, WHEN measured from `MainMenu._ready()` start to first frame where ContinueButton has focus AND `process_input == true`, THEN elapsed time < 2000 ms (excluding photosensitivity-modal display time, which is bounded only by user dismiss).
- **AC-MMUX-4.2 [Logic] [BLOCKING]** GIVEN ContinueButton activated with slot 0 OCCUPIED, WHEN measured from button-press to `LS.transition_to_section()` call, THEN elapsed time ≤ `menu_music_fade_out_ms` + 50 ms tolerance (default 800 + 50 = 850 ms). Verifies CR-6 fade-then-LS invariant from UX-side.

### Accessibility

- **AC-MMUX-5.1 [Integration] [BLOCKING]** GIVEN MainMenu MVP mounted, WHEN AccessKit tree is queried, THEN every interactive Control has a non-empty `accessibility_role` AND non-empty `accessibility_name`. Verifies Day-1 MVP per ADR-0004 IG10.
- **AC-MMUX-5.2 [Integration] [BLOCKING]** GIVEN PersonnelFileButton, WHEN `accessibility_description` is read, THEN it equals `tr("menu.main.settings.desc")` and English string == "Adjust audio, graphics, accessibility, and control settings." *(Mirrors AC-MENU-5.3.)*
- **AC-MMUX-5.3 [Integration] [BLOCKING]** GIVEN any modal mounted, WHEN modal first appears, THEN modal root has `accessibility_live == "assertive"` for one frame, then `accessibility_live == "off"` next frame (one-shot pattern via `call_deferred` per CR-21).
- **AC-MMUX-5.4 [Logic] [BLOCKING]** GIVEN any 2 adjacent UI elements where contrast matters (button label vs button fill; button focus vs background), WHEN sampled with WCAG contrast formula, THEN ratio ≥ 7:1 for ≥ 18 px text, ≥ 4.5:1 for body. Build stamp (12 px, 30% opacity — Open Question #5) is excluded from this AC pending resolution.
- **AC-MMUX-5.5 [Logic] [BLOCKING]** GIVEN `Settings.reduced_motion == true`, WHEN MainMenu is rendered AND any modal is mounted/dismissed, THEN no animation behaves differently than when `reduced_motion == false` — Main Menu is fully snap-cut by design.

### Localization

- **AC-MMUX-6.1 [Integration] [BLOCKING — before any non-EN locale ships]** GIVEN MainMenu mounted with active locale, WHEN locale is changed via Settings → dismissed, THEN: (a) `NOTIFICATION_TRANSLATION_CHANGED` propagates to Main Menu within the same frame; (b) all Label `text` values re-resolve to new-locale strings; (c) `accessibility_name` and `accessibility_description` on every Control re-resolve. Verifies `auto-translate-always` + `accessibility-name-re-resolve` patterns from UX-side.
- **AC-MMUX-6.2 [UI] [ADVISORY]** GIVEN MainMenu rendered in FR locale at 100% ui_scale, WHEN any button label is inspected, THEN no label is truncated (Godot `Label.get_visible_line_count() == 1` for every button label) AND no label clips outside its button rect. Per Open Questions #6, #7, #8 — translator brief shortens any overflow before this AC passes.
- **AC-MMUX-6.3 [UI] [ADVISORY]** GIVEN MainMenu rendered with build version 0.1.4 in active locale, WHEN footer is inspected (VS only), THEN format == "bqa/65 build 0.1.4" with localized "build" word substituted (e.g., FR "version", DE "Build" — final translations TBD).

### State Transitions

- **AC-MMUX-7.1 [Logic] [BLOCKING]** GIVEN MainMenu mounted with no modal, WHEN ContinueButton is activated AND music fade is in progress, THEN ContinueButton.disabled == true on the FIRST frame after activation (re-entrant guard per AC-MENU-4.3.a / AC-MENU-4.4).
- **AC-MMUX-7.2 [Logic] [BLOCKING]** GIVEN cold boot with `_boot_warning_pending == true`, WHEN `MainMenu._ready()` runs, THEN ALL Z2 buttons have `process_input == false` BEFORE `ModalScaffold.show_modal()` returns, no `await` is used between the two operations, and `Context.MODAL` is on stack after `show_modal()`. Verifies CR-8 / AC-MENU-1.3.

**Total**: 18 UX-specific ACs (3 Visual, 5 Navigation/Focus, 3 Slot-0 Label-Swap, 2 Performance, 5 Accessibility, 3 Localization, 2 State Transitions). Cross-references to GDD ACs noted where this spec narrows scope rather than adds new behavior.

---

## Open Questions

All Open Questions raised throughout this spec, consolidated. Each carries an owner + recommended resolution + decision deadline (relative to MVP / VS / Polish phases).

| # | Question | Where raised | Owner | Recommended resolution | Decision needed by |
|---|---|---|---|---|---|
| **1** | When slot 0 is EMPTY/CORRUPT, the Continue button label-swaps to "Begin Operation" which serves as the start-fresh entry. Does the New Game button ("Open New Operation") **hide** in this state, or **remain visible** as a redundant entry? | Section C.1 + C.3 + I (AC-MMUX-2.3 is resolution-dependent) | game-designer + ux-designer | **Recommended: HIDE** — when "Begin Operation" is the Continue button label, NewGameButton has no semantic distinction; showing both creates UX ambiguity. CR-6 implicitly supports this (the conditional confirm-modal logic only makes sense if NewGameButton is the sole "start fresh" path, distinct from Continue's resume-OR-start-fresh-with-confirm logic). | Before MVP sprint kickoff |
| **2** | Mouse-click-outside default policy on modals (Quit-Confirm, New-Game-Overwrite, Save-Failed) — should outside-click trigger Cancel, trigger nothing, or close the modal? | Section E + interaction-patterns.md Open Question #1 (already flagged at library level) | ux-designer + accessibility-specialist | **Recommended: trigger Cancel** (per `dual-focus-dismiss` pattern). Save-Failed exception: outside-click triggers nothing (player must explicitly choose Retry or Abandon). | When Quit-Confirm UX spec is authored |
| **3** | Build/version stamp footer — MVP or VS scope? | Section C.1 (item #7) | producer + qa-lead | **Recommended: VS** — keeps MVP layout invariant simple; pre-production QA can use Project Settings inspection or CLI tools for build-version verification. | Before MVP sprint kickoff |
| **4** | ContinueButton in EMPTY/CORRUPT state — `accessibility_description` "Start a new operation. No saved file detected." — does this leak game-state info that conflicts with Pillar 5 register? "No saved file detected" is modern-game-launcher prose. | Section G (AccessKit table) | ux-designer + accessibility-specialist + narrative-director | **Recommended: rephrase to** *"Begin a new operation. The previous file is closed."* — matches Case File register; communicates the state without modern launcher diction. AT users get the period register too. | Before VS sprint (FR/DE locale work depends on this) |
| **5** | Build stamp at 30% opacity — does this meet WCAG SC 1.4.3 (4.5:1 minimum contrast for normal text)? | Section G (text contrast table) | accessibility-specialist | **Recommended: raise to 50% opacity** (~4.5:1) OR explicitly flag build stamp as "decorative" per WCAG informative carve-out. Author opinion: decorative classification is correct (no informational value at the SC 1.4.3 level — it's a print convention, not user-facing data). | Before VS playtest sign-off |
| **6** | FR translation of "Open New Operation" — likely overflows button width at 100% ui_scale ("Ouvrir une nouvelle opération" ~30 chars vs ~25 budget). | Section H (string inventory) | localization-lead + writer | **Recommended: shorten FR translation to "Nouvelle opération" (18 chars).** Avoid font scale-down — that breaks layout consistency across locales. | Before FR locale ships |
| **7** | FR translation of "Close File" — "Fermer le dossier" (17 chars) vs ~14 budget at 100% ui_scale. | Section H | localization-lead + writer | **Recommended: shorten FR translation to "Fermer" (6 chars).** Watch for register loss — "Fermer" alone is generic; "Fermer le dossier" preserves Pillar 5 voice. Translator-brief should note this trade-off. | Before FR locale ships |
| **8** | BQA acronym + period stamps in title sub-stamp — translate "CASE FILE" → "DOSSIER" / "AKTE", or keep untranslated? | Section H | narrative-director + localization-lead | **Recommended: translate "CASE FILE" only** (keep "BQA/65" untranslated as period-acronym). FR: "DOSSIER BQA/65"; DE: "AKTE BQA/65". Preserves period inconsistency intentionally. | Before VS sprint |
| **9** | Title sub-stamp at 18 px vs menu UI floor at 24 px — does the sub-stamp need to scale up, or is it decorative (HUD-floor exception)? | Section G (minimum text sizes) | accessibility-specialist + art-director | **Recommended: classify as decorative** (per art-bible §7B condensed register intent) AND ensure the AccessKit `accessibility_description` on the title block conveys the same info ("BQA/65 Case File header"). The 18 px sub-stamp is supplementary to the 96 px main title. | Before VS playtest sign-off |
| **10** | Should the title block (Z1) be elevated from VS to MVP scope, given that MVP-without-title risks reading as "unfinished" rather than "minimalist"? | Section C.2 (conflict note) | producer + ux-designer + art-director | **Recommended: defer decision to first MVP playtest.** Ship MVP without title; observe playtester reactions. If 30%+ of playtesters comment "it looks unfinished" or similar, elevate Z1 to MVP in patch 1. Otherwise keep VS. | Decision deferred to MVP playtest report |

**Cross-reference**: Open Questions #6, #7, #8 also feed into `design/gdd/localization-scaffold.md` translator-brief work. Open Questions #4, #9 feed into `design/accessibility-requirements.md` Visual Accessibility table updates.
