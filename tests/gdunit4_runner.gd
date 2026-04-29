# GdUnit4 headless test runner — invoked by CI and /smoke-check.
# Usage: godot --headless --script tests/gdunit4_runner.gd
# Exits 0 on all-pass, non-zero on any failure.
extends SceneTree


func _init() -> void:
	var runner_script: Script = load("res://addons/gdunit4/GdUnitRunner.gd")
	if runner_script == null:
		push_error("GdUnit4 not found at res://addons/gdunit4/. Install via Godot AssetLib (Project → Project Settings → Plugins) before running tests.")
		quit(1)
		return
	var runner: Object = runner_script.new()
	runner.run_tests()
	quit(0)
