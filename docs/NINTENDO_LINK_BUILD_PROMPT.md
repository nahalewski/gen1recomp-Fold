# Build prompt — Nintendo Link Bridge

Hand this to a fresh Claude Code session (cloud or local) to build the bridge.
It stands alone.

---

Build the **Nintendo Link Bridge** for the AeonDX Android app
(https://github.com/nahalewski/AeonDX, branch `main` — fetch and merge before
every push; never force-push). It lets a rooted **Pixel 9 Pro Fold** (codename
`comet`, Tensor G4, Broadcom **BCM4390**) join a Nintendo Switch's local
wireless and act as the Wi-Fi radio the GB-Link Switch LDN project uses an
ESP32 for, so Pokémon FireRed/LeafGreen (and Emerald joining them) can trade
and battle with the Switch. Goal chain: Game Boy Advance → GB-Link USB (RP2040)
→ USB-C OTG → phone → Wi-Fi → Switch, no ESP32. Later: the AeonDX GBA emulator
in place of the physical GBA/GB-Link.

**Read first, in this order, and follow them:**
1. `docs/NINTENDO_LINK_ANDROID_PORT.md` — the phase-1 analysis. It has the ESP32→Android
   API mapping, the layered design, the phases, the blockers, and the
   **confirmed probe results from the actual phone**: the join path runs on the
   phone's separate **`wonder` radio** (module `wonder.ko`, interface
   `wondertap0`), NOT `wlan0`. `iw` on the phone shows that radio has monitor
   mode, `authenticate`/`associate`/`connect`/`new_key`, and
   **`CONTROL_PORT_OVER_NL80211`** (so the LDN 0x88B7 auth frames go over
   nl80211, no raw socket), and it does NOT force the firmware 4-way handshake.
   `wlan0` stays on the home network the whole time.
2. `tools/nintendo_link/probe.sh` and `tools/nintendo_link/listen.sh` — the
   read-only phone tests already written (test 1 done, test 2 = hear a room).
3. Upstream (clone read-only; AGPL-3.0 / GPL-3.0, compatible with AeonDX; keep
   headers, keep source public): `GB-Link/GB-Link-Switch-LDN` (the ESP32 bridge
   firmware `firmware/common/*.c`, the C# host `host/core/*.cs` = the reference
   trade+LDN+Pia+RFU stack, `docs/SERIAL_PROTOCOL.md`), `GB-Link/GBLink-Firmware`
   (the GB-Link USB adapter protocol), and `kinnay/LDN` (the Linux nl80211
   reference `ldn/wlan.py`).

**Do NOT** touch the app's Lua UI files (`fold3ds/`) — that is another owner's.
Expose the bridge to the UI only through the existing native bridge
(`love.system.foldCamera("call", "<cmd>", "<arg>")`, handled in
`android/FoldBridge.java`) so the 3DS/Switch skins can add a screen later.
**Do NOT** add any prod.keys import UI — the owner adds the key code themselves;
your code reads the 4 needed key entries from a path it is handed and never
bundles, downloads or logs keys.

**Constraints (do not violate):**
- Never fake functionality. If a step can't work, say exactly why in the doc,
  with the failing command's output.
- Listen-only until joining is proven on the phone. Never leave the phone's
  Wi-Fi altered: every change journaled and undone on stop/crash/USB-loss.
- The join path is the **`wonder` phy**; `wlan0` is left alone.
- FireRed/LeafGreen (+ Emerald joining) only — that's what the Switch games and
  the reference trade engine support.
- GB-Link/RP2040 keeps the microsecond GBA link-port timing; the phone only
  sees whole RFU frames over USB.
- Root only through one narrow `RootNetworkService` (a fixed command set, never
  an arbitrary shell), started with `su`.

**Build in phases, testing each before the next. Commit per phase to `main`
(merge first).**

- **Phase 2 — GB-Link USB.** `UsbManager` claim of the GB-Link's vendor
  interface (CDC-ACM fallback), set its wireless-adapter mode, read/write the
  "GB" framed transport (`0x47 0x42 | channel | len | payload`), a USB
  diagnostics test screen. No root. Testable with the adapter alone.
- **Phase 3 — `libaxm_ldn`.** Port `host/core` (Ldn, LdnJoiner, Pia, PiaLink,
  Rfu, TradeEngine, TradeSession, KeyFile) to C++ (NDK, CMake), beside
  `libemucore.so`. Desktop unit tests from the upstream vectors
  (`host/tests/fixtures`, `web/tests/*vectors.json`). JNI errors → Kotlin
  exceptions. Tags `AXM-LDN`, `AXM-POKEMON`.
- **Phase 4 — the radio, on the `wonder` phy.** A `LinkRadio` interface, then
  `RootWifiTransport`: through `RootNetworkService`, on `wondertap0`/`wonder`,
  do the five steps as separate journaled commands, each naming its step on
  failure — (a) monitor + hop 1/6/11 to hear the room, (b) associate to the
  room's BSSID with LDN's RSN element, (c) install pairwise+group CCMP keys,
  (d) the 0x88B7 auth over the nl80211 control port, (e) static 169.254/24 +
  neighbours + UDP 12345. Prove (a)-(e) on the phone against a real Switch
  hosting FireRed's Union Room before wiring the trade engine in. Tag `AXM-WIFI`,
  `AXM-ROOT`.
- **Phase 5 — bridge + service.** USB ↔ LDN end to end, a foreground
  `NintendoLinkService` (persistent notification, Wi-Fi low-latency lock only
  while active), full cleanup/recovery. Package `com.axm.nintendolink`
  (usb/ ldn/ network/ pokemon/ root/ diagnostics/ native/), the layering kept
  separate. Kotlin + Coroutines/Flow.
- **Phase 6 — the screen.** Status (GB-Link / Game Boy / Switch / Wi-Fi iface /
  root / session), the counters (USB RX/TX, LDN RX/TX, dropped, retries,
  latency), and a diagnostics/export view. Drawn by the 3DS and Switch skins —
  expose the state and controls over the `foldCamera` bridge and add a request
  line for the UI owner in `notes/ui-requests.md`, don't draw it yourself.
- **Phase 7 — emulator endpoint.** A `GameBoyLinkEndpoint` interface with a
  `PhysicalGbLinkEndpoint` now and an `EmulatedGbLinkEndpoint` stub, so AeonDX's
  own GBA (SkyEmu) can later feed the same path with no GB-Link.

Write everything you learn back into `docs/NINTENDO_LINK_ANDROID_PORT.md` as you
go. Keep pushes batched (each push restarts the APK build). Reply with what
works, what's tested on the phone vs only on the desktop, and the next blocker.
