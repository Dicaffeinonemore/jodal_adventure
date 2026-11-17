"""Generate all parts and build character_custom.aseprite with Aseprite CLI."""
import json, os, subprocess
from PIL import Image
import character_custom.gen_character as G

HERE = os.path.dirname(os.path.abspath(__file__))
ASE = r"C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe"
DEFAULT = {('hair_back', 'M_spiky'), ('skin', 'skin_fair'),
           ('clothes', 'M_tee_jeans'), ('hair', 'M_spiky')}

frames, imgs = G.main()
meta = json.load(open(os.path.join(HERE, 'frames.json'), encoding='utf-8'))

# palette from every colour used
cols = []
for key in G.LAYER_ORDER:
    for im in imgs[key]:
        for c in im.getdata():
            if c[3] and c[:3] not in cols:
                cols.append(c[:3])
cols.sort(key=lambda c: (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]))

def lstr(s):
    return '"' + s.replace(chr(92), '/') + '"'

L = []
L.append('local dir = %s' % lstr(os.path.join(HERE, 'strips') + '/'))
L.append('local out = %s' % lstr(os.path.join(HERE, 'character_custom.aseprite')))
L.append('local durs = {%s}' % ','.join(str(f['dur']) for f in meta['frames']))
L.append('local groups = {"hair_back","skin","clothes","hair"}')
L.append('local layers = {')
for ly in meta['layers']:
    if ly['empty']:
        continue
    name = ly['name'] + ('_back' if ly['group'] == 'hair_back' else '')
    vis = 'true' if (ly['group'], ly['name']) in DEFAULT else 'false'
    L.append('  {g=%s, name=%s, file=%s, vis=%s},' % (lstr(ly['group']), lstr(name), lstr(ly['file']), vis))
L.append('}')
L.append('local tags = {')
for t in meta['tags']:
    L.append('  {name=%s, s=%d, e=%d},' % (lstr(t['name']), t['start'] + 1, t['end'] + 1))
L.append('}')
L.append('local pal = {%s}' % ','.join('{%d,%d,%d}' % c for c in cols))
L.append(r'''
local N = #durs
local spr = Sprite(32, 32, ColorMode.RGB)
local first = spr.layers[1]
for i = 2, N do spr:newEmptyFrame() end
for i = 1, N do spr.frames[i].duration = durs[i] / 1000 end
local G = {}
for _, gname in ipairs(groups) do
  local g = spr:newGroup()
  g.name = gname
  G[gname] = g
end
for _, l in ipairs(layers) do
  local lay = spr:newLayer()
  lay.name = l.name
  lay.parent = G[l.g]
  local strip = Image{ fromFile = dir .. l.file }
  for i = 1, N do
    local img = Image(32, 32, ColorMode.RGB)
    img:drawImage(strip, Point(-(i - 1) * 32, 0))
    if not img:isEmpty() then spr:newCel(lay, i, img, Point(0, 0)) end
  end
  lay.isVisible = l.vis
end
spr:deleteLayer(first)
for _, t in ipairs(tags) do
  local tag = spr:newTag(t.s, t.e)
  tag.name = t.name
end
local p = Palette(#pal + 1)
p:setColor(0, Color{ r = 0, g = 0, b = 0, a = 0 })
for i, c in ipairs(pal) do p:setColor(i, Color{ r = c[1], g = c[2], b = c[3], a = 255 }) end
spr:setPalette(p)
spr:saveAs(out)
print("saved", out, "frames", #spr.frames, "layers", #spr.layers, "tags", #spr.tags)
''')
lua = os.path.join(HERE, 'build_aseprite.lua')
open(lua, 'w', encoding='utf-8').write('\n'.join(L))
r = subprocess.run([ASE, '-b', '--script', lua], capture_output=True, text=True, encoding='utf-8', errors='replace')
print(r.stdout, r.stderr)
print('palette colours', len(cols))
