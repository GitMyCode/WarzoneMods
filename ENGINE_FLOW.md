# Warzone Mod Engine — Hook Lifecycle & Game State

How the Warzone engine calls mod hooks and when game state updates.

---

## 1. Shared Mutable State

The engine exposes **one live, mutable** state object — not copies:

```
game.ServerGame.LatestTurnStanding.Territories   -- who owns each territory
game.Game.Players[id].State                       -- 2 = Playing, other = eliminated
```

When the engine changes these, any subsequent read sees the new value.
There is no versioning or before/after snapshots provided to mods.

---

## 2. Turn Lifecycle

```
Engine collects all player orders for this turn
│
├──► Server_AdvanceTurn_Start(game, addNewOrder)
│       State: reflects end of PREVIOUS turn. No orders executed yet.
│       This is the one clean moment to snapshot.
│
├──► FOR EACH order in engine-decided sequence:
│    │
│    │  1. Engine EXECUTES the order
│    │     ─── state mutates HERE ───
│    │     LatestTurnStanding: UPDATED
│    │     Player.State:       UPDATED
│    │     Side-effects:       APPLIED (cascades, eliminations)
│    │
│    │  2. Engine calls the mod hook:
│    │     Server_AdvanceTurn_Order(game, order, orderResult, skip, addNewOrder)
│    │       game          ← live state (AFTER the order)
│    │       order         ← the order that just executed
│    │       orderResult   ← outcome (IsAttack, IsSuccessful, etc.)
│    │
│    │  3. Hook returns → engine moves to next order
│    │
│    └──► (repeat for every order)
│
└──► Server_AdvanceTurn_End(game, addNewOrder)
        State: reflects ALL orders executed this turn.
```

**Key point**: by the time `_Order` fires, the order has **already executed**.
We see the result, not a preview.

---

## 3. The Before/After Problem

To detect changes (e.g. eliminations), mods need state **before** vs **after**
each order. The engine only gives us the "after" — it overwrote the "before".

```
                engine executes           our hook fires
                ─────┬─────               ──────┬──────
                     │                          │
  ┌──────────┐       │       ┌──────────┐       │       ┌──────────┐
  │ BEFORE   │───────┘───────│ AFTER    │───────┘───────│ we read  │
  │ state    │  (overwrites) │ state    │               │ AFTER    │
  └──────────┘               └──────────┘               └──────────┘
       ▲                                                      ▲
       │                                                      │
    we need this                                      this is what
    to compare                                        LatestTurnStanding
                                                      gives us now
```

**Common pattern**: snapshot state in `_Start`, carry it forward through each
`_Order` call, updating after each.

```
Order 1:  before₁ ──[apply order 1]──► after₁
Order 2:  after₁ (now before₂) ──[apply order 2]──► after₂
Order 3:  after₂ (now before₃) ──[apply order 3]──► after₃
```

---

## 4. Two Ways to Get "After" State in `_Order`

### Option A — Reconstruct from order fields

Copy `beforeOwners`, apply the one change deducible from the order type.

**Pro**: doesn't depend on `LatestTurnStanding` reliability in `_Order`.
**Con**: misses engine side-effects (commander cascades, etc.).

### Option B — Read `LatestTurnStanding` directly

The engine already updated it. Just read it.

**Pro**: sees everything, including cascades and side-effects.
**Con**: assumes `LatestTurnStanding` is fully updated before `_Order` fires.

---

## 5. Elimination Detection — Two Methods

### Territory count

```
if player had > 0 territories before and 0 after → ELIMINATED
```

Directly tied to the current order — good for attribution.
Only as accurate as the "after" state (see Option A vs B above).

### player.State

```lua
if player.State ~= 2 then → ELIMINATED   -- 2 = Playing
```

Catches everything (cascades, boots, surrenders).
But doesn't tell you *which* order caused it.

```
                            Territory Count    player.State
                            ═══════════════    ════════════
Normal capture (last terr)    ✓ catches         ✓ catches
Commander cascade             depends¹          ✓ catches
Boot/surrender                ✗ misses          ✓ catches
Attribution accuracy          ✓ precise         ? heuristic

¹ Caught if using Option B (direct read). Missed if using Option A (reconstruct).
```

---

## 6. Open Question: Commander Cascade Timing

When a commander dies, the engine removes all of that player's territories.
We don't have engine source. Two possible timings:

### Possibility A — Cascade during order execution (before `_Order` fires)

All territory changes + elimination reflected in `LatestTurnStanding` when
our hook fires. Reading it directly would see everything.

### Possibility B — Cascade deferred to end of turn

Only the attacked territory changes immediately. Cascade and elimination
happen in a later engine pass (before `_End`).

**Evidence**: The Assassin mod checks `player.State` in both `_Order` AND
`_End`, suggesting either the author wasn't sure or encountered deferred
cascades. Bounty mod test logs showed `player.State` updated in the same
`_Order` call, supporting Possibility A — but this may vary by config.
