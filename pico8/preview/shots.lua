-- Scripted run for `love cairns-p8.love --shots <dir> [--label <file>] [--all]`
-- (`make screenshots`). It presses the buttons for a player and saves:
--
--   pico8-cart.png    the title screen as a cartridge: the cart label with
--                     the cart's title and byline, like PICO-8 shows carts
--   pico8-title.png   the title screen with some levels solved
--   pico8.png         level 9 with one cairn built and a stone picked up
--   with --all also:  pico8-solved.png, pico8-menu.png, pico8-hit.png (a
--                     stone that just stopped against something)
--   with --label:     the title screen as __label__ text (tools/label.lua)
--
-- The moves come from tools/solve.lua (copied into the .love), run on the
-- cart's own rules. The cart's locals (cursor, state, ...) are read through
-- the upvalues of _update60, so the cart needs no test hooks.

local solve = require("solve")

local shots = {}
shots.__index = shots

-- levels 1-8 solved, on level 9
local SAVE = { [0] = 8, 2, 4, 6, 7, 7, 8, 9, 10, [63] = 9 }

-- finds a local of the cart by name among the upvalues of its callbacks
local function peek(env, name)
  local seen, queue = {}, { env._update60, env._draw }
  while #queue > 0 do
    local f = table.remove(queue, 1)
    if not seen[f] then
      seen[f] = true
      local i = 1
      while true do
        local n, v = debug.getupvalue(f, i)
        if not n then break end
        if n == name then return v end
        if type(v) == "function" then queue[#queue + 1] = v end
        i = i + 1
      end
    end
  end
end

function shots.new(dir, all, capture, label, cartridge)
  return setmetatable({ dir = dir, all = all, capture = capture, label = label, cartridge = cartridge,
    save = SAVE, buttons = {} }, shots)
end

function shots:start(env)
  local LEFT, RIGHT, UP, DOWN, O, X = 0, 1, 2, 3, 4, 5
  local self_ = self

  local function frame(buttons, n)
    for _ = 1, n or 1 do
      self_.buttons = {}
      for _, b in ipairs(buttons or {}) do self_.buttons[b] = true end
      coroutine.yield()
    end
  end

  local function shot(name)
    self_.capture(self_.dir .. "/" .. name, 4)
  end

  local function settle()
    for _ = 1, 600 do
      if not (peek(env, "anim") or peek(env, "intro") or peek(env, "outro")) then return end
      frame()
    end
  end

  local function walk(tx, ty)
    for _ = 1, 20 do
      local cur = peek(env, "cur")
      if cur.x == tx and cur.y == ty then return end
      frame({ cur.x < tx and RIGHT or cur.x > tx and LEFT or cur.y < ty and DOWN or UP })
      frame()
    end
  end

  local function pick_up(step)
    settle()
    if peek(env, "held") then frame({ O }); frame() end
    walk(step[1], step[2])
    frame({ O })
    frame()
  end

  self.co = coroutine.create(function()
    frame(nil, 50)
    shot("pico8-title.png")
    self_.cartridge(self_.dir .. "/pico8-cart.png")
    if self_.label then self_.label() end

    frame({ O })
    settle()
    local _, path = solve(env, env.rules_parse(env.levels[9][3]))
    local i = 1
    while env.rules_cairns(peek(env, "st")) < 1 do
      pick_up(path[i])
      local s = path[i]
      frame({ s[3] < 0 and LEFT or s[3] > 0 and RIGHT or s[4] < 0 and UP or DOWN })
      settle()
      i = i + 1
    end
    pick_up(path[i])
    frame(nil, 70)
    shot("pico8.png")

    if self_.all then
      frame({ O })
      frame({ 6 })
      frame(nil, 10)
      frame({ DOWN })
      frame(nil, 10)
      shot("pico8-menu.png")
      frame({ UP })
      frame({ O })
      frame(nil, 5)
      local hit_shot = false
      while i <= #path do
        pick_up(path[i])
        local s = path[i]
        frame({ s[3] < 0 and LEFT or s[3] > 0 and RIGHT or s[4] < 0 and UP or DOWN })
        settle()
        if not hit_shot and peek(env, "hit") then
          frame(nil, 3)
          shot("pico8-hit.png")
          hit_shot = true
        end
        i = i + 1
      end
      frame(nil, 40)
      shot("pico8-solved.png")
    end
  end)
end

-- called once per cart frame: false when the script is done
function shots:tick()
  if not self.co or coroutine.status(self.co) == "dead" then return false end
  local ok, err = coroutine.resume(self.co)
  if not ok then error(err) end
  return coroutine.status(self.co) ~= "dead"
end

return shots
