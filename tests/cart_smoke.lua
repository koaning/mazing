-- Cart smoke test: boots pico8/main.lua against stubbed PICO-8 graphics,
-- input and cartdata, then plays the game through its buttons: start from
-- the title, solve every level with the solver's moves (walking, pushing,
-- swapping between you and partner), and try undo, restart, bumping into
-- walls, the in-game menu and the saved progress along the way.
--
-- Run from the repo root:  luajit tests/cart_smoke.lua

package.path = "tools/?.lua;" .. package.path
local pico8_env = require("pico8_env")
local solve = require("solve")

local LEFT, RIGHT, UP, DOWN, O, X, PAUSE = 0, 1, 2, 3, 4, 5, 6
local ENTER = 40

local function noop() end

local function boot(saved)
  local env = pico8_env.new(".", pico8_env.make_rng(7))
  local pressed, holding = {}, {}
  local data = saved or {}

  for _, name in ipairs({ "cls", "rectfill", "rect", "circfill", "circ", "line", "print", "sfx", "music",
    "ovalfill", "pset", "fillp", "clip", "pal", "palt", "spr", "sspr", "cartdata", "menuitem", "poke" }) do
    rawset(env, name, noop)
  end
  rawset(env, "dget", function(i) return data[i] or 0 end)
  rawset(env, "dset", function(i, v) data[i] = v end)
  rawset(env, "del", function(t, v)
    for i = 1, #t do
      if t[i] == v then return table.remove(t, i) end
    end
  end)
  rawset(env, "ord", function(s, i) return string.byte(s, i or 1) end)
  rawset(env, "mid", function(a, b, c)
    if a > b then a, b = b, a end
    return math.max(a, math.min(b, c))
  end)
  rawset(env, "btnp", function(b) return pressed[b] == true end)
  rawset(env, "btn", function(b) return pressed[b] == true or holding[b] == true end)
  rawset(env, "sin", function(a) return -math.sin(a * 2 * math.pi) end)
  rawset(env, "cos", function(a) return math.cos(a * 2 * math.pi) end)
  -- devkit keyboard: stat(28, 40) is the enter key
  local keys = {}
  rawset(env, "stat", function(n, k) return n == 28 and keys[k] == true end)
  rawset(env, "stop", function(msg) error("cart stop(): " .. tostring(msg)) end)

  local src = assert(io.open("pico8/main.lua")):read("*a")
  src = src .. "\nfunction __peek() return { scene = scene, lv = lv, st = st, who = who, anim = anim,"
    .. " intro = intro, outro = outro, won = won, menu = menu, lvl = lvl, moves = #hist } end\n"
  local chunk = assert(loadstring(src, "@pico8/main.lua"))
  setfenv(chunk, env)
  chunk()

  local game = { env = env, data = data }

  function game.frame(buttons, hold, scancodes)
    pressed, holding, keys = {}, {}, {}
    for _, k in ipairs(scancodes or {}) do keys[k] = true end
    for _, b in ipairs(buttons or {}) do pressed[b] = true end
    for _, b in ipairs(hold or {}) do holding[b] = true end
    env._update60()
    env._draw()
  end

  function game.peek()
    return env.__peek()
  end

  -- runs frames until the cart is waiting for input again
  function game.settle()
    for _ = 1, 600 do
      local s = game.peek()
      if not (s.anim or s.intro or s.outro) then return s end
      game.frame()
    end
    error("cart never settled")
  end

  -- one solver step { who, dir }: swap to who with O if needed, then press the direction
  function game.step(step, last)
    local s = game.settle()
    if s.who ~= step[1] then
      game.frame({ O })
      assert(game.peek().who == step[1], "O should swap to the other one")
    end
    local before = game.peek().moves
    game.frame({ step[2] - 1 })
    assert(game.peek().moves == before + 1, "the move should count")
    if not last then game.settle() end
  end

  -- a tap of X: pressed for a frame, then let go
  function game.tap_x()
    game.frame({ X })
    game.frame()
  end

  -- the pause button (p / start) opens the in-game menu, then pick row r
  function game.menu(r)
    game.frame({ PAUSE }, { PAUSE })
    assert(game.peek().menu, "the pause button should open the menu")
    game.frame()
    for _ = 2, r do game.frame({ DOWN }) end
    game.frame({ O })
    assert(not game.peek().menu, "O should close the menu")
  end

  return game
end

local function solution(env, lvl)
  local l = env.levels[lvl]
  local moves, path = solve(env, env.rules_parse(l[2], l[3]))
  return path, moves
end

local game = boot()
local env = game.env
assert(game.peek().scene == "title", "the cart should boot into the title")

-- three levels are open on a fresh save, level 4 is locked
game.frame({ RIGHT })
game.frame({ RIGHT })
assert(game.peek().lvl == 3)
game.frame({ O })
assert(game.peek().scene == "play" and game.peek().lvl == 3, "level 3 is open on a fresh save")
game.settle()
game.menu(3)
assert(game.peek().scene == "title")
game.frame({ RIGHT })
assert(game.peek().lvl == 4)
game.frame({ O })
assert(game.peek().scene == "title", "level 4 is locked on a fresh save")
game.frame({ LEFT })
game.frame({ LEFT })
game.frame({ LEFT })
assert(game.peek().lvl == 1)

-- solving any open level unlocks the next so three unsolved stay open
local skip = boot()
skip.frame({ RIGHT })
skip.frame({ O })
assert(skip.peek().scene == "play" and skip.peek().lvl == 2)
local p2 = solution(skip.env, 2)
for k, st in ipairs(p2) do skip.step(st, k == #p2) end
while skip.peek().anim do skip.frame() end
skip.settle()
skip.menu(3)
assert(skip.peek().scene == "title")
-- cursor is on level 3; level 4 is now open, level 5 is still locked
skip.frame({ RIGHT })
assert(skip.peek().lvl == 4)
skip.frame({ O })
assert(skip.peek().scene == "play" and skip.peek().lvl == 4, "solving level 2 unlocks level 4")
skip.settle()
skip.menu(3)
skip.frame({ RIGHT })
assert(skip.peek().lvl == 5)
skip.frame({ O })
assert(skip.peek().scene == "title", "level 5 stays locked with only 1 solved")

-- enter is pico-8's pause button too: with the enter key down it selects
game.frame({ PAUSE }, { PAUSE }, { ENTER })
assert(game.peek().scene == "play", "enter on the title should start level 1")
local s = game.settle()
assert(s.lvl == 1 and s.moves == 0)

-- bumping into a wall isn't a move (level 1: the wall is right above you)
game.frame({ UP })
s = game.settle()
assert(s.moves == 0, "walking into a wall shouldn't count")

-- undo: one move, then a tap of X takes it back
local path = solution(env, 1)
game.step(path[1])
assert(game.peek().moves == 1, "a move should count")
game.tap_x()
assert(game.peek().moves == 0, "X should undo the move")

-- restart: hold X, press R (scancode 21), or pick it in the menu
game.step(path[1])
for _ = 1, 25 do game.frame({}, { X }) end
game.frame()
assert(game.peek().moves == 0, "holding X should restart the level")
assert(not game.peek().menu, "holding X shouldn't open the menu")
game.step(path[1])
game.frame({}, {}, { 21 })
game.frame()
assert(game.peek().moves == 0, "R should restart the level")
game.step(path[1])
game.menu(2)
assert(game.peek().moves == 0, "restart in the menu should restart the level")

-- the pause button (p / start) opens the menu, and closes it again
game.frame({ PAUSE })
assert(game.peek().menu, "the pause button should open the menu")
game.frame()
game.frame({ PAUSE })
assert(not game.peek().menu, "the pause button should close the menu")

-- O does nothing with one guy
game.frame({ O })
assert(game.peek().who == 1)

-- solve every level with the solver's moves, through the buttons
local played, swapped = 0, false
for lvl = 1, #env.levels do
  s = game.settle()
  assert(s.scene == "play" and s.lvl == lvl, "expected to be playing level " .. lvl .. ", got " .. tostring(s.lvl))
  local steps, n = solution(env, lvl)
  for k, step in ipairs(steps) do
    if step[1] == 2 then swapped = true end
    game.step(step, k == #steps)
  end
  -- the last move: once it's done, the level is solved and the next one starts on its own
  while game.peek().anim do game.frame() end
  s = game.peek()
  assert(s.won and s.outro, "level " .. lvl .. " should be solved, and move on")
  assert(s.moves == n, "level " .. lvl .. ": every move should count")
  assert(game.data[lvl] == 1, "level " .. lvl .. " should be saved as solved")
  assert(game.data[0] == lvl, "level " .. lvl .. " should unlock the next")
  game.settle()
  played = played + 1
end
assert(swapped, "some level should need partner")
assert(game.peek().scene == "title", "after the last level the game goes back to the title")

-- the menu's back to levels goes to the title too
game.frame({ O })
assert(game.peek().scene == "play")
game.settle()
game.menu(3)
assert(game.peek().scene == "title", "back to levels should go to the title")

-- saved progress survives a reboot: start on the last level played
local again = boot(game.data)
assert(again.peek().lvl == game.data[63], "the title should open on the last level played")
again.frame({ O })
assert(again.peek().scene == "play", "a solved level can be played again")

print("Cart smoke: " .. played .. " levels solved through the buttons, undo, restart, swap, menu and saves work.")
