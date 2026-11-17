"""Generate the prototype pixel art (2-head-tall SD characters, cozy tiles, icons).

Run from the project root:  python tools/gen_placeholders.py   (needs Pillow)
Everything lands in assets/sprites/placeholder/. Replace these files with real art
later, keeping the same file names and frame layout, and the game picks them up.

Frame layout of character sheets (24x32 px per frame, feet at y=29):
  rows: 0 = down, 1 = up, 2 = side (facing right; left is drawn flipped)
  cols: 0..3 walk cycle (col 0 doubles as the idle frame)
Player sheets are split into layers that the game tints at runtime:
  player_base.png (skin, face, shirt, legs) / player_outfit.png (light gray -> tinted)
  player_hair_0.png, player_hair_1.png (light gray -> tinted)
NPC sheets: one row (down), 2 idle frames.
Tiles: one row of 16x16 tiles, order = TILES below = enum in scripts/world/tiles.gd.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "placeholder"
OUT.mkdir(parents=True, exist_ok=True)

FW, FH = 24, 32
X0 = 4  # templates are 16 wide, centered in the 24 px frame
T = (0, 0, 0, 0)
OUTLINE = (38, 30, 44, 255)

SKIN = (255, 220, 184, 255)
SKIN_D = (236, 178, 140, 255)
EYE = (36, 32, 60, 255)
EYE_HI = (255, 255, 255, 255)
BLUSH = (255, 160, 160, 255)
MOUTH = (200, 100, 100, 255)
SHIRT = (250, 250, 255, 255)
SHIRT_D = (210, 214, 230, 255)
TIE = (210, 60, 70, 255)
TIE_D = (150, 40, 50, 255)
PANTS = (54, 60, 88, 255)
PANTS_D = (38, 42, 64, 255)
SHOE = (60, 40, 36, 255)
G1 = (250, 250, 250, 255)  # tint-able light
G2 = (208, 208, 214, 255)  # tint-able shade
G3 = (160, 160, 170, 255)  # tint-able dark


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def fill(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def mirror(rows):
    return [r + r[::-1] for r in rows]


def stamp(img, rows, ox, oy, palette):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != "." and ch in palette:
                px(img, ox + x, oy + y, palette[ch])


def outline(img, mask_imgs=None, color=OUTLINE):
    """Adds a 1 px outline around the opaque pixels of mask_imgs (default: img)."""
    masks = mask_imgs or [img]
    w, h = img.size
    solid = [[any(m.getpixel((x, y))[3] > 0 for m in masks) for x in range(w)] for y in range(h)]
    own = [[img.getpixel((x, y))[3] > 0 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and own[ny][nx]:
                    img.putpixel((x, y), color)
                    break


# ------------------------------------------------------------------ heads (16 wide)
HEAD_DOWN = mirror([
    "....ssss", "..ssssss", ".sssssss", ".sssssss", "ssssssss", "ssssssss", "ssssssss",
    "ssswesss", "ssseesss", "sbbssssm", ".sssssss", "..ssssss", "....oooo",
])
HEAD_UP = [r.replace("w", "s").replace("e", "s").replace("b", "s").replace("m", "s") for r in HEAD_DOWN]
HEAD_SIDE = [
    "....ssssssss....", "..ssssssssssss..", ".ssssssssssssss.", ".ssssssssssssss.",
    "ssssssssssssssss", "ssssssssssssssss", "ssssssssssssssss", "s" * 11 + "we" + "sss",
    "s" * 11 + "ee" + "sss", "s" * 9 + "bb" + "ss" + "m" + "ss", ".ssssssssssssss.",
    "..ssssssssssss..", "....oooooooo....",
]
HEAD_PAL = {"s": SKIN, "w": EYE_HI, "e": EYE, "b": BLUSH, "m": MOUTH, "o": SKIN_D}

# hair grids start one row above the head
_TOP = ["....HHHH", "..HHHHHH", ".HHHHHHH", "HHHIHHHH", "HHIIHHIH", "HIIIIHII", "HIIJIIIJ"]
HAIR_DOWN = {
    0: mirror(_TOP + ["HIJ.JIJ.", "IJ......", "J......."]),
    1: mirror(_TOP + ["HIJ.JIJ.", "IIJ.....", "IIJ.....", "IJJ.....", "IJ......", "IJ......",
                      "IJ......", "JJ......", ".J......"]),
}
_BACK = ["....HHHH", "..HHHHHH", ".HHHHHHH", "HHHHHHHH", "HHHIHHHH", "HIIIHIII", "HIIIIIII",
         "IIJIIIJI", "IJIJIJIJ", "IJJJJJJJ"]
HAIR_UP = {
    0: mirror(_BACK + [".JJJJJJJ", "..JJJJJJ", "....JJJJ"]),
    1: mirror(_BACK + ["IJJJJJJJ", "IJJIIJJJ", "IIJJJJJJ", ".IJJJJJJ", ".IIJJJJJ", "..IJJJJJ",
                       "...JJJJJ"]),
}
_SIDE = ["....HHHHHHHH", "..HHHHHHHHHHHH", ".HHHHHHHHHHHHHH", "HHHHHHHHHIHHHHHH",
         "HHHHHHIHHIIHHIH", "HHIIIIIIIIIJIIJ", "IIIIIIIJIJ.J.J", "IIIIIJJ", "IIIIJ", "IIJJ"]
HAIR_SIDE = {
    0: _SIDE + ["JJJ", ".J"],
    1: _SIDE + ["IIIJ", "IIIJ", "IIJJ", "IIJ", "IIJ", "IJJ", "JJ", ".J"],
}
HAIR_PAL_TINT = {"H": G1, "I": G2, "J": G3}


def bob(col):
    return 1 if col in (1, 3) else 0


# ------------------------------------------------------------------ bodies
def draw_legs(img, row, col, pants=PANTS, pants_d=PANTS_D, shoe=SHOE):
    if row in (0, 1):
        lift_l = 1 if col == 1 else 0
        lift_r = 1 if col == 3 else 0
        fill(img, 9, 23, 11, 27 - lift_l, pants)
        fill(img, 12, 23, 14, 27 - lift_r, pants_d)
        fill(img, 8, 28 - lift_l, 11, 29 - lift_l, shoe)
        fill(img, 12, 28 - lift_r, 15, 29 - lift_r, shoe)
    else:
        if col in (0, 2):
            fill(img, 10, 23, 12, 27, pants_d)
            fill(img, 12, 23, 14, 27, pants)
            fill(img, 10, 28, 15, 29, shoe)
        else:
            back, front = (pants_d, pants) if col == 1 else (pants, pants_d)
            fill(img, 8, 23, 10, 27, back)
            fill(img, 7, 28, 10, 29, shoe)
            fill(img, 13, 23, 15, 27, front)
            fill(img, 13, 28, 16, 29, shoe)


def draw_base_body(img, row, col, shirt=SHIRT, tie=TIE, skin=SKIN_D):
    t = 15 + bob(col)
    if row == 0:
        fill(img, 10, t, 13, t + 5, shirt)
        if tie:
            fill(img, 11, t, 12, t + 3, tie)
            fill(img, 11, t + 4, 12, t + 4, TIE_D)
        fill(img, 5, t + 5, 6, t + 6, skin)
        fill(img, 17, t + 5, 18, t + 6, skin)
    elif row == 1:
        fill(img, 5, t + 5, 6, t + 6, skin)
        fill(img, 17, t + 5, 18, t + 6, skin)
    else:
        fill(img, 14, t, 15, t + 1, shirt)
        hx = {0: 10, 1: 12, 2: 10, 3: 8}[col]
        fill(img, hx, t + 6, hx + 2, t + 7, skin)


def draw_jacket(img, row, col, c1=G1, c2=G2, c3=G3):
    t = 15 + bob(col)
    if row in (0, 1):
        fill(img, 7, t, 16, t + 7, c1)
        fill(img, 15, t + 1, 16, t + 7, c2)
        fill(img, 7, t + 7, 16, t + 7, c3)
        fill(img, 5, t, 6, t + 4, c2)
        fill(img, 17, t, 18, t + 4, c2)
        fill(img, 6, t + 1, 6, t + 4, c3)
        fill(img, 17, t + 1, 17, t + 4, c3)
        if row == 0:  # V opening shows the shirt and tie
            for y, (a, b) in enumerate(((10, 13), (10, 13), (10, 13), (11, 12), (11, 12))):
                fill(img, a, t + y, b, t + y, T)
            px(img, 11, t + 6, c3)
        else:
            fill(img, 11, t + 2, 12, t + 6, c2)
    else:
        fill(img, 8, t, 15, t + 7, c1)
        fill(img, 8, t + 1, 9, t + 7, c2)
        fill(img, 8, t + 7, 15, t + 7, c3)
        fill(img, 14, t, 15, t + 1, T)  # shirt collar at the front
        ax = {0: 10, 1: 12, 2: 10, 3: 8}[col]
        fill(img, ax, t + 1, ax + 2, t + 5, c2)
        fill(img, ax, t + 1, ax, t + 5, c3)


HEADS = {0: HEAD_DOWN, 1: HEAD_UP, 2: HEAD_SIDE}
HAIRS = {0: HAIR_DOWN, 1: HAIR_UP, 2: HAIR_SIDE}


def char_layers(row, col, style, hair_pal=HAIR_PAL_TINT, jacket=(G1, G2, G3), extras=None,
                shirt=SHIRT, tie=TIE, pants=(PANTS, PANTS_D)):
    """Returns (base, outfit, hair) images for one frame."""
    base = Image.new("RGBA", (FW, FH), T)
    outfit = Image.new("RGBA", (FW, FH), T)
    hair = Image.new("RGBA", (FW, FH), T)
    b = bob(col)
    draw_legs(base, row, col, *pants)
    draw_base_body(base, row, col, shirt, tie)
    stamp(base, HEADS[row], X0, 2 + b, HEAD_PAL)
    if jacket:
        draw_jacket(outfit, row, col, *jacket)
    if style is not None:
        stamp(hair, [r.ljust(16, ".") for r in HAIRS[row][style]], X0, 1 + b, hair_pal)
    if extras:
        extras(base, outfit, hair, row, col, b)
    # outlines: base+outfit share a silhouette, hair outlines itself on top
    outline(base, [base, outfit])
    outline(hair, [base, outfit, hair])
    return base, outfit, hair


def make_player():
    sheets = {n: Image.new("RGBA", (FW * 4, FH * 3), T) for n in
              ("player_base.png", "player_outfit.png", "player_hair_0.png", "player_hair_1.png")}
    for r in range(3):
        for c in range(4):
            base, outfit, hair0 = char_layers(r, c, 0)
            _, _, hair1 = char_layers(r, c, 1)
            for name, im in (("player_base.png", base), ("player_outfit.png", outfit),
                             ("player_hair_0.png", hair0), ("player_hair_1.png", hair1)):
                sheets[name].paste(im, (c * FW, r * FH))
    for name, im in sheets.items():
        im.save(OUT / name)


def merged(*layers):
    out = Image.new("RGBA", (FW, FH), T)
    for im in layers:
        out.alpha_composite(im)
    return out


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def hair_pal(c):
    return {"H": shade(c, 1.15), "I": c, "J": shade(c, 0.75)}


def jacket_cols(c):
    return (c, shade(c, 0.85), shade(c, 0.68))


def human_npc(name, jacket, hair, style=0, extras=None, shirt=SHIRT, tie=TIE, pants=(PANTS, PANTS_D)):
    img = Image.new("RGBA", (FW * 2, FH), T)
    for c in range(2):
        col = 1 if c == 1 else 0  # frame 1 bobs
        base, outfit, hr = char_layers(0, col if c == 1 else 0, style, hair_pal(hair),
                                       jacket_cols(jacket) if jacket else None, extras, shirt, tie, pants)
        img.paste(merged(base, outfit, hr), (c * FW, 0))
    img.save(OUT / f"npc_{name}.png")


def glasses(base, outfit, hair, row, col, b):
    for x0 in (X0 + 2, X0 + 9):
        for x in range(x0, x0 + 5):
            px(hair, x, 2 + b + 6, OUTLINE)
            px(hair, x, 2 + b + 9, OUTLINE)
        for y in range(6, 10):
            px(hair, x0, 2 + b + y, OUTLINE)
            px(hair, x0 + 4, 2 + b + y, OUTLINE)
    px(hair, X0 + 7, 2 + b + 7, OUTLINE)
    px(hair, X0 + 8, 2 + b + 7, OUTLINE)


def cap(color):
    def fn(base, outfit, hair, row, col, b):
        fill(hair, X0, 1 + b, X0 + 15, 4 + b, color)
        fill(hair, X0 + 2, 0 + b, X0 + 13, 0 + b, color)
        fill(hair, X0 + 3, 5 + b, X0 + 12, 5 + b, shade(color, 0.7))
    return fn


def apron(base, outfit, hair, row, col, b):
    t = 15 + b
    fill(outfit, 9, t + 1, 14, t + 7, (252, 252, 252, 255))
    fill(outfit, 9, t + 7, 14, t + 7, (220, 220, 225, 255))
    fill(hair, X0 + 1, 1 + b, X0 + 14, 3 + b, (255, 255, 255, 255))  # kerchief
    fill(hair, X0 + 1, 3 + b, X0 + 14, 3 + b, (225, 225, 230, 255))


def stork(img, ox, b):
    """나르미: white stork with a long orange beak and black wing tips."""
    W, Wd, K, O, R = (252, 252, 255, 255), (214, 218, 232, 255), (44, 44, 58, 255), (246, 150, 50, 255), (230, 90, 70, 255)
    lay = Image.new("RGBA", (FW, FH), T)
    d = ImageDraw.Draw(lay)
    d.line([(9, 25), (9, 29)], fill=R)
    d.line([(14, 25), (14, 29)], fill=R)
    d.line([(8, 29), (10, 29)], fill=R)
    d.line([(13, 29), (15, 29)], fill=R)
    d.ellipse([6, 13 + b, 17, 26], fill=W)
    d.ellipse([7, 20 + b, 16, 26], fill=Wd)
    d.ellipse([3, 15 + b, 8, 24], fill=K)
    d.ellipse([15, 15 + b, 20, 24], fill=K)
    d.ellipse([5, 2 + b, 18, 14 + b], fill=W)
    fill(lay, 8, 7 + b, 9, 8 + b, EYE)
    fill(lay, 14, 7 + b, 15, 8 + b, EYE)
    px(lay, 8, 7 + b, EYE_HI)
    px(lay, 14, 7 + b, EYE_HI)
    fill(lay, 6, 10 + b, 7, 10 + b, BLUSH)
    fill(lay, 16, 10 + b, 17, 10 + b, BLUSH)
    d.polygon([(10, 10 + b), (13, 10 + b), (12, 17 + b), (11, 17 + b)], fill=O)
    fill(lay, 10, 15 + b, 13, 16 + b, TIE)  # tiny tie: she works here too
    outline(lay)
    img.paste(lay, (ox, 0), lay)


def squirrel(img, ox, b):
    """달이: brown squirrel with a big striped tail and a green scarf."""
    N, Nd, C, G = (196, 124, 64, 255), (150, 90, 48, 255), (248, 222, 180, 255), (90, 170, 110, 255)
    lay = Image.new("RGBA", (FW, FH), T)
    d = ImageDraw.Draw(lay)
    d.ellipse([13, 3, 23, 23], fill=N)
    d.ellipse([16, 6, 21, 19], fill=Nd)
    d.ellipse([6, 15 + b, 16, 28], fill=N)
    d.ellipse([8, 18 + b, 14, 27], fill=C)
    fill(lay, 7, 28, 9, 29, Nd)
    fill(lay, 13, 28, 15, 29, Nd)
    d.ellipse([3, 4 + b, 16, 16 + b], fill=N)
    d.polygon([(4, 6 + b), (5, 1 + b), (8, 4 + b)], fill=N)
    d.polygon([(15, 6 + b), (14, 1 + b), (11, 4 + b)], fill=N)
    d.ellipse([5, 9 + b, 14, 16 + b], fill=C)
    fill(lay, 6, 8 + b, 7, 9 + b, EYE)
    fill(lay, 12, 8 + b, 13, 9 + b, EYE)
    px(lay, 6, 8 + b, EYE_HI)
    px(lay, 12, 8 + b, EYE_HI)
    fill(lay, 9, 11 + b, 10, 11 + b, (90, 50, 40, 255))
    fill(lay, 4, 11 + b, 5, 11 + b, BLUSH)
    fill(lay, 14, 11 + b, 15, 11 + b, BLUSH)
    fill(lay, 6, 16 + b, 15, 17 + b, G)
    fill(lay, 13, 18 + b, 14, 20 + b, G)
    outline(lay)
    img.paste(lay, (ox, 0), lay)


def mascot(name, fn):
    img = Image.new("RGBA", (FW * 2, FH), T)
    for c in range(2):
        fn(img, c * FW, c)
    img.save(OUT / f"npc_{name}.png")


def make_npcs():
    mascot("narumi", stork)
    mascot("dari", squirrel)
    human_npc("team_leader", (52, 62, 112, 255), (70, 70, 76, 255), 0, glasses)
    human_npc("officer_school", (96, 160, 110, 255), (110, 70, 44, 255), 1, glasses, tie=None)
    human_npc("senior", (196, 120, 156, 255), (44, 34, 34, 255), 1, tie=(250, 210, 90, 255))
    human_npc("vendor", (232, 180, 60, 255), (34, 34, 34, 255), 0, cap((60, 110, 190, 255)),
              tie=None, pants=((90, 80, 70, 255), (70, 60, 52, 255)))
    human_npc("cafeteria", (240, 130, 110, 255), (120, 120, 120, 255), 0, apron, tie=None)


# ------------------------------------------------------------------ tiles
# Order = enum in scripts/world/tiles.gd. Append only; never reorder.
TILES = [
    "floor", "wall", "desk", "carpet", "plant", "counter", "asphalt", "parking_line", "grass",
    "entrance", "window_wall", "wood_floor", "pc_desk", "vending", "board", "mirror", "ticket_machine",
    "bookshelf", "water_cooler", "sofa", "rug", "printer", "table", "bed_head", "bed_foot",
    "wardrobe", "home_floor", "home_wall", "fridge", "door_mat",
]

FLOOR_C = (236, 226, 204, 255)
WOOD = (214, 168, 116, 255)
HOME = (226, 182, 128, 255)
CARPET = (156, 172, 198, 255)


def tile_floor(t, x, base, line):
    fill(t, x, 0, x + 15, 15, base)
    for i in range(16):
        px(t, x + i, 15, line)
        px(t, x + 15, i, line)
    px(t, x + 4, 5, shade(base, 0.95))
    px(t, x + 11, 10, shade(base, 0.95))


def tile_planks(t, x, base):
    fill(t, x, 0, x + 15, 15, base)
    d = shade(base, 0.82)
    for y in (3, 7, 11, 15):
        fill(t, x, y, x + 15, y, d)
    for y, cx in ((0, 6), (4, 12), (8, 3), (12, 9)):
        fill(t, x + cx, y, x + cx, y + 2, d)
    px(t, x + 2, 1, shade(base, 1.08))
    px(t, x + 9, 9, shade(base, 1.08))


def tile_wall(t, x, face=(112, 120, 150, 255)):
    top = shade(face, 0.6)
    fill(t, x, 0, x + 15, 3, top)
    fill(t, x, 4, x + 15, 13, face)
    fill(t, x, 4, x + 15, 4, shade(face, 1.15))
    fill(t, x, 13, x + 15, 15, shade(face, 0.72))


def tile_desk(t, x, top=(176, 122, 78, 255)):
    fill(t, x, 0, x + 15, 15, FLOOR_C)
    fill(t, x, 1, x + 15, 10, top)
    fill(t, x, 1, x + 15, 1, shade(top, 1.18))
    fill(t, x, 11, x + 15, 13, shade(top, 0.7))
    fill(t, x + 1, 14, x + 2, 15, shade(top, 0.55))
    fill(t, x + 13, 14, x + 14, 15, shade(top, 0.55))


def make_tiles():
    img = Image.new("RGBA", (16 * len(TILES), 16), T)
    for i, name in enumerate(TILES):
        x = i * 16
        if name == "floor":
            tile_floor(img, x, FLOOR_C, (214, 202, 178, 255))
        elif name == "wall":
            tile_wall(img, x)
        elif name == "desk":
            tile_desk(img, x)
        elif name == "carpet":
            fill(img, x, 0, x + 15, 15, CARPET)
            for (a, b) in ((3, 3), (11, 3), (7, 11), (15, 11)):
                px(img, x + a % 16, b, shade(CARPET, 0.88))
        elif name == "plant":
            tile_floor(img, x, FLOOR_C, (214, 202, 178, 255))
            fill(img, x + 4, 10, x + 11, 15, (196, 110, 70, 255))
            fill(img, x + 4, 10, x + 11, 10, (226, 140, 96, 255))
            ImageDraw.Draw(img).ellipse([x + 1, 0, x + 14, 11], fill=(76, 160, 82, 255))
            ImageDraw.Draw(img).ellipse([x + 4, 1, x + 10, 6], fill=(112, 196, 108, 255))
            px(img, x + 9, 7, (52, 120, 60, 255))
        elif name == "counter":
            tile_desk(img, x, (214, 204, 186, 255))
        elif name == "asphalt":
            fill(img, x, 0, x + 15, 15, (88, 88, 98, 255))
            for (a, b) in ((2, 3), (9, 6), (13, 12), (5, 13)):
                px(img, x + a, b, (106, 106, 116, 255))
        elif name == "parking_line":
            fill(img, x, 0, x + 15, 15, (88, 88, 98, 255))
            fill(img, x + 7, 0, x + 8, 15, (244, 244, 244, 255))
        elif name == "grass":
            fill(img, x, 0, x + 15, 15, (116, 180, 92, 255))
            for (a, b) in ((3, 4), (10, 9), (6, 12), (13, 2)):
                px(img, x + a, b, (88, 150, 72, 255))
                px(img, x + a, b - 1, (140, 204, 110, 255))
        elif name == "entrance":
            fill(img, x, 0, x + 15, 15, (196, 64, 64, 255))
            fill(img, x + 1, 1, x + 14, 14, (226, 96, 86, 255))
            fill(img, x + 3, 3, x + 12, 12, (210, 80, 74, 255))
        elif name == "window_wall":
            tile_wall(img, x)
            fill(img, x + 2, 4, x + 13, 11, (240, 240, 244, 255))
            fill(img, x + 3, 5, x + 12, 10, (160, 210, 246, 255))
            fill(img, x + 3, 5, x + 12, 6, (200, 232, 252, 255))
            fill(img, x + 7, 5, x + 8, 10, (240, 240, 244, 255))
        elif name == "wood_floor":
            tile_planks(img, x, WOOD)
        elif name == "pc_desk":
            tile_desk(img, x)
            fill(img, x + 3, 0, x + 12, 7, (50, 52, 64, 255))
            fill(img, x + 4, 1, x + 11, 6, (110, 200, 255, 255))
            fill(img, x + 5, 2, x + 7, 2, (220, 244, 255, 255))
            fill(img, x + 7, 8, x + 8, 8, (50, 52, 64, 255))
            fill(img, x + 4, 9, x + 11, 10, (230, 230, 236, 255))
        elif name == "vending":
            fill(img, x, 0, x + 15, 15, FLOOR_C)
            fill(img, x + 1, 0, x + 14, 15, (64, 128, 210, 255))
            fill(img, x + 3, 2, x + 9, 11, (226, 242, 255, 255))
            for yy in (4, 7, 10):
                fill(img, x + 4, yy, x + 8, yy, (240, 120, 90, 255))
            fill(img, x + 11, 4, x + 12, 8, (250, 220, 80, 255))
            fill(img, x + 3, 13, x + 9, 14, (40, 60, 110, 255))
        elif name == "board":
            tile_wall(img, x)
            fill(img, x + 2, 3, x + 13, 11, (176, 128, 80, 255))
            fill(img, x + 3, 4, x + 7, 7, (252, 250, 230, 255))
            fill(img, x + 9, 5, x + 12, 9, (255, 236, 140, 255))
            px(img, x + 5, 4, (220, 60, 60, 255))
        elif name == "mirror":
            tile_wall(img, x)
            fill(img, x + 4, 2, x + 11, 12, (220, 220, 230, 255))
            fill(img, x + 5, 3, x + 10, 11, (190, 226, 246, 255))
            fill(img, x + 6, 4, x + 7, 6, (236, 248, 255, 255))
        elif name == "ticket_machine":
            fill(img, x, 0, x + 15, 15, FLOOR_C)
            fill(img, x + 2, 0, x + 13, 14, (226, 82, 72, 255))
            fill(img, x + 4, 2, x + 11, 6, (252, 250, 230, 255))
            fill(img, x + 5, 8, x + 10, 9, (60, 40, 40, 255))
            fill(img, x + 2, 15, x + 13, 15, (150, 50, 46, 255))
        elif name == "bookshelf":
            fill(img, x, 0, x + 15, 15, (130, 86, 52, 255))
            for sy in (1, 8):
                fill(img, x + 1, sy, x + 14, sy + 5, (92, 60, 38, 255))
                cols = [(220, 80, 70), (80, 140, 210), (240, 200, 80), (110, 180, 110), (190, 120, 200)]
                bx = x + 1
                for k in range(6):
                    w = 2 if k % 2 else 1
                    c = cols[(k + sy) % len(cols)] + (255,)
                    fill(img, bx, sy + 1 + (k % 2), bx + w, sy + 5, c)
                    bx += w + 1
            fill(img, x, 14, x + 15, 15, (100, 64, 40, 255))
        elif name == "water_cooler":
            tile_floor(img, x, FLOOR_C, (214, 202, 178, 255))
            fill(img, x + 4, 7, x + 11, 15, (236, 236, 242, 255))
            fill(img, x + 5, 0, x + 10, 7, (130, 196, 240, 255))
            fill(img, x + 6, 1, x + 7, 5, (190, 228, 252, 255))
            px(img, x + 6, 10, (230, 80, 70, 255))
            px(img, x + 9, 10, (70, 120, 220, 255))
        elif name == "sofa":
            tile_floor(img, x, FLOOR_C, (214, 202, 178, 255))
            fill(img, x, 2, x + 15, 13, (110, 150, 120, 255))
            fill(img, x, 2, x + 15, 6, (130, 172, 140, 255))
            fill(img, x + 7, 7, x + 8, 12, (90, 126, 100, 255))
            fill(img, x, 14, x + 15, 15, (70, 96, 78, 255))
        elif name == "rug":
            fill(img, x, 0, x + 15, 15, (196, 120, 110, 255))
            fill(img, x + 2, 2, x + 13, 13, (224, 160, 140, 255))
            fill(img, x + 5, 5, x + 10, 10, (240, 214, 170, 255))
        elif name == "printer":
            tile_floor(img, x, FLOOR_C, (214, 202, 178, 255))
            fill(img, x + 1, 4, x + 14, 14, (200, 202, 210, 255))
            fill(img, x + 1, 4, x + 14, 5, (226, 228, 236, 255))
            fill(img, x + 4, 1, x + 11, 4, (252, 252, 252, 255))
            fill(img, x + 3, 9, x + 12, 10, (90, 92, 104, 255))
            px(img, x + 12, 6, (90, 220, 120, 255))
        elif name == "table":
            tile_floor(img, x, FLOOR_C, (214, 202, 178, 255))
            ImageDraw.Draw(img).ellipse([x + 1, 1, x + 14, 12], fill=(246, 240, 228, 255), outline=(190, 176, 156, 255))
            fill(img, x + 7, 12, x + 8, 15, (150, 130, 110, 255))
        elif name == "bed_head":
            fill(img, x, 0, x + 15, 15, HOME)
            fill(img, x, 0, x + 15, 15, (150, 100, 70, 255))
            fill(img, x + 1, 2, x + 14, 15, (250, 250, 252, 255))
            fill(img, x + 3, 3, x + 12, 8, (236, 240, 252, 255))
            fill(img, x + 1, 10, x + 14, 15, (120, 170, 230, 255))
            fill(img, x + 1, 10, x + 14, 10, (160, 200, 246, 255))
        elif name == "bed_foot":
            fill(img, x, 0, x + 15, 15, (150, 100, 70, 255))
            fill(img, x + 1, 0, x + 14, 12, (120, 170, 230, 255))
            for yy in (3, 7):
                fill(img, x + 1, yy, x + 14, yy, (100, 150, 210, 255))
            fill(img, x, 13, x + 15, 15, (120, 78, 54, 255))
        elif name == "wardrobe":
            fill(img, x, 0, x + 15, 15, (170, 116, 72, 255))
            fill(img, x + 1, 1, x + 7, 14, (196, 140, 90, 255))
            fill(img, x + 8, 1, x + 14, 14, (196, 140, 90, 255))
            px(img, x + 6, 8, (250, 220, 120, 255))
            px(img, x + 9, 8, (250, 220, 120, 255))
            fill(img, x, 15, x + 15, 15, (120, 80, 50, 255))
        elif name == "home_floor":
            tile_planks(img, x, HOME)
        elif name == "home_wall":
            face = (238, 214, 178, 255)
            tile_wall(img, x, face)
            for sx in range(1, 16, 4):
                fill(img, x + sx, 5, x + sx, 12, shade(face, 0.93))
            fill(img, x, 12, x + 15, 12, (170, 120, 80, 255))
        elif name == "fridge":
            fill(img, x, 0, x + 15, 15, HOME)
            fill(img, x + 2, 0, x + 13, 15, (240, 244, 250, 255))
            fill(img, x + 2, 6, x + 13, 6, (196, 204, 216, 255))
            fill(img, x + 11, 2, x + 11, 4, (150, 160, 176, 255))
            fill(img, x + 11, 8, x + 11, 12, (150, 160, 176, 255))
            px(img, x + 5, 3, (240, 110, 100, 255))
        elif name == "door_mat":
            tile_planks(img, x, HOME)
            fill(img, x + 1, 3, x + 14, 13, (120, 150, 100, 255))
            fill(img, x + 2, 4, x + 13, 12, (150, 180, 120, 255))
    img.save(OUT / "tiles.png")


# ------------------------------------------------------------------ drive minigame
def make_drive():
    car = Image.new("RGBA", (18, 30), T)
    fill(car, 2, 1, 15, 28, (70, 120, 210, 255))
    fill(car, 2, 1, 15, 2, (110, 160, 240, 255))
    fill(car, 4, 3, 13, 8, (190, 228, 252, 255))
    fill(car, 3, 10, 14, 27, (246, 246, 250, 255))
    fill(car, 3, 10, 14, 10, (214, 214, 224, 255))
    fill(car, 6, 15, 11, 19, (70, 120, 210, 255))  # 조달청 truck mark
    for y in (5, 22):
        fill(car, 0, y, 1, y + 3, (40, 40, 48, 255))
        fill(car, 16, y, 17, y + 3, (40, 40, 48, 255))
    outline(car)
    car.save(OUT / "car_player.png")
    npc = Image.new("RGBA", (18, 30), T)
    fill(npc, 2, 1, 15, 28, (210, 76, 66, 255))
    fill(npc, 4, 19, 13, 25, (190, 228, 252, 255))
    fill(npc, 4, 3, 13, 8, (236, 110, 96, 255))
    for y in (5, 22):
        fill(npc, 0, y, 1, y + 3, (40, 40, 48, 255))
        fill(npc, 16, y, 17, y + 3, (40, 40, 48, 255))
    outline(npc)
    npc.save(OUT / "car_npc.png")
    cone = Image.new("RGBA", (12, 12), T)
    ImageDraw.Draw(cone).polygon([(6, 0), (10, 10), (1, 10)], fill=(250, 140, 40, 255))
    fill(cone, 3, 6, 8, 7, (250, 250, 250, 255))
    fill(cone, 0, 11, 11, 11, (200, 100, 30, 255))
    cone.save(OUT / "cone.png")
    bump = Image.new("RGBA", (40, 6), T)
    fill(bump, 0, 0, 39, 5, (240, 200, 40, 255))
    for i in range(0, 40, 8):
        fill(bump, i + 1, 1, i + 4, 4, (40, 40, 40, 255))
    outline(bump)
    bump.save(OUT / "speed_bump.png")
    star = Image.new("RGBA", (14, 14), T)
    ImageDraw.Draw(star).polygon([(7, 0), (9, 5), (13, 5), (10, 8), (11, 13), (7, 10), (3, 13), (4, 8), (1, 5), (5, 5)],
                                 fill=(255, 214, 60, 255))
    px(star, 6, 4, (255, 250, 200, 255))
    outline(star)
    star.save(OUT / "pickup_star.png")
    box = Image.new("RGBA", (14, 12), T)
    fill(box, 1, 3, 12, 10, (220, 70, 60, 255))
    fill(box, 1, 3, 12, 4, (246, 110, 96, 255))
    fill(box, 5, 1, 8, 2, (90, 90, 100, 255))
    fill(box, 6, 6, 7, 8, (250, 250, 250, 255))
    fill(box, 5, 7, 8, 7, (250, 250, 250, 255))
    outline(box)
    box.save(OUT / "pickup_repair.png")


def make_icons():
    def icon(name, fn):
        img = Image.new("RGBA", (16, 16), T)
        fn(img, ImageDraw.Draw(img))
        outline(img)
        img.save(OUT / name)
    icon("item_gukbap.png", lambda im, d: (d.ellipse([1, 5, 14, 14], fill=(244, 244, 244, 255)),
                                           d.ellipse([3, 6, 12, 10], fill=(210, 90, 56, 255)),
                                           fill(im, 5, 1, 5, 3, (230, 230, 230, 255)), fill(im, 9, 0, 9, 3, (230, 230, 230, 255))))
    icon("item_coffee.png", lambda im, d: (fill(im, 4, 4, 11, 14, (252, 252, 252, 255)),
                                           fill(im, 4, 7, 11, 10, (130, 86, 54, 255)),
                                           fill(im, 12, 7, 13, 10, (252, 252, 252, 255))))
    icon("item_meal.png", lambda im, d: (fill(im, 1, 4, 14, 13, (186, 196, 206, 255)),
                                         fill(im, 3, 6, 6, 9, (252, 250, 240, 255)),
                                         fill(im, 8, 6, 12, 9, (234, 124, 64, 255)),
                                         fill(im, 3, 10, 12, 11, (112, 176, 92, 255))))
    icon("item_energybar.png", lambda im, d: (fill(im, 2, 6, 13, 10, (244, 204, 64, 255)),
                                              fill(im, 5, 7, 10, 9, (206, 84, 52, 255))))


def circle_button(name, size, label_col):
    img = Image.new("RGBA", (size, size), T)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, size - 1, size - 1], fill=(255, 255, 255, 70), outline=(255, 255, 255, 170), width=2)
    if label_col:
        d.ellipse([size // 3, size // 3, size * 2 // 3, size * 2 // 3], fill=label_col)
    img.save(OUT / name)


def make_touch_ui():
    circle_button("touch_a.png", 44, (120, 200, 255, 200))
    circle_button("touch_b.png", 36, (255, 140, 120, 200))
    circle_button("touch_item.png", 32, (250, 220, 90, 200))
    circle_button("joy_base.png", 72, None)
    circle_button("joy_knob.png", 30, (255, 255, 255, 120))


def preview(path):
    """Writes a 4x preview sheet of every character (tinted like the game) for review."""
    names = ["npc_narumi.png", "npc_dari.png", "npc_team_leader.png", "npc_officer_school.png",
             "npc_senior.png", "npc_vendor.png", "npc_cafeteria.png"]
    sheet = Image.new("RGBA", (FW * 12, FH * 4), (70, 80, 110, 255))
    base = Image.open(OUT / "player_base.png")
    outfit = Image.open(OUT / "player_outfit.png")
    for hs in (0, 1):
        hair = Image.open(OUT / f"player_hair_{hs}.png")
        for r in range(3):
            for c in range(4):
                box = (c * FW, r * FH, (c + 1) * FW, (r + 1) * FH)
                fr = Image.new("RGBA", (FW, FH), T)
                fr.alpha_composite(base.crop(box))
                o = outfit.crop(box)
                fr.alpha_composite(_multiply(o, (60, 77, 140)))
                fr.alpha_composite(_multiply(hair.crop(box), (138, 90, 58)))
                sheet.paste(fr, ((c + hs * 4) * FW, r * FH), fr)
    for i, n in enumerate(names):
        im = Image.open(OUT / n)
        sheet.paste(im.crop((0, 0, FW, FH)), ((8 + i % 4) * FW, (i // 4) * FH), im.crop((0, 0, FW, FH)))
    tiles = Image.open(OUT / "tiles.png")
    sheet.paste(tiles.crop((0, 0, min(tiles.width, FW * 12), 16)), (0, FH * 3), tiles.crop((0, 0, min(tiles.width, FW * 12), 16)))
    rest = tiles.crop((FW * 12, 0, tiles.width, 16))
    sheet.paste(rest, (0, FH * 3 + 16), rest)
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(path)


def _multiply(im, rgb):
    out = im.copy()
    pxs = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pxs[x, y]
            if a and (r, g, b) != OUTLINE[:3]:
                pxs[x, y] = (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, a)
    return out


if __name__ == "__main__":
    import sys
    make_player()
    make_npcs()
    make_tiles()
    make_drive()
    make_icons()
    make_touch_ui()
    if len(sys.argv) > 1:
        preview(sys.argv[1])
    print("placeholders written to", OUT)
