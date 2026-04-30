# Story 004: Interact prompt strip — PC query resolver, _process state machine, get_prompt_label() extension hook

> **Epic**: HUD Core
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3–4 hours (M — _process resolver, PC injection contract, cache guards, extension hook)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-core.md`
**Requirement**: TR-HUD-003 (partial — PC query accessor contract), TR-HUD-013 (partial — no per-frame `tr()` calls)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus — subscriber-only contract, `is_instance_valid` guard) + ADR-0004 (UI Framework — no polling beyond authorised accessors) + ADR-0008 (Performance Budget — Slot 7 = 0.3 ms cap, `_process` is the primary cost site)

**ADR Decision Summary**: The interact prompt strip is the ONLY `_process()`-driven widget in HUD Core. It evaluates two PC queries (`pc.get_current_interact_target()` and `pc.is_hand_busy()`) per frame to drive a two-state machine: `HIDDEN` or `INTERACT_PROMPT` (CR-12, REV-2026-04-26). The PC reference is injected via `@export var pc: PlayerCharacter` BEFORE `add_child(hud)` — the injecting scene (or `LevelStreamingService`) must set `hud.pc = pc_node` pre-`add_child` or `_ready()` sees `null` and logs a `push_error` (CR-3). A null guard opens every `_process` path: `if pc == null: return`. The `_compose_prompt_text()` function (CR-12 §C.3) caches `tr(target.interact_label_key)` against `_last_interact_label_key: StringName` so `tr()` is called only on key change, never per-frame (FP-8, TR-HUD-013). The prompt-strip Label updates only when `new_state != _last_state or new_text != _last_prompt_text` — a change-guard prevents redundant `Label.text` writes per frame. `get_prompt_label() -> Label` exposes the prompt-strip Label reference for HSS consumption in the HUD State Signaling epic; this extension hook is the single agreed API boundary between HUD Core and HSS.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `@export var pc: PlayerCharacter` typed export requires `PlayerCharacter` class to be pre-declared in GDScript autoload or a class_name-registered script. The `is_instance_valid()` check before accessing `target.interact_label_key` is mandatory: `pc.get_current_interact_target()` may return a freed Object that passes `!= null` in Godot 4.x (ADR-0002 §IG4). `Label.text` getter in Godot 4.6 has a non-trivial cost; the change-guard compares against `_last_prompt_text` (a GDScript String var), not `_label.text` (avoids the getter call). `_process(delta)` receives `delta: float` — the delta value is not used by the resolver; the parameter is received and ignored (naming convention: `_delta`).

> "Godot 4.6 Label.text getter cost may differ from training data — verify against engine-reference before calling Label.text inside _process."

**Control Manifest Rules (Presentation)**:
- Required: `pc` set before `add_child(hud)` — pre-`_ready()` injection contract (CR-3)
- Required: `if pc == null: return` as the opening guard of `_process` and every PC-query path
- Required: `is_instance_valid(target)` before any property access on `pc.get_current_interact_target()` return value (ADR-0002 §IG4)
- Required: change-guard on prompt text — only write `_label.text` when state or text changes
- Required: `tr()` called only on interact-label-key change (FP-8, TR-HUD-013)
- Forbidden: `InputContext.push/pop/set` — HUD never modifies InputContext (FP-7, TR-HUD-015)
- Forbidden: direct PC property access beyond the two authorised query methods (FP-2, TR-HUD-013)
- Forbidden: `tr()` in `_process` without a key-change guard (FP-8)
- Guardrail: Slot 7 = 0.3 ms cap — `_process` resolver is the primary UI cost site; worst-case per F.5 must not exceed the allocated share; Story 006 measures this

---

## Acceptance Criteria

*From GDD `design/gdd/hud-core.md` §C.1 CR-3/CR-12/CR-13/CR-21, §C.3, §F.1, TR-HUD-003/013:*

- [ ] **AC-1** (CR-12, two-state machine): GIVEN `pc != null` AND `pc.get_current_interact_target()` returns a non-null, `is_instance_valid()` Node3D AND `pc.is_hand_busy()` returns `false`, WHEN `_process()` evaluates the resolver, THEN the prompt strip is in `INTERACT_PROMPT` state: `_prompt_label.visible = true` and `_prompt_label.text` reflects `_compose_prompt_text(INTERACT_PROMPT, target)`.

- [ ] **AC-2** (CR-12, HIDDEN path A — no target): GIVEN `pc != null` AND `pc.get_current_interact_target()` returns `null`, WHEN `_process()` evaluates, THEN state = `HIDDEN`: `_prompt_label.visible = false`.

- [ ] **AC-3** (CR-13, HIDDEN path B — hand busy): GIVEN `pc != null` AND `pc.get_current_interact_target()` returns a valid non-null Node3D AND `pc.is_hand_busy()` returns `true`, WHEN `_process()` evaluates, THEN state = `HIDDEN`: `_prompt_label.visible = false`. (Hand-busy suppresses the prompt even with a valid target.)

- [ ] **AC-4** (CR-3, null PC guard): GIVEN `pc == null` (not yet injected or deliberately unset), WHEN `_process()` runs, THEN state = `HIDDEN`; `_prompt_label.visible = false`; no GDScript error; no property access on `pc`.

- [ ] **AC-5** (CR-3, pre-`_ready()` injection): GIVEN the main game scene sets `hud.pc = pc_node` BEFORE calling `add_child(hud)`, WHEN `_ready()` fires, THEN `pc != null` and the prompt resolver operates correctly from first frame. Conversely, if `pc` is `null` at `_ready()` time, THEN a `push_error` is logged with message identifying the unset export and the HUD degrades gracefully (prompt always hidden until `pc` is set).

- [ ] **AC-6** (FP-8 / TR-HUD-013, `tr()` change-guard): GIVEN the resolver yields `INTERACT_PROMPT` with `target.interact_label_key == &"INTERACT_LIFT_COVER"` on frame N, WHEN frames N+1, N+2, ... also yield the same key, THEN `tr()` is called exactly once (on frame N's key-change detection) and zero times on subsequent frames where the key is unchanged. Verified by a spy counter on `_on_interact_key_changed`.

- [ ] **AC-7** (change-guard on Label.text write): GIVEN two consecutive `_process()` frames where resolver returns identical `(state, text)`, THEN `_prompt_label.text` is assigned exactly once (on state/text change), not on every frame. Verified by comparing `_last_prompt_text` with the composed string before writing.

- [ ] **AC-8** (`is_instance_valid` guard): GIVEN `pc.get_current_interact_target()` returns a freed Object reference (passes `!= null` but fails `is_instance_valid()`), WHEN `_compose_prompt_text()` runs, THEN the function returns `""` immediately (early-return path) without accessing any property on the freed object; state falls to `HIDDEN`.

- [ ] **AC-9** (CR-21, key-glyph mirror): GIVEN `_current_interact_glyph` is initialised to `"[E]"` (placeholder per CR-21 MVP development default), WHEN `_compose_prompt_text(INTERACT_PROMPT, target)` is called with key `&"INTERACT_READ_DOCUMENT"`, THEN the returned string is `_cached_static_prompt_prefix + "[E]" + " " + tr("INTERACT_READ_DOCUMENT")`. The static prefix `tr("HUD_INTERACT_PROMPT")` is cached at `_ready()` and NOT re-evaluated per frame. Placeholder `[E]` is documented in a `# TODO: CR-21 — replace with Input.get_glyph_for_action("interact") when Input GDD ships` comment.

- [ ] **AC-10** (`get_prompt_label()` extension hook): GIVEN the HUD Core scene is fully initialised, WHEN HSS calls `hud_core_instance.get_prompt_label()`, THEN it returns the `Label` node reference (`_prompt_label`) that is the visible text Label inside the prompt strip. The returned reference is the same node that `_compose_prompt_text()` writes to. This method is declared `func get_prompt_label() -> Label` in `hud_core.gd`.

- [ ] **AC-11** (TR-HUD-013, no direct PC property polling): GIVEN `src/ui/hud_core/hud_core.gd`, WHEN grep runs pattern `pc\.(health|max_health|current_health|stamina|is_crouching|is_sprinting|inventory)`, THEN zero matches (FP-2 — only `pc.get_current_interact_target()` and `pc.is_hand_busy()` are authorised).

---

## Implementation Notes

*Derived from GDD §C.1 CR-3/CR-12/CR-21, §C.3 resolver pseudocode + `_compose_prompt_text()` definition:*

**New variables added to `hud_core.gd` by this story:**

```gdscript
# PC injection (CR-3)
@export var pc: PlayerCharacter = null

# Prompt-strip state machine (CR-12)
enum PromptState { HIDDEN, INTERACT_PROMPT }
var _last_state: PromptState = PromptState.HIDDEN
var _last_prompt_text: String = ""

# Interact label key cache (FP-8 / CR-18)
var _last_interact_label_key: StringName = &""
var _cached_interact_label_text: String = ""
var _cached_static_prompt_prefix: String = ""  # set in _ready() via tr("HUD_INTERACT_PROMPT")

# Key-glyph mirror (CR-21) — placeholder until Input GDD ships
var _current_interact_glyph: String = "[E]"  # TODO: CR-21 replace with Input.get_glyph_for_action("interact")
```

**Node reference:**

```gdscript
@onready var _prompt_label: Label = $WidgetRoot/PromptStrip/CenterContainer/MarginContainer/HBoxContainer/PromptLabel
```

(Exact path matches Story 001 scene structure: CB widget's Label node. Verify path at integration time.)

**`_ready()` additions for this story:**

```gdscript
# Cache static prompt prefix (CR-18 — tr() once at ready)
_cached_static_prompt_prefix = tr("HUD_INTERACT_PROMPT") + " "
# Null-PC error gate (CR-3)
if pc == null:
    push_error("HUDCore: @export var pc is null at _ready(). "
             + "Injecting scene MUST set hud.pc = pc_node BEFORE add_child(hud).")
```

**`_process(_delta: float)` resolver (two-state machine per CR-12):**

```gdscript
func _process(_delta: float) -> void:
    # Prompt strip resolver
    if pc == null:
        _set_prompt_state(PromptState.HIDDEN, "")
        return
    var target: Node3D = pc.get_current_interact_target()
    var new_state: PromptState
    if target != null and not pc.is_hand_busy():
        new_state = PromptState.INTERACT_PROMPT
    else:
        new_state = PromptState.HIDDEN
    var new_text: String = _compose_prompt_text(new_state, target)
    if new_state != _last_state or new_text != _last_prompt_text:
        _set_prompt_state(new_state, new_text)
```

**`_compose_prompt_text()` (GDD §C.3 definition, FP-8 compliant):**

```gdscript
func _compose_prompt_text(state: PromptState, target: Node) -> String:
    if state != PromptState.INTERACT_PROMPT:
        return ""
    if not is_instance_valid(target):
        return ""
    var key: StringName = target.interact_label_key
    if key != _last_interact_label_key:
        _cached_interact_label_text = tr(key)  # tr() ONLY on key change
        _last_interact_label_key = key
    return _cached_static_prompt_prefix + _current_interact_glyph + " " + _cached_interact_label_text
```

**`_set_prompt_state()` helper:**

```gdscript
func _set_prompt_state(state: PromptState, text: String) -> void:
    _last_state = state
    _last_prompt_text = text
    _prompt_label.visible = (state != PromptState.HIDDEN)
    if state != PromptState.HIDDEN:
        _prompt_label.text = text
        # AccessKit announce deferred to avoid AT-flush race (ADR-0004 Gate 1 finding)
        _prompt_label.accessibility_description = text
```

**`get_prompt_label()` extension hook (HSS API boundary):**

```gdscript
## Returns the prompt-strip Label node for HSS extension consumption.
## HSS writes to this Label directly via its own state machine resolver.
## HUD Core retains ownership of visibility and the INTERACT_PROMPT state.
func get_prompt_label() -> Label:
    return _prompt_label
```

**Key-glyph rebinding (CR-21)**: The `_current_interact_glyph` variable is set once at `_ready()` to the placeholder `"[E]"`. When the Input GDD ships and closes CR-21, this story is amended to either:
- (a) call `Input.get_glyph_for_action(&"interact")` once at `_ready()` and cache it, plus subscribe to `Input.binding_changed` in the CR-1 subscriptions (Story 002 amendment), or
- (b) read from a `binding_changed(action: StringName, glyph: String)` Events signal if the Input GDD uses the bus.

Until CR-21 closes, `"[E]"` is the placeholder. Gamepad players see `[E]` at MVP — this is the documented exclusion `OQ-HUD-known-exclusion-1`.

**`target.interact_label_key` type**: the property is typed `StringName` on the interactable object. If the interactable GDD specifies a different type, update `_last_interact_label_key` type accordingly. Current assumption: `StringName` per Godot 4.x best practice for localisation keys.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Scene scaffold (prompt-strip Label node must exist); `_cached_static_prompt_prefix` cannot be set until the node path is authored
- **Story 002**: Signal connection plumbing (all 14 connections including `player_interacted` stub)
- **Story 003**: Health widget logic; `_on_ui_context_changed` Tween-kill block
- **Story 005**: Settings live-update wiring; `_on_ui_context_changed` full visibility implementation; `document_collected` memo notification (deferred to HSS epic, not HUD Core VS scope)
- Post-VS deferrals: Full prompt-strip rebind contract (CR-21 closes when Input GDD ships); Takedown prompt (TAKEDOWN_CUE cut from MVP per D4); HSS multi-state priority resolver (HSS epic owns priority logic on top of `get_prompt_label()`)

---

## QA Test Cases

**AC-1 — INTERACT_PROMPT state entry**
- Given: `pc` is a mock PlayerCharacter; `pc.get_current_interact_target()` returns a mock Node3D with `interact_label_key = &"INTERACT_OPEN_DOOR"`; `pc.is_hand_busy()` returns `false`
- When: `_process(0.016)` runs
- Then: `_prompt_label.visible == true`; `_prompt_label.text` contains the resolved label text; state logged as `INTERACT_PROMPT`

**AC-2 — HIDDEN when no target**
- Given: `pc.get_current_interact_target()` returns `null`
- When: `_process()` runs
- Then: `_prompt_label.visible == false`

**AC-3 — HIDDEN when hand busy**
- Given: `pc.get_current_interact_target()` returns a valid Node3D; `pc.is_hand_busy()` returns `true`
- When: `_process()` runs
- Then: `_prompt_label.visible == false` (hand-busy suppresses even with valid target)

**AC-4 — Null PC guard**
- Given: `pc = null`
- When: `_process()` runs
- Then: no GDScript error; `_prompt_label.visible == false`
- Edge cases: `pc` is null at `_ready()` → `push_error` fires once; subsequent `_process` frames degrade silently

**AC-5 — Pre-_ready() injection**
- Given: a test scene creates `HUDCore`, sets `hud.pc = mock_pc`, then calls `add_child(hud)`
- When: `_ready()` fires
- Then: `pc != null`; no `push_error`; prompt strip operates normally from first frame

**AC-6 — tr() called once per key-change only**
- Given: resolver returns `INTERACT_PROMPT` with key `&"INTERACT_READ_DOCUMENT"` for 10 consecutive frames
- When: `_process()` runs 10 times
- Then: `tr()` called exactly once (on first key match); `_last_interact_label_key == &"INTERACT_READ_DOCUMENT"` persists; no per-frame `tr()` overhead
- Automated: spy `_cached_interact_label_text` assignment count

**AC-7 — Label.text write change-guard**
- Given: state and text are identical for frames N and N+1
- When: `_process()` runs twice
- Then: `_prompt_label.text =` assignment happens only on frame N (state change); not on frame N+1 (no-change fast path)

**AC-8 — is_instance_valid guard**
- Given: `pc.get_current_interact_target()` returns a freed Object (passes `!= null`, fails `is_instance_valid()`)
- When: `_compose_prompt_text()` runs
- Then: returns `""`; no property access on freed object; no GDScript error

**AC-9 — Key-glyph placeholder**
- Given: `_current_interact_glyph = "[E]"` (default); interact target key = `&"INTERACT_LIFT_COVER"`
- When: `_compose_prompt_text(INTERACT_PROMPT, target)` executes
- Then: returned string is `tr("HUD_INTERACT_PROMPT") + " [E] " + tr("INTERACT_LIFT_COVER")`

**AC-10 — get_prompt_label() returns correct node**
- Given: `HUDCore` scene fully initialised
- When: `hud_core.get_prompt_label()` called
- Then: returned object is the same Label node that `_process()` writes to; `get_prompt_label() is Label == true`

**AC-11 — Forbidden pattern: no direct PC property polling**
- Given: `src/ui/hud_core/hud_core.gd`
- When: grep `pc\.(health|max_health|current_health|stamina|is_crouching|is_sprinting|inventory)`
- Then: zero matches

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/hud_core/test_prompt_strip_resolver.gd` — GUT tests for AC-1 through AC-10; deterministic (mock PC object injected; no real `_process` frame scheduling); must exist and pass
- `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` — extended with AC-11 grep pattern for direct PC property access
- Integration test `tests/integration/presentation/hud_core/test_prompt_strip_pc_injection.gd` — AC-5 at integration level (real scene loading, real PC node injection, real `_ready()` firing)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (prompt-strip Label node references required); Story 002 DONE (signal subscriptions plumbed; `player_interacted` stub exists); `PlayerCharacter` class must expose `get_current_interact_target() -> Node3D` and `is_hand_busy() -> bool` per PC GDD §UI Requirements
- Unlocks: HUD State Signaling epic (consumes `get_prompt_label()` to implement HSS multi-state priority resolver); Story 005 (full `_on_ui_context_changed` clears prompt strip state); Story 006 (VS integration smoke requires working prompt strip)

## Open Questions

- **`target.interact_label_key` property name**: the GDD specifies `target.interact_label_key` (StringName). Verify that the Interactable base class (or interface) in the PC/World-Object GDD exposes exactly this property name. If the property is named differently, update `_compose_prompt_text()` accordingly before sprint.
- **`PlayerCharacter` class availability at HUD compile time**: `@export var pc: PlayerCharacter` requires GDScript to resolve `PlayerCharacter` class. Verify that `player_character.gd` declares `class_name PlayerCharacter` and is accessible from `src/ui/hud_core/hud_core.gd` at project load time. If the PC class is in a different directory or uses a different class_name, update the export type annotation or use an untyped `@export var pc: Node` with a runtime cast.
- **`_process` opt-out when HUD is hidden**: When `visible = false` (context != GAMEPLAY), should `_process` be suppressed entirely via `set_process(false)` to reclaim the Slot 7 budget? Current implementation runs the resolver even when hidden (cheap, because `pc == null` fast-path fires) but technically wastes cycles. Decision: call `set_process(new_ctx == InputContext.Context.GAMEPLAY)` inside `_on_ui_context_changed` — deferred to Story 005 for the full context-change handler.
