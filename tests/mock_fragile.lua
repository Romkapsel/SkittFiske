-- Når spillet nekter noe av pynten, skal vinduet likevel virke (7. okt: vinduet stoppet halvveis i Forever)
T.failAnim = true
T.equip = { [16] = SWORD }
Put(POLE) Put(BAUBLE, 2)
Login()
check(NAMED.SkittFiskeWindow and not NAMED.SkittFiskeWindow.shown, "vinduet er bygget og skjult")
check(Chat("glow:"), "det som feilet, står i chatten")
check(SkittFiskeDB.debug.ui[1]:find("glow", 1, true), "og i debug")

local ok, err = pcall(Slash, "")
check(ok, "start virker: " .. tostring(err))
check(NAMED.SkittFiskeWindow.shown, "vinduet vises")
T.equip[16] = SWORD
local ok2, err2 = pcall(Fire, "UNIT_INVENTORY_CHANGED", "player")
check(ok2, "stangen av: ingen feil: " .. tostring(err2))
T.wench = 20000
check(pcall(NS.Window.RefreshLure), "agnet lyser uten animasjon")

-- Vinduet ble aldri bygget (alt feiler): ingenting annet skal krasje
local W = NS.Window
Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "g", 7620)
local okHide = pcall(Slash, "")
check(okHide, "avslutt virker")
check(SkittFiskeDB.history[1] ~= nil, "rapporten lagres")
