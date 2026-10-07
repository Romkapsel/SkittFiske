-- Svar fra spillet (fase 0): hva Forever-klienten faktisk gjør. Lagres i SkittFiskeDB.debug, så de kan leses
-- fra SavedVariables etter /reload eller utlogging. /skitt debug skriver et sammendrag i chatten og tar et øyeblikksbilde.
local addonName, ns = ...
local D = {}
ns.Debug = D
local Game = ns.Game

local function store()
  local db = ns.db
  if not db then return nil end
  db.debug = db.debug or {}
  local d = db.debug
  d.counts = d.counts or {}
  d.errors = d.errors or {}
  d.loot = d.loot or {}
  return d
end

function D.Count(k)
  local d = store()
  if d then d.counts[k] = (d.counts[k] or 0) + 1 end
end

-- Feilmeldinger mens du fisker (for å finne «Your fish got away!» og «No fish are hooked.»)
-- Korte notater (utstyrsbytte som feilet, handlinger spillet blokkerte), de 10 siste per type
function D.Note(kind, text)
  local d = store()
  if not d then return end
  d.notes = d.notes or {}
  local list = d.notes[kind] or {}
  d.notes[kind] = list
  table.insert(list, 1, ("%s %s"):format(date and date("%H:%M:%S") or "", tostring(text)))
  while #list > 10 do table.remove(list) end
end

function D.Error(msg)
  local d = store()
  if not d or not ns.active then return end
  D.BiteMark("feil: " .. msg)
  if d.errors[1] == msg then return end
  table.insert(d.errors, 1, msg)
  while #d.errors > 10 do table.remove(d.errors) end
end

-- Noe i vinduet eller rapporten som spillet nektet: lagres og vises én gang i chatten
function D.Ui(label, err)
  local d = store()
  local msg = tostring(label) .. ": " .. tostring(err)
  if d then
    d.ui = d.ui or {}
    for _, m in ipairs(d.ui) do if m == msg then return end end
    table.insert(d.ui, 1, msg)
    while #d.ui > 10 do table.remove(d.ui) end
  end
  ns.Print("|cffff6060" .. msg .. "|r")
end

function D.Loot(fishing)
  local d = store()
  if not d then return end
  local items = {}
  for i = 1, (Game.try(GetNumLootItems) or 0) do
    local link = Game.try(GetLootSlotLink, i)
    local _, name, qty = Game.try(GetLootSlotInfo, i)
    items[#items + 1] = tostring(link or name) .. " x" .. tostring(qty)
  end
  table.insert(d.loot, 1, { fishing = tostring(fishing), items = items, zone = table.concat({ Game.Zone() }, " / ") })
  while #d.loot > 5 do table.remove(d.loot) end
end

------------------------------------------------------------------------
-- Nappe-lytteren (Daniel 7. okt: kan fiskeøyet lyse når fisken napper?). Mens duppen er ute, noteres alle hendelser
-- spillet sender (hver høyst 3 ganger per kast), med sekunder siden kastet, pluss når loot åpnes og kastet stopper.
-- Finnes det en hendelse som alltid kommer like før fangsten, er det nappet. Lagres i SkittFiskeDB.debug.bite.
------------------------------------------------------------------------

local probe, cast

local function show(v)
  if v == nil then return "" end
  if Game.secret(v) then return "<hemmelig>" end
  local s = tostring(v)
  return #s > 40 and s:sub(1, 40) or s
end

function D.BiteMark(what)
  if not cast or cast.n >= 150 then return end
  cast.n = cast.n + 1
  cast.ev[#cast.ev + 1] = ("%.2f >> %s"):format(Game.Now() - cast.t0, show(what))
end

function D.BiteEvent(e, a, b)
  if not cast or cast.n >= 150 then return end
  cast.seen[e] = (cast.seen[e] or 0) + 1
  if cast.seen[e] > 3 then return end
  cast.n = cast.n + 1
  cast.ev[#cast.ev + 1] = ("%.2f %s %s %s"):format(Game.Now() - cast.t0, e, show(a), show(b))
end

function D.BiteStart()
  local d = store()
  if not d then return end
  if not probe then
    probe = CreateFrame("Frame")
    probe:SetScript("OnEvent", function(_, e, ...) D.BiteEvent(e, ...) end)
    -- Spillets «myke» mål (Interact-tasten) kan peke på duppen: noter når navnet endrer seg
    probe:SetScript("OnUpdate", function(self, el)
      self.t = (self.t or 0) + el
      if self.t < 0.1 or not cast then return end
      self.t = 0
      local n = Game.try(UnitName, "softinteract")
      if n ~= cast.soft then cast.soft = n D.BiteMark("softinteract=" .. tostring(n)) end
    end)
  end
  cast = { t0 = Game.Now(), ev = {}, seen = {}, n = 0 }
  d.bite = d.bite or {}
  table.insert(d.bite, 1, cast)
  while #d.bite > 8 do table.remove(d.bite) end
  pcall(probe.RegisterAllEvents, probe)
  probe:Show()
end

-- Kastet er over: lytt 2 s til (loot og feilmeldinger kommer like etter), så stopp
function D.BiteStop()
  local mine = cast
  if not mine then return end
  D.BiteMark("kastet stopper")
  local function stop()
    if cast ~= mine then return end
    if probe then pcall(probe.UnregisterAllEvents, probe) probe:Hide() end
    cast.seen, cast = nil, nil
  end
  if C_Timer then C_Timer.After(2, stop) else stop() end
end

function D.Snapshot()
  local d = store()
  if not d then return nil end
  local _, build, _, iface = Game.try(GetBuildInfo)
  local rank, max, mod = Game.Skill()
  local has, ms = Game.LureOnPole()
  local s = {
    build = tostring(build), interface = tostring(iface),
    spell = Game.FishingName(),
    skill = rank and (rank .. "/" .. tostring(max) .. " +" .. tostring(mod)) or "ukjent",
    keyDown = tostring(Game.GetCVar("ActionButtonUseKeyDown")),
    bgSound = tostring(Game.GetCVar("Sound_EnableSoundWhenGameIsInBG")),
    tooltipInfo = C_TooltipInfo ~= nil,
    worldFrameHook = WorldFrame ~= nil and WorldFrame.HookScript ~= nil,
    lureOnPole = tostring(has) .. " " .. tostring(ms),
    errFishEscaped = tostring(ERR_FISH_ESCAPED), errNotHooked = tostring(ERR_FISH_NOT_HOOKED),
    sparkmack = ns.Session.HasSparkmack(),
    gear = {},
  }
  for _, c in ipairs(ns.Gear.Scan()) do
    s.gear[#s.gear + 1] = ("%s slot %d bonus %d%s%s"):format(tostring(c.link or c.id), c.slot, c.bonus,
      c.pole and " stang" or "", c.equipped and " (på)" or "")
  end
  d.snapshot = s
  return s, d
end

function D.Show()
  local s, d = D.Snapshot()
  if not s then return end
  local c = d.counts
  ns.Print(("build %s · %s · skill %s · ActionButtonUseKeyDown %s · bakgrunnslyd %s"):format(
    s.build, s.spell, s.skill, s.keyDown, s.bgSound))
  ns.Print(("høyreklikk %d · dobbeltklikk %d · kast-knapp %d · kast %d"):format(
    c.rightDown or 0, c.armed or 0, c.castClick or 0, c.channel or 0))
  ns.Print(("agn på stanga: %s · utstyr funnet: %d · Sparkmack: %s"):format(s.lureOnPole, #s.gear,
    s.sparkmack and "ja" or "nei"))
  local l = d.loot[1]
  if l then ns.Print(("siste loot: fiske=%s · %s"):format(l.fishing, table.concat(l.items, ", "))) end
  if d.errors[1] then ns.Print("siste feilmelding: " .. d.errors[1]) end
  if d.ui and d.ui[1] then ns.Print("vinduet: " .. d.ui[1]) end
  ns.Print(("nappe-lytteren har %d kast lagret"):format(d.bite and #d.bite or 0))
end

function D.Clear()
  if ns.db then ns.db.debug = nil end
  ns.Print("debug tømt.")
end
