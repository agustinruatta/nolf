# Interaction Pattern Library: The Paris Affair

> **Status**: In Design
> **Author**: ux-designer + agustin.ruatta@vdx.tv (solo)
> **Last Updated**: 2026-04-29
> **Template**: Interaction Pattern Library
> **Closes**: `/gate-check pre-production` blocker #5 of 7
> **Linked Documents**: `design/gdd/systems-index.md` · `design/accessibility-requirements.md` · `design/gdd/input.md` · `design/gdd/menu-system.md` · `design/gdd/hud-core.md` · `design/gdd/hud-state-signaling.md` · `design/gdd/document-overlay-ui.md` · `design/gdd/cutscenes-and-mission-cards.md` · `design/gdd/dialogue-subtitles.md` · `design/gdd/settings-accessibility.md` · `design/gdd/save-load.md` · `design/gdd/failure-respawn.md` · `design/gdd/localization-scaffold.md` · `docs/architecture/adr-0004-ui-framework.md` (Proposed)
> **Pillar 5 carve-out posture**: Where a pattern locks a Pillar-5 absolute that creates a WCAG conflict, the resolution is the **Stage-Manager carve-out** (Settings-gated opt-in, default `false`). Patterns must surface this when they apply.

---

## Overview

This library is the canonical catalog of **interaction patterns** used across *The Paris Affair*. A pattern here is a reusable contract — input routing rule, modal scaffold, transition register, accessibility convention — that more than one screen, system, or surface depends on. When a UX spec, GDD, or implementation faces a choice that this library covers, it must reference the named pattern by ID rather than re-inventing it.

**Why this document exists**. Twenty-three system GDDs each declare per-system UI requirements; without a shared pattern vocabulary, the same interaction (modal dismiss, alert announce, sepia register, reduced-motion branch) gets specified five different ways across five GDDs and drifts on every revision. This library extracts the recurring conventions, locks their canonical form, and gives each one a stable ID that the per-screen UX specs (`design/ux/[screen].md`, authored via `/ux-design`) and stories can cite.

**Scope**. The library catalogs **interaction grammar** — what the player does, what the game does back, what the screen reader announces, what audio plays, what context pushes/pops. It does NOT specify visual design (Art Bible §3 owns visual identity, font registry, color palette, layout pixel budgets), engine architecture (ADR-0004 owns Theme + InputContext autoload + FontRegistry), or per-screen layout (per-screen UX specs own it). Where a pattern intersects with one of these, it cites the owning document and stops there.

**Authority and precedence**.

1. When this library and a GDD disagree, this library wins for the *interaction grammar* of the pattern; the GDD wins for *what the system does with the pattern*.
2. When this library and ADR-0004 disagree on UI architecture, ADR-0004 wins (it is the engine contract).
3. When this library and `design/accessibility-requirements.md` disagree on an accessibility commitment, the accessibility document wins.
4. When this library and the Pillar 5 absolutes (game-concept.md + per-GDD FP- entries) disagree on what is permitted on screen, Pillar 5 wins — the resolution is the Stage-Manager carve-out, never quietly relaxing a pattern.

**How patterns are organized**. Each pattern has: **ID** (kebab-case, stable), **Category**, **Used In** (every system or screen that depends on it — this is the bidirectional dependency contract from `coding-standards.md`), **Specification** (the rules), **Pillar fit** (which pillar(s) the pattern serves), **When to Use / When NOT to Use**, and **Accessibility notes** (what the pattern owes the Standard tier). Patterns are grouped into the **Pattern Catalog** index below for browsability and then specified in full in the **Patterns** section.

**Audience**. UX designers (when authoring per-screen UX specs), gameplay/UI programmers (when implementing or reviewing UI code), QA (when writing acceptance tests against patterns), and the accessibility audit (when verifying Standard tier compliance).

---

## Pattern Catalog

The catalog below indexes every pattern in this library, grouped by category. **ID** is the stable kebab-case reference UX specs and stories cite. **Pillar fit** lists the pillar(s) the pattern serves; "Engineering primitive" means the pattern is an architecture/correctness rule with no direct pillar tie. **Used in** is non-exhaustive — full dependency lists live in each pattern's specification below.

**Totals**: 36 patterns across 9 categories.

### Input Routing (6)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `input-context-stack` | Context push/pop autoload that gates which system consumes input. | Every system with a non-gameplay UI surface (Menu, Document Overlay, Cutscenes, Settings, Save/Load, F&R, Level Streaming). | Engineering primitive |
| `unhandled-input-dismiss` | `_unhandled_input(event)` is the project default; `_input(event)` is reserved for input-eating priority cases. | Every modal / cutscene / overlay dismiss path. | Engineering primitive |
| `dual-focus-dismiss` | Modal dismiss must fire from keyboard, gamepad, and (when applicable) mouse-click-outside, regardless of which child element holds focus. | Document Overlay, Quit-Confirm, Save-overwrite, Save-failed, Photosensitivity warning. | Standard-tier accessibility |
| `set-handled-before-pop` | `set_input_as_handled()` MUST run before `InputContext.pop()` to prevent silent-swallow propagation. | Every dismiss handler. | Engineering primitive |
| `held-key-flush-after-rebind` | Settings calls `Input.action_release()` immediately after `action_erase_events` + `action_add_event` to avoid a stuck "pressed" state. | Settings rebinding flow. | Engineering primitive |
| `tab-consume-non-focusable-modal` | Modal-root absorbs `ui_focus_next` / `ui_focus_prev` when the modal subtree has zero secondary focusable Controls, preventing focus escape. Optional polite AT announce on Tab consumption. | Document Overlay (only modal with no secondary focus targets at VS). | Standard-tier accessibility (focus trap correctness) |

### Modal & Dialog (6)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `modal-scaffold` | Shared template for every blocking dialog: focus trap + assertive announce + Confirm/Cancel button order + Esc/B dismiss + InputContext push to MODAL. | Quit-Confirm, Return-to-Registry, Re-Brief, New-Game-Overwrite, Save-overwrite, Save-failed, Photosensitivity boot-warning. | Engineering primitive + Standard-tier accessibility |
| `stage-manager-carve-out` | Settings-gated opt-in (default `false`) that lets accessibility unlock a Pillar-5 absolute. The project's signature Pillar-5 vs WCAG resolution. | Cutscenes (cinematic skip + text summary), HUD Core (damage flash off), any future Pillar-5 vs WCAG conflict. | Pillar 5 (load-bearing) + Accessibility |
| `photosensitivity-boot-warning` | First-launch persistent-flag modal warning + opt-out toggle, before any cinematic or chromatic flash plays. | Settings boot, before Main Menu. Anchors `hud_damage_flash_enabled` + Cutscenes CT-03 chromatic flash. | Accessibility (Basic+, project-elevated) |
| `save-failed-advisory` | PHANTOM-Red header band + Retry/Abandon buttons + assertive screen-reader announce; non-destructive (player choice, not auto-retry). | Save/Load (autosave failure, manual save failure, quicksave failure). | Pillar 5 (dossier register) + Accessibility |
| `case-file-destructive-button` | Ink Black fill + Parchment text styling for the destructive button in any Case File register modal. Distinct from the default BQA Blue safe-action button. Position is button-row left (paired with default-focus safe-action button on the right). Added 2026-04-29 per `design/ux/quit-confirm.md` OQ #3. | Quit-Confirm (Close File), Return-to-Registry (Return to Registry), Re-Brief Operation (Re-Brief), New-Game-Overwrite (Confirm). 4 known consumers via [CANONICAL] inheritance from `quit-confirm.md`. | Pillar 5 (Case File destructive register) + Standard-tier accessibility (color-independence via 4-signal redundancy) |
| `lectern-pause-card-modal` | Card-UI sister of `lectern-pause-register`: Parchment-on-sepia-dim gameplay-time modal card with no buttons, dismissed only via `ui_cancel`. Added 2026-04-29 per `design/ux/document-overlay.md` `/ux-review` OQ-UX-DOV-1. | Document Overlay UI (sole instance at VS). | Pillar 5 (Period Authenticity) + Pillar 2 (Discovery Rewards Patience) + Standard-tier accessibility |

### Cinematic & Card (5)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `mission-card-hard-cut-entry` | Briefing/Closing/Objective cards enter via hard cut, never fade-in. The Bass grammar. | Cutscenes Mission Cards (briefing / closing / objective). | Pillar 1 (Comedy: Bass grammar) + Pillar 5 (Period authenticity) |
| `silent-drop-dismiss-gate` | Cards reject `cutscene_dismiss` for the first N seconds with no visible affordance, then accept silently. The gate IS the UX. | Briefing card (4.0 s), Closing card (5.0 s), Objective card (3.0 s). | Pillar 5 (no visible affordance — FP-CMC-3) |
| `letterbox-slide-in` | 12-frame letterbox bars slide-in for cinematic composition (CT-05 only); reduced-motion replaces with hard-cut. | Cutscenes CT-05 climax. | Pillar 1 (cinematic composition) + Pillar 4 (CT-05 location climax) |
| `fade-to-black-close` | 24-frame fade-to-black on cinematic exit, paired with audio fade. | Closing card, mission-end transition. | Pillar 1 (cinematic composition) |
| `per-objective-opt-in-card` | Non-modal `ROLE_STATUS` slide-in card (720 × 200 px) that does NOT push InputContext.CUTSCENE — gameplay continues. The narrative substitute for a map waypoint. | Cutscenes objective updates (Mission & Level Scripting trigger). | Pillar 5 (narrative substitute for objective markers — Pillar-5 forbidden pattern) |

### HUD & Notification (7)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `lectern-pause-register` | Composite mode entered when Document Overlay opens: sepia-dim + ducked music + suppressed banter + suppressed HUD + suspended alert-music transitions. | Document Overlay UI. | Pillar 1 (theatre-mode refusal) + Pillar 2 (reading-rewards-patience) + Pillar 3 (theatre register) |
| `prompt-strip-lifecycle` | HUD prompt-strip widget that displays the active objective + first-encounter tutorial prompts; persists until acknowledged. | HUD Core, Mission & Level Scripting, D&S Plaza tutorial. | Pillar 5 (narrative objective text, no map markers) |
| `hud-state-notification` | Margin-note Label widget for transient state changes (MEMO_NOTIFICATION on document pickup, SAVE_FAILED, alert-cue). | HUD State Signaling. | Pillar 5 (margin-note dossier register) |
| `hoh-deaf-alert-cue` | Visual alert-state indicator paired with stinger audio so deaf/HoH players don't lose the stealth-detection signal. | HUD State Signaling REV-2026-04-26 D3 (HARD MVP DEP). | Accessibility + Pillar 3 (stealth as theatre — players must read the alert) |
| `critical-state-pulse` | Numeric value + visual flash + audio clock-tick when a resource crosses a critical threshold. Color-independent (numeric backup). | HUD Core health bar, low-HP state. | Accessibility (color-independent) + Pillar 3 |
| `diegetic-confirmation-toast` | ~1.5 s ephemeral dossier-register card (bottom-right), non-modal, for non-blocking confirmations. | Quicksave success, Quickload success, future ephemeral confirmations. | Pillar 5 (dossier register, non-intrusive) |
| `hud-auto-hide-on-context-leave` | HUD widgets hide when `InputContext != GAMEPLAY` and resume when context returns. `Tween.kill` on context-leave to prevent residual cost. | HUD Core (CR-10), Document Overlay, Cutscenes, Pause Menu, Settings. | Engineering primitive (perf budget) + Pillar 1 (theatre-mode refusal) |

### Subtitle & Caption (3)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `speaker-labeled-subtitle` | `[SPEAKER]:` prefix using a 7-category convention (`GUARD`, `CLERK`, `LT.MOREAU`, `VISITOR`, `STAFF`, `HANDLER`, `STERLING`). | Dialogue & Subtitles (D&S §C + 7-speaker rule), Cutscenes CT-04 HANDLER VO. | Pillar 1 (comedy lives in NPC voices) + Accessibility |
| `scripted-cinematic-caption` | D&S SCRIPTED Category 7 — in-cinematic dialogue captions rendered within the active letterbox image area. | Cutscenes CT-04 HANDLER VO line. | Accessibility + Pillar 5 (period-faithful, no modern caption styling) |
| `scripted-sfx-caption` | D&S SCRIPTED Category 8 — closed captions for narrative-critical non-dialogue SFX (device-tick, wire-cut, tick-cessation), MLS-triggered. | Cutscenes CT-05 narrative climax. | Accessibility (deaf/HoH narrative parity) |

### Settings & Rebinding (3)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `rebind-three-state-machine` | `NORMAL_BROWSE → CAPTURING → CONFLICT_RESOLUTION` state machine with cancel-out via Esc, conflict-warning UI, persistence to `user://settings.cfg`. | Settings rebinding screen. | Standard-tier accessibility |
| `toggle-hold-alternative` | Every "hold [button] to [action]" input offers a Settings-gated toggle alternative. | Sprint, crouch, ADS, gadget-charge (Settings CR-22 Day-1 MVP). | Standard-tier accessibility (motor) |
| `accessibility-opt-in-toggle` | The pattern shape for any Settings-gated accessibility opt-in: default `false`, persisted, label clarifies the trade-off, anchored to a Pillar-5 carve-out. | All Settings → Accessibility toggles (see Settings & Accessibility GDD §G.3 for canonical list). | Accessibility + Pillar 5 (carve-out shape) |

### Menu & Save (3)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `save-load-grid` | N-slot card grid (Load: 8-slot 2 × 4; Save: 7-slot 2 × 3 + 1; Slot 0 differentiated as Quicksave). Arrow-key + gamepad nav, AccessKit grid role. | Operations Archive (Load Game), File Dispatch (Save Game). | Pillar 5 (Operations Archive dossier register) + Accessibility |
| `pause-menu-folder-slide-in` | Pause Menu enters as a manila folder sliding in from screen edge; conditional Re-Brief Operation visibility. | Pause Menu (Menu System). | Pillar 5 (period-authentic manila folder register) |
| `sepia-death-sequence` | On player death: 60° camera pitch + 0.4 m Y translate over 800 ms + 1.5 s sepia fade + 2-frame hard-cut to F&R screen. No red vignette. | Failure & Respawn, Player Character death. | Pillar 3 (theatre-not-punishment) + Pillar 5 (no red vignette — modern AAA convention) |

### Localization (2)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `auto-translate-always` | Every static UI Label sets `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`; locale switch re-translates without scene rebuild. | Every UI surface. | Engineering primitive + i18n |
| `accessibility-name-re-resolve` | `_notification(NOTIFICATION_TRANSLATION_CHANGED)` handler re-resolves `accessibility_name` / `accessibility_description` so screen readers announce in the new locale. | Every AccessKit-tagged widget. | Accessibility + i18n |

### Reduced-Motion (1)

| ID | One-line | Used in | Pillar fit |
|---|---|---|---|
| `reduced-motion-conditional-branch` | At every animation site, branch on `Settings.reduced_motion`: tween path vs hard-cut/instant variant. The hard-cut variant must be vestibular-safe by design. | Cutscenes letterbox slide-in, Document Overlay sepia transition, Menu System animations, HUD damage_flash. | Standard-tier accessibility (vestibular) |

---

## Patterns

### Input Routing

#### `input-context-stack`

**Category**: Input Routing
**Pillar fit**: Engineering primitive
**Owner of contract**: ADR-0004 §IG (canonical Context enum + push/pop semantics) + Input GDD §C (action gating)
**Used In**: Menu System (`MENU`, `PAUSE`, `MODAL`), Document Overlay (`DOCUMENT_OVERLAY`), Cutscenes (`CUTSCENE`), Settings panel (`MENU` via Pause + dedicated `SETTINGS_REBIND` for capture sub-state), Save/Load dialogs (`MODAL`), Failure & Respawn (`MODAL`), Level Streaming (`LOADING`, pending ADR-0004 amendment).

**Description**. A single autoload (`InputContext`) maintains a stack of context values from a canonical enum (`GAMEPLAY`, `MENU`, `PAUSE`, `MODAL`, `CUTSCENE`, `DOCUMENT_OVERLAY`, `LOADING`, `SETTINGS_REBIND`). The top of the stack is "current"; consumers gate input by querying `InputContext.is_active(Context.X)`. Push when a UI surface opens; pop when it closes. The stack ensures nested surfaces (Pause → Settings → Rebind capture) restore correctly.

**Specification**.

1. The autoload is `/root/InputContext` and loads at the position registered in ADR-0007.
2. Public API: `push(context)`, `pop()`, `current() -> Context`, `is_active(context) -> bool`. No direct manipulation of the underlying stack.
3. Consumers gate input handlers by an `is_active(GAMEPLAY)` (or relevant context) check at the top of `_unhandled_input()`. Consumers MUST NOT inspect the stack contents.
4. The `is_active(X)` semantics: returns `true` iff `current() == X`. Non-top entries do not match. (See AC-INPUT-2.1.)
5. The owning system pushes on open and pops on close; no other system writes to the stack on its behalf. Cross-system push is a defect.
6. Held-key state survives push/pop transitions (Input AC-INPUT-5.1) — the stack does not flush input.
7. On scene tear-down (Level Streaming, Quit), all UI consumers must pop their context in `_exit_tree()` before the autoload is disposed.

**When to Use**. Any time a UI surface needs to claim input exclusively from gameplay or a parent surface — modal dialogs, overlays, cutscenes, menus, loading states.

**When NOT to Use**.

- Non-modal HUD updates (`per-objective-opt-in-card`) — gameplay continues, no context push.
- Toast confirmations (`diegetic-confirmation-toast`) — non-blocking, no context push.
- Pure read-only screens that don't accept input.

**Accessibility notes**. The stack is the substrate every accessibility feature builds on: subtitles suppress on `DOCUMENT_OVERLAY`, HUD hides on non-`GAMEPLAY` contexts, screen reader live regions announce on context push (assertive on modal, polite on status). Without the stack, these guarantees cannot be enforced.

---

#### `unhandled-input-dismiss`

**Category**: Input Routing
**Pillar fit**: Engineering primitive
**Owner of contract**: ADR-0004 §IG (`_unhandled_input` mandate) + Input GDD §C (Core Rule 1)
**Used In**: Every modal / cutscene / overlay dismiss path. Pause Menu, Document Overlay, Mission Cards, Quit-Confirm, Save-failed, Photosensitivity, Settings rebinding screen.

**Description**. The project default for input handling is Godot's `_unhandled_input(event)` callback. Use of `_input(event)` is an exception that requires an in-source justifying comment and code-review approval (Input AC-INPUT-6.3 ADVISORY). The reason: `_input` consumes events before the focus tree gets a chance, defeating focus-based routing and accidentally swallowing keyboard navigation.

**Specification**.

1. UI surfaces implement dismiss in `_unhandled_input(event)`, never `_input(event)`.
2. The handler's first line is the InputContext gate: `if not InputContext.is_active(Context.X): return`.
3. The handler matches actions via `event.is_action_pressed(InputActions.SOMETHING)`, never raw `KEY_*` / `JOY_BUTTON_*` constants (Input AC-INPUT-6.1).
4. Action constants live in `res://src/core/input/input_actions.gd` and are referenced via the `InputActions` global class, never via string literals or `preload(...)` paths.
5. Exceptions to `_unhandled_input` (debug overlays, input-eating priority cases) are gated by `OS.is_debug_build()` and accompanied by a justifying code-review comment.

**When to Use**. Every player-facing input handler in a UI surface.

**When NOT to Use**.

- Engine-level debug overlays that must intercept before focus routing (justify in source).
- System-mandated overrides like `_gui_input` for Control-specific handling (separate Godot callback, different semantics).

**Accessibility notes**. Using `_unhandled_input` ensures keyboard focus traversal (Tab/Shift+Tab) and gamepad UI navigation reach focusable Controls before the dismiss handler steals the event — required for keyboard-only navigation per accessibility-requirements.md Visual table.

---

#### `dual-focus-dismiss`

**Category**: Input Routing
**Pillar fit**: Standard-tier accessibility
**Owner of contract**: Input GDD §C (Core Rule 4 dual-focus dismiss) + Input AC-INPUT-3.1
**Used In**: Document Overlay (Esc / B / mouse-click-outside), Mission Cards (Esc / B after dismiss-gate; mouse-click-outside NOT supported — Pillar 5), Quit-Confirm modal (Esc / B / Cancel button), Save-overwrite, Save-failed (Retry / Abandon), Photosensitivity warning.

**Description**. A modal dismiss must fire from any of three input modalities — keyboard (`Esc` / Cancel action), gamepad (`B` / `Circle` / Cancel button), and (when permitted by the surface) mouse-click-outside the modal scrim — regardless of which child element holds focus. Without this rule, players who tab into a button inside the modal find that pressing Esc on the button does not close the modal because focus consumed the event.

**Specification**.

1. The dismiss handler lives on the modal's root CanvasLayer (or modal Control that owns the InputContext push), not on individual buttons.
2. The handler runs in `_unhandled_input` (per `unhandled-input-dismiss`), so focused children that don't consume the cancel event let it bubble.
3. The handler MUST execute `set_input_as_handled()` before `InputContext.pop()` (per `set-handled-before-pop`).
4. The cancel action is the InputActions canonical `ui_cancel` (mapped to Esc + B/Circle by ADR-0004 / Input GDD).
5. Mouse-click-outside support is per-surface: Document Overlay supports it (CR-7); Mission Cards do NOT support it (Pillar 5 forbids "click anywhere to skip" — silent-drop dismiss-gate owns dismissal). When supported, the modal scrim's `_gui_input` consumes a left-click and routes to the same dismiss handler.
6. The dismiss test must parametrize over `[keyboard_esc, gamepad_b, mouse_click_outside]` per Input AC-INPUT-3.1.

**When to Use**. Every modal that the player can dismiss without a destructive choice (Document Overlay, photo warning, Save-failed). When the modal has a destructive choice (Save-overwrite), Cancel is one of the buttons but `dual-focus-dismiss` still applies — Cancel = no overwrite.

**When NOT to Use**.

- Modals that lock the player into a choice (e.g., legal-acceptance EULA — none in this project).
- Surfaces where dismiss is forbidden by Pillar 5 (Mission Cards during dismiss-gate; the gate is the dismissal control, not a button or click).

**Accessibility notes**. Required for keyboard-only and gamepad-only players (Standard tier). A focus-trapped modal where Esc only closes when focus is on the modal background is one of the most common accessibility complaints in indie titles.

---

#### `set-handled-before-pop`

**Category**: Input Routing
**Pillar fit**: Engineering primitive
**Owner of contract**: Input GDD §C Core Rule 7 + Input AC-INPUT-3.2 + AC-INPUT-7.1
**Used In**: Every dismiss handler. Document Overlay close, Mission Card dismiss, Quit-Confirm Cancel, Save-failed Abandon, Photosensitivity Acknowledge.

**Description**. Order-of-operations rule: when a dismiss handler fires, it MUST call `set_input_as_handled()` *before* `InputContext.pop()`. If the order is reversed, the popped context exposes the gameplay handler to the same Esc/B event in the same frame, which then causes the gameplay handler to fire (e.g., opening Pause Menu, firing a weapon, dropping crouch). The bug presents as "I closed the dialog and a weird thing happened."

**Specification**.

1. Every dismiss handler emits `set_input_as_handled()` immediately on entering the handler (after the InputContext gate check), and only then performs `InputContext.pop()` and any cleanup.
2. CI enforcement: `tools/ci/check_dismiss_order.sh` greps for `InputContext.pop()` and verifies a `set_input_as_handled()` call appears before it in the same function (Input AC-INPUT-3.2).
3. The rule is independent of the dismiss action — the same order applies whether dismissed via Esc, B, mouse, or programmatic `close()`.

**When to Use**. Always, in every dismiss handler.

**When NOT to Use**.

- Programmatic close paths that don't originate from an input event (e.g., scripted `close()` after timer) — `set_input_as_handled()` is a no-op there but harmless.

**Accessibility notes**. Implicit dependency: the assertive-announce screen-reader event (`accessibility_live = LIVE_ASSERTIVE` on modal close) fires on close lifecycle, not on input-handling order — this rule does not affect the announce timing.

---

#### `held-key-flush-after-rebind`

**Category**: Input Routing
**Pillar fit**: Engineering primitive
**Owner of contract**: Input GDD §C Core Rule 9 + Input AC-INPUT-7.3
**Used In**: Settings rebinding flow (`rebind-three-state-machine`'s commit step).

**Description**. When a player rebinds an action while holding the prior key (e.g., they hold W to "move forward," then open Settings and rebind move forward to T), the engine retains the action's "pressed" state because the player never released W — but W is no longer bound to the action. The result: `Input.is_action_pressed(&"move_forward")` returns `true` indefinitely until the player presses *and releases* T. Settings must explicitly flush.

**Specification**.

1. After `InputMap.action_erase_events(action)` + `InputMap.action_add_event(action, new_event)`, Settings calls `Input.action_release(action)` immediately.
2. The flush runs once per rebound action, in the same frame as the rebind commit.
3. After flush, `Input.is_action_pressed(action)` returns `false` until the next press of the new binding.

**When to Use**. Every Settings rebind-commit path.

**When NOT to Use**.

- Initial `InputMap` setup at boot (no held-key state to flush).
- Reset-to-defaults if no rebind was applied (early-return).

**Accessibility notes**. None directly; this is correctness, not accessibility.

---

#### `tab-consume-non-focusable-modal`

**Category**: Input Routing
**Pillar fit**: Standard-tier accessibility (focus trap correctness)
**Owner of contract**: Document Overlay UI GDD §C.8 + CR-16 (canonical instance) + this entry
**Used In**: Document Overlay UI (sole instance at VS — only modal with zero secondary focusable Controls).

**Description**. When a modal subtree intentionally has zero secondary focusable Controls — i.e., no buttons, only a single scroll region or static text — the modal root must consume `ui_focus_next` and `ui_focus_prev` actions in `_unhandled_input` to prevent focus escape from the modal subtree to underlying gameplay or HUD focus targets. Without consumption, pressing Tab while reading would advance focus into the gameplay tree (where focus targets may not even exist or may be stale), confusing AT users and breaking the modal focus trap. The pattern complements `dual-focus-dismiss` (which governs Esc/B/click-outside dismissal) — together they form the complete input-handling contract for a no-button modal.

**Specification**.

1. **Trigger**. Modal subtree's `_unhandled_input(event)` checks `event.is_action_pressed("ui_focus_next")` and `event.is_action_pressed("ui_focus_prev")` after the `InputContext.is_active(MODAL_X)` gate.
2. **Consume**. Call `set_input_as_handled()` immediately. Do NOT call `grab_focus()` on any other Control — the focus stays where it is.
3. **No fallback button focus injection**. The pattern explicitly does NOT inject a synthetic focusable Control to receive Tab — that would require the modal to grow a second focus target (defeating the design intent of a no-button card).
4. **Optional polite AT announce** (post-VS enhancement). On Tab consumption, fire a polite `accessibility_live` announce: "[Modal name] — use arrow keys to scroll, Escape to close." Default OFF at VS pending Gate A AccessKit API confirmation.
5. **Pairs with `dual-focus-dismiss`**. The modal still dismisses via Esc/B/click-outside per `dual-focus-dismiss`; this pattern only governs `ui_focus_next` / `ui_focus_prev`.
6. **Code-review check**. The combination "non-focusable modal + missing Tab-consume" is a defect — the modal will leak focus to gameplay. Pair this pattern's adoption with a code-review verification that no second focusable Control exists in the modal subtree.

**When to Use**. Modals that intentionally have a single (or zero) focusable Control — typically reading surfaces where Tab has no meaningful target. Document Overlay is the canonical instance.

**When NOT to Use**.

- Multi-button modals — use `modal-scaffold`'s built-in focus trap (which cycles Tab among modal-internal focusable Controls).
- HUD widgets and non-modal surfaces — they don't claim input exclusively, so Tab consumption would be over-broad.
- Settings rebind capture state — that's a separate `rebind-three-state-machine` capture sub-state with its own focus rules.

**Accessibility notes**. The optional polite AT announce (specification rule 4) addresses a screen-reader UX gap: without the announce, AT users press Tab expecting movement and receive silence, which can read as a broken interaction. The polite-not-assertive choice avoids interrupting an in-progress body read. Mandatory at Comprehensive tier; ADVISORY at Standard tier (this project's commitment).

**Reference**: `design/ux/document-overlay.md` Interaction Map → "Modal interactions" + GDD CR-16 is the canonical specification.

---

### Modal & Dialog

#### `modal-scaffold`

**Category**: Modal & Dialog
**Pillar fit**: Engineering primitive + Standard-tier accessibility
**Owner of contract**: Menu System §C.2 (Owned Surfaces) + ADR-0004 §IG10 (AccessKit Day-1 mandate)
**Used In**: Quit-Confirm, Return-to-Registry, Re-Brief Operation, New-Game-Overwrite, Save-overwrite, Save-failed, Photosensitivity boot-warning. (Document Overlay and Mission Cards inherit *parts* of the scaffold but layer their own register on top.)

**Description**. The shared template every blocking dialog assembles from. Every modal in the project is built from this scaffold; per-surface UX specs add layout, copy, and surface-specific behavior, but cannot opt out of the scaffold's invariants.

**Specification**.

1. **Scene structure**. CanvasLayer (per-surface layer index, see ADR-0004) → modal Control with full-screen scrim → centered modal panel with Theme inheritance from `project_theme.tres`.
2. **Input contract** (mandatory). On open: push `InputContext.MODAL` (or surface-specific context like `DOCUMENT_OVERLAY`). On close: `set-handled-before-pop`. Dismiss obeys `dual-focus-dismiss` unless the surface is explicitly Pillar-5-locked (Mission Cards).
3. **Focus contract** (mandatory). On open, focus moves to the safest default button (Cancel for destructive dialogs, Acknowledge for advisory; never the destructive button by default). Focus is trapped within the modal — Tab/Shift+Tab cycles only modal-internal focusable Controls.
4. **Button order** (locked). Cancel is leftmost, Confirm is rightmost (LTR locales). For RTL locales, the order mirrors. Destructive Confirm uses PHANTOM Red `#C8102E` **EXCEPT in Case File register modals**, which use the `case-file-destructive-button` pattern (Ink Black `#1A1A1A` fill, Parchment text — see that pattern). Non-destructive Confirm uses BQA Blue `#1B3A6B` in both registers (Art Bible §3 palette).
5. **AccessKit contract** (Day-1 mandate per ADR-0004 IG10).
   - `accessibility_role = ROLE_DIALOG`
   - `accessibility_name = tr(title_key)`
   - `accessibility_description = tr(body_key)`
   - `accessibility_live = LIVE_ASSERTIVE` (one-shot on appear)
   - Re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` per `accessibility-name-re-resolve`.
6. **Animation contract**. Default: 200 ms fade-in scrim + 200 ms scale-in panel from 0.95. Reduced-motion: instant appear (per `reduced-motion-conditional-branch`).
7. **Background pause**. Modal does NOT pause the simulation — Pause Menu is its own surface with its own context. Modals layer over running gameplay; gameplay handlers gate on `InputContext.is_active(GAMEPLAY)` and self-suppress.
8. **Hierarchy depth**. A modal MAY open a child modal (Save grid → Overwrite confirm), but only one level deep. Nested modal-of-modal-of-modal is forbidden — refactor to a wizard or splitter.

**When to Use**. Every blocking dialog where the player must acknowledge or choose before continuing. Quit-Confirm, Save-overwrite, photosensitivity, save-failed, Return-to-Registry.

**When NOT to Use**.

- Non-blocking confirmations (`diegetic-confirmation-toast` instead).
- Cinematic surfaces where Pillar 5 owns dismissal (Mission Cards — `silent-drop-dismiss-gate` instead).
- Document reading (`lectern-pause-register` is a sister register, not a modal).
- Settings panel itself (it's a screen, not a dialog — uses `pause-menu-folder-slide-in` ancestry).

**Accessibility notes**. The AccessKit contract above is the project's floor. Modal focus trap is required for keyboard-only navigation; assertive-live is required so screen readers announce on appear (WCAG 2.1 SC 4.1.3 Status Messages).

---

#### `stage-manager-carve-out`

**Category**: Modal & Dialog (pattern shape; applied via Settings)
**Pillar fit**: Pillar 5 (load-bearing) + Accessibility (Standard tier)
**Owner of contract**: `design/accessibility-requirements.md` Pillar 5 carve-out posture (project-wide commitment) + Cutscenes §C.2.2 (canonical instance)
**Used In**: `accessibility_allow_cinematic_skip` (Cutscenes), `hud_damage_flash_enabled` opt-out (HUD Core), future Pillar-5-vs-WCAG conflicts.

**Description**. The project's signature accessibility pattern. When a Pillar 5 absolute (e.g., "no first-watch cinematic skip" / "no photosensitivity-incompatible flash") would create a WCAG 2.1 conflict, the resolution is NOT to relax the absolute by default — it is to add a Settings-gated opt-in toggle (default `false`) that lets the player who needs the accessibility unlock the relaxation explicitly. The shipping default preserves Pillar 5; the player choice honors accessibility. Both commitments are kept by surfacing the trade-off in Settings copy.

The name comes from "Stage Manager" register — the Settings panel's authorial register where the player makes deliberate, informed choices about the production they're seeing, mirroring how a stage manager makes lighting/cue decisions backstage rather than improvising in front of the audience.

**Specification**.

1. **Default**. The toggle ships `false`. Pillar 5 wins by default; the carve-out is opt-in only.
2. **Persistence**. Stored in `user://settings.cfg` `[accessibility]` category per ADR-0003. Survives game updates.
3. **Copy register**. Settings label uses Stage-Manager register — clarifies what the trade-off is (e.g., "Allow skipping unwatched cinematics. The story still plays in the background while skipped"). No moralizing copy; no "are you sure?"; no double-confirmation.
4. **Anchored to a Pillar 5 absolute**. Every carve-out instance must cite the specific Pillar 5 absolute it relaxes (e.g., "Cutscenes FP-CMC-2 — no mid-cinematic skip on first-watch"). If no Pillar 5 absolute is being relaxed, the toggle is just a regular accessibility setting — not a carve-out.
5. **Documented in `design/accessibility-requirements.md`**. The carve-out registry lives in the accessibility doc; this pattern library records only the *shape*.
6. **Pairing with `text_summary_of_cinematic`** (specific to Cutscenes). When the carve-out is for cinematic skip, the project also commits to a Settings-gated text-summary fallback so players who skip retain narrative parity. This pairing is recommended for any future "narrative bypass" carve-out.
7. **No runtime toggle prompt**. The carve-out is set in Settings, not in the moment of conflict (no "would you like to skip this cinematic? [Y/N]" prompt — that would itself violate Pillar 5 by surfacing the skip affordance during the cinematic).

**When to Use**. Every time a Pillar 5 absolute would create a WCAG 2.1 SC issue. Examples already in scope:

- WCAG SC 2.2.1 / 2.2.2 (Timing Adjustable / Pause, Stop, Hide) vs Cutscenes "no first-watch skip" → `accessibility_allow_cinematic_skip`.
- Photosensitivity (Harding FPA) vs CT-03 chromatic flash → `hud_damage_flash_enabled` (off-by-opt-out — slight inversion of the carve-out shape; documented in HUD Core REV-2026-04-26 D2).

**When NOT to Use**.

- Plain accessibility settings that don't relax a Pillar 5 absolute (e.g., subtitle size scale — that's just a setting, not a carve-out).
- Game balance / difficulty modes — Pillar 5 doesn't govern difficulty; use a different mechanism.
- Cosmetic preferences (FOV, brightness) — these are not carve-outs even when they affect accessibility.

**Accessibility notes**. The carve-out IS the accessibility commitment for Pillar-5 conflicts. Without it, every Pillar 5 absolute that intersects a WCAG SC would force a binary choice (drop Pillar 5 or fail accessibility); the carve-out lets both win.

---

#### `photosensitivity-boot-warning`

**Category**: Modal & Dialog
**Pillar fit**: Accessibility (Basic+, project-elevated to Day-1 HARD MVP DEP)
**Owner of contract**: Settings & Accessibility CR-23 + HUD Core REV-2026-04-26 D2 + Menu System §C.2 Owned Surfaces
**Used In**: First-launch flow, before Main Menu paints. Anchors `hud_damage_flash_enabled` opt-out and Cutscenes CT-03 chromatic flash exposure.

**Description**. A modal warning shown ONCE at first launch, before the Main Menu paints. It tells the player the game contains visual effects that may trigger photosensitive seizures (CT-03 single-frame chromatic flash + HUD damage_flash on hit + op-art rapid letterbox slide-in on CT-05) and offers two paths: Acknowledge (continue with effects on) or Go to Settings (jump to the Accessibility tab where the relevant toggles live). After acknowledgment, a persistent flag is written to `user://settings.cfg` and the modal does not re-appear unless the player resets settings.

**Specification**.

1. **Trigger**. First-launch detection via absence of `accessibility.photosensitivity_warning_acknowledged = true` in `user://settings.cfg`. The modal is shown by the Main Menu boot sequence after Settings autoload but before Main Menu paints.
2. **Scaffold**. Built on `modal-scaffold` with `accessibility_live = LIVE_ASSERTIVE`. Two buttons: "Acknowledge" (default focus) and "Open Settings."
3. **Copy register**. 38-word "Stage Manager" register copy per Settings & Accessibility CR-23 — informative, not alarming, no medical advice.
4. **Persistence**. On Acknowledge, write `accessibility.photosensitivity_warning_acknowledged = true` immediately to `user://settings.cfg`. On "Open Settings," write the flag and route to Settings → Accessibility tab.
5. **Locale**. Static copy uses `auto-translate-always`. AccessKit name re-resolves per `accessibility-name-re-resolve`.
6. **Reset behavior**. The flag is cleared by Settings "Reset to Defaults"; the modal will appear on next launch.
7. **Cinematic-flash interaction**. The modal is the accessibility anchor for CT-03's single-frame chromatic flash; CT-03 must not play before the modal has been acknowledged. (Mission scripting handles this via boot-order — first launch auto-routes through Main Menu, never directly into a cinematic.)
8. **Harding FPA audit**. The modal does not exempt the project from the Harding Flash and Pattern Analyzer audit committed in accessibility-requirements.md. The audit happens before VS lock; the modal communicates the residual risk after audit.

**When to Use**. First-launch only, before any cinematic content can play. Project commits to one global photosensitivity warning, not per-cinematic.

**When NOT to Use**.

- Subsequent launches (the persistent flag suppresses).
- In-game or in-cinematic warning (the warning is global, not per-scene — surfacing per-cinematic warnings would itself violate Pillar 5 by adding modern-game-look chrome).

**Accessibility notes**. The pattern itself is an accessibility commitment. The modal MUST be screen-reader-accessible (AccessKit role + assertive announce) so blind/low-vision players who don't see the visual warning still receive the audio announcement.

---

#### `save-failed-advisory`

**Category**: Modal & Dialog
**Pillar fit**: Pillar 5 (dossier register) + Accessibility (Standard tier)
**Owner of contract**: Save/Load §UI Requirements + HUD State Signaling SAVE_FAILED state + Menu System §C.2 Owned Surfaces
**Used In**: Quicksave failure, manual Save Game failure, autosave failure routing (autosave routes to non-blocking HUD State Signaling SAVE_FAILED instead of this modal — see specification rule 5).

**Description**. When a save operation fails (disk full, write permission denied, file system error), the player must be informed and given a meaningful choice — Retry or Abandon — without the failure auto-resolving silently or destroying their progress. The advisory is dossier-register: PHANTOM-Red header band, body explains the cause in non-technical language, two buttons. For autosave failures specifically, this modal is replaced by the non-blocking HUD State Signaling SAVE_FAILED state to avoid interrupting gameplay; the modal is reserved for player-triggered saves where the player is already paused.

**Specification**.

1. **Trigger**. Save/Load emits a `save_failed(slot, reason)` signal; UI routes to either this modal (manual save, quicksave) or to HUD State Signaling SAVE_FAILED (autosave). The routing is owned by the originating call-site, not Save/Load.
2. **Scaffold**. Built on `modal-scaffold`. Header band uses PHANTOM Red `#C8102E`. Body is one paragraph explaining the failure (e.g., "The file system reported insufficient disk space. The previous save is intact.") + the affected slot.
3. **Buttons**. "Retry" (Confirm position, BQA Blue) and "Abandon" (Cancel position). Default focus on Retry. Abandon does not erase the previous save's content; it merely closes the modal without re-attempting.
4. **AccessKit contract**. `accessibility_role = ROLE_ALERT` + `accessibility_live = LIVE_ASSERTIVE`. Screen reader announces the header copy + the cause + the button labels in scripted order.
5. **Autosave routing**. Autosave failure does NOT open this modal; it routes to HUD State Signaling SAVE_FAILED (margin-note Label, non-blocking). Rationale: autosave fires during gameplay and a blocking modal would interrupt the player; the margin-note tells them the autosave didn't take so they can manual-save when they're ready. (Save/Load §UI defers exact routing to call-site convention.)
6. **No auto-retry**. The system does not silently retry the save N times before showing the modal. The first failure is the modal — players don't trust silent retries on disk operations.
7. **Locale**. Cause-string is localized via `tr()`; the cause enum maps to a `tr_key` per Save/Load §V.

**When to Use**. Every player-triggered save that fails (Quicksave F5, manual Save Game from Pause Menu, New-Game-overwrite if it triggers a save).

**When NOT to Use**.

- Autosave failure — use HUD State Signaling SAVE_FAILED instead.
- Load failures — Load uses its own scaffold (Operations Archive load-failed dialog, separate UX spec).
- Settings save failures — Settings persists silently with a margin-note on next launch if the prior save was lost.

**Accessibility notes**. Assertive announce is mandatory — players who don't see the modal must learn of the failure. The cause copy must be plain-language (not error codes) so cognitive-accessibility players can act on it. PHANTOM Red header is a color signal; the header text ("SAVE FAILED") is the non-color backup.

---

#### `case-file-destructive-button`

**Category**: Modal & Dialog
**Pillar fit**: Pillar 5 (Case File destructive register) + Standard-tier accessibility
**Owner of contract**: `design/ux/quit-confirm.md` Section C.3 (canonical instance) + `interaction-patterns.md` (this entry)
**Used In**: Quit-Confirm (Close File button), Return-to-Registry (Return to Registry button) [VS], Re-Brief Operation (Re-Brief button) [VS], New-Game-Overwrite (Confirm button). 4 known consumers via [CANONICAL] inheritance from `quit-confirm.md`.

**Description**. The destructive button in a Case File register modal uses a distinct visual styling — Ink Black `#1A1A1A` fill with Parchment `#E8DCC4` text — that contrasts with the default safe-action button (BQA Blue `#1B3A6B` fill with Parchment text). The Ink Black fill mirrors the modal's header band (which renders as a stamped classification on a manila folder per art-bible §7D), reinforcing the visual association between the stamp and the destructive consequence. Position is always button-row left, paired with the default-focus safe-action button on the right (per `quit-confirm.md` [CANONICAL] decision). The destructive button is NEVER the default focus — players must explicitly Tab or click to it.

**Specification**.

1. **Default state fill**: Ink Black `#1A1A1A` fill, Parchment `#E8DCC4` text, hard-edged rectangle (no rounded corners, no drop shadow per art-bible §3.3).
2. **Focus state fill (inverted)**: Parchment fill, Ink Black text, with a 4 px BQA Blue `#1B3A6B` border. The inversion preserves the destructive identity (Ink Black/Parchment palette) while making focus unambiguous.
3. **Button position within button row**: ALWAYS left of the default-focus safe-action button. Right-side placement is forbidden (it would compete for the player's first-Tab attention with the safe button).
4. **Button hit-target**: minimum 280 × 56 px at 100% ui_scale (matches WCAG SC 2.5.5 + general project button floor).
5. **Activate feedback**: 1-frame fill-invert visual + rubber-stamp thud SFX on UI bus (per Player Fantasy "rubber-stamp thud on destructive actions"). The SFX is the load-bearing audio cue for destructive actions in the Case File register — distinct from the paper-shuffle SFX used for safe-action button activations.
6. **AccessKit**: `accessibility_role = "button"` + non-empty `accessibility_name` (the localized button label) + non-empty `accessibility_description` (plain-language clarification of what the destructive action does — e.g., "Quit the application without saving" for Close File). The description is mandatory because Case File register button labels ("Close File", "Return to Registry", "Re-Brief") are bureaucratic-register and AT users benefit from the plain-language safety net.
7. **Keyboard activation**: Enter / Space when focused. Single-press only — no hold-to-confirm. The modal-scaffold pattern's confirm gate (default focus on safe button, explicit Tab to destructive button) is the friction layer; the button itself activates immediately.
8. **No color-only signaling**: destructive nature is conveyed by **fill color** (Ink Black) + **position** (left of safe button) + **label text** (action verb implies finality) + **focus indicator** (4 px BQA Blue border on focus). 4-signal redundancy ensures color-blind players can identify the destructive button.

**Pattern data flow**:

```
[Player presses destructive button]
         │
         ▼
[Fill snap-inverts (Parchment / Ink Black) for 1 frame]
[Rubber-stamp thud SFX queued on UI bus]
         │
         ▼
[Destructive action fires synchronously]
   (e.g., get_tree().quit() for Close File,
          change_scene_to_file() for Return to Registry,
          FailureRespawn.restart_from_checkpoint() for Re-Brief,
          LS.transition_to_section(NEW_GAME) for New-Game-Overwrite)
```

**When to Use**. ANY destructive-action confirm modal in the Case File register. The pattern is [CANONICAL] for the 4 sibling Case File modals and any future Case File register modal that includes a destructive choice.

**When NOT to Use**.

- Non-destructive Case File modals (e.g., a hypothetical informational dialog with only an "Acknowledge" button — no destructive action) — use the default safe-action styling instead.
- Modals OUTSIDE the Case File register (e.g., the photosensitivity boot-warning modal which is non-diegetic per its own carve-out — no Ink Black fill needed; standard ADR-0004 Theme button styling applies).
- Save grids or Load grids where destructive actions (e.g., Delete Save) might appear in the future — those would need their own pattern (e.g., `case-file-card-destructive-action`) since they're not a 2-button confirm modal.

**Accessibility notes**. The 4-signal redundancy (color + position + text + focus) is the load-bearing accessibility claim — it satisfies WCAG SC 1.4.1 (color-independence) without requiring color-blind variants of the Ink Black palette. Default focus on the safe button (per `modal-scaffold`) means motor-accessibility players who accidentally press Enter immediately on modal mount will trigger the safe path, not the destructive path. The mandatory `accessibility_description` provides plain-language clarification for cognitive accessibility.

**Reference**: `design/ux/quit-confirm.md` Section C.3 + Section C.4 ASCII Wireframe (default state + Tab-to-Close-File focus state) is the canonical visual reference. Sibling modals (`return-to-registry.md`, `re-brief-operation.md`, `new-game-overwrite.md`) inherit verbatim per [CANONICAL] flag.

---

#### `lectern-pause-card-modal`

**Category**: Modal & Dialog
**Pillar fit**: Pillar 5 (Period Authenticity) + Pillar 2 (Discovery Rewards Patience — load-bearing) + Standard-tier accessibility
**Owner of contract**: Document Overlay UI GDD §V.1 + §C.2 + this entry; cross-paired with `lectern-pause-register` (HUD & Notification — composite world-state register sister)
**Used In**: Document Overlay UI (sole instance at VS).
**Related**: `lectern-pause-register` (HUD & Notification) — the composite world-state register that surrounds this card. The two patterns always co-fire: that entry coordinates the world-state (sepia + audio duck + HUD hide + banter suppression); this entry specifies the readable card surface the player interacts with. Implementers must wire both — the register without the card has no UI; the card without the register has no Lectern Pause framing.

**Description**. The Parchment-on-sepia-dim card UI used by the Document Overlay. Sister to `lectern-pause-register` — the latter is the project-wide composite mode (sepia-dim + ducked music + suppressed banter + suppressed HUD + suspended alert-music) the world enters when the overlay opens; this pattern is the *card itself* (the visible UI surface the player reads). The card is hard-edged BQA Blue header + Parchment body + American Typewriter Bold/Regular, with no buttons and no on-card chrome other than an optional scrollbar; dismissal is exclusively via `ui_cancel`. Distinct from Case File `modal-scaffold` (which has buttons, an Ink Black destructive register, and a manila-folder shell on Pause Menu mount).

**Specification**.

1. **Mount**. The card is instantiated by Mission & Level Scripting per-section (NOT autoload registry-mounted) at `CanvasLayer 5`, between PPS sepia ColorRect (CanvasLayer 4) and HUD Core (CanvasLayer 6). Single-instance invariant per Document Overlay CR-3.
2. **Visual frame**. PanelContainer 960 × 680 px at 1080p reference (clamps to 800 px min wide); BQA Blue `#1B3A6B` 64 px header band; Parchment `#F2E8C8` body with 32 px T/B + 48 px L/R padding; Parchment continuation footer 30 px (or 44 px when scroll hint visible).
3. **Typography**. American Typewriter Bold 20 px Parchment for `TitleLabel`; American Typewriter Regular 16 px Ink Black on Parchment for body; American Typewriter Regular 12 px Ink Black for footer hints.
4. **No buttons**. The card has zero focusable secondary controls (FP-OV-9 — explicit prohibition on Close/Done/Mark-as-read buttons). Dismiss is `ui_cancel` only; focus trap consumes Tab/Shift+Tab via `tab-consume-non-focusable-modal`.
5. **Scroll behavior**. `ScrollContainer` with `vertical_scroll_mode = SCROLL_MODE_AUTO`; 4 px scrollbar on right edge when overflow detected. No smooth-scroll inertia (FP-OV-12). Scroll hint label ("SCROLL — ↑ ↓ / Right Stick") appears in footer only when overflow detected.
6. **Open/close transitions**. Card snaps to visible at frame 0 (no fade-in); sepia engages around it via the paired `lectern-pause-register`. On close: card snaps to invisible (Option B "snappy dismiss"); sepia disengages around the now-empty space. Reduced-motion: identical card behavior; sepia transitions use the register's reduced-motion variant (instant engage/disengage).
7. **AccessKit contract**. `accessibility_role = ROLE_DIALOG` on modal root; `heading` role on `TitleLabel`; `scroll_area` on `BodyScrollContainer`; assertive one-frame announce on mount via the register's contract (post-`grab_focus` on `TitleLabel`).
8. **Anchor-enforced absolutes**. No swipe-to-next, no zoom/pan, no auto-dismiss, no music swell, no typewriter character-reveal, no inline glossary links, no progress percentage, no in-overlay font controls. Per Document Overlay GDD §G.5 (10 anchor-enforced absolutes; mixed anchors — Pillar 5, Lectern Pause, photosensitivity floor, production-economics floor, platform-constraint floor).

**When to Use**. Single-document gameplay-time read with no decision required from the player; player needs posture to read; dismiss is the only verb.

**When NOT to Use**.

- Modals that require a player decision (Save-overwrite, Quit-Confirm, Re-Brief, New-Game-Overwrite) — use `modal-scaffold` (Case File register) instead.
- Mission Cards (briefing/closing/objective) — use `mission-card-hard-cut-entry` instead.
- Pause Menu / Settings / Save grid screens — use `pause-menu-folder-slide-in` ancestry.
- A "browse a list of documents" screen (post-VS Polish-or-later case-file archive per DC §E.12) — that's a list view, not a single-document read; would need its own pattern.
- Any new register that wants Parchment + American Typewriter without the sepia-dim composite — the card pattern is paired with `lectern-pause-register` and cannot be invoked standalone.

**Accessibility notes**. The card has only one focusable Control (`BodyScrollContainer` for keyboard scroll); Tab/Shift+Tab consumption is mandatory (`tab-consume-non-focusable-modal`) so AT users don't tab into hidden gameplay focus targets. Body content must be exposed to AccessKit as parsed plain text (BBCode-stripped) — pending Gate G verification per ADR-0004. Scroll hint and dismiss hint use 12 px American Typewriter on Parchment; contrast ratio ~13.5:1 (WCAG AAA). Title contrast on BQA Blue is ~7.2:1 (WCAG AAA).

**Reference**: `design/ux/document-overlay.md` is the canonical UX spec for this pattern; `design/gdd/document-overlay-ui.md` §V.1 is the design contract; `lectern-pause-register` (this catalog, HUD & Notification) is the paired world-state register.

---

### Cinematic & Card

#### `mission-card-hard-cut-entry`

**Category**: Cinematic & Card
**Pillar fit**: Pillar 1 (Comedy: Bass grammar) + Pillar 5 (Period authenticity)
**Owner of contract**: Cutscenes CR-CMC-19 + FP-CMC-1 + UI.3
**Used In**: Mission Briefing Card, Mission Closing Card, Per-Objective Opt-In Card.

**Description**. Mission Cards enter via hard cut — frame N renders the card fully formed; frame N-1 rendered the prior content. No fade-in, no scale-in, no paper-translate-in (the paper-translate-in animation belongs to objective cards' slide-in only, not their initial appearance), no typewriter character-reveal. The hard cut IS the visual register; it reads as 1960s film cuts (Bass title-sequence grammar — abrupt, confident, theatrical) rather than modern game UI's "ease-in everything" default. Players experience the card as a slide already in place when it appears, like a projector advancing one frame.

**Specification**.

1. **Entry**. The card root sets `visible = true` and `modulate.a = 1.0` in a single frame. No tween on `modulate`. No tween on `scale`. No tween on `position` (the card is centered or anchored from instantiation, not animated into place).
2. **Audio pairing**. Card entry is paired with a single-frame audio cue per Cutscenes A.4 (e.g., `mission_started` SFX = period radio static + 3-blink Morse on briefing card). The audio cue starts on the same frame as the visual hard-cut.
3. **Reduced-motion**. No effect — hard-cut entry is already vestibular-safe by design (Cutscenes CR-CMC-19). The reduced-motion branch is a no-op for this pattern.
4. **AccessKit announce**. On hard-cut entry, the card root grabs focus (`grab_focus()`) and `accessibility_live = LIVE_ASSERTIVE` triggers a one-shot announcement of `accessibility_name = tr(title_key)` followed by `accessibility_description = tr(body_key) + " " + tr(stamp_key)` in scripted order.
5. **Forbidden patterns** (FP-CMC-1, FP-V-CMC-9). No fade-in. No paper-translate-in on Briefing/Closing (Objective cards have a slide-in *after* hard-cut entry — different timing). No bloom/glow accent on entry. No camera shake.
6. **Letterbox interaction**. CT-05 letterbox is a separate pattern (`letterbox-slide-in`) that animates onto the cinematic, not onto Mission Cards. Mission Cards never share a frame with letterbox.

**When to Use**. Every Mission Card entrance — Briefing (mission start), Closing (mission end), Objective (mid-mission objective updates).

**When NOT to Use**.

- Cinematic CT-03/CT-04/CT-05 — cinematics are not Mission Cards; their entry pattern is per-cinematic (CT-05 uses `letterbox-slide-in` after a 0-frame composition setup).
- Document Overlay — uses `lectern-pause-register` instead, which has a sepia-dim transition.
- Modal dialogs — use `modal-scaffold` instead, which has a 200 ms scrim fade.

**Accessibility notes**. Hard-cut entry is the most accessibility-friendly entry option in this category — no motion to potentially trigger vestibular issues. The announce-on-grab-focus contract ensures screen-reader players learn of the card immediately. The single-frame audio pairing must not exceed photosensitivity flash thresholds (Cutscenes audit committed in accessibility-requirements.md).

---

#### `silent-drop-dismiss-gate`

**Category**: Cinematic & Card
**Pillar fit**: Pillar 5 (no visible affordance — FP-CMC-3)
**Owner of contract**: Cutscenes FP-CMC-3 + G.1 (gate durations) + UI.3 dismiss-gate-open announcement
**Used In**: Mission Briefing Card (4.0 s), Mission Closing Card (5.0 s), Per-Objective Opt-In Card (3.0 s).

**Description**. Mission Cards reject the `cutscene_dismiss` action for the first N seconds of their on-screen lifetime, where N is the per-card dismiss-gate duration. During the gate, no visible affordance signals "you cannot dismiss yet" — no progress bar, no greyed-out skip button, no "Press any key to continue" prompt, no animated countdown. The gate IS the UX. After the gate elapses, `cutscene_dismiss` is honored silently — the player presses Esc/B and the card disappears with no acknowledgment text or sound. Players who read at typical pace finish reading just as the gate opens; players who read slower can take any extra time they need; players who try to dismiss immediately learn nothing happens and read the card.

The pattern relies on a strict Pillar 5 absolute (FP-CMC-3): no visible affordance, ever. The accessibility relaxation is a screen-reader-channel announcement at gate-open (per UI.3) — invisible to sighted players, audible to screen-reader users, satisfying WCAG SC 4.1.3 without violating FP-CMC-3.

**Specification**.

1. **Gate duration** (locked per card type, tunable within range).
   - Briefing card: `cutscenes_dismiss_gate_briefing_s = 4.0` (range [3.0, 5.0]).
   - Closing card: `cutscenes_dismiss_gate_closing_s = 5.0` (range [4.0, 8.0] — closing card seeds the next mission cliffhanger and is read more deliberately).
   - Objective card: `cutscenes_dismiss_gate_objective_s = 3.0` (range [2.0, 4.0]).
2. **Implementation**. On card open, start a SceneTreeTimer with the gate duration; set `_dismiss_gate_active = true`. The `cutscene_dismiss` handler's first guard is `if _dismiss_gate_active: return` (silent drop). On timer `timeout`, set `_dismiss_gate_active = false`.
3. **No visible affordance during gate** (FP-CMC-3). Forbidden: progress bars, countdown numbers, greyed-out skip text, pulsing button outline, "Press B" hints, animated indicator of any kind.
4. **Silent dismiss** (after gate). When `cutscene_dismiss` fires after gate-open, the card disappears immediately (one frame) without acknowledgment audio or visual confirmation.
5. **Accessibility relaxation — screen reader gate-open announce** (UI.3 BLOCKING). On `timeout`, set `accessibility_description += " — ready to dismiss"` (then revert one frame later) OR use AccessKit's queued-announcement API to fire `LIVE_POLITE` channel announce. Sighted players see no change; screen-reader players hear gate-open.
6. **Adaptive controller relaxation** (`cutscenes_auto_dismiss_timeout_s` Settings, default `0` / disabled). When > 0, the card auto-dismisses N seconds after gate-open. This protects adaptive-controller players who cannot produce default `cutscene_dismiss` (Esc / B). The auto-dismiss is INVISIBLE per FP-CMC-3 — no visible countdown.
7. **Stage-Manager carve-out interaction**. When `accessibility_allow_cinematic_skip = true` (Cutscenes §C.2.2), the gate is bypassed entirely — `cutscene_dismiss` honored at any time. This is a separate pattern (`stage-manager-carve-out`) layered on top.
8. **Pause Menu interaction**. Pause is BLOCKED during cinematic context; the gate does not interact with pause. The `text_summary_of_cinematic` setting + the Stage-Manager skip are the accessibility paths for the pause-blocked-during-cinematic restriction.

**When to Use**. Mission Cards. The pattern is specific to the dossier-register card surface; cinematics CT-03/04/05 use a different dismiss model (no first-watch skip, governed by Stage-Manager carve-out alone).

**When NOT to Use**.

- Cinematics — they don't have a dismiss-gate; their dismissal is governed by Stage-Manager carve-out (skip-or-not) only.
- Modal dialogs — `modal-scaffold` allows immediate dismissal via Cancel; no gate.
- Document Overlay — Lectern Pause has no gate; player closes when they're done reading.

**Accessibility notes**. The screen-reader gate-open announce (Spec rule 5) is BLOCKING per Cutscenes UI.3 — without it, blind/low-vision players have no way to know the gate has opened. The auto-dismiss Settings (rule 6) is also project-elevated above Standard tier for adaptive-controller players. Both relaxations preserve FP-CMC-3 by being invisible to sighted players.

---

#### `letterbox-slide-in`

**Category**: Cinematic & Card
**Pillar fit**: Pillar 1 (cinematic composition) + Pillar 4 (CT-05 location climax)
**Owner of contract**: Cutscenes CT-05 §A.4 + CR-CMC-18 / FP-V-CMC-9 (2.35:1 letterbox ONLY on CT-05)
**Used In**: Cutscenes CT-05 (bomb-disarm climax). NOT used in CT-03, CT-04, Mission Cards, or any other surface.

**Description**. 12-frame letterbox bar slide-in on the CT-05 climax. Top and bottom black bars (`ColorRect` on CanvasLayer 10) animate from off-screen to their 2.35:1 framing position, locking the cinematic into widescreen aspect for the climactic bomb-disarm sequence. The animation is exactly 12 frames at 60 fps (200 ms), Tween eased `EASE_OUT`. Op-art accent ring on sub-CanvasLayer 11 (`TextureRect`) appears once letterbox is locked. The letterbox is the *only* place 2.35:1 framing appears in the project (CR-CMC-18) — every other surface is full-frame.

**Specification**.

1. **Frame count**. 12 frames at 60 fps target framerate (200 ms). Locked. Tween uses `Tween.TRANS_QUART` + `Tween.EASE_OUT`.
2. **Bar geometry**. Top and bottom `ColorRect` nodes, full-width, height = `(viewport_height - viewport_height / 2.35) / 2`. Initial position: `position.y` = `-bar_height` (top) / `viewport_height` (bottom). Final position: `position.y = 0` (top) / `viewport_height - bar_height` (bottom).
3. **Color**. Ink Black `#0F0F0F` (Art Bible §3 palette). No outline; no animation overlay.
4. **CanvasLayer**. Letterbox bars on CanvasLayer 10 (cutscenes layer). Op-art ring on CanvasLayer 11 (sub-layer, CT-05 only per Cutscenes §C `cutscenes_op_art_canvas_layer` LOCKED).
5. **Reduced-motion path** (per `reduced-motion-conditional-branch`). When `Settings.reduced_motion = true`, the slide-in is replaced by a hard-cut variant — bars appear at final position in one frame. No animation. Vestibular-safe.
6. **Audio pairing**. Slide-in is paired with a Hammond F-minor 2nd inversion bass note (~65 Hz, C2) per Cutscenes A.4 audio-director correction. The note begins on frame 1 of the slide-in.
7. **AccessKit treatment**. The CanvasLayer root has `accessibility_role = ROLE_REGION` + `accessibility_live = LIVE_POLITE`. Caption Labels (per `scripted-sfx-caption`) inherit polite live region.
8. **Slide-out**. Closing CT-05 reverses the slide-in over 12 frames before `fade-to-black-close` begins. Reduced-motion path is hard-cut out.

**When to Use**. CT-05 only. The 2.35:1 framing is reserved for the bomb-disarm climax to give it visual singularity (Pillar 4 — Iconic Locations).

**When NOT to Use**.

- CT-03 (PHANTOM intro), CT-04 (HANDLER VO check-in), Mission Cards, Document Overlay — none use letterbox (CR-CMC-18, FP-V-CMC-9).
- Reduced-motion mode — substituted by hard-cut variant per Spec rule 5.
- Future cinematics outside the MVP — adding letterbox to a Tier 2 (Rome) cinematic would dilute the CT-05 singularity; requires Pillar 4 + Cutscenes ADR amendment.

**Accessibility notes**. Reduced-motion path (Spec rule 5) is BLOCKING. The slide-in's animation is fast (200 ms) and small-amplitude (~270 px on a 1080p frame), within standard vestibular safety bounds, but the conditional branch is mandatory regardless. The 2.35:1 framing reduces the active subtitle area; the `scripted-cinematic-caption` pattern positions captions within the active letterbox image area (817 px on CT-05) per accessibility-requirements.md.

---

#### `fade-to-black-close`

**Category**: Cinematic & Card
**Pillar fit**: Pillar 1 (cinematic composition)
**Owner of contract**: Cutscenes CT-05 closing + Closing Card sequence + Post-Process Stack `enable_fade_to_black()` API
**Used In**: Closing card / mission-end transition, CT-05 close, future cinematic exits.

**Description**. A 24-frame (400 ms at 60 fps) fade-to-black overlay on cinematic exit, paired with audio fade. The fade is owned by Post-Process Stack via the `enable_fade_to_black()` API; the cinematic system requests the fade via signal. Black is full opacity (`#000000`, alpha 1.0) at frame 24; before frame 1, no overlay is drawn. The fade communicates "this scene is closing"; the next frame after black is typically the next gameplay state or a respawn / load checkpoint.

**Specification**.

1. **Frame count**. 24 frames at 60 fps (400 ms). Locked per Cutscenes G.1.
2. **API**. Cinematic system calls `PostProcessStack.enable_fade_to_black(duration_s = 0.4)`; PPS owns the shader and the timing. Cinematic does NOT manipulate the shader directly.
3. **Audio pairing**. Audio bus (Music + SFX) fades to silence over the same 400 ms via AudioManager `fade_buses_to_silence(duration_s = 0.4)`. Voice bus (HANDLER VO) follows the same fade unless a final line is mid-render — in which case the fade waits for line end (Cutscenes A.4 audio-director rule).
4. **Hold-at-black**. After the 400 ms fade reaches full opacity, the screen holds at black for a per-cinematic hold time (typically 0.5–1.0 s) before the next state begins. Hold time is owned by the calling cinematic, not this pattern.
5. **Reduced-motion path**. No change — fade-to-black is vestibular-safe by design (no motion, only opacity ramp). Conditional branch is a no-op.
6. **AccessKit treatment**. The fade is non-interactive; it does not need an AccessKit role. The hold-at-black period is a good moment for a polite live-region announce of the next state (e.g., "Mission ended. Returning to Main Menu") — owned by the next state, not this pattern.
7. **Skip behavior**. When Stage-Manager carve-out is active and the player skips the cinematic, the fade-to-black still plays (it is the transition, not part of the cinematic). The skip lands at frame 1 of the fade.

**When to Use**. Every cinematic exit that transitions out of the cinematic register entirely (CT-05 close → mission-end). Also used for mission-end after closing card.

**When NOT to Use**.

- Inter-section transitions during gameplay — Level Streaming uses its own 2-frame hard-cut (Failure & Respawn ruling 2026-04-21, supersedes prior 0.3 s dissolve).
- Pause Menu close — uses `modal-scaffold` 200 ms fade.
- Document Overlay close — uses sepia-dim reverse, not fade-to-black.

**Accessibility notes**. The fade is photosensitivity-safe (no flash, monotonic opacity ramp). For players with cognitive accessibility needs, the hold-at-black gives a cleaner narrative break than an instant cut would.

---

#### `per-objective-opt-in-card`

**Category**: Cinematic & Card
**Pillar fit**: Pillar 5 (narrative substitute for objective markers — Pillar-5 forbidden pattern)
**Owner of contract**: Cutscenes Per-Objective Opt-In Card spec + UI.3 (`accessibility_role = ROLE_STATUS`)
**Used In**: Mid-mission objective updates triggered by Mission & Level Scripting (e.g., new objective unlocked, prior objective complete with narrative beat).

**Description**. A 720 × 200 px card slides in from screen edge to deliver an objective update without interrupting gameplay. Unlike Briefing/Closing cards, this one is **non-modal** — it does NOT push `InputContext.CUTSCENE`; gameplay continues; the card overlays at CanvasLayer 10 but does not block input. After the dismiss-gate elapses (3.0 s), the card slides out automatically — `cutscene_dismiss` can dismiss it earlier (after gate-open) but is not required. The card is the project's narrative substitute for the modern map waypoint marker, which Pillar 5 forbids.

**Specification**.

1. **Geometry**. 720 × 200 px, anchored to screen edge per UX spec (likely top-right or bottom-center; per-screen UX spec owns final position). Slides in over 12 frames; slides out over 12 frames; reduced-motion replaces both with hard-cut.
2. **Non-modal**. No `InputContext` push. Gameplay handlers continue to fire. HUD does NOT auto-hide (per `hud-auto-hide-on-context-leave` — context is still GAMEPLAY).
3. **Dismiss-gate**. 3.0 s gate per `silent-drop-dismiss-gate` (objective card duration). After gate-open, `cutscene_dismiss` slides the card out manually; otherwise it slides out at gate-open + auto-display-time.
4. **AccessKit contract**. `accessibility_role = ROLE_STATUS` (NOT `ROLE_DIALOG` — non-modal status). `accessibility_live = LIVE_POLITE` (does not interrupt gameplay focus). No focus grab — player retains gameplay focus.
5. **Stamp**. "OBJECTIVE" stamp in Ink Black on Parchment, rotated -5° per Cutscenes V.1 + Art Bible.
6. **Forbidden patterns**. No map marker companion (Pillar 5). No mini-map ping. No directional arrow. The card describes WHAT to do narratively; it does not say WHERE.
7. **Trigger**. Mission & Level Scripting fires `objective_unlocked(objective_id)`; Cutscenes subscribes and instantiates the card. Subsequent `objective_completed` may trigger a closing variant of this card (if the objective is narrative-significant).

**When to Use**. Mid-mission objective updates that warrant a narrative beat (new objective unlocked, prior objective complete with story implication).

**When NOT to Use**.

- Mission start / end — those are Briefing / Closing cards (`mission-card-hard-cut-entry` + modal CUTSCENE context).
- Tutorial prompts — use `prompt-strip-lifecycle` (HUD prompt-strip widget, persistent).
- Status notifications (document collected, save success) — use `hud-state-notification` instead.
- Routine objective ticks (every kill, every collected) — would clutter; reserve cards for narrative-significant updates only.

**Accessibility notes**. `LIVE_POLITE` (not assertive) is the right channel — the card is informational, not urgent. Screen-reader players hear it without losing gameplay focus. Reduced-motion replaces both slide-in and slide-out with hard-cut.

---

### HUD & Notification

#### `lectern-pause-register`

**Category**: HUD & Notification
**Pillar fit**: Pillar 1 (theatre-mode refusal) + Pillar 2 (reading rewards patience) + Pillar 3 (theatre register)
**Owner of contract**: Document Overlay UI §A.3 / §C.4 (open lifecycle) + Audio §Concurrency rule 6 + HUD Core CR-22 (Tween.kill on context leave) + D&S CR-DS-4 (banter suppression) + Post-Process Stack `enable_sepia_dim()` API
**Used In**: Document Overlay UI (sole instance). The pattern is named because it's the project's "suspended parenthesis" register — a complete interruption of gameplay where the game world dims into a backdrop and the document is the entire experience.
**Related**: `lectern-pause-card-modal` (Modal & Dialog) — the *card-UI surface* that this register surrounds. The two patterns always co-fire: this entry coordinates the world-state (sepia + audio duck + HUD hide + banter suppression); the card-modal entry specifies the readable card the player interacts with. Implementers must wire both — the register without the card has no UI; the card without the register has no Lectern Pause framing.

**Description**. When Document Overlay opens, six systems coordinate to produce a single register: Post-Process Stack applies sepia-dim shader (0.5 s ease-in-out); AudioManager ducks music + suspends alert-music transitions + suppresses banter; HUD Core hides all widgets via `Tween.kill` on context leave; D&S subtitle system self-suppresses; Cutscenes does not fire (CUTSCENE context is incompatible with DOCUMENT_OVERLAY); InputContext pushes DOCUMENT_OVERLAY. The result is a "Lectern Pause" — the world is still running but visually receded; the document is the only thing the player can interact with. On close, the reverse happens; if the world changed during reading (e.g., a guard spotted Eve), the change applies on the close frame as the audible cue.

**Specification**.

1. **Trigger**. Player calls `DocumentOverlay.open(document_id)`; the overlay's `open()` lifecycle (8 steps per Document Overlay UI §C.4) coordinates the register transition.
2. **Visual**. Post-Process Stack `enable_sepia_dim()` over 0.5 s `EASE_IN_OUT`. Reduced-motion: instant per `reduced-motion-conditional-branch` + Document Overlay §C.4 step 5.
3. **Audio**. Music ducks per Audio bus volumes (audio.md §Tuning Knobs). Alert-music transitions suspended (Audio Concurrency rule 6 — they continue to update dominant-state cache but do NOT tween; tween fires on close frame with cached state). Banter suppressed (D&S CR-DS-4). Stinger queue suspended.
4. **HUD**. All HUD widgets hide. `Tween.kill` runs on every active HUD tween to prevent residual cost during reading (HUD CR-22). Per `hud-auto-hide-on-context-leave`.
5. **InputContext**. DOCUMENT_OVERLAY pushed on open; popped on close. Save/Quicksave silently dropped during context (Save/Load CR-6).
6. **Close behavior**. On close, register reverses: sepia-dim disable + music tween fires (with cached dominant-state if it changed during reading) + HUD widgets re-show + banter resumes + InputContext pops.
7. **Edge case — alert state changed during reading**. Music transitions to `*_alarmed` immediately on close frame; no grace period. The overlay close itself is the audible cue that the world has changed (Audio §Concurrency rule 6 edge case).
8. **No Lectern Pause without overlay**. The register is always paired with Document Overlay. No other system may invoke sepia-dim + ducked music + suppressed HUD as a "Lectern Pause" — that would dilute the document register. (If a future system needs a similar register, name it differently and document the overlap.)

**When to Use**. Document Overlay only.

**When NOT to Use**.

- Cutscenes — use Cutscenes' own composite (CUTSCENE context + Mission Card hard-cut + letterbox-on-CT-05).
- Modal dialogs — use `modal-scaffold`.
- Pause Menu — use `pause-menu-folder-slide-in`. Pause is a different register (manila folder, not lectern).

**Accessibility notes**. Subtitle suppression during DOCUMENT_OVERLAY is mandatory (D&S §F.3) — without it, banter subtitles bleed through the duck and break Lectern Pause. The reduced-motion path replaces sepia-dim transition with instant; the underlying dim-state is unchanged.

---

#### `prompt-strip-lifecycle`

**Category**: HUD & Notification
**Pillar fit**: Pillar 5 (narrative objective text, no map markers)
**Owner of contract**: HUD Core prompt-strip Label widget + Mission & Level Scripting trigger contract + D&S Plaza tutorial 5-line set
**Used In**: HUD Core active-objective display, Mission & Level Scripting first-encounter prompts, D&S Plaza MVP-Day-1 tutorial (5 lines).

**Description**. A persistent HUD widget displaying the active objective in narrative prose (not "go to X marker") and first-encounter tutorial prompts (e.g., "Press F to chloroform a guard from behind"). The strip is small, dossier-register, located at HUD Core's designated anchor (per HUD Core §V — likely top-center or bottom-strip). It persists until acknowledged or until the underlying state changes (objective complete → next objective; tutorial line acknowledged or implicitly satisfied).

**Specification**.

1. **Widget**. A Label or RichTextLabel inside HUD Core's CanvasLayer; uses FontRegistry scale-aware font (18 px floor per HUD CR-19).
2. **Trigger**. MLS or system fires a signal (e.g., `objective_started(objective_id)`, `tutorial_prompt_show(prompt_key)`) → HUD Core subscribes and updates the strip text.
3. **Persistence**. The strip stays visible until: (a) the underlying state ends (objective complete, tutorial implicitly satisfied — e.g., player chloroforms a guard and the prompt was about chloroform); (b) the player acknowledges via a designated input (typically pressing the action the prompt describes); (c) a higher-priority prompt replaces it (priority ordering owned by HUD Core).
4. **No silent-drop**. The strip does not auto-fade or auto-dismiss after a time. It persists. (Notifications are different — those are `hud-state-notification`.)
5. **Auto-hide on context**. Hides via `hud-auto-hide-on-context-leave` when InputContext is not GAMEPLAY. Resumes when context returns.
6. **Locale**. Text via `tr(prompt_key)`. Re-resolves on translation change per `accessibility-name-re-resolve`.
7. **AccessKit**. Strip Control sets `accessibility_role = ROLE_STATUS` + `accessibility_live = LIVE_POLITE`. Updates announce politely when text changes.
8. **No directional info**. The strip describes WHAT, not WHERE. "Find the bomb" is allowed; "Bomb is 47m east, third floor" is forbidden (Pillar 5).

**When to Use**. Active objective display, first-encounter prompts (tutorial), persistent gameplay hints that wait for player action.

**When NOT to Use**.

- Transient notifications (document picked up, save complete) — use `hud-state-notification` (auto-fade).
- Narrative-significant objective updates — use `per-objective-opt-in-card` (mid-mission cinematic beat).
- Modal interruptions — use `modal-scaffold`.

**Accessibility notes**. The polite live-region announce ensures screen readers receive updates without interrupting gameplay focus. The 18 px floor (per HUD CR-19) satisfies Standard tier text-size requirements.

---

#### `hud-state-notification`

**Category**: HUD & Notification
**Pillar fit**: Pillar 5 (margin-note dossier register)
**Owner of contract**: HUD State Signaling §C (state machine + margin-note Label widget)
**Used In**: MEMO_NOTIFICATION (document picked up), SAVE_FAILED (autosave failure), alert-state HoH/deaf cue (paired with `hoh-deaf-alert-cue`), future ephemeral state changes.

**Description**. A margin-note Label widget at the HUD edge that surfaces transient state changes — a document was picked up, an autosave failed, an alert state escalated. The note appears, holds for a brief duration, then fades. Unlike `prompt-strip-lifecycle` (persistent until satisfied), notifications auto-resolve. Unlike `diegetic-confirmation-toast` (success-register card), notifications are register-aware: SAVE_FAILED uses PHANTOM-Red accent; MEMO_NOTIFICATION uses Parchment with BQA-Blue accent.

**Specification**.

1. **Widget**. A Label inside HUD Core's CanvasLayer at the margin-note anchor (per HUD State Signaling §V).
2. **State machine**. Notification states are enumerated by HUD State Signaling: MEMO_NOTIFICATION, SAVE_FAILED, ALERT_CUE_ESCALATION, etc. Each state has its own visual treatment (color accent + icon, no chrome) and duration.
3. **Lifecycle**. Trigger event → notification appears with hard-cut (no fade-in) → holds for state-specific duration (typically 2.0–3.5 s) → fades out over 200 ms. Reduced-motion: hard-cut out.
4. **Stacking**. If multiple notifications fire in close succession, they queue rather than overlap. Queue order is FIFO; overlapping is forbidden (would clutter the margin).
5. **Auto-hide on context**. Hides via `hud-auto-hide-on-context-leave`. If the InputContext leaves GAMEPLAY mid-notification, the notification is replayed when context returns (HUD State Signaling owns the replay queue).
6. **AccessKit**. `accessibility_role = ROLE_STATUS` + `accessibility_live = LIVE_POLITE`. The notification announces politely; SAVE_FAILED specifically announces with a higher-priority cue (still polite, not assertive — the modal `save-failed-advisory` is the assertive variant).
7. **Locale**. Text via `tr(notification_key)`.

**When to Use**. Transient state changes — document collected, autosave failed, alert state changed (paired with the alert-cue), future ephemeral notifications.

**When NOT to Use**.

- Modal-required failures — use `save-failed-advisory` for player-triggered saves.
- Persistent objective text — use `prompt-strip-lifecycle`.
- Success-register confirmations — use `diegetic-confirmation-toast`.
- Narrative beats — use `per-objective-opt-in-card`.

**Accessibility notes**. The polite live-region announce ensures audio parity for screen-reader players. SAVE_FAILED specifically must include the failure cause in the announce string (not just "save failed").

---

#### `hoh-deaf-alert-cue`

**Category**: HUD & Notification
**Pillar fit**: Accessibility + Pillar 3 (stealth as theatre — players must read the alert)
**Owner of contract**: HUD State Signaling REV-2026-04-26 D3 (HARD MVP DEP) + accessibility-requirements.md Auditory table
**Used In**: Stealth alert-state changes (unaware → suspicious → searching → combat).

**Description**. The visual companion to the alert-state stinger audio. Without this cue, deaf/HoH players lose the highest-stakes audio signal in the game (a guard noticed Eve) and cannot react. The cue is a margin-note `hud-state-notification` variant that shows the alert-state name + transition direction, paired with the existing AccessKit polite live-region announce. The cue is brief (3.0 s), fades cleanly, and uses Pillar-5-compatible dossier-register copy ("Searching" / "Alarmed" — not modern game-UI exclamation marks).

**Specification**.

1. **Trigger**. Stealth AI emits `alert_state_changed(actor, prior, current)`; HUD State Signaling subscribes and routes to the alert-cue handler when the state escalates (NOT on de-escalation).
2. **Display**. Margin-note Label per `hud-state-notification` mechanics. Text reads e.g., "[Guard] alerted" or "[Guard] searching". Color: PHANTOM Red `#C8102E` accent on the state name (NOT color-only — the text + change in baseline indicates the cue).
3. **Duration**. 3.0 s hold + 200 ms fade-out. Reduced-motion: hard-cut out.
4. **AccessKit**. Polite live-region announce ("[Guard] alerted") in addition to the visual cue. Both fire on the same frame.
5. **De-escalation**. When alert-state de-escalates (player slips back into shadow, guard returns to patrol), no cue fires — the absence of the cue is the signal. (De-escalation is slow over seconds; players notice via music ducking back to calm.)
6. **Pairing with audio stinger**. The cue does not replace the audio stinger — both fire. Hearing players hear the stinger and may glance at the cue; deaf/HoH players read the cue and infer the stinger.
7. **Pillar-5 register**. Copy uses dossier-register text. Forbidden: exclamation marks "[!]" (modern game UI), arrows pointing at the guard, mini-map highlight.

**When to Use**. Every stealth alert-state escalation. The pattern fires per actor — if 3 guards alert simultaneously, the cue fires for the dominant actor (HUD State Signaling owns dominant-actor selection).

**When NOT to Use**.

- De-escalation events (Spec rule 5).
- Civilian panic — civilians have their own notification path; alert-cue is for stealth-AI-perceived player.
- Cutscene-driven alert state changes — Cutscenes owns the cinematic register; HUD is hidden.

**Accessibility notes**. This pattern IS the accessibility commitment for the auditory alert-state stinger. Without it, the highest-stakes signal in the game is audio-only. HARD MVP DEP per HSS REV-2026-04-26 D3.

---

#### `critical-state-pulse`

**Category**: HUD & Notification
**Pillar fit**: Accessibility (color-independent) + Pillar 3
**Owner of contract**: HUD Core F.5 (critical-state pulse) + Audio CR-12 (clock-tick pairing)
**Used In**: HUD Core health bar at low HP. Future: any resource crossing a critical threshold (e.g., low ammo on a key weapon, if introduced post-MVP).

**Description**. When a resource (HP) crosses a critical threshold, the HUD pulses three signals in concert: visual (the resource value flashes; the bar pulses with a non-color-only treatment — outline thickening or scale wobble), numeric (the value is shown, not just a color-coded bar), and audio (a clock-tick ramps in via Audio bus). Color (red ramp) is NOT the only signal — every aspect has a non-color backup so colorblind players don't miss the threshold.

**Specification**.

1. **Threshold**. Per-resource. HP critical at 25% (HUD Core); future resources to define their own.
2. **Visual signals** (non-color-only).
   - Numeric value displayed (not just bar fill).
   - Bar outline thickens or pulses (not color shift alone).
   - Optional: scale wobble at 5% amplitude per pulse cycle (vestibular-safe).
3. **Audio signal**. AudioManager rates a clock-tick on the Music bus per Audio CR-12. Tick rate increases as HP decreases (linear ramp from 0.5 Hz at threshold to 2.0 Hz at near-death).
4. **Color**. Red ramp (`#C8102E` PHANTOM Red at threshold) for the bar fill; numeric value remains Ink Black on Parchment (legible regardless of bar fill).
5. **`clock_tick_enabled` opt-out** (`accessibility-opt-in-toggle`). Settings opt-out for the audio clock-tick — some players find it stress-inducing. Visual pulse continues regardless.
6. **De-escalation**. When HP rises back above threshold, the pulse cleanly cuts (no fade-out). Audio clock-tick stops.
7. **Reduced-motion**. Disables scale wobble (Spec rule 2c). Bar outline thickening + numeric value continue. Audio clock-tick continues unless opted out.

**When to Use**. HP near death. Future critical resources (ammo, gadget charges) only if Pillar 3 (Stealth as Theatre) supports the addition.

**When NOT to Use**.

- Non-critical state changes — use `hud-state-notification`.
- Ambient state (full HP, normal stealth) — no pulse.
- Combat tutorial — combat is not where this pattern teaches; the tutorial introduces it via `prompt-strip-lifecycle`.

**Accessibility notes**. The numeric backup (Spec rule 2a) satisfies WCAG SC 1.4.1 (Use of Color). The clock-tick opt-out (Spec rule 5) satisfies cognitive-accessibility — some players cannot tolerate ticking audio under stress.

---

#### `diegetic-confirmation-toast`

**Category**: HUD & Notification
**Pillar fit**: Pillar 5 (dossier register, non-intrusive)
**Owner of contract**: HUD Core Quicksave dossier-register confirmation toast + Input AC-INPUT-10.1 (forward dep on HUD Core)
**Used In**: Quicksave success, Quickload success, future ephemeral confirmations (NOT failures — those are `save-failed-advisory` or `hud-state-notification` SAVE_FAILED).

**Description**. A small, ephemeral, bottom-right card that appears for ~1.5 s when a non-blocking success event fires (Quicksave wrote successfully, Quickload restored). The card is dossier-register: Parchment background, Ink Black text, BQA-Blue accent stripe. It does NOT push InputContext, does not block input, does not auto-pause anything. It is the "non-modal success" register — the project's substitute for the modern AAA "saving icon spinning in the corner."

**Specification**.

1. **Geometry**. ~280 × 80 px card, anchored to bottom-right (HUD Core's designated toast anchor).
2. **Lifecycle**. Hard-cut entry → 1.4 s hold → 200 ms fade-out. Total visible time 1.6 s. Reduced-motion: hard-cut out (no fade).
3. **Non-modal**. No InputContext push. Gameplay continues. HUD does NOT auto-hide.
4. **Visual**. Parchment background + Ink Black text + BQA-Blue accent stripe (Art Bible). Text reads e.g., "Operation Quicksaved" or "Quickload — Plaza, 14:23".
5. **AccessKit**. `accessibility_role = ROLE_STATUS` + `accessibility_live = LIVE_POLITE`. Announces politely.
6. **No failure variant**. Failures route to `save-failed-advisory` (modal) or `hud-state-notification` SAVE_FAILED (margin-note). The toast is success-only.
7. **Locale**. Text via `tr()`.

**When to Use**. Quicksave / Quickload success. Future non-blocking success confirmations (e.g., "Settings saved" — though that one is silent today; documented for forward use).

**When NOT to Use**.

- Failures — see Spec rule 6.
- Modal acknowledgments — use `modal-scaffold`.
- Narrative beats — use `per-objective-opt-in-card`.
- Persistent state — use `prompt-strip-lifecycle`.

**Accessibility notes**. Polite live-region announce ensures audio parity. The 1.6 s total visible time is short — players who don't see it still have parity via audio.

---

#### `hud-auto-hide-on-context-leave`

**Category**: HUD & Notification
**Pillar fit**: Engineering primitive (perf budget) + Pillar 1 (theatre-mode refusal)
**Owner of contract**: HUD Core CR-10 (auto-hide) + CR-22 (Tween.kill on context leave)
**Used In**: HUD Core (all widgets), every system that pushes a non-GAMEPLAY context.

**Description**. When `InputContext` leaves `GAMEPLAY` (any push of MENU, MODAL, CUTSCENE, DOCUMENT_OVERLAY, etc.), HUD Core hides all widgets and kills any active tweens. When context returns to GAMEPLAY, widgets re-show. The pattern enforces two invariants: (1) the HUD does not bleed through cutscenes or overlays (Pillar 1 — theatre mode is total), and (2) the HUD's tweens do not consume frame budget while invisible (engineering primitive — Tween.kill prevents residual cost).

**Specification**.

1. **Trigger**. HUD Core subscribes to `Events.ui_context_changed(prev, current)`. On `current != GAMEPLAY`: hide all widgets + Tween.kill on every active tween. On `prev != GAMEPLAY and current == GAMEPLAY`: re-show widgets.
2. **Implementation**. Hide is `set_visible(false)` on the HUD CanvasLayer root. No fade. (Reduced-motion: same — hide is already instant.)
3. **Tween.kill mandatory** (CR-22). Every active HUD tween (damage_flash, critical-state-pulse, prompt-strip update animation) MUST be killed on context leave to prevent residual frame cost during overlay/cinematic.
4. **Notification queue replay**. If a `hud-state-notification` was mid-display when context left, HUD State Signaling queues the remaining display time and replays on context return.
5. **Per-widget exception**. None at MVP. (Future: a "always-visible" widget like a low-HP indicator might want to bleed through pause; document the carve-out then.)
6. **Pause Menu interaction**. Pause Menu pushes PAUSE context (or MENU) — HUD hides. The Pause Menu's own UI is the player-facing surface during pause; HUD widgets should not duplicate.

**When to Use**. Always — every UI surface that pushes a non-GAMEPLAY context relies on this rule. Owned by HUD Core; consumers do not opt-in or opt-out.

**When NOT to Use**.

- The pattern is universal; opt-out requires a documented per-widget carve-out (none at MVP).

**Accessibility notes**. The auto-hide does not affect screen-reader announce continuity — when the HUD hides, the underlying state still emits via the screen-reader channel of the new active surface (Pause Menu announces; HUD goes silent). The state machine is unaffected by visibility.

---

### Subtitle & Caption

#### `speaker-labeled-subtitle`

**Category**: Subtitle & Caption
**Pillar fit**: Pillar 1 (comedy lives in NPC voices) + Accessibility
**Owner of contract**: D&S §C (7-speaker convention) + D&S CR-DS-18 (speaker-label toggle) + dialogue-writer-brief.md
**Used In**: Dialogue & Subtitles (all 40-line per-section roster), Cutscenes CT-04 HANDLER VO. (Cutscenes CT-03/CT-05 use the SCRIPTED variants instead.)

**Description**. Every voiced line renders a subtitle prefixed with `[SPEAKER]:` from the project's 7-category convention (`GUARD`, `CLERK`, `LT.MOREAU`, `VISITOR`, `STAFF`, `HANDLER`, `STERLING`). The label tells the player WHO is speaking — critical because the comedy lives in distinguishable NPC voices (a stern Lt. Moreau line lands differently than a bored Clerk line) and because the player's spatial audio cue alone is not always enough to identify the speaker (especially when multiple NPCs are nearby). The label is part of the subtitle text, not a separate widget; localization treats `[SPEAKER]:` as a translatable token.

**Specification**.

1. **Speaker categories** (locked at 7). `GUARD`, `CLERK`, `LT.MOREAU`, `VISITOR`, `STAFF`, `HANDLER`, `STERLING`. No new category may be added without D&S GDD revision.
2. **Format**. `[SPEAKER]: line content`. The bracketed prefix is part of the localized string, not a separate Label.
3. **Default ON** (Settings VS commitment). Subtitles + speaker labels both default `true`. Industry default for subtitles is OFF; this project inverts because it's a dialogue-heavy register.
4. **Speaker-label toggle**. `subtitle_speaker_labels` Settings toggle (default `true`). When `false`, label is omitted; only line content shows. This is for players who find the label visually noisy; it does NOT affect AccessKit announce (screen reader still announces the speaker).
5. **Background scrim** (`subtitle_background` Settings, 3 modes). `none` / `scrim` / `opaque`. Default `scrim`. WCAG AAA contrast (7:1) when scrim or opaque.
6. **Text size** (`subtitle_size_scale` Settings). 32 px minimum at 1080p (Courier Prime per D&S V.1). Range 75%–150% scale.
7. **Suppression**. Subtitles suppress automatically during DOCUMENT_OVERLAY (D&S §F.3 self-suppression on `ui_context_changed`). Cutscenes CT-04 HANDLER VO uses this pattern; CT-05 uses SCRIPTED Cat 8 instead.
8. **Locale**. All subtitle text via `tr(line_id)`. Speaker label is part of the localized string, so French/German renderings can adapt the label syntax (e.g., `[GARDE] :` with French spacing convention).

**When to Use**. Every voiced line that fires during gameplay or in CT-04. The pattern is the project's universal subtitle grammar.

**When NOT to Use**.

- In-cinematic dialogue captions for CT-03/CT-05 — use `scripted-cinematic-caption` (Cat 7).
- Non-dialogue narrative SFX in CT-05 — use `scripted-sfx-caption` (Cat 8).
- System messages (save complete, error advisories) — those are HUD register, not dialogue.
- During Lectern Pause — suppressed per Spec rule 7.

**Accessibility notes**. Default-ON is itself an accessibility commitment that exceeds Standard tier baseline. Speaker labels are critical for cognitive-accessibility players who lose track of who's speaking when 2+ NPCs are nearby. The toggle (Spec rule 4) lets players who don't need labels disable them without sacrificing subtitles entirely.

---

#### `scripted-cinematic-caption`

**Category**: Subtitle & Caption
**Pillar fit**: Accessibility + Pillar 5 (period-faithful, no modern caption styling)
**Owner of contract**: D&S SCRIPTED Category 7 (in-cinematic dialogue) + Cutscenes CT-04 HANDLER VO line render path + UI.3 caption position rule
**Used In**: Cutscenes CT-04 HANDLER VO line. Future in-cinematic dialogue lines if added in Tier 2 cinematics.

**Description**. A specialized subtitle variant for in-cinematic dialogue. Unlike `speaker-labeled-subtitle` (which fires from gameplay banter), Cat 7 captions are MLS-triggered at scripted times within a cinematic, render within the active letterbox image area (when letterbox is present), and use the same Courier Prime + speaker-label convention but with cinematic-specific positioning constraints. The HANDLER VO line in CT-04 is the canonical instance.

**Specification**.

1. **Trigger**. Mission & Level Scripting fires `scripted_caption_trigger(scene_id, caption_key)` at scripted timecode within the cinematic. Cutscenes (NOT D&S) instantiates the Label.
2. **Position**. Within the active letterbox image area (CT-05: 817 px on 1080p). For non-letterboxed cinematics (CT-04), positioned at the same anchor as gameplay subtitles.
3. **Format**. Same `[SPEAKER]: line content` as `speaker-labeled-subtitle`. CT-04 uses `[HANDLER]`.
4. **Visual**. Inherits subtitle styling from D&S (Courier Prime, 32 px, scrim default). No additional cinematic chrome.
5. **Reduced-motion**. No effect on captions themselves; their entry is hard-cut, not animated.
6. **AccessKit**. Inherits D&S AccessKit treatment. The cinematic CanvasLayer root has `accessibility_live = LIVE_POLITE` per Cutscenes UI.3; caption announce inherits.
7. **Subtitle-toggle interaction**. Honors `subtitles_enabled` Settings. When subtitles are off, Cat 7 captions also do not render (consistent with player choice).

**When to Use**. In-cinematic dialogue lines. The pattern is narrow — only triggered in cinematics, not gameplay.

**When NOT to Use**.

- Gameplay banter — use `speaker-labeled-subtitle`.
- Non-dialogue cinematic SFX (device-tick, wire-cut) — use `scripted-sfx-caption` (Cat 8).
- Mission Card text — Mission Cards have their own AccessKit announce, not caption rendering.

**Accessibility notes**. Position-within-letterbox constraint (Spec rule 2) ensures captions don't render under the letterbox bars (which would be unreadable). Honoring `subtitles_enabled` (Spec rule 7) is mandatory — players who disabled subtitles must not have them re-enabled in cinematics.

---

#### `scripted-sfx-caption`

**Category**: Subtitle & Caption
**Pillar fit**: Accessibility (deaf/HoH narrative parity)
**Owner of contract**: D&S SCRIPTED Category 8 (non-dialogue narrative captions) + Cutscenes OQ-CMC-18 + accessibility-requirements.md Auditory table
**Used In**: Cutscenes CT-05 narrative-critical SFX — `tick_steady`, `tick_cessation`, `wire_cut`. Future narrative-critical SFX captions in Tier 2 cinematics if needed.

**Description**. Closed captions for narrative-critical non-dialogue SFX. The CT-05 climax depends on three audio events that carry narrative meaning a deaf/HoH player would otherwise miss: the steady device-tick (bomb is active — atmospheric stress), the wire-cut SFX (player executed disarm), and the tick-cessation (bomb disarmed — climactic confirmation). Without captions, the climactic narrative beat is audio-only. The captions render within the active letterbox image area, MLS-triggered, with bracketed sound-name copy (e.g., `[device ticks]`, `[wire snaps]`, `[device falls silent]`).

**Specification**.

1. **Trigger**. MLS fires `scripted_caption_trigger(scene_id, caption_key)` on the same frame as the SFX plays. Cutscenes instantiates the Label.
2. **Caption keys** (CT-05).
   - `cutscenes.caption.ct_05.tick_steady` → "[device ticks]" (renders for the duration of the steady-state tick, then fades).
   - `cutscenes.caption.ct_05.wire_cut` → "[wire snaps]" (single-fire on disarm action).
   - `cutscenes.caption.ct_05.tick_cessation` → "[device falls silent]" (single-fire on disarm complete).
3. **Position**. Within the active letterbox image area (CT-05: 817 px on 1080p). Same anchor as Cat 7 dialogue captions to avoid overlap (Cat 7 and Cat 8 do not share frame on CT-05).
4. **Format**. Bracketed lowercase sound description, no speaker label (these are not dialogue). Italic optional per per-screen UX spec.
5. **Visual**. Same Courier Prime + 32 px + scrim styling as `speaker-labeled-subtitle`.
6. **Subtitle-toggle interaction**. Honors `subtitles_enabled` Settings, same as Cat 7.
7. **AccessKit**. Inherits cinematic CanvasLayer's `LIVE_POLITE` channel (per Cutscenes UI.3 — caption Label nodes inherit polite live region).
8. **Locale**. Bracketed copy via `tr(caption_key)`. Translation must preserve the bracketed framing convention.

**When to Use**. Narrative-critical non-dialogue SFX where missing the cue would break narrative comprehension. The CT-05 trio is the canonical instance; future use requires Cutscenes audit (is the SFX truly narrative-critical, or is it atmospheric?).

**When NOT to Use**.

- Atmospheric SFX (room ambience, footsteps, gun shots) — covered by visual equivalents (HUD State Signaling alert-cue, footstep visuals when in stealth) per accessibility-requirements.md Gameplay-Critical SFX Audit.
- Dialogue — use Cat 7 or `speaker-labeled-subtitle`.
- Music cues (Hammond chord) — atmospheric, not narrative-critical (audit-confirmed).

**Accessibility notes**. This pattern IS the accessibility commitment for the CT-05 climactic narrative beat. Without it, deaf/HoH players experience the climax as a visual-only sequence that ends ambiguously (did the bomb stop ticking?). Closes accessibility-specialist Finding 4 (per accessibility-requirements.md row 104).

---

### Settings & Rebinding

#### `rebind-three-state-machine`

**Category**: Settings & Rebinding
**Pillar fit**: Standard-tier accessibility
**Owner of contract**: Settings & Accessibility CR-22 (binding-owner-of-record) + Input GDD §C.2.4 + Input AC-INPUT-4.x rebind ACs
**Used In**: Settings rebinding screen (Vertical Slice scope; gamepad-rebinding parity is post-MVP per technical-preferences.md).

**Description**. The rebinding flow is a three-state machine — `NORMAL_BROWSE → CAPTURING → CONFLICT_RESOLUTION → NORMAL_BROWSE`. NORMAL_BROWSE is the default: the player navigates the rebinding list, sees current bindings, and presses the rebind button on a row to begin. CAPTURING is the input-listening state: the next key/button pressed is captured as the new binding, with Esc as the cancel-out. If the captured event is already bound to another action, the machine transitions to CONFLICT_RESOLUTION, presenting the player with two choices: (a) refuse — return to NORMAL_BROWSE without changing the binding, or (b) offer-unbind — apply the new binding AND unbind the conflicting action (which becomes unbound and rebindable in NORMAL_BROWSE). The state machine prevents two bugs: silent duplicate bindings and "rebinding ate my Esc key."

**Specification**.

1. **States**. `NORMAL_BROWSE`, `CAPTURING`, `CONFLICT_RESOLUTION`. Owned by Settings panel; Input GDD provides the conflict-detection primitive (`InputMap.has_event(E)` per Input AC-INPUT-4.2a).
2. **InputContext**. NORMAL_BROWSE runs in `MENU` context (Settings panel). CAPTURING and CONFLICT_RESOLUTION push `SETTINGS_REBIND` (a sub-context) so the captured key isn't routed through Settings' own UI navigation handlers — otherwise pressing Down arrow would scroll the rebinding list AND get captured as a binding.
3. **CAPTURING transition** (NORMAL_BROWSE → CAPTURING). Player clicks/activates the rebind button on a row. UI updates to show "Press a key…" message. Push `SETTINGS_REBIND`.
4. **Capture**. The first non-Esc input event in CAPTURING is the candidate. Esc cancels — pop SETTINGS_REBIND, return to NORMAL_BROWSE without rebinding.
5. **Conflict check**. After capture, query `InputMap.has_event(captured)` for any other action. If yes → CONFLICT_RESOLUTION. If no → commit the rebind directly (NORMAL_BROWSE).
6. **CONFLICT_RESOLUTION**. Show modal-like inline state: "[E] is already bound to [Action B]. Rebind anyway and unbind [Action B], or cancel?" Two buttons (Rebind / Cancel). Per `dual-focus-dismiss`. Default focus: Cancel (safer default).
7. **Commit**. On Rebind: `InputMap.action_erase_events(target_action)` + `InputMap.action_add_event(target_action, captured)` + (if conflict) `InputMap.action_erase_events(conflict_action, captured_event)` + `Input.action_release(target_action)` (per `held-key-flush-after-rebind`).
8. **Persistence**. After commit, write `user://settings.cfg [controls]` per ADR-0003. Subsequent launches restore the rebinding (Input AC-INPUT-4.3 round-trip).
9. **Held-key flush** (per `held-key-flush-after-rebind`). MUST run on commit. Without it, the action's pressed-state lingers if the player held the prior key during rebind.
10. **Reset to defaults**. A "Reset bindings to default" button in NORMAL_BROWSE resets all rebindings; flush rule applies if any bindings change.

**When to Use**. Settings rebinding screen. The state machine is specific to in-game rebinding; Steam Input rebinding (system-level) is governed by Steam Input templates and is independent of this pattern.

**When NOT to Use**.

- System-level remapping (Steam Input controller templates) — handled by Steam, not the game.
- Quick rebind keyboard shortcuts (e.g., a debug overlay's hotkey) — those are dev-time, not player-facing.
- Action-by-action rebinding without conflict detection — silent-conflict is the bug this pattern prevents.

**Accessibility notes**. Esc cancel-out (Spec rule 4) is critical for accessibility: a player who accidentally clicks "rebind" must be able to back out without committing. The Cancel default in CONFLICT_RESOLUTION (Spec rule 6) follows the safer-default convention from `modal-scaffold`. Conflict-resolution AccessKit must be assertive — the player needs to hear about the conflict before acting.

---

#### `toggle-hold-alternative`

**Category**: Settings & Rebinding
**Pillar fit**: Standard-tier accessibility (motor)
**Owner of contract**: Settings & Accessibility CR-22 (Toggle-Sprint / Crouch / ADS Day-1 MVP) + accessibility-requirements.md Motor table
**Used In**: `sprint`, `crouch`, `ads`, `gadget_charge` (Settings Day-1 MVP). Future: any newly-added "hold [button] to [action]" input.

**Description**. Every "hold [button] to [action]" input in the project ships with a Settings-gated toggle alternative. The default is hold-mode (Pillar-3-aligned: stealth crouch is intentional, not a passive state); players who cannot sustain a hold (motor disability, hand fatigue) flip the toggle and the action becomes press-once-to-activate, press-again-to-deactivate. The pattern is mandatory for every sustained-hold input; introducing a new sustained-hold action without a toggle alternative is a defect.

**Specification**.

1. **Inputs covered at MVP**. `sprint`, `crouch`, `ads`, `gadget_charge`. Each has a corresponding Settings toggle (e.g., `toggle_sprint`).
2. **Default**. Toggle setting is `false` (hold mode). Pillar 3 prefers intentional, sustained inputs as the default.
3. **Toggle mode behavior**. First press fires the action's "begin" event; second press fires the action's "end" event. The action's pressed-state is sticky between presses.
4. **Hold mode behavior** (default). The action is pressed while the input is held; released when the input releases. Standard input semantics.
5. **Switch behavior**. Switching the Settings toggle while the action is currently active immediately resolves: in hold→toggle switch, the action stays active until the next press; in toggle→hold switch, the action releases on switch.
6. **Persistence**. `user://settings.cfg [accessibility]` per ADR-0003.
7. **No mid-action animation interruption**. Switching during a sprint must not interrupt the current animation cycle — the input layer changes; the player-character animation continues.
8. **Per-action future addition**. If a new sustained-hold action is added (e.g., `peek_lean`), it MUST add a corresponding `toggle_peek_lean` Setting at the same time. The pattern is mandatory.

**When to Use**. Every sustained-hold input. The pattern is universal; opt-out requires explicit Settings GDD revision.

**When NOT to Use**.

- Tap inputs (e.g., `interact`, `takedown`, `quicksave`) — no hold semantics, no toggle needed.
- Modifier inputs (e.g., `shift+key` chord — none in MVP, but if added, document the toggle pattern's interaction).
- System inputs (`pause`, `ui_cancel`) — no hold semantics.

**Accessibility notes**. This pattern IS the project's primary motor-accessibility commitment beyond Standard tier baseline. Hand-fatigue, repetitive-strain, one-handed-play, and many adaptive-controller setups depend on toggle alternatives. The default-hold (Spec rule 2) preserves Pillar 3's "intentional movement" register while honoring the player choice.

---

#### `accessibility-opt-in-toggle`

**Category**: Settings & Rebinding
**Pillar fit**: Accessibility + Pillar 5 (carve-out shape)
**Owner of contract**: Settings & Accessibility G.3 (Accessibility category) + `stage-manager-carve-out` pattern (this library)
**Used In**: All Settings → Accessibility toggles (see Settings & Accessibility GDD §G.3 for canonical list).

**Description**. The pattern shape for any Settings-gated accessibility opt-in. Each toggle has: a concrete default value (most are `false`, but subtitles default `true` per VS commitment); a clear label that names the trade-off rather than the technical implementation ("Allow skipping unwatched cinematics" not "cutscene_dismiss_gate_bypass"); persistence to `user://settings.cfg [accessibility]`; and a one-line description in the Settings panel that surfaces the trade-off (without moralizing). When the toggle relaxes a Pillar 5 absolute, it follows the additional rules of `stage-manager-carve-out`. This pattern's specification covers the universal toggle shape; the carve-out pattern adds Pillar-5-specific rules on top.

**Specification**.

1. **Default value** (per-toggle decision, but the project pattern is `false` unless an explicit VS commitment overrides — e.g., `subtitles_enabled = true` per Settings VS commitment).
2. **Label register**. Stage-Manager register — describes the trade-off in player-facing language. Example: "Allow skipping unwatched cinematics. The story still plays in the background while skipped." Forbidden: technical-jargon labels, moralizing copy ("we recommend keeping this on"), double-confirmation prompts.
3. **Persistence**. `user://settings.cfg [accessibility]` per ADR-0003. Survives game updates.
4. **Locale**. Label + description via `tr(setting_key)`. Re-resolves on translation change.
5. **AccessKit**. Toggle Control sets `accessibility_role = ROLE_CHECK_BOX` + `accessibility_name = tr(setting_key)` + `accessibility_description = tr(setting_description_key)`.
6. **Pillar 5 interaction**. If the toggle relaxes a Pillar 5 absolute, see `stage-manager-carve-out` for additional rules (anchored to specific FP- entry, paired fallback when applicable, no runtime prompt).
7. **No live preview**. Most toggles take effect on commit, not on hover/preview. (Exception: Settings sliders that need preview, like UI scale or subtitle size — those have their own pattern, not this one.)
8. **Group placement**. All accessibility toggles live under the Settings → Accessibility tab. Audio toggles (volume, mute) are NOT accessibility toggles — they live under Settings → Audio.

**When to Use**. Every Settings-gated accessibility option.

**When NOT to Use**.

- Game balance / difficulty settings — those are a different category (and the project does not commit to difficulty modes per accessibility-requirements.md).
- Cosmetic preferences (FOV, brightness, language) — those go under Settings → Display / Audio / Language, not Accessibility.
- Settings sliders (continuous values like `subtitle_size_scale`, `ui_scale`) — those use a slider pattern (separate; not in this library at MVP — flagged as a Gap).

**Accessibility notes**. The pattern itself is the floor for every accessibility option. Stage-Manager register copy (Spec rule 2) is mandatory — moralizing labels alienate players who depend on the toggle.

---

### Menu & Save

#### `save-load-grid`

**Category**: Menu & Save
**Pillar fit**: Pillar 5 (Operations Archive dossier register) + Accessibility
**Owner of contract**: Save/Load §UI Requirements + Menu System §C.2 (Operations Archive + File Dispatch)
**Used In**: Operations Archive (Load Game — 8-slot 2 × 4 grid; Slot 0 = Quicksave), File Dispatch (Save Game — 7-slot 2 × 3 + 1 grid).

**Description**. The Save and Load screens render save slots as a card grid with slot-card visual differentiation. Load is 8 slots (Slot 0 = Quicksave, Slots 1–7 = manual + autosave), Save is 7 slots (no Slot 0; the player can't manually overwrite Quicksave from Save). Each card shows: slot number, save timestamp, mission section name, mission elapsed time, and a thumbnail or icon. Slot 0 (Quicksave) is visually differentiated by an accent stripe + "QUICKSAVE" subtitle. Empty slots show "[ EMPTY ]" or "[ NEW SAVE ]" depending on the screen. Navigation: arrow keys + gamepad d-pad/stick + mouse click. AccessKit grid role (`ROLE_GRID`) for screen-reader navigation.

**Specification**.

1. **Layouts**.
   - **Load grid**: 8 slots in 2 rows × 4 columns. Slot 0 in the top-left position is the Quicksave slot, visually differentiated.
   - **Save grid**: 7 slots in 2 rows × 3 columns + 1 (last slot wraps to a third row's leftmost position). No Slot 0 — Quicksave is excluded from Save (it's only writable by F5).
2. **Card content**. Slot index + save timestamp (locale-aware) + mission section name (e.g., "Plaza" / "Eiffel — Restaurant level") + mission elapsed time + small thumbnail or icon. Empty slots: "[ EMPTY ]" (Save) or "[ NO DATA ]" (Load).
3. **Slot 0 differentiation** (Load grid only). BQA-Blue accent stripe along the left edge. "QUICKSAVE" subtitle below the slot number. Locked from manual overwrite — the slot is updated by F5 only.
4. **Navigation**.
   - Arrow keys / d-pad: cardinal navigation between cards.
   - Mouse click: focus + activate.
   - Activate (`ui_accept` / Enter / A): on Load → load this save; on Save → if empty, save here; if filled, open `Save-overwrite` modal.
   - Cancel (`ui_cancel` / Esc / B): pop SaveLoad screen, return to Pause Menu.
5. **AccessKit**. Grid container has `accessibility_role = ROLE_GRID`. Each card has `accessibility_role = ROLE_GRID_CELL` + `accessibility_name = tr("save_slot_card_label", {slot, timestamp, section, elapsed})`.
6. **Save overwrite confirm**. On Save activation of a filled slot, child modal opens (`modal-scaffold`) with "Overwrite save in slot N?" + Cancel/Overwrite buttons. Uses `dual-focus-dismiss` + `set-handled-before-pop`.
7. **Color-and-shape differentiation for save card states** (CR-25 + WCAG SC 1.4.1, VS scope). Filled vs empty cards differ by more than color — e.g., filled cards have content text, empty cards have placeholder framing.
8. **Reduced-motion**. Card hover / focus animations are 100 ms scale-in; reduced-motion = instant focus highlight.

**When to Use**. Operations Archive (Load Game), File Dispatch (Save Game). The grid is the canonical save-slot UI; not used elsewhere.

**When NOT to Use**.

- Settings categories (use tab/list layout, not grid).
- Document Collection archive (post-Polish, separate pattern).
- Quicksave success — that's `diegetic-confirmation-toast`, not a grid.

**Accessibility notes**. AccessKit grid role (Spec rule 5) is critical for screen-reader navigation; without it, the grid reads as flat list and the player loses spatial position. Color-and-shape differentiation (Spec rule 7) is WCAG SC 1.4.1 compliance — empty vs filled must read without color.

---

#### `pause-menu-folder-slide-in`

**Category**: Menu & Save
**Pillar fit**: Pillar 5 (period-authentic manila folder register)
**Owner of contract**: Menu System §C.2 (Pause Menu surface) + Art Bible (manila folder register)
**Used In**: Pause Menu only. Main Menu uses a different opening animation; Settings panel inherits from Pause Menu's animation chain.

**Description**. The Pause Menu enters as a manila folder sliding in from the screen edge — Pillar 5 register made literal. The folder slides in over 200 ms (12 frames at 60 fps), eased `EASE_OUT`. Inside the folder are the Pause Menu options: Continue / Save / Load / Settings / Re-Brief Operation (conditional) / Return to Registry / Quit to Desktop. The "Re-Brief Operation" option is conditionally visible based on whether the player has unlocked the briefing card for the current section. The folder slide-in is paired with a manila-paper-rustle SFX. Reduced-motion replaces the slide-in with a hard-cut paint of the folder.

**Specification**.

1. **Trigger**. Player presses `pause` (Esc / Start). Menu System pushes `InputContext.PAUSE`. Animation begins on the same frame.
2. **Animation**. Manila folder Control slides in from screen edge (likely left, per per-screen UX spec). Duration 200 ms (12 frames at 60 fps), Tween `EASE_OUT`.
3. **Audio pairing**. Manila-paper-rustle SFX (single-shot) on slide-in start. Volume per Audio bus.
4. **Reduced-motion**. Per `reduced-motion-conditional-branch`: hard-cut paint at final position, no slide. Audio cue still plays.
5. **Folder content**. Centered button stack inside the folder Control. Buttons: Continue / Save / Load / Settings / Re-Brief / Return to Registry / Quit. Re-Brief is hidden when the briefing card is not yet unlocked for the current section.
6. **Default focus**. Continue button (the safest, most-likely choice). Tab cycles within the folder.
7. **Slide-out**. On dismiss (player chooses Continue, presses Esc, etc.), folder slides back to screen edge over 200 ms. Reduced-motion = hard-cut out. InputContext pop on slide-out begin (not end), so input returns immediately.
8. **HUD interaction**. HUD auto-hides on PAUSE context push per `hud-auto-hide-on-context-leave`.

**When to Use**. Pause Menu only. The folder register is the Pause Menu's signature.

**When NOT to Use**.

- Main Menu — different surface, different opening animation per per-screen UX spec.
- Modal dialogs — use `modal-scaffold`.
- Settings panel — inherits the folder appearance for visual consistency, but Settings-specific layout owns the Settings tab structure (separate UX spec).

**Accessibility notes**. Reduced-motion (Spec rule 4) is mandatory. The slide-in is small-amplitude (~200 px on 1080p) and brief (200 ms), within vestibular safety bounds, but the conditional branch is required. AccessKit announce on open ("Pause Menu") via the folder Control's `accessibility_role = ROLE_DIALOG` + `accessibility_live = LIVE_ASSERTIVE`.

---

#### `sepia-death-sequence`

**Category**: Menu & Save
**Pillar fit**: Pillar 3 (theatre-not-punishment) + Pillar 5 (no red vignette — modern AAA convention)
**Owner of contract**: Player Character GDD death sequence + Failure & Respawn GDD §A (player fantasy: "house lights up between scenes")
**Used In**: Player death (single trigger; F&R routes to checkpoint or respawn screen).

**Description**. When the player dies, the camera pitches down 60° over 800 ms while translating to Y = 0.4 m (head on floor), simulating Eve falling. Concurrently, a sepia fade applies over 1.5 s (sepia-dim shader at full intensity). Audio cuts to silence after ~200 ms then fades to `*_calm` per Audio respawn-fade rules. After the 1.5 s sepia fade, a 2-frame hard-cut transitions to the Failure & Respawn screen (Level Streaming `FADE_OUT_FRAMES = 2` per F&R). No red vignette. No slow-motion replay. No "you died" text overlay during the death frame — the F&R screen owns the messaging. The whole sequence is 2.5 s and is intentional and load-bearing for the "house lights up between scenes" metaphor.

**Specification**.

1. **Camera animation**. Pitch -60° over 800 ms (Tween `EASE_IN`). Y position translates to 0.4 m (head on floor) over the same 800 ms.
2. **Sepia fade**. Post-Process Stack `enable_sepia_dim()` over 1.5 s `EASE_IN_OUT`. Reaches full intensity at 1.5 s.
3. **Audio**. Cut to silence over ~200 ms (Audio §respawn rules). After 200 ms, hold silence until F&R screen begins, then 2.0 s ease-in to `*_calm` per Audio `respawn_fade_in_s`.
4. **Hard-cut to F&R**. After 1.5 s sepia + camera animation, Level Streaming hard-cuts (2 frames at 60 fps = ~33 ms) to the F&R checkpoint scene.
5. **Forbidden patterns** (Pillar 5).
   - No red vignette (modern AAA convention).
   - No slow-motion (modern AAA convention).
   - No "YOU DIED" overlay text on the death frame (F&R screen owns messaging).
   - No camera shake (this is a death, not an action beat).
   - No bloom flash (bloom is project-wide disabled per Art Bible 8J).
6. **Reduced-motion**. Camera pitch animation is the only motion — vestibular impact is moderate (60° pitch). Reduced-motion path: skip the camera animation, hard-cut to head-on-floor pose, sepia fade still plays. Audio fade unchanged.
7. **Player input**. Suppressed on death-trigger frame (Player Character pushes `InputContext` via F&R-driven flow). Held inputs flush (player release flush).
8. **Hands outline**. Player Character GDD AC-9.3 — hands outline must remain visible during the sepia death sequence (verified test scene).

**When to Use**. Player death — the single trigger. The pattern is exclusive to this event.

**When NOT to Use**.

- Mission failure (timer expired, bomb detonated) — different framing; Mission & Level Scripting owns the failure cinematic which uses `fade-to-black-close` instead.
- NPC death — no special player-camera treatment; standard gameplay continues.
- Cinematic death scenes — Cutscenes own the cinematic register.

**Accessibility notes**. Reduced-motion path (Spec rule 6) is mandatory — 60° camera pitch is the most aggressive motion in the game and the most likely vestibular trigger. The `respawn_fade_in_s = 2.0 s` (Audio Tuning Knobs) is the result of a 2026-04-21 senior-director ruling that earlier 0.5 s ease-in read as cinema hard-cut and violated Pillar 3.

---

### Localization

#### `auto-translate-always`

**Category**: Localization
**Pillar fit**: Engineering primitive + i18n
**Owner of contract**: Localization Scaffold L129 + Menu System §UI-1
**Used In**: Every UI surface — Main Menu, Pause Menu, Settings, Save/Load, Document Overlay, Cutscenes, HUD, every modal.

**Description**. Every static UI Label sets `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. This makes Godot's translation system re-resolve the Label's text whenever the active locale changes, without requiring a scene rebuild or manual `tr()` call. The pattern is universal: any Label that displays player-facing text falls under this rule. Dynamic text (built via string interpolation, e.g., `"Slot %d - %s"` formatted at runtime) requires a different handling — the formatted string is computed via `tr()` per format-call, and re-resolution requires re-running the format call on locale change.

**Specification**.

1. **Default**. Every UI Label inherits or explicitly sets `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. The project Theme (`project_theme.tres`) inherits this default, so Labels using the project Theme inherit it.
2. **String source**. Label `text` is set to a translation key (e.g., `MAIN_MENU_CONTINUE`); Godot's locale system resolves the key to a localized string at render time.
3. **Dynamic text**. For interpolated strings (e.g., "Save Slot 3"), use `tr_n()` or format with `tr()` calls per locale change. The pattern requires re-running format on `NOTIFICATION_TRANSLATION_CHANGED` if the displayed string includes interpolated values.
4. **Locale switch**. The Settings Language tab triggers a locale change via `TranslationServer.set_locale()`. All Labels under `AUTO_TRANSLATE_MODE_ALWAYS` re-resolve automatically. AccessKit names re-resolve via `accessibility-name-re-resolve`.
5. **Static-only**. The pattern applies to static keys only. Runtime-generated content (player names, save timestamps, document body text) is NOT translated — those are passed through verbatim.
6. **Pseudolocalization**. VS playtest includes pseudolocalization stress test (German 1.4× expansion, French 1.3× — per Document Overlay UI UI-3).

**When to Use**. Every static UI Label. The pattern is universal.

**When NOT to Use**.

- Player names / usernames — verbatim.
- Save timestamps — locale-formatted via `Time.get_datetime_string_from_system()`, not `tr()`.
- Document body text — owned by Document Collection, written in English at MVP, future localization is a separate workstream.
- Console / debug output — not player-facing.

**Accessibility notes**. The pattern enables locale-driven accessibility — players with cognitive accessibility needs may be more comfortable in their first language, and the locale switcher must work with no game restart.

---

#### `accessibility-name-re-resolve`

**Category**: Localization
**Pillar fit**: Accessibility + i18n
**Owner of contract**: Menu System CR-22 + Cutscenes UI.3 (AccessKit re-resolve on translation change)
**Used In**: Every AccessKit-tagged widget — modals, buttons, save cards, Settings toggles, HUD widgets, cutscene cards.

**Description**. Static UI Labels re-translate automatically via `auto-translate-always`, but `accessibility_name` and `accessibility_description` properties are NOT in Godot's auto-translate path — they need explicit re-resolution on locale change. The pattern is a `_notification(NOTIFICATION_TRANSLATION_CHANGED)` handler that re-runs `accessibility_name = tr(name_key)` + `accessibility_description = tr(description_key)` for every accessibility-tagged Control. Without this, screen readers continue to announce the prior locale's name after the visible UI has switched languages — a desync bug that screen-reader users notice immediately.

**Specification**.

1. **Handler**. Every accessibility-tagged Control implements `_notification(what)` with a case for `NOTIFICATION_TRANSLATION_CHANGED` that re-resolves all `accessibility_*` string properties.
2. **Coverage**. `accessibility_name`, `accessibility_description`, and any custom AccessKit announce strings (e.g., assertive-announce one-shots).
3. **Source keys**. Each Control stores its translation keys (e.g., `_name_key = "PAUSE_MENU_CONTINUE"`); the handler re-runs `accessibility_name = tr(_name_key)` on translation change.
4. **Inheritance via Theme**. Where possible, the project Theme provides AccessKit defaults (e.g., button accessibility roles); per-Control name/description overrides require explicit storage of the source key.
5. **Test coverage**. AccessKit test fixture must verify: (a) initial locale's `accessibility_name` correct, (b) after `TranslationServer.set_locale(other)`, `accessibility_name` re-resolves correctly.
6. **No-op when unchanged**. The handler runs `tr(key)` regardless; Godot's translation system returns the same string if the locale hasn't changed (no extra cost).

**When to Use**. Every Control with `accessibility_name` or `accessibility_description` set explicitly.

**When NOT to Use**.

- Controls that inherit AccessKit defaults from Theme without per-instance override — Theme inheritance handles it.
- Non-Control nodes (CanvasLayer, Node) — they don't carry accessibility properties.

**Accessibility notes**. The pattern IS the accessibility commitment for locale switching. Without it, screen readers desync from visible UI on locale change — a critical bug for blind/low-vision players who rely entirely on the AccessKit channel.

---

### Reduced-Motion

#### `reduced-motion-conditional-branch`

**Category**: Reduced-Motion
**Pillar fit**: Standard-tier accessibility (vestibular)
**Owner of contract**: Settings & Accessibility G.3 `reduced_motion` toggle + accessibility-requirements.md Visual table
**Used In**: Cutscenes letterbox slide-in (`letterbox-slide-in`), Document Overlay sepia transition (`lectern-pause-register`), Menu System animations (`pause-menu-folder-slide-in` + `modal-scaffold`), HUD `damage_flash`, F&R `sepia-death-sequence`, mission cards (no-op — already hard-cut by design), per-objective slide-in/out, save card hover animations.

**Description**. Every animation site in the project branches on the `Settings.reduced_motion` flag and provides a vestibular-safe alternative (typically a hard-cut or instant variant). The pattern is a discipline, not a system: there is no shared "reduced-motion replacer" — each animation site owns its branch. The hard-cut variant must be vestibular-safe by design (no motion, no flash, no parallax). Some patterns are already vestibular-safe (mission card hard-cut, fade-to-black) and the branch is a no-op; others (letterbox slide-in, manila folder slide-in, sepia-dim transition) need active replacement.

**Specification**.

1. **Branch site**. Every animation tween's first line is: `if Settings.reduced_motion: <hard-cut variant>; return`.
2. **Hard-cut variants**. Replace tweens with `set_property(final_value)` calls. Replace slide-in animations with appearance at final position. Replace fade-in animations with `modulate.a = 1.0` or `visible = true`.
3. **Audio unchanged**. Audio cues paired with animations continue to play. Reduced-motion is a visual-only setting.
4. **No motion** (Spec rule 4). Hard-cut variants must not introduce alternative motion (e.g., do not "compensate" for a removed slide-in by adding a scale-up).
5. **Vestibular-safe by design** (Spec rule 5). Where a pattern's standard form is already vestibular-safe (Mission Card hard-cut entry, fade-to-black, modal scrim 200 ms fade-in), the branch is a no-op. Document the "no-op" status explicitly so reviewers don't think the branch is missing.
6. **Setting source**. `Settings.reduced_motion` is a boolean; default `false`. Players opt in via Settings → Accessibility per `accessibility-opt-in-toggle`.
7. **Test coverage**. Each animation site that has a real branch (not no-op) needs a test: assert that with `reduced_motion = true`, no Tween is created and the property reaches the final value in one frame.
8. **Documentation**. Every pattern in this library that has reduced-motion behavior documents it in its own Specification rule (visible in the patterns above — this is the meta-pattern).

**When to Use**. Every animation site. Always.

**When NOT to Use**.

- The pattern is universal. There is no opt-out.
- Animation that is already vestibular-safe by design (hard-cut entry, opacity ramp, no motion) — the branch is a no-op but documented.

**Accessibility notes**. This pattern IS the project's vestibular-accessibility commitment. Standard-tier per accessibility-requirements.md. Without it, players with vestibular sensitivity (~3–5% of the player base, per AbleGamers data) cannot tolerate the project's animation budget.

---

## Gaps & Patterns Needed

Patterns identified during authoring as needed but not specified in this MVP library. Each is flagged with the system that triggered the need, why it's a gap, and the recommended next step.

| Gap | Triggered by | Why it's a gap | Recommended next step |
|---|---|---|---|
| **`settings-slider-pattern`** ⚠ **BLOCKING** | `accessibility-opt-in-toggle` Spec rule 7 ("Settings sliders … have their own pattern, not this one") + `design/ux/settings-and-accessibility.md` (slider widgets referenced throughout: 6 audio sliders, `damage_flash_cooldown_ms`, `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em`, `mouse_sensitivity_x/y`, `gamepad_look_sensitivity`, and VS sliders) | Continuous-value Settings (subtitle size scale, UI scale, mouse sensitivity, audio bus volumes, brightness) need a slider pattern with live preview semantics, increment behavior on KB+gamepad, AccessKit role + value announce. Toggles are specified; sliders are not. `design/ux/settings-and-accessibility.md` references this pattern by name across every slider widget — a blocking dependency for the VS sprint. | Author before VS sprint kickoff (referenced by `design/ux/settings-and-accessibility.md` slider widgets). **Owner: ux-designer. Deadline: Before VS sprint kickoff.** Pattern needs: live preview vs commit-on-release, AccessKit `ROLE_SLIDER` + `accessibility_value` updates, gamepad d-pad fine-tune behavior. |
| **`section-load-transition`** | Level Streaming GDD §UI Requirements (referenced briefly in `fade-to-black-close` "When NOT to Use") | Inter-section transitions during gameplay use a 2-frame hard-cut per F&R 2026-04-21 ruling, but the pattern around what shows during the cut (loading screen? black? Operations Archive register?) is not specified here. The 2-frame cut itself is in F&R; the player-facing UX of the cut is undefined. | Author when Level Streaming UX spec is drafted. Likely the cut shows nothing (true hard cut to next section); but if there's a multi-second load on slow disk, an Operations-register loading card may be needed. |
| **`document-archive-browser`** | Document Collection §E.12 (Polish-or-later) — re-read collected documents from Pause Menu | A future "case-file archive" UX where the player can re-read previously collected documents. Polish or post-launch. The archive needs filter / sort / search semantics that don't exist anywhere else in the project. | Author when Polish phase begins. Until then, collected documents are write-only (player reads on collection, then can't re-read). |
| **`gamepad-rebinding-parity`** | Settings & Accessibility CR-22 + technical-preferences.md (gamepad rebinding parity is post-MVP) | KB+M rebinding flow is specified by `rebind-three-state-machine`. Gamepad rebinding parity is post-MVP per project commitment; when added, it will need its own pattern variant (gamepad-button capture, gamepad-axis capture for analog inputs, conflict detection across both KB+M and gamepad bindings). | Document at the time gamepad rebinding parity is committed (post-MVP). The pattern shape is similar to KB+M; variations are in the capture state's input filtering. |
| **`tooltip-on-hover`** | None directly — but Settings labels with longer descriptions, save card mission summaries, and Document Overlay header hint text could all benefit from a hover-tooltip pattern. | The project does not commit to tooltips at MVP. If added, they need: hover delay, accessibility (keyboard focus reveal), reduced-motion (instant vs fade-in), tooltip positioning rules. | Defer to post-MVP. Document when first need arises (likely Settings panel polish). |
| **`progress-indicator`** (loading bar / spinner) | None at MVP — Pillar 5 forbids modern game UI conveniences including loading spinners | The project ships with no loading bar / progress indicator. Section loads use a 2-frame hard-cut. If a multi-second load ever needs a player-facing indicator, the pattern would need to be designed in a Pillar-5-compatible register (e.g., a typewriter-style "decoding" animation, not a circular spinner). | Out of scope. Document at the time a real long load forces the question. |
| **`achievement-unlock-toast`** (Steam achievements) | Not currently in scope — no achievement system at MVP per game-concept.md | Steam achievements are out of MVP scope. If added, the unlock toast is platform-driven (Steam overlay) — but the in-game register may still want a paired notification. | Defer. Steam overlay is sufficient if achievements are added. |
| **Player journey re-validation** | `design/player-journey.md` does not exist | Patterns derived from GDD sources may have implicit player-journey assumptions baked in (e.g., the dismiss-gate durations assume a specific reading-pace player). Once a player journey map is authored, every pattern in this library should be re-validated against the journey. | Run a player journey workshop and revisit the catalog. |

---

## Open Questions

Questions surfaced during pattern authoring that need resolution. Each is owned by a specific stakeholder; deadlines are project-rhythm-aligned (VS, Polish, pre-`/ux-review`).

| Question | Owner | Deadline | Resolution path |
|---|---|---|---|
| **Mouse-click-outside on `dual-focus-dismiss` — should it be the project default for all modals, or per-surface opt-in?** | UX designer + producer | Before first per-screen UX spec authored | Document Overlay supports it (CR-7); Mission Cards explicitly do NOT (Pillar 5). For modals (Quit-Confirm, Save-overwrite, Photosensitivity), it's safer for accessibility (one more dismiss path) but riskier for accidental dismissal of destructive confirmations. **Recommendation**: opt-in per surface; default ON for advisory/info modals (Photosensitivity, Save-failed Abandon path), default OFF for destructive-confirm modals (Save-overwrite, Quit-Confirm). |
| **`silent-drop-dismiss-gate` — should auto-dismiss timeout (Spec rule 6) be exposed in Settings UX, or only via config file?** | UX designer + accessibility specialist | VS sprint planning | Currently spec'd as a Settings value (`cutscenes_auto_dismiss_timeout_s`). Question: does the Settings panel need a UX surface for this, or is it a config-file-only setting for adaptive-controller users who'll edit configs? **Recommendation**: Settings panel exposure via slider (0–30 s) under Accessibility tab. Surfaces the affordance to non-config-editing players who need it. |
| **`rebind-three-state-machine` — should `Esc` be re-bindable?** | UX designer + Input GDD owner | Before VS rebind UX spec | If `Esc` is rebindable, the cancel-out semantics break (player rebinds Esc to "fire weapon," now CAPTURING has no cancel). **Recommendation**: lock `Esc` (and `ui_cancel` action) as non-rebindable. Document in Settings UX as "system reserved." Aligns with Steam Big Picture conventions (Steam button is non-rebindable). |
| **`hud-state-notification` queue overflow — what happens if 10+ notifications fire in 1 second?** | HUD State Signaling GDD owner | Before HUD State Signaling sprint | Spec rule 4 says "queue rather than overlap, FIFO." If queue grows large, players see notifications drift in for 30+ seconds after the trigger. **Recommendation**: cap queue at 3 entries; on overflow, drop oldest non-failure. Failures (SAVE_FAILED) never drop. |
| **Pattern library maintenance — when a new pattern is identified post-VS, what's the addition flow?** | UX designer | Polish phase | Document the "How to add a new pattern" workflow. Likely: surface in `/ux-review` of the spec that introduced it; pattern-library author proposes draft; user approves; this library updated. |
| **Cross-pattern dependency declarations — should the catalog table show pattern-to-pattern deps explicitly?** | UX designer | Pre-`/ux-review` | E.g., `silent-drop-dismiss-gate` depends on `set-handled-before-pop` and interacts with `stage-manager-carve-out`. Currently dependencies are described in Specification text. **Recommendation**: add a "Depends on" / "Interacts with" line to the catalog; defer to next library revision rather than expanding catalog now. |
| **Accessibility tier audit — does this library actually deliver Standard tier coverage?** | accessibility-specialist (consultation) | Pre-`/gate-check` | Cross-check this library against `accessibility-requirements.md` Per-Feature Matrix. Verify every "Designed" status row has a pattern that delivers the commitment. **Recommendation**: run as part of `/ux-review` for this file. |
| **Per-screen UX spec authoring order — what's the priority?** | producer | VS sprint planning | Menu System §UI-3 lists 8 UX specs to author. Cutscenes UI.2 lists 4 more. Document Overlay UI-3 lists 1. Save/Load §Visual co-owns 3. Total ~16 per-screen UX specs needed. **Recommendation**: author in HARD-blocking-MVP-first order (photosensitivity → main menu → quit-confirm → pause menu → load grid → save grid → save-failed → quicksave-card → cutscene cards → document overlay). |
| **`stage-manager-carve-out` registry location — should the canonical list of carve-outs live here, in accessibility-requirements.md, or in a dedicated registry?** | UX designer + accessibility specialist | Before `/gate-check` | Currently spec'd as living in accessibility-requirements.md. **Recommendation**: keep registry in accessibility-requirements.md (where it's discoverable from accessibility audits); cross-link from this pattern's "Used In" line. |
