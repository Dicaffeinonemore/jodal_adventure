"""Animated GIF previews: each combo walking + running in 4 directions."""
import os
from PIL import Image
import character_custom.gen_character as G
HERE = os.path.dirname(os.path.abspath(__file__))
frames, imgs = G.build()
idx = {(f['anim'], f['dir'], f['idx']): i for i, f in enumerate(frames)}
combos = [('M_spiky','skin_fair','M_tee_jeans'), ('M_sidepart','skin_tan','M_hoodie'),
          ('M_crop','skin_dark','U_suit'), ('F_long','skin_light','F_dress'),
          ('F_ponytail','skin_fair','F_blouse_skirt'), ('F_bob','skin_tan','F_adventurer'),
          ('F_long','skin_dark','U_suit'), ('M_spiky','skin_light','M_adventurer')]
S = 4
for anim, ticks in (('walk', 150), ('run', 95)):
    out = []
    for k in range(8):   # 8 ticks = 2 loops of 4 frames
        canvas = Image.new('RGBA', (len(G.DIRS) * 32 * S, len(combos) * 32 * S), (120,150,110,255))
        for r, (h, s, c) in enumerate(combos):
            for col, d in enumerate(G.DIRS):
                im = G.compose(imgs, idx[(anim, d, k % 4)], h, s, c).resize((32*S, 32*S), Image.NEAREST)
                canvas.alpha_composite(im, (col*32*S, r*32*S))
        out.append(canvas.convert('RGB'))
    out[0].save(os.path.join(HERE, 'previews', f'{anim}_all.gif'), save_all=True,
                append_images=out[1:], duration=ticks, loop=0)
print('gifs ok')
