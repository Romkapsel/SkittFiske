-- En fremmed spiller: annen realm og fraksjon, første gang, ingen stang, ingen fiskeskill ennå, full makroliste.
-- Og en med Sparkmack: verdien hentes fra kursboka.
T.realm, T.faction, T.player = "Annen Realm", "Horde", "Fremmed"
T.skill = nil
T.macroLimit = 0
T.equip = { [1] = HELM }
Put(HAT)
Login()
check(Chat("fikk ikke laget makroen"), "full makroliste: du får beskjed")
check(not SkittFiskeDB.macroMade, "prøver igjen neste gang")

Slash("")
check(NS.active, "fiskemodus uten stang")
check(Chat("ingen fiskestang"), "beskjed om at stang mangler")
check(T.equip[1] == HAT, "hatten på likevel")
Slash("")
RunTimers(2)
check(T.equip[1] == HELM, "tilbake")
local r = SkittFiskeDB.history[1]
check(r == nil, "en økt uten kast gir ingen rapport")
check(NS.Report.Lines({ secs = 60, casts = 3, caught = 0, items = {}, money = 0, total = 0 })[5].left
  == "Ingenting på kroken denne gangen.", "«Ingenting på kroken» når du kastet uten fangst")

-- Med Sparkmack: normalkurs i kursboka for markedet du står i
SparkmackDB = { hist = { ["Annen Realm|Horde"] = { fmt = 2 } } }
SparkmackKursbok = { summary = function(H, now, y, only)
  local items = {}
  if only["6358:0"] then items["6358:0"] = { ref = 1000 } end
  return { items = items }
end }
Put(POLE)
Slash("")
T.loot = { fishing = true, items = { { OILY, 2 }, { SMALLFISH, 1 } } }
Fire("LOOT_OPENED") Fire("LOOT_CLOSED")
T.clock = T.clock + 600
Slash("")
r = SkittFiskeDB.history[1]
check(r.sparkmack == true, "Sparkmack funnet")
check(r.items[1].id == OILY and r.items[1].value == 1900, "normalkurs etter AH-avgift: 2 × 950")
check(r.items[2].value == 1, "uten kurs: vendorprisen")
check(r.perHour == math.floor(1901 * 6 + 0.5), "per time")
local src = NS.Report.Lines(r)
check(src[#src].left:find("Sparkmack", 1, true), "rapporten sier hvor verdien kommer fra")

-- Et annet marked i kursboka gir ingen kurs
T.realm = "Tredje"
check(NS.Session.AhPrice(OILY) == nil, "andre markeder brukes ikke")

-- Sparkmack som feiler, velter ikke rapporten
SparkmackKursbok.summary = function() error("boom") end
T.realm = "Annen Realm"
check(NS.Session.AhPrice(OILY) == nil and NS.Session.Price(OILY) == 4, "feil i kursboka: vendorpris")
