"""Patch that hides "Press Start" in the opening picture (assets/title/opening.png).

    python tools/make_title_cover.py

The words sit on plain sky. Every column of BOX is repainted by blending the sky just
above and just below it, and the result is saved as assets/title/opening_press_cover.png.
title_screen.gd fades the patch in at BOX's corner (PRESS_COVER_POS) once the player
starts, so the drawn "Press Start" disappears. Run again if opening.png changes
(and update PRESS_COVER_POS when BOX moves).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "title" / "opening.png"
OUT = ROOT / "assets" / "title" / "opening_press_cover.png"
BOX = (14, 174, 458, 252)  # x0, y0, x1, y1 (exclusive) around the words and their outline
SAMPLE = 3  # rows of sky averaged above and below
SPREAD = 2  # columns averaged on each side


def main() -> None:
    a = np.array(Image.open(SRC).convert("RGB")).astype(np.float32)
    x0, y0, x1, y1 = BOX
    top = a[y0 - SAMPLE:y0].mean(axis=0)  # (w, 3)
    bottom = a[y1:y1 + SAMPLE].mean(axis=0)
    w = a.shape[1]
    smooth_top = np.stack([top[max(0, x - SPREAD):min(w, x + SPREAD + 1)].mean(axis=0) for x in range(w)])
    smooth_bottom = np.stack([bottom[max(0, x - SPREAD):min(w, x + SPREAD + 1)].mean(axis=0) for x in range(w)])
    h = y1 - y0
    t = (np.arange(h, dtype=np.float32) + 0.5) / h
    patch = (smooth_top[None, x0:x1] * (1 - t)[:, None, None] + smooth_bottom[None, x0:x1] * t[:, None, None])
    Image.fromarray(np.clip(patch + 0.5, 0, 255).astype(np.uint8), "RGB").save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} {x1 - x0}x{h} at ({x0}, {y0})")


if __name__ == "__main__":
    main()
