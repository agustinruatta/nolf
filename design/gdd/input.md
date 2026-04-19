# Input

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (gameplay-programmer, ux-designer per routing)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Foundation infrastructure — indirectly serves Pillar 5 (Period Authenticity: no modern UX conveniences in the input layer)

## Summary

Input is the project's action-mapping layer — a Godot `InputMap`-based abstraction that translates keyboard, mouse, and gamepad events into named actions (move, jump, fire, interact, ui_cancel, etc.) that every system consumes by name. The Input system defines the canonical action set, the default KB/M and gamepad bindings, and the contract by which downstream systems read input. Rebinding is scoped to Settings & Accessibility (Vertical Slice, post-MVP for gamepad parity); ADR-0004 locks two specific UI-related actions (`ui_cancel`, `interact`).

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None (foundational)` · Related ADR: ADR-0004 (UI Framework mandates ui_cancel + interact actions)

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

## Detailed Design

### Core Rules

1. **Every cross-system input read goes through `InputMap`.** No system reads raw `KEY_*` constants directly (except for in-development debug keys gated by `OS.is_debug_build()`). All input queries use named actions via `event.is_action_pressed(&"action_name")` (event-driven) or `Input.is_action_pressed(&"action_name")` / `Input.get_vector(...)` (polling).
2. **Action names are canonical — use StringName literals project-wide.** All action references use `&"action_name"` (StringName). A typed `InputActions` static class declares every action as a `const NAME := &"name"` constant; systems import from it rather than spelling inline. This makes misspelled actions a compile-detectable error, not a silent runtime miss.
3. **InputContext (ADR-0004) gates gameplay input.** Every gameplay `_unhandled_input()` handler checks `InputContext.is_active(InputContext.Context.GAMEPLAY)` and returns early if not active. Modal surfaces (Menu, Document Overlay, Pause, Settings) push/pop their own context; when a modal is open, gameplay actions like `fire_primary` do not fire even if the player presses the bound key.
4. **Modal dismiss uses `_unhandled_input()` + `ui_cancel` action** (per ADR-0004). Dismiss is NEVER bound to a focused Button widget. This sidesteps Godot 4.6's dual-focus split (mouse/touch focus vs keyboard/gamepad focus).
5. **`get_viewport().set_input_as_handled()` MUST be called** after a handler consumes an event. Without it, the event continues propagating and may trigger other handlers. This is a code-review checkpoint for every system's input handlers.
6. **Rebinding at runtime uses `InputMap.action_erase_events()` + `InputMap.action_add_event()`** per action. Persistence serializes `InputEvent` subclass fields manually to `user://settings.cfg` (per ADR-0003 — settings are separate from SaveGame); `InputEvent` is not directly ConfigFile-serializable.
7. **Esc is dual-role via InputContext.** In `InputContext.GAMEPLAY`: `Esc` fires `pause`. In any modal context: `Esc` fires `ui_cancel`. Both actions are bound to `Esc`, resolved by the context gate in step 3. No double-handling bug because the context-inactive handler returns early.

### States and Transitions

**Stateless.** Input has no states of its own. `InputMap` is loaded at project startup from `project.godot` and persists for the lifetime of the application. Runtime rebinding mutates `InputMap` immediately — no state transitions between "legacy bindings" and "new bindings"; the change is atomic.

### Interactions with Other Systems

#### Action catalog (26 gameplay/UI + 3 debug = 29 actions)

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
| `weapon_slot_1` | `1` | — | Press | Inventory & Gadgets |
| `weapon_slot_2` | `2` | — | Press | Inventory & Gadgets |
| `weapon_slot_3` | `3` | — | Press | Inventory & Gadgets |
| `weapon_slot_4` | `4` | — | Press | Inventory & Gadgets |
| `weapon_slot_5` | `5` | — | Press | Inventory & Gadgets |
| `weapon_next` | `Mouse Wheel Up` | `JOY_BUTTON_DPAD_RIGHT` | Press | Inventory & Gadgets |
| `weapon_prev` | `Mouse Wheel Down` | `JOY_BUTTON_DPAD_LEFT` | Press | Inventory & Gadgets |

**Group 3 — Gadgets**

| Action | KB/M Default | Gamepad Default | Type | Consumer |
|---|---|---|---|---|
| `use_gadget` | `F` | `JOY_BUTTON_Y` | Press | Inventory & Gadgets — **context-resolves to takedown** when within melee range of an unaware guard; else activates equipped gadget. Priority rules live in Combat & Damage and Inventory GDDs. |
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
| Combat & Damage | Combat, Gadgets (takedown resolution) |
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

One implementation note for consumers (not a formula this GDD owns): `Input.get_vector()` applies its own deadzone and normalization when reading axis actions — this is engine-level behavior, configurable via the 4th parameter to `get_vector()`, and is exposed to consuming systems as a tuning knob in the consumer's GDD.

## Edge Cases

- **If the player presses a bound key while the corresponding `InputContext` is not active** → the handler returns early at the `InputContext.is_active()` check; the event is not consumed and continues propagating. **Resolution**: intended. Per Core Rule 3, every handler MUST gate by context. Missing gates are bugs.
- **If two actions bind to the same key (e.g., `Esc` → both `pause` and `ui_cancel`)** → Godot dispatches the event to `_unhandled_input()`; both actions match when tested via `event.is_action_pressed()`. **Resolution**: intended. Per Core Rule 7 (Esc dual-role), the context gate resolves which handler actually processes. The gameplay handler checks `InputContext.GAMEPLAY` and fires `pause`; the modal handler checks its own context and fires `ui_cancel`. Only one runs per event because the other context is inactive.
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

- **ADR-0004 (UI Framework)**: mandates `ui_cancel` = Esc + B/Circle and `interact` = E + A/Cross. InputContext autoload governs modal input routing. Input GDD provides the actions; ADR-0004 owns the routing stack.
- **ADR-0002 (Signal Bus)**: no direct dependency. If Input ever needs to emit cross-system events (e.g., `input_rebound(action_name)` for Settings), that signal must be added to `Events.gd` per ADR-0002 policy. Currently no such event is needed.
- **ADR-0003 (Save Format)**: Input rebinding config lives in `user://settings.cfg` (ConfigFile), separate from SaveGame. ConfigFile serialization of `InputEvent` subclass fields is manual.
- **ADR-0001 (Stencil)**: no interaction.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `InputMap` default bindings | Per Section C catalog | Locked (changes to ADR-0004-mandated actions require ADR amendment; any action may be runtime-rebound via Settings) | N/A | N/A |
| `Input.get_vector(...)` deadzone | Godot default (`0.2`) on axis actions; surfaced as 4th parameter | `0.05` – `0.35` | Larger = more tolerant of controller drift, less precise small movements | Smaller = more precise, may register unintended micro-movements from worn sticks |
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
| ADR-0004 input routing & mandated actions | `docs/architecture/adr-0004-ui-framework.md` | `ui_cancel` = Esc + B/Circle; `interact` = E + A/Cross; InputContext autoload push/pop; `_unhandled_input()` dismiss pattern | Rule dependency — Input provides actions; ADR-0004 routes events |
| ADR-0002 signal policy | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | Engine signals (including `Input.joy_connection_changed`) NOT re-emitted through Events bus — systems subscribe directly via `get_tree()` | Rule dependency |
| ADR-0003 settings persistence | `docs/architecture/adr-0003-save-format-contract.md` | Settings (including input rebindings) live in `user://settings.cfg`, separate from SaveGame | Rule dependency — scope of persistence |
| Signal Bus GDD subscriber lifecycle | `design/gdd/signal-bus.md` | Consumers of input actions follow the same `_ready()` connect / `_exit_tree()` disconnect pattern for Events signals they ALSO subscribe to | Rule dependency (for subscribers that consume both Input actions and Events signals) |
| `technical-preferences.md` platform section | `.claude/docs/technical-preferences.md` | Platform: PC Linux+Windows; Primary KB/M; Gamepad Partial (no rebinding parity at MVP) | Constraint source |

## Acceptance Criteria

> *Note: Input-related end-user feel criteria (e.g., "aim feels responsive," "mouse sensitivity feels natural") are owned by Player Character and Combat GDDs — those systems consume Input and define the feel. This GDD's criteria validate the Input contract itself.*

### Action catalog integrity

1. **GIVEN** the project's `InputMap`, **WHEN** the default bindings are loaded at startup, **THEN** every action listed in Section C is registered with the exact default binding (KB/M + gamepad where specified).
2. **GIVEN** any system source file, **WHEN** grepped for String-literal action references (e.g., `"move_forward"` with double quotes), **THEN** zero matches — all action references MUST use `InputActions.NAME` constants (StringName literals).
3. **GIVEN** `res://src/core/input/input_actions.gd`, **WHEN** its constants are enumerated, **THEN** it declares exactly one `const` per action in the Section C catalog (26 gameplay/UI + 3 debug = 29 constants).

### Context gating

4. **GIVEN** `InputContext.current() == MENU`, **WHEN** the player presses the key bound to `fire_primary`, **THEN** Combat & Damage's `_unhandled_input()` handler returns early; no shot is fired.
5. **GIVEN** `InputContext.current() == GAMEPLAY`, **WHEN** the player presses `Esc`, **THEN** Menu System's pause handler runs (opens pause menu) and Document Overlay's dismiss handler does NOT run.
6. **GIVEN** `InputContext.current() == DOCUMENT_OVERLAY`, **WHEN** the player presses `Esc`, **THEN** Document Overlay's dismiss handler runs (closes overlay) and Menu System's pause handler does NOT run.

### Dual-focus dismiss

7. **GIVEN** a modal Document Overlay is open, **WHEN** the player dismisses via keyboard (`Esc`) OR gamepad (`B/Circle`) OR mouse (clicking outside the card), **THEN** the dismiss handler fires regardless of which element has focus.
8. **GIVEN** any modal dismiss handler, **WHEN** it processes a `ui_cancel` event, **THEN** `get_viewport().set_input_as_handled()` is called to stop event propagation.

### Rebinding (Vertical Slice scope)

9. **GIVEN** the rebinding UI (owned by Settings) captures a new event for an action, **WHEN** it commits via `InputMap.action_erase_events(name)` + `InputMap.action_add_event(name, event)`, **THEN** the next input test of that action reflects the new binding.
10. **GIVEN** a rebind attempts to assign a key already bound to another action, **WHEN** the rebinding UI evaluates the conflict, **THEN** the UI refuses or offers to unbind the conflicting action (UI behavior owned by Settings; Input provides `InputMap.has_event()` for the check).
11. **GIVEN** the player rebinds an action and closes the Settings menu, **WHEN** the game is restarted, **THEN** the rebinding persists — loaded from `user://settings.cfg` at startup.

### Edge case behavior

12. **GIVEN** the player holds `move_forward` while opening the pause menu and closing it, **WHEN** `InputContext` returns to `GAMEPLAY`, **THEN** `Input.is_action_pressed(&"move_forward")` returns `true` (held-key state persists through context transitions).
13. **GIVEN** a gamepad disconnects mid-gameplay, **WHEN** the `Input.joy_connection_changed` signal fires, **THEN** KB/M input continues to work uninterrupted; Input does NOT auto-pause (pause is owned by Menu System's subscriber to that signal).
14. **GIVEN** a debug key (F1/F2/F3) is pressed in a release build, **WHEN** the event is processed, **THEN** no debug action fires — release builds strip debug actions from `project.godot`.

### Anti-pattern enforcement

15. **GIVEN** any system source file, **WHEN** grepped for direct reads of `KEY_*` constants in `_input()` or `_unhandled_input()` handlers (excluding debug-gated code), **THEN** zero matches — all input checks MUST route through `InputMap` actions. *Classification: code-review checkpoint.*
16. **GIVEN** any system source file, **WHEN** grepped for runtime `InputMap.action_add_event()` calls, **THEN** every such call is paired with a `InputMap.has_action()` check on the action name (prevents silent duplicate-action creation).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| `use_gadget` context-resolution priority: when Eve is both near an unaware guard AND holding an active gadget (e.g., lockpick), which action does F trigger? | Combat & Damage GDD author + Inventory & Gadgets GDD author | Resolved during those two GDDs' authoring | Recommendation: takedown takes precedence ONLY when the guard is within ≤1.5m melee range; else gadget. Final rule lives in Combat & Damage GDD. |
| Should MVP include a `pickup_alternate` key as a safety-valve if `interact` overloading proves confusing during Tier 0 playtest? | Game designer | After Tier 0 playtest | Ship without it at MVP; add if playtest feedback shows `interact` context resolution fails on dense rooms. |
| Gamepad rebinding parity timeline: is it a true post-MVP deferral, or a Vertical Slice scope item? | Producer | Before Settings GDD authoring | Per `technical-preferences.md`: Partial = full menu + gameplay navigation; rebinding parity is post-MVP. Confirm this stays the rule. |
| Mouse sensitivity and gamepad look-sensitivity multipliers: should they live in `user://settings.cfg` (Settings-managed) or in Player Character's data-driven config? | Player Character GDD author + Settings GDD author | During Player Character GDD authoring | Recommendation: both. Player Character defines sane defaults; Settings provides runtime override that persists to `settings.cfg`. |
| Should the `InputActions` static class be in `res://src/core/input/` or at a higher-level shared location (e.g., `res://src/shared/`)? | Lead programmer | Before Input implementation begins | Recommendation: `res://src/core/input/` — co-located with the Input implementation, imported by consumers via `class_name InputActions` global. |
