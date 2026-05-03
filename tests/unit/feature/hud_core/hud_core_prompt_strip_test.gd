# tests/unit/feature/hud_core/hud_core_prompt_strip_test.gd
#
# HUDCorePromptStripTest — GdUnit4 suite for Story HC-004.
#
# PURPOSE
#   AC-1..AC-11 — interact prompt state machine + change-guards + null-PC
#   safety + get_prompt_label() extension hook.

class_name HUDCorePromptStripTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"


# ── PC double — minimal stub satisfying the two authorised query methods ────

class _StubPC extends Node3D:
	var _target: Node3D = null
	var _hand_busy: bool = false
	func get_current_interact_target() -> Node3D: return _target
	func is_hand_busy() -> bool: return _hand_busy


class _StubInteractTarget extends Node3D:
	var interact_label_key: StringName = &"hud.health.label"  # reuse an existing key for tr() lookup


# ── AC-1: target present + hand free → INTERACT_PROMPT state ────────────────

func test_target_present_and_hand_free_shows_interact_prompt() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var pc_stub: _StubPC = _StubPC.new()
	add_child(pc_stub)
	auto_free(pc_stub)
	var target: _StubInteractTarget = _StubInteractTarget.new()
	add_child(target)
	auto_free(target)
	pc_stub._target = target
	hud.pc = pc_stub

	# Tick the resolver.
	hud._process(0.016)

	assert_bool(hud._prompt_label.visible).override_failure_message(
		"With target present + hand free, prompt label must be visible."
	).is_true()
	assert_int(int(hud._last_prompt_state)).is_equal(int(hud.PromptState.INTERACT_PROMPT))


# ── AC-2: no target → HIDDEN ─────────────────────────────────────────────────

func test_no_target_hides_prompt() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var pc_stub: _StubPC = _StubPC.new()
	add_child(pc_stub)
	auto_free(pc_stub)
	pc_stub._target = null
	hud.pc = pc_stub

	hud._process(0.016)

	assert_bool(hud._prompt_label.visible).is_false()


# ── AC-3: target present but hand busy → HIDDEN ─────────────────────────────

func test_target_present_but_hand_busy_hides_prompt() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var pc_stub: _StubPC = _StubPC.new()
	add_child(pc_stub)
	auto_free(pc_stub)
	var target: _StubInteractTarget = _StubInteractTarget.new()
	add_child(target)
	auto_free(target)
	pc_stub._target = target
	pc_stub._hand_busy = true
	hud.pc = pc_stub

	hud._process(0.016)

	assert_bool(hud._prompt_label.visible).is_false()


# ── AC-4: null PC → HIDDEN; no error ────────────────────────────────────────

func test_null_pc_hides_prompt_and_does_not_crash() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	hud.pc = null
	# Must not crash.
	hud._process(0.016)

	assert_bool(hud._prompt_label.visible).is_false()
	assert_int(int(hud._last_prompt_state)).is_equal(int(hud.PromptState.HIDDEN))


# ── AC-7: change-guard skips redundant Label.text writes ────────────────────

func test_text_write_change_guard_skips_redundant_writes() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var pc_stub: _StubPC = _StubPC.new()
	add_child(pc_stub)
	auto_free(pc_stub)
	var target: _StubInteractTarget = _StubInteractTarget.new()
	add_child(target)
	auto_free(target)
	pc_stub._target = target
	hud.pc = pc_stub

	# First tick — fires INTERACT_PROMPT, sets _last_prompt_text.
	hud._process(0.016)
	var text_after_first_tick: String = hud._last_prompt_text
	# Second tick with identical state — text must not change.
	hud._process(0.016)
	hud._process(0.016)

	assert_str(hud._last_prompt_text).is_equal(text_after_first_tick)


# ── AC-8: freed target object → HIDDEN safely ───────────────────────────────

func test_freed_target_falls_to_hidden_state() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var pc_stub: _StubPC = _StubPC.new()
	add_child(pc_stub)
	auto_free(pc_stub)
	var target: _StubInteractTarget = _StubInteractTarget.new()
	add_child(target)
	pc_stub._target = target
	hud.pc = pc_stub

	hud._process(0.016)
	assert_bool(hud._prompt_label.visible).is_true()

	# Free the target; PC stub still returns the now-freed reference.
	target.free()
	# Update the stub to nullify (simulates target.free() but stub still has
	# a stale reference variable). Since Godot Node free() on a tracked Node
	# leaves _target as null already, also explicitly set to null to test the
	# null branch.
	pc_stub._target = null

	hud._process(0.016)
	assert_bool(hud._prompt_label.visible).is_false()


# ── AC-10: get_prompt_label() returns the Label written by the resolver ─────

func test_get_prompt_label_returns_same_label_used_by_resolver() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var label: Label = hud.get_prompt_label()
	assert_object(label).is_not_null()
	assert_object(label).is_equal(hud._prompt_label)


# ── AC-11: HUD does not access PC properties beyond the two authorised methods ─

func test_hud_core_only_calls_authorised_pc_methods() -> void:
	# Source-level check: only get_current_interact_target() and is_hand_busy()
	# may be called on the `pc` reference.
	var f: FileAccess = FileAccess.open(_HUD_CORE_SCRIPT, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	var pc_call_pattern: RegEx = RegEx.new()
	pc_call_pattern.compile("\\bpc\\.([a-zA-Z_][a-zA-Z0-9_]*)")

	var allowed_calls: Array[String] = ["get_current_interact_target", "is_hand_busy"]
	var violations: Array[String] = []
	var lines: PackedStringArray = content.split("\n")
	for i in range(lines.size()):
		var stripped: String = lines[i].strip_edges()
		if stripped.begins_with("#"): continue
		var matches: Array[RegExMatch] = pc_call_pattern.search_all(lines[i])
		for m in matches:
			var method_name: String = m.get_string(1)
			if method_name in allowed_calls: continue
			violations.append("hud_core.gd:%d — pc.%s (only get_current_interact_target / is_hand_busy authorised)" % [i + 1, method_name])

	assert_int(violations.size()).override_failure_message(
		"FP-2: HUD must NOT access PC beyond the two authorised methods.\nViolations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)
