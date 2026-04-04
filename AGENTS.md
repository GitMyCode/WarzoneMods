# AGENTS.md

This repository contains a Warzone mod named `Assassin`.
Use this file as the default operating guide for agentic coding work in this repo.

**Scope**
This guidance applies to the whole repository.
The playable mod lives in `Assassin/`, and `Annotations.lua` provides Warzone API types for LuaLS and editor assistance.

**Instruction Sources**
Repository-specific agent guidance already exists in `.github/copilot-instructions.md`.
No `.cursorrules` file was found.
No `.cursor/rules/` directory was found.
This file incorporates the useful parts of the Copilot instructions and adds command/style guidance.

**Repository Layout**
`Assassin/Server_*.lua` contains server-side Warzone hooks.
`Assassin/Client_*.lua` contains client hooks and UI.
`Assassin/Util/` contains shared helpers and imported utility code.
`Assassin/README.md` explains the mod behavior and LuaLS setup.
`Assassin/ModDescription.txt` is the in-game mod description.
`Annotations.lua` provides Warzone API types for LuaLS.
`.vscode/settings.json` shows the intended editor setup.

**Important Files**
Start with `Assassin/Server_StartGame.lua` and `Assassin/Server_StartDistribution.lua` for initial target assignment.
Use `Assassin/Server_AdvanceTurn.lua` for elimination and winner resolution.
Use `Assassin/Server_GameCustomMessage.lua` and `Assassin/Client_GameRefresh.lua` for server/client synchronization and popup timing.
Use `Assassin/Client_PresentMenuUI.lua` and `Assassin/Util/AssassinUtil.lua` for the menu and shared Assassin-specific logic.

**Build / Run / Validation Commands**
There is no build system in this repo and no `package.json`, `Makefile`, rockspec, or CI workflow.
There is no automated test framework checked in, so there is also no single-test command.

Use these commands as the practical validation baseline:

```bash
# Syntax check one Lua file
luac -p Assassin/Server_StartGame.lua

# Syntax check another file you changed
luac -p Assassin/Client_GameRefresh.lua

# Syntax check every Lua file in the repo
zsh -c 'set -e; for f in **/*.lua(N); do luac -p "$f"; done'
```

Manual runtime testing is required in Warzone.
Per `Assassin/README.md` and `.github/copilot-instructions.md`, there is no build step.
To run the mod manually, load the `Assassin/` folder in the Warzone mod editor or place it in the local Warzone mods directory.

**Single-Test Guidance**
No automated single-test runner exists.
When asked to run a single test, interpret that as one targeted manual scenario in Warzone and pick the smallest scenario that covers the change.

Recommended manual scenarios:
1. Start a 2+ player game and confirm targets are assigned once.
2. Open the game as a player and confirm the target popup appears once.
3. Open the Mod menu and confirm the same target is shown there.
4. Eliminate the assigned target and confirm the winner is latched and other territories are neutralized.
5. Open the game as a spectator and confirm no client custom-message failure occurs.

**Editor / Linting Setup**
The repo expects LuaLS-aware editing.
`.vscode/settings.json` sets `Lua.runtime.version` to `LuaJIT` and enables Lua diagnostics.
`.vscode/settings.json` disables LuaLS formatting and enables format-on-save with `JohnnyMorganz.stylua` as the Lua formatter.
`.vscode/settings.json` includes `Annotations.lua` in `Lua.workspace.library`.

Use `Annotations.lua` instead of inventing local stubs for Warzone API objects.
If you use VS Code or LuaLS, make sure `Annotations.lua` stays in the workspace library.
If you use a formatter, review the diff carefully because the repo mixes styles across files.

**Formatting Rules**
Match the style of the file you are editing.
Do not normalize unrelated files just to make style uniform.
Main Assassin gameplay files generally use tabs and omit semicolons.
Some imported utility files in `Assassin/Util/` use spaces and semicolons.
Preserve that distinction unless you are intentionally refactoring the whole file.
Keep functions and conditionals compact and readable, prefer early returns over deep nesting, and keep comments short.

**Imports / Module Loading**
Put `require(...)` calls at the top of the file.
Follow existing require path style in the file you are touching.
Assassin-specific code typically uses slash-separated requires like `require("Util/AssassinUtil")`.
Some older utility bundle files use dot-separated or bare-name requires; do not rewrite them unless needed.
Prefer putting shared Assassin-specific helpers in `Assassin/Util/`.
Do not create a new helper file for a tiny one-off unless reuse is clear.

**Types / Annotations**
Keep existing EmmyLua / LuaLS annotations.
Use `---@param`, `---@return`, and `---@type` when they add clarity, and keep hook parameter annotations intact.
Use Warzone API types from `Annotations.lua` where possible.
Add annotations for non-obvious helper functions, table shapes, and callback arguments.
Do not add noisy annotations for trivial locals.

**Naming Conventions**
Warzone hook filenames and function names must match exactly.
Examples: `Server_StartGame.lua` defines `Server_StartGame`, and `Client_GameRefresh.lua` defines `Client_GameRefresh`.
Do not invent new global hook names; use `Server_*` for server hooks and `Client_*` for client hooks.
Assassin-specific shared helpers commonly use PascalCase names such as `AssignTargets` and `SaveTargets`.
Some generic utility files use lowercase or camelCase names; preserve existing local conventions in those files.
Use descriptive local variable names like `publicData`, `playerData`, `targetID`, and `winnerID`.
State keys in mod data are currently PascalCase, for example `Target`, `PopupShown`, `AssassinWinnerID`, and `AssassinTargetsAssigned`.
Do not rename persisted keys casually.

**State Management**
`Mod.PlayerGameData` is the main per-player persistent store; on the server it is treated as a table keyed by `PlayerID`.
On the client, the current player's portion is exposed directly as `Mod.PlayerGameData`.
`Mod.PublicGameData` is the main game-wide persistent store.
Use it for global flags and latched endgame state.
Keep state writes explicit and local to the logic that owns them.
Initialize missing mod-data tables defensively before writing into them.
Do not scatter writes to the same flag across unrelated hooks.

**Hook and Flow Conventions**
Preserve the current hook split.
Target assignment happens at startup in `Server_StartDistribution` and `Server_StartGame`, while winner detection lives in `Server_AdvanceTurn_Start`, `Server_AdvanceTurn_Order`, and `Server_AdvanceTurn_End`.
Immediate client/server synchronization uses `SendGameCustomMessage` on the client and `Server_GameCustomMessage` on the server.
Keep client UI logic in client hook files.
Keep actual game-state mutation on the server side.
If you add shared gameplay logic, prefer `Assassin/Util/AssassinUtil.lua` instead of duplicating it across hooks.

**Error Handling and Logging**
Prefer guard clauses and nil checks over thrown errors in gameplay hooks.
Main mod code currently returns early when expected data is missing and uses defensive checks for spectator mode, missing players, missing targets, and missing mod state.
Use `print(...)` for debugging/logging on the server side.
Prefer the existing `[Assassin]` prefix for new log messages, and use `UI.Alert(...)` only for player-facing client messages.
Do not add hard failures to normal gameplay paths unless the API contract truly requires it.
The generic timer utility throws errors, but that is not the dominant pattern for Assassin gameplay code.

**Editing Guidance**
Keep changes small and specific.
Prefer extending existing functions over introducing extra layers of abstraction for simple logic.
Avoid broad refactors unless they directly support the requested change.
Do not change the Warzone hook lifecycle structure without a concrete reason.
Do not remove debug logging that still helps explain gameplay flow unless it is clearly noisy or misleading.
If you touch both client and server behavior, verify the custom-message flow still matches on both sides.
Be careful with spectator behavior, and be careful with winner latching because the current logic stores winner info before the neutralization order is emitted.

**What To Verify After Changes**
Run `luac -p` on every changed Lua file, and run the full-repo syntax check for multi-file changes.
Manual-test the narrowest Warzone scenario that exercises the change.
If you changed target assignment, verify targets are saved in `Mod.PlayerGameData` and only assigned once.
If you changed popup behavior, verify popup persistence and menu display agree.
If you changed endgame logic or custom messages, verify `Mod.PublicGameData` winner flags and the client/server payloads still line up.

**Agent Summary**
This is a small Lua Warzone mod, not a compiled application.
There is no build pipeline and no automated tests.
The best automated validation available in-repo is Lua syntax checking with `luac -p`, and most correctness checking still requires a focused manual Warzone scenario.
Follow existing hook names, keep state management explicit, and preserve local file style.
