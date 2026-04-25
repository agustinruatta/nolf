---
name: Feedback — Collaboration Style
description: How the user engages with UX design consultation on this project — high-context, implementation-ready specs preferred
type: feedback
---

The user delivers fully-scoped context briefs (locked upstream contracts, player fantasy, game pillars, exact signal names, color codes, pixel dimensions) and expects implementation-ready output in return — not exploratory questions about basics already decided.

**Why:** The project uses a multi-agent studio architecture where each agent's output is consumed directly by a GDD authoring workflow. The UX designer's §Detailed Design content goes directly into `design/gdd/` files. Vague or exploratory answers create rework.

**How to apply:** When given a fully-scoped brief with locked contracts, deliver concrete specs (anchor presets by exact Godot name, margin values in px at 1080p reference, state machine transitions, signal names, grep-enforced forbidden patterns) rather than asking clarifying questions about things already specified. Reserve questions for genuine ambiguities — flag them as numbered OQ-UX-N items at the end rather than blocking the spec delivery. The user picks from the spec; UX designer writes only on approval.
