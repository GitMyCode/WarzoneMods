# Bounty Scaling Plan

## Context
- `Bounty/` grants bonus armies through `WL.IncomeMod` when an elimination is attributed.
- The mod now supports multiple bounty scaling styles instead of replacing the original global escalating bounty.

## Implemented modes
- `Fixed bounty`: every credited elimination pays the same configured amount.
- `Global bounty growth`: previous global escalation behavior; every credited elimination increases the bounty paid by future eliminations for everyone.
- `Kill-count bounty growth`: every player starts at the base bounty; a player's bounty is based on their own credited kill count, so two players with three kills have the same bounty.
- `Stacking bounty`: every player starts at the base bounty; when a player eliminates someone, the eliminated player's bounty is added to the killer's own bounty.

## Growth configuration
- Global growth and kill-count growth can use either:
  - Flat armies per kill, e.g. `20, 45, 70, 95` with `+25`.
  - Percentage per kill, e.g. `20, 24, 29, 35` with `+20%`, rounded to nearest.
- Stacking bounty does not use the flat/percent growth setting; it adds the victim's current bounty directly.

## State
- `Mod.PublicGameData.BountyEscalatingRewardCount` stores global credited elimination count.
- `Mod.PublicGameData.BountyKillCountsByPlayer` stores credited kills per player.
- `Mod.PublicGameData.BountyInheritedBountyByPlayer` stores current stacked bounty values per player.

## Main files
- `Bounty/Util/BountyReward.lua` — settings defaults, mode helpers, growth helpers, per-player state helpers, bounty calculation, preview formatting.
- `Bounty/Client_PresentConfigureUI.lua` — four mode options, flat/percent growth controls, preview.
- `Bounty/Client_SaveConfigureUI.lua` — validation and persistence.
- `Bounty/Client_PresentSettingsUI.lua` — game settings summary.
- `Bounty/Client_PresentMenuUI.lua` — current bounty display.
- `Bounty/Server_AdvanceTurn.lua` — pays victim/global bounty and applies the selected post-kill growth.
- `Bounty/ModDescription.txt` — player-facing description.

## Verification
- `luac -p` on changed Lua files.
- Full repo syntax check: `zsh -c 'set -e; for f in **/*.lua(N); do luac -p "$f"; done'`.
- Manual Warzone scenario examples:
  - Fixed: bounty remains constant.
  - Global growth: every credited kill increases the next bounty for everyone.
  - Kill-count flat: starting `20`, flat `25`; a player with 3 kills is worth `95`.
  - Stacking bounty: starting `20`; if A kills B, A becomes worth `40`; if C kills A, C becomes worth `60`.
