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

## Real consoles (research, 2026-09-26, Azahar session)

### 3DS
- Pretendo today: Pokemon X / Y / Omega Ruby / Alpha Sapphire are supported
  in beta (GTS, Wonder Trade, Friend Safari); Sun / Moon / Ultra Sun / Ultra
  Moon are not (no server support yet, so no online trades for them from any
  3DS, real or emulated).  Source: tech-insider.org "Set Up Pretendo Network
  for Pokemon Trading [2026]"; Pretendo forum threads "Will Pokemon sun/moon
  ever be supported" (forum.pretendo.network/t/29538) and "Any updates to
  Pokemon support?" (/t/11049).  pretendo.network itself was blocked from
  this sandbox, so re-check its compatibility list before relying on this.
- So real-3DS <-> Azahar trading works only where both use Pretendo online:
  Gen 6 GTS / Wonder Trade (not direct friend trades unless Pretendo's
  friends + matchmaking cover them for that game; not confirmed).
- Azahar online needs the player's own 3DS: Pretendo's Azahar guide
  (pretendo.network/docs/install/azahar) and the community gist
  (gist.github.com/Tsumuri-u/41a76beb24c8de4f4f5d0c0b55c3fb26) set it up
  with Azahar's Artic Setup Tool on a homebrewed 3DS (Luma3DS), which copies
  the console's system files / OTP and its Pretendo NNID into Azahar.  We
  can link to that flow (Azahar folder > Artic, already there) but cannot
  ship those files.
- Azahar multiplayer rooms: HLE of nwm:UDS carried over Azahar's own
  room protocol (deepwiki.com/azahar-emu/azahar/7.5-networking-and-multiplayer;
  citra.azahar-emu.org/help/feature/multiplayer).  Emulator <-> emulator
  only; a real 3DS's local wireless is raw 802.11 and cannot join.

### Switch / Switch 2
- No phone-only path: LDN is raw 802.11 action frames + an RSN/CCMP
  association, which Android apps cannot send or join.  Online is
  Nintendo's servers (NSO), not reachable by emulated GBA games.
- The ESP32 board (switch.gblink.io; code github.com/xxjeysonxx/GB-Link-Switch-LDN,
  fork of GB-Link/GB-Link-Switch-LDN, GPL-3.0, checked at f24af1b) does the
  radio part; the host does everything else.  Games: FireRed / LeafGreen
  (GBA side) <-> the Switch's FRLG over LDN.
- What driving it from the phone over USB-OTG would take (docs/SERIAL_PROTOCOL.md):
  - Serial: 8N1, no flow control, 115200 then 921600 (C3/native USB:
    rate ignored); don't toggle DTR/RTS.  Android: USB host API + a
    CDC-ACM / CP210x / CH34x driver (e.g. usb-serial-for-android).
  - Handshake: ASCII "\nLDN_BINARY\n" + 0x00, then LDN_HELLO; reply like
    "LDN_HELLO 1 esp32c6 dynamic-session,scan,auth,udp 1472"; check version
    and capabilities.  LDN_BEGIN <8 hex> per session.
  - Frames: COBS + 0x00 delimiter; raw = ver(1)=1, type(1), request_id(4 LE),
    session_id(4 LE), len(2 LE), payload, CRC-32/ISO-HDLC(4 LE); <= 4096 B.
    Types: 1 command (ASCII), 2 response (ends with LDN_DONE), 3 async
    event, 4 UDP out (dst IPv4 BE + payload), 5 UDP in; UDP <= 1472 B.
  - Host side we'd have to port (from host/core/*.cs and web/js/trade/*.js,
    12 files: link, rfu, session, engine, pk3, sav, ...): decrypt/verify the
    LDN advertisements, derive the room's CCMP key, LDN auth, Pia, the RFU
    (GBA wireless adapter) layer and the FRLG trade state machine, fed by the
    emulated game's RFU traffic.
  - Blocker: the host needs prod.keys from the player's own Switch (host/README.md
    "prod.keys"); we can only ask the player to provide them, never ship them.
  - Plus the board itself (ESP32-C3/C6/S3, flashed with its firmware).
- Verdict: possible only with that board + the player's prod.keys + a port of
  the host stack and an RFU hookup in the GBA core; FRLG only.
