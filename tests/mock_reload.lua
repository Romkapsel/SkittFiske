-- /reload og utlogging midt i fiskingen: alt fortsetter der du slapp, og lyden er aldri fast i fiskemodus
T.equip = { [1] = HELM, [16] = SWORD }
Put(POLE) Put(HAT)
local before = {}
for k, v in pairs(T.cvars) do before[k] = v end
Login()
Slash("")
Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 7620)
T.loot = { fishing = true, items = { { SMALLFISH, 1 } } }
Fire("LOOT_OPENED") Fire("LOOT_CLOSED")

-- Logg ut: lyden tilbake
Fire("PLAYER_LOGOUT")
for k, v in pairs(before) do check(T.cvars[k] == v, "lyden tilbake ved utlogging: " .. k) end

-- Logg inn igjen (ny Lua, samme SavedVariables)
T.handlers = {}
WorldFrame.hooks = {}
LoadAddon()
Login()
check(NS.active, "fiskemodus fortsetter")
check(T.cvars.Sound_EnableSoundWhenGameIsInBG == "1" and T.cvars.Sound_MusicVolume == "0", "fiskelyden på igjen")
check(NAMED.SkittFiskeWindow.shown, "vinduet åpent igjen")
check(SkittFiskeCharDB.session.casts == 1 and SkittFiskeCharDB.session.caught == 1, "økta fortsetter")
check(#T.macros == 1, "makroen lages ikke på nytt")
DoubleRight(0.2)
check(T.bindings.BUTTON2 == "SkittFiskeCastButton", "dobbeltklikk virker etter /reload")
Click(NAMED.SkittFiskeCastButton)

Slash("")
RunTimers(2)
check(T.equip[16] == SWORD and T.equip[1] == HELM, "det gamle utstyret tilbake etter /reload")
for k, v in pairs(before) do check(T.cvars[k] == v, "lyden tilbake: " .. k) end
check(SkittFiskeDB.history[1].caught == 1, "rapporten har fangsten fra før /reload")

-- Spillet krasjet mens en annen karakter fisket: lyden er fortsatt endret når denne logger inn
SkittFiskeDB.sound = { Sound_MusicVolume = "0.6" }
T.cvars.Sound_MusicVolume = "0"
T.handlers = {}
WorldFrame.hooks = {}
LoadAddon()
Login()
check(T.cvars.Sound_MusicVolume == "0.6" and SkittFiskeDB.sound == nil, "lyden settes tilbake for en karakter som ikke fisker")
