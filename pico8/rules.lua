-- rules.lua
-- the puzzle rules, ported from koaning/sokoban (js/sokoban.js and
-- js/goals.js). written in the lua subset that both pico-8 and luajit
-- accept (no +=, no !=, no ?, no math./table./string.) so the test
-- suite can run it on a desktop.
--
--  * you push crates and rocks one square over the floor, never onto
--    a door, and you can't pull them.
--  * you can't step into water. a crate pushed into water floats on
--    the same way: it stops on the first land it reaches, or stays
--    floating in front of anything solid, where it can't be pushed
--    again. a rock pushed into water sinks and fills it: that square
--    is ground from then on.
--  * while anything stands on a green switch (_), every green wall
--    flips: shut ones (G) open, open ones (g) shut. a green wall never
--    shuts on something standing in it.
--  * the way out (>) opens when every crate on its side of the level
--    is on a goal. walk out through it to win; with you and partner,
--    both have to get out. a level without a way out is won as soon as
--    its goal is met. "exit" levels have the way out open from the start.
--
-- a level is w by h squares, a square is i = y * w + x, 0 at the top
-- left. a state is { p = the square of each guy (-1 once he walked
-- out), c = crates, r = rocks, f = water filled by a sunken rock }.

-- in the order of pico-8's buttons: left, right, up, down
dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

wallish = { ["#"] = true, [">"] = true, ["<"] = true }

local function has(list, v)
  for x in all(list) do
    if x == v then return true end
  end
end

local function index_of(list, v)
  for k = 1, #list do
    if list[k] == v then return k end
  end
end

-- the square next to i going d, or nil off the board
function rules_step(lv, i, d)
  local x, y = i % lv.w + d[1], flr(i / lv.w) + d[2]
  if x >= 0 and y >= 0 and x < lv.w and y < lv.h then return y * lv.w + x end
end

-- reads a board (see levels.lua) into a level: { w, h, ch, inside,
-- goal, water, green, region, players, crates, rocks, exits, switches }
function rules_parse(s, goal)
  local lv = { w = 0, ch = {}, inside = {}, goal = {}, water = {}, green = {}, region = {},
    players = {}, crates = {}, rocks = {}, exits = {}, switches = {}, kind = goal or "crates" }
  local rows, row = {}, ""
  for i = 1, #s do
    local c = sub(s, i, i)
    if c == "|" then
      add(rows, row)
      row = ""
    else
      row = row .. c
    end
  end
  add(rows, row)
  lv.h = #rows
  for r in all(rows) do
    lv.w = max(lv.w, #r)
  end
  for y = 0, lv.h - 1 do
    for x = 0, lv.w - 1 do
      local c, i = sub(rows[y + 1], x + 1, x + 1), y * lv.w + x
      if c == "" then c = " " end
      lv.ch[i] = c
      if c == ">" then add(lv.exits, i) end
      if c == "@" or c == "+" then lv.players[1] = i end
      if c == "&" then lv.players[2] = i end
    end
  end

  -- the inside: a flood fill from each guy that stops at walls and
  -- doors. each flood is an area of its own, with its own way out
  for p in all(lv.players) do
    if not lv.inside[p] then
      local stack = { p }
      lv.inside[p], lv.region[p] = true, p
      while #stack > 0 do
        local i = deli(stack)
        for d in all(dirs) do
          local j = rules_step(lv, i, d)
          if j and not lv.inside[j] and not wallish[lv.ch[j]] then
            lv.inside[j], lv.region[j] = true, p
            add(stack, j)
          end
        end
      end
    end
  end
  for i = 0, lv.w * lv.h - 1 do
    local c = lv.ch[i]
    if lv.inside[i] then
      lv.goal[i] = c == "." or c == "*" or c == "+"
      if c == "$" or c == "*" then add(lv.crates, i) end
      if c == "o" then add(lv.rocks, i) end
      lv.water[i] = c == "~"
      if c == "_" then add(lv.switches, i) end
      if c == "G" then lv.green[i] = 1 end
      if c == "g" then lv.green[i] = 2 end
    end
  end
  -- a way out belongs to the area of the floor next to it
  for e in all(lv.exits) do
    for d in all(dirs) do
      local j = rules_step(lv, e, d)
      if j and lv.inside[j] then lv.region[e] = lv.region[j] end
    end
  end
  return lv
end

local function copy(list)
  local out = {}
  for v in all(list) do
    add(out, v)
  end
  return out
end

function rules_new(lv)
  return { p = copy(lv.players), c = copy(lv.crates), r = copy(lv.rocks), f = {} }
end

function rules_copy(s)
  return { p = copy(s.p), c = copy(s.c), r = copy(s.r), f = copy(s.f) }
end

-- water that no rock has filled
function rules_water(lv, s, i)
  return lv.water[i] and not has(s.f, i)
end

function rules_taken(s, i)
  return has(s.p, i) or has(s.c, i) or has(s.r, i)
end

-- whether anything stands on a green switch
function rules_pressed(lv, s)
  for i in all(lv.switches) do
    if rules_taken(s, i) then return true end
  end
end

-- whether the green wall at i is shut (press: rules_pressed, if known)
function rules_shut(lv, s, i, press)
  local g = lv.green[i]
  if not g then return false end
  if press == nil then press = rules_pressed(lv, s) end
  return (g == 1) == not press and not rules_taken(s, i)
end

-- the way out at square e is open
function rules_open(lv, s, e)
  if lv.kind == "exit" then return true end
  for i in all(s.c) do
    if lv.region[i] == lv.region[e] and not lv.goal[i] then return false end
  end
  return true
end

-- every crate on a goal (or, for "exit" levels, nothing to do)
function rules_met(lv, s)
  if lv.kind == "exit" then return true end
  for i in all(s.c) do
    if not lv.goal[i] then return false end
  end
  return #s.c > 0
end

-- the goal is met and everyone walked out (if there is a way out)
function rules_won(lv, s)
  if not rules_met(lv, s) then return false end
  for p in all(s.p) do
    if #lv.exits > 0 and p >= 0 then return false end
  end
  return true
end

-- guy `who` walks one square going d, pushing what is in the way.
-- returns nil if he can't, else { s = the new state, from, to, and
-- crate (its index), cto (where it ended up), or rock, rto, sank, or
-- out (he walked out) }. the old state is left alone.
function rules_move(lv, s, d, who)
  local p = s.p[who]
  if not p or p < 0 then return end
  local to = rules_step(lv, p, d)
  if not to or not (lv.inside[to] or lv.ch[to] == ">") then return end
  if rules_water(lv, s, to) or has(s.p, to) then return end
  local press = rules_pressed(lv, s)
  if rules_shut(lv, s, to, press) then return end

  -- squares nothing can be pushed (or float) into
  local function solid(j)
    return not j or not lv.inside[j] or rules_taken(s, j) or rules_shut(lv, s, j, press)
  end

  local n = rules_copy(s)
  local m = { s = n, from = p, to = to }
  n.p[who] = to
  local k = index_of(s.c, to)
  if k then
    local e = rules_step(lv, to, d)
    if solid(e) then return end
    -- a crate floats on while there's water ahead, and onto land
    while rules_water(lv, s, e) and not solid(rules_step(lv, e, d)) do
      e = rules_step(lv, e, d)
    end
    n.c[k], m.crate, m.cto = e, k, e
    return m
  end
  k = index_of(s.r, to)
  if k then
    local e = rules_step(lv, to, d)
    if solid(e) then return end
    m.rock, m.rto = true, e
    if rules_water(lv, s, e) then
      -- it sinks, and the water becomes ground
      deli(n.r, k)
      add(n.f, e)
      m.sank = true
    else
      n.r[k] = e
    end
    return m
  end
  if lv.inside[to] then return m end
  if rules_open(lv, s, to) then
    n.p[who], m.out = -1, true
    return m
  end
end
