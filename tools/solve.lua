-- Breadth-first solver for Cairns levels, on top of the cart's own rules
-- (pico8/rules.lua loaded through tools/pico8_env.lua). Used by
-- tests/test_rules.lua to check every level's fewest moves and by
-- tests/cart_smoke.lua to play levels through the cart.
--
--   local solve = require("solve")
--   local moves, path, states = solve(env, env.rules_parse(board))
--
-- Returns the fewest number of moves and the moves themselves as
-- { x, y, dx, dy } (the piece's square and the way it went), or nil when the
-- level can't be solved.

-- the same for two states with the same things on the same squares,
-- whichever piece is which
local function key(st)
  local seen, parts = {}, {}
  for _, p in ipairs(st.pieces) do
    local sq = p.x .. "," .. p.y
    if not seen[sq] then
      seen[sq] = true
      parts[#parts + 1] = sq .. (p.stack or p.kind)
    end
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

return function(env, start, max_states)
  max_states = max_states or 2000000
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
    for _, st in ipairs(frontier) do
      local k = key(st)
      if env.rules_solved(st) then return depth, path(k), count end
      for i, p in ipairs(st.pieces) do
        if not p.stack then
          for _, d in ipairs(env.dirs) do
            local m = env.rules_move(st, p, d[1], d[2])
            if m then
              local c = env.rules_copy(st)
              env.rules_apply(c, c.pieces[i], m)
              local ck = key(c)
              if parents[ck] == nil then
                parents[ck] = { key = k, step = { p.x, p.y, d[1], d[2] } }
                count = count + 1
                nxt[#nxt + 1] = c
                if count > max_states then return nil, nil, count end
              end
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
