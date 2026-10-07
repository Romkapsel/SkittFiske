-- Faste data: agn, fiskeskillens spell-ID-er og hvilke plasser utstyret sitter på
local addonName, ns = ...

ns.Data = {
  -- Agn (item-ID → bonus). Nye agn i Forever fanges også av tooltip-sjekken i Game.IsLure.
  LURES = {
    [6529] = 25,   -- Shiny Bauble
    [6530] = 50,   -- Nightcrawlers
    [6811] = 50,   -- Aquadynamic Fish Lens
    [6532] = 75,   -- Bright Baubles
    [7307] = 75,   -- Flesh Eating Worm
    [6533] = 100,  -- Aquadynamic Fish Attractor
    [34861] = 100, -- Sharpened Fish Hook
    [46006] = 100, -- Glow Worm
  },

  -- Fishing i alle ranker og utgaver; navnet hentes fra den første spillet kjenner
  FISHING_SPELLS = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 131474, 131476, 131490 },
  FISHING_FALLBACK = "Fishing",

  -- Fiskestenger: våpen (classID 2), underklasse 20
  POLE_CLASS = 2,
  POLE_SUBCLASS = 20,

  MAIN_HAND = 16,
  OFF_HAND = 17,

  -- Plassene vi ser etter fiskeutstyr på (ringer og trinkets: første plass)
  SLOT_OF = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15,
    INVTYPE_2HWEAPON = 16, INVTYPE_WEAPON = 16, INVTYPE_WEAPONMAINHAND = 16,
  },
  EQUIP_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 },

  HISTORY_MAX = 20,
  DOUBLE_CLICK = 0.4,  -- sekunder mellom to høyreklikk
  LURE_LOW = 60,       -- sekunder igjen før agnet lyser
}
