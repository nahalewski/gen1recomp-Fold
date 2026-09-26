#!/usr/bin/env python3
"""Cuts the teardown Easter egg's art (tools/art/teardown_*.png) into the
pieces fold3ds/teardown.lua throws around the cover screen.

  teardown_inside.png       the top half with its cover off, everything in:
                            the shell the parts go back into (inside.png)
  teardown_parts_back.png   the parts laid out, the side that faces the
                            cover (<part>_a.png: how each one goes back in)
  teardown_parts_front.png  the same parts turned over (<part>_b.png)

The boxes are regions of the 1448 x 1086 part sheets (the two line up to a
few pixels).  A piece is the box's visible pixels, minus the boxes listed
in CUT (where a neighbour touches it).  Run after changing the art:
python3 tools/make_teardown_sprites.py
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "art")
OUT = os.path.join(HERE, "..", "fold3ds", "teardown")

PARTS = {
    "lcd": (338, 520, 1114, 904),
    "speaker_l": (1004, 78, 1108, 421),
    "speaker_r": (1295, 78, 1405, 421),
    "camera_l": (1114, 122, 1192, 250),
    "camera_r": (1217, 122, 1292, 250),
    "ircam": (1130, 271, 1277, 345),
    "screw_1": (1126, 370, 1166, 421),
    "screw_2": (1181, 370, 1222, 421),
    "screw_3": (1236, 370, 1278, 421),
    "screw_4": (1126, 435, 1166, 486),
    "screw_5": (1181, 435, 1222, 486),
    "screw_6": (1236, 435, 1278, 486),
    "bracket_1": (1033, 463, 1116, 533),
    "bracket_2": (1149, 512, 1255, 577),
    "bracket_3": (1289, 463, 1368, 561),
    "bracket_4": (66, 801, 135, 905),
    "bracket_5": (1340, 800, 1413, 905),
    "bracket_6": (526, 950, 668, 1018),
    "ribbon_l": (64, 566, 301, 932),
    "ribbon_r": (1185, 580, 1378, 921),
    "foam_1": (107, 949, 256, 1026),
    "foam_2": (271, 945, 518, 1024),
    "ribbon_long": (678, 941, 1380, 1042),
}
# a piece loses the parts of these boxes that overlap it
CUT = {"lcd": ["bracket_1"]}


def cut(sheet, name):
    box = PARTS[name]
    piece = sheet.crop(box)
    if name in CUT:
        mask = Image.new("L", piece.size, 255)
        d = ImageDraw.Draw(mask)
        for other in CUT[name]:
            o = PARTS[other]
            d.rectangle((o[0] - box[0], o[1] - box[1], o[2] - box[0], o[3] - box[1]), fill=0)
        r, g, b, a = piece.split()
        a = Image.composite(a, Image.new("L", piece.size, 0), mask)
        piece = Image.merge("RGBA", (r, g, b, a))
    return piece


def main():
    os.makedirs(OUT, exist_ok=True)
    inside = Image.open(os.path.join(ART, "teardown_inside.png")).convert("RGBA")
    inside.save(os.path.join(OUT, "inside.png"), optimize=True)
    for side, src in (("a", "teardown_parts_back.png"), ("b", "teardown_parts_front.png")):
        sheet = Image.open(os.path.join(ART, src)).convert("RGBA")
        for name in PARTS:
            cut(sheet, name).save(os.path.join(OUT, "%s_%s.png" % (name, side)), optimize=True)
    print(len(PARTS), "parts")


if __name__ == "__main__":
    main()
