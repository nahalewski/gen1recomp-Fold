#!/usr/bin/env python3
"""Cuts the AeonDX boot art (tools/art/) into the pieces fold3ds/init.lua
animates on the boot screens (fold3ds/boot/aeondx_*.png).

  aeondx_boot_sheet.png  the top screen's sprite sheet: the logo, the logo in
                         its ring, the ring, the blue and purple streaks
  aeondx_loading.png     the bottom screen: the logo, "Loading...", the
                         empty bar and the full bar (the fill is animated)

Each box is a region of the 1448x1086 source; the piece is trimmed to what
is visible in it and its edges feathered so a neighbour's glow isn't cut
off hard.  Run after changing the art: python3 tools/make_boot_sprites.py
"""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "art")
OUT = os.path.join(HERE, "..", "fold3ds", "boot")

PIECES = {
    "aeondx_boot_sheet.png": {
        "logo": (10, 110, 790, 450),
        "ringlogo": (795, 10, 1448, 505),
        "ring": (0, 470, 565, 890),
        "streak_blue": (515, 520, 990, 890),
        "streak_purple": (945, 500, 1448, 890),
    },
    "aeondx_loading.png": {
        "load_logo": (262, 172, 1330, 540),
        "load_text": (440, 548, 1040, 628),
        "bar_empty": (330, 648, 1102, 716),
        "bar_full": (330, 912, 1102, 980),
    },
}
FEATHER = 10
MAX_W = 1024


def feathered(img):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle((FEATHER, FEATHER, w - FEATHER - 1, h - FEATHER - 1), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(FEATHER / 2))
    r, g, b, a = img.split()
    return Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, mask)))


def main():
    os.makedirs(OUT, exist_ok=True)
    for src, boxes in PIECES.items():
        sheet = Image.open(os.path.join(ART, src)).convert("RGBA")
        for name, box in boxes.items():
            piece = sheet.crop(box)
            if not name.startswith("bar_"):   # the bars keep their box: the fill lines up
                piece = feathered(piece)
                bbox = piece.split()[3].point(lambda v: 255 if v > 6 else 0).getbbox()
                if bbox:
                    piece = piece.crop(bbox)
            if piece.width > MAX_W:
                k = MAX_W / piece.width
                piece = piece.resize((MAX_W, round(piece.height * k)), Image.LANCZOS)
            piece.save(os.path.join(OUT, "aeondx_" + name + ".png"), optimize=True)
            print(name, piece.size)


if __name__ == "__main__":
    main()
