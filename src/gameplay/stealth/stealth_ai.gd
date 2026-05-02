# res://src/gameplay/stealth/stealth_ai.gd
#
# StealthAI — Enum and rule owner for the Stealth AI system in The Paris Affair.
#
# This class declares all enum types used in SAI-domain signal payloads and
# implements the _compute_severity rule that classifies each state transition.
# Signal declarations referencing these enums live in events.gd (AC-2).
#
# Implements: Story SAI-002 (StealthAI enums + Events.gd signal declarations)
# Requirements: TR-SAI-002, TR-SAI-003, TR-SAI-004, TR-SAI-005, TR-SAI-006
# GDD: design/gdd/stealth-ai.md §Detailed Rules (Alert state ownership) +
#      §Interactions (Signal Bus row)
# ADR: ADR-0002 IG 2 — enum types in signal signatures are defined as inner
#      enums on the system class that owns the concept. StealthAI owns all four
#      SAI-domain enum types; events.gd references them as qualified names.
#
# TR discrepancy note (TR-SAI-005 vs story AC-1):
#   TR-SAI-005 lists 5 AlertCause values (HEARD, SAW_PLAYER, SAW_BODY,
#   ALERTED_BY_OTHER, SCRIPTED). Story AC-1 specifies 7 (splits HEARD into
#   HEARD_NOISE / HEARD_GUNFIRE / CURIOSITY_BAIT). Story spec is the
#   authoritative implementation target — the registry text predates the
#   refined design. Flagged for /architecture-review reconciliation.

class_name StealthAI extends Node


# ── Alert state machine (TR-SAI-002) ──────────────────────────────────────────
## Six-state alert lattice for a PHANTOM guard.
## Active progression: UNAWARE → SUSPICIOUS → SEARCHING → COMBAT
## Terminal states: UNCONSCIOUS (non-lethal KO; wake-up clock active)
##                  DEAD        (lethal; permanent removal from play)
## GDD §Detailed Rules — Alert state ownership.
enum AlertState {
	UNAWARE,      ## Guard has no awareness of the player. Default initial state.
	SUSPICIOUS,   ## Guard noticed something; investigating stimulus.
	SEARCHING,    ## Guard lost sight but is actively searching the last known pos.
	COMBAT,       ## Guard has confirmed the player; full alarm engaged.
	UNCONSCIOUS,  ## Guard KO'd by non-lethal takedown; wake-up timer running.
	DEAD,         ## Guard killed by lethal takedown; permanent terminal state.
}


# ── Alert cause (TR-SAI-005, story-spec 7-value form) ─────────────────────────
## Cause that drove the AlertState transition. Used by _compute_severity and
## by the audio stinger router (Story 008) to select SFX variants.
## Story AC-1 specifies 7 values; TR-SAI-005 lists 5 (registry-vs-story drift).
## SAW_BODY applies a 2× sight_fill multiplier (GDD §Detailed Rules).
## SCRIPTED suppresses the audio stinger (Pillar 1 comedy preservation).
enum AlertCause {
	HEARD_NOISE,        ## Generic ambient noise crossed hearing threshold.
	SAW_PLAYER,         ## Guard's F.1 sight fill exceeded detection threshold.
	SAW_BODY,           ## Guard spotted an incapacitated / dead colleague (2× multiplier).
	HEARD_GUNFIRE,      ## Gunshot noise crossed the higher gunfire hearing threshold.
	ALERTED_BY_OTHER,   ## A neighbouring guard radioed / called out an alert.
	SCRIPTED,           ## Designer-triggered scripted alert (suppresses stinger).
	CURIOSITY_BAIT,     ## Player used a curiosity-bait gadget to lure the guard.
}


# ── Severity (TR-SAI-004) ─────────────────────────────────────────────────────
## Transition severity, passed in SAI-domain signal payloads.
## Controls Audio stinger emission (Pillar 1 comedy preservation):
##   MAJOR → brass-punch stinger; MINOR → no stinger.
enum Severity {
	MINOR,  ## Low-salience transition (e.g., UNAWARE → SUSPICIOUS).
	MAJOR,  ## High-salience transition (e.g., entering COMBAT or terminal state).
}


# ── Takedown type (TR-SAI-006) ────────────────────────────────────────────────
## Classifies a player takedown, routing Audio SFX variants and determining
## the resulting AlertState (MELEE_NONLETHAL → UNCONSCIOUS; STEALTH_BLADE → DEAD).
enum TakedownType {
	MELEE_NONLETHAL,  ## Dart, fist, or chloroform KO. Guard enters UNCONSCIOUS.
	STEALTH_BLADE,    ## Lethal blade strike. Guard enters DEAD.
}


# ── Severity rule (GDD §Detailed Rules — _compute_severity) ──────────────────

## Computes the Severity for an AlertState transition given the triggering cause.
##
## Rule (GDD §Detailed Rules, authoritative form):
##   1. ALERTED_BY_OTHER cause → always MINOR (peer-radio is low-drama).
##   2. new_state in {SEARCHING, COMBAT, DEAD, UNCONSCIOUS} → MAJOR.
##   3. All other combinations → MINOR.
##
## DEAD and UNCONSCIOUS are MAJOR because a guard's removal from play is
## high-salience for Mission Scripting + Audio clean-up (brass-punch stinger).
##
## Consumers: Events.alert_state_changed, Events.actor_became_alerted,
##            Events.actor_lost_target (Story 008 audio stinger subscriber).
static func _compute_severity(new_state: AlertState, cause: AlertCause) -> Severity:
	if cause == AlertCause.ALERTED_BY_OTHER:
		return Severity.MINOR
	if new_state == AlertState.SEARCHING or new_state == AlertState.COMBAT \
			or new_state == AlertState.DEAD or new_state == AlertState.UNCONSCIOUS:
		return Severity.MAJOR
	return Severity.MINOR
