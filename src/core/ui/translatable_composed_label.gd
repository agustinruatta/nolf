# src/core/ui/translatable_composed_label.gd
#
# TranslatableComposedLabel — Pattern B reference for LOC-004.
#
# Use this when a Label's text is a runtime composition (concatenation,
# format substitution with dynamic values, conditional branches) — i.e., the
# text is NOT a single tr() key that auto_translate_mode = ALWAYS could handle
# on its own.
#
# Pattern A vs Pattern B (LOC-004 reference):
#   • Pattern A — `Label.text = "menu.main.start_mission"` +
#     `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. Zero boilerplate;
#     Godot resolves tr() and re-resolves on locale change automatically.
#   • Pattern B — composed strings (e.g. `tr("hud.section.label") + ": " +
#     dynamic_value`). auto_translate_mode can't recompose because the
#     composition logic lives in script. Override _notification() to
#     listen for NOTIFICATION_TRANSLATION_CHANGED and re-run the composition.
#
# Forbidden: caching tr() at _ready into a `var` without a re-resolution
# mechanism (the `cached_translation_at_ready` rule per LOC-005 lint).
#
# Why this lives in src/core/ui/: shared UI primitive used across HUD,
# Menu, Settings, and Document Overlay epics. See LOC-004 Implementation
# Notes for the canonical Pattern A / Pattern B selection rule.

class_name TranslatableComposedLabel extends Label

## tr() key for the static label segment (e.g. "hud.objective.label").
@export var label_key: StringName = &""

## Dynamic value appended after the label segment + ": " separator.
## Set by callers; updates trigger an immediate refresh.
var current_value: String = "":
	set(value):
		current_value = value
		_refresh_text()


func _ready() -> void:
	# Disable Godot's auto-translate so it doesn't try to re-tr() our composed
	# string (which would resolve as a missing key). We re-resolve manually
	# in _notification(NOTIFICATION_TRANSLATION_CHANGED).
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_refresh_text()


## NOTIFICATION_TRANSLATION_CHANGED fires on every Node when
## TranslationServer.set_locale() is called. Re-run the composition so the
## label segment picks up the new locale's translation.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _refresh_text() -> void:
	if label_key == &"":
		text = current_value
		return
	var label_segment: String = tr(label_key)
	if current_value == "":
		text = "%s: " % label_segment
	else:
		text = "%s: %s" % [label_segment, current_value]
