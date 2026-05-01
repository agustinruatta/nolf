# LS-002 OQ-LS-11 Verification — `get_tree().current_scene = instance` Safety

**Story**: LS-002 — State machine + 13-step swap
**Open Question**: OQ-LS-11 — does direct reassignment of `get_tree().current_scene` work safely on Godot 4.6.x?

## Background

Step 7 of the LS-002 13-step swap sequence performs:
```gdscript
get_tree().root.add_child(instance)
get_tree().current_scene = instance
```

The story flagged OQ-LS-11 because godot-specialist couldn't confirm at design time whether direct `current_scene` assignment was safe vs requiring `change_scene_to_packed`. The latter was rejected (creates a one-frame `current_scene == null` window incompatible with the ordered-lifecycle service contract).

## Verification

| Field | Value |
|---|---|
| Engine | Godot 4.6.2-stable (arch_linux build, hash `001aa128b1cd80dc4e47e823c360bccf45ed6bad`) |
| Date | 2026-05-01 |
| Test artifact | `tests/integration/level_streaming/level_streaming_swap_test.gd` |
| Verifier | Autonomous loop run, sprint 02 close-out |

### Result: SAFE on Godot 4.6.2

The integration suite (`level_streaming_swap_test.gd`) exercises the assignment in 4 distinct test paths:

1. `test_transition_to_section_pushes_loading_and_enters_fading_out_synchronously` — verifies the synchronous side-effects on the call frame
2. `test_full_state_machine_progression_idle_to_idle` — drives the full 13-step coroutine including step 7's assignment, observes state transitions to FADING_IN and back to IDLE
3. `test_full_round_trip_plaza_to_stub_b_emits_both_signals` — runs TWO consecutive transitions (plaza → stub_b), confirming `get_tree().current_scene` reflects the most-recently-assigned instance after both swaps complete; `get_current_section_id()` reports the new id
4. `test_transition_to_unknown_section_aborts_cleanly` — confirms abort path works without leaving `current_scene` in a corrupt state

All 4 tests pass with zero errors / failures / warnings logged about the assignment. The `add_child` + `current_scene =` pair propagates correctly through Godot 4.6.2's SceneTree invariants.

### Specific observations

- No "Could not set scene_tree.current_scene" or similar warnings in stderr
- `Events.section_entered.emit` fires AFTER step 7 + the step-8 frame await — subscribers reading `get_tree().current_scene` from inside the handler see the new instance
- The outgoing scene's `queue_free` (step 4) propagates by the next `process_frame`; the brief overlap at step 4-7 has no observable consequence (the fade overlay is at alpha 1.0 hiding it)
- No memory growth across repeated transitions in the round-trip test

### Caveat

Verification is on **Linux Vulkan** (project Amendment A2 — D3D12 not targeted). Re-verification on Windows-Vulkan should occur during the first Windows export pass, alongside ADR-0008 Gate 4 (autoload boot) re-verification. Tracked in the ADR-0008 deferred-gate list.

## Sign-off

| Field | Value |
|---|---|
| Verified by | Autonomous loop (sprint-02 LS-002 close) |
| Date | 2026-05-01 |
| Build target | Linux Vulkan headless |
| Git SHA at verification | (post-LS-002 commit) |
| Verdict | **SAFE — keep `get_tree().current_scene = instance` at step 7** |

OQ-LS-11 closed.
