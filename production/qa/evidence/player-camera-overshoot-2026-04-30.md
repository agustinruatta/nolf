# QA Evidence — Player Camera Turn Overshoot Visual Feel (AC-7.4)

**Story**: PC-002 — First-person camera + look input
**AC**: 7.4 (Visual/Feel; art-director sign-off)
**Status**: Pending — first art-director review

## Acceptance Criterion

Rapid yaw input (> 180°/s) produces a perceptible yaw overshoot within
`turn_overshoot_deg ± 0.5°` (3.5° – 4.5°) and the overshoot settles
monotonically within `90 ± 10 ms`. Reads as "deliberate camera settle"
and not "drunk".

## Verification Procedure

1. Build the game (debug build acceptable).
2. Load `tests/scenes/player_camera_overshoot_review.tscn` (or any scene
   with PlayerCharacter + a camera-recording overlay).
3. Drive 5 rapid yaw sequences via mouse: 180°/s, 360°/s, 540°/s,
   720°/s, stop-and-reverse. Use a mouse macro or input recording for
   reproducibility.
4. Capture frame-by-frame `camera.basis.get_euler().y` for each sequence.
5. Plot the curves OR review in real-time at slowed playback.

## Expected (PASS)

- Each sequence shows a peak-then-settle curve.
- Settle is monotonic — no secondary oscillation.
- Overshoot amplitude for 360°/s input is in 3.5° – 4.5°.
- Subjective: reads as "deliberate weight" and "deliberate settle".
- Subjective: does NOT read as "drunk camera" or motion-sick-inducing.

## Sign-off

| Field | Value |
|-------|-------|
| Reviewer | _Pending — art-director_ |
| Date | _Pending_ |
| Build SHA | _Pending_ |
| Verdict | _Pending_ |
| Notes | _Pending_ |
