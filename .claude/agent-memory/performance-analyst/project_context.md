---
name: Project Performance Context
description: The Paris Affair — stealth game, Eiffel Tower, 5 sections, 60fps/16.6ms budget, Godot 4.6
type: project
---

Game: "The Paris Affair" — solo-dev stealth comedy set in the Eiffel Tower.
5 sections: Plaza, lower scaffolds, restaurant, upper structure, bomb chamber.
Target: 60 fps / 16.6ms frame budget. Draw calls ≤ 1500. Memory ≤ 4 GB. PC minspec.
Engine: Godot 4.6, Forward+ (Vulkan/D3D12), Jolt physics.
Guard density: "patrol groups" implied, 3-6 simultaneous plausible; max-per-section not specified in GDD.
Stealth AI GDD reviewed 2026-04-21 — performance review identified NavigationAgent3D re-path churn and missing max-guard-count cap as the primary risks.

**Why:** Needed to establish a performance baseline before implementation begins to catch design-level footguns before they become code-level regressions.
**How to apply:** Use this as the performance baseline when future systems (Combat & Damage, Civilian AI) are reviewed. Cross-check against this if guard counts change.
