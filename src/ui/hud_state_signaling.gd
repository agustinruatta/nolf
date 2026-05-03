# res://src/ui/hud_state_signaling.gd
#
# HUDStateSignaling — section-scoped Node that bridges Sprint-04 stealth
# alert state + document-pickup events into the HUD Core prompt label
# via the resolver-extension API.
#
# Lives at Section/Systems/HUDStateSignaling per GDD CR-2 (mirroring
# Section/Systems/DocumentCollection). NOT an autoload — section-scoped
# so it dies cleanly with the section on respawn.
#
# Subscriber-only (FP-HSS-8): HSS NEVER emits Events signals. It only
# subscribes + writes to the borrowed Label via the resolver callback.
#
# Story scope:
#   • HSS-001 (this story): structural scaffold, _ready/_exit_tree
#     lifecycle, resolver-extension registration, Events subscriptions,
#     E.20 null-guard.
#   • HSS-002: ALERT_CUE state body (Day-1 HoH/deaf accessibility).
#   • HSS-003: MEMO_NOTIFICATION state body (document pickup toast).

class_name HUDStateSignaling extends Node

## State priority enum — HUD Core picks the highest-priority active state
## per CR-6 dispatch.
enum HSSState { HIDDEN, ALERT_CUE, MEMO_NOTIFICATION }

## The borrowed prompt Label from HUD Core. Null-guarded per E.20 — if HUD
## Core is missing at _ready, HSS becomes inert (set_process(false)) rather
## than crashing on first dispatch.
var _label: Label = null

## ALERT_CUE rate-gate state (per-actor, per CR-9).
## Keys: actor Node references (weak — HUD Core resolver re-validates each tick).
var _alert_cue_last_fired_per_actor: Dictionary = {}
var _alert_cue_last_state_per_actor: Dictionary = {}

## HSS-002 tuning knobs.
const _ALERT_CUE_DURATION_S: float = 2.0
const _ALERT_CUE_ACTOR_COOLDOWN_S: float = 1.0

## HSS-003 tuning knobs.
const _MEMO_NOTIFICATION_DURATION_S: float = 3.0
const _QUEUED_STATE_MAX_AGE_S: float = 5.0

## Priority table per CR-6 (lower number = higher priority).
const _PRIORITY: Dictionary = {
	int(HSSState.HIDDEN): 99,
	int(HSSState.ALERT_CUE): 3,
	int(HSSState.MEMO_NOTIFICATION): 6,
}

## Day-1 ALERT_CUE timer — single-shot, reused across actors.
var _alert_cue_timer: Timer

## HSS-003 MEMO_NOTIFICATION timer — single-shot, 3.0s default.
var _memo_timer: Timer

## HSS-003 single-deep queue for the MEMO state when a higher-priority state
## (ALERT_CUE) is currently active. Cleared when activated or when freshness
## window expires (CR-3 §C.3 freshness check).
var _queued_memo_doc_id: StringName = &""
var _queued_memo_at_time: float = -1.0

## True iff HSS is in an active state (ALERT_CUE or MEMO_NOTIFICATION).
## Read by the resolver callback to decide which text to surface.
var _current_state: HSSState = HSSState.HIDDEN
var _current_text: String = ""


func _ready() -> void:
	# E.20 null-guard — HUD Core may be absent in some test contexts.
	var hud_core: Node = _find_hud_core()
	if hud_core == null or not is_instance_valid(hud_core):
		push_error(
			"HSS: HUD Core not present at _ready(); HSS disabled for this section."
		)
		set_process(false)
		return
	if hud_core.has_method(&"get_prompt_label"):
		_label = hud_core.get_prompt_label()
	if _label == null:
		push_error("HSS: HUD Core get_prompt_label() returned null; HSS disabled.")
		set_process(false)
		return

	# Build the ALERT_CUE timer (single-shot, _ALERT_CUE_DURATION_S default).
	_alert_cue_timer = Timer.new()
	_alert_cue_timer.name = &"AlertCueTimer"
	_alert_cue_timer.one_shot = true
	_alert_cue_timer.wait_time = _ALERT_CUE_DURATION_S
	add_child(_alert_cue_timer)
	_alert_cue_timer.timeout.connect(_on_alert_cue_dismissed)

	# HSS-003 MEMO_NOTIFICATION timer (single-shot, 3.0s default).
	_memo_timer = Timer.new()
	_memo_timer.name = &"MemoTimer"
	_memo_timer.one_shot = true
	_memo_timer.wait_time = _MEMO_NOTIFICATION_DURATION_S
	add_child(_memo_timer)
	_memo_timer.timeout.connect(_on_memo_dismissed)

	# HSS-003 — VS subscription for document-pickup toast.
	Events.document_collected.connect(_on_document_collected)

	# CR-4: register resolver extension BEFORE signal subscriptions.
	if hud_core.has_method(&"register_resolver_extension"):
		hud_core.register_resolver_extension(_resolve_hss_state)

	# CR-10: synchronous default flags only (CONNECT_DEFERRED forbidden).
	Events.alert_state_changed.connect(_on_alert_state_changed)
	Events.ui_context_changed.connect(_on_ui_context_changed)


## Locate the HUD Core node. Default lookup walks the scene tree from /root
## for the first node whose script class is HUDCore. Tests may inject a
## reference directly via the public _label setter.
func _find_hud_core() -> Node:
	var root: Node = get_tree().root if get_tree() != null else null
	if root == null:
		return null
	return _find_node_with_class_recursive(root, "HUDCore")


func _find_node_with_class_recursive(node: Node, class_token: String) -> Node:
	# Match by script class_name token in the node's script source.
	var script: Script = node.get_script()
	if script != null:
		var path: String = script.resource_path
		if path != "" and path.ends_with("hud_core.gd"):
			return node
	for child in node.get_children():
		var found: Node = _find_node_with_class_recursive(child, class_token)
		if found != null: return found
	return null


func _exit_tree() -> void:
	# CR-4 REV-2026-04-28 — unregister resolver extension to prevent dead
	# Callable accumulation in the HUD Core registry.
	var hud_core: Node = _find_hud_core()
	if hud_core != null and is_instance_valid(hud_core) and hud_core.has_method(&"unregister_resolver_extension"):
		hud_core.unregister_resolver_extension(_resolve_hss_state)

	# CR-10 — disconnect with is_connected guards.
	if Events.alert_state_changed.is_connected(_on_alert_state_changed):
		Events.alert_state_changed.disconnect(_on_alert_state_changed)
	if Events.ui_context_changed.is_connected(_on_ui_context_changed):
		Events.ui_context_changed.disconnect(_on_ui_context_changed)
	if Events.document_collected.is_connected(_on_document_collected):
		Events.document_collected.disconnect(_on_document_collected)
	if _alert_cue_timer != null and _alert_cue_timer.timeout.is_connected(_on_alert_cue_dismissed):
		_alert_cue_timer.timeout.disconnect(_on_alert_cue_dismissed)
	if _memo_timer != null and _memo_timer.timeout.is_connected(_on_memo_dismissed):
		_memo_timer.timeout.disconnect(_on_memo_dismissed)
	# CR-9 — clear rate-gate dicts on free.
	_alert_cue_last_fired_per_actor.clear()
	_alert_cue_last_state_per_actor.clear()
	# Force-stop active Timer.
	if _alert_cue_timer != null and not _alert_cue_timer.is_stopped():
		_alert_cue_timer.stop()


## CR-4: resolver-extension callback. Returns the HSS state HUD Core should
## consider for this frame. HUD Core's dispatcher picks the highest-priority
## active state. HSS-001 returns HIDDEN; HSS-002/003 fill in real state.
func _resolve_hss_state() -> Dictionary:
	return {"text": _current_text, "state_id": int(_current_state)}


# ── Handler stubs (HSS-001) — bodies in HSS-002 / HSS-003 ────────────────────

## HSS-002 — alert state changed handler.
##   • UNAWARE new_state → state-gate; ignored (CR-9 / §C.2 trigger row).
##   • Per-actor cooldown rate-gate (CR-9) — same actor must wait
##     _ALERT_CUE_ACTOR_COOLDOWN_S between cues UNLESS upward severity bypass.
##   • Upward-severity exemption (CR-9 REV-2026-04-28 / accessibility-specialist
##     Finding 1): a transition to a HIGHER alert state for the same actor
##     bypasses the cooldown so the player isn't deprived of the escalation cue.
##   • Stale freed-Node refs are erased on every event (ADR-0002 §IG4).
func _on_alert_state_changed(actor: Node, _old_state: int, new_state: int, _severity: int) -> void:
	if not is_instance_valid(actor): return
	if new_state == StealthAI.AlertState.UNAWARE: return

	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_clean_freed_actor_refs()

	var last_state: int = int(_alert_cue_last_state_per_actor.get(actor, int(StealthAI.AlertState.UNAWARE)))
	var last_fired: float = float(_alert_cue_last_fired_per_actor.get(actor, -1e30))
	var upward_severity: bool = new_state > last_state

	if not upward_severity and (now - last_fired) < _ALERT_CUE_ACTOR_COOLDOWN_S:
		return  # same-or-lower severity within cooldown — suppressed

	_alert_cue_last_fired_per_actor[actor] = now
	_alert_cue_last_state_per_actor[actor] = new_state

	_enter_alert_cue_state()


## CR-9 cleanup rule + ADR-0002 §IG4: erase entries for freed actor Nodes.
func _clean_freed_actor_refs() -> void:
	var keys_to_erase: Array = []
	for key in _alert_cue_last_fired_per_actor.keys():
		if not is_instance_valid(key):
			keys_to_erase.append(key)
	for k in keys_to_erase:
		_alert_cue_last_fired_per_actor.erase(k)
		_alert_cue_last_state_per_actor.erase(k)


## HSS-002 state entry: set ALERT_CUE active text + restart Timer.
## Text resolution uses tr() with the hud.alert.guard_alerted key. The Label
## itself remains owned by HUD Core; HSS surfaces text via _resolve_hss_state.
func _enter_alert_cue_state() -> void:
	_current_state = HSSState.ALERT_CUE
	_current_text = tr("hud.alert.guard_alerted")
	if _alert_cue_timer != null:
		_alert_cue_timer.start(_ALERT_CUE_DURATION_S)


## HSS-001 — context-leave clears HSS state immediately (no carry-over).
## HSS-003 extension: also stops MEMO timer + clears queued MEMO.
func _on_ui_context_changed(new_ctx: int, _old_ctx: int) -> void:
	if new_ctx != InputContext.Context.GAMEPLAY:
		_current_state = HSSState.HIDDEN
		_current_text = ""
		if _alert_cue_timer != null and not _alert_cue_timer.is_stopped():
			_alert_cue_timer.stop()
		if _memo_timer != null and not _memo_timer.is_stopped():
			_memo_timer.stop()
		_queued_memo_doc_id = &""
		_queued_memo_at_time = -1.0


## HSS-002 — alert cue timer end clears the ALERT_CUE state. If a queued MEMO
## is still fresh, promote it now (CR-3 §C.3 freshness check + activation).
func _on_alert_cue_dismissed() -> void:
	if _current_state == HSSState.ALERT_CUE:
		_current_state = HSSState.HIDDEN
		_current_text = ""
	# Promote queued MEMO if fresh.
	if _queued_memo_doc_id != &"":
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		if (now - _queued_memo_at_time) <= _QUEUED_STATE_MAX_AGE_S:
			_activate_memo_state(_queued_memo_doc_id)
		# Clear queue regardless of freshness.
		_queued_memo_doc_id = &""
		_queued_memo_at_time = -1.0


## HSS-003 — document-collected toast handler. Priority dispatch:
##   • If ALERT_CUE active (higher priority): queue MEMO with timestamp.
##   • If MEMO already active (same priority): drop per §C.3 collision rule.
##   • Otherwise: activate MEMO immediately.
func _on_document_collected(document_id: StringName) -> void:
	if document_id == &"": return
	var arriving_priority: int = int(_PRIORITY.get(int(HSSState.MEMO_NOTIFICATION), 99))
	var current_priority: int = int(_PRIORITY.get(int(_current_state), 99))
	if current_priority < arriving_priority:
		# Higher-priority state active → queue MEMO single-deep.
		_queued_memo_doc_id = document_id
		_queued_memo_at_time = float(Time.get_ticks_msec()) / 1000.0
		return
	if current_priority == arriving_priority:
		# Same-priority collision (already MEMO) → drop per §C.3.
		return
	_activate_memo_state(document_id)


## HSS-003 — set MEMO_NOTIFICATION state + start timer.
func _activate_memo_state(document_id: StringName) -> void:
	_current_state = HSSState.MEMO_NOTIFICATION
	_current_text = "%s — %s" % [tr("hud.collection.count"), String(document_id)]
	if _memo_timer != null:
		_memo_timer.start(_MEMO_NOTIFICATION_DURATION_S)


## HSS-003 — memo timer end clears the MEMO_NOTIFICATION state.
func _on_memo_dismissed() -> void:
	if _current_state == HSSState.MEMO_NOTIFICATION:
		_current_state = HSSState.HIDDEN
		_current_text = ""
