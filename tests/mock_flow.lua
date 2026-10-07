-- Hele runden: makro, start (utstyr, lyd, vindu), kast med dobbeltklikk, fangst, agn, stopp (utstyret tilbake, rapport)

-- Det du har på deg og i baggen
T.equip = { [1] = HELM, [8] = OLDBOOTS, [10] = GLOVES, [16] = SWORD, [17] = SHIELD }
T.enchant[10] = "Fishing +2"
Put(POLE) Put(ARCANITE) Put(HAT) Put(BOOTS) Put(REQ_HAT) Put(BAUBLE, 3) Put(CRAWLER, 5) Put(NEWLURE, 2) Put(BREAD, 10)
local before = {}
for k, v in pairs(T.cvars) do before[k] = v end

Login()
check(#T.macros == 1 and T.macros[1].name == "Skitt Fiske" and T.macros[1].body == "/skitt", "makroen lages")
check(T.macros[1].perChar == nil, "felles makro for alle karakterene")
check(Chat("makroen «Skitt Fiske» er laget"), "du får beskjed om makroen")
check(SkittFiskeDB.macroMade, "makroen lages bare én gang")
Slash("makro")
check(T.cursorMacro == 1, "/skitt makro legger den på musa")

local win = NAMED.SkittFiskeWindow
check(win and not win.shown, "vinduet er skjult før du fisker")

-- Start
Slash("")
check(NS.active and SkittFiskeCharDB.active, "fiskemodus på")
check(T.equip[16] == ARCANITE, "beste stang på")
check(T.equip[1] == HAT, "fiskehatten på (ikke den som bare krever skill)")
check(T.equip[8] == BOOTS, "fiskestøvlene på")
check(T.equip[10] == GLOVES, "hanskene med fiske-enchant blir sittende")
check(T.equip[17] == nil, "skjoldet gikk i baggen (tohånds stang)")
local saved = SkittFiskeCharDB.saved
check(saved[16].id == SWORD and saved[17].id == SHIELD and saved[1].id == HELM and saved[8].id == OLDBOOTS, "det gamle huskes")
check(saved[10] == nil, "hansker som ikke byttes huskes ikke")
check(T.cvars.Sound_SFXVolume == "1" and T.cvars.Sound_MusicVolume == "0" and T.cvars.Sound_AmbienceVolume == "0", "effekter opp, musikk og omgivelser av")
check(T.cvars.Sound_EnableSoundWhenGameIsInBG == "1", "lyd når du er ute av spillet")
check(SkittFiskeDB.sound.Sound_SFXVolume == "0.4", "den gamle lyden huskes")
check(win.shown, "vinduet åpnes")
check(SkittFiskeCharDB.session and SkittFiskeCharDB.session.skillStart == 120, "økta starter med skillen")
check(not Chat("ingen fiskestang"), "ingen klage når du har stang")

-- Trykk på /skitt to ganger i samme økt endrer ikke det som huskes
Slash("vindu")
check(SkittFiskeCharDB.saved[16].id == SWORD, "det gamle er uendret")

-- Kast: dobbelt høyreklikk binder høyre musknapp til kast-knappen
DoubleRight(0.6)
check(T.bindings.BUTTON2 == nil, "to langsomme klikk: ingenting")
DoubleRight(0.2)
check(T.bindings.BUTTON2 == "SkittFiskeCastButton", "dobbelt høyreklikk: neste slipp kaster")
local cast = NAMED.SkittFiskeCastButton
check(cast.attrs.type == "spell" and cast.attrs.spell == "Fishing", "kast-knappen kaster Fishing")
check(cast.clicks[1] == "AnyUp", "kast-knappen tar imot slippet")
Click(cast)
check(T.casts[1] == "Fishing", "kastet")
check(T.bindings.BUTTON2 == nil, "høyre musknapp er vanlig igjen etter kastet")
Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
check(SkittFiskeCharDB.session.casts == 1, "kastet telles")
Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 133)
check(SkittFiskeCharDB.session.casts == 1, "andre spells telles ikke")

-- Mens duppen er ute, gjør dobbeltklikk ingenting (høyreklikk på duppen fanger)
T.channel = "Fishing"
DoubleRight(0.2)
check(T.bindings.BUTTON2 == nil, "duppen er ute: ingen nytt kast")
T.channel = nil
T.mouseover = true
DoubleRight(0.2)
check(T.bindings.BUTTON2 == nil, "musa over en figur: ingen kast")
T.mouseover = false

-- Fangst
T.loot = { fishing = true, items = { { SMALLFISH, 1 } } }
Fire("LOOT_OPENED")
Fire("LOOT_READY")
Fire("LOOT_OPENED")
T.money = T.money + 0
Fire("LOOT_CLOSED")
T.loot = { fishing = true, items = { { OILY, 1 }, { SMALLFISH, 2 } } }
Fire("LOOT_OPENED")
T.money = T.money + 25
Fire("LOOT_CLOSED")
T.loot = { fishing = false, items = { { LONGJAW, 1 } } }
Fire("LOOT_OPENED")
Fire("LOOT_CLOSED")
local s = SkittFiskeCharDB.session
check(s.caught == 2, "to fangster (dobbel LOOT_OPENED teller én gang, vanlig loot teller ikke)")
check(s.items[SMALLFISH] == 3 and s.items[OILY] == 1 and s.items[LONGJAW] == nil, "fangsten per fisk")
check(s.money == 25, "penger fra fiske-loot")
check(SkittFiskeDB.zones["Elwynn Forest / Crystal Lake"].caught == 2, "fangsten lagres per sone")
Fire("UI_ERROR_MESSAGE", 51, "Your fish got away!")
Fire("UI_ERROR_MESSAGE", 52, "No fish are hooked.")
check(s.escaped == 1 and s.missed == 1, "slapp unna og for tidlig telles")

-- Agn: hvert agn i baggen får sin egen ring; klikk = agnet på stanga
local rings = NS.Window.Rings()
check(#rings == 4, "fire agn-ringer")
check(rings[1].secure and rings[1].clicks[1] == "AnyDown" and #rings[1].clicks == 1, "ringene klikkes bare én gang (AnyDown)")
check(rings[1].shown and rings[2].shown and rings[3].shown and not rings[4].shown, "tre agn vises")
check(rings[1].attrs.macrotext == "/use item:6530\n/use 16", "beste agn først, på stanga")
check(rings[3].attrs.macrotext == "/use item:999001\n/use 16", "nytt Forever-agn funnet via tooltipen")
Click(rings[1])
check(T.macroRuns[1] == "/use item:6530\n/use 16", "agnet brukes")
-- Bare ett slags agn igjen
for b = 0, 4 do for i = 1, T.bagSize do local id = T.bags[b][i] if id == CRAWLER or id == NEWLURE then T.bags[b][i] = nil end end end
Fire("BAG_UPDATE_DELAYED")
check(rings[1].attrs.macrotext == "/use item:6529\n/use 16" and rings[1].shown and not rings[2].shown, "ett agn: én ring")
-- Agnet på stanga
T.wench = 30000
NS.Window.RefreshLure()
T.wench = nil

-- Stopp
T.skill.rank = 124
T.clock = T.clock + 1800
Slash("")
check(not NS.active and not SkittFiskeCharDB.active, "fiskemodus av")
RunTimers(2)
check(T.equip[16] == SWORD and T.equip[17] == SHIELD and T.equip[1] == HELM and T.equip[8] == OLDBOOTS, "det gamle utstyret er tilbake")
check(SkittFiskeCharDB.saved == nil, "ingenting igjen å sette tilbake")
for k, v in pairs(before) do check(T.cvars[k] == v, "lyden tilbake: " .. k) end
check(SkittFiskeDB.sound == nil, "lyden er ikke husket lenger")
check(not win.shown, "vinduet lukkes")
local rep = NAMED.SkittFiskeReport
check(rep and rep.shown, "rapporten vises")
local r = SkittFiskeDB.history[1]
check(r and r.caught == 2 and r.casts == 1 and r.escaped == 1 and r.money == 25, "rapporten har fangsten")
check(r.skillFrom == 120 and r.skillTo == 124, "skillen gikk opp 4")
check(r.secs == 1800 and r.who == "Testfisker" and r.zone == "Elwynn Forest", "tid, hvem og hvor")
check(r.items[1].id == OILY and r.items[1].value == 4, "vendorpris uten Sparkmack")
check(r.total == 4 + 3 + 25 and r.perHour == 64, "verdi og per time")
check(r.sparkmack == false, "uten Sparkmack")
local lines = NS.Report.Lines(r)
local found = false
for _, l in ipairs(lines) do if l.left == "3 × Raw Brilliant Smallfish" then found = true end end
check(found, "rapportlinje: 3 × fisk")
check(SkittFiskeCharDB.session == nil, "økta er avsluttet")
check(T.bindings.BUTTON2 == nil, "ingen binding henger igjen")

-- Ingen globale utenom våre egne
for _, g in ipairs(NewGlobals()) do check(false, "ny global: " .. g) end
