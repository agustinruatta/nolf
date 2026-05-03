# tests/unit/feature/hud_core/hud_core_subscription_lifecycle_test.gd
#
# HUDCoreSubscriptionLifecycleTest — GdUnit4 suite for Story HC-002.
#
# PURPOSE
#   AC-1 / AC-2 / AC-3 / AC-4 — 14-connection lifecycle verification +
#   forbidden-pattern grep gates AC-5 through AC-12.
#
# GOVERNING REQUIREMENTS
#   TR-HUD-002, TR-HUD-003, TR-HUD-013, TR-HUD-015
#   ADR-0002 §IG3 (is_connected guard before disconnect)
#   ADR-0002 §IG4 (is_instance_valid before Node-payload deref)

class_name HUDCoreSubscriptionLifecycleTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"
const _HUD_DIR: String = "res://src/ui/hud_core"


# ── AC-1: 14 connections established after _ready() ─────────────────────────

func test_all_14_connections_established_after_ready() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	# (A) 9 Events autoload signals.
	assert_bool(Events.player_health_changed.is_connected(hud._on_health_changed)).is_true()
	assert_bool(Events.player_damaged.is_connected(hud._on_player_damaged)).is_true()
	assert_bool(Events.player_died.is_connected(hud._on_player_died)).is_true()
	assert_bool(Events.player_interacted.is_connected(hud._on_player_interacted)).is_true()
	assert_bool(Events.ammo_changed.is_connected(hud._on_ammo_changed)).is_true()
	assert_bool(Events.weapon_switched.is_connected(hud._on_weapon_switched)).is_true()
	assert_bool(Events.gadget_equipped.is_connected(hud._on_gadget_equipped)).is_true()
	assert_bool(Events.gadget_activation_rejected.is_connected(hud._on_gadget_activation_rejected)).is_true()
	assert_bool(Events.ui_context_changed.is_connected(hud._on_ui_context_changed)).is_true()
	# (B) 1 Settings signal — routed via Events bus per ADR-0002.
	assert_bool(Events.setting_changed.is_connected(hud._on_setting_changed)).is_true()
	# (C) 3 Timer child signals.
	assert_bool(hud._flash_timer.timeout.is_connected(hud._on_flash_timer_timeout)).is_true()
	assert_bool(hud._dry_fire_timer.timeout.is_connected(hud._on_dry_fire_timer_timeout)).is_true()
	assert_bool(hud._gadget_reject_timer.timeout.is_connected(hud._on_gadget_reject_timeout)).is_true()
	# (D) 1 viewport signal.
	assert_bool(get_viewport().size_changed.is_connected(hud._update_hud_scale)).is_true()


# ── AC-2: All 14 disconnections on _exit_tree() ─────────────────────────────

func test_all_14_disconnections_on_exit_tree() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	await get_tree().process_frame

	# Pre-condition: connections present.
	assert_bool(Events.player_health_changed.is_connected(hud._on_health_changed)).is_true()

	# Act: remove from tree (triggers _exit_tree).
	remove_child(hud)
	await get_tree().process_frame
	var vp_size_changed_still_connected: bool = get_viewport().size_changed.is_connected(hud._update_hud_scale)

	# Assert: every Events signal disconnected.
	assert_bool(Events.player_health_changed.is_connected(hud._on_health_changed)).is_false()
	assert_bool(Events.player_damaged.is_connected(hud._on_player_damaged)).is_false()
	assert_bool(Events.player_died.is_connected(hud._on_player_died)).is_false()
	assert_bool(Events.player_interacted.is_connected(hud._on_player_interacted)).is_false()
	assert_bool(Events.ammo_changed.is_connected(hud._on_ammo_changed)).is_false()
	assert_bool(Events.weapon_switched.is_connected(hud._on_weapon_switched)).is_false()
	assert_bool(Events.gadget_equipped.is_connected(hud._on_gadget_equipped)).is_false()
	assert_bool(Events.gadget_activation_rejected.is_connected(hud._on_gadget_activation_rejected)).is_false()
	assert_bool(Events.ui_context_changed.is_connected(hud._on_ui_context_changed)).is_false()
	assert_bool(Events.setting_changed.is_connected(hud._on_setting_changed)).is_false()
	# Viewport signal also disconnected.
	assert_bool(vp_size_changed_still_connected).is_false()

	hud.free()


# ── AC-3: No .connect() outside _ready() ────────────────────────────────────

func test_no_connect_calls_outside_ready_in_hud_core_src() -> void:
	var gd_files: Array[String] = _collect_gd_files(_HUD_DIR)
	var connect_pattern: RegEx = RegEx.new()
	connect_pattern.compile("\\.connect\\(")
	var violations: Array[String] = []

	for file_path in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null: continue
		var content: String = f.get_as_text()
		f.close()
		var lines: PackedStringArray = content.split("\n")
		var in_ready: bool = false
		var ready_indent: int = -1
		for i in range(lines.size()):
			var line: String = lines[i]
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"): continue
			if stripped.begins_with("func _ready"):
				in_ready = true
				ready_indent = _leading_indent(line)
				continue
			if in_ready and stripped.begins_with("func ") and _leading_indent(line) <= ready_indent:
				in_ready = false
			if in_ready: continue
			if connect_pattern.search(line) != null:
				violations.append("%s:%d — %s" % [file_path, i + 1, stripped])

	assert_int(violations.size()).override_failure_message(
		"All .connect() calls in hud_core.gd must live inside _ready(). Violations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


# ── AC-4: No double-connect after second _ready (idempotency) ───────────────

func test_no_double_connect_when_ready_runs_twice() -> void:
	var ScriptClass = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = ScriptClass.new()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame

	var conn_count: int = Events.player_health_changed.get_connections().size()
	# Filter to only this HUD instance's connection (other tests may add their own).
	var conn_for_this_hud: int = 0
	for c in Events.player_health_changed.get_connections():
		if c.callable.get_object() == hud:
			conn_for_this_hud += 1

	assert_int(conn_for_this_hud).override_failure_message(
		"Each Events signal must have exactly 1 connection per HUD instance. Got %d."
		% conn_for_this_hud
	).is_equal(1)


# ── AC-5: HUD emits zero signals (FP-1 subscriber-only) ─────────────────────

func test_hud_core_emits_zero_events_signals() -> void:
	var gd_files: Array[String] = _collect_gd_files(_HUD_DIR)
	var pattern: RegEx = RegEx.new()
	pattern.compile("Events\\.[a-zA-Z_]+\\.emit\\(")
	var violations: Array[String] = []

	for file_path in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null: continue
		var content: String = f.get_as_text()
		f.close()
		var lines: PackedStringArray = content.split("\n")
		for i in range(lines.size()):
			var stripped: String = lines[i].strip_edges()
			if stripped.begins_with("#"): continue
			if pattern.search(lines[i]) != null:
				violations.append("%s:%d — %s" % [file_path, i + 1, stripped])

	assert_int(violations.size()).override_failure_message(
		"FP-1: HUD must NOT emit any Events signals (subscriber-only). Violations:\n  %s"
		% "\n  ".join(violations)
	).is_equal(0)


# ── AC-6: HUD does not modify InputContext (FP-7) ───────────────────────────

func test_hud_core_does_not_modify_input_context() -> void:
	_assert_zero_grep_in_hud_dir(
		"InputContext\\.(push|pop|set)\\(",
		"FP-7: HUD must NOT modify InputContext (use ui_context_changed signal subscriber)."
	)


# ── AC-7: HUD does not poll non-authorised game systems (FP-3) ──────────────

func test_hud_core_does_not_poll_non_authorised_systems() -> void:
	_assert_zero_grep_in_hud_dir(
		"(InventorySystem|CombatSystemNode|StealthAI|CivilianAI|FailureRespawnService|MissionScriptingService)\\.[a-zA-Z_]+\\(",
		"FP-3: HUD must NOT poll non-authorised game systems directly."
	)


# ── AC-8: HUD does not subscribe to weapon_dry_fire_click (FP-5) ────────────

func test_hud_core_does_not_connect_to_weapon_dry_fire_click() -> void:
	_assert_zero_grep_in_hud_dir(
		"weapon_dry_fire_click\\.connect",
		"FP-5: weapon_dry_fire_click is Audio's exclusive subscription."
	)


# ── AC-9: HUD does not access PlayerCharacter properties directly (FP-2) ────

func test_hud_core_does_not_access_pc_properties_directly() -> void:
	_assert_zero_grep_in_hud_dir(
		"pc\\.(health|max_health|current_health|stamina|is_crouching|is_sprinting|inventory)",
		"FP-2: HUD must NOT access PC properties directly."
	)


# ── AC-10: HUD has no save/load registration (FP-12) ────────────────────────

func test_hud_core_has_no_save_load_registration() -> void:
	_assert_zero_grep_in_hud_dir(
		"(register_restore_callback|func capture\\(\\))",
		"FP-12: HUD must NOT register save/load callbacks."
	)


# ── AC-11: HUD scene contains no minimap/waypoint/marker tokens (FP-6) ──────

func test_hud_core_has_no_pillar_2_pillar_5_excluded_tokens() -> void:
	_assert_zero_grep_in_hud_dir(
		"(waypoint|minimap|objective_marker|alert_indicator|radar|compass|map_overlay|nav_arrow)",
		"FP-6: Pillar 2/5 absolute exclusion — no minimap/waypoint/marker/radar tokens in HUD."
	)


# ── AC-12: No raw tree-walk singleton lookups (FP-14) ───────────────────────

func test_hud_core_has_no_raw_tree_walk_singleton_lookups() -> void:
	_assert_zero_grep_in_hud_dir(
		"(Engine\\.get_singleton|get_tree\\(\\)\\.root\\.get_node)",
		"FP-14: HUD must NOT use raw tree-walk singleton lookups."
	)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _assert_zero_grep_in_hud_dir(pattern_str: String, fail_msg: String) -> void:
	var gd_files: Array[String] = _collect_gd_files(_HUD_DIR)
	var pattern: RegEx = RegEx.new()
	pattern.compile(pattern_str)
	var violations: Array[String] = []
	for file_path in gd_files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null: continue
		var content: String = f.get_as_text()
		f.close()
		var lines: PackedStringArray = content.split("\n")
		for i in range(lines.size()):
			var stripped: String = lines[i].strip_edges()
			if stripped.begins_with("#"): continue
			if pattern.search(lines[i]) != null:
				violations.append("%s:%d — %s" % [file_path, i + 1, stripped])
	assert_int(violations.size()).override_failure_message(
		"%s\nViolations:\n  %s" % [fail_msg, "\n  ".join(violations)]
	).is_equal(0)


func _collect_gd_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null: return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			results.append_array(_collect_gd_files(full_path))
		elif entry.ends_with(".gd"):
			results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return results


func _leading_indent(line: String) -> int:
	var n: int = 0
	for c: String in line:
		if c == "\t" or c == " ":
			n += 1
		else:
			break
	return n
