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
| 1 | 25416 | 25.42 |
| 2 | 26173 | 26.17 |
| 3 | 34118 | 34.12 |
| 4 | 34170 | 34.17 |
| 5 | 34232 | 34.23 |
| 6 | 34264 | 34.26 |
| 7 | 34265 | 34.27 |
| 8 | 34280 | 34.28 |
| 9 | 34306 | 34.31 |
| 10 | 34358 | 34.36 |

## Statistics
- Min: 25416 µs (25.42 ms)
- p50: 34264 µs (34.26 ms)
- p90: 34358 µs (34.36 ms)
- Max: 34358 µs (34.36 ms)

## SWAPPING phase (step 3 → step 10)
- p90: 10882 µs (10.88 ms)

## Verdict
- p90 ≤ 1500000 µs: PASS
- max ≤ 2500000 µs: PASS

## Slowest-Run Step Breakdown
| Step | Timestamp (µs) |
|---|---|
| 1 | 6662716 |
| 2 | 6662725 |
| 3 | 6676362 |
| 5 | 6676473 |
| 6 | 6684066 |
| 7 | 6684339 |
| 9 | 6687119 |
| 10 | 6687244 |
| 12 | 6697074 |
| 13 | 6697192 |

## Notes
- HEADLESS context is advisory-only; CI/LOCAL_DEV strict assertions apply.
- Iris Xe Gen 12 min-spec verification deferred per TD-002.