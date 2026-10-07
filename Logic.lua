-- Skitt Fiske: ren Lua uten WoW-API (testes i tests/test_logic.lua)
local addonName, ns = ...
local Logic = {}
ns.Logic = Logic

------------------------------------------------------------------------
-- Fiskebonus fra tooltip-linjer: «Equip: Increased Fishing +5.», «Fishing +2», «+5 Fishing»,
-- «Increases Fishing by 5». «Requires Fishing (100)» og agnets «Use:»-linje teller ikke.
------------------------------------------------------------------------

local function esc(s) return (s:gsub("(%W)", "%%%1")) end

function Logic.FishingBonus(lines, skillName)
  if type(lines) ~= "table" or type(skillName) ~= "string" or skillName == "" then return 0 end
  local name = esc(skillName:lower())
  local total = 0
  for _, line in ipairs(lines) do
    if type(line) == "string" then
      local l = line:lower()
      if l:find(name) and not l:find("%(%d+%)") and not l:find("^use:") then
        local n = l:match(name .. "%s*%+%s*(%d+)") or l:match("%+%s*(%d+)%s*" .. name)
          or l:match(name .. " by (%d+)")
        if n then total = total + tonumber(n) end
      end
    end
  end
  return total
end

------------------------------------------------------------------------
-- Hva skal på? candidates: { { slot, bonus, pole, link, id, equipped = slot|nil } }
-- Per plass vinner høyest bonus; stang alltid på 16 (også uten bonus). Likt = det du har på.
-- Svar: { [slot] = kandidat } bare der noe faktisk skal byttes.
------------------------------------------------------------------------

function Logic.PlanGear(candidates, mainHand)
  local best = {}
  for _, c in ipairs(candidates or {}) do
    local slot = c.slot
    if slot and (c.pole or (c.bonus or 0) > 0) and (slot ~= mainHand or c.pole) then
      local b = best[slot]
      local better = not b or (c.bonus or 0) > (b.bonus or 0)
        or ((c.bonus or 0) == (b.bonus or 0) and c.equipped and not b.equipped)
      if better then best[slot] = c end
    end
  end
  local plan = {}
  for slot, c in pairs(best) do
    if not c.equipped then plan[slot] = c end
  end
  return plan, best[mainHand] ~= nil
end

-- Rekkefølgen utstyret tas på eller av: hovedhånd først, så off-hand, så resten
function Logic.SlotOrder(slots, mainHand, offHand)
  local out = {}
  for s in pairs(slots) do out[#out + 1] = s end
  table.sort(out, function(a, b)
    local ra = a == mainHand and 0 or a == offHand and 1 or 2
    local rb = b == mainHand and 0 or b == offHand and 1 or 2
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  return out
end

------------------------------------------------------------------------
-- Lyd mens du fisker. current = nåværende verdier (strenger). Svar: verdiene som skal settes.
------------------------------------------------------------------------

Logic.SOUND_KEYS = { "Sound_EnableAllSound", "Sound_EnableSFX", "Sound_SFXVolume", "Sound_MusicVolume",
                     "Sound_AmbienceVolume", "Sound_MasterVolume", "Sound_EnableSoundWhenGameIsInBG" }

function Logic.SoundPlan(current)
  current = current or {}
  local plan = {
    Sound_EnableAllSound = "1",
    Sound_EnableSFX = "1",
    Sound_SFXVolume = "1",
    Sound_MusicVolume = "0",
    Sound_AmbienceVolume = "0",
    Sound_EnableSoundWhenGameIsInBG = "1",
  }
  local master = tonumber(current.Sound_MasterVolume)
  if master and master < 0.5 then plan.Sound_MasterVolume = "0.5" end
  -- Bare det som faktisk endres, og bare nøkler spillet har
  local out = {}
  for k, v in pairs(plan) do
    if current[k] ~= nil and tonumber(current[k]) ~= tonumber(v) then out[k] = v end
  end
  return out
end

------------------------------------------------------------------------
-- Dobbeltklikk
------------------------------------------------------------------------

function Logic.IsDoubleClick(last, now, limit)
  return last ~= nil and now - last > 0.02 and now - last <= (limit or 0.4)
end

------------------------------------------------------------------------
-- Agn. bag = { [id] = count }, known = { [id] = bonus }, extra = { [id] = true } (funnet via tooltip)
------------------------------------------------------------------------

function Logic.Lures(bag, known, extra)
  local out = {}
  for id, n in pairs(bag or {}) do
    if n > 0 and (known[id] or (extra and extra[id])) then
      out[#out + 1] = { id = id, count = n, bonus = known[id] or 0 }
    end
  end
  table.sort(out, function(a, b)
    if a.bonus ~= b.bonus then return a.bonus > b.bonus end
    return a.id < b.id
  end)
  return out
end

-- has = har stanga enchant, expMs = millisekunder igjen. Svar: "none" | "low" | "ok", sekunder
function Logic.LureState(has, expMs, low)
  if not has or type(expMs) ~= "number" then return "none", 0 end
  local s = math.floor(expMs / 1000)
  if s <= (low or 60) then return "low", s end
  return "ok", s
end

------------------------------------------------------------------------
-- Økta
------------------------------------------------------------------------

function Logic.NewSession(now, zone, skill)
  return { started = now, zone = zone, skillStart = skill, casts = 0, caught = 0, escaped = 0, missed = 0,
           money = 0, items = {}, names = {}, order = {} }
end

function Logic.AddCatch(s, loot)
  s.caught = s.caught + 1
  for _, l in ipairs(loot) do
    if l.money then
      s.money = s.money + l.money
    elseif l.id then
      if not s.items[l.id] then s.order[#s.order + 1] = l.id end
      s.items[l.id] = (s.items[l.id] or 0) + (l.n or 1)
      if l.name then s.names[l.id] = l.name end
    end
  end
end

-- Fangsten per sone (grunnlaget for lista over hva som kan fanges)
function Logic.AddZoneCatch(zones, key, loot)
  local z = zones[key]
  if not z then z = { caught = 0, items = {} } zones[key] = z end
  z.caught = z.caught + 1
  for _, l in ipairs(loot) do
    if l.id then z.items[l.id] = (z.items[l.id] or 0) + (l.n or 1) end
  end
end

-- price(id) → kobber per stk (eller nil). Svar: rapporten som lagres og vises
function Logic.Report(s, now, price, skillEnd, who)
  local secs = math.max(0, now - s.started)
  local items, total = {}, s.money or 0
  for _, id in ipairs(s.order) do
    local n = s.items[id]
    local p = price and price(id) or nil
    local v = p and math.floor(p * n + 0.5) or nil
    if v then total = total + v end
    items[#items + 1] = { id = id, n = n, name = s.names[id], value = v }
  end
  table.sort(items, function(a, b)
    if (a.value or 0) ~= (b.value or 0) then return (a.value or 0) > (b.value or 0) end
    if a.n ~= b.n then return a.n > b.n end
    return a.id < b.id
  end)
  local r = { started = s.started, secs = secs, zone = s.zone, who = who, casts = s.casts, caught = s.caught,
              escaped = s.escaped, missed = s.missed, money = s.money or 0, items = items, total = total }
  if s.skillStart and skillEnd then
    r.skillFrom, r.skillTo = s.skillStart, skillEnd
  end
  if secs >= 60 and total > 0 then r.perHour = math.floor(total * 3600 / secs + 0.5) end
  return r
end

-- Mange som slapp unna i forhold til fangsten = skillen er for lav for vannet
function Logic.TooLowSkill(r)
  return (r.escaped or 0) >= 3 and r.escaped >= (r.caught or 0) * 0.25
end

function Logic.PushHistory(list, r, max)
  table.insert(list, 1, r)
  while #list > (max or 20) do table.remove(list) end
end

------------------------------------------------------------------------
-- Tekst
------------------------------------------------------------------------

function Logic.Duration(secs, L)
  secs = math.floor(secs or 0)
  if secs < 60 then return L.DUR_S:format(secs) end
  local m = math.floor(secs / 60)
  if m < 60 then return L.DUR_M:format(m) end
  return L.DUR_HM:format(math.floor(m / 60), m % 60)
end

function Logic.Left(secs, L)
  if secs < 60 then return L.LEFT_S:format(secs) end
  return L.LEFT_M:format(math.ceil(secs / 60))
end

function Logic.Coins(c)
  c = math.floor((c or 0) + 0.5)
  local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. "g" end
  if s > 0 or (g > 0 and k > 0) then out[#out + 1] = s .. "s" end
  if k > 0 or #out == 0 then out[#out + 1] = k .. "c" end
  return table.concat(out, " ")
end

return Logic
