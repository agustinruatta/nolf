# GdUnit4 headless presence-check / sanity runner.
#
# Usage: godot --headless --script tests/gdunit4_runner.gd
#
# This script verifies the GdUnit4 addon is installed and locatable. It does
# NOT run the test suite — for that use the official CmdTool entry point:
#
#   godot --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
#         -a tests/unit -a tests/integration
#
# CI uses MikeSchulze/gdUnit4-action@v1, which wraps the CmdTool internally.
# Exits 0 if the addon is present and loadable, non-zero otherwise.
extends SceneTree


const CMD_TOOL_PATH := "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"


func _init() -> void:
	if not ResourceLoader.exists(CMD_TOOL_PATH):
		push_error(
			"GdUnit4 not found at %s. Install via AssetLib (Project Settings " % CMD_TOOL_PATH
			+ "→ Plugins → GdUnit4 ✓) or git clone https://github.com/MikeSchulze/gdUnit4 "
			+ "and copy addons/gdUnit4/ into ./addons/."
		)
		quit(1)
		return

	var script := load(CMD_TOOL_PATH) as Script
	if script == null:
		push_error("GdUnit4 addon present but GdUnitCmdTool.gd failed to load.")
		quit(1)
		return

	print("[gdunit4_runner] GdUnit4 addon detected at %s." % CMD_TOOL_PATH)
	print("[gdunit4_runner] To run the test suite use:")
	print("  godot -s -d %s -a tests/unit -a tests/integration" % CMD_TOOL_PATH)
	quit(0)
