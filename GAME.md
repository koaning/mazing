# Mazing

A PICO-8 crate-pushing puzzle (`pico8/mazing.p8` and `#include`d `.lua`
files), ported from koaning/sokoban (a browser game with a level editor).

Notes for agents about this game (the toolchain notes are in AGENTS.md).

- Code: `pico8/levels.lua` holds the 30 puzzles, `pico8/rules.lua` the pure
  rules (unit-tested in `tests/test_rules.lua`), and `pico8/main.lua` the
  title/level select, renderer, animations, undo, swapping, menu, keys,
  saves and sfx.
- Changing a level? It must be solvable: `tests/test_rules.lua` solves every
  level with `tools/solve.lua` and prints how many moves the solver needed,
  and `tests/cart_smoke.lua` solves every level through the buttons.
- `game.mk` sets `PREVIEW_EXTRA := tools/solve.lua` so
  `pico8/preview/shots.lua` can require the solver when capturing
  screenshots.
- Sprites are the cart's `__gfx__` section (koaning/sokoban's sandstone
  design). `pico8/main.lua` lists which sprite number is what.
- Sound: `tools/scores.lua`, sfx 0-9 (step, push, splash, sink, switch,
  door, undo, solved, bump, swap) and one song ("high moor", `music(0)`).
- Save data: `cartdata("koaning_mazing")` — slot 0 is the highest level
  solved, slots 1..30 are 1 once solved, slot 63 is the last level played.
