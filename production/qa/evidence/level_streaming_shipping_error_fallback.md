# LS-005 Manual Evidence — ErrorFallback shipping-build behavior

> **Status**: DEFERRED — populate when shipping export build is producible.
> **Related**: AC-6 (debug-build 2-second display + auto-MainMenu route) and AC-8 (shipping-build no-op `_simulate_registry_failure`).
> **Story**: `production/epics/level-streaming/story-005-registry-failure-error-fallback-recovery.md`

## Why deferred

AC-6 and AC-8 require a producible shipping export to verify:
- AC-6: shipping-build ErrorFallback flash-OR-skip behavior (debug-build 2s display is automated via `level_streaming_failure_recovery_test.gd`)
- AC-8: `_simulate_registry_failure()` is a no-op in shipping (`OS.is_debug_build()` guard at function entry — verifiable only via export-build inspection)

Sprint 08 ships with the automated portion of AC-6 (debug-build path) covered by the integration test. The shipping-build evidence below is to be filled when:
1. The export pipeline is stable (Sprint 09+ asset spec phase or later)
2. A representative export build is produced with a deliberate registry failure injected

## Manual verification protocol

When a shipping build is producible:

### AC-6 shipping-build path
1. Build the project in Release/Shipping mode (no debug symbols, `OS.is_debug_build()` returns false).
2. In a build with intentional registry-miss (e.g., temporarily remove an entry from `section_registry.tres`), trigger a `transition_to_section(&"missing_id", null, FORWARD)` from a debug hotkey or bootstrapping path.
3. Observe one of two acceptable behaviors:
   - **Flash**: ErrorFallback.tscn flashes briefly (≤1s) before auto-routing to MainMenu.tscn
   - **Skip**: Direct route to MainMenu.tscn without ErrorFallback being visible.
4. **Capture**: screenshot or 2-second screen recording showing the result.
5. **Sign-off**: lead-programmer reviews and approves the chosen behavior matches CR-3.

### AC-8 shipping no-op verification
1. In the shipping build, expose a debug menu or use the autoload's `_simulate_registry_failure()` from a bootstrap script.
2. Verify `_registry_valid` retains its boot value (true if registry loaded cleanly).
3. Verify subsequent `transition_to_section` calls succeed (no `push_error`, transition completes).
4. **Sign-off**: lead-programmer or qa-tester confirms.

## Evidence to capture

- [ ] AC-6 shipping screenshot or recording: `production/qa/evidence/screenshots/ls005-ac6-shipping-[date].{png|webm}`
- [ ] AC-8 shipping verification notes: `production/qa/evidence/ls005-ac8-shipping-export-[date].md`
- [ ] Sign-off: `[name] [date]`

## Notes

- The debug-build path (AC-6's 2-second-then-MainMenu) is fully covered by `tests/integration/level_streaming/level_streaming_failure_recovery_test.gd`.
- `scenes/error_fallback.gd` displays the message from `LevelStreamingService._last_error_message` and uses a `Timer` node with 2-second `wait_time` to auto-route to `res://scenes/Main.tscn` via `change_scene_to_file`. (See `scenes/error_fallback.gd` and `scenes/ErrorFallback.tscn` for the exact implementation.)
- ADR-0007 §CR-3 explicitly accepts both shipping-build behaviors (flash OR skip) — the implementation choice is documented in the script + scene definition.
