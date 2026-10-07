-- Fiskeutstyret: finn det beste, ta det på, og sett det gamle tilbake. Det gamle huskes i SkittFiskeCharDB.saved,
-- så det overlever /reload og utlogging.
local addonName, ns = ...
local Gear = {}
ns.Gear = Gear
local Data, Logic, Game, L = ns.Data, ns.Logic, ns.Game, ns.L
local MH, OH = Data.MAIN_HAND, Data.OFF_HAND

-- Alt du har på og i baggen som gir fiskeskill, og alle fiskestenger
function Gear.Scan()
  local name = Game.FishingName()
  local list = {}
  local function add(where, id, link, equippedSlot)
    local loc, class, sub = Game.ItemInstant(id)
    local slot = loc and Data.SLOT_OF[loc]
    if not slot then return end
    local pole = class == Data.POLE_CLASS and sub == Data.POLE_SUBCLASS
    if slot == MH and not pole then return end
    local bonus = Logic.FishingBonus(Game.TooltipLines(where), name)
    if not pole and bonus <= 0 then return end
    list[#list + 1] = { slot = equippedSlot or slot, bonus = bonus, pole = pole, id = id, link = link,
                        equipped = equippedSlot }
  end
  for _, s in ipairs(Data.EQUIP_SLOTS) do
    local id, link = Game.Equipped(s)
    if id then add({ inv = s }, id, link, s) end
  end
  Game.EachBagItem(function(bag, slot, id, link) add({ bag = bag, slot = slot }, id, link, nil) end)
  return list
end

local function remember(saved, slot)
  if saved[slot] ~= nil then return end
  local id, link = Game.Equipped(slot)
  saved[slot] = id and { id = id, link = link } or false
end

-- Ta på fiskeutstyret. Svar: om du har en stang, og hvor mange ting som byttes
function Gear.Start(cdb)
  local plan, hasPole = Logic.PlanGear(Gear.Scan(), MH)
  local saved = cdb.saved or {}
  local n = 0
  for slot in pairs(plan) do remember(saved, slot) n = n + 1 end
  if plan[MH] then remember(saved, OH) end
  cdb.saved = saved
  local order = Logic.SlotOrder(plan, MH, OH)
  for _, slot in ipairs(order) do
    local c = plan[slot]
    Game.Equip(c.link or c.id, slot)
  end
  -- Et bytte kan feile når to ting flyttes samtidig: prøv én gang til litt senere
  if n > 0 and C_Timer then
    C_Timer.After(0.6, function()
      if Game.InCombat() then return end
      for _, slot in ipairs(order) do
        local c = plan[slot]
        if Game.Equipped(slot) ~= c.id then Game.Equip(c.link or c.id, slot) end
      end
    end)
  end
  return hasPole, n
end

local function itemLabel(want) return want.link or Game.ItemName(want.id) or ("#" .. want.id) end

-- Ett forsøk på å sette tilbake. weaponsOnly i kamp. Svar: plassene som ikke stemmer ennå
local function attempt(saved, weaponsOnly)
  local wrong = {}
  for _, slot in ipairs(Logic.SlotOrder(saved, MH, OH)) do
    local want = saved[slot]
    local weapon = slot == MH or slot == OH
    local cur = Game.Equipped(slot)
    if want and cur ~= want.id then
      if weaponsOnly and not weapon then wrong[#wrong + 1] = slot
      else Game.Equip(want.link or want.id, slot) wrong[#wrong + 1] = slot end
    elseif want == false and cur then
      -- Plassen var tom før fiskingen (en vanlig hatt fantes ikke). Ta av, men ikke i kamp.
      -- Off-hand-plassen tømmes av seg selv når en tohånds stang går av.
      if slot ~= OH then
        if weaponsOnly then wrong[#wrong + 1] = slot
        elseif not Game.Unequip(slot) then ns.Print(L.NO_SPACE:format(Game.ItemName(cur) or "?")) end
      end
    end
  end
  return wrong
end

-- Sett det gamle utstyret tilbake. Svar: true når alt er gjort nå, false når noe venter på at kampen er over
function Gear.Restore(cdb)
  local saved = cdb.saved
  if not saved then return true end
  local combat = Game.InCombat()
  local wrong = attempt(saved, combat)
  if combat then
    cdb.restorePending = true
    return false
  end
  cdb.restorePending = nil
  if #wrong == 0 then cdb.saved = nil return true end
  if C_Timer then
    C_Timer.After(0.7, function()
      if Game.InCombat() or cdb.saved ~= saved then return end
      local still = attempt(saved, false)
      C_Timer.After(0.7, function()
        if cdb.saved ~= saved then return end
        for _, slot in ipairs(still) do
          local want = saved[slot]
          if want and Game.Equipped(slot) ~= want.id then ns.Print(L.MISSING_ITEM:format(itemLabel(want))) end
        end
        cdb.saved = nil
      end)
    end)
  else
    cdb.saved = nil
  end
  return true
end
