# Mazing

A stone-stacking puzzle for **PICO-8** (128×128, 16 colours): roll mossy
stones around a little grassy island and stack them into cairns with a flag
on top. It's a port of the "grassland cairns" look of
[Snowstack](https://github.com/koaning/ps-love2d/tree/main/games/snowstack):
30 puzzles, its 17 plus 13 found with a level generator.

**Play it in your browser: <https://koaning.github.io/mazing/>**

| Cartridge | Gameplay |
| --- | --- |
| ![PICO-8 cartridge](docs/screenshots/pico8-cart.png) | ![PICO-8 gameplay](docs/screenshots/pico8.png) |

## The rules

- **Rolling:** a stone rolls in a straight line until the next square holds a
  piece or a pine tree, and stops in front of it. A roll that nothing stops
  isn't allowed, because the stone would roll into the sea.
- **Stacking:** a small stone next to a big stone hops on top of it. A flag
  next to a big + small stack hops on top and finishes the cairn. Nothing else
  stacks.
- **Flags never roll**, and stacked stones never move again.
- **Solved** when every piece is part of a finished cairn. Every level shows
  the fewest moves it can be done in.
