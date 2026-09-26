# Game Link (the link cable over the network)

The user's ask: GB-Link-style trading for compatible games, with the phone
as the adapter (no ESP32, no computer), and instructions for the 3DS HOME
menu and the Switch skin.  Plus: find how emulated games can trade with
real consoles (DS, 3DS, Switch, Switch 2).

## UI (done, fold3ds/gamelink.lua + emuplay.lua)
A "Game Link" row in a game's pause menu (HOME), 3DS HOME menu and Switch
skin, shown only when the provider says the game can link.  Panel: Host
online (room code), Host on this Wi-Fi (ip:port), Join (keypad), state,
Stop, Manual (4 pages).  Provider contract:

    p.link(t) -> nil (can't link) or
      { state = "off"|"hosting"|"joining"|"paired"|"error",
        code = "AB12CD", address = "192.168.1.20:7777", peer = "...", msg = "..." }
    p.linkDo(action, arg)  -- "host_online" | "host_lan" | "join" (code or ip:port) | "stop"

## Transport (reuse gen1recomp's, don't invent one)
build/aeondx-game/src/link/Net.lua: ENet UDP peer-to-peer on the LAN (port
7777, host shows ip:port), and a TCP relay (relay.gen1re.com:7778, the host
gets a 6-character room code, newline-delimited JSON, works through NAT).
The gen1recomp Pokemon games already use it in their Cable Club.

## Emulator side (Melonds session: emu/, vc.lua, melonds.lua)
- SkyEmu GB/GBC: serial port (SB/SC, 8 bits per transfer, internal/external
  clock) exchanged with the peer; GBA: SIO normal (8/32-bit) and multiplayer
  (16-bit, 2 players) modes.  Lockstep with a small input delay so trades
  and battles stay in sync.  Then p.link/p.linkDo in vc.lua.
- melonDS (real consoles): Nintendo WFC is revived (WiiLink WFC, Wiimmfi);
  real DS / 3DS consoles use it for Gen 4/5 Pokemon GTS, Wi-Fi Club and
  trades.  melonDS can reach it over its network stack; find what the
  Android melonDS lib needs (network backend, DNS / WFC patch).

## Real consoles: what is possible
- DS: yes, through revived WFC (above).
- 3DS: online through Pretendo Network where it supports the game; Azahar
  needs files from the player's own 3DS for online play.  3DS local wireless
  (UDS) is raw Wi-Fi: not from a phone.
- Switch / Switch 2: local wireless (LDN) is raw 802.11, which Android apps
  can't send; online is Nintendo's servers.  Only way: an ESP32 board
  (switch.gblink.io, FRLG only) which the phone could drive over USB-OTG.
- Real Game Boys: a GB-Link USB adapter over USB-OTG (its WebUSB commands,
  GBLink-Firmware).
