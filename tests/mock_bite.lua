-- Nappe-lytteren (/skitt debug nappe): mens duppen er ute, noteres alt spillet sier (hver hendelse høyst 3 ganger)
T.equip = { [16] = SWORD }
Put(POLE)
Login()
Slash("debug nappe") -- lytteren er av til den slås på
Slash("")

Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 7620)
T.now = T.now + 4.5
Fire("SOUND_SPLASH_TEST", "a", 1)
for _ = 1, 10 do Fire("UNIT_AURA", "player") end
T.now = T.now + 0.8
T.loot = { fishing = true, items = { { SMALLFISH, 1 } } }
Fire("LOOT_OPENED")
Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
Fire("LOOT_CLOSED")
RunTimers(3)

local b = SkittFiskeDB.debug.bite and SkittFiskeDB.debug.bite[1]
check(b ~= nil, "kastet er lagret")
local text = table.concat(b and b.ev or {}, "\n")
check(text:find("4.50 SOUND_SPLASH_TEST a 1", 1, true), "hendelsen med tid siden kastet: " .. text)
check(text:find("5.30 >> LOOT_OPENED", 1, true), "loot med tid")
check(text:find(">> kastet stopper", 1, true), "kastet stopper")
local auras = 0
for _, l in ipairs(b and b.ev or {}) do if l:find("UNIT_AURA", 1, true) then auras = auras + 1 end end
check(auras == 3, "hver hendelse høyst 3 ganger per kast")
check(next(T.allEvents) == nil, "lytteren er av når kastet er over")

-- Hendelser etter at lytteren er av, noteres ikke
Fire("ANOTHER_EVENT")
check(not table.concat(b.ev, "\n"):find("ANOTHER_EVENT", 1, true), "ingenting etter stopp")

-- Uten fiskemodus lyttes det ikke
Slash("")
Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 7620)
check(next(T.allEvents) == nil, "ingen lytting utenom fiskingen")
