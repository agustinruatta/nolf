# tests/unit/feature/settings/audio_formula_test.gd
#
# AudioFormulaTest — GdUnit4 suite for Story SA-004.
#
# PURPOSE
#   AC-1 / AC-2 / AC-5 / AC-6 / AC-7 — F.1 forward + inverse round-trip,
#   silence sentinel, NaN guard, sub-Segment-A audible-but-quiet branch.
#
# GOVERNING REQUIREMENTS
#   GDD F.1 two-segment perceptual fader; AC-SA-3.1 / 3.2 / 3.5 / 11.13.

class_name AudioFormulaTest
extends GdUnitTestSuite


# ── AC-1: Round-trip fidelity within ±0.5 percentage points ──────────────────

func test_round_trip_pct_to_db_to_pct_within_half_point_for_sample_set() -> void:
	var positions: Array[int] = [0, 1, 50, 74, 75, 76, 100]
	for p in positions:
		var db: float = AudioSettingsFormula.pct_to_db(float(p))
		var p_recovered: int = AudioSettingsFormula.db_to_pct(db)
		assert_int(absi(p_recovered - p)).override_failure_message(
			"Round-trip failed for p=%d: db=%f, p_recovered=%d (delta=%d > 0)" % [p, db, p_recovered, absi(p_recovered - p)]
		).is_less_equal(0)


# ── AC-2: Silence sentinel at p=0 returns DB_FLOOR ───────────────────────────

func test_pct_to_db_zero_returns_silence_floor() -> void:
	var db: float = AudioSettingsFormula.pct_to_db(0.0)
	assert_float(db).is_equal(AudioSettingsFormula.DB_FLOOR)


func test_is_silence_returns_true_for_zero_position() -> void:
	assert_bool(AudioSettingsFormula.is_silence(0.0)).is_true()
	assert_bool(AudioSettingsFormula.is_silence(0.4)).override_failure_message(
		"p=0.4 rounds to 0 → silence."
	).is_true()
	assert_bool(AudioSettingsFormula.is_silence(0.5)).override_failure_message(
		"p=0.5 rounds to 1 → audible."
	).is_false()
	assert_bool(AudioSettingsFormula.is_silence(1.0)).is_false()


# ── AC-5: Out-of-range clamp guards (forward + inverse) ──────────────────────

func test_pct_to_db_clamps_above_100_to_zero_db() -> void:
	# p=101 → clamps to 100 → top of Segment B → 0 dB
	var db: float = AudioSettingsFormula.pct_to_db(101.0)
	assert_float(db).is_equal(0.0)


func test_pct_to_db_clamps_below_zero_to_silence_floor() -> void:
	# p=-1 → clamps to 0 → silence floor
	var db: float = AudioSettingsFormula.pct_to_db(-1.0)
	assert_float(db).is_equal(AudioSettingsFormula.DB_FLOOR)


func test_db_to_pct_clamps_above_zero_to_100() -> void:
	# dB=+5 → clamps to 0 dB → p=100
	var p: int = AudioSettingsFormula.db_to_pct(5.0)
	assert_int(p).is_equal(100)


func test_db_to_pct_clamps_below_floor_to_zero() -> void:
	# dB=-100 → clamps to -80 → p=0
	var p: int = AudioSettingsFormula.db_to_pct(-100.0)
	assert_int(p).is_equal(0)


# ── AC-6: NaN + inf guards (forward + inverse) ───────────────────────────────

func test_pct_to_db_nan_returns_silence_floor() -> void:
	var db: float = AudioSettingsFormula.pct_to_db(NAN)
	assert_float(db).override_failure_message(
		"NaN input must fold to silence floor (NaN-safe via is_nan precondition)."
	).is_equal(AudioSettingsFormula.DB_FLOOR)


func test_pct_to_db_inf_returns_silence_floor() -> void:
	# +inf → folded to 0 by precondition → silence sentinel
	var db: float = AudioSettingsFormula.pct_to_db(INF)
	assert_float(db).is_equal(AudioSettingsFormula.DB_FLOOR)


func test_db_to_pct_nan_returns_zero_position() -> void:
	var p: int = AudioSettingsFormula.db_to_pct(NAN)
	assert_int(p).is_equal(0)


func test_db_to_pct_inf_returns_zero_position() -> void:
	var p: int = AudioSettingsFormula.db_to_pct(INF)
	# inf folds to DB_FLOOR via precondition → p=0
	assert_int(p).is_equal(0)


# ── AC-7: Sub-Segment-A inverse returns p=1, not p=0 ────────────────────────

func test_db_to_pct_below_segment_a_floor_returns_one_not_zero() -> void:
	# -50 dB is below Segment A floor (-24) but above silence floor (-80).
	# Per the audible-but-quiet rule, return p=1 (slider shows audible),
	# NOT p=0 (silence sentinel).
	var p: int = AudioSettingsFormula.db_to_pct(-50.0)
	assert_int(p).override_failure_message(
		"dB=-50 (below Segment A, above silence floor) must return p=1 (audible-but-quiet), not p=0."
	).is_equal(1)


# ── F.1 specific value sanity checks ─────────────────────────────────────────

func test_pct_to_db_at_knee_returns_minus_12_db() -> void:
	# p=75 (knee) → -12 dB exactly per Segment B base.
	var db: float = AudioSettingsFormula.pct_to_db(75.0)
	assert_float(db).is_equal(-12.0)


func test_pct_to_db_at_max_returns_zero_db() -> void:
	# p=100 → 0 dB (max output).
	var db: float = AudioSettingsFormula.pct_to_db(100.0)
	assert_float(db).is_equal(0.0)


func test_pct_to_db_at_one_returns_segment_a_base() -> void:
	# p=1 → -24 dB exactly (Segment A base, audible-but-quiet floor).
	var db: float = AudioSettingsFormula.pct_to_db(1.0)
	assert_float(db).is_equal(AudioSettingsFormula.SEGMENT_A_BASE)
