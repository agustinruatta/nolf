# tests/integration/feature/settings/audio_bus_apply_test.gd
#
# AudioBusApplyTest — GdUnit4 integration suite for Story SA-004.
#
# PURPOSE
#   AC-3 / AC-4 — AudioSettingsSubscriber routes Events.setting_changed to
#   AudioServer bus volume apply + clock_tick_enabled state mirror.
#
# Note: tests instantiate the subscriber directly + add to tree so it
# subscribes to Events; we do NOT rely on the live AudioManager because
# src/audio/ is permission-locked at this checkpoint.

class_name AudioBusApplyTest
extends GdUnitTestSuite

const _SUBSCRIBER_SCRIPT: String = "res://src/core/settings/audio_settings_subscriber.gd"


# ── AC-3: setting_changed routes to AudioServer.set_bus_volume_db ────────────

## AC-3: emitting setting_changed("audio", "master_volume_db", -12.0) reaches
## the subscriber and AudioServer.get_bus_volume_db("Master") returns -12.0
## within ±0.01 dB tolerance.
func test_master_volume_db_emit_applies_to_audio_server_master_bus() -> void:
	var SubscriberScript = load(_SUBSCRIBER_SCRIPT)
	var subscriber: Node = SubscriberScript.new()
	add_child(subscriber)
	auto_free(subscriber)
	await get_tree().process_frame

	# Save original Master bus volume so we can restore at end.
	var master_idx: int = AudioServer.get_bus_index("Master")
	var saved_db: float = AudioServer.get_bus_volume_db(master_idx) if master_idx >= 0 else 0.0
	var saved_mute: bool = AudioServer.is_bus_mute(master_idx) if master_idx >= 0 else false

	# Act
	Events.setting_changed.emit(&"audio", &"master_volume_db", -12.0)
	await get_tree().process_frame

	# Assert — only when the Master bus exists (CI runners may not provide it).
	if master_idx >= 0:
		assert_float(AudioServer.get_bus_volume_db(master_idx)).override_failure_message(
			"After setting_changed(audio, master_volume_db, -12.0), Master bus volume must be -12.0 ±0.01 dB. Got: %f"
			% AudioServer.get_bus_volume_db(master_idx)
		).is_equal_approx(-12.0, 0.01)
		assert_bool(AudioServer.is_bus_mute(master_idx)).override_failure_message(
			"Non-silence dB value must NOT mute the bus."
		).is_false()
		# Restore.
		AudioServer.set_bus_volume_db(master_idx, saved_db)
		AudioServer.set_bus_mute(master_idx, saved_mute)


## AC-3 edge: silence sentinel value mutes the bus.
func test_silence_floor_db_value_mutes_bus() -> void:
	var SubscriberScript = load(_SUBSCRIBER_SCRIPT)
	var subscriber: Node = SubscriberScript.new()
	add_child(subscriber)
	auto_free(subscriber)
	await get_tree().process_frame

	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return  # CI runner without Master bus — skip
	var saved_db: float = AudioServer.get_bus_volume_db(master_idx)
	var saved_mute: bool = AudioServer.is_bus_mute(master_idx)

	# Act
	Events.setting_changed.emit(&"audio", &"master_volume_db", -80.0)
	await get_tree().process_frame

	# Assert: bus is muted (silence sentinel).
	assert_bool(AudioServer.is_bus_mute(master_idx)).override_failure_message(
		"Silence sentinel dB (-80) must mute the bus."
	).is_true()

	# Restore.
	AudioServer.set_bus_volume_db(master_idx, saved_db)
	AudioServer.set_bus_mute(master_idx, saved_mute)


## AC-5 defense-in-depth: dB above 0 is clamped to 0 before apply.
func test_above_zero_db_value_is_clamped_to_zero() -> void:
	var SubscriberScript = load(_SUBSCRIBER_SCRIPT)
	var subscriber: Node = SubscriberScript.new()
	add_child(subscriber)
	auto_free(subscriber)
	await get_tree().process_frame

	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	var saved_db: float = AudioServer.get_bus_volume_db(master_idx)
	var saved_mute: bool = AudioServer.is_bus_mute(master_idx)

	# Act — emit a corrupt cfg value above 0 dB.
	Events.setting_changed.emit(&"audio", &"master_volume_db", 9999.0)
	await get_tree().process_frame

	# Assert — clamped to 0 dB.
	assert_float(AudioServer.get_bus_volume_db(master_idx)).override_failure_message(
		"Above-zero dB values must be clamped to 0.0 (GDD AC-SA-3.5)."
	).is_equal_approx(0.0, 0.01)

	# Restore.
	AudioServer.set_bus_volume_db(master_idx, saved_db)
	AudioServer.set_bus_mute(master_idx, saved_mute)


# ── AC-4: clock_tick_enabled state mirrors the emit ──────────────────────────

func test_clock_tick_enabled_false_emit_sets_state_flag_to_false() -> void:
	var SubscriberScript = load(_SUBSCRIBER_SCRIPT)
	var subscriber: Node = SubscriberScript.new()
	add_child(subscriber)
	auto_free(subscriber)
	await get_tree().process_frame

	# Pre-condition: starts at default true.
	assert_bool(subscriber._clock_tick_enabled).is_true()

	# Act
	Events.setting_changed.emit(&"accessibility", &"clock_tick_enabled", false)
	await get_tree().process_frame

	# Assert
	assert_bool(subscriber._clock_tick_enabled).override_failure_message(
		"After setting_changed(accessibility, clock_tick_enabled, false), state flag must be false."
	).is_false()


func test_non_audio_non_accessibility_category_does_not_apply() -> void:
	var SubscriberScript = load(_SUBSCRIBER_SCRIPT)
	var subscriber: Node = SubscriberScript.new()
	add_child(subscriber)
	auto_free(subscriber)
	await get_tree().process_frame

	# Master bus should not be touched by a non-audio category emit.
	var master_idx: int = AudioServer.get_bus_index("Master")
	var saved_db: float = AudioServer.get_bus_volume_db(master_idx) if master_idx >= 0 else 0.0
	var saved_mute: bool = AudioServer.is_bus_mute(master_idx) if master_idx >= 0 else false

	# Act — emit graphics/resolution_scale (irrelevant category).
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.5)
	await get_tree().process_frame

	# Assert: Master bus unchanged.
	if master_idx >= 0:
		assert_float(AudioServer.get_bus_volume_db(master_idx)).is_equal_approx(saved_db, 0.01)
		assert_bool(AudioServer.is_bus_mute(master_idx)).is_equal(saved_mute)
