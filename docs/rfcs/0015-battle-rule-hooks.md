# RFC 0015: Battle rule hooks — `battle.style` and `catch.nickname`

## Status

Proposed.

## Motivation

Two decisions in a Red/Blue/Yellow battle are made for the player by the
OPTION screen and by the cart, and a game mode has no way to make them
instead:

**Whether a faint offers a free switch.** `EnemySendOutFirstMon` reads the
battle-style bit: SHIFT asks "will you change POKéMON?" when the foe's Pokémon
faints, SET does not. The engine reads `save.options.battleStyle` inline at
that moment. A mode that wants SET — a tournament, a Nuzlocke, a battle royale
where party-as-health is the whole design — can only get it by writing the
player's saved preference, which leaks into their real playthrough the first
time anything calls `Game:writeOptions` (the speed hotkey does, on every
press).

**Whether a catch asks for a nickname.** `AddPartyMon` and `SendNewMonToBox`
both run `AskName` after a capture. A mode with a disposable team, a
randomizer that names what it hands out, a speedrun practice mod — all want to
answer that prompt themselves, and the only way today is to drive the yes/no
box from outside. The script-gift path already has this seam: a mod that sets
`gift.nickname` on `pokemon.before_give` skips `AskName`. The catch path does
not.

The immediate consumer is a battle-royale mode; neither hook is specific to it.

## The decision it extends

This extends the **additive, guarded seam convention** Route B in
`CONTRIBUTING-mods.md` documents, and is gated by the parity guarantee
`tests/engine/gate_meta_coverage.lua` enforces. `catch.nickname` mirrors a
contract that already exists for gifts (`pokemon.before_give`'s
`gift.nickname`), so the two ways a Pokémon joins the party answer the same
question the same way.

There is no in-repo D-number registry to amend.

## Exact API delta

### New hook: `battle.style`

```lua
mod.hooks:wrap("battle.style", function(next, battle)
  if myMode.active then return "set" end
  return next(battle)           -- the OPTION row, as today
end)
```

Call site: `BattleState:battleStyle()`, called from the enemy send-out path at
the moment the SHIFT prompt would be offered. The vanilla link reads
`save.options.battleStyle` (lower-cased, default `"shift"`) exactly as the
inline read did. A return of `"set"` or `"shift"` is used; anything else reads
as the vanilla answer, so a hook that returns nothing by mistake cannot change
the rule. The player's saved preference is never written.

### New hook: `catch.nickname`

```lua
mod.hooks:wrap("catch.nickname", function(next, mon, ctx)
  -- ctx = { battle = <BattleState>, name = <display name>, game = <Game> }
  if myMode.active then return false end          -- keep the species name
  if randomizer then return pickName(mon) end     -- a string names it
  return next(mon, ctx)                           -- true: ask, as today
end)
```

Call site: `BattleState:offerNickname(mon, displayName)`, called from the
capture path where `AskName` ran, before the prompt is queued. The vanilla
link returns `true`. `false` skips the prompt and keeps the species name; a
string skips the prompt and is the nickname, clipped to the naming grid's ten
characters (an empty string names nothing, like the grid's own empty entry);
anything else queues the prompt as today. The method returns whether a prompt
was queued.

### No other surface changes

Both call sites are guarded by `Runtime.wantsHook`, and both vanilla links are
file-local functions, so a build with nothing wrapped runs the branch exactly
as before and allocates nothing it did not allocate before. `askNicknameUI` is
unchanged and still public.

## Migration

Nothing changes for existing mods. A mod that was writing
`save.options.battleStyle` to force a style should wrap `battle.style` instead
and stop writing the option.

## Verification

- `tests/modkit/cases/battle_rule_hooks.lua` — through the public mod API: the
  no-mod answers match the OPTION row and the cart's AskName; a wrapped mod
  forces either style without the row being written; `false`, a string, a
  too-long string, an empty string, and a fall-through each do what this RFC
  says at the catch prompt.
- `tests/engine/gate_hooks.lua` — both names are in the live catalog and pass
  the no-mod parity gate (vanilla called exactly once, result unchanged,
  nothing allocated).
- `tests/engine/gate_meta_coverage.lua` — both names are covered by the unit
  corpus.

## Backward compatibility

Additive. No existing hook, event, registry or manifest field changes shape.
The two new methods on `BattleState` are called only from the paths that
previously inlined their logic; the results with no subscriber are identical.
