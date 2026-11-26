-- Cart smoke test: boots pico8/main.lua against stubbed PICO-8 graphics,
-- input and cartdata, then plays the game through its buttons: start from
-- the title, solve every level with the solver's moves (walking the cursor,
-- picking stones up and sending them), and try undo, restart, the in-game menu
-- (back to levels) and the saved progress along the way.
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
    "ovalfill", "pset", "fillp", "clip", "pal", "cartdata", "menuitem", "poke" }) do
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
  src = src .. "\nfunction __peek() return { scene = scene, st = st, cur = cur, held = held, anim = anim,"
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

  function game.walk(tx, ty)
    for _ = 1, 20 do
      local cur = game.peek().cur
      if cur.x == tx and cur.y == ty then return end
      local b = cur.x < tx and RIGHT or cur.x > tx and LEFT or cur.y < ty and DOWN or UP
      game.frame({ b })
    end
    error("cursor didn't reach " .. tx .. "," .. ty)
  end

  -- one solver step: put down whatever is held, pick up the piece, send it
  function game.step(step)
    local s = game.settle()
    if s.held then game.frame({ O }) end
    game.walk(step[1], step[2])
    game.frame({ O })
    assert(game.peek().held, "O on a stone should pick it up")
    local b = step[3] < 0 and LEFT or step[3] > 0 and RIGHT or step[4] < 0 and UP or DOWN
    game.frame({ b })
    assert(game.peek().anim, "sending the stone should start its animation")
    game.settle()
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
  local moves, path = solve(env, env.rules_parse(env.levels[lvl][3]))
  return path, moves
end

local game = boot()
local env = game.env
assert(game.peek().scene == "title", "the cart should boot into the title")

-- a locked level can't be started
game.frame({ RIGHT })
assert(game.peek().lvl == 2)
game.frame({ O })
assert(game.peek().scene == "title", "level 2 is locked on a fresh save")
game.frame({ LEFT })

-- enter is pico-8's pause button too: with the enter key down it selects
game.frame({ PAUSE }, { PAUSE }, { ENTER })
assert(game.peek().scene == "play", "enter on the title should start level 1")
local s = game.settle()
assert(s.lvl == 1 and s.moves == 0)

-- undo: one move, then a tap of X takes it back
local path = solution(env, 1)
game.step(path[1])
assert(game.peek().moves == 1, "a move should count")
game.tap_x()
s = game.peek()
assert(s.moves == 0, "X should undo the move")

-- restart: hold X, or press R (scancode 21)
game.step(path[1])
for _ = 1, 25 do game.frame({}, { X }) end
game.frame()
assert(game.peek().moves == 0, "holding X should restart the level")
assert(not game.peek().menu, "holding X shouldn't open the menu")
game.step(path[1])
game.frame({}, {}, { 21 })
game.frame()
assert(game.peek().moves == 0, "R should restart the level")

-- picking up and putting down, with O and with enter
game.walk(path[1][1], path[1][2])
game.frame({ O })
assert(game.peek().held, "O should pick up a stone")
game.frame({ O })
assert(not game.peek().held, "O again should put it down")
game.frame({ PAUSE }, { PAUSE }, { ENTER })
assert(game.peek().held and not game.peek().menu, "enter should pick up a stone, not open the menu")
game.frame({}, { PAUSE }, { ENTER })
game.frame({ O })
assert(not game.peek().held)

-- the pause button (p / start) opens the menu, and closes it again
game.frame({ PAUSE })
assert(game.peek().menu, "the pause button should open the menu")
game.frame()
game.frame({ PAUSE })
assert(not game.peek().menu, "the pause button should close the menu")

-- solve every level with the fewest moves, through the buttons
local played = 0
for lvl = 1, #env.levels do
  s = game.settle()
  assert(s.scene == "play" and s.lvl == lvl, "expected to be playing level " .. lvl .. ", got " .. tostring(s.lvl))
  local steps, best = solution(env, lvl)
  for _, step in ipairs(steps) do game.step(step) end
  s = game.peek()
  assert(s.won, "level " .. lvl .. " should be solved")
  assert(s.moves == best, "level " .. lvl .. " moves")
  assert(game.data[lvl] == best, "level " .. lvl .. " fewest moves should be saved")
  assert(game.data[0] == lvl, "level " .. lvl .. " should unlock the next")
  for _ = 1, 30 do game.frame() end
  game.frame({ O })
  for _ = 1, 60 do game.frame() end
  played = played + 1
end
assert(game.peek().scene == "title", "after the last level the game goes back to the title")

-- the menu's level select goes back to the title too
game.frame({ O })
assert(game.peek().scene == "play")
game.settle()
game.menu(2)
assert(game.peek().scene == "title", "back to levels should go to the title")

-- saved progress survives a reboot: start on the last level played
local again = boot(game.data)
assert(again.peek().lvl == game.data[63], "the title should open on the last level played")
again.frame({ O })
assert(again.peek().scene == "play", "a solved level can be played again")

print("Cart smoke: " .. played .. " levels solved through the buttons, undo, menu and saves work.")
