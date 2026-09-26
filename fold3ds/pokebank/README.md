# emuPoke Bank: save readers

`sources.lua` finds the saves; each generation's reader turns a save into
`{ gen, game, trainer, tid, sid, mons }`. Every record in `mons` has the same
fields: gen, format, raw (the structure as saved), species (National Dex),
nick, ot, tid, sid, pid, level, item, moves, shiny, egg, where and slot.

| Reader | Games | Where the save is |
|---|---|---|
| `gen12.lua` | Red, Blue, Yellow, Gold, Silver, Crystal | VC saves; gen1recomp's own saves |
| `gen3.lua` | Ruby, Sapphire, Emerald, FireRed, LeafGreen | VC saves |
| `gen45.lua` | Diamond, Pearl, Platinum, HeartGold, SoulSilver (PK4); Black, White, Black 2, White 2 (PK5) | `melonds/data/saves/<game>.sav` |
| `gen67.lua` | X, Y, Omega Ruby, Alpha Sapphire (PK6); Sun, Moon, Ultra Sun, Ultra Moon (PK7) | Azahar: `sdmc/Nintendo 3DS/<id0>/<id1>/title/00040000/<title>/data/00000001/main` |
| `gen89.lua` | Sword, Shield (PK8); Brilliant Diamond, Shining Pearl (PB8); Legends: Arceus (PA8); Scarlet, Violet (PK9) | Eden: `nand/user/save/0000000000000000/<user>/<title id>/main` (BDSP: `SaveData.bin`) |

Offsets, the Pokemon encryption, the Gen 4 block counters, the Gen 5 CRC
footer, the 3DS block table, SwishCrypto's xorpad and the SCBlock format all
follow PKHeX (github.com/kwsch/PKHeX); each reader names the files it follows.
`text4.lua` is PKHeX's Gen 4 letter table. Scarlet / Violet's species numbers
are in `species.lua` (`tools/make_pokebank_species.py`).

## Tested

`fold3ds/tests/test_pokebank_readers.py` builds a save for every game above
in the game's own layout, puts known Pokemon in the party and the boxes, and
checks what the reader gets back. It runs in the Check workflow.
The Pokemon decryption and field offsets were also checked against PKHeX's
own sample Pokemon files (144 PK4 to PK9 files, every species right).

## Not yet

- No reader has been run on a save from a real cartridge or console. The
  tests follow PKHeX's layouts, not dumps. Legends: Arceus and BDSP have the
  least behind them: PKHeX's sample files have no PA8 or PB8.
- Korean Gen 4 names: `text4.lua` has only the international letters, so
  Korean names come out as `?`.
- Pokemon Legends: Z-A, Let's Go Pikachu / Eevee, and the GameCube games
  aren't read.
- Finding the Switch users' save folders runs `ls` (LOVE can't list folders
  outside its own). If `io.popen` isn't available, no Switch saves are listed.
- The readers only read. Nothing is written back to any game's save.
