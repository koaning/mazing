-- Finds new Mazing levels: random 7x5 boards, solved with the same
-- breadth-first search the tests use (tools/solve.lua on the cart's rules).
-- Prints candidates as levels.lua lines, sorted by fewest moves, to pick
-- from by hand (and give a name).
--
-- Usage (repo root):  luajit tools/genlevels.lua [tries] [seed]
--
-- A board is kept when it is solvable, takes at least a few moves per cairn,
-- and doesn't start with a piece already next to where it stacks (those tend
-- to play themselves). Boards already in pico8/levels.lua are skipped.

package.path = "tools/?.lua;" .. package.path
local pico8_env = require("pico8_env")
local solve = require("solve")

local tries = tonumber(arg[1]) or 3000
math.randomseed(tonumber(arg[2]) or os.time())

local env = pico8_env.new(".")
local W, H = env.board_w, env.board_h

local known = {}
for _, lv in ipairs(env.levels) do known[lv[3]] = true end

local function random_board()
  local cairns = math.random(1, 3)
  local trees = math.random(0, 4)
  local cells = {}
  for i = 1, W * H do cells[i] = "." end
  local function place(c)
    while true do
      local i = math.random(W * H)
      if cells[i] == "." then
        cells[i] = c
        return
      end
    end
  end
  for _ = 1, cairns do
    place("l"); place("m"); place("h")
  end
  for _ = 1, trees do place("t") end
  local rows = {}
  for y = 1, H do
    rows[y] = table.concat(cells, "", (y - 1) * W + 1, y * W)
  end
  return table.concat(rows, "|"), cairns
end

-- a small stone next to a big one, or a flag next to a big + small stack
local function has_free_stack(st)
  for _, p in ipairs(st.pieces) do
    for _, d in ipairs(env.dirs) do
      local m = env.rules_move(st, p, d[1], d[2])
      if m and m.kind == "stack" then return true end
    end
  end
  return false
end

local min_moves = { 6, 11, 16 }
local found, seen = {}, {}
for _ = 1, tries do
  local board, cairns = random_board()
  if not known[board] and not seen[board] then
    seen[board] = true
    local st = env.rules_parse(board)
    if not has_free_stack(st) then
      local moves, _, states = solve(env, st, 150000)
      if moves and moves >= min_moves[cairns] then
        found[#found + 1] = { board = board, moves = moves, states = states, cairns = cairns }
      end
    end
  end
end

table.sort(found, function(a, b)
  if a.moves ~= b.moves then return a.moves < b.moves end
  return a.states > b.states
end)
for _, f in ipairs(found) do
  print(string.format('  { "?", %d, "%s" }, -- %d cairns, %d states', f.moves, f.board, f.cairns, f.states))
end
io.stderr:write(#found .. " levels found in " .. tries .. " tries\n")
