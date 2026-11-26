-- Unit tests for the puzzle rules and the levels, run inside the PICO-8
-- sandbox (tools/pico8_env.lua) on the cart's own pico8/rules.lua and
-- pico8/levels.lua.
--
-- Run from the repo root:  luajit tests/test_rules.lua

package.path = "tools/?.lua;" .. package.path
local pico8_env = require("pico8_env")
local solve = require("solve")

local LEFT, RIGHT, UP, DOWN = 1, 2, 3, 4

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assert_true(val, msg)
  if not val then
    error(msg or "expected truthy value", 2)
  end
end

-- a level from rows, e.g. level(env, "#####", "#@$.#", "#####")
local function level(env, ...)
  local rows = { ... }
  local goal
  if rows[#rows] == "exit" then goal = table.remove(rows) end
  local lv = env.rules_parse(table.concat(rows, "|"), goal)
  return lv, env.rules_new(lv)
end

-- the square at column x, row y (from 0)
local function sq(lv, x, y) return y * lv.w + x end

-- walks guy `who` (default 1) through a list of directions; every step must work
local function walk(env, lv, s, list, who)
  for _, d in ipairs(list) do
    local m = env.rules_move(lv, s, env.dirs[d], who or 1)
    assert_true(m, "move " .. d .. " should work")
    s = m.s
  end
  return s
end

local function has(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

local tests = {}

function tests.parse_reads_the_board(env)
  local lv, s = level(env, "##>##", "#@$.#", "#####")
  assert_eq(lv.w, 5)
  assert_eq(lv.h, 3)
  assert_eq(s.p[1], sq(lv, 1, 1))
  assert_eq(#s.c, 1)
  assert_eq(s.c[1], sq(lv, 2, 1))
  assert_true(lv.goal[sq(lv, 3, 1)], "goal")
  assert_eq(#lv.exits, 1)
  assert_true(lv.inside[sq(lv, 2, 1)], "floor is inside")
  assert_true(not lv.inside[sq(lv, 0, 0)], "walls are not inside")
end

function tests.short_rows_are_padded_and_outside_stays_outside(env)
  local lv = level(env, "  ###", "###@#", "#$. #", "#####")
  assert_eq(lv.w, 5)
  assert_eq(lv.ch[sq(lv, 0, 0)], " ")
  assert_true(not lv.inside[sq(lv, 0, 0)], "the space outside the walls is not floor")
end

function tests.walking_and_pushing_a_crate(env)
  local lv, s = level(env, "######", "#@$ .#", "######")
  local m = env.rules_move(lv, s, env.dirs[RIGHT], 1)
  assert_eq(m.s.p[1], sq(lv, 2, 1))
  assert_eq(m.s.c[1], sq(lv, 3, 1))
  assert_eq(m.crate, 1)
  assert_eq(s.c[1], sq(lv, 2, 1), "the old state is left alone")
end

function tests.crates_dont_go_through_walls_or_other_crates(env)
  local lv, s = level(env, "#####", "#@$$#", "#####")
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil, "two crates in a row")
  lv, s = level(env, "####", "#@$#", "####")
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil, "a crate against a wall")
  assert_eq(env.rules_move(lv, s, env.dirs[LEFT], 1), nil, "walking into a wall")
end

function tests.no_walking_into_water(env)
  local lv, s = level(env, "#####", "#@~ #", "#####")
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil)
end

function tests.a_crate_floats_across_water_onto_land(env)
  local lv, s = level(env, "########", "#@$~~ .#", "########")
  local m = env.rules_move(lv, s, env.dirs[RIGHT], 1)
  assert_eq(m.s.c[1], sq(lv, 5, 1), "it drifts over both water squares and onto the land")
  assert_eq(m.s.p[1], sq(lv, 2, 1), "the guy only takes one step")
end

function tests.a_crate_stops_floating_in_front_of_a_wall_and_is_stuck(env)
  local lv, s = level(env, "######", "#@$~~#", "######")
  local m = env.rules_move(lv, s, env.dirs[RIGHT], 1)
  assert_eq(m.s.c[1], sq(lv, 4, 1), "it stays in the last water square")
  assert_true(env.rules_water(lv, m.s, sq(lv, 4, 1)), "still water under it")
  lv, s = level(env, "######", "#@ $~#", "######")
  s = walk(env, lv, s, { RIGHT, RIGHT })
  assert_eq(s.c[1], sq(lv, 4, 1), "floating")
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil, "can't push a floating crate: he'd step into water")
end

function tests.a_rock_sinks_and_fills_the_water(env)
  local lv, s = level(env, "#######", "#@o~~ #", "#######")
  local m = env.rules_move(lv, s, env.dirs[RIGHT], 1)
  assert_true(m.sank, "it sinks")
  assert_eq(#m.s.r, 0)
  assert_true(has(m.s.f, sq(lv, 3, 1)), "the first water square is filled")
  assert_true(not env.rules_water(lv, m.s, sq(lv, 3, 1)), "and is ground now")
  s = walk(env, lv, m.s, { RIGHT })
  assert_eq(s.p[1], sq(lv, 3, 1), "you can walk onto it")
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil, "the next one is still water")
end

function tests.a_rock_on_land_is_pushed_like_a_crate(env)
  local lv, s = level(env, "######", "#@o  #", "######")
  local m = env.rules_move(lv, s, env.dirs[RIGHT], 1)
  assert_eq(m.s.r[1], sq(lv, 3, 1))
  assert_true(not m.sank)
end

function tests.a_switch_flips_the_green_walls(env)
  local lv, s = level(env, "########", "#@$_ Gg#", "########")
  local G, g = sq(lv, 5, 1), sq(lv, 6, 1)
  assert_true(env.rules_shut(lv, s, G), "G starts shut")
  assert_true(not env.rules_shut(lv, s, g), "g starts open")
  s = walk(env, lv, s, { RIGHT })
  assert_true(env.rules_pressed(lv, s), "a crate holds the switch down")
  assert_true(not env.rules_shut(lv, s, G), "G opens")
  assert_true(env.rules_shut(lv, s, g), "g shuts")
end

function tests.a_green_wall_doesnt_shut_on_what_stands_in_it(env)
  local lv, s = level(env, "#######", "#@$g_ #", "#######")
  local g = sq(lv, 3, 1)
  s = walk(env, lv, s, { RIGHT })
  assert_eq(s.c[1], g, "the crate goes into the open green wall")
  s = walk(env, lv, s, { RIGHT })
  assert_true(env.rules_pressed(lv, s), "the crate is on the switch")
  assert_eq(s.p[1], g)
  assert_true(not env.rules_shut(lv, s, g), "it doesn't shut on him")
  s = walk(env, lv, s, { LEFT })
  assert_true(env.rules_shut(lv, s, g), "it shuts once he's out of it")
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil, "and a shut green wall is solid")
end

function tests.the_way_out_opens_when_the_crates_are_placed(env)
  local lv, s = level(env, "##>##", "#@$.#", "#####")
  local e = lv.exits[1]
  assert_true(not env.rules_open(lv, s, e), "shut while a crate is off its goal")
  s = walk(env, lv, s, { RIGHT })
  assert_true(env.rules_open(lv, s, e), "open once it's on")
  assert_true(env.rules_met(lv, s))
  assert_true(not env.rules_won(lv, s), "not won before he walks out")
  local m = env.rules_move(lv, s, env.dirs[UP], 1)
  assert_true(m.out, "he walks out")
  assert_eq(m.s.p[1], -1)
  assert_true(env.rules_won(lv, m.s))
end

function tests.a_shut_way_out_is_a_wall(env)
  local lv, s = level(env, "#>###", "#@$ .#", "######")
  assert_eq(env.rules_move(lv, s, env.dirs[UP], 1), nil)
end

function tests.a_level_without_a_way_out_is_won_when_the_crates_are_placed(env)
  local lv, s = level(env, "#####", "#@$.#", "#####")
  assert_true(not env.rules_won(lv, s))
  s = walk(env, lv, s, { RIGHT })
  assert_true(env.rules_won(lv, s))
end

function tests.exit_levels_are_open_from_the_start(env)
  local lv, s = level(env, "#####", "#@$ >", "#####", "exit")
  assert_true(env.rules_open(lv, s, lv.exits[1]))
  assert_true(env.rules_met(lv, s))
end

function tests.two_guys_block_each_other_and_both_must_get_out(env)
  local lv, s = level(env, "###>###", "#@&  .#", "#  $  #", "#######")
  assert_eq(#s.p, 2)
  assert_eq(env.rules_move(lv, s, env.dirs[RIGHT], 1), nil, "partner is in the way")
  s = walk(env, lv, s, { RIGHT }, 2)
  assert_eq(s.p[2], sq(lv, 3, 1))
end

function tests.an_island_without_crates_has_its_way_out_open(env)
  local lv, s = level(env, "#####>#", "#@$  .#", "#######", "#&    >", "#######")
  local top, low = lv.exits[1], lv.exits[2]
  assert_true(lv.region[top] ~= lv.region[low], "two areas")
  assert_true(not env.rules_open(lv, s, top), "the crate's side is shut")
  assert_true(env.rules_open(lv, s, low), "partner's side is open")
end

function tests.every_level_is_well_formed(env)
  assert_eq(#env.levels, 27)
  for i, l in ipairs(env.levels) do
    local name = "level " .. i .. " (" .. l[1] .. ")"
    local lv, s = env.rules_parse(l[2], l[3]), nil
    s = env.rules_new(lv)
    assert_true(s.p[1], name .. " has no @")
    assert_true(lv.w <= 16 and lv.h <= 13, name .. " is too big for the screen")
    for k = 0, lv.w * lv.h - 1 do
      if lv.inside[k] then
        local x, y = k % lv.w, math.floor(k / lv.w)
        assert_true(x > 0 and y > 0 and x < lv.w - 1 and y < lv.h - 1, name .. " isn't closed")
      end
    end
    if lv.kind == "crates" then
      local goals = 0
      for k = 0, lv.w * lv.h - 1 do
        if lv.goal[k] then goals = goals + 1 end
      end
      assert_true(#s.c > 0 and #s.c == goals, name .. " needs as many goals as crates")
    end
    assert_true(#l[1] <= 22, name .. " name is too long for the HUD")
    assert_true(l[1] == l[1]:lower(), name .. " name should be lowercase")
  end
end

function tests.every_level_can_be_solved(env)
  for i, l in ipairs(env.levels) do
    local moves, _, states = solve(env, env.rules_parse(l[2], l[3]))
    assert_true(moves, "level " .. i .. " (" .. l[1] .. ") can't be solved")
    io.write(string.format("    %2d %-18s %2d moves (%d states)\n", i, l[1], moves, states))
  end
end

local names = {}
for name in pairs(tests) do names[#names + 1] = name end
table.sort(names)

local failed = 0
for _, name in ipairs(names) do
  local env = pico8_env.new(".")
  local ok, err = pcall(tests[name], env)
  if ok then
    print("  ok    " .. name)
  else
    failed = failed + 1
    print("  FAIL  " .. name .. "\n        " .. tostring(err))
  end
end

if failed > 0 then
  print(failed .. " rule test(s) failed")
  os.exit(1)
end
print(#names .. " rule tests passed")
