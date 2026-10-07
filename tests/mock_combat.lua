-- Kamp: noe angriper deg mens du fisker. Våpnene kommer på med en gang, resten etter kampen.
T.equip = { [1] = HELM, [8] = OLDBOOTS, [16] = SWORD, [17] = SHIELD }
Put(STRONG) Put(HAT) Put(BOOTS) Put(BAUBLE, 2)
Login()

Slash("")
check(T.equip[16] == STRONG and T.equip[1] == HAT, "fiskeutstyret på")

T.combat = true
Fire("PLAYER_REGEN_DISABLED")
check(Chat("du er i kamp!"), "du får beskjed om kampen")

-- Dobbeltklikk i kamp gjør ingenting (og feiler ikke)
DoubleRight(0.2)
check(T.bindings.BUTTON2 == nil, "ingen kast i kamp")

-- Hemmelige verdier i kamp krasjer ikke noe
local oldChannel = UnitChannelInfo
UnitChannelInfo = function() return SECRET end
check(NS.Game.IsFishing() == false, "hemmelig kast-info: regnes som ikke fisking")
UnitChannelInfo = oldChannel

-- Avslutt midt i kampen
local ok, err = pcall(Slash, "")
check(ok, "avslutning i kamp feiler ikke: " .. tostring(err))
check(T.equip[16] == SWORD and T.equip[17] == SHIELD, "våpnene er på med en gang")
check(T.equip[1] == HAT and T.equip[8] == BOOTS, "rustningen venter til kampen er over")
check(Chat("våpnene er på"), "du får vite at resten kommer etterpå")
check(SkittFiskeCharDB.restorePending and SkittFiskeCharDB.saved, "det som gjenstår er husket")
check(NAMED.SkittFiskeWindow.shown, "vinduet (med sikre knapper) skjules ikke i kamp")
check(NAMED.SkittFiskeReport.shown, "rapporten vises likevel")

-- Starte i kamp går ikke
Slash("")
check(not NS.active and Chat("ikke midt i kamp"), "ingen start i kamp")

T.combat = false
Fire("PLAYER_REGEN_ENABLED")
RunTimers(2)
check(T.equip[1] == HELM and T.equip[8] == OLDBOOTS and T.equip[16] == SWORD, "alt er tilbake etter kampen")
check(SkittFiskeCharDB.saved == nil and not SkittFiskeCharDB.restorePending, "ingenting venter")
check(Chat("utstyret ditt er på igjen"), "du får beskjed")
check(not NAMED.SkittFiskeWindow.shown, "vinduet lukkes etter kampen")

-- Vinduet åpnet i kamp (start rett før kampen, vist igjen etterpå)
Slash("")
T.combat = true
NS.Window.Hide()
check(NAMED.SkittFiskeWindow.shown, "skjuling i kamp venter")
T.combat = false
Fire("PLAYER_REGEN_ENABLED")
check(not NAMED.SkittFiskeWindow.shown, "skjult etter kampen")

-- Krysset i vinduet avslutter som makroen
check(NS.active, "fisker fortsatt (vinduet var bare skjult)")
for _, f in ipairs(ALLFRAMES) do
  if f.label and f.label.text == "X" and f.parent == NAMED.SkittFiskeWindow then RunScript(f, "OnClick") end
end
check(not NS.active and not NAMED.SkittFiskeWindow.shown, "krysset avslutter fiskingen")
