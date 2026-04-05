# Warzone Engine — Tested Findings

Findings proven through local diagnostic testing (April 2025).
These supersede some assumptions in `ENGINE_FLOW.md`.

---

## 1. LatestTurnStanding Is One Order Behind in _Order

**Status**: Proven

When `Server_AdvanceTurn_Order` fires for order N,
`game.ServerGame.LatestTurnStanding` reflects the state after order **N-1**,
not after order N.

### Evidence

Tested across multiple turns with 4 players on a 6-territory map.
Every successful attack showed the same result:

```
ORDER #8: Player 2 attacks terr 1 (successful)
  LatestTurnStanding says terr 1 owner = Player 1474980 (the defender)
  Expected after successful attack: Player 2
  VERDICT: STALE
```

This was reproduced consistently across 5+ successful attacks in a single
turn. Failed attacks correctly showed no ownership change.

### Correction

In `_End`, `LatestTurnStanding` IS fully up-to-date (reflects all orders).

The `order` and `orderResult` parameters in `_Order` are always current and
accurate for the order being processed. Use these to correct for the
one-order lag when needed.

### Impact on ENGINE_FLOW.md

`ENGINE_FLOW.md` section 2 describes `LatestTurnStanding` as "UPDATED" before
`_Order` fires. This is incorrect. The correct model is:

```
FOR EACH order in engine-decided sequence:
  1. Engine calls Server_AdvanceTurn_Order
       LatestTurnStanding = state after order N-1 (STALE)
       order / orderResult = current order N (ACCURATE)
  2. Engine applies order N to the standing
  3. Move to next order
```

---

## 2. addNewOrder Inserts Immediately in _Order

**Status**: Proven

When `addNewOrder` is called from `_Order`, the inserted order becomes the
very next order processed. No player orders slip in between.

### Evidence

Inserted a dummy `GameOrderEvent` via `addNewOrder` after a successful
attack at order #5. The dummy arrived as order #6, before the remaining
player orders (#7–#13):

```
ORDER #5: Successful attack → dummy inserted
ORDER #6: GameOrderEvent (our dummy) ← IMMEDIATE
ORDER #7: Player attack (regular order)
ORDER #8: Player attack (regular order)
...
```

Tested with queued player orders remaining after the insertion point.
The dummy always arrived as the very next order.

### Implication

The real-game bug where a player order appeared between elimination detection
and the ASSASSIN WIN event was NOT caused by addNewOrder being delayed.
It was caused by late detection (see finding #3).

---

## 3. GameOrderStateTransition Does NOT Trigger _Order

**Status**: Proven

When the engine eliminates a player (e.g. "spedoink was eliminated!"), it
generates a `GameOrderStateTransition` event. This event appears in the game
log but does NOT trigger a `Server_AdvanceTurn_Order` call.

### Evidence

Diagnostic logging captured every `_Order` call with its `order.proxyType`.
In a turn where "AI 3 was eliminated!" appeared in the game log, no
`GameOrderStateTransition` proxyType was ever logged. All logged order types
were `GameOrderDeploy`, `GameOrderAttackTransfer`, or `GameOrderEvent`.

### Impact

Mods cannot react to eliminations at the moment they happen. Detection via
`player.State` is delayed — the state updates sometime between the causal
order and the next `_Order` call:

```
Game log sequence           _Order called?    player.State
─────────────────           ──────────────    ────────────
Attack kills last terr      YES               Still "Playing"
"X was eliminated!"         NO                Updating...
Next player's order         YES               Now "Eliminated"
```

This means when we first detect an elimination in `_Order`, it's actually
one (or more) orders after the elimination happened. The current order
may have changed territory ownership that LatestTurnStanding hasn't
reflected yet (finding #1). Both delays compound.

---

## 4. player.State Is Delayed for Commander Cascades

**Status**: Confirmed

When a commander dies in a failed attack, `player.State` is still `2`
(Playing) on the `_Order` call where the commander dies. It updates to
`3` (Eliminated) by `_End`, or by the next `_Order` call.

---

## 5. order.StandingUpdates Crashes

**Status**: Confirmed

Accessing `order.StandingUpdates` (documented on the `GameOrder` base class
in `Annotations.lua`) silently kills the entire `_Order` hook on Warzone
proxy objects. Do not use this field.

---

## 6. Mod.PublicGameData Persists Between _Order Calls

**Status**: Proven

Data written to `Mod.PublicGameData` in one `_Order` call is readable in
subsequent `_Order` calls within the same turn. Can be used to accumulate
state across orders.

---

## The Assassin Stale-Territory Bug

### Symptom

In game 43769215, when the Assassin mod detected a winner and neutralized
all non-winner territories, player Badgersass9 captured Albona between
detection and neutralization. Albona was missed by the TerritoryModifications
and Badgersass9 survived when they should have been eliminated.

### Root Cause (two delays compounding)

1. **Detection delay**: The attack that eliminated spedoink fired `_Order`,
   but `player.State` was still "Playing". The engine's
   `GameOrderStateTransition` did NOT trigger `_Order`. Our mod didn't
   detect the elimination until Badgersass9's order (the next `_Order`
   call), by which time Badgersass9 had already captured Albona.

2. **Stale standing**: When we detected at Badgersass9's order,
   `LatestTurnStanding` was one order behind — it didn't include
   Badgersass9's capture of Albona. Our TerritoryModifications were built
   from this stale view and missed Albona.

`addNewOrder` inserted the ASSASSIN WIN event immediately (proven), so no
orders slipped in after detection. The problem was entirely in what we
detected and what standing we read.

### Fix

In `EndGameIfWinnerLatched`, when called from `_Order`, check if the current
order is a successful attack. If so, override the stale standing's owner for
that territory with the actual new owner from `order.PlayerID`. This ensures:

- Non-winner captures get neutralized (even though the stale standing missed them)
- Winner captures are protected (not accidentally neutralized)

When called from `_End`, no correction is needed — the standing is current.

---

## Test Setup

All findings were tested locally using the Warzone mod editor with the Mod
Development Console for `print()` output. Test games used 4 AI players on a
small map (4–6 territories). The diagnostic code was a stripped-down version
of `Server_AdvanceTurn.lua` that logged every order's type, territory
ownership snapshots, and addNewOrder insertion timing.
