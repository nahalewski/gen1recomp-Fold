# RFC 0019: `pokemon.level_visible` — a level a mode can take off the screen

## Status

Proposed.

## Motivation

A Pokémon's level is printed on four Gen 1 surfaces — both battle
healthboxes, the party rows, and page 1 and page 2 of the status screen —
and every one of them prints it unconditionally. There is no seam. A mode
that wants the number gone has exactly two options today, and both are bad.

It can paint over the text from `render.hud`, which means knowing four pixel
rectangles, matching the background shade, and surviving the palette flashes
and the healthbox slide-in. Or it can monkey-patch the drawing modules from
inside its sandbox, which works — `require` hands a mod the engine's own
table — and is precisely what `CONTRIBUTING-mods.md` tells mods not to do.
A mod that took the second road already deleted its patching layer once, for
the reasons that document gives.

The motivating case is a battle royale where every party is scaled to a
shared rung that rises with the fog. The number on the healthbox is
therefore never news — it is the same for everyone, it changes on a clock,
and a player reading `:L37` on an opponent learns nothing except that they
are playing the same match. Worse, it reads as a threat it is not: a Lv37
opponent looks dangerous to a player who has not worked out that their own
team is Lv37 too. The mode wants the level off the HUD and out of the party
list, and the announcement it replaces it with is one line about everyone
getting stronger at once.

Nothing about that is specific to a battle royale. A randomizer that hides
levels to keep an encounter unreadable, a challenge run that forbids
level-checking, a hard mode that withholds an opponent's level, and a
"blind" Nuzlocke all want the same switch, and none of them should have to
learn where the `<LV>` glyph lives.

## The decision it extends

This extends the **additive, guarded seam convention** Route B in
`CONTRIBUTING-mods.md` documents, and is gated by the parity guarantee
`tests/engine/gate_meta_coverage.lua` enforces.

It sits with the presentation predicates already on the battle screen —
`battle.status_hud_visible`, `battle.bottom_ui_visible` and
`battle.caught_marker_visible` — and takes the same shape: a hook consulted
behind `Runtime.wantsHook`, defaulting to visible, where only an explicit
`false` suppresses. The difference is that a level is not a battle-only
readout, so this one is not named `battle.*` and carries the surface that
asked.

There is no in-repo D-number registry to amend.

## Exact API delta

### New hook: `pokemon.level_visible`

```lua
mod.hooks:wrap("pokemon.level_visible", function(next, mon, ctx)
  -- ctx = { where = "battle.enemy" | "battle.player" | "party" | "summary",
  --         game = <Game> }
  if myMode.active and ctx.where ~= "party" then
    return false      -- the level is not printed on that surface
  end
  return next(mon, ctx)   -- true: printed, as today
end)
```

Default `true`. Only an explicit `false` suppresses; `nil` and every other
value print, so a wrapper that forgets a branch cannot blank a screen by
accident.

`ctx.where` names the surface rather than the widget, because the number
means different things on different screens: on a battle HUD an opponent's
level is information about *them*, on the party and status screens your own
level is information about *you*. A mode that wants to hide the first and
keep the second can, and the motivating mode does exactly that.

### New module: `src/ui/LevelDisplay.lua`

One function, `LevelDisplay.visible(mon, where, game)`, wrapping the
`wantsHook`/`call` pair. It exists so the four call sites are a one-line
guard each instead of four copies of the same five lines, and so the hook
has one definition of "visible" rather than four that can drift.

### Call sites

| Surface | File | `where` |
| --- | --- | --- |
| Enemy healthbox | `src/battle/BattleState.lua` | `battle.enemy` |
| Player healthbox | `src/battle/BattleState.lua` | `battle.player` |
| Party rows | `src/ui/PartyMenu.lua` | `party` |
| Status page 1 and 2 | `src/ui/SummaryMenu.lua` | `summary` |

No layout moves. Each site keeps its own hand-rolled PrintLevel rule
(`home/pokemon.asm:335-345` — the `<LV>` tile, then the digits, with a level
of 100 writing its third digit back over the tile); it just asks first.

Two details are deliberate:

- **A status condition still replaces the level on a healthbox**, exactly as
  it does in the cart, so hiding the level never hides `PSN` or `BRN`. The
  guard is an `elseif` on the existing status branch, not a wrapper around
  it.
- **On status page 2 the `<to>` arrow is hidden with the level it points
  at.** The arrow introduces the next level; on its own it is half a
  sentence. The EXP-to-next-level figure beside it is a different field and
  still prints.

### No other surface changes

No event, no registry, no save field, no manifest key.

## Migration

None. The hook is additive and defaults to current behaviour.

## Verification

- `tests/modkit/cases/pokemon_level_visible.lua` — the contract through the
  public mod API: default true with no mod, `false` suppresses, the surface
  and the mon reach the hook, falling through prints, and a `nil` mon
  answers rather than throwing.
- `tests/engine/gate_hooks.lua` — the structural parity gate picks the hook
  up automatically, because it walks the live catalog rather than a list.
- `tests/engine/gate_meta_coverage.lua` — the coverage ratchet; the seam is
  covered by name from the change that introduces it, so it never enters the
  DEBT ledger.

## Backward compatibility

A build with no mod wrapping the hook never reaches `Runtime.call`:
`wantsHook` is checked first, which matters because two of the four sites
are on a per-frame draw path. Pixels are unchanged, and the parity gates
assert it.

## Scope, and what is deliberately not in this change

**Gen 1 only.** The Gen 2 screens keep their own level readouts
(`src/ui/gen2/PartyMenu.lua`, `SummaryMenu.lua`, `BoxMenu.lua`,
`HallOfFame.lua`) and do not consult the hook. So does the Gen 1 PC box list
(`src/ui/BoxMenu.lua`), where the level is baked into a row label string
rather than drawn as a field, and the box-to-PNG print path beside it.

Those are mechanical follow-ups, held back so this change stays reviewable
against screens that can actually be exercised here. The limitation is
stated in `docs/modding.md` beside the hook, so a mod author reads it before
depending on it rather than after.

## Compatibility seam for older engines

There is none, and none is possible without patching: the call sites are
mid-draw, so a mod on a stock engine cannot reach them. That is the argument
for the seam rather than a gap around it — the alternatives available to a
mod today are painting over the engine's own pixels or reaching into its
render modules, and the second is the thing the mod contract exists to
prevent.
