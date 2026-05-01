# prototypes/verification-spike/stub_guard.gd
#
# StubGuard — one of 12 synthetic guard nodes used by Axis B.
#
# Polls a stub player at 10 Hz with a phase offset. Measures per-poll cost
# in microseconds and tracks MEMORY_STATIC deltas to verify zero-alloc pattern.

extends Node3D

var guard_index: int = 0

## Reference to stub player — set by spawner (untyped to avoid cross-script parse dep).
var stub_player: Node3D = null

## Phase offset before first poll fires.
var phase_offset_sec: float = 0.0

## Shared output arrays — appended by this guard, read by root scene.
var poll_results: Array = []
var alloc_deltas: Array = []

## Backref to root for worst-frame tracking.
var worst_frame_ref: Node3D = null

var _elapsed: float = 0.0
var _phase_consumed: bool = false
var _poll_interval: float = 0.0


func _ready() -> void:
	_poll_interval = 1.0 / 10.0


func _process(delta: float) -> void:
	if stub_player == null:
		return

	_elapsed += delta

	if not _phase_consumed:
		if _elapsed < phase_offset_sec:
			return
		_phase_consumed = true
		_elapsed = 0.0

	if _elapsed >= _poll_interval:
		_elapsed -= _poll_interval
		_do_poll()


func _do_poll() -> void:
	var mem_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))

	var t0: int = Time.get_ticks_usec()

	# Call the two stub methods — untyped calls since stub_player is Node3D
	var _noise_level: float = stub_player.get_noise_level()
	var noise_event = stub_player.get_noise_event()

	# Copy the scalar fields we need before next mutation (mirrors real guard behaviour)
	var _copied_radius: float = noise_event.radius_m
	var _copied_origin: Vector3 = noise_event.origin

	var t1: int = Time.get_ticks_usec()

	var mem_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))

	poll_results.append(float(t1 - t0))
	alloc_deltas.append(mem_after - mem_before)

	# Update worst-case poll on root
	if worst_frame_ref != null:
		var poll_ms: float = float(t1 - t0) / 1000.0
		var current_worst: float = worst_frame_ref.get("_worst_frame_poll_ms")
		if poll_ms > current_worst:
			worst_frame_ref.set("_worst_frame_poll_ms", poll_ms)
