# Story 006: Plaza VS integration smoke — end-to-end visual sign-off + Slot 7 0.3 ms perf measurement

> **Epic**: HUD Core
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 2–3 hours (S — integration walkthrough, perf measurement, screenshot evidence; no new code unless a blocking defect is found)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-core.md`
**Requirement**: TR-HUD-010 (Slot 7 0.3 ms verification gate)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Performance Budget Distribution — Slot 7 = 0.3 ms cap for HUD Core + active modal surface; F.5 worst-case formula) + ADR-0004 (UI Framework — smoke test requirement from §Migration Plan step 8) + ADR-0002 (Signal Bus — smoke test verifies live signal plumbing end-to-end)

**ADR Decision Summary**: ADR-0008 Slot 7 allocates 0.3 ms per frame to the entire UI layer (HUD Core + any active modal surface). ADR-0004 §Migration Plan step 8 explicitly mandates a smoke-test HUD scene that receives `Events.player_health_changed` and updates the health Label as a prerequisite for setting ADR-0004 status Proposed → Accepted. This story is the VS-tier delivery of that gate: the Plaza VS scene (the vertical slice reference scene) is used as the real integration environment, exercising all Stories 001–005 together for the first time. The story has two outcomes: (1) visual sign-off — a screenshot showing the health numeral updating at <25% HP in Alarm Orange, the interact prompt showing near a document, and the pickup memo displaying briefly on document collection; (2) performance sign-off — Slot 7 measured at ≤ 0.3 ms on the development machine. If either fails, this story becomes a blocking defect story and the HUD Core epic cannot be marked Done.

**VS Scope Closure**: This story is the final deliverable of the HUD Core VS scope. After it passes, the EPIC.md Definition of Done is complete for VS tier, and the epic transitions to Done status pending `/story-done` on each constituent story.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: The Godot 4.6 `Profiler` or `VisualProfiler` is used to measure per-frame CPU cost of the HUD Core node. Measurement methodology: enable the profiler in the Godot editor during the Plaza VS scene playback; isolate `HUDCore._process` in the call-tree; record the worst-case frame cost during a 30-second gameplay window that includes at least one damage event, one interact prompt appearance, and one document collection. The 0.3 ms cap is the Iris Xe min-spec allocation — development machines may show lower costs; the measurement is a dev-machine smoke pass, with the Iris Xe gate verified on the reference hardware before sprint closure.

> "Godot 4.6 profiler call-tree granularity may differ from training data — verify that _process is reported at per-node granularity in the Script panel before relying on the measurement."

**Control Manifest Rules (Presentation)**:
- Required: evidence doc at `production/qa/evidence/hud_core/` with screenshot + perf measurement
- Required: all Stories 001–005 must be DONE before this story begins
- Guardrail: if Slot 7 > 0.3 ms on dev machine at worst-case, escalate to godot-specialist + performance-analyst before marking Done; do NOT mark Done with a known budget breach

---

## Acceptance Criteria

*From ADR-0008 §Slot 7, GDD §C.1 CR-10, §F.5, §H.0 evidence requirements, TR-HUD-010:*

- [ ] **AC-1** (end-to-end scene integration): GIVEN all Stories 001–005 are implemented and the Plaza VS scene instances HUD Core as a `CanvasLayer` child (layer = 1, NOT autoload), WHEN the scene runs in Godot 4.6, THEN: (a) No GDScript errors in the Output panel at scene load; (b) health numeral renders in the BL corner with a non-zero value; (c) no floating numbers, no minimap, no waypoints, no objective markers visible on screen (Pillar 5 check).

- [ ] **AC-2** (health widget visual sign-off): GIVEN the player takes a hit during the Plaza VS session, WHEN `Events.player_damaged` fires, THEN the health numeral flashes white for 1 frame and reverts; health numeral updates to the new `current` value. GIVEN health drops below 25% of max, THEN the numeral colour is Alarm Orange `#E85D2A`. Screenshot captured showing: (a) Parchment-on-blue health numeral at full health; (b) Alarm Orange numeral at critical health.

- [ ] **AC-3** (interact prompt visual sign-off): GIVEN the player walks within interact range of the Plaza VS document prop AND `pc.is_hand_busy() == false`, WHEN `_process()` evaluates the resolver, THEN the prompt strip appears at CB position with the document's `interact_label_key` text rendered and the `[E]` key glyph visible. GIVEN the player walks away (target becomes null), THEN the prompt strip hides (`visible = false`). Screenshot captured showing the prompt with the document in view.

- [ ] **AC-4** (pickup memo visual sign-off): GIVEN the player interacts with and collects a Plaza VS document, WHEN `Events.document_collected(doc)` fires, THEN the prompt strip briefly displays `tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)` for ~3 seconds, then hides. Screenshot captured at the moment of display (timer not yet expired).

- [ ] **AC-5** (TR-HUD-010, Slot 7 perf measurement): GIVEN the Plaza VS scene running at 1080p (or nearest available resolution on the dev machine), WHEN the Godot profiler Script panel is sampled during a worst-case 30-second window (≥1 damage event, ≥1 context switch GAMEPLAY→MENU→GAMEPLAY, ≥1 document collection), THEN the worst-case per-frame cost of `HUDCore._process` is ≤ 0.3 ms. The measurement is recorded in the evidence doc with: hardware spec, resolution, worst-case frame cost, mean frame cost, profiler screenshot.

- [ ] **AC-6** (theme and typography visual check): GIVEN the Plaza VS scene running, WHEN HUD is visible, THEN: (a) no rounded corners on any HUD panel (Art Bible §3.3); (b) no drop shadows on any HUD element; (c) health numeral and weapon+ammo text use the Futura Condensed Bold typeface at 1080p (visible as a condensed sans-serif vs a default proportional font); (d) key-rect border around `[E]` is 1 px Parchment `#F2E8C8` with transparent fill. Solo developer visual sign-off.

- [ ] **AC-7** (context-hide integration): GIVEN the player presses Esc (triggering `InputContext.push(MENU)` → `Events.ui_context_changed(MENU, GAMEPLAY)`), WHEN the menu opens, THEN all HUD elements are hidden (`visible = false` on HUD root) AND the health numeral is NOT visible behind the menu. GIVEN the player closes the menu (restoring GAMEPLAY context), THEN HUD elements are visible again and the health numeral shows the correct current value.

- [ ] **AC-8** (no autoload registration): GIVEN the Plaza VS scene's `project.godot` [autoload] block, WHEN examined, THEN `hud_core` is NOT listed as an autoload entry (FP-13 final check).

- [ ] **AC-9** (evidence doc filed): A file at `production/qa/evidence/hud_core/vs_smoke_evidence_<date>.md` exists and contains: story list (001–006 DONE), hardware spec, resolution, profiler results (AC-5), screenshot filenames, solo developer sign-off, and any open defects found during the walkthrough.

---

## Implementation Notes

*This story produces evidence, not code. If defects are found during the walkthrough, they are addressed as blocking fixes within this story before it can be marked Done.*

**Plaza VS scene setup requirements** (pre-conditions this story verifies):

1. `Plaza.tscn` (or equivalent VS scene) exists with a PlayerCharacter node, at least one interactable document prop with `interact_label_key: StringName` set, and the `Events` + `Settings` + `InputContext` autoloads in `project.godot`.
2. HUD Core is instanced as a child of the main game scene at `CanvasLayer` layer 1 (NOT as autoload).
3. `hud.pc = pc_node` is set before `add_child(hud)` in the main scene's `_ready()` (CR-3 injection contract).
4. The document prop's `document_collected` emission path is wired (either via a pickup trigger or a manual test signal emission).

**Measurement procedure (AC-5)**:

```
1. Open Plaza VS scene in Godot 4.6 editor.
2. Run the scene (F5 or play button).
3. Open Debugger → Profiler tab → Script panel.
4. Start profiling.
5. Perform worst-case sequence:
   a. Walk near a document prop (interact prompt visible for ~5 s).
   b. Press Esc → menu opens (context-hide fires) → close menu (context-restore fires).
   c. Take a damage event (manually trigger or use a debug key).
   d. Collect the document (pickup memo fires, 3 s display).
6. Stop profiling.
7. In the Script panel call tree: find "HUDCore._process". Record:
   - Worst-case single-frame cost (ms)
   - Mean frame cost (ms)
   - Total sample count
8. If "HUDCore._process" does not appear as a discrete call-tree node: check that
   `_process` is not being merged with the parent scene's _process. If merged, use
   the "self" cost column to isolate HUDCore's contribution.
9. Record results in evidence doc.
```

**Evidence file skeleton** (`production/qa/evidence/hud_core/vs_smoke_evidence_<date>.md`):

```markdown
# HUD Core VS Smoke Evidence

Date: YYYY-MM-DD
Developer: [name]
Hardware: [CPU, GPU, RAM]
OS: [Linux/Windows, kernel/build]
Godot version: 4.6.x
Resolution: 1080p (or actual)
Scene: Plaza VS (src/levels/plaza_vs.tscn or equivalent)

## Stories Completed
- [x] 001 — CanvasLayer scene root scaffold
- [x] 002 — Signal subscription lifecycle
- [x] 003 — Health widget logic
- [x] 004 — Interact prompt strip
- [x] 005 — Settings wiring + pickup memo + context-hide
- [x] 006 — This story

## Slot 7 Perf Measurement (AC-5)
HUDCore._process worst-case: X.XXX ms
HUDCore._process mean: X.XXX ms
Sample count: NNN frames
Cap: 0.300 ms
Result: PASS / FAIL

## Screenshots
- screenshot_001_health_parchment.png — full health, Parchment numeral
- screenshot_002_health_alarm_orange.png — <25% HP, Alarm Orange numeral
- screenshot_003_interact_prompt.png — document in range, prompt visible
- screenshot_004_pickup_memo.png — document collected, memo text visible
- screenshot_005_context_hide.png — menu open, HUD hidden

## Sign-off
[Developer name] — visual sign-off: PASS / FAIL
Open defects found: [none / list]
```

**Defect triage during walkthrough**: If any AC fails, the issue must be root-caused and fixed before marking this story Done. Small fixes (e.g., a wrong Label node path) can be addressed inline. Larger fixes (e.g., a scene structure mismatch from Story 001) should be filed as blocking bugs against the relevant story and resolved before closing Story 006.

**Slot 7 budget overage protocol**: If worst-case `_process` > 0.3 ms on the dev machine, escalate immediately (do NOT mark Done). Likely causes: (a) `tr()` call inside `_process` without the key-change guard (FP-8 violation — check `_compose_prompt_text`); (b) `Label.text` getter called in the change-guard instead of `_last_prompt_text` comparison; (c) `add_theme_color_override` called every frame (missing level-triggered guard). These are the F.5 cost constants that the GDD identified as the primary Slot 7 risk.

---

## Out of Scope

*By design — these are post-VS deferrals explicitly noted in the Epic VS Scope Guidance:*

- Ammo widget (no Combat in VS) — deferred post-VS
- Gadget tile widget (no Inventory in VS) — deferred post-VS
- Takedown prompt (TAKEDOWN_CUE cut from MVP per D4) — cut permanently
- Damage flash photosensitivity boot warning modal (Settings & Accessibility HARD DEP — deferred to Settings epic)
- Crosshair `_draw()` implementation (deferred post-VS; crosshair widget renders nothing until this story)
- Full prompt-strip rebind contract (CR-21 — deferred until Input GDD ships)
- Iris Xe min-spec perf measurement on reference hardware (this story does a dev-machine smoke pass; full Iris Xe gate is a pre-sprint-ship requirement per ADR-0008)

---

## QA Test Cases

**AC-1 — Scene loads without errors**
- Setup: Open Plaza VS scene in Godot 4.6; press F5
- Verify: Output panel shows no GDScript errors at startup; HUD Core CanvasLayer layer 1 appears in the scene tree
- Pass condition: Zero errors in Output; HUD is visible at frame 1

**AC-2 — Health widget end-to-end**
- Setup: Begin Plaza VS session; manually trigger `Events.player_health_changed.emit(24, 100)` via Godot editor remote debug console or test harness
- Verify: Health numeral in BL corner updates to "24" in Alarm Orange `#E85D2A`; `Events.player_health_changed.emit(100, 100)` reverts to Parchment
- Pass condition: Screenshots captured at both states

**AC-3 — Interact prompt end-to-end**
- Setup: Walk towards the Plaza VS document prop until `pc.get_current_interact_target()` returns non-null; verify `pc.is_hand_busy() == false`
- Verify: Prompt strip appears at CB position with document label and `[E]` glyph; walks away → strip hides
- Pass condition: Screenshot at prompt-visible state

**AC-4 — Pickup memo end-to-end**
- Setup: Collect the Plaza VS document (or emit `Events.document_collected.emit(doc)` via test harness)
- Verify: Prompt strip shows memo text for ~3 s; text disappears after `_memo_timer` expires
- Pass condition: Screenshot at memo-visible state

**AC-5 — Slot 7 measurement**
- Setup: Godot profiler Script panel; 30-second worst-case session per measurement procedure
- Verify: `HUDCore._process` worst-case ≤ 0.3 ms
- Pass condition: Measurement recorded in evidence doc; PASS if ≤ 0.3 ms

**AC-6 — Typography and visual restraint check**
- Setup: Visual inspection of HUD at 1080p
- Verify: Futura Condensed Bold font visible (condensed letterforms vs proportional default); no rounded corners; no shadows; `[E]` bordered rect with transparent fill
- Pass condition: Solo developer visual sign-off in evidence doc

**AC-7 — Context-hide integration**
- Setup: Active Plaza VS session; press Esc
- Verify: Menu opens; HUD elements invisible behind menu; close menu → HUD reappears with correct health value
- Pass condition: Screenshot at menu-open state (HUD hidden)

**AC-8 — No autoload**
- Setup: Open `project.godot` in text editor; search `[autoload]` block
- Verify: No entry for `hud_core` or `HUDCore`
- Pass condition: Zero matches

**AC-9 — Evidence doc filed**
- Verify: `production/qa/evidence/hud_core/vs_smoke_evidence_<date>.md` exists and contains all required fields
- Pass condition: File exists; all sections filled; developer sign-off present

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/hud_core/vs_smoke_evidence_<date>.md` — evidence doc with all fields (AC-9)
- `production/qa/evidence/hud_core/screenshot_001_health_parchment.png` (AC-2)
- `production/qa/evidence/hud_core/screenshot_002_health_alarm_orange.png` (AC-2)
- `production/qa/evidence/hud_core/screenshot_003_interact_prompt.png` (AC-3)
- `production/qa/evidence/hud_core/screenshot_004_pickup_memo.png` (AC-4)
- `production/qa/evidence/hud_core/screenshot_005_context_hide.png` (AC-7)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001–005 ALL DONE; Plaza VS scene exists with PlayerCharacter, document prop, autoloads registered; `project_theme.tres` and `hud_theme.tres` authored; `FontRegistry` static class implemented
- Unlocks: Epic DONE gate (all stories complete + evidence filed); ADR-0004 §Migration Plan step 8 smoke test satisfied; HUD State Signaling epic unblocked at the `get_prompt_label()` boundary

## Open Questions

- **Plaza VS scene availability**: This story assumes a Plaza VS scene exists at time of Story 006 execution. If the Plaza VS scene is not yet authored (level design work pending), this story blocks. Confirm with producer/lead-programmer that the VS scene is scheduled before HUD Core Story 006 executes.
- **Iris Xe reference hardware access**: The AC-5 measurement in this story is a dev-machine smoke pass. The binding Iris Xe min-spec gate (ADR-0008 Slot 7 cap verification on Iris Xe Gen 12) is a separate, pre-sprint-ship requirement. Confirm whether Iris Xe hardware is available and who owns that measurement — it is NOT part of this story's scope.
- **Test harness for signal injection**: AC-2–AC-4 require firing `Events.*` signals from outside the game loop (or via in-game triggers). Confirm the available mechanism: (a) Godot editor remote debug console, (b) a dev/debug key binding in the Plaza VS scene, or (c) a GUT integration test that injects signals. If no test harness exists at Story 006 time, this story may need to provision a minimal debug-key binding in the Plaza VS scene to trigger damage, document_collected, and context changes.
