# res://scenes/error_fallback.gd
#
# ErrorFallback — minimal placeholder scene script for Story LS-005.
#
# Behavior:
#   1. On `_ready()`, reads `LevelStreamingService._last_error_message` and
#      displays it in the Label node. Displays a default string if empty.
#   2. Starts an auto-dismiss timer (AutoDismissTimer, 2.0 s).
#   3. On timer timeout, calls `change_scene_to_file("res://scenes/MainMenu.tscn")`
#      to route the player back to the main menu.
#
# Debug vs. shipping: `_show_error_fallback` in LevelStreamingService routes
# to this scene only in debug builds. In shipping builds the player is routed
# directly to MainMenu. This scene's behavior therefore only runs in debug.
#
# Visual treatment (Art Bible 7D dossier card) is post-MVP. The current layout
# is a minimal functional placeholder that satisfies AC-6 timing.
#
# Implements: Story LS-005 (AC-6 — ErrorFallback display + auto-dismiss)
# Requirements: TR-LS-002, TR-LS-003
# GDD: design/gdd/level-streaming.md §Edge Cases
# ADR: ADR-0007 CR-3

extends Control


# ── Constants ──────────────────────────────────────────────────────────────

const MAIN_MENU_PATH: String = "res://scenes/MainMenu.tscn"
const AUTO_DISMISS_SECONDS: float = 2.0
const DEFAULT_ERROR_TEXT: String = "File not found — returning to main menu."


# ── Node references ────────────────────────────────────────────────────────

@onready var _label: Label = $Label
@onready var _timer: Timer = $AutoDismissTimer


# ── Lifecycle ──────────────────────────────────────────────────────────────

## Reads `LevelStreamingService._last_error_message` and displays it in the
## Label. Starts the auto-dismiss timer immediately. The timer fires
## `_on_auto_dismiss_timer_timeout` after `AUTO_DISMISS_SECONDS` (2.0 s),
## which calls `change_scene_to_file` to route to MainMenu.
##
## AC-6: label shows error text; auto-dismiss fires after ≥2s.
func _ready() -> void:
	var message: String = LevelStreamingService.get_last_error_message_for_test()
	if message.is_empty():
		message = DEFAULT_ERROR_TEXT
	_label.text = message

	_timer.wait_time = AUTO_DISMISS_SECONDS
	_timer.one_shot = true
	_timer.timeout.connect(_on_auto_dismiss_timer_timeout)
	_timer.start()


# ── Signal callbacks ────────────────────────────────────────────────────────

## Auto-dismiss callback: fires after AUTO_DISMISS_SECONDS. Routes player to
## MainMenu via `change_scene_to_file`. Story LS-005 AC-6.
func _on_auto_dismiss_timer_timeout() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
