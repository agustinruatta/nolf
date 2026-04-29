# Menu System

> **Status**: In Design — Revised 2026-04-27 per /design-review (12 BLOCKING items resolved; 38 RECOMMENDED items deferred to fast-follow)
> **Author**: user + ux-designer + art-director + game-designer + creative-director + godot-specialist + audio-director + accessibility-specialist + qa-lead + systems-designer + performance-analyst + localization-lead
> **Last Updated**: 2026-04-27
> **Implements Pillar**: Primary 5 (Period Authenticity Over Modernization); Supporting 1 (Comedy Without Punchlines), Supporting 3 (Stealth is Theatre, Not Punishment)
> **Phasing**: Single GDD with per-section **[MVP]** / **[VS]** tags. **Day-1 MVP slice** = photosensitivity boot-warning modal scaffold + Settings entry-point + minimal Main Menu shell (HARD MVP-DEP per HUD Core REV-2026-04-26 D2 + Settings & Accessibility CR-18 / OQ-SA-3). **Full VS scope** = Main Menu / Pause Menu / Load Game grid / Save Game grid / save-failed dialog / quit-confirm / mission dossier card.

## Overview

Menu System is *The Paris Affair*'s **player-facing chrome layer plus the modal-scaffold and scene-handoff infrastructure** that surrounds the actual game. As a data layer it owns: the `MainMenu.tscn` boot scene loaded via `get_tree().change_scene_to_file()` at application start (Level Streaming **CR-7** — the menu is not a section), the `InputContext.MENU` / `InputContext.PAUSE` / `InputContext.SETTINGS` push/pop lifecycle per ADR-0004, the modal scaffold node that hosts the photosensitivity boot-warning dialog (Settings **CR-18 / OQ-SA-3**, Day-1 MVP, scaffold polls `SettingsService._boot_warning_pending` in `_ready()` and gates main-menu interactivity until the modal closes), the save-card grid renderers that read sidecar metadata via `SaveLoad.slot_metadata(N)` (ADR-0003: Menu never opens `.res` directly), and the LS-allowlisted call-site for `LevelStreaming.transition_to_section()` per LS **CR-4** — Menu fades out menu music, then calls `transition_to_section(first_section_id, null, NEW_GAME)` (New Game) or `SaveLoad.load_from_slot(N)` → `transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)` (Load Game), and registers a step-9 restore callback (LS L55). As a player-facing surface it is the **mission-dossier card register** (Art Bible 7D) — every screen, button, and dialog is staged as a 1965 BQA case file, not as modern game-menu chrome: Main Menu (Continue / New Game / Load Game / Settings / Quit), Pause Menu (Resume / Save Game / Load Game / Settings / Restart from Checkpoint / Main Menu / Quit Desktop), Load Game (8-slot grid; slot 0 visible per Save/Load **CR-10**), Save Game (Pause-only 7-slot grid per Save/Load **CR-11**), the save-failed dialog (subscribes `Events.save_failed` per Save/Load **CR-9**, ADR-0002 Save domain), the quit-confirm modal, and the shared modal-scaffold container that Settings & Accessibility **CR-18** mounts the photosensitivity warning into. Menu System pushes `InputContext.MENU` (Main Menu) / `Context.PAUSE` (Pause Menu) per ADR-0004 and uses the `_unhandled_input()` + `ui_cancel` modal-dismiss pattern (ADR-0004 §97 — sidesteps Godot 4.6's dual-focus split, pending Gate 1 verification). It is **NOT autoload** (ADR-0007: MainMenu.tscn is the boot scene; Pause Menu is a per-section CanvasLayer overlay), subscribes only (ADR-0002: emits no domain signals at MVP), and inherits `project_theme.tres` via per-surface child Themes (ADR-0004, pending Gate 2 verification on `base_theme` / `fallback_theme`). This GDD covers a **Day-1 MVP slice** — photosensitivity boot-warning modal scaffold + Settings entry-point button + minimal Main Menu shell (Continue / New Game / Settings / Quit, no Load Game grid) — that closes the HARD-MVP gate raised by HUD Core REV-2026-04-26 D2 and Settings & Accessibility OQ-SA-3, plus the **full Vertical Slice scope** — every player-facing screen above with the full mission-dossier-card aesthetic. **This GDD defines**: every menu screen the player can reach, the modal-scaffold contract, the InputContext push/pop discipline, the LS / SaveLoad caller pattern, the menu-music handoff to Audio, the focus and AccessKit semantics for each surface, and the Pillar 5 forbidden patterns that keep modern UX paternalism out. **This GDD does NOT define**: the Settings panel's internal layout (Settings & Accessibility #23 owns its HSplitContainer at CanvasLayer 10 + the photosensitivity-warning copy, dismissed-flag persistence, and `[Show Photosensitivity Notice]` button); the save serialization format (Save/Load + ADR-0003 own — Menu reads sidecar via `slot_metadata(N)` only); the section scene loading and step-9 callback machinery (LS owns); the menu music asset selection or fade curve (Audio owns; Menu only triggers fade-out before NEW_GAME LS call per LS L201); HUD widgets (HUD Core #16 owns); Document Overlay (#20 owns its own modal); Cutscenes (#22 owns); and the typography / color palette of the mission-dossier card itself (Art Bible 7D + ADR-0004 Theme own — Menu specifies which Theme node hierarchy renders which screen).

## Player Fantasy

**Fantasy: "The Case File."** When the player presses `Esc` mid-patrol, the screen does not dim with a translucent grey overlay. A manila folder slides onto the desk from the bottom-right of the screen with the sound of a paper drawer closing — the tab reads **STERLING, E. — OPERATION TOUR D'IVOIRE — EYES ONLY — BQA/65**. Inside is a typed index card listing the player's options: **Resume Surveillance / Save Dispatch / Load Dispatch / Adjust Equipment / Abort Mission / Close File**. The cursor is a fountain-pen nib. The player is not a paused gamer; the player is the case officer at BQA Registry who has paused the operation to consult the file. Every menu interaction is a bureaucratic act on Eve's behalf — typing a name onto a carbon-copy save form, stamping a destructive action with `CASE CLOSED`, advancing a slide of intelligence photographs from the Eiffel Tower archive.

This fantasy lands when the player learns, by the third or fourth pause, that the menu is **not getting in their way** — it is part of the same world the operation lives in. Eve is still on the platform; the dispatcher is just consulting the file before letting her continue.

**Register:**

- **Visual.** Manila folder, carbon paper, photographic surveillance imagery, BQA seal, French/English bilingual stamps where appropriate (`VU PAR`, `CONFIDENTIEL`). Typewriter Courier (body copy) + a stamped sans-serif (headers / labels) per Art Bible 7B/7D + ADR-0004 FontRegistry (American Typewriter for body, Futura/DIN for headers per the project's locked typography). Red `EYES ONLY` band on every screen header. The Case File never goes fullscreen-modal — it is always *on the desk*; gameplay frame-buffer can be visible behind a darkened-but-not-blurred desk surround.
- **Language.** Bureaucratic-neutral. **"Save Dispatch"** not "Save Game". **"Resume Surveillance"** not "Resume". **"Abort Mission"** not "Quit to Main Menu". **"Personnel File"** for Settings entry-point. **"Operations Archive"** for Load Game. Save slots are dated dispatches: *Dispatch 03 — Tour Eiffel, niveau 2 — 14:23 GMT*. The save-failed dialog is not an error popup; it is a stamped form: ***DISPATCH NOT FILED — RETRY***. The quit-confirm is not a modal popup; it is a stamped form: ***CLOSE FILE — Y/N***. The boot photosensitivity warning (Settings CR-18, locked 38-word body) is presented as an *Operational Advisory* card at the front of the file — period-stamped, not modern medical-warning chrome. Eve never speaks in any of these strings. The bureaucracy is the joke. *Get Smart* CONTROL files rendered with absolute seriousness.
- **Audio.** Typewriter clack on confirm, paper-shuffle on screen transition, drawer-slide on open and close, rubber-stamp thud on destructive actions (Quit, Delete Save, Restart Checkpoint). No menu music *during* menus; menu music is reserved for the boot main menu only and fades out before the LS `NEW_GAME` call (LS L201). All UI-bus, not voice-bus, so dialogue can never collide with menu foley.

**Pillar map:**

- **Primary 5: Period Authenticity Over Modernization.** Every surface is 1965 BQA tradecraft, no pixel of modern game-launcher chrome. The fantasy *is* Pillar 5 at full volume — there is no "non-diegetic carve-out" needed at the Menu shell because the Case File register is wholly diegetic. (Settings & Accessibility's Stage-Manager carve-out continues to apply *inside* the Personnel File sub-screen at the panel level — that boundary is already drawn in the locked Settings GDD; this GDD does not relitigate it.)
- **Primary 1: Comedy Without Punchlines.** The bureaucratic register is the joke. *Get Smart*'s rigid file-and-stamp protocol applied to a stealth operation is inherently funny when rendered with absolute seriousness. The Case File never winks. Eve does not crack wise. The world quips around her — `EYES ONLY` on the boot warning, *VU PAR* stamps where modern menus would say "Last played", `CASE CLOSED` instead of "Quit to Desktop". Pillar 1 gets distributed coverage from Document Collection / Dialogue / Mission Scripting / Civilian AI / Cutscenes; Menu System adds itself to that list as the **ambient comedy layer the player traverses on every session boot, save, and quit**.
- **Supporting 3: Stealth is Theatre, Not Punishment.** Pausing mid-patrol is a dispatcher conferring with HQ, not a god-mode timeout — the operation is held, not interrupted. The Save-Failed dialog is a stamped form, not a punishment screen. The Pause Menu's `Restart from Checkpoint` is *Re-Brief Operation*, not a reload-from-failure mea culpa. Even the moment of failure is staged as theatre, never administered as punishment.

**Five explicit refusals** (what this fantasy explicitly rejects):

1. **No translucent grey pause overlay.** Pause is a physical object (the manila folder) on the desk, not a transparent UI layer slid over gameplay. If a pause UI is described in any future GDD revision as "fade gameplay to 40% alpha and overlay buttons," reject it.
2. **No "Quit to Main Menu" / "Quit to Desktop" verbiage anywhere.** The strings are *Return to Registry* and *Close File*. Modern game-launcher language is the most sensitive tell — it betrays the period instantly.
3. **No save thumbnails / screenshots in the slot grid.** Carbon-copy forms with typed metadata only. A live screenshot of the Eiffel Tower mid-patrol breaks the fiction that this is paper. (Save/Load OQ "should the HUD be visible in the save thumbnail?" — answered by this refusal: *no thumbnail at all*.)
4. **No real-world clock on save timestamps.** Dispatches are stamped with *in-mission* time and section name (`niveau 2 — 14:23 GMT`), not "Saved 4 minutes ago." Real-world wall-clock time is modern game-launcher chrome.
5. **No animated transitions other than paper movement.** No crossfades, no Material Design slide-ins, no parallax scroll, no card-flip animations. Things enter as paper enters: dropped, pulled, stamped, advanced. Animation curves are mechanical, not eased.

**Fantasy test for future menu additions:**

> *"If a menu element couldn't have been printed, typed, stamped, or filed in 1965, it doesn't ship."*

This rule is the first thing future GDD revisions, art-spec briefs, and `/ux-design` calls for Menu screens must satisfy before any other consideration. If a proposed addition fails this test, it must either be rejected or moved into Settings' Stage-Manager carve-out (and only if it is genuinely accessibility-load-bearing).

**Cross-register continuity.** The Case File's bureaucratic-neutral voice harmonizes with the project's other locked registers: HUD Core's "The Glance" (cockpit-dial silence until the moment it isn't), Settings & Accessibility's "The Stage Manager" (backstage friction-removal so the play can land), Inventory's "The Crouched Swap" (deliberation between two stealth solutions), and Civilian AI's "Stealth With Witnesses" (the audience makes the theatre literal). All five registers share three traits: **dry, restrained, anchored to a specific staged moment, never quippy.** The Case File adds the *bureaucratic* register to the project's voice family — no other locked GDD owns it, and Pillar 1 needs a system that does.

## Detailed Design

### C.1 Core Rules

Numbered rules; each tagged **[MVP]** (Day-1 slice) or **[VS]** (full Vertical Slice). The CR list is the authoritative behaviour specification — every rule below must hold for the GDD to ship.

**[MVP] CR-1 — `MainMenu.tscn` is the application boot scene.** Set as **Main Scene** in Project Settings → Application → Run → Main Scene. Engine loads it directly on cold boot — there is no `change_scene_to_file()` call on cold boot. The `change_scene_to_file()` path (LS CR-7) applies only to the *return-to-Main-Menu-from-gameplay* case (Pause → Return to Registry, future post-mission completion). Menu System is **NOT autoload** (ADR-0007). All Menu logic lives in scenes and per-scene scripts; no autoload registration.

**[MVP] CR-2 — InputContext push/pop discipline.** Main Menu pushes `InputContext.MENU` in its `_ready()` and pops it before calling `LS.transition_to_section()` or before `get_tree().quit()`. Pause Menu pushes `InputContext.PAUSE` on mount and pops on unmount. Modals push `InputContext.MODAL` on appearance and pop on dismiss. Loading transitions push `InputContext.LOADING` immediately before `SaveLoad.load_from_slot()` (popped implicitly when LS scene change destroys the menu tree). All input is consumed via `_unhandled_input()` checking `event.is_action_pressed(&"ui_cancel")` per ADR-0004 §97 (sidesteps Godot 4.6 dual-focus split). Raw `KEY_ESCAPE` is never tested. **[BLOCKING coord]** ADR-0004 amendment: add `Context.MODAL` and `Context.LOADING` enum values to `InputContextStack.Context` (this amendment closes one open gap from the Settings GDD's modal scaffold spec and one from the F&R revision item #4 simultaneously).

**[MVP] CR-3 — Pause Menu availability gate.** Pause Menu is only mountable when `InputContextStack.peek() == InputContext.GAMEPLAY`. A `pause` action input in any other context (MENU, SETTINGS, LOADING, MODAL, PAUSE itself) is silently consumed and produces no effect. The `pause` action is owned by the Input GDD (mapped to `Esc` / `JOY_BUTTON_START`). Menu does not register `pause` directly — it consumes the action in `PauseMenuController._unhandled_input()` (see CR-4).

**[VS] CR-4 — Pause Menu is a CanvasLayer overlay, not a scene change.** A lightweight `PauseMenuController` `Node` script lives on each section scene root (or on the project's `SectionRoot` base script if one exists — TBD with level-streaming team, see Open Questions). On `pause` action while `InputContext.current() == GAMEPLAY`, it instantiates `PauseMenu.tscn` (preloaded `const`), `add_child`s it to `get_tree().current_scene`, and pushes `InputContext.PAUSE`. On Pause Menu close, it `queue_free`s the instance and pops the context. Menu does NOT call `get_tree().paused = true` — the world remains visible behind the desk overlay; only player input is gated by InputContext. (Music continues uninterrupted from gameplay during Pause per Audio §L378 — the section's `[section]_calm` or `[section]_alert` track keeps playing; menu foley sits on UI bus.)

**[MVP] CR-5 — Continue button label-swap semantics.** If `SaveLoad.slot_metadata(0)` returns a non-null, non-empty Dictionary AND state ≠ CORRUPT, the Main Menu's Continue button is enabled and labelled `tr("menu.main.continue")` ("Resume Surveillance"). On activation: fade menu music to silence (CR-20), then call `SaveLoad.load_from_slot(0)` → `LevelStreaming.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)` → register step-9 restore callback (LS L55). If slot 0 is empty/absent/corrupted, the button label swaps to `tr("menu.main.continue_empty")` ("Begin Operation"). **Activation in this state ALWAYS opens the New-Game-Overwrite confirm modal** (`ModalScaffold.show_modal(NewGameOverwriteContent)`) regardless of slots 1–7 state — see CR-6 amendment. Same button position, same focus target — the label is the only visual feedback at rest, but activation gates a destructive operation behind a confirm step. **Decision: design-review 2026-04-27 — silent fall-through to New Game flow rejected as destructive UX risk for returning players whose slot 0 is corrupted.** No "no save found" dialog at rest (Pillar 5 silent register on the button itself preserved); confirm-on-activation is the safety mitigation.

**[MVP] CR-6 — New Game flow.** The Main Menu's New Game / "Begin Operation" button opens the New-Game-Overwrite confirm modal scaffold (`tr("menu.new_game_confirm.title")` → "OPEN NEW OPERATION"; body: per §C.8 `body_alt`; default focus: Cancel) under the following conditions:
- **Always** when activated from the "Begin Operation" label (slot 0 corrupt/empty per CR-5) — closes the destructive-silent-swap risk identified in design-review 2026-04-27.
- **Always** when activated from the "Open New Operation" label AND slot 0 is the player's only progress (slots 1–7 all empty).
- **Skipped (proceeds directly)** when activated from the "Open New Operation" label AND at least one of slots 1–7 is non-empty (player has manual saves; the autosave is not their only progress).

On confirm: **set `button.disabled = true` immediately on first press** (prevents re-entrant music-fade coroutine per §E Cluster H case 3); fade menu music to silence on the `MAIN_MENU` bus (Audio L97) over `menu_music_fade_out_ms` (default 800 ms; tuning knob), `await` fade completion, push `Context.LOADING`, call `LevelStreaming.transition_to_section(first_section_id, null, NEW_GAME)`. Menu does NOT call `SaveLoad` for New Game — slot 0 is created later by LS's first autosave trigger. **[Decision: user adjudicated — confirm modal ALWAYS opens on slot-0-corrupt/empty path AND on slot-0-only-progress path; skipped only when manual saves exist.]**

**[MVP] CR-7 — Settings entry-point button.** The `tr("menu.main.settings")` button ("Personnel File") on Main Menu and `tr("menu.pause.settings")` button on Pause Menu calls `SettingsService.open_panel()`. Settings (system #23) owns its `CanvasLayer 10` HSplitContainer panel + its own `InputContext.SETTINGS` push/pop + its own dismiss. Menu re-activates on Settings dismiss when InputContext returns to `MENU` or `PAUSE`. The Settings button has `accessibility_description = tr("menu.main.settings.desc")` ("*Adjust audio, graphics, accessibility, and control settings.*") because "Personnel File" is the one Case File label genuinely ambiguous to first-time AT users (per accessibility-specialist).

**[MVP] CR-8 — Photosensitivity boot-warning poll.** In `MainMenu._ready()`, after `ModalScaffold` is instantiated as a child of MainMenu and `InputContext.MENU` is pushed, but BEFORE any Main Menu button is interactive: synchronous read of `SettingsService._boot_warning_pending: bool` (Settings GDD CR-18). If `true`: call `ModalScaffold.show_modal(PhotosensitivityWarningContent)` which pushes `Context.MODAL` and disables the Main Menu button container via `set_process_input(false)`. The modal's *Continue* button (default focus per Settings GDD CR-18 — *button label canonicalised to "Continue" 2026-04-29 per `design/ux/photosensitivity-boot-warning.md` OQ #8*) calls back to `SettingsService.dismiss_warning()` which sets `accessibility.photosensitivity_warning_dismissed = true` and emits `setting_changed`; the modal then closes via `ModalScaffold.hide_modal()`, pops `Context.MODAL`, calls `set_process_input(true)` on the Main Menu button container, and restores focus to the Continue button on Main Menu (label "Resume Surveillance" if slot 0 OK, "Begin Operation" if slot 0 empty/corrupt — per CR-5). If `_boot_warning_pending == false`: no modal mounts; main menu interactive immediately. **No `await`** — autoload ordering (SettingsService autoload slot owned by ADR-0007 §Canonical Registration Table; MainMenu loads after all autoloads `_ready()` complete) guarantees `_boot_warning_pending` is fully committed before `MainMenu._ready()` reads it. *(2026-04-28: stale "slot 8" reference corrected to "per ADR-0007" — current canonical slot is 10; ADR-0007 IG7 forbids restating slot numbers in GDDs.)*

**[MVP] CR-9 — Quit-to-Desktop ("Close File") flow.** [REVISED 2026-04-29 per `design/ux/quit-confirm.md` OQ #2 — cancel button label canonicalised to "Continue Mission" per locked string table line 342 + AC-MENU-7.1 (the prior prose "Return to File" was stale).] The Main Menu's `tr("menu.main.quit")` button ("Close File") calls `ModalScaffold.show_modal(QuitConfirmContent)`. Body copy: `tr("menu.quit_confirm.body_alt")` ("*Operation abandoned.*"). Two buttons: *Close File* (destructive — Ink Black header band + button fill) and *Continue Mission* (default focus — BQA Blue button fill). On *Close File*: pop `Context.MENU`, call `get_tree().quit()`. On *Continue Mission* or `ui_cancel`: dismiss modal, return focus to the Quit button. **No save is triggered automatically on quit** — the player is responsible for explicit saves. Same ModalScaffold pattern is reused for Pause Menu's Quit-Desktop entry, Pause Menu's Return-to-Registry entry, Pause Menu's Re-Brief Operation entry (CR-13), and the New-Game-overwrite confirm (CR-6).

**[MVP] CR-10 — Save-failed dialog subscription.** Menu System (both `MainMenu` and `PauseMenu` while mounted) subscribes to `Events.save_failed(reason: SaveLoad.FailureReason)` (ADR-0002 Save domain) on `_ready()` and unsubscribes in `_exit_tree()` per ADR-0002 §Impl-Guideline-3 with `is_connected()` guard. On signal receipt: call `ModalScaffold.show_modal(SaveFailedContent)` populated with the reason string. Body copy: `tr("menu.save_failed.body_alt")` ("*Write error. Retry?*"). PHANTOM Red header band: *DISPATCH NOT FILED*. Two buttons: *Retry* (default focus, attempts the most-recent save target) and *Abandon*. The dialog is **non-blocking**: the host menu (Main or Pause) does NOT disable underlying controls — the modal sits above as an overlay. This is intentional per Save/Load CR-9 ("non-blocking dialog"). `accessibility_live = "assertive"` on appearance (high-stakes loss event) → cleared to `"off"` next frame via `call_deferred` (one-shot pattern).

**[VS] CR-11 — Load Game grid (8-slot, 2 cols × 4 rows).** Accessible from Main Menu *and* Pause Menu via the Operations Archive button. Renders an 8-slot grid in a `GridContainer` with `columns = 2`. Slot 0 occupies the top-left cell with BQA Blue 2 px left-border accent + `AUTO-FILED` stamp + `tr("menu.save.card_slot_zero")` header — visually differentiated but not segregated (per Save/Load CR-10). Slots 1–7 fill left-to-right, top-to-bottom. Cards read sidecar metadata via `SaveLoad.slot_metadata(N)` (ADR-0003 — never opens `.res` directly). On slot selection (any state but EMPTY/CORRUPT): fade menu music to silence, push `Context.LOADING`, call `SaveLoad.load_from_slot(N)` → `transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)`. Selecting EMPTY slot: focus is allowed (announced as available) but activation does nothing (button `disabled = true`). Selecting CORRUPT slot: button `disabled = true`; AccessKit announces *"Dispatch {slot}. File damaged. Cannot load."*

**[VS] CR-12 — Save Game grid (Pause-only, 7-slot, 2 cols × 3 rows + 1).** Accessible from Pause Menu only via the File Dispatch button. Renders 7 slots (1–7) in a `GridContainer` with `columns = 2`: rows 1–3 hold pairs; row 4 holds slot 7 alone in column 0 (column 1 of row 4 is absent — empty cell, not focusable). Slot 0 NOT shown per Save/Load CR-11. Cards read `slot_metadata(N)` same as Load grid. **In-card overwrite confirm**: selecting an OCCUPIED slot swaps the card face inline (no modal opens): top text becomes `tr("menu.save.confirm_overwrite")` ("*Overwrite Dispatch 03?*"); the body area collapses to two focusable buttons inside the same card — `[CANCEL]` (default focus, bottom-left of card) and `[CONFIRM]` (bottom-right). `ui_cancel` triggers `[CANCEL]` inline (returns card to normal OCCUPIED state, does NOT close the Save grid — two `ui_cancel` presses required to exit the grid from an in-confirm state). On `[CONFIRM]`: call `SaveLoad.save_to_slot(N)`. Selecting EMPTY slot: write immediately (`SaveLoad.save_to_slot(N)`) — empty slots have no overwrite-confirm because there is nothing to lose. **No thumbnail; no screenshot; no live preview** (per Pillar 5 Refusal 3).

**[VS] CR-13 — Re-Brief Operation (Restart from Checkpoint).** Pause Menu surfaces the *Re-Brief Operation* button only when `FailureRespawn.has_checkpoint() == true` (button is hidden, not disabled, when no checkpoint exists — at MVP the button never shows because mid-section checkpoints are not implemented). On activation: open ModalScaffold confirm (`RE-BRIEF OPERATION` Ink Black header; body: `tr("menu.rebrief.body_alt")` "*Reload last checkpoint?*"; default focus: Cancel). On confirm: call `FailureRespawn.restart_from_checkpoint()`. **[BLOCKING coord]** F&R GDD must add public query API `has_checkpoint() -> bool` (currently not specified). String never appears as "Restart from Checkpoint" or "Checkpoint" anywhere in the UI — Case File register is *Re-Brief Operation* exclusively.

**[VS] CR-14 — Return to Registry (Main Menu from Pause).** Pause Menu surfaces *Return to Registry* button. On activation: open ModalScaffold confirm (`RETURN TO REGISTRY` Ink Black header; body: `tr("menu.return_registry.body_alt")` "*Unsaved progress lost.*"; default focus: Cancel). On confirm: pop `Context.PAUSE`, fade gameplay music if Audio supports a fade-on-section-exit (Audio coord item — currently audio fades on `section_exited` per Audio § Mission domain, so this happens for free), call `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")`. The destructive scene change destroys the section + Pause Menu trees; MainMenu loads fresh. On Cancel or `ui_cancel`: dismiss modal.

**[VS] CR-15 — Quicksave / Quickload feedback.** F5 (Quicksave) and F9 (Quickload) actions are owned by Save/Load (Save/Load CR-5). Menu System provides only ephemeral status feedback per Save/Load L111: a small stamped status card (BQA Blue header band, `DISPATCH FILED` for save / `DISPATCH LOADED` for load) appears in the bottom-right corner of the screen for 1.4 seconds (tuning knob `quicksave_feedback_duration_s`, default 1.4 s) then fades out. The card is read-only — Menu does not initiate the save/load itself. This feedback widget is **NOT a ModalScaffold modal** — it does not push InputContext; gameplay continues uninterrupted; it is a HUD-adjacent ephemeral overlay. Subscribes to `Events.game_saved(slot, section_id)` (filtered for slot == 0 = autosave / quicksave) and `Events.game_loaded(slot)` (filtered for slot == 0 = quickload).

**[VS] CR-16 — Mission dossier card backdrop.** The Main Menu background is a static mission-dossier card per Art Bible §7D: surveillance photography of the Eiffel Tower with stamped intelligence metadata. Not interactive at MVP. At VS the same dossier card is referenced by Cutscenes & Mission Cards (system #22) for mission-briefing transitions — coord item with that GDD.

**[VS] CR-17 — Gamepad navigation.** All menu screens support full gamepad navigation (D-pad / left-stick on `ui_up/down/left/right`, `JOY_BUTTON_A` on `ui_accept`, `JOY_BUTTON_B` on `ui_cancel`). Keyboard/Mouse is primary per `.claude/docs/technical-preferences.md`. Gamepad menu navigation is VS scope. **Mouse cursor**: when in any menu surface, the system cursor is replaced by the fountain-pen-nib cursor sprite (`ui_cursor_fountain_pen_nib_normal.png`, 32×32, hotspot at nib tip top-right) via `Input.set_custom_mouse_cursor()`. Restored to default on Menu exit.

**[MVP] CR-18 — No autoload; no per-frame polling.** Menu System has no autoload registration (ADR-0007). Neither `MainMenu.tscn` nor `PauseMenu.tscn` nor `ModalScaffold.tscn` uses `_process()` or `_physics_process()`. All state transitions are signal-driven. The sole exception is the one-time `_boot_warning_pending` poll in CR-8 (which runs in `_ready()`, not per-frame).

**[MVP] CR-19 — Sole-publisher discipline (consumer-only).** Menu System emits **zero** signals on the ADR-0002 Signal Bus at MVP and VS. It is a consumer-only system: reads `SaveLoad.slot_metadata()` + `slot_state(N)`; subscribes `Events.save_failed`, `Events.game_saved`, `Events.game_loaded`; calls `LS.transition_to_section()`, `SaveLoad.load_from_slot()`, `SaveLoad.save_to_slot()`, `SettingsService.open_panel()`, `SettingsService.dismiss_warning()`, `FailureRespawn.has_checkpoint()`, `FailureRespawn.restart_from_checkpoint()`, `Input.set_custom_mouse_cursor()`. If a future feature requires Menu to publish a signal (e.g., `menu_opened`/`menu_closed`), that is an ADR-0002 amendment requiring lead-programmer review.

**[MVP] CR-20 — Music fade-before-transition invariant.** Menu calls `LS.transition_to_section()` for `NEW_GAME` and `LOAD_FROM_SAVE` only after menu music has faded to silence on the `MAIN_MENU` bus per LS L201. The `await` pattern in CR-5 / CR-6 is mandatory — calling LS before fade completion is a contract violation that produces audible click on transition. The fade duration is the `menu_music_fade_out_ms` tuning knob (default 800 ms).

**[MVP] CR-21 — AccessKit one-shot assertive pattern.** All `accessibility_live = "assertive"` regions (boot-warning modal root, Pause Menu root on appearance, save-failed dialog root, quit-confirm dialog root) follow a strict one-shot pattern: assertive is set BEFORE the node becomes visible (so AT announces on appearance) and cleared to `"off"` in the first frame after appearance via `call_deferred`. A permanently-assertive container would re-announce on every focus change within that container — which is an AT usability defect. **[BLOCKING coord]** ADR-0004 Gate 1 (Godot 4.6 `accessibility_*` property names verification) blocks AccessKit implementation across Settings, Menu, and HUD Core uniformly.

**[MVP] CR-22 — Localized AccessKit re-resolve.** Every Control with a non-trivial localized `accessibility_name` MUST re-set it on `NOTIFICATION_TRANSLATION_CHANGED` via a `_update_accessibility_names()` helper called from `_ready()` and from `_notification(NOTIFICATION_TRANSLATION_CHANGED)`. `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` covers `text` re-resolution but NOT `accessibility_name` (which is a plain `String` property outside the auto-translate pipeline). MVP-critical plumbing even though only English ships at MVP — pattern must be in place for VS locale switcher consumption.

**[MVP] CR-23 — Reduced-motion conditional branch.** All paper-movement tweens (folder slide, modal scaffold appearance, screen-transition shuffle, stamp slam-down) wrap in `if accessibility.reduced_motion_enabled: _show_immediately() else: _play_tween()`. The setting `accessibility.reduced_motion_enabled` is a Settings forward-dep (VS); the conditional branch in Menu animation code is MVP. At MVP the setting always reads false (Consumer Default Strategy per Settings CR-6) — animations always play. At VS the setting becomes player-toggleable; reduced-motion players get instant appearance.

**[VS] CR-24 — Modal scaffold focus trap.** All ModalScaffold modals (boot-warning, save-failed, quit-confirm, return-to-registry-confirm, re-brief-confirm, new-game-overwrite-confirm) implement a strict Tab-cycle focus trap via `focus_neighbor_top/bottom/left/right` on the modal's first and last focusable children — Tab from last wraps to first; Shift+Tab from first wraps to last; no Tab traversal can ever reach the underlying menu while modal is open. `ui_cancel` is the only exit (and only when the modal is dismissible — boot-warning is non-dismissible, see CR-8).

**[VS] CR-25 — Card-state shape differentiators (WCAG SC 1.4.1).** Save card EMPTY / OCCUPIED / CORRUPT states are distinguishable by shape and text alone (color reinforces but is not the sole signal). Per art-director: EMPTY = blank ruled card with centred `--- DISPATCH VIDE ---` typed text + 30% dimmed Parchment + `VACANT` 25%-opacity stamp; OCCUPIED = full typed metadata + `FILED` 45%-opacity stamp upper-right; CORRUPT = `████ ████ ████` redacted body lines + `DOSSIER CORROMPU` PHANTOM Red diagonal stamp + 1 px tear-mark on each ruled body line. Verified in grayscale at 1080p with the comic-book outline post-process active — three states remain distinguishable by shape and text alone (BLOCKING AC).

---

### C.2 Owned Surfaces

Every surface Menu System owns, with mounting node, scope tag, InputContext push, default focus, AccessKit role, and dismiss path.

| Surface | Tag | Mounting node | InputContext | Default focus | AccessKit role | Dismiss path |
|---|---|---|---|---|---|---|
| Main Menu shell | **MVP** | `MainMenu.tscn` (boot scene; CanvasLayer = root) | push `Context.MENU` in `_ready()`; pop before LS call or `quit()` | "Continue" if slot 0 OCCUPIED; else "Begin Operation" | `landmark` | (no `ui_cancel` at top level — destructive flows go through Quit button) |
| Photosensitivity boot-warning modal | **MVP** | `ModalScaffold` child of MainMenu, `PhotosensitivityWarningContent` child | push `Context.MODAL` on `show_modal()`; pop on Continue | "Continue" (per Settings CR-18 default) | `dialog` (live `assertive` one-shot) | "Continue" button only — **NOT** dismissible by `ui_cancel` (CR-8) *(REVISED 2026-04-29 per OQ #8 — was "Acknowledge")* |
| Settings entry-point button | **MVP** | Child of MainMenu (and child of PauseMenu at VS) | calls `SettingsService.open_panel()`; Settings owns its own `Context.SETTINGS` push/pop | n/a (the button is a focusable child of its parent surface) | `button` (with `accessibility_description` per CR-7) | n/a |
| Quit-confirm modal | **MVP** | `ModalScaffold` child of MainMenu (and PauseMenu at VS) | push `Context.MODAL`; pop on Cancel/Confirm | "Continue Mission" (Cancel) — safe-default | `dialog` (live `assertive` one-shot) | "Continue Mission" / `ui_cancel` / "Close File" (latter triggers `quit()`) *(REVISED 2026-04-29 per OQ #2 — cancel label was "Return to File")* |
| New-Game-overwrite-confirm modal | **MVP** | `ModalScaffold` child of MainMenu | push `Context.MODAL`; pop on Cancel/Confirm | "Cancel" (safe-default) | `dialog` (live `assertive` one-shot) | "Cancel" / `ui_cancel` / "Open New Operation" |
| Pause Menu shell | **VS** | `PauseMenu.tscn` instantiated by `PauseMenuController` on `pause`; `add_child` to `current_scene` (CanvasLayer 8 per ADR-0004 IG7) | push `Context.PAUSE` on mount; pop on unmount | "Resume Surveillance" | `dialog` (live `assertive` one-shot on appearance) | "Resume Surveillance" / `ui_cancel` (top level) |
| Operations Archive (Load Game grid, 8-slot 2×4) | **VS** | Child of MainMenu OR child of PauseMenu (sub-screen swap, no new context push) | inherits parent's context (`MENU` or `PAUSE`) | last-used slot in-session, else slot 0 | `grid` (live `polite` for end-of-list `polite` announcements per accessibility-specialist) | `ui_cancel` returns to parent menu; focus restores to "Operations Archive" button |
| File Dispatch (Save Game grid, 7-slot 2×3+1) | **VS** | Child of PauseMenu only | inherits `PAUSE` | last-used slot in-session, else slot 1 | `grid` | `ui_cancel` returns to PauseMenu; focus restores to "File Dispatch" button. **Two-press** required to exit if a card is in in-card overwrite-confirm state (CR-12) |
| Save-failed dialog (DISPATCH NOT FILED) | **VS** | `ModalScaffold` child of whichever menu is active | push `Context.MODAL`; pop on Retry/Abandon | "Retry" | `dialog` (live `assertive` one-shot) | "Abandon" / `ui_cancel` / "Retry" (re-attempts most recent save target) |
| Return-to-Registry-confirm modal | **VS** | `ModalScaffold` child of PauseMenu | push `Context.MODAL`; pop on Cancel/Confirm | "Continue Mission" (Cancel) | `dialog` (live `assertive` one-shot) | "Continue Mission" / `ui_cancel` / "Return to Registry" (latter triggers `change_scene_to_file`) |
| Re-Brief-Operation-confirm modal | **VS** | `ModalScaffold` child of PauseMenu | push `Context.MODAL`; pop on Cancel/Confirm | "Continue Mission" (Cancel) | `dialog` (live `assertive` one-shot) | "Continue Mission" / `ui_cancel` / "Re-Brief" (latter triggers `FailureRespawn.restart_from_checkpoint()`) |
| Quicksave / Quickload feedback card | **VS** | Direct child of MainMenu/PauseMenu/active section root (NOT `ModalScaffold`) | NO context push (transient overlay) | n/a (non-focusable; `mouse_filter = MOUSE_FILTER_IGNORE`) | `statictext` (live `polite` for AT) | auto-fade after `quicksave_feedback_duration_s` (1.4 s default) |

---

### C.3 Boot Sequence

In precise dependency order, from app launch to "Main Menu interactive":

1. **Godot engine boot.** Godot 4.6 starts; Jolt physics initialized (4.6 default); rendering initialized (Forward+ Vulkan on Linux / D3D12 on Windows).
2. **Autoload instantiation per ADR-0007 §Canonical Registration Table.** Each registered autoload calls `_ready()` in the slot order defined by ADR-0007. SettingsService runs the boot-time settings burst at its registered slot: reads `user://settings.cfg` (ADR-0003), applies all persisted settings, evaluates `_boot_warning_pending` flag, emits `setting_changed` per stored key, emits `settings_loaded` one-shot signal (ADR-0002 amendment landed 2026-04-28 — closes prior BLOCKING coord on `settings_loaded` per Settings OQ-SA-2). FontRegistry is **NOT an autoload** per ADR-0004 (it is a static class, not in scene tree). *(2026-04-28: stale slot enumeration removed per ADR-0007 IG7 — GDDs do not restate slot numbers; consult ADR-0007 for current canonical order.)*
3. **Main scene load.** Engine loads `MainMenu.tscn` (set as Project Settings → Application → Run → Main Scene) directly. **NOT** via `change_scene_to_file()` on cold boot.
4. **`MainMenu._ready()` runs.** Push `InputContext.MENU` via `InputContextStack`. Instantiate `ModalScaffold` as child of MainMenu (single shared instance). Subscribe to `Events.save_failed` (CR-10), `Events.game_saved` (CR-15 quicksave feedback), `Events.game_loaded` (CR-15 quickload feedback). Set custom mouse cursor to fountain-pen-nib sprite (CR-17). Disable Main Menu button container input via `set_process_input(false)` until step 5 resolves.
5. **Boot-warning poll.** Synchronous read of `SettingsService._boot_warning_pending` (CR-8). **Branch A (`true`):** `ModalScaffold.show_modal(PhotosensitivityWarningContent)`; `Context.MODAL` pushed; modal awaits Continue button (per CR-8 — *button label canonicalised 2026-04-29 per OQ #8*); on Continue: `SettingsService.dismiss_warning()` writes dismissed flag, `ModalScaffold.hide_modal()`, `Context.MODAL` popped, button container `set_process_input(true)`, focus to Main Menu Continue button (label per CR-5: "Resume Surveillance" / "Begin Operation"). **Branch B (`false`):** button container immediately enabled; focus set per CR-5 default.
6. **Main menu interactive.** Player can navigate Continue / Begin Operation / Operations Archive (VS) / Personnel File / Close File.

The boot sequence diagram below uses arrow notation to show the order:

```
APP LAUNCH
  ↓
Godot Engine boot
  ↓
Autoloads instantiate (per ADR-0007 §Canonical Registration Table)
  ↓ (Settings boot burst at SettingsService slot: load cfg → apply rebinds →
                                                  emit setting_changed × N →
                                                  emit settings_loaded one-shot)
  ↓
Engine loads MainMenu.tscn (Project Settings → Main Scene)
  ↓
MainMenu._ready():
  • InputContext.push(MENU)
  • Instantiate ModalScaffold (single shared)
  • Subscribe Events.{save_failed, game_saved, game_loaded}
  • set_custom_mouse_cursor(fountain_pen_nib)
  • Button container set_process_input(false)
  ↓
Synchronous poll: SettingsService._boot_warning_pending ?
  ↓                                        ↓
  YES: ModalScaffold.show_modal(PhotoWarn)  NO: skip
  ↓ (await Continue button)
  Modal closes; SettingsService.dismiss_warning()
  ↓                                        ↓
  Button container set_process_input(true) ← MERGE
  Focus → "Continue" or "Begin Operation"
  ↓
MAIN MENU INTERACTIVE
```

---

### C.4 Modal Scaffold Architecture

**Single shared `ModalScaffold.tscn`** instance lives as a child of the topmost menu surface (MainMenu or PauseMenu). Implementation pattern (per godot-specialist's Item 4 + Item 11 verdict):

- **Node type**: Custom `Control`-rooted scene — **NOT** `Window`, **NOT** `AcceptDialog`/`ConfirmationDialog` (Window-based built-ins fight the period theme + couple to OS chrome + fragmented AccessKit semantics).
- **Tree**: `Control` (root, `mouse_filter = MOUSE_FILTER_STOP`) → `ColorRect` backdrop (52% Ink Black `#1A1A1A` per art-director — NOT blur, NOT translucent gameplay-buffer manipulation per Refusal 1) → `PanelContainer` (the stamped card, StyleBoxFlat, hard 0 px corners) → content child swapped per modal type.
- **CanvasLayer index**: 20 (above Settings 10 / Cutscenes 10 / Subtitles 15; below LS fade 127).
- **API**: `show_modal(content_scene_path: String, return_focus_node: Control = null)` + `hide_modal()` + signal `modal_dismissed`.
- **Queue (depth-1, content-type-aware)**: instance variable `_pending_modal_content: PackedScene = null`. **Queue policy is differentiated by content idempotency** (revised 2026-04-27 to address silent-drop of destructive intent identified by systems-designer):
  - **Save-failed (idempotent)**: If `show_modal(SaveFailedContent)` is called while a modal is active, the incoming SaveFailedContent is queued in `_pending_modal_content`, replacing any prior queued SaveFailedContent (most-recent-wins is correct — the most recent failure is what the player needs to see).
  - **Destructive confirms (non-idempotent — Quit-Confirm, Return-to-Registry, Re-Brief, New-Game-Overwrite)**: If a destructive confirm is the active modal, an incoming save-failed is queued normally. If a destructive confirm is requested while a different destructive confirm OR save-failed is active, the request is **rejected** via `push_error("ModalScaffold: rejected non-idempotent modal request while modal already active")` and the signal is dropped. This prevents silent dropping of player destructive intent.
  - **Save-failed → save-failed**: most-recent-wins (idempotent).
  - **Destructive → save-failed**: save-failed queued; destructive proceeds; on dismiss, save-failed shows.
  - **Destructive → destructive**: rejected with push_error.
  - **Save-failed (active) → destructive**: rejected with push_error (player must dismiss save-failed first).

  On `hide_modal()`, if `_pending_modal_content != null`, immediately call `show_modal(_pending_modal_content, null)` and clear the slot. Handles the save-failed-during-quit-confirm collision (§E Cluster B case 4 + Cluster D case 2) without dropping the second idempotent modal, and refuses to drop non-idempotent destructive intent.
- **InputContext**: `show_modal()` pushes `Context.MODAL`; `hide_modal()` pops it.
- **Focus**: `show_modal()` calls `content.get_default_focus_target().call_deferred("grab_focus")`; on close, calls `return_focus_node.call_deferred("grab_focus")` if provided.
- **Focus trap (CR-24)**: implemented via `focus_neighbor_*` wiring on the content's first/last focusable Control.
- **AccessKit one-shot assertive**: scaffold root has `accessibility_role = "dialog"`, `accessibility_live = "assertive"` set BEFORE `show_modal()` triggers visibility; cleared to `"off"` next frame via `call_deferred` (CR-21).
- **Dismiss**: `_unhandled_input()` checks `event.is_action_pressed(&"ui_cancel")` (per ADR-0004 §97); if the current content is dismissible (boot-warning is NOT — CR-8), call `hide_modal()`.
- **Recyclability**: scaffold is reused across multiple modals in the same MainMenu/PauseMenu lifetime. After boot-warning closes, the same scaffold receives `show_modal(SaveFailedContent)` if `Events.save_failed` fires later, without re-instantiation. (Boot-warning + immediate-New-Game collision is handled by destruction of MainMenu tree on `change_scene_to_file()` — scaffold dies with parent.)
- **Modal content scenes** (one per modal type): `PhotosensitivityWarningContent.tscn`, `SaveFailedContent.tscn`, `QuitConfirmContent.tscn`, `NewGameOverwriteContent.tscn` (MVP); `ReturnToRegistryContent.tscn`, `ReBriefContent.tscn` (VS). Each is a `Control` with one `Label` for body + N `Button`s for actions + optional `accessibility_description` overrides.

---

### C.5 Save Card Grid

Layout, states, and in-card overwrite-confirm flow.

**Grid geometry (CR-11 / CR-12):**

- Load Game (8-slot): `GridContainer` `columns = 2`, 4 rows. Slot 0 in cell `(0,0)` top-left; slots 1–7 fill row-first left-to-right, top-to-bottom.
- Save Game (7-slot): `GridContainer` `columns = 2`, 4 rows. Slots 1–6 fill cells `(0,0)` through `(1,2)`; slot 7 fills `(0,3)` alone; cell `(1,3)` is absent (no Control in that grid position — `mouse_filter = MOUSE_FILTER_IGNORE` placeholder if needed for layout integrity, or the GridContainer simply has 7 children).
- Card dimensions: 360 × 96 px at 1080p baseline (per art-director). Inter-card gap: 6 px horizontal + 6 px vertical.
- Total grid footprint (Load): 2 × 360 + 6 = 726 px wide × 4 × 96 + 18 = 402 px tall. Fits within the manila folder's 760 × 720 px interior (resolved in design-review 2026-04-27 — folder width grown from 520 to 760 to accommodate the 4×2 grid + 17 px side margins; folder height grown from 680 to 720 to accommodate grid + tab + body margins; LOCKED constants updated in §G.2; folder asset `ui_folder_manila_base_large.png` regenerated to 760 × 760 with tab overhang preserved).

**Card states (CR-25 — shape differentiators verified in grayscale):**

| State | Card body | Stamp | Color | Focus / activation |
|---|---|---|---|---|
| **OCCUPIED** | Full typed metadata: `DISPATCH 03`, `TOUR EIFFEL — NIVEAU 2 — 14:23 GMT`, three ruled body lines (40% opacity) | `FILED` upper-right, Ink Black 45% | Standard Parchment `#F2E8C8` | Focus enabled; activation triggers load (Load grid) or in-card overwrite-confirm (Save grid) |
| **EMPTY** | Centered `— DISPATCH VIDE —` (Save grid) or `— No Dispatch On File —` (Load grid) | `VACANT` Ink Black 25% | 30% dimmed Parchment via `modulate` | Focus enabled (announced as available); activation triggers immediate save (Save grid) or no-op (Load grid — `disabled = true`) |
| **CORRUPT** | `████ ████ ████` redacted body lines (each ruled line has a 2 px tear-mark at center) | `DOSSIER CORROMPU` PHANTOM Red diagonal at −20° | Cooler off-white `#E8E0D0` | Focus enabled; activation `disabled = true`; AccessKit announces "*File damaged.*" |
| **AUTOSAVE** (slot 0 only, Load grid) | Same as OCCUPIED but header reads `SAUVEGARDE AUTO — TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` | `AUTO-FILED` BQA Blue 45% | Standard Parchment + 2 px BQA Blue left-border accent stripe | Standard load behaviour |

**In-card overwrite-confirm flow (CR-12 — Save grid only):**

1. Player has Save grid open in PauseMenu, focus on slot 3 (OCCUPIED state).
2. Player presses `ui_accept`.
3. Card 3 swaps in-place to confirm state: top text becomes `tr("menu.save.confirm_overwrite")` ("Overwrite Dispatch 03?"); body collapses; two buttons appear inside the same card area: `[CANCEL]` (left, default focus) and `[CONFIRM]` (right). Card's neighbouring cards (1, 2, 4) remain in their normal state — only slot 3 is in confirm mode.
4. Focus moves to `[CANCEL]` automatically. Tab cycles between `[CANCEL]` and `[CONFIRM]` only — does NOT escape to other slots.
5. Player can: (a) press `ui_cancel` → triggers `[CANCEL]` → card returns to normal OCCUPIED state, focus returns to card 3; OR (b) navigate to and press `[CONFIRM]` → calls `SaveLoad.save_to_slot(3)` → card returns to OCCUPIED with updated metadata.
6. Two `ui_cancel` presses required to exit Save grid from in-confirm state: first press cancels the confirm, second press exits the grid.

This pattern keeps stack depth at 2 (PAUSE + Save grid) — no third Modal context layer is pushed for the overwrite confirm. Paper-consistent (player marks up the same form, doesn't reach for a new one).

---

### C.6 Esc-Key Discipline (per level of menu stack)

`ui_cancel` is the universal cancel/dismiss action. Per ADR-0004 §97 pattern, all surfaces use `_unhandled_input()` + `event.is_action_pressed(&"ui_cancel")`. Behaviour by stack level:

| Stack level | `ui_cancel` behaviour |
|---|---|
| MainMenu top level (`MENU`) | **Nothing.** No quit-confirm on Esc at top. Player must navigate to "Close File" explicitly. (Accidental Esc at boot must not trigger a destructive flow. NOLF1 precedent.) |
| MainMenu → Operations Archive sub-screen | Closes Load Game sub-screen, returns focus to "Operations Archive" button. |
| MainMenu → ModalScaffold (Quit-Confirm / New-Game-Overwrite) | Triggers Cancel path on the modal; closes; returns focus to triggering button. |
| MainMenu → ModalScaffold (Photosensitivity) | **Blocked.** No effect. Only the "Continue" button (per CR-8) dismisses. |
| PauseMenu top level (`PAUSE`) | **Resumes game.** Pops `Context.PAUSE`, `queue_free`s PauseMenu node. Identical to "Resume Surveillance". (Esc-to-resume is universal expected behaviour — failing to honor it at top of Pause is friction.) |
| PauseMenu → File Dispatch / Operations Archive sub-screen | Closes sub-screen, returns focus to triggering button in PauseMenu. |
| PauseMenu → Save grid in in-card-confirm state | Triggers in-card `[CANCEL]`; card returns to OCCUPIED; does NOT close Save grid. (Two-press required to exit from in-confirm state, intentional per CR-12.) |
| PauseMenu → ModalScaffold (any of: Quit-Confirm / Return-to-Registry / Re-Brief / Save-Failed) | Triggers Cancel path; closes; returns focus to triggering button. |
| Settings panel open (any context) | Settings owns `Context.SETTINGS` dismiss — Menu does not handle `ui_cancel` while `Context.SETTINGS` is active. |
| `Context.LOADING` active | **Blocked.** No handler attached to the loading transition. Dead-input state by design. |

---

### C.7 InputContext Push/Pop Matrix

Every push/pop in Menu System's lifetime, in order, with assertion guard.

| Trigger | Push | Pop | Assertion guard |
|---|---|---|---|
| `MainMenu._ready()` | `push(MENU)` | popped on LS call or `quit()` | `assert(InputContextStack.peek() == GAMEPLAY)` (the boot-default context) |
| `ModalScaffold.show_modal(...)` | `push(MODAL)` | popped on `hide_modal()` | `assert(peek() in [MENU, PAUSE])` |
| `PauseMenuController._unhandled_input()` on `pause` | `push(PAUSE)` | popped on Pause Menu close | `assert(peek() == GAMEPLAY)` (CR-3) |
| `MainMenu` calling LS for NEW_GAME / LOAD_FROM_SAVE | `push(LOADING)` immediately before `transition_to_section()` | implicit (scene change destroys MainMenu tree) | n/a |
| `PauseMenu` calling LS for LOAD_FROM_SAVE | `push(LOADING)` immediately before `transition_to_section()` | implicit (scene change destroys PauseMenu + section trees) | n/a |
| Settings entry-point button | (Settings pushes `SETTINGS` itself; Menu does not push) | (Settings pops `SETTINGS` itself) | n/a |
| `MainMenu._exit_tree()` (LS scene change for NEW_GAME / LOAD_FROM_SAVE / Return-to-Registry) | n/a | `pop(MENU)` if still on stack | `assert(peek() in [MENU, LOADING])` |

**[BLOCKING coord]** ADR-0004 must add `Context.MODAL` and `Context.LOADING` enum values. Without these, the matrix above does not compile. This is a single ADR-0004 amendment that closes:
- Menu System's modal lifecycle (this GDD's CR-2 + CR-8 + CR-9 + CR-10 + CR-13 + CR-14 + C.4 architecture)
- Settings & Accessibility's photosensitivity warning + future revert-confirm (already specified but pending this enum)
- F&R revision item #4 (`Context.LOADING` was found missing during F&R review)

---

### C.8 Locked English Strings

All player-visible English strings are locked here. Every string satisfies the Player Fantasy test (*"if it couldn't have been printed, typed, stamped, or filed in 1965, it doesn't ship"*). Character counts are inclusive of spaces; strings ≤ 25 chars satisfy Localization L212. Body-copy strings in dialog cards are flagged separately (Localization confirms whether L212 applies to labels only — coord item).

**Main Menu**

| tr-key | English | chars |
|---|---|---|
| `menu.main.continue` | Resume Surveillance | 19 |
| `menu.main.continue_empty` | Begin Operation | 15 |
| `menu.main.new_game` | Open New Operation | 18 |
| `menu.main.load_game` | Operations Archive | 18 |
| `menu.main.settings` | Personnel File | 14 |
| `menu.main.settings.desc` (AccessKit) | Adjust audio, graphics, accessibility, and control settings. | 60 (description, not label — no cap) |
| `menu.main.continue.desc` (AccessKit) | Continue the most recent operation in progress. | 47 |
| `menu.main.continue_empty.desc` (AccessKit) | Begin a new operation. | 22 |
| `menu.main.new_game.desc` (AccessKit) | Begin a new operation. Will overwrite the autosave dispatch if no manual saves exist. | 84 |
| `menu.main.load_game.desc` (AccessKit) | Open a previously filed dispatch from the operations archive. | 60 |
| `menu.main.quit.desc` (AccessKit) | Quit the application. Unsaved progress is lost. | 47 |
| `menu.main.quit` | Close File | 10 |

**Pause Menu**

| tr-key | English | chars |
|---|---|---|
| `menu.pause.resume` | Resume Surveillance | 19 |
| `menu.pause.save` | File Dispatch | 13 |
| `menu.pause.load` | Operations Archive | 18 |
| `menu.pause.settings` | Personnel File | 14 |
| `menu.pause.restart` | Re-Brief Operation | 18 |
| `menu.pause.main_menu` | Return to Registry | 18 |
| `menu.pause.quit` | Close File | 10 |
| `menu.pause.resume.desc` (AccessKit) | Resume the operation in progress. | 34 |
| `menu.pause.save.desc` (AccessKit) | File the current dispatch — save your progress. | 49 |
| `menu.pause.load.desc` (AccessKit) | Load a previously filed dispatch. Current unsaved progress is lost. | 67 |
| `menu.pause.restart.desc` (AccessKit) | Reload the last checkpoint. Recent progress since checkpoint is lost. | 70 |
| `menu.pause.main_menu.desc` (AccessKit) | Return to the main menu. Unsaved progress is lost. | 50 |
| `menu.pause.quit.desc` (AccessKit) | Quit the application. Unsaved progress is lost. | 47 |

**Save / Load grid card metadata**

| tr-key | Template | Rendered example |
|---|---|---|
| `menu.save.card_label` | Dispatch {n} | `Dispatch 03` |
| `menu.save.card_location` | {section} — {time} GMT | `Tour Eiffel, niv. 2 — 14:23 GMT` |
| `menu.save.card_slot_zero` | Autosave — {section} | `Autosave — Tour Eiffel, niv. 2` |
| `menu.load.title` | Operations Archive | 18 |
| `menu.load.slot_empty` | — No Dispatch On File — | 23 |
| `menu.save.title` | File Dispatch | 13 |
| `menu.save.slot_empty` | — Slot Unoccupied — | 19 |
| `menu.save.confirm_overwrite` | Overwrite Dispatch? | 19 |
| `menu.save.overwrite_yes` | Re-File | 7 |
| `menu.save.overwrite_no` | Cancel | 6 |

**Modal scaffolds**

| tr-key | English | chars | Notes |
|---|---|---|---|
| `menu.save_failed.title` | DISPATCH NOT FILED | 18 | All-caps stamp register, intentional |
| `menu.save_failed.body_alt` | Write error. Retry? | 19 | (alt of original 26-char copy; shorter version chosen) |
| `menu.save_failed.retry` | Retry | 5 | |
| `menu.save_failed.dismiss` | Abandon | 7 | |
| `menu.quit_confirm.stamp` | CASE CLOSED | 11 | Ink Black header band rendered as stamp graphic |
| `menu.quit_confirm.body_alt` | Operation abandoned. | 20 | |
| `menu.quit_confirm.confirm` | Close File | 10 | |
| `menu.quit_confirm.cancel` | Continue Mission | 16 | |
| `menu.return_registry.stamp` | RETURN TO REGISTRY | 18 | Ink Black header band |
| `menu.return_registry.body_alt` | Unsaved progress lost. | 22 | |
| `menu.return_registry.confirm` | Return to Registry | 18 | |
| `menu.return_registry.cancel` | Continue Mission | 16 | |
| `menu.rebrief.stamp` | RE-BRIEF OPERATION | 18 | Ink Black header band |
| `menu.rebrief.body_alt` | Reload last checkpoint? | 23 | |
| `menu.rebrief.confirm` | Re-Brief | 8 | |
| `menu.rebrief.cancel` | Continue Mission | 16 | |
| `menu.new_game_confirm.title` | OPEN NEW OPERATION | 18 | PHANTOM Red header band (same destructive register as save-failed) |
| `menu.new_game_confirm.body_alt` | Autosave will be overwritten. | 28 (over) | Coord with Localization to confirm L212 cap scope |
| `menu.new_game_confirm.confirm` | Begin Operation | 15 | |
| `menu.new_game_confirm.cancel` | Cancel | 6 | |

**Quicksave / Quickload feedback**

| tr-key | English | chars |
|---|---|---|
| `menu.quicksave.feedback` | DISPATCH FILED | 14 |
| `menu.quickload.feedback` | DISPATCH LOADED | 15 |

**Photosensitivity warning** (Settings-owned strings — Menu only mounts the scaffold; copy is `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_BODY")` per Settings GDD)

| tr-key | Owner |
|---|---|
| `SETTINGS_PHOTOSENSITIVITY_WARNING_BODY` | Settings & Accessibility GDD (locked 38-word copy + 300-char locale ceiling) |
| `menu.photo_warning.continue` | Continue (8 chars) — Menu-owned button label inside the scaffold *(REVISED 2026-04-29 per OQ #8 — was "Acknowledge" 11 chars)* |
| `menu.photo_warning.go_to_settings` | Go to Settings (14 chars) — Menu-owned button label |
| `menu.photo_warning.go_to_settings.desc` (AccessKit) | Open accessibility settings to configure flash intensity. |

---

### C.9 AccessKit Per-Widget Table

Mirror of Settings GDD §C.5 format. Surfaces below cover MVP slice; VS surfaces (Pause Menu, Save / Load grids, save-failed dialog) inherit the same rules and are detailed in §UI Requirements.

| Widget | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` | Tag |
|---|---|---|---|---|---|
| MainMenu root | `landmark` | `tr("menu.main.label")` → "Main Menu" | (none) | `off` | MVP |
| Continue button | `button` | `tr("menu.main.continue")` (or `continue_empty`) | `tr("menu.main.continue.desc")` (or `tr("menu.main.continue_empty.desc")` when label-swapped) — required because all Case File rebrands are ambiguous to first-time AT users, not just "Personnel File". Coverage extended in design-review 2026-04-27 per accessibility-specialist (SC 1.3.1 / SC 2.4.6). | `off` | MVP |
| New Game button | `button` | `tr("menu.main.new_game")` → "Open New Operation" | `tr("menu.main.new_game.desc")` | `off` | MVP |
| Load Game button | `button` | `tr("menu.main.load_game")` → "Operations Archive" | `tr("menu.main.load_game.desc")` | `off` | VS |
| Settings button | `button` | `tr("menu.main.settings")` → "Personnel File" | `tr("menu.main.settings.desc")` (CR-7) | `off` | MVP |
| Quit button | `button` | `tr("menu.main.quit")` → "Close File" | `tr("menu.main.quit.desc")` | `off` | MVP |
| Photosensitivity modal root | `dialog` | `tr("menu.photo_warning.title")` → "Operational Advisory" | `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_BODY")` (full 38-word warning body — required so AT announces the safety content with the modal, not silent static Label children. Fix applied 2026-04-27 — closes the safety-critical AT announcement gap identified by accessibility-specialist.) | `assertive` one-shot (CR-21) | MVP |
| Photo Continue button | `button` | `tr("menu.photo_warning.continue")` → "Continue" | (none) | `off` | MVP *(REVISED 2026-04-29 per OQ #8)* |
| Photo Go-to-Settings button | `button` | `tr("menu.photo_warning.go_to_settings")` | `tr("menu.photo_warning.go_to_settings.desc")` | `off` | MVP |
| Quit-confirm modal root | `dialog` | `tr("menu.quit_confirm.stamp")` → "CASE CLOSED" | (none) | `assertive` one-shot | MVP |
| Quit-confirm Cancel button | `button` | `tr("menu.quit_confirm.cancel")` → "Continue Mission" | (none) | `off` | MVP |
| Quit-confirm Confirm button | `button` | `tr("menu.quit_confirm.confirm")` → "Close File" | (none — `disabled` state announces unavailability if needed) | `off` | MVP |
| Save card OCCUPIED | `button` | `tr("menu.save_card.occupied.name", {slot, section, time})` → "Dispatch 3. Tour Eiffel niveau 2. 14:23 GMT." | `tr("menu.save_card.occupied.desc")` (Save grid: "Press to overwrite this dispatch with your current progress.") | `off` | VS |
| Save card EMPTY | `button` | `tr("menu.save_card.empty.name", {slot})` → "Dispatch 3. Empty — press to file here." | (none) | `off` | VS |
| Save card CORRUPT | `button` (`disabled = true`) | `tr("menu.save_card.corrupt.name", {slot})` → "Dispatch 3. File damaged. Cannot load." | `tr("menu.save_card.corrupt.desc")` → "This dispatch file is damaged and cannot be opened." | `off` | VS |

**[BLOCKING coord]** ADR-0004 Gate 1 (Godot 4.6 `accessibility_*` property names verification) must close before this table can be implemented in code. The table assumes property names per the post-4.5 Godot AccessKit integration as understood from project-pinned engine reference; verification is a 5-minute editor inspection per godot-specialist's Item 8.

---

### C.10 Interactions with Other Systems

Bidirectional cross-GDD contract verification. Every interaction is bidirectional unless noted; if Menu's contract here doesn't match the upstream GDD, surface as a coord item.

| Other system | Direction | Interaction | Verified against | Notes |
|---|---|---|---|---|
| **Save / Load** ✅ | Menu → SaveLoad | Calls `slot_metadata(N)` for save card render; `load_from_slot(N)` for load; `save_to_slot(N)` for save | Save/Load CR-9, CR-10, CR-11, CR-8 + L106 + L153 | Menu reads sidecar only; never opens `.res` (ADR-0003) |
| **Save / Load** ✅ | SaveLoad → Menu | Emits `save_failed`, `game_saved`, `game_loaded` (ADR-0002 Save domain); Menu subscribes per CR-10 + CR-15 | Save/Load CR-9 | Save-failed dialog is non-blocking; quicksave / quickload feedback is ephemeral overlay, no InputContext push |
| **Level Streaming** ✅ | Menu → LS | Calls `transition_to_section()` for NEW_GAME and LOAD_FROM_SAVE; registers step-9 restore callback (LS L55) | LS CR-4, CR-7, L201 | Menu is one of three caller-allowlist members; `get_stack()` debug assertion guards in LS |
| **Level Streaming** ✅ | LS → Menu | LS scene change destroys Menu trees on transition; Menu's `_exit_tree()` cleans up subscriptions | LS L320 | F&R + Mission Scripting + Menu all share step-9 restore callback contract |
| **Input** ✅ | Input → Menu | Menu consumes `pause`, `ui_up/down/left/right`, `ui_accept`, `ui_cancel` | Input GDD L105–L110 + L156–L177 | `pause` only fires in `Context.GAMEPLAY` (CR-3); gamepad reconnect (`Input.joy_connection_changed`) handled by PauseMenu directly per Input L156 |
| **Settings & Accessibility** ✅ | Menu → Settings | Reads `_boot_warning_pending: bool` synchronously in `_ready()` (CR-8); calls `open_panel()` from Settings entry-point (CR-7); calls `dismiss_warning()` on Continue button | Settings CR-18 + OQ-SA-3 | **CLOSES Settings BLOCKING coord OQ-SA-3** with this GDD's CR-8 + C.4 ModalScaffold spec |
| **Settings & Accessibility** ✅ | Settings → Menu | Settings emits `setting_changed(category, name, value)` (Variant payload exception, ADR-0002); Menu subscribes only for `category == "accessibility" && name == "reduced_motion_enabled"` to gate animation per CR-23 | Settings CR-1 + CR-23 | Reduced-motion conditional branch is MVP; setting consumption is VS |
| **Audio** ✅ | Menu → Audio | Triggers menu-music fade-out on `MAIN_MENU` bus before LS NEW_GAME call (CR-20); duration `menu_music_fade_out_ms` | Audio L97 + LS L201 | Music continues uninterrupted from gameplay during Pause per Audio L378 — Menu does NOT duck/fade music on Pause open |
| **Localization Scaffold** ✅ | Menu → L10n | All visible strings via `tr("menu.*")`; static labels use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (Loc L129) | Loc L129 + L183 + L212 | `accessibility_name` re-resolution requires `_notification(NOTIFICATION_TRANSLATION_CHANGED)` plumbing per CR-22 |
| **Failure & Respawn** ⚠ | Menu → F&R | Calls `has_checkpoint() -> bool` to gate Re-Brief Operation visibility (CR-13); calls `restart_from_checkpoint()` on confirm | F&R GDD does not currently expose this query API | **[BLOCKING coord — VS]** F&R GDD must add public query API |
| **Post-Process Stack** ⚠ | Menu → PPS | OPTIONAL `enable_sepia_dim()` for pause overlay (PPS L96/355) | PPS OQ — Menu GDD decides | **DECISION: Menu does NOT use PPS sepia dim for Pause.** Pause uses a 52% Ink Black ColorRect overlay per art-director (NOT a sepia tint). The Document Overlay system uses the sepia dim; Pause Menu uses a neutral darken so Pause is visually distinct from Document Overlay. PPS coord item: closed in Menu's favour — Menu does not consume `enable_sepia_dim()`. |
| **HUD Core** ✅ | HUD → Menu | None — HUD does not interact with Menu (HUD is consumer-only of gameplay state; Menu does not render during gameplay) | HUD Core §F | HUD is hidden when InputContext != GAMEPLAY per HUD CR-1 |
| **HUD Core** ✅ | Menu → HUD | Menu System's photosensitivity boot-warning modal scaffold closes HUD Core's HARD MVP DEP (REV-2026-04-26 D2) — HUD damage flash kill-switch UI cannot be exercised without this scaffold | HUD Core REV-2026-04-26 D2 | **CLOSES HUD Core BLOCKING coord** |
| **Cutscenes & Mission Cards** | Menu → CMC (forward) | Menu's mission-dossier card backdrop (CR-16) shares aesthetic + assets with CMC's mission-briefing transitions | CMC GDD #22 not yet authored | Coord item for CMC GDD authoring: dossier asset reuse + Art Bible §7D shared visual register |
| **Mission & Level Scripting** ✅ | Menu → MLS | Menu does not call MLS directly. New Game flow calls LS, which fires `mission_started` after section load — MLS reacts there | MLS L297 | Indirect: Menu → LS → MLS via signal taxonomy |
| **Document Overlay UI** ✅ | none | Document Overlay has its own InputContext and modal; Menu does not interact | Document Overlay GDD #20 | Forbidden non-dep: Menu does not render during Document Overlay |
| **Document Collection** ✅ | none | Document Collection writes to SaveGame; Menu reads via `slot_metadata` | Document Collection GDD | Indirect via SaveLoad sidecar |
| **Combat & Damage** ✅ | none | Forbidden non-dep | Combat GDD | Combat does not touch Menu System at any layer |
| **Stealth AI** ✅ | none | Forbidden non-dep | SAI GDD | SAI does not touch Menu System |
| **Player Character** ✅ | none | Forbidden non-dep | PC GDD | PC does not touch Menu System (PC state restored via SaveGame, not Menu) |
| **Inventory & Gadgets** ✅ | none | Forbidden non-dep | Inventory GDD | Inventory state restored via SaveGame, not Menu |
| **Civilian AI** ✅ | none | Forbidden non-dep | CAI GDD | CAI state ephemeral per section, not in SaveGame |
| **Footstep Component** ✅ | none | Forbidden non-dep | Footstep GDD | |
| **Outline Pipeline** ✅ | none | Forbidden non-dep | Outline GDD | (Note: Settings panel may interact with Outline via `get_resolution_scale()` — that is a Settings concern, not Menu's) |

**Bidirectional consistency check** (each row's "Verified against" cell points at the upstream GDD's section that locks the contract — verified 2026-04-26 PM during this GDD authoring; if any upstream section changes, Menu System's row must be re-verified):

✅ Save/Load CR-9/10/11 + L106/153 — verified
✅ LS CR-4/7/L55/L201/L320 — verified
✅ Input GDD L105–110 / L133 / L156 / L177 / L246 — verified
✅ Settings CR-18 + OQ-SA-3 + entries-registry SettingsService row — verified; this GDD CLOSES OQ-SA-3
✅ Audio L97 / L188 / L378 — verified
✅ Localization L129 / L183 / L212 — verified
✅ HUD Core REV-2026-04-26 D2 — verified; this GDD CLOSES HARD MVP DEP
⚠ F&R GDD — `has_checkpoint() -> bool` API does NOT yet exist; **[BLOCKING coord for VS]**
⚠ Cutscenes & Mission Cards (#22) — GDD not yet authored; coord item for that GDD authoring

---

### C.11 Forbidden Patterns (Pillar 5 + accessibility consolidation)

QA-grep-lintable rules. Each is a Pillar 5 or WCAG 2.1 AA enforcement gate. Each maps to an AC in §H.

**FP-1 — No translucent gameplay-buffer overlay during Pause.** Pause uses a 52% Ink Black ColorRect ABOVE the gameplay viewport, NOT a `modulate.a` change on the gameplay CanvasLayer. *Grep gate*: any `modulate.a` assignment in `MainMenu.gd` / `PauseMenu.gd` / `ModalScaffold.gd` is a violation.

**FP-2 — No "Quit to Main Menu" / "Quit to Desktop" / "Game" / "Play" / "New Game" verbiage in player-visible strings.** Strings are *Return to Registry*, *Close File*, *Open New Operation*, *Resume Surveillance*. *Grep gate*: any `tr(...)` key value containing `"Quit to"`, `"Game"` (case-insensitive), `"Play"` in `translations/menu.csv`. (Exception: `tr-keys` themselves may contain `_game_` as a sub-feature taxonomy per Localization CR-1 — only the *English values* are linted.)

**FP-3 — No save thumbnails / screenshots / live-preview viewports in Menu surfaces.** *Grep gate*: any `Texture2D` node inside `SaveCard.tscn` scene tree; any `SubViewport` node inside any scene under `src/ui/menu/` (closes the live-preview loophole per §E Cluster J case 4); any `DisplayServer.screen_get_image()` / `Viewport.get_texture().get_image()` call inside `src/ui/menu/`.

**FP-4 — No real-world wall-clock timestamps.** *Grep gate*: `Time.get_datetime_dict_from_system` and `Time.get_unix_time_from_system` forbidden in `src/ui/menu/`.

**FP-5 — No relative-time strings.** No `"X minutes ago"`, `"hours ago"`, `"recently"`, `"just"`, `"last played"`, `"left off"`. *Grep gate*: `translations/menu.csv` value column matches any of those literal substrings.

**FP-6 — No "Are you sure?" verbiage anywhere.** Strings are *Operation abandoned.*, *Unsaved progress lost.*, *Reload last checkpoint?* — bureaucratic-neutral. *Grep gate*: `"Are you sure"` / `"Do you want to"` / `"Permanently"` / `"cannot be undone"` in `translations/menu.csv`.

**FP-7 — No exclamation marks in menu strings.** The bureaucracy is never excited. *Grep gate*: any `!` in `translations/menu.csv` value column.

**FP-8 — No animated transitions other than paper-movement and stamp-slam.** Specifically: no `Tween.new()` / `create_tween()` / `$AnimationPlayer.play` inside any Menu scene's `_on_focus_entered`, `_on_mouse_entered`, or screen-fade callbacks (the `create_tween` pattern is the modern Godot 4.x idiom and must be in the grep per §E Cluster J case 1). The only allowed animations are the folder slide-in/out (CR-4 + V.7 spec), the modal scaffold appearance, the screen-shuffle paper transition (V.7), and the stamp-slam on destructive confirm (V.7). *Grep gate*: `grep -rn "create_tween\|Tween\.new\|AnimationPlayer\.play" src/ui/menu/` flags any match inside focus or hover callback methods (analogous to HUD Core AC-HUD-pillar-1 scene-tree CI scan pattern).

**FP-9 — No bare `Label` nodes without FontRegistry override.** Every visible `Label` in a Menu scene must have a `theme_override_fonts/font` set via FontRegistry (ADR-0004) — no Godot default theme leakage. *Grep gate*: scene-tree CI scan for `Label` nodes inside `src/ui/menu/` scenes without a `theme_override_fonts/font` property.

**FP-10 — No corner radius > 0 on any Control element.** Hard-edged rectangles per Art Bible §3.3. *Grep gate*: any `StyleBoxFlat.corner_radius_*` > 0 inside `src/ui/menu/` resources.

**FP-11 — No drop shadows / soft glows / gradient fills.** Per Art Bible §3.3. Focus indicators are 2 px Parchment hard-edge borders only. *Grep gate*: any `StyleBoxFlat.shadow_*` > 0; any `StyleBoxFlat` with non-uniform `bg_color` (gradient).

**FP-12 — No countdown timers visible in Menu surfaces.** Settings' resolution-revert 10-s timer is the only countdown anywhere in the project (Settings carve-out). *Grep gate*: any `$Timer` with a visible Label-update connection inside `src/ui/menu/` scenes EXCEPT `Settings` panel scenes.

**FP-13 — No toast notifications, no ephemeral pop-up banners EXCEPT the explicit quicksave/quickload feedback card (CR-15).** No floating "Settings applied", "Autosave in progress", "Achievement unlocked" overlays. *Grep gate*: any `Label` with a `Timer.autostart = true` inside Menu scenes that is not the `QuicksaveFeedback.tscn` / `QuickloadFeedback.tscn` exemption.

**FP-14 — No simultaneous multi-key input requirement (Ctrl+S, Alt+Q, etc.).** WCAG SC 2.1.1. Every menu action reachable via single-key navigation (Tab + Enter, or arrow + Enter). *Grep gate*: any `Input.is_key_pressed(KEY_CONTROL)` / `KEY_ALT` / `KEY_SHIFT` modifier check inside `src/ui/menu/`.

**FP-15 — No keyboard trap outside modals.** WCAG SC 2.1.2. Every non-modal surface allows `ui_cancel` to escape. Only modals (boot-warning, save-failed, quit-confirm, return-to-registry, re-brief, new-game-overwrite) implement focus trap (CR-24). *Grep gate*: any `_unhandled_input` returning early without `set_input_as_handled()` inside a non-modal Menu scene that prevents `ui_cancel` from propagating.

**FP-16 — No flash / pulse / animated warning state on CORRUPT save cards exceeding 3 Hz.** WCAG SC 2.3.1. *Grep gate*: any timer-driven `modulate` change on `SaveCard.tscn` with period < 333 ms.

**FP-17 — No permanent `accessibility_live = "assertive"` on any container.** One-shot pattern only (CR-21). *Grep gate*: any `accessibility_live = "assertive"` set in scene `.tscn` data without a corresponding `call_deferred("set", "accessibility_live", "off")` in the scene's `_ready()`.

**FP-18 — No system / OS chrome / Steam overlay / platform achievement instantiation inside Menu scenes.** *Grep gate*: any `addons/steamworks/` import inside `src/ui/menu/`.

## Formulas

Eight formulas. Menu System has light traditional balance math; what counts as "formulas" here is layout geometry, animation timing, state predicates, and frame-cost composition. Naming continuity with HUD Core F.5 (`C_*` cost-term family) and Settings F.1–F.4 (predicate / gate-pattern family).

### F.1 — Save Card Grid Cell Position

```
col(i)      = i mod cols
row(i)      = i div cols
x_offset(i) = col(i) × (card_w + gap_h)
y_offset(i) = row(i) × (card_h + gap_v)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Card index (0-based) | `i` | int | [0, 7] (Load) / [0, 6] (Save) | Linear slot index; 0 = top-left cell |
| Column count | `cols` | int | {2} (locked) | Number of columns in the grid |
| Card width | `card_w` | int | 360 (locked at 1080p) | Width of one card in design-pixels |
| Card height | `card_h` | int | 96 (locked at 1080p) | Height of one card in design-pixels |
| Horizontal gap | `gap_h` | int | 6 (locked) | Pixel gap between columns |
| Vertical gap | `gap_v` | int | 6 (locked) | Pixel gap between rows |
| Column index | `col(i)` | int | [0, 1] | Column of card `i` |
| Row index | `row(i)` | int | [0, 3] | Row of card `i` |
| Horizontal offset | `x_offset(i)` | int | {0, 366} px | X position of card `i` relative to grid origin |
| Vertical offset | `y_offset(i)` | int | {0, 102, 204, 306} px | Y position of card `i` relative to grid origin |

**Output Range:** `x_offset` ∈ {0, 366}; `y_offset` ∈ {0, 102, 204, 306}. Exact integers — no floating-point rounding. The grid origin is the GridContainer's top-left corner; the formula computes child offsets that GridContainer would produce naturally with `columns = 2`. The formula is authoritative for CI position-assertions; it does not replace GridContainer layout, it validates it.

**Grid footprint:** Load (8 cards) = 2×360 + 1×6 = **726 px** wide × 4×96 + 3×6 = **402 px** tall. Save (7 cards, 2×3+1) = same width × 3×96 + 2×6 + 1×96 = **396 px** tall.

**Occupancy predicate for the 7-slot Save grid:** `occupied(col, row) = (row < 3) OR (row == 3 AND col == 0)`. The absent cell `(1, 3)` is NOT a focusable button — GridContainer simply has 7 children, not 8 (no phantom `disabled = true` placeholder).

**Worked example — card index 5 in the 2×4 Load grid:**
- `col(5) = 5 mod 2 = 1`; `row(5) = 5 div 2 = 2`
- `x_offset = 1 × 366 = 366 px`; `y_offset = 2 × 102 = 204 px`
- Position: (366, 204) px relative to grid origin (column 1, row 2).

**Verification gates:**
- **GATE-F1-A** (LOW): Confirm `GridContainer.columns = 2` respects the 7-child stop naturally in Godot 4.6 (no phantom 8th child needed).
- **GATE-F1-B** (LOW): Confirm `GridContainer` gap is set via `add_theme_constant_override(&"h_separation", 6)` and `&"v_separation"` in Godot 4.6.

---

### F.2 — Photosensitivity Modal Body Fit Predicate

```
chars_per_line(font_size_px) =
    60    if font_size_px == 11
    69    if font_size_px == 10

lines_available = 5   (fixed — 460 × 164 px body area at American Typewriter)

body_fits(body_chars, font_size_px) =
    body_chars  ≤  chars_per_line(font_size_px) × lines_available
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Localised body string length | `body_chars` | int | [0, ∞) — design cap ≤ 345 | Character count (Unicode scalar) of the rendered body string |
| Font size | `font_size_px` | int | {10, 11} | Two permissible body font sizes; 11 px default; 10 px fallback for locales 301–345 chars |
| Characters per line | `chars_per_line` | int | {60, 69} | Average chars fitting on one line at the given font size in 460 px width |
| Lines available | `lines_available` | int | 5 (fixed) | Body lines available in 460 × 164 px area |
| Fit result | `body_fits` | bool | {true, false} | Whether the string fits without overflow |

**Output Range:** Boolean. Three-outcome decision tree:

| `body_chars` range | Decision |
|---|---|
| ≤ 300 | `body_fits(body_chars, 11) = true` — render at 11 px |
| 301–345 | `body_fits(body_chars, 11) = false`; `body_fits(body_chars, 10) = true` — fall back to 10 px |
| ≥ 346 | both sizes overflow; **locale GDD amendment required** before shipping that locale |

**Critical caveat:** `chars_per_line` is an *average-line estimate* — American Typewriter is proportional, not monospaced. The integer predicate is for localiser self-check; the **authoritative fit check is `Label.get_line_count() ≤ 5`** after rendering with `autowrap_mode` set.

**Worked example — French locale body (~116 chars):** `body_fits(116, 11) = 116 ≤ 300 = true` — renders at 11 px.

**Worked example — hypothetical long German (340 chars):** `body_fits(340, 11) = false; body_fits(340, 10) = 340 ≤ 345 = true` — falls back to 10 px.

**Verification gates:**
- **GATE-F2-A** (MEDIUM, BLOCKING before localisation ships): Confirm `Label.get_line_count()` in Godot 4.6 returns count of *wrapped* lines (not `\n` newlines). TextServer was reworked across 4.4–4.5.
- **GATE-F2-B** (MEDIUM): Confirm `Label.autowrap_mode` constant name in 4.6 (pre-4.4 used `Label.AUTOWRAP_WORD`; 4.4+ may have moved this to `TextServer.AUTOWRAP_WORD`).

---

### F.3 — Animation Duration with Reduced-Motion Gate

```
actual_duration_ms(nominal_duration_ms, reduced_motion_enabled) =
    0    if reduced_motion_enabled == true
    nominal_duration_ms    otherwise
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Nominal duration | `nominal_duration_ms` | int | [80, 800] across all menu animations | Authored animation duration before accessibility gating |
| Reduced-motion flag | `reduced_motion_enabled` | bool | {true, false} | `SettingsService.accessibility.reduced_motion_enabled` |
| Actual duration | `actual_duration_ms` | int | {0} ∪ [80, 800] | Duration the tween actually uses; 0 = instant |

**Nominal duration registry** (locked by §C / Art Director):

| Animation | `nominal_duration_ms` | Curve |
|---|---|---|
| Folder slide-in | 180 | `TRANS_CUBIC EASE_OUT` |
| Folder slide-out | 140 | `TRANS_CUBIC EASE_IN` |
| Stamp slam-down | 100 | Scale 0%→120%→100% (2-keyframe) |
| Save-failed header band slide-in | 80 | Linear |
| Screen-shuffle paper transition | 100 | Two concurrent translate+fade tweens |
| Menu music fade-out | 800 | Audio-bus linear fade (not a Tween) |
| Quicksave feedback fade-out | 200 | F.4 |

**Output Range:** Either 0 (instant) or the nominal value. Binary gate — no interpolated partial reduction. Rationale: WCAG 2.3.3 requires the ability to *remove* animation, not merely slow it.

**Evaluation point:** Evaluated at `_play_*` call time (when animation begins), not per-frame. If `reduced_motion_enabled` changes mid-flight, the in-flight tween completes at original duration; the setting takes effect on the next `_play_*` call.

**Worked example — folder slide-in with reduced-motion OFF:** `actual_duration_ms(180, false) = 180 ms` → `Tween.tween_property(...).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_duration(0.180)`.

**Worked example — stamp slam with reduced-motion ON:** `actual_duration_ms(100, true) = 0 ms` → skip tween entirely; set stamp to final state immediately.

**Verification gate:**
- **GATE-F3-A** (MEDIUM, BLOCKING for impl): Confirm `Tween.set_duration(0.0)` behaves as instant property-set in Godot 4.6, not as divide-by-zero or no-op. If unreliable, branch: `if actual_duration_ms == 0: [instant set]; else: [tween with duration / 1000.0]`.

---

### F.4 — Quicksave Feedback Timeline

```
t_hold_end_s    = quicksave_feedback_duration_s - 0.2
t_fade_start_s  = t_hold_end_s
t_fade_end_s    = quicksave_feedback_duration_s

opacity(t) =
    1.0                                      if t < t_hold_end_s
    1.0 - (t - t_fade_start_s) / 0.2         if t_hold_end_s ≤ t ≤ t_fade_end_s
    0.0                                      if t > t_fade_end_s
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Display duration | `quicksave_feedback_duration_s` | float | [0.8, 3.0] — default **1.4 s** (tuning knob) | Total time from card appearance to opacity = 0 |
| Fade window | `0.2` | float | 0.2 (fixed) | Final fade-out duration (perceptual minimum) |
| Hold end time | `t_hold_end_s` | float | `duration − 0.2` | Time at which opacity begins declining |
| Opacity | `opacity(t)` | float | [0.0, 1.0] | Card `modulate.a` at time `t` after appearance |

**Output Range:** `opacity` ∈ [0.0, 1.0]. Card freed (`queue_free()`) the frame after opacity reaches 0.0.

**Worked example — default settings (1.4 s):**
- `t_hold_end_s = 1.4 − 0.2 = 1.2 s`
- At `t = 0.0`: `opacity = 1.0`
- At `t = 1.2`: hold ends; fade begins
- At `t = 1.3`: `opacity = 1.0 − (1.3 − 1.2)/0.2 = 0.5`
- At `t = 1.4`: `opacity = 0.0`; freed next frame

**Debounce-replace on successive quicksaves:** Second quicksave at `t_2` while feedback card is still visible: `restart_timer()` resets `t = 0`; in-flight fade tween is `stop()`-ed and a new tween begins from scratch. Card returns to `opacity = 1.0` immediately at `t_2`. **Implementation:** the `Tween` object MUST be stored as instance variable `_feedback_tween` so it can be stopped before reinitialisation. Do not use fire-and-forget `create_tween()`.

**Save-failed override rule:** If `Events.save_failed` fires while feedback card is visible: card vanishes instantly (no fade), `queue_free()`, then `ModalScaffold.show_modal(SaveFailedContent)`. Skipped regardless of `reduced_motion_enabled` (no animation competition with error modal).

**Verification gate:**
- **GATE-F4-A** (MEDIUM, BLOCKING for impl): Confirm `Tween.stop()` on a Tween created via `create_tween()` does not free the Tween object (allowing restart). Distinction between `stop()`, `kill()`, and reference lifetime is documentation-dependent in Godot 4.x.

---

### F.5 — In-Card Overwrite-Confirm Two-Press Exit Predicate

```
card_in_confirm_state(card)     := bool   per card
any_card_in_confirm_state(grid) := OR over all cards c of card_in_confirm_state(c)

should_close_save_grid_on_ui_cancel(grid) :=
    NOT any_card_in_confirm_state(grid)
```

**Per-card state machine:**

```
NORMAL → [select OCCUPIED card] → CONFIRM_PENDING
CONFIRM_PENDING → [ui_cancel]    → NORMAL   (one ui_cancel consumed; grid does NOT close)
CONFIRM_PENDING → [CONFIRM btn]  → NORMAL   (save executes)
CONFIRM_PENDING → [CANCEL btn]   → NORMAL
NORMAL → [ui_cancel] → evaluate should_close_save_grid_on_ui_cancel(grid)
                       → true  → close Save grid; restore focus to "File Dispatch" in Pause Menu
                       → false → unreachable from NORMAL state (single-focus invariant)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Card confirm state | `card_in_confirm_state` | bool | {true, false} | This card showing inline overwrite-confirm UI |
| Grid aggregate | `any_card_in_confirm_state` | bool | {true, false} | Logical OR across all cards |
| Exit predicate | `should_close_save_grid_on_ui_cancel` | bool | {true, false} | Whether `ui_cancel` should close the Save grid |

**Output Range:** Boolean. Two-press rule: first `ui_cancel` while card is `CONFIRM_PENDING` resets that card to `NORMAL` (consumed by card's own `_unhandled_input`). Second `ui_cancel` (no card in confirm state) closes the grid.

**Single-focus invariant:** Only one card can be `CONFIRM_PENDING` at a time, because keyboard navigation allows focus on one card at a time and CONFIRM_PENDING is entered only on focused-card activation. The aggregate form is the correct predicate (remains valid if programmatic focus-bypass is introduced).

**Worked example — two-press exit:**
1. Player navigates to card 3 (OCCUPIED), presses `ui_accept`. Card 3 → `CONFIRM_PENDING`. `any_card_in_confirm_state = true`. `should_close = false`.
2. Player presses `ui_cancel`. Card 3's handler fires first (deepest-first), transitions card 3 → `NORMAL`, consumes the event. Grid remains open.
3. Player presses `ui_cancel` again. No card in `CONFIRM_PENDING`. `should_close = true`. Grid closes; focus returns to "File Dispatch" button.

**Verification gate:**
- **GATE-F5-A** (LOW): Confirm `_unhandled_input` propagation order — focused `Button`'s handler fires before parent `SaveGrid` container's handler. Documented behaviour; verify in 10-min editor test with `accept_event()`.

---

### F.6 — Per-Frame Budget Claim

Naming family extends HUD Core F.5 (`C_*` cost-term convention).

```
C_menu_steady = C_menu_idle = 0.0  ms   (gameplay phase — no scene tree nodes alive)

C_menu_pause  = C_menu_draw + (C_label_menu × N_label_menu_updates) + C_a11y_menu
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Idle cost (gameplay) | `C_menu_idle` | float (ms) | **≤ 0.005 ms (below measurement threshold; not exactly zero)** | Cost while Pause Menu NOT visible: PauseMenuController is a Node in the scene tree with `_unhandled_input` dispatch per propagated input event + InputContextStack autoload property read in CR-3 guard. These costs are non-zero but unmeasurable on target hardware (Iris Xe). PauseMenuController has no `_process`, no active subscriptions, no instantiated PauseMenu nodes (CR-4: `add_child` on demand). **Menu claims below-measurement-threshold ADR-0008 budget during gameplay.** Honesty correction applied 2026-04-27 — prior "0.0 (exact)" claim made AC-MENU-16.1 fail on any honest profiler check. |
| Draw cost (pause visible) | `C_menu_draw` | float (ms) | est. [0.01, 0.04] | Per-frame render cost: ~7 `Button` + 1 `PanelContainer` + `ColorRect`. No `_draw()` overrides per FP rules. |
| Per-Label update cost | `C_label_menu` | float (ms) | est. [0.02, 0.05] (same family as HUD `C_label`) | One `Label.text` write inside Menu surfaces during pause. Steady-state typical value: 0 updates/frame (labels are static once rendered). |
| Label updates this frame | `N_label_menu_updates` | int | [0, 2] | 0 in steady-state. Save-card grid open: one-time burst of 7 reads, NOT per-frame. |
| AccessKit overhead | `C_a11y_menu` | float (ms) | est. [0.005, 0.030] (same family as HUD `C_a11y`) | Per-frame accessibility-tree maintenance. Same OQ-HUD-5 measurement gate applies. |
| Total pause-visible | `C_menu_pause` | float (ms) | est. [0.015, 0.070] (shell only) | Worst case ~0.070 ms for the static Pause Menu shell (7 buttons + ColorRect + folder texture). |
| Pause + Save grid open | `C_menu_pause_grid` | float (ms) | est. [0.080, 0.250] (per-frame) | Per-frame steady-state with 7 cards rendered (each card = PanelContainer + 3+ Labels + stamp overlays = ~21+ Labels in tree). Excludes the one-time grid-open burst (sidecar I/O). Added 2026-04-27 to address performance-analyst's worst-case scoping concern. |
| Save grid I/O burst | `C_menu_grid_io` | ms (one-time) | bounded ≤ 50 ms target on Iris Xe + spinning storage; ≤ 5 ms typical on SSD | One-time spike when Save / Load grid opens: 7 × `slot_metadata(N)` sidecar reads. Recommendation: cache sidecar metadata in SaveLoad on autoload `_ready()` so grid-open is a memory read, not disk I/O. **[BLOCKING coord — Save/Load GDD]**: confirm sidecar caching policy. |

**Output Range:** **≤ 0.005 ms below-measurement-threshold** during gameplay (CR-3 guard cost only). **~0.040 ms typical / ~0.070 ms worst-case** during Pause shell. **~0.080–0.250 ms per-frame during Save/Load grid-open state.** The 16.6 ms frame budget remains the target during Pause as well — Menu's marginal contribution is small but the gameplay scene's own systems (which continue to tick, since `get_tree().paused = false` per CR-4) still claim their normal budget. **The earlier framing "16.6 ms frame budget is not gameplay-critical during Pause" was misleading and is rescinded in design-review 2026-04-27** — only Menu's slice is small; the full budget is still contested.

**Worked example — static Pause Menu open, no interactions:**
`C_menu_pause = 0.025 + (0.035 × 0) + 0.015 = ~0.040 ms`.

**ADR-0008 sub-slot recommendation:** Menu System does **NOT** claim a named ADR-0008 sub-slot. Rationale:

1. During gameplay (the budget-critical phase): `C_menu_idle = 0.0 ms` exactly — there is nothing to claim.
2. During Pause: the engine is rendering a paused scene. The 16.6 ms frame budget is not gameplay-critical in this state.
3. Save-card grid-open is one-time initialisation, categorically outside per-frame budget scope.

Recommendation: **record Menu System as "zero steady-state gameplay claim" in a comment on ADR-0008 Slot 7** — no named sub-slot reservation. Consistent with how other purely-modal systems (Document Overlay #20, Settings panel) should be treated.

**No verification gate** — this is a budget composition, not an engine-API question.

---

### F.7 — Modal AccessKit One-Shot Timing

```
live_state(t) =
    "assertive"    if t == 0     (t = frames since modal became visible, counting from 0)
    "off"          if t >= 1
```

**Full frame-boundary state machine:**

```
Frame N   (modal becomes visible):
    1. Set accessibility_live = "assertive"   ← BEFORE visible = true
    2. Set visible = true
    3. call_deferred("set", "accessibility_live", "off")   ← queued for Frame N+1

Frame N+1 (deferred callback fires):
    4. accessibility_live = "off"
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Frames since visible | `t` | int | [0, ∞) | 0 = the frame in which `visible = true`; counts in engine frames |
| Live region value | `live_state(t)` | string | {"assertive", "off"} | The `accessibility_live` property value on the modal's root `Control` |

**Output Range:** "assertive" for exactly one frame (frame N), then "off" until the next visibility transition. Per-visibility-transition one-shot, NOT per-modal-lifetime.

**Why assertive BEFORE visible:** Screen-readers observe the `accessibility_live` property change. If `visible = true` fires first and `assertive` fires second, the AT may not announce the modal content (the accessibility tree was populated as a non-live region). Setting `assertive` first primes the AT to announce when the tree populates.

**Why `call_deferred` for the reset:** queues the call to execute at the end of the current frame's idle time (after all `_process` and signal handlers). Guarantees `accessibility_live = "off"` is set on Frame N+1, ensuring the AT has a full frame to process the assertive announcement.

**Re-show within the same frame edge case:** First `_show_modal` → `_hide_modal` → second `_show_modal` all in same frame: each show queues its own deferred reset; both set `"off"` (idempotent — second is a no-op). Net result: AT receives the assertive announce from the second show.

**Worked example — save-failed modal (CR-10):**
- Frame 60: `Events.save_failed` received. `ModalScaffold.show_modal(SaveFailedContent)`.
- Frame 60, step A: `modal_root.accessibility_live = "assertive"`
- Frame 60, step B: `modal_root.visible = true`
- Frame 60, step C: `modal_root.call_deferred("set", "accessibility_live", "off")` queued.
- Frame 61: `accessibility_live = "off"`. Screen-reader announces *"DISPATCH NOT FILED — Write error. Retry?"* (the assertive live-region announcement from frame 60).

**Verification gates — HIGH RISK:**
- **GATE-F7-A** (HIGH, BLOCKING for MVP — elevated in design-review 2026-04-27 from "VS-BLOCKING / MVP-ADVISORY"): Confirm exact GDScript property name for AccessKit live regions on `Control` in Godot 4.6. ADR-0004 Gate 1 already identifies this as unverified. **Rationale for MVP elevation**: the Day-1 photosensitivity boot-warning depends on `accessibility_role = "dialog"` and the assertive one-shot pattern (CR-21). If property names are wrong, the boot-warning does not announce — defeating the very gate that closes HUD Core REV-2026-04-26 D2 + Settings OQ-SA-3 simultaneously. **A 10-minute editor session reading `Control` GDScript API autocomplete is the only reliable verification.** If the property does not exist in 4.6 GDScript, the entire one-shot pattern must be replaced with whatever AccessKit API Godot 4.6 exposes. **Do not implement Day-1 MVP slice without verification.**
- **GATE-F7-B** (MEDIUM): Confirm `call_deferred("set", "property_name", value)` syntax in 4.6 GDScript. The alternative `call_deferred.bind(...)` form may be required.

---

### F.8 — `accessibility_name` Re-Resolve on Locale Change

```
accessibility_name_current(control, locale) =
    tr(control._accessibility_name_key, locale)

should_update_accessibility_names(notification) =
    notification == NOTIFICATION_READY
    OR notification == NOTIFICATION_TRANSLATION_CHANGED
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Control node | `control` | Node | any Control with localised `accessibility_name` | The Control whose `accessibility_name` must stay in sync with current locale |
| Locale | `locale` | string | valid BCP-47 | Currently active locale; changes when `TranslationServer.set_locale()` is called |
| Translation key | `_accessibility_name_key` | string | non-empty key in `translations/menu.csv` | Stored as `const` on node script |
| Notification | `notification` | int | Godot notification enum | The notification triggering re-resolve |
| Output | `accessibility_name_current` | string | translated string in active locale | Correct localised accessibility name |

**Output Range:** Always a non-empty translated string while the key exists in active locale. Fallback: missing key → `tr()` returns the key itself (Godot's documented fallback). Acceptable — screen reader announcing the key is a localisation bug, not a crash.

**Implementation contract** — every Control in a Menu scene with a localised `accessibility_name` MUST implement:

```gdscript
const ACCESSIBILITY_NAME_KEY := "menu.surface.widget_id"

func _ready() -> void:
    _update_accessibility_names()

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        _update_accessibility_names()

func _update_accessibility_names() -> void:
    accessibility_name = tr(ACCESSIBILITY_NAME_KEY)
    # … repeat for each localised accessibility_name on this node's subtree
```

**Worked example — "Resume Surveillance" button locale switch EN → FR:**
- `_ready()`: `accessibility_name = tr("menu.pause.resume")` → `"Resume Surveillance"` (EN)
- User switches locale to FR in Settings.
- `SettingsService.setting_changed("language.locale", "fr")` fires.
- Localization Scaffold calls `TranslationServer.set_locale("fr")` and broadcasts `NOTIFICATION_TRANSLATION_CHANGED`.
- Control's `_notification` fires with `NOTIFICATION_TRANSLATION_CHANGED`.
- `_update_accessibility_names()` runs: `accessibility_name = tr("menu.pause.resume")` → `"Reprendre la surveillance"` (FR).

**CI gate (FP-9 family):** scene-tree scan for any `Control` in `src/ui/menu/` scenes that:
1. Has a non-empty `accessibility_name` literal in the `.tscn` file (scene-authored), AND
2. Does NOT have either: (a) a `_notification` override calling `_update_accessibility_names()`; OR (b) a parent surface script's `_notification` handler iterating its subtree.

ADVISORY at MVP (English-only); BLOCKING before VS ships a localisable locale.

**Verification gates:**
- **GATE-F8-A** (LOW): Confirm `NOTIFICATION_TRANSLATION_CHANGED` is the correct constant name in 4.6 and fires on `Control` (not just `Node` base class) when `TranslationServer.set_locale()` is called.
- **GATE-F8-B** (MEDIUM, ADVISORY — resolution committed 2026-04-27): Confirm whether 4.6's AccessKit auto-re-resolves `accessibility_name = tr(...)` on locale change — i.e., whether `auto_translate_mode` covers `accessibility_name`. **Resolution: CR-22 plumbing is mandatory regardless of gate outcome (defensive).** If `auto_translate_mode` covers `accessibility_name` in 4.6, the manual `_notification` handler is benign redundancy — two lines per widget. If it does not, the manual handler is essential. Cost of being defensive: minimal. Cost of being wrong on the optimistic side: silent AT locale breakage. Defensive plumbing chosen. The gate outcome no longer affects whether CR-22 ships, only whether it can be removed as cleanup post-VS.

---

### Cross-Formula Family Notes

- **Naming continuity with HUD Core F.5**: F.6 reuses `C_label_menu`, `C_a11y_menu`, `C_draw_menu` prefixes. When OQ-HUD-5's measurement campaign runs (C_label and C_a11y on Iris Xe / Godot 4.6 / 810p), measured values feed both HUD F.5 and Menu F.6 worked examples — they share the same TextServer + AccessKit measurement context.
- **Reduced-motion gate**: F.3 is the single canonical gate for all 7 menu animations. F.4's 0.2 s fade is subject to F.3's gate. F.4's save-failed override (instant dismiss) is a separate code path — applies regardless of accessibility setting.
- **No new cross-system registry entries required.** All constants used (`menu_music_fade_out_ms`, `quicksave_feedback_duration_s`) are Menu-internal tuning knobs (§G). `reduced_motion_enabled` is owned by SettingsService and already registered. F.6's zero-claim recommendation means no ADR-0008 registry amendment.

### Verification gates summary by risk

| Gate | Formula | Risk | Blocking level |
|---|---|---|---|
| GATE-F7-A: `accessibility_live` property name | F.7 | **HIGH** | **BLOCKING for MVP** (elevated 2026-04-27; Day-1 boot-warning AT announcement depends on this; bundles with ADR-0004 Gate 1) |
| GATE-F2-A/B: TextServer `Label.get_line_count()` / autowrap mode | F.2 | MEDIUM | BLOCKING before localisation ships |
| GATE-F3-A: `Tween.set_duration(0.0)` behaviour | F.3 | MEDIUM | BLOCKING for impl |
| GATE-F4-A: `Tween.stop()` vs `kill()` lifecycle | F.4 | MEDIUM | BLOCKING for impl |
| GATE-F7-B: `call_deferred("set", ...)` syntax | F.7 | MEDIUM | BLOCKING for impl |
| GATE-F8-B: `auto_translate_mode` covers `accessibility_name` | F.8 | MEDIUM | ADVISORY |
| GATE-F1-A/B: GridContainer 7-child stop / gap API | F.1 | LOW | ADVISORY |
| GATE-F5-A: `_unhandled_input` propagation order | F.5 | LOW | ADVISORY |
| GATE-F8-A: `NOTIFICATION_TRANSLATION_CHANGED` constant | F.8 | LOW | ADVISORY |

## Edge Cases

40 cases across 10 clusters. Each case names the exact condition AND the exact resolution. Cases that introduce NEW coord items (beyond §C's 6 BLOCKING) are flagged inline.

### Cluster A — Boot Lifecycle

- **If `SettingsService._ready()` has not yet completed when `MainMenu._ready()` polls `_boot_warning_pending`**: This cannot happen under ADR-0007 — autoloads complete `_ready()` calls in slot order BEFORE the main scene's `_ready()` fires. No guard needed; assert in tests only. Document the ordering guarantee as a comment in `MainMenu._ready()` citing ADR-0007.
- **If `user://settings.cfg` is absent on first launch and `_boot_warning_pending` defaults to `true`**: The modal mounts normally per CR-8 Branch A. `SettingsService.dismiss_warning()` writes `accessibility.photosensitivity_warning_dismissed = true` to an initially-empty cfg file; `FileAccess.open_compressed()` creates `user://settings.cfg` on first write. The boot-warning IS the first-launch gate.
- **If `_boot_warning_pending == true` and the player attempts to activate "Begin Operation" before the Continue button (modal) is reachable (fast click during modal fade-in)**: `set_process_input(false)` is called on the Main Menu button container in `_ready()` BEFORE `show_modal()`. The modal pushes `Context.MODAL` before any frame is rendered. Any input on the button container is dropped. Focus is set inside the modal. The button container never activates.
- **If the `ModalScaffold` node is missing from the MainMenu scene tree (authoring error)**: Add `assert(modal_scaffold != null, "ModalScaffold child required in MainMenu.tscn")` as the first line of `_ready()`. The error surfaces immediately as a readable authoring-time crash rather than a silent null-dereference at boot-warning poll time.
- **If `SettingsService.dismiss_warning()` fails (disk full on first write)**: The modal remains visible; `Context.MODAL` remains on stack; menu stays non-interactive. The player can press Continue again. Next boot re-shows the warning because `_boot_warning_pending` remains `true` (the flag was never written). The player cannot progress until disk space is freed. **This is acceptable** — the warning is a Day-1 MVP hard gate; the system must not silently pretend it was acknowledged. **[NEW BLOCKING coord — Settings GDD]**: `SettingsService.dismiss_warning()` must return `bool` indicating write success.

### Cluster B — Same-Frame Input Storms

- **If the player presses `ui_cancel` on the same frame that `Events.save_failed` fires while PauseMenu is open**: `save_failed` triggers `ModalScaffold.show_modal(SaveFailedContent)` pushing `Context.MODAL`. `_unhandled_input` at PauseMenu checks `peek() == PAUSE` first; with `MODAL` now top-of-stack, the `ui_cancel` event propagates to `ModalScaffold._unhandled_input()`, which interprets it as Cancel ("Abandon") on save-failed. Pause Menu behind is unaffected. No race — both signal handling and `_unhandled_input` run in the same frame's idle step; `show_modal()` calls `push(MODAL)` synchronously before the input handler runs.
- **If the player mashes `ui_accept` on a Save grid slot on the same frame `Events.save_failed` fires**: The in-card overwrite-confirm enters `CONFIRM_PENDING`. Then save-failed fires; `Context.MODAL` is pushed. The card stays in `CONFIRM_PENDING` visually but unreachable behind the modal. On Save-Failed dismiss ("Abandon"), `Context.MODAL` pops; the save grid is still visible with the card in `CONFIRM_PENDING`; focus returns to the `[CANCEL]` button inside the card (the `return_focus_node` passed to `show_modal()` MUST be the card's `[CANCEL]` button, not the card itself).
- **If the `pause` action fires on the same frame that `LevelStreaming.transition_to_section()` was called (`Context.LOADING` was just pushed)**: CR-3 + the Push/Pop Matrix guarantee `PauseMenuController._unhandled_input()` checks `peek() == GAMEPLAY` before mounting Pause Menu. With `LOADING` on stack, the guard fails; `pause` input is silently consumed. No Pause Menu mounts.
- **If `Events.save_failed` fires while a New-Game-overwrite-confirm modal is already open**: `ModalScaffold.show_modal()` is hosting `NewGameOverwriteContent`. **[NEW BLOCKING coord — §C.4 amendment]**: `ModalScaffold` must implement a depth-1 queue. The incoming `show_modal(SaveFailedContent)` is queued in `_pending_modal_content`; shown immediately after `hide_modal()`. Queue depth is 1 — a second queued item replaces the first (save-failed is idempotent — the most recent failure is what the player needs to see).
- **If `Events.game_saved` and `Events.save_failed` fire in the same frame** (Save/Load internal inconsistency): Per F.4 Save-Failed override rule, quicksave feedback card vanishes instantly, `queue_free()`, then `ModalScaffold.show_modal(SaveFailedContent)`. The `_feedback_tween.stop()` + `queue_free()` + `show_modal()` sequence runs because `save_failed` handler checks `is_instance_valid(_feedback_card)` before stopping the tween.

### Cluster C — Save / Load Grid Edge Cases

- **If `SaveLoad.slot_metadata(0)` returns a Dictionary with `section_id` mapping to a section that no longer exists in the build (version mismatch)**: Continue button renders enabled (non-null metadata). On activation, LS fails internally when section resource is not found. **[NEW BLOCKING coord — LS GDD]**: `LS.transition_to_section()` must surface failure either via a `transition_failed(reason)` signal or by returning `bool`. On failure: pop `Context.LOADING`, re-push `Context.MENU`, show `ModalScaffold.show_modal(SaveFailedContent)` with a version-mismatch-specific body string.
- **If `SaveLoad.slot_metadata(N)` returns `null` for a slot whose `.res` exists on disk** (sidecar missing but `.res` present): Render slot as `CORRUPT` per CR-25 (`████ ████ ████` redacted lines + `DOSSIER CORROMPU` stamp + `disabled = true`). AccessKit announces *"Dispatch N. File damaged. Cannot load."* The underlying `.res` is not opened (ADR-0003).
- **If `slot_metadata(0)` returns non-null Dictionary but every expected key is empty string** (corrupt but structurally valid sidecar — zero-byte write): The Continue button non-null check passes but the card displays empty metadata. Resolution: caller must validate `metadata.get("section_id", "")` is non-empty. If empty: treat as `CORRUPT`. For slot 0: Continue button falls through to "Begin Operation" label (CR-5). **[NEW BLOCKING coord — Save/Load GDD]**: define the canonical "required keys" set for sidecar validation, so Menu has a deterministic `is_valid_metadata(dict) -> bool` predicate.
- **If `DirAccess.rename()` fails mid-slot-rotation during save** (partial write — old renamed but new write fails): Entirely Save/Load territory — Menu does not call `DirAccess` directly (ADR-0003). Save/Load fires `Events.save_failed` per CR-9; Menu handles per CR-10. The slot may temporarily appear `CORRUPT` on next grid render if sidecar absent. The "Retry" button re-attempts `SaveLoad.save_to_slot(N)` (most-recent target stored as `_last_save_slot: int`).
- **If slot 0 metadata is `CORRUPT` and the player activates Continue/"Begin Operation"**: CR-5 specifies that null/empty/corrupted slot 0 → button shows "Begin Operation" and behaves identically to New Game. CORRUPT detection must happen at `_ready()`/slot-display time and set a flag `_slot_0_available: bool` used by CR-5. CORRUPT slot 0 → `_slot_0_available = false` → Begin Operation label → New Game flow. No overwrite-confirm modal (nothing valid to overwrite).
- **If in-card overwrite-confirm is active on slot 3 and `Events.save_failed` fires from a different subsystem** (background autosave failure not from this menu's action): The card is in `CONFIRM_PENDING`. Save-failed modal opens. On dismiss, `Context.MODAL` pops; card 3 is still `CONFIRM_PENDING`; focus returns to the card's `[CANCEL]` button (`return_focus_node` for save-failed modal MUST be set to the card's `[CANCEL]` button, not the Save grid root). The "Retry" path retries the autosave, NOT the manual slot-3 save (each save target tracks its own retry semantics in Save/Load).
- **If LS `transition_to_section(LOAD_FROM_SAVE)` is called and the step-9 restore callback fires, but `save_failed` fires on the same frame during section restore**: Menu trees are already destroyed by LS scene change. `_exit_tree()` unsubscribed via `is_connected()` guard (ADR-0002 §Impl-Guideline-3). Signal lands on no Menu subscriber — emitted into empty space, no crash. The new section scene's HUD or overlay must handle this. Document: "save-failed subscription is per-scene-lifetime; newly-loaded section scenes must re-subscribe if they need save-failed handling."

### Cluster D — Modal Scaffold Lifecycle

- **If `SettingsService.open_panel()` is called while boot-warning modal is active** (impossible under CR-8 since button container has `set_process_input(false)`, but defensive case): `peek()` is `MODAL`. `open_panel()` should `assert(peek() in [MENU, PAUSE])` before pushing `SETTINGS`. If assertion fires, `push_error()` and return early. The boot-warning stays visible. This guard lives in Settings GDD CR-7, not Menu, but Menu must `assert(peek() != Context.MODAL)` before calling `open_panel()`.
- **If `Events.save_failed` fires while a quit-confirm modal is open**: Quit-confirm displayed via ModalScaffold; `Context.MODAL` on stack. The save-failed `show_modal()` hits the `_pending_modal_content` queue (Cluster B case 4). Save-failed content is queued. Quit-confirm proceeds. On "Close File": `get_tree().quit()` — queued modal never shows (process exits). On "Continue Mission" Cancel: quit-confirm closes; pending save-failed `show_modal()` fires immediately. Player sees save-failed dialog with full context.
- **If a modal is opened during a scene change** (the `change_scene_to_file()` for "Return to Registry" was issued, `Context.LOADING` was pushed, and `save_failed` fires in the same frame before the scene change destroys the tree): `Context.LOADING` on stack. `save_failed` fires; `show_modal()` assertion `peek() in [MENU, PAUSE]` fails on `LOADING`. `show_modal()` returns early; signal dropped. Scene change proceeds. Correct behavior — player cannot interact during loading.
- **If `return_focus_node` passed to `ModalScaffold.hide_modal()` has been freed before modal closes** (triggering button removed during modal session — possible during locale-change-triggered button list rebuild): `hide_modal()` calls `return_focus_node.call_deferred("grab_focus")`. If freed, `call_deferred` on freed object silently does nothing (Godot 4.x). Focus is now unanchored. Resolution: before calling, check `is_instance_valid(return_focus_node)`. If false: fall back to `_default_focus_target.call_deferred("grab_focus")` where `_default_focus_target` = first focusable button in parent menu surface (Continue / "Begin Operation" for MainMenu; "Resume Surveillance" for PauseMenu).
- **If `ModalScaffold.show_modal()` is called while `Context.LOADING` is active**: `assert(peek() in [MENU, PAUSE])` blocks the call. Signal dropped. Document as intentional: during loading, all error modals are invisible because the player cannot act on them — the scene is changing. Any save-failed during this window is a silent drop; the new scene's first autosave will re-emit if condition persists.

### Cluster E — Gamepad + Input Device Lifecycle

- **If a gamepad disconnects while focus is on a Save grid slot in `CONFIRM_PENDING` state**: `Input.joy_connection_changed(device_index, connected=false)` fires. Per Input GDD L156, Menu subscribes. On disconnect: display a transient non-modal notification using the F.4 quicksave feedback card pattern (BQA Blue band, *"Controller disconnected. Continue with keyboard."*). Save grid remains open; CONFIRM_PENDING card remains visible; keyboard navigation takes over (focus stays on `[CANCEL]`). Player can complete or cancel with keyboard.
- **If a gamepad reconnects with a different device index** (player disconnects controller A, reconnects controller B — Godot reports as new device): `joy_connection_changed(new_device_index, connected=true)` fires. Menu stores `_active_gamepad_device: int` updated on each connect. Re-poll `Input.get_joy_name(new_device_index)` is informational only. Navigation resumes without state reset; focus preserved.
- **If two gamepads are connected simultaneously**: Godot's InputMap actions respond to any device by default. Both controllers drive the same focus cursor — expected behavior. Single-player game; multi-gamepad is benign in menus. Document as intentional.
- **If the player uses keyboard and gamepad simultaneously on the same frame** (dual-focus split — Godot 4.6 known issue per ADR-0004 §97): The `_unhandled_input()` + `event.is_action_pressed(&"ui_cancel")` pattern processes events in arrival order; first event matched is handled, `set_input_as_handled()` is called, second event does not re-fire. Result: one `ui_cancel`, not two. **[BLOCKING coord — ADR-0004 Gate 1]**: this `_unhandled_input` + `ui_cancel` bypass is specifically cited as the dual-focus-split workaround in ADR-0004 §97 but has not been engine-verified in 4.6. (Same gate already inherited.)
- **If gamepad disconnect occurs during the non-dismissible photosensitivity boot-warning modal**: Keyboard "Enter" / `ui_accept` still works on the Continue button (FOCUS_ALL responds to KB and gamepad). The `joy_connection_changed` handler queues the transient disconnect card — but the modal has `Context.MODAL` and button container has `set_process_input(false)`. The transient card must NOT push InputContext (same non-modal feedback pattern). Renders above modal at CanvasLayer 20+, auto-fades per F.4 timeline. Mouse cursor still works. Player can click Continue with mouse or press Enter.

### Cluster F — Window / Display Lifecycle

- **If the OS window loses focus** (alt-tab, minimize) **while the photosensitivity boot-warning modal is open**: Godot fires `NOTIFICATION_WM_FOCUS_OUT`. Menu does NOT pause the scene tree (`get_tree().paused = false` always per CR-4). Modal stays visible. On focus regain (`NOTIFICATION_WM_FOCUS_IN`), no state re-init needed; modal exactly as left. Boot-warning is non-dismissible so no accidental dismiss can occur.
- **If the OS window loses focus while a destructive confirm modal (quit-confirm, return-to-registry) is open**: Modal stays visible and non-responsive to OS-level events. Concern: `Input` may have missed a key-release event while focus was out. Resolution: on `NOTIFICATION_WM_FOCUS_IN`, call `Input.flush_buffered_events()` to clear any stale input state before the first `_unhandled_input` of the refocused frame. Prevents phantom `ui_cancel` from dismissing modal on refocus.
- **If the viewport emits `size_changed` while the Save grid is rendered** (player resizes window mid-pause): `GridContainer` re-layouts automatically; F.1 outputs are still valid (they describe child-offset geometry relative to container origin). On DPI change (window moved to different-DPI monitor), the custom mouse cursor's 32×32 hotspot may drift. Resolution: subscribe to `DisplayServer.window_set_dpi_changed` (if available in 4.6) and re-call `Input.set_custom_mouse_cursor()`. **[ADVISORY OQ]**: verify `DisplayServer.window_set_dpi_changed` exists in Godot 4.6 — if absent, accept cursor hotspot drift as known defect.
- **If the window is minimized during the LS `transition_to_section()` call** (player alt-tabs during loading): `Context.LOADING` on stack; no Menu input processed (dead-input state). LS scene change proceeds in background. Window restored → new section scene displayed. No Menu logic needed; LOADING is terminal for Menu.
- **If the custom mouse cursor is not reset when returning from an OS popup dialog**: Godot resets cursor to system default when focus is lost to OS chrome. On `NOTIFICATION_WM_FOCUS_IN`, re-call `Input.set_custom_mouse_cursor(fountain_pen_nib_texture, Input.CURSOR_ARROW, hotspot)` to restore in-game cursor. Add to `_notification()` handler in `MainMenu.gd` / `PauseMenu.gd` for `NOTIFICATION_WM_FOCUS_IN`.

### Cluster G — Localization Runtime Edge Cases

- **If a locale change fires (`NOTIFICATION_TRANSLATION_CHANGED`) while a save-failed modal is open**: CR-22 requires `_update_accessibility_names()` on locale change. All static `Label.text` update via `auto_translate_mode`. Modal body and button labels re-translate in place. Modal stays open — no dismiss/re-open cycle. F.7 one-shot assertive AccessKit announce is NOT re-triggered on locale change (modal already visible — re-asserting would re-announce). Only `accessibility_name` re-resolves (F.8 pattern).
- **If a locale change fires while in-card overwrite-confirm is active**: `[CANCEL]` and `[CONFIRM]` button labels are `tr("menu.save.overwrite_no")` / `tr("menu.save.overwrite_yes")` — both re-translate via `auto_translate_mode`. The confirm state machine (`card_in_confirm_state = true`) is not reset. Focus stays on `[CANCEL]`. No layout recompute needed (card geometry is fixed 360 × 96 px). If translated label overflows button width, button uses `text_overrun_behavior = TEXT_OVERRUN_TRIM_ELLIPSIS`.
- **If a translation key is missing for a locale** (e.g., `menu.save.card_location` has no Japanese entry): Godot's `tr()` returns the key itself as fallback — save card renders the key string in the location field. Ugly but not a crash. Resolution: Localization Scaffold's pseudo-locale stress test (which must include all `menu.*` keys) catches this before ship. Add `menu.save.card_location` and all template keys to Localization completeness CI check. `{section}` and `{time}` substitution tokens still substitute into whatever string `String.format()` receives.
- **If an RTL locale is activated at VS** (future-proof; none in MVP): All Menu surfaces use `CanvasItem.set_layout_direction(LayoutDirection.LAYOUT_DIRECTION_LOCALE)` (Godot Control default). `GridContainer` mirrors LTR order: slot 0 → top-right, slot 1 → top-left. F.1 `x_offset` formula remains correct for LTR layout only — formula is for CI position-assertions and must be marked as LTR-only. Add a comment on F.1: "RTL layout mirrors column order; formula assertions must account for layout direction." **No RTL locale ships at MVP or VS per Localization GDD; forward-compat note only.**
- **If a pseudolocale stress test (200% string-length expansion) causes a save card label to overflow its 360 × 96 px boundary**: Card `Label` must have `clip_contents = true` on `PanelContainer` and `text_overrun_behavior = TEXT_OVERRUN_TRIM_ELLIPSIS` on each `Label`. At 200% expansion, labels trim with ellipsis — card never expands beyond 360 × 96 px. F.1 grid geometry is preserved. Localization QA gate (not runtime crash); must be caught by pseudolocale CI pass before any locale ships.

### Cluster H — Settings Panel + Audio Coordination

- **If the Settings panel is open (`Context.SETTINGS`) and `Events.save_failed` fires**: `ModalScaffold.show_modal()` assertion `peek() in [MENU, PAUSE]` fails on `SETTINGS`. Modal does not mount; signal dropped. Correct: while Settings is open, the player cannot save; a save-failed from background autosave should not interrupt a settings session. On Settings close, if cause persists, next autosave re-emits and modal appears correctly. Document as intentional.
- **If `setting_changed("accessibility", "reduced_motion_enabled", true)` fires while a folder slide-in tween is in flight**: Per F.3, gate is evaluated at `_play_*` call time, NOT per-frame. In-flight tween completes at original `nominal_duration_ms`. Next `_play_*` evaluates `reduced_motion_enabled = true` and uses `actual_duration_ms = 0`. No mid-tween kill.
- **If menu music fade is in progress and the player immediately opens Settings via keyboard shortcut**: The "Begin Operation" button handler issues `await` on music fade before calling LS. If `open_panel()` is called from a different button while the coroutine awaits, two coroutines are now in flight. Before calling `LS.transition_to_section()`, check `peek() == LOADING` — if Settings opened during the await, `peek()` would be `SETTINGS` and the guard would block the LS call. **[NEW BLOCKING coord — CR-6 amendment]**: the "Begin Operation" button must be `disabled = true` after first press to prevent re-entrant coroutines (see CR-6 amendment below).
- **If Audio fails to load the `MAIN_MENU` music asset at boot**: Menu calls music fade-out before LS — a no-op if no music is playing (the bus has no signal to fade). Coroutine completes immediately. LS proceeds normally. Menu does not subscribe to Audio error signals (Audio's domain). Document as: "if `MAIN_MENU` bus has no audio loaded, the fade coroutine returns immediately and LS transition proceeds without delay."

### Cluster I — Cross-System Signal Collisions

- **If `Events.game_saved(slot=0)` fires while Pause Menu is closing** (`_exit_tree()` running): `_exit_tree()` unsubscribes via `is_connected()` guard (ADR-0002 §Impl-Guideline-3). If signal fires after `_exit_tree()` starts, unsubscribe has run — handler not called. If signal fires before `_exit_tree()`, feedback card instantiates as PauseMenu child but parent's `queue_free()` chain kills the card. No orphan node; no crash. `queue_free()` is deferred to end-of-frame.
- **If `Events.game_loaded(slot=0)` fires during `Context.LOADING`**: Menu trees being destroyed by LS scene change. `_exit_tree()` unsubscribes. Signal lands on no Menu subscriber. No feedback card shown. New section scene must display load-confirmation feedback via its own mechanism (out of Menu scope).
- **If `FailureRespawn.restart_from_checkpoint()` is called while the quicksave feedback card is visible**: Feedback card is child of PauseMenu. `restart_from_checkpoint()` triggers LS scene reload, destroying tree including feedback card. `_feedback_tween` cleaned up by `queue_free()` chain. F.4 save-failed override does NOT apply (Re-Brief uses modal scaffold, not feedback card). Card simply dies with scene tree.
- **If `Events.save_failed` fires after `get_tree().quit()` has been called** (quit-confirm "Close File" path): Engine shutdown scheduled at end-of-frame. Subscribers either still connected (assertion fails on missing `MENU/PAUSE`, `push_error`, modal does not mount) or already disconnected (signal into empty space). Either path: clean shutdown without crash modal during exit.
- **If F&R `restart_from_checkpoint()` completes and step-9 restore callback fires, but `Events.save_failed` also fires from checkpoint re-write during restore**: Same as Cluster C case 7 — Menu trees destroyed by LS scene change; no Menu subscriber. Save-failed fires into empty space. Restore proceeds. New section scene handles if it subscribes. Out of Menu GDD scope.

### Cluster J — Pillar 5 / Forbidden Pattern Enforcement at Runtime

- **If a future GDD revision introduces a `Tween` for focus-hover animation on a Save card** (violating FP-8): The FP-8 grep gate does not catch `create_tween()` (modern Godot 4.x idiom). **[NEW in-house amendment to FP-8 below]**: extend grep pattern to match `create_tween\|Tween\.new\|AnimationPlayer\.play` on focus-callback methods.
- **If a localization workflow accidentally injects an exclamation mark into a `menu.*` CSV value** (violating FP-7): FP-7 grep gate checks `translations/menu.csv` value column. Resolution: the CI pipeline must run FP-7 grep as a BLOCKING gate (not advisory) before any locale string is merged. Lint runs on raw CSV before TranslationServer imports. A `!` in a tr-key name is not caught by value-column lint — extend grep to also check key names if translation tooling could produce malformed keys.
- **If a developer adds a `print()` statement inside a Menu Label's text-update path that renders debug to a `Label.text`** (indirectly violating FP-9 — wrong text in Label): Not grep-able as a Pillar violation. Resolution: add an AC verifying `Label.text` values in Menu scenes only contain `tr(...)` return values at runtime (no raw string literals or `str(...)` debug output). AC is integration test checking all visible `Label` nodes against the `tr("menu.*")` key space.
- **If a save thumbnail is accidentally rendered by a future integration** — e.g., a `SubViewport` added to `SaveCard.tscn` for a "live preview" feature (violating FP-3): FP-3 grep covers `Texture2D`, `screen_get_image()`, `Viewport.get_texture().get_image()`. A `SubViewport` node would not be caught. **[NEW in-house amendment to FP-3 below]**: extend FP-3 grep to include `SubViewport` node type inside `SaveCard.tscn` and any Menu scene: `grep -n "SubViewport" src/ui/menu/`.
- **If `Time.get_datetime_dict_from_system()` is introduced via a "last saved X minutes ago" feature** (simultaneously violating FP-4 and FP-5): FP-4 already covers these `Time.*` calls in `src/ui/menu/`; FP-5 covers string values. Both are CI BLOCKING. Bypass risk: developer could compute relative time in a different module (e.g., SaveLoad) and pass pre-formatted string in sidecar metadata. Resolution: **[NEW BLOCKING coord — Save/Load GDD]**: sidecar metadata schema must explicitly prohibit relative-time strings; all timestamps must be mission-time `{section} — {time} GMT` format only.

### NEW BLOCKING coord items emerging from §E

Six new BLOCKING coord items are introduced beyond §C's six. The ADR-0004 / Gate 1 / Gate 2 / Settings amendments / F&R `has_checkpoint()` items remain.

1. **§C.4 amendment — `ModalScaffold._pending_modal_content` queue**: depth-1 queue; `show_modal()` while `_is_modal_active = true` queues the incoming content; `hide_modal()` flushes the queue. Required by Cluster B case 4 and Cluster D case 2.
2. **LS GDD coord — `transition_failed` signal or return bool**: `LS.transition_to_section()` must surface failure (e.g., section resource not found / version mismatch). Required by Cluster C case 1.
3. **Save/Load GDD coord — sidecar required-keys validation predicate**: define canonical "required keys" set so Menu has deterministic `is_valid_metadata(dict) -> bool`. Required by Cluster C case 3.
4. **CR-6 amendment (in-house, applied below) — "Begin Operation" button `disabled = true` after first press**: prevents re-entrant music-fade coroutine. Required by Cluster H case 3.
5. **Settings GDD coord — `dismiss_warning()` returns bool**: detect disk-full failure at boot-warning Continue press. Required by Cluster A case 5.
6. **§C.11 amendments (in-house, applied below) — FP-3 `SubViewport` grep extension + FP-8 `create_tween` extension**: close grep loopholes. Required by Cluster J cases 1 + 4.

### NEW ADVISORY OQ emerging from §E

- **OQ-MENU-1 [ADVISORY]**: Verify `DisplayServer.window_set_dpi_changed` exists in Godot 4.6 (Cluster F case 3). If absent, accept cursor hotspot drift on multi-monitor DPI change as known defect.

## Dependencies

Menu System sits at the **Presentation layer** of the dependency graph. It depends on every Foundation autoload that runs before MainMenu.tscn loads (per ADR-0007 boot order) and on the four ADR contracts that govern UI architecture, save format, signal taxonomy, and autoload order. It is depended on by HUD Core (Day-1 MVP DEP for boot-warning scaffold), Settings & Accessibility (CR-18 / OQ-SA-3 Day-1 modal scaffold), Cutscenes & Mission Cards (mission-dossier asset reuse, VS), and Failure & Respawn (Pause Menu Re-Brief Operation entry, VS).

### F.1 Hard upstream dependencies

Menu cannot function without these contracts being in place. All listed are designed and locked unless flagged.

| System | Lock status | Contract Menu must respect |
|---|---|---|
| **Save / Load** ✅ | Approved | `slot_metadata(N) -> Dictionary` for save-card render (sidecar only — never opens `.res` per ADR-0003); `load_from_slot(N) -> SaveGame` for load; `save_to_slot(N, ...)` for save; subscribes `Events.save_failed` / `game_saved` / `game_loaded`. Save/Load CR-9/10/11/8/5. |
| **Level Streaming** ✅ | Approved | One of three caller-allowlist members for `transition_to_section(section_id, save_game, reason)` per LS CR-4. Calls with `NEW_GAME` (Main Menu New Game) or `LOAD_FROM_SAVE` (Main + Pause Load Game). Registers step-9 restore callback (LS L55). Fades menu music on `MAIN_MENU` bus BEFORE the LS NEW_GAME call (LS L201). |
| **Input** ✅ | Approved | Consumes `pause` (only fires in `Context.GAMEPLAY` per CR-3), `ui_up/down/left/right`, `ui_accept`, `ui_cancel`. Subscribes to `Input.joy_connection_changed` directly per Input GDD L156 (engine signal — not re-emitted through Events bus per ADR-0002 §IG3). |
| **Settings & Accessibility** ✅ | Approved (pending OQ-SA-3 closure by this GDD) | Synchronous read of `SettingsService._boot_warning_pending: bool` in `MainMenu._ready()` (Settings CR-18). Calls `SettingsService.open_panel()` from Settings entry-point button (CR-7). Calls `SettingsService.dismiss_warning()` on Continue button (modal scaffold). Subscribes to `Events.setting_changed` filtered for `category == "accessibility" && name == "reduced_motion_enabled"` per CR-23. |
| **Audio** ✅ | Approved | Triggers menu-music fade-out on `MAIN_MENU` bus before LS NEW_GAME call (CR-20). Audio-bus linear fade over `menu_music_fade_out_ms` (default 800 ms). Music continues uninterrupted from gameplay during Pause per Audio L378 (Menu does NOT duck/fade music on Pause open). |
| **Localization Scaffold** ✅ | Approved | All visible strings via `tr("menu.*")`. Static labels use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` per Localization L129. Save-card section names from `meta.*` keys resolved at menu-render time (Localization L133). `menu.*` key namespace registered in `translations/menu.csv` per Localization L129. Pseudolocale stress test must include all `menu.*` keys (per §E Cluster G case 3). |
| **ADR-0002** ✅ | Approved | Subscribes `save_failed`, `game_saved`, `game_loaded` (Save domain). Subscribes `setting_changed` (Settings domain — Variant payload exception). Emits NO domain signals at MVP and VS (CR-19 sole-publisher discipline = consumer-only). |
| **ADR-0003** ✅ | Approved | Reads sidecar metadata only via `slot_metadata()`. Never opens `.res` directly. Validates required keys per `is_valid_metadata(dict)` predicate (NEW BLOCKING coord — Save/Load GDD must define canonical key set per §E Cluster C case 3). |
| **ADR-0004** ⚠ | Proposed (2 verification gates OPEN) | Theme inheritance via `project_theme.tres` + per-surface child themes; FontRegistry static class for font getters; InputContext autoload push/pop with `_unhandled_input()` + `ui_cancel` modal-dismiss pattern (sidesteps 4.6 dual-focus split). **Gate 1 (`accessibility_*` property names)** + **Gate 2 (`base_theme` vs `fallback_theme`)** + **NEW: `Context.MODAL` and `Context.LOADING` enum additions** all BLOCKING. |
| **ADR-0007** ✅ | Approved | Menu System is NOT autoload — `MainMenu.tscn` is Project Settings → Application → Run → Main Scene; engine loads it directly on cold boot. Autoloads complete `_ready()` calls in slot order per ADR-0007 §Canonical Registration Table BEFORE MainMenu's `_ready()` fires per autoload ordering guarantee. SettingsService autoload slot is owned by ADR-0007 (currently slot 10 per the 2026-04-27 amendment — CLOSED; consult ADR-0007 for current canonical order). *(2026-04-28: stale "1→8" + "slot 8" references corrected per `/review-all-gdds` 2026-04-28 finding 2b-2.)* |

### F.2 Soft upstream dependencies

Enhanced by these but works without them.

| System | Lock status | Contract |
|---|---|---|
| **Post-Process Stack** ✅ | Approved | Optional `enable_sepia_dim()` API — **DECLINED** by Menu per §C.10. Pause Menu uses 52% Ink Black ColorRect overlay (NOT sepia tint) so Pause is visually distinct from Document Overlay (which uses sepia dim). Closes PPS OQ-PPS-2 in Menu's favour. |
| **Failure & Respawn** ⚠ | Approved (1 NEW BLOCKING coord for VS) | VS-only soft dep: Re-Brief Operation entry visibility gated on `FailureRespawn.has_checkpoint() -> bool`. **NEW BLOCKING coord — F&R GDD**: `has_checkpoint()` public query API does not currently exist; F&R GDD amendment required before VS sprint. Does NOT block MVP (Re-Brief Operation is VS-tier; MVP has no mid-section checkpoints). |

### F.3 Downstream forward dependents

Systems that depend on Menu System.

| System | Status | Contract Menu provides |
|---|---|---|
| **HUD Core** ✅ | Approved 2026-04-25 | **CLOSES HUD Core REV-2026-04-26 D2 HARD MVP DEP**: photosensitivity boot-warning modal scaffold ships Day-1, allowing HUD's damage-flash kill-switch UI to be exercised. Menu provides the scaffold node + boot-warning trigger via `_boot_warning_pending` poll in CR-8. |
| **Settings & Accessibility** ✅ | Approved 2026-04-26 | **CLOSES Settings OQ-SA-3 BLOCKING coord**: Menu polls `_boot_warning_pending` per CR-18; provides modal scaffold; provides Settings entry-point button on Main Menu and Pause Menu. Modal copy + dismissed-flag persistence remain Settings-owned per CR-18 boundary. |
| **Cutscenes & Mission Cards** | NOT YET DESIGNED | Mission-dossier card backdrop (CR-16) shares Art Bible §7D aesthetic and assets. CMC GDD #22 will need to consume Menu's mission-dossier card visual register or instantiate its own using the same asset list (§V seed). Coord item for CMC GDD authoring. |
| **Failure & Respawn** ✅ | Approved 2026-04-24 | Menu provides Pause Menu's Re-Brief Operation entry (CR-13, VS). F&R provides `restart_from_checkpoint()` and `has_checkpoint()` (NEW BLOCKING coord above). |
| **Level Streaming** ✅ | Approved | LS AC-LS-3.5 is `pending` until Menu System GDD reaches Approved status. **This GDD's approval unblocks AC-LS-3.5.** |

### F.4 ADR dependencies (full list)

| ADR | Status | Constraint Menu inherits |
|---|---|---|
| **ADR-0002** Signal Bus + Event Taxonomy | Accepted (with pending Settings amendment for `settings_loaded`) | Subscribes save-domain + settings-domain signals; emits zero domain signals at MVP/VS. |
| **ADR-0003** Save Format Contract | Accepted | Reads sidecar via `slot_metadata()`; never opens `.res`. |
| **ADR-0004** UI Framework | Proposed (Gate 1 + Gate 2 + Context.MODAL/LOADING amendments BLOCKING) | Theme + FontRegistry + InputContext + `_unhandled_input()` + `ui_cancel` modal-dismiss + AccessKit per-widget contract. |
| **ADR-0007** Autoload Load Order Registry | Accepted (SettingsService slot landed 2026-04-27 amendment — CLOSED) | Menu is NOT autoload; reads SettingsService at the slot defined by ADR-0007 §Canonical Registration Table synchronously. |
| **ADR-0008** Performance Budget Distribution | Accepted | Menu claims ZERO steady-state gameplay budget (F.6). Documented as "no named sub-slot reservation" comment on Slot 7. |

### F.5 Forbidden non-dependencies

Systems Menu must NOT touch.

| System | Reason | Pillar / ADR enforcement |
|---|---|---|
| **HUD Core** (HUD widgets, draw layer) | HUD is consumer-only of gameplay state; Menu does not render during gameplay. HUD is hidden when InputContext != GAMEPLAY per HUD CR-1. | Pillar 5 + HUD CR-1 |
| **Document Overlay UI** (#20) | Document Overlay has its own InputContext.DOCUMENT_OVERLAY and modal scaffold; Menu does not interact. | ADR-0004 + Document Overlay GDD |
| **Document Collection** (#15) | Document Collection writes to SaveGame; Menu reads via `slot_metadata` only (sidecar). No direct API consumption. | Indirect via SaveLoad |
| **Combat & Damage** (#11) | Combat is gameplay-layer; Menu is presentation. Combat does not touch Menu at any layer. | Layered architecture |
| **Stealth AI** (#10) | SAI is gameplay; Menu does not render during gameplay (HUD is hidden). | Layered architecture |
| **Player Character** (#8) | PC state restored via SaveGame, not Menu. PC does not touch Menu. | ADR-0003 separation |
| **Inventory & Gadgets** (#12) | Inventory state restored via SaveGame; not via Menu. | ADR-0003 separation |
| **Civilian AI** (#16) | CAI state ephemeral per section, not in SaveGame. CAI does not interact with Menu. | Layered architecture |
| **Footstep Component** (#?) | Audio-emit only system; no UI surface. | Layered architecture |
| **Outline Pipeline** (#4) | Outline is gameplay-rendering; Settings panel may interact via `get_resolution_scale()` — that is Settings's concern, NOT Menu's. | Layered architecture |
| **Mission & Level Scripting** (#13) | Menu does not call MLS directly. New Game flow calls LS, which fires `mission_started` after section load — MLS reacts there. | Indirect via LS signal taxonomy |

### F.6 Bidirectional consistency check

Each row's "Verified against" cell points at the upstream GDD's section that locks the contract. Verified 2026-04-26 PM during this GDD authoring; if any upstream section changes, Menu's row must be re-verified.

| Cross-GDD contract | Verified against | Status |
|---|---|---|
| Save/Load: `slot_metadata(N)`, `load_from_slot(N)`, `save_to_slot(N, ...)`, save-domain signals | Save/Load CR-9 / CR-10 / CR-11 / CR-8 / L106 / L153 | ✅ Verified |
| LS: `transition_to_section()` caller-allowlist, step-9 restore callback, music-fade-before-NEW_GAME, MainMenu.tscn cold-boot path | LS CR-4 / CR-7 / L55 / L201 / L320 | ✅ Verified |
| Input: action consumption + gamepad reconnect signal | Input GDD L105–L110 / L133 / L156 / L177 / L246 | ✅ Verified |
| Settings: `_boot_warning_pending` poll + modal scaffold contract + entry-point button + dismiss API | Settings CR-18 + OQ-SA-3 + entries-registry SettingsService row | ✅ Verified — **this GDD CLOSES OQ-SA-3** |
| Audio: `MAIN_MENU` bus, music-continues-during-pause invariant, fade-before-NEW_GAME | Audio L97 / L188 / L378 + LS L201 | ✅ Verified |
| Localization: `menu.*` keys, `auto_translate_mode = ALWAYS`, pseudolocale stress test | Localization L129 / L183 / L212 | ✅ Verified |
| HUD Core: photosensitivity boot-warning HARD MVP DEP closure | HUD Core REV-2026-04-26 D2 | ✅ Verified — **this GDD CLOSES HARD MVP DEP** |
| F&R: `has_checkpoint()` public query API + `restart_from_checkpoint()` for Re-Brief Operation | F&R GDD §F (currently does NOT specify these public APIs) | ⚠ **NEW BLOCKING coord for VS** |
| LS: `transition_failed` signal or return bool for failed-section-load recovery | LS GDD §C/§F (currently no failure path specified) | ⚠ **NEW BLOCKING coord** (per §E Cluster C case 1) |
| Save/Load: sidecar required-keys validation predicate | Save/Load GDD §C/§D (currently no canonical key set) | ⚠ **NEW BLOCKING coord** (per §E Cluster C case 3) |
| Save/Load: relative-time strings prohibited in sidecar metadata | Save/Load GDD §C/§D | ⚠ **NEW BLOCKING coord** (per §E Cluster J case 5) |
| Settings: `dismiss_warning()` returns bool | Settings GDD §C / API surface | ⚠ **NEW BLOCKING coord** (per §E Cluster A case 5) |
| ADR-0002: `settings_loaded` one-shot signal amendment | ADR-0002 + Settings OQ-SA-2 | ⚠ Inherited BLOCKING (Settings sprint) |
| ADR-0004: Gate 1 (`accessibility_*` property names) + Gate 2 (`base_theme` vs `fallback_theme`) | ADR-0004 §Verification Required | ⚠ Inherited BLOCKING (Settings + HUD Core sprint) |
| ADR-0004: `Context.MODAL` + `Context.LOADING` enum additions | ADR-0004 IG7 / Settings GDD modal scaffold spec / F&R revision item #4 | ⚠ **NEW BLOCKING coord** — bundles previously-separate Settings + F&R items into one ADR-0004 amendment |
| ADR-0007: SettingsService autoload slot amendment | ADR-0007 §Slots / Settings OQ-SA-1 | ✅ **CLOSED 2026-04-27** — SettingsService registered per ADR-0007 §Canonical Registration Table (current slot owned by ADR-0007). |
| Cutscenes & Mission Cards (#22) — mission-dossier asset reuse | CMC GDD not yet authored | ⚠ Forward coord item (when CMC is designed) |

### F.7 Consolidated coord items (BLOCKING + ADVISORY)

Pulled together from §C, §D, §E, §F. Numbered for tracking.

**BLOCKING for sprint** (12 items):

1. **ADR-0004 amendment**: add `Context.MODAL` + `Context.LOADING` enum values to `InputContextStack.Context`. Bundles 3 previously-separate items (Settings modal, Menu modal, F&R revision item #4) into one amendment.
2. **ADR-0004 Gate 1**: confirm Godot 4.6 `Control.accessibility_*` property names (`accessibility_role`, `accessibility_name`, `accessibility_live`, etc.) — 5-min editor inspection per godot-specialist Item 8. Inherited BLOCKING from Settings + HUD Core.
3. **ADR-0004 Gate 2**: confirm Theme inheritance property name (`base_theme` vs `fallback_theme`) — 2-min editor inspection. Inherited BLOCKING.
4. **ADR-0002 amendment**: add `settings_loaded` one-shot signal to taxonomy. Inherited from Settings OQ-SA-2.
5. ~~**ADR-0007 amendment**: register SettingsService at autoload slot #8. Inherited from Settings OQ-SA-1.~~ **CLOSED 2026-04-27** — landed in ADR-0007 amendment; SettingsService registered per ADR-0007 §Canonical Registration Table (slot owned by ADR-0007).
6. **F&R GDD amendment**: add public query API `has_checkpoint() -> bool` + `restart_from_checkpoint() -> void` (or return signature TBD). Required for VS Re-Brief Operation entry (CR-13).
7. **LS GDD amendment**: surface `transition_to_section()` failure via `transition_failed(reason)` signal OR return `bool`. Required for failed-section-load recovery (§E Cluster C case 1).
8. **Save/Load GDD amendment**: define canonical "required keys" set for sidecar validation. Menu needs deterministic `is_valid_metadata(dict) -> bool` predicate. Required by §E Cluster C case 3.
9. **Save/Load GDD amendment**: explicitly prohibit relative-time strings in sidecar metadata; all timestamps must be mission-time `{section} — {time} GMT` format only. Required by §E Cluster J case 5 (closes FP-4 / FP-5 bypass route).
10. **Settings GDD amendment**: `SettingsService.dismiss_warning()` returns `bool` indicating write success. Required for boot-warning disk-full detection per §E Cluster A case 5.
11. **§C.4 internal amendment APPLIED**: `ModalScaffold._pending_modal_content` depth-1 queue (already integrated into §C.4).
12. **CR-6 internal amendment APPLIED**: "Begin Operation" button `disabled = true` immediately on first press (already integrated into CR-6).

**ADVISORY** (5 items):

13. **PPS OQ-PPS-2 closure**: Pause Menu uses 52% Ink Black overlay (NOT sepia dim per Document Overlay). Coord item: PPS GDD should note this decision in its OQ-PPS-2 row.
14. **ADR-0004 IG7 layer-10 collision**: Settings panel + Cutscenes letterbox both at CanvasLayer 10. If they cannot be simultaneously active (Settings only from Pause/Menu, not during cutscenes), the collision is benign. ADR-0004 owner should annotate.
15. **PauseMenuController architecture choice**: stand-alone Node script per section vs `SectionRoot` base script (godot-specialist's Item 9 alternative). Level-streaming team coord.
16. **Localization L212 cap scope clarification**: 25-char cap applies to labels only or all visible strings? 4 body-copy strings exceed 25 chars; alts pre-emptively chosen — verify with Localization team.
17. **CMC GDD #22 forward coord**: when CMC is authored, mission-dossier asset reuse from Art Bible §7D + Menu §V seed. Cutscenes consumes Menu's mission-dossier card visual register or instantiates its own.

**RESOLVED OQ inherited from upstream GDDs** (3 items):

- ✅ Settings OQ-SA-3 (Menu System scaffold) — **CLOSED** by this GDD's CR-8 + §C.4 ModalScaffold spec.
- ✅ HUD Core REV-2026-04-26 D2 HARD MVP DEP (photosensitivity boot-warning UI) — **CLOSED** by this GDD's CR-8.
- ✅ PPS OQ-PPS-2 (sepia dim vs neutral dim for pause overlay) — **CLOSED in Menu's favour**: Pause uses 52% Ink Black ColorRect (NOT sepia tint).

## Tuning Knobs

Menu System has a small set of designer-tunable values (animation timings, fade durations, overlay alpha) and a much larger set of LOCKED layout constants (card dimensions, grid geometry, modal scaffold dimensions). LOCKED values are documented here for completeness so they cannot be silently changed during sprint without GDD amendment.

### G.1 Menu-owned animation timing knobs

All durations are designer-tunable within the safe range. Reduced-motion gate (F.3) clamps all to 0 ms when `accessibility.reduced_motion_enabled` is true.

| Knob | Default | Safe Range | Affects | Notes |
|---|---|---|---|---|
| `menu_music_fade_out_ms` | 800 ms | [200, 2000] | CR-6 / CR-20 menu-music fade before LS NEW_GAME call | Below 200 ms: audible click on transition. Above 2000 ms: player perceives delay. |
| `folder_slide_in_duration_ms` | 180 ms | [100, 300] | CR-4 Pause Menu mount; F.3 reduced-motion gated | Below 100 ms: paper-arrival lacks weight. Above 300 ms: feels slow. `TRANS_CUBIC EASE_OUT`. |
| `folder_slide_out_duration_ms` | 140 ms | [80, 250] | CR-4 Pause Menu unmount; F.3 gated | Faster than slide-in to reduce friction on resume. `TRANS_CUBIC EASE_IN`. |
| `stamp_slam_duration_ms` | 100 ms | [60, 200] | Destructive-confirm stamp animation; F.3 gated | 6 frames at 60 fps. Scale 0%→120%→100%. SFX synced to frame 1, not frame N. |
| `save_failed_header_band_slide_ms` | 80 ms | [40, 160] | DISPATCH NOT FILED stamp band slide-in; F.3 gated | Linear (no easing) — mechanical stamp motion. |
| `screen_shuffle_duration_ms` | 100 ms | [60, 200] | Sub-screen swap (Main Menu ↔ Operations Archive; Pause Menu ↔ File Dispatch); F.3 gated | Two concurrent translate+fade tweens. 20 px horizontal offset. |
| `quicksave_feedback_duration_s` | 1.4 s | [0.8, 3.0] | F.4 quicksave / quickload feedback card display | Includes 0.2 s linear fade-out at end. Below 0.8 s: too brief to read. Above 3.0 s: distracts from gameplay during patrol. |
| `quicksave_feedback_fade_window_s` | 0.2 s | LOCKED (not tunable) | F.4 final fade window | Perceptual minimum for graceful fade. |

### G.2 Menu-owned visual / layout constants (LOCKED)

These are LOCKED by Art Bible §7B/§7D + ADR-0004 + this GDD's §C/§D. Listed for traceability — any change requires GDD amendment.

| Constant | Value | Owner | Locked by |
|---|---|---|---|
| `save_card_width_px` | 360 | art-director | Art Bible §7D + Menu §C.5 + F.1 |
| `save_card_height_px` | 96 | art-director | Art Bible §7D + Menu §C.5 + F.1 |
| `save_card_gap_h_px` | 6 | art-director | F.1 grid geometry |
| `save_card_gap_v_px` | 6 | art-director | F.1 grid geometry |
| `manila_folder_width_px` | 760 | art-director | Art Bible §7D + Menu §C.4 (grown from 520→760 to fit Load grid 726 px + 17 px side margins; resolved in design-review 2026-04-27) |
| `manila_folder_height_px` | 720 | art-director | Art Bible §7D + Menu §C.4 (grown from 680→720 to fit Load grid 402 px + tab + body margins) |
| `photosensitivity_modal_width_px` | 480 | art-director | Settings CR-18 + Menu §C.4 + F.2 |
| `photosensitivity_modal_height_px` | 280 | art-director | F.2 (5 lines × 11 px + header + buttons + margins) |
| `save_failed_modal_width_px` | 400 | art-director | Menu §C.4 |
| `save_failed_modal_height_px` | 200 | art-director | Menu §C.4 |
| `quit_confirm_modal_width_px` | 400 | art-director | Menu §C.4 (same family as save-failed) |
| `quit_confirm_modal_height_px` | 200 | art-director | Menu §C.4 |
| `body_lines_available` | 5 | systems-designer | F.2 (locked at 460 × 164 px body area) |
| `body_min_font_size_px` | 10 | systems-designer | F.2 fallback floor |
| `body_default_font_size_px` | 11 | systems-designer | F.2 default |
| `card_focus_border_width_px` | 2 | art-director | Per art-director §C visual restraint |
| `desk_overlay_alpha` | 0.52 | art-director | §C.4 ModalScaffold backdrop + Pause Menu overlay (52% Ink Black `#1A1A1A`) |
| `mouse_cursor_hotspot_x` | 30 | art-director | Fountain-pen-nib sprite hotspot top-right (nib tip on 32×32 sprite — pixel column 30 of 0-indexed 32 px width). Corrected in design-review 2026-04-27; previous (0,0) value was a top-left hotspot inconsistent with the "top-right nib tip" art spec. |
| `mouse_cursor_hotspot_y` | 0 | art-director | (top row of the 32 px sprite — nib tip Y) |

### G.3 Menu-owned overlay + scaffold knobs

Settings affecting the modal scaffold and its content presentation.

| Knob | Default | Safe Range | Affects | Notes |
|---|---|---|---|---|
| `modal_scaffold_canvas_layer` | 20 | LOCKED (per godot-specialist) | ModalScaffold render layer | Above Settings 10, Cutscenes 10, Subtitles 15; below LS fade 127. |
| `pause_menu_canvas_layer` | 8 | LOCKED (per ADR-0004 IG7) | PauseMenu render layer | ADR-0004 IG7 assigned. Cannot collide with HUD 1 / Settings 10 / Subtitles 15 / fade 127. |
| `body_chars_locale_ceiling` | 300 | LOCKED (per Settings GDD) | F.2 photosensitivity body fit | Per Settings: 38 English words + ~150% locale expansion = 300 chars at 11 px. >345 chars at 10 px requires locale GDD amendment. |
| `auto_translate_mode_default` | `ALWAYS` | LOCKED | All static menu Labels | Per Localization L129 + ADR-0004. |

### G.4 Forward-dep settings consumed (Settings-owned, NOT Menu-owned)

Menu reads these but does NOT own them. Listed for traceability of cross-system contracts.

| Setting | Owner | Default | Used by Menu in |
|---|---|---|---|
| `accessibility.reduced_motion_enabled` | Settings & Accessibility GDD §C | `false` | F.3 reduced-motion gate (CR-23) — gates all menu animations |
| `accessibility.photosensitivity_warning_dismissed` | Settings & Accessibility GDD §C (locked) | (absent on first launch) | CR-8 boot-warning poll trigger |
| `language.locale` | Localization Scaffold GDD | `"en"` | CR-22 `accessibility_name` re-resolve + F.8 (fires `NOTIFICATION_TRANSLATION_CHANGED` when changed) |
| `accessibility.crosshair_enabled` | Settings GDD (Combat-locked default) | `true` | NOT consumed by Menu — Menu does not render the gameplay crosshair (HUD does). Listed for completeness — Menu does not touch this setting. |
| `audio.master_volume_db` | Audio + Settings GDDs | `0.0 dB` | Indirectly: Audio bus already applies the master volume to the `MAIN_MENU` bus. Menu's fade-out is on top of Audio's master gain. |

### G.5 Ownership matrix

| Knob category | Owner GDD | Read by | Write by |
|---|---|---|---|
| Animation timings (G.1) | **Menu System (this GDD)** | Menu animation tweens | Menu `_play_*` methods |
| Visual / layout constants (G.2) | **Art Bible + Menu System** (LOCKED) | Menu scenes + Art assets | Art revision (GDD amendment required) |
| Overlay + scaffold layer indices (G.3) | **Menu System** (LOCKED per ADR-0004 IG7 / godot-specialist) | Menu scenes (CanvasLayer.layer assignment) | ADR-0004 amendment required |
| Body fit constants (F.2) | **systems-designer + Localization** (LOCKED per F.2) | F.2 predicate | F.2 + Localization GDD amendment |
| `accessibility.reduced_motion_enabled` | **Settings & Accessibility** | Menu F.3 gate | Settings panel (player toggle) |
| `accessibility.photosensitivity_warning_dismissed` | **Settings & Accessibility** | Menu CR-8 poll | Settings on Continue button + `[Show Photosensitivity Notice]` button |
| `language.locale` | **Localization Scaffold** | Menu CR-22 + F.8 re-resolve | Settings panel (player switch) |

### G.6 Pillar 5 absolutes (NOT tunable, even by GDD amendment)

These are Pillar-5-anchored design decisions. Changing them is not a tuning knob — it is a fundamental design re-litigation requiring CD ratification.

| Absolute | Locked by |
|---|---|
| No save thumbnails / screenshots | Player Fantasy Refusal 3 + FP-3 |
| No real-world wall-clock timestamps | Player Fantasy Refusal 4 + FP-4/FP-5 |
| No translucent gameplay-buffer overlay (only 52% Ink Black ColorRect ABOVE the viewport) | Player Fantasy Refusal 1 + FP-1 |
| No "Are you sure?" / "Quit to Main Menu" / "New Game!" verbiage | Player Fantasy Refusal 2 + FP-2/FP-6/FP-7 |
| No animations other than paper-movement + stamp-slam | Player Fantasy Refusal 5 + FP-8 |
| Manila folder + carbon-copy + period stamp visual register | Art Bible §7D + Player Fantasy "The Case File" |
| Bureaucratic-neutral language (Save Dispatch / Resume Surveillance / Close File) | Player Fantasy "The Case File" register + locked English strings §C.8 |
| Menu System emits zero ADR-0002 domain signals (consumer-only) | CR-19 sole-publisher discipline |
| Menu System is NOT autoload (MainMenu.tscn = boot scene; Pause = CanvasLayer overlay) | ADR-0007 + LS CR-7 + CR-1 |

## Visual/Audio Requirements

### Visual Requirements (V.1 – V.9)

#### V.1 Manila folder + page surfaces (Pause Menu container)

| Element | Spec |
|---|---|
| Folder body color | `#C19A4B` (period-accurate buff manila — between raw Kraft and bleached cream; warmer/darker than Parchment `#F2E8C8` so paper inside the folder reads as separate object) |
| Folder texture | Flat solid fill + paper-fibre noise overlay at 8% opacity (monochrome, ≤ 4 px tile, seamless) |
| Folder dimensions | 760 × 720 px at 1080p; bottom-right slide-in (lower-center-right quadrant), NOT full-center. Width grown from 520→760 in design-review 2026-04-27 to accommodate Load grid 726 px footprint + 17 px side margins. |
| Folder geometry | Visible portion ~760 × 720 px; offset so the upper-left of the screen (Eiffel Tower ironwork) remains visible behind the 52% overlay |
| Tab background | PHANTOM Red `#C8102E` rectangle, 4 px hard edge (no rounding) |
| Tab text | American Typewriter 11 px, Parchment `#F2E8C8`, content: `STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65` |
| Tab dimensions | ~140 × 28 px; offset 2/3 across folder width from the left edge |
| Page texture (typed bond) | Parchment `#F2E8C8` base + paper-fibre noise at 5% opacity + 1 px Ink Black `#1A1A1A` ruled border |
| Carbon-copy effect | Text rendered twice: original Ink Black `#1A1A1A` 100% opacity + carbon impression at 65% opacity gray `#2D2D2D` offset 2 px down + 1 px right (single set of text nodes; effect baked into card background asset OR shader pass on text layer — implementation detail delegated to technical-artist) |
| Desk surround (Pause overlay) | Solid `#1A1A1A` ColorRect at **52% alpha** above the gameplay viewport. **NOT a blur**, **NOT a translucent compositing layer on the gameplay buffer** (FP-1). |

#### V.2 Save card visual specifications

| Element | Spec |
|---|---|
| Card dimensions | 360 × 96 px at 1080p baseline; 10 px internal margins all sides |
| Card top line | `DISPATCH 03` (or equivalent slot label) in DIN 1451 Engschrift 11 px, Ink Black `#1A1A1A`, left-aligned |
| Card second line | Section name + in-mission time in American Typewriter 10 px, Ink Black, left-aligned. Format: `TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` |
| Card third line | 1 px ruled line at 70% opacity (period typed forms had ruled dividers between header and body) |
| Card body area | 3 horizontal ruled lines at 1 px, 40% opacity, evenly spaced (suggests typed lines of classified content that are redacted/blank) |
| Card stamp area | Bottom-right rectangular area 40 × 18 px |
| OCCUPIED stamp | `FILED` in DIN 1451 8 px Ink Black at 45% opacity |
| EMPTY stamp + body | `VACANT` 8 px Ink Black at 25% opacity; header reads `DISPATCH — [UNASSIGNED]` in Parchment receding; card 30% dimmer Parchment via `modulate` |
| CORRUPT stamp + body | `CORRUPTED — DO NOT FILE` in PHANTOM Red `#C8102E` 9 px DIN 1451 (or `DOSSIER CORROMPU` localized); cooler off-white background `#E8E0D0` (distinguishable from Parchment by luminance + hue shift); 3 body ruled lines have 2 px horizontal tear-mark mid-line (mask asset, not particle) |
| AUTOSAVE (slot 0 only, Load grid) | Header reads `DISPATCH AUTO — [section_name] — [time_gmt]`; stamp `AUTO-FILED` BQA Blue `#1B3A6B` at 45% opacity; 1 px BQA Blue left-border 2 px wide |

#### V.3 Save / Load grid layouts

**Layout per CR-11 + CR-12 + F.1 (user-approved 2×N grid):**

- **Load Game (8 slots):** GridContainer `columns = 2`, 4 rows. Slot 0 in `(col=0, row=0)`. Slots 1–7 fill row-first left-to-right, top-to-bottom. Footprint: 2×360 + 6 = 726 px × 4×96 + 18 = 402 px.
- **Save Game (7 slots, Pause-only):** GridContainer `columns = 2`, 4 rows. Slots 1–6 in cells `(0,0)` through `(1,2)`. Slot 7 alone in cell `(0,3)`. Cell `(1,3)` is absent (no Control). Footprint: 2×360 + 6 = 726 px × 3×96 + 12 + 96 = 396 px.
- **Inter-card gap:** 6 px H × 6 px V.
- **Slot 0 differentiation (Load grid only):** AUTOSAVE state per V.2; positioned top-left; not segregated from slots 1–7 by separator/divider — only by stamp + border-accent.

#### V.4 Photosensitivity boot-warning modal scaffold (Day-1 MVP)

| Element | Spec |
|---|---|
| Card dimensions | 480 × 280 px at 1080p, **centered** (the only Menu surface where centered is appropriate — appears at front of the file before main folder opens) |
| Header band | BQA Blue `#1B3A6B`, full card width, 32 px tall; text `OPERATIONAL ADVISORY — BQA/65` in DIN 1451 11 px Parchment `#F2E8C8`, centered vertically |
| Body area | 460 × 164 px after header + button area; American Typewriter 11 px Ink Black; auto-wrap; line count ≤ 5 per F.2 |
| Body fallback | If locale exceeds 300 chars at 11 px → drop to 10 px (≤ 345 chars per F.2). If still overflows → locale GDD amendment required (F.2 third decision branch). Card does NOT scroll; does NOT stretch. |
| Continue button | 160 × 32 px, BQA Blue `#1B3A6B` fill, Parchment `#F2E8C8` text, DIN 1451 12 px; default focus; 2 px Parchment outer border (focus indicator) |
| Go to Settings button | 160 × 32 px, Ink Black `#1A1A1A` fill, Parchment text (visually receding vs Continue) |
| Button gap | 16 px horizontal between buttons, horizontally centered, 16 px from card bottom |

#### V.5 Save-failed dialog (DISPATCH NOT FILED) visual

| Element | Spec |
|---|---|
| Card dimensions | 400 × 200 px, centered, 52% Ink Black overlay backdrop |
| Header band | PHANTOM Red `#C8102E`, 28 px tall full width; text `DISPATCH NOT FILED` in DIN 1451 12 px Parchment, left-aligned with 10 px left margin |
| Body | Two lines American Typewriter 10 px Ink Black: line 1 = error reason (localized); line 2 = blank |
| Divider | 1 px ruled line below body |
| Retry button | 140 × 28 px, PHANTOM Red `#C8102E` fill, Parchment text (attention color, NOT destructive); default focus; 2 px Parchment focus border |
| Cancel/Abandon button | 140 × 28 px, BQA Blue `#1B3A6B` fill, Parchment text |
| BQA seal | NOT present on this card — rejection slips are bureaucratic rejections, not sealed intelligence |

#### V.6 Quit-Confirm / Return-to-Registry / Re-Brief / New-Game-Overwrite modal family

Same family as save-failed (400 × 200 px); distinct header band color:

| Modal | Header band color | Header text | Default focus button |
|---|---|---|---|
| Quit-Confirm | Ink Black `#1A1A1A` | `CLOSE FILE — CONFIRM` | "Continue Mission" (Cancel, BQA Blue fill) |
| Return-to-Registry | Ink Black `#1A1A1A` | `RETURN TO REGISTRY` | "Continue Mission" (Cancel) |
| Re-Brief Operation | Ink Black `#1A1A1A` | `RE-BRIEF OPERATION` | "Continue Mission" (Cancel) |
| New-Game-Overwrite | PHANTOM Red `#C8102E` | `OPEN NEW OPERATION` | "Cancel" (BQA Blue) |

VU PAR stamp asset (Ink Black 42% opacity) appears in the body's bottom-left corner of the Quit-Confirm dialog only (signed-off-document register).

#### V.7 Animation choreography

| Animation | Curve / Duration | Direction | Audio sync |
|---|---|---|---|
| Folder slide-in (Pause open) | 180 ms `TRANS_CUBIC EASE_OUT` | Bottom-right of screen translating upward | Drawer-slide audio paired to tween START (sound precedes visual completion intentionally — you hear the drawer before paper fully lands) |
| Folder slide-out (Pause close) | 140 ms `TRANS_CUBIC EASE_IN` | Reverse — folder translates back down off-screen | Faster than slide-in to reduce friction on resume |
| Desk overlay fade | Simultaneous with folder slide-in/out, 180 / 140 ms linear | Opacity 0→0.52 / 0.52→0 | (n/a) |
| Stamp slam-down (destructive confirm) | 100 ms (6 frames @ 60 fps) | Scale 0%→120%→100%; frames 1–4 descent, frames 5–6 settle | Rubber-stamp thud audio fires on **frame 1** (the instant the stamp begins moving — this is the "thud" moment in the physical-object model, NOT when it lands) |
| Save-failed header band slide-in | 80 ms linear | PHANTOM Red header band slides in from top of card downward | (no dedicated audio cue — Audio's save-failed sting covers it) |
| Screen-shuffle paper transition | 100 ms two concurrent tweens | Outgoing translates 20 px left + fades to 0% opacity; incoming translates from 20 px right of rest position to rest, opacity 100% | Paper-shuffle audio fires at tween start |

**No crossfades. No Material Design slides. No spring overshoot.** Pillar 5 Refusal 5 is absolute: animation curves are mechanical, not eased. (Cubic ease-in/out is permitted because it reads as paper landing on a surface — it has physical weight, unlike spring physics.)

#### V.8 Asset list seed

Naming convention: `[category]_[name]_[variant]_[size].[ext]`. Run `/asset-spec` after this GDD is approved + Art Bible §7D is finalized.

**Folder + paper:**
- `ui_folder_manila_base_large.png` — 760 × 760 px (interior 760 × 720 + 40 px tab overhang at top), Kraft buff `#C19A4B` + paper-fibre noise baked. Regenerated in design-review 2026-04-27 from prior 520 × 720 spec.
- `ui_folder_tab_eyes_only_normal.png` — 140 × 28 px, PHANTOM Red band + typed label
- `ui_page_bond_base_large.png` — 480 × 640 px, Parchment `#F2E8C8` + ruled border
- `ui_page_carbon_copy_overlay_large.png` — 480 × 640 px, Ink Black 35% offset overlay (tileable)

**Stamps:**
- `ui_stamp_eyes_only_band_normal.png` — 460 × 20 px PHANTOM Red `EYES ONLY` band
- `ui_stamp_confidentiel_normal.png` — 180 × 48 px BQA Blue 38% opacity diagonal
- `ui_stamp_vu_par_normal.png` — 80 × 32 px Ink Black 42% rectangular w/ underline
- `ui_stamp_filed_normal.png` — 56 × 18 px Ink Black `FILED`
- `ui_stamp_vacant_normal.png` — 64 × 18 px Ink Black 25% `VACANT`
- `ui_stamp_corrupted_normal.png` — 160 × 20 px PHANTOM Red `CORRUPTED — DO NOT FILE` w/ tear effect
- `ui_stamp_dispatch_not_filed_normal.png` — 240 × 20 px PHANTOM Red `DISPATCH NOT FILED`
- `ui_stamp_close_file_normal.png` — 220 × 20 px Ink Black `CLOSE FILE — CONFIRM`
- `ui_stamp_auto_filed_normal.png` — 80 × 18 px BQA Blue 45% `AUTO-FILED`

**BQA seal:**
- `ui_seal_bqa_watermark_small.png` — 64 × 64 px BQA Blue `#1B3A6B` single-color, transparent bg, intended for 20% opacity compositing

**Cursor:**
- `ui_cursor_fountain_pen_nib_normal.png` — 32 × 32 px Parchment on transparent, hotspot top-right (nib tip)

**Save cards:**
- `ui_card_save_occupied_normal.png` — 360 × 96 px OCCUPIED state shell
- `ui_card_save_empty_normal.png` — 360 × 96 px EMPTY state shell (dimmed Parchment)
- `ui_card_save_corrupt_normal.png` — 360 × 96 px CORRUPT state shell w/ tear-marks

**Modal scaffolds:**
- `ui_card_advisory_operational_normal.png` — 480 × 280 px Operational Advisory shell w/ BQA Blue header band

**Button chrome:** No dedicated textures — `StyleBoxFlat` with hard 0 px corners + 2 px Parchment focus border via theme override.

**Overlay:** `ColorRect` at 52% alpha — no texture asset needed if Godot ColorRect handles it.

> **📌 Asset Spec** — Visual/Audio requirements are defined. After Art Bible §7D is approved, run `/asset-spec system:menu-system` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

#### V.9 Pillar 5 visual restraint compliance check (10 items)

These positive prohibitions are encoded in the GDD to prevent future drift:

1. **No corner radius > 0 px on any interactive element** (Art Bible §3.3 hard-edged rectangles). FP-10.
2. **No drop shadows / soft glows on any element at any state** including hover/focus/active. Art Bible §3.3. Focus = 2 px Parchment hard border only. FP-11.
3. **No gradient fills anywhere.** Flat solid colors from the locked palette only. Paper-fibre noise textures are noise, not gradients — they pass. FP-11.
4. **No animation other than paper-movement translation + destructive-action stamp scale.** No color-cycling, pulse-on-hover, breathing on BQA seal, parallax. FP-8.
5. **No neon accent colors / colors outside the locked palette in any interactive state.** Locked: BQA Blue, Parchment, Alarm Orange, PHANTOM Red, Ink Black, manila-buff (folder only). Hover/pressed/focus/disabled use opacity shifts + border changes within existing palette.
6. **No screen-fill color other than 52% Ink Black desk overlay.** Overlay color locked.
7. **No photographic textures on interactive elements.** Paper-fibre noise (≤ 4 px grain monochrome) is permitted on folder + pages. Photographic imagery is permitted only on the gameplay frame-buffer behind the overlay. Buttons / cards / modals = stylized flat-color fills + ruled lines only.
8. **No type sizes below 10 px for visible strings.** 10 px (American Typewriter) / 9 px (DIN 1451 Engschrift) floor. Below = legibility collapse at 1080p with comic-book outline post-process active.
9. **No animated transitions between game screens (52% overlay is compositing layer, not a fade-to-black).** The LS fade overlay lives at `CanvasLayer.layer = 127` (level-streaming.md CR-1; signed 8-bit `CanvasLayer.layer` ceiling per Godot 4.x — `128` overflows) and is exclusive to LS section transitions; using it for menu-open/close is the wrong tool. (B5 from /review-all-gdds 2026-04-27 closed 2026-04-27 — earlier draft cited the impossible value `1024`; corrected to the canonical 127 per LS CR-1.)
10. **No UI element that would not have a physical-world referent in 1965 BQA tradecraft.** Operational encoding of the Player Fantasy test. Progress bars, health indicators, loading spinners, notification badges, unread-count chips, achievement popups — all forbidden.

---

### Audio Requirements (A.1 – A.6)

#### A.1 Audio cue inventory

All cues are on the **UI bus** exclusively. UI bus is exempt from the 16-slot SFX pool stealing rule (Audio L367 — voice and UI exempt) and from VO ducking (Audio Rule 7 — UI bus is not ducked). All menu foley therefore survives any VO line or music transition without volume interference.

Format: `sfx_ui_menu_[name]_[variant].wav` for one-shots (< 500 ms); 48 kHz / 16-bit; normalized to −14 LUFS.

| # | Cue | Trigger | Duration | Sonic register | Variants |
|---|---|---|---|---|---|
| **A1** | Confirm (typewriter clack) | Any non-destructive button activation across all surfaces | 60–80 ms | Olivetti Lettera 32 single-key strike, hard mechanical contact, dry stop, fundamental ~1.5–3 kHz + 200 Hz body knock. NOT modern keyboard. | 3 (`_01..03`) + ±5% pitch random |
| **A2** | Pause open (drawer slide-in) | `PauseMenuController` mounts `PauseMenu.tscn`, 180 ms folder slide-in starts | 170–190 ms (matched to tween) | 1960s agency furniture wooden drawer + brass rail. Friction scrape (~20 ms) → smooth slide (~130 ms) → soft landing stop (~30 ms). Wood resonance 120–300 Hz + brass-rail ring 2–4 kHz. **Stop transient is loudest moment** | 1 |
| **A3** | Pause close (drawer slide-out) | PauseMenu `queue_free` begins, 140 ms slide-out starts | 130–150 ms | Same drawer reversed; push-close has less initial friction; close cue quieter overall than open (player attention returning to gameplay) | 1 |
| **A4** | Save / Load grid navigation | Focus change between save cards via arrow / D-pad | 30–40 ms | Single index card drawn across stack of similar cards. Dry paper-on-paper, upper-mid 3–5 kHz transient, minimal body. **8–10 dB below confirm cue** (subliminal texture, not event punctuation) | 2 (`_01`, `_02`) |
| **A5** | In-card overwrite-confirm enter | Save card transitions to `CONFIRM_PENDING` | 50–70 ms | Single index card turned face-up — light snap of card landing flat. Slightly crisper than navigation; registers as "something changed" without alarm | 1 |
| **A6** | Destructive confirm (rubber-stamp thud) | Quit Confirm "Close File" + New-Game-Overwrite + Re-Brief + Return-to-Registry confirm + Save-Failed "Abandon" | 90–110 ms (matched to 100 ms stamp animation) | Rubber ink-pad stamp on paper. Downstroke air (~10 ms) → hard contact (~20 ms) → adhesion + paper flex (~30 ms) → lift-off + slight ink-stick (~20 ms). Rubbery-wet 150–400 Hz + paper-flex 2–4 kHz. **Loudest UI cue — destructive actions feel heavier than navigation.** Triggered at START of animation (impact transient lands within first 30 ms = first 2 frames stamp face meeting paper) | 2 (`_01`, `_02`) |
| **A7** | Screen-transition paper shuffle | Sub-screen swap (Main Menu ↔ Operations Archive) | 90–110 ms (matched to 100 ms transition animation) | Stack of intelligence photographs/documents advanced in carousel — slide-projector advance: mechanical clunk (~20 ms) + brief slide (~50 ms) + arrival-click (~15 ms). Paper-on-paper body 800 Hz–2 kHz + clunk 200–500 Hz. NOT same as A4 (single card) — this is whole stack moving | 2 (`_01`, `_02`) |
| **A8** | Modal appearance (non-save-failed) | `ModalScaffold.show_modal()` for Quit-Confirm / Return-to-Registry / Re-Brief / New-Game-Overwrite | 50–70 ms | Single sheet of heavy paper dropped flat on desk — air-displacement whoosh (~10 ms) + flat impact (~15 ms) + brief resonance (~20 ms). Low-mid thud 200–600 Hz + paper transient 3–5 kHz. **Softer than stamp; heavier than navigation** — confirms a decision point has arrived | 1 |

**Cues that DO NOT exist:**

- **Photosensitivity boot-warning modal**: NO audio cue on appearance. A warning about photosensitivity must not accompany a sudden transient. Silence is the correct register.
- **Quicksave / Quickload feedback card appearance**: NO additional Menu-owned cue. Audio's `game_saved` chime (~200 ms soft tock, SFX bus) already fires on the `Events.game_saved` signal in parallel; both reactions are to the same signal. Card and chime coexist without collision.
- **Save-failed modal appearance**: NO Menu-owned cue. Audio owns the descending-minor-two-note sting (~400 ms, SFX bus) on `Events.save_failed` per Audio L181. Menu shows the dialog only.
- **Save-failed header band 80 ms slide-in**: NO dedicated cue (the Audio sting covers the dialog appearance auditorily).
- **Save grid CONFIRM (slot save-confirm via in-card `[CONFIRM]`)**: A1 typewriter clack covers it — the save action is non-destructive (writing to an existing slot is a save, not a destruction).
- **Save grid CANCEL (in-card `[CANCEL]`)**: A1 typewriter clack covers it.
- **Pause Menu mount / unmount**: A2 / A3 only — no music change (see A.4 below).

#### A.2 Bus routing

All Menu-owned cues route to the **UI bus**, never SFX, Voice, Music, or Ambient. Audio-owned cues that fire on Menu-relevant signals (save-failed sting, game_saved chime) route to the **SFX bus** per Audio GDD §C — these are gameplay-event stings, not UI foley. The two buses coexist without collision.

#### A.3 Menu music handoff to LS (CR-20)

Menu music fade-out before LS NEW_GAME call delegates to AudioManager — Menu does NOT manipulate `MusicNonDiegetic.volume_db` directly (AFP-5 absolute):

```gdscript
await AudioManager.begin_main_menu_fade_out(menu_music_fade_out_ms / 1000.0)
```

`AudioManager.begin_main_menu_fade_out(duration_s: float) -> Signal` is owned by Audio. It implements the `volume_db` tween (Audio Rule 6 — `TRANS_LINEAR` on `volume_db` is perceptually linear because Godot's `volume_db` is already logarithmic; **do NOT** apply linear curves to amplitude 0.0–1.0 and convert — that produces a "falls off a cliff" fade) and returns the `fade_complete` signal. Menu awaits this signal before calling LS.

**AFP-5 fix applied 2026-04-27**: prior `create_tween().tween_property(music_player, "volume_db", ...)` example contradicted AFP-5 (which prohibits Menu setting `MusicNonDiegetic.volume_db` directly). The implementation of the tween lives in AudioManager; Menu calls a named method and awaits its signal.

Default duration `menu_music_fade_out_ms = 800 ms` (tuning knob §G.1). The `await` in CR-6 ensures LS is not called until AudioManager's `fade_complete` signal fires — consistent with Audio Rule 6 + LS L201.

**[ADVISORY coord — Audio GDD]**: register `AudioManager.begin_main_menu_fade_out(duration_s: float) -> Signal` as a public API.

#### A.4 No-audio-on-pause-open invariant

The `MAIN_MENU` bus state (Audio L97) is specifically the boot-menu music state and applies only when AudioManager is in the `MAIN_MENU` state. **During in-game Pause, AudioManager is in `[section]_calm` or `[section]_alert`** — the section track continues uninterrupted per Audio L378. The Pause Menu mounting event fires no signal that AudioManager subscribes to. `PauseMenuController` is Menu-domain; it pushes `Context.PAUSE` and mounts the folder overlay, neither of which touches AudioManager.

The drawer-slide cue A2 sits on the UI bus and is audibly additive over the ongoing section track. This is intentional — the player hears the section's calm jazz continue while the folder slides into frame.

#### A.5 Reduced-motion audio rule

**Audio cues are NOT tied to `accessibility.reduced_motion_enabled`.** When reduced-motion is true, the visual animation is suppressed (folder appears instantly, stamp materializes, etc.) but the audio cue STILL plays at its full duration. Rationale: the cue is the tactile confirmation that the action was taken; it is not part of the animation. Suppressing audio cues under reduced-motion would remove the only remaining confirmation feedback for players who also have reduced hearing or who are not watching the screen.

Implementation: Menu code MUST fire the audio cue unconditionally in its `_activate_button()` / `_play_modal_appear()` / etc. paths, NOT inside the `if not accessibility.reduced_motion_enabled` branch that gates the visual tween.

#### A.6 Audio-side forbidden patterns

**AFP-1 — No music state change, duck, fade, or pause on Pause Menu open or close.** Pause is a dispatcher consulting the file; the operation continues. Any `AudioManager` call, Music bus volume change, or fade tween triggered by Pause open/close is a violation. The only audio event on Pause open is A2 drawer-slide on UI bus.

**AFP-2 — No looping ambient SFX during menus.** Menu surfaces do not own or play any looping layer on the Ambient bus. If a section's ambient loop is audible during Pause (because section scene persists behind folder), that is Audio's domain responding to `section_entered` — Menu does not start, stop, or modify it.

**AFP-3 — No UI foley cue with significant frequency content above 6 kHz.** Period-authentic register is typewriter / paper / brass-rail furniture / rubber stamp — predominantly low-mid and mid energy (60 Hz–4 kHz). High-frequency content above 6 kHz (sparkle, modern click-clack, digital transients) breaks 1965 register and clashes with Goldsmith/Mancini score register. Apply gentle high-shelf rolloff above 5 kHz if foley source has modern bright energy.

**AFP-4 — No UI foley cue on the Voice bus.** Voice bus is exclusively VO playback per Audio Rule 9. By extension, no non-VO audio routes to Voice. Menu foley is UI bus only. A cue accidentally routed to Voice would be subject to VO ducking and would incorrectly suppress music during menu interactions.

**AFP-5 — No additional audio on the `MAIN_MENU` bus state from Menu code.** The `MAIN_MENU` music state (Audio L97) is AudioManager's domain. Menu triggers a fade-out via the CR-6 tween on `MusicNonDiegetic.volume_db`; AudioManager implements the actual fade. Menu must NEVER set `MusicNonDiegetic.volume_db` directly, NEVER call `AudioStreamPlayer.stop()` on music players, NEVER attempt to set the `MAIN_MENU` bus state on AudioManager's behalf.

#### A.7 NEW Audio GDD coord item

**Audio GDD §Visual/Audio amendment — register UI foley (non-signal-driven) sources:**

The 8 cue families A1–A8 are not currently registered in the Audio GDD's SFX catalog (Audio §V SFX event catalog, L491–523). The catalog lists every SFX keyed by subscribed signal. Menu foley cues are NOT signal-driven — they are triggered directly by Menu node scripts in response to UI events. They will never appear in Audio GDD's signal-subscription table. However, they should be registered in a new subsection of the Audio GDD titled "UI foley sources (non-signal-driven)":

| Cue | Trigger | Bus | File convention |
|---|---|---|---|
| A1 confirm | Button activation | UI | `sfx_ui_menu_confirm_[01-03].wav` |
| A2 pause open | PauseMenu mount | UI | `sfx_ui_menu_pause_open_01.wav` |
| A3 pause close | PauseMenu queue_free | UI | `sfx_ui_menu_pause_close_01.wav` |
| A4 grid nav | Card focus change | UI | `sfx_ui_menu_nav_[01-02].wav` |
| A5 card flip | In-card confirm enter | UI | `sfx_ui_menu_card_flip_01.wav` |
| A6 stamp | Destructive confirm | UI | `sfx_ui_menu_stamp_[01-02].wav` |
| A7 transition | Sub-screen swap | UI | `sfx_ui_menu_transition_[01-02].wav` |
| A8 modal open | Non-save-failed modal | UI | `sfx_ui_menu_modal_open_01.wav` |

**Coord status: ADVISORY** — not blocking for Menu GDD authoring. Menu GDD references these cue names + UI bus routing; Audio GDD amendment registers them in the catalog for sound-designer delegation.

## UI Requirements

### UI-1 Boundaries

Menu System is the project's primary **player-facing chrome layer**. UI Framework architecture is fully delegated to ADR-0004 (Theme + InputContext + FontRegistry); this GDD adds nothing to ADR-0004's scope. Menu's UI requirements are:

- **Owned UI surfaces (per §C.2 Owned Surfaces table):** Main Menu, Pause Menu, Operations Archive (Load Game grid), File Dispatch (Save Game grid), Photosensitivity boot-warning modal scaffold, Save-failed dialog, Quit-Confirm modal, Return-to-Registry modal, Re-Brief Operation modal, New-Game-overwrite modal, Quicksave / Quickload feedback card, Settings entry-point button.
- **NOT owned:** Settings panel internals (Settings & Accessibility GDD #23 owns its HSplitContainer at CanvasLayer 10); HUD widgets (HUD Core #16); Document Overlay (#20); Cutscenes (#22); the Main Menu music asset (Audio); the photosensitivity modal copy + dismissed-flag persistence (Settings).
- **All UI surfaces inherit `project_theme.tres`** via per-surface child Themes (ADR-0004 §1, pending Gate 2 verification).
- **All static labels use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`** (Localization L129) for locale switch; localized `accessibility_name` re-resolves via `_notification(NOTIFICATION_TRANSLATION_CHANGED)` per CR-22 + F.8.

### UI-2 Accessibility floor (Day-1 + Polish)

Per ADR-0004 IG10 the AccessKit per-widget contract is Day-1 mandate, NOT deferred to Polish. The §C.9 AccessKit per-widget table is the authoritative spec. Compliance level:

| Compliance area | Day-1 MVP | Polish (VS / post-VS) |
|---|---|---|
| AccessKit role + name on every Menu Control with non-trivial label | ✅ Required (§C.9 table) | (already at Day-1 floor) |
| AccessKit `accessibility_description` on Settings entry-point | ✅ Required (CR-7) | (already at Day-1 floor) |
| AccessKit `accessibility_live = "assertive"` one-shot pattern on modal appearance | ✅ Required (CR-21 + F.7) | (already at Day-1 floor) |
| `accessibility_name` re-resolve on locale change | ✅ Required as plumbing (CR-22) | English-only at MVP; FR + DE at VS via VS locale switcher |
| Keyboard-only navigation 100% reachable | ✅ Required for boot-warning + Settings entry-point + Main Menu | All surfaces VS |
| Modal focus trap | ✅ Required for boot-warning + Quit-Confirm modals (Day-1 surfaces) | All modals VS |
| Reduced-motion conditional branch in animation code | ✅ Required as plumbing (CR-23) — branch present, setting reads false at MVP | Setting consumption goes live at VS |
| Color-and-shape differentiation for save card states | n/a (save grid is VS) | ✅ Required at VS (CR-25 + WCAG SC 1.4.1) |
| Custom mouse cursor restoration on `NOTIFICATION_APPLICATION_FOCUS_IN` | ✅ Required (CR-17 + §E Cluster F) | (already at Day-1 floor) |

### UI-3 UX-spec authoring (delegate to `/ux-design`)

This GDD specifies the **structural behavior** of every Menu surface. The **per-screen UX details** (precise focus order beyond what §C specifies, specific label positions within the modal scaffold, focus-ring visual treatment, hover states, exact pixel layouts) belong in dedicated UX specs authored via `/ux-design` in Phase 4 (Pre-Production). Stories that reference UX should cite `design/ux/[screen].md`, NOT this GDD directly.

**UX specs to author (in priority order — Day-1 MVP first):**

1. `design/ux/photosensitivity-boot-warning.md` — Day-1 MVP, **HARD-blocking HUD Core + Settings sprints**. Modal scaffold layout, Continue / Go to Settings button placement, AccessKit announce timing. **AUTHORED 2026-04-29 — APPROVED.**
2. `design/ux/main-menu.md` — Day-1 MVP minimum slice. Continue / Begin Operation / Personnel File / Close File button stack; quit-confirm modal scaffold.
3. `design/ux/quit-confirm.md` — Day-1 MVP. Modal scaffold pattern shared by Return-to-Registry, Re-Brief, New-Game-Overwrite.
4. `design/ux/pause-menu.md` — VS. Folder slide-in geometry, button stack, Re-Brief Operation conditional visibility.
5. `design/ux/load-game-screen.md` — VS. 8-slot 2×4 grid; slot 0 visual differentiation; arrow-key navigation; AccessKit grid role.
6. `design/ux/save-game-screen.md` — VS. 7-slot 2×3+1 grid; in-card overwrite-confirm flow.
7. `design/ux/save-failed-dialog.md` — VS. PHANTOM Red header band; Retry / Abandon buttons; assertive announce.
8. `design/ux/quicksave-feedback-card.md` — VS. Bottom-right ephemeral card; 1.4 s + 200 ms fade; non-modal.

> **📌 UX Flag — Menu System**: This system has 8 distinct UX surfaces. In Phase 4 (Pre-Production), run `/ux-design` to create per-screen UX specs **before** writing epics / stories. Stories that reference UI should cite `design/ux/[screen].md`, not this GDD.
>
> Recommended priority: author boot-warning + Main Menu + Quit-Confirm UX specs FIRST (Day-1 MVP HARD-blocking deps); the remaining VS specs follow in the order listed above. The Save/Load UX flag in Save/Load GDD §Visual/Audio (L249) already calls for `design/ux/load-game-screen.md`, `design/ux/save-game-screen.md`, `design/ux/save-failed-dialog.md` — those three are co-owned with Save/Load.

## Acceptance Criteria

61 ACs across 20 groups. Format: **GIVEN** [initial state], **WHEN** [action/trigger], **THEN** [measurable outcome]. Each AC tagged with story type ([Logic] / [Integration] / [UI] / [Visual] / [Config]) and gate level ([BLOCKING] = build-gating; [ADVISORY] = lead-reviewed). Test file paths are proposed (do not exist on disk yet — programmer creates during implementation).

### H.1 Boot Lifecycle

- **AC-MENU-1.1 [Logic] [BLOCKING]** GIVEN the engine has completed all autoload `_ready()` calls in the slot order defined by ADR-0007 §Canonical Registration Table (currently 10 autoloads — Events, EventLogger, SaveLoad, InputContext, LevelStreamingService, PostProcessStack, Combat, FailureRespawn, MissionLevelScripting, SettingsService — but the AC asserts on the count and order owned by ADR-0007, NOT on the literal value), WHEN the engine loads `MainMenu.tscn` as the Project Settings main scene and `MainMenu._ready()` runs, THEN `InputContextStack.peek()` returns `Context.MENU` within the same frame, no `change_scene_to_file()` call is made to load `MainMenu.tscn` itself, and no autoload node named `MainMenu` exists in the scene tree. Verifies CR-1, CR-18. *(2026-04-28: AC rewritten per `/review-all-gdds` 2026-04-28 finding 2f-1 — prior wording asserted "8 autoload _ready calls" which conflicted with ADR-0007 Gate 1's current 10-autoload assertion.)*
- **AC-MENU-1.2 [Logic] [BLOCKING]** GIVEN `SettingsService._boot_warning_pending == false`, WHEN `MainMenu._ready()` completes, THEN no `ModalScaffold` modal is open, `peek() == Context.MENU`, and all Main Menu buttons have `process_input = true` within the same `_ready()` frame. Verifies CR-8 Branch B, C.3 step 5.
- **AC-MENU-1.3 [Logic] [BLOCKING]** GIVEN `_boot_warning_pending == true`, WHEN `MainMenu._ready()` runs, THEN: (a) the Main Menu button container has `process_input = false` BEFORE `show_modal()` is called; (b) `peek() == Context.MODAL` after `show_modal()` returns; (c) the photosensitivity modal's root node is visible. Both (a) and (b) occur within `_ready()` — no `await` between them. Verifies CR-8 Branch A.
- **AC-MENU-1.4 [Integration] [BLOCKING]** GIVEN a `MainMenu.tscn` scene instantiated in a test harness with the `ModalScaffold` child node removed (deliberate authoring-error fixture), WHEN the scene is loaded with a custom error handler intercepting `assert()` failures (registered before instantiation; prevents engine exit), THEN the intercepted error message contains the literal string `"ModalScaffold child required in MainMenu.tscn"` and no null-dereference occurs before the message is captured. Implementation note: this test requires a GUT test-extension or a standalone headless runner that hooks `assert()` failure callbacks — not vanilla GUT. (Rewritten 2026-04-27 per qa-lead — original wording assumed vanilla-GUT crash assertion which is not testable.) Verifies §E Cluster A case 4.
- **AC-MENU-1.5 [Integration] [BLOCKING]** GIVEN cold boot on a machine where `user://settings.cfg` is absent, WHEN the game launches for the first time, THEN `_boot_warning_pending` evaluates to `true`, the photosensitivity modal appears before any Main Menu button is interactive, and the `Begin Operation` label is visible in the Continue button position (slot 0 absent). Verifies CR-8, CR-5 empty-slot case.

### H.2 Pause Menu Lifecycle

- **AC-MENU-2.1 [Logic] [BLOCKING]** GIVEN `peek() == Context.GAMEPLAY`, WHEN the `pause` action fires, THEN `PauseMenuController` calls `add_child(PauseMenu.tscn instance)` on `get_tree().current_scene`, `peek()` becomes `Context.PAUSE`, `get_tree().paused` remains `false`, and the gameplay section scene root remains visible in the scene tree. Verifies CR-3, CR-4.
- **AC-MENU-2.2 [Logic] [BLOCKING]** GIVEN PauseMenu is mounted and `peek() == Context.PAUSE`, WHEN `Resume Surveillance` is activated OR `ui_cancel` fires at PauseMenu top level, THEN `PauseMenu.tscn` instance is `queue_free()`-d, `peek()` returns to `Context.GAMEPLAY`, and no `change_scene_to_file()` call is made. Verifies CR-4 unmount path.
- **AC-MENU-2.3 [Logic] [BLOCKING]** GIVEN `peek() == Context.MENU` (Main Menu open), WHEN the `pause` action fires, THEN `PauseMenuController._unhandled_input()` reads `peek() != GAMEPLAY` via CR-3 guard, silently consumes the input, and no PauseMenu node is added to the scene tree. Verifies CR-3 negative gate.
- **AC-MENU-2.4 [Integration] [BLOCKING]** GIVEN PauseMenu mounted over an active gameplay section with music playing, WHEN the Pause Menu is open, THEN the section's ambient music continues playing without interruption or volume change during the entire Pause Menu lifetime. Verifies CR-4 "music continues", §C.10 Audio row.
- **AC-MENU-2.5 [Visual] [ADVISORY]** GIVEN PauseMenu mounted over a live gameplay scene, WHEN a screenshot is taken with the Pause Menu open, THEN: (a) the gameplay framebuffer is visible behind the desk overlay (not hidden or blacked out); (b) a 52% Ink Black `#1A1A1A` `ColorRect` overlay is present between gameplay and the menu card; (c) the gameplay scene shows no `modulate.a` change on its CanvasLayer. Evidence: `production/qa/evidence/pause-overlay-visual-[date].png` + art-director sign-off. Verifies CR-4, FP-1, `desk_overlay_alpha = 0.52`.

### H.3 Continue Button Label-Swap

- **AC-MENU-3.1 [Logic] [BLOCKING]** GIVEN `SaveLoad.slot_metadata(0)` returns a non-null, non-empty Dictionary, WHEN `MainMenu._ready()` resolves the Continue button, THEN `button.text == tr("menu.main.continue")` and the rendered English string is exactly `"Resume Surveillance"` (19 chars, no trailing whitespace, no `!`). Verifies CR-5 occupied path.
- **AC-MENU-3.2 [Logic] [BLOCKING]** GIVEN `slot_metadata(0)` returns `null` OR an empty Dictionary, WHEN `MainMenu._ready()` resolves the Continue button, THEN `button.text == tr("menu.main.continue_empty")` and the rendered English string is exactly `"Begin Operation"`, AND the button's enabled state is `true`. Verifies CR-5 empty path.
- **AC-MENU-3.3 [Logic] [BLOCKING]** GIVEN `slot_metadata(0)` returns a Dictionary with `state == SaveLoad.SlotState.CORRUPT`, WHEN `MainMenu._ready()` resolves the Continue button, THEN the button label displays `"Begin Operation"` (falls through to empty/corrupt path), the button is enabled, and no "file damaged" announcement fires on the Continue button (that announcement belongs to the Load grid's slot 0 card only). Verifies CR-5 corrupt-slot fallback.

### H.4 New Game Flow

- **AC-MENU-4.1 [Logic] [BLOCKING]** GIVEN `slot_metadata(0)` returns non-null Dictionary AND slots 1–7 are all empty, WHEN the New Game button is activated, THEN `ModalScaffold.show_modal(NewGameOverwriteContent)` is called, the modal title resolves to `"OPEN NEW OPERATION"`, default focus is on Cancel, and `peek() == Context.MODAL`. Verifies CR-6 conditional confirm path.
- **AC-MENU-4.2 [Logic] [BLOCKING]** GIVEN `slot_metadata(0)` returns non-null AND at least one of slots 1–7 is non-empty, WHEN New Game is activated, THEN no modal opens and execution proceeds directly to the music-fade + LS path. Verifies CR-6 decision: confirm only when slot 0 is the player's only progress.
- **AC-MENU-4.3 [Logic] [BLOCKING]** GIVEN the New Game confirm modal is open and the player confirms, WHEN the confirm action fires, THEN: (a) `button.disabled = true` on first press (BEFORE music fade starts); (b) `LS.transition_to_section()` is NOT called until music fade has completed (`await`); (c) `push(Context.LOADING)` is called immediately before `transition_to_section()`. Verifies CR-6 disable + music-fade invariant + LOADING push.
- **AC-MENU-4.4 [Logic] [BLOCKING]** GIVEN New Game button has been pressed once and `disabled == true`, WHEN a second activation reaches the button, THEN no second music-fade coroutine spawns and `transition_to_section()` is called exactly once. Verifies CR-6 re-entrant prevention; §E Cluster H case 3.

### H.5 Settings Entry-Point

- **AC-MENU-5.1 [Integration] [BLOCKING]** GIVEN Main Menu is open and `peek() == Context.MENU`, WHEN the Personnel File button is activated, THEN `SettingsService.open_panel()` is called exactly once, `peek() == Context.SETTINGS` (pushed by Settings, NOT Menu), and Main Menu buttons remain visible but do not receive focus. Verifies CR-7.
- **AC-MENU-5.2 [Integration] [BLOCKING]** GIVEN Settings panel open (`Context.SETTINGS`), WHEN the player dismisses Settings via its own dismiss path, THEN `peek()` returns to `Context.MENU` (or `Context.PAUSE` if entered from Pause), and focus returns to the Personnel File button in the originating surface. Verifies CR-7 focus-restore.
- **AC-MENU-5.3 [UI] [ADVISORY]** GIVEN the Personnel File button is inspected at runtime via AccessKit, WHEN `accessibility_description` is read, THEN it equals `tr("menu.main.settings.desc")` → "*Adjust audio, graphics, accessibility, and control settings.*" (60 chars). Manual walkthrough: focus button with screen reader; AT must announce the description. Verifies CR-7.

### H.6 Photosensitivity Boot-Warning

- **AC-MENU-6.1 [Logic] [BLOCKING]** GIVEN `_boot_warning_pending == true`, WHEN `ModalScaffold.show_modal(PhotosensitivityWarningContent)` is called, THEN `peek() == Context.MODAL` and the modal root has `accessibility_role == "dialog"` (per GATE-F7-A property name). Verifies CR-8.
- **AC-MENU-6.2 [Logic] [BLOCKING]** GIVEN photosensitivity modal is visible and `peek() == Context.MODAL`, WHEN `ui_cancel` fires, THEN the event is consumed and the modal remains open — `hide_modal()` is NOT called. Verifies CR-8 non-dismissible-by-ui_cancel.
- **AC-MENU-6.3 [Logic] [BLOCKING]** [REVISED 2026-04-29 per `design/ux/photosensitivity-boot-warning.md` OQ #8 — button label canonicalised to "Continue" per Settings GDD CR-18 authoritative source] GIVEN photosensitivity modal is open, WHEN Continue is activated, THEN in order: (a) `SettingsService.dismiss_warning()` is called and returns `true`; (b) `ModalScaffold.hide_modal()` is called; (c) `peek() == Context.MENU`; (d) focus moves to Continue / Begin Operation per CR-5; (e) Main Menu button container has `process_input = true`. All five within one frame. Verifies CR-8 Continue path.
- **AC-MENU-6.4 [Logic] [BLOCKING]** [REVISED 2026-04-29 per OQ #8] GIVEN `dismiss_warning()` returns `false` (disk-full failure), WHEN Continue is pressed, THEN modal remains open, `peek() == Context.MODAL`, button container retains `process_input = false`, and a second Continue press re-attempts `dismiss_warning()`. Verifies §E Cluster A case 5.
- **AC-MENU-6.5 [UI] [ADVISORY]** [REVISED 2026-04-29 per OQ #8] GIVEN photosensitivity modal is open with screen reader active, WHEN the modal appears (assertive one-shot per F.7), THEN the AT announces the modal's content. Default focus = Continue. Go to Settings button has `accessibility_description`. Manual walkthrough doc filed. Verifies CR-8, C.9.

### H.6-locale (NEW per QA-lead GAP-3)

- **AC-MENU-6.6 [Logic] [BLOCKING — before any non-EN locale ships]** [REVISED 2026-04-29 per `/ux-design photosensitivity-boot-warning` OQ #7 + `/ux-design quit-confirm` OQ #1] GIVEN a localised body string for the photosensitivity warning, WHEN `Label.get_line_count()` is called after rendering at the project's locked menu UI body floor (18 px per `accessibility-requirements.md`) with `autowrap_mode` set, THEN the result is ≤ 5 lines. **Font scale-down is rejected** (the prior `11 px / 10 px / locale-amendment` rule was found to conflict with `accessibility-requirements.md` minimum text size 18 px for Mission Card body — see `design/ux/photosensitivity-boot-warning.md` Section H + OQ #7 for the conflict analysis). **If a locale's body exceeds 5 lines at 18 px in the modal width**, the modal height grows from the 280 px (photosensitivity) / 200 px (Case File modals) baseline up to ~340 px / ~260 px respectively to accommodate 5–6 lines without font shrinkage. **If a locale's body exceeds 6 lines even at the maximum modal height**, the locale is flagged as GDD amendment required before shipping (CI check fails the locale bundle). Verifies F.2 with the revised rule. Same rule applies to all 4 Case File register modals (Quit-Confirm, Return-to-Registry, Re-Brief, New-Game-Overwrite) per `design/ux/quit-confirm.md` [CANONICAL] inheritance.

### H.7 Quit-Confirm

- **AC-MENU-7.1 [Logic] [BLOCKING]** GIVEN Main Menu is open and `peek() == Context.MENU`, WHEN Close File is activated, THEN `ModalScaffold.show_modal(QuitConfirmContent)` is called, `peek() == Context.MODAL`, default focus is on Continue Mission (Cancel) — NOT Close File. Verifies CR-9 default-Cancel focus.
- **AC-MENU-7.2 [Logic] [BLOCKING]** GIVEN Quit-Confirm modal open, WHEN Continue Mission is activated OR `ui_cancel` fires, THEN `hide_modal()` is called, `peek() == Context.MENU`, and focus returns to Close File button. `get_tree().quit()` is NOT called. Verifies CR-9 cancel path.
- **AC-MENU-7.3 [Logic] [BLOCKING]** GIVEN Quit-Confirm modal open, WHEN Close File (destructive) is activated, THEN `pop()` removes `Context.MENU` and `get_tree().quit()` is called. No save triggered. Verifies CR-9 confirm path.

### H.8 Save-Failed Dialog

- **AC-MENU-8.1 [Logic] [BLOCKING]** GIVEN MainMenu (or PauseMenu) is mounted and subscribed to `Events.save_failed` in `_ready()`, WHEN `_exit_tree()` fires, THEN `Events.save_failed.is_connected(...)` returns `false` — subscription disconnected, `is_connected()` guard used (no double-disconnect error). Verifies CR-10 subscription lifecycle.
- **AC-MENU-8.2 [Logic] [BLOCKING]** GIVEN PauseMenu active and no modal open, WHEN `Events.save_failed` fires, THEN `show_modal(SaveFailedContent)` is called, modal header resolves to "DISPATCH NOT FILED", default focus = Retry, `peek() == Context.MODAL`, and underlying PauseMenu buttons remain visible without disabling `process_input`. Verifies CR-10 non-blocking modal.
- **AC-MENU-8.3 [Logic] [BLOCKING]** GIVEN a Quit-Confirm modal is already open (`_is_modal_active == true`), WHEN `Events.save_failed` fires in the same frame, THEN `_pending_modal_content` is set to `SaveFailedContent` (most-recent-wins), the active Quit-Confirm is NOT forcibly closed, and when Quit-Confirm dismisses (Cancel), `show_modal(SaveFailedContent)` fires immediately. Queue depth never exceeds 1. Verifies C.4 depth-1 queue; §E Cluster B case 4.
- **AC-MENU-8.4 [Logic] [BLOCKING]** GIVEN Save-Failed modal open and Retry activated, WHEN the retry save call fires, THEN `SaveLoad.save_to_slot(N)` is called for the same slot N that originally triggered `save_failed` (most-recent target tracked). Verifies CR-10 Retry path.

### H.9 Save / Load Grid

- **AC-MENU-9.1 [Logic] [BLOCKING]** GIVEN Load Game grid rendered, WHEN GridContainer is inspected, THEN `columns == 2`, exactly 8 child Controls, slot 0 at `(col=0, row=0)` per F.1, slot 7 at `(col=1, row=3)`, GridContainer has `h_separation = 6` + `v_separation = 6`. Verifies CR-11, F.1.
- **AC-MENU-9.2 [Logic] [BLOCKING]** GIVEN Save Game grid rendered, WHEN GridContainer is inspected, THEN `columns == 2`, exactly 7 child Controls (slot 7 alone in `(col=0, row=3)`), cell `(col=1, row=3)` contains no focusable Control (GridContainer has 7 children, not 8, per F.1 occupancy predicate `(row < 3) OR (row == 3 AND col == 0)`), slot 0 NOT present. Verifies CR-12, F.1.
- **AC-MENU-9.3 [Logic] [BLOCKING]** GIVEN Save grid with slot 3 in OCCUPIED state, WHEN player activates slot 3 (first press), THEN card transitions to `CONFIRM_PENDING` inline (no ModalScaffold opens, `peek()` remains `Context.PAUSE`), card text changes to "*Overwrite Dispatch?*", focus moves to `[CANCEL]` inside card. Verifies CR-12, F.5 first step.
- **AC-MENU-9.4 [Logic] [BLOCKING]** GIVEN Save grid with slot 3 in CONFIRM_PENDING, WHEN `ui_cancel` fires (first press), THEN card returns to NORMAL OCCUPIED, grid remains open, `should_close_save_grid_on_ui_cancel` evaluates `false` per F.5. WHEN second `ui_cancel` press (no card in CONFIRM_PENDING), THEN grid closes and focus returns to File Dispatch button. Verifies F.5 two-press exit, C.5 step 6.
- **AC-MENU-9.5 [Logic] [BLOCKING]** GIVEN Load Game grid rendered with slot 0 in AUTOSAVE state, WHEN slot 0 card is inspected, THEN: (a) 2 px BQA Blue left-border accent; (b) header text resolves to AUTO-FILED stamp; (c) `disabled == false`. WHEN slot 0 in CORRUPT state, THEN `disabled == true` and `accessibility_name` contains "*File damaged.*" Verifies CR-11 slot 0 differentiation, C.5 states.
- **AC-MENU-9.6 [Logic] [BLOCKING]** GIVEN Save Game grid rendered, WHEN an EMPTY slot is activated, THEN `SaveLoad.save_to_slot(N)` is called immediately — no overwrite-confirm appears. WHEN a CORRUPT slot is inspected, THEN `disabled == true` and activation produces no effect. Verifies CR-12.

### H.10 InputContext Push/Pop Discipline

- **AC-MENU-10.1 [Logic] [BLOCKING]** GIVEN `peek() != Context.GAMEPLAY` (boot default invariant violated), WHEN `MainMenu._ready()` pushes `Context.MENU`, THEN the push is preceded by `assert(peek() == Context.GAMEPLAY)` per C.7 — assertion fires, surfacing the ordering violation as immediate crash. Verifies C.7 assertion guard.
- **AC-MENU-10.2 [Logic] [BLOCKING]** GIVEN `peek() != Context.MENU` and `peek() != Context.PAUSE`, WHEN `ModalScaffold.show_modal()` is called, THEN `assert(peek() in [MENU, PAUSE])` fires — preventing modal mount in non-menu context (e.g., during LOADING). Verifies C.7.
- **AC-MENU-10.3 [Logic] [BLOCKING]** GIVEN New Game flow proceeds past music fade, WHEN `LS.transition_to_section()` is about to be called, THEN `push(Context.LOADING)` has already been called — `peek() == Context.LOADING` at the moment `transition_to_section()` is called. Verifies C.7 LOADING push.
- **AC-MENU-10.4 [Logic] [BLOCKING]** GIVEN `MainMenu._exit_tree()` fires due to LS scene change, WHEN exit-tree handler runs, THEN `pop(Context.MENU)` is called if `Context.MENU` still on stack, with `assert(peek() in [MENU, LOADING])` before the pop. Verifies C.7 `_exit_tree()` pop.

### H.11 Esc-Key Discipline

- **AC-MENU-11.1 [Logic] [BLOCKING]** GIVEN `peek() == Context.MENU` and no modal/sub-screen open (Main Menu top level), WHEN `ui_cancel` fires, THEN no action is taken — no quit-confirm opens, no visible UI change. Verifies C.6 "MainMenu top level — Nothing".
- **AC-MENU-11.2 [Logic] [BLOCKING]** GIVEN `peek() == Context.PAUSE` and PauseMenu top level shown, WHEN `ui_cancel` fires, THEN PauseMenu is dismissed identically to activating Resume Surveillance: `queue_free()`, pop `PAUSE`, `peek() == GAMEPLAY`. Verifies C.6 "PauseMenu top level — Resumes game".
- **AC-MENU-11.3 [Logic] [BLOCKING]** GIVEN `peek() == Context.LOADING`, WHEN any input including `ui_cancel` fires, THEN no `_unhandled_input` handler in Menu System processes the event — dead-input state. No Pause Menu mounts, no modal opens. Verifies C.6 LOADING-blocked, §E Cluster B case 3.

### H.12 ModalScaffold Contract

- **AC-MENU-12.1 [Logic] [BLOCKING]** GIVEN `show_modal(ContentA)` was called and `_is_modal_active == true`, WHEN `show_modal(ContentB)` is called before `ContentA` is dismissed, THEN `_pending_modal_content` is set to `ContentB` (most-recent-wins), `ContentA` remains visible, no second modal layer is pushed, `InputContextStack` remains at depth +1 (only one `Context.MODAL` on stack). Verifies C.4 depth-1 queue.
- **AC-MENU-12.2 [Logic] [BLOCKING]** GIVEN modal is open and `hide_modal()` is called, WHEN `_pending_modal_content != null`, THEN `show_modal(_pending_modal_content)` is called immediately after the previous modal closes, `_pending_modal_content` is cleared, the new modal's content receives `call_deferred("grab_focus")` to its default focus target. Verifies C.4 queue drain.
- **AC-MENU-12.3 [Logic] [BLOCKING]** GIVEN modal is open and `return_focus_node` was provided, WHEN `hide_modal()` is called and `_pending_modal_content == null`, THEN `return_focus_node.call_deferred("grab_focus")` is called. WHEN `is_instance_valid(return_focus_node) == false`, THEN no crash; fallback silently skips `grab_focus()`. Verifies C.4 focus-restore + `is_instance_valid` fallback.
- **AC-MENU-12.4 [Logic] [BLOCKING]** GIVEN a modal with two focusable buttons (`[CANCEL]` first, `[CONFIRM]` last), WHEN Tab is pressed from `[CONFIRM]`, THEN focus wraps to `[CANCEL]` — does NOT escape to underlying menu. WHEN Shift+Tab from `[CANCEL]`, THEN focus wraps to `[CONFIRM]`. Verifies CR-24 focus trap.

### H.13 AccessKit Semantics

- **AC-MENU-13.1 [Logic] [BLOCKING]** GIVEN `show_modal()` is called, WHEN the test inspects `accessibility_live` and `visible` synchronously immediately after `show_modal()` returns and again after a one-frame yield (`await get_tree().process_frame`), THEN: (a) immediately after `show_modal()` returns and BEFORE the frame yield: `accessibility_live == "assertive"` AND `visible == true`; (b) AFTER the one-frame yield: `accessibility_live == "off"` AND `visible == true`. Set-ordering inside `show_modal()` verified via a property-assignment-order spy injected into `ModalScaffold` for testing (records the sequence of set() calls). The "no frame exists" universal-negative formulation is removed in favor of these positive observations. (Rewritten 2026-04-27 per qa-lead — universal-negative properties are not unit-testable.) Verifies F.7, CR-21 one-shot.
- **AC-MENU-13.2 [Logic] [BLOCKING]** GIVEN a Control in a Menu scene with localised `accessibility_name`, WHEN `_ready()` fires, THEN `_update_accessibility_names()` is called and `accessibility_name == tr(ACCESSIBILITY_NAME_KEY)` in active locale. WHEN `NOTIFICATION_TRANSLATION_CHANGED` fires, THEN `_update_accessibility_names()` is called again and `accessibility_name` updates. Verifies F.8, CR-22.
- **AC-MENU-13.3 [Logic] [BLOCKING]** GIVEN a CORRUPT save card (`slot_state(N) == SlotState.CORRUPT`) in the Load grid, WHEN the card's `accessibility_name` is read, THEN it contains the slot index and the substring "*File damaged.*" (from `tr("menu.save_card.corrupt.name", {slot})` → "*Dispatch N. File damaged. Cannot load.*"). Steady-state `accessibility_live == "off"`. Verifies C.9 CORRUPT card.
- **AC-MENU-13.4 [Logic] [BLOCKING]** GIVEN a Settings button in MainMenu or PauseMenu, WHEN `accessibility_description` is read, THEN it equals `tr("menu.main.settings.desc")` both at `_ready()` AND after `NOTIFICATION_TRANSLATION_CHANGED`. Verifies CR-7 + CR-22 (the `accessibility_description` field is NOT covered by `auto_translate_mode` any more than `accessibility_name` is).

### H.14 Locked English Strings

- **AC-MENU-14.1 [Config] [ADVISORY]** GIVEN `translations/menu.csv` on disk, WHEN every English value in `menu.main.*` / `menu.pause.*` / `menu.save_failed.*` / `menu.quit_confirm.*` / `menu.return_registry.*` / `menu.rebrief.*` / `menu.new_game_confirm.*` / `menu.quicksave.*` / `menu.quickload.*` / `menu.photo_warning.*` is inspected, THEN every value matches §C.8 string table exactly. Smoke check: diff `translations/menu.csv` against §C.8 before sprint review.
- **AC-MENU-14.2 [Config] [ADVISORY]** GIVEN `translations/menu.csv`, WHEN English value column searched for `"Quit to"`, `"Main Menu"` (standalone), `"Desktop"`, `"Game"` (case-insensitive), `"Play"`, `"New Game"`, THEN zero matches. Verifies FP-2.
- **AC-MENU-14.3 [Config] [ADVISORY]** GIVEN `translations/menu.csv`, WHEN value column searched for `"!"`, THEN zero matches. Verifies FP-7.
- **AC-MENU-14.4 [Config] [ADVISORY]** GIVEN `translations/menu.csv`, WHEN value column searched for `"minutes ago"`, `"hours ago"`, `"recently"`, `"just"`, `"last played"`, `"left off"`, THEN zero matches. Verifies FP-5.

### H.15 Forbidden Patterns CI Grep Gates

CI shell script at `tools/ci/check_menu_forbidden_patterns.sh`. Each AC names the exact grep command. Each must return zero matches (or zero outside an allowlist) to pass.

- **AC-MENU-15.1 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "modulate\.a" src/ui/menu/` executes, THEN zero matches. Verifies FP-1.
- **AC-MENU-15.2 [Config] [ADVISORY]** GIVEN CI run targeting `translations/menu.csv` value column, WHEN `grep -in "\"Quit to\|\"Game\"\|\"Play\"\|\"New Game"` executes, THEN zero matches. Verifies FP-2 (tr-key names containing `_game_` are excluded — lint English values only).
- **AC-MENU-15.3 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "Texture2D\|SubViewport\|screen_get_image\|get_texture().get_image" src/ui/menu/` executes, THEN zero matches. Verifies FP-3.
- **AC-MENU-15.4 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "Time\.get_datetime_dict_from_system\|Time\.get_unix_time_from_system" src/ui/menu/` executes, THEN zero matches. Verifies FP-4.
- **AC-MENU-15.5 [Config] [ADVISORY]** GIVEN CI run targeting `translations/menu.csv`, WHEN `grep -in "minutes ago\|hours ago\|recently\|just\|last played\|left off" translations/menu.csv` executes, THEN zero matches. Verifies FP-5.
- **AC-MENU-15.6 [Config] [ADVISORY]** GIVEN CI run targeting `translations/menu.csv`, WHEN `grep -in "are you sure\|do you want to\|permanently\|cannot be undone" translations/menu.csv` executes, THEN zero matches. Verifies FP-6.
- **AC-MENU-15.7 [Config] [ADVISORY]** GIVEN CI run targeting `translations/menu.csv`, WHEN `grep -n "!" translations/menu.csv` executes against value column, THEN zero matches. Verifies FP-7.
- **AC-MENU-15.8 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "create_tween\|Tween\.new\|AnimationPlayer\.play" src/ui/menu/` executes, THEN any match in a file whose name does NOT match the pattern `^_play_[a-z_]+\.gd$` (animation-helper files identified by the `_play_` prefix naming convention) causes the check to fail (exit non-zero). Files matching the `_play_` prefix are allowlisted automatically — no maintenance to the allowlist when new helpers are added, provided they follow the naming convention. (Rewritten 2026-04-27 per qa-lead — pattern-based allowlist replaces hardcoded filename list.) Verifies FP-8.
- **AC-MENU-15.9 [Logic] [BLOCKING — pending tooling]** GIVEN a `.tscn` scene-tree parser exists at `tools/ci/scene_tree_lint.py` and is committed, WHEN the parser scans `.tscn` files under `src/ui/menu/` for `Label` nodes lacking a `theme_override_fonts/font` property, THEN zero such Label nodes exist. **Tooling pre-req: `tools/ci/scene_tree_lint.py` does not yet exist on disk** — must be built before this AC can run. While tooling is absent, this AC remains BLOCKING but un-runnable; gating it on the tooling-build sprint task. (Status note added 2026-04-27 per qa-lead.) Verifies FP-9.
- **AC-MENU-15.10 [Logic] [BLOCKING]** GIVEN CI run scanning `.tres` and `.tscn` resources under `src/ui/menu/`, WHEN `grep -rn "corner_radius" src/ui/menu/` executes and matched `StyleBoxFlat.corner_radius_*` values are extracted, THEN every value is 0. Verifies FP-10.
- **AC-MENU-15.11 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "shadow_size\|shadow_offset\|shadow_color" src/ui/menu/` executes, THEN zero matches with non-zero values. Verifies FP-11.
- **AC-MENU-15.12 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "autostart.*true" src/ui/menu/` runs against Timer nodes, THEN zero matches outside `QuicksaveFeedbackCard.tscn` and `QuickloadFeedbackCard.tscn`. Verifies FP-12 / FP-13.
- **AC-MENU-15.13 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "KEY_CONTROL\|KEY_ALT\|KEY_SHIFT\|is_key_pressed" src/ui/menu/` executes, THEN zero matches. Verifies FP-14.
- **AC-MENU-15.14 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "Timer.*period.*\(0\.\([0-2][0-9][0-9]\|0[0-9][0-9]\)\)" src/ui/menu/` (period < 333 ms) runs against `SaveCard.tscn` + scripts, THEN zero matches involving `modulate` updates. Verifies FP-16.
- **AC-MENU-15.15 [Logic] [BLOCKING — pending tooling]** GIVEN the scene-tree parser at `tools/ci/scene_tree_lint.py` (same tool as AC-MENU-15.9), WHEN it scans `.tscn` files under `src/ui/menu/` for scene-authored `accessibility_live = "assertive"` literals AND correlates each with the scene's root `.gd` script, THEN for each match, the script's `_ready()` contains a corresponding `call_deferred()`-style reset to `"off"` (Godot 4.x Callable form `(func(): accessibility_live = "off").call_deferred()` OR the legacy string-call form, both accepted). **Tooling pre-req: `tools/ci/scene_tree_lint.py` does not exist on disk** — see AC-MENU-15.9 status. (Status + Callable-form acceptance added 2026-04-27 per qa-lead and godot-specialist.) Verifies FP-17.
- **AC-MENU-15.16 [Logic] [BLOCKING]** GIVEN CI run targeting `src/ui/menu/`, WHEN `grep -rn "addons/steamworks" src/ui/menu/` executes, THEN zero matches. Verifies FP-18.

### H.16 Performance Budget

- **AC-MENU-16.1 [Logic] [BLOCKING]** GIVEN gameplay section running with no Pause Menu mounted, WHEN `PauseMenuController` is present on section root, THEN it has zero `_process()` callbacks, zero `_physics_process()` callbacks, and `PauseMenu.tscn` has not been added as a scene tree child. Sum contribution to per-frame cost from all Menu System nodes is **below profiler measurement threshold during gameplay (≤ 0.005 ms target)** — the `_unhandled_input` dispatch + InputContextStack peek per input event are non-zero but unmeasurable on Iris Xe target hardware. (Wording corrected 2026-04-27 per performance-analyst — prior "exactly 0.0 ms" claim made this AC fail any honest profiler check.) Verifies F.6 `C_menu_idle ≤ 0.005 ms`, CR-18.
- **AC-MENU-16.2 [Logic] [BLOCKING]** GIVEN no per-frame polling per CR-18, WHEN `MainMenu.gd` / `PauseMenu.gd` / `ModalScaffold.gd` are scanned, THEN none contain a `_process(delta)` or `_physics_process(delta)` function body. Single allowed exception is the `_ready()` boot-warning poll in `MainMenu.gd` (which is `_ready()`, not `_process()`). Verifies CR-18 grep scan in CI.

### H.17 Reduced-Motion Compliance

- **AC-MENU-17.1 [Logic] [BLOCKING]** GIVEN `accessibility.reduced_motion_enabled == true`, WHEN any of the 7 menu animations is triggered (folder slide-in 180 ms, folder slide-out 140 ms, stamp slam-down 100 ms, save-failed header band 80 ms, screen-shuffle 100 ms, quicksave fade-out 200 ms, modal scaffold appearance), THEN F.3 evaluates to `actual_duration_ms = 0` for each, and the animation's target property is set to its final value instantly (no tween runs). Verifies F.3, CR-23.
- **AC-MENU-17.2 [Logic] [BLOCKING]** GIVEN `reduced_motion_enabled == false` and folder slide-in fires, WHEN `_play_folder_slide_in()` is called, THEN F.3 yields `actual_duration_ms(180, false) == 180`, tween created with duration 0.180 s, `TRANS_CUBIC`, `EASE_OUT`. Verifies F.3 nominal path.
- **AC-MENU-17.3 [Logic] [BLOCKING]** GIVEN `reduced_motion_enabled` changes from `false` to `true` while a tween is in-flight, WHEN the in-flight tween completes, THEN the next `_play_*` call after the setting change produces `actual_duration_ms == 0` (setting takes effect on next call, not mid-flight per F.3 evaluation-point rule). Verifies F.3.

### H.18 Locale Switch Behaviour

- **AC-MENU-18.1 [Logic] [BLOCKING]** GIVEN Main Menu is open with EN locale active, WHEN `TranslationServer.set_locale("fr")` is called (simulating Settings locale switch), THEN within the same frame or next after `NOTIFICATION_TRANSLATION_CHANGED`: (a) all `Label.text` properties on Main Menu buttons have updated to FR via `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`; (b) `accessibility_name` on the same buttons has updated to FR via `_update_accessibility_names()`. Both must hold simultaneously. Verifies CR-22, F.8.
- **AC-MENU-18.2 [Logic] [BLOCKING]** GIVEN a modal is open (e.g., Quit-Confirm) with EN locale, WHEN `TranslationServer.set_locale("fr")` is called mid-modal, THEN modal remains open (locale change does not close or reset modal state), modal button labels update via `auto_translate_mode`, `accessibility_name` updates via `_update_accessibility_names()`. `peek() == Context.MODAL` throughout. Verifies §E Cluster G; CR-22.

### H.19 Window / Focus Lifecycle

- **AC-MENU-19.1 [Logic] [BLOCKING]** GIVEN a `MainMenu.gd` or `PauseMenu.gd` test calls `_notification(NOTIFICATION_APPLICATION_FOCUS_IN)` directly (simulating the OS focus-regain event — `NOTIFICATION_APPLICATION_FOCUS_IN` does not fire in headless/CI mode without a window manager), WHEN the handler runs, THEN: (a) `Input.flush_buffered_events()` was called (verified via an `InputFlushSpy` mock injected at construction); (b) `Input.set_custom_mouse_cursor(fountain_pen_texture, ...)` was called (verified via `InputSpy`). Story type changed from [Integration] to [Logic] in 2026-04-27 review per qa-lead — the OS-event simulation cannot run headless. The window-level trigger (actual alt-tab) is covered separately in AC-MENU-19.3 below as a [Visual] [ADVISORY] manual playtest. Verifies §E Cluster F window-focus re-entry; CR-17 cursor restore.
- **AC-MENU-19.3 [Visual] [ADVISORY]** GIVEN Menu System active in a real OS window session (not headless), WHEN the player alt-tabs out and back to the game window, THEN the custom fountain-pen-nib cursor is visible and the in-game state is unchanged. Manual playtest evidence in `production/qa/evidence/window-focus-recovery-[date]/` per the manual-walkthrough template (BLOCKING coord — see AC template task below). Added 2026-04-27 to cover the OS-level scenario that AC-MENU-19.1 cannot cover headless.
- **AC-MENU-19.2 [Visual] [ADVISORY]** GIVEN Menu System running with custom cursor active, WHEN a screenshot is taken with cursor over any menu surface, THEN cursor sprite is `ui_cursor_fountain_pen_nib_normal.png` (32×32 px), hotspot at nib tip (top-right), OS default cursor not visible simultaneously. Evidence: screenshot + art-director sign-off. Verifies CR-17.

### H.20 Visual Restraint Compliance

- **AC-MENU-20.1 [Visual] [ADVISORY]** GIVEN MainMenu or PauseMenu open at 1080p with comic-book outline post-process active, WHEN screenshot is taken of manila folder save-card area, THEN: (a) folder background = `#C19A4B`; (b) pause overlay alpha = 52% (`#1A1A1A` at 0.52); (c) no UI element has corner radius > 0; (d) no drop shadow / soft glow / gradient fill visible. Evidence: screenshot + art-director sign-off. Verifies §G `desk_overlay_alpha`, FP-10, FP-11.
- **AC-MENU-20.2 [Visual] [ADVISORY]** GIVEN Load Game grid rendered at 1080p, WHEN screenshot taken and converted to grayscale, THEN four card states (OCCUPIED, EMPTY, CORRUPT, AUTOSAVE) remain distinguishable by shape and text alone. OCCUPIED: `FILED` stamp upper-right. EMPTY: `VACANT` stamp + centered dash text. CORRUPT: diagonal `DOSSIER CORROMPU` stamp + redacted body lines. AUTOSAVE: `AUTO-FILED` stamp + blue-border trace (visible in grayscale as distinct left-side darkening). Evidence: grayscale screenshot + art-director sign-off. Verifies CR-25, WCAG SC 1.4.1.

### H.21 Sole-Publisher Discipline (NEW per QA-lead GAP-2)

- **AC-MENU-21.1 [Logic] [BLOCKING]** GIVEN the full lifetime of MainMenu and PauseMenu (`_ready()` through `_exit_tree()`), WHEN all signal emissions on the ADR-0002 Signal Bus are monitored, THEN zero signals are emitted by any `MainMenu.gd`, `PauseMenu.gd`, or `ModalScaffold.gd` node. *Grep gate*: `grep -rn "Events\." src/ui/menu/` returns only subscription calls (`.connect`, `.is_connected`, `await`) — no `.emit()` calls. Verifies CR-19.

### H.22 Re-Brief Operation (VS — gated by F&R coord)

- **AC-MENU-22.1a [Config] [BLOCKING — pre-sprint gate]** GIVEN the VS sprint for Re-Brief Operation is being planned, WHEN the story enters sprint, THEN `FailureRespawn.has_checkpoint() -> bool` exists as a documented public API in the F&R GDD with a corresponding unit test passing in CI. If the API does not exist, the story is not sprintable — it must not enter the sprint board. (Pre-sprint gate, split from former AC-MENU-22.1 in 2026-04-27 per qa-lead — a BLOCKING-on-BLOCKED AC was a placeholder, not a verifiable criterion.)
- **AC-MENU-22.1b [Logic] [BLOCKING — VS]** GIVEN AC-MENU-22.1a has passed (F&R API exists), GIVEN PauseMenu open with `FailureRespawn.has_checkpoint() == true`, WHEN PauseMenu renders, THEN the Re-Brief Operation entry is visible. WHEN `has_checkpoint() == false`, THEN the entry is hidden (NOT disabled). On activation: opens ModalScaffold confirm; on confirm: calls `restart_from_checkpoint()`. Verifies CR-13.

---

### Coverage Matrix

| Item | Primary ACs | Gate |
|---|---|---|
| CR-1 | 1.1 | BLOCKING |
| CR-2 | 10.1–10.4 | BLOCKING |
| CR-3 | 2.3 | BLOCKING |
| CR-4 | 2.1, 2.2, 2.5 | BLOCKING / ADVISORY |
| CR-5 | 3.1, 3.2, 3.3 | BLOCKING |
| CR-6 | 4.1–4.4 | BLOCKING |
| CR-7 | 5.1, 5.2, 5.3, 13.4 | BLOCKING / ADVISORY |
| CR-8 | 6.1–6.5 | BLOCKING / ADVISORY |
| CR-9 | 7.1–7.3 | BLOCKING |
| CR-10 | 8.1–8.4 | BLOCKING |
| CR-11 | 9.1, 9.5 | BLOCKING |
| CR-12 | 9.2, 9.3, 9.4, 9.6 | BLOCKING |
| CR-13 | 22.1 (placeholder, BLOCKED on F&R) | BLOCKING |
| CR-14 | 11.2, 10.4 | BLOCKING |
| CR-15 | covered implicitly by F.4 ACs + 15.12 timer gate | — |
| CR-16 | 20.1 | ADVISORY |
| CR-17 | 19.1, 19.2 | BLOCKING / ADVISORY |
| CR-18 | 1.1, 16.1, 16.2 | BLOCKING |
| CR-19 | 21.1 | BLOCKING |
| CR-20 | 4.3 | BLOCKING |
| CR-21 | 13.1 | BLOCKING |
| CR-22 | 13.2, 13.4, 18.1, 18.2 | BLOCKING |
| CR-23 | 17.1–17.3 | BLOCKING |
| CR-24 | 12.4 | BLOCKING |
| CR-25 | 20.2 | ADVISORY |
| F.1 | 9.1, 9.2 | BLOCKING |
| F.2 | 6.6 | BLOCKING (locale gate) |
| F.3 | 17.1–17.3 | BLOCKING |
| F.4 | 8.4 (debounce), 15.12 (timer gate) | BLOCKING |
| F.5 | 9.3, 9.4 | BLOCKING |
| F.6 | 16.1, 16.2 | BLOCKING |
| F.7 | 13.1 | BLOCKING |
| F.8 | 13.2, 18.1, 18.2 | BLOCKING |
| FP-1 through FP-18 | 15.1–15.16 | BLOCKING / ADVISORY |

**Note**: All test file paths (`tests/unit/menu_system/`, `tests/integration/menu_system/`, `tools/ci/check_menu_forbidden_patterns.sh`) are PROPOSED — they do not exist on disk yet. The implementing programmer creates them. Do not reference as existing evidence in sprint review until created and passing runs are recorded.

## Open Questions

Open questions accumulated across §C–§H, organized by gate level (BLOCKING for sprint vs ADVISORY) and consolidated for tracking. Closures via fresh `/design-review` session, ADR amendment, or upstream GDD coordination.

### Blocking for sprint (14 items)

| OQ | Item | Owner | Resolution path |
|---|---|---|---|
| **OQ-MENU-1** | **ADR-0004 amendment**: add `Context.MODAL` + `Context.LOADING` enum values to `InputContextStack.Context`. Bundles 3 previously-separate items (Settings modal scaffold, Menu modal lifecycle CR-2/CR-8, F&R revision item #4) into one amendment. | technical-director + lead-programmer | `/architecture-decision adr-0004-amendment` (or inline ADR-0004 patch) before Menu sprint planning |
| **OQ-MENU-2** | **ADR-0004 Gate 1** (Inherited from Settings + HUD Core sprints): confirm Godot 4.6 `Control.accessibility_*` property names (`accessibility_role`, `accessibility_name`, `accessibility_live`). 5-min editor inspection per godot-specialist Item 8. Bundles with GATE-F7-A. | godot-specialist | 5-min Godot 4.6 editor session reading `Control` GDScript API autocomplete |
| **OQ-MENU-3** | **ADR-0004 Gate 2** (Inherited): confirm Theme inheritance property name (`base_theme` vs `fallback_theme`). 2-min editor inspection. | godot-specialist | 2-min Godot 4.6 editor session inspecting Theme resource Inspector |
| **OQ-MENU-4** | **ADR-0002 amendment** (Inherited from Settings OQ-SA-2): add `settings_loaded` one-shot signal to taxonomy. | lead-programmer | ADR-0002 patch in same session as OQ-MENU-1 |
| **OQ-MENU-5** | ~~**ADR-0007 amendment** (Inherited from Settings OQ-SA-1): register SettingsService at autoload slot #8.~~ **CLOSED 2026-04-27** — SettingsService landed in ADR-0007 §Canonical Registration Table per the 2026-04-27 amendment. | lead-programmer | RESOLVED |
| **OQ-MENU-6** | **F&R GDD amendment**: add public query API `has_checkpoint() -> bool` + `restart_from_checkpoint() -> void` (or signature TBD). Required for VS Re-Brief Operation entry CR-13 + AC-MENU-22.1. | game-designer + systems-designer | F&R GDD §C amendment in fresh session |
| **OQ-MENU-7** | **LS GDD amendment**: surface `transition_to_section()` failure via `transition_failed(reason)` signal OR return `bool`. Required by §E Cluster C case 1 (failed-section-load recovery). | level-designer + systems-designer | LS GDD §C/§F amendment |
| **OQ-MENU-8** | **Save/Load GDD amendment**: define canonical "required keys" set for sidecar validation. Menu needs `is_valid_metadata(dict) -> bool` predicate per §E Cluster C case 3. | systems-designer | Save/Load GDD §C/§D amendment |
| **OQ-MENU-9** | **Save/Load GDD amendment**: explicitly prohibit relative-time strings in sidecar metadata; all timestamps must be mission-time `{section} — {time} GMT` format only. Closes FP-4/FP-5 bypass route per §E Cluster J case 5. | game-designer | Save/Load GDD §C amendment |
| **OQ-MENU-10** | **Settings GDD amendment**: `SettingsService.dismiss_warning()` returns `bool` indicating write success. Required for boot-warning disk-full detection per §E Cluster A case 5 + AC-MENU-6.4. | game-designer | Settings GDD §C amendment |
| **OQ-MENU-11** | **GATE-F3-A** (BLOCKING for impl): confirm `Tween.set_duration(0.0)` behaves as instant property-set in Godot 4.6 (not as divide-by-zero or no-op). If unreliable, branch implementation: `if actual_duration_ms == 0: [instant set]; else: [tween]`. | godot-specialist | Editor test in Godot 4.6 |
| **OQ-MENU-12** | **GATE-F4-A** (BLOCKING for impl): confirm `Tween.stop()` on `create_tween()`-created Tween does not free the Tween (allowing restart). Distinction between `stop()`, `kill()`, and reference lifetime is doc-dependent in Godot 4.x. | godot-specialist | Editor test |
| **OQ-MENU-13** | **GATE-F7-B** (BLOCKING for impl): confirm `call_deferred("set", "property_name", value)` syntax in 4.6 GDScript. Alternative `call_deferred.bind(...)` form may be required. | godot-specialist | Editor test |
| **OQ-MENU-14** | **GATE-F2-A** (BLOCKING before localization ships, per AC-MENU-6.6): confirm `Label.get_line_count()` returns wrapped-line count (not `\n` count). TextServer reworked across 4.4–4.5. (GATE-F2-B closed 2026-04-27 per project engine reference `docs/engine-reference/godot/modules/ui.md`: `label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` is the 4.6 idiom.) | godot-specialist + localization-lead | 5-min editor verification before any locale ships |
| **OQ-MENU-25** | **Localization L212 cap scope** (elevated 2026-04-27 from ADVISORY OQ-MENU-17): confirm whether the 25-char cap applies to labels only or all visible strings. Without resolution, modal scaffold body width has no authoritative constraint; `menu.new_game_confirm.body_alt` (28 chars) and the four other body-copy strings (>25 chars) cannot be locked. | localization-lead | Localization GDD L212 clarification before sprint |

### Advisory (10 items)

| OQ | Item | Owner | Resolution path |
|---|---|---|---|
| **OQ-MENU-15** | **ADR-0004 IG7 layer-10 collision**: Settings panel + Cutscenes letterbox both at CanvasLayer 10. If they cannot be simultaneously active (Settings only from Pause/Menu, NOT during cutscenes), collision is benign. ADR-0004 owner should annotate. | technical-director | ADR-0004 IG7 footnote |
| **OQ-MENU-16** | **PauseMenuController architecture choice**: stand-alone `Node` script per section vs `SectionRoot` base script. godot-specialist's Item 9 alternative. Level-streaming team coord. | level-designer + godot-specialist | Decision before Menu sprint impl |
| **OQ-MENU-17** | **CLOSED — elevated to BLOCKING as OQ-MENU-25** in design-review 2026-04-27. | — | See OQ-MENU-25. |
| **OQ-MENU-18** | **Cutscenes & Mission Cards (#22) forward coord**: when CMC is authored, the mission-dossier asset reuse from Art Bible §7D + Menu §V seed should be coordinated. CMC consumes Menu's mission-dossier card visual register or instantiates its own. | art-director + narrative-director | Coord during CMC GDD authoring |
| **OQ-MENU-19** | **Audio GDD §V amendment**: register the 8 UI foley sources A1–A8 (typewriter clack, drawer slide-in/out, grid nav, card flip, stamp, paper shuffle, modal open) in a new "UI foley sources (non-signal-driven)" subsection of Audio GDD §V SFX catalog. Not blocking — Menu GDD references cue names + UI bus routing; Audio GDD amendment registers them for sound-designer delegation. | audio-director + sound-designer | Audio GDD §V patch |
| **OQ-MENU-20** | **GATE-F1-A/B**: confirm `GridContainer.columns = 2` respects 7-child stop naturally in Godot 4.6 (no phantom 8th child needed) AND confirm `add_theme_constant_override(&"h_separation", 6)` / `&"v_separation"` API names in 4.6. LOW risk. | godot-specialist | 5-min editor verification |
| **OQ-MENU-21** | **GATE-F5-A**: confirm `_unhandled_input` propagation order — focused `Button`'s handler fires before parent `SaveGrid` container's handler. Documented behavior; verify in 10-min editor test. LOW risk. | godot-specialist | Editor test |
| **OQ-MENU-22** | **GATE-F8-A**: confirm `NOTIFICATION_TRANSLATION_CHANGED` constant name in 4.6 + fires on `Control` (not just `Node` base class) when `TranslationServer.set_locale()` is called. LOW risk — documented since Godot 3.x. | godot-specialist | Editor test |
| **OQ-MENU-23** | **GATE-F8-B**: confirm whether 4.6's AccessKit auto-re-resolves `accessibility_name = tr(...)` on locale change (i.e., whether `auto_translate_mode` covers `accessibility_name`). MEDIUM risk. If yes, manual `_notification` handler is unnecessary boilerplate; if no, it is essential. | godot-specialist | Editor test in Godot 4.6 |
| **OQ-MENU-24** | **DisplayServer.window_set_dpi_changed in 4.6** (per §E Cluster F case 3): verify signal exists for cursor hotspot restoration on multi-monitor DPI change. If absent, accept cursor hotspot drift as known defect. LOW risk. | godot-specialist | Editor inspection |

### Resolved during this GDD authoring (3 items, for traceability)

These OQs from upstream GDDs are CLOSED by this GDD's spec — no further action needed.

| Resolved OQ | Closed by |
|---|---|
| **Settings OQ-SA-3** (Menu System scaffold for photosensitivity warning) | This GDD's CR-8 + §C.4 ModalScaffold spec |
| **HUD Core REV-2026-04-26 D2 HARD MVP DEP** (photosensitivity boot-warning UI) | This GDD's CR-8 + §C.4 ModalScaffold (boot-warning is Day-1 MVP) |
| **PPS OQ-PPS-2** (sepia dim vs neutral dim for pause overlay) | This GDD's §C.10 PPS row + §V.1 desk overlay spec — Pause uses 52% Ink Black ColorRect, NOT sepia tint. Document Overlay continues to use sepia dim. PPS GDD should annotate OQ-PPS-2 with this closure. |

### Deliberately omitted from MVP / VS scope (5 items, for traceability)

These items are intentionally absent from this GDD to prevent re-litigation in future sessions.

| Omitted item | Reason |
|---|---|
| Save thumbnails / screenshots | Pillar 5 Refusal 3 + FP-3 (period authenticity violation) |
| Real-world wall-clock timestamps on save cards | Pillar 5 Refusal 4 + FP-4/FP-5 (mission-time only per Save/Load OQ-MENU-9) |
| "Are you sure?" confirmation language | Pillar 5 Refusal 2 + FP-6 (CASE CLOSED stamp + Cancel/Confirm pattern replaces it) |
| Translucent gameplay-buffer overlay | Pillar 5 Refusal 1 + FP-1 (52% Ink Black ColorRect ABOVE viewport replaces it) |
| Menu music during in-game Pause | Pillar 3 + Audio L378 + AFP-1 (gameplay music continues uninterrupted; Pause is a held operation, not a separated-from-world state) |
| Gamepad rebinding parity in menus | Per `.claude/docs/technical-preferences.md`: "Gamepad Support: Partial — full menu/gameplay navigation; rebinding parity is post-MVP." |
| Multiplayer / co-op menus | Anti-pillar — single-player premium |
| Achievement notifications / Steam overlay chrome | FP-18 + Pillar 5 (modern UX paternalism) |
| Loading screen tips / pre-load mini-games | Pillar 3 + Pillar 5 (no modern UX paternalism; LS handles loading via fade-to-black per LS CR-1) |
