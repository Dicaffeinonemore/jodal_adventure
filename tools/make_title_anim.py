"""Animated title screen from one still picture (tools/ref/opening-screen.png).

    python tools/make_title_anim.py

Cuts the still into layers and writes
  assets/title/*.png         layers: bg (moving parts painted out), bg_blur (fills the
                             edges on screens that are not 16:9), the three characters,
                             title glyphs, "Press Start", the "!" marks, window glass mask
  scripts/ui/title_art.gd    layer positions + animation numbers (generated, do not edit)
  docs/title_anim.gif        a looping preview rendered from the same layers and numbers
Godot cannot play GIFs, so the title screen (scripts/ui/title_screen.gd) plays the same
animation from the layers. The motion formulas live in both places: keep them in sync
(animate() here, _process() there).

Only numpy + Pillow. The indexed silhouette matte beside the source identifies the
three bodies, leaving the paving shadows, shrubs and facade in the still. Text is
selected by "not sky blue". The background behind every moving
part is painted in from the surrounding pixels (onion-peel average); only thin bands of
it ever show, at the edges of a part while it moves.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "ref" / "opening-screen.png"
CHARACTER_MASK = SRC.with_name("title-character-mask.png")
OUT = ROOT / "assets" / "title"
GD = ROOT / "scripts" / "ui" / "title_art.gd"
GIF = ROOT / "docs" / "title_anim.gif"

# ---- animation numbers (written to title_art.gd as well)
PERIOD = 2.4  # seconds; every motion repeats exactly in this time (GIF loop)
GIF_FRAMES = 24
GIF_WIDTH = 960
# name, palette index in the silhouette matte, hop height px, phase 0..1
CHARACTERS = [
    ("narumi", 1, 10.0, 0.0),
    ("rookie", 2, 8.0, 0.33),
    ("dari", 3, 14.0, 0.66),
]
SQUASH = 0.015  # landing squash (scale y 1 - SQUASH, x 1 + SQUASH)
# "!" marks: box, character index they cheer for
MARKS = [((552, 372, 645, 468), 1), ((1070, 518, 1145, 595), 2)]
TITLE_BOX = (12, 2, 950, 175)
TITLE_WAVE = 5.0  # px
TITLE_STAGGER = 0.55  # radians between glyphs
PRESS_BOX = (22, 182, 450, 248)
PRESS_ON = 0.8  # visible for this many seconds of every 1.2
PRESS_CYCLE = 1.2
# window glass: building outline (polygon) x blue pixels, minus the characters
BUILDING = [(445, 292), (1000, 168), (1000, 112), (1540, 4), (1672, 4), (1672, 720), (445, 720)]
LOGO_BOX = (1080, 345, 1180, 430)  # the 조달청 symbol's blue half is not glass
SHINE_ALPHA = 0.9
SHINE_WIDTH = 38.0  # px across the band
SHINE_SLOPE = 0.5  # band runs along x + SHINE_SLOPE * y = const
SHINE_TIME = 0.55  # share of PERIOD the sweep takes; the rest is quiet

N8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def shift(a, dy, dx):
    """a moved by (dy, dx), edges padded with False/0."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def dilate(m, n):
    for _ in range(n):
        m = m | np.logical_or.reduce([shift(m, dy, dx) for dy, dx in N8])
    return m


def erode(m, n):
    return ~dilate(~m, n)


def paint_in(rgb, mask):
    """Fill mask from its edge inward with the mean of known neighbours."""
    ys, xs = np.nonzero(mask)
    y0, y1 = max(ys.min() - 2, 0), min(ys.max() + 3, rgb.shape[0])
    x0, x1 = max(xs.min() - 2, 0), min(xs.max() + 3, rgb.shape[1])
    sub = rgb[y0:y1, x0:x1].astype(np.float32)
    known = ~mask[y0:y1, x0:x1]
    sub[~known] = 0
    while not known.all():
        acc = np.zeros_like(sub)
        cnt = np.zeros(known.shape, np.float32)
        for dy, dx in N8:
            k = shift(known, dy, dx)
            acc += shift(sub * known[..., None], dy, dx)
            cnt += k
        new = ~known & (cnt > 0)
        sub[new] = acc[new] / cnt[new][:, None]
        known |= new
    rgb[y0:y1, x0:x1] = sub.round().astype(np.uint8)


def box_mask(shape, box, sub):
    m = np.zeros(shape, bool)
    x0, y0, x1, y1 = box
    m[y0:y1, x0:x1] = sub
    return m


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    rgb = np.asarray(src).copy()
    H, W = rgb.shape[:2]
    r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
    lum = (r * 299 + g * 587 + b * 114) // 1000
    sky = (b > 170) & (b > r + 55) & (b > g + 10)
    OUT.mkdir(parents=True, exist_ok=True)
    layers = {}  # name -> (RGBA image, (x, y) top-left in the still)

    def save_layer(name, mask, feather=0.7):
        ys, xs = np.nonzero(mask)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        alpha = Image.fromarray((mask[y0:y1, x0:x1] * 255).astype(np.uint8))
        if feather:
            alpha = alpha.filter(ImageFilter.GaussianBlur(feather))
        im = src.crop((x0, y0, x1, y1)).convert("RGBA")
        im.putalpha(alpha)
        im.save(OUT / f"{name}.png", optimize=True)
        layers[name] = (im, (int(x0), int(y0)))
        return x0, y0, x1, y1

    paint = np.zeros((H, W), bool)

    # ---- characters
    chars = []
    with Image.open(CHARACTER_MASK) as mask_image:
        if mask_image.mode != "P" or mask_image.size != src.size:
            raise ValueError("Character mask must be indexed and match the source size")
        matte = np.array(mask_image)
    for name, index, amp, phase in CHARACTERS:
        m = matte == index
        bx0, by0, bx1, by1 = save_layer(name, m, feather=0)
        chars.append({"name": name, "foot": ((bx0 + bx1) / 2.0, float(by1)), "amp": amp, "phase": phase})
        paint |= dilate(m, 1)

    # ---- "!" marks: yellow strokes and the dark outline hugging them
    marks = []
    for box, owner in MARKS:
        x0, y0, x1, y1 = box
        yellow = (r > 200) & (g > 160) & (b < 120)
        sub = yellow[y0:y1, x0:x1]
        sub = (sub | (lum[y0:y1, x0:x1] < 90)) & dilate(sub, 5)
        m = box_mask((H, W), box, sub)
        name = f"mark_{len(marks)}"
        bx0, by0, bx1, by1 = save_layer(name, m)
        marks.append({"name": name, "center": ((bx0 + bx1) / 2.0, (by0 + by1) / 2.0), "owner": owner})
        paint |= dilate(m, 2)

    # ---- title glyphs: split at empty columns
    x0, y0, x1, y1 = TITLE_BOX
    tmask = dilate(~sky[y0:y1, x0:x1], 1)
    cols = tmask.any(axis=0)
    glyphs = []
    x = 0
    while x < cols.size:
        if not cols[x]:
            x += 1
            continue
        start = x
        while x < cols.size and cols[x]:
            x += 1
        sub = np.zeros_like(tmask)
        sub[:, start:x] = tmask[:, start:x]
        if sub.sum() < 200:
            continue
        name = f"title_{len(glyphs)}"
        m = box_mask((H, W), TITLE_BOX, sub)
        save_layer(name, m, 0.5)
        glyphs.append(name)
        paint |= dilate(m, 2)

    # ---- Press Start
    x0, y0, x1, y1 = PRESS_BOX
    m = box_mask((H, W), PRESS_BOX, dilate(~sky[y0:y1, x0:x1], 1))
    save_layer("press", m, 0.5)
    paint |= dilate(m, 2)

    # ---- window glass (alpha mask only; the shine is drawn on it)
    poly = Image.new("L", (W, H), 0)
    ImageDraw.Draw(poly).polygon(BUILDING, fill=255)
    char_area = matte != 0
    # The stone posts are lavender in shadow. Only the cyan-blue glazing reflects.
    glass = (np.asarray(poly) > 0) & (b > 150) & (b > r + 40) & (g > r + 28) & ~dilate(char_area, 6)
    lx0, ly0, lx1, ly1 = LOGO_BOX
    glass[ly0:ly1, lx0:lx1] = False
    glass = erode(dilate(glass, 1), 1)
    ys, xs = np.nonzero(glass)
    gx0, gy0, gx1, gy1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    gim = Image.new("RGBA", (gx1 - gx0, gy1 - gy0), (255, 255, 255, 0))
    gim.putalpha(Image.fromarray((glass[gy0:gy1, gx0:gx1] * 255).astype(np.uint8)))
    gim.save(OUT / "glass.png", optimize=True)
    glass_pos = (int(gx0), int(gy0))

    # ---- background with every moving part painted out
    bg = rgb.copy()
    paint_in(bg, paint)
    bg_im = Image.fromarray(bg)
    bg_im.save(OUT / "bg.png", optimize=True)
    blur = src.resize((W // 8, H // 8), Image.BILINEAR).filter(ImageFilter.GaussianBlur(3))
    blur = Image.eval(blur, lambda v: int(v * 0.75))
    blur.save(OUT / "bg_blur.png", optimize=True)

    write_gd(W, H, layers, chars, marks, glyphs, glass_pos, gim.size)
    write_gif(bg_im, layers, chars, marks, glyphs, gim, glass_pos)
    print(f"layers: {len(layers)} + glass, glyphs: {len(glyphs)}, painted px: {int(paint.sum())}")


# ---- animation, mirrored in title_screen.gd _process()
def hop(t, phase):
    """0 on the ground .. 1 at the top, two hops per PERIOD."""
    return abs(math.sin(math.pi * (2.0 * t / PERIOD + phase)))


def animate(t):
    """Per-layer state at time t (seconds)."""
    state = {"chars": [], "glyph_y": [], "marks": []}
    for _name, _index, amp, phase in CHARACTERS:
        h = hop(t, phase)
        squash = SQUASH * (1.0 - h) ** 4
        state["chars"].append((-amp * h, 1.0 + squash, 1.0 - squash))
    for k in range(64):
        state["glyph_y"].append(-TITLE_WAVE * math.sin(2.0 * math.pi * t / PERIOD - k * TITLE_STAGGER))
    for _box, owner in MARKS:
        state["marks"].append(1.0 + 0.25 * hop(t, CHARACTERS[owner][3]))
    state["press"] = (t % PRESS_CYCLE) < PRESS_ON
    state["shine"] = (t % PERIOD) / (PERIOD * SHINE_TIME)  # 0..1 while sweeping, >1 quiet
    return state


def shine_band(p, gw, gh):
    """Band centre (in x + SLOPE * y of the glass layer) for sweep progress p."""
    return -SHINE_WIDTH * 2 + p * (gw + SHINE_SLOPE * gh + SHINE_WIDTH * 4)


def write_gif(bg, layers, chars, marks, glyphs, glass, glass_pos):
    W, H = bg.size
    ga = np.asarray(glass)[..., 3].astype(np.float32) / 255.0
    gh, gw = ga.shape
    yy, xx = np.mgrid[0:gh, 0:gw].astype(np.float32)
    frames = []
    for f in range(GIF_FRAMES):
        t = f * PERIOD / GIF_FRAMES
        s = animate(t)
        im = bg.copy().convert("RGBA")
        if s["shine"] <= 1.0:
            d = (xx + SHINE_SLOPE * yy - shine_band(s["shine"], gw, gh)) / SHINE_WIDTH
            a = ga * SHINE_ALPHA * np.exp(-d * d)
            sh = Image.new("RGBA", (gw, gh), (255, 255, 255, 0))
            sh.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
            im.alpha_composite(sh, glass_pos)
        for c, (dy, sx, sy) in zip(chars, s["chars"]):
            lay, _ = layers[c["name"]]
            w, h = lay.size
            sw, shh = max(1, round(w * sx)), max(1, round(h * sy))
            scaled = lay.resize((sw, shh), Image.BILINEAR)
            fx, fy = c["foot"]
            im.alpha_composite(scaled, (round(fx - sw / 2), round(fy - shh + dy)))
        for m, sc in zip(marks, s["marks"]):
            lay, _ = layers[m["name"]]
            w, h = lay.size
            sw, shh = round(w * sc), round(h * sc)
            cx, cy = m["center"]
            im.alpha_composite(lay.resize((sw, shh), Image.BILINEAR), (round(cx - sw / 2), round(cy - shh / 2)))
        for k, name in enumerate(glyphs):
            lay, (ox, oy) = layers[name]
            im.alpha_composite(lay, (ox, round(oy + s["glyph_y"][k])))
        if s["press"]:
            lay, pos = layers["press"]
            im.alpha_composite(lay, pos)
        frames.append(im.convert("RGB").resize((GIF_WIDTH, round(H * GIF_WIDTH / W)), Image.LANCZOS))
    pal = frames[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [fr.quantize(palette=pal, dither=Image.Dither.NONE) for fr in frames]
    GIF.parent.mkdir(parents=True, exist_ok=True)
    q[0].save(GIF, save_all=True, append_images=q[1:], duration=round(PERIOD * 1000 / GIF_FRAMES),
              loop=0, optimize=False, disposal=1)


def vec(p):
    return f"Vector2({p[0]:g}, {p[1]:g})"


def write_gd(W, H, layers, chars, marks, glyphs, glass_pos, glass_size):
    lines = [
        "## Generated by tools/make_title_anim.py from tools/ref/opening-screen.png. Do not edit:",
        "## change the numbers in the tool and run it again. Positions are pixels of the still.",
        "",
        f"const SIZE := {vec((W, H))}",
        f"const PERIOD := {PERIOD}",
        f"const SQUASH := {SQUASH}",
        f"const TITLE_WAVE := {TITLE_WAVE}",
        f"const TITLE_STAGGER := {TITLE_STAGGER}",
        f"const PRESS_ON := {PRESS_ON}",
        f"const PRESS_CYCLE := {PRESS_CYCLE}",
        f"const SHINE_ALPHA := {SHINE_ALPHA}",
        f"const SHINE_WIDTH := {SHINE_WIDTH}",
        f"const SHINE_SLOPE := {SHINE_SLOPE}",
        f"const SHINE_TIME := {SHINE_TIME}",
        "## file, feet (bottom centre), hop height, phase",
        "const CHARACTERS := [",
    ]
    for c in chars:
        lines.append(f'\t{{"file": "{c["name"]}", "foot": {vec(c["foot"])}, "amp": {c["amp"]}, "phase": {c["phase"]}}},')
    lines += ["]", "## file, centre, index into CHARACTERS it cheers for", "const MARKS := ["]
    for m in marks:
        lines.append(f'\t{{"file": "{m["name"]}", "center": {vec(m["center"])}, "owner": {m["owner"]}}},')
    lines += ["]", "## file, top-left (one per title glyph, left to right)", "const GLYPHS := ["]
    for name in glyphs:
        lines.append(f'\t{{"file": "{name}", "pos": {vec(layers[name][1])}}},')
    lines += [
        "]",
        f'const PRESS := {{"file": "press", "pos": {vec(layers["press"][1])}}}',
        f'const GLASS := {{"file": "glass", "pos": {vec(glass_pos)}, "size": {vec(glass_size)}}}',
        "",
    ]
    GD.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
