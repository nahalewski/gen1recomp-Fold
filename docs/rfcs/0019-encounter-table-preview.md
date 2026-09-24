# RFC 0019: Encounter table preview (`encounter.table`)

## Status

Proposed.

## Motivation

`encounter.roll` and `encounter.species` let a mod transform one wild
encounter draw: RNG in, one `{species, level}` out. Neither gives a mod a way
to ask what the effective distribution looks like without actually rolling.

A mod that wants to display encounters, a route overlay or a "what's here"
panel, has two options today, and both are wrong. It can read the raw
`Data.encounters[mapId].grass`/`.water` table directly, which misses anything
a live `encounter.roll` wrapper is doing: a weather bias, a swarm, a
time-of-day shift. Or it can sample the real roll hundreds of times to
estimate the distribution, which is expensive, fires the real RNG, and still
only approximates the answer.

The immediate consumer is a route-info overlay mod that wants to show what's
catchable on the current route, composed with whatever another installed mod
is doing to the odds. Nothing here is specific to it; any reader mod wanting
the same answer hits the same wall.

## The decision it extends

This extends the additive, guarded seam convention Route B in
`CONTRIBUTING-mods.md` documents, alongside the existing `encounter.roll`/
`encounter.species` pair it sits next to. It does not change either of those
hooks' contracts: a real roll is untouched by this RFC, still exactly
`Runtime.call("encounter.roll", ...)` then `Runtime.call("encounter.species",
...)`, no new call added to that path. `encounter.table` is a separate,
preview-only chain that only the new query method below ever calls.

There is no in-repo D-number registry to amend.

## Exact API delta

### New hook: `encounter.table`

```lua
mod.hooks:wrap("encounter.table", function(next, dist, ctx)
  -- dist = { [speciesName] = weight, ... }, already includes every
  -- vanilla slot for this map/terrain (and time of day, on Gen 2)
  -- ctx.mapId, ctx.terrain: same fields encounter.roll/species already carry
  -- ctx.preview = true always; ctx.rng is absent (see below)
  if isWindy(ctx.mapId) then
    dist = bias(dist, "FLYING")
  end
  return next(dist, ctx)
end)
```

Raised only from the new query method, never from a real roll. `dist` is the
value each link transforms and returns, the same shape as the map it
received. A wrapper that throws is caught and skipped by `Hooks:call` itself,
same as any other hook. A wrapper that returns nothing is a different failure
mode `Hooks:call` does not guard: an empty return makes the whole
`Runtime.call` return nothing, which would silently hand the query method a
nil `dist` instead of a table. The query method checks the result is a table
before accepting it and keeps the pre-hook `dist` otherwise, so a careless
wrapper degrades to "did nothing" rather than crashing whatever reads the
result.

**`ctx.rng` is absent on a preview call.** `encounter.roll`/`encounter.species`
both carry a working `ctx.rng`; a preview call has nothing to roll, so the
field is missing rather than stubbed. A wrapper shared between
`encounter.roll` and `encounter.table` that unconditionally calls
`ctx.rng(...)` errors loudly on the preview path instead of silently drawing
real randomness, which is the failure mode we want: a mod author who shares
logic between the two finds out immediately, at test time, not from a bug
report about phantom RNG draws during a menu render.

### New query method: `mod.world:effectiveEncounters(mapId, terrain, opts)`

```lua
local info = mod.world:effectiveEncounters("ROUTE_29", "grass")
-- info = { chance = 0.6, dist = { RATTATA = 51, PIDGEY = 51, ... } }  or nil

info, err = mod.world:effectiveEncounters(mapId, terrain, { daytime = "NITE" })
```

Returns `nil, reason` only when the call itself does not make sense: an
unrecognized `terrain` string, or (Gen 2) an `opts.daytime` that is not one of
`"MORN"`/`"DAY"`/`"NITE"`/`"DARK"`. A map or terrain that genuinely has
nothing there, an unknown map id, a landlocked map asked about `"water"`, a
zero-rate table, still answers the question asked: `{ chance = 0, dist = {} }`.
Telling those two failure modes apart would need a live map registry, and Gen
1 and Gen 2 expose that differently (`data.maps` vs. the live `World.maps`),
so this stays a caller-facing distinction rather than an engine-plumbing one:
"nothing here" and "you asked about a place that doesn't exist" both read the
same, which is honest about what the query can and cannot tell you apart.

On a hit, returns `{ chance, dist }`:

- `chance` is the vanilla probability that a step produces any encounter at
  all: `grass.rate / 256` on Gen 1 (or the def's own `.buckets`-scaled
  equivalent), the model-specific constant on Gen 2. It is not run through
  `encounter.table` in this RFC. Biasing whether an encounter happens at all,
  as opposed to which species it is, is a separate question, one this RFC
  doesn't answer for grass/water and doesn't need to: `encounter.fishing`
  already handles rod encounters as its own hook, untouched here. Worth its
  own preview hook later if a mod actually needs one.
- `dist` is a flat species-to-weight map, one entry per distinct species
  (slots repeating the same species are summed, since a caller asking "how
  likely is CATERPIE" doesn't care which slot it's in). Weights are the raw
  per-slot values the vanilla table already encodes (Gen 1: consecutive
  `.buckets`/`encounterBuckets` differences; Gen 2: consecutive
  `GRASS_SLOT_CHANCES`/`WATER_SLOT_CHANCES` differences), not normalized to a
  probability. They are comparable within one `dist`, not across two
  different calls with a different base `chance`.
- `terrain` is `"grass"`, `"water"`, or, Gen 1 only, `"indoor"`, matching the
  real values `ctx.terrain` already carries on `encounter.roll`/
  `encounter.species` (the issue that opened this proposal said "surf"; the
  engine's own ctx has always said "water", and this RFC follows the engine).
  `"indoor"` reads the same `grass` table caves already resolve through
  today; that's an existing engine behavior, not new here, and is worth a
  caller knowing about rather than discovering it by comparing two supposedly
  different distributions that turn out identical.
- `opts.daytime` (Gen 2 only, optional) previews a specific time of day
  (`"MORN"`, `"DAY"`, `"NITE"`); omitted, it uses the map's actual current
  time, the same value a real roll would use right now. Gen 2 grass genuinely
  has three different distributions per map; a caller that wants "what does
  the player see this instant" gets it by default, and a caller that wants to
  preview a different time asks for it explicitly.

**A Gen 2 swarm is reflected; a roamer is not, and those are two different
things in `src/core/gen2/Roamers.lua`.** A swarm is a persistent, per-map
substitution of the whole table (`Roamers.Swarm.tables`), the same one a real
roll already draws from, so `effectiveEncounters` runs the base table through
it before building `dist`. A roaming legendary is a dynamic, per-step
override (`Roamers.checkEncounter`, called immediately before `rollEncounter`
on both the wild-step and sweet-scent paths) that replaces the map's
encounter outright the moment it fires, and this RFC does not try to predict
that. `effectiveEncounters` reports the swarm-aware static table composed
with `encounter.table` wrappers; a route overlay built on it should treat the
answer as "the map's own encounters," not "guaranteed to be what the next
step produces."

## Migration and compatibility

Nothing changes for existing mods. `encounter.roll` and `encounter.species`
keep their exact current signatures, call sites, and behavior; no existing
mod using either needs to change anything. A mod that already estimates a
distribution by sampling `encounter.roll` hundreds of times can switch to one
`effectiveEncounters` call, at its own pace. `encounter.table` is additive
only: no existing hook, event, registry, or manifest field changes shape.

## Verification

- `tests/modkit/cases/encounter_table.lua`, through the public mod API:
  `effectiveEncounters` against a fixture map with no wrapper installed
  matches the vanilla table's own weights exactly, including summing a
  species that occupies more than one slot; a wrapped `encounter.table`
  biases the returned `dist` without ever calling `ctx.rng` (asserted
  absent, not just unused); a wrapper that returns nothing leaves `dist`
  exactly as it was, proving the type-check guard actually holds (confirmed
  by briefly removing the guard and watching this same case crash with a
  nil `dist`, before restoring it); an unknown map and a zero-rate map both
  answer `{ chance = 0, dist = {} }` rather than erroring; an invalid
  `terrain` or `opts.daytime` string returns `nil, reason`, and so does Gen
  2's `"indoor"`, which does not exist there the way Gen 1's cave quirk
  does; Gen 2's three real `opts.daytime` values each return the correct
  one of the three slot lists, and the omitted case resolves the save's
  actual current time via `Clock.hour`/`Palettes.clockDaytime`, pinned
  deterministically in the test with `Clock.setTime` rather than depending
  on the host clock.
- `tests/engine/gate_hooks.lua`, the live-catalog parity gate: `encounter.table`
  gets its no-mod-installed pass automatically once the literal
  `Runtime.call("encounter.table", ...)` string exists in source, no
  hand-written code needed for that part.
- `tests/engine/gate_gen2_mod_api.lua`: `encounter.table` has call sites in
  both a `gen2`-pathed file and a non-`gen2` file (mirroring `encounter.roll`/
  `encounter.species`), so it needs an explicit entry in that gate's
  `GEN2_HOOKS` list, or the gate fails with instructions saying so.
- `tests/engine/gate_meta_coverage.lua`: covered by the new case file above;
  no `DEBT` entry needed.
- `docs/mod-api-gen2-compat.md`: a new line next to the existing
  `encounter.roll`/`encounter.species`/`encounter.fishing` entry, documenting
  `encounter.table` and `effectiveEncounters` the same way, plus a line in the
  partial-coverage section noting the same swarm-yes/roamer-no split those
  hooks already have.
- `docs/modding.md`: a new "Effective wild-encounter distribution" section,
  matching the RFC-cited-in-prose convention the two most recent hook
  additions (RFC 0014, RFC 0015) already established there.

## Deprecation etiquette

Nothing is removed, renamed, superseded, or deprecated.
