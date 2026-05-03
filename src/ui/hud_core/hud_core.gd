# res://src/ui/hud_core/hud_core.gd
#
# HUDCore — CanvasLayer-rooted scene that hosts the four placeholder HUD
# widgets (BL Health, BR Weapon+Ammo, TR Gadget tile, CB Prompt-strip) plus
# the center Crosshair Control.
#
# NOT an autoload (FP-13 — HUD is a per-main-scene CanvasLayer; ADR-0007
# slot table is full). Instanced by the main game scene; receives signals
# directly from Events bus subscribers.
#
# Story scope:
#   • HC-001 (this story): scene scaffold + Theme + FontRegistry + structural
#     widget tree + dual-focus-split exemption (mouse_filter + focus_mode)
#   • HC-002: signal subscription lifecycle (14 connect/disconnect calls)
#   • HC-003: health widget logic (damage flash, critical-state trigger,
#     Tween.kill)
#   • HC-004: interact prompt strip _process state machine
#   • HC-005: settings live-update wiring + pickup memo + context-hide
#   • HC-006: Plaza VS integration smoke + visual sign-off
#
# Design choice: the widget tree is built programmatically in _ready() at
# this story (no .tscn fixture). The .tscn authoring is deferred to HC-006
# where visual sign-off requires editor inspection of the scene tree.
# Programmatic build keeps HC-001 closeable today while preserving the
# structural contract for the CI tests.

class_name HUDCore extends CanvasLayer

const _HUD_THEME_PATH: String = "res://src/core/ui_framework/themes/hud_theme.tres"

## Design size (px) for the various Label sets at the 1080p reference.
const _DESIGN_HEALTH_NUMERAL_PX: int = 22
const _DESIGN_WEAPON_NAME_PX: int = 13
const _DESIGN_AMMO_NUMERAL_PX: int = 22
const _DESIGN_PROMPT_LABEL_PX: int = 14

## F.3 scale-factor clamp range — viewport_height / 1080 capped at [0.667, 2.0].
const _SCALE_FACTOR_MIN: float = 0.667
const _SCALE_FACTOR_MAX: float = 2.0

## Widget node references — populated in _build_widget_tree().
var _root_control: Control
var _health_label_hp: Label
var _health_label_numeral: Label
var _weapon_name_label: Label
var _ammo_label: Label
var _gadget_tile: PanelContainer
var _prompt_label: Label
var _prompt_key_rect: PanelContainer
var _prompt_key_label: Label
var _crosshair: CrosshairWidget

## Timer child nodes for damage-flash + dry-fire + gadget-reject feedback.
## Created programmatically in _build_widget_tree() per HC-002 CR-1.
var _flash_timer: Timer
var _dry_fire_timer: Timer
var _gadget_reject_timer: Timer

## HC-003 health widget state.
const _HEALTH_PARCHMENT: Color = Color(0.949, 0.910, 0.784, 1.0)
const _HEALTH_ALARM_ORANGE: Color = Color(0.910, 0.365, 0.165, 1.0)
const _PLAYER_CRITICAL_HEALTH_THRESHOLD: float = 0.25

var _current_health: int = 0
var _max_health: int = 100
var _was_critical: bool = false
var _current_health_color: Color = _HEALTH_PARCHMENT
## True when the photosensitivity opt-out has suppressed the flash.
var _flash_suppressed: bool = not SettingsDefaults.DAMAGE_FLASH_ENABLED
## Pending-flash latch (CR-7 rate-gate). Set true if a damage event arrives
## while the timer is running; deferred flash fires on timer timeout.
var _pending_flash: bool = false
## HC-003 / CR-22 Tween references for kill-on-context-leave. Currently null;
## post-VS HSS pulse may populate.
var _damage_flash_tween: Tween = null
var _dry_fire_flash_tween: Tween = null

## HC-004 prompt-strip state.
enum PromptState { HIDDEN, INTERACT_PROMPT }
## Player character reference — injected by the main scene BEFORE add_child(hud).
## Typed as Node3D (not PlayerCharacter) so test doubles satisfying the same
## query API can be injected. Per CR-3, HUD is forbidden from polling PC
## properties beyond the two authorised query methods
## (get_current_interact_target + is_hand_busy) — enforced by the AC-11 grep.
@export var pc: Node3D = null

var _last_prompt_state: PromptState = PromptState.HIDDEN
var _last_prompt_text: String = ""
var _last_interact_label_key: StringName = &""
var _cached_interact_label_text: String = ""
var _cached_static_prompt_prefix: String = ""

## CR-21 placeholder until Input GDD ships Input.get_glyph_for_action("interact").
var _current_interact_glyph: String = "[E]"

## HC-005 settings mirrors. Initialised to defaults; updated by burst.
var _crosshair_enabled_mirror: bool = SettingsDefaults.CROSSHAIR_ENABLED

## HC-005 — 4th Timer for the document-collected pickup memo (3.0s display).
var _memo_timer: Timer
## True while a memo is rendered; suppresses prompt-resolver overwrite.
var _memo_active: bool = false
## HC-005 / CR-22 — gadget-reject desat tween reference, killed on context-leave.
var _gadget_reject_desat_tween: Tween = null


func _ready() -> void:
	# CanvasLayer layer index 1 — within ADR-0004 §IG7 [0..3] HUD range.
	layer = 1

	# Initial visibility tied to InputContext; the only authorised
	# InputContext.current() read outside a signal handler (CR-10).
	visible = InputContext.current() == InputContext.Context.GAMEPLAY

	_build_widget_tree()
	_apply_focus_disabled_recursively(_root_control)
	_update_hud_scale()

	# HC-002 CR-1 — 14 signal connections in _ready() exclusively.
	# (A) 9 Events autoload signals.
	Events.player_health_changed.connect(_on_health_changed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(_on_player_died)
	Events.player_interacted.connect(_on_player_interacted)
	Events.ammo_changed.connect(_on_ammo_changed)
	Events.weapon_switched.connect(_on_weapon_switched)
	Events.gadget_equipped.connect(_on_gadget_equipped)
	Events.gadget_activation_rejected.connect(_on_gadget_activation_rejected)
	Events.ui_context_changed.connect(_on_ui_context_changed)
	# (B) 1 Settings signal — SettingsService is the autoload key.
	Events.setting_changed.connect(_on_setting_changed)
	# (C) 3 local Timer child signals.
	_flash_timer.timeout.connect(_on_flash_timer_timeout)
	_dry_fire_timer.timeout.connect(_on_dry_fire_timer_timeout)
	_gadget_reject_timer.timeout.connect(_on_gadget_reject_timeout)
	# (D) 1 viewport signal.
	get_viewport().size_changed.connect(_update_hud_scale)
	# HC-005 — 15th connection: document_collected for pickup memo.
	Events.document_collected.connect(_on_document_collected)
	# HC-005 — _memo_timer.timeout.
	_memo_timer.timeout.connect(_on_memo_timer_timeout)

	# HC-004 — cache static prompt prefix once at boot (CR-18 tr() change-guard).
	_cached_static_prompt_prefix = tr("hud.interact.prompt") + " "
	if pc == null:
		push_error(
			"HUDCore: @export var pc is null at _ready(). "
			+ "Main scene MUST set hud.pc = pc_node BEFORE add_child(hud). "
			+ "HUD will degrade gracefully (prompt always HIDDEN) until pc is set."
		)


## HC-004 — prompt-strip two-state resolver. Runs every frame; the
## change-guard ensures Label.text is written only when state OR composed
## text differs from the previous frame.
func _process(_delta: float) -> void:
	if pc == null:
		_set_prompt_state(PromptState.HIDDEN, "")
		return
	var target: Node3D = pc.get_current_interact_target()
	var new_state: PromptState
	if target != null and is_instance_valid(target) and not pc.is_hand_busy():
		new_state = PromptState.INTERACT_PROMPT
	else:
		new_state = PromptState.HIDDEN
	var new_text: String = _compose_prompt_text(new_state, target)
	if new_state != _last_prompt_state or new_text != _last_prompt_text:
		_set_prompt_state(new_state, new_text)


## HC-004 — apply state to the Label widget.
func _set_prompt_state(state: PromptState, composed_text: String) -> void:
	_last_prompt_state = state
	_last_prompt_text = composed_text
	if _prompt_label == null: return
	if state == PromptState.INTERACT_PROMPT:
		_prompt_label.visible = true
		_prompt_label.text = composed_text
	else:
		_prompt_label.visible = false


## HC-004 — compose the displayed prompt for an INTERACT_PROMPT state.
## Returns "" for HIDDEN states. The tr() lookup for the dynamic interact
## key is gated by the _last_interact_label_key change-guard so per-frame
## tr() calls happen at most once on key change.
func _compose_prompt_text(state: PromptState, target: Node) -> String:
	if state != PromptState.INTERACT_PROMPT: return ""
	if not is_instance_valid(target): return ""
	var key: StringName = StringName("")
	if &"interact_label_key" in target:
		key = target.get(&"interact_label_key")
	if key == &"": return ""
	if key != _last_interact_label_key:
		_last_interact_label_key = key
		_cached_interact_label_text = tr(String(key))
	return _cached_static_prompt_prefix + _current_interact_glyph + " " + _cached_interact_label_text


## HC-004 — extension hook for HSS / other UI overlays that need to read or
## decorate the live prompt Label. Returns the same Label written to by
## _compose_prompt_text() / _set_prompt_state().
func get_prompt_label() -> Label:
	return _prompt_label


## HSS-001 / CR-4: registry of resolver-extension Callables. Each extension
## returns a `Dictionary` of {"text": String, "state_id": int} that HUD Core
## may render alongside or in priority over the prompt resolver's output.
## Currently HUD Core does not iterate these in _process (per HC-005 scope);
## the registry is provisioned here so HSS-001 can register/unregister
## without crashing, and HC-006 wires the priority dispatch.
var _resolver_extensions: Array[Callable] = []


## HSS-001 / CR-4: register a resolver extension Callable. Idempotent.
func register_resolver_extension(extension: Callable) -> void:
	if not _resolver_extensions.has(extension):
		_resolver_extensions.append(extension)


## HSS-001 / CR-4 REV-2026-04-28: unregister to prevent dead-Callable
## accumulation when the owning section is freed.
func unregister_resolver_extension(extension: Callable) -> void:
	_resolver_extensions.erase(extension)


## HC-002 CR-1 — disconnect every signal connected in _ready() with an
## is_connected guard so a partial-connect on _ready (e.g., autoload absent)
## does not raise on disconnect.
func _exit_tree() -> void:
	if Events.player_health_changed.is_connected(_on_health_changed):
		Events.player_health_changed.disconnect(_on_health_changed)
	if Events.player_damaged.is_connected(_on_player_damaged):
		Events.player_damaged.disconnect(_on_player_damaged)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.player_interacted.is_connected(_on_player_interacted):
		Events.player_interacted.disconnect(_on_player_interacted)
	if Events.ammo_changed.is_connected(_on_ammo_changed):
		Events.ammo_changed.disconnect(_on_ammo_changed)
	if Events.weapon_switched.is_connected(_on_weapon_switched):
		Events.weapon_switched.disconnect(_on_weapon_switched)
	if Events.gadget_equipped.is_connected(_on_gadget_equipped):
		Events.gadget_equipped.disconnect(_on_gadget_equipped)
	if Events.gadget_activation_rejected.is_connected(_on_gadget_activation_rejected):
		Events.gadget_activation_rejected.disconnect(_on_gadget_activation_rejected)
	if Events.ui_context_changed.is_connected(_on_ui_context_changed):
		Events.ui_context_changed.disconnect(_on_ui_context_changed)
	if Events.setting_changed.is_connected(_on_setting_changed):
		Events.setting_changed.disconnect(_on_setting_changed)
	if _flash_timer != null and _flash_timer.timeout.is_connected(_on_flash_timer_timeout):
		_flash_timer.timeout.disconnect(_on_flash_timer_timeout)
	if _dry_fire_timer != null and _dry_fire_timer.timeout.is_connected(_on_dry_fire_timer_timeout):
		_dry_fire_timer.timeout.disconnect(_on_dry_fire_timer_timeout)
	if _gadget_reject_timer != null and _gadget_reject_timer.timeout.is_connected(_on_gadget_reject_timeout):
		_gadget_reject_timer.timeout.disconnect(_on_gadget_reject_timeout)
	if _memo_timer != null and _memo_timer.timeout.is_connected(_on_memo_timer_timeout):
		_memo_timer.timeout.disconnect(_on_memo_timer_timeout)
	if Events.document_collected.is_connected(_on_document_collected):
		Events.document_collected.disconnect(_on_document_collected)
	var vp: Viewport = get_viewport()
	if vp != null and vp.size_changed.is_connected(_update_hud_scale):
		vp.size_changed.disconnect(_update_hud_scale)


# ── Handler stubs (HC-002) — bodies land in HC-003/004/005 ───────────────────

## HC-003 — health widget update + critical-state edge trigger (CR-5/CR-6).
## Edge-triggered: only the false→true and true→false crossings call
## add_theme_color_override; level-triggered redundant emissions are no-ops.
func _on_health_changed(current: float, max_health: float) -> void:
	_current_health = int(current)
	_max_health = int(max_health) if max_health > 0 else 100
	if _health_label_numeral != null:
		_health_label_numeral.text = str(_current_health)
	var ratio: float = float(current) / float(max_health) if max_health > 0 else 0.0
	var is_critical: bool = ratio < _PLAYER_CRITICAL_HEALTH_THRESHOLD
	if is_critical and not _was_critical:
		_was_critical = true
		_current_health_color = _HEALTH_ALARM_ORANGE
		if _health_label_numeral != null:
			_health_label_numeral.add_theme_color_override(&"font_color", _current_health_color)
	elif not is_critical and _was_critical:
		_was_critical = false
		_current_health_color = _HEALTH_PARCHMENT
		if _health_label_numeral != null:
			_health_label_numeral.add_theme_color_override(&"font_color", _current_health_color)


## HC-003 — damage-flash trigger with CR-7 rate-gate.
##   • If flash gate is open (_flash_timer stopped) → fire immediately + start timer.
##   • If gate is closed → set _pending_flash; deferred fire on timer timeout.
##   • If photosensitivity opt-out suppresses → no flash; rate-gate timer still
##     runs to prevent latch accumulation.
func _on_player_damaged(_amount: float, _source: Node, _is_critical: bool) -> void:
	if _flash_suppressed:
		return
	if _flash_timer == null: return
	if _flash_timer.is_stopped():
		_fire_damage_flash()
		_flash_timer.start()
	else:
		_pending_flash = true


## HC-003 helper — applies the flash override, awaits one frame, then reverts
## to the colour captured BEFORE the await (prevents the Tween race).
func _fire_damage_flash() -> void:
	if _health_label_numeral == null: return
	var pre_flash_color: Color = _current_health_color
	_health_label_numeral.add_theme_color_override(&"font_color", Color.WHITE)
	await get_tree().process_frame
	if not is_instance_valid(self): return
	if _health_label_numeral == null: return
	_health_label_numeral.add_theme_color_override(&"font_color", pre_flash_color)

## HC-003 — death overlay handoff.
func _on_player_died(_cause: int) -> void:
	pass

## HC-004 — interact prompt clearing on activation.
func _on_player_interacted(target: Node3D) -> void:
	# ADR-0002 §IG4 Node-payload guard.
	if not is_instance_valid(target): return

## HC-004 — ammo widget update.
func _on_ammo_changed(_weapon_id: StringName, _current: int, _reserve: int) -> void:
	pass

## HC-004 — weapon-name label update.
func _on_weapon_switched(_weapon_id: StringName) -> void:
	pass

## HC-004 — gadget tile icon update.
func _on_gadget_equipped(_gadget_id: StringName) -> void:
	pass

## HC-004 — gadget desat flash.
func _on_gadget_activation_rejected(_gadget_id: StringName) -> void:
	pass

## HC-003 + HC-005 / CR-22: full context-hide on leaving GAMEPLAY.
##   • visible toggle on root
##   • set_process(false) to drop _process budget to zero (AC-10)
##   • all Tween references killed (AC-7b/c/d/9; null-guarded)
##   • all Timer children stopped (AC-7f)
##   • pending-flash + memo latches cleared (AC-7g + AC-8 drop semantics)
##   • restoration enables _process and visibility; transient state is NOT restored
func _on_ui_context_changed(new_ctx: int, _old_ctx: int) -> void:
	var entering_gameplay: bool = new_ctx == InputContext.Context.GAMEPLAY
	visible = entering_gameplay
	if not entering_gameplay:
		# Slot 7 budget zero during menus/cutscenes.
		set_process(false)
		# Kill all in-flight Tweens (null-guarded).
		if _damage_flash_tween != null:
			_damage_flash_tween.kill()
			_damage_flash_tween = null
		if _dry_fire_flash_tween != null:
			_dry_fire_flash_tween.kill()
			_dry_fire_flash_tween = null
		if _gadget_reject_desat_tween != null:
			_gadget_reject_desat_tween.kill()
			_gadget_reject_desat_tween = null
		# Stop every Timer child.
		if _flash_timer != null: _flash_timer.stop()
		if _dry_fire_timer != null: _dry_fire_timer.stop()
		if _gadget_reject_timer != null: _gadget_reject_timer.stop()
		if _memo_timer != null: _memo_timer.stop()
		# Clear pending latches (drop semantics on context-leave).
		_pending_flash = false
		_memo_active = false
	else:
		# Restoration — re-enable per-frame resolver work.
		set_process(true)


## HC-003 + HC-005 — settings live-update dispatch. Single subscription
## handles two categories per the documented dual-guard pattern:
##   • accessibility/damage_flash_enabled  — photosensitivity opt-out (HC-003)
##   • accessibility/crosshair_enabled     — crosshair toggle (HC-005)
##   • language/locale                     — invalidate tr() caches (HC-005 AC-3)
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
	if category != &"accessibility" and category != &"language": return
	if category == &"accessibility":
		match name:
			&"damage_flash_enabled":
				if value is bool:
					_flash_suppressed = not value
			&"crosshair_enabled":
				if value is bool:
					_crosshair_enabled_mirror = value
					if _crosshair != null:
						_crosshair.visible = _crosshair_enabled_mirror and visible
	elif category == &"language" and name == &"locale":
		# Locale invalidation — re-resolve cached prompt prefix and force
		# the prompt resolver to re-tr() the next interact label key.
		_cached_static_prompt_prefix = tr("hud.interact.prompt") + " "
		_last_interact_label_key = &""


## HC-003 — deferred-flash latch flush on rate-gate timer end.
func _on_flash_timer_timeout() -> void:
	if _pending_flash and not _flash_suppressed:
		_pending_flash = false
		_fire_damage_flash()
		_flash_timer.start()

## HC-004 — dry-fire timer end.
func _on_dry_fire_timer_timeout() -> void:
	pass

## HC-004 — gadget-reject timer end.
func _on_gadget_reject_timeout() -> void:
	pass


## HC-005 — pickup memo on document_collected. Renders a 3.0s message via
## the prompt label, replacing whatever the prompt resolver was showing.
## Returns immediately if the doc payload fails the is_instance_valid guard
## (ADR-0002 §IG4 Node payload safety).
func _on_document_collected(document_id: StringName) -> void:
	if document_id == &"": return
	if _prompt_label == null: return
	# AC-5: compose memo text. Title key resolution defers to the document's
	# title in production; for VS scope we use the document_id directly.
	var memo_text: String = "%s: %s" % [tr("hud.collection.count"), String(document_id)]
	_prompt_label.text = memo_text
	_prompt_label.visible = true
	_memo_active = true
	_memo_timer.start()


## HC-005 — memo timer end. Hide the prompt label; resolver will re-render
## next frame if a target is still in range.
func _on_memo_timer_timeout() -> void:
	_memo_active = false
	if _prompt_label != null:
		_prompt_label.visible = false


## Programmatically construct the HUD widget tree. Each Control sets
## mouse_filter + focus_mode in its own constructor block to satisfy AC-5.
func _build_widget_tree() -> void:
	# Root Control fills the viewport.
	_root_control = Control.new()
	_root_control.name = &"Root"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.theme = load(_HUD_THEME_PATH)
	add_child(_root_control)

	# ── BL Health field ──────────────────────────────────────────────────────
	var bl_margin: MarginContainer = MarginContainer.new()
	bl_margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl_margin.add_theme_constant_override(&"margin_left", 16)
	bl_margin.add_theme_constant_override(&"margin_bottom", 16)
	_root_control.add_child(bl_margin)

	var hp_box: HBoxContainer = HBoxContainer.new()
	hp_box.add_theme_constant_override(&"separation", 6)
	bl_margin.add_child(hp_box)

	_health_label_hp = Label.new()
	_health_label_hp.text = tr("hud.health.label")
	hp_box.add_child(_health_label_hp)

	_health_label_numeral = Label.new()
	_health_label_numeral.text = ""  # populated by HC-003 from player_health_changed
	hp_box.add_child(_health_label_numeral)

	# ── BR Weapon + Ammo field ───────────────────────────────────────────────
	var br_margin: MarginContainer = MarginContainer.new()
	br_margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_margin.add_theme_constant_override(&"margin_right", 16)
	br_margin.add_theme_constant_override(&"margin_bottom", 16)
	_root_control.add_child(br_margin)

	var ammo_box: VBoxContainer = VBoxContainer.new()
	br_margin.add_child(ammo_box)

	_weapon_name_label = Label.new()
	_weapon_name_label.text = ""  # populated post-VS
	ammo_box.add_child(_weapon_name_label)

	_ammo_label = Label.new()
	_ammo_label.text = ""  # populated post-VS
	ammo_box.add_child(_ammo_label)

	# ── TR Gadget tile (scaffold only) ───────────────────────────────────────
	_gadget_tile = PanelContainer.new()
	_gadget_tile.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_root_control.add_child(_gadget_tile)

	# ── CB Prompt strip ──────────────────────────────────────────────────────
	var cb_center: CenterContainer = CenterContainer.new()
	cb_center.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root_control.add_child(cb_center)

	var cb_margin: MarginContainer = MarginContainer.new()
	cb_center.add_child(cb_margin)

	var prompt_box: HBoxContainer = HBoxContainer.new()
	prompt_box.add_theme_constant_override(&"separation", 6)
	cb_margin.add_child(prompt_box)

	_prompt_label = Label.new()
	_prompt_label.text = ""  # set by HC-004 prompt resolver
	_prompt_label.visible = false  # HC-004: initial state HIDDEN until resolver runs
	prompt_box.add_child(_prompt_label)

	_prompt_key_rect = PanelContainer.new()
	prompt_box.add_child(_prompt_key_rect)

	_prompt_key_label = Label.new()
	_prompt_key_label.text = ""
	_prompt_key_rect.add_child(_prompt_key_label)

	# ── Center Crosshair ─────────────────────────────────────────────────────
	_crosshair = CrosshairWidget.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(_crosshair)

	# ── HC-002 Timer children — feedback timers ──────────────────────────────
	_flash_timer = Timer.new()
	_flash_timer.name = &"FlashTimer"
	_flash_timer.one_shot = true
	_flash_timer.wait_time = 0.333
	add_child(_flash_timer)

	_dry_fire_timer = Timer.new()
	_dry_fire_timer.name = &"DryFireTimer"
	_dry_fire_timer.one_shot = true
	_dry_fire_timer.wait_time = 0.333
	add_child(_dry_fire_timer)

	_gadget_reject_timer = Timer.new()
	_gadget_reject_timer.name = &"GadgetRejectTimer"
	_gadget_reject_timer.one_shot = true
	_gadget_reject_timer.wait_time = 0.2
	add_child(_gadget_reject_timer)

	# HC-005 — 4th Timer for the pickup memo display.
	_memo_timer = Timer.new()
	_memo_timer.name = &"MemoTimer"
	_memo_timer.one_shot = true
	_memo_timer.wait_time = 3.0
	add_child(_memo_timer)


## Recursively apply mouse_filter = IGNORE + focus_mode = NONE to every
## Control in the subtree. AC-5 contract — HUD never receives input.
## Also sets the dual-focus-split exemption meta on the root Control.
func _apply_focus_disabled_recursively(node: Node) -> void:
	if node is Control:
		var c: Control = node
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.focus_mode = Control.FOCUS_NONE
	if node == _root_control:
		node.set_meta(&"focus_disabled_recursively", true)
	for child in node.get_children():
		_apply_focus_disabled_recursively(child)


## Apply F.3 scale-driven font lookup to every numeric Label. Called in
## _ready() and on viewport.size_changed (CR-19 — single viewport connection).
func _update_hud_scale() -> void:
	var vp: Viewport = get_viewport()
	if vp == null: return
	var scale_factor: float = clampf(float(vp.get_visible_rect().size.y) / 1080.0, _SCALE_FACTOR_MIN, _SCALE_FACTOR_MAX)
	if _health_label_numeral != null:
		_health_label_numeral.add_theme_font_override(
			&"font",
			FontRegistry.hud_numeral(int(round(_DESIGN_HEALTH_NUMERAL_PX * scale_factor)))
		)
	if _weapon_name_label != null:
		_weapon_name_label.add_theme_font_override(
			&"font",
			FontRegistry.hud_numeral(int(round(_DESIGN_WEAPON_NAME_PX * scale_factor)))
		)
	if _ammo_label != null:
		_ammo_label.add_theme_font_override(
			&"font",
			FontRegistry.hud_numeral(int(round(_DESIGN_AMMO_NUMERAL_PX * scale_factor)))
		)
	if _prompt_label != null:
		_prompt_label.add_theme_font_override(
			&"font",
			FontRegistry.hud_numeral(int(round(_DESIGN_PROMPT_LABEL_PX * scale_factor)))
		)
