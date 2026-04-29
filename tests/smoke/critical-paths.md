# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (reads this file).
**Update**: Add new entries when new core systems are implemented.

---

## Core Stability (always run)

1. Game launches to main menu without crash.
2. New game can be started from the main menu.
3. Main menu responds to all inputs without freezing.
4. Pause menu opens (Esc / Start) and resumes gameplay cleanly.
5. Quit-to-menu and quit-to-desktop both work without crash.

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented. -->
<!-- Example: "Player can move, jump, crouch, and the camera follows correctly." -->
6. [Primary mechanic — update when Plaza MVP is implemented]
7. [Secondary mechanic — update when stealth AI / document collection ships]

## Data Integrity

8. Quicksave (F5) completes without error and is silently dropped during blocked contexts (CUTSCENE / DOCUMENT_OVERLAY / MODAL / LOADING) per Save/Load CR-6.
9. Quickload (F9) restores correct state — player position, inventory, mission progress.
10. New Game on slot 1, then loading slot 5, does not contaminate slot 5 state (per Cutscenes EC-CMC-B.4 + Save/Load CR pattern).

## Performance

11. No visible frame-rate drops on target hardware (60 fps / 16.6 ms budget per `.claude/docs/technical-preferences.md`).
12. No measurable memory growth over 5 minutes of play (4 GB ceiling).
13. Restaurant section (highest-density NPC scene) sustains 60 fps with full civilian + guard population.

## Accessibility (basic gate, before VS)

14. Settings menu opens, photosensitivity-toggle works, photosensitivity-warning modal appears at first boot.
15. `cutscene_dismiss` (Esc / B) silently drops during dismiss-gate (per Cutscenes CR-CMC-2.1 / FP-CMC-3) and honors after gate expiry.

---

## Adding a smoke check

When a new core system ships, append a numbered entry under the appropriate section.
Keep total ≤ 15 entries — if the list grows past that, promote items to integration
tests and remove from smoke. The 15-minute budget is the load-bearing constraint.
