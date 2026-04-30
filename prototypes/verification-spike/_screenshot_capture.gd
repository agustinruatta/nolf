# prototypes/verification-spike/_screenshot_capture.gd
#
# Throwaway helper used by the verification spike to capture a screenshot
# of a target scene and write it to disk so the agent can view it without
# the Godot editor open. Underscore prefix marks it as a tooling helper.
#
# Usage:
#   godot --rendering-driver vulkan --resolution 1280x720 \
#     res://prototypes/verification-spike/_screenshot_capture.tscn -- \
#     --target=res://prototypes/verification-spike/stencil_outline_demo.tscn \
#     --out=user://stencil_outline_demo.png

extends Node

const FRAMES_TO_SETTLE := 5

var _target_scene_path: String = ""
var _out_path: String = ""


func _ready() -> void:
	_parse_args()
	if _target_scene_path.is_empty():
		push_error("[capture] missing --target=<scene path>")
		get_tree().quit(1)
		return

	var packed := load(_target_scene_path) as PackedScene
	if packed == null:
		push_error("[capture] failed to load %s" % _target_scene_path)
		get_tree().quit(2)
		return

	var instance := packed.instantiate()
	add_child(instance)
	print("[capture] target loaded: %s" % _target_scene_path)

	# Let the scene render a few frames so transient GPU state settles.
	for i in range(FRAMES_TO_SETTLE):
		await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var save_err := img.save_png(_out_path)
	if save_err != OK:
		push_error("[capture] save_png failed: %d" % save_err)
		get_tree().quit(3)
		return
	print("[capture] screenshot saved → %s" % _out_path)
	get_tree().quit(0)


func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		if raw_arg.begins_with("--target="):
			_target_scene_path = raw_arg.trim_prefix("--target=")
		elif raw_arg.begins_with("--out="):
			_out_path = raw_arg.trim_prefix("--out=")
	if _out_path.is_empty():
		_out_path = "user://capture.png"
