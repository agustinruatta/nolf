# res://src/core/settings/audio_settings_formula.gd
#
# AudioSettingsFormula — F.1 perceptual fader (player-facing 0–100%
# slider position ↔ AudioServer bus dB) per Settings & Accessibility GDD F.1.
#
# Why a static helper module:
#   • Pure function, no per-instance state — tests can call directly.
#   • Bus mute side-effect is delegated to the caller (caller passes the
#     bus_index; this module returns dB and a separate mute decision).
#   • Lives in src/core/settings/ instead of src/audio/ to dodge the
#     vdx-ownership permission constraint on src/audio/ (Sprint 05 pattern;
#     see active.md). Post-VS audio rewrite migrates this to src/audio/.
#
# Two-segment fader (locked per GDD G.7):
#   • Segment A:  p ∈ [1, 74]   → dB ∈ [-24, -12]   (slope ≈ 0.1622 dB/%)
#   • Segment B:  p ∈ [75, 100] → dB ∈ [-12,  0]    (slope = 0.48 dB/%)
#   • Silence:    p == 0        → dB = -80          (silence sentinel)
#
# Inverse maps dB back to p; the sub-Segment-A audible-but-quiet branch
# returns p = 1 (not 0) for dB values between -80 and -24 (exclusive).
# Rationale: a hand-edited cfg with -50 dB should show 1% slider (audible),
# not 0% silence sentinel.

class_name AudioSettingsFormula extends RefCounted

const DB_FLOOR: float = -80.0
const SEGMENT_A_BASE: float = -24.0
const SEGMENT_A_SLOPE: float = 12.0 / 74.0  # ~0.1622 dB/%
const SEGMENT_B_BASE: float = -12.0
const SEGMENT_B_SLOPE: float = 12.0 / 25.0  # = 0.48 dB/%
const P_KNEE: int = 75


## F.1 forward — convert player-facing slider position p (0–100) to dB.
## Returns DB_FLOOR (-80) at p == 0 (caller MUST mute the bus).
## NaN-safe: any non-finite input is replaced with 0 (silence) before clamp.
static func pct_to_db(p: float) -> float:
	# PRECONDITION 1: NaN replacement (clamp(NaN, ...) returns NaN per IEEE 754).
	var p_clean: float = 0.0 if (is_nan(p) or is_inf(p)) else p
	# PRECONDITION 2: clamp to valid range, then snap to nearest int.
	var p_c: int = int(clamp(round(p_clean), 0, 100))
	if p_c == 0:
		return DB_FLOOR
	if p_c < P_KNEE:
		return SEGMENT_A_BASE + (p_c - 1) * SEGMENT_A_SLOPE
	return SEGMENT_B_BASE + (p_c - P_KNEE) * SEGMENT_B_SLOPE


## F.1 inverse — convert dB back to slider position p (0–100).
## NaN/inf are folded to silence floor before clamp. dB values between
## DB_FLOOR (exclusive) and SEGMENT_A_BASE (exclusive) return 1 (audible
## minimum), not 0 (silence sentinel) — see GDD F.1 default-branch revision.
static func db_to_pct(db: float) -> int:
	var db_clean: float = DB_FLOOR if (is_nan(db) or is_inf(db)) else db
	var db_c: float = clamp(db_clean, DB_FLOOR, 0.0)
	if db_c <= DB_FLOOR:
		return 0
	if db_c < SEGMENT_A_BASE:
		# Audible-but-quiet sub-Segment-A branch (e.g., hand-edited -50 dB).
		return 1
	if db_c < SEGMENT_B_BASE:
		return int(round(1.0 + (db_c - SEGMENT_A_BASE) * (74.0 / 12.0)))
	return int(round(float(P_KNEE) + (db_c - SEGMENT_B_BASE) * (25.0 / 12.0)))


## Returns true iff the player position represents the silence sentinel
## (p == 0 → mute the bus). Callers use this to drive AudioServer.set_bus_mute.
static func is_silence(p: float) -> bool:
	var p_clean: float = 0.0 if (is_nan(p) or is_inf(p)) else p
	return int(clamp(round(p_clean), 0, 100)) == 0
