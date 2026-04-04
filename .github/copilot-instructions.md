```markdown
# Copilot / AI Agent Instructions — WarzoneMods / Assassin

Purpose: Help an AI agent quickly understand project structure, conventions, and useful code locations for Warzone mod development.

**Quick Setup**

- **LuaLS**: This repo includes `Annotations.lua` to enable Warzone API types. See [Assassin/README.md](Assassin/README.md#L1-L40) for VS Code settings example.

**Project Layout & Patterns**

- **Mod entrypoints**: Server scripts use `Server_*` hooks and client scripts use `Client_*`. See examples: [Assassin/Server_StartGame.lua](Assassin/Server_StartGame.lua#L1-L40) and [Assassin/Server_AdvanceTurn.lua](Assassin/Server_AdvanceTurn.lua#L1-L120).
- **State storage**: Two primary Mod-level stores are used:
  - `Mod.PlayerGameData` — per-player persistent data (targets saved here).
  - `Mod.PublicGameData` — game-wide flags (e.g. `AssassinTargetsAssigned`, `AssassinWinnerID`).
- **Utilities**: Shared helpers live under `Assassin/Util/` (e.g., `Assassin/Util/AssassinUtil.lua`) — prefer putting cross-file logic here.
- **Messaging**: Server→client custom messages are used for immediate sync (example: `get_target` used in README/handlers). Follow existing call patterns in `Client_*` files.

**Common Code Patterns (examples to reuse)**

- Assign targets once in `Server_StartGame` and persist via `SaveTargets(...)` into `Mod.PlayerGameData` — see [Assassin/Server_StartGame.lua](Assassin/Server_StartGame.lua#L1-L40).
- End-game logic is latched in `Mod.PublicGameData` and enacted on `Server_AdvanceTurn_End` using `WL.TerritoryModification` — see [Assassin/Server_AdvanceTurn.lua](Assassin/Server_AdvanceTurn.lua#L1-L120).
- Use `require("Util/AssassinUtil")` for shared helper functions; match existing require-style paths.

**Development & Testing Notes (discoverable)**

- No build step: this is a Lua mod; to test, place the `Assassin` folder into the Warzone mods directory or use the Warzone mod editor. For editor/IDE help, enable `Annotations.lua` in your `Lua.workspace.library`.
- Follow file naming conventions: `Client_*` for client hooks and UI, `Server_*` for server hooks and turn logic.

**When Editing or Adding Code**

- Keep side effects explicit: update `Mod.PlayerGameData` or `Mod.PublicGameData` only where intent is clear (assignment, save, end-game latch).
- Preserve existing hooking patterns (`Server_AdvanceTurn_Start`, `_Order`, `_End`) rather than introducing new global hook names.

**Where to Look First**

- Initialization & target assignment: [Assassin/Server_StartGame.lua](Assassin/Server_StartGame.lua#L1-L40)
- Turn processing & end-game: [Assassin/Server_AdvanceTurn.lua](Assassin/Server_AdvanceTurn.lua#L1-L120)
- Developer notes & LuaLS setup: [Assassin/README.md](Assassin/README.md#L1-L50)

If anything here looks incomplete or you'd like more examples (message handlers, specific util functions), tell me which area to expand.
```
