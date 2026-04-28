# Inventory & Gadgets

> **Status**: **Approved pending Coord items 2026-04-24** — user accepted in-session revisions without fresh re-review. Sprint cannot start until BLOCKING Coord items close (#2 ADR-0002 amendment, #3 Registry Phase 5b, #7 SAI BAIT_SOURCE, #8 Combat apply_fire_path, #9 Input GDD L91, #10 save-load.md schema). `/design-review` verdict MAJOR REVISION NEEDED with 12 blockers + disagreements across 6 specialists + creative-director senior synthesis was resolved via inline revision pass. User-approved revision decisions applied inline: (1) **OQ-INV-1 resolved Option B** — Parfum-KO drops nothing (anti-farm invariant preserved; requires SAI `guard_incapacitated(guard, cause: DamageType)` signature via ADR-0002 amendment). (2) **CR-15 auto-cycle past dry weapons** — pistol reserve dry now routes to next available weapon in scroll order, matching NOLF1 baseline and preserving Crouched Swap vignette. (3) **CR-5b revised to "investigating-guard claims the case"** — Cigarette Case queue_frees when the investigating guard's SUSPICIOUS investigation resolves (returns to UNAWARE); single-distraction-beat design intent preserved without spam exploits. (4) **Compact gains noise-event cost** — activation emits a small positional NoiseEvent (CURIOSITY_BAIT, radius 3m) so peek is not "free perfect info"; aligns with Pillar 3 risk-weighted observation. Editorial fixes: (5) `Combat.apply_fire_path` declared as Coordination item — Combat GDD amendment required before sprint. (6) CR-11 save/restore pattern unified to `LevelStreamingService.register_restore_callback` per LS CR-2, renamed `_on_restore_from_save`, schema aligned with save-load.md. (7) F.3 single-drop bug fixed — offset gated on `guard_index > 0`; counter reset boundary corrected to `_physics_process` start. (8) F.6 `net_ghost = 0 LOCKED` reframed — "LOCKED at 0% miss" + acknowledgment of ~10% realistic miss rate. (9) Medkit economy capped at 3/mission (Coord item #5 Mission Scripting). *(2026-04-28 update — cap raised 3 → 7 per `/review-all-gdds` 2026-04-28 GD-B4 design decision: 1 medkit guaranteed per section post-Plaza (Lower 1 / Restaurant 1 / Upper 2 / Bomb 1 = 5 guaranteed) + 2 off-path bonus = 7 total. Closes the late-mission health-scarcity death-spiral risk identified in the cross-review. MLS §C.5 + §G.3 + AC-MLS-7.3 swept; this header is informational — actual cap source is MLS.)* (10) Cache plan reduced to 8 pistol + 2 dart off-path caches across 5 sections. (11) CR-16 blade+fire silent-reject gains dry-click SFX. (12) CURIOSITY_BAIT cross-ref fixed. (13) CR-10 mesh-swap ordering specified (hide-then-queue_free). (14) OQ-INV-4 tiebreaker changed to `get_instance_id()`. (15) AC-INV-9.1 pattern count 7→8. (16) AC-INV-8.4 / 8.5 rewritten to callback-spy / manual-evidence. (17) Vignette 2 rewritten to "two field devices" to match 2-of-3 pre-packed. (18) New Coordination items added for Input GDD L91 single-dispatch clarification + Combat GDD `apply_fire_path` declaration.
> **Author**: user + game-designer (primary) + systems-designer + gameplay-programmer + godot-specialist (feasibility) + art-director + audio-director + ux-designer + qa-lead (consulting) + creative-director (review verdict)
> **Last Updated**: 2026-04-24 (revision pass on 2026-04-24 `/design-review` MAJOR REVISION NEEDED)
> **Implements Pillars**: 2 (Discovery Rewards Patience), 3 (Stealth is Theatre, Not Punishment), 5 (Period Authenticity Over Modernization), 1 (Comedy Without Punchlines — secondary, via gadget flavor)
> **Source Concept**: `design/gdd/game-concept.md`
> **Systems Index Row**: #12 · MVP · Feature Layer · M effort
> **Dependencies (upstream, locked)**: Player Character ✅, Input ✅, Combat & Damage ✅, ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0006
> **Dependents (forward)**: Mission & Level Scripting, Failure & Respawn, HUD Core, Save / Load, Settings & Accessibility

## Overview

Inventory & Gadgets owns every carryable item on Eve Sterling — the 4 weapons (silenced pistol, dart gun, rifle, takedown blade), a small roster of 3–5 BQA-issued gadgets (exact list settled in §Detailed Design), the consumable medkit path, and the `WorldItem` pickup entities that spawn from guard drops and authored caches. It is simultaneously (a) the **data layer** — Weapon and Gadget Resources (`*.tres`) whose schema Combat & Damage reads on every fire (`base_damage`, `fire_rate_sec`, `magazine_size`, `damage_type`) — and (b) the **player-facing inventory verb** — slots 1..5 for direct weapon selection, `weapon_next/prev` for NOLF1-style scroll cycling, `use_gadget` for activation (mutexed against `takedown` via `SAI.takedown_prompt_active`), `gadget_next/prev` for rotary gadget selection, and the priority-2 `interact` hook that pockets anything Eve's raycast resolves to a pickup. The system is a **child node of `PlayerCharacter`** (`class_name InventorySystem extends Node`), not an autoload — autoload count and slot allocation are owned by ADR-0007 (consult ADR-0007 §Canonical Registration Table for current count and ordering). It publishes 4 frozen signals from the Inventory domain of the Signal Bus (`gadget_equipped`, `gadget_used`, `weapon_switched`, `ammo_changed`) and owns the `weapon_fired` emit-site that Combat, Audio, and Stealth AI all subscribe to. Contracts are anchored in **ADR-0001** (stencil Tier 1 for held items and pickups per the ADR-0001 canonical table, so BQA gadgets and guard-dropped ammo stay legible against 1960s interior chrome), **ADR-0002** (the 4 Inventory-domain signals + the `weapon_fired` emit-site), **ADR-0003** (`InventoryState extends Resource` with typed `@export` fields for ammo dict, equipped gadget, cooldowns, and current weapon), **ADR-0004** (HUD Core subscribes to this GDD's signals via `project_theme.tres` + `FontRegistry` — this GDD does NOT render), and **ADR-0006** (`LAYER_PROJECTILES` for thrown/launched gadget colliders). **This GDD defines**: Weapon Resource schema, Gadget Resource schema, ammo accounting (magazine + reserve + pickup cap clamp), the gadget roster and cooldown model, the pistol-reserve-dry → fists auto-fallthrough resolution (Combat OQ-CD-3), `WorldItem` pickup entity, and the drop-spawn rules on `enemy_killed`. **This GDD does NOT define**: fire math or damage resolution (Combat & Damage), HUD rendering (HUD Core), pickup placement in levels (Mission & Level Scripting), healing math (Player Character's `apply_heal`), AI patrol state serialization (Stealth AI's portion of `SaveGame`), or the takedown blade's damage number (locked at `blade_takedown_damage = 100` in the registry). Pillar fit: Pillar 2 is primary — the anti-farm invariants (dart-KO net-0, fist-KO net-negative) and pickup caches make observation pay more than aggression; Pillar 3 is served by non-lethal gadget choices that preserve alert-state reversibility; Pillar 5 is served by the slot-1..5 + scroll binding model — no modern radial weapon wheel, no hold-to-scavenge loot prompt, no quick-slot paint-the-button paternalism.

## Player Fantasy

**"The Pre-Packed Bag."** Eve Sterling does not scavenge her identity. Before the wheels of the BOAC Super VC10 touched down at Le Bourget, the Bureau of Queen's Affairs had issued her a kit — four weapons, a small roster of field-devices, a medkit — and she had chosen what to carry. The inventory screen is not a menu. It is a glance into a handbag she packed herself. Every gadget in that bag was requisitioned, signed for, and briefed on in a memo she only half-read. When she produces the fountain-pen lockpick at the Ritz or the compact-mirror at a blind corner, the fantasy is not her improvisation — it is the institution's foresight. Someone at BQA predicted this exact problem two months ago, typed a memo in triplicate, and filed the carbon. Eve is the agent. The Bureau is the author. Her hands, by now, already know where everything is.

This is the **Pillar-5 register of Player Character (Section B) translated into object form.** Eve does not grind for tools; she arrives with them. She does not panic-swap; her thumb already knows the slots. She does not quip when producing the cigarette-case listening device; the requisition memo did the quipping for her, two months ago, at a desk in Thames House.

### Felt moments (anchor vignettes)

Three micro-scenes, in the register the system should serve:

1. **The Crouched Swap.** Second platform, 1122. A PHANTOM technician rounds the elevator shaft sooner than expected. Eve is crouched behind a service trolley. Her thumb slides `2 → 1` — dart gun to silenced pistol — without looking at the HUD. One soft shot. Her thumb slides back to `2`. The technician hasn't finished falling when she is already watching the next corner. *The swap itself is the fantasy: friction-free, diegetic, already-decided.*
2. **The Handbag Check.** Safehouse prologue, Rue de Rivoli, 0547. Eve opens her clutch on the dresser before leaving for the Tower. Four weapons, **two BQA-issued gadgets carefully chosen for Paris**, a medkit slot awaiting a field kit. No progression tree, no empty slots awaiting grind. The pre-packed bag says: *this is who you are today, and it is enough.* The fantasy of completeness at the starting line — completeness is **what BQA deemed sufficient**, not what the player can accumulate. The third gadget (Parfum) is a mission-authored dead-drop discovery, not a starting kit entry: it belongs to the Bureau's *field intelligence*, not her morning packing.
3. **The Pickup That Isn't Greedy.** Eve passes a dead PHANTOM guard on the restaurant gangway. Three pistol rounds on the body. She keeps walking. Three rooms later she is out, and she remembers the cache — doubles back with the discipline of someone who *plans her ammunition*, not someone who hoovers every surface. The fantasy is the professional who takes what she needs and leaves the rest.

### Gadget roster philosophy (design test)

Every gadget in Eve's kit must earn **two seats**: a **field-utility seat** and a **period-absurdity seat**. A gadget that only *does a useful thing* is a modern immersive-sim tool (a lockpick, a mirror-on-stick) — fine, but not distinctly this game. A gadget that is *only a comedy object* (a robotic poodle, a joy-buzzer) is a gag that interrupts Composed Removal (Combat §Player Fantasy). The NOLF1 lesson is that the best gadgets are **clinical utility in an absurd disguise** — the lipstick-that-is-actually-a-detonator works because the memo describes it with a straight face. The comedy is that the Bureau issued it; the utility is that it works.

**Design test** — applied to every candidate gadget in §Detailed Design:

> *If the BQA requisition memo describing this gadget would make a bureaucrat giggle, but the gadget's in-field effect would make a tactician nod, the gadget fits.*

Lean toward utility-with-disguise; avoid pure gags. A gadget that fails the tactician nod is comedy furniture (belongs in a document or a set dressing, not the inventory). A gadget that fails the bureaucrat giggle is a modern-shooter tool (belongs in Deus Ex, not this game).

### Pillar alignment

- **Pillar 2 (Discovery Rewards Patience)** — load-bearing. The pre-packed bag sets the *ceiling* of Eve's capability at mission start; the only way to extend capability during the mission is **observation** (finding caches Mission Scripting has placed off-path) and **restraint** (the anti-farm economy — dart-KO nets 0 darts, fist-KO nets 0 darts, pistol-kill nets –1 round after reload overhead — so aggressive play depletes, patient play sustains). The gadget roster is fixed; the ammo supply rewards the patient observer. See §F.6 for the economy treatment.
- **Pillar 3 (Stealth is Theatre, Not Punishment)** — supporting. Non-lethal gadgets (dart gun, chloroform-style devices if chosen, anything that opens a non-violent solution) preserve alert-state reversibility. Every gadget in the roster should at minimum *not foreclose* stealth — a gadget whose only use is combat escalation (grenade, shotgun-disguised-as-umbrella) would belong to Combat, not here. The medkit specifically is a Pillar-3 instrument: it is the *material permission* for the game to let you survive a shootout and still stealth the next room.
- **Pillar 5 (Period Authenticity Over Modernization)** — load-bearing. No radial weapon wheel, no time-dilation menu, no hold-to-scavenge prompt, no quick-slot paint-the-button paternalism. The inventory verbs are **slots 1..5** (direct-select) and **scroll-cycle** (`weapon_next/prev`) — NOLF1's binding grammar, unaltered. Gadget activation is `use_gadget` (one button, immediate effect); gadget rotation is `gadget_next/prev` — no submenu, no selection dwell time. When the player opens the inventory screen for details, they see a **pre-packed handbag**, not a loot grid.
- **Pillar 1 (Comedy Without Punchlines)** — supporting via requisition-memo voice. Every gadget and weapon has a **description field** in its Resource schema; those descriptions are written in dry BQA clerical register — "KL/112/A: silver fountain pen, covert tumbler utility. Approved for Paris operations pending further review." — and the humor is the gap between that register and the object it describes. Eve herself never quips when producing or using a gadget; her hands are the Bureau's. The comedy is typographic, not verbal.

### Tonal touchstones

- *No One Lives Forever* 1 (2000) — primary. BQA's kit is modelled on UNITY's Santa gadget (a cigarette lighter that is also a laser); the requisition-memo voice is the NOLF1 briefing-scene register transposed into tooltip form.
- James Bond's Q-branch (Sean Connery era, not Roger Moore) — the clinical delivery of absurd objects. Q does not giggle. Neither does the BQA.
- Saul Bass title design — restraint as style. The inventory screen should look more like a contents-of-handbag title card than a modern loot grid.
- *Get Smart* (1965 TV) — the one cautionary reference. The shoe-phone is *too much* gag, not enough utility. Our floor is higher: every gadget must pass the tactician nod.

### Design test — does this inventory feature serve the fantasy?

Same test-pattern as Combat §Player Fantasy: does this change **Eve's register**, or **the world's around her**?

| Candidate feature | Register changed | Verdict |
|---|---|---|
| Radial weapon wheel with time-dilation | Eve's (she pauses the world to deliberate) | **Cut** |
| Slot-1..5 stable bindings for full mission | World's (the kit has a fixed shape; Eve has not) | **Keep** |
| Gadget unlock via XP / progression tree | Eve's (she grows into competence mid-mission) | **Cut** |
| Pre-packed starting inventory at mission open | World's (BQA has packed the bag) | **Keep** |
| "Handy!" quip on pickup | Eve's (protagonist narrates herself) | **Cut** |
| BQA memo tooltip on gadget description | World's (typography carries the humor) | **Keep** |
| Auto-pickup hoover (walk-over collects) | Eve's (player is a magnet, no decision) | **Cut** |
| Priority-2 `interact` raycast pickup (deliberate) | World's (the player chooses what to pocket) | **Keep** |
| Weapon-drop particle burst + sparkle VFX | Eve's (the world is rewarding her for kills) | **Cut** |
| Discreet mesh-plus-outline for dropped weapons | World's (the item is a period object on the floor) | **Keep** |

**Scope of the Design Test** (inherited from Combat): governs **diegetic period fiction**. Accessibility scaffolding (high-contrast inventory text, larger pickup prompts, colorblind-safe ammo bar) is NOT in this test's domain — those are player-accommodation affordances, decided on accessibility grounds by Settings & Accessibility, not diegetic grounds.

## Detailed Design

Inventory & Gadgets is a **component on Player Character** (`class_name InventorySystem extends Node`, child of `PlayerCharacter` scene). It holds the authoritative state of Eve's carried items — equipped weapon, per-weapon ammo (magazine + reserve), equipped gadget, gadget-rotation index, mission-pickup availability flag, medkit count — and it owns the code paths that read `fire_primary`, drive weapon-switch animation timing, route the PC's priority-2 `interact` resolution into pocket logic, and emit the four frozen Inventory-domain signals from ADR-0002 plus the `weapon_fired` emit-site. Combat reads Weapon Resource fields per fire but does NOT hold them; the data layer is Inventory's. Per architecture.md §3.3 and ADR-0002: ammo state, reload state, fire-rate gating, weapon-switch state, and gadget cooldown state (trivially empty — see §C.1 CR-5b) all live here. Damage math, projectile spawn, alert-state transitions, HUD rendering, and pickup placement all live elsewhere.

### C.1 Core Rules

Numbered. A programmer must be able to implement each without questions.

**CR-1 Weapon-slot grammar (direct slot select).** Slot mapping is fixed for the entire mission:

| Slot | Binding | Weapon | Ammo |
|---|---|---|---|
| 1 | `weapon_slot_1` | Silenced pistol | magazine 8 / reserve 32 start / cap 48 |
| 2 | `weapon_slot_2` | Dart gun | magazine 4 / reserve 16 start / cap 24 |
| 3 | `weapon_slot_3` | Rifle (pickup-only) | magazine 3 / reserve 0 start / per-pickup +6 / cap 12 |
| 4 | `weapon_slot_4` | Takedown blade | no ammo (context-gated via `SAI.takedown_prompt_active()`) |
| 5 | `weapon_slot_5` | Fists | no ammo (innate, always available) |

Direct-select behavior:

- `weapon_slot_N` where `N == current_weapon_slot`: **silent reject** (no animation, no audio, no state change).
- `weapon_slot_3` when rifle has NOT been picked up (`mission_pickup_rifle_acquired == false`): **silent reject with dry-click cue** (Audio owns the 1-click SFX; no reload-style audio, no pop-up). The slot is addressable but the item is absent; a silent-silent reject reads as a broken binding, so the dry click signals "slot empty" without breaking Composed Removal.
- `weapon_slot_4` always resolves to blade-equipped state regardless of `SAI.takedown_prompt_active()`. Selection is not context-gated; **activation is** (CR-16 silent-reject-on-fire; Combat's Takedown input is the only activation path).
- `weapon_slot_N` during `RELOADING`: **interrupts reload immediately** (Combat CR-17 invariant — weapon-switch cancels reload), then enters `SWITCHING` state per CR-3. Partial reload is lost; magazine retains pre-reload count.
- `weapon_slot_N` during `SWITCHING` (mid-swap): **silent reject** — switch is not cancellable once started (Combat CR-16 invariant).
- `weapon_slot_N` while `player.is_hand_busy() == true`: **silent reject** (PC owns the hand; Inventory polls this gate).

**CR-2 Weapon-scroll cycle (`weapon_next` / `weapon_prev`).** Scroll iterates the 5 slots in order (1→2→3→4→5→wrap to 1; reverse for `prev`).

- Scroll **skips empty slots**. If rifle has not been picked up, scroll cycles 1→2→4→5→1, etc. Direct-select still attempts and dry-clicks per CR-1.
- Slot 4 (blade) is NOT skipped during scroll even when no Takedown prompt is active. The blade is always "held"; its context gate is at activation (Combat Takedown input), not at selection.
- Slot 5 (fists) is always in the cycle (innate).
- Scroll wraps (next from 5 → 1; prev from 1 → 5).
- Scroll during `RELOADING`: behaves as direct-select (interrupts reload, enters `SWITCHING`).
- Scroll during `SWITCHING` or `is_hand_busy()`: **silent reject**.

**CR-3 Weapon-switch animation timing.** Swap duration is **0.35 s** (Combat CR-16 locked value — holster-draw blend).

- SWITCHING is **not cancellable** once started — fire, reload, and second weapon-select inputs during SWITCHING are silently rejected.
- Damage during SWITCHING does **NOT** cancel the swap (Combat CR-16 explicit invariant — the swap is a Composed Removal beat, not an interruptible UI action).
- `weapon_fired` does **NOT** emit during SWITCHING; `fire_primary` presses during SWITCHING are silently dropped.
- **Held-mesh swap point**: previous mesh is hidden at `t = 0.175 s`, new mesh is shown at `t = 0.175 s` — the HandAnchor re-parent executes at the holster nadir (midpoint). Implementation pattern: instantiate the new weapon's `mesh: PackedScene`, `player.HandAnchor.add_child(new_instance)`, `previous_instance.queue_free()` at `t = 0.175 s`.
- `weapon_switched(new_weapon_id)` signal emits at `t = 0.35 s` (state transition to IDLE).

**CR-4 Gadget activation (`use_gadget` via Combat's single-dispatch handler).** The `use_gadget` input shares its binding (F / JOY_BUTTON_Y) with `takedown` per Input GDD L90–91. To avoid same-frame double-fire across two independent `_unhandled_input` handlers, activation uses a **single dispatch point in Combat's input handler**:

```gdscript
# In CombatSystemNode._unhandled_input — the authoritative dispatcher.
if event.is_action_pressed(InputActions.TAKEDOWN_OR_GADGET):
    if SAI.takedown_prompt_active():
        _execute_takedown()
    else:
        InventorySystem.try_use_gadget()  # direct method call (Inventory is a known PC child)
    get_viewport().set_input_as_handled()
```

Rationale: `takedown` and `use_gadget` share one action name at the input layer; Combat owns the takedown path (authoritative for lethal damage routing), so Combat's handler runs and dispatches to the correct side. Inventory does NOT subscribe to `use_gadget` directly — it exposes `try_use_gadget()` as a public method. This closes the double-fire risk flagged in godot feasibility review (Q4, 2026-04-23).

**CR-4b Gadget activation behavior inside `try_use_gadget()`.** On call:

1. Read equipped gadget Resource from `_equipped_gadget`.
2. Evaluate the gadget's **contextual gate** (per-gadget, defined in §C.2). If gate returns `false`:
   - **Silent reject with affordance cue**: gamepad haptic pulse (50 ms, low intensity) AND HUD gadget icon desaturates for 0.2 s (HUD Core subscribes to `gadget_activation_rejected` — NEW signal, candidate for ADR-0002 amendment; see §F Dependencies "Coordination items"). No audio (to avoid breaking stealth with a diegetic noise during a failed activation).
   - Return.
3. If gate returns `true`: execute gadget effect (per-gadget; see §C.2), emit `gadget_used(gadget_id, player.global_position)`.
4. If `_equipped_gadget` is null (transitional state during mid-rotation): **silent reject, no cue**.

**CR-5 Gadget rotation (`gadget_next` / `gadget_prev`).** The gadget cycle contains exactly the gadgets currently in inventory: 2 starting + optional 1 mission-pickup = **max 3**. There is always exactly one gadget equipped; no "empty" gadget state at mission start (since both pre-packed gadgets are in the clutch from `_ready()`).

- Cycle order: **Compact (idx 0, default) → Cigarette Case (idx 1) → Parfum (idx 2, added mid-mission)**. `gadget_next` wraps; `gadget_prev` is inverse.
- On rotation: emit `gadget_equipped(new_gadget_id)`.
- `gadget_next/prev` is **NOT gated** by `SWITCHING`, `RELOADING`, or `is_hand_busy()`. Gadget selection involves no HandAnchor mesh attachment at MVP — gadgets have no persistent held mesh; the mesh (if any) spawns only during activation (e.g., the Compact's fiber-optic viewfinder camera pose is transient, 10 s). Rotation itself is pure data + HUD-icon update.
- Rotation during `PICKUP_IN_PROGRESS`: allowed (pickup is a single-frame state).
- Post-mission-pickup: when Parfum is collected (CR-13), it appends to the cycle. Currently-equipped gadget is unchanged; `gadget_next` from Cigarette Case now reaches Parfum instead of wrapping to Compact.

**CR-5b Gadget cooldown model.** Per user decision 2026-04-23: **no cooldowns, no charges**. The Gadget Resource schema has no `cooldown_sec` field and no `charges_remaining` field. Gadget activation is gated purely by the per-gadget contextual gate (CR-4b step 2). `gadget_used` can fire unlimited times per mission — repeated activation with no gate failure is permitted by the economy. Pillar-2 scarcity lever is ammo, not gadgets.

**CR-6 Pickup rule (Priority-2 `interact`).** Inventory **subscribes to `Events.player_interacted(target: Node3D)`** (PC-emitted, ADR-0002-frozen Player-domain signal). When the signal fires:

1. Inventory checks `target is WorldItem` — if false, return (Document Collection or another subscriber handles it).
2. Inventory reads `world_item.item_id: StringName` and `world_item.quantity: int` (and for the mission gadget, `world_item.gadget_resource: GadgetResource`).
3. Inventory updates state per item type (CR-7..CR-9).
4. Inventory calls `world_item.queue_free()`.
5. **Key contract**: Inventory does NOT poll PC for raycast state; PC owns the raycast and emits `player_interacted` after priority resolution. This preserves the layer-dependency rule (PC is Core layer; Inventory is Feature layer; Feature subscribes to Core signals, does not poll Core data).

Implementation correction from godot feasibility review (Q5, 2026-04-23): any direct `PlayerCharacter.pocket_item(WorldItem)` method call would be a **downward call from Core to Feature layer** and is forbidden. Route always via the signal.

**CR-7 WorldItem drop on guard incapacitation / death.** Inventory subscribes to two signals for drop spawning:

| Signal | Fired by | Inventory action |
|---|---|---|
| `Events.enemy_killed(guard: Node, killer: Node)` | Combat — only on `is_dead = true` (BULLET, MELEE_BLADE, FALL_OUT_OF_BOUNDS per Combat `is_lethal_damage_type()`) | Spawn WorldItem per CR-7a drop table (uses `guard._last_damage_type`) |
| `Events.guard_incapacitated(guard: Node, cause: int)` **(signature extended 2026-04-24 — `cause: Combat.DamageType`)** | Stealth AI — only on UNCONSCIOUS transition (MELEE_NONLETHAL chloroform + DART_TRANQUILISER + MELEE_FIST at 0 HP) | Spawn WorldItem per CR-7a drop table (uses `cause` to distinguish dart/fist/Parfum) |

Rationale for the two-signal subscription: dart-KO, fist-KO, and Parfum-KO transition guards to UNCONSCIOUS, not DEAD; `enemy_killed` does NOT fire for these paths. SAI's `guard_incapacitated` signal (added 2026-04-22 per SAI GDD 3rd-pass revision; signature extended 2026-04-24 to include `cause: int` — ADR-0002 amendment item) fires on the UNCONSCIOUS transition and carries the damage-type cause so Inventory can distinguish KO origin without reading internal guard fields. Subscribing to both signals keeps the code branching clean without filtering.

**`guard_incapacitated` signature extension** (Coordination item #2 — REVISED 2026-04-24): ADR-0002 amendment must extend signal signature from `guard_incapacitated(guard: Node)` to `guard_incapacitated(guard: Node, cause: int)` where `cause` is a `Combat.DamageType` enum value: `DART_TRANQUILISER`, `MELEE_FIST`, or a new `MELEE_PARFUM` value (NEW — must be added to Combat.DamageType enum as part of the amendment bundle). SAI's `receive_damage` path stores the cause and passes it when emitting `guard_incapacitated`. The Parfum behavior scene calls `SAI.receive_damage(guard, 0, eve, DamageType.MELEE_PARFUM)` instead of the previous `DART_TRANQUILISER` — the terminal UNCONSCIOUS routing is identical (SAI's `is_lethal_damage_type(MELEE_PARFUM) == false`), only the cause propagation changes. This requires a paired Combat.DamageType enum addition.

**CR-7a Drop table** (locked — all values are registry-canonical; do NOT contradict):

| Kill / KO cause (from `guard._last_damage_type`) | Weapon guard carried | WorldItem spawned |
|---|---|---|
| BULLET or MELEE_BLADE (lethal) | `silenced_pistol` | WorldItem(item_id=`"pistol_ammo"`, quantity=`guard_drop_pistol_rounds = 3`) |
| BULLET or MELEE_BLADE (lethal) | `rifle` | WorldItem(item_id=`"rifle_ammo"`, quantity=`guard_drop_rifle_rounds = 3`) |
| BULLET or MELEE_BLADE (lethal) | `none` / unarmed | No WorldItem |
| DART_TRANQUILISER (UNCONSCIOUS) | Any | WorldItem(item_id=`"dart_ammo"`, quantity=`guard_drop_dart_on_dart_ko = 1`) |
| MELEE_FIST (UNCONSCIOUS) | Any | **No WorldItem** (`guard_drop_dart_on_fist_ko = 0` — anti-farm invariant, LOCKED {0}) |
| MELEE_PARFUM (UNCONSCIOUS) **— NEW 2026-04-24, OQ-INV-1 Option B** | Any | **No WorldItem** (`guard_drop_dart_on_parfum_ko = 0` — anti-farm invariant, LOCKED {0}; mirrors fist-KO policy). Preserves dart break-even. |
| FALL_OUT_OF_BOUNDS | Any | No WorldItem (no drop on environmental deaths — guard position is invalid at drop time) |

**CR-7b Multi-drop positional offset (REVISED 2026-04-24 — fixes [systems-designer BLOCK-1, BLOCK-4]).** If two or more WorldItems spawn within the same physics tick at positions within 0.5 m of each other, apply a deterministic radial offset. **Critical: offset is ONLY applied when `guard_index > 0`** — the first drop in a tick (`i=0`) spawns at the guard's unmodified world position. Prior drafts incremented the counter unconditionally, which produced a `(0.4, 0, 0)` east offset even on single-drop cases — a guard dying near an east wall would drop ammo INTO the wall.

```gdscript
# In the drop-spawn coroutine (subscribers to enemy_killed + guard_incapacitated):
var drop_position: Vector3 = guard.global_position
if _drop_index_this_tick > 0:
    drop_position += Vector3(
        cos(_drop_index_this_tick * 2.3), 0, sin(_drop_index_this_tick * 2.3)
    ) * 0.4
_drop_index_this_tick += 1
```

Counter reset boundary: `_drop_index_this_tick` is reset to `0` at the start of EVERY `_physics_process` frame (NOT `_process`). `enemy_killed` and `guard_incapacitated` fire from Combat and SAI synchronous paths that run inside `_physics_process`. A `_process` reset boundary would not align with physics-tick signal emission. Implementation:

```gdscript
func _physics_process(_delta: float) -> void:
    _drop_index_this_tick = 0
```

Prevents z-fighting on ≥2 same-tick drops and ensures each WorldItem is individually addressable by PC's priority-2 raycast. Single-drop case is unmodified (drop at guard position). Max realistic N in same tick ≈ 6 (5-guard room + 1 cache scripted release).

**CR-8 Pickup cap clamp.** On `pocket_item` for ammo pickups:

`new_reserve = min(current_reserve + quantity, max_reserve_cap)`

Excess rounds are silently lost (excess = quantity carried beyond cap). `world_item.queue_free()` fires regardless of how many rounds were absorbed — the player cannot "decline" a partial pickup. `ammo_changed(weapon_id, current_magazine, new_reserve)` emits with the post-clamp value.

Cap values (registry-locked except rifle):

| Weapon | `max_reserve_cap` | Source |
|---|---|---|
| Silenced pistol | 48 | `pistol_max_reserve` (registry, locked) |
| Dart gun | 24 | `dart_max_reserve` (registry, locked) |
| Rifle | **12** | `rifle_max_reserve` — **NEW registry candidate** (owned by this GDD). Derivation: 4× magazine (consistent with pistol/dart ratio), but ammo-type is pickup-only so the cap doubles as a Pillar-2 anti-hoard lever. Safe range [9, 18]. |

**CR-9 Medkit consumption.** Medkit is a **WorldItem pickup**, NOT a gadget. On `player_interacted` where `target.item_id == "medkit"`:

1. Inventory calls `player.apply_heal(medkit_heal_amount: float, self)`.
2. `apply_heal` rejects non-positive amounts (PC API invariant — do NOT pass negative or zero).
3. `world_item.queue_free()` fires after heal call returns.
4. **No `ammo_changed` emit** (medkits do not affect ammo state). HUD health readout updates via PC's `player_health_changed` signal (PC's `apply_heal` emits).
5. Medkit does NOT occupy a gadget slot or weapon slot. It is pickup-consumed-immediately; the player never "holds" a medkit.
6. `medkit_heal_amount` is a tuning knob (see §G). Default proposed: **40 HP**. Rationale: the registry's `health_hp = 100` + Combat's `guard_pistol_damage_vs_eve = 18` means 40 HP is 2.2 guard-shots of healing — meaningful but not a full reset. Safe range [25, 60].

**CR-10 Held-item mesh attachment (REVISED 2026-04-24 — fixes [gameplay-programmer Issue 5] double-stencil-write concern).** On `weapon_switched` signal emit (the weapon-side path; gadgets have no persistent held-mesh at MVP):

1. If previous mesh instance is parented to `player.HandAnchor`:
   - **Step 1a**: `previous_mesh.hide()` **synchronously** — this disables rendering immediately in the same frame, preventing the outline pipeline from writing both meshes' Tier-1 stencils during the `queue_free`-defer window.
   - **Step 1b**: `player.HandAnchor.remove_child(previous_mesh)` **synchronously** — removes the node from scene tree, so VisualInstance3D is detached before the new child is added.
   - **Step 1c**: `previous_mesh.queue_free()` — deferred free happens end-of-frame; node is already orphaned and invisible, so any lingering reference is safe. (Pooling is NOT adopted at MVP — scale is ≤6 weapon scenes; profile-driven optimization, not premature.)
2. Instantiate new weapon's `mesh: PackedScene` (field on `WeaponResource`): `new_instance = weapon.mesh.instantiate()`.
3. `player.HandAnchor.add_child(new_instance)`. Local transform is inherited from HandAnchor; no manual positioning.
4. For weapons with two-handed IK poses (rifle): set `player.LeftHandIK.target` and `player.RightHandIK.target` to `Marker3D` nodes defined inside the weapon's PackedScene, referenced by name via `WeaponResource.hand_pose_marker_name: StringName`. **VERIFY-AT-IMPL BLOCKER (flagged 2026-04-24 by [godot-specialist B-2]):** `SkeletonModifier3D` IK is post-cutoff (Godot 4.5+). HandAnchor is a child of Camera3D (per PC GDD L67), while the player body's Skeleton3D (where IK modifiers live) is in a different scene subtree. Whether a SkeletonModifier3D can resolve a target NodePath that crosses the Camera/body subtree boundary needs **explicit engine-reference verification before the rifle IK story can be written.** If unsupported, fallback options: (a) world-space target propagation via manual `Transform3D` update each frame (performance cost — evaluate against ADR-0008 budget); (b) scope rifle IK out of MVP and accept a static rifle hold pose. Coordination item #8 (NEW) — owner: godot-specialist + technical-director, target: Technical Setup phase.
5. Outline tier for held weapon mesh: **Tier 1 (Heaviest, 4 px)** per ADR-0001 canonical table — weapons and gadgets are in Eve's on-screen possession and must read against any interior backdrop.

**CR-11 Save / restore.** Inventory owns an `InventoryState extends Resource` Resource (ADR-0003 contract):

```gdscript
class_name InventoryState
extends Resource

@export var current_weapon_id: StringName = &"silenced_pistol"
@export var equipped_gadget_id: StringName = &"gadget_compact"
@export var mission_pickup_available: bool = false
@export var mission_pickup_rifle_acquired: bool = false
@export var medkit_count: int = 0  # reserved — MVP is immediate-consume, but field supports a future carry-medkits mode
@export var ammo_magazine: Dictionary = {}  ## StringName -> int (weapon_id -> rounds currently in magazine)
@export var ammo_reserve: Dictionary = {}   ## StringName -> int (weapon_id -> rounds in reserve)
```

Implementation correction from godot feasibility review (Q7, 2026-04-23): use **untyped `Dictionary`** with `## StringName -> int` doc comment, NOT `TypedDictionary[StringName, int]`. `TypedDictionary` serialization stability with `ResourceSaver` is unverified post-cutoff (Godot 4.4+); the safe ADR-0003-compliant choice is untyped `Dictionary`. Flag as VERIFY-AT-IMPL upgrade candidate for Technical Setup.

**Save/restore pattern (REVISED 2026-04-24 — resolves cross-GDD ownership confusion flagged by [gameplay-programmer Issue 2], [systems-designer BLOCK-3], [godot-specialist B-1]).**

Inventory uses TWO distinct restore paths plus ONE serialize path, each with a clearly-owned entry point:

1. **Section-load restore path (LS-owned)** — Inventory calls `LevelStreamingService.register_restore_callback(_on_restore_from_save)` in `_ready()`. (`register_restore_callback` is owned by **Level Streaming**, NOT `SaveLoad` — confirmed against LS CR-2. Prior drafts misattributed owner to `SaveLoad`.) The callback is invoked at LS step 9 of the 13-step swap sequence. Signature matches LS CR-2:

   ```gdscript
   func _on_restore_from_save(target_section_id: StringName, save_game: SaveGame, reason: LevelStreamingService.TransitionReason) -> void:
       # save_game.inventory_state is an InventoryState Resource (ADR-0003 payload).
       var snap: InventoryState = save_game.inventory_state
       current_weapon_id = snap.current_weapon_id
       equipped_gadget_id = snap.equipped_gadget_id
       mission_pickup_available = snap.mission_pickup_available
       mission_pickup_rifle_acquired = snap.mission_pickup_rifle_acquired
       medkit_count = snap.medkit_count
       ammo_magazine = snap.ammo_magazine.duplicate(true)  # ADR-0003 deep-copy
       ammo_reserve = snap.ammo_reserve.duplicate(true)
       # Rebuild _gadget_cycle deterministically from mission_pickup_available flag:
       _gadget_cycle = [&"gadget_compact", &"gadget_cigarette_case"]
       if mission_pickup_available:
           _gadget_cycle.append(&"gadget_parfum")
       Events.gadget_equipped.emit(equipped_gadget_id)  # HUD re-sync
   ```

   This path runs on FORWARD, LOAD_FROM_SAVE, and NEW_GAME TransitionReasons. RESPAWN uses the Failure & Respawn-owned path below instead.

2. **Respawn restore path (F&R-owned, uses floor)** — Failure & Respawn calls `InventorySystem.restore_weapon_ammo(snapshot: InventoryState, floor: Dictionary, max_cap: Dictionary) -> void` after LS step 9 (F&R-specific post-restore hook; see Failure & Respawn forward contract below). This path is distinct from path 1 because RESPAWN applies the ammo floor F.2; FORWARD/LOAD_FROM_SAVE does not.

3. **Serialize path (Mission Scripting-owned caller; Inventory provides)** — Inventory exposes `serialize_to(save_game: SaveGame) -> void` as a public method. Mission & Level Scripting (the save payload assembler per `save-load.md` Overview §3) calls it from its `section_entered` autosave handler (Save/Load CR-3). `serialize_to` writes `save_game.inventory_state = _to_inventory_state()` where `_to_inventory_state()` constructs a new `InventoryState` Resource from the live Inventory fields. Naming convention: `serialize_to` is the WRITE path; `_on_restore_from_save` is the READ path. The method names are now unambiguous in direction.

**Schema alignment with save-load.md.** `save-load.md` line 102 previously described `ammo: Dictionary[StringName, int]` (single dict). The correct schema — matching CR-11's `InventoryState` two-dict split (`ammo_magazine` + `ammo_reserve`) — is a **`save-load.md` touch-up Coordination item** (see §F). Both dicts are required because magazine count and reserve count are distinct game-state fields with different semantics (magazine is "currently chambered rounds between reloads"; reserve is "rounds carried"). Flattening to one dict loses the mid-reload partial-magazine state.

**No `Events.section_exited` subscription.** Inventory does NOT subscribe to `Events.section_exited` directly. The LS-registered callback (path 1) is the sole restore entry for section loads; the F&R call (path 2) is the sole restore entry for respawns; the Mission-Scripting-called `serialize_to` (path 3) is the sole serialize entry. Avoids "PC freed mid-swap before signal fires" race.

**Respawn floor application** (Failure & Respawn forward contract — per Combat §F.6):

On respawn restore, Failure & Respawn calls `InventorySystem.restore_weapon_ammo(snapshot: InventoryState, floor: Dictionary, max_cap: Dictionary) -> void`. Inventory implements:

```gdscript
func restore_weapon_ammo(snapshot: InventoryState, floor: Dictionary, max_cap: Dictionary) -> void:
    for weapon_id in snapshot.ammo_reserve.keys():
        # Defensive clamp against corrupt save values (REVISED 2026-04-24 per [systems-designer REC-4]):
        # negative magazine or reserve from a corrupt .save file would propagate through max()/min()
        # and produce nonsensical positive totals. Clamp each term to >= 0 BEFORE summation.
        var mag_val: int = max(0, snapshot.ammo_magazine.get(weapon_id, 0))
        var res_val: int = max(0, snapshot.ammo_reserve.get(weapon_id, 0))
        if snapshot.ammo_magazine.get(weapon_id, 0) < 0 or snapshot.ammo_reserve.get(weapon_id, 0) < 0:
            push_warning("Inventory.restore_weapon_ammo: corrupt save — negative ammo for %s, clamped to 0" % weapon_id)
        var snapshot_total: int = mag_val + res_val
        var target_total: int = max(snapshot_total, floor.get(weapon_id, 0))
        target_total = min(target_total, max_cap.get(weapon_id, target_total))
        # Redistribute: fill magazine first, overflow to reserve.
        var mag_size: int = _weapons[weapon_id].magazine_size
        ammo_magazine[weapon_id] = min(target_total, mag_size)
        ammo_reserve[weapon_id] = target_total - ammo_magazine[weapon_id]
```

Floor values (Combat GDD §F.6): `floor = { &"silenced_pistol": respawn_floor_pistol_total = 16, &"dart_gun": respawn_floor_dart_total = 8 }`. Rifle preserved at snapshot value unchanged. Floor applies ONLY on first death per checkpoint (`floor_applied_this_checkpoint: bool` flag owned by Failure & Respawn, not Inventory — Inventory calls `restore_weapon_ammo` blindly with the floor dict the F&R system hands in; F&R replaces floor with empty dict on subsequent deaths per checkpoint).

**CR-12 Starting-inventory sequence.** On `_ready()`, Inventory initializes with:

| Field | Initial value |
|---|---|
| `current_weapon_id` | `&"silenced_pistol"` (Slot 1) |
| `equipped_gadget_id` | `&"gadget_compact"` (default gadget index 0) |
| `ammo_magazine[&"silenced_pistol"]` | 8 (full) |
| `ammo_magazine[&"dart_gun"]` | 4 (full) |
| `ammo_magazine[&"rifle"]` | 0 (not picked up) |
| `ammo_reserve[&"silenced_pistol"]` | 32 |
| `ammo_reserve[&"dart_gun"]` | 16 |
| `ammo_reserve[&"rifle"]` | 0 |
| `mission_pickup_available` | false (Parfum not acquired) |
| `mission_pickup_rifle_acquired` | false |
| `medkit_count` | 0 |
| `_gadget_cycle[]` | `[&"gadget_compact", &"gadget_cigarette_case"]` (Parfum appended on CR-13 pickup) |

**CR-13 Mission-pickup gadget acquisition.** Mission Scripting places one `WorldItem` (`item_id = "gadget_mission_pickup"`, `gadget_resource: GadgetResource` referencing the Parfum Resource) in the Tier 1 Eiffel Tower restaurant section (specific room authored by Mission Scripting). On pickup (priority-2 `player_interacted`):

1. `pocket_item` detects `item_id == "gadget_mission_pickup"`.
2. `_gadget_cycle.append(world_item.gadget_resource.gadget_id)` — cycle grows 2 → 3 entries.
3. Set `mission_pickup_available = true`.
4. Emit `gadget_equipped(_equipped_gadget_id)` (with current, NOT newly-added gadget id) — notifies HUD that cycle has grown so HUD can re-draw the rotation indicator. (If HUD needs a separate `gadget_roster_extended` signal, that's a Coordination item — see §F.)
5. `world_item.queue_free()`.
6. `gadget_next` from Cigarette Case now reaches Parfum instead of wrapping.

**CR-14 Fire-input pipeline.** Per architecture.md §3.3 and godot feasibility review (Q3, 2026-04-23), Inventory **catches `fire_primary` input in its own `_unhandled_input`** (Combat is a pure damage-routing hub; ammo / reload / fire-rate gating is Inventory's):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(InputActions.FIRE_PRIMARY):
        if not _can_fire():  # ammo > 0, not reloading, not switching, not hand-busy, fire-rate timer elapsed
            if _current_weapon_ammo_magazine() == 0:
                _emit_dry_fire_click()  # Audio-owned SFX signal (not weapon_fired)
            return
        if _current_weapon_id == &"takedown_blade":
            # CR-16: blade + fire = silent reject, no feedback. Composed Removal.
            return
        _decrement_magazine()
        _reset_fire_cadence_timer()
        Events.weapon_fired.emit(_current_weapon_resource, _get_muzzle_position(), _get_muzzle_direction())
        Combat.apply_fire_path(_current_weapon_resource, _get_muzzle_position(), _get_muzzle_direction())
        Events.ammo_changed.emit(_current_weapon_id, _current_weapon_ammo_magazine(), _current_weapon_ammo_reserve())
        get_viewport().set_input_as_handled()
```

The split per ADR-0002 and architecture.md: **Inventory owns "when and whether to fire"** (ammo / reload / fire-rate / switching gates + `weapon_fired` emit + `ammo_changed` emit + dry-fire click routing). **Combat owns "what happens when fire resolves"** (projectile spawn, hitscan, damage application, pre-fire occlusion check per Combat CR-6). `Combat.apply_fire_path(...)` is Combat's public entry.

**CR-15 Pistol-reserve-dry fallthrough (Combat OQ-CD-3 resolution, REVISED 2026-04-24).** Per user decision 2026-04-24 (supersedes 2026-04-23 "no auto-switch"): **auto-cycle past dry weapons on next fire_primary press**, matching NOLF1 baseline and preserving the Crouched Swap anchor vignette ("her thumb already knows"). When any weapon's magazine AND reserve both reach 0 and `fire_primary` is pressed:

1. First press on the dry weapon produces the dry-fire click SFX (Audio-owned `weapon_dry_fire_click` signal — NOT `weapon_fired`). This is the confirmation tick that "this gun is empty."
2. Concurrent with the click, Inventory auto-advances to the next **non-dry weapon in scroll order** (1→2→3→4→5 wrap), skipping any weapon with magazine==0 AND reserve==0 AND not rifle-unacquired. Fists (slot 5, innate, no ammo) and blade (slot 4, context-gated, no ammo) are always non-dry and catch the fallthrough.
3. The auto-switch enters `SWITCHING` state normally (0.35 s animation, CR-3 invariants). `weapon_switched` emits at t=0.35 s for the new weapon.
4. The triggering `fire_primary` press is CONSUMED by the dry-click + switch initiation. The player must press `fire_primary` again after the 0.35 s switch completes to fire the newly equipped weapon. Rationale: auto-fire-through would be too magical — the dry-click gives the player time to process the empty and react; the auto-switch gives them a ready tool when they do.
5. If ALL carried weapons are dry (pistol + dart + rifle all empty AND blade's context gate is inactive — edge case, extraordinarily unlikely given fists are always available), the player lands on fists. Fists are innate and always non-dry.

Rationale: Practiced Hands fantasy (§Player Fantasy "The Crouched Swap") describes a thumb that "already knows" — an auto-cycle preserves that register without interrupting Composed Removal for a UI-driven weapon-selection fumble. The system fluently hands Eve the next viable tool; she does not fumble at an empty chamber. This matches Combat E.8 routing "Inventory & Gadgets' concern" — this GDD resolves it as "auto-cycle past dry, one press of dry-click + switch consumed, second press fires new weapon."

**CR-16 Blade + Fire = dry-click cue (REVISED 2026-04-24).** Per user decision 2026-04-24 (supersedes 2026-04-23 "silent reject"): when takedown blade is equipped (Slot 4) and `fire_primary` is pressed, emit a **blade-specific dry-click cue** (short steel-on-leather tick, ~80 ms close-mic via `weapon_dry_fire_click(&"takedown_blade")` signal; Audio-owned). No HUD response, no haptic, no state change. The blade's activation path remains Combat's `takedown` input exclusively (dedicated Input action per Combat CR-3).

Rationale: preserves Composed Removal (Combat §Player Fantasy) — Eve does not actually fire the blade, and there is no "wrong tool" message — but the cue is consistent with the Rifle-empty and Pistol-empty feedback patterns (E.9 dry-click convention), so the player learns "this slot does something — just not that." Zero feedback reads as hardware glitch; a discreet mechanical tick reads as "the object acknowledges you." Aligned with [game-designer B-3] finding in the `/design-review` 2026-04-24 pass.

**CR-17 Forbidden patterns (grep-enforceable).** Grep targets for CI to fail-loud if any of these land in `src/gameplay/inventory/`:

| Rule | Grep pattern | Rationale |
|---|---|---|
| Inventory MUST NOT subscribe to `player_footstep` | `player_footstep` | FootstepComponent owns noise-accounting; Inventory has no reason to hear footsteps |
| Inventory MUST NOT write guard properties directly | `guard\.(ammo|health|alert_state|_last_damage_type) *=` | Read-only contract; Combat + SAI own guard state |
| Inventory MUST NOT emit `enemy_killed`, `enemy_damaged`, `player_damaged`, `player_health_changed`, `player_died` | `(enemy_killed|enemy_damaged|player_damaged|player_health_changed|player_died)\.emit` | Combat + PC own these emit-sites |
| Inventory MUST NOT call `Combat.apply_damage_to_actor` | `Combat\.apply_damage_to_actor` | Damage routing belongs to Combat; Inventory's fire path calls `Combat.apply_fire_path` instead |
| Inventory MUST NOT read `SAI.*` except `SAI.takedown_prompt_active()` | `SAI\.` excluding `SAI\.takedown_prompt_active` | SAI is encapsulated; Inventory's only SAI surface is the mutex check |
| Inventory MUST NOT write `player.health` directly | `player\.health *=` | PC owns health state; Inventory calls `apply_heal()` |
| Inventory MUST NOT use `NavigationServer3D.map_get_path` synchronously | `NavigationServer3D\.map_get_path` | ADR-0008 / SAI CR-boundary; no pathfinding in Inventory |
| Inventory MUST NOT use `call_deferred` in fire / pickup / swap paths | `call_deferred` within `_unhandled_input` handlers | Determinism: all weapon/pickup state mutations are synchronous-in-handler per Combat CR-14 precedent |

### C.2 Gadget Roster (3 gadgets MVP)

Each gadget is a `GadgetResource extends Resource` (`.tres`) with the shared schema below (CR-5b: no cooldown / charges fields). Per-gadget behavior is implemented via a dedicated gadget-behavior scene referenced by `GadgetResource.behavior_scene: PackedScene`. The Inventory `try_use_gadget()` method reads the Resource, instantiates the behavior scene (or calls into its pre-instantiated instance), evaluates the contextual gate, and executes the effect.

**Shared `GadgetResource` schema:**

```gdscript
class_name GadgetResource
extends Resource

@export var gadget_id: StringName
@export var display_name: String
@export var description: String   ## BQA requisition memo text, period-authentic clerical register
@export var mesh: PackedScene     ## Optional — only populated if gadget has a held-mesh at activation
@export var icon: Texture2D       ## HUD icon for gadget indicator (rendered by HUD Core)
@export var activation_sound: AudioStream  ## Audio-owned; Inventory emits gadget_used and Audio plays this
@export var behavior_scene: PackedScene    ## Per-gadget activation + contextual-gate implementation
```

**Gadget 1 — The Compact** (pre-packed #1, default equipped).

| Field | Value |
|---|---|
| `gadget_id` | `&"gadget_compact"` |
| `display_name` | "Compact, Covert Optical" |
| Cover identity | Women's powder compact, gunmetal finish with BQA-blue enamel inset on the lid |
| Utility | **Fiber-optic viewfinder.** On activation, camera shifts to a narrow keyhole view through the case's fiber-optic relay lens (visual: small rounded viewport overlay inside a larger vignette). Duration: up to 10 s. Canceled by any movement input (WASD / gamepad left stick) or by pressing `use_gadget` again. During the view, Eve is stationary but vulnerable (no invincibility — a guard could still hear her noise signature or spot her crouched body). AI state is fully visible in the viewfinder (guards, patrol direction, alert level — Eve sees what her head already sees from the HandAnchor perspective, just through the lens). |
| Contextual gate | `peek_surface` collision-shape tag authored by Mission & Level Scripting is detected within 1.5 m of Eve's forward-facing raycast. Gate returns `false` if no peek surface is detected. Peek surfaces are authored per-room (doors, vent grilles, gapped walls). |
| Pillar | **2** (Discovery Rewards Patience) — the Compact rewards players who stop before a door. |
| BQA memo (description field) | *KL/031/C: Ladies' powder compact, covert optical surveillance instrument. Standard cosmetic exterior; interior mirror is a cerium-coated relay lens feeding a sub-3mm fiber bundle to the case rim. Operative to apply facing away from the observed surface and hold steady. Instrument emits an audible mechanical whirr during lens extension — operative is advised that activation is not perfectly silent. Not to be returned with lipstick residue. Replacement cost is charged to the operative's department.* |
| SAI interaction | **Direct (REVISED 2026-04-24 per [game-designer R-2] — was previously "None").** Activation emits a single positional NoiseEvent at Eve's current position: `NoiseEvent { type = CURIOSITY_BAIT, radius_m = compact_activation_noise_radius = 3.0, origin = player.global_position }`. The whirr is brief (tied to the 200 ms lens-extension SFX from §A.2), emitted once on activation, not continuous. Any UNAWARE guard within 3 m whose perception cone resolves the noise enters SUSPICIOUS per SAI F.2b spike rules (same cost model as the Cigarette Case, smaller radius). No emission during the passive viewing duration — only the single activation whirr. Rationale: Compact is no longer "free perfect info in tagged rooms"; peek has a real cost and respects Pillar-3 risk-weighted observation. Closes the Compact-as-wet-remote-camera concern. |
| Forbidden modes | No through-walls sight (requires a peek-surface authored tag — "x-ray vision" would violate Pillar 4). No guard-highlighting UI overlay (Pillar 5 — no modern outline-on-hostile). No silent-activation mode (the whirr is diegetic and SAI-hearable; a "silent Compact" accessibility toggle would become an exploit). |

**Gadget 2 — The Cigarette Case** (pre-packed #2).

| Field | Value |
|---|---|
| `gadget_id` | `&"gadget_cigarette_case"` |
| `display_name` | "Cigarette Case, Covert Acoustic" |
| Cover identity | Silver cigarette case monogrammed "E.S." on the face; six Sobranie cigarettes visible when opened (period dressing, no mechanical function); clockwork clicking mechanism concealed in the lid seam |
| Utility | **Acoustic diversion placement.** On activation, Eve places the case on a valid placement surface within 1.5 m of her forward-facing raycast. After placement, the case emits a **4-second looped clicking noise** at the case's world position. Stealth AI's noise perception treats the case position as a noise source (NOT Eve's position) — a guard within hearing range whose perception cone intersects the case will transition to SUSPICIOUS with investigation target set to case position. After 4 s, the clicking stops; the case remains placed. Retrieve/claim model (REVISED 2026-04-24 per [game-designer R-3]): **the investigating guard "claims" the case.** When the attracted guard's SUSPICIOUS investigation resolves (guard returns to UNAWARE — SAI's normal de-escalation after the ~4 s Suspicious timeout without further cues), the case is queue_free'd from the world with a subtle "guard picks up item" beat (guard pauses at case position for ~0.5 s, case mesh disappears, guard shakes head and returns to patrol). Eve **cannot** retrieve the case if a guard reaches it. Eve CAN retrieve the case (walk within 0.5 m of placed position) ONLY while no guard has reached the investigation target — the window is the transit time from guard spotting the noise to guard arriving. If no guard hears it in the 4-second window, Eve can retrieve freely. Result: the case is consumed when successfully used as bait; only unused / unheard placements are recoverable. Preserves "single distraction beat" without spam exploits. |
| Contextual gate | `placeable_surface` collision-shape tag authored by Mission & Level Scripting within 1.5 m of Eve's forward-facing raycast, with local up-vector ≥ 0.7 (flat-enough horizontal surface). Gate returns `false` if no placeable surface is reachable OR if a case is already placed AND unclaimed (max one active case in the world — CR-4b returns early with affordance cue). Once the placed case has been claimed by an investigating guard and queue_free'd, the gate returns to permitting placement. **Charge model (2026-04-24)**: the Cigarette Case is NOT charge-limited per mission — Eve can place any number of cases over the course of the mission, but only one can exist in the world at a time, and successful uses are consumed by the investigating guard. This means a mission with no guards would allow unlimited re-placement (no practical limit); a mission with many guards consumes one case per successful distraction. Pillar-2 scarcity lever is guard-encounter-count, not per-mission case count. |
| Pillar | **3** (Stealth is Theatre, Not Punishment) — creates patrol gaps via non-violent distraction, fully reversible (guard returns to Unaware after investigation if nothing confirms). |
| BQA memo (description field) | *KL/088/A: Cigarette case, monogrammed silver, covert acoustic diversion instrument. Inner clockwork mechanism produces a 4-second clicking sequence when activated via left thumb pressure on the E-monogram inset. Operative leaves case on any available surface and proceeds. Cigarettes are standard issue Sobranies; not for personal consumption on active operations. Case to be retrieved following use.* |
| SAI interaction | **Direct.** Case emits a noise event at its world position into SAI's `HearingPoller` with `noise_level = 3` (equivalent to Sprint-tier noise — audible at ~8 m per SAI F.2). Effect: targeted guard enters SUSPICIOUS with investigation target = case position. Multi-guard propagation applies per SAI F.4 (`PROPAGATION_BUMP` can escalate nearby guards). Case does NOT trigger COMBAT state directly (noise-only, no player-spotted cue). If the investigating guard reaches the case and finds no additional cues within their Suspicious timeout (~4 s after clicks stop), they return to UNAWARE per SAI state-diagram. |
| Forbidden modes | No thrown / ranged placement (Pillar 5 — the case is elegant equipment, not a grenade). No detonation / explosive mode (anti-pattern: thrown gas canister violation). No stacking (max 1 case active at a time). |

**Gadget 3 — The Parfum Bottle** (mission-pickup, Tier 1 Eiffel Tower restaurant section).

| Field | Value |
|---|---|
| `gadget_id` | `&"gadget_parfum"` |
| `display_name` | "Parfum Bottle, Covert Sedative" |
| Cover identity | Cobalt-blue glass bottle, gold atomizer bulb, label reads "Nuit de PHANTOM — Eau de Parfum, 15 ml." Found in a locked cabinet in the Eiffel Tower restaurant's private dining room, with a BQA dead-drop note from "Operative Whitmore." |
| Utility | **Front-facing sedative aerosol spray.** On activation, Eve sprays a mist in a 1.5 m forward cone. Any guard whose head collider enters the cone within 0.5 s of spray AND is NOT in COMBAT state AND is NOT already UNCONSCIOUS transitions to UNCONSCIOUS via the SAI `receive_damage(guard, amount=0, attacker=player, damage_type=DamageType.MELEE_PARFUM)` path (REVISED 2026-04-24 per OQ-INV-1 Option B — was `DART_TRANQUILISER` pre-revision; changed so CR-7 subscriber can distinguish Parfum-KO for no-drop routing). Same terminal outcome (UNCONSCIOUS with `WAKE_UP_SEC = 45s` wake clock), different cause propagation. Distinguishing gate vs existing tools: front-facing (no rear-arc requirement like blade); melee-range (unlike dart); silent (unlike fists 3-swing noise). |
| Contextual gate | Forward-facing raycast hits a guard within 1.5 m AND guard's alert state is NOT COMBAT AND NOT UNCONSCIOUS AND NOT DEAD. Gate returns `false` otherwise. |
| Pillar | **3** (Stealth is Theatre — fills front-facing silent-non-lethal gap) + **4** (Iconic Locations — the gadget is narratively bound to the Eiffel Tower restaurant section) |
| BQA memo (description field) | *FS/PHANTOM/007: Parfum bottle, cobalt glass, Nuit de PHANTOM branding, recovered from dead-drop asset (restaurant level, cabinet C, shelf 2). Contents appear to be a modified thiamine-series sedative in aerosol suspension. Lab analysis confirms non-lethal at standard perfume-bottle concentration. Operative Whitmore's incident report notwithstanding, fieldwork use is approved at range ≤1.5 m, face-toward target only. Do not spray near the wine.* |
| SAI interaction | **Direct (REVISED 2026-04-24 — OQ-INV-1 resolved Option B).** Routes through SAI's existing `receive_damage(guard, 0, eve, DART_TRANQUILISER)` path per SAI OQ-CD-1 amendment (MELEE_NONLETHAL → UNCONSCIOUS). The UNCONSCIOUS transition fires `Events.guard_incapacitated(guard, cause: DamageType)` — **signature extended 2026-04-24 to include the `cause` parameter per ADR-0002 amendment coordination item** so Inventory's CR-7 drop subscriber can distinguish dart-KO from Parfum-KO from fist-KO. Parfum-KO drops **nothing** (`guard_drop_dart_on_parfum_ko = 0`, LOCKED anti-farm invariant mirroring fist-KO). Preserves the Ghost dart-economy break-even invariant — unlimited Parfum activations cannot farm darts. Tonal alignment preserved: Parfum is a perfume bottle with sedative aerosol, not a reloaded dart dispenser. |
| Forbidden modes | No spray against COMBAT-state guards (gate returns false). No spray against UNCONSCIOUS/DEAD guards (gate returns false — prevents idempotent re-spray). No area-of-effect / multi-target mode (only the first guard intersecting the cone is affected — prevents "spray down the corridor" at 3 guards simultaneously). No lethal mode. |

### C.3 Forbidden Gadget Archetypes (explicit record)

The following popular stealth-game gadget archetypes are **explicitly excluded** from MVP and VS. Downstream GDDs (Mission Scripting, Settings & Accessibility, Civilian AI) should reference this list when considering new gameplay hooks; the burden of proof is on *re-opening*, not on keeping-excluded.

| Archetype | Why excluded |
|---|---|
| **Remote spy camera / sticky-cam** (Splinter Cell, Deus Ex) | Duplicates the Compact's utility (room scouting) without the cover-identity joke. Pure surveillance tool — no bureaucrat-giggle dimension. A camera-that-is-a-camera fails the period-absurdity seat. |
| **Knockout gas grenade / thrown sedative canister** (Dishonored sleep darts in thrown form, Hitman gas) | Pure combat escalation — belongs to Combat, not Inventory. Duplicates dart-gun role at AoE scale. Grenade-shaped gadget is a tactical-FPS trope with no 1965 spy-comedy register. The Parfum Bottle delivers the sedative-aerosol fantasy at melee range with a cover disguise; a thrown canister is the anti-pattern. |
| **Disguise / uniform kit** (Hitman) | Tier 3 Full Vision scope (game-concept.md). Even as a gadget, a "PHANTOM uniform" in a drawer would be a progression-gate prop (anti-pattern) masquerading as a gadget. Mission Scripting owns any such narrative item if it ever appears. |
| **Keycards / access tokens as gadgets** | Narrative props, not gadgets. Mission Scripting places keys as world objects interacted with on specific doors. Keys do NOT enter `_gadget_cycle[]`. |
| **Grapple hook / zipline clip** | Pillar 5 / Pillar 4 — the Eiffel Tower's vertical traversal is authored via stairs / lifts / maintenance gangways, not player-directed climb tools. A zipline would compete with the Tower's geometry rather than co-star with it. |
| **Holographic decoy / projected image** | Anachronistic (1965 technology ceiling — no holograms). Would violate Pillar 5. |
| **Proximity mine / tripwire** | Combat-escalation anti-pattern (see gas grenade reasoning). Also: lethal explosives violate Pillar 3 reversibility — a mine-KO'd guard is DEAD, not UNCONSCIOUS. |
| **X-ray / thermal goggles** | "Wall-hack" UI — Pillar 5 violation. Compact provides the *authored* peek path without granting omniscience. |

### C.4 States and Transitions

Inventory has 5 distinct states. The state is a single enum on `InventorySystem` (not distributed across sub-nodes).

```gdscript
enum InventoryState {
    IDLE,                # Weapon equipped, ready for input
    SWITCHING,           # 0.35s holster-draw blend in progress (CR-3)
    RELOADING,           # Reload in progress (Combat timer-owned)
    HAND_BUSY,           # PC's is_hand_busy() is true (external override)
    PICKUP_IN_PROGRESS,  # Single-frame pocket_item execution
}
```

**Transition table:**

| From \ To | IDLE | SWITCHING | RELOADING | HAND_BUSY | PICKUP_IN_PROGRESS |
|---|---|---|---|---|---|
| **IDLE** | — | weapon_slot_N press (CR-1), weapon_next/prev press (CR-2) | reload input press + magazine < mag_size + reserve > 0 (Combat-owned) | `player.is_hand_busy()` transitions false→true | `Events.player_interacted` emits with WorldItem target (CR-6) |
| **SWITCHING** | 0.35 s timer elapses; `weapon_switched` emits (CR-3) | — | ❌ | ❌ (damage / hand_busy cannot override SWITCHING per CR-3 invariant) | ❌ |
| **RELOADING** | Reload timer elapses (Combat); `ammo_changed` emits | weapon_slot_N press (cancels reload, CR-1) | — | `is_hand_busy()` transitions true (cancels reload) | ❌ (pickup input is gated — interact is priority-2 only; this path doesn't exist in practice) |
| **HAND_BUSY** | `is_hand_busy()` transitions true→false | ❌ (weapon_slot_N silent-rejected per CR-1) | ❌ (reload silent-rejected) | — | ❌ (interact prompt suppressed when `is_hand_busy()` per CR-6) |
| **PICKUP_IN_PROGRESS** | Synchronous return from `pocket_item` (same frame) | ❌ | ❌ | ❌ | — |

**Invariants:**

- SWITCHING is **non-cancellable** — no input or signal can exit SWITCHING before the 0.35 s timer completes. Damage during SWITCHING does NOT cancel (Combat CR-16).
- HAND_BUSY is **externally driven** — Inventory does not set `is_hand_busy()`; PC owns it. Inventory polls (or subscribes to a hypothetical `player_hand_busy_changed` signal if PC adds one — forward coordination item).
- PICKUP_IN_PROGRESS is **single-frame synchronous** — `pocket_item` returns before the next frame. Listed as a formal state for completeness but never observable for more than 1 physics tick.
- Entering SWITCHING from RELOADING CANCELS the reload (partial progress lost; magazine retains pre-reload count). Entering HAND_BUSY from RELOADING also cancels.
- Gadget rotation (`gadget_next/prev`) does NOT transition state — rotation is a pure data mutation that fires during any state (CR-5 Exception: no gate).

### C.5 Interactions with Other Systems

The table below specifies what flows in each direction and who owns the interface. Each row is a **bidirectional contract** — both sides must honour the same API names.

| Other system | Direction | Data in / method called by Inventory | Data out / signal emitted by Inventory | Interface owner |
|---|---|---|---|---|
| **Player Character** (Approved) | bidirectional | **In**: polls `player.is_hand_busy() -> bool` each frame during input handling; reads `player.HandAnchor` (attach point for held-mesh); sets `player.LeftHandIK.target` / `player.RightHandIK.target` Marker3D references on weapon-switch; consumes `InteractPriority.Kind` enum (PICKUP = 2). | **Out**: calls `player.apply_heal(amount: float, source: Node)` on medkit pickup (CR-9). Subscribes to `Events.player_interacted(target: Node3D)` for pickup routing (CR-6). | PC owns `HandAnchor`, `is_hand_busy()`, `apply_heal()`, `InteractPriority.Kind`, `LeftHandIK`/`RightHandIK`. Inventory owns held-mesh lifecycle + medkit heal caller. |
| **Combat & Damage** (Approved) | bidirectional | **In**: Combat reads `WeaponResource.base_damage`, `fire_rate_sec`, `magazine_size`, `damage_type_int` on each fire via `Combat.apply_fire_path(weapon, position, direction)`. Reads `guard._last_damage_type: int` (Combat's enum member) on `enemy_killed` / `guard_incapacitated` to select drop table (CR-7a). | **Out**: calls `Combat.apply_fire_path(...)` on successful fire gate pass. Emits `Events.weapon_fired(weapon, position, direction)` (owns this emit-site per ADR-0002). Emits `Events.ammo_changed(weapon_id, mag, reserve)` after reload / drop-pickup. | Weapon Resource schema: **Inventory owns**. `weapon_fired` emit-site: **Inventory owns**. Fire-gate (when to emit): **Inventory owns** (Q3 feasibility correction). Damage math, projectile spawn, hitscan, pre-fire occlusion check: **Combat owns** (Combat CR-6). |
| **Stealth AI** (Approved) | outbound read | **In**: reads `SAI.takedown_prompt_active() -> bool` inside Combat's single-dispatch handler (CR-4) to route `use_gadget` vs `takedown`. Subscribes to `Events.guard_incapacitated(guard: Node)` for UNCONSCIOUS drops (CR-7 dart-KO + fist-KO + Parfum-KO routing). | **Out**: emits `gadget_used(gadget_id, position)` when any gadget activates; the Cigarette Case routes the case position into SAI's `HearingPoller` (noise event) via gadget-behavior scene logic, NOT via a direct SAI method call from Inventory. | SAI owns `takedown_prompt_active()`, `guard_incapacitated` signal, `HearingPoller` API. Inventory emits diegetic noise events by spawning a Noise node at the case position (same pattern as FootstepComponent). |
| **Input** (Approved) | inbound only | **In**: consumes `weapon_slot_1..5`, `weapon_next`, `weapon_prev`, `gadget_next`, `gadget_prev`, `fire_primary`, `reload`. `use_gadget` / `takedown` shared action is dispatched by Combat (CR-4), not consumed directly by Inventory. `interact` is consumed by PC; Inventory receives the post-resolution `player_interacted` signal. | **Out**: none. Inventory emits no input actions. | Input GDD owns action names; Inventory consumes. |
| **Signal Bus (ADR-0002)** | bidirectional | **Subscribed**: `Events.enemy_killed(guard, killer)` (CR-7 lethal drops); `Events.guard_incapacitated(guard)` (CR-7 non-lethal drops — SAI-emitted); `Events.player_interacted(target)` (CR-6 pickups — PC-emitted). | **Emitted** (ADR-0002 frozen signals owned by Inventory): `gadget_equipped(id: StringName)`, `gadget_used(id: StringName, position: Vector3)`, `weapon_switched(id: StringName)`, `ammo_changed(weapon_id: StringName, current: int, reserve: int)`, `weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)`. | ADR-0002 owns the bus; Inventory's subscription on `guard_incapacitated` + candidate emit of `gadget_activation_rejected` are **Coordination items** (see §F). |
| **Save / Load** (Designed pending review, ADR-0003 frozen) | bidirectional | **In**: `LevelStreamingService.register_restore_callback(_on_restore_from_save)` called from `_ready()` per LS CR-2 (pattern owner is Level Streaming, NOT Save/Load — corrected 2026-04-28 per `/review-all-gdds` 2026-04-28 finding 2a-1). On restore: receives `InventoryState: Resource` from Failure & Respawn (after floor application) or from Save/Load directly on save-slot load. | **Out**: on save trigger, provides `InventoryState` via the registered callback. Schema per CR-11. | ADR-0003 owns format; Inventory owns populate/restore logic + `restore_weapon_ammo(snapshot, floor, max_cap)` method. |
| **Mission & Level Scripting** (Not Started) | inbound | **In**: Mission Scripting places `WorldItem` nodes with `item_id`, `quantity`, and (for mission gadget) `gadget_resource: GadgetResource`. Mission Scripting authors `peek_surface` and `placeable_surface` collision-shape tags for gadget contextual gates. Sets `guard.carried_weapon_id: StringName` at guard-spawn. | **Out**: none (reads passively from scene-authored nodes). | Mission Scripting owns placement authoring + tag authoring; Inventory reads passively. |
| **Failure & Respawn** (Not Started) | inbound | **In**: F&R calls `InventorySystem.restore_weapon_ammo(snapshot: InventoryState, floor: Dictionary, max_cap: Dictionary) -> void` on respawn. F&R owns `floor_applied_this_checkpoint: bool` flag (first-death-only floor). Floor values from Combat §F.6: pistol total = 16, dart total = 8. | **Out**: none. | Combat defines floor contract; F&R owns per-checkpoint flag; Inventory implements method. |
| **HUD Core** (APPROVED 2026-04-26) | outbound only | **In**: none. | **Out**: HUD Core subscribes to Inventory's 4 frozen Inventory-domain signals (`ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected` *if added via ADR-0002 amendment*). HUD renders; Inventory does NOT render. | HUD Core owns rendering; Inventory owns signals. |
| **Audio** (Approved) | outbound only | **In**: none. | **Out**: Audio subscribes to `weapon_fired`, `gadget_used`. Also subscribes to a separate dry-fire click signal (NOT `weapon_fired`) — Inventory emits `weapon_dry_fire_click(weapon_id)` — new candidate, ADR-0002 amendment. **Coordination item** (see §F). | Audio owns SFX + music routing; Inventory owns signals. |
| **Document Collection** (Not Started) | none (indirect via PC priority) | **In**: both systems are potential consumers of the `interact` raycast. Priority resolution lives inside PC (`InteractPriority.Kind.DOCUMENT = 0` vs `PICKUP = 2` — lower wins, so a Document geometrically nearby but with overlapping WorldItem always wins). Inventory and Document Collection do NOT communicate directly. | **Out**: none to Doc Collection. | PC owns priority resolution. |
| **Settings & Accessibility** (Not Started) | inbound | **In**: future accessibility toggles may affect gadget affordance cues (e.g., disable gamepad haptic on CR-4b reject, or add a non-diegetic "gadget ready" HUD glyph). Forward-dep. | **Out**: none. | Settings owns toggles; Inventory consumes via Settings API (forward contract). |

**Performance budget.** Per ADR-0008, Inventory's per-frame cost falls under **Slot #8 (pooled residual, 0.8 ms)** — Inventory has no `_process` or `_physics_process` ticking cost in steady state. All activity is event-driven (`_unhandled_input`, `Events.*` subscribers, `player_interacted` subscriber). Estimated worst-case frame cost:

| Scenario | Estimated cost | Slot |
|---|---|---|
| Idle (IDLE state, no input) | ~0 ms (no tick) | — |
| Fire press (magazine decrement + 2 signal emits) | < 0.05 ms (one-shot) | #8 |
| Weapon swap (instantiate + queue_free + re-parent) | 0.05–0.15 ms (one-shot, at `t = 0.175 s` of swap) | #8 |
| Pickup event (dict write + queue_free + signal emit) | < 0.05 ms (one-shot) | #8 |
| Gadget activation (behavior-scene spawn) | 0.05–0.3 ms depending on gadget (Compact camera-swap is cheapest; Parfum raycast + SAI call is most expensive) | #8 |

No sub-budget allocation is requested from ADR-0008. If a future gadget introduces per-frame polling (e.g., a tracker that updates a HUD marker each frame), that gadget's implementation triggers a budget coordination request (§F).

## Formulas

Inventory's math is primarily procedural (state transitions, clamps, offsets). The formulas below formalize the 6 non-trivial computations; the bulk of state-machine behavior is captured in §C Core Rules. Locked registry values are referenced by name — do NOT inline alternative values here.

### F.1 — Pickup cap clamp

The pickup-cap clamp formula is defined as:

`new_reserve = min(current_reserve + pickup_quantity, max_reserve_cap)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `current_reserve` | R | int | [0, `max_reserve_cap`] | Rounds currently held in reserve for the weapon being restocked |
| `pickup_quantity` | Q | int | [1, 99] | Number of rounds on the WorldItem being pocketed (`world_item.quantity`) |
| `max_reserve_cap` | C | int | {48, 24, 12} | Per-weapon reserve ceiling: pistol = `pistol_max_reserve = 48`, dart = `dart_max_reserve = 24`, rifle = `rifle_max_reserve = 12` |
| `new_reserve` | R' | int | [0, `max_reserve_cap`] | Post-pickup reserve value written back to `ammo_reserve[weapon_id]` |

**Output Range:** [0, `max_reserve_cap`]. The `min()` clamp is the sole bound; excess rounds above cap are silently discarded. `world_item.queue_free()` fires regardless of how many rounds were absorbed — partial pickups at cap do NOT produce a partial WorldItem remainder (E.2).

**Example A — pistol at 40 reserve picks up a 3-round guard drop:**
- R = 40, Q = 3, C = 48
- R' = min(40 + 3, 48) = 43. Full pickup absorbed; no discard.

**Example B — pistol at 47 reserve picks up a 3-round guard drop:**
- R = 47, Q = 3, C = 48
- R' = min(47 + 3, 48) = 48. 1 round absorbed; **2 rounds discarded silently**.

**Example C — dart at 24 reserve picks up 1-dart drop (from guard_incapacitated):**
- R = 24, Q = 1, C = 24
- R' = min(24 + 1, 24) = 24. 0 rounds absorbed; **1 dart discarded silently**. WorldItem still frees per CR-6. (E.3 — dart at cap: PICKUP resolves but is a no-op clamp.)

### F.2 — Respawn ammo floor restore (redistribution)

Called by Failure & Respawn on respawn restore, per-weapon:

```
target_total = clamp(max(snapshot_total, floor), 0, max_cap)
magazine     = min(target_total, magazine_size)
reserve      = target_total - magazine
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `snapshot_total` | S | int | [0, `max_cap`] | `snapshot.ammo_magazine[weapon_id] + snapshot.ammo_reserve[weapon_id]` at checkpoint death |
| `floor` | F | int | {0, 8, 16} | Minimum guaranteed total on first-death-per-checkpoint: pistol = `respawn_floor_pistol_total = 16`, dart = `respawn_floor_dart_total = 8`, rifle = 0 (no floor) |
| `max_cap` | C | int | {48, 24, 12} | Per-weapon ceiling |
| `magazine_size` | M | int | {8, 4, 3} | `weapon.magazine_size` — pistol 8, dart 4, rifle 3 |
| `target_total` | T | int | [0, `max_cap`] | Post-clamp total ammo to redistribute |
| `magazine` | mag | int | [0, `magazine_size`] | Post-restore magazine count (fill magazine first) |
| `reserve` | res | int | [0, `max_cap` − `magazine_size`] | Remainder after magazine fill |

**Output Range:** `target_total` is bounded by the outer clamp; `magazine` is bounded by `magazine_size`; `reserve` is bounded by `max_cap − magazine_size`. None can be negative.

**Example A — pistol, dying below floor (3 mag + 5 reserve = total 8, floor = 16, cap = 48):**
- S = 8, F = 16, C = 48, M = 8
- T = clamp(max(8, 16), 0, 48) = 16
- mag = min(16, 8) = 8; res = 16 − 8 = 8
- Result: **8 mag + 8 reserve = 16 total**. Floor triggered.

**Example B — pistol, dying above floor (6 mag + 12 reserve = total 18, floor = 16, cap = 48):**
- S = 18, F = 16, C = 48, M = 8
- T = clamp(max(18, 16), 0, 48) = 18
- mag = 8; res = 10
- Result: **8 mag + 10 reserve = 18 total**. Snapshot preserved; floor not triggered; magazine re-filled.

**Example C — pistol at cap (6 mag + 42 reserve = total 48, floor = 16, cap = 48):**
- S = 48, T = clamp(max(48, 16), 0, 48) = 48
- mag = 8; res = 40. Result: 8 mag + 40 reserve = 48 total. Cap holds; corrupted-snapshot safe.

**Example D — dart, dying below floor (1 mag + 2 reserve = total 3, floor = 8, cap = 24):**
- S = 3, F = 8, C = 24, M = 4
- T = 8; mag = 4; res = 4
- Result: **4 mag + 4 reserve = 8 total**. Floor triggered for the dart path.

**Example E — rifle (no floor), dying with 1 mag + 2 reserve = total 3:**
- S = 3, F = 0 (rifle absent from floor dict), C = 12, M = 3
- T = max(3, 0) = 3; mag = 3; res = 0
- Result: **3 mag + 0 reserve = 3 total**. Snapshot unchanged (no rifle floor).

### F.3 — Multi-drop positional offset (REVISED 2026-04-24)

Applied when `_drop_index_this_tick > 0` within a physics tick (i.e., only the 2nd and later drops in the same tick are offset; the 1st drop spawns at guard position). Counter resets at `_physics_process` start (CR-7b, corrected from prior `_process` boundary):

```
if _drop_index_this_tick == 0:
    drop_position = guard.global_position              # single-drop case: no offset
else:
    drop_position = guard.global_position
                  + Vector3(cos(_drop_index_this_tick × 2.3), 0, sin(_drop_index_this_tick × 2.3)) × 0.4
_drop_index_this_tick += 1
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `guard.global_position` | P | Vector3 | world space | Guard's world-space origin at drop time |
| `_drop_index_this_tick` | i | int | [0, N−1] | Per-physics-tick drop counter, reset at each `_physics_process` start (fixed 2026-04-24 from prior `_process` boundary) |
| `2.3` | — | float | literal | Radian increment between drops. Irrational with 2π → no exact-angle repeats within the first 272 drops |
| `0.4` | — | float | literal | Radial offset in meters |
| `drop_position` | D | Vector3 | P (if i=0) or P ± 0.4 m (XZ) if i>0 | Final WorldItem spawn origin |

**Output Range:** If `i == 0`, D = P (no offset — single-drop case, prevents lone drops landing 0.4 m into walls). If `i > 0`, D is within 0.4 m of P in the XZ plane; Y is unchanged (ground plane). Two drops at indices 0 and 1 are separated by exactly `0.4 m` (i=1 is the first offset; its delta from origin is `(cos(2.3), 0, sin(2.3)) × 0.4`, distance from origin = 0.4 m). Two offsets at indices 1 and 2: separated by `0.4 × √(2 − 2cos(2.3)) ≈ 0.56 m`, exceeding 0.5 m z-fighting threshold.

**Example A — one guard dies alone (i=0 case):**
- i=0: offset NOT applied → D = P exactly. Drop at guard position. No risk of wall-clip from offset.

**Example B — two guards die on the same physics tick dropping one pistol-ammo WorldItem each:**
- Guard A, i=0: no offset → D_A = P_A
- Guard B at P_A (overlap), i=1: cos(2.3)≈−0.666, sin(2.3)≈0.746 → D_B = P_A + (−0.267, 0, 0.298)
- Separation ≈ 0.4 m. **Note**: this falls just below the 0.5 m z-fighting threshold stated in CR-7b. Acceptable given each mesh is ~180 tris and collision shapes are ~0.15 m — addressability by PC raycast is preserved. If z-fighting is observed in practice, increase literal radius from 0.4 to 0.5.

**Example C — three drops same tick (multi-guard kill, i=0,1,2):**
- i=0: D_0 = P
- i=1: D_1 = P + (−0.267, 0, 0.298) → distance from P = 0.4 m
- i=2: D_2 = P + (cos(4.6)×0.4, 0, sin(4.6)×0.4) ≈ P + (−0.043, 0, −0.398) → distance from P = 0.4 m
- Separation D_1↔D_2 ≈ 0.76 m. Well above z-fighting threshold.

### F.4 — Medkit heal

On medkit pickup (CR-9):

`player.apply_heal(medkit_heal_amount, self)` → `new_hp = clamp(current_hp + medkit_heal_amount, 0, player_max_health)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `medkit_heal_amount` | H | float | [25, 60] | HP restored per medkit. Default **40**. Safe range lower-bound (25) = minimum meaningful heal (> 1 pistol-hit absorption); upper-bound (60) = keeps Pillar-3 tension (does not fully reset from critical). |
| `current_hp` | hp | float | (0, 100] | Eve's HP pre-heal. Positive by invariant — if hp == 0, Eve is dead; medkit cannot be picked up post-death. |
| `player_max_health` | HP_max | float | 100 (locked PC registry) | Ceiling |
| `new_hp` | hp' | float | [hp, 100] | Post-heal HP |

**Output Range:** [hp, 100] — heal is monotonic (never reduces HP); clamp at max ensures over-heal is silently capped. `apply_heal` rejects H ≤ 0 (PC API invariant — Inventory never passes 0 or negative).

**Pillar-3 rationale:** At default H=40 and `guard_pistol_damage_vs_eve = 18`, one medkit absorbs ~2.2 guard-shots. From critical (hp=25, below `player_critical_health_threshold`), heal yields hp' = 65 — above critical but not full-reset. This preserves Composed Removal: the medkit is *permission to continue*, not *erasure of cost*.

**Example A — Eve at 35 HP picks up medkit:**
- hp = 35, H = 40 → hp' = min(35 + 40, 100) = 75.

**Example B — Eve at 75 HP picks up medkit (over-heal):**
- hp = 75, H = 40 → hp' = min(75 + 40, 100) = 100. 15 HP of heal "lost" to the cap. (No partial pickup — the medkit WorldItem still frees per CR-9.)

### F.5 — Cigarette Case noise event emission

The Cigarette Case's behavior scene emits a NoiseEvent every physics tick for the 4-second active duration (§C.2 Gadget 2). **Cross-reference correction (REVISED 2026-04-24 per [systems-designer REC-1]):** `CURIOSITY_BAIT` is primarily an `AlertCause` enum in SAI, not a NoiseEvent type. The NoiseEvent type field must map to SAI's EVENT_WEIGHT-supported event type vocabulary; the CURIOSITY_BAIT semantic is conveyed via the `AlertCause` the guard assigns on entering SUSPICIOUS. The NoiseEvent shape is therefore:

`NoiseEvent { type = BAIT_SOURCE, radius_m = case_noise_radius, origin = case.global_position, alert_cause = AlertCause.CURIOSITY_BAIT }`

where `BAIT_SOURCE` is a new NoiseEvent type added to SAI's EVENT_WEIGHT table (Coordination item #7 — SAI GDD amendment: add `BAIT_SOURCE` row to F.2b EVENT_WEIGHT table with weight equivalent to Sprint-tier; propagation suppressed per F.4 on `AlertCause.CURIOSITY_BAIT`, preserving the "single guard distraction beat" design intent). The emitter supplies both fields; SAI reads `type` for weight lookup and `alert_cause` for downstream propagation routing.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `case_noise_radius` | r | float | 8.0 m (locked) | Audible radius. Equivalent to Sprint-tier locomotion noise (PC noise table) at a fixed radius, not velocity-scaled |
| `case.global_position` | P_case | Vector3 | world space | World position of the placed case (NOT Eve's). SAI treats this as the LKP |
| `noise_level_tier` | — | int | 3 (Sprint-tier) | Governs `EVENT_WEIGHT[CURIOSITY_BAIT]` in SAI's F.2b |
| `active_duration_sec` | τ | float | 4.0 s | Clicking sequence duration. After τ, emitter queue_frees; case mesh persists until retrieved |

**SAI integration** (read-only contract — SAI F.2b is authoritative): audibility at guard position = `max(0, r − d(guard, P_case))`. Any UNAWARE guard within 8 m accumulates sound suspicion per the SAI perception formula. Per SAI's `CURIOSITY_BAIT` suppression rule (SAI F.4), the investigating guard does NOT propagate alert to other guards — the case is a self-contained distraction beat (matches Pillar-1 comedy register — one guard walking toward a clicking cigarette case is funnier than three).

**Output Range:** A guard adjacent to the case (d = 0) reaches SUSPICIOUS within 1–2 ticks (0.1–0.2 s) per SAI F.2b spike cap. A guard beyond 8 m is unaffected. Guards at 4–8 m transition to SUSPICIOUS within 1–3 s depending on SAI tuning.

**Example:** Eve places the case in the Ritz suite foyer (P_case = (4.5, 0, 2.1)). Guard A is at (3.1, 0, 2.0), d=1.4 m. Audibility = max(0, 8.0 − 1.4) = 6.6. Guard A transitions to SUSPICIOUS with `AlertCause.CURIOSITY_BAIT` at t≈0.1 s, navigates toward P_case, investigates for ~4 s post-click-stop, returns to UNAWARE if no Eve contact. Guard B at (11.0, 0, 4.8), d=6.8 m → audibility ≈ 1.2 → SUSPICIOUS transition slower (~2–3 s). Guard C at (20.0, 0, 8.0), d>8m → unaffected.

### F.6 — Per-encounter net ammo flow (Pillar-2 reconciliation)

**Purpose:** This formula is an **audit, not a prescription** — it verifies that the locked values in Combat GDD §F.6 + this GDD's cap/floor math + Mission Scripting's future cache placements produce the Pillar-2 depletion curve. If the simulation ever swings to Aggressive-positive, Pillar-2 has collapsed and either the drop values or the cache counts need adjustment.

For a single encounter with G guards, all carrying silenced pistols:

```
cost_aggressive  = G × cost_per_kill_pistol × (1 + miss_rate) + reload_overhead_rounds
drop_aggressive  = G × guard_drop_pistol_rounds
net_aggressive   = drop_aggressive − cost_aggressive

cost_ghost       = G × cost_per_ko_dart × (1 + dart_miss_rate)   # dart_miss_rate accounts for retries on missed shots
drop_ghost       = G × guard_drop_dart_on_dart_ko × (1 − unreachable_drop_rate)  # ~20% drops on inaccessible ledges per E.6
net_ghost        = drop_ghost − cost_ghost            # 0 at ideal play (100% dart hit, 0% unreachable); approximately −(0.1×c_d + 0.2×d_d) = −0.3 per KO in realistic play

cost_fist        = 0
drop_fist        = G × guard_drop_dart_on_fist_ko     (always 0 — LOCKED {0})
net_fist         = 0
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `guards_engaged` | G | int | [1, 10] | Number of guards in the encounter |
| `cost_per_kill_pistol` | c_p | int | 3 (locked, body-only TTK) | Combat §F.1: ceil(100 / silenced_pistol_base_damage=34) = 3 |
| `cost_per_ko_dart` | c_d | int | 1 (locked) | `dart_damage = 150 > 100 HP` → 1-shot KO |
| `miss_rate` | m | float | [0.0, 0.3] | Default estimate 0.20 for Aggressive play (Combat §F.3 implicit from spread) |
| `reload_overhead_rounds` | r_oh | int | [2, 4] | Rounds left in partially-emptied magazines lost to mid-combat reloads. Default 3 per 4-guard fight. |
| `guard_drop_pistol_rounds` | d_p | int | **3** (Combat §F.6 registry source-of-truth per 2026-04-22 NOLF1 rebalance) | Per-lethal-kill drop. Registry-synced 2026-04-23 to value 3 (`design/registry/entities.yaml:856`); prior 8→3 staleness closed. |
| `guard_drop_dart_on_dart_ko` | d_d | int | LOCKED {1} | Anti-farm invariant |
| `guard_drop_dart_on_fist_ko` | d_f | int | LOCKED {0} | Anti-farm invariant |
| `guard_drop_dart_on_parfum_ko` | d_pf | int | LOCKED {0} — NEW 2026-04-24 (OQ-INV-1 Option B) | Anti-farm invariant for Parfum-KO; see OQ-INV-1 resolution |
| `dart_miss_rate` | m_d | float | [0.0, 0.15] | Realistic dart-aim miss rate (headshot vs body miss). Default estimate 0.10 for a trained stealth player. |
| `unreachable_drop_rate` | u_d | float | [0.0, 0.3] | Fraction of drops landing on inaccessible geometry (ledges, pits, walls). Default estimate 0.20 per E.6. |
| `net_aggressive` | N_a | float | [−∞, 0] intended | Negative target — Aggressive depletes per-encounter. Positive = Pillar-2 collapsed. |
| `net_ghost` | N_g | float | `[−(c_d × m_d + d_d × u_d), 0]` | LOCKED at 0 ONLY at ideal play (0% miss, 0% unreachable). Realistic Ghost is mildly depleting: ~-0.3 darts per KO with defaults. Prior "LOCKED 0" language revised 2026-04-24. |
| `net_fist` | N_f | int | 0 (locked) | Anti-farm — fists are free and drop nothing. True invariant (no miss possible, no drop to become inaccessible). |

**Output Range for Aggressive (4-guard encounter default):**

- Cost = 4 × 3 × 1.2 + 3 = 14.4 + 3 ≈ **17 rounds**
- Drop = 4 × 3 = **12 rounds**
- Net = 12 − 17 = **−5 rounds per encounter** (Aggressive depletion confirmed)

**Output Range for Ghost (4-guard encounter default, realistic play — REVISED 2026-04-24):**

- Cost = 4 × 1 × 1.10 (10% miss) = 4.4 darts
- Drop = 4 × 1 × 0.80 (20% unreachable) = 3.2 darts
- Net = 3.2 − 4.4 = **−1.2 darts per 4-guard encounter** in realistic play.
- **Ideal play (skilled stealth, favorable geometry):** Cost=4, Drop=4, Net=0. This is the "break-even" reference but it requires 100% dart accuracy AND 0% unreachable-drop terrain, which is an asymptote not a guarantee.
- Across 35-guard mission: ~−10 darts realistic vs 0 ideal. Starting dart reserve 16 → 6 at mission end (realistic), 16 end (ideal). Caches close the realistic-play gap.
- **Pillar-2 signal:** Ghost-realistic actually DOES have mild scarcity pressure, which improves Pillar-2 differentiation from Aggressive (no longer "everyone ends capped"). Previously, the false-invariant "Ghost=0 break-even" obscured this.

**Output Range for Fist (4-guard encounter default):**

- Cost = 0; Drop = 0. Net = **0** (LOCKED).

**Example (5-section mission, midpoint guard counts: 4/7/9/9/6 = 35 guards total):**

Aggressive: 5 × avg(−5) ≈ **−25 rounds net-flow across mission without caches**. Starting pistol reserve = 40 (8 mag + 32 reserve). End-of-mission pistol = 40 − 25 = 15 rounds. Hits near respawn floor (16); cache support from Mission Scripting is **load-bearing** — without ~11 modestly-sized caches (6 pistol rounds typical), Aggressive bottoms out or forces a death-for-floor-restore exploit (partially closed by first-death-per-checkpoint flag in Failure & Respawn).

Ghost: 35 guards × 0 = **0 darts net-flow**. Starting dart reserve = 20. End-of-mission = 20 darts. Dart-only play is sustainable if the player's KO accuracy is 100%. Dart pickup miss (e.g., Eve can't reach the drop because the guard fell into an inaccessible pit) shaves this; caches provide the margin. economy-designer 2026-04-23 recommends ~11 caches across 5 sections with mixed contents (6 pistol + 2 dart typical).

**Pillar-2 delta check (Aggressive vs Ghost end-of-mission, with 11 caches delivering +33 pistol rounds and +10 darts):**

- Aggressive end pistol: 15 + 33 − (caches missed, ~10%) ≈ **42 rounds** (from 40 start)
- Ghost end pistol: 40 (never spent pistol) + any pistol caches found = ~65 (but capped at 48) = **48 rounds**
- Aggressive end dart: 20 + ~9 darts from caches ≈ **24 darts** (at cap)
- Ghost end dart: 20 + 9 + 0 spend = 29, capped at **24 darts**
- **Pistol delta: 48 − 42 = 6 rounds (~14%). Dart delta: 0.** Weak Pillar-2 signal on absolute totals.

**CONCERN (flagged to §Open Questions OQ-INV-2):** Pillar-2 differentiation is psychological (felt-scarcity during play — the Aggressive player saw the ammo counter drop below 10 multiple times) rather than end-state (everyone finishes near-full with caches). Playtest-gated: validate that Aggressive-path players *report* feeling ammo pressure at S3-S4 even if end-of-mission totals are close. If playtest shows no felt scarcity, reduce S4 cache counts (economy-designer recommendation: remove S4 main-route pistol cache to create a real "hunt for the off-path cache" beat).

## Edge Cases

50 edge cases covering 10 categories (A–J). Each names the exact condition and the exact outcome; no hand-waving. Cross-edge cases with Combat (E.8 / E.32 / E.33 / E.35 / E.37 / E.41) and SAI (E.19–E.23) are explicitly reconciled. Two items raised to §Open Questions (OQ-INV-3, OQ-INV-4).

### A. Ammo / Pickup Edges

- **E.1 [A — pickup at cap]**: If `current_reserve == max_reserve_cap` at pickup time, F.1 yields `new_reserve = max_reserve_cap`. Q rounds discarded silently. `world_item.queue_free()` fires regardless. `ammo_changed` emits with unchanged reserve. No partial-item remainder left in world.
- **E.2 [A — pickup while a different weapon is at cap]**: The clamp applies only to the picked-up weapon's reserve. The currently-equipped weapon is unaffected. Interact does NOT silent-reject; WorldItem always frees.
- **E.3 [A — pickup mid-reload]**: Pickup (priority-2, single-frame `PICKUP_IN_PROGRESS`) is orthogonal to reload (Combat-owned timer). Both proceed independently. Final reserve = `(pre-reload-reserve − rounds-used-by-reload) + pickup_quantity`, clamped to cap. No reload interrupt.
- **E.4 [A — pickup mid-SWITCHING]**: Per §C.4 state-table, `PICKUP_IN_PROGRESS` is NOT reachable from SWITCHING. `Events.player_interacted` is suppressed while `is_hand_busy()` is true, and SWITCHING drives HandAnchor mesh reattach. WorldItem remains in world; player picks up after the switch completes. **See OQ-INV-3 below**.
- **E.5 [A — two WorldItems at same XZ position]**: F.3 offset applies; `guard_index` counter increments per drop spawned in the frame. Separation ≈ 0.73 m at i=0,1 — both individually addressable.
- **E.6 [A — WorldItem spawns in inaccessible geometry]**: Spawn position = `guard.global_position + F.3 offset`. If guard died flush against a wall or on an unreachable ledge, the WorldItem may be un-pickable. Inventory does NOT validate floor reachability. Acceptable MVP loss (economy accounts for ~20% miss rate per F.6). `FALL_OUT_OF_BOUNDS` kills explicitly suppress any drop (CR-7a row 6). Mission Scripting should avoid placing guards < 0.5 m from walls in beats where drop retrieval matters.
- **E.7 [A — guard dies lethally carrying no weapon]**: CR-7a row 3. `enemy_killed` fires; Inventory reads `guard.carried_weapon_id == &""` → no WorldItem. No `ammo_changed` emit. Correct behavior for narrative unarmed guards.

### B. Weapon-Switch Edges

- **E.8 [B — direct-select same slot]**: `weapon_slot_N` where `N == current_weapon_slot`: silent reject. Idempotent. No animation, no audio, no signal.
- **E.9 [B — weapon_slot_3 with no rifle]**: Silent reject with dry-click cue (Audio-owned `weapon_dry_fire_click` signal — distinct from reserve-empty dry-click). No `weapon_switched` emit. Slot addressable; item absent. Rationale: fully silent read as broken binding.
- **E.10 [B — direct-select during SWITCHING]**: Silent reject per CR-1. SWITCHING is non-cancellable; no queue. In-progress switch completes to its original target.
- **E.11 [B — direct-select during RELOADING]**: Interrupts reload; enters SWITCHING. Magazine retains pre-reload count (partial top-up discarded). Reserve unchanged. No `ammo_changed` emit on cancel.
- **E.12 [B — scroll with all non-current slots empty]**: Structurally impossible at MVP — fists (slot 5) and blade (slot 4) are innate; effective minimum cycle = 4.
- **E.13 [B — damage during SWITCHING]**: Does NOT cancel per CR-3 + Combat CR-16. 0.35 s animation continues; `weapon_fired` does not emit during the window. HP loss is Combat-routed independently.
- **E.14 [B — save/restore mid-SWITCHING]**: Checkpoints only fire at `section_entered`; SWITCHING cannot span a section boundary. On respawn, `current_weapon_id` holds the last-committed weapon (pre-switch state). Restore enters IDLE with that weapon equipped. No partial-switch state is saved; in-progress switches are silently abandoned.

### C. Gadget Edges

- **E.15 [C — Compact activated with no peek_surface in range]**: Gate fails. CR-4b: haptic pulse (50 ms, low) + HUD icon desaturation (0.2 s). `gadget_used` does NOT emit. Camera remains first-person. Behavior scene never fully instantiated.
- **E.16 [C — Compact active, player moves]**: Behavior scene cancels on any movement input (WASD / left-stick). Camera returns to first-person. `gadget_used` already emitted on activation; no cancellation signal (HUD tracks active-gadget-with-timeout internally from emit timestamp).
- **E.17 [C — Compact 10 s timer elapses naturally]**: Behavior scene's timer fires; camera returns to first-person; scene queue_frees. No deactivation signal. HUD indicator returns to idle via its own timer.
- **E.18 [C — Cigarette Case placed, then placed again mid-click]**: "Max one active case" gate fails. CR-4b cue. Placed case continues τ = 4 s click undisturbed.
- **E.19 [C — Cigarette Case placed, Eve walks >8 m away during emission]**: Case emits at `P_case` regardless of Eve's distance. Retrieval gate (walk within 0.5 m) is not met at >8 m; case remains placed and active. No edge; intended behavior.
- **E.20 [C — Cigarette Case placed on non-tagged surface]**: Gate requires `placeable_surface` tag + local up-vector ≥ 0.7. Either missing → gate fails, CR-4b cue fires, no placement.
- **E.21 [C — Cigarette Case retrieved mid-emission]**: Behavior scene detects Eve within 0.5 m, cancels noise emitter, queue_frees. Investigating guard de-escalates per SAI normal path (4 s timeout, then UNAWARE if no cues).
- **E.22 [C — Parfum sprayed at guard in COMBAT state]**: Gate `alert_state != COMBAT` fails. CR-4b cue. No `receive_damage` call. Rationale: Parfum is a stealth-approach tool.
- **E.23 [C — Parfum sprayed at UNCONSCIOUS guard]**: Gate `alert_state != UNCONSCIOUS` fails. Idempotent — re-spray has no effect, no waste.
- **E.24 [C — Parfum cone overlaps multiple guards]**: "Only the first guard in cone" per §C.2 Gadget 3. Behavior scene calls `get_overlapping_bodies()` and selects `result[0]`. **See OQ-INV-4 below** — nearest-guard semantics require explicit sort by distance.
- **E.25 [C — use_gadget with no gadget equipped]**: `_equipped_gadget == null` only in a transitional mid-rotation state. CR-4b step 4 silent reject, no cue. Not observable in normal play; defensive guard.
- **E.26 [C — gadget_next with only 1 gadget in cycle]**: Cannot occur at mission start (2 gadgets pre-packed) or post-Parfum (3 gadgets). Defensive behavior: `_gadget_cycle.size() == 1` → `gadget_next` wraps to index 0 (same entry), emits `gadget_equipped` with the same id (no-op from HUD's view).
- **E.27 [C — mission-pickup Parfum acquired post-save-point, then respawn]**: `InventoryState.mission_pickup_available` is serialized per CR-11. If checkpoint was saved BEFORE pickup: flag=false in snapshot; Mission Scripting re-spawns the WorldItem on section reload. If checkpoint was saved AFTER pickup: flag=true; `_gadget_cycle` restored with Parfum appended; WorldItem does NOT re-spawn (Mission Scripting reads flag and suppresses placement). **Mission Scripting forward-dep: must not re-place Parfum WorldItem when `mission_pickup_available == true`.**

### D. Medkit Edges

- **E.28 [D — medkit at 100 HP]**: `apply_heal(40)` → `new_hp = clamp(140, 0, 100) = 100`. 40 HP discarded silently. WorldItem still frees. `player_health_changed` emits regardless (PC unconditional). F.4 Example B path.
- **E.29 [D — multiple medkits on same tile]**: F.3 offset applies (≥0.73 m separation). Each heal call independent. Picking up both from 60 HP: first heal → 100, second heal → 100 (40 HP wasted). Total waste depends on order / timing.

### E. Save / Restore Edges

- **E.30 [E — restore with ammo above cap]**: F.2 `target_total = clamp(max(S, F), 0, C)` → clamp brings S > C down to C. No crash. `push_warning` logs the anomaly.
- **E.31 [E — restore below floor, first death per checkpoint]**: F.2 Example A path. Floor triggers. Second death: F&R sets `floor_applied_this_checkpoint = true`, passes empty floor dict on subsequent restore calls. F.2 with empty floor: `max(S, 0) = S` — snapshot-only.
- **E.32 [E — restore with mission_pickup_available=true but WorldItem already freed]**: Correct behavior. Cycle restored with Parfum appended; Mission Scripting suppresses re-spawn. Inventory takes no re-spawn action.
- **E.33 [E — restore with mission_pickup_available=false]**: Cycle = `[gadget_compact, gadget_cigarette_case]`. Mission Scripting re-places Parfum WorldItem on section load per authored position. Eve picks up again on next run.
- **E.34 [E — respawn floor applied twice in same checkpoint]**: Failure & Respawn owns `floor_applied_this_checkpoint`. First call passes floor dict; second call passes `{}`. Inventory executes `restore_weapon_ammo` blindly per CR-11. Flag reset at new `section_entered`.
- **E.35 [E — corrupt save: ammo_magazine contains unknown weapon_id]**: On restore, iterate snapshot keys. Unknown key → `push_warning` + skip; no mutation, no crash. Valid entries restored normally.

### F. Combat-Cross Edges

- **E.36 [F — pistol reserve dry, fire input (resolves Combat OQ-CD-3)]**: CR-15 — dry-fire click SFX via `weapon_dry_fire_click` signal (Audio-owned). `weapon_fired` does NOT emit. No ammo consumed. No auto-switch. Player switches manually via `weapon_slot_5` or scroll. Practiced Hands fantasy preserved.
- **E.37 [F — two guards killed same tile (Combat E.33)]**: F.3 offset. Both WorldItems at ≥0.73 m separation. No merge. Both individually pickable.
- **E.38 [F — save-restore mid-reload (Combat E.35)]**: Checkpoints fire at `section_entered`, never mid-action. `_is_reloading = false` on restore (CR-11 does not serialize it). Magazine + reserve retain last committed counts.
- **E.39 [F — respawn with ammo below floor (Combat E.37)]**: F.2 math. Pistol floor 16, dart floor 8, rifle no floor. Not farmable: first-death-per-checkpoint flag at F&R (E.34).
- **E.40 [F — dart wall-spawn cancelled by Combat pre-fire check (Combat E.41)]**: Combat CR-6 pre-fire occlusion check cancels at call site before Inventory's fire path proceeds. `_decrement_magazine()` is NOT called (gate failed pre-decrement). No `ammo_changed` emit. Dart magazine unchanged.

### G. Stealth AI-Cross Edges

- **E.41 [G — guard wakes from Parfum-KO; dart-drop already in world]**: On `guard_incapacitated`, Inventory spawns dart WorldItem (CR-7 same as dart-KO). If guard wakes (UNCONSCIOUS → SUSPICIOUS at `WAKE_UP_SEC = 45 s`), the WorldItem REMAINS in world. Inventory does NOT subscribe to wake signal. Dart drop at former incapacitation position is orphaned; player may retrieve it. No despawn.
- **E.42 [G — dart-KO + immediate blade-takedown → DEAD; double-drop risk]**: Both subscribers fire sequentially. `guard_incapacitated` → dart WorldItem spawned. Then blade-takedown routes via SAI CR-15 delegation → `apply_damage_to_actor(guard, 100, eve, MELEE_BLADE)` → `enemy_killed` fires → pistol-ammo WorldItem spawned (CR-7a lethal row). **Result: 1 dart + 1 pistol-ammo drop from same guard**, both legitimate (dart spent on KO; pistol drop from lethal finisher). F.3 offset prevents z-fighting. Design note: minor Pillar-2 concern — dart-then-execute is net "+1 dart, +3 pistol rounds" vs direct lethal's "+3 pistol rounds." Not an exploit (the dart was spent), but playtest-gated observation.

### H. Input-Cross Edges

- **E.43 [H — use_gadget pressed as takedown_prompt transitions false → true same frame]**: CR-4 single-dispatch reads `SAI.takedown_prompt_active()` once per event. Outcome: whichever state SAI reports at evaluation time wins. One-frame race window; consequence = "gadget activates instead of takedown on the exact frame prompt appears." Recoverable, not a softlock. No double-dispatch (`set_input_as_handled()` fires in both branches).
- **E.44 [H — weapon_slot_N + weapon_slot_M pressed same frame]**: Godot queues both; `_unhandled_input` fires in enqueue order. First press enters SWITCHING; second press during SWITCHING is silent-rejected per CR-1. Only first press executes. No queue of pending switches.

### I. Degenerate Player-Input Edges

- **E.45 [I — spam fire at max rate with dart gun]**: `fire_rate_sec` cadence timer gates. Presses during cooldown are dropped (`_can_fire()` returns false — no decrement, no emit). At magazine = 0: dry-fire click. Deterministic — no double-decrement possible.
- **E.46 [I — spam use_gadget on Compact]**: No cooldown per CR-5b. Gate re-evaluates each press. Rapid toggle-on/off with no state hazard; `gadget_used` emits on each activation. Behavior scene should debounce camera-flicker at its layer (implementation quality, not GDD contract).
- **E.47 [I — spam gadget_next at max rate]**: Ungated (CR-5). Each press rotates index + emits `gadget_equipped`. At 60 Hz button-hold: 60 emits/sec. HUD Core must tolerate rapid successive emits (update-in-place; no per-emit widget allocation). Estimated cost: negligible within ADR-0008 Slot #8.
- **E.48 [I — rapid weapon_slot_1 → 2 → 1 during SWITCHING]**: First press enters SWITCHING (if from IDLE). Subsequent presses during SWITCHING are silent-rejected per CR-1. Player ends up on weapon 2 regardless. No ping-pong.

### J. Performance / ADR-0008 Edges

- **E.49 [J — multiple WorldItems spawn in a single frame (mass guard death)]**: F.3 `guard_index` counter increments per drop. N drops in one frame → N synchronous `add_child` calls. Worst realistic case N = 6 (5-guard room + 1 cache scripted release) ≈ 0.3 ms one-shot, within ADR-0008 Slot #8's 0.8 ms budget. N ≥ 10 scenarios are excluded by Forbidden Archetype §C.3 (no grenades).
- **E.50 [J — pickup WorldItem while another is mid-spawn same frame]**: `pocket_item` executes synchronously in PICKUP_IN_PROGRESS. New WorldItem added via `add_child` within the same frame is not yet in PC's raycast result (raycast resolved at frame start, before add_child). New WorldItem becomes pickable on the next frame. No collision, no race.

### Open Questions raised by §E (flagged for §Open Questions)

- **OQ-INV-3** (E.4): Does `player.is_hand_busy()` return true during the SWITCHING state? PC GDD must clarify whether HandAnchor mesh-reattach sets this flag or whether SWITCHING blocks pickup via a separate Inventory-internal gate. **Owner: Player Character GDD revision (minor clarification). Target resolution: before pre-implementation.**
- **OQ-INV-4** (E.24): Parfum-cone nearest-guard selection — `get_overlapping_bodies()` order is non-deterministic under Jolt. Behavior scene should sort by `distance_to(player)` before selecting `result[0]`. **Owner: Inventory implementation sprint. Target resolution: Parfum behavior-scene implementation.**

## Dependencies

Every dependency is bidirectional — if this GDD lists "depends on Combat", Combat's GDD must list "depended on by Inventory". Mismatches are a §F audit gate (verified 2026-04-23 — all upstream deps reciprocate except SAI-`guard_incapacitated` subscription row, flagged as Coordination item below). **Hard** = system cannot function without it. **Soft** = enhanced by it but works without it.

### Upstream (systems this GDD depends on)

| Dependency | Status | Interface (what flows in) | Hard / Soft | Notes |
|---|---|---|---|---|
| **Player Character** (#8) | Approved | `HandAnchor` Node3D (child of Camera3D) for held-mesh parenting; `is_hand_busy() -> bool` polled to gate inputs and suppress pickup prompt; `InteractPriority.Kind.PICKUP = 2` enum consumed by PC's raycast resolver; `LeftHandIK` / `RightHandIK` targets (Marker3D names referenced from `WeaponResource.hand_pose_marker_name: StringName`); `apply_heal(amount, source)` called by medkit pickup (CR-9); `Events.player_interacted(target: Node3D)` subscribed by Inventory for priority-2 pickup routing (CR-6). | **Hard** | PC must ship before this GDD's sprint. PC is Approved; no block. Reciprocated by PC GDD §Dependencies table. |
| **Input** (#2) | Designed pending review | Consumes actions: `weapon_slot_1..5`, `weapon_next`, `weapon_prev`, `gadget_next`, `gadget_prev`, `fire_primary`, `reload`. Shared-binding `use_gadget`/`takedown` dispatched by Combat (CR-4). Does NOT consume `interact` directly — receives post-resolution signal via PC. | **Hard** | 10 action names Inventory consumes. Reciprocated by Input GDD rows L78–92. |
| **Combat & Damage** (#11) | Approved | Calls `Combat.apply_fire_path(weapon: WeaponResource, position: Vector3, direction: Vector3)` on successful fire gate pass (CR-14). Reads `Combat.is_lethal_damage_type(damage_type: int) -> bool` for drop-table routing (CR-7a). Reads `guard._last_damage_type: int` (Combat's `CombatSystemNode.DamageType` enum, accessed as int per GDScript enum-export limitation) to select drop payload. Reads `Combat.DamageType` enum members: `MELEE_BLADE`, `BULLET`, `DART_TRANQUILISER`, `MELEE_FIST`, `FALL_OUT_OF_BOUNDS`. | **Hard** | Combat is Approved; forward-dep row in Combat §Dependencies confirms Inventory owns Weapon Resource schema + `weapon_fired` emit-site. Combat's OQ-CD-3 (pistol-dry fallthrough) is resolved here in CR-15 + E.36. |
| **Stealth AI** (#10) | Approved | Reads `SAI.takedown_prompt_active() -> bool` inside Combat's single-dispatch handler (CR-4). Subscribes to `Events.guard_incapacitated(guard)` (CR-7 non-lethal drop routing). Parfum behavior scene calls `SAI.receive_damage(guard, 0, eve, DamageType.DART_TRANQUILISER) -> bool is_dead` (SAI's §F.1 contract). | **Hard** | SAI is Approved. Reciprocation: SAI GDD §Dependencies lists Inventory as forward-dep for Takedown-prompt consumer, BUT `guard_incapacitated` Inventory-subscription row is not yet listed in SAI GDD — **Coordination item #1** below. |
| **Signal Bus (ADR-0002)** | ADR Proposed | 4 frozen Inventory-domain signals declared in ADR-0002: `gadget_equipped(StringName)`, `gadget_used(StringName, Vector3)`, `weapon_switched(StringName)`, `ammo_changed(StringName, int, int)`. Plus the `weapon_fired(Resource, Vector3, Vector3)` emit-site owned by Inventory (per ADR-0002 + architecture.md §3.3). Subscribes to `enemy_killed`, `guard_incapacitated`, `player_interacted`, `section_entered` (via SaveLoad callback, not direct). | **Hard** | ADR-0002 freezes the 4 Inventory signals. New candidates (`gadget_activation_rejected`, `weapon_dry_fire_click`) are **Coordination item #2** — ADR-0002 amendment required. |
| **Save / Load (ADR-0003)** | Designed pending review; ADR Proposed | `LevelStreamingService.register_restore_callback(_on_restore_from_save)` registration (CR-11) — pattern owner is LS per LS CR-2, NOT Save/Load (corrected 2026-04-28 per `/review-all-gdds` 2026-04-28 finding 2a-1). `InventoryState: Resource` schema per ADR-0003. `ResourceSaver.save` / `ResourceLoader.load` are Save/Load-owned. Receives `InventoryState` on restore via callback. | **Hard** | ADR-0003 locked the Resource-as-save-shape pattern. Save/Load GDD §Dependencies confirms Inventory is a contributor. `register_restore_callback` pattern was added by LS GDD CR-10 and is reused here (no new API). |
| **Audio** (#3) | Approved | Audio subscribes to `weapon_fired` and `gadget_used` for SFX. Also subscribes to proposed `weapon_dry_fire_click(weapon_id)` signal (distinct from `weapon_fired` — Coordination item #2) and `gadget_activation_rejected(gadget_id)` if the affordance cue is audio-routed (currently NOT audio per CR-4b to avoid stealth-breakage — HUD desaturation + haptic only). | **Hard** | Audio is Approved; forward-dep row in Audio §Dependencies confirms subscription to 2 Inventory signals + `weapon_fired`. Audio GDD will need a minor touch-up when the Coordination item #2 ADR-0002 amendment lands. |
| **Localization Scaffold** (#7) | Designed pending review | Gadget `display_name` + `description` (BQA memo text) are localized via the string-table mechanism. `WeaponResource.display_name` + `description` are localized similarly. Pickup prompts ("pocket", "read note", "open door") are resolved by PC's interact system, not Inventory. | **Soft** | Inventory emits signal payloads in neutral form (StringNames for IDs; human text is looked up by HUD Core). Localization is a rendering concern, not a state concern. Localization Scaffold has no Inventory-specific requirement beyond string-table registration. |
| **Level Streaming** (#9) | Approved | Triggers `Events.section_entered` / `section_exited` which Save/Load consumes to invoke Inventory's registered restore callback. No direct subscription from Inventory to LS events — all LS coupling is mediated by Save/Load. | **Soft (mediated)** | LS does not know about Inventory; Inventory does not subscribe to LS signals. Both systems interact through Save/Load + `register_restore_callback`. |
| **Architecture / ADRs** | See ADR row below | — | **Hard** | See ADR table. |

### Architectural dependencies (ADRs)

| ADR | Status | What this GDD consumes | Notes |
|---|---|---|---|
| **ADR-0001** Stencil ID Contract | Proposed | Held-weapon / held-gadget meshes render at **Tier 1 Heaviest (4 px outline)** per ADR-0001 canonical table. WorldItem pickups (ammo drops, medkits, mission gadget) also render at Tier 1 so they stay legible on interior floors. FPS-hands exception (ADR-0005) does NOT extend to held objects — the held weapon/gadget IS outlined at Tier 1. | No amendments needed. |
| **ADR-0002** Signal Bus + Event Taxonomy | Proposed | 4 frozen Inventory signals + `weapon_fired` emit-site + subscriptions to `enemy_killed`, `guard_incapacitated`, `player_interacted`. | **Amendment required** (Coordination item #2): register `gadget_activation_rejected` + `weapon_dry_fire_click` + Inventory's `guard_incapacitated` subscriber row. |
| **ADR-0003** Save Format Contract | Proposed | `InventoryState extends Resource` schema per CR-11. `register_restore_callback` pattern per CR-11 (inherited from LS GDD CR-10). | No amendments needed. |
| **ADR-0004** UI Framework | Proposed | HUD Core consumes `project_theme.tres` + `FontRegistry` for rendering Inventory-emitted signal payloads. Inventory does NOT touch UI directly. | No amendments needed. |
| **ADR-0006** Collision Layer Contract | Proposed | `WorldItem` lives on `MASK_INTERACTABLES` (priority-2 raycast target). Parfum cone `get_overlapping_bodies()` reads `MASK_GUARDS`. Cigarette Case placement raycast reads `MASK_WORLD` for `placeable_surface` tag query. Dart gun projectile (Combat-owned) on `LAYER_PROJECTILES` — Inventory does NOT spawn dart colliders. | No amendments needed. |
| **ADR-0007** Autoload Load-Order Registry | Proposed (amended 2026-04-23) | **Inventory is NOT an autoload.** `InventorySystem extends Node` is a child of PC (architecture.md §3.3). The 7 autoload slots (1..6 + Combat at 7) are full post-amendment; Inventory does not claim a slot. | No amendments needed. |
| **ADR-0008** Performance Budget Distribution | Proposed | Inventory's per-frame cost falls under **Slot #8 (pooled residual, 0.8 ms)** — no `_process` / `_physics_process` ticking. All activity event-driven (fire input, pickup signal, swap animation, gadget activation). Worst-case one-shot costs estimated < 0.3 ms (see §C.5 performance table). | No amendments needed unless a future gadget introduces per-frame polling. |

### Forward dependents (systems that depend on Inventory)

| Dependent | Status | What Inventory provides | Forward contract |
|---|---|---|---|
| **Combat & Damage** (#11) | Approved | Weapon Resource schema (`base_damage`, `fire_rate_sec`, `magazine_size`, `damage_type_int`, `mesh`, `icon`, `fire_sound`, `reload_sound`, `reload_time_sec`, `pickup_drop_amount`, `pickup_max_reserve`, `hand_pose_marker_name`). Blade Resource: `base_damage = 100`, `damage_type_int = MELEE_BLADE`, `fire_rate_sec = 0.0`, no magazine/reserve. `weapon_fired` emit-site. `ammo_changed` emit-site. | Combat's AC-CD-12.1 (starting inventory) and AC-CD-12.2 (drop values) reference registry constants owned here. |
| **Mission & Level Scripting** (#13) | Not Started | Authors `WorldItem` placements (ammo caches, medkits, mission-gadget Parfum). Authors `peek_surface` and `placeable_surface` collision-shape tags for gadget gates. Sets `guard.carried_weapon_id: StringName` at guard-spawn time. Reads `InventoryState.mission_pickup_available` on section reload to suppress re-spawn (E.27, E.32). | **Forward contract lock**: Mission Scripting must not re-spawn the Parfum WorldItem when `InventoryState.mission_pickup_available == true`. See E.32 / E.33 for the re-spawn decision tree. |
| **Failure & Respawn** (#14) | Not Started | Calls `InventorySystem.restore_weapon_ammo(snapshot: InventoryState, floor: Dictionary, max_cap: Dictionary)` on respawn. Inventory implements (see F.2). | **Forward contract lock**: F&R owns `floor_applied_this_checkpoint: bool` flag (first-death-only floor). Floor dict: `{ &"silenced_pistol": 16, &"dart_gun": 8 }`. Max-cap dict: `{ &"silenced_pistol": 48, &"dart_gun": 24, &"rifle": 12 }`. |
| **HUD Core** (#16) | APPROVED 2026-04-26 | Subscribes to `ammo_changed`, `weapon_switched`, `gadget_equipped`. Per HUD Core REV-2026-04-26, also subscribes to `gadget_activation_rejected` (for 0.2 s desaturation per HUD CR-9) and does NOT subscribe to `weapon_dry_fire_click` (Audio-only); dry-fire detection via unchanged-value `ammo_changed` per HUD CR-8 (rate-gated at 3 Hz via dedicated `_dry_fire_timer`). HUD reads `WeaponResource.magazine_size`, current magazine, and reserve via Inventory API `get_ammo(weapon_id: StringName) -> Dictionary`. HUD reads `GadgetResource.icon: Texture2D` for gadget indicator. | **Forward contract lock**: HUD Core must update in-place on rapid successive `gadget_equipped` emits (E.47 — spam gadget_next case). |
| **Audio** (#3) | Approved | Subscribes to `weapon_fired(weapon, position, direction)`, `gadget_used(id, position)`. When Coordination item #2 lands: also subscribes to `weapon_dry_fire_click(weapon_id)`. Audio reads `WeaponResource.fire_sound` + `WeaponResource.reload_sound` + `GadgetResource.activation_sound` via the signal payload's Resource reference. | **Forward contract lock**: Audio GDD already ships aligned on the `weapon_fired` + `gadget_used` contracts. Minor touch-up needed on ADR-0002 amendment landing. |
| **Settings & Accessibility** (#23) | Not Started | Future accessibility toggles: disable gamepad haptic on CR-4b affordance cue; add a non-diegetic "gadget ready" HUD glyph; enlarged pickup prompt. Inventory exposes these as opt-in behaviors. | **Forward contract lock**: Settings owns the toggles; Inventory reads them via Settings API (forward). MVP scope: haptic-only reject cue is accessibility-aware from day one (gamepad haptic is opt-out via Settings). |
| **Document Collection** (#17) | Not Started | No direct coupling. Competes at priority-2 `interact` raycast via PC's `InteractPriority.Kind` enum (DOCUMENT = 0, PICKUP = 2 — lower wins). If a document and a WorldItem overlap geometrically, DOCUMENT wins. | **Forward contract lock**: Mission Scripting authors placements such that documents and ammo pickups are not spatially coincident (authoring-time constraint, not a runtime conflict). |

### Forbidden dependencies (explicit non-deps)

These systems do NOT depend on each other; the boundary is grep-enforced per §C CR-17.

| Non-dep | Why explicit |
|---|---|
| **FootstepComponent** | Inventory MUST NOT subscribe to `player_footstep` (CR-17 grep rule). FootstepComponent owns noise accounting; Inventory has no noise-side concerns (the Cigarette Case emits its own NoiseEvent at `P_case`, not via FC). |
| **Civilian AI** (#15 MVP stub) | Civilians do NOT carry weapons, do NOT drop ammo on death (civilians shouldn't die in stealth-first play). Inventory has no civilian-side subscription. If a civilian is killed (edge case — friendly fire spray?), no WorldItem spawns (CR-7a row: `carried_weapon_id == none`). |
| **Outline Pipeline** (#4) / **Post-Process Stack** (#5) | Inventory does NOT touch rendering. Held-mesh outline tier is declared by ADR-0001 assignment on the mesh's StencilTier export; the pipeline renders it. No shader or post-process configuration lives here. |
| **Dialogue & Subtitles** (#18) | No gadget produces dialogue. Parfum's affordance cue is haptic + HUD only (no Eve-quip per Pillar-1 anti-pattern). Dialogue is triggered by guards reacting to Inventory-emitted signals (e.g., SAI reacts to Cigarette Case noise; Dialogue reacts to SAI state) — indirect, not a direct Inventory-Dialogue coupling. |

### Coordination items (producer-tracked — these are NOT blocking Inventory GDD sign-off, but must close before implementation)

These are cross-GDD / cross-ADR touch-ups triggered by this GDD landing. Producer assigns owners; resolution needed before or during Inventory's implementation sprint.

1. **SAI GDD §Dependencies row for Inventory**: Add Inventory as a subscriber to `Events.guard_incapacitated(guard)` (currently SAI lists the signal's emit-site but not all subscribers). Minor text edit; no contract change. Owner: producer → SAI GDD maintainer. Target: before Inventory sprint starts.

2. **ADR-0002 amendment** (bundled — REVISED 2026-04-24 after OQ-INV-1 Option B and other resolutions):
   - Register new signal `gadget_activation_rejected(gadget_id: StringName)` — CR-4b HUD icon desaturation cue
   - Register new signal `weapon_dry_fire_click(weapon_id: StringName)` — distinct from `weapon_fired`; Audio-only subscription
   - **Extend** `guard_incapacitated(guard: Node)` signature to `guard_incapacitated(guard: Node, cause: int)` where `cause: Combat.DamageType` — NEW 2026-04-24 per OQ-INV-1 resolution
   - Register Inventory as subscriber row for `Events.guard_incapacitated(guard, cause)` (mirrors coordination item #1; now with extended signature)
   - Register Inventory as subscriber row for `Events.enemy_killed(guard, killer)` — already likely listed, confirm
   - **Combat.DamageType enum addition**: new member `MELEE_PARFUM` — non-lethal per `is_lethal_damage_type()`. Combat GDD touch-up paired with this ADR amendment.
   - Target: 1 `/architecture-decision adr-0002-amendment` session; no new ADR, amends existing one. Owner: `technical-director` + `lead-programmer` per ADR routing.

3. **Registry updates (Phase 5b)** — this session will handle on Inventory GDD approval:
   - `guard_drop_pistol_rounds`: **8 → 3** — APPLIED 2026-04-23 in registry sweep (was stale since Combat's 2026-04-22 revision; flagged by both §D specialists 2026-04-23)
   - `rifle_max_reserve`: **NEW** entry, value 12, safe range [9, 18], source `design/gdd/inventory-gadgets.md`, referenced_by [combat-damage.md, failure-respawn.md]
   - `medkit_heal_amount`: **NEW** entry, value 40 HP, safe range [25, 60], source this GDD, referenced_by [combat-damage.md if referenced there, failure-respawn.md]
   - `gadget_compact`, `gadget_cigarette_case`, `gadget_parfum`: **NEW** gadget entries with `gadget_id`, `pillar_served`, `slot_assignment`, `contextual_gate` attributes
   - `WorldItem`: **NEW** cross-system entity entry
   - **`guard_drop_dart_on_parfum_ko`: NEW 2026-04-24 entry**, value 0, LOCKED invariant, source this GDD, anti-farm invariant mirroring `guard_drop_dart_on_fist_ko`
   - **`compact_activation_noise_radius`: NEW 2026-04-24 entry**, value 3.0 m, safe range [2.0, 4.0], source this GDD (Compact peek cost per [game-designer R-2] resolution)
   - **`medkit_max_per_mission`: NEW 2026-04-24 entry**, value 3, safe range [2, 5], source this GDD (medkit economy ceiling per [economy-designer]), referenced_by [mission-level-scripting.md — placement authoring budget]

4. **HUD Core GDD forward-hook** (APPROVED 2026-04-26): HUD Core subscribes to the 4 Inventory signals listed above per HUD CR-1; tolerates rapid successive `gadget_equipped` emits per E.47 + HUD AC-HUD-5.6 (the desat timer simply restarts on each rejection — 10+ rapid rejects in one frame restart the timer; 10th call owns the 0.2 s window).

5. **Mission & Level Scripting GDD forward-hook** (Not Started) — REVISED 2026-04-24 per [economy-designer]: when MLS is authored, it must:
   - Author **~8 pickup caches** across 5 sections (REDUCED from 11 to prevent cap overflow) + **2 dart-only off-path caches** (S3 and S4 — force Pillar-2 observation moments). Updated distribution: S1: 1 pistol cache, S2: 1 pistol + 1 dart-only off-path, S3: 2 pistol + 1 dart-only off-path, S4: 2 pistol (no main-route — shifted to off-path gantry version per [economy-designer] Pillar-2 contingency), S5: 2 pistol
   - Author `peek_surface` collision-shape tags at ≥5 points per section (Compact usability)
   - Author `placeable_surface` tags at ≥3 points per section (Cigarette Case placement)
   - Author Parfum WorldItem placement in the restaurant level private dining room
   - Suppress Parfum respawn when `InventoryState.mission_pickup_available == true` (E.27, E.32, E.33)
   - Set `guard.carried_weapon_id: StringName` at each guard-spawn
   - **NEW 2026-04-24**: place **at most 3 medkits across the full mission** (economy budget: 3 × 40 HP = 120 HP healing vs ~90 HP Aggressive damage total; preserves Pillar-3 "material permission, not erasure"). Suggested distribution: S2: 1, S4: 1, S5: 1. Or 3 placed as mission-critical checkpoints only.
   - **NEW 2026-04-24**: cap rifle-carrying guards at **1 per section** to prevent the rifle self-sustaining economy flagged by [economy-designer]. Coord item adds rationale note for MLS authoring.

6. **Failure & Respawn GDD forward-hook** (Not Started): implement `floor_applied_this_checkpoint: bool` per-checkpoint flag; call `InventorySystem.restore_weapon_ammo(snapshot, floor, max_cap)` with empty floor dict on all non-first deaths.

7. **SAI GDD touch-up — BAIT_SOURCE NoiseEvent type (NEW 2026-04-24 per [systems-designer REC-1])**: SAI GDD F.2b EVENT_WEIGHT table must add a `BAIT_SOURCE` row (weight equivalent to Sprint-tier, ~3) so the Cigarette Case's per-physics-tick NoiseEvent (`type = BAIT_SOURCE, alert_cause = AlertCause.CURIOSITY_BAIT`) has a valid weight lookup. Without this, F.5's noise emission hits an undefined event type and SAI's perception computation fails silently. Owner: SAI GDD maintainer. Target: before Inventory sprint.

8. **Combat GDD touch-up — `apply_fire_path` method declaration (NEW 2026-04-24 per [gameplay-programmer Issue 3])**: Combat GDD §C must declare `apply_fire_path(weapon: WeaponResource, position: Vector3, direction: Vector3) -> void` as an explicit public method on CombatSystemNode. This method owns: hitscan/dart routing per Combat CR-5/CR-6, pre-fire occlusion check per Combat E.41, damage application per Combat F.1. Inventory CR-14 calls it; Inventory CR-17 forbids direct `apply_damage_to_actor` calls (routed through `apply_fire_path`). Owner: combat-damage.md maintainer. Target: before Inventory sprint. **BLOCKING** — Inventory cannot implement fire path without this method defined upstream.

9. **Input GDD touch-up — L91 single-dispatch clarification (NEW 2026-04-24 per [gameplay-programmer Issue 1])**: Input GDD L91 currently reads "handlers MUST mutex on `SAI.takedown_prompt_active()` ... both systems check their own gate." This contradicts Inventory CR-4's single-dispatch via Combat's handler. One-line amendment: "Dispatched by Combat's single `_unhandled_input` handler per Inventory CR-4; Inventory exposes `try_use_gadget()` as a public method and does not install a handler for this action." Owner: Input GDD maintainer. Target: before Inventory sprint.

10. **save-load.md touch-up — InventoryState schema (NEW 2026-04-24 per [systems-designer BLOCK-3, gameplay-programmer Issue 2])**: save-load.md line 102 currently says Inventory passes `ammo: Dictionary[StringName, int]` (single flat dict). The correct schema is two dicts (`ammo_magazine` + `ammo_reserve`) per CR-11. Update save-load.md row to reflect the split. Also: save-load.md should clarify that Inventory registers via `LevelStreamingService.register_restore_callback`, NOT `SaveLoad.*` (pattern owner is LS per LS CR-2). Owner: save-load.md maintainer. Target: before Inventory sprint.

11. **godot-specialist gate — SkeletonModifier3D IK scene-graph verification (NEW 2026-04-24 per [godot-specialist B-2])**: Verify whether a `SkeletonModifier3D` target NodePath can resolve across the Camera/body subtree boundary (HandAnchor is under Camera3D; player body Skeleton3D is in a different subtree). If not, the rifle IK target cannot reach `Marker3D` nodes inside the weapon's PackedScene. Escalation path: (a) world-space target propagation with manual `Transform3D` updates each frame, or (b) scope rifle IK out of MVP. Owner: godot-specialist + technical-director. Target: Technical Setup phase, before the rifle IK story is written.

12. **godot-specialist gate — Autoload `_unhandled_input` behavior (NEW 2026-04-24 per [godot-specialist XR-1])**: Combat is an autoload per ADR-0007. Combat CR-4's input-dispatch pattern assumes autoload `_unhandled_input` is called. Autoloads can implement `_unhandled_input`, but tree-order ordering with scene-node handlers is non-obvious. Verify against Godot 4.6 behavior that Combat's `_unhandled_input` receives `use_gadget`/`takedown` events AFTER GUI/scene-node consumption but reliably. If not, refactor Combat's input capture to `Input.is_action_just_pressed()` polling in `_physics_process`. Owner: godot-specialist. Target: before Inventory sprint.

13. **Playtest gate OQ-INV-2** (Pillar-2 felt-scarcity validation): see §Open Questions. Target resolution: Tier 0 vertical-slice playtest reports.

### Pre-implementation gates

Before the Inventory sprint can begin, these gates must close (REVISED 2026-04-24 post-`/design-review`):

| Gate | Owner | Current state |
|---|---|---|
| ADR-0002 amendment (Coord item #2 — bundled) | `technical-director` + `lead-programmer` | **CLOSED 2026-04-24** — `/architecture-decision adr-0002-amendment` session landed; 2 new Inventory signals + `guard_incapacitated` signature extension + `MELEE_PARFUM` enum addition applied to `docs/architecture/adr-0002-signal-bus-event-taxonomy.md`; registry `gameplay_event_dispatch.signal_signature` bumped to 38 signals |
| SAI GDD row touch-up (Coord item #1) | SAI GDD maintainer | **CLOSED 2026-04-24** — `guard_incapacitated(guard, cause: int)` emit-site extended to 2-param at L166 (step 5 note), L295 (UNCONSCIOUS transition row), L296 (DEAD transition row), L627 (E.16 signal interleaving), L680 (ADR-0002 amendment item now marked LANDED), and AC-SAI-3.3 signature assertion |
| SAI GDD BAIT_SOURCE EVENT_WEIGHT add (Coord item #7) | SAI GDD maintainer | **CLOSED 2026-04-24** — `BAIT_SOURCE` row added to F.2b EVENT_WEIGHT table with weight 1.0 (Sprint-tier); propagation suppression per F.4 `CURIOSITY_BAIT` documented in row notes |
| Combat GDD `apply_fire_path` method declaration (Coord item #8) | combat-damage.md maintainer | **CLOSED 2026-04-24** — new `CR-4b Public fire-path dispatch method` inserted before CR-5 declaring the public method signature + internal routing responsibilities (E.41 pre-fire check, CR-5 hitscan, CR-6 projectile, F.1 damage, CR-2 post-fire signals); `MELEE_PARFUM` added to DamageType enum, `is_lethal_damage_type` prose, `damage_type_to_death_cause` match block, CR-16 non-lethal list |
| Input GDD L91 single-dispatch clarification (Coord item #9) | Input GDD maintainer | **CLOSED 2026-04-24** — `use_gadget` row rewritten: "Dispatched by Combat's single `_unhandled_input` handler per Inventory CR-4; Inventory exposes `try_use_gadget()` as a public method and does NOT install its own `_unhandled_input` handler for this action" |
| save-load.md InventoryState schema touch-up (Coord item #10) | save-load.md maintainer | **CLOSED 2026-04-24** — Inventory row updated: two-dict schema (`ammo_magazine` + `ammo_reserve`) replacing single `ammo: Dictionary[StringName, int]`; untyped `Dictionary` with doc-comment typing clarified; `LevelStreamingService.register_restore_callback` registration path documented (not `SaveLoad.*`) |
| Registry updates (Coord item #3) | producer → this session Phase 5b | **PARTIALLY CLOSED 2026-04-24** — ADR-0002 amendment landed registry updates for `gameplay_event_dispatch` (38 signals) + new `guard_drop_dart_on_parfum_ko = 0 LOCKED` entity. Remaining items: `compact_activation_noise_radius = 3.0`, `medkit_max_per_mission = 3` entries (low priority, can land during sprint) |
| OQ-INV-1 Parfum-KO drop policy | user decision | **RESOLVED 2026-04-24 (Option B)** |
| OQ-INV-3 resolution (PC GDD `is_hand_busy()` clarification) | PC GDD maintainer | **OPEN** — E.4 |
| OQ-INV-4 resolution (Parfum cone nearest-guard sort) | Inventory implementation | **Deferred to sprint** — E.24; tiebreaker spec'd as `get_instance_id()` |
| godot-specialist IK scene-graph verification (Coord item #11) | godot-specialist + technical-director | **OPEN — NEW 2026-04-24** (rifle IK story blocked) |
| godot-specialist autoload `_unhandled_input` verification (Coord item #12) | godot-specialist | **OPEN — NEW 2026-04-24** |

**BLOCKING gates (must close before sprint starts)**: Coord items #2, #3, #7, #8, #9, #10 — **all CLOSED 2026-04-24** (#2 ADR-0002 amendment landed; #3 registry Phase 5b partially closed with remaining low-priority entries sprint-deferrable; #7 SAI BAIT_SOURCE row + `guard_incapacitated` 2-param extension landed; #8 Combat `apply_fire_path` method + `MELEE_PARFUM` enum landed; #9 Input GDD L91 single-dispatch language landed; #10 save-load.md two-dict InventoryState schema landed). Remaining pre-sprint engine-verification gates: **Coord item #11** can be narrowed to "rifle IK story only" if core inventory sprint proceeds without rifle. **Coord item #12** could gate all input work if autoload behavior breaks; verify before sprint day 1.

**Non-blocking for sprint start**: Coord items #1, #4, #5, #6 (HUD Core, MLS, F&R — those are forward-dep GDDs not yet authored); OQ-INV-3 blocks only E.4 (can ship Option B default — Inventory-internal SWITCHING gate — per that OQ's resolution note); OQ-INV-4 is sprint-deferred.

## Tuning Knobs

Designer-adjustable values. Each knob lists default, safe range, and failure modes at extremes. Registry-locked values are referenced by name (value lives in `design/registry/entities.yaml`); **Inventory-owned** values are new or locally-scoped. Ship-lock candidates are flagged; playtest-gated knobs are flagged.

### G.1 Ammo / pickup knobs

| Knob | Default | Safe range | At too-low | At too-high | Owner |
|---|---|---|---|---|---|
| `pistol_magazine_size` | 8 | [6, 12] | Reload thrash during Aggressive encounters | Reload never triggers; tension lost | **Registry-locked** (Combat source) |
| `pistol_starting_reserve` | 32 | [16, 48] | Aggressive dry by Section 3 | Aggressive never feels scarcity; Pillar 2 weakens | **Registry-locked** |
| `pistol_max_reserve` | 48 | [24, 64] | Pickup overflow on 2nd guard | Ammo hoarding, cap never binds | **Registry-locked** |
| `dart_magazine_size` | 4 | [3, 6] | Forces reload every guard | Each dart stops feeling precious | **Registry-locked** |
| `dart_starting_reserve` | 16 | [8, 24] | Ghost route dry by Section 2 | Dart scarcity disappears | **Registry-locked** |
| `dart_max_reserve` | 24 | [16, 32] | Cache overflow common | Hoarding | **Registry-locked** |
| `rifle_magazine_size` | 3 | [2, 5] | Never worth carrying | Rifle becomes daily driver | **Registry-locked** |
| `rifle_pickup_reserve` | 6 | [3, 9] | Rifle barely usable per pickup | Rifle becomes staple | **Registry-locked** |
| **`rifle_max_reserve`** | **12** | **[9, 18]** | **Rifle pickup after 2 collected is always wasted** | **Rifle becomes hoardable** | **Inventory-owned (NEW registry candidate — Phase 5b)** |
| `guard_drop_pistol_rounds` | **3** | [2, 5] | Aggressive softlocks by Section 3 | Aggressive ammo-positive, Pillar 2 collapses | **Registry-locked** (synced 2026-04-23 from prior stale 8 → 3) |
| `guard_drop_rifle_rounds` | 3 | [1, 5] | Rifle drop pointless | Rifle farmable | **Registry-locked** |
| `guard_drop_dart_on_dart_ko` | 1 | {1} **LOCKED** | N/A | Anti-farm breaks | **Registry-locked invariant** |
| `guard_drop_dart_on_fist_ko` | 0 | {0} **LOCKED** | N/A | Fist-farm re-opens | **Registry-locked invariant** |
| `respawn_floor_pistol_total` | 16 | [12, 24] | Softlock on genuinely-low state | Farm exploit risk (partially closed by first-death-per-checkpoint flag) | **Registry-locked** |
| `respawn_floor_dart_total` | 8 | [4, 12] | Ghost softlock post-death | Dart farm | **Registry-locked** |

### G.2 Medkit knobs

| Knob | Default | Safe range | At too-low | At too-high | Owner |
|---|---|---|---|---|---|
| **`medkit_heal_amount`** | **40 HP** | **[25, 60]** | **Below 25: medkit feels useless vs 18 dmg/pistol-hit (< 1.5 hits absorbed)** | **Above 60: fully resets from critical; Pillar-3 tension erodes** | **Inventory-owned (NEW registry candidate — Phase 5b)** |

Rationale: With `guard_pistol_damage_vs_eve = 18` and `player_max_health = 100`, default 40 HP absorbs ~2.2 guard-shots. A player at `player_critical_health_threshold = 25` heals to 65 — above critical, below full. Playtest-gated if Combat's damage values change.

### G.3 Gadget knobs

**Compact:**

| Knob | Default | Safe range | Failure modes | Owner |
|---|---|---|---|---|
| `compact_peek_range_m` | 1.5 | [1.0, 2.5] | Too low: peek_surface tags become impossible to find. Too high: peek through walls feels wall-hacky, Pillar 4 violation | Inventory-owned |
| `compact_peek_duration_sec` | 10.0 | [6.0, 15.0] | Too low: 4 s isn't enough to observe a patrol. Too high: defeats the "patient observer" tension | Inventory-owned |
| `compact_viewfinder_fov_deg` | 35.0 | [25, 50] | Too low: viewfinder is a pinhole. Too high: looks like a telescope cheat | Inventory-owned |
| **`compact_activation_noise_radius`** **(NEW 2026-04-24)** | **3.0 m** | **[2.0, 4.0]** | **Too low: peek is free perfect info in tagged rooms (the concern [game-designer R-2] raised). Too high: Compact is unusable near any guard — Pillar-3 risk-weight becomes a lock.** | **Inventory-owned** |

**Cigarette Case:**

| Knob | Default | Safe range | Failure modes | Owner |
|---|---|---|---|---|
| `case_placement_range_m` | 1.5 | [1.0, 2.5] | Too low: player must be glued to surfaces. Too high: Eve reaches through geometry | Inventory-owned |
| `case_retrieval_range_m` | 0.5 | [0.3, 1.0] | Too low: retrieval finicky. Too high: auto-retrieve while walking past | Inventory-owned |
| `case_noise_radius_m` | 8.0 | [6.0, 12.0] | Too low: guard must be next to case to hear. Too high: whole room alerts, violates "single guard distraction" design | Inventory-owned (aligned with SAI F.2 Sprint-tier) |
| `case_active_duration_sec` | 4.0 | [3.0, 6.0] | Too low: guard doesn't reach case before click stops. Too high: guard reaches case then waits awkwardly | Inventory-owned |

**Parfum Bottle:**

| Knob | Default | Safe range | Failure modes | Owner |
|---|---|---|---|---|
| `parfum_cone_range_m` | 1.5 | [1.0, 2.0] | Too low: must press against guard's face. Too high: ranged weapon; duplicates dart gun role | Inventory-owned |
| `parfum_cone_angle_deg` | 60 | [45, 75] | Too narrow: near-unusable; cone becomes a line. Too wide: multi-target AoE risk | Inventory-owned |
| `parfum_intake_window_sec` | 0.5 | [0.3, 1.0] | Too low: strict sync window, most sprays fail. Too high: guard can enter cone long after spray | Inventory-owned |

### G.4 Feedback / affordance knobs

| Knob | Default | Safe range | Failure modes | Owner |
|---|---|---|---|---|
| `haptic_reject_pulse_duration_ms` | 50 | [30, 100] | Too short: imperceptible. Too long: distracting buzz on every context-fail | Inventory-owned |
| `haptic_reject_pulse_intensity` | 0.3 (low) | [0.2, 0.5] | Too weak: feedback invisible. Too strong: exits "subtle cue" register | Inventory-owned |
| `hud_icon_desaturation_duration_sec` | 0.2 | [0.1, 0.5] | Too short: easy to miss. Too long: icon looks permanently broken on repeated fails | Inventory-owned |

**Accessibility coupling**: `haptic_reject_pulse_duration_ms` is opt-out via Settings → Accessibility → Haptic Feedback (forward-dep to Settings & Accessibility GDD).

### G.5 Timing knobs (cross-system, mostly reference-only)

| Knob | Default | Safe range | Failure modes | Owner |
|---|---|---|---|---|
| `weapon_switch_duration_sec` | 0.35 | Combat CR-16 locked | Too low: swap reads as instant teleport. Too high: loses Practiced Hands dignity | **Combat-locked** (see Combat §Tuning Knobs) |
| `weapon_switch_mesh_swap_point_sec` | 0.175 (= swap_duration / 2) | tied to weapon_switch_duration_sec | Must equal mid-animation nadir | Inventory-owned (derived) |
| `pickup_cap_excess_loss` | silent | {silent, partial_refund, partial_remainder} | Only "silent" is the intended ship mode | Inventory-owned (policy knob, not numeric) |

### G.6 Multi-drop geometry knobs (F.3-derived)

| Knob | Default | Safe range | Failure modes | Owner |
|---|---|---|---|---|
| `multi_drop_offset_radius_m` | 0.4 | [0.3, 0.7] | Too low: z-fighting possible. Too high: drops land beyond raycast range on tight-geometry ledges | Inventory-owned |
| `multi_drop_angle_increment_rad` | 2.3 | {~2.3, ~1.9, ~2.7} | Must be irrational w.r.t. 2π to avoid angle repeats within ~272 drops | Inventory-owned (mathematical constant) |

### G.7 Ship-lock candidates

The following knobs are **ship-locked** — they do NOT appear in the Settings menu (not player-adjustable) and should not be tuned post-release without a balance-patch cycle:

- All Pillar-2 anti-farm invariants: `guard_drop_dart_on_dart_ko = 1`, `guard_drop_dart_on_fist_ko = 0`
- Weapon switch duration (Combat-locked)
- `pickup_cap_excess_loss = silent` (policy)
- `multi_drop_angle_increment_rad = 2.3` (mathematical)
- `noise_global_multiplier` coupling for Cigarette Case (tied to PC GDD's `noise_global_multiplier` ship-lock per PC §G)

### G.8 Playtest-gated knobs

These require Tier 0 or Tier 1 playtest data before locking. Initial values shipped; refinement expected:

- `medkit_heal_amount` — validates Pillar-3 "material permission" tension (OQ-INV-2 related)
- `compact_peek_duration_sec` — validates observation-reward pacing
- `case_noise_radius_m` — validates single-guard distraction vs room-alert threshold
- `parfum_cone_range_m` + `parfum_cone_angle_deg` — validates "front-facing silent" feels like a distinct tool vs dart
- All pickup cache counts + cache yields (Mission Scripting owns; see §F Coordination item #5)

## Visual/Audio Requirements

### V.1 — Held-Weapon Mesh Specifications

All held weapons attach at `player.HandAnchor` per CR-10. All carry **Outline Tier 1 (4 px at 1080p)** per ADR-0001 and art bible §8C. No PBR maps; all surfaces use flat unlit color with hand-painted pattern per art bible Principle 1.

| Weapon | Period reference | Visual design | Poly budget | Texture |
|---|---|---|---|---|
| **Silenced Pistol** | Walther PPK + period suppressor (~70 mm threaded tube) | Matte Eiffel Grey `#6B7280`, subtle engraved BQA proof-mark on slide; two-tone body/suppressor | ~600 tris | 512×512, 1 slot |
| **Dart Gun** | CO₂-powered pen-style disguised pistol (slim, shorter than pistol) | Matte BQA-blue anodized `#1B3A6B`, brushed stripe decal on barrel band, embossed requisition stamp near grip well — reads as period German signal pistol, NOT sci-fi raygun | ~450 tris | 512×512, 1 slot |
| **Rifle** (pickup-only) | Lee-Enfield No.4 or period semi-auto | Dark walnut stock `#5C3D2E`, Eiffel Grey blued steel, PHANTOM Red stencil mark on receiver; **only two-handed IK weapon — requires named `Marker3D` nodes for `LeftHandIK`/`RightHandIK`** per CR-10 | ~800 tris | 512×512 × 2 slots (wood + metal) |
| **Takedown Blade** | Folding stiletto, Italian-influenced | Matte near-black `#1A1A1A` chequered grip wrap, Eiffel Grey flat-polished blade (~85 mm). No ornament — utility over threat theater | ~350 tris | 512×512, 1 slot |
| **Fists** | — (no held mesh) | FPS hands (ADR-0005 2,000-tri budget already allocated); bare-hand idle animation without HandAnchor attachment | — | — |

### V.2 — Gadget Mesh Specifications

Per CR-5b gadgets have no persistent held mesh; meshes instantiate only during activation via `GadgetResource.mesh: PackedScene` and free on deactivation. All Tier 1 outline while visible.

**Gadget 1 — The Compact.** In-hand activation: flat gunmetal rectangle ~60×45 mm, gunmetal base `#6B7280` with BQA-blue enamel inset on lid face `#1B3A6B` (geometric diamond ~20×15 mm). Lid renders at ~30° open showing fiber-optic aperture (small dark circle with single white-pixel lens highlight). Cover identity: the lid interior has a shallow flat off-white `#F2E8C8` faux-mirror panel — anyone sees cosmetics, not electronics. Poly: ~300 tris (lid ~120, body ~120, hinge ~60). 512×512, 1 slot. Tier 1.

**Gadget 2 — The Cigarette Case.** In-hand during placement gesture + same mesh as placed WorldItem: slim silver rectangle ~95×60×10 mm, monogram "E.S." engraved on face (flat near-black line achieved via texture decal, not geometry). Six Sobranie cigarettes visible through open lid: flat cream-yellow atlas face, no volumetric geometry. Period clasp bar-latch (~5 tris) sells 1965 authenticity. Poly: ~280 tris. 512×512, 1 slot. Tier 1 in-hand AND while placed.

**Gadget 3 — The Parfum Bottle.** In-hand activation: cobalt glass body `#1B4F7A` (slightly more vivid than BQA Blue — reads glass-colored, not faction-colored), gold Paris Amber `#E8A020` atomizer bulb (period teardrop), front label "Nuit de PHANTOM — Eau de Parfum, 15 ml" in Futura Condensed Parchment on near-black label field (~18×12 mm flat decal, no embossing geometry). PHANTOM branding IS the joke — BQA dead-drop note in WorldItem pickup explains. Poly: ~350 tris. 512×512, 1 slot. Tier 1.

### V.3 — WorldItem Pickup Mesh Specifications

All WorldItem pickups render at **Tier 1 (4 px)** while unacquired; outline disappears with mesh on `queue_free()`.

| WorldItem | Design | Poly |
|---|---|---|
| Pistol/Dart ammo drop | Period cardboard ammo box (~60×35×20 mm), Parchment `#F2E8C8` base, PHANTOM Red stencil label "CAL. 7.65" or "TRANQ. SERIES A"; lid slightly ajar; 3 loose rounds fanned beside (reinforces felt-scarcity) | ~180 tris |
| Rifle ammo drop | Period stripper clip of 3 rounds in Parchment paper sleeve, Eiffel Grey clip, "7.62 MATCH" Parchment label band (~55×18 mm) | ~140 tris |
| Medkit field kit | Dark brown `#3D2B1F` leather strap-and-buckle chassis (~120×80×35 mm), flat white cross on face in Parchment, period-accurate buckle clasp geometry, BQA requisition stamp on side face "MED/4A" | ~220 tris, 2 material slots (leather + cross) |
| Mission-gadget satchel (Parfum dead-drop) | Small canvas satchel (~150×100×60 mm), Eiffel Grey canvas, BQA Blue enamel-pin badge on flap (~8 mm), flap slightly open with folded note visible — "Operative Whitmore" in American Typewriter visible on note. Parfum bottle NOT visible inside at WorldItem stage — value signaled by BQA pin + outline weight | ~280 tris |

### V.4 — VFX Requirements

**Compact — Fiber-Optic Viewfinder Overlay.** Implementation: `CanvasLayer`-based screen-space overlay (NOT `CompositorEffect` — scope disproportionate for 10 s gadget). `TextureRect` covers full viewport with vignette mask (heavy circular black vignette converging to ~35% viewport-width clear aperture). Inside aperture: gameplay view visible. Thin period-camera reticle in Parchment (~1 px stroke) inscribes aperture edge. Fade-in/out over 6 frames (0.1 s). **No chromatic aberration, no scanlines** — clean analog lens aesthetic, not surveillance digital noise.

**Cigarette Case — Clockwork Click.** NO visual FX on case during 4 s active sequence. Case sits inert; distraction is entirely acoustic + SAI-side. Deliberate: adding visual "sound ripple" would telegraph the effect and undercut deadpan register. The comedy is that a box sits there and a guard walks toward it.

**Parfum — Sedative Aerosol Cone.** `GPUParticles3D` node parented to atomizer `Marker3D`. Forward cone ~25° half-angle, 1.5 m max range. Style: small billboarded quads, flat cobalt→translucent-white gradient (ramp: `#1B4F7A` at 80% alpha → `#FFFFFF` at 0% alpha), slight upward drift (gravity −0.2 m/s). 40–60 particles, 0.1–0.15 m billboard. No physics interaction with geometry (1.5 m range short enough that clipping is rare/acceptable). Duration: 0.3 s active + 0.2 s fade. "Period magazine illustration of a perfume spray," not fluid sim. VFX node owned by gadget behavior scene; `queue_free()` on animation completion.

**Weapon Fire / Muzzle Flash / Dart Projectile / Tracers.** Combat owns all per §C.5 contract. Inventory's held-mesh involvement is limited to recoil pose (V.5).

**Weapon Switch.** NO VFX. 0.35 s holster-draw blend is pure diegetic hand motion — no flash, no trail, no flourish. Mesh-swap at t=0.175 s is direct instantiate/free; no transition effect.

### V.5 — Animation Requirements (Inventory Scope Only)

Inventory does not own the full animation system; specifies trigger points + timing contracts only.

- **Weapon switch** (CR-3): Holster-down 0 → 0.175 s (weapon lowers inward toward hip). Mesh swap at t=0.175 s. Draw-up 0.175 → 0.35 s. Reads as "holster, take, raise" — habitual, no drama. Animation implements; Inventory owns the non-cancellable 0.35 s timing contract.
- **Compact**: lid-flip-open ~6 frames, held steady for viewfinder duration, closes in ~6 frames on deactivation. Minimal wrist movement.
- **Cigarette Case**: flip-open + lower-to-surface two-beat gesture. Beat 1 (~8 frames): lid flips open. Beat 2 (~12 frames): hand lowers to authored surface, case placed, hand withdraws. Total ~0.33 s.
- **Parfum**: atomizer-pump press — right hand raises bottle, single-hand bulb press. ~10 frame press-and-release accompanied by V.4 VFX cone.
- **Fire / Reload**: Combat-referenced. Inventory's sole visual role at fire: brief recoil pose (snap-back for pistol/dart, bolt-cycle gesture for rifle) driven by Animation subscribing to `weapon_fired`.
- **Pickup**: reach-and-pocket wrist rotation (~8 frames), PC-owned, triggered on `Events.player_interacted`. Inventory references as visual contract but does not own.

### V.6 — Typography + Iconography (BQA memo voice)

- **GadgetResource.description / WeaponResource.description**: **American Typewriter** (ITC; fallback Courier Prime), 16 px body. Per art bible §7B and §8C. The BQA clerical register (dry, procedural, departmentally passive-aggressive) is carried by this typeface. The humor is the gap between the typeface's bureaucratic formality and the object it describes.
- **Gadget HUD icon** (forward-dep to HUD Core): flat 2-color silhouette at 56×56 px. BQA Blue tint on lighter BQA tint field; NO outline on the icon (silhouette IS the icon per art bible §7C). Requisition number overlay in lower-left in American Typewriter at ~7 px — below legibility floor, intentionally micro-text as texture/register reinforcement. Cigarette Case icon carries noise-level glyph (3 concentric arcs, Parchment) in upper-right per art bible §7A (noisy gadget); Compact + Parfum carry no glyph (both silent on Eve's end).
- **HUD palette for Inventory UI elements** (consistent with art bible §4.4, no new colors introduced):
  - Gadget icon field: BQA Blue `#1B3A6B` at 85% opacity
  - Icon tint: `#2A4F8A` (slightly lighter BQA)
  - Requisition micro-text: Parchment `#F2E8C8`
  - Ammo numerals: Parchment `#F2E8C8` (standard); Alarm Orange `#E85D2A` when reserve = 0 (critical ammo state — same semantics as critical health)
  - Gadget rejection cue (CR-4b): icon desaturates for 0.2 s via tint shift toward Eiffel Grey `#6B7280`
  - Parfum icon tint: PHANTOM Red `#C8102E` per art bible §4.2 "captured enemy equipment" semantic (gadget originated from PHANTOM's own supply chain). *Alternate treatment: BQA Blue (unified faction indication — Bureau endorsed the gadget). **Resolved 2026-04-23 by author: PHANTOM Red** — it's the joke, the visual register, and the §Player Fantasy anchor.*

### V.7 — Outline Tier Verification Table

| Asset | Tier | Weight (1080p) | Source Rule |
|---|---|---|---|
| Held weapons (4, in HandAnchor) | **1 — Heaviest** | 4 px | CR-10 Step 5; ADR-0001; art bible §8C |
| Held gadget meshes (Compact/Case/Parfum in-hand during activation) | **1** | 4 px | ADR-0001; FPS-hands exception (ADR-0005) does NOT extend to held objects |
| Placed Cigarette Case (WorldItem on surface) | **1** | 4 px | Art bible §8C; ADR-0001 |
| WorldItem ammo drops + medkit + mission satchel | **1** | 4 px | ADR-0001; §8C — key interactive objects receive heaviest outline |
| PHANTOM guards | 2 — Medium | 2.5 px | Art bible §8C |
| Environment geometry | 3 — Light | 1.5 px | Art bible §8C |
| FPS player hands (Eve, no weapon) | None | — | ADR-0005 exception |

### V.8 — Outline Pipeline Concern Flags

Forward to `godot-shader-specialist` (outline shader owner) for verification before implementation:

- **W-OUTLINE-1** — Held mesh viewport-edge clipping. When Eve aims toward a corner and suppressor/blade tip exits viewport, Tier 1 outline clipping at viewport boundary may read as broken. Verify if stencil pass handles gracefully or requires 20–30 px inset margin on Tier 1 FPS-object outline pass.
- **W-OUTLINE-2** — WorldItem outline when occluded by geometry. Should Tier 1 outline remain visible x-ray-style (aids discovery, Pillar 5 violation) or hide with mesh (Pillar 2 — observation-rewarding). **Recommended: outlines hide with mesh** (standard stencil behavior). Confirm stencil pass doesn't inadvertently produce x-ray behavior for Tier 1 occluded objects.
- **W-OUTLINE-3** — Placed Cigarette Case double-outline risk during placement. If behavior scene instantiates placed mesh before freeing in-hand mesh (even 1 frame), same asset carries two stencil writes. Verify placement gesture completes in-hand `queue_free()` before surface-placed instance is added to tree.

📌 **Asset Spec** — Visual requirements defined. After art bible is confirmed, run `/asset-spec system:inventory-gadgets` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

---

### A.1 — Weapon SFX (positional, `Events.weapon_fired` subscribe; SFX bus)

All weapon SFX are positional: Audio subscribes to `Events.weapon_fired(weapon, position, direction)` and routes to a pooled `AudioStreamPlayer3D` at `position`, with the current section's `AudioEffectReverb` preset.

**Silenced pistol**: fire = suppressed mechanical pop (no ballistic bang, ~110 dB suppressed-equivalent close-mic clack + brief pressure tail); slide-rack on reload (~180 ms metal ratchet); mag-out (~60 ms polymer-on-metal click); mag-in (~80 ms metallic seating + spring settle); casing drop (deferred ~350 ms after fire, light brass clink 1–2 bounces); dry-fire click (≤150 ms hammer-click).

**Dart gun**: fire = compressed-air puff (~80 ms muffled pneumatic exhale, no bang, identifiably mechanical but quiet); CO₂ swap on reload (~100 ms metallic unseat + brief hiss + re-seat click); dry-fire click (≤150 ms hollow empty-pneumatic click — distinct from pistol's hammer-click).

**Rifle**: fire = period bolt-action single shot WITH full diegetic bang (loud low crack — Combat context is already escalated when rifle appears; this is the one weapon where the report is the point); bolt cycle on reload (~350 ms rack-back + forward slam); casing ping (deferred ~200 ms, bright brass-on-metal ~120 ms); dry-fire (≤150 ms bolt-lock thud — bolt hitting empty-chamber stop, distinct from pistol + dart).

**Takedown blade**: unsheathe on `weapon_switched` to blade (~100 ms steel-on-leather draw, plays immediately on signal receipt since visual occurred at midpoint). Impact: Combat-owned (via `takedown_performed`).

**Fists**: equip on `weapon_switched` to fists (~150 ms cloth-rustle + glove-settle, close-mic). Impact: Combat-owned.

**Weapon switch SFX (Inventory-owned, all weapons, non-spatial `SFX` bus)**: three-part cue during the 0.35 s switch — (1) holster-thud at ~0.175 s (dull weight-thud seating at hip), (2) draw-snap at t=0.35 s (short leather-and-metal snap), (3) light leather-rustle + metal-on-metal layer beneath both accompanying mesh-swap point. Total ≤0.35 s.

### A.2 — Gadget SFX (`Events.gadget_used` subscribe)

Audio reads `GadgetResource.activation_sound: AudioStream` from signal payload. Compact + Parfum: close-mic non-spatial. Cigarette Case ticking: **positional at P_case** (`AudioStreamPlayer3D`, `SFX` bus) — world sound that SAI's `HearingPoller` also reads.

**Compact**: lid click-open (~80 ms metal snap on activation), mechanical whirr (~200 ms fiber-optic lens extension starting ~80 ms post-lid), click-close on cancel/re-press/timer-expiry.

**Cigarette Case**: flip-open (~80 ms metal lid click, close-mic Eve's hand), place-on-surface (~50 ms dampened tap), **4-second clockwork ticking loop at P_case** (world-positioned `AudioStreamPlayer3D`; period clockwork register — mechanical, rhythmic, slightly irregular, NOT a metronome; seamless loop at 4 s boundary; audible at `case_noise_radius_m = 8 m`). Retrieve pick-up: ~200 ms case-close + Sobranie cigarette rustle.

**Parfum**: atomizer pump (~80 ms rubber-bulb squeeze), aerosol hiss (~150 ms soft pressurized-liquid mist ~80 ms post-pump), guard-incap: Combat/SAI-owned.

### A.3 — Dry-fire + affordance cues

**`weapon_dry_fire_click(weapon_id: StringName)`** — candidate ADR-0002 amendment (Coordination item #2). Audio subscribes; HUD does not. No haptic (haptic reserved for gadget-activation-rejected per CR-4b). Three distinct clicks ≤150 ms close-mic:
- Pistol: sharp high-register hammer-click (firing pin on empty chamber)
- Dart gun: hollow click with no air release (pneumatic cycling on no charge)
- Rifle: dull short bolt-lock thud (bolt on empty-chamber stop)

**`gadget_activation_rejected(gadget_id: StringName)`** — **NO audio** per CR-4b. Stealth-safe by design. HUD desaturation + gamepad haptic only. Audio does NOT subscribe to this signal. Do not add SFX under any circumstance.

### A.4 — Pickup SFX (subscribe to `Events.player_interacted` via Audio's existing handler; SFX bus, close-mic non-spatial)

Forward-dep: Audio GDD's `_on_player_interacted` handler routes by `target.item_id` when `target is WorldItem`.

- Ammo pickup (`"pistol_ammo"` / `"dart_ammo"` / `"rifle_ammo"`): ~200 ms cloth-swish + metal-clink (fabric rustle + rounds sliding into pouch)
- Medkit (`"medkit"`): ~250 ms leather-case buckle snap + bandage-cloth rustle
- Mission gadget (`"gadget_mission_pickup"`): ~300 ms canvas-satchel rustle + dead-drop note paper shuffle (period dead-drop register — unhurried, deliberate)
- Pickup prompt appear/dismiss: **no audio** (UI-silent per Pillar 5)

### A.5 — Signal emit-subscribe contract

Inventory emits; Audio subscribes:

| Signal | Handler | Routing |
|---|---|---|
| `weapon_fired(weapon, position, direction)` | `_on_weapon_fired` | Pooled 3D at `position` |
| `gadget_used(id, position)` | `_on_gadget_used` | Close-mic non-3D for Compact + Parfum; positional 3D at `position` for Cigarette Case ticking |
| `weapon_dry_fire_click(weapon_id)` | `_on_weapon_dry_fire_click` | Close-mic non-3D at Eve's position |

`weapon_dry_fire_click` handler is gated on the ADR-0002 amendment (Coordination item #2).

### A.6 — Mix + mastering

| Category | Bus | Spatialization | Level |
|---|---|---|---|
| Weapon fire (pistol / dart / rifle) | SFX | Pooled `AudioStreamPlayer3D` at muzzle | Center-stage; pistol is dominant close-field |
| Weapon switch / reload | SFX | Non-spatial | Close-field; below fire |
| Gadget SFX (Compact / Parfum) | SFX | Non-spatial | Close-mic; intimate, not room-filling |
| **Cigarette Case ticking** | SFX | `AudioStreamPlayer3D` at P_case; inverse-distance | World-present; attenuation MUST match `case_noise_radius_m = 8 m` so audible-to-player distance ≈ SAI-perception radius |
| Dry-fire click | SFX | Non-spatial | Very close-mic; ≤150 ms; cuts through any music state |
| Pickup SFX | SFX | Non-spatial | Close-mic; brief; below weapon SFX |

**Critical contract**: Cigarette Case ticking attenuation curve MUST match SAI's `case_noise_radius_m = 8 m` so the audible range for the player and the perception radius for guards coincide — a player who cannot hear the clicks can infer that a guard at that range cannot hear them either. This is the audio-gameplay legibility contract.

### A.7 — Audio pre-implementation gates

| Gate | Dependency | State |
|---|---|---|
| `weapon_dry_fire_click` signal registration | ADR-0002 amendment (Coord item #2) | **OPEN** — Audio handler blocked until signal is on bus |
| Cigarette Case ticking noise-event spec | F.5 SAI integration | **CONFIRMED** — no additional gate |

## UI Requirements

Ownership split: **Inventory & Gadgets provides signals + state; HUD Core GDD owns widget rendering.** This section specifies intent + requirements; implementation contracts live in HUD Core GDD and (once authored) `design/ux/inventory-screen.md` + `design/ux/hud-ammo-gadget.md`.

### UI-1 — Inventory Screen (Pause-Accessible)

**Access model.** Accessible only while paused; never during active gameplay (Pillar 5 — no time-dilation, no mid-action menus). Opening: `I` key (keyboard) or equivalent pause-then-tab gesture. Closing: `Esc` / `B/Circle` per ADR-0004 modal dismiss. The `PAUSE` InputContext (ADR-0004) must be active before the inventory screen is shown. The inventory screen itself pushes no additional InputContext mode — it lives within PAUSE. *(Alternative: dedicated `INVENTORY_SCREEN` enum entry — single-line ADR-0004 addition; deferred to UX spec authoring when/if needed.)*

**InputContext capture while open.** `weapon_slot_N`, `gadget_next`, `gadget_prev`, `fire_primary`, `use_gadget`, `interact` are no-ops while the screen is open — no state mutation, no signal emissions. Scroll + directional inputs navigate on-screen display only (display-preview, read-only). Enforced by the PAUSE gate; the inventory screen MUST NOT install a separate input handler that bypasses PAUSE.

**Layout intent.** The screen presents a **pre-packed handbag**, not a loot grid. Intended composition: Saul-Bass-influenced flat contents-of-handbag illustration plane with items labeled rather than stacked. Empty slots (rifle not yet acquired) render a discreet dashed-outline silhouette — no "?" or "LOCKED" chrome. **No drag-and-drop, no sorting, no favorites, no multi-page** at MVP.

**Element list** (complete for MVP):

| Category | Elements |
|---|---|
| Weapons (4 rows) | Weapon icon + slot number + display name in Futura + current magazine + reserve in DIN |
| Gadgets (2 pre-packed + 1 conditional) | Gadget BQA silhouette icon + requisition number + display name in DIN + **BQA memo description text in American Typewriter below** |
| Medkit | Medkit icon + "×N" count (×0 at mission start) |
| Ammo breakdown | Per-weapon: magazine / reserve for pistol + dart + rifle |

The BQA memo text (`GadgetResource.description`) renders in American Typewriter — **this is the only place in the game the full memo appears.** The typographic comedy lives here, not in HUD overlays.

**Display-only contract.** Eve's bag was packed by the Bureau. Player reads; they do not rearrange.

### UI-2 — In-Game HUD: Gadget Indicator (HUD Core renders)

**Position.** Bottom-right corner (NOLF1 grammar). Screen-edge anchor, consistent margin (art bible §3.3 — no center-screen permanent chrome). Solid BQA Blue `#1B3A6B` field strip at 85% opacity, hard-edged, no gradient (art bible §4.4).

**Content.**
- Gadget icon: flat BQA-blue silhouette `#1B3A6B` on lighter BQA tint `#2A4F8A`. One-color flat; NO gradient. **Parfum-specific tint: PHANTOM Red `#C8102E`** per art bible §4.2 semantic vocabulary (captured enemy equipment).
- Requisition number (DIN, small, beneath icon): e.g., `KL/031/C`.
- Display name (DIN, Parchment `#F2E8C8`).

**States.**

| State | Visual |
|---|---|
| Idle (equipped, ready) | Normal BQA Blue, normal opacity |
| Active (Compact viewfinder / Case placed) | Subtle highlight — icon brightens to `#2A4F8A`. NO animation, NO pulse (Pillar 1: no winking icons) |
| Rejected (CR-4b gate fail) | Desaturates to near-greyscale for **0.2 s**. No audio. No modal text |
| Mid-rotation (`gadget_next/prev` in flight) | Cross-fade old → new icon ≤ **100 ms** to support rapid rotation (E.47). Driven by `gadget_equipped` signal |

**Rotation hint.** Minimal pair of navigation glyphs (small arrows or period tick marks) flanking icon — present only when cycle length > 1. Same scale/weight as requisition number; NOT tutorial chrome. Appear/disappear when cycle length changes (Parfum pickup emits `gadget_equipped` re-emit per CR-13 step 4).

**HUD Core subscriptions.** `Events.gadget_equipped(id)` → redraw with cross-fade. `Events.gadget_activation_rejected` (ADR-0002 amendment pending — §F Coord item) → trigger 0.2 s desaturation.

### UI-3 — In-Game HUD: Ammo Indicator (HUD Core renders)

**Position.** Bottom-left corner (opposite to gadget indicator — NOLF1 grammar). BQA Blue field strip, same spec as UI-2.

**Content.** Current weapon icon + magazine + reserve. **Typography: American Typewriter for numeric readout** (period printed-figures feel). Format: `8 / 32` (magazine / reserve). Three-digit space for each.

**States.**

| State | Trigger | Visual |
|---|---|---|
| Normal | Reserve > magazine size | Parchment `#F2E8C8` |
| Low | Reserve ≤ magazine size | Reserve numeral shifts Alarm Orange `#E85D2A`. NOT color-only — also numerically readable (colorblind-safe, art bible §4.5) |
| Empty magazine | Magazine == 0 on `fire_primary` | Magazine numeral flashes Alarm Orange for **50 ms**. Weapon icon + reserve do NOT flash |

**Special cases.**

| Weapon | Display |
|---|---|
| Takedown blade (Slot 4) | `∞` in American Typewriter (per Combat §V) |
| Fists (Slot 5) | Ammo widget hides entirely — no "0 / 0" chrome |
| Rifle not acquired | Slot 3 icon = dashed silhouette, no numeral |

**HUD Core subscriptions.** `Events.ammo_changed` → redraw numerals. `Events.weapon_switched` → redraw icon + ammo for new weapon (special-case blade / fists).

### UI-4 — Pickup Prompts (HUD Core renders; Inventory-authored text)

**Gate.** Prompt appears only when PC's interact raycast resolves a `WorldItem` target AND `is_hand_busy() == false`. PC owns raycast; HUD Core subscribes to `player_interacted` + monitors `is_hand_busy()`.

**Text** (short, dry, period register, max 4 words — Pillar 1). DIN body, small.

| WorldItem | Prompt |
|---|---|
| Pistol / dart / rifle ammo | "Pocket ammo" |
| Medkit | "Pocket medkit" |
| Mission gadget (Parfum satchel) | "Pocket device" |
| BQA dead-drop note | "Read note" |

**No "Press E to …" prefix. No button-icon chrome.** Verb + object is the prompt. Position: center-screen-lower, above interact icon (PC owns positioning).

### UI-5 — Dry-Fire + Dry-Select Feedback

**Dry-fire (magazine empty + fire pressed).** Audio: `weapon_dry_fire_click(weapon_id)` (Audio-owned). Visual: magazine numeral flashes Alarm Orange for **50 ms**. Only the numeral — NOT weapon icon, NOT reserve, NOT screen overlay. **No modal text** ("Out of ammo!" pop-up = Pillar 5 violation).

**Rifle slot dry-select (CR-1 E.9).** Audio: `weapon_dry_fire_click(&"rifle")`. Visual: dashed rifle silhouette flashes Alarm Orange for **50 ms**. No modal.

### UI-6 — Gadget Activation Rejection (CR-4b)

- Haptic: 50 ms low-intensity pulse (`haptic_reject_pulse_intensity = 0.3`) on gamepad only. Opt-out via Settings → Accessibility → Haptic Feedback. **[FORWARD-DEP: Settings & Accessibility GDD]**
- Visual: gadget HUD icon desaturates for 0.2 s (UI-2 Rejected state).
- **No audio** (explicit Pillar 3 — stealth-safe).
- **No modal text**.

### UI-7 — Accessibility Requirements

| Requirement | Detail | Forward-dep |
|---|---|---|
| Haptic feedback toggle | UI-6 rejection haptic opt-out ON/OFF | **[FORWARD-DEP: Settings & Accessibility — "Haptic Feedback" toggle]** |
| Non-diegetic "gadget ready" glyph | Opt-in always-on HUD glyph (small checkmark or period tick beside gadget indicator) showing "contextual gate: OPEN." Off by default | **[FORWARD-DEP: Settings & Accessibility — "Gadget Ready Indicator" toggle]** |
| Colorblind-safe ammo states | Alarm Orange (UI-3) always paired with numeric value. No state conveyed by color alone | Structural — no toggle |
| Text scaling | All HUD text respects ADR-0004 Theme font scaling. Inventory screen memo text must remain legible at minimum supported scale | ADR-0004 mandates |
| Screen reader — HUD elements | Each persistent HUD element carries semantic label: gadget indicator `"Device: [display_name]"`; ammo `"[weapon_name]: [magazine] in magazine, [reserve] in reserve"`; blade `"Takedown blade: unlimited"`; fists `"Fists: equipped"` | **[FORWARD-DEP: ADR-0004 Gate 1 — Godot 4.6 accessibility_ property names; HUD Core implements]** |
| No color-only faction signal | BQA Blue vs Alarm Orange each paired with shape/position cues per art bible §4.5 | Structural |
| No flashing > 3 Hz | 50 ms flashes in UI-5 are single-pulse, NOT sustained cycling | Structural |

### UI-8 — InputContext Coupling (ADR-0004)

While inventory screen is open (PAUSE context): `GAMEPLAY` InputContext is paused. `weapon_slot_N`, `scroll`, `gadget_next/prev` route to display-preview navigation only — no state mutation, no Inventory signal emissions. `fire_primary`, `use_gadget`, `interact` are no-ops. Modal dismiss (`Esc` / `B/Circle`) closes inventory + pops PAUSE per ADR-0004 rule 4.

Future dedicated `INVENTORY_SCREEN` InputContext enum entry = single-line ADR-0004 addition; low risk, low cost; deferred to UX spec authoring.

### UI-9 — Forward-Dep Summary

**[FORWARD-DEP: Settings & Accessibility GDD]** — 3 contracts needed:
1. **Haptic Feedback** toggle — opt-out ON/OFF for UI-6 rejection pulse
2. **Gadget Ready Indicator** toggle — opt-in non-diegetic HUD glyph for players who cannot rely on haptic
3. **Screen reader semantic labels** — HUD Core implements on all persistent HUD elements (requires ADR-0004 Gate 1 accessibility verification)

**[FORWARD-DEP: HUD Core GDD]** — HUD Core must implement UI-2, UI-3, UI-4, UI-5, UI-6 rendering behaviors. This GDD specs intent + signal contracts; HUD Core owns widget scenes, Theme inheritance, CanvasLayer assignment. Stories referencing HUD rendering of inventory state should cite HUD Core GDD + `design/ux/hud-ammo-gadget.md` (once authored), NOT this GDD directly.

**[SIGNAL BUS COORDINATION: ADR-0002 amendment candidates]**:
- `gadget_activation_rejected(gadget_id: StringName)` — required for UI-2 Rejected state + UI-6 haptic trigger
- `weapon_dry_fire_click(weapon_id: StringName)` — required for UI-3 Empty state + UI-5 audio

Both flagged in §F.5 Coordination items. UX confirms they are load-bearing for HUD Core + Audio. ADR-0002 amendment must land before HUD Core GDD authoring begins.

📌 **UX Flag — Inventory & Gadgets**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the Inventory Screen (pause-accessible) and HUD gadget/ammo indicators **before** writing epics. Stories that reference UI should cite `design/ux/inventory-screen.md` and `design/ux/hud-ammo-gadget.md`, not this GDD directly.

## Acceptance Criteria

51 ACs across 9 groups. Each carries a story-type tag (`[Logic]` = unit test BLOCKING; `[Integration]` = integration or documented playtest BLOCKING; `[UI]`/`[Visual/Feel]` = walkthrough + evidence ADVISORY; `[Config/Data]` = smoke check ADVISORY) and an evidence path. Covers §C Core Rules (CR-1..17), §C.2 Gadget Roster behaviors, §D Formulas F.1–F.6 worked examples, §E edge cases (high-value), §C.5 Interactions contracts, and Pillar compliance. Two ACs (AC-INV-5.4 + AC-INV-1.5/2.7) are BLOCKED by open questions — noted inline.

### 1. Weapon Switching

- **AC-INV-1.1** `[Logic]` **GIVEN** Eve is in IDLE with Slot 2 (dart gun) equipped, **WHEN** `weapon_slot_2` fires, **THEN** no signal emits, no animation, state remains IDLE. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.2** `[Logic]` **GIVEN** IDLE with Slot 2 equipped and `mission_pickup_rifle_acquired == false`, **WHEN** `weapon_slot_3` fires, **THEN** state remains IDLE, `weapon_switched` does NOT emit, `weapon_dry_fire_click(&"rifle")` emits. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.3** `[Logic]` **GIVEN** SWITCHING state (0.35 s timer running), **WHEN** any `weapon_slot_N` or `weapon_next/prev` fires, **THEN** silent reject — no new SWITCHING, no signal, in-progress switch completes to original target. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.4** `[Logic]` **GIVEN** RELOADING state (magazine < `magazine_size`, reserve > 0), **WHEN** `weapon_slot_N` with N ≠ current fires, **THEN** reload cancelled (magazine retains pre-reload count, no `ammo_changed` emit), state → SWITCHING, 0.35 s timer starts. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.5** `[Logic]` **GIVEN** `player.is_hand_busy() == true`, **WHEN** any `weapon_slot_N` fires, **THEN** silent reject — no state change, no signal emission. *NOTE: final path for SWITCHING-state coverage depends on OQ-INV-3 resolution in PC GDD.* Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.6** `[Logic]` **GIVEN** SWITCHING state entered, **WHEN** t=0.175 s elapses, **THEN** previous weapon mesh `queue_free()`'d AND new weapon mesh instantiated as child of `player.HandAnchor` in the same frame — and not before or after. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.7** `[Logic]` **GIVEN** damage applied to Eve during SWITCHING, **WHEN** damage resolves, **THEN** SWITCHING timer is NOT interrupted — `weapon_switched` emits at t=0.35 s as normal. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.8** `[Logic]` **GIVEN** `weapon_next` pressed from Slot 5 (fists), **WHEN** scroll wraps, **THEN** Slot 1 (silenced pistol) equipped AND `weapon_switched(&"silenced_pistol")` emits at t=0.35 s. Reverse: `weapon_prev` from Slot 1 wraps to Slot 5. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-1.9** `[Logic]` **GIVEN** `mission_pickup_rifle_acquired == false`, **WHEN** `weapon_next/prev` scrolls, **THEN** Slot 3 is skipped — effective cycle is 1→2→4→5→1 (and reverse) — no dry-click for scroll (CR-2). Evidence: `tests/unit/inventory/weapon_switch_test.gd`

### 2. Pickup and Drops

- **AC-INV-2.1** `[Logic]` **GIVEN** `current_reserve = 47` for pistol and a 3-round guard drop pocketed, **WHEN** `pocket_item` runs, **THEN** `ammo_reserve[&"silenced_pistol"] == 48` (2 rounds discarded), `ammo_changed` emits with reserve=48, WorldItem freed (F.1 Example B). Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.2** `[Logic]` **GIVEN** `current_reserve = 24` (dart cap) and 1-dart drop pocketed, **WHEN** `pocket_item` runs, **THEN** `ammo_reserve[&"dart_gun"]` remains 24 (1 dart discarded), `ammo_changed` emits unchanged reserve, WorldItem freed (F.1 Example C). Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.3** `[Logic]` **GIVEN** guard killed lethally (BULLET) with `carried_weapon_id == &"silenced_pistol"`, **WHEN** `Events.enemy_killed` fires, **THEN** WorldItem with `item_id == &"pistol_ammo"` and `quantity == 3` spawns near guard's `global_position`. Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.4** `[Logic]` **GIVEN** guard downed via dart (DART_TRANQUILISER), **WHEN** `Events.guard_incapacitated` fires, **THEN** WorldItem with `item_id == &"dart_ammo"` and `quantity == 1` spawns — regardless of weapon carried. Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.5** `[Logic]` **GIVEN** guard downed via fists (MELEE_FIST), **WHEN** `Events.guard_incapacitated` fires, **THEN** no WorldItem spawned (anti-farm invariant `guard_drop_dart_on_fist_ko == 0` locked). Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.6** `[Logic]` **GIVEN** two guards die on same frame at positions ≤ 0.5 m apart, **WHEN** both `enemy_killed` signals fire, **THEN** WorldItem spawn positions ≥ 0.73 m apart (F.3 verification: `|D_A − D_B| ≥ 0.73`). Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.7** `[Logic]` **GIVEN** `Events.player_interacted` fires with non-WorldItem target, **WHEN** Inventory's subscriber handles, **THEN** no action, no `queue_free()` on the target. *NOTE: also covers the PC-gate-during-SWITCHING case per OQ-INV-3.* Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-2.8** `[Logic]` **GIVEN** guard killed via FALL_OUT_OF_BOUNDS, **WHEN** `enemy_killed` fires, **THEN** no WorldItem spawned (CR-7a explicit row). Evidence: `tests/unit/inventory/pickup_drop_test.gd`

### 3. Gadget Activation — Compact

- **AC-INV-3.1** `[Logic]` **GIVEN** Compact equipped and `peek_surface`-tagged shape within 1.5 m of forward raycast, **WHEN** `try_use_gadget()` called, **THEN** gate returns `true`, `gadget_used(&"gadget_compact", player.global_position)` emits, behavior scene instantiated. Evidence: `tests/unit/inventory/gadget_compact_test.gd`
- **AC-INV-3.2** `[Logic]` **GIVEN** Compact equipped, no `peek_surface` within 1.5 m, **WHEN** `try_use_gadget()` called, **THEN** gate returns `false`, `gadget_used` NOT emitted, `gadget_activation_rejected(&"gadget_compact")` emits (HUD desaturation + haptic pulse). Evidence: `tests/unit/inventory/gadget_compact_test.gd`
- **AC-INV-3.3** `[Logic]` **GIVEN** Compact behavior scene active (camera in fiber-optic view), **WHEN** any movement input (WASD or left-stick > threshold) fires, **THEN** behavior scene cancels, camera returns to first-person, no re-emit of `gadget_used`. Evidence: `tests/unit/inventory/gadget_compact_test.gd`
- **AC-INV-3.4** `[Logic]` **GIVEN** Compact behavior scene active and 10 s timer elapses without cancellation, **WHEN** timer fires, **THEN** behavior scene `queue_free()`'d, camera returns to first-person, no signal emitted. Evidence: `tests/unit/inventory/gadget_compact_test.gd`

### 4. Gadget — Cigarette Case

- **AC-INV-4.1** `[Logic]` **GIVEN** Case equipped, `placeable_surface`-tagged surface with up-vector ≥ 0.7 within 1.5 m, no case currently placed, **WHEN** `try_use_gadget()` called, **THEN** case placed at P_case, `gadget_used(&"gadget_cigarette_case", P_case)` emits, noise emitter begins 4 s emission at P_case. Evidence: `tests/unit/inventory/gadget_case_test.gd`
- **AC-INV-4.2** `[Logic]` **GIVEN** Case emitter active at P_case, **WHEN** NoiseEvent emitted each physics tick, **THEN** event carries `origin == P_case` (NOT Eve's position) and `noise_level_tier == 3` (Sprint-tier). Evidence: `tests/unit/inventory/gadget_case_test.gd`
- **AC-INV-4.3** `[Logic]` **GIVEN** Case already placed (max one active), **WHEN** `try_use_gadget()` called second time, **THEN** gate fails, `gadget_activation_rejected` emits, placed case continues 4 s emission undisturbed. Evidence: `tests/unit/inventory/gadget_case_test.gd`
- **AC-INV-4.4** `[Logic]` **GIVEN** Case placed and Eve walks within 0.5 m of P_case, **WHEN** retrieval proximity triggers, **THEN** emitter cancelled, behavior scene `queue_free()`'d, case available for re-placement. Evidence: `tests/unit/inventory/gadget_case_test.gd`
- **AC-INV-4.5** `[Logic]` **GIVEN** Case active and emitting, **WHEN** Eve moves to position > 8 m from P_case, **THEN** case continues emitting at P_case — emission does NOT cease based on Eve's distance (E.19). Evidence: `tests/unit/inventory/gadget_case_test.gd`

### 5. Gadget — Parfum

- **AC-INV-5.1** `[Logic]` **GIVEN** Parfum equipped, guard head collider within 1.5 m of forward cone, guard `alert_state NOT IN {COMBAT, UNCONSCIOUS, DEAD}`, **WHEN** `try_use_gadget()` called, **THEN** `SAI.receive_damage(guard, 0, eve, DamageType.DART_TRANQUILISER)` called, guard transitions to UNCONSCIOUS, `gadget_used(&"gadget_parfum", player.global_position)` emits. Evidence: `tests/unit/inventory/gadget_parfum_test.gd`
- **AC-INV-5.2** `[Logic]` **GIVEN** Parfum equipped, nearest-cone guard `alert_state == COMBAT`, **WHEN** `try_use_gadget()` called, **THEN** gate fails, `gadget_activation_rejected` emits, no `receive_damage` call. Evidence: `tests/unit/inventory/gadget_parfum_test.gd`
- **AC-INV-5.3** `[Logic]` **GIVEN** Parfum equipped, nearest-cone guard `alert_state == UNCONSCIOUS`, **WHEN** `try_use_gadget()` called, **THEN** gate fails (idempotent), `gadget_activation_rejected` emits. Evidence: `tests/unit/inventory/gadget_parfum_test.gd`
- **AC-INV-5.4** `[Logic]` **(RESOLVED 2026-04-24 — OQ-INV-1 Option B)** **GIVEN** guard KO'd via Parfum (triggers `guard_incapacitated(guard, cause=MELEE_PARFUM)`), **WHEN** CR-7 subscriber handles, **THEN** **no WorldItem spawns** (Parfum-KO drops nothing — `guard_drop_dart_on_parfum_ko = 0` LOCKED invariant, mirrors fist-KO). `ammo_changed` does NOT emit. The `cause` parameter is read from the extended `guard_incapacitated` signature (ADR-0002 amendment requirement). Evidence: `tests/unit/inventory/gadget_parfum_test.gd`
- **AC-INV-5.5** `[Logic]` **(REVISED 2026-04-24 per OQ-INV-1 Option B)** **GIVEN** Parfum-KO'd guard (no dart WorldItem spawned per AC-INV-5.4), **WHEN** `WAKE_UP_SEC = 45 s` elapses and guard → SUSPICIOUS, **THEN** no WorldItem-related state change — Inventory never spawned a drop for this KO and has nothing to despawn. Wake-up is purely SAI's concern (E.41 intent preserved). Evidence: `tests/unit/inventory/gadget_parfum_test.gd`

### 6. Fire Pipeline, Dry-Fire, and Medkit

- **AC-INV-6.1** `[Logic]` **GIVEN** Slot 1 equipped, `ammo_magazine > 0`, `_can_fire() == true`, **WHEN** `fire_primary` fires, **THEN** magazine decrements by 1, `Events.weapon_fired` emits (weapon, muzzle_pos, muzzle_dir), `Combat.apply_fire_path()` called, `ammo_changed` emits post-decrement. Evidence: `tests/unit/inventory/fire_pipeline_test.gd`
- **AC-INV-6.2** `[Logic]` **GIVEN** Slot 1, magazine=0 AND reserve=0, **WHEN** `fire_primary` fires, **THEN** `weapon_fired` NOT emitted, no decrement, `weapon_dry_fire_click(&"silenced_pistol")` emits, no auto-switch (CR-15). Evidence: `tests/unit/inventory/fire_pipeline_test.gd`
- **AC-INV-6.3** `[Logic]` **GIVEN** Slot 4 (takedown blade) equipped, **WHEN** `fire_primary` fires, **THEN** silent reject — no signal, no audio, no haptic (CR-16 Composed Removal). Evidence: `tests/unit/inventory/fire_pipeline_test.gd`
- **AC-INV-6.4** `[Logic]` **GIVEN** WorldItem `item_id=&"medkit"` pocketed via `player_interacted`, **WHEN** `pocket_item` handles, **THEN** `player.apply_heal(40, self)` called, no `ammo_changed` emit, WorldItem freed, no `gadget_used` (medkit is not a gadget). Evidence: `tests/unit/inventory/medkit_test.gd`
- **AC-INV-6.5** `[Logic]` **GIVEN** Eve at 100 HP picks up medkit, **WHEN** `apply_heal(40)` called, **THEN** `new_hp = clamp(140, 0, 100) = 100`, WorldItem frees, `player_health_changed` emits via PC. Evidence: `tests/unit/inventory/medkit_test.gd`
- **AC-INV-6.6** `[Logic]` **GIVEN** Eve at 35 HP, **WHEN** `apply_heal(40)` called, **THEN** `new_hp = min(75, 100) = 75` (F.4 Example A). Evidence: `tests/unit/inventory/medkit_test.gd`

### 7. Save/Restore and Starting Inventory

- **AC-INV-7.1** `[Logic]` **GIVEN** `_ready()` runs (mission start), **WHEN** state read immediately, **THEN** `current_weapon_id == &"silenced_pistol"`, `equipped_gadget_id == &"gadget_compact"`, `ammo_magazine[&"silenced_pistol"] == 8`, `ammo_reserve[&"silenced_pistol"] == 32`, `ammo_magazine[&"dart_gun"] == 4`, `ammo_reserve[&"dart_gun"] == 16`, `mission_pickup_available == false`, `medkit_count == 0`, `_gadget_cycle == [&"gadget_compact", &"gadget_cigarette_case"]`. **Independently QA-testable without GDD**: launch new mission, open debug overlay, verify all fields. Evidence: `tests/unit/inventory/starting_inventory_test.gd`
- **AC-INV-7.2** `[Logic]` **GIVEN** `restore_weapon_ammo` called with snapshot (pistol mag=3, reserve=5, total=8), floor={pistol:16}, cap={pistol:48}, **WHEN** restore executes, **THEN** `ammo_magazine[pistol] == 8` and `ammo_reserve[pistol] == 8` (F.2 Example A floor trigger). Evidence: `tests/unit/inventory/save_restore_test.gd`
- **AC-INV-7.3** `[Logic]` **GIVEN** snapshot `ammo_reserve[pistol] = 54` (above cap 48), **WHEN** restore executes, **THEN** reserve clamps to 48, no crash, `push_warning` logs anomaly (E.30). Evidence: `tests/unit/inventory/save_restore_test.gd`
- **AC-INV-7.4** `[Logic]` **GIVEN** save snapshot contains unknown `weapon_id` key (e.g., `&"alien_laser"`), **WHEN** `restore_weapon_ammo` iterates, **THEN** unknown key skipped with `push_warning`, no crash, no mutation to valid entries (E.35). Evidence: `tests/unit/inventory/save_restore_test.gd`
- **AC-INV-7.5** `[Logic]` **GIVEN** `InventoryState.mission_pickup_available == true` in snapshot, **WHEN** Inventory restores gadget cycle, **THEN** `_gadget_cycle == [&"gadget_compact", &"gadget_cigarette_case", &"gadget_parfum"]`, `gadget_equipped` signal emits with current equipped gadget. Evidence: `tests/unit/inventory/save_restore_test.gd`
- **AC-INV-7.6** `[Logic]` **GIVEN** Parfum acquired AFTER a checkpoint save (`mission_pickup_available == false` in snapshot) then Eve respawns, **WHEN** `restore_weapon_ammo` restores, **THEN** `mission_pickup_available == false` restored, cycle returns to 2 entries, Mission Scripting is expected to re-spawn Parfum WorldItem (MLS forward contract — E.27). Evidence: `tests/unit/inventory/save_restore_test.gd`

### 8. Cross-System Contracts

- **AC-INV-8.1** `[Logic]` **GIVEN** dart gun equipped, valid fire, pre-fire occlusion check in `Combat.apply_fire_path` fails (E.40), **WHEN** fire path returns, **THEN** `_decrement_magazine()` NOT called, magazine unchanged, `weapon_fired` NOT emitted, `ammo_changed` NOT emitted. Evidence: `tests/unit/inventory/fire_pipeline_test.gd`
- **AC-INV-8.2** `[Logic]` **GIVEN** `SAI.takedown_prompt_active() == true` and use_gadget/takedown fires, **WHEN** Combat single-dispatch handler evaluates, **THEN** `_execute_takedown()` called, `InventorySystem.try_use_gadget()` NOT called — dispatch mutually exclusive, no double-fire. Evidence: `tests/unit/inventory/gadget_activation_test.gd`
- **AC-INV-8.3** `[Logic]` **GIVEN** dart-KO on guard (`guard_incapacitated` DART_TRANQUILISER), **WHEN** player immediately executes blade takedown on same guard (`enemy_killed` MELEE_BLADE), **THEN** both signals processed sequentially — 1 dart WorldItem from `guard_incapacitated` + 1 pistol-ammo WorldItem from `enemy_killed`, F.3 offset applied (E.42 — both drops legitimate). Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-8.4** `[Logic]` **(REWRITTEN 2026-04-24 per [qa-lead])** **GIVEN** Inventory in IDLE steady-state with no input or pending signals, **WHEN** the test harness installs a method-call spy on `InventorySystem._process` and `InventorySystem._physics_process`, and 60 consecutive frames execute, **THEN** the spy records zero invocations on either callback (Inventory does not override `_process` or `_physics_process` at the root InventorySystem node — ADR-0008 Slot #8 steady-state invariant). This replaces the prior unfalsifiable "0 ms per-frame CPU" claim with a callable-presence assertion. Evidence: `tests/unit/inventory/performance_test.gd`
- **AC-INV-8.5** `[Visual/Feel]` **(DEMOTED to manual evidence 2026-04-24 per [qa-lead])** **GIVEN** 6 `enemy_killed` signals fire within the same `_physics_process` tick (worst-case multi-drop), **WHEN** all 6 Inventory drop-spawn subscribers process synchronously, **THEN** exactly 6 WorldItem nodes are present in the scene tree under the WorldItems parent AND `_drop_index_this_tick == 6` at tick end AND all 6 positions are pairwise ≥ 0.4 m apart (F.3 verification). Sub-ms wall-clock budget (≤0.8 ms one-shot for the 6-drop scenario) is validated during the Performance Polish phase via profiler-assisted manual measurement, NOT via GUT unit-test timing (GUT's framework overhead makes sub-ms timing unreliable). Evidence: `tests/unit/inventory/performance_test.gd` (functional assertion) + `production/qa/evidence/inventory_mass_drop_perf.md` (profiler evidence, Polish phase).
- **AC-INV-8.6** `[Integration]` **GIVEN** Case emitter active at P_case, `noise_level_tier == 3`, **WHEN** guard positioned 6 m from P_case, **THEN** guard transitions to SUSPICIOUS with `investigation_target == P_case` within 1–3 s (F.5 SAI integration). Evidence: `tests/integration/inventory/case_sai_integration_test.gd`
- **AC-INV-8.7** `[Integration]` **GIVEN** `InventorySystem.register_restore_callback(_serialize_inventory)` called in `_ready()`, **WHEN** Save/Load triggers callback at step 9 of LS 13-step swap, **THEN** `InventoryState` Resource returned with current_weapon_id, gadget cycle state, all ammo dict values; no crash, no null. Evidence: `tests/integration/inventory/save_load_integration_test.gd`

### 8b. New ACs for edge-case coverage (ADDED 2026-04-24 per [qa-lead] coverage gaps)

- **AC-INV-8.8** `[Logic]` **GIVEN** `use_gadget` pressed at the exact frame `SAI.takedown_prompt_active()` transitions `false → true` (E.43 race), **WHEN** Combat's single-dispatch handler evaluates, **THEN** whichever SAI state is read at evaluation time wins (one-shot race), `set_input_as_handled()` fires in either branch, NO double-dispatch (neither `gadget_used` nor `takedown_performed` fires twice), next frame resumes normal behavior. Evidence: `tests/unit/inventory/gadget_activation_test.gd`
- **AC-INV-8.9** `[Logic]` **GIVEN** two `weapon_slot_N` events queued in the same frame (e.g., slot_2 then slot_3 same tick, E.44), **WHEN** `_unhandled_input` processes in enqueue order, **THEN** first press enters SWITCHING at t=0; second press during SWITCHING is silent-rejected per CR-1; final state = first-press weapon; exactly 1 `weapon_switched` emit. Evidence: `tests/unit/inventory/weapon_switch_test.gd`
- **AC-INV-8.10** `[Logic]` **GIVEN** F.2 respawn with dart snapshot (mag=1, res=2, total=3) below dart floor (8), **WHEN** `restore_weapon_ammo` executes, **THEN** `ammo_magazine[dart_gun] == 4` AND `ammo_reserve[dart_gun] == 4` (total = 8, floor triggered, F.2 Example D). Evidence: `tests/unit/inventory/save_restore_test.gd`
- **AC-INV-8.11** `[Logic]` **GIVEN** F.2 respawn with rifle snapshot (mag=1, res=2, total=3), no rifle floor in floor dict, **WHEN** `restore_weapon_ammo` executes, **THEN** `ammo_magazine[rifle] == 3` AND `ammo_reserve[rifle] == 0` (snapshot preserved, F.2 Example E). Evidence: `tests/unit/inventory/save_restore_test.gd`
- **AC-INV-8.12** `[Logic]` **GIVEN** `_drop_index_this_tick = 5` at end of a physics tick, **WHEN** next `_physics_process` begins, **THEN** `_drop_index_this_tick == 0` at start of first-frame subscriber invocation (F.3 CR-7b reset). Evidence: `tests/unit/inventory/pickup_drop_test.gd`
- **AC-INV-8.13** `[Integration]` **GIVEN** Parfum equipped, guard UNAWARE within 1.5 m front-cone, **WHEN** `try_use_gadget()` executes the full chain Parfum spray → `SAI.receive_damage(guard, 0, eve, MELEE_PARFUM)` → `guard_incapacitated(guard, MELEE_PARFUM)` → CR-7 subscriber, **THEN** guard transitions UNCONSCIOUS AND NO WorldItem spawns AND `gadget_used` emits exactly once (OQ-INV-1 Option B + CR-7a new row). Evidence: `tests/integration/inventory/parfum_sai_full_chain_test.gd`
- **AC-INV-8.14** `[Integration]` **GIVEN** Inventory-registered LS callback invoked at step 9 of a LOAD_FROM_SAVE transition, **WHEN** `_on_restore_from_save(section_id, save_game, TransitionReason.LOAD_FROM_SAVE)` executes, **THEN** Inventory fields match `save_game.inventory_state` field-for-field (current_weapon_id, equipped_gadget_id, mission_pickup_available, ammo dicts, gadget cycle reconstructed) AND `gadget_equipped` emits exactly once post-restore. Evidence: `tests/integration/inventory/ls_restore_callback_test.gd`

### 9. Pillars, Forbidden Patterns, and Infrastructure

- **AC-INV-9.1** `[Logic]` **(CORRECTED 2026-04-24 per [qa-lead])** **GIVEN** CR-17 grep patterns run against `src/gameplay/inventory/` in CI, **WHEN** scan completes, **THEN** zero matches for all **8** forbidden patterns (`player_footstep`, guard property writes, forbidden emit sites [`enemy_killed`/`enemy_damaged`/`player_damaged`/`player_health_changed`/`player_died`], `Combat.apply_damage_to_actor`, restricted `SAI.*` except `SAI.takedown_prompt_active`, `player.health =`, `NavigationServer3D.map_get_path`, `call_deferred` in `_unhandled_input` handlers). Prior count "7" was a miscount — CR-17 table enumerates 8 distinct patterns. CI script MUST grep all 8 targets; a silently-omitted pattern results in false-PASS. Evidence: CI grep gate (no file path — CI script reports PASS/FAIL with per-pattern line-count breakdown).
- **AC-INV-9.2** `[UI]` **GIVEN** fresh mission start (independently QA-testable without GDD), **WHEN** player opens inventory screen and examines gadgets, **THEN** exactly 2 gadgets visible (Compact + Cigarette Case), medkit count reads 0, Parfum slot absent, each gadget description in present-tense BQA-bureaucratic register (no Eve first-person quips). Evidence: `production/qa/evidence/inventory_mission_start_ui.md`
- **AC-INV-9.3** `[UI]` **GIVEN** fresh mission start (independently QA-testable), **WHEN** player presses any of Slots 1–5 and scroll inputs, **THEN** no radial wheel appears, no time-dilation, no auto-switch to fists on pistol dry, slot binding does not change mid-mission (Pillar-5 NOLF1 grammar). Evidence: `production/qa/evidence/inventory_pillar5_bindings.md`
- **AC-INV-9.4** `[Integration]` **GIVEN** complete mission playthrough using only lethal Aggressive tactics (pistol-kill all guards, no stealth, no deliberate cache seeking), **WHEN** ammo counts logged at each section boundary, **THEN** pistol reserve drops by ≥ 3 rounds net per 4-guard encounter (F.6 `net_aggressive ≤ −3`), confirming Pillar-2 depletion over mission-length session. **Playtest gate for OQ-INV-2.** Evidence: `production/qa/evidence/pillar2_aggressive_economy_playtest.md`
- **AC-INV-9.5** `[Integration]` **GIVEN** complete mission playthrough using only dart-KO and Parfum non-lethal tactics, **WHEN** dart counts logged per encounter, **THEN** net dart flow per encounter is 0 (dart spent=1, dropped=1, LOCKED) — Ghost is break-even; non-lethal gadgets preserve UNCONSCIOUS reversibility (Pillar-3). Evidence: `production/qa/evidence/pillar3_nonlethal_reversibility_playtest.md`
- **AC-INV-9.6** `[Logic]` **GIVEN** `gadget_next` pressed 60 times in 1 second with 3 gadgets in cycle, **WHEN** all 60 events process, **THEN** `gadget_equipped` emits exactly 60 times, no dropped events, no state corruption, final `equipped_gadget_id == (initial_index + 60) mod 3` (E.47 tolerance). Evidence: `tests/unit/inventory/gadget_rotation_test.gd`
- **AC-INV-9.7** `[Logic]` **GIVEN** Parfum WorldItem acquired mid-mission (CR-13), **WHEN** `pocket_item` processes `item_id == &"gadget_mission_pickup"`, **THEN** `_gadget_cycle` grows 2→3 with `&"gadget_parfum"` appended, `gadget_equipped` emits with currently-equipped id (not new one), `mission_pickup_available = true`. Evidence: `tests/unit/inventory/gadget_rotation_test.gd`
- **AC-INV-9.8** `[Config/Data]` **GIVEN** registry values `guard_drop_pistol_rounds=3`, `rifle_max_reserve=12`, `medkit_heal_amount=40`, `guard_drop_dart_on_dart_ko=1`, `guard_drop_dart_on_fist_ko=0` are loaded, **WHEN** smoke check validates against GDD locked values, **THEN** all five match exactly, no stale values (e.g., old `guard_drop_pistol_rounds=8`) are present. Evidence: `production/qa/smoke-[date].md`

### Open Question flags on AC set

- **AC-INV-5.4** BLOCKED by **OQ-INV-1** (Parfum-KO drop policy). If user decides Parfum-KO drops nothing (prevent dart-farm via Parfum), this AC must be rewritten and SAI must expose KO-cause on `guard_incapacitated`.
- **AC-INV-1.5 / AC-INV-2.7** final behavior during SWITCHING is BLOCKED by **OQ-INV-3** resolution in PC GDD. If `is_hand_busy() == true` during SWITCHING, the PC gate suppresses pickup per E.4. If `is_hand_busy() == false`, Inventory must apply its own SWITCHING-internal gate at the `player_interacted` handler.

## Open Questions

Questions that surfaced during design but were not fully resolved. Each has an owner + target resolution + blocking severity. **Blocking** = must close before implementation sprint. **Playtest-gated** = ships with provisional tuning; refined from Tier 0 / Tier 1 playtest data. **Forward** = resolved by a downstream GDD (Mission Scripting, Settings & Accessibility).

### OQ-INV-1 — Parfum-KO drop policy — **RESOLVED 2026-04-24 (Option B)**

**Status**: **RESOLVED** — user decision 2026-04-24.

**Decision**: Option B (Parfum-KO drops nothing). Rationale summarised from [game-designer B-1] and [economy-designer]: unlimited Parfum + trivial front-facing gate = structural farm vector that breaks the dart economy break-even invariant. Option B closes the vector while preserving Parfum's tactical niche ("face-to-face silent non-lethal") and its tonal register (perfume bottle, not dart dispenser).

**Implementation fallout (applied 2026-04-24)**:
- SAI `guard_incapacitated` signal signature extended: `(guard: Node, cause: int)` where `cause: Combat.DamageType`. ADR-0002 amendment requirement bundled into Coord item #2.
- Combat.DamageType enum gains `MELEE_PARFUM` member (new; non-lethal routing per `is_lethal_damage_type()`).
- Parfum behavior scene calls `SAI.receive_damage(guard, 0, eve, DamageType.MELEE_PARFUM)` instead of `DART_TRANQUILISER`.
- Registry gains `guard_drop_dart_on_parfum_ko = 0` LOCKED invariant (NEW — Phase 5b registry update Coord item #3).
- CR-7a drop table gains MELEE_PARFUM row (no drop).
- AC-INV-5.4 rewritten to assert no drop.

**No longer blocks**: previously blocked AC-INV-5.4 and ADR-0002 amendment scope; both now proceed with Option B.

### OQ-INV-2 — Pillar-2 felt-scarcity playtest validation

**Status**: **Playtest-gated** (deferred, not blocking MVP GDD sign-off; blocking full sprint commitment).

**Question**: §D F.6 economy audit shows Aggressive vs Ghost end-of-mission delta is ~14% on absolute totals + ~20% on pistol-only delta when the recommended 11-cache pattern is placed. economy-designer flagged this as **borderline** for Pillar-2 differentiation (>30% preferred). Does Aggressive actually *feel* ammo-scarce mid-mission, even if end-state totals are close?

**Resolution mechanism**: Tier 0 Plaza playtest (`/prototype stealth-ai`) + full Tier 1 playtest once Mission Scripting places caches. Collect: times-player-saw-ammo-counter-below-10 per playstyle; player-reported scarcity-pressure feel at Section 3 + 4; natural recovery behavior (do players seek caches?).

**Contingency**: if Aggressive reports no felt scarcity at S3-S4, economy-designer recommends removing the S4 main-route pistol cache (keeping only the off-path gantry version) — pushes end-of-mission Aggressive total to ~21 vs Ghost ~34 = 38% delta, clearing threshold.

**Owner**: producer (playtest scheduling) + economy-designer (cache placement iteration).

**Target resolution**: after first Tier 1 mission-length playtest.

**Blocks**: AC-INV-9.4 (`[Integration]` Pillar-2 playtest evidence).

### OQ-INV-3 — `player.is_hand_busy()` scope during SWITCHING

**Status**: **BLOCKING** for E.4 behavior. PC GDD clarification needed.

**Question**: The §C.4 state-table marks `PICKUP_IN_PROGRESS` as NOT reachable from `SWITCHING`. The mechanism assumed: `player.is_hand_busy() == true` during SWITCHING suppresses PC's `player_interacted` emission. But PC GDD does NOT explicitly state that SWITCHING sets `is_hand_busy()`. If `is_hand_busy()` is only set during interact-animation states (document open, SAI takedown override), then a priority-2 `interact` raycast during SWITCHING would emit `player_interacted` — and Inventory would receive it, violating the state-table.

**Options**:

- **Option A**: PC GDD amended to state "`is_hand_busy()` returns true during weapon SWITCHING state (HandAnchor mid-mesh-swap)." Cleanest — single-source-of-truth gate on PC.
- **Option B**: Inventory installs its own internal gate — `player_interacted` subscriber checks `self._state == SWITCHING` and returns early. Adds Inventory-internal state coupling.

**Owner**: PC GDD maintainer (Option A preferred; minor clarification edit).

**Target resolution**: before Inventory sprint. Default if not decided: Option B (Inventory-internal gate, defensive).

**Blocks**: AC-INV-1.5 and AC-INV-2.7 final path; E.4 behavior.

### OQ-INV-4 — Parfum cone nearest-guard sort

**Status**: **Deferred to implementation sprint** (not blocking GDD sign-off).

**Question**: Parfum's `get_overlapping_bodies()` on the 1.5 m forward-cone returns a list; §C.2 says "only the first guard intersecting the cone is affected." Jolt (Godot 4.6 default) does not guarantee deterministic overlap result order. If two guards are at identical distances, the selection is non-deterministic.

**Resolution (REVISED 2026-04-24 per [gameplay-programmer Issue 8, godot-specialist V-2])**: Parfum behavior scene MUST sort `get_overlapping_bodies()` by `body.global_position.distance_to(player.global_position)` and take `result[0]` after sorting. Deterministic nearest-guard semantics. Tiebreaker for identical distance: **`body.get_instance_id()`** (ascending int comparison) — guaranteed unique per node in Godot 4.6 and deterministic within a session. Previously specified `body.name` alphabetic: rejected because Mission Scripting scene authoring can produce duplicate node names (Godot only auto-renames siblings under a parent, not across the scene tree), which would make the tiebreaker a coinflip between duplicate-named guards. `get_instance_id()` cannot collide.

**Owner**: gameplay-programmer during Parfum behavior-scene implementation.

**Target resolution**: Parfum implementation sprint (no GDD amendment needed — implementation detail).

**Blocks**: AC-INV-5.1 deterministic behavior (strict test: two guards at identical distance → nearest wins by `get_instance_id()` ascending).

### OQ-INV-5 — Accessibility rebind for `use_gadget`/`takedown` shared binding

**Status**: Forward-dep to Settings & Accessibility GDD.

**Question**: `use_gadget` and `takedown` share binding (F / JOY_Y) with Combat's single-dispatch mutex per CR-4. Can a player rebind these separately (e.g., "Takedown = G, UseGadget = F") for accessibility? If yes, the mutex collapses (no shared binding) and Combat's dispatch logic may need to route differently.

**Resolution**: Settings & Accessibility GDD decides whether rebinding is parity (MVP = keyboard rebind only, gamepad parity deferred per technical-preferences.md) or full. If separate binding is permitted, Combat's single-dispatch becomes two independent handlers — each checks `SAI.takedown_prompt_active()` independently, with the original double-fire race risk returning (mitigated by `set_input_as_handled()` in both).

**Owner**: Settings & Accessibility GDD + Input GDD revision.

**Target resolution**: Settings & Accessibility GDD authoring (Vertical Slice phase).

**Blocks**: Long-term binding rebinding support. MVP ships with shared binding per Input GDD L90–91.

### OQ-INV-6 — Mission-gadget respawn timing across save-load slots

**Status**: Forward-dep to Mission Scripting GDD + Save/Load GDD reciprocation.

**Question**: E.27 / E.32 / E.33 cover the Parfum respawn rules within a single mission run. But across **save-slot loads** (player loads a save made before Parfum pickup), Mission Scripting must re-place the WorldItem. Is the save-slot load path exactly equivalent to the section-reload-on-respawn path? If yes, no new rule needed. If no (save-slot loads may snapshot from a deeper save state), Mission Scripting's placement logic needs an additional gate.

**Owner**: Mission Scripting GDD + Save/Load GDD.

**Target resolution**: Mission Scripting authoring (Feature-layer, follows Inventory).

**Blocks**: None for Inventory MVP; Mission Scripting integration test coverage.

---

### OQ summary for producer tracking

| OQ | Severity | Owner | Target | Affects |
|---|---|---|---|---|
| OQ-INV-1 | **RESOLVED 2026-04-24 (Option B)** | user decision | Pre-sprint | AC-INV-5.4, AC-INV-5.5 rewritten; ADR-0002 signature extended; registry invariant added |
| OQ-INV-2 | Playtest-gated | producer + economy-designer | First Tier 1 playtest | AC-INV-9.4 — partially improved by realistic-play `net_ghost` correction 2026-04-24 |
| OQ-INV-3 | **BLOCKING** | PC GDD maintainer | Pre-sprint | AC-INV-1.5, AC-INV-2.7, E.4 — Option B default (Inventory-internal gate) implementable if PC decision slips |
| OQ-INV-4 | Sprint-deferred | gameplay-programmer | Parfum impl | AC-INV-5.1 determinism — tiebreaker resolved 2026-04-24 to `get_instance_id()` |
| OQ-INV-5 | Forward | Settings & Accessibility GDD | VS phase | Long-term rebind |
| OQ-INV-6 | Forward | Mission Scripting GDD | Feature phase | Save-slot load integration |
