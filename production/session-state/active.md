# Session State

**Last updated:** 2026-04-30 — Sprint 02 in progress. **11/24 Must-Have stories done** (SB-001..003, SL-001..004, IN-001..002, PC-001..002). Test suite: **108/108 PASS**. PC chain progressing toward demo loop. Continuing with `/dev-story` loop.

## Next Action — START HERE

PC-002 unlocks PC-003 (movement state machine — uses camera forward for direction). Ready stories:

- **PC-003** (Movement state machine + locomotion) — depends on PC-002 ✅
- **LOC-001** (CSV registration + tr() runtime) — no deps
- **SB-004** (subscriber lifecycle + Node validity guard) — Signal Bus continuation

**Recommended next**: **PC-003** — movement is the heart of the walk-the-Plaza demo.

Run `/dev-story production/epics/player-character/story-003-movement-state-machine.md` to continue.

Sprint plan: `production/sprints/sprint-02-foundation-core.md` (24 Must-Have / 5 Should-Have / 2 Nice-to-Have stories, 3-week cadence).
QA plan: `production/qa/qa-plan-sprint-02-2026-04-30.md`.
Sprint status: `production/sprint-status.yaml` (machine-readable; auto-updated by `/story-done`).

## Current Stage

**Pre-Production** (per `production/stage.txt`). Gate to Production still requires the Vertical Slice build + ≥3 playtests + playtest report. Sprint 02 is the vehicle that closes those.

## What's Ready (the asset base for Sprint 02)

### Epics + Stories — 21 epics, 130 stories total

See `production/epics/index.md` for the full table. Per-layer summary:

- **Foundation (7 epics, 47 stories)**: signal-bus (6) + save-load (9) + localization-scaffold (5) + level-streaming (10) + audio (5) + outline-pipeline (5) + post-process-stack (7).
- **Core (3 epics, 19 stories)**: input (7) + player-character (8) + footstep-component (4).
- **Feature (5 epics, 31 stories)**: stealth-ai (10) + document-collection (5) + mission-level-scripting (5) + failure-respawn (6) + dialogue-subtitles (5).
- **Presentation (5 epics, 27 stories)**: hud-core (6) + hud-state-signaling (3) + document-overlay-ui (5) + menu-system (8) + cutscenes-and-mission-cards (5).
- **Polish (1 epic, 6 stories)**: settings-accessibility (Day-1 HARD MVP slice + VS expansion).

**Deferred post-VS** (do not include in Sprint 02): combat-damage, inventory-gadgets, civilian-ai. Plaza-opening scene doesn't justify these without harming the design fit.

### ADR Status
- ✅ Accepted: ADR-0001, 0002, 0003, 0005 (flipped 2026-05-01 via fps_hands_demo sign-off), 0006, 0007.
- ⏸️ Proposed (with documented deferrals — won't auto-block stories citing them): ADR-0004 (G3/G4/G5 deferred to runtime AT testing post-MVP); ADR-0008 (Restaurant + Iris Xe hardware measurement deferred to first Production sprint shipping outline-bearing scene).

### Test Harness
- GdUnit4 v6.0.0 installed at `addons/gdUnit4/`, plugin enabled in `project.godot`.
- 1-line compatibility patch applied at `addons/gdUnit4/src/core/GdUnitFileAccess.gd:199` (Godot 4.6.2 dropped the `skip_cr` arg from `FileAccess.get_as_text`). Documented in `tests/README.md`.
- Verified: `godot -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit -a tests/integration` runs the Sprint 01 signal_bus_smoke_test, 6/6 PASS, exit 0.
- Stub `tests/gdunit4_runner.gd` removed — official CLI is the canonical entry point.
- `reports/` (GdUnit4 local artefact dir) added to `.gitignore`.

### Visual / Asset Direction
- NOLF 1 alignment brief at `production/notes/nolf1-style-alignment-brief.md` — synthesises existing references, surfaces 5 gaps that `/asset-spec` will need to resolve.
- Visual reference scene at `prototypes/visual_reference/plaza_visual_reference.tscn` (placeholder primitives, NOLF1 palette + outline shader). Scene is **parked** — user defers visual iteration to post-VS / specialist agents (per memory `feedback_artistic_decisions`).

### Architecture Artefacts (unchanged from Sprint 01 close)
- `docs/architecture/architecture.md` — master architecture
- `docs/architecture/control-manifest.md` — Manifest Version 2026-04-30 (Foundation + Core layer rules)
- `docs/architecture/tr-registry.yaml` — TR-ID → ADR coverage map
- `docs/registry/architecture.yaml` — forbidden-pattern registry

## Known Cross-Epic Open Questions (`/sprint-plan` should surface these)

Story breakdown agents flagged these dependencies as needing pre-Sprint-02 resolution OR ordered into Sprint 02 with the dependency-receiver story marked BLOCKED until upstream lands:

1. **HUD Core ↔ HSS handshake**: HSS Story 001 needs HUD Core's `register_resolver_extension` / `unregister_resolver_extension` APIs. Order HUD Core 001-002 before HSS 001.
2. **Settings ↔ HSS Day-1**: HSS Day-1 alert-cue needs `hud_alert_cue_enabled` toggle in Settings. Settings story 001 may need amendment, OR HSS 002 falls back to default-true.
3. **Document Collection ↔ MLS**: DC Story 005 (Plaza tutorial integration) depends on MLS GDD §C.5 amendment (Plaza `&"critical_path"` spline + `Section/Systems/DocumentCollection` node placement) and Localization Scaffold registering `ui.interact.pocket_document` key. Sequence: localization-scaffold story → MLS story 003 (Plaza section authoring) → DC 005.
4. **MLS ↔ F&R**: OQ-MLS-2 — F&R dying-state save must capture `MissionState.triggers_fired`. Coordinate the F&R 002 + MLS 004 implementations.
5. **ADR-0004 Proposed Gates**: Settings Story 005 (panel UI) is BLOCKED on ADR-0004 G1 + G5 (AccessKit Label live-region, BBCode body). Defer Story 005 implementation to post-VS unless the gates close mid-sprint. D&S Story 004 has a related `accessibility_live` open question (VG-DS-2).
6. **ADR-0006 Triggers-layer amendment**: MLS Story 005 currently uses `MASK_PLAYER` placeholder pending the amendment. Either resolve the ADR amendment now or accept the placeholder and revisit.
7. **Outline Pipeline `RenderingServer.get_video_adapter_type()`**: Story 004 (resolution-scale kernel) needs API verification against `docs/engine-reference/godot/modules/rendering.md` before pickup.
8. **Post-Process Stack — 4.6 glow rework + tonemapper constant**: Stories 002 + 005 have OQ items pending the 4.6 glow path verification. Likely first thing to address in Sprint 02.

`/sprint-plan` should treat these as ordering constraints (most are dependency edges, not blockers).

## Session Extract — /story-done 2026-04-30 (SL-003)

- Verdict: COMPLETE
- Story: `production/epics/save-load/story-003-load-from-slot-type-guard-version-mismatch.md` — load_from_slot + type-guard + version-mismatch refusal
- ACs: 8/8 PASS (all auto-verified by 10 tests)
- Tests: `save_load_service_load_test.gd` — 10 functions; suite 60/60 PASS
- Deviations: None
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SL-003 status → done; completed: 2026-04-30
- Sprint 02 progress: 6/24 Must-Have done (25.0%)
- Code review: APPROVED (solo mode; inline review — implementation mirrors ADR-0003 §Key Interfaces pseudocode verbatim).
- Critical proof points: type-guard catches both null AND wrong-class; both directions of version mismatch refused; refuse-load-on-mismatch preserves file on disk; on-disk round-trip preserves all 7 sub-resources + StringName keys + nested GuardRecord; CACHE_MODE_IGNORE structural state-leak defense.
- Save/Load chain progress: SL-001 + SL-002 + SL-003 closed. SL-004 (duplicate_deep) is the final piece for the full save → quit → reload → resume demo loop.
- Next recommended: **SL-004** (duplicate_deep state-isolation discipline — directly unlocked by SL-003; closes the Save/Load chain; ADR-0003 IG 3 caller-side discipline pattern).

## Session Extract — /story-done 2026-04-30 (PC-002)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/player-character/story-002-camera-look-input.md` — First-person camera + look input
- ACs: 4 PASS / 1 DEFERRED (AC-7.4 art-director Visual/Feel sign-off pending; manual evidence template ready)
- Tests: 8 functions across 3 files (player_camera_fov + player_camera_pitch_clamp + player_camera_rotation_split); suite 108/108 PASS
- Files (5): player_character.gd extended, 3 test files, 1 manual evidence template
- Deviations: ADVISORY — Story's Implementation Notes showed `rotation.x -= relative.y * sens` but AC-7.2 spec requires positive relative.y → +85° clamp. Resolved by using `+=` (additive). Sign convention now documented in script header.
- Tech debt logged: None
- sprint-status.yaml: PC-002 status → done; completed: 2026-04-30
- Sprint 02 progress: 11/24 Must-Have done (45.8%)
- Code review: APPROVED (solo mode; suite-pass = full green gate)
- Critical proof points: FOV unchanged across all 4 movement states; pitch clamps at ±85° both directions; yaw rotates body, pitch rotates camera (perfect decoupling); turn overshoot Tween wired (visual feel deferred to art-director).
- Unblocks: PC-003 (movement uses camera forward), PC-005 (interact raycast uses _camera.global_position + camera forward).
- Next recommended: **PC-003** (Movement state machine + locomotion).

## Session Extract — /story-done 2026-04-30 (PC-001)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/player-character/story-001-scene-root-scaffold.md` — PlayerCharacter scene root scaffold
- ACs: 6/6 PASS (all auto-verified by 11 tests)
- Tests: `player_character_scaffold_test.gd` — 11 functions; suite 100/100 PASS (**sprint milestone**)
- Files created: 5 (player_enums.gd, noise_event.gd, player_character.gd, PlayerCharacter.tscn, scaffold test)
- Deviations: ADVISORY — AC-6 `var velocity` redeclaration omitted (Godot 4.x parse error: CharacterBody3D already provides `velocity` as built-in). Documented inline. INFO — initial layer-bit-clear missing; fixed during integration to satisfy AC-4 "clears all other layer bits".
- Tech debt logged: None
- sprint-status.yaml: PC-001 status → done; completed: 2026-04-30
- Sprint 02 progress: 10/24 Must-Have done (41.7%)
- Code review: APPROVED (solo mode; suite-pass = full green gate)
- Critical proof points: Eve on LAYER_PLAYER only (other layer bits FALSE); mask covers WORLD+AI; zero bare integer literals in collision references; PlayerEnums hosted on consumer class per ADR-0002 IG 2; NoiseEvent is RefCounted (not Resource) per GDD §F.4 zero-allocation constraint.
- Unblocks: PC-002 (camera look), PC-003..008, FS-001..004 — entire Player Character + Footstep chains.
- Next recommended: **PC-002** (First-person camera + look input).

## Session Extract — /story-done 2026-04-30 (IN-002)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/input/story-002-input-context-stack-autoload.md` — InputContextStack autoload
- ACs: 5/5 PASS (AC-INPUT-2.1 + 9.2 + Stack invariant + Events emission + Debug action registration)
- Tests: 10 functions across 2 files (input_context_gate + input_context_autoload_load_order); suite 89/89 PASS
- Files changed: 7 (input_context.gd stub→production, events.gd ui_context_changed signal, event_logger.gd handler, 2 test maintenance edits, 2 new tests)
- Cross-epic handshake closed: SB-002's deferred ui_context_changed signal restored with `int` payload (avoids Events↔InputContextStack circular import — same precedent as SL-002's save_failed).
- Deviations: ADVISORY — events.gd + event_logger.gd modifications are out of stated story scope but were the planned cross-epic handshake (SB-002 deferred-UI-domain → IN-002 brings the enum and re-adds signal).
- Tech debt logged: None
- sprint-status.yaml: IN-002 status → done; completed: 2026-04-30
- Sprint 02 progress: 9/24 Must-Have done (37.5%)
- Code review: APPROVED (solo mode; suite-pass = full green gate)
- Critical proof points: Stack invariant (always starts at GAMEPLAY, never empty); class_name/autoload-key split honoured (InputContextStack class, InputContext autoload); ADR-0007 cross-autoload safety respected (_init empty, _ready references InputActions which is a static class not an autoload); EventLogger now subscribes to all 33 Events.* signals.
- Unblocks: **PC-001** + entire Player Character chain (PC-002..005); IN-003 + IN-005.
- Next recommended: **PC-001** (PlayerCharacter scene root scaffold).

## Session Extract — /story-done 2026-04-30 (IN-001)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/input/story-001-input-actions-static-class.md` — InputActions static class + project.godot action catalog
- ACs: 4/4 PASS (AC-INPUT-1.1, 1.3, 9.1, 5.3 partial)
- Tests: 12 functions across 3 files (input_action_catalog + input_actions_constants + input_actions_path); suite 79/79 PASS
- CI: tools/ci/check_debug_action_gating.sh PASS
- Files created/modified: 7 (src/core/input/input_actions.gd, project.godot 33 [input] entries, expected_bindings.yaml fixture, 3 test files, CI shell script)
- Deviations: ADVISORY — initial agent draft used non-existent `assert_failure(msg: String)` GdUnit4 API; fixed via batch replacement to canonical `assert_bool(false).override_failure_message(msg).is_true()` pattern. INFO — JOY_BUTTON_START button_index=6 (not 11) per Godot 4.6 SDL3 mapping; JOY_BUTTON_DPAD_UP=11.
- TR registry note: TR-INP-002 lists "30 actions" but GDD + this story implement 36 (33 gameplay/UI + 3 debug). Recommend `/architecture-review` next pass.
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes added
- sprint-status.yaml: IN-001 status → done; completed: 2026-04-30
- Sprint 02 progress: 8/24 Must-Have done (33.3%)
- Code review: APPROVED (solo mode; suite-pass + CI-script-pass = full green gate; no specialist sub-agents spawned given clean implementation)
- Critical proof points: All 33 gameplay/UI actions in project.godot with KB/M + gamepad bindings per ADR-0004 IG 14; 36 InputActions constants verified (33 + 3 debug); ADR-0004 locked actions present (ui_cancel/interact/pause); debug constants do NOT satisfy InputMap.has_action in non-debug runs (proves runtime-only registration).
- Unblocks: IN-002 + entire Player Character chain (PC-001..005) + all consumer epics referencing InputActions constants.
- Next recommended: **IN-002** (InputContextStack autoload).

## Session Extract — /story-done 2026-04-30 (SL-004)

- Verdict: COMPLETE
- Story: `production/epics/save-load/story-004-duplicate-deep-state-isolation.md` — duplicate_deep state-isolation discipline
- ACs: 7/7 PASS (all auto-verified by 7 tests)
- Tests: `save_load_duplicate_deep_test.gd` — 7 functions; suite 67/67 PASS
- Deviations: None
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SL-004 status → done; completed: 2026-04-30
- Sprint 02 progress: 7/24 Must-Have done (29.2%)
- Code review: APPROVED (solo mode; inline review). Production-schema deep-copy verified including the godot-specialist 2026-04-22 §5 follow-up on Dictionary[StringName, GuardRecord].
- Critical proof points: All 7 sub-resources distinct instances after deep-copy; GuardRecord values in Dictionary deep-copied (not just container); Dict[StringName,int] / Dict[StringName,bool] / Array[StringName] all isolate correctly; StringName key interning preserved (engine contract documented).
- **Save/Load chain CLOSED**: SL-001 + SL-002 + SL-003 + SL-004 complete. End-of-sprint demo's invisible half is structurally feasible.
- Next recommended: **IN-001** (InputActions static class — opens up the longest remaining chain to the visible half of the demo: walk around the Plaza). Other ready stories: LOC-001, SB-004.

## Session Extract — /dev-story 2026-04-30 (SL-004)

- Story: `production/epics/save-load/story-004-duplicate-deep-state-isolation.md`
- Files changed: src/core/save_load/save_load_service.gd (3-line caller-discipline comment), tests/unit/foundation/save_load_duplicate_deep_test.gd (created — 7 functions)
- Test written: tests/unit/foundation/save_load_duplicate_deep_test.gd
- Blockers: None
- Next: /code-review then /story-done

## Session Extract — /dev-story 2026-04-30 (SL-003)

- Story: `production/epics/save-load/story-003-load-from-slot-type-guard-version-mismatch.md` — load_from_slot + type-guard + version-mismatch refusal
- Files changed (2):
  - `src/core/save_load/save_load_service.gd` — added `load_from_slot(slot: int) -> SaveGame` per ADR-0003 IG 1 + IG 4 + §Key Interfaces pseudocode (file-exists check → ResourceLoader.load → null-and-type-guard → version compare → emit). Added `_load_resource()` test seam using `CACHE_MODE_IGNORE` to force fresh disk reads (structural defense against AC-8 state-leak).
  - `tests/unit/foundation/save_load_service_load_test.gd` — created. 10 test functions covering all 8 ACs: AC-1 happy path, AC-2 SLOT_NOT_FOUND, AC-3 (×2 — corrupt bytes + wrong class), AC-4 (×2 — older + future version), AC-5 game_loaded payload + format_version match, AC-6 on-disk round-trip with all 7 sub-resources + StringName key preservation + nested GuardRecord, AC-7 latency 3rd call <5ms, AC-8 no-state-leak via CACHE_MODE_IGNORE.
- Tests written: 10 functions
- Suite result: 60/60 PASS (9 suites: signal_bus_smoke + events_purity + events_autoload_registration + events_signal_taxonomy + event_logger_debug + atomic_write_power_loss + save_game_round_trip + save_load_service_save + new save_load_service_load); 0 errors, 0 failures, 0 orphans, exit 0
- AC-7 latency: well under 5ms threshold locally
- Critical proof points: type-guard catches both null AND wrong-class (PlayerState saved as slot file); both directions of version mismatch refused; refuse-load-on-mismatch leaves the file on disk (NOT deleted); on-disk round-trip preserves all 7 sub-resources + StringName Dict keys + nested GuardRecord; CACHE_MODE_IGNORE provides structural state-leak defense.
- Story manifest version unchanged (2026-04-30 = current)
- Blockers: None
- Next: `/code-review` then `/story-done`

## Session Extract — /story-done 2026-04-30 (SL-002)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/save-load/story-002-save-load-service-atomic-write.md` — SaveLoadService autoload + save_to_slot atomic write
- ACs: 10/10 PASS (all auto-verified by 11 tests: 9 unit + 2 integration)
- Tests: `save_load_service_save_test.gd` (10 functions) + `atomic_write_power_loss_test.gd` (2 functions); suite 50/50 PASS
- Deviations logged: ADVISORY — events.gd + event_logger.gd modifications (planned cross-epic handshake to re-add save_failed signal deferred by SB-002); ADVISORY — AC-7 perf test asserts 50ms regression boundary (CI-tolerant) with 10ms production target documented inline.
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SL-002 status → done; completed: 2026-04-30
- Sprint 02 progress: 5/24 Must-Have done (20.8%)
- Code review: APPROVED (solo mode; in-line via /code-review with godot-gdscript-specialist + qa-tester). Review fixes: MEDIUM — added test_save_to_slot_io_error_leaves_previous_good_save_byte_identical (AC-4 safety guarantee for previous good file untouched on IO_ERROR); CLEANUP — switched to static DirAccess.rename_absolute / remove_absolute; CLEANUP — latency 15ms → 50ms CI-tolerant threshold.
- Critical proof points: AC-4 dual coverage (no-previous-file + previous-good-byte-identical); AC-5 RENAME_FAILED + cleanup + previous good intact; AC-8 power-loss orphan tmp does not destroy previous good save AND subsequent save cleanly overwrites the orphan.
- Cross-epic handshake closed: SB-002's deferred save_failed signal is now restored with `int` payload (avoids Events↔SaveLoadService circular import); EventLogger now subscribes to all 32 Events.* signals.
- Next recommended: **SL-003** (load_from_slot + type-guard + version-mismatch refusal — directly unlocked by SL-002; completes the read-side companion to the write path; ADR-0003 IG 4 type-guard discipline).

## Session Extract — /dev-story 2026-04-30 (SL-002)

- Story: `production/epics/save-load/story-002-save-load-service-atomic-write.md` — SaveLoadService autoload + save_to_slot atomic write
- Files changed (5):
  - `src/core/save_load/save_load_service.gd` — Sprint 01 stub → production class (`class_name SaveLoadService extends Node`, `FailureReason` enum, `save_to_slot()` with full ADR-0003 IG 5 atomic-write protocol; test seams `_save_resource()` + `_rename_file()` + `_remove_if_exists()` for fault injection per AC-4/AC-5)
  - `src/core/signal_bus/events.gd` — added `signal save_failed(reason: int)` to Persistence domain (was deferred in SB-002 pending SaveLoad.FailureReason; SL-002 brings the enum, signal re-added with `int` payload to avoid Events↔SaveLoadService circular import)
  - `src/core/signal_bus/event_logger.gd` — added `_on_save_failed` handler + `_register(Events.save_failed, _on_save_failed)` in `_connect_all` (subscriptions: 31 → 32)
  - `tests/unit/foundation/save_load_service_save_test.gd` — created (9 tests covering AC-1, AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10; uses `_IOFailingService` + `_RenameFailingService` test subclasses for fault injection)
  - `tests/integration/foundation/atomic_write_power_loss_test.gd` — created (2 tests covering AC-2 autoload registration + AC-8 power-loss orphan tmp simulation)
  - `tests/unit/foundation/events_signal_taxonomy_test.gd` — updated to assert `save_failed` is now PRESENT with `[TYPE_INT]` signature (no longer deferred)
  - `tests/integration/foundation/event_logger_debug_test.gd` — `EXPECTED_CONNECTION_COUNT` 31 → 32 (matches new save_failed subscription)
- Tests written: 11 functions (9 unit + 2 integration)
- Suite result: 49/49 PASS (8 suites); 0 errors, 0 failures, 0 orphans, exit 0
- AC-7 latency: well under 15ms threshold (cold + warm runs both ~1-3ms locally)
- Deviations: minor — `events.gd` and `event_logger.gd` modifications are technically out of SL-002's stated scope (story listed only the service + test files), BUT both modifications are functionally REQUIRED for SL-002's `save_failed` emits to work and were anticipated by SB-002's completion notes ("save_failed deferred to Save/Load epic re-add with proper SaveLoad.FailureReason enum"). This is the planned cross-epic handshake, executed correctly.
- Story manifest version unchanged (2026-04-30 = current)
- Blockers: None
- Next: `/code-review` on the new files, then `/story-done`

## Session Extract — /story-done 2026-04-30 (SL-001)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/save-load/story-001-save-game-resource-scaffold.md` — SaveGame Resource + 7 typed sub-resource scaffolding
- ACs: 7/7 PASS — all auto-verified by 9 unit tests; AC-7 round-trip strengthened during code review
- Tests: 9 functions in `save_game_round_trip_test.gd`; suite 38/38 PASS (6 suites total)
- Deviations logged: ADVISORY — TR-SAV-002 registry text lists 6 sub-resources; ADR-0003 + story require 7 (failure_respawn). Implementation followed ADR. Recommend `/architecture-review` next pass to refresh registry.
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SL-001 status → done; completed: 2026-04-30
- Sprint 02 progress: 4/24 Must-Have done (16.7%)
- Code review: APPROVED (solo mode; in-line via /code-review with godot-gdscript-specialist + qa-tester). Six fixes applied during review: BLOCKING — StringName key-type assertion in AC-7 round-trip; WARNINGs — CACHE_MODE_IGNORE on ResourceLoader.load, missing field assertions (rotation/last_known_target_position/collected_gadget_flags/triggers_fired/mission.section_id), assert_str StringName coercion, FORMAT_VERSION reference vs literal, PlayerState doc comments.
- Critical proof point: AC-7 round-trip succeeded — proves all 7 typed @export sub-resources serialize correctly through ResourceSaver.save(... FLAG_COMPRESS); no IG 11 violations (F2 trap) slipped through; StringName Dictionary keys preserved; GuardRecord-as-Dictionary-value round-trips cleanly.
- Next recommended: **SL-002** (SaveLoadService autoload + save_to_slot atomic write — directly unlocked by SL-001; ADR-0003 IG 5 atomic-write protocol with Sprint 01 finding F1 enforcement). Also unblocked: LOC-001, IN-001, SB-004.

## Session Extract — /dev-story 2026-04-30 (SL-001)

- Story: `production/epics/save-load/story-001-save-game-resource-scaffold.md` — SaveGame Resource + 7 typed sub-resource scaffolding
- Files created (10):
  - `src/core/save_load/save_game.gd` — `class_name SaveGame extends Resource`, `FORMAT_VERSION: int = 2`, 7 typed sub-resource `@export` fields, `_init()` default-initializes children
  - `src/core/save_load/states/player_state.gd` — `class_name PlayerState`
  - `src/core/save_load/states/inventory_state.gd` — `class_name InventoryState` (untyped Dictionary for ammo_magazine/reserve per Inventory CR-11)
  - `src/core/save_load/states/stealth_ai_state.gd` — `class_name StealthAIState` (guards: Dictionary keyed by actor_id)
  - `src/core/save_load/states/civilian_ai_state.gd` — `class_name CivilianAIState` (panicked stub)
  - `src/core/save_load/states/document_collection_state.gd` — `class_name DocumentCollectionState`
  - `src/core/save_load/states/mission_state.gd` — `class_name MissionState` (fired_beats per MLS CR-7)
  - `src/core/save_load/states/failure_respawn_state.gd` — `class_name FailureRespawnState` (placeholder; F&R epic refines)
  - `src/core/save_load/states/guard_record.gd` — `class_name GuardRecord` (top-level per IG 11 — inner-class @export trap avoided)
  - `tests/unit/foundation/save_game_round_trip_test.gd` — 9 test functions including the critical `test_save_game_round_trip_preserves_all_fields` (AC-7) round-trip via `ResourceSaver.save(... FLAG_COMPRESS)` + `ResourceLoader.load`
- Tests written: 9 functions covering AC-1 through AC-7
- Suite result: 38/38 PASS (6 suites: signal_bus_smoke + events_purity + events_autoload_registration + events_signal_taxonomy + event_logger_debug + new save_game_round_trip); 0 errors, 0 failures, 0 orphans, exit 0
- AC-7 outcome: full round-trip passed — proves all 7 typed `@export` sub-resources serialize correctly through `ResourceSaver` (no IG 11 violations slipped through), StringName keys preserved in Dictionary, GuardRecord preserved as Dictionary value
- Deviation: minor — test file initially used `assert_vector3()` (not a GdUnit4 API); replaced with `assert_that()` universal assertion. Pattern noted: GdUnit4 6.0.0 has `assert_int/str/bool/float/object/that` — no per-type Vector helper.
- Story manifest version unchanged (2026-04-30 = current)
- Blockers: None
- TR registry note: TR-SAV-002 text lists 6 sub-resources (player, inventory, stealth_ai, civilian_ai, documents, mission); story + ADR-0003 spec actually requires 7 (adds failure_respawn). Minor TR registry staleness — should be updated by `/architecture-review` next pass. Implementation followed the ADR (7 sub-resources).
- Next: `/code-review` on the 10 files, then `/story-done`

## Session Extract — /story-done 2026-04-30 (SB-003)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/signal-bus/story-003-event-logger-debug-autoload.md` — EventLogger autoload: debug subscription + non-debug self-removal
- ACs: 1 PASS / 1 DEFERRED — AC-11-A auto-verified by 6 integration tests; AC-11-B requires release export, manual evidence procedure documented
- Tests: 6 functions in `event_logger_debug_test.gd`; suite 29/29 PASS (5 suites total)
- Deviations logged: ADVISORY — `class_name SignalBusEventLogger` autoload-key/class-name split (mirrors ADR-0002 OQ-CD-1 precedent); ADVISORY — handler type-mismatch coverage in `_connect_all()` deferred to SB-006
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SB-003 status → done; completed: 2026-04-30
- Sprint 02 progress: 3/24 Must-Have done (12.5%)
- Code review: APPROVED (solo mode; in-line via /code-review with godot-gdscript-specialist + qa-tester); two minor fixes applied (Array[Variant] typing + Dictionary cast comment)
- Closes SB-001's documented event_logger.gd._ready() stub deviation
- Next recommended: **SL-001** (SaveGame Resource scaffolding — highest leverage, unblocks LS-001 → PC chain → demo). Also unblocked: **LOC-001**, **IN-001**, **SB-004**.

## Session Extract — /dev-story 2026-04-30 (SB-003)

- Story: `production/epics/signal-bus/story-003-event-logger-debug-autoload.md` — EventLogger autoload: debug subscription + non-debug self-removal
- Files changed: `src/core/signal_bus/event_logger.gd` (stub → full impl with `class_name SignalBusEventLogger` mirroring `Events`/`SignalBusEvents` autoload-key/class-name split per ADR-0002 OQ-CD-1; 31 per-signal handlers across 9 domains; `_format_log_line()` pure utility for testability; `_register()` bookkeeping; `_exit_tree()` with `is_connected` guards; `OS.is_debug_build()` early-out for AC-11-B); `tests/integration/foundation/event_logger_debug_test.gd` (created — 6 test functions; uses `auto_free()` for clean orphan-node management)
- Files created: `production/qa/evidence/event_logger_release_self_removal.md` (manual evidence template for AC-11-B; pending first release export)
- Tests written: 6 integration test functions covering AC-11-A (subscriber count, log-line format — signal name / timestamp prefix / `[EventLogger]` prefix / no-payload handling / exit_tree disconnect)
- Suite result: 29/29 PASS (5 suites: signal_bus_smoke + events_purity + events_autoload_registration + events_signal_taxonomy + new event_logger_debug); 0 errors, 0 failures, 0 orphans, exit 0
- Deviation: minor — agent used `class_name SignalBusEventLogger` (not `EventLogger`) to mirror the existing Events/SignalBusEvents pattern from ADR-0002 OQ-CD-1 amendment. Avoids the parser conflict between class_name and the `EventLogger` autoload key. Consistent with established codebase convention. Risk: low.
- Closes SB-001's documented `event_logger.gd._ready()` stub deviation.
- Story manifest version rolled forward 2026-04-29 → 2026-04-30 (Foundation rules unchanged)
- Blockers: None
- Test runner note: required `godot --headless --editor --quit-after 2` once to refresh global class cache for the new `class_name`. Future test runs will succeed without this.
- Next: `/code-review` on the 3 changed/created files, then `/story-done`

## Session Extract — /story-done 2026-04-30 (SB-002)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/signal-bus/story-002-builtin-type-signals.md` — Built-in-type signal declarations on events.gd
- ACs: 10/10 passing (AC-3-A through AC-3-J + deferred-absence integrity check)
- Tests: 11 functions in `events_signal_taxonomy_test.gd`; class_name discrimination added post-review for 6 TYPE_OBJECT signals
- Suite: 23/23 PASS (4 test files: signal_bus_smoke + events_purity + events_autoload_registration + events_signal_taxonomy)
- Deviations logged: Cutscenes domain banner (ADR-driven, not Mission); save_failed deferred to Save/Load epic
- Tech debt logged: None
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SB-002 status → done
- Sprint 02 progress: 2/24 Must-Have done (8.3%)
- Next recommended: **SB-003** (EventLogger debug autoload — restores the `_ready()` body SB-001 stubbed; full subscriber to all `Events.*` signals + non-debug self-removal). Also unblocked: **LOC-001** (independent), **IN-001** (independent).

## Session Extract — /dev-story 2026-04-30 (SB-002)

- Story: `production/epics/signal-bus/story-002-builtin-type-signals.md` — Built-in-type signal declarations on events.gd
- Files changed: `src/core/signal_bus/events.gd` (8 skeleton → 31 production signals across 9 domains; `save_failed(reason: int)` removed pending Save/Load epic re-add with proper `SaveLoad.FailureReason` enum); `tests/unit/foundation/events_signal_taxonomy_test.gd` (created — 11 test functions)
- Tests written: 11 test functions covering AC-3-A through AC-3-J + deferred-absence guard
- Suite result: 23/23 PASS (6 smoke + 6 SB-001 + 11 new); 0 errors, 0 failures, exit 0
- Deviation: minor — `cutscene_started`/`cutscene_ended` placed under a dedicated `# ─── Cutscenes domain ───` banner per ADR-0002 amendment 2026-04-29, not bundled under Mission as the story listed. ADR wins per story rule.
- Story manifest version rolled forward 2026-04-29 → 2026-04-30 (Foundation rules unchanged)
- Blockers: None
- Next: `/code-review` then `/story-done`

## Session Extract — /story-done 2026-04-30 (SB-001)

- Verdict: COMPLETE WITH NOTES
- Story: `production/epics/signal-bus/story-001-events-autoload-structural.md` — Events autoload structural purity + registration finalization
- ACs: 3/3 passing — all verified by automated tests (12/12 PASS in suite)
- Deviation logged: `event_logger.gd` `_ready()` stubbed (in-scope-but-out-of-declared-files); SB-003 restores full impl. Risk: low.
- Tech debt logged: None (deviation is tracked in SB-003 prereqs, not tech-debt-register)
- Story file: Status: Ready → Status: Complete (2026-04-30); Completion Notes section added
- sprint-status.yaml: SB-001 status → done; completed: 2026-04-30
- Next recommended: **SB-002** (Built-in-type signal declarations on events.gd) — depends on SB-001 only, now satisfied; unblocks SL-001 + LS-002 + FS-004 + downstream save-load chain

## Session Extract — /dev-story 2026-04-30 (SB-001)

- Story: `production/epics/signal-bus/story-001-events-autoload-structural.md` — Events autoload structural purity + registration finalization
- Files changed: `src/core/signal_bus/events.gd` (smoke_test_pulse removed, _ready removed), `src/core/signal_bus/event_logger.gd` (in-scope deviation — stubbed _ready to prevent crash; SB-003 owns full restoration), `tests/unit/foundation/events_purity_test.gd` (created, 151 lines, 4 functions), `tests/unit/foundation/events_autoload_registration_test.gd` (created, 69 lines, 2 functions)
- Tests written: 6 new test functions covering AC-1, AC-2, AC-3 — all pass
- Suite result: 12/12 PASS (6 pre-existing + 6 new); 0 errors, 0 failures
- Deviation flagged: `event_logger.gd` _ready was stubbed because removing `smoke_test_pulse` from `events.gd` made the existing `Events.smoke_test_pulse.connect()` line crash at autoload boot. Stub annotated `# SB-003 will land full impl`. Out-of-scope-but-necessary; SB-003 must restore the full `_ready()` body. Risk: low.
- Story manifest version rolled forward 2026-04-29 → 2026-04-30 (Foundation rules unchanged; additive Feature/Presentation/Polish updates).
- Blockers: None
- Next: `/code-review` on the 4 changed/created files, then `/story-done`

## Recently Completed (this session, 2026-04-30)

- 17 epics created across Feature, Presentation, Foundation top-up, and Polish layers (`/create-epics`)
- 99 stories authored across those 17 epics (`/create-stories`) — 5 incomplete batches finished via continuation agents
- `production/project-stage-report.md` written (Pre-Production → Production gap analysis)
- `production/notes/nolf1-style-alignment-brief.md` written (NOLF 1 reference synthesis + 5 asset-spec gaps)
- `prototypes/visual_reference/plaza_visual_reference.tscn` built (NOLF 1 palette + outline shader, parked for post-VS iteration)
- GdUnit4 install verified, 1-line patch applied, stub runner deleted, `reports/` gitignored
- Memory: `feedback_artistic_decisions` saved (user defers art-direction to specialists)

## Files Modified This Session (2026-04-30)

- `production/project-stage-report.md` (created)
- `production/notes/nolf1-style-alignment-brief.md` (created)
- `production/epics/index.md` (Feature, Presentation, Polish, Foundation top-up entries added; story counts populated)
- `production/epics/{audio,outline-pipeline,post-process-stack,input,player-character,footstep-component,stealth-ai,document-collection,mission-level-scripting,failure-respawn,dialogue-subtitles,hud-core,hud-state-signaling,document-overlay-ui,menu-system,cutscenes-and-mission-cards,settings-accessibility}/EPIC.md` (created with VS scope guidance) — 17 new epic files
- `production/epics/[same 17]/story-NNN-*.md` — 99 new story files
- `addons/gdUnit4/src/core/GdUnitFileAccess.gd` (1-line 4.6.2 compat patch at line 199)
- `tests/README.md` (CLI form updated, patch documented, stub-removed note)
- `tests/gdunit4_runner.gd` + `.uid` (deleted)
- `.gitignore` (added `reports/`)
- `prototypes/visual_reference/{README.md, plaza_visual_reference.gd, plaza_visual_reference.tscn}` (created)
- `production/session-state/active.md` (this file)

## How to Resume

1. New session reads this file (auto-loaded by `session-start.sh` hook)
2. Run `/dev-story production/epics/signal-bus/story-003-event-logger-debug-autoload.md` — the next story in the dependency chain. SB-001 + SB-002 are Complete; SB-003 closes the EventLogger stub deviation.
3. After SB-003 lands: `/code-review` → `/story-done` → either continue Signal Bus (SB-004 lifecycle / SB-005 anti-pattern fences / SB-006 edge-case dispatch) or pivot to LOC-001 / IN-001 / SL-001 (all unblocked).
4. Maintain one story-loop per session and `/clear` between, per cadence agreed 2026-04-30.
