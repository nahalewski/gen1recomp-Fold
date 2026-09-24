package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local CodeEntry = require("src.link.CodeEntry")
local LinkState = require("src.link.LinkState")

local function roundTrip(ip)
  return LinkState.addrText(LinkState.addrEntry(ip))
end

do
  T.eq(roundTrip("10.0.0.1"), "10.0.0.1", "a two-digit first octet survives")
  T.eq(roundTrip("10.42.0.1"), "10.42.0.1", "hotspot addresses survive")
  T.eq(roundTrip("192.168.1.40"), "192.168.1.40", "short tails do not zero-extend")
  T.eq(roundTrip("255.255.255.255"), "255.255.255.255", "a full-width address fits")
  T.eq(roundTrip(nil), "192.168.0.1", "no LAN IP falls back to a usable seed")
  T.eq(roundTrip("not an address"), "192.168.0.1", "junk falls back to the seed")
end

do
  local state = LinkState.addrEntry("10.0.0.1")
  T.eq(state.pos, 8, "the cursor starts on the last filled slot")
  T.eq(state.length, LinkState.ADDR_LENGTH, "the widget is the address shape")
  T.eq(CodeEntry.charAt(state, 9), " ", "unused slots are blank, not '0'")
end

do
  local function entryOf(text)
    return CodeEntry.fromText(text, { length = LinkState.ADDR_LENGTH,
                                      charset = LinkState.ADDR_CHARSET })
  end
  T.eq(LinkState.addrText(entryOf("10.0.0")), nil, "three octets are rejected")
  T.eq(LinkState.addrText(entryOf("10.0.0.256")), nil, "an octet over 255 is rejected")
  T.eq(LinkState.addrText(entryOf("10.0.0.1.2")), nil, "five octets are rejected")
  T.eq(LinkState.addrText(entryOf("")), nil, "an empty widget is rejected")
end

do
  local state = LinkState.addrEntry("10.0.0.1")
  state.pos = 1
  CodeEntry.up(state)
  T.eq(LinkState.addrText(state), "20.0.0.1", "scrubbing edits one slot")
  for _ = 1, 11 do CodeEntry.up(state) end
  T.eq(LinkState.addrText(state), "10.0.0.1", "a full cycle returns the digit")
end

T.finish("link_addr_entry_bug1295")
