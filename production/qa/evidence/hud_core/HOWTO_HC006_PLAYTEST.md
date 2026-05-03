# How to do the HC-006 visual playtest + Slot 7 perf measurement

This is the step-by-step for the user. Sprint 06 close-out items 2 + 3.
Plaza VS scene + HUD + HSS are wired in `src/core/main.gd`. Debug keys
F1–F8 are added so you can trigger every AC without needing Combat or
Document Collection systems (those ship in Sprint 7).

---

## 1. Launch the project

1. Open `/home/agu/Projects/Claude-Code-Game-Studios/project.godot` in Godot 4.6.
2. Press **F5** (or click the Play ▶ button).
3. The Plaza VS scene loads. Mouse is captured immediately.

You should see:
- 3D Plaza environment (floor, walls, crates, pillar)
- WelcomeLabel showing keybindings
- **Bottom-Left HUD widget**: `HP 100` (Parchment-on-blue panel)
- Other HUD slots empty until triggered

If you do NOT see the HUD: the burst emit may have raced HUD `_ready`. Press **F3** to force-emit `player_health_changed(100, 100)`.

---

## 2. Visual sign-off — AC-2 / AC-3 / AC-4 / AC-6

### AC-2: Health widget — damage flash + critical-state edge trigger

| Step | Key | Expected |
|---|---|---|
| 1. Trigger damage flash | **F1** | Health numeral flashes WHITE for 1 frame, reverts to Parchment `#F2E8C8` |
| 2. Drop to critical health | **F2** | Numeral colour switches to Alarm Orange `#E85D2A` (and updates to `20`) |
| 3. Damage flash while critical | **F1** | Brief white flash, reverts to Alarm Orange (NOT Parchment — captured pre-flash colour) |
| 4. Recover above 25% | **F3** | Numeral reverts to Parchment, value `100` |

**Screenshots to capture** (`production/qa/evidence/hud_core/`):
- `screenshot_001_health_parchment.png` — full health (100), Parchment
- `screenshot_002_health_alarm_orange.png` — critical (20), Alarm Orange
- `screenshot_003_damage_flash_mid_white.png` — caught mid-flash white (try ~30 fps screen capture if F1 frame is too fast)

### AC-3: Interact prompt strip

**Currently unobservable** — Plaza has no interactable document prop with `interact_label_key`. The prompt resolver's hidden state can be confirmed (no prompt visible at any time). Adding a real interactable belongs to the Document Collection epic (Sprint 7 DC-001..005).

What you CAN verify visually:
- Walk anywhere in Plaza — prompt strip stays HIDDEN (correct AC-2 path B / AC-4 null-PC path).

Screenshot:
- `screenshot_004_no_prompt.png` — no prompt visible while walking

### AC-4: Pickup memo

| Step | Key | Expected |
|---|---|---|
| 1. Trigger document collected | **F4** | Bottom-center prompt strip shows `<doc_collected_text>: plaza_dossier` for 3 seconds, then hides |

Screenshot:
- `screenshot_005_pickup_memo.png` — memo visible mid-display

### AC-6: Theme + typography visual check

While the HUD is visible, verify (no key needed — just look):
- ☐ BL Health panel: BQA Blue `#1B3A6B` at **85% opacity** (translucent over Plaza geometry)
- ☐ No rounded corners on any HUD panel
- ☐ No drop shadows on any HUD element
- ☐ Health numeral typeface is Futura Condensed Bold @ 1080p (condensed sans-serif look) — system font fallback used at MVP per FontRegistry MVP placeholder
- ☐ Key-rect border around `[E]` glyph: 1px Parchment, transparent fill (only visible during AC-3 — currently unobservable)

Screenshot:
- `screenshot_006_hud_opacity_85_percent.png` — BL widget over varied geometry (wall + floor + sky behind)

---

## 3. AC-7: Context-hide + context-restore (bonus check)

| Step | Key | Expected |
|---|---|---|
| 1. Trigger menu context | **F7** | All HUD elements hide (`visible = false`); `_process` disabled |
| 2. Restore gameplay | **F8** | All HUD elements visible again |

---

## 4. HSS-002: ALERT_CUE (HUD State Signaling)

| Step | Key | Expected |
|---|---|---|
| 1. Trigger alert | **F6** | HSS state activates ALERT_CUE — currently NOT visually rendered (HUD Core doesn't yet pull from `_resolver_extensions` on every frame; HC-006 acceptance only required the architectural smoke). Confirmed via the test suite. |

Note: the actual HSS text-to-prompt-label projection is wired but the HUD Core resolver loop that pulls from `_resolver_extensions` is post-VS (the registry is populated; the priority dispatcher is not). **For HC-006 visual sign-off, treat HSS-002 as architecturally verified by the unit tests (10/10 PASS).**

---

## 5. AC-5: Slot 7 perf measurement (Godot Profiler)

### Setup
1. With the scene running (F5), press **F7** to OPEN the Godot Editor's Debugger panel (or click Debugger tab at the bottom).
2. Click **Profiler** sub-tab.
3. Click **Start** to begin profiling.

### Worst-case sequence (30-second window)
While profiling is active, perform this sequence:
1. Walk around for ~5 seconds (HUD `_process` runs each frame for the prompt resolver).
2. **F1** twice (damage flash + rate-gate latch).
3. **F2** then **F3** (critical state edge + recovery edge — fires `_on_health_changed` twice).
4. **F4** (memo + 3-second display).
5. **F7** then **F8** (context-hide + context-restore — exercises `set_process(false)`).
6. **F6** (alert state — fires HSS handler).
7. Walk ~5 more seconds.

### Stop + record
1. Click **Stop** to end profiling.
2. In the **Script** panel of the profiler (or **Functions** if labeled), find `HUDCore._process` in the call tree. The "Self" column is the time HUDCore's own `_process` body takes (excluding children).
3. Record:
   - Worst-case single-frame `Self` cost (ms)
   - Mean `Self` cost (ms)
   - Total sample count

### Pass criterion
**HUDCore._process worst-case ≤ 0.300 ms**

If exceeded: open `production/qa/evidence/hud_core/vs_smoke_evidence_skeleton.md` and document the violation. The likely culprit would be `_compose_prompt_text` doing too many tr() calls — but the change-guard in HC-004 should keep it at zero `tr()` calls per frame when the target is unchanged.

If pass: take a screenshot of the profiler showing the `HUDCore._process` line:
- `screenshot_007_profiler_hudcore_process.png`

---

## 6. Fill in the evidence doc

Open `production/qa/evidence/hud_core/vs_smoke_evidence_skeleton.md` and:
1. Replace `Date: 2026-05-03 (skeleton)` with today's date.
2. Fill in `Developer:`, `Hardware:`, `OS:`, `Resolution:` blocks.
3. Replace each `[ ]` checkbox with `[x]` once verified.
4. Replace each `screenshot_NNN_*.png — TBD` with the actual filename you saved.
5. Fill in the **Slot 7 Perf Measurement** worst-case + mean numbers.
6. Sign off at the bottom (`[x]` Solo developer visual sign-off).

---

## 7. Cleanup before commit

The debug keys F1/F2/F3/F4/F6/F7/F8 are dev-only and should be removed before shipping. **For Sprint 06 commit they're fine** — Sprint 7 will replace them with real Combat damage events + Document Collection pickup triggers + Menu System modal opens. Add a TODO comment at the top of the debug block in `main.gd` if you want a reminder.

---

## Quick reference card

| Key | Action |
|---|---|
| **F1** | Trigger damage flash |
| **F2** | Health 20% (critical) |
| **F3** | Health 100% (recovery) |
| **F4** | Document collected (memo) |
| **F5** | Quicksave (existing) |
| **F6** | Alert state changed (HSS) |
| **F7** | Open menu (context-hide) |
| **F8** | Close menu (context-restore) |
| **F9** | Quickload (existing) |
| **WASD/Mouse** | Walk + look |
| **Esc** | Release mouse capture |
