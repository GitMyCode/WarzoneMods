# Limited Private Diplomacy

A Warzone mod that makes private communication scarce, visible, and strategic.

## Mechanic

- The mod adds a configurable **Communication Card** to the normal Warzone Cards UI.
- When a player plays the card, a dialog opens.
- The sender chooses one active recipient and writes a private message.
- The card resolves late in the turn.
- The recipient can read the message in their mod inbox after the turn advances.
- The sender keeps a sent copy.
- Everyone sees metadata: who sent a private message to whom.
- Message contents are not stored in public game data or public event text.

## Gameplay goal

Private diplomacy becomes a scarce, visible action. Players can still negotiate, bluff, deceive, and signal, but every private conversation leaves public metadata that other players can reason about.

## Warzone limitation

Warzone mods can change normal game settings in `Server_Created`, so this mod automatically disables built-in private messaging there by default. After creation, private diplomacy should happen through Communication Cards.

## Configuration

Hosts can configure:

- pieces required for a whole Communication Card;
- minimum card pieces received per turn;
- initial card pieces;
- card weight;
- maximum message length;
- whether built-in private messaging is automatically disabled at game creation.
