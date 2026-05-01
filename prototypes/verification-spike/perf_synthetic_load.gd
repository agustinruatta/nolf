# prototypes/verification-spike/perf_synthetic_load.gd
#
# ADR-0008 Synthetic Load Spike
#
# Purpose: Framework verification for ADR-0008 (Performance Budget Distribution).
# Exercises four measurable axes simultaneously over a 30-second headless capture:
#
#   Axis A — Autoload cold-boot timing (ADR-0008 Gate 4 — ≤50 ms cold-start)
#   Axis B — Slot-5 polling load (12 stub guards at 10 Hz each = 120 polls/sec)
#   Axis C — Signal-bus emit cost (player_footstep at ~3.5 Hz)
#   Axis D — Save-write under load (save_to_slot at T=15s, ≤10 ms budget)
#
# NOT a src/ file. Run headless:
#   godot --headless --path /home/vdx/Projects/Claude-Code-Game-Studios \
#         prototypes/verification-spike/perf_synthetic_load.tscn --quit-after 35

extends Node3D

# Preload stub scripts so class references resolve without autoload registration.
const StubPlayerCharacterScript = preload("res://prototypes/verification-spike/stub_player_character.gd")
const StubGuardScript = preload("res://prototypes/verification-spike/stub_guard.gd")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

const CAPTURE_DURATION_SEC: float = 30.0
const GUARD_COUNT: int = 12
const GUARD_POLL_HZ: float = 10.0
const FOOTSTEP_HZ: float = 3.5
const SAVE_TRIGGER_SEC: float = 15.0

# ---------------------------------------------------------------------------
# State — Axis A
# ---------------------------------------------------------------------------
var _process_start_ms: int = 0

# ---------------------------------------------------------------------------
# State — Axis B
# ---------------------------------------------------------------------------
var _stub_player: Node3D   # StubPlayerCharacter instance
var _guards: Array = []    # Array of StubGuard instances

var _poll_times_us: Array = []     # Array[float] — per-poll duration µs
var _worst_frame_poll_ms: float = 0.0
var _alloc_deltas: Array = []      # Array[int] — MEMORY_STATIC delta per poll

# ---------------------------------------------------------------------------
# State — Axis C
# ---------------------------------------------------------------------------
var _footstep_timer: float = 0.0
var _footstep_emit_count: int = 0
var _footstep_times_us: Array = []  # Array[float] — per-emit duration µs
var _footstep_received: int = 0

# ---------------------------------------------------------------------------
# State — Axis D
# ---------------------------------------------------------------------------
var _save_triggered: bool = false
var _save_latency_ms: float = -1.0
var _save_result: bool = false

# ---------------------------------------------------------------------------
# Frame capture
# ---------------------------------------------------------------------------
var _frame_times_ms: Array = []    # Array[float]
var _capture_elapsed: float = 0.0
var _capture_active: bool = false
var _warmup_frames: int = 5


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	_process_start_ms = Time.get_ticks_msec()


func _ready() -> void:
	print("=== ADR-0008 Synthetic Load Spike ===")
	print("Godot: ", Engine.get_version_info())
	print("process_start: %d ms" % _process_start_ms)
	print("_ready() at:   %d ms" % Time.get_ticks_msec())
	print("")

	_report_axis_a()
	_setup_axis_b()
	Events.player_footstep.connect(_on_footstep_received)

	_capture_active = true
	print("--- Capture armed: 30-second window ---")
	print("")


func _process(delta: float) -> void:
	if not _capture_active:
		return

	_warmup_frames -= 1
	if _warmup_frames < 0:
		_frame_times_ms.append(delta * 1000.0)

	_capture_elapsed += delta

	# Axis C — footstep emit
	_footstep_timer += delta
	if _footstep_timer >= (1.0 / FOOTSTEP_HZ):
		_footstep_timer -= (1.0 / FOOTSTEP_HZ)
		_emit_footstep()

	# Axis D — save at T=15s
	if not _save_triggered and _capture_elapsed >= SAVE_TRIGGER_SEC:
		_save_triggered = true
		_trigger_save()

	# End capture
	if _capture_elapsed >= CAPTURE_DURATION_SEC:
		_capture_active = false
		_finalize_and_print_report()
		get_tree().quit(0)


# ---------------------------------------------------------------------------
# Axis A
# ---------------------------------------------------------------------------

func _report_axis_a() -> void:
	print("--- Axis A: Autoload Cold-Boot Timing ---")
	print("  project.godot autoloads (10 total — ADR-0008 assumed 4; delta noted):")
	print("   1  Events              (SignalBusEvents)")
	print("   2  EventLogger         (SignalBusEventLogger)")
	print("   3  SaveLoad            (SaveLoadService)")
	print("   4  InputContext        (InputContextStack)")
	print("   5  LevelStreamingService")
	print("   6  PostProcessStack")
	print("   7  Combat              (CombatSystemNode)")
	print("   8  FailureRespawn      (FailureRespawnService)")
	print("   9  MissionLevelScripting")
	print("  10  SettingsService")
	print("")

	var now_ms: int = Time.get_ticks_msec()
	var total_boot_ms: int = now_ms - _process_start_ms
	print("  process_start -> scene _ready() delta: %d ms (all 10 autoloads + scene load)" % total_boot_ms)

	if total_boot_ms <= 50:
		print("  Gate 4 (<=50 ms): PASS (%d ms with 10 autoloads)" % total_boot_ms)
	else:
		print("  Gate 4 (<=50 ms): FAIL (%d ms — OVER BUDGET)" % total_boot_ms)

	print("  [METHODOLOGY NOTE] Individual per-autoload timestamps require instrumentation")
	print("  inside each autoload _ready(). This spike measures aggregate upper-bound only.")
	print("")


# ---------------------------------------------------------------------------
# Axis B
# ---------------------------------------------------------------------------

func _setup_axis_b() -> void:
	_stub_player = StubPlayerCharacterScript.new()
	_stub_player.name = "StubPlayerCharacter"
	add_child(_stub_player)

	for i in range(GUARD_COUNT):
		var guard = StubGuardScript.new()
		guard.name = "StubGuard_%02d" % i
		guard.guard_index = i
		guard.stub_player = _stub_player
		guard.poll_results = _poll_times_us
		guard.alloc_deltas = _alloc_deltas
		guard.worst_frame_ref = self
		guard.phase_offset_sec = float(i) * (1.0 / GUARD_POLL_HZ / float(GUARD_COUNT))
		add_child(guard)
		_guards.append(guard)

	print("--- Axis B: Spawned %d stub guards (10 Hz each, phase-offset) ---" % GUARD_COUNT)
	print("")


# ---------------------------------------------------------------------------
# Axis C
# ---------------------------------------------------------------------------

func _emit_footstep() -> void:
	var t0: int = Time.get_ticks_usec()
	Events.player_footstep.emit(&"stone", 4.5)
	var t1: int = Time.get_ticks_usec()
	_footstep_times_us.append(float(t1 - t0))
	_footstep_emit_count += 1


func _on_footstep_received(_surface: StringName, _noise_radius: float) -> void:
	_footstep_received += 1


# ---------------------------------------------------------------------------
# Axis D
# ---------------------------------------------------------------------------

func _trigger_save() -> void:
	print("--- Axis D: Triggering save_to_slot at T=%.1f s ---" % _capture_elapsed)
	var save_game := SaveGame.new()
	save_game.section_id = &"synthetic_load_spike"
	save_game.saved_at_iso8601 = "2026-05-01T00:00:00"
	save_game.elapsed_seconds = _capture_elapsed

	var t0: int = Time.get_ticks_usec()
	_save_result = SaveLoad.save_to_slot(1, save_game)
	var t1: int = Time.get_ticks_usec()
	_save_latency_ms = float(t1 - t0) / 1000.0

	print("  Result: %s" % ("success" if _save_result else "failed"))
	print("  Latency: %.3f ms" % _save_latency_ms)
	print("  Axis D (<=10 ms): %s" % ("PASS" if _save_latency_ms <= 10.0 else "FAIL"))
	print("")


# ---------------------------------------------------------------------------
# Final report
# ---------------------------------------------------------------------------

func _finalize_and_print_report() -> void:
	print("")
	print("======================================================")
	print("=== ADR-0008 SYNTHETIC LOAD REPORT                ===")
	print("======================================================")
	print("")

	# Axis B
	print("--- Axis B: Guard Polling (Slot-5 Proxy) ---")
	print("  Guards: %d x 10 Hz = 120 polls/sec aggregate (>= 80 Hz spec)" % GUARD_COUNT)
	var n_polls: int = _poll_times_us.size()
	if n_polls > 0:
		var sorted_b: Array = _poll_times_us.duplicate()
		sorted_b.sort()
		var sum_b: float = 0.0
		for v in sorted_b:
			sum_b += v
		print("  Total polls: %d" % n_polls)
		print("  Per-poll: mean=%.2f us  p50=%.2f us  p95=%.2f us  p99=%.2f us  max=%.2f us" % [
			sum_b / n_polls,
			sorted_b[int(n_polls * 0.50)],
			sorted_b[int(n_polls * 0.95)],
			sorted_b[int(n_polls * 0.99)],
			sorted_b[n_polls - 1]
		])
	else:
		print("  No poll data.")

	var n_allocs: int = _alloc_deltas.size()
	if n_allocs > 0:
		var nonzero: int = 0
		for d in _alloc_deltas:
			if d != 0:
				nonzero += 1
		print("  Alloc checks: %d  |  Non-zero frames: %d" % [n_allocs, nonzero])
		if nonzero == 0:
			print("  Zero-alloc: VERIFIED (NoiseEvent in-place mutation confirmed)")
		else:
			print("  Zero-alloc: REGRESSION (%d frames had unexpected allocations)" % nonzero)
	print("  Worst single-poll: %.4f ms" % _worst_frame_poll_ms)
	print("")

	# Axis C
	print("--- Axis C: Signal-Bus Emit (player_footstep @ 3.5 Hz) ---")
	var n_emits: int = _footstep_emit_count
	print("  Emitted: %d  |  Received: %d  |  Drop: %.1f%%" % [
		n_emits,
		_footstep_received,
		100.0 * (1.0 - float(_footstep_received) / max(1.0, float(n_emits)))
	])
	var n_c: int = _footstep_times_us.size()
	if n_c > 0:
		var sorted_c: Array = _footstep_times_us.duplicate()
		sorted_c.sort()
		var sum_c: float = 0.0
		for v in sorted_c:
			sum_c += v
		print("  Per-emit: mean=%.2f us  p50=%.2f us  p95=%.2f us  p99=%.2f us  max=%.2f us" % [
			sum_c / n_c,
			sorted_c[int(n_c * 0.50)],
			sorted_c[int(n_c * 0.95)],
			sorted_c[int(n_c * 0.99)],
			sorted_c[n_c - 1]
		])
	print("")

	# Axis D
	print("--- Axis D: Save-Write Under Load ---")
	if _save_latency_ms >= 0.0:
		print("  Latency: %.3f ms  |  Result: %s  |  Budget (10 ms): %s" % [
			_save_latency_ms,
			"success" if _save_result else "failed",
			"PASS" if _save_latency_ms <= 10.0 else "FAIL"
		])
	else:
		print("  Save never triggered.")
	print("")

	# Frame histogram
	print("--- Frame-Time Histogram (30-second capture) ---")
	var n_ft: int = _frame_times_ms.size()
	if n_ft > 0:
		var ft: Array = _frame_times_ms.duplicate()
		ft.sort()
		var sum_ft: float = 0.0
		for v in ft:
			sum_ft += v
		var p50: float = ft[int(n_ft * 0.50)]
		var p95: float = ft[int(n_ft * 0.95)]
		var p99: float = ft[int(n_ft * 0.99)]
		var max_ft: float = ft[n_ft - 1]
		print("  Frames: %d  |  Mean: %.3f ms" % [n_ft, sum_ft / n_ft])
		print("  p50: %.3f ms  p95: %.3f ms  p99: %.3f ms  max: %.3f ms" % [p50, p95, p99, max_ft])
		var over: int = 0
		for v in ft:
			if v > 16.6:
				over += 1
		print("  Over 16.6 ms: %d / %d (%.1f%%)" % [over, n_ft, 100.0 * over / n_ft])
		if over == 0:
			print("  Frame budget: PASS")
		else:
			print("  Frame budget: OVER (headless — no GPU render cost; note for interpretation)")
	else:
		print("  No frame data.")

	print("")
	print("======================================================")
	print("=== END ADR-0008 SYNTHETIC LOAD REPORT            ===")
	print("======================================================")
