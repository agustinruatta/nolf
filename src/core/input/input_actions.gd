## Static class declaring every InputMap action name as a typed StringName constant.
## Import via class_name InputActions — never via preload() literal path.
## Consumers: every system that reads InputMap actions project-wide.
##
## Usage:
##   Input.is_action_pressed(InputActions.JUMP)
##   event.is_action_pressed(InputActions.FIRE_PRIMARY)
##
## Design refs: design/gdd/input.md §Section C, ADR-0004, ADR-0007.
## 36 constants total: 33 gameplay/UI + 3 debug (Group 6).
class_name InputActions
extends RefCounted

# ── Group 1: Movement ──────────────────────────────────────────────────────
## Axis-based movement: read via Input.get_vector() in _physics_process.
## Mouse X/Y motion for look_horizontal/look_vertical is read directly via
## event.relative in the Player Character controller — mouse motion events
## are not InputMap actions. The gamepad axis binding IS registered in
## project.godot for look_horizontal/look_vertical; KB/M has no button event.

## W key / JOY_AXIS_LEFT_Y (−): move the character forward.
const MOVE_FORWARD: StringName    = &"move_forward"
## S key / JOY_AXIS_LEFT_Y (+): move the character backward.
const MOVE_BACKWARD: StringName   = &"move_backward"
## A key / JOY_AXIS_LEFT_X (−): strafe left.
const MOVE_LEFT: StringName       = &"move_left"
## D key / JOY_AXIS_LEFT_X (+): strafe right.
const MOVE_RIGHT: StringName      = &"move_right"
## Mouse X / JOY_AXIS_RIGHT_X: horizontal camera rotation. No KB button event.
const LOOK_HORIZONTAL: StringName = &"look_horizontal"
## Mouse Y / JOY_AXIS_RIGHT_Y: vertical camera rotation. No KB button event.
const LOOK_VERTICAL: StringName   = &"look_vertical"
## Space / JOY_BUTTON_A (button_index=0): jump.
const JUMP: StringName            = &"jump"
## Left Ctrl / JOY_BUTTON_RIGHT_STICK (button_index=8): crouch toggle.
const CROUCH: StringName          = &"crouch"
## Left Shift / JOY_BUTTON_LEFT_STICK (button_index=7): sprint hold.
const SPRINT: StringName          = &"sprint"

# ── Group 2: Combat & Weapons ──────────────────────────────────────────────
## Press/Hold semantics: read via event.is_action_pressed() in _unhandled_input.

## Mouse Button 1 / JOY_AXIS_TRIGGER_RIGHT (axis=5, value=1.0): fire weapon.
const FIRE_PRIMARY: StringName    = &"fire_primary"
## Mouse Button 2 / JOY_AXIS_TRIGGER_LEFT (axis=4, value=1.0): aim down sights.
const AIM_DOWN_SIGHTS: StringName = &"aim_down_sights"
## R key / JOY_BUTTON_X (button_index=2): reload current weapon.
const RELOAD: StringName          = &"reload"
## Key 1 / no gamepad (VS forward dep): equip weapon slot 1.
const WEAPON_SLOT_1: StringName   = &"weapon_slot_1"
## Key 2 / no gamepad (VS forward dep): equip weapon slot 2.
const WEAPON_SLOT_2: StringName   = &"weapon_slot_2"
## Key 3 / no gamepad (VS forward dep): equip weapon slot 3.
const WEAPON_SLOT_3: StringName   = &"weapon_slot_3"
## Key 4 / no gamepad (VS forward dep): equip weapon slot 4.
const WEAPON_SLOT_4: StringName   = &"weapon_slot_4"
## Key 5 / no gamepad (VS forward dep): equip weapon slot 5.
const WEAPON_SLOT_5: StringName   = &"weapon_slot_5"
## Mouse Wheel Up / JOY_BUTTON_DPAD_RIGHT (button_index=14): cycle weapon forward.
const WEAPON_NEXT: StringName     = &"weapon_next"
## Mouse Wheel Down / JOY_BUTTON_DPAD_LEFT (button_index=13): cycle weapon backward.
const WEAPON_PREV: StringName     = &"weapon_prev"

# ── Group 3: Gadgets ───────────────────────────────────────────────────────
## takedown and use_gadget are DISTINCT actions on distinct default keys (Q / F).
## No shared-binding router. Two distinct keys = no swallowed keystrokes (Pillar 3).
## Note: takedown and reload both map to JOY_BUTTON_X on gamepad (GDD design intent).
## KB/M paths differ (Q vs R); gamepad rebinding parity is a VS forward dep.

## Q key / JOY_BUTTON_X (button_index=2): perform stealth takedown.
## Live only when SAI.takedown_prompt_active(attacker) returns true.
const TAKEDOWN: StringName        = &"takedown"
## F key / JOY_BUTTON_Y (button_index=3): activate equipped gadget.
const USE_GADGET: StringName      = &"use_gadget"
## Mouse Button 4 / JOY_BUTTON_DPAD_UP (button_index=11): cycle gadget forward.
const GADGET_NEXT: StringName     = &"gadget_next"
## Mouse Button 5 / JOY_BUTTON_DPAD_DOWN (button_index=12): cycle gadget backward.
const GADGET_PREV: StringName     = &"gadget_prev"

# ── Group 4: Interaction ───────────────────────────────────────────────────
## ADR-0004 locked: E + JOY_BUTTON_A. Resolved by Player Character raycast priority.
## Context-sensitive: document > terminal > item > door.

## E key / JOY_BUTTON_A (button_index=0): interact with world object. ADR-0004 locked.
const INTERACT: StringName        = &"interact"

# ── Group 5: UI & Menus ───────────────────────────────────────────────────
## ADR-0004 locked: ui_cancel = Esc + B/Circle; pause = Esc + START.
## Every ui_* action MUST have both KB/M AND gamepad bindings (ADR-0004 IG 14).

## Esc / JOY_BUTTON_B (button_index=1): cancel/back in menus. ADR-0004 locked.
const UI_CANCEL: StringName       = &"ui_cancel"
## Esc / JOY_BUTTON_START (button_index=6): open pause menu. ADR-0004 locked.
## JOY_BUTTON_START = button_index 6 per Godot 4.6 SDL3 driver (NOT 11).
## JOY_BUTTON_DPAD_UP = button_index 11 (different button). See GDD note.
const PAUSE: StringName           = &"pause"
## Arrow Up / JOY_BUTTON_DPAD_UP (button_index=11): navigate UI up.
const UI_UP: StringName           = &"ui_up"
## Arrow Down / JOY_BUTTON_DPAD_DOWN (button_index=12): navigate UI down.
const UI_DOWN: StringName         = &"ui_down"
## Arrow Left / JOY_BUTTON_DPAD_LEFT (button_index=13): navigate UI left.
const UI_LEFT: StringName         = &"ui_left"
## Arrow Right / JOY_BUTTON_DPAD_RIGHT (button_index=14): navigate UI right.
const UI_RIGHT: StringName        = &"ui_right"
## Enter / JOY_BUTTON_A (button_index=0): confirm selection in menus.
const UI_ACCEPT: StringName       = &"ui_accept"
## F5 / no gamepad: quick save to slot 0.
const QUICKSAVE: StringName       = &"quicksave"
## F9 / no gamepad: quick load from slot 0.
const QUICKLOAD: StringName       = &"quickload"

# ── Group 6: Debug (registered at runtime in debug builds only) ────────────
## These constants exist in the class but the actions are NOT in project.godot.
## _register_debug_actions() is called from InputContext autoload _ready(),
## wrapped in `if OS.is_debug_build():`.
## AC-INPUT-5.3: debug actions must never appear in project.godot [input].

## F1 / no gamepad: toggle Stealth AI on/off. Debug-build only.
const DEBUG_TOGGLE_AI: StringName   = &"debug_toggle_ai"
## F2 / no gamepad: toggle noclip traversal. Debug-build only.
const DEBUG_NOCLIP: StringName      = &"debug_noclip"
## F3 / no gamepad: force AI to alert state. Debug-build only.
const DEBUG_SPAWN_ALERT: StringName = &"debug_spawn_alert"

# ── Debug action registration ──────────────────────────────────────────────

## Registers debug InputMap actions at runtime. Call site: InputContext._ready().
## Must be wrapped in `if OS.is_debug_build():` at the call site — this method
## must NOT be invoked in release builds.
## Uses InputMap.add_action() + action_add_event() per GDD Core Rule 11.
## Validates with has_action() before add_event() per GDD Core Rule 6.
static func _register_debug_actions() -> void:
	_register_debug_action(DEBUG_TOGGLE_AI,   KEY_F1)
	_register_debug_action(DEBUG_NOCLIP,      KEY_F2)
	_register_debug_action(DEBUG_SPAWN_ALERT, KEY_F3)


static func _register_debug_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	if InputMap.has_action(action):
		InputMap.action_add_event(action, ev)
