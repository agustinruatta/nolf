# Epic: Input

> **Layer**: Core (per `architecture.md` §3.2 — Input is Core despite its GDD's Quick-reference labelling it Foundation)
> **GDD**: `design/gdd/input.md`
> **Architecture Module**: Input — `InputContext` autoload + `InputActions` static class (`architecture.md` §3.2)
> **Engine Risk**: MEDIUM (SDL3 gamepad backend 4.5+; dual-focus split 4.6 sidestepped via `_unhandled_input` + `ui_cancel`)
> **Status**: Ready (with note: governing ADR-0004 is Proposed pending G5 — BBCode AccessKit serialization — for unrelated formatted-body scope; Input-relevant clauses are validated)
> **Stories**: Not yet created — run `/create-stories input`
> **Manifest Version**: 2026-04-30

## Overview

Input is the Core-layer system that owns all action-binding, context-routing, and runtime-rebinding for *The Paris Affair*. It registers 30 named InputMap actions (27 gameplay/UI + 3 debug) backed by `InputActions.*` StringName constants, and exposes the `InputContext` autoload (line 4 per ADR-0007) whose stack-structured Context enum gates which inputs route to which handlers (`{GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, CUTSCENE, MODAL, LOADING, SETTINGS}`). Every `_unhandled_input` handler in the project queries `InputContext.is_active(GAMEPLAY)` (or the relevant context) before consuming events; this discipline replaces the engine's 4.6 dual-focus mouse/keyboard split with a single, project-owned routing mechanism per ADR-0004's `_unhandled_input + ui_cancel` strategy.

Input also owns runtime rebinding (via `InputMap.action_erase_events` + `action_add_event`) and persistence to `user://settings.cfg` per ADR-0003. Gamepad support is partial at MVP — full menu/gameplay navigation works; rebinding parity is post-MVP per `technical-preferences.md`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0004: UI Framework (Theme + InputContext + FontRegistry) | Owns the InputContext autoload + Context enum; mandates `_unhandled_input + ui_cancel` discipline; `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` for declarative bindings; `ui_cancel` is the universal back/dismiss action | MEDIUM |
| ADR-0007: Autoload Load Order Registry | `InputContext` at autoload line 4 (after `Events`, `EventLogger`, `SaveLoad`); cross-autoload reference safety; `*res://` scene-mode prefix; `InputContext.Context` enum owned by `InputContextStack` per ADR-0002 enum-ownership rule | LOW |
| ADR-0002: Signal Bus + Event Taxonomy | Owns `Events.ui_context_changed(new: InputContext.Context, old: InputContext.Context)` (added 2026-04-28) — InputContextStack is sole publisher; HUD State Signaling and Document Overlay UI subscribe | LOW |

**Status note**: ADR-0004 is currently `Proposed` overall pending Gate 5 (`RichTextLabel` BBCode → AccessKit plain-text serialization, runtime AT testing). Gates 1–4 are CLOSED as of 2026-04-29 Sprint 01 verification — including G4 (`auto_translate_mode` enum identifiers verified). Input-relevant clauses (InputContext autoload + Context enum + `ui_cancel` discipline) are fully validated. Per Localization Scaffold's precedent (Stories may proceed against ADR-0004's in-scope clauses without G5 closure), Input stories may proceed.

## GDD Requirements

The `input.md` GDD specifies:

- 30 named InputMap actions (27 gameplay/UI + 3 debug)
- `InputActions` static class declaring all action StringName constants (e.g., `MOVE_FORWARD`, `JUMP`, `INTERACT`, `FIRE`, `TAKEDOWN`, `AIM`, `USE_GADGET`, `SWITCH_WEAPON`, `QUICKSAVE`, `QUICKLOAD`, `PAUSE`, `INVENTORY`, `MAP`, etc.)
- `InputContext` autoload (`class_name InputContextStack`) with stack-structured Context enum `{GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, CUTSCENE, MODAL, LOADING, SETTINGS}`
- Push/pop discipline: `InputContext.push(ctx)` / `InputContext.pop(ctx)` / `is_active(ctx) -> bool` / `current() -> Context`
- `_unhandled_input` + `ui_cancel` discipline per ADR-0004 — every handler queries `InputContext.is_active(...)` before consuming events
- Runtime rebinding via `InputMap.action_erase_events` + `action_add_event`; persists to `user://settings.cfg [input]` section
- Locale-aware glyph display (post-MVP — gamepad button glyphs)
- Forbidden patterns: `direct_input_global_query` (skipping the InputContext gate), `unregistered_action` (using `Input.is_action_*` with a string literal not in InputActions), `cross_context_event_consumption` (handler consuming an event without checking context)

Specific requirement IDs `TR-INP-001` through `TR-INP-010` (10 TRs) are in `docs/architecture/tr-registry.yaml`.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/input.md` are verified.
- `InputContextStack` autoload registered at line 4 of `project.godot [autoload]` per ADR-0007.
- All 30 InputMap actions are registered in `project.godot [input]` block AND in `InputActions` static class as StringName constants.
- `InputContext.push/pop/is_active/current` API works; stack discipline enforced (LIFO push/pop).
- `Events.ui_context_changed(new, old)` fires on every push/pop transition (per ADR-0002 2026-04-28 amendment).
- Runtime rebinding persists to `user://settings.cfg`; restored on game launch.
- Forbidden patterns registered in `docs/registry/architecture.yaml` + CI grep guards.
- Logic stories have passing unit tests; integration stories cover at least one full context-stack scenario (e.g., GAMEPLAY → DOCUMENT_OVERLAY → pop → GAMEPLAY).

## Verification Spike Status (Sprint 01, 2026-04-29)

ADR-0004 G1 (AccessKit description property), G2 (`Control.accessibility_description` set/get), G3 (Theme-typed lookup), G4 (`auto_translate_mode` enum identifiers) all CLOSED. The `InputContext` autoload script stub exists at `src/core/ui/input_context.gd` (extends `Node`, `_ready()` pass-through) — production implementation replaces this stub. ADR-0007 G(a) + G(b) verified — autoload line-4 placement is proven safe.

## Next Step

Run `/create-stories input` to break this epic into implementable stories.
