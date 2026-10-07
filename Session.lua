-- Økta: kast, fangst, de som slapp unna, og rapporten til slutt. Økta ligger i SkittFiskeCharDB.session,
-- så den overlever /reload. Fangst per sone samles i SkittFiskeDB.zones (grunnlaget for lista over hva som kan fanges).
local addonName, ns = ...
local Session = {}
ns.Session = Session
local Logic, Game = ns.Logic, ns.Game

local function zoneKey()
  local z, sub = Game.Zone()
  if sub ~= "" and sub ~= z then return z .. " / " .. sub, z end
  return z, z
end

function Session.Start(cdb)
  if cdb.session then return end
  local _, z = zoneKey()
  cdb.session = Logic.NewSession(Game.Clock(), z, (Game.Skill()))
end

------------------------------------------------------------------------
-- Pris: normalkursen fra Sparkmack's kursbok etter 5 % AH-avgift, ellers det vendoren betaler
------------------------------------------------------------------------

function Session.AhPrice(id)
  local K, DB = SparkmackKursbok, SparkmackDB
  if not (type(K) == "table" and K.summary and type(DB) == "table" and type(DB.hist) == "table") then return nil end
  local H = DB.hist[Game.Market()]
  if not H then return nil end
  local key = id .. ":0"
  local ok, sum = pcall(K.summary, H, Game.Clock(), nil, { [key] = true })
  local it = ok and type(sum) == "table" and sum.items and sum.items[key]
  if it and type(it.ref) == "number" and it.ref > 0 then return it.ref end
end

function Session.HasSparkmack()
  return type(SparkmackKursbok) == "table" and type(SparkmackDB) == "table"
end

function Session.Price(id)
  local vendor = Game.SellPrice(id)
  local ah = Session.AhPrice(id)
  if ah then ah = ah * 0.95 end
  if ah and (not vendor or ah > vendor) then return ah end
  return vendor
end

function Session.Stop(cdb, db)
  local s = cdb.session
  if not s then return nil end
  local r = Logic.Report(s, Game.Clock(), Session.Price, (Game.Skill()), Game.try(UnitName, "player"))
  r.sparkmack = Session.HasSparkmack()
  db.history = db.history or {}
  Logic.PushHistory(db.history, r, ns.Data.HISTORY_MAX)
  cdb.session = nil
  return r
end

------------------------------------------------------------------------
-- Hendelser
------------------------------------------------------------------------

function Session.OnChannelStart(cdb, spellId)
  local s = cdb.session
  local name = spellId and ((C_Spell and C_Spell.GetSpellName) and Game.try(C_Spell.GetSpellName, spellId)
    or Game.try(GetSpellInfo, spellId))
  if not Game.IsFishingSpell(spellId, name) then return end
  ns.Debug.Count("channel")
  if s then s.casts = s.casts + 1 end
  if ns.active then ns.Debug.BiteStart() end
end

local lootOpen, moneyBefore, pending
function Session.OnLootOpened(cdb, db)
  if lootOpen then return end
  lootOpen = true
  local fishing = Game.try(IsFishingLoot)
  ns.Debug.Loot(fishing)
  if not fishing then pending = nil return end
  local loot = {}
  for i = 1, (Game.try(GetNumLootItems) or 0) do
    local link = Game.try(GetLootSlotLink, i)
    local id = Game.IdFromLink(link)
    if id then
      local _, name, qty = Game.try(GetLootSlotInfo, i)
      loot[#loot + 1] = { id = id, n = (type(qty) == "number" and qty > 0) and qty or 1, name = name }
    end
  end
  pending = loot
  moneyBefore = Game.try(GetMoney)
  db.zones = db.zones or {}
  Logic.AddZoneCatch(db.zones, (zoneKey()), loot)
  if cdb.session then Logic.AddCatch(cdb.session, loot) end
end

-- Penger fra fiske-loot: forskjellen i gull fra vinduet åpnet til det lukkes
function Session.OnLootClosed(cdb)
  lootOpen = false
  if not pending then return end
  pending = nil
  local after = Game.try(GetMoney)
  if cdb.session and moneyBefore and after and after > moneyBefore then
    cdb.session.money = (cdb.session.money or 0) + (after - moneyBefore)
  end
  moneyBefore = nil
end

function Session.OnError(cdb, a, b)
  local msg = type(b) == "string" and b or (type(a) == "string" and a) or nil
  if not msg or Game.secret(msg) then return end
  ns.Debug.Error(msg)
  local s = cdb.session
  if not s then return end
  if ERR_FISH_ESCAPED and msg == ERR_FISH_ESCAPED then s.escaped = s.escaped + 1
  elseif ERR_FISH_NOT_HOOKED and msg == ERR_FISH_NOT_HOOKED then s.missed = s.missed + 1 end
end
