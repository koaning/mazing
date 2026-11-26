-- Scripted run for `love mazing-p8.love --shots <dir> [--label <file>] [--all]`
-- (`make screenshots`). It presses the buttons for a player and saves:
--
--   pico8-cart.png    the title screen as a cartridge: the cart label with
--                     the cart's title and byline, like PICO-8 shows carts
--   pico8-title.png   the title screen with some levels solved
--   pico8.png         level 21 (ferry) part way: a rock sunk, a crate across
--   with --all also:  pico8-two.png (level 22, you and partner),
--                     pico8-menu.png
--   with --label:     the title screen as __label__ text (tools/label.lua)
--
-- The moves come from tools/solve.lua (copied into the .love), run on the
-- cart's own rules. The cart's locals (state, who, ...) are read through
-- the upvalues of _update60, so the cart needs no test hooks.

local solve = require("solve")

local shots = {}
shots.__index = shots

-- levels 1-20 solved, on level 21
local SAVE = { [0] = 20, [63] = 21 }
for i = 1, 20 do SAVE[i] = 1 end

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
  local O = 4
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

  -- plays the solver's moves from..to of level n
  local function play(path, from, to)
    for i = from, to do
      local s = path[i]
      settle()
      if peek(env, "who") ~= s[1] then frame({ O }) end
      frame({ s[2] - 1 })
      settle()
    end
  end

  local function path_of(n)
    local _, path = solve(env, env.rules_parse(env.levels[n][2], env.levels[n][3]))
    return path
  end

  self.co = coroutine.create(function()
    frame(nil, 70)
    shot("pico8-title.png")
    self_.cartridge(self_.dir .. "/pico8-cart.png")
    if self_.label then self_.label() end

    frame({ O })
    settle()
    local path = path_of(21)
    play(path, 1, 15)
    frame(nil, 20)
    shot("pico8.png")

    if self_.all then
      frame({ 6 })
      frame(nil, 10)
      shot("pico8-menu.png")
      frame({ 6 })
      frame(nil, 5)
      -- solving it goes on to level 22 by itself
      play(path, 16, #path)
      settle()
      local two = path_of(22)
      play(two, 1, 12)
      frame(nil, 20)
      shot("pico8-two.png")
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
