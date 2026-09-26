#!/usr/bin/env python3
"""Cuts the emuPoke Bank UI sheet (tools/art/pokebank_sheet.png, the
user's art, 1448 x 1086) into the pieces fold3ds/pokebank draws
(fold3ds/pokebank/ui/<name>.png).  Boxes are regions of the sheet; each
piece is trimmed to its visible pixels.  Run after changing the art:
python3 tools/make_pokebank_ui.py
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SHEET = os.path.join(HERE, "art", "pokebank_sheet.png")
OUT = os.path.join(HERE, "..", "fold3ds", "pokebank", "ui")

P = {
    "logo": (8, 5, 632, 331), "logo_small": (612, 62, 824, 252), "icon": (833, 65, 1017, 286),
    "tab_boxes": (1033, 11, 1273, 71), "tab_party": (1033, 71, 1273, 126),
    "tab_cloud": (1033, 126, 1273, 182), "tab_dex": (1032, 182, 1273, 241),
    "tab_favorites": (1032, 242, 1273, 302),
    "badge_new": (1297, 39, 1434, 91), "badge_online": (1295, 95, 1434, 148),
    "badge_link": (1295, 155, 1433, 208), "badge_saved": (1295, 215, 1434, 269),
    "panel_main": (16, 330, 470, 621), "panel_box": (479, 328, 870, 623),
    "panel_info": (875, 330, 1140, 620), "panel_name": (1148, 330, 1434, 430),
    "panel_notes": (1148, 429, 1434, 532), "panel_capacity": (1148, 532, 1434, 621),
    "slot_empty": (21, 632, 111, 719), "slot_empty2": (119, 631, 210, 719),
    "slot_blue": (218, 630, 310, 720), "slot_purple": (316, 630, 409, 721),
    "slot_locked": (416, 632, 506, 719), "slot_mon": (515, 632, 606, 719),
    "slot_add": (615, 632, 703, 718),
    "arrow_left": (924, 636, 1005, 683), "arrow_right": (1010, 636, 1091, 682),
    "num_1": (1109, 634, 1165, 683), "num_2": (1169, 637, 1218, 682), "num_3": (1223, 637, 1272, 681),
    "num_4": (1277, 637, 1327, 681), "num_5": (1331, 637, 1380, 681), "num_6": (1385, 637, 1434, 681),
    "bar_title": (710, 695, 886, 739), "bar_cyan": (894, 695, 1069, 739),
    "bar_purple": (1077, 695, 1252, 739), "bar_grey": (1262, 696, 1433, 738),
    "btn_deposit": (23, 742, 182, 845), "btn_withdraw": (186, 742, 343, 845),
    "btn_move": (346, 742, 503, 845), "btn_search": (502, 742, 660, 845),
    "btn_sort": (660, 742, 820, 845), "btn_filter": (23, 850, 182, 951),
    "btn_trade": (186, 850, 343, 951), "btn_settings": (346, 850, 503, 951),
    "btn_back": (506, 849, 660, 949), "btn_confirm": (661, 850, 821, 951),
}
ICONS1 = ["search", "sort", "filter", "folder", "cloud", "storage", "swap"]
ICONS2 = ["up", "down", "left", "right", "plus", "minus", "star", "gear"]
ICONS3 = ["info", "warning", "ok", "cancel", "refresh", "trash", "hand"]
X1 = [(840, 904), (917, 983), (996, 1062), (1075, 1141), (1155, 1221), (1235, 1302), (1315, 1383)]
X2 = [(840, 905), (917, 983), (996, 1061), (1075, 1141), (1154, 1209), (1222, 1275), (1287, 1349), (1361, 1427)]
X3 = [(839, 908), (920, 987), (1000, 1069), (1084, 1151), (1165, 1234), (1248, 1319), (1341, 1391)]
for n, (a, b) in zip(ICONS1, X1): P["ico_" + n] = (a - 2, 746, b + 2, 798)
for n, (a, b) in zip(ICONS2, X2): P["ico_" + n] = (a - 2, 803, b + 2, 855)
for n, (a, b) in zip(ICONS3, X3): P["ico_" + n] = (a - 2, 857, b + 2, 921)
for i, (a, b) in enumerate([(826, 895), (903, 972), (980, 1049), (1057, 1126), (1134, 1203),
                            (1211, 1281), (1289, 1358), (1367, 1436)], 1):
    P["silhouette_%d" % i] = (a - 2, 932, b + 2, 1005)


# the second sheet (tools/art/pokebank_sheet2.png): tabs, HOME / Switch app
# icons, big bottom-screen buttons, small square icons, utility icons and
# more silhouettes
SHEET2 = os.path.join(HERE, "art", "pokebank_sheet2.png")
P2 = {}
def row(names, xs, y0, y1, prefix):
    for n, (a, b) in zip(names, xs):
        P2[prefix + n] = (a - 2, y0 - 2, b + 2, y1 + 2)
TOP = ["boxes", "party", "cloud", "dex", "search", "settings", "favorites"]
row(TOP, [(13, 128), (127, 242), (242, 357), (357, 472), (471, 584), (585, 698), (701, 815)], 66, 174, "tab2_")
row(["trade", "filter", "sort", "move", "deposit", "withdraw", "back", "confirm"],
    [(14, 113), (111, 210), (209, 309), (308, 408), (409, 511), (511, 614), (613, 713), (713, 821)], 192, 300, "tab2_")
P2["app_icon_l"] = (838, 60, 1079, 306)
P2["app_icon_m"] = (1088, 80, 1292, 292)
P2["app_icon_s"] = (1296, 123, 1442, 292)
row(["boxes", "party", "cloud", "dex"], [(25, 202), (209, 385), (391, 567), (573, 750)], 378, 475, "big_")
row(["search", "settings", "favorites", "trade"], [(26, 203), (210, 386), (392, 568), (574, 751)], 484, 584, "big_")
row(["filter", "sort", "move", "deposit", "withdraw"], [(24, 155), (167, 299), (311, 444), (457, 601), (608, 754)], 595, 702, "big_")
row(["back", "back_purple", "confirm", "confirm_green"], [(21, 185), (194, 366), (372, 561), (570, 756)], 712, 811, "big_")
row(TOP, [(790, 872), (878, 959), (964, 1048), (1054, 1138), (1144, 1226), (1232, 1313), (1319, 1401)], 378, 455, "sq_")
row(["trade", "filter", "sort", "move", "deposit", "withdraw", "back", "confirm"],
    [(790, 866), (870, 946), (950, 1027), (1031, 1107), (1111, 1187), (1192, 1268), (1271, 1347), (1351, 1425)], 463, 539, "sq_")
P2["switch_icon"] = (787, 611, 1019, 815)
P2["switch_icon_on"] = (1026, 606, 1262, 818)
P2["switch_icon_s"] = (1266, 620, 1427, 802)
row(["ball", "grid", "cloud", "swap", "star", "search", "filter", "gear"],
    [(26, 112), (120, 208), (215, 303), (308, 396), (402, 490), (496, 584), (592, 679), (686, 773)], 881, 960, "util_")
row(["folder", "info", "warning", "ok", "cancel", "plus", "minus", "refresh"],
    [(24, 111), (117, 203), (208, 295), (302, 389), (398, 485), (495, 581), (590, 677), (686, 772)], 970, 1051, "util_")
for i, (a, b) in enumerate([(806, 894), (903, 991), (1002, 1090), (1102, 1190), (1202, 1290), (1302, 1390)], 1):
    P2["mon2_%d" % i] = (a - 2, 876, b + 2, 960)
for i, (a, b) in enumerate([(805, 894), (902, 991), (1000, 1090), (1100, 1189), (1201, 1289), (1301, 1390)], 7):
    P2["mon2_%d" % i] = (a - 2, 966, b + 2, 1055)


def cut(sheet, boxes):
    for name, box in boxes.items():
        piece = sheet.crop(box)
        bbox = piece.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
        if bbox:
            piece = piece.crop(bbox)
        piece.save(os.path.join(OUT, name + ".png"), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    cut(Image.open(SHEET2).convert("RGBA"), P2)
    sheet = Image.open(SHEET).convert("RGBA")
    for name, box in P.items():
        piece = sheet.crop(box)
        bbox = piece.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
        if bbox:
            piece = piece.crop(bbox)
        piece.save(os.path.join(OUT, name + ".png"), optimize=True)
    print(len(P) + len(P2), "pieces")


if __name__ == "__main__":
    main()
