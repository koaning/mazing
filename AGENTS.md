# Agent notes

This repo holds **Mazing**, a PICO-8 crate-pushing puzzle (`pico8/mazing.p8`
and `#include`d `.lua` files), ported from koaning/sokoban (a browser game
with a level editor).

- Always finish with `make test` from the repo root. It runs the rule tests
  and level solver (`tests/test_rules.lua`), the cart smoke test
  (`tests/cart_smoke.lua`, which solves every level through the buttons), the
  approximate 8192-token budget meter (`tools/p8tokens.lua`), and checks the
  cart's sound data is up to date (`tools/music.lua --check`).
- PICO-8 files (`pico8/*.lua`) use the Lua subset accepted by both PICO-8 and
  LuaJIT: no `+=`/`!=`/`?`, no `math.`/`table.`/`string.`/`ipairs`, and keep
  numbers within PICO-8's ±32767 fixed-point range. Use lowercase in strings
  (PICO-8 shows uppercase as small caps glyphs).
- `pico8/main.lua` is loaded on its own by the smoke test, so it only sees
  the globals of `rules.lua` and `levels.lua`, not their `local`s.
- Changing a level? It must be solvable: the unit tests solve every level
  and print how many moves the solver needed.
- The sprites are the cart's `__gfx__` section (koaning/sokoban's sandstone
  design). `pico8/main.lua` lists which sprite number is what.
- PICO-8 itself isn't installed in CI; `make smoke` boots the cart on a
  stubbed API, and `make serve` hosts the cart in the browser via
  `pico8/preview/` (a minimal PICO-8 stand-in player). If the cart uses a
  PICO-8 API `pico8/preview/` doesn't implement yet, add it there (and to the
  stubs in `tests/cart_smoke.lua`).
- `make screenshots` (needs LÖVE; without a display use
  `make screenshots LOVE="xvfb-run -a love"`) replays `pico8/preview/shots.lua`
  and refreshes `docs/screenshots/` and the cart label. Rerun it after visual
  changes.
- When showing screenshots or visual previews to the user, embed the images
  directly inline in the conversation response rather than hiding them behind
  a separate markdown artifact.
