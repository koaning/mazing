# Mazing — PICO-8 cart

| Cartridge | Gameplay |
| --- | --- |
| ![PICO-8 cartridge](../docs/screenshots/pico8-cart.png) | ![PICO-8 gameplay](../docs/screenshots/pico8.png) |

```bash
pico8 -run mazing.p8     # or `make pico8` from the repo root
```

The cart is `mazing.p8`, which `#include`s:

| File | What |
| --- | --- |
| `levels.lua` | the 30 puzzles: name, fewest moves, board |
| `rules.lua` | reading a board, rolling, stacking, solved (ported from snowstack) |
| `main.lua` | title + level select, island and stone renderer, animations, undo, menu, keys, saves, sfx |

Edit the `.lua` files in any editor. PICO-8 picks them up on `run`. To
export a standalone `.p8.png`/HTML, load the cart in PICO-8 and `save` /
`export`; includes get baked in at that point.

## Controls

- Title: ⬅️➡️⬆️⬇️ pick a level, 🅾️ play. Levels open one by one as you solve them.
- Game: ⬅️➡️⬆️⬇️ move the cursor, 🅾️ pick up the stone or flag under it,
  then ⬅️➡️⬆️⬇️ send it that way. 🅾️ or ❎ puts it down again.
- ❎ with nothing picked up undoes a move. Hold ❎ (or press R) to restart
  the level.
- P (Start on a gamepad) opens the menu: resume, back to levels.
- Enter works like 🅾️ everywhere. PICO-8 normally opens its pause menu on
  Enter; the cart reads the raw keyboard (devkit mode) to tell Enter, P and R
  apart and suppresses that pause menu (`poke(0x5f30, 1)`), so its own menu
  opens instead.
- Esc belongs to PICO-8 itself when the cart runs inside the PICO-8 app
  (`make pico8`): it stops the cart and drops you into the console/editor.
  Type `resume` there (or press Ctrl+R to start over). `make play` exports a
  standalone player instead, with no editor behind it. In the browser
  preview Esc opens the menu like P.

While a piece is picked up, the squares it can go to light up: **blue** where
it would roll to (with a dotted trail), **orange** where it would hop onto a
stack. A way that isn't allowed makes the piece shake.

## Levels

One string per board, rows split by `|`, the first row is the far side:

```lua
{ "pine stop", 4, ".......|.m.t...|.......|..lh...|......." },
```

`.` grass, `t` pine tree, `l` big stone, `m` small stone, `h` flag. Every level
is 7 × 5 and has as many big stones as small stones and flags. `make test`
solves every level with a breadth-first search (`tools/solve.lua`) and fails
when the fewest-moves number is wrong.

The first 17 levels are snowstack's. The rest came from the generator:

```bash
luajit tools/genlevels.lua 4000 42 > candidates.txt   # tries, seed (slow: ~10 min)
```

It places random pieces and trees, keeps boards that are solvable, take a
few moves per cairn and don't start with a stack ready to make, and prints
them sorted by fewest moves. Pick, name, and slot them in by difficulty.

## Saved progress

`cartdata("koaning_mazing")`: `dget(0)` is the highest level solved,
`dget(1..30)` your fewest moves on each level, `dget(63)` the level played
last (the title opens on it).

## Sound

`tools/music.lua` holds everything you hear and compiles it into the cart:

- sfx 0-7, the sound effects, written as short note strings and kept soft:
  quiet sine tones for picking up, putting down and undo, gravel under a
  rolling stone (once per square), a dull tick and thump when stones stack, a
  small bell for a planted flag, a muted thud for a bump, and a slow D major 9
  arpeggio when a level is solved.
- sfx 8+ and `__music__`: "high moor", one calm chord loop with no lead
  melody that plays all the time (pattern 0). A plucked sine harp arpeggio
  over a triangle bass.

```bash
make music   # rewrite the cart's sound data after editing the scores
```

`make test` fails if the cart's sound data is stale. The cart plays music
with `music(n, fade, 3)`, which reserves channels 0-1 so sfx always have 2-3.
If you edit the sound in PICO-8's editors instead, stop using the score
because `make music` would overwrite those edits.

## Preview player (no PICO-8 needed)

`preview/` is a small PICO-8 stand-in written in LÖVE. It reads
`mazing.p8`, resolves its `#include`s and runs the cart against a minimal
PICO-8 API: 128×128 framebuffer, the 16-colour palette, shapes, fill
patterns, a 3×5 font, buttons, coroutines, `cartdata` saved in LÖVE's save
folder, and a tiny synth (`preview/synth.lua`) for the `__sfx__` and
`__music__` sections.

```bash
make pico8-preview && love dist/mazing-p8.love   # desktop
make serve                                       # browser
make screenshots                                 # scripted run, see preview/shots.lua
```

`make screenshots` plays a scripted run (`preview/shots.lua`), saves
`docs/screenshots/*.png`, and writes the title screen into the cart's
`__label__` (`tools/label.lua`), which PICO-8 needs for `export`.

Colours, font and sound are approximations. Use real PICO-8 to judge
how the cart looks and sounds.
