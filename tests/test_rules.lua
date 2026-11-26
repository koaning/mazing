-- Unit tests for the puzzle rules and the levels, run inside the PICO-8
-- sandbox (tools/pico8_env.lua) on the cart's own pico8/rules.lua and
-- pico8/levels.lua.
--
-- Run from the repo root:  luajit tests/test_rules.lua

package.path = "tools/?.lua;" .. package.path
local pico8_env = require("pico8_env")
local solve = require("solve")

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

-- a board from rows, e.g. board(env, ".l...", "..t..")
local function board(env, ...)
  return env.rules_parse(table.concat({ ... }, "|"))
end

local function piece_at(env, st, x, y)
  local p = env.rules_movable_at(st, x, y)
  assert_true(p, "no movable piece at " .. x .. "," .. y)
  return p
end

local tests = {}

function tests.parse_reads_pieces_trees_and_size(env)
  local st = board(env, "l.t", ".mh")
  assert_eq(st.w, 3)
  assert_eq(st.h, 2)
  assert_eq(#st.pieces, 3)
  assert_true(env.rules_tree(st, 3, 1), "tree at 3,1")
  assert_eq(env.rules_content_at(st, 1, 1), "l")
  assert_eq(env.rules_content_at(st, 2, 2), "m")
  assert_eq(env.rules_content_at(st, 3, 2), "h")
  assert_eq(env.rules_content_at(st, 2, 1), nil)
end

function tests.stone_rolls_until_the_square_before_a_piece(env)
  local st = board(env, "l...h")
  local m = env.rules_move(st, piece_at(env, st, 1, 1), 1, 0)
  assert_eq(m.kind, "roll")
  assert_eq(m.x, 4)
  assert_eq(m.dist, 3)
end

function tests.stone_stops_in_front_of_a_tree(env)
  local st = board(env, ".m..t")
  local m = env.rules_move(st, piece_at(env, st, 2, 1), 1, 0)
  assert_eq(m.kind, "roll")
  assert_eq(m.x, 4)
end

function tests.roll_into_the_sea_is_not_allowed(env)
  local st = board(env, ".l...", "..t..")
  assert_eq(env.rules_move(st, piece_at(env, st, 2, 1), 1, 0), nil, "nothing stops it on the right")
  assert_eq(env.rules_move(st, piece_at(env, st, 2, 1), -1, 0), nil, "the left edge doesn't stop it")
  assert_eq(env.rules_move(st, piece_at(env, st, 2, 1), 0, -1), nil, "off the top")
end

function tests.blocked_right_away_is_not_a_move(env)
  local st = board(env, "lt...")
  assert_eq(env.rules_move(st, piece_at(env, st, 1, 1), 1, 0), nil)
end

function tests.small_stone_hops_onto_a_big_stone(env)
  local st = board(env, "ml")
  local p = piece_at(env, st, 1, 1)
  local m = env.rules_move(st, p, 1, 0)
  assert_eq(m.kind, "stack")
  assert_eq(m.stack, "lm")
  env.rules_apply(st, p, m)
  assert_eq(env.rules_content_at(st, 2, 1), "lm")
  assert_eq(env.rules_movable_at(st, 2, 1), nil, "a stack can't move")
end

function tests.flag_finishes_a_cairn(env)
  local st = board(env, "mlh")
  env.rules_apply(st, piece_at(env, st, 1, 1), env.rules_move(st, piece_at(env, st, 1, 1), 1, 0))
  local flag = piece_at(env, st, 3, 1)
  local m = env.rules_move(st, flag, -1, 0)
  assert_eq(m.kind, "stack")
  assert_eq(m.stack, "lmh")
  env.rules_apply(st, flag, m)
  assert_eq(env.rules_cairns(st), 1)
  assert_true(env.rules_solved(st), "one finished cairn solves it")
end

function tests.nothing_else_stacks(env)
  local cases = {
    { "lm", 1, "big stone never goes on top" },
    { "ll", 1, "big on big" },
    { "mm", 1, "small on small" },
    { "hl", 1, "flag on a lone big stone" },
    { "hm", 1, "flag on a lone small stone" },
    { "mh", 1, "small stone on a flag" },
  }
  for _, c in ipairs(cases) do
    local st = board(env, c[1])
    assert_eq(env.rules_move(st, piece_at(env, st, c[2], 1), 1, 0), nil, c[3])
  end
end

function tests.flags_never_roll(env)
  local st = board(env, "h...l")
  assert_eq(env.rules_move(st, piece_at(env, st, 1, 1), 1, 0), nil)
  assert_eq(#env.rules_moves(st, piece_at(env, st, 1, 1)), 0)
end

function tests.stacked_pieces_never_move(env)
  local st = board(env, "ml..t")
  local small = piece_at(env, st, 1, 1)
  env.rules_apply(st, small, env.rules_move(st, small, 1, 0))
  for _, p in ipairs(st.pieces) do
    assert_eq(#env.rules_moves(st, p), 0, "stacked " .. p.kind .. " has moves")
  end
end

function tests.not_solved_until_every_piece_is_in_a_cairn(env)
  local st = board(env, "lmh", "...")
  assert_true(not env.rules_solved(st), "loose pieces")
  assert_true(not env.rules_solved(board(env, "...")), "an empty board is not a puzzle")
end

function tests.copy_is_independent(env)
  local st = board(env, "l...t")
  local c = env.rules_copy(st)
  env.rules_apply(c, c.pieces[1], env.rules_move(c, c.pieces[1], 1, 0))
  assert_eq(st.pieces[1].x, 1)
  assert_eq(c.pieces[1].x, 4)
end

function tests.every_level_is_7x5_with_matching_pieces(env)
  assert_eq(#env.levels, 30)
  for i, lv in ipairs(env.levels) do
    local st = env.rules_parse(lv[3])
    assert_eq(st.w, env.board_w, "level " .. i .. " width")
    assert_eq(st.h, env.board_h, "level " .. i .. " depth")
    for row in lv[3]:gmatch("[^|]+") do
      assert_eq(#row, env.board_w, "level " .. i .. " row length")
    end
    local n = { l = 0, m = 0, h = 0 }
    for _, p in ipairs(st.pieces) do n[p.kind] = n[p.kind] + 1 end
    assert_true(n.l > 0 and n.l == n.m and n.m == n.h,
      "level " .. i .. " needs as many big stones as small stones and flags")
    assert_true(#lv[1] <= 15, "level " .. i .. " name is too long for the HUD")
  end
end

function tests.every_level_best_is_the_fewest_moves(env)
  for i, lv in ipairs(env.levels) do
    local moves, _, states = solve(env, env.rules_parse(lv[3]))
    assert_true(moves, "level " .. i .. " (" .. lv[1] .. ") can't be solved")
    assert_eq(lv[2], moves, "level " .. i .. " (" .. lv[1] .. ") best")
    io.write(string.format("    %2d %-15s %2d moves (%d states)\n", i, lv[1], moves, states))
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
