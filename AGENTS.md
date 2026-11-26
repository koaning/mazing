# Agent notes

This repo holds **Mazing**, a PICO-8 stone-stacking puzzle (`pico8/mazing.p8`
and `#include`d `.lua` files), ported from snowstack in koaning/ps-love2d.

- Always finish with `make test` from the repo root. It runs the rule tests
  and level solver (`tests/test_rules.lua`), the cart smoke test
  (`tests/cart_smoke.lua`, which solves every level through the buttons), the
  approximate 8192-token budget meter (`tools/p8tokens.lua`), and checks the
  cart's sound data is up to date (`tools/music.lua --check`).
- PICO-8 files (`pico8/*.lua`) use the Lua subset accepted by both PICO-8 and
  LuaJIT: no `+=`/`!=`/`?`, no `math.`/`table.`/`string.`/`ipairs`, and keep
  numbers within PICO-8's ±32767 fixed-point range. Use lowercase in strings
  (PICO-8 shows uppercase as small caps glyphs).
- Changing a level? Its fewest-moves number must match the solver; the unit
  tests print the solver's answer for every level.
- PICO-8 itself isn't installed in CI; `make smoke` boots the cart on a
  stubbed API, and `make serve` hosts the cart in the browser via
  `pico8/preview/` (a minimal PICO-8 stand-in player). If the cart uses a
  PICO-8 API `pico8/preview/` doesn't implement yet, add it there (and to the
  stubs in `tests/cart_smoke.lua`).
- `make screenshots` (needs LÖVE) replays `pico8/preview/shots.lua` and
  refreshes `docs/screenshots/` and the cart label. Rerun it after visual changes.
- When showing screenshots or visual previews to the user, embed the images
  directly inline in the conversation response rather than hiding them behind
  a separate markdown artifact.
