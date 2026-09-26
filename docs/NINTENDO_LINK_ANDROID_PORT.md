# Nintendo Link Bridge: porting GB-Link Switch LDN to Android

Phase 1 of the user's plan: what the upstream projects do, what the ESP32
actually does, and how much of it a phone can take over.  **No application
code is changed in this phase.**

Target chain:

    Game Boy / GBA -> GB-Link USB V2 (RP2040) -> USB-C OTG -> Pixel 9 Pro Fold (root)
                   -> native LDN bridge -> Wi-Fi -> Nintendo Switch

Later chain (no GB-Link, no ESP32):

    AeonDX (the GBA game in SkyEmu) -> EmulatedGbLinkEndpoint -> LDN engine -> Switch

Sources read (September 2026, commit heads at the time):

| Repo | What it holds | Licence |
| --- | --- | --- |
| [GB-Link/GB-Link-Switch-LDN](https://github.com/GB-Link/GB-Link-Switch-LDN) | ESP32 bridge firmware (`firmware/common/*.c`, ESP-IDF 6.1), C# host (`host/core/*.cs`), web client (`web/js`), `docs/SERIAL_PROTOCOL.md` | AGPL-3.0 (its LDN parts from kinnay/LDN, GPL-3.0) |
| [GB-Link/GBLink-Firmware](https://github.com/GB-Link/GBLink-Firmware) | the GB-Link adapter (RP2040, Zephyr): link-port PIO, USB, modes | see repo |
| [xxjeysonxx/GB-Link-Switch-LDN](https://github.com/xxjeysonxx/GB-Link-Switch-LDN) | a fork (Spanish UI, .sav support, no Wonder Trade), binaries only for the firmware | AGPL-3.0 |

Licensing: AGPL-3.0 and GPL-3.0 code may be combined with AeonDX (Azahar is
GPL-2.0-or-later, melonDS GPL-3.0).  Ported files keep their copyright headers
and say where they came from; the combined source stays public (it is, on
GitHub), which is what AGPL section 13 asks of us.

---

## A. What the ESP32 actually does

`docs/SERIAL_PROTOCOL.md` ("Responsibilities and porting requirements") is
explicit, and the firmware agrees with it:

> The host holds prod.keys, decrypts and verifies advertisements, derives the
> session key, and runs LDN authentication, Pia, RFU and the trade state
> machine. The device receives the derived CCMP key for the current room and
> handles 802.11 association, key installation and network transfer.

So the ESP32 is a **Wi-Fi radio with five capabilities**, nothing more:

1. **Hear the room advertisements.** A Switch hosting a room sends LDN
   advertisements as 802.11 **vendor-specific action frames** (management
   type 0, subtype 13) on channel 1, 6 or 11.  The firmware turns on
   promiscuous mode (`esp_wifi_set_promiscuous`, mgmt+data+ctrl filters) and
   also uses remain-on-channel, and reports each action frame's encrypted body
   verbatim with the sender BSSID (`ldn_probe.c: promiscuous_rx`,
   `remember_action`, `LDN_ADV`).
2. **Join the room.** A station association to the Switch's BSS: a hidden
   16-byte SSID (hex), a fixed BSSID and channel, a chosen station MAC
   (`esp_wifi_set_mac`), and **an exact RSN element** (CCMP, PSK,
   capabilities 0x000c, copied from kinnay/LDN), forced into the association
   request by hooking the private supplicant callback table
   (`esp_wifi_set_appie_internal`, `esp_wifi_register_wpa_cb_internal`).
3. **Skip the 4-way handshake and install the keys itself.** EAPOL is
   dropped (`probe_rx_eapol`); the host-derived 16-byte CCMP key is installed
   as both the pairwise (index 0, RX+TX) and group (index 1, RX) key
   (`esp_wifi_set_sta_key_internal`), then the port is authorised
   (`esp_wifi_auth_done_internal`).  **This is the part no public API allows.**
4. **LDN authentication frames**: raw Ethernet frames with EtherType
   **0x88B7**, sent and received on the associated link (`ldn_control.c`
   filters them out of the RX path before lwIP).
5. **Plain IP afterwards**: a static 169.254.x.x/24 address, static neighbour
   (ARP) entries for the room's members, and UDP port **12345** (Pia), payloads
   up to 1472 bytes (`ldn_udp.c`), plus replay protection, re-association,
   disconnect notices and cleanup.

The v2 firmware can also run the whole session on the chip (standalone, a
GB-Link Pico wired to its UART), but the host-driven mode above is the one a
phone replaces.

## B. What is ordinary IP networking

Capability 5 only: once associated and keyed, the room is a normal IPv4
network.  A static address on the interface, neighbour entries, and UDP
sockets on port 12345.  Pia (the game's session protocol, `pia_*.c` /
`Pia.cs`) is application-level AES crypto over UDP and runs anywhere.

## C. What needs direct Wi-Fi control

Capabilities 1-4:

| Need | Linux way | Stock Android (no root) | Rooted Pixel |
| --- | --- | --- | --- |
| RX vendor action frames (broadcast) on ch 1/6/11 | nl80211 `REGISTER_FRAME` (action, OUI match) + `REMAIN_ON_CHANNEL`, or a monitor interface | **No** (no API) | Needs CAP_NET_ADMIN (root). Works only if the Pixel's Broadcom full-MAC driver passes broadcast vendor action frames to a registered socket while a station interface exists. **Must be tested on the device.** |
| Associate with custom RSN IE, fixed BSSID/SSID/channel, chosen MAC | nl80211 `CONNECT` (or `AUTHENTICATE`+`ASSOCIATE`) with `ATTR_IE`; `ip link set address` | **No** (WifiNetworkSpecifier can't carry raw IEs or a raw PSK) | Root; wpa_supplicant has to let go of `wlan0` (or a second virtual interface, if the driver allows one). Full-MAC firmware builds its own RSN IE; whether it accepts ours is the key unknown. |
| No 4-way handshake; install CCMP pairwise + group keys; authorise port | nl80211 `NEW_KEY` (+ `SET_KEY` default) and `SET_STATION` authorized | **No** | Root; `NEW_KEY` is what wpa_supplicant itself uses on this driver, so it is likely supported. Blocker if the firmware insists on offloading the handshake. |
| TX/RX EtherType 0x88B7 frames | `AF_PACKET` socket bound to the interface | **No** (raw sockets need CAP_NET_RAW) | Root |
| Static 169.254/24 address + neighbour entries | rtnetlink / `ip addr`, `ip neigh` | **No** | Root; must not disturb Android's own routing (policy routing tables) and must be removed afterwards |
| UDP 12345 | BSD sockets | Yes, if bound to that network | Yes |

**Raw 802.11 injection is not required.**  The firmware sniffs but does not
inject; everything it transmits is a normal association or data frame.  Monitor
mode would make item 1 easy but is not strictly needed if frame registration
works.

## D. What runs unchanged on Linux / Android

* The whole host: LDN advertisement decryption and verification, key
  derivation from `prod.keys`, LDN authentication, Pia, RFU (the GBA Wireless
  Adapter layer), the trade engine and `.pk3` handling.  Upstream has it twice:
  C# (`host/core/*.cs`, ~2,250 lines, the reference) and JavaScript
  (`web/js/trade/*.js`, a port of it).  Target: C++ in `libaxm_ldn.so`
  (portable, unit-testable on the desktop), or Kotlin.
* `pia_*.c` from the firmware (C, depends only on its crypto helpers and small
  FreeRTOS stubs, see `firmware/tools/host_stubs`): builds on Linux with small
  changes.
* The GB-Link frame format and the web client's bridge logic (pure data).

## E. ESP-IDF APIs and their Android / Linux replacements

| ESP-IDF | Used for | Android / Linux |
| --- | --- | --- |
| `esp_wifi_set_promiscuous*`, rx callback | hearing advertisements | nl80211 `REGISTER_FRAME` + `REMAIN_ON_CHANNEL` (root), or monitor mode where the driver has it (not on Pixel) |
| `esp_wifi_set_channel` | scanning ch 1/6/11 | `REMAIN_ON_CHANNEL` per channel |
| `esp_wifi_set_mac` | the station MAC LDN expects | `ip link set dev X address` (interface down) |
| `esp_wifi_set_config` + `esp_wifi_connect` | join (SSID/BSSID/channel) | nl80211 `CONNECT` with `ATTR_SSID/MAC/WIPHY_FREQ/IE` |
| `esp_wifi_set_appie_internal` (private) | exact RSN IE | `NL80211_ATTR_IE` in `CONNECT` (driver may still add its own) |
| `esp_wifi_register_wpa_cb_internal` (private) | drop EAPOL, no 4-way | connect with no wpa_supplicant on that interface; ignore EAPOL |
| `esp_wifi_set_sta_key_internal` (private) | CCMP pairwise/group keys | nl80211 `NEW_KEY` (cipher 00-0f-ac:4) |
| `esp_wifi_auth_done_internal` (private) | open the port | nl80211 `SET_STATION` `STA_FLAG_AUTHORIZED` |
| `esp_wifi_internal_reg_rxcb` (control RX) | 0x88B7 frames | `AF_PACKET` socket, `ETH_P` 0x88B7 |
| lwIP static IP, `DHCPS_STATIC_ENTRIES` neighbours | 169.254/24, members | rtnetlink `RTM_NEWADDR`, `RTM_NEWNEIGH` |
| lwIP UDP | Pia on 12345 | BSD sockets bound to the interface (`SO_BINDTODEVICE`, root) |
| NVS (keys) | prod.keys-derived material | Android Keystore-wrapped file in app storage |
| UART / USB Serial-JTAG transport | host link | not needed: the host is in-process |

## F. The GB-Link USB protocol

From GBLink-Firmware `src/layers/usbLayer.cpp` and the web client:

* **Composite USB device**: a vendor (WebUSB) interface plus CDC-ACM.  The web
  page uses WebUSB or serial; Android can claim either with `UsbManager` bulk
  transfers (no root).  The vendor interface is preferred; CDC-ACM is the
  fallback.
* **Command endpoint** (vendor interface), command ranges by module:
  0x00-0x0F control (`0x00 SetMode`, `0x01 Cancel`), 0x10-0x1F GBA link,
  0x30-0x3F GB link / printer, 0x40-0x4F hardware (`0x42` LED, `0x43`
  bootloader, `0x4b` cable).  Modes: 0 GBA trade emu, 1 GBA link, 2 GB link,
  3 printer, 4 Advance Wars, 5 e-Reader, **plus the wireless-adapter mode**
  (firmware 2.2.5, `web/firmware/adapter/gblink-wireless-2.2.5.uf2`) that this
  bridge needs.
* **Data**: the "GB" framed transport, `0x47 0x42 | channel:1 | len:2 LE |
  payload` (channel 0 command, 1 data, 2 status; payload up to 128), the same
  over USB as over the Pico UART (`pico_link.h`).  RFU frames ride inside it:
  `"RFU1" | type:4 BE | header:4 BE | payload`, fixed sizes (broadcast 36,
  host/client send 104, others 16), sent in 64-byte pieces
  (`web/js/trade/adapter.js`).
* **To the ESP32 (for reference)**: COBS frames, `version:1 | kind:1 |
  request:4 LE | session:4 LE | length:2 LE | payload | crc32:4 LE`, kinds
  COMMAND 1 / RESPONSE 2 / EVENT 3 / ADAPTER_OUT 6 / ADAPTER_IN 7; ASCII
  commands `LDN_HELLO`, `LDN_BEGIN`, `LDN_INFO`, `LDN_KEY(S)`,
  `LDN_ADAPTER host|uart`, `LDN_BRIDGE_START/STATUS`, `LDN_RF`; 8N1,
  115200 then 921600.  Kept in this document because "the phone drives the
  ESP32" (below) speaks exactly this.

## G. What is timing-sensitive

* **The GBA link port**: 2 MHz SIO32 words, 250 ns half-bits.  Only the
  RP2040's PIO meets it (the firmware notes the ESP32-S3's GPIO cannot).  It
  stays on the GB-Link, as the user asked.  Android never sees link-port
  timing; it sees whole RFU frames.
* **RFU and Pia**: the games tolerate milliseconds, not microseconds.  The
  upstream host's `SessionTiming.cs` holds the budgets; the web page warns
  that a throttled background tab gets dropped.  On Android: a foreground
  service, a Wi-Fi lock (`WIFI_MODE_FULL_LOW_LATENCY`), no USB request
  batching.
* **Advertisements**: a room must be heard within the Switch's advertisement
  interval while hopping 1/6/11.

---

## Android replacement architecture

    GbLinkUsbManager / GbLinkDevice      (UsbManager, vendor or CDC interface)
            |  GbLinkTransport: "GB" frames <-> RFU frames
    GameBoyLinkEndpoint  <- PhysicalGbLinkEndpoint now, EmulatedGbLinkEndpoint later
            |
    PokemonLinkProtocol / PokemonTradeSession   (RFU <-> Pia, the trade engine)
            |
    LdnSession / LdnProtocol / LdnCrypto / LdnDiscovery   (libaxm_ldn.so, C++)
            |
    LinkRadio  <- one interface, three implementations:
            |   RootWifiTransport  (nl80211 + AF_PACKET + rtnetlink, via RootNetworkService)
            |   EspBoardRadio      (an ESP32 on USB, the upstream serial protocol)
            |   (LinuxBoxRadio     a Pi Zero 2 W over USB gadget ethernet, optional)
            |
    Wi-Fi -> Nintendo Switch

`LinkRadio` is exactly the ESP32's five capabilities (hear advertisements,
join with RSN/CCMP, install keys, 0x88B7 frames, IP/UDP).  Everything above
it is identical whichever radio is used, so the ESP32 board works on day one
(no root needed) and the rooted Pixel radio replaces it when phase 5 proves the
driver can do it.

Fitting it into AeonDX (it differs from the spec's Compose screens because
AeonDX's interface is the LÖVE 3DS / Switch HOME menus; the user asked for it
"in the 3DS and Switch UI"):

* Kotlin, `azahar/java/org/citra/citra_emu/fold3ds/nintendolink/` (package
  structure as the spec: usb/, ldn/, network/, pokemon/, root/, diagnostics/),
  a foreground `NintendoLinkService`, reached from Lua through the
  existing `love.system.foldCamera("call", ...)` bridge.
* C++ `libaxm_ldn.so` (NDK, CMake) beside `libemucore.so`; JNI errors mapped
  to Kotlin exceptions, logging tags `AXM-GBLINK`, `AXM-LDN`, `AXM-WIFI`,
  `AXM-ROOT`, `AXM-POKEMON`.
* The screens (status, controls, counters, diagnostics, key import) drawn by
  the 3DS / Switch UI (`fold3ds/`), folded: one column, unfolded: controls
  left, live session right.  A game's pause menu gets "Nintendo Link" beside
  "Game Link" for FireRed / LeafGreen / Emerald.
* Keys: `prod.keys` picked through the Storage Access Framework, only the four
  entries the host uses (`aes_kek_generation_source`,
  `aes_key_generation_source`, `master_key_00`, `master_key_12`) kept,
  encrypted with an Android Keystore key, never logged, never bundled,
  never downloaded.

## Root requirements

Only for `RootWifiTransport`, through one narrow `RootNetworkService`
(a small root helper binary started with `su`, speaking a fixed command set
over a socketpair, never a shell):

* `iw`-equivalent nl80211 calls on the Wi-Fi interface (register frames,
  remain on channel, connect, new key, set station), done in C inside the
  helper;
* `AF_PACKET` socket for 0x88B7;
* rtnetlink address / neighbour / rule changes, recorded so they can be undone;
* stopping and restarting wpa_supplicant's hold on the interface
  (`svc wifi disable` / `cmd wifi` or a second interface), and restoring it.

Recovery: every change is written to a journal file before it is made; on
Stop, USB loss, Switch disconnect, service death (`onTaskRemoved`,
`onDestroy`) and at the next app start the journal is replayed backwards, and
Wi-Fi is handed back to Android.

## Implementation phases (the spec's order, with what each proves)

1. **This document.**
2. **GB-Link USB**: detect, permission, claim the vendor interface, set the
   wireless-adapter mode, read and write "GB" frames, a USB diagnostics page.
   No root.  Testable with the adapter alone.
3. **libaxm_ldn**: port `host/core` (Ldn.cs, LdnJoiner.cs, Pia.cs, PiaLink.cs,
   Rfu.cs, TradeEngine.cs, TradeSession.cs, KeyFile.cs) to C++; unit tests from
   `host/tests/fixtures` and `web/tests/*vectors.json` (upstream ships test
   vectors, so this phase is verifiable on the desktop).
4. **EspBoardRadio**: the phone drives an ESP32 over USB-OTG with the serial
   protocol above.  Result: Game Boy -> GB-Link -> phone -> ESP32 -> Switch with
   **no computer and no root**.  This is also the reference the rooted radio is
   checked against.
5. **RootWifiTransport, on the Pixel**: in this order, each a go/no-go test:
   (a) `iw list` equivalent: does the driver report `frame`, `remain_on_channel`,
   `connect`, `new_key`?  (b) do Nintendo action frames arrive on a registered
   socket?  (c) does `CONNECT` with our RSN IE and no handshake associate?
   (d) do installed keys decrypt (the LDN authentication succeeds)?  (e) UDP.
6. **Bridge**: USB <-> LDN end to end, foreground service, locks.
7. **UI**: the full screens in the 3DS and Switch skins.
8. **EmulatedGbLinkEndpoint**: SkyEmu's GBA SIO / RFU in the emulator feeding
   the same `GameBoyLinkEndpoint` (needs a Wireless Adapter (RFU) model in the
   core; FireRed / LeafGreen / Emerald look for it).

## Known blockers (honest list)

1. **Pixel Wi-Fi driver**: Pixels have used Broadcom full-MAC Wi-Fi (the
   `bcmdhd` driver) with the 802.11 stack in the chip's firmware; the exact chip
   in the 9 Pro Fold should be read off the phone (`/vendor/firmware`,
   `dmesg`).  Stock firmware offers no monitor mode, Nexmon's patches cover
   older Broadcom chips only, and whether (b)-(d) above work is unknown until
   tested on the phone.
   If the firmware rejects a custom RSN IE or insists on its own handshake,
   **the rooted Pixel alone cannot join an LDN room**; that would need a
   patched Wi-Fi firmware or kernel driver.
2. **Taking wlan0 from Android** ends the phone's normal Wi-Fi for the session
   (a second concurrent interface depends on the driver).  Mobile data stays.
3. **FireRed / LeafGreen only** (and Emerald joining them): that is what the
   Switch games and the upstream trade engine support.
4. **prod.keys** from the player's own Switch is required; AeonDX will not ship
   or download it.
5. **Timing under Android**: needs the foreground service and a low-latency
   Wi-Fi lock; USB OTG power for the GB-Link.

## Other boards the user asked about

* **ESP32 models**: upstream builds for the ESP32, ESP32-S3, ESP32-C3 and
  ESP32-C6.  The S3 / C3 / C6 have native USB (they plug straight into the
  phone); the original ESP32 goes through its USB-UART chip, which Android can
  also drive (CP210x / CH340 need a small driver in the app).
* **Raspberry Pi Pico W / Pico 2 W**: **no.**  Their CYW43439 radio is driven
  by a closed firmware with no promiscuous mode, no raw management frames and
  no raw key installation in the Pico SDK, which are exactly the five
  capabilities.  (A plain Pico is what the GB-Link already is.)
* **Raspberry Pi Zero 2 W**: **yes, in principle.**  It runs Linux, so it has
  the same nl80211 / AF_PACKET / rtnetlink interfaces this document plans for
  the Pixel, and its BCM43436 is among the chips Nexmon patches for monitor
  mode; kinnay/LDN (the Linux LDN implementation upstream copied its RSN IE
  from) is written for Linux with a monitor-capable adapter.  (A USB Wi-Fi
  dongle with monitor mode is the fallback if Nexmon misbehaves.)  It is also the ideal test bench for `RootWifiTransport`: the same
  Linux code, on hardware where it is known to work, before the Pixel.  It
  would sit where the ESP32 sits (USB gadget ethernet or serial to the phone).
