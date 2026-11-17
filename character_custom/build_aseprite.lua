local dir = "C:/Users/훈도/Desktop/aseprite-mcp-main/character_custom/strips/"
local out = "C:/Users/훈도/Desktop/aseprite-mcp-main/character_custom/character_custom.aseprite"
local durs = {400,400,400,400,400,400,400,400,150,150,150,150,150,150,150,150,150,150,150,150,150,150,150,150,95,95,95,95,95,95,95,95,95,95,95,95,95,95,95,95}
local groups = {"hair_back","skin","clothes","hair"}
local layers = {
  {g="hair_back", name="F_long_back", file="hair_back__F_long.png", vis=false},
  {g="hair_back", name="F_ponytail_back", file="hair_back__F_ponytail.png", vis=false},
  {g="skin", name="skin_light", file="skin__skin_light.png", vis=false},
  {g="skin", name="skin_fair", file="skin__skin_fair.png", vis=true},
  {g="skin", name="skin_tan", file="skin__skin_tan.png", vis=false},
  {g="skin", name="skin_dark", file="skin__skin_dark.png", vis=false},
  {g="clothes", name="M_tee_jeans", file="clothes__M_tee_jeans.png", vis=true},
  {g="clothes", name="M_hoodie", file="clothes__M_hoodie.png", vis=false},
  {g="clothes", name="M_adventurer", file="clothes__M_adventurer.png", vis=false},
  {g="clothes", name="F_dress", file="clothes__F_dress.png", vis=false},
  {g="clothes", name="F_blouse_skirt", file="clothes__F_blouse_skirt.png", vis=false},
  {g="clothes", name="F_adventurer", file="clothes__F_adventurer.png", vis=false},
  {g="clothes", name="U_suit", file="clothes__U_suit.png", vis=false},
  {g="hair", name="M_spiky", file="hair__M_spiky.png", vis=true},
  {g="hair", name="M_sidepart", file="hair__M_sidepart.png", vis=false},
  {g="hair", name="M_crop", file="hair__M_crop.png", vis=false},
  {g="hair", name="F_long", file="hair__F_long.png", vis=false},
  {g="hair", name="F_ponytail", file="hair__F_ponytail.png", vis=false},
  {g="hair", name="F_bob", file="hair__F_bob.png", vis=false},
}
local tags = {
  {name="idle_down", s=1, e=2},
  {name="idle_left", s=3, e=4},
  {name="idle_right", s=5, e=6},
  {name="idle_up", s=7, e=8},
  {name="walk_down", s=9, e=12},
  {name="walk_left", s=13, e=16},
  {name="walk_right", s=17, e=20},
  {name="walk_up", s=21, e=24},
  {name="run_down", s=25, e=28},
  {name="run_left", s=29, e=32},
  {name="run_right", s=33, e=36},
  {name="run_up", s=37, e=40},
}
local pal = {{42,31,45},{53,36,36},{34,42,64},{66,41,26},{74,40,24},{55,49,61},{76,47,28},{44,54,80},{54,54,63},{47,58,86},{74,52,52},{44,58,116},{92,54,30},{90,58,32},{92,58,34},{74,66,80},{138,42,46},{59,74,107},{138,46,58},{106,66,40},{108,65,40},{74,74,86},{107,68,40},{62,79,153},{70,83,110},{156,58,56},{122,82,48},{58,115,58},{142,76,54},{58,98,168},{74,95,154},{184,58,58},{138,85,48},{192,57,59},{138,90,54},{184,64,76},{142,91,60},{90,106,138},{217,64,72},{208,82,74},{79,154,79},{79,134,214},{176,117,68},{192,112,94},{160,133,96},{198,106,142},{192,138,85},{217,138,122},{176,160,120},{212,155,102},{168,168,184},{220,156,116},{236,143,176},{201,173,132},{180,180,196},{232,197,71},{240,188,156},{216,200,160},{201,201,214},{245,199,160},{220,220,228},{232,232,236},{255,227,204},{244,244,248},{246,246,246},{255,255,255}}

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
