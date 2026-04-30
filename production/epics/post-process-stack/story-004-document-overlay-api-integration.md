# Story 004: Document Overlay API integration handshake

> **Epic**: Post-Process Stack
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3 hours (M — signal connections + integration test covering the Document Overlay ↔ PostProcessStack API contract)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-002, TR-PP-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (FPS Hands Outline Rendering) — composition layer context; ADR-0008 (Performance Budget Distribution) — chain cost with sepia active
**ADR Decision Summary**: The GDD establishes a hard API contract (§Interactions, §Detailed Design Core Rule 5): Document Overlay UI calls `PostProcessStack.enable_sepia_dim()` on `open()` and `PostProcessStack.disable_sepia_dim()` on `close()`. This is the direct-method-call pattern (not signal-bus), as `PostProcessStack` is an autoload and its API is directly accessible. The Overlay UI epic depends on this API being stable — this story makes the integration handshake testable and documents it as a binding contract for the Document Overlay UI epic.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Direct autoload method call (`PostProcessStack.enable_sepia_dim()`) is stable GDScript 4.0+ pattern. Signal Bus subscription for `document_opened` / `document_closed` events uses `Events.document_opened.connect(...)` in `_ready()` per ADR-0002 IG 3 (connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards). No post-cutoff API risk.

**Control Manifest Rules (Foundation)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required: every Node-typed signal payload checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4) — `document_opened` payload is a `StringName doc_id`, not a Node; this rule applies if any Node is in a future signal extension
- Forbidden: PostProcessStack must NOT publish any signals (GDD §Anti-patterns `pps_publishing_signals` — the stack is a one-way service, not an event emitter)
- Forbidden: PostProcessStack must NOT hold references to Document Overlay or any other system (GDD Core Rule 5 — service-locator anti-pattern); it responds to direct method calls only
- Guardrail: signal `document_opened` / `document_closed` are one-shot per session (≤7 document picks per play-through per ADR-0002 IG 5 frequency table) — no per-frame cost concern

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` §Acceptance Criteria AC-6 and AC-7 + §Interactions ADR-0004 lifecycle contract:*

- [ ] **AC-1**: GIVEN Document Overlay UI is closed (no overlay), WHEN the player triggers `interact` on a document and the Document Overlay calls `PostProcessStack.enable_sepia_dim()`, THEN `PostProcessStack.is_sepia_active` transitions to `true` and the sepia dim begins fading in (state = `FADING_IN`). Verifiable via an integration test with a stub Document Overlay caller.
- [ ] **AC-2**: GIVEN the Document Overlay is open (sepia is ACTIVE or FADING_IN), WHEN the player dismisses the overlay and the Document Overlay calls `PostProcessStack.disable_sepia_dim()`, THEN `PostProcessStack` transitions to `FADING_OUT` and eventually `IDLE` with `is_sepia_active = false`.
- [ ] **AC-3**: GIVEN sepia dim is ACTIVE, WHEN a `CanvasLayer` renders the Document Overlay card above the post-processed scene, THEN the card content appears at full saturation while the world behind it is sepia-dimmed. This is a structural assertion: the overlay's `CanvasLayer` (layer index 20 per GDD §Interactions, above HUD at 8-9) renders AFTER the `CompositorEffect` chain completes, which means the CanvasLayer is not subject to the sepia dim pass. Confirmed via screenshot in Story 007.
- [ ] **AC-4**: GIVEN `PostProcessStack` autoload, WHEN the source file is grepped for signal emissions (`emit(`) or signal declarations, THEN zero matches (PostProcessStack publishes no signals — GDD anti-pattern `pps_publishing_signals`).
- [ ] **AC-5**: GIVEN `PostProcessStack` autoload, WHEN the source file is grepped for direct references to Document Overlay, Menu System, or any other system class name (other than `Events` and `SepiaDimEffect`), THEN zero matches (no service-locator references — GDD Core Rule 5).
- [ ] **AC-6**: The integration contract is documented in `docs/architecture/` as a cross-reference comment: "Document Overlay UI (system 20) calls `PostProcessStack.enable_sepia_dim()` on open and `PostProcessStack.disable_sepia_dim()` on close per GDD post-process-stack.md §Interactions + ADR-0004 lifecycle contract." This ensures the Document Overlay UI epic finds the contract when implementing.

---

## Implementation Notes

*Derived from GDD §Interactions ADR-0004 lifecycle contract + §Detailed Design Core Rule 5 + ADR-0002 IG 3:*

This story wires the integration from the PostProcessStack side. Document Overlay UI epic will wire its side later. The integration is testable now via a stub caller.

**What PostProcessStack owns here:**

PostProcessStack does NOT subscribe to `Events.document_opened` directly — the GDD's lifecycle contract specifies that Document Overlay UI calls `PostProcessStack.enable_sepia_dim()` directly (not via signal). PostProcessStack is a passive service that responds to calls. It does NOT listen for `document_opened`.

The GDD's ADR-0004 lifecycle contract snippet:
```
# Document Overlay calls:
func _on_document_opened(doc_id: StringName) -> void:
    PostProcessStack.enable_sepia_dim()   # <-- Document Overlay's responsibility
    _show_document_card(doc_id)
```

PostProcessStack's side is therefore complete after Story 003. This story:
1. Writes an integration test that acts as a stub Document Overlay caller
2. Verifies the API contract is stable and testable
3. Ensures no forbidden coupling patterns have been introduced
4. Documents the contract for the Document Overlay UI epic

**Integration test pattern** (`tests/integration/post_process_stack/document_overlay_handshake_test.gd`):

```
# Stub caller: mimics Document Overlay UI calling the API
func test_enable_on_document_open():
    var pps = PostProcessStackService.new()  # or add_child to test scene
    pps.enable_sepia_dim()
    assert_true(pps.is_sepia_active)
    # state machine is FADING_IN immediately after call

func test_disable_on_document_close():
    # ... set up ACTIVE state, call disable_sepia_dim(), assert FADING_OUT
```

**CanvasLayer ordering note** (AC-3): The sepia dim `CompositorEffect` operates on the 3D viewport's color buffer. Godot's `CanvasLayer` renders after the 3D viewport in the rendering pipeline. Any `CanvasLayer` (Document Overlay is at layer 20) is composited over the post-processed 3D frame — it is never subject to the `CompositorEffect`. This is a structural Godot rendering property, not PostProcessStack code. The integration test for AC-3 is a visual check (Story 007), not a code assertion.

**Contract documentation**: Update `src/foundation/post_process/post_process_stack.gd` with a doc comment above `enable_sepia_dim()`:
```
## Called by Document Overlay UI (system 20) on document open per GDD post-process-stack.md §Interactions.
## Also valid for Menu System and Cutscenes (see GDD §Open Questions).
## Direct call only — PostProcessStack does not subscribe to document_opened signal.
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Document Overlay UI epic: the Document Overlay side of the integration (calling `enable_sepia_dim()` / `disable_sepia_dim()` from the overlay's open/close lifecycle)
- Story 007: visual screenshot verification that the Document Overlay card appears at full saturation while the world is sepia-dimmed (AC-3 visual confirmation)
- Menu System and Cutscenes sepia dim integration (deferred per GDD §Open Questions — Menu GDD and Cutscenes GDD decide independently)

---

## QA Test Cases

**AC-1 — enable_sepia_dim() call from stub Document Overlay**
- Given: `PostProcessStackService` in IDLE state (fresh instance)
- When: a stub caller (mimicking Document Overlay) calls `PostProcessStack.enable_sepia_dim()`
- Then: `is_sepia_active == true`; internal state == FADING_IN; the SepiaDimEffect receives a `set_dim_intensity` call with a value > 0.0 (or tween has started)
- Edge cases: call while already ACTIVE → AC-5 idempotency (no-op); call twice rapidly → single tween running

**AC-2 — disable_sepia_dim() call from stub Document Overlay**
- Given: state == ACTIVE (sepia fully on)
- When: stub caller calls `PostProcessStack.disable_sepia_dim()`
- Then: state == FADING_OUT; eventually (after 0.5 s or simulated time) state == IDLE, `is_sepia_active == false`
- Edge cases: call while IDLE → idempotent no-op (no error)

**AC-4 — No signal publications from PostProcessStack**
- Given: `post_process_stack.gd` source
- When: source is grepped for `emit(` occurrences and `signal ` declarations
- Then: zero matches (the service publishes no signals)
- Edge cases: future developer adds a debug signal → this test catches the addition before review

**AC-5 — No service-locator coupling**
- Given: `post_process_stack.gd` source
- When: source is grepped for references to `DocumentOverlay`, `MenuSystem`, `CutsceneManager`, or any other non-Events, non-SepiaDimEffect class
- Then: zero matches
- Edge cases: helper import at top of file → grep for class names in method body only (exclude `class_name` and `extends` lines)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/post_process_stack/document_overlay_handshake_test.gd` — must exist and pass
- Test acts as stub Document Overlay caller; covers AC-1, AC-2 (enable/disable API round-trip)
- AC-4 and AC-5 covered by grep assertions in the same or a companion unit test file
- AC-3 (visual: card at full saturation) deferred to Story 007 visual evidence

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (tween state machine must be DONE; integration test exercises the full lifecycle)
- Unlocks: Document Overlay UI epic (can now implement against the stable, tested API contract), Story 007 (visual check of the CanvasLayer + sepia composition)
