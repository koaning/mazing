-- Breadth-first solver for the levels, on top of the cart's own rules
-- (pico8/rules.lua loaded through tools/pico8_env.lua), like the search()
-- of koaning/sokoban's js/sokoban.js. Used by tests/test_rules.lua to
-- check every level can be solved and by tests/cart_smoke.lua and the
-- preview's screenshot run to play levels through the cart.
--
--   local solve = require("solve")
--   local moves, path, states = solve(env, lv)   -- lv = env.rules_parse(...)
--
-- Returns the fewest number of moves and the moves themselves as a list of
-- { who, dir } (dir indexes env.dirs, which is in button order), or nil
-- when the level can't be solved.

local function sorted(list)
  local c = {}
  for i = 1, #list do c[i] = list[i] end
  table.sort(c)
  return table.concat(c, ",")
end

local function key(s)
  return table.concat(s.p, ",") .. ":" .. sorted(s.c) .. "|" .. sorted(s.r) .. "|" .. sorted(s.f)
end

-- squares a crate can never be got to a goal from: corners of the floor
-- that aren't goals, and water (a floating crate can't be pushed again)
-- unless a rock may fill it. only when every crate has to reach a goal.
local function dead_squares(env, lv)
  local dead = {}
  if lv.kind ~= "crates" then return dead end
  local function blocked(i, d)
    local j = env.rules_step(lv, i, env.dirs[d])
    return not j or not lv.inside[j]
  end
  for i = 0, lv.w * lv.h - 1 do
    if lv.inside[i] and not lv.goal[i] then
      if lv.water[i] and #lv.rocks == 0 then
        dead[i] = true
      elseif (blocked(i, 1) or blocked(i, 2)) and (blocked(i, 3) or blocked(i, 4)) then
        dead[i] = true
      end
    end
  end
  return dead
end

return function(env, lv, max_states)
  max_states = max_states or 2000000
  local dead = dead_squares(env, lv)
  local prune = lv.kind == "crates"
  local start = env.rules_new(lv)
  local parents = { [key(start)] = false }
  local frontier, count, depth = { start }, 1, 0

  local function path(k)
    local list = {}
    while parents[k] do
      table.insert(list, 1, parents[k].step)
      k = parents[k].key
    end
    return list
  end

  while #frontier > 0 do
    local nxt = {}
    for _, s in ipairs(frontier) do
      local k = key(s)
      if env.rules_won(lv, s) then return depth, path(k), count end
      for who = 1, #s.p do
        for d = 1, 4 do
          local m = env.rules_move(lv, s, env.dirs[d], who)
          local e = m and m.cto
          if m and not (e and not lv.goal[e] and (dead[e] or (prune and env.rules_water(lv, m.s, e)))) then
            local mk = key(m.s)
            if parents[mk] == nil then
              parents[mk] = { key = k, step = { who, d } }
              count = count + 1
              nxt[#nxt + 1] = m.s
              if count > max_states then return nil, nil, count end
            end
          end
        end
      end
    end
    frontier = nxt
    depth = depth + 1
  end
  return nil, nil, count
end
