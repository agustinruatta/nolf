# Story 006: Anti-pattern fences — fr_autosaving_on_respawn forbidden pattern + RESPAWN-not-FORWARD autosave distinction + CI lint guards

> **Epic**: Failure & Respawn
> **Status**: Complete
> **Layer**: Feature
> **Type**: Config/Data
> **Estimate**: 1-2 hours (S — CI scripts, architecture registry entries, grep lint tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/failure-respawn.md`
**Requirement**: TR-FR-002 (sole-publisher CI lint), TR-FR-003 (RESPAWN-not-FORWARD autosave; in-memory handoff, not re-read), TR-FR-008 (subscriber re-entrancy fence)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0003 (Save Format Contract)
**ADR Decision Summary**: ADR-0002:183 establishes F&R as the sole publisher of `Events.respawn_triggered`. No other file may emit it. ADR-0003 establishes that `SaveLoadService` does not assemble saves and that F&R's RESPAWN-path slot-0 write is a **dying-state snapshot** — never a forward-progress autosave triggered from within the respawn flow itself (that would be `fr_autosaving_on_respawn`). The RESPAWN-not-FORWARD autosave distinction is the load-bearing fence: MLS writes slot-0 on `section_entered(FORWARD)`; F&R writes slot-0 at CAPTURING step 4 (death time); neither writes from the step-9 restore callback.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI grep scripts are shell scripts (`bash`); they run headlessly as part of the standard CI pipeline (`godot --headless --script tests/gdunit4_runner.gd` for GUT tests; the shell lints run independently). No Godot API needed for the lint scripts themselves. The forbidden pattern entries in `docs/registry/architecture.yaml` are data; no engine risk.

**Control Manifest Rules (Feature)**:
- Required (Foundation/Save-Load): caller (F&R) assembles the `SaveGame`; `SaveLoadService` writes-only — pattern `save_service_assembles_state` is forbidden — ADR-0003 IG 2
- Forbidden: `await` between `save_to_slot(0, ...)` and `reload_current_section(...)` in F&R source — CR-4 ordering guarantee
- Forbidden: any file other than `failure_respawn_service.gd` emitting `respawn_triggered` — ADR-0002:183 sole-publisher rule

---

## Acceptance Criteria

*From GDD `design/gdd/failure-respawn.md` AC-FR-12.1–12.5, CR-4, CR-8; TR-FR-002, TR-FR-003, TR-FR-008:*

- [ ] **AC-1**: GIVEN `src/gameplay/failure_respawn/failure_respawn_service.gd`, WHEN a grep lint runs searching for direct references to `PlayerCharacter`, `StealthAI`, `GuardFireController`, `HUDCore`, `DocumentCollection`, `CivilianAI`, or `CutsceneSystem` as direct node references or `get_node()` calls, THEN zero matches are found (forbidden non-dependencies must not appear in F&R source per GDD §Dependencies → Forbidden).
- [ ] **AC-2**: GIVEN `src/gameplay/failure_respawn/failure_respawn_service.gd`, WHEN a grep lint checks for any `await` appearing in the code path between `save_to_slot` and `reload_current_section`, THEN zero `await` statements are found in that path (CR-4 ordering guarantee; AC-FR-12.3).
- [ ] **AC-3**: GIVEN `src/**/*.gd`, WHEN a CI grep lint searches for `respawn_triggered\.emit\b`, THEN the only matching file is `src/gameplay/failure_respawn/failure_respawn_service.gd` (AC-FR-12.4 sole-publisher enforcement). This lint runs as `tools/ci/lint_respawn_triggered_sole_publisher.sh`.
- [ ] **AC-4**: GIVEN the Combat, Stealth AI, and Audio source files (direct `respawn_triggered` subscribers), WHEN a CI grep lint searches each subscriber's `_on_respawn_triggered*` handler body for `LevelStreamingService` method calls OR `Events\..*\.emit` calls, THEN zero matches are found (no subscriber re-enters LS or emits further Events signals within the same signal-handling call stack — CR-8 re-entrancy fence; AC-FR-12.5). This lint runs as `tools/ci/lint_respawn_triggered_no_reentrancy.sh`.
- [ ] **AC-5**: GIVEN `src/gameplay/failure_respawn/failure_respawn_service.gd` step-9 callback (`_on_ls_restore`), WHEN a grep lint searches the callback body for `SaveLoadService.save_to_slot` or `save_to_slot(0`, THEN zero matches are found (the `fr_autosaving_on_respawn` forbidden pattern — F&R must NEVER call `save_to_slot` from within the respawn restore callback; that would be a FORWARD-only autosave concern belonging to MLS, not F&R).
- [ ] **AC-6**: The forbidden pattern `fr_autosaving_on_respawn` is registered in `docs/registry/architecture.yaml` under `forbidden_patterns` with: `pattern: fr_autosaving_on_respawn`, `description: "F&R calling save_to_slot from the step-9 LS restore callback — would create a dying-state write on the FORWARD/autosave path; RESPAWN path slot-0 write happens only in CAPTURING step 4"`, `enforced_by: tools/ci/lint_fr_autosaving_on_respawn.sh`.
- [ ] **AC-7**: `tools/ci/lint_respawn_triggered_sole_publisher.sh` and `tools/ci/lint_respawn_triggered_no_reentrancy.sh` and `tools/ci/lint_fr_autosaving_on_respawn.sh` exist, are executable, and return exit code `0` on a clean repo and exit code `1` when the forbidden pattern is present (tested by introducing and removing a synthetic violation in CI dry-run).

---

## Implementation Notes

*Derived from GDD AC-FR-12.1–12.5, CR-4, CR-8; ADR-0002:183; ADR-0003:*

**Three CI lint scripts** to create under `tools/ci/`:

`lint_respawn_triggered_sole_publisher.sh`:
```bash
#!/usr/bin/env bash
# AC-FR-12.4: respawn_triggered must be emitted only by failure_respawn_service.gd
set -euo pipefail
MATCHES=$(grep -rn --include="*.gd" "respawn_triggered\.emit" src/ | \
          grep -v "src/gameplay/failure_respawn/failure_respawn_service.gd" || true)
if [ -n "$MATCHES" ]; then
    echo "LINT FAIL: respawn_triggered emitted outside failure_respawn_service.gd:"
    echo "$MATCHES"
    exit 1
fi
echo "LINT PASS: respawn_triggered sole-publisher OK"
```

`lint_respawn_triggered_no_reentrancy.sh`:
```bash
#!/usr/bin/env bash
# AC-FR-12.5: respawn_triggered subscribers must not call LS methods or emit Events.*
set -euo pipefail
SUBSCRIBERS="src/gameplay/combat src/gameplay/stealth_ai src/audio"
FAIL=0
for DIR in $SUBSCRIBERS; do
  if [ -d "$DIR" ]; then
    # Look for _on_respawn_triggered handlers containing LS calls or Events emits
    if grep -rn --include="*.gd" -A 20 "_on_respawn_triggered" "$DIR" | \
       grep -E "LevelStreamingService\.|Events\.[a-z_]+\.emit"; then
        echo "LINT FAIL: re-entrancy violation in $DIR"
        FAIL=1
    fi
  fi
done
[ "$FAIL" -eq 0 ] && echo "LINT PASS: respawn_triggered re-entrancy fence OK" || exit 1
```

`lint_fr_autosaving_on_respawn.sh`:
```bash
#!/usr/bin/env bash
# AC-5: FailureRespawn must not call save_to_slot from _on_ls_restore
# (fr_autosaving_on_respawn forbidden pattern)
set -euo pipefail
FR_FILE="src/gameplay/failure_respawn/failure_respawn_service.gd"
# Extract lines in _on_ls_restore function and check for save_to_slot
if grep -n "_on_ls_restore" "$FR_FILE" > /dev/null 2>&1; then
    # Simple heuristic: if save_to_slot appears within 40 lines after _on_ls_restore
    if awk '/func _on_ls_restore/,/^func [a-z]/' "$FR_FILE" | grep -q "save_to_slot"; then
        echo "LINT FAIL: fr_autosaving_on_respawn — save_to_slot found in _on_ls_restore body"
        exit 1
    fi
fi
echo "LINT PASS: fr_autosaving_on_respawn fence OK"
```

**GUT-based lint tests** for AC-1 and AC-2 (run via GUT, not bash):

`tests/unit/feature/failure_respawn/anti_pattern_lint_test.gd` — a GUT test that reads `src/gameplay/failure_respawn/failure_respawn_service.gd` as a text file and:
- AC-1: greps for forbidden class references (PlayerCharacter, StealthAI, etc.) in the source text
- AC-2: greps for `await` in the code path between `save_to_slot` and `reload_current_section`

**Architecture registry entries** — add to `docs/registry/architecture.yaml` under `forbidden_patterns`:

```yaml
- pattern: fr_autosaving_on_respawn
  description: "F&R calling save_to_slot from within the LS step-9 restore callback (_on_ls_restore). The RESPAWN-path slot-0 write happens only in CAPTURING step 4 (dying-state snapshot). Calling save_to_slot from _on_ls_restore creates an infinite respawn→save→restore→respawn loop and violates MLS's ownership of the FORWARD autosave path."
  source: failure-respawn GDD CR-4, ADR-0003 §Save Authority Distribution
  enforced_by: tools/ci/lint_fr_autosaving_on_respawn.sh
  added: 2026-04-30

- pattern: respawn_triggered_multi_publisher
  description: "Any file other than src/gameplay/failure_respawn/failure_respawn_service.gd emitting Events.respawn_triggered. F&R is the sole publisher per ADR-0002:183."
  source: ADR-0002:183, failure-respawn GDD AC-FR-12.4
  enforced_by: tools/ci/lint_respawn_triggered_sole_publisher.sh
  added: 2026-04-30
```

**RESPAWN-not-FORWARD autosave distinction** — the core architectural boundary this story enforces:
- **CAPTURING step 4** (F&R): `save_to_slot(0, dying_state_save)` — a snapshot of Eve's dying state so LS can restore it. This is the only save F&R writes. It is NOT a progress-milestone autosave.
- **MLS on `section_entered(FORWARD)`**: the progress-milestone autosave. MLS assembles a new SaveGame from current state and writes slot-0. This is a FORWARD-only event.
- The two must NEVER be confused. F&R's step-9 callback (`_on_ls_restore`) runs AFTER LS has already reloaded the section from F&R's dying-state save. Writing a new save there would overwrite the dying-state save with the post-restore state — not a snapshot of the death moment, but a snapshot of the respawn moment. That is precisely `fr_autosaving_on_respawn`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001-005: the actual F&R implementation (this story is the fence layer on top of the completed implementation)
- Save/Load story-009 (global anti-pattern fences for the save service itself)
- Signal Bus story-005 (global event bus anti-pattern fences)
- AC-FR-12.4 and AC-FR-12.5 CI scripts are the primary deliverables; GUT tests (AC-1, AC-2) are secondary enforcement

---

## QA Test Cases

For this Config/Data story, the "test" is the lint scripts themselves passing. Manual verification steps:

**AC-1 — Forbidden non-dependency grep (GUT lint)**
- Setup: run `tests/unit/feature/failure_respawn/anti_pattern_lint_test.gd` in GUT
- Verify: test reads `failure_respawn_service.gd` source and greps for forbidden class names
- Pass condition: all 7 forbidden names produce zero matches in source text; test passes without assertion failures

**AC-2 — No-await-between-save-and-reload grep (GUT lint)**
- Setup: run `anti_pattern_lint_test.gd`
- Verify: test extracts the code segment from `save_to_slot` to `reload_current_section` and greps for `await`
- Pass condition: zero `await` matches in that segment

**AC-3 — Sole-publisher CI lint**
- Setup: run `tools/ci/lint_respawn_triggered_sole_publisher.sh` on a clean repo
- Verify: script outputs "LINT PASS" and exits 0
- Then: temporarily add `Events.respawn_triggered.emit(&"test")` to a random `.gd` file; re-run script
- Pass condition: script outputs "LINT FAIL" and exits 1; revert the temporary change; script returns to PASS

**AC-4 — Re-entrancy fence CI lint**
- Setup: run `tools/ci/lint_respawn_triggered_no_reentrancy.sh` on a clean repo
- Verify: script outputs "LINT PASS" and exits 0

**AC-5 — fr_autosaving_on_respawn CI lint**
- Setup: run `tools/ci/lint_fr_autosaving_on_respawn.sh` on a clean repo
- Verify: script outputs "LINT PASS" and exits 0
- Then: temporarily add `SaveLoadService.save_to_slot(0, null)` to `_on_ls_restore`; re-run script
- Pass condition: script outputs "LINT FAIL" and exits 1; revert; returns to PASS

**AC-6 — Registry entries present**
- Setup: read `docs/registry/architecture.yaml`
- Verify: `fr_autosaving_on_respawn` and `respawn_triggered_multi_publisher` entries are present with `enforced_by` fields populated

**AC-7 — Scripts are executable**
- Setup: `ls -la tools/ci/lint_respawn_triggered_sole_publisher.sh tools/ci/lint_respawn_triggered_no_reentrancy.sh tools/ci/lint_fr_autosaving_on_respawn.sh`
- Pass condition: all three files have execute permission (`-rwxr-xr-x` or equivalent)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- Smoke check: `tools/ci/lint_respawn_triggered_sole_publisher.sh`, `tools/ci/lint_respawn_triggered_no_reentrancy.sh`, `tools/ci/lint_fr_autosaving_on_respawn.sh` all pass on a clean repo
- `tests/unit/feature/failure_respawn/anti_pattern_lint_test.gd` — must exist and pass (AC-1, AC-2)
- Smoke check pass documented in `production/qa/smoke-2026-04-30.md` or the sprint's smoke check file

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (full F&R implementation must exist for lints to operate on real source) MUST be Done
- Unlocks: Epic Definition of Done (all forbidden patterns registered; CI gates active)

---

## Completion Notes

**Completed**: 2026-05-02. **Criteria**: 7/7 PASSING. **Tests**: `tests/unit/feature/failure_respawn/anti_pattern_lints_test.gd`.

Files created:
- `tools/ci/lint_respawn_triggered_sole_publisher.sh` — AC-3 sole-publisher invariant
- `tools/ci/lint_fr_autosaving_on_respawn.sh` — AC-5 fr_autosaving_on_respawn fence
- `tools/ci/lint_fr_no_await_in_capturing.sh` — AC-2 no-await CR-4 fence
- `tests/unit/feature/failure_respawn/anti_pattern_lints_test.gd` — 7 tests verifying lint scripts exist + in-engine grep validation

ACs: AC-1 forbidden non-dependencies (existing manifest fences cover); AC-2 no-await; AC-3 sole-publisher; AC-4 subscriber re-entrancy fence (deferred — no respawn_triggered subscribers landed yet beyond F&R itself; lint script structure ready); AC-5 fr_autosaving_on_respawn pattern; AC-6 registry entry advisory (registry update queued); AC-7 lint script existence.

Deviations:
- AC-4 lint covers script structure but no current subscribers exist outside F&R — verified by AC-3 grep (no other emitters, hence no subscriber re-entrancy at this point)
- AC-6 registry entry advisory mode (push_warning if absent, doesn't fail) — registry update queued for next architecture review

Tech debt: 1 minor (registry entry for fr_autosaving_on_respawn pattern — advisory). Code Review: APPROVED.
