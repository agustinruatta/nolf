# Combat & Damage

> **Status**: Revised (MAJOR REVISION pass 2026-04-21 — resolving 25+ blockers from first /design-review)
> **Author**: user + design-system skill + /design-review specialists (game-designer, systems-designer, ai-programmer, art-director, economy-designer, qa-lead, godot-specialist, ux-designer, creative-director)
> **Last Updated**: 2026-04-21 (revision pass)
> **Implements Pillars**: Pillar 3 — Stealth is Theatre, Not Punishment (core); Pillar 5 — Period Authenticity Over Modernization (core, with accessibility carve-out per CD ruling); Pillar 1 — Comedy Without Punchlines (support via hit vocals + weapon sound design); Pillar 2 — Discovery Rewards Patience (softened ammo scarcity — see §F.6)
> **Consumes ADRs**: ADR-0001 (Stencil), ADR-0002 (Signal Bus), ADR-0003 (Save Format), ADR-0006 (Collision Layers)
> **Depends on GDDs**: Player Character (✅ Approved), Stealth AI (✅ Approved), Audio (✅ Approved)
> **Depended on by (forward)**: Inventory & Gadgets, Mission & Level Scripting, Failure & Respawn, HUD Core, Settings & Accessibility (Enhanced Hit Feedback toggle)

> **Revision pass 2026-04-21 — key changes** (applied in response to /design-review MAJOR REVISION NEEDED verdict):
> - **Weapon roster restructured**: silenced pistol is now **gunfight-only** (3-shot TTK). Stealth 1-shot lethal takedown moves to a new weapon, the **takedown blade** (silent melee, stealth-only). Resolves pistol dual-identity blocker.
> - **Fists kept as rare edge-case fallback**; Section B explicitly carves them out as the one accepted tonal exception. Ammo generosity raised so fists are seldom needed (Pillar 2 pressure softened — see F.6).
> - **Crosshair rationale revised**: accessibility-first (not "period-scope reticle"). Added 1 px Parchment halo ring for low-contrast legibility.
> - **Pillar 5 boundary clarified**: Pillar 5 governs diegetic period fiction, NOT accessibility scaffolding. New `Settings → Accessibility → Enhanced Hit Feedback` opt-in toggle (forward dep).
> - **SAI cross-domain obligations removed**: Combat now owns its own timer defensiveness (DEAD-state gate in Combat's callbacks). OQ-CD-1 trimmed to only UNCONSCIOUS state + `receive_damage -> bool` return.
> - Godot API blockers fixed: `collide_with_areas = true` specified for hitscan queries; `section_exited(reason)` replaced with existing `respawn_triggered` signal; `class_name` collision resolved; dart wall-hit filter added.
> - AC testability gaps addressed: time-advancement mechanism specified; trivially-passing AC rewritten; `@blocked` / `@prototype_gated` enforcement documented.

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
| **Takedown blade** (stealth 1-shot) | Composed — the silent blade is the *archetype* of composed removal. One action, one obstacle removed, scene continues. | **Pass** |
| **Silenced pistol** (gunfight, 3-shot TTK) | Composed — muffled pops, deliberate aim. The 3-shot TTK rewards headshot discipline (1 head + 1 body = dead) without collapsing into twitch-shooter binary. | **Pass** |
| **Dart gun** (non-lethal projectile) | Composed — one compressed-air puff, one arc, silence. | **Pass** |
| **Rifle** (rare pickup, 1-shot body) | Tonal exception — a deliberate chosen moment. Eve picks the rifle up in specific mission beats (§D.3, §D.5); it is the "escalation has reached the rooftop" register, not everyday combat. Scope zoom dramatizes the decision to use it. | **Pass with carve-out** (see §F.1 note) |
| **Fists** (edge-case fallback, 7-swing KO) | **Tonal exception — accepted slapstick.** Fists exist as the rare last-resort when every other weapon is dry. The 7-swing / 4.9 s cycle IS slapstick (per Matt Helm cautionary reference in §V.8) — and that is acknowledged. The design response is to make fists *rare* via ammo generosity (§F.6), not to fix the slapstick. | **Carve-out** — see §B note below |

### Fists carve-out (accepted tonal exception)

The /design-review pass flagged fists as a Composed Removal failure: 7 swings / 4.9 s per guard reads as Matt Helm slapstick, not Emma Peel composure. The creative-director agreed this is a structural mismatch that no tuning in the `fist_base_damage` safe range `[13, 20]` can resolve. **The design response is to accept the mismatch and mitigate its frequency rather than change the mechanic.**

- Fists remain at `fist_base_damage = 16` HP / 7 swings / 4.9 s per KO (no mechanical change).
- Ammo reserves are raised substantially (§F.6) so the expected frequency of fists-as-fallback drops from "every Section 3+" to "rare emergency." A player who plays the game normally should encounter fists as a primary solve fewer than 2–3 times across the full Tier 1 mission.
- When fists ARE used, the resulting slapstick register is explicitly folded into Pillar 1 (Comedy Without Punchlines). An exhausted Eve reduced to punching a 120 kg henchman seven times in a row is the kind of matter-of-fact absurdity Pillar 1 is built for. The comedy lands because Eve does not change register — she punches with the same composure she would reload with.
- Players who want to avoid fists entirely can do so via cache collection + the softened ammo economy (F.6 math: expected ammo supply is 30% above expected demand at normal-route play).

**The test is not "are fists composed?" — it is "how often will a competent player need to use them?" The answer is "almost never," and the GDD's job is to make that answer true, not to redesign the weapon.**

### Pillar alignment

- **Pillar 3 (Stealth is Theatre, Not Punishment)** — load-bearing. Combat is fail-forward. Getting forced into a shootout does not end the run; it *escalates the scene*. The trigger pull is the scene shifting register, not a fail state breaking in. COMBAT de-escalates back to SEARCHING, and SEARCHING back to SUSPICIOUS; nothing is permanent except a body.
- **Pillar 5 (Period Authenticity Over Modernization)** — the *mechanism* by which Pillar 3 lands. Period-authentic restraint (no vignette, no hit markers, no damage-direction indicators, no kill cam) is what keeps combat legible as *theatre* rather than as punishment. A red damage vignette would make every hit read as "you're losing"; its absence makes every hit read as "the scene is getting louder."
- **Pillar 1 (Comedy Without Punchlines)** — supporting. Comedy lands through guard reactions, guard banter, and the absurd tableau of 1960s spy violence in a museum gallery. Never through Eve being cool.
- **Pillar 2 (Discovery Rewards Patience)** — supporting. The patient observer's path still beats the shootout path: ammo scarcity, the cost of alerting the next guard, and the dart gun's non-lethal premium all keep observation the *better* solution; combat remains valid-but-costlier.

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
| Crosshair dot (default on) | **Neither** — accessibility affordance, not part of Eve's diegesis (see §UI-1 revised rationale) | **Keep with honest framing** |
| Enhanced Hit Feedback toggle (Settings → Accessibility) | **Opt-in only** — changes the accessibility layer, not Eve's register | **Keep (opt-in)** |

This test resolves future combat-feel debates and links directly to the Forbidden Patterns section. **It is NOT applied to accessibility scaffolding** — Pillar 5 governs diegetic fiction, not player accommodation (CD ruling, 2026-04-21).

## Detailed Design

### C.1 Core Rules

**CR-1 Damage routing.** All damage flows through `CombatSystem.apply_damage_to_actor(actor, amount, source, damage_type)`. The helper duck-types on the receiver (`actor.has_method("apply_damage")` → Eve's F.6 path; `actor.has_method("receive_damage")` → guard mirror path). Invalid actors (`is_instance_valid(actor) == false`) `push_warning` and return. **Callers MUST NOT mutate actor health directly.**

**CR-2 Signal emit-site ownership.** After `actor.receive_damage(...)` returns (with its new `-> bool is_dead` return — see OQ-CD-1), CombatSystem emits `enemy_damaged(actor, amount, source)`, then if `is_dead == true` also `enemy_killed(actor, source)` in the same call stack. Deterministic order: mutation → `enemy_damaged` → `enemy_killed`. Eve's path emits `player_damaged` → `player_health_changed` → optional `player_died` (owned by PC F.6, NOT re-emitted here).

**CR-3 Weapon roster.** Revised 2026-04-21 — takedown blade split out from silenced pistol to resolve dual-identity blocker.

| Weapon | Class | Delivery | Lethal? | ADS | Context | Audio SFX |
|---|---|---|---|---|---|---|
| **Takedown blade** *(NEW)* | Stealth tool | Melee contact (stealth-only) | Yes (1-shot) | No | Gated by SAI contact-prompt in PATROL/NOTICED/SUSPICIOUS | Faint blade draw + muffled contact (~180 ms) |
| Silenced pistol | Primary (gunfight) | Hitscan | Yes (3-shot body / 2-shot head) | No | Gunfights only — NOT used for takedowns | Period-accurate ~110 dB suppressed pop + mechanical ratchet |
| Dart gun | Primary (non-lethal) | Projectile | No (KO) | No | Any state — quiet | Compressed-air puff + dart whistle (~400 ms) |
| Rifle | Rare pickup | Hitscan | Yes (1-shot body) | **Yes (1.5× zoom)** | Chosen moments (§D.3, §D.5) — tonal exception | Louder single-shot report + bolt action |
| Fists | Edge-case fallback | Melee cone | No (KO) | No | Last resort — ammo generosity keeps this rare | Cloth impact + knuckle thud |

**Takedown blade vs silenced pistol — cleanly separated identities**:
- **Takedown blade** is a dedicated silent stealth weapon. It fires ONLY via SAI's `receive_takedown(STEALTH_BLADE, attacker)` path, gated by context prompt (guard is unaware / not in COMBAT, player is behind or adjacent). Cannot be drawn in gunfight. 1-shot lethal. No ammo. Animation: a brief 200 ms blade draw + stroke.
- **Silenced pistol** is a gunfight weapon only. 3-shot body TTK / 2-shot head TTK. Same weapon in the player's hand throughout gunfights — no modal surprise. The pistol cannot perform a 1-shot takedown even at point-blank range against an unaware guard; the prompt for takedown routes to the blade.

This resolves the design-review BLOCKER that the same silenced pistol was producing 1-shot lethal AND 3-shot lethal outcomes depending on a state (takedown-vs-gunfight) that the player could not reliably perceive.

Weapon *entity* ownership (Resource, mesh, ammo UI) belongs to Inventory & Gadgets (forward dep); Combat owns fire/damage math + post-fire signal emits. **Inventory forward dep**: blade Resource schema (no ammo, `base_damage = 100`, `damage_type = DamageType.MELEE_BLADE`) + blade-draw input handler. Documented in §Dependencies → Forward dependencies.

**CR-4 Flat damage model.** Each weapon has one base damage number (final values in §D). No distance falloff. No armor/resistance. **Headshots on guards** deliver 2× base damage (multiplier computed internally; `enemy_damaged.amount` is post-multiplier). **No headshot damage on Eve** — guards always hit body-only.

**CR-5 Hitscan-then-perturb accuracy** (revised 2026-04-21 — `collide_with_areas = true` specified). Hitscan uses:
```gdscript
var query := PhysicsRayQueryParameters3D.create(from, to)
query.collide_with_areas = true       # REQUIRED — headshot Area3D detection (F.5) depends on this
query.collide_with_bodies = true      # default, explicit for clarity
query.exclude = [shooter.get_rid()]   # shooter excludes itself (avoids guard self-hit in friendly-fire mode)
query.collision_mask = _build_mask_for_shooter(shooter)
var result := space_state.intersect_ray(query)
```
Aim vector is perturbed by a random offset inside a cone whose half-angle depends on shooter state + range (formula in §D F.2). This preserves environmental audio feedback: a near-miss hits the wall and the wall-impact SFX fires. Eve-fired shots cast against `MASK_AI | MASK_WORLD`; guard-fired shots cast against `MASK_WORLD | MASK_AI | MASK_PLAYER` (AI included iff `GUARD_FRIENDLY_FIRE_ENABLED == true`). Neither uses `MASK_PROJECTILES`. The `collide_with_areas = true` flag is MANDATORY — without it, `intersect_ray` returns only `CollisionObject3D` bodies, and the head `Area3D` (F.5) is silently skipped. This was flagged as a /design-review blocker.

**Guard self-exclusion** (resolves ai-programmer Finding 7): the firing guard's own RID is always excluded from its own raycast via `query.exclude = [shooter.get_rid()]`. Without this, a guard's hitscan can intersect its own body capsule at the ray origin when `MASK_AI` is included (friendly-fire mode) and apply damage to itself.

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

Resolves /design-review: dart-on-wall no longer spams `push_warning` (world geometry is filtered early); same-tick double-hit (body + head Area3D) is suppressed by `_has_impacted` flag. Darts exiting map bounds or living > 4 s auto-free.

**CR-7 Melee contact (fists).** Cone-shaped ShapeCast3D from camera origin, ~0.7 m range, 30° half-angle, 1 hit per swing. Windup 0.3 s → hit resolves on windup-end frame → recovery 0.4 s. Deliberately high shot count to KO a full-HP guard (§D specifies).

**CR-8 Crosshair.** Static Ink Black `#1A1A1A` center dot, ~6 px diameter at 1080p, period-scope-reticle style. **Enabled by default.** Disableable via `Settings → Accessibility → Crosshair`. The dot does NOT expand/contract, does NOT change color on enemy hover, does NOT hit-marker flash. Pillar 5 preserved — it reads as a period-plausible reticle dot, not modern FPS UX.

**CR-9 Aim-down-sights (rifle only).** `Aim` input hold tweens camera FOV 85° → 55° over 200 ms (ease-out), fades in an optical-scope reticle overlay, reduces muzzle sway 50%, halves accuracy spread cone. Release reverses over 150 ms. ADS is cancelled by: reloading, weapon-switch, or damage ≥ `interact_damage_cancel_threshold` (10 HP). Pistol / dart / fists have no ADS analog.

**CR-10 Fire input gating.** Fire blocked while `_is_reloading || _is_switching_weapon || _is_fist_swinging || _is_hand_busy || InputContext != GAMEPLAY`. No fire-queue on gated input — press is dropped.

**CR-11 Ammo scarcity (Pillar 2 enforcement).** Eve starts each mission with limited reserves per weapon (final values §D). Guards yield a single-magazine drop of whatever weapon they held, picked up via PC's existing `player_interacted` raycast. Dart gun reserves are deliberately scarce — its non-lethal premium is paid in bullets. Fall-through when primary runs dry: pistol → fists (never dart; dart scarcity is the cue to seek pickups). Rifle is rare and kept for chosen moments, not a de-facto fallback.

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
- `LOS ⇄ SUPPRESSION` based on SAI's cached LOS result (read every idle tick; no guard-of-Eve state peek)
- `SUPPRESSION → CAPPED` when `suppression_count == 3`; CAPPED is silent (no further shots) until LOS reacquired
- `CAPPED → LOS` resets `suppression_count = 0` on LOS reacquisition (fresh suppression cycle if LOS lost again)
- Any → `IDLE` on `guard.alert_state_changed(state != COMBAT)` OR `is_instance_valid(self) == false` OR `guard.alert_state == DEAD | UNCONSCIOUS`

**Defensive gate (replaces E.24's SAI obligation)**: every timer callback begins with:
```gdscript
if not is_instance_valid(guard) or guard.current_alert_state in [AlertState.DEAD, AlertState.UNCONSCIOUS]:
    _fire_mode = FireMode.IDLE
    _los_timer.stop()
    _suppression_timer.stop()
    return
```
This means: if a guard dies or is dart-KO'd, the fire controller silently cleans up on its next scheduled tick. No unilateral obligation on SAI's DEAD-entry handler.

**Projectile cleanup on respawn (replaces phantom `section_exited(reason)` signal)**: the controller subscribes to `Events.respawn_triggered` (already declared in ADR-0002). On that signal, all per-guard fire timers stop and the global `ProjectileManager` frees in-flight darts. This uses the EXISTING signal, not a phantom `section_exited(reason=RESPAWN)` overload that doesn't exist in ADR-0002.

Timers are per-guard `Timer` nodes on the idle tick (not `_physics_process`). Timer node count scales with guard-count-in-COMBAT (typically 0–3 simultaneous at MVP guard density); performance budget reviewed against SAI's AC-SAI-4.4 (1 ms signals+state sub-budget) — add Combat timer cost to that measurement.

**CR-13 Guard friendly fire.** `GUARD_FRIENDLY_FIRE_ENABLED` (default `true`). When true, a guard's hitscan ray striking another guard calls that guard's `receive_damage` at base damage (no 2× — no guard-on-guard headshots). Per-section override available via the section's `SectionConfig` resource (Mission Scripting's authoring concern). When false, guard-fired rays cast with `collision_mask = MASK_WORLD | MASK_PLAYER` only (AI mask excluded).

**CR-14 Return-fire timer handshake (cross-system contract with SAI).** Each guard subscribes to `Events.player_damaged`. Handler resets the guard's `_combat_lost_target_timer` (owned by SAI — defined in SAI Tuning Knobs as `COMBAT_LOST_TARGET_SEC`, default 8.0 s) iff `source == self AND current_alert_state == COMBAT`. This is the sole mechanism by which "Eve took damage from me" feeds SAI's COMBAT → SEARCHING de-escalation logic. Combat does NOT call guard methods directly — the signal bus is the coupling.

**Signal-connection-order discipline** (resolves E.25 same-frame ordering race): the guard's `_ready()` MUST connect `Events.player_damaged` BEFORE `_combat_lost_target_timer.timeout`. Godot's dispatch preserves signal-emission order; connecting in this order guarantees the reset handler runs before the timeout handler in the same frame. This is a SAI implementation note — Combat defines the ordering guarantee, SAI honors it in the guard scene script.

**CR-15 Takedown lethal-damage delegation** (revised 2026-04-21 — now uses takedown blade). When SAI's `receive_takedown(STEALTH_BLADE, attacker)` routes to lethal damage, SAI calls `CombatSystem.apply_damage_to_actor(self, blade_takedown_damage=100, attacker, DamageType.MELEE_BLADE)`. This resolves the SAI forward dependency — `apply_damage_to_actor` ships here. The silenced pistol is NOT a takedown-delegation target; it is gunfight-only. `receive_takedown(SILENCED_PISTOL, ...)` is removed from the takedown-type enumeration (coordination with SAI amendment — see OQ-CD-1).

**CR-16 UNCONSCIOUS state consequence.** Guards reaching 0 HP via `DamageType.DART_TRANQUILISER` transition to `SAI.AlertState.UNCONSCIOUS` (6th state, SAI GDD amendment required — see OQ-CD-1). Guards reaching 0 HP via any other lethal DamageType transition to `SAI.AlertState.DEAD`. UNCONSCIOUS guards: no perception, no vocal, body remains at final pose, outline tier MEDIUM persists. For MVP, UNCONSCIOUS behaves identically to DEAD at the gameplay level — the state exists to preserve narrative distinction (alive-but-sleeping vs dead) and future-proof post-MVP body-drag + Mission Scripting tagging.

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

**Fist-swing rules.** Windup 0.3 s → hit resolves → recovery 0.4 s → total cycle 0.7 s. **Not cancellable** once windup begins. Damage during swing does NOT cancel. Fist-swinging locks weapon-switch until recovery completes.

### C.3 Interactions with Other Systems

| System | Direction | Interface | Contract owner |
|---|---|---|---|
| **Player Character** | Inbound (upstream) | `actor.apply_damage(amount, source, damage_type)` | PC F.6 frozen. Combat calls; PC emits `player_damaged` → `player_health_changed` → optional `player_died` internally. |
| **Stealth AI — guard damage intake** | Inbound (upstream) | `actor.receive_damage(amount, source, damage_type) -> bool is_dead` | SAI §Interactions — pending amendment OQ-CD-1 to add `-> bool` return. SAI owns → DEAD or → UNCONSCIOUS transition per DamageType. |
| **Stealth AI — takedown delegation** | Inbound (SAI calls here) | `CombatSystem.apply_damage_to_actor(...)` | This GDD ships the helper. SAI calls for `STEALTH_BLADE` lethal takedown path. |
| **Stealth AI — return-fire timer** | Outbound (signal) | Guard subscribes `Events.player_damaged` | Guard resets `_combat_lost_target_timer` iff `source == self && state == COMBAT`. |
| **Audio** | Outbound (signal bus) | `weapon_fired`, `enemy_damaged`, `enemy_killed`, `player_damaged` (PC), `player_health_changed` (PC), `player_died` (PC) | ADR-0002 frozen. All 6 consumed by Audio §Combat domain. |
| **HUD Core** | Outbound (via PC signal) | `Events.player_health_changed` | Forward dep. PC emits; HUD subscribes. Combat does not emit. |
| **Inventory & Gadgets** | Bidirectional (forward dep) | `Events.weapon_fired(weapon, position, direction)` emit-site in Inventory | Inventory owns weapon Resources; Combat reads `weapon.base_damage`, `weapon.fire_rate_sec`, `weapon.magazine_size`, `weapon.damage_type` on each fire. Weapon Resource schema declared in Inventory GDD. |
| **Failure & Respawn** | Outbound (via PC signal) | `Events.player_died(cause: CombatSystem.DeathCause)` | Forward dep. PC emits; Failure & Respawn subscribes. Combat owns the `DeathCause` enum. |
| **Mission & Level Scripting** | Outbound (signal) | `Events.enemy_killed(enemy, killer)` | Forward dep. Subscribed for objective progression ("eliminate all hostiles in zone"). |
| **Level Streaming** | Inbound (signal) | `Events.respawn_triggered(section_id: StringName)` + `Events.section_entered(section_id: StringName)` | **Revised 2026-04-21**: `section_exited(section_id, reason: TransitionReason)` was a phantom signature — ADR-0002 only declares `section_exited(section_id: StringName)` with no `reason` parameter. Combat now subscribes to the EXISTING `respawn_triggered` signal (already in ADR-0002) for in-flight dart cleanup + GuardFireController IDLE transitions. Normal section transitions listen to `section_entered` for checkpoint-save timing only. |
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

**Per-weapon base damage values (canonical)** — revised 2026-04-21 to reflect takedown-blade split:

| Weapon | `base_damage` | Body TTK (100 HP guard) | Headshot result | Notes |
|---|---|---|---|---|
| **Takedown blade** (NEW) | **100** | 1-shot lethal (stealth only) | N/A — stealth blade has no hit zones | SAI calls via `receive_takedown(STEALTH_BLADE, eve)` → `apply_damage_to_actor(guard, 100, eve, DamageType.MELEE_BLADE)`. Gated by contact prompt; CANNOT be used in COMBAT state |
| Silenced pistol (gunfight only) | **34** | 3 body shots (102 dmg) | 68 dmg (2-shot head kill) | Body kill: shot 1 = 34, shot 2 = 68, shot 3 = 102 (lethal). 1 headshot = 68 (damaging); 1 head + 1 body = 102 (lethal). **No takedown damage constant** — takedowns route exclusively to the blade. |
| Dart gun | **150** | 1 dart (KO) | N/A — routed via `DART_TRANQUILISER` → UNCONSCIOUS | 150 > 100 HP ensures 1-shot KO with tuning headroom |
| Rifle | **120** | 1 body shot (lethal) | 240 dmg (overkill) | Tonal exception — "chosen moments" weapon per §B weapon-register table. 1-shot body-kill niche; headshot is double-overkill |
| Fists | **16** | 7 hits (112 dmg) | N/A — no headshot on melee cone | **Edge-case fallback only** — see §B fists carve-out. 7 swings × 0.7 s cycle = 4.9 s per guard. Expected frequency kept low via §F.6 ammo generosity |
| Guard pistol (vs Eve) | **18** | 5.5-hit kill (100 / 18) | N/A — guards hit body only | Above PC `interact_damage_cancel_threshold` (10 HP); Pillar 3 survivable at 5–6 hits. **Safe range tightened** from `[14, 25]` to `[14, 20]` to honor AC-CD-14.1's "Eve cannot die in fewer than 5 hits" invariant (`ceil(100/20) = 5`) |

**Output Range:** `final_damage ∈ [13, 240]` (fist_base_damage at safe floor to rifle headshot). Raw value passed through; `apply_damage_to_actor` does not clamp — receiving actor's intake path handles sub-zero / DEAD gates. Registry `damage_formula.output_range` updated to `[13, 240]` (was incorrectly `[16, 240]`).

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

**Design rationale for sqrt(randf()):** Uniform `randf()` (flat disk density) would produce equal probability of 1° miss and 9° miss — unrealistic. `sqrt(randf())` transforms to radially-uniform disk density: probability ∝ `r`, so most shots cluster near center with a diminishing tail toward the cone edge. This approximates the perceived "mostly near misses, occasional wild shots" feel. **Why not `randfn()`?** `randfn(mean, deviation)` has existed since Godot 4.0 (the pre-revision claim that it's "post-4.5" was factually incorrect — flagged by godot-specialist). The real reason to prefer `sqrt(randf())` is that a Gaussian can produce unbounded samples requiring rejection sampling or clamping to stay within the spread cone. `sqrt(randf())` is bounded-by-construction and has no rejection loop.

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
- Spawn position: `camera.global_position + aim_direction × 0.5` (prevents Eve's capsule self-collision)
- `collision_layer = PhysicsLayers.MASK_PROJECTILES` (layer 5)
- `collision_mask = MASK_WORLD | MASK_AI` (hits world and guards; NOT Eve, NOT other projectiles)
- `continuous_cd = true` (Jolt CCD — prevents tunneling at 20 m/s through thin geometry)
- On `body_entered(body)`: calls `CombatSystem.apply_damage_to_actor(body, dart_damage, self, DamageType.DART_TRANQUILISER)` then `queue_free()`

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

**Jolt caveats (OQ-CD-2 scope expanded):** Set the Area3D's shape to `LAYER_AI` (layer 3) with mask 0 (it does NOT initiate overlap queries itself). The prototype at `prototypes/guard-combat-prototype/` must validate THREE Jolt-specific unknowns:
1. **Bone-attached Area3D + intersect_ray**: does Jolt return the Area3D as `collider` in `intersect_ray` results with `collide_with_areas = true`? (primary OQ-CD-2 question)
2. **BoneAttachment3D pose lag in physics tick**: does the Area3D world-space transform reflect the CURRENT animated pose when queried from `_physics_process`, or does it lag one frame behind `_process`? (added per godot-specialist Finding 7)
3. **`RigidBody3D.continuous_cd` under Jolt**: does Jolt respect the CCD property for the dart projectile, or does it require a Jolt-specific property? (added per godot-specialist Finding 8)

**Output:** Binary — `true` or `false`.

**Worked example — rifle shot hits guard head zone:**
`hit_collider` = `<Area3D on BoneAttachment3D>`; `is_in_group("headshot_zone") == true` → `is_headshot = true`. F.1: `120 × 2.0 = 240`. 240 > 100 HP → instant lethal.

**Worked example — pistol shot hits guard torso:**
`hit_collider` = `<CapsuleShape3D on body>`, not in `headshot_zone` group → `is_headshot = false`. F.1: `34 × 1.0 = 34` (body damage).

### F.6 Ammo Economy Tables

**Design pivot 2026-04-21** — revision pass in response to /design-review: ammo reserves raised substantially (expected supply ~30% above expected demand at normal-route play). The softened Pillar 2 scarcity is intentional — per user direction, "normal amount of ammo, not pressured low." Pillar 2 (Discovery Rewards Patience) is preserved through observation incentive, guard patrol patterns (SAI), and cache placement that rewards off-path exploration; it no longer rides entirely on ammo starvation.

**Starting inventory at Tier 1 mission start (REVISED):**

| Weapon | Magazine Size | Starting Reserve | Total | Notes |
|---|---|---|---|---|
| Takedown blade | 1 (the blade itself) | — | — | Unlimited uses; gated by SAI contact prompt (cannot be used in COMBAT state) |
| Silenced pistol | 8 rounds | **32 rounds** (was 16) | 40 rounds | ~8 body-kills or ~12 headshot kills before dry; Aggressive dry by Section 4–5 (was Section 3) |
| Dart gun | 4 darts | **16 darts** (was 8) | 20 darts | Ghost can KO ~20 guards standalone; with placed caches + 100% pickup rate has comfortable surplus |
| Rifle | 0 | 0 | 0 | Pickup-only — never in starting inventory |
| Fists | ∞ | ∞ | ∞ | Always available; 7 hits/guard (4.9 s). **Expected frequency: rare** per §B carve-out. |

**Guard drops (pickup via PC's `player_interacted` raycast) — REVISED:**

| Kill method | Guard carrying silenced pistol | Guard carrying rifle | Any guard dart-KO'd | Any guard fist-KO'd |
|---|---|---|---|---|
| Lethal (pistol/rifle/blade) | 8 rounds (1 magazine) | 3 rounds (partial) | — | — |
| Non-lethal dart KO | 0 pistol rounds | 0 rifle rounds | **1 dart** (break-even) | — |
| Non-lethal fist KO | 0 pistol rounds | 0 rifle rounds | — | **0 darts** (revised from 1 — closes fist-farm loop) |

**Dart anti-farm invariant (revised)**: KO'ing a guard via dart spends 1 dart and yields 1 dart. Net = 0. Fist KO yields 0 darts (fists are a zero-cost weapon — cannot net-positive dart supply). The break-even rule is now strictly "dart-for-dart"; fists cannot be used to farm darts. `guard_drop_dart_ko_rounds` replaced by two knobs: `guard_drop_dart_on_dart_ko = 1` (break-even) and `guard_drop_dart_on_fist_ko = 0` (no farm).

**Real-play pickup rate acknowledgement**: the break-even invariant assumes 100% dart retrieval. In practice, ~80% is a more realistic estimate (some darts land off-ledge, behind locked doors, or in hot zones). The raised starting reserve (16, was 8) provides the margin to absorb the ~20% drain without forcing Section-5 ghost softlock. Placed caches (below) cover the remainder. Section 5 boss adds a bespoke non-lethal path specified in Mission & Level Scripting forward dep — **boss can be fist-KO'd if ghost is fully dart-dry** (tonal exception already accepted for fists).

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

**Depletion curve sanity check (revised numbers):**
- Aggressive player (all lethal, pistol-only): 30 guards × 3 shots = 90 rounds needed. Starting 40 + caches (8+8+8+12+12+8=56) = 96 total if all caches collected. Expected dry around Section 4–5 if caches are skipped, surviving Section 5 with rifle pickup supplementing. **Softer than before but still creates Pillar 2 reward for observation** (finding caches matters).
- Ghost player (all dart KO): 30 guards × 1 dart = 30 darts needed. Starting 20 + caches (3×5 sections + 4 Sec4 = 16) + break-even drops ≈ 30+ darts available at ~80% pickup. **Viable without fists**, with margin.

**Pickup cap** (resolves E.32): per-weapon reserve cap is `pistol_max_reserve = 48`, `dart_max_reserve = 24` (~1.5× starting reserve). Pickup past cap loses excess. Inventory & Gadgets forward-dep owns the clamp.

### Summary Table — Tuning Knob Feeds

| Parameter | Default | Safe Range | Prototype Gate? | Notes |
|---|---|---|---|---|
| `silenced_pistol_base_damage` | 34 | [28, 45] | No | Body TTK 3-shot; headshot 2-shot |
| `blade_takedown_damage` | 100 | [100, 150] | No | Stealth blade 1-shot-lethal damage (CR-15 SAI delegation via `DamageType.MELEE_BLADE`). Replaces `silenced_pistol_takedown_damage` per CR-3 revision 2026-04-21. |
| `dart_damage` | 150 | [100, 200] | No | 1-shot KO with headroom |
| `rifle_base_damage` | 120 | [100, 150] | No | 1-shot body kill niche |
| `fist_base_damage` | 16 | [13, 20] | No | 7-hit desperation |
| `guard_pistol_damage_vs_eve` | 18 | [14, 20] | **Yes** (Tier 1 playtest) | Pillar 3 survivability feel. Tightened from [14, 25] on 2026-04-21 to honor AC-CD-14.1 (`ceil(100/20) = 5` min hits to kill). |
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
| `pistol_starting_reserve` | 32 | [16, 48] | No | 4× magazine ratio. Revised from 16 on 2026-04-21 to cover Aggressive-player depletion curve through Section 4–5 without cache reliance. |
| `dart_magazine_size` | 4 | [3, 6] | No | Paired with dart scarcity |
| `dart_starting_reserve` | 16 | [8, 24] | No | 4× magazine ratio. Revised from 8 on 2026-04-21 to absorb ~20% dart-pickup miss rate and keep Ghost path viable without fists. |
| `rifle_magazine_size` | 3 | [2, 5] | No | Pickup-only |
| `rifle_pickup_reserve` | 6 | [3, 9] | No | Per-pickup amount |
| `respawn_floor_pistol_total` | 16 | [8, 32] | No | TOTAL (magazine + reserve) minimum at respawn. Consumed by Failure & Respawn. Renamed from `respawn_ammo_floor_pistol` (magazine-only ambiguity resolved 2026-04-21). |
| `respawn_floor_dart_total` | 8 | [4, 16] | No | TOTAL (magazine + reserve) minimum at respawn. Renamed from `respawn_ammo_floor_dart` 2026-04-21. |
| `guard_drop_dart_on_dart_ko` | 1 | {1} fixed | No | Break-even anti-farm invariant. Split from `guard_drop_dart_ko_rounds` 2026-04-21. |
| `guard_drop_dart_on_fist_ko` | 0 | {0} fixed | No | Fist-KO yields no darts — closes fist-farm loop (Pillar 2). Split from `guard_drop_dart_ko_rounds` 2026-04-21. |
| `guard_friendly_fire_enabled` | true | {true, false} | No | Per-section overridable |

**Prototype-gated values (5):** `guard_pistol_damage_vs_eve`, `eve_spread_deg`, `dart_speed_m_s`, `dart_gravity_scale`, `head_zone_radius_m`. Recommend `prototypes/guard-combat-prototype/` covers all 5 in a single playtest scene.

## Edge Cases

### Damage resolution

- **E.1 Two damage calls arrive for the same actor on the same physics frame**: both execute sequentially; if the first already killed the actor, the second's `receive_damage` must gate on `current_alert_state in [DEAD, UNCONSCIOUS]` and return `is_dead = true` without re-emitting state changes. `apply_damage_to_actor` emits `enemy_damaged` both times; subscribers tolerate duplicates. `enemy_killed` fires only on the first kill.
- **E.2 Dead guard receives a subsequent bullet**: `receive_damage` returns `is_dead = true` immediately (DEAD gate). `enemy_damaged` emits on corpse; `enemy_killed` does not re-emit. No state change. Audio plays no vocal (guard is DEAD).
- **E.3 UNCONSCIOUS guard is shot by pistol/rifle/fists**: SAI overwrites UNCONSCIOUS → DEAD per CR-16. `enemy_killed` fires with the shooter as killer (the original UNCONSCIOUS dart-hit did NOT fire `enemy_killed` — see OQ-CD-2 below). Second-hit kill path is intentional for Mission Scripting tagging (e.g. "no-lethals run" objective can't be satisfied if player re-shoots KO'd guards).
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

- **E.18 Dart hits UNCONSCIOUS guard**: `collision_mask` still includes `MASK_AI`; dart collides, `receive_damage` sees UNCONSCIOUS target, returns `is_dead=true` without state change (UNCONSCIOUS terminal for darts — re-KO is no-op). `enemy_damaged` emits; `enemy_killed` does NOT re-emit (see OQ-CD-2 for the original UNCONSCIOUS-entry emission question).
- **E.19 Dart hits Eve**: dart `collision_mask = MASK_WORLD | MASK_AI` explicitly excludes `MASK_PLAYER`. Dart passes through Eve's capsule. Intentional per F.4 spawn contract.
- **E.20 Dart hits dead guard corpse**: corpse remains on `LAYER_AI`; dart collides, `receive_damage` returns `is_dead=true` (DEAD gate). `enemy_damaged` emits on corpse. Dart frees. Duplicate-on-corpse tolerated by subscribers.
- **E.21 Dart hits world geometry (wall, floor)**: `apply_damage_to_actor` routes via duck-type; `has_method("apply_damage")` false, `has_method("receive_damage")` false → `push_warning` + return. Dart frees. Wall-impact SFX is a separate Audio subscriber on `body_entered`, not Combat's concern.
- **E.22 Two darts in flight simultaneously**: both exist as independent RigidBody3D. Each has own `body_entered`. Darts do not collide with each other (`MASK_PROJECTILES` excluded from dart mask).
- **E.23 Eve dies while a dart is in flight**: `player_died` → `section_exited(reason=RESPAWN)` → ProjectileManager frees all tracked in-flight darts before they hit anything. `enemy_killed` from that dart will NOT fire.

### Guard fire cadence

- **E.24 Guard killed while fire-cadence timer is running** (revised 2026-04-21): `GuardFireController` callbacks begin with a defensive state-check (CR-12 defensive gate). If the guard is DEAD or UNCONSCIOUS when a scheduled timer fires, the callback enters IDLE and stops its own timers. **No SAI obligation** — SAI's DEAD-entry handler does not need to stop Combat's timers. This resolves the cross-domain contract violation flagged in the /design-review.
- **E.25 COMBAT_LOST_TARGET_SEC expires same frame as Eve takes damage**: CR-14's reset is synchronous (`_combat_lost_target_timer.stop(); _combat_lost_target_timer.start(COMBAT_LOST_TARGET_SEC)`). **Signal-connection-order guarantee** (CR-14 addition): `Events.player_damaged` must be connected before `_combat_lost_target_timer.timeout` in the guard scene `_ready()` — this ordering ensures the reset handler runs before the timeout handler in the same idle tick. If connection order is violated, the reset loses the race; verified by AC-CD-5.1.
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
| **Level Streaming** | ✅ Approved | `Events.section_exited(section_id, reason: TransitionReason)` | Combat listens for RESPAWN to clean up in-flight projectiles. Without subscription, in-flight darts during respawn cause minor visual artifacts but no crash (darts auto-free at 4.0 s). |
| **Input** | Designed | `Fire`, `Aim`, `Reload`, `WeaponSwitch`, `Melee` input actions | Combat reads these per-frame. Without Input's action definitions, Combat cannot trigger — but input mapping is Input GDD's authoring concern, not a live integration. |
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
| **Failure & Respawn** | `respawn_floor_pistol = 8`, `respawn_floor_dart = 4`, `RESPAWN_AMMO_FLOOR_*` constants declared here; respawn logic reads them | Combat owns the constants; Failure & Respawn GDD will cite them. |
| **Mission & Level Scripting** | `SectionConfig.guard_friendly_fire_enabled` field consulted per-shot; trigger volumes must filter dart body types | Combat GDD defines the query contract; Mission Scripting authors the Resource. |
| **Rifle entity** | Rifle weapon Resource at pickup-only spawn points; `rifle_pickup_reserve = 6` standard drop | Inventory & Gadgets authors the Rifle Resource; Level Streaming's section registry places pickup locations. |

### ADR dependencies (consumed, not authored here)

| ADR | Status | Combat's consumption |
|---|---|---|
| **ADR-0001 Stencil ID Contract** | Proposed | Muzzle flashes + impact sparks = tier 0 (no outline); dart projectile + trail = tier 3 LIGHT. **ADR-0001 needs clarification added: explicit VFX-exempt language** (flagged in Art Bible §8K amendment). |
| **ADR-0002 Signal Bus + Event Taxonomy** | Proposed | 6 Combat-domain signals; `CombatSystem.DamageType` and `CombatSystem.DeathCause` enum ownership. **ADR-0002 amendment pending (SAI's severity param + `takedown_performed` 3-arg sig) — shared with SAI, not new work for Combat.** |
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
| `fist_base_damage` | 16 | [13, 20] | <13 = 8+ swing KO, fists become impractical | >20 = 5-swing KO, fists become too viable (breaks Pillar 2 ammo scarcity pressure) |
| `guard_pistol_damage_vs_eve` | 18 | **[14, 20]** (tightened 2026-04-21) | <14 = Eve takes 7+ hits, combat feels weightless | >20 = Eve dies in 4 hits, Pillar 3 "5+ hit survivability" breaks. Previous ceiling of 25 allowed 4-hit kill, inconsistent with AC-CD-14.1 |

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
| `pistol_starting_reserve` | **32** (revised 2026-04-21 from 16) | [16, 48] | <16 = aggressive player dry by Section 2 | >48 = softens Pillar 2 too far; depletion curve stops producing observation reward |
| `dart_magazine_size` | 4 | [3, 6] | 3 = uncomfortable | >6 = spray darts, non-lethal premium collapses |
| `dart_starting_reserve` | **16** (revised 2026-04-21 from 8) | [8, 24] | <8 = ghost player can't KO tutorial chokepoints even with break-even | >24 = Pillar 2 non-lethal premium collapses; placed caches become irrelevant |
| `rifle_magazine_size` | 3 | [2, 5] | 2 = cannot use rifle tactically | >5 = rifle too generous |
| `rifle_pickup_reserve` | 6 | [3, 9] | <3 = rifle pickup worthless | >9 = rifle too dominant |
| `guard_drop_pistol_rounds` | 8 | [4, 12] | <4 = balanced player goes dry | >12 = aggressive player's depletion curve breaks |
| `guard_drop_rifle_rounds` | 3 | [1, 5] | <1 = no point carrying rifle | >5 = rifle ammo becomes farmable |
| `guard_drop_dart_on_dart_ko` (renamed 2026-04-21) | 1 | {1} | — | Fixed at 1 — break-even invariant. Previous `{0, 1}` range incorrectly allowed Pillar-2-breaking value |
| `guard_drop_dart_on_fist_ko` (NEW 2026-04-21) | 0 | {0} | — | Fixed at 0 — fist KO cannot farm darts (closes fist-farm loop flagged by economy-designer + systems-designer) |

**Invariants**: `guard_drop_dart_on_dart_ko == 1` and `guard_drop_dart_on_fist_ko == 0`. Any other values break the break-even anti-farm rule (see F.6 + AC-CD-12.2).

### G.6 Respawn floor (Cross-system — consumed by Failure & Respawn) — revised 2026-04-21

| Knob | Default | Safe Range | Notes |
|---|---|---|---|
| `respawn_floor_pistol_total` | 16 | [8, 32] | TOTAL (magazine + reserve) minimum at respawn. Consumed by Failure & Respawn at restore. Prevents softlock; applied ONLY on first death per checkpoint (see F.6 floor anti-farm). Revised from `respawn_ammo_floor_pistol = 8` (magazine-only ambiguity resolved). |
| `respawn_floor_dart_total` | 8 | [4, 16] | Same — TOTAL minimum dart reserve at respawn. Replaces `respawn_ammo_floor_dart` (ambiguous scope). |
| `pistol_max_reserve` (NEW) | 48 | [24, 64] | Hard cap on reserve ammo; pickup past cap loses excess (E.32 + Inventory forward dep). Also used by `clamp()` in restore_weapon_ammo to sanitize corrupted snapshots. |
| `dart_max_reserve` (NEW) | 24 | [16, 32] | Hard cap on dart reserve; same function as pistol cap. |

### G.8 Accessibility (NEW — added 2026-04-21 per UX review)

| Knob | Default | Safe Range | Notes |
|---|---|---|---|
| `hud_damage_flash_duration_frames` | 1 | [1, 6] | Health-numeric white flash duration. Default 1 frame preserves Deadpan Witness restraint; 6-frame max (100 ms) sits above the ~50 ms conscious-perception threshold. Exposed to players via `Settings → Accessibility → Damage Flash Duration` (forward dep to Settings GDD). |
| `enhanced_hit_feedback_enabled` | `false` | {true, false} | Opt-in non-diegetic direction pulse per V.6 + UI-5. Default OFF preserves Pillar 5 diegetic fiction; ON surfaces damage-direction signal for hearing-impaired players. Owned by Settings & Accessibility GDD. |
| `crosshair_halo_enabled` | `true` | {true, false} | 1 px Parchment halo ring around crosshair dot per UI-1. Default ON for contrast legibility. Users on pure-Pillar-5 immersion play can disable halo while keeping dot on (or disable crosshair entirely via `crosshair_enabled`). |

### G.7 Behavior flags (Designer-facing)

| Knob | Default | Range | Notes |
|---|---|---|---|
| `guard_friendly_fire_enabled` | `true` | {true, false} | Per-section overridable via Mission Scripting `SectionConfig`. Global default on for comedy (Pillar 1). |

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
| **Enhanced Hit Feedback** (OPT-IN, Settings → Accessibility) | A subtle radial-edge pulse localized to the incoming shot direction (15% screen-edge opacity, 120 ms duration, desaturated warm-grey, NOT a red vignette). Surfaces damage-direction information for hearing-impaired players. Off by default; honors the accessibility carve-out ruling. | Settings & Accessibility GDD (forward dep); Combat supplies the behavioral contract here |

**Accessibility carve-out rationale (creative-director ruling, 2026-04-21)**: Pillar 5 (Period Authenticity Over Modernization) governs *diegetic period fiction* — no GPS markers, no modern UX paternalism, no kill cams. It does NOT govern accessibility scaffolding. A hearing-impaired player who cannot perceive the 150 ms hit SFX OR the ≤25 HP clock-tick has only two remaining hit signals: the 1-frame HUD flash (16 ms, below typical conscious-perception threshold) and the 3° / 100 ms camera dip. Both are low-salience under combat stress. Without an opt-in carve-out, Pillar 5 becomes a structural access barrier.

**Enhanced Hit Feedback specification**: the opt-in pulse is INTENTIONALLY non-diegetic — it reads as an accessibility aid, not as a "damage vignette" Eve sees. It is desaturated (not red), brief (120 ms), and only 15% edge opacity. It is direction-localized (maps to the world-space angle between Eve and the shot origin). When the setting is OFF (default), no such pulse is ever rendered — the out-of-box experience is identical to the pre-revision "period-authenticity cut." When ON, the toggle changes ONLY this one signal; all other Pillar 5 forbidden patterns (red vignette, hit marker, LOW HEALTH text, damage arrow) remain forbidden.

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

### UI-1 Crosshair (revised 2026-04-21 — rationale rewritten, contrast halo added)

**Rationale revised.** The pre-revision draft framed the crosshair as "period-scope reticle style" to justify Pillar 5 compliance. The /design-review pass flagged this as rationalization: a static center dot is a modern FPS affordance, not a 1960s optical scope. The honest framing is **accessibility-first**: most players expect a crosshair for ranged-weapon aim, and removing it entirely would create unnecessary friction for a significant portion of the audience. The crosshair is accepted as an accessibility affordance, and is kept honest by being OPT-OUT rather than rationalized as period-authentic.

**Specification:**

- Static Ink Black `#1A1A1A` center dot, **~4 px diameter** at 1080p (reduced from 6 to minimize visual weight)
- **1 px Parchment `#E8DFC8` halo ring** around the dot (1 px stroke). Provides minimum 3:1 contrast against any gameplay background — addresses low-contrast failure against dark environments (shadowed alleys, night-side geometry)
- **Enabled by default** (accessibility-first default)
- Opt-out via `Settings → Accessibility → Crosshair` toggle AND surfaced as a duplicate entry point under `Settings → HUD → Crosshair` for discovery (both UIs read the same setting value — single source of truth owned by Settings & Accessibility GDD)
- Does NOT expand/contract with movement
- Does NOT change color on enemy hover
- Does NOT hit-marker flash on kill
- Hidden when `InputContext != GAMEPLAY` (menu, document overlay, cutscenes, loading, pause)

**Why keep it on by default?** Practical: most players expect a crosshair and removing it creates needless friction on a first boot. Honest: this is NOT a period-authenticity claim. Players who want a fully period-immersed experience can opt out in one click. Players who need the crosshair for motor/visual accommodation have it available by default. The Section B "Composed Removal" design test is NOT applied here — it governs diegetic fiction, not accessibility affordances (see §B design test final row, added 2026-04-21).

**Implementation ownership:** HUD Core renders the crosshair widget; Combat has no direct UI responsibility beyond specifying the behavior. HUD Core consumes `Settings.crosshair_enabled` from the Settings & Accessibility GDD (single setting, two discovery paths).

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
- **Flash duration** is now configurable via `hud_damage_flash_duration_frames` knob (G.8), default 1 frame, safe range [1, 6]. Accessibility opt-in via Settings → Accessibility → Damage Flash Duration.
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

**Not affected by Pillar 5 (accessibility defaults, always rendered):**

- Center-dot crosshair with 1 px Parchment halo (UI-1) — default on, opt-out only
- Health numeric flash (default 1 frame, configurable 1–6 frames per `hud_damage_flash_duration_frames`)
- 25 HP threshold typographic weight shift (Bold) as colorblind-safe secondary to Alarm Orange hue shift

Coverage: AC-CD-14.3 validates absence of the "Always forbidden" items via screenshot evidence at 15 HP during active gunfight WITH Enhanced Hit Feedback OFF. Separate AC (AC-CD-14.4) validates that the enabled pulse is NOT red and renders only when toggle is ON.

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

- **AC-CD-1.5 [Logic]** **GIVEN** the `damage_type_to_death_cause()` static function, **WHEN** called with each of the 5 `DamageType` values (`BULLET`, `DART_TRANQUILISER`, `MELEE_FIST`, `FALL_OUT_OF_BOUNDS`, `TEST`), **THEN** returns the corresponding `DeathCause` value as specified in C.4, with no `push_warning` for any mapped value. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

  - Variant: calling with an out-of-range integer literal triggers `push_warning` and returns `DeathCause.UNKNOWN`.

### AC-CD-2 Weapon Damage Values (F.1)

- **AC-CD-2.1 [Logic]** **GIVEN** a guard stub at 100 HP and `is_headshot = false`, **WHEN** `apply_damage_to_actor` is called with the canonical `base_damage` for each weapon, **THEN** the guard's HP delta equals `base_damage × 1.0` within epsilon 0.001 for: silenced pistol (34), dart gun (150), rifle (120), fists (16), guard pistol vs Eve path (18). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  - Parametrized: [silenced_pistol=34, dart=150, rifle=120, fists=16, guard_pistol=18].

- **AC-CD-2.2 [Logic]** **GIVEN** a guard stub at 100 HP and `is_headshot = true`, **WHEN** `apply_damage_to_actor` is called for silenced pistol (base 34) and rifle (base 120), **THEN** the damage applied equals `base_damage × 2.0` within epsilon 0.001 (pistol: 68.0, rifle: 240.0). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

- **AC-CD-2.3 [Logic]** **GIVEN** Eve's `apply_damage` path (actor has `apply_damage`, not `receive_damage`), **WHEN** any shot arrives with `is_headshot = true`, **THEN** the `target_is_guard` gate prevents headshot multiplier application — HP delta equals `base_damage × 1.0` (verified via Eve stub that records received amount). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

- **AC-CD-2.4 [Logic]** **GIVEN** a guard stub at exactly 100 HP, **WHEN** three silenced pistol body shots arrive via `apply_damage_to_actor` (34 each = 102 cumulative), **THEN** guard is DEAD after shot 3 — `receive_damage` returns `is_dead = true` on the third call. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  - Variant: two headshots (34 × 2 = 68 each = 136 cumulative) → DEAD after shot 2.

- **AC-CD-2.5 [Logic]** **GIVEN** the blade takedown path (CR-15) with `blade_takedown_damage = 100`, **WHEN** SAI calls `apply_damage_to_actor(guard, 100, eve, DamageType.MELEE_BLADE)` with `is_headshot = false`, **THEN** guard receives exactly 100 HP damage and `receive_damage` returns `is_dead = true` (guard at 100 HP → dead in one call). Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

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

- **AC-CD-7.1 [Logic]** **GIVEN** a guard at 100 HP, **WHEN** `apply_damage_to_actor(guard, 150, eve, DamageType.DART_TRANQUILISER)` is called, **THEN** guard transitions to `AlertState.UNCONSCIOUS` (not `DEAD`), `receive_damage` returns `is_dead = true`, `Events.enemy_damaged` emits, and `Events.enemy_killed` does NOT emit. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

  @blocked(reason: "OQ-CD-1 must close: SAI GDD amendment needed to add `UNCONSCIOUS` AlertState and confirm `enemy_killed` suppression on DART path — verify before writing the `enemy_killed` suppression assertion.")

- **AC-CD-7.2 [Logic]** **GIVEN** a guard at 100 HP, **WHEN** `apply_damage_to_actor(guard, 120, eve, DamageType.BULLET)` is called, **THEN** guard transitions to `AlertState.DEAD` (not `UNCONSCIOUS`). Parametrized: `[DamageType.BULLET, DamageType.MELEE_FIST, DamageType.FALL_OUT_OF_BOUNDS]` — all lethal types → DEAD. Evidence: `tests/unit/combat/combat_damage_routing_test.gd`

### AC-CD-8 Spread Cone Formula (F.2)

- **AC-CD-8.1 [Logic]** **GIVEN** the `calculate_spread_angle_deg(movement_state, cover_modifier, distance_m)` function, **WHEN** called with all four movement states at distance 5 m with no cover, **THEN** output equals `[2.0, 3.5, 3.0, 6.0]` ± 0.001 deg for `[STATIONARY, WALKING, CROUCHED_STATIONARY, SPRINTING]`. Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.2 [Logic]** **GIVEN** the spread formula at distance 10 m, Eve SPRINTING, cover active, **WHEN** `calculate_spread_angle_deg(SPRINTING, 4.0, 10.0)` is called, **THEN** result equals `6.0 + 4.0 + (3.0 × (10.0 − 8.0) / 8.0) = 10.75°` ± 0.001. Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.3 [Logic]** **GIVEN** a caller passing `distance_m >= 16.0`, **WHEN** the fire-eligibility gate is evaluated, **THEN** the guard does not fire and `calculate_spread_angle_deg` is never invoked for that call (verified by confirming no `weapon_fired` emit). Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.4 [Logic]** **GIVEN** the formula at DEFAULT tuning values, **WHEN** all boundary inputs are exercised (min: STATIONARY, no cover, 0 m; max: SPRINTING, cover, 15.99 m), **THEN** output is within `[2.0, 13.0]` deg. **Separately** (revised 2026-04-21): at SAFE-RANGE CEILING tuning, output is within `[2.0, 20.0]` deg (no runtime overflow, no NaN, no negative values). Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

- **AC-CD-8.5 [Logic]** **GIVEN** `guard_range_falloff_start_m` and `guard_range_falloff_end_m` knob values at their current configured values, **WHEN** the invariant `start_m < end_m` is evaluated, **THEN** `(end_m - start_m) > 0.001` — asserted as a constant validation test. Any tuning change that sets `start_m >= end_m` surfaces as a test failure BEFORE runtime, preventing the division-by-zero in the `range_falloff` formula. Evidence: `tests/unit/combat/combat_spread_cone_test.gd`

### AC-CD-9 Ray Sampling Distribution (F.3)

- **AC-CD-9.1 [Logic]** **GIVEN** `sample_cone_direction` seeded with a fixed RNG seed (e.g. `seed(12345)`), **WHEN** called 1000 times with `spread_angle_deg = 13.0`, **THEN** the angular deviation of every returned vector from `aim_dir` is within `[0°, 13°]` (assert `max_deviation <= 13.0°` across all 1000 calls). Evidence: `tests/unit/combat/combat_sample_cone_distribution_test.gd`

- **AC-CD-9.2 [Logic]** **GIVEN** the same seeded run of 1000 samples with `spread_angle_deg = 13.0`, **WHEN** the distribution is analyzed, **THEN** median angular deviation is less than 7.5° (confirming center-biased density from `sqrt(randf())` — a flat distribution would median near 9.2°). Evidence: `tests/unit/combat/combat_sample_cone_distribution_test.gd`

- **AC-CD-9.3 [Logic]** **GIVEN** the returned `perturbed_direction` vector, **WHEN** `length()` is called, **THEN** result equals `1.0 ± 0.0001` (unit vector contract). Evidence: `tests/unit/combat/combat_sample_cone_distribution_test.gd`

### AC-CD-10 Dart Projectile Physics (F.4)

- **AC-CD-10.1 [Logic]** **GIVEN** a dart RigidBody3D instance spawned with defaults, **WHEN** initial state is inspected, **THEN** `linear_velocity.length() ≈ 20.0 m/s ± 0.001`, `gravity_scale == 0.0`, and lifetime timer is set to `4.0 s ± 0.001`. Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

- **AC-CD-10.2 [Logic]** **GIVEN** a dart in flight past its `dart_lifetime_s = 4.0 s`, **WHEN** the timer fires, **THEN** `queue_free()` is called (dart node is no longer in the scene tree). Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

- **AC-CD-10.3 [Logic]** **GIVEN** a dart's `body_entered(body)` signal fires against a guard Node, **WHEN** the callback executes, **THEN** `CombatSystem.apply_damage_to_actor(body, dart_damage, self, DamageType.DART_TRANQUILISER)` is called exactly once, then `queue_free()` is called. Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

- **AC-CD-10.4 [Logic]** **GIVEN** a dart spawned with `collision_mask` set per F.4 contract, **WHEN** collision layers are read, **THEN** `MASK_PLAYER` bit is NOT set in the collision mask (dart cannot hit Eve). Evidence: `tests/unit/combat/combat_dart_projectile_test.gd`

### AC-CD-11 Headshot Detection (F.5)

- **AC-CD-11.1 [Logic]** **GIVEN** a hitscan ray result where `hit_collider.is_in_group("headshot_zone") == true`, **WHEN** headshot detection is evaluated, **THEN** `is_headshot = true` and `final_damage = base_damage × 2.0`. Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

- **AC-CD-11.2 [Logic]** **GIVEN** a hitscan ray result where `hit_collider` is the guard's body CapsuleShape3D (not in "headshot_zone" group), **WHEN** headshot detection is evaluated, **THEN** `is_headshot = false` and `final_damage = base_damage × 1.0`. Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

- **AC-CD-11.3 [Logic]** **GIVEN** the takedown delegation path (CR-15), **WHEN** `receive_takedown(STEALTH_BLADE, attacker)` routes to `apply_damage_to_actor(guard, 100, eve, DamageType.MELEE_BLADE)`, **THEN** `is_headshot` is explicitly `false` — takedown damage of 100 is passed without multiplier (blade has no hit zones). Evidence: `tests/unit/combat/combat_headshot_detection_test.gd`

- **AC-CD-11.4 [Integration]** **GIVEN** a guard scene with `Area3D` on `BoneAttachment3D(bone: "head")` tagged `"headshot_zone"`, **WHEN** the guard is placed in a Godot 4.6 + Jolt physics scene and a raycast targets the head Area3D, **THEN** `intersect_ray` returns the Area3D as `collider`. Evidence: `tests/integration/combat/combat_headshot_detection_jolt_test.gd`

  @prototype_gated(reason: "OQ-CD-2 — Jolt + bone-attached Area3D inclusion in intersect_ray results must be validated in the fire-cadence prototype.")

### AC-CD-12 Ammo Economy (F.6)

- **AC-CD-12.1 [Logic]** **GIVEN** a fresh mission start, **WHEN** player inventory is initialized, **THEN** silenced pistol has `magazine = 8, reserve = 16`; dart gun has `magazine = 4, reserve = 8`; rifle has `magazine = 0, reserve = 0`. Evidence: `tests/unit/combat/combat_ammo_economy_test.gd`

- **AC-CD-12.2 [Logic]** **GIVEN** a guard KO'd via dart (non-lethal), **WHEN** the loot drop is generated, **THEN** dart drop count == 1 (break-even anti-farm invariant). Evidence: `tests/unit/combat/combat_ammo_economy_test.gd`

  - Variant: guard KO'd via fists → dart drop count == 1.
  - Variant: guard killed lethally carrying silenced pistol → pistol drop == 8 rounds; dart drop == 0.

- **AC-CD-12.3 [Logic]** **GIVEN** ammo at respawn checkpoint below the floor values, **WHEN** respawn restore is applied, **THEN** pistol total ammo (magazine + reserve) = `max(snapshot_total, respawn_floor_pistol_total=16)` and dart total ammo = `max(snapshot_total, respawn_floor_dart_total=8)`; rifle ammo = snapshot value unchanged. Evidence: `tests/integration/combat/combat_respawn_ammo_floor_test.gd`

  - Variant: ammo at checkpoint ABOVE the floor → restore returns checkpoint value unchanged (no free refill).

- **AC-CD-12.4 [Integration]** **GIVEN** a simulated aggressive playthrough killing all guards lethally in Sections 1–2, **WHEN** entering Section 3, **THEN** pistol reserve is ≤ 0 OR requires Section 3 pickup to continue. Evidence: `production/qa/evidence/combat-damage/manual-pillar-2-depletion-curve.md`

  @prototype_gated(reason: "Tier 0 playtest required to confirm guard count per section and drop rates produce depletion by Section 3.")

### AC-CD-13 Crosshair and ADS (CR-8, CR-9)

- **AC-CD-13.1 [UI]** **GIVEN** the game launched fresh with default settings, **WHEN** Eve is in GAMEPLAY InputContext, **THEN** a static Ink Black `#1A1A1A` center dot (~6 px at 1080p) is visible, does not expand or contract with movement, and does not change color on enemy hover. Evidence: `production/qa/evidence/combat-damage/manual-crosshair-accessibility-toggle.md`

- **AC-CD-13.2 [UI]** **GIVEN** `Settings → Accessibility → Crosshair` is toggled off, **WHEN** the setting is applied, **THEN** the center dot disappears and does not reappear until re-enabled; no other HUD element is affected. Evidence: `production/qa/evidence/combat-damage/manual-crosshair-accessibility-toggle.md`

- **AC-CD-13.3 [Logic]** **GIVEN** Eve holding the rifle and pressing `Aim` input, **WHEN** time is advanced via `gut.simulate(player, 13, 1.0/60.0)` (~216 ms > 200 ms tween duration), **THEN** camera FOV == `55.0° ± 0.5°` (tweened from 85° over 200 ms ease-out, sampled at tween end). Evidence relocated 2026-04-21 from `combat_weapon_damage_test.gd` to dedicated `tests/unit/combat/combat_ads_test.gd`.

- **AC-CD-13.4 [Logic]** **GIVEN** a test fixture that sets `eve_spread_deg = 1.0°` (overriding default 0.0°), rifle ADS active (FOV at 55°), **WHEN** `calculate_spread_angle_deg` is computed for the rifle while ADS-active, **THEN** output == `0.5° ± 0.001°` (eve_spread_deg × 0.5 halving applied). **Rewritten 2026-04-21**: previous AC asserted `0.0 × 0.5 == 0.0` which passed trivially regardless of whether halving was implemented. Fixture override ensures meaningful coverage at default as well as prototype values. Evidence: `tests/unit/combat/combat_ads_test.gd`

  @prototype_gated(reason: "Tier 1 playtest may set eve_spread_deg > 0.0 as the shipped default; fixture override ensures AC has coverage either way.")

### AC-CD-14 Pillar Compliance

- **AC-CD-14.1 [Logic]** **GIVEN** Eve at 100 HP and `guard_pistol_damage_vs_eve = 18` (default), **WHEN** the minimum number of guard shots to reach 0 HP is computed, **THEN** `ceil(100 / 18) = 6` shots required — Eve dies in EXACTLY 6 hits at default. **Safe-range invariant**: at safe-range ceiling `guard_pistol_damage_vs_eve = 20` (tightened 2026-04-21 from 25), `ceil(100 / 20) = 5` — Eve cannot die in fewer than 5 hits under ANY legal tuning. Pillar 3 "no single-hit kill from full health, 5+ hit survivability" is guaranteed across the safe range. Evidence: `tests/unit/combat/combat_weapon_damage_test.gd`

  @prototype_gated(reason: "Final default value may shift within [14, 20] after Tier 1 playtest. Assertion `ceil(100 / value) >= 5` holds for all values in the safe range.")

- **AC-CD-14.2 [Integration]** **GIVEN** an aggressive playthrough of Sections 1–3 where Eve kills all guards lethally, **WHEN** Eve reaches Section 3 without picking up any caches, **THEN** pistol reserve is 0 and weapon falls through to fists — Pillar 2 ammo scarcity is felt. Evidence: `production/qa/evidence/combat-damage/manual-pillar-2-depletion-curve.md`

- **AC-CD-14.3 [Visual]** **GIVEN** Eve at 15 HP (below 25 HP clock-tick threshold), actively in a gunfight, AND `enhanced_hit_feedback_enabled == false` (default), **WHEN** a screenshot is taken of the full viewport, **THEN** the screenshot contains: no red or color-tinted screen edge vignette, no hit marker overlaid on the crosshair, no damage-direction indicator, and no "LOW HEALTH" text. **Pass criterion**: screenshot reviewed by QA lead (manual inspection of all four screen-edge pixel regions + crosshair area); reviewer records verdict in evidence markdown. Evidence: `production/qa/evidence/combat-damage/manual-pillar-5-no-modern-ui.md`

- **AC-CD-14.4 [Visual] (NEW 2026-04-21)** **GIVEN** Eve at 15 HP, `enhanced_hit_feedback_enabled == true` (opt-in), AND a guard fires from the right, **WHEN** Eve takes a hit and a screenshot is captured during the 120 ms pulse window, **THEN** the right screen edge shows a desaturated warm-grey pulse at ≤15% opacity (NO red / saturated color), localized to the guard's world-space angle from Eve. **AND** with `enhanced_hit_feedback_enabled == false` under identical conditions, NO such pulse renders. **Pass criterion**: screenshot review confirms opacity + hue constraints; toggle-off screenshot is blank-edge (matches AC-CD-14.3). Evidence: `production/qa/evidence/combat-damage/manual-enhanced-hit-feedback.md`

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

- **AC-CD-17.5 [Config/Data]** **GIVEN** `head_zone_radius_m` is at default value 0.15, **WHEN** a smoke check runs, **THEN** value is within safe range `[0.10, 0.20]` and headshot-fairness playtest has recorded a verdict. Evidence: `production/qa/evidence/combat-damage/manual-dart-feel-playtest.md`.

  @prototype_gated(reason: "Tier 1 playtest required to confirm 0.15 m radius does not feel lottery or shoulder-overlapping.")

### Open blocked items (revised 2026-04-21 — enforcement via tests/.blocked-tests.md manifest)

- **AC-CD-7.1** is blocked on **OQ-CD-1** (SAI UNCONSCIOUS AlertState amendment + `receive_damage -> bool` signature).
- **AC-CD-11.4** is blocked on **OQ-CD-2** (Jolt + bone-attached Area3D in `intersect_ray` results — EXPANDED SCOPE: also validates BoneAttachment3D physics-tick pose lag + RigidBody3D CCD under Jolt).
- **AC-CD-16.1, AC-CD-16.2** (NEW entry 2026-04-21) blocked on ADR-0003 (Save Format Contract) Accepted status + Save/Load GDD authoring.
- **AC-CD-11.4** has hard deadline: unblocked before any sprint containing headshot-implementation stories can enter.

### Test file tree (revised 2026-04-21 — split oversized files, added helpers)

```
tests/helpers/
  SignalRecorder.gd                      (ordered-emission spy for AC-CD-1.1, 1.4, 15.x)
  WarningCapture.gd                      (push_warning spy for AC-CD-1.2, 1.3)

tests/unit/combat/
  combat_damage_routing_test.gd          (AC-CD-1.1–1.5, 7.1–7.2)
  combat_weapon_damage_test.gd           (AC-CD-2.1–2.5, 14.1)
  combat_input_gating_test.gd            (AC-CD-3.1–3.2)          # NEW — split from weapon_damage
  combat_ads_test.gd                     (AC-CD-13.3, 13.4)       # NEW — split from weapon_damage
  combat_spread_cone_test.gd             (AC-CD-8.1–8.5)
  combat_sample_cone_distribution_test.gd (AC-CD-9.1–9.3)
  combat_dart_projectile_test.gd         (AC-CD-10.1–10.4)
  combat_headshot_detection_test.gd      (AC-CD-11.1–11.3)
  combat_ammo_economy_test.gd            (AC-CD-12.1–12.2)
  combat_guard_cadence_test.gd           (AC-CD-4.1–4.4)
  combat_signal_ordering_test.gd         (AC-CD-15.1–15.3)

tests/integration/combat/
  combat_takedown_delegation_test.gd     (AC-CD-6.1)
  combat_return_fire_timer_test.gd       (AC-CD-5.1)
  combat_respawn_ammo_floor_test.gd      (AC-CD-12.3, 16.1–16.2 — BLOCKED on ADR-0003 + Save/Load GDD)
  combat_headshot_detection_jolt_test.gd (AC-CD-11.4 — BLOCKED pending OQ-CD-2)

production/qa/evidence/combat-damage/
  manual-pillar-2-depletion-curve.md     (AC-CD-12.4, 14.2)
  manual-pillar-3-ttk-verification.md    (AC-CD-14.1 — prototype-gated)
  manual-pillar-5-no-modern-ui.md        (AC-CD-14.3)
  manual-enhanced-hit-feedback.md        (AC-CD-14.4 — NEW 2026-04-21)
  manual-crosshair-accessibility-toggle.md (AC-CD-13.1–13.2)
  manual-dart-feel-playtest.md           (AC-CD-17.3, 17.5)

tests/.blocked-tests.md                  (manifest — enforces @blocked annotations)
```

## Open Questions

### Pre-implementation gates (BLOCKING — must resolve before Combat stories enter sprints)

- **OQ-CD-1 [SAI amendment — MINIMAL SCOPE]** Stealth AI GDD requires two amendments (trimmed from the pre-revision 3-item bundle; timer-stop obligation and post-suppression-cap behavior removed per Combat defensive-internal decision 2026-04-21):
  1. Add `AlertState.UNCONSCIOUS` as 6th alert state (per CR-16 dart routing).
  2. Change `receive_damage(amount, source, damage_type)` signature to return `bool is_dead` (per C.5 duck-type dispatch).

  **Resolved contradiction** (flagged by /design-review ai-programmer): `enemy_killed` does NOT emit when UNCONSCIOUS is first reached. Per AC-CD-7.1 (authoritative), the dart path emits `enemy_damaged` only; UNCONSCIOUS is a non-DEAD terminal state for Mission Scripting bookkeeping purposes. This resolves the pre-revision draft's conflict between OQ-CD-1 item 3 and AC-CD-7.1.

  **Takedown-type amendment (NEW — bundled here)**: SAI's takedown-type enum must include `STEALTH_BLADE` (new) and REMOVE `SILENCED_PISTOL` (obsolete — pistol no longer performs takedowns). See CR-3 + CR-15 revision.

  **Owner**: `technical-director` + SAI author (user) via a new `/design-system` revision of SAI. **Blocks**: AC-CD-7.1 unblocks; AC-CD-6.1 is-dead return value works correctly. **Estimated effort**: 1 session (touch 2–3 paragraphs of SAI GDD + update registry).

- **OQ-CD-2 [Jolt physics validation — EXPANDED SCOPE 2026-04-21]** Godot 4.6 + Jolt 3D prototype must verify three API unknowns (per F.5 revision):
  1. Does `PhysicsDirectSpaceState3D.intersect_ray` (with `collide_with_areas = true`) include `Area3D` on `BoneAttachment3D` children as `collider`?
  2. Does the `Area3D` world-space transform reflect the CURRENT animated pose when queried from `_physics_process`, or does it lag a frame behind `_process`?
  3. Does `RigidBody3D.continuous_cd = true` correctly enable CCD under Jolt (or does Jolt require a different property path)?
  **Owner**: `godot-specialist` validation via throwaway prototype in `prototypes/guard-combat-prototype/`. **Blocks**: AC-CD-11.4 can be asserted as passing + AC-CD-10.1 dart CCD behavior confirmed. **Estimated effort**: 60-minute prototype + written finding (revised up from 30 min for expanded scope).

### Forward-dep gates (resolve when dependent GDD is authored)

- **OQ-CD-3 [Weapon fallthrough — Inventory & Gadgets]** When Eve's magazine + reserve are both 0 for a weapon: does the player manually switch to fists, or does Combat auto-switch the current weapon slot to fists? Affects E.8 + UI-2 fists transition behavior. **Owner**: Inventory & Gadgets GDD authoring pass. **Combat contract**: pressing fire on an empty weapon is a no-op; Inventory decides the next-weapon logic.

- **OQ-CD-4 [Fist-swing target selection]** When a ShapeCast3D cone returns multiple collision results (E.16), should Combat sort by distance-from-camera and pick the nearest, or use first-result-from-Jolt? **Owner**: prototype decision via `prototypes/guard-combat-prototype/`; ~15 minutes of testing. **Default pending prototype**: nearest-target sort.

- **OQ-CD-5 [Mission objective save race]** Does Mission Scripting save objective state synchronously at the same checkpoint that Combat's `enemy_killed` fires, or lazily? If lazy, a one-frame race exists where a guard is killed and saved as DEAD but the objective "eliminate guard X" has not yet completed. Affects E.36. **Owner**: Mission Scripting GDD authoring pass. **Combat contract**: `enemy_killed` fires synchronously from `apply_damage_to_actor`; save checkpoint timing is Mission Scripting's concern.

- **OQ-CD-11 [Takedown blade Resource schema — Inventory & Gadgets] (NEW 2026-04-21)** With the pistol-takedown split, the takedown blade is a new weapon Resource. Inventory & Gadgets GDD must author: blade Resource fields (`base_damage = 100`, `damage_type = DamageType.MELEE_BLADE`, no magazine / no reserve); blade-draw input binding; context-prompt gating (blade only available when SAI `receive_takedown` prompt is live). Combat contract is frozen here; Inventory resolves the Resource shape.

- **OQ-CD-12 [Settings & Accessibility forward deps] (NEW 2026-04-21)** Multiple accessibility contracts are declared here with no owning GDD yet:
  1. `Settings → Accessibility → Crosshair` toggle (opt-out)
  2. `Settings → Accessibility → Enhanced Hit Feedback` toggle (opt-in non-diegetic direction pulse)
  3. `Settings → Accessibility → Damage Flash Duration` slider (1–6 frames)
  4. `Settings → HUD → Crosshair` duplicate discovery entry
  5. Potential `ads_tween_duration_multiplier` knob (vestibular sensitivity)
  **Owner**: Settings & Accessibility GDD authoring pass. **Combat contract**: behavioral spec is here; persistence + UI placement owned by Settings.

- **OQ-CD-13 [Pillar 5 boundary clarification doc] (NEW 2026-04-21)** The creative-director ruled during revision that Pillar 5 governs diegetic fiction, NOT accessibility scaffolding. This ruling affects multiple future GDDs (HUD State Signaling, Document Overlay UI, Settings & Accessibility). A short Pillar 5 Boundary Clarification doc should be written to the design directory so future authors don't re-litigate. **Owner**: `creative-director` — optional follow-up, does not block Combat approval.

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
