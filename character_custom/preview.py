"""Composite preview sheets for checking the generated parts."""
import os
import sys
from PIL import Image, ImageDraw
import character_custom.gen_character as G

HERE = os.path.dirname(os.path.abspath(__file__))
PV = os.path.join(HERE, 'previews')
os.makedirs(PV, exist_ok=True)
BG = (120, 150, 110, 255)


def check_templates():
    bad = []
    for v, t in G.HEAD.items():
        for r in t:
            if len(r) != 12:
                bad.append(('head', v, r))
    for n, views in G.HAIRS.items():
        for v, t in views.items():
            for r in t:
                if len(r) != 18:
                    bad.append((n, v, r, len(r)))
    for n, t in G.SIDE_LEGS.items():
        assert len(t) == 5, n
        for r in t:
            if len(r) != 12:
                bad.append(('legs', n, r))
    for d in (G.NEAR_ARM, G.FAR_ARM):
        for n, t in d.items():
            for r in t:
                if len(r) != 12:
                    bad.append(('arm', n, r))
    for b in bad:
        print('BAD', b)
    return not bad


def grid(cells, cols, scale, label_rows=None):
    """cells: list of 32x32 images; returns scaled grid image."""
    rows = (len(cells) + cols - 1) // cols
    cw = G.SZ * scale + 4
    out = Image.new('RGBA', (cols * cw + 4, rows * cw + 4), (40, 40, 48, 255))
    for i, c in enumerate(cells):
        bg = Image.new('RGBA', (G.SZ, G.SZ), BG)
        bg = Image.alpha_composite(bg, c).resize((G.SZ * scale, G.SZ * scale), Image.NEAREST)
        out.paste(bg, (4 + (i % cols) * cw, 4 + (i // cols) * cw))
    return out


def main():
    if not check_templates():
        sys.exit(1)
    frames, imgs = G.main()
    idx = {(f['anim'], f['dir'], f['idx']): i for i, f in enumerate(frames)}
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'

    # all animation frames of one default combo
    def anim_sheet(hair, skin, cloth, fn, scale=6):
        cells = []
        for a, _ in G.ANIMS:
            for d in G.DIRS:
                n = sum(1 for f in frames if f['anim'] == a and f['dir'] == d)
                for k in range(4):
                    if k < n:
                        cells.append(G.compose(imgs, idx[(a, d, k)], hair, skin, cloth))
                    else:
                        cells.append(Image.new('RGBA', (32, 32), (0, 0, 0, 0)))
        grid(cells, 8, scale).save(os.path.join(PV, fn))

    anim_sheet('M_spiky', 'skin_fair', 'M_tee_jeans', 'anim_male.png')
    anim_sheet('F_long', 'skin_light', 'F_dress', 'anim_female.png')

    # every hair x 4 directions (idle frame 0)
    cells = []
    for h in G.HAIRS:
        for d in G.DIRS:
            cells.append(G.compose(imgs, idx[('idle', d, 0)], h, 'skin_fair', None))
    grid(cells, 8, 6).save(os.path.join(PV, 'hairs.png'))

    # every outfit x 4 directions
    cells = []
    for o in G.OUTFITS:
        for d in G.DIRS:
            hair = 'F_bob' if o.startswith('F_') else 'M_sidepart'
            cells.append(G.compose(imgs, idx[('idle', d, 0)], hair, 'skin_fair', o))
    grid(cells, 8, 6).save(os.path.join(PV, 'outfits.png'))

    # skins
    cells = []
    for s in G.SKINS:
        for d in G.DIRS:
            cells.append(G.compose(imgs, idx[('idle', d, 0)], 'M_crop', s, None))
    grid(cells, 8, 6).save(os.path.join(PV, 'skins.png'))
    print('previews written')


if __name__ == '__main__':
    main()
