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
function D.Error(msg)
  local d = store()
  if not d or not ns.active then return end
  if d.errors[1] == msg then return end
  table.insert(d.errors, 1, msg)
  while #d.errors > 10 do table.remove(d.errors) end
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
end

function D.Clear()
  if ns.db then ns.db.debug = nil end
  ns.Print("debug tømt.")
end
