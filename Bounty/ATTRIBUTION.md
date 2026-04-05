# Bounty — Kill Attribution Reference

How we determine who killed whom for each elimination scenario.

See [ENGINE_FLOW.md](../ENGINE_FLOW.md) for how the engine hook lifecycle works.

---

## Detection

Two methods run on every `_Order` call, in this order:

| Method | How | Catches | Misses |
|--------|-----|---------|--------|
| Territory count | `beforeCount > 0 && afterCount == 0` | Normal captures | Cascades, boots, failed attacks |
| player.State | `State ~= 2` | Everything | Possibly delayed by one or more orders |

Deduplicated via `processedEliminations` — once detected, not re-processed.
Persists across turns (a player can only be eliminated once).

Final sweep in `_End` catches anything both methods missed in `_Order`.

---

## Attribution Priority

Once an elimination is detected, resolve killer in this order:

```
1. Current order    →  direct causal link from the order that just executed
2. Trap             →  victim attacked a trapped territory (blockade/abandon)
3. Last-attacker    →  whoever last captured a territory from victim this turn
```

---

## Scenarios

### Last territory conquered

```
Trigger:   A attacks C's only remaining territory. Successful.
Detection: Territory count (C: 1 → 0)
Attribution:
  Priority 1 — order is attack on C's territory → killer = A  ✓
```

### Last territory conquered (multi-territory)

```
Trigger:   A attacks C's territory T3. C also had T1, T2 taken earlier this turn.
           T3 is C's last one.
Detection: Territory count (C: 1 → 0)
Attribution:
  Priority 1 — order is attack on C's territory → killer = A  ✓
  (A gets credit even if B took T1 and T2 — A took the last one)
```

### Commander kill (happy path)

```
Trigger:   A attacks T1 (C's commander). Successful.
           Engine cascades: C's other territories → Neutral, C eliminated.
Detection: Territory count misses it (BuildAfterOwners doesn't see cascade).
           player.State catches it (C.State ≠ 2).
Attribution:
  Priority 1 — order is attack on T1, beforeOwners[T1] = C = victim → killer = A  ✓
```

### Commander kill (delayed State)

```
Trigger:   A attacks T1 (C's commander). Cascade happens.
           But player.State not updated until a later _Order call.
Detection: Missed on A's order. Caught on a later order via player.State.
Attribution:
  Priority 1 — later order is unrelated (e.g. deploy) → nil
  Priority 2 — no trap (later order is not an attack on a trap) → nil
  Priority 3 — lastAttacker[C] = A → killer = A  ✓ (usually correct)

  RISK: if between A's order and detection, another player B "attacks"
  a territory we think is C's (stale beforeOwners due to cascade),
  lastAttacker gets overwritten → killer = B  ✗ (wrong)
```

### Trap kill (blockade/abandon + commander cascade)

```
Setup:     B plays Blockade on T5 → T5 becomes Neutral (big army stack).
           We record trap: T5 → B.
Trigger:   C attacks T5. C's commander dies in the battle.
           Engine cascades: all C's territories → Neutral, C eliminated.
Detection: Territory count misses it (BuildAfterOwners doesn't see cascade).
           player.State catches it (C.State ≠ 2).
Attribution:
  Priority 1 — order is attack on T5, but beforeOwners[T5] = Neutral ≠ C → nil
               (failed-attack branch: attacker = C = victim, defender = Neutral → nil)
  Priority 2 — ResolveTrapKiller: victim C is the attacker, target T5 has
               trap owned by B → killer = B  ✓
```

### Failed attack (attacker dies, commander cascade)

```
Trigger:   C attacks D's territory. C's commander dies in the battle.
           Engine cascades: all C's territories → Neutral, C eliminated.
Detection: Territory count misses it (BuildAfterOwners doesn't see cascade).
           player.State catches it (C.State ≠ 2).
Attribution:
  Priority 1 — order is attack, attacker IS victim (C = C),
               defender = D (beforeOwners[target]) → killer = D  ✓
```

### Boot / surrender / vote-to-boot

```
Trigger:   Engine eliminates C due to boot timer, surrender, or vote.
Detection: player.State catches it (territory count won't — no territory change).
Attribution:
  Priority 1 — current order is unrelated → nil
  Priority 2 — no trap → nil
  Priority 3 — lastAttacker[C] if anyone attacked C this turn → that player
               If no one attacked C → nil → NO BOUNTY AWARDED

  This is correct: no player "killed" them, so no reward.
```

### Elimination caught in `_End` only

```
Trigger:   Elimination not detected during any _Order call
           (e.g. cascade timing edge case).
Detection: _End sweep via player.State.
Attribution:
  Only lastAttacker available (no current order context in _End).
  lastAttacker[victim] → killer, or nil → no bounty.
```

---

## State Tracked Per Turn

| Key | Set in | Used for |
|-----|--------|----------|
| `BountyPrevOwnerByTerritory` | `_Start` (snapshot), updated each `_Order` | Before/after comparison |
| `BountyTrapOwnerByTerritory` | Persistent, updated on blockade/abandon | Trap attribution |
| `BountyProcessedEliminations` | `_Order` / `_End`, persists across turns | Deduplication |
| `BountyLastAttackerByVictim` | `_Order` on successful attacks, reset each turn | Fallback attribution |

---

## Known Limitations

1. **Commander cascade blindness** — `BuildAfterOwners` can't see cascade
   side-effects. Territory count misses these eliminations. Mitigated by
   `player.State` fallback.

2. **Last-attacker overwrite** — if multiple players attack the victim in the
   same turn and `player.State` is delayed, the wrong player may get credit.
   Requires cascade + delayed State + stale beforeOwners. Very unlikely.

3. **Boot/surrender with no attacker** — no bounty awarded. Intentional.

4. **LatestTurnStanding is one order behind** — tested and confirmed broken.
   Reading it in `_Order` gives stale data. `BuildAfterOwners` (manual
   deduction from order properties) is the only reliable approach.

---

## Open Questions

### Q1: Is `player.State` immediate on commander cascade?

**Context:** When a commander dies during an attack, the engine cascades all
of that player's territories to Neutral and eliminates them. `BuildAfterOwners`
can't see this cascade — it only knows about the single territory the order
targeted. If `player.State` is updated to `!= 2` on the **same** `_Order` call
where the cascade happens, we could use it to patch `afterOwners` (set all of
that player's territories to Neutral), making the rolling snapshot accurate.

**Why it matters:**
- If **immediate**: we can fix cascade blindness entirely. After
  `BuildAfterOwners`, check every player's State. If `!= 2`, set all their
  territories in `afterOwners` to Neutral. Territory count detection and
  last-attacker tracking both become accurate for cascades.
- If **delayed**: we stay dependent on the last-attacker fallback for
  cascade kills, which can be overwritten (Limitation 2).

**How to test:** Set up a game with commanders. Have player A attack player C's
commander territory. Look at the `[DIAG]` logs:
- Find the `_Order` call for A's attack on C's commander territory.
- Check `[DIAG]` line for C on **that same** `_Order` call.
- If `State != 2` → immediate. If `State == 2` → delayed (check which later
  `_Order` call shows the change).

**Status:** UNTESTED — diagnostic logging added, awaiting experiment.
