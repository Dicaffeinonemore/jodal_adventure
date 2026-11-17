"""Generate placeholder pixel art for the prototype.

Run from the project root:  python3 tools/gen_placeholders.py
Everything lands in assets/sprites/placeholder/. Replace these files with real art
later, keeping the same file names and frame layout, and the game picks them up.

Frame layout of character sheets (24x32 px per frame):
  rows: 0 = down, 1 = up, 2 = side (facing right; left is drawn flipped)
  cols: 0..3 walk cycle (col 0 doubles as the idle frame)
Player sheets are split into layers that the game tints at runtime:
  player_base.png (skin, face, legs) / player_outfit.png (light gray -> tinted)
  player_hair_0.png, player_hair_1.png (light gray -> tinted)
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "placeholder"
OUT.mkdir(parents=True, exist_ok=True)

FW, FH = 24, 32
T = (0, 0, 0, 0)
OUTLINE = (40, 32, 40, 255)
SKIN = (255, 214, 170, 255)
SKIN_D = (226, 170, 130, 255)
PANTS = (60, 66, 90, 255)
SHOE = (35, 35, 45, 255)
EYE = (30, 30, 40, 255)
G1 = (250, 250, 250, 255)  # tint-able light
G2 = (205, 205, 210, 255)  # tint-able shade
G3 = (150, 150, 160, 255)  # tint-able dark

LEG_OFFSETS = [(0, 0), (-1, 1), (0, 0), (1, -1)]  # (left leg dy, right leg dy) per frame


def sheet(rows=3, cols=4):
    return Image.new("RGBA", (FW * cols, FH * rows), T)


def rect(d, x0, y0, x1, y1, fill, outline=None):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def bob(col):
    return 1 if col in (1, 3) else 0


def draw_base(d, ox, oy, row, col):
    b = bob(col)
    ll, rl = LEG_OFFSETS[col]
    # legs
    if row == 2:
        rect(d, ox + 10, oy + 24 + min(ll, 0), ox + 12, oy + 29 + ll, PANTS)
        rect(d, ox + 12, oy + 24 + min(rl, 0), ox + 14, oy + 29 + rl, PANTS)
        rect(d, ox + 10, oy + 29 + ll, ox + 13, oy + 30 + ll, SHOE)
        rect(d, ox + 12, oy + 29 + rl, ox + 15, oy + 30 + rl, SHOE)
    else:
        rect(d, ox + 8, oy + 24, ox + 11, oy + 29 + ll, PANTS)
        rect(d, ox + 13, oy + 24, ox + 16, oy + 29 + rl, PANTS)
        rect(d, ox + 8, oy + 29 + ll, ox + 11, oy + 30 + ll, SHOE)
        rect(d, ox + 13, oy + 29 + rl, ox + 16, oy + 30 + rl, SHOE)
    # head
    rect(d, ox + 5, oy + 3 + b, ox + 18, oy + 15 + b, SKIN, OUTLINE)
    if row == 0:
        rect(d, ox + 8, oy + 10 + b, ox + 9, oy + 12 + b, EYE)
        rect(d, ox + 14, oy + 10 + b, ox + 15, oy + 12 + b, EYE)
        rect(d, ox + 6, oy + 13 + b, ox + 7, oy + 13 + b, (255, 170, 160, 255))
        rect(d, ox + 16, oy + 13 + b, ox + 17, oy + 13 + b, (255, 170, 160, 255))
    elif row == 2:
        rect(d, ox + 15, oy + 10 + b, ox + 16, oy + 12 + b, EYE)
    # hands
    rect(d, ox + 4, oy + 21 + b, ox + 5, oy + 22 + b, SKIN_D)
    rect(d, ox + 18, oy + 21 + b, ox + 19, oy + 22 + b, SKIN_D)


def draw_outfit(d, ox, oy, row, col):
    b = bob(col)
    rect(d, ox + 6, oy + 16 + b, ox + 17, oy + 24 + b, G1, OUTLINE)
    rect(d, ox + 4, oy + 16 + b, ox + 6, oy + 21 + b, G2, OUTLINE)
    rect(d, ox + 17, oy + 16 + b, ox + 19, oy + 21 + b, G2, OUTLINE)
    if row == 0:
        rect(d, ox + 11, oy + 16 + b, ox + 12, oy + 20 + b, G3)  # tie / zipper line
    rect(d, ox + 6, oy + 23 + b, ox + 17, oy + 24 + b, G3)


def draw_hair(d, ox, oy, row, col, style):
    b = bob(col)
    if row == 1:  # back of head fully covered
        rect(d, ox + 5, oy + 2 + b, ox + 18, oy + 14 + b, G1, OUTLINE)
        rect(d, ox + 6, oy + 11 + b, ox + 17, oy + 14 + b, G2)
    else:
        rect(d, ox + 5, oy + 2 + b, ox + 18, oy + 7 + b, G1, OUTLINE)
        if row == 0:
            rect(d, ox + 5, oy + 7 + b, ox + 6, oy + 11 + b, G2)
            rect(d, ox + 17, oy + 7 + b, ox + 18, oy + 11 + b, G2)
        else:
            rect(d, ox + 5, oy + 7 + b, ox + 10, oy + 11 + b, G2)
    if style == 1:  # long hair / ponytail
        if row == 0:
            rect(d, ox + 4, oy + 7 + b, ox + 6, oy + 18 + b, G2, OUTLINE)
            rect(d, ox + 17, oy + 7 + b, ox + 19, oy + 18 + b, G2, OUTLINE)
        elif row == 1:
            rect(d, ox + 8, oy + 13 + b, ox + 15, oy + 20 + b, G2, OUTLINE)
        else:
            rect(d, ox + 2, oy + 6 + b, ox + 6, oy + 17 + b, G2, OUTLINE)


def make_player():
    layers = {
        "player_base.png": lambda d, ox, oy, r, c: draw_base(d, ox, oy, r, c),
        "player_outfit.png": lambda d, ox, oy, r, c: draw_outfit(d, ox, oy, r, c),
        "player_hair_0.png": lambda d, ox, oy, r, c: draw_hair(d, ox, oy, r, c, 0),
        "player_hair_1.png": lambda d, ox, oy, r, c: draw_hair(d, ox, oy, r, c, 1),
    }
    for name, fn in layers.items():
        img = sheet()
        d = ImageDraw.Draw(img)
        for r in range(3):
            for c in range(4):
                fn(d, c * FW, r * FH, r, c)
        img.save(OUT / name)


def npc_sheet(name, draw_fn):
    """NPC placeholder: 1 row (down), 2 idle frames."""
    img = sheet(rows=1, cols=2)
    d = ImageDraw.Draw(img)
    for c in range(2):
        draw_fn(d, c * FW, 0, c)
    img.save(OUT / f"npc_{name}.png")


def human(shirt, hair, pants=PANTS, extra=None):
    def fn(d, ox, oy, c):
        b = c
        rect(d, ox + 8, oy + 24, ox + 11, oy + 29, pants)
        rect(d, ox + 13, oy + 24, ox + 16, oy + 29, pants)
        rect(d, ox + 8, oy + 29, ox + 11, oy + 30, SHOE)
        rect(d, ox + 13, oy + 29, ox + 16, oy + 30, SHOE)
        rect(d, ox + 6, oy + 16 + b, ox + 17, oy + 24, shirt, OUTLINE)
        rect(d, ox + 4, oy + 16 + b, ox + 6, oy + 21 + b, shirt, OUTLINE)
        rect(d, ox + 17, oy + 16 + b, ox + 19, oy + 21 + b, shirt, OUTLINE)
        rect(d, ox + 5, oy + 3 + b, ox + 18, oy + 15 + b, SKIN, OUTLINE)
        rect(d, ox + 5, oy + 2 + b, ox + 18, oy + 6 + b, hair, OUTLINE)
        rect(d, ox + 8, oy + 10 + b, ox + 9, oy + 12 + b, EYE)
        rect(d, ox + 14, oy + 10 + b, ox + 15, oy + 12 + b, EYE)
        if extra:
            extra(d, ox, oy, b)
    return fn


def stork(d, ox, oy, c):  # Narumi placeholder: white stork
    b = c
    rect(d, ox + 9, oy + 22, ox + 10, oy + 30, (230, 120, 60, 255))
    rect(d, ox + 13, oy + 22, ox + 14, oy + 30, (230, 120, 60, 255))
    rect(d, ox + 5, oy + 12 + b, ox + 18, oy + 24, (250, 250, 250, 255), OUTLINE)
    rect(d, ox + 3, oy + 15 + b, ox + 6, oy + 22, (40, 40, 50, 255))
    rect(d, ox + 17, oy + 15 + b, ox + 20, oy + 22, (40, 40, 50, 255))
    rect(d, ox + 7, oy + 2 + b, ox + 16, oy + 12 + b, (250, 250, 250, 255), OUTLINE)
    rect(d, ox + 9, oy + 6 + b, ox + 10, oy + 7 + b, EYE)
    rect(d, ox + 13, oy + 6 + b, ox + 14, oy + 7 + b, EYE)
    rect(d, ox + 10, oy + 9 + b, ox + 13, oy + 14 + b, (240, 150, 50, 255), OUTLINE)


def squirrel(d, ox, oy, c):  # Dari placeholder: brown squirrel with big tail
    b = c
    brown, light = (190, 120, 60, 255), (240, 205, 160, 255)
    rect(d, ox + 15, oy + 8 + b, ox + 22, oy + 26, brown, OUTLINE)
    rect(d, ox + 6, oy + 16 + b, ox + 16, oy + 28, brown, OUTLINE)
    rect(d, ox + 8, oy + 18 + b, ox + 13, oy + 26, light)
    rect(d, ox + 4, oy + 5 + b, ox + 16, oy + 16 + b, brown, OUTLINE)
    rect(d, ox + 4, oy + 2 + b, ox + 6, oy + 5 + b, brown, OUTLINE)
    rect(d, ox + 14, oy + 2 + b, ox + 16, oy + 5 + b, brown, OUTLINE)
    rect(d, ox + 7, oy + 9 + b, ox + 8, oy + 10 + b, EYE)
    rect(d, ox + 12, oy + 9 + b, ox + 13, oy + 10 + b, EYE)
    rect(d, ox + 9, oy + 12 + b, ox + 11, oy + 13 + b, light)


def apron(d, ox, oy, b):
    rect(d, ox + 8, oy + 18 + b, ox + 15, oy + 24, (250, 250, 250, 255))


def make_npcs():
    npc_sheet("narumi", stork)
    npc_sheet("dari", squirrel)
    npc_sheet("team_leader", human((50, 60, 110, 255), (60, 60, 60, 255)))
    npc_sheet("officer_school", human((90, 150, 100, 255), (90, 60, 40, 255)))
    npc_sheet("senior", human((170, 110, 140, 255), (40, 30, 30, 255)))
    npc_sheet("vendor", human((200, 160, 70, 255), (30, 30, 30, 255), (110, 90, 70, 255)))
    npc_sheet("cafeteria", human((240, 120, 100, 255), (200, 200, 200, 255), extra=apron))


# --- tiles: one row of 16x16 tiles; index order must match scripts/world/tiles.gd ---
TILE_COLORS = [
    ("floor", (232, 222, 200)),
    ("wall", (90, 96, 120)),
    ("desk", (150, 105, 70)),
    ("carpet", (150, 165, 190)),
    ("plant", (232, 222, 200)),
    ("counter", (200, 190, 175)),
    ("asphalt", (85, 85, 92)),
    ("parking_line", (85, 85, 92)),
    ("grass", (110, 170, 90)),
    ("entrance", (200, 70, 70)),
    ("window_wall", (90, 96, 120)),
    ("wood_floor", (205, 160, 110)),
    ("pc_desk", (150, 105, 70)),
    ("vending", (60, 120, 200)),
    ("board", (90, 96, 120)),
    ("mirror", (90, 96, 120)),
    ("ticket_machine", (200, 190, 175)),
]


def make_tiles():
    n = len(TILE_COLORS)
    img = Image.new("RGBA", (16 * n, 16), T)
    d = ImageDraw.Draw(img)
    for i, (name, col) in enumerate(TILE_COLORS):
        x = i * 16
        c = col + (255,)
        rect(d, x, 0, x + 15, 15, c)
        dark = tuple(max(0, v - 30) for v in col) + (255,)
        if name in ("floor", "wood_floor"):
            d.line([x, 15, x + 15, 15], fill=dark)
            d.line([x + 15, 0, x + 15, 15], fill=dark)
        elif name in ("wall", "window_wall", "board", "mirror"):
            rect(d, x, 11, x + 15, 15, dark)
            if name == "window_wall":
                rect(d, x + 3, 2, x + 12, 8, (170, 210, 240, 255), OUTLINE)
            if name == "board":
                rect(d, x + 2, 2, x + 13, 9, (120, 90, 60, 255), OUTLINE)
                rect(d, x + 4, 4, x + 7, 6, (250, 250, 230, 255))
            if name == "mirror":
                rect(d, x + 4, 1, x + 11, 10, (200, 230, 245, 255), OUTLINE)
        elif name in ("desk", "pc_desk", "counter", "ticket_machine"):
            rect(d, x, 0, x + 15, 11, c, OUTLINE)
            rect(d, x, 12, x + 15, 15, dark)
            if name == "pc_desk":
                rect(d, x + 4, 1, x + 11, 7, (40, 40, 50, 255))
                rect(d, x + 5, 2, x + 10, 6, (120, 200, 255, 255))
            if name == "ticket_machine":
                rect(d, x + 3, 0, x + 12, 13, (230, 80, 70, 255), OUTLINE)
                rect(d, x + 5, 2, x + 10, 5, (250, 250, 230, 255))
        elif name == "plant":
            rect(d, x + 5, 9, x + 10, 14, (170, 100, 60, 255), OUTLINE)
            d.ellipse([x + 2, 1, x + 13, 10], fill=(70, 150, 70, 255), outline=OUTLINE)
        elif name == "parking_line":
            rect(d, x + 7, 0, x + 8, 15, (240, 240, 240, 255))
        elif name == "grass":
            for gx, gy in ((3, 4), (10, 9), (6, 12)):
                d.point((x + gx, gy), fill=(80, 140, 70, 255))
        elif name == "entrance":
            rect(d, x + 1, 1, x + 14, 14, (220, 100, 90, 255))
        elif name == "vending":
            rect(d, x + 1, 0, x + 14, 15, c, OUTLINE)
            rect(d, x + 3, 2, x + 9, 10, (220, 240, 255, 255))
            rect(d, x + 11, 4, x + 12, 8, (250, 220, 80, 255))
    img.save(OUT / "tiles.png")


def make_drive():
    car = Image.new("RGBA", (16, 28), T)
    d = ImageDraw.Draw(car)
    rect(d, 1, 0, 14, 27, (60, 110, 200, 255), OUTLINE)
    rect(d, 3, 3, 12, 8, (180, 220, 250, 255))
    rect(d, 2, 10, 13, 25, (240, 240, 240, 255), OUTLINE)  # cargo box
    car.save(OUT / "car_player.png")
    npc = Image.new("RGBA", (16, 28), T)
    d = ImageDraw.Draw(npc)
    rect(d, 1, 0, 14, 27, (200, 70, 60, 255), OUTLINE)
    rect(d, 3, 19, 12, 24, (180, 220, 250, 255))
    npc.save(OUT / "car_npc.png")
    cone = Image.new("RGBA", (12, 12), T)
    d = ImageDraw.Draw(cone)
    d.polygon([(6, 0), (11, 11), (0, 11)], fill=(250, 140, 40, 255), outline=OUTLINE)
    rect(d, 3, 6, 8, 7, (250, 250, 250, 255))
    cone.save(OUT / "cone.png")
    bump = Image.new("RGBA", (40, 6), T)
    d = ImageDraw.Draw(bump)
    rect(d, 0, 0, 39, 5, (240, 200, 40, 255), OUTLINE)
    for i in range(0, 40, 8):
        rect(d, i + 1, 1, i + 4, 4, (40, 40, 40, 255))
    bump.save(OUT / "speed_bump.png")


def make_icons():
    icons = {
        "item_gukbap.png": lambda d: (d.ellipse([1, 5, 14, 14], fill=(240, 240, 240, 255), outline=OUTLINE),
                                      d.ellipse([3, 6, 12, 10], fill=(200, 80, 50, 255))),
        "item_coffee.png": lambda d: (rect(d, 4, 4, 11, 14, (250, 250, 250, 255), OUTLINE),
                                      rect(d, 4, 7, 11, 10, (120, 80, 50, 255)),
                                      rect(d, 5, 1, 6, 3, (200, 200, 200, 255))),
        "item_meal.png": lambda d: (rect(d, 1, 4, 14, 13, (180, 190, 200, 255), OUTLINE),
                                    rect(d, 3, 6, 6, 9, (250, 250, 240, 255)),
                                    rect(d, 8, 6, 12, 9, (230, 120, 60, 255)),
                                    rect(d, 3, 10, 12, 11, (110, 170, 90, 255))),
        "item_energybar.png": lambda d: (rect(d, 2, 6, 13, 10, (240, 200, 60, 255), OUTLINE),
                                         rect(d, 5, 7, 10, 9, (200, 80, 50, 255))),
    }
    for name, fn in icons.items():
        img = Image.new("RGBA", (16, 16), T)
        fn(ImageDraw.Draw(img))
        img.save(OUT / name)


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


if __name__ == "__main__":
    make_player()
    make_npcs()
    make_tiles()
    make_drive()
    make_icons()
    make_touch_ui()
    print("placeholders written to", OUT)
