# res://src/core/ui_framework/font_registry.gd
#
# FontRegistry — static class providing the single point of font lookup
# for HUD numerals, with size-driven Futura Condensed Bold ↔ DIN 1451
# Engschrift substitution at the 18 px floor (Art Bible §7B/§8C).
#
# NOT an autoload — a static class exposed via the FontRegistry global.
# Why: per ADR-0007 the autoload table is full; per ADR-0004 §IG7 the font
# lookup is a pure function with no per-instance state.
#
# At MVP, font resources are not yet authored — both branches return
# Godot's SystemFont as a placeholder. Post-VS the actual TTF resources
# will be loaded from assets/fonts/ and substituted here.

class_name FontRegistry extends RefCounted

## The 18 px floor below which we switch from Futura Condensed Bold to
## DIN 1451 Engschrift. Per Art Bible §7B/§8C: Futura's letterforms become
## illegible below this size; DIN 1451's Engschrift cut keeps numerals
## crisp at 13–17 px.
const NUMERAL_FONT_FLOOR_PX: int = 18


## Returns the Font appropriate for a numeric Label at physical_size_px.
## Below the 18 px floor → DIN 1451 Engschrift; at/above → Futura Condensed Bold.
##
## At MVP, both branches return SystemFont placeholders (variation differs by
## variation_coordinates). Tests verify the BRANCH is selected correctly.
static func hud_numeral(physical_size_px: int) -> Font:
	if physical_size_px < NUMERAL_FONT_FLOOR_PX:
		return _din_1451_engschrift()
	return _futura_condensed_bold()


## Returns true iff the given size selects DIN 1451 (sub-floor branch).
## Tests use this to verify the branch decision without comparing Font instances.
static func is_din_branch(physical_size_px: int) -> bool:
	return physical_size_px < NUMERAL_FONT_FLOOR_PX


static func _futura_condensed_bold() -> Font:
	# MVP placeholder — real Futura Condensed Bold loads from assets/fonts/ post-VS.
	# Use SystemFont with variation tag to differentiate from DIN at MVP test layer.
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Futura Condensed", "Futura", "DejaVu Sans"])
	f.font_weight = 700  # Bold
	return f


static func _din_1451_engschrift() -> Font:
	# MVP placeholder — real DIN 1451 Engschrift loads from assets/fonts/ post-VS.
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["DIN 1451", "DIN", "DejaVu Sans Condensed"])
	f.font_weight = 600  # Demi-bold
	return f
