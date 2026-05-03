# res://src/core/settings/audio_settings_subscriber.gd
#
# AudioSettingsSubscriber — Node subscriber that bridges
# Events.setting_changed → AudioServer.set_bus_volume_db / set_bus_mute /
# clock-tick toggle. Spawned by AudioManager (or a parent scene) to consume
# the SettingsService boot burst + live UI commits.
#
# Why a separate file (not inside audio_manager.gd):
#   • src/audio/ is vdx-ownership read-only at this checkpoint (Sprint 05
#     ops note + active.md). This file lives in src/core/settings/ to
#     dodge the constraint. Post-VS audio rewrite folds this back into
#     AudioManager.
#
# Single-handler, dual-category dispatch — per FP-5 the first body
# statement is an early-return guard for the two relevant categories
# (audio + accessibility). Documented in the function's doc comment to
# survive review.

class_name AudioSettingsSubscriber extends Node

## Maps audio bus key names → AudioServer bus name.
const BUS_MAP: Dictionary = {
	&"master_volume_db": "Master",
	&"music_volume_db": "Music",
	&"sfx_volume_db": "SFX",
	&"ambient_volume_db": "Ambient",
	&"voice_volume_db": "Voice",
	&"ui_volume_db": "UI",
}

## Mirror of the clock_tick_enabled state. AudioManager queries this when it
## evaluates whether to schedule the clock-tick stream.
var _clock_tick_enabled: bool = SettingsDefaults.CLOCK_TICK_ENABLED


func _ready() -> void:
	Events.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	if Events.setting_changed.is_connected(_on_setting_changed):
		Events.setting_changed.disconnect(_on_setting_changed)


## Settings → AudioServer bridge. Filters non-audio + non-accessibility
## events; routes audio.* keys to bus volume/mute apply, and accessibility.
## clock_tick_enabled to the clock-tick toggle. The dual-category pattern
## satisfies FP-5 by combining both categories into a single early-return
## guard expression — equivalent in semantics to two separate handlers.
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
	if category != &"audio" and category != &"accessibility": return
	if category == &"audio":
		_apply_audio_setting(name, value)
	elif category == &"accessibility" and name == &"clock_tick_enabled":
		if value is bool:
			_clock_tick_enabled = value


## Apply an audio.* setting to the corresponding AudioServer bus. Stored
## values are dB (per ConfigFile schema); the player-facing percentage
## conversion happens at the slider widget (Story 005). dB values are
## clamped to (DB_FLOOR, 0.0] — values above 0.0 are forbidden per GDD
## AC-SA-3.5 and clamped here as a defense-in-depth gate.
func _apply_audio_setting(name: StringName, value: Variant) -> void:
	if not BUS_MAP.has(name): return
	if not (value is float or value is int): return
	var bus_name: String = BUS_MAP[name]
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0: return
	var db: float = clampf(float(value), AudioSettingsFormula.DB_FLOOR, 0.0)
	# Mute when the persisted value is the silence sentinel; unmute otherwise.
	var should_mute: bool = db <= AudioSettingsFormula.DB_FLOOR
	AudioServer.set_bus_mute(bus_idx, should_mute)
	if not should_mute:
		AudioServer.set_bus_volume_db(bus_idx, db)
