# Bounty Dynamic Bonus Plan

## Context
- The `Bounty/` mod currently grants a fixed army income reward (`Mod.Settings.BountyReward`, default `10`) whenever an elimination is attributed.
- Rewards are granted in `Bounty/Server_AdvanceTurn.lua` via `WL.IncomeMod.Create`, which matches `ENGINE_FINDINGS.md` guidance to avoid reinforcement-card crashes.
- The requested change is to let game creators choose between the existing fixed reward and a growing reward where each awarded kill increases the next bounty (example: `100, 120, 144, 172.8...`).
- Confirmed product choices: escalation is global for the whole game, the growth percentage is configurable with a default of `20%`, values are rounded to the nearest whole army, and the configure UI should preview 5 values.
- The game menu should preview the next bounty value, and the configuration UI should show an example sequence.

## Approach
- Add a reward mode setting with readable labels: `Fixed bounty` vs `Escalating bounty`.
- Keep the existing base reward setting (`BountyReward`) as both the fixed reward amount and the first/starting escalating bounty.
- Add `BountyEscalationPercent` with a default of `20` as a whole-number percentage (UI slider `0..100`, hard validation `0..1000`).
- Calculate escalating rewards from the exact formula `base * (1 + percent / 100) ^ rewardsGranted`, then round the displayed/granted value to the nearest whole army. This avoids compounding rounding drift.
- Store a global `BountyEscalatingRewardCount` (number of successful bounty rewards already granted) in `Mod.PublicGameData`, so server reward grants and client menu previews agree.
- Advance the global count only when an escalating bounty is actually granted to a killer; uncredited eliminations and zero-value rewards do not advance it.
- Keep all actual bounty grants server-side and continue using `WL.IncomeMod` inside `GameOrderEvent`.

## Files to modify
- `Bounty/Util/BountyReward.lua` — new shared helper file for settings defaults, mode names, rounding, reward calculation, and preview formatting; required from each changed client/server hook that needs reward calculations.
- `Bounty/Client_PresentConfigureUI.lua` — add mode controls, percentage control, and generated sequence preview.
- `Bounty/Client_SaveConfigureUI.lua` — persist/validate new settings while preserving old fixed-reward behavior.
- `Bounty/Client_PresentSettingsUI.lua` — describe selected reward mode and escalation settings.
- `Bounty/Client_PresentMenuUI.lua` — show next bounty value during the game.
- `Bounty/Server_AdvanceTurn.lua` — calculate current reward, grant it, then update escalation state.
- `Bounty/Server_Created.lua`, `Bounty/Server_StartDistribution.lua`, `Bounty/Server_StartGame.lua` — initialize public bounty state defensively if needed.
- `Bounty/ModDescription.txt` — update public description to mention escalating rewards.

## Reuse
- Existing reward grant path: `Bounty/Server_AdvanceTurn.lua` `GrantEliminationReward(...)`.
- Existing non-negative setting readers: replace/centralize their behavior in shared bounty helpers instead of duplicating new logic.
- Existing `Mod.PublicGameData` initialization pattern in `Bounty/Server_Created.lua`, `Server_StartDistribution.lua`, and `Server_StartGame.lua`.
- Warzone engine/API guidance from `ENGINE_FINDINGS.md`: use `WL.IncomeMod` for rewards and avoid stale `LatestTurnStanding` in `_Order`.
- UI API types from `Annotations.lua`: `CreateNumberInputField`, `CreateRadioButton`/`CreateRadioButtonGroup`, `CreateLabel`, and `SetText` are available. The preview should refresh from change handlers when the user toggles reward mode or changes numeric values.

## Steps
- [x] Add shared helper constants/functions: default reward (`10`), fixed/escalating mode keys, default escalation percent (`20`), non-negative number readers, nearest-integer rounding, `BountyCalculateReward(base, percent, rewardCount)`, `BountyNextReward(settings, publicData)`, and preview sequence formatting for 5 values.
- [x] Update configure UI to use a radio group for `Fixed bounty` / `Escalating bounty`, keep the base reward input, add an escalation percent input, and display an automatically refreshed 5-value example sequence.
- [x] Update save UI to validate base reward (`0..100000`), validate whole-number escalation percent (`0..1000` hard limit), persist `BountyRewardMode`, `BountyReward`, and `BountyEscalationPercent`, and default missing mode to fixed for backward compatibility.
- [x] Update settings UI to summarize either fixed rewards or escalating rewards (`starts at X, +Y% per rewarded elimination, rounded to nearest`).
- [x] Initialize `BountyEscalatingRewardCount = 0` defensively alongside existing public data fields without resetting it during normal turn hooks.
- [x] Refactor `GrantEliminationReward(...)` so the caller calculates the current bounty, grants that amount, and increments `BountyEscalatingRewardCount` only after a positive escalating reward is granted.
- [x] Update menu text to show fixed reward details or escalating details including `Next bounty: +N armies` and current reward number/count.
- [x] Update `ModDescription.txt` to mention fixed or escalating bonus armies rather than only a fixed reinforcement-card style reward.

## Verification
- Run Lua syntax checks on changed files with `luac -p` and then the whole repo syntax check.
- Manual Warzone test with fixed mode: confirm rewards stay at the configured amount and old behavior remains compatible.
- Manual Warzone test with escalating mode: configure base `100`, increase `20%`, confirm the preview shows `100, 120, 144, 173, 207`; first rewarded elimination grants `100`, menu then shows next bounty `120`, then `144`, etc.
- Manual multi-elimination check: if multiple players are eliminated in one hook pass, confirm each credited elimination consumes the next global bounty in sorted processing order.
- Manual menu/settings checks: verify the configure preview sequence, in-game next-bounty preview, and settings summary match the selected mode.
