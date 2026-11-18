"""Generate the prototype pixel art (2-head-tall SD characters, cozy tiles, icons).

Run from the project root:  python tools/gen_placeholders.py   (needs Pillow)
Everything lands in assets/sprites/placeholder/. Replace these files with real art
later, keeping the same file names and frame layout, and the game picks them up.

Frame layout of character sheets (24x32 px per frame, feet at y=29):
  rows: 0 = down, 1 = up, 2 = side (facing right; left is drawn flipped)
  cols: 0..3 walk cycle (col 0 doubles as the idle frame)
Player sheets are split into layers (bottom to top) that the game tints at runtime:
  player_skin.png (head, hands: white/gray -> skin tone)
  player_outfit_<n>_base.png (shirt, tie, pants, shoes, body outline: as is)
  player_outfit_<n>.png (jacket / vest / jumper / skirt: gray -> outfit color)
  player_face_<0 male|1 female>.png (eyes, blush, mouth: as is)
  player_hair_<n>.png (gray -> hair color)
NPC sheets: people use the same 3x4 layout as the player (they walk around);
  the mascots (나르미, 달이) are one row (down) with 2 idle frames.
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
# Skin is drawn white/gray and tinted at runtime with the chosen skin tone.
SKIN_T = (255, 255, 255, 255)
SKIN_TD = (236, 206, 194, 255)  # = SKIN_D / SKIN per channel, so tinting with SKIN gives SKIN_D
HEAD_DOWN = mirror([
    "....ssss", "..ssssss", ".sssssss", ".sssssss", "ssssssss", "ssssssss", "ssssssss",
    "ssssssss", "ssssssss", "ssssssss", ".sssssss", "..ssssss", "....oooo",
])
HEAD_UP = HEAD_DOWN
HEAD_SIDE = [
    "....ssssssss....", "..ssssssssssss..", ".ssssssssssssss.", ".ssssssssssssss.",
    "ssssssssssssssss", "ssssssssssssssss", "ssssssssssssssss", "ssssssssssssssss",
    "ssssssssssssssss", "ssssssssssssssss", ".ssssssssssssss.", "..ssssssssssss..",
    "....oooooooo....",
]
SKIN_PAL = {"s": SKIN_T, "o": SKIN_TD}

# Faces sit on top of the tinted skin (rows = head rows). Eyes: white
# sclera around a dark pupil over a lighter iris, lash on the outer corner only.
LASH = (34, 26, 40, 255)
SCLERA = (255, 255, 255, 255)
PUPIL = (30, 22, 34, 255)
IRIS = (104, 70, 52, 255)
BLUSH_A = (255, 120, 120, 110)  # translucent so it works on every skin tone
MOUTH_F = (222, 96, 112, 255)
FACE_PAL = {"k": LASH, "w": SCLERA, "p": PUPIL, "i": IRIS, "b": BLUSH_A, "m": MOUTH, "r": MOUTH_F}
_EMPTY = ["." * 16] * 7
FACE_DOWN = {
    0: _EMPTY + ["...kpw....wpk...", "...wpw....wpw...", "...wiw....wiw...", ".bb....mm....bb."],
    1: _EMPTY + ["..kkpw....wpkk..", "...wpw....wpw...", "...wiw....wiw...", ".bb....rr....bb."],
}
FACE_SIDE = {
    0: _EMPTY + ["...........kp...", "...........wp...", "...........wi...", ".........bb..m.."],
    1: _EMPTY + ["..........kkp...", "...........wp...", "...........wi...", ".........bb..r.."],
}
FACES = {0: FACE_DOWN, 1: None, 2: FACE_SIDE}

# Hair grids start one row above the head. Styles (index = game's hair_style):
# 0 짧은 머리, 1 가르마, 2 단발, 3 긴 머리, 4 포니테일
_TOP = ["....HHHH", "..HHHHHH", ".HHHHHHH", "HHHIHHHH", "HHIIHHIH", "HIIIIHII", "HIIJIIIJ"]
_BANG = "HIJ.JIJ."
_PART = [
    "....HHHHHHHH....", "..HHHHHHHHHHHH..", ".HHHHHHHHHHHHHH.", "HHHHHHHHHHIHHHHH",
    "HHHHHHHIIHHI.HHH", "HIIIIIIIIIIJ.IIH", "HIIIIIIIIJJ..IIJ", "IIIIIJJJ.J...IJJ",
    "IJJ...........IJ", "J..............J",
]
HAIR_DOWN = {
    0: mirror(_TOP + [_BANG, "IJ......", "J......."]),
    1: _PART,
    2: mirror(_TOP + ["HIJIJIJI", "IIJ.....", "IIJ.....", "IIJ.....", "IJJ.....", ".JJ....."]),
    3: mirror(_TOP + [_BANG, "IIJ.....", "IIJ.....", "IJJ.....", "IJ......", "IJ......",
                      "IJ......", "JJ......", ".J......"]),
    4: mirror(_TOP + [_BANG, "IJ......", "IJ......", "J......."]),
}
_BACK = ["....HHHH", "..HHHHHH", ".HHHHHHH", "HHHHHHHH", "HHHIHHHH", "HIIIHIII", "HIIIIIII",
         "IIJIIIJI", "IJIJIJIJ", "IJJJJJJJ"]
HAIR_UP = {
    0: mirror(_BACK + [".JJJJJJJ", "..JJJJJJ", "....JJJJ"]),
    1: mirror(_BACK + [".JJJJJJJ", "..JJJJJJ", "....JJJJ"]),
    2: mirror(_BACK + ["IJJJJJJJ", "IJJIIJJJ", "IIJJJJJJ", ".IJJJJJJ", ".JJJJJJJ"]),
    3: mirror(_BACK + ["IJJJJJJJ", "IJJIIJJJ", "IIJJJJJJ", ".IJJJJJJ", ".IIJJJJJ", "..IJJJJJ",
                       "...JJJJJ"]),
    4: mirror(_BACK + ["..JJJJJJ", "......JJ", "......IH", "......IH", "......II", "......IJ",
                       "......IJ", ".......J"]),
}
_SIDE = ["....HHHHHHHH", "..HHHHHHHHHHHH", ".HHHHHHHHHHHHHH", "HHHHHHHHHIHHHHHH",
         "HHHHHHIHHIIHHIH", "HHIIIIIIIIIJIIJ", "IIIIIIIJIJ.J.J", "IIIIIJJ", "IIIIJ", "IIJJ"]
HAIR_SIDE = {
    0: _SIDE + ["JJJ", ".J"],
    1: _SIDE[:7] + ["IIIIIJJ....IJJ", "IIIIJ", "IIJJ", "JJJ", ".J"],
    2: _SIDE + ["IIIJ", "IIIJ", "IIJJ", "IJJ", ".J"],
    3: _SIDE + ["IIIJ", "IIIJ", "IIJJ", "IIJ", "IIJ", "IJJ", "JJ", ".J"],
    4: _SIDE[:7] + ["JIIIIJJ", "JIIIJ", "IJJJ", "HIJ", "HIJ", "IIJ", "IJ", "IJ", ".J"],
}
HAIR_PAL_TINT = {"H": G1, "I": G2, "J": G3}


def bob(col):
    return 1 if col in (1, 3) else 0


# ------------------------------------------------------------------ bodies
# An outfit = untinted parts (shirt, tie, pants, shoes) + one tinted top (and skirt).
RIBBON = (220, 80, 110, 255)
TIGHTS = ((52, 50, 70, 255), (40, 38, 56, 255))


def outfit(**kw):
    spec = {"top": "jacket", "tie": TIE, "shirt": SHIRT, "pants": (PANTS, PANTS_D), "skirt": False}
    spec.update(kw)
    return spec


# index = game's outfit_style: 0 정장, 1 치마 정장, 2 니트 조끼, 3 활동복 점퍼
OUTFITS = [
    outfit(),
    outfit(tie="ribbon", pants=TIGHTS, skirt=True),
    outfit(top="vest"),
    outfit(top="jumper", tie=None, pants=((128, 120, 100, 255), (100, 94, 78, 255))),
]


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


def arm_x(col):
    return {0: 10, 1: 12, 2: 10, 3: 8}[col]


def draw_base_body(base, skin, row, col, spec):
    """Shirt, tie/ribbon, vest sleeves (untinted) and hands (skin layer)."""
    t = 15 + bob(col)
    shirt, tie = spec["shirt"], spec["tie"]
    if row == 0:
        fill(base, 10, t, 13, t + 5, shirt)
        if tie == "ribbon":
            for x in (10, 13):
                px(base, x, t, RIBBON)
                px(base, x, t + 1, RIBBON)
            fill(base, 11, t, 12, t, shade(RIBBON, 0.7))
        elif tie:
            fill(base, 11, t, 12, t + 3, tie)
            fill(base, 11, t + 4, 12, t + 4, shade(tie, 0.7))
        fill(skin, 5, t + 5, 6, t + 6, SKIN_TD)
        fill(skin, 17, t + 5, 18, t + 6, SKIN_TD)
    elif row == 1:
        fill(skin, 5, t + 5, 6, t + 6, SKIN_TD)
        fill(skin, 17, t + 5, 18, t + 6, SKIN_TD)
    else:
        fill(base, 14, t, 15, t + 1, shirt)
        hx = arm_x(col)
        fill(skin, hx, t + 6, hx + 2, t + 7, SKIN_TD)
    if spec["top"] == "vest":  # white shirt sleeves
        if row in (0, 1):
            fill(base, 5, t, 6, t + 4, shirt)
            fill(base, 17, t, 18, t + 4, shirt)
            fill(base, 6, t + 1, 6, t + 4, SHIRT_D)
            fill(base, 17, t + 1, 17, t + 4, SHIRT_D)
        else:
            ax = arm_x(col)
            fill(base, ax, t + 1, ax + 2, t + 5, shirt)
            fill(base, ax, t + 1, ax, t + 5, SHIRT_D)


def draw_top(img, row, col, spec, c1=G1, c2=G2, c3=G3):
    """The tinted part of the outfit: jacket / vest / jumper, plus the skirt."""
    t = 15 + bob(col)
    kind = spec["top"]
    if row in (0, 1):
        fill(img, 7, t, 16, t + 7, c1)
        fill(img, 15, t + 1, 16, t + 7, c2)
        fill(img, 7, t + 7, 16, t + 7, c3)
        if kind != "vest":
            fill(img, 5, t, 6, t + 4, c2)
            fill(img, 17, t, 18, t + 4, c2)
            fill(img, 6, t + 1, 6, t + 4, c3)
            fill(img, 17, t + 1, 17, t + 4, c3)
        if row == 0 and kind == "jacket":  # V opening shows the shirt and tie
            for y, (a, b) in enumerate(((10, 13), (10, 13), (10, 13), (11, 12), (11, 12))):
                fill(img, a, t + y, b, t + y, T)
            px(img, 11, t + 6, c3)
        elif row == 0 and kind == "vest":  # deeper V, shirt and tie show
            for y, (a, b) in enumerate(((9, 14), (10, 13), (10, 13), (10, 13), (11, 12), (11, 12))):
                fill(img, a, t + y, b, t + y, T)
        elif row == 0:  # jumper: collar, tee at the neck, zipper
            fill(img, 11, t, 12, t, T)
            fill(img, 9, t, 10, t, c2)
            fill(img, 13, t, 14, t, c2)
            fill(img, 11, t + 1, 11, t + 6, c3)
        elif kind == "jumper":
            fill(img, 8, t, 15, t, c2)
        else:
            fill(img, 11, t + 2, 12, t + 6, c2)
    else:
        fill(img, 8, t, 15, t + 7, c1)
        fill(img, 8, t + 1, 9, t + 7, c2)
        fill(img, 8, t + 7, 15, t + 7, c3)
        fill(img, 14, t, 15, t + 1, T)  # shirt collar at the front
        ax = arm_x(col)
        if kind == "vest":
            fill(img, ax, t + 1, ax + 2, t + 5, T)  # the shirt sleeve shows through
        else:
            fill(img, ax, t + 1, ax + 2, t + 5, c2)
            fill(img, ax, t + 1, ax, t + 5, c3)
    if spec["skirt"]:
        if row in (0, 1):
            fill(img, 8, 23, 15, 25, c1)
            fill(img, 14, 23, 15, 25, c2)
            fill(img, 8, 25, 15, 25, c3)
        else:
            fill(img, 8, 23, 15, 25, c1)
            fill(img, 8, 23, 9, 25, c2)
            fill(img, 8, 25, 15, 25, c3)


def outline_union(target, masks, color=OUTLINE):
    """Draws a 1 px outline into target around the union of the masks' opaque pixels."""
    w, h = target.size
    solid = [[any(m.getpixel((x, y))[3] > 0 for m in masks) for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and solid[ny][nx]:
                    target.putpixel((x, y), color)
                    break


HEADS = {0: HEAD_DOWN, 1: HEAD_UP, 2: HEAD_SIDE}
HAIRS = {0: HAIR_DOWN, 1: HAIR_UP, 2: HAIR_SIDE}
LAYERS = ("skin", "cbase", "ctint", "face", "hair")  # bottom to top, same as CharacterVisual


def frame_layers(row, col, spec, style, gender):
    """One frame, split into the game's layers. skin/ctint/hair are tint-ready grays."""
    L = {k: Image.new("RGBA", (FW, FH), T) for k in LAYERS}
    b = bob(col)
    draw_legs(L["cbase"], row, col, *spec["pants"])
    draw_base_body(L["cbase"], L["skin"], row, col, spec)
    stamp(L["skin"], HEADS[row], X0, 2 + b, SKIN_PAL)
    if FACES[row]:
        stamp(L["face"], FACES[row][gender], X0, 2 + b, FACE_PAL)
    draw_top(L["ctint"], row, col, spec)
    if style is not None:
        stamp(L["hair"], [r.ljust(16, ".") for r in HAIRS[row][style]], X0, 1 + b, HAIR_PAL_TINT)
    # body outline goes in the untinted layer; hair outlines itself on top
    outline_union(L["cbase"], [L["skin"], L["cbase"], L["ctint"]])
    outline(L["hair"], [L["skin"], L["cbase"], L["ctint"], L["hair"]])
    return L


def player_sheet_names():
    names = ["player_skin.png", "player_face_0.png", "player_face_1.png"]
    names += [f"player_outfit_{i}_base.png" for i in range(len(OUTFITS))]
    names += [f"player_outfit_{i}.png" for i in range(len(OUTFITS))]
    names += [f"player_hair_{s}.png" for s in range(len(HAIR_DOWN))]
    return names


def make_player():
    sheets = {n: Image.new("RGBA", (FW * 4, FH * 3), T) for n in player_sheet_names()}
    for r in range(3):
        for c in range(4):
            pos = (c * FW, r * FH)
            for g in (0, 1):
                L = frame_layers(r, c, OUTFITS[0], None, g)
                sheets[f"player_face_{g}.png"].paste(L["face"], pos)
            sheets["player_skin.png"].paste(L["skin"], pos)
            for i, spec in enumerate(OUTFITS):
                L = frame_layers(r, c, spec, None, 0)
                sheets[f"player_outfit_{i}_base.png"].paste(L["cbase"], pos)
                sheets[f"player_outfit_{i}.png"].paste(L["ctint"], pos)
            for s in range(len(HAIR_DOWN)):
                L = frame_layers(r, c, OUTFITS[0], s, 0)
                sheets[f"player_hair_{s}.png"].paste(L["hair"], pos)
    for name, im in sheets.items():
        im.save(OUT / name)
    for old in ("player_base.png", "player_outfit.png"):  # pre-11/17 layer layout
        for p in (OUT / old, OUT / (old + ".import")):
            if p.exists():
                p.unlink()


def merged(*layers):
    out = Image.new("RGBA", (FW, FH), T)
    for im in layers:
        out.alpha_composite(im)
    return out


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def _multiply(im, rgb):
    """Like Godot's self_modulate, but leaves the outline color alone."""
    out = im.copy()
    pxs = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pxs[x, y]
            if a and (r, g, b) != OUTLINE[:3]:
                pxs[x, y] = (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, a)
    return out


def human_npc(name, spec, jacket, hair, style=0, gender=0, extras=None, skin=SKIN):
    """Full walking sheet (rows down / up / side, 4 columns) like the player's."""
    img = Image.new("RGBA", (FW * 4, FH * 3), T)
    for r in range(3):
        for c in range(4):
            L = frame_layers(r, c, spec, style, gender)
            mid = Image.new("RGBA", (FW, FH), T)  # over the clothes (apron)
            top = Image.new("RGBA", (FW, FH), T)  # over the hair (glasses, cap)
            if extras:
                extras(mid, top, r, c, bob(c))
            fr = merged(_multiply(L["skin"], skin), L["cbase"], _multiply(L["ctint"], jacket), mid,
                        L["face"], _multiply(L["hair"], hair), top)
            img.paste(fr, (c * FW, r * FH))
    img.save(OUT / f"npc_{name}.png")


def combine(*fns):
    def fn(mid, top, row, col, b):
        for f in fns:
            f(mid, top, row, col, b)
    return fn


def glasses(mid, top, row, col, b):
    y0 = 2 + b
    if row == 1:  # back of the head
        return
    if row == 2:  # side: a small lens in front of the eye and the temple to the ear
        for x in range(X0 + 11, X0 + 15):
            px(top, x, y0 + 5, OUTLINE)
            px(top, x, y0 + 8, OUTLINE)
        for y in range(5, 9):
            px(top, X0 + 14, y0 + y, OUTLINE)
        for x in range(X0 + 8, X0 + 11):
            px(top, x, y0 + 6, OUTLINE)
        return
    for x0 in (X0 + 2, X0 + 9):
        for x in range(x0, x0 + 5):
            px(top, x, y0 + 6, OUTLINE)
            px(top, x, y0 + 10, OUTLINE)
        for y in range(6, 11):
            px(top, x0, y0 + y, OUTLINE)
            px(top, x0 + 4, y0 + y, OUTLINE)
    px(top, X0 + 7, y0 + 8, OUTLINE)
    px(top, X0 + 8, y0 + 8, OUTLINE)


def cap(color):
    def fn(mid, top, row, col, b):
        fill(top, X0, 1 + b, X0 + 15, 4 + b, color)
        fill(top, X0 + 2, 0 + b, X0 + 13, 0 + b, color)
        fill(top, X0 + 3, 5 + b, X0 + 12, 5 + b, shade(color, 0.7))
    return fn


def apron(mid, top, row, col, b):
    t = 15 + b
    if row == 0:
        fill(mid, 9, t + 1, 14, t + 7, (252, 252, 252, 255))
        fill(mid, 9, t + 7, 14, t + 7, (220, 220, 225, 255))
    elif row == 2:
        fill(mid, 13, t + 1, 15, t + 7, (252, 252, 252, 255))
    fill(top, X0 + 1, 1 + b, X0 + 14, 3 + b, (255, 255, 255, 255))  # kerchief
    fill(top, X0 + 1, 3 + b, X0 + 14, 3 + b, (225, 225, 230, 255))


def police_vest(mid, top, row, col, b):
    """Neon-yellow traffic vest over the uniform jumper."""
    t = 15 + b
    x0, x1 = (8, 15) if row == 2 else (7, 16)
    fill(mid, x0, t + 2, x1, t + 6, (214, 240, 70, 255))
    fill(mid, x0, t + 4, x1, t + 4, (230, 234, 240, 255))


def stethoscope(mid, top, row, col, b):
    if row != 0:
        return
    t = 15 + b
    for (x, y) in ((9, 0), (9, 1), (9, 2), (10, 3), (14, 0), (14, 1), (14, 2), (13, 3), (11, 4), (12, 4), (12, 5)):
        px(mid, x, t + y, (60, 64, 80, 255))
    px(mid, 12, t + 6, (190, 196, 210, 255))


def firefighter_gear(mid, top, row, col, b):
    """Reflective stripes on the turnout coat and a red helmet with a visor."""
    t = 15 + b
    x0, x1 = (8, 15) if row == 2 else (7, 16)
    fill(mid, x0, t + 5, x1, t + 5, (232, 236, 96, 255))
    fill(mid, x0, t + 6, x1, t + 6, (190, 196, 200, 255))
    red, dark = (214, 56, 44, 255), (150, 36, 30, 255)
    fill(top, X0, 1 + b, X0 + 15, 4 + b, red)
    fill(top, X0 + 2, 0 + b, X0 + 13, 0 + b, red)
    if row == 0:
        fill(top, X0 + 6, 0 + b, X0 + 9, 4 + b, (240, 220, 90, 255))  # front badge
    fill(top, X0 - 1, 5 + b, X0 + 16, 5 + b, dark)  # brim


# ------------------------------------------------------------------ mascots
# 나르미 (white stork: big egg-shaped head with a crest swept back to the right, light
# blue goggles, orange beak, red neckerchief, wings with black tips, orange feet) and
# 달이 (orange squirrel: round ears, three stripes on the forehead, white lower face,
# white belly, brown backpack straps, tail behind on the right), drawn after the
# official mascot image (tools/ref/mascots.png). One grid row per pixel row; frame 2
# drops one head row (the idle bob).
MASCOT_PAL = {
    "o": OUTLINE[:3], "W": (252, 252, 255), "w": (230, 233, 242), "s": (200, 206, 222),
    "b": (104, 156, 188), "B": (176, 218, 236), "h": (228, 246, 252), "E": (28, 28, 36), "H": (255, 255, 255),
    "O": (242, 152, 70), "q": (206, 112, 52), "R": (222, 44, 52), "r": (160, 30, 40), "K": (52, 52, 62),
    "F": (240, 156, 80), "N": (242, 160, 78), "n": (214, 122, 58), "L": (250, 192, 118), "i": (252, 238, 228),
    "P": (232, 112, 56), "U": (132, 82, 50), "u": (96, 58, 38),
}
NARUMI = [
    "................ooo.....",
    "..........ooooooWWWoo...",
    "........ooWWWWWWWWWWWo..",
    "......ooWWWWWWWWWWWWssoo",
    ".....oWWWWWWWWWWWWWWWWWo",
    "....oWWWWWWWWWWWWWWsssoo",
    "...oWWWWWWWWWWWWWWWWWWo.",
    "...oWWWWWWWWWWWWWWWWsso.",
    "..oWWWWWWWWWWWWWWWWWWWo.",
    "..oWbbbbbbbbbbbbbbbbWo..",
    "..oWbhhhhhBBBBBBBBBbWo..",
    "..oWbBBEHBBBBBBEHBBbWo..",
    "..oWbBBEEBBBBBBEEBBbWo..",
    "..oWbBBEEBbbbbBEEBBbWo..",
    "..oWbBBBBBbOObBBBBBbWo..",
    "..owWbbbbbWqqWbbbbbWso..",
    "...owWWWWWWWWWWWWWWso...",
    "....owwWWWWWWWWWWsso....",
    ".....ooossssssssooo.....",
    "......oRRRRRRRRRRRRo....",
    "......orrrrrrrrrrrRRo...",
    ".....ooWWWWWWWWWWWrRo...",
    "...ooWWWWWWWWWWWWWWoo...",
    "..oWWWWsWWWWWWWWsWWWWo..",
    ".oKWWWWowWWWWWWsoWWWWKo.",
    ".oKKKWooWWWWWWWsooWKKKo.",
    "..oKKoo.oWWWWWWo.ooKKo..",
    "...oo...oFFooFFoKKooo...",
    "........oFFooFFo........",
    "......oFFFFooFFFFo......",
    ".......oooo..oooo.......",
]
DARI = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "....ooo..........ooo....",
    "...oNNNo........oNNNo...",
    "..oNiiiNo......oNiiiNo..",
    "..oNiiiNooooooooNiiiNo..",
    "..oNNiNNNnNNnNnNNNiNNo..",
    "..oNNNNNNnNNnNnNNNNNNo..",
    "..oNNNNNNnNNnNnNNNNNNo..",
    "..oLNNNNNNNNNNNNNNNNNo..",
    "..oLNNNNNNNNNNNNNNNNno..",
    "..oNNNNNEHNNNNEHNNNNno..",
    "..oNNNNNEENNNNEENNNNno..",
    "..oWWWWWEEWPPWEEWWWWwo..",
    "..owWWWWWWWEEWWWWWWWwo..",
    "...owWWWWWEWWEWWWWWwo...",
    "....owwwwwwwwwwwwwwo....",
    ".....oooooooooooooo.ooo.",
    ".....oNUNNNNNNNNUNooWWo.",
    ".....oNUNNWWWWNNUNoNWWo.",
    ".....oNuNWWWWWWNuNoNNWo.",
    ".....oNNNWWWWWWNNNoNNNo.",
    ".....onNNWWWWWWNNnonNNo.",
    ".....onNNNWWWWNNNnoNNo..",
    "......oNNNooooNNNooo....",
    "......onnno..onnno......",
    ".......ooo....ooo.......",
]


def grid_layer(rows, pal):
    lay = Image.new("RGBA", (FW, FH), T)
    for y, row in enumerate(rows):
        assert len(row) == FW, (y, row)
        for x, ch in enumerate(row):
            if ch != ".":
                lay.putpixel((x, y), pal[ch] + (255,))
    return lay


def mascot(name, rows, bob_row):
    img = Image.new("RGBA", (FW * 2, FH), T)
    for c, frame in enumerate((rows, ["." * FW] + rows[:bob_row] + rows[bob_row + 1:])):
        lay = grid_layer(frame, MASCOT_PAL)
        img.paste(lay, (c * FW, 0), lay)
    img.save(OUT / f"npc_{name}.png")


def make_npcs():
    mascot("narumi", NARUMI, 7)
    mascot("dari", DARI, 13)
    human_npc("team_leader", outfit(), (52, 62, 112), (70, 70, 76), 0, 0, glasses)
    human_npc("officer_school", outfit(tie=None), (96, 160, 110), (130, 84, 52), 3, 1, glasses)
    human_npc("senior", outfit(tie=(250, 210, 90, 255)), (196, 120, 156), (60, 46, 46), 2, 1)
    human_npc("vendor", outfit(top="jumper", tie=None, pants=((90, 80, 70, 255), (70, 60, 52, 255))),
              (232, 180, 60), (40, 40, 40), 0, 0, cap((60, 110, 190, 255)), skin=(236, 196, 156))
    human_npc("cafeteria", outfit(tie=None), (240, 130, 110), (140, 140, 140), 0, 1, apron)
    # 수요기관 사람들 (11/17: 장소마다 다른 사람이 나오도록)
    human_npc("teacher", outfit(top="vest", tie=None), (210, 130, 96), (90, 60, 44), 3, 1)
    human_npc("student", outfit(top="jumper", tie=None, pants=((70, 100, 170, 255), (54, 78, 140, 255))),
              (250, 200, 60), (50, 40, 36), 4, 1, cap((240, 90, 80, 255)))
    human_npc("officer_fire", outfit(tie=(60, 60, 70, 255)), (44, 58, 104), (40, 36, 36), 0, 0,
              cap((36, 46, 86, 255)))
    human_npc("firefighter", outfit(top="jumper", tie=None, pants=((150, 126, 70, 255), (120, 100, 56, 255))),
              (196, 166, 92), (60, 44, 36), 0, 0, firefighter_gear)
    human_npc("officer_clinic", outfit(tie=None), (246, 246, 250), (70, 50, 40), 2, 1, glasses)
    human_npc("nurse", outfit(top="jumper", tie=None, pants=((120, 180, 210, 255), (96, 150, 180, 255))),
              (140, 196, 226), (40, 32, 30), 4, 1)
    human_npc("officer_center", outfit(top="vest"), (110, 132, 104), (50, 40, 36), 1, 0)
    human_npc("citizen", outfit(top="jumper", tie=None, pants=((110, 100, 90, 255), (86, 78, 70, 255))),
              (156, 112, 80), (214, 214, 220), 0, 0, glasses, skin=(240, 204, 170))
    human_npc("inspector", outfit(tie=(70, 120, 200, 255)), (250, 250, 252), (60, 50, 46), 1, 0, glasses)
    # 11/18 요양원·경찰서·병원 사람들, 주차장의 교통 전문 변호사
    human_npc("officer_nursing", outfit(top="vest", tie=None), (196, 150, 110), (90, 64, 50), 2, 1, glasses)
    human_npc("caregiver", outfit(top="jumper", tie=None, pants=((236, 236, 240, 255), (206, 206, 214, 255))),
              (246, 160, 180), (60, 44, 40), 4, 1)
    human_npc("grandma", outfit(top="jumper", tie=None, pants=((120, 100, 130, 255), (96, 80, 104, 255))),
              (170, 120, 190), (226, 226, 230), 2, 1, glasses, skin=(240, 206, 176))
    human_npc("officer_police", outfit(tie=(40, 48, 80, 255)), (52, 70, 120), (40, 36, 36), 1, 0,
              cap((36, 50, 96, 255)))
    human_npc("police", outfit(top="jumper", tie=None, pants=((44, 56, 96, 255), (34, 44, 76, 255))),
              (70, 96, 160), (36, 32, 32), 0, 0, combine(police_vest, cap((36, 50, 96, 255))))
    human_npc("officer_hospital", outfit(tie=(60, 140, 140, 255)), (70, 150, 150), (60, 46, 40), 1, 0, glasses)
    human_npc("doctor", outfit(tie=(70, 110, 190, 255)), (250, 250, 252), (50, 40, 38), 3, 1, stethoscope)
    human_npc("wonmuncheol", outfit(tie=(120, 40, 50, 255)), (66, 68, 80), (86, 86, 92), 0, 0, glasses)


# ------------------------------------------------------------------ tiles
# Order = enum in scripts/world/tiles.gd. Append only; never reorder.
TILES = [
    "floor", "wall", "desk", "carpet", "plant", "counter", "asphalt", "parking_line", "grass",
    "entrance", "window_wall", "wood_floor", "pc_desk", "vending", "board", "mirror", "ticket_machine",
    "bookshelf", "water_cooler", "sofa", "rug", "printer", "table", "bed_head", "bed_foot",
    "wardrobe", "home_floor", "home_wall", "fridge", "door_mat",
    # 11/17 수요기관 건물 외관·앞마당·실내
    "grass_flower", "path", "hedge", "facade_school", "facade_fire", "garage_door", "facade_clinic",
    "facade_center", "glass_door", "tile_white", "hospital_bed", "locker", "med_cabinet", "garage_floor",
    "kiosk", "flower_bed", "chalkboard",
    # 11/17 품질검사실
    "conveyor", "qc_station",
    # 11/18 수요기관 추가: 요양원·경찰서·병원 외관
    "facade_nursing", "facade_police", "facade_hospital",
]

# Outdoor palette: bright and saturated, dark outlines (the cozy look of the reference video).
GRASS_B = (128, 200, 82, 255)
GRASS_D = (96, 166, 64, 255)
GRASS_L = (168, 226, 110, 255)
WHITE_TILE = (242, 245, 248, 255)


def tile_grass_flower(t, x):
    fill(t, x, 0, x + 15, 15, GRASS_B)
    for (a, b) in ((2, 3), (12, 2), (7, 9), (14, 12), (3, 13)):
        px(t, x + a, b, GRASS_D)
        px(t, x + a, b - 1, GRASS_L)
    for (a, b, c) in ((4, 6, (255, 150, 176, 255)), (11, 11, (255, 255, 255, 255)), (9, 2, (255, 222, 90, 255))):
        px(t, x + a, b, c)
        px(t, x + a - 1, b, shade(c, 0.85))
        px(t, x + a + 1, b, shade(c, 0.85))
        px(t, x + a, b - 1, shade(c, 0.85))
        px(t, x + a, b + 1, GRASS_D)


def tile_facade(t, x, face, line, window=True, band=None):
    """Front wall of a building seen from the yard: bricks, a window, a dark base."""
    fill(t, x, 0, x + 15, 15, face)
    for y in (3, 7, 11):
        fill(t, x, y, x + 15, y, line)
    for y, offs in ((0, (5, 13)), (4, (1, 9)), (8, (5, 13)), (12, (1, 9))):
        for o in offs:
            fill(t, x + o, y, x + o, y + 2, line)
    if band:
        fill(t, x, 0, x + 15, 1, band)
    if window:
        fill(t, x + 3, 3, x + 12, 10, OUTLINE)
        fill(t, x + 4, 4, x + 11, 9, (150, 206, 246, 255))
        fill(t, x + 4, 4, x + 11, 5, (206, 236, 252, 255))
        fill(t, x + 7, 4, x + 8, 9, (240, 240, 244, 255))
    fill(t, x, 14, x + 15, 15, OUTLINE)
    fill(t, x, 13, x + 15, 13, shade(face, 0.7))

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
        elif name == "grass_flower":
            tile_grass_flower(img, x)
        elif name == "path":
            fill(img, x, 0, x + 15, 15, (222, 204, 164, 255))
            d = ImageDraw.Draw(img)
            for (a, b, w, h) in ((1, 1, 6, 5), (9, 2, 5, 4), (2, 9, 5, 5), (9, 8, 6, 6)):
                d.rectangle([x + a, b, x + a + w, b + h], fill=(236, 222, 190, 255), outline=(176, 156, 120, 255))
        elif name == "hedge":
            fill(img, x, 0, x + 15, 15, GRASS_B)
            d = ImageDraw.Draw(img)
            d.ellipse([x - 1, 1, x + 9, 13], fill=(70, 142, 64, 255), outline=(38, 72, 40, 255))
            d.ellipse([x + 6, 0, x + 16, 13], fill=(70, 142, 64, 255), outline=(38, 72, 40, 255))
            fill(img, x + 2, 3, x + 4, 4, (120, 190, 96, 255))
            fill(img, x + 9, 2, x + 11, 3, (120, 190, 96, 255))
            fill(img, x, 14, x + 15, 15, (52, 100, 50, 255))
        elif name == "facade_school":
            tile_facade(img, x, (236, 210, 164, 255), (204, 172, 128, 255), band=(150, 96, 70, 255))
        elif name == "facade_fire":
            tile_facade(img, x, (200, 74, 62, 255), (156, 52, 46, 255), window=False, band=(246, 246, 246, 255))
        elif name == "garage_door":
            fill(img, x, 0, x + 15, 15, (226, 72, 60, 255))
            for y in range(1, 14, 3):
                fill(img, x, y, x + 15, y, (166, 46, 40, 255))
            fill(img, x, 0, x + 15, 0, (246, 246, 246, 255))
            fill(img, x, 14, x + 15, 15, OUTLINE)
        elif name == "facade_clinic":
            tile_facade(img, x, (244, 246, 250, 255), (214, 220, 230, 255), band=(96, 184, 146, 255))
        elif name == "facade_center":
            tile_facade(img, x, (214, 206, 188, 255), (184, 174, 154, 255), band=(110, 132, 170, 255))
        elif name == "facade_nursing":  # warm cream with a wood-brown band
            tile_facade(img, x, (246, 226, 196, 255), (220, 196, 160, 255), band=(156, 110, 76, 255))
        elif name == "facade_police":  # navy with a white band
            tile_facade(img, x, (70, 96, 160, 255), (52, 72, 126, 255), band=(240, 244, 250, 255))
        elif name == "facade_hospital":  # pale blue-gray with a red band
            tile_facade(img, x, (220, 230, 240, 255), (190, 204, 220, 255), band=(214, 70, 70, 255))
        elif name == "glass_door":
            fill(img, x, 0, x + 15, 15, (196, 200, 210, 255))
            fill(img, x, 0, x + 15, 1, OUTLINE)
            fill(img, x + 1, 2, x + 14, 15, (70, 76, 92, 255))
            fill(img, x + 2, 3, x + 13, 15, (160, 214, 246, 255))
            fill(img, x + 2, 3, x + 13, 5, (214, 240, 252, 255))
            fill(img, x + 7, 3, x + 8, 15, (70, 76, 92, 255))
            px(img, x + 6, 9, (250, 220, 120, 255))
            px(img, x + 9, 9, (250, 220, 120, 255))
        elif name == "tile_white":
            tile_floor(img, x, WHITE_TILE, (218, 226, 234, 255))
        elif name == "hospital_bed":
            tile_floor(img, x, WHITE_TILE, (218, 226, 234, 255))
            fill(img, x + 1, 0, x + 14, 15, (196, 204, 214, 255))
            fill(img, x + 2, 1, x + 13, 14, (252, 252, 254, 255))
            fill(img, x + 3, 2, x + 12, 5, (232, 238, 248, 255))
            fill(img, x + 2, 7, x + 13, 14, (140, 210, 190, 255))
            fill(img, x + 2, 7, x + 13, 7, (176, 230, 214, 255))
        elif name == "locker":
            fill(img, x, 0, x + 15, 15, (176, 176, 180, 255))
            fill(img, x + 1, 0, x + 14, 14, (140, 164, 190, 255))
            fill(img, x + 7, 0, x + 8, 14, (100, 120, 146, 255))
            for xx in (2, 9):
                for yy in (2, 4):
                    fill(img, x + xx, yy, x + xx + 4, yy, (100, 120, 146, 255))
            px(img, x + 6, 8, (240, 230, 160, 255))
            px(img, x + 9, 8, (240, 230, 160, 255))
            fill(img, x, 15, x + 15, 15, (90, 100, 120, 255))
        elif name == "med_cabinet":
            tile_floor(img, x, WHITE_TILE, (218, 226, 234, 255))
            fill(img, x + 1, 0, x + 14, 14, (250, 250, 252, 255))
            fill(img, x + 1, 14, x + 14, 15, (196, 204, 214, 255))
            fill(img, x + 6, 3, x + 9, 11, (80, 180, 120, 255))
            fill(img, x + 3, 6, x + 12, 8, (80, 180, 120, 255))
        elif name == "garage_floor":
            fill(img, x, 0, x + 15, 15, (184, 184, 188, 255))
            for (a, b) in ((3, 4), (11, 9), (6, 13), (13, 2)):
                px(img, x + a, b, (164, 164, 170, 255))
            fill(img, x, 15, x + 15, 15, (170, 170, 176, 255))
        elif name == "kiosk":
            fill(img, x, 0, x + 15, 15, FLOOR_C)
            fill(img, x + 3, 0, x + 12, 15, (70, 130, 200, 255))
            fill(img, x + 4, 2, x + 11, 6, (220, 240, 255, 255))
            fill(img, x + 5, 8, x + 7, 9, (240, 90, 80, 255))
            fill(img, x + 9, 8, x + 10, 9, (250, 220, 90, 255))
            fill(img, x + 5, 11, x + 10, 11, (40, 60, 100, 255))
            fill(img, x + 3, 15, x + 12, 15, (40, 70, 120, 255))
        elif name == "flower_bed":
            fill(img, x, 0, x + 15, 15, GRASS_B)
            fill(img, x, 7, x + 15, 15, (150, 96, 60, 255))
            fill(img, x, 7, x + 15, 7, (186, 126, 82, 255))
            fill(img, x, 15, x + 15, 15, OUTLINE)
            d = ImageDraw.Draw(img)
            d.ellipse([x, 0, x + 15, 9], fill=(84, 158, 72, 255))
            for (a, b, c) in ((3, 3, (255, 140, 170, 255)), (8, 2, (255, 230, 90, 255)), (12, 4, (255, 255, 255, 255)),
                              (6, 6, (255, 120, 110, 255))):
                fill(img, x + a, b, x + a + 1, b + 1, c)
        elif name == "conveyor":
            tile_floor(img, x, WHITE_TILE, (218, 226, 234, 255))
            fill(img, x, 3, x + 15, 12, (70, 74, 88, 255))
            for xx in range(0, 16, 4):
                fill(img, x + xx, 4, x + xx + 1, 11, (96, 100, 116, 255))
            fill(img, x, 3, x + 15, 3, (150, 156, 170, 255))
            fill(img, x, 12, x + 15, 13, (120, 126, 140, 255))
            fill(img, x, 14, x + 15, 14, OUTLINE)
        elif name == "qc_station":
            tile_floor(img, x, WHITE_TILE, (218, 226, 234, 255))
            fill(img, x, 2, x + 15, 13, (226, 230, 236, 255))
            fill(img, x, 2, x + 15, 3, (250, 250, 252, 255))
            fill(img, x + 2, 5, x + 7, 10, (130, 200, 250, 255))  # screen
            fill(img, x + 3, 6, x + 4, 6, (230, 246, 255, 255))
            fill(img, x + 10, 1, x + 10, 6, OUTLINE)  # lamp arm
            fill(img, x + 9, 6, x + 13, 7, (250, 210, 80, 255))
            fill(img, x + 10, 9, x + 13, 11, (90, 200, 120, 255))  # pass button
            fill(img, x, 14, x + 15, 15, (150, 156, 170, 255))
        elif name == "chalkboard":
            tile_wall(img, x)
            fill(img, x + 1, 3, x + 14, 12, (150, 104, 66, 255))
            fill(img, x + 2, 4, x + 13, 11, (52, 112, 82, 255))
            fill(img, x + 4, 6, x + 9, 6, (230, 236, 220, 255))
            fill(img, x + 4, 8, x + 11, 8, (230, 236, 220, 255))
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


def make_vehicles():
    """Parked vehicles seen from above, front facing down (out of the garage)."""
    ft = Image.new("RGBA", (24, 44), T)
    red, red_d = (214, 52, 44, 255), (160, 36, 30, 255)
    fill(ft, 3, 1, 20, 42, red)
    fill(ft, 3, 1, 3, 42, red_d)
    fill(ft, 4, 3, 19, 27, (196, 200, 210, 255))  # ladder deck
    for y in range(4, 27, 3):
        fill(ft, 7, y, 16, y, (130, 134, 150, 255))
    fill(ft, 7, 3, 7, 27, (130, 134, 150, 255))
    fill(ft, 16, 3, 16, 27, (130, 134, 150, 255))
    fill(ft, 3, 29, 20, 30, (246, 246, 246, 255))  # stripe
    fill(ft, 5, 33, 18, 39, (170, 220, 250, 255))  # windshield
    fill(ft, 5, 33, 18, 34, (220, 242, 252, 255))
    fill(ft, 6, 31, 9, 32, (80, 140, 250, 255))
    fill(ft, 14, 31, 17, 32, (250, 80, 80, 255))
    for y in (6, 18, 34):
        fill(ft, 0, y, 2, y + 4, (40, 40, 48, 255))
        fill(ft, 21, y, 23, y + 4, (40, 40, 48, 255))
    outline(ft)
    ft.save(OUT / "firetruck.png")

    amb = Image.new("RGBA", (20, 36), T)
    fill(amb, 2, 1, 17, 34, (248, 248, 250, 255))
    fill(amb, 2, 1, 2, 34, (210, 214, 224, 255))
    fill(amb, 2, 20, 17, 21, (240, 120, 40, 255))
    fill(amb, 8, 6, 11, 15, (226, 58, 50, 255))  # cross on the roof
    fill(amb, 5, 9, 14, 12, (226, 58, 50, 255))
    fill(amb, 4, 25, 15, 31, (170, 220, 250, 255))
    fill(amb, 4, 23, 7, 24, (250, 80, 80, 255))
    fill(amb, 12, 23, 15, 24, (80, 140, 250, 255))
    for y in (5, 26):
        fill(amb, 0, y, 1, y + 3, (40, 40, 48, 255))
        fill(amb, 18, y, 19, y + 3, (40, 40, 48, 255))
    outline(amb)
    amb.save(OUT / "ambulance.png")


def _food_sheet(name, fw, fh, draw):
    """3 frames: full, half eaten, empty."""
    img = Image.new("RGBA", (fw * 3, fh), T)
    for f in range(3):
        fr = Image.new("RGBA", (fw, fh), T)
        draw(fr, ImageDraw.Draw(fr), f)
        outline(fr)
        img.paste(fr, (f * fw, 0))
    img.save(OUT / name)


def make_meal_scene():
    """Art for the cafeteria meal window (Story._eat_at_cafeteria)."""
    W, H = 160, 90
    bg = Image.new("RGBA", (W, H), (252, 238, 208, 255))
    d = ImageDraw.Draw(bg)
    fill(bg, 0, 52, W - 1, H - 1, (214, 168, 116, 255))  # wainscot
    fill(bg, 0, 52, W - 1, 53, (176, 126, 82, 255))
    for xx in range(0, W, 12):
        fill(bg, xx, 54, xx, H - 1, (196, 150, 102, 255))
    # window with sky and a cloud
    d.rectangle([12, 10, 58, 42], fill=(246, 246, 250, 255), outline=OUTLINE)
    fill(bg, 15, 13, 55, 39, (150, 210, 250, 255))
    fill(bg, 15, 13, 55, 18, (190, 228, 252, 255))
    d.ellipse([22, 20, 38, 28], fill=(255, 255, 255, 255))
    d.ellipse([30, 17, 44, 27], fill=(255, 255, 255, 255))
    fill(bg, 35, 13, 35, 39, (246, 246, 250, 255))
    # menu board
    d.rectangle([98, 8, 150, 42], fill=(150, 104, 66, 255), outline=OUTLINE)
    fill(bg, 101, 11, 147, 39, (52, 104, 78, 255))
    for i, yy in enumerate((15, 21, 27, 33)):
        fill(bg, 104, yy, 104 + 22 + (i % 2) * 10, yy, (236, 236, 220, 255))
        fill(bg, 136, yy, 143, yy, (250, 220, 120, 255))
    # pendant lamp
    fill(bg, 79, 0, 80, 8, OUTLINE)
    d.polygon([(72, 14), (87, 14), (83, 8), (76, 8)], fill=(250, 200, 80, 255), outline=OUTLINE)
    fill(bg, 76, 15, 83, 16, (255, 240, 180, 255))
    # potted plant on the right
    d.rectangle([152, 36, 159, 52], fill=(196, 110, 70, 255), outline=OUTLINE)
    d.ellipse([148, 22, 164, 40], fill=(84, 158, 72, 255), outline=OUTLINE)
    bg.save(OUT / "meal_bg.png")

    table = Image.new("RGBA", (W, 34), T)
    fill(table, 0, 4, W - 1, 22, (204, 148, 96, 255))
    fill(table, 0, 4, W - 1, 5, (228, 180, 128, 255))
    fill(table, 0, 23, W - 1, 28, (150, 100, 62, 255))
    fill(table, 0, 3, W - 1, 3, OUTLINE)
    fill(table, 0, 29, W - 1, 29, OUTLINE)
    for lx in (14, 140):
        fill(table, lx, 30, lx + 5, 33, (120, 78, 50, 255))
    table.save(OUT / "meal_table.png")

    def gukbap(fr, d, f):
        d.ellipse([1, 4, 22, 17], fill=(70, 50, 44, 255))  # 뚝배기
        d.ellipse([3, 3, 20, 11], fill=(110, 80, 66, 255))
        if f < 2:
            top = 4 if f == 0 else 6
            d.ellipse([4, top, 19, 11], fill=(214, 92, 56, 255))
            for (a, b) in ((7, 6), (12, 7), (15, 6)):
                if f == 0 or a != 12:
                    fill(fr, a, b + (top - 4), a + 1, b + (top - 4), (110, 190, 80, 255))
            fill(fr, 9, top + 2, 11, top + 3, (250, 240, 220, 255))
        else:
            d.ellipse([5, 5, 18, 10], fill=(150, 90, 66, 255))

    def meal(fr, d, f):
        fill(fr, 0, 2, 33, 19, (186, 196, 206, 255))
        fill(fr, 0, 2, 33, 3, (210, 218, 226, 255))
        d.ellipse([2, 4, 13, 12], fill=(250, 250, 246, 255) if f < 2 else (226, 230, 236, 255))  # rice
        if f == 0:
            d.ellipse([3, 3, 12, 9], fill=(255, 255, 252, 255))
        d.ellipse([15, 4, 25, 12], fill=(200, 110, 70, 255) if f < 2 else (180, 150, 130, 255))  # soup
        for i, c in enumerate(((110, 180, 90, 255), (240, 160, 70, 255), (250, 220, 120, 255))):
            if f == 0 or (f == 1 and i != 1):
                fill(fr, 3 + i * 9, 14, 8 + i * 9, 17, c)
        fill(fr, 27, 5, 31, 7, (236, 120, 100, 255) if f == 0 else (186, 196, 206, 255))

    def curry(fr, d, f):
        d.ellipse([0, 4, 27, 17], fill=(250, 250, 252, 255))
        d.ellipse([2, 5, 25, 15], fill=(236, 238, 242, 255))
        if f < 2:
            d.ellipse([4, 6, 14, 14] if f == 0 else [6, 7, 13, 13], fill=(255, 255, 250, 255))
            d.ellipse([12, 6, 24, 14] if f == 0 else [14, 8, 22, 13], fill=(214, 150, 50, 255))
            fill(fr, 17, 9, 18, 10, (240, 120, 50, 255))
            if f == 0:
                fill(fr, 20, 11, 21, 12, (240, 120, 50, 255))
        else:
            fill(fr, 10, 10, 16, 10, (220, 190, 120, 255))

    _food_sheet("food_gukbap.png", 24, 18, gukbap)
    _food_sheet("food_meal.png", 34, 20, meal)
    _food_sheet("food_curry.png", 28, 18, curry)
    spoon = Image.new("RGBA", (5, 12), T)
    ImageDraw.Draw(spoon).ellipse([0, 0, 4, 4], fill=(226, 230, 238, 255))
    fill(spoon, 2, 4, 2, 11, (200, 206, 216, 255))
    outline(spoon)
    spoon.save(OUT / "spoon.png")


def _save_outlined(img, name):
    outline(img)
    img.save(OUT / name)


def make_products():
    """Goods on the inspection conveyor (24x24, drawn at 3x). Defects are drawn by the game."""
    def furniture(d, im):  # desk / shelf / chair: wooden top and legs
        d.rectangle([2, 6, 21, 11], fill=(200, 146, 92, 255))
        fill(im, 2, 6, 21, 7, (226, 176, 120, 255))
        fill(im, 3, 12, 5, 21, (150, 100, 62, 255))
        fill(im, 18, 12, 20, 21, (150, 100, 62, 255))
        fill(im, 6, 12, 17, 13, (170, 116, 72, 255))

    def device(d, im):  # projector / purifier / thermometer box: casing, lens, buttons
        d.rounded_rectangle([1, 5, 22, 19], 3, fill=(236, 238, 244, 255))
        fill(im, 2, 6, 21, 7, (252, 252, 255, 255))
        d.ellipse([4, 8, 11, 15], fill=(60, 66, 84, 255))
        d.ellipse([6, 10, 9, 13], fill=(130, 200, 250, 255))
        fill(im, 14, 9, 19, 10, (90, 200, 120, 255))
        fill(im, 14, 13, 19, 14, (240, 120, 90, 255))
        fill(im, 2, 17, 21, 18, (200, 204, 214, 255))

    def soft(d, im):  # folded mat / fire suit: fabric with seams
        d.rounded_rectangle([2, 4, 21, 20], 2, fill=(110, 150, 220, 255))
        fill(im, 2, 11, 21, 12, (86, 120, 190, 255))
        for xx in (6, 12, 18):
            fill(im, xx, 5, xx, 19, (140, 176, 236, 255))
        fill(im, 3, 5, 20, 5, (150, 186, 240, 255))

    def metal(d, im):  # tray / wheelchair parts / hose reel: steel
        d.rounded_rectangle([1, 6, 22, 17], 3, fill=(196, 202, 212, 255))
        d.rounded_rectangle([4, 8, 19, 15], 2, fill=(170, 178, 190, 255))
        fill(im, 2, 7, 21, 7, (232, 236, 242, 255))
        fill(im, 6, 10, 10, 10, (226, 230, 238, 255))

    for name, fn in (("furniture", furniture), ("device", device), ("soft", soft), ("metal", metal)):
        img = Image.new("RGBA", (24, 24), T)
        fn(ImageDraw.Draw(img), img)
        _save_outlined(img, f"product_{name}.png")

    mag = Image.new("RGBA", (14, 14), T)
    d = ImageDraw.Draw(mag)
    d.ellipse([0, 0, 9, 9], outline=(60, 60, 70, 255), width=2)
    d.ellipse([2, 2, 7, 7], fill=(200, 236, 255, 160))
    d.line([(8, 8), (13, 13)], fill=(150, 100, 60, 255), width=2)
    mag.save(OUT / "magnifier.png")

    box = Image.new("RGBA", (12, 10), T)
    fill(box, 0, 1, 11, 9, (210, 160, 100, 255))
    fill(box, 0, 1, 11, 2, (236, 190, 130, 255))
    fill(box, 5, 1, 6, 9, (180, 130, 80, 255))
    _save_outlined(box, "box_carry.png")


def _room_bg(wall, floor, name, extra):
    W, H = 160, 90
    bg = Image.new("RGBA", (W, H), wall)
    d = ImageDraw.Draw(bg)
    fill(bg, 0, 66, W - 1, H - 1, floor)
    fill(bg, 0, 66, W - 1, 67, shade(floor, 0.8))
    for xx in range(0, W, 16):
        fill(bg, xx, 68, xx, H - 1, shade(floor, 0.9))
    extra(bg, d)
    bg.save(OUT / name)


def make_event_scenes():
    """Backgrounds for EventWindow: the inspection lab and a storage room."""
    def lab(bg, d):
        d.rectangle([10, 8, 50, 34], fill=(246, 246, 250, 255), outline=OUTLINE)  # window
        fill(bg, 13, 11, 47, 31, (170, 220, 250, 255))
        for i, xx in enumerate((104, 120, 136)):  # shelf with sample boxes
            d.rectangle([xx, 14, xx + 12, 26], fill=((120, 170, 230, 255), (240, 200, 90, 255), (140, 200, 140, 255))[i],
                        outline=OUTLINE)
        fill(bg, 98, 27, 154, 29, (150, 104, 66, 255))
        d.rectangle([56, 8, 92, 30], fill=(52, 104, 78, 255), outline=OUTLINE)  # results board
        for yy in (13, 18, 23):
            fill(bg, 60, yy, 80, yy, (236, 236, 220, 255))
            fill(bg, 84, yy, 88, yy, (120, 220, 120, 255))
        d.rectangle([24, 56, 136, 74], fill=(226, 230, 236, 255), outline=OUTLINE)  # inspection table
        fill(bg, 25, 57, 135, 58, (250, 250, 252, 255))
        fill(bg, 30, 75, 33, 89, (150, 156, 170, 255))
        fill(bg, 127, 75, 130, 89, (150, 156, 170, 255))

    def room(bg, d):
        for sx in (8, 112):  # shelves
            d.rectangle([sx, 16, sx + 40, 64], fill=(170, 116, 72, 255), outline=OUTLINE)
            for yy in (30, 46):
                fill(bg, sx + 1, yy, sx + 39, yy + 1, (130, 86, 52, 255))
            for k in range(3):
                d.rectangle([sx + 4 + k * 12, 20, sx + 13 + k * 12, 29], fill=(210, 160, 100, 255), outline=OUTLINE)
        d.rectangle([64, 10, 96, 30], fill=(246, 246, 250, 255), outline=OUTLINE)
        fill(bg, 67, 13, 93, 27, (170, 220, 250, 255))

    _room_bg((236, 240, 246, 255), (196, 202, 214, 255), "event_lab.png", lab)
    _room_bg((250, 236, 206, 255), (196, 150, 102, 255), "event_room.png", room)


# ------------------------------------------------------------------ 조달청 logo
# Pixelized from the official symbol (tools/ref/pps_logo.jpg: emblem + wordmark).
# The colors are reduced to the logo's own navy / red / gray; white becomes clear.
LOGO_REF = Path(__file__).resolve().parent / "ref" / "pps_logo.jpg"
LOGO_EMBLEM_BOX = (180, 31, 608, 445)  # in the reference image
LOGO_TEXT_BOX = (712, 155, 1257, 337)
LOGO_NAVY, LOGO_RED, LOGO_GRAY = (5, 56, 99, 255), (228, 3, 45, 255), (87, 85, 86, 255)


def _logo_quant(img, pal, white_bias):
    out = Image.new("RGBA", img.size, T)
    src = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = src[x, y]
            best, best_d = None, None
            for q in pal + [(255, 255, 255, 0)]:
                dist = sum((a - b) ** 2 for a, b in zip(c, q[:3])) * (white_bias if q[3] == 0 else 1)
                if best_d is None or dist < best_d:
                    best, best_d = q, dist
            out.putpixel((x, y), best if best[3] else T)
    return out


def logo_emblem(size):
    ref = Image.open(LOGO_REF).convert("RGB")
    return _logo_quant(ref.crop(LOGO_EMBLEM_BOX).resize((size, size), Image.BOX), [LOGO_NAVY, LOGO_RED], 1.6)


def logo_wordmark(height):
    ref = Image.open(LOGO_REF).convert("RGB").crop(LOGO_TEXT_BOX)
    w = round(ref.width * height / ref.height)
    return _logo_quant(ref.resize((w, height), Image.BOX), [LOGO_GRAY], 1.3)


def logo(emblem=14, text=10, gap=3):
    """Horizontal logo (emblem, then 조달청), transparent background."""
    em, tx = logo_emblem(emblem), logo_wordmark(text)
    img = Image.new("RGBA", (em.width + gap + tx.width, max(em.height, tx.height)), T)
    img.alpha_composite(em, (0, (img.height - em.height) // 2))
    img.alpha_composite(tx, (em.width + gap, (img.height - tx.height) // 2))
    return img


def make_logo():
    """pps_logo.png: the pixel logo on a white plate (ID card in character creation)."""
    lg = logo(16, 11, 4)
    plate = Image.new("RGBA", (lg.width + 8, lg.height + 6), (255, 255, 255, 255))
    plate.alpha_composite(lg, (4, 3))
    plate.save(OUT / "pps_logo.png")


def make_title():
    """Title screen town (320x180, shown at 2x): destinations on both sides, 조달청 in the middle."""
    W, H = 320, 180
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    for y in range(0, 140):  # sky gradient
        t = y / 140
        c = (int(120 + 90 * t), int(190 + 40 * t), int(250 - 10 * t), 255)
        fill(img, 0, y, W - 1, y, c)
    for i, (cx, r) in enumerate(((20, 30), (90, 24), (170, 34), (250, 26), (310, 30))):  # far hills
        d.ellipse([cx - r * 2, 104 - r // 2, cx + r * 2, 140 + r], fill=(120, 190, 120, 255))
    fill(img, 0, 140, W - 1, 151, (214, 206, 190, 255))  # sidewalk
    for xx in range(0, W, 8):
        fill(img, xx, 140, xx, 151, (196, 188, 172, 255))
    fill(img, 0, 140, W - 1, 140, OUTLINE)
    fill(img, 0, 152, W - 1, H - 1, (84, 86, 98, 255))  # road
    fill(img, 0, 152, W - 1, 152, (230, 230, 230, 255))
    for xx in range(4, W, 20):
        fill(img, xx, 165, xx + 9, 166, (240, 210, 90, 255))

    def windows(x0, y0, x1, y1, cols, rows, frame=(246, 246, 250, 255)):
        cw = (x1 - x0) // cols
        rh = (y1 - y0) // rows
        for cx in range(cols):
            for ry in range(rows):
                wx, wy = x0 + cx * cw + 2, y0 + ry * rh + 2
                d.rectangle([wx, wy, wx + cw - 5, wy + rh - 5], fill=frame, outline=OUTLINE)
                fill(img, wx + 1, wy + 1, wx + cw - 6, wy + rh - 6, (150, 206, 246, 255))

    def tree(x, y, c=(80, 160, 76, 255)):
        fill(img, x - 1, y, x + 1, y + 10, (130, 86, 52, 255))
        d.ellipse([x - 8, y - 12, x + 8, y + 4], fill=c, outline=OUTLINE)
        d.ellipse([x - 5, y - 10, x, y - 5], fill=shade(c, 1.25))

    # Buildings go on their own transparent layer: cropped below into bld_<id>.png for
    # the driving minigame (start: 조달청, finish: the destination), then composited.
    background = img
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    # school (left)
    d.rectangle([6, 96, 58, 140], fill=(236, 210, 164, 255), outline=OUTLINE)
    d.polygon([(4, 96), (32, 82), (60, 96)], fill=(176, 92, 70, 255), outline=OUTLINE)
    d.ellipse([27, 86, 37, 96], fill=(250, 250, 250, 255), outline=OUTLINE)
    fill(img, 32, 88, 32, 91, OUTLINE)
    fill(img, 32, 91, 34, 91, OUTLINE)
    windows(9, 100, 56, 126, 4, 2)
    d.rectangle([26, 128, 38, 140], fill=(150, 206, 246, 255), outline=OUTLINE)
    # fire station
    d.rectangle([62, 104, 104, 140], fill=(200, 74, 62, 255), outline=OUTLINE)
    fill(img, 62, 104, 104, 107, (246, 246, 246, 255))
    for gx in (66, 86):
        d.rectangle([gx, 118, gx + 15, 140], fill=(226, 72, 60, 255), outline=OUTLINE)
        for yy in range(121, 140, 4):
            fill(img, gx + 1, yy, gx + 14, yy, (166, 46, 40, 255))
    windows(66, 108, 102, 117, 3, 1)
    # 조달청 (center): wide government building, columns, flag
    d.rectangle([106, 60, 214, 140], fill=(232, 228, 216, 255), outline=OUTLINE)
    d.rectangle([100, 54, 220, 62], fill=(196, 190, 176, 255), outline=OUTLINE)
    windows(112, 64, 208, 94, 6, 2)
    d.rectangle([130, 96, 190, 111], fill=(255, 255, 255, 255), outline=OUTLINE)  # sign: the pixel logo
    sign = logo(14, 10, 3)
    img.alpha_composite(sign, (160 - sign.width // 2, 97 + (14 - sign.height) // 2))
    for cx in range(118, 206, 14):  # columns at the entrance
        d.rectangle([cx, 112, cx + 5, 140], fill=(250, 248, 240, 255), outline=OUTLINE)
    d.rectangle([150, 118, 170, 140], fill=(150, 206, 246, 255), outline=OUTLINE)
    fill(img, 160, 118, 160, 140, OUTLINE)
    fill(img, 211, 30, 212, 54, OUTLINE)  # flagpole at the right end of the roof (the title banner covers the middle)
    d.rectangle([213, 29, 231, 41], fill=(255, 255, 255, 255), outline=OUTLINE)  # flag with the emblem
    img.alpha_composite(logo_emblem(9), (218, 31))
    # clinic
    d.rectangle([218, 100, 260, 140], fill=(244, 246, 250, 255), outline=OUTLINE)
    fill(img, 218, 100, 260, 103, (96, 184, 146, 255))
    d.rectangle([233, 106, 245, 118], fill=(250, 250, 250, 255), outline=OUTLINE)
    fill(img, 237, 108, 241, 116, (80, 180, 120, 255))
    fill(img, 235, 110, 243, 114, (80, 180, 120, 255))
    windows(221, 120, 258, 131, 3, 1)
    # community center
    d.rectangle([264, 94, 314, 140], fill=(214, 206, 188, 255), outline=OUTLINE)
    fill(img, 264, 94, 314, 98, (110, 132, 170, 255))
    windows(267, 100, 312, 126, 4, 2)
    d.rectangle([282, 128, 296, 140], fill=(150, 206, 246, 255), outline=OUTLINE)
    for name, box in (("school", (4, 81, 61, 141)), ("fire", (61, 103, 105, 141)), ("pps", (99, 29, 233, 141)),
                      ("clinic", (217, 99, 262, 141)), ("center", (263, 93, 316, 141))):
        part = img.crop(box)
        if name == "pps":  # the neighbours overlap its roof line: keep only the 조달청 below the roof
            for yy in range(63 - box[1], part.height):
                for xx in list(range(0, 106 - box[0])) + list(range(215 - box[0], part.width)):
                    part.putpixel((xx, yy), T)
        part.save(OUT / f"bld_{name}.png")
    background.alpha_composite(img)
    img = background
    d = ImageDraw.Draw(img)
    for x in (2, 60, 108, 212, 262, 318):  # trees and flowers on the sidewalk
        tree(x, 134)
    for x in range(4, W, 11):
        px(img, x, 146, (255, 150, 176, 255))
        px(img, x + 5, 148, (255, 230, 90, 255))
    img.save(OUT / "title_town.png")

    cloud = Image.new("RGBA", (28, 12), T)
    dc = ImageDraw.Draw(cloud)
    for (a, b, c, e) in ((0, 4, 12, 11), (7, 0, 20, 11), (15, 3, 27, 11)):
        dc.ellipse([a, b, c, e], fill=(255, 255, 255, 255))
    cloud.save(OUT / "cloud.png")


def make_extra_buildings():
    """bld_<id>.png for destinations that are not on the title town (drive finish line)."""
    def windows(d, img, x0, y0, x1, y1, cols, rows):
        cw = (x1 - x0) // cols
        rh = (y1 - y0) // rows
        for cx in range(cols):
            for ry in range(rows):
                wx, wy = x0 + cx * cw + 2, y0 + ry * rh + 2
                d.rectangle([wx, wy, wx + cw - 5, wy + rh - 5], fill=(246, 246, 250, 255), outline=OUTLINE)
                fill(img, wx + 1, wy + 1, wx + cw - 6, wy + rh - 6, (150, 206, 246, 255))

    # 요양원: low, wide, warm cream walls, brown roof, a ramp to the door
    img = Image.new("RGBA", (64, 46), T)
    d = ImageDraw.Draw(img)
    d.rectangle([3, 16, 60, 45], fill=(246, 226, 196, 255), outline=OUTLINE)
    d.polygon([(0, 17), (10, 6), (53, 6), (63, 17)], fill=(156, 110, 76, 255), outline=OUTLINE)
    windows(d, img, 6, 19, 58, 34, 5, 1)
    d.rectangle([26, 35, 37, 45], fill=(150, 206, 246, 255), outline=OUTLINE)
    d.polygon([(38, 45), (38, 41), (50, 45)], fill=(200, 196, 186, 255), outline=OUTLINE)
    for x in (8, 54):  # flower boxes
        d.rectangle([x - 4, 41, x + 4, 45], fill=(140, 96, 60, 255), outline=OUTLINE)
        for k in (-2, 1, 3):
            px(img, x + k, 40, (255, 150, 176, 255))
    img.save(OUT / "bld_nursing.png")

    # 경찰서: navy walls, white band, blue-red light on the roof
    img = Image.new("RGBA", (54, 54), T)
    d = ImageDraw.Draw(img)
    d.rectangle([2, 12, 51, 53], fill=(70, 96, 160, 255), outline=OUTLINE)
    fill(img, 3, 13, 50, 16, (240, 244, 250, 255))
    windows(d, img, 5, 18, 49, 40, 4, 2)
    d.rectangle([20, 42, 33, 53], fill=(150, 206, 246, 255), outline=OUTLINE)
    fill(img, 26, 42, 26, 53, OUTLINE)
    d.rectangle([19, 4, 34, 11], fill=(230, 230, 236, 255), outline=OUTLINE)
    fill(img, 21, 6, 25, 9, (60, 110, 230, 255))
    fill(img, 28, 6, 32, 9, (230, 60, 60, 255))
    img.save(OUT / "bld_police.png")

    # 병원: tall pale building, red band, red cross sign
    img = Image.new("RGBA", (56, 70), T)
    d = ImageDraw.Draw(img)
    d.rectangle([2, 6, 53, 69], fill=(220, 230, 240, 255), outline=OUTLINE)
    fill(img, 3, 7, 52, 10, (214, 70, 70, 255))
    windows(d, img, 5, 24, 51, 56, 4, 3)
    d.rectangle([20, 11, 35, 22], fill=(250, 250, 250, 255), outline=OUTLINE)
    fill(img, 26, 13, 29, 20, (214, 60, 60, 255))
    fill(img, 23, 15, 32, 18, (214, 60, 60, 255))
    d.rectangle([18, 58, 37, 69], fill=(150, 206, 246, 255), outline=OUTLINE)
    fill(img, 27, 58, 27, 69, OUTLINE)
    img.save(OUT / "bld_hospital.png")


def make_race():
    """Racing minigame extras: a tintable rival truck, a box obstacle, a drink pickup."""
    rival = Image.new("RGBA", (18, 30), T)
    fill(rival, 2, 1, 15, 28, (250, 250, 250, 255))
    fill(rival, 2, 1, 15, 2, (255, 255, 255, 255))
    fill(rival, 4, 3, 13, 8, (190, 228, 252, 255))
    fill(rival, 3, 11, 14, 27, (226, 226, 232, 255))
    fill(rival, 6, 15, 11, 19, (200, 200, 208, 255))
    for y in (5, 22):
        fill(rival, 0, y, 1, y + 3, (40, 40, 48, 255))
        fill(rival, 16, y, 17, y + 3, (40, 40, 48, 255))
    _save_outlined(rival, "car_rival.png")
    crate = Image.new("RGBA", (14, 14), T)
    fill(crate, 1, 1, 12, 12, (200, 150, 92, 255))
    fill(crate, 1, 1, 12, 2, (230, 184, 126, 255))
    fill(crate, 6, 1, 7, 12, (170, 120, 70, 255))
    fill(crate, 1, 6, 12, 7, (170, 120, 70, 255))
    _save_outlined(crate, "race_crate.png")
    bar = Image.new("RGBA", (38, 12), T)  # road-works barricade, spans one lane
    fill(bar, 1, 2, 36, 7, (250, 250, 250, 255))
    for k in range(-6, 38, 8):
        for y in range(2, 8):
            for xx in range(k + (y - 2), k + (y - 2) + 4):
                if 1 <= xx <= 36:
                    px(bar, xx, y, (240, 120, 40, 255))
    fill(bar, 3, 8, 4, 10, (70, 70, 80, 255))
    fill(bar, 33, 8, 34, 10, (70, 70, 80, 255))
    fill(bar, 2, 0, 3, 1, (250, 220, 60, 255))
    fill(bar, 34, 0, 35, 1, (250, 220, 60, 255))
    _save_outlined(bar, "barricade.png")
    can = Image.new("RGBA", (10, 14), T)
    fill(can, 1, 1, 8, 12, (60, 170, 230, 255))
    fill(can, 1, 1, 8, 2, (200, 210, 220, 255))
    fill(can, 3, 5, 6, 8, (250, 230, 80, 255))
    _save_outlined(can, "pickup_drink.png")


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
    icon("item_energybar.png", lambda im, d: (fill(im, 4, 2, 11, 14, (60, 170, 230, 255)),  # energy drink can
                                              fill(im, 4, 2, 11, 3, (210, 216, 226, 255)),
                                              fill(im, 6, 6, 9, 10, (250, 230, 80, 255))))


# Order = PhoneMenu.APP_ICONS in scripts/ui/phone_menu.gd (append only).
PHONE_APPS = ["task", "bag", "growth", "save", "sound", "title"]


def make_phone_apps():
    """Esc menu smartphone: one row of 24x24 app icons (rounded tile + white glyph)."""
    S = 24
    sheet = Image.new("RGBA", (S * len(PHONE_APPS), S), T)
    W = (255, 255, 255, 255)
    tiles = {"task": (66, 122, 230), "bag": (232, 150, 60), "growth": (70, 176, 104),
             "save": (120, 96, 210), "sound": (236, 92, 120), "title": (96, 106, 128)}
    for i, name in enumerate(PHONE_APPS):
        img = Image.new("RGBA", (S, S), T)
        d = ImageDraw.Draw(img)
        base = tiles[name] + (255,)
        d.rounded_rectangle([1, 1, S - 2, S - 2], radius=6, fill=base, outline=OUTLINE)
        d.rounded_rectangle([2, 2, S - 3, 8], radius=4, fill=shade(base, 1.15))
        fill(img, 3, 6, S - 4, 8, base)
        if name == "task":  # clipboard with lines
            d.rectangle([7, 5, 16, 18], fill=W, outline=OUTLINE)
            d.rectangle([9, 4, 14, 6], fill=(200, 200, 210, 255), outline=OUTLINE)
            for y in (9, 12, 15):
                fill(img, 9, y, 14, y, base)
        elif name == "bag":  # briefcase
            d.rectangle([5, 9, 18, 18], fill=W, outline=OUTLINE)
            d.rectangle([9, 6, 14, 9], outline=OUTLINE)
            fill(img, 5, 13, 18, 13, shade(base, 0.8))
            fill(img, 11, 12, 12, 14, base)
        elif name == "growth":  # rising bars + arrow
            for k, h in enumerate((4, 7, 10)):
                d.rectangle([6 + k * 4, 18 - h, 8 + k * 4, 18], fill=W, outline=OUTLINE)
            d.line([(6, 10), (11, 7), (17, 4)], fill=(255, 236, 120, 255), width=1)
            fill(img, 15, 4, 17, 4, (255, 236, 120, 255))
            fill(img, 17, 4, 17, 6, (255, 236, 120, 255))
        elif name == "save":  # floppy disk
            d.rectangle([6, 5, 17, 18], fill=W, outline=OUTLINE)
            d.rectangle([8, 5, 15, 9], fill=(190, 196, 210, 255), outline=OUTLINE)
            d.rectangle([8, 12, 15, 18], fill=shade(base, 1.3), outline=OUTLINE)
        elif name == "sound":  # speaker + waves
            d.polygon([(5, 10), (8, 10), (12, 6), (12, 17), (8, 13), (5, 13)], fill=W, outline=OUTLINE)
            d.arc([11, 8, 16, 15], -60, 60, fill=W)
            d.arc([11, 5, 19, 18], -60, 60, fill=W)
        elif name == "title":  # little house
            d.polygon([(5, 12), (12, 5), (19, 12)], fill=W, outline=OUTLINE)
            d.rectangle([7, 12, 17, 18], fill=W, outline=OUTLINE)
            d.rectangle([11, 14, 13, 18], fill=base, outline=OUTLINE)
        sheet.paste(img, (i * S, 0))
    sheet.save(OUT / "phone_apps.png")


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


# Same values as GameState (scripts/autoload/game_state.gd), for the preview only.
PV_SKIN = [(255, 226, 200), (244, 200, 160), (214, 160, 116), (150, 100, 70)]
PV_HAIR = [(58, 47, 47), (138, 90, 58), (224, 176, 96), (107, 123, 208)]
PV_OUTFIT = [(60, 77, 140), (74, 74, 82), (201, 138, 106), (240, 240, 240)]


def player_frame(r, c, gender=0, skin=0, hair_style=0, hair_color=0, outfit_style=0, outfit_color=0):
    box = (c * FW, r * FH, (c + 1) * FW, (r + 1) * FH)
    load = lambda n: Image.open(OUT / n).crop(box)
    return merged(_multiply(load("player_skin.png"), PV_SKIN[skin]),
                  load(f"player_outfit_{outfit_style}_base.png"),
                  _multiply(load(f"player_outfit_{outfit_style}.png"), PV_OUTFIT[outfit_color]),
                  load(f"player_face_{gender}.png"),
                  _multiply(load(f"player_hair_{hair_style}.png"), PV_HAIR[hair_color]))


def preview(path):
    """Writes a 4x review sheet: player options (tinted like the game), NPCs, tiles."""
    cells = []
    for s in range(len(HAIR_DOWN)):  # row 0: hair styles, front / side / back
        cells.append([player_frame(0, 0, int(s >= 2), 0, s, 1), player_frame(2, 0, int(s >= 2), 0, s, 1),
                      player_frame(1, 0, int(s >= 2), 0, s, 1)])
    rows = [[f for trio in cells for f in trio][:15]]
    rows.append([player_frame(0, 0, 1 if o == 1 else 0, o % 4, 3 if o == 1 else 0, o, o, o) for o in range(4)]
                + [player_frame(2, 1, 1 if o == 1 else 0, o % 4, 3 if o == 1 else 0, o, o, o) for o in range(4)]
                + [player_frame(0, c, 0, 1, 1, 0, 2, 2) for c in range(4)])
    names = ["npc_narumi.png", "npc_dari.png", "npc_team_leader.png", "npc_officer_school.png",
             "npc_senior.png", "npc_vendor.png", "npc_cafeteria.png"]
    rows.append([Image.open(OUT / n).crop((0, 0, FW, FH)) for n in names]
                + [player_frame(1, c, 1, 2, 4, 2, 3, 1) for c in range(4)])
    places = ["teacher", "student", "officer_fire", "firefighter", "officer_clinic", "nurse", "officer_center",
              "citizen"]
    rows.append([Image.open(OUT / f"npc_{n}.png").crop((0, 0, FW, FH)) for n in places])
    sheet = Image.new("RGBA", (FW * 15, FH * len(rows) + 32), (70, 80, 110, 255))
    for y, row in enumerate(rows):
        for x, fr in enumerate(row):
            sheet.paste(fr, (x * FW, y * FH), fr)
    tiles = Image.open(OUT / "tiles.png")
    for i in range(0, tiles.width, FW * 15):
        part = tiles.crop((i, 0, min(tiles.width, i + FW * 15), 16))
        sheet.paste(part, (0, FH * len(rows) + 16 * (i // (FW * 15))), part)
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(path)


if __name__ == "__main__":
    import sys
    make_player()
    make_npcs()
    make_tiles()
    make_drive()
    make_vehicles()
    make_meal_scene()
    make_products()
    make_event_scenes()
    make_logo()
    make_title()
    make_extra_buildings()
    make_race()
    make_icons()
    make_phone_apps()
    make_touch_ui()
    if len(sys.argv) > 1:
        preview(sys.argv[1])
    print("placeholders written to", OUT)
