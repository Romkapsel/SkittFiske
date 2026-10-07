-- Logic.lua alene, uten WoW-API
local Logic, L, Data = NS.Logic, NS.L, NS.Data

check(GetTime == nil and CreateFrame == nil, "ingen WoW-API i denne testen")

-- Fiskebonus fra tooltip
local B = Logic.FishingBonus
check(B({ "Strong Fishing Pole", "Equip: Increased Fishing +5." }, "Fishing") == 5, "Increased Fishing +5")
check(B({ "Reinforced Leather Gloves", "Fishing +2" }, "Fishing") == 2, "enchant Fishing +2")
check(B({ "+15 Fishing" }, "Fishing") == 15, "+15 Fishing")
check(B({ "Equip: Increases Fishing by 10." }, "Fishing") == 10, "Increases Fishing by 10")
check(B({ "Equip: Increased Fishing +20.", "Fishing +2" }, "Fishing") == 22, "stang med enchant: summen")
check(B({ "Requires Fishing (100)" }, "Fishing") == 0, "Requires Fishing (100) teller ikke")
check(B({ "Use: When applied to your fishing pole, increases Fishing by 25 for 10 min." }, "Fishing") == 0, "agnets Use-linje teller ikke")
check(B({ "Two-Hand", "Fishing Pole" }, "Fishing") == 0, "vanlig stang: 0")
check(B({ "Equip: Increased Angeln +5." }, "Angeln") == 5, "annet språk: skillnavnet fra spillet")
check(B(nil, "Fishing") == 0 and B({}, nil) == 0, "tomt: 0")

-- Plan for utstyret
local plan, hasPole = Logic.PlanGear({
  { slot = 16, bonus = 0, pole = true, id = 1 },
  { slot = 16, bonus = 35, pole = true, id = 2 },
  { slot = 1, bonus = 5, id = 3 },
  { slot = 1, bonus = 0, id = 4, equipped = 1 },
  { slot = 10, bonus = 2, id = 5, equipped = 10 },
  { slot = 8, bonus = 5, id = 6 },
  { slot = 16, bonus = 99, pole = false, id = 7 },
}, 16)
check(hasPole, "har stang")
check(plan[16] and plan[16].id == 2, "beste stang")
check(plan[1] and plan[1].id == 3, "fiskehatt")
check(plan[10] == nil, "hansker med enchant sitter allerede på")
check(plan[8] and plan[8].id == 6, "støvler")
local plan2, pole2 = Logic.PlanGear({ { slot = 1, bonus = 5, id = 3 } }, 16)
check(not pole2 and plan2[1], "uten stang: hatten likevel, men ingen stang")
local plan3 = Logic.PlanGear({ { slot = 16, bonus = 5, pole = true, id = 9, equipped = 16 }, { slot = 16, bonus = 5, pole = true, id = 8 } }, 16)
check(plan3[16] == nil, "lik bonus: behold den du har på")
local order = Logic.SlotOrder({ [1] = 1, [17] = 1, [8] = 1, [16] = 1 }, 16, 17)
check(order[1] == 16 and order[2] == 17 and order[3] == 1 and order[4] == 8, "rekkefølge: hovedhånd, off-hand, resten")

-- Lyd
local sp = Logic.SoundPlan({ Sound_EnableAllSound = "1", Sound_EnableSFX = "0", Sound_SFXVolume = "0.4",
  Sound_MusicVolume = "0.6", Sound_AmbienceVolume = "0.5", Sound_MasterVolume = "0.3", Sound_EnableSoundWhenGameIsInBG = "0" })
check(sp.Sound_EnableSFX == "1" and sp.Sound_SFXVolume == "1" and sp.Sound_MusicVolume == "0", "effekter opp, musikk av")
check(sp.Sound_EnableSoundWhenGameIsInBG == "1", "lyd når spillet ikke er i fokus")
check(sp.Sound_MasterVolume == "0.5", "lav hovedvolum løftes til 0.5")
check(sp.Sound_EnableAllSound == nil, "uendret verdi settes ikke")
local sp2 = Logic.SoundPlan({ Sound_MasterVolume = "0.9", Sound_SFXVolume = "1.0" })
check(sp2.Sound_MasterVolume == nil and sp2.Sound_SFXVolume == nil, "høyt nok volum røres ikke; 1.0 = 1")
check(Logic.SoundPlan({}).Sound_EnableSFX == nil, "ukjente innstillinger settes ikke")

-- Dobbeltklikk
check(Logic.IsDoubleClick(10, 10.3, 0.4), "0,3 s = dobbeltklikk")
check(not Logic.IsDoubleClick(10, 10.5, 0.4), "0,5 s = to enkeltklikk")
check(not Logic.IsDoubleClick(nil, 10, 0.4), "første klikk")
check(not Logic.IsDoubleClick(10, 10.01, 0.4), "samme klikk to ganger teller ikke")

-- Agn
local lures = Logic.Lures({ [6529] = 3, [6530] = 5, [999] = 2, [4540] = 10, [6532] = 0 }, Data.LURES, { [999] = true })
check(#lures == 3, "tre slags agn (brød og tomme teller ikke)")
check(lures[1].id == 6530 and lures[2].id == 6529 and lures[3].id == 999, "sortert på bonus, ukjente sist")
check(lures[1].count == 5, "antall")
local st, s = Logic.LureState(true, 420000, 60)
check(st == "ok" and s == 420, "7 min igjen")
check((Logic.LureState(true, 30000, 60)) == "low", "30 s igjen = lyser")
check((Logic.LureState(false)) == "none", "uten agn")

-- Økta og rapporten
local ses = Logic.NewSession(1000, "Elwynn Forest", 120)
Logic.AddCatch(ses, { { id = 6291, n = 1, name = "Raw Brilliant Smallfish" } })
Logic.AddCatch(ses, { { id = 6291, n = 2 }, { id = 6358, n = 1, name = "Oily Blackmouth" } })
Logic.AddCatch(ses, { { money = 35 } })
ses.casts, ses.escaped = 5, 1
check(ses.caught == 3 and ses.items[6291] == 3 and ses.money == 35, "fangst summeres")
local prices = { [6291] = 1, [6358] = 600 }
local r = Logic.Report(ses, 1000 + 1800, function(id) return prices[id] end, 123, "Testfisker")
check(r.secs == 1800 and r.caught == 3 and r.casts == 5, "tid, fanget, kast")
check(r.items[1].id == 6358 and r.items[1].value == 600, "mest verdifulle først")
check(r.items[2].n == 3 and r.items[2].value == 3, "verdi = pris × antall")
check(r.total == 603 + 35, "total med penger")
check(r.perHour == 1276, "per time")
check(r.skillFrom == 120 and r.skillTo == 123, "skill fra og til")
check(r.items[2].name == "Raw Brilliant Smallfish", "navnet huskes")
local r0 = Logic.Report(Logic.NewSession(0, "X", nil), 30, nil, nil)
check(r0.total == 0 and r0.perHour == nil and r0.skillFrom == nil, "tom økt")
check(Logic.TooLowSkill({ escaped = 4, caught = 10 }), "4 av 10 slapp unna = for lav skill")
check(not Logic.TooLowSkill({ escaped = 1, caught = 10 }), "1 av 10 er greit")
local zones = {}
Logic.AddZoneCatch(zones, "Elwynn Forest / Crystal Lake", { { id = 6291, n = 2 } })
Logic.AddZoneCatch(zones, "Elwynn Forest / Crystal Lake", { { id = 6291, n = 1 }, { money = 5 } })
check(zones["Elwynn Forest / Crystal Lake"].caught == 2 and zones["Elwynn Forest / Crystal Lake"].items[6291] == 3, "fangst per sone")
local hist = {}
for i = 1, 25 do Logic.PushHistory(hist, { n = i }, 20) end
check(#hist == 20 and hist[1].n == 25 and hist[20].n == 6, "de 20 siste, nyeste først")

-- Tekst
check(Logic.Coins(12345) == "1g 23s 45c", "1g 23s 45c")
check(Logic.Coins(50) == "50c" and Logic.Coins(0) == "0c", "kobber")
check(Logic.Coins(10005) == "1g 0s 5c", "gull og kobber")
check(Logic.Coins(20000) == "2g", "rene gull")
check(Logic.Duration(45, L) == "45 s" and Logic.Duration(600, L) == "10 min" and Logic.Duration(4500, L) == "1 t 15 min", "varighet")
check(Logic.Left(30, L) == "30 s" and Logic.Left(61, L) == "2 min", "tid igjen")

-- Nedtrekket: fisken som er fanget i området (underområdet først, ellers hele sonen)
local zz = {
  ["Elwynn Forest / Crystal Lake"] = { caught = 4, items = { [6291] = 3, [6303] = 1 } },
  ["Elwynn Forest / Goldshire"] = { caught = 2, items = { [6291] = 2 } },
  ["Stormwind City / The Canals"] = { caught = 1, items = { [6289] = 1 } },
}
local zl, scope, total = Logic.ZoneFish(zz, "Elwynn Forest", "Crystal Lake")
check(scope == "sub" and total == 4 and #zl == 2, "underområdet")
check(zl[1].id == 6291 and zl[1].n == 3 and zl[1].pct == 0.75, "flest først, med andel")
zl, scope, total = Logic.ZoneFish(zz, "Elwynn Forest", "Northshire Valley")
check(scope == "zone" and total == 6 and zl[1].n == 5, "nytt underområde: hele sonen")
zl, scope = Logic.ZoneFish(zz, "Durotar", "")
check(#zl == 0, "ingenting fanget her")

-- Hva som kan fanges: databasen først, så egen fangst som ikke står der
local fd = {
  ["Stormwind City"] = { { 6289, 0.5 }, { 6308, 0.3 }, { 6291, 0.18 }, { 858, 0.005 } },
  ["Elwynn Forest / Crystal Lake"] = { { 6291, 0.6 }, { 6289, 0.4 } },
  ["Elwynn Forest"] = { { 6291, 0.59 } },
}
local own = { ["Stormwind City / The Canals"] = { caught = 3, items = { [6289] = 2, [999002] = 1 } } }
local al, has = Logic.AreaFish(fd, own, "Stormwind City", "The Canals")
check(has and #al == 5, "databasen for sonen + egen ukjent fisk")
check(al[1].id == 6289 and al[1].pct == 0.5 and al[1].caught == 2, "sjanse fra databasen, hake når du har fått den")
check(al[2].caught == nil, "ikke fått ennå")
check(al[5].id == 999002 and al[5].own and al[5].caught == 1, "egen fangst som ikke står i databasen kommer sist")
al = Logic.AreaFish(fd, {}, "Elwynn Forest", "Crystal Lake")
check(#al == 2 and al[1].pct == 0.6, "underområdet har egne data")
al = Logic.AreaFish(fd, {}, "Elwynn Forest", "Goldshire")
check(#al == 1 and al[1].pct == 0.59, "ellers sonen")
al, has = Logic.AreaFish(fd, {}, "Durotar", "")
check(#al == 0 and not has, "ingen data")
check(Logic.Pct(0.42) == "42 %" and Logic.Pct(0.007) == "0,7 %" and Logic.Pct(0.005) == "0,5 %", "prosent som tekst")

-- Skill i området: underområdet først, ellers sonen; krav og sjanse som serveren regner
local sk = { ["Stormwind City"] = -20, ["Westfall"] = 55, ["Westfall / Longshore"] = 130 }
check(Logic.ZoneSkill(sk, "Stormwind City", "The Canals") == -20, "sonen når underområdet ikke har eget nivå")
check(Logic.ZoneSkill(sk, "Westfall", "Longshore") == 130, "underområdet har eget nivå")
check(Logic.ZoneSkill(sk, "Durotar", "") == nil, "ukjent område")
local need = Logic.SkillNeeds(-20)
check(need.min == 1 and need.full == 75, "Stormwind: krever 1, ingen slipper unna fra 75")
need = Logic.SkillNeeds(55)
check(need.min == 55 and need.full == 150, "Westfall: krever 55, full fangst fra 150")
check(Logic.CatchChance(90, -20) == 1, "90 i Stormwind: alt")
check(Logic.CatchChance(54, 55) == 0, "under nivået: ingenting")
check(Logic.CatchChance(55, 55) == 0.05, "på nivået: 5 %")
check(Logic.CatchChance(100, 55) == 0.5, "45 over: 50 %")
check(Logic.CatchChance(nil, 55) == nil, "ukjent skill")
