# Level Streaming Perf Measurement — 2026-05-03

## Environment
- Context: HEADLESS
- Hardware: Intel(R) Core(TM) i9-14900HX
- Godot: 4.6.2-stable (arch_linux)
- DisplayServer: headless

## Thresholds (HEADLESS)
- p90 ≤ 1500000 µs (1500.0 ms)
- max ≤ 2500000 µs (2500.0 ms)

## 10-Run Durations
| Run | Total (µs) | Total (ms) |
|---|---|---|
| 1 | 26557 | 26.56 |
| 2 | 26963 | 26.96 |
| 3 | 34018 | 34.02 |
| 4 | 34101 | 34.10 |
| 5 | 34169 | 34.17 |
| 6 | 34221 | 34.22 |
| 7 | 34316 | 34.32 |
| 8 | 34334 | 34.33 |
| 9 | 34351 | 34.35 |
| 10 | 34389 | 34.39 |

## Statistics
- Min: 26557 µs (26.56 ms)
- p50: 34221 µs (34.22 ms)
- p90: 34389 µs (34.39 ms)
- Max: 34389 µs (34.39 ms)

## SWAPPING phase (step 3 → step 10)
- p90: 11112 µs (11.11 ms)

## Verdict
- p90 ≤ 1500000 µs: PASS
- max ≤ 2500000 µs: PASS

## Slowest-Run Step Breakdown
| Step | Timestamp (µs) |
|---|---|
| 1 | 7132803 |
| 2 | 7132810 |
| 3 | 7146459 |
| 5 | 7146584 |
| 6 | 7153469 |
| 7 | 7153775 |
| 9 | 7156492 |
| 10 | 7156646 |
| 12 | 7167192 |
| 13 | 7167306 |

## Notes
- HEADLESS context is advisory-only; CI/LOCAL_DEV strict assertions apply.
- Iris Xe Gen 12 min-spec verification deferred per TD-002.