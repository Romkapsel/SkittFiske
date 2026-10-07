-- Alt som spør spillet. Hvert kall går gjennom pcall og sjekker hemmelige verdier, så addonen aldri krasjer.
local addonName, ns = ...
local Game = {}
ns.Game = Game
local Data = ns.Data

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
Game.secret = secret

-- Første returverdi fra f(...), eller nil ved feil eller hemmelig verdi
local function try(f, ...)
  if not f then return nil end
  local ok, a, b, c, d, e, g, h, i, j, k, l = pcall(f, ...)
  if not ok or secret(a) then return nil end
  return a, b, c, d, e, g, h, i, j, k, l
end
Game.try = try

------------------------------------------------------------------------
-- Fiskeskillen
------------------------------------------------------------------------

local spellName
function Game.FishingName()
  if spellName then return spellName end
  for _, id in ipairs(Data.FISHING_SPELLS) do
    local n = (C_Spell and C_Spell.GetSpellName) and try(C_Spell.GetSpellName, id) or try(GetSpellInfo, id)
    if type(n) == "string" and n ~= "" then spellName = n return n end
  end
  return Data.FISHING_FALLBACK
end

function Game.IsFishingSpell(id, name)
  if id and not secret(id) then
    for _, f in ipairs(Data.FISHING_SPELLS) do if f == id then return true end end
  end
  return type(name) == "string" and not secret(name) and name == Game.FishingName()
end

-- Svar: rank, max, bonus (fra utstyr og agn), eller nil
function Game.Skill()
  local want = Game.FishingName()
  if GetNumSkillLines and GetSkillLineInfo then
    local n = try(GetNumSkillLines) or 0
    for i = 1, n do
      local name, header, _, rank, _, mod, max = try(GetSkillLineInfo, i)
      if not header and name == want and type(rank) == "number" then return rank, max, mod or 0 end
    end
  end
  if GetProfessions and GetProfessionInfo then
    local _, _, _, fishing = try(GetProfessions)
    if fishing then
      local _, _, rank, max, _, _, _, mod = try(GetProfessionInfo, fishing)
      if type(rank) == "number" then return rank, max, mod or 0 end
    end
  end
  return nil
end

-- Står du og fisker nå (duppen er ute)?
function Game.IsFishing()
  local name, _, _, _, _, _, _, id = try(UnitChannelInfo, "player")
  if not name then return false end
  return Game.IsFishingSpell(id, name)
end

------------------------------------------------------------------------
-- Ting
------------------------------------------------------------------------

function Game.ItemInstant(id)
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local _, _, _, loc, icon, class, sub = try(f, id)
  return loc, class, sub, icon
end

function Game.ItemName(id)
  local n = (C_Item and C_Item.GetItemNameByID) and try(C_Item.GetItemNameByID, id) or try(GetItemInfo, id)
  if type(n) == "string" then return n end
end

function Game.ItemIcon(id)
  local i = (C_Item and C_Item.GetItemIconByID) and try(C_Item.GetItemIconByID, id)
  if i then return i end
  local _, _, _, icon = Game.ItemInstant(id)
  return icon or 134400
end

function Game.SellPrice(id)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local r = { try(f, id) }
  local p = r[11]
  if type(p) == "number" and p > 0 then return p end
end

function Game.ItemCount(id)
  local f = (C_Item and C_Item.GetItemCount) or GetItemCount
  return try(f, id) or 0
end

local function idFromLink(l) return type(l) == "string" and tonumber(l:match("item:(%d+)")) or nil end
Game.IdFromLink = idFromLink

-- Alle plasser i baggene: fn(bag, slot, id, link, count)
function Game.EachBagItem(fn)
  local C = C_Container
  local num = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  local getId = (C and C.GetContainerItemID) or GetContainerItemID
  local getLink = (C and C.GetContainerItemLink) or GetContainerItemLink
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local n = try(num, bag) or 0
    for s = 1, n do
      local id = try(getId, bag, s)
      if id then
        local link = try(getLink, bag, s)
        local count = 1
        if C and C.GetContainerItemInfo then
          local info = try(C.GetContainerItemInfo, bag, s)
          if type(info) == "table" and type(info.stackCount) == "number" then count = info.stackCount end
        elseif GetContainerItemInfo then
          local _, c = try(GetContainerItemInfo, bag, s)
          if type(c) == "number" then count = c end
        end
        fn(bag, s, id, link, count)
      end
    end
  end
end

function Game.FreeBag()
  local f = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local free, family = try(f, bag)
    if (free or 0) > 0 and (family or 0) == 0 then return bag end
  end
end

function Game.Equipped(slot)
  return try(GetInventoryItemID, "player", slot), try(GetInventoryItemLink, "player", slot)
end

------------------------------------------------------------------------
-- Tooltip-linjer (venstre tekst). where = { bag, slot } | { inv = slot } | { id = id }
------------------------------------------------------------------------

local scanTip
local function scanLines(setter, ...)
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "SkittFiskeScanTip", UIParent, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  scanTip:ClearLines()
  if not pcall(scanTip[setter], scanTip, ...) then return {} end
  local out = {}
  for i = 1, (scanTip:NumLines() or 0) do
    local fs = _G["SkittFiskeScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    if type(t) == "string" and not secret(t) then out[#out + 1] = t end
  end
  return out
end

local function infoLines(data)
  local out = {}
  if type(data) == "table" and type(data.lines) == "table" then
    for _, line in ipairs(data.lines) do
      local t = line.leftText
      if type(t) == "string" and not secret(t) then out[#out + 1] = t end
    end
  end
  return out
end

function Game.TooltipLines(where)
  local T = C_TooltipInfo
  if T then
    local data
    if where.bag then data = try(T.GetBagItem, where.bag, where.slot)
    elseif where.inv then data = try(T.GetInventoryItem, "player", where.inv)
    else data = try(T.GetItemByID, where.id) end
    if data then return infoLines(data) end
  end
  if where.bag then return scanLines("SetBagItem", where.bag, where.slot) end
  if where.inv then return scanLines("SetInventoryItem", "player", where.inv) end
  return scanLines("SetItemByID", where.id)
end

-- Et agn vi ikke kjenner: noe som brukes på fiskestanga
function Game.IsLure(id)
  if Data.LURES[id] then return true end
  local loc = Game.ItemInstant(id)
  if loc and loc ~= "" then return false end
  for _, t in ipairs(Game.TooltipLines({ id = id })) do
    local l = t:lower()
    if l:find("^use:") and l:find("fishing pole", 1, true) then return true end
  end
  return false
end

------------------------------------------------------------------------
-- Ta på og av
------------------------------------------------------------------------

function Game.Equip(item, slot)
  local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
  if not f then return false end
  return (pcall(f, item, slot))
end

-- Ta av det som sitter på slot, og legg det i en ledig bag
function Game.Unequip(slot)
  local bag = Game.FreeBag()
  if not bag then return false end
  if not pcall(PickupInventoryItem, slot) then return false end
  local ok
  if bag == 0 then
    ok = pcall(PutItemInBackpack)
  else
    local toInv = (C_Container and C_Container.ContainerIDToInventoryID) or ContainerIDToInventoryID
    local inv = try(toInv, bag)
    ok = inv and pcall(PutItemInBag, inv)
  end
  if not ok and ClearCursor then pcall(ClearCursor) end
  return ok and true or false
end

-- Klikk på knapper: ned når spillet bruker «ActionButtonUseKeyDown», ellers opp (Control V5)
function Game.ClickMode()
  return Game.GetCVar("ActionButtonUseKeyDown") == "0" and "AnyUp" or "AnyDown"
end

function Game.InCombat()
  return (try(InCombatLockdown) or try(UnitAffectingCombat, "player")) and true or false
end

------------------------------------------------------------------------
-- Annet
------------------------------------------------------------------------

function Game.GetCVar(k)
  local f = (C_CVar and C_CVar.GetCVar) or GetCVar
  local v = try(f, k)
  if v ~= nil then return tostring(v) end
end

function Game.SetCVar(k, v)
  local f = (C_CVar and C_CVar.SetCVar) or SetCVar
  return f and (pcall(f, k, v)) or false
end

function Game.Zone()
  local z = try(GetRealZoneText) or ""
  local sub = try(GetSubZoneText) or ""
  return z, sub
end

-- Agnet på stanga: har, millisekunder igjen
function Game.LureOnPole()
  local has, ms = try(GetWeaponEnchantInfo)
  if has == nil then return nil end
  return has and true or false, ms
end

function Game.Market()
  return (try(GetRealmName) or "?") .. "|" .. (try(UnitFactionGroup, "player") or "?")
end

function Game.Now() return try(GetTime) or 0 end
function Game.Clock() return (time and time()) or 0 end
