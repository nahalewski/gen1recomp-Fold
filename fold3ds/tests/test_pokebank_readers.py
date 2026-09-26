"""Tests for the emuPoke Bank save readers of Gen 4 to 9 (gen45.lua, gen67.lua,
gen89.lua):

    python fold3ds/tests/test_pokebank_readers.py      (needs luajit)

Each test builds a save the way the game lays it out -- the offsets, the
Pokemon encryption and shuffle, the Gen 4 block footers and counters, the
Gen 5 CRC footer, the 3DS "BEEF" table, SwishCrypto's xorpad and SCBlocks --
following PKHeX (the same sources the readers cite), puts known Pokemon in
the party and the boxes, and checks what the reader gets back.
"""
import os
import random
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PASS = FAIL = 0


def check(name, got, want):
    global PASS, FAIL
    if got == want:
        PASS += 1
    else:
        FAIL += 1
        print(f"  FAIL {name}\n       got  {got!r}\n       want {want!r}")


# ------------------------------------------------------------ Pokemon structures
ORDER = [0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1,
         1, 0, 2, 3, 1, 0, 3, 2, 2, 0, 1, 3, 3, 0, 1, 2, 2, 0, 3, 1, 3, 0, 2, 1,
         1, 2, 0, 3, 1, 3, 0, 2, 2, 1, 0, 3, 3, 1, 0, 2, 2, 3, 0, 1, 3, 2, 0, 1,
         1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 0,
         0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1,
         1, 0, 2, 3, 1, 0, 3, 2]


def crypt(data, seed):
    out = bytearray(data)
    for i in range(0, len(out), 2):
        seed = (0x41C64E6D * seed + 0x6073) & 0xFFFFFFFF
        w = struct.unpack_from("<H", out, i)[0] ^ (seed >> 16)
        struct.pack_into("<H", out, i, w)
    return bytes(out)


def text4_table():
    import re
    src = open(os.path.join(ROOT, "fold3ds", "pokebank", "text4.lua"), encoding="utf-8").read()
    return {v: int(k) for k, v in re.findall(r'\[(\d+)\]="((?:[^"\\]|\\.)*)"', src)}


T4 = None


def enc_text(fmt, s, chars):
    global T4
    out = bytearray(chars * 2)
    if fmt == "pk4":
        T4 = T4 or text4_table()
        vals = [T4[c] for c in s] + [0xFFFF]
    else:
        vals = [ord(c) for c in s] + [0xFFFF if fmt == "pk5" else 0]
    for i, v in enumerate(vals[:chars]):
        struct.pack_into("<H", out, i * 2, v)
    return bytes(out)


# format -> stored size, party size, offsets
FMT = {
    "pk4": dict(size=136, party=236, pid=0, moves=0x28, iv=0x38, nick=0x48, ot=0x68, nc=11, oc=8, lv=0x8C, g45=True),
    "pk5": dict(size=136, party=220, pid=0, moves=0x28, iv=0x38, nick=0x48, ot=0x68, nc=11, oc=8, lv=0x8C, g45=True),
    "pk6": dict(size=0xE8, party=0x104, pid=0x18, moves=0x5A, iv=0x74, nick=0x40, ot=0xB0, nc=13, oc=13, lv=0xEC),
    "pk7": dict(size=0xE8, party=0x104, pid=0x18, moves=0x5A, iv=0x74, nick=0x40, ot=0xB0, nc=13, oc=13, lv=0xEC),
    "pk8": dict(size=0x148, party=0x158, pid=0x1C, moves=0x72, iv=0x8C, nick=0x58, ot=0xF8, nc=13, oc=13, lv=0x148),
    "pb8": dict(size=0x148, party=0x158, pid=0x1C, moves=0x72, iv=0x8C, nick=0x58, ot=0xF8, nc=13, oc=13, lv=0x148),
    "pa8": dict(size=0x168, party=0x178, pid=0x1C, moves=0x54, iv=0x94, nick=0x60, ot=0x110, nc=13, oc=13, lv=0x168),
    "pk9": dict(size=0x148, party=0x158, pid=0x1C, moves=0x72, iv=0x8C, nick=0x58, ot=0xF8, nc=13, oc=13, lv=0x148),
}


def make_pk(fmt, mon, party):
    """A Pokemon, encrypted as the game stores it.  mon: dict of species
    (the value stored: internal for PK9), nick, ot, tid, sid, ec, pid, exp,
    item, moves, egg, level."""
    f = FMT[fmt]
    d = bytearray(f["size"])
    ec = mon["ec"]
    struct.pack_into("<I", d, 0, ec)
    if f["pid"]:
        struct.pack_into("<I", d, f["pid"], mon["pid"])
    struct.pack_into("<HHHHI", d, 8, mon["species"], mon["item"], mon["tid"], mon["sid"], mon["exp"])
    for i, m in enumerate(mon["moves"]):
        struct.pack_into("<H", d, f["moves"] + i * 2, m)
    struct.pack_into("<I", d, f["iv"], (1 << 30) if mon.get("egg") else 0x3FFFFFFF & 0x1234567)
    d[f["nick"]:f["nick"] + f["nc"] * 2] = enc_text(fmt, mon["nick"], f["nc"])
    d[f["ot"]:f["ot"] + f["oc"] * 2] = enc_text(fmt, mon["ot"], f["oc"])
    chk = sum(struct.unpack_from("<%dH" % ((f["size"] - 8) // 2), d, 8)) & 0xFFFF
    struct.pack_into("<H", d, 6, chk)
    # shuffle: the stored block at position ORDER[sv*4+k] is decrypted block k
    sv = (ec >> 13) & 31
    bs = (f["size"] - 8) // 4
    blocks = [d[8 + k * bs:8 + (k + 1) * bs] for k in range(4)]
    shuffled = [None] * 4
    for k in range(4):
        shuffled[ORDER[sv * 4 + k]] = blocks[k]
    body = crypt(b"".join(shuffled), chk if f.get("g45") else ec)
    out = bytes(d[:8]) + body
    if party:
        stats = bytearray(f["party"] - f["size"])
        stats[f["lv"] - f["size"]] = mon["level"]
        out += crypt(bytes(stats), ec)
    return out


def mons(fmt, n, rng, species_pool):
    out = []
    for i in range(n):
        ec = rng.getrandbits(32) | 1
        out.append(dict(species=species_pool[i % len(species_pool)], nick="MON%d" % i, ot="ASH",
                        tid=rng.getrandbits(16), sid=rng.getrandbits(16), ec=ec,
                        pid=ec if FMT[fmt].get("g45") else rng.getrandbits(32), exp=1000 + i,
                        item=i % 5, moves=[33, 45, 0, 0][: 1 + i % 3], level=5 + i, egg=(i == 3)))
    return out


# ------------------------------------------------------------ running the readers
LUA = r"""
package.path = ROOT .. "/?.lua;" .. package.path
local R = require(MOD)
local f = assert(io.open(PATH, "rb")); local b = f:read("*a"); f:close()
local t, why = R.read(b)
if not t then print("ERR", why) return end
print("SAVE", t.gen, t.game, t.trainer, t.tid, t.sid, #t.mons)
for _, m in ipairs(t.mons) do
  print("MON", m.format, m.where, m.slot, m.species, m.nick, m.ot, m.tid, m.level, m.item,
    table.concat(m.moves, ","), tostring(m.egg), #m.raw)
end
"""


def run(mod, data):
    with tempfile.NamedTemporaryFile(delete=False) as tf:
        tf.write(data)
        path = tf.name
    script = "ROOT=%r MOD=%r PATH=%r\n" % (ROOT, mod, path) + LUA
    try:
        res = subprocess.run(["luajit", "-e", script], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(path)
    if res.returncode != 0:
        return [("LUAERR", res.stderr.strip())]
    return [tuple(line.split("\t")) for line in res.stdout.splitlines()]


def expect(name, lines, gen, game, trainer, tid, sid, party, boxed, fmt, species_of=lambda s: s):
    head = lines[0] if lines else ("nothing",)
    check(name + " save", head, ("SAVE", str(gen), game, trainer, str(tid), str(sid), str(len(party) + len(boxed))))
    got = lines[1:]
    want = []
    for i, m in enumerate(party):
        want.append(("Party", str(i + 1), m, str(m["level"])))
    for where, slot, m in boxed:
        want.append((where, str(slot), m, None))
    for (where, slot, m, lv), g in zip(want, got):
        check(f"{name} {where} {slot}", (g[2], g[3], g[4], g[5], g[6], g[7], g[9], g[10], g[11]),
              (where, str(slot), str(species_of(m["species"])), m["nick"], m["ot"], str(m["tid"]), str(m["item"]),
               ",".join(str(x) for x in m["moves"] if x), "true" if m.get("egg") else "false"))
        check(f"{name} {where} {slot} format", g[1], fmt)
        if lv:
            check(f"{name} {where} {slot} level", g[8], lv)


# ------------------------------------------------------------ Gen 4
def gen4(game, general, storage, storage_size, trainer, party_at, box_at, box_stride, rng):
    b = bytearray(0x80000)
    ps = mons("pk4", 3, rng, [25, 387, 493])
    bx = mons("pk4", 4, rng, [1, 150, 251, 445])
    # the newer copy is the second partition's; the first holds junk
    for part, counter in ((0, 1), (0x40000, 2)):
        g = part
        b[g + party_at - 4] = len(ps) if counter == 2 else 1
        for i, m in enumerate(ps if counter == 2 else ps[:1]):
            b[g + party_at + i * 236:g + party_at + (i + 1) * 236] = make_pk("pk4", m, True)
        b[g + trainer:g + trainer + 16] = enc_text("pk4", "LUCAS" if counter == 2 else "OLD", 8)
        struct.pack_into("<HH", b, g + trainer + 0x10, 12345, 54321)
        for blk, size in ((g, general), (part + storage, storage_size)):
            o = blk + size - 0x14
            struct.pack_into("<IIIII", b, o, counter, 0, size, 0x20060623, 0)
    where = []
    s = 0x40000 + storage + box_at
    for i, m in enumerate(bx):
        box, slot = divmod(i * 7, 30)
        o = s + box * box_stride + slot * 136
        b[o:o + 136] = make_pk("pk4", m, False)
        where.append(("Box %d" % (box + 1), slot + 1, m))
    lines = run("fold3ds.pokebank.gen45", bytes(b))
    expect(game, lines, 4, game, "LUCAS", 12345, 54321, ps, where, "pk4")


# ------------------------------------------------------------ Gen 5
def crc16(data):
    crc = 0xFFFF
    for x in data:
        crc ^= x << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return crc


def gen5(game, size, info, rng):
    b = bytearray(0x80000)
    ps = mons("pk5", 2, rng, [494, 649])
    bx = mons("pk5", 5, rng, [495, 571, 643, 7, 0x100])
    b[0x18E04] = len(ps)
    for i, m in enumerate(ps):
        b[0x18E08 + i * 220:0x18E08 + (i + 1) * 220] = make_pk("pk5", m, True)
    where = []
    for i, m in enumerate(bx):
        box, slot = divmod(i * 13, 30)
        o = 0x400 + box * 0x1000 + slot * 136
        b[o:o + 136] = make_pk("pk5", m, False)
        where.append(("Box %d" % (box + 1), slot + 1, m))
    b[0x19404:0x19414] = enc_text("pk5", "HILDA", 8)
    struct.pack_into("<HH", b, 0x19414, 11111, 22222)
    f = size - 0x100
    b[f:f + info] = bytes(rng.getrandbits(8) for _ in range(info))
    struct.pack_into("<H", b, f + info + 0x10 - 2, crc16(b[f:f + info]))
    lines = run("fold3ds.pokebank.gen45", bytes(b))
    expect(game, lines, 5, game, "HILDA", 11111, 22222, ps, where, "pk5")


# ------------------------------------------------------------ Gen 6 / 7
def gen67(game, fmt, size, party_at, box_at, status, name, rng):
    b = bytearray(size)
    ps = mons(fmt, 4, rng, [650, 658, 722, 800])
    bx = mons(fmt, 3, rng, [716, 791, 25])
    for i, m in enumerate(ps):
        b[party_at + i * 0x104:party_at + (i + 1) * 0x104] = make_pk(fmt, m, True)
    b[party_at + 6 * 0x104] = len(ps)
    where = []
    for i, m in enumerate(bx):
        box, slot = divmod(i * 31, 30)
        o = box_at + (box * 30 + slot) * 0xE8
        b[o:o + 0xE8] = make_pk(fmt, m, False)
        where.append(("Box %d" % (box + 1), slot + 1, m))
    struct.pack_into("<HH", b, status, 4242, 2424)
    b[status + name:status + name + 26] = enc_text(fmt, "SERENA", 13)
    b[size - 0x1F0:size - 0x1F0 + 4] = struct.pack("<I", 0x42454546)
    lines = run("fold3ds.pokebank.gen67", bytes(b))
    expect(game, lines, int(fmt[2]), game, "SERENA", 4242, 2424, ps, where, fmt)


# ------------------------------------------------------------ Switch
XORPAD = None


def xorpad():
    import re
    src = open(os.path.join(ROOT, "fold3ds", "pokebank", "gen89.lua"), encoding="utf-8").read()
    body = src[src.index("local XORPAD = {"):]
    body = body[:body.index("}")]
    return [int(x, 16) for x in re.findall(r"0x([0-9A-F]{2})", body)]


def swish_crypt(data):
    """PKHeX's CryptStaticXorpadBytes, step by step."""
    xp = xorpad()
    data = bytearray(data)
    size = len(xp) - 1
    iterations = (len(data) - 1) // size
    pos = 0
    while True:
        for i in range(len(xp)):
            data[pos + i] ^= xp[i]
        pos += size
        iterations -= 1
        if iterations == 0:
            break
    for i in range(len(data) - pos):
        data[pos + i] ^= xp[i]
    return bytes(data)


class XorShift:
    def __init__(self, key):
        s = key
        for _ in range(bin(key).count("1")):
            s = self.adv(s)
        self.s, self.c = s, 0

    @staticmethod
    def adv(s):
        s ^= (s << 2) & 0xFFFFFFFF
        s ^= s >> 15
        s ^= (s << 13) & 0xFFFFFFFF
        return s

    def byte(self):
        r = (self.s >> (self.c * 8)) & 0xFF
        if self.c == 3:
            self.s, self.c = self.adv(self.s), 0
        else:
            self.c += 1
        return r

    def enc(self, data):
        return bytes(x ^ self.byte() for x in data)


def sc_object(key, payload):
    x = XorShift(key)
    return struct.pack("<I", key) + x.enc(bytes([4]) + struct.pack("<I", len(payload)) + payload)


def sc_value(key, typ, payload):
    x = XorShift(key)
    return struct.pack("<I", key) + x.enc(bytes([typ]) + payload)


def sc_array(key, sub, size, items):
    x = XorShift(key)
    return struct.pack("<I", key) + x.enc(bytes([5]) + struct.pack("<I", len(items) // size) + bytes([sub]) + items)


def switch(game, fmt, gen, box_key, party_key, status_key, stride, pstride, tid_at, name_at, boxes, rng,
           species_store=lambda s: s):
    ps = mons(fmt, 2, rng, [species_store(s) for s in (906, 1000)] if fmt == "pk9" else [810, 899])
    bx = mons(fmt, 3, rng, [species_store(s) for s in (25, 923, 1025)] if fmt == "pk9" else [25, 133, 888])
    party = bytearray(6 * pstride + 1)
    for i, m in enumerate(ps):
        party[i * pstride:(i + 1) * pstride] = make_pk(fmt, m, True)
    party[6 * pstride] = len(ps)
    box = bytearray(boxes * 30 * stride)
    where = []
    for i, m in enumerate(bx):
        bi, slot = divmod(i * 29, 30)
        o = (bi * 30 + slot) * stride
        box[o:o + stride] = make_pk(fmt, m, stride != FMT[fmt]["size"])[:stride]
        where.append(("Box %d" % (bi + 1), slot + 1, m))
    status = bytearray(0x200)
    struct.pack_into("<HH", status, tid_at, 777, 888)
    status[name_at:name_at + 26] = enc_text(fmt, "GLORIA", 13)
    blocks = [sc_value(0x11111111, 1, b""), sc_value(0x22222222, 10, struct.pack("<I", 5)),
              sc_array(0x33333333, 9, 2, b"\x01\x00\x02\x00"), sc_object(status_key, bytes(status)),
              sc_object(party_key, bytes(party)), sc_value(0x44444444, 2, b""),
              sc_object(box_key, bytes(box)), sc_object(0x55555555, b"filler" * 40)]
    data = swish_crypt(b"".join(blocks)) + bytes(32)
    lines = run("fold3ds.pokebank.gen89", data)
    nat = (lambda s: INTERNAL9.get(s, s)) if fmt == "pk9" else (lambda s: s)
    expect(game, lines, gen, game, "GLORIA", 777, 888, ps, where, fmt, species_of=nat)


INTERNAL9 = {}


def load_internal9():
    import re
    src = open(os.path.join(ROOT, "fold3ds", "pokebank", "species.lua"), encoding="utf-8").read()
    line = next(l for l in src.splitlines() if l.startswith("S.GEN9_INTERNAL"))
    INTERNAL9.update({int(a): int(b) for a, b in re.findall(r"\[(\d+)\] = (\d+)", line)})


def bdsp(rng):
    size, ver = 0xEF0A4, 0x34
    b = bytearray(size)
    struct.pack_into("<I", b, 0, ver)
    ps = mons("pb8", 3, rng, [387, 390, 393])
    bx = mons("pb8", 2, rng, [483, 484])
    for i, m in enumerate(ps):
        b[0x14098 + i * 0x158:0x14098 + (i + 1) * 0x158] = make_pk("pb8", m, True)
    b[0x14098 + 6 * 0x158] = len(ps)
    where = []
    for i, m in enumerate(bx):
        bi, slot = divmod(i * 45, 30)
        o = 0x14EF4 + (bi * 30 + slot) * 0x158
        b[o:o + 0x158] = make_pk("pb8", m, True)
        where.append(("Box %d" % (bi + 1), slot + 1, m))
    b[0x79BB4:0x79BB4 + 26] = enc_text("pb8", "DAWN", 13)
    struct.pack_into("<HH", b, 0x79BB4 + 0x1C, 31337, 7331)
    lines = run("fold3ds.pokebank.gen89", bytes(b))
    expect("BDSP", lines, 8, "Brilliant Diamond / Shining Pearl", "DAWN", 31337, 7331, ps, where, "pb8")


def main():
    rng = random.Random(4)
    load_internal9()
    to_internal = {v: k for k, v in INTERNAL9.items()}
    gen4("Diamond / Pearl", 0xC100, 0xC100, 0x121E0, 0x64, 0x98, 4, 0xFF0, rng)
    gen4("Platinum", 0xCF2C, 0xCF2C, 0x121E4, 0x68, 0xA0, 4, 0xFF0, rng)
    gen4("HeartGold / SoulSilver", 0xF628, 0xF700, 0x12310, 0x64, 0x98, 0, 0x1000, rng)
    gen5("Black / White", 0x24000, 0x8C, rng)
    gen5("Black 2 / White 2", 0x26000, 0x94, rng)
    gen67("X / Y", "pk6", 0x65600, 0x14200, 0x22600, 0x14000, 0x48, rng)
    gen67("Omega Ruby / Alpha Sapphire", "pk6", 0x76000, 0x14200, 0x33000, 0x14000, 0x48, rng)
    gen67("Sun / Moon", "pk7", 0x6BE00, 0x1400, 0x4E00, 0x1200, 0x38, rng)
    gen67("Ultra Sun / Ultra Moon", "pk7", 0x6CC00, 0x1600, 0x5200, 0x1400, 0x38, rng)
    switch("Sword / Shield", "pk8", 8, 0x0D66012C, 0x2985FE5D, 0xF25C070E, 0x158, 0x158, 0xA0, 0xB0, 2, rng)
    switch("Legends: Arceus", "pa8", 8, 0x47E1CEAB, 0x2985FE5D, 0xF25C070E, 0x168, 0x178, 0x10, 0x20, 2, rng)
    switch("Scarlet / Violet", "pk9", 9, 0x0D66012C, 0x3AA1A9AD, 0xE3E89BD1, 0x158, 0x158, 0x00, 0x10, 2, rng,
           species_store=lambda s: to_internal.get(s, s))
    bdsp(rng)
    # not a save at all
    check("junk", run("fold3ds.pokebank.gen45", bytes(0x80000))[0][0], "ERR")
    check("junk 3DS", run("fold3ds.pokebank.gen67", bytes(0x65600))[0][0], "ERR")
    check("junk Switch", run("fold3ds.pokebank.gen89", bytes(rng.getrandbits(8) for _ in range(4096)))[0][0], "ERR")
    print(f"{PASS} passed, {FAIL} failed")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
