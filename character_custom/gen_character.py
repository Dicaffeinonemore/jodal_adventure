"""
Chibi character customization model generator (32x32, head:body = 2:1).

Builds every customization layer for every animation frame from small
pixel templates, so all parts stay aligned frame by frame:
  hair_back/*  (hair parts that sit behind the body)
  skin/*       (base body + face, one layer per skin tone)
  clothes/*    (outfits; M_ = male list, F_ = female list, U_ = both)
  hair/*       (hair parts in front)

Outputs
  strips/<group>__<layer>.png  one 32px-tall strip per layer (all frames)
  frames.json                  frame / tag table used by build_aseprite.lua
  sheets/*.png + sheets.json   game-ready grid sheets (rows = anim x dir)
  previews/*.png               composited previews
"""
import json
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SZ = 32


def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


OUT = hx('2a1f2d')          # single outline colour for everything
EYE = OUT
IRIS = hx('4a5f9a')
EYE_WHITE = hx('ffffff')

SKINS = {   # base, shadow, mouth
    'skin_light': ('ffe3cc', 'f0bc9c', 'd98a7a'),
    'skin_fair':  ('f5c7a0', 'dc9c74', 'c0705e'),
    'skin_tan':   ('d49b66', 'b07544', '8e4c36'),
    'skin_dark':  ('8e5b3c', '6c4128', '4a2818'),
}
UNDER_TOP = ('dcdce4', 'b4b4c4')
UNDER_BOT = ('5a6a8a', '46536e')
HAIR = {'l': hx('c08a55'), 'h': hx('8a5530'), 'd': hx('5c361e'), 'r': hx('d94048')}

# ---------------------------------------------------------------- templates
# Head interior 12x14 placed at (10, 8); outline is generated around it.
HEAD = {
    'front': [
        "..ssssssss..",
        ".ssssssssss.",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "sssssssssssd",
        "sseesssseesd",
        "sswesssswesd",
        "ssiissssiisd",
        "sssssmmssssd",
        ".sssssssssd.",
        "..ssssssss..",
    ],
    'back': [
        "..ssssssss..",
        ".ssssssssss.",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "sssssssssssd",
        "sssssssssssd",
        "sssssssssssd",
        "sssssssssssd",
        "sssssssssssd",
        ".sssssssssd.",
        "..ssssssss..",
    ],
    'side': [   # facing right
        "..ssssssss..",
        ".ssssssssss.",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "ssssssssssss",
        "sssssksseess",
        "sssskksswess",
        "ssssssssiiss",
        "ssssssssssms",
        ".ssssssssss.",
        "..ssssssss..",
    ],
}
HEAD_X, HEAD_Y = 10, 8

# Hair templates: 18 wide, origin (7, 4). lowercase = front layer,
# UPPERCASE = back layer (drawn behind the body). Outline is generated.
HAIR_X, HAIR_Y = 7, 4
HAIRS = {
    # ------------------------------------------------------------ male
    'M_spiky': {
        'front': [
            "......h....h......",
            "..h...hh..hh...h..",
            "..hh.hhhhhhhh.hh..",
            "..hhhhllhhhhhhhh..",
            ".hhhlllhhhhhhhhhd.",
            ".hhllhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            "..hhhhhhhhhhhhdd..",
            "..hhhdhhhhdhhhhd..",
            "..hh.hhd.hhhd.hd..",
            "..h.....h......h..",
            "..h............h..",
            "..h............d..",
        ],
        'back': [
            "......h....h......",
            "..h...hh..hh...h..",
            "..hh.hhhhhhhh.hh..",
            "..hhhhllhhhhhhhh..",
            ".hhhlllhhhhhhhhhd.",
            ".hhllhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            "..hhhhhhhhhhhhdd..",
            "..hhhhhhhhhhhhhd..",
            "..hhdhhhhdhhhhdd..",
            "...hh.hhhhh.hhd...",
            "....h...hh...h....",
        ],
        'side': [
            "....h....h........",
            "..h.hh..hh..h.....",
            "..hhhhhhhhhhhh....",
            ".hhhhllhhhhhhhh...",
            "hhhhlllhhhhhhhhh..",
            ".hhhllhhhhhhhhhd..",
            "hhhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhdd..",
            ".hhhhhhhhhhhhhd...",
            "..hhhhhhhhhhhd.d..",
            "..hhhhhhhh.h......",
            "..hhhhh...........",
            "..hhhhh...........",
            "..hhhhd...........",
            "...hhd............",
            "....h.............",
        ],
    },
    'M_sidepart': {
        'front': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhhh.hhhhhhh...",
            "..hhll.hhhhhhhhd..",
            "..hll.hhhhhhhhhd..",
            "..hhhhhhhhhhhhdd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..h.....hhhhhhhd..",
            "..h.......hhhhhd..",
            "..h............h..",
            "..h............d..",
        ],
        'back': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhllhhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhdd..",
            "...hhhhhhhhhhhd...",
            "....dddddddddd....",
        ],
        'side': [
            "..................",
            ".....hhhhhh.......",
            "...hhhhhhhhhh.....",
            "..hhllhhhhhhhh....",
            ".hhllhhhhhhhhhh...",
            ".hhhhhhhhhhhhhhh..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhd...",
            ".hhhhhhh..hhhd....",
            ".hhhhhh....hd.....",
            "..hhhhh...........",
            "..hhhhh...........",
            "..hhhhd...........",
            "...hhd............",
        ],
    },
    'M_crop': {
        'front': [
            "..................",
            "..................",
            ".....hhhhhhhh.....",
            "...hhhhhhhhhhhh...",
            "..hllhhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhdd..",
            "..hdhhdhhdhhdhdd..",
            "..h............d..",
        ],
        'back': [
            "..................",
            "..................",
            ".....hhhhhhhh.....",
            "...hhhhhhhhhhhh...",
            "..hllhhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhdd..",
            "...hhhhhhhhhhhd...",
            "....dddddddddd....",
        ],
        'side': [
            "..................",
            "..................",
            "....hhhhhhhh......",
            "..hhhhhhhhhhhh....",
            ".hllhhhhhhhhhhh...",
            ".hlhhhhhhhhhhhhh..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhd...",
            ".hhhhhhhhhhhhd....",
            ".hhhhhhh..........",
            ".hhhhhh...........",
            "..hhhhh...........",
            "..hhhhd...........",
            "...hhd............",
        ],
    },
    # ---------------------------------------------------------- female
    'F_long': {
        'front': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhhllhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhdhhhhdhhhhdd.",
            ".hhhd.hhhd.hhhhdd.",
            "Dhh............hdD",
            "Dhh............hdD",
            "Dhh............hdD",
            "Dhh............hdD",
            "Dhh............hdD",
            "Dhd............ddD",
            "DDD............DDD",
            "DDDDDDDDDDDDDDDDDD",
            "DDDDDDDDDDDDDDDDDD",
            "DHDDDDDDDDDDDDDHDD",
            ".D..............D.",
        ],
        'back': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhllhhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhdhhhhhhhdd.",
            ".hhhhhhdhhhhhhhdd.",
            ".hhhhhhdhhhhhhhdd.",
            ".hhhhhhdhhhhhhhdd.",
            ".hhhhhhdhhhhhhhdd.",
            ".hhhhhhdhhhhhhhdd.",
            "..hhhhhdhhhhhhdd..",
            "..hhhhhdhhhhhhdd..",
            "....hhhdhhhhdd....",
            "......hdhhhd......",
            "......h.h.hd......",
        ],
        'side': [
            "..................",
            ".....hhhhhh.......",
            "...hhhhhhhhhh.....",
            "..hhllhhhhhhhh....",
            ".hhllhhhhhhhhhh...",
            ".hlhhhhhhhhhhhhh..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhdhhhd..",
            ".hhhhhhhhh..hd.d..",
            ".hhhhhhhh.........",
            ".hhhhhhhh.........",
            ".hhhhhhhd.........",
            ".hhhhhhhd.........",
            ".hhhhhhd..........",
            ".hhhhhhd..........",
            ".hhhhhhd..........",
            ".hhhhhd...........",
            ".hhhhhd...........",
            ".hdhhd............",
            "..h.h.............",
        ],
    },
    'F_ponytail': {
        'front': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhhllhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhdH.",
            "..hhhhhhhhhhhhhdHD",
            "..hhhhhhhhhhhhhdHD",
            "..hhhdhhhhhhdhhdHD",
            "..hh.hhd..hhd.hdHD",
            "..h............hHD",
            "..h............dHD",
            "................HD",
            "................HD",
            "................DD",
            "................D.",
        ],
        'back': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhllhhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            "..hlhhhhhhhhhhhd..",
            "..hhhhhrrrrhhhhd..",
            "..hhhhhrrrrhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhhd..",
            "..hhhhhhhhhhhhdd..",
            "...hhhhhhhhhhhd...",
            "....hhhhhhhhdd....",
            ".......hhhd.......",
            ".......hhhd.......",
            ".......hhhd.......",
            "........hhd.......",
            "........hd........",
            "........h.........",
        ],
        'side': [
            "..................",
            ".....hhhhhh.......",
            "...hhhhhhhhhh.....",
            "..hhllhhhhhhhh....",
            ".hhllhhhhhhhhhh...",
            ".rhhhhhhhhhhhhhh..",
            "hrhhhhhhhhhhhhhd..",
            "hhhhhhhhhhhhhhhd..",
            "hh.hhhhhhhhhhhhd..",
            "hh.hhhhhhhhdhhhd..",
            "hh.hhhhhhh..hd.d..",
            "hh..hhh...........",
            "hd..hhh...........",
            "hd...hd...........",
            "hd................",
            "dd................",
            ".d................",
        ],
    },
    'F_bob': {
        'front': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhllhhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            ".hhlhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hh............dd.",
            ".hh............hd.",
            ".hh............hd.",
            ".hh............hd.",
            ".hh............hd.",
            ".hhh..........ddd.",
            "..hh..........dd..",
        ],
        'back': [
            "..................",
            "......hhhhhh......",
            "....hhhhhhhhhh....",
            "...hhllhhhhhhhh...",
            "..hhllhhhhhhhhhd..",
            ".hhlhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            ".hhhhhhhhhhhhhhdd.",
            "..hhdhhhhhhdhhdd..",
        ],
        'side': [
            "..................",
            ".....hhhhhh.......",
            "...hhhhhhhhhh.....",
            "..hhllhhhhhhhh....",
            ".hhllhhhhhhhhhh...",
            ".hlhhhhhhhhhhhhh..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhhhhhhhhd..",
            ".hhhhhhhh.........",
            ".hhhhhhhh.........",
            ".hhhhhhhd.........",
            ".hhhhhhhd.........",
            ".hhhhhhhd.........",
            ".hhhhhhhhd........",
            "..hhhhhdd.........",
        ],
    },
}

# Side-view legs, rows y25..y29, cols x10..x21.
# W hip, n/N near leg upper/lower, f/F far leg upper/lower, s near shoe, t far shoe
SIDE_LEGS = {
    'stand': [
        "............",
        "...WWWWWW...",
        "....fnn.....",
        "....FNN.....",
        "....tsss....",
    ],
    'contactA': [   # near leg forward
        "............",
        "...WWWWWW...",
        "...ff.nn....",
        "..FF...NN...",
        "..ttt..sss..",
    ],
    'passB': [      # near leg planted, far leg lifted behind (body up)
        "...WWWWWW...",
        "....fnn.....",
        "...FFNN.....",
        "..tt.NN.....",
        ".....sss....",
    ],
    'contactC': [   # near leg back
        "............",
        "...WWWWWW...",
        "...nn.ff....",
        "..NN...FF...",
        "..sss..ttt..",
    ],
    'passD': [      # far leg planted, near leg lifted behind (body up)
        "...WWWWWW...",
        "....nnf.....",
        "...NNFF.....",
        "..ss.FF.....",
        ".....ttt....",
    ],
    'runA': [       # airborne, near leg reaching forward, far leg kicked back
        "...WWWWWW...",
        "..fff..nn...",
        ".tt.....NN..",
        ".........sss",
        "............",
    ],
    'runB': [       # near foot lands, far leg tucked
        "............",
        "...WWWWWW...",
        "...FFnn.....",
        "..tt.NN.....",
        ".....sss....",
    ],
    'runC': [       # airborne, far leg reaching forward, near leg kicked back
        "...WWWWWW...",
        "..nnn..ff...",
        ".ss.....FF..",
        ".........ttt",
        "............",
    ],
    'runD': [       # far foot lands, near leg tucked
        "............",
        "...WWWWWW...",
        "...NNff.....",
        "..ss.FF.....",
        ".....ttt....",
    ],
}

# Side-view near arm, rows y23..y26 (+bob), cols x10..x21.
# a sleeve top, A sleeve lower, h hand, o internal outline
NEAR_ARM = {   # S = shadow cast on the torso behind the arm
    'down':  [".....aa.....", "....SAA.....", "....Shh.....", "............"],
    'fwd':   [".....aa.....", ".....SAA....", "......Shh...", "............"],
    'back':  [".....aa.....", "....AAS.....", "...hhS......", "............"],
    'pfwd':  [".....aa.....", ".....AAAhh..", ".....SSS....", "............"],
    'pmid':  [".....aa.....", ".....AAh....", ".....SS.....", "............"],
    'pback': [".....aa.....", "..hhAAS.....", "....SS......", "............"],
}
FAR_ARM = {   # drawn behind the torso
    None:    ["............"] * 4,
    'fwd':   ["............", ".........A..", ".........h..", "............"],
    'back':  ["............", "..A.........", "..h.........", "............"],
    'pfwd':  ["............", ".........h..", "............", "............"],
    'pback': ["............", "..h.........", "............", "............"],
}

# ---------------------------------------------------------------- frames
DIRS = ['down', 'left', 'right', 'up']


def front_frames(anim):
    S = dict(bob=0, hdy=0, hdx=0, lift={'L': 0, 'R': 0}, arms={'L': 'down', 'R': 'down'})

    def f(**kw):
        d = json.loads(json.dumps(S))
        d.update(kw)
        return d
    if anim == 'idle':
        return [f(), f(hdy=1)]
    if anim == 'walk':
        return [f(bob=-1, lift={'L': 1, 'R': 0}, arms={'L': 'down', 'R': 'up'}),
                f(),
                f(bob=-1, lift={'L': 0, 'R': 1}, arms={'L': 'up', 'R': 'down'}),
                f()]
    if anim == 'run':
        return [f(bob=-1, lift={'L': 2, 'R': 0}, arms={'L': 'down', 'R': 'up'}),
                f(lift={'L': 0, 'R': 1}, arms={'L': 'up', 'R': 'up'}),
                f(bob=-1, lift={'L': 0, 'R': 2}, arms={'L': 'up', 'R': 'down'}),
                f(lift={'L': 1, 'R': 0}, arms={'L': 'up', 'R': 'up'})]


def side_frames(anim):
    def f(legs, near, far=None, bob=0, hdy=0, hdx=0):
        return dict(legs=legs, near=near, far=far, bob=bob, hdy=hdy, hdx=hdx)
    if anim == 'idle':
        return [f('stand', 'down'), f('stand', 'down', hdy=1)]
    if anim == 'walk':
        return [f('contactA', 'back', 'fwd'),
                f('passB', 'down', None, bob=-1),
                f('contactC', 'fwd', 'back'),
                f('passD', 'down', None, bob=-1)]
    if anim == 'run':
        return [f('runA', 'pback', 'pfwd', bob=-1, hdx=1),
                f('runB', 'pmid', None, hdx=1),
                f('runC', 'pfwd', 'pback', bob=-1, hdx=1),
                f('runD', 'pmid', None, hdx=1)]


ANIMS = [('idle', 400), ('walk', 150), ('run', 95)]

# ---------------------------------------------------------------- geometry


def n4(x, y):
    return ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))


def outline_of(filled):
    out = set()
    for (x, y) in filled:
        for p in n4(x, y):
            if p not in filled:
                out.add(p)
    return out


def body_front(f):
    """label map {(x,y): (part, shade)} for front/back views."""
    L = {}
    b = f['bob']
    for y in range(23, 26):
        for x in range(12, 20):
            L[(x, y + b)] = ('T', 1 if x == 19 else 0)
    for side, x in (('L', 11), ('R', 20)):
        sh = 1 if side == 'R' else 0
        if f['arms'][side] == 'down':
            L[(x, 23 + b)] = ('Au', sh)
            L[(x, 24 + b)] = ('Al', sh)
            L[(x, 25 + b)] = ('H', sh)
        else:
            L[(x, 23 + b)] = ('Au', sh)
            L[(x, 24 + b)] = ('H', sh)
    for x in range(12, 20):
        L[(x, 26 + b)] = ('W', 1 if x == 19 else 0)
    for side, xs in (('L', (13, 14)), ('R', (17, 18))):
        lift = f['lift'][side]
        top, foot = 27 + b, 29 - lift
        for y in range(top, foot):
            for x in xs:
                L[(x, y)] = ('Lu' if y == top else 'Ll', 1 if x == 18 else 0)
        for x in xs:
            L[(x, foot)] = ('F', 1 if x == 18 else 0)
    return L


def body_side(f):
    """label map for a right-facing side view."""
    L = {}
    b = f['bob']
    # far arm (behind torso)
    for r, row in enumerate(FAR_ARM[f['far']]):
        for c, ch in enumerate(row):
            if ch == 'A':
                L[(10 + c, 23 + r + b)] = ('Al', 1)
            elif ch == 'h':
                L[(10 + c, 23 + r + b)] = ('H', 1)
    # legs + hips
    legmap = {'W': ('W', 0), 'n': ('Lu', 0), 'N': ('Ll', 0), 'f': ('Lu', 1),
              'F': ('Ll', 1), 's': ('F', 0), 't': ('F', 1)}
    for r, row in enumerate(SIDE_LEGS[f['legs']]):
        for c, ch in enumerate(row):
            if ch in legmap:
                part, sh = legmap[ch]
                x = 10 + c
                if ch == 'W' and x == 18:
                    sh = 1
                L[(x, 25 + r)] = (part, sh)
    # torso
    for y in range(23, 26):
        for x in range(13, 19):
            L[(x, y + b)] = ('T', 1 if x == 18 else 0)
    # near arm over torso
    amap = {'a': ('Au', 0), 'A': ('Al', 0), 'h': ('H', 0)}
    for r, row in enumerate(NEAR_ARM[f['near']]):
        for c, ch in enumerate(row):
            p = (10 + c, 23 + r + b)
            if ch in amap:
                L[p] = amap[ch]
            elif ch == 'S' and L.get(p, ('',))[0] == 'T':
                L[p] = ('T', 1)
    return L


def stamp(template, ox, oy):
    pts = {}
    for r, row in enumerate(template):
        for c, ch in enumerate(row):
            if ch != '.':
                pts[(ox + c, oy + r)] = ch
    return pts


# ---------------------------------------------------------------- outfits
def R(a, b):
    return (hx(a), hx(b))


WHITE = R('f4f4f8', 'c9c9d6')
OUTFITS = {
    'M_tee_jeans': dict(
        cover={'T': R('4f86d6', '3a62a8'), 'Au': R('4f86d6', '3a62a8'),
               'W': R('3b4a6b', '2c3650'), 'Lu': R('3b4a6b', '2c3650'),
               'Ll': R('3b4a6b', '2c3650'), 'F': R('6b4428', '4c2f1c')}),
    'M_hoodie': dict(
        cover={'T': R('d0524a', '9c3a38'), 'Au': R('d0524a', '9c3a38'),
               'Al': R('d0524a', '9c3a38'),
               'W': R('4a4a56', '36363f'), 'Lu': R('4a4a56', '36363f'),
               'Ll': R('4a4a56', '36363f'), 'F': R('e8e8ec', 'a8a8b8')},
        detail='hoodie'),
    'M_adventurer': dict(
        cover={'T': R('4f9a4f', '3a733a'), 'Au': R('4f9a4f', '3a733a'),
               'Al': R('d8c8a0', 'b0a078'),
               'W': R('7a5230', '5a3a20'), 'Lu': R('4f9a4f', '3a733a'),
               'Ll': R('c9ad84', 'a08560'), 'F': R('5c3a22', '42291a')},
        skirt=dict(rows=1, flare=0, ramp=R('4f9a4f', '3a733a')),
        detail='belt'),
    'F_dress': dict(
        cover={'T': R('ec8fb0', 'c66a8e'), 'Au': R('ec8fb0', 'c66a8e'),
               'W': R('ec8fb0', 'c66a8e'), 'F': R('b8404c', '8a2e3a')},
        skirt=dict(rows=1, flare=1, ramp=R('ec8fb0', 'c66a8e')),
        detail='collar'),
    'F_blouse_skirt': dict(
        cover={'T': WHITE, 'Au': WHITE, 'Al': WHITE,
               'W': R('3e4f99', '2c3a74'), 'F': R('4a3434', '352424')},
        skirt=dict(rows=1, flare=1, ramp=R('3e4f99', '2c3a74'), pleats=True),
        detail='ribbon'),
    'F_adventurer': dict(
        cover={'T': R('b83a3a', '8a2a2e'), 'Au': WHITE, 'Al': WHITE,
               'W': R('8a5a36', '6a4228'), 'Ll': R('5c3a22', '42291a'),
               'F': R('5c3a22', '42291a')},
        skirt=dict(rows=1, flare=1, ramp=R('8a5a36', '6a4228')),
        detail='vest'),
    'U_suit': dict(
        cover={'T': R('2f3a56', '222a40'), 'Au': R('2f3a56', '222a40'),
               'Al': R('2f3a56', '222a40'),
               'W': R('2f3a56', '222a40'), 'Lu': R('2f3a56', '222a40'),
               'Ll': R('2f3a56', '222a40'), 'F': R('4a4250', '37313d')},
        detail='suit'),
}
DETAIL_COL = {
    'string': hx('f4f4f8'), 'pocket': hx('9c3a38'), 'hood': hx('9c3a38'),
    'buckle': hx('e8c547'), 'collar': hx('f6f6f6'), 'ribbon': hx('d94048'),
    'shirt': hx('f4f4f8'), 'tie': hx('c0393b'), 'lace': hx('f4f4f8'),
}


# ---------------------------------------------------------------- render
def render(view, f):
    """Return {layer_key: {(x,y): rgba}} for a right/front/back frame."""
    layers = {}
    labels = body_front(f) if view in ('front', 'back') else body_side(f)
    b = f['bob']

    # ---- head geometry
    hy = HEAD_Y + b + f['hdy']
    hxp = HEAD_X + f['hdx']
    head = stamp(HEAD[view], hxp, hy)
    head_ol = outline_of(set(head))
    head_mask = set(head) | head_ol

    body_set = set(labels)
    body_ol = outline_of(body_set)

    # ---- skin layers
    for sk, (base, shad, mouth) in SKINS.items():
        base, shad, mouth = hx(base), hx(shad), hx(mouth)
        px = {}
        for p in body_ol:
            px[p] = OUT
        for p, (part, sh) in labels.items():
            if part == 'O':
                px[p] = OUT
            elif part in ('T', 'Au'):
                px[p] = hx(UNDER_TOP[sh])
            elif part in ('W', 'Lu'):
                px[p] = hx(UNDER_BOT[sh])
            else:
                px[p] = shad if sh else base
        for p in head_ol:
            px[p] = OUT
        for p, ch in head.items():
            px[p] = {'s': base, 'd': shad, 'k': shad, 'm': mouth,
                     'e': EYE, 'i': IRIS, 'w': EYE_WHITE}[ch]
        layers[('skin', sk)] = px

    # ---- clothes
    tor_x0, tor_x1 = (12, 19) if view in ('front', 'back') else (13, 18)
    hip_y = 26 + b
    for name, o in OUTFITS.items():
        px = {}
        for p, (part, sh) in labels.items():
            if part in o['cover']:
                px[p] = o['cover'][part][sh]
        sk = o.get('skirt')
        if sk:
            extra = {}
            for r in range(1, sk['rows'] + 1):
                y = hip_y + r
                for x in range(tor_x0 - sk['flare'], tor_x1 + sk['flare'] + 1):
                    sh = 1 if x >= tor_x1 + sk['flare'] - (0 if view == 'side' else 0) else 0
                    if sk.get('pleats') and view != 'side' and (x - tor_x0) % 3 == 2:
                        sh = 1
                    extra[(x, y)] = sk['ramp'][sh]
            shape = set(extra) | {p for p, (pt, _) in labels.items() if pt == 'W'}
            for p in outline_of(shape):
                if p in labels and labels[p][0] != 'O':
                    continue          # never draw a hem line across a leg
                if p in shape:
                    continue
                px[p] = OUT
            px.update(extra)
        details(o.get('detail'), view, b, px, labels)
        for p in list(px):
            if p in head_mask:
                del px[p]
        layers[('clothes', name)] = px

    # ---- hair
    hhy = HAIR_Y + b + f['hdy']
    hhx = HAIR_X + f['hdx']
    for name, views in HAIRS.items():
        pts = stamp(views[view], hhx, hhy)
        filled = set(pts)
        front = {p for p, ch in pts.items() if ch.islower()}
        fpx, bpx = {}, {}
        for p in outline_of(filled):
            if any(q in front for q in n4(*p)):
                fpx[p] = OUT
            else:
                bpx[p] = OUT
        for p, ch in pts.items():
            (fpx if ch.islower() else bpx)[p] = HAIR[ch.lower()]
        layers[('hair', name)] = fpx
        layers[('hair_back', name)] = bpx
    return layers


def details(kind, view, b, px, labels):
    D = DETAIL_COL
    y0 = 23 + b
    if kind is None:
        return
    if view == 'front':
        if kind == 'hoodie':
            px[(14, y0)] = D['string']
            px[(17, y0)] = D['string']
            px[(14, y0 + 1)] = D['string']
            px[(17, y0 + 1)] = D['string']
            for x in range(14, 18):
                px[(x, y0 + 2)] = D['pocket']
        elif kind == 'belt':
            px[(15, y0)] = hx('d8c8a0')
            px[(16, y0)] = hx('d8c8a0')
            px[(15, 26 + b)] = D['buckle']
            px[(16, 26 + b)] = D['buckle']
        elif kind == 'collar':
            for x in range(14, 18):
                px[(x, y0)] = D['collar']
        elif kind == 'ribbon':
            px[(15, y0)] = D['ribbon']
            px[(16, y0)] = D['ribbon']
        elif kind == 'vest':
            px[(15, y0)] = D['lace']
            px[(16, y0)] = D['lace']
            px[(15, y0 + 1)] = hx('6a4228')
            px[(16, y0 + 1)] = hx('6a4228')
        elif kind == 'suit':
            px[(14, y0)] = D['shirt']
            px[(17, y0)] = D['shirt']
            px[(15, y0)] = D['tie']
            px[(16, y0)] = D['tie']
            px[(15, y0 + 1)] = D['tie']
            px[(16, y0 + 1)] = D['tie']
    elif view == 'back':
        if kind == 'hoodie':
            for x in range(13, 19):
                px[(x, y0)] = D['hood']
        elif kind == 'belt':
            pass
    else:  # side, facing right; front edge is x=18
        def put(p, c):
            if p in labels and labels[p][0] == 'T':
                px[p] = c
        if kind == 'hoodie':
            put((13, y0), D['hood'])
            put((14, y0), D['hood'])
            put((18, y0 + 1), D['string'])
        elif kind == 'belt':
            put((18, y0), hx('d8c8a0'))
        elif kind == 'collar':
            put((17, y0), D['collar'])
            put((18, y0), D['collar'])
        elif kind == 'ribbon':
            put((18, y0), D['ribbon'])
        elif kind == 'vest':
            put((18, y0), D['lace'])
        elif kind == 'suit':
            put((18, y0), D['shirt'])
            put((18, y0 + 1), D['tie'])
        if kind == 'belt':
            p = (18, 26 + b)
            if p in labels:
                px[p] = D['buckle']


# ---------------------------------------------------------------- driver
def build():
    frames = []      # list of (anim, dir, idx, duration, view, spec)
    for anim, dur in ANIMS:
        for d in DIRS:
            specs = side_frames(anim) if d in ('left', 'right') else front_frames(anim)
            for i, s in enumerate(specs):
                frames.append(dict(anim=anim, dir=d, idx=i, dur=dur, spec=s))

    layer_imgs = {}   # key -> list of Image
    for fr in frames:
        d = fr['dir']
        view = {'down': 'front', 'up': 'back'}.get(d, 'side')
        lay = render(view, fr['spec'])
        for key, px in lay.items():
            img = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
            for (x, y), c in px.items():
                if 0 <= x < SZ and 0 <= y < SZ:
                    xx = (SZ - 1 - x) if d == 'left' else x
                    img.putpixel((xx, y), c)
            layer_imgs.setdefault(key, []).append(img)
    return frames, layer_imgs


LAYER_ORDER = (
    [('hair_back', n) for n in HAIRS] +
    [('skin', n) for n in SKINS] +
    [('clothes', n) for n in OUTFITS] +
    [('hair', n) for n in HAIRS]
)


def main():
    frames, imgs = build()
    n = len(frames)
    sd = os.path.join(HERE, 'strips')
    os.makedirs(sd, exist_ok=True)
    meta_layers = []
    for key in LAYER_ORDER:
        strip = Image.new('RGBA', (SZ * n, SZ), (0, 0, 0, 0))
        for i, im in enumerate(imgs[key]):
            strip.paste(im, (i * SZ, 0))
        fn = f'{key[0]}__{key[1]}.png'
        strip.save(os.path.join(sd, fn))
        meta_layers.append(dict(group=key[0], name=key[1], file=fn,
                                empty=strip.getbbox() is None))
    tags = []
    for i, fr in enumerate(frames):
        t = f"{fr['anim']}_{fr['dir']}"
        if not tags or tags[-1]['name'] != t:
            tags.append(dict(name=t, start=i, end=i))
        else:
            tags[-1]['end'] = i
    meta = dict(size=SZ, frames=[dict(anim=f['anim'], dir=f['dir'], idx=f['idx'],
                                      dur=f['dur']) for f in frames],
                tags=tags, layers=meta_layers)
    with open(os.path.join(HERE, 'frames.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, indent=1)

    # ---- game sheets: rows = anim x dir, cols = frame index
    shd = os.path.join(HERE, 'sheets')
    os.makedirs(shd, exist_ok=True)
    rows = [(a, d) for a, _ in ANIMS for d in DIRS]
    maxc = max(f['idx'] for f in frames) + 1
    sheet_meta = dict(frame_w=SZ, frame_h=SZ, columns=maxc,
                      rows=[dict(row=r, anim=a, dir=d,
                                 frames=sum(1 for f in frames if f['anim'] == a and f['dir'] == d),
                                 ms=dict(ANIMS)[a]) for r, (a, d) in enumerate(rows)],
                      layer_order_bottom_to_top=[f'{g}/{nm}' for g, nm in LAYER_ORDER])
    for key in LAYER_ORDER:
        if key[0] == 'hair_back' and all(im.getbbox() is None for im in imgs[key]):
            continue
        sh = Image.new('RGBA', (SZ * maxc, SZ * len(rows)), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            r = rows.index((fr['anim'], fr['dir']))
            sh.paste(imgs[key][i], (fr['idx'] * SZ, r * SZ))
        sh.save(os.path.join(shd, f'{key[0]}__{key[1]}.png'))
    with open(os.path.join(shd, 'sheets.json'), 'w', encoding='utf-8') as fh:
        json.dump(sheet_meta, fh, indent=1)
    print('frames', n, 'layers', len(LAYER_ORDER))
    return frames, imgs


def compose(imgs, i, hair, skin, cloth):
    im = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0))
    for key in [('hair_back', hair), ('skin', skin), ('clothes', cloth), ('hair', hair)]:
        if cloth is None and key[0] == 'clothes':
            continue
        im = Image.alpha_composite(im, imgs[key][i])
    return im


if __name__ == '__main__':
    main()
