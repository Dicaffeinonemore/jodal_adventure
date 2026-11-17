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
    img = Image.new("RGBA", (FW * 2, FH), T)
    for c in range(2):  # frame 1 bobs
        L = frame_layers(0, c, spec, style, gender)
        mid = Image.new("RGBA", (FW, FH), T)  # over the clothes (apron)
        top = Image.new("RGBA", (FW, FH), T)  # over the hair (glasses, cap)
        if extras:
            extras(mid, top, c, bob(c))
        fr = merged(_multiply(L["skin"], skin), L["cbase"], _multiply(L["ctint"], jacket), mid,
                    L["face"], _multiply(L["hair"], hair), top)
        img.paste(fr, (c * FW, 0))
    img.save(OUT / f"npc_{name}.png")


def glasses(mid, top, col, b):
    y0 = 2 + b
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
    def fn(mid, top, col, b):
        fill(top, X0, 1 + b, X0 + 15, 4 + b, color)
        fill(top, X0 + 2, 0 + b, X0 + 13, 0 + b, color)
        fill(top, X0 + 3, 5 + b, X0 + 12, 5 + b, shade(color, 0.7))
    return fn


def apron(mid, top, col, b):
    t = 15 + b
    fill(mid, 9, t + 1, 14, t + 7, (252, 252, 252, 255))
    fill(mid, 9, t + 7, 14, t + 7, (220, 220, 225, 255))
    fill(top, X0 + 1, 1 + b, X0 + 14, 3 + b, (255, 255, 255, 255))  # kerchief
    fill(top, X0 + 1, 3 + b, X0 + 14, 3 + b, (225, 225, 230, 255))


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
    human_npc("team_leader", outfit(), (52, 62, 112), (70, 70, 76), 0, 0, glasses)
    human_npc("officer_school", outfit(tie=None), (96, 160, 110), (130, 84, 52), 3, 1, glasses)
    human_npc("senior", outfit(tie=(250, 210, 90, 255)), (196, 120, 156), (60, 46, 46), 2, 1)
    human_npc("vendor", outfit(top="jumper", tie=None, pants=((90, 80, 70, 255), (70, 60, 52, 255))),
              (232, 180, 60), (40, 40, 40), 0, 0, cap((60, 110, 190, 255)), skin=(236, 196, 156))
    human_npc("cafeteria", outfit(tie=None), (240, 130, 110), (140, 140, 140), 0, 1, apron)


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
    make_icons()
    make_touch_ui()
    if len(sys.argv) > 1:
        preview(sys.argv[1])
    print("placeholders written to", OUT)
