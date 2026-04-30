# Epic: Save / Load

> **Layer**: Foundation
> **GDD**: `design/gdd/save-load.md`
> **Architecture Module**: Save / Load (SaveLoadService autoload — `architecture.md` §3.1)
> **Engine Risk**: MEDIUM (`Resource.duplicate_deep()` 4.5; atomic rename API; binary `.res` class-name lookup)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories save-load`
> **Manifest Version**: 2026-04-29

## Overview

Save / Load is the persistence backbone of *The Paris Affair* — a single
`SaveLoadService` autoload that writes and reads sectional checkpoint saves in
binary `.res` format with atomic write semantics. It is **subscriber-agnostic**:
callers (Mission & Level Scripting, Failure & Respawn, the player's explicit
save action) assemble a complete `SaveGame` Resource from each owning system's
current state, then hand it to Save/Load for persistence. Eight save slots
exist (slot_0 = autosave, 1–7 manual, NOLF1-style). Failure modes emit via the
Signal Bus (`Events.save_failed`); settings persist in a separate
`user://settings.cfg` file.

ADR-0003 locks the format contract; this epic implements the `SaveLoadService`
autoload, the `SaveGame` Resource + 7 typed sub-resources (`PlayerState`,
`InventoryState`, `StealthAIState`, `CivilianAIState`, `DocumentCollectionState`,
`MissionState`, `FailureRespawnState`), the metadata sidecar (`slot_N_meta.cfg`),
and the atomic-write protocol (write to `slot_N.tmp.res`, verify OK,
`DirAccess.rename(tmp, final)`).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0003: Save Format Contract | Binary `.res` Resource saves with `ResourceSaver.FLAG_COMPRESS`; `SaveLoadService` writes/reads only (callers assemble `SaveGame`); per-actor identity uses stable `actor_id: StringName` not NodePaths; refuse-load-on-mismatch versioning; atomic write via `slot_N.tmp.res` → `DirAccess.rename`; settings stored separately in `user://settings.cfg` | MEDIUM |
| ADR-0007: Autoload Load Order Registry | `SaveLoad` at autoload line 3 (after `EventLogger`, before `InputContext`); cross-autoload reference safety; `*res://` scene-mode prefix | LOW |

## GDD Requirements

The `save-load.md` GDD specifies the design-level behavior and cross-system
integration patterns for the Save / Load service. Implementation requirements
trace to ADR-0003 §Implementation Guidelines (11 rules including the
2026-04-29 Amendment A5 additions for tmp-file extension and inner-class
@export rule):

- Atomic write protocol (`slot_N.tmp.res` → verify OK → `DirAccess.rename` → metadata sidecar)
- 8 slot scheme (slot_0 = autosave at section transitions; 1–7 = manual)
- `SaveGame.FORMAT_VERSION = 2` const + `save_format_version` @export var sentinel
- 7 typed sub-resources (each top-level `class_name`'d in its own file under `src/core/save_load/states/`)
- `SaveLoad.FailureReason` enum (NONE, IO_ERROR, VERSION_MISMATCH, CORRUPT_FILE, SLOT_NOT_FOUND, RENAME_FAILED)
- Mandatory `duplicate_deep()` discipline on load (state isolation)
- Type-guard after every load (`is null` OR `not is SaveGame` → emit `save_failed(CORRUPT_FILE)`)
- Anti-pattern fences: `save_service_assembles_state`, `save_state_uses_node_references`, `forgotten_duplicate_deep_on_load`

Specific requirement traces are in `docs/architecture/tr-registry.yaml` under
Save/Load ownership; story creation will pull current TR-IDs from there.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/save-load.md` are verified.
- `SaveLoadService` autoload registered at line 3 of `project.godot [autoload]` per ADR-0007.
- 7 typed sub-resource files exist under `src/core/save_load/states/`, each with `class_name` registered (per ADR-0003 IG 11 — the inner-class @export trap is avoided).
- `SaveGame` round-trip integration test passes: assemble → save_to_slot → load_from_slot → `duplicate_deep` → field-equality assertion across all 7 sub-resources, including the `Dictionary[StringName, GuardRecord]` and `Dictionary[StringName, bool]` typed-dict shapes.
- Power-loss simulation test passes: kill process mid-write; previous good save remains intact; no half-written tmp files leak between runs.
- Metadata sidecar (`slot_N_meta.cfg`) reads correctly without loading the full `.res` (Menu System will consume this).
- All 3 anti-pattern fences (`save_service_assembles_state`, `save_state_uses_node_references`, `forgotten_duplicate_deep_on_load`) registered in the architecture registry.
- Logic stories have passing unit tests in `tests/unit/foundation/`; integration stories have integration tests in `tests/integration/foundation/`.

## Verification Spike Status (Sprint 01, 2026-04-29)

ADR-0003 is **Accepted** (3/3 verification gates passed via
`prototypes/verification-spike/save_format_check.gd` headless run on Godot
4.6.2 stable). Findings F1 (atomic-write tmp-extension) and F2 (inner-class
@export trap) are folded into ADR-0003 Amendment A5. Production code can rely
on the verified APIs without re-verifying.

## Next Step

Run `/create-stories save-load` to break this epic into implementable stories.
