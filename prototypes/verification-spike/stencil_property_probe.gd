# prototypes/verification-spike/stencil_property_probe.gd
#
# Headless probe to discover the Godot 4.6 stencil-buffer API surface.
# Stencil support was added in Godot 4.5 — post-LLM-cutoff. This script
# enumerates the actual property names available on BaseMaterial3D and
# the related rendering classes so we can write the stencil demo against
# confirmed identifiers, not guessed ones.
#
# OUTPUT
#   - List of stencil-related properties on BaseMaterial3D
#   - List of stencil-related properties on ShaderMaterial
#   - Project Settings keys related to stencil (if any)
#   - Hint about which API path the stencil demo should use
#
# HOW TO RUN
#   godot --headless --script res://prototypes/verification-spike/stencil_property_probe.gd

extends SceneTree


func _initialize() -> void:
	print()
	print("=== Stencil API Probe — Godot 4.6 ===")
	print("Engine version: %s" % Engine.get_version_info().string)
	print()

	_probe_class_properties("BaseMaterial3D")
	_probe_class_properties("StandardMaterial3D")
	_probe_class_properties("ShaderMaterial")

	_probe_project_settings()

	print()
	print("=== End probe ===")
	quit(0)


func _probe_class_properties(cls: String) -> void:
	print("--- Properties on %s containing 'stencil' (case-insensitive) ---" % cls)
	if not ClassDB.class_exists(cls):
		print("  CLASS NOT FOUND")
		return
	var props := ClassDB.class_get_property_list(cls, true)
	var matches: Array = []
	for p in props:
		var n: String = p.name
		if n.to_lower().contains("stencil"):
			matches.append("%s [%s, hint=%s]" % [n, type_string(p.type), str(p.hint_string)])
	if matches.is_empty():
		print("  (none found)")
	else:
		for m in matches:
			print("  ", m)
	print()


func _probe_project_settings() -> void:
	print("--- ProjectSettings keys containing 'stencil' (case-insensitive) ---")
	var found: int = 0
	for path in ProjectSettings.get_property_list():
		var n: String = path.name
		if n.to_lower().contains("stencil"):
			print("  ", n, " = ", ProjectSettings.get_setting(n))
			found += 1
	if found == 0:
		print("  (none found in property list)")
	print()
