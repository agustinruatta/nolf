# Quick diagnostic: how fast does _process run in headless mode?
extends Node

var _frame_count: int = 0
var _total_elapsed: float = 0.0
var _start_real: int = 0

func _ready() -> void:
	_start_real = Time.get_ticks_msec()

func _process(delta: float) -> void:
	_frame_count += 1
	_total_elapsed += delta
	if _frame_count == 60:
		var real_elapsed: int = Time.get_ticks_msec() - _start_real
		print("After 60 frames: game_time=%.3f s  wall_time=%d ms  fps=%.1f" % [
			_total_elapsed, real_elapsed, 60.0 / _total_elapsed])
		get_tree().quit(0)
