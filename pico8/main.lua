-- main.lua
-- title + level select, the island, front-view stones, rolling and
-- hopping animations, undo and restart, the in-game menu, saved progress,
-- sfx and music. the rules live in rules.lua, levels in levels.lua.

-- top-left of the 7x5 board, 16px squares
local ox, oy = 8, 28

-- sfx (see tools/music.lua):
-- 0 pick up, 1 put down, 2 roll, 3 stack, 4 flag, 5 bump, 6 undo,
-- 7 solved. one song plays all the time, from pattern 0, on channels
-- 0-1 (mask 3) so sfx keep 2-3.

-- saved progress:
-- dget(0) highest level solved, dget(i) your fewest moves on level i
-- (0 = not solved yet), dget(63) the level played last
cartdata("koaning_cairns")

-- how high a piece sits in a stack: on the big stone, on the small one
local lift = { l = 0, m = 8, h = 15 }
-- moss on the stones as { u, v } pairs in -1..1, turned while rolling
local moss = {
  l = { -0.5, -0.3, 0.35, 0.25, 0.9, -0.45, -0.1, 0.65, -0.95, 0.5 },
  m = { -0.35, 0.1, 0.55, -0.4, 0.15, 0.7 },
}
local names = { l = "big stone", m = "small stone", h = "flag" }

-- pixel art: rows split by "|", one hex colour per pixel, "." = clear
local function pix(s)
  local list, x, y = {}, 0, 0
  for i = 1, #s do
    local c = sub(s, i, i)
    if c == "|" then
      x, y = 0, y + 1
    else
      if c ~= "." then add(list, { x, y, tonum("0x" .. c) }) end
      x = x + 1
    end
  end
  return list
end

local tree_art = pix("......1......|.....131.....|.....1b31....|....13b331...|.....1b31....|....13bb31...|...13b33331..|....1b3331...|...13bb3331..|..13b3333331.|...1b333331..|..13bb333331.|.13b33333331.|..1b3333331..|.13bb3333331.|13b3333333331|1111144411111|.....424.....")
local flag_art = {
  pix("a|4888|48888|488888|48822|4|4|4|4|4|4|4|4"),
  pix("a|4.888|488888|48888|4822|4|4|4|4|4|4|4|4"),
}
local menu_items = { "resume", "back to levels" }
local confetti_c = { 8, 9, 10, 7, 14 }

-- logo letters, 8 rows each, drawn 2x as carved stone
local logo = {
  { 6, "011110110011110000110000110000110000110011011110" },
  { 6, "011110110011110011110011111111110011110011110011" },
  { 2, "1111111111111111" },
  { 6, "111110110011110011111110110110110011110011110011" },
  { 6, "110011111011111111110111110011110011110011110011" },
  { 6, "011110110011110000011110000011000011110011011110" },
}

local scene = "title"
local flag_x = 0

-- keys: enter works like 🅾️, r restarts, and the pause button (p, or
-- start on a gamepad) opens the cart's own menu instead of pico-8's.
-- pico-8 reports enter as the pause button too, so the raw keyboard
-- (devkit mode: scancode 40 enter, 88 keypad enter, 21 r) tells them apart.
poke(0x5f2d, 1)
local enter, enter_was, pause, pause_was = false, false, false, false
local rkey, rkey_was = false, false

local function read_keys()
  local down, p, r = stat(28, 40) or stat(28, 88), btn(6), stat(28, 21)
  enter = down and not enter_was
  pause = p and not pause_was and not down
  rkey = r and not rkey_was
  enter_was, pause_was, rkey_was = down, p, r
  if p then poke(0x5f30, 1) end
end

-- 🅾️ or enter
local function ok()
  return btnp(4) or enter
end
music(0, 0, 3)

local lvl = mid(1, dget(63), #levels)
local st, hist = nil, {}
local cur = { x = 1, y = 1 }
local held = nil
local anim = nil
local intro, outro = nil, nil
local won = nil
local shake = nil
-- a stone that stopped against something: { x, y, dx, dy, t, id }
local hit = nil
local menu = nil
local xhold = 0
local spin = {}
local bits = {}
local pollen = {}
local frame = 0

for i = 1, 14 do
  add(pollen, { x = rnd(128), y = rnd(128), s = 0.1 + rnd(0.2) })
end

local function unlocked()
  return min(dget(0) + 1, #levels)
end

local function cx_of(x) return ox + (x - 1) * 16 + 8 end
local function by_of(y) return oy + (y - 1) * 16 + 13 end

local function piece(id)
  for p in all(st.pieces) do
    if p.id == id then return p end
  end
end

local function held_piece()
  local p = held and piece(held)
  if p and not p.stack then return p end
end

local function start_level(n, drop)
  lvl = n
  st = rules_parse(levels[n][3])
  hist, held, anim, won, shake, menu, outro, hit = {}, nil, nil, nil, nil, nil, nil, nil
  intro = drop and 0 or nil
  spin, bits = {}, {}
  for p in all(st.pieces) do
    spin[p.id] = { 0, 0 }
  end
  cur = { x = st.pieces[1].x, y = st.pieces[1].y }
  dset(63, n)
end

local function restart()
  if #hist > 0 then
    st = hist[1]
    hist, held, anim, won = {}, nil, nil, nil
    sfx(6)
  end
end

local function undo()
  if #hist > 0 then
    st = deli(hist)
    held, anim = nil, nil
    sfx(6)
  end
end

local function to_title()
  scene, menu = "title", nil
end

local function play(n)
  scene = "play"
  start_level(n, true)
end

local function solved()
  won = 0
  sfx(7)
  if lvl > dget(0) then dset(0, lvl) end
  local mine = dget(lvl)
  if mine == 0 or #hist < mine then dset(lvl, #hist) end
end

local function confetti(x, y)
  for i = 1, 14 do
    local a = rnd(1)
    add(bits, {
      x = x, y = y, vx = cos(a) * (0.5 + rnd(1)), vy = -1 - rnd(1.5),
      c = confetti_c[flr(rnd(5)) + 1], t = 40 + rnd(20),
    })
  end
end

-- the move animation is done: change the board for real
local function land()
  local p, m = anim.p, anim.m
  anim = nil
  rules_apply(st, p, m)
  cur.x, cur.y = m.x, m.y
  if m.kind == "stack" then
    held = nil
    if m.stack == "lmh" then
      sfx(4)
      confetti(cx_of(m.x), by_of(m.y) - 26)
    else
      sfx(3)
    end
  else
    sfx(3)
    -- whatever stopped it sways, the stone squashes against it
    hit = { x = m.x + m.dx, y = m.y + m.dy, dx = m.dx, dy = m.dy, t = 18, id = p.id }
  end
  if rules_solved(st) then solved() end
end

local function send(p, dx, dy)
  local m = rules_move(st, p, dx, dy)
  if m then
    add(hist, rules_copy(st))
    anim = { p = p, m = m, t = 0, dur = m.kind == "roll" and m.dist * 5 or 12 }
    if m.kind == "stack" then sfx(0) end
  else
    shake = { id = p.id, t = 12 }
    sfx(5)
  end
end

local function tap_x()
  if held then
    held = nil
    sfx(1)
  else
    undo()
  end
end

-------------------------------------------------------------
-- update
-------------------------------------------------------------

local function update_title()
  local n = unlocked()
  local d = 0
  if btnp(0) then d = -1 end
  if btnp(1) then d = 1 end
  if btnp(2) then d = -10 end
  if btnp(3) then d = 10 end
  if d ~= 0 then
    local to = lvl + d
    if to >= 1 and to <= #levels then
      lvl = to
      sfx(0)
    end
  end
  if ok() then
    if lvl <= n then
      play(lvl)
    else
      sfx(5)
    end
  end
end

local function update_menu()
  if btnp(2) then menu.row = (menu.row - 2) % #menu_items + 1 end
  if btnp(3) then menu.row = menu.row % #menu_items + 1 end
  if btnp(5) or pause then menu = nil return end
  if ok() then
    local r = menu.row
    menu = nil
    if r == 2 then to_title() end
  end
end

local function update_play()
  for p in all(bits) do
    p.x, p.y, p.vy, p.t = p.x + p.vx, p.y + p.vy, p.vy + 0.08, p.t - 1
    if p.t < 0 then del(bits, p) end
  end
  if shake then
    shake.t = shake.t - 1
    if shake.t <= 0 then shake = nil end
  end
  if hit then
    hit.t = hit.t - 1
    if hit.t <= 0 then hit = nil end
  end

  if intro then
    intro = intro + 1
    if intro % 10 == 1 and intro < 30 then sfx(1) end
    if intro > 40 then intro = nil end
    return
  end
  if outro then
    outro = outro + 1
    if outro > 40 then
      if lvl < #levels then
        start_level(lvl + 1, true)
      else
        to_title()
      end
    end
    return
  end
  if menu then
    update_menu()
    return
  end
  if anim then
    local a = anim
    a.t = a.t + 1
    if a.m.kind == "roll" then
      local s = spin[a.p.id]
      s[1], s[2] = s[1] + a.m.dx * 0.12, s[2] + a.m.dy * 0.12
      if a.t % 5 == 1 then sfx(2) end
    end
    if a.t >= a.dur then land() end
    return
  end
  if won then
    won = won + 1
    if won > 110 or (won > 20 and ok()) then
      outro = 0
      won = nil
    end
    return
  end

  if pause then
    menu = { row = 1 }
    sfx(0)
    return
  end

  if rkey then restart() end

  -- tap x to put down / undo, hold x to restart
  if btn(5) then
    xhold = xhold + 1
    if xhold == 20 then
      held = nil
      restart()
    end
  else
    if xhold > 0 and xhold < 20 then tap_x() end
    xhold = 0
  end

  for b = 0, 3 do
    if btnp(b) then
      local d = dirs[b + 1]
      local p = held_piece()
      if p then
        send(p, d[1], d[2])
      elseif rules_on_board(st, cur.x + d[1], cur.y + d[2]) then
        cur.x, cur.y = cur.x + d[1], cur.y + d[2]
      end
    end
  end

  if ok() then
    local p = rules_movable_at(st, cur.x, cur.y)
    if held then
      held = nil
      sfx(1)
    elseif p then
      held = p.id
      sfx(0)
    else
      sfx(5)
    end
  end
end

function _update60()
  frame = frame + 1
  read_keys()
  for p in all(pollen) do
    p.x, p.y = (p.x + p.s) % 128, (p.y + sin(frame / 200 + p.s) * 0.1) % 128
  end
  if scene == "title" then
    update_title()
  else
    update_play()
  end
end

-------------------------------------------------------------
-- drawing helpers
-------------------------------------------------------------

-- exact pixel ink width (wide button glyphs >= 128 are 8px, ascii is 4px)
local function text_w(s)
  local w = 0
  for i = 1, #s do
    w = w + (ord(s, i) >= 128 and 8 or 4)
  end
  return max(0, w - 1)
end

local function cprint(s, y, c)
  print(s, flr((128 - text_w(s)) / 2), y, c)
end

-- lean shifts the top of the art sideways, the bottom stays planted
local function draw_pix(list, x, y, lean)
  local h = list[#list][2]
  for q in all(list) do
    pset(x + q[1] + flr((lean or 0) * (h - q[2]) / h + 0.5), y + q[2], q[3])
  end
end

local function corners(x0, y0, x1, y1, s, c)
  for a = -1, 1, 2 do
    for b = -1, 1, 2 do
      local x, y = a < 0 and x0 or x1, b < 0 and y0 or y1
      line(x, y, x - a * s, y, c)
      line(x, y, x, y - b * s, c)
    end
  end
end

local function draw_sea()
  cls(12)
  for i = 0, 22 do
    local x = (i * 37 + frame / (6 + i % 3)) % 150 - 10
    local y = (i * 23) % 128
    line(x, y, x + 2 + i % 3, y, 7)
  end
end

-- a stone, front view: centre x, the y it rests on, big or small,
-- and how far its moss has turned
local function draw_stone(cx, by, big, sp, sx, sy)
  local rx, ry = (big and 7 or 5) - (sx or 0), (big and 5 or 4) - (sy or 0)
  local cy = by - ry
  ovalfill(cx - rx, cy - ry, cx + rx, cy + ry, 5)
  ovalfill(cx - rx + 1, cy - ry + 1, cx + rx - 1, cy + ry - 1, 13)
  ovalfill(cx - rx + 1, cy - ry + 1, cx + rx - 3, cy + ry - 2, 6)
  line(cx - rx + 3, cy - ry + 2, cx - 1, cy - ry + 2, 7)
  local m = moss[big and "l" or "m"]
  for i = 1, #m, 2 do
    local u = (m[i] + sp[1] + 1) % 2 - 1
    local v = (m[i + 1] + sp[2] + 1) % 2 - 1
    if abs(u) < 0.8 and abs(v) < 0.75 then
      local x, y = cx + u * (rx - 1), cy + v * (ry - 1)
      pset(x, y, 3)
      pset(x + 1, y, 11)
    end
  end
end

-- one piece standing at cx, by (its square's resting y)
local function draw_piece(p, cx, by, waving, lean, sx, sy)
  if p.kind == "h" then
    if not p.stack and not (anim and anim.p == p) then
      -- planted in a little mound of earth
      ovalfill(cx - 3, by - 1, cx + 3, by + 1, 4)
      line(cx - 2, by - 1, cx, by - 1, 15)
    end
    draw_pix(flag_art[waving and flr(frame / 12) % 2 + 1 or 1], cx - 1, by - 12, lean)
  else
    draw_stone(cx + flr(lean / 3 + 0.5), by, p.kind == "l", spin[p.id] or { 0, 0 }, sx, sy)
  end
end

-- how a square sways after a stone hit it: sideways for a hit from the
-- side, a little dip for a hit from the front or back
local function sway(x, y)
  if not hit or hit.x ~= x or hit.y ~= y then return 0, 0 end
  local k = hit.t / 18 * cos((18 - hit.t) / 9)
  return hit.dx * 4 * k, abs(hit.dy * k) > 0.4 and 1 or 0
end

-- how far a square's things have flown off the top of the screen
local function fly(x, y)
  local t = intro or outro
  if not t then return 0 end
  local k = mid(0, (t - (y - 1) * 5 - (x - 1)) / 12, 1)
  if intro then k = 1 - k end
  return -128 * k * k
end

local function draw_island()
  -- foam, grass and the cliff along the front
  rectfill(3, 21, 124, 112, 7)
  rectfill(4, 22, 123, 111, 3)
  rectfill(4, 112, 123, 116, 4)
  line(4, 114, 123, 114, 2)
  line(4, 117, 123, 117, 1)
  for i = 0, 11 do
    pset(8 + i * 10, 24 + (i * 7) % 3, 11)
    pset(6 + (i * 13) % 116, 109, 11)
  end
  for y = 1, board_h do
    for x = 1, board_w do
      local x0, y0 = ox + (x - 1) * 16, oy + (y - 1) * 16
      if (x + y) % 2 == 1 then fillp(0xa050) end
      rectfill(x0, y0, x0 + 15, y0 + 15, 0x3b)
      fillp()
    end
  end
end

local function draw_targets()
  local p = held_piece()
  if not p or anim then return end
  for m in all(rules_moves(st, p)) do
    local x0, y0 = ox + (m.x - 1) * 16, oy + (m.y - 1) * 16
    if m.kind == "stack" then
      rectfill(x0 + 1, y0 + 1, x0 + 14, y0 + 14, 9)
    else
      fillp(0xa5a5)
      for i = 1, m.dist - 1 do
        local tx, ty = x0 - m.dx * i * 16, y0 - m.dy * i * 16
        rectfill(tx + 3, ty + 3, tx + 12, ty + 12, 0xc0 + 11)
      end
      fillp()
      rectfill(x0 + 1, y0 + 1, x0 + 14, y0 + 14, 12)
    end
  end
end

-- trees and pieces, far row first, a stack from the bottom up
local function draw_things()
  local list = {}
  for k in pairs(st.trees) do
    local x, y = k % 16, flr(k / 16)
    add(list, { y * 64 + x, x, y, nil, 0 })
  end
  for p in all(st.pieces) do
    local x, y, up = p.x, p.y, p.stack and lift[p.kind] or 0
    if anim and anim.p == p then
      local k, m = anim.t / anim.dur, anim.m
      x, y = x + (m.x - x) * k, y + (m.y - y) * k
      if m.kind == "stack" then
        up = lift[p.kind] * k + sin(k / 2) * -10
      end
    end
    add(list, { y * 64 + x + up / 32, x, y, p, up })
  end
  -- insertion sort on the draw key
  for i = 2, #list do
    local j = i
    while j > 1 and list[j - 1][1] > list[j][1] do
      list[j], list[j - 1] = list[j - 1], list[j]
      j = j - 1
    end
  end

  for e in all(list) do
    local p = e[4]
    local cx, by = ox + (e[2] - 1) * 16 + 8, by_of(e[3])
    local off = fly(flr(e[2] + 0.5), flr(e[3] + 0.5))
    if e[5] == 0 and off > -60 then
      ovalfill(cx - 6, by - 1, cx + 6, by + 2, 3)
    end
    by = by + off
    local lean, dip = sway(e[2], e[3])
    by = by + dip
    if not p then
      draw_pix(tree_art, cx - 6, by - 16, lean)
    else
      local sx, sy = 0, 0
      if hit and hit.id == p.id and hit.t > 12 then
        sx, sy = abs(hit.dx), abs(hit.dy)
        cx = cx + hit.dx
      end
      if shake and shake.id == p.id then cx = cx + sin(shake.t / 6) * 2 end
      if held == p.id and not anim then by = by - 1 - flr(frame / 10) % 2 end
      -- a stack sways more the higher up a piece is
      draw_piece(p, cx, by - e[5], p.stack == "lmh", lean * (1 + e[5] / 15), sx, sy)
    end
  end
end

local function draw_hud()
  rectfill(0, 0, 127, 8, 1)
  print(lvl, 2, 2, 10)
  print(levels[lvl][1], 14, 2, 7)
  local s = #hist .. "/" .. levels[lvl][2]
  print(s, 126 - text_w(s), 2, #hist > levels[lvl][2] and 9 or 6)

  rectfill(0, 119, 127, 127, 1)
  local hint = ""
  local p = held_piece()
  if won then
    hint = "\142 next level"
  elseif p then
    hint = #rules_moves(st, p) == 0 and "stuck!  \151 put down" or "\139\145\148\131 send it  \151 put down"
  elseif rules_movable_at(st, cur.x, cur.y) then
    hint = "\142 pick up the " .. names[rules_movable_at(st, cur.x, cur.y).kind]
  elseif #hist > 0 then
    hint = "\151 undo  hold \151 restart  p menu"
  elseif not intro then
    hint = "find a stone        p menu"
  end
  if xhold > 4 and #hist > 0 then
    rectfill(0, 119, xhold * 6.4, 119, 10)
  end
  cprint(hint, 121, 6)
end

local function panel(x0, y0, x1, y1)
  rectfill(x0 + 2, y0 + 2, x1 + 2, y1 + 2, 1)
  rectfill(x0, y0, x1, y1, 7)
  rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, 6)
end

local function draw_play()
  draw_sea()
  draw_island()
  draw_targets()
  draw_things()
  for p in all(bits) do
    pset(p.x, p.y, p.c)
  end
  for p in all(pollen) do
    pset(p.x, p.y, 10)
  end
  if not (intro or outro or anim or won) then
    local x0, y0 = ox + (cur.x - 1) * 16, oy + (cur.y - 1) * 16
    local c = held and 10 or (frame % 40 < 20 and 7 or 6)
    corners(x0 - 1, y0 - 1, x0 + 16, y0 + 16, 3, c)
  end
  draw_hud()

  if won and won > 10 then
    -- over the half of the board with fewer cairns on it
    local y, far = 84, 0
    for p in all(st.pieces) do
      if p.y < 3 then far = far + 1 end
    end
    if far * 2 < #st.pieces then y = 12 end
    panel(34, y, 93, y + 14)
    cprint("cairns built!", y + 5, 3)
  end
  if menu then
    panel(26, 48, 101, 72)
    for i = 1, #menu_items do
      local y = 45 + i * 9
      local on = i == menu.row
      if on then print("\145", 30, y, 8) end
      print(menu_items[i], 40, y, on and 1 or 13)
    end
  end
end

-- the logo's pixels: { x, y, top edge, bottom edge }, 2x2 each
local logo_px = {}
local lx = 22
for g in all(logo) do
  local w, bits = g[1], g[2]
  local function on(i, j)
    return j >= 0 and j < 8 and sub(bits, j * w + i + 1, j * w + i + 1) == "1"
  end
  for j = 0, 7 do
    for i = 0, w - 1 do
      if on(i, j) then
        add(logo_px, { lx + i * 2, 14 + j * 2, not on(i, j - 1), not on(i, j + 1) })
      end
    end
  end
  if w == 2 then flag_x = lx + 1 end
  lx = lx + w * 2 + 4
end

local function draw_title()
  draw_sea()
  for p in all(pollen) do
    pset(p.x, p.y, 7)
  end

  -- the logo, carved stone with moss on top, and a flag on the i
  for pass = 1, 3 do
    for q in all(logo_px) do
      local x, y = q[1], q[2]
      if pass == 1 then
        rectfill(x - 1, y - 1, x + 2, y + 4, 1)
      elseif pass == 2 then
        rectfill(x, y, x + 1, y + 1, q[4] and 5 or 6)
      else
        if q[3] then
          line(x, y, x + 1, y, (x * 7 + y) % 5 < 2 and 11 or 7)
        end
        if q[4] then line(x, y + 1, x + 1, y + 1, 13) end
      end
    end
  end
  draw_pix(flag_art[flr(frame / 12) % 2 + 1], flag_x, 1)
  cprint("roll stones, plant flags", 41, 1)

  -- the level grid
  local n = unlocked()
  panel(5, 48, 122, 100)
  for i = 1, #levels do
    local cx, cy = 9 + (i - 1) % 10 * 11, 53 + flr((i - 1) / 10) * 15
    local open = i <= n
    rectfill(cx, cy, cx + 9, cy + 12, i == lvl and 10 or open and 11 or 6)
    if i == lvl then
      corners(cx - 1, cy - 1, cx + 10, cy + 13, 2, frame % 40 < 20 and 8 or 2)
    end
    local s = tostr(i)
    print(s, cx + 6 - #s * 2, cy + 6, open and 3 or 13)
    if dget(i) > 0 then
      line(cx + 1, cy + 1, cx + 1, cy + 4, 4)
      line(cx + 2, cy + 1, cx + 3, cy + 1, 8)
      pset(cx + 2, cy + 2, 8)
    end
  end

  -- the picked level
  rectfill(0, 107, 127, 127, 1)
  local lv = levels[lvl]
  if lvl <= n then
    cprint(lv[1], 111, 7)
    cprint("\142 play", 119, 10)
  else
    cprint("solve " .. (lvl - 1) .. " to open it", 115, 6)
  end
end

function _draw()
  if scene == "title" then
    draw_title()
  else
    draw_play()
  end
end

