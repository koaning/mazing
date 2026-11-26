-- rules.lua
-- the puzzle rules, ported from snowstack (koaning/ps-love2d).
-- written in the lua subset that both pico-8 and luajit accept
-- (no +=, no !=, no ?, no math./table./string.) so the test
-- suite can run it on a desktop.
--
-- pieces: l big stone, m small stone, h flag.
--  * a stone rolls in a straight line until the next square
--    holds a piece or a tree, and stops in front of it. a roll
--    that nothing stops isn't allowed: it would fall in the sea.
--  * a small stone next to a lone big stone hops on top of it,
--    a flag next to a big + small stack hops on top of that and
--    finishes the cairn. nothing else stacks.
--  * flags never roll, they can only hop onto a stack.
--  * a piece in a stack never moves again.
--  * solved when every piece is part of a finished cairn.

board_w, board_h = 7, 5

dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

-- what a stack turns into when a piece hops on top
stacks_onto = { m = { l = "lm" }, h = { lm = "lmh" } }

-- reads a board string (see levels.lua) into a state:
-- { w, h, trees = { [x + y * 16] = true }, pieces = { ... } }
function rules_parse(s)
  local st = { trees = {}, pieces = {}, w = 0, h = 1 }
  local x = 1
  for i = 1, #s do
    local c = sub(s, i, i)
    if c == "|" then
      x = 1
      st.h = st.h + 1
    else
      if c == "t" then
        st.trees[x + st.h * 16] = true
      elseif c ~= "." then
        add(st.pieces, { id = #st.pieces + 1, kind = c, x = x, y = st.h })
      end
      if x > st.w then st.w = x end
      x = x + 1
    end
  end
  return st
end

function rules_copy(st)
  local c = { trees = st.trees, pieces = {}, w = st.w, h = st.h }
  for p in all(st.pieces) do
    add(c.pieces, { id = p.id, kind = p.kind, x = p.x, y = p.y, stack = p.stack })
  end
  return c
end

function rules_on_board(st, x, y)
  return x >= 1 and x <= st.w and y >= 1 and y <= st.h
end

function rules_tree(st, x, y)
  return st.trees[x + y * 16]
end

-- what is on a square: "l", "m", "h", "lm", "lmh" or nil
function rules_content_at(st, x, y)
  for p in all(st.pieces) do
    if p.x == x and p.y == y then return p.stack or p.kind end
  end
end

-- the piece on a square that can still move
function rules_movable_at(st, x, y)
  for p in all(st.pieces) do
    if p.x == x and p.y == y and not p.stack then return p end
  end
end

-- where piece p goes when sent dx, dy:
-- { kind = "roll" or "stack", dx, dy, x, y, dist, stack }, or nil
function rules_move(st, p, dx, dy)
  if p.stack then return nil end
  local nx, ny = p.x + dx, p.y + dy
  if not rules_on_board(st, nx, ny) or rules_tree(st, nx, ny) then return nil end

  local nxt = rules_content_at(st, nx, ny)
  if nxt then
    local to = stacks_onto[p.kind] and stacks_onto[p.kind][nxt]
    if not to then return nil end
    return { kind = "stack", dx = dx, dy = dy, x = nx, y = ny, dist = 1, stack = to }
  end

  if p.kind == "h" then return nil end
  local dist = 1
  while true do
    local ax, ay = nx + dx, ny + dy
    if not rules_on_board(st, ax, ay) then return nil end
    if rules_tree(st, ax, ay) or rules_content_at(st, ax, ay) then break end
    nx, ny, dist = ax, ay, dist + 1
  end
  return { kind = "roll", dx = dx, dy = dy, x = nx, y = ny, dist = dist }
end

-- every move piece p can make, one per direction that works
function rules_moves(st, p)
  local list = {}
  for d in all(dirs) do
    local m = rules_move(st, p, d[1], d[2])
    if m then add(list, m) end
  end
  return list
end

function rules_apply(st, p, m)
  if m.kind == "stack" then
    for q in all(st.pieces) do
      if q.x == m.x and q.y == m.y then q.stack = m.stack end
    end
    p.stack = m.stack
  end
  p.x, p.y = m.x, m.y
end

function rules_cairns(st)
  local n = 0
  for p in all(st.pieces) do
    if p.kind == "h" and p.stack == "lmh" then n = n + 1 end
  end
  return n
end

-- solved when every piece is in a finished cairn
function rules_solved(st)
  if #st.pieces == 0 then return false end
  for p in all(st.pieces) do
    if p.stack ~= "lmh" then return false end
  end
  return true
end
