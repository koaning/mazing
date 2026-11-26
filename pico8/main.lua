-- main.lua
-- title + level select, the level drawn from the sprite sheet, walking
-- and pushing animations, undo and restart, swapping between you and
-- partner, the in-game menu, saved progress, sfx and music. the rules
-- live in rules.lua, levels in levels.lua.

-- the sprite sheet (__gfx__), 8x8 sprites from koaning/sokoban's
-- "sandstone" design:
--   1-7   wall pieces: top left, across, top right, along, bottom left,
--         bottom right, top. a wall is drawn as four 4x4 quarters
--   8-11  water, inner corners (top left, top right, bottom left, right)
--   12    the marker over the one you play
--   16-31 water, by which sides are land (1 up, 2 right, 4 down, 8 left)
--   32 goal, 33 crate, 34 crate on a goal, 35 rock, 36 sunken rock,
--   37/38 switch (pressed), 39/40 green wall shut/open, 41/42 door
--   frame (across/side), 43/44 shut, 45/46 open, 47 way in
--   48-54 you: front, stepping, back, stepping, side, stepping, pushing.
--         partner is you in other colours (pal 13->4, 12->14)

-- sfx (see tools/music.lua):
-- 0 step, 1 push, 2 splash, 3 sink, 4 switch, 5 door opens, 6 undo,
-- 7 solved, 8 bump, 9 swap. one song plays all the time, from
-- pattern 0, on channels 0-1 (mask 3) so sfx keep 2-3.

-- saved progress:
-- dget(0) highest level solved, dget(i) 1 once level i is solved,
-- dget(63) the level played last
cartdata("koaning_mazing")

-- the screen palette: sandstone, with a few of pico-8's extra colours
pal({ [0] = 133, 134, 2, 3, 132, 5, 6, 7, 136, 9, 135, 139, 12, 140, 142, 15 }, 1)

-- which wall piece a quarter takes, for none / beside / along / inner
-- corner / full, one string per quarter (top left, right, bottom l, r)
local wall_q = { "12467", "32457", "52437", "62417" }
local menu_items = { "resume", "restart", "back to levels" }

-- logo letters, 8 rows each, drawn 2x as carved sandstone
local logo = {
  "011110110011110000011110000011000011110011011110",
  "011110110011110011110011110011110011110011011110",
  "110011110011110110111100111100110110110011110011",
  "011110110011110011110011110011110011110011011110",
  "111110110011110011111110110011110011110011111110",
  "011110110011110011111111110011110011110011110011",
  "110011111011111111110111110011110011110011110011",
}

local scene = "title"

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
local lv, st, hist = nil, nil, {}
-- who is played, which way each one faces (a button), who pushed last
local who, face, pushed = 1, {}, {}
local ox, oy = 0, 0
local anim, won, menu, intro, outro, bump = nil
-- a direction pressed while something moved, and how long one is held
local queued, holdf = nil, {}
local xhold, frame = 0, 0
local bits = {}

local function unlocked()
  return min(dget(0) + 1, #levels)
end

-- a square's top left on the screen
local function sx_of(i) return ox + i % lv.w * 8 end
local function sy_of(i) return oy + flr(i / lv.w) * 8 end

local function inside_guys()
  local list = {}
  for k = 1, #st.p do
    if st.p[k] >= 0 then add(list, k) end
  end
  return list
end

local function open_exits()
  local n = 0
  for e in all(lv.exits) do
    if rules_open(lv, st, e) then n = n + 1 end
  end
  return n
end

local function start_level(n)
  lvl = n
  lv = rules_parse(levels[n][2], levels[n][3])
  st = rules_new(lv)
  hist, who, face, pushed = {}, 1, { 3, 3 }, {}
  anim, won, menu, outro, bump, queued, bits = nil, nil, nil, nil, nil, nil, {}
  ox, oy = flr((128 - lv.w * 8) / 2), 9 + flr((110 - lv.h * 8) / 2)
  intro = 0
  dset(63, n)
end

local function restart()
  if #hist > 0 then
    st, hist, who, anim, won, pushed = rules_new(lv), {}, 1, nil, nil, {}
    sfx(6)
  end
end

local function undo()
  if #hist > 0 then
    local h = deli(hist)
    st, who, anim, pushed = h.s, h.who, nil, {}
    sfx(6)
  end
end

local function to_title()
  scene, menu, outro = "title", nil, nil
end

local function play(n)
  scene = "play"
  start_level(n)
end

-- solved: on to the next level right away
local function solved()
  won, outro = true, 0
  sfx(7)
  if lvl > dget(0) then dset(0, lvl) end
  dset(lvl, 1)
end

local function splash(i)
  for k = 1, 10 do
    add(bits, {
      x = sx_of(i) + 4, y = sy_of(i) + 4, vx = rnd(1.6) - 0.8, vy = -0.6 - rnd(1),
      c = k % 2 == 0 and 7 or 12, t = 14 + rnd(10),
    })
  end
end

-- how far (in squares) the moved crate has got after t frames: the push
-- takes as long as a step, floating on is a little quicker per square
local function crate_dist(t)
  return t < 6 and t / 6 or 1 + (t - 6) / 5
end

-- walk the one being played one square, pushing what is in the way
local function step(b)
  local d = dirs[b + 1]
  face[who] = b
  local m = rules_move(lv, st, d, who)
  if not m then
    pushed[who] = false
    bump = { k = who, t = 8 }
    sfx(8)
    return
  end
  add(hist, { s = st, who = who })
  local open, press = open_exits(), rules_pressed(lv, st)
  st = m.s
  pushed[who] = m.crate or m.rock
  local dist = 0
  if m.crate then
    local a, e = m.to, m.cto
    dist = abs(a % lv.w - e % lv.w) + abs(flr(a / lv.w) - flr(e / lv.w))
  end
  anim = { m = m, who = who, t = 0, dist = dist, dur = max(6, 6 + (dist - 1) * 5),
    door = open_exits() > open, click = rules_pressed(lv, st) ~= press }
  sfx(m.crate and 1 or m.rock and 1 or 0)
  if m.out then
    -- he walked out: play the other one, if he's still in
    local list = inside_guys()
    if #list > 0 then who = list[1] end
  end
end

-- the move animation is done
local function land()
  local a, m = anim, anim.m
  anim = nil
  if m.sank then
    splash(m.rto)
    sfx(3)
  end
  if a.click then sfx(4) end
  if a.door then sfx(5) end
  if rules_won(lv, st) then solved() end
end

local function swap()
  local list = inside_guys()
  if #list > 1 then
    who = who == list[1] and list[2] or list[1]
    sfx(9)
  end
end

-------------------------------------------------------------
-- update
-------------------------------------------------------------

local function update_title()
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
    if lvl <= unlocked() then
      play(lvl)
    else
      sfx(8)
    end
  end
end

local function update_menu()
  if btnp(2) then menu.row = (menu.row - 2) % #menu_items + 1 end
  if btnp(3) then menu.row = menu.row % #menu_items + 1 end
  if btnp(5) or pause then
    menu = nil
    return
  end
  if ok() then
    local r = menu.row
    menu = nil
    if r == 2 then restart() end
    if r == 3 then to_title() end
  end
end

local function update_play()
  for p in all(bits) do
    p.x, p.y, p.vy, p.t = p.x + p.vx, p.y + p.vy, p.vy + 0.12, p.t - 1
    if p.t < 0 then del(bits, p) end
  end
  if bump then
    bump.t = bump.t - 1
    if bump.t <= 0 then bump = nil end
  end

  if intro then
    intro = intro + 1
    if intro > 20 then intro = nil end
    return
  end
  if outro then
    outro = outro + 1
    if outro > 20 then
      if lvl < #levels then
        start_level(lvl + 1)
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
  if pause then
    menu = { row = 1 }
    sfx(0)
    return
  end
  if rkey then restart() end

  -- tap ❎ to undo, hold it to restart
  if btn(5) then
    xhold = xhold + 1
    if xhold == 20 then restart() end
  else
    if xhold > 0 and xhold < 20 then undo() end
    xhold = 0
  end
  if ok() then swap() end

  -- a press is kept until the move before it is done; holding a
  -- direction keeps walking that way
  for b = 0, 3 do
    holdf[b] = btn(b) and (holdf[b] or 0) + 1 or 0
    if btnp(b) then queued = b end
  end
  if anim then
    local a = anim
    a.t = a.t + 1
    if a.m.crate and a.t == 6 and rules_water(lv, st, rules_step(lv, a.m.to, dirs[face[a.who] + 1])) then
      splash(rules_step(lv, a.m.to, dirs[face[a.who] + 1]))
      sfx(2)
    end
    if a.t >= a.dur then land() end
    return
  end
  if not queued then
    for b = 0, 3 do
      if holdf[b] > 12 then queued = b end
    end
  end
  if queued then
    step(queued)
    queued = nil
  end
end

function _update60()
  frame = frame + 1
  read_keys()
  if scene == "title" then
    update_title()
  else
    update_play()
  end
end

-------------------------------------------------------------
-- drawing
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

local function panel(x0, y0, x1, y1)
  rectfill(x0 + 2, y0 + 2, x1 + 2, y1 + 2, 0)
  rectfill(x0, y0, x1, y1, 4)
  rect(x0, y0, x1, y1, 15)
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

-- one quarter (q: 0 top left, 1 top right, 2 bottom left, 3 right) of
-- sprite n, drawn at x, y
local function quarter(n, q, x, y)
  local qx, qy = q % 2 * 4, flr(q / 2) * 4
  sspr(n % 16 * 8 + qx, flr(n / 16) * 8 + qy, 4, 4, x + qx, y + qy)
end

local function draw_board()
  local w, h = lv.w, lv.h
  local press = rules_pressed(lv, st)
  local function at(x, y)
    return x >= 0 and y >= 0 and x < w and y < h and lv.ch[y * w + x] or " "
  end
  -- water keeps its shape when it's filled in
  local function wet(x, y)
    return x >= 0 and y >= 0 and x < w and y < h and lv.water[y * w + x]
  end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local i, c = y * w + x, at(x, y)
      local sx, sy = ox + x * 8, oy + y * 8
      if lv.inside[i] or c == ">" or c == "<" then
        -- the floor, a faint checker
        if (x + y) % 2 == 1 then fillp(0x8020) end
        rectfill(sx, sy, sx + 7, sy + 7, 0x1f)
        fillp()
      end
      if c == "#" then
        rectfill(sx, sy, sx + 7, sy + 7, 4)
        for q = 0, 3 do
          local hx, vy = q % 2 * 2 - 1, flr(q / 2) * 2 - 1
          local b, a = wallish[at(x + hx, y)], wallish[at(x, y + vy)]
          local k = b and a and (wallish[at(x + hx, y + vy)] and 5 or 4) or b and 2 or a and 3 or 1
          quarter(tonum(sub(wall_q[q + 1], k, k)), q, sx, sy)
        end
      elseif c == ">" or c == "<" then
        local across = wallish[at(x - 1, y)] and wallish[at(x + 1, y)]
        local s = across and 41 or 42
        spr(s, sx, sy)
        if c == ">" then spr(s + (rules_open(lv, st, i) and 4 or 2), sx, sy) end
      end
      if lv.water[i] then
        local land, bit = 0, 1
        for d in all({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
          if not wet(x + d[1], y + d[2]) then land = land + bit end
          bit = bit * 2
        end
        spr(16 + land, sx, sy)
        for q = 0, 3 do
          local hx, vy = q % 2 * 2 - 1, flr(q / 2) * 2 - 1
          if wet(x + hx, y) and wet(x, y + vy) and not wet(x + hx, y + vy) then
            quarter(8 + q, q, sx, sy)
          end
        end
        -- a sunken rock, once it's down
        for f in all(st.f) do
          if f == i and not (anim and anim.m.rto == i) then spr(36, sx, sy) end
        end
      end
      if c == "_" then spr(press and 38 or 37, sx, sy) end
      if lv.green[i] then spr(rules_shut(lv, st, i, press) and 39 or 40, sx, sy) end
      if lv.goal[i] then spr(32, sx, sy) end
    end
  end
end

-- where a thing moving from square a to e is after k squares of n
local function lerp(a, e, k, n)
  local t = n > 0 and min(k / n, 1) or 1
  return sx_of(a) + (sx_of(e) - sx_of(a)) * t, sy_of(a) + (sy_of(e) - sy_of(a)) * t
end

local function draw_things()
  local m = anim and anim.m
  for k = 1, #st.c do
    local i = st.c[k]
    local x, y = sx_of(i), sy_of(i)
    local moving = m and m.crate == k
    if moving then
      x, y = lerp(m.to, i, crate_dist(anim.t), anim.dist)
    elseif rules_water(lv, st, i) then
      -- floating: it bobs
      y = y + flr(frame / 20) % 2
    end
    spr(lv.goal[i] and not moving and 34 or 33, x, y)
  end
  for i in all(st.r) do
    if not (m and m.rto == i) then spr(35, sx_of(i), sy_of(i)) end
  end
  if m and m.rock then
    local x, y = lerp(m.to, m.rto, anim.t, 6)
    spr(35, x, y + (m.sank and anim.t / 3 or 0))
  end

  local both = #inside_guys() > 1
  for k = 1, #st.p do
    local p, moving = st.p[k], m and anim.who == k
    if p >= 0 or moving then
      local x, y = sx_of(max(p, 0)), sy_of(max(p, 0))
      if moving then x, y = lerp(m.from, m.to, anim.t, 6) end
      if bump and bump.k == k then x = x + sin(bump.t / 8) end
      -- the pose: which way he faces, mid step, pushing
      local b, n, flip = face[k], 48, false
      if b < 2 then
        n, flip = pushed[k] and 54 or moving and 53 or 52, b == 0
      else
        n = b == 2 and 50 or 48
        if moving then n, flip = n + 1, #hist % 2 == 1 end
      end
      if k == 2 then
        pal(13, 4)
        pal(12, 14)
      end
      spr(n, x, y, 1, 1, flip)
      pal(13, 13)
      pal(12, 12)
      if both and k == who and not won then spr(12, x, y - 6 - flr(frame / 20) % 2) end
    end
  end
end

local function draw_hud()
  rectfill(0, 0, 127, 8, 4)
  print(lvl, 2, 2, 10)
  print(levels[lvl][1], 14, 2, 7)
  local s = tostr(#hist)
  print(s, 126 - text_w(s), 2, 15)

  rectfill(0, 119, 127, 127, 4)
  local hint = "push every crate onto a goal"
  if #inside_guys() > 1 then
    hint = "\142 swap  \151 undo  p menu"
  elseif #hist > 0 then
    hint = "\151 undo  hold \151 restart  p menu"
  elseif lv.kind == "exit" then
    hint = "find the way out"
  end
  if xhold > 4 and #hist > 0 then
    rectfill(0, 119, xhold * 6.4, 119, 10)
  end
  cprint(hint, 121, 15)
end

local function draw_play()
  cls(0)
  local r = intro and intro * 4 or outro and (20 - outro) * 4
  if r then clip(64 - r, 64 - r, r * 2, r * 2) end
  draw_board()
  draw_things()
  for p in all(bits) do
    pset(p.x, p.y, p.c)
  end
  clip()
  draw_hud()

  if menu then
    panel(26, 44, 101, 78)
    for i = 1, #menu_items do
      local y = 41 + i * 9
      local on = i == menu.row
      if on then print("\145", 30, y, 9) end
      print(menu_items[i], 40, y, on and 7 or 1)
    end
  end
end

-- the logo's pixels: { x, y, top edge, bottom edge }, 2x2 each
local logo_px = {}
for n = 1, #logo do
  local bits_ = logo[n]
  local function on(i, j)
    return j >= 0 and j < 8 and sub(bits_, j * 6 + i + 1, j * 6 + i + 1) == "1"
  end
  for j = 0, 7 do
    for i = 0, 5 do
      if on(i, j) then
        add(logo_px, { n * 16 - 6 + i * 2, 8 + j * 2, not on(i, j - 1), not on(i, j + 1) })
      end
    end
  end
end

local function draw_title()
  cls(0)
  -- the logo, carved sandstone
  for pass = 1, 3 do
    for q in all(logo_px) do
      local x, y = q[1], q[2]
      if pass == 1 then
        rectfill(x - 1, y - 1, x + 2, y + 4, 4)
      elseif pass == 2 then
        rectfill(x, y, x + 1, y + 1, q[4] and 1 or 15)
      elseif q[3] then
        line(x, y, x + 1, y, 7)
      end
    end
  end

  -- a crate pushed along a strip of floor
  rectfill(0, 32, 127, 39, 15)
  local x = frame / 2 % 168 - 24
  spr(54, x, 32)
  spr(33, x + 8, 32)
  cprint("push crates, walk out", 42, 15)

  -- the level grid
  local n = unlocked()
  panel(5, 50, 122, 100)
  for i = 1, #levels do
    local cx, cy = 9 + (i - 1) % 10 * 11, 54 + flr((i - 1) / 10) * 15
    local open = i <= n
    rectfill(cx, cy, cx + 9, cy + 12, i == lvl and 10 or open and 15 or 1)
    if i == lvl then
      corners(cx - 1, cy - 1, cx + 10, cy + 13, 2, frame % 40 < 20 and 9 or 4)
    end
    local s = tostr(i)
    print(s, cx + 6 - #s * 2, cy + 6, open and 4 or 7)
    if dget(i) > 0 then
      -- a little crate on a goal: solved
      rectfill(cx + 1, cy + 1, cx + 3, cy + 3, 9)
      pset(cx + 2, cy + 2, 8)
    end
  end

  -- the picked level
  rectfill(0, 107, 127, 127, 4)
  if lvl <= n then
    cprint(levels[lvl][1], 111, 7)
    cprint("\142 play", 119, 10)
  else
    cprint("solve " .. (lvl - 1) .. " to open it", 115, 15)
  end
end

function _draw()
  if scene == "title" then
    draw_title()
  else
    draw_play()
  end
end
