# ADR-0003: Save Format Contract

## Status

**Proposed** — moves to Accepted once two verification gates pass: (1) `ResourceSaver.save(save, path, ResourceSaver.FLAG_COMPRESS)` on a binary `.res` returns `OK` in Godot 4.6 editor; (2) `DirAccess.rename(tmp, final)` is the correct atomic-rename API in 4.6.

## Date

2026-04-19

## Last Verified

2026-04-19

## Decision Makers

User (project owner) · godot-gdscript-specialist (technical validation) · `/architecture-decision` skill

## Summary

The game persists state via binary `Resource` saves (`.res`) using `ResourceSaver`/`ResourceLoader`, scoped to the current section only (NOLF1-style sectional checkpoints). A top-level `SaveGame extends Resource` holds typed per-system state Resources (player, inventory, stealth AI, civilian AI, documents, mission). `SaveLoadService` is an autoload that owns the persistence domain — it writes/reads files only, holds no scene-system references, and accepts pre-assembled `SaveGame` objects from callers. Versioning is refuse-load-on-mismatch. Per-actor state uses stable `actor_id: StringName` set on scene authoring, not NodePaths.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Persistence (Resource serialization, FileAccess, DirAccess) |
| **Knowledge Risk** | MEDIUM-HIGH — `Resource`/`ResourceSaver` are stable since 4.0 (training-data); 4.4 changed `FileAccess.store_*` return types (bool); 4.5 added `duplicate_deep()` for nested Resource trees. Both 4.4/4.5 changes are post-cutoff and load-bearing for this contract. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (Core/4.4 FileAccess changes), `current-best-practices.md` (4.5 `duplicate_deep()`), `deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` (4.5) for state isolation on load. Note: this contract uses `ResourceSaver`/`ResourceLoader` exclusively, not `FileAccess.store_*` directly, so the 4.4 `bool`-return change is informational only — `ResourceSaver.save()` returns `Error` (e.g., `OK`), which is what we check. |
| **Verification Required** | (1) Confirm `ResourceSaver.save(save_game, "user://test.res", ResourceSaver.FLAG_COMPRESS)` returns `OK` in Godot 4.6 editor. (2) Confirm `DirAccess.rename(tmp_path, final_path)` is the correct atomic-rename API in 4.6 — the breaking-changes doc does not flag this as changed, but worth a quick editor confirmation. (3) Confirm `Resource.duplicate_deep()` is callable on a `SaveGame` instance with nested typed-Resource fields and produces a fully isolated copy. |

> **Note**: MEDIUM-HIGH Knowledge Risk. Resource serialization patterns are stable; the load-bearing post-cutoff API is `duplicate_deep()`. If the project ever backtracks below Godot 4.5, this contract must be revised.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0002** (Signal Bus + Event Taxonomy) — soft dependency. Save/Load publishes `Events.game_saved(slot, section_id)`, `Events.game_loaded(slot)`, `Events.save_failed(reason: SaveLoad.FailureReason)` signals defined there. The `SaveLoad.FailureReason` enum is owned by this ADR's `SaveLoadService`. |
| **Enables** | All system GDDs that contribute serializable state — Player Character, Inventory & Gadgets, Stealth AI, Civilian AI, Document Collection, Mission & Level Scripting, Failure & Respawn. |
| **Blocks** | Inventory & Gadgets (system 12), Stealth AI (system 10), Document Collection (system 17), Mission & Level Scripting (system 13), Failure & Respawn (system 14), Save/Load (system 6) — six system GDDs cannot specify their serialization shape until this ADR reaches Accepted. |
| **Ordering Note** | Sibling to ADR-0001 and ADR-0002. ADR-0003 may be authored in any order relative to ADR-0004 (UI Framework). |

## Context

### Problem Statement

Without a project-wide save format contract, every system that contributes to save state will invent its own scheme. Per the TD review of `systems-index.md`: "Serializing inventory + AI patrol state + document bitmap + mission state is where first-time Godot projects lose two weeks." Specifically, four problems compound:

1. **Schema fragmentation** — each system serializes differently; cross-system references break; load logic becomes a multi-format bus.
2. **No versioning policy** — first patch that changes any system's data shape silently breaks every existing save.
3. **NodePath / Node reference traps** — naive serialization of guard/civilian state via `NodePath` fails because the scene tree doesn't exist at file-load time.
4. **No atomicity** — power loss mid-write produces corrupt saves indistinguishable from valid ones.

This contract must exist before Inventory, Stealth AI, Document Collection, and Mission Scripting GDDs are authored — otherwise each will need a retroactive "what do we serialize" section.

### Current State

Project is in pre-production. No source code exists. No prior save system to migrate from.

### Constraints

- **Engine: Godot 4.6, GDScript primary.** `Resource` + `ResourceSaver`/`ResourceLoader` is the canonical persistence stack since 4.0.
- **Scope: sectional checkpoint only** — locked design decision. A save = current section's state. Concept doc Section "Flow State Design" specifies NOLF-style sectional respawn.
- **Format: binary `.res`** — locked design decision. `ResourceSaver.FLAG_COMPRESS`. ~2-3× smaller than text `.tres`; opaque to debug, but type-safe via `class_name`.
- **Versioning: refuse-load-on-mismatch + force-new-save** — locked design decision. Acceptable for single-shot indie ship; documented trade-off if Tier 2 (Rome/Vatican) ever ships and changes the format.
- **Performance: <10 ms save latency** at the ~1–10 KB sectional save size. Synchronous writes acceptable; no threading.
- **Cross-system contract**: Save/Load publishes status via `Events` bus (ADR-0002), not direct callbacks.
- **First-time solo Godot dev** — pattern must be debuggable, well-documented, and resistant to common pitfalls (silent null returns, NodePath traps, missing `duplicate_deep`).

### Requirements

- One canonical `SaveGame extends Resource` holds the full sectional save.
- Per-system state is a typed `Resource` subclass referenced by `SaveGame` via `@export`.
- `SaveLoadService` autoload owns the persistence domain: it writes/reads files only.
- Atomic write pattern: write to temp file, rename. No half-written saves on crash.
- Per-actor (guard/civilian) state uses stable string IDs, not NodePaths.
- Failures emit `Events.save_failed(reason)` per ADR-0002; do not auto-recover destructively.
- Save slot metadata (for menu display) is stored in a separate `ConfigFile` sidecar so the menu does not have to load the full binary Resource just to show a save card.

## Decision

**Use `Resource`-based binary saves (`.res`) with `ResourceSaver.FLAG_COMPRESS`. Save scope is the current section. `SaveLoadService` autoload writes/reads only; callers assemble the `SaveGame`. Per-actor state uses stable `actor_id: StringName` set on scene authoring. Versioning refuses-load-on-mismatch.**

### Architecture

```
                       ┌─────────────────────────────────────────┐
                       │  CALLERS (assemble SaveGame from live   │
                       │  systems and pass it in)                │
                       │  Mission Scripting (section transition) │
                       │  Failure & Respawn (death checkpoint)   │
                       │  Player save action (manual)            │
                       └─────────────────┬───────────────────────┘
                                         │ SaveLoad.save_to_slot(N, save_game)
                                         ▼
        ┌─────────────────────────────────────────────────────────────┐
        │  SaveLoadService autoload (load order 3, after Events)      │
        │  ────────────────────────────────────────────────────────── │
        │  Owns persistence domain. Writes/reads files only.          │
        │  Holds NO scene-system references. NEVER assembles SaveGame.│
        │                                                             │
        │  Atomic write pattern:                                      │
        │    1. ResourceSaver.save(sg, "user://saves/slot_N.res.tmp", │
        │                           ResourceSaver.FLAG_COMPRESS)      │
        │    2. Check return == OK; else emit save_failed(IO_ERROR)   │
        │    3. DirAccess.rename(tmp, final)                          │
        │    4. Write slot_N_meta.cfg sidecar (ConfigFile)            │
        │    5. Write slot_N_thumb.png (optional screenshot)          │
        │    6. Events.game_saved.emit(slot, section_id)              │
        └─────────────────┬───────────────────────────────────────────┘
                          │ persists to
                          ▼
            user://saves/
              ├── slot_0.res        (autosave — full SaveGame Resource)
              ├── slot_0_meta.cfg   (light metadata for menu display)
              ├── slot_0_thumb.png  (low-res screenshot)
              ├── slot_1.res / _meta.cfg / _thumb.png  (manual slot 1)
              ├── slot_2.res / ...  (manual slot 2)
              ├── slot_3.res / ...  (manual slot 3)
              ├── slot_4.res / ...  (manual slot 4)
              ├── slot_5.res / ...  (manual slot 5)
              ├── slot_6.res / ...  (manual slot 6)
              └── slot_7.res / ...  (manual slot 7)

            user://settings.cfg     (separate — owned by Settings system)
```

### Key Interfaces

```gdscript
# res://src/core/save_load/save_game.gd
class_name SaveGame extends Resource

# In-code sentinel (NOT @export — const cannot be exported in GDScript)
const FORMAT_VERSION: int = 1   # increment on any schema change

# Serialized fields
@export var save_format_version: int = FORMAT_VERSION  # written at save, checked at load
@export var saved_at_iso8601: String = ""
@export var section_id: StringName = &""
@export var elapsed_seconds: float = 0.0

# Per-system state (each is a typed Resource — see save_load/states/)
@export var player: PlayerState
@export var inventory: InventoryState
@export var stealth_ai: StealthAIState
@export var civilian_ai: CivilianAIState
@export var documents: DocumentCollectionState
@export var mission: MissionState
```

```gdscript
# res://src/core/save_load/save_load_service.gd
# Autoload: "SaveLoad", load order 3 (after Events at order 1, EventLogger at order 2)
class_name SaveLoadService extends Node

enum FailureReason {
    NONE,
    IO_ERROR,           # ResourceSaver returned non-OK
    VERSION_MISMATCH,   # save_format_version != FORMAT_VERSION
    CORRUPT_FILE,       # ResourceLoader returned null or wrong type
    SLOT_NOT_FOUND,     # load called on empty slot
    RENAME_FAILED,      # atomic rename step failed
}

const SAVE_DIR: String = "user://saves/"

# Public API — fully decoupled from game-system internals.
# Caller MUST construct the SaveGame before calling save_to_slot.

func save_to_slot(slot: int, save_game: SaveGame) -> bool:
    # Returns true on success; emits Events.save_failed on failure.
    # Atomic write: tmp file → rename → metadata sidecar → screenshot.
    # On success: emits Events.game_saved(slot, save_game.section_id).
    pass

func load_from_slot(slot: int) -> SaveGame:
    # Returns the loaded SaveGame, or null on any failure.
    # Type-guards against class mismatch and version mismatch.
    # On success: emits Events.game_loaded(slot).
    # On failure: emits Events.save_failed(reason).
    # CALLER is responsible for calling .duplicate_deep() before
    # handing fields to live systems (state isolation).
    pass

func slot_exists(slot: int) -> bool: pass

func slot_metadata(slot: int) -> Dictionary:
    # Reads slot_N_meta.cfg (ConfigFile sidecar) — does NOT load the full Resource.
    # Used by the Menu System to render save cards without paying full load cost.
    # Returns: {section_id, section_display_name, saved_at_iso8601,
    #           elapsed_seconds, screenshot_path, save_format_version}
    pass
```

```gdscript
# Per-actor state — actor identity scheme
# res://src/core/save_load/states/stealth_ai_state.gd
class_name StealthAIState extends Resource

@export var guards: Dictionary = {}  # Dictionary[StringName, GuardRecord]

# res://src/core/save_load/states/guard_record.gd
class_name GuardRecord extends Resource

@export var alert_state: int = 0           # StealthAI.AlertState enum
@export var patrol_index: int = 0
@export var last_known_target_position: Vector3 = Vector3.ZERO
@export var current_position: Vector3 = Vector3.ZERO
```

```gdscript
# Each guard/civilian script declares a stable actor_id (set in scene)
# res://src/gameplay/stealth_ai/guard.gd
class_name Guard extends CharacterBody3D

@export var actor_id: StringName = &""  # MUST be unique per section scene
```

### Implementation Guidelines

1. **`SaveGame.FORMAT_VERSION` is a `const`; `save_format_version` is an `@export var` initialized from it.** Only the `var` is serialized. The `const` is the runtime sentinel for compare-on-load.
2. **`SaveLoadService` accepts a pre-assembled `SaveGame`** — it does NOT query game systems to assemble one. Mission Scripting (or Failure & Respawn, or a player save action) builds the `SaveGame` by reading current state from each owning system, then passes it in. This keeps `SaveLoadService` decoupled from the rest of the game.
3. **State isolation on load**: callers MUST call `loaded_save.duplicate_deep()` before handing nested state to live systems. Otherwise, mutations to live state would mutate the cached loaded resource. Document this as a load-side discipline rule.
4. **Type-guard after every load**: `if loaded == null or not (loaded is SaveGame): emit save_failed(CORRUPT_FILE); return null`. Binary `.res` returns `null` silently on class mismatch — this is the most likely silent bug.
5. **Atomic write**: write to `slot_N.res.tmp` first; verify `ResourceSaver.save() == OK`; then `DirAccess.rename(tmp, final)`. Power-loss mid-write leaves the previous good save intact.
6. **Per-actor identity uses `actor_id: StringName`** declared as `@export` on the actor's script and set uniquely in each section's scene. The scene author is responsible for uniqueness within a section. Do NOT use `NodePath` or `Node` references in saved Resources — they cannot survive a scene reload.
7. **Save slot scheme**: 8 slots total — `slot_0` = autosave (overwritten at every section transition + explicit save action), `slot_1`–`slot_7` = player-controlled manual saves. NOLF1-style multi-slot, generously sized so players can keep milestone saves at every section + alternate route experiments.
8. **Metadata sidecar**: every `slot_N.res` has a paired `slot_N_meta.cfg` (ConfigFile) and optional `slot_N_thumb.png`. Sidecar fields: `section_id`, `section_display_name`, `saved_at_iso8601`, `elapsed_seconds`, `screenshot_path`, `save_format_version`. Menu System reads only the sidecar to render save cards (avoids full Resource load).
9. **Failure handling**: on any save failure, emit `Events.save_failed(reason)`, return `false`, leave the previous good save intact. Do NOT auto-delete or auto-recover destructively. The Menu System listens for `save_failed` and shows a dialog.
10. **Settings file is separate**: Settings & Accessibility uses `user://settings.cfg` (ConfigFile) — never part of the SaveGame Resource. Prevents settings loss when starting a new game and decouples settings versioning from save format versioning.

## Alternatives Considered

### Alternative 1: JSON via `FileAccess` + manual serialization

- **Description**: Each system contributes a Dictionary to a top-level Dictionary; serialize via `JSON.stringify()` / `JSON.parse_string()`; write via `FileAccess.store_string()`.
- **Pros**: Human-readable for debugging; full control over format; trivial migration logic; easy to share saves for support.
- **Cons**: ~2-3× larger files; loses Godot type safety (everything is `Dictionary` or `Variant`); manual marshaling/unmarshaling boilerplate per system; no editor preview of save state; FileAccess.store_* return-bool change (4.4) means more error-handling boilerplate.
- **Estimated Effort**: 2× chosen approach (per-system marshal/unmarshal).
- **Rejection Reason**: Loses the type-safety benefit that `Resource` + `@export` provides for free. The schema fragmentation problem the contract is meant to solve gets re-introduced as "every system invents its own dictionary shape."

### Alternative 2: Custom binary via `FileAccess.store_buffer()`

- **Description**: Each system writes raw bytes via `FileAccess`; central format header + per-system payload chunks.
- **Pros**: Smallest file size; fastest read/write; full control over format.
- **Cons**: Massive implementation cost; debugging is opaque (need a hex viewer); migration is a custom byte-level parser; no Godot tool benefits (editor preview, type system).
- **Estimated Effort**: 4× chosen approach.
- **Rejection Reason**: Total overkill for ~1–10 KB sectional saves. The space and time savings are imperceptible at this size; the engineering cost is not.

### Alternative 3: `ConfigFile` (.ini-like)

- **Description**: Use Godot's built-in `ConfigFile` for the entire save.
- **Pros**: Built-in; human-readable; trivial for flat settings.
- **Cons**: Awkward for nested structures (per-guard records would have to flatten to dotted keys); no type safety (everything is `Variant`); not idiomatic for gameplay state.
- **Estimated Effort**: Comparable to JSON alternative.
- **Rejection Reason**: ConfigFile is the right choice for settings (used here for `user://settings.cfg`) and for the metadata sidecar. It is the wrong choice for nested gameplay state.

### Alternative 4: Full-game state per save (not sectional)

- **Description**: Each save captures the entire mission state across all sections — completed, current, and locked-but-known.
- **Pros**: Player can return to any section freely from a single save; richer save UI ("you've been to 4 of 5 sections").
- **Cons**: Larger files (still small in absolute terms — maybe 20 KB instead of 5 KB); more complex schema; more code paths to test (what does it mean to "save" while in section 3 if section 1 is also persisted?); doesn't match the concept doc's "sectional" specification.
- **Estimated Effort**: 1.5× chosen approach (more state to serialize, more reload logic).
- **Rejection Reason**: Concept doc explicitly specifies sectional saves (NOLF1-style). Full-game state is overkill for a 5-section linear mission.

### Alternative 5: Versioning via explicit migration functions (instead of refuse-load-on-mismatch)

- **Description**: Each schema change includes a migration function `migrate_v1_to_v2(old_save: Dictionary) -> SaveGame` that the loader calls when version mismatches.
- **Pros**: Saves survive patches; required if Tier 2 (Rome/Vatican) ever ships and changes the format.
- **Cons**: Migration functions are non-trivial code that must be written and tested for every schema change; each old version remains a maintenance burden forever.
- **Estimated Effort**: Higher per schema change; lower at first ship.
- **Rejection Reason**: User chose simpler path. Acceptable trade-off for single-shot indie ship. **Documented trade-off**: if Tier 2 ever ships and changes the SaveGame schema (e.g., adds a `mission_id` field to support multi-mission saves), Paris-mission saves from v1 will be invalidated. Players will start a new game when they buy Rome/Vatican — which happens to also be a new mission, so the UX impact is plausibly muted, but real.

## Consequences

### Positive

- One canonical save format means no per-system fragmentation. Adding a new state field is a one-line `@export` on the relevant `*_State` Resource.
- `Resource` + `@export` gives free type safety and editor preview during development.
- Atomic write pattern eliminates corrupt-save-on-crash failures.
- Sectional scope keeps save files small (~1–10 KB) and load-time imperceptible.
- `SaveLoadService` autoload is fenced to file I/O only — does not become a service locator (respects ADR-0002 anti-pattern fence).
- Caller-assembled `SaveGame` keeps state ownership with the systems that own it (Mission Scripting reads from each system at save-time).
- `actor_id` scheme survives scene reloads — no NodePath fragility.
- Metadata sidecar means the menu renders save cards in O(metadata) not O(full save).
- Settings separated from saves prevents settings loss on new-game.

### Negative

- Refuse-load-on-mismatch versioning means any patch that changes save schema invalidates existing saves. **Trade-off documented** — acceptable for single-shot ship; would force players to restart on Tier 2 release if Rome/Vatican changes the format.
- Binary `.res` is opaque to debug — need editor or `ResourceLoader` to inspect a save. Mitigated by: (a) writing a `.tres` debug dump from the editor when needed; (b) the metadata sidecar (ConfigFile) is human-readable.
- `actor_id` uniqueness within a section scene is a scene-authoring discipline. Easy to violate; needs a section-scene lint check.
- `SaveLoadService` API requires callers to assemble `SaveGame` before calling — more verbose at call site than a "save the world" autoload method, but enforces decoupling.
- `duplicate_deep()` discipline on load (state isolation) is easy to forget — needs to be in code review checklist and the control manifest when authored.

### Neutral

- 8 save slots (1 autosave + 7 manual) gives players generous room for milestone saves and alternate-route experiments. The Menu System's mission-dossier card grid will need to handle 8 slots cleanly (UX consideration for the Menu System GDD).
- Settings as `user://settings.cfg` is the standard Godot convention.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| `ResourceSaver.save() with FLAG_COMPRESS` produces unexpected output in Godot 4.6 | LOW | MEDIUM | **Verification gate 1**: 5-minute editor test before status moves to Accepted. |
| `DirAccess.rename()` API changed in 4.4–4.6 | LOW | LOW | **Verification gate 2**: editor confirmation. Breaking-changes doc does not flag this as changed. |
| Binary `.res` returns `null` on class-name mismatch (silent failure) | HIGH | MEDIUM | Mandatory type-guard pattern after every load: `if loaded == null or not (loaded is SaveGame): emit save_failed`. Documented in implementation guidelines + control manifest. |
| Subscriber forgets `duplicate_deep()` on load → cached loaded resource gets mutated by live systems | MEDIUM | MEDIUM | Documented as load-side discipline. Code review catches; control manifest entry when authored. |
| Scene author duplicates `actor_id` between two guards in same section → save key collision | MEDIUM | HIGH | Section-scene lint check (when test scaffolding lands). Until then, code review on every section scene. |
| Power loss during save leaves corrupt slot file | LOW | HIGH | Atomic write pattern (tmp + rename) ensures previous good save survives. |
| Tier 2 (Rome/Vatican) ships and changes save schema → Paris saves invalidated | MEDIUM | LOW | Documented trade-off. Players starting Tier 2 are starting a new mission anyway. If schema migration becomes critical, supersede this ADR with one selecting Alternative 5. |
| `SaveLoadService` drifts toward becoming a service locator (gains methods that query game systems) | MEDIUM | HIGH | Anti-pattern fence registered in `architecture.yaml`: `save_service_assembles_state` forbidden. Code review on every PR touching the file. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (save latency, ~5 KB save on SSD) | N/A | ≤2 ms (write + rename + sidecar) | 100 ms perceptible threshold |
| CPU (save latency, spinning disk worst case) | N/A | ≤10 ms | 100 ms |
| CPU (load latency at section start) | N/A | ≤2 ms (load + duplicate_deep + assign) | Hidden inside Level Streaming load cost (~200–500 ms) |
| Memory (per loaded SaveGame instance) | N/A | <100 KB even after duplicate_deep | N/A |
| Disk (per save slot) | N/A | ~5 KB binary `.res` + ~1 KB metadata + ~50 KB optional thumbnail | Negligible |

> No need for async/threaded save. Synchronous fits the budget by orders of magnitude.

## Migration Plan

This is the project's third ADR. No existing code or saves to migrate. Implementation order:

1. Verification gates: 5-minute Godot 4.6 editor session — (a) save and reload a binary `.res` with `FLAG_COMPRESS`; (b) rename a file via `DirAccess.rename()`; (c) `duplicate_deep()` on a `SaveGame` with nested typed-Resource fields.
2. Create `res://src/core/save_load/` directory tree per the file structure in Decision section.
3. Implement `SaveGame` Resource with stub state Resources (each system fills out its own state Resource later in its own GDD).
4. Implement `SaveLoadService` autoload with atomic-write pattern. Wire up `Events.game_saved` / `Events.game_loaded` / `Events.save_failed` emits.
5. Smoke test: assemble a stub SaveGame, save to slot 0, reload, confirm round-trip equality.
6. Set ADR-0003 status Proposed → Accepted.
7. Begin authoring system GDDs that contribute serialized state — each GDD must include a "Save State" subsection specifying its `*_State` Resource shape and its `actor_id` convention if applicable.

**Rollback plan**: If `Resource`-based binary saves prove problematic in practice (e.g., class-name lookup turns out to be flaky across builds), supersede this ADR with one selecting Alternative 1 (JSON). The contract (sectional, refuse-load-on-mismatch, caller-assembled, atomic-write, actor_id) remains; only the format mechanism changes.

## Validation Criteria

- [ ] **Gate 1**: `ResourceSaver.save(test_save, "user://test.res", ResourceSaver.FLAG_COMPRESS)` returns `OK` in Godot 4.6 editor.
- [ ] **Gate 2**: `DirAccess.rename(tmp, final)` renames atomically on Linux and Windows.
- [ ] **Gate 3**: `SaveGame.duplicate_deep()` on an instance with nested typed `*_State` Resources produces a fully isolated copy (mutations to copy don't affect original).
- [ ] `SaveLoadService` autoload registered in `project.godot`, load order 3.
- [ ] Smoke test: round-trip save → load → confirm SaveGame equality.
- [ ] Power-loss simulation: kill process mid-write; reload; confirm previous good save intact.
- [ ] All system GDDs that contribute saved state include a "Save State" subsection specifying their `*_State` Resource shape.
- [ ] Anti-pattern fence registered: `save_service_assembles_state`, `save_state_uses_node_references`, `forgotten_duplicate_deep_on_load`.
- [ ] Code review checklist includes `actor_id` uniqueness within section scenes.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/systems-index.md` | Save/Load (system 6) | "Sectional checkpoints, NOLF-style, save data serialization" | This contract IS the implementation: sectional scope, atomic write, typed Resource serialization, `Events.game_saved` notification. |
| `design/gdd/systems-index.md` | Failure & Respawn (system 14) | "Sectional restart contract" | `Events.respawn_triggered(section_id)` triggers a load from autosave (slot 0); SaveLoadService restores SaveGame; `duplicate_deep()` isolates state. |
| `design/gdd/systems-index.md` | Inventory & Gadgets (system 12) | "Equipped state, ammo per weapon" | `InventoryState extends Resource` is the typed shape; `@export var ammo: Dictionary` (StringName→int) serializes cleanly. |
| `design/gdd/systems-index.md` | Stealth AI (system 10) | "Per-guard alert state, patrol index, last-known-target" | `StealthAIState.guards: Dictionary[StringName, GuardRecord]` keyed by `actor_id`. Survives scene reload via stable IDs. |
| `design/gdd/systems-index.md` | Document Collection (system 17) | "Per-save collection state" | `DocumentCollectionState.collected: Array[StringName]` of document IDs. |
| `design/gdd/systems-index.md` | Mission & Level Scripting (system 13) | "Mission state, objective tracking, scripted-event triggers fired" | `MissionState` Resource with `current_section`, `objectives_completed: Array[StringName]`, `triggers_fired: Array[StringName]`. |
| `design/gdd/systems-index.md` | Settings & Accessibility (system 23) | "Graphics/audio/input options, subtitle toggle, text scaling" | Settings explicitly NOT part of SaveGame — uses separate `user://settings.cfg` ConfigFile. Prevents settings loss on new game. |
| `design/art/art-bible.md` | Section 7D | "Save/load = period mission-dossier card" | Save metadata sidecar (`slot_N_meta.cfg`) provides the fields the Menu System needs to render the dossier card without loading the full SaveGame Resource. |

## Related

- **ADR-0001** (Stencil ID Contract) — independent; no interaction.
- **ADR-0002** (Signal Bus + Event Taxonomy) — soft dependency. Save/Load publishes `game_saved`, `game_loaded`, `save_failed` defined there. The `SaveLoad.FailureReason` enum is OWNED by `SaveLoadService` (per ADR-0002's enum-ownership rule).
- **ADR-0004** (UI Framework — pending) — Menu System will consume `slot_metadata()` to render the mission-dossier card per Art Bible 7D. Must NOT call `load_from_slot()` directly during menu rendering (use the sidecar).
- **`docs/registry/architecture.yaml`** — new entries: `state_ownership` for save data ownership, `interfaces` for SaveLoadService API contract, `api_decisions` for binary `.res` format choice, `forbidden_patterns` for save-system anti-patterns.
- **Future system GDDs**: every system that contributes to save state will define its own `*_State extends Resource` shape in its GDD's "Save State" subsection.
