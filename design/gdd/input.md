# Input

> **Status**: In Design — Revised 2026-04-27 (`/design-review` MAJOR REVISION pass: 6 specialists + creative-director synthesis. 13 BLOCKING items addressed inline. Settings GDD CR-22 confirmed as binding-owner-of-record for default keybindings; `takedown`/`use_gadget` split to two distinct actions on two distinct keys; `InputContext.LOADING` flagged as ADR-0004 amendment PRE-IMPL GATE; Pillar 5 carve-outs subsection added; StringName "compile-detectable" claim retracted; mouse capture mode ownership documented; 13 ACs rewritten with story-type tags + test paths; 6 ACs added.)
> **Author**: User + `/design-system` skill + specialists (gameplay-programmer, ux-designer per routing) + 2026-04-27 review revision pass (game-designer, systems-designer, godot-specialist, gameplay-programmer, qa-lead, ux-designer, creative-director synthesis)
> **Last Updated**: 2026-04-27
> **Last Verified**: 2026-04-27
> **Implements Pillar**: Foundation infrastructure — indirectly serves Pillar 5 (Period Authenticity: dossier-register input grammar, with named carve-outs for direct-slot weapon hotkeys / quicksave / mousewheel cycling)

## Summary

Input is the project's action-mapping layer — a Godot `InputMap`-based abstraction that translates keyboard, mouse, and gamepad events into named actions (move, jump, fire, interact, ui_cancel, etc.) that every system consumes by name. The Input system defines the canonical action **set** (the catalog of action names and their semantics), the **default** KB/M and gamepad bindings (subject to Settings GDD CR-22 as binding-owner-of-record), and the contract by which downstream systems read input. Rebinding is scoped to Settings & Accessibility (Vertical Slice, post-MVP for gamepad parity); ADR-0004 locks two specific UI-related actions (`ui_cancel`, `interact`). `takedown` and `use_gadget` are two distinct InputMap actions on two distinct default keys per Settings CR-22 — there is no shared-binding router.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None (foundational, but blocked on ADR-0004 → Accepted promotion)` · Related ADR: ADR-0004 (UI Framework — currently **Proposed**; mandates ui_cancel + interact actions, owns InputContext autoload + Context enum)

## Overview

Input is a Foundation-layer infrastructure system. Players never think about it directly — they think about Eve moving when they press `W`, the menu dismissing when they press `Esc`, a document opening when they hit `E`. The Input system is what makes those translations consistent across every surface. Without a unified action map, every system (Player Character, Inventory, Menu, Document Overlay) would invent its own key-checking logic and bindings would diverge — a player who rebound `Interact` for picking up gadgets would still have to press `E` to read a document. The Input system prevents that fragmentation by defining one project-wide catalog of named actions and one canonical binding table per input method.

**Scope by milestone:**
- **MVP**: Full action map exists with default bindings. Rebinding is manual (InputMap edited in Godot editor or via a config file — no in-game rebinding UI yet).
- **Vertical Slice**: Rebinding UI ships through Settings & Accessibility, with KB/M parity.
- **Post-MVP**: Gamepad rebinding parity (per `technical-preferences.md`).

ADR-0004 (UI Framework) locks two actions the Input GDD must provide: `ui_cancel` (bound to `Esc` + gamepad `B/Circle`) and `interact` (bound to `E` + gamepad `A/Cross`). These are modal-dismiss and generic-interaction actions that every UI surface consumes via `_unhandled_input()`.

## Player Fantasy

Input infrastructure protects two pillars at once: **Stealth as Theatre** (Pillar 3) demands inputs that fire instantly and unambiguously; **Period Authenticity** (Pillar 5) demands those inputs be presented as a 1960s field operative would see them — a typed dossier of bindings, not a glowing radial menu. The failures Input refuses:

- **No mystery drops.** Every failed takedown, every blown stealth approach traces to a player decision — never to a swallowed keystroke. (Pillar 3: fairness is the precondition for theatre.)
- **No modern crutches.** No hold-to-confirm rings, no contextual gesture hints, no radial weapon wheels, no mobile-style quick-action menus. The binding list is a **dossier page**, not an HUD widget. (Pillar 5.)
- **No rebinding rot.** When rebinding ships (Vertical Slice), remapped keys propagate everywhere — UI prompts, tutorial text, save-screen hints. The game never refers to a key the player has changed.
- **No gamepad second-class feel for navigation.** Menus and gameplay are fully playable on gamepad from Day 1, even before full rebinding parity ships. (Partial gamepad per `technical-preferences.md` means the menu-navigation path is complete at MVP.)

Players will never praise the Input system by name. They will praise the game feeling **direct and honest** — inputs that mean exactly what they expect, presented in a visual language that belongs to 1965.

### Period Authenticity Carve-outs

Three modern-FPS conventions ship in the action catalog. Each is a deliberate carve-out from Pillar 5, justified diegetically rather than silently included. Anchor: **the dossier names what your hands already know.**

- **Number-key weapon slots (`weapon_slot_1..5`)**: Number rows predate 1965 (typewriters, telephones, calculators, switchboard cord positions) — pressing a labeled key on a desk is period-coherent. The alternative — a radial weapon wheel — is the *exact* modern UX Pillar 5 forbids. Direct-slot hotkeys are the period-authentic answer to "fast deliberate weapon choice." Gamepad parity for direct-slot selection ships via chord bindings (`LEFT_SHOULDER + DPAD_*`) — see Section C Group 2.
- **Mousewheel weapon/gadget cycling (`weapon_next/prev`, `gadget_next/prev`)**: Cycling-via-physical-thumb-motion is a 1960s-coherent metaphor — rolodex, rotary dial, microfilm reel. The mousewheel translates that motion into 1990s PC grammar; the underlying gesture is period-consistent.
- **Quicksave / Quickload (F5 / F9)**: 1990s PC convention with no 1960s analog. Carved out **on the condition** of a diegetic feedback contract: F5 fires a ~1.5s dossier-register confirmation toast (e.g., *"Field log saved — 14:32"*) rendered by HUD Core in the dossier typographic register. F5 during a save-in-progress is queued (Save/Load owns rate-limiting); F5 during `InputContext.LOADING` is dropped silently with a HUD warning suppressed during the load (LOADING-context behavior — see ADR-0004 amendment PRE-IMPL GATE). Without this feedback contract, F5/F9 would violate the "inputs that mean exactly what they expect" promise above; with it, they are honest.

These carve-outs are *named*, not silently shipped. Any future contributor reading this section knows exactly which conventions are exempted and why.

## Detailed Rules

### Core Rules

1. **Every cross-system input read goes through `InputMap`.** No system reads raw `KEY_*`, `JOY_BUTTON_*`, `JOY_AXIS_*`, or `MOUSE_BUTTON_*` constants directly (except for in-development debug keys gated by `OS.is_debug_build()`). All input queries use named actions via `event.is_action_pressed(&"action_name")` (event-driven) or `Input.is_action_pressed(&"action_name")` / `Input.get_vector(...)` (polling).
   - **Selection guidance (project-wide convention):** Use **event-driven** (`event.is_action_pressed()` inside `_unhandled_input`) for `Press` and `Toggle` action types — single-shot semantics. Use **polled** (`Input.is_action_pressed()` inside `_process` or `_physics_process`) for `Hold` and `[AXIS]` action types — sustained-state semantics. `sprint` (Hold) MUST be polled; an event-driven Hold check misses sustained state across frame boundaries.
2. **Action names are canonical — use StringName literals project-wide.** All action references use `&"action_name"` (StringName). A typed `InputActions` static class at `res://src/core/input/input_actions.gd` declares every action as a `const NAME := &"name"` constant; systems import from it via `class_name InputActions` rather than spelling inline. This convention reduces but does not eliminate misspelling risk: misspelled constant *names* (e.g., `InputActions.MVE_FORWARD`) are compile errors; misspelled constant *values* (e.g., `const MOVE_FORWARD := &"move_froward"`) are silent runtime misses caught only by `InputMap.has_action()` validation. Core Rule 6 mandates that validation.
3. **InputContext (ADR-0004) gates gameplay input.** Every gameplay `_unhandled_input()` handler checks `InputContext.is_active(InputContext.Context.GAMEPLAY)` and returns early if not active. Modal surfaces (Menu, Document Overlay, Pause, Settings) push/pop their own context; when a modal is open, gameplay actions like `fire_primary` do not fire even if the player presses the bound key.
   - **Canonical Context enum lives in ADR-0004**, not in this GDD. Current values: `GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, SETTINGS`. **`LOADING` is required by Level Streaming (LS-Gate-2), Failure & Respawn (coord #4), and Mission Scripting** but is NOT in the current ADR-0004 enum — see the **PRE-IMPL GATE** in Dependencies for the required ADR amendment.
   - Input is **stateless** at the action layer. Apparent context-sensitivity is delegated entirely to the `InputContext` autoload (ADR-0004). When debugging unexpected context-routing behavior, inspect `InputContext._stack`, not Input.
4. **Modal dismiss uses `_unhandled_input()` + `ui_cancel` action** (per ADR-0004). Dismiss is NEVER bound to a focused Button widget. This sidesteps Godot 4.6's dual-focus split (mouse/touch focus vs keyboard/gamepad focus). Modals using `hide()` (vs `queue_free()`) MUST call `release_focus()` before hiding — a hidden Control with retained keyboard focus consumes events via `_gui_input` BEFORE they reach `_unhandled_input` at the scene root.
5. **`get_viewport().set_input_as_handled()` MUST be called** after a handler consumes an event. Without it, the event continues propagating and may trigger other handlers. This is a code-review checkpoint for every system's input handlers (see AC #15 grep enforcement).
6. **Rebinding at runtime uses `InputMap.action_erase_events()` + `InputMap.action_add_event()`** per action. The pair MUST be called consecutively in the same function with no `await` between them — within a single frame this sequence is safe (GDScript main thread, no preemption); an `await` between erase and add leaves the action transiently unbound and any `_unhandled_input` running in the awaited frame will miss the binding. Every runtime call to `action_add_event()` MUST first check `InputMap.has_action(name)` (gotcha #3 below); a misspelled action silently creates a duplicate action with no error. Persistence serializes `InputEvent` subclass fields manually to `user://settings.cfg` `[controls]` section (per ADR-0003 — settings are separate from SaveGame); `InputEvent` is not directly ConfigFile-serializable. Settings GDD owns the wire format and the SDL2→SDL3 migration story for legacy `settings.cfg` files (button-index drift on SDL3 driver upgrade — Settings must version-stamp the format).
7. **Esc is dual-role via InputContext.** In `InputContext.GAMEPLAY`: `Esc` fires `pause`. In any modal context: `Esc` fires `ui_cancel`. Both actions are bound to `Esc`, resolved by the context gate in step 3. **Order-of-operations rule (silent-swallow prevention):** any modal dismiss handler MUST call `get_viewport().set_input_as_handled()` BEFORE calling `InputContext.pop()`. Reversing the order opens a same-frame window where the modal's context check has already returned `false` (post-pop) but the gameplay handler's context check also returns `false` (transition not yet settled), and the unhandled Esc falls through to Godot's built-in `ui_cancel` focus-clear behavior — a Pillar 3 violation. Consume first, pop second.
8. **Mouse capture mode owner: Player Character on `InputContext.GAMEPLAY` enter; modals push `MOUSE_MODE_VISIBLE` on open and pop on close.** `look_horizontal` / `look_vertical` (Mouse X / Mouse Y axis) only deliver events when `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED`. Player Character calls `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)` on entering gameplay context; every modal that opens a cursor (Menu, Document Overlay, Settings, Pause) MUST set `MOUSE_MODE_VISIBLE` on `_ready()` / open and restore the previous mode on close. `InputContext` does NOT own mouse mode — it is a sibling concern owned by the consuming surface, with Player Character as the gameplay-side default.
9. **Held-key flush on rebind commit (Vertical Slice scope):** When Settings commits a rebind via `action_erase_events` + `action_add_event`, it MUST also call `Input.action_release(action_name)` for the action being rebound. Without this, an already-held physical key remains bound to the OLD action's keypress state at the OS layer; the player's character abruptly stops on rebind close. Settings owns the implementation; this rule documents the contract.
10. **`interact` priority queue is a hard rule, not a heuristic.** Player Character resolves `interact` via prioritized world-raycast: **document > terminal > item > door**, with tie-breaker by raycast distance (closest target wins on ties). This is a fixed rule, not playtest-tunable. **Level-design constraint (binding on Mission & Level Scripting authoring contract):** level designers MUST NOT co-locate competing interact targets within 1.5 m of a single forward raycast hit (e.g., do not place a document on a desk in front of a door at the same range). The CI lint in Mission & Level Scripting's level-validation suite flags violations. This trade transfers ambiguity from a runtime UX decision (where the player would experience swallowed keystrokes) to an authoring-time decision (where the level designer knows the rule and routes around it). No `pickup_alternate` action ships at MVP; OQ #2 closed.
11. **Debug action runtime registration mechanism:** debug actions (`debug_toggle_ai`, `debug_noclip`, `debug_spawn_alert`) are NOT declared in `project.godot` — Godot 4.6's `project.godot` has no conditional sections per build type. Instead, `InputActions._register_debug_actions()` is called from the Input bootstrap, wrapped in `if OS.is_debug_build():`, and uses `InputMap.add_action(name)` + `InputMap.action_add_event(name, event)` to register each debug action at runtime. Release builds skip the registration entirely; `InputMap.has_action(&"debug_toggle_ai")` returns `false`. Verified by AC-INPUT-5.3.

### States and Transitions

**Stateless.** Input has no states of its own. `InputMap` is loaded at project startup from `project.godot` and persists for the lifetime of the application. Runtime rebinding mutates `InputMap` immediately — no state transitions between "legacy bindings" and "new bindings"; the change is atomic.

### Interactions with Other Systems

#### Action catalog (33 gameplay/UI + 3 debug = 36 actions)

> **Binding-owner-of-record**: Settings GDD CR-22 owns the canonical default-keybindings table. The defaults shown below MUST match Settings CR-22 exactly. If the two ever drift, Settings is authoritative — file an Input GDD revision pass to realign.

**Group 1 — Movement** (`[AXIS]` read via `Input.get_vector()`)

| Action | KB/M Default | Gamepad Default | Type | Consumer |
|---|---|---|---|---|
| `move_forward` | `W` | `JOY_AXIS_LEFT_Y` (−) | `[AXIS]` | Player Character |
| `move_backward` | `S` | `JOY_AXIS_LEFT_Y` (+) | `[AXIS]` | Player Character |
| `move_left` | `A` | `JOY_AXIS_LEFT_X` (−) | `[AXIS]` | Player Character |
| `move_right` | `D` | `JOY_AXIS_LEFT_X` (+) | `[AXIS]` | Player Character |
| `look_horizontal` | Mouse X | `JOY_AXIS_RIGHT_X` | `[AXIS]` | Player Character |
| `look_vertical` | Mouse Y | `JOY_AXIS_RIGHT_Y` | `[AXIS]` | Player Character |
| `jump` | `Space` | `JOY_BUTTON_A` | Press | Player Character |
| `crouch` | `Left Ctrl` | `JOY_BUTTON_RIGHT_STICK` | Toggle | Player Character, Stealth AI (noise) |
| `sprint` | `Left Shift` | `JOY_BUTTON_LEFT_STICK` | Hold | Player Character, Stealth AI (noise) |

**Group 2 — Combat & weapons**

| Action | KB/M Default | Gamepad Default | Type | Consumer |
|---|---|---|---|---|
| `fire_primary` | `Mouse Button 1` | `JOY_AXIS_TRIGGER_RIGHT` | Hold | Combat & Damage |
| `aim_down_sights` | `Mouse Button 2` | `JOY_AXIS_TRIGGER_LEFT` | Hold | Combat & Damage, Player Character |
| `reload` | `R` | `JOY_BUTTON_X` | Press | Combat & Damage |
| `weapon_slot_1` | `1` | — *(VS forward dep)* | Press | Inventory & Gadgets |
| `weapon_slot_2` | `2` | — *(VS forward dep)* | Press | Inventory & Gadgets |
| `weapon_slot_3` | `3` | — *(VS forward dep)* | Press | Inventory & Gadgets |
| `weapon_slot_4` | `4` | — *(VS forward dep)* | Press | Inventory & Gadgets |
| `weapon_slot_5` | `5` | — *(VS forward dep)* | Press | Inventory & Gadgets |
| `weapon_next` | `Mouse Wheel Up` | `JOY_BUTTON_DPAD_RIGHT` | Press | Inventory & Gadgets |
| `weapon_prev` | `Mouse Wheel Down` | `JOY_BUTTON_DPAD_LEFT` | Press | Inventory & Gadgets |

> **Gamepad direct-slot parity (Vertical Slice forward dep)**: At MVP, gamepad players reach weapons via cycle-only (`weapon_next` / `weapon_prev` on D-pad Right/Left). Direct-slot parity (chord bindings such as `LEFT_SHOULDER + DPAD_*` or a held-modifier scheme) is a Vertical Slice forward dep, owned by Inventory & Gadgets' input handler at VS scope. The MVP cycle-only limitation is acknowledged as a known Pillar 3 friction point on gamepad — D-pad cycling is fast enough for deliberate weapon choice during pre-engagement stealth, but is not "instant" mid-encounter. Settings & Accessibility CR-22 forward-dep covers any gamepad rebinding parity changes when this lands.

**Group 3 — Gadgets**

| Action | KB/M Default | Gamepad Default | Type | Consumer |
|---|---|---|---|---|
| `takedown` | `Q` | `JOY_BUTTON_X` | Press | Combat & Damage — dedicated stealth-kill input per Combat CR-3 + Settings CR-22. Live only when `SAI.takedown_prompt_active(attacker)` returns `true`. Distinct InputMap action with dedicated default key (no shared-binding router). Combat's `_unhandled_input` handler reads `event.is_action_pressed(&"takedown")` only; gadget activation is Inventory's concern under a different action name. |
| `use_gadget` | `F` | `JOY_BUTTON_Y` | Press | Inventory & Gadgets — activates equipped gadget. **Distinct InputMap action** with dedicated default key per Settings CR-22 (binding-owner-of-record). Inventory installs its own `_unhandled_input` handler and reads `event.is_action_pressed(&"use_gadget")`; the previous shared-binding + Combat-router design has been retired (2026-04-27 revision pass) following CD adjudication: shared binding violated Pillar 3 fairness ("no swallowed keystrokes") because the dispatch decision was opaque to the player. Two distinct actions = two distinct keys = no swallowed keystrokes. |
| `gadget_next` | `Mouse Button 4` | `JOY_BUTTON_DPAD_UP` | Press | Inventory & Gadgets |
| `gadget_prev` | `Mouse Button 5` | `JOY_BUTTON_DPAD_DOWN` | Press | Inventory & Gadgets |

**Group 4 — Interaction**

| Action | KB/M Default | Gamepad Default | Type | Consumer |
|---|---|---|---|---|
| `interact` | `E` (ADR-0004) | `JOY_BUTTON_A` (ADR-0004) | Press | **Context-sensitive.** Player Character resolves via prioritized world-raycast: document > terminal > item > door. Serves Document Collection, Mission Scripting, Inventory & Gadgets (pickups). |

**Group 5 — UI & Menus**

| Action | KB/M Default | Gamepad Default | Type | Consumer |
|---|---|---|---|---|
| `ui_cancel` | `Esc` (ADR-0004) | `JOY_BUTTON_B` (ADR-0004) | Press | Menu System, Document Overlay UI, InputContext autoload. Dual-role with `pause` via InputContext. |
| `pause` | `Esc` | `JOY_BUTTON_START` | Press | Menu System. Fires in `InputContext.GAMEPLAY` only. |
| `ui_up` | `Arrow Up` | `JOY_BUTTON_DPAD_UP` | Press | Menu System, Settings |
| `ui_down` | `Arrow Down` | `JOY_BUTTON_DPAD_DOWN` | Press | Menu System, Settings |
| `ui_left` | `Arrow Left` | `JOY_BUTTON_DPAD_LEFT` | Press | Menu System, Settings |
| `ui_right` | `Arrow Right` | `JOY_BUTTON_DPAD_RIGHT` | Press | Menu System, Settings |
| `ui_accept` | `Enter` | `JOY_BUTTON_A` | Press | Menu System, Settings |
| `quicksave` | `F5` | — | Press | Save / Load (slot 0 autosave) |
| `quickload` | `F9` | — | Press | Save / Load (slot 0 autosave) |

**Group 6 — Debug** (dev-only, gated by `OS.is_debug_build()`, stripped from in-game rebinding UI)

| Action | KB/M Default | Purpose |
|---|---|---|
| `debug_toggle_ai` | `F1` | Toggle Stealth AI on/off |
| `debug_noclip` | `F2` | Toggle noclip traversal |
| `debug_spawn_alert` | `F3` | Force AI to alert state |

#### Consumer matrix (downstream systems → input groups)

| System | Uses groups |
|---|---|
| Player Character | Movement, Interaction (context resolution owner) |
| Combat & Damage | Combat, Gadgets (`takedown` dedicated action per Combat CR-3) |
| Inventory & Gadgets | Combat (weapon slots), Gadgets, Interaction (pickup) |
| Stealth AI | Movement (reads crouch/sprint for noise calc) |
| Document Collection | Interaction (document pickup) |
| Mission Scripting | Interaction (terminal, scripted trigger) |
| Menu System | UI, `pause` |
| Document Overlay UI | UI (`ui_cancel`) |
| Settings & Accessibility | UI (menu nav) |
| Save / Load | UI (quicksave/quickload) |
| InputContext autoload | UI (`ui_cancel` for context pop) |

#### Critical Godot 4.6 gotchas (required reading for any system consuming input)

- **`grab_focus()` does NOT capture mouse focus in 4.6.** It only sets keyboard/gamepad focus. Do not rely on it for mouse-click activation.
- **`get_viewport().set_input_as_handled()` must be called on the Viewport**, not the node. Missing it causes event propagation bugs.
- **Action name validation**: any runtime call to `InputMap.action_add_event()` must first check `InputMap.has_action(name)`. Otherwise, a misspelled action silently creates a duplicate and the original receives no event.

## Formulas

**None.** Input is pure infrastructure with no balance values or calculations. Movement speed scalars, mouse sensitivity curves, controller dead zones, and sprint multipliers are all **owned by the consuming system** (e.g., `mouse_sensitivity` lives in Player Character; crouch noise scalar lives in Stealth AI). The Input system reads raw events and exposes named actions; transformations on the input data are the consumer's responsibility.

One implementation note for consumers (not a formula this GDD owns): `Input.get_vector()` applies its own deadzone and normalization when reading axis actions — this is engine-level behavior, configurable via the **5th** parameter (`deadzone: float = -1.0`) of `get_vector(neg_x, pos_x, neg_y, pos_y, deadzone)`. The deadzone is applied **radially** (unified vector magnitude threshold), NOT per-axis — important for precision crouch movement where consumers might assume independent x/y thresholds. The Godot 4.6 default deadzone for the call is `-1.0` (inherits the InputMap action's per-action deadzone, default `0.5` for newly-added axis actions per Godot 4.6 InputMap; verify against `docs/engine-reference/godot/` before sprint). Consuming GDDs must set deadzone explicitly if Player Character or Combat want different sensitivity than the InputMap default.

## Edge Cases

- **If the player presses a bound key while the corresponding `InputContext` is not active** → the handler returns early at the `InputContext.is_active()` check; the event is not consumed and continues propagating. **Resolution**: intended. Per Core Rule 3, every handler MUST gate by context. Missing gates are bugs.
- **If two actions bind to the same key (e.g., `Esc` → both `pause` and `ui_cancel`)** → Godot dispatches the event to `_unhandled_input()`; both actions match when tested via `event.is_action_pressed()`. **Resolution**: intended. Per Core Rule 7 (Esc dual-role), the context gate resolves which handler actually processes. The gameplay handler checks `InputContext.GAMEPLAY` and fires `pause`; the modal handler checks its own context and fires `ui_cancel`. Only one runs per event because the other context is inactive.
- **Esc silent-swallow during context-transition frame** → if a modal's dismiss handler calls `InputContext.pop()` BEFORE calling `set_input_as_handled()`, there is a same-frame window where the modal's context check has already returned `false` (post-pop) but the gameplay handler's context check also returns `false` (transition not yet settled). Both handlers return early, the unhandled Esc falls through to Godot's built-in `ui_cancel` focus-clear behavior, and the player perceives a swallowed input. **Resolution**: Core Rule 7 order-of-operations rule — consume first (`get_viewport().set_input_as_handled()`), pop second (`InputContext.pop()`). Verified by AC #18 (NEW). Reverse order is a Pillar 3 violation.
- **Mouse capture mode lost after modal close** → if a modal opens (e.g., pause menu sets `MOUSE_MODE_VISIBLE` to show a cursor) and closes without restoring `MOUSE_MODE_CAPTURED`, `look_horizontal` / `look_vertical` axis events stop firing — the player can move but cannot turn. **Resolution**: Core Rule 8 — every modal that changes mouse mode MUST restore the previous mode on close (push/pop semantics for mouse mode mirror InputContext semantics). Player Character is the gameplay-side default-restorer when `InputContext.GAMEPLAY` becomes `current()` again. Verified by AC #19 (NEW).
- **Player rebinds an action while holding the key bound to it (Vertical Slice)** → e.g., player holds `W` (mapped to `move_forward`), opens Settings, rebinds `move_forward` to `T`, closes Settings. The OS still reports physical `W` as held but `W` no longer maps to any action. `Input.is_action_pressed(&"move_forward")` returns `false` until the player releases and represses. Player Character abruptly stops. **Resolution**: Core Rule 9 — Settings MUST call `Input.action_release(action_name)` for every rebound action immediately after the `action_erase_events` + `action_add_event` pair. Verified by AC #20 (NEW, Vertical Slice scope).
- **If a player rebinds an action to a key already used by another action** → runtime rebinding UI (Vertical Slice) MUST detect the conflict and either refuse the bind or offer to unbind the conflicting action. **Resolution**: Settings & Accessibility owns the conflict-detection UI rule; Input just provides the `InputMap.has_event()` query. Intended conflict-surface behavior is a Vertical Slice design question for Settings' GDD.
- **If a gamepad disconnects mid-gameplay** → Godot fires the `Input.joy_connection_changed` signal; UI should optionally pause the game and show a "reconnect controller" prompt. **Resolution**: Pause handling is Menu System's concern. Input does NOT auto-pause; it just keeps reading whatever input is still available (KB/M remains functional). Menu System subscribes to `joy_connection_changed` via `get_tree()` per ADR-0002 engine-signal policy (don't re-emit through Events bus).
- **If a player presses `quicksave` (F5) while `Save/Load` is busy saving a previous quicksave** → the second F5 press is ignored by Save/Load; its `save_in_progress` flag gates the call. **Resolution**: Save/Load owns the rate-limiting; Input just emits the key event.
- **If a debug key (F1/F2/F3) is pressed in a release build** → Input has no matching action (debug keys are gated by `OS.is_debug_build()` in project.godot configuration). **Resolution**: intended. Release builds strip debug actions entirely; the keypress falls through with no match.
- **If the Input system is queried before `InputMap` is loaded** → `Input.is_action_pressed()` returns `false`; `InputMap.has_action()` returns `false`. **Resolution**: not a real edge case under Godot's lifecycle — `InputMap` loads at project startup before any scene, guaranteed. Listed only to document the assumption.
- **If the player holds a movement key (e.g., `move_forward`) during a context transition (e.g., opens pause menu while running)** → the keypress state persists in the OS/engine layer; when the context returns to `GAMEPLAY`, `Input.is_action_pressed(&"move_forward")` immediately returns `true` again if the key is still held. **Resolution**: intended. Players can open menus mid-run and resume running on close. Player Character GDD handles any velocity smoothing; Input exposes state honestly.
- **If a runtime rebind inserts a binding Godot cannot represent** (extremely rare — e.g., some exotic joystick axis) → `InputMap.action_add_event()` succeeds but the event may never fire. **Resolution**: Settings UI rebind-capture MUST validate the captured event is a recognized type (`InputEventKey`, `InputEventMouseButton`, `InputEventJoypadButton`, `InputEventJoypadMotion`) before committing.

## Dependencies

Input has **no upstream dependencies** on other game systems — it depends only on the Godot engine (`InputMap`, `Input` singleton, `InputEvent` subclasses) and the `InputContext` autoload defined in ADR-0004.

### Downstream dependents

| System | Direction | Nature of Dependency |
|---|---|---|
| Player Character (system 8) | PC → Input | Reads `move_*`, `look_*`, `jump`, `crouch`, `sprint`, `interact` (context-resolved). Owns the interact raycast priority logic. |
| Combat & Damage (system 11) | Combat → Input | Reads `fire_primary`, `aim_down_sights`, `reload`. Resolves `use_gadget` to takedown when near unaware guard. |
| Inventory & Gadgets (system 12) | Inventory → Input | Reads `weapon_slot_1..5`, `weapon_next`, `weapon_prev`, `use_gadget`, `gadget_next`, `gadget_prev`. |
| Stealth AI (system 10) | Stealth AI → Input | Reads `crouch` / `sprint` state to compute noise footprint (via Player Character). |
| Document Collection (system 17) | Documents → Input | Receives `interact` events resolved by Player Character raycast. |
| Mission & Level Scripting (system 13) | Mission → Input | Receives `interact` events for terminals / scripted triggers. |
| Menu System (system 21) | Menu → Input | Reads `pause`, `ui_up/down/left/right`, `ui_accept`, `ui_cancel`. |
| Document Overlay UI (system 20) | Doc Overlay → Input | Reads `ui_cancel` via `_unhandled_input()`; gamepad scroll via right stick. |
| Settings & Accessibility (system 23) | Settings → Input | Owns runtime rebinding UI. Calls `InputMap.action_erase_events()` + `InputMap.action_add_event()` per rebind. Persists to `user://settings.cfg`. |
| Save / Load (system 6) | Save/Load → Input | Reads `quicksave` / `quickload`. |
| InputContext autoload (ADR-0004) | InputContext → Input | Stores the context stack Input handlers query. |

### Engine dependency

Godot 4.6 `InputMap` + `Input` singleton + `InputEvent` subclasses (stable since 4.0). SDL3 gamepad driver (4.5+) — transparent to GDScript. Dual-focus split (4.6) — Input does not interact with focus state directly; event-driven handlers via `_unhandled_input()` are focus-agnostic.

### ADR contracts

- **ADR-0004 (UI Framework — currently `Proposed`)**: mandates `ui_cancel` = Esc + B/Circle and `interact` = E + A/Cross. InputContext autoload governs modal input routing. Input GDD provides the actions; ADR-0004 owns the routing stack and the canonical `Context` enum. **PRE-IMPL GATE**: per project rules ("Never skip Accepted — stories referencing a Proposed ADR are auto-blocked"), ADR-0004 must be promoted Proposed → Accepted before any sprint consuming this Input GDD can start. The 2 verification gates are listed in ADR-0004 itself.
- **ADR-0002 (Signal Bus)**: no direct dependency. If Input ever needs to emit cross-system events (e.g., `input_rebound(action_name)` for Settings), that signal must be added to `Events.gd` per ADR-0002 policy. Currently no such event is needed.
- **ADR-0003 (Save Format)**: Input rebinding config lives in `user://settings.cfg` (ConfigFile) `[controls]` section, separate from SaveGame. ConfigFile serialization of `InputEvent` subclass fields is manual; Settings GDD owns the wire format and SDL2→SDL3 migration story for legacy files.
- **ADR-0001 (Stencil)**: no interaction.

### Pre-implementation gates (BLOCKING for sprint start)

1. **ADR-0004 amendment to add `InputContext.LOADING` AND `InputContext.MODAL`** — Level Streaming LS-Gate-2, Failure & Respawn coord item #4, and Mission Scripting all reference `InputContext.LOADING` as a required context; Menu System CR-2 + L117–120 + L910 reference `InputContext.MODAL` for modal-scaffold push/pop (photosensitivity warning, save-failed dialog, quit-confirm, etc.). ADR-0004's current enum is `{GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, SETTINGS}` — both `LOADING` and `MODAL` must be added in a single bundled amendment with one-paragraph push/pop contracts: (a) `LOADING` for Level Streaming + Save/Load to consume during scene transitions; (b) `MODAL` for the Menu System modal-scaffold to consume during transient dialogs that overlay another modal context (e.g., save-failed dialog rendered over the Pause Menu). Until both land, every level transition guarantees input pass-through (Pillar 3 violation by construction) AND modal scaffolds push an unowned context state (Menu System B4 from /review-all-gdds 2026-04-27 — closed by this addition). The amendment lands as one PR per ADR-0004's atomic-context-addition pattern.
2. **ADR-0004 promotion `Proposed` → `Accepted`** — see ADR contracts above. The two verification gates must be closed by godot-specialist + creative-director.
3. **Inventory GDD CR-4 amendment** — Inventory currently still references `InputActions.TAKEDOWN_OR_GADGET` (a ghost name not in this catalog) and the Combat-as-router single-dispatch model (also retired). Inventory must be amended to: (a) read `event.is_action_pressed(&"use_gadget")` directly in its own `_unhandled_input` handler; (b) drop the `TAKEDOWN_OR_GADGET` reference; (c) acknowledge differentiated defaults per Settings CR-22.
4. **Combat GDD CR-3 confirmation** — Combat must confirm its `_unhandled_input` reads `&"takedown"` only (no router dispatch); Combat does NOT call `InventorySystem.try_use_gadget()`. Inventory owns its own input path.
5. **`InputActions` static class authoring** — Open Question #5 closed: the class lives at `res://src/core/input/input_actions.gd`; consumers import via `class_name InputActions` global, never via `preload(...)` literal path. AC #21 (NEW) verifies the path.

### Forward dependencies (Vertical Slice scope, not blocking MVP)

- **HUD Core diegetic save toast** — F5/F9 quicksave/quickload feedback contract per Player Fantasy "Period Authenticity Carve-outs" subsection. HUD Core owns the toast widget; Input emits the keypress.
- **Inventory & Gadgets gamepad direct-slot parity** — chord bindings or held-modifier scheme per Section C Group 2 note. Inventory owns the implementation.
- **Settings & Accessibility runtime rebinding UI + Hold-to-toggle accessibility** — Settings owns the rebinding screen (CR-22), conflict detection, persistence, the held-key flush on rebind commit (Core Rule 9), the wire format for `user://settings.cfg`, the SDL2→SDL3 migration story, the Hold-to-toggle accessibility for `sprint`/`crouch`/`aim_down_sights` (CR-21), and dynamic glyph swapping for rebound gamepad buttons in UI prompts.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `InputMap` default bindings | Per Section C catalog | Locked (changes to ADR-0004-mandated actions require ADR amendment; any action may be runtime-rebound via Settings) | N/A | N/A |
| `Input.get_vector(...)` deadzone | Godot 4.6 default `-1.0` (inherits per-action InputMap deadzone, default `0.5`); surfaced as 5th parameter; **radial** (unified) not per-axis | `0.05` – `0.35` *(recommended consumer override range; the engine default of 0.5 is too aggressive for stealth-precise movement)* | Larger = more tolerant of controller drift, less precise small movements; values ≥0.35 produce a sharp step-function discontinuity (binary off/full) | Smaller = more precise, may register continuous micro-movement from worn sticks (drift commonly 0.04–0.08 — values below `0.05` register phantom input) |
| Debug action availability | Enabled in debug builds (`OS.is_debug_build()` → true) | Boolean, per-build | N/A — release builds strip debug actions entirely | N/A |
| Rebinding persistence path | `user://settings.cfg`, section `[input]` | Locked — per ADR-0003 settings separation | N/A | N/A |
| Action name registry | `InputActions` static class constants | Locked — adding an action requires GDD amendment + Events.gd taxonomy review if the action emits cross-system events | N/A | N/A |

### NOT owned by this GDD (tuning lives in the consumer)

- `mouse_sensitivity_x`, `mouse_sensitivity_y` → Player Character
- `gamepad_look_sensitivity` → Player Character
- `sprint_speed_multiplier`, `crouch_speed_multiplier` → Player Character
- `crouch_noise_multiplier`, `sprint_noise_multiplier` → Stealth AI
- `ads_zoom_multiplier` → Combat & Damage

If a future playtest reveals that a sensitivity value belongs project-wide rather than per-consumer, promote it here and mark the consumer GDD as deferring to this source.

## Visual/Audio Requirements

**None.** Input has no visual or audio output. Consumers of input actions may produce feedback (click SFX in Menu System, weapon fire SFX in Combat & Damage), but those reactions are owned by the consuming system's GDD, not by Input.

## UI Requirements

**None.** Input has no UI of its own. The in-game rebinding UI (Vertical Slice scope) is **owned by Settings & Accessibility** (system 23), which queries Input via `InputMap.action_get_events()` for current bindings and commits changes via `InputMap.action_erase_events()` + `InputMap.action_add_event()`. Settings' GDD owns the rebinding screen design, conflict-detection UI, and persistence to `user://settings.cfg`.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| **Settings GDD CR-22 (binding-owner-of-record)** | `design/gdd/settings-accessibility.md` line 143 | Differentiated defaults: `use_gadget = KEY_F / JOY_BUTTON_Y`, `takedown = KEY_Q / JOY_BUTTON_X`. Section C action catalog defaults MUST match CR-22 exactly. | Authoritative source for default keybindings |
| ADR-0004 input routing & mandated actions (status: **Proposed**) | `docs/architecture/adr-0004-ui-framework.md` | `ui_cancel` = Esc + B/Circle; `interact` = E + A/Cross; InputContext autoload push/pop; `_unhandled_input()` dismiss pattern; canonical `Context` enum (currently missing `LOADING`) | Rule dependency — Input provides actions; ADR-0004 routes events. **Proposed status auto-blocks consuming sprints; LOADING amendment required.** |
| ADR-0002 signal policy | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | Engine signals (including `Input.joy_connection_changed`) NOT re-emitted through Events bus — systems subscribe directly via `get_tree()` | Rule dependency |
| ADR-0003 settings persistence | `docs/architecture/adr-0003-save-format-contract.md` | Settings (including input rebindings) live in `user://settings.cfg` `[controls]` section, separate from SaveGame | Rule dependency — scope of persistence |
| ADR-0007 autoload load order | `docs/architecture/adr-0007-autoload-load-order-registry.md` | InputContext autoload loads at the position registered in ADR-0007. Consumers querying `InputContext.current()` from `_ready()` rely on this load-order guarantee. | Rule dependency — load-order contract |
| Signal Bus GDD subscriber lifecycle | `design/gdd/signal-bus.md` | Consumers of input actions follow the same `_ready()` connect / `_exit_tree()` disconnect pattern for Events signals they ALSO subscribe to | Rule dependency (for subscribers that consume both Input actions and Events signals) |
| Inventory & Gadgets CR-4 (PRE-IMPL GATE — pending amendment) | `design/gdd/inventory-gadgets.md` line 117 | Currently references the retired shared-binding + `TAKEDOWN_OR_GADGET` model. Must be amended to read `&"use_gadget"` directly in Inventory's own handler. | Coordination dependency |
| Combat & Damage CR-3 (PRE-IMPL GATE — pending confirmation) | `design/gdd/combat-damage.md` | `takedown` is a dedicated Input action; Combat's handler reads `&"takedown"` only, no router dispatch into Inventory. | Coordination dependency |
| `technical-preferences.md` platform section | `.claude/docs/technical-preferences.md` | Platform: PC Linux+Windows; Primary KB/M; Gamepad Partial (no rebinding parity at MVP) | Constraint source |

## Acceptance Criteria

> *Note: Input-related end-user feel criteria (e.g., "aim feels responsive," "mouse sensitivity feels natural") are owned by Player Character and Combat GDDs — those systems consume Input and define the feel. This GDD's criteria validate the Input contract itself.*
>
> *Story-type tags follow `coding-standards.md` matrix: **[Logic]** (unit-testable formulas / state), **[Integration]** (multi-system), **[Visual]** (screenshots), **[UI]** (manual walkthrough), **[Config]** (smoke check), **[Code-Review]** (grep / static analysis). All ACs below are BLOCKING unless explicitly marked ADVISORY.*

### Action catalog integrity

1. **AC-INPUT-1.1 [Logic] BLOCKING.** **GIVEN** the project's `InputMap`, **WHEN** the test fixture `tests/fixtures/input/expected_bindings.yaml` is iterated (one row per Section C action), **THEN** for every row, `InputMap.action_has_event(action_name, event)` returns `true` for the listed default keyboard event AND for the listed default gamepad event (where present). Evidence: `tests/unit/input/input_action_catalog_test.gd`.
2. **AC-INPUT-1.2 [Code-Review] BLOCKING.** **GIVEN** the source tree, **WHEN** the CI command `grep -rPn '(?<!&)"[a-z][a-z0-9_]+"\s*\)' src/ --include="*.gd" | grep -vE 'InputActions\.|class_name|extends'` is run, **THEN** zero matches outside the `res://src/core/input/input_actions.gd` declarations themselves. (Heuristic — flags double-quoted lowercase identifiers passed as function arguments; `&"foo"` StringName literals correctly skipped.) Evidence: `tools/ci/check_action_literals.sh`.
3. **AC-INPUT-1.3 [Logic] BLOCKING.** **GIVEN** `res://src/core/input/input_actions.gd`, **WHEN** its constants are enumerated via reflection in the test, **THEN** it declares exactly **36 constants** (33 gameplay/UI + 3 debug); the count of constants equals the count of rows in Section C; every constant value is a StringName literal that satisfies `InputMap.has_action(value)`. Evidence: `tests/unit/input/input_actions_constants_test.gd`.

### Context gating

4. **AC-INPUT-2.1 [Logic] BLOCKING** *(rewritten 2026-04-27 to test the gate condition Input owns; per-system early-return tests live in each consumer's GDD)*. **GIVEN** `InputContext.push(Context.MENU)` is called, **WHEN** `InputContext.is_active(Context.GAMEPLAY)` is queried, **THEN** it returns `false`; **WHEN** `InputContext.is_active(Context.MENU)` is queried, **THEN** it returns `true`. Evidence: `tests/unit/input/input_context_gate_test.gd`.
5. **AC-INPUT-2.2 [Integration] BLOCKING.** **GIVEN** Menu System and Document Overlay scenes both loaded as test fixtures with `InputContext.current() == GAMEPLAY`, **WHEN** an `InputEventKey` for `Esc` is injected via `Input.parse_input_event()`, **THEN** Menu System's pause handler runs (verify via `pause_menu_opened` signal subscription) and Document Overlay's dismiss handler does NOT run (verify via subscription that records 0 calls). Evidence: `tests/integration/input/input_context_routing_test.gd::test_esc_in_gameplay_routes_to_pause`.
6. **AC-INPUT-2.3 [Integration] BLOCKING.** **GIVEN** Menu System and Document Overlay scenes both loaded with `InputContext.current() == DOCUMENT_OVERLAY`, **WHEN** an `InputEventKey` for `Esc` is injected, **THEN** Document Overlay's dismiss handler runs and Menu System's pause handler does NOT. Evidence: `tests/integration/input/input_context_routing_test.gd::test_esc_in_overlay_routes_to_dismiss`.

### Dual-focus dismiss

7. **AC-INPUT-3.1 [Integration] BLOCKING — parametrized over input modality.** **GIVEN** a modal Document Overlay is open, **WHEN** the test parametrizes over `[keyboard_esc, gamepad_b, mouse_click_outside]` and injects each, **THEN** the dismiss handler fires regardless of which element has focus. Three sub-cases must all pass. Evidence: `tests/integration/input/dual_focus_dismiss_test.gd::test_dismiss_via_modality[*]`.
8. **AC-INPUT-3.2 [Code-Review] BLOCKING.** **GIVEN** the source tree, **WHEN** every modal dismiss handler is identified via `grep -rPn 'InputContext\.pop\(\)' src/ --include="*.gd"`, **THEN** every handler matched contains a `set_input_as_handled()` call BEFORE its `InputContext.pop()` call (Core Rule 7 order-of-operations — silent-swallow prevention). Evidence: `tools/ci/check_dismiss_order.sh`.

### Rebinding (Vertical Slice scope)

9. **AC-INPUT-4.1 [Logic] BLOCKING (VS).** **GIVEN** a fresh `InputMap` with `move_forward` bound to `W`, **WHEN** the test calls `InputMap.action_erase_events(&"move_forward")` then `InputMap.action_add_event(&"move_forward", new_event_T)`, **THEN** an injected `InputEventKey(T, pressed=true)` causes `event.is_action_pressed(&"move_forward")` to return `true`, AND an injected `InputEventKey(W, pressed=true)` causes it to return `false`. Evidence: `tests/unit/input/input_rebind_runtime_test.gd`.
10. **AC-INPUT-4.2 [Logic] BLOCKING (VS) — split into two.** **(a)** [Input scope] **GIVEN** an attempt to rebind action A to event E that is already bound to action B, **WHEN** `InputMap.has_event(E)` is queried before the bind, **THEN** it returns `true` (the conflict-detection primitive Input owns). **(b)** [Settings scope — moved to Settings GDD] The conflict-resolution UI behavior (refuse / offer-unbind) is verified in Settings GDD AC-SA-6.3, not here. Evidence: `tests/unit/input/input_has_event_test.gd`.
11. **AC-INPUT-4.3 [Integration] BLOCKING (VS).** **GIVEN** a clean test environment with `ProjectSettings.globalize_path("user://test_settings.cfg")` resolved to a temp path, **WHEN** the test (a) writes a known rebinding `move_forward → T` to that file, (b) restarts input loading from that path, (c) injects an `InputEventKey(T)`, **THEN** `event.is_action_pressed(&"move_forward")` returns `true`. Test tears down the temp file in `_exit_tree()` (per `coding-standards.md` Isolation rule). Evidence: `tests/integration/input/input_rebind_persistence_test.gd`.
12. **AC-INPUT-4.4 [Integration] BLOCKING (VS) — full round-trip.** **GIVEN** a clean test environment, **WHEN** the test sequence (a) rebinds `move_forward → T` via Settings API, (b) writes `user://test_settings.cfg`, (c) clears the runtime `InputMap` for the action, (d) re-loads the cfg from disk, (e) injects `InputEventKey(T)`, **THEN** `event.is_action_pressed(&"move_forward")` returns `true`. Round-trip atomic. Evidence: `tests/integration/input/rebind_round_trip_test.gd`.

### Edge case behavior

13. **AC-INPUT-5.1 [Logic] BLOCKING.** **GIVEN** `Input.parse_input_event(InputEventKey(W, pressed=true))` has been called and `Input.is_action_pressed(&"move_forward")` returns `true`, **WHEN** the test calls `InputContext.push(Context.MENU)` and then `InputContext.pop()`, **THEN** `Input.is_action_pressed(&"move_forward")` still returns `true` (held-key state persists through context transitions). Evidence: `tests/unit/input/held_key_through_context_test.gd`.
14. **AC-INPUT-5.2 [Logic] BLOCKING.** **GIVEN** the test calls `Input.emit_signal("joy_connection_changed", 0, false)` (gamepad 0 disconnect), **WHEN** the signal is processed, **THEN** `Input.is_action_pressed(&"move_forward")` continues to return the expected value for held KB input AND no `pause` action is emitted by Input itself (pause-on-disconnect is Menu System's concern, verified in Menu's GDD). Evidence: `tests/unit/input/joy_disconnect_test.gd`.
15. **AC-INPUT-5.3 [Code-Review] BLOCKING — debug-action gating mechanism.** **GIVEN** the `InputActions` static class source AND `project.godot`, **WHEN** the file is grep-checked, **THEN** **(a)** debug action constants (`debug_toggle_ai`, `debug_noclip`, `debug_spawn_alert`) do NOT appear in `project.godot` — they are runtime-registered only; **(b)** the runtime registration block in `InputActions._register_debug_actions()` (or equivalent) is wrapped in `if OS.is_debug_build():` AND uses `InputMap.add_action()` + `InputMap.action_add_event()` for each debug action. **Mechanism**: handler-gated registration per CD synthesis 2026-04-27. `project.godot` cannot conditionally strip per-build-type, so debug actions are absent from `project.godot` and registered at runtime in debug builds only. Evidence: `tools/ci/check_debug_action_gating.sh`.

### Anti-pattern enforcement

16. **AC-INPUT-6.1 [Code-Review] BLOCKING.** **GIVEN** the source tree, **WHEN** the CI command `grep -rPn '\b(KEY_|JOY_BUTTON_|JOY_AXIS_|MOUSE_BUTTON_)[A-Z_]+' src/ --include="*.gd" | grep -vE 'OS\.is_debug_build|^src/core/input/'` is run, **THEN** zero matches outside the `InputActions` class itself and outside `OS.is_debug_build()`-gated blocks. All input checks MUST route through `InputMap` actions (Core Rule 1 — extended grep covers KB / gamepad button / gamepad axis / mouse button raw constants). Evidence: `tools/ci/check_raw_input_constants.sh`.
17. **AC-INPUT-6.2 [Code-Review] BLOCKING.** **GIVEN** the source tree, **WHEN** the CI command `grep -rPn 'InputMap\.action_add_event\(' src/ --include="*.gd"` is run, **THEN** for every match, the immediately preceding 5 lines contain an `InputMap.has_action(` check on the same action name (Core Rule 6 — prevents silent duplicate-action creation on misspelled action names). Evidence: `tools/ci/check_action_add_event_validation.sh`.
18. **AC-INPUT-6.3 [Code-Review] ADVISORY.** **GIVEN** the source tree, **WHEN** the CI command `grep -rPn 'func _input\s*\(' src/ --include="*.gd" | grep -vE 'OS\.is_debug_build|^src/core/input/|tools/'` is run, **THEN** every match is accompanied by a code-review-approved comment justifying use of `_input()` over `_unhandled_input()` (Core Rule 1 — `_unhandled_input()` is the project default; `_input()` is reserved for input-eating priority cases like debug overlays). Evidence: `tools/ci/check_unhandled_input_default.sh`.

### Order-of-operations + mouse mode (NEW — Core Rules 7, 8)

19. **AC-INPUT-7.1 [Integration] BLOCKING.** **GIVEN** a modal dismiss handler that calls `set_input_as_handled()` then `InputContext.pop()`, **WHEN** an `Esc` event is injected during a context-transition test fixture, **THEN** the gameplay handler does NOT receive a propagated `Esc` event (verify via subscriber-call-count assertion = 0 on gameplay handler). Evidence: `tests/integration/input/esc_consume_before_pop_test.gd`.
20. **AC-INPUT-7.2 [Integration] BLOCKING.** **GIVEN** Player Character is in `InputContext.GAMEPLAY` and `Input.mouse_mode == MOUSE_MODE_CAPTURED`, **WHEN** the test pushes `InputContext.MENU` (modal opens, sets `MOUSE_MODE_VISIBLE`) and pops back to `GAMEPLAY`, **THEN** Player Character's gameplay-context-restore restores `MOUSE_MODE_CAPTURED` (verify via `Input.mouse_mode` assertion). Evidence: `tests/integration/input/mouse_mode_restore_test.gd`.
21. **AC-INPUT-7.3 [Integration] BLOCKING (VS).** **GIVEN** `Input.parse_input_event(InputEventKey(W, pressed=true))` and `move_forward → W` binding, **WHEN** the test rebinds `move_forward → T` via `action_erase_events` + `action_add_event`, **THEN** Settings calls `Input.action_release(&"move_forward")` immediately after, AND `Input.is_action_pressed(&"move_forward")` returns `false` until the player presses `T` (Core Rule 9 held-key flush). Evidence: `tests/integration/input/rebind_held_key_flush_test.gd`.

### `InputContext.LOADING` push/pop (NEW — DEPENDS ON ADR-0004 AMENDMENT)

22. **AC-INPUT-8.1 [Integration] BLOCKED — pending ADR-0004 LOADING amendment.** **GIVEN** Level Streaming pushes `InputContext.LOADING` at transition step 1, **WHEN** the test injects an `InputEventKey` for `fire_primary` during the LOADING context, **THEN** Combat's `_unhandled_input` handler's `InputContext.is_active(GAMEPLAY)` check returns `false` and no shot is fired; **WHEN** `F5` is injected, **THEN** Save/Load's quicksave handler returns early (Save/Load gates on LOADING). Evidence: `tests/integration/input/loading_context_gate_test.gd`. **Test cannot be authored until ADR-0004 LOADING enum value is approved.**

### Foundational class location + autoload load order (NEW)

23. **AC-INPUT-9.1 [Config] BLOCKING.** **GIVEN** the project source tree, **WHEN** the file `res://src/core/input/input_actions.gd` is checked for existence AND contains `class_name InputActions`, **THEN** both checks pass (closes Open Question #5 — file path + global-class-name resolution). No system uses `preload("res://src/core/input/...")` literal paths; all imports go through the `class_name` global. Evidence: `tests/unit/input/input_actions_path_test.gd`.
24. **AC-INPUT-9.2 [Logic] BLOCKING.** **GIVEN** project autoload registry per ADR-0007, **WHEN** the test queries `Engine.get_main_loop().get_root().get_node("/root/InputContext")` from a `_ready()` callback in a test scene, **THEN** the node resolves successfully (autoload has loaded before consuming scenes — load-order guarantee). Evidence: `tests/unit/input/input_context_autoload_load_order_test.gd`.

### Quicksave/Quickload diegetic feedback (NEW — Pillar 5 carve-out contract)

25. **AC-INPUT-10.1 [Integration] BLOCKING (forward dep on HUD Core).** **GIVEN** the player presses `quicksave` (F5) in `InputContext.GAMEPLAY`, **WHEN** Save/Load's handler completes the save, **THEN** HUD Core renders a ~1.5s diegetic dossier-register confirmation toast. Toast widget is HUD Core's responsibility; Input verifies only that the F5 keypress fired the action. Evidence: HUD Core integration test (path TBD when HUD Core GDD is authored).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| ~~`use_gadget` context-resolution priority~~ | — | — | **CLOSED 2026-04-27** — `takedown` and `use_gadget` are now two distinct InputMap actions on two distinct default keys per Settings CR-22 (`takedown=Q/JOY_BUTTON_X`, `use_gadget=F/JOY_BUTTON_Y`). No router needed; no priority decision needed. |
| ~~Should MVP include a `pickup_alternate` key as a safety-valve if `interact` overloading proves confusing during Tier 0 playtest?~~ | — | — | **CLOSED 2026-04-27** — `interact` priority queue is now a hard rule: document > terminal > item > door, with tie-breaker by raycast distance (closest target wins on ties). Level-design constraint added: **Level designers MUST NOT co-locate competing interact targets within 1.5 m of a single raycast hit.** Enforced via Mission & Level Scripting authoring contract; CI lint flags violations. No `pickup_alternate` action ships at MVP. |
| Gamepad rebinding parity timeline: is it a true post-MVP deferral, or a Vertical Slice scope item? | Producer | Before Settings GDD authoring | Per `technical-preferences.md`: Partial = full menu + gameplay navigation; rebinding parity is post-MVP. Confirm this stays the rule. |
| ~~Mouse sensitivity and gamepad look-sensitivity multipliers location~~ | — | — | **CLOSED 2026-04-27** — Resolved by Player Character GDD (Approved 2026-04-21) + Settings GDD C.2 (`mouse_sensitivity_x`, `mouse_sensitivity_y`, `gamepad_look_sensitivity`, `invert_y_axis` under `[controls]` category). Player Character defines defaults; Settings provides runtime override persisted to `user://settings.cfg`. |
| ~~`InputActions` static class location~~ | — | — | **CLOSED 2026-04-27** — `res://src/core/input/input_actions.gd` is the canonical location; consumers import via `class_name InputActions` global, never via `preload(...)` literal path. AC-INPUT-9.1 verifies. |
