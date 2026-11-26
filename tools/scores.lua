-- Mazing sound: readable scores compiled into the cart's __sfx__ and
-- __music__ sections by `make music` (tools/sfx.lua, which explains the
-- notation).
--
-- sfx 0-9 are the sound effects (the `effects` table below), sfx 10+ the
-- background music: one calm, original chord loop (open maj7 voicings,
-- sus4 lifts), "high moor" in G major, music(0), played on the title
-- screen and in game alike.
-- No lead melody: a soft plucked sine harp arpeggio on channel 0 and a
-- root/fifth triangle bass on channel 1. Channels 2-3 stay free for sfx.

return {
  first_sfx = 10,

  -- Kept soft and low: a footstep is barely there, crates scrape, water
  -- splashes, and the way out opening rings a little bell.
  effects = {
    -- a soft low footstep
    { name = "step", speed = 2, notes = "d1:1:1:5" },
    -- a crate or rock scraping over sandstone
    { name = "push", speed = 3, notes = "c0:6:2:0 c0:6:2:0 c0:6:1:5" },
    -- a crate landing in water
    { name = "splash", speed = 3, notes = "c3:6:3:0 a2:6:2:3 f2:6:1:5" },
    -- a rock sinking: a low plop and bubbles
    { name = "sink", speed = 3, notes = "e2:0:3:3 c1:0:3:3 c1:6:1:5" },
    -- a switch clicking down or up, and the green walls flipping
    { name = "switch", speed = 2, notes = "c3:1:2:0 g2:1:2:3 g2:1:1:5" },
    -- the way out opens: a small bell on an open fifth
    { name = "door", speed = 6, notes = "g3:0:3:0 d4:0:2:0 d4:0:2:2 d4:0:1:5" },
    -- a soft downward glide
    { name = "undo", speed = 3, notes = "e3:0:2:0 b2:0:2:1 b2:0:1:5" },
    -- a slow, quiet G major 9 arpeggio, in the key of the song
    { name = "solved", speed = 10,
      notes = "g2:0:3:0 d3:0:3:0 a3:0:3:0 b3:0:3:0 f#4:0:2:0 f#4:0:2:2 f#4:0:1:2 f#4:0:1:5" },
    -- a muted thud when he can't go that way
    { name = "bump", speed = 5, notes = "a0:1:3:3 a0:1:1:5" },
    -- a quiet sine lift: playing the other one
    { name = "swap", speed = 2, notes = "a2:0:2:0 e3:0:3:0 e3:0:2:5" },
  },

  songs = {
    {
      name = "song", title = "high moor", speed = 50,
      patterns = {
        a = { "gmaj7", "em7", "cmaj7", "dsus4/d7" },
        a2 = { "gmaj7", "bm7", "cmaj7", "am7/d7" },
        b = { "em7", "cmaj7", "am7", "dsus4/d7" },
        coda = { "gmaj7", "cmaj7", "am7/d7", "gmaj" },
      },
      order = { "a", "a2", "b", "coda" },
    },
  },
}
