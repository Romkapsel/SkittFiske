-- Skitt Fiske: start og stopp, hendelser, makroen og /skitt
local addonName, ns = ...
local L, Game = ns.L, ns.Game

ns.active = false
local db, cdb
local queue = {}

function ns.Print(s) print(L.PREFIX .. s) end
function ns.Queue(k, v) queue[k] = v end

------------------------------------------------------------------------
-- Makroen på baren: /skitt
------------------------------------------------------------------------

local MACRO_ICONS = { "INV_Fishingpole_02", 132932, 134400 }

local function ensureMacro(announce)
  if Game.InCombat() or not (GetMacroIndexByName and CreateMacro) then return nil end
  local idx = Game.try(GetMacroIndexByName, L.MACRO_NAME) or 0
  if idx > 0 then return idx end
  for _, icon in ipairs(MACRO_ICONS) do
    local ok, i = pcall(CreateMacro, L.MACRO_NAME, icon, "/skitt", nil)
    if ok and type(i) == "number" and i > 0 then
      if announce then ns.Print(L.MACRO_MADE) end
      return i
    end
  end
  ns.Print(L.MACRO_FULL)
  return nil
end

local function macroToCursor()
  local idx = ensureMacro(false)
  if idx and PickupMacro and pcall(PickupMacro, idx) then ns.Print(L.MACRO_ON_CURSOR) end
end

------------------------------------------------------------------------
-- Start og stopp
------------------------------------------------------------------------

function ns.Start()
  if ns.active then return end
  if Game.InCombat() then ns.Print(L.IN_COMBAT_START) return end
  ns.active, cdb.active = true, true
  local hasPole = ns.Gear.Start(cdb)
  if not hasPole then ns.Print(L.NO_POLE) end
  ns.Sound.Apply(db)
  ns.Session.Start(cdb)
  ns.Report.Hide()
  ns.Window.Show()
  ns.Window.Refresh(cdb)
end

function ns.Stop()
  if not ns.active then return end
  ns.active, cdb.active = false, false
  ns.Cast.Disarm()
  if not ns.Gear.Restore(cdb) then ns.Print(L.IN_COMBAT_RESTORE) end
  ns.Sound.Restore(db)
  ns.Window.CombatWarning(false)
  ns.Window.Hide()
  if ns.Session.Stop(cdb, db) then ns.Report.Show(1) end
end

function ns.Toggle()
  if ns.active then ns.Stop() else ns.Start() end
end

------------------------------------------------------------------------
-- Hendelser
------------------------------------------------------------------------

local ev = CreateFrame("Frame")
local on = {}

on.ADDON_LOADED = function(name)
  if name ~= addonName then return end
  SkittFiskeDB = SkittFiskeDB or {}
  SkittFiskeCharDB = SkittFiskeCharDB or {}
  db, cdb = SkittFiskeDB, SkittFiskeCharDB
  db.history = db.history or {}
  db.zones = db.zones or {}
  ns.db, ns.cdb = db, cdb
end

on.PLAYER_LOGIN = function()
  ns.Cast.Init()
  ns.Safe("vindu", function() ns.Window.Create(cdb) end)
  if not db.macroMade then
    if ensureMacro(true) then db.macroMade = true end
  end
  if cdb.active then
    -- Fortsett der du slapp (etter /reload eller utlogging midt i fiskingen)
    ns.active = true
    ns.Sound.Apply(db)
    ns.Session.Resume(cdb)
    ns.Session.Start(cdb)
    ns.Window.Show()
    ns.Window.Refresh(cdb)
  elseif db.sound then
    ns.Sound.Restore(db) -- en annen karakter fisket da spillet ble avsluttet
  end
  if cdb.restorePending and not Game.InCombat() then ns.Gear.Restore(cdb) end
end

-- Lyden tilbake når du logger ut midt i fiskingen; den settes på igjen neste gang du logger inn
on.PLAYER_LOGOUT = function()
  if ns.active then ns.Sound.Restore(db) end
  ns.Session.Pause(cdb)
end

on.PLAYER_REGEN_DISABLED = function()
  if ns.active then
    ns.Window.CombatWarning(true)
    ns.Print(L.AGGRO)
  end
end

on.PLAYER_REGEN_ENABLED = function()
  ns.Cast.Disarm()
  if queue.window ~= nil then
    if queue.window then ns.Window.Show() else ns.Window.Hide() end
    queue.window = nil
  end
  if cdb.restorePending then
    ns.Gear.Restore(cdb)
    ns.Print(L.RESTORED_LATER)
  end
  ns.Window.CombatWarning(false)
  if ns.active then ns.Window.Refresh(cdb) end
end

on.UNIT_SPELLCAST_CHANNEL_START = function(unit, _, spellId)
  if unit == "player" then ns.Session.OnChannelStart(cdb, spellId) if ns.active then ns.Window.RefreshCatch(cdb) end end
end

on.UNIT_SPELLCAST_CHANNEL_STOP = function(unit)
  if unit == "player" then ns.Debug.BiteStop() end
end

on.LOOT_OPENED = function()
  ns.Debug.BiteMark("LOOT_OPENED")
  ns.Session.OnLootOpened(cdb, db)
  if ns.active then ns.Window.RefreshCatch(cdb) end
end

on.LOOT_CLOSED = function() ns.Session.OnLootClosed(cdb) end

on.UI_ERROR_MESSAGE = function(a, b)
  ns.Session.OnError(cdb, a, b)
  if ns.active then ns.Window.RefreshCatch(cdb) end
end

on.BAG_UPDATE_DELAYED = function() if ns.active then ns.Window.RefreshLures() end end
on.UNIT_INVENTORY_CHANGED = function(unit)
  if unit == "player" and ns.active then ns.Window.RefreshLure() ns.Window.RefreshSkill() end
end
local function skill() if ns.active then ns.Window.RefreshSkill() end end
on.SKILL_LINES_CHANGED = skill
on.CHAT_MSG_SKILL = skill
on.ZONE_CHANGED = skill
on.ZONE_CHANGED_INDOORS = skill
on.ZONE_CHANGED_NEW_AREA = skill

for e in pairs(on) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, e, ...) on[e](...) end)

------------------------------------------------------------------------
-- /skitt
------------------------------------------------------------------------

SLASH_SKITTFISKE1 = "/skitt"
SLASH_SKITTFISKE2 = "/skittfiske"
SlashCmdList.SKITTFISKE = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$")
  if msg == "" then ns.Toggle()
  elseif msg == "makro" then macroToCursor()
  elseif msg == "rapport" then ns.Report.Show(1)
  elseif msg == "vindu" then if ns.active then ns.Window.Show() end
  elseif msg == "debug" then ns.Debug.Show()
  elseif msg == "øye" then ns.Window.EyeGlow(true) if C_Timer then C_Timer.After(5, function() ns.Window.EyeGlow(false) end) end
  elseif msg == "debug tøm" then ns.Debug.Clear()
  elseif msg == "debug nappe" then
    db.biteProbe = not db.biteProbe
    ns.Print(db.biteProbe and "nappe-lytteren er på." or "nappe-lytteren er av.")
  else ns.Print(L.HELP) end
end
