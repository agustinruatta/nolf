# QA Evidence — EventLogger Release Self-Removal (AC-11-B)

> **Story**: SB-003 — EventLogger debug subscription + non-debug self-removal
> **Acceptance Criterion**: AC-11-B
> **Status**: Pending — first release export
> **Evidence Type**: Manual (release-build behavior cannot be exercised by GdUnit4 in editor mode)

## Acceptance Criterion

> GIVEN the project is launched in non-debug release export, WHEN any `Events`
> signal is emitted, THEN no `EventLogger` log line is printed (because
> `EventLogger` self-removed in `_ready` via `OS.is_debug_build()` returning false).

## Verification Procedure

1. Open Godot Editor → Project → Export.
2. Configure a Linux/X11 export preset (or Windows Desktop) WITHOUT the "Export With Debug" checkbox enabled. Note: the checkbox label may read "Export With Debug" or "Debug Build" depending on Godot version. Both refer to the same flag — leave it UNCHECKED to produce a release build.
3. Click "Export Project..." (NOT "Export PCK/ZIP") and write to a temp directory.
4. Run the exported binary from a terminal to capture stdout, e.g.:
   ```
   ./paris_affair_release.x86_64 2>&1 | tee release_run.log
   ```
5. From the running game, trigger any path that emits an `Events.*` signal (a manual save, a settings change, walking to fire `player_footstep`, etc.). For an automated trigger before any gameplay UI exists, add a temporary `Events.settings_loaded.emit()` call in a test scene, build, and run.
6. Inspect `release_run.log` for the substring `[EventLogger]`.

## Expected Outcome

- ✅ **PASS**: Zero lines in `release_run.log` contain `[EventLogger]`.
- ✅ **PASS**: A debug script that calls `get_node_or_null("/root/EventLogger")` after the first frame returns `null` (EventLogger has self-freed). This is verifiable by adding a `_process` log in any other autoload that runs `print("EventLogger present: ", get_node_or_null("/root/EventLogger") != null)` during the first frame post-boot.
- ❌ **FAIL** (any of): A `[EventLogger]` line appears in stdout; or `/root/EventLogger` is non-null after frame 1.

## Risks / Notes

- `OS.is_debug_build()` returns `true` for editor runs and `--debug` headless invocations. The test ONLY exercises the release-export path.
- If the release export is run with a `--verbose` flag, no extra `[EventLogger]` lines should appear — `EventLogger` is freed before any signal can be emitted to it.
- If a future release-build instrumentation tool ever needs an event-trace, do NOT re-enable `EventLogger` in production — add a separate, opt-in telemetry autoload with its own ADR.

## Sign-off

| Field | Value |
|-------|-------|
| Tester | _Pending_ |
| Date | _Pending — first release export_ |
| Build SHA | _Pending_ |
| Verdict | _Pending_ |
| Notes | _Pending_ |
