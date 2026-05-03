# LS-007 Manual Evidence — F5 mid-transition produces post-transition save chime

> **Status**: DEFERRED — populate when MVP build with audio integration is producible.
> **Related**: AC-8 (manual walkthrough that the save-confirm chime fires AFTER snap-reveal completes, not during the transition cut)
> **Story**: `production/epics/level-streaming/story-007-quicksave-quickload-queue-during-transition.md`

## Why deferred

AC-8 verifies the human-perceived audio + UI integration during a mid-transition F5 press:
- Save-confirm chime audible AFTER snap-reveal (not during the FADING_OUT/SWAPPING/FADING_IN cut)
- Save card visible in Menu post-transition (slot 0 has fresh save with current section captured)

This requires:
1. A producible MVP build with full audio integration (Audio epic shipped Sprint 07 ✅)
2. A live mid-transition F5 input in a real game session (cannot be automated headlessly — F5 is an `Input` event, not a `LSS` API call)

Sprint 08 LS-007 ships:
- The LSS API surface (`queue_quicksave_or_fire()` + `queue_quickload_or_fire()`) — verified by `tests/integration/level_streaming/level_streaming_quicksave_queue_test.gd` (AC-1..AC-7 + AC-9, 12 tests)
- The drain-at-FADING_IN→IDLE plumbing — automated via signal-spy assertions
- The `_abort_transition` extension for queue-clearing — automated

The audio + UI feel verification (AC-8) is the only DEFERRED item.

## Manual verification protocol

When MVP build is producible:

1. Run a live game session in debug mode.
2. Trigger a section transition (e.g., walk into a transition trigger volume in Plaza or trigger via debug menu).
3. **During FADING_OUT or SWAPPING phase** (~330ms after transition begins; observe the screen fading to black), press **F5**.
4. Observe and capture:
   - **Audio**: NO save-confirm chime during the transition cut (silent during fade-out → swap → fade-in)
   - **Audio**: Save-confirm chime audible AFTER snap-reveal completes (player regains control, screen is fully visible)
   - **HUD**: NO HUD save-toast or feedback during the transition cut
5. Open Menu after transition completes:
   - Slot 0 (quicksave slot) shows a fresh save with `current_section` reflecting the post-transition section
   - Save metadata shows the timestamp matches the F5 press time

## Evidence to capture

- [ ] Video clip (≥5 seconds) capturing the full sequence: F5 press → transition cut (silent) → snap-reveal → chime
- [ ] Screenshot of Menu showing the slot 0 entry post-F5
- [ ] Audio waveform OR debug log showing chime fires AFTER `Events.section_entered` (not during)
- [ ] Sign-off: `[qa-tester / lead-programmer name] [date]`

## Notes

- The drain ordering rationale (per ADR-0007 §CR-16): if F5 fires during transition and respawn ALSO queued, the F5 quicksave fires FIRST (preserves "I want to save my current state NOW" intent), then quickload OR respawn fires. This is verified automatically by `test_quicksave_and_quickload_both_queued_drain_in_correct_order` (AC-5).
- Edge case (rare): player presses F5 during the LAST 2 frames of FADING_IN (right before IDLE). The drain still fires correctly because step 13 IDLE-set runs synchronously before the drain check. Automated by `test_quicksave_queued_during_fading_in_drains_after_idle` (AC-4).
- Save/Load Story 007's `QuicksaveInputHandler` already delegates to `LevelStreamingService.queue_quicksave_or_fire()` (verified at code-review time by `test_quicksave_input_handler_delegates_to_lss_not_save_load_directly`, AC-9).

## Implementation references

- LSS public API: `src/core/level_streaming/level_streaming_service.gd::queue_quicksave_or_fire()` + `::queue_quickload_or_fire()`
- LSS step-13 drain: `src/core/level_streaming/level_streaming_service.gd::_run_swap_sequence()` (drain order: quicksave → quickload → respawn)
- Save/Load handler: `src/core/save_load/quicksave_input_handler.gd::_try_quicksave()` (delegates to LSS)
- Audio stinger: Audio epic Sprint 07 (AUD-005 COMBAT stinger applies to save-confirm chime via `Events.game_saved` subscriber)
