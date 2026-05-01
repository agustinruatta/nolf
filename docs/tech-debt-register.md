# Tech Debt Register

Active tech-debt items logged from completed stories. Each entry lists the
debt, why it's deferred, who owns it, and the trigger that re-opens it.

Format: `- [TD-NNN]` (sequential) — debt — origin — owner — trigger.

---

## Active

### TD-001 — `query.exclude` mid-loop append unreliable on Godot 4.6.2

- **Origin**: PC-005 (Interact raycast). Production bug discovered 2026-05-01: `PhysicsRayQueryParameters3D.exclude.append()` between `intersect_ray()` calls does NOT propagate to the next query call on Godot 4.6.2 Linux Vulkan, despite the project's verified-engine-reference doc claiming it does.
- **Workaround in production code**: Re-assign the entire `excludes` array each iteration (`var excludes: Array[RID] = []` + `excludes.append(rid)` + `query.exclude = excludes`). Implemented in `src/gameplay/player/player_character.gd::_resolve_interact_target()`.
- **Documentation gap**:
  - `docs/engine-reference/godot/modules/physics.md` Raycasting section claims `query.exclude` backing array is exposed by reference in 4.6 — this is INCORRECT for 4.6.2 Linux Vulkan. Update the section with a 4.6.2 caveat.
  - `production/epics/player-character/story-005-interact-raycast.md` Engine Notes also asserts the in-place pattern — update or annotate with the production-code finding.
- **Owner**: technical-director / godot-specialist
- **Re-open trigger**: Engine upgrade (4.7+) — re-test mid-loop append; if fixed in upstream Godot, update the engine-reference and consider simplifying production code.

### TD-002 — ADR-0008 Iris Xe numerical verification deferred

- **Origin**: ADR-0008 promotion 2026-05-01. Architectural-Framework Verification (Gate 5) PASSED on dev hardware; Iris Xe Gen 12 numerical Gates 1, 2, 4 remain DEFERRED.
- **What's deferred**:
  - Gate 1: Iris Xe + Restaurant scene + 12 SAI guards + Combat + outline + sepia at 60 fps p99
  - Gate 2: RTX 2060 informative measurement
  - Gate 4: Per-autoload `_ready()` instrumentation; current dev-hw aggregate 110 ms exceeds the 50 ms target
- **Re-open trigger**: Restaurant scene authored AND Stealth AI implemented AND Combat implemented AND Iris Xe Gen 12 hardware available. Re-run all 3 deferred gates; failure returns ADR-0008 to Proposed.
- **Owner**: producer / technical-director (gate scheduling)

### TD-003 — Per-autoload boot instrumentation missing

- **Origin**: ADR-0008 Gate 4 verification spike 2026-05-01. Total cold-boot time aggregated to 110 ms on dev hw; per-autoload breakdown not measured.
- **Action needed**: Add `Time.get_ticks_msec()` start/end markers to each autoload's `_ready()` and log the deltas to identify the dominant contributor (PostProcessStack suspected per ADR-0008 §Risks).
- **Re-open trigger**: Sprint 03+ when an autoload-perf story is queued; or when Iris Xe verification work begins.
- **Owner**: engine-programmer

### TD-004 — Pseudolocalization export-preset filter (LOC-002 AC-5)

- **Origin**: LOC-002 (Pseudolocalization) 2026-05-01. AC-5 requires the `export_presets.cfg` `exclude_filter` to drop `_dev_pseudo.*` from shipped builds. Presets don't exist yet (no export-pipeline story has run).
- **Required filter** (per evidence doc):
  ```ini
  exclude_filter="*/_dev_pseudo.csv,*/_dev_pseudo.*.translation,*/_dev_pseudo.# context.translation,*/_dev_pseudo.csv.import"
  ```
- **Re-open trigger**: First export-pipeline story / first `gh release` build attempt.
- **Owner**: release-manager / devops-engineer
- **Reference**: `production/qa/evidence/localization_export_filter_evidence.md`

### TD-005 — `_latch_noise_spike()` zero/negative radius unguarded (PC-005)

- **Origin**: PC-005 (Interact raycast). The `_latch_noise_spike(type, radius, origin)` method does not validate radius; current call sites all pass positive `@export_range` knobs, but a future AI-side call site could pass a 0.0 or negative value with no early-return.
- **Risk level**: LOW — current call sites are safe; risk emerges if Stealth AI calls the latch directly (unlikely; SAI reads via `get_noise_event` accessor).
- **Re-open trigger**: When AI integration introduces new `_latch_noise_spike` callers, add a radius validity guard.
- **Owner**: gameplay-programmer

### TD-006 — AC-3.1 multiplier coverage testability ceiling (PC-004)

- **Origin**: PC-004 (Noise perception surface). AC-3.1 requires testing `noise_global_multiplier` at values `{0.7, 1.0, 1.3}`; the multiplier is a ship-locked `const` per game-designer B-2 closure. Tests proxy the formula by scaling `noise_walk` instead, which proves `knob × const` reaches output but doesn't directly verify the const is read (vs hardcoded `1.0`).
- **Acknowledgement**: Inherent testability ceiling per the const design decision; not a defect.
- **Re-open trigger**: If `noise_global_multiplier` ever becomes runtime-tunable (would require new ADR), update tests to exercise it directly.
- **Owner**: qa-lead / game-designer

### TD-007 — `_resolve_surface_tag()` uses `_warned_bodies` cache that survives mission-load (FS-003)

- **Origin**: FS-003 (Surface detection raycast). Story spec calls for `_warned_bodies` to clear on mission-load. Current implementation only clears on `_ready()` — sufficient for FootstepComponent's lifetime, but the same FC instance won't see a clear when LSS swaps sections (FC is parented to PlayerCharacter which persists across sections per Story PC-007).
- **Risk level**: LOW — only affects untagged-body warning suppression. Worst case: a tagged body across section boundaries is never re-warned (which is the desired behavior anyway).
- **Re-open trigger**: PC-007 (`reset_for_respawn`) integration — consider clearing `_warned_bodies` on respawn.
- **Owner**: gameplay-programmer

---

## Closed / Promoted

(none yet)

---

**Last updated**: 2026-05-01 — initial register; 7 active items from sprint-02 close-out.
