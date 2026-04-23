# Combat & Damage

> **Status**: Revised (MAJOR REVISION pass 2 — 2026-04-22 — resolving 34 blockers from second /design-review)
> **Author**: user + design-system skill + /design-review specialists (game-designer, systems-designer, ai-programmer, economy-designer, qa-lead, godot-specialist, ux-designer, creative-director)
> **Last Updated**: 2026-04-22 (second revision pass)
> **Implements Pillars**: Pillar 3 — Stealth is Theatre, Not Punishment (core); Pillar 5 — Period Authenticity Over Modernization (core, with explicit boundary: governs diegetic fiction only per CD ruling — OQ-CD-13); Pillar 2 — Discovery Rewards Patience (load-bearing post-revision — restored via NOLF1-authentic drop rates, see §F.6); Pillar 1 — Comedy Without Punchlines (support via guard banter + environmental absurdity, NOT via Eve's physical actions — §V.8 Matt Helm anti-pattern primary)
> **Consumes ADRs**: ADR-0001 (Stencil), ADR-0002 (Signal Bus — amendment pending), ADR-0003 (Save Format), ADR-0006 (Collision Layers)
> **Depends on GDDs**: Player Character (✅ Approved — type-rename coordination pending), Stealth AI (✅ Approved — OQ-CD-1 amendment required), Audio (✅ Approved — type-rename coordination pending)
> **Depended on by (forward)**: Inventory & Gadgets, Mission & Level Scripting, Failure & Respawn, HUD Core, Settings & Accessibility (8 contracts via OQ-CD-12), Input (new Takedown action), Dialogue & Subtitles

> **Revision pass 2026-04-22 — key changes** (applied in response to second /design-review MAJOR REVISION NEEDED verdict — 6 specialist adversarial reviews + CD senior synthesis):
> - **UNCONSCIOUS semantics resolved — Transitional model**: dart → UNCONSCIOUS, `is_dead = false`, no `enemy_killed`. Subsequent lethal damage on UNCONSCIOUS guard → DEAD + `enemy_killed`. Re-dart on UNCONSCIOUS = no-op. Resolves E.1/E.3/CR-16/AC-CD-7.1 contradictions. `DamageType` lethality classified via new `is_lethal_damage_type()` helper. `MELEE_FIST` reclassified non-lethal (routes to UNCONSCIOUS).
> - **Blade vs pistol input — dedicated Takedown input**: new `Takedown` input action (kbd `F`, gamepad Y). Fire never triggers blade; Takedown never triggers pistol. Eliminates takedown-moment ambiguity. Input GDD forward-dep.
> - **Fists reworked**: `fist_base_damage 16 → 40` (safe range `[34, 50]`). 3-swing KO (was 7), 2.1 s cycle (was 4.9 s). Viable deliberate silent non-lethal KO AND ammo-dry fallback. No Pillar 1 slapstick carve-out — §V.8 Matt Helm anti-pattern primary.
> - **Design Test scope clarified**: §B table "Neither" row removed; Design Test governs diegetic fiction only; accessibility scaffolding has its own rationale (UI-1, V.6).
> - **Economy rebalanced — NOLF1-authentic**: `guard_drop_pistol_rounds = 3` (was 8). Break-even on paper, net-negative after real-play friction. Pillar 2 depletion pressure restored. New §F.6 per-section depletion math shown explicitly.
> - **Photosensitivity rate-gate**: new `hud_damage_flash_cooldown_ms = 333` fixed at 3 Hz WCAG ceiling. HUD Core coalesces rapid damage into single deferred flash. First-boot photosensitivity warning (OQ-CD-12 item 7).
> - **Crosshair resolution + contrast**: dot size now `0.19% × viewport_v` (3 px min / 12 px max); halo changed to `tri_band` (Parchment outer + Ink Black inner) so contrast holds against both light and dark backgrounds. Resolves ux-designer BLOCKER-2 + BLOCKER-3.
> - **Phantom APIs eliminated**: `ProjectileManager` removed (per-dart self-subscription to `respawn_triggered`). `guard.has_los_to_player()` + `guard.takedown_prompt_active()` public accessors declared in OQ-CD-1 SAI amendment (was phantom state-peek).
> - **Godot API corrections**: `query.exclude` now collects ALL owned CollisionObject3D RIDs (not just body — fixes guard self-headshot via head Area3D). Dart `_on_impact` handles both `body_entered` AND `area_entered` (fixes dart graze-headshot silent failure). Pre-fire occlusion check prevents silent dart-inside-wall. ShapeCast3D cone spec corrected (no ConeShape3D in Godot 4.6 — SphereShape3D sweep). CR-14 cross-signal FIFO claim removed (synchronous in-handler reset is the mechanism).
> - **F.1 output_range corrected**: `[34, 240]` default / `[34, 300]` safe-range ceiling.
> - **F.3 median claim corrected**: median angular deviation for `sqrt(randf())` on 13° cone is ~9.2° (analytically), not 7.5°. AC-CD-9.2 assertion updated to `[8.5°, 9.9°]`.
> - **Test infrastructure gate (AC-CD-19)**: `SignalRecorder.gd`, `WarningCapture.gd`, `.blocked-tests.md` manifest formally flagged as `/test-setup` sprint prerequisites.
> - **OQ-CD-13 reclassified**: Pillar 5 Boundary Clarification doc now BLOCKING for downstream GDDs (HUD State Signaling, Document Overlay, Menu, Settings & Accessibility). Does not block Combat approval.
> - **ADR-0002 amendment coordination**: type rename `CombatSystem → CombatSystemNode` flagged. PC-Approved + Audio-Approved GDDs reference old type name in frozen signatures; producer sequences the amendment landing with cross-GDD type-rename pass.
> - Numerous stale-value propagation fixes (AC-CD-12.1 reserves, AC-CD-12.2 variant, AC-CD-1.5 enum list, AC-CD-2.1 parametrized list, CR-8/AC-CD-13.1 crosshair size, F.1 output_range, F.3 median, E.21/E.23 prose).

## Overview

Combat & Damage is both the **damage-routing data layer** and **the system that enables fail-forward combat**. As infrastructure, it owns the `CombatSystem.DamageType` and `CombatSystem.DeathCause` enums plus the `damage_type_to_death_cause()` helper that Player Character (F.6), Stealth AI (per-guard `receive_damage`), Failure & Respawn (`player_died` cause routing), HUD Core (health readout), and Audio (threshold-triggered clock-tick) all consume. As a gameplay system, it defines how Eve's five MVP weapons — silenced pistol, takedown blade, dart gun, optional rifle, fists — deliver damage (hitscan for pistol/rifle, projectile for the dart, contact for blade/fists) and how guards return fire in their COMBAT state.

Combat is the **player-facing verb that Pillar 3 (Stealth is Theatre, Not Punishment) hinges on**: getting shot, and shooting back, opens dramatic possibility space rather than ending the run. The **takedown blade** is the quiet 1-shot lethal stealth tool; the **silenced pistol** is the gunfight weapon (3-shot body TTK, rewards headshot aim); the **dart gun** is the non-lethal alternative; **fists** exist as the last-resort edge-case fallback when everything else is dry. Period authenticity (Pillar 5) rules out modern combat UX — no hit markers, no damage-direction indicators, no damage-edge vignette — leaving default damage feedback to audio (hit SFX, ≤25 HP clock-tick), HUD numeric readout (driven by `player_health_changed`), and the camera dip already owned by Player Character. **Accessibility carve-out**: Pillar 5 governs diegetic period fiction, NOT accessibility scaffolding (creative-director ruling, 2026-04-21). Opt-in `Settings → Accessibility → Enhanced Hit Feedback` surfaces a non-diegetic damage-direction pulse for hearing-impaired players; default off. The system spans four ADRs: **ADR-0001** (muzzle-flash and tracer stencil tier), **ADR-0002** (the six frozen combat signals — `weapon_fired`, `player_damaged`, `player_health_changed`, `enemy_damaged`, `enemy_killed`, `player_died`), **ADR-0003** (save-format for per-weapon ammo + reserve state), and **ADR-0006** (`MASK_PROJECTILES` for projectile colliders and hitscan occluder masks).

**This GDD defines**: damage math (formulas, resistances = none at MVP), per-weapon fire/reload/spread behaviour, the damage-side contract for guard return fire (what happens when bullets reach Eve — not AI targeting/cover decisions, which belong to Stealth AI), lethal-takedown damage application (`apply_damage_to_actor`), `CombatSystem` enum ownership, and the six combat signal emit-sites. **This GDD does NOT define**: weapon entity specs, ammo pickup tables, or weapon-switch UI (Inventory & Gadgets); guard vocal reactions to being shot (Dialogue & Subtitles); HUD ammo counter or health-flash widget (HUD Core); respawn flow after `player_died` (Failure & Respawn); AI targeting / cover selection (Stealth AI); the Enhanced Hit Feedback accessibility toggle implementation (Settings & Accessibility — Combat defines the behavioral contract only).

## Player Fantasy

**"Composed Removal of an Obstacle."** Eve has been ghosting a villa for eight minutes. A guard rounds the corner she mistimed. She is already on him — one silent blade stroke from behind, a 200 ms exhale, and she steps over him toward the next door. The scene did not end — it escalated. Later, same mission, worse luck: three guards at once, HP dropping, the clock-tick starts somewhere between her ears, the gallery light goes Bass-poster red-and-black, and she reloads the silenced pistol behind a marble plinth with the same composure she had in the foyer. **Eve does not change register. The world around her does.**

This is the **Deadpan Witness framing of Player Character (Section B) continued into its combat register.** Eve is still not panicking, still not quipping, still not rolling. She does not scream when hit. She might exhale. The HUD number tells her she is at 24 HP and refuses to flash, pulse, or plead; the clock-tick is an analog 1960s second-hand, dry and mechanical — not a red vignette and not a "LOW HEALTH" warning. The *absence* of modern combat feedback is itself the felt presence of the period. The HUD is characterized the same way she is: restrained, composed, unbothered.

### Weapon-register mapping (Composed Removal test applied per weapon)

| Weapon | Register it serves | Composed Removal test |
|---|---|---|
| **Takedown blade** (stealth 1-shot lethal) | Composed — the silent blade is the *archetype* of composed removal. One action, one obstacle removed, scene continues. | **Pass** |
| **Silenced pistol** (gunfight, 3-shot TTK) | Composed — muffled pops, deliberate aim. The 3-shot TTK rewards headshot discipline (1 head + 1 body = dead) without collapsing into twitch-shooter binary. | **Pass** |
| **Dart gun** (non-lethal projectile) | Composed — one compressed-air puff, one arc, silence. | **Pass** |
| **Rifle** (rare pickup, 1-shot body) | Tonal exception — a deliberate chosen moment. Eve picks the rifle up in specific mission beats (§D.3, §D.5); it is the "escalation has reached the rooftop" register, not everyday combat. Scope zoom dramatizes the decision to use it. | **Pass with carve-out** (see §F.1 note) |
| **Fists** (deliberate silent non-lethal KO, 3-swing / ~2.1 s cycle) | Composed — fists are now a viable planned tool: 2–3 decisive close-range strikes to an unaware guard. Not slapstick — paced between the blade's 1-shot and the dart gun's ranged projectile. Serves two use cases: (1) deliberate melee non-lethal KO when ranged darts are inappropriate, (2) emergency fallback when everything else is dry. §V.8 Matt Helm cautionary reference retained as the *ceiling* on fist theatrics — fists must never read as a brawl. | **Pass** |

**Fists role (2026-04-22 revision).** Per user direction: fists serve deliberate silent non-lethal KO (close-range, when dart isn't the right tool) AND ammo-dry fallback. The prior 7-swing / 4.9 s cycle read as Matt Helm slapstick and was cut. The new 3-swing cycle (`fist_base_damage = 40`, ceil(100/40) = 3 swings × 0.7 s = 2.1 s per KO) keeps fists within Composed Removal — paced as three deliberate strikes, not a brawl. §V.8's cautionary reference still applies to *repetitive* punching (if tuning ever forced 4+ swings, the anti-pattern would re-emerge); the 2–3-swing window is the safe band.

### Pillar alignment

- **Pillar 3 (Stealth is Theatre, Not Punishment)** — load-bearing. Combat is fail-forward. Getting forced into a shootout does not end the run; it *escalates the scene*. The trigger pull is the scene shifting register, not a fail state breaking in. COMBAT de-escalates back to SEARCHING, and SEARCHING back to SUSPICIOUS; nothing is permanent except a body.
- **Pillar 5 (Period Authenticity Over Modernization)** — the *mechanism* by which Pillar 3 lands. Period-authentic restraint (no vignette, no hit markers, no damage-direction indicators, no kill cam) is what keeps combat legible as *theatre* rather than as punishment. A red damage vignette would make every hit read as "you're losing"; its absence makes every hit read as "the scene is getting louder."
- **Pillar 1 (Comedy Without Punchlines)** — supporting. Comedy lands through guard reactions, guard banter, and the absurd tableau of 1960s spy violence in a museum gallery. **Never through Eve being cool, and never through Eve's physical actions being goofy** — §V.8's Matt Helm cautionary reference is primary: if combat reads as slapstick, it has left this pillar's register. Fists in particular stay within the pillar only while they remain 2–3 decisive strikes (see §F.1 fist tuning).
- **Pillar 2 (Discovery Rewards Patience)** — load-bearing (restored post-2026-04-22). Guard ammo drops are **net-negative for Aggressive** (drop 3 rounds per lethal kill vs 3-shot body TTK — break-even at best, negative when including reload inefficiency), which re-establishes ammo depletion as a real Pillar 2 lever. The patient observer's path still beats the shootout path: observation discovers caches, darts keep the non-lethal premium, and combat accumulates a cost — the shootout drains reserves. NOLF1-authentic. See §F.6 economy rewrite.

### Tonal touchstones

- *The Avengers* (1960s ITV) — Emma Peel's unflappability as the dramatic through-line; the genre's commitment to letting music and cutting do the escalation work while the protagonist remains the still point.
- *No One Lives Forever* 1 (2000) — Cate Archer when things go sideways; combat flowing continuously out of stealth rather than breaking it.
- *Our Man Flint* (1966) — Flint's restaurant fight as the archetype of composed violence in a public space.
- Saul Bass title design — restraint as style; the *absence* of visual noise is the statement.

### Design test

**Does this feature change Eve's register, or the world's around her?**

| Candidate feature | Register changed | Verdict |
|---|---|---|
| Red damage vignette | Eve's (suggests she's losing composure) | **Cut** |
| Clock-tick loop at ≤25 HP | World's (environment becomes audibly tense) | **Keep** |
| Hit marker crosshair | Eve's (gives her superhuman feedback she shouldn't have) | **Cut** |
| Silenced-pistol mechanical ratchet | World's (weapon has period texture) | **Keep** |
| "LOW HEALTH" text warning | Eve's (the HUD is pleading with her) | **Cut** |
| Guard grunt-and-crumple reaction | World's (the obstacle reacts to its removal) | **Keep** |

**Scope of the Design Test** (revised 2026-04-22 per CD ruling). The Design Test governs **diegetic period fiction** — elements Eve could plausibly experience, perceive, or be portrayed by within the 1960s spy fiction the game inhabits. It does **NOT** govern accessibility scaffolding (crosshair, damage-flash duration, colorblind cues, Enhanced Hit Feedback). Those are player-accommodation affordances, decided on accessibility grounds, not diegetic grounds. Accessibility surfaces have their own rationale (see UI-1, V.6, UI-5) and are not in this test's domain. Previous "Neither" rows were a symptom of trying to force accessibility items through a diegetic test — they belong outside the test.

## Detailed Design

### C.1 Core Rules

**CR-1 Damage routing.** All damage flows through `CombatSystem.apply_damage_to_actor(actor, amount, source, damage_type)`. The helper duck-types on the receiver (`actor.has_method("apply_damage")` → Eve's F.6 path; `actor.has_method("receive_damage")` → guard mirror path). Invalid actors (`is_instance_valid(actor) == false`) `push_warning` and return. **Callers MUST NOT mutate actor health directly.**

**CR-2 Signal emit-site ownership.** After `actor.receive_damage(...)` returns (with its new `-> bool is_dead` return — see OQ-CD-1), CombatSystem emits `enemy_damaged(actor, amount, source)`, then if `is_dead == true` also `enemy_killed(actor, source)` in the same call stack. Deterministic order: mutation → `enemy_damaged` → `enemy_killed`. Eve's path emits `player_damaged` → `player_health_changed` → optional `player_died` (owned by PC F.6, NOT re-emitted here).

**CR-3 Weapon roster.** Revised 2026-04-22 — fists reworked to 3-swing deliberate KO per user direction; blade bound to dedicated Takedown input.

| Weapon | Class | Delivery | Lethal? | ADS | Context | Input | Audio SFX |
|---|---|---|---|---|---|---|---|
| **Takedown blade** | Stealth tool (lethal) | Melee contact (stealth-only) | Yes (1-shot) | No | Gated by SAI contact-prompt in PATROL/NOTICED/SUSPICIOUS | **`Takedown` input** (NEW, dedicated — NOT `Fire`) | Faint blade draw + muffled contact (~180 ms) |
| Silenced pistol | Primary (gunfight) | Hitscan | Yes (3-shot body / 2-shot head) | No | Gunfights only — NOT used for takedowns | `Fire` (always unambiguously pistol) | Period-accurate ~110 dB suppressed pop + mechanical ratchet |
| Dart gun | Primary (non-lethal ranged) | Projectile | No (KO) | No | Any state — quiet | `Fire` (when equipped) | Compressed-air puff + dart whistle (~400 ms) |
| Rifle | Rare pickup | Hitscan | Yes (1-shot body) | **Yes (1.5× zoom)** | Chosen moments (§D.3, §D.5) — tonal exception | `Fire` (when equipped) | Louder single-shot report + bolt action |
| **Fists** *(reworked 2026-04-22)* | Melee non-lethal (deliberate or fallback) | Melee cone | No (KO) | No | Two use cases: deliberate silent close-range KO; ammo-dry fallback | `Melee` (existing) | Cloth impact + knuckle thud |

**Dedicated Takedown input contract (NEW, 2026-04-22 per user decision)**:
- Takedown is a distinct input action (default keyboard: `F`; default gamepad: face-button Y/△). Binding owned by Input GDD (forward-dep update required).
- Takedown input is **only live** when SAI's context prompt is active (guard is in PATROL/NOTICED/SUSPICIOUS AND player is behind/adjacent within ~1.5 m AND guard LOS does not include player). The context prompt UI surfaces the Takedown input glyph; if the prompt is not visible, Takedown input does nothing (dry input — no audio cue, no animation).
- `Fire` input is **never** a takedown trigger. Pressing Fire while the context prompt is live still fires the pistol (or dart, whichever is equipped). This is intentional: the two inputs are unambiguous, so the player cannot accidentally break stealth by mashing Fire.
- The blade cannot be drawn outside the Takedown context. It is not switchable from the weapon wheel; there is no "blade-equipped" state. Takedown input routes directly to SAI's `receive_takedown(STEALTH_BLADE, eve)` → CR-15 damage delegation. Resolves the prior input-ambiguity blocker.

**Weapon identity separation**:
- **Takedown blade** — silent lethal, 1-shot, gated by Takedown input + context prompt. No ammo.
- **Fists** — silent non-lethal, 3-swing ~2.1 s KO, Melee input, always available. Viable deliberate tool (Ghost players can fist-KO in corridors where dart isn't safe) AND ammo-dry fallback.
- **Silenced pistol** — gunfight only, 3-shot body TTK, Fire input. No takedown behavior.
- **Dart gun** — non-lethal ranged KO, 1-shot, Fire input.
- **Rifle** — 1-shot body lethal, chosen-moment tonal exception.

Weapon *entity* ownership (Resource, mesh, ammo UI) belongs to Inventory & Gadgets (forward dep); Combat owns fire/damage math + post-fire signal emits. **Inventory forward dep** (revised 2026-04-22): blade Resource schema (no ammo, `base_damage = 100`, `damage_type = DamageType.MELEE_BLADE`, `fire_rate_sec = 0.0` with inline comment "context-gated single-use per takedown prompt — no cooldown beyond animation duration"); no separate blade-draw input handler (use Takedown input directly); fists have Melee input + 0.7 s cycle cooldown already specified in CR-7.

**CR-4 Flat damage model.** Each weapon has one base damage number (final values in §D). No distance falloff. No armor/resistance. **Headshots on guards** deliver 2× base damage (multiplier computed internally; `enemy_damaged.amount` is post-multiplier). **No headshot damage on Eve** — guards always hit body-only.

**CR-5 Hitscan-then-perturb accuracy** (revised 2026-04-22 — guard self-exclusion expanded to cover all owned CollisionObject3D RIDs, not just body). Hitscan uses:
```gdscript
var query := PhysicsRayQueryParameters3D.create(from, to)
query.collide_with_areas = true       # REQUIRED — headshot Area3D detection (F.5) depends on this
query.collide_with_bodies = true      # default, explicit for clarity
query.exclude = _collect_self_rids(shooter)  # body RID + head Area3D RID + any child CollisionObject3D
query.collision_mask = _build_mask_for_shooter(shooter)
var result := space_state.intersect_ray(query)
```
Aim vector is perturbed by a random offset inside a cone whose half-angle depends on shooter state + range (formula in §D F.2). This preserves environmental audio feedback: a near-miss hits the wall and the wall-impact SFX fires. Eve-fired shots cast against `MASK_AI | MASK_WORLD`; guard-fired shots cast against `MASK_WORLD | MASK_AI | MASK_PLAYER` (AI included iff `GUARD_FRIENDLY_FIRE_ENABLED == true`). Neither uses `MASK_PROJECTILES`. The `collide_with_areas = true` flag is MANDATORY — without it, `intersect_ray` returns only `CollisionObject3D` bodies, and the head `Area3D` (F.5) is silently skipped.

**Guard self-exclusion (revised 2026-04-22 — multi-RID)**: since `collide_with_areas = true` exposes the head `Area3D` to hitscan, a guard's own hitscan in friendly-fire mode could intersect its own head `Area3D` (a distinct `CollisionObject3D` with its own RID, separate from the body capsule's RID). The exclusion list must cover **every owned collision object**:

```gdscript
static func _collect_self_rids(shooter: Node) -> Array[RID]:
    var rids: Array[RID] = []
    if shooter is CollisionObject3D:
        rids.append(shooter.get_rid())
    for child in shooter.find_children("*", "CollisionObject3D", true, false):
        # includes BoneAttachment3D → Area3D("headshot_zone") and any future child colliders
        rids.append((child as CollisionObject3D).get_rid())
    return rids
```

This resolves godot-specialist B1 + ai-programmer F7: without it, a guard in friendly-fire mode can self-headshot at the ray origin. AC-CD-18 (new) asserts this invariant (see §Acceptance Criteria).

**Mask rebuild is per-shot, not cached**: `_build_mask_for_shooter(shooter)` constructs a local `int` mask per fire call, reading the current value of `SectionConfig.guard_friendly_fire_enabled` at construction time. No mask is stored as a cached field on the guard. If Mission Scripting flips the config between shots, the next shot honors the new value (resolves ai-programmer Finding 10).

**Mask rebuild is per-shot, not cached**: `_build_mask_for_shooter(shooter)` constructs a local `int` mask per fire call, reading the current value of `SectionConfig.guard_friendly_fire_enabled` at construction time. No mask is stored as a cached field on the guard. If Mission Scripting flips the config between shots, the next shot honors the new value (resolves ai-programmer Finding 10).

**CR-6 Projectile dart** (revised 2026-04-21 — wall-hit filter + double-hit guard). `RigidBody3D` on `LAYER_PROJECTILES`, CCD on, travel speed 20 m/s. Visible mesh at tier 3 LIGHT outline (per Art Bible §8K amendment). Dart maintains a `_has_impacted: bool = false` flag to guard against same-tick double `body_entered` (e.g. body + head Area3D overlap).

```gdscript
func _on_body_entered(body: Node) -> void:
    if _has_impacted:
        return  # defensive: ignore second same-tick callback
    _has_impacted = true

    if body.is_in_group("world") or body is StaticBody3D:
        # Wall / floor / static geometry — no damage call, just free. Audio subscribes
        # to body_entered separately for wall-impact SFX.
        queue_free()
        return

    if body.has_method("apply_damage") or body.has_method("receive_damage"):
        Combat.apply_damage_to_actor(body, DART_DAMAGE, self, CombatSystemNode.DamageType.DART_TRANQUILISER)
        queue_free()
        return

    # Unknown body type — warn (genuine anomaly, not a normal wall miss).
    push_warning("Dart hit unknown body type: %s" % body.name)
    queue_free()
```

Resolves /design-review: dart-on-wall no longer spams `push_warning` (world geometry is filtered early); same-tick double-hit (body + head Area3D) is suppressed by `_has_impacted` flag. Darts exiting map bounds or living > 4 s auto-free. **Also handles Area3D-only contact (revised 2026-04-22 — godot-specialist B8 fix)**: the dart scene connects BOTH `body_entered` (physics body contact) AND `area_entered` (Area3D overlap) to the same `_on_impact(other: Node)` handler. In Godot 4.6, a `RigidBody3D` overlapping an `Area3D` fires `area_entered` on the RigidBody3D side; if the dart grazes only the head `Area3D` without touching the body capsule, `body_entered` never fires but `area_entered` does. The shared handler ensures damage applies. `_has_impacted` still guards against double-fire when both signals trigger same-tick.

**Dart wall-spawn edge case (revised 2026-04-22 — godot-specialist B14 fix)**: if Eve is flush against cover, the spawn offset (`camera.global_position + aim_direction × 0.5`, F.4) can place the dart *inside* wall geometry. The dart's `_on_impact` fires at spawn time with `body is StaticBody3D`, and the dart frees silently with no SFX, no damage, no player feedback. To prevent this silent failure, Combat's fire routine performs a `PhysicsRayQueryParameters3D.create(camera_pos, spawn_pos)` pre-check against `MASK_WORLD`; if occluded, the shot is cancelled at the fire site — a dry-fire click SFX plays (Audio-owned), no dart is spawned, no ammo is consumed, and `weapon_fired` does NOT emit. Documented in E.41 below.

**CR-7 Melee contact (fists).** Revised 2026-04-22 — 3-swing KO cycle per user decision; primitive correction per godot-specialist B9.

Fists use a forward-sweep detection volume from camera origin:
- Godot 4.6 has no `ConeShape3D`. The detection volume is a `SphereShape3D` of radius 0.35 m swept from camera origin along the forward axis for 0.7 m via `ShapeCast3D.target_position = -camera.basis.z * 0.7`. The spherical swept volume approximates a 30° half-angle cone at 0.7 m reach within ±0.1 m tolerance — acceptable for melee feel and computationally cheap.
- 1 hit per swing (OQ-CD-4 gates multi-target selection: nearest-collider sort pending prototype).
- Windup 0.3 s → hit resolves on windup-end frame → recovery 0.4 s → total cycle 0.7 s.
- KO threshold: 3 swings at `fist_base_damage = 40` → 120 HP cumulative against a 100 HP guard. Per-KO time budget: 2.1 s (down from 4.9 s). Viable as deliberate silent non-lethal KO per CR-3 revised role.

**CR-8 Crosshair.** Revised 2026-04-22 to resolve ux-designer BLOCKER-2 (resolution scaling) and BLOCKER-3 (contrast claim). See UI-1 for complete specification — Combat describes behavior; HUD Core renders.

- Dot color Ink Black `#1A1A1A`, scaled to **0.19% of viewport vertical resolution** (approx. 4 px at 1080p, 5 px at 1440p, 8 px at 4K), clamped min 3 px max 12 px.
- Halo stroke 1 physical pixel, Parchment `#E8DFC8` outer + Ink Black `#1A1A1A` inner 1 px (tri-band, not single-band): this guarantees ≥3:1 contrast against BOTH dark interiors (Parchment band dominates) AND light exterior/sepia backgrounds (Ink Black inner band dominates). Halo contrast claim against "any gameplay background" is now empirically supported.
- **Enabled by default.** Disableable via `Settings → Accessibility → Crosshair` AND `Settings → HUD → Crosshair` (single source of truth, two discovery paths — UI-1 + UI-6).
- Does NOT expand/contract, does NOT change color on enemy hover, does NOT hit-marker flash.
- **Accessibility affordance, not diegetic.** Not subject to the §B Design Test. See UI-1 rationale.

**CR-9 Aim-down-sights (rifle only).** `Aim` input hold tweens camera FOV 85° → 55° over 200 ms (ease-out), fades in an optical-scope reticle overlay, reduces muzzle sway 50%, halves accuracy spread cone. Release reverses over 150 ms. ADS is cancelled by: reloading, weapon-switch, or damage ≥ `interact_damage_cancel_threshold` (10 HP). Pistol / dart / fists have no ADS analog. **Vestibular comfort note**: 150°/s FOV rate at default 200 ms exceeds the 90°/s reference threshold for motion-sensitive players; forward-dep `ads_tween_duration_multiplier` in Settings & Accessibility GDD (OQ-CD-12 item 5) exposes a slower tween option.

**CR-10 Fire input gating.** Fire blocked while `_is_reloading || _is_switching_weapon || _is_fist_swinging || _is_hand_busy || InputContext != GAMEPLAY`. No fire-queue on gated input — press is dropped. **Takedown input (revised 2026-04-22)** is gated separately: Takedown fires only when (a) SAI emits a context-prompt signal indicating an eligible unaware guard within ~1.5 m in front/behind arc AND (b) `InputContext == GAMEPLAY`. Takedown and Fire are independent bindings — pressing Fire never triggers Takedown and vice versa (per CR-3 revised dedicated-input contract). Melee input (fists) gates on `_is_fist_swinging == false` only; Melee is always available when not mid-cycle.

**CR-11 Ammo scarcity (Pillar 2 enforcement).** Eve starts each mission with limited reserves per weapon (final values §D). Guards yield a **net-negative** drop (revised 2026-04-22 — NOLF1-authentic): 3 pistol rounds per lethal kill (below 3-shot TTK cost when reload overhead included), 3 rifle rounds partial, 1 dart on dart-KO (break-even), 0 darts on fist-KO (fist-farm closed). Aggressive depletes progressively across the mission. Fall-through when primary runs dry: pistol → fists (fists are now a viable non-lethal melee tool AND the ammo-dry fallback; dart-gun route remains valid iff dart reserves remain).

**CR-12 Guard return-fire cadence** (revised 2026-04-21 — Combat owns all return-fire state defensively; no SAI contract obligations).

Return-fire is implemented as a per-guard `GuardFireController` scene-attached node owned by Combat (not SAI). The controller subscribes to guard state changes via Signal Bus and manages its own timers. Combat does NOT impose obligations on SAI's state-machine handlers.

**Fire modes:**

| Mode | Cadence | Cap | State gate |
|---|---|---|---|
| First-shot delay after COMBAT entry | 0.65 s | — | Starts on `guard.alert_state_changed(COMBAT)` signal |
| Direct LOS fire | 1 shot every 1.4 s | — | Active while guard's last LOS check (from SAI F.1 cache) = visible |
| Suppression fire (sight lost) | 1 shot every 2.8 s | Max 3 suppression shots per LOS-loss cycle | Active while LOS cache = occluded AND suppression_count < 3 |

**State ownership (resolves LOS-to-suppression transition ambiguity)**: `GuardFireController` holds its own internal state `FireMode ∈ {IDLE, DRAW, LOS, SUPPRESSION, CAPPED}`. Transitions:

- `IDLE → DRAW` on COMBAT entry signal, `DRAW → LOS` on first-shot-delay timeout
- `LOS ⇄ SUPPRESSION` based on SAI's public LOS accessor (see LOS interface below)
- `SUPPRESSION → CAPPED` when `suppression_count == 3`; CAPPED is silent (no further shots) until LOS reacquired
- `CAPPED → LOS` resets `suppression_count = 0` on LOS reacquisition (fresh suppression cycle if LOS lost again)
- Any → `IDLE` on `guard.alert_state_changed(state != COMBAT)` OR `is_instance_valid(self) == false` OR `guard.alert_state == DEAD | UNCONSCIOUS`. **`IDLE` entry via this path MUST set `suppression_count = 0` AND stop both timers** (revised 2026-04-22 per ai-programmer F1 — prevents stale count carrying across COMBAT→SEARCHING→COMBAT bounces).

**LOS interface — SAI public accessor (revised 2026-04-22 per ai-programmer F3, godot-specialist B3-context)**: SAI must expose `guard.has_los_to_player() -> bool` as a public method that returns the guard's most recent F.1 perception cache result (cache-hit path, no new raycast). This resolves the previously-phantom "SAI's cached LOS result" reference. The accessor is stale-safe — SAI's F.1 cache is frame-invalidated, so reading at idle tick frequency produces at most 1-physics-frame lag, acceptable for return-fire cadence. Added to OQ-CD-1 SAI amendment scope.

**Defensive gate (replaces E.24's SAI obligation)**: every timer callback begins with:
```gdscript
if not is_instance_valid(guard) or guard.current_alert_state in [AlertState.DEAD, AlertState.UNCONSCIOUS]:
    _fire_mode = FireMode.IDLE
    _suppression_count = 0
    _los_timer.stop()
    _suppression_timer.stop()
    return
```
This means: if a guard dies or is dart-KO'd, the fire controller silently cleans up on its next scheduled tick. No unilateral obligation on SAI's DEAD-entry handler.

**Projectile cleanup on respawn (revised 2026-04-22 — no central ProjectileManager; self-cleanup pattern)**: `ProjectileManager` was a phantom reference in the prior revision and is removed. Instead, each dart `RigidBody3D` self-subscribes to `Events.respawn_triggered` in its own `_ready()` (`Events.respawn_triggered.connect(_on_respawn)`), disconnects in `_exit_tree()`, and the handler calls `queue_free()` on itself. GuardFireController likewise subscribes to `Events.respawn_triggered` directly and, on signal, transitions itself to IDLE and stops its own timers. No central registry is needed. `GuardFireController._exit_tree()` MUST disconnect the subscription to avoid dangling autoload references (godot-specialist B12).

Timers are per-guard `Timer` nodes on the idle tick (not `_physics_process`). Timer node count scales with guard-count-in-COMBAT (typically 0–3 simultaneous at MVP guard density). **Performance budget note (revised 2026-04-22 per ai-programmer F12)**: prior draft consumed SAI's AC-SAI-4.4 `1 ms signals+state` sub-budget unilaterally. Combat's per-guard timer cost is now declared as an INDEPENDENT Combat budget line of **0.3 ms mean / 0.5 ms P95** at 3-guard-COMBAT density, measured against the total frame budget (16.6 ms), NOT inside SAI's sub-budget. Cross-system budget reconciliation **CLOSED 2026-04-23 by ADR-0008 Slot #2**: SAI 6.0 ms + GuardFireController 0.5 ms P95 consolidated into a single 6.5 ms guard-systems envelope (same reference scene, same CI gate).

**CR-13 Guard friendly fire.** `GUARD_FRIENDLY_FIRE_ENABLED` (default `true`). When true, a guard's hitscan ray striking another guard calls that guard's `receive_damage` at base damage (no 2× — no guard-on-guard headshots). Per-section override available via the section's `SectionConfig` resource (Mission Scripting's authoring concern). When false, guard-fired rays cast with `collision_mask = MASK_WORLD | MASK_PLAYER` only (AI mask excluded).

**CR-14 Return-fire timer handshake (cross-system contract with SAI).** Each guard subscribes to `Events.player_damaged`. Handler resets the guard's `_combat_lost_target_timer` (owned by SAI — defined in SAI Tuning Knobs as `COMBAT_LOST_TARGET_SEC`, default 8.0 s) iff `source == self AND current_alert_state == COMBAT`. This is the sole mechanism by which "Eve took damage from me" feeds SAI's COMBAT → SEARCHING de-escalation logic. Combat does NOT call guard methods directly — the signal bus is the coupling.

**Synchronous reset discipline** (revised 2026-04-22 — godot-specialist B11 + ai-programmer F4 fix): the prior "connect `Events.player_damaged` before `timer.timeout` and Godot FIFO guarantees ordering" claim was incorrect. Godot 4.6's FIFO ordering is **per-signal**, not cross-signal; it cannot guarantee that `player_damaged` handlers run before an unrelated `Timer.timeout` in the same frame. The correct mechanism is synchronous in-handler reset:

- Guard's `_on_player_damaged(amount, source, _is_critical)` handler calls `_combat_lost_target_timer.stop(); _combat_lost_target_timer.start(COMBAT_LOST_TARGET_SEC)` IMMEDIATELY (no await, no deferred call, no tween).
- Because Godot signal dispatch is synchronous within the emit call stack, the reset completes before emit returns. Any `timer.timeout` scheduled for the same frame would fire later in the frame (timers evaluate during their own process tick); by then the timer has been restarted to its full duration and no timeout fires.
- There is no cross-signal ordering dependency. Connection order of `player_damaged` vs `timer.timeout` is irrelevant.
- This is a SAI implementation note — but no SAI cross-domain contract is created; the guarantee is a property of Godot's synchronous emit, not of connection sequencing.

**CR-15 Takedown lethal-damage delegation** (revised 2026-04-22 — Takedown input path). When the player presses the dedicated `Takedown` input (CR-3) while SAI's context prompt is live, SAI's `receive_takedown(STEALTH_BLADE, eve)` handler fires. SAI calls `Combat.apply_damage_to_actor(self, blade_takedown_damage=100, eve, DamageType.MELEE_BLADE)`. `apply_damage_to_actor` invokes `guard.receive_damage(100, ...)` (synchronous), which reduces HP to 0, transitions `current_alert_state = DEAD` (synchronous state mutation before return), and returns `is_dead = true`. Combat then emits `enemy_damaged(guard, 100, eve)` followed by `enemy_killed(guard, eve)` in the same call stack. The silenced pistol is NOT a takedown-delegation target; it is gunfight-only. `receive_takedown(SILENCED_PISTOL, ...)` is removed from the takedown-type enumeration — SAI amendment OQ-CD-1 item 3. **Call-stack synchronicity (2026-04-22 clarification per systems-designer F8)**: SAI's DEAD-state transition inside `receive_damage` must be synchronous (state field mutation, not deferred) so `GuardFireController`'s defensive gate (reading `current_alert_state`) sees DEAD on its next tick. Declared in OQ-CD-1 amendment.

**CR-16 UNCONSCIOUS state consequence (revised 2026-04-22 — Transitional model per user decision; non-lethal DamageTypes routing).** Guards reaching 0 HP via a **non-lethal DamageType** (`DART_TRANQUILISER` OR `MELEE_FIST`) transition to `SAI.AlertState.UNCONSCIOUS` (6th state, SAI GDD amendment OQ-CD-1). Guards reaching 0 HP via any lethal DamageType (`BULLET`, `MELEE_BLADE`, `FALL_OUT_OF_BOUNDS`) transition to `SAI.AlertState.DEAD`. UNCONSCIOUS guards: no perception, no vocal, body remains at final pose, outline tier MEDIUM persists.

**Lethality classification (CR-16 extension)**: the `DamageType` enum is accompanied by a lethality-bit helper:
```gdscript
static func is_lethal_damage_type(damage_type: DamageType) -> bool:
    return damage_type in [
        DamageType.BULLET,
        DamageType.MELEE_BLADE,
        DamageType.FALL_OUT_OF_BOUNDS,
        DamageType.TEST,  # conservative: test path mimics lethal for AC-5 compatibility
    ]
```
`DART_TRANQUILISER` and `MELEE_FIST` are non-lethal. SAI's `receive_damage` reads `Combat.is_lethal_damage_type(damage_type)` to decide DEAD vs UNCONSCIOUS. This makes fists a viable deliberate non-lethal KO tool per CR-3 revised role while keeping MELEE_BLADE firmly lethal for stealth kills.

**Signal semantics on UNCONSCIOUS entry**: `receive_damage(150, eve, DART_TRANQUILISER)` sets HP = 0 (or clamped floor), transitions state to UNCONSCIOUS, **returns `is_dead = false`**. Rationale: `is_dead` in the `apply_damage_to_actor` contract means "this damage call produced a death-equivalent state that should fire `enemy_killed`." UNCONSCIOUS is NOT death — Mission Scripting's "no-lethals" objective must distinguish it. Combat's C.5 therefore emits `enemy_damaged` but NOT `enemy_killed` on dart-KO entry. AC-CD-7.1 unchanged in its assertion.

**Subsequent damage on UNCONSCIOUS guard (Transitional model — resolves E.1 vs E.3 contradiction)**: an UNCONSCIOUS guard struck by lethal DamageType (BULLET, MELEE_BLADE, MELEE_FIST, rifle, fall) transitions UNCONSCIOUS → DEAD. `receive_damage` returns `is_dead = true`; `apply_damage_to_actor` emits `enemy_damaged` then `enemy_killed`. E.1's "DEAD/UNCONSCIOUS gate" rule is tightened: **only DEAD is fully terminal (no-op on further damage). UNCONSCIOUS accepts lethal-DamageType further damage and transitions to DEAD; UNCONSCIOUS accepts further DART_TRANQUILISER damage as no-op (guard is already fully KO'd; re-darting is idempotent).**

**Gameplay consequence**: Mission Scripting's "eliminate all hostiles" objective counts DEAD via `enemy_killed` subscription. UNCONSCIOUS guards don't complete that objective — consistent with non-lethal intent. A player who KOs a guard with a dart and then shoots the corpse triggers UNCONSCIOUS → DEAD, completes the elimination, and loses the "no-lethals" achievement. This preserves narrative distinction AND lets mission objectives count both lethal paths cleanly.

### C.2 Player Combat State (booleans, no enum)

Eve has no combat-state enum. Combat state is three booleans that compose freely with PC's movement state:

```gdscript
var _is_reloading: bool = false
var _is_switching_weapon: bool = false
var _is_fist_swinging: bool = false
```

- `_is_aiming` is NOT a boolean — it's the live state of the `Aim` input (held vs released), polled from PC's input system per-frame.
- `_is_firing` is NOT a boolean — it's implied by "fire-rate cooldown timer is running."

**Fire input gate composition:** `can_fire = not (_is_reloading or _is_switching_weapon or _is_fist_swinging or _is_hand_busy or InputContext != GAMEPLAY)`.

**Reload rules.** Duration per weapon (§D). Cancellable by: weapon-switch input (cancels reload, starts switch), or damage ≥ 10 HP (matches PC's `interact_damage_cancel_threshold` — consistent cancel policy). A completed reload tops up the magazine from the reserve.

**Weapon-switch rules.** Duration 0.35 s holster-draw blend. **Not cancellable** once started (prevents input-spam cycling). Damage during switch does NOT cancel; the switch completes on schedule.

**Fist-swing rules.** Windup 0.3 s → hit resolves → recovery 0.4 s → total cycle 0.7 s. **Not cancellable** once windup begins. Damage during swing does NOT cancel. Fist-swinging locks weapon-switch until recovery completes. Per CR-7 (2026-04-22 revision), KO threshold is 3 swings at `fist_base_damage = 40`; per-KO time 2.1 s total.

**Takedown-input gating (NEW 2026-04-22).** The `Takedown` input (CR-3 revised) is blocked while any of: `_is_reloading || _is_switching_weapon || _is_fist_swinging || _is_hand_busy || InputContext != GAMEPLAY`. Additionally gated on SAI's context-prompt being live (i.e., an eligible guard is in range + unaware + behind-arc per SAI's `takedown_prompt_active(target: Node) -> bool` accessor — bundled into OQ-CD-1 SAI amendment). Without both gates, Takedown input drops silently (no animation, no audio, no SAI call).

### C.3 Interactions with Other Systems

| System | Direction | Interface | Contract owner |
|---|---|---|---|
| **Player Character** | Inbound (upstream) | `actor.apply_damage(amount, source, damage_type)` | PC F.6 frozen. Combat calls; PC emits `player_damaged` → `player_health_changed` → optional `player_died` internally. |
| **Stealth AI — guard damage intake** | Inbound (upstream) | `actor.receive_damage(amount, source, damage_type) -> bool is_dead` | SAI §Interactions — pending amendment OQ-CD-1 to add `-> bool` return. Per Transitional UNCONSCIOUS model (CR-16 revised 2026-04-22): dart-KO returns `is_dead = false` (UNCONSCIOUS is not death); subsequent lethal damage on UNCONSCIOUS guard returns `is_dead = true` (transitions to DEAD). |
| **Stealth AI — takedown delegation** | Inbound (SAI calls here) | `Combat.apply_damage_to_actor(...)` (via autoload) | This GDD ships the helper. SAI calls for `STEALTH_BLADE` lethal takedown path triggered by dedicated `Takedown` input (CR-3). |
| **Stealth AI — return-fire timer** | Outbound (signal) | Guard subscribes `Events.player_damaged` | Guard resets `_combat_lost_target_timer` iff `source == self && state == COMBAT`. Reset is synchronous in-handler (CR-14 revised 2026-04-22). |
| **Stealth AI — LOS accessor** | Inbound (read) | `guard.has_los_to_player() -> bool` (NEW 2026-04-22 — bundled in OQ-CD-1) | `GuardFireController` polls this each idle tick to decide LOS ⇄ SUPPRESSION transitions. SAI internal raycast cache; no new raycast per call. |
| **Stealth AI — takedown-prompt accessor** | Inbound (read) | `guard.takedown_prompt_active(eve) -> bool` (NEW 2026-04-22 — bundled in OQ-CD-1) | Combat's Takedown-input gate polls this. SAI owns eligibility (behind-arc + unseen + range). |
| **Audio** | Outbound (signal bus) | `weapon_fired`, `enemy_damaged`, `enemy_killed`, `player_damaged` (PC), `player_health_changed` (PC), `player_died` (PC) | ADR-0002 frozen. All 6 consumed by Audio §Combat domain. |
| **HUD Core** | Outbound (via PC signal) | `Events.player_health_changed` | Forward dep. PC emits; HUD subscribes. Combat does not emit. |
| **Inventory & Gadgets** | Bidirectional (forward dep) | `Events.weapon_fired(weapon, position, direction)` emit-site in Inventory | Inventory owns weapon Resources; Combat reads `weapon.base_damage`, `weapon.fire_rate_sec`, `weapon.magazine_size`, `weapon.damage_type` on each fire. Weapon Resource schema declared in Inventory GDD. |
| **Failure & Respawn** | Outbound (via PC signal) | `Events.player_died(cause: CombatSystem.DeathCause)` | Forward dep. PC emits; Failure & Respawn subscribes. Combat owns the `DeathCause` enum. |
| **Mission & Level Scripting** | Outbound (signal) | `Events.enemy_killed(enemy, killer)` | Forward dep. Subscribed for objective progression ("eliminate all hostiles in zone"). |
| **Level Streaming** | Inbound (signal) | `Events.respawn_triggered(section_id: StringName)` + `Events.section_entered(section_id, reason: TransitionReason)` | Each dart `RigidBody3D` self-subscribes to `Events.respawn_triggered` and `queue_free()`s itself on emit (revised 2026-04-22 — no central ProjectileManager). `GuardFireController` subscribes to same signal for IDLE transition. Normal section transitions use `section_entered` for checkpoint-save timing. `section_entered`'s `reason: TransitionReason` parameter is per Level Streaming's pending ADR-0002 amendment (LS-Gate-1); Combat consumes the parameter when it lands. |
| **Save/Load** | Bidirectional (ADR-0003) | Per player: `current_weapon_id`, `ammo_magazine[weapon_id]`, `ammo_reserve[weapon_id]`. Per guard (dead/unconscious): `alert_state`, `position`, `rotation`, `final_damage_type` (drives restore pose). | ADR-0003 format. Not serialised: mid-shot state, in-flight darts, fire-cadence timers (reset on restore). |
| **Signal Bus** | Outbound (publisher) | 2 signals owned here: `enemy_damaged`, `enemy_killed`. 4 observed/forwarded: `weapon_fired` (Inventory), `player_damaged`/`player_health_changed`/`player_died` (PC). | ADR-0002 frozen. |

### C.4 `CombatSystem` enum definitions (AUTHORITATIVE)

```gdscript
# res://src/gameplay/combat/combat_system.gd
# Script is REGISTERED AS AUTOLOAD under the key "Combat" (see project.godot).
# class_name differs from the autoload key to avoid global-identifier collision
# (same pattern as Events / SignalBusEvents in ADR-0002).
class_name CombatSystemNode
extends Node  # autoload singleton per ADR-0002 Events-style convention

enum DamageType {
    BULLET,
    DART_TRANQUILISER,
    MELEE_FIST,
    MELEE_BLADE,         # NEW — takedown blade (stealth 1-shot)
    FALL_OUT_OF_BOUNDS,
    TEST,
}

enum DeathCause {
    SHOT,
    TRANQUILISED,
    MELEE,
    ENVIRONMENTAL,
    UNKNOWN,
}

static func damage_type_to_death_cause(damage_type: DamageType) -> DeathCause:
    match damage_type:
        DamageType.BULLET:             return DeathCause.SHOT
        DamageType.DART_TRANQUILISER:  return DeathCause.TRANQUILISED
        DamageType.MELEE_FIST:         return DeathCause.MELEE
        DamageType.MELEE_BLADE:        return DeathCause.MELEE
        DamageType.FALL_OUT_OF_BOUNDS: return DeathCause.ENVIRONMENTAL
        DamageType.TEST:               return DeathCause.UNKNOWN
        _:
            push_warning("damage_type_to_death_cause: unhandled DamageType %s" % damage_type)
            return DeathCause.UNKNOWN
```

**Autoload vs class_name (revised 2026-04-21).** The script is registered as the `Combat` autoload (project.godot `[autoload]` section). Its `class_name` is `CombatSystemNode` — intentionally different from the autoload key. This mirrors the ADR-0002 pattern (`class_name SignalBusEvents`, autoload key `Events`) and avoids the global-identifier collision the previous draft triggered. **External callers use the autoload name**: `Combat.apply_damage_to_actor(...)`, `Combat.damage_type_to_death_cause(...)`. **Enum qualified paths use the class name**: `CombatSystemNode.DamageType.BULLET`. Signatures in ADR-0002 that previously read `CombatSystem.DeathCause` are updated to `CombatSystemNode.DeathCause` — coordination note flagged for ADR-0002 amendment.

**Rules:**
- `BULLET` is not split per-weapon. The `source` Node (a weapon Resource reference) carries weapon identity. A split would pollute `damage_type_to_death_cause()` with identical outputs and create a trap for future weapons.
- `DART_TRANQUILISER` maps to `TRANQUILISED` — preserves narrative distinction for future Failure & Respawn dialogue variants and guard UNCONSCIOUS state routing.
- `MELEE_BLADE` (NEW) and `MELEE_FIST` both map to `DeathCause.MELEE`. They are separate `DamageType` values to let SAI's `receive_damage` branch on them (blade → DEAD at 1-shot 100 HP; fist → DEAD at cumulative threshold).
- `FALL_OUT_OF_BOUNDS` covers kill-plane (PC E.kill_plane) and any future environmental-instant-death paths. Fall damage (OQ-2) is a separate future variant.
- `TEST` preserves PC AC-5's test-stub contract — cannot be removed without a PC GDD revision.
- `match` block is exhaustive-by-design: adding a `DamageType` value without updating the function surfaces at edit time, not runtime. **Do NOT refactor to a Dictionary** — silent key-miss would hide defects.
- **Dual-method actor priority** (added 2026-04-21): if an actor implements BOTH `apply_damage` and `receive_damage`, the `apply_damage` path wins (Eve's branch in C.5). A hypothetical Civilian AI with both methods is routed as a player-type actor. Documented to remove implementer ambiguity.

### C.5 `apply_damage_to_actor` implementation contract

```gdscript
# Autoload method on CombatSystem
func apply_damage_to_actor(
    actor: Node,
    amount: float,
    source: Node,
    damage_type: DamageType
) -> void:
    if not is_instance_valid(actor):
        push_warning("apply_damage_to_actor: invalid actor reference")
        return

    if actor.has_method("apply_damage"):
        # Eve's path: PC F.6 owns signal emission and DEAD-state logic
        actor.apply_damage(amount, source, damage_type)
        return

    if actor.has_method("receive_damage"):
        # Guard path: SAI owns state transition (→ DEAD or → UNCONSCIOUS per DamageType)
        var is_dead: bool = actor.receive_damage(amount, source, damage_type)
        Events.enemy_damaged.emit(actor, amount, source)
        if is_dead:
            Events.enemy_killed.emit(actor, source)
        return

    push_warning("apply_damage_to_actor: actor %s has no damage intake method" % actor.name)
```

**Contract invariants:**
- `enemy_damaged.amount` is **post-multiplier** (2× headshot already applied if applicable). Subscribers do not see a separate crit flag.
- Emit order: `enemy_damaged` BEFORE `enemy_killed` — deterministic.
- PC's path does NOT emit `enemy_damaged` for Eve — PC emits `player_damaged` with its own signature.
- `has_method` duck typing is deliberate — it survives future actor types (Civilian AI) without touching this function.

## Formulas

### F.1 Per-Weapon Final Damage

The per-weapon final damage formula is defined as:

`final_damage = base_damage × H`

where `H = 2.0` iff `(is_headshot == true AND target_is_guard == true)`, else `H = 1.0`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base damage | `base_damage` | float | > 0 | Weapon's flat damage from its Resource; one of the four constants below |
| Headshot flag | `is_headshot` | bool | {true, false} | True iff F.5 returns true; always false on Eve (guards fire body-only) |
| Target-is-guard flag | `target_is_guard` | bool | {true, false} | True iff `actor.has_method("receive_damage")`; false on Eve's `apply_damage` path |
| Headshot multiplier | `H` | float | {1.0, 2.0} | Conditional; Eve is ineligible by `target_is_guard` gate |
| Final damage | `final_damage` | float | > 0 | Passed to `apply_damage_to_actor`; `enemy_damaged.amount` carries this value |

**Per-weapon base damage values (canonical)** — revised 2026-04-22 to reflect fists rework (3-swing deliberate KO):

| Weapon | `base_damage` | Body TTK (100 HP guard) | Headshot result | Notes |
|---|---|---|---|---|
| **Takedown blade** | **100** | 1-shot lethal (Takedown-input gated) | N/A — stealth blade has no hit zones | Takedown input (CR-3) → SAI `receive_takedown(STEALTH_BLADE, eve)` → `Combat.apply_damage_to_actor(guard, 100, eve, DamageType.MELEE_BLADE)`. Gated by SAI context prompt + unaware guard; CANNOT be used in COMBAT state. |
| Silenced pistol (gunfight only) | **34** | 3 body shots (102 dmg) | 68 dmg (2-shot head kill) | Body kill: shot 1 = 34, shot 2 = 68, shot 3 = 102 (lethal). 1 headshot = 68 (damaging); 1 head + 1 body = 102 (lethal). **No takedown damage constant** — takedowns route exclusively to the blade. |
| Dart gun | **150** | 1 dart (KO) | N/A — routed via `DART_TRANQUILISER` → UNCONSCIOUS | 150 > 100 HP ensures 1-shot KO with tuning headroom |
| Rifle | **120** | 1 body shot (lethal) | 240 dmg (overkill) | Tonal exception — "chosen moments" weapon per §B weapon-register table. 1-shot body-kill niche; headshot is double-overkill |
| **Fists** *(reworked 2026-04-22)* | **40** | **3 hits (120 dmg) — 2.1 s cycle** | N/A — no headshot on melee cone | Deliberate silent non-lethal KO (per user direction). 3 swings × 0.7 s = 2.1 s per KO. Used for close-range non-lethal stealth AND ammo-dry fallback. Safe range `[34, 50]` preserves 2–3-swing KO window (ceil(100/50) = 2, ceil(100/34) = 3). |
| Guard pistol (vs Eve) | **18** | 5.5-hit kill (100 / 18) | N/A — guards hit body only | Above PC `interact_damage_cancel_threshold` (10 HP); Pillar 3 survivable at 5–6 hits. Safe range `[14, 20]` honors AC-CD-14.1 invariant (`ceil(100/20) = 5`). |

**Output Range (revised 2026-04-22):** at DEFAULT tuning values, `final_damage ∈ [34, 240]` (lowest default = pistol body at 34; highest default = rifle headshot at 240). At SAFE-RANGE ceilings, `final_damage ∈ [34, 300]` (rifle safe ceiling 150 × 2 headshot = 300). Registry `damage_formula.output_range` updated to TWO values: `default_range = [34, 240]`, `safe_range = [34, 300]`. Minimum floor 34 reflects the smallest legal base_damage in combat use (pistol); fist minimum of 34 at safe floor is covered separately in fist-specific tests. Raw value passed through; `apply_damage_to_actor` does not clamp — receiving actor's intake path handles sub-zero / DEAD gates.

**Worked example — silenced pistol headshot on guard:**
`final_damage = 34 × 2.0 = 68`. Guard at 100 HP → 32 HP after first headshot → 0 HP (lethal) after second headshot. Two-headshot kill; one body + one headshot = 34 + 68 = 102 = lethal.

**Worked example — takedown blade delegation (CR-15):**
SAI calls `Combat.apply_damage_to_actor(guard, blade_takedown_damage=100, eve, DamageType.MELEE_BLADE)`. `final_damage = 100 × 1.0 = 100` (no headshot flag on takedown path — blade has no hit zones). Guard receives 100 → `is_dead=true`. Takedown stays 1-shot lethal; gunfight path uses the silenced pistol at 34 HP/shot with NO takedown override. The same-weapon mental-model confusion from the pre-revision draft is removed.

**Worked example — dart on guard:**
`final_damage = 150`. `DamageType.DART_TRANQUILISER` routes guard → UNCONSCIOUS state. Headshot flag is irrelevant — dart does not compute `is_headshot` (darts have no hit-zone detection).

### F.2 Guard Aim Spread Cone

The spread cone half-angle is defined as:

`spread_angle_deg = base_angle(movement_state) + cover_modifier + range_falloff(distance_m)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Movement state | `movement_state` | enum | {STATIONARY, WALKING, CROUCHED_STATIONARY, SPRINTING} | Eve's movement state at shot time |
| Base angle | `base_angle` | float (deg) | {2.0, 3.0, 3.5, 6.0} | Lookup below |
| Cover modifier | `cover_modifier` | float (deg) | {0.0, 4.0} | +4° when Eve is partially occluded from guard LOS |
| Distance | `distance_m` | float (m) | [0, 16) | Guard-to-Eve Euclidean distance; guard cannot fire ≥ 16 m |
| Range falloff | `range_falloff` | float (deg) | [0.0, 3.0] | `0` below 8 m; `3.0 × (distance − 8) / 8` from 8 m → 16 m |
| Output spread | `spread_angle_deg` | float (deg) | [2.0, 13.0] | Cone half-angle; fed to F.3 |

**Base angle lookup:**

| `movement_state` | `base_angle` (deg) |
|---|---|
| STATIONARY | 2.0 |
| CROUCHED_STATIONARY | 3.0 |
| WALKING | 3.5 |
| SPRINTING | 6.0 |

**Eve's own spread (when firing):** `eve_spread_deg = 0.0` (perfect aim at MVP — arcade-period feel). Prototype-gated: Tier 1 playtest may warrant 0.5–1.5° on sprint-fire only to preserve the "stop to shoot" micro-decision. Rifle ADS halves whatever Eve's spread is (so 0.0 stays 0.0, or 1.5 → 0.75 if sprint-tax is introduced).

**Output Range (at default tuning values)**: min 2.0° (stationary, no cover, ≤ 8 m) → max 13.0° (sprinting + cover + falloff: 6 + 4 + 3). **At safe-range ceilings** (revised 2026-04-21, resolves systems-designer Finding 5): `guard_spread_sprinting_deg = 9` + `guard_cover_modifier_deg = 6` + `guard_range_falloff_max_deg = 5` = 20° theoretical max. The stated `[2.0, 13.0]` range holds ONLY at default tuning. Registry `damage_formula.spread_range` updated to `[2.0, 20.0]` for safe-range coverage.

**Fire gate invariant**: callers MUST gate on `distance_m < guard_range_falloff_end_m` (default 16.0) before invoking this formula. The gate uses the live tuning-knob value — NOT hardcoded 16.0 — so designer tuning `end_m = 12` correctly gates guards from firing at 12–15.99 m (resolves systems-designer Finding 6).

**Falloff-bound invariant (resolves systems-designer Finding 4 + divide-by-zero)**: `guard_range_falloff_start_m < guard_range_falloff_end_m` is a HARD invariant. The runtime computation guards against it:
```gdscript
var denominator: float = guard_range_falloff_end_m - guard_range_falloff_start_m
assert(denominator > 0.001, "Falloff invariant violated: start >= end")
var falloff: float = guard_range_falloff_max_deg * clamp((distance_m - start_m) / denominator, 0.0, 1.0)
```
AC-CD-8.5 added to assert this invariant as a constant-validation test (same pattern as AC-CD-4.4's cadence invariant).

**Worked example — guard at 10 m, Eve sprinting in partial cover:**
`range_falloff = 3.0 × (10 − 8) / 8 = 0.75°`
`spread_angle_deg = 6.0 + 4.0 + 0.75 = 10.75°`

At 10 m, a 10.75° cone produces lateral miss magnitudes up to `10 × tan(10.75°) ≈ 1.9 m`. Eve sprinting through open ground at 10 m from a guard has a ~64% chance of being hit (F.3 sampling distribution) — dangerous but survivable.

**Worked example — guard at 5 m, Eve stationary:**
`spread_angle_deg = 2.0°`. At 5 m, lateral miss up to `5 × tan(2°) ≈ 17 cm`. Against Eve's 0.3 m capsule radius, stationary-at-5-m is near-certain hit. **Implication: standing in the open at close range = near-guaranteed hit.** Intentional.

### F.3 Ray-Sample Within Cone (Hitscan-then-Perturb)

The hitscan ray direction is perturbed by a Gaussian-biased sample inside the cone:

```gdscript
func sample_cone_direction(aim_basis: Basis, spread_angle_deg: float) -> Vector3:
    var spread_rad: float = deg_to_rad(spread_angle_deg)
    var r: float = sqrt(randf())                       # radially uniform disk density
    var phi: float = randf_range(0.0, TAU)             # uniform azimuth
    var theta: float = spread_rad * r                  # polar angle within cone

    var perp: Vector3 = aim_basis.x * cos(phi) + aim_basis.y * sin(phi)
    var aim_dir: Vector3 = -aim_basis.z                # Godot convention: -Z forward

    # Rodrigues rotation: rotate aim_dir by theta around perp axis
    var perturbed: Vector3 = (
        aim_dir * cos(theta)
        + perp.cross(aim_dir) * sin(theta)
        + perp * perp.dot(aim_dir) * (1.0 - cos(theta))
    )
    return perturbed.normalized()
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Spread half-angle | `spread_angle_deg` | float (deg) | [2.0, 13.0] | Output of F.2 |
| Radial sample | `r` | float | [0.0, 1.0) | `sqrt(randf())` — radially uniform disk (pseudo-Gaussian) |
| Azimuth | `phi` | float (rad) | [0, 2π) | Uniform random rotation around aim axis |
| Polar angle | `theta` | float (rad) | [0, spread_rad) | Radial offset from aim |
| Aim basis | `aim_basis` | Basis | — | Camera basis (Eve) or guard transform (guards) |
| Perturbed direction | `perturbed_direction` | Vector3 | unit | Final ray direction |

**Design rationale for sqrt(randf()):** Uniform `randf()` (flat disk density) would produce equal probability of 1° miss and 9° miss — unrealistic. `sqrt(randf())` transforms to radially-uniform disk density (the standard disk-sampling trick): probability ∝ `r`, so the *linear* distribution in `r` means center-weighted miss density but NOT heavy center-cluster. **Statistical properties (corrected 2026-04-22 per systems-designer F11)**: for `r = sqrt(randf())` on [0, 1), the distribution has CDF `F(r) = r²`, so the median of `r` is `√0.5 ≈ 0.707`. For a 13° cone, median polar angle is `13° × 0.707 ≈ 9.2°` (not 7.5° as prior draft claimed). This is still *more* center-biased than flat-disk (which would median at `0.5 × 13° = 6.5°` in `r`, but with equal-probability rings producing visually uniform distribution at the edge). AC-CD-9.2 assertion revised to `< 9.5°` (tolerance above the analytical 9.2° median). **Why not `randfn()`?** `randfn(mean, deviation)` has existed since Godot 4.0. The preference for `sqrt(randf())` is that a Gaussian can produce unbounded samples requiring rejection sampling or clamping to stay within the spread cone. `sqrt(randf())` is bounded-by-construction and has no rejection loop.

**Output Range:** Unit Vector3 with angular deviation from `aim_dir` in `[0, spread_rad)`. No clamping needed — `r` is bounded by construction.

**Worked example — 10.75° cone, randf() returns 0.64:**
`r = sqrt(0.64) = 0.8`, `theta = 10.75° × 0.8 = 8.6°`. At 10 m, lateral deviation = `10 × sin(8.6°) ≈ 1.5 m`.

### F.4 Dart Gun Projectile Physics

The dart's initial state is defined as:

```
linear_velocity = aim_direction.normalized() × dart_speed_m_s
gravity_scale   = 0.0
lifetime        = dart_lifetime_s  (auto-queue_free on timeout)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Aim direction | `aim_direction` | Vector3 | unit | Camera forward at fire moment (NO cone perturbation — dart is perfectly accurate) |
| Dart speed | `dart_speed_m_s` | float (m/s) | [15, 30] (default **20**) | Muzzle speed |
| Gravity scale | `gravity_scale` | float | 0.0 (locked) | Zero — dart flies straight |
| Lifetime | `dart_lifetime_s` | float (s) | [3.0, 6.0] (default **4.0**) | Auto-free timer |
| Max range (derived) | `max_range_m` | float (m) | `dart_speed × lifetime` | 20 × 4 = 80 m |

**Spawn contract (for the weapon Resource to honor at spawn time):**
- **Pre-fire occlusion check** (NEW 2026-04-22): Combat performs a `PhysicsRayQueryParameters3D.create(camera.global_position, spawn_pos)` against `MASK_WORLD` BEFORE spawning. If occluded, the fire is cancelled at the call site — dry-fire click SFX plays, no dart spawned, no ammo consumed, no `weapon_fired` signal. Prevents silent "fire inside wall" when Eve is flush against cover (godot-specialist B14).
- Spawn position: `camera.global_position + aim_direction × 0.5` (prevents Eve's capsule self-collision)
- `collision_layer = PhysicsLayers.MASK_PROJECTILES` (layer 5)
- `collision_mask = MASK_WORLD | MASK_AI` (hits world and guards; NOT Eve, NOT other projectiles)
- `continuous_cd = true` **(@prototype_gated — OQ-CD-2 item 3)**: Jolt may or may not honor Godot-Physics's `continuous_cd` property; OQ-CD-2's prototype validates whether CCD is active under Jolt or requires a Jolt-specific property path. Implementers MUST wait for prototype verdict before shipping dart physics.
- On `body_entered(body)` OR `area_entered(area)`: both signals connect to the same `_on_impact(other)` handler (CR-6 revised 2026-04-22 — handles both PhysicsBody3D contact and Area3D overlap). Handler calls `Combat.apply_damage_to_actor(other, dart_damage, self, DamageType.DART_TRANQUILISER)` with guard (`_has_impacted` flag) against double-fire, then `queue_free()`.
- On `Events.respawn_triggered` emit: dart `queue_free()`s itself (self-cleanup, no central manager — CR-12 revised 2026-04-22). Dart MUST disconnect the subscription in `_exit_tree()` to avoid dangling autoload references.

**Why zero gravity?** At 20 m/s over 5–15 m engagement range, real gravity (9.8 m/s²) would drop 0.31–2.76 m — visible, disruptive, would break aim-for-head shots. Zero gravity = straight flight = reads as a precision tool. Subtle 0.5 m/s² arc option is prototype-gated for Tier 1 iff "dart feels too surgical."

**Why lifetime instead of kinematic range cap?** Per-physics-frame distance computation is per-dart CPU cost; lifetime is free. 4.0 s × 20 m/s = 80 m which vastly exceeds the 16 m guard fire range and any realistic engagement range — lifetime as effective max range is appropriate.

**Worked example — dart at guard 8 m ahead:**
Travel time = `8 / 20 = 0.4 s`. `body_entered` fires at 0.4 s, damage applied, dart frees. Lifetime timer (fires at 4.0 s) becomes moot.

### F.5 Headshot Hit-Zone Detection

Headshot detection uses a dedicated `Area3D` child on each guard, tagged via group membership:

`is_headshot = hit_collider.is_in_group("headshot_zone")`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Raycast hit collider | `hit_collider` | Node | — | `intersect_ray` result dict `collider` key |
| Group flag | `is_headshot` | bool | {true, false} | True iff `hit_collider.is_in_group("headshot_zone")` |
| Zone Y offset | `head_zone_y_offset_m` | float (m) | **1.65** | Sphere center, relative to guard root origin (eye_height 1.7 − 0.05 centers on crown) |
| Zone radius | `head_zone_radius_m` | float (m) | **0.15** | Sphere radius — ~17% of 1.8 m standing height |

**Authoring pattern (guards' scene):**

```
phantom_guard.tscn
├── CharacterBody3D (root)
│   ├── CapsuleShape3D (body collider, layer LAYER_AI)
│   ├── Skeleton3D
│   │   └── BoneAttachment3D (bone: "head")
│   │       └── Area3D (group: "headshot_zone", layer LAYER_AI, mask 0)
│   │           └── SphereShape3D (radius: 0.15)
│   └── ...
```

**Why Area3D + BoneAttachment3D:** The sphere's world-space center follows the head bone's animation position regardless of pose, crouch, or ragdoll. Area3D generates no physics response — it's a detection volume, not a solid collider.

**Why NOT Y-threshold or local-Y check:**
- World-space Y check is brittle on stairs, slopes, crouched guards.
- Local-space Y decouples from animation retargeting and visual head position.
- Group membership on a bone-attached Area3D is the correct Godot 4.6 idiom.

**Bone name contract (resolves systems-designer Finding 10)**: the head bone MUST be named `"head"` (lowercase, exact string). This is recorded in `design/registry/entities.yaml` under `phantom_guard.head_bone_name = "head"` as a canonical asset contract. Riggers using alternate names (`"Head"`, `"head_bone"`, `"Bip01_Head"`) will produce silent fallback to root-origin Y = 0 — a fairness failure. Enforced by an asset-audit script that greps guard `.tscn` files for `BoneAttachment3D` bone property and validates against the registry.

**Query flag requirement**: the raycast query used for hit detection (CR-5) MUST set `query.collide_with_areas = true`. Without this, Godot 4.x returns only `CollisionObject3D` bodies and the head Area3D is silently skipped. This was the primary blocker surfaced by /design-review godot-specialist.

**Jolt caveats (OQ-CD-2 — BLOCKING PROTOTYPE):** Set the Area3D's shape to `LAYER_AI` (layer 3) with mask 0 (it does NOT initiate overlap queries itself). **The "Area3D returned as `collider`" behavior below is EXPECTED — NOT confirmed.** The prototype at `prototypes/guard-combat-prototype/` must validate THREE Jolt-specific unknowns; implementers MUST wait for prototype verdict before shipping headshot detection:

1. **Bone-attached Area3D + intersect_ray**: does Jolt return the Area3D as `collider` in `intersect_ray` results with `collide_with_areas = true`? Hypothesis: yes (matches Godot-Physics behavior). If NO, fallback path: use a non-Area collider (e.g., a child `CollisionShape3D` on a sibling `StaticBody3D` bone-attached, layered but masked-off from damage). Decision tree: if Jolt returns `CharacterBody3D` (parent) instead of the Area3D, we need a different head-detection strategy (e.g., distance-to-bone-origin check on the hit collider).
2. **BoneAttachment3D pose lag in physics tick**: does the Area3D world-space transform reflect the CURRENT animated pose when queried from `_physics_process`, or does it lag one frame behind `_process`? **Mitigation path (pre-specified 2026-04-22 per godot-specialist M6)**: if lag is confirmed, set guards' `AnimationPlayer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS` so skeleton pose updates inside the physics tick, syncing with the hitscan query. If that resolves the lag, no GDD change is needed; if it doesn't, a manual `BoneAttachment3D.update_transform()` call in `_physics_process` before raycast is the alternative.
3. **`RigidBody3D.continuous_cd` under Jolt**: does Jolt respect the CCD property for the dart projectile, or does it require a Jolt-specific property (e.g., a Jolt physics server extension)? If NO, fallback: increase dart speed cap OR shorten tick interval for dart physics; both acceptable at 20 m/s over ≤16 m engagement ranges.

**Worked example (PENDING OQ-CD-2 item 1 CONFIRMATION) — rifle shot hits guard head zone:**
Expected: `hit_collider` = `<Area3D on BoneAttachment3D>`; `is_in_group("headshot_zone") == true` → `is_headshot = true`. F.1: `120 × 2.0 = 240`. 240 > 100 HP → instant lethal. **If OQ-CD-2 returns differently (e.g., Jolt returns `CharacterBody3D`), the detection path changes and AC-CD-11.x assertions are re-authored.**

**Worked example — pistol shot hits guard torso:**
`hit_collider` = `<CapsuleShape3D on body>`, not in `headshot_zone` group → `is_headshot = false`. F.1: `34 × 1.0 = 34` (body damage).

**Output:** Binary — `true` or `false`.

### F.6 Ammo Economy Tables

**Design pivot 2026-04-22 — NOLF1-authentic rebalance** (per user decision on economy). Starting reserves stay at the 2026-04-21 raised values (pistol 32, dart 16) so Eve isn't "pressured low from the first door." But guard drops are **net-negative for Aggressive** (3 pistol rounds per lethal kill, below the 3-shot body-TTK cost once reload overhead is counted), which restores Pillar 2's ammo-depletion pressure. NOLF1's Pillar 2 signature — "even when you win a shootout, you lost" — returns. Caches remain the secondary reward for off-path observation. Pillar 2 is owned jointly by Combat (depletion-via-drops) + Level Design (cache placement), with combat-side depletion as the primary lever.

**Starting inventory at Tier 1 mission start:**

| Weapon | Magazine Size | Starting Reserve | Total | Notes |
|---|---|---|---|---|
| Takedown blade | — (draw-per-takedown) | — | — | Unlimited uses; gated by Takedown input + SAI context prompt |
| Silenced pistol | 8 rounds | **32 rounds** | 40 rounds | ~13 body-TTK kills or ~20 headshot-lead kills before dry; Aggressive dry by Section 3–4 with guard drops included |
| Dart gun | 4 darts | **16 darts** | 20 darts | Ghost can KO 20 guards standalone; placed caches + break-even drops provide margin at 70–80% real-play pickup |
| Rifle | 0 | 0 | 0 | Pickup-only — never in starting inventory |
| Fists | — | — | — | Always available. 3-swing / 2.1 s cycle per KO (revised 2026-04-22). Viable deliberate non-lethal melee tool OR ammo-dry fallback. No ammo counter. |

**Guard drops (pickup via PC's `player_interacted` raycast) — REVISED 2026-04-22 (NOLF1 authentic):**

| Kill method | Guard carrying silenced pistol | Guard carrying rifle | Dart-KO dart drop | Fist-KO dart drop |
|---|---|---|---|---|
| Lethal (pistol/rifle/blade) | **3 rounds** (was 8) | 3 rounds (partial) | — | — |
| Non-lethal dart KO | 0 pistol rounds | 0 rifle rounds | **1 dart** (break-even) | — |
| Non-lethal fist KO | 0 pistol rounds | 0 rifle rounds | — | **0 darts** (no farm) |

**Design intent**: a lethal pistol kill costs 3 rounds and drops 3 rounds — break-even at 100% pickup. With realistic pickup friction (reload cost: 1 spilled round at reload-on-empty; missed shots on spread; partial pickups interrupted by next alert), Aggressive accumulates a NET LOSS over the mission. Ghost's dart break-even is unchanged. Fists remain zero-yield on fist-KO.

**Dart anti-farm invariant (unchanged from 2026-04-21)**: `guard_drop_dart_on_dart_ko = 1` (break-even); `guard_drop_dart_on_fist_ko = 0` (no farm). Even though fists are now a viable deliberate non-lethal KO tool, fist-KO'd guards still drop 0 darts — fists cannot subsidize the dart economy.

**Real-play pickup rate acknowledgement**: dart break-even assumes 100% retrieval. In practice, ~80% (darts land off-ledge, in hot zones, behind locked doors). Starting reserve (16) + placed caches + break-even drops absorb the ~20% drain. Ghost economy sanity check below. Section 5 boss: with fists now 2.1 s / 3-swing, fist-KO on a standard-HP boss (100 HP) is a 2.1 s action — viable as a last-resort non-lethal boss path. Boss HP forward-dep remains with Mission & Level Scripting; the contract here is "if boss HP ≤ 100, fist-KO path works; if Mission Scripting gives boss > 100 HP, it must either tune fist damage up OR provide a bespoke non-lethal takedown slot."

**Placed pickups per section (Tier 1) — REVISED (generosity adjusted):**

| Section | Guards | Pistol caches | Rifle | Dart caches | Rationale |
|---|---|---|---|---|---|
| Sec 1 Plaza | 3–5 | 1 × 8 | — | 1 × 3 | Tutorial density; caches on observer-path |
| Sec 2 Scaffolds | 5–7 | 1 × 8 | — | 1 × 3 | Off-path detour required |
| Sec 3 Restaurant | 6–8 + civilians | 1 × 8 + 1 × 4 | 1 pickup + 3 mag + 3 reserve | 1 × 3 | First rifle pickup; dart behind civilian zone |
| Sec 4 Upper Structure | 7–9 | 1 × 12 | — | 1 × 4 | Dense guard count offset by richer caches |
| Sec 5 Bomb Chamber | 4–6 + boss | 1 × 8 | 1 pickup + 3 mag + 3 reserve | 1 × 3 (NEW) | Pressure section with a single cache each — ghost viable without fists-on-boss |

Rifle table clarification: "1 pickup + 3 mag + 3 reserve" means the rifle weapon itself (magazine full at 3) plus 3 reserve rounds = 6 total per pickup. Matches `rifle_pickup_reserve = 6` knob. Previous "1 pickup + 3 rds" wording was ambiguous and is replaced.

**Respawn ammo policy (Failure & Respawn contract — forward dep) — CLARIFIED:**

```gdscript
# All floor comparisons apply to TOTAL ammo (magazine + reserve), NOT to magazine alone.
# Result is clamped to [0, per_weapon_max_reserve] to defend against corruption / underflow.
func restore_weapon_ammo(snapshot_total: int, floor: int, max_cap: int) -> int:
    var candidate: int = max(snapshot_total, floor)
    return clamp(candidate, 0, max_cap)

# Per-weapon floors:
respawn_floor_pistol_total = 16   # 1 magazine (8) + 1 reserve refill (8)
respawn_floor_dart_total   = 8    # 1 magazine (4) + 1 reserve refill (4)
respawn_floor_rifle_total  = -1   # sentinel: preserved as-is, no floor applied
```

**Floor scope clarified (resolves AMBIGUITY BLOCKER)**: "pistol ammo = 16 minimum" means total (magazine + reserve) ≥ 16. A player dying with 3 in magazine + 5 in reserve (total 8) restores to 16 total — implementation redistributes as 8 magazine + 8 reserve. A player dying with 6 magazine + 12 reserve (total 18) restores unchanged. Magazine never exceeds `magazine_size`; any overflow stays in reserve.

**Floor anti-farm protection** (resolves economy-designer Finding 4): the floor applies ONLY on first death since last `section_entered` checkpoint. The `failure_respawn_node` tracks a per-checkpoint `floor_applied_this_checkpoint: bool`. Subsequent deaths in the same section restore to snapshot only (no floor). This closes the spend-to-7-round-and-die farm loop while preserving softlock prevention on genuinely ammo-depleted checkpoints. Forward contract to Failure & Respawn GDD.

**Between-section carryover:** **Full carryover**. Scarcity compounds across the mission. Ghost's accumulated darts, Aggressive's depletion, both persist. Checkpoint saves fire at Level Streaming's `section_entered` (already in ADR-0003 save format).

**Depletion curve sanity check (revised 2026-04-22 — NOLF1 math, per-section):**

| Section | Guards (mid) | Aggressive spend (3/guard) | Cache contribution (pistol) | Guard drops (3/guard) | Net end-of-section balance |
|---|---|---|---|---|---|
| Start | — | — | 40 starting total | — | **40** |
| Sec 1 Plaza (4 guards) | 4 | 12 | +8 (cache) | +12 (4×3) | 40 − 12 + 8 + 12 = **48** |
| Sec 2 Scaffolds (6 guards) | 6 | 18 | +8 | +18 | 48 − 18 + 8 + 18 = **56** |
| Sec 3 Restaurant (7 guards) | 7 | 21 | +12 (8+4) | +21 | 56 − 21 + 12 + 21 = **68** |
| Sec 4 Upper (8 guards) | 8 | 24 | +12 | +24 | 68 − 24 + 12 + 24 = **80** |
| Sec 5 Chamber (5 guards) | 5 | 15 | +8 | +15 | 80 − 15 + 8 + 15 = **88** |

**Aggressive at 100% cache + 100% pickup** would END at 88 reserves — overflow. BUT: real-play friction reduces this:
- Missed shots (spread on moving Eve vs moving guard): assume 15% miss rate × 90 spent = 13.5 wasted rounds
- Reload-on-empty loses 1 round (remaining mag discarded): assume 6 reloads × 1 = 6 wasted
- Partial pickups interrupted by new alerts: assume 30% of pickups miss = 18 guard-drop rounds lost; 8 cache rounds lost
- Corrected end: 88 − 13.5 − 6 − 18 − 8 = **~42 rounds** (a single magazine's cushion at mission end — genuine Pillar 2 feel)

**Aggressive skipping caches (observation penalty)** = 88 − 48 cache total − friction 37 = **~3 rounds left** entering Section 5. The NOLF1 signature returns: skip observation, feel the cost. With `pistol_max_reserve = 48` cap, late-game drift is capped — late-mission Aggressive maxes at 48 + 8 mag = 56 total, never the 80+ of the accumulation-curve draft.

**Ghost player (dart-KO focus, 30 guards × 1 dart)**: starting 20 + caches (3+3+3+4+3 = 16) + break-even drops × 80% pickup (24 recovered) = 60 darts gross inflow against 30 spent = **30 net darts** at mission-end assuming 100% pickup. At 80% pickup (realistic), Ghost ends with ~24 darts — comfortable margin. Dart scarcity is NOT the Pillar 2 lever for Ghost; observation-discovering-caches is. Ghost's pressure is getting caught mid-KO (alert triangle), not running out of ammo.

**Mixed archetype (default expected play — mix of darts, fists for close-range KO, pistol for shootouts)**: economy holds with substantial margin; fists fill the close-range silent slot without ammo cost.

**Pickup cap** (resolves E.32): per-weapon reserve cap is `pistol_max_reserve = 48`, `dart_max_reserve = 24` (~1.5× starting reserve). Pickup past cap loses excess. Inventory & Gadgets forward-dep owns the clamp.

### Summary Table — Tuning Knob Feeds

| Parameter | Default | Safe Range | Prototype Gate? | Notes |
|---|---|---|---|---|
| `silenced_pistol_base_damage` | 34 | [28, 45] | No | Body TTK 3-shot; headshot 2-shot |
| `blade_takedown_damage` | 100 | [100, 150] | No | Stealth blade 1-shot-lethal damage (CR-15 SAI delegation via `DamageType.MELEE_BLADE`). Replaces `silenced_pistol_takedown_damage` per CR-3 revision 2026-04-21. |
| `dart_damage` | 150 | [100, 200] | No | 1-shot KO with headroom |
| `rifle_base_damage` | 120 | [100, 150] | No | 1-shot body kill niche |
| `fist_base_damage` | **40** (revised 2026-04-22 from 16) | **[34, 50]** | No | 3-swing deliberate KO (default); 2-swing at safe ceiling. Safe range preserves 2–3-swing window; outside this range fists either slapstick (>3 swings) or overpowered (<2 swings). |
| `guard_pistol_damage_vs_eve` | 18 | [14, 20] | **Yes** (Tier 1 playtest) | Pillar 3 survivability feel. Safe range honors AC-CD-14.1 (`ceil(100/20) = 5` min hits to kill). |
| `guard_first_shot_delay_s` | 0.65 | [0.4, 1.0] | No | Reaction window |
| `guard_los_cadence_s` | 1.4 | [1.0, 2.0] | No | LOS fire rhythm |
| `guard_suppression_cadence_s` | 2.8 | [2.0, 4.0] | No | Must stay ≥1.5× LOS |
| `guard_suppression_max_shots` | 3 | [2, 5] | No | Caps suppression cost |
| `guard_spread_stationary_deg` | 2.0 | [1.0, 4.0] | No | |
| `guard_spread_walking_deg` | 3.5 | [2.5, 5.0] | No | |
| `guard_spread_crouched_deg` | 3.0 | [2.0, 4.5] | No | |
| `guard_spread_sprinting_deg` | 6.0 | [4.0, 9.0] | No | |
| `guard_cover_modifier_deg` | 4.0 | [2.0, 6.0] | No | |
| `guard_range_falloff_start_m` | 8.0 | [6.0, 10.0] | No | |
| `guard_range_falloff_end_m` | 16.0 | [12.0, 20.0] | No | Hard no-fire cutoff |
| `guard_range_falloff_max_deg` | 3.0 | [1.5, 5.0] | No | |
| `eve_spread_deg` | 0.0 | [0.0, 1.5] | **Yes** (Tier 1) | Sprint-fire tax decision |
| `dart_speed_m_s` | 20.0 | [15, 30] | **Yes** (feel playtest) | |
| `dart_lifetime_s` | 4.0 | [3.0, 6.0] | No | |
| `dart_gravity_scale` | 0.0 | {0.0, 0.5} | **Yes** (Tier 1 arc option) | |
| `head_zone_radius_m` | 0.15 | [0.10, 0.20] | **Yes** (fairness) | |
| `head_zone_y_offset_m` | 1.65 | [1.55, 1.75] | No | Bone-attached; bone pose authoritative |
| `pistol_magazine_size` | 8 | [6, 12] | No | Paired with fire rate |
| `pistol_starting_reserve` | 32 | [16, 48] | No | 4× magazine ratio. Covers Aggressive through the mission assuming NOLF1 drops (3/kill); dry around Section 4–5 without caches. |
| `dart_magazine_size` | 4 | [3, 6] | No | Paired with dart scarcity |
| `dart_starting_reserve` | 16 | [8, 24] | No | 4× magazine ratio. Absorbs ~20% dart-pickup miss rate and keeps Ghost path viable. |
| `rifle_magazine_size` | 3 | [2, 5] | No | Pickup-only |
| `rifle_pickup_reserve` | 6 | [3, 9] | No | Per-pickup amount |
| `respawn_floor_pistol_total` | 16 | [8, 32] | No | TOTAL (magazine + reserve) minimum at respawn. Consumed by Failure & Respawn. |
| `respawn_floor_dart_total` | 8 | [4, 16] | No | TOTAL (magazine + reserve) minimum at respawn. |
| `pistol_max_reserve` | 48 | [24, 64] | No | Hard cap on reserve ammo; pickup past cap loses excess (E.32). Also used in `restore_weapon_ammo` clamp. |
| `dart_max_reserve` | 24 | [16, 32] | No | Hard cap on dart reserve. |
| `guard_drop_pistol_rounds` | **3** (revised 2026-04-22 from 8) | [2, 5] | No | Per-lethal-kill drop from guard carrying silenced pistol. NOLF1-authentic — below 3-shot body-TTK cost once reload overhead + miss rate are counted → Aggressive net-negative. |
| `guard_drop_rifle_rounds` | 3 | [1, 5] | No | Per-lethal-kill drop from guard carrying rifle. |
| `guard_drop_dart_on_dart_ko` | 1 | {1} fixed | No | Break-even anti-farm invariant. |
| `guard_drop_dart_on_fist_ko` | 0 | {0} fixed | No | Fist-KO yields no darts — closes fist-farm loop (Pillar 2). |
| `guard_friendly_fire_enabled` | true | {true, false} | No | Per-section overridable |

**Prototype-gated values (5):** `guard_pistol_damage_vs_eve`, `eve_spread_deg`, `dart_speed_m_s`, `dart_gravity_scale`, `head_zone_radius_m`. Recommend `prototypes/guard-combat-prototype/` covers all 5 in a single playtest scene.

## Edge Cases

### Damage resolution

- **E.1 Two damage calls arrive for the same actor on the same physics frame** (revised 2026-04-22 per Transitional UNCONSCIOUS model): both execute sequentially. If the first lethally kills the actor (state → DEAD), the second's `receive_damage` gates on `current_alert_state == DEAD` and returns `is_dead = true` without re-emitting state changes. If the first puts the actor UNCONSCIOUS and the second is lethal DamageType (BULLET/MELEE_BLADE/MELEE_FIST/rifle/fall), UNCONSCIOUS → DEAD transitions and `is_dead = true`. If both are DART_TRANQUILISER on an UNCONSCIOUS target, the second is no-op (`is_dead = false`). `apply_damage_to_actor` emits `enemy_damaged` on every call; `enemy_killed` fires once at the moment the actor reaches DEAD (which is first-kill for lethal path, or on the post-UNCONSCIOUS-lethal-hit for the transitional path).
- **E.2 Dead guard receives a subsequent bullet**: `receive_damage` returns `is_dead = true` immediately (DEAD gate). `enemy_damaged` emits on corpse; `enemy_killed` does not re-emit. No state change. Audio plays no vocal (guard is DEAD).
- **E.3 UNCONSCIOUS guard is shot by pistol/rifle/fists/blade** (revised 2026-04-22 — Transitional model): state transitions UNCONSCIOUS → DEAD (via `receive_damage` seeing `current_alert_state == UNCONSCIOUS` + lethal DamageType, reducing HP further into negative, committing DEAD state). `receive_damage` returns `is_dead = true`. `apply_damage_to_actor` emits `enemy_damaged(guard, damage, source)` followed by `enemy_killed(guard, source)`. Intended for Mission Scripting tagging: a "no-lethals" objective cannot be satisfied if the player re-shoots KO'd guards (the re-shot fires `enemy_killed`, which Mission Scripting counts as a lethal). The original dart path that produced UNCONSCIOUS did NOT fire `enemy_killed`; only the subsequent lethal re-hit does.
- **E.4 Eve fires exact lethal shot AND guard kills Eve same frame**: both `player_died` (PC emit) and `enemy_killed` (Combat emit) fire same frame. Subscribers run independently in emission order. Failure & Respawn freezes input on `player_died`; Mission Scripting counts the guard kill. Dramatic mutual-elimination is intended.
- **E.5 Guard hitscan ray penetrates Eve's capsule and would continue to a second guard**: `intersect_ray` returns the first hit only. Ray stops at Eve. Second guard never receives damage. Intentional — Jolt is single-hit by design (CR-5).
- **E.6 Eve fires at a guard mid-draw (0.65 s first-shot-delay window)**: Eve's hitscan resolves immediately. Guard's draw-animation timer is independent; if Eve's shot kills the guard, SAI's DEAD-state entry stops the fire-cadence timer (E.24). If Eve's shot only wounds, the draw completes at 0.65 s and fire cadence starts normally.
- **E.7 Eve at exactly 0 HP**: PC F.6 boundary `health <= 0.0` triggers DEAD. At exactly 0.0, Eve is DEAD. `player_died` fires. No "barely alive at zero" ambiguity.

### Weapon state

- **E.8 Last round fired, reserve = 0**: fire resolves, `weapon_fired` emits, magazine drops to 0. No auto-reload. Fire input on next press is gated at weapon level — dry-fire click SFX (Audio-owned), no signal, no damage. **Fallthrough to fists is Inventory & Gadgets' concern — see OQ-CD-3.**
- **E.9 Reload initiated with reserve = 0**: `_is_reloading` briefly sets true, method immediately aborts on `reserve == 0` check, resets to false same frame. No animation, no sound, no ammo movement.
- **E.10 Reload initiated with magazine full**: silently dropped at `magazine < magazine_size` gate. `_is_reloading` never sets true. Idempotent — no side effects.
- **E.11 Weapon-switch while reloading**: reload cancels; partial-reload rounds are NOT recovered; switch starts immediately. Reserve unchanged, magazine unchanged from pre-reload.
- **E.12 Fire input during weapon-switch**: dropped by CR-10 gate. No queued fire — the 0.35 s switch completes before fire becomes available.
- **E.13 ADS input during fist swing**: fists are not ADS-eligible; ADS input has no registered handler on the fist path. Silently ignored. Fist swing completes normally.
- **E.14 Dart in flight + Eve switches weapons**: dart continues flying independently (owned by scene, not by weapon Resource). Weapon switch completes cleanly. Dart `body_entered` callback remains live.
- **E.15 Fist swing with zero valid targets in cone**: no `apply_damage_to_actor` call. Swing completes full cycle. Cloth-impact SFX still plays (represents Eve's action, not a target reaction). No signal.
- **E.16 Fist swing overlaps multiple targets in cone**: CR-7 specifies 1 hit per swing. Resolution: **OPEN QUESTION (OQ-CD-4)** — prototype nearest-target sort vs. ShapeCast3D first-result.
- **E.17 Rapid-fire press before cooldown clears**: second press dropped by fire-rate cooldown timer. No double-shot, no queue.

### Projectile

- **E.18 Dart hits UNCONSCIOUS guard** (revised 2026-04-22): `collision_mask` includes `MASK_AI`; dart collides, `receive_damage` sees UNCONSCIOUS target + DART_TRANQUILISER DamageType → idempotent no-op, returns `is_dead = false`. `enemy_damaged` emits (redundant-tolerant subscribers); `enemy_killed` does NOT emit. Re-darting an already-KO'd guard doesn't count as an elimination. If a LETHAL DamageType arrives on the same UNCONSCIOUS target (e.g., dart then pistol), E.3 applies.
- **E.19 Dart hits Eve**: dart `collision_mask = MASK_WORLD | MASK_AI` explicitly excludes `MASK_PLAYER`. Dart passes through Eve's capsule. Intentional per F.4 spawn contract.
- **E.20 Dart hits dead guard corpse**: corpse remains on `LAYER_AI`; dart collides, `receive_damage` returns `is_dead=true` (DEAD gate). `enemy_damaged` emits on corpse. Dart frees. Duplicate-on-corpse tolerated by subscribers.
- **E.21 Dart hits world geometry (wall, floor)** (revised 2026-04-22 — CR-6 match): dart's `_on_impact(body)` filters world early (`body.is_in_group("world") or body is StaticBody3D`) and `queue_free()`s with NO `push_warning`, NO damage call. Wall-impact SFX is a separate Audio subscriber on the dart's own `body_entered` signal (Audio reads the event before queue_free completes in the same tick). The pre-revision "routes via duck-type → `push_warning`" description was wrong; CR-6 filters world before any `apply_damage_to_actor` call.
- **E.22 Two darts in flight simultaneously**: both exist as independent RigidBody3D. Each has own `_on_impact`. Darts do not collide with each other (`MASK_PROJECTILES` excluded from dart mask).
- **E.23 Eve dies while a dart is in flight** (revised 2026-04-22 — self-cleanup pattern): `player_died` → Failure & Respawn emits `Events.respawn_triggered(section_id)` (per ADR-0002:183). Every in-flight dart is self-subscribed to `respawn_triggered` and calls `queue_free()` on its own handler. No central ProjectileManager is involved. `enemy_killed` from any in-flight dart will NOT fire (dart is freed before impact). `GuardFireController` simultaneously transitions to IDLE via the same signal.

### Guard fire cadence

- **E.24 Guard killed while fire-cadence timer is running** (revised 2026-04-21): `GuardFireController` callbacks begin with a defensive state-check (CR-12 defensive gate). If the guard is DEAD or UNCONSCIOUS when a scheduled timer fires, the callback enters IDLE and stops its own timers. **No SAI obligation** — SAI's DEAD-entry handler does not need to stop Combat's timers. This resolves the cross-domain contract violation flagged in the /design-review.
- **E.25 COMBAT_LOST_TARGET_SEC expires same frame as Eve takes damage** (revised 2026-04-22 — synchronous reset discipline): CR-14's reset is synchronous in the `Events.player_damaged` handler. The `stop(); start(COMBAT_LOST_TARGET_SEC)` call completes inside the signal dispatch call stack, BEFORE the emit returns. Any `Timer.timeout` scheduled for the same frame fires during its own process tick (evaluating timer state as of that moment); by then the timer has been restarted and no timeout fires. **No cross-signal FIFO guarantee is needed** — synchronous mutation inside the handler is the mechanism, not connection order.
- **E.26 Guard in COMBAT-no-LOS reaches suppression_max_shots (3)** (revised 2026-04-21): Combat's `GuardFireController` enters `CAPPED` state. `CAPPED` is a silent state — no further shots fire regardless of LOS state. The guard naturally de-escalates via SAI's existing COMBAT → SEARCHING transition (triggered by `COMBAT_LOST_TARGET_SEC` expiring with no damage taken). On LOS reacquisition, `CAPPED → LOS` resets `suppression_count = 0` (fresh cycle). **No post-cap SAI content needed** — the existing SAI de-escalation path handles it.
- **E.27 Eve in kill-plane free-fall and guard cadence timer fires**: guard's ray can hit Eve mid-fall (CapsuleShape3D still present until `player_died` emits). PC F.6 `apply_damage` gates on DEAD state. Functionally unreachable at kill_plane_y = -50 m (far beyond 16 m guard fire range), but the gate exists.

### Friendly fire

- **E.28 `GUARD_FRIENDLY_FIRE_ENABLED` overridden mid-section by Mission Scripting**: guard re-reads `SectionConfig.guard_friendly_fire_enabled` on each fire (not cached at COMBAT entry). Mask is rebuilt per-shot. Mission Scripting owns the config mutation; Combat defines the per-shot query contract.
- **E.29 Guard A's friendly-fire kills guard B**: `enemy_killed(guard_B, guard_A)` emits with guard A as killer. Mission Scripting sees the correct killer (not Eve). Eve receives no Mission-Scripting kill credit. Intentional per CR-13.

### Headshot

- **E.30 Hitscan grazes body/head collider boundary**: `intersect_ray` returns single first-hit. Head Area3D is spatially above CapsuleShape3D (BoneAttachment3D at Y≈1.65 m); rays from torso-entry hit body first, rays from above hit head first. No ambiguity.
- **E.31 Blade takedown path (CR-15) never produces headshot**: CR-15 explicitly passes `is_headshot = false` regardless of guard orientation — the blade has no hit zones. Takedown uses `blade_takedown_damage = 100` via `DamageType.MELEE_BLADE`, not the 2×-multiplied body value.

### Ammo pickup

- **E.32 Pickup while magazine + reserve is at starting maximum**: excess rounds are lost. WorldItem still frees from world. Exact cap math is Inventory & Gadgets' contract to define.
- **E.33 Two guards killed on same tile**: both WorldItem drops spawn with small positional offset (Inventory authoring). Both pickable separately. No merge logic at MVP.
- **E.34 Pickup during dart reload**: pickup adds to reserve immediately (reserve += amount). In-progress reload uses the reserve snapshot captured at reload-start. Final reserve = (pre-reload-reserve − rounds-used-by-reload) + picked-up-amount.

### Respawn and save

- **E.35 Save-restore with mid-reload state**: ADR-0003 does NOT serialize mid-reload. On load `_is_reloading = false`, ammo counts restored from checkpoint snapshot. Checkpoint fires at `section_entered` (between sections), not mid-action — no partial-reload ammo loss because the checkpoint is never mid-reload.
- **E.36 Save-restore with guard killed but Mission objective not yet resolved**: **OPEN QUESTION (OQ-CD-5)** — Mission Scripting checkpoint timing affects whether a one-frame race exists between `enemy_killed` emission and objective handler execution.
- **E.37 Respawn with ammo below floor**: `max(checkpoint_snapshot, respawn_floor)` applies per F.6. Pistol restores to 8 min, dart to 4 min, rifle preserved as-is. Farmable? No — floor only triggers when genuinely below; no "free refill" exploit.

### Cross-system side-effects

- **E.38 Dart in flight enters Mission Scripting trigger volume**: dart's RigidBody3D registers `body_entered` with Area3D triggers it passes through. Mission Scripting's trigger handlers must filter by `body.is_in_group("player")` or equivalent — darts must NOT fire mission triggers. Flag for Mission Scripting GDD: trigger handlers must gate on actor type.
- **E.39 Eve in interact (`_is_hand_busy`) takes damage ≥ 10 HP**: interact cancels per PC F.6 E.6; Combat's fire gate (CR-10) was already blocking fire, so no Combat-side interaction. PC handles the cancel internally.
- **E.40 Settings toggle crosshair disabled mid-gunfight**: HUD queries the setting each frame (or reacts to `setting_changed` signal). Combat holds no state for the crosshair — toggling is purely HUD's concern. No Combat-side effect.
- **E.41 Dart fire with Eve flush against cover** (NEW 2026-04-22 — godot-specialist B14): CR-6 pre-fire occlusion check detects spawn-point-inside-world-geometry. Fire is cancelled at the call site; dry-fire click SFX plays; no ammo consumed; no `weapon_fired` emit. Prevents silent dart loss when Eve is pressed against a wall.
- **E.42 Rapid back-to-back hits on Eve exceed WCAG 3 Hz flash rate** (NEW 2026-04-22 — ux-designer BLOCKER-1): two guards each firing at 1.4 s cadence offset can land hits ~700 ms apart → 1.4 Hz sustained, or burst 3+ hits/sec during multi-guard alpha strikes. At `hud_damage_flash_duration_frames = 1` (default 16 ms) the aggregate flash rate can briefly exceed 3 Hz. HUD Core enforces a minimum inter-flash interval of `hud_damage_flash_cooldown_ms = 333` (3 Hz ceiling) — damage events arriving during the cooldown window coalesce into a single flash (the HUD latches "damage since last flash" and fires one flash per cooldown window regardless of hit count). The secondary cues (camera dip, audio SFX) are NOT rate-limited — only the visual flash is gated. Also flags first-boot photosensitivity warning as a forward-dep to Settings & Accessibility GDD (OQ-CD-12 item 7).

## Dependencies

### Upstream hard dependencies (Combat & Damage cannot function without these)

| System | Status | Interface consumed | Why hard |
|---|---|---|---|
| **Player Character** | ✅ Approved | `player.apply_damage(amount, source, damage_type)` — F.6 frozen | Combat's damage path into Eve requires this method. Signal emission (`player_damaged`, `player_health_changed`, `player_died`) is PC-owned; Combat cannot emit these directly. |
| **Stealth AI** | ✅ Approved (with pending OQ-CD-1 amendment) | `guard.receive_damage(amount, source, damage_type) -> bool is_dead`; `guard.receive_takedown(takedown_type, attacker)`; `AlertState` enum incl. new `UNCONSCIOUS` | Combat needs a guard damage intake + state-transition-to-DEAD/UNCONSCIOUS path. Takedowns delegate lethal damage back to Combat via `apply_damage_to_actor`. |
| **Signal Bus** | Designed, pending re-review | `Events.weapon_fired`, `Events.enemy_damaged`, `Events.enemy_killed`, `Events.player_damaged`, `Events.player_health_changed`, `Events.player_died` | All 6 Combat-domain signals defined in ADR-0002. Combat emits 2 (`enemy_damaged`, `enemy_killed`) directly; the other 4 come from PC/Inventory but are part of Combat's visible contract. |
| **ADR-0002 Signal Bus + Event Taxonomy** | Proposed | Signal signatures frozen | Contract frozen; any signal amendment requires TD approval. |
| **ADR-0003 Save Format Contract** | Proposed | Per-weapon ammo state serialized; per-guard state serialized | Ammo carryover (F.6 ammo economy) depends on checkpoint save format. |
| **ADR-0006 Collision Layer Contract** | Proposed | `PhysicsLayers.MASK_PROJECTILES` (layer 5), `MASK_AI` (3), `MASK_WORLD` (1), `MASK_PLAYER` (2) | Hitscan masks and projectile layers depend on this contract. |
| **Godot 4.6 Jolt 3D physics** | Engine | `PhysicsRayQueryParameters3D`, `RigidBody3D` CCD, `ShapeCast3D`, `Area3D` on `BoneAttachment3D` | Hitscan + projectile + melee cone + headshot detection all require these APIs. |

### Upstream soft dependencies (Combat enhanced, still functions without)

| System | Status | Interface | Why soft |
|---|---|---|---|
| **Audio** | ✅ Approved | Subscribes to all 6 Combat signals for SFX + music state transitions | Combat fires correctly without Audio; Audio presence is felt but does not block fire/damage mechanics. |
| **Level Streaming** | ✅ Approved | `Events.respawn_triggered(section_id: StringName)` (Failure & Respawn emits; dart + GuardFireController self-subscribe) | Used for self-cleanup of in-flight darts + GuardFireController IDLE transition on respawn. Without subscription, darts auto-free at `dart_lifetime_s = 4.0 s` anyway — visual artifacts only. |
| **Input** | Designed | `Fire`, `Aim`, `Reload`, `WeaponSwitch`, `Melee`, **`Takedown`** (NEW 2026-04-22) input actions | Combat reads these per-frame. Takedown is a new dedicated action for blade takedowns (CR-3 revised). Input GDD forward-dep: add Takedown action + default bindings (kbd `F`, gamepad Y). |
| **ADR-0001 Stencil Contract** | Proposed | Tier 0 for muzzle flashes + hit sparks; Tier 3 for dart mesh | Aesthetic ties — Combat's VFX would render without stencil tagging but would not match the outline-tier grammar. Art Bible §8K amendment (flagged) formalizes. |
| **ADR-0005 FPS Hands Outline** | Accepted (Amendment active) | Weapon mesh in Eve's hand inherits SubViewport outline | Weapon visual outline. Combat does not render the hands pipeline — it supplies the weapon mesh that renders inside it. |

### Downstream hard consumers (systems that require Combat)

| System | Status | Interface | Blocker? |
|---|---|---|---|
| **Failure & Respawn** | Not Started | Subscribes to `player_died(cause: DeathCause)`; reads `respawn_floor_pistol`, `respawn_floor_dart` constants | **YES** — cannot author until Combat ships `DeathCause` enum + ammo-floor constants. |
| **HUD Core** | Not Started | Subscribes to `player_health_changed`, `weapon_fired`, `enemy_damaged` for ammo readouts + health numeric + hit-flash | **YES** — HUD ammo/health readouts require Combat's weapon Resource schema + signal emissions. |
| **Stealth AI — guard return-fire timer** | ✅ Approved | Subscribes to `Events.player_damaged` for CR-14 timer reset | Soft: SAI's COMBAT → SEARCHING 8 s timer works without Combat's emit (timer just never resets early), but the design intent breaks. |
| **Mission & Level Scripting** | Not Started | Subscribes to `enemy_killed(enemy, killer)` for objective progression ("eliminate all hostiles") | Hard for shootout-mandatory missions; soft for pure stealth missions. |

### Downstream soft consumers (Combat optional)

| System | Status | Interface | Usage |
|---|---|---|---|
| **Dialogue & Subtitles** | Not Started | May subscribe to `enemy_killed` for banter-line triggers ("They got Kovacs!") | Atmospheric enhancement. |
| **Civilian AI** | Not Started | May subscribe to `weapon_fired`, `enemy_killed` for panic reactions | Civilian panic triggers on shots/kills — Combat emits; Civilian AI decides behavior. |
| **Analytics (future)** | Not in scope | Kill counts, damage dealt, weapon usage | Telemetry; not MVP. |

### Forward dependencies (systems Combat references that don't yet exist)

These are stubbed in this GDD with placeholder contracts:

| Forward system | Contract Combat specifies | Stub plan |
|---|---|---|
| **Inventory & Gadgets** | Weapon Resource schema (`base_damage`, `fire_rate_sec`, `magazine_size`, `damage_type`); `WorldItem` drop entity for ammo pickups; weapon-switch input handler | Inventory GDD authors the Resource schema; Combat reads Resource fields. For tests, a stub Weapon Resource in `tests/fixtures/` with hard-coded values. |
| **HUD Core** | Subscribes to `player_health_changed` + `weapon_fired` + `enemy_damaged`; reads weapon Resource for ammo counts | Combat fires signals with or without HUD Core shipped. HUD can subscribe lazily. |
| **Failure & Respawn** | `respawn_floor_pistol_total = 16`, `respawn_floor_dart_total = 8` (TOTAL, not mag-only); first-death-per-checkpoint flag; `restore_weapon_ammo(snapshot, floor, max_cap)` contract | Combat owns the constants + function signature; Failure & Respawn GDD implements + cites. |
| **Mission & Level Scripting** | `SectionConfig.guard_friendly_fire_enabled` field consulted per-shot; trigger volumes must filter dart body types; boss HP contract (if > 100 HP, specify a bespoke non-lethal takedown slot) | Combat GDD defines the query contract; Mission Scripting authors the SectionConfig Resource + boss HP value. |
| **Rifle entity** | Rifle weapon Resource at pickup-only spawn points; `rifle_pickup_reserve = 6` standard drop | Inventory & Gadgets authors the Rifle Resource; Level Streaming's section registry places pickup locations. |
| **Settings & Accessibility** | 7 contracts: crosshair opt-out (UI-1), Enhanced Hit Feedback toggle (V.6), Damage Flash Duration slider (G.8), Damage Flash Cooldown ms (G.8 NEW — photosensitivity rate-gate), `Settings → HUD → Crosshair` duplicate entry (UI-6), ADS tween duration multiplier (vestibular — UI-4), first-boot photosensitivity warning | Settings & Accessibility GDD owns persistence + UI placement; Combat defines behavioral contracts. |
| **Input GDD** | Add `Takedown` input action (NEW 2026-04-22) with default bindings: keyboard `F`, gamepad Y/△. Must NOT be bindable to the same key as `Fire` (validation rule) | Input GDD authoring must include Takedown in InputMap. |

### ADR dependencies (consumed, not authored here)

| ADR | Status | Combat's consumption |
|---|---|---|
| **ADR-0001 Stencil ID Contract** | Proposed | Muzzle flashes + impact sparks = tier 0 (no outline); dart projectile + trail = tier 3 LIGHT. **ADR-0001 needs clarification added: explicit VFX-exempt language** (flagged in Art Bible §8K amendment). |
| **ADR-0002 Signal Bus + Event Taxonomy** | Proposed | 6 Combat-domain signals; `CombatSystem.DamageType` and `CombatSystem.DeathCause` enum ownership. **ADR-0002 amendment pending** — bundles: (a) SAI's severity param + `takedown_performed` 3-arg sig (prior); (b) update signal type annotations from `CombatSystem.DeathCause` → `CombatSystemNode.DeathCause` (prior); (c) **NEW 2026-04-22**: if OQ-CD-1 SAI amendment adds LOS + takedown-prompt accessors, declare them in ADR-0002's accessor-convention section. Also: PC GDD (Approved) + Audio GDD (Approved) reference `CombatSystem.DeathCause` in frozen signatures and will need a coordinated type-rename pass; producer should sequence this with the ADR-0002 amendment landing. |
| **ADR-0003 Save Format Contract** | Proposed | Per-weapon ammo + per-guard state serialization; respawn floor applied at restore (logic lives in Failure & Respawn, format lives here). |
| **ADR-0004 UI Framework** | Proposed | HUD crosshair rendering uses the UI Framework's input-context stack (crosshair visible only when InputContext == GAMEPLAY). |
| **ADR-0006 Collision Layer Contract** | Proposed | `MASK_PROJECTILES`, `MASK_AI`, `MASK_WORLD`, `MASK_PLAYER` all consumed via `PhysicsLayers` constants. |

### Bidirectional consistency checks

This GDD is bidirectionally consistent with:

- ✅ **Player Character** lists "Combat & Damage" in its Dependencies (§F) as a downstream consumer that calls `apply_damage`. Verified at PC §F.
- ✅ **Stealth AI** lists "Combat & Damage" as a forward dep for `apply_damage_to_actor` + guard `receive_damage`. SAI GDD §Dependencies confirms. **New: SAI needs to list `UNCONSCIOUS` AlertState consequence + `receive_damage -> bool` amendment — bundled in OQ-CD-1 amendment.**
- ✅ **Audio** lists 6 Combat signals in its §Combat domain table. Verified at Audio §3.2.
- ⏳ **Signal Bus** GDD enum-ownership list needs `CombatSystem.DamageType` + `CombatSystem.DeathCause` added. Bundled as the pending Signal Bus touch-up (SAI + Combat both flag this).
- ⏳ **HUD Core** (Not Started) will list Combat as upstream.
- ⏳ **Failure & Respawn** (Not Started) will list Combat as upstream.
- ⏳ **Mission & Level Scripting** (Not Started) will list Combat as upstream for the friendly-fire config + enemy_killed subscription.

## Tuning Knobs

Combat & Damage exposes **32 tuning knobs** across 5 categories. The categorization distinguishes knobs designers should adjust during playtest (Designer-facing) from those that are cross-formula correctness parameters (Correctness — change carefully, they propagate) and from cross-system constants (consumed by other GDDs).

### G.1 Weapon damage (Designer-facing)

What they control: per-weapon TTK and damage balance.

| Knob | Default | Safe Range | Breaks if too low | Breaks if too high |
|---|---|---|---|---|
| `silenced_pistol_base_damage` | 34 | [28, 45] | <28 = 4+ shot body kill, combat drags | >45 = 2-shot body kill, removes TTK tension |
| `blade_takedown_damage` (NEW) | 100 | [100, 150] | <100 = takedown fails to kill | >150 = no functional impact (overkill on 100 HP). **Replaces** `silenced_pistol_takedown_damage` — takedowns now route to the new blade weapon (CR-3 revision 2026-04-21) |
| `dart_damage` | 150 | [100, 200] | <100 = guards survive darts (breaks non-lethal contract) | >200 = no functional impact |
| `rifle_base_damage` | 120 | [100, 150] | <100 = no 1-shot body kill niche, rifle becomes just "louder pistol" | >150 = no functional impact (already 1-shot) |
| `fist_base_damage` | **40** *(reworked 2026-04-22)* | **[34, 50]** | <34 = 4+ swing KO, drifts back toward Matt Helm slapstick territory (§V.8 anti-pattern) | >50 = 1-swing KO, fists become OP vs dart gun / blade, breaks weapon roster differentiation |
| `guard_pistol_damage_vs_eve` | 18 | [14, 20] | <14 = Eve takes 7+ hits, combat feels weightless | >20 = Eve dies in 4 hits, Pillar 3 "5+ hit survivability" breaks (AC-CD-14.1 invariant) |

**Interaction warning**: `silenced_pistol_base_damage` and `blade_takedown_damage` are INTENTIONALLY DIFFERENT constants on DIFFERENT weapons. A designer tuning pistol base damage should not affect blade-takedown lethality — the blade owns takedowns; the pistol owns gunfights. This separation preserves the 1-shot-lethal takedown contract regardless of gunfight TTK tuning.

### G.2 Guard fire cadence (Designer-facing)

What they control: the rhythm of guard return fire; Pillar 3 (fail-forward) survivability feel.

| Knob | Default | Safe Range | Breaks if too low | Breaks if too high |
|---|---|---|---|---|
| `guard_first_shot_delay_s` | 0.65 | [0.4, 1.0] | <0.4 s = no reaction window, combat feels punishing | >1.0 s = guards feel helpless / intent unclear |
| `guard_los_cadence_s` | 1.4 | [1.0, 2.0] | <1.0 s = overlapping fire, Eve can't track | >2.0 s = guards feel lethargic |
| `guard_suppression_cadence_s` | 2.8 | [2.0, 4.0] | <2.0 s = suppression ≈ LOS fire, cap pointless | >4.0 s = 3 shots over 12 s = guard barely engaged |
| `guard_suppression_max_shots` | 3 | [2, 5] | 1 = guard gives up too fast | 6+ = suppression outlasts the 8 s de-escalation window |

**Invariant**: `guard_suppression_cadence_s >= 1.5 × guard_los_cadence_s`. Breaking this removes the "slower while uncertain" design intent.

### G.3 Guard accuracy (Designer-facing)

What they control: hit probability as function of Eve's movement + range; Pillar 3 "theatrical, not twitch-shooter" feel.

| Knob | Default | Safe Range | Breaks if too low | Breaks if too high |
|---|---|---|---|---|
| `guard_spread_stationary_deg` | 2.0 | [1.0, 4.0] | <1° = near-perfect aim, no cover incentive | >4° = guards miss stationary Eve at 5 m, absurd |
| `guard_spread_walking_deg` | 3.5 | [2.5, 5.0] | — | — |
| `guard_spread_crouched_deg` | 3.0 | [2.0, 4.5] | — | — |
| `guard_spread_sprinting_deg` | 6.0 | [4.0, 9.0] | <4° = sprint feels dangerous, no escape vector | >9° = sprint near-immune, breaks risk/reward |
| `guard_cover_modifier_deg` | 4.0 | [2.0, 6.0] | <2° = cover feels pointless | >6° = cover = invincibility |
| `guard_range_falloff_start_m` | 8.0 | [6.0, 10.0] | — | Must stay below `guard_range_falloff_end_m` |
| `guard_range_falloff_end_m` | 16.0 | [12.0, 20.0] | — | >20 m stretches tension absurdly |
| `guard_range_falloff_max_deg` | 3.0 | [1.5, 5.0] | <1.5° = range meaningless | >5° = long-range guards are jokes |
| `eve_spread_deg` | 0.0 | [0.0, 1.5] | — | >1.5° = Eve's accuracy feels broken (arcade-period feel violated) |

**Prototype-gated**: `eve_spread_deg`. Tier 1 playtest may introduce a sprint-fire tax (0.5–1.0° on SPRINTING only); default 0.0° = perfect aim preserved.

### G.4 Projectile + detection physics (Correctness — change carefully)

What they control: dart behaviour, headshot hit-zone.

| Knob | Default | Safe Range | Notes |
|---|---|---|---|
| `dart_speed_m_s` | 20.0 | [15, 30] | Below 15 = visually sluggish; above 30 = reads as hitscan |
| `dart_lifetime_s` | 4.0 | [3.0, 6.0] | Derived max range = speed × lifetime = 80 m at defaults |
| `dart_gravity_scale` | 0.0 | {0.0, 0.5} | 0.0 = straight flight; 0.5 = subtle arc (Tier 1 playtest option) |
| `head_zone_radius_m` | 0.15 | [0.10, 0.20] | Below 0.10 = headshots feel lottery; above 0.20 = overlaps shoulder area |
| `head_zone_y_offset_m` | 1.65 | [1.55, 1.75] | Bone-attached via BoneAttachment3D; adjust only if guard skeleton deviates from registry `eye_height_m = 1.7` |
| `interact_damage_cancel_threshold` | 10 HP | [5, 20] | Owned by PC GDD — Combat consumes. Consistent with CR-9 ADS cancel + reload cancel. |

### G.5 Ammo economy (Designer-facing — cross-system)

What they control: Pillar 2 (Discovery Rewards Patience) enforcement via scarcity.

| Knob | Default | Safe Range | Breaks if too low | Breaks if too high |
|---|---|---|---|---|
| `pistol_magazine_size` | 8 | [6, 12] | <6 = constant reloads, breaks Deadpan Witness register | >12 = reload is never a beat, removes theatrical pause |
| `pistol_starting_reserve` | 32 | [16, 48] | <16 = aggressive player dry by Section 2 | >48 = softens Pillar 2 too far; depletion curve stops producing observation reward |
| `dart_magazine_size` | 4 | [3, 6] | 3 = uncomfortable | >6 = spray darts, non-lethal premium collapses |
| `dart_starting_reserve` | 16 | [8, 24] | <8 = ghost player can't KO tutorial chokepoints even with break-even | >24 = Pillar 2 non-lethal premium collapses; placed caches become irrelevant |
| `rifle_magazine_size` | 3 | [2, 5] | 2 = cannot use rifle tactically | >5 = rifle too generous |
| `rifle_pickup_reserve` | 6 | [3, 9] | <3 = rifle pickup worthless | >9 = rifle too dominant |
| `guard_drop_pistol_rounds` | **3** *(NOLF1 revision 2026-04-22 from 8)* | [2, 5] | <2 = aggressive player softlocks by Section 3 | >5 = ammo-positive per guard, Pillar 2 collapses to late-game cap drift |
| `guard_drop_rifle_rounds` | 3 | [1, 5] | <1 = no point carrying rifle | >5 = rifle ammo becomes farmable |
| `guard_drop_dart_on_dart_ko` | 1 | {1} | — | Fixed at 1 — break-even invariant. |
| `guard_drop_dart_on_fist_ko` | 0 | {0} | — | Fixed at 0 — fist KO cannot farm darts (closes fist-farm loop). |

**Invariants**: `guard_drop_dart_on_dart_ko == 1` and `guard_drop_dart_on_fist_ko == 0`. Additionally, `guard_drop_pistol_rounds < pistol_body_shots_per_kill` (`3 < 3` at default — break-even threshold; miss rate + reload overhead make realized drops net-negative). Any value ≥ 5 would make Aggressive ammo-positive, breaking Pillar 2. See F.6 + AC-CD-12.2.

### G.6 Respawn floor (Cross-system — consumed by Failure & Respawn)

| Knob | Default | Safe Range | Notes |
|---|---|---|---|
| `respawn_floor_pistol_total` | 16 | [8, 32] | TOTAL (magazine + reserve) minimum at respawn. Consumed by Failure & Respawn at restore. Prevents softlock; applied ONLY on first death per checkpoint (see F.6 floor anti-farm). |
| `respawn_floor_dart_total` | 8 | [4, 16] | Same — TOTAL minimum dart reserve at respawn. |
| `pistol_max_reserve` | 48 | [24, 64] | Hard cap on reserve ammo; pickup past cap loses excess (E.32 + Inventory forward dep). Also used by `clamp()` in restore_weapon_ammo to sanitize corrupted snapshots. |
| `dart_max_reserve` | 24 | [16, 32] | Hard cap on dart reserve; same function as pistol cap. |

### G.7 Behavior flags (Designer-facing)

| Knob | Default | Range | Notes |
|---|---|---|---|
| `guard_friendly_fire_enabled` | `true` | {true, false} | Per-section overridable via Mission Scripting `SectionConfig`. Global default on for comedy (Pillar 1). |

### G.8 Accessibility (NEW — added 2026-04-21; expanded 2026-04-22 per ux-designer BLOCKER-1/2/3)

| Knob | Default | Safe Range | Notes |
|---|---|---|---|
| `hud_damage_flash_duration_frames` | 1 | [1, 6] | Health-numeric white flash duration per hit. Default 1 frame preserves Deadpan Witness restraint; 6-frame max (100 ms) sits above the ~50 ms conscious-perception threshold. Player-exposed via `Settings → Accessibility → Damage Flash Duration`. |
| `hud_damage_flash_cooldown_ms` | **333** *(NEW 2026-04-22)* | {333 fixed at ceiling} | Minimum interval between consecutive visual flashes (3 Hz WCAG 2.3.1 ceiling for photosensitivity safety). During cooldown, additional damage events coalesce into a single deferred flash at cooldown end. Fixed at 333 ms; not player-tunable below (safety). Can be raised (≤1000 ms) if player finds even 3 Hz uncomfortable — forward-dep Settings & Accessibility. |
| `crosshair_dot_size_pct_v` | **0.19%** *(NEW 2026-04-22 — resolution-independent)* | [0.15%, 0.30%] | Crosshair dot size as percentage of viewport vertical resolution. At 1080p = ~2 px; at 1440p = ~3 px; at 4K = ~4 px. Clamped min 3 physical pixels max 12 physical pixels in implementation. Replaces the pre-revision "~4 px at 1080p" fixed-pixel spec per ux-designer BLOCKER-2. |
| `crosshair_halo_style` | **tri_band** *(NEW 2026-04-22 per ux-designer BLOCKER-3)* | {none, parchment_only, tri_band} | Halo stroke composition. `tri_band` = Parchment outer + Ink Black inner bands (each 1 physical px), guaranteeing ≥3:1 contrast against both light and dark backgrounds. `parchment_only` is the pre-revision spec (fails against sepia exterior per ux-designer BLOCKER-3); kept as an option for players who prefer minimal halo. `none` disables halo entirely (Ink Black dot alone). |
| `enhanced_hit_feedback_enabled` | `false` | {true, false} | Opt-in non-diegetic direction pulse per V.6 + UI-5. Default OFF preserves Pillar 5 diegetic fiction; ON surfaces damage-direction signal for hearing-impaired players. Direction model: **4-quadrant** (NE / NW / SE / SW pulse on corresponding screen corner) based on angle(eve_forward, eve_position → shot_origin) at hit frame. Simpler than continuous radial gradient; testable. Owned by Settings & Accessibility GDD. |
| `crosshair_enabled` | `true` | {true, false} | Opt-out toggle. When false, dot + halo both hidden. Surfaced in Settings under BOTH Accessibility AND HUD paths (UI-6). |

### Tuning knob ownership

- **Combat Designer** owns G.1 weapon damage, G.3 accuracy tuning, G.5 ammo economy.
- **Art Director** owns G.4 projectile + VFX physics — these have visual implications that the art team must sign off on.
- **Systems Designer** owns G.2 guard cadence + G.6 respawn floor (mathematical balance, not aesthetic).
- **Level Designer** owns per-section overrides via `SectionConfig` (friendly fire, placed pickup counts).
- **Accessibility lead** does NOT own any Combat knobs — accessibility concerns (crosshair toggle) live in Settings & Accessibility GDD, not here.

### Knobs NOT exposed (designer-forbidden)

These values are hard-coded in the formulas and must NOT be designer-tunable:

- `H` (headshot multiplier of 2.0 in F.1) — changing this requires redesigning TTK math.
- Hitscan collision masks (`MASK_AI | MASK_WORLD` for Eve, + `MASK_PLAYER` for guards) — owned by ADR-0006, not per-encounter tunable.
- Fire-cadence timer node type (per-guard `Timer` on idle tick) — implementation, not design.
- `sample_cone_direction` sampling method (sqrt(randf)) — formula-correctness, not tuning.
- Signal emission order (`enemy_damaged` before `enemy_killed`) — contract invariant.

## Visual/Audio Requirements

### Governing principle (Design Test from Section B)

**Does this feature change Eve's register, or the world's around her?** Every visual or audio choice in combat must pass this test. Cut (Eve's register): red vignette, hit marker, "LOW HEALTH" text, damage-direction indicator, kill cam. Keep (world's register): clock-tick at ≤25 HP, silenced-pistol mechanical ratchet, guard grunt-and-crumple, camera dip, period-authentic muzzle flash.

### V.1 Muzzle flashes (per weapon)

| Weapon | Style | Duration | Color | Stencil tier |
|---|---|---|---|---|
| Silenced pistol | Soft near-white warm bloom at barrel tip (radius ≤½ barrel diameter) | 3–4 frames (50–67 ms) | Warm white fading to faint yellow-cream `#FFF8E0` | **0 (no outline)** — muzzle flash IS a light event |
| Dart gun | Compressed-air heat-haze distortion shimmer at barrel tip (~8 px at 1080p) | 2 frames | — (no color — distortion) | 0 |
| Rifle | Hard center-white bloom ringed by warm amber | 6–8 frames | Core `#FFFFFF`; ring `#E8A020` (Paris Amber, Art Bible §4.3) | 0 |
| Fists | No flash (no combustion) | — | — | — |

**Period authenticity:** flashes read as practical-camera overexposure artifacts, not designed VFX moments. Reference frame: NOLF1's corridor silhouettes, *Our Man Flint*'s restaurant fight.

### V.2 Bullet tracers / projectile visibility

- **Silenced pistol (hitscan):** NO tracer. Period-authentic (subsonic suppressed rounds are invisible). Player infers hit from audio + guard reaction. Tier N/A.
- **Dart gun (projectile):** Visible small needle-shape mesh, ~6–8 cm, blunt-finned tail, Eiffel Grey `#6B7280` body with Paris Amber `#E8A020` needle tip (ampoule-catching-light aesthetic). Faint 3-frame motion-blur smear trail suggests forward motion (comic-panel smear, not sci-fi light trail). **Tier 3 (LIGHT, 1.5 px outline)** — dart is a world object, readable but not hero.
- **Rifle (hitscan):** Thin 2 px white `#FFFFFF` scan line, visible 3 frames from barrel to impact, then vanishes. Reads as photographic light-drag artifact — "something fast passed through frame." Distinguishes rifle's louder register without becoming sci-fi.

### V.3 Hit sparks / impact direction

- **World surface hits** (wall, floor, metal, marble): 3–5 Eiffel Grey `#6B7280` spark particles, 6-frame lifetime, spraying perpendicular to surface normal, 12–16 cm spread. Optional small chip-scar decal persists (tier 3 LIGHT, time-limited texture swap). **No bright orange sparks. No persistent bullet-hole decals.**
- **Guard body hits:** No blood. Silhouette shudder — guard's pose snaps back by small angular impulse on hit frame, recovers over 3 frames. Audio grunt + crumple (Audio GDD). Communication via shape change (Art Bible Principle 1 — Ink Before Texture). Hit sparks: NONE (guard's body is not a stone surface).
- **Guard head hits (headshot, 2× damage):** No hit marker. Silhouette shudder amplitude ~1.5× body-hit. Collapse animation enters 4–6 frames faster than standard lethal hit. Perceptive players recognize faster collapse as crit signal; inattentive players still see the kill. Pillar 5 holds — no floating text, no crosshair flash, no UI element.

### V.4 Body-drop grammar (Composed Removal)

| Kill method | Phase 1 | Phase 2 | Final pose | Duration |
|---|---|---|---|---|
| Silenced pistol (lethal) | 12-frame standing hold (knees soften, silhouette holds) | 20-frame guided fall to side | Compact fetal-adjacent, face-away, helmet-dome visible | 32 frames (535 ms) |
| Dart gun (non-lethal sleep) | Gradual sag (no phase break) | Slide down wall OR fold to sitting → tip to side-lie | Seated-slump — legs extended (involuntary-relaxation grammar) | 40 frames (667 ms) |
| Fists (KO) | 1–6 frame stagger in blow-direction | Fold to same seated-slump as dart | Same seated-slump as dart | 30 frames (500 ms) — 10 frames faster than dart |

**Composed Removal invariant:** every drop must pass Deadpan Witness test. Does the camera snap to the fallen body? No. Does a "kill confirmed" prompt appear? No. The body drop is punctuation, not celebration. Outlines persist on fallen bodies — tier MEDIUM remains on DEAD guards and UNCONSCIOUS guards (a corpse/sleeper is still a world object another guard can find).

**OQ for AI Programmer:** guard collapse's final pose ends in side-lie with face AWAY from Eve's approach vector. This requires SAI passing the approach vector to the body-drop animator at DEAD/UNCONSCIOUS state entry. Bundled into OQ-CD-1 (SAI amendment).

### V.5 Blood / gore policy

**No blood at MVP. Fully NOLF1.** Bureaucratic violence — Eve removes an obstacle, which does not leave stains. Pillar 1 (comedy lands through matter-of-factness), Pillar 5 (period-authentic restraint), Art Bible §1 Principle 1 (Ink Before Texture — communication via shape change, not surface effect). No stenciled blood. No pooling. No hit decals on bodies. Decision locked; no revisit before post-MVP.

### V.6 Eve's hit feedback stack (the "absence" that's present)

Four registers change on hit by default. A fifth is available as opt-in accessibility.

| Register | Change | Owner |
|---|---|---|
| **Health numeric** | **Configurable-duration flash** to `#FFFFFF`, return to Parchment (above 25%) or Alarm Orange (below 25%) per Art Bible §7D. Default 1 frame; tunable `hud_damage_flash_duration_frames ∈ [1, 6]` (see §G). Secondary cue at 25 HP threshold: font weight shifts Regular → Bold (colorblind-safe secondary to the hue shift) | HUD Core (existing §7D spec) |
| **Camera** | 3° downward dip over 6 frames, recovery over 10 frames (world's register — the *hit* moved her, not a subjective fear-state) | PC (existing hard-landing dip node; separate tuning knob for hit) |
| **Audio** | 150 ms hit SFX (non-spatial, Audio GDD §Combat catalog). Below 25 HP: clock-tick loop at 90 bpm on UI bus | Audio (existing subscriber to `player_damaged` + `player_health_changed`) |
| **Period-authenticity cut** (DEFAULT) | NO damage vignette. NO FOV nudge. NO "LOW HEALTH" text. NO damage-direction indicator. NO hit marker. | Forbidden patterns (Pillar 5 governs diegetic fiction) |
| **Enhanced Hit Feedback** (OPT-IN, Settings → Accessibility) | Subtle desaturated warm-grey pulse at a specific screen-corner (**4-quadrant model** — NE / NW / SE / SW — based on angle between Eve's forward vector and the shot origin at hit frame). 15% edge opacity, 120 ms duration, NOT a red vignette. Surfaces damage-direction information for hearing-impaired players. Off by default. | Settings & Accessibility GDD (forward dep); Combat supplies the behavioral contract here |

**Accessibility carve-out rationale (creative-director ruling, 2026-04-21)**: Pillar 5 (Period Authenticity Over Modernization) governs *diegetic period fiction* — no GPS markers, no modern UX paternalism, no kill cams. It does NOT govern accessibility scaffolding. A hearing-impaired player who cannot perceive the 150 ms hit SFX OR the ≤25 HP clock-tick has only two remaining hit signals: the 1-frame HUD flash (16 ms, below typical conscious-perception threshold) and the 3° / 100 ms camera dip. Both are low-salience under combat stress. Without an opt-in carve-out, Pillar 5 becomes a structural access barrier.

**Enhanced Hit Feedback specification (revised 2026-04-22 — 4-quadrant direction model)**: the opt-in pulse is INTENTIONALLY non-diegetic — it reads as an accessibility aid, not as a "damage vignette" Eve sees. It is desaturated (not red), brief (120 ms), only 15% edge opacity, and localized to ONE of four screen corners (NE/NW/SE/SW) based on the angle between Eve's forward vector and the shot origin at hit frame. The 4-quadrant model is deliberately coarse — it communicates "shot came from your back-right quadrant" not a precise bearing. This is sufficient for accessibility (alert the player where to turn) without producing a high-fidelity targeting overlay that would cross into hit-marker territory. When the setting is OFF (default), no such pulse is ever rendered — the out-of-box experience is identical to the period-authenticity cut. When ON, the toggle changes ONLY this one signal; all other Pillar 5 forbidden patterns (red vignette, hit marker, LOW HEALTH text, continuous damage arrow) remain forbidden.

### V.7 Reload + weapon-switch visual grammar

**Reload (Deadpan Witness grammar):** No dramatic eject-and-slap. No magazine arc. No looking at the gun. Three-beat functional motion:
1. Support hand to grip; firing hand finds spare magazine
2. Magazine releases, drops out of frame (no showboating)
3. Fresh magazine enters with quiet mechanical seat

Courrèges navy sleeve (§5.1) visible in first frames — establishes Eve identity. Finger positions composed (surgeon/card-dealer reference), not splayed/action-hero. Reference: Coburn's Flint handling objects as beneath the drama of the scene.

**Weapon switch:** Instant holster/draw — no 600 ms intermediate animation. Eve does not theatrically announce the switch. Ammo HUD numeral updates on the same frame as the switch. No weapon-zoom-to-camera flourish.

**FPS hands carve-out (ADR-0005):** weapon mesh in hands is in SubViewport at FOV 55° with inverted-hull outline (Tier-HEAVIEST equivalent, 4 px at 1080p). Weapon outline follows mesh normals throughout reload motion — occluded/visible portions handle themselves.

### V.8 Period-authenticity north stars

- *Our Man Flint* (1966), restaurant fight — "composed violence" reference. Coburn never hurries. Scene returns to normal immediately after.
- *The Avengers* (1965–66, ITV), Emma Peel fights — brisk, theatrical, never gory. Opponents fold and lie still. Camera does not linger. Fights are punctuation.
- Saul Bass title design — restraint is the style. Held frames, then a cut.
- *Matt Helm* films — cautionary reference (slapstick combat). If combat reads as goofy, it's gone too far Helm.

### V.9 Art Bible amendments required

(Flagged by art-director specialist — not new sections, extensions of existing.)

1. **§4.4 UI/HUD Palette:** add `#FFFFFF` as transient-only HUD color (1-frame hit flash; never held state).
2. **§7D Animation Feel:** add camera-dip hit feedback spec (3°, 6 frames dip / 10 frames recovery; separate tuning knob from hard-landing).
3. **NEW §8K VFX Asset Class — Combat Feedback:**
   - `vfx_muzzle_[weapon]_flash_[size].png` — sprite billboard, tier 0
   - `vfx_bullet_impact_spark_small.png` — particle sprite, tier 0
   - `vfx_dart_trail_loop_small.png` — motion-blur smear, tier 3
   - `vfx_dart_needle_projectile.glb` — projectile mesh, tier 3, ≤60 tris
   - Establishes: all combat VFX are tier 0 (no outline) EXCEPT dart projectile + trail (tier 3).
4. **§3.4 Hero Shapes:** add one-sentence clarification that fallen-guard silhouettes must remain readable at mid-distance — collapse pose must not place body in silhouette-identical position to environment geometry.

---

**📌 Asset Spec flag:** After the art bible amendments above are approved, run `/asset-spec system:combat-damage` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

### UI-1 Crosshair (revised 2026-04-22 — resolution-independent sizing + tri-band halo)

**Rationale.** The crosshair is an accessibility affordance, not a diegetic element. The Section B Design Test is NOT applied here — see the Design Test "Scope" note. Kept honest by being OPT-OUT.

**Specification (revised 2026-04-22):**

- Dot color Ink Black `#1A1A1A`.
- **Dot size: `crosshair_dot_size_pct_v = 0.19%` of viewport vertical resolution** (approx. 2 px at 1080p, 3 px at 1440p, 4 px at 4K), clamped `min 3 physical px, max 12 physical px`. Replaces the prior "~4 px at 1080p" fixed-pixel spec that failed at 4K sub-pixel rendering (ux-designer BLOCKER-2).
- **Halo: tri-band** (`crosshair_halo_style = tri_band`, default) — 1 px Parchment `#E8DFC8` outer ring + 1 px Ink Black `#1A1A1A` inner ring. The tri-band guarantees ≥3:1 contrast against BOTH light backgrounds (Ink Black inner band dominates) AND dark backgrounds (Parchment band dominates). Resolves ux-designer BLOCKER-3 — the pre-revision single-Parchment halo failed against sepia exterior scenes (~1.1:1 contrast).
- **Enabled by default** (accessibility-first).
- Opt-out via `Settings → Accessibility → Crosshair` AND duplicate entry at `Settings → HUD → Crosshair` (UI-6). Single source of truth (`Settings.crosshair_enabled`), two discovery paths.
- Does NOT expand/contract with movement.
- Does NOT change color on enemy hover.
- Does NOT hit-marker flash on kill.
- Hidden when `InputContext != GAMEPLAY` (menu, document overlay, cutscenes, loading, pause).

**Why keep it on by default?** Practical: most players expect a crosshair and removing it creates needless friction on a first boot. Players who want a fully period-immersed experience can opt out in one click. Players who need the crosshair for motor/visual accommodation have it by default. The Design Test does not apply (see §B scope note).

**Implementation ownership:** HUD Core renders the crosshair widget; Combat has no direct UI responsibility beyond specifying the behavior. HUD Core consumes `Settings.crosshair_enabled` + `crosshair_dot_size_pct_v` + `crosshair_halo_style` from the Settings & Accessibility GDD.

### UI-2 Ammo counter

- Numeric readout of current magazine + reserve per weapon (format: `8 / 32`)
- Updates within 1 physics frame of fire / reload / pickup / weapon-switch
- No animation, no progress bar, no fade
- **Fists-equipped state displays `— / —`** (em-dashes, not digits, not hidden). Preserves the "something is equipped" signal for the player; hidden-widget approach was rejected as a silent-transition UX failure.
- **Takedown blade equipped state displays `∞`** (single glyph). Communicates "no ammo limit" without misleading digit count.

**Implementation ownership:** HUD Core renders; reads `weapon.magazine_size`, current magazine, and reserve from Combat's inventory state.

### UI-3 Health numeric (revised 2026-04-21 — colorblind secondary cue + configurable flash)

- Existing readout per Player Character GDD §UI (owned by PC + HUD Core)
- Combat contributes: `player_health_changed` signal emission (via PC's internal emit in F.6), drives the damage flash
- **Flash duration** is configurable via `hud_damage_flash_duration_frames` knob (G.8), default 1 frame, safe range [1, 6]. Accessibility opt-in via Settings → Accessibility → Damage Flash Duration.
- **Flash rate-gate (NEW 2026-04-22 — photosensitivity)**: a minimum inter-flash interval of `hud_damage_flash_cooldown_ms = 333` (3 Hz ceiling per WCAG 2.3.1) is enforced by HUD Core. During cooldown, additional damage events coalesce into a single deferred flash at cooldown end. Audio SFX + camera dip are NOT rate-limited — only the visual flash is gated.
- Below 25 HP: color shifts to Alarm Orange (Art Bible §4.4, PC GDD)
- **Colorblind-safe secondary cue** (NEW): at the 25 HP threshold, the numeric's font weight also shifts from Regular to Bold. This is a pure typographic change readable by all players regardless of color perception. No period-authenticity conflict — typographic weight shift is era-appropriate. Art Bible §7D amendment flagged in V.9.

**Implementation ownership:** PC + HUD Core. Combat is a signal producer, not a UI owner.

### UI-4 ADS reticle overlay (rifle only)

- Faint optical-scope-style reticle (period-appropriate crosshairs + ranging marks)
- Fades in during ADS entry (200 ms), fades out during ADS exit (150 ms)
- Replaces the crosshair dot during ADS
- Hidden when non-rifle weapon is equipped
- **Motion-sickness forward dep** (NEW): the ADS FOV tween (85° → 55°) is a core gameplay mechanic, not decoration. It is NOT subject to a general `Settings → Accessibility → Reduce Motion` toggle. However, Settings & Accessibility GDD should consider a separate `ads_tween_duration_multiplier` knob to let vestibular-sensitive players extend the tween (slower FOV change = lower motion intensity). Flagged as forward dep — Combat does not implement, but the tween duration must be knob-driven in the HUD Core implementation so Settings can consume it.

**Implementation ownership:** HUD Core renders; Combat signals the ADS state via a combat-state accessor on the player character.

### UI-5 Forbidden UI (Pillar 5 — Period Authenticity) + Accessibility carve-out

**Always forbidden (diegetic fiction — Pillar 5):**

- Damage-edge red vignette
- Hit marker crosshair flash
- Damage-direction indicator (arrow / edge glow in SATURATED colors / screen highlight)
- "LOW HEALTH" text warning
- Kill cam / slow-mo kill feed
- Floating damage numbers
- Headshot confirmation popup

**Conditionally rendered via opt-in accessibility toggle (Settings → Accessibility → Enhanced Hit Feedback, default OFF):**

- Subtle desaturated radial-edge pulse (15% opacity, 120 ms, warm-grey) locating the incoming shot direction. Explicitly NOT a red vignette; intentionally reads as accessibility aid not Eve's subjective state. See V.6 Enhanced Hit Feedback row.

**Not affected by Pillar 5 (accessibility defaults, rendered by default — individually opt-out available):**

- Center-dot crosshair with tri-band halo (UI-1) — rendered by default, opt-out via `Settings → Accessibility → Crosshair`
- Health numeric flash (default 1 frame, configurable 1–6 frames per `hud_damage_flash_duration_frames`, rate-gated at 3 Hz per `hud_damage_flash_cooldown_ms`)
- 25 HP threshold typographic weight shift (Bold) as colorblind-safe secondary to Alarm Orange hue shift

Wording clarification (revised 2026-04-22 — ux-designer R5): prior "always rendered" phrasing was contradicted by the opt-out toggle; corrected to "rendered by default; individually opt-out available."

Coverage: AC-CD-14.3 validates absence of the "Always forbidden" items via screenshot evidence at 15 HP during active gunfight WITH Enhanced Hit Feedback OFF. Separate AC (AC-CD-14.4) validates that the enabled pulse is NOT red, uses the 4-quadrant direction model, and renders only when toggle is ON.

### UI-6 Crosshair toggle — dual discovery path (revised 2026-04-21)

Belongs to Settings & Accessibility GDD (forward dep). Combat specifies the behavioral contract (UI-1); Settings owns the toggle definition + persistence. **Two discovery paths** (resolves ux-designer Finding 8): the `Settings.crosshair_enabled` value is surfaced under BOTH `Settings → Accessibility → Crosshair` AND `Settings → HUD → Crosshair`. Single source of truth (one stored setting); two entry points for two player mental models:
- Accessibility-first player finds it under Accessibility (expected location).
- Immersion-first (pure-Pillar-5 roleplay) player finds it under HUD (expected location).

Flagged as dual-surface requirement to Settings & Accessibility GDD.

---

**📌 UX Flag — Combat & Damage:** This system has UI requirements that contribute to HUD Core and Menu System. In Phase 4 (Pre-Production), run `/ux-design hud` and `/ux-design settings-accessibility` to create UX specs for those screens BEFORE writing implementation epics. Stories that reference combat UI should cite `design/ux/hud.md` and `design/ux/settings-accessibility.md`, not this GDD directly.

## Acceptance Criteria

### Testing mechanics (preamble — added 2026-04-21)

All ACs in this section assume the following test infrastructure exists (to be built as part of `/test-setup`):

- **`tests/helpers/SignalRecorder.gd`** — subscribes to named signals and records `(signal_name, args, monotonic_index)` tuples. Used to assert signal emission order (AC-CD-1.1, AC-CD-1.4, AC-CD-15.x).
- **`tests/helpers/WarningCapture.gd`** — autoload test helper that monkey-patches `push_warning` in headless CI to capture warning strings in an array. Used by AC-CD-1.2, AC-CD-1.3. Replaces the pre-revision draft's reference to `assert_called_on_next_warning` which does not exist in GUT 7.x.
- **Time advancement**: timer-based ACs (AC-CD-4.x, AC-CD-5.1, AC-CD-13.3) advance time via `gut.simulate(node, frame_count, 1.0 / 60.0)` (GUT's frame-stepping helper), NOT real-time wall-clock waits. Tolerance `±0.017 s` corresponds to 1 physics frame at 60 fps.

**`@blocked` and `@prototype_gated` enforcement**: these annotations are documentation markers AND enforced via `tests/.blocked-tests.md` manifest. CI checks that every `@blocked` annotation corresponds to either (a) a `pending("reason")` call at the top of the test function (test skipped with visible reason) OR (b) an entry in the manifest with a matching AC-ID. Tests that reference blocked dependencies without either mechanism fail the lint step. This resolves the qa-lead BLOCKER that these annotations were previously unenforced documentation.

### AC-CD-1 Damage Routing

- **AC-CD-1.1 [Logic]** **GIVEN** a valid guard Node with `receive_damage` method and a valid Eve Node with `apply_damage` method, **WHEN** `Combat.apply_damage_to_actor(guard, 34.0, eve, DamageType.BULLET)` is called, **THEN** `guard.receive_damage` is invoked exactly once and `Events.enemy_damaged` emits with `(guard, 34.0, eve)` before `enemy_killed` can emit. **Verification mechanism**: `SignalRecorder` helper subscribes to both signals; test asserts `recorder.index_of(enemy_damaged) < recorder.index_of(enemy_killed)` when `is_dead == true`. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

  - Variant: call with Eve as actor — `apply_damage` is invoked, `enemy_damaged` does NOT emit.
  - Variant: call with `DamageType.TEST` — routes to Eve's path via `apply_damage` duck-type; `enemy_damaged` is never emitted for Eve.

- **AC-CD-1.2 [Logic]** **GIVEN** an actor whose `is_instance_valid()` returns `false`, **WHEN** `apply_damage_to_actor` is called, **THEN** no damage method is invoked, no signal emits, and a warning is pushed via `push_warning`. **Verification mechanism**: `WarningCapture` autoload (see preamble) records warnings into an array; test asserts `WarningCapture.get_captured().has("apply_damage_to_actor: invalid actor reference")`. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

- **AC-CD-1.3 [Logic]** **GIVEN** a valid Node with neither `apply_damage` nor `receive_damage`, **WHEN** `apply_damage_to_actor` is called, **THEN** no signal emits and `push_warning` fires. **Verification**: same `WarningCapture` mechanism as AC-CD-1.2. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

- **AC-CD-1.4 [Logic]** **GIVEN** `guard.receive_damage` returns `is_dead = true`, **WHEN** `apply_damage_to_actor` completes, **THEN** `Events.enemy_damaged` emits before `Events.enemy_killed` — signal order verified by recording emission sequence in a test listener. Evidence: `tests/unit/combat/combat_signal_ordering_test.gd`

  - Variant: `receive_damage` returns `is_dead = false` — `enemy_killed` must NOT emit.

- **AC-CD-1.5 [Logic]** **GIVEN** the `damage_type_to_death_cause()` static function, **WHEN** called with each of the **6** `DamageType` values (`BULLET`, `DART_TRANQUILISER`, `MELEE_FIST`, `MELEE_BLADE`, `FALL_OUT_OF_BOUNDS`, `TEST`), **THEN** returns the corresponding `DeathCause` value as specified in C.4 (`BULLET→SHOT`, `DART_TRANQUILISER→TRANQUILISED`, `MELEE_FIST→MELEE`, `MELEE_BLADE→MELEE`, `FALL_OUT_OF_BOUNDS→ENVIRONMENTAL`, `TEST→UNKNOWN`), with no `push_warning` for any mapped value. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

  - Variant: calling with an out-of-range integer literal triggers `push_warning` and returns `DeathCause.UNKNOWN`.
  - Revised 2026-04-22 — MELEE_BLADE added per C.4 enum (prior 5-value list was stale after 2026-04-21 blade split).

### AC-CD-2 Weapon Damage Values (F.1)

- **AC-CD-2.1 [Logic]** **GIVEN** a guard stub at 100 HP and `is_headshot = false`, **WHEN** `apply_damage_to_actor` is called with the canonical `base_damage` for each weapon, **THEN** the guard's HP delta equals `base_damage × 1.0` within epsilon 0.001 for: silenced pistol (34), dart gun (150), rifle (120), fists (**40** — revised 2026-04-22), blade takedown (100), guard pistol vs Eve path (18). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  - Parametrized: [silenced_pistol=34, dart=150, rifle=120, fists=40, blade=100, guard_pistol=18].

- **AC-CD-2.2 [Logic]** **GIVEN** a guard stub at 100 HP and `is_headshot = true`, **WHEN** `apply_damage_to_actor` is called for silenced pistol (base 34) and rifle (base 120), **THEN** the damage applied equals `base_damage × 2.0` within epsilon 0.001 (pistol: 68.0, rifle: 240.0). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

- **AC-CD-2.3 [Logic]** **GIVEN** Eve's `apply_damage` path (actor has `apply_damage`, not `receive_damage`), **WHEN** any shot arrives with `is_headshot = true`, **THEN** the `target_is_guard` gate prevents headshot multiplier application — HP delta equals `base_damage × 1.0` (verified via Eve stub that records received amount). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

- **AC-CD-2.4 [Logic]** **GIVEN** a guard stub at exactly 100 HP, **WHEN** three silenced pistol body shots arrive via `apply_damage_to_actor` (34 each = 102 cumulative), **THEN** guard is DEAD after shot 3 — `receive_damage` returns `is_dead = true` on the third call. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  - Variant: two headshots (34 × 2 = 68 each = 136 cumulative) → DEAD after shot 2.

- **AC-CD-2.5 [Logic]** **GIVEN** the blade takedown path (CR-15) with `blade_takedown_damage = 100`, **WHEN** SAI calls `apply_damage_to_actor(guard, 100, eve, DamageType.MELEE_BLADE)` with `is_headshot = false`, **THEN** guard receives exactly 100 HP damage AND **`is_headshot` is explicitly `false` at the point of damage application** (asserted by spy on `receive_damage` args) AND `receive_damage` returns `is_dead = true`. Guards against a regression where a headshot multiplier is accidentally applied on the blade path. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

- **AC-CD-2.6 [Logic] (NEW 2026-04-22)** **GIVEN** a guard stub at 100 HP, **WHEN** three fist swings of `fist_base_damage = 40` are applied sequentially via `apply_damage_to_actor(guard, 40, eve, DamageType.MELEE_FIST)`, **THEN** guard is KO'd (state → UNCONSCIOUS per CR-16 non-lethal routing) after the 3rd swing — cumulative damage 120 ≥ 100 HP. At safe-range ceiling `fist_base_damage = 50`, two swings suffice. Confirms the 2–3-swing KO window AND the non-lethal routing (fists → UNCONSCIOUS per CR-16 lethality classification). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

### AC-CD-3 Input Gating (CR-10)

- **AC-CD-3.1 [Logic]** **GIVEN** player character with `_is_reloading = true`, **WHEN** fire input is triggered, **THEN** no `weapon_fired` signal emits and `apply_damage_to_actor` is not called. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  - Parametrized: repeat with each blocking flag independently set to true: `[_is_reloading, _is_switching_weapon, _is_fist_swinging, _is_hand_busy]`.
  - Variant: `InputContext != GAMEPLAY` — fire blocked, no signal, no damage call.

- **AC-CD-3.2 [Logic]** **GIVEN** all five gate flags are false and `InputContext == GAMEPLAY`, **WHEN** fire input is triggered with ammo > 0, **THEN** `weapon_fired` emits exactly once per press. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

### AC-CD-4 Guard Return-Fire Cadence (CR-12)

- **AC-CD-4.1 [Logic]** **GIVEN** a guard transitioning to COMBAT state, **WHEN** time is advanced via `gut.simulate(guard, 40, 1.0/60.0)` (40 frames × 16.67 ms = 666 ms), **THEN** the first return-fire event occurs no sooner than `guard_first_shot_delay_s = 0.65 s` (±0.017 s tolerance, one physics frame at 60 fps). Fire event recorded via `SignalRecorder` subscribed to `Events.weapon_fired`. Evidence: `tests/unit/combat/combat_guard_cadence_test.gd`

- **AC-CD-4.2 [Logic]** **GIVEN** a guard in COMBAT with direct LOS to Eve, **WHEN** three consecutive shots are tracked, **THEN** the interval between each successive shot is `1.4 s ± 0.017 s`. Evidence: `tests/unit/combat/combat_guard_cadence_test.gd`

- **AC-CD-4.3 [Logic]** **GIVEN** a guard in COMBAT that loses LOS, **WHEN** suppression fire is tracked, **THEN** shot interval is `2.8 s ± 0.017 s` and total suppression shots do not exceed `guard_suppression_max_shots = 3`. Evidence: `tests/unit/combat/combat_guard_cadence_test.gd`

  - Variant: after the 3rd suppression shot, verify no 4th shot fires during the subsequent 6 s window while LOS remains lost.

- **AC-CD-4.4 [Logic]** **GIVEN** `guard_suppression_cadence_s = 2.8` and `guard_los_cadence_s = 1.4`, **WHEN** the invariant `suppression_cadence >= 1.5 × los_cadence` is evaluated, **THEN** `2.8 >= 1.5 × 1.4 = 2.1` — asserted as a constant validation test so any tuning change that breaks this ratio surfaces as a test failure. Evidence: `tests/unit/combat/combat_guard_cadence_test.gd`

### AC-CD-5 Return-Fire Timer Handshake (CR-14)

- **AC-CD-5.1 [Integration]** **GIVEN** a guard in COMBAT state with `_combat_lost_target_timer` running at T−1 s before expiry, **WHEN** `Events.player_damaged` emits with `source == this_guard`, **THEN** `_combat_lost_target_timer` is synchronously reset to its full duration (verified by reading timer's `time_left` > T−1 within the same frame). Evidence: `tests/integration/combat/combat_return_fire_timer_test.gd`

  - Variant: `source != this_guard` — timer is NOT reset; `time_left` unchanged within epsilon.
  - Variant: `source == this_guard` but guard's `current_alert_state != COMBAT` — timer NOT reset.

### AC-CD-6 Takedown Delegation (CR-15)

- **AC-CD-6.1 [Integration]** **GIVEN** a guard at 100 HP in UNAWARE or SUSPICIOUS state, **WHEN** SAI's `receive_takedown(STEALTH_BLADE, eve)` is called, **THEN** (1) `CombatSystem.apply_damage_to_actor` is invoked with `amount = 100` and `damage_type = DamageType.MELEE_BLADE`, (2) `guard.receive_damage` is called once, (3) `receive_damage` returns `is_dead = true`, (4) `Events.enemy_damaged(guard, 100, eve)` emits, (5) `Events.enemy_killed(guard, eve)` emits — all in that order within one call stack. Evidence: `tests/integration/combat/combat_takedown_delegation_test.gd`

### AC-CD-7 UNCONSCIOUS State (CR-16)

- **AC-CD-7.1 [Logic]** (revised 2026-04-22 — Transitional model) **GIVEN** a guard at 100 HP, **WHEN** `apply_damage_to_actor(guard, 150, eve, DamageType.DART_TRANQUILISER)` is called, **THEN** guard transitions to `AlertState.UNCONSCIOUS` (not `DEAD`), `receive_damage` returns `is_dead = false` (per CR-16 Transitional model — UNCONSCIOUS is not death), `Events.enemy_damaged` emits, and `Events.enemy_killed` does NOT emit. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

  @blocked(reason: "OQ-CD-1 SAI amendment required to add `UNCONSCIOUS` AlertState + `is_lethal_damage_type()` helper consumption in SAI's `receive_damage` implementation. Enforced via `tests/.blocked-tests.md` manifest.")

- **AC-CD-7.2 [Logic]** (revised 2026-04-22 — lethality split) **GIVEN** a guard at 100 HP, **WHEN** `apply_damage_to_actor` is called with a **lethal** DamageType (`[BULLET, MELEE_BLADE, FALL_OUT_OF_BOUNDS]`), **THEN** guard transitions to `AlertState.DEAD` and `receive_damage` returns `is_dead = true`. **Separately**: with a **non-lethal** DamageType (`[DART_TRANQUILISER, MELEE_FIST]` cumulatively reaching 0 HP), guard transitions to `AlertState.UNCONSCIOUS` and `receive_damage` returns `is_dead = false`. Parametrized per `Combat.is_lethal_damage_type(dt)`. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

- **AC-CD-7.3 [Logic] (NEW 2026-04-22 — UNCONSCIOUS → DEAD transition per E.3)** **GIVEN** a guard already in `AlertState.UNCONSCIOUS` (HP ≤ 0), **WHEN** `apply_damage_to_actor(guard, 34, eve, DamageType.BULLET)` is called (subsequent lethal hit), **THEN** guard transitions UNCONSCIOUS → DEAD, `receive_damage` returns `is_dead = true`, `Events.enemy_damaged` emits, AND `Events.enemy_killed(guard, eve)` emits. **Separately**: additional `DART_TRANQUILISER` on UNCONSCIOUS target is idempotent no-op — no state change, `is_dead = false`, no `enemy_killed`. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

  @blocked(reason: "Same OQ-CD-1 gate as AC-CD-7.1.")

### AC-CD-8 Spread Cone Formula (F.2)

- **AC-CD-8.1 [Logic]** **GIVEN** the `calculate_spread_angle_deg(movement_state, cover_modifier, distance_m)` function, **WHEN** called with all four movement states at distance 5 m with no cover, **THEN** output equals `[2.0, 3.5, 3.0, 6.0]` ± 0.001 deg for `[STATIONARY, WALKING, CROUCHED_STATIONARY, SPRINTING]`. Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.2 [Logic]** **GIVEN** the spread formula at distance 10 m, Eve SPRINTING, cover active, **WHEN** `calculate_spread_angle_deg(SPRINTING, 4.0, 10.0)` is called, **THEN** result equals `6.0 + 4.0 + (3.0 × (10.0 − 8.0) / 8.0) = 10.75°` ± 0.001. Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.3 [Logic]** **GIVEN** a caller passing `distance_m >= 16.0`, **WHEN** the fire-eligibility gate is evaluated, **THEN** the guard does not fire and `calculate_spread_angle_deg` is never invoked for that call (verified by confirming no `weapon_fired` emit). Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.4 [Logic]** **GIVEN** the formula at DEFAULT tuning values, **WHEN** all boundary inputs are exercised (min: STATIONARY, no cover, 0 m; max: SPRINTING, cover, 15.99 m), **THEN** output is within `[2.0, 13.0]` deg. **Separately** (revised 2026-04-21): at SAFE-RANGE CEILING tuning, output is within `[2.0, 20.0]` deg (no runtime overflow, no NaN, no negative values). Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.5 [Logic]** **GIVEN** `guard_range_falloff_start_m` and `guard_range_falloff_end_m` knob values at their current configured values, **WHEN** the invariant `start_m < end_m` is evaluated, **THEN** `(end_m - start_m) > 0.001` — asserted as a constant validation test. Any tuning change that sets `start_m >= end_m` surfaces as a test failure BEFORE runtime, preventing the division-by-zero in the `range_falloff` formula. Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

### AC-CD-9 Ray Sampling Distribution (F.3)

- **AC-CD-9.1 [Logic]** **GIVEN** `sample_cone_direction` seeded with a fixed RNG seed (e.g. `seed(12345)`), **WHEN** called 1000 times with `spread_angle_deg = 13.0`, **THEN** the angular deviation of every returned vector from `aim_dir` is within `[0°, 13°]` (assert `max_deviation <= 13.0°` across all 1000 calls). Evidence: `tests/unit/combat/combat_sample_cone_distribution_test.gd`

- **AC-CD-9.2 [Logic]** (revised 2026-04-22 — correct median + seed restated) **GIVEN** `sample_cone_direction` seeded with `seed(12345)` — same seed as AC-CD-9.1 — **WHEN** 1000 samples are drawn with `spread_angle_deg = 13.0`, **THEN** median angular deviation falls in `[8.5°, 9.9°]` (analytically 9.2° for `sqrt(randf())` — the CDF-derived median is `13° × sqrt(0.5) ≈ 9.19°`; the tolerance band accommodates statistical variance at n=1000). A flat-disk (uniform `randf()`) would median at `0.5 × 13° = 6.5°`, so values in the ~6.5° range indicate the square-root transform is not applied — the `[8.5°, 9.9°]` window discriminates the correct implementation. Evidence: `tests/unit/combat/combat_sample_cone_distribution_test.gd`

  **Note on prior claim**: the pre-revision assertion "< 7.5°" was mathematically incorrect for `sqrt(randf())`. Fix documented in F.3 revised rationale.

- **AC-CD-9.3 [Logic]** **GIVEN** the returned `perturbed_direction` vector, **WHEN** `length()` is called, **THEN** result equals `1.0 ± 0.0001` (unit vector contract). Evidence: `tests/unit/combat/combat_sample_cone_distribution_test.gd`

### AC-CD-10 Dart Projectile Physics (F.4)

- **AC-CD-10.1 [Logic]** **GIVEN** a dart RigidBody3D instance spawned with defaults, **WHEN** initial state is inspected, **THEN** `linear_velocity.length() ≈ 20.0 m/s ± 0.001`, `gravity_scale == 0.0`, and lifetime timer is set to `4.0 s ± 0.001`. Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

- **AC-CD-10.2 [Logic]** **GIVEN** a dart in flight past its `dart_lifetime_s = 4.0 s`, **WHEN** the timer fires, **THEN** `queue_free()` is called (dart node is no longer in the scene tree). Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

- **AC-CD-10.3 [Logic]** (revised 2026-04-22 — dual-signal handler) **GIVEN** a dart's `_on_impact(other)` handler fires via EITHER `body_entered` (physics body) OR `area_entered` (Area3D overlap, e.g., head zone), **WHEN** the callback executes against a guard Node, **THEN** `Combat.apply_damage_to_actor(other, dart_damage, self, DamageType.DART_TRANQUILISER)` is called exactly once (via `_has_impacted` flag guarding double-fire), then `queue_free()` is called. Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

  - Variant: both signals fire same-tick (body + head Area3D) — damage applied only once.

- **AC-CD-10.4 [Logic]** **GIVEN** a dart spawned with `collision_mask` set per F.4 contract, **WHEN** collision layers are read, **THEN** `MASK_PLAYER` bit is NOT set in the collision mask (dart cannot hit Eve). Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

- **AC-CD-10.5 [Logic] (NEW 2026-04-22 — pre-fire occlusion check)** **GIVEN** Eve pressed flush against a wall such that `camera.global_position + aim_direction × 0.5` falls inside a `StaticBody3D` (world geometry), **WHEN** Fire input is pressed with dart equipped, **THEN** (1) no dart RigidBody3D is spawned, (2) `Events.weapon_fired` does NOT emit, (3) ammo is not consumed, (4) Audio subscribes to a separate "dry-fire click" signal emit. Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

### AC-CD-11 Headshot Detection (F.5)

- **AC-CD-11.1 [Logic]** **GIVEN** a hitscan ray result where `hit_collider.is_in_group("headshot_zone") == true`, **WHEN** headshot detection is evaluated, **THEN** `is_headshot = true` and `final_damage = base_damage × 2.0`. Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

- **AC-CD-11.2 [Logic]** **GIVEN** a hitscan ray result where `hit_collider` is the guard's body CapsuleShape3D (not in "headshot_zone" group), **WHEN** headshot detection is evaluated, **THEN** `is_headshot = false` and `final_damage = base_damage × 1.0`. Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

- **AC-CD-11.3 [Logic]** **GIVEN** the takedown delegation path (CR-15), **WHEN** `receive_takedown(STEALTH_BLADE, attacker)` routes to `apply_damage_to_actor(guard, 100, eve, DamageType.MELEE_BLADE)`, **THEN** `is_headshot` is explicitly `false` — takedown damage of 100 is passed without multiplier (blade has no hit zones). Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

- **AC-CD-11.4 [Integration]** **GIVEN** a guard scene with `Area3D` on `BoneAttachment3D(bone: "head")` tagged `"headshot_zone"`, **WHEN** the guard is placed in a Godot 4.6 + Jolt physics scene and a raycast targets the head Area3D with `collide_with_areas = true`, **THEN** `intersect_ray` returns the Area3D as `collider`. Evidence: `tests/integration/combat/combat_headshot_detection_jolt_test.gd`

  @prototype_gated(reason: "OQ-CD-2 item 1 — Jolt + bone-attached Area3D inclusion in intersect_ray results must be validated in the fire-cadence prototype. If Jolt returns a different collider (e.g., parent CharacterBody3D), the fallback path in F.5 decision tree applies and this AC is rewritten.")

- **AC-CD-11.5 [Logic] (NEW 2026-04-22 — multi-RID self-exclusion)** **GIVEN** a guard in friendly-fire mode (`GUARD_FRIENDLY_FIRE_ENABLED = true`) firing its own hitscan from camera origin outward, **WHEN** the exclude list is computed via `_collect_self_rids(shooter)`, **THEN** the exclusion list contains the guard's `CharacterBody3D` RID AND the head `Area3D` RID (collected via `find_children("*", "CollisionObject3D", true, false)`). Raycast result `collider` is NEVER the firing guard's own body or head zone. Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

### AC-CD-12 Ammo Economy (F.6)

- **AC-CD-12.1 [Logic]** (revised 2026-04-22 — stale values corrected) **GIVEN** a fresh mission start, **WHEN** player inventory is initialized, **THEN** silenced pistol has `magazine = 8, reserve = 32`; dart gun has `magazine = 4, reserve = 16`; rifle has `magazine = 0, reserve = 0`. Values sourced from `pistol_starting_reserve` (G.5) and `dart_starting_reserve` (G.5) knobs. Evidence: `tests/unit/combat/combat_ammo_economy_test.gd`

- **AC-CD-12.2 [Logic]** (revised 2026-04-22 — NOLF1 drop values + fist-farm closure) **GIVEN** a guard KO'd via dart (non-lethal), **WHEN** the loot drop is generated, **THEN** dart drop count == 1 (`guard_drop_dart_on_dart_ko = 1` — break-even anti-farm invariant). Evidence: `tests/unit/combat/combat_ammo_economy_test.gd`

  - Variant: guard KO'd via fists → dart drop count == **0** (`guard_drop_dart_on_fist_ko = 0` — no fist-farm).
  - Variant: guard killed lethally carrying silenced pistol → pistol drop == **3 rounds** (`guard_drop_pistol_rounds = 3` per NOLF1 rebalance 2026-04-22); dart drop == 0.
  - Variant: guard killed lethally carrying rifle → rifle drop == 3 rounds.

- **AC-CD-12.3 [Logic]** **GIVEN** ammo at respawn checkpoint below the floor values, **WHEN** respawn restore is applied, **THEN** pistol total ammo (magazine + reserve) = `max(snapshot_total, respawn_floor_pistol_total=16)` and dart total ammo = `max(snapshot_total, respawn_floor_dart_total=8)`; rifle ammo = snapshot value unchanged. Evidence: `tests/integration/combat/combat_respawn_ammo_floor_test.gd`

  - Variant: ammo at checkpoint ABOVE the floor → restore returns checkpoint value unchanged (no free refill).
  - Variant: ammo at checkpoint ABOVE `pistol_max_reserve = 48` (if save file corrupted or edge-case accumulation) → restore clamps to 48; rounds above cap are silently lost. Documented as intentional behavior.

- **AC-CD-12.4 [Integration]** (revised 2026-04-22 — NOLF1 math) **GIVEN** a simulated aggressive playthrough killing all guards lethally in Sections 1–2 without collecting any caches, **WHEN** entering Section 3, **THEN** pistol total ammo (magazine + reserve) is ≤ 16 rounds (one magazine cushion). Derivation: start 40 + 10 guards × (3 drop − 3 TTK) = 40 + 0 − reload losses (~4 rounds) = ~36. With spread misses (~15%) = ~30. With partial pickup friction (~30% rounds lost on interrupted pickups) = ~16. Evidence: `production/qa/evidence/combat-damage/manual-pillar-2-depletion-curve.md`

  @prototype_gated(reason: "Tier 0 playtest required to confirm guard counts per section, real-play miss rates, and pickup friction produce the predicted depletion. Exact 16-round threshold may shift ±4 after playtest; AC adjusts post-playtest.")

### AC-CD-13 Crosshair and ADS (CR-8, CR-9)

- **AC-CD-13.1 [UI]** (revised 2026-04-22 — resolution-independent sizing + tri-band halo) **GIVEN** the game launched fresh with default settings at 1080p, **WHEN** Eve is in GAMEPLAY InputContext, **THEN** a static Ink Black `#1A1A1A` center dot (~2 physical px; `0.19% × 1080 = 2.05`, clamped to min 3 px effective) is visible, surrounded by a tri-band halo (1 px Parchment `#E8DFC8` outer + 1 px Ink Black `#1A1A1A` inner). Dot does not expand/contract with movement, does not change color on enemy hover, does not hit-marker flash. Evidence: `production/qa/evidence/combat-damage/manual-crosshair-accessibility-toggle.md`

  - Variant at 1440p: dot ~3 physical px; halo unchanged.
  - Variant at 4K: dot ~4 physical px (clamped by max 12 px ceiling); halo unchanged.
  - Variant (contrast test): screenshot dot against light (Parchment-adjacent) background → Ink Black inner halo band provides ≥3:1 contrast; dot against dark indoor background → Parchment outer band provides ≥3:1 contrast. Verified via pixel-sampling protocol in evidence markdown.

- **AC-CD-13.2A [UI]** (split from prior AC-CD-13.2, revised 2026-04-22) **GIVEN** `Settings → Accessibility → Crosshair` is toggled off, **WHEN** the setting is applied, **THEN** the center dot and halo disappear; no other HUD element is affected; `Settings.crosshair_enabled` value reads `false`. Evidence: `production/qa/evidence/combat-damage/manual-crosshair-accessibility-toggle.md`

- **AC-CD-13.2B [UI] (NEW 2026-04-22 — dual-surface discovery)** **GIVEN** `Settings → HUD → Crosshair` is toggled off (from the HUD menu, not Accessibility), **WHEN** the setting is applied, **THEN** (1) the center dot and halo disappear same as AC-CD-13.2A; (2) `Settings.crosshair_enabled` value reads `false` — SAME stored setting as the Accessibility path; (3) re-opening `Settings → Accessibility → Crosshair` shows the toggle in the OFF state (single source of truth). Evidence: `production/qa/evidence/combat-damage/manual-crosshair-accessibility-toggle.md`

- **AC-CD-13.3 [Logic]** **GIVEN** Eve holding the rifle and pressing `Aim` input, **WHEN** time is advanced via `gut.simulate(player, 13, 1.0/60.0)` (~216 ms > 200 ms tween duration), **THEN** camera FOV == `55.0° ± 0.5°` (tweened from 85° over 200 ms ease-out, sampled at tween end). Evidence relocated 2026-04-21 from `combat_weapon_damage_test.gd` to dedicated `tests/unit/combat/combat_ads_test.gd`.

- **AC-CD-13.4 [Logic]** **GIVEN** a test fixture that sets `eve_spread_deg = 1.0°` (overriding default 0.0°), rifle ADS active (FOV at 55°), **WHEN** `calculate_spread_angle_deg` is computed for the rifle while ADS-active, **THEN** output == `0.5° ± 0.001°` (eve_spread_deg × 0.5 halving applied). **Rewritten 2026-04-21**: previous AC asserted `0.0 × 0.5 == 0.0` which passed trivially regardless of whether halving was implemented. Fixture override ensures meaningful coverage at default as well as prototype values. Evidence: `tests/unit/combat/combat_ads_test.gd`

  @prototype_gated(reason: "Tier 1 playtest may set eve_spread_deg > 0.0 as the shipped default; fixture override ensures AC has coverage either way.")

### AC-CD-14 Pillar Compliance

- **AC-CD-14.1 [Logic]** **GIVEN** Eve at 100 HP and `guard_pistol_damage_vs_eve = 18` (default), **WHEN** the minimum number of guard shots to reach 0 HP is computed, **THEN** `ceil(100 / 18) = 6` shots required — Eve dies in EXACTLY 6 hits at default. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  @prototype_gated(reason: "Final default value may shift within [14, 20] after Tier 1 playtest.")

- **AC-CD-14.1b [Logic] (NEW 2026-04-22 — safe-range invariant as assertion)** **GIVEN** `guard_pistol_damage_vs_eve` at ANY value within its declared safe range `[14, 20]`, **WHEN** `ceil(100 / guard_pistol_damage_vs_eve) >= 5` is evaluated, **THEN** the assertion holds. Implemented as a constant-validation test that parametrizes over the safe-range endpoints and several interior values; same pattern as AC-CD-4.4 and AC-CD-8.5. Guards against a future tuning-range expansion that would let Eve die in <5 hits (breaking Pillar 3 survivability floor). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

- **AC-CD-14.2 [Integration]** **GIVEN** an aggressive playthrough of Sections 1–3 where Eve kills all guards lethally, **WHEN** Eve reaches Section 3 without picking up any caches, **THEN** pistol reserve is 0 and weapon falls through to fists — Pillar 2 ammo scarcity is felt. Evidence: `production/qa/evidence/combat-damage/manual-pillar-2-depletion-curve.md`

- **AC-CD-14.3 [Visual]** (revised 2026-04-22 — pixel-sampling protocol) **GIVEN** Eve at 15 HP (below 25 HP clock-tick threshold), actively in a gunfight, AND `enhanced_hit_feedback_enabled == false` (default), **WHEN** a screenshot is taken of the full viewport at 1080p, **THEN** the screenshot contains: no red or color-tinted screen edge vignette, no hit marker overlaid on the crosshair, no damage-direction indicator, no "LOW HEALTH" text. **Pass criterion (objective)**: sample 5 pixels from each of the four screen-edge regions (top-left `(20, 20)`, top-right `(1900, 20)`, bottom-left `(20, 1060)`, bottom-right `(1900, 1060)`, center `(960, 540)`). Mean channel values must match the underlying scene render (reviewer compares against control screenshot at full HP, same scene, same frame). Pixel-sampling procedure + control-screenshot capture process detailed in evidence markdown template. Evidence: `production/qa/evidence/combat-damage/manual-pillar-5-no-modern-ui.md`

- **AC-CD-14.4 [Visual]** (revised 2026-04-22 — 4-quadrant direction model + pixel-sampling) **GIVEN** Eve at 15 HP, `enhanced_hit_feedback_enabled == true` (opt-in), AND a guard fires from the NE quadrant (in front + to the right of Eve's forward vector), **WHEN** Eve takes a hit and a screenshot is captured during the 120 ms pulse window, **THEN** the NE corner pulse region (roughly `(1600, 0)` to `(1920, 300)` at 1080p) shows a desaturated warm-grey pulse at ≤15% opacity (sampled alpha in range `[0.00, 0.15 ± 0.02]`) AND hue is desaturated warm-grey (NOT red: H ∉ `[0°, 20°] ∪ [340°, 360°]` in HSV). The other three corners show background render (no pulse). **AND** with `enhanced_hit_feedback_enabled == false` under identical conditions, the NE corner matches the control screenshot (no pulse). **Pass criterion**: alpha sampling in specified regions; HSV hue test; opacity threshold verified via image-editor dropper tool (procedure in evidence markdown). Evidence: `production/qa/evidence/combat-damage/manual-enhanced-hit-feedback.md`

### AC-CD-15 Signal Contracts (ADR-0002)

- **AC-CD-15.1 [Logic]** **GIVEN** a guard damage call where `receive_damage` returns `is_dead = false`, **WHEN** `apply_damage_to_actor` completes, **THEN** `Events.enemy_damaged` emits once with `(actor, amount_post_multiplier, source)` and `Events.enemy_killed` does NOT emit. Evidence: `tests/unit/combat/combat_signal_ordering_test.gd`

- **AC-CD-15.2 [Logic]** **GIVEN** a guard damage call where `receive_damage` returns `is_dead = true`, **WHEN** `apply_damage_to_actor` completes, **THEN** `Events.enemy_damaged` emits first, then `Events.enemy_killed(actor, source)` emits second — order recorded by listener spy with monotonic call index. Evidence: `tests/unit/combat/combat_signal_ordering_test.gd`

- **AC-CD-15.3 [Logic]** **GIVEN** two back-to-back `apply_damage_to_actor` calls on the same guard (E.1 same-frame double-hit), **WHEN** the second call arrives after the guard is already DEAD, **THEN** `enemy_damaged` emits on the second call but `enemy_killed` does NOT re-emit. Evidence: `tests/unit/combat/combat_signal_ordering_test.gd`

### AC-CD-16 Save / Load

- **AC-CD-16.1 [Integration]** **GIVEN** Eve mid-mission with `pistol_magazine = 3, pistol_reserve = 9, dart_magazine = 2, dart_reserve = 5`, **WHEN** the checkpoint save fires at `section_entered`, **THEN** restoring from that save produces identical values. Evidence: `tests/integration/combat/combat_respawn_ammo_floor_test.gd`

  @blocked(reason: "Requires ADR-0003 (Save Format Contract) accepted status AND Save/Load GDD authored. Test cannot be written against a mock serializer — the real serialization format must exist. Added 2026-04-21 per qa-lead review.")

- **AC-CD-16.2 [Integration]** **GIVEN** a save captured mid-reload (`_is_reloading = true`), **WHEN** the save is written and then restored (ADR-0003 does not serialize mid-reload), **THEN** `_is_reloading == false` on restore; ammo values reflect pre-reload snapshot. Evidence: `tests/integration/combat/combat_respawn_ammo_floor_test.gd`

  @blocked(reason: "Same as AC-CD-16.1 — depends on ADR-0003 + Save/Load GDD.")

### AC-CD-17 Prototype-Gated Values (G.4 / G.3)

- **AC-CD-17.1 [Config/Data]** **GIVEN** `guard_pistol_damage_vs_eve` is at default value 18, **WHEN** a smoke check runs against `SectionConfig` defaults, **THEN** value is within safe range `[14, 20]` and is not hardcoded in source. Evidence: smoke check pass log.

  @prototype_gated(reason: "Tier 1 playtest required to confirm 18 HP delivers Pillar 3 feel.")

- **AC-CD-17.2 [Config/Data]** **GIVEN** `eve_spread_deg` is at default value 0.0, **WHEN** a smoke check runs, **THEN** value is within safe range `[0.0, 1.5]`. Evidence: smoke check pass log.

  @prototype_gated(reason: "Tier 1 playtest decides whether sprint-fire tax > 0.0 is introduced.")

- **AC-CD-17.3 [Config/Data]** **GIVEN** `dart_speed_m_s` is at default value 20.0, **WHEN** a smoke check runs, **THEN** value is within safe range `[15.0, 30.0]` and dart-feel manual playtest has been recorded. Evidence: `production/qa/evidence/combat-damage/manual-dart-feel-playtest.md`.

  @prototype_gated(reason: "Feel playtest required; dart speed is the primary feel variable.")

- **AC-CD-17.4 [Config/Data]** **GIVEN** `dart_gravity_scale` is at default value 0.0, **WHEN** a smoke check runs, **THEN** value is either `0.0` or `0.5` (binary option per G.4 safe range). Evidence: smoke check pass log.

  @prototype_gated(reason: "Tier 1 playtest decides whether subtle arc (0.5) is introduced.")

- **AC-CD-17.5 [Config/Data]** (revised 2026-04-22 — separate evidence file) **GIVEN** `head_zone_radius_m` is at default value 0.15, **WHEN** a smoke check runs, **THEN** value is within safe range `[0.10, 0.20]` and headshot-fairness playtest has recorded a verdict. Evidence: `production/qa/evidence/combat-damage/manual-headshot-fairness-playtest.md` *(split from manual-dart-feel-playtest for separation of concerns per qa-lead NIT-5)*.

  @prototype_gated(reason: "Tier 1 playtest required to confirm 0.15 m radius does not feel lottery or shoulder-overlapping.")

### AC-CD-18 Photosensitivity rate-gate (NEW 2026-04-22 — WCAG 2.3.1 compliance)

- **AC-CD-18.1 [Logic]** **GIVEN** `hud_damage_flash_duration_frames = 6` (max tuning) AND `hud_damage_flash_cooldown_ms = 333` (default), **WHEN** 10 `player_damaged` signals emit at 50 ms intervals over 500 ms (simulating rapid multi-hit), **THEN** no more than `ceil(500 / 333) = 2` visual flashes render on the HUD (asserted by spying on HUD's flash widget animation trigger). The intervening damage events are coalesced — the secondary SFX + camera dip still fire for each, but visual flashes are rate-gated. Evidence: `tests/integration/combat/combat_photosensitivity_rate_gate_test.gd`

### AC-CD-19 Test infrastructure gate (NEW 2026-04-22 — explicit sprint gate)

- **AC-CD-19.1 [Meta]** **GIVEN** any sprint containing stories that consume AC-CD-1.x, 2.x, 4.x, 6.1, 7.x, 9.x, 11.x, 12.x, 13.3, 15.x, or 18.1, **WHEN** the sprint-start smoke-check runs, **THEN** `tests/helpers/SignalRecorder.gd` + `tests/helpers/WarningCapture.gd` MUST exist in the repository AND `tests/.blocked-tests.md` manifest MUST exist. If any are missing, stories referencing those ACs are moved to the next sprint; `/test-setup` is the blocking deliverable. Evidence: sprint-start smoke-check log.

### Open blocked items (revised 2026-04-22)

- **AC-CD-7.1, AC-CD-7.3** are blocked on **OQ-CD-1** (SAI amendment: UNCONSCIOUS AlertState + `receive_damage -> bool` signature + `is_lethal_damage_type` helper consumption + `has_los_to_player()` accessor + `takedown_prompt_active(actor)` accessor + `STEALTH_BLADE` takedown-type rename).
- **AC-CD-11.4** is blocked on **OQ-CD-2** (Jolt + bone-attached Area3D in `intersect_ray` results — 3-item prototype scope).
- **AC-CD-16.1, AC-CD-16.2** blocked on ADR-0003 (Save Format Contract) Accepted status + Save/Load GDD authoring.
- **All AC references to SignalRecorder / WarningCapture / `.blocked-tests.md`** gated by AC-CD-19.1 (`/test-setup` prerequisite).
- **AC-CD-11.4** has hard deadline: unblocked before any sprint containing headshot-implementation stories can enter.

### Test file tree (revised 2026-04-21 — split oversized files, added helpers)

```
tests/helpers/
  SignalRecorder.gd                      (ordered-emission spy for AC-CD-1.1, 1.4, 15.x)
  WarningCapture.gd                      (push_warning spy for AC-CD-1.2, 1.3)

tests/unit/combat/
  combat_damage_routing_test.gd          (AC-CD-1.1–1.5, 7.1–7.3)
  combat_weapon_damage_test.gd           (AC-CD-2.1–2.6, 14.1, 14.1b)
  combat_input_gating_test.gd            (AC-CD-3.1–3.2)
  combat_ads_test.gd                     (AC-CD-13.3, 13.4)
  combat_spread_cone_test.gd             (AC-CD-8.1–8.5)
  combat_sample_cone_distribution_test.gd (AC-CD-9.1–9.3)
  combat_dart_projectile_test.gd         (AC-CD-10.1–10.5)
  combat_headshot_detection_test.gd      (AC-CD-11.1–11.3, 11.5)
  combat_ammo_economy_test.gd            (AC-CD-12.1–12.2)
  combat_guard_cadence_test.gd           (AC-CD-4.1–4.4)
  combat_signal_ordering_test.gd         (AC-CD-15.1–15.3)

tests/integration/combat/
  combat_takedown_delegation_test.gd     (AC-CD-6.1)
  combat_return_fire_timer_test.gd       (AC-CD-5.1)
  combat_respawn_ammo_floor_test.gd      (AC-CD-12.3, 16.1–16.2 — BLOCKED on ADR-0003 + Save/Load GDD)
  combat_headshot_detection_jolt_test.gd (AC-CD-11.4 — BLOCKED pending OQ-CD-2)
  combat_photosensitivity_rate_gate_test.gd (AC-CD-18.1 — NEW)

production/qa/evidence/combat-damage/
  manual-pillar-2-depletion-curve.md     (AC-CD-12.4, 14.2)
  manual-pillar-3-ttk-verification.md    (AC-CD-14.1 — prototype-gated)
  manual-pillar-5-no-modern-ui.md        (AC-CD-14.3)
  manual-enhanced-hit-feedback.md        (AC-CD-14.4 — NEW 2026-04-21)
  manual-crosshair-accessibility-toggle.md (AC-CD-13.1–13.2)
  manual-dart-feel-playtest.md           (AC-CD-17.3)
  manual-headshot-fairness-playtest.md   (AC-CD-17.5 — split 2026-04-22)

tests/.blocked-tests.md                  (manifest — enforces @blocked annotations; MUST exist per AC-CD-19.1)
```

## Open Questions

### Pre-implementation gates (BLOCKING — must resolve before Combat stories enter sprints)

- **OQ-CD-1 [SAI amendment — REVISED SCOPE 2026-04-22]** Stealth AI GDD requires the following amendments to unblock Combat stories:
  1. Add `AlertState.UNCONSCIOUS` as 6th alert state (per CR-16 revised).
  2. Change `receive_damage(amount, source, damage_type)` signature to return `bool is_dead` (per C.5 duck-type dispatch).
  3. SAI's `receive_damage` consumes `Combat.is_lethal_damage_type(damage_type)` helper to decide DEAD (lethal) vs UNCONSCIOUS (non-lethal). Transitional model per CR-16: UNCONSCIOUS accepts further lethal damage → DEAD (see E.3); UNCONSCIOUS + DART_TRANQUILISER or MELEE_FIST is idempotent no-op.
  4. Takedown-type enum: include `STEALTH_BLADE` (new) and remove `SILENCED_PISTOL` (obsolete).
  5. **NEW accessors (public methods, called by GuardFireController on each idle tick)**:
     - `guard.has_los_to_player() -> bool` — returns SAI's F.1 perception cache LOS result. No new raycast per call.
     - `guard.takedown_prompt_active(attacker: Node) -> bool` — returns whether `attacker` is eligible to invoke `receive_takedown(STEALTH_BLADE, attacker)` right now (behind-arc + unseen + within ~1.5 m).
  6. Synchronicity guarantee: SAI's `receive_damage` must mutate `current_alert_state` synchronously (no `call_deferred`) before returning, so Combat's signal ordering (`enemy_damaged` → `enemy_killed`) and `GuardFireController`'s defensive gate both observe the correct state within the same call stack.

  **Owner**: user via `/design-system` revision of SAI + `technical-director` approval. **Blocks**: AC-CD-7.1, AC-CD-7.3 unblock; AC-CD-6.1 is-dead return works correctly; LOS-based return-fire cadence works; Takedown-input flow works. **Estimated effort**: 1.5 sessions (touch 4–5 paragraphs of SAI GDD + update registry + update Audio/PC GDD cross-references for the takedown-type rename).

- **OQ-CD-2 [Jolt physics validation — EXPANDED SCOPE 2026-04-21]** Godot 4.6 + Jolt 3D prototype must verify three API unknowns (per F.5 revision):
  1. Does `PhysicsDirectSpaceState3D.intersect_ray` (with `collide_with_areas = true`) include `Area3D` on `BoneAttachment3D` children as `collider`?
  2. Does the `Area3D` world-space transform reflect the CURRENT animated pose when queried from `_physics_process`, or does it lag a frame behind `_process`?
  3. Does `RigidBody3D.continuous_cd = true` correctly enable CCD under Jolt (or does Jolt require a different property path)?
  **Owner**: `godot-specialist` validation via throwaway prototype in `prototypes/guard-combat-prototype/`. **Blocks**: AC-CD-11.4 can be asserted as passing + AC-CD-10.1 dart CCD behavior confirmed. **Estimated effort**: 60-minute prototype + written finding (revised up from 30 min for expanded scope).

### Forward-dep gates (resolve when dependent GDD is authored)

- **OQ-CD-3 [Weapon fallthrough — Inventory & Gadgets]** When Eve's magazine + reserve are both 0 for a weapon: does the player manually switch to fists, or does Combat auto-switch the current weapon slot to fists? Affects E.8 + UI-2 fists transition behavior. **Owner**: Inventory & Gadgets GDD authoring pass. **Combat contract**: pressing fire on an empty weapon is a no-op; Inventory decides the next-weapon logic.

- **OQ-CD-4 [Fist-swing target selection]** When a ShapeCast3D cone returns multiple collision results (E.16), should Combat sort by distance-from-camera and pick the nearest, or use first-result-from-Jolt? **Owner**: prototype decision via `prototypes/guard-combat-prototype/`; ~15 minutes of testing. **Default pending prototype**: nearest-target sort.

- **OQ-CD-5 [Mission objective save race]** Does Mission Scripting save objective state synchronously at the same checkpoint that Combat's `enemy_killed` fires, or lazily? If lazy, a one-frame race exists where a guard is killed and saved as DEAD but the objective "eliminate guard X" has not yet completed. Affects E.36. **Owner**: Mission Scripting GDD authoring pass. **Combat contract**: `enemy_killed` fires synchronously from `apply_damage_to_actor`; save checkpoint timing is Mission Scripting's concern.

- **OQ-CD-11 [Takedown blade Resource schema — Inventory & Gadgets] (revised 2026-04-22 — dedicated Takedown input)** With the pistol-takedown split AND the Takedown-input decision (CR-3 revised), the takedown blade is a new weapon Resource but does NOT occupy a regular weapon slot. Inventory & Gadgets GDD must author: blade Resource fields (`base_damage = 100`, `damage_type = DamageType.MELEE_BLADE`, `fire_rate_sec = 0.0` with comment "context-gated single-use per prompt", no magazine, no reserve); blade-draw input binding is the dedicated `Takedown` input (NOT a weapon-switch); context-prompt gating consults SAI's `takedown_prompt_active` accessor. Combat contract frozen here; Inventory resolves the Resource shape and how the Takedown input is wired.

- **OQ-CD-12 [Settings & Accessibility forward deps] (revised 2026-04-22 — expanded)** Multiple accessibility contracts declared in Combat require Settings & Accessibility GDD to own:
  1. `Settings → Accessibility → Crosshair` toggle (opt-out, boolean)
  2. `Settings → Accessibility → Enhanced Hit Feedback` toggle (opt-in, boolean)
  3. `Settings → Accessibility → Damage Flash Duration` slider (1–6 frames, int)
  4. `Settings → Accessibility → Damage Flash Cooldown (Photosensitivity)` slider (333–1000 ms, int; default 333, cannot go below — safety floor)
  5. `Settings → HUD → Crosshair` duplicate discovery entry (single source of truth — writes to same `Settings.crosshair_enabled` value)
  6. `Settings → Accessibility → ADS Tween Duration Multiplier` (vestibular sensitivity, 1.0×–3.0×, float)
  7. First-boot photosensitivity warning dialog (auto-shown on first launch; dismissible)
  8. `Settings → Accessibility → Clock-tick Enabled` (cross-ref to Audio GDD `clock_tick_enabled` — if disabled, the ≤25 HP clock-tick loop does not play. Hearing-impaired players depending on Enhanced Hit Feedback may prefer the clock-tick silent.)
  9. **Motor accessibility flag (NEW 2026-04-22 — ux-designer R2)**: aim-assist is NOT in MVP scope, but Settings & Accessibility GDD should document motor-accessibility as a deliberate gap with a post-MVP plan (magnetism + sticky-aim + crosshair-scale multiplier).
  **Owner**: Settings & Accessibility GDD authoring pass. **Combat contract**: behavioral spec in this GDD; persistence + UI placement owned by Settings.

- **OQ-CD-13 [Pillar 5 boundary clarification doc] (revised 2026-04-22 — now BLOCKING for dependent GDDs)** The creative-director ruled during 2026-04-21 revision that Pillar 5 governs diegetic fiction, NOT accessibility scaffolding. This ruling is load-bearing in this GDD (UI-1, V.6, UI-5, §B Design Test scope note) AND propagates to HUD State Signaling, Document Overlay UI, Menu System, Settings & Accessibility. **BLOCKING CHANGE 2026-04-22**: a short Pillar 5 Boundary Clarification doc (~1 page at `design/pillar-5-boundary.md`) MUST be authored BEFORE any of those downstream GDDs enters `/design-system`. Does NOT block Combat approval; DOES block downstream GDD authoring. **Owner**: `creative-director` — 1 session. **Blocks**: HUD State Signaling, Document Overlay UI, Menu System, Settings & Accessibility GDD authoring.

### Tier 1 playtest-gated (5 values)

- **OQ-CD-6 [Playtest: guard pistol damage vs Eve]** `guard_pistol_damage_vs_eve = 18` — default produces 5.5-hit kill. Playtest may shift within [14, 20] (tightened 2026-04-21 from [14, 25] to honor AC-CD-14.1's "Eve cannot die in fewer than 5 hits" invariant). Target feel: survivable but weighty.
- **OQ-CD-7 [Playtest: Eve spread]** `eve_spread_deg = 0.0` — default perfect aim. Tier 1 playtest may introduce 0.5–1.0° sprint-fire tax.
- **OQ-CD-8 [Playtest: dart speed]** `dart_speed_m_s = 20.0` — default. Playtest validates dart feels like a precision tool, not a pellet.
- **OQ-CD-9 [Playtest: dart arc]** `dart_gravity_scale = 0.0` — default straight flight. Playtest may introduce 0.5 m/s² subtle arc if dart feels too surgical.
- **OQ-CD-10 [Playtest: headshot fairness]** `head_zone_radius_m = 0.15` — default. Playtest validates radius doesn't feel lottery (too small) or shoulder-overlap (too large).

### Art Bible amendments (tracked separately)

Tracked in §Visual/Audio Requirements V.9 — §4.4 palette, §7D animation, NEW §8K VFX asset class, §3.4 silhouette clarification. **Owner**: `art-director` via an Art Bible revision pass. Does not block Combat GDD approval, but blocks the asset-spec run.

### Registry additions (Phase 5b gate)

New constants to register in `design/registry/entities.yaml` — handled in Phase 5b of the `/design-system` workflow at completion.
