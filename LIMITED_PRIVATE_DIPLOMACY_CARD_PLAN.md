# Limited Private Diplomacy — Card-Based Revision Plan

## Context

The current implementation sends messages from the Mod menu via `SendGameCustomMessage`, which is not the intended UX. The desired mechanic is a real Warzone custom card: when a player plays a Communication/Diplomacy card, a card-specific dialog opens, the player chooses one recipient and writes the message, and the message is delivered/resolved through the normal turn order. The Mod menu should mainly be an inbox/history viewer, not the sending surface.

Warzone limitation remains: mods cannot intercept or limit built-in private chat. The mod will continue to require/disclose that built-in private messaging should be disabled for the intended experience.

## Approach

Replace the token-send UI with a custom card flow:

1. Create a **Communication Card** with `addCard(...)` in `Client_SaveConfigureUI.lua`, storing its returned ID in `Mod.Settings.CommunicationCardID`.
2. Configure scarcity through normal Warzone card settings: pieces per whole card, pieces gained per turn/minimum pieces, initial pieces, and card weight.
3. Use `Client_PresentPlayCardUI.lua` to open a dialog when the Communication Card is played:
   - select one active recipient;
   - type a message;
   - validate non-empty and max length;
   - call `playCard(...)` with public order text like `Alice sends a private diplomacy message to Bob` and hidden `ModData` carrying recipient ID + message;
   - set phase to `WL.TurnPhase.CardsWearOff` so these diplomacy events resolve at the end of the turn.
4. In `Server_AdvanceTurn_Order`, detect `GameOrderPlayCardCustom` for `CommunicationCardID`, parse the payload, then:
   - append public metadata to `Mod.PublicGameData.CommunicationLog`;
   - append the message content to recipient inbox and sender sent history in `Mod.PlayerGameData`;
   - add a public `GameOrderEvent` announcing only the metadata.
5. Keep `Client_GameRefresh.lua` notification behavior so recipients get a popup after the turn refreshes.
6. Keep `Client_PresentMenuUI.lua` as inbox/sent/public-log viewer, removing the send form.

## Files to modify

- `CommunicationCard/Client_PresentPlayCardUI.lua` — new card dialog for recipient + message.
- `CommunicationCard/Client_SaveConfigureUI.lua` — create/register custom Communication Card.
- `CommunicationCard/Client_PresentConfigureUI.lua` — replace token settings with card-piece/card-weight settings plus max message length/private-chat requirement.
- `CommunicationCard/Client_PresentSettingsUI.lua` — show card distribution and message settings.
- `CommunicationCard/Server_AdvanceTurn.lua` — resolve played communication-card orders and deliver messages.
- `CommunicationCard/Server_GameCustomMessage.lua` — keep only `mark_read`; remove immediate `send_message` action.
- `CommunicationCard/Client_PresentMenuUI.lua` — remove send form; keep inbox/sent/public diplomacy log.
- `CommunicationCard/Util/CommunicationUtil.lua` — add payload encode/decode helpers and card-setting helpers.
- `CommunicationCard/ModDescription.txt` and `CommunicationCard/README.md` — update UX description from token menu action to card-based action.

## Reuse

Patterns found in `/Users/marma/dev/warzone-mods-crawler/repos`:

- `FizzerWL/ExampleMods/SmokeBombCardMod/Client_PresentPlayCardUI.lua` — opens a custom card dialog and calls `playCard(...)` with `ModData`.
- `FizzerWL/ExampleMods/SmokeBombCardMod/Server_AdvanceTurn.lua` — detects `GameOrderPlayCardCustom` in `Server_AdvanceTurn_Order` and converts it into a public `GameOrderEvent`.
- `JustMe003/WarzoneMods/Forced LD Card/Client_PresentPlayCardUI.lua` — player-target selection for a custom card and duplicate-target checking in `game.Orders`.
- `JustMe003/WarzoneMods/Forced LD Card/Client_SaveConfigureUI.lua` — stores the returned custom card ID in `Mod.Settings.CardID`.
- Existing `CommunicationCard/Client_GameRefresh.lua` — recipient notification/inbox alert can be reused with minimal changes.
- Existing `CommunicationCard/Util/CommunicationUtil.lua` — player resolution, formatting, public/private log helpers can be retained and extended.

## Steps

- [ ] Add card distribution defaults/constants and getters in `CommunicationUtil.lua`.
- [ ] Add `CommCreatePayload(recipientID, message)` and `CommParsePayload(payload)` helpers using a mod-specific prefix.
- [ ] Update configure UI to expose card settings: pieces for whole card, pieces per turn/minimum pieces, initial pieces, card weight, max message length, and built-in-PM requirement.
- [ ] Update save configure hook to validate settings and call `addCard("Communication Card", ..., "CommunicationCard.png", ...)`.
- [ ] Implement `Client_PresentPlayCardUI` dialog:
  - [ ] ignore cards whose ID is not `Mod.Settings.CommunicationCardID`;
  - [ ] close the card picker if `closeCardsDialog` is available;
  - [ ] present recipient list and message text field;
  - [ ] validate recipient/message;
  - [ ] call `playCard(publicMetadataText, payload, WL.TurnPhase.CardsWearOff)`.
- [ ] Move send logic from `Server_GameCustomMessage` into `Server_AdvanceTurn_Order` for played custom card orders.
- [ ] Keep public event content metadata-only; never include message body in `Mod.PublicGameData` or `GameOrderEvent.Message`.
- [ ] Keep `Server_GameCustomMessage` for `mark_read` only.
- [ ] Simplify the Mod menu to inbox, sent messages, public log, and reminder about built-in chat limitation.
- [ ] Update README and mod description.

## Verification

- Run Lua syntax check: `zsh -c 'set -e; for f in CommunicationCard/**/*.lua(N); do luac -p "$f"; done'`.
- Create a local test game with built-in private messaging disabled.
- Confirm the Communication Card appears in the normal Warzone card UI.
- Play the card as Player A:
  - dialog opens;
  - Player A selects Player B and writes a message;
  - order list shows only metadata, not content.
- Advance the turn:
  - public game log/event says Player A sent a private diplomacy message to Player B;
  - Player B gets a notification and can read content in inbox;
  - Player A can see the sent copy;
  - other players can see only metadata/public log.
- Confirm no mod-menu send path remains.
