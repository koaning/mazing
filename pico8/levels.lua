-- levels.lua
-- the puzzles, in order: { name, fewest moves, board }.
-- the board is 7 squares wide and 5 deep, rows split by "|",
-- the first row is the far side:
--   .  grass   t  pine tree
--   l  big stone   m  small stone   h  flag
-- tests/test_rules.lua solves every level and checks the
-- fewest moves, so keep it right when adding one.
-- the first 17 layouts are snowstack's (koaning/ps-love2d), the rest
-- came from tools/genlevels.lua. ordered by fewest moves.

levels = {
  { "flag day", 2, ".......|...h...|...l...|...m...|......." },
  { "pine stop", 4, ".......|.m.t...|.......|..lh...|......." },
  { "bump", 6, ".......|...l.t.|..m....|.......|..t.h.." },
  { "long way round", 7, ".......|.......|...tm..|.h.....|..t.l.." },
  { "lookout", 7, "....h..|.t.....|.....t.|..t....|t.l.m.." },
  { "high tide", 8, "...th..|......t|...t...|..m..l.|......." },
  { "thicket", 9, ".......|.m..t..|.t.....|.....l.|..th..." },
  { "switchback", 10, ".......|.....t.|..t....|.....m.|..th.l." },
  { "either side", 11, ".......|..ltl..|.......|..h.h..|..m.m.." },
  { "two of a kind", 12, ".......|.hml...|.....h.|..m....|.t..l.." },
  { "four pines", 14, "t.....t|.h...h.|.......|.m...m.|t.l.l.t" },
  { "low road", 15, "th.m..t|...t..m|h......|.l...l.|....t.." },
  { "crosswind", 16, ".......|....t..|.h...h.|..tlml.|...m..." },
  { "close ranks", 16, "..l.l..|t.m.m.t|...t...|.h...h.|t.....t" },
  { "sandbar", 16, "m...m.h|.......|.......|h.....l|l....t." },
  { "wet feet", 17, ".......|.l.ht..|.t...l.|.h.....|.m...m." },
  { "stone circle", 17, ".......|.h.hl..|..mm...|...l.h.|.m...l." },
  { "heather", 17, ".m...h.|m...l.t|t......|l..h...|....tt." },
  { "tidepool", 18, ".t.l.t.|t......|....mm.|....h..|..h...l" },
  { "three peaks", 18, ".m.tlh.|mt.....|....h.l|l....h.|tm..t.." },
  { "back to back", 19, "...t...|.......|.hm.mh.|t.....t|.l...l." },
  { "sheepfold", 19, "h.m.l..|.......|.t...t.|m....l.|t.h...t" },
  { "flag to flag", 20, "t.m...t|......m|.......|lh..h..|t...l.t" },
  { "headland", 20, ".m.h..t|.h.....|.....lt|.......|m.l...." },
  { "standing stones", 22, "h...l..|..l..mm|hh....m|t......|.l..t.." },
  { "gale", 24, ".......|.m..ml.|.l...l.|.h.m...|.h..h.." },
  { "landslide", 24, "l.l....|...l...|..t...h|...m..t|htmt.hm" },
  { "summit", 25, ".l..m..|ll.....|..t..hm|.h.....|..h...m" },
  { "far shores", 26, "t.mh..t|.......|....h..|l......|t...lmt" },
  { "last light", 26, "...m...|h..m.l.|..l...l|..h...h|......m" },
}
