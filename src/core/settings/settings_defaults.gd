# res://src/core/settings/settings_defaults.gd
#
# SettingsDefaults — pure const declarations, no runtime logic (CR-10).
#
# Why a single shared constants module:
#   • Avoids inline-string-literal typos across the SettingsService write path,
#     UI commit handlers (Story 005), and consumer subscribers (HUD Core, Audio).
#   • Single source-of-truth for fresh-install defaults (AC-5 in SA-001).
#   • Used by the boot burst (SA-002) — the burst emits one Events.setting_changed
#     per key from this manifest before settings_loaded fires.
#
# Categories follow the GDD §C taxonomy:
#   • audio:           master/music/sfx/ambient/voice/ui dB
#   • graphics:        resolution_scale (hardware-detected, no const default)
#   • accessibility:   damage flash, crosshair, photosensitivity, subtitles, clock tick
#   • controls:        sprint/crouch/ADS toggles, mouse + gamepad sensitivity
#   • language:        locale code
#
# StringName usage: every key + category is a StringName (interned) for O(1)
# dictionary lookup in SettingsService. Use the K_* / C_* constants below
# instead of inline literals to dodge typo bugs.

class_name SettingsDefaults extends RefCounted

# ── Categories (StringName) ───────────────────────────────────────────────────
const C_AUDIO: StringName = &"audio"
const C_GRAPHICS: StringName = &"graphics"
const C_ACCESSIBILITY: StringName = &"accessibility"
const C_CONTROLS: StringName = &"controls"
const C_LANGUAGE: StringName = &"language"

# ── Audio keys ────────────────────────────────────────────────────────────────
const K_MASTER_VOLUME_DB: StringName = &"master_volume_db"
const K_MUSIC_VOLUME_DB: StringName = &"music_volume_db"
const K_SFX_VOLUME_DB: StringName = &"sfx_volume_db"
const K_AMBIENT_VOLUME_DB: StringName = &"ambient_volume_db"
const K_VOICE_VOLUME_DB: StringName = &"voice_volume_db"
const K_UI_VOLUME_DB: StringName = &"ui_volume_db"

const MASTER_VOLUME_DB: float = 0.0
const MUSIC_VOLUME_DB: float = 0.0
const SFX_VOLUME_DB: float = 0.0
const AMBIENT_VOLUME_DB: float = 0.0
const VOICE_VOLUME_DB: float = 0.0
const UI_VOLUME_DB: float = 0.0

# ── Accessibility keys ────────────────────────────────────────────────────────
const K_DAMAGE_FLASH_ENABLED: StringName = &"damage_flash_enabled"
const K_DAMAGE_FLASH_COOLDOWN_MS: StringName = &"damage_flash_cooldown_ms"
const K_CROSSHAIR_ENABLED: StringName = &"crosshair_enabled"
const K_PHOTOSENSITIVITY_WARNING_DISMISSED: StringName = &"photosensitivity_warning_dismissed"
const K_SUBTITLES_ENABLED: StringName = &"subtitles_enabled"
const K_SUBTITLE_SIZE_SCALE: StringName = &"subtitle_size_scale"
const K_SUBTITLE_BACKGROUND: StringName = &"subtitle_background"
const K_SUBTITLE_SPEAKER_LABELS: StringName = &"subtitle_speaker_labels"
const K_SUBTITLE_LINE_SPACING_SCALE: StringName = &"subtitle_line_spacing_scale"
const K_SUBTITLE_LETTER_SPACING_EM: StringName = &"subtitle_letter_spacing_em"
const K_CLOCK_TICK_ENABLED: StringName = &"clock_tick_enabled"

const DAMAGE_FLASH_ENABLED: bool = true
const DAMAGE_FLASH_COOLDOWN_MS: int = 333  # WCAG 2.3.1 safety floor — CR-17
const CROSSHAIR_ENABLED: bool = true
# photosensitivity_warning_dismissed: absent on first launch (absence = needs warning).
const SUBTITLES_ENABLED: bool = true  # WCAG SC 1.2.2 opt-OUT default — CR-23
const SUBTITLE_SIZE_SCALE: float = 1.0
const SUBTITLE_BACKGROUND: StringName = &"scrim"
const SUBTITLE_SPEAKER_LABELS: bool = true
const SUBTITLE_LINE_SPACING_SCALE: float = 1.0
const SUBTITLE_LETTER_SPACING_EM: float = 0.0
const CLOCK_TICK_ENABLED: bool = true

# ── Controls keys ─────────────────────────────────────────────────────────────
const K_SPRINT_IS_TOGGLE: StringName = &"sprint_is_toggle"
const K_CROUCH_IS_TOGGLE: StringName = &"crouch_is_toggle"
const K_ADS_IS_TOGGLE: StringName = &"ads_is_toggle"
const K_MOUSE_SENSITIVITY_X: StringName = &"mouse_sensitivity_x"
const K_MOUSE_SENSITIVITY_Y: StringName = &"mouse_sensitivity_y"
const K_GAMEPAD_LOOK_SENSITIVITY: StringName = &"gamepad_look_sensitivity"
const K_INVERT_Y_AXIS: StringName = &"invert_y_axis"

const SPRINT_IS_TOGGLE: bool = false
const CROUCH_IS_TOGGLE: bool = false
const ADS_IS_TOGGLE: bool = false
const MOUSE_SENSITIVITY_X: float = 1.0
const MOUSE_SENSITIVITY_Y: float = 1.0
const GAMEPAD_LOOK_SENSITIVITY: float = 1.0
const INVERT_Y_AXIS: bool = false

# ── Language keys ─────────────────────────────────────────────────────────────
const K_LOCALE: StringName = &"locale"
const LOCALE: String = "en"


## Returns the full default manifest as a 2-level Dictionary:
##   { category_name: { key_name: default_value, ... }, ... }
## Excludes graphics/resolution_scale (hardware-detected at first launch per CR-11)
## and accessibility/photosensitivity_warning_dismissed (absence = needs warning).
static func get_manifest() -> Dictionary:
	return {
		C_AUDIO: {
			K_MASTER_VOLUME_DB: MASTER_VOLUME_DB,
			K_MUSIC_VOLUME_DB: MUSIC_VOLUME_DB,
			K_SFX_VOLUME_DB: SFX_VOLUME_DB,
			K_AMBIENT_VOLUME_DB: AMBIENT_VOLUME_DB,
			K_VOICE_VOLUME_DB: VOICE_VOLUME_DB,
			K_UI_VOLUME_DB: UI_VOLUME_DB,
		},
		C_ACCESSIBILITY: {
			K_DAMAGE_FLASH_ENABLED: DAMAGE_FLASH_ENABLED,
			K_DAMAGE_FLASH_COOLDOWN_MS: DAMAGE_FLASH_COOLDOWN_MS,
			K_CROSSHAIR_ENABLED: CROSSHAIR_ENABLED,
			K_SUBTITLES_ENABLED: SUBTITLES_ENABLED,
			K_SUBTITLE_SIZE_SCALE: SUBTITLE_SIZE_SCALE,
			K_SUBTITLE_BACKGROUND: SUBTITLE_BACKGROUND,
			K_SUBTITLE_SPEAKER_LABELS: SUBTITLE_SPEAKER_LABELS,
			K_SUBTITLE_LINE_SPACING_SCALE: SUBTITLE_LINE_SPACING_SCALE,
			K_SUBTITLE_LETTER_SPACING_EM: SUBTITLE_LETTER_SPACING_EM,
			K_CLOCK_TICK_ENABLED: CLOCK_TICK_ENABLED,
		},
		C_CONTROLS: {
			K_SPRINT_IS_TOGGLE: SPRINT_IS_TOGGLE,
			K_CROUCH_IS_TOGGLE: CROUCH_IS_TOGGLE,
			K_ADS_IS_TOGGLE: ADS_IS_TOGGLE,
			K_MOUSE_SENSITIVITY_X: MOUSE_SENSITIVITY_X,
			K_MOUSE_SENSITIVITY_Y: MOUSE_SENSITIVITY_Y,
			K_GAMEPAD_LOOK_SENSITIVITY: GAMEPAD_LOOK_SENSITIVITY,
			K_INVERT_Y_AXIS: INVERT_Y_AXIS,
		},
		C_LANGUAGE: {
			K_LOCALE: LOCALE,
		},
	}
