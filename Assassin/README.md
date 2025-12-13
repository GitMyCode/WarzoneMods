# Warzone Assassin Mode (Mod)

Assassin Mode assigns every player a secret target at game start. The first player to eliminate their target wins.

## How It Works

- Targets are assigned once at game start (server-side) and stored in `Mod.PlayerGameData`.
- Each player sees their own target via:
  - a one-time popup when they open the game, and
  - the Mod menu button at any time.
- When a player eliminates their target, the mod ends the game by neutralizing all non-winner territories.

## Gameplay Notes

- You need at least 2 players for targets to be assigned.
- In multiplayer, client refresh timing can vary, so the mod uses a server custom message (`get_target`) to fetch your target immediately if it hasn’t arrived yet.

## Development Notes (LuaLS / Types)

This repo includes `Annotations.lua` so VS Code + LuaLS can provide Warzone Mod API types and autocomplete.

### VS Code setup

1. Install the Lua language server extension: https://marketplace.visualstudio.com/items?itemName=sumneko.lua
2. In settings, add the path to `Annotations.lua` under `Lua.workspace.library`.

Example `settings.json`:

```json
{
	"Lua.workspace.library": [
		"/absolute/path/to/warzone-assassin-mod/Annotations.lua"
	]
}
```

## Credits

Annotations made by [Just_A_Dutchman_](https://github.com/JustMe003)

Credits to [TBestLittleHelper](https://github.com/TBestLittleHelper) for helping me out
