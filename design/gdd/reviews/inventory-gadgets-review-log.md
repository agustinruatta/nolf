# Inventory & Gadgets — Review Log

Revision history for `design/gdd/inventory-gadgets.md`. Each entry records a `/design-review` verdict, specialist consultation list, blocker/recommendation counts, and a summary of key findings + resolutions.

---

## Review — 2026-04-24 — Verdict: MAJOR REVISION NEEDED (revisions applied inline same session)

Scope signal: **L (possibly XL)** — creative-director flagged scope mislabel from M; 9 upstream deps, 6 formulas, 3 behavior scenes, 51 ACs (58 post-revision), ADR-0002 amendment required, 6+ cross-system contracts.

Specialists: game-designer, systems-designer, economy-designer, qa-lead, gameplay-programmer, godot-specialist, creative-director (senior synthesis).

Blocking items: **12** | Recommended: **~18**

### Summary of key findings from creative-director verdict

Issues clustered into four failure modes that together produced the MAJOR REVISION verdict:

1. **Fantasy/mechanics incoherence**: Vignette 2 promised "three BQA-issued gadgets" but CR-12 ships only 2; CR-15 pistol-dry "no auto-switch" contradicted the Crouched Swap "thumb already knows" anchor; Compact was a "wet" version of the §C.3-excluded remote spy camera.
2. **Economic instability** (three exploit vectors): Parfum dart-farm via unlimited activations + trivial gate (15+ free darts post-acquisition) breaks the dart anti-farm invariant; cache cap-overflow erases the observation-reward signal after Section 2; rifle self-sustaining economy if MLS places 2+ rifle carriers; medkit economy unspecified (5 medkits = Pillar-3 collapse).
3. **Formula defects**: F.3 single-drop always offsets 0.4 m east (counter increments unconditionally); F.3 counter reset at `_process` start but drops fire from `_physics_process` signals; F.6 `net_ghost = 0 LOCKED` false at any non-zero miss rate; CURIOSITY_BAIT cross-reference broken (SAI enum vs NoiseEvent type).
4. **Upstream API gaps**: `Combat.apply_fire_path` called by CR-14 but not defined in `combat-damage.md`; CR-11 save/restore three overlapping/contradictory patterns (wrong owner `SaveLoad` vs correct `LevelStreamingService`; mismatched method name `_serialize_inventory` vs LS-invoked restore semantics; schema mismatch with save-load.md's single-dict `ammo` vs CR-11's two-dict); Input GDD L91 contradicts Inventory CR-4 single-dispatch; `SkeletonModifier3D` IK scene-graph reachability (HandAnchor under Camera vs body Skeleton3D) unvalidated; autoload `_unhandled_input` pattern non-standard.

### User-approved design decisions (applied inline 2026-04-24)

1. **OQ-INV-1 Option B** — Parfum-KO drops nothing. Closes dart-farm vector, preserves break-even invariant, preserves Parfum tonal register (perfume bottle, not dart dispenser). Requires ADR-0002 amendment to extend `guard_incapacitated(guard: Node, cause: int)` and add `Combat.DamageType.MELEE_PARFUM`.
2. **CR-15 auto-cycle past dry weapons** — next `fire_primary` on dry weapon fires dry-click + initiates switch to next non-dry weapon. NOLF1 baseline, preserves Crouched Swap fantasy without UI-interrupt mid-gunfight.
3. **CR-5b "investigating guard claims the case"** — Cigarette Case is consumed when the investigating guard's SUSPICIOUS investigation resolves (queue_free on guard de-escalate). Eve can only retrieve if no guard has reached the investigation target. Preserves single-distraction-beat without enabling serial-distract-every-guard spam.
4. **Compact gains activation noise-event** — 3 m CURIOSITY_BAIT emission at Eve's position on activation (tied to diegetic mechanical whirr in §A.2). Peek is no longer "free perfect info"; aligns with Pillar 3 risk-weighted observation and resolves the "wet remote camera" concern.

### Specialist-default resolutions (applied without a user-decision widget)

- Vignette 2 rewritten to "two field devices, carefully chosen" (game-designer R-1 recommendation).
- Medkit ceiling set at 3 per mission (economy-designer recommendation; added to MLS forward-hook Coord item #5).
- Cache plan reduced from 11 to 8 pistol caches + 2 dart-only off-path caches (economy-designer contingency pre-applied, not playtest-gated).
- OQ-INV-4 tiebreaker changed from `body.name` alphabetic to `body.get_instance_id()` (godot-specialist V-2 + gameplay-programmer Issue 8).

### Structural / formula / upstream API fixes

- **F.3 single-drop bug**: gate offset on `_drop_index_this_tick > 0`; first drop spawns at guard position exactly.
- **F.3 reset boundary**: counter reset at `_physics_process` start, not `_process`.
- **F.6 `net_ghost` reframed**: "LOCKED at 0 only at ideal play"; realistic play (~10% miss + ~20% unreachable) produces mild depletion — Pillar-2 signal actually improves.
- **CR-11 save/restore** unified into 3 distinct paths with unambiguous method names:
  - `_on_restore_from_save(section_id, save_game, reason)` registered with `LevelStreamingService.register_restore_callback` — runs at LS step 9 on FORWARD/LOAD_FROM_SAVE/NEW_GAME.
  - `restore_weapon_ammo(snapshot, floor, max_cap)` called by Failure & Respawn on RESPAWN with ammo floor application (F.2).
  - `serialize_to(save_game)` called by Mission Scripting's `section_entered` autosave handler.
  - Defensive negative-clamp + `push_warning` added to `restore_weapon_ammo` for corrupt-save resilience.
- **CURIOSITY_BAIT cross-ref**: NoiseEvent type renamed to `BAIT_SOURCE`; `alert_cause` carries `AlertCause.CURIOSITY_BAIT` separately. Requires SAI GDD F.2b EVENT_WEIGHT table addition (Coord item #7).
- **CR-10 mesh-swap ordering**: hide + remove_child synchronously before `queue_free` to close W-OUTLINE-3 double-stencil-write window.
- **CR-16 blade+fire**: now emits blade-specific dry-click SFX (80 ms close-mic) via `weapon_dry_fire_click`. Consistent with E.9 dry-click convention.

### QA fixes

- AC-INV-9.1 count corrected 7 → 8 patterns (CR-17 table has 8 distinct grep targets).
- AC-INV-8.4 rewritten from unfalsifiable "0 ms per-frame CPU" to callable-presence spy assertion on `_process` + `_physics_process`.
- AC-INV-8.5 demoted from `[Logic]` sub-ms timing to `[Visual/Feel]` functional assertion + Polish-phase manual profiler evidence.
- AC-INV-8.3 integration cross-edge already correct.
- New ACs added (AC-INV-8.8 through AC-INV-8.14) covering E.43 race, E.44 two-slot-same-frame, F.2 dart + rifle floor paths, F.3 counter reset, Parfum-SAI-drop full chain integration, LS restore callback integration.

### New Coordination items (7-12)

- **#7** SAI GDD BAIT_SOURCE EVENT_WEIGHT addition.
- **#8** Combat GDD `apply_fire_path(weapon, position, direction)` method declaration — **BLOCKING**.
- **#9** Input GDD L91 single-dispatch clarification.
- **#10** save-load.md InventoryState schema touch-up (two-dict ammo + LS ownership of `register_restore_callback`).
- **#11** godot-specialist SkeletonModifier3D scene-graph verification (rifle IK).
- **#12** godot-specialist autoload `_unhandled_input` verification.

### Status after revision

Pre-sprint BLOCKING gates reduced from unresolvable to **closable with targeted amendments**:
- Coord items #2, #3, #7, #8, #9, #10 must close before sprint starts.
- Coord items #11, #12 are godot-specialist verification gates (small-scope).
- Coord items #1, #4, #5, #6 are non-blocking (forward-dep GDDs, narrative-safe).
- OQ-INV-1 RESOLVED; OQ-INV-3 still open but has Option-B default; OQ-INV-4 spec'd.

### Specialist disagreements surfaced (and adjudicated)

- **Which unlimited gadget is riskier — Compact or Case?** [game-designer] said Compact (information exploit); [economy-designer] said Case (economic exploit). Creative-director adjudicated as "both, on different axes" — fixes applied to both.
- **Pillar-2 fist-KO dominance** [economy-designer] — is a `combat-damage.md` concern (damage-tier economics), not inventory. Flagged for upstream; not blocking this GDD.

### Scope signal (post-revision)

Still **L** — revision did not reduce scope; if anything it added Coord items. Producer should re-estimate sprint effort and consider splitting into (a) core inventory + swap + save/restore, (b) gadget roster + behavior scenes, (c) HUD/VFX/SFX polish sprints.

### Prior verdict resolved: First review

### Next step

Skill did not recommend a fresh re-review after in-session revision (user elected "Revise now"). Consider `/design-review design/gdd/inventory-gadgets.md` in a fresh session as a sanity check before sprint planning — all revisions documented above should close the majority of original findings.
